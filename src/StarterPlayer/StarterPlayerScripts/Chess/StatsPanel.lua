-- The Stats card (opened from the lobby). Everyone sees their total wins / draws / losses against
-- other players as three big tiles down the left (games against bots aren't counted: old "*_bot"
-- buckets and detail.bots in saved data are ignored). VIPs (Settings.VIP_PASS) also get the detailed
-- stats beside them and a "Saved games" tab: every game they reviewed, which they can open in the
-- review again. Others see the VIP offer there instead: a gold card with the perks and the price in
-- Robux. The Leaderboard tab (everyone) shows the global top 10 of Most wins and Champions side by
-- side (rank, headshot, name, count; your own row in green) and your own counts underneath. It loads
-- when the tab is opened and again after LB_CACHE seconds. Landscape, so it fits a phone; fixed sizes
-- only (no AutomaticSize), like every other card.
--
--   StatsPanel.new(gui, cb, levels) -> panel      cb = { close(), reviewSaved(id), buyVip(),
--                                                 fetchLeaderboard(board) -> data|nil (yields) }
--                                                 (levels is kept for the caller but unused now)
--   panel:setLoading() / panel:show(data)         data = { results, vip, games } from the server
--   leaderboard data (board = "wins" | "titles"): { board, top = { { rank, userId, name, value } },
--                                                 mine = { wins, titles } }
--   panel.holder (show / hide it), panel.closeFace (controller focus)

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Settings = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Settings"))
local Ui = require(script.Parent.UiKit)
local T, BOLD, HEAVY = Ui.T, Ui.BOLD, Ui.HEAVY
local corner, stroke, card, label, button, list = Ui.corner, Ui.stroke, Ui.card, Ui.label, Ui.button, Ui.list
local I, setText = Ui.ICONS, Ui.setText

local StatsPanel = {}
StatsPanel.__index = StatsPanel

local W, H = 720, 410
local TILES_W = 180 -- the W / D / L column
local CONTENT_Y = 114
local CONTENT_H = H - CONTENT_Y - 16
local ROW = 56 -- 5 rows fill the content height, level with the tiles
local SAVED_ROW = 58
local VIP_PRICE = 400 -- shown until the pass's real price loads
local LB_HEAD = 38 -- a board's title bar
local LB_ROW = 40
local LB_FOOT = 34 -- "You: ..." under both boards
local LB_CACHE = 60 -- seconds before the boards load again (the server caches them as long)
local BOARDS = {
	{ id = "wins", title = "Most wins", icon = I.win, style = "primary", empty = "No wins yet. Beat a player to get on the board!" },
	{ id = "titles", title = "Champions", icon = I.queen, style = "gold", empty = "No champions yet. Win a tournament to be the first!" },
}

local rgb = Color3.fromRGB
local GOLD_TOP, GOLD_BOTTOM = rgb(255, 222, 102), rgb(244, 150, 28)
local BROWN = rgb(94, 46, 4)

local function frame(parent, name, size, pos)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Size = size
	f.Position = pos or UDim2.new()
	f.Parent = parent
	return f
end

-- a rounded inner box (rows, tiles)
local function box(parent, name, size, pos, color, transparency)
	local f = frame(parent, name, size, pos)
	f.BackgroundColor3 = color or T.panelLift
	f.BackgroundTransparency = transparency or 0
	corner(f, 12)
	return f
end

local function wdl(s)
	s = s or { w = 0, l = 0, d = 0 }
	return string.format("%dW  %dD  %dL", s.w or 0, s.d or 0, s.l or 0)
end

