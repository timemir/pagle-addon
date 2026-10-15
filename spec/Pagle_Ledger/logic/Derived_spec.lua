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
---@return PagleLedgerNS ns
---@return LedgerState state the projection's, built
local function ledgerOver(records, saved, catalogue)
	local fake = newFakePagle()
	fake.setCatalogue(catalogue or fixture())
	fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
	for _, record in ipairs(records) do
		fake.catchLog:Append(record)
	end
	fake.globals.PagleLedgerDB = saved
	local ns = fake.load("Pagle_Ledger").ns
	fake.login()
	fake.enterWorld()
	return ns, ns.StateNow() --[[@as LedgerState]]
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
				{ id = SMALLFISH, caught = true, stars = { true, true, false }, removed = false },
				{ id = MACKEREL, caught = true, stars = { true, true, false }, removed = false },
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
end)
