-- Game sound effects. From Roblox's licensed Pro Sound Effects / APM libraries, free Creator Store
-- audio, or Roblox's built-in sounds; swap an id here to change a sound everywhere.
--   Sounds.play(name)           flat (your own table)
--   Sounds.play(name, position) from a point in the world (a table you're standing near)
--   Sounds.play(name, position, { volume, speed, fadeAfter, fadeTime }) -> the playing Sound
--   Sounds.fade(sound, time)    fade a playing sound out and stop it
-- A LIB entry's fx adds sound effects: "bass" (big low end), "reverb" (a hall tail), "slow" (muffled).
-- Sounds.enabled is the player's Settings toggle.

local SoundService = game:GetService("SoundService")

local Sounds = {}
Sounds.enabled = true

local LIB = {
	move = { id = "rbxassetid://9118623491", volume = 0.7, speed = 1.3 }, -- hit rock with wood, light strike
	capture = { id = "rbxassetid://9126266458", volume = 0.75, speed = 1.15 }, -- iron weight knocks against wood
	castle = { id = "rbxassetid://9118621947", volume = 0.7, speed = 1.2 }, -- a second light wood strike
	check = { id = "rbxassetid://9126073001", volume = 0.3, speed = 1.0 }, -- synth sparkle ding
	start = { id = "rbxassetid://9126073318", volume = 0.3, speed = 0.9 }, -- softer ding
	finish = { id = "rbxassetid://9126073011", volume = 0.35, speed = 0.8 }, -- long ding
	tick = { id = "rbxassetid://9118621947", volume = 0.25, speed = 2.2 }, -- low time: a quick tap each second
	snipe = { id = "rbxasset://sounds/impact_explosion_03.mp3", volume = 0.35, speed = 2.3 }, -- a sharp crack
	-- Bishop Snipe cutscene (free Creator Store sounds)
	sniperShot = { id = "rbxassetid://98063753863205", volume = 0.9, speed = 0.85, fx = { "bass", "reverb" } }, -- "Sniper Rifle Single Shot 1" (CBE_Simon), pitched down
	-- the cinematic layer under it (APM Music / Pro Sound Effects, free in any experience)
	braam = { id = "rbxassetid://87457247631454", volume = 0.55, speed = 1.0 }, -- "Scorched Earth Braam" (APM)
	riser = { id = "rbxassetid://1837834284", volume = 0.5, speed = 1.0 }, -- "REVERSE HARD STOP-Noise Build 06" (APM): 4 s, ends dead
	heartbeat = { id = "rbxassetid://6202853067", volume = 0.7, speed = 1.0, fx = { "bass" } }, -- "Heartbeat (loop)" (Screaming_Monkeys)
	trailerHit = { id = "rbxassetid://1835333323", volume = 0.8, speed = 1.0 }, -- "Angry Heavy Hitter Hit" (APM)
	lowBoom = { id = "rbxassetid://1835337001", volume = 0.7, speed = 1.0 }, -- "Fear Enhancer Low Boom" (APM)
	impactBoom = { id = "rbxassetid://119977062667102", volume = 0.6, speed = 1.0, fx = { "bass" } }, -- "cinematic-impact-boom" (fcracky)
	slowWhoosh = { id = "rbxassetid://9125920594", volume = 0.7, speed = 0.55, fx = { "reverb" } }, -- "Searing Whoosh Fast Rushing Pass By" (PSE), slowed
	woodBreak = { id = "rbxassetid://9120801590", volume = 0.6, speed = 0.9 }, -- "Wood Break 1" (Pro Sound Effects)
	rumble = { id = "rbxassetid://9113169432", volume = 0.45, speed = 0.9 }, -- "Artillery Distant 2" (PSE): the tail
	boltOpen = { id = "rbxassetid://122612995190489", volume = 0.6, speed = 1.0 }, -- "SPX-80 Bolt Open" (Jilusions)
	boltClose = { id = "rbxassetid://99816337580692", volume = 0.6, speed = 1.0 }, -- "Intervention BoltFowardAndDown" (Jilusions)
	shellDrop = { id = "rbxassetid://9113631067", volume = 0.35, speed = 1.1 }, -- "Bullet Drops 4" (Pro Sound Effects)
	scopeZoom = { id = "rbxassetid://18772934574", volume = 0.5, speed = 1.0 }, -- "Sniper scope zoom in" (Gonee_e)
	-- Double Jump
	neigh = { id = "rbxassetid://76083961423839", volume = 0.6, speed = 1.0, fx = { "reverb" } }, -- "Horse Neigh" (sd3ric)
	leap = { id = "rbxassetid://9126229005", volume = 0.8, speed = 0.9 }, -- "Whoosh By Fast Airy Swooshing Whipping Thuds 3" (PSE)
	choir = { id = "rbxassetid://138790306528800", volume = 0.5, speed = 1.0, fx = { "reverb" } }, -- "Harken Sing" (an angelic choir)
	beamBlast = { id = "rbxassetid://77772246617018", volume = 0.8, speed = 0.9, fx = { "bass", "reverb" } }, -- "energy beam blast 1" (yodguard)
	warpIn = { id = "rbxassetid://113381279319015", volume = 0.8, speed = 1.0 }, -- "279-S_appear"
	twinkle = { id = "rbxassetid://135385970610304", volume = 0.5, speed = 1.0, fx = { "reverb" } }, -- "Twinkle08"
	unsheath = { id = "rbxassetid://79499154333475", volume = 0.7, speed = 1.0, fx = { "reverb" } }, -- a sword draw (Roblok_studio)
	bladeRing = { id = "rbxassetid://5789211405", volume = 0.9, speed = 0.9, fx = { "reverb" } }, -- "sword_swing_fast_whoosh_blade_ring_001"
	sheath = { id = "rbxassetid://5276811184", volume = 0.9, speed = 1.0, fx = { "reverb" } }, -- "Katana Sheathe" (bluslip)
	cut = { id = "rbxassetid://120078433650951", volume = 0.8, speed = 1.0, fx = { "bass" } }, -- "Black Slashes"
	chains = { id = "rbxassetid://9113760230", volume = 0.9, speed = 0.9, fx = { "reverb" } }, -- "Chain Movement 2" (PSE)
	glassBreak = { id = "rbxassetid://17806433611", volume = 0.9, speed = 1.0, fx = { "reverb" } }, -- "Glass_Heavy_2"
	kaching = { id = "rbxassetid://91609406292294", volume = 0.8, speed = 1.0 }, -- "retro cash register ka-ching"
	-- Battering Ram
	snort = { id = "rbxassetid://9113634896", volume = 0.8, speed = 0.8, fx = { "bass" } }, -- "Bull Goblin Snorts 6" (PSE)
	stomp = { id = "rbxassetid://9114036511", volume = 0.8, speed = 1.0, fx = { "bass" } }, -- "Deep Impacts 7" (PSE)
	rush = { id = "rbxassetid://9125442175", volume = 0.8, speed = 0.9 }, -- "Cloth Whooshes Fast Whooshes Rumbling Pass Bys" (PSE)
	skid = { id = "rbxassetid://9119906619", volume = 0.7, speed = 1.3 }, -- "Table And Chair Movement 2" (PSE): wood scrape
	crateBreak = { id = "rbxassetid://77082947220205", volume = 0.6, speed = 0.9 }, -- "wood_crate_break3" (srth_h)
	dodge = { id = "rbxassetid://9114373663", volume = 0.7, speed = 1.15 }, -- "Fast Pass By Airy Whooshes Windy 2" (PSE): the king's sidestep
	ricochet = { id = "rbxassetid://7842386350", volume = 0.8, speed = 0.9, fx = { "reverb" } }, -- "Bullet Ricochet 2" (DuncanDunclub)
	bulletHit = { id = "rbxassetid://100725736694571", volume = 0.8, speed = 0.9, fx = { "bass" } }, -- "wood_solid_impact_bullet3" (daon2000)
	good = { id = "rbxassetid://9126073001", volume = 0.35, speed = 1.35 }, -- review: a bright chime (brilliant / great)
	bad = { id = "rbxassetid://9126073011", volume = 0.3, speed = 0.55 }, -- review: a low note (mistake / blunder)
	jump = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.5, speed = 1.1 }, -- Double Jump: take-off (built in)
	land = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.7, speed = 0.9 }, -- Double Jump: landing (built in)
	crash = { id = "rbxasset://sounds/impact_explosion_03.mp3", volume = 0.4, speed = 1.2 }, -- Battering Ram: a heavy smash
	magic = { id = "rbxassetid://9126073001", volume = 0.35, speed = 0.75 }, -- Swap: a low sparkle
	teleport = { id = "rbxassetid://9126073318", volume = 0.4, speed = 1.5 }, -- Royal Escape: a bright blip
	hover = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.18, speed = 1.4 }, -- a soft tick, Roblox built-in
	click = { id = "rbxassetid://9118623491", volume = 0.45, speed = 1.9 }, -- the wood "move" knock, pitched up
}

