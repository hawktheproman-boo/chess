-- Classic: standard FIDE chess. The engine's defaults are the rules; the only hooks are for Steal a
-- Piece (Shared/Abilities/StealPiece), the Robux steal, which has no charge unless the server grants
-- it to a player who paid. Without a grant Classic is plain chess (perft is unchanged).

local Shared = script.Parent.Parent
local Moves = require(Shared.Chess.Moves)
local Steal = require(Shared.Abilities.StealPiece)

local Classic = {
	id = "Classic",
	name = "Classic",
}

function Classic.setup(game)
	game.abilityState = { w = { steal = 0 }, b = { steal = 0 } }
end

function Classic.abilityActions(game, capturesOnly)
	return Steal.actions(game, capturesOnly)
end

-- replays: whoever stole in these actions had a steal
function Classic.prepareReplay(game, actions)
	Steal.grantUsed(game, actions)
end

-- trusted = already known legal (search). Returns ok, move-list text.
function Classic.applyAbility(game, action, trusted)
	if action.id ~= Steal.id then
		return false, "no abilities in this mode"
	end
	if not trusted then
		local found = false
		for _, legal in Steal.actions(game) do
			if legal.from == action.from then
				found = true
				break
			end
		end
		if not found then
			return false, "illegal ability"
		end
	end
	local extra = Steal.apply(game, action)
	if trusted then
		return true
	end
	local text = Steal.describe(game, action, extra)
	if Moves.inCheck(game, game.turn) then
		local any = #Moves.legal(game) > 0 or #Steal.actions(game) > 0
		text ..= if any then "+" else "#"
	end
	return true, text
end

function Classic.abilityScore(game, action, values)
	return Steal.score(game, action, values)
end

return Classic
