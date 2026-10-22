-- Runs every chess table and the remotes. The server is the authority: clients only request.
--
-- Remotes (ReplicatedStorage.Remotes, created here):
--   Lobby          RemoteFunction  (verb, tableId, arg) -> ok, err|data
--                  verbs: "list", "sit" (arg = "w"|"b"|nil), "stand", "configure" (arg = {mode, clock}),
--                  "ready" (arg = bool), "addBot" (arg = level 1..4), "removeBot", "botLevel" (arg = level: the seated bot's, in place), "stats",
--                  "saveGame" (arg = review record, VIP), "savedGame" / "deleteGame" (arg = id, VIP),
--                  "botLevels", "quick" (arg = { vs = "bot"|"player", level, clock, color = "w"|"b"|nil }),
--                  "wallet" -> { coins, owned, vip }, "buy" (arg = ability id) -> ok, { coins, owned } | err,
--                  tournaments (Tournament/*): "tourney" -> the banner / bracket view, "tourneyStart" (VIP),
--                  "tourneyJoin", "tourneyLeave", "tourneyWatch" (teleport as a spectator),
--                  "today" -> the daily log lists, "todayGame" (arg = id) -> one logged game,
--                  "leaderboard" (arg = "wins"|"titles") -> { board, top = { { rank, userId, name, value } }
--                  (top 10), mine = { wins, titles } } (Leaderboards)
--   RequestAction  RemoteEvent     client -> (tableId, action)   rejected -> State {type="rejected"}
--   TableCommand   RemoteEvent     client -> (tableId, cmd)      resign / offerDraw / acceptDraw /
--                                                                declineDraw / snapshot
--   State          RemoteEvent     server -> payload (see ChessTable)
--   Wallet         RemoteEvent     server -> { coins, owned, steals, gained? } after a win reward or a change
--   Tournament     RemoteEvent     server -> lobby: { kind = "state", event?, tournament }; tournament
--                                  server: { kind = "bracket", ... } (Tournament/Launcher, Tournament/Runner)
-- Roles: the lobby place (Settings.START_PLACE_ID) runs quick play and the tournament Launcher; any
-- other place running this code is a tournament server: Tournament/Runner owns the tables there, and
-- nobody sits down by themselves (ReplicatedStorage attribute "TournamentServer").
-- The lobby place also starts LobbyBoards (the Most wins / Champions screens in the lobby).
-- MarketplaceService.ProcessReceipt: Settings.STEAL_PRODUCT (Steal a Piece) adds a paid steal to the
-- wallet and, mid-game, grants it in that game at once.
-- Studio only: ServerStorage.ChessDebug (BindableFunction) drives tables with fake players.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Settings = require(Shared.Settings)
local Notation = require(Shared.Chess.Notation)
local ChessTable = require(script.Parent.ChessTable)
local Results = require(script.Parent.Results)
local Leaderboards = require(script.Parent.Leaderboards)
local Prefs = require(script.Parent.Prefs)
local Vip = require(script.Parent.Vip)
local SavedGames = require(script.Parent.SavedGames)
local Search = require(Shared.Bot.Search)
local Seating = require(script.Parent.Seating)
local Wallet = require(script.Parent.Wallet)
local Passes = require(script.Parent.Passes)
local Shop = require(Shared.Shop)
local TournamentFolder = script.Parent.Parent:WaitForChild("Tournament")
local Launcher = require(TournamentFolder.Launcher)
local Runner = require(TournamentFolder.Runner)
local DailyLog = require(TournamentFolder.DailyLog)

local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(class, name)
	local r = remotes:FindFirstChild(name) or Instance.new(class)
	r.Name = name
	r.Parent = remotes
	return r
end
local Lobby = remote("RemoteFunction", "Lobby")
local RequestAction = remote("RemoteEvent", "RequestAction")
local TableCommand = remote("RemoteEvent", "TableCommand")
local State = remote("RemoteEvent", "State")
Wallet.setRemote(remote("RemoteEvent", "Wallet"))
local TournamentRemote = remote("RemoteEvent", "Tournament")
remotes.Parent = ReplicatedStorage

-- (Studio: the workspace attribute TestTournamentServer makes this server a tournament server; the
-- runner then waits for ChessDebug "tourneyLocal")
local studioTournament = RunService:IsStudio() and workspace:GetAttribute("TestTournamentServer") == true
local isTournamentServer = studioTournament or (game.PlaceId ~= 0 and game.PlaceId ~= Settings.START_PLACE_ID)
ReplicatedStorage:SetAttribute("TournamentServer", isTournamentServer)

local isStudio = RunService:IsStudio()
local tables = {} -- id -> ChessTable
local debugLog = {} -- id -> last broadcasts (Studio only)

-- Stats count games against people only. A win against a person pays coins (Shop.WIN_REWARD) once
-- the game is Shop.MIN_PLIES long and counts on the Most wins leaderboard; bot games pay nothing.
-- (Test drivers' fake players have no Player, so their games never touch real stats, wallets or
-- boards.)
local function onFinished(t, result)
	if result.reason ~= "aborted" then
		local plies = if t.game then #t.game.history else 0
		for color, p in t.seats do
			local opponent = t.seats[if color == "w" then "b" else "w"]
			if p.player and opponent and opponent.player then
				local outcome = if result.winner == nil then "d" elseif result.winner == color then "w" else "l"
				Results.record(p.userId, {
					bucket = if t.owner == "tournament" then "Tournament" else t.settings.mode,
					outcome = outcome,
					reason = result.reason,
					plies = plies,
				})
				if outcome == "w" then
					Leaderboards.addWin(p.userId)
					if plies >= Shop.MIN_PLIES then
						Wallet.award(p.userId, Shop.WIN_REWARD)
					end
				end
			end
		end
	end
	t:freeDisconnected()
	if t.onTournament then
		t.onTournament(t, result) -- (Tournament/Runner: the bracket moves on)
	end
end

local function makeTable(id)
	local t
	t = ChessTable.new(id, function(payload)
		State:FireAllClients(payload)
		if payload.type == "snapshot" or payload.type == "result" then
			task.defer(Seating.sync, tables[id]) -- chairs follow seats and status
		end
		if isStudio then
			local log = debugLog[id] or {}
			debugLog[id] = log
			table.insert(log, payload)
			if #log > 30 then
				table.remove(log, 1)
			end
		end
	end, onFinished)
	t.loadoutFor = function(p)
		return if p.player then Wallet.owned(p.userId) else nil
	end
	t.stealFor = function(p)
		return p.player ~= nil and Wallet.steals(p.userId) > 0
	end
	t.onSteal = function(p)
		if p and p.player then
			Wallet.spendSteal(p.userId)
		end
	end
	tables[id] = t
	return t
end

for i = 1, Settings.TABLE_COUNT do
	makeTable("T" .. i)
end

local function participantFor(player)
	return { userId = player.UserId, name = player.DisplayName, player = player }
end

local function tableOf(userId)
	for _, t in tables do
		if t:colorOf(userId) then
			return t
		end
	end
	return nil
end

-- Simple rate limit: 20 requests per 2 seconds per player.
local buckets = {}
local function allowed(player)
	local now = os.clock()
	local b = buckets[player]
	if not b or now - b.start > 2 then
		b = { start = now, count = 0 }
		buckets[player] = b
	end
	b.count += 1
	return b.count <= 20
end

-- Sit a player down (chair prompt or lobby). Moving to another table is fine unless mid-game.
local function sitPlayer(player, tableId, color)
	local t = tables[tableId]
	if not t then
		return false, "no such table"
	end
	if isTournamentServer or t.owner then
		return false, "this table is for the tournament"
	end
	local current = tableOf(player.UserId)
	if current and current ~= t then
		if current.status == "playing" then
			return false, "finish your game first"
		end
		local ok, err = current:stand(player.UserId)
		if not ok then
			return false, err
		end
	end
	return t:sit(participantFor(player), if color == "w" or color == "b" then color else nil)
end

-- One-click play. vs "player": join someone waiting alone at a table, else take an empty table
-- and wait there. vs "bot": take an empty table, invite the bot and start straight away.
local function quickPlay(player, opts)
	if isTournamentServer then
		return false, "this server is for the tournament"
	end
	opts = if type(opts) == "table" then opts else {}
	local uid = player.UserId
	local current = tableOf(uid)
	if current and current.status == "playing" then
		return false, "finish your game first"
	end
	if current then
		current:stand(uid)
	end
	local vsBot = opts.vs == "bot"
	local mode = if type(opts.mode) == "string" and Settings.hasMode(opts.mode) then opts.mode else nil
	local chosen, color
	if not vsBot then
		for i = 1, Settings.TABLE_COUNT do
			local t = tables["T" .. i]
			local w, b = t.seats.w, t.seats.b
			-- a player picked a mode on the Play screen: only join someone waiting in that mode
			if t.status ~= "playing" and not t.owner and (mode == nil or t.settings.mode == mode) then
				if w and not w.isBot and not b then
					chosen, color = t, "b"
					break
				elseif b and not b.isBot and not w then
					chosen, color = t, "w"
					break
				end
			end
		end
	end
	if not chosen then
		for i = 1, Settings.TABLE_COUNT do
			local t = tables["T" .. i]
			if t.status ~= "playing" and not t.owner and not t.seats.w and not t.seats.b then
				chosen = t
				break
			end
		end
		if not chosen then
			return false, "all tables are busy"
		end
		color = if opts.color == "w" or opts.color == "b" then opts.color elseif math.random() < 0.5 then "w" else "b"
	end
	local ok, err = chosen:sit(participantFor(player), color)
	if not ok then
		return false, err
	end
	if mode and chosen.settings.mode ~= mode then
		chosen:configure(uid, { mode = mode }) -- a fresh table waits in the picked mode
	end
	if vsBot then
		if type(opts.clock) == "string" and Settings.clock(opts.clock) then
			chosen:configure(uid, { clock = opts.clock })
		end
		local level = if type(opts.level) == "number" then opts.level else 2
		local okBot, errBot = chosen:addBot(uid, level)
		if not okBot then
			return false, errBot
		end
		chosen:setReady(uid, true)
	end
	return true, chosen.id
end

Seating.init(tables, function(player, tableId, color)
	if allowed(player) then
		local ok, err = sitPlayer(player, tableId, color)
		if not ok then
			State:FireClient(player, { type = "rejected", tableId = tableId, seq = tables[tableId].seq, reason = err })
		end
	end
end)

local function summary(t)
	local snap = t:snapshot()
	return { id = t.id, status = snap.status, settings = snap.settings, seats = snap.seats }
end

Lobby.OnServerInvoke = function(player, verb, tableId, arg)
	if not allowed(player) then
		return false, "slow down"
	end
	if verb == "list" then
		local out = {}
		for i = 1, Settings.TABLE_COUNT do
			table.insert(out, summary(tables["T" .. i]))
		end
		return true, out
	elseif verb == "stats" then -- { results, vip, games (VIP only: saved reviews, newest first) }
		local vip = Vip.owns(player)
		return true, { results = Results.get(player.UserId), vip = vip, games = if vip then SavedGames.list(player.UserId) else nil }
	elseif verb == "saveGame" then -- arg = review record; VIP only
		if not Vip.owns(player) then
			return false, "vip only"
		end
		return SavedGames.save(player.UserId, arg)
	elseif verb == "savedGame" then -- arg = id -> the full game
		if not Vip.owns(player) or type(arg) ~= "string" then
			return false, "vip only"
		end
		return true, SavedGames.get(player.UserId, arg)
	elseif verb == "deleteGame" then
		if not Vip.owns(player) or type(arg) ~= "string" then
			return false, "vip only"
		end
		return SavedGames.delete(player.UserId, arg)
	elseif verb == "getPrefs" then
		return true, Prefs.get(player.UserId)
	elseif verb == "setPrefs" then -- arg = { theme?, sound? }; returns the saved prefs
		return true, Prefs.set(player.UserId, arg)
	elseif verb == "wallet" then -- { coins, owned, vip }
		local w = Wallet.view(player.UserId)
		w.vip = Vip.owns(player)
		return true, w
	elseif verb == "buy" then
		return Wallet.buy(player.UserId, arg)
	elseif verb == "quick" then
		return quickPlay(player, arg)
	elseif verb == "tourney" then
		if isTournamentServer then
			return true, Runner.view()
		end
		return Launcher.state(player)
	elseif verb == "tourneyStart" then
		if isTournamentServer then
			return false, "you're in a tournament"
		end
		if not Vip.owns(player) then
			return false, "vip only"
		end
		return Launcher.start(participantFor(player))
	elseif verb == "tourneyJoin" or verb == "tourneyLeave" then
		if isTournamentServer then
			return false, "you're in a tournament"
		end
		return (if verb == "tourneyJoin" then Launcher.join else Launcher.leave)(participantFor(player))
	elseif verb == "tourneyWatch" then
		if isTournamentServer then
			return false, "you're already here"
		end
		return Launcher.watch(player)
	elseif verb == "today" then
		return true, DailyLog.today()
	elseif verb == "todayGame" then
		local g = DailyLog.game(arg)
		if not g then
			return false, "that game isn't in today's log"
		end
		return true, g
	elseif verb == "leaderboard" then -- arg = "wins" | "titles"
		if arg ~= "wins" and arg ~= "titles" then
			return false, "no such board"
		end
		return true, { board = arg, top = Leaderboards.top(arg, 10), mine = Leaderboards.mine(player.UserId) }
	elseif verb == "botLevels" then
		local out = {}
		for _, l in Search.LEVELS do
			table.insert(out, { id = l.id, name = l.name })
		end
		return true, out
	end
	local t = type(tableId) == "string" and tables[tableId]
	if not t then
		return false, "no such table"
	end
	if verb == "sit" then
		return sitPlayer(player, tableId, arg)
	end
	if t.owner then
		return false, "this table is for the tournament"
	end
	if verb == "stand" then
		return t:stand(player.UserId)
	elseif verb == "configure" then
		return t:configure(player.UserId, arg)
	elseif verb == "ready" then
		return t:setReady(player.UserId, arg == true)
	elseif verb == "addBot" then
		return t:addBot(player.UserId, arg)
	elseif verb == "removeBot" then
		return t:removeBot(player.UserId)
	elseif verb == "botLevel" then
		return t:setBotLevel(player.UserId, arg)
	end
	return false, "unknown verb"
end

RequestAction.OnServerEvent:Connect(function(player, tableId, action)
	if not allowed(player) then
		return
	end
	local t = type(tableId) == "string" and tables[tableId]
	if not t then
		return
	end
	local ok, err = t:requestAction(player.UserId, action)
	if not ok then
		State:FireClient(player, { type = "rejected", tableId = tableId, seq = t.seq, reason = err })
	end
end)

TableCommand.OnServerEvent:Connect(function(player, tableId, cmd)
	if not allowed(player) then
		return
	end
	local t = type(tableId) == "string" and tables[tableId]
	if not t or type(cmd) ~= "string" then
		return
	end
	if cmd == "snapshot" then
		State:FireClient(player, t:snapshot())
		return
	end
	local ok, err = t:command(player.UserId, cmd)
	if not ok then
		State:FireClient(player, { type = "rejected", tableId = tableId, seq = t.seq, reason = err })
	end
end)

Players.PlayerAdded:Connect(function(player)
	task.spawn(Wallet.get, player.UserId) -- loaded before their first game needs it
	task.spawn(Passes.preload, player.UserId)
	for _, t in tables do
		t:playerRejoined(participantFor(player))
	end
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Humanoid", 10)
		task.wait(0.5)
		Seating.syncPlayer(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
	Prefs.forget(player.UserId)
	Wallet.forget(player.UserId)
	for _, t in tables do
		t:playerLeft(player.UserId)
	end
end)

-- an ability gamepass bought in this server: the Shop shows it owned at once
Passes.onBought(function(userId)
	Wallet.refresh(userId)
end)

-- Steal a Piece purchases. Granted once per receipt (the wallet remembers receipt ids); if it can't
-- be saved yet, Roblox retries later.
local function processReceipt(info)
	if info.ProductId ~= Settings.STEAL_PRODUCT then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not Wallet.grantSteal(info.PlayerId, tostring(info.PurchaseId)) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local t = tableOf(info.PlayerId)
	if t then
		t:grantSteal(info.PlayerId) -- mid-game: usable right away
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
MarketplaceService.ProcessReceipt = processReceipt

-- Tournaments: the lobby announces and launches them; a tournament server plays one.
if isTournamentServer then
	if not studioTournament then
		Runner.start({ tables = tables, remote = TournamentRemote, participantFor = participantFor })
	end
else
	Launcher.init(TournamentRemote)
	task.spawn(require(script.Parent.LobbyBoards).start) -- the big leaderboard screens in the lobby
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.1 then
		return
	end
	acc = 0
	for _, t in tables do
		local ok, err = pcall(t.tick, t)
		if not ok then
			warn("[Chess] table tick failed:", t.id, err)
		end
	end
end)

-- Studio test driver ------------------------------------------------------------------------------
if isStudio then
	local hook = ServerStorage:FindFirstChild("ChessDebug") or Instance.new("BindableFunction")
	hook.Name = "ChessDebug"
	hook.Parent = ServerStorage
	local function fake(userId, name)
		return { userId = userId, name = name or ("Test" .. -userId) }
	end
	hook.OnInvoke = function(verb, tableId, ...)
		local args = { ... }
		if verb == "vip" then -- ("vip", userId, on|nil): pretend to own (or not own) the VIP pass
			Vip.override(tableId, args[1])
			return true
		end
		if verb == "wallet" then -- ("wallet", userId, coins?, ownedIds?, steals?): a session-only test wallet
			return true, Wallet.debugSet(tableId, args[1], args[2], args[3])
		end
		if verb == "passes" then -- ("passes", userId, false|nil): pretend to own no ability gamepass
			Passes.override(tableId, args[1])
			return true
		end
		if verb == "receipt" then -- ("receipt", userId, purchaseId): as if a Steal a Piece was bought
			return true, processReceipt({ PlayerId = tableId, ProductId = Settings.STEAL_PRODUCT, PurchaseId = args[1] })
		end
		if verb == "tourneyLocal" then -- ("tourneyLocal", nBots, botTime?, withPlayers?): play a bracket here with
			-- bots (and the players in this server, when withPlayers)
			local bots = {}
			for i = 1, tableId or 8 do
				table.insert(bots, { userId = -500 - i, name = "Bot " .. i, isBot = true, level = 1 + (i % 2) })
			end
			if args[2] then
				for _, pl in Players:GetPlayers() do
					table.insert(bots, participantFor(pl))
				end
			end
			Runner.start({ tables = tables, remote = TournamentRemote, participantFor = participantFor,
				test = { players = bots, botSpeed = { time = args[1] or 0.05, think = args[1] or 0 } } })
			return true
		end
		if verb == "tourneyFake" then -- ("tourneyFake", n): add n fake players to the open tournament (Studio map)
			local Registry = require(TournamentFolder.Registry)
			local out
			for i = 1, tableId or 1 do
				local ok, rec = Registry.join({ userId = -700 - i, name = "Fake " .. i })
				out = if ok then #rec.players else rec
			end
			return true, out
		end
		if verb == "tourneyStartsIn" then -- ("tourneyStartsIn", seconds): shorten the open tournament's countdown
			local Registry = require(TournamentFolder.Registry)
			return Registry.update(function(old)
				if not old or old.state ~= "open" then
					return nil, "none open"
				end
				old.startsAt = os.time() + (tableId or 5)
				return old
			end)
		end
		if verb == "lbFake" then -- ("lbFake", n, board?, mine?): n fake entries (ids -901...) with random
			-- values on the board ("wins" | "titles", nil = both), in the _studio stores; mine = a
			-- number also puts every player in this server on it with that value
			local made = 0
			for _, board in Leaderboards.BOARDS do
				if args[1] == nil or args[1] == board then
					for i = 1, tableId or 12 do
						local most = if board == "wins" then 120 else 8
						if Leaderboards.debugSet(board, -900 - i, math.random(1, most), "Fake " .. i) then
							made += 1
						end
					end
					if type(args[2]) == "number" then
						for _, pl in Players:GetPlayers() do
							Leaderboards.debugSet(board, pl.UserId, args[2])
						end
					end
				end
			end
			return true, made
		end
		if verb == "tourneyClear" then -- end the Studio tournament record
			local Registry = require(TournamentFolder.Registry)
			return Registry.update(function(old)
				if not old then
					return nil, "none"
				end
				old.state = "cancelled"
				old.reason = "cleared in Studio"
				return old
			end)
		end
		if verb == "reset" then
			debugLog[tableId] = nil
			local old = tables[tableId]
			local t = makeTable(tableId)
			t.seq = if old then old.seq else 0 -- keep counting, so clients accept the new table's snapshots
			t:sendSnapshot()
			return true
		end
		local t = tables[tableId]
		if not t then
			return false, "no such table"
		end
		if verb == "sit" then
			return t:sit(fake(args[1], args[3]), args[2])
		elseif verb == "stand" then
			return t:stand(args[1])
		elseif verb == "configure" then
			return t:configure(args[1], args[2])
		elseif verb == "ready" then
			return t:setReady(args[1], args[2] ~= false)
		elseif verb == "move" then -- (userId, "e4" | "e2e4")
			if not t.game then
				return false, "no game"
			end
			local m = Notation.parseMove(t.game, args[2])
			if not m then
				return false, "can't parse " .. tostring(args[2])
			end
			return t:requestAction(args[1], { kind = "move", from = m.from, to = m.to, promotion = m.promotion })
		elseif verb == "action" then -- raw action table, as a client would send it
			return t:requestAction(args[1], args[2])
		elseif verb == "command" then
			return t:command(args[1], args[2])
		elseif verb == "leave" then
			t:playerLeft(args[1])
			return true
		elseif verb == "rejoin" then
			return t:playerRejoined(fake(args[1], args[2]))
		elseif verb == "advance" then -- move this table's clock forward by n seconds
			t.timeOffset += args[1]
			t:tick()
			return true
		elseif verb == "addBot" then -- (level, color): seats a bot directly, no human needed
			return t:seatBot(args[1], args[2])
		elseif verb == "playerAddBot" then -- (userId, level): as the lobby does it
			return t:addBot(args[1], args[2])
		elseif verb == "removeBot" then
			return t:removeBot(args[1])
		elseif verb == "start" then -- (fen?) start now: bot vs bot, or from a test position
			if t.status == "playing" then
				return false, "already playing"
			end
			t:start(args[1])
			return true
		elseif verb == "botSpeed" then -- (time, think) override for bot levels; nil time clears it
			t.botSpeed = if args[1] then { time = args[1], think = args[2] or 0 } else nil
			return true
		elseif verb == "snapshot" then
			return true, t:snapshot()
		elseif verb == "log" then
			return true, debugLog[tableId] or {}
		end
		return false, "unknown verb"
	end
end
