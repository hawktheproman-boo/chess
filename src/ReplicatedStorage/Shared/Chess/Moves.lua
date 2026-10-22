-- Move generation, attack detection and make/unmake for a game state (see Game). Pure Luau.
-- A move is { from, to, promotion = "q"|"r"|"b"|"n"|nil, flag = "double"|"ep"|"castle"|nil }.
-- Mode hooks (optional, on game.mode): modifyMoves(game, square, piece, moves) runs on each
-- piece's pseudo-legal moves, so abilities can add or remove moves. Legality is checked here for
-- everything: no move may leave the mover's own king attacked.

local Board = require(script.Parent.Board)

local band = bit32.band
local onBoard = Board.onBoard

local Moves = {}

local KNIGHT = { 33, 31, 18, 14, -33, -31, -18, -14 }
local KING = { 1, -1, 16, -16, 17, 15, -17, -15 }
local DIAG = { 17, 15, -17, -15 }
local ORTHO = { 1, -1, 16, -16 }
local PROMOS = { "q", "r", "b", "n" }
local SIDES = { 1, -1 }
Moves.PROMOS = PROMOS

-- castling rights bitmask: white king-side 1, white queen-side 2, black king-side 4, black queen-side 8
Moves.WK, Moves.WQ, Moves.BK, Moves.BQ = 1, 2, 4, 8
-- rights kept when a move touches a square (from or to): moving a king or rook, or capturing a rook
local KEEP = {}
for _, s in Board.squares do
	KEEP[s] = 15
end
KEEP[0x04] = 15 - 1 - 2 -- e1
KEEP[0x07] = 15 - 1 -- h1
KEEP[0x00] = 15 - 2 -- a1
KEEP[0x74] = 15 - 4 - 8 -- e8
KEEP[0x77] = 15 - 4 -- h8
KEEP[0x70] = 15 - 8 -- a8
Moves.KEEP = KEEP -- abilities that remove pieces use it too

-- Is square s attacked by any piece of color `by`?
function Moves.isAttacked(board, s: number, by: string): boolean
	local sq = board.sq
	-- pawns: a pawn of `by` attacks diagonally forward, so look diagonally backward from s
	local back = if by == "w" then -16 else 16
	for _, side in SIDES do
		local t = s + back + side
		if onBoard(t) then
			local p = sq[t]
			if p and p.color == by and p.type == "p" then
				return true
			end
		end
	end
	for _, d in KNIGHT do
		local t = s + d
		if onBoard(t) then
			local p = sq[t]
			if p and p.color == by and p.type == "n" then
				return true
			end
		end
	end
	for _, d in KING do
		local t = s + d
		if onBoard(t) then
			local p = sq[t]
			if p and p.color == by and p.type == "k" then
				return true
			end
		end
	end
	for _, d in DIAG do
		local t = s + d
		while onBoard(t) do
			local p = sq[t]
			if p then
				if p.color == by and (p.type == "b" or p.type == "q") then
					return true
				end
				break
			end
			t += d
		end
	end
	for _, d in ORTHO do
		local t = s + d
		while onBoard(t) do
			local p = sq[t]
			if p then
				if p.color == by and (p.type == "r" or p.type == "q") then
					return true
				end
				break
			end
			t += d
		end
	end
	return false
end

function Moves.inCheck(game, color: string): boolean
	local k = game.board.kings[color]
	return k ~= nil and Moves.isAttacked(game.board, k, Board.other(color))
end

local function add(list, from, to, flag)
	table.insert(list, { from = from, to = to, flag = flag })
end

local function addPawn(list, from, to, promoRank, flag)
	if Board.rank(to) == promoRank then
		for _, promo in PROMOS do
			table.insert(list, { from = from, to = to, promotion = promo })
		end
	else
		add(list, from, to, flag)
	end
end

