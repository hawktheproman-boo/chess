-- Per-player results by bucket (mode id, e.g. "Classic"): DataStore "ChessStats_v1", key
-- "u_<userId>", value { [bucket] = { w, l, d }, detail = ... }. Only games against people are
-- recorded (since 2026-10-18); older saves still hold "<Mode>_bot" buckets and detail.bots, which
-- the Stats panel ignores.
-- detail (shown to VIPs, recorded for everyone): { streak, bestStreak, games, plies, longest,
-- fastestWin (plies), winsBy = { [reason] = n }, bots = { [level name] = { w, l, d } } }.
-- Studio needs "Enable Studio Access to API Services" for this to save; failures only warn.

local DataStoreService = game:GetService("DataStoreService")

local Results = {}

local storeOk, store = pcall(function()
	return DataStoreService:GetDataStore("ChessStats_v1")
end)
if not storeOk then
	warn("[Chess] stats DataStore unavailable:", store)
	store = nil
end

local warned = false

-- info = { bucket, outcome = "w" (win) | "l" (loss) | "d" (draw), reason?, plies?, botLevel? (name) }.
-- Runs in the background with retries.
function Results.record(userId: number, info)
	local bucket, outcome = info.bucket, info.outcome
	if not store or userId <= 0 then
		return
	end
	task.spawn(function()
		for attempt = 1, 3 do
			local ok, err = pcall(function()
				store:UpdateAsync("u_" .. userId, function(old)
					old = old or {}
					local b = old[bucket] or { w = 0, l = 0, d = 0 }
					b[outcome] += 1
					old[bucket] = b
					local d = old.detail or { streak = 0, bestStreak = 0, games = 0, plies = 0, longest = 0, winsBy = {}, bots = {} }
					local plies = info.plies or 0
					d.games += 1
					d.plies += plies
					d.longest = math.max(d.longest, plies)
					if outcome == "w" then
						d.streak += 1
						d.bestStreak = math.max(d.bestStreak, d.streak)
						if info.reason then
							d.winsBy[info.reason] = (d.winsBy[info.reason] or 0) + 1
						end
						if plies > 0 then
							d.fastestWin = math.min(d.fastestWin or math.huge, plies)
						end
					elseif outcome == "l" then
						d.streak = 0
					end
					if info.botLevel then
						local lv = d.bots[info.botLevel] or { w = 0, l = 0, d = 0 }
						lv[outcome] += 1
						d.bots[info.botLevel] = lv
					end
					old.detail = d
					return old
				end)
			end)
			if ok then
				return
			end
			if not warned then
				warned = true
				warn("[Chess] couldn't save a result:", err)
			end
			task.wait(2 ^ attempt)
		end
	end)
end

function Results.get(userId: number)
	if not store then
		return nil
	end
	local ok, data = pcall(function()
		return store:GetAsync("u_" .. userId)
	end)
	return if ok then data or {} else nil
end

return Results
