-- The ability panel (Abilities games), after the ability cards at the bottom of Hunt Valley-style
-- games: one card per piece, pawn to king. Each card shows the piece on a coloured tile, the piece
-- and the ability's name, its key (1-6, keyboard only) and a status: READY, NO TARGET, AIMING,
-- USED (used cards fade) or LOCKED (not bought in the Shop yet: faded, with a padlock). Tap / click / press its key to aim that ability.
-- Wide screens: a row of cards along the bottom, under your player bar. Compact (phones): a 3x2
-- grid of icon cards beside the board, between the player cards.
--
--   AbilityBar.new(parent, onPick) -> bar          onPick(id)
--   bar:setColor("w"|"b")                         your pieces' colour (redraws the icons)
--   bar:setCompact(bool)
--   bar:update(states, aimingId, showKeys)        states = { [id] = { charges, ready, locked? } }
--   bar.holder (place / show it)

local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent.UiKit)
local PieceIcons = require(script.Parent.PieceIcons)
local Sounds = require(script.Parent.Sounds)
local T = Ui.T

local AbilityBar = {}
AbilityBar.__index = AbilityBar

local rgb = Color3.fromRGB
-- pawn to king, like the mode's list; accent = the card's tile colour
AbilityBar.CARDS = {
	{ id = "PawnPassant", piece = "p", pieceName = "Pawn", name = "Any Passant", accent = rgb(40, 190, 170) },
	{ id = "KnightJump", piece = "n", pieceName = "Knight", name = "Double Jump", accent = rgb(52, 152, 219) },
	{ id = "BishopSnipe", piece = "b", pieceName = "Bishop", name = "Snipe", accent = rgb(232, 70, 58) },
	{ id = "RookRam", piece = "r", pieceName = "Rook", name = "Battering Ram", accent = rgb(240, 130, 40) },
	{ id = "KingEscape", piece = "k", pieceName = "King", name = "Royal Escape", accent = rgb(255, 200, 61) },
}
local WIDE = Vector2.new(164, 64)
local SMALL = Vector2.new(56, 64)
local GAP = 8
local STATUS = {
	ready = { "READY", rgb(120, 230, 90) },
	aiming = { "AIMING", rgb(255, 214, 102) },
	none = { "NO TARGET", rgb(150, 170, 150) },
	used = { "USED", rgb(235, 110, 100) },
	locked = { "SHOP", rgb(255, 214, 102) },
}
local SHORT = { ready = "READY", aiming = "AIM", none = "WAIT", used = "USED", locked = "SHOP" }

local function label(parent, name, text, size, pos, face, textSize, color, align)
	local l = Ui.label(parent, name, text, size, pos, face, textSize, color, align)
	l.ZIndex = 3
	return l
end

function AbilityBar.new(parent, onPick)
	local self = setmetatable({}, AbilityBar)
	self.onPick = onPick
	local holder = Instance.new("Frame")
	holder.Name = "AbilityBar"
	holder.BackgroundTransparency = 1
	holder.Parent = parent
	self.holder = holder
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(GAP, GAP)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = holder
	self.grid = grid

	self.cards = {}
	for i, c in AbilityBar.CARDS do
		-- a CanvasGroup, so a used card can fade as one
		local group = Instance.new("CanvasGroup")
		group.Name = c.id
		group.LayoutOrder = i
		group.BackgroundTransparency = 1
		group.Parent = holder
		local scale = Instance.new("UIScale")
		scale.Parent = group
		local b = Instance.new("TextButton")
		b.Name = "Card"
		b.Text = ""
		b.AutoButtonColor = false
		b.Selectable = true
		b.Size = UDim2.new(1, -4, 1, -4)
		b.Position = UDim2.fromOffset(2, 2)
		b.BackgroundColor3 = T.white
		b.Parent = group
		Ui.corner(b, 10)
		Ui.gradient(b, rgb(30, 44, 36), rgb(14, 24, 18))
		local ring = Ui.stroke(b, T.white, 2, 0.45)
		-- the coloured tile with the piece on it
		local tile = Instance.new("Frame")
		tile.Name = "Tile"
		tile.BackgroundColor3 = T.white
		tile.ZIndex = 2
		tile.Parent = b
		Ui.corner(tile, 8)
		Ui.gradient(tile, c.accent:Lerp(T.white, 0.15), c.accent:Lerp(T.ink, 0.35))
		Ui.stroke(tile, T.ink, 2)
		local kicker = label(b, "Kicker", string.upper(c.pieceName), UDim2.new(1, -66, 0, 12), UDim2.fromOffset(62, 6), Ui.HEAVY, 11, rgb(170, 190, 175))
		local name = label(b, "Name", string.upper(c.name), UDim2.new(1, -66, 0, 20), UDim2.fromOffset(62, 18), Ui.TITLE, 16, T.white)
		name.TextScaled = true
		name.TextTruncate = Enum.TextTruncate.None -- (shrinks to fit instead)
		local cap = Instance.new("UITextSizeConstraint")
		cap.MaxTextSize, cap.MinTextSize = 16, 7
		cap.Parent = name
		Ui.chunky(name, 1.5)
		local key = label(b, "Key", tostring(i), UDim2.fromOffset(18, 18), UDim2.fromOffset(62, 41), Ui.TITLE, 12, T.white, Enum.TextXAlignment.Center)
		key.BackgroundColor3 = T.ink
		key.BackgroundTransparency = 0.15
		Ui.corner(key, 5)
		Ui.stroke(key, T.white, 1, 0.6)
		local lock = Ui.icon(tile, Ui.ICONS.lock, UDim2.fromScale(0.55, 0.55), UDim2.fromScale(1, 1), Vector2.new(0.75, 0.75))
		lock.Name = "Lock"
		lock.ZIndex = 4
		lock.Visible = false
		local status = label(b, "Status", "", UDim2.new(1, -90, 0, 16), UDim2.fromOffset(84, 42), Ui.TITLE, 13, T.white)
		status.TextScaled = true
		status.TextTruncate = Enum.TextTruncate.None
		local statusCap = Instance.new("UITextSizeConstraint")
		statusCap.MaxTextSize, statusCap.MinTextSize = 13, 7
		statusCap.Parent = status
		b.MouseEnter:Connect(function()
			if self.states and self.states[c.id] and self.states[c.id].charges > 0 and not self.states[c.id].locked then
				TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.05 }):Play()
			end
		end)
		b.MouseLeave:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.1), { Scale = if self.aiming == c.id then 1.06 else 1 }):Play()
		end)
		b.Activated:Connect(function()
			Sounds.play("click")
			self.onPick(c.id)
		end)
		self.cards[c.id] = { group = group, scale = scale, button = b, ring = ring, tile = tile, kicker = kicker, name = name,
			key = key, status = status, lock = lock, def = c }
	end
	self:setCompact(false)
	return self
