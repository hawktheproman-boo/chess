-- The chess bot: evaluation + alpha-beta search. Pure Luau (no services); the caller passes a clock
-- and an optional yield so a server can spread the search over frames.
--
--   local action, info = Search.choose(gameClone, Search.LEVELS[3], { now = os.clock, yield = fn, rng = Random.new() })
--
-- Moves and ability actions go through the same list: legal moves from Moves.legal plus the mode's
-- abilityActions, applied with game:push / game:pop, so abilities need no bot changes.
-- Search works on whatever game it is given and mutates it during the search: pass a clone.

local Chess = script.Parent.Parent.Chess
local Board = require(Chess.Board)
local Moves = require(Chess.Moves)

local Search = {}

-- Difficulty levels. depth = max iterative-deepening depth, time = seconds budget,
-- margin = pick randomly among root moves within this many centipawns of the best,
-- blunder = chance of a random legal move, think = minimum seconds before moving (feels human).
Search.LEVELS = {
	{ id = 1, name = "Beginner", depth = 1, time = 0.3, margin = 150, blunder = 0.2, think = 0.8 },
	{ id = 2, name = "Casual", depth = 2, time = 0.6, margin = 50, blunder = 0.05, think = 0.8 },
	{ id = 3, name = "Club", depth = 3, time = 1.5, margin = 15, blunder = 0, think = 0.6 },
	{ id = 4, name = "Strong", depth = 6, time = 2.5, margin = 0, blunder = 0, think = 0.4 },
}

local VALUE = { p = 100, n = 320, b = 330, r = 500, q = 900, k = 0 }
Search.VALUE = VALUE
local MATE = 100000
Search.MATE = MATE

