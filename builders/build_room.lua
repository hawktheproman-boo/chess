-- Builds the lobby into workspace.Lobby (Edit mode): a sunny outdoor chess park. A pale stone
-- plaza on a lawn, hedges and trees around it, eight tables with green/cream boards. Re-runnable: it
-- replaces the previous build. Run: python tools/run_luau.py builders/build_room.lua
-- Then builders/build_decor.lua (the fountain, the stage, the leaderboards, lamps, flags: it needs
-- this build), then builders/check_zfighting.lua.
-- Plan (2026-10-20 makeover): spawn at the south (+Z) entrance, the leaderboards either side of the
-- path, the two table rows with the fountain between them, the tournament stage at the north end.
--
-- Layout contract used by the code (keep it if you restyle):
--   workspace.Lobby.Tables.<T1..T8> (Model, attribute TableId, ModelStreamingMode Persistent)
--     Top                      table top (PrimaryPart)
--     Board/<n>                64 square parts, attribute Square = 0x88 index; White sits at +Z
--     WhiteSeat / BlackSeat    Seat parts with a ProximityPrompt "SitPrompt" (attribute Color)
--   Squares are SQUARE studs wide; piece models stand on the square's top face. Parts named
--   Shade / Bulb / Cord are hidden for a seated player (none in this build).

local SQUARE = 1.4
local TABLE_Y = 3.4 -- table top surface
local SQ_H = 0.2
local PLAZA_X, PLAZA_Z = 190, 150

local old = workspace:FindFirstChild("Lobby")
if old then
	old:Destroy()
end
for _, name in { "Baseplate", "SpawnLocation" } do
	local d = workspace:FindFirstChild(name)
	if d then
		d:Destroy()
	end
end

local lobby = Instance.new("Model")
lobby.Name = "Lobby"

local C = {
	grass = Color3.fromRGB(108, 172, 78),
	hedge = Color3.fromRGB(70, 136, 60),
	plaza = Color3.fromRGB(236, 218, 184),
	tableTop = Color3.fromRGB(222, 188, 140),
	frame = Color3.fromRGB(70, 104, 56),
	light = Color3.fromRGB(238, 238, 210),
	dark = Color3.fromRGB(118, 150, 86),
	seat = Color3.fromRGB(106, 168, 79),
	white = Color3.fromRGB(248, 248, 246),
	trunk = Color3.fromRGB(122, 86, 58),
	leaves = Color3.fromRGB(96, 168, 70),
	soil = Color3.fromRGB(110, 82, 60),
}

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
	return p
end

-- Ground: lawn (top y = -0.3) with the plaza on it (top y = 0), so the plaza has a small curb.
local park = Instance.new("Folder")
park.Name = "Park"
park.Parent = lobby
part(park, "Lawn", Vector3.new(600, 1, 600), CFrame.new(0, -0.8, 0), C.grass, Enum.Material.Grass)
part(park, "Plaza", Vector3.new(PLAZA_X, 1, PLAZA_Z), CFrame.new(0, -0.5, 0), C.plaza, Enum.Material.Slate)

-- Hedges just outside the plaza, standing on the lawn, with an entrance on the +Z side.
local hx, hz, hh, ht = PLAZA_X / 2, PLAZA_Z / 2, 3.2, 2.4
local hedgeY = -0.3 + hh / 2
part(park, "HedgeN", Vector3.new(PLAZA_X + 2 * ht, hh, ht), CFrame.new(0, hedgeY, -hz - ht / 2), C.hedge, Enum.Material.LeafyGrass)
part(park, "HedgeW", Vector3.new(ht, hh, PLAZA_Z), CFrame.new(-hx - ht / 2, hedgeY, 0), C.hedge, Enum.Material.LeafyGrass)
part(park, "HedgeE", Vector3.new(ht, hh, PLAZA_Z), CFrame.new(hx + ht / 2, hedgeY, 0), C.hedge, Enum.Material.LeafyGrass)
local gap = 24
local sideLen = (PLAZA_X + 2 * ht - gap) / 2
part(park, "HedgeSW", Vector3.new(sideLen, hh, ht), CFrame.new(-(gap / 2 + sideLen / 2), hedgeY, hz + ht / 2), C.hedge, Enum.Material.LeafyGrass)
part(park, "HedgeSE", Vector3.new(sideLen, hh, ht), CFrame.new(gap / 2 + sideLen / 2, hedgeY, hz + ht / 2), C.hedge, Enum.Material.LeafyGrass)

