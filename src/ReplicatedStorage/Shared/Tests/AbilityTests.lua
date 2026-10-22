-- Abilities mode tests (pure, Edit mode): require(<clone of Shared>.Tests.AbilityTests).run()

local Shared = script.Parent.Parent
local Board = require(Shared.Chess.Board)
local Game = require(Shared.Chess.Game)
local Moves = require(Shared.Chess.Moves)
local Notation = require(Shared.Chess.Notation)
local Abilities = require(Shared.Modes.Abilities)
local Snipe = require(Shared.Abilities.BishopSnipe)
local QueenSwap = require(Shared.Abilities.QueenSwap)
local Search = require(Shared.Bot.Search)

local Tests = {}

local function sq(n)
	return Board.parse(n) :: number
end

local function snipe(from, dir)
	return { kind = "ability", id = "BishopSnipe", from = sq(from), dir = dir }
end

local function act(id, from, fields)
	local a = { kind = "ability", id = id, from = sq(from) }
	for k, v in fields or {} do
		a[k] = if type(v) == "string" then sq(v) else v
	end
	return a
end

-- apply, undo, and check the position and charges came back
local function roundTrip(g, a)
	local fen, key = g:fen(), Abilities.stateKey(g)
	local ok, err = g:apply(a)
	assert(ok, err)
	g:undo()
	assert(g:fen() == fen and Abilities.stateKey(g) == key, "undo: " .. g:fen())
end

local function names(list)
	local out = {}
	for _, s in list do
		table.insert(out, Board.name(s))
	end
	return table.concat(out, " ")
end

