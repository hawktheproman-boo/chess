-- The flat 2D board (a GUI over the screen), styled like a classic online board: cream and green
-- squares, coordinates in the corners, flat outlined pieces. It mirrors BoardView's API so the
-- client can drive either: sync(game, animate), setMarks(marks), dragTo(sq, x, y), squareAt(x, y).
-- Input: one invisible button over the board reports presses as squares (mouse and touch).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local PieceIcons = require(script.Parent.PieceIcons)
local Ui = require(script.Parent.UiKit)

local Board2D = {}
Board2D.__index = Board2D

local LIGHT = Color3.fromRGB(238, 238, 210)
local DARK = Color3.fromRGB(118, 150, 86)
local HIGHLIGHT = Color3.fromRGB(246, 246, 105)
local FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)

-- opts.parent: draw inside this frame (e.g. the review screen) instead of a full-screen GUI of its own
function Board2D.new(onDown, opts)
	opts = opts or {}
	local self = setmetatable({}, Board2D)
	self.color = "w"
	self.models = {} -- piece id -> { frame, sq, type, color }
	self.markFrames = {}
	self.light, self.dark = LIGHT, DARK

	local gui
	if opts.parent then
		gui = opts.parent
		self.embedded = true
	else
		gui = Instance.new("ScreenGui")
		gui.Name = "ChessBoard2D"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 1 -- under the HUD (dialogs stay on top)
		gui.Enabled = false
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
	self.gui = gui

	-- soft backdrop so the board reads as a clean 2D screen
	local backdrop = Instance.new("Frame")
	backdrop.Visible = not self.embedded
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Position = UDim2.fromOffset(0, -100)
	backdrop.Size = UDim2.new(1, 0, 1, 200)
	backdrop.BackgroundColor3 = Color3.fromRGB(222, 234, 212)
	backdrop.BackgroundTransparency = 0.08
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	local holder = Instance.new("Frame")
	holder.Name = "Board"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.BackgroundColor3 = Color3.fromRGB(52, 92, 40)
	holder.BorderSizePixel = 0
	holder.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = holder
	self.holder = holder

	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.Size = UDim2.new(1, -12, 1, -12)
	inner.Position = UDim2.fromOffset(6, 6)
	inner.BackgroundTransparency = 1
	inner.ClipsDescendants = true
	inner.Parent = holder
	self.inner = inner

	self.squares = {}
	for rank = 0, 7 do
		for file = 0, 7 do
			local sq = rank * 16 + file
			local f = Instance.new("Frame")
			f.Name = tostring(sq)
			f.Size = UDim2.fromScale(1 / 8, 1 / 8)
			f.BorderSizePixel = 0
			f.BackgroundColor3 = if (file + rank) % 2 == 1 then LIGHT else DARK
			f.Parent = inner
			self.squares[sq] = f
		end
	end
	-- layers above the squares
	local function layer(name, z)
		local l = Instance.new("Frame")
		l.Name = name
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.ZIndex = z
		l.Parent = inner
		return l
	end
	self.coordLayer = layer("Coords", 2)
	self.markLayer = layer("Marks", 3)
	self.pieceLayer = layer("Pieces", 4)
	self.topLayer = layer("Top", 6)

	self.cursor = Instance.new("Frame")
	self.cursor.Name = "Cursor"
	self.cursor.BackgroundTransparency = 1
	self.cursor.Size = UDim2.fromScale(1 / 8, 1 / 8)
	self.cursor.Visible = false
	self.cursor.Parent = self.topLayer
	local cs = Instance.new("UIStroke")
	cs.Color = Color3.fromRGB(255, 255, 255)
	cs.Thickness = 4
	cs.Parent = self.cursor

	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 10
	hit.Selectable = false
	hit.AutoButtonColor = false
	hit.Parent = inner
	hit.MouseButton1Down:Connect(function(x, y)
		-- these x/y include the GUI inset; AbsolutePosition (and InputObject.Position) don't. On a
		-- phone with a notch the inset has a left part too (about a square wide on a small board).
		local inset = GuiService:GetGuiInset()
		x -= inset.X
		y -= inset.Y
		onDown(self:squareAt(x, y), x, y)
	end)

	if self.embedded then
		holder.Size = UDim2.fromScale(1, 1)
		self:setOrientation("w")
		return self
	end
	local cam = workspace.CurrentCamera
	local function layout()
		-- keep clear of the HUD (the same layout as the HUD; on phones the board takes the full
		-- height and the player bars sit beside it)
		local layout = Ui.seatLayout(cam.ViewportSize, GuiService:GetGuiInset().Y, self.strip)
		holder.Size = UDim2.fromOffset(layout.board, layout.board)
		holder.Position = UDim2.new(0.5, 0, 0.5, -layout.shift)
	end
	self.layout = layout
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	layout()
	self:setOrientation("w")
	return self
