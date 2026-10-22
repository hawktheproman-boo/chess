-- Client side of the chess tables: mirrors every table's game from the server's State stream, draws
-- the boards (BoardView), and when you're seated runs the camera, the HUD and your input
-- (mouse click/drag, touch tap/drag, controller cursor). The server decides everything; this
-- script only requests (Remotes.RequestAction / TableCommand / Lobby).

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = require(Shared.Chess.Game)
local Settings = require(Shared.Settings)
local Search = require(Shared.Bot.Search)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local BoardView = require(script.Parent.BoardView)
local Pieces = require(script.Parent.Pieces)
local CameraRig = require(script.Parent.CameraRig)
local Device = require(script.Parent.Device)
local Hud = require(script.Parent.Hud)
local Cutscene = require(script.Parent.Cutscene)
local Snipe = require(Shared.Abilities.BishopSnipe)
local RookRam = require(Shared.Abilities.RookRam)
local KnightJump = require(Shared.Abilities.KnightJump)
local KingEscape = require(Shared.Abilities.KingEscape)
local PawnPassant = require(Shared.Abilities.PawnPassant)
local Steal = require(Shared.Abilities.StealPiece)
local AbilityBar = require(script.Parent.AbilityBar)
local AbilitiesMode = require(Shared.Modes.Abilities)
local Board2D = require(script.Parent.Board2D)
local LobbyHud = require(script.Parent.LobbyHud)
local Sounds = require(script.Parent.Sounds)
local SettingsPanel = require(script.Parent.SettingsPanel)
local Music = require(script.Parent.Music)
local ReviewPanel = require(script.Parent.ReviewPanel)
local PlayScreen = require(script.Parent.PlayScreen)
local TournamentBanner = require(script.Parent.TournamentBanner)
local BracketPanel = require(script.Parent.BracketPanel)
local StageScreen = require(script.Parent.StageScreen)
local LobbyAmbience = require(script.Parent.LobbyAmbience)
local Ui = require(script.Parent.UiKit)
local Themes = require(Shared.Themes)

-- the player's settings (loaded from the server below); paintBoard colours one 3D table with them
local prefs = { theme = Themes.DEFAULT, sound = true, music = true, autoQueen = false, pieceSet = Settings.DEFAULT_PIECE_SET }
local openSettings -- (defined with the settings panel)
local openReview -- (defined with the review panel)
local reviewSavedGame -- (id) open a saved game's review, also defined there
local reviewTodayGame -- (id) open one of today's logged tournament games, also defined there
local isTournamentServer = ReplicatedStorage:GetAttribute("TournamentServer") == true
local bracketPanel -- the tournament server's bracket (BracketPanel), created with the lobby HUD
local function paintBoard(model)
	local theme = Themes.get(prefs.theme)
	local board = model:FindFirstChild("Board")
	if board then
		for _, p in board:GetChildren() do
			local sq = p:GetAttribute("Square")
			if sq then
				p.Color = if (sq % 16 + sq // 16) % 2 == 1 then theme.light else theme.dark
			end
		end
	end
	for _, side in { "FrameN", "FrameS", "FrameE", "FrameW" } do
		local f = model:FindFirstChild(side)
		if f then
			f.Color = theme.frame
		end
	end
end

-- While seated, jumping is off (it would pop you out of the chair; the controller's A picks pieces).
local seatedNow = false
local function setJump(enabled)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, enabled)
	end
end
player.CharacterAdded:Connect(function(char)
	char:WaitForChild("Humanoid", 10)
	if seatedNow then
		setJump(false)
	end
end)

local VALUE = { p = 1, n = 3, b = 3, r = 5, q = 9 }
local REJECT_TEXT = {
	["not your turn"] = "It's not your turn",
	["illegal move"] = "That move isn't legal",
	["seat taken"] = "That seat is taken",
	["finish your game first"] = "Finish your game first",
	["a game is in progress"] = "A game is in progress",
	["make a move before offering again"] = "Make a move before offering another draw",
	["slow down"] = "Slow down a little",
}

-- Tables -------------------------------------------------------------------------------------------
local views, states, boards = {}, {}, {}
local setupTable -- (defined below, once the state handling exists)

-- A light on the ground around each table: green while a seat is free, grey when it's full or a
-- game is on. A ring and a soft glow drawn by a SurfaceGui on an invisible slab just above the
-- floor (never coplanar with it), plus a real PointLight while it's green.
local LIGHT_FREE = Color3.fromRGB(92, 230, 90)
local LIGHT_FULL = Color3.fromRGB(150, 156, 160)
local PULSE = TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local function makeGroundLight(model, parent)
	local cf, size = model:GetBoundingBox()
	local diameter = math.max(size.X, size.Z) + 3
	local slab = Instance.new("Part")
	slab.Name = "GroundLight"
	slab.Anchored, slab.CanCollide, slab.CanQuery, slab.CanTouch, slab.CastShadow = true, false, false, false, false
	slab.Transparency = 1
	slab.Size = Vector3.new(diameter, 0.1, diameter)
	slab.CFrame = CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2 + 0.08, cf.Position.Z)
	slab.Parent = parent
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.Parent = slab
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.Size = UDim2.fromScale(1, 1)
	glow.BackgroundColor3 = Color3.new(1, 1, 1)
	glow.BorderSizePixel = 0
	glow.Parent = gui
	Ui.corner(glow).CornerRadius = UDim.new(0.5, 0)
	local fade = Instance.new("UIGradient") -- brightest at the rim, clear in the middle
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(0.85, 0.75),
		NumberSequenceKeypoint.new(1, 0.45),
	})
	fade.Parent = glow
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.new(1, -24, 1, -24)
	ring.BackgroundTransparency = 1
	ring.Parent = gui
	Ui.corner(ring).CornerRadius = UDim.new(0.5, 0)
	local rim = Instance.new("UIStroke")
	rim.Thickness = 10
	rim.Color = Color3.new(1, 1, 1)
	rim.Parent = ring
	local lamp = Instance.new("PointLight")
	lamp.Range = diameter * 0.6
	lamp.Brightness = 1.2
	lamp.Shadows = false
	lamp.Parent = slab
	local pulse = TweenService:Create(rim, PULSE, { Transparency = 0.45 })
	return { glow = glow, rim = rim, lamp = lamp, pulse = pulse, free = nil }
end

local function setGroundLight(light, free)
	if light.free == free then
		return
	end
	light.free = free
	local color = if free then LIGHT_FREE else LIGHT_FULL
	light.glow.BackgroundColor3 = color
	light.rim.Color = color
	light.lamp.Color = color
	light.lamp.Enabled = free
	light.rim.Transparency = if free then 0 else 0.35
	if free then
		light.pulse:Play()
	else
		light.pulse:Cancel()
		light.rim.Transparency = 0.35
	end
end