-- The VIP offer (not VIP yet): a gold card with light rays turning behind a bobbing crown, a
-- FOREVER tag, the three perks and a green Robux button that shines and bounces now and then.
local function buildOffer(self, parent, size, pos)
	-- (no ClipsDescendants: Roblox doesn't draw rotated things inside a clipping frame, so the rays
	-- are short enough to fade out inside the card instead)
	local offer = box(parent, "Upsell", size, pos, T.white)
	corner(offer, 16)
	Ui.gradient(offer, GOLD_TOP, GOLD_BOTTOM)
	stroke(offer, T.ink, 4)
	self.upsell = offer
	local anims = {}

	-- rays: thin bars through the crown's centre, brightest in the middle, turning slowly
	local CROWN = UDim2.fromOffset(88, 112)
	local rays = frame(offer, "Rays", UDim2.fromOffset(0, 0), CROWN)
	for i = 0, 11 do
		local r = Instance.new("Frame")
		r.Name = "Ray"
		r.AnchorPoint = Vector2.new(0.5, 0.5)
		r.Size = UDim2.fromOffset(28, 200)
		r.Rotation = i * 15
		r.BackgroundColor3 = T.white
		r.BorderSizePixel = 0
		r.Parent = rays
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.15, 0.6),
			NumberSequenceKeypoint.new(0.5, 0.15),
			NumberSequenceKeypoint.new(0.85, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = r
	end
	table.insert(anims, TweenService:Create(rays, TweenInfo.new(24, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 }))
	local glow = frame(offer, "Glow", UDim2.fromOffset(124, 124), CROWN)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.BackgroundColor3 = T.white
	glow.BackgroundTransparency = 0.45
	corner(glow, 62)
	local crown = Ui.icon(offer, I.vip, 120, CROWN, Vector2.new(0.5, 0.5))
	crown.Rotation = -6
	table.insert(anims, TweenService:Create(crown, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = CROWN + UDim2.fromOffset(0, -7), Rotation = 6 }))

	-- the words: kicker, big VIP, what it is
	local textX = 182
	local kicker = label(offer, "Kicker", Ui.spaced("Unlock"), UDim2.new(1, -textX - 110, 0, 20), UDim2.fromOffset(textX, 14), Ui.TITLE, 16, BROWN)
	kicker.TextTransparency = 0.15
	local title = label(offer, "Title", "VIP", UDim2.new(1, -textX - 16, 0, 58), UDim2.fromOffset(textX - 2, 28), Ui.TITLE, 60, T.white)
	Ui.chunky(title, 4)
	local tag = label(offer, "Forever", "FOREVER", UDim2.fromOffset(118, 32), UDim2.new(1, -14, 0, 18), Ui.TITLE, 18, T.white, Enum.TextXAlignment.Center)
	tag.AnchorPoint = Vector2.new(1, 0)
	tag.Rotation = 8
	tag.BackgroundColor3 = T.red
	tag.BackgroundTransparency = 0
	corner(tag, 10)
	stroke(tag, T.ink, 2.5)
	Ui.chunky(tag, 2)

	-- perks: icon + one line each
	local perks = frame(offer, "Perks", UDim2.new(1, -textX - 14, 0, 3 * 30), UDim2.fromOffset(textX, 92))
	list(perks, 2).HorizontalAlignment = Enum.HorizontalAlignment.Left
	for i, p in { { I.fire, "Win streaks and stats per mode" }, { I.target, "Your accuracy and brilliant moves" },
		{ I.save, "Every game you review, saved" } } do
		local r = frame(perks, "Perk" .. i, UDim2.new(1, 0, 0, 28))
		r.LayoutOrder = i
		Ui.icon(r, p[1], 26, UDim2.new(0, 0, 0.5, 0), Vector2.new(0, 0.5))
		label(r, "Text", p[2], UDim2.new(1, -36, 1, 0), UDim2.fromOffset(34, 0), HEAVY, 18, BROWN)
	end

	-- the buy button (in a wrapper, so its bounce doesn't fight the button's own press squash)
	local wrap = frame(offer, "Buy", UDim2.new(1, -32, 0, 66), UDim2.new(0.5, 0, 1, -14))
	wrap.AnchorPoint = Vector2.new(0.5, 1)
	local bounce = Instance.new("UIScale")
	bounce.Parent = wrap
	local _, buy = button(wrap, "GetVip", "", UDim2.fromScale(1, 1), "primary", function()
		self.cb.buyVip()
	end)
	buy.TextSize = 34
	buy.Outline.Thickness = 3
	self.buyFace = buy
	self:setPrice(VIP_PRICE)
	self.bounceTween = TweenService:Create(bounce, TweenInfo.new(0.32, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 2.2),
		{ Scale = 1.05 })
	table.insert(anims, self.bounceTween)
	-- a light streak sweeping across the button
	local clip = frame(buy, "ShineClip", UDim2.fromScale(1, 1))
	clip.ClipsDescendants = true
	local shine = frame(clip, "Shine", UDim2.new(0, 120, 1, 0), UDim2.new(-0.3, 0, 0, 0))
	shine.BackgroundColor3 = T.white
	shine.BackgroundTransparency = 0
	local sg = Instance.new("UIGradient")
	sg.Rotation = 20
	sg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	sg.Parent = shine
	table.insert(anims, TweenService:Create(shine, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, false, 2.4),
		{ Position = UDim2.new(1.1, 0, 0, 0) }))
	self.offerAnims = anims
	self.offerBounce = bounce
