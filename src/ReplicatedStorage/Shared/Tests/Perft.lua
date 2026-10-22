-- Perft and rules tests for Shared/Chess. Run from Studio (execute_luau, Edit):
--   require(game.ReplicatedStorage.Shared.Tests.Perft).perft(1, 4)   -- position 1 to depth 4
--   require(game.ReplicatedStorage.Shared.Tests.Perft).rules()
-- Perft numbers: Chess Programming Wiki, "Perft Results".

local Chess = script.Parent.Parent.Chess
local Board = require(Chess.Board)
local Game = require(Chess.Game)
local Moves = require(Chess.Moves)
local Notation = require(Chess.Notation)

local Tests = {}

Tests.POSITIONS = {
	{ name = "start", fen = Notation.START, counts = { 20, 400, 8902, 197281 } },
	{ name = "kiwipete", fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
		counts = { 48, 2039, 97862 } },
	{ name = "pos3", fen = "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", counts = { 14, 191, 2812, 43238 } },
	{ name = "pos4", fen = "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
		counts = { 6, 264, 9467 } },
	{ name = "pos5", fen = "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", counts = { 44, 1486, 62379 } },
	{ name = "pos6", fen = "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10",
		counts = { 46, 2079, 89890 } },
}

-- Runs one position up to maxDepth; returns ok and a report line per depth.
function Tests.perft(index: number, maxDepth: number?)
	local pos = Tests.POSITIONS[index]
	local g = Game.new(pos.fen)
	local out, allOk = {}, true
	for depth = 1, math.min(maxDepth or #pos.counts, #pos.counts) do
		local t = os.clock()
		local n = Moves.perft(g, depth)
		local ok = n == pos.counts[depth]
		allOk = allOk and ok
		table.insert(out, string.format("%s %s d%d: %d (want %d) %.2fs", if ok then "PASS" else "FAIL",
			pos.name, depth, n, pos.counts[depth], os.clock() - t))
	end
	if Notation.toFEN(g) ~= pos.fen then
		allOk = false
		table.insert(out, "FAIL " .. pos.name .. ": state changed after perft: " .. Notation.toFEN(g))
	end
	return allOk, table.concat(out, "\n")
end

function Tests.divide(index: number, depth: number)
	local g = Game.new(Tests.POSITIONS[index].fen)
	local lines = {}
	for mv, n in Moves.divide(g, depth) do
		table.insert(lines, mv .. ": " .. n)
	end
	table.sort(lines)
	return table.concat(lines, "\n")
end

local function play(g, list)
	for _, text in list do
		local m = Notation.parseMove(g, text)
		assert(m, "could not parse " .. text .. " in " .. g:fen())
		local ok, err = g:apply({ kind = "move", from = m.from, to = m.to, promotion = m.promotion })
		assert(ok, text .. ": " .. tostring(err))
	end
end

local function sq(name)
	return Board.parse(name) :: number
end

Tests.CASES = {
	{ "scholar's mate", function()
		local g = Game.new()
		play(g, { "e4", "e5", "Bc4", "Nc6", "Qh5", "Nf6", "Qxf7#" })
		assert(g.result and g.result.winner == "w" and g.result.reason == "checkmate", "no mate")
		assert(g:moveList() == "1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7#", g:moveList())
	end },
	{ "undo back to start", function()
		local g = Game.new()
		play(g, { "e4", "d5", "exd5", "Qxd5", "Nc3", "Qa5", "d4", "c6", "Nf3", "Bg4", "Bf4", "e6", "h3", "Bxf3",
			"Qxf3", "Bb4", "Be2", "Nd7", "a3", "O-O-O" })
		while g:undo() do end
		assert(g:fen() == Notation.START, g:fen())
	end },
	{ "stalemate", function()
		local g = Game.new("k7/8/8/2Q5/8/8/8/7K w - - 0 1")
		play(g, { "Qb6" })
		assert(g.result and g.result.reason == "stalemate", "no stalemate")
	end },
	{ "threefold repetition", function()
		local g = Game.new()
		play(g, { "Nf3", "Nf6", "Ng1", "Ng8", "Nf3", "Nf6", "Ng1" })
		assert(not g.result, "ended early")
		play(g, { "Ng8" })
		assert(g.result and g.result.reason == "repetition", "no repetition draw")
	end },
	{ "fifty-move rule", function()
		local g = Game.new("k7/8/8/8/8/8/8/K6R w - - 99 80")
		play(g, { "Rh2" })
		assert(g.result and g.result.reason == "fifty-move rule", "no fifty-move draw")
	end },
	{ "insufficient material", function()
		local g = Game.new("k7/8/8/8/8/8/1n6/K7 w - - 0 1")
		play(g, { "Kxb2" })
		assert(g.result and g.result.reason == "insufficient material", "no draw")
		assert(Game.new("k7/8/8/8/8/8/3b4/KB6 w - - 0 1"):insufficientMaterial() == false, "opposite bishops")
		assert(Game.new("k7/8/8/8/8/8/b7/KB6 w - - 0 1"):insufficientMaterial() == true, "same-colour bishops")
	end },
	{ "en passant pin refused", function()
		local g = Game.new("8/8/8/K2Pp2r/8/8/8/7k w - e6 0 1")
		assert(g:findMove(sq("d5"), sq("e6")) == nil, "pinned en passant allowed")
		local g2 = Game.new("8/8/8/3Pp3/8/8/8/K6k w - e6 0 1")
		assert(g2:findMove(sq("d5"), sq("e6")) ~= nil, "en passant missing")
		play(g2, { "dxe6" })
		assert(g2.board:get(sq("e5")) == nil, "captured pawn still there")
	end },
	{ "castling SAN and rules", function()
		local g = Game.new("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
		play(g, { "O-O" })
		assert(g.board:get(sq("f1")).type == "r" and g.board:get(sq("g1")).type == "k", "castle placement")
		assert(g:fen() == "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R4RK1 b kq - 1 1", g:fen())
		-- can't castle through an attacked square (f1 is hit by the bishop on c4)
		local g2 = Game.new("4k3/8/8/8/2b5/8/8/4K2R w K - 0 1")
		assert(g2:findMove(sq("e1"), sq("g1")) == nil, "castled through check")
	end },
	{ "promotion", function()
		local g = Game.new("8/P7/8/8/8/8/8/k6K w - - 0 1")
		local m = Notation.parseMove(g, "a8=Q+")
		assert(m and m.promotion == "q", "no promo parse")
		assert(Notation.san(g, m) == "a8=Q+", Notation.san(g, m))
		assert(#g:legalMoves(sq("a7")) == 4, "want 4 promotion choices")
		play(g, { "a8=N" })
		assert(g.board:get(sq("a8")).type == "n", "underpromotion")
		g:undo()
		assert(g.board:get(sq("a7")).type == "p", "promotion undo")
	end },
	{ "SAN disambiguation", function()
		local g = Game.new("k7/8/8/8/8/8/8/KN3N2 w - - 0 1")
		local m = g:findMove(sq("b1"), sq("d2"))
		assert(Notation.san(g, m) == "Nbd2", Notation.san(g, m))
		local g2 = Game.new("7k/8/8/8/R7/8/8/R6K w - - 0 1")
		local m2 = g2:findMove(sq("a1"), sq("a2"))
		assert(Notation.san(g2, m2) == "R1a2", Notation.san(g2, m2))
	end },
	{ "FEN round trip", function()
		for _, pos in Tests.POSITIONS do
			assert(Game.new(pos.fen):fen() == pos.fen, pos.name)
		end
	end },
	{ "illegal moves rejected", function()
		local g = Game.new()
		assert(not g:apply({ kind = "move", from = sq("e2"), to = sq("e5") }), "e2e5")
		assert(not g:apply({ kind = "move", from = sq("e7"), to = sq("e5") }), "moved black on white's turn")
		assert(not g:apply({ kind = "move", from = sq("g1"), to = sq("g3") }), "knight g3")
		assert(not g:apply({ kind = "warp" }), "unknown action")
	end },
	{ "timeout vs bare king is a draw", function()
		local g = Game.new("k7/8/8/8/8/8/8/K6R w - - 0 1")
		g:timeout("b")
		assert(g.result.winner == "w", "white has mating material")
		local g2 = Game.new("k7/8/8/8/8/8/8/K6R w - - 0 1")
		g2:timeout("w")
		assert(g2.result.winner == "b" or g2.result.winner == nil, "bad timeout result")
		assert(g2.result.winner == nil, "black has a bare king, so white flagging is a draw")
	end },
}

function Tests.rules()
	local out, fails = {}, 0
	for _, case in Tests.CASES do
		local ok, err = pcall(case[2])
		if not ok then
			fails += 1
		end
		table.insert(out, (if ok then "PASS " else "FAIL ") .. case[1] .. (if ok then "" else ": " .. tostring(err)))
	end
	return fails == 0, table.concat(out, "\n")
end

return Tests
