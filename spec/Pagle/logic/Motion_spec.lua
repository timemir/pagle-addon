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