end

-- Abilities games on wide screens leave a strip at the bottom for the ability panel
function Board2D:setStrip(on: boolean)
	if self.strip ~= on then
		self.strip = on
		if self.layout then
			self.layout()
		end
	end
end

-- display row/column of a square for the current orientation (own side at the bottom)
function Board2D:cell(sq)
	local file, rank = sq % 16, sq // 16
	if self.color == "b" then
		return 7 - file, rank
	end
	return file, 7 - rank
end

function Board2D:cellPosition(sq)
	local col, row = self:cell(sq)
	return UDim2.fromScale(col / 8, row / 8)
end

function Board2D:setOrientation(color)
	self.color = color
	for sq, f in self.squares do
		f.Position = self:cellPosition(sq)
	end
	-- coordinates: rank numbers down the left column, file letters along the bottom row
	self.coordLayer:ClearAllChildren()
	for sq, f in self.squares do
		local col, row = self:cell(sq)
		local file, rank = sq % 16, sq // 16
		local onLight = (file + rank) % 2 == 1
		local function coord(text, anchor, pos)
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Text = text
			l.FontFace = FONT
			l.TextScaled = true
			l.TextColor3 = if onLight then self.dark else self.light
			l.Size = UDim2.fromScale(0.026, 0.03)
			l.AnchorPoint = anchor
			l.Position = pos
			l.Parent = self.coordLayer
		end
		if col == 0 then
			coord(tostring(rank + 1), Vector2.new(0, 0), UDim2.fromScale(col / 8 + 0.005, row / 8 + 0.004))
		end
		if row == 7 then
			coord(string.char(97 + file), Vector2.new(1, 1), UDim2.fromScale((col + 1) / 8 - 0.005, 1 - 0.003))
		end
	end
	for _, e in self.models do
		e.frame.Position = self:cellPosition(e.sq)
	end
end

-- a board theme (Shared/Themes): squares, border and coordinates
function Board2D:setTheme(theme)
	self.light, self.dark = theme.light, theme.dark
	self.holder.BackgroundColor3 = theme.frame2D
	for sq, f in self.squares do
		f.BackgroundColor3 = if (sq % 16 + sq // 16) % 2 == 1 then self.light else self.dark
	end
	self:setOrientation(self.color)
end

function Board2D:setVisible(on)
	if self.embedded then
		self.holder.Visible = on
		return
	end
	self.gui.Enabled = on
end

-- screen point -> square (or nil)
function Board2D:squareAt(x, y)
	local pos, size = self.inner.AbsolutePosition, self.inner.AbsoluteSize
	local col = math.floor((x - pos.X) / size.X * 8)
	local row = math.floor((y - pos.Y) / size.Y * 8)
	if col < 0 or col > 7 or row < 0 or row > 7 then
		return nil
	end
	local file, rank
	if self.color == "b" then
		file, rank = 7 - col, row
	else
		file, rank = col, 7 - row
	end
	return rank * 16 + file
end

local function newPiece(self, piece)
	local f = PieceIcons.new(piece.type, piece.color)
	f.Size = UDim2.fromScale(1 / 8, 1 / 8)
	f.ZIndex = 4
	f.Parent = self.pieceLayer
	return f
end

function Board2D:sync(game, animate)
	local seen = {}
	for sq, piece in game.board.sq do
		seen[piece.id] = true
		local e = self.models[piece.id]
		if not e then
			e = { frame = newPiece(self, piece), type = piece.type, color = piece.color, sq = sq }
			self.models[piece.id] = e
			e.frame.Position = self:cellPosition(sq)
		elseif e.type ~= piece.type or e.color ~= piece.color then
			e.frame:Destroy()
			e.frame = newPiece(self, piece)
			e.type, e.color, e.sq = piece.type, piece.color, sq
			e.frame.Position = self:cellPosition(sq)
		elseif e.sq ~= sq or e.dragging then
			local dragged = e.dragging
			e.dragging = nil
			e.sq = sq
			e.frame.ZIndex = 4
			e.frame.Size = UDim2.fromScale(1 / 8, 1 / 8)
			if animate and not dragged then
				e.frame.ZIndex = 5
				TweenService:Create(e.frame, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Position = self:cellPosition(sq) }):Play()
			else
				e.frame.Position = self:cellPosition(sq)
			end
		end
	end
	for id, e in self.models do
		if not seen[id] then
			self.models[id] = nil
			e.frame:Destroy()
		end
	end
