-- Abilities mode: Classic rules plus the user's abilities (vault Design/Abilities Mode): every
-- piece type has one, each once per game per player. Each ability is a module in Shared/Abilities
-- with: id, name, piece, actions(game, capturesOnly), apply(game, action) -> extra,
-- describe(game, action, extra), score(game, action, values) and charges(game, color).
-- Ability state lives on the game (game.abilityState) so undo, clones and replays all keep it.

local Shared = script.Parent.Parent
local Moves = require(Shared.Chess.Moves)
local BishopSnipe = require(Shared.Abilities.BishopSnipe)
local KnightJump = require(Shared.Abilities.KnightJump)
local RookRam = require(Shared.Abilities.RookRam)
local QueenSwap = require(Shared.Abilities.QueenSwap)
local KingEscape = require(Shared.Abilities.KingEscape)
local PawnPassant = require(Shared.Abilities.PawnPassant)
local Steal = require(Shared.Abilities.StealPiece)

local Abilities = {
	id = "Abilities",
	name = "Abilities",
}

-- (in board order, pawn to king: the ability panel shows them like this)
-- (The queen has none for now: Swap was scrapped on 2026-10-20, and the queen's Domain Expansion
-- isn't built yet.)
Abilities.list = { PawnPassant, KnightJump, BishopSnipe, RookRam, KingEscape }
BishopSnipe.piece = "b"
local byId, byPiece = {}, {}
for _, a in Abilities.list do
	byId[a.id] = a
	byPiece[a.piece] = a
end
-- Steal a Piece (Robux, Shared/Abilities/StealPiece) is played like an ability but isn't one of the
-- abilities: it isn't in the panel, the loadout or the position key, and it has no charge until granted.
byId[Steal.id] = Steal
-- Swap is retired: it isn't offered or sold, but games saved before it was scrapped still replay
-- (prepareReplay gives it back to whoever used it).
byId[QueenSwap.id] = QueenSwap
Abilities.byId = byId
Abilities.byPiece = byPiece -- piece type -> its ability

function Abilities.setup(game)
	-- one charge of each, per player
	game.abilityState = {
		w = { snipe = 1, jump = 1, ram = 1, swap = 0, escape = 1, passant = 1, steal = 0 },
		b = { snipe = 1, jump = 1, ram = 1, swap = 0, escape = 1, passant = 1, steal = 0 },
	}
	game.landed = {} -- squares where the last action left pieces (Any Passant)
end

-- Abilities are bought in the Shop: loadout = { w = { ids }?, b = { ids }? } (nil = every ability).
-- A colour's abilities that aren't in its list start with no charge. Call right after Game.new.
function Abilities.setLoadout(game, loadout)
	if type(loadout) ~= "table" or not game.abilityState then
		return
	end
	for _, color in { "w", "b" } do
		local ids = loadout[color]
		if type(ids) == "table" then
			for _, ability in Abilities.list do
				if not table.find(ids, ability.id) then
					game.abilityState[color][ability.key] = 0
				end
			end
		end
	end
	game.seen = { [game:key()] = 1 } -- (the ability state is part of the position key)
end

-- After every action: remember where it left pieces, so Any Passant knows what "just landed".
-- (Undo puts the old list back through the record's onPop.)
function Abilities.onTurnStart(game)
	local rec = game.stack[#game.stack]
	if not rec then
		return
	end
	local landed = rec.landed or (if rec.undo == nil and rec.move then { rec.move.to } else {})
	local before = game.landed
	game.landed = landed
	rec.onPop = function(g)
		g.landed = before
	end
end

-- capturesOnly: just the ability actions that capture (plus escapes while in check). The bot's
-- search uses it: quiet double jumps and swaps would triple its branching for little gain.
function Abilities.abilityActions(game, capturesOnly)
	local out = {}
	for _, ability in Abilities.list do
		for _, a in ability.actions(game, capturesOnly) do
			table.insert(out, a)
		end
	end
	for _, a in Steal.actions(game, capturesOnly) do
		table.insert(out, a)
	end
	return out
end

-- replays: whoever stole in these actions had a steal; whoever swapped (an old saved game) had a swap
function Abilities.prepareReplay(game, actions)
	Steal.grantUsed(game, actions)
	if type(actions) ~= "table" then
		return
	end
	local color = game.turn
	for _, a in actions do
		if type(a) == "table" and a.kind == "ability" and a.id == QueenSwap.id then
			game.abilityState[color].swap = 1
		end
		color = if color == "w" then "b" else "w"
	end
	game.seen = { [game:key()] = 1 }
end

-- charges left for a colour, all abilities together
function Abilities.chargesLeft(game, color)
	local n = 0
	for _, ability in Abilities.list do
		n += ability.charges(game, color)
	end
	return n
end

local function same(a, b)
	return a.id == b.id and a.from == b.from and a.dir == b.dir and a.mid == b.mid and a.to == b.to
end

-- trusted = already known legal (search). Otherwise the action must match a legal one.
-- Returns ok, move-list text.
function Abilities.applyAbility(game, action, trusted)
	local ability = byId[action.id]
	if not ability then
		return false, "unknown ability"
	end
	if not trusted then
		local found = false
		for _, legal in ability.actions(game) do
			if same(legal, action) then
				found = true
				break
			end
		end
		if not found then
			return false, "illegal ability"
		end
	end
	local extra = ability.apply(game, action)
	if trusted then
		return true
	end
	local text = ability.describe(game, action, extra)
	-- check / mate suffix, like SAN
	if Moves.inCheck(game, game.turn) then
		local any = #Moves.legal(game) > 0 or #Abilities.abilityActions(game) > 0
		text ..= if any then "+" else "#"
	end
	return true, text
end

-- ability state is part of the position (for repetition)
function Abilities.stateKey(game)
	local w, b = game.abilityState.w, game.abilityState.b
	return "s" .. w.snipe .. w.jump .. w.ram .. w.escape .. w.passant
		.. b.snipe .. b.jump .. b.ram .. b.escape .. b.passant
end

-- bot move ordering
function Abilities.abilityScore(game, action, values)
	local ability = byId[action.id]
	return if ability and ability.score then ability.score(game, action, values) else 0
end

return Abilities
