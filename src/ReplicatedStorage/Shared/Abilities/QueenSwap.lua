-- Swap: RETIRED on 2026-10-20 (the user scrapped it for a queen Domain Expansion, not built yet).
-- It isn't in Abilities.list, the Shop or the ability bar; it's kept only so games saved before then
-- still replay (Abilities.prepareReplay hands it back to whoever used it). Its old rules:
--   your queen, instead of a move, once per game per player;
--   she trades squares with any one of your own pieces, anywhere, except the king.
--   (Agent rule: a pawn may not be swapped onto the first or last rank.) It may never leave your
--   own king in check.
-- Action: { kind = "ability", id = "QueenSwap", from = queen square, to = the other piece's square }
-- Pure Luau.

local Chess = script.Parent.Parent.Chess
local Board = require(Chess.Board)
local Util = require(script.Parent.Util)

local Swap = {}

Swap.id = "QueenSwap"
Swap.name = "Swap"
Swap.key = "swap"
Swap.piece = "q"

function Swap.charges(game, color)
	return Util.charges(game, color, Swap.key)
end

function Swap.apply(game, action)
	local color = game.turn
	local board = game.board
	local rec = Util.begin(game, action, { action.from, action.to })
	local queen, other = board:remove(action.from), board:remove(action.to)
	queen.moved, other.moved = true, true
	board:place(action.to, queen)
	board:place(action.from, other)
	rec.landed = { action.from, action.to }
	Util.finish(game, rec, color, Swap.key, other.type == "p")
	return {}
end

function Swap.actions(game, capturesOnly)
	local color = game.turn
	if capturesOnly or Swap.charges(game, color) < 1 then
		return {} -- (never captures, so the bot's search leaves it out)
	end
	local out = {}
	local sq = game.board.sq
	for _, from in Util.piecesOf(game, "q") do
		local fromRank = Board.rank(from)
		for _, to in Board.squares do
			local p = sq[to]
			if to ~= from and p and p.color == color and p.type ~= "k"
				and not (p.type == "p" and (fromRank == 0 or fromRank == 7)) then
				local a = { kind = "ability", id = Swap.id, from = from, to = to }
				if Util.legal(game, Swap, a) then
					table.insert(out, a)
				end
			end
		end
	end
	return out
end

local LETTER = { p = "", n = "N", b = "B", r = "R", q = "Q" }

-- move-list text, e.g. "Qd1 swap Nb1" (after the swap the other piece stands on the queen's square)
function Swap.describe(game, action)
	local other = game.board.sq[action.from]
	return "Q" .. Board.name(action.from) .. " swap " .. (other and LETTER[other.type] or "") .. Board.name(action.to)
end

function Swap.score()
	return 0
end

return Swap