local function setupTableNow(model)
	local id = model:GetAttribute("TableId")
	local board = model:WaitForChild("Board", 30)
	if not id or not board or views[id] then
		return
	end
	local t0 = os.clock()
	while #board:GetChildren() < 64 and os.clock() - t0 < 30 do
		task.wait(0.2) -- table models are Persistent, but may still be arriving
	end
	if not model.PrimaryPart then
		model:GetPropertyChangedSignal("PrimaryPart"):Wait()
	end
	do
		local view = BoardView.new(model)
		views[id] = view
		paintBoard(model)
		states[id] = { seq = -1, meta = nil, game = nil, display = Game.new(), lastRequest = 0 }
		boards[id] = { light = makeGroundLight(model, view.folder) }
		view:sync(states[id].display, false)
	end
	setupTable(id)
end

local function requestSnapshot(id)
	local st = states[id]
	if os.clock() - st.lastRequest > 1 then
		st.lastRequest = os.clock()
		Remotes.TableCommand:FireServer(id, "snapshot")
	end
end

-- Seated state -------------------------------------------------------------------------------------
local mine = nil -- { id, color }
local ui = { selected = nil, legal = {}, targets = {}, cursor = nil, drag = nil, autoQueen = false, tilted = true, botLevel = 3,
	mode2D = false }
local hud
local board2d -- the flat GUI board (2D mode), created below
local lobbyHud -- the not-seated HUD (Play vs Bot / Player, Tables, Stats), created below
local playScreen -- the Play screen (mode cards), created after the lobby HUD
local bindLobbyMenu -- (defined with the lobby HUD)

local function myState()
	return mine and states[mine.id]
end

-- what to draw: your own move shows right away (predicted) while the server confirms it
local function currentGame(st)
	return st.predicted or st.game or st.display
end

-- where a table's sounds are heard: flat at your own table, from the board when you're nearby
local function soundAt(id)
	if mine and mine.id == id then
		return true, nil
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and views[id] and (root.Position - views[id].center).Magnitude < 60 then
		return true, views[id].center
	end
	return false, nil
end

local function lobby(verb, id, arg)
	task.spawn(function()
		local ok, err = Remotes.Lobby:InvokeServer(verb, id, arg)
		if ok == false then
			local text = REJECT_TEXT[err] or tostring(err)
			if mine and hud then
				hud:toast(text)
			elseif lobbyHud then
				lobbyHud:toast(text)
			end
		end
	end)
end

local function material(game)
	local m = { w = 0, b = 0 }
	for _, p in game.board.sq do
		m[p.color] += VALUE[p.type] or 0
	end
	return m
end

local updateHud, canAct, refresh -- (defined below)

-- the side to move's legal ability actions (all of them), from the mirror game
local function abilityActionsFor(st)
	local game = st and st.game
	if not (game and game.mode and game.mode.abilityActions) then
		return {}
	end
	return game.mode.abilityActions(game)
end

-- Ability aiming. Tap a glowing piece to see what its ability can do, then tap a target:
--   Snipe / Battering Ram: any square on a line;  Double Jump: the first landing, then the second;
--   Royal Escape: the square to land on.
-- Returns the marks for the current pick ({ targets, tints, selected }).
local function abilityMarks(game)
	local marks = { targets = {}, tints = {}, selected = ui.abMid or ui.abFrom }
	local seen = {}
	for _, a in ui.abActions do
		if not seen[a.from] then
			seen[a.from] = true
			table.insert(marks.tints, a.from)
		end
		if ui.abFrom == a.from then
			local sq = game.board.sq
			if a.id == "BishopSnipe" then
				for _, s in Snipe.path(game, a.from, a.dir) do
					marks.targets[s] = if sq[s] and sq[s].type ~= "k" then "capture" else "move"
				end
			elseif a.id == "RookRam" then
				local t = RookRam.trace(game, a.from, a.dir)
				for _, s in t.path do
					marks.targets[s] = if sq[s] then "capture" else "move"
				end
			elseif a.id == "KnightJump" then
				if not ui.abMid then
					marks.targets[a.mid] = if sq[a.mid] then "capture" else "move"
				elseif a.mid == ui.abMid then
					marks.targets[a.to] = if sq[a.to] and a.to ~= a.from then "capture" else "move"
				end
			elseif a.id == "PawnPassant" then
				marks.targets[PawnPassant.target(game, a)] = "capture"
				marks.targets[a.to] = "move"
			elseif a.id == "StealPiece" then
				marks.targets[a.from] = "capture"
			else -- KingEscape
				marks.targets[a.to] = if sq[a.to] then "capture" else "move"
			end
		end
	end
	return marks
end

local function updateMarks()
	local st = myState()
	if not st then
		return
	end
	local game = currentGame(st)
	local marks = { targets = ui.targets, selected = ui.selected }
	if ui.targeting then
		marks = abilityMarks(st.game)
	end
	local last = game.history[#game.history]
	if last and last.action.from then
		marks.lastFrom, marks.lastTo = last.action.from, last.action.to
	end
	if st.game and st.meta and st.meta.status ~= "waiting" and game:inCheck() then
		marks.check = game.board.kings[game.turn]
	end
	if Device.current == "pad" then
		marks.cursor = ui.cursor
	end
	views[mine.id]:setMarks(marks)
	board2d:setMarks(marks)
end

local exitTargeting, playAbility, abilityPrompt, abilityStates, aimAbility -- (defined below)

-- Steal a Piece, for the HUD button: "buy" (no paid steal this game: the button prompts the Robux
-- product), "ready" (yours to use) or "used"
local stealPrice = Settings.STEAL_ROBUX
task.spawn(function()
	local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, Settings.STEAL_PRODUCT, Enum.InfoType.Product)
	if ok and info and type(info.PriceInRobux) == "number" then
		stealPrice = info.PriceInRobux
	end
end)
local function stealState(st)
	if not (st and st.game and st.meta and mine) or st.meta.tournament then
		return nil -- (never in a tournament game)
	end
	local granted = st.meta.steal and st.meta.steal[mine.color]
	if not granted then
		return { state = "buy", price = stealPrice }
	end
	return { state = if Steal.charges(st.game, mine.color) > 0 then "ready" else "used", price = stealPrice }
end

local function deselect()
	ui.selected, ui.legal, ui.targets, ui.drag = nil, {}, {}, nil
	updateMarks()
end

-- the ability panel's cards: { [id] = { charges, ready } } for your colour
abilityStates = function(st)
	local out = {}
	local game = st.game
	if not (game and game.abilityState) then
		return out
	end
	local usable = {}
	if canAct() then
		for _, a in abilityActionsFor(st) do
			usable[a.id] = true
		end
	end
	-- abilities you haven't bought (Shop) are locked; no loadout = you have them all
	local loadout = st.meta and st.meta.loadout
	local mineList = loadout and loadout[mine.color]
	for _, ability in AbilitiesMode.list do
		out[ability.id] = { charges = ability.charges(game, mine.color), ready = usable[ability.id] == true,
			locked = mineList ~= nil and table.find(mineList, ability.id) == nil }
	end
	return out
end

