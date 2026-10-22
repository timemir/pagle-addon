-- The Ledger's climb at 1.0 on FakePagle (LED-R30–R32, LED-R37–R39, LED-R199; ADR 0011): the full Prestige cost,
-- another Module's Activity XP in the climb, read from Core and never stored, and the level-ups it brings, with a stub
-- paying Module reporting through M:ReportXPEarned (AXP-R2) as Hunts and the Tackle Board do.

local T0 = SERVER_TIME - 700
-- A zone the catalogue doesn't chart: no Zone Mastery rank adds to the numbers (LED-R54).
local ZONE = 12
-- Fish of their own Species. Landing TO_60 of them new in one Cast in a new zone reaches level 60 with 240 XP carried
-- (as adapter/Prestige_spec.lua works out): 200 for the zone, 610 a Species and 10 more for each of the first 300 in
-- Fresh Water (LED-R20, LED-R22), 200,840 against the 200,600 reaching 60 costs in every climb (LED-R30).
local FIRST_FISH, FISH_COUNT, TO_60 = 100001, 330, 324
-- One new Species in a new zone, in Fresh Water: 20 + 500 + 100 + 200 = 820 of the Ledger's own XP (LED-R20).
local FIRST_CAST_XP = 820
-- The roster's Module order (CORE-R41).
local ORDER = { Hunts = 20, TackleBoard = 40 }

-- A catalogue in the shape of ns.catalogue (DATA-R76): FISH_COUNT fish, each its own Species, and no area.
local function catalogue()
	local items = {}
	for id = FIRST_FISH, FIRST_FISH + FISH_COUNT - 1 do
		items[id] = fishRecord(id, { typicalLength = 300 })
	end
	return catalogueWith({ items = items })
end

-- `count` of the fish from fish number `from` (1 for the first), as item IDs.
local function fishes(from, count)
	local ids = {}
	for i = 1, count do
		ids[i] = FIRST_FISH + from + i - 2
	end
	return ids
end

-- Loot of one item each, for fake.playCast.
local function loot(itemIDs)
	local items = {}
	for i, itemID in ipairs(itemIDs) do
		items[i] = { itemID = itemID, quantity = 1 }
	end
	return items
end

-- A stub paying Module `name` on `fake` (AXP-R2): its lifetime Activity XP starts at `start` (0 by default), its
-- projection adds `perCast` to it at each live Cast and reports it there, and reports it from its done. Returns its
-- handle.
---@param fake FakePagle
---@param name string
---@param perCast integer?
---@param start integer?
---@return table
local function payingModule(fake, name, perCast, start)
	local handle = fake.Pagle.RegisterModule({ name = name, title = name, order = ORDER[name] })
	local total = start or 0
	handle:NewProjection({
		db = {},
		rulesVersion = 1,
		reset = function()
			return {}
		end,
		apply = function(_, record, mode)
			if mode == "live" and record.kind == "cast" and perCast then
				total = total + perCast
				handle:ReportXPEarned(total)
			end
		end,
		done = function()
			handle:ReportXPEarned(total)
		end,
	})
	return handle
end

-- A FakePagle with the Ledger loaded over the catalogue and `history`, fishing live in ZONE, logged in and, unless
-- `building`, in the world. `modules` (run before the Ledger loads, or after with `after`) registers the paying ones.
-- With `last`, it is the next session over that one's PagleLog and PagleLedgerDB.
---@param options { history: table[]?, building: boolean?, modules: fun(fake: FakePagle)?, after: boolean?, last: { fake: FakePagle, loaded: LoadedAddon }? }?
---@return FakePagle fake
---@return LoadedAddon loaded
local function session(options)
	options = options or {}
	local fake = newFakePagle()
	fake.setCatalogue(catalogue())
	fake.conditions.zone = ZONE
	local last = options.last
	if last then
		fake.catchLog.data = last.fake.catchLog.data
		fake.globals.PagleLedgerDB = last.loaded.env.PagleLedgerDB
	end
	fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
	for _, record in ipairs(options.history or {}) do
		fake.catchLog:Append(record)
	end
	fake.globals.BreakUpLargeNumbers = breakUpLargeNumbers
	if options.modules and not options.after then
		options.modules(fake)
	end
	local loaded = fake.load("Pagle_Ledger")
	if options.modules and options.after then
		options.modules(fake)
	end
	fake.login()
	if not options.building then
		fake.enterWorld()
		fake.nextFrame()
	end
	return fake, loaded
end

-- The Ledger's state now.
---@param loaded LoadedAddon
---@return LedgerState
local function stateOf(loaded)
	return loaded.ns.projection:GetState()
end

-- The ink XP bar's words now (LED-R145).
---@param loaded LoadedAddon
---@return string
local function barText(loaded)
	local ns = loaded.ns
	return ns.InkXpBar(stateOf(loaded), ns.SavedCelebrated(), SERVER_TIME, breakUpLargeNumbers).text
end

