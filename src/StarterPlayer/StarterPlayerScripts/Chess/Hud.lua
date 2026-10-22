-- The seated HUD, built in code. Style: white cards and green buttons with a chunky darker bottom
-- edge, rounded corners and Roblox's Builder Sans: friendly, not loud. Every control is a real
-- button, so mouse, touch and controller (GuiService selection) all work. The HUD only shows state
-- and calls back; ChessClient decides.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local PieceIcons = require(script.Parent.PieceIcons)
local AbilityBar = require(script.Parent.AbilityBar)

local Hud = {}
Hud.__index = Hud

local Ui = require(script.Parent.UiKit)
local T, BOLD, HEAVY, MEDIUM = Ui.T, Ui.BOLD, Ui.HEAVY, Ui.MEDIUM
local corner, stroke, card, label, button, list = Ui.corner, Ui.stroke, Ui.card, Ui.label, Ui.button, Ui.list
local I, setText, tile, setTile = Ui.ICONS, Ui.setText, Ui.tile, Ui.setTile

-- kept short: this game is for all ages
local REASONS = {
	checkmate = "Checkmate",
	stalemate = "Stalemate",
	repetition = "Same moves 3 times",
	["fifty-move rule"] = "50 moves, no capture",
	["insufficient material"] = "Not enough pieces",
	resignation = "Resigned",
	agreement = "Agreed draw",
	timeout = "Out of time",
	["timeout vs insufficient material"] = "Out of time",
	abandoned = "Opponent left",
	aborted = "Game aborted",
}
local PIECE_NAMES = { q = "Queen", r = "Rook", b = "Bishop", n = "Knight" }

