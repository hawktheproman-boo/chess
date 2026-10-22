-- Ability gamepasses (Shared/Shop: each ability's `pass`): owning the pass owns the ability, the
-- same as buying it with coins. Ownership is cached for the session; "doesn't own" is re-checked
-- after a minute, and a purchase in this server flips it at once. Passes.preload checks every pass
-- when a player joins, so a game start never waits on it.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shop = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Shop"))

local Passes = {}

local cache = {} -- userId -> { [passId] = true | os.clock() of a "no" }
local onBought -- (userId, abilityId) -> (), set by TableService
local overrides = {} -- userId -> false: Studio tests pretend the player owns no ability pass

local function check(userId: number, passId: number): boolean
	local c = cache[userId]
	if not c then
		c = {}
		cache[userId] = c
	end
	local v = c[passId]
	if v == true then
		return true
	end
	if v and os.clock() - v < 60 then
		return false
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, userId, passId)
	c[passId] = if ok and owns then true else os.clock()
	return c[passId] == true
end

-- ability ids this player owns through gamepasses
function Passes.abilities(userId: number): { string }
	local out = {}
	if userId <= 0 or overrides[userId] == false then
		return out
	end
	for _, item in Shop.ABILITIES do
		if item.pass and check(userId, item.pass) then
			table.insert(out, item.id)
		end
	end
	return out
end

-- Studio tests: on = false hides every ability pass this player owns; nil goes back to the truth
function Passes.override(userId: number, on: boolean?)
	overrides[userId] = if on == false then false else nil
end

function Passes.preload(userId: number)
	Passes.abilities(userId)
end

function Passes.onBought(fn)
	onBought = fn
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
	if not bought then
		return
	end
	for _, item in Shop.ABILITIES do
		if item.pass == passId then
			cache[player.UserId] = cache[player.UserId] or {}
			cache[player.UserId][passId] = true
			if onBought then
				onBought(player.UserId, item.id)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	cache[player.UserId] = nil
end)

return Passes
