-- Per-player settings: DataStore "ChessPrefs_v1", key "u_<userId>", value { theme, sound, music, autoQueen, pieceSet }.
-- Kept in memory for the session too, so settings still work in Studio without API access.

local DataStoreService = game:GetService("DataStoreService")

local Themes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Themes"))
local Settings = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Settings"))

local Prefs = {}

local storeOk, store = pcall(function()
	return DataStoreService:GetDataStore("ChessPrefs_v1")
end)
if not storeOk then
	store = nil
end

local cache = {} -- userId -> prefs
local DEFAULTS = { theme = Themes.DEFAULT, sound = true, music = true, autoQueen = false, pieceSet = Settings.DEFAULT_PIECE_SET }

local function clean(p)
	p = type(p) == "table" and p or {}
	local theme = if type(p.theme) == "string" then Themes.get(p.theme).id else DEFAULTS.theme
	local sound = if type(p.sound) == "boolean" then p.sound else DEFAULTS.sound
	local autoQueen = if type(p.autoQueen) == "boolean" then p.autoQueen else DEFAULTS.autoQueen
	local music = if type(p.music) == "boolean" then p.music else DEFAULTS.music
	local pieceSet = if type(p.pieceSet) == "string" and Settings.pieceSet(p.pieceSet) then p.pieceSet else DEFAULTS.pieceSet
	return { theme = theme, sound = sound, music = music, autoQueen = autoQueen, pieceSet = pieceSet }
end

function Prefs.get(userId: number)
	if cache[userId] then
		return cache[userId]
	end
	local data
	if store and userId > 0 then
		local ok, v = pcall(function()
			return store:GetAsync("u_" .. userId)
		end)
		data = ok and v or nil
	end
	cache[userId] = clean(data)
	return cache[userId]
end

-- merge a client's change in (anything invalid is dropped), save it in the background
function Prefs.set(userId: number, change)
	if type(change) ~= "table" then
		return Prefs.get(userId)
	end
	local merged = table.clone(Prefs.get(userId))
	if type(change.theme) == "string" and Themes.get(change.theme).id == change.theme then
		merged.theme = change.theme -- an unknown theme id is ignored (keeps the current one)
	end
	if change.sound ~= nil then
		merged.sound = change.sound
	end
	if type(change.pieceSet) == "string" and Settings.pieceSet(change.pieceSet) then
		merged.pieceSet = change.pieceSet -- (an unknown set is ignored)
	end
	if type(change.music) == "boolean" then
		merged.music = change.music
	end
	if change.autoQueen ~= nil then
		merged.autoQueen = change.autoQueen
	end
	merged = clean(merged)
	cache[userId] = merged
	if store and userId > 0 then
		task.spawn(function()
			pcall(function()
				store:SetAsync("u_" .. userId, merged)
			end)
		end)
	end
	return merged
end

function Prefs.forget(userId: number)
	cache[userId] = nil
end

return Prefs
