-- One chess table: two seats, settings, the authoritative Game, the clock, draw offers and
-- disconnects. Knows nothing about remotes: it reports through `broadcast(payload)` and
-- `onFinished(table, result)`, so a test driver can run it directly.
--
-- A participant is { userId, name, player = Player? }. Test drivers seat fake ones (negative
-- userIds, no player). Bots are { userId <= -100, name, isBot = true, level = 1..4 }: always ready,
-- they move by themselves (maybeBotMove) and leave when no human is left at the table. Status: "waiting" (seats/settings/ready), "playing", "over" (result shown;
-- both ready again = rematch with colours swapped).
--
-- Tournament tables (Tournament/Runner): `owner` is set while the runner owns the table, and
-- runMatch seats both players and starts at once (no ready, no rematch, no aborting: leaving or
-- resigning early is a loss, and a player who doesn't make a first move in time loses).
--
-- Payloads (every broadcast bumps `seq`; a client that sees a gap asks for a snapshot):
--   snapshot { status, settings, seats, actions, sans, fen, clock, drawOffer, result, loadout, steal,
--            tournament? = { matchId, stage, round } while the tournament runner owns the table }
--            (loadout: Abilities games, the abilities each colour owns, { w = ids?, b = ids? };
--            a missing colour has all of them; steal: { w = true?, b = true? } the colours with a paid
--            Steal a Piece this game, Shared/Abilities/StealPiece)
--   action   { action, san, fen, ply, clock }
--   result   { result, clock }
--   drawOffer{ color } (nil color = offer withdrawn/declined)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Board = require(Shared.Chess.Board)
local Game = require(Shared.Chess.Game)
local Settings = require(Shared.Settings)
local Search = require(Shared.Bot.Search)
local Steal = require(Shared.Abilities.StealPiece)
local Clock = require(script.Parent.Clock)

local ChessTable = {}
ChessTable.__index = ChessTable

local PROMOS = { q = true, r = true, b = true, n = true }

function ChessTable.new(id: string, broadcast, onFinished)
	local self = setmetatable({}, ChessTable)
	self.id = id
	self.broadcast = broadcast
	self.onFinished = onFinished
	self.seats = {} -- color -> participant
	self.ready = {} -- color -> true
	self.disconnectedAt = {} -- color -> server time
	self.settings = { mode = "Classic", clock = Settings.DEFAULT_CLOCK }
	self.status = "waiting"
	self.game = nil
	self.clock = nil
	self.seq = 0
	self.drawOffer = nil -- color that offered
	self.lastOfferPly = {} -- color -> ply of their last offer (one offer per own move)
	self.timeOffset = 0 -- test drivers advance time with this
	self.gameToken = 0 -- bumps every game so a stale bot search is dropped
	self.botSpeed = nil -- test override { time, think } for bot levels
	self.loadout = nil -- Abilities games: { w = ids?, b = ids? } (Modes/Abilities.setLoadout)
	-- participant -> the ability ids they bought, or nil for all (set by TableService; test
	-- drivers leave it unset, so their games have every ability)
	self.loadoutFor = nil
	self.steal = nil -- { w = true?, b = true? }: who has a paid steal this game
	self.stealFor = nil -- participant -> has an unspent paid steal (set by TableService)
	self.onSteal = nil -- participant -> (): a steal was used (spend it)
	-- tournaments: the runner owns the table (players can't sit, stand, configure or ready up)
	self.owner = nil -- "tournament" while owned
	self.clockOverride = nil -- { white, black, inc } seconds: per-side times (Armageddon)
	self.noAbort = false -- leaving or resigning before move 2 is a loss, not an abort
	self.firstMoveLimit = nil -- seconds each side has for its first move
	self.lastMoveAt = nil
	self.match = nil -- runner data: { matchId, stage }
	return self
end

function ChessTable:now(): number
	return workspace:GetServerTimeNow() + self.timeOffset
end

function ChessTable:colorOf(userId: number): string?
	for color, p in self.seats do
		if p.userId == userId then
			return color
		end
	end
	return nil
end

function ChessTable:isReady(color: string): boolean
	local p = self.seats[color]
	return p ~= nil and (p.isBot == true or self.ready[color] == true)
end

function ChessTable:hasHuman(): boolean
	for _, p in self.seats do
		if not p.isBot then
			return true
		end
	end
	return false
end

function ChessTable:send(payload)
	self.seq += 1
	payload.seq = self.seq
	payload.tableId = self.id
	self.broadcast(payload)
end

local function seatInfo(self, color)
	local p = self.seats[color]
	if not p then
		return nil
	end
	return {
		userId = p.userId,
		name = p.name,
		isBot = p.isBot == true,
		level = p.level,
		ready = self:isReady(color),
		connected = self.disconnectedAt[color] == nil,
	}
end

function ChessTable:clockSnapshot()
	return if self.clock then self.clock:snapshot(self:now()) else nil
end

function ChessTable:snapshot()
	local actions, sans = {}, {}
	if self.game then
		for _, h in self.game.history do
			table.insert(actions, h.action)
			table.insert(sans, h.san)
		end
	end
	return {
		type = "snapshot",
		seq = self.seq,
		tableId = self.id,
		status = self.status,
		settings = table.clone(self.settings),
		seats = { w = seatInfo(self, "w"), b = seatInfo(self, "b") },
		actions = actions,
		sans = sans,
		fen = if self.game then self.game:fen() else nil,
		startFen = self.startFen,
		clock = self:clockSnapshot(),
		drawOffer = self.drawOffer,
		result = if self.game then self.game.result else nil,
		loadout = self.loadout,
		steal = self.steal,
		tournament = if self.owner == "tournament" then self.match else nil, -- { matchId, stage, round }
	}
end

function ChessTable:sendSnapshot()
	self.seq += 1
	self.broadcast(self:snapshot())
end

-- Seating ------------------------------------------------------------------------------------------

function ChessTable:sit(participant, color: string?)
	if self.status == "playing" then
		return false, "a game is in progress"
	end
	if self:colorOf(participant.userId) then
		return false, "already seated"
	end
	if color ~= "w" and color ~= "b" then
		color = if not self.seats.w then "w" elseif not self.seats.b then "b" else nil
	end
	if not color or self.seats[color] then
		return false, "seat taken"
	end
	self.seats[color] = participant
	self.ready = {}
	if self.status == "over" then
		self.status = "waiting"
	end
	self:sendSnapshot()
	return true
end

function ChessTable:stand(userId: number)
	local color = self:colorOf(userId)
	if not color then
		return false, "not seated"
	end
	if self.status == "playing" then
		self:leaveGame(color)
	end
	self.seats[color] = nil
	self.disconnectedAt[color] = nil
	self.ready = {}
	if self.status == "over" then
		self.status = "waiting"
	end
	if not self:hasHuman() then
		for c, p in table.clone(self.seats) do
			if p.isBot then
				self.seats[c] = nil -- bots don't stay at an empty table
			end
		end
	end
	self:sendSnapshot()
	return true
end

-- Bots -----------------------------------------------------------------------------------------------

local botCounter = 0

function ChessTable:seatBot(level: number, color: string?)
	local info = Search.LEVELS[level]
	if not info then
		return false, "unknown bot level"
	end
	botCounter += 1
	return self:sit({ userId = -100 - botCounter, name = "Bot (" .. info.name .. ")", isBot = true, level = level }, color)
end

-- A seated player invites a bot into the free seat.
function ChessTable:addBot(userId: number, level)
	local color = self:colorOf(userId)
	if not color or self.seats[color].isBot then
		return false, "sit down first"
	end
	if type(level) ~= "number" or level % 1 ~= 0 then
		return false, "unknown bot level"
	end
	return self:seatBot(level, Board.other(color))
end

-- Change the seated bot's level in place (no remove + add, so the table panel doesn't jump).
function ChessTable:setBotLevel(userId: number, level)
	local color = self:colorOf(userId)
	if not color then
		return false, "not seated"
	end
	if self.status == "playing" then
		return false, "a game is in progress"
	end
	local other = self.seats[Board.other(color)]
	local info = type(level) == "number" and Search.LEVELS[level]
	if not (other and other.isBot) then
		return false, "no bot here"
	end
	if not info then
		return false, "unknown bot level"
	end
	other.level = level
	other.name = "Bot (" .. info.name .. ")"
	self.ready = {}
	self:sendSnapshot()
	return true
end

function ChessTable:removeBot(userId: number)
	local color = self:colorOf(userId)
	if not color then
		return false, "not seated"
	end
	if self.status == "playing" then
		return false, "a game is in progress"
	end
	local other = self.seats[Board.other(color)]
	if not (other and other.isBot) then
		return false, "no bot here"
	end
	self.seats[Board.other(color)] = nil
	self.ready = {}
	if self.status == "over" then
		self.status = "waiting"
	end
	self:sendSnapshot()
	return true
end

-- If it's a bot's turn, think on a copy of the game (spread over frames) and then move.
function ChessTable:maybeBotMove()
	if self.status ~= "playing" or self.botThinking then
		return
	end
	local color = self.game.turn
	local p = self.seats[color]
	if not (p and p.isBot) then
		return
	end
	self.botThinking = true
	local token, ply = self.gameToken, #self.game.history
	local level = table.clone(Search.LEVELS[p.level] or Search.LEVELS[2])
	local last = self.game.history[#self.game.history]
	if last and last.action.kind == "ability" then
		level.think = math.max(level.think, Settings.cutscene(last.action.id) + 0.3) -- let the cutscene finish
	end
	if self.botSpeed then
		level.time, level.think = self.botSpeed.time, self.botSpeed.think
	end
	local budget = level.time
	if self.clock then
		local left = self.clock:remaining(color, self:now())
		budget = math.max(0.05, math.min(budget, left / 30 + self.clock.increment * 0.5))
	end
	local copy = self.game:clone()
	task.spawn(function()
		local started = os.clock()
		local ok, action = pcall(Search.choose, copy, level, {
			now = os.clock,
			yield = task.wait,
			budget = budget,
		})
		local waitLeft = level.think - (os.clock() - started)
		if waitLeft > 0 then
			task.wait(waitLeft)
		end
		if self.gameToken ~= token then
			return -- a new game started while thinking; that game owns botThinking now
		end
		self.botThinking = false
		if self.status ~= "playing" or #self.game.history ~= ply then
			return -- the game ended or moved on while thinking
		end
		if not ok or not action then
			warn("[Chess] bot failed to pick a move:", action)
			self:finish(Board.other(color), "resignation")
			return
		end
		local moved, err = self:requestAction(p.userId, action)
		if not moved then
			warn("[Chess] bot move rejected:", err)
			self:finish(Board.other(color), "resignation")
		end
	end)
end

-- Leaving a running game: abort if neither side has really played yet, otherwise it's a loss.
function ChessTable:leaveGame(color: string)
	if #self.game.history < 2 and not self.noAbort then
		self:finish(nil, "aborted")
	else
		self:finish(Board.other(color), "abandoned")
	end
end

function ChessTable:configure(userId: number, settings)
	if self.status == "playing" then
		return false, "a game is in progress"
	end
	if not self:colorOf(userId) then
		return false, "not seated"
	end
	if type(settings) ~= "table" then
		return false, "bad settings"
	end
	if settings.mode ~= nil then
		if type(settings.mode) ~= "string" or not Settings.hasMode(settings.mode) then
			return false, "unknown mode"
		end
		self.settings.mode = settings.mode
	end
	if settings.clock ~= nil then
		if type(settings.clock) ~= "string" or not Settings.clock(settings.clock) then
			return false, "unknown clock"
		end
		self.settings.clock = settings.clock
	end
	self.ready = {} -- the other player must agree to the new settings
	self:sendSnapshot()
	return true
end

function ChessTable:setReady(userId: number, ready: boolean)
	local color = self:colorOf(userId)
	if not color then
		return false, "not seated"
	end
	if self.status == "playing" then
		return false, "a game is in progress"
	end
	self.ready[color] = if ready then true else nil
	if self:isReady("w") and self:isReady("b") then
		if self.status == "over" then
			-- rematch: swap colours
			self.seats.w, self.seats.b = self.seats.b, self.seats.w
			self.disconnectedAt.w, self.disconnectedAt.b = self.disconnectedAt.b, self.disconnectedAt.w
		end
		self:start()
	else
		self:sendSnapshot()
	end
	return true
end

-- fen: optional start position (test drivers only; players always start from the normal setup)
function ChessTable:start(fen: string?)
	local Modes = Shared:WaitForChild("Modes")
	self.startFen = fen
	local mode = require(Modes:FindFirstChild(self.settings.mode) or Modes.Classic)
	self.game = Game.new(fen, mode)
	-- Abilities: each player has only what they bought; a bot gets the same as the person it plays
	self.loadout = nil
	if mode.setLoadout and self.loadoutFor then
		local loadout = {}
		for _, color in { "w", "b" } do
			local p = self.seats[color]
			if p and not p.isBot then
				loadout[color] = self.loadoutFor(p)
			end
		end
		for _, color in { "w", "b" } do
			local p = self.seats[color]
			if p and p.isBot then
				loadout[color] = loadout[Board.other(color)]
			end
		end
		self.loadout = loadout
		mode.setLoadout(self.game, loadout)
	end
	-- Steal a Piece: players with a paid, unspent steal have it this game (never bots, never in a
	-- tournament)
	self.steal = {}
	if self.stealFor and not self.owner then
		for _, color in { "w", "b" } do
			local p = self.seats[color]
			if p and not p.isBot and self.stealFor(p) then
				self.steal[color] = true
			end
		end
	end
	Steal.grant(self.game, self.steal)
	local preset = Settings.clock(self.settings.clock)
	local o = self.clockOverride
	self.clock = if o then Clock.new(o.white, o.inc, o.black)
		elseif preset and preset.base then Clock.new(preset.base, preset.increment)
		else nil
	self.lastMoveAt = self:now()
	self.status = "playing"
	self.ready = {}
	self.drawOffer = nil
	self.lastOfferPly = {}
	self.gameToken += 1
	self.botThinking = false
	self:sendSnapshot()
	self:maybeBotMove()
end

-- A steal was bought during this player's game: they can use it now (once per game).
function ChessTable:grantSteal(userId: number): boolean
	local color = self:colorOf(userId)
	if not color or self.owner or self.status ~= "playing" or not self.steal or self.steal[color] then
		return false
	end
	self.steal[color] = true
	Steal.grant(self.game, { [color] = true })
	self:sendSnapshot() -- clients rebuild the game with the grant
	return true
end

-- Playing ------------------------------------------------------------------------------------------

-- Never trust the client: rebuild the action from checked fields only.
local ABILITY_DIRS = { [17] = true, [15] = true, [-15] = true, [-17] = true, [16] = true, [-16] = true, [1] = true, [-1] = true }
local function square(v)
	return type(v) == "number" and v % 1 == 0 and Board.onBoard(v)
end

local function cleanAction(a)
	if type(a) ~= "table" then
		return nil
	end
	if a.kind == "ability" then
		-- shape check only; the game decides whether the mode has it and it is legal. Fields:
		-- from (always), dir (snipe / ram), mid + to (double jump), to (swap / escape)
		if type(a.id) ~= "string" or #a.id > 32 or not square(a.from) then
			return nil
		end
		if (a.dir ~= nil and not ABILITY_DIRS[a.dir]) or (a.mid ~= nil and not square(a.mid))
			or (a.to ~= nil and not square(a.to)) then
			return nil
		end
		return { kind = "ability", id = a.id, from = a.from, dir = a.dir, mid = a.mid, to = a.to }
	end
	if a.kind ~= "move" then
		return nil
	end
	local from, to, promo = a.from, a.to, a.promotion
	if type(from) ~= "number" or type(to) ~= "number" or from % 1 ~= 0 or to % 1 ~= 0 then
		return nil
	end
	if not Board.onBoard(from) or not Board.onBoard(to) then
		return nil
	end
	if promo ~= nil and not (type(promo) == "string" and PROMOS[promo]) then
		return nil
	end
	return { kind = "move", from = from, to = to, promotion = promo }
end

function ChessTable:requestAction(userId: number, action)
	if self.status ~= "playing" then
		return false, "no game in progress"
	end
	local color = self:colorOf(userId)
	if not color then
		return false, "not seated"
	end
	if color ~= self.game.turn then
		return false, "not your turn"
	end
	local clean = cleanAction(action)
	if not clean then
		return false, "malformed action"
	end
	if self.clock and self.clock:flagged(self:now()) then
		self:tick()
		return false, "out of time"
	end
	local ok, err = self.game:apply(clean)
	if not ok then
		return false, err
	end
	if self.clock then
		self.clock:press(color, self:now())
		if clean.kind == "ability" then
			self.clock:hold(Settings.cutscene(clean.id), self:now()) -- the opponent watches the cutscene
		end
	end
	self.lastMoveAt = self:now()
	if self.drawOffer and self.drawOffer ~= color then
		self.drawOffer = nil -- moving instead of answering declines the offer
	end
	if clean.kind == "ability" and clean.id == Steal.id and self.onSteal then
		self.onSteal(self.seats[color]) -- the paid steal is spent
	end
	local h = self.game.history[#self.game.history]
	self:send({
		type = "action",
		action = clean,
		san = h.san,
		fen = self.game:fen(),
		ply = #self.game.history,
		clock = self:clockSnapshot(),
	})
	if self.game.result then
		self:finish(self.game.result.winner, self.game.result.reason)
	else
		self:maybeBotMove()
	end
	return true
end

function ChessTable:command(userId: number, cmd: string)
	local color = self:colorOf(userId)
	if not color then
		return false, "not seated"
	end
	if self.status ~= "playing" then
		return false, "no game in progress"
	end
	local ply = #self.game.history
	if cmd == "resign" then
		if ply < 2 and not self.noAbort then
			self:finish(nil, "aborted")
		else
			self:finish(Board.other(color), "resignation")
		end
	elseif cmd == "offerDraw" then
		if self.drawOffer then
			return false, "a draw offer is already open"
		end
		if self.lastOfferPly[color] and self.lastOfferPly[color] >= ply - 1 then
			return false, "make a move before offering again"
		end
		self.drawOffer = color
		self.lastOfferPly[color] = ply
		self:send({ type = "drawOffer", color = color })
	elseif cmd == "acceptDraw" then
		if self.drawOffer ~= Board.other(color) then
			return false, "no offer to accept"
		end
		self:finish(nil, "agreement")
	elseif cmd == "declineDraw" then
		if self.drawOffer ~= Board.other(color) then
			return false, "no offer to decline"
		end
		self.drawOffer = nil
		self:send({ type = "drawOffer", color = nil })
	else
		return false, "unknown command"
	end
	return true
end

function ChessTable:finish(winner: string?, reason: string)
	if self.status ~= "playing" then
		return
	end
	if not self.game.result or self.game.result.reason ~= reason then
		self.game:finish(winner, reason)
	end
	if self.clock then
		self.clock:stop(self:now())
	end
	self.status = "over"
	self.drawOffer = nil
	self.ready = {}
	self:send({ type = "result", result = self.game.result, clock = self:clockSnapshot() })
	if self.onFinished then
		self.onFinished(self, self.game.result)
	end
end

-- Called often by TableService: flags and disconnect forfeits.
function ChessTable:tick()
	if self.status ~= "playing" then
		return
	end
	local now = self:now()
	if self.clock then
		local flagged = self.clock:flagged(now)
		if flagged then
			self.game:timeout(flagged)
			self:finish(self.game.result.winner, self.game.result.reason)
			return
		end
	end
	for color, at in self.disconnectedAt do
		if now - at >= Settings.DISCONNECT_GRACE then
			self:leaveGame(color)
			return
		end
	end
	-- tournaments: no first move in time loses (the clock only starts after White's first move)
	if self.firstMoveLimit and #self.game.history < 2 and now - (self.lastMoveAt or now) >= self.firstMoveLimit then
		self:finish(Board.other(self.game.turn), "abandoned")
	end
end

-- Tournaments ---------------------------------------------------------------------------------------

-- The runner starts a game here: white and black are participants (a player who isn't in the server
-- is seated as disconnected, so the usual grace forfeit applies).
-- opts = { clock = preset id, clockOverride = { white, black, inc }?, match = runner data }
function ChessTable:runMatch(white, black, opts)
	self.owner = "tournament"
	self.seats = { w = white, b = black }
	self.ready = {}
	self.disconnectedAt = {}
	for color, p in self.seats do
		if not p.isBot and not (p.player and p.player.Parent) then
			self.disconnectedAt[color] = self:now()
		end
	end
	self.settings = { mode = "Classic", clock = opts.clock or Settings.DEFAULT_CLOCK }
	self.clockOverride = opts.clockOverride
	self.noAbort = true
	self.firstMoveLimit = Settings.FIRST_MOVE_LIMIT
	self.match = opts.match
	self:start()
end

-- The runner is done with the table: empty it and give it back.
function ChessTable:release()
	if self.status == "playing" then
		return false
	end
	self.owner = nil
	self.clockOverride = nil
	self.noAbort = false
	self.firstMoveLimit = nil
	self.match = nil
	self.seats = {}
	self.ready = {}
	self.disconnectedAt = {}
	self.status = "waiting"
	self:sendSnapshot()
	return true
end

-- Connection -------------------------------------------------------------------------------------

function ChessTable:playerLeft(userId: number)
	local color = self:colorOf(userId)
	if not color then
		return
	end
	if self.status == "playing" then
		self.disconnectedAt[color] = self:now() -- grace period; tick() forfeits when it runs out
		self:sendSnapshot()
	else
		self:stand(userId)
	end
end

function ChessTable:playerRejoined(participant)
	local color = self:colorOf(participant.userId)
	if not color then
		return false
	end
	self.seats[color] = participant
	self.disconnectedAt[color] = nil
	self:sendSnapshot()
	return true
end

-- After a game ends, seats whose player is gone are freed.
function ChessTable:freeDisconnected()
	for color in table.clone(self.disconnectedAt) do
		local p = self.seats[color]
		if p then
			self:stand(p.userId)
		end
	end
end

return ChessTable
