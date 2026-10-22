-- The announcements' motion as maths (announcements.md › Motion): the canvas's cubic-bezier and steps easings, and an
-- animation's values over time from its keyframes, each segment eased as CSS eases it.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

-- Rounds to 3 places, so eased values compare.
local function round(value)
	return math.floor(value * 1000 + 0.5) / 1000
end

describe("the motion's easings", function()
	it("run a cubic-bezier from 0 to 1, overshooting past 1 where the curve does", function()
		local slide = ns.Bezier(0.2, 1.2, 0.4, 1)

		assert.are.same({ 0, 1 }, { slide(0), slide(1) })
		assert.is_true(slide(0.5) > 1)
		assert.are.equal(0.5, round(ns.Bezier(0.5, 0.5, 0.5, 0.5)(0.5)))
	end)

	it("preserve time when both control points lie on y = x", function()
		local identity = ns.Bezier(0.2, 0.2, 0.8, 0.8)

		for _, t in ipairs({ 0.25, 0.5, 0.75 }) do
			assert.is_true(math.abs(identity(t) - t) < 0.000001)
		end
	end)

	it("ease out faster than they ease in", function()
		assert.is_true(ns.EASE.out(0.25) > 0.25)
		assert.are.equal(0.25, ns.EASE.linear(0.25))
	end)

	it("step in n jumps, the last at the end", function()
		local steps = ns.Steps(4)

		assert.are.same({ 0, 0.25, 0.5, 0.75, 1 }, { steps(0.1), steps(0.3), steps(0.6), steps(0.99), steps(1) })
	end)
end)

describe("an animation's values over time", function()
	-- Held at 10 until 0.2 of its run, then 10 to 20 linearly by 0.6, held after; 10 s long.
	local animation = {
		dur = 10,
		ease = ns.EASE.linear,
		keys = { { 0, { 10 } }, { 0.2, { 10 } }, { 0.6, { 20 } }, { 1, { 20 } } },
		apply = function() end,
	}

	it("hold, move between their keys, and finish at the last", function()
		local values = {}
		for _, t in ipairs({ 1, 2, 4, 6, 9, 10, 12 }) do
			local value, finished = ns.MotionSample(animation, t)
			values[#values + 1] = { round(value[1]), finished }
		end

		assert.are.same({
			{ 10, false },
			{ 10, false },
			{ 15, false },
			{ 20, false },
			{ 20, false },
			{ 20, true },
			{ 20, true },
		}, values)
	end)

	it("ease a segment with its starting key's own easing", function()
		local stepped = {
			dur = 1,
			keys = { { 0, { 0 }, ease = ns.Steps(2) }, { 1, { 10 } } },
			apply = function() end,
		}

		assert.are.same({ 0, 5, 5 }, {
			ns.MotionSample(stepped, 0.25)[1],
			ns.MotionSample(stepped, 0.5)[1],
			ns.MotionSample(stepped, 0.75)[1],
		})
	end)

	it("wait out a delay, loop forever with iter infinite, and play back on alternate runs", function()
		local spin = { dur = 60, ease = ns.EASE.linear, iter = "infinite", keys = { { 0, { 0 } }, { 1, { 360 } } } }
		local swing =
			{ dur = 1, ease = ns.EASE.linear, iter = 2, dir = "alternate", keys = { { 0, { 0 } }, { 1, { 1 } } } }
		local late = { dur = 1, ease = ns.EASE.linear, delay = 2, keys = { { 0, { 0 } }, { 1, { 1 } } } }

		local value, finished = ns.MotionSample(spin, 75)
		assert.are.same({ 90, false }, { round(value[1]), finished })
		assert.are.equal(0.25, round(ns.MotionSample(swing, 1.75)[1]))
		assert.are.same({ 0, 0.5 }, { ns.MotionSample(late, 1)[1], ns.MotionSample(late, 2.5)[1] })
	end)

	it("settle at the last key, or the first for one that loops forever", function()
		local spin = { dur = 60, iter = "infinite", keys = { { 0, { 0 } }, { 1, { 360 } } } }

		assert.are.same({ { 20 }, { 0 } }, { ns.MotionSettled(animation), ns.MotionSettled(spin) })
	end)
end)

describe("the motion player", function()
	-- A player over a fake host: whether the setting is on, and whether it asked for ticks (awake) or not.
	local function newPlayer(on)
		local host = { on = on ~= false, awake = false }
		host.player = ns.NewMotionPlayer({
			isOn = function()
				return host.on
			end,
			wake = function()
				host.awake = true
			end,
			sleep = function()
				host.awake = false
			end,
		})
		return host
	end

	-- An owner frame, visible until a spec hides it.
	local function newOwner()
		local owner = { visible = true }
		function owner:IsVisible()
			return self.visible
		end
		return owner
	end

	-- A 1 s fade from 0 to 1 that writes each value it sets into `seen`.
	local function fade(seen)
		return {
			dur = 1,
			ease = ns.EASE.linear,
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				seen[#seen + 1] = v[1]
			end,
		}
	end

	it("plays from its first frame to its end, runs onDone there, and asks for no tick at rest (QOL-R25)", function()
		local host, seen, done = newPlayer(), {}, 0
		local asleepBefore = not host.awake

		host.player:Animate(newOwner(), { fade(seen) }, function()
			done = done + 1
		end)
		local awake = host.awake
		host.player:Step(0.5)
		host.player:Step(0.6)

		assert.are.same({ true, true }, { asleepBefore, awake })
		assert.are.same({ 0, 0.5, 1 }, seen)
		assert.are.same({ 1, false }, { done, host.awake })
	end)

	it("settles a hidden owner's animations at their end, its cues and onDone run, never dropping them", function()
		local host, owner, seen, spun, events = newPlayer(), newOwner(), {}, {}, {}
		host.player:Animate(owner, {
			fade(seen),
			{
				dur = 2,
				ease = ns.EASE.linear,
				iter = "infinite",
				keys = { { 0, { 0 } }, { 1, { 360 } } },
				apply = function(v)
					spun[#spun + 1] = v[1]
				end,
			},
		}, function()
			events[#events + 1] = "done"
		end)
		host.player:Cue(owner, 0.8, function()
			events[#events + 1] = "cue"
		end)
		host.player:Step(0.25)

		owner.visible = false
		host.player:Step(0.25)
		host.player:Step(0.25)

		assert.are.same({ 0, 0.25, 1 }, seen)
		assert.are.same({ 0, 45, 0 }, spun) -- a loop rests where it starts
		assert.are.same({ "cue", "done" }, events)
		assert.is_false(host.awake)
	end)

	it("with the Animations setting off, settles at once, runs onDone and never a cue, without a tick", function()
		local host, owner, seen, events = newPlayer(false), newOwner(), {}, {}

		host.player:Animate(owner, { fade(seen) }, function()
			events[#events + 1] = "done"
		end)
		host.player:Cue(owner, 0.1, function()
			events[#events + 1] = "cue"
		end)

		assert.are.same({ { 1 }, { "done" }, false }, { seen, events, host.awake })
	end)

	it("stops an owner where it is, without its onDone, and rests once nothing plays", function()
		local host, owner, seen, done = newPlayer(), newOwner(), {}, false
		host.player:Animate(owner, { fade(seen) }, function()
			done = true
		end)
		host.player:Step(0.5)

		host.player:Stop(owner)
		host.player:Step(0.5)

		assert.are.same({ { 0, 0.5 }, false, false }, { seen, done, host.awake })
	end)
end)
