-- The Ledger's projection def (LED-R2, LED-R4, LED-R98; catch-log.md › Projection definition) through
-- ns.ProjectionDef and ns.RulesVersion, with no Core: what M:NewProjection is handed.

describe("the Ledger's projection def", function()
	local ns = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns
	local lookups = {
		GetItem = function()
			return nil
		end,
		-- A world index charting no zone (LED-R10).
		world = ns.NewWorld({
			GetItem = function() end,
			GetZones = function()
				return {}
			end,
			GetArea = function() end,
			GetZoneCatches = function() end,
		}),
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
			AreaName = function() end,
			RaiseWriteUp = note("RaiseWriteUp"),
			LogId = function() end,
			FormatNumber = tostring,
			RefreshGoods = note("RefreshGoods"),
			SizeText = function() end,
			ZoneCrest = function() end,
		}
	end
	local outlets = noting({})

	it(
		"has rulesVersion LEDGER_RULES_VERSION × 100 + SIZE_RULES_VERSION, a missing one counting as 0 (LED-R2)",
		function()
			-- LEDGER_RULES_VERSION 10: 4 when ★ moved to the 5th Catch (LED-R45), 5 for the full Prestige cost and
			-- Activity XP in the climb (LED-R4, LED-R30, LED-R37), 6 for the varieties caught (VAR-R20), 7 for the
			-- second round's counts (LED-R118), 8 for the crest times and record (LED-R155, LED-R156), 9 for the
			-- measures' rise times (LED-R158), 10 for the fish of each race and faction (LED-R164).
			assert.are.equal(1000, ns.RulesVersion(nil))
			assert.are.equal(1002, ns.RulesVersion(2))
			assert.are.equal(1000, ns.ProjectionDef({}, lookups, outlets, nil).rulesVersion)
			assert.are.equal(1002, ns.ProjectionDef({}, lookups, outlets, 2).rulesVersion)
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

			def.apply(
				state,
				{ kind = "build", seq = 1, id = "x-1", char = 1, time = 1, build = 1, version = "1" },
				"live"
			)
			def.apply(
				state,
				{ kind = "purchase", seq = 2, id = "x-2", char = 1, time = 1, good = 1, price = 5 },
				"live"
			)
			assert.are.same(empty, state)

			def.apply(
				state,
				{ kind = "skill", seq = 3, id = "x-3", char = 1, time = 9, rank = 80, max = 150, mod = 0 },
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
				-- Nothing charted: 0% (LED-R70).
				"SetSummaryLine Ledger: Angler Level 3 · 0% complete",
			}, calls)
			assert.are.same({ [225] = true }, global.celebrated.skill)
			assert.are.same({ [0] = 3 }, global.celebrated.levels)
			assert.are.equal(40, global.celebrated.coins)
		end
	)

	it(
		"refreshes the goods after a live entry that takes the peak level past a multiple of 10, and only then (LED-R111, SHOP-R31)",
		function()
			local calls = {}
			local def = ns.ProjectionDef({}, lookups, noting(calls))
			local state = def.reset()
			-- 10 XP short of level 10: the steps to it cost 9 × 1,000 + 80 × (1 + … + 9) = 12,600 (LED-R30).
			state.xp = 12590
			local function refreshes()
				local n = 0
				for _, call in ipairs(calls) do
					n = n + (call == "RefreshGoods nil" and 1 or 0)
				end
				return n
			end
			def.apply(state, reading(1, 10), "live") -- no Skill Milestone, no XP: still level 9
			assert.are.same({ 9, 0 }, { ns.PeakLevel(state), refreshes() })

			def.apply(state, reading(2, 80), "live") -- Skill Milestone 75: 1,000 XP

			assert.are.same({ 10, 1 }, { ns.PeakLevel(state), refreshes() })
		end
	)

	it(
		"refreshes the goods after a live entry that raises a zone to Master, the moment its crest is earned, and not for a lesser rank (LED-R114, SHOP-R31)",
		function()
			-- Pond lists one ungated Species and nothing else, so its first Catch passes every rank to Master; Brook
			-- lists two, so its first Catch reaches Regular only (LED-R50).
			local POND, BROOK, ONE, TWO = 12, 40, 6303, 6291
			local areas = {
				[POND] = { hasData = true, catches = { catchEntry(ONE) } },
				[BROOK] = { hasData = true, catches = { catchEntry(ONE), catchEntry(TWO) } },
			}
			local getItem = itemLookup({ [ONE] = fishRecord(ONE), [TWO] = fishRecord(TWO) })
			local world = ns.NewWorld({
				GetItem = getItem,
				GetZones = function()
					return { POND, BROOK }
				end,
				GetArea = function(zone)
					return areas[zone]
				end,
				GetZoneCatches = function(zone)
					local list = {}
					for i, catch in ipairs(areas[zone].catches) do
						list[i] = { areaID = zone, itemID = catch.itemID, confirmed = true }
					end
					return list
				end,
			})
			local charted = { GetItem = getItem, MatchesConditions = function() end, world = world }
			local calls = {}
			local def = ns.ProjectionDef({}, charted, noting(calls))
			local state = def.reset()
			local function refreshes()
				local n = 0
				for _, call in ipairs(calls) do
					n = n + (call == "RefreshGoods nil" and 1 or 0)
				end
				return n
			end

			def.apply(state, castRecord({ seq = 1, zone = BROOK, items = { ONE } }), "live")
			assert.are.same({ 2, 0 }, { state.zones[BROOK].rank, refreshes() })
			def.apply(state, castRecord({ seq = 2, zone = POND, items = { ONE } }), "live")

			assert.are.same({ 5, 1 }, { state.zones[POND].rank, refreshes() })
		end
	)

	it(
		"refreshes the goods in every done, after Coins and before the summary line, and never mid-rebuild (LED-R93, LED-R111, SHOP-R31)",
		function()
			local calls = {}
			local def = ns.ProjectionDef({}, lookups, noting(calls))
			local state = def.reset()
			for seq = 1, 3 do
				def.apply(state, reading(seq, 80 * seq), "rebuild")
			end
			assert.are.same({}, calls)

			def.done(state, { firstBuild = false, rebuilt = true, replayed = 0 })

			assert.are.same({ "ReportCoinsEarned", "RefreshGoods", "SetSummaryLine" }, {
				calls[#calls - 2]:match("^%a+"),
				calls[#calls - 1]:match("^%a+"),
				calls[#calls]:match("^%a+"),
			})
		end
	)

	-- Outlets for done: moments as "<kind> <title> / <text> <coins> <summaryOnly>", Write-up sections as their heading
	-- then lines, both in `raised`, on the log "log".
	---@param raised (string|string[])[]
	---@return LedgerOutlets
	local function collecting(raised)
		local collected = noting({})
		collected.RaiseMoment = function(moment)
			raised[#raised + 1] = ("%s %s / %s %s %s"):format(
				moment.kind,
				moment.title,
				tostring(moment.text),
				tostring(moment.coins),
				tostring(moment.summaryOnly)
			)
		end
		collected.RaiseWriteUp = function(section)
			raised[#raised + 1] = { section.heading, unpack(section.lines) }
		end
		collected.LogId = function()
			return "log"
		end
		collected.FormatNumber = breakUpLargeNumbers
		return collected
	end

	-- A got-away Cast, entry `seq`.
	local function gotAway(seq)
		return {
			kind = "cast",
			seq = seq,
			id = "x-" .. seq,
			char = 1,
			time = seq,
			outcome = "gotAway",
			conditions = { minute = 0, zone = 0, subzone = 0, events = {}, auras = {} },
			items = {},
		}
	end

	-- A caught Cast of `itemID` in zone 0, entry `seq`.
	local function caught(seq, itemID)
		local record = gotAway(seq)
		record.outcome = "caught"
		record.items = { { n = 1, itemID = itemID, quantity = 1, catchId = record.id .. ":1" } }
		return record
	end

	it("raises M3's achievements live and, summary-only, in a rebuild's done (LED-R4, LED-R93, LED-R97)", function()
		local raised = {}
		local def = ns.ProjectionDef({ celebrated = { logId = "log" } }, lookups, collecting(raised))
		local state = def.reset()

		-- Every item is Uncharted to these lookups: each first Catch earns an `uncharted` achievement (LED-R64).
		def.apply(state, caught(1, 99901), "rebuild")
		def.done(state, { firstBuild = false, rebuilt = true, replayed = 0 })
		def.apply(state, caught(2, 99902), "live")

		assert.are.same({ 1, 1 }, { state.uncharted[99901].n, state.uncharted[99902].n })
		assert.are.same({
			"uncharted Unknown catch, logged / Item 99901 nil true",
			"uncharted Unknown catch, logged / Item 99902 nil nil",
		}, raised)
	end)

	it("merges a rebuild's new levels into one summary-only levelUp for the highest (LED-R93, LED-R97)", function()
		local raised = {}
		local global = { celebrated = { logId = "log" } }
		local def = ns.ProjectionDef(global, lookups, collecting(raised))
		local state = def.reset()
		-- 1,000 XP each: level 2 (1,080) at the second, level 3 (2,240) at the third.
		def.apply(state, reading(1, 80), "rebuild")
		def.apply(state, reading(2, 160), "rebuild")
		def.apply(state, reading(3, 230), "rebuild")

		def.done(state, { firstBuild = false, rebuilt = true, replayed = 0 })

		assert.are.same({
			"skillMilestone Skill Milestone / Fishing 75 nil true",
			"skillMilestone Skill Milestone / Fishing 150 nil true",
			"skillMilestone Skill Milestone / Fishing 225 nil true",
			"levelUp Angler Level 3 / +2 levels 40 true",
		}, raised)
		assert.are.same({ [0] = 3 }, global.celebrated.levels)
	end)

	it("clears the scratch list after done: the next done raises nothing again (LED-R98)", function()
		local raised = {}
		local def = ns.ProjectionDef({ celebrated = { logId = "log" } }, lookups, collecting(raised))
		local state = def.reset()
		def.apply(state, reading(1, 80), "rebuild")
		def.done(state, { firstBuild = false, rebuilt = true, replayed = 0 })

		def.done(state, { firstBuild = false, rebuilt = true, replayed = 0 })

		assert.are.equal(1, #raised)
	end)

	it("heads a first build with the Casts applied, as BreakUpLargeNumbers writes them (LED-R93)", function()
		local raised = {}
		local def = ns.ProjectionDef({}, lookups, collecting(raised))
		local state = def.reset()
		for seq = 1, 1234 do
			def.apply(state, gotAway(seq), "rebuild")
		end

		def.done(state, { firstBuild = true, rebuilt = true, replayed = 0 })

		assert.are.same({ { "Your Ledger was written up from 1,234 Casts", "Angler Level 1" } }, raised)
	end)

	it("writes up a catch-up's Skill Milestones, in the singular for one (LED-R94)", function()
		local raised = {}
		local def = ns.ProjectionDef({ celebrated = { logId = "log" } }, lookups, collecting(raised))
		local state = def.reset()
		def.apply(state, reading(1, 80), "replay")

		def.done(state, { firstBuild = false, rebuilt = false, replayed = 1 })

		assert.are.same({ { "While the Ledger was off", "1 Skill Milestone" } }, raised)
	end)

	it(
		"writes up no catch-up that earned nothing new: a celebrated Skill Milestone, a got-away Cast (LED-R93)",
		function()
			local raised = {}
			local global = { celebrated = { logId = "log", skill = { [75] = true } } }
			local def = ns.ProjectionDef(global, lookups, collecting(raised))
			local state = def.reset()
			def.apply(state, reading(1, 80), "replay")
			def.apply(state, gotAway(2), "replay")

			def.done(state, { firstBuild = false, rebuilt = false, replayed = 2 })

			assert.are.same({}, raised)
		end
	)
end)
