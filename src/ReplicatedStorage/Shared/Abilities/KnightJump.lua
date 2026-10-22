-- Double Jump (picked by the user, rules in vault Design/Abilities Mode):
--   any of your knights, instead of a move, once per game per player;
--   two knight moves in a row by the same knight; it can capture on either landing (a capture on
--   the first leg doesn't end the jump), and it may land back on its starting square.
--   It never lands on the enemy king, and it may never leave your own king in check.
-- Action: { kind = "ability", id = "KnightJump", from = knight square, mid = first landing, to = second }
-- Pure Luau.

local Chess = script.Parent.Parent.Chess
local Board = require(Chess.Board)
local Util = require(script.Parent.Util)

local KNIGHT = { 33, 31, 18, 14, -33, -31, -18, -14 }

local Jump = {}

Jump.id = "KnightJump"
Jump.name = "Double Jump"
Jump.key = "jump"
Jump.piece = "n"

function Jump.charges(game, color)
	return Util.charges(game, color, Jump.key)
end

-- can the knight (colour `me`) land on s? (empty or an enemy that isn't the king)
local function landable(game, s, me, from)
	if not Board.onBoard(s) then
		return false
	end
	if s == from then
		return true -- its own start square is empty once it has jumped away
	end
	local p = game.board.sq[s]
	return p == nil or (p.color ~= me and p.type ~= "k")
end

-- the squares this jump captures on, in order
function Jump.hits(game, action)
	local sq = game.board.sq
	local me = sq[action.from] and sq[action.from].color
	local out = {}
	for _, s in { action.mid, action.to } do
		local p = sq[s]
		if p and p.color ~= me and s ~= action.from and not table.find(out, s) then
			table.insert(out, s)
		end
	end
	return out
end

function Jump.apply(game, action)
	local color = game.turn
	local hits = Jump.hits(game, action)
	local rec = Util.begin(game, action, { action.from, action.mid, action.to })
	if game.board.sq[action.mid] then
		game.board:remove(action.mid)
	end
	Util.shift(game, action.from, action.mid)
	if action.to ~= action.mid and game.board.sq[action.to] then
		game.board:remove(action.to)
	end
	Util.shift(game, action.mid, action.to)
	rec.landed = { action.to }
	Util.finish(game, rec, color, Jump.key, #hits > 0)
	return hits
end

-- legal jumps for the side to move. capturesOnly: just the ones that take something (the bot's
-- search; quiet double jumps are left to people)
function Jump.actions(game, capturesOnly)
	local color = game.turn
	if Jump.charges(game, color) < 1 then
		return {}
	end
	local out = {}
	local sq = game.board.sq
	for _, from in Util.piecesOf(game, "n") do
		for _, d1 in KNIGHT do
			local mid = from + d1
			if mid ~= from and landable(game, mid, color, nil) then
				for _, d2 in KNIGHT do
					local to = mid + d2
					if landable(game, to, color, from) then
						local captures = (sq[mid] ~= nil) or (to ~= from and sq[to] ~= nil)
						if not capturesOnly or captures then
							local a = { kind = "ability", id = Jump.id, from = from, mid = mid, to = to }
							if Util.legal(game, Jump, a) then
								table.insert(out, a)
							end
						end
					end
				end
			end
		end
	end
	return out
end

-- move-list text, e.g. "Nb1 jump c3 xd5" (+ / # added by the mode)
function Jump.describe(game, action, hits)
	local function leg(s)
		return (if table.find(hits, s) then "x" else "") .. Board.name(s)
	end
	return "N" .. Board.name(action.from) .. " jump " .. leg(action.mid) .. " " .. leg(action.to)
end

function Jump.score(game, action, values)
	return Util.value(game, Jump.hits(game, action), values)
end

return Jump