local function slide(list, sq, from, color, dirs)
	for _, d in dirs do
		local t = from + d
		while onBoard(t) do
			local p = sq[t]
			if p then
				if p.color ~= color then
					add(list, from, t)
				end
				break
			end
			add(list, from, t)
			t += d
		end
	end
end

-- Pseudo-legal moves for the piece on `from` (own king safety not checked yet, except castling
-- through or out of check).
function Moves.pieceMoves(game, from: number, list)
	list = list or {}
	local board = game.board
	local sq = board.sq
	local p = sq[from]
	if not p then
		return list
	end
	local color, kind = p.color, p.type
	local start = #list
	if kind == "p" then
		local dir = if color == "w" then 16 else -16
		local startRank = if color == "w" then 1 else 6
		local promoRank = if color == "w" then 7 else 0
		local one = from + dir
		if onBoard(one) and not sq[one] then
			addPawn(list, from, one, promoRank)
			local two = one + dir
			if Board.rank(from) == startRank and not sq[two] then
				add(list, from, two, "double")
			end
		end
		for _, side in SIDES do
			local t = from + dir + side
			if onBoard(t) then
				local q = sq[t]
				if q and q.color ~= color then
					addPawn(list, from, t, promoRank)
				elseif t == game.ep and not q then
					add(list, from, t, "ep")
				end
			end
		end
	elseif kind == "n" or kind == "k" then
		for _, d in (if kind == "n" then KNIGHT else KING) do
			local t = from + d
			if onBoard(t) then
				local q = sq[t]
				if not q or q.color ~= color then
					add(list, from, t)
				end
			end
		end
		if kind == "k" then
			Moves.castles(game, from, color, list)
		end
	elseif kind == "b" then
		slide(list, sq, from, color, DIAG)
	elseif kind == "r" then
		slide(list, sq, from, color, ORTHO)
	elseif kind == "q" then
		slide(list, sq, from, color, DIAG)
		slide(list, sq, from, color, ORTHO)
	end
	local mode = game.mode
	if mode and mode.modifyMoves then
		-- hand the hook only this piece's moves
		local own, n = {}, #list
		for i = start + 1, n do
			table.insert(own, list[i])
		end
		for i = n, start + 1, -1 do
			list[i] = nil
		end
		own = mode.modifyMoves(game, from, p, own) or own
		for _, m in own do
			table.insert(list, m)
		end
	end
	return list
end

function Moves.castles(game, from, color, list)
	local home = if color == "w" then 0x04 else 0x74
	if from ~= home then
		return
	end
	local sq = game.board.sq
	local enemy = Board.other(color)
	local kSide = if color == "w" then Moves.WK else Moves.BK
	local qSide = if color == "w" then Moves.WQ else Moves.BQ
	local function rookOn(s)
		local r = sq[s]
		return r ~= nil and r.type == "r" and r.color == color
	end
	if band(game.castle, kSide + qSide) == 0 or Moves.isAttacked(game.board, from, enemy) then
		return
	end
	if band(game.castle, kSide) ~= 0 and rookOn(from + 3) and not sq[from + 1] and not sq[from + 2]
		and not Moves.isAttacked(game.board, from + 1, enemy)
		and not Moves.isAttacked(game.board, from + 2, enemy) then
		add(list, from, from + 2, "castle")
	end
	if band(game.castle, qSide) ~= 0 and rookOn(from - 4) and not sq[from - 1] and not sq[from - 2]
		and not sq[from - 3]
		and not Moves.isAttacked(game.board, from - 1, enemy)
		and not Moves.isAttacked(game.board, from - 2, enemy) then
		add(list, from, from - 2, "castle")
	end
end

function Moves.pseudo(game, color: string)
	local list = {}
	local sq = game.board.sq
	for _, s in Board.squares do
		local p = sq[s]
		if p and p.color == color then
			Moves.pieceMoves(game, s, list)
		end
	end
	return list
end

