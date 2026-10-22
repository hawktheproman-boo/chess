-- Game review: the bot searches every position of a finished game, then each move is graded by how
-- much it lowered the mover's winning chances compared with the best move (lichess-style win %,
-- so a pawn lost in a won position matters less than in an equal one). Pure Luau: the caller
-- passes a clock and a yield, so the client can analyse over many frames.
--
--   Review.analyse({ startFen, mode = modeModule?, actions }, {
--       now = os.clock, yield = fn, budget = 0.3, depth = 5,
--       onPly = fn(i, entry), onProgress = fn(done, total) })  -> entries, summary
--
-- entry (one per ply): { san, mover, class, drop, accuracy, cpBefore, cpAfter (White's view,
--   centipawns, mates as ±10000), mateAfter (moves to mate, + White / - Black, or nil),
--   best = action, bestSan, played = action,
--   ability (the move was an ability), missedAbility (an ability was best and the move cost
--   10%+ win chance) }

local Chess = script.Parent.Parent.Chess
local Game = require(Chess.Game)
local Moves = require(Chess.Moves)
local Search = require(script.Parent.Search)

local Review = {}

local MATE = Search.MATE
local MATE_CP = 10000

-- grade names, best first, with the colours the review screen uses
Review.CLASSES = {
	{ id = "brilliant", name = "Brilliant", symbol = "!!", color = Color3.fromRGB(27, 172, 166) },
	{ id = "great", name = "Great", symbol = "!", color = Color3.fromRGB(92, 139, 196) },
	{ id = "best", name = "Best", symbol = "★", color = Color3.fromRGB(106, 168, 79) },
	{ id = "excellent", name = "Excellent", symbol = "✓", color = Color3.fromRGB(130, 190, 80) },
	{ id = "good", name = "Good", symbol = "○", color = Color3.fromRGB(140, 160, 120) },
	{ id = "forced", name = "Forced", symbol = "•", color = Color3.fromRGB(150, 150, 150) },
	{ id = "inaccuracy", name = "Inaccuracy", symbol = "?!", color = Color3.fromRGB(240, 190, 50) },
	{ id = "mistake", name = "Mistake", symbol = "?", color = Color3.fromRGB(245, 140, 60) },
	{ id = "blunder", name = "Blunder", symbol = "??", color = Color3.fromRGB(225, 70, 55) },
}
Review.CLASS = {}
for _, c in Review.CLASSES do
	Review.CLASS[c.id] = c
end

