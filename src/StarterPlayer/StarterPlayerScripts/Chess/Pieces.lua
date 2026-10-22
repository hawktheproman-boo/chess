-- Chess piece models. Piece sets (Settings.PIECE_SETS): Classic and Toon are Blender meshes
-- (ReplicatedStorage.PieceSets.<Set>.<kind>, one MeshPart each, made by art/pieces/make_sets.py and
-- builders/piece_sets.lua); Simple is the original set built from primitive parts below, and the
-- fallback whenever a mesh is missing. Each player picks their set (Pieces.setSet; it only changes
-- what they see). Built once per set/type/colour, cloned after. Every model's pivot is the centre of
-- its base's underside, and knights face -Z (White's forward); rotate Black's by 180 degrees.
-- Simple: stacked parts are embedded into each other (never share a face plane), so nothing z-fights.
--
--   Pieces.build(kind, color, set?) -> Model     (set defaults to Pieces.current)
--   Pieces.setSet(id) -> changed                 Pieces.current

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Settings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Settings"))

local Pieces = {}
Pieces.current = Settings.DEFAULT_PIECE_SET

-- mesh sets: colour and finish per side
local rgb = Color3.fromRGB
local MESH_LOOK = {
	Classic = {
		w = { color = rgb(238, 231, 214), reflectance = 0.02 }, -- ivory
		b = { color = rgb(52, 47, 44), reflectance = 0.07 }, -- ebony
	},
	Toon = { -- its own palette, so the set is obvious at a glance
		w = { color = rgb(255, 246, 222), reflectance = 0 }, -- warm cream
		b = { color = rgb(66, 58, 122), reflectance = 0 }, -- deep indigo
	},
}

-- High contrast on both square colours: bright white and a soft charcoal, with a subtle darker /
-- lighter trim instead of metal (readability over decoration).
local COLORS = {
	w = { color = Color3.fromRGB(250, 250, 247), reflectance = 0 },
	b = { color = Color3.fromRGB(74, 72, 70), reflectance = 0.04 },
}
local ACCENT = {
	w = Color3.fromRGB(206, 206, 198),
	b = Color3.fromRGB(42, 40, 38),
}
local SCALE = 1.08

local function newPart(model, shape, size, cf, color, colorKey)
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color or COLORS[colorKey].color
	p.Reflectance = COLORS[colorKey].reflectance
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- vertical cylinder: diameter d, height h, bottom at y
local function cyl(m, k, d, h, y, color)
	return newPart(m, Enum.PartType.Cylinder, Vector3.new(h, d, d), CFrame.new(0, y + h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), color, k)
end
local function ball(m, k, d, y, color)
	return newPart(m, Enum.PartType.Ball, Vector3.new(d, d, d), CFrame.new(0, y, 0), color, k)
end
local function block(m, k, size, cf, color)
	return newPart(m, Enum.PartType.Block, size, cf, color, k)
end
local function wedge(m, k, size, cf)
	local w = Instance.new("WedgePart")
	w.Size = size
	w.CFrame = cf
	w.Anchored = true
	w.CanCollide = false
	w.CanQuery = false
	w.CanTouch = false
	w.Material = Enum.Material.SmoothPlastic
	w.Color = COLORS[k].color
	w.Reflectance = COLORS[k].reflectance
	w.Parent = m
	return w
end

local function base(m, k, d)
	cyl(m, k, d, 0.16, 0)
	cyl(m, k, d * 0.92, 0.05, 0.14, ACCENT[k]) -- brass ring
	cyl(m, k, d * 0.8, 0.12, 0.17)
end

local BUILD = {}

function BUILD.p(m, k)
	base(m, k, 0.9)
	cyl(m, k, 0.5, 0.18, 0.26)
	cyl(m, k, 0.36, 0.36, 0.4)
	cyl(m, k, 0.56, 0.07, 0.72)
	ball(m, k, 0.46, 0.96)
end

function BUILD.r(m, k)
	base(m, k, 1.02)
	cyl(m, k, 0.66, 0.84, 0.26)
	cyl(m, k, 0.88, 0.26, 1.06)
	for i = 0, 3 do
		local a = math.rad(45 + 90 * i)
		block(m, k, Vector3.new(0.22, 0.2, 0.22), CFrame.new(math.cos(a) * 0.3, 1.39, math.sin(a) * 0.3) * CFrame.Angles(0, -a, 0))
	end
end

function BUILD.n(m, k)
	base(m, k, 1.02)
	cyl(m, k, 0.64, 0.4, 0.26)
	-- neck leaning forward (-Z), head reaching out, mane down the back, two ears
	block(m, k, Vector3.new(0.42, 0.86, 0.52), CFrame.new(0, 0.98, 0.04) * CFrame.Angles(math.rad(-14), 0, 0))
	block(m, k, Vector3.new(0.38, 0.34, 0.74), CFrame.new(0, 1.34, -0.2) * CFrame.Angles(math.rad(18), 0, 0))
	wedge(m, k, Vector3.new(0.38, 0.22, 0.3), CFrame.new(0, 1.2, -0.62) * CFrame.Angles(math.rad(18), 0, 0) * CFrame.Angles(0, math.pi, 0))
	block(m, k, Vector3.new(0.16, 0.74, 0.16), CFrame.new(0, 1.04, 0.33) * CFrame.Angles(math.rad(-14), 0, 0), ACCENT[k])
	for _, x in { -0.11, 0.11 } do
		wedge(m, k, Vector3.new(0.09, 0.18, 0.12), CFrame.new(x, 1.58, 0.0) * CFrame.Angles(math.rad(10), 0, 0))
	end
