-- Knockout tournament rules and bracket logic, shared by the server and the client. A VIP starts a
-- tournament, anyone can join, it needs 8-16 players and starts after a 5-minute countdown. Classic
-- rules only (no abilities, no Steal). It's a knockout: lose and you're out. A drawn game is replayed
-- with the colours swapped, and if that's drawn too an Armageddon game decides it (Black gets less
-- time, but a draw counts as a Black win).
--
-- Pure module: no services, no Instances. The bracket is a plain table that must stay fully
-- serialisable (it goes through RemoteEvents and MemoryStore): only strings, numbers, booleans and
-- tables with either array keys or string keys, never mixed. `false` means "nobody".
--
-- player = { userId, name }
-- match  = { id = "R<round>M<index>", round, index, a, b (player | false), winner (userId | false),
--            done, bye, stage = "game" | "rematch" | "armageddon", games, absent, whiteFirst }
-- bracket = { size, round, rounds = { { match, ... }, ... }, finished, champion, seed }

local Tournament = {}

Tournament.MIN = 8 -- fewest players to start
Tournament.MAX = 16 -- most players
Tournament.COUNTDOWN = 300 -- seconds from the start to the first round
Tournament.CLOCK = "5+3" -- a Settings clock preset id (game and rematch)
Tournament.ARMAGEDDON = { white = 300, black = 240, inc = 2 } -- seconds; a draw counts as a Black win
Tournament.ARRIVAL_WAIT = 60 -- seconds the tournament server waits for registered players to arrive
Tournament.BREAK = 20 -- seconds between rounds
Tournament.END_WAIT = 120 -- seconds the results stay up after the final
Tournament.MIN_LOG_PLIES = 20 -- a game this short isn't logged
Tournament.LOG_TOP = 10 -- games kept in each list of the daily log (top accuracy, most brilliants)

-- The smallest power of two that holds n players (at least 2).
local function sizeFor(n: number): number
	local size = 2
	while size < n do
		size *= 2
	end
	return size
end

-- A fresh list in random order.
local function shuffled(list, rng: Random)
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = rng:NextInteger(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

-- Build one match. a / b are players or false. One player = a bye (already won).
local function newMatch(round: number, index: number, a, b, rng: Random)
	local m = {
		id = "R" .. round .. "M" .. index,
		round = round,
		index = index,
		a = a,
		b = b,
		winner = false,
		done = false,
		bye = false,
		stage = "game",
		games = {},
		absent = {},
		whiteFirst = false,
	}
	if a and b then
		m.whiteFirst = if rng:NextInteger(1, 2) == 1 then a.userId else b.userId
	elseif a or b then
		local p = a or b
		m.bye = true
		m.done = true
		m.winner = p.userId
		m.whiteFirst = p.userId
	else
		m.done = true -- nobody turned up on either side
	end
	return m
end

-- The other player's userId in a match (false if there isn't one).
local function opponent(match, userId)
	if match.a and match.a.userId == userId then
		return match.b and match.b.userId
	elseif match.b and match.b.userId == userId then
		return match.a and match.a.userId
	end
	return false
end

-- Find a player's { userId, name } in round 1.
local function findPlayer(bracket, userId)
	for _, m in bracket.rounds[1] do
		if m.a and m.a.userId == userId then
			return m.a
		end
		if m.b and m.b.userId == userId then
			return m.b
		end
	end
	return nil
end

local function newEvents()
	return { matchDone = false, roundDone = false, finished = false }
end

