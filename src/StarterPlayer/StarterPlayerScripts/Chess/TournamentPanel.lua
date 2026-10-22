-- The lobby's Tournament card (from the Play screen's Tournament card, or the banner). Two tabs:
--   Tournament: what's on now (Shared/Tournament, Tournament/Launcher on the server):
--     none / ended  -> "Start a tournament" (VIPs) or "Get VIP to host"; anyone can join one
--     open          -> who's hosting, the countdown, the players (8 needed, 16 max), Join / Leave
--     live          -> the round being played, Watch (teleports you there as a spectator)
--   Today's games: the daily log (Tournament/DailyLog): every final's deciding game, the most
--     accurate games and the games with the most brilliant moves; Review opens one.
-- Fixed sizes only (no AutomaticSize), like every other card.
--
--   TournamentPanel.new(gui, cb) -> panel   cb = { close(), start(), join(), leave(), watch(), buyVip(),
--                                                  fetchToday() -> data | nil (yields), review(id) }
--   panel:setState(view)   view = Registry.view + startsIn (or nil: nothing on)
--   panel:setVip(on)   panel:showTab("now" | "today")   panel.holder, panel.closeFace

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tournament = require(Shared.Tournament)
local Ui = require(script.Parent.UiKit)
local T, BOLD, HEAVY = Ui.T, Ui.BOLD, Ui.HEAVY
local corner, label, button = Ui.corner, Ui.label, Ui.button
local I, setText = Ui.ICONS, Ui.setText

local TournamentPanel = {}
TournamentPanel.__index = TournamentPanel

local W, H = 680, 470
local TABS_H = 50
local CONTENT_Y = 62
local CONTENT_H = H - CONTENT_Y - TABS_H - 26
local rgb = Color3.fromRGB
local GOLD = rgb(255, 214, 90)
local RULES = string.format("Knockout  ·  Classic rules  ·  %s min + %s s  ·  %d–%d players\nA draw is replayed with colours swapped, then Armageddon (a draw counts as a Black win).",
	string.match(Tournament.CLOCK, "^(%d+)"), string.match(Tournament.CLOCK, "%+(%d+)$"), Tournament.MIN, Tournament.MAX)

local function frame(parent, name, size, pos)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Size = size
	f.Position = pos or UDim2.new()
	f.Parent = parent
	return f
end

local function clockText(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function TournamentPanel.new(gui, cb)
	local self = setmetatable({}, TournamentPanel)
	self.cb = cb
	self.view = nil
	self.vip = false

	local holder, body = Ui.card(gui, "Tournament", UDim2.fromOffset(W, H), UDim2.fromScale(0.5, 0.46), Vector2.new(0.5, 0.5))
	holder.Visible = false
	self.holder = holder
	local head = Ui.header(body, "Tournament", nil, 30, I.vip)
	head.BackgroundColor3 = rgb(214, 158, 30)
	body.TitleFix.BackgroundColor3 = rgb(214, 158, 30)
	local _, close = Ui.closeX(body, function()
		cb.close()
	end)
	self.closeFace = close

	-- Now tab -----------------------------------------------------------------------------------------
	local now = frame(body, "Now", UDim2.fromOffset(W - 32, CONTENT_H), UDim2.fromOffset(16, CONTENT_Y))
	self.nowTab = now
	local title = label(now, "Status", "", UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, 4), Ui.TITLE, 32, T.white, Enum.TextXAlignment.Center)
	Ui.chunky(title, 2.5)
	self.title = title
	local sub = label(now, "Sub", "", UDim2.new(1, 0, 0, 26), UDim2.fromOffset(0, 46), HEAVY, 20, GOLD, Enum.TextXAlignment.Center)
	Ui.chunky(sub, 1.5)
	self.sub = sub
	-- the players (up to 16, 4 to a row)
	local names = frame(now, "Players", UDim2.new(1, 0, 0, 4 * 30 + 3 * 6), UDim2.fromOffset(0, 82))
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.25, -6, 0, 30)
	grid.CellPadding = UDim2.fromOffset(8, 6)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = names
	self.nameLabels = {}
	for i = 1, Tournament.MAX do
		local l = label(names, "P" .. i, "", UDim2.new(), UDim2.new(), BOLD, 16, T.white, Enum.TextXAlignment.Center)
		l.LayoutOrder = i
		l.BackgroundColor3 = T.panelLift
		l.BackgroundTransparency = 0
		corner(l, 15)
		self.nameLabels[i] = l
	end
	self.namesFrame = names
	local rules = label(now, "Rules", RULES, UDim2.new(1, 0, 0, 44), UDim2.fromOffset(0, 230), BOLD, 15, T.muted, Enum.TextXAlignment.Center)
	rules.TextWrapped = true
	rules.TextTruncate = Enum.TextTruncate.None
	local actionH, action = button(now, "Action", "", UDim2.fromOffset(300, 58), "gold", function()
		self:pressAction()
	end)
	actionH.AnchorPoint = Vector2.new(0.5, 1)
	actionH.Position = UDim2.new(0.5, 0, 1, 0)
	action.TextSize = 26
	self.actionHolder, self.action = actionH, action

	-- Today tab ---------------------------------------------------------------------------------------
	local today = Instance.new("ScrollingFrame")
	today.Name = "Today"
	today.BackgroundTransparency = 1
	today.BorderSizePixel = 0
	today.Size = UDim2.fromOffset(W - 32, CONTENT_H)
	today.Position = UDim2.fromOffset(16, CONTENT_Y)
	today.ScrollBarThickness = 6
	today.ScrollBarImageColor3 = T.muted
	today.CanvasSize = UDim2.new()
	today.ScrollingDirection = Enum.ScrollingDirection.Y
	today.Visible = false
	today.Parent = body
	self.todayTab = today
	self.todayEmpty = label(body, "TodayEmpty", "", UDim2.fromOffset(W - 32, 60), UDim2.fromOffset(16, CONTENT_Y + 60), HEAVY, 20, T.muted, Enum.TextXAlignment.Center)
	self.todayEmpty.TextWrapped = true
	self.todayEmpty.Visible = false

	-- tabs ----------------------------------------------------------------------------------------------
	local tabs = frame(body, "Tabs", UDim2.new(1, -32, 0, TABS_H), UDim2.new(0, 16, 1, -TABS_H - 14))
	Ui.list(tabs, 12, true)
	local _, nowB = button(tabs, "NowTab", "Tournament", UDim2.fromOffset(210, TABS_H), "gold", function()
		self:showTab("now")
	end, I.vip)
	nowB.Parent.LayoutOrder = 1
	local _, todayB = button(tabs, "TodayTab", "Today's games", UDim2.fromOffset(230, TABS_H), "secondary", function()
		self:showTab("today")
	end, I.stats)
	todayB.Parent.LayoutOrder = 2
	for _, b in { nowB, todayB } do
		b.TextSize = 21
		setText(b, b.Text)
	end
	self.tabButtons = { now = nowB, today = todayB }

	-- the countdown ticks while the card is open
	RunService.Heartbeat:Connect(function()
		if holder.Visible and self.endsAt and os.clock() - (self.lastTick or 0) > 0.25 then
			self.lastTick = os.clock()
			self:refresh()
		end
	end)
	self:showTab("now")
	return self
