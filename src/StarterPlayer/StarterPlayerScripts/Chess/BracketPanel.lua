-- The tournament server's screen (Tournament/Runner): the knockout bracket, one column per round,
-- each match a box with both names (the winner bright, the loser faded) and what's happening:
-- "LIVE · Table 3" with a Watch button, "Rematch", "Armageddon", "Bye". A status line on top
-- (players arriving / next round in 0:15 / the champion) and, for players, their own next match.
-- A Bracket button (top left) opens it again; Back to lobby teleports home.
-- Its own ScreenGui; ChessClient hides it while you're seated at your board.
--
--   BracketPanel.new(cb) -> panel   cb = { watch(tableId), lobby() }
--   panel:setView(v)   (Remotes.Tournament { kind = "bracket", ... })   panel:setSeated(on)
--   panel:open(on)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tournament = require(Shared.Tournament)
local Ui = require(script.Parent.UiKit)
local T, BOLD, HEAVY = Ui.T, Ui.BOLD, Ui.HEAVY
local corner, label, button, stroke = Ui.corner, Ui.label, Ui.button, Ui.stroke
local I, setText = Ui.ICONS, Ui.setText

local BracketPanel = {}
BracketPanel.__index = BracketPanel

local W, H = 900, 520
local TOP = 96 -- under the header and the status lines
local BOX_W, BOX_H, BOX_GAP = 196, 56, 8
local COL_GAP = 28
local rgb = Color3.fromRGB
local GOLD = rgb(255, 214, 90)
local STAGES = { rematch = "Rematch", armageddon = "Armageddon" }

local me = Players.LocalPlayer

