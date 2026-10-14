-- Hunts' projection (HNT-R13, HNT-R25–R27, HNT-R110, HNT-R136–R138; LOG-R70–R77) on FakePagle, over the fixture
-- Hunt list and the fixture catalogue: a history of Casts appended to fake.catchLog, then login, then live Casts.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")
---@diagnostic disable-next-line: undefined-global -- as above
local catalogue = dofile("spec/Pagle_Hunts/fixtures/Catalogue.lua")

local C = catalogue
local MARCH_1 = 1772323200 -- 2026-03-01 00:00 UTC: every fixture Hunt but fixture_tide_late and fixture_grouper exists
local JUNE_1 = 1780272000 -- 2026-06-01, the fixture's retired date
local RACK_AURA = 1280341 -- fixture_rack's aura
local UNCOMMON = 6643 -- a quality.uncommon member (fixture_rack's class)
local NIGHT, DAY, DUSK = 1320, 600, 1140 -- realm minutes: 22:00 (night), 10:00 (day), 19:00 (fixture_oddity's hours)

-- The server time of realm minute `minute` on 2026-03-(1 + day), on a realm 7 hours behind UTC.
---@param day integer
---@param minute integer
---@return integer
local function at(day, minute)
	return MARCH_1 + day * 86400 + (minute + 420) * 60
end

-- A Cast record for fake.catchLog:Append, by the player's character (char 1), at realm `minute` of `day`.
---@param day integer
---@param minute integer?
---@param where { zone: integer, subzone: integer? }
---@param itemIDs integer[]? nil for a got-away Cast
---@param auras integer[]?
local function cast(day, minute, where, itemIDs, auras)
	local items = {}
	for i, itemID in ipairs(itemIDs or {}) do
		items[i] = { itemID = itemID, quantity = 1 }
	end
	return {
		kind = "cast",
		char = 1,
		time = at(day, minute or NIGHT),
		outcome = itemIDs and "caught" or "gotAway",
		conditions = {
			minute = minute,
			zone = where.zone,
			subzone = where.subzone or 0,
			events = {},
			auras = auras or {},
		},
		items = items,
	}
end

local AUBERDINE = { zone = C.DARKSHORE, subzone = C.AUBERDINE }
local DARKSHORE = { zone = C.DARKSHORE }
local WESTFALL = { zone = C.WESTFALL }
local ELWYNN = { zone = C.ELWYNN }

-- Appends `records` to fake.catchLog (the player's character first) and returns them as appended, Catch IDs and
-- realm dates filled in by Core's codec.
---@param fake table
---@param records table[]
---@return PagleCast[]
local function append(fake, records)
	fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
	local appended = {}
	for _, record in ipairs(records) do
		appended[#appended + 1] = fake.catchLog:Append(record)
	end
	return appended
end

-- The history: a night Nightfin in its waters, a got-away Cast there, a day Nightfin, a night Cast outside its
-- waters, a Deviate Fish in fixture_oddity's hours, then an uncommon item under the Rack's aura in those hours too.
---@param fake table
---@return PagleCast[]
local function withHistory(fake)
	return append(fake, {
		cast(0, NIGHT, AUBERDINE, { C.NIGHTFIN }),
		cast(0, NIGHT + 30, AUBERDINE),
		cast(1, DAY, DARKSHORE, { C.NIGHTFIN }),
		cast(1, NIGHT + 60, WESTFALL),
		cast(2, DUSK, DARKSHORE, { C.DEVIATE }),
		cast(2, DUSK + 30, DARKSHORE, { UNCOMMON }, { RACK_AURA }),
	})
end

-- Pagle_Hunts on a FakePagle serving the fixture catalogue (or `options.data`), with `history(fake)` appended before
-- login, then logged in and caught up. `options.prepare(loaded)` runs before Hunts' ADDON_LOADED; `options.fake` is a
-- FakePagle already set up (a next session's).
---@param history (fun(fake: table): any)?
---@param options { data: table?, prepare: fun(loaded: LoadedAddon)?, fake: table? }?
---@return LoadedAddon loaded
---@return table fake
---@return any appended what `history` returned
local function session(history, options)
	options = options or {}
	local fake = options.fake or newFakePagle()
	fake.setCatalogue(options.data or catalogue.base())
	local appended = history and history(fake)
	local loaded = hunts.load(fake, { prepare = options.prepare })
	fake.login()
	fake.enterWorld()
	return loaded, fake, appended
end

-- The next session on the same machine: a new FakePagle over the same Catch log and the PagleHuntsDB the last one
-- saved (its global section: the fake client has no strlenutf8 for AceDB's profile keys).
---@param last table the last session's FakePagle
---@param lastLoaded LoadedAddon
---@return table fake
local function nextSession(last, lastLoaded)
	local fake = newFakePagle()
	fake.catchLog.data = last.catchLog.data
	fake.globals.PagleHuntsDB = { global = lastLoaded.env.PagleHuntsDB.global }
	return fake
end

-- A deep copy of a table of plain values, to compare a state with a later one.
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, item in pairs(value) do
		out[key] = copy(item)
	end
	return out
end

-- The HuntTier a Catch reached (HNT-R15): its Cast's time, Catch ID, item, zone and realm date (2026-03-(1 + day)).
local function tier(record, day)
	local catch = record.items[1]
	return {
		time = record.time,
		catchId = catch.catchId,
		itemID = catch.itemID,
		zone = record.conditions.zone,
		date = { year = 2026, month = 3, day = 1 + day },
	}
end

-- Notes each call of Hunts' outlets (#196's) in `calls`, from a load's prepare on.
---@param calls table
---@return fun(loaded: LoadedAddon)
local function noteOutlets(calls)
	return function(loaded)
		loaded.ns.outlets.Reached = function(record, reached)
			calls[#calls + 1] = { "Reached", record.seq, copy(reached) }
		end
		loaded.ns.outlets.Done = function(_, info)
			calls[#calls + 1] = { "Done", copy(info) }
		end
	end
end

-- Moves the live conditions to realm `minute` in `where`, with `auras` up (none by default).
---@param fake table
---@param minute integer
---@param where { zone: integer, subzone: integer? }
---@param auras integer[]?
local function fishAt(fake, minute, where, auras)
	local conditions = copy(fake.conditions)
	conditions.minute, conditions.zone, conditions.subzone = minute, where.zone, where.subzone or 0
	conditions.auras = auras or {}
	fake.setConditions(conditions)
end

-- The Coins reports Core accepted from Hunts (SHOP-R2), in order.
local function huntsReports(fake)
	local totals = {}
	for _, report in ipairs(fake.coinReports) do
		if report.module == "Hunts" then
			totals[#totals + 1] = report.total
		end
	end
	return totals
end

describe("Hunts' projection", function()
	it("builds the HuntsState of a history: Casts, counts, tiers, effort and a set title (HNT-R137)", function()
		local loaded, _, records = session(withHistory)

		assert.are.same({
			casts = 6,
			-- fixture_snapper, fixture_oddity and fixture_rack completed, and fixture_wagers' title (HNT-R110).
			coins = 30 + 30 + 30 + 100,
			-- No entry for a Hunt with neither effort nor a Catch, such as fixture_tide_late, whose since (2026-04-01)
			-- is after these Nightfin (HNT-R13), or fixture_sunscale, fished for nowhere by day.
			hunts = {
				fixture_snapper = {
					count = 2,
					effort = 2,
					sinceLast = 0,
					caught = true,
					reached = { tier(records[1], 0) },
				},
				-- Effort without a Catch: its 22:00–04:00 hours in its waters, Darkshore and Westfall (HNT-R25).
				fixture_hefty_blackmouth = { count = 0, effort = 3, sinceLast = 3, caught = false, reached = {} },
				fixture_oddity = {
					count = 1,
					effort = 2,
					sinceLast = 1,
					caught = true,
					reached = { tier(records[5], 2) },
				},
				fixture_rack = {
					count = 1,
					effort = 1,
					sinceLast = 0,
					caught = true,
					reached = { tier(records[6], 2) },
				},
			},
			sets = {
				-- fixture_grouper doesn't exist yet, so oddity and rack complete fixture_wagers (HNT-R20).
				fixture_wagers = {
					earnedAt = records[6].time,
					date = { year = 2026, month = 3, day = 3 },
					fromRetirement = false,
				},
			},
		}, loaded.ns.State())
	end)

	it("reads only Casts: a Skill Reading and a build entry change nothing (HNT-R136)", function()
		local loaded = session(function(fake)
			append(fake, { cast(0, NIGHT, AUBERDINE) })
			fake.catchLog:Append({ kind = "skill", char = 1, time = at(0, NIGHT + 1), rank = 150, max = 225, mod = 0 })
			fake.catchLog.data.entries[#fake.catchLog.data.entries + 1] = BUILD_ENTRY
		end)

		local state = loaded.ns.State()
		assert.are.equal(1, state.casts)
		assert.are.same({ 1, 1 }, { state.hunts.fixture_snapper.effort, state.hunts.fixture_hefty_blackmouth.effort })
	end)

	describe("effort (HNT-R25–R27)", function()
		it("counts a night Hunt's night Casts in its waters, caught or not, and no day Cast", function()
			local loaded = session(function(fake)
				append(fake, {
					cast(0, NIGHT, AUBERDINE), -- night, a subzone of its waters
					cast(0, NIGHT + 1, { zone = C.ASHENVALE }, { C.SMALLFISH }), -- night, caught, its waters
					cast(1, DAY, AUBERDINE), -- day
					cast(1, NIGHT, ELWYNN), -- night, not its waters
				})
			end)

			local snapper = loaded.ns.State().hunts.fixture_snapper
			assert.are.same({ 2, 2, 0 }, { snapper.effort, snapper.sinceLast, snapper.count })
		end)

		it("resets the Casts since the latest qualifying Catch on its Cast, after counting it (HNT-R26)", function()
			local loaded = session(function(fake)
				append(fake, {
					cast(0, NIGHT, AUBERDINE),
					cast(0, NIGHT + 1, AUBERDINE),
					cast(0, NIGHT + 2, AUBERDINE, { C.NIGHTFIN }),
					cast(0, NIGHT + 3, AUBERDINE),
				})
			end)

			local snapper = loaded.ns.State().hunts.fixture_snapper
			assert.are.same({ 4, 1, 1 }, { snapper.effort, snapper.sinceLast, snapper.count })
		end)

		it("resets it on a qualifying Catch that isn't an effort Cast too (HNT-R26)", function()
			local loaded = session(function(fake)
				append(fake, {
					cast(0, NIGHT, AUBERDINE),
					cast(1, DAY, { zone = C.ELWYNN }, { C.NIGHTFIN }), -- day, not its waters: still its Species
				})
			end)

			local snapper = loaded.ns.State().hunts.fixture_snapper
			assert.are.same({ 1, 0, 1 }, { snapper.effort, snapper.sinceLast, snapper.count })
		end)

		it("is none for a Hunt without a board spec, whose Catches still count (HNT-R7, HNT-R25)", function()
			-- A release that dropped the night window's spec: fixture_snapper keeps its waters but has no board spec.
			local data = catalogue.base()
			data.windows.night = nil
			local loaded = session(function(fake)
				append(fake, { cast(0, NIGHT, AUBERDINE), cast(0, NIGHT + 1, AUBERDINE, { C.NIGHTFIN }) })
			end, { data = data })

			local snapper = loaded.ns.State().hunts.fixture_snapper
			assert.are.same({ 0, 0, 1 }, { snapper.effort, snapper.sinceLast, snapper.count })
		end)

		it("counts every Cast under an aura-only Hunt's aura, anywhere and at any hour (HNT-R25)", function()
			local loaded = session(function(fake)
				append(fake, {
					cast(0, DAY, WESTFALL, nil, { RACK_AURA }),
					cast(0, NIGHT, ELWYNN, { C.SMALLFISH }, { RACK_AURA }),
					cast(1, DUSK, DARKSHORE, nil, { RACK_AURA }),
					cast(1, DUSK + 1, DARKSHORE), -- no aura
				})
			end)

			local rack = loaded.ns.State().hunts.fixture_rack
			assert.are.same({ 3, 3, 0 }, { rack.effort, rack.sinceLast, rack.count })
		end)

		it("is plain counts: a Hunt's progress holds no odds or rates (HNT-R27)", function()
			local loaded = session(withHistory)

			for _, progress in pairs(loaded.ns.State().hunts) do
				local keys = {}
				for key in pairs(progress) do
					keys[#keys + 1] = key
				end
				table.sort(keys)
				assert.are.same({ "caught", "count", "effort", "reached", "sinceLast" }, keys)
			end
		end)
	end)

	describe("Coins (HNT-R110)", function()
		it("sums 30 per completion, 15 per further tier and 100 per title, and reports it from done", function()
			-- fixture_rack's tiers are 1 and 5: five uncommon items under its aura reach both.
			local loaded, fake = session(function(fake)
				withHistory(fake)
				append(fake, {
					cast(3, DAY, WESTFALL, { UNCOMMON, UNCOMMON }, { RACK_AURA }),
					cast(3, DAY + 1, WESTFALL, { UNCOMMON, UNCOMMON }, { RACK_AURA }),
				})
			end)

			local state = loaded.ns.State()
			assert.are.same({ 5, 2 }, { state.hunts.fixture_rack.count, #state.hunts.fixture_rack.reached })
			assert.are.equal(3 * 30 + 15 + 100, state.coins)
			assert.are.same({ 3 * 30 + 15 + 100 }, huntsReports(fake))
		end)

		it("counts a title a retirement completed, found in done at now (HNT-R23, HNT-R197)", function()
			-- fixture_hefty_blackmouth retired with fixture_sunscale: from 2026-06-01 fixture_snapper, done in March,
			-- is fixture_dusk's only Hunt.
			local loaded, fake = session(withHistory, {
				prepare = function(loaded)
					loaded.ns.huntList.hunts[4].retired = JUNE_1
				end,
			})

			local state = loaded.ns.State()
			assert.are.same(
				{ earnedAt = JUNE_1, date = { year = 2026, month = 6, day = 1 }, fromRetirement = true },
				state.sets.fixture_dusk
			)
			assert.are.equal(3 * 30 + 2 * 100, state.coins)
			assert.are.same({ 3 * 30 + 2 * 100 }, huntsReports(fake))
		end)

		it("reports after a live Catch that changes it, and not after one that doesn't (SHOP-R2)", function()
			local _, fake = session(withHistory)
			fishAt(fake, NIGHT, AUBERDINE)

			fake.playCast("caught", { { itemID = C.SMALLFISH, quantity = 1 } })
			-- fixture_tide_late (since 2026-04-01) completes on today's first Nightfin; fixture_snapper is done.
			fake.playCast("caught", { { itemID = C.NIGHTFIN, quantity = 1 } })
			fake.playCast("caught", { { itemID = C.NIGHTFIN, quantity = 1 } })

			assert.are.same({ 190, 190 + 30 }, huntsReports(fake))
		end)
	end)

	describe("the outlets and redraws (HNT-R137, #196)", function()
		it("hand a live Cast's newly reached tiers to Reached, and redraw after done and each live Cast", function()
			local calls, redraws = {}, {}
			local _, fake = session(withHistory, {
				prepare = function(loaded)
					noteOutlets(calls)(loaded)
					loaded.ns.OnRedraw(function(reason)
						redraws[#redraws + 1] = reason
					end)
				end,
			})
			fishAt(fake, NIGHT, AUBERDINE, { RACK_AURA })

			-- A got-away Cast reaches nothing; then 4 uncommon items reach fixture_rack's tier 2 and a Nightfin
			-- fixture_tide_late's completion, in the Hunt list's order.
			fake.playCast("gotAway")
			local live = fake.playCast("caught", {
				{ itemID = UNCOMMON, quantity = 1 },
				{ itemID = UNCOMMON, quantity = 1 },
				{ itemID = UNCOMMON, quantity = 1 },
				{ itemID = UNCOMMON, quantity = 1 },
				{ itemID = C.NIGHTFIN, quantity = 1 },
			})

			assert.are.same({
				{ "Done", { firstBuild = true, rebuilt = true, replayed = 0 } },
				{
					"Reached",
					live.seq,
					{
						tiers = { { hunt = "fixture_rack", tier = 2 }, { hunt = "fixture_tide_late", tier = 1 } },
						sets = {},
					},
				},
			}, calls)
			-- One redraw from done, then one for each live Cast (HNT-R42).
			assert.are.same({ "projection", "projection", "projection" }, redraws)
			assert.are.same({ 190, 190 + 15 + 30 }, huntsReports(fake))
		end)

		it("hand a live set title to Reached with the Cast that earned it (HNT-R87)", function()
			local calls = {}
			local _, fake = session(function(fake)
				append(fake, { cast(2, DUSK, DARKSHORE, { C.DEVIATE }) })
			end, { prepare = noteOutlets(calls) })
			fishAt(fake, DAY, WESTFALL, { RACK_AURA })

			local live = fake.playCast("caught", { { itemID = UNCOMMON, quantity = 1 } })

			assert.are.same({
				"Reached",
				live.seq,
				{ tiers = { { hunt = "fixture_rack", tier = 1 } }, sets = { "fixture_wagers" } },
			}, calls[2])
			assert.are.same({ 30, 30 + 30 + 100 }, huntsReports(fake))
		end)

		it("hand nothing to Reached while rebuilding or catching up (HNT-R85, LOG-R75)", function()
			local calls = {}
			local loaded, fake = session(withHistory, { prepare = noteOutlets(calls) })
			local replayed = append(fake, { cast(3, NIGHT, AUBERDINE, { C.NIGHTFIN }) })

			local next = nextSession(fake, loaded)
			local again = {}
			session(nil, { fake = next, prepare = noteOutlets(again) })

			assert.are.same({ { "Done", { firstBuild = true, rebuilt = true, replayed = 0 } } }, calls)
			assert.are.same({ { "Done", { firstBuild = false, rebuilt = false, replayed = #replayed } } }, again)
		end)
	end)

	describe("rebuilds and catch-ups (HNT-R136, HNT-R191, LOG-R72)", function()
		-- A first session over the history (with helpers.lua's history of three day Casts in Darkshore before it),
		-- then the next one, `prepare`d: what its done was told, the state it holds, and the first one's.
		local function rebuildOf(prepare)
			local first, firstFake = session(function(fake)
				for _, entry in ipairs(history(3)) do
					fake.catchLog.data.entries[#fake.catchLog.data.entries + 1] = entry
				end
				withHistory(fake)
			end)
			local before = copy(first.ns.State())
			local calls = {}
			local loaded = session(nil, {
				fake = nextSession(firstFake, first),
				prepare = function(loaded)
					noteOutlets(calls)(loaded)
					if prepare then
						prepare(loaded)
					end
				end,
			})
			return calls[1][2], loaded.ns.State(), before, loaded
		end

		it("keep the state the log built, with nothing to apply, while nothing changed (LOG-R71)", function()
			local info, state, before = rebuildOf(nil)

			assert.are.same({ firstBuild = false, rebuilt = false, replayed = 0 }, info)
			assert.are.same(before, state)
			assert.are.equal(9, state.casts)
		end)

		it("rebuild from seq 0 to the same state when the Hunt list's fingerprint changes (DATA-R72)", function()
			local info, state, before, loaded = rebuildOf(function(loaded)
				loaded.ns.huntList.fingerprint = "f1c7f1c7f1c70002"
			end)

			assert.are.same({ firstBuild = false, rebuilt = true, replayed = 0 }, info)
			assert.are.same(before, state)
			assert.matches("%+f1c7f1c7f1c70002$", loaded.env.PagleHuntsDB.global.projection.fingerprint)
		end)

		it("rebuild from seq 0 to the same state when the rules version changes (HNT-R138)", function()
			local info, state, before, loaded = rebuildOf(function(loaded)
				loaded.ns.HUNTS_RULES_VERSION = 2
			end)

			assert.are.same({ firstBuild = false, rebuilt = true, replayed = 0 }, info)
			assert.are.same(before, state)
			assert.are.equal(2, loaded.env.PagleHuntsDB.global.projection.rulesVersion)
		end)

		it("store the rules version 1 and the Hunt list's fingerprint after the content's (HNT-R136)", function()
			local loaded, fake = session(withHistory)

			local db = loaded.env.PagleHuntsDB.global.projection
			assert.are.equal(1, loaded.ns.HUNTS_RULES_VERSION)
			assert.are.same(
				{ 1, fake.Pagle.CONTENT_FINGERPRINT .. "+f1c7f1c7f1c7f1c7", 6 },
				{ db.rulesVersion, db.fingerprint, db.lastSeq }
			)
			assert.are.equal(loaded.ns.State(), db.projection)
		end)

		it("count Casts recorded while Hunts was off, in the catch-up (HNT-R13, LOG-R90)", function()
			local first, firstFake = session(withHistory)
			-- While Hunts was off: two night Casts at Auberdine, one with a Nightfin.
			append(firstFake, { cast(3, NIGHT, AUBERDINE), cast(3, NIGHT + 1, AUBERDINE, { C.NIGHTFIN }) })

			local loaded = session(nil, { fake = nextSession(firstFake, first) })

			local snapper = loaded.ns.State().hunts.fixture_snapper
			assert.are.same(
				{ 8, 4, 0, 3 },
				{ loaded.ns.State().casts, snapper.effort, snapper.sinceLast, snapper.count }
			)
		end)
	end)

	describe("the seams it binds (HNT-R69, LOG-R74)", function()
		it("ns.IsUpdating() is true until the first build finishes, and through a rebuild's applies", function()
			local fake = newFakePagle()
			fake.setCatalogue(catalogue.base())
			withHistory(fake)
			local loaded = hunts.load(fake)
			local seen = {}
			local apply = loaded.ns.ApplyCast
			loaded.ns.ApplyCast = function(...)
				seen[#seen + 1] = loaded.ns.IsUpdating()
				return apply(...)
			end

			fake.login()
			assert.is_true(loaded.ns.IsUpdating())
			fake.enterWorld()

			assert.is_false(loaded.ns.IsUpdating())
			assert.are.same({ true, true, true, true, true, true }, seen)
		end)

		it("ns.State() is the projection's state, live Casts included", function()
			local loaded, fake = session(withHistory)
			fishAt(fake, NIGHT, AUBERDINE)

			fake.playCast("gotAway")

			assert.are.equal(loaded.ns.projection:GetState(), loaded.ns.State())
			assert.are.same({ 7, 3, 1 }, {
				loaded.ns.State().casts,
				loaded.ns.State().hunts.fixture_snapper.effort,
				loaded.ns.State().hunts.fixture_snapper.sinceLast,
			})
		end)
	end)

	it("counts a Catch whose Cast has no realm minute (a secret clock), dating its tier by the UTC day", function()
		local loaded, _, records = session(function(fake)
			return append(fake, { cast(0, nil, { zone = C.ELWYNN }, { C.NIGHTFIN }) })
		end)

		local snapper = loaded.ns.State().hunts.fixture_snapper
		assert.are.equal(1, snapper.count)
		-- Realm 22:00 on 2026-03-01 is 05:00 UTC on 2026-03-02.
		assert.are.same({ year = 2026, month = 3, day = 2 }, snapper.reached[1].date)
		assert.is_nil(records[1].conditions.date)
	end)
end)