-- Trees on the lawn around the park (round, friendly shapes)
local function tree(pos, scale)
	local m = Instance.new("Model")
	m.Name = "Tree"
	local h = 9 * scale
	part(m, "Trunk", Vector3.new(h, 1.6 * scale, 1.6 * scale), CFrame.new(pos + Vector3.new(0, -0.3 + h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		C.trunk, Enum.Material.Wood, { Shape = Enum.PartType.Cylinder })
	for _, b in { { Vector3.new(0, h + 1.5 * scale, 0), 9 }, { Vector3.new(2.6, h - 0.2, 1.2) * scale, 6.5 }, { Vector3.new(-2.4, h + 0.3, -1.4) * scale, 6.8 } } do
		part(m, "Leaves", Vector3.one * b[2] * scale, CFrame.new(pos + b[1]), C.leaves, Enum.Material.Grass, { Shape = Enum.PartType.Ball })
	end
	m.Parent = park
end
local trees = { -- on the lawn, outside the hedges (x beyond ±98, z beyond ±78)
	{ -110, -88, 1.1 }, { -60, -92, 0.95 }, { -12, -94, 1.15 }, { 36, -92, 1 }, { 84, -90, 1.1 }, { 116, -70, 1 },
	{ -114, -36, 1 }, { -112, 14, 1.15 }, { -114, 58, 1.05 }, { 114, -22, 1.05 }, { 112, 26, 1.1 }, { 116, 70, 0.95 },
	{ -96, 92, 1 }, { -46, 94, 1.1 }, { 44, 94, 0.95 }, { 94, 92, 1.1 },
}
for _, t in trees do
	tree(Vector3.new(t[1], 0, t[2]), t[3])
end

-- Flower planters at the plaza corners (stand on the plaza)
for _, sx in { -1, 1 } do
	for _, sz in { -1, 1 } do
		local base = Vector3.new(sx * (hx - 7), 0, sz * (hz - 7))
		part(park, "Planter", Vector3.new(6, 1.6, 6), CFrame.new(base + Vector3.new(0, 0.8, 0)), C.white)
		part(park, "Soil", Vector3.new(5, 0.2, 5), CFrame.new(base + Vector3.new(0, 1.7, 0)), C.soil, Enum.Material.Ground)
		part(park, "Bush", Vector3.one * 4.2, CFrame.new(base + Vector3.new(0, 3.3, 0)), C.leaves, Enum.Material.Grass, { Shape = Enum.PartType.Ball })
	end
end

local spawn = Instance.new("SpawnLocation")
spawn.Name = "Spawn"
spawn.Anchored = true
spawn.Size = Vector3.new(10, 0.2, 10)
spawn.CFrame = CFrame.new(0, 0.1, hz - 9)
spawn.Color = C.seat
spawn.Material = Enum.Material.SmoothPlastic
spawn.Neutral = true
spawn.Duration = 0
spawn.TopSurface = Enum.SurfaceType.Smooth
spawn.Parent = park

-- Tables --------------------------------------------------------------------------------------------
local tables = Instance.new("Folder")
tables.Name = "Tables"
tables.Parent = lobby

local function addPrompt(seat, color, label)
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "SitPrompt"
	pr.ActionText = if color == "w" then "Play White" else "Play Black"
	pr.ObjectText = label
	pr.KeyboardKeyCode = Enum.KeyCode.E
	pr.GamepadKeyCode = Enum.KeyCode.ButtonX
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 9
	pr.RequiresLineOfSight = false
	pr:SetAttribute("Color", color)
	pr.Parent = seat
end

local function chair(model, name, center, facing, color, label)
	-- facing: +1 = chair at +Z looking toward -Z (White); -1 = at -Z looking toward +Z (Black)
	local rot = if facing == 1 then CFrame.new() else CFrame.Angles(0, math.pi, 0)
	local base = CFrame.new(center) * rot
	local seat = Instance.new("Seat")
	seat.Name = name
	seat.Anchored = true
	seat.Size = Vector3.new(3, 0.6, 3)
	seat.CFrame = base * CFrame.new(0, 1.9, 0) -- seat spans y 1.6 .. 2.2
	seat.Color = C.seat
	seat.Material = Enum.Material.SmoothPlastic
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.Parent = model
	addPrompt(seat, color, label)
	for _, o in { Vector3.new(-1.2, 0, -1.2), Vector3.new(1.2, 0, -1.2), Vector3.new(-1.2, 0, 1.2), Vector3.new(1.2, 0, 1.2) } do
		part(model, name .. "Leg", Vector3.new(0.4, 1.6, 0.4), base * CFrame.new(o.X, 0.8, o.Z), C.white)
	end
	part(model, name .. "Back", Vector3.new(3, 3.4, 0.4), base * CFrame.new(0, 1.6 + 1.7, 1.7), C.white)
	return seat
end

-- eight tables (a tournament round of 16 plays 8 games). The middle gap (x ±19.5, z ±12) holds the
-- fountain (build_decor).
local cols, rows = { -63, -27, 27, 63 }, { -24, 24 }
local n = 0
for _, z in rows do
	for _, x in cols do
		n += 1
		local id = "T" .. n
		local label = "Table " .. n
		local m = Instance.new("Model")
		m.Name = id
		m:SetAttribute("TableId", id)
		m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- clients need every board, near or far
		local c = Vector3.new(x, 0, z)

		local top = part(m, "Top", Vector3.new(15, 0.8, 15), CFrame.new(c + Vector3.new(0, TABLE_Y - 0.4, 0)), C.tableTop, Enum.Material.Wood)
		m.PrimaryPart = top
		local legH = TABLE_Y - 0.8
		for _, o in { Vector3.new(-6.3, 0, -6.3), Vector3.new(6.3, 0, -6.3), Vector3.new(-6.3, 0, 6.3), Vector3.new(6.3, 0, 6.3) } do
			part(m, "Leg", Vector3.new(1, legH, 1), CFrame.new(c + o + Vector3.new(0, legH / 2, 0)), C.white)
		end

		-- board: 64 squares standing on the top, frame around them (touching, never overlapping)
		local board = Instance.new("Folder")
		board.Name = "Board"
		board.Parent = m
		for rank = 0, 7 do
			for file = 0, 7 do
				local sqIndex = rank * 16 + file
				local light = (file + rank) % 2 == 1
				local p = part(board, tostring(sqIndex), Vector3.new(SQUARE, SQ_H, SQUARE),
					CFrame.new(c + Vector3.new((file - 3.5) * SQUARE, TABLE_Y + SQ_H / 2, (3.5 - rank) * SQUARE)),
					if light then C.light else C.dark)
				p:SetAttribute("Square", sqIndex)
			end
		end
		local half = 4 * SQUARE
		local fw, fh = 0.8, 0.35
		part(m, "FrameS", Vector3.new(2 * half + 2 * fw, fh, fw), CFrame.new(c + Vector3.new(0, TABLE_Y + fh / 2, half + fw / 2)), C.frame)
		part(m, "FrameN", Vector3.new(2 * half + 2 * fw, fh, fw), CFrame.new(c + Vector3.new(0, TABLE_Y + fh / 2, -half - fw / 2)), C.frame)
		part(m, "FrameW", Vector3.new(fw, fh, 2 * half), CFrame.new(c + Vector3.new(-half - fw / 2, TABLE_Y + fh / 2, 0)), C.frame)
		part(m, "FrameE", Vector3.new(fw, fh, 2 * half), CFrame.new(c + Vector3.new(half + fw / 2, TABLE_Y + fh / 2, 0)), C.frame)

		chair(m, "WhiteSeat", c + Vector3.new(0, 0, 10), 1, "w", label)
		chair(m, "BlackSeat", c + Vector3.new(0, 0, -10), -1, "b", label)

		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "WhiteSeat" and d.Name ~= "BlackSeat" and d.Parent ~= board then
				d.CanQuery = d.Name == "Top" -- keep raycasts for the board simple
			end
		end
		m.Parent = tables
	end
end

lobby.Parent = workspace

-- Lighting: bright, clear early afternoon
local L = game:GetService("Lighting")
L.ClockTime = 13.5
L.Brightness = 2.2
L.Ambient = Color3.fromRGB(118, 118, 124)
L.OutdoorAmbient = Color3.fromRGB(122, 122, 132)
L.EnvironmentDiffuseScale = 1
L.EnvironmentSpecularScale = 0.6
L.ShadowSoftness = 0.3
L.GlobalShadows = true
L.ExposureCompensation = -0.2
for _, e in L:GetChildren() do
	if e:IsA("DepthOfFieldEffect") then
		e.Enabled = false
	elseif e:IsA("SunRaysEffect") then
		e.Enabled = true
		e.Intensity = 0.04
		e.Spread = 0.6
	elseif e:IsA("Atmosphere") then
		e.Density = 0.26
		e.Offset = 0
		e.Color = Color3.fromRGB(199, 220, 255)
		e.Decay = Color3.fromRGB(110, 140, 180)
		e.Glare = 0
		e.Haze = 1
	elseif e:IsA("BloomEffect") then
		e.Intensity = 0.15
		e.Threshold = 2.4
		e.Size = 18
	end
end

return "built " .. n .. " tables"
