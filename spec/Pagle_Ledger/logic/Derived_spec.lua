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
end)
