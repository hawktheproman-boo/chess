-- Draws one table: piece models (local to this client), move animations, and the board
-- highlights (last move, check, selection, legal targets, controller cursor). Pieces are tracked
-- by the engine's piece ids, so castling, en passant, promotion and future abilities all animate
-- through one diff.
--
-- Highlights are thin slabs floating a little above the squares (never on the same plane as a
-- square) or SelectionBoxes, so nothing z-fights.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Pieces = require(script.Parent.Pieces)

local BoardView = {}
BoardView.__index = BoardView

local MOVE_TIME = 0.24
local ARC = 0.45

local root = workspace:FindFirstChild("ChessLocal") or Instance.new("Folder")
root.Name = "ChessLocal"
root.Parent = workspace

local active = {} -- running animations

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for i = #active, 1, -1 do
		local a = active[i]
		local t = math.clamp((now - a.start) / a.duration, 0, 1)
		-- ease in-out, so the slide and the hop peak together
		local e = if t < 0.5 then 4 * t ^ 3 else 1 - (-2 * t + 2) ^ 3 / 2
		local pos = a.from.Position:Lerp(a.to.Position, e) + Vector3.new(0, math.sin(math.pi * t) * a.arc, 0)
		a.model:PivotTo(CFrame.new(pos) * a.to.Rotation)
		if t >= 1 then
			table.remove(active, i)
			if a.done then
				a.done()
			end
		end
	end
end)

function BoardView.new(model: Model)
	local self = setmetatable({}, BoardView)
	self.model = model
	self.id = model:GetAttribute("TableId")
	self.squares = {}
	for _, p in model.Board:GetChildren() do
		self.squares[p:GetAttribute("Square")] = p
	end
	local a1, h8 = self.squares[0], self.squares[119]
	self.size = a1.Size.X
	self.topY = a1.Position.Y + a1.Size.Y / 2
	self.center = Vector3.new((a1.Position.X + h8.Position.X) / 2, self.topY, (a1.Position.Z + h8.Position.Z) / 2)
	self.folder = Instance.new("Folder")
	self.folder.Name = self.id
	self.folder.Parent = root
	self.models = {} -- piece id -> { model, sq, type, color }
	self.marks = Instance.new("Folder")
	self.marks.Name = "Marks"
	self.marks.Parent = self.folder

	self.cursorBox = Instance.new("SelectionBox")
	self.cursorBox.Color3 = Color3.fromRGB(255, 255, 255)
	self.cursorBox.LineThickness = 0.06
	self.cursorBox.SurfaceTransparency = 1
	self.cursorBox.Parent = self.folder
	self.selectBox = Instance.new("SelectionBox")
	self.selectBox.Color3 = Color3.fromRGB(246, 246, 105)
	self.selectBox.LineThickness = 0.05
	self.selectBox.SurfaceTransparency = 0.7
	self.selectBox.SurfaceColor3 = Color3.fromRGB(246, 246, 105)
	self.selectBox.Parent = self.folder
	return self
end

-- top-centre of a square, facing the right way for a piece of `color`
function BoardView:squareCFrame(sq: number, color: string?): CFrame
	local p = self.squares[sq]
	local pos = Vector3.new(p.Position.X, self.topY, p.Position.Z)
	return CFrame.new(pos) * (if color == "b" then CFrame.Angles(0, math.pi, 0) else CFrame.new())
end

-- world point on the board plane -> square index (or nil off the board)
function BoardView:squareAt(point: Vector3): number?
	local file = math.floor((point.X - self.center.X) / self.size + 4)
	local rank = math.floor(4 - (point.Z - self.center.Z) / self.size)
	if file < 0 or file > 7 or rank < 0 or rank > 7 then
		return nil
	end
	return rank * 16 + file
end

