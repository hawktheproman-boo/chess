-- Shared look for every chess GUI: the "simulator" style (see the vault's Design/UI Style.md).
-- Deep green panels with a faint checkerboard and a thick ink outline, chunky Fredoka One text
-- with an ink outline, saturated gradient buttons with diagonal stripes, emoji icons beside the
-- text. Icons are the Illustrator set drawn through EditableImage (Icons.lua); where that isn't
-- allowed they fall back to emoji. Nothing here needs uploaded images.

local TweenService = game:GetService("TweenService")

local Sounds = require(script.Parent.Sounds)
local Icons = require(script.Parent.Icons)

local Ui = {}

local function font(weight)
	return Font.new("rbxasset://fonts/families/BuilderSans.json", weight or Enum.FontWeight.Bold)
end
local BOLD = font(Enum.FontWeight.Bold)
local HEAVY = font(Enum.FontWeight.ExtraBold)
local MEDIUM = font(Enum.FontWeight.Medium)
-- chunky titles and buttons (the egg-panel look) and the big Play-screen display type
local TITLE = Font.new("rbxasset://fonts/families/FredokaOne.json")
local DISPLAY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)

local rgb = Color3.fromRGB
local T = {
	-- panels
	panel = rgb(30, 59, 34),
	panelDeep = rgb(18, 38, 21),
	panelLift = rgb(46, 84, 50),
	ink = rgb(12, 20, 12),
	-- accents
	green = rgb(91, 194, 54),
	greenEdge = rgb(52, 128, 30),
	gold = rgb(255, 200, 61),
	blue = rgb(52, 152, 219),
	abilities = rgb(176, 58, 160),
	locked = rgb(70, 78, 90),
	red = rgb(232, 70, 58),
	redEdge = rgb(150, 36, 28),
	white = rgb(255, 255, 255),
	-- text on panels
	text = rgb(242, 248, 236),
	muted = rgb(168, 196, 160),
	-- older names, re-pointed for the dark style
	greenDeep = rgb(255, 214, 102), -- accent text (was dark green on white)
	greenSoft = rgb(46, 84, 50), -- inner rows / boxes
	whiteEdge = rgb(12, 20, 12), -- outlines
	clockIdle = rgb(18, 38, 21),
	shadow = rgb(0, 0, 0),
}

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 2
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function gradient(parent, top, bottom, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end

local function shade(c, k)
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

-- a soft white sheen over the top half of a button / bar. (A UIGradient on a text object would
-- tint its text too, so faces keep a flat colour and get this overlay instead.)
local SHEEN = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.7),
	NumberSequenceKeypoint.new(0.5, 1),
	NumberSequenceKeypoint.new(1, 1),
})
local function highlight(frame, r)
	local f = Instance.new("Frame")
	f.Name = "Sheen"
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BorderSizePixel = 0
	f.Active = false
	f.Parent = frame
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = f
	local g = Instance.new("UIGradient")
	g.Transparency = SHEEN
	g.Rotation = 90
	g.Parent = f
	return f
end

-- chunky text: Fredoka One, white, thick ink outline (titles, buttons, big numbers)
local function chunky(l, thickness, face)
	l.FontFace = face or TITLE
	local s = Instance.new("UIStroke")
	s.Name = "Outline"
	s.Color = T.ink
	s.Thickness = thickness or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = l
	return l
end

-- faint checkerboard behind a panel's content (built once its size is known; rebuilt on resize)
local CHECK = 34
-- Built ONCE at a fixed size (w x h in GUI offset units) and clipped by the panel. It never
-- watches AbsoluteSize: that rebuilt on every resize, and a panel that kept growing (the table
-- panel on the live client) rebuilt it endlessly and froze the game.
local MAX_CHECK_CELLS = 400
local function checker(frame, w, h)
	local holder = Instance.new("Frame")
	holder.Name = "Checker"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ClipsDescendants = true
	holder.ZIndex = 0
	holder.Parent = frame
	local cols = math.ceil(math.clamp(w, CHECK, 1200) / CHECK)
	local rows = math.ceil(math.clamp(h, CHECK, 900) / CHECK)
	local made = 0
	for y = 0, rows - 1 do
		for x = y % 2, cols - 1, 2 do
			if made >= MAX_CHECK_CELLS then
				return holder
			end
			local sq = Instance.new("Frame")
			sq.BorderSizePixel = 0
			sq.BackgroundColor3 = T.white
			sq.BackgroundTransparency = 0.955
			sq.Size = UDim2.fromOffset(CHECK, CHECK)
			sq.Position = UDim2.fromOffset(x * CHECK, y * CHECK)
			sq.ZIndex = 0
			sq.Parent = holder
			made += 1
		end
	end
	return holder
