-- The lobby HUD (shown while you're NOT seated): a big PLAY at the bottom, and down the left your
-- coins over Shop, Tables, Stats and Settings, plus their cards. Same look as the seated HUD (UiKit). It only shows state and
-- calls back; ChessClient talks to the server.
--
-- cb = { quickBot(opts), quickPlayer(), sit(tableId), fetchStats() -> data|nil (yields),
--        fetchLeaderboard(board) -> data|nil (yields; the Stats card's Leaderboard tab),
--        reviewSaved(id), buyVip(), buy(id) -> ok, wallet | err (yields), buyPass(passId),
--        tourney = { start(), join(), leave(), watch(), fetchToday() -> data|nil, review(id) } }
-- lobby:open("tourney") shows the Tournament card (TournamentPanel). In a tournament server
-- (setTournamentServer) there's no PLAY and no Tables: the bracket (BracketPanel) takes over.
-- lobby:setWallet({ coins, owned, vip? }) keeps the coin counter and the Shop up to date.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local Settings = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Settings"))
local Ui = require(script.Parent.UiKit)
local StatsPanel = require(script.Parent.StatsPanel)
local ShopPanel = require(script.Parent.ShopPanel)
local TournamentPanel = require(script.Parent.TournamentPanel)
local Shop = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Shop"))
local T, BOLD, HEAVY, MEDIUM = Ui.T, Ui.BOLD, Ui.HEAVY, Ui.MEDIUM
local corner, stroke, card, label, button, list = Ui.corner, Ui.stroke, Ui.card, Ui.label, Ui.button, Ui.list
local I, setText, tile, closeX = Ui.ICONS, Ui.setText, Ui.tile, Ui.closeX

local LobbyHud = {}
LobbyHud.__index = LobbyHud

local COLORS = { { id = "w", label = "White", icon = I.white }, { id = nil, label = "Random", icon = I.random },
	{ id = "b", label = "Black", icon = I.black } }

function LobbyHud.new(cb, levels)
	local self = setmetatable({}, LobbyHud)
	self.cb = cb
	self.levels = levels
	self.choice = { level = 2, clock = Settings.DEFAULT_CLOCK, color = 2, mode = 1 }
	local gui = Instance.new("ScreenGui")
	gui.Name = "ChessLobby"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 4
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui
	local scale = Instance.new("UIScale")
	scale.Parent = gui

	-- bottom bar --------------------------------------------------------------------------------------
	-- bottom centre: one big PLAY (opens the Play screen's mode cards)
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -18)
	bar.Size = UDim2.fromOffset(300, 84)
	bar.Parent = gui
	self.bar = bar
	list(bar, 10, true)
	local _, playB = button(bar, "Play", "PLAY", UDim2.fromOffset(280, 80), "primary", function()
		self:open(nil)
		cb.play()
	end, I.play)
	playB.TextSize = 38
	setText(playB, "PLAY")
	self.playBot = playB -- (the controller's Y jumps here)

	-- left side column, like the big simulator games: icon + text, a colour each
	local side = Instance.new("Frame")
	side.Name = "Side"
	side.BackgroundTransparency = 1
	side.AnchorPoint = Vector2.new(0, 0.5)
	side.Position = UDim2.new(0, 16, 0.5, 0)
	side.Size = UDim2.fromOffset(190, 44 + 4 * 62 + 4 * 10)
	side.Parent = gui
	self.side = side
	list(side, 10)
	-- your coins, at the top of the column (a dark pill, the big gold number)
	local coins = Instance.new("Frame")
	coins.Name = "Coins"
	coins.Size = UDim2.fromOffset(190, 44)
	coins.BackgroundColor3 = T.ink
	coins.BackgroundTransparency = 0.25
	coins.LayoutOrder = 0
	coins.Parent = side
	corner(coins, 22)
	stroke(coins, T.ink, 2.5)
	Ui.icon(coins, I.coin, 38, UDim2.fromOffset(4, 3))
	local coinsText = label(coins, "Amount", "0", UDim2.new(1, -56, 1, 0), UDim2.fromOffset(48, 0), Ui.TITLE, 28, Color3.fromRGB(255, 214, 90))
	Ui.chunky(coinsText, 2.5)
	self.coinsText = coinsText
	self.coinsScale = Instance.new("UIScale")
	self.coinsScale.Parent = coins
	local sideSize = UDim2.fromOffset(190, 62)
	local _, shopB = button(side, "Shop", "Shop", sideSize, "primary", function()
		self:open("shop")
	end, I.shop)
	local _, tablesB = button(side, "Tables", "Tables", sideSize, "abilities", function()
		self:open("tables")
	end, I.tables)
	local _, statsB = button(side, "Stats", "Stats", sideSize, "blue", function()
		self:open("stats")
	end, I.stats)
	local _, settingsB = button(side, "Settings", "Settings", sideSize, "gold", function()
		self:open(nil)
		cb.settings()
	end, I.settings)
	for i, b in { shopB, tablesB, statsB, settingsB } do
		b.Parent.LayoutOrder = i
		b.TextSize = 24
		b.TextXAlignment = Enum.TextXAlignment.Left
		b:SetAttribute("IconPadBase", 14) -- left margin; setText adds room for the icon
	end
	setText(shopB, "Shop")
	setText(tablesB, "Tables")
	self.tablesButton = tablesB.Parent
	setText(statsB, "Stats")
	setText(settingsB, "Settings")

	-- shared: a centred card with a green title and a Close button
	local function sheet(name, title, height, icon)
		local holder, body = card(gui, name, UDim2.fromOffset(460, height), UDim2.fromScale(0.5, 0.46), Vector2.new(0.5, 0.5))
		Ui.header(body, title, nil, nil, icon)
		local _, close = closeX(body, function()
			self:open(nil)
		end)
		holder.Visible = false
		return holder, body, close
	end

	-- Play vs Bot: level tiles, clock, colour, start ------------------------------------------------
	local botCard, botBody = sheet("BotSetup", "Play Bot", 322, I.bot)
	local tiles = Instance.new("Frame")
	tiles.BackgroundTransparency = 1
	tiles.Size = UDim2.new(1, -32, 0, 100)
	tiles.Position = UDim2.fromOffset(16, 66)
	tiles.Parent = botBody
	list(tiles, 8, true)
	self.levelTiles = {}
	for i, lv in levels do
		local h, face = button(tiles, "Level" .. i, "", UDim2.new(0.25, -6, 1, 0), "secondary", function()
			self.choice.level = i
			self:refreshBotCard()
		end)
		h.LayoutOrder = i
		Ui.icon(face, I[lv.name] or "", 50, UDim2.new(0.5, 0, 0, 6), Vector2.new(0.5, 0))
		Ui.chunky(label(face, "Name", lv.name, UDim2.new(1, -8, 0, 26), UDim2.fromOffset(4, 58), Ui.TITLE, 21, T.white, Enum.TextXAlignment.Center), 2)
		self.levelTiles[i] = face
	end
	local opts = Instance.new("Frame")
	opts.BackgroundTransparency = 1
	opts.Size = UDim2.new(1, -32, 0, 50)
	opts.Position = UDim2.fromOffset(16, 178)
	opts.Parent = botBody
	list(opts, 8, true)
	local _, modeB = button(opts, "Mode", "Mode", UDim2.new(0.34, -6, 1, 0), "secondary", function()
		self.choice.mode = self.choice.mode % #Settings.MODES + 1
		self:refreshBotCard()
	end)
	modeB.Parent.LayoutOrder = 1
	self.modeChoice = modeB
	local _, clockB = button(opts, "Clock", "Clock", UDim2.new(0.33, -6, 1, 0), "secondary", function()
		local idx = 1
		for i, c in Settings.CLOCKS do
			if c.id == self.choice.clock then
				idx = i
			end
		end
		self.choice.clock = Settings.CLOCKS[idx % #Settings.CLOCKS + 1].id
		self:refreshBotCard()
	end)
	clockB.Parent.LayoutOrder = 2
	local _, colorB = button(opts, "Color", "Color", UDim2.new(0.33, -6, 1, 0), "secondary", function()
		self.choice.color = self.choice.color % #COLORS + 1
		self:refreshBotCard()
	end)
	colorB.Parent.LayoutOrder = 3
	self.clockChoice, self.colorChoice = clockB, colorB
	local startH, start = button(botBody, "Start", "Play!", UDim2.new(1, -32, 0, 60), "primary", function()
		self:open(nil)
		cb.quickBot({ vs = "bot", level = self.choice.level, clock = self.choice.clock, color = COLORS[self.choice.color].id,
			mode = Settings.MODES[self.choice.mode] })
	end, I.start)
	startH.Position = UDim2.fromOffset(16, 244)
	start.TextSize = 24
	self.startButton = start
	self.botCard = botCard

	-- Tables list --------------------------------------------------------------------------------------
	local tablesCard, tablesBody = sheet("TablesList", "Tables", 470, I.tables) -- (8 rows)
	local rows = Instance.new("Frame")
	rows.BackgroundTransparency = 1
	rows.Size = UDim2.new(1, -28, 0, 394)
	rows.Position = UDim2.fromOffset(14, 64)
	rows.Parent = tablesBody
	local rl = list(rows, 6)
	rl.VerticalAlignment = Enum.VerticalAlignment.Top
	self.tableRows = {}
	for i = 1, Settings.TABLE_COUNT do
		local id = "T" .. i
		local row = Instance.new("Frame")
		row.Name = id
		row.Size = UDim2.new(1, 0, 0, 44)
		row.BackgroundColor3 = T.panelLift
		row.BackgroundTransparency = if i % 2 == 1 then 0 else 0.5
		row.BorderSizePixel = 0
		row.LayoutOrder = i
		row.Parent = rows
		corner(row, 10)
		label(row, "Name", "Table " .. i, UDim2.fromOffset(80, 44), UDim2.fromOffset(12, 0), HEAVY, 18)
		local who = label(row, "Who", "", UDim2.new(1, -220, 1, 0), UDim2.fromOffset(92, 0), BOLD, 16, T.text)
		local _, sit = button(row, "Sit", "Sit", UDim2.fromOffset(110, 36), "primary", function()
			self:open(nil)
			cb.sit(id)
		end)
		sit.Parent.AnchorPoint = Vector2.new(1, 0.5)
		sit.Parent.Position = UDim2.new(1, -8, 0.5, 0)
		self.tableRows[id] = { who = who, sit = sit }
	end
	self.tablesCard = tablesCard

	-- Stats ---------------------------------------------------------------------------------------------
	self.stats = StatsPanel.new(gui, {
		close = function()
			self:open(nil)
		end,
		reviewSaved = function(id)
			cb.reviewSaved(id)
		end,
		buyVip = function()
			cb.buyVip()
		end,
		fetchLeaderboard = function(board)
			return cb.fetchLeaderboard(board)
		end,
	}, levels)
	self.statsCard = self.stats.holder

	-- Shop ----------------------------------------------------------------------------------------------
	self.shop = ShopPanel.new(gui, {
		close = function()
			self:open(nil)
		end,
		buy = function(id)
			local ok, res = cb.buy(id)
			if ok then
				self:setWallet(res) -- (the coin counter too)
			end
			return ok, res
		end,
		buyVip = function()
			cb.buyVip()
		end,
		buyPass = function(passId)
			cb.buyPass(passId)
		end,
		toast = function(text)
			self:toast(text)
		end,
	})
	self.shopCard = self.shop.holder

	-- Tournament ------------------------------------------------------------------------------------
	local tcb = cb.tourney or {}
	self.tourney = TournamentPanel.new(gui, {
		close = function()
			self:open(nil)
		end,
		start = tcb.start,
		join = tcb.join,
		leave = tcb.leave,
		watch = tcb.watch,
		buyVip = function()
			cb.buyVip()
		end,
		fetchToday = tcb.fetchToday,
		review = tcb.review,
	})
	self.tourneyCard = self.tourney.holder

	local toast = label(gui, "Toast", "", UDim2.fromOffset(0, 42), UDim2.new(0.5, 0, 0, 24), HEAVY, 19, T.white, Enum.TextXAlignment.Center)
	toast.AutomaticSize = Enum.AutomaticSize.X
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.BackgroundColor3 = T.green
	toast.BackgroundTransparency = 0
	toast.Visible = false
	corner(toast, 21)
	local tpad = Instance.new("UIPadding")
	tpad.PaddingLeft, tpad.PaddingRight = UDim.new(0, 20), UDim.new(0, 20)
	tpad.Parent = toast
	self.toastLabel = toast

	local cam = workspace.CurrentCamera
	local function rescale()
		local v = cam.ViewportSize
		local s = Ui.uiScale(v)
		scale.Scale = s
		self.compact = Ui.compact(v)
		-- a card taller than the screen (phones) shrinks to fit, centred
		local room = v.Y - GuiService:GetGuiInset().Y - 40 -- (the close X overhangs the top corner)
		for _, c in { self.botCard, self.tablesCard, self.statsCard, self.shopCard, self.tourneyCard } do
			-- (the Shop is wide: it fits the width too)
			Ui.setFit(c, math.min(1, room / (c.Size.Y.Offset * s), (v.X - 24) / (c.Size.X.Offset * s)))
			c.Position = UDim2.fromScale(0.5, if self.compact then 0.5 else 0.46)
		end
		self.side.Visible = self.which == nil or not self.compact
		-- phones: up a little, clear of the thumbstick in the bottom-left corner
		self.side.Position = UDim2.new(0, 16, if self.compact then 0.47 else 0.5, 0)
	end
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()
	self:refreshBotCard()
	return self
end

function LobbyHud:toast(text)
	self.toastToken = (self.toastToken or 0) + 1
	local token = self.toastToken
	self.toastLabel.Text = text
	self.toastLabel.Visible = true
	task.delay(3, function()
		if self.toastToken == token then
			self.toastLabel.Visible = false
		end
	end)
end

function LobbyHud:setVisible(on)
	self.gui.Enabled = on
	if not on then
		self:open(nil)
	end
end

-- your coins and bought abilities changed (or arrived): the counter bumps when it goes up
function LobbyHud:setWallet(w)
	if type(w) ~= "table" or type(w.coins) ~= "number" then
		return
	end
	local before = self.coinsShown
	self.coinsShown = w.coins
	self.coinsText.Text = Shop.format(w.coins)
	if before and w.coins > before then
		self.coinsScale.Scale = 1.25
		game:GetService("TweenService"):Create(self.coinsScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	self.shop:setWallet(w)
	if w.vip ~= nil then
		self.tourney:setVip(w.vip)
	end
end

-- a tournament server: no PLAY (quick play) and no Tables; Shop, Stats and Settings stay
function LobbyHud:setTournamentServer(on)
	self.tournamentServer = on
	self.tablesButton.Visible = not on
	self:open(self.which)
end

-- which card is open: "bot", "tables", "stats", "shop", "tourney" or nil
function LobbyHud:open(which)
	self.which = which
	self.botCard.Visible = which == "bot"
	self.tablesCard.Visible = which == "tables"
	self.statsCard.Visible = which == "stats"
	self.shopCard.Visible = which == "shop"
	self.tourneyCard.Visible = which == "tourney"
	if which == "shop" then
		self.shop:showTab("abilities")
	elseif which == "tourney" then
		self.tourney:showTab("now")
	end
	self.bar.Visible = which == nil and not self.tournamentServer -- PLAY would sit under the open card
	self.side.Visible = which == nil or not self.compact -- (phones: the card needs the width)
	if which == "stats" then
		self.stats:setLoading()
		task.spawn(function()
			local data = self.cb.fetchStats()
			if self.which == "stats" then
				self.stats:show(data)
			end
		end)
	end
	if self.usingPad then
		GuiService.SelectedObject = if which == "bot" then self.startButton
			elseif which == "tables" then self.tableRows.T1.sit
			elseif which == "stats" then self.stats.closeFace
			elseif which == "shop" then self.shop.closeFace
			elseif which == "tourney" then self.tourney.closeFace
			else nil
	end
end

function LobbyHud:focusBar()
	GuiService.SelectedObject = self.playBot
end

function LobbyHud:setPad(on)
	self.usingPad = on
end

function LobbyHud:refreshBotCard()
	for i, face in self.levelTiles do
		local picked = i == self.choice.level
		Ui.restyle(face, if picked then "primary" else "secondary")
	end
	local clock = Settings.clock(self.choice.clock)
	setText(self.clockChoice, if clock then clock.label else self.choice.clock, I.clock)
	local color = COLORS[self.choice.color]
	setText(self.colorChoice, color.label, color.icon)
	local mode = Settings.MODES[self.choice.mode]
	setText(self.modeChoice, mode, I[mode] or "")
end

-- summaries: { [id] = { seats, status } } from the client's table mirrors
function LobbyHud:updateTables(summaries)
	for id, row in self.tableRows do
		local s = summaries[id]
		if s then
			local w, b = s.seats.w, s.seats.b
			local full = w ~= nil and b ~= nil
			if not w and not b then
				row.who.Text = "Empty"
			elseif full then
				row.who.Text = string.format("%s vs %s%s", w.name, b.name, if s.status == "playing" then "  (playing)" else "")
			else
				row.who.Text = (w or b).name .. " is waiting"
			end
			row.sit.Parent.Visible = s.status ~= "playing" and not full
			row.sit.Text = if (w or b) then "Join" else "Sit"
		end
	end
end

return LobbyHud