end

function StatsPanel.new(gui, cb, levels)
	local self = setmetatable({}, StatsPanel)
	self.cb = cb
	self.levels = levels
	local holder, body = card(gui, "StatsCard", UDim2.fromOffset(W, H), UDim2.fromScale(0.5, 0.47), Vector2.new(0.5, 0.5))
	holder.Visible = false
	self.holder = holder
	Ui.header(body, "Your stats", nil, nil, I.stats)
	local _, close = Ui.closeX(body, function()
		cb.close()
	end)
	self.closeFace = close
	-- VIPs get a gold badge in the title bar
	local badge = label(body, "VipBadge", "VIP", UDim2.fromOffset(96, 34), UDim2.new(0, 14, 0, 27), Ui.TITLE, 20, T.white, Enum.TextXAlignment.Center)
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.BackgroundColor3 = T.gold
	badge.BackgroundTransparency = 0
	badge.ZIndex = 3
	corner(badge, 17)
	stroke(badge, T.ink, 2.5)
	Ui.chunky(badge, 2)
	setText(badge, "VIP", I.vip)
	badge.Visible = false
	self.vipBadge = badge

	-- tabs
	local tabs = frame(body, "Tabs", UDim2.new(1, -40, 0, 42), UDim2.fromOffset(20, 64))
	local tl = list(tabs, 10, true)
	tl.HorizontalAlignment = Enum.HorizontalAlignment.Left
	local _, overviewTab = button(tabs, "Overview", "Overview", UDim2.fromOffset(170, 42), "primary", function()
		self:setTab("overview")
	end, I.stats)
	local _, savedTab = button(tabs, "Saved", "Saved games", UDim2.fromOffset(210, 42), "secondary", function()
		self:setTab("saved")
	end, I.save)
	local _, boardTab = button(tabs, "Leaderboard", "Leaderboard", UDim2.fromOffset(200, 42), "secondary", function()
		self:setTab("leaderboard")
	end, I.queen)
	overviewTab.TextSize, savedTab.TextSize, boardTab.TextSize = 17, 17, 17
	setText(overviewTab, "Overview")
	setText(savedTab, "Saved games")
	setText(boardTab, "Leaderboard")
	self.tabFaces = { overview = overviewTab, saved = savedTab, leaderboard = boardTab }

	local content = UDim2.new(1, -40, 0, CONTENT_H)
	local contentPos = UDim2.fromOffset(20, CONTENT_Y)

	-- Overview: three big tiles down the left, then the VIP details (or the VIP offer) --------------
	local overview = frame(body, "Overview", content, contentPos)
	self.overview = overview
	local tiles = frame(overview, "Tiles", UDim2.new(0, TILES_W, 1, 0))
	list(tiles, 8)
	self.tiles = {}
	for i, t in { { "w", "Wins", I.win, "primary" }, { "d", "Draws", I.tie, "secondary" }, { "l", "Losses", I.lose, "red" } } do
		local tile = box(tiles, t[1], UDim2.new(1, 0, 1 / 3, -6), nil, Ui.STYLES[t[4]].face)
		tile.LayoutOrder = i
		stroke(tile, T.ink, 3)
		Ui.highlight(tile, 12)
		Ui.icon(tile, t[3], 48, UDim2.new(0, 10, 0.5, 0), Vector2.new(0, 0.5))
		local n = label(tile, "Count", "–", UDim2.new(1, -72, 0, 44), UDim2.fromOffset(64, 6), Ui.TITLE, 42, T.white, Enum.TextXAlignment.Center)
		Ui.chunky(n, 3)
		local cap = label(tile, "Caption", t[2], UDim2.new(1, -72, 0, 24), UDim2.new(0, 64, 1, -32), Ui.TITLE, 20, T.white, Enum.TextXAlignment.Center)
		Ui.chunky(cap, 2)
		self.tiles[t[1]] = n
	end

	local rightX = TILES_W + 10
	local rightSize, rightPos = UDim2.new(1, -rightX, 1, 0), UDim2.fromOffset(rightX, 0)

	-- VIP details: two columns of five rows (icon, label, value)
	local detail = frame(overview, "Detail", rightSize, rightPos)
	self.detail = detail
	self.rows = {}
	local function row(col, i, key, icon, text)
		local r = box(detail, key, UDim2.new(0.5, -5, 0, ROW - 4), UDim2.new(col * 0.5, col * 5, 0, (i - 1) * ROW), T.panelLift, if i % 2 == 1 then 0 else 0.45)
		Ui.icon(r, icon, 24, UDim2.new(0, 8, 0.5, 0), Vector2.new(0, 0.5))
		label(r, "Label", text, UDim2.new(1, -140, 1, 0), UDim2.fromOffset(38, 0), BOLD, 16, T.muted)
		local v = label(r, "Value", "–", UDim2.new(0, 100, 1, 0), UDim2.new(1, -108, 0, 0), Ui.TITLE, 18, T.white, Enum.TextXAlignment.Right)
		Ui.chunky(v, 1.5)
		self.rows[key] = v
	end
	row(0, 1, "rate", I.target, "Win rate")
	row(0, 2, "streak", I.fire, "Win streak")
	row(0, 3, "best", I.fire, "Best streak")
	row(0, 4, "games", I.gamepad, "Games")
	row(0, 5, "length", I.clock, "Avg. game")
	row(1, 1, "Classic", I.Classic, "Classic")
	row(1, 2, "Abilities", I.Abilities, "Abilities")
	row(1, 3, "mates", I.win, "Checkmates")
	row(1, 4, "accuracy", I.review, "Accuracy")
	row(1, 5, "brilliant", I.Abilities, "Brilliant")

	-- not VIP: the offer
	buildOffer(self, overview, rightSize, rightPos)
	-- the pass's real price, once it loads
	task.spawn(function()
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, Settings.VIP_PASS, Enum.InfoType.GamePass)
		if ok and info and type(info.PriceInRobux) == "number" then
			self:setPrice(info.PriceInRobux)
		end
	end)

	-- Saved games (VIP): a scrolling list, newest first -----------------------------------------------
	local saved = frame(body, "Saved", content, contentPos)
	saved.Visible = false
	self.saved = saved
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "List"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = T.muted
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Parent = saved
	local sl = list(scroll, 6)
	sl.VerticalAlignment = Enum.VerticalAlignment.Top
	self.savedScroll = scroll
	local empty = label(saved, "Empty", "", UDim2.new(1, -40, 0, 80), UDim2.fromOffset(20, 40), BOLD, 18, T.muted, Enum.TextXAlignment.Center)
	empty.TextWrapped = true
	self.savedEmpty = empty

	-- Leaderboard: two boards side by side, your counts underneath --------------------------------------
	local boards = frame(body, "Leaderboard", content, contentPos)
	boards.Visible = false
	self.boards = boards
	self.boardLists = {}
	for i, b in BOARDS do
		local col = frame(boards, b.id, UDim2.new(0.5, -5, 1, -(LB_FOOT + 8)), UDim2.new((i - 1) * 0.5, (i - 1) * 5, 0, 0))
		local head = box(col, "Head", UDim2.new(1, 0, 0, LB_HEAD), nil, Ui.STYLES[b.style].face)
		stroke(head, T.ink, 2.5)
		Ui.highlight(head, 12)
		Ui.icon(head, b.icon, 28, UDim2.new(0, 10, 0.5, 0), Vector2.new(0, 0.5))
		local title = label(head, "Title", b.title, UDim2.new(1, -56, 1, 0), UDim2.fromOffset(46, 0), Ui.TITLE, 20, T.white)
		Ui.chunky(title, 2)
		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "List"
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.Position = UDim2.fromOffset(0, LB_HEAD + 6)
		scroll.Size = UDim2.new(1, 0, 1, -(LB_HEAD + 6))
		scroll.ScrollBarThickness = 6
		scroll.ScrollBarImageColor3 = T.muted
		scroll.CanvasSize = UDim2.new()
		scroll.ScrollingDirection = Enum.ScrollingDirection.Y
		scroll.Parent = col
		local sl = list(scroll, 4)
		sl.VerticalAlignment = Enum.VerticalAlignment.Top
		local note = label(col, "Note", "", UDim2.new(1, -24, 0, 60), UDim2.fromOffset(12, LB_HEAD + 30), BOLD, 16, T.muted, Enum.TextXAlignment.Center)
		note.TextWrapped = true
		note.TextTruncate = Enum.TextTruncate.None
		self.boardLists[b.id] = { scroll = scroll, note = note, spec = b }
	end
	local foot = box(boards, "You", UDim2.new(1, 0, 0, LB_FOOT), UDim2.new(0, 0, 1, -LB_FOOT), T.panelLift)
	Ui.icon(foot, I.user, 22, UDim2.new(0, 10, 0.5, 0), Vector2.new(0, 0.5))
	local mine = label(foot, "Mine", "", UDim2.new(1, -48, 1, 0), UDim2.fromOffset(40, 0), Ui.TITLE, 18, T.white)
	Ui.chunky(mine, 1.5)
	self.mineLabel = mine

	holder:GetPropertyChangedSignal("Visible"):Connect(function()
		self:animateOffer(holder.Visible and self.upsell.Visible)
	end)
	self.status = label(body, "Status", "", UDim2.new(1, -40, 0, 30), UDim2.new(0, 20, 0.5, 20), BOLD, 18, T.muted, Enum.TextXAlignment.Center)
	self:setTab("overview")
	return self