end

-- quick "pop" when something appears: UIScale 0.85 -> 1, Back easing
local POP = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
-- (it pops to the card's "Fit" attribute: below 1 when the card is taller than a phone's screen)
local function popOnShow(holder)
	local sc = Instance.new("UIScale")
	sc.Name = "Pop"
	sc.Parent = holder
	holder:GetPropertyChangedSignal("Visible"):Connect(function()
		if holder.Visible then
			local fit = holder:GetAttribute("Fit") or 1
			sc.Scale = 0.85 * fit
			TweenService:Create(sc, POP, { Scale = fit }):Play()
		end
	end)
end

-- shrink a card (one made by card()) so it fits: fit = 1 is its normal size
local function setFit(holder, fit)
	holder:SetAttribute("Fit", fit)
	local sc = holder:FindFirstChild("Pop")
	if sc then
		sc.Scale = fit
	end
end

-- Screen size. Everything is laid out for 1280x720 and scaled down with a UIScale. A phone in
-- landscape (about 750x380, with a 58 px top bar) would shrink that to ~0.5: too small to read or
-- tap. Short screens are "compact": they get a bigger scale of their own, cards too tall for them
-- get a fit (setFit), and the seated HUD moves the player bars beside the board.
local function compact(v: Vector2): boolean
	return v.Y < 560
end
local function uiScale(v: Vector2): number
	if compact(v) then
		return math.clamp(math.min(v.Y / 430, v.X / 860), 0.6, 1)
	end
	return math.clamp(math.min(v.X / 1280, v.Y / 720), 0.55, 1.15)
end