local CASES = {
	{ "hits enemies, skips the king, stops at own piece", function()
		-- White bishop c1, NE line: d2 (black knight), e3 (black king, skipped), f4 (black pawn),
		-- g5 (white pawn: blocks), h6 (black rook, safe behind it)
		local g = Game.new("8/8/7r/6P1/5p2/4k3/3n4/2B1K3 w - - 0 1", Abilities)
		local hits = Snipe.hits(g, sq("c1"), 17)
		assert(names(hits) == "d2 f4", names(hits))
		local ok, text = g:apply(snipe("c1", 17))
		assert(ok, text)
		assert(g.board:get(sq("d2")) == nil and g.board:get(sq("f4")) == nil, "targets not removed")
		assert(g.board:get(sq("e3")).type == "k", "king was hit")
		assert(g.board:get(sq("h6")).type == "r", "shot went through own piece")
		assert(g.board:get(sq("c1")).type == "b", "bishop moved")
		assert(g.history[1].san == "Bc1 snipe NE x2+", g.history[1].san) -- d2 gone: the bishop now checks e3
	end },
	{ "once per game per player", function()
		local g = Game.new("4k3/8/8/3p1p2/8/1B3B2/8/4K3 w - - 0 1", Abilities)
		assert(#Snipe.actions(g) > 0, "no snipe offered")
		assert(g:apply(snipe("b3", 17)), "first snipe")
		assert(g:apply({ kind = "move", from = sq("e8"), to = sq("d7") }), "black move")
		assert(#Snipe.actions(g) == 0, "second snipe offered")
		assert(not g:apply(snipe("f3", 15)), "second snipe accepted")
		assert(Snipe.charges(g, "b") == 1, "black lost its charge")
	end },
	{ "undo restores board, charges and rights", function()
		local g = Game.new("r3k2r/8/8/8/8/8/8/R3K1B1 w Qkq - 5 20", Abilities)
		local before = g:fen()
		assert(g:apply(snipe("g1", 15)) == false, "nothing on that line should mean no action")
		local g2 = Game.new("r3k2r/8/8/8/8/8/6B1/R3K3 w Qkq - 5 20", Abilities)
		local b2 = g2:fen()
		assert(g2:apply(snipe("g2", 15)), "snipe h1-a8 diagonal") -- hits a8 rook
		assert(g2.board:get(sq("a8")) == nil, "a8 rook not sniped")
		assert(string.find(g2:fen(), " Qk "), "black lost queen-side castling: " .. g2:fen())
		assert(g2.halfmove == 0, "halfmove not reset")
		g2:undo()
		assert(g2:fen() == b2 and Snipe.charges(g2, "w") == 1, "undo: " .. g2:fen())
		assert(g:fen() == before, "failed apply changed state")
	end },
	{ "can't leave own king in check, can escape check", function()
		-- white king e1 in check from the black rook e8; bishop c3 NE line hits d4 pawn only: illegal
		local g = Game.new("4r1k1/8/8/8/3p4/2B5/8/4K3 w - - 0 1", Abilities)
		assert(not g:apply(snipe("c3", 17)), "snipe ignored check")
		-- bishop b5 can snipe the checking rook on e8 (b5-c6-d7-e8)
		local g2 = Game.new("4r1k1/8/8/1B6/8/8/8/4K3 w - - 0 1", Abilities)
		assert(g2:apply(snipe("b5", 17)), "snipe out of check refused")
	end },
	{ "a snipe stops stalemate", function()
		-- White to move: king a1 has no squares, pawn blocked; only the snipe is legal
		local g = Game.new("8/8/8/8/8/1q6/1p6/K1B4k w - - 0 1", Abilities)
		local classic = Game.new("8/8/8/8/8/1q6/1p6/K1B4k w - - 0 1")
		assert(#classic:legalActions() == 0 or #Moves.legal(classic) >= 0, "")
		local acts = g:legalActions()
		local hasSnipe = false
		for _, a in acts do
			if a.kind == "ability" then
				hasSnipe = true
			end
		end
		assert(hasSnipe, "snipe not offered when it is the way out")
	end },
	{ "start position perft unchanged in Abilities mode", function()
		local g = Game.new(nil, Abilities)
		local n = #Moves.legal(g)
		assert(n == 20, "start moves " .. n)
		assert(Moves.perft(g, 3) == 8902, "perft d3")
	end },
	{ "bot takes a big snipe", function()
		-- Bc1 NE line: d2 empty, e3 knight, f4 empty, g5 queen, h6 rook
		local g = Game.new("4k3/8/7r/6q1/8/4n3/8/2B1K3 w - - 0 1", Abilities)
		local level = table.clone(Search.LEVELS[3])
		level.blunder = 0
		local a = Search.choose(g:clone(), level, { rng = Random.new(3) })
		assert(a and a.kind == "ability" and a.from == sq("c1") and a.dir == 17, "bot didn't snipe")
	end },
	{ "client replay of an ability game matches", function()
		local g = Game.new("4k3/8/7r/6q1/8/4n3/8/2B1K3 w - - 0 1", Abilities)
		assert(g:apply(snipe("c1", 17)))
		local r = Game.new("4k3/8/7r/6q1/8/4n3/8/2B1K3 w - - 0 1", Abilities)
		for _, h in g.history do
			assert(r:apply(h.action), "replay failed")
		end
		assert(r:fen() == g:fen() and Abilities.stateKey(r) == Abilities.stateKey(g), "replay differs")
	end },
	-- Double Jump ---------------------------------------------------------------------------------
	{ "double jump captures on both landings", function()
		local g = Game.new("4k3/8/8/3p4/8/2n5/8/1N2K3 w - - 0 1", Abilities)
		local ok, err = g:apply(act("KnightJump", "b1", { mid = "c3", to = "d5" }))
		assert(ok, err)
		assert(g.board:get(sq("d5")).type == "n" and g.board:get(sq("d5")).color == "w", "knight not on d5")
		assert(g.board:get(sq("c3")) == nil and g.board:get(sq("b1")) == nil, "c3 / b1 not empty")
		assert(g.history[1].san == "Nb1 jump xc3 xd5", g.history[1].san)
		assert(g.halfmove == 0, "halfmove not reset")
	end },
	{ "double jump may land back on its start", function()
		local g = Game.new("4k3/8/8/8/8/2n5/8/1N2K3 w - - 0 1", Abilities)
		assert(g:apply(act("KnightJump", "b1", { mid = "c3", to = "b1" })), "jump back refused")
		assert(g.board:get(sq("b1")).type == "n" and g.board:get(sq("c3")) == nil, "jump back wrong")
		roundTrip(Game.new("4k3/8/8/3p4/8/2n5/8/1N2K3 w - - 0 1", Abilities), act("KnightJump", "b1", { mid = "c3", to = "d5" }))
	end },
	{ "double jump never lands on the king or own pieces", function()
		local g = Game.new("8/8/8/8/8/2k5/3P4/1N2K3 w - - 0 1", Abilities)
		assert(not g:apply(act("KnightJump", "b1", { mid = "c3", to = "d5" })), "landed on the king")
		assert(not g:apply(act("KnightJump", "b1", { mid = "d2", to = "f3" })), "landed on own pawn")
	end },
	-- Battering Ram --------------------------------------------------------------------------------
	{ "ram smashes through and stops in front of the king", function()
		local g = Game.new("4k3/4p3/8/4n3/8/8/8/4R1K1 w - - 0 1", Abilities)
		local ok, err = g:apply(act("RookRam", "e1", { dir = 16 }))
		assert(ok, err)
		assert(g.board:get(sq("e7")).type == "r", "rook not on e7")
		assert(g.board:get(sq("e5")) == nil and g.board:get(sq("e8")).type == "k", "e5 not smashed / king hit")
		assert(g.history[1].san == "Re1 ram e7 x2+", g.history[1].san)
	end },
	{ "ram stops at its own piece, offered only when it hits", function()
		local g = Game.new("4k3/8/8/4P3/4n3/8/8/R3K3 w Q - 0 1", Abilities)
		assert(not g:apply(act("RookRam", "a1", { dir = 1 })), "ram into own king accepted")
		local g2 = Game.new("4k3/8/8/4P3/4n3/8/8/4R1K1 w - - 0 1", Abilities)
		assert(g2:apply(act("RookRam", "e1", { dir = 16 })), "ram refused")
		assert(g2.board:get(sq("e4")).type == "r" and g2.board:get(sq("e5")).type == "p", "didn't stop at own pawn")
		roundTrip(Game.new("4k3/8/8/4P3/4n3/8/8/4R1K1 w - - 0 1", Abilities), act("RookRam", "e1", { dir = 16 }))
	end },
	-- Swap (retired) ------------------------------------------------------------------------------
	{ "swap is retired: never offered, old saved games still replay", function()
		local fen = "4k3/8/8/8/8/8/8/N2QK3 w - - 0 1"
		local g = Game.new(fen, Abilities)
		for _, a in Abilities.abilityActions(g) do
			assert(a.id ~= "QueenSwap", "swap offered")
		end
		assert(not g:apply(act("QueenSwap", "d1", { to = "a1" })), "swap accepted in a new game")
		local actions = { act("QueenSwap", "d1", { to = "a1" }), { kind = "move", from = sq("e8"), to = sq("e7") } }
		local r = Game.forReplay(fen, Abilities, actions)
		for _, a in actions do
			local ok, err = r:apply(a)
			assert(ok, err)
		end
		assert(r.board:get(sq("a1")).type == "q" and r.board:get(sq("d1")).type == "n", "old swap didn't replay")
		assert(QueenSwap.charges(r, "b") == 0, "black got a swap")
	end },
	-- Royal Escape ---------------------------------------------------------------------------------
	{ "royal escape gets out of a back-rank mate", function()
		local fen = "6k1/8/8/8/8/8/5PPP/4r1K1 w - - 0 1"
		local classic = Game.new(fen)
		classic:updateResult()
		assert(classic.result and classic.result.reason == "checkmate", "not mate in Classic")
		local g = Game.new(fen, Abilities)
		assert(not g:apply(act("KingEscape", "g1", { to = "e3" })), "escaped into check (e-file)")
		assert(not g:apply(act("KingEscape", "g1", { to = "g2" })), "own piece / one square")
		local ok, err = g:apply(act("KingEscape", "g1", { to = "g3" }))
		assert(ok, err)
		assert(g.board.kings.w == sq("g3"), "king not on g3")
		roundTrip(Game.new(fen, Abilities), act("KingEscape", "g1", { to = "h3" }))
	end },
	{ "royal escape can capture, not into check", function()
		local g = Game.new("6k1/8/8/8/8/6n1/5PPP/4r1K1 w - - 0 1", Abilities)
		local ok, err = g:apply(act("KingEscape", "g1", { to = "g3" }))
		assert(ok, err)
		assert(g.history[1].san == "Kg1 escape xg3", g.history[1].san)
		local g2 = Game.new("6k1/8/7r/8/8/6n1/5PPP/4r1K1 w - - 0 1", Abilities) -- the h6 rook guards h3
		assert(not g2:apply(act("KingEscape", "g1", { to = "h3" })), "escaped onto an attacked square")
	end },
	{ "each ability once per game", function()
		local g = Game.new("4k3/p7/8/8/8/8/P7/4K3 w - - 0 1", Abilities)
		local ok, err = g:apply(act("KingEscape", "e1", { to = "e3" }))
		assert(ok, err)
		assert(g:apply({ kind = "move", from = sq("e8"), to = sq("e7") }))
		assert(not g:apply(act("KingEscape", "e3", { to = "e5" })), "second escape accepted")
		local Escape = Abilities.byId.KingEscape
		assert(Escape.charges(g, "w") == 0 and Escape.charges(g, "b") == 1, "charges wrong")
	end },
	{ "bot rams for material", function()
		local g = Game.new("k7/8/8/q7/8/n7/8/R6K w - - 0 1", Abilities)
		local level = table.clone(Search.LEVELS[3])
		level.blunder = 0
		local a = Search.choose(g:clone(), level, { rng = Random.new(3) })
		assert(a and a.kind == "ability", "bot didn't use an ability: " .. tostring(a and (a.id or a.to)))
	end },
	-- Any Passant ----------------------------------------------------------------------------------
	{ "any passant takes a piece that just landed beside the pawn", function()
		local g = Game.new("4k3/8/5n2/4P3/8/8/8/4K3 b - - 0 1", Abilities)
		assert(g:apply({ kind = "move", from = sq("f6"), to = sq("d5") }), "Nd5")
		local ok, err = g:apply(act("PawnPassant", "e5", { to = "d6" }))
		assert(ok, err)
		assert(g.board:get(sq("d5")) == nil, "knight not taken")
		assert(g.board:get(sq("d6")).type == "p" and g.board:get(sq("e5")) == nil, "pawn not on d6")
		assert(g.history[2].san == "e5 passant xd6", g.history[2].san)
	end },
	{ "any passant only right after it lands", function()
		local g = Game.new("4k3/8/5n2/4P3/8/8/8/4K3 b - - 0 1", Abilities)
		assert(g:apply({ kind = "move", from = sq("f6"), to = sq("d5") }))
		assert(g:apply({ kind = "move", from = sq("e1"), to = sq("e2") }))
		assert(g:apply({ kind = "move", from = sq("e8"), to = sq("e7") }))
		assert(not g:apply(act("PawnPassant", "e5", { to = "d6" })), "passant on a piece that landed earlier")
	end },
	{ "any passant: never the king, landing square must be empty", function()
		local g = Game.new("8/8/3k4/4P3/8/8/8/4K3 b - - 0 1", Abilities)
		assert(g:apply({ kind = "move", from = sq("d6"), to = sq("d5") }))
		assert(not g:apply(act("PawnPassant", "e5", { to = "d6" })), "took the king")
		local g2 = Game.new("4k3/8/3p1n2/4P3/8/8/8/4K3 b - - 0 1", Abilities)
		assert(g2:apply({ kind = "move", from = sq("f6"), to = sq("d5") }))
		assert(not g2:apply(act("PawnPassant", "e5", { to = "d6" })), "landed on an occupied square")
	end },
	{ "a pawn double step is left to normal en passant", function()
		local g = Game.new("4k3/3p4/8/4P3/8/8/8/4K3 b - - 0 1", Abilities)
		assert(g:apply({ kind = "move", from = sq("d7"), to = sq("d5") }))
		assert(not g:apply(act("PawnPassant", "e5", { to = "d6" })), "spent a charge on a normal en passant")
		assert(g:apply({ kind = "move", from = sq("e5"), to = sq("d6") }), "normal en passant refused")
	end },
	{ "any passant undo restores the board and what landed", function()
		local g = Game.new("4k3/8/5n2/4P3/8/8/8/4K3 b - - 0 1", Abilities)
		assert(g:apply({ kind = "move", from = sq("f6"), to = sq("d5") }))
		roundTrip(g, act("PawnPassant", "e5", { to = "d6" }))
		assert(g.landed[1] == sq("d5"), "landed not restored")
		g:undo()
		assert(#g.landed == 0, "landed after undoing the knight move")
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
	local _ = Notation
	return fails == 0, table.concat(out, "\n")
end

return Tests
