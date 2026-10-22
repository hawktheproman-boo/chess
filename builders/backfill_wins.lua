-- One-off: seeds the LIVE Most wins board (OrderedDataStore "ChessLB_Wins_v1") from the stats every
-- player already has (DataStore "ChessStats_v1", keys "u_<userId>"): their total wins against people,
-- summed over the buckets (Classic, Abilities, Tournament; old "*_bot" buckets and "detail" are
-- skipped, as the Stats card skips them). Results.lua keeps recording every win that the board counts,
-- so a player's stats total is never below their board value; each entry is raised to the stats total
-- and never lowered, which makes re-running it safe.
--
-- Run once, in the MAIN place (Edit mode, "Enable Studio Access to API Services" on), after the
-- Leaderboards code is published: python tools/run_luau.py builders/backfill_wins.lua
-- It starts as a dry run (prints what it would write). Set DRY_RUN = false to write.
-- Studio games never write "ChessLB_Wins_v1" (they use the _studio stores); this script is the one
-- exception, on purpose: it names the live store directly.

local DRY_RUN = true
local TARGET = "ChessLB_Wins_v1" -- the live board (NOT the _studio one)
local PAUSE = 0.15 -- seconds between players (stays under the DataStore budgets)

local DataStoreService = game:GetService("DataStoreService")
local stats = DataStoreService:GetDataStore("ChessStats_v1")
local board = DataStoreService:GetOrderedDataStore(TARGET)

local function totalWins(data)
	local w = 0
	if type(data) ~= "table" then
		return 0
	end
	for bucket, s in data do
		if bucket ~= "detail" and not string.find(bucket, "_bot$") and type(s) == "table" then
			w += tonumber(s.w) or 0
		end
	end
	return w
end

local seen, written, skipped, failed = 0, 0, 0, 0
local pages = stats:ListKeysAsync("u_", 100)
while true do
	for _, key in pages:GetCurrentPage() do
		local name = key.KeyName
		local userId = tonumber(string.match(name, "^u_(%d+)$"))
		if userId and userId > 0 then
			seen += 1
			local ok, data = pcall(stats.GetAsync, stats, name)
			local wins = if ok then totalWins(data) else 0
			if not ok then
				failed += 1
				warn("[backfill] couldn't read", name, data)
			elseif wins <= 0 then
				skipped += 1
			elseif DRY_RUN then
				print(string.format("[backfill] would set %d -> %d wins", userId, wins))
				written += 1
			else
				local okW, err = pcall(board.UpdateAsync, board, tostring(userId), function(old)
					old = tonumber(old) or 0
					return if wins > old then wins else nil -- (nil: leave it)
				end)
				if okW then
					written += 1
				else
					failed += 1
					warn("[backfill] couldn't write", userId, err)
				end
			end
			task.wait(PAUSE)
		end
	end
	if pages.IsFinished then
		break
	end
	pages:AdvanceToNextPageAsync()
end

local summary = string.format("[backfill] %s: %d players, %d %s, %d with no wins, %d failed",
	if DRY_RUN then "dry run" else "done", seen, written, if DRY_RUN then "to write" else "written", skipped, failed)
print(summary)
return summary
