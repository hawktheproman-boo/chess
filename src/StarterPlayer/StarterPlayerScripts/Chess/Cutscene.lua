-- The ability cutscenes. Bishop Snipe has four shots (load, scope, fire, hit: see the Bishop Snipe
-- section below); the others are one shot each. The two players at the table get the camera moves
-- and the screen overlay; spectators nearby see the effects. Each fits in Settings.cutscene(id)
-- seconds (the server holds the opponent's clock that long).
--
--   Cutscene.snipe(view, from, dir, hits, { camera = bool, onHit = fn(sq), done = fn() })
--   Cutscene.ability(view, id, action, info, opts)   the other four (below)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Settings = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Settings"))
local CameraRig = require(script.Parent.CameraRig)
local Ui = require(script.Parent.UiKit)
local Sounds = require(script.Parent.Sounds)
local VfxKit = require(script.Parent.VfxKit)
local Music = require(script.Parent.Music)
local Pieces = require(script.Parent.Pieces)

local Cutscene = {}

local function fx(parent, shape, size, cf, color, transparency)
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency or 0
	p.Parent = parent
	return p
end

local function fadeAndDestroy(p, time)
	TweenService:Create(p, TweenInfo.new(time), { Transparency = 1 }):Play()
	task.delay(time + 0.05, function()
		p:Destroy()
	end)
end

-- The other abilities: Double Jump, Battering Ram, Royal Escape, Any Passant, Steal ----------------
-- Same frame as the snipe for the two players (letterbox bars, a big title, a camera move); just the
-- effects for spectators. Each fits in Settings.cutscene(id) (the opponent's clock waits that long).
-- The pieces are animated here; the client re-syncs the board when done() runs.
--   info: KnightJump -> squares it captures on; RookRam -> { path, hits, land };
--         KingEscape -> { captured square } or {}

local UP = Vector3.yAxis
local TITLES = {
	KnightJump = { "DOUBLE JUMP", Color3.fromRGB(90, 160, 255) },
	RookRam = { "BATTERING RAM", Color3.fromRGB(255, 140, 50) },
	KingEscape = { "ROYAL ESCAPE", Color3.fromRGB(255, 214, 102) },
	PawnPassant = { "ANY PASSANT", Color3.fromRGB(90, 230, 210) },
	StealPiece = { "STEAL!", Color3.fromRGB(255, 200, 61) },
}

-- letterbox bars and a chunky title in the top bar
local function banner(text, color)
	local gui = Instance.new("ScreenGui")
	gui.Name = "AbilityCutscene"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.DisplayOrder = 30
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local bars = {}
	for i, y in { 0, 1 } do
		local b = Instance.new("Frame")
		b.BackgroundColor3 = Color3.new(0, 0, 0)
		b.BorderSizePixel = 0
		b.AnchorPoint = Vector2.new(0, y)
		b.Size = UDim2.new(1, 0, 0, 0)
		b.Position = UDim2.fromScale(0, y)
		b.Parent = gui
		bars[i] = b
	end
	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 1) -- in the bottom bar (Roblox's own buttons sit over the top one)
	title.Position = UDim2.fromScale(0.5, 0.985)
	title.Size = UDim2.fromScale(0.8, 0.085)
	title.BackgroundTransparency = 1
	title.ZIndex = 3
	title.Text = text
	title.FontFace = Ui.TITLE
	title.TextScaled = true
	title.TextColor3 = color
	title.TextTransparency = 1
	title.Parent = gui
	local outline = Instance.new("UIStroke")
	outline.Color = Ui.T.ink
	outline.Thickness = 3
	outline.Transparency = 1
	outline.Parent = title
	local scale = Instance.new("UIScale")
	scale.Parent = title
	local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local function show(on)
		for _, b in bars do
			TweenService:Create(b, info, { Size = UDim2.new(1, 0, if on then 0.11 else 0, 0) }):Play()
		end
		TweenService:Create(title, info, { TextTransparency = if on then 0 else 1 }):Play()
		TweenService:Create(outline, info, { Transparency = if on then 0 else 1 }):Play()
		if on then
			scale.Scale = 1.4
			TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end
	return gui, show
end

-- run step(a) every frame for a = 0..1 over `duration` seconds (yields until it's done)
local function animate(duration, step)
	local t0 = os.clock()
	while true do
		local a = math.clamp((os.clock() - t0) / duration, 0, 1)
		step(a)
		if a >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
end

local function ease(a)
	return (1 - math.cos(a * math.pi)) / 2
end

local function partsOf(model)
	local base = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			base[p] = p.Transparency
		end
	end
	return base
end

local function fade(base, a)
	for part, t0 in base do
		part.Transparency = t0 + (1 - t0) * a
	end
end

-- a flat ring on the board that grows and fades (landings, arrivals)
local function ring(folder, pos, color, size)
	local disc = fx(folder, Enum.PartType.Cylinder, Vector3.new(0.06, 0.6, 0.6), CFrame.new(pos + UP * 0.08) * CFrame.Angles(0, 0, math.pi / 2), color, 0.2)
	TweenService:Create(disc, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.06, size, size) }):Play()
	fadeAndDestroy(disc, 0.45)
end

-- a quick bright ball (hits, sparks)
local function burst(folder, pos, color, size)
	local b = fx(folder, Enum.PartType.Ball, Vector3.one * 0.4, CFrame.new(pos), color, 0.1)
	TweenService:Create(b, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * size }):Play()
	fadeAndDestroy(b, 0.3)
end

local scenes = {}