-- Pair the winners of the finished round into the next one.
local function buildNextRound(bracket)
	local prev = bracket.rounds[bracket.round]
	local round = bracket.round + 1
	local rng = Random.new(bracket.seed + round)
	local out = {}
	for i = 1, #prev, 2 do
		local w1, w2 = prev[i].winner, prev[i + 1].winner
		local a, b = false, false
		if w1 then
			local p = findPlayer(bracket, w1)
			a = { userId = p.userId, name = p.name }
		end
		if w2 then
			local p = findPlayer(bracket, w2)
			b = { userId = p.userId, name = p.name }
		end
		table.insert(out, newMatch(round, #out + 1, a, b, rng))
	end
	table.insert(bracket.rounds, out)
	bracket.round = round
end

-- If every match of the current round is done, move on (and keep going while rounds resolve by byes).
local function closeRound(bracket, ev)
	while not bracket.finished do
		local ms = bracket.rounds[bracket.round]
		for _, m in ms do
			if not m.done then
				return
			end
		end
		ev.roundDone = true
		if #ms == 1 then
			bracket.finished = true
			bracket.champion = ms[1].winner
			ev.finished = true
			ev.champion = bracket.champion
			return
		end
		buildNextRound(bracket)
		ev.newRound = bracket.round
	end
end

-- Players are { userId, name }. Returns the round-1 bracket (or a finished one for 0 / 1 players).
function Tournament.newBracket(players, rng: Random?)
	local r = rng or Random.new()
	local n = #players
	local size = sizeFor(n)
	local bracket = {
		size = size,
		round = 1,
		rounds = { {} },
		finished = false,
		champion = false,
		seed = r:NextInteger(1, 2147483646),
	}
	if n == 0 then
		bracket.finished = true
		return bracket
	end

	local list = shuffled(players, r)
	local count = size // 2

	-- everyone gets a first slot, the rest fill second slots alternating top half / bottom half
	local order = {}
	if count == 1 then
		order = { 1 }
	else
		for i = 1, count // 2 do
			table.insert(order, i)
			table.insert(order, i + count // 2)
		end
	end
	local second = {}
	for i = count + 1, n do
		second[order[i - count]] = list[i]
	end

	for i = 1, count do
		local a = { userId = list[i].userId, name = list[i].name }
		local b = false
		if second[i] then
			b = { userId = second[i].userId, name = second[i].name }
		end
		table.insert(bracket.rounds[1], newMatch(1, i, a, b, r))
	end

	closeRound(bracket, newEvents()) -- a single player wins by walkover
	return bracket
end

-- The current round's matches that still need playing.
function Tournament.current(bracket)
	local out = {}
	if bracket.finished then
		return out
	end
	for _, m in bracket.rounds[bracket.round] do
		if not m.done and m.a and m.b then
			table.insert(out, m)
		end
	end
	return out
end

-- Who plays what colour next in this match, and on which clock.
function Tournament.nextGame(match)
	if match.done or not match.a or not match.b then
		return nil
	end
	local first = match.whiteFirst
	local second = opponent(match, first)
	if match.stage == "game" then
		return { white = first, black = second, stage = "game", clock = Tournament.CLOCK }
	elseif match.stage == "rematch" then
		return { white = second, black = first, stage = "rematch", clock = Tournament.CLOCK }
	end
	-- Armageddon: the player who had Black in game 1 takes White
	return { white = second, black = first, stage = "armageddon", clock = Tournament.ARMAGEDDON }
end

-- Apply a result to a match that's known to be playable.
local function applyOutcome(bracket, match, outcome, ev)
	local g = Tournament.nextGame(match)
	local game = { white = g.white, black = g.black, stage = match.stage, outcome = "" }

	if type(outcome) == "table" then
		game.outcome = "forfeit"
		match.winner = opponent(match, outcome.forfeit)
		match.done = true
	elseif outcome == "white" or outcome == "black" then
		game.outcome = outcome
		match.winner = if outcome == "white" then g.white else g.black
		match.done = true
	else
		game.outcome = "draw"
		if match.stage == "game" then
			match.stage = "rematch"
		elseif match.stage == "rematch" then
			match.stage = "armageddon"
		else
			match.winner = g.black -- a drawn Armageddon is a Black win
			match.done = true
		end
	end
	table.insert(match.games, game)

	if match.done then
		ev.matchDone = true
		closeRound(bracket, ev)
	end
end

-- The match with this id, if it's still waiting for a result.
local function openMatch(bracket, matchId)
	if bracket.finished then
		return nil
	end
	local r, i = string.match(matchId, "^R(%d+)M(%d+)$")
	local round = r and bracket.rounds[tonumber(r)]
	local m = round and round[tonumber(i)]
	if m and m.id == matchId and not m.done and m.a and m.b then
		return m
	end
	return nil
end

-- outcome: "white" | "black" | "draw" (the game nextGame gave out), or { forfeit = userId }.
function Tournament.report(bracket, matchId: string, outcome)
	local m = openMatch(bracket, matchId)
	if not m then
		return {}
	end
	if type(outcome) == "table" then
		local f = outcome.forfeit
		if not (m.a.userId == f or m.b.userId == f) then
			return {}
		end
	elseif outcome ~= "white" and outcome ~= "black" and outcome ~= "draw" then
		return {}
	end
	local ev = newEvents()
	applyOutcome(bracket, m, outcome, ev)
	return ev
end

-- The player's undone match in the current round.
function Tournament.matchOf(bracket, userId: number)
	if bracket.finished then
		return nil
	end
	for _, m in bracket.rounds[bracket.round] do
		if not m.done and ((m.a and m.a.userId == userId) or (m.b and m.b.userId == userId)) then
			return m
		end
	end
	return nil
end

-- Several players who never showed up / left before playing, handled together. A match where both
-- are absent has no winner; if only one is, they forfeit.
function Tournament.markAllAbsent(bracket, userIds)
	local hit = {}
	for _, id in userIds do
		local m = Tournament.matchOf(bracket, id)
		if m then
			m.absent[tostring(id)] = true
			if not table.find(hit, m) then
				table.insert(hit, m)
			end
		end
	end
	if #hit == 0 then
		return {}
	end
	local ev = newEvents()
	for _, m in hit do
		local aOut = m.absent[tostring(m.a.userId)]
		local bOut = m.absent[tostring(m.b.userId)]
		if aOut and bOut then
			m.done = true
			m.winner = false
			ev.matchDone = true
			closeRound(bracket, ev)
		else
			local loser = if aOut then m.a.userId else m.b.userId
			applyOutcome(bracket, m, { forfeit = loser }, ev)
		end
	end
	return ev
end

-- One player who never showed up / left before playing.
function Tournament.markAbsent(bracket, userId: number)
	return Tournament.markAllAbsent(bracket, { userId })
end

-- "Final", "Semi-final", "Quarter-final", "Round of 16" by how many players the round has.
function Tournament.roundName(round: number, size: number): string
	local n = math.floor(size / 2 ^ (round - 1))
	if n <= 2 then
		return "Final"
	elseif n == 4 then
		return "Semi-final"
	elseif n == 8 then
		return "Quarter-final"
	end
	return "Round of " .. n
end

function Tournament.playerName(bracket, userId: number): string?
	local p = findPlayer(bracket, userId)
	return p and p.name
end

return Tournament