end

function Board2D:clearPieces()
	for id, e in self.models do
		e.frame:Destroy()
		self.models[id] = nil
	end
end

function Board2D:dragTo(sq, x, y)
	for _, e in self.models do
		if e.sq == sq then
			e.dragging = true
			local pos, size = self.inner.AbsolutePosition, self.inner.AbsoluteSize
			e.frame.ZIndex = 8
			e.frame.Size = UDim2.fromScale(1.15 / 8, 1.15 / 8)
			e.frame.Position = UDim2.fromScale((x - pos.X) / size.X - 1.15 / 16, (y - pos.Y) / size.Y - 1.15 / 16)
			return
		end
	end
end

local function tint(parent, pos, color, transparency)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1 / 8, 1 / 8)
	f.Position = pos
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.Parent = parent
	return f
end

-- marks = { lastFrom, lastTo, check, selected, targets = { [sq] = "move"|"capture" }, cursor }
function Board2D:setMarks(marks)
	self.markLayer:ClearAllChildren()
	for _, sq in marks.tints or {} do
		tint(self.markLayer, self:cellPosition(sq), HIGHLIGHT, 0.3)
	end
	for _, sq in { marks.lastFrom, marks.lastTo, marks.selected } do
		if sq then
			tint(self.markLayer, self:cellPosition(sq), HIGHLIGHT, 0.45)
		end
	end
	if marks.check then
		local f = tint(self.markLayer, self:cellPosition(marks.check), Color3.fromRGB(235, 70, 60), 0.35)
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.9) })
		g.Parent = f
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = f
	end
	for sq, kind in marks.targets or {} do
		local cell = tint(self.markLayer, self:cellPosition(sq), Color3.new(0, 0, 0), 1)
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(0.5, 0.5)
		dot.BorderSizePixel = 0
		dot.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = dot
		if kind == "swap" then -- (Swap: one of your own pieces) a purple ring
			dot.Size = UDim2.fromScale(0.86, 0.86)
			dot.BackgroundTransparency = 1
			local ring = Instance.new("UIStroke")
			ring.Thickness = math.max(3, self.inner.AbsoluteSize.X / 8 * 0.09)
			ring.Color = Color3.fromRGB(150, 70, 240)
			ring.Transparency = 0.2
			ring.Parent = dot
		elseif kind == "capture" then
			dot.Size = UDim2.fromScale(0.86, 0.86)
			dot.BackgroundTransparency = 1
			local ring = Instance.new("UIStroke")
			ring.Thickness = math.max(3, self.inner.AbsoluteSize.X / 8 * 0.09)
			ring.Color = Color3.fromRGB(0, 0, 0)
			ring.Transparency = 0.78
			ring.Parent = dot
		else
			dot.Size = UDim2.fromScale(0.32, 0.32)
			dot.BackgroundTransparency = 0.8
		end
		dot.Parent = cell
	end
	if marks.cursor then
		self.cursor.Visible = true
		self.cursor.Position = self:cellPosition(marks.cursor)
	else
		self.cursor.Visible = false
	end
end

return Board2D
