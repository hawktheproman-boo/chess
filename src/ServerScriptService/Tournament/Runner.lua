-- Runs a tournament inside the tournament place (a reserved server; TableService starts it when
-- game.PlaceId isn't the lobby). It finds its record (Registry) by this server's PrivateServerId, waits
-- for the registered players (Tournament.ARRIVAL_WAIT), draws the knockout bracket with those who
-- came, and plays it on the room's tables: each match is started on a free table with
-- ChessTable:runMatch (Classic, the tournament clock, no Steal); a draw is replayed with colours
-- swapped, then Armageddon (Shared/Tournament decides). Anyone else here is a spectator.
-- A player who isn't in the server when their game is due is marked absent (they forfeit).
-- Clients get Remotes.Tournament { kind = "bracket", bracket, tables = { matchId -> tableId }, round,
-- state = "arriving" | "playing" | "break" | "done" | "none", champion?, nextIn? }.
-- Every finished game goes to DailyLog; the champion is announced to every lobby (Registry) and
-- gets +1 on the Champions leaderboard (not in test runs), and after Tournament.END_WAIT everyone
-- goes back to the lobby.
--
-- Runner.start(ctx) ctx = { tables, remote, participantFor, test? = { players = { participant },
-- botSpeed? } } (Studio: test players are bots, the record is made up and nothing is announced).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Settings = require(Shared.Settings)
local Tournament = require(Shared.Tournament)
local Registry = require(script.Parent.Registry)
local DailyLog = require(script.Parent.DailyLog)
local Leaderboards = require(script.Parent.Parent:WaitForChild("Tables"):WaitForChild("Leaderboards"))

local Runner = {}

local ctx
local record -- the Registry record (or the test's)
local bracket
local running = {} -- matchId -> ChessTable
local present = {} -- userId -> participant (players here, and test bots)
local state = "arriving"
local nextAt -- os.clock() when the next round starts (during a break)
local championName

local function roundName()
	return if bracket then Tournament.roundName(bracket.round, bracket.size) else "Players arriving"
end

local function view()
	local tablesOf = {}
	for id, t in running do
		tablesOf[id] = t.id
	end
	return {
		kind = "bracket",
		state = state,
		bracket = bracket,
		tables = tablesOf,
		round = if state == "done" then "Finished" else roundName(),
		champion = championName,
		nextIn = if nextAt then math.max(0, math.ceil(nextAt - os.clock())) else nil,
		hostName = record and record.hostName,
		expected = record and #record.players or 0,
		arrived = (function()
			local n = 0
			for _ in present do
				n += 1
			end
			return n
		end)(),
	}
end

local function broadcast()
	ctx.remote:FireAllClients(view())
end

local function setRound(text)
	if ctx.test or not record then
		return
	end
	task.spawn(function()
		local ok, rec = Registry.update(function(old)
			if not old or old.id ~= record.id then
				return nil, "changed"
			end
			old.round = text
			return old
		end)
		if ok then
			Registry.publish("round", rec)
		end
	end)
end

local function freeTable()
	for i = 1, Settings.TABLE_COUNT do
		local t = ctx.tables["T" .. i]
		if t and not t.owner and t.status ~= "playing" then
			return t
		end
	end
	return nil
end

local schedule -- (forward)

-- did this player sit down for at least one game (not a walkover: byes and no-shows only)?
local function playedAGame(userId: number): boolean
	for _, round in bracket.rounds do
		for _, m in round do
			if #m.games > 0 and ((m.a and m.a.userId == userId) or (m.b and m.b.userId == userId)) then
				return true
			end
		end
	end
	return false
end

local function finishTournament()
	state = "done"
	nextAt = nil
	championName = if bracket.champion then Tournament.playerName(bracket, bracket.champion) else nil
	broadcast()
	local champion = bracket.champion
	if not ctx.test and type(champion) == "number" and champion > 0 and playedAGame(champion) then
		Leaderboards.addTitle(champion)
	end
	if not ctx.test and record then
		task.spawn(function()
			local ok, rec = Registry.update(function(old)
				if not old or old.id ~= record.id then
					return nil, "changed"
				end
				old.state = "done"
				old.champion = championName
				old.round = "Finished"
				return old
			end)
			if ok then
				Registry.publish("finished", rec)
			end
		end)
	end
	task.delay(Tournament.END_WAIT, function()
		if RunService:IsStudio() or ctx.test then
			return
		end
		local everyone = Players:GetPlayers()
		if #everyone > 0 then
			pcall(TeleportService.TeleportAsync, TeleportService, Settings.START_PLACE_ID, everyone)
		end
	end)
end

local function afterReport(ev)
	if ev.finished or bracket.finished then
		finishTournament()
	elseif ev.roundDone then
		state = "break"
		nextAt = os.clock() + Tournament.BREAK
		setRound(roundName())
		broadcast()
		task.delay(Tournament.BREAK, function()
			nextAt = nil
			state = "playing"
			schedule()
		end)
	else
		broadcast()
		task.delay(3, schedule) -- a rematch / Armageddon, or nothing (the round's other games go on)
	end
end

local function onResult(t, result)
	local info = t.match
	if not info or running[info.matchId] ~= t then
		return
	end
	running[info.matchId] = nil
	local outcome = if result.winner == "w" then "white" elseif result.winner == "b" then "black" else "draw"
	local actions = {}
	for _, h in t.game.history do
		table.insert(actions, h.action)
	end
	local white, black = t.seats.w, t.seats.b
	local ev = Tournament.report(bracket, info.matchId, outcome)
	DailyLog.consider({
		white = white.name, black = black.name, whiteId = white.userId, blackId = black.userId,
		result = result, clock = t.settings.clock, startFen = t.startFen, actions = actions,
	}, {
		tournamentId = record and record.id, round = info.round, stage = info.stage, final = ev.finished == true,
	})
	task.delay(5, function()
		t:release()
	end)
	afterReport(ev)
end

-- start every match of the round that isn't being played yet
schedule = function()
	if not bracket or bracket.finished or state ~= "playing" then
		return
	end
	-- players who aren't here forfeit
	local gone = {}
	for _, m in Tournament.current(bracket) do
		if not running[m.id] then
			for _, p in { m.a, m.b } do
				if not present[p.userId] then
					table.insert(gone, p.userId)
				end
			end
		end
	end
	if #gone > 0 then
		local ev = Tournament.markAllAbsent(bracket, gone)
		if ev.roundDone or ev.finished then
			afterReport(ev)
			return
		end
	end
	for _, m in Tournament.current(bracket) do
		if not running[m.id] then
			local t = freeTable()
			if not t then
				task.delay(3, schedule) -- a table is still showing a result
				break
			end
			local g = Tournament.nextGame(m)
			local white, black = present[g.white], present[g.black]
			running[m.id] = t
			t.onTournament = onResult
			if ctx.test and ctx.test.botSpeed then
				t.botSpeed = ctx.test.botSpeed
			end
			t:runMatch(white, black, {
				clock = if type(g.clock) == "string" then g.clock else nil,
				clockOverride = if type(g.clock) == "table" then g.clock else nil,
				match = { matchId = m.id, stage = g.stage, round = roundName() },
			})
		end
	end
	broadcast()
end

local function begin()
	local arrived = {}
	for _, p in record.players do
		if present[p.userId] then
			table.insert(arrived, { userId = p.userId, name = p.name })
		end
	end
	bracket = Tournament.newBracket(arrived)
	if bracket.finished then
		finishTournament()
		return
	end
	state = "playing"
	setRound(roundName())
	schedule()
end

local function findRecord()
	for _ = 1, 15 do
		local rec = Registry.get()
		if rec and rec.privateServerId and rec.privateServerId == game.PrivateServerId then
			return rec
		end
		task.wait(2)
	end
	return nil
end

function Runner.start(c)
	ctx = c
	if ctx.test then
		record = { id = "test", hostName = "Studio", players = {} }
		for _, p in ctx.test.players do
			table.insert(record.players, { userId = p.userId, name = p.name })
			present[p.userId] = p
		end
		begin()
		return
	end
	Players.PlayerAdded:Connect(function(player)
		present[player.UserId] = ctx.participantFor(player)
		task.wait(1)
		if player.Parent then
			ctx.remote:FireClient(player, view())
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		present[player.UserId] = nil
	end)
	for _, player in Players:GetPlayers() do
		present[player.UserId] = ctx.participantFor(player)
	end
	task.spawn(function()
		record = findRecord()
		if not record then
			state = "none"
			broadcast()
			task.wait(10)
			if not RunService:IsStudio() then
				local everyone = Players:GetPlayers()
				if #everyone > 0 then
					pcall(TeleportService.TeleportAsync, TeleportService, Settings.START_PLACE_ID, everyone)
				end
			end
			return
		end
		-- wait for the registered players (everyone, or until the time is up)
		local deadline = os.clock() + Tournament.ARRIVAL_WAIT
		while os.clock() < deadline do
			local missing = 0
			for _, p in record.players do
				if not present[p.userId] then
					missing += 1
				end
			end
			if missing == 0 then
				break
			end
			nextAt = deadline
			broadcast()
			task.wait(2)
		end
		nextAt = nil
		begin()
	end)
end

-- a player asks for the bracket (on joining)
function Runner.view()
	return view()
end

return Runner
