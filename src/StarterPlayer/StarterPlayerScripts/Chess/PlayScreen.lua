-- The Play screen (the "matchmaking" look): the world blurs and darkens, a big PLAY title, and a
-- row of mode cards: vs Bot, Classic 1v1, Abilities 1v1, Tournament (VIPs host, anyone joins).
-- Hovering / tapping / D-pad picks a card: it grows, gets a white back plate, a shine sweeps across
-- it and a PLAY button shows. It only calls back; ChessClient talks to the server.
--
--   local screen = PlayScreen.new({ bot = fn(), pvp = fn(mode), tournament = fn(), shown = fn(open)? })
--   screen:open(usingPad)   screen:close()   screen:isOpen()

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent.UiKit)
local Sounds = require(script.Parent.Sounds)
local T, I = Ui.T, Ui.ICONS
local label, corner, stroke, button = Ui.label, Ui.corner, Ui.stroke, Ui.button

local PlayScreen = {}
PlayScreen.__index = PlayScreen

local rgb = Color3.fromRGB
local CARD = 270
-- id, icon, name, big centre text, gradient top -> bottom, tag + its icon (shown when not picked), locked
local MODES = {
	{ id = "bot", icon = I.bot, name = "VS BOT", big = "VS AI", top = rgb(38, 166, 154), bottom = rgb(34, 92, 52), tag = "ALL LEVELS", tagIcon = I.Beginner },
	{ id = "Classic", icon = I.Classic, name = "CLASSIC", big = "1v1", top = rgb(232, 178, 48), bottom = rgb(40, 110, 46), tag = "POPULAR", tagIcon = I.fire },
	{ id = "Abilities", icon = I.Abilities, name = "ABILITIES", big = "1v1", top = rgb(226, 72, 72), bottom = rgb(96, 36, 140), tag = "NEW", tagIcon = I.new },
	{ id = "Tournament", icon = I.vip, name = "TOURNAMENT", big = "CUP", top = rgb(240, 196, 64), bottom = rgb(28, 40, 96), tag = "VIP HOSTS", tagIcon = I.vip },
}
local NAV_ACTION = "ChessPlayScreenNav"
local PICK = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- a dashed border just inside a card (small white dashes along each edge)
local function dashes(parent, inset, count)
	for side = 1, 4 do
		for i = 0, count - 1 do
			local d = Instance.new("Frame")
			d.BorderSizePixel = 0
			d.BackgroundColor3 = T.white
			d.BackgroundTransparency = 0.45
			d.ZIndex = 2
			local t = (i + 0.25) / count
			if side == 1 or side == 3 then -- top / bottom
				d.Size = UDim2.new(0.5 / count, 0, 0, 2)
				d.Position = UDim2.new(t, 0, if side == 1 then 0 else 1, if side == 1 then inset else -inset - 2)
			else -- left / right
				d.Size = UDim2.new(0, 2, 0.5 / count, 0)
				d.Position = UDim2.new(if side == 4 then 0 else 1, if side == 4 then inset else -inset - 2, t, 0)
			end
			d.Parent = parent
		end
	end
end

-- big display text with a soft dark shadow underneath (the matchmaking title look)
local function display(parent, name, text, size, pos, textSize, anchor)
	local shadow = label(parent, name .. "Shadow", text, size, pos + UDim2.fromOffset(0, 4), Ui.DISPLAY, textSize, T.ink, Enum.TextXAlignment.Center)
	shadow.TextTransparency = 0.55
	local l = label(parent, name, text, size, pos, Ui.DISPLAY, textSize, T.white, Enum.TextXAlignment.Center)
	shadow.TextTruncate, l.TextTruncate = Enum.TextTruncate.None, Enum.TextTruncate.None
	shadow.AnchorPoint, l.AnchorPoint = anchor or Vector2.zero, anchor or Vector2.zero
	shadow.ZIndex, l.ZIndex = 3, 4
	return l, shadow
end

