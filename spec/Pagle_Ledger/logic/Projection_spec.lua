-- The Ledger's projection def (LED-R2, LED-R4; catch-log.md › Projection definition) through ns.ProjectionDef and
-- ns.RulesVersion, with no Core: what M:NewProjection is handed.

describe("the Ledger's projection def", function()
	local ns = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns
	local lookups = {
		GetItem = function()
			return nil
		end,
	}

	it(
		"has rulesVersion LEDGER_RULES_VERSION × 100 + SIZE_RULES_VERSION, a missing one counting as 0 (LED-R2)",
		function()
			assert.are.equal(100, ns.RulesVersion(nil))
			assert.are.equal(101, ns.RulesVersion(1))
			assert.are.equal(100, ns.ProjectionDef({}, lookups, nil).rulesVersion)
			assert.are.equal(101, ns.ProjectionDef({}, lookups, 1).rulesVersion)
		end
	)

	it("binds PagleLedgerDB.global.projection, made if missing and kept if saved (LED-R2, LOG-R70)", function()
		local fresh = {}
		local saved = { projection = { lastSeq = 4 } }

		local db = ns.ProjectionDef(fresh, lookups).db
		assert.are.equal(fresh.projection, db)
		assert.are.same({}, db)
		local savedTable = saved.projection
		assert.are.equal(savedTable, ns.ProjectionDef(saved, lookups).db)
		assert.are.same({ lastSeq = 4 }, saved.projection)
	end)

	it("has no extraFingerprint, and no done until the moments come (LED-R2, tickets #101 and #102)", function()
		local def = ns.ProjectionDef({}, lookups)

		assert.is_nil(def.extraFingerprint)
		assert.is_nil(def.done)
	end)

	it(
		"resets to the fold's empty state and applies through the fold, ignoring other kinds (LED-R2, LED-R3)",
		function()
			local def = ns.ProjectionDef({}, lookups)
			local state = def.reset()
			local empty = ns.NewLedgerFold(lookups).reset()

			def.apply(state, { kind = "prestige", seq = 1, id = "x-1", char = 1, time = 1, rank = 1 }, "live")
			def.apply(
				state,
				{ kind = "build", seq = 2, id = "x-2", char = 1, time = 1, build = 1, version = "1" },
				"live"
			)
			def.apply(
				state,
				{ kind = "purchase", seq = 3, id = "x-3", char = 1, time = 1, good = 1, price = 5 },
				"live"
			)
			assert.are.same(empty, state)

			def.apply(
				state,
				{ kind = "skill", seq = 4, id = "x-4", char = 1, time = 9, rank = 80, max = 150, mod = 0 },
				"replay"
			)
			assert.are.same({ [75] = 9 }, state.skill)
		end
	)
end)
