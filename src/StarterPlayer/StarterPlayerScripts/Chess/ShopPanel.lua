-- The Shop card (opened from the lobby's Shop button), after the user's two references: the
-- simulator "Store" (a header with your coin balance and a red X, a grid of saturated item cards,
-- each with its art, price and a green Buy button, and category tabs along the bottom) in the
-- dark-green chess panel. Tabs:
--   Abilities: the piece abilities (Shared/Shop). Any Passant is free for everyone; the others
--              are bought once, with coins (green coin button) or with their Robux gamepass (blue
--              Robux button), and kept forever. Owned cards say OWNED; a card you can't afford in
--              coins shows how many are missing. Coins take two taps (price, then Sure?) so a stray
--              tap never spends them (Roblox confirms Robux purchases itself).
--   VIP:       the VIP gamepass (Robux). (Steal a Piece isn't sold here: it has its own button in
--              a game.)
-- Fixed sizes only (no AutomaticSize), like every other card.
--
--   ShopPanel.new(gui, cb) -> panel      cb = { close(), buy(id) -> ok, wallet | err (yields),
--                                               buyPass(passId), buyVip(), toast(text) }
--   panel:setWallet(w)                   w = { coins, owned = { ids }, vip? }
--   panel:showTab("abilities" | "vip")
--   panel.holder (show / hide it), panel.closeFace (controller focus)

local MarketplaceService = game:GetService("MarketplaceService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Settings = require(Shared.Settings)
local Shop = require(Shared.Shop)
local Ui = require(script.Parent.UiKit)
local AbilityBar = require(script.Parent.AbilityBar)
local PieceIcons = require(script.Parent.PieceIcons)
local AbilityDemo = require(script.Parent.AbilityDemo)
local Sounds = require(script.Parent.Sounds)
local T, BOLD, HEAVY = Ui.T, Ui.BOLD, Ui.HEAVY
local corner, stroke, label, button = Ui.corner, Ui.stroke, Ui.label, Ui.button
local I, setText = Ui.ICONS, Ui.setText

local ShopPanel = {}
ShopPanel.__index = ShopPanel

local W, H = 760, 476
local GRID_Y = 100 -- under the header and the "win to earn" line
local TABS_H = 50
local GAP = 12
local CARD_W = math.floor((W - 32 - 2 * GAP) / 3)
local GRID_H = H - GRID_Y - TABS_H - 28 -- the Abilities area (the VIP tab uses the same box)
local TIER_HEAD = 30 -- a tier column's header ("COMMON" on its colour line)
local CARD_H = math.floor((GRID_H - TIER_HEAD - 8 - GAP) / 2) -- two cards per column show at once
local VIP_PRICE = 400 -- shown until the pass's real price loads
local CONFIRM_TIME = 3 -- seconds a "Sure?" waits for the second tap

local rgb = Color3.fromRGB
local COIN_GOLD = rgb(255, 214, 90)
local MISSING = rgb(255, 150, 140)

local function frame(parent, name, size, pos)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Size = size
	f.Position = pos or UDim2.new()
	f.Parent = parent
	return f
end

-- one line of text, as big as fits its width (up to maxSize). (TextScaled doesn't shrink unwrapped
-- text to its width, so a long name ran into the piece on a phone.)
local function fitLine(l, width, maxSize)
	l.TextScaled = false
	l.TextWrapped = false
	l.TextSize = maxSize
	task.spawn(function()
		local params = Instance.new("GetTextBoundsParams")
		params.Text = l.Text
		params.Font = l.FontFace
		params.Size = maxSize
		params.Width = 10000
		local ok, b = pcall(TextService.GetTextBoundsAsync, TextService, params)
		if ok and b.X > 0 then
			l.TextSize = math.min(maxSize, math.floor(maxSize * width / (b.X + 4)))
		end
	end)
end

-- a dark pill with a coin and a number (the header balance, a card's price)
local function coinPill(parent, name, size, pos, textSize)
	local pill = frame(parent, name, size, pos)
	pill.BackgroundColor3 = T.ink
	pill.BackgroundTransparency = 0.35
	corner(pill, size.Y.Offset // 2)
	local iconSize = size.Y.Offset - 8
	Ui.icon(pill, I.coin, iconSize, UDim2.fromOffset(4, 4))
	local n = label(pill, "Amount", "0", UDim2.new(1, -iconSize - 14, 1, 0), UDim2.fromOffset(iconSize + 8, 0), Ui.TITLE, textSize, COIN_GOLD)
	Ui.chunky(n, 2)
	return pill, n
end

function ShopPanel.new(gui, cb)
	local self = setmetatable({}, ShopPanel)
	self.cb = cb
	self.wallet = { coins = 0, owned = {} }
	self.confirm = nil -- the ability id waiting for its second tap
	self.buying = nil -- the ability id being bought right now
	self.detailId = nil -- the ability whose detail view is open
	self.passPrices = {} -- gamepass id -> live Robux price

	local holder, body = Ui.card(gui, "Shop", UDim2.fromOffset(W, H), UDim2.fromScale(0.5, 0.46), Vector2.new(0.5, 0.5))
	holder.Visible = false
	self.holder = holder
	Ui.header(body, "Shop", nil, 30, I.shop)
	local _, close = Ui.closeX(body, function()
		cb.close()
	end)
	self.closeFace = close
	-- your coins, top right of the header (left of the X)
	local balance, amount = coinPill(body, "Balance", UDim2.fromOffset(150, 38), UDim2.new(1, -46, 0, 8), 24)
	balance.AnchorPoint = Vector2.new(1, 0)
	balance.ZIndex = 2
	self.balance, self.balanceScale = amount, Instance.new("UIScale")
	self.balanceScale.Parent = balance

	-- the hint line: how coins are earned (gold keyword, like the egg panel's subtitle)
	local hint = label(body, "Hint", "", UDim2.new(1, -32, 0, 28), UDim2.fromOffset(16, 62), Ui.TITLE, 19, T.white, Enum.TextXAlignment.Center)
	hint.RichText = true
	Ui.chunky(hint, 1.5)
	hint.Text = string.format('Win <font color="#FFC83D">1v1 games</font> to earn coins: <font color="#FFD65A">+%d</font> a win', Shop.WIN_REWARD)
	self.hint = hint

	-- Abilities tab: one column per rarity tier (Common | Uncommon | Epic), each with its coloured header
	-- and divider lines between them; the cards stack under their tier (pawn to king order). A column
	-- with more than two cards scrolls on its own.
	local grid = frame(body, "Abilities", UDim2.fromOffset(W - 32, GRID_H), UDim2.fromOffset(16, GRID_Y))
	self.grid = grid
	self.items = {}
	local tiers = {}
	for key, r in Shop.RARITIES do
		table.insert(tiers, { key = key, r = r })
	end
	table.sort(tiers, function(a, b)
		return a.r.order < b.r.order
	end)
	for c, tier in tiers do
		local x = (c - 1) * (CARD_W + GAP)
		local col = frame(grid, tier.r.name, UDim2.fromOffset(CARD_W, GRID_H), UDim2.fromOffset(x, 0))
		local head = label(col, "Head", string.upper(tier.r.name), UDim2.new(1, 0, 0, TIER_HEAD - 6), UDim2.new(), Ui.TITLE, 22,
			tier.r.color, Enum.TextXAlignment.Center)
		Ui.chunky(head, 2)
		local rule = frame(col, "Rule", UDim2.new(1, -16, 0, 4), UDim2.fromOffset(8, TIER_HEAD - 5))
		rule.BackgroundTransparency = 0
		rule.BackgroundColor3 = tier.r.color
		corner(rule, 2)
		if c > 1 then -- the divider between this column and the one before
			local div = frame(grid, "Divider", UDim2.fromOffset(2, GRID_H - 6), UDim2.fromOffset(x - GAP / 2 - 1, 4))
			div.BackgroundTransparency = 0.55
			div.BackgroundColor3 = T.white
		end
		local list = Instance.new("ScrollingFrame")
		list.Name = "Cards"
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.Size = UDim2.fromOffset(CARD_W, GRID_H - TIER_HEAD - 8)
		list.Position = UDim2.fromOffset(0, TIER_HEAD + 8)
		list.ScrollBarThickness = 4
		list.ScrollingDirection = Enum.ScrollingDirection.Y
		list.ClipsDescendants = true
		list.Parent = col
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, GAP)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = list
		local n = 0
		for i, def in AbilityBar.CARDS do
			if Shop.byId[def.id] and (Shop.byId[def.id].rarity or "common") == tier.key then
				n += 1
				local it = self:buildItem(list, i, def)
				it.frame.Size = UDim2.fromOffset(CARD_W, CARD_H)
				self.items[def.id] = it
			end
		end
		list.CanvasSize = UDim2.fromOffset(0, n * CARD_H + math.max(n - 1, 0) * GAP)
		list.ScrollingEnabled = n > 2
		if n == 0 then
			local none = label(col, "None", "Coming soon", UDim2.new(1, 0, 0, 30), UDim2.fromOffset(0, TIER_HEAD + 40), BOLD, 18, T.muted,
				Enum.TextXAlignment.Center)
			none.TextTransparency = 0.2
		end
	end

	-- VIP tab ------------------------------------------------------------------------------------------
	local vipTab = frame(body, "Vip", UDim2.fromOffset(W - 32, GRID_H), UDim2.fromOffset(16, GRID_Y))
	vipTab.Visible = false
	self.vipTab = vipTab
	self:buildVip(vipTab)

	-- category tabs along the bottom (like Food / Swords / Boosts) --------------------------------------
	local tabs = frame(body, "Tabs", UDim2.new(1, -32, 0, TABS_H), UDim2.new(0, 16, 1, -TABS_H - 14))
	Ui.list(tabs, 12, true)
	self.tabsRow = tabs
	local _, abilitiesTab = button(tabs, "AbilitiesTab", "Abilities", UDim2.fromOffset(200, TABS_H), "primary", function()
		self:showTab("abilities")
	end, I.Abilities)
	abilitiesTab.Parent.LayoutOrder = 1
	local _, vipTabB = button(tabs, "VipTab", "VIP", UDim2.fromOffset(200, TABS_H), "secondary", function()
		self:showTab("vip")
	end, I.vip)
	vipTabB.Parent.LayoutOrder = 2
	for _, b in { abilitiesTab, vipTabB } do
		b.TextSize = 22
		setText(b, b.Text)
	end
	self.tabButtons = { abilities = abilitiesTab, vip = vipTabB }

	-- the detail view, and its Back button (in the tabs' place)
	self:buildDetail(body)
	local back = frame(body, "Back", UDim2.new(1, -32, 0, TABS_H), UDim2.new(0, 16, 1, -TABS_H - 14))
	back.Visible = false
	Ui.list(back, 12, true)
	local _, backB = button(back, "BackButton", "Back", UDim2.fromOffset(200, TABS_H), "secondary", function()
		self:closeDetail()
	end, I.back)
	backB.TextSize = 22
	setText(backB, "Back", I.back)
	self.backRow, self.backFace = back, backB
	holder:GetPropertyChangedSignal("Visible"):Connect(function()
		if not holder.Visible then
			self:closeDetail()
		end
	end)
	self:showTab("abilities")
	return self
end

-- One ability card: the piece's colour as a two-tone gradient, the ability name and "tap for info" on
-- the left, the piece big on the right, the price and Buy along the bottom. (Its rarity is the column
-- it sits in.) The rules aren't on the
-- card (too small to read on a phone): tapping the card opens its detail view.
function ShopPanel:buildItem(parent, order, def)
	local item = Instance.new("TextButton")
	item.Name = def.id
	item.Text = ""
	item.AutoButtonColor = false
	item.LayoutOrder = order
	item.BackgroundColor3 = T.white
	item.Parent = parent
	corner(item, 14)
	Ui.gradient(item, def.accent:Lerp(T.white, 0.12), def.accent:Lerp(T.ink, 0.45))
	local ring = stroke(item, T.ink, 3.5)
	local scale = Instance.new("UIScale")
	scale.Parent = item
	item.Activated:Connect(function()
		Sounds.play("click")
		self:openDetail(def.id)
	end)

	-- the piece, big on the right, on a soft glow
	local glow = frame(item, "Glow", UDim2.fromOffset(80, 80), UDim2.new(1, -54, 0, 40))
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.BackgroundColor3 = T.white
	glow.BackgroundTransparency = 0.78
	corner(glow, 40)
	local piece = PieceIcons.new(def.piece, "w")
	piece.Name = "Piece"
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	piece.Size = UDim2.fromOffset(84, 84)
	piece.Position = UDim2.new(1, -54, 0, 38)
	piece.Rotation = 8
	piece.Parent = item

	local name = label(item, "Name", def.name, UDim2.fromOffset(CARD_W - 110, 32), UDim2.fromOffset(12, 10), Ui.TITLE, 28, T.white)
	name.TextTruncate = Enum.TextTruncate.None
	fitLine(name, CARD_W - 110, 28)
	Ui.chunky(name, 2.5)
	-- "tap for info" (the piece's name is left to the picture: a kicker was too small to read on a phone)
	local info = label(item, "Info", "TAP FOR INFO", UDim2.fromOffset(112, 24), UDim2.fromOffset(12, 46), HEAVY, 14, T.white, Enum.TextXAlignment.Center)
	info.BackgroundColor3 = T.ink
	info.BackgroundTransparency = 0.45
	corner(info, 12)

	-- bottom row: the coin price and the Robux price, both buttons (or OWNED / FREE)
	local shopItem = Shop.byId[def.id]
	local owned = label(item, "Owned", "OWNED", UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 1, -46), Ui.TITLE, 22, rgb(140, 240, 110), Enum.TextXAlignment.Center)
	Ui.chunky(owned, 2.5)
	owned.BackgroundColor3 = T.ink
	owned.BackgroundTransparency = 0.35
	corner(owned, 18)
	setText(owned, if shopItem.free then "FREE · OWNED" else "OWNED", I.yes)
	owned.Visible = false
	local half = (CARD_W - 28) / 2
	local buyH, buy, robuxH, robux = self:buyButtons(item, def.id, half, 40, 21)
	buyH.AnchorPoint = Vector2.new(0, 1)
	buyH.Position = UDim2.new(0, 10, 1, -8)
	robuxH.AnchorPoint = Vector2.new(1, 1)
	robuxH.Position = UDim2.new(1, -10, 1, -8)
	-- (how many coins are missing is only shown in the detail view: on the card it covered the piece)
	local need = label(item, "Need", "", UDim2.fromOffset(0, 0), UDim2.new(), HEAVY, 12, MISSING)
	need.Size = UDim2.new()
	need.TextTransparency = 1

	item.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.03 }):Play()
	end)
	item.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	return { frame = item, ring = ring, scale = scale, owned = owned, buyHolder = buyH, buy = buy, robuxHolder = robuxH,
		robux = robux, need = need, def = def }
end

-- the coin button and the Robux button for an ability (its card and the detail view both have them)
function ShopPanel:buyButtons(parent, id, w, h, textSize)
	local shopItem = Shop.byId[id]
	local buyH, buy = button(parent, "Buy", Shop.format(Shop.price(id) or 0), UDim2.fromOffset(w, h), "primary", function()
		self:tapBuy(id)
	end, I.coin)
	buy.TextSize = textSize
	local robuxH, robux = button(parent, "Robux", tostring(shopItem.robux or ""), UDim2.fromOffset(w, h), "blue", function()
		if shopItem.pass and not table.find(self.wallet.owned, id) then
			self.cb.buyPass(shopItem.pass)
		end
	end, Ui.ROBUX)
	robux.TextSize = textSize
	if shopItem.pass then -- the live price, once it loads
		task.spawn(function()
			local price = self.passPrices[shopItem.pass]
			if not price then
				local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, shopItem.pass, Enum.InfoType.GamePass)
				if ok and info and type(info.PriceInRobux) == "number" then
					price = info.PriceInRobux
					self.passPrices[shopItem.pass] = price
				end
			end
			if price then
				setText(robux, tostring(price))
			end
		end)
	end
	return buyH, buy, robuxH, robux
end

-- The detail view (a card was tapped) takes the grid's place: a looping demo of the ability on a
-- little board on the left; the name, the rules and the buy buttons on the right. Back replaces the
-- tabs along the bottom.
local DETAIL_Y = 62
local DETAIL_H = H - DETAIL_Y - TABS_H - 14 - 12
local DEMO_SIDE = 255

function ShopPanel:buildDetail(body)
	local d = frame(body, "Detail", UDim2.fromOffset(W - 32, DETAIL_H), UDim2.fromOffset(16, DETAIL_Y))
	d.BackgroundTransparency = 0
	d.BackgroundColor3 = T.white
	d.Visible = false
	corner(d, 14)
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Parent = d
	stroke(d, T.ink, 3.5)
	self.detail = { frame = d, grad = grad, buttons = {} }
	local D = self.detail

	D.demo = AbilityDemo.new(d, DEMO_SIDE, UDim2.fromOffset(18, 16))

	local x = DEMO_SIDE + 44
	local colW = W - 32 - x - 16
	local half = (colW - 12) / 2
	D.x, D.half = x, half
	-- the piece, top right, on its glow
	local glow = frame(d, "Glow", UDim2.fromOffset(84, 84), UDim2.new(1, -60, 0, 56))
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.BackgroundColor3 = T.white
	glow.BackgroundTransparency = 0.78
	corner(glow, 42)
	local name = label(d, "Name", "", UDim2.fromOffset(colW - 100, 46), UDim2.fromOffset(x, 14), Ui.TITLE, 40, T.white)
	name.TextTruncate = Enum.TextTruncate.None
	Ui.chunky(name, 3)
	D.nameW = colW - 100
	D.name = name
	local kicker = label(d, "Kicker", "", UDim2.fromOffset(colW - 90, 20), UDim2.fromOffset(x + 2, 62), HEAVY, 17, T.white)
	kicker.TextTransparency = 0.2
	kicker.RichText = true -- (the rarity is in its tier's colour)
	D.kicker = kicker
	local info = label(d, "Info", "", UDim2.fromOffset(colW, 150), UDim2.fromOffset(x + 2, 94), BOLD, 24, T.white)
	info.TextWrapped = true
	info.TextScaled = true -- (up to 24: the longest rules shrink a little to fit)
	local infoCap = Instance.new("UITextSizeConstraint")
	infoCap.MaxTextSize = 24
	infoCap.Parent = info
	info.TextTruncate = Enum.TextTruncate.None
	info.TextYAlignment = Enum.TextYAlignment.Top
	Ui.chunky(info, 1)
	D.info = info

	-- the bottom of the column: the buy buttons (or OWNED), "Need N more coins" above them
	local owned = label(d, "Owned", "OWNED", UDim2.fromOffset(colW, 50), UDim2.new(0, x, 1, -66), Ui.TITLE, 26, rgb(140, 240, 110), Enum.TextXAlignment.Center)
	Ui.chunky(owned, 2.5)
	owned.BackgroundColor3 = T.ink
	owned.BackgroundTransparency = 0.35
	corner(owned, 25)
	owned.Visible = false
	D.owned = owned
	local need = label(d, "Need", "", UDim2.fromOffset(colW, 18), UDim2.new(0, x, 1, -88), HEAVY, 16, MISSING, Enum.TextXAlignment.Center)
	need.TextStrokeTransparency = 0.4
	D.need = need
end

function ShopPanel:openDetail(id)
	local D = self.detail
	local def = self.items[id].def
	local shopItem = Shop.byId[id]
	self.confirm = nil
	self.detailId = id
	D.grad.Color = ColorSequence.new(def.accent:Lerp(T.white, 0.05), def.accent:Lerp(T.ink, 0.55))
	D.name.Text = def.name
	fitLine(D.name, D.nameW, 40)
	local rarity = Shop.rarity(def.id)
	D.kicker.Text = string.format('<font color="#%s">%s</font>  ·  %s  ·  ONCE A GAME', rarity.color:ToHex(), string.upper(rarity.name),
		string.upper(def.pieceName))
	D.info.Text = shopItem.info or ""
	if D.piece then
		D.piece:Destroy()
	end
	local piece = PieceIcons.new(def.piece, "w")
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	piece.Size = UDim2.fromOffset(92, 92)
	piece.Position = UDim2.new(1, -60, 0, 54)
	piece.Rotation = 8
	piece.Parent = D.frame
	D.piece = piece
	-- this ability's buttons (made the first time it's opened; the others are hidden)
	if not D.buttons[id] then
		local buyH, buy, robuxH, robux = self:buyButtons(D.frame, id, D.half, 50, 24)
		buyH.Position = UDim2.new(0, D.x, 1, -64)
		robuxH.Position = UDim2.new(0, D.x + D.half + 12, 1, -64)
		D.buttons[id] = { buyHolder = buyH, buy = buy, robuxHolder = robuxH, robux = robux }
	end
	for bid, set in D.buttons do
		if bid ~= id then
			set.buyHolder.Visible = false
			set.robuxHolder.Visible = false
		end
	end
	self.grid.Visible = false
	self.hint.Visible = false
	self.tabsRow.Visible = false
	self.backRow.Visible = true
	D.frame.Visible = true
	D.demo:play(id)
	self:cancelConfirm() -- (refreshes)
end

function ShopPanel:closeDetail()
	if not self.detailId then
		return
	end
	self.detailId = nil
	self.detail.demo:stop()
	self.detail.frame.Visible = false
	self.backRow.Visible = false
	self.tabsRow.Visible = true
	self.grid.Visible = self.tab == "abilities"
	self.hint.Visible = self.tab == "abilities"
	self:cancelConfirm()
end

-- The VIP tab: the VIP pass (Robux), one card in the middle.
function ShopPanel:buildVip(parent)
	local half = (W - 32 - GAP) / 2
	local vip = frame(parent, "VipPass", UDim2.new(0, half, 1, 0), UDim2.fromScale(0.5, 0))
	vip.AnchorPoint = Vector2.new(0.5, 0)
	vip.BackgroundColor3 = T.white
	vip.BackgroundTransparency = 0
	corner(vip, 14)
	Ui.gradient(vip, rgb(255, 222, 102), rgb(244, 150, 28))
	stroke(vip, T.ink, 3.5)
	Ui.icon(vip, I.vip, 110, UDim2.new(0.5, 0, 0, 14), Vector2.new(0.5, 0))
	local title = label(vip, "Title", "VIP", UDim2.new(1, -20, 0, 50), UDim2.fromOffset(10, 124), Ui.TITLE, 48, T.white, Enum.TextXAlignment.Center)
	Ui.chunky(title, 3.5)
	local perks = label(vip, "Perks", "Detailed stats  ·  Saved game reviews  ·  Tournaments (soon)", UDim2.new(1, -28, 0, 40),
		UDim2.fromOffset(14, 176), BOLD, 15, rgb(94, 46, 4), Enum.TextXAlignment.Center)
	perks.TextWrapped = true
	perks.TextTruncate = Enum.TextTruncate.None
	local buyH, buy = button(vip, "BuyVip", tostring(VIP_PRICE), UDim2.new(1, -40, 0, 54), "primary", function()
		if not self.wallet.vip then
			self.cb.buyVip()
		end
	end, Ui.ROBUX)
	buyH.AnchorPoint = Vector2.new(0.5, 1)
	buyH.Position = UDim2.new(0.5, 0, 1, -14)
	buy.TextSize = 28
	self.vipBuy = buy
	self.vipPrice = VIP_PRICE
	task.spawn(function()
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, Settings.VIP_PASS, Enum.InfoType.GamePass)
		if ok and info and type(info.PriceInRobux) == "number" then
			self.vipPrice = info.PriceInRobux
			self:refresh()
		end
	end)