end

-- the buy button: the Robux icon and the price
function StatsPanel:setPrice(price)
	setText(self.buyFace, tostring(price), Ui.ROBUX)
end

-- the offer's animations run only while it's on screen
function StatsPanel:animateOffer(on)
	if on == self.offerPlaying then
		return
	end
	self.offerPlaying = on
	for _, tw in self.offerAnims do
		if on then
			tw:Play()
		else
			tw:Pause()
		end
	end
end

-- (a tap on the locked Saved tab) draws the eye to the buy button
function StatsPanel:nudgeOffer()
	local tw = TweenService:Create(self.offerBounce, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 1, true), { Scale = 1.12 })
	tw.Completed:Once(function()
		if self.offerPlaying then
			self.bounceTween:Play() -- (the nudge cancelled it)
		end
	end)
	tw:Play()
end

function StatsPanel:setTab(which)
	self.tab = which
	for id, face in self.tabFaces do
		Ui.restyle(face, if which == id then "primary" else "secondary")
	end
	local loaded = self.data ~= nil
	self.overview.Visible = loaded and which == "overview"
	-- the saved games are VIP only: others see the VIP card on the overview instead
	if which == "saved" and loaded and not self.data.vip then
		self:nudgeOffer()
		self.tab = "overview"
		self.overview.Visible = true
		Ui.restyle(self.tabFaces.overview, "primary")
		Ui.restyle(self.tabFaces.saved, "secondary")
	end
	self.saved.Visible = loaded and self.tab == "saved"
	-- the boards don't need the stats: they load by themselves
	self.boards.Visible = self.tab == "leaderboard"
	self.status.Visible = self.statusShown == true and self.tab ~= "leaderboard"
	if self.tab == "leaderboard" then
		self:loadBoards()
	end
