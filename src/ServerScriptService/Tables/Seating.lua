-- Ties the physical tables (workspace.Lobby.Tables, built by builders/build_room.lua) to the logical
-- ChessTables: chair prompts sit you down, and the Seat parts follow the logical seats. Sitting in
-- a chair by walking into it doesn't count; leaving a chair by jumping doesn't stand you up (you
-- get put back). Standing is the HUD's job.

local Seating = {}

local chairs = {} -- tableId -> { w = Seat, b = Seat }
local tablesById

function Seating.init(tables, sitPlayer)
	tablesById = tables
	local root = workspace:WaitForChild("Lobby", 10)
	local folder = root and root:FindFirstChild("Tables")
	if not folder then
		warn("[Chess] no workspace.Lobby.Tables: run builders/build_room.lua")
		return
	end
	for _, model in folder:GetChildren() do
		local id = model:GetAttribute("TableId")
		local w, b = model:FindFirstChild("WhiteSeat"), model:FindFirstChild("BlackSeat")
		if id and tables[id] and w and b then
			chairs[id] = { w = w, b = b }
			for color, seat in { w = w, b = b } do
				local prompt = seat:FindFirstChild("SitPrompt")
				if prompt then
					prompt.Triggered:Connect(function(player)
						sitPlayer(player, id, color)
					end)
				end
				seat:GetPropertyChangedSignal("Occupant"):Connect(function()
					task.defer(Seating.sync, tables[id])
				end)
			end
			task.defer(Seating.sync, tables[id]) -- (prompts start right: none in a tournament server)
		end
	end
end

local function humanoidOf(participant)
	local player = participant and participant.player
	local char = player and player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		return hum
	end
	return nil
end

function Seating.sync(t)
	local pair = t and chairs[t.id]
	if not pair then
		return
	end
	for color, seat in pair do
		local p = t.seats[color]
		local hum = humanoidOf(p)
		local occupant = seat.Occupant
		if occupant and occupant ~= hum then
			local weld = seat:FindFirstChild("SeatWeld")
			if weld then
				weld:Destroy()
			end
			occupant.Sit = false
		end
		if hum and seat.Occupant ~= hum then
			seat:Sit(hum)
		end
		local prompt = seat:FindFirstChild("SitPrompt")
		if prompt then
			prompt.Enabled = p == nil and t.status ~= "playing" and not t.owner
				and not game:GetService("ReplicatedStorage"):GetAttribute("TournamentServer")
		end
	end
end

-- after a respawn, put seated players back in their chairs
function Seating.syncPlayer(player)
	for _, t in tablesById do
		if t:colorOf(player.UserId) then
			Seating.sync(t)
		end
	end
end

return Seating
