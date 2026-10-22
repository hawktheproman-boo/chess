-- The day's best tournament games. Every finished tournament game is reviewed on the server
-- (Shared/Bot/Review, one at a time, spread over frames) and offered to DataStore "ChessDaily_v1",
-- key "d_<YYYY-MM-DD>" (UTC; Studio writes "studio_d_..." so tests never touch the real day):
--   { champions = { entry }, top = { entry }, brilliant = { entry } }
--   champions: every tournament's deciding game of the final (always kept, however it ended)
--   top:       the Tournament.LOG_TOP games with the highest accuracy by one player (games of at least
--              Tournament.MIN_LOG_PLIES plies that weren't abandoned)
--   brilliant: the Tournament.LOG_TOP games with the most brilliant moves
-- entry = { id, t, white, black, whiteId, blackId, result, clock, startFen, actions, plies,
--           accuracy = { w, b }, brilliants = { w, b }, best, bril, tournamentId, round, stage, final }
-- The lobby lists them without moves (DailyLog.today) and opens one (DailyLog.game) in the review.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tournament = require(Shared.Tournament)
local Review = require(Shared.Bot.Review)
local Classic = require(Shared.Modes.Classic)

local DailyLog = {}

local PREFIX = if RunService:IsStudio() then "studio_d_" else "d_"
local CACHE = 30 -- seconds the lobby reuses what it read

local store
do
	local ok, s = pcall(function()
		return DataStoreService:GetDataStore("ChessDaily_v1")
	end)
	store = if ok then s else nil
end

local function dayKey(t: number?): string
	return PREFIX .. os.date("!%Y-%m-%d", t or os.time())
end

local queue = {} -- entries waiting for their review
local working = false
local pending = 0 -- entries queued or being reviewed (BindToClose waits for them)

local function trim(list, n, better)
	table.sort(list, better)
	while #list > n do
		table.remove(list)
	end
end

local function save(entry)
	if not store then
		return
	end
	local ok, err = pcall(function()
		store:UpdateAsync(dayKey(entry.t), function(old)
			local v = type(old) == "table" and old or {}
			v.champions = v.champions or {}
			v.top = v.top or {}
			v.brilliant = v.brilliant or {}
			if entry.final then
				table.insert(v.champions, entry)
			end
			local real = entry.plies >= Tournament.MIN_LOG_PLIES and entry.result.reason ~= "abandoned"
			if real and entry.best then
				table.insert(v.top, entry)
				trim(v.top, Tournament.LOG_TOP, function(a, b)
					return (a.best or 0) > (b.best or 0)
				end)
			end
			if real and entry.bril > 0 then
				table.insert(v.brilliant, entry)
				trim(v.brilliant, Tournament.LOG_TOP, function(a, b)
					if a.bril ~= b.bril then
						return a.bril > b.bril
					end
					return (a.best or 0) > (b.best or 0)
				end)
			end
			return v
		end)
	end)
	if not ok then
		warn("[Chess] couldn't save to the daily log:", err)
	end
end

local function review(entry)
	if entry.plies > 0 then
		local ok, err, summary = pcall(Review.analyse, { startFen = entry.startFen, mode = Classic, actions = entry.actions }, {
			now = os.clock,
			yield = task.wait,
			budget = 0.2,
			depth = 5,
			slice = 0.006,
		})
		if ok and summary then
			for _, color in { "w", "b" } do
				local s = summary[color]
				entry.accuracy[color] = s.accuracy and math.floor(s.accuracy * 10 + 0.5) / 10 or nil
				entry.brilliants[color] = s.counts.brilliant or 0
			end
			entry.best = math.max(entry.accuracy.w or 0, entry.accuracy.b or 0)
			entry.bril = entry.brilliants.w + entry.brilliants.b
		else
			warn("[Chess] couldn't review a tournament game:", if ok then "no summary" else err)
		end
	end
	save(entry)
end

local function work()
	if working then
		return
	end
	working = true
	while #queue > 0 do
		local entry = table.remove(queue, 1)
		review(entry)
		pending -= 1
	end
	working = false
end

-- A tournament game finished. game = { white, black, whiteId, blackId, result, clock, startFen, actions };
-- meta = { tournamentId, round, stage, final }. The final's deciding game jumps the queue.
function DailyLog.consider(game, meta)
	local entry = {
		id = HttpService:GenerateGUID(false),
		t = os.time(),
		white = game.white,
		black = game.black,
		whiteId = game.whiteId,
		blackId = game.blackId,
		result = { winner = game.result.winner, reason = game.result.reason },
		clock = game.clock,
		startFen = game.startFen,
		actions = game.actions,
		plies = #game.actions,
		accuracy = {},
		brilliants = { w = 0, b = 0 },
		best = nil,
		bril = 0,
		tournamentId = meta.tournamentId,
		round = meta.round,
		stage = meta.stage,
		final = meta.final == true,
	}
	pending += 1
	if entry.final then
		table.insert(queue, 1, entry)
	else
		table.insert(queue, entry)
	end
	task.spawn(work)
end

function DailyLog.busy(): boolean
	return pending > 0
end

-- today's lists without the moves: { champions, top, brilliant }
local cached, cachedAt = nil, 0
local function readToday()
	if cached and os.clock() - cachedAt < CACHE then
		return cached
	end
	if not store then
		return {}
	end
	local ok, v = pcall(store.GetAsync, store, dayKey())
	if ok then
		cached, cachedAt = (if type(v) == "table" then v else {}), os.clock()
	end
	return cached or {}
end

function DailyLog.today()
	local v = readToday()
	local out = { day = os.date("!%Y-%m-%d") }
	for _, list in { "champions", "top", "brilliant" } do
		out[list] = {}
		for _, e in v[list] or {} do
			table.insert(out[list], {
				id = e.id, t = e.t, white = e.white, black = e.black, result = e.result, clock = e.clock,
				plies = e.plies, accuracy = e.accuracy, brilliants = e.brilliants, best = e.best, bril = e.bril,
				round = e.round, stage = e.stage, final = e.final,
			})
		end
	end
	return out
end

-- one of today's games, with its moves
function DailyLog.game(id)
	if type(id) ~= "string" then
		return nil
	end
	local v = readToday()
	for _, list in { "champions", "top", "brilliant" } do
		for _, e in v[list] or {} do
			if e.id == id then
				return e
			end
		end
	end
	return nil
end

game:BindToClose(function()
	local deadline = os.clock() + 25
	while DailyLog.busy() and os.clock() < deadline do
		task.wait(0.5)
	end
end)

return DailyLog
