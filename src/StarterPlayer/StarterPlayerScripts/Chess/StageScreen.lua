-- The big screen on the lobby's tournament stage (workspace.Lobby.Decor.Stage.Screen, 30 x 13 studs).
-- A SurfaceGui in PlayerGui adorned to that part, so its buttons can be clicked. It shows the
-- tournament the client already knows about, in text big enough to read from across the lobby:
--   none       "TOURNAMENT STAGE" and how a VIP starts one
--   open       the host, a live countdown, n / MAX players and a big JOIN button ("You're in!" once joined)
--   launching  "Starting..."
--   live       a red LIVE pill, the round, and a WATCH button (not for players who are in it)
--   done       a crown and "<name> is the champion!"
--   cancelled  "Tournament cancelled" and why
-- The part may arrive late or never (another place, an old build): setState just remembers the view.
--
--   StageScreen.new(cb) -> screen    cb = { join(), watch() }
--   screen:setState(view)            view = the tournament view the banner gets (Registry.view + startsIn), or nil

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tournament = require(Shared.Tournament)
local Ui = require(script.Parent.UiKit)
local T, I = Ui.T, Ui.ICONS

local StageScreen = {}
StageScreen.__index = StageScreen

local PPS = 40 -- pixels per stud: 30 x 13 studs = 1200 x 520 px
local W, H = 1200, 520
local FIND_TIMEOUT = 60 -- seconds to wait for each part of the path
local rgb = Color3.fromRGB
local NAVY_TOP, NAVY_BOTTOM = rgb(30, 42, 92), rgb(12, 18, 46)

local function find(...)
	local node = workspace
	for _, name in { ... } do
		node = node:WaitForChild(name, FIND_TIMEOUT)
		if not node then
			return nil
		end
	end
	return node
end

-- a big chunky label in the middle of the screen (placed per state by StageScreen:place)
local function bigLabel(parent, name, color)
	local l = Ui.label(parent, name, "", UDim2.new(1, -80, 0, 100), UDim2.fromOffset(40, 0), Ui.TITLE, 80, color or T.white, Enum.TextXAlignment.Center)
	l.TextTruncate = Enum.TextTruncate.None
	l.TextWrapped = true
	l.Visible = false
	Ui.chunky(l, 6)
	return l
end

function StageScreen.new(cb)
	local self = setmetatable({}, StageScreen)
	self.cb = cb or {}

	local gui = Instance.new("SurfaceGui")
	gui.Name = "ChessStageScreen"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PPS
	gui.LightInfluence = 0
	gui.MaxDistance = 200
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui

	-- dark navy panel with a gold border
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = T.white
	panel.BorderSizePixel = 0
	panel.Parent = gui
	Ui.corner(panel, 44)
	Ui.gradient(panel, NAVY_TOP, NAVY_BOTTOM)
	Ui.stroke(panel, T.gold, 12)

	self.title = bigLabel(panel, "Title", T.gold)
	self.big = bigLabel(panel, "Big", T.white)
	self.sub = bigLabel(panel, "Sub", T.muted)
	self.crown = Ui.icon(panel, I.queen, 150, UDim2.new(0.5, 0, 0, 40), Vector2.new(0.5, 0))
	self.crown.Visible = false

	-- the red LIVE pill
	local pill = Ui.label(panel, "Live", "LIVE", UDim2.fromOffset(260, 90), UDim2.new(0.5, 0, 0, 36), Ui.TITLE, 70, T.white, Enum.TextXAlignment.Center)
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.BackgroundColor3 = T.red
	pill.BackgroundTransparency = 0
	pill.Visible = false
	Ui.corner(pill, 45)
	Ui.stroke(pill, T.ink, 5)
	Ui.chunky(pill, 5)
	self.pill = pill

	-- the one action button (JOIN / WATCH)
	local holder, face = Ui.button(panel, "Action", "JOIN", UDim2.fromOffset(480, 120), "primary", function()
		local fn = self.action and self.cb[self.action]
		if fn then
			fn()
		end
	end)
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 370)
	holder.Visible = false
	face.TextSize = 76
	face.Outline.Thickness = 6
	self.buttonHolder, self.button = holder, face

	self.view = nil
	self.endsAt = nil
	self.tickConn = nil

	-- the part may come late: wait for it in the background
	task.spawn(function()
		local screen = find("Lobby", "Decor", "Stage", "Screen")
		if screen and screen:IsA("BasePart") then
			gui.Adornee = screen
		end
	end)

	self:render()
	return self
