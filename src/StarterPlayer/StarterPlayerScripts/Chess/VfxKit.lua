-- Anime-style VFX for the cutscenes (client only). Textures are white on transparent and tinted here;
-- they come from art/vfx/make_textures.py, uploaded to Roblox (ids below). Every world effect goes in
-- the `folder` it's given (the cutscene destroys that folder when it ends) and cleans itself up.
--   VfxKit.shockwave(folder, cf, color, size, time)     a ring expanding in cf's XZ plane (normal = cf.UpVector)
--   VfxKit.decal(folder, cf, texture, color, size, time) a flat image (cracks) that fades out
--   VfxKit.flare(folder, pos, texture, color, from, to, time, spin?)  a camera-facing image that grows and fades
--   VfxKit.sparks(folder, cf, color, n, speed, spread?) streaks thrown along cf.LookVector (spread in degrees)
--   VfxKit.charge(folder, pos, color, radius) -> stop()  particles pulled into a point, a growing glow
--   VfxKit.beam(folder, a, b, color, width) -> beam      an energy beam; beam:set(a, b), beam:fade(time)
--   VfxKit.aura(model, color) -> remove()               a glowing outline and light on a model
--   VfxKit.impactFrame(style)                            1-2 frames of stark colour (screen only)
--   VfxKit.speedLines(gui, time, color)                  radial anime speed lines over the screen
--   VfxKit.bloom(on)                                     extra glow while a cutscene plays

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local VfxKit = {}

VfxKit.T = {
	glow = "rbxassetid://82691160738141",
	spark = "rbxassetid://117378380733640",
	star = "rbxassetid://109801804982851",
	ring = "rbxassetid://107633835755032",
	speedlines = "rbxassetid://124652061951785",
	crack = "rbxassetid://122255110321014",
	energy = "rbxassetid://113931135531505",
	slash = "rbxassetid://116610412023164",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
}
local T = VfxKit.T

local function anchor(folder, cf)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.one * 0.05
	p.CFrame = cf
	p.Parent = folder
	return p
end

local function later(t, inst)
	task.delay(t, function()
		if inst then
			inst:Destroy()
		end
	end)
end

-- a flat textured square (both faces) at cf, sized `size` studs
local function flat(folder, cf, texture, color, size, transparency)
	local p = anchor(folder, cf)
	p.Size = Vector3.new(size, 0.02, size)
	local decals = {}
	for _, face in { Enum.NormalId.Top, Enum.NormalId.Bottom } do
		local d = Instance.new("Decal")
		d.Texture = texture
		d.Color3 = color
		d.Transparency = transparency or 0
		d.Face = face
		d.Parent = p
		table.insert(decals, d)
	end
	return p, decals
end

function VfxKit.shockwave(folder, cf, color, size, time)
	time = time or 0.4
	local p, decals = flat(folder, cf, T.ring, color, size * 0.15, 0)
	local info = TweenInfo.new(time, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(p, info, { Size = Vector3.new(size, 0.02, size) }):Play()
	for _, d in decals do
		TweenService:Create(d, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	end
	later(time + 0.05, p)
end

function VfxKit.decal(folder, cf, texture, color, size, time)
	local p, decals = flat(folder, cf, texture, color, size, 0.05)
	for _, d in decals do
		TweenService:Create(d, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	end
	later(time + 0.05, p)
end

function VfxKit.flare(folder, pos, texture, color, from, to, time, spin)
	local p = anchor(folder, CFrame.new(pos))
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(from, from)
	bb.LightInfluence = 0
	bb.Brightness = 3
	bb.Parent = p
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = texture
	img.ImageColor3 = color
	img.Rotation = math.random(0, 360)
	img.Parent = bb
	local info = TweenInfo.new(time, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(bb, info, { Size = UDim2.fromScale(to, to) }):Play()
	TweenService:Create(img, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ ImageTransparency = 1, Rotation = img.Rotation + (spin or 0) }):Play()
	later(time + 0.05, p)
	return p
end

function VfxKit.sparks(folder, cf, color, n, speed, spread)
	local p = anchor(folder, cf)
	local e = Instance.new("ParticleEmitter")
	e.Texture = T.spark
	e.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	e.LightEmission = 1
	e.Brightness = 3
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.Drag = 4
	e.Lifetime = NumberRange.new(0.2, 0.45)
	e.SpreadAngle = Vector2.new(spread or 180, spread or 180)
	e.Acceleration = Vector3.new(0, -12, 0)
	e.Rate = 0
	e.EmissionDirection = Enum.NormalId.Front -- the part's front face: cf.LookVector
	e.Parent = p
	e:Emit(n)
	later(0.6, p)
end

function VfxKit.charge(folder, pos, color, radius)
	local p = anchor(folder, CFrame.new(pos))
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * radius * 2
	local e = Instance.new("ParticleEmitter")
	e.Texture = T.spark
	e.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	e.LightEmission = 1
	e.Brightness = 2
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) })
	e.Speed = NumberRange.new(radius * 2.2, radius * 2.8)
	e.Lifetime = NumberRange.new(0.32, 0.36)
	e.Rate = 70
	e.Parent = p
	-- the core glow grows while it charges
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(0.2, 0.2)
	bb.LightInfluence = 0
	bb.Brightness = 3
	bb.Parent = p
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = T.glow
	img.ImageColor3 = color
	img.Parent = bb
	TweenService:Create(bb, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromScale(radius * 1.4, radius * 1.4) }):Play()
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = radius * 4
	light.Brightness = 0
	light.Parent = p
	TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 4 }):Play()
	return function()
		e.Enabled = false
		TweenService:Create(img, TweenInfo.new(0.15), { ImageTransparency = 1 }):Play()
		TweenService:Create(light, TweenInfo.new(0.15), { Brightness = 0 }):Play()
		later(0.5, p)
	end