end

-- fetch both boards (unless they loaded less than LB_CACHE seconds ago)
function StatsPanel:loadBoards()
	if self.boardsAt and os.clock() - self.boardsAt < LB_CACHE then
		return
	end
	self.boardsAt = os.clock()
	if not self.mineShown then
		self.mineLabel.Text = "You: …"
	end
	for id, entry in self.boardLists do
		if not entry.loaded then
			entry.note.Text = "Loading…"
		end
		task.spawn(function()
			local data = self.cb.fetchLeaderboard and self.cb.fetchLeaderboard(id)
			if type(data) == "table" then
				self:fillBoard(id, data.top)
				self:setMine(data.mine)
			else
				self.boardsAt = nil -- try again next time the tab opens
				if not entry.loaded then
					entry.note.Text = "The leaderboard isn't available right now."
				end
			end
		end)
	end
end

function StatsPanel:setMine(mine)
	if type(mine) ~= "table" then
		return
	end
	self.mineShown = true
	local w, t = mine.wins or 0, mine.titles or 0
	self.mineLabel.Text = string.format("You: %d %s  ·  %d %s", w, if w == 1 then "win" else "wins", t, if t == 1 then "title" else "titles")
end

local MEDALS = { rgb(255, 200, 61), rgb(214, 224, 232), rgb(222, 140, 74) } -- gold, silver, bronze

