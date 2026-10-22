-- The game review screen: a 2D board you can step through, an eval bar, each side's accuracy and
-- move grades, a move list with coloured grade badges, "best was …" feedback, and the PGN to copy.
-- The bot analyses the game in the background while you browse (Shared/Bot/Review).
-- Abilities games get their own review instead of a PGN (other chess programs can't replay them):
-- ability moves are labelled and highlighted, a snipe shows its line and the pieces it took, the
-- feedback counts the material an ability won or flags a missed one, each side's ability use is
-- summed up, and "Next key moment" jumps between abilities, mistakes and blunders.
--
--   local panel = ReviewPanel.new()
--   panel:open({ startFen, modeName, mode = modeModule?, actions, white, black, result, clock, myColor })

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Game = require(Shared.Chess.Game)
local Pgn = require(Shared.Chess.Pgn)
local Review = require(Shared.Bot.Review)
local Search = require(Shared.Bot.Search)
local Snipe = require(Shared.Abilities.BishopSnipe)
local RookRam = require(Shared.Abilities.RookRam)
local Board2D = require(script.Parent.Board2D)
local Sounds = require(script.Parent.Sounds)
local Ui = require(script.Parent.UiKit)

local T, HEAVY, BOLD, MEDIUM = Ui.T, Ui.HEAVY, Ui.BOLD, Ui.MEDIUM
local corner, stroke, card, label, button, list = Ui.corner, Ui.stroke, Ui.card, Ui.label, Ui.button, Ui.list
local I, setText = Ui.ICONS, Ui.setText

local ReviewPanel = {}
ReviewPanel.__index = ReviewPanel

local NAV_ACTION = "ChessReviewNav"
local RunService = game:GetService("RunService")
-- the grade chips, in order (excellent counts with good; forced moves aren't shown)
local CHIP_ORDER = { "brilliant", "great", "best", "good", "inaccuracy", "mistake", "blunder" }

-- a short move-list label for an ability move: "Bc1 snipe NE x3+" -> "Bc1 Snipe ×3+",
-- "Ra1 ram a6 x2" -> "Ra1 Ram ×2", "Nb1 jump c3 xd5" -> "Nb1 Jump c3 xd5", ...
local function shortLabel(san)
	san = string.gsub(san or "", " snipe %u+ x(%d+)", " Snipe ×%1")
	san = string.gsub(san, " ram %w+ x(%d+)", " Ram ×%1")
	san = string.gsub(san, " jump ", " Jump ")
	san = string.gsub(san, " swap ", " Swap ")
	san = string.gsub(san, " escape ", " Escape ")
	san = string.gsub(san, " passant ", " Passant ")
	return san
end

-- the sound for an ability, by id (review stepping)
local ABILITY_SOUND = { BishopSnipe = "snipe", KnightJump = "land", RookRam = "crash", QueenSwap = "magic", KingEscape = "teleport", PawnPassant = "land" }

local function evalText(cp, mate)
	if mate then
		return if mate == 0 then "#" elseif mate > 0 then "M" .. mate else "-M" .. -mate
	end
	return string.format("%+.1f", cp / 100)
end

function ReviewPanel.new()
	local self = setmetatable({}, ReviewPanel)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ChessReview"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 25
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = T.panelDeep
	backdrop.BorderSizePixel = 0
	backdrop.Active = true -- swallows clicks so the 3D board underneath never gets them
	backdrop.Parent = gui

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(1040, 620)
	root.BackgroundTransparency = 1
	root.Parent = backdrop
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local cam = workspace.CurrentCamera
	local function rescale()
		local v = cam.ViewportSize
		scale.Scale = math.clamp(math.min(v.X / 1090, v.Y / 660), 0.35, 1.25)
	end
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	-- players above and below the board
	self.topName = label(root, "TopName", "", UDim2.fromOffset(560, 26), UDim2.fromOffset(36, 0), HEAVY, 20, T.text)
	self.bottomName = label(root, "BottomName", "", UDim2.fromOffset(560, 26), UDim2.fromOffset(36, 594), HEAVY, 20, T.text)

	-- eval bar: White's share from the bottom
	local bar = Instance.new("Frame")
	bar.Name = "EvalBar"
	bar.Size = UDim2.fromOffset(24, 560)
	bar.Position = UDim2.fromOffset(0, 30)
	bar.BackgroundColor3 = Color3.fromRGB(64, 64, 64)
	bar.BorderSizePixel = 0
	bar.ClipsDescendants = true
	bar.Parent = root
	corner(bar, 6)
	local fill = Instance.new("Frame")
	fill.Name = "White"
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)
	fill.Size = UDim2.fromScale(1, 0.5)
	fill.BackgroundColor3 = Color3.fromRGB(245, 245, 240)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	self.evalFill, self.evalBar = fill, bar
	self.evalLabel = label(bar, "Value", "", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 1, -20), BOLD, 11, T.text, Enum.TextXAlignment.Center)
	self.evalLabel.ZIndex = 3
	self.evalSkel = nil -- (made below, once the shimmer helpers exist on self)
	self.evalBarFrame = bar

	local boardArea = Instance.new("Frame")
	boardArea.Name = "BoardArea"
	boardArea.Size = UDim2.fromOffset(560, 560)
	boardArea.Position = UDim2.fromOffset(36, 30)
	boardArea.BackgroundTransparency = 1
	boardArea.Parent = root
	self.board = Board2D.new(function() end, { parent = boardArea })
	self.badge = nil

	-- right panel (kept short: accuracy, your grades as chips, one feedback card, the moves) ---------
	local holder, body = card(root, "Panel", UDim2.fromOffset(424, 620), UDim2.fromOffset(616, 0))
	local head = Ui.header(body, "Review", 50, 26)
	Ui.closeX(body, function()
		self:close()
	end)
	self.panel = body
	self.title = head
	self.shimmers, self.pulses = {}, {}
	self.evalSkel = self:skeleton(self.evalBarFrame, UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(96, 98, 96))

	-- accuracy cards (a shimmering bar until the analysis is done)
	self.acc = {}
	for i, color in { "w", "b" } do
		local box = Instance.new("Frame")
		box.Name = "Acc" .. color
		box.Size = UDim2.fromOffset(188, 70)
		box.Position = UDim2.fromOffset(if i == 1 then 16 else 220, 62)
		box.BackgroundColor3 = if color == "w" then Color3.fromRGB(250, 250, 246) else Color3.fromRGB(40, 44, 40)
		box.BorderSizePixel = 0
		box.Parent = body
		corner(box, 12)
		stroke(box, T.ink, 2.5)
		local fg = if color == "w" then T.ink else T.white
		local name = label(box, "Name", "", UDim2.new(1, -16, 0, 20), UDim2.fromOffset(10, 6), BOLD, 15, fg)
		local value = label(box, "Value", "", UDim2.new(1, -16, 0, 36), UDim2.fromOffset(10, 28), Ui.TITLE, 32, fg)
		local skel = self:skeleton(box, UDim2.fromOffset(110, 26), UDim2.fromOffset(10, 34),
			if color == "w" then Color3.fromRGB(218, 222, 212) else Color3.fromRGB(70, 76, 70))
		self.acc[color] = { name = name, value = value, skel = skel }
	end

	-- your grades: one chip per grade (symbol badge + count); the feedback card names them
	label(body, "YourMoves", "Your moves", UDim2.fromOffset(392, 18), UDim2.fromOffset(16, 140), BOLD, 14, T.muted)
	local chips = Instance.new("Frame")
	chips.Name = "Chips"
	chips.BackgroundTransparency = 1
	chips.Size = UDim2.fromOffset(392, 56)
	chips.Position = UDim2.fromOffset(16, 160)
	chips.Parent = body
	list(chips, 6, true)
	self.chips = {}
	for i, id in CHIP_ORDER do
		local c = Review.CLASS[id]
		local chip = Instance.new("Frame")
		chip.Name = id
		chip.LayoutOrder = i
		chip.Size = UDim2.fromOffset(51, 56)
		chip.BackgroundColor3 = T.panelDeep
		chip.BorderSizePixel = 0
		chip.Parent = chips
		corner(chip, 10)
		local dot = label(chip, "Dot", c.symbol, UDim2.fromOffset(26, 26), UDim2.new(0.5, -13, 0, 4), HEAVY, 13, T.white, Enum.TextXAlignment.Center)
		dot.BackgroundColor3 = c.color
		dot.BackgroundTransparency = 0
		corner(dot, 13)
		local count = label(chip, "Count", "", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 31), Ui.TITLE, 19, T.text, Enum.TextXAlignment.Center)
		local skel = self:skeleton(chip, UDim2.fromOffset(22, 14), UDim2.new(0.5, -11, 0, 36))
		self.chips[id] = { chip = chip, count = count, skel = skel }
	end
	-- Abilities games: abilities used / missed (yours)
	self.abilityLine = label(body, "Abilities", "", UDim2.fromOffset(392, 18), UDim2.fromOffset(16, 220), BOLD, 14, Color3.fromRGB(255, 140, 130))
	self.abilityLine.Visible = false

	-- feedback card: a big grade badge and one or two lines about the selected move
	local fb = Instance.new("Frame")
	fb.Name = "Feedback"
	fb.Size = UDim2.fromOffset(392, 92)
	fb.Position = UDim2.fromOffset(16, 242)
	fb.BackgroundColor3 = T.panelLift
	fb.BorderSizePixel = 0
	fb.Parent = body
	corner(fb, 12)
	stroke(fb, T.ink, 2)
	self.feedbackBox = fb
	local badge = label(fb, "Badge", "", UDim2.fromOffset(52, 52), UDim2.fromOffset(12, 20), HEAVY, 22, T.white, Enum.TextXAlignment.Center)
	badge.BackgroundColor3 = T.panelDeep
	badge.BackgroundTransparency = 0
	corner(badge, 26)
	stroke(badge, T.ink, 2.5)
	Ui.chunky(badge, 1.5)
	self.fbBadge = badge
	self.feedback = label(fb, "Text", "", UDim2.new(1, -86, 1, -16), UDim2.fromOffset(76, 8), BOLD, 16, T.text)
	self.feedback.TextWrapped = true
	self.feedback.RichText = true
	self.feedback.TextTruncate = Enum.TextTruncate.None
	self.feedback.TextYAlignment = Enum.TextYAlignment.Center
	-- skeleton for a move that hasn't been analysed yet: a grey badge and two shimmering lines
	self.fbSkel = {
		self:skeleton(fb, UDim2.fromOffset(240, 14), UDim2.fromOffset(76, 30)),
		self:skeleton(fb, UDim2.fromOffset(160, 14), UDim2.fromOffset(76, 52)),
	}
	-- on a mistake or blunder: play the best move on the board instead (press again to go back)
	local bestH, bestB = button(fb, "ShowBest", "Best move", UDim2.fromOffset(124, 38), "primary", function()
		self:toggleBest()
	end, I.best)
	bestH.AnchorPoint = Vector2.new(1, 1)
	bestH.Position = UDim2.new(1, -8, 1, -8)
	bestB.TextSize = 15
	bestH.Visible = false
	self.bestHolder, self.bestButton = bestH, bestB

	-- move list
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Moves"
	scroll.Size = UDim2.fromOffset(392, 214)
	scroll.Position = UDim2.fromOffset(16, 344)
	scroll.BackgroundColor3 = T.panelDeep
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = body
	corner(scroll, 10)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -4, 0, 26)
	grid.CellPadding = UDim2.fromOffset(4, 2)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingTop, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6), UDim.new(0, 10)
	pad.Parent = scroll
	self.moveScroll = scroll

	-- navigation, plus one action tile (PGN in Classic, Key moment in Abilities)
	local nav = Instance.new("Frame")
	nav.Name = "Nav"
	nav.BackgroundTransparency = 1
	nav.Size = UDim2.fromOffset(392, 48)
	nav.Position = UDim2.fromOffset(16, 566)
	nav.Parent = body
	list(nav, 6, true)
	for i, b in { { "First", "|◀", function() self:go(0) end }, { "Prev", "◀", function() self:go(self.ply - 1) end },
		{ "Next", "▶", function() self:go(self.ply + 1) end }, { "Last", "▶|", function() self:go(#self.record.actions) end } } do
		local h, face = button(nav, b[1], b[2], UDim2.fromOffset(72, 46), if i == 3 then "primary" else "secondary", b[3])
		h.LayoutOrder = i
		face.TextSize = 20
		if i == 3 then
			self.nextButton = face
		end
	end
	local h1 = Ui.tile(nav, "Pgn", I.copy, "PGN", UDim2.fromOffset(80, 46), "blue", function() self:showPgn(true) end)
	h1.LayoutOrder = 5
	h1.Face.Icon.TextSize = 20
	self.pgnHolder = h1
	local hk = Ui.tile(nav, "KeyMoment", I.key, "Key", UDim2.fromOffset(80, 46), "gold", function() self:nextKeyMoment() end)
	hk.LayoutOrder = 5
	hk.Face.Icon.TextSize = 20
	hk.Visible = false
	self.keyHolder = hk

	-- PGN sheet (over the panel): the text in a box, and a Copy button that selects all of it.
	-- Roblox games can't write to the clipboard, so the player presses Ctrl+C (or Copy on a phone).
	local pgnHolder, pgnBody = card(body, "PgnSheet", UDim2.new(1, -24, 1, -62), UDim2.fromOffset(12, 56))
	pgnHolder.ZIndex = 10
	local copyHint = label(pgnBody, "Hint", "", UDim2.new(1, -24, 0, 26), UDim2.new(0, 12, 1, -88), HEAVY, 16, T.greenDeep, Enum.TextXAlignment.Center)
	copyHint.Visible = false
	self.copyHint = copyHint
	local box = Instance.new("TextBox")
	box.Name = "Text"
	box.MultiLine = true
	box.ClearTextOnFocus = false
	box.TextEditable = true -- edits are undone below; keeping it editable keeps select-all + copy working everywhere
	box.TextWrapped = true
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Top
	box.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json")
	box.TextSize = 13
	box.TextColor3 = T.text
	box.BackgroundColor3 = T.panelDeep
	box.Size = UDim2.new(1, -24, 1, -104)
	box.Position = UDim2.fromOffset(12, 12)
	box.Parent = pgnBody
	corner(box, 8)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if self.pgnText and box.Text ~= self.pgnText then
			box.Text = self.pgnText
		end
	end)
	self.pgnBox = box
	local copyH = button(pgnBody, "Copy", "Copy", UDim2.new(0.5, -18, 0, 44), "primary", function() self:copyPgn() end, I.copy)
	copyH.Position = UDim2.new(0, 12, 1, -56)
	local backH = button(pgnBody, "Back", "Back", UDim2.new(0.5, -18, 0, 44), "secondary", function() self:showPgn(false) end, I.back)
	backH.AnchorPoint = Vector2.new(1, 0)
	backH.Position = UDim2.new(1, -12, 1, -56)
	self.pgnSheet = pgnHolder
	pgnHolder.Visible = false

	return self
end

-- record: { startFen, modeName, mode, actions, white, black, result, clock, myColor }
function ReviewPanel:open(record)
	self:close()
	self.record = record
	self.entries = {}
	self.abilityInfo = {}
	self.token = (self.token or 0) + 1
	-- Abilities games: no PGN (it couldn't be replayed elsewhere); the custom review parts instead
	self.abilities = record.modeName == "Abilities"
	setText(self.title, if self.abilities then "Review  ·  Abilities" else "Review", I.review)
	self.pgnHolder.Visible = not self.abilities
	self.keyHolder.Visible = self.abilities
	self.abilityLine.Visible = self.abilities
	local flip = record.myColor == "b"
	self.board:setOrientation(if flip then "b" else "w")
	self.topName.Text = if flip then record.white else record.black
	self.bottomName.Text = if flip then record.black else record.white
	self.acc.w.name.Text = record.white
	self.acc.b.name.Text = record.black

	-- replay once for the SANs and the PGN
	local g = Game.forReplay(record.startFen, record.mode, record.actions)
	for _, a in record.actions do
		if not g:apply(a) then
			break
		end
	end
	self.sans = {}
	for i, h in g.history do
		self.sans[i] = h.san
	end
	if self.abilities then
		self.pgnText = nil
	else
		self.pgnText = Pgn.build({ startFen = record.startFen, moves = Pgn.movesFrom(g), mode = record.modeName,
			white = record.white, black = record.black, result = record.result, clock = record.clock })
	end
	self.pgnBox.Text = self.pgnText or ""
	self:buildMoveList()
	self:refreshCounts()
	self.board:clearPieces()
	self.ply = -1
	self.analysing = true
	self.userNavigated = false
	self:go(0, true) -- the start position while it analyses; move 1 once the analysis is done
	self.gui.Enabled = true
	self:startShimmer()
	self:bindInput(true)
	self:startAnalysis()
end

function ReviewPanel:close()
	self.token = (self.token or 0) + 1 -- stops a running analysis
	self.gui.Enabled = false
	self:stopShimmer()
	self:showPgn(false)
	self:bindInput(false)
end

-- a short note across the top ("Saved to Stats")
function ReviewPanel:toast(text)
	local l = self.toastLabel
	if not l then
		l = label(self.gui, "Toast", "", UDim2.fromOffset(300, 40), UDim2.new(0.5, 0, 0, 16), Ui.TITLE, 20, T.white, Enum.TextXAlignment.Center)
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.BackgroundColor3 = T.green
		l.BackgroundTransparency = 0
		l.ZIndex = 20
		Ui.corner(l, 20)
		Ui.stroke(l, T.ink, 2.5)
		Ui.chunky(l, 1.5)
		self.toastLabel = l
	end
	self.toastToken = (self.toastToken or 0) + 1
	local token = self.toastToken
	setText(l, text, Ui.ICONS.save)
	l.Visible = true
	task.delay(2.5, function()
		if self.toastToken == token then
			l.Visible = false
		end
	end)
end

function ReviewPanel:isOpen()
	return self.gui.Enabled
end

function ReviewPanel:showPgn(on)
	if self.abilities then
		on = false -- no PGN for Abilities games
	end
	self.pgnSheet.Visible = on
	self.copyHint.Visible = false
	if on then
		self.pgnBox.Text = self.pgnText or ""
	end
end

-- Copy: focus the PGN box and select all of it; the player finishes with Ctrl+C / Copy
function ReviewPanel:copyPgn()
	local box = self.pgnBox
	box:CaptureFocus()
	box.CursorPosition = #box.Text + 1
	box.SelectionStart = 1
	local phone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	setText(self.copyHint, if phone then "Selected! Now tap Copy" else "Selected! Now press Ctrl+C", I.yes)
	self.copyHint.Visible = true
end

function ReviewPanel:startAnalysis()
	local token = self.token
	local total = #self.record.actions
	self.status = "Analysing… 0/" .. total
	self:refreshFeedback()
	task.spawn(function()
		local _, summary = Review.analyse({ startFen = self.record.startFen, mode = self.record.mode, actions = self.record.actions }, {
			budget = 0.15, -- thinking time per position (waiting between frames doesn't count)
			slice = 0.006, -- at most ~6 ms of analysis per frame, so the review stays smooth
			depth = 5,
			yield = function()
				task.wait()
			end,
			cancelled = function()
				return self.token ~= token
			end,
			onPly = function(i, entry)
				if self.token ~= token then
					return
				end
				self.entries[i] = entry
				self:updateMoveButton(i)
				self.status = string.format("Analysing… %d/%d", i, total)
				self:refreshCounts()
				if i == self.ply or i == self.ply + 1 then
					self:refreshFeedback()
					self:refreshEval()
				end
			end,
		})
		if self.token == token then
			self.status = nil
			self.analysing = false
			self.summary = summary
			if not self.userNavigated and #self.record.actions > 0 then
				self:go(1, true) -- start the walkthrough at the first move (unless you've already moved on)
			end
			self:refreshCounts()
			self:refreshFeedback()
			if self.onAnalysed then
				task.spawn(self.onAnalysed, self.record, summary)
			end
		end
	end)
end

function ReviewPanel:buildMoveList()
	for _, c in self.moveScroll:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	self.moveButtons = {}
	local fields = string.split(self.record.startFen or "", " ")
	local turn = fields[2] or "w"
	local number = tonumber(fields[6]) or 1
	local order = 0
	if turn == "b" then
		-- Black moves first: an empty White cell keeps the columns lined up
		order += 1
		local spacer = Instance.new("Frame")
		spacer.BackgroundTransparency = 1
		spacer.LayoutOrder = order
		spacer.Parent = self.moveScroll
	end
	for i, san in self.sans do
		order += 1
		local b = Instance.new("TextButton")
		b.Name = "Move" .. i
		b.LayoutOrder = order
		local isAbility = self.record.actions[i] and self.record.actions[i].kind == "ability"
		b.Text = (if turn == "w" then number .. ". " else "") .. (if isAbility then "✦ " .. shortLabel(san) else san)
		b.FontFace = BOLD
		b.TextSize = 15
		b.TextColor3 = if isAbility then Color3.fromRGB(255, 120, 110) else T.text
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.TextTruncate = Enum.TextTruncate.AtEnd
		b.BackgroundColor3 = T.white
		b.BackgroundTransparency = 1
		b.AutoButtonColor = true
		b.Parent = self.moveScroll
		corner(b, 6)
		local p = Instance.new("UIPadding")
		p.PaddingLeft = UDim.new(0, 26)
		p.Parent = b
		local dot = label(b, "Grade", "", UDim2.fromOffset(20, 20), UDim2.new(0, -23, 0.5, -10), HEAVY, 11, T.white, Enum.TextXAlignment.Center)
		dot.BackgroundColor3 = T.panelLift
		dot.BackgroundTransparency = 0
		corner(dot, 10)
		self.pulses[dot] = true -- pulses (skeleton) until this move is graded
		b.Activated:Connect(function()
			self:go(i)
		end)
		self.moveButtons[i] = { button = b, dot = dot }
		if turn == "b" then
			number += 1
		end
		turn = if turn == "w" then "b" else "w"
	end
end

function ReviewPanel:updateMoveButton(i)
	local mb, e = self.moveButtons[i], self.entries[i]
	if mb and e then
		local c = Review.CLASS[e.class]
		self.pulses[mb.dot] = nil
		mb.dot.BackgroundTransparency = 0
		mb.dot.BackgroundColor3 = c.color
		mb.dot.Text = c.symbol
	end
end

function ReviewPanel:refreshCounts()
	local summary = Review.summary(self.entries)
	local me = self.record.myColor or "w"
	local mine = summary[me]
	for id, chip in self.chips do
		local n = mine.counts[id] or 0
		if id == "good" then
			n += mine.counts.excellent or 0
		end
		chip.count.Text = tostring(n)
		-- the counts stay skeletons until the whole game is analysed (they'd jump around otherwise)
		chip.count.Visible = not self.analysing
		chip.skel.Visible = self.analysing
		chip.chip.BackgroundTransparency = if n > 0 or self.analysing then 0 else 0.55
	end
	if self.abilities then
		self.abilityLine.Text = string.format("✦ Abilities: %d used · %d missed", mine.abilitiesUsed, mine.abilitiesMissed)
	end
	for _, color in { "w", "b" } do
		local a = summary[color].accuracy
		local acc = self.acc[color]
		local ready = a ~= nil and not self.analysing
		acc.value.Text = if ready then string.format("%.1f", a) else ""
		acc.skel.Visible = not ready
	end
	self:shimmerCheck()
end

-- the eval bar shows the position after the selected move (the start: the first entry's "before")
function ReviewPanel:refreshEval()
	local cp, mate
	if self.showingBest then
		local e = self.entries[self.ply]
		cp = e and e.cpBefore
	elseif self.ply == 0 then
		local e = self.entries[1]
		cp = e and e.cpBefore
	else
		local e = self.entries[self.ply]
		cp, mate = e and e.cpAfter, e and e.mateAfter
	end
	self.evalSkel.Visible = cp == nil
	self:shimmerCheck()
	if not cp then
		self.evalLabel.Text = ""
		return
	end
	local share = Review.winPercent(cp) / 100
	if mate then
		share = if mate > 0 or (mate == 0 and cp > 0) then 1 else 0
	end
	local flip = self.record.myColor == "b"
	self.evalFill.AnchorPoint = if flip then Vector2.new(0, 0) else Vector2.new(0, 1)
	self.evalFill.Position = if flip then UDim2.fromScale(0, 0) else UDim2.fromScale(0, 1)
	self.evalFill.Size = UDim2.fromScale(1, math.clamp(share, 0.02, 0.98))
	self.evalLabel.Text = evalText(cp, mate)
	-- the number sits at the leading side's end of the bar
	local whiteAhead = share >= 0.5
	local atBottom = whiteAhead ~= flip
	self.evalLabel.Position = if atBottom then UDim2.new(0, 0, 1, -20) else UDim2.fromOffset(0, 2)
	self.evalLabel.TextColor3 = if whiteAhead then T.ink else T.white
end

-- the "Show best move" button is offered on mistakes, blunders and missed abilities
local function offersBest(e)
	return e ~= nil and e.best ~= nil and (e.class == "mistake" or e.class == "blunder" or e.missedAbility == true)
end

function ReviewPanel:refreshFeedback()
	local e = self.entries[self.ply]
	local offer = offersBest(e)
	self.bestHolder.Visible = offer
	if self.showingBest then
		setText(self.bestButton, "Back", I.back)
	else
		setText(self.bestButton, "Best move", I.best)
	end
	-- text leaves room for the Best move button underneath it when that shows
	self.feedback.Size = if offer then UDim2.new(1, -86, 1, -56) else UDim2.new(1, -86, 1, -16)
	local waiting = self.ply > 0 and e == nil and not self.showingBest
	for _, sk in self.fbSkel do
		sk.Visible = waiting
	end
	local badgeClass = if self.showingBest then "best" elseif e then e.class else nil
	if badgeClass then
		local c = Review.CLASS[badgeClass]
		self.fbBadge.Text = c.symbol
		self.fbBadge.BackgroundColor3 = c.color
	else
		self.fbBadge.Text = ""
		self.fbBadge.BackgroundColor3 = T.panelDeep
	end
	self:shimmerCheck()
	local text
	if self.showingBest and e then
		local best = Review.CLASS.best
		text = string.format("<font color=\"#%s\">★ Best move here: <b>%s</b></font>", best.color:ToHex(), shortLabel(e.bestSan or "?"))
		local info = self.bestInfo
		if info and info.count > 0 then
			text ..= string.format(" It takes %d piece%s (+%d).", info.count, if info.count == 1 then "" else "s", info.points)
		end
		self.feedback.Text = text
		return
	end
	if self.ply == 0 then
		text = "Start position. Use ◀ ▶ to step through."
	elseif not e then
		text = ""
	else
		local c = Review.CLASS[e.class]
		local hex = c.color:Lerp(T.white, 0.45):ToHex() -- brightened so it reads on the green card
		local moveName = self.moveButtons[self.ply] and self.moveButtons[self.ply].button.Text or e.san
		if e.class == "brilliant" then
			text = string.format("<font color=\"#%s\">%s is brilliant!!</font> It gives material away, and it works.", hex, moveName)
		elseif e.class == "great" then
			text = string.format("<font color=\"#%s\">%s is a great move!</font> It was the only good move here.", hex, moveName)
		elseif e.class == "best" then
			text = string.format("<font color=\"#%s\">%s is the best move.</font>", hex, moveName)
		elseif e.class == "forced" then
			text = string.format("%s was the only legal move.", moveName)
		else
			local article = if e.class == "inaccuracy" or e.class == "excellent" then "an" else "a"
			-- "an excellent move", "a good move"; "an inaccuracy", "a mistake", "a blunder"
			local noun = string.lower(c.name) .. (if e.class == "excellent" or e.class == "good" then " move" else "")
			text = string.format("<font color=\"#%s\">%s is %s %s.</font>", hex, moveName, article, noun)
			if e.bestSan and e.class ~= "excellent" then
				text ..= " Best was <b>" .. shortLabel(e.bestSan) .. "</b>."
			end
		end
		local info = self.abilityInfo[self.ply]
		if e.ability and info and info.count > 0 then
			text ..= string.format(" It took %d piece%s (+%d).", info.count, if info.count == 1 then "" else "s", info.points)
		end
		if e.missedAbility then
			text ..= " <font color=\"#" .. T.red:ToHex() .. "\">A missed ability!</font>"
		end
	end
	self.feedback.Text = text
end

-- jump to the position after `ply` moves (0 = the start)
function ReviewPanel:go(ply, quiet)
	local record = self.record
	ply = math.clamp(ply, 0, #record.actions)
	local step = ply - (self.ply or 0)
	if not quiet and step ~= 0 then
		self.userNavigated = true
		self:playStepSound(ply, step)
	end
	self.ply = ply
	self.showingBest = false
	self.bestToken = (self.bestToken or 0) + 1
	local g = Game.forReplay(record.startFen, record.mode, record.actions)
	local before
	for i = 1, ply do
		if i == ply then
			before = g:clone()
		end
		g:apply(record.actions[i])
	end
	self.board:sync(g, step == 1 or step == -1)
	local e = self.entries[ply]
	local info = self:drawMove(before, g, record.actions[ply], e and e.class)
	if info then
		self.abilityInfo[ply] = info
	end
	-- highlight the selected move in the list and keep it in view
	for i, mb in self.moveButtons or {} do
		mb.button.BackgroundTransparency = if i == ply then 0 else 1
		mb.button.BackgroundColor3 = if i == ply then T.panelLift else T.white
	end
	local mb = self.moveButtons and self.moveButtons[ply]
	if mb then
		local top = mb.button.AbsolutePosition.Y - self.moveScroll.AbsolutePosition.Y + self.moveScroll.CanvasPosition.Y
		local view = self.moveScroll.AbsoluteSize.Y
		if top < self.moveScroll.CanvasPosition.Y or top > self.moveScroll.CanvasPosition.Y + view - 30 then
			self.moveScroll.CanvasPosition = Vector2.new(0, math.max(0, top - view / 2))
		end
	end
	self:refreshFeedback()
	self:refreshEval()
end

-- sounds while stepping: the move itself (forward) or a soft knock (back), then a chime on a
-- brilliant / great move or a low note on a mistake / blunder
function ReviewPanel:playStepSound(ply, step)
	if ply == 0 then
		Sounds.play("move")
		return
	end
	local san = self.sans[ply] or ""
	local action = self.record and self.record.actions[ply]
	if step > 0 and action and action.kind == "ability" then
		Sounds.play(ABILITY_SOUND[action.id] or "snipe")
	elseif step > 0 then
		Sounds.forMove(san)
	else
		Sounds.play("move")
	end
	local e = self.entries[ply]
	if e then
		if e.class == "brilliant" or e.class == "great" then
			task.delay(0.12, Sounds.play, "good")
		elseif e.class == "mistake" or e.class == "blunder" then
			task.delay(0.12, Sounds.play, "bad")
		end
	end
end

-- Skeleton loaders: a placeholder bar with a soft shine sweeping across it. One loop drives every
-- shine (and pulses the move-list dots) while the review is open and something is still loading.
function ReviewPanel:skeleton(parent, size, pos, color)
	local f = Instance.new("Frame")
	f.Name = "Skeleton"
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color or T.panelDeep:Lerp(T.white, 0.12)
	f.BorderSizePixel = 0
	f.ClipsDescendants = true
	f.ZIndex = 4
	f.Parent = parent
	corner(f, 7)
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Size = UDim2.fromScale(1, 1)
	shine.BackgroundColor3 = T.white
	shine.BorderSizePixel = 0
	shine.ZIndex = 4
	shine.Parent = f
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.72),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Rotation = 15
	g.Parent = shine
	table.insert(self.shimmers, g)
	return f
end

function ReviewPanel:startShimmer()
	if self.shimmerConn then
		return
	end
	self.shimmerConn = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local x = (t % 1.3) / 1.3 * 2.4 - 1.2
		for _, g in self.shimmers do
			if g.Parent and g.Parent.Parent and g.Parent.Parent.Visible then
				g.Offset = Vector2.new(x, 0)
			end
		end
		local a = 0.35 + 0.3 * math.sin(t * 5)
		for dot in self.pulses do
			dot.BackgroundTransparency = a
		end
	end)
end

function ReviewPanel:stopShimmer()
	if self.shimmerConn then
		self.shimmerConn:Disconnect()
		self.shimmerConn = nil
	end
end

-- keep the loop running only while something on screen is still loading
function ReviewPanel:shimmerCheck()
	if not self.gui.Enabled then
		return
	end
	local loading = self.analysing or next(self.pulses) ~= nil
	if loading then
		self:startShimmer()
	else
		self:stopShimmer()
	end
end

-- Marks and the grade badge for one move: `before` is the position it was played in, `after` the
-- result. Returns { count, points } for an ability (what it took), else nil.
function ReviewPanel:drawMove(before, after, a, classId)
	local marks, info = {}, nil
	if a and a.kind == "ability" and before then
		-- the piece that used it tinted; a snipe's / ram's line as dots, landings as dots, and the
		-- pieces it took in red (whatever of the opponent's is gone afterwards)
		marks.targets, marks.tints = {}, { a.from }
		if a.id == "BishopSnipe" then
			for _, s in Snipe.path(before, a.from, a.dir) do
				marks.targets[s] = "move"
			end
		elseif a.id == "RookRam" then
			for _, s in RookRam.trace(before, a.from, a.dir).path do
				marks.targets[s] = "move"
			end
		end
		for _, s in { a.mid, a.to } do
			marks.targets[s] = if a.id == "QueenSwap" then "swap" else "move"
		end
		local alive = {}
		for _, p in after.board.sq do
			alive[p.id] = true
		end
		info = { count = 0, points = 0 }
		local mover = before.turn
		for s, p in before.board.sq do
			if p.color ~= mover and not alive[p.id] then
				marks.targets[s] = "capture"
				info.count += 1
				info.points += (Search.VALUE[p.type] or 0) // 100
			end
		end
	elseif a then
		marks.lastFrom = a.from
		marks.lastTo = a.to
	end
	if after:inCheck() then
		marks.check = after.board.kings[after.turn]
	end
	self.board:setMarks(marks)
	if self.badge then
		self.badge:Destroy()
		self.badge = nil
	end
	local at = a and (a.to or a.from)
	if classId and at then
		local c = Review.CLASS[classId]
		local col, row = self.board:cell(at)
		local badge = label(self.board.topLayer, "Grade", c.symbol, UDim2.fromScale(0.05, 0.05),
			UDim2.fromScale((col + 1) / 8 - 0.035, row / 8 - 0.015), HEAVY, 13, T.white, Enum.TextXAlignment.Center)
		badge.TextScaled = true
		badge.BackgroundColor3 = c.color
		badge.BackgroundTransparency = 0
		badge.ZIndex = 7
		corner(badge, 99)
		stroke(badge, T.white, 2)
		self.badge = badge
	end
	return info
end

-- Show best move: the board goes back to the position before the selected move and plays the
-- best move instead (with a ★ badge); pressing again returns to the move that was played.
function ReviewPanel:toggleBest()
	local e = self.entries[self.ply]
	if self.showingBest or not offersBest(e) then
		self:go(self.ply)
		return
	end
	local record = self.record
	local g = Game.forReplay(record.startFen, record.mode, record.actions)
	for i = 1, self.ply - 1 do
		g:apply(record.actions[i])
	end
	local before = g:clone()
	self.board:sync(g, false) -- pieces back to where they stood before the move
	if not g:apply(e.best) then
		return
	end
	self.showingBest = true
	self.bestToken = (self.bestToken or 0) + 1
	local token = self.bestToken
	self.bestInfo = self:drawMove(before, g, e.best, "best")
	task.delay(0.2, function()
		if self.showingBest and self.bestToken == token then
			self.board:sync(g, true) -- then the best move slides in
		end
	end)
	self:refreshFeedback()
	self:refreshEval()
end

-- Abilities review: jump to the next ability use, brilliant/great move, mistake or blunder (wrapping round)
function ReviewPanel:nextKeyMoment()
	local moments = {}
	for i = 1, #self.record.actions do
		local e = self.entries[i]
		local isAbility = self.record.actions[i].kind == "ability"
		if isAbility or (e and (e.class == "mistake" or e.class == "blunder" or e.class == "brilliant" or e.class == "great"
			or e.missedAbility)) then
			table.insert(moments, i)
		end
	end
	if #moments == 0 then
		self.feedback.Text = "No key moments" .. (if self.status then " yet (" .. self.status .. ")" else " in this game.")
		return
	end
	for _, i in moments do
		if i > self.ply then
			self:go(i)
			return
		end
	end
	self:go(moments[1])
end

-- arrows / D-pad step through the game, Home/End jump, B closes (keyboard and controller)
function ReviewPanel:bindInput(on)
	if not on then
		ContextActionService:UnbindAction(NAV_ACTION)
		return
	end
	ContextActionService:BindActionAtPriority(NAV_ACTION, function(_, state, input)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Sink
		end
		local k = input.KeyCode
		if k == Enum.KeyCode.Left or k == Enum.KeyCode.DPadLeft then
			self:go(self.ply - 1)
		elseif k == Enum.KeyCode.Right or k == Enum.KeyCode.DPadRight then
			self:go(self.ply + 1)
		elseif k == Enum.KeyCode.Home or k == Enum.KeyCode.DPadUp then
			self:go(0)
		elseif k == Enum.KeyCode.End or k == Enum.KeyCode.DPadDown then
			self:go(#self.record.actions)
		elseif k == Enum.KeyCode.ButtonB then
			if self.pgnSheet.Visible then
				self:showPgn(false)
			else
				self:close()
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, 4000, Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Home, Enum.KeyCode.End,
		Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight, Enum.KeyCode.DPadUp, Enum.KeyCode.DPadDown, Enum.KeyCode.ButtonB)
	if GuiService.SelectedObject then
		GuiService.SelectedObject = self.nextButton
	end
end

return ReviewPanel