local folder = Instance.new("Folder")
folder.Name = "ChessSounds"
folder.Parent = SoundService

local templates = {}
for name, s in LIB do
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = s.id
	sound.Volume = s.volume
	sound.PlaybackSpeed = s.speed
	for _, kind in s.fx or {} do
		if kind == "bass" then
			local eq = Instance.new("EqualizerSoundEffect")
			eq.LowGain, eq.MidGain, eq.HighGain = 9, 0, -2
			eq.Parent = sound
		elseif kind == "reverb" then
			local rv = Instance.new("ReverbSoundEffect")
			rv.DecayTime, rv.Density, rv.Diffusion, rv.WetLevel, rv.DryLevel = 2.4, 1, 1, -6, 0
			rv.Parent = sound
		elseif kind == "slow" then
			local eq = Instance.new("EqualizerSoundEffect")
			eq.LowGain, eq.MidGain, eq.HighGain = 4, -4, -20
			eq.Parent = sound
		end
	end
	sound.Parent = folder
	templates[name] = sound
end

local anchor -- an invisible part that carries positioned sounds
local function anchorPart()
	if not (anchor and anchor.Parent) then
		anchor = Instance.new("Part")
		anchor.Name = "ChessSoundAnchor"
		anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
		anchor.Transparency = 1
		anchor.Size = Vector3.one * 0.2
		anchor.Parent = workspace
	end
	return anchor
