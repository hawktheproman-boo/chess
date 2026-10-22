-- Steal a Piece tests (pure, Edit mode): require(<clone of Shared>.Tests.StealTests).run()

local Shared = script.Parent.Parent
local Board = require(Shared.Chess.Board)
local Game = require(Shared.Chess.Game)
local Classic = require(Shared.Modes.Classic)
local Abilities = require(Shared.Modes.Abilities)
local Steal = require(Shared.Abilities.StealPiece)
local Tests = {}

local function sq(n)
	return Board.parse(n) :: number
end

local function steal(from)
	return { kind = "ability", id = "StealPiece", from = sq(from) }
end

local function froms(g)
	local out = {}
	for _, a in Steal.actions(g) do
		table.insert(out, Board.name(a.from))
	end
	table.sort(out)
	return table.concat(out, " ")
end

local CASES = {
	{ "no steal without a grant (Classic stays plain chess)", function()
		local g = Game.new(nil, Classic)
		assert(#g:legalActions() == 20, "start position actions: " .. #g:legalActions())
		assert(not g:apply(steal("b8")), "stole without a grant")
	end },
	{ "a granted steal takes any piece but the king and queen", function()
		local g = Game.new(nil, Classic)
		Steal.grant(g, { w = true })
		local list = froms(g)
		assert(not string.find(list, "d8") and not string.find(list, "e8"), "king / queen offered: " .. list)
		assert(#Steal.actions(g) == 14, "targets: " .. list)
		assert(g:apply(steal("g8")))
		local p = g.board.sq[sq("g8")]
		assert(p and p.color == "w" and p.type == "n", "g8 isn't a white knight")
		assert(g.history[1].san == "Steal Ng8", g.history[1].san)
		assert(Steal.charges(g, "w") == 0, "charge not spent")
		assert(#Steal.actions(g) == 0, "black has no steal")
	end },
	{ "once per game, and undo gives it back", function()
		local g = Game.new(nil, Classic)
		Steal.grant(g, { w = true, b = true })
		local fen = g:fen()
		assert(g:apply(steal("a8")))
		assert(g:apply(steal("a1")), "black's own steal")
		assert(g:apply({ kind = "move", from = sq("e2"), to = sq("e4") }))
		assert(g:apply({ kind = "move", from = sq("e7"), to = sq("e5") }))
		assert(not g:apply(steal("b8")), "white stole twice")
		g:undo()
		g:undo()
		g:undo()
		g:undo()
		assert(g:fen() == fen, "undo: " .. g:fen())
		assert(Steal.charges(g, "w") == 1, "charge not back")
		assert(g.board.sq[sq("a8")].color == "b", "a8 not back to black")
	end },
	{ "stealing the checker gets out of check; never into check", function()
		-- white king e1 in check from a black rook e8; white steals it
		local g = Game.new("4r2k/8/8/8/8/8/8/R3K3 w Q - 0 1", Classic)
		Steal.grant(g, { w = true })
		assert(g:apply(steal("e8")), "couldn't steal the checker")
		-- in check from a queen (which can't be stolen): no steal helps, so none is offered
		local h = Game.new("4k3/8/8/8/8/8/3n4/4K2q w - - 0 1", Classic)
		Steal.grant(h, { w = true })
		assert(froms(h) == "", "steals offered in check: " .. froms(h))
	end },
	{ "a steal can't be the way out when there's no grant: mate stays mate", function()
		local h = Game.new("6rk/6pp/7N/8/8/8/8/6K1 w - - 0 1", Classic)
		assert(h:apply({ kind = "move", from = sq("h6"), to = sq("f7") }))
		assert(h.result and h.result.reason == "checkmate", "smothered mate missing")
	end },
	{ "with a steal, the smothered king takes the knight over instead", function()
		local h = Game.new("6rk/6pp/7N/8/8/8/8/6K1 w - - 0 1", Classic)
		Steal.grant(h, { b = true })
		assert(h:apply({ kind = "move", from = sq("h6"), to = sq("f7") }))
		assert(h.result == nil, "mate despite a steal")
		assert(h:apply(steal("f7")))
	end },
	{ "works in Abilities mode beside the five", function()
		local g = Game.new(nil, Abilities)
		local before = Abilities.stateKey(g)
		Steal.grant(g, { w = true })
		assert(Abilities.stateKey(g) == before, "steal is in the position key")
		assert(g:apply(steal("b8")))
		assert(Abilities.chargesLeft(g, "w") == #Abilities.list, "the others changed")
	end },
	{ "replays grant the steal to whoever used it", function()
		local g = Game.new(nil, Classic)
		Steal.grant(g, { b = true })
		local actions = {
			{ kind = "move", from = sq("e2"), to = sq("e4") },
			steal("g1"),
		}
		for _, a in actions do
			assert(g:apply(a))
		end
		local r = Game.forReplay(nil, Classic, actions)
		for _, a in actions do
			assert(r:apply(a), "replay failed")
		end
		assert(r:fen() == g:fen(), "replay differs")
		assert(Steal.charges(Game.forReplay(nil, Classic, actions), "w") == 0, "white got a steal")
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
