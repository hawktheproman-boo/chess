-- A chess game: state, actions, undo and game-end detection. Pure Luau; the server owns the real
-- one, clients may run a copy to show legal moves instantly.
--
-- Everything a player does is an action:
--   { kind = "move", from = sq, to = sq, promotion = "q"|... }
--   { kind = "ability", ... }   (handled by the mode: game.mode.applyAbility / abilityActions)
-- game:apply(action) validates against the legal list, so a client request can be passed straight
-- in. game.result is nil while the game runs, then { winner = "w"|"b"|nil, reason = "..." }.

local Board = require(script.Parent.Board)
local Moves = require(script.Parent.Moves)
local Notation = require(script.Parent.Notation)

local Game = {}
Game.__index = Game

function Game.new(fen: string?, mode)
	local self = setmetatable(Notation.parseFEN(fen or Notation.START), Game)
	self.mode = mode -- nil or a Modes/* module (rule hooks)
	self.stack = {} -- undo records (Moves.make)
	self.history = {} -- { action, san, key } per applied action
	self.seen = {} -- position key -> times reached
	self.result = nil
	if mode and mode.setup then
		mode.setup(self) -- before the first position key: ability state is part of it
	end
	self.seen[self:key()] = 1
	return self
end

-- A game set up to replay a finished game's actions (saved games, reviews): the mode grants what
-- those actions need (a paid Steal a Piece). Live games use Game.new plus the server's grants.
function Game.forReplay(fen: string?, mode, actions)
	local self = Game.new(fen, mode)
	if mode and mode.prepareReplay then
		mode.prepareReplay(self, actions)
	end
	return self
end

-- Position identity for repetition. The en passant square only counts when a capture is possible.
function Game:key(): string
	local ep = self.ep
	if ep then
		local pawnDir = if self.turn == "w" then -16 else 16
		local can = false
		for _, side in { 1, -1 } do
			local s = ep + pawnDir + side
			local p = Board.onBoard(s) and self.board.sq[s]
			if p and p.type == "p" and p.color == self.turn then
				can = true
			end
		end
		if not can then
			ep = nil
		end
	end
	local realEp = self.ep
	self.ep = ep
	local k = Notation.positionFEN(self)
	self.ep = realEp
	if self.mode and self.mode.stateKey then
		k ..= "|" .. self.mode.stateKey(self) -- ability state is part of the position
	end
	return k
end

function Game:inCheck(color: string?): boolean
	return Moves.inCheck(self, color or self.turn)
end

function Game:legalMoves(from: number?)
	return Moves.legal(self, from)
end

-- All legal actions for the side to move: moves plus whatever the mode adds (abilities).
function Game:legalActions()
	local out = {}
	for _, m in Moves.legal(self) do
		table.insert(out, { kind = "move", from = m.from, to = m.to, promotion = m.promotion, flag = m.flag })
	end
	if self.mode and self.mode.abilityActions then
		for _, a in self.mode.abilityActions(self) do
			table.insert(out, a)
		end
	end
	return out
end

function Game:findMove(from: number, to: number, promotion: string?)
	for _, m in Moves.legal(self, from) do
		if m.to == to and m.promotion == promotion then
			return m
		end
	end
	return nil
end

local function countAndColors(board)
	local minors = {} -- { type, color, squareColor }
	local other = false
	for s, p in board.sq do
		if p.type == "b" or p.type == "n" then
			table.insert(minors, { type = p.type, color = p.color, shade = (Board.file(s) + Board.rank(s)) % 2 })
		elseif p.type ~= "k" then
			other = true
		end
	end
	return minors, other
end

function Game:insufficientMaterial(): boolean
	local minors, other = countAndColors(self.board)
	if other then
		return false
	end
	if #minors <= 1 then
		return true
	end
	-- only bishops, all on the same square colour
	local shade = minors[1].shade
	for _, m in minors do
		if m.type ~= "b" or m.shade ~= shade then
			return false
		end
	end
	return true
end

-- Can `color` still mate at all? (Used for timeouts: a flag against bare material is a draw.)
function Game:canMate(color: string): boolean
	local minors = 0
	for _, p in self.board.sq do
		if p.color == color and p.type ~= "k" then
			if p.type == "b" or p.type == "n" then
				minors += 1
			else
				return true
			end
		end
	end
	return minors >= 2
end

function Game:finish(winner: string?, reason: string)
	self.result = { winner = winner, reason = reason }
end

-- After an action: checkmate, stalemate, and the automatic draws.
function Game:updateResult()
	local actions = self:legalActions()
	if #actions == 0 then
		if self:inCheck() then
			self:finish(Board.other(self.turn), "checkmate")
		else
			self:finish(nil, "stalemate")
		end
	elseif self.mode and self.mode.checkResult and self.mode.checkResult(self) then
		return -- the mode set game.result itself (e.g. a king was captured by an ability)
	elseif self.seen[self:key()] >= 3 then
		self:finish(nil, "repetition")
	elseif self.halfmove >= 100 then
		self:finish(nil, "fifty-move rule")
	elseif self:insufficientMaterial() then
		self:finish(nil, "insufficient material")
	end
end

-- Validates and applies an action. Returns true, or false and a reason.
function Game:apply(action)
	if self.result then
		return false, "game over"
	end
	local san
	if action.kind == "move" or action.kind == nil then
		local m = self:findMove(action.from, action.to, action.promotion)
		if not m then
			return false, "illegal move"
		end
		san = Notation.san(self, m)
		Moves.make(self, m)
		self.stack[#self.stack].action = { kind = "move", from = m.from, to = m.to, promotion = m.promotion }
	elseif action.kind == "ability" then
		local mode = self.mode
		if not (mode and mode.applyAbility) then
			return false, "no abilities in this mode"
		end
		local ok, text = mode.applyAbility(self, action) -- validates, pushes its own undo record
		if not ok then
			return false, text or "illegal ability"
		end
		san = text
	else
		return false, "unknown action"
	end
	if self.mode and self.mode.onTurnStart then
		-- anything this changes (cooldown ticks) must be recorded on self.stack[#self.stack] so undo
		-- can reverse it
		self.mode.onTurnStart(self, self.turn)
	end
	local key = self:key()
	self.seen[key] = (self.seen[key] or 0) + 1
	table.insert(self.history, { action = action, san = san, key = key })
	self:updateResult()
	return true
end

-- Low level, for search: apply an action already known to be legal (from Moves.legal or the mode's
-- abilityActions) with no validation, SAN, history or result. Undo it with pop().
function Game:push(action)
	if action.kind == "ability" then
		self.mode.applyAbility(self, action, true) -- trusted: already known legal
	else
		Moves.make(self, action)
	end
	if self.mode and self.mode.onTurnStart then
		self.mode.onTurnStart(self, self.turn)
	end
end

function Game:pop()
	local rec = self.stack[#self.stack]
	if rec.undo then
		rec.undo(self) -- ability records carry their own undo
		table.remove(self.stack)
	else
		Moves.unmake(self)
	end
	if rec.onPop then
		rec.onPop(self) -- what the mode's onTurnStart changed
	end
end

function Game:undo(): boolean
	local h = table.remove(self.history)
	if not h then
		return false
	end
	self.seen[h.key] -= 1
	if self.seen[h.key] == 0 then
		self.seen[h.key] = nil
	end
	self:pop()
	self.result = nil
	return true
end

-- An independent copy of the current position (board, rights, repetition counts, ability state)
-- with an empty undo stack and history. The bot searches a clone so the live game never changes
-- mid-search.
function Game:clone()
	local c = setmetatable({}, Game)
	c.board = self.board:clone()
	c.turn, c.castle, c.ep = self.turn, self.castle, self.ep
	c.halfmove, c.fullmove = self.halfmove, self.fullmove
	c.mode = self.mode
	c.stack, c.history = {}, {}
	c.seen = table.clone(self.seen)
	c.result = self.result
	for k, v in self do
		if c[k] == nil and k ~= "stack" and k ~= "history" then
			c[k] = Board.deepCopy(v) -- extra state a mode keeps on the game (ability state)
		end
	end
	return c
end

function Game:resign(color: string)
	if not self.result then
		self:finish(Board.other(color), "resignation")
	end
end

function Game:agreeDraw()
	if not self.result then
		self:finish(nil, "agreement")
	end
end

function Game:timeout(color: string)
	if not self.result then
		local winner = Board.other(color)
		if self:canMate(winner) then
			self:finish(winner, "timeout")
		else
			self:finish(nil, "timeout vs insufficient material")
		end
	end
end

function Game:fen(): string
	return Notation.toFEN(self)
end

-- SAN move list as one string: "1. e4 e5 2. Nf3"
function Game:moveList(): string
	local out = {}
	for i, h in self.history do
		if i % 2 == 1 then
			table.insert(out, ((i + 1) // 2) .. ".")
		end
		table.insert(out, h.san)
	end
	return table.concat(out, " ")
end

return Game