end

function TournamentPanel:setVip(on)
	self.vip = on == true
	self:refresh()
end

function TournamentPanel:setState(view)
	self.view = view
	self.endsAt = if view and view.state == "open" and view.startsIn then os.clock() + view.startsIn else nil
	self.busy = false
	self:refresh()
end

function TournamentPanel:showTab(which)
	self.tab = which
	self.nowTab.Visible = which == "now"
	self.todayTab.Visible = which == "today"
	self.todayEmpty.Visible = false
	for id, b in self.tabButtons do
		Ui.restyle(b, if id == which then (if id == "now" then "gold" else "blue") else "secondary")
	end
	if which == "today" then
		self:loadToday()
	end
	self:refresh()
end

-- what the big button does right now
function TournamentPanel:actionFor()
	local v = self.view
	if v and v.state == "open" then
		return if v.joined then "leave" else "join"
	elseif v and (v.state == "live" or v.state == "launching") then
		return if v.state == "live" then "watch" else nil
	end
	return if self.vip then "start" else "vip"
end

function TournamentPanel:pressAction()
	if self.busy then
		return
	end
	local what = self:actionFor()
	if what == "vip" then
		self.cb.buyVip()
		return
	end
	if not what then
		return
	end
	self.busy = true
	self:refresh()
	task.spawn(function()
		self.cb[what]()
		self.busy = false
		self:refresh()
	end)
end

