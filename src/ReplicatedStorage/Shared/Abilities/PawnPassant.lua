-- Any Passant (the user's rule, vault Design/Abilities Mode; was "En Passant Anything"):
--   one of your pawns on its 5th rank, instead of a move, once per game per player;
--   any enemy piece that has just landed on the square beside the pawn (left or right) can be
--   captured en passant style: the pawn moves diagonally forward to the square behind it and takes it.
--   (Agent rules: never the king; the square the pawn moves to must be empty; a pawn's double step
--   beside it is left to normal en passant, so the charge isn't spent on a free capture.)
-- "Just landed" comes from game.landed, which the mode keeps up to date after every action.
-- Action: { kind = "ability", id = "PawnPassant", from = pawn square, to = the square it moves to }
-- Pure Luau.

local Chess = script.Parent.Parent.Chess
local Board = require(Chess.Board)
local Util = require(script.Parent.Util)

local Passant = {}

Passant.id = "PawnPassant"
Passant.name = "Any Passant"
Passant.key = "passant"
Passant.piece = "p"

function Passant.charges(game, color)
	return Util.charges(game, color, Passant.key)
end

local function forward(color)
	return if color == "w" then 16 else -16
end

-- the square of the piece it takes (beside the pawn, behind where the pawn lands)
function Passant.target(game, action)
	local p = game.board.sq[action.from]
	return action.to - forward(if p then p.color else game.turn)
end

function Passant.hits(game, action)
	return { Passant.target(game, action) }
end

function Passant.apply(game, action)
	local color = game.turn
	local target = Passant.target(game, action)
	local rec = Util.begin(game, action, { action.from, target, action.to })
	game.board:remove(target)
	Util.shift(game, action.from, action.to)
	rec.landed = { action.to }
	Util.finish(game, rec, color, Passant.key, true)
	return { target }
end

function Passant.actions(game)
	local color = game.turn
	local landed = game.landed
	if Passant.charges(game, color) < 1 or not landed or #landed == 0 then
		return {}
	end
	local fifth = if color == "w" then 4 else 3
	local sq = game.board.sq
	local out = {}
	for _, from in Util.piecesOf(game, "p") do
		if Board.rank(from) == fifth then
			for _, side in { -1, 1 } do
				local t = from + side
				local p = Board.onBoard(t) and sq[t]
				if p and p.color ~= color and p.type ~= "k" and table.find(landed, t) then
					local to = t + forward(color)
					local normalEp = p.type == "p" and game.ep == to
					if Board.onBoard(to) and sq[to] == nil and not normalEp then
						local a = { kind = "ability", id = Passant.id, from = from, to = to }
						if Util.legal(game, Passant, a) then
							table.insert(out, a)
						end
					end
				end
			end
		end
	end
	return out
end

-- move-list text, e.g. "e5 passant xd6": the pawn on e5 takes the piece beside it and lands on d6
function Passant.describe(game, action, hits)
	return Board.name(action.from) .. " passant x" .. Board.name(action.to)
end

function Passant.score(game, action, values)
	return Util.value(game, Passant.hits(game, action), values)
end

return Passant
