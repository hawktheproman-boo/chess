-- The lobby side of tournaments (Shared/Tournament, Tournament/Registry): starting one (VIP), joining
-- and leaving, the global announcement, and the launch.
--   * Every lobby server keeps the current record (Registry) and pushes it to each of its players
--     through Remotes.Tournament: { kind = "state", event?, tournament = view + startsIn }. The client
--     shows the banner from it; `event` (open / started / cancelled / finished) makes it announce.
--   * At startsAt any lobby server may claim the launch (open -> launching, UpdateAsync, so only one
--     wins; a launch that stalls for 90 s can be claimed again). Fewer than Tournament.MIN players:
--     cancelled. Otherwise the claimer makes sure the tournament place exists (ensurePlace), reserves
--     a server in it and marks the record live with the access code.
--   * Seeing "live", each lobby server teleports its own registered players there; "Watch" teleports
--     anyone else as a spectator.
-- The tournament place: one place made with AssetService:CreatePlaceAsync from the template place
-- (Settings.TOURNAMENT_TEMPLATE_ID, a separate place with copying on and the same code). It's kept in
-- DataStore "ChessTournament_v1" key "place" = { placeId, templateUpdated }, and made again when the
-- template has been updated since (its asset Updated time), so it always runs the current code.

local AssetService = game:GetService("AssetService")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Settings = require(Shared.Settings)
local Tournament = require(Shared.Tournament)
local Registry = require(script.Parent.Registry)

local Launcher = {}

local POLL = 15
local STALE_LAUNCH = 90

local remote
local current -- the last record read
local sent = {} -- "<tournamentId>:<userId>" -> true: already teleported
local launching = false

local store
do
	local ok, s = pcall(function()
		return DataStoreService:GetDataStore("ChessTournament_v1")
	end)
	store = if ok then s else nil
end

local function viewFor(record, player)
	local v = Registry.view(record, player.UserId)
	if v then
		v.startsIn = math.max(0, (record.startsAt or 0) - os.time())
	end
	return v
end

local function push(event, onlyPlayer)
	if not remote then
		return
	end
	for _, player in (if onlyPlayer then { onlyPlayer } else Players:GetPlayers()) do
		remote:FireClient(player, { kind = "state", event = event, tournament = viewFor(current, player) })
	end
end

-- The tournament place's id (made from the template if it's missing or older than the template).
local function ensurePlace(): number
	local template = Settings.TOURNAMENT_TEMPLATE_ID
	if not template or template == 0 then
		error("the tournament template place isn't set up (Settings.TOURNAMENT_TEMPLATE_ID)")
	end
	if not store then
		error("no DataStore")
	end
	local info = MarketplaceService:GetProductInfo(template, Enum.InfoType.Asset)
	local updated = tostring(info and info.Updated or "")
	local saved = store:GetAsync("place")
	if type(saved) == "table" and type(saved.placeId) == "number" and saved.templateUpdated == updated then
		return saved.placeId
	end
	local placeId = AssetService:CreatePlaceAsync("Chess Tournament", template, "Knockout chess tournaments")
	store:SetAsync("place", { placeId = placeId, templateUpdated = updated, made = os.time() })
	return placeId
end

local function teleport(players, record, role)
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = record.accessCode
	options:SetTeleportData({ tournamentId = record.id, role = role })
	for attempt = 1, 2 do
		local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, record.placeId, players, options)
		if ok then
			return true
		end
		warn("[Chess] tournament teleport failed:", err)
		task.wait(3)
	end
	return false
end

-- live: send this server's registered players who haven't gone yet
local function sendPlayers()
	local record = current
	if not (record and record.state == "live" and record.accessCode and record.placeId) then
		return
	end
	local batch = {}
	for _, p in record.players do
		local player = Players:GetPlayerByUserId(p.userId)
		local key = record.id .. ":" .. p.userId
		if player and not sent[key] then
			sent[key] = true
			table.insert(batch, player)
		end
	end
	if #batch > 0 then
		task.spawn(teleport, batch, record, "player")
	end
end

