-- Coins, bought abilities and paid steals: DataStore "ChessWallet_v1", key "u_<userId>",
-- value { coins, owned = { [abilityId] = true }, earned, steals, receipts }:
--   earned = all coins ever won; steals = paid Steal a Piece uses not spent yet; receipts = the
--   newest developer-product purchase ids already granted (so a receipt is never granted twice).
-- Free abilities (Shop.FREE) are always owned, and so is every ability whose gamepass the player
-- owns (Tables/Passes); the client sees them all in `owned`.
-- Every change goes through UpdateAsync, so the stored value is the truth and two servers can't
-- spend the same coins twice. A session cache answers reads (Wallet.owned at game start); when
-- the DataStore can't be reached (Studio without API access) the cache alone is used.
-- Changes are pushed to the player through Remotes.Wallet: { coins, owned = { ids }, steals, gained? }.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Shop"))
local Passes = require(script.Parent.Passes)

local Wallet = {}

local storeOk, store = pcall(function()
	return DataStoreService:GetDataStore("ChessWallet_v1")
end)
if not storeOk then
	warn("[Chess] wallet DataStore unavailable:", store)
	store = nil
end

local cache = {} -- userId -> wallet
local loading = {} -- userId -> true while the first read runs
local remote -- Remotes.Wallet (set by TableService)
local sandbox = {} -- userId -> true: Studio tests, changes stay in the cache (never saved)
local MAX_RECEIPTS = 50

local function clean(v)
	v = type(v) == "table" and v or {}
	local owned = {}
	if type(v.owned) == "table" then
		for id in v.owned do
			if Shop.byId[id] then
				owned[id] = true
			end
		end
	end
	for _, id in Shop.FREE do
		owned[id] = true
	end
	local receipts = {}
	if type(v.receipts) == "table" then
		for _, r in v.receipts do
			if type(r) == "string" then
				table.insert(receipts, r)
			end
		end
	end
	return {
		coins = if type(v.coins) == "number" then math.max(0, math.floor(v.coins)) else Shop.START_COINS,
		owned = owned,
		earned = if type(v.earned) == "number" then v.earned else 0,
		steals = if type(v.steals) == "number" then math.max(0, math.floor(v.steals)) else 0,
		receipts = receipts,
	}
end

-- what the client sees: owned = bought, free and gamepass abilities, in Shop order
local function view(w, userId)
	local passes = Passes.abilities(userId)
	local owned = {}
	for _, item in Shop.ABILITIES do
		if w.owned[item.id] or table.find(passes, item.id) then
			table.insert(owned, item.id)
		end
	end
	return { coins = w.coins, owned = owned, steals = w.steals }
end

function Wallet.setRemote(r)
	remote = r
end

local function push(userId, extra)
	local player = Players:GetPlayerByUserId(userId)
	if remote and player and cache[userId] then
		local v = view(cache[userId], userId)
		if extra then
			for k, x in extra do
				v[k] = x
			end
		end
		remote:FireClient(player, v)
	end
end

function Wallet.get(userId: number)
	while loading[userId] do
		task.wait()
	end
	if cache[userId] then
		return cache[userId]
	end
	local data
	if store and userId > 0 then
		loading[userId] = true
		local ok, v = pcall(function()
			return store:GetAsync("u_" .. userId)
		end)
		loading[userId] = nil
		if not ok then
			warn("[Chess] couldn't load a wallet:", v)
		end
		data = ok and v or nil
	end
	cache[userId] = clean(data)
	return cache[userId]
end

function Wallet.view(userId: number)
	return view(Wallet.get(userId), userId)
end

-- tell the player their wallet changed (e.g. a gamepass was bought)
function Wallet.refresh(userId: number)
	push(userId)
end

-- ability ids this player owns
function Wallet.owned(userId: number): { string }
	return view(Wallet.get(userId), userId).owned
end

-- change(wallet) edits a clean copy and returns ok, err. Saved with UpdateAsync (retried); the
-- cache takes the saved value. Without a store the change applies to the cache only.
local function update(userId: number, change)
	Wallet.get(userId)
	if not store or userId <= 0 or sandbox[userId] then
		local w = clean(cache[userId])
		local ok, err = change(w)
		if ok then
			cache[userId] = w
		end
		return ok, err
	end
	local result, why
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:UpdateAsync("u_" .. userId, function(old)
				local w = clean(old)
				local fine, reason = change(w)
				if not fine then
					why = reason
					return nil -- cancels the write
				end
				result = w
				return w
			end)
		end)
		if ok then
			if result then
				cache[userId] = result
				return true
			end
			return false, why
		end
		warn("[Chess] wallet save failed:", err)
		task.wait(2 ^ attempt)
	end
	return false, "couldn't save, try again"
end

-- Win reward. Runs in the background; the player is told through the remote.
function Wallet.award(userId: number, amount: number)
	task.spawn(function()
		local ok = update(userId, function(w)
			w.coins += amount
			w.earned += amount
			return true
		end)
		if ok then
			push(userId, { gained = amount })
		end
	end)
end

-- Buy an ability with coins. Returns ok, view | err.
function Wallet.buy(userId: number, id)
	local price = type(id) == "string" and Shop.price(id)
	if not price then
		return false, if type(id) == "string" and Shop.byId[id] then "already owned" else "unknown item"
	end
	if table.find(Passes.abilities(userId), id) then
		return false, "already owned"
	end
	local ok, err = update(userId, function(w)
		if w.owned[id] then
			return false, "already owned"
		end
		if w.coins < price then
			return false, "not enough coins"
		end
		w.coins -= price
		w.owned[id] = true
		return true
	end)
	if not ok then
		return false, err
	end
	return true, Wallet.view(userId)
end

-- Paid steals --------------------------------------------------------------------------------------

function Wallet.steals(userId: number): number
	return Wallet.get(userId).steals
end

-- A Steal a Piece purchase (ProcessReceipt). Returns true once it's saved, also when this receipt was
-- already granted before; false = not saved yet (Roblox retries the receipt later).
function Wallet.grantSteal(userId: number, purchaseId: string): boolean
	local ok = update(userId, function(w)
		if table.find(w.receipts, purchaseId) then
			return true -- (already granted: saving again changes nothing)
		end
		w.steals += 1
		table.insert(w.receipts, purchaseId)
		while #w.receipts > MAX_RECEIPTS do
			table.remove(w.receipts, 1)
		end
		return true
	end)
	if ok then
		push(userId)
	end
	return ok
end

-- a steal was used in a game (background)
function Wallet.spendSteal(userId: number)
	task.spawn(function()
		local ok = update(userId, function(w)
			if w.steals < 1 then
				return false, "no steals"
			end
			w.steals -= 1
			return true
		end)
		if ok then
			push(userId)
		end
	end)
end

-- Studio test hook: set coins, owned ids and / or paid steals. From then on this player's wallet is a sandbox
-- for the rest of the session: wins and purchases change the cache only, never the saved wallet.
function Wallet.debugSet(userId: number, coins: number?, owned: { string }?, steals: number?)
	sandbox[userId] = true
	local w = clean(Wallet.get(userId))
	if coins then
		w.coins = coins
	end
	if owned then
		w.owned = {}
		for _, id in owned do
			w.owned[id] = true
		end
		w = clean(w) -- (free abilities stay owned)
	end
	if steals then
		w.steals = steals
	end
	cache[userId] = w
	push(userId)
	return Wallet.view(userId)
end

function Wallet.forget(userId: number)
	cache[userId] = nil
	sandbox[userId] = nil
end

return Wallet