-- Bishop Snipe ------------------------------------------------------------------------------------------
-- Four shots. Only the two seated players get the camera and the screen overlay; anyone nearby sees
-- the rest (the rifle, the shot, the bullet, the hits).
--   1 load  the bishop turns down the line, a sniper rifle drops into place, the bolt racks back and
--           a shell spins out onto the board
--   2 scope through the scope: it zooms in on the first piece in the line while the sway settles
--   3 fire  side-on: muzzle flash, a white impact frame, the rifle and the bishop kick back
--   4 hit   the camera rides beside the bullet; each target bursts into splinters; an enemy king in
--           the way sidesteps it like Sans (a grey afterimage stays, "MISS" pops up) and slides back
-- The whole thing fits in Settings.cutscene("BishopSnipe") (the opponent's clock is held that long).

local SNIPE = { load = 2.8, scope = 2.4, fire = 1.9 } -- scene lengths; the hit scene gets the rest
local SHOT_AT = SNIPE.load + SNIPE.scope + 0.5 -- the trigger pull (the riser is timed to end on it)
local RIFLE_SCALE = 0.8
local RED = Color3.fromRGB(235, 60, 60)
local BRASS = Color3.fromRGB(226, 182, 92)
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local WHITE_HOT = Color3.fromRGB(255, 236, 210)
local GOLD = Color3.fromRGB(255, 214, 110)
local TX = VfxKit.T
-- a ring standing up across the direction `dir` (the shockwave's normal is dir)
local function across(pos, dir)
	return CFrame.lookAt(pos, pos + dir) * CFrame.Angles(-math.pi / 2, 0, 0)
end

-- world direction of a 0x88 diagonal step (White sits at +Z: rank up = -Z)
local function worldDir(dir)
	local df = if dir == 17 or dir == -15 then 1 else -1
	local dr = if dir == 17 or dir == 15 then 1 else -1
	return Vector3.new(df, 0, -dr).Unit
end

-- the screen overlay: letterbox bars, the title, the scope view and a white impact frame
local function snipeGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SnipeCutscene"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None -- edge to edge: the impact frames must fill the screen
	gui.DisplayOrder = 30
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local function frame(parent, size, pos, color, transparency)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = size
		f.Position = pos
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transparency
		f.BorderSizePixel = 0
		f.Parent = parent
		return f
	end
	local function round(f)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = f
	end

	-- scope: a round window; a huge dark stroke blacks out everything around it
	local scope = frame(gui, UDim2.fromScale(0.86, 0.86), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(120, 160, 120), 0.94)
	scope.Visible = false
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.DominantAxis = Enum.DominantAxis.Height
	ratio.Parent = scope
	round(scope)
	local dark = Instance.new("UIStroke")
	dark.Thickness = 3000
	dark.Color = Color3.fromRGB(4, 6, 4)
	dark.Parent = scope
	local rim = frame(scope, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), Color3.new(), 1)
	round(rim)
	local rimStroke = Instance.new("UIStroke")
	rimStroke.Thickness = 10
	rimStroke.Color = Color3.fromRGB(14, 14, 16)
	rimStroke.Parent = rim
	local ink = Color3.fromRGB(10, 10, 10)
	-- crosshair: thin lines with a gap in the middle, thick posts at the edges, mil dots
	for _, axis in { Vector2.new(1, 0), Vector2.new(0, 1) } do
		for _, s in { -1, 1 } do
			local function bar(from, to, px)
				local mid = (from + to) / 2
				local len = to - from
				frame(scope, if axis.X == 1 then UDim2.new(len, 0, 0, px) else UDim2.new(0, px, len, 0),
					UDim2.fromScale(0.5 + axis.X * s * mid, 0.5 + axis.Y * s * mid), ink, 0)
			end
			bar(0.035, 0.32, 2)
			bar(0.32, 0.5, 7)
			for _, m in { 0.08, 0.13, 0.18, 0.23, 0.28 } do
				local dot = frame(scope, UDim2.fromOffset(6, 6), UDim2.fromScale(0.5 + axis.X * s * m, 0.5 + axis.Y * s * m), ink, 0)
				round(dot)
			end
		end
	end
	local dot = frame(scope, UDim2.fromOffset(9, 9), UDim2.fromScale(0.5, 0.5), RED, 0)
	round(dot)
	local zoom = Instance.new("TextLabel")
	zoom.AnchorPoint = Vector2.new(0.5, 0.5)
	zoom.Position = UDim2.fromScale(0.5, 0.82)
	zoom.Size = UDim2.fromScale(0.2, 0.045)
	zoom.BackgroundTransparency = 1
	zoom.FontFace = Ui.HEAVY
	zoom.TextScaled = true
	zoom.TextColor3 = RED
	zoom.Text = "x1.0"
	zoom.Parent = scope
	local lock = Instance.new("ImageLabel")
	lock.AnchorPoint = Vector2.new(0.5, 0.5)
	lock.Position = UDim2.fromScale(0.5, 0.5)
	lock.Size = UDim2.fromScale(0.95, 0.95)
	lock.BackgroundTransparency = 1
	lock.Image = VfxKit.T.ring
	lock.ImageColor3 = RED
	lock.ImageTransparency = 1
	lock.Parent = scope

	local bars = {}
	for i, y in { 0, 1 } do
		local b = Instance.new("Frame")
		b.BackgroundColor3 = Color3.new(0, 0, 0)
		b.BorderSizePixel = 0
		b.AnchorPoint = Vector2.new(0, y)
		b.Size = UDim2.new(1, 0, 0, 0)
		b.Position = UDim2.fromScale(0, y)
		b.ZIndex = 2
		b.Parent = gui
		bars[i] = b
	end
	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 1) -- in the bottom bar (Roblox's own buttons sit over the top one)
	title.Position = UDim2.fromScale(0.5, 0.985)
	title.Size = UDim2.fromScale(0.8, 0.085)
	title.BackgroundTransparency = 1
	title.Text = "BISHOP SNIPE"
	title.FontFace = Ui.TITLE
	title.TextScaled = true
	title.TextColor3 = RED
	title.TextTransparency = 1
	title.ZIndex = 3
	title.Parent = gui
	local outline = Instance.new("UIStroke")
	outline.Color = Ui.T.ink
	outline.Thickness = 3
	outline.Transparency = 1
	outline.Parent = title
	local titleScale = Instance.new("UIScale")
	titleScale.Parent = title
	local flash = frame(gui, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), Color3.new(1, 1, 1), 1)
	flash.ZIndex = 5

	local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local o = { gui = gui }
	function o.show(on)
		for _, b in bars do
			TweenService:Create(b, info, { Size = UDim2.new(1, 0, if on then 0.11 else 0, 0) }):Play()
		end
		TweenService:Create(title, info, { TextTransparency = if on then 0 else 1 }):Play()
		TweenService:Create(outline, info, { Transparency = if on then 0 else 1 }):Play()
		if on then
			titleScale.Scale = 1.4
			TweenService:Create(titleScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end
	function o.scope(on)
		scope.Visible = on
	end
	-- the lock-on ring closes in on the crosshair over `time`, then pings
	function o.lock(time)
		lock.Size = UDim2.fromScale(0.95, 0.95)
		lock.Rotation = 0
		lock.ImageTransparency = 0.15
		TweenService:Create(lock, TweenInfo.new(time, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{ Size = UDim2.fromScale(0.2, 0.2), Rotation = 200 }):Play()
		task.delay(time, function()
			if lock.Parent then
				lock.ImageColor3 = Color3.new(1, 1, 1)
				TweenService:Create(lock, TweenInfo.new(0.25), { Size = UDim2.fromScale(0.34, 0.34), ImageTransparency = 1 }):Play()
			end
		end)
	end
	function o.zoom(x)
		zoom.Text = string.format("x%.1f", x)
	end
	function o.flash(strength)
		flash.BackgroundTransparency = 1 - (strength or 1)
		TweenService:Create(flash, TweenInfo.new(0.16), { BackgroundTransparency = 1 }):Play()
	end
	return o
end

-- the rifle: ReplicatedStorage.CutsceneProps.Sniper (builders/cutscene_props.lua), or a plain stand-in
local function makeRifle(parent)
	local props = ReplicatedStorage:FindFirstChild("CutsceneProps")
	local src = props and props:FindFirstChild("Sniper")
	local m
	if src then
		m = src:Clone()
	else
		m = Instance.new("Model")
		local function part(name, size, offset, color)
			local p = Instance.new("Part")
			p.Name = name
			p.Size = size
			p.CFrame = CFrame.new(offset)
			p.Color = color
			p.Parent = m
			return p
		end
		m.PrimaryPart = part("Root", Vector3.one * 0.1, Vector3.zero, Color3.new())
		m.PrimaryPart.Transparency = 1
		part("Stock", Vector3.new(0.13, 0.3, 1.4), Vector3.new(0, -0.12, 0.3), Color3.fromRGB(122, 72, 40))
		part("Metal", Vector3.new(0.1, 0.1, 2.2), Vector3.new(0, 0, -0.6), Color3.fromRGB(40, 41, 46))
		part("Lens", Vector3.new(0.12, 0.12, 0.8), Vector3.new(0, 0.17, 0.05), Color3.fromRGB(40, 41, 46))
		part("Bolt", Vector3.new(0.16, 0.06, 0.06), Vector3.new(-0.12, 0, 0.22), Color3.fromRGB(170, 170, 176))
		for _, p in m:GetChildren() do
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		end
	end
	m:ScaleTo(RIFLE_SCALE)
	m.Parent = parent
	return m
end

-- a few bright particles from one point (smoke puffs, sparks)
local function puff(folder, pos, n, color, size, speed, life)
	local a = Instance.new("Part")
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch = true, false, false, false
	a.Transparency = 1
	a.Size = Vector3.one * 0.1
	a.CFrame = CFrame.new(pos)
	a.Parent = folder
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.3), NumberSequenceKeypoint.new(1, size) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Speed = NumberRange.new(speed * 0.4, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(life * 0.6, life)
	e.Drag = 3
	e.Rate = 0
	e.Parent = a
	e:Emit(n)
	task.delay(life + 0.2, function()
		a:Destroy()
	end)
end

-- small pieces flung out that fall with gravity and fade (splinters, sparks)
local function debris(folder, pos, n, color, size, speed, neon, avoid: Vector3?)
	for _ = 1, n do
		local p = fx(folder, Enum.PartType.Block, size, CFrame.new(pos), color, 0)
		p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		local v = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit * speed * (0.6 + math.random() * 0.6)
		if avoid and v:Dot(avoid) > 0 then
			v -= avoid * v:Dot(avoid) * 2 -- (never towards the camera)
		end
		local spin = CFrame.Angles(math.random() * 0.4, math.random() * 0.4, math.random() * 0.4)
		task.spawn(function()
			local life = if neon then 0.3 else 0.7
			local t0 = os.clock()
			local last = t0
			while p.Parent do
				local now = os.clock()
				local dt = now - last
				last = now
				local a = (now - t0) / life
				if a >= 1 then
					break
				end
				v += Vector3.new(0, -30 * dt, 0)
				local at = p.Position + v * dt
				p.CFrame = if neon then CFrame.lookAt(at, at + v) else (p.CFrame * spin) - p.Position + at
				p.Transparency = a * a
				RunService.RenderStepped:Wait()
			end
			p:Destroy()
		end)
	end
end

-- hide a model for this player only (the camera sits inside or behind it)
local function hideLocal(model, on)
	if model then
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") or p:IsA("Decal") then
				p.LocalTransparencyModifier = if on then 1 else 0
			end
		end
	end
end

local function firstColor(model)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Transparency < 1 then
			return p.Color
		end
	end
	return Color3.fromRGB(200, 200, 200)
end

function Cutscene.snipe(view, from: number, dir: number, hits, opts)
	opts = opts or {}
	local started = os.clock()
	local total = Settings.cutscene("BishopSnipe")
	local folder = Instance.new("Folder")
	folder.Name = "SnipeFx"
	folder.Parent = view.folder
	local base = view:squareCFrame(from).Position
	local d = worldDir(dir)
	local side = d:Cross(UP).Unit -- the bishop's right, looking down the line
	local bishop = view:modelAt(from)
	local me = if bishop then bishop.color else nil
	local cam = opts.camera
	if cam then
		Music.duck(true) -- (back up once the scene's length has passed, even if it ends early)
		task.delay(total + 0.3, Music.duck, false)
	end
	local ui = if cam then snipeGui() else nil
	local function sound(name, pos, o)
		return Sounds.play(name, if cam then nil else pos, o)
	end
	-- every piece and the rifle, for the impact frames' silhouettes
	local function silhouettes(rifleModel)
		local list = { rifleModel }
		for _, e in view.models do
			table.insert(list, e.model)
		end
		return list
	end

	-- the line: the targets (from `hits`) and any enemy king between them, nearest first
	local isHit = {}
	for _, sq in hits do
		isHit[sq] = true
	end
	local line = {}
	local remaining = #hits
	local sq = from + dir
	while remaining > 0 and bit32.band(sq, 0x88) == 0 do
		local e = view:modelAt(sq)
		if isHit[sq] then
			table.insert(line, { sq = sq, kind = "hit", e = e })
			remaining -= 1
		elseif e and e.type == "k" and e.color ~= me then
			table.insert(line, { sq = sq, kind = "king", e = e })
		end
		sq += dir
	end
	local firstAim = if #line > 0 then view:squareCFrame(line[1].sq).Position + UP * 0.9 else base + d * view.size * 3 + UP * 0.9

	-- 1 LOAD ---------------------------------------------------------------------------------------
	local avatar = if cam then Players.LocalPlayer.Character else nil
	if ui then
		ui.show(true)
		hideLocal(avatar, true) -- the low shots look back over the player's own seat
		VfxKit.bloom(true)
	end
	local unAura = if bishop then VfxKit.aura(bishop.model, RED) else function() end
	sound("braam", base, { fadeAfter = 2.4, fadeTime = 0.6 })
	task.delay(SHOT_AT - 4.0, function()
		if folder.Parent then
			sound("riser", base) -- 4 s, cut dead on the shot
		end
	end)
	local stopCharge = VfxKit.charge(folder, base + UP * 1.2, RED, 1.6)
	local aim = CFrame.lookAt(base, base + d) -- facing down the line (-Z forward)
	local rest = bishop and bishop.model:GetPivot()
	local hold = aim * CFrame.new(-0.3, 1.2, -0.3) -- the rifle at the bishop's left, at chest height
	local rifle = makeRifle(folder)
	local root = rifle.PrimaryPart
	local bolt = rifle:FindFirstChild("Bolt")
	local boltRel = if bolt then root.CFrame:ToObjectSpace(bolt.CFrame) else nil
	local slide, kick = 0, CFrame.new()
	local rifleCf = hold + UP * 3
	local function place()
		rifle:PivotTo(rifleCf * kick)
		if bolt then
			bolt.CFrame = root.CFrame * CFrame.new(0, 0, slide * RIFLE_SCALE) * boltRel
		end
	end
	place()
	local function muzzle()
		return (rifleCf * kick * CFrame.new(0, 0, -1.72 * RIFLE_SCALE)).Position
	end

	if cam then
		-- low, at the bishop's left front, slowly pushing in
		local focus = base + UP * 1.1
		CameraRig.override(CFrame.lookAt(base - side * 3.4 + d * 1.8 + UP * 1.4, focus), 52)
		task.delay(0.05, function()
			CameraRig.override(CFrame.lookAt(base - side * 2.5 + d * 1.0 + UP * 1.6, focus + d * 0.3), 46, 1.6)
		end)
	end
	-- the bishop turns down the line while the rifle drops in
	task.spawn(function()
		animate(0.45, function(a)
			local k = ease(a)
			if bishop and bishop.model.Parent and rest then
				bishop.model:PivotTo(rest:Lerp(aim, k))
			end
		end)
	end)
	task.wait(0.55)
	animate(0.35, function(a)
		rifleCf = hold + UP * 3 * (1 - a) ^ 2
		place()
	end)
	-- the rifle lands: the charge releases in a ring on the board, a star and sparks
	stopCharge()
	VfxKit.shockwave(folder, CFrame.new(base + UP * 0.06), RED, view.size * 2.8, 0.45)
	VfxKit.flare(folder, hold.Position, TX.star, WHITE_HOT, 0.5, 3, 0.3, 40)
	VfxKit.sparks(folder, CFrame.lookAt(hold.Position, hold.Position + UP), RED, 22, 11, 70)
	local unRifleAura = VfxKit.aura(rifle, RED)
	sound("boltClose", hold.Position)
	sound("impactBoom", hold.Position, { volume = 0.45 })
	if cam then
		CameraRig.shake(0.2, 0.2)
	end
	task.wait(0.45)
	-- rack the bolt (a close-up on it): back, a shell spins out, then forward
	if cam then
		local boltAt = (rifleCf * CFrame.new(-0.05, 0.02, 0.18)).Position
		CameraRig.override(CFrame.lookAt((rifleCf * CFrame.new(-1.1, 0.35, -0.25)).Position, boltAt), 40)
	end
	task.wait(0.15)
	sound("boltOpen", hold.Position)
	animate(0.22, function(a)
		slide = 0.22 * ease(a)
		place()
	end)
	do
		local port = (rifleCf * CFrame.new(-0.08, 0.05, 0.1 * RIFLE_SCALE)).Position
		local shell = fx(folder, Enum.PartType.Cylinder, Vector3.new(0.14, 0.05, 0.05), CFrame.new(port), BRASS, 0)
		shell.Material = Enum.Material.Metal
		VfxKit.sparks(folder, CFrame.lookAt(port, port - side + UP * 0.5), GOLD, 8, 6, 35)
		task.spawn(function()
			local v = -side * 2.6 + UP * 4 + d * 0.4
			local floorY = view.topY + 0.025
			local t0, last = os.clock(), os.clock()
			local bounced = false
			while shell.Parent and os.clock() - t0 < 0.9 do
				local now = os.clock()
				local dt = now - last
				last = now
				v += Vector3.new(0, -24 * dt, 0)
				local at = shell.Position + v * dt
				if at.Y < floorY then
					at = Vector3.new(at.X, floorY, at.Z)
					v = Vector3.new(v.X * 0.4, -v.Y * 0.3, v.Z * 0.4)
					if not bounced then
						bounced = true
						sound("shellDrop", at)
					end
				end
				shell.CFrame = CFrame.new(at) * CFrame.Angles(0, (now - t0) * 14, (now - t0) * 20)
				RunService.RenderStepped:Wait()
			end
			fadeAndDestroy(shell, 0.3)
		end)
	end
	task.wait(0.3)
	sound("boltClose", hold.Position)
	animate(0.16, function(a)
		slide = 0.22 * (1 - ease(a))
		place()
	end)
	if cam then
		CameraRig.shake(0.06, 0.08)
		task.wait(0.15)
		-- back out to the bishop as it settles into the aim
		CameraRig.override(CFrame.lookAt(base - side * 2.2 - d * 0.9 + UP * 1.9, base + d * 3 + UP * 1.0), 48, 0.6)
	end
	-- settle into the aim: the bishop leans into the stock
	local lean = aim * CFrame.Angles(math.rad(-6), 0, 0)
	animate(0.5, function(a)
		local k = ease(a)
		if bishop and bishop.model.Parent then
			bishop.model:PivotTo(aim:Lerp(lean, k))
		end
		rifleCf = hold:Lerp(CFrame.lookAt(hold.Position, firstAim), k * 0.6)
		place()
	end)
	local loadEnd = started + SNIPE.load
	if os.clock() < loadEnd then
		task.wait(loadEnd - os.clock())
	end

	-- 2 SCOPE --------------------------------------------------------------------------------------
	if not cam then -- (the seated players get the ring inside the scope instead)
		VfxKit.flare(folder, firstAim, TX.ring, RED, 2.6, 1.2, SNIPE.scope, 220)
	end
	VfxKit.flare(folder, (rifleCf * CFrame.new(0, 0.17 * RIFLE_SCALE, -0.4 * RIFLE_SCALE)).Position, TX.star, WHITE_HOT, 0.3, 1.2, SNIPE.scope, 90)
	task.delay(SNIPE.scope - 0.15, function()
		if folder.Parent then -- locked: a ping on the target
			VfxKit.flare(folder, firstAim, TX.star, RED, 0.4, 2.2, 0.25, 45)
		end
	end)
	if cam then
		ui.scope(true)
		ui.lock(SNIPE.scope * 0.75)
		sound("scopeZoom")
		local beat = sound("heartbeat")
		task.delay(SNIPE.scope - 0.3, Sounds.fade, beat, 0.3)
		-- the rifle and the bishop's head would block the view from the eyepiece: hide them for this shot
		hideLocal(rifle, true)
		hideLocal(bishop and bishop.model, true)
		local eye = (rifleCf * CFrame.new(0, 0.17 * RIFLE_SCALE, 0.6 * RIFLE_SCALE)).Position
		local dist = (firstAim - eye).Magnitude
		local wide, tight = 44, math.clamp(math.deg(2 * math.atan(1.1 / dist)), 7, 26)
		local t0 = os.clock()
		animate(SNIPE.scope - 0.1, function(a)
			local k = ease(math.min(a / 0.7, 1))
			local fov = wide + (tight - wide) * k
			local t = os.clock() - t0
			local sway = (1 - math.min(a / 0.85, 1)) * 0.06 * dist / 6
			local look = firstAim + side * math.sin(t * 3.1) * sway + UP * math.cos(t * 2.3) * sway * 0.7
			CameraRig.override(CFrame.lookAt(eye, look), fov)
			ui.zoom(math.tan(math.rad(wide / 2)) / math.tan(math.rad(fov / 2)))
		end)
		ui.scope(false)
		hideLocal(rifle, false)
		hideLocal(bishop and bishop.model, false)
	else
		task.wait(SNIPE.scope)
	end

	-- 3 FIRE ---------------------------------------------------------------------------------------
	local aimed = rifleCf
	if cam then
		-- side-on at the rifle's left, looking along it towards the muzzle
		local at = (aimed * CFrame.new(-1.9, 0.45, -0.9)).Position
		CameraRig.override(CFrame.lookAt(at, (aimed * CFrame.new(0, 0.05, -0.45)).Position), 50)
	end
	local stopMuzzle = VfxKit.charge(folder, muzzle(), RED, 0.7)
	local shotAt = started + SHOT_AT
	if os.clock() < shotAt then
		task.wait(shotAt - os.clock()) -- a held breath (the riser cuts to silence here)
	end
	stopMuzzle()
	local m0 = muzzle()
	sound("sniperShot", m0)
	sound("trailerHit", m0)
	local hitstop = 0.1
	if ui then
		hitstop = VfxKit.impactFrames(ui.gui, silhouettes(rifle), { "white", "invert", "manga", "invert", "red" }, 0.06)
		task.delay(hitstop, VfxKit.speedLines, ui.gui, 0.5, Color3.new(1, 1, 1))
	end
	if cam then
		CameraRig.shake(0.45, 0.35)
	end
	VfxKit.flare(folder, m0, TX.star, WHITE_HOT, 0.6, 4.2, 0.2, 30)
	VfxKit.flare(folder, m0, TX.glow, RED, 1, 3.2, 0.3)
	VfxKit.shockwave(folder, across(m0, d), WHITE_HOT, 2.6, 0.35)
	task.delay(0.04, VfxKit.shockwave, folder, across(m0 + d * 0.7, d), RED, 1.8, 0.3)
	VfxKit.sparks(folder, CFrame.lookAt(m0, m0 + d), Color3.fromRGB(255, 190, 110), 30, 24, 22)
	-- muzzle flash: a hot core, a star and the brake's side blasts, a light and smoke
	local core = fx(folder, Enum.PartType.Ball, Vector3.one * 0.35, CFrame.new(m0), Color3.fromRGB(255, 246, 200), 0)
	TweenService:Create(core, TweenInfo.new(0.1), { Size = Vector3.one * 1.1 }):Play()
	fadeAndDestroy(core, 0.12)
	local dirCf = CFrame.lookAt(m0, m0 + d)
	local spike = fx(folder, Enum.PartType.Block, Vector3.new(0.12, 0.12, 1.4), dirCf * CFrame.new(0, 0, -0.6), Color3.fromRGB(255, 200, 90), 0)
	fadeAndDestroy(spike, 0.1)
	local blast = fx(folder, Enum.PartType.Block, Vector3.new(1.2, 0.1, 0.1), dirCf, Color3.fromRGB(255, 160, 60), 0)
	fadeAndDestroy(blast, 0.1)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 140)
	light.Brightness = 8
	light.Range = 14
	light.Parent = core
	puff(folder, m0, 14, Color3.fromRGB(200, 200, 200), 1.2, 3, 0.9)
	-- recoil: the rifle jumps back and its muzzle climbs, then settles; the bishop rocks back
	task.spawn(function()
		task.wait(hitstop) -- hitstop on the impact frames
		sound("slowWhoosh", m0)
		animate(0.06, function(a)
			kick = CFrame.new(0, 0, 0.32 * a) * CFrame.Angles(math.rad(11) * a, 0, 0)
			place()
			if bishop and bishop.model.Parent then
				bishop.model:PivotTo(lean * CFrame.Angles(math.rad(12) * a, 0, 0))
			end
		end)
		animate(0.7, function(a)
			local k = 1 - ease(a)
			kick = CFrame.new(0, 0, 0.32 * k) * CFrame.Angles(math.rad(11) * k, 0, 0)
			place()
			if bishop and bishop.model.Parent then
				bishop.model:PivotTo(lean * CFrame.Angles(math.rad(12) * k, 0, 0))
			end
		end)
	end)
	local fireEnd = started + SNIPE.load + SNIPE.scope + SNIPE.fire
	if os.clock() < fireEnd then
		task.wait(fireEnd - os.clock())
	end

	-- 4 HIT ----------------------------------------------------------------------------------------
	-- the bullet's path, all straight lines through each target at its middle. An enemy king in the way
	-- isn't hit: it sidesteps just before the bullet arrives, and the bullet flies on through its afterimage.
	local function heightOf(e, default)
		if e and e.model.Parent then
			return e.model:GetExtentsSize().Y
		end
		return default
	end
	local legs = {} -- { a, b, event }
	local at = m0
	for _, t in line do
		local c = view:squareCFrame(t.sq).Position
		local b
		if t.kind == "hit" then
			b = c + UP * math.clamp(heightOf(t.e, 1.6) * 0.5, 0.55, 1.05)
		else
			b = c + UP * math.clamp(at.Y - c.Y, 0.55, 1.05) -- straight on, at the bullet's height
		end
		table.insert(legs, { a = at, b = b, event = t })
		at = b
	end
	local exit = (legs[#legs] and (legs[#legs].b - legs[#legs].a).Unit) or d
	table.insert(legs, { a = at, b = at + exit * 1.2 })
	local length = 0
	for _, l in legs do
		l.len = (l.b - l.a).Magnitude
		length += l.len
	end
	local speed = math.max(length / 1.9, 4) -- slow motion: about 2 s down the line

	local bullet = fx(folder, Enum.PartType.Block, Vector3.new(0.07, 0.07, 0.26), CFrame.lookAt(m0, m0 + d), BRASS, 0)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.035, 0), Vector3.new(0, -0.035, 0)
	a0.Parent, a1.Parent = bullet, bullet
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.3
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 240, 200), RED)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.WidthScale = NumberSequence.new(2.5, 0.5)
	trail.Parent = bullet
	local glowGui = Instance.new("BillboardGui")
	glowGui.Size = UDim2.fromScale(0.9, 0.9)
	glowGui.LightInfluence = 0
	glowGui.Brightness = 3
	glowGui.Parent = bullet
	local glowImg = Instance.new("ImageLabel")
	glowImg.BackgroundTransparency = 1
	glowImg.Size = UDim2.fromScale(1, 1)
	glowImg.Image = TX.glow
	glowImg.ImageColor3 = RED
	glowImg.Parent = glowGui
	local rails = {} -- the energy line left behind the bullet, one straight piece per leg
	local firstHit = true

	-- the king's sidestep (Sans in Undertale): it snaps a square's width off the line, a grey
	-- afterimage stays behind and fades, "MISS" pops up over it; it slides back once the bullet is past
	local function dodge(k)
		if not (k and k.model.Parent) then
			return
		end
		local kr = k.model:GetPivot()
		local ghost = k.model:Clone()
		for _, p in ghost:GetDescendants() do
			if p:IsA("BasePart") then
				p.Color = Color3.fromRGB(150, 150, 155)
				p.Material = Enum.Material.SmoothPlastic
				p.Transparency = 0.4
				p.CastShadow = false
			end
		end
		ghost.Parent = folder
		task.spawn(function()
			task.wait(0.35)
			local parts = partsOf(ghost)
			animate(0.6, function(a)
				fade(parts, a)
			end)
			ghost:Destroy()
		end)
		sound("dodge", kr.Position)
		local away = kr - side * view.size * 0.8
		local h = heightOf(k, 2.2)
		animate(0.1, function(a)
			k.model:PivotTo(kr:Lerp(away, ease(a)))
		end)
		-- MISS
		local tag = Instance.new("Part")
		tag.Anchored, tag.CanCollide, tag.CanQuery, tag.CanTouch = true, false, false, false
		tag.Transparency = 1
		tag.Size = Vector3.one * 0.1
		tag.CFrame = CFrame.new(away.Position + UP * (h * 0.85) + side * 0.3) -- by its head, in the low bullet-cam shot
		tag.Parent = folder
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromScale(2.6, 0.9)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.Parent = tag
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Arcade
		label.Text = "MISS"
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(210, 210, 210)
		label.Parent = bb
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Thickness = 3
		stroke.Parent = label
		local pop = Instance.new("UIScale")
		pop.Scale = 1.6
		pop.Parent = label
		TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(tag, TweenInfo.new(1.6, Enum.EasingStyle.Sine), { CFrame = tag.CFrame + UP * 0.4 }):Play()
		task.delay(1.3, function()
			if label.Parent then
				TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
				TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
		end)
		-- back to its square once the bullet is through
		task.delay(0.9, function()
			if k.model.Parent then
				local from0 = k.model:GetPivot()
				animate(0.35, function(a)
					k.model:PivotTo(from0:Lerp(kr, ease(a)))
				end)
			end
		end)
	end

	local function track(pos, heading)
		if cam then
			CameraRig.override(CFrame.lookAt(pos + side * 2.3 + UP * 0.6 - heading * 1.3, pos + heading * 1.4), 55)
		end
	end
	local lastRipple = 0
	local lastHit = nil
	for _, t in line do
		if t.kind == "hit" then
			lastHit = t
		end
	end
	for _, l in legs do
		local dur = l.len / speed
		local heading = (l.b - l.a).Unit
		local rail = VfxKit.beam(folder, l.a, l.a, RED, 0.22)
		table.insert(rails, rail)
		local dodged = false
		animate(dur, function(a)
			local pos = l.a:Lerp(l.b, a)
			local face = heading
			bullet.CFrame = CFrame.lookAt(pos, pos + face)
			rail:set(l.a, pos)
			-- the king sees it coming: it moves when the bullet is about a square away
			if not dodged and l.event and l.event.kind == "king" and (l.b - pos).Magnitude < view.size * 1.1 then
				dodged = true
				task.spawn(dodge, l.event.e)
			end
			track(pos, heading)
			-- bullet-time air ripples
			if os.clock() - lastRipple > 0.09 then
				lastRipple = os.clock()
				local r = fx(folder, Enum.PartType.Cylinder, Vector3.new(0.03, 0.2, 0.2), CFrame.lookAt(pos, pos + face) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(255, 255, 255), 0.75)
				TweenService:Create(r, TweenInfo.new(0.3), { Size = Vector3.new(0.03, 0.7, 0.7) }):Play()
				fadeAndDestroy(r, 0.3)
			end
		end)
		local t = l.event
		if t and t.kind == "hit" then
			local pos = l.b
			local color = if t.e and t.e.model.Parent then firstColor(t.e.model) else Color3.fromRGB(200, 200, 200)
			local floor = view:squareCFrame(t.sq).Position
			local big = firstHit or t == lastHit
			firstHit = false
			VfxKit.flare(folder, pos, TX.star, WHITE_HOT, 0.5, 3.4, 0.22, 35)
			VfxKit.flare(folder, pos, TX.glow, RED, 1, 2.8, 0.3)
			VfxKit.shockwave(folder, CFrame.new(floor + UP * 0.06), RED, view.size * 2.4, 0.4)
			task.delay(0.05, VfxKit.shockwave, folder, CFrame.new(floor + UP * 0.07), WHITE_HOT, view.size * 1.5, 0.3)
			VfxKit.shockwave(folder, across(pos, heading), WHITE_HOT, 1.8, 0.25)
			VfxKit.sparks(folder, CFrame.lookAt(pos, pos + heading), RED, 26, 16, 60)
			VfxKit.decal(folder, CFrame.new(floor + UP * 0.03) * CFrame.Angles(0, math.random() * math.pi * 2, 0), TX.crack,
				Color3.fromRGB(40, 24, 24), view.size * 1.1, 1.6)
			debris(folder, pos, 10, color, Vector3.new(0.12, 0.12, 0.12), 9, false, side)
			puff(folder, pos, 6, Color3.fromRGB(220, 210, 190), 1, 2, 0.7)
			sound("bulletHit", pos)
			sound("woodBreak", pos)
			if big then
				sound(if t == lastHit then "lowBoom" else "impactBoom", pos)
			end
			if opts.onHit then
				opts.onHit(t.sq)
			end
			if cam then
				CameraRig.shake(if big then 0.45 else 0.3, 0.25)
			end
			-- hitstop, with impact frames: a full burst on the first and last hits, a flick on the rest
			local hold2 = 0.12
			if ui then
				hold2 = VfxKit.impactFrames(ui.gui, silhouettes(rifle),
					if big then { "invert", "manga", "invert", "red" } else { "manga", "red" }, 0.06) + 0.08
			end
			task.wait(hold2)
		elseif t and t.kind == "king" then
			task.wait(0.35) -- a beat on the MISS as the bullet passes through the afterimage
		end
	end
	fadeAndDestroy(bullet, 0.2)
	glowGui.Enabled = false
	for _, r in rails do
		r:fade(0.9)
	end
	sound("rumble", base, { fadeAfter = 1.6, fadeTime = 0.8 })
	for _, t in line do
		if t.kind == "hit" then
			puff(folder, view:squareCFrame(t.sq).Position + UP * 0.4, 5, Color3.fromRGB(200, 190, 180), 1.4, 1, 1.2)
		end
	end
	if cam then
		-- a wide look back down the line
		local far = if #line > 0 then view:squareCFrame(line[#line].sq).Position else base + d * 4
		local mid = (base + far) / 2
		CameraRig.override(CFrame.lookAt(mid + side * 6 + UP * 6 - d * 1.5, mid), 50, 0.9)
	end

	-- hold to the full length, then hand the board back
	local rest2 = total - (os.clock() - started) - 0.35
	if rest2 > 0 then
		task.wait(rest2)
	end
	if ui then
		ui.show(false)
		CameraRig.override(nil)
		hideLocal(avatar, false)
		VfxKit.bloom(false)
		task.delay(0.4, function()
			ui.gui:Destroy()
		end)
	end
	unAura()
	unRifleAura()
	for _, p in rifle:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "Root" then
			TweenService:Create(p, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		end
	end
	if bishop and bishop.model.Parent and rest then
		local from0 = bishop.model:GetPivot()
		animate(0.3, function(a)
			bishop.model:PivotTo(from0:Lerp(rest, ease(a)))
		end)
	else
		task.wait(0.3)
	end
	folder:Destroy()
	if opts.done then
		opts.done()
	end
end


-- Battering Ram ----------------------------------------------------------------------------------
-- The same treatment as Snipe, in orange (about 8 s):
--   wind-up  a low camera in front of the rook looking back at it; it snorts steam like a bull and
--            rocks back twice, each stomp cracking the board (braam, then a riser cut dead on launch)
--   launch   an impact-frame burst, a shockwave behind it, orange speed lines, a trailer hit
--   charge   it accelerates down the line leaving orange afterimages and a dust trail; every piece it
--            reaches is launched spinning into the air (impact frames and a hitstop on each)
--   skid     sparks and a wood scrape as it brakes; an enemy king it stops in front of flinches ("!")
local ORANGE = Color3.fromRGB(255, 140, 50)
local RAM_LAUNCH = 2.6 -- seconds from the start to the launch (the riser ends here)

-- a copy of a piece thrown into the air, spinning, that fades out (the real one is removed at once)
local function launchCopy(folder, model, push)
	local copy = model:Clone()
	for _, p in copy:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
		end
	end
	copy.Parent = folder
	local parts = partsOf(copy)
	local start = copy:GetPivot()
	local v = push + UP * (7 + math.random() * 2)
	local spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit * 14
	task.spawn(function()
		local t0 = os.clock()
		while copy.Parent do
			local t = os.clock() - t0
			if t > 1.1 then
				break
			end
			local pos = start.Position + v * t + Vector3.new(0, -16 * t * t, 0)
			copy:PivotTo(CFrame.new(pos) * CFrame.fromAxisAngle(spin.Unit, spin.Magnitude * t) * (start - start.Position))
			fade(parts, math.clamp((t - 0.6) / 0.5, 0, 1))
			RunService.RenderStepped:Wait()
		end
		copy:Destroy()
	end)
end

-- a fading orange ghost of a model where it is now (the charge's afterimages)
local function afterimage(folder, model, color, life)
	local ghost = model:Clone()
	for _, p in ghost:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CastShadow = true, false, false
			p.Color = color
			p.Material = Enum.Material.Neon
			p.Transparency = 0.75 -- (Neon under the cutscene bloom washes out if it's any stronger)
		elseif p:IsA("Highlight") or p:IsA("Light") then
			p:Destroy()
		end
	end
	ghost.Parent = folder
	local parts = partsOf(ghost)
	task.spawn(function()
		animate(life, function(a)
			fade(parts, a)
		end)
		ghost:Destroy()
	end)
end

scenes.RookRam = function(view, action, t, opts, folder)
	local cam = opts.camera
	local gui = opts.gui
	local started = os.clock()
	local e = view:modelAt(action.from)
	local p0, pl = view:squareCFrame(action.from).Position, view:squareCFrame(t.land).Position
	local d = if (pl - p0).Magnitude > 0.01 then (pl - p0).Unit else Vector3.xAxis
	local lat = d:Cross(UP).Unit -- sideways
	local function snd(name, pos, o)
		return Sounds.play(name, if cam then nil else pos, o)
	end
	local function silhouettes()
		local list = {}
		for _, m in view.models do
			table.insert(list, m.model)
		end
		return list
	end
	local avatar = if cam then Players.LocalPlayer.Character else nil
	if cam then
		hideLocal(avatar, true)
		VfxKit.bloom(true)
	end
	if not (e and e.model.Parent) then
		task.wait(1)
		if cam then
			hideLocal(avatar, false)
			VfxKit.bloom(false)
		end
		return
	end
	local rook = e.model
	local rest = rook:GetPivot()
	local spin = rest - rest.Position
	local h = rook:GetExtentsSize().Y
	-- the rook's pose: tilted back by `lean` radians and slid `back` studs from its square
	local function pose(at, lean, back)
		rook:PivotTo(CFrame.new(at - d * (back or 0)) * CFrame.fromAxisAngle(lat, lean or 0) * spin)
	end
	local unAura = VfxKit.aura(rook, ORANGE)

	-- WIND-UP ------------------------------------------------------------------------------------------
	if cam then
		local face = p0 + UP * h * 0.55
		CameraRig.override(CFrame.lookAt(p0 + d * 3.6 + UP * 0.8 + lat * 0.9, face), 50)
		task.delay(0.05, function()
			CameraRig.override(CFrame.lookAt(p0 + d * 2.6 + UP * 0.7 + lat * 0.6, face), 44, 2.2)
		end)
	end
	snd("braam", p0, { fadeAfter = 2.0, fadeTime = 0.5 })
	snd("riser", p0, { timePosition = 4.0 - RAM_LAUNCH })
	local stopCharge = VfxKit.charge(folder, p0 + UP * 0.3, ORANGE, 1.5)
	local function snort()
		snd("snort", p0)
		for _, s2 in { -1, 1 } do
			puff(folder, p0 + UP * h * 0.95 + lat * s2 * 0.25 + d * 0.2, 6, Color3.fromRGB(240, 240, 240), 0.9, 3, 0.7)
		end
	end
	local function stomp(power)
		snd("stomp", p0, { volume = 0.5 + power * 0.4 })
		VfxKit.shockwave(folder, CFrame.new(p0 + UP * 0.06), ORANGE, view.size * (1.8 + power), 0.4)
		puff(folder, p0 + UP * 0.15, 8, Color3.fromRGB(215, 200, 175), 1.2, 2.5, 0.8)
		if power > 0.5 then
			VfxKit.decal(folder, CFrame.new(p0 + UP * 0.03) * CFrame.Angles(0, math.random() * 6.28, 0), TX.crack,
				Color3.fromRGB(40, 24, 24), view.size * 1.3, 3)
			VfxKit.sparks(folder, CFrame.lookAt(p0 + UP * 0.1, p0 + UP), ORANGE, 16, 9, 80)
		end
		if cam then
			CameraRig.shake(0.15 + power * 0.25, 0.2)
		end
	end
	task.wait(0.35)
	snort()
	task.wait(0.35)
	-- two rock-backs, the second bigger
	for i, power in { 0.4, 1 } do
		local lean = math.rad(10 + power * 8)
		animate(0.3, function(a)
			pose(rest.Position, lean * ease(a), 0.25 * power * ease(a))
		end)
		animate(0.1, function(a)
			local k = 1 - a * a
			pose(rest.Position, lean * k, 0.25 * power * k)
		end)
		pose(rest.Position, 0, 0)
		stomp(power)
		if i == 1 then
			task.wait(0.25)
			snort()
		end
	end
	-- the held breath: crouched back, silent, then GO
	animate(0.25, function(a)
		pose(rest.Position, math.rad(12) * ease(a), 0.2 * ease(a))
	end)
	stopCharge()
	local launchAt = started + RAM_LAUNCH
	if os.clock() < launchAt then
		task.wait(launchAt - os.clock())
	end

	-- LAUNCH -------------------------------------------------------------------------------------------
	snd("trailerHit", p0)
	snd("rush", p0)
	local hitstop = 0.1
	if gui then
		hitstop = VfxKit.impactFrames(gui, silhouettes(), { "white", "invert", "manga" }, 0.06)
	end
	VfxKit.shockwave(folder, across(p0 + UP * h * 0.5 - d * 0.4, d), ORANGE, 3, 0.4)
	VfxKit.shockwave(folder, CFrame.new(p0 + UP * 0.06), WHITE_HOT, view.size * 3, 0.45)
	VfxKit.sparks(folder, CFrame.lookAt(p0 + UP * 0.1, p0 - d + UP * 0.6), ORANGE, 24, 14, 40)
	task.wait(hitstop)

	-- CHARGE -------------------------------------------------------------------------------------------
	local start = rest.Position - d * 0.2
	local finish = pl
	local dist = (finish - start).Magnitude
	local travel = math.clamp(dist / 6, 1.0, 2.0)
	local pending = {}
	for _, sq in t.hits do
		table.insert(pending, { sq = sq, at = (view:squareCFrame(sq).Position - start):Dot(d) - view.size * 0.5 })
	end
	table.sort(pending, function(a, b)
		return a.at < b.at
	end)
	local lastAt = if #pending > 0 then pending[#pending].at else nil
	local firstDone = false
	if gui then
		VfxKit.speedLines(gui, travel + 0.6, ORANGE)
	end
	-- the rook's place along the line for a = 0..1: it accelerates, then skids the last stretch
	local SKID = 0.8
	local function along(a)
		if a < SKID then
			return 0.88 * (a / SKID) ^ 1.5
		end
		local k = (a - SKID) / (1 - SKID)
		return 0.88 + 0.12 * (1 - (1 - k) ^ 2)
	end
	local clock, last = 0, os.clock()
	local lastGhost, lastDust = 0, 0
	local skidding = false
	while clock < travel do
		local now = os.clock()
		clock += now - last
		last = now
		local a = math.clamp(clock / travel, 0, 1)
		local pos = start:Lerp(finish, along(a))
		local leanFwd = if a < SKID then -math.rad(8) else -math.rad(8) * (1 - (a - SKID) / (1 - SKID)) + math.rad(6) * math.sin(math.min(1, (a - SKID) / (1 - SKID)) * math.pi)
		pose(pos, leanFwd, 0)
		if cam then
			local from = pos - d * (2.4 + 0.6 * a) + UP * 0.9 + lat * 1.2
			CameraRig.override(CFrame.lookAt(from, pos + d * 1.5 + UP * h * 0.4), 58)
		end
		if a < SKID and now - lastGhost > 0.06 then
			lastGhost = now
			afterimage(folder, rook, Color3.fromRGB(255, 110, 30), 0.3)
		end
		if now - lastDust > 0.08 then
			lastDust = now
			puff(folder, pos + UP * 0.1, 3, Color3.fromRGB(215, 200, 175), 0.9, 1.5, 0.6)
		end
		if a >= SKID and not skidding then
			skidding = true
			snd("skid", pos, { fadeAfter = 0.8, fadeTime = 0.3 })
		end
		if skidding and math.random() < 0.5 then
			VfxKit.sparks(folder, CFrame.lookAt(pos + UP * 0.05, pos - d + UP * 0.3), ORANGE, 3, 8, 30)
		end
		-- smash whatever it has reached
		local travelled = (pos - start):Dot(d)
		while pending[1] and travelled >= pending[1].at do
			local hit = table.remove(pending, 1)
			local victim = view:modelAt(hit.sq)
			local hp = view:squareCFrame(hit.sq).Position
			local big = not firstDone or hit.at == lastAt
			firstDone = true
			if victim and victim.model.Parent then
				launchCopy(folder, victim.model, d * 6 + lat * (math.random() - 0.5) * 6)
				hideLocal(victim.model, true) -- the flying copy takes its place
				debris(folder, hp + UP * 0.8, 10, firstColor(victim.model), Vector3.new(0.13, 0.13, 0.13), 10, false, if cam then lat else nil)
			end
			if opts.onHit then
				opts.onHit(hit.sq)
			end
			VfxKit.flare(folder, hp + UP * 0.8, TX.star, WHITE_HOT, 0.6, 3.6, 0.22, 35)
			VfxKit.shockwave(folder, CFrame.new(hp + UP * 0.06), ORANGE, view.size * 2.6, 0.4)
			VfxKit.shockwave(folder, across(hp + UP * 0.8, d), WHITE_HOT, 2.2, 0.25)
			VfxKit.sparks(folder, CFrame.lookAt(hp + UP * 0.8, hp + UP * 0.8 + d), ORANGE, 26, 16, 60)
			VfxKit.decal(folder, CFrame.new(hp + UP * 0.03) * CFrame.Angles(0, math.random() * 6.28, 0), TX.crack,
				Color3.fromRGB(40, 24, 24), view.size * 1.2, 3)
			snd("woodBreak", hp)
			snd("crateBreak", hp)
			snd(if big then (if hit.at == lastAt then "lowBoom" else "impactBoom") else "stomp", hp)
			if cam then
				CameraRig.shake(if big then 0.5 else 0.3, 0.25)
			end
			-- hitstop with impact frames (the clock doesn't run while it holds)
			local hold = 0.1
			if gui then
				hold = VfxKit.impactFrames(gui, silhouettes(), if big then { "invert", "manga", "red" } else { "manga", "red" }, 0.06) + 0.06
			end
			task.wait(hold)
			last = os.clock()
		end
		RunService.RenderStepped:Wait()
	end
	pose(finish, 0, 0)
	e.sq = t.land
	stomp(0.6)

	-- an enemy king right in front of where it stopped flinches
	local fileOf = function(sq)
		return sq % 16
	end
	local beyond = t.land + action.dir
	if bit32.band(beyond, 0x88) == 0 and math.abs(fileOf(beyond) - fileOf(t.land)) <= 1 then
		local k = view:modelAt(beyond)
		if k and k.type == "k" and k.color ~= e.color and k.model.Parent then
			local kr = k.model:GetPivot()
			local kh = k.model:GetExtentsSize().Y
			task.spawn(function()
				animate(0.18, function(a)
					k.model:PivotTo(CFrame.new(kr.Position) * CFrame.fromAxisAngle(lat, -math.rad(16) * ease(a)) * (kr - kr.Position))
				end)
				task.wait(0.6)
				animate(0.35, function(a)
					k.model:PivotTo(CFrame.new(kr.Position) * CFrame.fromAxisAngle(lat, -math.rad(16) * (1 - ease(a))) * (kr - kr.Position))
				end)
			end)
			local tag = Instance.new("Part")
			tag.Anchored, tag.CanCollide, tag.CanQuery, tag.CanTouch, tag.Transparency = true, false, false, false, 1
			tag.Size = Vector3.one * 0.1
			tag.CFrame = CFrame.new(kr.Position + UP * (kh + 0.4))
			tag.Parent = folder
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromScale(1, 1.2)
			bb.AlwaysOnTop = true
			bb.LightInfluence = 0
			bb.Parent = tag
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.Arcade
			label.Text = "!"
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(255, 70, 60)
			label.Parent = bb
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 3
			stroke.Parent = label
			local pop = Instance.new("UIScale")
			pop.Scale = 2
			pop.Parent = label
			TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			snd("dodge", kr.Position, { volume = 0.4, speed = 1.6 })
		end
	end

	-- SETTLE -------------------------------------------------------------------------------------------
	snd("rumble", pl, { fadeAfter = 1.5, fadeTime = 0.8 })
	puff(folder, pl + UP * 0.2, 10, Color3.fromRGB(215, 200, 175), 1.6, 2, 1.2)
	if cam then
		local mid = (p0 + pl) / 2
		local span = (pl - p0).Magnitude
		CameraRig.override(CFrame.lookAt(mid + lat * (5 + span * 0.4) + UP * (5 + span * 0.35), mid), 48, 0.9)
	end
	local total = Settings.cutscene("RookRam")
	local left = total - (os.clock() - started) - 0.6
	if left > 0 then
		task.wait(left)
	end
	unAura()
	if cam then
		hideLocal(avatar, false)
		VfxKit.bloom(false)
	end
end


-- Double Jump --------------------------------------------------------------------------------------
-- The same treatment, in blue (about 8.5 s):
--   wind-up  a low side camera; the knight rears up like a horse and neighs, stamps down (a crack), then
--            crouches (braam, then a riser cut dead on the take-off)
--   leap 1   impact frames on take-off; a high arc with hang time at the top (speed lines, blue
--            afterimages); the camera tracks it from the side
--   land 1   a shockwave and a crack; a capture launches the piece spinning (impact frames, hitstop)
--   leap 2   a whip-pan to the next square; it springs again at once, higher, spinning a full turn
--   land 2   the biggest hit: a long impact-frame burst, a double shockwave, a big shake
local BLUE = Color3.fromRGB(90, 160, 255)
local JUMP_TAKEOFF = 2.0

scenes.KnightJump = function(view, action, hits, opts, folder)
	local cam = opts.camera
	local gui = opts.gui
	local started = os.clock()
	local e = view:modelAt(action.from)
	local function snd(name, pos, o)
		return Sounds.play(name, if cam then nil else pos, o)
	end
	local function silhouettes()
		local list = {}
		for _, m in view.models do
			table.insert(list, m.model)
		end
		return list
	end
	if not (e and e.model.Parent) then
		task.wait(1)
		return
	end
	local avatar = if cam then Players.LocalPlayer.Character else nil
	if cam then
		hideLocal(avatar, true)
		VfxKit.bloom(true)
	end
	local knight = e.model
	local rest = knight:GetPivot()
	local spin = rest - rest.Position
	local h = knight:GetExtentsSize().Y
	local p0 = view:squareCFrame(action.from).Position
	local p1 = view:squareCFrame(action.mid).Position
	local p2 = view:squareCFrame(action.to).Position
	local function flat(v)
		v = Vector3.new(v.X, 0, v.Z)
		return if v.Magnitude > 0.01 then v.Unit else Vector3.xAxis
	end
	-- the knight at `at`, tilted by `tilt` radians about the axis `lat` (+ = top back), turned `yaw`
	local function pose(at, lat, tilt, yaw)
		knight:PivotTo(CFrame.new(at) * CFrame.fromAxisAngle(lat, tilt or 0) * CFrame.Angles(0, yaw or 0, 0) * spin)
	end
	local unAura = VfxKit.aura(knight, BLUE)

	-- WIND-UP ------------------------------------------------------------------------------------------
	local d1 = flat(p1 - p0)
	local lat1 = d1:Cross(UP).Unit
	if cam then
		local face = p0 + UP * h * 0.55
		CameraRig.override(CFrame.lookAt(p0 + lat1 * 3.6 + d1 * 0.8 + UP * 0.9, face), 50)
		task.delay(0.05, function()
			CameraRig.override(CFrame.lookAt(p0 + lat1 * 2.7 + d1 * 0.6 + UP * 0.8, face), 44, 1.8)
		end)
	end
	snd("braam", p0, { fadeAfter = 1.6, fadeTime = 0.5 })
	snd("riser", p0, { timePosition = 4.0 - JUMP_TAKEOFF })
	local stopCharge = VfxKit.charge(folder, p0 + UP * 0.3, BLUE, 1.4)
	task.wait(0.35)
	-- rear up like a horse, neighing, then stamp down
	snd("neigh", p0)
	animate(0.45, function(a)
		local k = ease(a)
		pose(p0 + UP * 0.25 * k - d1 * 0.15 * k, lat1, math.rad(28) * k)
	end)
	task.wait(0.25)
	animate(0.12, function(a)
		local k = 1 - a * a
		pose(p0 + UP * 0.25 * k - d1 * 0.15 * k, lat1, math.rad(28) * k)
	end)
	pose(p0, lat1, 0)
	snd("stomp", p0)
	VfxKit.shockwave(folder, CFrame.new(p0 + UP * 0.06), BLUE, view.size * 2.4, 0.4)
	VfxKit.decal(folder, CFrame.new(p0 + UP * 0.03) * CFrame.Angles(0, math.random() * 6.28, 0), TX.crack,
		Color3.fromRGB(30, 30, 50), view.size * 1.2, 3)
	puff(folder, p0 + UP * 0.15, 8, Color3.fromRGB(215, 200, 175), 1.2, 2.5, 0.8)
	if cam then
		CameraRig.shake(0.3, 0.2)
	end
	-- crouch for the spring
	animate(0.3, function(a)
		pose(p0, lat1, -math.rad(12) * ease(a))
	end)
	stopCharge()
	local takeoff = started + JUMP_TAKEOFF
	if os.clock() < takeoff then
		task.wait(takeoff - os.clock())
	end

	-- the two leaps ----------------------------------------------------------------------------------
	local legs = {
		{ from = p0, to = p1, sq = action.mid, height = view.size * 3.0, spin = 0, last = false },
		{ from = p1, to = p2, sq = action.to, height = view.size * 3.6, spin = math.pi * 2, last = true },
	}
	for n, leg in legs do
		local dir = flat(leg.to - leg.from)
		local lat = dir:Cross(UP).Unit
		local mid = (leg.from + leg.to) / 2
		-- take-off
		if n == 1 then
			snd("trailerHit", leg.from)
			if gui then
				task.wait(VfxKit.impactFrames(gui, silhouettes(), { "white", "invert", "manga" }, 0.06))
			end
		else
			-- a whip-pan to the new leg, a short crouch, and straight back up
			if cam then
				CameraRig.override(CFrame.lookAt(mid + lat * 6 + UP * 2.4, mid + UP * 0.6), 55, 0.25)
			end
			animate(0.15, function(a)
				pose(leg.from, lat, -math.rad(12) * ease(a))
			end)
		end
		snd("leap", leg.from)
		snd(if n == 1 then "rush" else "slowWhoosh", leg.from, { volume = 0.6 })
		VfxKit.shockwave(folder, CFrame.new(leg.from + UP * 0.06), BLUE, view.size * 2.6, 0.4)
		puff(folder, leg.from + UP * 0.1, 10, Color3.fromRGB(215, 200, 175), 1.3, 3, 0.8)
		VfxKit.sparks(folder, CFrame.lookAt(leg.from + UP * 0.1, leg.from + UP), BLUE, 18, 12, 50)
		if gui then
			VfxKit.speedLines(gui, 1.1, BLUE)
		end
		-- the flight: hang time at the top (k slows right down around the middle)
		local dur = 1.15
		local t0 = os.clock()
		local lastGhost = 0
		while true do
			local u = math.clamp((os.clock() - t0) / dur, 0, 1)
			local hang = 0.5 + 4 * (u - 0.5) ^ 3
			local k = u * 0.35 + hang * 0.65
			local pos = leg.from:Lerp(leg.to, k) + UP * leg.height * 4 * k * (1 - k)
			local tilt = math.rad(15) * (1 - k) - math.rad(22) * k -- nose up going up, nose down coming down
			pose(pos, lat, tilt, leg.spin * k)
			if cam then
				-- the camera rises with the knight and keeps it centred, all the way up the arc
				local look = pos + UP * h * 0.45
				local rise = (pos.Y - mid.Y) * 0.8
				CameraRig.override(CFrame.lookAt(mid + lat * 7 - dir * 0.6 + UP * (2.2 + rise), look), 58)
			end
			if os.clock() - lastGhost > 0.07 then
				lastGhost = os.clock()
				afterimage(folder, knight, Color3.fromRGB(80, 140, 255), 0.35)
			end
			if u >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		pose(leg.to, lat, 0, leg.spin)
		e.sq = leg.sq

		-- landing
		local captured = table.find(hits, leg.sq) ~= nil
		local big = leg.last
		local victim = nil
		for _, m in view.models do
			if m ~= e and m.sq == leg.sq then
				victim = m
			end
		end
		if captured and victim and victim.model.Parent then
			launchCopy(folder, victim.model, dir * 5 + lat * (math.random() - 0.5) * 6)
			debris(folder, leg.to + UP * 0.6, 10, firstColor(victim.model), Vector3.new(0.13, 0.13, 0.13), 9, false, if cam then lat else nil)
			hideLocal(victim.model, true)
		end
		if captured and opts.onHit then
			opts.onHit(leg.sq)
		end
		VfxKit.shockwave(folder, CFrame.new(leg.to + UP * 0.06), BLUE, view.size * (if big then 3.6 else 2.6), 0.45)
		task.delay(0.06, VfxKit.shockwave, folder, CFrame.new(leg.to + UP * 0.07), WHITE_HOT, view.size * (if big then 2.4 else 1.6), 0.35)
		VfxKit.flare(folder, leg.to + UP * 0.5, TX.star, WHITE_HOT, 0.6, if big then 4 else 3, 0.22, 35)
		VfxKit.sparks(folder, CFrame.lookAt(leg.to + UP * 0.1, leg.to + UP), BLUE, if big then 30 else 18, 14, 75)
		VfxKit.decal(folder, CFrame.new(leg.to + UP * 0.03) * CFrame.Angles(0, math.random() * 6.28, 0), TX.crack,
			Color3.fromRGB(30, 30, 50), view.size * (if big then 1.5 else 1.1), 3)
		puff(folder, leg.to + UP * 0.15, if big then 14 else 8, Color3.fromRGB(215, 200, 175), 1.5, 3, 0.9)
		snd("stomp", leg.to)
		if captured then
			snd("woodBreak", leg.to)
			snd("crateBreak", leg.to)
		end
		snd(if big then "lowBoom" elseif captured then "impactBoom" else "stomp", leg.to)
		if big then
			snd("trailerHit", leg.to, { volume = 0.6 })
		end
		if cam then
			CameraRig.shake(if big then 0.6 elseif captured then 0.4 else 0.25, 0.3)
		end
		local pattern = if big then { "white", "invert", "manga", "invert", "red" }
			elseif captured then { "invert", "manga", "red" }
			else { "manga" }
		if gui then
			task.wait(VfxKit.impactFrames(gui, silhouettes(), pattern, 0.06))
		end
		task.wait(if big then 0.15 else 0.25)
	end

	-- SETTLE -------------------------------------------------------------------------------------------
	snd("rumble", p2, { fadeAfter = 1.4, fadeTime = 0.8 })
	if cam then
		local center = (p0 + p1 + p2) / 3
		local lat = flat(p2 - p0):Cross(UP)
		lat = if lat.Magnitude > 0.01 then lat.Unit else Vector3.xAxis
		CameraRig.override(CFrame.lookAt(center + lat * 7 + UP * 6.5, center), 48, 0.9)
	end
	local total = Settings.cutscene("KnightJump")
	local left = total - (os.clock() - started) - 0.6
	if left > 0 then
		task.wait(left)
	end
	unAura()
	if cam then
		hideLocal(avatar, false)
		VfxKit.bloom(false)
	end
end

-- ROYAL ESCAPE ===========================================================================================
-- Tension (the checking pieces' red lines, a gold column charging) → vanish (impact frames, a pillar of
-- light, the king shoots up) → a gold sigil forms over the landing square → the king slams down into it
-- (a capture launches the piece) → gold motes settle. About 7.5 s (Settings.CUTSCENES.KingEscape).

local ESCAPE_VANISH = 2.4

-- the pieces of the other colour that attack `sq` right now, from the models on the board
local function attackersOf(view, sq, color)
	local occ = {}
	for _, m in view.models do
		if m.sq then
			occ[m.sq] = m
		end
	end
	local f0, r0 = sq % 16, sq // 16
	local out = {}
	for _, m in view.models do
		if m.sq and m.color ~= color and m.model.Parent then
			local df, dr = f0 - m.sq % 16, r0 - m.sq // 16
			local adf, adr = math.abs(df), math.abs(dr)
			local hit = false
			if m.type == "p" then
				hit = adf == 1 and dr == (if m.color == "w" then 1 else -1)
			elseif m.type == "n" then
				hit = (adf == 1 and adr == 2) or (adf == 2 and adr == 1)
			elseif m.type == "k" then
				hit = math.max(adf, adr) == 1
			else
				local straight = (df == 0 or dr == 0) and (adf + adr > 0)
				local diag = adf == adr and adf > 0
				if (straight and (m.type == "r" or m.type == "q")) or (diag and (m.type == "b" or m.type == "q")) then
					local sf, sr = math.sign(df), math.sign(dr)
					hit = true
					for i = 1, math.max(adf, adr) - 1 do
						if occ[m.sq + (sr * 16 + sf) * i] then
							hit = false
							break
						end
					end
				end
			end
			if hit then
				table.insert(out, m)
			end
		end
	end
	return out
end

-- a flat spinning textured disc on the board (the landing sigil)
local function sigil(folder, pos, texture, color, size)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(size, 0.02, size)
	p.CFrame = CFrame.new(pos)
	p.Parent = folder
	local decals = {}
	for _, face in { Enum.NormalId.Top, Enum.NormalId.Bottom } do
		local d = Instance.new("Decal")
		d.Texture = texture
		d.Color3 = color
		d.Transparency = 1
		d.Face = face
		d.Parent = p
		table.insert(decals, d)
	end
	local o = { part = p }
	function o.set(scale, angle, transparency)
		p.Size = Vector3.new(size * scale, 0.02, size * scale)
		p.CFrame = CFrame.new(pos) * CFrame.Angles(0, angle, 0)
		for _, d in decals do
			d.Transparency = transparency
		end
	end
	return o
end

-- gold motes drifting down over `pos` for `life` seconds
local function motes(folder, pos, color, life)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
	p.Size = Vector3.new(4, 0.1, 4)
	p.CFrame = CFrame.new(pos + UP * 4)
	p.Parent = folder
	local e = Instance.new("ParticleEmitter")
	e.Texture = TX.glow
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.22), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0.1)
	e.Lifetime = NumberRange.new(1.6, 2.4)
	e.Speed = NumberRange.new(0.2, 0.6)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -1.2, 0)
	e.Rate = 40
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Parent = p
	task.delay(life, function()
		e.Enabled = false
		task.wait(2.5)
		p:Destroy()
	end)
end

scenes.KingEscape = function(view, action, hits, opts, folder)
	local cam = opts.camera
	local gui = opts.gui
	local started = os.clock()
	local e = view:modelAt(action.from)
	local function snd(name, pos, o)
		return Sounds.play(name, if cam then nil else pos, o)
	end
	local function silhouettes()
		local list = {}
		for _, m in view.models do
			table.insert(list, m.model)
		end
		return list
	end
	if not (e and e.model.Parent) then
		task.wait(1)
		return
	end
	local avatar = if cam then Players.LocalPlayer.Character else nil
	if cam then
		hideLocal(avatar, true)
		VfxKit.bloom(true)
	end
	local king = e.model
	local base = partsOf(king)
	local rest = king:GetPivot()
	local h = king:GetExtentsSize().Y
	local pa = view:squareCFrame(action.from).Position
	local pb = view:squareCFrame(action.to).Position
	local land = view:squareCFrame(action.to, e.color)
	local d = Vector3.new(pb.X - pa.X, 0, pb.Z - pa.Z)
	d = if d.Magnitude > 0.01 then d.Unit else Vector3.zAxis
	local lat = d:Cross(UP).Unit
	-- the way into the board from the landing square (the landing shots look from there, so a king that
	-- escapes to an edge square isn't shot from off the board)
	local centre = (view:squareCFrame(0).Position + view:squareCFrame(119).Position) / 2
	local inward = Vector3.new(centre.X - pb.X, 0, centre.Z - pb.Z)
	inward = if inward.Magnitude > 0.01 then inward.Unit else -d
	local inSide = inward:Cross(UP).Unit
	local victim = nil
	for _, m in view.models do
		if m ~= e and m.sq == action.to then
			victim = m
		end
	end
	local unAura = VfxKit.aura(king, GOLD)

	-- TENSION ------------------------------------------------------------------------------------------
	-- close on the king from behind its escape line, so the landing square sits in the background
	if cam then
		local face = pa + UP * h * 0.6
		CameraRig.override(CFrame.lookAt(pa - d * 3.4 + lat * 1.4 + UP * 1.2, face), 52)
		task.delay(0.05, function()
			CameraRig.override(CFrame.lookAt(pa - d * 2.5 + lat * 1.0 + UP * 1.0, face), 44, 2.2)
		end)
	end
	local threats = {}
	local attackers = attackersOf(view, action.from, e.color)
	for _, m in attackers do
		local from = m.model:GetPivot().Position + UP * m.model:GetExtentsSize().Y * 0.5
		local b = VfxKit.beam(folder, from, pa + UP * h * 0.5, RED, 0.24)
		table.insert(threats, b)
		VfxKit.flare(folder, from, TX.glow, RED, 0.4, 1.4, 0.4)
	end
	local beat
	if #attackers > 0 then
		snd("dodge", pa, { volume = 0.4, speed = 0.6 })
		beat = snd("heartbeat", pa, { volume = 0.7 })
	end
	snd("braam", pa, { fadeAfter = 2.0, fadeTime = 0.6 })
	snd("riser", pa, { timePosition = 4.0 - ESCAPE_VANISH })
	task.wait(0.7)
	-- the king calls on its crown: a gold column rises around it, a choir swells
	local choir = snd("choir", pa, { volume = 0.0 })
	if choir then
		TweenService:Create(choir, TweenInfo.new(1.4), { Volume = 0.5 }):Play()
	end
	local stopCharge = VfxKit.charge(folder, pa + UP * 0.3, GOLD, 1.5)
	local column = fx(folder, Enum.PartType.Cylinder, Vector3.new(0.1, view.size * 0.95, view.size * 0.95),
		CFrame.new(pa) * CFrame.Angles(0, 0, math.pi / 2), GOLD, 0.9)
	VfxKit.shockwave(folder, CFrame.new(pa + UP * 0.06), GOLD, view.size * 2.2, 0.5)
	animate(1.2, function(a)
		local k = ease(a)
		local tall = 0.1 + 7 * k
		column.Size = Vector3.new(tall, view.size * (0.95 - 0.2 * k), view.size * (0.95 - 0.2 * k))
		column.CFrame = CFrame.new(pa + UP * tall / 2) * CFrame.Angles(0, 0, math.pi / 2)
		column.Transparency = 0.9 - 0.08 * k -- faint: the bloom blows a stronger column out over the king
		-- the king trembles and lifts off the square
		local shake = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 0.04 * k
		king:PivotTo(rest + UP * 0.35 * k + shake)
		for _, b in threats do
			b.beam.Width0 = 0.24 + 0.1 * math.sin(os.clock() * 30)
			b.beam.Width1 = b.beam.Width0
		end
	end)
	stopCharge()
	local vanishAt = started + ESCAPE_VANISH
	if os.clock() < vanishAt then
		task.wait(vanishAt - os.clock())
	end

	-- VANISH -------------------------------------------------------------------------------------------
	if beat then
		Sounds.fade(beat, 0.2)
	end
	snd("trailerHit", pa)
	snd("beamBlast", pa)
	if gui then
		task.wait(VfxKit.impactFrames(gui, silhouettes(), { "white", "invert", "manga" }, 0.06))
	end
	-- the threats strike empty air
	for _, b in threats do
		b:fade(0.25)
	end
	for _ = 1, #attackers do
		VfxKit.sparks(folder, CFrame.lookAt(pa + UP * h * 0.5, pa + UP * 3), RED, 10, 9, 70)
	end
	-- a pillar of light; the king streaks up it
	local pillar = fx(folder, Enum.PartType.Cylinder, Vector3.new(40, view.size * 1.2, view.size * 1.2),
		CFrame.new(pa + UP * 20) * CFrame.Angles(0, 0, math.pi / 2), WHITE_HOT, 0.1)
	TweenService:Create(pillar, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = Vector3.new(40, 0.05, 0.05) }):Play()
	fadeAndDestroy(pillar, 0.6)
	fadeAndDestroy(column, 0.3)
	VfxKit.shockwave(folder, CFrame.new(pa + UP * 0.06), GOLD, view.size * 3.4, 0.45)
	task.delay(0.05, VfxKit.shockwave, folder, CFrame.new(pa + UP * 0.07), WHITE_HOT, view.size * 2.2, 0.35)
	VfxKit.flare(folder, pa + UP * h * 0.5, TX.star, WHITE_HOT, 0.6, 4.5, 0.3, 40)
	VfxKit.sparks(folder, CFrame.lookAt(pa + UP * 0.2, pa + UP * 5), GOLD, 40, 18, 25)
	if cam then
		CameraRig.shake(0.45, 0.3)
		CameraRig.override(CFrame.lookAt(pa - d * 3.4 + lat * 1.4 + UP * 0.8, pa + UP * 2.2), 60, 0.35)
	end
	local lifted = king:GetPivot()
	animate(0.28, function(a)
		local k = a * a
		king:PivotTo(lifted + UP * 9 * k)
		fade(base, math.clamp(a * 1.3, 0, 1))
	end)
	fade(base, 1)
	unAura()
	task.wait(0.35)

	-- SIGIL --------------------------------------------------------------------------------------------
	-- cut to above the landing square: the sigil draws itself, a light falls from the sky
	if cam then
		CameraRig.override(CFrame.lookAt(pb + UP * 8 - d * 2.6 + lat * 1.5, pb), 52)
		task.delay(0.05, function()
			CameraRig.override(CFrame.lookAt(pb + UP * 6.2 - d * 2.2 + lat * 1.2, pb), 48, 1.3)
		end)
	end
	local unMark = if victim and victim.model.Parent then VfxKit.aura(victim.model, RED) else nil
	snd("magic", pb, { volume = 0.6 })
	local outer = sigil(folder, pb + UP * 0.05, TX.ring, GOLD, view.size * 2.4)
	local inner = sigil(folder, pb + UP * 0.06, TX.star, WHITE_HOT, view.size * 1.4)
	local stopCharge2 = VfxKit.charge(folder, pb + UP * 0.3, GOLD, 1.4)
	local sky = VfxKit.beam(folder, pb + UP * 30, pb + UP * 30, GOLD, view.size * 0.6)
	animate(1.0, function(a)
		local k = ease(a)
		outer.set(0.3 + 0.7 * k, a * 2.5, 1 - 0.85 * k)
		inner.set(0.2 + 0.8 * k, -a * 3.5, 1 - 0.7 * k)
		sky:set(pb + UP * 30, pb + UP * (30 - 29.9 * k))
	end)
	stopCharge2()
	snd("warpIn", pb, { volume = 0.8 })
	task.wait(0.25)

	-- DROP-IN ------------------------------------------------------------------------------------------
	if cam then
		CameraRig.override(CFrame.lookAt(pb + inward * 3.0 + inSide * 1.2 + UP * 0.7, pb + UP * h * 0.6), 54)
	end
	e.sq = action.to
	fade(base, 0)
	local unAura2 = VfxKit.aura(king, GOLD)
	animate(0.18, function(a)
		king:PivotTo(land + UP * 8 * (1 - a * a))
		if math.random() < 0.6 then
			afterimage(folder, king, GOLD, 0.3)
		end
	end)
	king:PivotTo(land)
	sky:fade(0.3)
	local captured = #hits > 0
	if unMark then
		unMark()
	end
	if captured and victim and victim.model.Parent then
		launchCopy(folder, victim.model, -inward * 5 + inSide * (math.random() - 0.5) * 6)
		debris(folder, pb + UP * 0.6, 10, firstColor(victim.model), Vector3.new(0.13, 0.13, 0.13), 9, false, if cam then inward else nil)
		hideLocal(victim.model, true)
	end
	if captured and opts.onHit then
		opts.onHit(action.to)
	end
	VfxKit.shockwave(folder, CFrame.new(pb + UP * 0.06), GOLD, view.size * 4, 0.5)
	task.delay(0.06, VfxKit.shockwave, folder, CFrame.new(pb + UP * 0.07), WHITE_HOT, view.size * 2.6, 0.35)
	VfxKit.flare(folder, pb + UP * 0.6, TX.star, WHITE_HOT, 0.6, 4.5, 0.25, 35)
	VfxKit.sparks(folder, CFrame.lookAt(pb + UP * 0.1, pb + UP), GOLD, 34, 15, 80)
	VfxKit.decal(folder, CFrame.new(pb + UP * 0.03) * CFrame.Angles(0, math.random() * 6.28, 0), TX.crack,
		Color3.fromRGB(60, 45, 20), view.size * 1.5, 3)
	puff(folder, pb + UP * 0.15, 14, Color3.fromRGB(255, 230, 170), 1.5, 3, 0.9)
	snd("lowBoom", pb)
	snd("stomp", pb)
	if captured then
		snd("woodBreak", pb)
		snd("crateBreak", pb)
		snd("impactBoom", pb)
	end
	if cam then
		CameraRig.shake(if captured then 0.6 else 0.45, 0.35)
	end
	if gui then
		local pattern = if captured then { "white", "invert", "manga", "invert", "red" } else { "white", "invert", "manga" }
		task.wait(VfxKit.impactFrames(gui, silhouettes(), pattern, 0.06))
	end
	-- the sigil burns out
	task.spawn(function()
		animate(0.8, function(a)
			outer.set(1 + 0.3 * a, 2.5 + a, 0.15 + 0.85 * a)
			inner.set(1 + 0.5 * a, -3.5 - a, 0.3 + 0.7 * a)
		end)
		outer.part:Destroy()
		inner.part:Destroy()
	end)

	-- SETTLE -------------------------------------------------------------------------------------------
	motes(folder, pb, GOLD, 2.2)
	snd("twinkle", pb, { volume = 0.5 })
	if choir then
		Sounds.fade(choir, 1.8)
	end
	if cam then
		-- a slow low orbit on the king, then a wide shot of where it ran from and to
		CameraRig.override(CFrame.lookAt(pb + inward * 2.6 - inSide * 1.4 + UP * 0.9, pb + UP * h * 0.6), 50, 1.4)
	end
	local total = Settings.cutscene("KingEscape")
	task.wait(math.max(0, total - (os.clock() - started) - 2.0))
	if cam then
		local center = (pa + pb) / 2
		CameraRig.override(CFrame.lookAt(center + lat * 6.5 + UP * 6 - d * 1, center), 48, 0.9)
	end
	local left = total - (os.clock() - started) - 0.6
	if left > 0 then
		task.wait(left)
	end
	unAura2()
	if cam then
		hideLocal(avatar, false)
		VfxKit.bloom(false)
	end
end

-- ANY PASSANT ============================================================================================
-- A katana iaido: the pawn's sheathed katana drops in beside it; the blade slides an inch out with a
-- glint (the target, unaware, gets a "?") → flash step: the pawn vanishes in a teal line (impact frames)
-- → four flash-step slashes round the frozen target, each leaving its cut hanging in the air → the pawn
-- stands behind the target, blade out → it sheathes the blade slowly; on the click every cut bursts and
-- the target falls apart. About 7.5 s (Settings.CUTSCENES.PawnPassant).

local TEAL = Color3.fromRGB(90, 230, 210)
local PASSANT_FLASH = 2.6
local KATANA_BLADE = 1.84 -- the blade's length in the model, guard to tip (studs, before scaling)

-- the katana (Blade, Guard, Grip) and its scabbard, both pivoting on the centre of the guard,
-- blade towards -Z, edge down (-Y); part stand-ins if the props weren't built in this place
local function makeKatana(parent, scale)
	local props = ReplicatedStorage:FindFirstChild("CutsceneProps")
	local function stand(name, list)
		local m = Instance.new("Model")
		m.Name = name
		for _, s in list do
			local p = Instance.new("Part")
			p.Name, p.Size, p.CFrame, p.Color = s[1], s[2], CFrame.new(s[3]), s[4]
			p.Material = Enum.Material.Metal
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
			p.Parent = m
		end
		m.PrimaryPart = m:FindFirstChild("Root")
		m.PrimaryPart.Transparency = 1
		return m
	end
	local sword = props and props:FindFirstChild("Katana")
	sword = if sword then sword:Clone() else stand("Katana", {
		{ "Root", Vector3.one * 0.1, Vector3.zero, Color3.new() },
		{ "Blade", Vector3.new(0.04, 0.1, 1.74), Vector3.new(0, 0.02, -0.97), Color3.fromRGB(215, 220, 228) },
		{ "Guard", Vector3.new(0.23, 0.27, 0.04), Vector3.zero, Color3.fromRGB(205, 160, 60) },
		{ "Grip", Vector3.new(0.08, 0.1, 0.55), Vector3.new(0, 0, 0.33), Color3.fromRGB(28, 34, 70) },
	})
	local saya = props and props:FindFirstChild("Saya")
	saya = if saya then saya:Clone() else stand("Saya", {
		{ "Root", Vector3.one * 0.1, Vector3.zero, Color3.new() },
		{ "Saya", Vector3.new(0.09, 0.15, 1.84), Vector3.new(0, 0.03, -0.92), Color3.fromRGB(18, 18, 22) },
	})
	sword:ScaleTo(scale)
	saya:ScaleTo(scale)
	sword.Parent, saya.Parent = parent, parent
	return sword, saya
end

-- a katana frame with the blade pointing along `b` and the edge leading towards `edge`
local function bladeFrame(guard, b, edge)
	local z = -b.Unit
	local y = -(edge - z * edge:Dot(z)).Unit
	return CFrame.fromMatrix(guard, y:Cross(z), y, z)
end

-- a pixel-font mark over a piece that pops in (the target's "?")
local function popMark(folder, pos, text, color)
	local tag = Instance.new("Part")
	tag.Anchored, tag.CanCollide, tag.CanQuery, tag.CanTouch, tag.Transparency = true, false, false, false, 1
	tag.Size = Vector3.one * 0.1
	tag.CFrame = CFrame.new(pos)
	tag.Parent = folder
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(1, 1.2)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = tag
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Arcade
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Parent = bb
	animate(0.15, function(a)
		bb.Size = UDim2.fromScale(1 + 0.4 * (1 - a), 1.2 + 0.5 * (1 - a))
	end)
	return function()
		tag:Destroy()
	end
end

-- a slash mark hanging in the air: a flat teal arc in the plane of (along, up), centred on `at`
local function slashMark(folder, at, along, up, length, width)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(length, width, 0.02)
	p.CFrame = CFrame.fromMatrix(at, along.Unit, up.Unit)
	p.Parent = folder
	local decals = {}
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local d = Instance.new("Decal")
		d.Texture = TX.slash
		d.Color3 = TEAL
		d.Face = face
		d.Parent = p
		table.insert(decals, d)
	end
	-- and a thin white-hot line through it
	local line = fx(folder, Enum.PartType.Block, Vector3.new(length * 0.9, 0.04, 0.04), CFrame.fromMatrix(at, along.Unit, up.Unit), WHITE_HOT, 0)
	local o = { part = p, line = line }
	function o.burst(time)
		task.spawn(function()
			for _, d in decals do
				d.Color3 = WHITE_HOT
			end
			animate(time, function(a)
				p.Size = Vector3.new(length * (1 + 0.8 * a), width * (1 - a), 0.02)
				for _, d in decals do
					d.Transparency = a
				end
				line.Transparency = a
			end)
			p:Destroy()
			line:Destroy()
		end)
	end
	return o
end

-- a piece cut in two: two copies slide apart along `n` (one rising a little), tip over and fade
local function splitApart(folder, model, n, back)
	local start = model:GetPivot()
	local h = model:GetExtentsSize().Y
	for s = -1, 1, 2 do
		local copy = model:Clone()
		for _, p in copy:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored, p.CanCollide = true, false
			elseif p:IsA("Highlight") then
				p:Destroy()
			end
		end
		copy.Parent = folder
		local parts = partsOf(copy)
		local axis = n:Cross(UP).Unit * s
		task.spawn(function()
			animate(1.1, function(a)
				local k = 1 - (1 - a) ^ 2
				local slide = n * s * 0.45 * k - back * 0.2 * k + UP * (if s > 0 then 0.12 else 0) * math.sin(a * math.pi)
				copy:PivotTo(CFrame.new(start.Position + slide) * CFrame.fromAxisAngle(axis, math.rad(70) * a * a)
					* CFrame.new(0, -h * 0.15 * a * a, 0) * (start - start.Position))
				fade(parts, math.clamp((a - 0.55) / 0.45, 0, 1))
			end)
			copy:Destroy()
		end)
	end
end

scenes.PawnPassant = function(view, action, hits, opts, folder)
	local cam = opts.camera
	local gui = opts.gui
	local started = os.clock()
	local e = view:modelAt(action.from)
	local function snd(name, pos, o)
		return Sounds.play(name, if cam then nil else pos, o)
	end
	local function silhouettes(extra)
		local list = {}
		for _, m in view.models do
			table.insert(list, m.model)
		end
		for _, m in extra or {} do
			table.insert(list, m)
		end
		return list
	end
	if not (e and e.model.Parent) then
		task.wait(1)
		return
	end
	local avatar = if cam then Players.LocalPlayer.Character else nil
	if cam then
		hideLocal(avatar, true)
		VfxKit.bloom(true)
	end
	local pawn = e.model
	local rest = pawn:GetPivot()
	local spin = rest - rest.Position
	local h = pawn:GetExtentsSize().Y
	local p0 = view:squareCFrame(action.from).Position
	local p1 = view:squareCFrame(action.to).Position
	local tsq = hits[1]
	local pt = if tsq then view:squareCFrame(tsq).Position else p0:Lerp(p1, 0.5)
	local fwd = Vector3.new(p1.X - pt.X, 0, p1.Z - pt.Z)
	fwd = if fwd.Magnitude > 0.01 then fwd.Unit else Vector3.zAxis
	local side = Vector3.new(pt.X - p0.X, 0, pt.Z - p0.Z)
	side = if side.Magnitude > 0.01 then side.Unit else fwd:Cross(UP).Unit
	local victim = nil
	for _, m in view.models do
		if m ~= e and m.sq == tsq then
			victim = m
		end
	end
	local th = if victim and victim.model.Parent then victim.model:GetExtentsSize().Y else h
	local cutAt = pt + UP * th * 0.5
	local unAura = VfxKit.aura(pawn, TEAL)

	-- the katana, sheathed, floats at the pawn's hip on the far side from the target, handle forward
	local ks = math.clamp(h * 1.25 / 2.45, 0.3, 0.9)
	local blade = KATANA_BLADE * ks
	local sword, saya = makeKatana(folder, ks)
	local function hipAt(at)
		local hip = at - side * view.size * 0.38 + UP * h * 0.42
		return CFrame.lookAt(hip, hip - fwd) * CFrame.Angles(math.rad(-8), 0, 0) -- the grip a touch up
	end
	local hip0 = hipAt(p0)
	sword:PivotTo(hip0 + UP * 4)
	saya:PivotTo(hip0 + UP * 4)

	-- LOCK-ON ------------------------------------------------------------------------------------------
	local both = (p0 + pt) / 2 + UP * h * 0.5
	if cam then
		CameraRig.override(CFrame.lookAt(p0 - fwd * 3.4 - side * 1.5 + UP * 1.0, both), 50)
		task.delay(0.05, function()
			CameraRig.override(CFrame.lookAt(p0 - fwd * 2.7 - side * 1.2 + UP * 0.8, both), 45, 1.2)
		end)
	end
	snd("braam", p0, { fadeAfter = 2.2, fadeTime = 0.6 })
	snd("riser", p0, { timePosition = 4.0 - PASSANT_FLASH })
	local stopCharge = VfxKit.charge(folder, p0 + UP * 0.3, TEAL, 1.2)
	-- the sword drops in
	animate(0.25, function(a)
		local k = a * a
		sword:PivotTo(hip0 + UP * 4 * (1 - k))
		saya:PivotTo(hip0 + UP * 4 * (1 - k))
	end)
	sword:PivotTo(hip0)
	saya:PivotTo(hip0)
	snd("stomp", p0, { volume = 0.5 })
	VfxKit.shockwave(folder, CFrame.new(p0 + UP * 0.06), TEAL, view.size * 2.2, 0.4)
	VfxKit.sparks(folder, CFrame.lookAt(hip0.Position, hip0.Position + UP), TEAL, 14, 8, 60)
	local unSwordAura = VfxKit.aura(sword, TEAL)
	task.wait(0.3)
	-- the target hasn't noticed
	local unQuestion = popMark(folder, pt + UP * (th + 0.45), "?", Color3.fromRGB(230, 230, 230))
	task.wait(0.4)
	-- close on the guard: the thumb pushes the blade an inch out, a glint runs up it
	if cam then
		local g = hip0.Position
		CameraRig.override(CFrame.lookAt(g - side * 1.5 + fwd * 0.6 + UP * 0.35, g - fwd * blade * 0.25), 40)
		task.delay(0.05, function()
			CameraRig.override(CFrame.lookAt(g - side * 1.2 + fwd * 0.45 + UP * 0.3, g - fwd * blade * 0.2), 34, 1.0)
		end)
	end
	snd("unsheath", p0, { volume = 0.6, fadeAfter = 0.4, fadeTime = 0.2 })
	animate(0.18, function(a)
		sword:PivotTo(hip0 * CFrame.new(0, 0, 0.09 * ks * 4 * ease(a)))
	end)
	task.spawn(function()
		-- the glint runs along the scabbard towards the tip
		for i = 0, 6 do
			VfxKit.flare(folder, hip0.Position + UP * 0.05 + hip0.LookVector * blade * i / 7, TX.star, WHITE_HOT, 0.15, 0.9, 0.12, 90)
			task.wait(0.05)
		end
	end)
	VfxKit.flare(folder, hip0.Position + UP * 0.05, TX.star, WHITE_HOT, 0.2, 2.0, 0.45, 90)
	-- the pawn sinks into its stance
	animate(0.6, function(a)
		pawn:PivotTo(CFrame.new(p0) * CFrame.fromAxisAngle(side:Cross(UP).Unit, -math.rad(8) * ease(a)) * spin)
	end)
	stopCharge()
	local flashAt = started + PASSANT_FLASH
	if os.clock() < flashAt then
		task.wait(flashAt - os.clock())
	end

	-- FLASH STEP ---------------------------------------------------------------------------------------
	snd("trailerHit", p0)
	snd("bladeRing", p0, { volume = 0.9 })
	unQuestion()
	-- gone: a teal line where it went, ghosts along it
	local a0, a1 = p0 + UP * h * 0.45, p1 + UP * h * 0.45
	for i = 1, 3 do
		pawn:PivotTo(CFrame.new(p0:Lerp(pt, i / 4)) * spin)
		afterimage(folder, pawn, TEAL, 0.3 + i * 0.08)
	end
	local line = fx(folder, Enum.PartType.Block, Vector3.new(0.06, 0.06, (a1 - a0).Magnitude + 1),
		CFrame.lookAt((a0 + a1) / 2, a1), WHITE_HOT, 0)
	TweenService:Create(line, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.01, 0.01, (a1 - a0).Magnitude + 1.6), Color = TEAL }):Play()
	fadeAndDestroy(line, 0.5)
	VfxKit.shockwave(folder, CFrame.new(p0 + UP * 0.06), TEAL, view.size * 2.4, 0.35)
	puff(folder, p0 + UP * 0.1, 8, Color3.fromRGB(215, 200, 175), 1.1, 2.5, 0.7)
	-- gone (hidden); the scabbard waits, hidden, at the landing square
	local pawnParts, swordParts, sayaParts = partsOf(pawn), partsOf(sword), partsOf(saya)
	local hip1 = hipAt(p1)
	fade(pawnParts, 1)
	fade(swordParts, 1)
	fade(sayaParts, 1)
	saya:PivotTo(hip1)
	if gui then
		VfxKit.speedLines(gui, 1.6, TEAL)
		task.wait(VfxKit.impactFrames(gui, silhouettes(), { "white", "invert", "manga" }, 0.06))
	end

	-- THE SLASHES --------------------------------------------------------------------------------------
	-- the target, frozen, from the front; the pawn flickers round it, a cut each time
	if cam then
		CameraRig.override(CFrame.lookAt(pt + fwd * 3.0 - side * 1.9 + UP * 1.3, cutAt), 50)
		task.delay(0.05, function()
			CameraRig.override(CFrame.lookAt(pt + fwd * 2.6 - side * 1.6 + UP * 1.1, cutAt), 46, 1.4)
		end)
	end
	local marks = {}
	local around = { -side, fwd, side, -fwd }
	local tilts = { 35, -50, 70, -20 }
	for i = 1, 4 do
		local dir = around[i]
		local q = pt + dir * view.size * 0.75
		local toT = -dir
		-- the swing plane: towards the target, tilted
		local up = CFrame.fromAxisAngle(toT, math.rad(tilts[i])):VectorToWorldSpace(UP)
		local guard = q + UP * h * 0.55
		pawn:PivotTo(CFrame.lookAt(q, q + toT) * spin)
		fade(pawnParts, 0)
		fade(swordParts, 0)
		afterimage(folder, pawn, TEAL, 0.35)
		snd("bladeRing", cutAt, { volume = 0.7, speed = 0.85 + i * 0.1 })
		-- the swing: from up and back, down through the target
		animate(0.09, function(a)
			local phi = math.rad(110 - 170 * a)
			local b = toT * math.cos(phi) + up * math.sin(phi)
			local edge = toT * math.sin(phi) - up * math.cos(phi)
			sword:PivotTo(bladeFrame(guard, b, edge))
			afterimage(folder, sword, TEAL, 0.22)
		end)
		local along = (toT - up * 0.4).Unit
		local n = toT:Cross(up).Unit
		table.insert(marks, slashMark(folder, cutAt, along, n:Cross(along).Unit, view.size * 2.2, view.size * 0.55))
		VfxKit.flare(folder, cutAt, TX.star, WHITE_HOT, 0.3, 1.8, 0.15, 60)
		VfxKit.sparks(folder, CFrame.lookAt(cutAt, cutAt + along), TEAL, 8, 9, 40)
		if cam then
			CameraRig.shake(0.18, 0.1)
		end
		fade(pawnParts, 1)
		fade(swordParts, 1)
		task.wait(0.14)
	end

	-- FOLLOW-THROUGH -----------------------------------------------------------------------------------
	-- it is behind the target, blade out low and to the side, its back to the target
	local land = view:squareCFrame(action.to, e.color)
	e.sq = action.to
	pawn:PivotTo(land)
	fade(pawnParts, 0)
	fade(swordParts, 0)
	fade(sayaParts, 0)
	local guardOut = p1 - side * view.size * 0.3 + fwd * 0.1 + UP * h * 0.5
	local outB = (fwd * 0.55 - side * 0.65 - UP * 0.35).Unit
	local outCf = bladeFrame(guardOut, outB, (-UP - fwd * 0.2).Unit)
	sword:PivotTo(outCf)
	snd("slowWhoosh", p1, { volume = 0.6 })
	VfxKit.shockwave(folder, CFrame.new(p1 + UP * 0.06), TEAL, view.size * 2.2, 0.35)
	puff(folder, p1 + UP * 0.1, 8, Color3.fromRGB(215, 200, 175), 1.1, 2.5, 0.7)
	if cam then
		local mid = (p1 + pt) / 2 + UP * h * 0.5
		CameraRig.override(CFrame.lookAt(p1 + fwd * 2.5 - side * 1.5 + UP * 0.6, mid), 46)
		task.delay(0.05, function()
			CameraRig.override(CFrame.lookAt(p1 + fwd * 2.1 - side * 1.25 + UP * 0.55, mid), 42, 1.4)
		end)
	end
	local hum = snd("heartbeat", pt, { volume = 0.45 })
	task.wait(0.45)

	-- SHEATHE ------------------------------------------------------------------------------------------
	-- the blade comes round to the scabbard's mouth, then slides home slowly
	local mouth = hip1 * CFrame.new(0, 0, blade * 0.98)
	local from = sword:GetPivot()
	animate(0.35, function(a)
		sword:PivotTo(from:Lerp(mouth, ease(a)))
	end)
	animate(0.6, function(a)
		local k = a * a * (3 - 2 * a)
		sword:PivotTo(hip1 * CFrame.new(0, 0, blade * 0.98 * (1 - k)))
	end)
	sword:PivotTo(hip1)

	-- CLICK --------------------------------------------------------------------------------------------
	snd("sheath", p1, { volume = 0.9 })
	if hum then
		Sounds.fade(hum, 0.1)
	end
	task.wait(0.22)
	for _, m in marks do
		m.burst(0.45)
	end
	if victim and victim.model.Parent then
		-- falls apart: the two halves slide off the cut either way and topple, then a few shards fly
		splitApart(folder, victim.model, side, fwd)
		debris(folder, cutAt, 14, firstColor(victim.model), Vector3.new(0.12, 0.12, 0.12), 8, false, if cam then fwd else nil)
		hideLocal(victim.model, true)
	end
	if tsq and opts.onHit then
		opts.onHit(tsq)
	end
	snd("cut", pt)
	snd("woodBreak", pt)
	snd("impactBoom", pt)
	VfxKit.shockwave(folder, CFrame.new(pt + UP * 0.06), TEAL, view.size * 3.2, 0.45)
	task.delay(0.05, VfxKit.shockwave, folder, CFrame.new(pt + UP * 0.07), WHITE_HOT, view.size * 2, 0.35)
	VfxKit.flare(folder, cutAt, TX.star, WHITE_HOT, 0.6, 3.8, 0.25, 30)
	VfxKit.sparks(folder, CFrame.lookAt(cutAt, cutAt + UP), TEAL, 26, 12, 80)
	VfxKit.decal(folder, CFrame.new(pt + UP * 0.03) * CFrame.Angles(0, math.random() * 6.28, 0), TX.crack,
		Color3.fromRGB(30, 50, 50), view.size * 1.2, 3)
	if cam then
		CameraRig.shake(0.5, 0.3)
	end
	if gui then
		task.wait(VfxKit.impactFrames(gui, silhouettes({ sword, saya }), { "invert", "manga", "invert", "red" }, 0.06))
	end

	-- SETTLE -------------------------------------------------------------------------------------------
	snd("rumble", pt, { fadeAfter = 1.0, fadeTime = 0.8 })
	puff(folder, pt + UP * 0.15, 10, Color3.fromRGB(215, 200, 175), 1.4, 2.5, 0.9)
	if cam then
		local centre = (p0 + p1 + pt) / 3
		CameraRig.override(CFrame.lookAt(centre - fwd * 4.5 - side * 4 + UP * 5, centre), 46, 1.0)
	end
	local total = Settings.cutscene("PawnPassant")
	task.wait(math.max(0, total - (os.clock() - started) - 1.4))
	-- the sword fades away in teal sparks
	unSwordAura()
	VfxKit.sparks(folder, CFrame.lookAt(hip1.Position, hip1.Position + UP), TEAL, 16, 5, 90)
	animate(0.5, function(a)
		fade(swordParts, a)
		fade(sayaParts, a)
	end)
	sword:Destroy()
	saya:Destroy()
	local left = total - (os.clock() - started) - 0.6
	if left > 0 then
		task.wait(left)
	end
	unAura()
	if cam then
		hideLocal(avatar, false)
		VfxKit.bloom(false)
	end
end

-- STEAL A PIECE ==========================================================================================
-- A heist: a red sigil locks onto the target ("!?"); gold chains shoot in from the stealer's side of the
-- board and bind it → yank: it's ripped into the air spinning (impact frames) → flip: its old colour
-- shatters off like glass and it's the stealer's colour → it drops back down, turned to face its new
-- side, "STOLEN!" stamped over it. About 8 s (Settings.CUTSCENES.StealPiece). The piece stays on its
-- square; the board redraws it in its new colour when the cutscene ends.

local STEAL_RED = Color3.fromRGB(235, 50, 60)
local STEAL_GOLD = Color3.fromRGB(255, 200, 61)
local STEAL_YANK = 2.6

-- a big pixel-font stamp over a piece that slams in from large (the "STOLEN!")
local function stamp(folder, pos, text, color, stroke)
	local tag = Instance.new("Part")
	tag.Anchored, tag.CanCollide, tag.CanQuery, tag.CanTouch, tag.Transparency = true, false, false, false, 1
	tag.Size = Vector3.one * 0.1
	tag.CFrame = CFrame.new(pos)
	tag.Parent = folder
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(4, 1.2)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = tag
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Arcade
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeColor3 = stroke
	label.TextStrokeTransparency = 0
	label.Rotation = -8
	label.Parent = bb
	animate(0.14, function(a)
		local k = 1 + 1.4 * (1 - a) ^ 2
		bb.Size = UDim2.fromScale(4 * k, 1.2 * k)
	end)
	return function(time)
		task.spawn(function()
			animate(time, function(a)
				label.TextTransparency = a
				label.TextStrokeTransparency = a
				tag.CFrame = CFrame.new(pos + UP * 0.4 * a)
			end)
			tag:Destroy()
		end)
	end
end

-- a gold chain of links from a towards b; set(a, b, shown) lays the links along the line, showing the
-- first `shown` fraction of it (it shoots out); fade(time) dissolves it
local function chain(folder, color)
	local LINK = 0.17
	local links = {}
	for i = 1, 60 do
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Size = Vector3.new(0.035, 0.11, 0.2)
		p.Material = Enum.Material.Metal
		p.Color = color
		p.Transparency = 1
		p.Parent = folder
		links[i] = p
	end
	local o = {}
	function o.set(a, b, shown)
		local d = b - a
		local len = d.Magnitude
		local n = math.min(#links, math.floor(len * (shown or 1) / LINK))
		local dir = if len > 0.01 then d.Unit else Vector3.yAxis
		local base = CFrame.lookAt(a, a + dir)
		for i, p in links do
			if i <= n then
				p.Transparency = 0
				p.CFrame = base * CFrame.new(0, 0, -(i - 0.5) * LINK) * CFrame.Angles(0, 0, if i % 2 == 0 then math.pi / 2 else 0)
			else
				p.Transparency = 1
			end
		end
	end
	function o.fade(time)
		task.spawn(function()
			local alive = {}
			for _, p in links do
				if p.Transparency < 1 then
					table.insert(alive, p)
				end
			end
			animate(time, function(a)
				for _, p in alive do
					p.Transparency = a
					p.Position += Vector3.new(0, -0.02, 0)
				end
			end)
			for _, p in links do
				p:Destroy()
			end
		end)
	end
	return o
end

scenes.StealPiece = function(view, action, hits, opts, folder)
	local cam = opts.camera
	local gui = opts.gui
	local started = os.clock()
	local e = view:modelAt(action.from)
	local function snd(name, pos, o)
		return Sounds.play(name, if cam then nil else pos, o)
	end
	local function silhouettes(extra)
		local list = {}
		for _, m in view.models do
			table.insert(list, m.model)
		end
		for _, m in extra or {} do
			table.insert(list, m)
		end
		return list
	end
	if not (e and e.model.Parent) then
		task.wait(1)
		return
	end
	local avatar = if cam then Players.LocalPlayer.Character else nil
	if cam then
		hideLocal(avatar, true)
		VfxKit.bloom(true)
	end
	local piece = e.model
	local rest = piece:GetPivot()
	local h = piece:GetExtentsSize().Y
	local pos = view:squareCFrame(action.from).Position
	local newColor = if e.color == "w" then "b" else "w"
	-- towards the stealer's side of the board (its back rank), along the piece's file
	local f = action.from % 16
	local toSide = view:squareCFrame(f).Position - view:squareCFrame(f + 7 * 16).Position
	toSide = Vector3.new(toSide.X, 0, toSide.Z).Unit * (if newColor == "w" then 1 else -1)
	local lat = toSide:Cross(UP).Unit
	local unMark = VfxKit.aura(piece, STEAL_RED)

	-- THE MARK -----------------------------------------------------------------------------------------
	-- low, from the stealer's side, looking up at the target
	local face = pos + UP * h * 0.65
	if cam then
		CameraRig.override(CFrame.lookAt(pos + toSide * 3.6 + lat * 0.8 + UP * 0.5, face), 50)
		task.delay(0.05, function()
			CameraRig.override(CFrame.lookAt(pos + toSide * 2.8 + lat * 0.6 + UP * 0.45, face), 44, 2.0)
		end)
	end
	snd("braam", pos, { fadeAfter = 2.2, fadeTime = 0.6 })
	snd("riser", pos, { timePosition = 4.0 - STEAL_YANK })
	-- a red sigil draws itself under it
	local outer = sigil(folder, pos + UP * 0.05, TX.ring, STEAL_RED, view.size * 2.2)
	local inner = sigil(folder, pos + UP * 0.06, TX.star, STEAL_GOLD, view.size * 1.3)
	task.spawn(function()
		animate(0.8, function(a)
			local k = ease(a)
			outer.set(0.3 + 0.7 * k, a * 2, 1 - 0.8 * k)
			inner.set(0.2 + 0.8 * k, -a * 3, 1 - 0.7 * k)
		end)
		while outer.part.Parent do
			local t = os.clock()
			outer.set(1, t * 1.5, 0.2)
			inner.set(1, -t * 2.2, 0.3)
			RunService.RenderStepped:Wait()
		end
	end)
	snd("magic", pos, { volume = 0.5 })
	local stopCharge = VfxKit.charge(folder, pos + UP * 0.3, STEAL_RED, 1.3)
	task.wait(0.5)
	-- it notices
	local unNotice = popMark(folder, pos + UP * (h + 0.45), "!?", STEAL_RED)
	snd("dodge", pos, { volume = 0.5, speed = 0.8 })
	task.wait(0.4)
	-- gold chains shoot in from the stealer's side and bind it
	if cam then
		CameraRig.override(CFrame.lookAt(pos + toSide * 4.2 + lat * 2.2 + UP * 1.8, pos + UP * h * 0.5), 50, 0.5)
	end
	snd("chains", pos, { volume = 0.9 })
	local chains = {}
	local anchors = {}
	for i = -1, 1 do
		table.insert(anchors, pos + toSide * view.size * 4.5 + lat * view.size * 1.6 * i + UP * (2.6 + math.abs(i) * 0.6))
	end
	local hold = { -0.35, 0.55, 0.15 }
	for i, a in anchors do
		local c = chain(folder, STEAL_GOLD)
		table.insert(chains, c)
		task.spawn(function()
			local target = pos + UP * h * (0.5 + hold[i] * 0.4)
			animate(0.22, function(k)
				c.set(a, target, k)
			end)
			VfxKit.flare(folder, target, TX.star, STEAL_GOLD, 0.2, 1.4, 0.2, 40)
			VfxKit.sparks(folder, CFrame.lookAt(target, a), STEAL_GOLD, 8, 7, 50)
		end)
		task.wait(0.12)
	end
	task.wait(0.15)
	snd("stomp", pos, { volume = 0.5 })
	if cam then
		CameraRig.shake(0.2, 0.15)
	end
	-- it strains against them
	animate(0.5, function(a)
		local shake = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 0.06
		piece:PivotTo(rest + shake + UP * 0.05 * a)
	end)
	piece:PivotTo(rest)
	stopCharge()
	local yankAt = started + STEAL_YANK
	if os.clock() < yankAt then
		task.wait(yankAt - os.clock())
	end

	-- THE YANK -----------------------------------------------------------------------------------------
	unNotice()
	snd("trailerHit", pos)
	snd("chains", pos, { volume = 1, speed = 1.3 })
	snd("rush", pos, { volume = 0.6 })
	if gui then
		task.wait(VfxKit.impactFrames(gui, silhouettes(), { "white", "invert", "manga" }, 0.06))
	end
	VfxKit.shockwave(folder, CFrame.new(pos + UP * 0.06), STEAL_GOLD, view.size * 3, 0.45)
	puff(folder, pos + UP * 0.1, 10, Color3.fromRGB(215, 200, 175), 1.3, 3, 0.8)
	if cam then
		CameraRig.override(CFrame.lookAt(pos + toSide * 4.4 + lat * 1.6 + UP * 2.4, pos + UP * (h * 0.5 + 1.6)), 52, 0.3)
	end
	local up = 1.7
	animate(0.7, function(a)
		local k = 1 - (1 - a) ^ 3
		local at = rest + UP * up * k
		piece:PivotTo(CFrame.new(at.Position) * CFrame.Angles(0, k * math.pi * 3, math.sin(a * 9) * 0.15 * (1 - a)) * (rest - rest.Position))
		for i, c in chains do
			c.set(anchors[i], at.Position + UP * h * (0.5 + hold[i] * 0.4))
		end
		if math.random() < 0.4 then
			afterimage(folder, piece, STEAL_GOLD, 0.3)
		end
	end)

	-- THE FLIP -----------------------------------------------------------------------------------------
	local high = piece:GetPivot()
	local mid = high.Position + UP * h * 0.5
	snd("glassBreak", mid, { volume = 0.9 })
	snd("impactBoom", mid)
	-- its old colour shatters off; underneath, it's the stealer's
	local old = firstColor(piece)
	unMark()
	local stolen = Pieces.build(e.type, newColor)
	for _, p in stolen:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		end
	end
	stolen:PivotTo(high)
	stolen.Parent = folder
	hideLocal(piece, true)
	local unGold = VfxKit.aura(stolen, STEAL_GOLD)
	debris(folder, mid, 22, old, Vector3.new(0.14, 0.14, 0.04), 10, false, if cam then toSide else nil)
	debris(folder, mid, 8, STEAL_RED, Vector3.new(0.1, 0.1, 0.03), 8, true, if cam then toSide else nil)
	VfxKit.flare(folder, mid, TX.star, WHITE_HOT, 0.6, 5, 0.3, 40)
	VfxKit.flare(folder, mid, TX.glow, STEAL_GOLD, 1, 4, 0.5)
	VfxKit.shockwave(folder, across(mid, toSide), STEAL_RED, view.size * 3.4, 0.45)
	task.delay(0.06, VfxKit.shockwave, folder, across(mid, toSide), STEAL_GOLD, view.size * 2.4, 0.35)
	-- the chains have done their job
	for i, c in chains do
		c.fade(0.4)
		VfxKit.sparks(folder, CFrame.lookAt(anchors[i], mid), STEAL_GOLD, 6, 6, 40)
	end
	if cam then
		CameraRig.shake(0.5, 0.3)
	end
	if gui then
		task.wait(VfxKit.impactFrames(gui, silhouettes({ stolen }), { "invert", "manga", "invert", "red" }, 0.06))
	end
	task.wait(0.3)

	-- THE DROP -----------------------------------------------------------------------------------------
	-- it comes down turning to face its new side
	local land = view:squareCFrame(action.from, newColor)
	if cam then
		CameraRig.override(CFrame.lookAt(pos + toSide * 4.0 + lat * 1.4 + UP * 1.4, pos + UP * h * 0.85), 50)
	end
	local fromCf = stolen:GetPivot()
	animate(0.22, function(a)
		local k = a * a
		stolen:PivotTo(fromCf:Lerp(land, k))
	end)
	stolen:PivotTo(land)
	outer.part:Destroy()
	inner.part:Destroy()
	snd("stomp", pos)
	snd("lowBoom", pos)
	snd("kaching", pos, { volume = 0.8 })
	VfxKit.shockwave(folder, CFrame.new(pos + UP * 0.06), STEAL_GOLD, view.size * 3.6, 0.5)
	task.delay(0.06, VfxKit.shockwave, folder, CFrame.new(pos + UP * 0.07), WHITE_HOT, view.size * 2.2, 0.35)
	VfxKit.sparks(folder, CFrame.lookAt(pos + UP * 0.1, pos + UP), STEAL_GOLD, 30, 14, 70)
	VfxKit.decal(folder, CFrame.new(pos + UP * 0.03) * CFrame.Angles(0, math.random() * 6.28, 0), TX.crack,
		Color3.fromRGB(60, 45, 20), view.size * 1.3, 3)
	puff(folder, pos + UP * 0.15, 12, Color3.fromRGB(255, 230, 170), 1.4, 3, 0.9)
	if cam then
		CameraRig.shake(0.4, 0.3)
	end
	local unStamp = stamp(folder, pos + UP * (h + 0.3), "STOLEN!", STEAL_GOLD, STEAL_RED)

	-- SETTLE -------------------------------------------------------------------------------------------
	motes(folder, pos, STEAL_GOLD, 1.8)
	snd("twinkle", pos, { volume = 0.5 })
	if cam then
		CameraRig.override(CFrame.lookAt(pos + toSide * 3.4 - lat * 1.5 + UP * 1.5, pos + UP * h * 0.85), 48, 1.6)
	end
	local total = Settings.cutscene("StealPiece")
	task.wait(math.max(0, total - (os.clock() - started) - 2.0))
	if cam then
		local c = view.center or pos
		CameraRig.override(CFrame.lookAt(pos + toSide * 5 + lat * 3 + UP * 5.5, pos:Lerp(c, 0.3)), 48, 0.9)
	end
	unStamp(0.8)
	local left = total - (os.clock() - started) - 0.6
	if left > 0 then
		task.wait(left)
	end
	unGold()
	if cam then
		hideLocal(avatar, false)
		VfxKit.bloom(false)
	end
end

function Cutscene.ability(view, id: string, action, info, opts)
	opts = opts or {}
	local scene = scenes[id]
	local started = os.clock()
	local folder = Instance.new("Folder")
	folder.Name = "AbilityFx"
	folder.Parent = view.folder
	local gui, show
	if opts.camera then
		local t = TITLES[id] or { id, Ui.T.white }
		gui, show = banner(t[1], t[2])
		show(true)
		opts.gui = gui
	end
	local function sound(name, pos)
		Sounds.play(name, if opts.camera then nil else pos)
	end
	if opts.camera then
		Music.duck(true) -- the scene's own sound design takes over
	end
	if scene then
		local ok, err = pcall(scene, view, action, info or {}, opts, folder, sound)
		if not ok then
			warn("[Cutscene] " .. id .. ": " .. tostring(err))
		end
	end
	-- hold the frame to the cutscene's full length (the opponent's clock is paused that long)
	local rest = Settings.cutscene(id) - (os.clock() - started) - 0.3
	if rest > 0 then
		task.wait(rest)
	end
	if opts.camera then
		Music.duck(false)
		show(false)
		CameraRig.override(nil)
		task.delay(0.4, function()
			gui:Destroy()
		end)
	end
	task.wait(0.3)
	folder:Destroy()
	if opts.done then
		opts.done()
	end
end

return Cutscene
