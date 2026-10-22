--!strict
-- 0x88 board. Square index = rank * 16 + file (both 0-based); a square is on the board when
-- bit32.band(sq, 0x88) == 0. Pieces are tables: { type = "p"|"n"|"b"|"r"|"q"|"k", color = "w"|"b",
-- id = number, moved = boolean, data = {} } (data holds ability state). Pure: no Roblox services.

local Board = {}
Board.__index = Board

export type Piece = { type: string, color: string, id: number, moved: boolean, data: { [any]: any } }

function Board.new()
	local self = setmetatable({}, Board)
	self.sq = {} :: { [number]: Piece }
	self.kings = {} :: { [string]: number? } -- color -> king square (nil if that side has no king)
	self.nextId = 1
	return self
end

function Board.onBoard(s: number): boolean
	return s >= 0 and s < 128 and bit32.band(s, 0x88) == 0
end

function Board.index(file: number, rank: number): number
	return rank * 16 + file
end

function Board.file(s: number): number
	return bit32.band(s, 7)
end

function Board.rank(s: number): number
	return bit32.rshift(s, 4)
end

function Board.name(s: number): string
	return string.char(97 + Board.file(s)) .. tostring(Board.rank(s) + 1)
end

function Board.parse(name: string): number?
	local f, r = string.byte(name, 1), tonumber(string.sub(name, 2, 2))
	if not f or not r or f < 97 or f > 104 or r < 1 or r > 8 then
		return nil
	end
	return Board.index(f - 97, r - 1)
end

function Board.other(color: string): string
	return if color == "w" then "b" else "w"
end

-- every on-board square, a1, b1 ... h8
Board.squares = {} :: { number }
for rank = 0, 7 do
	for file = 0, 7 do
		table.insert(Board.squares, rank * 16 + file)
	end
end

function Board:get(s: number): Piece?
	return self.sq[s]
end

function Board:newPiece(pieceType: string, color: string): Piece
	local p = { type = pieceType, color = color, id = self.nextId, moved = false, data = {} }
	self.nextId += 1
	return p
end

function Board:place(s: number, p: Piece)
	self.sq[s] = p
	if p.type == "k" then
		self.kings[p.color] = s
	end
end

function Board:remove(s: number): Piece?
	local p = self.sq[s]
	self.sq[s] = nil
	if p and p.type == "k" and self.kings[p.color] == s then
		self.kings[p.color] = nil
	end
	return p
end

local function deepCopy(t: any): any
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in t do
		c[k] = deepCopy(v)
	end
	return c
end
Board.deepCopy = deepCopy

function Board:clone()
	local c = Board.new()
	for s, p in self.sq do
		c.sq[s] = deepCopy(p)
	end
	for color, s in self.kings do
		c.kings[color] = s
	end
	c.nextId = self.nextId
	return c
end

return Board