end

local Beam = {}
Beam.__index = Beam
function Beam:set(a, b)
	self.a0.WorldPosition = a
	self.a1.WorldPosition = b
end
function Beam:fade(time)
	local t0 = os.clock()
	local beam, w = self.beam, self.width
	task.spawn(function()
		while beam.Parent do
			local k = math.clamp((os.clock() - t0) / time, 0, 1)
			beam.Transparency = NumberSequence.new(k)
			beam.Width0, beam.Width1 = w * (1 + k), w * (1 - k)
			if k >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		self.part:Destroy()
	end)
end

function VfxKit.beam(folder, a, b, color, width)
	local p = anchor(folder, CFrame.new(a))
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = p, p
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Texture = T.energy
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = 3
	beam.TextureSpeed = 4
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Brightness = 3
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(color)
	beam.Width0, beam.Width1 = width, width
	beam.Segments = 1
	beam.Parent = p
	local self = setmetatable({ part = p, a0 = a0, a1 = a1, beam = beam, width = width }, Beam)
	self:set(a, b)
	return self
end

function VfxKit.aura(model, color)
	local h = Instance.new("Highlight")
	h.FillColor = color
	h.FillTransparency = 1 -- outline only (a fill tints white pieces)
	h.OutlineColor = color
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = model
	h.Parent = model
	local light
	local base = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if base then
		light = Instance.new("PointLight")
		light.Color = color
		light.Range = 6
		light.Brightness = 2
		light.Parent = base
	end
	return function()
		h:Destroy()
		if light then
			light:Destroy()
		end
	end
end

-- Impact frames: "flash" = a blown-out white-hot frame then a stark red one; "red" = one red frame.
-- Done with a ColorCorrection on Lighting, so it only touches this player's screen.
function VfxKit.impactFrame(style)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "ImpactFrame"
	cc.Parent = Lighting
	task.spawn(function()
		if style == "flash" then
			cc.Brightness, cc.Contrast, cc.Saturation, cc.TintColor = 0.45, 2.5, -1, Color3.new(1, 1, 1)
			task.wait(0.05)
		end
		cc.Brightness, cc.Contrast, cc.Saturation, cc.TintColor = -0.05, 3, -1, Color3.fromRGB(255, 70, 70)
		task.wait(0.06)
		cc:Destroy()
	end)
end