updateHud = function()
	local st = myState()
	if not (st and st.meta and hud) then
		return
	end
	-- Abilities tables keep a strip along the bottom of wide screens for the ability panel
	local strip = st.meta.settings.mode == "Abilities"
	board2d:setStrip(strip)
	CameraRig.setStrip(strip)
	local meta = st.meta
	local game = currentGame(st)
	local sans = {}
	if st.game then
		for _, h in st.game.history do
			table.insert(sans, h.san)
		end
	end
	local me = meta.seats[mine.color]
	local clock = Settings.clock(meta.settings.clock)
	hud:update({
		label = "Table " .. string.sub(mine.id, 2),
		myColor = mine.color,
		status = meta.status,
		seats = meta.seats,
		settings = meta.settings,
		drawOffer = meta.drawOffer,
		result = meta.result,
		sans = sans,
		material = material(game),
		turn = game.turn,
		ready = me and me.ready,
		botLevelName = Search.LEVELS[ui.botLevel].name,
		clockLabel = clock and clock.label or meta.settings.clock,
		autoQueen = ui.autoQueen,
		tilted = ui.tilted,
		mode2D = ui.mode2D,
		targeting = ui.targeting,
		abilities = abilityStates(st),
		steal = stealState(st),
		targetingId = ui.abFilter,
		showKeys = Device.current == "mouse",
	})
end

exitTargeting = function()
	ui.targeting, ui.abActions, ui.abFrom, ui.abMid, ui.abFilter = false, {}, nil, nil, nil
	updateMarks()
	updateHud()
end

-- An ability's cutscene: the camera move only for the two players at that table; nearby spectators
-- see the effects; far away it just updates. Board syncs wait until it's over.
-- info: what the ability did, worked out before it was applied (snipe hits, ram trace, ...)
playAbility = function(id, action, info)
	local st = states[id]
	local view = views[id]
	local seated = mine ~= nil and mine.id == id
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local near = seated or (root ~= nil and (root.Position - view.center).Magnitude < 90)
	if not near then
		return
	end
	st.cutscene = true
	st.cutsceneId = action.id
	if seated then
		exitTargeting()
		deselect()
		hud:setVisible(false, true) -- a clean frame; a game-over card waits until the cutscene is done
		if ui.mode2D then
			board2d:setVisible(false) -- the cutscene is 3D; 2D comes back after
		end
	end
	task.spawn(function()
		local opts = {
			camera = seated,
			onHit = function(sq)
				view:popAt(sq)
			end,
			done = function()
				st.cutscene = false
				if seated and mine and mine.id == id then
					hud:setVisible(true)
					if ui.mode2D then
						board2d:setVisible(true)
					end
				end
				refresh(id, false)
			end,
		}
		if action.id == "BishopSnipe" then
			Cutscene.snipe(view, action.from, action.dir, info, opts)
		else
			Cutscene.ability(view, action.id, action, info, opts)
		end
	end)
end

local HINTS = {
	mouse = "Click or drag a piece",
	touch = "Tap or drag a piece",
	pad = "A: pick / drop  ·  B: cancel  ·  Y: menu",
}

canAct = function()
	local st = myState()
	return st ~= nil and st.game ~= nil and st.meta.status == "playing" and st.game.turn == mine.color
		and not hud.promo.Visible and not hud.confirmFrame.Visible and not st.cutscene and not st.predicted
end

