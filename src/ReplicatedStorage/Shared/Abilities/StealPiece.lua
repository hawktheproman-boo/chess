-- Steal a Piece (the user's ability, rules in vault Design/Abilities Mode): bought with Robux, one
-- developer product per use (Settings.STEAL_PRODUCT). In Classic and Abilities games:
--   instead of a move, once per game per player;
--   any enemy piece except the king and the queen becomes yours, on the same square.
--   (Agent rules) It may never leave your own king in check, so stealing the piece that gives
--   check gets you out of it; it can give check and mate; the stolen piece counts as moved.
-- The charge (game.abilityState[color].steal) is 0 until the server grants it to a player who has
-- a paid steal (StealPiece.grant); it isn't part of the position key. Replays of finished games
-- grant it to whoever used it (StealPiece.grantUsed).
-- Action: { kind = "ability", id = "StealPiece", from = the enemy piece's square }
-- Pure Luau.

local Chess = script.Parent.Parent.Chess
local Board = require(Chess.Board)
local Util = require(script.Parent.Util)

local Steal = {}

Steal.id = "StealPiece"
Steal.name = "Steal a Piece"
Steal.key = "steal"

local LETTER = { n = "N", b = "B", r = "R", p = "" }

function Steal.charges(game, color)
	return Util.charges(game, color, Steal.key)
end

-- granted = { w = true?, b = true? }: those colours get their one steal for this game
function Steal.grant(game, granted)
	if type(granted) ~= "table" or not game.abilityState then
		return
	end
	for _, color in { "w", "b" } do
		if granted[color] and game.abilityState[color] then
			game.abilityState[color][Steal.key] = math.max(game.abilityState[color][Steal.key] or 0, 1)
		end
	end
end

-- a replay (saved game, review): grant it to each colour that stole in these actions
function Steal.grantUsed(game, actions)
	if type(actions) ~= "table" then
		return
	end
	local granted, color = {}, game.turn
	for _, a in actions do
		if type(a) == "table" and a.kind == "ability" and a.id == Steal.id then
			granted[color] = true
		end
		color = Board.other(color)
	end
	Steal.grant(game, granted)
end

local function stealable(p, enemy)
	return p ~= nil and p.color == enemy and p.type ~= "k" and p.type ~= "q"
end

function Steal.apply(game, action)
	local color = game.turn
	local board = game.board
	local rec = Util.begin(game, action, { action.from })
	local old = board:remove(action.from)
	local mine = board:newPiece(old.type, color)
	mine.moved = true
	board:place(action.from, mine)
	rec.landed = { action.from }
	Util.finish(game, rec, color, Steal.key, true) -- (like a capture: the 50-move count restarts)
	return { piece = old.type }
end

-- capturesOnly (the bot's quiet search) leaves it out
function Steal.actions(game, capturesOnly)
	local out = {}
	local color = game.turn
	if capturesOnly or Steal.charges(game, color) < 1 then
		return out
	end
	local enemy = Board.other(color)
	for _, s in Board.squares do
		if stealable(game.board.sq[s], enemy) then
			local a = { kind = "ability", id = Steal.id, from = s }
			if Util.legal(game, Steal, a) then
				table.insert(out, a)
			end
		end
	end
	return out
end

-- "Steal Nc6" / "Steal e5" (a pawn)
function Steal.describe(game, action, extra)
	return "Steal " .. (LETTER[extra and extra.piece or "p"] or "") .. Board.name(action.from)
end

-- the cutscene's target
function Steal.hits(game, action)
	return { action.from }
end

-- bot move ordering: the piece is lost to them and gained by us
function Steal.score(game, action, values)
	local p = game.board.sq[action.from]
	return if p then 2 * (values[p.type] or 0) else 0
end

return Steal