function Hud.formatTime(t: number): string
	t = math.max(0, t)
	if t < 10 then
		return string.format("0:%04.1f", t)
	end
	return string.format("%d:%02d", t // 60, math.floor(t % 60))
end

local thumbCache = {}
local function setAvatar(img, botLabel, seat)
	if seat and seat.isBot then
		img.Image = ""
		botLabel.Visible = true
		return
	end
	botLabel.Visible = false
	local id = seat and seat.userId
	if not id or id <= 0 then
		img.Image = ""
		return
	end
	if thumbCache[id] then
		img.Image = thumbCache[id]
		return
	end
	task.spawn(function()
		local ok, url = pcall(Players.GetUserThumbnailAsync, Players, id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		if ok then
			thumbCache[id] = url
			img.Image = url
		end
	end)
end

function Hud.new(cb)
	local self = setmetatable({}, Hud)
	self.cb = cb
	local gui = Instance.new("ScreenGui")
	gui.Name = "ChessHud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui
	local scale = Instance.new("UIScale")
	scale.Parent = gui

	-- player bars ---------------------------------------------------------------------------------
	local function bar(name, anchorY, posY)
		local holder, body = card(gui, name, UDim2.fromOffset(420, 100), UDim2.new(0.5, 0, anchorY, posY), Vector2.new(0.5, anchorY))
		holder.Size = UDim2.fromOffset(420, 58)
		local ring = stroke(body, T.green, 3)
		ring.Transparency = 1
		local avatar = Instance.new("ImageLabel")
		avatar.Name = "Avatar"
		avatar.Size = UDim2.fromOffset(42, 42)
		avatar.Position = UDim2.fromOffset(8, 8)
		avatar.BackgroundColor3 = T.greenSoft
		avatar.BorderSizePixel = 0
		avatar.Parent = body
		corner(avatar, 21)
		local bot = label(avatar, "Bot", "BOT", UDim2.fromScale(1, 1), UDim2.new(), HEAVY, 13, T.white, Enum.TextXAlignment.Center)
		bot.BackgroundColor3 = T.green
		bot.BackgroundTransparency = 0
		corner(bot, 21)
		bot.Visible = false
		label(body, "PlayerName", "", UDim2.new(1, -190, 0, 26), UDim2.fromOffset(60, 7), HEAVY, 19)
		label(body, "Material", "", UDim2.new(1, -190, 0, 18), UDim2.fromOffset(60, 32), MEDIUM, 15, T.muted)
		local clock = Instance.new("Frame")
		clock.Name = "ClockBox"
		clock.Size = UDim2.fromOffset(108, 42)
		clock.Position = UDim2.new(1, -116, 0, 8)
		clock.BackgroundColor3 = T.clockIdle
		clock.BorderSizePixel = 0
		clock.Parent = body
		corner(clock, 10)
		label(clock, "Time", "", UDim2.fromScale(1, 1), UDim2.new(), HEAVY, 26, T.text, Enum.TextXAlignment.Center)
		return { holder = holder, body = body, ring = ring, avatar = avatar, bot = bot, clock = clock, anchorY = anchorY, posY = posY }
	end
	-- wide: one row (avatar, name, clock) above / below the board. Compact (phones): a 176-wide card
	-- beside the board, the clock across the bottom.
	local function shapeBar(b, compact)
		local body, name, material, time = b.body, b.body.PlayerName, b.body.Material, b.clock.Time
		if compact then
			b.holder.Size = UDim2.fromOffset(176, 100)
			b.holder.AnchorPoint = Vector2.new(1, b.anchorY)
			b.holder.Position = UDim2.new(1, -14, b.anchorY, if b.anchorY == 0 then 8 else -8)
			b.avatar.Size = UDim2.fromOffset(36, 36)
			name.Size, name.Position, name.TextSize = UDim2.new(1, -58, 0, 22), UDim2.fromOffset(50, 6), 17
			material.Size, material.Position, material.TextSize = UDim2.new(1, -58, 0, 16), UDim2.fromOffset(50, 27), 14
			b.clock.Size, b.clock.Position = UDim2.new(1, -16, 0, 44), UDim2.fromOffset(8, 50)
			time.TextSize = 28
		else
			b.holder.Size = UDim2.fromOffset(420, 58)
			b.holder.AnchorPoint = Vector2.new(0.5, b.anchorY)
			b.holder.Position = UDim2.new(0.5, 0, b.anchorY, b.posY)
			b.avatar.Size = UDim2.fromOffset(42, 42)
			name.Size, name.Position, name.TextSize = UDim2.new(1, -190, 0, 26), UDim2.fromOffset(60, 7), 19
			material.Size, material.Position, material.TextSize = UDim2.new(1, -190, 0, 18), UDim2.fromOffset(60, 32), 15
			b.clock.Size, b.clock.Position = UDim2.fromOffset(108, 42), UDim2.new(1, -116, 0, 8)
			time.TextSize = 26
		end
		body.Size = UDim2.fromScale(1, 1)
	end
	self.top = bar("Opponent", 0, 10)
	self.bottom = bar("You", 1, -14)

	-- move list ------------------------------------------------------------------------------------
	local movesHolder, moves = card(gui, "Moves", UDim2.fromOffset(210, 330), UDim2.new(1, -14, 0.5, 0), Vector2.new(1, 0.5))
	Ui.header(moves, "Moves", 40, 20, I.moves)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "List"
	scroll.Size = UDim2.new(1, -12, 1, -48)
	scroll.Position = UDim2.fromOffset(6, 42)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = T.green
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Selectable = false
	scroll.Parent = moves
	self.movesFrame, self.moveList = movesHolder, scroll

	-- action buttons (left): Steal / Draw / Resign while playing, then a 2x2 grid of icon tiles
	local actions = Instance.new("Frame")
	actions.Name = "Actions"
	actions.BackgroundTransparency = 1
	actions.Size = UDim2.fromOffset(176, 330)
	actions.Position = UDim2.new(0, 14, 0.5, 0)
	actions.AnchorPoint = Vector2.new(0, 0.5)
	actions.Parent = gui
	list(actions, 8)
	local bsize = UDim2.fromOffset(176, 48)
	local h
	-- Steal a Piece (Robux, once per game): the price chip shows until it's bought for this game
	h, self.stealButton = button(actions, "Steal", "Steal", bsize, "gold", function() cb.steal() end, I.steal)
	h.LayoutOrder = 0
	self.stealButton.TextXAlignment = Enum.TextXAlignment.Left
	self.stealButton:SetAttribute("IconPadBase", 12)
	setText(self.stealButton, "Steal")
	local chip = label(self.stealButton, "Price", "", UDim2.fromOffset(66, 30), UDim2.new(1, -8, 0.5, 0), Ui.TITLE, 17, T.white, Enum.TextXAlignment.Right)
	chip.AnchorPoint = Vector2.new(1, 0.5)
	chip.BackgroundColor3 = T.ink
	chip.BackgroundTransparency = 0.3
	chip.ZIndex = 3
	corner(chip, 9)
	local cpad = Instance.new("UIPadding")
	cpad.PaddingRight = UDim.new(0, 8)
	cpad.Parent = chip
	local rbx = Instance.new("ImageLabel")
	rbx.Name = "Robux"
	rbx.BackgroundTransparency = 1
	rbx.Image = Ui.ROBUX
	rbx.Size = UDim2.fromOffset(18, 18)
	rbx.Position = UDim2.new(0, 6, 0.5, -9)
	rbx.ZIndex = 3
	rbx.Parent = chip
	self.stealPrice = chip
	h, self.drawButton = button(actions, "OfferDraw", "Draw", bsize, "secondary", function() cb.offerDraw() end, I.draw)
	h.LayoutOrder = 1
	h, self.resignButton = button(actions, "Resign", "Resign", bsize, "danger", function()
		self:confirm("Resign?", cb.resign, I.resign)
	end, I.resign)
	h.LayoutOrder = 2
	local tiles = Instance.new("Frame")
	tiles.Name = "Tiles"
	tiles.BackgroundTransparency = 1
	tiles.Size = UDim2.fromOffset(176, 152)
	tiles.LayoutOrder = 3
	tiles.Parent = actions
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(84, 72)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = tiles
	local tsize = UDim2.fromOffset(84, 72)
	h, self.viewButton = tile(tiles, "View2D", I.view2D, "2D", tsize, "primary", function() cb.toggle2D() end)
	h.LayoutOrder = 1
	h, self.tiltButton = tile(tiles, "Tilt", I.tilt, "Tilt", tsize, "secondary", function() cb.tilt() end)
	h.LayoutOrder = 2
	h = tile(tiles, "Settings", I.settings, "Settings", tsize, "blue", function() cb.settings() end)
	h.LayoutOrder = 3
	h, self.leaveButton = tile(tiles, "Leave", I.leave, "Leave", tsize, "danger", function()
		if self.playing then
			self:confirm("Leave? You lose this game.", cb.stand, I.leave)
		else
			cb.stand()
		end
	end)
	h.LayoutOrder = 4

	-- table panel (seated, no game running): mode + clock, bot + level, Ready, Leave ----------------
	-- (fixed height, set by layoutPanel from the rows showing: AutomaticSize here grew without end on
	-- the live client and froze the game)
	local panelHolder, panel = card(gui, "TablePanel", UDim2.fromOffset(340, 320), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	list(panel, 10).VerticalAlignment = Enum.VerticalAlignment.Top
	local head = label(panel, "Title", "Table", UDim2.new(1, 0, 0, 56), UDim2.new(), Ui.TITLE, 30, T.white, Enum.TextXAlignment.Center)
	head.BackgroundColor3 = T.green
	head.BackgroundTransparency = 0
	corner(head, 16)
	Ui.highlight(head, 16)
	Ui.chunky(head, 3)
	self.panelTitle = head
	local wide = UDim2.new(1, -40, 0, 50)
	local function row(name)
		local r = Instance.new("Frame")
		r.Name = name
		r.BackgroundTransparency = 1
		r.Size = wide
		r.Parent = panel
		list(r, 8, true)
		return r
	end
	local setupRow = row("SetupRow")
	local _, modeFace = button(setupRow, "Mode", "Classic", UDim2.new(0.5, -4, 1, 0), "secondary", function() cb.cycleMode() end, I.Classic)
	self.modeButton = modeFace
	local _, clockFace = button(setupRow, "Clock", "10 min", UDim2.new(0.5, -4, 1, 0), "secondary", function() cb.cycleClock() end, I.clock)
	self.clockButton = clockFace
	-- "Play vs bot" is a tick box; the bot's level shows (and cycles) only once a bot is seated
	local botHolder, botFace, setBot = Ui.checkbox(panel, "Bot", "Play vs bot", wide, function() cb.botButton() end)
	self.botButton, self.setBotCheck = botFace, setBot
	local levelHolder, levelFace = button(panel, "Level", "Bot level: Club", wide, "secondary", function() cb.cycleLevel() end, I.Club)
	self.levelButton = levelFace
	self.botRow, self.levelRow = botHolder, levelHolder
	local readyHolder
	readyHolder, self.readyButton = button(panel, "Ready", "Ready!", UDim2.new(1, -40, 0, 56), "primary", function() cb.ready() end, I.ready)
	self.readyButton.TextSize = 22
	self.readyHolder = readyHolder
	local leaveHolder = button(panel, "LeavePanel", "Leave", wide, "danger", function() cb.stand() end, I.leave)
	for i, c in { head, setupRow, botHolder, levelHolder, readyHolder, leaveHolder } do
		c.LayoutOrder = i
	end
	self.panel = panelHolder

	-- result card ------------------------------------------------------------------------------------
	local resultHolder, result = card(gui, "Result", UDim2.fromOffset(420, 196), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	self.resultTitle = label(result, "Title", "", UDim2.new(1, -20, 0, 50), UDim2.fromOffset(10, 14), Ui.TITLE, 44, T.green, Enum.TextXAlignment.Center)
	Ui.chunky(self.resultTitle, 3.5)
	self.resultSub = label(result, "Sub", "", UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, 66), BOLD, 18, T.muted, Enum.TextXAlignment.Center)
	-- the coins a win against a person paid (Hud:setReward), between the reason and the buttons
	self.rewardLabel = label(result, "Reward", "", UDim2.new(1, -20, 0, 28), UDim2.fromOffset(10, 92), Ui.TITLE, 24,
		Color3.fromRGB(255, 214, 90), Enum.TextXAlignment.Center)
	Ui.chunky(self.rewardLabel, 2.5)
	self.rewardLabel.Visible = false
	self.rewardScale = Instance.new("UIScale")
	self.rewardScale.Parent = self.rewardLabel
	local rrow = Instance.new("Frame")
	rrow.BackgroundTransparency = 1
	rrow.Size = UDim2.new(1, -36, 0, 50)
	rrow.Position = UDim2.fromOffset(18, 124)
	rrow.Parent = result
	list(rrow, 10, true)
	local rh, rematch = button(rrow, "Rematch", "Rematch", UDim2.new(0.36, -7, 1, 0), "primary", function() cb.ready() end, I.rematch)
	rh.LayoutOrder = 1
	self.rematchButton = rematch
	local vh = button(rrow, "Review", "Review", UDim2.new(0.32, -7, 1, 0), "secondary", function() cb.review() end, I.review)
	vh.LayoutOrder = 2
	local lh = button(rrow, "ResultLeave", "Leave", UDim2.new(0.32, -6, 1, 0), "secondary", function() cb.stand() end, I.leave)
	lh.LayoutOrder = 3
	self.result = resultHolder

	-- the ability panel (Abilities games): along the bottom, or beside the board on phones. Made
	-- before the draw offer, which shares its spot on phones and must draw on top.
	self.abilityBar = AbilityBar.new(gui, function(id)
		cb.pickAbility(id)
	end)
	self.abilityBar.holder.Visible = false

	-- draw offer card: in the left column above the action buttons, so it never covers the board
	local offerHolder, offer = card(gui, "DrawOffer", UDim2.fromOffset(176, 150), UDim2.new(0, 14, 0.5, -175), Vector2.new(0, 1))
	local offerText = label(offer, "Text", "Draw?", UDim2.new(1, -20, 0, 44), UDim2.fromOffset(10, 6), HEAVY, 22, T.text, Enum.TextXAlignment.Center)
	setText(offerText, "Draw?", I.draw)
	local orow = Instance.new("Frame")
	orow.BackgroundTransparency = 1
	orow.Size = UDim2.new(1, -20, 0, 92)
	orow.Position = UDim2.fromOffset(10, 52)
	orow.Parent = offer
	list(orow, 6)
	local _, accept = button(orow, "Accept", "Yes", UDim2.new(1, 0, 0, 42), "primary", function() cb.acceptDraw() end, I.yes)
	accept.Parent.LayoutOrder = 1
	self.acceptButton = accept
	local declineH = button(orow, "Decline", "No", UDim2.new(1, 0, 0, 42), "secondary", function() cb.declineDraw() end, I.no)
	declineH.LayoutOrder = 2
	self.offer = offerHolder

	-- promotion picker: just the four pieces --------------------------------------------------------
	local promoHolder, promo = card(gui, "Promotion", UDim2.fromOffset(440, 160), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	setText(Ui.chunky(label(promo, "Title", "Pick a piece", UDim2.new(1, 0, 0, 34), UDim2.fromOffset(0, 8), Ui.TITLE, 26, T.white, Enum.TextXAlignment.Center), 2.5), "Pick a piece", I.queen)
	local prow = Instance.new("Frame")
	prow.BackgroundTransparency = 1
	prow.Size = UDim2.new(1, -24, 0, 100)
	prow.Position = UDim2.fromOffset(12, 48)
	prow.Parent = promo
	list(prow, 8, true)
	self.promoButtons = {}
	for i, kind in { "q", "r", "b", "n" } do
		local holder, face = button(prow, PIECE_NAMES[kind], "", UDim2.new(0.25, -6, 1, 0), "secondary", function()
			self:hidePromotion()
			if self.onPromote then
				self.onPromote(kind)
			end
		end)
		holder.LayoutOrder = i
		self.promoButtons[kind] = face
	end
	self.promo = promoHolder

	-- confirm dialog ---------------------------------------------------------------------------------
	local confirmHolder, confirm = card(gui, "Confirm", UDim2.fromOffset(380, 158), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	self.confirmText = label(confirm, "Text", "", UDim2.new(1, -36, 0, 64), UDim2.fromOffset(18, 10), HEAVY, 22, T.text, Enum.TextXAlignment.Center)
	self.confirmText.TextWrapped = true
	local crow = Instance.new("Frame")
	crow.BackgroundTransparency = 1
	crow.Size = UDim2.new(1, -36, 0, 52)
	crow.Position = UDim2.fromOffset(18, 88)
	crow.Parent = confirm
	list(crow, 10, true)
	local _, yes = button(crow, "Yes", "Yes", UDim2.new(0.5, -5, 1, 0), "red", function()
		confirmHolder.Visible = false
		local f = self.onConfirm
		self.onConfirm = nil
		self:refocus()
		if f then
			f()
		end
	end, I.yes)
	self.confirmYes = yes
	local _, no = button(crow, "No", "No", UDim2.new(0.5, -5, 1, 0), "secondary", function()
		confirmHolder.Visible = false
		self.onConfirm = nil
		self:refocus()
	end, I.no)
	self.confirmNo = no
	self.confirmFrame = confirmHolder

	-- toast and hints ------------------------------------------------------------------------------------
	local toast = label(gui, "Toast", "", UDim2.fromOffset(0, 40), UDim2.new(0.5, 0, 0, 142), HEAVY, 18, T.white, Enum.TextXAlignment.Center)
	toast.AutomaticSize = Enum.AutomaticSize.X
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.BackgroundColor3 = T.green
	toast.BackgroundTransparency = 0
	toast.Visible = false
	corner(toast, 20)
	local tpad = Instance.new("UIPadding")
	tpad.PaddingLeft, tpad.PaddingRight = UDim.new(0, 18), UDim.new(0, 18)
	tpad.Parent = toast
	self.toastLabel = toast

	local hint = label(gui, "Hint", "", UDim2.fromOffset(0, 28), UDim2.new(0, 14, 1, -14), BOLD, 14, T.greenDeep)
	hint.AutomaticSize = Enum.AutomaticSize.X
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.BackgroundColor3 = T.panelDeep
	hint.BackgroundTransparency = 0.15
	hint.TextTruncate = Enum.TextTruncate.None
	corner(hint, 14)
	local hpad = Instance.new("UIPadding")
	hpad.PaddingLeft, hpad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	hpad.Parent = hint
	self.hint = hint

	for _, f in { panelHolder, resultHolder, offerHolder, promoHolder, confirmHolder } do
		f.Visible = false
	end

	local cam = workspace.CurrentCamera
	local function rescale()
		local v = cam.ViewportSize
		local layout = Ui.seatLayout(v, GuiService:GetGuiInset().Y, self.strip)
		scale.Scale = layout.scale
		self.compact = layout.compact
		-- your bar sits above the ability panel when there is one along the bottom
		self.bottom.posY = if self.strip and not layout.compact then -14 - Ui.STRIP_H else -14
		local bar = self.abilityBar
		bar:setCompact(layout.compact)
		if layout.compact then
			bar.holder.AnchorPoint, bar.holder.Position = Vector2.new(1, 0.5), UDim2.new(1, -14, 0.5, 0)
		else
			bar.holder.AnchorPoint, bar.holder.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -12)
		end
		shapeBar(self.top, layout.compact)
		shapeBar(self.bottom, layout.compact)
		-- the draw offer: above the buttons (wide), or between the player cards (compact)
		if layout.compact then
			offerHolder.AnchorPoint, offerHolder.Position = Vector2.new(1, 0.5), UDim2.new(1, -14, 0.5, 0)
		else
			offerHolder.AnchorPoint, offerHolder.Position = Vector2.new(0, 1), UDim2.new(0, 14, 0.5, -175)
		end
		self.wideScreen = not layout.compact and v.X >= 760 -- phones: the move list would cover the board
		movesHolder.Visible = self.wideScreen and self.hasMoves == true
		hint.Visible = not layout.compact and v.X >= 900
		hint.Position = UDim2.new(0, 14, 1, if self.strip then -14 - Ui.STRIP_H else -14) -- (above the ability panel)
		self:updatePlayerList()
	end
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	self.relayout = rescale
	rescale()
	return self
end

-- (forCutscene: hidden only while a cutscene plays, so the player list stays hidden too)
function Hud:setVisible(on, forCutscene)
	self.gui.Enabled = on
	self.inCutscene = not on and forCutscene == true
	if not on then
		GuiService.SelectedObject = nil
	end
	self:updatePlayerList()
end

-- On phones Roblox's player list sits right where the opponent's card goes; it's hidden while
-- you're seated (the cards show who's playing) and comes back when you leave.
function Hud:updatePlayerList()
	local hide = (self.gui.Enabled or self.inCutscene) and self.compact == true
	if hide ~= self.playerListHidden then
		self.playerListHidden = hide
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, not hide)
	end
end

-- a win paid coins: "+50 coins" on the result card (cleared when the next game starts)
function Hud:setReward(n)
	setText(self.rewardLabel, "+" .. n .. " coins", I.coin)
	self.rewardLabel.Visible = true
	self.rewardScale.Scale = 0.4
	game:GetService("TweenService"):Create(self.rewardScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function Hud:toast(text)
	self.toastToken = (self.toastToken or 0) + 1
	local token = self.toastToken
	self.toastLabel.Text = text
	self.toastLabel.Visible = true
	task.delay(2.5, function()
		if self.toastToken == token then
			self.toastLabel.Visible = false
		end
	end)
end

function Hud:confirm(text, onYes, icon)
	setText(self.confirmText, text, icon or "")
	self.onConfirm = onYes
	self.confirmFrame.Visible = true
	self:refocus()
end

-- color: the side promoting, for the piece pictures
function Hud:showPromotion(onPick, color)
	self.onPromote = onPick
	for kind, face in self.promoButtons do
		local old = face:FindFirstChild("Piece")
		if old then
			old:Destroy()
		end
		local icon = PieceIcons.new(kind, color or "w")
		icon.Size = UDim2.new(1, -12, 1, -12)
		icon.Position = UDim2.fromOffset(6, 4)
		icon.Parent = face
	end
	self.promo.Visible = true
	self:refocus()
end

function Hud:hidePromotion()
	self.promo.Visible = false
	self:refocus()
end

-- the topmost open dialog, for controller focus
function Hud:overlay()
	if self.confirmFrame.Visible then
		return self.confirmNo
	elseif self.promo.Visible then
		return self.promoButtons.q
	elseif self.result.Visible then
		return self.rematchButton
	elseif self.panel.Visible then
		return if self.readyHolder.Visible then self.readyButton else self.clockButton
	elseif self.offer.Visible then
		return self.acceptButton
	end
	return nil
end

-- Controller: dialogs grab focus; otherwise focus stays on the board unless the menu is open.
function Hud:refocus()
	if not self.usingPad then
		return
	end
	local o = self:overlay()
	if o then
		GuiService.SelectedObject = o
	elseif self.menuOpen then
		GuiService.SelectedObject = if self.drawButton.Parent.Visible then self.drawButton else self.viewButton
	else
		GuiService.SelectedObject = nil
	end
end

function Hud:setPad(usingPad)
	self.usingPad = usingPad
	if not usingPad then
		self.menuOpen = false
	end
	self:refocus()
end

function Hud:toggleMenu()
	self.menuOpen = not self.menuOpen
	self:refocus()
end

function Hud:setHint(text)
	self.hint.Text = text
end

local function fillBar(b, seat, material, toMove, isYou, waiting)
	local name = if seat then seat.name else "Empty seat"
	if isYou then
		name ..= " (you)"
	end
	b.body.PlayerName.Text = name
	b.body.Material.Text = if waiting and seat and seat.ready and not seat.isBot then "Ready ✓"
		elseif material and material > 0 then "+" .. material
		else ""
	b.ring.Transparency = if toMove then 0 else 1
	b.toMove = toMove
	setAvatar(b.avatar, b.bot, seat)
end

-- info: { label, myColor, status, seats, settings, drawOffer, result, sans, material = {w, b},
--         turn, ready, botLevelName, clockLabel, autoQueen, tilted, mode2D }
function Hud:update(info)
	self.info = info
	local me, opp = info.myColor, if info.myColor == "w" then "b" else "w"
	local playing = info.status == "playing"
	self.playing = playing
	if playing then
		self.rewardLabel.Visible = false
	end
	local diff = (info.material.w or 0) - (info.material.b or 0)
	local mat = { w = diff, b = -diff }
	fillBar(self.bottom, info.seats[me], mat[me], playing and info.turn == me, true, not playing)
	fillBar(self.top, info.seats[opp], mat[opp], playing and info.turn == opp, false, not playing)

	-- move list: number, White's move, Black's move
	self.moveList:ClearAllChildren()
	local ll = Instance.new("UIListLayout")
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = self.moveList
	local sans = info.sans or {}
	for i = 1, #sans, 2 do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -6, 0, 26)
		row.BackgroundColor3 = T.panelLift
		row.BackgroundTransparency = if (i // 2) % 2 == 0 then 0.6 else 0
		row.BorderSizePixel = 0
		row.LayoutOrder = i
		row.Parent = self.moveList
		corner(row, 6)
		label(row, "N", ((i + 1) // 2) .. ".", UDim2.new(0, 34, 1, 0), UDim2.fromOffset(6, 0), BOLD, 15, T.muted)
		label(row, "W", sans[i], UDim2.new(0, 70, 1, 0), UDim2.fromOffset(40, 0), HEAVY, 16)
		label(row, "B", sans[i + 1] or "", UDim2.new(0, 70, 1, 0), UDim2.fromOffset(112, 0), HEAVY, 16)
	end
	self.moveList.CanvasPosition = Vector2.new(0, 1e5)
	self.hasMoves = #sans > 0
	self.movesFrame.Visible = self.wideScreen and self.hasMoves

	-- piece abilities: Abilities games only. The layout keeps the panel's strip for the whole time
	-- you sit at an Abilities table (so the board doesn't jump when the game starts).
	local abilities = info.settings.mode == "Abilities"
	if abilities ~= (self.strip == true) then
		self.strip = abilities
		self.relayout()
	end
	self.abilityBar.holder.Visible = playing and abilities
	if abilities then
		self.abilityBar:setColor(info.myColor)
		self.abilityBar:update(info.abilities or {}, if info.targeting then info.targetingId or "all" else nil, info.showKeys)
	end
	self.drawButton.Parent.Visible = playing
	self.resignButton.Parent.Visible = playing
	-- Steal a Piece: info.steal = { state = "buy" | "ready" | "used", price }
	local steal = info.steal
	self.stealButton.Parent.Visible = playing and steal ~= nil and steal.state ~= "used"
	if steal then
		local ready = steal.state == "ready"
		Ui.restyle(self.stealButton, if ready and info.targetingId == "StealPiece" then "primary" else "gold")
		setText(self.stealButton, if ready then "Steal!" else "Steal")
		self.stealPrice.Visible = not ready
		self.stealPrice.Text = tostring(steal.price or "")
	end
	setText(self.drawButton, if info.drawOffer == me then "Sent" else "Draw")
	if info.mode2D then
		setTile(self.viewButton, I.view3D, "3D")
	else
		setTile(self.viewButton, I.view2D, "2D")
	end
	self.tiltButton.Parent.Visible = not info.mode2D
	setTile(self.tiltButton, I.tilt, if info.tilted then "Flat" else "Tilt")

	-- table panel: seated and no game running (and no result to show)
	local showResult = info.status == "over" and info.result ~= nil
	self.panel.Visible = not playing and not showResult
	if self.panel.Visible then
		self.panelTitle.Text = info.label
		local mode = info.settings.mode
		setText(self.modeButton, mode, I[mode] or "")
		setText(self.clockButton, info.clockLabel)
		local oppSeat = info.seats[opp]
		-- a person in the other seat: no bot buttons
		local hasBot = oppSeat ~= nil and oppSeat.isBot == true
		self.botRow.Visible = not (oppSeat and not oppSeat.isBot)
		self.setBotCheck(hasBot)
		self.levelRow.Visible = hasBot
		setText(self.levelButton, "Bot level: " .. info.botLevelName, I[info.botLevelName] or "")
		self.readyHolder.Visible = oppSeat ~= nil
		if info.ready then
			setText(self.readyButton, "Waiting…", I.waiting)
		else
			setText(self.readyButton, "Ready!", I.ready)
		end
		-- panel height from the rows showing: title 56, rows + 10 px gaps, 18 px bottom margin
		local h = 56 + 18
		for _, r in { { self.modeButton.Parent.Parent, 50 }, { self.botRow, 50 }, { self.levelRow, 50 }, { self.readyHolder, 56 }, { true, 50 } } do
			if r[1] == true or r[1].Visible then
				h += 10 + r[2]
			end
		end
		self.panel.Size = UDim2.fromOffset(340, h)
	end

	self.result.Visible = showResult
	if showResult then
		local r = info.result
		local title, color, icon = "Draw", T.muted, I.tie
		if r.reason == "aborted" then
			title, icon = "Game aborted", ""
		elseif r.winner == me then
			title, color, icon = "You win!", T.green, I.win
		elseif r.winner ~= nil then
			title, color, icon = "You lost", T.red, I.lose
		end
		setText(self.resultTitle, title, icon)
		self.resultTitle.TextColor3 = color
		local oppSeat = info.seats[opp]
		local wantsRematch = oppSeat and not oppSeat.isBot and oppSeat.ready and not info.ready
		self.resultSub.Text = (REASONS[r.reason] or r.reason) .. (if wantsRematch then "  ·  Rematch?" else "")
		if info.ready then
			setText(self.rematchButton, "Waiting…", I.waiting)
		else
			setText(self.rematchButton, if info.seats[opp] then "Rematch" else "New game", I.rematch)
		end
	end

	self.offer.Visible = playing and info.drawOffer == opp
	self:refocus()
end

-- every frame: clocks (green box = that side's clock is running, red = under 20 seconds)
function Hud:tickClocks(clock, me, now)
	local opp = if me == "w" then "b" else "w"
	for _, pair in { { self.bottom, me }, { self.top, opp } } do
		local b, c = pair[1], pair[2]
		local box, text = b.clock, b.clock.Time
		if not clock then
			text.Text = "–"
			box.BackgroundColor3 = T.clockIdle
			text.TextColor3 = T.muted
		else
			local t = clock[c]
			if clock.running == c then
				t -= math.max(0, now - math.max(clock.at, clock.since or clock.at)) -- held during cutscenes
			end
			text.Text = Hud.formatTime(t)
			if t < 20 and clock.running == c then
				box.BackgroundColor3, text.TextColor3 = T.red, T.white
			elseif b.toMove then
				box.BackgroundColor3, text.TextColor3 = T.green, T.white
			else
				box.BackgroundColor3, text.TextColor3 = T.clockIdle, T.text
			end
		end
	end
end

return Hud
