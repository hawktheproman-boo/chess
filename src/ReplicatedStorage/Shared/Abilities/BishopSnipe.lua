-- Bishop Snipe (the user's ability, rules in vault Design/Abilities Mode):
--   any of your bishops, instead of a move, once per game per player;
--   pick one of its 4 diagonal directions; every ENEMY piece from the bishop to the edge is removed;
--   your own piece blocks the shot (it stops there); the enemy king is skipped (never hit).
--   Only directions that hit at least one piece are offered.
-- Action: { kind = "ability", id = "BishopSnipe", from = bishop square, dir = 17 | 15 | -15 | -17 }
-- Pure Luau.

local Chess = script.Parent.Parent.Chess
local Board = require(Chess.Board)
local Moves = require(Chess.Moves)

local band = bit32.band

local Snipe = {}

Snipe.id = "BishopSnipe"
Snipe.name = "Bishop Snipe"
Snipe.key = "snipe"
Snipe.DIRS = { 17, 15, -15, -17 } -- 0x88: NE, NW, SE, SW (from White's side)
Snipe.DIR_NAMES = { [17] = "NE", [15] = "NW", [-15] = "SE", [-17] = "SW" }

function Snipe.charges(game, color)
	local st = game.abilityState and game.abilityState[color]
	return if st then st.snipe or 0 else 0
end

-- squares of the enemy pieces this shot removes, nearest first
function Snipe.hits(game, from: number, dir: number)
	local sq = game.board.sq
	local me = sq[from] and sq[from].color
	local out = {}
	local s = from + dir
	while Board.onBoard(s) do
		local p = sq[s]
		if p then
			if p.color == me then
				break -- your own piece blocks the shot
			elseif p.type ~= "k" then
				table.insert(out, s) -- the enemy king is skipped
			end
		end
		s += dir
	end
	return out
end

-- every square the shot travels over (for targeting highlights and the tracer)
function Snipe.path(game, from: number, dir: number)
	local sq = game.board.sq
	local me = sq[from] and sq[from].color
	local out = {}
	local s = from + dir
	while Board.onBoard(s) do
		local p = sq[s]
		if p and p.color == me then
			break
		end
		table.insert(out, s)
		s += dir
	end
	return out
end

-- Apply without checks; pushes an undo record (with its own undo) onto game.stack.
function Snipe.apply(game, action)
	local color = game.turn
	local board = game.board
	local hits = Snipe.hits(game, action.from, action.dir)
	local rec = {
		move = action,
		castle = game.castle,
		ep = game.ep,
		halfmove = game.halfmove,
		fullmove = game.fullmove,
		removed = {},
	}
	local castle = game.castle
	for _, s in hits do
		table.insert(rec.removed, { sq = s, piece = board:remove(s) })
		castle = band(castle, Moves.KEEP[s]) -- a sniped corner rook loses its castling right
	end
	game.castle = castle
	game.abilityState[color].snipe -= 1
	game.ep = nil
	game.halfmove = 0
	if color == "b" then
		game.fullmove += 1
	end
	game.turn = Board.other(color)
	rec.undo = function(g)
		g.turn = color
		g.abilityState[color].snipe += 1
		for i = #rec.removed, 1, -1 do
			local r = rec.removed[i]
			g.board:place(r.sq, r.piece)
		end
		g.castle, g.ep, g.halfmove, g.fullmove = rec.castle, rec.ep, rec.halfmove, rec.fullmove
	end
	table.insert(game.stack, rec)
	return hits
end

-- legal snipe actions for the side to move
function Snipe.actions(game)
	local color = game.turn
	if Snipe.charges(game, color) < 1 then
		return {}
	end
	local enemy = Board.other(color)
	local out = {}
	for _, s in Board.squares do
		local p = game.board.sq[s]
		if p and p.color == color and p.type == "b" then
			for _, dir in Snipe.DIRS do
				if #Snipe.hits(game, s, dir) > 0 then
					local a = { kind = "ability", id = Snipe.id, from = s, dir = dir }
					Snipe.apply(game, a)
					local k = game.board.kings[color]
					local legal = k == nil or not Moves.isAttacked(game.board, k, enemy)
					game:pop()
					if legal then
						table.insert(out, a)
					end
				end
			end
		end
	end
	return out
end

-- move-list text, e.g. "Bc4 snipe NE x2" (+ / # added by the mode)
function Snipe.describe(game, action, hits)
	return "B" .. Board.name(action.from) .. " snipe " .. Snipe.DIR_NAMES[action.dir] .. " x" .. #hits
end

-- move ordering hint for the bot: value of what it removes
function Snipe.score(game, action, values)
	local total = 0
	for _, s in Snipe.hits(game, action.from, action.dir) do
		total += values[game.board.sq[s].type] or 0
	end
	return total
end

return Snipe
