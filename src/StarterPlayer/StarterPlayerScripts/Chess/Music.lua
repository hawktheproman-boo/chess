-- Background music: a shuffled playlist of calm classical piano (Roblox's licensed music library,
-- found with AssetService:SearchAudio), one track after another with a short fade between them.
-- The Settings "Background music" tick box turns it on and off (prefs.music); ability cutscenes
-- duck it so their sound design comes through.
--   Music.setEnabled(on)   start / fade out (call once prefs are known)
--   Music.duck(on)         quieter while a cutscene plays

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Music = {}

local TRACKS = {
	{ id = 9048615440, name = "Chopin: Nocturne" },
	{ id = 1844513698, name = "Debussy: Clair de Lune" },
	{ id = 1837474061, name = "Satie: Gymnopedie No. 1" },
	{ id = 1848053043, name = "Chopin: Impromptu in F-sharp major, Op. 36" },
	{ id = 1837474107, name = "Satie: Gymnopedie No. 3" },
	{ id = 1847113523, name = "Liszt: Valse oubliee No. 1" },
	{ id = 1837474465, name = "Debussy: Prelude, Les sons et les parfums" },
}
local VOLUME = 0.32
local DUCKED = 0.08
local FADE = 2

local sound = Instance.new("Sound")
sound.Name = "ChessMusic"
sound.Volume = 0
sound.Parent = SoundService

local enabled, ducked, running = false, false, false
local order, at = {}, 0

local function target()
	return if not enabled then 0 elseif ducked then DUCKED else VOLUME
end

local function fadeTo(volume, time)
	TweenService:Create(sound, TweenInfo.new(time), { Volume = volume }):Play()
end

-- a fresh shuffle, never starting with the track that just played
local function reshuffle(last)
	order = {}
	for i = 1, #TRACKS do
		table.insert(order, i)
	end
	for i = #order, 2, -1 do
		local j = math.random(i)
		order[i], order[j] = order[j], order[i]
	end
	if order[1] == last and #order > 1 then
		order[1], order[2] = order[2], order[1]
	end
	at = 0
end

local function nextTrack()
	at += 1
	if at > #order then
		reshuffle(order[#order])
		at = 1
	end
	return TRACKS[order[at]]
end

local function run()
	if running then
		return
	end
	running = true
	task.spawn(function()
		reshuffle(nil)
		while enabled do
			local track = nextTrack()
			sound.SoundId = "rbxassetid://" .. track.id
			sound.TimePosition = 0
			sound.Volume = 0
			sound:Play()
			fadeTo(target(), FADE)
			-- wait for the end (or for the music to be turned off); a track that won't load is skipped
			local t0 = os.clock()
			while enabled and sound.IsPlaying do
				if not sound.IsLoaded and os.clock() - t0 > 10 then
					break
				end
				local left = sound.TimeLength - sound.TimePosition
				if sound.IsLoaded and sound.TimeLength > 0 and left < FADE then
					fadeTo(0, math.max(left, 0.1))
					task.wait(math.max(left, 0.1))
					break
				end
				task.wait(0.25)
			end
			sound:Stop()
			if enabled then
				task.wait(1.5) -- a breath between pieces
			end
		end
		running = false
	end)
end

function Music.setEnabled(on: boolean)
	enabled = on == true
	if enabled then
		run()
	else
		fadeTo(0, FADE / 2)
	end
end

function Music.duck(on: boolean)
	ducked = on == true
	if sound.IsPlaying then
		fadeTo(target(), 0.6)
	end
end

return Music
