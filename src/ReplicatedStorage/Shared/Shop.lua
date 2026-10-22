-- The Shop's catalogue and the coin rules, shared by the server (Tables/Wallet, Tables/Passes) and
-- the client (ShopPanel). Coins are earned only by winning games against people (any mode); bot
-- games pay nothing. Every player owns Any Passant from the start. The other abilities are bought
-- once, with coins or with their Robux gamepass, and kept forever: in an Abilities game each player
-- can only use the abilities they own (a bot gets the same ones as the person it plays).
-- Steal a Piece isn't sold here: it's a developer product bought from its button in a game
-- (Settings.STEAL_PRODUCT).

local Shop = {}

Shop.START_COINS = 0 -- a new player's wallet (Any Passant is already theirs)
Shop.WIN_REWARD = 50 -- coins for winning a game against a person
Shop.MIN_PLIES = 10 -- a win pays only once both sides have made 5 moves (no instant-resign farming)
Shop.COINS_PER_ROBUX = 10 -- coin prices follow the gamepass prices at this rate

-- Rarity tiers (user, 2026-10-20), shown on the Shop cards: a name and a colour each, in order.
-- Each ability's tier follows its price: free / cheap = Common, mid = Uncommon, top = Epic.
local rgb = Color3.fromRGB
Shop.RARITIES = {
	common = { name = "Common", color = rgb(56, 172, 236), order = 1 },
	uncommon = { name = "Uncommon", color = rgb(70, 200, 90), order = 2 },
	epic = { name = "Epic", color = rgb(196, 168, 255), order = 3 },
}

-- pawn to king, like the ability panel. free: everyone owns it. pass / robux: the gamepass and its
-- price (the Shop shows the live price once it loads). info: the rules, shown when a player taps the
-- card (the Shop's detail view, next to a little demo of it).
Shop.ABILITIES = {
	{ id = "PawnPassant", rarity = "common", free = true,
		info = "An enemy piece just landed beside your pawn? Your pawn hops diagonally behind it and takes it, like en passant. Any piece but the king." },
	{ id = "KnightJump", rarity = "epic", pass = 2040261216, robux = 150,
		info = "Your knight makes two knight jumps in one turn. It can capture on both landings." },
	{ id = "BishopSnipe", rarity = "epic", pass = 2037519702, robux = 150,
		info = "Your bishop fires down a diagonal, wiping out every enemy on it. Your own pieces block the shot, and the king is skipped." },
	{ id = "RookRam", rarity = "uncommon", pass = 2036577735, robux = 100,
		info = "Your rook charges in a line, smashing every enemy in its path. It stops at your own piece, the edge, or in front of the king." },
	{ id = "KingEscape", rarity = "common", pass = 2040423129, robux = 50,
		info = "Your king teleports up to 2 squares away, even onto an enemy piece to capture it. Perfect for getting out of check." },
}
for _, item in Shop.ABILITIES do
	item.price = if item.robux then item.robux * Shop.COINS_PER_ROBUX else nil -- in coins
end

local byId = {}
for _, item in Shop.ABILITIES do
	byId[item.id] = item
end
Shop.byId = byId

-- ability ids everyone owns
Shop.FREE = {}
for _, item in Shop.ABILITIES do
	if item.free then
		table.insert(Shop.FREE, item.id)
	end
end

-- an ability's rarity tier ({ name, color, order }), Common if it has none
function Shop.rarity(id: string)
	local item = byId[id]
	return Shop.RARITIES[item and item.rarity or "common"] or Shop.RARITIES.common
end

-- coins, or nil for a free ability
function Shop.price(id: string): number?
	local item = byId[id]
	return item and item.price
end

-- 1250 -> "1,250"
function Shop.format(n: number): string
	if n < 0 then
		return "-" .. Shop.format(-n)
	end
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

return Shop
