-- Builds ReplicatedStorage.PieceSets (Edit mode) from the uploaded piece meshes, so every place
-- gets the same sets without re-importing: python tools/run_luau.py builders/piece_sets.lua
-- The meshes come from art/pieces/make_sets.py (Blender) -> <Set>.fbx -> Studio's 3D Importer
-- (uploaded to The Depths Studio, 2026-10-18). Re-import after changing a set and update the ids here.
--
-- Layout used by Pieces.lua: ReplicatedStorage.PieceSets.<Set>.<kind> = MeshPart, kind p r n b q k;
-- its pivot (PivotOffset) is the centre of the base's underside, and the knight faces -Z.

local AssetService = game:GetService("AssetService")

local SETS = {
	Classic = {
		p = "77728569315316", r = "86308214004474", n = "107986066609899",
		b = "120661226514175", q = "99650415620767", k = "73308855540285",
	},
	Toon = {
		p = "101941075137365", r = "107851549751696", n = "117903822391665",
		b = "85203930874482", q = "135279372370290", k = "92897138865665",
	},
}

local RS = game:GetService("ReplicatedStorage")
local old = RS:FindFirstChild("PieceSets")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "PieceSets"

local made = 0
for setName, kinds in SETS do
	local folder = Instance.new("Folder")
	folder.Name = setName
	folder.Parent = root
	for kind, id in kinds do
		local part = AssetService:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. id))
		part.Name = kind
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Material = Enum.Material.SmoothPlastic
		part.CFrame = CFrame.new(0, part.Size.Y / 2, 0)
		part.PivotOffset = CFrame.new(0, -part.Size.Y / 2, 0) -- pivot: the base's underside
		part:SetAttribute("Height", part.Size.Y)
		part.Parent = folder
		made += 1
	end
end
root.Parent = RS

-- the importer's copies in the workspace aren't needed any more
for _, name in { "Classic", "Toon", "pawn_test" } do
	local m = workspace:FindFirstChild(name)
	if m and m:IsA("Model") then
		m:Destroy()
	end
end
return "built " .. made .. " piece meshes"
