-- FEN in/out, SAN (for the move list) and UCI-style coordinates ("e2e4", "e7e8q"). Pure Luau.

local Board = require(script.Parent.Board)
local Moves = require(script.Parent.Moves)

local Notation = {}

Notation.START = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

local CASTLE_CHARS = { K = Moves.WK, Q = Moves.WQ, k = Moves.BK, q = Moves.BQ }

-- Parses a FEN into the state fields a Game uses: board, turn, castle, ep, halfmove, fullmove.
function Notation.parseFEN(fen: string)
	local parts = string.split(fen, " ")
	local board = Board.new()
	local rank, file = 7, 0
	for ch in string.gmatch(parts[1] or "", ".") do
		if ch == "/" then
			rank -= 1
			file = 0
		elseif tonumber(ch) then
			file += tonumber(ch) :: number
		else
			local lower = string.lower(ch)
			assert(string.find("pnbrqk", lower, 1, true), "bad FEN piece " .. ch)
			local color = if ch == lower then "b" else "w"
			local s = Board.index(file, rank)
			local p = board:newPiece(lower, color)
			-- pieces off their start squares count as moved (castling rights decide castling)
			p.moved = not (lower == "p" and rank == (if color == "w" then 1 else 6))
			board:place(s, p)
			file += 1
		end
	end
	local castle = 0
	for ch in string.gmatch(parts[3] or "-", ".") do
		castle += CASTLE_CHARS[ch] or 0
	end
	return {
		board = board,
		turn = if parts[2] == "b" then "b" else "w",
		castle = castle,
		ep = if parts[4] and parts[4] ~= "-" then Board.parse(parts[4]) else nil,
		halfmove = tonumber(parts[5]) or 0,
		fullmove = tonumber(parts[6]) or 1,
	}
end

-- Piece placement + side + castling + en passant: the part of the FEN that identifies a position.
function Notation.positionFEN(game): string
	local rows = {}
	local sq = game.board.sq
	for rank = 7, 0, -1 do
		local row, empty = {}, 0
		for file = 0, 7 do
			local p = sq[Board.index(file, rank)]
			if p then
				if empty > 0 then
					table.insert(row, tostring(empty))
					empty = 0
				end
				table.insert(row, if p.color == "w" then string.upper(p.type) else p.type)
			else
				empty += 1
			end
		end
		if empty > 0 then
			table.insert(row, tostring(empty))
		end
		table.insert(rows, table.concat(row))
	end
	local castle = ""
	for _, pair in { { "K", Moves.WK }, { "Q", Moves.WQ }, { "k", Moves.BK }, { "q", Moves.BQ } } do
		if bit32.band(game.castle, pair[2]) ~= 0 then
			castle ..= pair[1]
		end
	end
	return table.concat(rows, "/") .. " " .. game.turn .. " " .. (if castle == "" then "-" else castle)
		.. " " .. (if game.ep then Board.name(game.ep) else "-")
end

function Notation.toFEN(game): string
	return Notation.positionFEN(game) .. " " .. game.halfmove .. " " .. game.fullmove
end

function Notation.uci(m): string
	return Board.name(m.from) .. Board.name(m.to) .. (m.promotion or "")
end

-- SAN for move m in the current position (call before applying it). `legal` is optional: the
-- side's legal moves, if already generated.
function Notation.san(game, m, legal): string
	local sq = game.board.sq
	local p = sq[m.from]
	local s
	if m.flag == "castle" then
		s = if m.to > m.from then "O-O" else "O-O-O"
	else
		local capture = sq[m.to] ~= nil or m.flag == "ep"
		if p.type == "p" then
			s = (if capture then string.sub(Board.name(m.from), 1, 1) .. "x" else "") .. Board.name(m.to)
			if m.promotion then
				s ..= "=" .. string.upper(m.promotion)
			end
		else
			-- disambiguate between same-type pieces that can reach the same square
			legal = legal or Moves.legal(game)
			local sameFile, sameRank, others = false, false, false
			for _, o in legal do
				if o.to == m.to and o.from ~= m.from and sq[o.from].type == p.type then
					others = true
					if Board.file(o.from) == Board.file(m.from) then
						sameFile = true
					end
					if Board.rank(o.from) == Board.rank(m.from) then
						sameRank = true
					end
				end
			end
			local from = Board.name(m.from)
			local dis = ""
			if others then
				if not sameFile then
					dis = string.sub(from, 1, 1)
				elseif not sameRank then
					dis = string.sub(from, 2, 2)
				else
					dis = from
				end
			end
			s = string.upper(p.type) .. dis .. (if capture then "x" else "") .. Board.name(m.to)
		end
	end
	Moves.make(game, m)
	if Moves.inCheck(game, game.turn) then
		s ..= if #Moves.legal(game) == 0 then "#" else "+"
	end
	Moves.unmake(game)
	return s
end

-- Finds the legal move matching a SAN ("Nf3", "exd5", "O-O", "e8=Q+") or UCI ("g1f3") string.
function Notation.parseMove(game, text: string)
	local clean = string.gsub(text, "[+#!?]", "")
	clean = string.gsub(clean, "0", "O")
	local legal = Moves.legal(game)
	for _, m in legal do
		if Notation.uci(m) == string.lower(text) then
			return m
		end
	end
	for _, m in legal do
		local san = string.gsub(Notation.san(game, m, legal), "[+#]", "")
		if san == clean then
			return m
		end
	end
	return nil
end

return Notation
