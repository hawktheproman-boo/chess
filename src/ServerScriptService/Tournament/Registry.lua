-- The one tournament that's registering or running, shared by every server of the experience.
-- MemoryStore hash map "ChessTournament_v1", key "current" (2 h TTL); every change is an UpdateAsync,
-- so two servers can't both add the 17th player or both launch it. The record:
--   { id, hostId, hostName, startsAt (os.time), players = { { userId, name } },
--     state = "open" | "launching" | "live" | "done" | "cancelled", reason?,
--     launchedBy? (JobId), launchingSince?, placeId?, accessCode?, privateServerId?,
--     round? (name of the round being played), champion? (name) }
-- MessagingService topic "ChessTournament" carries a small poke { kind, id } when it changes (a message
-- is at most 1 kB, so servers read the record itself); servers also poll it, as messages can be lost.
-- Studio uses its own map and topic, so tests never reach live servers.

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")

local Tournament = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Tournament"))

local Registry = {}

local SUFFIX = if RunService:IsStudio() then "_studio" else ""
local TOPIC = "ChessTournament" .. SUFFIX
local KEY = "current"
local TTL = 2 * 3600

local mapOk, map = pcall(function()
	return MemoryStoreService:GetHashMap("ChessTournament_v1" .. SUFFIX)
end)
if not mapOk then
	warn("[Chess] tournament MemoryStore unavailable:", map)
	map = nil
end

local ACTIVE = { open = true, launching = true, live = true }
Registry.ACTIVE = ACTIVE

function Registry.get()
	if not map then
		return nil
	end
	local ok, v = pcall(map.GetAsync, map, KEY)
	if not ok then
		warn("[Chess] couldn't read the tournament:", v)
		return nil
	end
	return v
end

-- change(old) returns the new record, or nil, err to leave it as it is. Returns ok, record | err.
function Registry.update(change)
	if not map then
		return false, "tournaments aren't available right now"
	end
	local result, why
	local ok, err = pcall(function()
		map:UpdateAsync(KEY, function(old)
			local new, reason = change(old)
			if not new then
				why = reason
				return nil
			end
			result = new
			return new
		end, TTL)
	end)
	if not ok then
		warn("[Chess] couldn't update the tournament:", err)
		return false, "couldn't reach the tournament service, try again"
	end
	if not result then
		return false, why or "no change"
	end
	return true, result
end

function Registry.publish(kind: string, record)
	task.spawn(function()
		pcall(MessagingService.PublishAsync, MessagingService, TOPIC, { kind = kind, id = record and record.id })
	end)
end

function Registry.subscribe(fn)
	task.spawn(function()
		local ok, err = pcall(MessagingService.SubscribeAsync, MessagingService, TOPIC, function(msg)
			fn(type(msg.Data) == "table" and msg.Data or {})
		end)
		if not ok then
			warn("[Chess] couldn't listen for tournaments:", err)
		end
	end)
end

local function find(record, userId)
	for i, p in record.players do
		if p.userId == userId then
			return i
		end
	end
	return nil
end
Registry.find = find

-- A VIP starts one; they're its first player.
function Registry.create(host)
	return Registry.update(function(old)
		if old and ACTIVE[old.state] then
			return nil, "a tournament is already " .. (if old.state == "open" then "starting" else "running")
		end
		return {
			id = HttpService:GenerateGUID(false),
			hostId = host.userId,
			hostName = host.name,
			startsAt = os.time() + Tournament.COUNTDOWN,
			players = { { userId = host.userId, name = host.name } },
			state = "open",
		}
	end)
end

function Registry.join(p)
	return Registry.update(function(old)
		if not old or old.state ~= "open" then
			return nil, "no tournament is open to join"
		end
		if find(old, p.userId) then
			return nil, "you're already in"
		end
		if #old.players >= Tournament.MAX then
			return nil, "the tournament is full"
		end
		table.insert(old.players, { userId = p.userId, name = p.name })
		return old
	end)
end

function Registry.leave(userId: number)
	return Registry.update(function(old)
		local i = old and old.state == "open" and find(old, userId)
		if not i then
			return nil, "you're not in it"
		end
		table.remove(old.players, i)
		return old
	end)
end

-- the record as clients see it (no access code)
function Registry.view(record, userId: number?)
	if not record then
		return nil
	end
	local names = {}
	for _, p in record.players do
		table.insert(names, p.name)
	end
	return {
		id = record.id,
		state = record.state,
		reason = record.reason,
		hostName = record.hostName,
		startsAt = record.startsAt,
		count = #record.players,
		names = names,
		joined = userId ~= nil and find(record, userId) ~= nil,
		round = record.round,
		champion = record.champion,
	}
end

return Registry
