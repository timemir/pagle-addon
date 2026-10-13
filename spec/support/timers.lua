-- The one timer fake: a clock that moves only when a spec moves it, with C_Timer's repeating tickers and one-shot
-- timers on it. The fake client's C_Timer and GetTime run on one (addStubs), and so does FakePagle's grace timer
-- (spec/support/fake_pagle.lua), so both pick the next timer due the same way.
--
--   loaded.client.advance(0.5)   -- the clock moves on 0.5 s, running each ticker and timer that comes due, in time order
--   loaded.client.runTimers()    -- every C_Timer.After callback queued so far runs now, as the next frames would
--   loaded.client.time()         -- GetTime(): seconds since the load

---@class FakeClient
---@field time fun(): number The client's clock, in seconds since the load, as GetTime() returns it; advance moves it.
---@field advance fun(seconds: number) Moves the client's clock on, running each ticker every time its period passes
--- and each C_Timer.After callback once its time has passed, in time order (ties in the order they were made).
---@field runTimers fun() Runs every C_Timer.After callback queued so far, as the next frames would, in order.

--- A clock with timers on it, at 0 until `advance` moves it.
---@class FakeClock
---@field time fun(): number Seconds since the clock was made.
---@field advance fun(seconds: number) Moves the clock on `seconds`, running each timer as it comes due, earliest
--- first; of two due at once, the one made first.
---@field newTicker fun(period: number, callback: fun(ticker: table)): table What C_Timer.NewTicker(period, callback)
--- does without iterations: a ticker, with Cancel and IsCancelled, that runs callback every period until cancelled.
---@field after fun(seconds: number, callback: fun()) What C_Timer.After does: runs callback once, when advance has
--- moved the clock `seconds` on or at runTimers, whichever comes first.
---@field runTimers fun() Runs every `after` callback not yet run, in the order they were queued. One a callback
--- queues waits for the next runTimers.

local timers = {}

---@return FakeClock
function timers.newClock()
	local clock = {}
	local now = 0
	-- Every ticker and timer, in the order made; a timer is a ticker that cancels itself when it runs.
	local scheduled = {}

	function clock.time()
		return now
	end

	function clock.newTicker(period, callback)
		local ticker = { period = period, due = now + period, callback = callback, cancelled = false }
		function ticker:Cancel()
			self.cancelled = true
		end
		function ticker:IsCancelled()
			return self.cancelled
		end
		scheduled[#scheduled + 1] = ticker
		return ticker
	end

	function clock.after(seconds, callback)
		local timer = clock.newTicker(seconds, function(self)
			self:Cancel()
			callback()
		end)
		timer.once = true
	end

	function clock.advance(seconds)
		local target = now + seconds
		while true do
			local nextTicker
			for _, ticker in ipairs(scheduled) do
				if
					not ticker.cancelled
					and ticker.due <= target
					and (not nextTicker or ticker.due < nextTicker.due)
				then
					nextTicker = ticker
				end
			end
			if not nextTicker then
				break
			end
			now = nextTicker.due
			nextTicker.due = now + nextTicker.period
			nextTicker.callback(nextTicker)
		end
		now = target
	end

	function clock.runTimers()
		local due = {}
		for _, ticker in ipairs(scheduled) do
			if ticker.once and not ticker.cancelled then
				due[#due + 1] = ticker
			end
		end
		for _, timer in ipairs(due) do
			timer.callback(timer)
		end
	end

	return clock
end

--- C_Timer (NewTicker and After) and GetTime on a fresh clock, with the client's advance, runTimers and time on it.
---@param client FakeClient
---@param stubs table<string, any> The fake client's stubs, which this adds to.
function timers.addStubs(client, stubs)
	local clock = timers.newClock()
	client.time, client.advance, client.runTimers = clock.time, clock.advance, clock.runTimers
	stubs.C_Timer = {
		NewTicker = function(seconds, callback)
			return clock.newTicker(seconds, callback)
		end,
		After = function(seconds, callback)
			clock.after(seconds, callback)
		end,
	}
	stubs.GetTime = function()
		return clock.time()
	end
end

return timers
