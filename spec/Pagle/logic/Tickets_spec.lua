-- Core's Refresh purse (ADR 0017, core/refresh.md): each Module's last reported lifetime
-- Refreshes earned and spent, tied to the log's logId, and what is left; as pure logic through ns.NewTickets,
-- ns.TicketTotalProblem and ns.TieTotalsToLog.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

-- A purse over `store` (PagleDB.global.tickets) with the log's logId `world.logId`. Each TicketsChanged it fires lands
-- in `world.fired` as `{ event, tickets }`.
local function newTickets(store)
	local world = { fired = {}, logId = "3f9a2c1e7b0d4a65" }
	world.store = store or { earned = {}, spent = {}, logId = world.logId }
	world.tickets = ns.NewTickets({
		fire = function(event, tickets)
			world.fired[#world.fired + 1] = { event = event, tickets = tickets }
		end,
		logId = function()
			return world.logId
		end,
	})
	world.tickets:Open(world.store)
	return world
end

describe("ns.TicketTotalProblem", function()
	for _, case in ipairs({
		{ "a negative number", -1 },
		{ "a fraction", 1.5 },
		{ "a string", "3" },
		{ "nothing", nil },
		{ "infinity", math.huge },
		{ "not a number", 0 / 0 },
	}) do
		it("refuses " .. case[1] .. " (REF-R2)", function()
			assert.matches(
				"M:ReportTicketsEarned takes a whole number of Refreshes, 0 or more",
				ns.TicketTotalProblem(case[2], "ReportTicketsEarned"),
				1,
				true
			)
		end)
	end

	it("names the method it was asked about (REF-R2)", function()
		assert.matches(
			"M:ReportTicketsSpent takes a whole number of Refreshes, 0 or more",
			ns.TicketTotalProblem(-1, "ReportTicketsSpent"),
			1,
			true
		)
	end)

	it("takes 0 and any whole number above it (REF-R2)", function()
		assert.is_nil(ns.TicketTotalProblem(0, "ReportTicketsEarned"))
		assert.is_nil(ns.TicketTotalProblem(7, "ReportTicketsSpent"))
	end)
end)

describe("ns.NewTickets", function()
	it("stores earned and spent totals apart, under the Module's def.name (REF-R3)", function()
		local world = newTickets()

		world.tickets:ReportEarned("Hunts", 5)
		world.tickets:ReportSpent("TackleBoard", 2)

		assert.are.same({ Hunts = 5 }, world.store.earned)
		assert.are.same({ TackleBoard = 2 }, world.store.spent)
	end)

	it("holds the sum of earned minus the sum of spent, across Modules (REF-R5)", function()
		local world = newTickets()
		world.tickets:ReportEarned("Hunts", 5)
		world.tickets:ReportEarned("Other", 3)
		world.tickets:ReportSpent("TackleBoard", 2)
		world.tickets:ReportSpent("Other", 1)

		assert.are.same({ tickets = 5, earned = 8, spent = 3 }, world.tickets:Get())
	end)

	it("floors at 0 when more is spent than earned, and rises again from there (REF-R5)", function()
		local world = newTickets()
		world.tickets:ReportEarned("Hunts", 2)
		world.tickets:ReportSpent("TackleBoard", 3)

		assert.are.same({ tickets = 0, earned = 2, spent = 3 }, world.tickets:Get())

		world.tickets:ReportEarned("Hunts", 4)
		assert.are.equal(1, world.tickets:Get().tickets)
	end)

	it("replaces a total with a lower later report (REF-R4)", function()
		local world = newTickets()
		world.tickets:ReportEarned("Hunts", 5)

		world.tickets:ReportEarned("Hunts", 3)

		assert.are.same({ Hunts = 3 }, world.store.earned)
		assert.are.equal(3, world.tickets:Get().tickets)
	end)

	it("counts totals already stored, with no report this session (REF-R3, REF-R90)", function()
		local world = newTickets({ earned = { Hunts = 5 }, spent = { TackleBoard = 1 }, logId = "3f9a2c1e7b0d4a65" })

		assert.are.same({ tickets = 4, earned = 5, spent = 1 }, world.tickets:Get())
	end)

	it("fires TicketsChanged with the new totals once per change (REF-R6)", function()
		local world = newTickets()

		world.tickets:ReportEarned("Hunts", 5)
		world.tickets:ReportSpent("TackleBoard", 2)

		assert.are.same({
			{ event = "TicketsChanged", tickets = { tickets = 5, earned = 5, spent = 0 } },
			{ event = "TicketsChanged", tickets = { tickets = 3, earned = 5, spent = 2 } },
		}, world.fired)
	end)

	it("fires nothing for a report equal to the stored total (REF-R2, REF-R6)", function()
		local world = newTickets({ earned = { Hunts = 5 }, spent = { TackleBoard = 1 }, logId = "3f9a2c1e7b0d4a65" })

		world.tickets:ReportEarned("Hunts", 5)
		world.tickets:ReportSpent("TackleBoard", 1)

		assert.are.same({}, world.fired)
	end)

	it(
		"stores a first report of 0, which adds the Module to the store, and fires nothing: no field changes (REF-R6)",
		function()
			local world = newTickets()

			world.tickets:ReportEarned("Hunts", 0)

			assert.are.same({ Hunts = 0 }, world.store.earned)
			assert.are.same({}, world.fired)
		end
	)

	it("fires for a spent total that moves while the floor holds the count at 0 (REF-R6)", function()
		local world = newTickets()
		world.tickets:ReportSpent("TackleBoard", 2)

		world.tickets:ReportSpent("TackleBoard", 3)

		assert.are.equal(2, #world.fired)
		assert.are.same({ tickets = 0, earned = 0, spent = 3 }, world.fired[2].tickets)
	end)

	it("hands out a fresh table each call, so a caller's change never reaches the store (REF-R6)", function()
		local world = newTickets()
		world.tickets:ReportEarned("Hunts", 5)
		local first = world.tickets:Get()

		first.tickets = 99

		assert.are.equal(5, world.tickets:Get().tickets)
		assert.are.same({ Hunts = 5 }, world.store.earned)
	end)

	it("takes the log's logId at each report, so a fresh log's first totals stay theirs (REF-R3)", function()
		local world = newTickets({ earned = {}, spent = {} })
		world.logId = "a1b2c3d4e5f60718" -- the logId PLAYER_LOGIN created (LOG-R15)

		world.tickets:ReportEarned("Hunts", 1)

		assert.are.equal("a1b2c3d4e5f60718", world.store.logId)
	end)
end)

describe("Tickets:Open", function()
	it("empties earned and spent of another logId in place and takes the log's (REF-R3)", function()
		local store = { earned = { Hunts = 6 }, spent = { TackleBoard = 2 }, logId = "0000000000000001" }
		local earned, spent = store.earned, store.spent

		local world = newTickets(store)

		assert.are.same({ earned = {}, spent = {}, logId = "3f9a2c1e7b0d4a65" }, store)
		assert.are.equal(earned, store.earned)
		assert.are.equal(spent, store.spent)
		assert.are.same({ tickets = 0, earned = 0, spent = 0 }, world.tickets:Get())
		assert.are.same({}, world.fired)
	end)

	it("keeps the totals of the same logId (REF-R3)", function()
		local store = { earned = { Hunts = 6 }, spent = { TackleBoard = 2 }, logId = "3f9a2c1e7b0d4a65" }

		newTickets(store)

		assert.are.same({ earned = { Hunts = 6 }, spent = { TackleBoard = 2 }, logId = "3f9a2c1e7b0d4a65" }, store)
	end)
end)

describe("ns.TieTotalsToLog for a store with spent totals", function()
	it("empties `spent` along with `earned` for another logId, and says so (REF-R3)", function()
		local store = { earned = { Hunts = 6 }, spent = { TackleBoard = 2 }, logId = "0000000000000001" }

		assert.is_true(ns.TieTotalsToLog(store, "3f9a2c1e7b0d4a65"))

		assert.are.same({ earned = {}, spent = {}, logId = "3f9a2c1e7b0d4a65" }, store)
	end)

	it("leaves `spent` as it is for the same logId (REF-R3)", function()
		local store = { earned = { Hunts = 6 }, spent = { TackleBoard = 2 }, logId = "3f9a2c1e7b0d4a65" }

		assert.is_false(ns.TieTotalsToLog(store, "3f9a2c1e7b0d4a65"))

		assert.are.equal(2, store.spent.TackleBoard)
	end)
end)