end

-- put a label in a row: y and height in pixels, text size
function StageScreen:place(l, text, y, h, size)
	l.Text = text
	l.Position = UDim2.fromOffset(40, y)
	l.Size = UDim2.new(1, -80, 0, h)
	l.TextSize = size
	l.Visible = true
end

local function clock(left: number): string
	left = math.max(0, math.floor(left))
	return string.format("%d:%02d", left // 60, left % 60)
end

function StageScreen:setState(view)
	self.view = view
	self.endsAt = if view and view.state == "open" and view.startsIn then os.clock() + view.startsIn else nil
	self:render()
end

function StageScreen:showButton(text, style, action)
	self.action = action
	self.buttonHolder.Visible = true
	Ui.restyle(self.button, style)
	Ui.setText(self.button, text)
end

-- the countdown ticks only while a tournament is open
function StageScreen:setTicking(on)
	if on and not self.tickConn then
		self.tickConn = RunService.RenderStepped:Connect(function()
			if self.endsAt then
				local s = clock(self.endsAt - os.clock())
				if s ~= self.big.Text then
					self.big.Text = s
				end
			end
		end)
	elseif not on and self.tickConn then
		self.tickConn:Disconnect()
		self.tickConn = nil
	end
end

function StageScreen:render()
	local v = self.view
	for _, l in { self.title, self.big, self.sub } do
		l.Visible = false
	end
	self.crown.Visible = false
	self.pill.Visible = false
	self.buttonHolder.Visible = false
	self.action = nil
	self.title.TextColor3 = T.gold
	self.big.TextColor3 = T.white
	self.sub.TextColor3 = T.muted
	self:setTicking(v ~= nil and v.state == "open")

	if not v then
		self:place(self.title, "TOURNAMENT STAGE", 90, 110, 100)
		self:place(self.sub, "No tournament right now. VIPs can host one from the Tournament card.", 240, 170, 56)
	elseif v.state == "open" then
		self:place(self.title, string.format("%s's tournament", v.hostName or "?"), 24, 90, 72)
		self:place(self.big, clock((self.endsAt or os.clock()) - os.clock()), 112, 170, 160)
		self.big.TextColor3 = T.gold
		self:place(self.sub, string.format("%d / %d players", v.count or 0, Tournament.MAX), 286, 70, 56)
		if v.joined then
			local l = self.sub
			l.TextColor3 = T.green
			self:place(l, string.format("You're in!   %d / %d players", v.count or 0, Tournament.MAX), 286, 70, 56)
			self:place(self.title, string.format("%s's tournament", v.hostName or "?"), 24, 90, 72)
		else
			self:showButton("JOIN", "primary", "join")
		end
	elseif v.state == "launching" then
		self:place(self.title, "TOURNAMENT", 90, 110, 100)
		self:place(self.big, "Starting…", 210, 170, 130)
	elseif v.state == "live" then
		self.pill.Visible = true
		self:place(self.title, tostring(v.round or "Tournament"), 150, 130, 110)
		self:place(self.sub, if v.joined then "You're in it. Good luck!" else "The tournament is being played now", 290, 70, 54)
		if not v.joined then
			self:showButton("WATCH", "blue", "watch")
		end
	elseif v.state == "done" then
		self.crown.Visible = true
		self:place(self.title, if v.champion then v.champion .. " is the champion!" else "Tournament finished", 220, 220, 90)
	elseif v.state == "cancelled" then
		self:place(self.title, "Tournament cancelled", 90, 110, 96)
		self.title.TextColor3 = T.red
		if v.reason then
			self:place(self.sub, tostring(v.reason), 240, 170, 56)
		end
	else
		self:place(self.title, "TOURNAMENT STAGE", 90, 110, 100)
	end
end

return StageScreen
