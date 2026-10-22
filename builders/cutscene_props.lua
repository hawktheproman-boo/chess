-- Builds ReplicatedStorage.CutsceneProps (run in Edit mode in every place, then save).
--   Sniper: the Bishop Snipe rifle (art/props/make_rifle.py -> Sniper.fbx -> 3D Importer, uploaded to
--   The Depths Studio). A Model of 4 MeshParts plus an invisible Root at the rifle's origin: on the
--   bore axis above the trigger, muzzle towards -Z. Cutscene.lua clones it and moves it by Root.
--   The Bolt part slides back along +Z for the reload.
--   Katana + Saya: the Any Passant sword and its scabbard (art/props/make_katana.py -> Katana.fbx -> 3D
--   Importer). Both share the origin at the centre of the guard, blade towards -Z, edge down. Katana =
--   Blade, Guard, Grip; Saya = the scabbard, a separate Model so it can be moved on its own.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SNIPER = {
	-- name, mesh id, offset from the origin (from the importer), colour, material
	{ "Stock", 139276095841028, Vector3.new(0, -0.169468, 0.114616), Color3.fromRGB(122, 72, 40), Enum.Material.Wood },
	{ "Metal", 109529370168243, Vector3.new(0, -0.19, -0.630001), Color3.fromRGB(40, 41, 46), Enum.Material.Metal },
	{ "Bolt", 121059340145107, Vector3.new(-0.132439, -0.017635, 0.224148), Color3.fromRGB(170, 170, 176), Enum.Material.Metal },
	{ "Lens", 136280276586926, Vector3.new(0, 0.17, 0.05), Color3.fromRGB(150, 30, 36), Enum.Material.Glass },
}

local KATANA = {
	{ "Blade", 127173855133557, Vector3.new(0, 0.0465653, -0.971962), Color3.fromRGB(215, 220, 228), Enum.Material.Metal },
	{ "Guard", 81837650949690, Vector3.new(0, 0, 0.279999), Color3.fromRGB(205, 160, 60), Enum.Material.Metal },
	{ "Grip", 114761257471287, Vector3.new(0, 0, 0.334999), Color3.fromRGB(28, 34, 70), Enum.Material.Fabric },
}
local SAYA = {
	{ "Saya", 131496459315776, Vector3.new(0, 0.0532886, -0.922729), Color3.fromRGB(18, 18, 22), Enum.Material.SmoothPlastic },
}

local folder = ReplicatedStorage:FindFirstChild("CutsceneProps") or Instance.new("Folder")
folder.Name = "CutsceneProps"

local function build(name, list)
	local old = folder:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * 0.1
	root.Transparency = 1
	root.CFrame = CFrame.new()
	root.Parent = model
	for _, s in list do
		local part = AssetService:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. s[2]))
		part.Name = s[1]
		part.CFrame = CFrame.new(s[3])
		part.Color = s[4]
		part.Material = s[5]
		part.Parent = model
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = p.Name ~= "Root"
		end
	end
	model.PrimaryPart = root
	model.Parent = folder
	-- the importer's copy
	local imported = workspace:FindFirstChild(name)
	if imported then
		imported:Destroy()
	end
	print("built CutsceneProps." .. name)
end

build("Sniper", SNIPER)
build("Katana", KATANA)
build("Saya", SAYA)
folder.Parent = ReplicatedStorage