end

-- your pieces' colour: the tiles show your own pieces
function AbilityBar:setColor(color)
	if color == self.color then
		return
	end
	self.color = color
	for _, card in self.cards do
		if card.icon then
			card.icon:Destroy()
		end
		local icon = PieceIcons.new(card.def.piece, color)
		icon.Name = "Piece"
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Size = UDim2.fromScale(0.9, 0.9)
		icon.ZIndex = 3
		icon.Parent = card.tile
		card.icon = icon
	end
end

function AbilityBar:setCompact(compact)
	self.compact = compact
	local cell = if compact then SMALL else WIDE
	local gap = if compact then 4 else GAP
	self.grid.CellSize = UDim2.fromOffset(cell.X, cell.Y)
	self.grid.CellPadding = UDim2.fromOffset(gap, gap)
	local cols = if compact then 3 else #AbilityBar.CARDS
	local rows = math.ceil(#AbilityBar.CARDS / cols)
	self.holder.Size = UDim2.fromOffset(cols * cell.X + (cols - 1) * gap, rows * cell.Y + (rows - 1) * gap)
	for _, card in self.cards do
		if compact then
			card.tile.Size = UDim2.fromOffset(40, 40)
			card.tile.Position = UDim2.new(0.5, -20, 0, 4)
			card.status.Size, card.status.Position = UDim2.new(1, -4, 0, 13), UDim2.new(0, 2, 1, -17)
			card.status.TextXAlignment = Enum.TextXAlignment.Center
		else
			card.tile.Size = UDim2.fromOffset(50, 50)
			card.tile.Position = UDim2.fromOffset(5, 5)
			card.status.Size = UDim2.new(1, -90, 0, 16)
			card.status.TextXAlignment = Enum.TextXAlignment.Left
		end
		card.kicker.Visible = not compact
		card.name.Visible = not compact
	end
	self:redraw()
end

function AbilityBar:update(states, aimingId, showKeys)
	self.states, self.aiming, self.showKeys = states, aimingId, showKeys
	self:redraw()
end

-- aiming this ability (or every ability: the controller's ability button)
local function aimingFor(self, id)
	return self.aiming == id or self.aiming == "all"
end

function AbilityBar:redraw()
	for id, card in self.cards do
		local st = self.states and self.states[id] or { charges = 0, ready = false }
		local kind = if st.locked then "locked" elseif st.charges < 1 then "used" elseif aimingFor(self, id) then "aiming" elseif st.ready then "ready" else "none"
		local s = STATUS[kind]
		card.status.Text = if self.compact then SHORT[kind] else s[1]
		card.status.TextColor3 = s[2]
		card.group.GroupTransparency = if kind == "used" then 0.55 elseif kind == "locked" then 0.35 elseif kind == "none" then 0.2 else 0
		card.lock.Visible = kind == "locked"
		card.ring.Color = if kind == "aiming" then T.gold elseif kind == "ready" then s[2] else T.white
		card.ring.Thickness = if kind == "aiming" then 3 else 2
		card.ring.Transparency = if kind == "aiming" or kind == "ready" then 0 else 0.55
		card.scale.Scale = if kind == "aiming" then 1.06 else 1
		card.key.Visible = self.showKeys == true and not self.compact
		if not self.compact then -- (beside the key, or where the key would be)
			card.status.Position = if card.key.Visible then UDim2.fromOffset(84, 42) else UDim2.fromOffset(62, 42)
			card.status.Size = UDim2.new(1, if card.key.Visible then -90 else -68, 0, 16)
		end
	end
end

return AbilityBar
