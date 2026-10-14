-- Moments and a Cast's Announcements (announcements.md › Moments and the ladder, › A Cast's Announcements;
-- ADR 0007): logic/Moments.lua fed moments, the projection machinery's seams and a frame queue.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

local LEDGER = { def = { name = "Ledger", title = "Ledger", order = 10 } }
local HUNTS = { def = { name = "Hunts", title = "Hunts", order = 20 } }
local CAST = "Player-4618-0A1B2C3D-1791731000-0"

-- A collector over fake seams. `world.frame()` runs what was queued for the next frame; `world.mode` and
-- `world.updating` are what the projection machinery would say; `world.idle()` is the last projection finishing.
local function newWorld()
	local world = { mode = nil, updating = false, shown = {}, summarized = {}, reported = {} }
	local queued, idle = {}, {}
	world.moments = ns.NewMoments({
		mode = function()
			return world.mode
		end,
		isUpdating = function()
			return world.updating
		end,
		whenIdle = function(fn)
			if world.updating then
				idle[#idle + 1] = fn
			else
				fn()
			end
		end,
		nextFrame = function(step)
			queued[#queued + 1] = step
		end,
		report = function(message)
			world.reported[#world.reported + 1] = message
		end,
		show = function(announcement)
			world.shown[#world.shown + 1] = announcement
		end,
		summarize = function(moment)
			world.summarized[#world.summarized + 1] = moment
		end,
	})
	function world.frame()
		local steps = queued
		queued = {}
		for _, step in ipairs(steps) do
			step()
		end
	end
	function world.idle()
		world.updating = false
		local hooks = idle
		idle = {}
		for _, fn in ipairs(hooks) do
			fn()
		end
	end
	return world
end

-- A moment on `rung` titled `title`, for CAST unless `fields.cast` is false; other fields from `fields`.
local function moment(rung, title, fields)
	local m = { rung = rung, kind = "spec", title = title, cast = CAST }
	for key, value in pairs(fields or {}) do
		m[key] = value
	end
	if m.cast == false then
		m.cast = nil
	end
	return m
end

-- The headline titles of what was shown, in order.
local function headlines(world)
	local titles = {}
	for i, announcement in ipairs(world.shown) do
		titles[i] = announcement.headline.title
	end
	return titles
end

describe("a Cast's moments", function()
	it("become one Announcement on the next frame, never before (ANN-R10, ANN-R11)", function()
		local world = newWorld()

		world.moments:Raise(LEDGER, moment("toast", "New Species"))
		assert.are.same({}, world.shown)
		world.frame()

		assert.are.same({ "New Species" }, headlines(world))
		assert.are.equal("toast", world.shown[1].rung)
		assert.are.equal(CAST, world.shown[1].cast)
	end)
end)

-- The titles of an Announcement's moments, ranked.
local function ranked(announcement)
	local titles = {}
	for i, m in ipairs(announcement.moments) do
		titles[i] = m.title
	end
	return titles
end

describe("a Cast's Announcements", function()
	it("merges two Modules' moments for one Cast, raised in either order (ANN-R10, ANN-R11)", function()
		for _, ledgerFirst in ipairs({ true, false }) do
			local world = newWorld()
			local species = moment("toast", "New Species", { stamp = "New!" })
			local hunt = moment("toast.high", "Hunt completed")

			if ledgerFirst then
				world.moments:Raise(LEDGER, species)
				world.moments:Raise(HUNTS, hunt)
			else
				world.moments:Raise(HUNTS, hunt)
				world.moments:Raise(LEDGER, species)
			end
			world.frame()

			assert.are.same({ "Hunt completed" }, headlines(world))
			local shown = world.shown[1]
			assert.are.same({ "toast.high", { "New!" }, 0 }, { shown.rung, shown.stamps, shown.more })
		end
	end)

	it(
		"split into a big one of its banners and splash and a catch one of its toasts and Nods, the big one first"
			.. " (ANN-R11)",
		function()
			local world = newWorld()
			world.moments:Raise(LEDGER, moment("toast", "New Species", { stamp = "New!" }))
			world.moments:Raise(LEDGER, moment("banner", "Level 12"))
			world.moments:Raise(LEDGER, moment("nod", "New in this zone"))
			world.moments:Raise(LEDGER, moment("banner", "1,000 Catches"))
			world.frame()

			assert.are.same({ "Level 12", "New Species" }, headlines(world))
			local big, catch = world.shown[1], world.shown[2]
			assert.are.same({ "banner", { "1,000 Catches" }, CAST }, { big.rung, big.stamps, big.cast })
			assert.are.same({ "toast", { "New in this zone" }, CAST }, { catch.rung, catch.stamps, catch.cast })
			assert.are.same({ "Level 12", "1,000 Catches" }, ranked(big))
		end
	)

	it("makes one Announcement for a Cast with moments on one side only (ANN-R11)", function()
		local world = newWorld()
		world.moments:Raise(LEDGER, moment("splash", "Legend"))
		world.moments:Raise(LEDGER, moment("banner", "Level 12"))
		world.frame()

		assert.are.same({ "Legend" }, headlines(world))
		assert.are.same({ "Level 12" }, world.shown[1].stamps)
	end)

	it("shows at most 4 stamps, highest ranked first, and the rest as +N (ANN-R11)", function()
		local world = newWorld()
		for i, rung in ipairs({ "toast.high", "toast", "toast", "toast.low", "nod", "nod" }) do
			world.moments:Raise(LEDGER, moment(rung, "Moment " .. i))
		end
		world.frame()

		assert.are.same({ "Moment 1" }, headlines(world))
		assert.are.same({ "Moment 2", "Moment 3", "Moment 4", "Moment 5" }, world.shown[1].stamps)
		assert.are.equal(1, world.shown[1].more)
	end)

	it("merges identical stamp texts into one, a stamp's text being its stamp, else its title (ANN-R11)", function()
		local world = newWorld()
		world.moments:Raise(HUNTS, moment("toast.high", "Hunt completed"))
		world.moments:Raise(LEDGER, moment("toast", "New Species", { stamp = "New!" }))
		world.moments:Raise(HUNTS, moment("toast", "Nightfin found", { stamp = "New!" }))
		world.moments:Raise(LEDGER, moment("nod", "New in this zone"))
		world.frame()

		assert.are.same({ "New!", "New in this zone" }, world.shown[1].stamps)
		assert.are.equal(0, world.shown[1].more)
	end)

	it(
		"sums the coins of each Announcement's own moments apart from the 4 stamps, a Nod's too, so none show"
			.. " twice (ANN-R11, ANN-R23)",
		function()
			local world = newWorld()
			world.moments:Raise(LEDGER, moment("banner", "Level 12", { coins = 50 }))
			for i = 1, 5 do
				world.moments:Raise(HUNTS, moment("toast", "Hunt " .. i, { coins = 10 }))
			end
			world.moments:Raise(LEDGER, moment("nod", "New in this zone", { coins = 2 }))
			world.frame()

			assert.are.same({ "Level 12", "Hunt 1" }, headlines(world))
			assert.are.same({ 50, 52 }, { world.shown[1].coins, world.shown[2].coins })
			assert.are.equal(4, #world.shown[2].stamps)
			assert.are.equal(1, world.shown[2].more)
		end
	)

	it("breaks ties on a rung by order, then the Module's def.order, then the earliest raised (ANN-R2)", function()
		local world = newWorld()
		world.moments:Raise(HUNTS, moment("toast", "Hunts, order 100"))
		world.moments:Raise(LEDGER, moment("toast", "Ledger, raised second"))
		world.moments:Raise(LEDGER, moment("toast", "Ledger, raised third"))
		world.moments:Raise(HUNTS, moment("toast", "Hunts, order 50", { order = 50 }))
		world.moments:Raise(LEDGER, moment("toast.low", "Lower rung", { order = 1 }))
		world.frame()

		assert.are.same({
			"Hunts, order 50",
			"Ledger, raised second",
			"Ledger, raised third",
			"Hunts, order 100",
			"Lower rung",
		}, ranked(world.shown[1]))
		assert.are.equal("Hunts, order 50", world.shown[1].headline.title)
	end)

	it("keeps Core's own copy, so a Module changing its table afterwards changes nothing (ANN-R3)", function()
		local world = newWorld()
		local mine =
			moment("toast", "Size record", { ruler = { old = 300, new = 312, unit = "length", label = "Pagle size" } })

		world.moments:Raise(LEDGER, mine)
		mine.title = "Changed"
		mine.ruler.new = 999
		world.frame()

		assert.are.same({ "Size record" }, headlines(world))
		assert.are.equal(312, world.shown[1].headline.ruler.new)
		assert.are_not.equal(mine, world.shown[1].headline)
	end)
end)

describe("when a moment may be raised", function()
	it("drops one raised in a replay or rebuild apply, reported once per Module per login (ANN-R4, LOG-R75)", function()
		local world = newWorld()

		world.mode = "replay"
		world.moments:Raise(LEDGER, moment("toast", "Replayed"))
		world.mode = "rebuild"
		world.moments:Raise(LEDGER, moment("toast", "Rebuilt"))
		world.moments:Raise(HUNTS, moment("toast", "Rebuilt too"))
		world.mode = nil
		world.frame()

		assert.are.same({}, world.shown)
		assert.are.same({}, world.summarized)
		assert.are.equal(2, #world.reported)
		assert.matches("Ledger", world.reported[1])
		assert.matches("Hunts", world.reported[2])
	end)

	it(
		"keeps a summaryOnly moment from done for the summary, never shown, and drops any other (ANN-R4, ANN-R63)",
		function()
			local world = newWorld()

			world.mode = "done"
			world.moments:Raise(LEDGER, moment("toast", "Reclassified", { summaryOnly = true }))
			world.moments:Raise(LEDGER, moment("toast", "Shown from done"))
			world.mode = nil
			world.frame()

			assert.are.same({}, world.shown)
			assert.are.equal(1, #world.summarized)
			assert.are.equal("Reclassified", world.summarized[1].title)
			assert.are.equal(1, #world.reported)
		end
	)

	it(
		"hands each moment it keeps to the summary when raised, with its Module (ANN-R25, announcements.md › Data)",
		function()
			local world = newWorld()

			world.mode = "live"
			world.moments:Raise(HUNTS, moment("toast.high", "Hunt completed", { coins = 5 }))
			world.mode = nil
			world.moments:Raise(LEDGER, moment("nod", "Logged in", { cast = false }))

			assert.are.equal(2, #world.summarized)
			local first = world.summarized[1]
			assert.are.same(
				{ "Hunts", "Hunts", 20, "toast.high", "Hunt completed", 5, CAST },
				{ first.module, first.moduleTitle, first.moduleOrder, first.rung, first.title, first.coins, first.cast }
			)
		end
	)
end)

describe("while a projection updates", function()
	local LATER = "Player-4618-0A1B2C3D-1791731005-0"
	local SAME_SECOND = "Player-4618-0A1B2C3D-1791731005-1"

	it(
		"Cast moments wait, then flush Cast by Cast, in Cast order, on the frame after the last projection"
			.. " finishes (ANN-R10, ANN-R11)",
		function()
			local world = newWorld()
			world.updating = true

			world.moments:Raise(LEDGER, moment("toast", "Same second", { cast = SAME_SECOND }))
			world.moments:Raise(LEDGER, moment("toast", "Later", { cast = LATER }))
			world.moments:Raise(HUNTS, moment("toast.high", "First", { cast = CAST }))
			world.moments:Raise(LEDGER, moment("toast", "First, merged", { cast = CAST }))
			world.moments:Raise(LEDGER, moment("banner", "Later, level", { cast = LATER }))
			world.frame()
			world.frame()
			assert.are.same({}, world.shown)

			world.idle()
			assert.are.same({}, world.shown)
			world.frame()

			assert.are.same({ "First", "Later, level", "Later", "Same second" }, headlines(world))
			assert.are.same({ "First, merged" }, world.shown[1].stamps)
		end
	)

	it("a moment without a Cast still flushes on the next frame, as its own Announcement (ANN-R12)", function()
		local world = newWorld()
		world.updating = true

		world.moments:Raise(LEDGER, moment("toast", "Skill 150", { cast = false }))
		world.moments:Raise(HUNTS, moment("nod", "Window open", { cast = false }))
		world.moments:Raise(LEDGER, moment("toast", "Held", { cast = CAST }))
		world.frame()

		assert.are.same({ "Skill 150", "Window open" }, headlines(world))
		assert.is_nil(world.shown[1].cast)
		assert.are.same({}, world.shown[1].stamps)
	end)
end)

describe("ns.MomentProblem", function()
	it("refuses an unknown rung, a missing kind or a missing title, and takes every rung (ANN-R1)", function()
		assert.matches("not a rung", ns.MomentProblem({ rung = "huge", kind = "k", title = "t" }))
		assert.matches("kind", ns.MomentProblem({ rung = "toast", title = "t" }))
		assert.matches("title", ns.MomentProblem({ rung = "toast", kind = "k" }))
		assert.matches("table", ns.MomentProblem("toast"))
		for _, rung in ipairs({ "nod", "toast.low", "toast", "toast.high", "banner", "splash" }) do
			assert.is_nil(ns.MomentProblem({ rung = rung, kind = "k", title = "t" }))
		end
	end)
end)
