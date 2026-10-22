-- Bot tests (pure, Edit mode): require(<clone of Shared>.Tests.BotTests).run()

local Shared = script.Parent.Parent
local Board = require(Shared.Chess.Board)
local Game = require(Shared.Chess.Game)
local Notation = require(Shared.Chess.Notation)
local Search = require(Shared.Bot.Search)

local Tests = {}

local function uci(a)
	return Board.name(a.from) .. Board.name(a.to) .. (a.promotion or "")
end

local TACTICS = {
	{ name = "back-rank mate in 1", fen = "6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1", want = "a1a8", levels = { 2, 3, 4 } },
	{ name = "win the hanging queen", fen = "rnb1kbnr/pppp1ppp/8/4p1q1/3P4/2N5/PPP1PPPP/R1BQKBNR w KQkq - 0 1",
		want = "c1g5", levels = { 2, 3, 4 } },
	{ name = "promote", fen = "8/P6k/8/8/8/8/8/K7 w - - 0 1", want = "a7a8q", levels = { 3, 4 } },
	{ name = "escape mate threat (black)", fen = "6k1/5ppp/8/8/8/8/5PPP/R5K1 b - - 0 1", want = nil, levels = { 3, 4 },
		check = function(g, a) -- after black's move, white must not have Ra8#
			g:push({ from = a.from, to = a.to, promotion = a.promotion })
			local m = g:findMove(Board.parse("a1"), Board.parse("a8"))
			local mates = false
			if m then
				g:push(m)
				mates = #g:legalMoves() == 0 and g:inCheck()
				g:pop()
			end
			g:pop()
			return not mates
		end },
}

function Tests.run()
	local out, fails = {}, 0
	local rng = Random.new(1)
	for _, t in TACTICS do
		for _, lv in t.levels do
			local level = table.clone(Search.LEVELS[lv])
			level.blunder = 0 -- tactics tests check skill, not the random blunders
			local g = Game.new(t.fen)
			local a, info = Search.choose(g:clone(), level, { rng = rng })
			local ok = a ~= nil and (if t.check then t.check(g, a) else uci(a) == t.want)
			if not ok then
				fails += 1
			end
			table.insert(out, string.format("%s %s L%d: %s (d%s, %s nodes)", if ok then "PASS" else "FAIL", t.name, lv,
				a and uci(a) or "nil", tostring(info.depth), tostring(info.nodes)))
		end
	end
	-- the search must leave the game it searched exactly as it was
	local g = Game.new("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
	local before = g:fen()
	Search.choose(g, Search.LEVELS[4], { rng = rng, budget = 0.5 })
	local same = g:fen() == before and #g.stack == 0
	if not same then
		fails += 1
	end
	table.insert(out, (if same then "PASS" else "FAIL") .. " search leaves the position unchanged")
	return fails == 0, table.concat(out, "\n")
end

-- How deep the strong level gets in its time budget.
function Tests.speed()
	local out = {}
	for _, fen in { Notation.START, "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1" } do
		local g = Game.new(fen)
		local a, info = Search.choose(g, Search.LEVELS[4], { rng = Random.new(2) })
		table.insert(out, string.format("%s: %s depth %d, %d nodes, %.2fs (%.0f nodes/s)", string.sub(fen, 1, 20),
			uci(a), info.depth, info.nodes, info.time, info.nodes / info.time))
	end
	return table.concat(out, "\n")
end

return Tests