-- Manga impact frames: a burst of stark frames, each `dt` seconds (default 0.05). The key models are
-- redrawn as flat silhouettes in a ViewportFrame over the screen, from the current camera.
--   "invert" black screen, white silhouettes, white speed lines
--   "manga"  white screen, black silhouettes, black speed lines
--   "white"  the world blown out white-hot      "red"  the world in stark red and black
--   VfxKit.impactFrames(gui, { model, ... }, { "white", "invert", "manga", "red" }, dt?)
-- Returns how long the burst lasts (the caller holds the action that long: the hitstop).
function VfxKit.impactFrames(gui, models, pattern, dt)
	dt = dt or 0.05
	-- Studio only: workspace attribute ImpactFrameHold = seconds holds every frame that long (to inspect them)
	if RunService:IsStudio() and type(workspace:GetAttribute("ImpactFrameHold")) == "number" then
		dt = workspace:GetAttribute("ImpactFrameHold")
	end
	local cam = workspace.CurrentCamera
	local holder = Instance.new("Frame")
	holder.Name = "ImpactFrames"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BorderSizePixel = 0
	holder.ZIndex = 6
	holder.Visible = false
	holder.Parent = gui
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.fromScale(1, 1)
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.new(1, 1, 1)
	vp.LightColor = Color3.new(0, 0, 0) -- flat: no shading, just the shape
	vp.ZIndex = 7
	vp.Parent = holder
	local vcam = Instance.new("Camera")
	vcam.CFrame = cam.CFrame
	vcam.FieldOfView = cam.FieldOfView
	vcam.Parent = vp
	vp.CurrentCamera = vcam
	for _, m in models do
		if m and m.Parent then
			local ok, c = pcall(function()
				return m:Clone()
			end)
			if ok and c then
				for _, d in c:GetDescendants() do
					if d:IsA("BasePart") then
						d.Color = Color3.new(1, 1, 1)
						d.Material = Enum.Material.SmoothPlastic
						if d:IsA("MeshPart") then
							d.TextureID = ""
						end
						d.Transparency = if d.Transparency > 0.95 or d.Name == "Root" then 1 else 0
					elseif not (d:IsA("Model") or d:IsA("Folder") or d:IsA("DataModelMesh") or d:IsA("Attachment")) then
						d:Destroy()
					end
				end
				c.Parent = vp
			end
		end
	end
	local lines = Instance.new("ImageLabel")
	lines.AnchorPoint = Vector2.new(0.5, 0.5)
	lines.Position = UDim2.fromScale(0.5, 0.5)
	lines.Size = UDim2.fromScale(1.7, 1.7)
	lines.BackgroundTransparency = 1
	lines.Image = T.speedlines
	lines.ZIndex = 8
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.DominantAxis = Enum.DominantAxis.Width
	ratio.Parent = lines
	lines.Parent = holder
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "ImpactFrame"
	cc.Enabled = false
	cc.Parent = Lighting
	task.spawn(function()
		for _, kind in pattern do
			lines.Rotation = math.random(0, 360)
			if kind == "invert" or kind == "manga" then
				cc.Enabled = false
				holder.Visible = true
				local ink = if kind == "invert" then Color3.new(0, 0, 0) else Color3.new(1, 1, 1)
				local paper = if kind == "invert" then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
				holder.BackgroundColor3 = ink
				vp.ImageColor3 = paper
				lines.ImageColor3 = paper
			else
				holder.Visible = false
				cc.Enabled = true
				if kind == "white" then
					cc.Brightness, cc.Contrast, cc.Saturation, cc.TintColor = 0.5, 2.5, -1, Color3.new(1, 1, 1)
				else
					cc.Brightness, cc.Contrast, cc.Saturation, cc.TintColor = -0.05, 3, -1, Color3.fromRGB(255, 60, 60)
				end
			end
			task.wait(dt)
		end
		holder:Destroy()
		cc:Destroy()
	end)
	return #pattern * dt
end

function VfxKit.speedLines(gui, time, color)
	local img = Instance.new("ImageLabel")
	img.Name = "SpeedLines"
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.5, 0.5)
	img.Size = UDim2.fromScale(1.6, 1.6)
	img.BackgroundTransparency = 1
	img.Image = T.speedlines
	img.ImageColor3 = color or Color3.new(1, 1, 1)
	img.ImageTransparency = 0.15
	img.ZIndex = 4
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.DominantAxis = Enum.DominantAxis.Width
	ratio.Parent = img
	img.Parent = gui
	task.spawn(function()
		local t0 = os.clock()
		while img.Parent and os.clock() - t0 < time do
			img.Rotation = math.random(0, 360) -- re-drawn every frame, like hand-drawn lines
			img.ImageTransparency = 0.15 + 0.85 * ((os.clock() - t0) / time) ^ 2
			RunService.RenderStepped:Wait()
		end
		img:Destroy()
	end)
end

local bloom
function VfxKit.bloom(on)
	if on then
		if not bloom then
			bloom = Instance.new("BloomEffect")
			bloom.Name = "CutsceneBloom"
			bloom.Intensity = 0.9
			bloom.Size = 30
			bloom.Threshold = 0.9
			bloom.Parent = Lighting
		end
	elseif bloom then
		bloom:Destroy()
		bloom = nil
	end
end

return VfxKit
