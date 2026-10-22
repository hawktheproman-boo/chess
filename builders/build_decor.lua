-- Builds the lobby decor into workspace.Lobby.Decor (Edit mode), after builders/build_room.lua:
-- the paths, the fountain with a giant king, the tournament stage and its screen, the two
-- leaderboards by the spawn, lamp posts, flags, audience benches and flower beds. Re-runnable: it
-- replaces the previous Decor. Run: python tools/run_luau.py builders/build_decor.lua
-- Then: python tools/run_luau.py builders/check_zfighting.lua
--
-- Contract used by the code (keep it if you restyle):
--   Decor.Leaderboards.Wins.Screen / Decor.Leaderboards.Titles.Screen  readable face = Front, 12 x 15
--       (Tables/LobbyBoards draws them on the server)
--   Decor.Stage.Screen  readable face = Front (Chess/StageScreen draws it on each client)
--   (Fountain, Stage and Flags are Persistent models: the clients need them from the start)
--   Decor.Flags.<Flag>  Parts with attribute Hinge (Vector3, the top of the pole): LobbyAmbience
--       sways them around it
--   Decor.Fountain.Sparkle  an anchor with the fountain's particle emitters
-- Everything stands slightly into the ground (bottoms at y = -0.2): no face is ever coplanar with
-- the plaza top (y = 0) or with another part's face.

local lobby = workspace:FindFirstChild("Lobby")
assert(lobby, "run builders/build_room.lua first")
local old = lobby:FindFirstChild("Decor")
if old then
	old:Destroy()
end
local decor = Instance.new("Folder")
decor.Name = "Decor"

local rgb = Color3.fromRGB
local C = {
	path = rgb(206, 186, 152),
	stone = rgb(242, 238, 228),
	stoneDark = rgb(196, 188, 172),
	water = rgb(90, 176, 230),
	gold = rgb(240, 186, 60),
	navy = rgb(32, 42, 82),
	navyDark = rgb(22, 28, 56),
	screen = rgb(14, 16, 26),
	pole = rgb(52, 58, 66),
	lamp = rgb(255, 226, 160),
	wood = rgb(160, 112, 70),
	soil = rgb(110, 82, 60),
	leaves = rgb(96, 168, 70),
	hedge = rgb(70, 136, 60),
	flagA = rgb(64, 168, 90), -- the HUD's green
	flagB = rgb(250, 250, 246),
}
local UP = Vector3.yAxis
local G = -0.2 -- every part's bottom

local count = 0
local function part(parent, name, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props or {} do
		p[k] = v
	end
	p.Parent = parent
	count += 1
	return p
end

-- a standing cylinder: centre x/z, bottom and top y
local function column(parent, name, x, z, radius, bottom, top, color, material, props)
	return part(parent, name, Vector3.new(top - bottom, radius * 2, radius * 2),
		CFrame.new(x, (bottom + top) / 2, z) * CFrame.Angles(0, 0, math.pi / 2), color, material,
		(function()
			local t = props or {}
			t.Shape = Enum.PartType.Cylinder
			return t
		end)())
end

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or decor
	return f
end

local function model(name, parent, persistent)
	local m = Instance.new("Model")
	m.Name = name
	if persistent then
		m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- the client code needs it from the start
	end
	m.Parent = parent or decor
	return m
end

-- Paths ---------------------------------------------------------------------------------------------
-- a warm stone path from the spawn to the stage, round the fountain, and east-west between the rows.
-- 0.12 thick, centred on the plaza top, so its faces sit at ±0.06 (never coplanar with the plaza).
local paths = folder("Paths")
local PT = 0.12
part(paths, "South", Vector3.new(12, PT, 62), CFrame.new(0, 0, 12.5 + 62 / 2), C.path, Enum.Material.Pavement)
part(paths, "North", Vector3.new(12, PT, 37.5), CFrame.new(0, 0, -12.5 - 37.5 / 2), C.path, Enum.Material.Pavement)
part(paths, "West", Vector3.new(82, PT, 8), CFrame.new(-12.5 - 82 / 2, 0, 0), C.path, Enum.Material.Pavement)
part(paths, "East", Vector3.new(82, PT, 8), CFrame.new(12.5 + 82 / 2, 0, 0), C.path, Enum.Material.Pavement)
part(paths, "Round", Vector3.new(PT, 26, 26), CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.pi / 2), C.path, Enum.Material.Pavement,
	{ Shape = Enum.PartType.Cylinder })

