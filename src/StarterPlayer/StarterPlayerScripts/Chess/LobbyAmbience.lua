-- Life in the lobby park (client only, built on builders/build_decor.lua's Decor):
--   the flags sway on their poles (Decor.Flags parts with a Hinge attribute)
--   a few birds circle high over the park, flapping now and then
--   soft birdsong everywhere, and running water near the fountain (Decor.Fountain.Sparkle)
-- Sounds follow the Settings sound switch (Sounds.enabled). Nothing here touches the tables.
--   LobbyAmbience.start()

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Sounds = require(script.Parent.Sounds)

local LobbyAmbience = {}

local BIRDSONG = "rbxassetid://139786277679262" -- "Nature's Soft Chorus" (Creator Store, 167 s)
local WATER = "rbxassetid://137086424700822" -- "Calming water stream in the rainforest" (150 s)
local BIRDS = 6

local function bird(parent, i)
	local m = Instance.new("Model")
	m.Name = "Bird"
	local function piece(name, size, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = m
		return p
	end
	local tint = if i % 3 == 0 then Color3.fromRGB(70, 70, 78) else Color3.fromRGB(240, 240, 236)
	local body = piece("Body", Vector3.new(0.5, 0.45, 1.5), tint)
	local left = piece("Wing", Vector3.new(1.5, 0.08, 0.7), tint)
	local right = piece("Wing", Vector3.new(1.5, 0.08, 0.7), tint)
	m.Parent = parent
	return { body = body, left = left, right = right,
		radius = 46 + (i * 13) % 34, height = 32 + (i * 7) % 12, speed = 0.11 + (i % 4) * 0.025,
		phase = i * 1.7, dir = if i % 2 == 0 then 1 else -1, centre = Vector3.new(((i * 29) % 60) - 30, 0, ((i * 17) % 50) - 25) }
end

local function loop(id, parent, volume, rollOff)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	if rollOff then
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = rollOff[1]
		s.RollOffMaxDistance = rollOff[2]
	end
	s.Parent = parent
	s:Play()
	return { sound = s, volume = volume }
end

function LobbyAmbience.start()
	task.spawn(function()
		local lobby = workspace:WaitForChild("Lobby", 60)
		local decor = lobby and lobby:WaitForChild("Decor", 30)
		if not decor then
			return -- an older build without the decor
		end
		local root = Instance.new("Folder")
		root.Name = "LobbyAmbience"
		root.Parent = workspace

		-- flags: remember each one's rest pose relative to its hinge
		local flags = {}
		local flagFolder = decor:WaitForChild("Flags", 10)
		if flagFolder then
			flagFolder:WaitForChild("Flag", 10) -- (a Persistent model: its parts arrive together)
		end
		for _, p in if flagFolder then flagFolder:GetChildren() else {} do
			local hinge = p:GetAttribute("Hinge")
			if p:IsA("BasePart") and typeof(hinge) == "Vector3" then
				table.insert(flags, { part = p, hinge = hinge, rest = CFrame.new(hinge):ToObjectSpace(p.CFrame), phase = hinge.X * 0.37 + hinge.Z * 0.11 })
			end
		end

		local birds = {}
		for i = 1, BIRDS do
			table.insert(birds, bird(root, i))
		end

		local sounds = { loop(BIRDSONG, SoundService, 0.22) }
		local fountain = decor:WaitForChild("Fountain", 10)
		local sparkle = fountain and fountain:WaitForChild("Sparkle", 10)
		if sparkle then
			table.insert(sounds, loop(WATER, sparkle, 0.45, { 8, 45 }))
		end
		task.spawn(function()
			while root.Parent do
				for _, s in sounds do
					s.sound.Volume = if Sounds.enabled then s.volume else 0
				end
				task.wait(1)
			end
		end)

		RunService.RenderStepped:Connect(function()
			local t = os.clock()
			for _, f in flags do
				-- a slow swing plus a quicker flutter, about the pole
				local a = math.sin(t * 1.3 + f.phase) * 0.22 + math.sin(t * 4.1 + f.phase * 2) * 0.05
				f.part.CFrame = CFrame.new(f.hinge) * CFrame.Angles(0, a, 0) * f.rest
			end
			for _, b in birds do
				local a = b.phase + t * b.speed * b.dir
				local pos = b.centre + Vector3.new(math.cos(a) * b.radius, b.height + math.sin(t * 0.5 + b.phase) * 2, math.sin(a) * b.radius)
				local ahead = b.centre + Vector3.new(math.cos(a + 0.05 * b.dir) * b.radius, b.height, math.sin(a + 0.05 * b.dir) * b.radius)
				local bank = CFrame.Angles(0, 0, -0.25 * b.dir)
				local cf = CFrame.lookAt(pos, Vector3.new(ahead.X, pos.Y, ahead.Z)) * bank
				-- flap in bursts, then glide
				local burst = math.sin(t * 0.7 + b.phase) > 0.2
				local flap = if burst then math.sin(t * 14 + b.phase) * 0.6 else 0.12
				b.body.CFrame = cf
				b.left.CFrame = cf * CFrame.new(-0.25, 0.1, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-0.75, 0, 0)
				b.right.CFrame = cf * CFrame.new(0.25, 0.1, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(0.75, 0, 0)
			end
		end)
	end)
end

return LobbyAmbience