-- The seated layout, shared by the HUD and the 2D board (inset = the top bar's height).
-- Wide: player bars above and below the board, buttons left, move list right.
-- Compact: the board takes the full height; buttons left, player bars right (both 176 wide).
-- strip: an Abilities game on a wide screen: the ability panel takes a strip along the bottom (your
-- player bar moves up above it) and the board shifts up by `shift` pixels to stay centred.
-- Returns { compact, scale, board = the board's side in pixels, shift }
local SIDE_W = 176
local STRIP_H = 64 + 10 -- the ability panel's cards plus a gap
local function seatLayout(v: Vector2, inset: number, strip: boolean?)
	local usable = v.Y - inset
	if compact(v) then
		local board = usable - 16
		local s = math.min(uiScale(v), (usable - 16) / 330) -- the button column fits the height
		s = math.min(s, (v.X - board - 4 * 14) / (2 * SIDE_W)) -- both columns fit beside the board
		if s < 0.6 then -- a very small screen: the board gives way, the columns stay usable
			s = 0.6
			board = v.X - 4 * 14 - 2 * SIDE_W * s
		end
		return { compact = true, scale = s, board = math.floor(math.max(board, 180)), shift = 0 }
	end
	local s = math.clamp(math.min(v.X / 1280, v.Y / 720), 0.55, 1.15)
	local side = math.max(176 + 14 + 12, 210 + 14 + 12) * s
	local extra = if strip then STRIP_H * s else 0
	local availH = usable - 2 * (58 + 14 + 12) * s - extra
	local availW = v.X - 2 * side
	return { compact = false, scale = s, board = math.floor(math.clamp(math.min(availH, availW), 200, 900)), shift = extra / 2 }
end
Ui.STRIP_H = STRIP_H

-- Dark green panel. Returns holder (place / show it) and body (put content in it; transparent, so
-- layouts in it don't see the background). The background is a sibling under the body: a deep
-- green gradient, the checkerboard and a thick ink outline, with a hard drop shadow.
local function card(parent, name, size, pos, anchor)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.Size = size
	holder.Position = pos
	holder.AnchorPoint = anchor or Vector2.zero
	holder.BackgroundTransparency = 1
	holder.Parent = parent
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.Position = UDim2.fromOffset(0, 6)
	shadow.BackgroundColor3 = T.shadow
	shadow.BackgroundTransparency = 0.6
	shadow.BorderSizePixel = 0
	shadow.Parent = holder
	corner(shadow, 16)
	local bg = Instance.new("Frame")
	bg.Name = "Bg"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = T.white
	bg.BorderSizePixel = 0
	bg.ClipsDescendants = true
	bg.Parent = holder
	corner(bg, 16)
	gradient(bg, T.panel, T.panelDeep)
	stroke(bg, T.ink, 4)
	-- the card's own offset size, or a generous default when it's sized by scale / not known yet
	checker(bg, if size.X.Offset > 0 then size.X.Offset else 600, if size.Y.Offset > 0 then size.Y.Offset else 700)
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.fromScale(1, 1)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Parent = holder
	corner(body, 16)
	popOnShow(holder)
	return holder, body
end

local function label(parent, name, text, size, pos, face, textSize, color, align)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = text
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.FontFace = face or BOLD
	l.TextSize = textSize or 18
	l.TextColor3 = color or T.text
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

-- a green title bar across the top of a panel, with chunky title text
local function header(body, text, height, textSize, iconArg)
	local head = label(body, "Title", text, UDim2.new(1, 0, 0, height or 54), UDim2.new(), TITLE, textSize or 28, T.white, Enum.TextXAlignment.Center)
	head.BackgroundColor3 = T.green
	head.BackgroundTransparency = 0
	corner(head, 16)
	highlight(head, 16)
	chunky(head, 3)
	local fix = Instance.new("Frame") -- squares off the bar's bottom corners
	fix.Name = "TitleFix"
	fix.Size = UDim2.new(1, 0, 0, 16)
	fix.Position = UDim2.new(0, 0, 0, (height or 54) - 16)
	fix.BackgroundColor3 = T.green
	fix.BorderSizePixel = 0
	fix.ZIndex = 0
	fix.Parent = body
	if iconArg then
		Ui.setText(head, text, iconArg)
	end
	return head
end

-- diagonal stripes over a button face: a white frame whose transparency is banded by a UIGradient
-- (hard stops). Part B swaps this for a tiled stripe image.
local STRIPES
do
	local kps = { NumberSequenceKeypoint.new(0, 0.88) }
	for k = 1, 9 do
		local t = k / 10
		local before = if k % 2 == 1 then 0.88 else 1
		local after = if k % 2 == 1 then 1 else 0.88
		table.insert(kps, NumberSequenceKeypoint.new(t - 0.002, before))
		table.insert(kps, NumberSequenceKeypoint.new(t, after))
	end
	table.insert(kps, NumberSequenceKeypoint.new(1, 1))
	STRIPES = NumberSequence.new(kps)
end
-- A rotated gradient only spans the frame's own box, so on a wide button its ends never reach the
-- corners (a flat tint on the left, nothing on the right). The stripes are drawn on a frame 1.4x the
-- button, centred, inside a plain frame that clips them to the button. (Not a CanvasGroup: under a
-- UIScale, as in Settings, Roblox drew those at the wrong place.)
local function stripes(face)
	local clip = Instance.new("Frame")
	clip.Name = "Stripes"
	clip.Size = UDim2.fromScale(1, 1)
	clip.BackgroundTransparency = 1
	clip.BorderSizePixel = 0
	clip.ClipsDescendants = true
	clip.Active = false
	clip.Parent = face
	local f = Instance.new("Frame")
	f.Name = "Bands"
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(1.4, 1.4)
	f.BackgroundColor3 = T.white
	f.BorderSizePixel = 0
	f.Active = false
	f.Parent = clip
	local g = Instance.new("UIGradient")
	g.Transparency = STRIPES
	g.Rotation = 30
	g.Parent = f
	return clip
end

-- chunky button: a darker "edge" frame (ink outline) with the gradient face 4px above it
-- styles: primary (green), secondary (dark green), danger / red (red), blue, gold, abilities,
-- locked (slate). Striped styles get the diagonal stripes.
local STYLES = {
	primary = { face = T.green, edge = T.greenEdge, stripes = true },
	secondary = { face = rgb(64, 110, 68), edge = rgb(34, 64, 38) },
	danger = { face = T.red, edge = T.redEdge, stripes = true },
	red = { face = T.red, edge = T.redEdge, stripes = true },
	blue = { face = T.blue, edge = rgb(30, 96, 150), stripes = true },
	gold = { face = T.gold, edge = rgb(184, 126, 20), stripes = true },
	abilities = { face = T.abilities, edge = rgb(104, 28, 96), stripes = true },
	locked = { face = T.locked, edge = rgb(40, 46, 56) },
}

-- Icons sit beside the text. Callers pass the emoji below (Ui.ICONS.x); when the Illustrator icon
-- of that name can be drawn (Icons.lua), an image replaces the emoji.
local ICONS = {
	bot = "🤖", pvp = "⚔️", tables = "🪑", stats = "🏆", settings = "⚙️", leave = "🚪",
	clock = "⏱️", Classic = "♟️", Abilities = "✨", ready = "✅", waiting = "⏳", draw = "🤝",
	resign = "🏳️", snipe = "🎯", cancel = "❌", yes = "✅", no = "❌", rematch = "🔁", review = "📊",
	view2D = "🔲", view3D = "🧊", tilt = "📐", moves = "📜", theme = "🎨", soundOn = "🔊",
	soundOff = "🔇", queen = "👑", copy = "📋", back = "↩️", best = "💡", key = "⭐", close = "✖",
	start = "▶️", white = "⚪", black = "⚫", random = "🎲", win = "🏆", lose = "😢", tie = "🤝",
	play = "▶️", lock = "🔒", fire = "🔥", new = "🌟", vip = "👑", user = "👤", save = "🔖",
	gamepad = "🎮", target = "🎯", coin = "🪙", shop = "🛒", steal = "🧲",
	-- bot levels, by name
	Beginner = "🐣", Casual = "🙂", Club = "😎", Strong = "💪",
}
-- emoji -> icon name (pairs that share an emoji share a picture too)
-- the Robux icon, shipped with every Roblox client (no upload); setText takes it like an emoji
local ROBUX = "rbxasset://textures/ui/common/robux@3x.png"
local ICON_NAME = {}
for name, emoji in ICONS do
	ICON_NAME[emoji] = ICON_NAME[emoji] or name
end
-- an icon argument (emoji or name) -> the icon name, if there's a picture for it
local function iconName(iconArg)
	if not iconArg or iconArg == "" then
		return nil
	end
	local name = if ICONS[iconArg] then iconArg else ICON_NAME[iconArg]
	return if Icons.has(name) then name else nil
end

local ICON_GAP = 11
-- how much the UIScales above a GUI object shrink it (TextBounds are in screen pixels, offsets aren't)
local function scaleOf(obj)
	local s = 1
	local p = obj
	while p and p:IsA("GuiBase2d") do
		for _, c in p:GetChildren() do
			if c:IsA("UIScale") then
				s *= c.Scale
			end
		end
		p = p.Parent
	end
	return if s > 0 then s else 1
end

-- keep an image icon just left of the (centred or left-aligned) text
local function placeIcon(face)
	local img = face:FindFirstChild("IconImg")
	if not img then
		return
	end
	if face.Text == "" then
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
	elseif face.TextXAlignment == Enum.TextXAlignment.Center then
		-- children sit in the padded area, so 0.5 is the text's centre
		img.AnchorPoint = Vector2.new(1, 0.5)
		img.Position = UDim2.new(0.5, -face.TextBounds.X / scaleOf(face) / 2 - ICON_GAP, 0.5, 0)
	else
		img.AnchorPoint = Vector2.new(1, 0.5)
		img.Position = UDim2.new(0, -ICON_GAP, 0.5, 0)
	end
end

-- set a button face's (or label's) text, keeping its icon in front (icon = nil keeps the current
-- one, "" removes it)
-- A face's UIPadding (room for an icon or a tick box) also shifts its overlay children, which left
-- a bare strip down the button's left side. Keep the shine and the stripes spanning the whole face.
local function fitOverlays(face)
	local pad = face:FindFirstChildOfClass("UIPadding")
	local l = if pad then pad.PaddingLeft.Offset else 0
	local r = if pad then pad.PaddingRight.Offset else 0
	local t = if pad then pad.PaddingTop.Offset else 0
	local b = if pad then pad.PaddingBottom.Offset else 0
	for _, name in { "Sheen", "Stripes" } do
		local o = face:FindFirstChild(name)
		if o then
			o.Position = UDim2.fromOffset(-l, -t)
			o.Size = UDim2.new(1, l + r, 1, t + b)
		end
	end
end
local function watchPad(face, pad)
	pad.Changed:Connect(function()
		fitOverlays(face)
	end)
	fitOverlays(face)
end

local function setText(face, text, iconArg)
	if iconArg ~= nil then
		face:SetAttribute("Icon", iconArg)
	end
	iconArg = face:GetAttribute("Icon")
	local name = iconName(iconArg)
	local path = if type(iconArg) == "string" and string.sub(iconArg, 1, 8) == "rbxasset" then iconArg else nil
	local img = face:FindFirstChild("IconImg")
	local pad = face:FindFirstChild("IconPad") or face:FindFirstChildOfClass("UIPadding")
	if name or path then
		local size = if face.TextScaled then 30 else math.floor(face.TextSize * 1.5)
		if not img then
			img = Instance.new("ImageLabel")
			img.Name = "IconImg"
			img.BackgroundTransparency = 1
			img.ZIndex = face.ZIndex
			img.Parent = face
			face:GetPropertyChangedSignal("TextBounds"):Connect(function()
				placeIcon(face)
			end)
		end
		img.Size = UDim2.fromOffset(size, size)
		if path then
			img.Image = path
			img.ImageRectOffset, img.ImageRectSize = Vector2.zero, Vector2.zero
		else
			Icons.set(img, name)
		end
		if not pad then
			pad = Instance.new("UIPadding")
			pad.Name = "IconPad"
			pad.Parent = face
			watchPad(face, pad)
		end
		if face:GetAttribute("IconPadBase") == nil then
			face:SetAttribute("IconPadBase", pad.PaddingLeft.Offset)
		end
		local base = face:GetAttribute("IconPadBase")
		pad.PaddingLeft = UDim.new(0, if text ~= "" then base + size + ICON_GAP else base)
		fitOverlays(face)
		face.Text = text
		placeIcon(face)
		return
	end
	if img then
		img:Destroy()
	end
	if face:GetAttribute("IconPadBase") ~= nil then
		if not pad then
			pad = Instance.new("UIPadding")
			pad.Name = "IconPad"
			pad.Parent = face
			watchPad(face, pad)
		end
		pad.PaddingLeft = UDim.new(0, face:GetAttribute("IconPadBase"))
		fitOverlays(face)
	end
	if iconArg and iconArg ~= "" then
		-- emoji fallback: the icon a size bigger than the text
		face.RichText = true
		local big = string.format('<font size="%d">%s</font>', math.floor(face.TextSize * 1.3), iconArg)
		face.Text = if text ~= "" then big .. "  " .. text else big
	else
		face.Text = text
	end
end

-- a standalone icon: an ImageLabel when the picture exists, else the emoji in a label
local function icon(parent, iconArg, size, pos, anchor)
	local name = iconName(iconArg)
	local l
	if name then
		l = Instance.new("ImageLabel")
		Icons.set(l, name)
	else
		l = Instance.new("TextLabel")
		l.Text = if ICONS[iconArg] then ICONS[iconArg] else (iconArg or "")
		l.TextScaled = true
		l.FontFace = HEAVY
		l.TextColor3 = T.white
	end
	l.Name = "IconImg"
	l.BackgroundTransparency = 1
	l.Size = if typeof(size) == "UDim2" then size else UDim2.fromOffset(size or 32, size or 32)
	l.Position = pos or UDim2.new()
	l.AnchorPoint = anchor or Vector2.zero
	l.Parent = parent
	return l
end

local PRESS = TweenInfo.new(0.08)
local function button(parent, name, text, size, style, onClick, icon)
	local s = STYLES[style or "primary"] or STYLES.primary
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.Size = size
	holder.BackgroundColor3 = s.edge
	holder.BorderSizePixel = 0
	holder.Parent = parent
	corner(holder, 12)
	stroke(holder, T.ink, 2.5)
	local sc = Instance.new("UIScale")
	sc.Parent = holder
	local b = Instance.new("TextButton")
	b.Name = "Face"
	b.Text = text
	b.Size = UDim2.new(1, 0, 1, -4)
	b.BackgroundColor3 = s.face
	b.TextColor3 = T.white
	b.TextSize = 19
	b.AutoButtonColor = true
	b.Selectable = true
	b.BorderSizePixel = 0
	b.Parent = holder
	corner(b, 12)
	highlight(b)
	chunky(b, 2)
	if s.stripes then
		stripes(b)
	end
	local function press(down)
		b.Position = if down then UDim2.fromOffset(0, 2) else UDim2.new()
		TweenService:Create(sc, PRESS, { Scale = if down then 0.96 else 1 }):Play()
	end
	b.MouseButton1Down:Connect(function()
		press(true)
	end)
	b.MouseButton1Up:Connect(function()
		press(false)
	end)
	b.MouseLeave:Connect(function()
		press(false)
	end)
	b.Activated:Connect(function()
		Sounds.play("click")
	end)
	b.Activated:Connect(onClick)
	setText(b, text, icon)
	-- the holder is what layouts place; callers use the face for text / selection
	return holder, b
end

-- recolour an existing button (e.g. a toggle that turns green when on)
local function restyle(face, style)
	local s = STYLES[style] or STYLES.primary
	face.Parent.BackgroundColor3 = s.edge
	face.BackgroundColor3 = s.face
	local st = face:FindFirstChild("Stripes")
	if s.stripes and not st then
		stripes(face)
		fitOverlays(face)
	elseif st and not s.stripes then
		st:Destroy()
	end
end

-- a checkbox: a dark button with a tick box on the left (green with a tick when on).
-- Returns holder, face, set(on). Clicking flips it and calls onToggle(on).
local function checkbox(parent, name, text, size, onToggle)
	local on = false
	local box, tick
	local function set(v)
		on = v == true
		box.BackgroundColor3 = if on then T.green else rgb(22, 40, 25)
		tick.Visible = on
	end
	local holder, face = button(parent, name, text, size, "secondary", function()
		set(not on)
		onToggle(on)
	end)
	local pad = Instance.new("UIPadding")
	pad.Name = "CheckPad"
	pad.PaddingLeft = UDim.new(0, 34)
	pad.Parent = face
	watchPad(face, pad)
	box = Instance.new("Frame")
	box.Name = "Check"
	box.AnchorPoint = Vector2.new(0, 0.5)
	box.Position = UDim2.new(0, 12, 0.5, -2)
	box.Size = UDim2.fromOffset(28, 28)
	box.BorderSizePixel = 0
	box.ZIndex = face.ZIndex + 2
	box.Active = false
	box.Parent = holder
	corner(box, 8)
	stroke(box, T.ink, 2.5)
	tick = Instance.new("ImageLabel")
	tick.Name = "Tick"
	tick.BackgroundTransparency = 1
	tick.AnchorPoint = Vector2.new(0.5, 0.5)
	tick.Position = UDim2.fromScale(0.5, 0.5)
	tick.Size = UDim2.fromScale(0.9, 0.9)
	tick.ZIndex = box.ZIndex + 1
	tick.Parent = box
	if Icons.has("yes") then
		Icons.set(tick, "yes")
	end
	set(false)
	return holder, face, set
end

-- square icon button with a short caption under the icon (side buttons, lobby bar)
local function tile(parent, name, icon, caption, size, style, onClick)
	local holder, b = button(parent, name, "", size, style, onClick)
	local ic = label(b, "Icon", "", UDim2.new(1, 0, 1, -22), UDim2.fromOffset(0, 2), HEAVY, 30, T.white, Enum.TextXAlignment.Center)
	ic.TextTruncate = Enum.TextTruncate.None
	local img = Instance.new("ImageLabel")
	img.Name = "TileImg"
	img.BackgroundTransparency = 1
	img.AnchorPoint = Vector2.new(0.5, 0)
	img.Size = UDim2.new(1, -12, 1, -26)
	img.Position = UDim2.new(0.5, 0, 0, 3)
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = b
	local cap = label(b, "Caption", caption, UDim2.new(1, -6, 0, 18), UDim2.new(0, 3, 1, -22), TITLE, 15, T.white, Enum.TextXAlignment.Center)
	chunky(cap, 1.5)
	Ui.setTile(b, icon, caption)
	return holder, b
end

local function setTile(face, iconArg, caption)
	local name = iconName(iconArg)
	face.TileImg.Visible = name ~= nil
	if name then
		Icons.set(face.TileImg, name)
	end
	face.Icon.Text = if name then "" else iconArg
	face.Caption.Text = caption
end

-- red square X over a panel's top-right corner, slightly tilted (closes it)
local function closeX(parent, onClick)
	local h, b = button(parent, "Close", "X", UDim2.fromOffset(48, 48), "red", onClick)
	h.AnchorPoint = Vector2.new(0.5, 0.5)
	h.Position = UDim2.new(1, -10, 0, 10)
	h.Rotation = 4
	h.ZIndex = 5
	b.ZIndex = 5
	b.TextSize = 30
	b.Outline.Thickness = 3
	return h, b
end

-- red number bubble on a button's corner (nil / 0 hides it)
local function badge(parent, n)
	local l = parent:FindFirstChild("Badge")
	if not l then
		l = label(parent, "Badge", "", UDim2.fromOffset(26, 26), UDim2.new(1, -14, 0, -10), TITLE, 16, T.white, Enum.TextXAlignment.Center)
		l.BackgroundColor3 = T.red
		l.BackgroundTransparency = 0
		l.ZIndex = 6
		corner(l, 13)
		stroke(l, T.ink, 2)
		chunky(l, 1.5)
	end
	l.Text = tostring(n or "")
	l.Visible = n ~= nil and n ~= 0
	return l
end

-- letter-spaced small caps for kickers and card labels ("C H O O S E")
local function spaced(text)
	local out = {}
	for _, c in utf8.codes(string.upper(text)) do
		table.insert(out, utf8.char(c))
	end
	return table.concat(out, " ")
end

local function list(parent, padding, horizontal)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding or 8)
	l.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
	return l
end

Ui.T, Ui.BOLD, Ui.HEAVY, Ui.MEDIUM, Ui.TITLE, Ui.DISPLAY, Ui.font = T, BOLD, HEAVY, MEDIUM, TITLE, DISPLAY, font
Ui.corner, Ui.stroke, Ui.card, Ui.label, Ui.button, Ui.list = corner, stroke, card, label, button, list
Ui.ICONS, Ui.setText, Ui.tile, Ui.setTile, Ui.closeX = ICONS, setText, tile, setTile, closeX
Ui.highlight, Ui.checkbox = highlight, checkbox
Ui.ROBUX, Ui.setFit, Ui.compact, Ui.uiScale, Ui.seatLayout = ROBUX, setFit, compact, uiScale, seatLayout
Ui.icon, Ui.iconName, Ui.Icons = icon, iconName, Icons
Ui.gradient, Ui.chunky, Ui.header, Ui.restyle, Ui.badge, Ui.spaced, Ui.STYLES, Ui.stripes, Ui.popOnShow, Ui.shade =
	gradient, chunky, header, restyle, badge, spaced, STYLES, stripes, popOnShow, shade

return Ui