local function fadeOut(model)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			TweenService:Create(p, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		end
	end
	task.delay(0.3, function()
		model:Destroy()
	end)
end

function BoardView:place(entry, sq)
	entry.sq = sq
	entry.model:PivotTo(self:squareCFrame(sq, entry.color))
end

-- Bring the models in line with game.board. animate = slide moved pieces, fade captured ones.
function BoardView:sync(game, animate: boolean)
	local seen = {}
	for sq, piece in game.board.sq do
		seen[piece.id] = true
		local e = self.models[piece.id]
		if not e then
			e = { model = Pieces.build(piece.type, piece.color), type = piece.type, color = piece.color }
			e.model.Parent = self.folder
			self.models[piece.id] = e
			self:place(e, sq)
		elseif e.type ~= piece.type or e.color ~= piece.color then
			-- promotion (or a transformed piece): slide the old model, then swap
			local old, from = e.model, e.sq
			e.model = Pieces.build(piece.type, piece.color)
			e.type, e.color, e.sq = piece.type, piece.color, sq
			if animate and from ~= sq then
				e.model.Parent = nil
				table.insert(active, { model = old, from = self:squareCFrame(from, e.color), to = self:squareCFrame(sq, e.color),
					start = os.clock(), duration = MOVE_TIME, arc = ARC, done = function()
						old:Destroy()
						e.model.Parent = self.folder
						self:place(e, e.sq)
					end })
			else
				old:Destroy()
				e.model.Parent = self.folder
				self:place(e, sq)
			end
		elseif e.sq ~= sq or e.dragging then
			local dragged = e.dragging
			e.dragging = nil
			if animate and e.sq ~= sq then
				-- a dropped piece glides on from where the pointer let go
				local from = if dragged then e.model:GetPivot() else self:squareCFrame(e.sq, e.color)
				e.sq = sq
				table.insert(active, { model = e.model, from = from, to = self:squareCFrame(sq, e.color),
					start = os.clock(), duration = if dragged then MOVE_TIME * 0.6 else MOVE_TIME,
					arc = if dragged then 0 elseif e.type == "n" then ARC * 1.4 else ARC })
			else
				self:place(e, sq)
			end
		end
	end
	for id, e in self.models do
		if not seen[id] then
			self.models[id] = nil
			if animate then
				task.delay(MOVE_TIME * 0.7, fadeOut, e.model)
			else
				e.model:Destroy()
			end
		end
	end
end

function BoardView:clearPieces()
	for id, e in self.models do
		e.model:Destroy()
		self.models[id] = nil
	end
end

function BoardView:modelAt(sq: number)
	for _, e in self.models do
		if e.sq == sq then
			return e
		end
	end
	return nil
end

-- Marks ----------------------------------------------------------------------------------------------

local function slab(parent, cf, size, color, transparency, lift)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.Color = color
	p.Transparency = transparency
	p.CFrame = cf * CFrame.new(0, lift + size.Y / 2, 0)
	p.Parent = parent
	return p
end

-- marks = { lastFrom, lastTo, check (square), selected, targets = { [sq] = "move"|"capture" }, cursor }
function BoardView:setMarks(marks)
	self.marks:ClearAllChildren()
	local s = self.size
	if marks.lastFrom then
		slab(self.marks, self:squareCFrame(marks.lastFrom), Vector3.new(s, 0.02, s), Color3.fromRGB(246, 246, 105), 0.5, 0.006)
	end
	if marks.lastTo then
		slab(self.marks, self:squareCFrame(marks.lastTo), Vector3.new(s, 0.02, s), Color3.fromRGB(246, 246, 105), 0.4, 0.006)
	end
	if marks.check then
		slab(self.marks, self:squareCFrame(marks.check), Vector3.new(s, 0.02, s), Color3.fromRGB(220, 40, 40), 0.35, 0.03)
	end
	for _, t in marks.tints or {} do -- e.g. bishops that can snipe
		slab(self.marks, self:squareCFrame(t), Vector3.new(s, 0.02, s), Color3.fromRGB(246, 246, 105), 0.35, 0.012)
	end
	for sq, kind in marks.targets or {} do
		if kind == "capture" then
			slab(self.marks, self:squareCFrame(sq), Vector3.new(s * 0.94, 0.02, s * 0.94), Color3.fromRGB(226, 84, 70), 0.45, 0.05)
		elseif kind == "swap" then -- (Swap: one of your own pieces)
			slab(self.marks, self:squareCFrame(sq), Vector3.new(s * 0.94, 0.02, s * 0.94), Color3.fromRGB(170, 100, 255), 0.4, 0.05)
		else
			local dot = slab(self.marks, self:squareCFrame(sq), Vector3.new(0.04, s * 0.32, s * 0.32), Color3.fromRGB(30, 30, 30), 0.35, 0.05)
			dot.Shape = Enum.PartType.Cylinder
			dot.CFrame = self:squareCFrame(sq) * CFrame.new(0, 0.07, 0) * CFrame.Angles(0, 0, math.pi / 2)
		end
	end
	self.selectBox.Adornee = if marks.selected then self.squares[marks.selected] else nil
	self.cursorBox.Adornee = if marks.cursor then self.squares[marks.cursor] else nil
end

-- Snipe hit: the piece at sq pops (grows and fades) and is dropped from tracking right away.
function BoardView:popAt(sq: number)
	for id, e in self.models do
		if e.sq == sq then
			self.models[id] = nil
			local model = e.model
			local pivot = model:GetPivot()
			local t0 = os.clock()
			local conn
			conn = RunService.RenderStepped:Connect(function()
				local a = math.clamp((os.clock() - t0) / 0.3, 0, 1)
				if not model.Parent then
					conn:Disconnect()
					return
				end
				model:PivotTo(pivot * CFrame.new(0, a * 0.6, 0) * CFrame.Angles(a * 0.8, 0, a * 0.5))
				for _, p in model:GetDescendants() do
					if p:IsA("BasePart") then
						p.Transparency = a
					end
				end
				if a >= 1 then
					conn:Disconnect()
					model:Destroy()
				end
			end)
			return
		end
	end
end

-- Drag support: move a piece model freely (screen pointer), then sync() puts it where it belongs.
function BoardView:dragTo(sq: number, point: Vector3)
	local e = self:modelAt(sq)
	if e then
		e.dragging = true
		e.model:PivotTo(CFrame.new(point + Vector3.new(0, 0.6, 0)) * self:squareCFrame(sq, e.color).Rotation)
	end
end

return BoardView
