-- Royal Escape (picked by the user, rules in vault Design/Abilities Mode):
--   your king, instead of a move, once per game per player; it works while in check (its main use);
--   the king teleports to a square up to 2 squares away, empty or holding an enemy piece (which
--   it captures), as long as it isn't in check after landing. Removes castling rights like any
--   king move. (Only squares exactly 2 away are offered: one square away is a normal king move,
--   so the charge would be wasted.)
-- Action: { kind = "ability", id = "KingEscape", from = king square, to = landing square }
-- Pure Luau.

local Chess = script.Parent.Parent.Chess
local Board = require(Chess.Board)
local Util = require(script.Parent.Util)

local Escape = {}

Escape.id = "KingEscape"
Escape.name = "Royal Escape"
Escape.key = "escape"
Escape.piece = "k"

function Escape.charges(game, color)
	return Util.charges(game, color, Escape.key)
end

function Escape.hits(game, action)
	return if game.board.sq[action.to] then { action.to } else {}
end

function Escape.apply(game, action)
	local color = game.turn
	local hits = Escape.hits(game, action)
	local rec = Util.begin(game, action, { action.from, action.to })
	if #hits > 0 then
		game.board:remove(action.to)
	end
	Util.shift(game, action.from, action.to)
	rec.landed = { action.to }
	Util.finish(game, rec, color, Escape.key, #hits > 0)
	return hits
end

-- capturesOnly (the bot's search): escapes that capture, plus every escape while in check
function Escape.actions(game, capturesOnly)
	local color = game.turn
	local from = game.board.kings[color]
	if not from or Escape.charges(game, color) < 1 then
		return {}
	end
	local inCheck = game:inCheck(color)
	local out = {}
	local sq = game.board.sq
	for df = -2, 2 do
		for dr = -2, 2 do
			if math.max(math.abs(df), math.abs(dr)) == 2 then
				local f, r = Board.file(from) + df, Board.rank(from) + dr
				if f >= 0 and f <= 7 and r >= 0 and r <= 7 then
					local to = Board.index(f, r)
					local p = sq[to]
					if (p == nil or (p.color ~= color and p.type ~= "k")) and (not capturesOnly or inCheck or p ~= nil) then
						local a = { kind = "ability", id = Escape.id, from = from, to = to }
						if Util.legal(game, Escape, a) then
							table.insert(out, a)
						end
					end
				end
			end
		end
	end
	return out
end

-- move-list text, e.g. "Ke1 escape g3" / "Ke1 escape xg3"
function Escape.describe(game, action, hits)
	return "K" .. Board.name(action.from) .. " escape " .. (if #hits > 0 then "x" else "") .. Board.name(action.to)
end

function Escape.score(game, action, values)
	return Util.value(game, Escape.hits(game, action), values)
end

return Escape