end

function ShopPanel:showTab(which)
	self.tab = which
	self:closeDetail()
	self.grid.Visible = which == "abilities"
	self.vipTab.Visible = which == "vip"
	self.hint.Visible = which == "abilities"
	for id, b in self.tabButtons do
		Ui.restyle(b, if id == which then (if id == "vip" then "gold" else "primary") else "secondary")
	end
	self:cancelConfirm()
end

local function owns(self, id)
	return table.find(self.wallet.owned, id) ~= nil
end

function ShopPanel:cancelConfirm()
	self.confirm = nil
	self.confirmToken = (self.confirmToken or 0) + 1
	self:refresh()
end

-- first tap arms the card ("Sure?"), the second buys; can't afford -> say how many coins are missing
function ShopPanel:tapBuy(id)
	if self.buying or owns(self, id) then
		return
	end
	local price = Shop.price(id)
	if not price then
		return
	end
	if self.wallet.coins < price then
		self.cb.toast(string.format("You need %s more coins: win 1v1 games to earn them", Shop.format(price - self.wallet.coins)))
		return
	end
	if self.confirm ~= id then
		self.confirm = id
		self.confirmToken = (self.confirmToken or 0) + 1
		local token = self.confirmToken
		self:refresh()
		task.delay(CONFIRM_TIME, function()
			if self.confirmToken == token then
				self:cancelConfirm()
			end
		end)
		return
	end
	self.confirm = nil
	self.buying = id
	self:refresh()
	task.spawn(function()
		local ok, res = self.cb.buy(id)
		self.buying = nil
		if ok and type(res) == "table" then
			self:setWallet(res)
			Sounds.play("good")
			self.cb.toast(self.items[id].def.name .. " unlocked! Use it in Abilities games.")
			local item = self.items[id]
			item.scale.Scale = 1.12
			TweenService:Create(item.scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		else
			self.cb.toast(if res == "not enough coins" then "Not enough coins" else "Couldn't buy that, try again")
			self:refresh()
		end
	end)
end

function ShopPanel:setWallet(w)
	if type(w) ~= "table" then
		return
	end
	local before = self.wallet.coins
	self.wallet = { coins = w.coins or 0, owned = w.owned or {}, vip = if w.vip ~= nil then w.vip else self.wallet.vip }
	if self.wallet.coins ~= before and self.holder.Visible then
		self.balanceScale.Scale = 1.2
		TweenService:Create(self.balanceScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	self:refresh()
end

-- one ability's buttons (on its card, or in the detail view)
local function refreshButtons(self, id, set)
	local have = owns(self, id)
	local price = Shop.price(id) or 0
	local short = price - self.wallet.coins
	set.owned.Visible = have
	set.buyHolder.Visible = not have
	set.robuxHolder.Visible = not have
	set.need.Visible = not have and short > 0
	set.need.Text = string.format("Need %s more coins", Shop.format(short))
	if not have then
		if self.buying == id or self.confirm == id then
			Ui.restyle(set.buy, "gold")
			setText(set.buy, if self.buying == id then "…" else "Sure?", "")
		else
			Ui.restyle(set.buy, if short > 0 then "locked" else "primary")
			setText(set.buy, Shop.format(price), I.coin)
		end
	end
end

function ShopPanel:refresh()
	self.balance.Text = Shop.format(self.wallet.coins)
	for id, item in self.items do
		refreshButtons(self, id, item)
		item.ring.Color = if owns(self, id) then rgb(140, 240, 110) else T.ink
	end
	local id = self.detailId
	if id and self.detail then
		local D, set = self.detail, self.detail.buttons[id]
		refreshButtons(self, id, { owned = D.owned, need = D.need, buyHolder = set.buyHolder, buy = set.buy, robuxHolder = set.robuxHolder })
		setText(D.owned, if Shop.byId[id].free then "FREE · OWNED" else "OWNED", I.yes)
	end
	if self.vipBuy then
		if self.wallet.vip then
			Ui.restyle(self.vipBuy, "secondary")
			setText(self.vipBuy, "OWNED", I.yes)
		else
			Ui.restyle(self.vipBuy, "primary")
			setText(self.vipBuy, tostring(self.vipPrice), Ui.ROBUX)
		end
	end
end

return ShopPanel