function PlayScreen.new(cb)
	local self = setmetatable({}, PlayScreen)
	self.cb = cb
	local gui = Instance.new("ScreenGui")
	gui.Name = "ChessPlay"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 15 -- above the lobby, below Settings (20)
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = rgb(6, 14, 8)
	dim.BackgroundTransparency = 0.4
	dim.BorderSizePixel = 0
	dim.Active = true -- swallows clicks meant for the world behind
	dim.Parent = gui

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(1280, 720)
	root.BackgroundTransparency = 1
	root.Parent = dim
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local cam = workspace.CurrentCamera
	local footer = {}
	local close
	-- Phones: the 720-tall layout would shrink to ~0.5. Instead the tip is dropped, the layout is
	-- cropped to the kicker..scroll bar band (y 46..616) and stretched to the screen's width, so the
	-- cards come out ~30% bigger and scroll sideways.
	local function rescale()
		local v = cam.ViewportSize
		if Ui.compact(v) then
			local s = math.min(v.Y / 570, 1)
			scale.Scale = s
			root.Size = UDim2.fromOffset(math.max(v.X / s, 600), 720)
			root.AnchorPoint, root.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, -46 * s)
			close.Position = UDim2.new(1, -24, 0, 54)
		else
			scale.Scale = math.clamp(math.min(v.X / 1280, v.Y / 720), 0.45, 1.3)
			root.Size = UDim2.fromOffset(1280, 720)
			root.AnchorPoint, root.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
			close.Position = UDim2.new(1, -40, 0, 40)
		end
		for _, f in footer do
			f.Visible = not Ui.compact(v)
		end
	end

	-- kicker + title
	local kicker = label(root, "Kicker", Ui.spaced("Choose a mode"), UDim2.new(1, 0, 0, 24), UDim2.fromOffset(0, 52), Ui.MEDIUM, 20, T.text, Enum.TextXAlignment.Center)
	kicker.TextTransparency = 0.1
	display(root, "Title", "PLAY", UDim2.new(1, 0, 0, 90), UDim2.fromOffset(0, 74), 88)

	-- outlined circle X (top right)
	close = Instance.new("TextButton")
	close.Name = "Close"
	close.Text = "X"
	close.FontFace = Ui.DISPLAY
	close.TextSize = 30
	close.TextColor3 = T.white
	close.BackgroundTransparency = 1
	close.Size = UDim2.fromOffset(64, 64)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -40, 0, 40)
	close.Selectable = true
	close.Parent = root
	corner(close, 32)
	stroke(close, T.white, 3)
	close.Activated:Connect(function()
		self:close()
	end)
	self.closeButton = close

	-- the card row (scrolls sideways when it doesn't fit)
	local row = Instance.new("ScrollingFrame")
	row.Name = "Cards"
	row.Size = UDim2.new(1, 0, 0, CARD + 90)
	row.Position = UDim2.fromOffset(0, 190)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.ScrollingDirection = Enum.ScrollingDirection.X
	row.ScrollBarThickness = 0
	row.AutomaticCanvasSize = Enum.AutomaticSize.X
	row.CanvasSize = UDim2.new()
	row.Selectable = false
	row.Parent = root
	Ui.list(row, 32, true) -- 4 cards fit at 1280 wide (centred); narrower screens scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 40), UDim.new(0, 40)
	pad.Parent = row
	self.row = row

	self.cards = {}
	for i, m in MODES do
		self.cards[i] = self:makeCard(row, i, m)
	end

	-- scroll indicator
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.new(0.5, 0, 0, 600)
	track.Size = UDim2.fromOffset(820, 8)
	track.BackgroundColor3 = T.white
	track.BackgroundTransparency = 0.8
	track.BorderSizePixel = 0
	track.Parent = root
	corner(track, 4)
	stroke(track, T.white, 1, 0.6)
	local thumb = Instance.new("Frame")
	thumb.Name = "Thumb"
	thumb.BackgroundColor3 = T.white
	thumb.BorderSizePixel = 0
	thumb.Size = UDim2.fromScale(0.3, 1)
	thumb.Parent = track
	corner(thumb, 4)
	local function updateThumb()
		local canvas = row.AbsoluteCanvasSize.X
		local window = row.AbsoluteWindowSize.X
		if canvas <= window + 1 then
			track.Visible = false
			return
		end
		track.Visible = true
		local frac = window / canvas
		thumb.Size = UDim2.fromScale(frac, 1)
		thumb.Position = UDim2.fromScale((1 - frac) * row.CanvasPosition.X / (canvas - window), 0)
	end
	row:GetPropertyChangedSignal("CanvasPosition"):Connect(updateThumb)
	row:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updateThumb)
	row:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updateThumb)
	self.updateThumb = updateThumb

	-- footer
	footer[1] = label(root, "Footer", Ui.spaced("Tip"), UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 636), Ui.MEDIUM, 16, T.muted, Enum.TextXAlignment.Center)
	footer[2] = label(root, "FooterText", "In Abilities, every piece has a power you can use once per game.", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 658), Ui.MEDIUM, 17, T.text, Enum.TextXAlignment.Center)
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()
	return self