function TournamentPanel:refresh()
	local v = self.view
	local state = v and v.state
	local count = v and v.count or 0
	-- title + subline
	if state == "open" then
		self.title.Text = (v.hostName or "?") .. "'s Tournament"
		local left = if self.endsAt then self.endsAt - os.clock() else 0
		self.sub.Text = string.format("Starts in %s  ·  %d / %d players%s", clockText(left), count, Tournament.MAX,
			if count < Tournament.MIN then string.format(" (%d needed)", Tournament.MIN) else "")
	elseif state == "launching" then
		self.title.Text = "Starting…"
		self.sub.Text = string.format("%d players are heading to the tournament", count)
	elseif state == "live" then
		self.title.Text = (v.hostName or "?") .. "'s Tournament is live"
		self.sub.Text = (v.round or "Playing") .. "  ·  " .. count .. " players"
	elseif state == "done" and v.champion then
		self.title.Text = "🏆 " .. v.champion .. " won!"
		self.sub.Text = "Start the next one" .. (if self.vip then "" else " (VIPs host, anyone joins)")
	elseif state == "cancelled" then
		self.title.Text = "Tournament cancelled"
		self.sub.Text = v.reason or ""
	else
		self.title.Text = "No tournament right now"
		self.sub.Text = if self.vip then "Start one: everyone online gets 5 minutes to join" else "VIPs host tournaments, anyone can join"
	end
	-- players
	local names = v and (state == "open" or state == "launching" or state == "live") and v.names or {}
	for i, l in self.nameLabels do
		local n = names[i]
		l.Text = n or ""
		l.BackgroundTransparency = if n then 0 else 0.7
	end
	-- the button
	local what = self:actionFor()
	self.actionHolder.Visible = what ~= nil
	if what == "start" then
		Ui.restyle(self.action, "gold")
		setText(self.action, if self.busy then "…" else "Start a tournament", I.vip)
	elseif what == "vip" then
		Ui.restyle(self.action, "gold")
		setText(self.action, "Get VIP to host", I.vip)
	elseif what == "join" then
		Ui.restyle(self.action, "primary")
		setText(self.action, if self.busy then "…" else "Join", I.yes)
	elseif what == "leave" then
		Ui.restyle(self.action, "red")
		setText(self.action, if self.busy then "…" else "Leave", I.leave)
	elseif what == "watch" then
		Ui.restyle(self.action, "blue")
		setText(self.action, if self.busy then "…" else "Watch", I.review)
	end
end

-- Today's games ---------------------------------------------------------------------------------------

local SECTIONS = {
	{ key = "champions", title = "Champions' finals", icon = "🏆" },
	{ key = "top", title = "Highest accuracy", icon = "🎯" },
	{ key = "brilliant", title = "Most brilliant moves", icon = "✨" },
}
local ROW_H, HEAD_H, GAP = 58, 34, 6

local function resultText(e)
	local r = e.result or {}
	local score = if r.winner == "w" then "1-0" elseif r.winner == "b" then "0-1" else "½-½"
	return string.format("%s  ·  %s  ·  %d moves", score, r.reason or "?", math.ceil((e.plies or 0) / 2))
end

function TournamentPanel:loadToday()
	local token = (self.todayToken or 0) + 1
	self.todayToken = token
	self.todayTab:ClearAllChildren()
	self.todayEmpty.Text = "Loading today's games…"
	self.todayEmpty.Visible = true
	task.spawn(function()
		local data = self.cb.fetchToday()
		if self.todayToken ~= token or self.tab ~= "today" then
			return
		end
		self:showToday(data)
	end)
end

function TournamentPanel:showToday(data)
	local list = self.todayTab
	list:ClearAllChildren()
	if not data then
		self.todayEmpty.Text = "Couldn't load today's games"
		self.todayEmpty.Visible = true
		return
	end
	local y, any = 0, false
	for _, sec in SECTIONS do
		local entries = data[sec.key] or {}
		if #entries > 0 then
			any = true
			local h = label(list, sec.key .. "Head", sec.icon .. "  " .. sec.title, UDim2.new(1, -10, 0, HEAD_H), UDim2.fromOffset(0, y), Ui.TITLE, 22, GOLD)
			Ui.chunky(h, 1.5)
			y += HEAD_H
			for i, e in entries do
				local row = Instance.new("Frame")
				row.Name = sec.key .. i
				row.Size = UDim2.new(1, -10, 0, ROW_H)
				row.Position = UDim2.fromOffset(0, y)
				row.BackgroundColor3 = T.panelLift
				row.BorderSizePixel = 0
				row.Parent = list
				corner(row, 10)
				label(row, "Players", (e.white or "?") .. "  vs  " .. (e.black or "?"), UDim2.new(1, -250, 0, 26), UDim2.fromOffset(12, 5), HEAVY, 18, T.white)
				label(row, "Info", (e.round or "") .. "  ·  " .. resultText(e), UDim2.new(1, -250, 0, 20), UDim2.fromOffset(12, 31), BOLD, 14, T.muted)
				local stat = if sec.key == "brilliant" then string.format("✨ %d", e.bril or 0)
					elseif e.best then string.format("%.1f%%", e.best)
					else ""
				local s = label(row, "Stat", stat, UDim2.fromOffset(100, ROW_H), UDim2.new(1, -228, 0, 0), Ui.TITLE, 22, GOLD, Enum.TextXAlignment.Right)
				Ui.chunky(s, 1.5)
				local rh = button(row, "Review", "Review", UDim2.fromOffset(110, 40), "blue", function()
					self.cb.review(e.id)
				end, I.review)
				rh.AnchorPoint = Vector2.new(1, 0.5)
				rh.Position = UDim2.new(1, -9, 0.5, 0)
				y += ROW_H + GAP
			end
			y += 8
		end
	end
	list.CanvasSize = UDim2.fromOffset(0, y)
	self.todayEmpty.Text = "No tournament games today yet (" .. tostring(data.day or "") .. ", UTC)"
	self.todayEmpty.Visible = not any
end

return TournamentPanel
