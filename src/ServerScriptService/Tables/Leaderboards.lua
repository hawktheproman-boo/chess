-- Global leaderboards, shared by every server of the experience. Two OrderedDataStores, key
-- tostring(userId), value = a count:
--   "wins"   ChessLB_Wins_v1        games won against people (every mode, Tournament too)
--   "titles" ChessLB_Champions_v1   tournaments won
-- Studio uses "<name>_studio" (like Tournament/Registry), so tests never touch the live boards.
-- Writes go in the background with retries and only for real ids (> 0); the debug setter
-- (Studio only, ChessDebug "lbFake") is the one way to put fake (negative) ids in.
--
--   Leaderboards.addWin(userId) / Leaderboards.addTitle(userId)       +1, background
--   Leaderboards.top(board, n = 10) -> { { rank, userId, name, value } }   (yields; cached CACHE s)
--   Leaderboards.mine(userId) -> { wins, titles }                        (yields)
-- top and mine return what they can: an empty list / zeros when the store can't be read.
-- Results.lua (ChessStats_v1) still holds the per-mode stats; builders/backfill_wins.lua seeds the
-- wins board from it once.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Leaderboards = {}

local SUFFIX = if RunService:IsStudio() then "_studio" else ""
local CACHE = 60 -- seconds a board's top list is reused
local MAX_N = 50
local NAMES = {
	wins = "ChessLB_Wins_v1",
	titles = "ChessLB_Champions_v1",
}
Leaderboards.BOARDS = { "wins", "titles" }

local stores = {}
for board, name in NAMES do
	local ok, s = pcall(function()
		return DataStoreService:GetOrderedDataStore(name .. SUFFIX)
	end)
	if ok then
		stores[board] = s
	else
		warn("[Chess] leaderboard store unavailable:", name, s)
	end
end

local warned = false
local cache = {} -- board -> { at = os.clock(), n, rows }
local fetching = {} -- board -> true while a GetSortedAsync is out
local names = {} -- userId -> name (fake ids: what lbFake gave them)

local function increment(board, userId: number)
	local store = stores[board]
	if not store or type(userId) ~= "number" or userId <= 0 then
		return
	end
	task.spawn(function()
		for attempt = 1, 3 do
			local ok, err = pcall(function()
				store:IncrementAsync(tostring(userId), 1)
			end)
			if ok then
				return
			end
			if not warned then
				warned = true
				warn("[Chess] couldn't update a leaderboard:", board, err)
			end
			task.wait(2 ^ attempt)
		end
	end)
end

function Leaderboards.addWin(userId: number)
	increment("wins", userId)
end

function Leaderboards.addTitle(userId: number)
	increment("titles", userId)
end

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.Name
		return player.Name
	end
	if userId > 0 then
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		if ok and type(name) == "string" then
			names[userId] = name
			return name
		end
		return "Player " .. userId -- (not cached: try again next time)
	end
	return "Test " .. -userId
end

-- the names for a page of entries, looked up side by side (each lookup can take a moment)
local function fillNames(rows)
	local left = #rows
	local done = Instance.new("BindableEvent")
	for _, r in rows do
		task.spawn(function()
			r.name = nameOf(r.userId)
			left -= 1
			if left == 0 then
				done:Fire()
			end
		end)
	end
	if left > 0 then
		done.Event:Wait()
	end
	done:Destroy()
end

local function fetch(board, n)
	local store = stores[board]
	if not store then
		return {}
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, n):GetCurrentPage()
	end)
	if not ok then
		if not warned then
			warned = true
			warn("[Chess] couldn't read a leaderboard:", board, page)
		end
		return nil
	end
	local rows = {}
	for i, entry in page do
		local id = tonumber(entry.key)
		if id then
			table.insert(rows, { rank = i, userId = id, name = "", value = entry.value })
		end
	end
	fillNames(rows)
	return rows
end

local function slice(rows, n)
	local out = table.create(math.min(n, #rows))
	for i = 1, math.min(n, #rows) do
		out[i] = rows[i]
	end
	return out
end

function Leaderboards.top(board: string, n: number?)
	if not NAMES[board] then
		return {}
	end
	n = math.clamp(math.floor(tonumber(n) or 10), 1, MAX_N)
	while fetching[board] do -- someone else is reading it: share their result
		task.wait(0.2)
	end
	local c = cache[board]
	if c and os.clock() - c.at < CACHE and c.n >= n then
		return slice(c.rows, n)
	end
	fetching[board] = true
	local ok, rows = pcall(fetch, board, n)
	fetching[board] = nil
	if ok and rows then
		cache[board] = { at = os.clock(), n = n, rows = rows }
		return slice(rows, n)
	end
	return if c then slice(c.rows, n) else {} -- (a stale list beats none)
end

function Leaderboards.mine(userId: number)
	local out = { wins = 0, titles = 0 }
	if type(userId) ~= "number" then
		return out
	end
	for _, board in Leaderboards.BOARDS do
		local store = stores[board]
		if store then
			local ok, v = pcall(store.GetAsync, store, tostring(userId))
			if ok and type(v) == "number" then
				out[board] = v
			end
		end
	end
	return out
end

-- Studio only (ChessDebug "lbFake"): set an entry outright, fake ids included, in the _studio stores.
function Leaderboards.debugSet(board: string, userId: number, value: number, name: string?)
	assert(RunService:IsStudio(), "Leaderboards.debugSet is Studio only")
	local store = stores[board]
	if not store then
		return false, "no store"
	end
	if name then
		names[userId] = name
	end
	local ok, err = pcall(store.SetAsync, store, tostring(userId), math.max(0, math.floor(value)))
	cache[board] = nil
	return ok, err
end

return Leaderboards
