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

describe("ns.CatchNodMoment", function()
	it('reads "{item name} · {band} · {length}" in the Angler\'s unit, a silent Nod of the Cast (ANN-R13)', function()
		local cast = caughtCast({ { 6289, { length = 342, band = 2 } } })

		local nod = ns.CatchNodMoment(cast, itemName, "cm") --[[@as PagleMoment]]

		assert.are.same(
			{ rung = "nod", kind = "catch", title = "Raw Longjaw Mud Snapper · Decent · 34.2 cm", icon = 6289 },
			{ rung = nod.rung, kind = nod.kind, title = nod.title, icon = nod.icon }
		)
		assert.are.same({ CAST, false }, { nod.cast, nod.sound })
		assert.is_nil(nod.text)
		assert.is_nil(ns.MomentProblem(nod))
		local monster = caughtCast({ { 6289, { length = 342, band = 5 } } })
		assert.are.equal(
			"Raw Longjaw Mud Snapper · Monster · 13.5 in",
			(ns.CatchNodMoment(monster, itemName, "in") --[[@as PagleMoment]]).title
		)
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
			assert.are.equal(
				"Raw Longjaw Mud Snapper · Tiddler · 21.0 cm",
				(ns.CatchNodMoment(sized, itemName, "cm") --[[@as PagleMoment]]).title
			)

			local junk = ns.CatchNodMoment(caughtCast({ { 0 }, { 6358 } }), itemName, "cm") --[[@as PagleMoment]]
			assert.are.same({ "Oily Blackmouth", 6358 }, { junk.title, junk.icon })
		end
	)

	it('reads "Item {itemID}" for a name the client hasn\'t cached (ANN-R13)', function()
		local nod = ns.CatchNodMoment(caughtCast({ { 99001 } }), itemName, "cm") --[[@as PagleMoment]]
		assert.are.equal("Item 99001", nod.title)
	end)

	it("is nil for a got-away Cast and for one whose every item is item 0 (ANN-R13, LOG-R8)", function()
		assert.is_nil(ns.CatchNodMoment(caughtCast({}, "gotAway"), itemName, "cm"))
		assert.is_nil(ns.CatchNodMoment(caughtCast({ { 0 }, { 0 } }), itemName, "cm"))
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
		'names its Catch\'s variety, "{item name} · {variety name} · {band} · {length}", the name a segment of its'
			.. " own with its rarity, and carries the variety's art (VAR-R26)",
		function()
			local cast = caughtCast({ { 6359, { length = 342, band = 2 }, CORAL } })

			local nod = ns.CatchNodMoment(cast, itemName, "cm", varieties) --[[@as PagleMoment]]

			assert.are.equal("Firefin Snapper · Coral · Decent · 34.2 cm", nod.title)
			assert.are.same(
				{ name = "Coral", rarity = "common", before = "Firefin Snapper ·", after = "· Decent · 34.2 cm" },
				nod.variety
			)
			assert.are.same(CORAL_ART, nod.art)
			-- A copy: Core's lists are shared (CORE-R18).
			assert.are_not.equal(CORAL_ART, nod.art)
			assert.are.same({ 6359, "nod", false }, { nod.icon, nod.rung, nod.sound })
			assert.is_nil(ns.MomentProblem(nod))
		end
	)

	it("names a variety with no art by name alone, keeping the item's icon (VAR-R26)", function()
		local cast = caughtCast({ { 6359, { length = 342, band = 2 }, { id = "6359.flame-finned", index = 1 } } })
		cast.items[1].variety.rarity = "common"

		local nod = ns.CatchNodMoment(cast, itemName, "cm", varieties) --[[@as PagleMoment]]

		assert.are.same({ "Firefin Snapper · Flame-finned · Decent · 34.2 cm", "Flame-finned", nil }, {
			nod.title,
			nod.variety.name,
			nod.art,
		})
	end)

	it("reads as before when Core can't name the variety: no list, no entry or no name in lore (VAR-R26)", function()
		local unnamed = {
			{ id = "6359.flame-finned", index = 1, rarity = "common" },
			{ id = "6359.coral", index = 2, rarity = "common", art = CORAL_ART },
		}
		for _, list in ipairs({ false, {}, unnamed }) do
			local cast = caughtCast({ { 6359, { length = 342, band = 2 }, CORAL } })
			local nod = ns.CatchNodMoment(cast, itemName, "cm", function()
				return list or nil
			end) --[[@as PagleMoment]]

			assert.are.same({ "Firefin Snapper · Decent · 34.2 cm" }, { nod.title, nod.variety, nod.art })
		end
		local cast = caughtCast({ { 6359, { length = 342, band = 2 }, CORAL } })
		local plain = ns.CatchNodMoment(cast, itemName, "cm") --[[@as PagleMoment]]
		assert.are.same({ "Firefin Snapper · Decent · 34.2 cm" }, { plain.title, plain.variety, plain.art })
	end)
end)

describe("the catch Nod", function()
	-- Core's catch Nod for CAST, as ns.CatchNodMoment makes it.
	local function catchNod()
		return ns.CatchNodMoment(caughtCast({ { 6358 } }), itemName, "cm") --[[@as PagleMoment]]
	end

	it(
		"shows alone as a Nod of its Cast on the next frame, and never reaches the summary (ANN-R13, ANN-R25)",
		function()
			local world = newWorld()

			world.moments:RaiseCatchNod(catchNod())
			assert.are.same({}, world.shown)
			world.frame()

			assert.are.same({ "Oily Blackmouth" }, headlines(world))
			assert.are.same({ "nod", CAST, {}, 0 }, {
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

				world.moments:RaiseCatchNod(catchNod())
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

			world.moments:RaiseCatchNod(catchNod())
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