function StatsPanel:fillBoard(id, rows)
	local entry = self.boardLists[id]
	entry.loaded = true
	for _, c in entry.scroll:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	rows = if type(rows) == "table" then rows else {}
	entry.note.Text = if #rows == 0 then entry.spec.empty else ""
	local me = Players.LocalPlayer.UserId
	for i, r in rows do
		local rank = r.rank or i
		local isMe = r.userId == me
		local row = box(entry.scroll, "Row" .. i, UDim2.new(1, -10, 0, LB_ROW), nil, if isMe then T.greenEdge else T.panelLift,
			if isMe or i % 2 == 1 then 0 else 0.45)
		row.LayoutOrder = i
		if isMe then
			stroke(row, T.green, 2)
		end
		local n = label(row, "Rank", tostring(rank), UDim2.fromOffset(34, LB_ROW), UDim2.fromOffset(4, 0), Ui.TITLE, 19,
			MEDALS[rank] or T.muted, Enum.TextXAlignment.Center)
		Ui.chunky(n, 1.5)
		-- the headshot (fake test ids have none: a person icon instead)
		local pic = frame(row, "Head", UDim2.fromOffset(32, 32), UDim2.new(0, 40, 0.5, -16))
		pic.BackgroundColor3 = T.panelDeep
		pic.BackgroundTransparency = 0
		corner(pic, 16)
		if type(r.userId) == "number" and r.userId > 0 then
			local img = Instance.new("ImageLabel")
			img.Name = "Shot"
			img.BackgroundTransparency = 1
			img.Size = UDim2.fromScale(1, 1)
			img.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", r.userId)
			img.Parent = pic
			corner(img, 16)
		else
			Ui.icon(pic, I.user, 22, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
		end
		label(row, "Name", tostring(r.name or "?"), UDim2.new(1, -150, 1, 0), UDim2.fromOffset(80, 0), BOLD, 17, T.white)
		local v = label(row, "Value", tostring(r.value or 0), UDim2.fromOffset(60, LB_ROW), UDim2.new(1, -68, 0, 0), Ui.TITLE, 19, T.white,
			Enum.TextXAlignment.Right)
		Ui.chunky(v, 1.5)
	end
	entry.scroll.CanvasSize = UDim2.fromOffset(0, #rows * (LB_ROW + 4))
end

function StatsPanel:setLoading()
	self.data = nil
	self.status.Text = "Loading…"
	self.statusShown = true
	self:setTab(self.tab or "overview")
end

function StatsPanel:show(data)
	if data == nil then
		self.data = nil
		self.status.Text = "Stats aren't available right now."
		self.statusShown = true
		self:setTab(self.tab)
		return
	end
	self.data = data
	self.statusShown = false
	local results = data.results or {}
	local total = { w = 0, d = 0, l = 0 }
	for bucket, s in results do
		-- only games against people: skip the detail and any old "*_bot" buckets
		if bucket ~= "detail" and not string.find(bucket, "_bot$") and type(s) == "table" then
			total.w += s.w or 0
			total.d += s.d or 0
			total.l += s.l or 0
		end
	end
	for k, n in self.tiles do
		n.Text = tostring(total[k])
	end
	local games = total.w + total.d + total.l
	self.detail.Visible = data.vip
	self.upsell.Visible = not data.vip
	self.vipBadge.Visible = data.vip
	self:animateOffer(self.holder.Visible and not data.vip)
	self.tabFaces.saved.Parent.Visible = true
	setText(self.tabFaces.saved, "Saved games", if data.vip then I.save else I.lock)
	if data.vip then
		local d = results.detail or {}
		local r = self.rows
		r.rate.Text = if games > 0 then string.format("%d%%", math.floor(total.w / games * 100 + 0.5)) else "–"
		r.streak.Text = tostring(d.streak or 0)
		r.best.Text = tostring(d.bestStreak or 0)
		r.games.Text = tostring(games)
		r.length.Text = if (d.games or 0) > 0 then string.format("%d moves", math.floor(d.plies / d.games / 2 + 0.5)) else "–"
		r.mates.Text = tostring(d.winsBy and d.winsBy.checkmate or 0)
		for _, mode in Settings.MODES do
			r[mode].Text = wdl(results[mode])
		end
		local accSum, accN, brilliant = 0, 0, 0
		for _, gm in data.games or {} do
			if gm.accuracy then
				accSum += gm.accuracy
				accN += 1
			end
			brilliant += gm.counts and gm.counts.brilliant or 0
		end
		r.accuracy.Text = if accN > 0 then string.format("%.1f%%", accSum / accN) else "–"
		r.brilliant.Text = tostring(brilliant)
	end
	self:fillSaved(data.games)
	self:setTab(self.tab)
end

function StatsPanel:fillSaved(games)
	for _, c in self.savedScroll:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	games = games or {}
	self.savedEmpty.Text = if #games == 0 then "No saved games yet.\nReview a game when it ends and it's saved here." else ""
	for i, gm in games do
		local r = box(self.savedScroll, "Game" .. i, UDim2.new(1, -12, 0, SAVED_ROW), nil, T.panelLift, if i % 2 == 1 then 0 else 0.45)
		r.LayoutOrder = i
		Ui.icon(r, gm.mode, 40, UDim2.new(0, 10, 0.5, 0), Vector2.new(0, 0.5))
		local opp = if gm.myColor == "w" then gm.black else gm.white
		local who = label(r, "Who", "vs " .. tostring(opp), UDim2.new(1, -200, 0, 26), UDim2.fromOffset(60, 6), Ui.TITLE, 19, T.white)
		Ui.chunky(who, 1.5)
		local winner = gm.result and gm.result.winner
		local outcome, color
		if winner == nil then
			outcome, color = "Draw", T.muted
		elseif winner == gm.myColor then
			outcome, color = "Win", T.green
		else
			outcome, color = "Loss", T.red
		end
		local bits = { string.format('<font color="#%s"><b>%s</b></font>', color:Lerp(T.white, 0.25):ToHex(), outcome) }
		if gm.accuracy then
			table.insert(bits, string.format("%.1f%%", gm.accuracy))
		end
		table.insert(bits, string.format("%d moves", math.ceil((gm.plies or 0) / 2)))
		if gm.t then
			table.insert(bits, os.date("%d %b", gm.t))
		end
		local sub = label(r, "Sub", table.concat(bits, "  ·  "), UDim2.new(1, -200, 0, 20), UDim2.fromOffset(60, 32), BOLD, 15, T.muted)
		sub.RichText = true
		local h = button(r, "Review", "Review", UDim2.fromOffset(124, 42), "blue", function()
			self.cb.reviewSaved(gm.id)
		end, I.review)
		h.AnchorPoint = Vector2.new(1, 0.5)
		h.Position = UDim2.new(1, -10, 0.5, 0)
		h.Face.TextSize = 17
		setText(h.Face, "Review")
	end
	self.savedScroll.CanvasSize = UDim2.fromOffset(0, #games * (SAVED_ROW + 6))
end

return StatsPanel