end

function PlayScreen:makeCard(row, index, m)
	local holder = Instance.new("Frame")
	holder.Name = m.id
	holder.Size = UDim2.fromOffset(CARD, CARD + 60)
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = index
	holder.Parent = row
	local sc = Instance.new("UIScale")
	sc.Parent = holder

	-- the white back plate (picked card only), offset like a sticker behind the card
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.Size = UDim2.fromOffset(CARD + 20, CARD + 20)
	plate.Position = UDim2.fromOffset(-6, 20)
	plate.BackgroundColor3 = T.white
	plate.BorderSizePixel = 0
	plate.Visible = false
	plate.Parent = holder
	corner(plate, 10)

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.fromOffset(CARD, CARD)
	face.Position = UDim2.fromOffset(4, 30)
	face.BackgroundColor3 = T.white
	face.BorderSizePixel = 0
	face.ClipsDescendants = true
	face.Parent = holder
	corner(face, 8)
	Ui.gradient(face, m.top, m.bottom)
	local edge = stroke(face, T.white, 2, 0.35)
	dashes(face, 10, 12)

	-- big art behind the text: the drawn card illustration, or (no images) a giant faded icon
	local art = Instance.new("ImageLabel")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	-- big and faded, tucked into the bottom-right corner (clipped by the card) like the art on
	-- matchmaking cards, so the small icon and the big label stay the stars
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Size = UDim2.fromOffset(250, 250)
	art.Position = UDim2.fromOffset(CARD - 62, CARD - 58)
	art.Rotation = -12
	art.ImageTransparency = 0.5
	art.ZIndex = 1
	art.Parent = face
	if not Ui.Icons.card(art, m.id) then
		art:Destroy()
		art = label(face, "Art", m.icon, UDim2.fromOffset(240, 240), UDim2.fromOffset(110, 100), Ui.BOLD, 190, T.white, Enum.TextXAlignment.Center)
		art.TextTransparency = 0.78
		art.Rotation = -14
		art.TextTruncate = Enum.TextTruncate.None
		art.ZIndex = 1
	end

	-- icon + spaced name at the top, the big label in the middle
	local icon = Ui.icon(face, m.icon, 52, UDim2.new(0.5, 0, 0, 24), Vector2.new(0.5, 0))
	icon.ZIndex = 3
	local name = label(face, "Name", Ui.spaced(m.name), UDim2.new(1, 0, 0, 24), UDim2.fromOffset(0, 80), Ui.DISPLAY, 18, T.white, Enum.TextXAlignment.Center)
	name.ZIndex = 3
	display(face, "Big", m.big, UDim2.new(1, 0, 0, 90), UDim2.new(0, 0, 0.5, 6), 70, Vector2.new(0, 0.5))

	-- tag at the bottom (hidden while picked: the PLAY button takes its place)
	local tag = label(face, "Tag", "", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 1, -52), Ui.TITLE, 22, T.gold, Enum.TextXAlignment.Center)
	tag.ZIndex = 3
	Ui.setText(tag, m.tag, m.tagIcon)
	Ui.chunky(tag, 2)

	-- shine: a soft white stripe that sweeps across the picked card
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Size = UDim2.new(0.28, 0, 1.6, 0)
	shine.AnchorPoint = Vector2.new(0.5, 0.5)
	shine.Position = UDim2.fromScale(-0.4, 0.5)
	shine.Rotation = 24
	shine.BackgroundColor3 = T.white
	shine.BorderSizePixel = 0
	shine.ZIndex = 5
	shine.Visible = false
	shine.Parent = face
	local sg = Instance.new("UIGradient")
	sg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(1, 1) })
	sg.Parent = shine

	-- PLAY (or the locked button) under the big label
	local playH, play
	if m.locked then
		playH, play = button(face, "Play", "Soon", UDim2.fromOffset(170, 52), "locked", function() end, I.lock)
	else
		playH, play = button(face, "Play", "PLAY", UDim2.fromOffset(170, 52), "primary", function()
			self:play(index)
		end)
	end
	play.TextSize = 26
	Ui.setText(play, if m.locked then "Soon" else "PLAY")
	playH.AnchorPoint = Vector2.new(0.5, 1)
	playH.Position = UDim2.new(0.5, 0, 1, -18)
	playH.ZIndex = 6
	playH.Visible = false
	play.Selectable = false -- the card button above it takes the controller's A

	-- the whole card is one button: hover / D-pad focus picks it, a click on the picked card plays
	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 10 -- on top: a click anywhere on the picked card (PLAY included) plays it
	hit.Selectable = true
	hit.SelectionImageObject = Instance.new("Frame") -- no default selection box; picking shows it
	hit.SelectionImageObject.BackgroundTransparency = 1
	hit.Parent = holder
	hit.MouseEnter:Connect(function()
		self:pick(index)
	end)
	hit.SelectionGained:Connect(function()
		self:pick(index)
	end)
	hit.Activated:Connect(function()
		Sounds.play("click")
		if self.picked == index then
			self:play(index)
		else
			self:pick(index)
		end
	end)

	return { holder = holder, scale = sc, plate = plate, face = face, edge = edge, tag = tag, shine = shine, play = playH, hit = hit, mode = m }