-- Apply a move to the game state; returns nothing. Pushes an undo record onto game.stack.
function Moves.make(game, m)
	local board = game.board
	local sq = board.sq
	local piece = sq[m.from]
	local rec = {
		move = m,
		castle = game.castle,
		ep = game.ep,
		halfmove = game.halfmove,
		fullmove = game.fullmove,
		moved = piece.moved,
	}
	local capSq = m.to
	if m.flag == "ep" then
		capSq = m.to + (if piece.color == "w" then -16 else 16)
	end
	local cap = sq[capSq]
	if cap then
		rec.captured, rec.capSq = cap, capSq
		board:remove(capSq)
	end
	sq[m.from] = nil
	board:place(m.to, piece)
	piece.moved = true
	if m.flag == "castle" then
		local rookFrom, rookTo
		if m.to > m.from then
			rookFrom, rookTo = m.from + 3, m.from + 1
		else
			rookFrom, rookTo = m.from - 4, m.from - 1
		end
		local rook = sq[rookFrom]
		rec.rookMoved = rook.moved
		sq[rookFrom] = nil
		sq[rookTo] = rook
		rook.moved = true
	end
	if m.promotion then
		piece.type = m.promotion
	end
	game.castle = band(game.castle, KEEP[m.from], KEEP[m.to])
	game.ep = if m.flag == "double" then (m.from + m.to) // 2 else nil
	if piece.type == "p" or m.promotion or cap then
		game.halfmove = 0
	else
		game.halfmove += 1
	end
	if game.turn == "b" then
		game.fullmove += 1
	end
	game.turn = Board.other(game.turn)
	table.insert(game.stack, rec)
end

function Moves.unmake(game)
	local rec = table.remove(game.stack)
	local m = rec.move
	local board = game.board
	local sq = board.sq
	local piece = sq[m.to]
	if m.promotion then
		piece.type = "p"
	end
	sq[m.to] = nil
	board:place(m.from, piece)
	piece.moved = rec.moved
	if m.flag == "castle" then
		local rookFrom, rookTo
		if m.to > m.from then
			rookFrom, rookTo = m.from + 3, m.from + 1
		else
			rookFrom, rookTo = m.from - 4, m.from - 1
		end
		local rook = sq[rookTo]
		sq[rookTo] = nil
		sq[rookFrom] = rook
		rook.moved = rec.rookMoved
	end
	if rec.captured then
		board:place(rec.capSq, rec.captured)
	end
	game.castle, game.ep = rec.castle, rec.ep
	game.halfmove, game.fullmove = rec.halfmove, rec.fullmove
	game.turn = Board.other(game.turn)
	return rec
end

-- Legal moves for the side to move (or the piece on `from` only).
function Moves.legal(game, from: number?)
	local color = game.turn
	local enemy = Board.other(color)
	local pseudo
	if from then
		local p = game.board.sq[from]
		if not p or p.color ~= color then
			return {}
		end
		pseudo = Moves.pieceMoves(game, from)
	else
		pseudo = Moves.pseudo(game, color)
	end
	local out = {}
	for _, m in pseudo do
		Moves.make(game, m)
		local k = game.board.kings[color]
		if k == nil or not Moves.isAttacked(game.board, k, enemy) then
			table.insert(out, m)
		end
		Moves.unmake(game)
	end
	return out
end

function Moves.perft(game, depth: number): number
	if depth == 0 then
		return 1
	end
	local moves = Moves.legal(game)
	if depth == 1 then
		return #moves
	end
	local n = 0
	for _, m in moves do
		Moves.make(game, m)
		n += Moves.perft(game, depth - 1)
		Moves.unmake(game)
	end
	return n
end

-- perft per root move, for tracking down a wrong count
function Moves.divide(game, depth: number)
	local out = {}
	for _, m in Moves.legal(game) do
		Moves.make(game, m)
		out[Board.name(m.from) .. Board.name(m.to) .. (m.promotion or "")] = Moves.perft(game, depth - 1)
		Moves.unmake(game)
	end
	return out
end

return Moves