end

function Sounds.fade(s: Sound?, time: number)
	if s and s.Parent then
		game:GetService("TweenService"):Create(s, TweenInfo.new(time), { Volume = 0 }):Play()
		task.delay(time, function()
			s:Stop()
			s:Destroy()
		end)
	end
end

function Sounds.play(name: string, position: Vector3?, opts)
	local t = templates[name]
	if not (Sounds.enabled and t) then
		return nil
	end
	local s = t:Clone()
	if opts then
		s.Volume = opts.volume or s.Volume
		s.PlaybackSpeed = opts.speed or s.PlaybackSpeed
		s.TimePosition = opts.timePosition or 0 -- (start part-way in, e.g. a riser cut to fit)
		if opts.fadeAfter then
			task.delay(opts.fadeAfter, Sounds.fade, s, opts.fadeTime or 0.5)
		end
	end
	if position then
		local a = Instance.new("Attachment")
		a.WorldPosition = position
		a.Parent = anchorPart()
		s.RollOffMinDistance = 12
		s.RollOffMaxDistance = 70
		s.Parent = a
		s.Ended:Once(function()
			a:Destroy()
		end)
	else
		s.Parent = folder
		s.Ended:Once(function()
			s:Destroy()
		end)
	end
	s:Play()
	return s
end

-- the sounds for one applied move, read from its SAN ("exd5", "O-O", "Qh7#", "e8=Q+")
function Sounds.forMove(san: string?, position: Vector3?)
	san = san or ""
	if string.find(san, "O%-O") then
		Sounds.play("move", position)
		task.delay(0.09, Sounds.play, "castle", position)
	elseif string.find(san, "x") then
		Sounds.play("capture", position)
	else
		Sounds.play("move", position)
	end
	if string.find(san, "[+#]") then
		task.delay(0.05, Sounds.play, "check", position)
	end
end

return Sounds