-- centipawns (side to move's view) -> win chance 0..100
function Review.winPercent(cp: number): number
	return 50 + 50 * (2 / (1 + math.exp(-0.00368208 * cp)) - 1)
end

-- search scores -> centipawns, mates as ±MATE_CP
local function toCp(score: number): number
	if score >= MATE - 1000 then
		return MATE_CP
	elseif score <= -(MATE - 1000) then
		return -MATE_CP
	end
	return math.clamp(score, -(MATE_CP - 1), MATE_CP - 1)
end

-- moves until mate from a search score (side to move's view): + we mate, - we get mated
local function mateIn(score: number): number?
	if score >= MATE - 1000 then
		return math.ceil((MATE - score) / 2)
	elseif score <= -(MATE - 1000) then
		return -math.ceil((MATE + score) / 2)
	end
	return nil
end

local function sameAction(a, b)
	if not (a and b) then
		return false
	end
	if (a.kind or "move") ~= (b.kind or "move") then
		return false
	end
	if a.kind == "ability" then
		return a.id == b.id and a.from == b.from and a.dir == b.dir and a.mid == b.mid and a.to == b.to
	end
	return a.from == b.from and a.to == b.to and a.promotion == b.promotion
end

local function classify(drop: number, isBest: boolean, forced: boolean): string
	if forced then
		return "forced"
	elseif isBest then
		return "best"
	elseif drop >= 30 then
		return "blunder"
	elseif drop >= 20 then
		return "mistake"
	elseif drop >= 10 then
		return "inaccuracy"
	elseif drop < 2 then
		return "excellent"
	end
	return "good"
end

-- Brilliant: how much material the mover leaves en prise after a move: the biggest loss among the
-- opponent's legal captures of a knight-or-better (all of it if undefended, else the piece minus
-- the cheapest capturer). Legal moves only, so pinned attackers don't count.
local function materialAtRisk(after, mover: string): number
	local VALUE = Search.VALUE
	local sq = after.board.sq
	local risk = 0
	for _, m in after:legalMoves() do
		local target = sq[m.to]
		if target and target.color == mover and (VALUE[target.type] or 0) >= 300 then
			local value = VALUE[target.type]
			local loss = value
			if Moves.isAttacked(after.board, m.to, mover) then
				loss = value - (VALUE[sq[m.from].type] or 0)
			end
			risk = math.max(risk, loss)
		end
	end
	return risk
end

-- material balance (mover minus opponent), kings left out
local function materialLead(game, mover: string): number
	local lead = 0
	for _, piece in game.board.sq do
		local v = Search.VALUE[piece.type] or 0
		lead += if piece.color == mover then v else -v
	end
	return lead
end

-- One position: its score for the side to move, the best action, and whether it was forced.
local function evaluate(game, level, opts)
	if game.result then
		if game.result.reason == "checkmate" then
			return -MATE, nil, false
		end
		if game.result.winner == nil then
			return 0, nil, false
		end
	end
	local actions = game:legalActions()
	if #actions == 0 then
		return (if game:inCheck() then -MATE else 0), nil, false
	end
	local action, info = Search.choose(game:clone(), level, { now = opts.now, yield = opts.yield, slice = opts.slice, computeBudget = true })
	if info.forced then
		-- one legal action: no search score; the static view is enough (it isn't graded)
		return Search.evaluate(game), action, true
	end
	return info.score or 0, action, false
end

-- the SAN of an action in this position
local function sanOf(game, action)
	if not action then
		return nil
	end
	local c = game:clone()
	if c:apply(action) then
		return c.history[#c.history].san
	end
	return nil
end

function Review.analyse(record, opts)
	opts = opts or {}
	opts.now = opts.now or os.clock
	local level = { depth = opts.depth or 5, time = opts.budget or 0.3, margin = 0, blunder = 0 }
	local game = Game.forReplay(record.startFen, record.mode, record.actions)
	local total = #record.actions
	local entries = {}

	local score, best, forced = evaluate(game, level, opts)
	local lastBefore -- the position before the previous move
	for i, action in record.actions do
		local mover = game.turn
		local before = game:clone()
		local ok = game:apply(action)
		if not ok then
			break -- the record doesn't replay (shouldn't happen): stop at what we have
		end
		local san = game.history[#game.history].san
		local nextScore, nextBest, nextForced = evaluate(game, level, opts)
		-- the mover's view: best = score, played = -(opponent's score after the move)
		local bestCp, playedCp = toCp(score), toCp(-nextScore)
		local isBest = sameAction(action, best)
		local drop = if isBest then 0 else math.max(0, Review.winPercent(bestCp) - Review.winPercent(playedCp))
		local class = classify(drop, isBest, forced)
		local bestWin, playedWin = Review.winPercent(bestCp), Review.winPercent(playedCp)
		-- Brilliant: a best (or near-best) move that gives material away on purpose (leaves a knight
		-- or better en prise, worth more than anything it captured) while the mover stays at least
		-- level, and the mover wasn't already well up in material (then a giveaway proves nothing)
		if (class == "best" or class == "excellent") and action.kind ~= "ability" then
			local captured = before.board.sq[action.to]
			local gained = if captured then (Search.VALUE[captured.type] or 0) else 0
			local risk = materialAtRisk(game, mover)
			if risk - gained >= 200 and playedWin >= 45 and materialLead(before, mover) <= 300 then
				class = "brilliant"
			end
		end
		-- Great: the best move when every other move is much worse (20%+ win chance) and that
		-- changes the outcome; plain recaptures don't count
		if class == "best" then
			-- a recapture: the opponent just captured on this square and we take back
			local prev = record.actions[i - 1]
			local recapture = prev ~= nil and prev.to ~= nil and prev.to == action.to and lastBefore ~= nil
				and lastBefore.board.sq[prev.to] ~= nil
			if not recapture then
				local alt, altInfo = Search.choose(before:clone(), { depth = level.depth, time = level.time * 0.8, margin = 0, blunder = 0 },
					{ now = opts.now, yield = opts.yield, slice = opts.slice, computeBudget = true, skip = function(m)
						return sameAction(m, action)
					end })
				if alt then
					local altScore = altInfo.score
					if altInfo.forced or altScore == nil then
						local c = before:clone()
						c:apply(alt)
						altScore = -Search.evaluate(c)
					end
					local altWin = Review.winPercent(toCp(altScore))
					if bestWin - altWin >= 20 and altWin <= 65 then
						class = "great"
					end
				end
			end
		end
		local accuracy = math.clamp(103.1668 * math.exp(-0.04354 * drop) - 3.1669, 0, 100)
		local sign = if mover == "w" then 1 else -1
		local mate = mateIn(nextScore)
		local entry = {
			san = san,
			mover = mover,
			class = class,
			drop = drop,
			accuracy = accuracy,
			cpBefore = sign * bestCp,
			cpAfter = sign * playedCp,
			-- mateIn is from the side now to move; flip it to White's view
			mateAfter = if mate then mate * (if game.turn == "w" then 1 else -1) else nil,
			best = best,
			bestSan = if isBest then san else sanOf(before, best),
			played = action,
			ability = action.kind == "ability",
			missedAbility = not isBest and best ~= nil and best.kind == "ability" and drop >= 10,
		}
		entries[i] = entry
		if opts.onPly then
			opts.onPly(i, entry)
		end
		if opts.onProgress then
			opts.onProgress(i, total)
		end
		if opts.cancelled and opts.cancelled() then
			break
		end
		score, best, forced = nextScore, nextBest, nextForced
		lastBefore = before
	end
	return entries, Review.summary(entries)
end

-- per side: average accuracy (forced moves left out), how many of each grade, abilities used and
-- abilities missed
function Review.summary(entries)
	local out = {}
	for _, color in { "w", "b" } do
		local sum, n, counts, used, missed = 0, 0, {}, 0, 0
		for _, c in Review.CLASSES do
			counts[c.id] = 0
		end
		for _, e in entries do
			if e.mover == color then
				counts[e.class] += 1
				used += if e.ability then 1 else 0
				missed += if e.missedAbility then 1 else 0
				if e.class ~= "forced" then
					sum += e.accuracy
					n += 1
				end
			end
		end
		out[color] = { accuracy = if n > 0 then sum / n else nil, counts = counts, abilitiesUsed = used, abilitiesMissed = missed }
	end
	return out
end

return Review
