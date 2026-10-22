-- The Settings sheet, opened from the lobby bar or the seated HUD: board theme swatches (a mini
-- board each), the piece set (a button that steps through Settings.PIECE_SETS), the background
-- music tick box, the sound toggle and auto-queen. It only reports choices; the client applies and
-- saves them.
--   SettingsPanel.new({ theme = fn(id), sound = fn(on), music = fn(on), autoQueen = fn(on), pieceSet = fn(id) })
--   panel:open(prefs)

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local Themes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Themes"))
local Settings = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Settings"))
local Ui = require(script.Parent.UiKit)
local Sounds = require(script.Parent.Sounds)

local T, HEAVY, BOLD = Ui.T, Ui.HEAVY, Ui.BOLD
local corner, stroke, card, label, button = Ui.corner, Ui.stroke, Ui.card, Ui.label, Ui.button
local I, setText = Ui.ICONS, Ui.setText

local SettingsPanel = {}
SettingsPanel.__index = SettingsPanel

function SettingsPanel.new(cb)
	local self = setmetatable({}, SettingsPanel)
	self.cb = cb
	self.prefs = { theme = Themes.DEFAULT, sound = true, music = true, autoQueen = false, pieceSet = Settings.DEFAULT_PIECE_SET }

	local gui = Instance.new("ScreenGui")
	gui.Name = "ChessSettings"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20 -- above both HUDs
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	-- (built at the largest size of both layouts, so the card's checkerboard covers either)
	local holder, body = card(gui, "Sheet", UDim2.fromOffset(760, 530), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	Ui.header(body, "Settings", nil, nil, I.settings)
	Ui.closeX(body, function()
		self:close()
	end)

	local themeLabel = label(body, "ThemeLabel", "", UDim2.new(1, -32, 0, 24), UDim2.fromOffset(16, 64), HEAVY, 20, T.text)
	setText(themeLabel, "Board", I.theme)
	local grid = Instance.new("Frame")
	grid.Name = "Themes"
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, -32, 0, 236)
	grid.Position = UDim2.fromOffset(16, 94)
	grid.Parent = body
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / 3, -8, 0.5, -6)
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	self.swatches = {}
	for i, theme in ipairs(Themes) do
		local b = Instance.new("TextButton")
		b.Name = theme.id
		b.Text = ""
		b.LayoutOrder = i
		b.BackgroundColor3 = T.panelLift
		b.AutoButtonColor = true
		b.Selectable = true
		b.Parent = grid
		corner(b, 12)
		local ring = stroke(b, T.ink, 2)
		-- a mini 4x4 board
		local mini = Instance.new("Frame")
		mini.Name = "Mini"
		mini.AnchorPoint = Vector2.new(0.5, 0)
		mini.Position = UDim2.new(0.5, 0, 0, 8)
		mini.Size = UDim2.new(0, 76, 0, 76)
		mini.BackgroundColor3 = theme.frame2D
		mini.BorderSizePixel = 0
		mini.Active = false
		mini.Parent = b
		corner(mini, 6)
		for r = 0, 3 do
			for f = 0, 3 do
				local c = Instance.new("Frame")
				c.Size = UDim2.fromOffset(17, 17)
				c.Position = UDim2.fromOffset(4 + f * 17, 4 + r * 17)
				c.BackgroundColor3 = if (r + f) % 2 == 0 then theme.light else theme.dark
				c.BorderSizePixel = 0
				c.Parent = mini
			end
		end
		label(b, "Name", theme.name, UDim2.new(1, -8, 0, 22), UDim2.new(0, 4, 1, -26), BOLD, 16, T.text, Enum.TextXAlignment.Center)
		b.Activated:Connect(function()
			Sounds.play("click")
			self.prefs.theme = theme.id
			self:refresh()
			cb.theme(theme.id)
		end)
		self.swatches[theme.id] = { button = b, ring = ring }
	end

	local soundH, sound = button(body, "Sound", "Sound", UDim2.new(0.5, -22, 0, 50), "secondary", function()
		self.prefs.sound = not self.prefs.sound
		self:refresh()
		cb.sound(self.prefs.sound)
	end, I.soundOn)
	soundH.Position = UDim2.new(0, 16, 1, -126)
	self.soundButton = sound
	local queenH, queen = button(body, "AutoQueen", "Auto-queen", UDim2.new(0.5, -22, 0, 50), "secondary", function()
		self.prefs.autoQueen = not self.prefs.autoQueen
		self:refresh()
		cb.autoQueen(self.prefs.autoQueen)
	end, I.queen)
	queenH.AnchorPoint = Vector2.new(1, 0)
	queenH.Position = UDim2.new(1, -16, 1, -126)
	self.queenButton = queen
	-- piece set: each press steps to the next one
	local setH, setB = button(body, "PieceSet", "Pieces", UDim2.new(1, -32, 0, 50), "secondary", function()
		local list = Settings.PIECE_SETS
		local at = 1
		for i, s in list do
			if s.id == self.prefs.pieceSet then
				at = i
			end
		end
		self.prefs.pieceSet = list[at % #list + 1].id
		self:refresh()
		cb.pieceSet(self.prefs.pieceSet)
	end, I.Classic)
	setH.Position = UDim2.new(0, 16, 1, -186)
	self.setButton = setB
	-- background music: a tick box
	local musicH, _, setMusic = Ui.checkbox(body, "Music", "Background music", UDim2.new(1, -32, 0, 50), function(on)
		self.prefs.music = on
		cb.music(on)
	end)
	self.setMusic = setMusic
	local closeH, close = button(body, "Close", "Done", UDim2.new(1, -32, 0, 50), "primary", function()
		self:close()
	end, I.yes)
	closeH.Position = UDim2.new(0, 16, 1, -66)
	self.closeButton = close

	-- Wide screens: a tall card (themes, then the toggles, then Done). Phones: a wide one (themes
	-- left, the buttons stacked on the right), so it can be drawn much bigger.
	local cam = workspace.CurrentCamera
	local function rescale()
		local v = cam.ViewportSize
		if Ui.compact(v) then
			holder.Size = UDim2.fromOffset(760, 346)
			grid.Size = UDim2.fromOffset(470, 236)
			for i, h in { setH, musicH, soundH, queenH, closeH } do
				h.Size = UDim2.fromOffset(240, 46)
				h.AnchorPoint = Vector2.new(1, 0)
				h.Position = UDim2.new(1, -16, 0, 80 + (i - 1) * 52 + (if i == 5 then 10 else 0))
			end
			local room = v.Y - GuiService:GetGuiInset().Y - 40 -- (the close X overhangs the top)
			scale.Scale = math.min(Ui.uiScale(v), room / 346)
		else
			holder.Size = UDim2.fromOffset(500, 590)
			grid.Size = UDim2.new(1, -32, 0, 236)
			setH.Size, setH.AnchorPoint, setH.Position = UDim2.new(1, -32, 0, 50), Vector2.zero, UDim2.new(0, 16, 1, -246)
			musicH.Size, musicH.AnchorPoint, musicH.Position = UDim2.new(1, -32, 0, 50), Vector2.zero, UDim2.new(0, 16, 1, -186)
			soundH.Size, soundH.AnchorPoint, soundH.Position = UDim2.new(0.5, -22, 0, 50), Vector2.zero, UDim2.new(0, 16, 1, -126)
			queenH.Size, queenH.AnchorPoint, queenH.Position = UDim2.new(0.5, -22, 0, 50), Vector2.new(1, 0), UDim2.new(1, -16, 1, -126)
			closeH.Size, closeH.AnchorPoint, closeH.Position = UDim2.new(1, -32, 0, 50), Vector2.zero, UDim2.new(0, 16, 1, -66)
			scale.Scale = math.clamp(math.min(v.X / 620, v.Y / 740), 0.6, 1)
		end
	end
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()
	return self
end

function SettingsPanel:refresh()
	for id, s in self.swatches do
		local on = id == self.prefs.theme
		s.ring.Color = if on then T.gold else T.ink
		s.ring.Thickness = if on then 4 else 2
		s.button.BackgroundColor3 = if on then T.green:Lerp(T.panel, 0.4) else T.panelLift
	end
	setText(self.soundButton, if self.prefs.sound then "Sound on" else "Sound off", if self.prefs.sound then I.soundOn else I.soundOff)
	setText(self.queenButton, "Auto-queen " .. (if self.prefs.autoQueen then "on" else "off"))
	self.setMusic(self.prefs.music ~= false)
	local set = Settings.pieceSet(self.prefs.pieceSet) or Settings.PIECE_SETS[1]
	setText(self.setButton, "Pieces: " .. set.name)
	-- an "on" toggle is green
	for _, b in { { self.soundButton, self.prefs.sound }, { self.queenButton, self.prefs.autoQueen } } do
		Ui.restyle(b[1], if b[2] then "primary" else "secondary")
	end
end

function SettingsPanel:open(prefs)
	self.prefs = table.clone(prefs)
	self:refresh()
	self.gui.Enabled = true
	if GuiService:IsTenFootInterface() or GuiService.SelectedObject then
		GuiService.SelectedObject = self.swatches[self.prefs.theme].button
	end
end

function SettingsPanel:close()
	self.gui.Enabled = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.gui) then
		GuiService.SelectedObject = nil
	end
end

function SettingsPanel:isOpen()
	return self.gui.Enabled
end

return SettingsPanel
