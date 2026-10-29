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
		toastStyle = function()
			return world.style
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

	it(
		"sums the tickets of each Announcement's own moments apart from the 4 stamps, a Nod's too, so none show"
			.. " twice (ANN-R11, ANN-R23, REF-R7)",
		function()
			local world = newWorld()
			world.moments:Raise(LEDGER, moment("banner", "Level 12", { tickets = 1 }))
			for i = 1, 5 do
				world.moments:Raise(HUNTS, moment("toast", "Hunt " .. i, { tickets = 2 }))
			end
			world.moments:Raise(LEDGER, moment("nod", "New in this zone", { tickets = 3 }))
			world.frame()

			assert.are.same({ "Level 12", "Hunt 1" }, headlines(world))
			assert.are.same({ 1, 13 }, { world.shown[1].tickets, world.shown[2].tickets })
			assert.are.equal(4, #world.shown[2].stamps)
			assert.are.equal(1, world.shown[2].more)
		end
	)

	it(
		"leaves a moment with no tickets as it was: no `tickets` on the Announcement, the same stamps (REF-R7)",
		function()
			local world = newWorld()
			world.moments:Raise(HUNTS, moment("toast", "Hunt completed", { coins = 5 }))
			world.moments:Raise(HUNTS, moment("nod", "Tier 1", { tickets = 0 }))
			world.frame()

			assert.is_nil(world.shown[1].tickets)
			assert.are.same({ "Tier 1" }, world.shown[1].stamps)
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
			moment("toast", "Size record", { ruler = { old = 300, new = 312, unit = "length", label = "length" } })

		world.moments:Raise(LEDGER, mine)
		mine.title = "Changed"
		mine.ruler.new = 999
		world.frame()

		assert.are.same({ "Size record" }, headlines(world))
		assert.are.equal(312, world.shown[1].headline.ruler.new)
		assert.are_not.equal(mine, world.shown[1].headline)
	end)

	it("copies a moment's art too (ANN-R3, VAR-R25)", function()
		local world = newWorld()
		local mine =
			moment("toast", "Rare variety", { art = { texture = 1, left = 0, right = 0.1, top = 0, bottom = 0.05 } })

		world.moments:Raise(LEDGER, mine)
		mine.art.right = 1
		world.frame()

		assert.are.same({ texture = 1, left = 0, right = 0.1, top = 0, bottom = 0.05 }, world.shown[1].headline.art)
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

-- A Cast that beat a size record and found a variety for the first time (#424), the moments the Ledger raises for it
-- (LED-R97): a size record beside a Common variety's `newVariety`, both `toast.low`, the record first.
local COLOUR_ART = { texture = "Varieties1", left = 0.09375, right = 0.1875, top = 0, bottom = 0.046875 }
local function recordAndVariety(rarity)
	return moment("toast.low", "Size record", {
		kind = "sizeRecord",
		order = 100,
		text = "Raw Bristle Whisker Catfish",
		stamp = "Record",
		icon = 6291,
		ruler = { old = 303, new = 304, unit = "length", label = "Tiddler" },
	}),
		moment("toast.low", "New variety", {
			kind = "newVariety",
			order = 120,
			text = "Coral",
			stamp = "New variety",
			icon = 6291,
			art = COLOUR_ART,
			variety = { name = "Coral", rarity = rarity },
		})
end

describe("a Cast's size record and new variety (#424, ANN-R11, VAR-R25)", function()
	it("make one toast headlined by the record, the variety riding on it as a stamp with its art", function()
		local world = newWorld()

		local record, variety = recordAndVariety("common")
		world.moments:Raise(LEDGER, record)
		world.moments:Raise(LEDGER, variety)
		world.frame()

		-- The record outranks the variety on their shared rung (ANN-R2), so the variety's art isn't the headline's:
		-- Core takes it from the moment riding as a stamp.
		local shown = world.shown[1]
		assert.are.same({ "sizeRecord", { "New variety" } }, { shown.headline.kind, shown.stamps })
		assert.is_nil(shown.headline.art)
		assert.are.same(COLOUR_ART, shown.moments[2].art)
		assert.are.same({ name = "Coral", rarity = "common" }, shown.moments[2].variety)
	end)

	it("keep a Module's variety apart from the Module's table once raised (ANN-R3)", function()
		local world = newWorld()
		local record, variety = recordAndVariety("rare")

		world.moments:Raise(LEDGER, record)
		world.moments:Raise(LEDGER, variety)
		variety.variety.name = "Changed"
		world.frame()

		assert.are.equal("Coral", world.shown[1].moments[2].variety.name)
	end)
end)

-- A first-catch variety's own toast (#422, VAR-R28): the moment the Ledger raises for a Common, Uncommon or Rare one.
local function ownVariety(rung, kind, order, title, rarity)
	return moment(rung, title, {
		kind = kind,
		order = order,
		text = "Coral",
		stamp = rarity == "common" and "New variety" or nil,
		icon = 6291,
		art = COLOUR_ART,
		ownStamp = true,
		kicker = "Decent · 34.2 cm",
		variety = { name = "Coral", rarity = rarity, fish = "Raw Bristle Whisker Catfish" },
	})
end

describe("a new variety's own stamp (#422, ANN-R11, VAR-R28)", function()
	local function make(...)
		return ns.MakeAnnouncement({ ... }) --[[@as PagleAnnouncement]]
	end

	it("is the headline's first stamp, its stamp text or else its title", function()
		local common = make(ownVariety("toast.low", "newVariety", 120, "New variety", "common"))
		local rare = make(ownVariety("toast", "rareVariety", 105, "Rare variety", "rare"))

		assert.are.same({ { "New variety" }, { "Rare variety" } }, { common.stamps, rare.stamps })
		assert.are.equal(0, common.more)
	end)

	it("comes before the stamps of the moments riding on it, and merges with an identical one", function()
		local trophy = moment("toast.low", "Trophy family", { kind = "familyStar", order = 130, stamp = "★★" })
		local variety = ownVariety("toast.low", "newVariety", 120, "New variety", "common")
		local twin = moment("toast.low", "New variety", { kind = "other", order = 125, stamp = "New variety" })

		local announcement = make(trophy, variety, twin)

		assert.are.same({ "New variety", "★★" }, announcement.stamps)
		assert.are.equal(variety, announcement.headline)
	end)

	it("counts toward the 4 stamps shown, the fifth distinct one beyond as +N", function()
		local variety = ownVariety("toast.low", "newVariety", 120, "New variety", "common")
		local riding = {}
		for i = 1, 4 do
			riding[i] = moment("toast.low", "Rider " .. i, { kind = "rider", order = 130 + i, stamp = "R" .. i })
		end

		local announcement = make(variety, unpack(riding))

		assert.are.same({ { "New variety", "R1", "R2", "R3" }, 1 }, { announcement.stamps, announcement.more })
	end)

	it("is not shown when the variety rides on another headline, whose stamps are as they were", function()
		local record = moment("toast.low", "Size record", { kind = "sizeRecord", order = 100, stamp = "Record" })
		local variety = ownVariety("toast.low", "newVariety", 120, "New variety", "common")
		local rare = ownVariety("toast", "rareVariety", 105, "Rare variety", "rare")

		assert.are.same({ "New variety" }, make(record, variety).stamps)
		assert.are.same({ "Rare variety" }, make(moment("toast", "New Species", { order = 100 }), rare).stamps)
	end)

	it("is for a moment that asks for it: other headlines, an Epic variety's banner among them, have none", function()
		local epic = moment(
			"banner",
			"Epic variety",
			{ kind = "epicVariety", order = 97, variety = { name = "X", rarity = "epic" } }
		)
		local species = moment("toast", "New Species", { kind = "newSpecies", stamp = "New!" })

		assert.are.same({ {}, {} }, { make(epic).stamps, make(species).stamps })
	end)

	it("keeps the moment's title: the Session summary and the cards read it, whatever the toast's kicker", function()
		local variety = ownVariety("toast.low", "newVariety", 120, "New variety", "common")
		local world = newWorld()

		world.moments:Raise(LEDGER, variety)
		world.frame()

		assert.are.same({ "New variety", "Decent · 34.2 cm", true }, {
			world.summarized[1].title,
			world.shown[1].headline.kicker,
			world.shown[1].headline.ownStamp,
		})
		assert.are.equal("Raw Bristle Whisker Catfish", world.shown[1].headline.variety.fish)
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

	it("takes a firstNote that is a text, and refuses any other (ONB-R53, ONB-R93)", function()
		assert.is_nil(ns.MomentProblem({ rung = "toast", kind = "k", title = "t", firstNote = "A new Species." }))
		assert.matches("firstNote", ns.MomentProblem({ rung = "toast", kind = "k", title = "t", firstNote = 3 }))
		assert.matches("firstNote", ns.MomentProblem({ rung = "toast", kind = "k", title = "t", firstNote = "" }))
	end)

	it("takes an art that is a texture and its rectangle, and refuses any other (VAR-R25)", function()
		local art = { texture = "Interface\\Varieties1", left = 0, right = 0.09375, top = 0, bottom = 0.046875 }
		assert.is_nil(ns.MomentProblem({ rung = "toast", kind = "k", title = "t", art = art }))
		assert.matches("art", ns.MomentProblem({ rung = "toast", kind = "k", title = "t", art = "Varieties1" }))
		assert.matches("art", ns.MomentProblem({ rung = "toast", kind = "k", title = "t", art = { texture = 1 } }))
	end)

	it("takes a variety that is a name and a rarity, and refuses any other (VAR-R25, VAR-R26)", function()
		local function problem(variety)
			return ns.MomentProblem({ rung = "toast", kind = "k", title = "t", variety = variety })
		end
		assert.is_nil(problem({ name = "Coral", rarity = "common" }))
		assert.matches("variety", problem("Coral"))
		assert.matches("variety", problem({ name = "Coral" }))
		assert.matches("variety", problem({ name = "", rarity = "rare" }))
		assert.matches("variety", problem({ name = "Coral", rarity = 3 }))
	end)
end)

-- A caught Cast record (LOG-R65) holding `items`, each `{ itemID, size?, variety? }`, as the Catch log hands it out.
local function caughtCast(items, outcome)
	local cast = { id = CAST, kind = "cast", outcome = outcome or "caught", items = {} }
	for n, item in ipairs(items) do
		cast.items[n] =
			{ n = n, itemID = item[1], quantity = 1, catchId = CAST .. ":" .. n, size = item[2], variety = item[3] }
	end
	return cast
end

-- The client's names for the items these specs catch.
local NAMES = {
	[6358] = "Oily Blackmouth",
	[6289] = "Raw Longjaw Mud Snapper",
	[6299] = "Sickly Looking Fish",
	[6359] = "Firefin Snapper",
}
local function itemName(itemID)
	return NAMES[itemID]
end

describe("ns.CatchToastMoment", function()
	it(
		"is a toast.low of the Cast, its kicker \"{band} · {length}\" in the Angler's unit over the item's name"
			.. " (ANN-R13)",
		function()
			local cast = caughtCast({ { 6289, { length = 342, band = 2 } } })

			local toast = ns.CatchToastMoment(cast, itemName, "cm") --[[@as PagleMoment]]

			assert.are.same(
				{ rung = "toast.low", kind = "catch", title = "Decent · 34.2 cm", text = "Raw Longjaw Mud Snapper" },
				{ rung = toast.rung, kind = toast.kind, title = toast.title, text = toast.text }
			)
			assert.are.same({ 6289, CAST }, { toast.icon, toast.cast })
			-- It plays the toast sound (ANN-R70): no `sound = false`.
			assert.is_nil(toast.sound)
			assert.is_nil(ns.MomentProblem(toast))
			local monster = caughtCast({ { 6289, { length = 342, band = 5 } } })
			assert.are.equal(
				"Monster · 13.5 in",
				(ns.CatchToastMoment(monster, itemName, "in") --[[@as PagleMoment]]).title
			)
		end
	)

	it(
		'keeps the old Nod\'s line, "{item name} · {band} · {length}", for the step down (ANN-R13, ANN-R31)',
		function()
			local sized = caughtCast({ { 6289, { length = 342, band = 2 } } })
			local nodLine = (ns.CatchToastMoment(sized, itemName, "cm") --[[@as PagleMoment]]).nodLine
			assert.are.equal("Raw Longjaw Mud Snapper · Decent · 34.2 cm", nodLine)

			local junk = ns.CatchToastMoment(caughtCast({ { 6358 } }), itemName, "cm") --[[@as PagleMoment]]
			assert.are.equal("Oily Blackmouth", junk.nodLine)
		end
	)

	it('reads "Caught" for its kicker when the Catch has no size (ANN-R13)', function()
		local toast = ns.CatchToastMoment(caughtCast({ { 6358 } }), itemName, "cm") --[[@as PagleMoment]]

		assert.are.same({ "Caught", "Oily Blackmouth", 6358 }, { toast.title, toast.text, toast.icon })
		assert.is_nil(ns.MomentProblem(toast))
	end)

	it(
		"names the first Catch with a Simulated Size, else the first that isn't item 0, by name alone (ANN-R13)",
		function()
			local sized = caughtCast({
				{ 0 },
				{ 6358 },
				{ 6289, { length = 210, band = 1 } },
				{ 6299, { length = 90, band = 3 } },
			})
			local toast = ns.CatchToastMoment(sized, itemName, "cm") --[[@as PagleMoment]]
			assert.are.same({ "Tiddler · 21.0 cm", "Raw Longjaw Mud Snapper" }, { toast.title, toast.text })

			local junk = ns.CatchToastMoment(caughtCast({ { 0 }, { 6358 } }), itemName, "cm") --[[@as PagleMoment]]
			assert.are.same({ "Oily Blackmouth", 6358 }, { junk.text, junk.icon })
		end
	)

	it('reads "Item {itemID}" for a name the client hasn\'t cached (ANN-R13)', function()
		local toast = ns.CatchToastMoment(caughtCast({ { 99001 } }), itemName, "cm") --[[@as PagleMoment]]
		assert.are.same({ "Item 99001", "Item 99001" }, { toast.text, toast.nodLine })
	end)

	it("is nil for a got-away Cast and for one whose every item is item 0 (ANN-R13, LOG-R8)", function()
		assert.is_nil(ns.CatchToastMoment(caughtCast({}, "gotAway"), itemName, "cm"))
		assert.is_nil(ns.CatchToastMoment(caughtCast({ { 0 }, { 0 } }), itemName, "cm"))
	end)

	-- Firefin Snapper's second variety, as Core lists it (VAR-R11), its art 192 × 96 at (192, 0) on a 2048 atlas.
	local CORAL_ART = { texture = "Varieties1", left = 192 / 2048, right = 384 / 2048, top = 0, bottom = 96 / 2048 }
	local FIREFIN = {
		{ id = "6359.flame-finned", key = "flame-finned", index = 1, rarity = "common", name = "Flame-finned" },
		{ id = "6359.coral", key = "coral", index = 2, rarity = "common", name = "Coral", art = CORAL_ART },
	}
	local function varieties(speciesID)
		return speciesID == 6359 and FIREFIN or nil
	end
	local CORAL = { id = "6359.coral", index = 2, rarity = "common" }

	it(
		"names its Catch's variety after the fish's name on its text and carries the Nod's line cut about the name, but"
			.. " no art: its medallion keeps the item's icon (VAR-R26)",
		function()
			local cast = caughtCast({ { 6359, { length = 342, band = 2 }, CORAL } })

			local toast = ns.CatchToastMoment(cast, itemName, "cm", varieties) --[[@as PagleMoment]]

			assert.are.same({ "Decent · 34.2 cm", "Firefin Snapper" }, { toast.title, toast.text })
			assert.are.equal("Firefin Snapper · Coral · Decent · 34.2 cm", toast.nodLine)
			assert.are.same(
				{ name = "Coral", rarity = "common", before = "Firefin Snapper ·", after = "· Decent · 34.2 cm" },
				toast.variety
			)
			-- The variety's art fills a medallion only on its own moment (VAR-R25, VAR-R26): the Catch's item shows here.
			assert.is_nil(toast.art)
			assert.are.same({ 6359, "toast.low", nil }, { toast.icon, toast.rung, toast.sound })
			assert.is_nil(ns.MomentProblem(toast))
		end
	)

	it("names a variety with no art by name alone, as it does one with art (VAR-R26)", function()
		local cast = caughtCast({ { 6359, { length = 342, band = 2 }, { id = "6359.flame-finned", index = 1 } } })
		cast.items[1].variety.rarity = "common"

		local toast = ns.CatchToastMoment(cast, itemName, "cm", varieties) --[[@as PagleMoment]]

		assert.are.same({ "Firefin Snapper · Flame-finned · Decent · 34.2 cm", "Flame-finned", nil }, {
			toast.nodLine,
			toast.variety.name,
			toast.art,
		})
	end)

	it("reads as before when Core can't name the variety: no list, no entry or no name in lore (VAR-R26)", function()
		local unnamed = {
			{ id = "6359.flame-finned", index = 1, rarity = "common" },
			{ id = "6359.coral", index = 2, rarity = "common", art = CORAL_ART },
		}
		for _, list in ipairs({ false, {}, unnamed }) do
			local cast = caughtCast({ { 6359, { length = 342, band = 2 }, CORAL } })
			local toast = ns.CatchToastMoment(cast, itemName, "cm", function()
				return list or nil
			end) --[[@as PagleMoment]]

			assert.are.same({ "Firefin Snapper · Decent · 34.2 cm" }, { toast.nodLine, toast.variety, toast.art })
		end
		local cast = caughtCast({ { 6359, { length = 342, band = 2 }, CORAL } })
		local plain = ns.CatchToastMoment(cast, itemName, "cm") --[[@as PagleMoment]]
		assert.are.same({ "Firefin Snapper · Decent · 34.2 cm" }, { plain.nodLine, plain.variety, plain.art })
	end)

	it("names only a variety caught before this Cast, never the first (VAR-R27)", function()
		local cast = caughtCast({ { 6359, { length = 342, band = 2 }, CORAL } })

		local first = ns.CatchToastMoment(cast, itemName, "cm", varieties, function()
			return false
		end) --[[@as PagleMoment]]
		local again = ns.CatchToastMoment(cast, itemName, "cm", varieties, function(variety, castId)
			return variety.id == "6359.coral" and castId == CAST
		end) --[[@as PagleMoment]]

		assert.are.same({ "Decent · 34.2 cm", "Firefin Snapper", nil, nil }, {
			first.title,
			first.text,
			first.variety,
			first.art,
		})
		assert.are.equal("Coral", again.variety.name)
	end)
end)

describe("the catch toast", function()
	-- Core's catch toast for CAST, as ns.CatchToastMoment makes it.
	local function catchToast()
		return ns.CatchToastMoment(caughtCast({ { 6358 } }), itemName, "cm") --[[@as PagleMoment]]
	end

	it(
		"shows alone as a toast.low of its Cast on the next frame, and never reaches the summary (ANN-R13, ANN-R25)",
		function()
			local world = newWorld()

			world.moments:RaiseCatchToast(catchToast())
			assert.are.same({}, world.shown)
			world.frame()

			assert.are.same({ "Caught" }, headlines(world))
			assert.are.same({ "toast.low", CAST, {}, 0 }, {
				world.shown[1].rung,
				world.shown[1].cast,
				world.shown[1].stamps,
				world.shown[1].more,
			})
			assert.are.same({}, world.summarized)
		end
	)

	it(
		"is dropped when a Module raises any moment for the Cast, on either side, never riding as a stamp (ANN-R13,"
			.. " ANN-R11)",
		function()
			for _, rung in ipairs({ "nod", "toast.low", "banner" }) do
				local world = newWorld()

				world.moments:RaiseCatchToast(catchToast())
				world.moments:Raise(LEDGER, moment(rung, "New in this zone"))
				world.frame()

				assert.are.same({ "New in this zone" }, headlines(world))
				assert.are.same({ {}, 0, { "New in this zone" } }, {
					world.shown[1].stamps,
					world.shown[1].more,
					ranked(world.shown[1]),
				})
			end
		end
	)

	it(
		"is held with the Cast's other moments while a projection updates, and still replaced (ANN-R10, ANN-R13)",
		function()
			local world = newWorld()
			world.updating = true

			world.moments:RaiseCatchToast(catchToast())
			world.frame()
			assert.are.same({}, world.shown)
			world.moments:Raise(LEDGER, moment("toast", "New Species"))
			world.idle()
			world.frame()

			assert.are.same({ "New Species" }, headlines(world))
			assert.are.same({ "New Species" }, ranked(world.shown[1]))
		end
	)
end)

describe("an Epic variety's moment while the Extravaganza Gala is equipped (ANN-R85, VAR-R25)", function()
	local GALA = "ledger.toaststyle.gala"
	-- The Ledger's banner "Epic variety" (LED-R97), and a variety of another rarity as a banner would have it.
	local function variety(rarity, rung)
		return moment(rung or "banner", "Epic variety", {
			kind = "epicVariety",
			text = "Phoenix-fin",
			variety = { name = "Phoenix-fin", rarity = rarity },
		})
	end

	it("is a toast.high, only for an Epic variety's banner and only with the Gala", function()
		assert.are.equal("toast.high", ns.MomentRung(variety("epic"), GALA))
		assert.are.equal("banner", ns.MomentRung(variety("epic"), "core.toaststyle.page"))
		assert.are.equal("banner", ns.MomentRung(variety("epic"), nil))
		assert.are.equal("toast", ns.MomentRung(variety("rare", "toast"), GALA))
		assert.are.equal("banner", ns.MomentRung(moment("banner", "Every colour of Pike"), GALA))
		assert.are.equal("banner", ns.MomentRung(moment("banner", "Angler Level 12"), GALA))
		assert.are.equal(
			"splash",
			ns.MomentRung(moment("splash", "A Legend", { variety = { name = "x", rarity = "epic" } }), GALA)
		)
	end)

	it("is raised as a toast.high, to the display and the Session summary alike, and never as a banner", function()
		local world = newWorld()
		world.style = GALA

		world.moments:Raise(LEDGER, variety("epic"))
		world.frame()

		assert.are.equal("toast.high", world.shown[1].rung)
		assert.are.equal("toast.high", world.shown[1].headline.rung)
		assert.are.equal("toast.high", world.summarized[1].rung)
		assert.are.equal(1, #world.shown)
	end)

	it("is a banner with any other style equipped, or none", function()
		for _, style in ipairs({ "core.toaststyle.page", "hunts.toaststyle.nightfin", false }) do
			local world = newWorld()
			world.style = style or nil

			world.moments:Raise(LEDGER, variety("epic"))
			world.frame()

			assert.are.equal("banner", world.shown[1].rung)
			assert.are.equal("banner", world.summarized[1].rung)
		end
	end)

	it("joins the Cast's toasts on the catch side, the banner side of the Cast left to its own moments", function()
		local world = newWorld()
		world.style = GALA

		world.moments:Raise(LEDGER, variety("epic"))
		world.moments:Raise(LEDGER, moment("toast", "New Species"))
		world.moments:Raise(LEDGER, moment("banner", "Angler Level 12"))
		world.frame()

		-- The level banner is the Cast's big one; the Epic variety headlines the toasts, over the New Species.
		assert.are.same({ "Angler Level 12", "Epic variety" }, headlines(world))
		assert.are.same({ "Epic variety", "New Species" }, ranked(world.shown[2]))
	end)
end)