local function send(from, to, promotion)
	local action = { kind = "move", from = from, to = to, promotion = promotion }
	Remotes.RequestAction:FireServer(mine.id, action)
	deselect()
	-- predict: play the move on a copy now, so the piece moves without waiting for the server.
	-- The server's echo then lands on the same position (nothing moves again); a reject puts it back.
	local st = myState()
	local guess = st.game:clone()
	if guess:apply(action) then
		st.predicted = guess
		Sounds.forMove(guess.history[#guess.history].san)
		refresh(mine.id, true)
	end
end

local function attempt(from, to)
	local promo = false
	for _, m in ui.legal do
		if m.to == to and m.promotion then
			promo = true
		end
	end
	if not promo then
		send(from, to, nil)
	elseif ui.autoQueen then
		send(from, to, "q")
	else
		hud:showPromotion(function(kind)
			send(from, to, kind)
		end, mine.color)
	end
end

local function selectSquare(sq)
	local st = myState()
	local game = st.game
	ui.selected = sq
	ui.legal = game:legalMoves(sq)
	ui.targets = {}
	for _, m in ui.legal do
		ui.targets[m.to] = if game.board.sq[m.to] or m.flag == "ep" then "capture" else "move"
	end
	updateMarks()
end

local ABILITY_NAMES = { BishopSnipe = "Snipe", KnightJump = "Double Jump", RookRam = "Battering Ram",
	QueenSwap = "Swap", KingEscape = "Royal Escape", PawnPassant = "Any Passant", StealPiece = "Steal a Piece" }

-- Aim an ability (id) or every ability (nil): the pieces that can use it glow. Pressing the same
-- card again cancels. A piece that's the only one with it is picked straight away.
aimAbility = function(id)
	if ui.targeting and ui.abFilter == id then
		exitTargeting()
		return
	end
	local st = myState()
	if not (st and st.game and st.game.abilityState and (st.meta.settings.mode == "Abilities" or id == "StealPiece")) then
		return
	end
	if not canAct() then
		hud:toast("Wait for your turn")
		return
	end
	local acts = {}
	for _, a in abilityActionsFor(st) do
		if id == nil or a.id == id then
			table.insert(acts, a)
		end
	end
	local name = id and ABILITY_NAMES[id]
	local loadout = st.meta.loadout and st.meta.loadout[mine.color]
	if id and id ~= "StealPiece" and loadout and not table.find(loadout, id) then
		hud:toast("Unlock " .. name .. " in the Shop")
		if ui.targeting then
			exitTargeting()
		end
		return
	end
	if #acts == 0 then
		local ability = id and AbilitiesMode.byId[id]
		local used = if ability then ability.charges(st.game, mine.color) < 1 else AbilitiesMode.chargesLeft(st.game, mine.color) < 1
		hud:toast(if used then (if name then name .. " is used up" else "All abilities used")
			else (if name then "Nothing to use " .. name .. " on right now" else "No ability can be used now"))
		if ui.targeting then
			exitTargeting()
		end
		return
	end
	deselect()
	ui.targeting, ui.abActions, ui.abFrom, ui.abMid, ui.abFilter = true, acts, nil, nil, id
	local froms = {}
	for _, a in acts do
		froms[a.from] = true
	end
	local only = next(froms)
	if next(froms, only) == nil then
		ui.abFrom = only -- one piece has it: skip straight to its targets
		hud:toast(if name then name .. ": pick a target" else "Pick a target")
	else
		hud:toast(if name then name .. ": tap a glowing piece" else "Tap a glowing piece")
	end
	updateMarks()
	updateHud()
end

-- "Use Double Jump? ..." for the confirm dialog
abilityPrompt = function(game, a)
	local name = ABILITY_NAMES[a.id] or "this ability"
	local n
	if a.id == "BishopSnipe" then
		n = #Snipe.hits(game, a.from, a.dir)
	elseif a.id == "RookRam" then
		n = #RookRam.trace(game, a.from, a.dir).hits
	elseif a.id == "KnightJump" then
		n = #KnightJump.hits(game, a)
	elseif a.id == "KingEscape" then
		n = #KingEscape.hits(game, a)
	elseif a.id == "PawnPassant" then
		n = 1
	elseif a.id == "StealPiece" then
		local p = game.board.sq[a.from]
		local names = { p = "pawn", n = "knight", b = "bishop", r = "rook" }
		return string.format("Steal this %s? It becomes yours.", names[p and p.type or "p"] or "piece")
	end
	local what = if n and n > 0 then string.format(" (takes %d piece%s)", n, if n == 1 then "" else "s") else ""
	return string.format("Use %s%s? Once per game.", name, what)
end

-- a click / tap / A press on a square
local function press(sq, allowDrag)
	if not sq then
		deselect()
		return
	end
	if not canAct() then
		return
	end
	local game = myState().game
	if ui.targeting and ui.abFilter == "StealPiece" then
		-- Steal a Piece: a tap on a glowing enemy piece takes it (after the confirm)
		for _, a in ui.abActions do
			if a.from == sq then
				local tableId = mine.id
				local clean = { kind = "ability", id = a.id, from = a.from }
				hud:confirm(abilityPrompt(game, a), function()
					Remotes.RequestAction:FireServer(tableId, clean)
				end, Ui.ICONS.steal)
				exitTargeting()
				return
			end
		end
		exitTargeting()
		return
	end
	if ui.targeting then
		local target = abilityMarks(game).targets[sq]
		if ui.abFrom and target then
			-- a target of the picked piece: fire (or, for a double jump, pick the first landing)
			for _, a in ui.abActions do
				if a.from == ui.abFrom then
					local hit = false
					if a.id == "BishopSnipe" then
						hit = table.find(Snipe.path(game, a.from, a.dir), sq) ~= nil
					elseif a.id == "RookRam" then
						hit = table.find(RookRam.trace(game, a.from, a.dir).path, sq) ~= nil
					elseif a.id == "PawnPassant" then
						hit = a.to == sq or PawnPassant.target(game, a) == sq
					elseif a.id == "KnightJump" then
						if not ui.abMid then
							if a.mid == sq then
								ui.abMid = sq
								updateMarks()
								return
							end
						else
							hit = a.mid == ui.abMid and a.to == sq
						end
					else
						hit = a.to == sq
					end
					if hit then
						local tableId = mine.id
						local clean = { kind = "ability", id = a.id, from = a.from, dir = a.dir, mid = a.mid, to = a.to }
						hud:confirm(abilityPrompt(game, a), function()
							Remotes.RequestAction:FireServer(tableId, clean)
						end, Ui.ICONS.Abilities)
						exitTargeting()
						return
					end
				end
			end
		end
		-- a glowing piece picks it (again: unpicks it)
		for _, a in ui.abActions do
			if a.from == sq then
				ui.abFrom = if ui.abFrom == sq then nil else sq
				ui.abMid = nil
				updateMarks()
				return
			end
		end
		if ui.abMid then -- off target: step back to the first landing
			ui.abMid = nil
			updateMarks()
			return
		end
		exitTargeting()
		return
	end
	if ui.selected and ui.targets[sq] then
		attempt(ui.selected, sq)
		return
	end
	local piece = game.board.sq[sq]
	if piece and piece.color == mine.color and sq ~= ui.selected then
		selectSquare(sq)
		if allowDrag then
			ui.drag = { from = sq, moved = false }
		end
	elseif sq == ui.selected and allowDrag then
		ui.drag = { from = sq, moved = false } -- pick it up again to drag
	else
		deselect()
	end
end

local function boardPoint(screenPos)
	local view = mine and views[mine.id]
	if not view then
		return nil
	end
	local ray = workspace.CurrentCamera:ScreenPointToRay(screenPos.X, screenPos.Y)
	if math.abs(ray.Direction.Y) < 1e-4 then
		return nil
	end
	local t = (view.topY - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then
		return nil
	end
	return ray.Origin + ray.Direction * t
end

-- Controller cursor -----------------------------------------------------------------------------------
local function moveCursor(dx, dy)
	local sign = if mine.color == "w" then 1 else -1
	local file = (ui.cursor % 16) + dx * sign
	local rank = (ui.cursor // 16) + dy * sign
	ui.cursor = math.clamp(rank, 0, 7) * 16 + math.clamp(file, 0, 7)
	updateMarks()
end

local stick = Vector2.zero
local nextStep = 0

local function bindActions()
	ContextActionService:BindActionAtPriority("ChessPick", function(_, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if GuiService.SelectedObject then
			return Enum.ContextActionResult.Pass -- a button is focused: let it activate
		end
		press(ui.cursor, false)
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.ButtonA)
	ContextActionService:BindActionAtPriority("ChessBack", function(_, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if hud.confirmFrame.Visible then
			hud.confirmFrame.Visible = false
			hud.onConfirm = nil
			hud:refocus()
		elseif hud.promo.Visible then
			hud:hidePromotion()
		elseif ui.targeting then
			exitTargeting()
		elseif hud.menuOpen then
			hud:toggleMenu()
		else
			deselect()
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.ButtonB)
	ContextActionService:BindActionAtPriority("ChessMenu", function(_, state)
		if state == Enum.UserInputState.Begin then
			hud:toggleMenu()
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.ButtonY)
	ContextActionService:BindActionAtPriority("ChessSnipe", function(_, state)
		if state == Enum.UserInputState.Begin then
			hud.cb.ability()
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.ButtonX, Enum.KeyCode.F)
	local NUMBER_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six }
	ContextActionService:BindActionAtPriority("ChessAbilityKeys", function(_, state, input)
		local st = myState()
		if state ~= Enum.UserInputState.Begin or not (st and st.meta and st.meta.settings.mode == "Abilities") then
			return Enum.ContextActionResult.Pass
		end
		local i = table.find(NUMBER_KEYS, input.KeyCode)
		local card = i and AbilityBar.CARDS[i]
		if card then
			aimAbility(card.id)
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, table.unpack(NUMBER_KEYS))
	ContextActionService:BindActionAtPriority("ChessView", function(_, state)
		if state == Enum.UserInputState.Begin then
			hud.cb.toggle2D()
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.ButtonR1, Enum.KeyCode.V)
	ContextActionService:BindActionAtPriority("ChessTilt", function(_, state)
		if state == Enum.UserInputState.Begin then
			ui.tilted = not ui.tilted
			CameraRig.setTilted(ui.tilted)
			updateHud()
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.ButtonL1, Enum.KeyCode.T)
	ContextActionService:BindActionAtPriority("ChessCursor", function(_, state, input)
		if GuiService.SelectedObject then
			return Enum.ContextActionResult.Pass
		end
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			stick = Vector2.new(input.Position.X, input.Position.Y)
			return Enum.ContextActionResult.Sink
		end
		if state == Enum.UserInputState.Begin then
			local k = input.KeyCode
			moveCursor(if k == Enum.KeyCode.DPadRight then 1 elseif k == Enum.KeyCode.DPadLeft then -1 else 0,
				if k == Enum.KeyCode.DPadUp then 1 elseif k == Enum.KeyCode.DPadDown then -1 else 0)
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.DPadUp, Enum.KeyCode.DPadDown, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight,
		Enum.KeyCode.Thumbstick1)
end

local function unbindActions()
	for _, name in { "ChessPick", "ChessBack", "ChessMenu", "ChessTilt", "ChessCursor", "ChessView", "ChessSnipe", "ChessAbilityKeys" } do
		ContextActionService:UnbindAction(name)
	end
	stick = Vector2.zero
end

local function enterSeat(id, color)
	mine = { id = id, color = color }
	ui.cursor = if color == "w" then 20 else 100 -- e2 / e7
	deselect()
	CameraRig.enter(views[id], color, ui.tilted)
	board2d:setOrientation(color)
	board2d:clearPieces()
	board2d:sync(currentGame(states[id]), false)
	board2d:setVisible(ui.mode2D)
	hud:setVisible(true)
	hud:setPad(Device.current == "pad")
	hud:setHint(HINTS[Device.current])
	ProximityPromptService.Enabled = false
	seatedNow = true
	if bracketPanel then
		bracketPanel:setSeated(true)
	end
	setJump(false)
	bindActions()
	lobbyHud:setVisible(false)
	ContextActionService:UnbindAction("LobbyMenu")
end

local function exitSeat()
	if not mine then
		return
	end
	views[mine.id]:setMarks({})
	board2d:setVisible(false)
	board2d:clearPieces()
	mine = nil
	unbindActions()
	CameraRig.exit()
	hud:setVisible(false)
	ProximityPromptService.Enabled = true
	seatedNow = false
	if bracketPanel then
		bracketPanel:setSeated(false)
	end
	setJump(true)
	lobbyHud:setVisible(true)
	bindLobbyMenu()
end

local function updateMine()
	local found
	for id, st in states do
		if st.meta then
			for color, seat in st.meta.seats do
				if seat and seat.userId == player.UserId then
					found = { id = id, color = color }
				end
			end
		end
	end
	if found and (not mine or mine.id ~= found.id or mine.color ~= found.color) then
		if mine then
			exitSeat()
		end
		enterSeat(found.id, found.color)
	elseif not found and mine then
		exitSeat()
	end
end

-- Ground lights and refresh -------------------------------------------------------------------------
local function updateSign(id)
	local meta = states[id].meta
	if not meta or not boards[id] then
		return
	end
	local full = meta.seats.w ~= nil and meta.seats.b ~= nil
	setGroundLight(boards[id].light, meta.status ~= "playing" and not full)
end

refresh = function(id, animate)
	local st = states[id]
	if lobbyHud then
		local summaries = {}
		for tid, s in states do
			if s.meta then
				summaries[tid] = { seats = s.meta.seats, status = s.meta.status }
			end
		end
		lobbyHud:updateTables(summaries)
	end
	if not st.cutscene then
		views[id]:sync(currentGame(st), animate)
		if mine and mine.id == id then
			board2d:sync(currentGame(st), animate)
		end
	end
	updateSign(id)
	updateMine()
	if mine and mine.id == id then
		-- a move came in: drop a stale selection
		if ui.selected and not (canAct() and st.game.board.sq[ui.selected]) then
			deselect()
		end
		updateMarks()
		updateHud()
	end
end

local function applySnapshot(st, p)
	st.seq = p.seq
	st.meta = p
	if p.fen then
		local Modes = Shared:WaitForChild("Modes")
		local modeModule = Modes:FindFirstChild(p.settings.mode)
		local mode = modeModule and require(modeModule) or nil
		local g = Game.new(p.startFen, mode)
		if p.loadout and mode and mode.setLoadout then
			mode.setLoadout(g, p.loadout) -- the abilities each player bought
		end
		Steal.grant(g, p.steal) -- who has a paid Steal a Piece this game
		for _, action in p.actions do
			local ok = g:apply(action)
			if not ok then
				warn("[Chess] couldn't replay", p.tableId, "at ply", #g.history + 1)
				break
			end
		end
		st.game = g
	else
		st.game = nil
	end
end

Remotes.State.OnClientEvent:Connect(function(p)
	local id = p.tableId
	local st = states[id]
	if not st then
		return
	end
	if p.type == "rejected" then
		st.predicted = nil
		if mine and mine.id == id then
			hud:toast(REJECT_TEXT[p.reason] or p.reason)
			views[id]:sync(currentGame(st), false) -- put a dragged piece back
			board2d:sync(currentGame(st), false)
		end
		requestSnapshot(id)
		return
	end
	if p.type == "snapshot" then
		if p.seq >= st.seq then
			st.predicted = nil
			local was = st.meta and st.meta.status
			applySnapshot(st, p)
			if was and was ~= "playing" and p.status == "playing" and #p.actions == 0 then
				local heard, pos = soundAt(id)
				if heard then
					Sounds.play("start", pos)
				end
			end
			refresh(id, false)
			-- a Steal a Piece just bought in this game: aim it straight away
			if ui.stealPending and mine and mine.id == id then
				local steal = stealState(st)
				if steal and steal.state == "ready" then
					ui.stealPending = false
					hud:toast("Steal a Piece is yours: tap an enemy piece")
					if canAct() then
						task.defer(aimAbility, "StealPiece")
					end
				end
			end
		end
		return
	end
	if p.seq ~= st.seq + 1 or not st.meta then
		requestSnapshot(id)
		return
	end
	st.seq = p.seq
	local echo = st.predicted ~= nil -- our own predicted move coming back: its sound already played
	st.predicted = nil
	local meta = st.meta
	if p.type == "action" then
		local mover = st.game and st.game.turn
		-- what an ability does, worked out on the position before it (for its cutscene)
		local abilityInfo
		local a = p.action
		if a.kind == "ability" and st.game then
			if a.id == "BishopSnipe" then
				abilityInfo = Snipe.hits(st.game, a.from, a.dir)
			elseif a.id == "RookRam" then
				abilityInfo = RookRam.trace(st.game, a.from, a.dir)
			elseif a.id == "KnightJump" then
				abilityInfo = KnightJump.hits(st.game, a)
			elseif a.id == "KingEscape" then
				abilityInfo = KingEscape.hits(st.game, a)
			elseif a.id == "PawnPassant" then
				abilityInfo = PawnPassant.hits(st.game, a)
			elseif a.id == "StealPiece" then
				abilityInfo = Steal.hits(st.game, a)
			else
				abilityInfo = {}
			end
		end
		local ok = st.game and st.game:apply(p.action)
		if not ok or st.game:fen() ~= p.fen then
			requestSnapshot(id)
			return
		end
		meta.clock = p.clock
		if meta.drawOffer and meta.drawOffer ~= mover then
			meta.drawOffer = nil -- moving declined it (server rule)
		end
		if abilityInfo then
			playAbility(id, p.action, abilityInfo)
		elseif not echo and p.action.kind ~= "ability" then
			local heard, pos = soundAt(id)
			if heard then
				Sounds.forMove(st.game.history[#st.game.history].san, pos)
			end
		end
		refresh(id, true)
	elseif p.type == "result" then
		meta.result = p.result
		meta.status = "over"
		local heard, pos = soundAt(id)
		if heard then
			task.delay(if st.cutscene then Settings.cutscene(st.cutsceneId) else 0.3, Sounds.play, "finish", pos)
		end
		meta.clock = p.clock
		meta.drawOffer = nil
		for _, seat in meta.seats do
			seat.ready = seat.isBot == true
		end
		refresh(id, false)
	elseif p.type == "drawOffer" then
		meta.drawOffer = p.color
		refresh(id, false)
	end
end)

-- HUD -----------------------------------------------------------------------------------------------
hud = Hud.new({
	offerDraw = function()
		Remotes.TableCommand:FireServer(mine.id, "offerDraw")
	end,
	resign = function()
		Remotes.TableCommand:FireServer(mine.id, "resign")
	end,
	acceptDraw = function()
		Remotes.TableCommand:FireServer(mine.id, "acceptDraw")
	end,
	declineDraw = function()
		Remotes.TableCommand:FireServer(mine.id, "declineDraw")
	end,
	stand = function()
		lobby("stand", mine.id)
	end,
	tilt = function()
		ui.tilted = not ui.tilted
		CameraRig.setTilted(ui.tilted)
		updateHud()
	end,
	ability = function()
		aimAbility(nil)
	end,
	steal = function()
		local s = stealState(myState())
		if not s then
			return
		end
		if s.state == "ready" then
			aimAbility("StealPiece")
		elseif s.state == "buy" then
			ui.stealPending = true -- aim as soon as the purchase lands in this game
			MarketplaceService:PromptProductPurchase(player, Settings.STEAL_PRODUCT)
		end
	end,
	pickAbility = function(id)
		aimAbility(id)
	end,
	cycleMode = function()
		local st = myState()
		local idx = table.find(Settings.MODES, st.meta.settings.mode) or 1
		lobby("configure", mine.id, { mode = Settings.MODES[idx % #Settings.MODES + 1] })
	end,
	settings = function()
		openSettings()
	end,
	review = function()
		openReview()
	end,
	toggle2D = function()
		ui.mode2D = not ui.mode2D
		deselect()
		board2d:setVisible(ui.mode2D)
		updateHud()
	end,
	ready = function()
		local st = myState()
		local me = st.meta.seats[mine.color]
		lobby("ready", mine.id, not (me and me.ready))
	end,
	cycleClock = function()
		local st = myState()
		local idx = 1
		for i, c in Settings.CLOCKS do
			if c.id == st.meta.settings.clock then
				idx = i
			end
		end
		lobby("configure", mine.id, { clock = Settings.CLOCKS[idx % #Settings.CLOCKS + 1].id })
	end,
	botButton = function()
		local st = myState()
		local opp = st.meta.seats[if mine.color == "w" then "b" else "w"]
		if opp and opp.isBot then
			lobby("removeBot", mine.id)
		elseif not opp then
			lobby("addBot", mine.id, ui.botLevel)
		end
	end,
	cycleLevel = function()
		ui.botLevel = ui.botLevel % #Search.LEVELS + 1
		local st = myState()
		local opp = st.meta.seats[if mine.color == "w" then "b" else "w"]
		if opp and opp.isBot then
			lobby("botLevel", mine.id, ui.botLevel) -- (in place: the panel keeps its rows)
		end
		updateHud()
	end,
})

lobbyHud = LobbyHud.new({
	quickBot = function(opts)
		lobby("quick", nil, opts)
	end,
	quickPlayer = function(mode)
		task.spawn(function()
			local ok, res = Remotes.Lobby:InvokeServer("quick", nil, { vs = "player", mode = mode })
			if not ok then
				lobbyHud:toast(REJECT_TEXT[res] or tostring(res))
			end
		end)
	end,
	sit = function(id)
		lobby("sit", id)
	end,
	settings = function()
		openSettings()
	end,
	play = function()
		playScreen:open(Device.current == "pad")
	end,
	fetchStats = function()
		local ok, data = Remotes.Lobby:InvokeServer("stats")
		return if ok then data else nil
	end,
	fetchLeaderboard = function(board)
		local ok, data = Remotes.Lobby:InvokeServer("leaderboard", nil, board)
		return if ok then data else nil
	end,
	reviewSaved = function(id)
		reviewSavedGame(id)
	end,
	buyVip = function()
		MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, Settings.VIP_PASS)
	end,
	buy = function(id)
		return Remotes.Lobby:InvokeServer("buy", nil, id)
	end,
	buyPass = function(passId)
		MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, passId)
	end,
	-- tournaments (TournamentPanel calls these from a task; they may yield)
	tourney = {
		start = function()
			local ok, res = Remotes.Lobby:InvokeServer("tourneyStart")
			if ok then
				lobbyHud.tourney:setState(res)
			else
				lobbyHud:toast(if res == "vip only" then "Only VIPs can start a tournament" else tostring(res))
			end
		end,
		join = function()
			local ok, res = Remotes.Lobby:InvokeServer("tourneyJoin")
			if ok then
				lobbyHud.tourney:setState(res)
				lobbyHud:toast("You're in! The tournament starts when the countdown ends.")
			else
				lobbyHud:toast(tostring(res))
			end
		end,
		leave = function()
			local ok, res = Remotes.Lobby:InvokeServer("tourneyLeave")
			if ok then
				lobbyHud.tourney:setState(res)
			else
				lobbyHud:toast(tostring(res))
			end
		end,
		watch = function()
			local ok, res = Remotes.Lobby:InvokeServer("tourneyWatch")
			lobbyHud:toast(if ok then "Taking you to the tournament…" else tostring(res))
		end,
		fetchToday = function()
			local ok, data = Remotes.Lobby:InvokeServer("today")
			return if ok then data else nil
		end,
		review = function(id)
			reviewTodayGame(id)
		end,
	},
}, Search.LEVELS)
lobbyHud:setPad(Device.current == "pad")

-- coins and bought abilities: fetched once, then pushed by the server (a win reward says gained)
local function fetchWallet()
	local ok, w = Remotes.Lobby:InvokeServer("wallet")
	if ok then
		lobbyHud:setWallet(w)
	end
end
task.spawn(fetchWallet)
Remotes:WaitForChild("Wallet").OnClientEvent:Connect(function(w)
	lobbyHud:setWallet(w)
	if type(w.gained) == "number" and w.gained > 0 then
		hud:setReward(w.gained)
		Sounds.play("good")
	end
end)
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, bought)
	if userId == player.UserId and productId == Settings.STEAL_PRODUCT and not bought then
		ui.stealPending = false
	end
end)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
	if player == Players.LocalPlayer and bought and passId ~= Settings.VIP_PASS then
		task.wait(1) -- an ability gamepass: the server hears about it too; then the Shop says OWNED
		fetchWallet()
		lobbyHud:toast("Unlocked! Use it in Abilities games.")
		return
	end
	if player == Players.LocalPlayer and passId == Settings.VIP_PASS and bought then
		lobbyHud:toast("VIP unlocked! Your reviews are saved now.")
		task.wait(1) -- the server hears about the purchase too; give it a moment
		fetchWallet() -- (the Shop's VIP card says OWNED)
		if lobbyHud.which == "stats" then
			lobbyHud:open("stats")
		end
	end
end)

-- the Play screen's mode cards: vs Bot opens the bot options, the others queue for a player
playScreen = PlayScreen.new({
	bot = function()
		lobbyHud:open("bot")
	end,
	tournament = function()
		lobbyHud:open("tourney")
	end,
	pvp = function(mode)
		lobbyHud.cb.quickPlayer(mode)
	end,
	shown = function(open)
		-- the lobby HUD hides behind the Play screen (and comes back if you're still standing)
		lobbyHud.gui.Enabled = not open and not seatedNow
	end,
})

-- Controller in the lobby: Y jumps to the bottom bar, B closes an open card.
bindLobbyMenu = function()
	ContextActionService:BindActionAtPriority("LobbyMenu", function(_, state, input)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if input.KeyCode == Enum.KeyCode.ButtonY then
			lobbyHud:focusBar()
			return Enum.ContextActionResult.Sink
		elseif lobbyHud.which then
			lobbyHud:open(nil)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, 2000, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonB)
end
bindLobbyMenu()

board2d = Board2D.new(function(sq)
	if mine and ui.mode2D then
		press(sq, true)
	end
end)

-- Settings: board theme, sound, music, saved per player on the server -----------------------------------
local function applyPrefs()
	Sounds.enabled = prefs.sound
	for _, m in workspace:WaitForChild("Lobby"):WaitForChild("Tables"):GetChildren() do
		if views[m:GetAttribute("TableId")] then
			paintBoard(m)
		end
	end
	board2d:setTheme(Themes.get(prefs.theme))
	-- another piece set: rebuild every board's pieces in it
	if Pieces.setSet(prefs.pieceSet) then
		for id, view in views do
			view:clearPieces()
			local st = states[id]
			if st then
				view:sync(currentGame(st), false)
			end
		end
	end
end
local function savePrefs(change)
	task.spawn(function()
		Remotes.Lobby:InvokeServer("setPrefs", nil, change)
	end)
end
local settingsPanel = SettingsPanel.new({
	theme = function(id)
		prefs.theme = id
		applyPrefs()
		savePrefs({ theme = id })
	end,
	sound = function(on)
		prefs.sound = on
		applyPrefs()
		savePrefs({ sound = on })
	end,
	music = function(on)
		prefs.music = on
		Music.setEnabled(on)
		savePrefs({ music = on })
	end,
	autoQueen = function(on)
		prefs.autoQueen = on
		ui.autoQueen = on
		savePrefs({ autoQueen = on })
	end,
	pieceSet = function(id)
		prefs.pieceSet = id
		applyPrefs()
		savePrefs({ pieceSet = id })
	end,
})
openSettings = function()
	settingsPanel:open(prefs)
end
task.spawn(function()
	local ok, saved = Remotes.Lobby:InvokeServer("getPrefs")
	if ok and type(saved) == "table" then
		prefs.theme = saved.theme or prefs.theme
		if type(saved.sound) == "boolean" then
			prefs.sound = saved.sound
		end
		if type(saved.music) == "boolean" then
			prefs.music = saved.music
		end
		if type(saved.autoQueen) == "boolean" then
			prefs.autoQueen = saved.autoQueen
			ui.autoQueen = saved.autoQueen
		end
		if type(saved.pieceSet) == "string" and Settings.pieceSet(saved.pieceSet) then
			prefs.pieceSet = saved.pieceSet
		end
	end
	applyPrefs()
	Music.setEnabled(prefs.music)
end)

-- Game review: the finished game at your table, analysed on this client -----------------------------
local reviewPanel = ReviewPanel.new()
openReview = function()
	local st = myState()
	if not (st and st.game and st.meta) then
		return
	end
	local meta = st.meta
	local actions = {}
	for _, h in st.game.history do
		table.insert(actions, h.action)
	end
	local modeModule = Shared.Modes:FindFirstChild(meta.settings.mode)
	local function seatName(color)
		local seat = meta.seats[color]
		return if seat then seat.name else "?"
	end
	reviewPanel:open({
		startFen = meta.startFen,
		modeName = meta.settings.mode,
		mode = if modeModule then require(modeModule) else nil,
		actions = actions,
		white = seatName("w"),
		black = seatName("b"),
		result = meta.result,
		clock = Settings.clock(meta.settings.clock),
		clockId = meta.settings.clock,
		myColor = mine.color,
	})
end

-- VIPs: a game is saved once its review is analysed (Stats > Saved games). The server checks VIP
-- and replays the moves; a game opened from the saved list isn't saved again.
reviewPanel.onAnalysed = function(record, summary)
	if record.savedId then
		return
	end
	local me = summary[record.myColor or "w"]
	local ok = Remotes.Lobby:InvokeServer("saveGame", nil, {
		startFen = record.startFen,
		modeName = record.modeName,
		actions = record.actions,
		white = record.white,
		black = record.black,
		result = record.result,
		clockId = record.clockId,
		myColor = record.myColor,
		accuracy = me and me.accuracy,
		counts = me and me.counts,
	})
	if ok == true and reviewPanel:isOpen() then
		reviewPanel:toast("Saved to Stats")
	end
end

-- open a saved game's review (from Stats > Saved games)
local function openSavedReview(id)
	local ok, gm = Remotes.Lobby:InvokeServer("savedGame", nil, id)
	if not (ok and gm) then
		lobbyHud:toast("Couldn't load that game")
		return
	end
	local modeModule = Shared.Modes:FindFirstChild(gm.mode)
	lobbyHud:open(nil)
	reviewPanel:open({
		startFen = gm.startFen,
		modeName = gm.mode,
		mode = if modeModule then require(modeModule) else nil,
		actions = gm.actions,
		white = gm.white,
		black = gm.black,
		result = gm.result,
		clock = Settings.clock(gm.clock),
		clockId = gm.clock,
		myColor = gm.myColor,
		savedId = gm.id,
	})
end
reviewSavedGame = openSavedReview

-- open one of today's logged tournament games (Tournament card > Today's games); never saved again
reviewTodayGame = function(id)
	local ok, gm = Remotes.Lobby:InvokeServer("todayGame", nil, id)
	if not (ok and gm) then
		lobbyHud:toast("Couldn't load that game")
		return
	end
	lobbyHud:open(nil)
	reviewPanel:open({
		startFen = gm.startFen,
		modeName = "Classic",
		mode = require(Shared.Modes.Classic),
		actions = gm.actions,
		white = gm.white,
		black = gm.black,
		result = gm.result,
		clock = Settings.clock(gm.clock),
		clockId = gm.clock,
		myColor = if gm.blackId == player.UserId then "b" else "w",
		savedId = gm.id,
	})
end

-- Tournaments ------------------------------------------------------------------------------------------
-- Lobby: the banner in every server, the Tournament card and the big screen on the lobby's stage
-- (StageScreen), fed by Remotes.Tournament ("state").
-- Tournament server: the bracket ("bracket"); no PLAY or Tables; Watch walks you to a table.
LobbyAmbience.start()
local banner, stageScreen
if isTournamentServer then
	lobbyHud:setTournamentServer(true)
	bracketPanel = BracketPanel.new({
		watch = function(tableId)
			local root = workspace:FindFirstChild("Lobby")
			local model = root and root.Tables:FindFirstChild(tableId)
			local char = player.Character
			if model and model.PrimaryPart and char then
				local c = model.PrimaryPart.Position
				local spot = c + Vector3.new(if c.X > 0 then -11 else 11, 3, 0) -- beside the board, between the chairs
				char:PivotTo(CFrame.lookAt(spot, Vector3.new(c.X, spot.Y, c.Z)))
			end
			bracketPanel:open(false)
		end,
		lobby = function()
			lobbyHud:toast("Taking you back to the lobby…")
			local ok, err = pcall(TeleportService.Teleport, TeleportService, Settings.START_PLACE_ID)
			if not ok then
				lobbyHud:toast("Couldn't teleport: " .. tostring(err))
			end
		end,
	})
	bracketPanel:setSeated(seatedNow)
else
	banner = TournamentBanner.new({
		join = function()
			task.spawn(lobbyHud.cb.tourney.join)
		end,
		leave = function()
			task.spawn(lobbyHud.cb.tourney.leave)
		end,
		watch = function()
			task.spawn(lobbyHud.cb.tourney.watch)
		end,
		open = function()
			if not seatedNow then
				lobbyHud:open("tourney")
			end
		end,
	})
	stageScreen = StageScreen.new({
		join = function()
			task.spawn(lobbyHud.cb.tourney.join)
		end,
		watch = function()
			task.spawn(lobbyHud.cb.tourney.watch)
		end,
	})
end
Remotes:WaitForChild("Tournament").OnClientEvent:Connect(function(msg)
	if type(msg) ~= "table" then
		return
	end
	if msg.kind == "state" and banner then
		lobbyHud.tourney:setState(msg.tournament)
		banner:setState(msg.tournament, msg.event)
		stageScreen:setState(msg.tournament)
	elseif msg.kind == "bracket" and bracketPanel then
		bracketPanel:setView(msg)
	end
end)
task.spawn(function()
	local ok, v = Remotes.Lobby:InvokeServer("tourney")
	if ok and v then
		if bracketPanel then
			bracketPanel:setView(v)
		elseif banner then
			lobbyHud.tourney:setState(v)
			banner:setState(v)
			stageScreen:setState(v)
		end
	end
end)

-- Studio only: PlayerScripts.ChessClientDebug lets test scripts press what a player would press
if game:GetService("RunService"):IsStudio() then
	local hook = Instance.new("BindableFunction")
	hook.Name = "ChessClientDebug"
	hook.OnInvoke = function(verb, arg)
		if verb == "review" then
			openReview()
			return reviewPanel:isOpen()
		elseif verb == "reviewGo" then
			reviewPanel:go(arg)
			return reviewPanel.ply
		elseif verb == "reviewBest" then
			reviewPanel:toggleBest()
			return reviewPanel.showingBest == true
		elseif verb == "reviewKey" then
			reviewPanel:nextKeyMoment()
			return reviewPanel.ply
		elseif verb == "closeReview" then
			reviewPanel:close()
			return true
		elseif verb == "settings" then
			openSettings()
			return true
		elseif verb == "theme" then
			prefs.theme = arg
			applyPrefs()
			return true
		end
		return false
	end
	hook.Parent = player:WaitForChild("PlayerScripts")
end

Device.Changed:Connect(function(d)
	lobbyHud:setPad(d == "pad")
	if mine then
		hud:setPad(d == "pad")
		hud:setHint(HINTS[d])
		updateMarks()
	end
end)

-- Pointer input (mouse + touch) -------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not mine then
		return
	end
	local t = input.UserInputType
	if ui.mode2D then
		-- the 2D board's own button handles presses; a click elsewhere just cancels
		if t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			deselect()
		end
		return
	end
	if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
		local point = boardPoint(input.Position)
		press(point and views[mine.id]:squareAt(point), true)
	elseif t == Enum.UserInputType.MouseButton2 then
		deselect()
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not (mine and ui.drag) then
		return
	end
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch then
		if ui.mode2D then
			ui.drag.moved = true
			board2d:dragTo(ui.drag.from, input.Position.X, input.Position.Y)
			return
		end
		local point = boardPoint(input.Position)
		if point then
			ui.drag.moved = true
			views[mine.id]:dragTo(ui.drag.from, point)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if not (mine and ui.drag) then
		return
	end
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
		local drag = ui.drag
		ui.drag = nil
		if drag.moved then
			local sq
			if ui.mode2D then
				sq = board2d:squareAt(input.Position.X, input.Position.Y)
			else
				local point = boardPoint(input.Position)
				sq = point and views[mine.id]:squareAt(point)
			end
			if sq and sq ~= drag.from and ui.targets[sq] then
				attempt(drag.from, sq)
			end
			-- snap the dragged piece back; the server's move (if any) animates it properly
			local st = myState()
			views[mine.id]:sync(currentGame(st), false)
			board2d:sync(currentGame(st), false)
		end
	end
end)

-- Every frame: clocks and the controller stick
RunService.RenderStepped:Connect(function()
	local st = myState()
	if not (st and st.meta) then
		return
	end
	local now = workspace:GetServerTimeNow()
	hud:tickClocks(st.meta.status == "playing" and st.meta.clock or (st.meta.status == "over" and st.meta.clock) or nil,
		mine.color, now)
	-- low time: a tick each second under 10 s while your own clock runs
	local c = st.meta.clock
	if st.meta.status == "playing" and c and c.running == mine.color and c[mine.color] then
		local left = c[mine.color] - math.max(0, now - math.max(c.at, c.since or c.at))
		local whole = math.ceil(left)
		if left > 0 and left <= 10 and whole ~= ui.lastTick then
			ui.lastTick = whole
			Sounds.play("tick")
		end
	end
	if stick.Magnitude > 0.6 and os.clock() >= nextStep and not GuiService.SelectedObject then
		local dx = if math.abs(stick.X) > 0.5 then math.sign(stick.X) else 0
		local dy = if math.abs(stick.Y) > 0.5 then math.sign(stick.Y) else 0
		moveCursor(dx, dy)
		nextStep = os.clock() + 0.18
	elseif stick.Magnitude <= 0.6 then
		nextStep = 0
	end
end)

setupTable = function(id)
	states[id].lastRequest = 0
	requestSnapshot(id)
end
local tablesFolder = workspace:WaitForChild("Lobby"):WaitForChild("Tables")
tablesFolder.ChildAdded:Connect(function(m)
	task.spawn(setupTableNow, m)
end)
for _, m in tablesFolder:GetChildren() do
	task.spawn(setupTableNow, m)
end
