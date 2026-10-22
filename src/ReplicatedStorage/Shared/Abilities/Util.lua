-- Shared plumbing for the piece abilities (not an ability itself). Every ability is once per game
-- per player: game.abilityState[color][key] counts what's left. An ability that moves pieces saves
-- the squares it touches and restores them on undo, so one undo works for all of them.
-- Pure Luau.

local Chess = script.Parent.Parent.Chess
local Board = require(Chess.Board)
local Moves = require(Chess.Moves)

local band = bit32.band

local Util = {}

function Util.charges(game, color: string, key: string): number
	local st = game.abilityState and game.abilityState[color]
	return if st then st[key] or 0 else 0
end

-- Start an undo record: remembers the given squares (their pieces and moved flags) and the rights.
function Util.begin(game, action, squares: { number })
	local rec = {
		move = action,
		castle = game.castle,
		ep = game.ep,
		halfmove = game.halfmove,
		fullmove = game.fullmove,
		saved = {},
	}
	for _, s in squares do
		if rec.saved[s] == nil then
			local p = game.board.sq[s]
			rec.saved[s] = { piece = p or false, moved = p and p.moved }
		end
	end
	return rec
end

-- Finish an ability: castling rights for every touched square, the 50-move counter (reset when
-- something was captured or a pawn moved), the charge, the turn; then push the record.
function Util.finish(game, rec, color: string, key: string, reset: boolean)
	local castle = game.castle
	for s in rec.saved do
		castle = band(castle, Moves.KEEP[s])
	end
	game.castle = castle
	game.ep = nil
	game.halfmove = if reset then 0 else game.halfmove + 1
	if color == "b" then
		game.fullmove += 1
	end
	game.abilityState[color][key] -= 1
	game.turn = Board.other(color)
	rec.undo = function(g)
		g.turn = color
		g.abilityState[color][key] += 1
		for s in rec.saved do
			g.board:remove(s)
		end
		for s, e in rec.saved do
			if e.piece then
				e.piece.moved = e.moved
				g.board:place(s, e.piece)
			end
		end
		g.castle, g.ep, g.halfmove, g.fullmove = rec.castle, rec.ep, rec.halfmove, rec.fullmove
	end
	table.insert(game.stack, rec)
end

-- move the piece on `from` to `to` (whatever is on `to` must already be gone)
function Util.shift(game, from: number, to: number)
	if from == to then
		return
	end
	local p = game.board:remove(from)
	if p then
		p.moved = true
		game.board:place(to, p)
	end
end

-- Is this ability action legal: after it, the mover's king isn't attacked?
function Util.legal(game, ability, action): boolean
	local color = game.turn
	ability.apply(game, action)
	local k = game.board.kings[color]
	local ok = k == nil or not Moves.isAttacked(game.board, k, Board.other(color))
	game:pop()
	return ok
end

-- the squares of the side to move's pieces of one type
function Util.piecesOf(game, pieceType: string)
	local out = {}
	local color = game.turn
	for s, p in game.board.sq do
		if p.color == color and p.type == pieceType then
			table.insert(out, s)
		end
	end
	table.sort(out) -- (pairs order isn't stable; keeps action lists deterministic)
	return out
end

-- material value of the enemy pieces on these squares (bot move ordering)
function Util.value(game, squares, values): number
	local total = 0
	for _, s in squares do
		local p = game.board.sq[s]
		if p then
			total += values[p.type] or 0
		end
	end
	return total
end

return Util
