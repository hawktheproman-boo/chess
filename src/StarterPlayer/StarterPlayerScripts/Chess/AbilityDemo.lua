-- Little looping demos of each piece ability on a 5x5 board, for the Shop's detail view: a few
-- pieces, a tap ring where the player would tap, the squares the game would light up, then the
-- ability itself (hop, beam, charge, teleport), with a one-line caption under the board.
-- Squares are named like a real board, a1 bottom-left to e5 top-right (White plays up).
-- Pieces only ever scale (never fade), so it works with both PieceIcons kinds (image / viewport).
--
--   AbilityDemo.new(parent, side, pos) -> demo   (side = the board's width; the caption sits under it)
--   demo:play(abilityId)   loops until demo:stop()
--   demo.frame

local TweenService = game:GetService("TweenService")

local PieceIcons = require(script.Parent.PieceIcons)
local Ui = require(script.Parent.UiKit)
local T = Ui.T

local AbilityDemo = {}
AbilityDemo.__index = AbilityDemo

local N = 5
local CAP_H = 52
local LIGHT = Color3.fromRGB(238, 238, 210) -- (Board2D's squares)
local DARK = Color3.fromRGB(118, 150, 86)
local rgb = Color3.fromRGB
local MARK = {
	dot = { color = T.ink, transparency = 0.55, dot = true }, -- where it can go
	hit = { color = rgb(232, 70, 58), transparency = 0.35 }, -- what it will hit
	own = { color = rgb(255, 200, 61), transparency = 0.35 }, -- your own pieces it can pick
	sel = { color = rgb(246, 246, 105), transparency = 0.25 }, -- the piece you tapped
	check = { color = rgb(255, 40, 40), transparency = 0.2 },
}

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function layer(parent, name, z)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundTransparency = 1
	f.ZIndex = z
	f.Parent = parent
	return f
end

function AbilityDemo.new(parent, side, pos)
	local self = setmetatable({}, AbilityDemo)
	self.sq = math.floor(side / N)
	side = self.sq * N
	local frame = Instance.new("Frame")
	frame.Name = "Demo"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(side, side + 8 + CAP_H)
	frame.Position = pos or UDim2.new()
	frame.Parent = parent
	self.frame = frame

	local edge = Instance.new("Frame")
	edge.Name = "Edge"
	edge.Size = UDim2.fromOffset(side + 10, side + 10)
	edge.Position = UDim2.fromOffset(-5, -5)
	edge.BackgroundColor3 = rgb(52, 92, 40)
	edge.Parent = frame
	Ui.corner(edge, 10)
	Ui.stroke(edge, T.ink, 3)

	local board = Instance.new("Frame")
	board.Name = "Board"
	board.Size = UDim2.fromOffset(side, side)
	board.BackgroundTransparency = 1
	board.ClipsDescendants = true
	board.Parent = frame
	self.board = board
	local squares = layer(board, "Squares", 1)
	for file = 0, N - 1 do
		for rank = 0, N - 1 do
			local s = Instance.new("Frame")
			s.BorderSizePixel = 0
			s.Size = UDim2.fromOffset(self.sq, self.sq)
			s.Position = UDim2.fromOffset(file * self.sq, (N - 1 - rank) * self.sq)
			s.BackgroundColor3 = if (file + rank) % 2 == 0 then DARK else LIGHT
			s.Parent = squares
		end
	end
	self.marks = layer(board, "Marks", 2)
	self.pieceLayer = layer(board, "Pieces", 3)
	self.fx = layer(board, "Fx", 4)

	local cap = Ui.label(frame, "Caption", "", UDim2.new(1, 0, 0, CAP_H), UDim2.new(0, 0, 0, side + 8), Ui.TITLE, 21, T.white, Enum.TextXAlignment.Center)
	cap.BackgroundColor3 = T.ink
	cap.BackgroundTransparency = 0.35
	cap.TextWrapped = true
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
	pad.Parent = cap
	cap.TextTruncate = Enum.TextTruncate.None
	Ui.corner(cap, 12)
	Ui.chunky(cap, 1.5)
	self.caption = cap
	self.capScale = Instance.new("UIScale")
	self.capScale.Parent = cap

	self.pieces = {} -- square name -> { gui, scale }
	return self
end

-- "c3" -> the square's centre, in pixels
function AbilityDemo:at(name: string): UDim2
	local file = string.byte(name) - 97
	local rank = tonumber(string.sub(name, 2)) - 1
	return UDim2.fromOffset((file + 0.5) * self.sq, (N - 1 - rank + 0.5) * self.sq)
end

function AbilityDemo:put(name, kind, color)
	local gui = PieceIcons.new(kind, color or "w")
	gui.AnchorPoint = Vector2.new(0.5, 0.5)
	gui.Size = UDim2.fromOffset(self.sq * 0.9, self.sq * 0.9)
	gui.Position = self:at(name)
	gui.Parent = self.pieceLayer
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	self.pieces[name] = { gui = gui, scale = scale }
end

function AbilityDemo:setup(list)
	for name, p in list do
		self:put(name, p[1], p[2])
	end
end

function AbilityDemo:say(text)
	self.caption.Text = text
	self.capScale.Scale = 0.9
	tween(self.capScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
end

function AbilityDemo:mark(names, kind)
	local m = MARK[kind]
	for _, name in names do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = self:at(name)
		f.BackgroundColor3 = m.color
		f.BackgroundTransparency = 1
		if m.dot then
			f.Size = UDim2.fromOffset(self.sq * 0.32, self.sq * 0.32)
			Ui.corner(f, self.sq)
		else
			f.Size = UDim2.fromOffset(self.sq, self.sq)
		end
		f.Parent = self.marks
		tween(f, 0.15, { BackgroundTransparency = m.transparency })
	end
end

function AbilityDemo:unmark()
	self.marks:ClearAllChildren()
end

-- a white ring closing in on a square: "tap here"
function AbilityDemo:tap(name)
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = self:at(name)
	ring.Size = UDim2.fromOffset(self.sq * 1.5, self.sq * 1.5)
	ring.BackgroundTransparency = 1
	ring.Parent = self.fx
	Ui.corner(ring, self.sq)
	local st = Ui.stroke(ring, T.white, 5)
	tween(ring, 0.3, { Size = UDim2.fromOffset(self.sq * 0.7, self.sq * 0.7) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(0.3)
	tween(st, 0.25, { Transparency = 1 })
	tween(ring, 0.25, { Size = UDim2.fromOffset(self.sq * 0.9, self.sq * 0.9) })
	task.delay(0.3, function()
		ring:Destroy()
	end)
	task.wait(0.2)
end

-- a few bits flying out of a square
function AbilityDemo:burst(name, color)
	local c = self:at(name)
	for i = 1, 6 do
		local a = (i / 6) * math.pi * 2 + math.random() * 0.4
		local bit = Instance.new("Frame")
		bit.AnchorPoint = Vector2.new(0.5, 0.5)
		bit.Size = UDim2.fromOffset(7, 7)
		bit.Position = c
		bit.Rotation = math.random(0, 90)
		bit.BackgroundColor3 = color or T.white
		bit.BorderSizePixel = 0
		bit.Parent = self.fx
		local d = self.sq * 0.6
		tween(bit, 0.35, {
			Position = c + UDim2.fromOffset(math.cos(a) * d, math.sin(a) * d),
			Size = UDim2.fromOffset(2, 2),
			BackgroundTransparency = 1,
		})
		task.delay(0.4, function()
			bit:Destroy()
		end)
	end
end

-- the piece on a square pops and is gone
function AbilityDemo:capture(name)
	local p = self.pieces[name]
	if not p then
		return
	end
	self.pieces[name] = nil
	self:burst(name, rgb(255, 214, 90))
	tween(p.scale, 0.08, { Scale = 1.3 })
	task.delay(0.08, function()
		tween(p.scale, 0.16, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	end)
	task.delay(0.3, function()
		p.gui:Destroy()
	end)
end

-- style: "slide", "hop" (lifts as it goes) or "charge" (speeds up). A piece already on `to` is
-- captured as it lands.
function AbilityDemo:move(from, to, t, style)
	local p = self.pieces[from]
	local victim = self.pieces[to]
	self.pieces[from] = nil
	p.gui.ZIndex = 2
	if style == "charge" then
		tween(p.gui, t, { Position = self:at(to) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	else
		tween(p.gui, t, { Position = self:at(to) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	end
	if style == "hop" then
		tween(p.scale, t / 2, { Scale = 1.3 })
		task.delay(t / 2, function()
			tween(p.scale, t / 2, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end)
	end
	task.wait(t)
	if victim then
		self.pieces[to] = victim
		self:capture(to)
	end
	self.pieces[to] = p
	p.gui.ZIndex = 1
end

-- a piece charges along a line (speeding up), hitting each square in `hits` as it gets there
function AbilityDemo:charge(from, to, hits, t)
	local p = self.pieces[from]
	self.pieces[from] = nil
	local a, b = self:at(from), self:at(to)
	local function dist(u, v)
		return math.sqrt((v.X.Offset - u.X.Offset) ^ 2 + (v.Y.Offset - u.Y.Offset) ^ 2)
	end
	local total = dist(a, b)
	p.gui.ZIndex = 2
	tween(p.gui, t, { Position = b }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local start = os.clock()
	for _, name in hits do
		-- (Quad In covers x of the way at t * sqrt(x); hit a moment before the rook gets there)
		local when = t * math.sqrt(dist(a, self:at(name)) / total) - 0.04
		local left = when - (os.clock() - start)
		if left > 0 then
			task.wait(left)
		end
		self:capture(name)
	end
	local left = t - (os.clock() - start)
	if left > 0 then
		task.wait(left)
	end
	self.pieces[to] = p
	p.gui.ZIndex = 1
end

function AbilityDemo:shake(name)
	local p = self.pieces[name]
	for _, r in { -14, 12, -8, 0 } do
		tween(p.gui, 0.06, { Rotation = r })
		task.wait(0.06)
	end
end

-- a tracer from one square to another, drawn out from the start
function AbilityDemo:beam(from, to, color)
	local a, b = self:at(from), self:at(to)
	local ax, ay, bx, by = a.X.Offset, a.Y.Offset, b.X.Offset, b.Y.Offset
	local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0, 0.5)
	line.BorderSizePixel = 0
	line.BackgroundColor3 = color or rgb(255, 90, 70)
	line.Size = UDim2.fromOffset(0, 8)
	line.Position = a
	line.Rotation = math.deg(math.atan2(by - ay, bx - ax))
	line.Parent = self.fx
	Ui.corner(line, 4)
	-- (rotation turns around the centre: keep the start fixed by moving the centre along)
	local function place(l)
		local cx = ax + (bx - ax) * (l / len) / 2
		local cy = ay + (by - ay) * (l / len) / 2
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromOffset(cx, cy)
		line.Size = UDim2.fromOffset(l, 8)
	end
	local steps = 10
	for i = 1, steps do
		place(len * i / steps)
		task.wait(0.025)
	end
	tween(line, 0.35, { BackgroundTransparency = 1 })
	task.delay(0.4, function()
		line:Destroy()
	end)
end

-- the king fades out (shrinks) and drops in on another square inside a gold ring
function AbilityDemo:teleport(from, to)
	local p = self.pieces[from]
	tween(p.scale, 0.22, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	tween(p.gui, 0.22, { Rotation = 90 })
	task.wait(0.25)
	if self.pieces[to] then
		self:capture(to)
	end
	self.pieces[from] = nil
	self.pieces[to] = p
	p.gui.Position = self:at(to)
	p.gui.Rotation = 0
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = self:at(to)
	ring.Size = UDim2.fromOffset(self.sq * 0.4, self.sq * 0.4)
	ring.BackgroundTransparency = 1
	ring.Parent = self.fx
	Ui.corner(ring, self.sq)
	local st = Ui.stroke(ring, rgb(255, 200, 61), 6)
	tween(ring, 0.4, { Size = UDim2.fromOffset(self.sq * 1.4, self.sq * 1.4) })
	tween(st, 0.4, { Transparency = 1 })
	task.delay(0.45, function()
		ring:Destroy()
	end)
	tween(p.scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	task.wait(0.3)
end

-- The scripts: each sets up its board and plays once (it's looped by play). -------------------------

local SCRIPTS = {}

SCRIPTS.PawnPassant = function(d)
	d:setup({ c3 = { "p", "w" }, e5 = { "n", "b" }, a1 = { "k", "w" }, e1 = { "r", "w" } })
	d:say("An enemy lands right beside your pawn…")
	task.wait(0.9)
	d:move("e5", "d3", 0.45, "hop")
	d:mark({ "d3" }, "hit")
	task.wait(0.6)
	d:say("Tap your pawn")
	d:tap("c3")
	d:mark({ "c3" }, "sel")
	d:mark({ "d4" }, "dot")
	task.wait(0.5)
	d:tap("d4")
	d:unmark()
	d:say("It hops behind it and takes it!")
	d:move("c3", "d4", 0.35, "hop")
	d:capture("d3")
	task.wait(1.4)
end

SCRIPTS.KnightJump = function(d)
	d:setup({ b1 = { "n", "w" }, c3 = { "p", "b" }, d5 = { "b", "b" }, e1 = { "k", "w" }, a5 = { "k", "b" } })
	d:say("Tap your knight")
	task.wait(0.5)
	d:tap("b1")
	d:mark({ "b1" }, "sel")
	d:mark({ "a3", "d2" }, "dot")
	d:mark({ "c3" }, "hit")
	task.wait(0.6)
	d:say("Jump once…")
	d:tap("c3")
	d:unmark()
	d:move("b1", "c3", 0.4, "hop")
	task.wait(0.3)
	d:mark({ "c3" }, "sel")
	d:mark({ "a2", "a4", "b5", "d1", "e2", "e4" }, "dot")
	d:mark({ "d5" }, "hit")
	d:say("…and jump again, the same turn!")
	task.wait(0.7)
	d:tap("d5")
	d:unmark()
	d:move("c3", "d5", 0.4, "hop")
	task.wait(1.4)
end

SCRIPTS.BishopSnipe = function(d)
	d:setup({ a1 = { "b", "w" }, c3 = { "n", "b" }, d4 = { "k", "b" }, e5 = { "r", "b" }, e1 = { "k", "w" }, b4 = { "p", "b" } })
	d:say("Tap your bishop, pick a diagonal")
	task.wait(0.5)
	d:tap("a1")
	d:mark({ "a1" }, "sel")
	d:mark({ "b2", "c3", "d4", "e5" }, "hit")
	task.wait(0.7)
	d:tap("e5")
	d:unmark()
	d:say("Every enemy on it is wiped out!")
	d:beam("a1", "e5")
	d:capture("c3")
	task.wait(0.12)
	d:shake("d4")
	d:capture("e5")
	task.wait(0.5)
	d:say("(the king is skipped)")
	task.wait(1.4)
end

SCRIPTS.RookRam = function(d)
	d:setup({ a1 = { "r", "w" }, a3 = { "n", "b" }, a4 = { "b", "b" }, a5 = { "p", "w" }, e1 = { "k", "w" }, d5 = { "k", "b" } })
	d:say("Tap your rook, pick a direction")
	task.wait(0.5)
	d:tap("a1")
	d:mark({ "a1" }, "sel")
	d:mark({ "a2", "a3", "a4" }, "hit")
	task.wait(0.7)
	d:tap("a4")
	d:unmark()
	d:say("CHARGE! It smashes everything in its path")
	d:charge("a1", "a4", { "a3", "a4" }, 0.45)
	task.wait(0.4)
	d:say("…and stops at your own piece")
	task.wait(1.4)
end

SCRIPTS.KingEscape = function(d)
	d:setup({ c2 = { "k", "w" }, c5 = { "r", "b" }, e3 = { "p", "b" }, a5 = { "k", "b" } })
	d:mark({ "c2" }, "check")
	d:say("Check! Tap your king")
	task.wait(0.8)
	d:tap("c2")
	d:mark({ "a1", "a2", "a3", "a4", "b1", "b2", "b3", "b4", "d1", "d2", "d3", "d4", "e1", "e2", "e4" }, "dot")
	d:mark({ "e3" }, "hit")
	d:say("It can teleport up to 2 squares")
	task.wait(0.8)
	d:tap("e3")
	d:unmark()
	d:say("Escaped, and took a pawn!")
	d:teleport("c2", "e3")
	task.wait(1.4)
end

function AbilityDemo:reset()
	self.marks:ClearAllChildren()
	self.pieceLayer:ClearAllChildren()
	self.fx:ClearAllChildren()
	self.pieces = {}
	self.caption.Text = ""
end

function AbilityDemo:play(id)
	self:stop()
	local run = SCRIPTS[id]
	if not run then
		return
	end
	self.thread = task.spawn(function()
		while true do
			self:reset()
			run(self)
		end
	end)
end

function AbilityDemo:stop()
	if self.thread then
		pcall(task.cancel, self.thread)
		self.thread = nil
	end
	self:reset()
end

return AbilityDemo
