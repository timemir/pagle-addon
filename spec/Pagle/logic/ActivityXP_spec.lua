-- Core's Activity XP (core/activity-xp.md, ADR 0011): each paying Module's last reported lifetime total, tied to the
-- log's logId, their sum and `ActivityXPChanged`, as pure logic through ns.NewActivityXP and ns.TieTotalsToLog.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

-- A registered Module named `name`, as the registry lists it.
local function module(name)
	return { def = { name = name, title = name, order = 10 } }
end

-- Activity XP over `store` (PagleDB.global.activityXP), with the Modules in `on` registered and the log's logId
-- `world.logId`. Each ActivityXPChanged it fires lands in `world.fired` as `{ event, entry }`.
local function newActivityXP(store, on)
	local world = { fired = {}, logId = "3f9a2c1e7b0d4a65", on = {} }
	for _, name in ipairs(on or {}) do
		world.on[#world.on + 1] = module(name)
	end
	world.store = store or { earned = {}, logId = world.logId }
	world.xp = ns.NewActivityXP({
		fire = function(event, entry)
			world.fired[#world.fired + 1] = { event = event, entry = entry }
		end,
		modules = function()
			return world.on
		end,
		logId = function()
			return world.logId
		end,
	})
	world.xp:Open(world.store)
	return world
end

describe("ns.XPTotalProblem", function()
	for _, case in ipairs({
		{ "a negative number", -1 },
		{ "a fraction", 1.5 },
		{ "a string", "10" },
		{ "nothing", nil },
		{ "infinity", math.huge },
		{ "not a number", 0 / 0 },
	}) do
		it("refuses " .. case[1] .. " (AXP-R2)", function()
			assert.matches(
				"M:ReportXPEarned takes a whole number of Activity XP, 0 or more",
				ns.XPTotalProblem(case[2]),
				1,
				true
			)
		end)
	end

	it("takes 0 and any whole number above it (AXP-R2)", function()
		assert.is_nil(ns.XPTotalProblem(0))
		assert.is_nil(ns.XPTotalProblem(150))
	end)
end)

describe("ns.NewActivityXP", function()
	it("stores a report under the Module's def.name and fires ActivityXPChanged once (AXP-R3, AXP-R7)", function()
		local world = newActivityXP(nil, { "Hunts" })

		world.xp:Report("Hunts", 150, nil)

		assert.are.same({ Hunts = 150 }, world.store.earned)
		assert.are.same({ { event = "ActivityXPChanged" } }, world.fired)
	end)

	it("fires nothing for a report equal to the stored total (AXP-R7)", function()
		local world = newActivityXP(nil, { "Hunts" })
		world.xp:Report("Hunts", 150, nil)

		world.xp:Report("Hunts", 150, nil)

		assert.are.equal(1, #world.fired)
	end)

	it("replaces a total with a lower report, and fires (AXP-R4, AXP-R7)", function()
		local world = newActivityXP(nil, { "Hunts" })
		world.xp:Report("Hunts", 150, nil)

		world.xp:Report("Hunts", 100, nil)

		assert.are.same({ Hunts = 100 }, world.store.earned)
		assert.are.equal(2, #world.fired)
	end)

	it("fires with the live entry it is handed, after storing the total (AXP-R7)", function()
		local world = newActivityXP(nil, { "TackleBoard" })
		local entry = { seq = 12, kind = "module" }
		local stored
		world.xp = ns.NewActivityXP({
			fire = function(_, fired)
				stored = { world.store.earned.TackleBoard, fired }
			end,
			modules = function()
				return world.on
			end,
			logId = function()
				return world.logId
			end,
		})
		world.xp:Open(world.store)

		world.xp:Report("TackleBoard", 100, entry)

		assert.are.equal(100, stored[1])
		assert.are.equal(entry, stored[2])
	end)

	it("fires for a first report of 0, which lists the Module as a source (AXP-R6, AXP-R7)", function()
		local world = newActivityXP(nil, { "Hunts" })

		world.xp:Report("Hunts", 0, nil)

		assert.are.equal(1, #world.fired)
		assert.are.same({ total = 0, bySource = { Hunts = { total = 0, enabled = true } } }, world.xp:Get())
	end)

	it("sums the stored totals, and lists only the Modules that reported (AXP-R6)", function()
		local world = newActivityXP(nil, { "Hunts", "TackleBoard", "Stats" })

		world.xp:Report("Hunts", 400, nil)
		world.xp:Report("TackleBoard", 350, nil)

		assert.are.same({
			total = 750,
			bySource = { Hunts = { total = 400, enabled = true }, TackleBoard = { total = 350, enabled = true } },
		}, world.xp:Get())
		assert.are.equal(750, world.xp:Total())
	end)

	it(
		"still counts a disabled or uninstalled Module's last total, listed with enabled false (AXP-R3, AXP-R6, AXP-R90)",
		function()
			local world = newActivityXP(
				{ earned = { Hunts = 600, TackleBoard = 250 }, logId = "3f9a2c1e7b0d4a65" },
				{ "TackleBoard" }
			)

			assert.are.same({
				total = 850,
				bySource = { Hunts = { total = 600, enabled = false }, TackleBoard = { total = 250, enabled = true } },
			}, world.xp:Get())
		end
	)

	it("hands out a fresh table each call, so a caller's change never reaches the store (AXP-R6)", function()
		local world = newActivityXP(nil, { "Hunts" })
		world.xp:Report("Hunts", 150, nil)
		local first = world.xp:Get()

		first.total = 999
		first.bySource.Hunts.total = 999

		assert.are_not.equal(first, world.xp:Get())
		assert.are.same({ total = 150, bySource = { Hunts = { total = 150, enabled = true } } }, world.xp:Get())
		assert.are.same({ Hunts = 150 }, world.store.earned)
	end)

	it("takes the log's logId at each report, so a fresh log's first totals stay theirs (AXP-R3)", function()
		local world = newActivityXP({ earned = {} }, { "Hunts" })
		world.logId = "a1b2c3d4e5f60718" -- the logId PLAYER_LOGIN created (LOG-R15)

		world.xp:Report("Hunts", 150, nil)

		assert.are.equal("a1b2c3d4e5f60718", world.store.logId)
	end)

	it("refills from the next reports after PagleDB is lost (AXP-R91)", function()
		local world = newActivityXP({ earned = {} }, { "Hunts", "TackleBoard" })
		assert.are.same({ total = 0, bySource = {} }, world.xp:Get())

		world.xp:Report("Hunts", 400, nil)
		world.xp:Report("TackleBoard", 350, nil)

		assert.are.equal(750, world.xp:Total())
	end)
end)

describe("ActivityXP:Open", function()
	it("empties the totals of another logId and takes the log's (AXP-R3)", function()
		local store = { earned = { Hunts = 600, TackleBoard = 250 }, logId = "0000000000000001" }
		local earned = store.earned

		local world = newActivityXP(store, { "Hunts" })

		assert.are.same({ earned = {}, logId = "3f9a2c1e7b0d4a65" }, store)
		assert.are.equal(earned, store.earned) -- emptied in place: PagleDB's own table
		assert.are.same({ total = 0, bySource = {} }, world.xp:Get())
		assert.are.same({}, world.fired)
	end)

	it("keeps the totals of the same logId (AXP-R3)", function()
		local store = { earned = { Hunts = 600 }, logId = "3f9a2c1e7b0d4a65" }

		newActivityXP(store, { "Hunts" })

		assert.are.same({ earned = { Hunts = 600 }, logId = "3f9a2c1e7b0d4a65" }, store)
	end)
end)

describe("ns.TieTotalsToLog", function()
	it("empties a store of another logId in place, takes the new one and says so (AXP-R3, SHOP-R3)", function()
		local store = { earned = { Ledger = 1200, TackleBoard = 750 }, logId = "0000000000000001" }
		local earned = store.earned

		assert.is_true(ns.TieTotalsToLog(store, "3f9a2c1e7b0d4a65"))

		assert.are.same({ earned = {}, logId = "3f9a2c1e7b0d4a65" }, store)
		assert.are.equal(earned, store.earned)
	end)

	it("empties a store for a new log whose logId PLAYER_LOGIN has yet to create (AXP-R3, LOG-R18)", function()
		local store = { earned = { Ledger = 1200 }, logId = "0000000000000001" }

		assert.is_true(ns.TieTotalsToLog(store, nil))

		assert.are.same({ earned = {} }, store)
	end)

	it("leaves a store of the same logId as it is (AXP-R3, SHOP-R3)", function()
		local store = { earned = { Ledger = 1200 }, logId = "3f9a2c1e7b0d4a65" }

		assert.is_false(ns.TieTotalsToLog(store, "3f9a2c1e7b0d4a65"))

		assert.are.same({ earned = { Ledger = 1200 }, logId = "3f9a2c1e7b0d4a65" }, store)
	end)
end)
