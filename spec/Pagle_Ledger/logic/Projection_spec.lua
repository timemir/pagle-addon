-- The Ledger's projection def (LED-R2, LED-R4, LED-R98; catch-log.md › Projection definition) through
-- ns.ProjectionDef and ns.RulesVersion, with no Core: what M:NewProjection is handed.

describe("the Ledger's projection def", function()
	local ns = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns
	local lookups = {
		GetItem = function()
			return nil
		end,
	}

	-- Outlets that note each call as "<call> <argument>" in `calls`.
	---@param calls string[]
	---@return LedgerOutlets
	local function noting(calls)
		local function note(name)
			return function(value)
				calls[#calls + 1] = name .. " " .. tostring(type(value) == "table" and value.kind or value)
			end
		end
		return {
			RaiseMoment = note("RaiseMoment"),
			ReportCoinsEarned = note("ReportCoinsEarned"),
			SetSummaryLine = note("SetSummaryLine"),
			ItemName = function() end,
			ZoneName = function() end,
		}
	end
	local outlets = noting({})

	it(
		"has rulesVersion LEDGER_RULES_VERSION × 100 + SIZE_RULES_VERSION, a missing one counting as 0 (LED-R2)",
		function()
			assert.are.equal(100, ns.RulesVersion(nil))
			assert.are.equal(101, ns.RulesVersion(1))
			assert.are.equal(100, ns.ProjectionDef({}, lookups, outlets, nil).rulesVersion)
			assert.are.equal(101, ns.ProjectionDef({}, lookups, outlets, 1).rulesVersion)
		end
	)

	it("binds PagleLedgerDB.global.projection, made if missing and kept if saved (LED-R2, LOG-R70)", function()
		local fresh = {}
		local saved = { projection = { lastSeq = 4 } }

		local db = ns.ProjectionDef(fresh, lookups, outlets).db
		assert.are.equal(fresh.projection, db)
		assert.are.same({}, db)
		local savedTable = saved.projection
		assert.are.equal(savedTable, ns.ProjectionDef(saved, lookups, outlets).db)
		assert.are.same({ lastSeq = 4 }, saved.projection)
	end)

	it("has no extraFingerprint, and a done (LED-R2, LED-R93, LED-R98)", function()
		local def = ns.ProjectionDef({}, lookups, outlets)

		assert.is_nil(def.extraFingerprint)
		assert.are.equal("function", type(def.done))
	end)

	it(
		"resets to the fold's empty state and applies through the fold, ignoring other kinds (LED-R2, LED-R3)",
		function()
			local def = ns.ProjectionDef({}, lookups, outlets)
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

	-- A Skill Reading at `rank`, entry `seq`.
	local function reading(seq, rank)
		return { kind = "skill", seq = seq, id = "x-" .. seq, char = 1, time = seq, rank = rank, max = 300, mod = 0 }
	end

	it(
		"raises only for a live entry: a replayed or rebuilt one's achievements wait for done (LED-R91, LED-R98)",
		function()
			local calls = {}
			local global = {}
			local def = ns.ProjectionDef(global, lookups, noting(calls))
			local state = def.reset()

			def.apply(state, reading(1, 80), "rebuild")
			def.apply(state, reading(2, 160), "replay")
			assert.are.same({}, calls)
			assert.is_nil(global.celebrated)

			-- 3 × 1,000 XP: level 2 by the replay, level 3 (1,080 + 1,160) by the live entry, each 20 Coins (LED-R88).
			def.apply(state, reading(3, 230), "live")
			assert.are.same({
				"RaiseMoment skillMilestone",
				"RaiseMoment levelUp",
				"ReportCoinsEarned 40",
				"SetSummaryLine Ledger: Angler Level 3",
			}, calls)
			assert.are.same({ [225] = true }, global.celebrated.skill)
			assert.are.same({ [0] = 3 }, global.celebrated.levels)
			assert.are.equal(40, global.celebrated.coins)
		end
	)

	it("celebrates nothing in its done yet: ticket #102 builds it (LED-R93)", function()
		local calls = {}
		local global = {}
		local def = ns.ProjectionDef(global, lookups, noting(calls))
		local state = def.reset()
		def.apply(state, reading(1, 80), "rebuild")

		def.done(state, { firstBuild = true, rebuilt = true, replayed = 0 })

		assert.are.same({}, calls)
		assert.is_nil(global.celebrated)
	end)
end)
