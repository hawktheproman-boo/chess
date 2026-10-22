-- The two big leaderboard screens in the lobby ("Most wins" and "Tournament champions"). Each is a
-- SurfaceGui on the front face of an anchored Part the lobby builder makes:
--   workspace.Lobby.Decor.Leaderboards.Wins.Screen / .Titles.Screen   (12 x 15 studs)
-- It draws a dark panel with a coloured title bar and the top 10 (rank, headshot, name, count), in
-- the same colours and fonts as the Leaderboard tab in StatsPanel, and refreshes every 60 s.
-- The same board is drawn on the back of the board (the Back part's Back face) for people behind it.
-- A screen that isn't there (another place, an old build) is skipped quietly.
--
--   LobbyBoards.start()   -- builds both screens in the background; safe to call once at startup

local Leaderboards = require(script.Parent.Leaderboards)

local LobbyBoards = {}

local PPS = 72 -- pixels per stud: 12 x 15 studs = 864 x 1080 px, so rows can be ~95 px tall
local ROWS = 10
local REFRESH = 60 -- seconds
local FIND_TIMEOUT = 20 -- seconds to wait for each part of the path

local rgb = Color3.fromRGB
local TITLE_FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local NAME_FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local C = {
	panelDeep = rgb(18, 38, 21),
	panelLift = rgb(46, 84, 50),
	ink = rgb(12, 20, 12),
	green = rgb(91, 194, 54),
	greenEdge = rgb(52, 128, 30),
	gold = rgb(255, 200, 61),
	goldEdge = rgb(184, 126, 20),
	white = rgb(255, 255, 255),
	muted = rgb(168, 196, 160),
}
local MEDALS = { rgb(255, 200, 61), rgb(214, 224, 232), rgb(222, 140, 74) } -- gold, silver, bronze

local BOARDS = {
	{ id = "wins", part = "Wins", title = "MOST WINS", face = C.green, edge = C.greenEdge, empty = "No wins yet. Be the first!" },
	{ id = "titles", part = "Titles", title = "CHAMPIONS", face = C.gold, edge = C.goldEdge, empty = "No champions yet" },
}

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function text(parent, name, str, size, pos, font, textSize, color, align)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = str
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextSize = textSize
	l.TextColor3 = color
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

-- chunky text: an ink outline round the letters
local function outline(l, thickness)
	local s = Instance.new("UIStroke")
	s.Name = "Outline"
	s.Color = C.ink
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = l
end

-- workspace.Lobby.Decor.<...>: waits a little for each step, nil if it never turns up
local function find(...)
	local node = workspace
	for _, name in { ... } do
		node = node:WaitForChild(name, FIND_TIMEOUT)
		if not node then
			return nil
		end
	end
	return node
end

-- builds one screen's gui; returns a function that fills it with a list of rows
local function build(screen: BasePart, spec, face: Enum.NormalId?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PPS
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ResetOnSpawn = false
	gui.Parent = screen

	local W, H = math.floor(screen.Size.X * PPS), math.floor(screen.Size.Y * PPS)
	local PAD = 20
	local HEAD = 100
	local ROW_GAP = 8
	local top = PAD + HEAD + 14
	local rowH = math.floor((H - top - PAD - (ROWS - 1) * ROW_GAP) / ROWS)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = C.panelDeep
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, 48)
	stroke(panel, spec.edge, 10)

	-- the coloured title bar
	local head = Instance.new("Frame")
	head.Name = "Head"
	head.Size = UDim2.new(1, -2 * PAD, 0, HEAD)
	head.Position = UDim2.fromOffset(PAD, PAD)
	head.BackgroundColor3 = spec.face
	head.BorderSizePixel = 0
	head.Parent = panel
	corner(head, 32)
	stroke(head, C.ink, 5)
	local title = text(head, "Title", spec.title, UDim2.fromScale(1, 1), UDim2.new(), TITLE_FONT, 72, C.white, Enum.TextXAlignment.Center)
	outline(title, 6)

	-- the rows, made once and refilled
	local list = Instance.new("Frame")
	list.Name = "List"
	list.Size = UDim2.new(1, -2 * PAD, 1, -top - PAD)
	list.Position = UDim2.fromOffset(PAD, top)
	list.BackgroundTransparency = 1
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, ROW_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local rows = {}
	for i = 1, ROWS do
		local row = Instance.new("Frame")
		row.Name = "Row" .. i
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, rowH)
		row.BackgroundColor3 = C.panelLift
		row.BackgroundTransparency = if i % 2 == 1 then 0 else 0.45
		row.BorderSizePixel = 0
		row.Visible = false
		row.Parent = list
		corner(row, 24)
		local rank = text(row, "Rank", tostring(i), UDim2.fromOffset(100, rowH), UDim2.fromOffset(6, 0), TITLE_FONT, 64, C.muted, Enum.TextXAlignment.Center)
		outline(rank, 4)
		local pic = Instance.new("Frame")
		pic.Name = "Head"
		pic.Size = UDim2.fromOffset(rowH - 16, rowH - 16)
		pic.Position = UDim2.fromOffset(112, 8)
		pic.BackgroundColor3 = C.panelDeep
		pic.BorderSizePixel = 0
		pic.Parent = row
		corner(pic, rowH)
		local shot = Instance.new("ImageLabel")
		shot.Name = "Shot"
		shot.Size = UDim2.fromScale(1, 1)
		shot.BackgroundTransparency = 1
		shot.Parent = pic
		corner(shot, rowH)
		local nameX = 112 + rowH - 16 + 18
		local valueW = 190
		local name = text(row, "Name", "", UDim2.new(1, -nameX - valueW - 16, 1, 0), UDim2.fromOffset(nameX, 0), NAME_FONT, 52, C.white)
		outline(name, 3)
		local value = text(row, "Value", "", UDim2.fromOffset(valueW, rowH), UDim2.new(1, -valueW - 20, 0, 0), TITLE_FONT, 64, C.white, Enum.TextXAlignment.Right)
		outline(value, 4)
		rows[i] = { row = row, rank = rank, shot = shot, name = name, value = value }
	end

	-- friendly line when nobody is on the board yet
	local empty = text(panel, "Empty", spec.empty, UDim2.new(1, -120, 0, 240), UDim2.new(0, 60, 0.5, -120), NAME_FONT, 60, C.muted, Enum.TextXAlignment.Center)
	empty.TextWrapped = true
	empty.TextTruncate = Enum.TextTruncate.None
	empty.Visible = false

	return function(data)
		empty.Visible = #data == 0
		for i, r in rows do
			local d = data[i]
			r.row.Visible = d ~= nil
			if d then
				local rank = d.rank or i
				r.rank.Text = tostring(rank)
				r.rank.TextColor3 = MEDALS[rank] or C.muted
				r.name.Text = tostring(d.name or "?")
				r.value.Text = tostring(d.value or 0)
				if type(d.userId) == "number" and d.userId > 0 then
					r.shot.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", d.userId)
				else
					r.shot.Image = "" -- (fake test ids have no headshot: a blank circle)
				end
			end
		end
	end
end

local function run(spec)
	local screen = find("Lobby", "Decor", "Leaderboards", spec.part, "Screen")
	if not screen or not screen:IsA("BasePart") then
		return
	end
	local fills = { build(screen, spec) }
	-- the board's back panel shows it too, for anyone coming from the other side
	local back = screen.Parent and screen.Parent:FindFirstChild("Back")
	if back and back:IsA("BasePart") then
		table.insert(fills, build(back, spec, Enum.NormalId.Back))
	end
	while screen.Parent do
		local ok, err = pcall(function()
			local top = Leaderboards.top(spec.id, ROWS)
			for _, fill in fills do
				fill(top)
			end
		end)
		if not ok then
			warn("[Chess] lobby board failed:", spec.id, err)
		end
		task.wait(REFRESH)
	end
end

function LobbyBoards.start()
	for _, spec in BOARDS do
		task.spawn(run, spec)
	end
end

return LobbyBoards
