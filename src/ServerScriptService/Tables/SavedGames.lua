-- VIP saved games: every game a VIP reviews is kept so they can open the review again from Stats.
-- DataStore "ChessGames_v1", key "u_<userId>", value { list = { game, ... } } newest first, at most
-- Settings.MAX_SAVED_GAMES. A game:
--   { id, t (os.time), mode, white, black, result = { winner, reason }, clock (id), myColor,
--     startFen, actions, accuracy?, counts? (grade -> n for myColor), sig }
-- The client sends the record; the server replays it and keeps only the legal actions (with only
-- plain fields), so a bad record can't store junk. Reviewing the same game twice updates one entry.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Settings = require(Shared.Settings)
local Game = require(Shared.Chess.Game)

local SavedGames = {}

local storeOk, store = pcall(function()
	return DataStoreService:GetDataStore("ChessGames_v1")
end)
if not storeOk then
	warn("[Chess] saved games DataStore unavailable:", store)
	store = nil
end

local MAX_PLIES = 600
local GRADES = { "brilliant", "great", "best", "excellent", "good", "inaccuracy", "mistake", "blunder" }

local function str(v, max)
	return if type(v) == "string" then string.sub(v, 1, max) else nil
end

-- an action with only plain fields (string keys, string / number / boolean values)
local function plain(action)
	local out = {}
	for k, v in action do
		local tv = type(v)
		if type(k) == "string" and #k <= 16 and (tv == "number" or tv == "boolean" or (tv == "string" and #v <= 16)) then
			out[k] = v
		end
	end
	return out
end

-- client record -> a clean game entry, or nil
local function clean(record)
	if type(record) ~= "table" or type(record.actions) ~= "table" then
		return nil
	end
	local mode = str(record.modeName, 20)
	if not Settings.hasMode(mode) then
		return nil
	end
	local startFen = str(record.startFen, 100)
	local ok, g = pcall(Game.forReplay, startFen, require(Shared.Modes[mode]), record.actions)
	if not ok then
		return nil
	end
	local actions, sig = {}, { startFen or "" }
	for i, a in record.actions do
		if i > MAX_PLIES or type(a) ~= "table" then
			break
		end
		local p = plain(a)
		local applied = pcall(function()
			assert(g:apply(p))
		end)
		if not applied then
			break
		end
		table.insert(actions, p)
		table.insert(sig, HttpService:JSONEncode(p))
	end
	if #actions == 0 then
		return nil
	end
	local result = type(record.result) == "table" and record.result or {}
	local counts = {}
	if type(record.counts) == "table" then
		for _, grade in GRADES do
			local n = record.counts[grade]
			if type(n) == "number" and n >= 0 and n < 1000 then
				counts[grade] = math.floor(n)
			end
		end
	end
	local acc = record.accuracy
	return {
		mode = mode,
		white = str(record.white, 40) or "?",
		black = str(record.black, 40) or "?",
		result = { winner = if result.winner == "w" or result.winner == "b" then result.winner else nil, reason = str(result.reason, 30) },
		clock = str(record.clockId, 12),
		myColor = if record.myColor == "b" then "b" else "w",
		startFen = startFen,
		actions = actions,
		accuracy = if type(acc) == "number" and acc >= 0 and acc <= 100 then math.floor(acc * 10 + 0.5) / 10 else nil,
		counts = counts,
		sig = table.concat(sig, ";"),
	}
end

-- Saves (or updates) a reviewed game. Returns true when stored.
function SavedGames.save(userId: number, record): boolean
	if not store or userId <= 0 then
		return false
	end
	local entry = clean(record)
	if not entry then
		return false
	end
	local ok, err = pcall(function()
		store:UpdateAsync("u_" .. userId, function(old)
			old = old or {}
			local list = old.list or {}
			for i, gm in list do
				if gm.sig == entry.sig then
					-- the same game reviewed again: keep its id and date, refresh the grades
					entry.id, entry.t = gm.id, gm.t
					table.remove(list, i)
					break
				end
			end
			entry.id = entry.id or HttpService:GenerateGUID(false):sub(1, 8)
			entry.t = entry.t or os.time()
			table.insert(list, 1, entry)
			while #list > Settings.MAX_SAVED_GAMES do
				table.remove(list)
			end
			old.list = list
			return old
		end)
	end)
	if not ok then
		warn("[Chess] couldn't save a game:", err)
	end
	return ok
end

local function load(userId)
	if not store then
		return nil
	end
	local ok, data = pcall(function()
		return store:GetAsync("u_" .. userId)
	end)
	return if ok then (data and data.list or {}) else nil
end

-- the list without the moves (for the Stats card), or nil if the store is down
function SavedGames.list(userId: number)
	local list = load(userId)
	if not list then
		return nil
	end
	local out = {}
	for _, gm in list do
		table.insert(out, { id = gm.id, t = gm.t, mode = gm.mode, white = gm.white, black = gm.black, result = gm.result,
			clock = gm.clock, myColor = gm.myColor, accuracy = gm.accuracy, counts = gm.counts, plies = #gm.actions })
	end
	return out
end

function SavedGames.get(userId: number, id: string)
	for _, gm in load(userId) or {} do
		if gm.id == id then
			return gm
		end
	end
	return nil
end

function SavedGames.delete(userId: number, id: string): boolean
	if not store then
		return false
	end
	return (pcall(function()
		store:UpdateAsync("u_" .. userId, function(old)
			if not (old and old.list) then
				return nil
			end
			for i, gm in old.list do
				if gm.id == id then
					table.remove(old.list, i)
					break
				end
			end
			return old
		end)
	end))
end

return SavedGames