end

function BUILD.b(m, k)
	base(m, k, 0.98)
	cyl(m, k, 0.56, 0.32, 0.26)
	cyl(m, k, 0.42, 0.56, 0.52)
	cyl(m, k, 0.62, 0.07, 1.04, ACCENT[k])
	ball(m, k, 0.52, 1.32)
	-- mitre cut: a thin dark slot across the head
	block(m, k, Vector3.new(0.06, 0.24, 0.54), CFrame.new(0.06, 1.4, 0) * CFrame.Angles(0, 0, math.rad(-30)), Color3.fromRGB(20, 18, 16))
	ball(m, k, 0.16, 1.63)
end

function BUILD.q(m, k)
	base(m, k, 1.06)
	cyl(m, k, 0.64, 0.42, 0.26)
	cyl(m, k, 0.48, 0.62, 0.64)
	cyl(m, k, 0.72, 0.07, 1.22, ACCENT[k])
	cyl(m, k, 0.62, 0.24, 1.27)
	-- a big, clearly spiky coronet so the queen never reads as a rook (top-down or side-on)
	for i = 0, 7 do
		local a = math.rad(45 * i)
		ball(m, k, 0.2, 1.56).CFrame = CFrame.new(math.cos(a) * 0.3, 1.56, math.sin(a) * 0.3)
	end
	cyl(m, k, 0.22, 0.12, 1.48)
	ball(m, k, 0.26, 1.72, ACCENT[k])
end

function BUILD.k(m, k)
	base(m, k, 1.1)
	cyl(m, k, 0.68, 0.44, 0.26)
	cyl(m, k, 0.52, 0.72, 0.68)
	cyl(m, k, 0.76, 0.07, 1.38, ACCENT[k])
	cyl(m, k, 0.6, 0.3, 1.43)
	block(m, k, Vector3.new(0.12, 0.46, 0.12), CFrame.new(0, 1.92, 0), ACCENT[k])
	block(m, k, Vector3.new(0.12, 0.12, 0.36), CFrame.new(0, 1.97, 0), ACCENT[k]) -- faces the 2D icons' side view
end

-- unknown piece types (from a future mode): a plain marker
function BUILD.unknown(m, k)
	base(m, k, 0.9)
	cyl(m, k, 0.5, 0.6, 0.26)
	ball(m, k, 0.5, 1.0)
end

local cache = {}

local function simple(kind, color)
	local key = "Simple" .. kind .. color
	local template = cache[key]
	if not template then
		template = Instance.new("Model")
		template.Name = (if color == "w" then "White" else "Black") .. string.upper(kind)
		;(BUILD[kind] or BUILD.unknown)(template, color)
		template.WorldPivot = CFrame.new()
		template:ScaleTo(SCALE)
		cache[key] = template
	end
	return template:Clone()
end

-- a mesh set's piece, or nil when that set / kind isn't there
local function fromMesh(set, kind, color)
	local key = set .. kind .. color
	local template = cache[key]
	if not template then
		local sets = ReplicatedStorage:FindFirstChild("PieceSets")
		local folder = sets and sets:FindFirstChild(set)
		local mesh = folder and folder:FindFirstChild(kind)
		local look = MESH_LOOK[set]
		if not (mesh and mesh:IsA("MeshPart") and look) then
			return nil
		end
		template = Instance.new("Model")
		template.Name = (if color == "w" then "White" else "Black") .. string.upper(kind)
		local part = mesh:Clone()
		part.Anchored = true
		part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
		part.Color = look[color].color
		part.Reflectance = look[color].reflectance
		part.Material = Enum.Material.SmoothPlastic
		part.CFrame = CFrame.new(0, part.Size.Y / 2, 0)
		part.Parent = template
		template.PrimaryPart = part
		template.WorldPivot = CFrame.new()
		cache[key] = template
	end
	return template:Clone()
end

function Pieces.build(kind: string, color: string, set: string?): Model
	set = set or Pieces.current
	if set ~= "Simple" then
		local m = fromMesh(set, kind, color)
		if m then
			return m
		end
	end
	return simple(kind, color)
end

-- the viewer picked another set; returns true when it changed (the caller rebuilds the boards)
function Pieces.setSet(id: string?): boolean
	if not Settings.pieceSet(id) or id == Pieces.current then
		return false
	end
	Pieces.current = id
	return true
end

-- Height of the tallest piece (the Classic king), for camera framing.
Pieces.MAX_HEIGHT = 2.3

return Pieces