-- The fountain and the giant king --------------------------------------------------------------------
local fountain = model("Fountain", nil, true)
local R = 9.6 -- the basin's outer radius (the gap between the table rows is ±12)
column(fountain, "Basin", 0, 0, R, G, 0.5, C.stoneDark, Enum.Material.Limestone)
local N = 32
for i = 0, N - 1 do
	-- the rim: 32 blocks round a circle; alternate ones are 0.02 taller so the small overlaps between
	-- neighbours never share a top face
	local a = i / N * math.pi * 2
	local top = if i % 2 == 0 then 1.8 else 1.82
	local len = 2 * (R - 0.5) * math.sin(math.pi / N) + 0.12
	part(fountain, "Rim", Vector3.new(len, top - G, 1), CFrame.new(math.sin(a) * (R - 0.5), (G + top) / 2, math.cos(a) * (R - 0.5)) * CFrame.Angles(0, a, 0),
		C.stone, Enum.Material.Limestone)
end
column(fountain, "Water", 0, 0, R - 0.9, 0.4, 1.25, C.water, Enum.Material.Glass,
	{ Transparency = 0.25, Reflectance = 0.15, CanCollide = false })
column(fountain, "Plinth", 0, 0, 3.4, G, 3.4, C.stone, Enum.Material.Marble)
column(fountain, "PlinthTrim", 0, 0, 3.55, 3.0, 3.6, C.gold, Enum.Material.Metal)
column(fountain, "PlinthTop", 0, 0, 2.6, 3.4, 4.6, C.stone, Enum.Material.Marble)

-- the Classic set's king, 8 times life size (a stand-in column if the piece sets aren't in this place)
local sets = game:GetService("ReplicatedStorage"):FindFirstChild("PieceSets")
local kingSrc = sets and sets:FindFirstChild("Classic") and sets.Classic:FindFirstChild("k")
local KING_SCALE = 8
if kingSrc then
	local king = kingSrc:Clone()
	king.Name = "King"
	king.Anchored = true
	king.Size = kingSrc.Size * KING_SCALE
	king.CFrame = CFrame.new(0, 4.6 + king.Size.Y / 2 - 0.05, 0) * CFrame.Angles(0, math.pi, 0) -- facing the spawn
	king.Color = rgb(250, 250, 247)
	king.Material = Enum.Material.Marble
	king.Parent = fountain
	count += 1
else
	column(fountain, "King", 0, 0, 3, 4.55, 20, rgb(250, 250, 247), Enum.Material.Marble)
end

-- the jets and sparkles: an invisible anchor with the emitters
local sparkle = part(fountain, "Sparkle", Vector3.one * 0.2, CFrame.new(0, 3.7, 0), C.water, Enum.Material.SmoothPlastic,
	{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
for i = 0, 3 do
	local a = i / 4 * math.pi * 2 + math.pi / 4
	local at = Instance.new("Attachment")
	at.Name = "Jet"
	at.Position = Vector3.new(math.sin(a) * 3.3, 0, math.cos(a) * 3.3)
	at.Orientation = Vector3.new(0, math.deg(a), -35) -- tipped outwards
	at.Parent = sparkle
	local jet = Instance.new("ParticleEmitter")
	jet.Name = "Jet"
	jet.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	jet.Color = ColorSequence.new(rgb(200, 236, 255))
	jet.LightEmission = 0.4
	jet.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.25) })
	jet.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.7) })
	jet.Lifetime = NumberRange.new(0.9, 1.1)
	jet.Rate = 45
	jet.Speed = NumberRange.new(11, 12)
	jet.SpreadAngle = Vector2.new(4, 4)
	jet.Acceleration = Vector3.new(0, -26, 0)
	jet.EmissionDirection = Enum.NormalId.Top
	jet.Parent = at
