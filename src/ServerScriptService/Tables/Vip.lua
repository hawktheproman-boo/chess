-- VIP gamepass ownership (Settings.VIP_PASS): detailed stats and saved game reviews.
-- Owning is cached for the session; "doesn't own" is re-checked after a minute, and a purchase in
-- this server flips it at once. Studio test scripts can force it with Vip.override(userId, bool).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Settings = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Settings"))

local Vip = {}

local owns = {} -- userId -> true | { checked = os.clock() } (not owned)
local overrides = {}

function Vip.owns(player: Player): boolean
	local id = player.UserId
	if overrides[id] ~= nil then
		return overrides[id]
	end
	local c = owns[id]
	if c == true then
		return true
	end
	if c and os.clock() - c.checked < 60 then
		return false
	end
	local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, id, Settings.VIP_PASS)
	if ok and result then
		owns[id] = true
		return true
	end
	owns[id] = { checked = os.clock() }
	return false
end

function Vip.override(userId: number, on: boolean?)
	overrides[userId] = on
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
	if bought and passId == Settings.VIP_PASS then
		owns[player.UserId] = true
	end
end)

Players.PlayerRemoving:Connect(function(player)
	owns[player.UserId] = nil
end)

return Vip
