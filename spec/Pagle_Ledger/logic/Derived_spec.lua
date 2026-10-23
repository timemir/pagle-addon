-- The values Pagle's backend reads from the Ledger's state (#223, #76 item 5; logic/Derived.lua): its leaderboard
-- measures, the computed titles, the zones mastered and lifetime Catches, each a function of a projection state alone,
-- on FakePagle over a fixture catalogue. The world index they read is the one the Ledger's projection is bound with
-- (ns.world): the adapter's here, ns.BindProjections' in the backend's driver (spec/logic_alone_spec.lua).

local MACKEREL, SMALLFISH, NIGHTFISH, LEGEND = 6303, 6291, 13759, 19803
local ELWYNN, WESTFALL = 12, 40

-- Elwynn lists Mackerel alone, so its one Catch masters it (LED-R50). Westfall lists Smallfish and a night fish. The
-- Legend is on no list.
local function fixture()
	return catalogueWith({
		items = {
			[MACKEREL] = fishRecord(MACKEREL),
			[SMALLFISH] = fishRecord(SMALLFISH),
			[NIGHTFISH] = fishRecord(NIGHTFISH),
			[LEGEND] = fishRecord(LEGEND, { legend = true }),
		},
		areas = {
			[ELWYNN] = areaRecord(0, { skillBase = 1, catches = { catchEntry(MACKEREL) } }),
			[WESTFALL] = areaRecord(0, {
				skillBase = 1,
				catches = { catchEntry(SMALLFISH), catchEntry(NIGHTFISH, "night", NIGHT_WINDOW) },
			}),
		},
		windows = { night = { spec = NIGHT_WINDOW, confirmed = true } },
	})
end

-- The Ledger loaded on a fake over the fixture, its log holding `records`, logged in and built. `saved` is a saved
-- PagleLedgerDB.
---@param records table[]
---@param saved table?
---@param catalogue table? another catalogue than the fixture's
---@param logId string? the log's logId, for a saved celebrated set that keeps it (LED-R90)
---@return PagleLedgerNS ns
---@return LedgerState state the projection's, built
---@return FakePagle fake
local function ledgerOver(records, saved, catalogue, logId)
	local fake = newFakePagle()
	fake.setCatalogue(catalogue or fixture())
	fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
	if logId then
		fake.catchLog.data.logId = logId
	end
	for _, record in ipairs(records) do
		fake.catchLog:Append(record)
	end
	fake.globals.PagleLedgerDB = saved
	local ns = fake.load("Pagle_Ledger").ns
	fake.login()
	fake.enterWorld()
	local state = ns.StateNow() --[[@as LedgerState]]
	return ns, state, fake
end

local T0 = SERVER_TIME - 7000

-- Mackerel in Elwynn, a Cast that got away, then Smallfish and the Legend on one Cast in Westfall.
local HISTORY = {
	castRecord({ time = T0, zone = ELWYNN, items = { MACKEREL } }),
	castRecord({ time = T0 + 60, zone = ELWYNN, outcome = "gotAway" }),
	castRecord({ time = T0 + 120, zone = WESTFALL, items = { SMALLFISH, LEGEND } }),
}

describe("the Ledger's values for the backend (#223)", function()
	describe("before any Catch", function()
		local ns, state
		setup(function()
			ns, state = ledgerOver({})
		end)

		it("measures level 1 with no XP, no Prestige and nothing of the Ledger done", function()
			assert.are.same({
				anglerLevel = { prestige = 0, level = 1, xp = 0 },
				ledgerCompletion = { percent = 0, done = 0, total = 5 },
				speciesCaught = 0,
				legendsCaught = 0,
			}, ns.Measures(state))
		end)

		it("has earned the level 1 title alone, which is the automatic one (LED-R75, LED-R77)", function()
			assert.are.same({ "title:level1" }, ns.EarnedTitles(state))
			assert.are.equal("title:level1", ns.AutomaticTitle(state))
		end)

		it("has mastered no zone and caught nothing", function()
			assert.are.same({ 0, 0 }, { ns.ZonesMastered(state), ns.LifetimeCatches(state) })
		end)
	end)

	describe("after the history", function()
		local ns, state
		setup(function()
			ns, state = ledgerOver(HISTORY)
		end)

		it("counts the Catches, not the Casts (LED-R42)", function()
			assert.are.equal(3, ns.LifetimeCatches(state))
		end)

		it("counts Elwynn mastered and Westfall not (LED-R50, LED-R71)", function()
			assert.are.equal(1, ns.ZonesMastered(state))
		end)

		it("measures 2 Species and 1 Legend caught, and 3 of the Ledger's 5 parts done: 60% (LED-R70)", function()
			local measures = ns.Measures(state)

			assert.are.same({ percent = 60, done = 3, total = 5 }, measures.ledgerCompletion)
			assert.are.same({ 2, 1 }, { measures.speciesCaught, measures.legendsCaught })
		end)

		it("measures the Angler Level the Ledger computes: the climb's level and its XP, at prestige rank 0", function()
			local level = ns.Measures(state).anglerLevel

			assert.are.same({ prestige = 0, level = ns.Level(state), xp = state.xp }, level)
			assert.is_true(level.xp > 0)
		end)

		it("earns Elwynn's Zone Master title and the Legend's, after the level titles (LED-R75, LED-R76)", function()
			local earned = ns.EarnedTitles(state)

			assert.are.same({ "zonemaster:" .. ELWYNN, "legend:" .. LEGEND }, { earned[#earned - 1], earned[#earned] })
			assert.are.equal("title:level1", earned[1])
		end)

		it("takes the highest level title earned as the automatic one (LED-R77)", function()
			local earned = ns.EarnedTitles(state)

			assert.are.equal(earned[#earned - 2], ns.AutomaticTitle(state))
			assert.is_truthy(ns.AutomaticTitle(state):find("^title:level%d+$"))
		end)
	end)

	it("lists only the titles the state computes, never the celebrated set's (LED-R76, #76 item 6)", function()
		local ns, state = ledgerOver({}, { global = { celebrated = { titles = { ["title:prestige1"] = true } } } })

		assert.are.same({ "title:level1" }, ns.EarnedTitles(state))
	end)

	it("measures a Prestige: rank 1, back to level 1 of the next climb (LED-R32)", function()
		local ns, state = ledgerOver({ { kind = "prestige", char = 1, time = T0, rank = 1 } })

		assert.are.same({ prestige = 1, level = 1, xp = state.xp }, ns.Measures(state).anglerLevel)
		assert.are.equal("title:level60", ns.AutomaticTitle(state))
	end)

	-- The backend passes Core's Activity XP total, the sum of the paying Modules' ActivityXPEarned (AXP-R9); the client
	-- passes none and reads Pagle.GetActivityXP().total.
	describe("with Core's Activity XP total as an argument (LED-R37, #76 item 15)", function()
		-- Levels 1 to 10 cost 9 × 1,000 + 80 × (1 + … + 9) = 12,600 XP. Most tests below fold an empty log, so the
		-- level is the Activity XP's alone.
		local TO_LEVEL_10 = 12600

		it("counts it in the Angler Level's level and XP (LED-R31)", function()
			local ns, state = ledgerOver({})

			assert.are.same({ prestige = 0, level = 10, xp = TO_LEVEL_10 }, ns.Measures(state, TO_LEVEL_10).anglerLevel)
			assert.are.same({ prestige = 0, level = 1, xp = 0 }, ns.Measures(state, 0).anglerLevel)
		end)

		it("adds it to the Ledger's own XP", function()
			local ns, state = ledgerOver(HISTORY)

			assert.are.equal(state.xp + TO_LEVEL_10, ns.Measures(state, TO_LEVEL_10).anglerLevel.xp)
			assert.are.equal(ns.ClimbOf(state.xp + TO_LEVEL_10), ns.Measures(state, TO_LEVEL_10).anglerLevel.level)
		end)

		it("reads Core's total in game when given none, and takes a given one over it", function()
			local ns, state, fake = ledgerOver({})
			fake.setActivityXP("Hunts", TO_LEVEL_10)

			assert.are.equal(10, ns.Measures(state).anglerLevel.level)
			assert.are.same(ns.Measures(state, TO_LEVEL_10), ns.Measures(state))
			assert.are.same({ prestige = 0, level = 1, xp = 0 }, ns.Measures(state, 0).anglerLevel)
		end)

		it("counts only what is above the latest Prestige entry's snapshot, never below 0 (LED-R32, AXP-R5)", function()
			local prestige = { kind = "prestige", char = 1, time = T0, rank = 1, activityXP = 1000 }
			local ns, state = ledgerOver({ prestige })

			assert.are.equal(state.xp + 500, ns.Measures(state, 1500).anglerLevel.xp)
			assert.are.equal(state.xp, ns.Measures(state, 800).anglerLevel.xp)
		end)

		it("earns the level titles it reaches, the automatic title among them (LED-R75, LED-R77)", function()
			local ns, state = ledgerOver({})

			assert.are.same({ "title:level1" }, ns.EarnedTitles(state, 0))
			assert.are.same({ "title:level1", "title:level10" }, ns.EarnedTitles(state, TO_LEVEL_10))
			assert.are.equal("title:level10", ns.AutomaticTitle(state, TO_LEVEL_10))
			assert.are.equal("title:level1", ns.AutomaticTitle(state, 0))
		end)

		it("gives the Journal's level and titles with it (LED-R30, LED-R75)", function()
			local ns, state = ledgerOver({})

			local journal = ns.JournalValues(state, 20, TO_LEVEL_10 + 500)

			-- Level 10 to 11 costs 1,800.
			assert.are.same({ into = 500, cost = 1800, carried = 0 }, journal.level)
			assert.are.same({ "title:level1", "title:level10" }, journal.titles)
		end)

		it("pays 20 Coins for each level it adds above the climb's own (LED-R38, LED-R88)", function()
			local ns, state = ledgerOver({})

			assert.are.equal(9 * 20, ns.CoinsEarned(state, TO_LEVEL_10))
			assert.are.equal(0, ns.CoinsEarned(state, 0))
		end)
	end)

	describe("the Legend list (LED-R63, PRJ-R15)", function()
		local LISTED, GONE, UNLISTED = 19803, 19806, 19808

		-- Elwynn lists two Legends, one of them removed; a third Legend is on no list.
		local function legends()
			return catalogueWith({
				items = {
					[MACKEREL] = fishRecord(MACKEREL),
					[LISTED] = fishRecord(LISTED, { legend = true }),
					[GONE] = fishRecord(GONE, { legend = true, removed = true }),
					[UNLISTED] = fishRecord(UNLISTED, { legend = true }),
				},
				areas = {
					[ELWYNN] = areaRecord(0, {
						catches = { catchEntry(MACKEREL), catchEntry(LISTED), catchEntry(GONE) },
					}),
				},
			})
		end

		it("lists every Legend an Angler with no Catches counts: listed and not removed (LED-R11, LED-R12)", function()
			local ns = ledgerOver({}, nil, legends())

			assert.are.same({ LISTED }, ns.LegendList())
		end)

		it("is the release's, whatever the Angler caught", function()
			local caught = { castRecord({ time = T0, zone = ELWYNN, items = { UNLISTED, GONE } }) }
			local ns = ledgerOver(caught, nil, legends())

			assert.are.same({ LISTED }, ns.LegendList())
		end)

		it("is empty when the release lists no Legend", function()
			local ns = ledgerOver({})

			assert.are.same({}, ns.LegendList())
		end)
	end)

	describe("the title record (#76 item 2)", function()
		-- A Ledger Module record as the Catch log hands it to the Ledger (LOG-R41).
		local function record(kind, payload)
			return { kind = "module", module = "Ledger", recordKind = kind, payload = payload, char = 1, time = T0 }
		end

		it("is a picked title key in a `title` record's payload", function()
			assert.are.equal("legend:19803", ledgerOver({}).PickedTitle(record("title", "legend:19803")))
		end)

		it("picks automatic with an empty payload (LED-R77)", function()
			assert.is_false(ledgerOver({}).PickedTitle(record("title", "")))
		end)

		it("is nil for any other record", function()
			assert.is_nil(ledgerOver({}).PickedTitle(record("celebrated", "title:level1")))
		end)
	end)

	describe("Journal values (ANG Journal values)", function()
		local LISTED_LEGEND, GONE_LEGEND, TROPHY_A, TROPHY_B, JUNK = 19803, 19806, 13901, 13902, 6309
		local DUSKWOOD = 10

		-- Elwynn (skill base 1) lists Mackerel; Westfall (skill base 10) lists Smallfish, a night fish, a Legend, two
		-- weights of trophy family 1 (19 and 22) and a junk item. Duskwood has no data, so it isn't charted. A removed
		-- Legend is on no list.
		local function journalFixture()
			return catalogueWith({
				items = {
					[MACKEREL] = fishRecord(MACKEREL),
					[SMALLFISH] = fishRecord(SMALLFISH),
					[NIGHTFISH] = fishRecord(NIGHTFISH),
					[LISTED_LEGEND] = fishRecord(LISTED_LEGEND, { legend = true }),
					[GONE_LEGEND] = fishRecord(GONE_LEGEND, { legend = true, removed = true }),
					[TROPHY_A] = itemRecord("trophy", { family = 1, weight = 19 }),
					[TROPHY_B] = itemRecord("trophy", { family = 1, weight = 22 }),
					[JUNK] = itemRecord("junk"),
				},
				areas = {
					[ELWYNN] = areaRecord(0, { skillBase = 1, catches = { catchEntry(MACKEREL) } }),
					[WESTFALL] = areaRecord(0, {
						skillBase = 10,
						catches = {
							catchEntry(SMALLFISH),
							catchEntry(NIGHTFISH, "night", NIGHT_WINDOW),
							catchEntry(LISTED_LEGEND),
							catchEntry(TROPHY_B),
							catchEntry(TROPHY_A),
							catchEntry(JUNK),
						},
					}),
					[DUSKWOOD] = areaRecord(0, { hasData = false }),
				},
				windows = { night = { spec = NIGHT_WINDOW, confirmed = true } },
			})
		end

		-- A Skill Reading of 150 of 225, Mackerel in Elwynn, Smallfish and the lighter trophy in Westfall, the removed
		-- Legend, and Mackerel in Duskwood.
		local JOURNAL_HISTORY = {
			{ kind = "skill", char = 1, time = T0 - 10, rank = 150, max = 225, mod = 0 },
			castRecord({ time = T0, zone = ELWYNN, items = { MACKEREL } }),
			castRecord({ time = T0 + 60, zone = WESTFALL, items = { SMALLFISH, TROPHY_A } }),
			castRecord({ time = T0 + 120, zone = WESTFALL, items = { GONE_LEGEND } }),
			castRecord({ time = T0 + 180, zone = DUSKWOOD, items = { MACKEREL } }),
		}

		local ns, state, journal
		setup(function()
			ns, state = ledgerOver(JOURNAL_HISTORY, nil, journalFixture())
			journal = ns.JournalValues(state, 20)
		end)

		it("gives each part of Ledger completion as { done, total } (LED-R71)", function()
			assert.are.same({
				species = { 2, 3 },
				varieties = { 0, 0 },
				junk = { 0, 1 },
				treasure = { 0, 0 },
				trophy = { 1, 2 },
				zones = { 1, 2 },
			}, journal.parts)
		end)

		it("gives the titles, the next Catch Milestone and the Skill Milestones (LED-R40, LED-R42)", function()
			assert.are.same(ns.EarnedTitles(state), journal.titles)
			assert.are.equal(1000, journal.nextCatchMilestone)
			assert.are.same({
				{ skill = 75, reached = true },
				{ skill = 150, reached = true },
				{ skill = 225, reached = false },
				{ skill = 300, reached = false },
			}, journal.skillMilestones)
		end)

		it("gives each character's latest Skill Reading (LED-R41)", function()
			assert.are.same({ { index = 1, skill = 150, max = 225 } }, journal.characters)
		end)

		it("gives a tile per charted zone and per fished uncharted one, by skill base (LED-R131)", function()
			assert.are.same({
				{ area = ELWYNN, continent = 0, charted = true, rank = 5, completion = 100 },
				{ area = WESTFALL, continent = 0, charted = true, rank = 3, completion = 50 },
				{ area = DUSKWOOD, continent = 0, charted = false, rank = 0 },
			}, journal.zones)
		end)

		it("gives every Species of the world by ID, caught or not, with its computed stars (LED-R45)", function()
			assert.are.same({
				-- In their element, each short of ★'s five Catches (LED-R45).
				{ id = SMALLFISH, caught = true, stars = { false, true, false }, removed = false },
				{ id = MACKEREL, caught = true, stars = { false, true, false }, removed = false },
				{ id = NIGHTFISH, caught = false, stars = { false, false, false }, removed = false },
			}, journal.species)
		end)

		it("gives N without removed Legends, and every caught Legend with whether it is removed (LED-R63)", function()
			assert.are.same({ total = 1, caught = { { item = GONE_LEGEND, removed = true } } }, journal.legends)
		end)

		it("gives each trophy family's stars and its weights, lightest first (LED-R47, LED-R61)", function()
			assert.are.same({
				{
					family = 1,
					stars = { true, true, false },
					weights = {
						{ item = TROPHY_A, weight = 19, landed = true },
						{ item = TROPHY_B, weight = 22, landed = false },
					},
				},
			}, journal.trophies)
		end)

		it("gives the Ledger's own XP all told, as Where your XP came from shows it (LED-R150, LED-R155)", function()
			local own = ns.XPSourceLines(state, { total = 0, bySource = {} })[1]

			assert.are.same({ ledger = own.total }, journal.xp)
			assert.are.equal(state.lifetimeXP, journal.xp.ledger)
			assert.is_true(journal.xp.ledger > 0)
		end)

		it("gives the Ledger's own XP without the Activity XP the level counts (LED-R37, LED-R155)", function()
			assert.are.same(journal.xp, ns.JournalValues(state, 20, 12600).xp)
		end)

		it("keeps every climb's XP after a Prestige, the carried XP counted once (LED-R32, LED-R155)", function()
			local prestiged = setmetatable({ xp = 300, prestige = 1, lifetimeXP = 200900 }, { __index = state })

			assert.are.equal(200900, ns.JournalValues(prestiged, 20).xp.ledger)
		end)

		it("gives the XP into the level and the next step's cost below 60, with nothing carried (LED-R30)", function()
			local climbing = setmetatable({ xp = 1500, prestige = 0 }, { __index = state })

			-- Level 1 to 2 costs 1,080; level 2 to 3 costs 1,160.
			assert.are.same({ into = 420, cost = 1160, carried = 0 }, ns.JournalValues(climbing, 20).level)
		end)

		it("gives the carried XP at 60, and no cost (LED-R30, LED-R145)", function()
			-- Levels 1 to 60 cost 59 × 1,000 + 80 × (1 + … + 59) = 200,600.
			local capped = setmetatable({ xp = 200600 + 500, prestige = 0 }, { __index = state })

			assert.are.same({ into = 500, carried = 500 }, ns.JournalValues(capped, 20).level)
		end)
	end)

	describe("variety and crest Journal values (ANG #224, #76 item 18)", function()
		local KEYS = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j" }
		local DUSKWOOD_AREA = 10
		local RARITIES =
			{ "common", "common", "common", "common", "uncommon", "uncommon", "uncommon", "rare", "rare", "epic" }

		-- Core's own variety hash (VAR-R3), to find a Cast time whose one Catch is a chosen variety.
		local core = loadAddon("Pagle", FOREVER_GLOBALS).ns

		-- The variety Core gives the one Catch of a Cast by character 1 at `time` (its Catch ID's tie is 0).
		local function varietyAt(time)
			return core.VarietyIndex(("%s-%d-0:1"):format(PLAYER_GUID, time))
		end

		-- A caught Cast of one `itemID` in `zone` at the first time from `from` whose Catch is variety `index`.
		local function castOfVariety(itemID, zone, index, from)
			local time = from
			while varietyAt(time) ~= index do
				time = time + 1
			end
			return castRecord({ time = time, zone = zone, items = { itemID } })
		end

		-- Mackerel, Smallfish and the night fish are sized with ten varieties each (VAR-R1); Elwynn lists Mackerel
		-- alone, so its first Catch masters it (LED-R50); Westfall lists the other two.
		local function varietyFixture()
			local sized = { typicalLength = 300, varieties = KEYS }
			return catalogueWith({
				items = {
					[MACKEREL] = fishRecord(MACKEREL, sized),
					[SMALLFISH] = fishRecord(SMALLFISH, sized),
					[NIGHTFISH] = fishRecord(NIGHTFISH, sized),
				},
				areas = {
					[ELWYNN] = areaRecord(0, { skillBase = 1, catches = { catchEntry(MACKEREL) } }),
					[WESTFALL] = areaRecord(0, {
						skillBase = 1,
						catches = { catchEntry(SMALLFISH), catchEntry(NIGHTFISH, "night", NIGHT_WINDOW) },
					}),
				},
				windows = { night = { spec = NIGHT_WINDOW, confirmed = true } },
			})
		end

		-- All ten of Mackerel in Elwynn, in position order, then a second Catch of its first variety and one Smallfish
		-- in Westfall. `times[i]` is the first Catch of Mackerel's variety i.
		local times, records = {}, {}
		local from = T0
		for index = 1, 10 do
			local record = castOfVariety(MACKEREL, ELWYNN, index, from)
			records[#records + 1] = record
			times[index] = record.time
			from = record.time + 60
		end
		records[#records + 1] = castOfVariety(MACKEREL, ELWYNN, 1, from)
		local smallfishTime = records[#records].time + 60
		records[#records + 1] = castRecord({ time = smallfishTime, zone = WESTFALL, items = { SMALLFISH } })

		local ns, state, fake, journal
		setup(function()
			ns, state, fake = ledgerOver(records, nil, varietyFixture())
			journal = ns.JournalValues(state, 20)
		end)

		it("gives every Species with varieties by ID, its caught ones in position order (VAR-R2, VAR-R10)", function()
			local smallfish = varietyAt(smallfishTime)
			local mackerel = {}
			for index = 1, 10 do
				mackerel[index] = {
					id = MACKEREL .. "." .. KEYS[index],
					position = index,
					rarity = RARITIES[index],
					first = times[index],
				}
			end

			assert.are.same({
				{
					species = SMALLFISH,
					caught = {
						{
							id = SMALLFISH .. "." .. KEYS[smallfish],
							position = smallfish,
							rarity = RARITIES[smallfish],
							first = smallfishTime,
						},
					},
				},
				{ species = MACKEREL, caught = mackerel },
				{ species = NIGHTFISH, caught = {} },
			}, journal.varieties)
		end)

		it("names each caught variety and its rarity as Core lists them in game (VAR-R11)", function()
			for _, entry in ipairs(journal.varieties) do
				local list = fake.Pagle.GetVarieties(entry.species)
				for _, caught in ipairs(entry.caught) do
					assert.are.same(
						{ list[caught.position].id, list[caught.position].rarity },
						{ caught.id, caught.rarity }
					)
				end
			end
		end)

		it("counts the varieties the Journal counts: its caught positions are the Ledger's (VAR-R20)", function()
			for _, entry in ipairs(journal.varieties) do
				assert.are.equal(ns.VarietiesCaught(state, entry.species), #entry.caught)
			end
		end)

		it(
			"gives the earned crests, zone crests first, each with the time of the record that earned it (LED-R113, VAR-R12)",
			function()
				assert.are.same({
					{ id = "ledger.crest.elwynn", kind = "zone", zone = ELWYNN, earnedAt = times[1] },
					{ id = "core.crest.fish." .. MACKEREL, kind = "fish", species = MACKEREL, earnedAt = times[10] },
				}, journal.crests)
			end
		)

		it("gives the crests the client owns for the same log, and none it doesn't (LED-R114, VAR-R12)", function()
			for _, crest in ipairs(journal.crests) do
				assert(fake.Pagle.IsOwned(crest.id), crest.id .. " isn't owned in game")
			end
			assert.is_false(fake.Pagle.IsOwned("ledger.crest.westfall"))
			assert.is_false(fake.Pagle.IsOwned("core.crest.fish." .. SMALLFISH))
		end)

		it("leaves out a zone crest the celebrated set alone keeps: computed only (ANG-R4, #76 item 6)", function()
			-- Kept for this log, so the first build keeps it (LED-R90).
			local saved = { global = { celebrated = { logId = "log", zones = { [WESTFALL] = 5 } } } }
			local kept, keptState, keptFake = ledgerOver(records, saved, varietyFixture(), "log")

			assert.is_true(keptFake.Pagle.IsOwned("ledger.crest.westfall"))
			for _, crest in ipairs(kept.JournalValues(keptState, 20).crests) do
				assert.are_not.equal("ledger.crest.westfall", crest.id)
			end
		end)

		it("orders the zone crests by the zone crest table and the fish crests by Species ID (LED-R113)", function()
			local fished = setmetatable({
				zones = {
					[WESTFALL] = { rank = 5, masterAt = T0 + 5 },
					[ELWYNN] = { rank = 5, masterAt = T0 + 9 },
					[DUSKWOOD_AREA] = { rank = 4 },
				},
			}, { __index = state })

			local ids = {}
			for i, crest in ipairs(ns.JournalValues(fished, 20).crests) do
				ids[i] = crest.id
			end

			-- The table lists Elwynn ("elwynn") before Westfall ("westfall"); a zone below Master has none.
			assert.are.same({ "ledger.crest.elwynn", "ledger.crest.westfall", "core.crest.fish." .. MACKEREL }, ids)
		end)

		it("gives none of either before any Catch", function()
			local empty, emptyState = ledgerOver({}, nil, varietyFixture())
			local values = empty.JournalValues(emptyState, 20)

			assert.are.same({}, values.crests)
			assert.are.same({ species = MACKEREL, caught = {} }, values.varieties[2])
		end)
	end)

	describe("the crest record (#76 item 19, LED-R156)", function()
		-- A Ledger Module record as the Catch log hands it to the Ledger (LOG-R41).
		local function record(kind, payload, time)
			return {
				kind = "module",
				module = "Ledger",
				recordKind = kind,
				payload = payload,
				char = 1,
				time = time or T0,
			}
		end

		it("is the equipped crest's good ID in a `crest` record's payload", function()
			local ns = ledgerOver({})

			assert.are.equal("ledger.crest.elwynn", ns.EquippedCrest(record("crest", "ledger.crest.elwynn")))
			assert.are.equal("core.crest.fish.6303", ns.EquippedCrest(record("crest", "core.crest.fish.6303")))
		end)

		it("equips Plain with an empty payload", function()
			assert.is_false(ledgerOver({}).EquippedCrest(record("crest", "")))
		end)

		it("is nil for any other record", function()
			assert.is_nil(ledgerOver({}).EquippedCrest(record("title", "ledger.crest.elwynn")))
		end)

		it("is folded into the state, the latest by entry time, the later in log order on equal time", function()
			local _, state = ledgerOver({
				record("crest", "ledger.crest.elwynn", T0),
				record("crest", "", T0 + 60),
				record("crest", "core.crest.fish.6303", T0 + 30),
				record("crest", "ledger.crest.westfall", T0 + 60),
			})

			assert.are.same({ good = "ledger.crest.westfall", time = T0 + 60 }, state.crest)
		end)

		it("leaves the state without one while the log has none", function()
			local _, state = ledgerOver(HISTORY)

			assert.is_nil(state.crest)
		end)

		it("is to be logged when the equipped crest isn't the latest record's: Plain as an empty payload", function()
			local ns = ledgerOver({})
			local none = { crest = nil }
			local elwynn = { crest = { good = "ledger.crest.elwynn", time = T0 } }
			local plain = { crest = { good = "", time = T0 } }

			assert.are.equal("ledger.crest.elwynn", ns.CrestRecordFor(none, "ledger.crest.elwynn", false))
			assert.is_nil(ns.CrestRecordFor(none, "core.crest.plain", true))
			assert.is_nil(ns.CrestRecordFor(elwynn, "ledger.crest.elwynn", false))
			assert.are.equal("", ns.CrestRecordFor(elwynn, "core.crest.plain", true))
			assert.is_nil(ns.CrestRecordFor(plain, "core.crest.plain", true))
			assert.are.equal("core.crest.fish.6303", ns.CrestRecordFor(elwynn, "core.crest.fish.6303", false))
		end)
	end)
end)