end
local glints = Instance.new("ParticleEmitter")
glints.Name = "Glints"
glints.Texture = "rbxasset://textures/particles/sparkles_main.dds"
glints.Color = ColorSequence.new(rgb(255, 226, 140))
glints.LightEmission = 1
glints.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 0) })
glints.Lifetime = NumberRange.new(2, 3)
glints.Rate = 4
glints.Speed = NumberRange.new(0.5, 1.5)
glints.SpreadAngle = Vector2.new(180, 180)
glints.Shape = Enum.ParticleEmitterShape.Cylinder
glints.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
glints.Parent = sparkle
local glow = Instance.new("PointLight")
glow.Color = rgb(150, 210, 255)
glow.Range = 14
glow.Brightness = 0.8
glow.Parent = sparkle

-- The tournament stage (north end) ------------------------------------------------------------------
local stage = model("Stage", nil, true)
local SZ0, SZ1 = -66.5, -50 -- back and front edges
local SW = 48
local SH = 2.4
part(stage, "Floor", Vector3.new(SW, SH - G, SZ1 - SZ0), CFrame.new(0, (G + SH) / 2, (SZ0 + SZ1) / 2), C.navy, Enum.Material.WoodPlanks)
part(stage, "TrimFront", Vector3.new(SW + 0.4, 0.4, 0.5), CFrame.new(0, SH + 0.1, SZ1 + 0.05), C.gold, Enum.Material.Metal)
for _, sx in { -1, 1 } do
	part(stage, "TrimSide", Vector3.new(0.5, 0.4, SZ1 - SZ0 - 0.6), CFrame.new(sx * (SW / 2 + 0.05), SH + 0.1, (SZ0 + SZ1 - 0.2) / 2), C.gold, Enum.Material.Metal)
end
-- steps up the front, their backs tucked 0.2 into the stage (each a little lower underground and
-- narrower than the one below, so no two share a face)
for k = 1, 2 do
	local depth = 2 * (3 - k)
	local bottom = G - 0.1 * k
	local tuck = 0.1 + 0.1 * k
	part(stage, "Step", Vector3.new(16.4 - 0.4 * k, 0.8 * k - bottom, depth + tuck), CFrame.new(0, (bottom + 0.8 * k) / 2, SZ1 + (depth - tuck) / 2), C.navyDark, Enum.Material.WoodPlanks)
end
-- the backdrop wall, the screen in front of it, a gold frame round the screen
local WALL_Z = -66.9
part(stage, "Backdrop", Vector3.new(SW + 0.4, 22.3, 1.2), CFrame.new(0, -0.3 + 22.3 / 2, WALL_Z), C.navy, Enum.Material.SmoothPlastic)
part(stage, "BackdropCap", Vector3.new(SW + 0.8, 0.6, 1.6), CFrame.new(0, 22.0 + 0.25, WALL_Z), C.gold, Enum.Material.Metal)
local SCR_W, SCR_H, SCR_Y = 30, 13, 12 -- centre height
local scrZ = WALL_Z + 0.6 + 0.25 -- the wall's front face is at WALL_Z + 0.6
part(stage, "Screen", Vector3.new(SCR_W, SCR_H, 0.4), CFrame.new(0, SCR_Y, scrZ) * CFrame.Angles(0, math.pi, 0), C.screen, Enum.Material.SmoothPlastic)
local fz = scrZ + 0.12 -- the frame stands proud of the screen's face, overlapping its edges
part(stage, "FrameTop", Vector3.new(SCR_W + 1.8, 0.9, 0.6), CFrame.new(0, SCR_Y + SCR_H / 2 + 0.35, fz), C.gold, Enum.Material.Metal)
part(stage, "FrameBottom", Vector3.new(SCR_W + 1.8, 0.9, 0.6), CFrame.new(0, SCR_Y - SCR_H / 2 - 0.35, fz), C.gold, Enum.Material.Metal)
for _, sx in { -1, 1 } do
	part(stage, "FrameSide", Vector3.new(0.9, SCR_H + 0.1, 0.62), CFrame.new(sx * (SCR_W / 2 + 0.35), SCR_Y, fz), C.gold, Enum.Material.Metal)