-- Piece-square tables (Michniewski's simplified evaluation), White's view, rank 8 first.
local PST = {
	p = {
		0, 0, 0, 0, 0, 0, 0, 0,
		50, 50, 50, 50, 50, 50, 50, 50,
		10, 10, 20, 30, 30, 20, 10, 10,
		5, 5, 10, 25, 25, 10, 5, 5,
		0, 0, 0, 20, 20, 0, 0, 0,
		5, -5, -10, 0, 0, -10, -5, 5,
		5, 10, 10, -20, -20, 10, 10, 5,
		0, 0, 0, 0, 0, 0, 0, 0,
	},
	n = {
		-50, -40, -30, -30, -30, -30, -40, -50,
		-40, -20, 0, 0, 0, 0, -20, -40,
		-30, 0, 10, 15, 15, 10, 0, -30,
		-30, 5, 15, 20, 20, 15, 5, -30,
		-30, 0, 15, 20, 20, 15, 0, -30,
		-30, 5, 10, 15, 15, 10, 5, -30,
		-40, -20, 0, 5, 5, 0, -20, -40,
		-50, -40, -30, -30, -30, -30, -40, -50,
	},
	b = {
		-20, -10, -10, -10, -10, -10, -10, -20,
		-10, 0, 0, 0, 0, 0, 0, -10,
		-10, 0, 5, 10, 10, 5, 0, -10,
		-10, 5, 5, 10, 10, 5, 5, -10,
		-10, 0, 10, 10, 10, 10, 0, -10,
		-10, 10, 10, 10, 10, 10, 10, -10,
		-10, 5, 0, 0, 0, 0, 5, -10,
		-20, -10, -10, -10, -10, -10, -10, -20,
	},
	r = {
		0, 0, 0, 0, 0, 0, 0, 0,
		5, 10, 10, 10, 10, 10, 10, 5,
		-5, 0, 0, 0, 0, 0, 0, -5,
		-5, 0, 0, 0, 0, 0, 0, -5,
		-5, 0, 0, 0, 0, 0, 0, -5,
		-5, 0, 0, 0, 0, 0, 0, -5,
		-5, 0, 0, 0, 0, 0, 0, -5,
		0, 0, 0, 5, 5, 0, 0, 0,
	},
	q = {
		-20, -10, -10, -5, -5, -10, -10, -20,
		-10, 0, 0, 0, 0, 0, 0, -10,
		-10, 0, 5, 5, 5, 5, 0, -10,
		-5, 0, 5, 5, 5, 5, 0, -5,
		0, 0, 5, 5, 5, 5, 0, -5,
		-10, 5, 5, 5, 5, 5, 0, -10,
		-10, 0, 5, 0, 0, 0, 0, -10,
		-20, -10, -10, -5, -5, -10, -10, -20,
	},
	k = {
		-30, -40, -40, -50, -50, -40, -40, -30,
		-30, -40, -40, -50, -50, -40, -40, -30,
		-30, -40, -40, -50, -50, -40, -40, -30,
		-30, -40, -40, -50, -50, -40, -40, -30,
		-20, -30, -30, -40, -40, -30, -30, -20,
		-10, -20, -20, -20, -20, -20, -20, -10,
		20, 20, 0, 0, 0, 0, 20, 20,
		20, 30, 10, 0, 0, 10, 30, 20,
	},
	kEnd = {
		-50, -40, -30, -20, -20, -30, -40, -50,
		-30, -20, -10, 0, 0, -10, -20, -30,
		-30, -10, 20, 30, 30, 20, -10, -30,
		-30, -10, 30, 40, 40, 30, -10, -30,
		-30, -10, 30, 40, 40, 30, -10, -30,
		-30, -10, 20, 30, 30, 20, -10, -30,
		-30, -30, 0, 0, 0, 0, -30, -30,
		-50, -30, -30, -30, -30, -30, -30, -50,
	},
}
local FULL_PHASE = 2 * (2 * 320 + 2 * 330 + 2 * 500 + 900) -- non-pawn material at the start

local function pstIndex(s: number, color: string): number
	local file, rank = Board.file(s), Board.rank(s)
	if color == "w" then
		return (7 - rank) * 8 + file + 1
	end
	return rank * 8 + file + 1
end

-- Static evaluation in centipawns from the side to move's point of view.
function Search.evaluate(game): number
	local score, phase = 0, 0
	local wk, bk
	for s, p in game.board.sq do
		local v = VALUE[p.type] or 0
		if p.type == "k" then
			if p.color == "w" then wk = s else bk = s end
		else
			if p.type ~= "p" then
				phase += v
			end
			local t = PST[p.type]
			local pv = v + (if t then t[pstIndex(s, p.color)] else 0)
			score += if p.color == "w" then pv else -pv
		end
	end
	-- king: blend middlegame and endgame tables by remaining material
	local mg = math.clamp(phase / FULL_PHASE, 0, 1)
	for _, pair in { { wk, "w" }, { bk, "b" } } do
		local s = pair[1]
		if s then
			local i = pstIndex(s, pair[2])
			local v = mg * PST.k[i] + (1 - mg) * PST.kEnd[i]
			score += if pair[2] == "w" then v else -v
		end
	end
	return if game.turn == "w" then score else -score
end

-- Legal actions for the side to move: moves plus mode abilities.
local function actions(game)
	local list = Moves.legal(game)
	local mode = game.mode
	if mode and mode.abilityActions then
		-- only the abilities that capture (or escape check), unless nothing else is legal: then
		-- every one, so a quiet ability that's the only way out isn't scored as mate
		for _, a in mode.abilityActions(game, #list > 0) do
			table.insert(list, a)
		end
	end
	return list
end

local function sameAction(a, b)
	if not a or not b then
		return false
	end
	return a.from == b.from and a.to == b.to and a.promotion == b.promotion and a.kind == b.kind and a.id == b.id
		and a.dir == b.dir and a.mid == b.mid -- (a direction / first landing tells abilities of one piece apart)
end

-- MVV-LVA ordering: best move from the last iteration first, then captures (most valuable victim,
-- least valuable attacker), then promotions, then the rest.
local function order(game, list, first)
	local sq = game.board.sq
	for _, m in list do
		local s = 0
		if sameAction(m, first) then
			s = 1e7
		elseif m.kind == "ability" then
			-- like a capture of everything it removes
			local mode = game.mode
			local gain = if mode and mode.abilityScore then mode.abilityScore(game, m, VALUE) else 0
			s = if gain > 0 then 1e5 + 10 * gain else 50
		else
			local victim = sq[m.to]
			if m.flag == "ep" then
				s = 1e5 + 10 * 100 - 100
			elseif victim then
				s = 1e5 + 10 * (VALUE[victim.type] or 0) - (VALUE[sq[m.from].type] or 0)
			end
			if m.promotion then
				s += 9e4 + VALUE[m.promotion]
			end
		end
		m.score = s
	end
	table.sort(list, function(a, b)
		return a.score > b.score
	end)
end

local Ctx = {}
Ctx.__index = Ctx

function Ctx:checkTime()
	self.nodes += 1
	if self.nodes % 256 == 0 then
		local t = self.now()
		if t >= self.deadline then
			self.stopped = true
		elseif self.yield and t - self.lastYield > self.slice then
			self.yield()
			local back = self.now()
			if self.computeBudget then
				self.deadline += back - t -- the budget counts thinking time only, not time spent waiting
			end
			self.lastYield = back
		end
	end
	return self.stopped
end

function Ctx:quiesce(alpha, beta, qdepth)
	if self:checkTime() then
		return 0
	end
	local game = self.game
	local stand = Search.evaluate(game)
	if stand >= beta then
		return stand
	end
	if stand > alpha then
		alpha = stand
	end
	if qdepth <= 0 then
		return stand
	end
	local color = game.turn
	local enemy = Board.other(color)
	local sq = game.board.sq
	local caps = {}
	for _, m in Moves.pseudo(game, color) do
		if sq[m.to] or m.flag == "ep" or m.promotion == "q" then
			table.insert(caps, m)
		end
	end
	-- abilities that remove material count as captures here, so a snipe one move past the search
	-- depth isn't invisible (that made Abilities evals swing by several pawns from ply to ply)
	local mode = game.mode
	if mode and mode.abilityActions then
		for _, a in mode.abilityActions(game, true) do -- (already legal)
			if mode.abilityScore == nil or mode.abilityScore(game, a, VALUE) > 0 then
				table.insert(caps, a)
			end
		end
	end
	order(game, caps, nil)
	local best = stand
	for _, m in caps do
		local legal
		if m.kind == "ability" then
			game:push(m)
			legal = true
		else
			Moves.make(game, m)
			local k = game.board.kings[color]
			legal = k == nil or not Moves.isAttacked(game.board, k, enemy)
		end
		if legal then
			local score = -self:quiesce(-beta, -alpha, qdepth - 1)
			if m.kind == "ability" then
				game:pop()
			else
				Moves.unmake(game)
			end
			if self.stopped then
				return 0
			end
			if score > best then
				best = score
			end
			if score > alpha then
				alpha = score
			end
			if alpha >= beta then
				break
			end
		else
			Moves.unmake(game)
		end
	end
	return best
end

function Ctx:negamax(depth, alpha, beta, ply)
	if self:checkTime() then
		return 0
	end
	local game = self.game
	if ply > 0 and game.halfmove >= 100 then
		return 0
	end
	if ply == 1 and (game.seen[game:key()] or 0) >= 2 then
		return 0 -- this root move repeats a position for the third time: a draw
	end
	local inCheck = Moves.inCheck(game, game.turn)
	if inCheck then
		depth += 1 -- check extension
	end
	if depth <= 0 then
		return self:quiesce(alpha, beta, 6)
	end
	local list = actions(game)
	if #list == 0 then
		return if inCheck then -MATE + ply else 0
	end
	if ply == 0 and self.skip then
		for i = #list, 1, -1 do
			if self.skip(list[i]) then
				table.remove(list, i)
			end
		end
	end
	order(game, list, if ply == 0 then self.rootBest else nil)
	local best = -math.huge
	for _, m in list do
		game:push(m)
		local score = -self:negamax(depth - 1, -beta, -alpha, ply + 1)
		game:pop()
		if self.stopped then
			return 0
		end
		if score > best then
			best = score
			if ply == 0 then
				self.iterBest = m
			end
		end
		if score > alpha then
			alpha = score
		end
		if alpha >= beta then
			break
		end
	end
	return best
end

local function toAction(m)
	if m.kind == "ability" then
		local a = table.clone(m)
		a.score = nil
		return a
	end
	return { kind = "move", from = m.from, to = m.to, promotion = m.promotion }
end

-- Picks an action for the side to move. opts: now (function, seconds), yield (optional function),
-- rng (Random), budget (seconds, overrides level.time), skip (fn(action) -> true to leave a root
-- action out), slice (seconds of thinking between yields, default 0.004 - keep it small so a server
-- or client frame never stalls), computeBudget (true: waiting in yields doesn't use up the budget).
-- Returns action, info.
function Search.choose(game, level, opts)
	opts = opts or {}
	local now = opts.now or os.clock
	local rng = opts.rng or Random.new()
	local list = actions(game)
	if opts.skip then
		-- leave some root actions out (the review asks for the best move other than X)
		for i = #list, 1, -1 do
			if opts.skip(list[i]) then
				table.remove(list, i)
			end
		end
	end
	if #list == 0 then
		return nil, { reason = "no legal actions" }
	end
	if #list == 1 then
		return toAction(list[1]), { depth = 0, nodes = 0, forced = true }
	end
	if level.blunder > 0 and rng:NextNumber() < level.blunder then
		return toAction(list[rng:NextInteger(1, #list)]), { depth = 0, nodes = 0, blunder = true }
	end
	local start = now()
	local ctx = setmetatable({
		game = game,
		now = now,
		yield = opts.yield,
		lastYield = start,
		deadline = start + (opts.budget or level.time),
		slice = opts.slice or 0.004,
		computeBudget = opts.computeBudget == true,
		skip = opts.skip,
		nodes = 0,
		stopped = false,
	}, Ctx)

	if level.margin > 0 then
		-- weaker levels: score every root move exactly at a fixed depth, then pick near the best
		local scored = {}
		for depth = 1, level.depth do
			local pass = {}
			for _, m in list do
				game:push(m)
				local s = -ctx:negamax(depth - 1, -math.huge, math.huge, 1)
				game:pop()
				if ctx.stopped then
					break
				end
				table.insert(pass, { m = m, s = s })
			end
			if ctx.stopped and #scored > 0 then
				break
			end
			if #pass == #list or #scored == 0 then
				scored = pass
			end
			if ctx.stopped then
				break
			end
		end
		table.sort(scored, function(a, b)
			return a.s > b.s
		end)
		local best = scored[1].s
		local near = {}
		for _, e in scored do
			-- never pick away from a found mate
			if e.s >= best - level.margin and (best < MATE - 1000 or e.s == best) then
				table.insert(near, e)
			end
		end
		local pick = near[rng:NextInteger(1, #near)]
		return toAction(pick.m), { depth = level.depth, nodes = ctx.nodes, score = pick.s, best = best,
			choices = #near, time = now() - start }
	end

	-- strong: iterative deepening alpha-beta; keep the last completed iteration's move
	local bestMove, bestScore, reached = list[1], 0, 0
	for depth = 1, level.depth do
		ctx.iterBest = nil
		local score = ctx:negamax(depth, -math.huge, math.huge, 0)
		if ctx.stopped then
			-- a partial iteration searched the previous best first, so its best is at least as good
			if ctx.iterBest then
				bestMove = ctx.iterBest
			end
			break
		end
		bestMove, bestScore, reached = ctx.iterBest or bestMove, score, depth
		ctx.rootBest = bestMove
		if score >= MATE - 1000 then
			break -- found a forced mate
		end
	end
	return toAction(bestMove), { depth = reached, nodes = ctx.nodes, score = bestScore, time = now() - start }
end

return Search
