-- Edit-mode preview for stills: puts a mid-game position on Table 5 using the client's Pieces module
-- (pieces are normally client-only). Run with arg-less run_luau; remove with clear_preview.lua.
local Pieces = require(game.StarterPlayer.StarterPlayerScripts.Chess.Pieces:Clone())
local old = workspace:FindFirstChild("PiecePreview")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "PiecePreview"
local model = workspace.Lobby.Tables.T5
-- a Ruy Lopez-ish middlegame: (file, rank, type, color)
local layout = "r1bq1rk1/2p1bppp/p1np1n2/1p2p3/4P3/1BP2N1P/PP1P1PP1/RNBQR1K1"
local rank = 7
local file = 0
for ch in string.gmatch(layout, ".") do
	if ch == "/" then
		rank -= 1
		file = 0
	elseif tonumber(ch) then
		file += tonumber(ch)
	else
		local color = if ch == string.upper(ch) then "w" else "b"
		local sq = model.Board:FindFirstChild(tostring(rank * 16 + file))
		local m = Pieces.build(string.lower(ch), color)
		local top = sq.Position + Vector3.new(0, sq.Size.Y / 2, 0)
		m:PivotTo(CFrame.new(top) * (if color == "b" then CFrame.Angles(0, math.pi, 0) else CFrame.new()))
		m.Parent = folder
		file += 1
	end
end
folder.Parent = workspace
return "preview placed"
