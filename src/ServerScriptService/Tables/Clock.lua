-- Chess clock with Fischer increment. Times are passed in (server time), so it has no hidden state
-- and the client can redraw it from a snapshot: { w, b, running, at }.
-- No clock runs before White's first move; the increment is only added to a clock that was running.
-- blackBase: Black's own starting time (Armageddon: Black has less); defaults to base.

local Clock = {}
Clock.__index = Clock

function Clock.new(base: number, increment: number, blackBase: number?)
	return setmetatable({ left = { w = base, b = blackBase or base }, increment = increment, running = nil, since = 0 }, Clock)
end

function Clock:remaining(color: string, now: number): number
	local t = self.left[color]
	if self.running == color then
		t -= math.max(0, now - self.since) -- since may be in the future (a held clock)
	end
	return math.max(t, 0)
end

function Clock:stop(now: number)
	if self.running then
		self.left[self.running] = self:remaining(self.running, now)
	end
	self.running = nil
end

-- `color` just moved: bank its time (+ increment) and start the other side.
function Clock:press(color: string, now: number)
	if self.running == color then
		self.left[color] = self:remaining(color, now) + self.increment
	end
	self.running = if color == "w" then "b" else "w"
	self.since = now
end

-- Hold the running clock for `seconds` (e.g. while a cutscene plays). Call right after press().
function Clock:hold(seconds: number, now: number)
	if self.running then
		self.since = math.max(self.since, now) + seconds
	end
end

-- the color whose time ran out, or nil
function Clock:flagged(now: number): string?
	if self.running and self:remaining(self.running, now) <= 0 then
		return self.running
	end
	return nil
end

function Clock:snapshot(now: number)
	-- since: when the running side's time starts ticking (later than `at` while held)
	return { w = self:remaining("w", now), b = self:remaining("b", now), running = self.running, at = now,
		since = math.max(self.since, now) }
end

return Clock
