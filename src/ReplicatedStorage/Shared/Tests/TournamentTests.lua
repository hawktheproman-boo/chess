-- Tournament tests (pure, Edit mode): require(<clone of Shared>.Tests.TournamentTests).run()

local Shared = script.Parent.Parent
local T = require(Shared.Tournament)
local Tests = {}

local function makePlayers(n)
	local out = {}
	for i = 1, n do
		table.insert(out, { userId = 100 + i, name = "P" .. i })
	end
	return out
end

local function bracketOf(n, seed)
	return T.newBracket(makePlayers(n), Random.new(seed or 1))
end

-- how many matches of round 1 are byes
local function byes(b)
	local c = 0
	for _, m in b.rounds[1] do
		if m.bye then
			c += 1
		end
	end
	return c
end

-- play every match out, White always wins; returns how many games were reported
local function playAll(b)
	local games = 0
	while not b.finished do
		local list = T.current(b)
		assert(#list > 0, "bracket stuck: nothing to play")
		local m = list[1]
		T.report(b, m.id, "white")
		games += 1
		assert(games < 200, "too many games")
	end
	return games
end

local function isEntrant(n, userId)
	return type(userId) == "number" and userId > 100 and userId <= 100 + n
end

-- every table has only array keys or only string keys; values are plain data; no cycles
local function checkPlain(t, stack, path)
	assert(not stack[t], "cycle at " .. path)
	stack[t] = true
	local n = #t
	local arr, str = 0, 0
	for k, v in t do
		if type(k) == "number" then
			arr += 1
			assert(k >= 1 and k <= n and k == math.floor(k), "bad array key " .. tostring(k) .. " at " .. path)
		elseif type(k) == "string" then
			str += 1
		else
			error("bad key type at " .. path)
		end
		local tv = type(v)
		assert(tv == "string" or tv == "number" or tv == "boolean" or tv == "table", tv .. " value at " .. path)
		if tv == "table" then
			checkPlain(v, stack, path .. "." .. tostring(k))
		end
	end
	assert(arr == 0 or str == 0, "mixed keys at " .. path)
	assert(arr == 0 or arr == n, "hole in array at " .. path)
	stack[t] = nil
end

local CASES = {
	{ "8 players: 3 rounds, no byes, 7 games to a champion", function()
		local b = bracketOf(8)
		assert(b.size == 8, "size " .. b.size)
		assert(#b.rounds[1] == 4, "R1 matches " .. #b.rounds[1])
		assert(byes(b) == 0, "byes in an 8-player bracket")
		assert(playAll(b) == 7, "game count")
		assert(b.finished and isEntrant(8, b.champion), "no champion")
		assert(#b.rounds == 3, "rounds " .. #b.rounds)
		assert(T.roundName(1, 8) == "Quarter-final", T.roundName(1, 8))
		assert(T.roundName(2, 8) == "Semi-final", T.roundName(2, 8))
		assert(T.roundName(3, 8) == "Final", T.roundName(3, 8))
		assert(T.roundName(1, 16) == "Round of 16", T.roundName(1, 16))
	end },
	{ "9 players: 16 slots, 7 byes and 1 real match in round 1", function()
		local b = bracketOf(9)
		assert(b.size == 16, "size " .. b.size)
		assert(#b.rounds[1] == 8, "R1 matches")
		assert(byes(b) == 7, "byes " .. byes(b))
		assert(#T.current(b) == 1, "real matches " .. #T.current(b))
		assert(playAll(b) == 8, "game count")
		assert(b.finished and isEntrant(9, b.champion), "champion")
	end },
	{ "13 and 16 players: the right byes, n - 1 games", function()
		for _, case in { { 13, 3 }, { 16, 0 } } do
			local n, want = case[1], case[2]
			local b = bracketOf(n, n)
			assert(b.size == 16, "size for " .. n)
			assert(byes(b) == want, n .. " players: byes " .. byes(b))
			assert(playAll(b) == n - 1, n .. " players: game count")
			assert(b.finished and isEntrant(n, b.champion), n .. " players: champion")
		end
	end },
	{ "draw chain: rematch with colours swapped, then Armageddon, then Black wins", function()
		local b = bracketOf(8)
		local m = T.current(b)[1]
		local g1 = T.nextGame(m)
		assert(g1.stage == "game" and g1.clock == T.CLOCK, "game 1")
		assert(g1.white == m.whiteFirst, "white isn't whiteFirst")

		local ev = T.report(b, m.id, "draw")
		assert(not ev.matchDone and m.stage == "rematch", "no rematch after a draw")
		local g2 = T.nextGame(m)
		assert(g2.stage == "rematch" and g2.clock == T.CLOCK, "rematch clock")
		assert(g2.white == g1.black and g2.black == g1.white, "colours not swapped")

		T.report(b, m.id, "draw")
		assert(not m.done and m.stage == "armageddon", "no armageddon after two draws")
		local g3 = T.nextGame(m)
		assert(g3.stage == "armageddon", "stage")
		assert(g3.white == g1.black, "armageddon White isn't game 1's Black")
		assert(g3.clock == T.ARMAGEDDON, "armageddon clock")
		assert(g3.clock.white == 300 and g3.clock.black == 240 and g3.clock.inc == 2, "armageddon times")

		ev = T.report(b, m.id, "draw")
		assert(ev.matchDone and m.done, "armageddon draw didn't finish the match")
		assert(m.winner == g3.black, "Black should win a drawn Armageddon")
		assert(#m.games == 3 and m.games[3].stage == "armageddon", "game log")
	end },
	{ "forfeit at the rematch stage: the other player wins", function()
		local b = bracketOf(8)
		local m = T.current(b)[1]
		T.report(b, m.id, "draw")
		assert(m.stage == "rematch", "not at rematch")
		local quitter, other = m.a.userId, m.b.userId
		local ev = T.report(b, m.id, { forfeit = quitter })
		assert(ev.matchDone and m.done, "forfeit didn't end the match")
		assert(m.winner == other, "winner is the quitter")
		assert(m.games[2].outcome == "forfeit" and m.games[2].stage == "rematch", "forfeit not logged")
		-- a stranger can't forfeit, and a finished match ignores reports
		assert(next(T.report(b, m.id, "white")) == nil, "report on a done match not ignored")
		local m2 = T.current(b)[1]
		assert(next(T.report(b, m2.id, { forfeit = 999999 })) == nil, "stranger forfeit not ignored")
		assert(next(T.report(b, "R9M9", "white")) == nil, "unknown match not ignored")
	end },
	{ "markAbsent: one absent advances the opponent; both absent leaves a bye behind", function()
		local b = bracketOf(8)
		local m1 = b.rounds[1][1]
		local m2 = b.rounds[1][2]
		local ev = T.markAbsent(b, m1.a.userId)
		assert(ev.matchDone and m1.done and m1.winner == m1.b.userId, "opponent didn't advance")
		assert(m1.absent[tostring(m1.a.userId)], "absence not stored")
		assert(next(T.markAbsent(b, 424242)) == nil, "unknown player not ignored")

		T.markAllAbsent(b, { m2.a.userId, m2.b.userId })
		assert(m2.done and m2.winner == false, "both absent should leave no winner")

		-- finish round 1, then check round 2's first match is a bye for m1's winner
		for _, m in T.current(b) do
			T.report(b, m.id, "white")
		end
		assert(b.round == 2, "round " .. b.round)
		local r2 = b.rounds[2][1]
		assert(r2.bye and r2.done, "round 2 match should be a bye")
		assert(r2.a.userId == m1.winner and r2.b == false, "wrong player on the bye")
		assert(r2.winner == m1.winner, "bye winner")
		assert(#T.current(b) == 1, "round 2 should have one real match left")
		assert(playAll(b) >= 1 and b.finished, "didn't finish")
		assert(b.champion ~= false, "champion missing")
	end },
	{ "both absent in the final: nobody wins", function()
		local b = bracketOf(2)
		local m = b.rounds[1][1]
		local ev = T.markAllAbsent(b, { m.a.userId, m.b.userId })
		assert(ev.finished and ev.champion == false, "events")
		assert(b.finished and b.champion == false, "champion should be false")
	end },
	{ "small brackets: 6, 2, 1 and 0 players", function()
		local b6 = bracketOf(6)
		assert(b6.size == 8 and #b6.rounds[1] == 4, "6 players: size")
		assert(byes(b6) == 2, "6 players: byes " .. byes(b6))
		assert(playAll(b6) == 5, "6 players: games")

		local b2 = bracketOf(2)
		assert(b2.size == 2 and #b2.rounds[1] == 1 and not b2.finished, "2 players")
		local m = T.current(b2)[1]
		local g = T.nextGame(m)
		local ev = T.report(b2, m.id, "black")
		assert(ev.finished and ev.matchDone and ev.roundDone, "final events")
		assert(b2.finished and b2.champion == g.black and ev.champion == g.black, "2 players: champion")
		assert(T.roundName(1, 2) == "Final", "final name")

		local b1 = bracketOf(1)
		assert(b1.finished and b1.champion == 101, "1 player")
		assert(#T.current(b1) == 0, "1 player: matches left")

		local b0 = bracketOf(0)
		assert(b0.finished and b0.champion == false, "0 players")
		assert(#T.current(b0) == 0 and #b0.rounds[1] == 0, "0 players: matches")
	end },
	{ "lookups: playerName, matchOf, name of a round", function()
		local b = bracketOf(8)
		assert(T.playerName(b, 103) == "P3", "playerName")
		assert(T.playerName(b, 5) == nil, "playerName for a stranger")
		local m = T.matchOf(b, 103)
		assert(m and (m.a.userId == 103 or m.b.userId == 103), "matchOf")
		T.report(b, m.id, "white")
		assert(T.matchOf(b, m.a.userId) == nil, "matchOf after the match is done")
		assert(T.matchOf(b, m.b.userId) == nil, "matchOf for the loser / winner while round 1 runs")
	end },
	{ "the bracket stays plain data (array xor string keys, no cycles)", function()
		local b = bracketOf(13, 7)
		local list = T.current(b)
		T.report(b, list[1].id, "draw")
		T.report(b, list[1].id, "draw")
		T.report(b, list[2].id, { forfeit = list[2].a.userId })
		T.report(b, list[3].id, "white")
		T.markAbsent(b, list[4].b.userId)
		checkPlain(b, {}, "bracket")
		playAll(b)
		checkPlain(b, {}, "bracket")
		checkPlain(bracketOf(0), {}, "empty")
		checkPlain(bracketOf(1), {}, "single")
	end },
}

function Tests.run()
	local out, fails = {}, 0
	for _, c in CASES do
		local ok, err = pcall(c[2])
		if not ok then
			fails += 1
		end
		table.insert(out, (if ok then "PASS " else "FAIL ") .. c[1] .. (if ok then "" else ": " .. tostring(err)))
	end
	return fails == 0, table.concat(out, "\n")
end

return Tests
