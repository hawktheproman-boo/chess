-- The global tournament announcement: a gold pill across the top of the screen in every lobby server
-- (its own ScreenGui, so it shows while you're playing at a table too).
--   open      "🏆 Name's tournament starts in 4:32 · 6/16" [Join] (or "You're in!" [Leave]); stays
--             up for the whole countdown, and pops in with a sound when it's announced
--   started   "🏆 The tournament has started!" [Watch] for 20 s
--   finished  "🏆 Name won the tournament!" for 12 s
--   cancelled "Tournament cancelled: only 5 joined (8 needed)" for 8 s
-- Tapping the text opens the Tournament card.
--
--   TournamentBanner.new(cb) -> banner   cb = { join(), leave(), watch(), open() }
--   banner:setState(view, event?)   (view = Registry.view + startsIn, or nil)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tournament = require(Shared.Tournament)
local Ui = require(script.Parent.UiKit)
local Sounds = require(script.Parent.Sounds)
local T, I = Ui.T, Ui.ICONS

local TournamentBanner = {}
TournamentBanner.__index = TournamentBanner

local W, H = 620, 52
local rgb = Color3.fromRGB

function TournamentBanner.new(cb)
	local self = setmetatable({}, TournamentBanner)
	self.cb = cb
	local gui = Instance.new("ScreenGui")
	gui.Name = "ChessTournamentBanner"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 8
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui
	local scale = Instance.new("UIScale")
	scale.Parent = gui

	local pill = Instance.new("TextButton")
	pill.Name = "Banner"
	pill.Text = ""
	pill.AutoButtonColor = false
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0, 10)
	pill.Size = UDim2.fromOffset(W, H)
	pill.BackgroundColor3 = T.white
	pill.Visible = false
	pill.Parent = gui
	Ui.corner(pill, H // 2)
	Ui.gradient(pill, rgb(255, 214, 90), rgb(214, 140, 20))
	Ui.stroke(pill, T.ink, 3)
	pill.Activated:Connect(function()
		cb.open()
	end)
	self.pill = pill
	self.pop = Instance.new("UIScale")
	self.pop.Parent = pill
	Ui.icon(pill, I.vip, 38, UDim2.fromOffset(10, 7))
	local text = Ui.label(pill, "Text", "", UDim2.new(1, -190, 1, 0), UDim2.fromOffset(54, 0), Ui.TITLE, 21, T.white)
	Ui.chunky(text, 2)
	self.text = text
	local bh, b = Ui.button(pill, "Action", "Join", UDim2.fromOffset(120, 40), "primary", function()
		if self.action then
			self.cb[self.action]()
		end
	end)
	bh.AnchorPoint = Vector2.new(1, 0.5)
	bh.Position = UDim2.new(1, -8, 0.5, 0)
	b.TextSize = 20
	self.buttonHolder, self.button = bh, b

	local cam = workspace.CurrentCamera
	local function rescale()
		scale.Scale = Ui.uiScale(cam.ViewportSize)
	end
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()
	RunService.Heartbeat:Connect(function()
		if pill.Visible and os.clock() - (self.lastTick or 0) > 0.25 then
			self.lastTick = os.clock()
			self:refresh()
		end
	end)
	return self
end

function TournamentBanner:popIn()
	self.pop.Scale = 0.7
	TweenService:Create(self.pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Sounds.play("good")
end

function TournamentBanner:setState(view, event)
	self.view = view
	self.endsAt = if view and view.state == "open" and view.startsIn then os.clock() + view.startsIn else nil
	-- a short message for an event (started / finished / cancelled) stays up for a while
	if event == "started" or event == "finished" or event == "cancelled" then
		self.flash = event
		self.flashUntil = os.clock() + (if event == "started" then 20 elseif event == "finished" then 12 else 8)
	end
	self:refresh()
	if event == "open" or self.flash == event then
		if self.pill.Visible then
			self:popIn()
		end
	end
end

function TournamentBanner:refresh()
	local v = self.view
	local text, action
	if self.flash and os.clock() < (self.flashUntil or 0) then
		if self.flash == "started" and v and v.state == "live" then
			text, action = "The tournament has started!", if v.joined then nil else "watch"
		elseif self.flash == "finished" and v and v.champion then
			text = v.champion .. " won the tournament!"
		elseif self.flash == "cancelled" then
			text = "Tournament cancelled" .. (if v and v.reason then ": " .. v.reason else "")
		end
	else
		self.flash = nil
	end
	if not text and v and v.state == "open" then
		local left = math.max(0, math.floor((self.endsAt or os.clock()) - os.clock()))
		local clock = string.format("%d:%02d", left // 60, left % 60)
		if v.joined then
			text, action = string.format("You're in! Starts in %s · %d/%d", clock, v.count, Tournament.MAX), "leave"
		else
			text, action = string.format("%s's tournament starts in %s · %d/%d", v.hostName or "?", clock, v.count, Tournament.MAX), "join"
		end
	end
	self.pill.Visible = text ~= nil
	if not text then
		return
	end
	self.text.Text = text
	self.action = action
	self.buttonHolder.Visible = action ~= nil
	self.text.Size = UDim2.new(1, if action then -190 else -64, 1, 0)
	if action then
		Ui.restyle(self.button, if action == "leave" then "red" elseif action == "watch" then "blue" else "primary")
		Ui.setText(self.button, if action == "leave" then "Leave" elseif action == "watch" then "Watch" else "Join")
	end
end

return TournamentBanner