function BracketPanel.new(cb)
	local self = setmetatable({}, BracketPanel)
	self.cb = cb
	self.seated = false
	self.wantOpen = true
	local gui = Instance.new("ScreenGui")
	gui.Name = "ChessBracket"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	gui.Parent = me:WaitForChild("PlayerGui")
	self.gui = gui
	local scale = Instance.new("UIScale")
	scale.Parent = gui

	-- the reopen button, top left
	local openH, openB = button(gui, "BracketButton", "Bracket", UDim2.fromOffset(170, 52), "gold", function()
		self:open(true)
	end, I.vip)
	openH.Position = UDim2.fromOffset(16, 12)
	openB.TextSize = 22
	setText(openB, "Bracket", I.vip)
	self.openHolder = openH

	local holder, body = Ui.card(gui, "Bracket", UDim2.fromOffset(W, H), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	self.holder = holder
	local head = Ui.header(body, "Tournament", nil, 30, I.vip)
	head.BackgroundColor3 = rgb(214, 158, 30)
	body.TitleFix.BackgroundColor3 = rgb(214, 158, 30)
	self.head = head
	Ui.closeX(body, function()
		self:open(false)
	end)
	local status = label(body, "Status", "", UDim2.new(1, -32, 0, 24), UDim2.fromOffset(16, 60), Ui.TITLE, 22, GOLD, Enum.TextXAlignment.Center)
	Ui.chunky(status, 1.5)
	self.status = status
	local mine = label(body, "Mine", "", UDim2.new(1, -32, 0, 20), UDim2.fromOffset(16, 84), HEAVY, 16, T.white, Enum.TextXAlignment.Center)
	mine.TextTransparency = 0.1
	self.mine = mine

	local area = Instance.new("ScrollingFrame")
	area.Name = "Rounds"
	area.BackgroundTransparency = 1
	area.BorderSizePixel = 0
	area.Position = UDim2.fromOffset(16, TOP + 14)
	area.Size = UDim2.fromOffset(W - 32, H - TOP - 14 - 80)
	area.ScrollBarThickness = 6
	area.ScrollBarImageColor3 = T.muted
	area.CanvasSize = UDim2.new()
	area.Parent = body
	self.area = area

	local backH, back = button(body, "Lobby", "Back to lobby", UDim2.fromOffset(240, 52), "secondary", function()
		cb.lobby()
	end, I.leave)
	backH.AnchorPoint = Vector2.new(0.5, 1)
	backH.Position = UDim2.new(0.5, 0, 1, -14)
	back.TextSize = 21
	setText(back, "Back to lobby", I.leave)

	local cam = workspace.CurrentCamera
	local function rescale()
		local v = cam.ViewportSize
		local s = Ui.uiScale(v)
		scale.Scale = s
		Ui.setFit(holder, math.min(1, (v.Y - 70) / (H * s), (v.X - 24) / (W * s)))
	end
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()
	RunService.Heartbeat:Connect(function()
		if holder.Visible and self.nextAt and os.clock() - (self.lastTick or 0) > 0.5 then
			self.lastTick = os.clock()
			self:refreshStatus()
		end
	end)
	self:apply()
	return self
end

function BracketPanel:apply()
	local show = self.wantOpen and not self.seated
	self.holder.Visible = show
	self.openHolder.Visible = not show and not self.seated
end

function BracketPanel:open(on)
	self.wantOpen = on
	self:apply()
end

function BracketPanel:setSeated(on)
	if on == self.seated then
		return
	end
	self.seated = on
	if not on then
		self.wantOpen = true -- back from your game: show where you stand
	end
	self:apply()
end

local function clockText(s)
	s = math.max(0, math.floor(s))
	return string.format("%d:%02d", s // 60, s % 60)
end

function BracketPanel:refreshStatus()
	local v = self.view
	if not v then
		return
	end
	local left = if self.nextAt then self.nextAt - os.clock() else nil
	local text
	if v.state == "none" then
		text = "There's no tournament in this server. Taking you back to the lobby…"
	elseif v.state == "arriving" then
		text = string.format("Players arriving: %d / %d%s", v.arrived or 0, v.expected or 0, if left then "  ·  starts in " .. clockText(left) else "")
	elseif v.state == "break" then
		text = (v.round or "Next round") .. (if left then " starts in " .. clockText(left) else "")
	elseif v.state == "done" then
		text = if v.champion then "🏆 " .. v.champion .. " is the champion!" else "The tournament is over"
	else
		text = (v.round or "Playing") .. "  ·  " .. (v.hostName or "?") .. "'s tournament"
	end
	self.status.Text = text
end

-- your own situation, from the bracket
local function myLine(v)
	local b = v.bracket
	if not b then
		return ""
	end
	local inIt, out = false, false
	for _, round in b.rounds do
		for _, m in round do
			local mineA = m.a and m.a.userId == me.UserId
			local mineB = m.b and m.b.userId == me.UserId
			if mineA or mineB then
				inIt = true
				if m.done and m.winner ~= me.UserId then
					out = true
				end
			end
		end
	end
	if not inIt then
		return "You're watching. Pick a live game below to watch it."
	end
	if b.finished then
		return if b.champion == me.UserId then "You won the tournament!" else "Thanks for playing!"
	end
	if out then
		return "You're out. Stay and watch the rest, or head back to the lobby."
	end
	local m = Tournament.matchOf(b, me.UserId)
	if m then
		local tableId = v.tables and v.tables[m.id]
		local opp = if m.a and m.a.userId == me.UserId then m.b else m.a
		return string.format("Your match: vs %s%s", opp and opp.name or "?", if tableId then "  ·  " .. string.gsub(tableId, "T", "Table ") else "  ·  starting soon")
	end
	return "You're through! Waiting for the next round."
end

function BracketPanel:setView(v)
	self.view = v
	self.nextAt = if v.nextIn then os.clock() + v.nextIn else nil
	self:refreshStatus()
	self.mine.Text = myLine(v)
	self:drawBracket()
end

local function nameRow(parent, p, y, won, lost)
	local l = label(parent, "Name", if p then p.name else "—", UDim2.new(1, -16, 0, 24), UDim2.fromOffset(8, y), HEAVY, 16,
		if won then rgb(140, 240, 110) else T.white)
	l.TextTransparency = if lost or not p then 0.55 else 0
	if p and p.userId == me.UserId then
		l.Text = l.Text .. " (you)"
	end
	return l
end

function BracketPanel:drawBracket()
	local area = self.area
	area:ClearAllChildren()
	local v = self.view
	local b = v and v.bracket
	if not b then
		return
	end
	local rounds = math.max(1, math.floor(math.log(b.size, 2) + 0.5))
	local tallest = 0
	for r = 1, rounds do
		local x = (r - 1) * (BOX_W + COL_GAP)
		local title = label(area, "Round" .. r, Tournament.roundName(r, b.size), UDim2.fromOffset(BOX_W, 22), UDim2.fromOffset(x, 0), Ui.TITLE, 18,
			if r == b.round and not b.finished then GOLD else T.muted, Enum.TextXAlignment.Center)
		Ui.chunky(title, 1)
		local matches = b.rounds[r]
		local slots = b.size // 2 ^ r
		-- later rounds sit centred between the matches that feed them
		local step = (BOX_H + BOX_GAP) * 2 ^ (r - 1)
		for i = 1, slots do
			local m = matches and matches[i]
			local y = 28 + (i - 1) * step + (step - BOX_H - BOX_GAP) / 2
			local box = Instance.new("Frame")
			box.Name = "M" .. r .. "_" .. i
			box.Position = UDim2.fromOffset(x, y)
			box.Size = UDim2.fromOffset(BOX_W, BOX_H)
			box.BackgroundColor3 = T.panelLift
			box.BorderSizePixel = 0
			box.Parent = area
			corner(box, 10)
			local tableId = m and v.tables and v.tables[m.id]
			stroke(box, if tableId then rgb(232, 70, 58) elseif m and m.done then T.ink else T.ink, if tableId then 3 else 2)
			if m then
				nameRow(box, m.a, 3, m.done and m.a and m.winner == m.a.userId, m.done and m.a and m.winner ~= m.a.userId)
				nameRow(box, m.b, 28, m.done and m.b and m.winner == m.b.userId, m.done and m.b and m.winner ~= m.b.userId)
				local tag
				if tableId then
					tag = "LIVE"
				elseif m.bye then
					tag = "BYE"
				elseif not m.done and STAGES[m.stage] then
					tag = string.upper(STAGES[m.stage])
				end
				if tableId then
					local wh, wb = button(box, "Watch", "Watch", UDim2.fromOffset(74, 26), "red", function()
						self.cb.watch(tableId)
					end)
					wh.AnchorPoint = Vector2.new(1, 0)
					wh.Position = UDim2.new(1, -4, 0, 4)
					wb.TextSize = 15
				elseif tag then
					local t = label(box, "Tag", tag, UDim2.fromOffset(80, 16), UDim2.new(1, -86, 0, 4), HEAVY, 11, GOLD, Enum.TextXAlignment.Right)
					t.TextTransparency = 0.1
				end
			else
				nameRow(box, nil, 3)
				nameRow(box, nil, 28)
			end
			tallest = math.max(tallest, y + BOX_H)
		end
	end
	area.CanvasSize = UDim2.fromOffset(rounds * (BOX_W + COL_GAP) - COL_GAP, tallest + 8)
	area.ScrollingDirection = Enum.ScrollingDirection.XY
end

return BracketPanel