end

function PlayScreen:pick(index)
	if self.picked == index then
		return
	end
	self.picked = index
	for i, c in self.cards do
		local on = i == index
		TweenService:Create(c.scale, PICK, { Scale = if on then 1.08 else 0.96 }):Play()
		c.plate.Visible = on
		c.edge.Transparency = if on then 0 else 0.35
		c.play.Visible = on
		c.tag.Visible = not on
		c.shine.Visible = on
		if c.shineTween then
			c.shineTween:Cancel()
			c.shineTween = nil
		end
		if on then
			c.shine.Position = UDim2.fromScale(-0.4, 0.5)
			c.shineTween = TweenService:Create(c.shine, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 1.6), { Position = UDim2.fromScale(1.4, 0.5) })
			c.shineTween:Play()
		end
	end
	-- keep the picked card in view
	local c = self.cards[index]
	local left = c.holder.AbsolutePosition.X - self.row.AbsolutePosition.X + self.row.CanvasPosition.X
	local window = self.row.AbsoluteWindowSize.X
	local target = math.clamp(left - (window - c.holder.AbsoluteSize.X) / 2, 0, math.max(0, self.row.AbsoluteCanvasSize.X - window))
	TweenService:Create(self.row, PICK, { CanvasPosition = Vector2.new(target, 0) }):Play()
end

function PlayScreen:play(index)
	local m = MODES[index]
	if m.locked then
		return
	end
	self:close()
	if m.id == "bot" then
		self.cb.bot()
	elseif m.id == "Tournament" then
		self.cb.tournament()
	else
		self.cb.pvp(m.id)
	end
end

function PlayScreen:open(usingPad)
	self.gui.Enabled = true
	if self.cb.shown then
		self.cb.shown(true)
	end
	local blur = Lighting:FindFirstChild("ChessPlayBlur") or Instance.new("BlurEffect")
	blur.Name = "ChessPlayBlur"
	blur.Size = 0
	blur.Parent = Lighting
	TweenService:Create(blur, TweenInfo.new(0.25), { Size = 18 }):Play()
	self.picked = nil
	self:pick(2) -- Classic
	task.defer(self.updateThumb)
	if usingPad then
		GuiService.SelectedObject = self.cards[2].hit
	end
	-- controller: B closes, A on the picked card plays (A is the native select on the card button)
	ContextActionService:BindActionAtPriority(NAV_ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			self:close()
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.ButtonB)
end

function PlayScreen:close()
	if not self.gui.Enabled then
		return
	end
	self.gui.Enabled = false
	if self.cb.shown then
		self.cb.shown(false)
	end
	ContextActionService:UnbindAction(NAV_ACTION)
	local blur = Lighting:FindFirstChild("ChessPlayBlur")
	if blur then
		blur:Destroy()
	end
	for _, c in self.cards do
		if c.shineTween then
			c.shineTween:Cancel()
			c.shineTween = nil
		end
	end
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.gui) then
		GuiService.SelectedObject = nil
	end
end

function PlayScreen:isOpen()
	return self.gui.Enabled
end

return PlayScreen
