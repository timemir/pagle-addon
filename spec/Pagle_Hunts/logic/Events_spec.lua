-- Hunt Events at runtime (HNT-R1, HNT-R30, HNT-R31, HNT-R32, HNT-R140, HNT-R141, HNT-R156): logic/Events.lua over the
-- fixture event pool (spec/Pagle_Hunts/fixtures/EventList.lua), its lore and the fixture catalogue, as OnInitialize
-- builds it into ns.events.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local C = hunts.catalogue

describe("Hunt Events at runtime", function()
	local fake = newFakePagle()
	fake.setCatalogue(C.base())
	local ns = hunts.load(fake).ns
	local events = ns.events

	it(
		"reads the pool from ns.eventList at load, in event-ID order, with its fingerprint (HNT-R1, DATA-R98)",
		function()
			assert.are.same({ "fixture_shore", "fixture_vale" }, hunts.ids(events:Events()))
			assert.are.equal("e1e1e1e1e1e1e1e1", events:Fingerprint())
			assert.is_nil(events:Event("fixture_nowhere"))
		end
	)

	it("makes each event Hunt imposed, with no set, since or retired, bound to the event's zones (HNT-R141)", function()
		local vale = events:Event("fixture_vale")
		assert.are.same({
			id = "fixture_vale_blackmouth",
			event = "fixture_vale",
			kind = "imposed",
			species = C.BLACKMOUTH,
			conditions = { areas = { C.ASHENVALE, C.ELWYNN } },
			tiers = { 1 },
		}, vale.hunts[2])
		-- Its own conditions narrow the event's zones; they are never changed in the pool.
		local oddity = events:Event("fixture_shore").hunts[3]
		assert.are.same({ time = { { 1080, 1260 } }, areas = { C.DARKSHORE } }, oddity.conditions)
		assert.is_nil(ns.eventList.events[1].hunts[3].conditions.areas)
	end)

	it("works out where each event Hunt bites once per load: its zones, no waters (HNT-R30–R32)", function()
		local where = events:Event("fixture_vale").where.fixture_vale_haul
		assert.are.same({}, where.waters)
		assert.are.same({ C.ASHENVALE, C.ELWYNN }, where.places)
		assert.are.same({ C.ELWYNN, C.ASHENVALE }, { where.zones[1], where.zones[2] })
		-- The lowest skill base among its places: Elwynn Forest's 25.
		assert.are.equal(25, where.skillNeed)
		assert.are.same({ areas = { C.ASHENVALE, C.ELWYNN } }, where.boardSpec)
	end)

	it("names an event and its Hunts from the lore, or by ID while it has none (HNT-R1, HNT-R140)", function()
		local shore, vale = events:Event("fixture_shore"), events:Event("fixture_vale")
		assert.are.same(
			{ "Shore Wager", "fixture_vale", "Darkshore's tide, three days long." },
			{ events:EventName(shore), events:EventName(vale), events:EventNote(shore) }
		)
		assert.are.same(
			{ "Shore Snapper", "fixture_shore_haul" },
			{ events:HuntName(shore.hunts[2]), events:HuntName(shore.hunts[1]) }
		)
		assert.is_nil(events:EventNote(vale))
	end)

	it("keeps the pool's band and rotation, and gives a pushed event its band from its skill (HNT-R156)", function()
		assert.are.same({ "low", true, false }, {
			events:Event("fixture_shore").band,
			events:Event("fixture_shore").rotation,
			events:Event("fixture_shore").pushed,
		})
		local pushed = ns.NewHuntEvent({
			id = "p_deep",
			zones = { C.ASHENVALE },
			skill = { 276, 300 },
			rotation = true,
			name = "Deep Water",
			hunts = { { id = "p_deep_haul", name = "Deep Haul", class = "species.any", tiers = { 1 } } },
		}, true, ns.lookups)
		assert.are.same(
			{ "high", false, true, "Deep Water" },
			{ pushed.band, pushed.rotation, pushed.pushed, pushed.name }
		)
		assert.are.same(
			{ "low", "low", "mid", "mid", "high" },
			{ ns.SkillBand(0), ns.SkillBand(150), ns.SkillBand(151), ns.SkillBand(275), ns.SkillBand(276) }
		)
	end)

	it("reads a missing pool as an empty one", function()
		local empty = ns.NewEventList(nil, ns.L, ns.lookups)
		assert.are.same({}, empty:Events())
		assert.is_nil(empty:Fingerprint())
	end)
end)