local function launch(record)
	launching = true
	local ok, placeId, code, privateId = pcall(function()
		local id = ensurePlace()
		local accessCode, psid = TeleportService:ReserveServer(id)
		return id, accessCode, psid
	end)
	local okUpdate, rec
	if ok then
		okUpdate, rec = Registry.update(function(old)
			if not old or old.id ~= record.id or old.state ~= "launching" then
				return nil, "changed"
			end
			old.state = "live"
			old.placeId = placeId
			old.accessCode = code
			old.privateServerId = privateId
			old.round = "Players arriving"
			return old
		end)
		if okUpdate then
			Registry.publish("started", rec)
		end
	else
		warn("[Chess] couldn't open the tournament place:", placeId)
		okUpdate, rec = Registry.update(function(old)
			if not old or old.id ~= record.id then
				return nil, "changed"
			end
			old.state = "cancelled"
			old.reason = "the tournament place couldn't be opened"
			return old
		end)
		if okUpdate then
			Registry.publish("cancelled", rec)
		end
	end
	launching = false
	if okUpdate then
		current = rec
		push(if rec.state == "live" then "started" else "cancelled")
		sendPlayers()
	end
end

-- countdown over: claim the launch (or cancel when too few joined)
local function tryLaunch()
	if launching or not current then
		return
	end
	local id = current.id
	local ok, rec = Registry.update(function(old)
		if not old or old.id ~= id then
			return nil, "gone"
		end
		local stale = old.state == "launching" and os.time() - (old.launchingSince or 0) > STALE_LAUNCH
		if (old.state ~= "open" and not stale) or os.time() < old.startsAt then
			return nil, "not now"
		end
		if #old.players < Tournament.MIN then
			old.state = "cancelled"
			old.reason = string.format("only %d joined (%d needed)", #old.players, Tournament.MIN)
			return old
		end
		old.state = "launching"
		old.launchedBy = game.JobId
		old.launchingSince = os.time()
		return old
	end)
	if not ok then
		return
	end
	current = rec
	if rec.state == "cancelled" then
		Registry.publish("cancelled", rec)
		push("cancelled")
		return
	end
	task.spawn(launch, rec)
end

local function refresh(event)
	local before = current
	current = Registry.get()
	if event == nil and before and current and before.id == current.id and before.state ~= current.state then
		event = if current.state == "live" then "started" elseif current.state == "cancelled" then "cancelled"
			elseif current.state == "done" then "finished" else nil
	elseif event == nil and current and (not before or before.id ~= current.id) and current.state == "open" then
		event = "open"
	end
	push(event)
	sendPlayers()
end

function Launcher.init(r)
	remote = r
	Registry.subscribe(function(msg)
		refresh(if type(msg.kind) == "string" then msg.kind else nil)
	end)
	Players.PlayerAdded:Connect(function(player)
		task.wait(2)
		if player.Parent then
			push(nil, player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if current and current.state == "open" and Registry.find(current, player.UserId) then
			task.spawn(function()
				local ok, rec = Registry.leave(player.UserId)
				if ok then
					current = rec
					Registry.publish("count", rec)
					push(nil)
				end
			end)
		end
	end)
	task.spawn(function()
		refresh(nil)
		local last = os.clock()
		while true do
			task.wait(1)
			if current and Registry.ACTIVE[current.state] and current.state ~= "live" and os.time() >= current.startsAt then
				tryLaunch()
			end
			if os.clock() - last >= POLL then
				last = os.clock()
				refresh(nil)
			end
		end
	end)
end

-- Lobby verbs ---------------------------------------------------------------------------------------

function Launcher.state(player)
	return true, viewFor(current, player)
end

function Launcher.start(participant)
	local ok, rec = Registry.create(participant)
	if not ok then
		return false, rec
	end
	current = rec
	Registry.publish("open", rec)
	push("open")
	return true, viewFor(rec, participant.player)
end

function Launcher.join(participant)
	local ok, rec = Registry.join(participant)
	if not ok then
		return false, rec
	end
	current = rec
	Registry.publish("count", rec)
	push(nil)
	return true, viewFor(rec, participant.player)
end

function Launcher.leave(participant)
	local ok, rec = Registry.leave(participant.userId)
	if not ok then
		return false, rec
	end
	current = rec
	Registry.publish("count", rec)
	push(nil)
	return true, viewFor(rec, participant.player)
end

function Launcher.watch(player)
	local record = Registry.get()
	if not (record and record.state == "live" and record.accessCode) then
		return false, "no tournament is being played right now"
	end
	if RunService:IsStudio() then
		return false, "teleports don't work in Studio"
	end
	task.spawn(teleport, { player }, record, "spectator")
	return true
end

return Launcher
