-- Battering Ram (picked by the user, rules in vault Design/Abilities Mode):
--   any of your rooks, instead of a move, once per game per player;
--   pick one of its 4 straight directions; the rook charges down the line, removing every ENEMY
--   piece, until it reaches your own piece, the enemy king (it stops in front of it) or the edge,
--   and ends on the last square it reached. Only directions that hit at least one piece are offered.
-- Action: { kind = "ability", id = "RookRam", from = rook square, dir = 16 | -16 | 1 | -1 }
-- Pure Luau.

local Chess = script.Parent.Parent.Chess
local Board = require(Chess.Board)
local Util = require(script.Parent.Util)

local Ram = {}

Ram.id = "RookRam"
Ram.name = "Battering Ram"
Ram.key = "ram"
Ram.piece = "r"
Ram.DIRS = { 16, -16, 1, -1 } -- 0x88: up, down, right, left (from White's side)
Ram.DIR_NAMES = { [16] = "up", [-16] = "down", [1] = "right", [-1] = "left" }

function Ram.charges(game, color)
	return Util.charges(game, color, Ram.key)
end

-- the charge: { path = squares it travels over, hits = enemy squares it smashes, land = where it
-- stops (nil if it can't move at all) }
function Ram.trace(game, from: number, dir: number)
	local sq = game.board.sq
	local me = sq[from] and sq[from].color
	local path, hits, land = {}, {}, nil
	local s = from + dir
	while Board.onBoard(s) do
		local p = sq[s]
		if p and (p.color == me or p.type == "k") then
			break -- your own piece, or the enemy king: it stops in front
		end
		if p then
			table.insert(hits, s)
		end
		table.insert(path, s)
		land = s
		s += dir
	end
	return { path = path, hits = hits, land = land }
end

function Ram.hits(game, from, dir)
	return Ram.trace(game, from, dir).hits
end

function Ram.apply(game, action)
	local color = game.turn
	local t = Ram.trace(game, action.from, action.dir)
	local touched = { action.from }
	for _, s in t.hits do
		table.insert(touched, s)
	end
	table.insert(touched, t.land)
	local rec = Util.begin(game, action, touched)
	for _, s in t.hits do
		game.board:remove(s)
	end
	Util.shift(game, action.from, t.land)
	rec.landed = { t.land }
	Util.finish(game, rec, color, Ram.key, true)
	return t
end

function Ram.actions(game)
	local color = game.turn
	if Ram.charges(game, color) < 1 then
		return {}
	end
	local out = {}
	for _, from in Util.piecesOf(game, "r") do
		for _, dir in Ram.DIRS do
			if #Ram.trace(game, from, dir).hits > 0 then
				local a = { kind = "ability", id = Ram.id, from = from, dir = dir }
				if Util.legal(game, Ram, a) then
					table.insert(out, a)
				end
			end
		end
	end
	return out
end

-- move-list text, e.g. "Ra1 ram a6 x3"
function Ram.describe(game, action, t)
	return "R" .. Board.name(action.from) .. " ram " .. Board.name(t.land) .. " x" .. #t.hits
end

function Ram.score(game, action, values)
	return Util.value(game, Ram.trace(game, action.from, action.dir).hits, values)
end

return Ram