-- Every levelUp moment Core kept from `from` on (shown or summary-only), in order.
---@param fake FakePagle
---@param from integer? the first index of fake.summarized to look at
---@return PagleRaisedMoment[]
local function levelUps(fake, from)
	local found = {}
	for i = from or 1, #fake.summarized do
		if fake.summarized[i].kind == "levelUp" then
			found[#found + 1] = fake.summarized[i]
		end
	end
	return found
end

describe("the Ledger's climb at 1.0", function()
	it("makes the step from level 1 to 2 after a Prestige cost 1,080, as in the first climb (LED-R30)", function()
		local fake, loaded = session({ history = { castRecord({ time = T0, zone = ZONE, items = fishes(1, TO_60) }) } })
		assert.are.equal(60, loaded.ns.Level(stateOf(loaded)))

		fake.prestige()

		assert.are.same({ 1, 240 }, { loaded.ns.Level(stateOf(loaded)), stateOf(loaded).xp })
		assert.are.equal("240 of 1,080.", barText(loaded))
	end)

	it(
		"raises the computed level with a Module's 2,000 Activity XP as 2,000 more Ledger XP would, never doubled (LED-R37, LED-R38, LED-R22)",
		function()
			local hunts
			local fake, loaded = session({
				modules = function(f)
					hunts = payingModule(f, "Hunts")
				end,
			})
			local ns = loaded.ns
			assert.are.equal(ns.FRESH_WATER_CAP, ns.FreshWaterShown(stateOf(loaded), SERVER_TIME))

			hunts:ReportXPEarned(2000)

			-- 2,000 is 920 into level 2's 1,160 step (LED-R30); doubled, it would be level 3.
			assert.are.same({ 2, 920, 1160 }, { ns.Climb(stateOf(loaded)) })
			assert.are.same({ 0, 0 }, { stateOf(loaded).xp, stateOf(loaded).lifetimeXP })
			assert.are.equal("920 of 1,160.", barText(loaded))
			assert.matches("^Ledger: Angler Level 2 ", fake.global.summary.lines.Ledger.lines.ledger)
		end
	)

	it(
		"keeps the shown level after a report of 0, the XP bar waiting at 0 of its step, and takes the Coins back (LED-R38, LED-R36, AXP-R4)",
		function()
			local hunts
			local fake, loaded = session({
				modules = function(f)
					hunts = payingModule(f, "Hunts")
				end,
			})
			hunts:ReportXPEarned(2000)
			local raised = #fake.summarized

			hunts:ReportXPEarned(0)

			local ns = loaded.ns
			assert.are.same(
				{ 1, 2 },
				{ ns.Level(stateOf(loaded)), ns.ShownLevel(stateOf(loaded), ns.SavedCelebrated()) }
			)
			assert.are.equal("0 of 1,160.", barText(loaded))
			assert.are.equal(raised, #fake.summarized)
			assert.matches("^Ledger: Angler Level 2 ", fake.global.summary.lines.Ledger.lines.ledger)
			assert.are.same({ 20, 0 }, {
				fake.coinReports[#fake.coinReports - 1].total,
				fake.coinReports[#fake.coinReports].total,
			})
		end
	)

	it(
		"gives the new climb the Activity XP since the Prestige entry's snapshot: 5,600 after 5,000 is 600 (LED-R37, LED-R32, AXP-R5)",
		function()
			local hunts
			local fake, loaded = session({
				history = { castRecord({ time = T0, zone = ZONE, items = fishes(1, TO_60) }) },
				modules = function(f)
					hunts = payingModule(f, "Hunts")
				end,
			})
			local ns = loaded.ns
			hunts:ReportXPEarned(5000)

			local entry = fake.prestige()

			-- The ending climb counts its 5,000 Activity XP: 240 + 5,000 carried, level 5 of the new climb, whose
			-- levels are the Prestige entry's (LED-R32).
			assert.are.same({ 5000, 5000, 5240 }, {
				entry.activityXP,
				stateOf(loaded).prestigeActivityXP,
				stateOf(loaded).xp,
			})
			assert.are.same({ 0, 5 }, { ns.ClimbActivityXP(stateOf(loaded)), ns.Level(stateOf(loaded)) })
			local prestigeLevels = levelUps(fake)
			assert.is_nil(prestigeLevels[#prestigeLevels].cast)

			hunts:ReportXPEarned(5600)

			assert.are.same({ 600, 5, 1040, 1400 }, { ns.ClimbActivityXP(stateOf(loaded)), ns.Climb(stateOf(loaded)) })
		end
	)

	for _, order in ipairs({ "after", "before" }) do
		it(
			"raises one levelUp with the Cast's ID for a report during its live apply, the paying Module applying "
				.. order
				.. " the Ledger (LED-R39, ANN-R10)",
			function()
				-- The Cast's 820 of the Ledger's own XP stays in level 1; with Hunts' 300 it reaches level 2.
				local fake = session({
					modules = function(f)
						payingModule(f, "Hunts", 300)
					end,
					after = order == "after",
				})

				local record = assert(fake.playCast("caught", loot(fishes(1, 1))))
				fake.nextFrame()

				local raised = levelUps(fake)
				assert.are.equal(1, #raised)
				assert.are.same({ record.id, "Angler Level 2" }, { raised[1].cast, raised[1].title })
				assert.is_nil(raised[1].summaryOnly)
				-- The Cast's Announcements (a banner and a toast, ANN-R11) hold its levelUp with its New Species, and
				-- every moment in them is the Cast's.
				local kinds = {}
				for _, announcement in ipairs(fake.announcements) do
					for _, moment in ipairs(announcement.moments) do
						assert.are.equal(record.id, moment.cast)
						kinds[moment.kind] = true
					end
				end
				assert.are.same({ true, true }, { kinds.levelUp, kinds.newSpecies })
				assert.is_true(FIRST_CAST_XP < 1080 and FIRST_CAST_XP + 300 >= 1080)
			end
		)
	end

	for _, order in ipairs({ "after", "before" }) do
		it(
			"raises the levelUp summary-only for a report from another Module's done, that Module finishing "
				.. order
				.. " the Ledger (LED-R39, ANN-R63)",
			function()
				-- A first session, whose Ledger's done celebrates its level 1; at the next login, Hunts' done reports
				-- 2,000 it earned meanwhile.
				local last, lastLoaded = session()
				local fake, loaded = session({
					last = { fake = last, loaded = lastLoaded },
					modules = function(f)
						payingModule(f, "Hunts", nil, 2000)
					end,
					after = order == "after",
				})

				local raised = levelUps(fake)
				assert.are.equal(1, #raised)
				assert.are.same(
					{ "Angler Level 2", true, 20 },
					{ raised[1].title, raised[1].summaryOnly, raised[1].coins }
				)
				assert.is_nil(raised[1].cast)
				assert.are.same({}, fake.announcements)
				assert.are.equal(2, loaded.ns.SavedCelebrated().levels[0])
				assert.are.equal(20, fake.coinReports[#fake.coinReports].total)
			end
		)
	end

	it("waits while the Ledger is updating, and raises the level-up from its done (LED-R39, LED-R93)", function()
		local last, lastLoaded = session()
		local hunts
		local fake, loaded = session({
			last = { fake = last, loaded = lastLoaded },
			building = true,
			-- A paying Module with no projection, reporting outside any apply.
			modules = function(f)
				hunts = f.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = ORDER.Hunts })
			end,
		})
		assert.is_true(loaded.ns.projection:IsUpdating())
		hunts:ReportXPEarned(2000)
		fake.nextFrame()
		assert.are.same({}, levelUps(fake))

		fake.enterWorld()
		fake.nextFrame()
		fake.nextFrame()

		local raised = levelUps(fake)
		assert.are.equal(1, #raised)
		assert.are.same({ "Angler Level 2", true }, { raised[1].title, raised[1].summaryOnly })
		assert.are.equal(20, fake.coinReports[#fake.coinReports].total)
		assert.are.equal(2, loaded.ns.ShownLevel(stateOf(loaded), loaded.ns.SavedCelebrated()))
	end)

	it("never rebuilds or folds anything again for a Module's report (LED-R37, ADR 0011)", function()
		local hunts
		local fake, loaded = session({
			history = { castRecord({ time = T0, zone = ZONE, items = fishes(1, 3) }) },
			modules = function(f)
				hunts = payingModule(f, "Hunts")
			end,
		})
		local state, db = stateOf(loaded), loaded.env.PagleLedgerDB.global.projection
		local stored = { db.lastSeq, db.rulesVersion, db.fingerprint }
		local before = { state.xp, state.coins, state.casts }
		local sections = #fake.writeUps

		hunts:ReportXPEarned(4000)
		hunts:ReportXPEarned(1500)

		assert.are.equal(state, stateOf(loaded))
		assert.are.same(stored, { db.lastSeq, db.rulesVersion, db.fingerprint })
		assert.are.same(before, { state.xp, state.coins, state.casts })
		assert.is_false(loaded.ns.projection:IsUpdating())
		assert.are.equal(sections, #fake.writeUps)
	end)

	it(
		"reports the Coins of the levels Activity XP brings, and refreshes the bindings when it passes level 10 (LED-R89, LED-R111)",
		function()
			local hunts
			local fake = session({
				modules = function(f)
					hunts = payingModule(f, "Hunts")
				end,
			})
			assert.is_false(fake.Pagle.IsOwned("ledger.binding.level10"))

			-- 12,600 XP reaches level 10 (LED-R30): 9 levels, 180 Coins (LED-R88).
			hunts:ReportXPEarned(12600)

			assert.are.equal(180, fake.coinReports[#fake.coinReports].total)
			assert.is_true(fake.Pagle.IsOwned("ledger.binding.level10"))
			assert.is_false(fake.Pagle.IsOwned("ledger.binding.level20"))
		end
	)
end)
