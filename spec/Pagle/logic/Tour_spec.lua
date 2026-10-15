-- `/pagle dev tour` (CORE-R65–R68): the screenshot tour over every registered tour stop, on FakePagle's wiring, which
-- is Core's (logic/Wiring.lua's ns.WireDev). A stop's show and hide here note what they do in `seen`, and the fake's
-- screenshot notes each shot there too, so a spec reads the order of events.

-- A FakePagle logged in with dev on and two Modules registered: the Ledger (order 10) and QoL (order 50). Returns the
-- fake, the two handles and `seen`, where every show, hide and screenshot is noted in order.
local function touring()
	local fake = newFakePagle()
	local seen = {}
	fake.tourShots = seen
	local ledger = fake.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
	local qol = fake.Pagle.RegisterModule({ name = "QoL", title = "QoL", order = 50 })
	fake.login()
	fake.enterWorld()
	fake.slash("dev on")
	fake.printed = {}
	return fake, ledger, qol, seen
end

-- A stop's show and hide, noting "show <name>" and "hide <name>" in `seen`.
local function noting(seen, name)
	return function()
		seen[#seen + 1] = "show " .. name
	end, function()
		seen[#seen + 1] = "hide " .. name
	end
end

-- Registers stop `id` on handle `M`, noting its show and hide under `name`.
local function stop(M, seen, id, name)
	local show, hide = noting(seen, name)
	M:RegisterTourStop(id, "the " .. name, show, hide)
end

-- Registers one of Core's own stops, as Core's adapter does, noting under `name`.
local function coreStop(fake, seen, id, name)
	local show, hide = noting(seen, name)
	assert.is_nil(fake.ns.tourStops:Add(fake.ns.TOUR_CORE, id, "the " .. name, show, hide))
end

-- Runs the whole tour now: long enough for every stop's waits.
local function finish(fake)
	fake.wait(60)
end

describe("M:RegisterTourStop (CORE-R65)", function()
	it("raises an error at the Module's call for a bad ID, a duplicate, no label or no show or hide", function()
		local fake, ledger, _, seen = touring()
		stop(ledger, seen, "journal.home", "home")

		local function register(...)
			local args = { ... }
			return function()
				ledger:RegisterTourStop(unpack(args, 1, 4))
			end
		end
		local function noop() end
		assert.has_error(
			register("journal.home", "again", noop, noop),
			"Ledger's tour stop journal.home is already registered"
		)
		assert.has_error(register("has space", "x", noop, noop), "Ledger's tour stop ID has space isn't [%w_.]+")
		assert.has_error(register("", "x", noop, noop), "Ledger's tour stop ID  isn't [%w_.]+")
		assert.has_error(register("a", nil, noop, noop), "Ledger's tour stop a has no label")
		assert.has_error(register("a", "x", nil, noop), "Ledger's tour stop a needs a show and a hide function")
		assert.has_error(register("a", "x", noop, "no"), "Ledger's tour stop a needs a show and a hide function")
		assert.has_error(function()
			fake.ns.ModuleHandle.RegisterTourStop({}, "a", "x", noop, noop)
		end, "RegisterTourStop is a Module handle method: call M:RegisterTourStop(id, label, show, hide)")
	end)

	it("lets two Modules use one ID: each stop is named after its Module", function()
		local fake, ledger, qol, seen = touring()
		stop(ledger, seen, "settings", "ledger settings")
		stop(qol, seen, "settings", "qol settings")

		fake.slash("dev tour list")

		assert.are.same({
			"Pagle dev: 2 tour stops:",
			"  ledger.settings: the ledger settings",
			"  qol.settings: the qol settings",
		}, fake.printed)
	end)
end)

describe("/pagle dev tour (CORE-R66)", function()
	it("shows each stop in Module order, Core first, in register order, shooting it before it hides", function()
		local fake, ledger, qol, seen = touring()
		stop(qol, seen, "settings", "qol")
		stop(ledger, seen, "journal.home", "home")
		coreStop(fake, seen, "shop", "shop")
		stop(ledger, seen, "journal.zone", "zone")

		fake.slash("dev tour")
		finish(fake)

		assert.are.same({
			"show shop",
			"shot",
			"hide shop",
			"show home",
			"shot",
			"hide home",
			"show zone",
			"shot",
			"hide zone",
			"show qol",
			"shot",
			"hide qol",
		}, seen)
	end)

	it("prints the start time, one line per stop as it shows, and the end time", function()
		local fake, ledger, _, seen = touring()
		stop(ledger, seen, "journal.home", "home")
		stop(ledger, seen, "journal.zone", "zone")

		fake.slash("dev tour")
		finish(fake)

		assert.are.same({
			"Pagle dev: touring 2 stops from 12:00:00; a screenshot of each goes to the Screenshots folder.",
			"Pagle dev: tour 1/2: ledger.journal.home",
			"Pagle dev: tour 2/2: ledger.journal.zone",
			"Pagle dev: the tour is done at 12:00:00.",
		}, fake.printed)
	end)

	it("waits 2.8 s on each stop before its screenshot, then hides it", function()
		local fake, ledger, _, seen = touring()
		stop(ledger, seen, "journal.home", "home")

		fake.slash("dev tour")
		assert.are.same({ "show home" }, seen)
		fake.wait(2.7)
		assert.are.same({ "show home" }, seen)
		fake.wait(0.1)
		assert.are.same({ "show home", "shot" }, seen)
		finish(fake)
		assert.are.same({ "show home", "shot", "hide home" }, seen)
	end)

	it("runs one Module's stops for `tour <module>`, case-insensitively; core names Core's own", function()
		local fake, ledger, qol, seen = touring()
		stop(ledger, seen, "journal.home", "home")
		stop(qol, seen, "settings", "qol")
		coreStop(fake, seen, "shop", "shop")

		fake.slash("dev tour QoL")
		finish(fake)
		fake.slash("dev tour core")
		finish(fake)

		assert.are.same({ "show qol", "shot", "hide qol", "show shop", "shot", "hide shop" }, seen)
		assert.are.equal("Pagle dev: tour 1/1: qol.settings", fake.printed[2])
	end)

	it("names the Modules with stops for a Module that has none", function()
		local fake, ledger, _, seen = touring()
		stop(ledger, seen, "journal.home", "home")
		coreStop(fake, seen, "shop", "shop")

		fake.slash("dev tour stats")

		assert.are.same({ "Pagle dev: no tour stops for stats; stops are registered for core, ledger." }, fake.printed)
		assert.are.same({}, seen)
	end)

	it("lists the stops, or one Module's, with their labels, showing nothing (CORE-R68)", function()
		local fake, ledger, _, seen = touring()
		stop(ledger, seen, "journal.home", "home")
		coreStop(fake, seen, "shop", "shop")

		fake.slash("dev tour list")
		fake.slash("dev tour list ledger")

		assert.are.same({
			"Pagle dev: 2 tour stops:",
			"  core.shop: the shop",
			"  ledger.journal.home: the home",
			"Pagle dev: 1 tour stop:",
			"  ledger.journal.home: the home",
		}, fake.printed)
		assert.are.same({}, seen)
	end)

	it("carries on past a stop whose show or hide fails, reporting the error", function()
		local fake, ledger, _, seen = touring()
		ledger:RegisterTourStop("broken", "broken", function()
			error("no frame")
		end, function()
			error("no frame either")
		end)
		stop(ledger, seen, "journal.home", "home")

		fake.slash("dev tour")
		finish(fake)

		assert.are.same({ "shot", "show home", "shot", "hide home" }, seen)
		assert.are.equal(2, #fake.reported)
		fake.reported = {}
	end)

	it("is a dev command: off, it prints how to turn dev on and tours nothing", function()
		local fake, ledger, _, seen = touring()
		stop(ledger, seen, "journal.home", "home")
		fake.slash("dev off")

		fake.slash("dev tour")
		finish(fake)

		assert.are.same({}, seen)
	end)
end)

describe("/pagle dev tour while restricted (CORE-R67)", function()
	it("refuses to start while restricted, showing nothing", function()
		local fake, ledger, _, seen = touring()
		stop(ledger, seen, "journal.home", "home")
		fake.setRestricted(true)

		fake.slash("dev tour")
		finish(fake)

		assert.are.same({}, seen)
		assert.are.same({ "Pagle dev: the tour waits until combat ends; try again then." }, fake.printed)
	end)

	it("ends at a restriction: the stop on screen hides unshot, and no other shows", function()
		local fake, ledger, _, seen = touring()
		stop(ledger, seen, "journal.home", "home")
		stop(ledger, seen, "journal.zone", "zone")

		fake.slash("dev tour")
		fake.wait(1)
		fake.setRestricted(true)
		finish(fake)

		assert.are.same({ "show home", "hide home" }, seen)
		assert.are.equal("Pagle dev: the tour stopped at 1/2: combat started.", fake.printed[#fake.printed])
	end)

	it("runs one tour at a time, and `tour stop` ends it after the stop on screen", function()
		local fake, ledger, _, seen = touring()
		stop(ledger, seen, "journal.home", "home")
		stop(ledger, seen, "journal.zone", "zone")

		fake.slash("dev tour")
		fake.slash("dev tour")
		fake.slash("dev tour stop")
		finish(fake)
		fake.slash("dev tour stop")

		assert.are.same({ "show home", "hide home" }, seen)
		assert.are.same({
			"Pagle dev: touring 2 stops from 12:00:00; a screenshot of each goes to the Screenshots folder.",
			"Pagle dev: tour 1/2: ledger.journal.home",
			"Pagle dev: a tour is running; /pagle dev tour stop ends it.",
			"Pagle dev: the tour stops once this stop hides.",
			"Pagle dev: the tour stopped at 1/2.",
			"Pagle dev: no tour is running.",
		}, fake.printed)
	end)
end)

describe("/pagle dev tour without Screenshot() (CORE-R66)", function()
	it("asks the dev to press Print Screen at each stop's line, and waits longer for it", function()
		local fake, ledger, _, seen = touring()
		fake.tourShots = nil
		stop(ledger, seen, "journal.home", "home")

		fake.slash("dev tour")
		fake.wait(1.5 + 0.5)
		local early = #seen
		finish(fake)

		assert.are.equal(1, early)
		assert.are.same({ "show home", "hide home" }, seen)
		assert.are.same({
			"Pagle dev: touring 1 stop from 12:00:00; this client can't take screenshots, so press Print Screen as"
				.. " each stop's line appears.",
			"Pagle dev: tour 1/1: ledger.journal.home",
			"Pagle dev: the tour is done at 12:00:00.",
		}, fake.printed)
	end)
end)