end
-- two giant rooks guarding the stage corners (stand-in towers without the piece sets)
local rookSrc = sets and sets:FindFirstChild("Classic") and sets.Classic:FindFirstChild("r")
for _, sx in { -1, 1 } do
	local x, z = sx * (SW / 2 - 4), SZ0 + 6
	column(stage, "Pedestal", x, z, 2.6, SH - 0.1, SH + 1.0, C.gold, Enum.Material.Metal)
	if rookSrc then
		local rook = rookSrc:Clone()
		rook.Name = "Rook"
		rook.Anchored = true
		rook.Size = rookSrc.Size * 5
		rook.CFrame = CFrame.new(x, SH + 1.0 + rook.Size.Y / 2 - 0.05, z)
		rook.Color = rgb(74, 72, 70)
		rook.Material = Enum.Material.Marble
		rook.Parent = stage
		count += 1
	end
end
-- warm stage lights
for _, sx in { -1, 1 } do
	local l = part(stage, "LightRig", Vector3.one * 0.2, CFrame.new(sx * 10, 9, SZ1 - 2), C.gold, Enum.Material.SmoothPlastic,
		{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local s = Instance.new("SpotLight")
	s.Face = Enum.NormalId.Back
	s.Angle = 70
	s.Range = 22
	s.Brightness = 2
	s.Color = rgb(255, 230, 190)
	s.Parent = l
	l.CFrame = CFrame.lookAt(l.Position, Vector3.new(0, SCR_Y, scrZ)) * CFrame.Angles(0, math.pi, 0)
end

-- audience benches in front of the stage, facing it
local benches = folder("Benches")
local function bench(pos, facing)
	-- facing: the direction someone sitting looks
	local cf = CFrame.lookAt(pos, pos + facing)
	local m = model("Bench", benches)
	for _, ox in { -3.2, 3.2 } do
		part(m, "Leg", Vector3.new(0.5, 1.6 - G, 1.6), cf * CFrame.new(ox, (G + 1.6) / 2 - pos.Y, 0), C.pole, Enum.Material.Metal)
	end
	part(m, "Seat", Vector3.new(8, 0.35, 1.8), cf * CFrame.new(0, 1.75 - pos.Y, 0), C.wood, Enum.Material.Wood)
	part(m, "Back", Vector3.new(8, 1.4, 0.3), cf * CFrame.new(0, 2.75 - pos.Y, 0.95), C.wood, Enum.Material.Wood)
end
for _, z in { -44, -40 } do
	for _, x in { -11, 11 } do
		bench(Vector3.new(x, 0, z), Vector3.new(0, 0, -1))
	end
end

-- The leaderboards, either side of the spawn path, turned to face the spawn -------------------------
local boards = folder("Leaderboards")
local LB_W, LB_H, LB_BOTTOM = 12, 15, 2.6
for _, b in { { "Wins", -24, C.flagA }, { "Titles", 24, C.gold } } do
	local m = model(b[1], boards)
	local centre = Vector3.new(b[2], LB_BOTTOM + LB_H / 2, 56)
	local cf = CFrame.lookAt(centre, Vector3.new(0, centre.Y, 78)) -- Front faces the spawn
	part(m, "Screen", Vector3.new(LB_W, LB_H, 0.4), cf, C.screen, Enum.Material.SmoothPlastic)
	part(m, "Back", Vector3.new(LB_W + 1.2, LB_H + 1.2, 0.6), cf * CFrame.new(0, 0, 0.45), C.navy, Enum.Material.SmoothPlastic)
	part(m, "Crest", Vector3.new(LB_W + 1.6, 0.8, 0.9), cf * CFrame.new(0, LB_H / 2 + 0.9, 0.4), b[3], Enum.Material.Metal)
	local postH = LB_BOTTOM + LB_H + 1.4 - G
	for _, ox in { -1, 1 } do
		local p = cf * CFrame.new(ox * (LB_W / 2 + 0.95), 0, 0.45)
		part(m, "Post", Vector3.new(0.8, postH, 0.8), CFrame.new(p.Position.X, G + postH / 2, p.Position.Z) * cf.Rotation, C.pole, Enum.Material.Metal)
		part(m, "PostCap", Vector3.new(1.1, 0.5, 1.1), CFrame.new(p.Position.X, G + postH + 0.2, p.Position.Z) * cf.Rotation, b[3], Enum.Material.Metal)
	end
end

-- Planters along the spawn path, between it and the leaderboards: a clipped low hedge with topiary
-- balls (a formal garden look, no candy colours) --------------------------------------------------------
local beds = folder("FlowerBeds")
for _, sx in { -1, 1 } do
	local x = sx * 9
	part(beds, "Bed", Vector3.new(3, 0.9 - G, 20), CFrame.new(x, (G + 0.9) / 2, 52), C.stone, Enum.Material.Limestone)
	part(beds, "Soil", Vector3.new(2.4, 0.2, 19.4), CFrame.new(x, 0.95, 52), C.soil, Enum.Material.Ground)
	part(beds, "Hedge", Vector3.new(2, 1.1, 18.6), CFrame.new(x, 1.5, 52), C.hedge, Enum.Material.LeafyGrass)
	for i = 0, 3 do
		part(beds, "Topiary", Vector3.one * 2.1, CFrame.new(x, 2.55, 44.5 + i * 5), C.leaves, Enum.Material.Grass, { Shape = Enum.PartType.Ball })
	end
end

-- Lamp posts ------------------------------------------------------------------------------------------
local lamps = folder("Lamps")
local function lamp(x, z)
	local m = model("Lamp", lamps)
	column(m, "Base", x, z, 0.7, G, 0.8, C.pole, Enum.Material.Metal)
	column(m, "Pole", x, z, 0.25, 0.7, 9.2, C.pole, Enum.Material.Metal)
	column(m, "Cap", x, z, 0.75, 10.4, 10.7, C.pole, Enum.Material.Metal)
	local bulb = part(m, "Bulb", Vector3.one * 1.3, CFrame.new(x, 9.8, z), C.lamp, Enum.Material.Neon, { Shape = Enum.PartType.Ball })
	local l = Instance.new("PointLight")
	l.Color = C.lamp
	l.Range = 16
	l.Brightness = 0.9
	l.Shadows = false
	l.Parent = bulb
end
for _, p in {
	-- along the spawn path, and the north path to the stage
	{ -8, 30 }, { 8, 30 }, { -8, -30 }, { 8, -30 },
	-- round the fountain
	{ -14, -9 }, { 14, -9 }, { -14, 9 }, { 14, 9 },
	-- the east-west path ends and the plaza edges
	{ -88, -6 }, { 88, -6 }, { -88, 40 }, { 88, 40 }, { -88, -46 }, { 88, -46 },
	{ -45, 70 }, { 45, 70 }, { -45, -70 }, { 45, -70 },
} do
	lamp(p[1], p[2])
end

-- Flags: tall poles at the stage corners and the entrance; LobbyAmbience sways the flags ------------
local flags = model("Flags", nil, true)
local function flagPole(x, z, color, side)
	-- side: which way the flag hangs from the pole (+1 = +X)
	local top = 17
	column(flags, "FlagPole", x, z, 0.22, G, top, C.pole, Enum.Material.Metal)
	part(flags, "FlagFinial", Vector3.one * 0.7, CFrame.new(x, top + 0.3, z), C.gold, Enum.Material.Metal, { Shape = Enum.PartType.Ball })
	local w, h = 5.5, 3.4
	local f = part(flags, "Flag", Vector3.new(w, h, 0.12), CFrame.new(x + side * (w / 2 + 0.25), top - 0.4 - h / 2, z), color, Enum.Material.Fabric,
		{ CanCollide = false, CanQuery = false })
	f:SetAttribute("Hinge", Vector3.new(x, top - 0.4, z))
	local stripe = part(flags, "FlagStripe", Vector3.new(w + 0.02, 0.6, 0.16), f.CFrame * CFrame.new(0, 0, 0), C.gold, Enum.Material.Fabric,
		{ CanCollide = false, CanQuery = false })
	stripe:SetAttribute("Hinge", Vector3.new(x, top - 0.4, z))
end
flagPole(-SW / 2 - 3, SZ1 - 1, C.flagA, -1)
flagPole(SW / 2 + 3, SZ1 - 1, C.flagA, 1)
flagPole(-14, 70, C.flagB, -1)
flagPole(14, 70, C.flagB, 1)

decor.Parent = lobby
return "decor: " .. count .. " parts"
