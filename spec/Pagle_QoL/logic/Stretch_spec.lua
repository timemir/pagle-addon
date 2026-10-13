-- The Fishing stretch's pure logic: when a stretch starts and ends (QOL-R61), and the lease and restore protocol
-- for its CVars (QOL-R62, QOL-R63, QOL-R64).

describe("QoL's Fishing stretch logic", function()
	local ns = loadAddon("Pagle_QoL", FOREVER_GLOBALS).ns

	describe("ns.NewStretch", function()
		it("starts at the first CastStarted while armed, and not again while running (QOL-R61)", function()
			local stretch = ns.NewStretch()

			assert.is_true(stretch:CastStarted(true))
			assert.is_true(stretch:IsRunning())
			assert.is_false(stretch:CastStarted(true))
		end)

		it("never starts while disarmed: restricted or standing down (QOL-R61, QOL-R30, QOL-R82)", function()
			local stretch = ns.NewStretch()

			assert.is_false(stretch:CastStarted(false))
			assert.is_false(stretch:IsRunning())
		end)

		it("ends 60 s after the last CastEnded, of any outcome (QOL-R61, qol.md › Tunables)", function()
			local stretch = ns.NewStretch()
			stretch:CastStarted(true)
			stretch:CastEnded()

			assert.is_false(stretch:Elapse(59.5))
			assert.is_true(stretch:IsRunning())
			assert.is_true(stretch:Elapse(0.5))
			assert.is_false(stretch:IsRunning())
		end)

		it("doesn't count while a channel runs, and a new channel restarts the count (QOL-R61)", function()
			local stretch = ns.NewStretch()
			stretch:CastStarted(true)
			assert.is_false(stretch:IsCounting())
			assert.is_false(stretch:Elapse(120))

			stretch:CastEnded()
			assert.is_true(stretch:IsCounting())
			stretch:Elapse(50)
			stretch:CastStarted(true)
			assert.is_false(stretch:IsCounting())
			assert.is_false(stretch:Elapse(120))

			stretch:CastEnded()
			assert.is_false(stretch:Elapse(59))
			assert.is_true(stretch:Elapse(1))
		end)

		it("ends at once on any other cause, and only once (QOL-R61)", function()
			local stretch = ns.NewStretch()
			assert.is_false(stretch:End())

			stretch:CastStarted(true)
			stretch:CastEnded()
			assert.is_true(stretch:End())
			assert.is_false(stretch:IsRunning())
			assert.is_false(stretch:IsCounting())
			assert.is_false(stretch:End())
		end)

		it("ignores a CastEnded outside a stretch, so a later stretch counts from its own Casts (QOL-R61)", function()
			local stretch = ns.NewStretch()
			stretch:CastEnded()
			assert.is_false(stretch:IsCounting())

			stretch:CastStarted(true)
			assert.is_false(stretch:Elapse(60))
		end)
	end)

	describe("ns.SameCVarValue", function()
		-- Each row: two values as GetCVar returns them, then whether they're the same (QOL-R62, QOL-R63).
		local ROWS = {
			{ "15", "15", true },
			{ "15", "15.000000", true },
			{ "1", "1.0", true },
			{ "0", "-0", true },
			{ "3", "0", false },
			{ "14.5", "15", false },
			{ "abc", "abc", true },
			{ "abc", "ABC", false },
			{ "1", "on", false },
			{ "", "0", false },
		}
		for _, row in ipairs(ROWS) do
			it(
				("reads %q and %q as %s: as numbers when both parse, else as strings (QOL-R63)"):format(
					row[1],
					row[2],
					row[3] and "the same" or "different"
				),
				function()
					assert.are.equal(row[3], ns.SameCVarValue(row[1], row[2]))
					assert.are.equal(row[3], ns.SameCVarValue(row[2], row[1]))
				end
			)
		end
	end)

	-- CVars as a client holds them, for ns.Lease and ns.RestoreLease. `stores` turns what SetCVar is given into what
	-- GetCVar reads back (the client may normalise it); `log` gets "set NAME VALUE" for each SetCVar.
	---@param values table<string, string>
	---@param stores (fun(name: string, value: string): string)?
	local function newCVars(values, stores)
		local cvars = { values = values, log = {} }
		function cvars.get(name)
			return cvars.values[name]
		end
		function cvars.set(name, value)
			cvars.log[#cvars.log + 1] = ("set %s %s"):format(name, value)
			cvars.values[name] = stores and stores(name, value) or value
		end
		return cvars
	end

	-- The player's values before any lease: nothing at the soft-interact values.
	local function playerValues()
		return { SoftTargetInteract = "1", SoftTargetInteractRange = "10", SoftTargetInteractRangeIsHard = "1" }
	end

	describe("ns.Lease", function()
		it("leases the soft-interact row: interact 3, range 15, range not hard (QOL-R62)", function()
			local lease, cvars = {}, newCVars(playerValues())

			ns.Lease(lease, ns.SOFT_INTERACT_LEASE, cvars)

			assert.are.same({
				SoftTargetInteract = "3",
				SoftTargetInteractRange = "15",
				SoftTargetInteractRangeIsHard = "0",
			}, cvars.values)
			assert.are.same({
				{ name = "SoftTargetInteract", orig = "1", set = "3" },
				{ name = "SoftTargetInteractRange", orig = "10", set = "15" },
				{ name = "SoftTargetInteractRangeIsHard", orig = "1", set = "0" },
			}, lease)
		end)

		it("writes { name, orig } before SetCVar, then set as GetCVar reads it back (QOL-R63)", function()
			local lease = {}
			local seen = {}
			local cvars = newCVars(playerValues(), function(_, value)
				return value .. ".000000"
			end)
			local set = cvars.set
			function cvars.set(name, value)
				local entry = lease[#lease]
				seen[#seen + 1] = { name = entry.name, orig = entry.orig, set = entry.set }
				set(name, value)
			end

			ns.Lease(lease, ns.SOFT_INTERACT_LEASE, cvars)

			assert.are.same({ name = "SoftTargetInteract", orig = "1" }, seen[1])
			assert.are.same({ name = "SoftTargetInteract", orig = "1", set = "3.000000" }, lease[1])
		end)

		it("leases no CVar that already holds its leased value, compared as numbers (QOL-R62)", function()
			local lease = {}
			local cvars = newCVars({
				SoftTargetInteract = "3.0",
				SoftTargetInteractRange = "10",
				SoftTargetInteractRangeIsHard = "0",
			})

			ns.Lease(lease, ns.SOFT_INTERACT_LEASE, cvars)

			assert.are.same({ "set SoftTargetInteractRange 15" }, cvars.log)
			assert.are.same({ { name = "SoftTargetInteractRange", orig = "10", set = "15" } }, lease)
		end)

		it("leases SoftTargetInteractRange only while the player's value is below 15 (QOL-R62)", function()
			for _, row in ipairs({
				{ "60", false },
				{ "15", false },
				{ "15.5", false },
				{ "14.9", true },
				{ "0", true },
			}) do
				local values = playerValues()
				values.SoftTargetInteractRange = row[1]
				local lease, cvars = {}, newCVars(values)

				ns.Lease(lease, ns.SOFT_INTERACT_LEASE, cvars)

				assert.are.equal(row[2] and "15" or row[1], cvars.values.SoftTargetInteractRange, row[1])
				assert.are.equal(row[2] and 3 or 2, #lease, row[1])
			end
		end)

		it("leases no CVar the client doesn't know (GetCVar returns nil)", function()
			local lease, cvars = {}, newCVars({ SoftTargetInteract = "1" })

			ns.Lease(lease, ns.SOFT_INTERACT_LEASE, cvars)

			assert.are.same({ { name = "SoftTargetInteract", orig = "1", set = "3" } }, lease)
		end)

		it(
			"keeps a waiting entry whose CVar still holds the leased value, so orig stays the player's (QOL-R63)",
			function()
				local values = playerValues()
				values.SoftTargetInteract = "3"
				local lease = { { name = "SoftTargetInteract", orig = "1", set = "3" } }

				ns.Lease(lease, { ns.SOFT_INTERACT_LEASE[1] }, newCVars(values))

				assert.are.same({ { name = "SoftTargetInteract", orig = "1", set = "3" } }, lease)
			end
		)

		it("replaces a waiting entry the player has overruled since, leasing from their new value (QOL-R63)", function()
			local values = playerValues()
			values.SoftTargetInteract = "2"
			local lease = { { name = "SoftTargetInteract", orig = "1", set = "3" } }

			ns.Lease(lease, { ns.SOFT_INTERACT_LEASE[1] }, newCVars(values))

			assert.are.same({ { name = "SoftTargetInteract", orig = "2", set = "3" } }, lease)
		end)
	end)

	describe("ns.RestoreLease", function()
		it("restores each CVar that still reads set to orig, and removes its entry (QOL-R63)", function()
			local lease, cvars = {}, newCVars(playerValues())
			ns.Lease(lease, ns.SOFT_INTERACT_LEASE, cvars)
			cvars.log = {}

			ns.RestoreLease(lease, cvars)

			assert.are.same(playerValues(), cvars.values)
			assert.are.same({}, lease)
			assert.are.equal(3, #cvars.log)
		end)

		it("leaves a value the player changed during the stretch, and removes its entry (QOL-R63)", function()
			local lease, cvars = {}, newCVars(playerValues())
			ns.Lease(lease, ns.SOFT_INTERACT_LEASE, cvars)
			cvars.values.SoftTargetInteractRange = "30"
			cvars.log = {}

			ns.RestoreLease(lease, cvars)

			assert.are.equal("30", cvars.values.SoftTargetInteractRange)
			assert.are.same({ "set SoftTargetInteract 1", "set SoftTargetInteractRangeIsHard 1" }, cvars.log)
			assert.are.same({}, lease)
		end)

		it("compares with set as numbers when both parse, else as strings (QOL-R63)", function()
			local cvars = newCVars({ A = "15.000000", B = "on", C = "ON" })
			local lease = {
				{ name = "A", orig = "10", set = "15" },
				{ name = "B", orig = "off", set = "on" },
				{ name = "C", orig = "off", set = "on" },
			}

			ns.RestoreLease(lease, cvars)

			assert.are.same({ A = "10", B = "off", C = "ON" }, cvars.values)
			assert.are.same({}, lease)
		end)

		it("keeps an entry whose restore didn't take, for the leftover restore (QOL-R63, QOL-R64)", function()
			local cvars = newCVars({ A = "3" }, function()
				return "3"
			end)
			local lease = { { name = "A", orig = "1", set = "3" } }

			ns.RestoreLease(lease, cvars)

			assert.are.same({ { name = "A", orig = "1", set = "3" } }, lease)
		end)

		it("removes an entry whose CVar the client no longer knows (QOL-R63)", function()
			local cvars = newCVars({})
			local lease = { { name = "Gone", orig = "1", set = "3" } }

			ns.RestoreLease(lease, cvars)

			assert.are.same({}, cvars.log)
			assert.are.same({}, lease)
		end)
	end)
end)
