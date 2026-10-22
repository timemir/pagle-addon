-- An event pool in the shape of addons/Pagle_Hunts/data/EventList.lua (ns.eventList, DATA-R98), for
-- make-test-log_spec.lua's wagers runs (--eventlist), so their test logs don't move with the generated pool: one event
-- per band (HNT-R156), so slot k's pick is its band's one event (HNT-R152), in the charted zones of
-- spec/scripts/fixtures/TestLogCatalogue.lua, Elwynn Forest (12) and Westfall (40). The mid one holds a Timed Hunt (realm
-- 05:00 to 08:00) and a Big ones Hunt (a Size band of 2 or more, HNT-R14).

if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

local ns = select(2, ...)

ns.eventList = {
	fingerprint = "7e57e0e0e0e0e0a1",
	events = {
		{
			id = "fixture_elwynn_evening",
			zones = { 12 },
			tags = { "lake", "low" },
			skill = { 25, 75 },
			band = "low",
			rotation = true,
			hunts = {
				{ id = "fixture_elwynn_evening_haul", class = "species.any", tiers = { 10, 25 } },
				{ id = "fixture_elwynn_evening_smallfish", species = 6291, tiers = { 4 } },
			},
		},
		{
			id = "fixture_westfall_dawn",
			zones = { 40 },
			tags = { "coast", "day", "mid" },
			skill = { 160, 200 },
			band = "mid",
			rotation = true,
			hunts = {
				{ id = "fixture_westfall_dawn_haul", class = "species.any", tiers = { 12, 60 } },
				{
					id = "fixture_westfall_dawn_mackerel",
					species = 6303,
					conditions = { time = { { 300, 480 } } },
					tiers = { 4, 10 },
				},
				{ id = "fixture_westfall_dawn_big", species = 6299, minBand = 2, tiers = { 2, 5 } },
			},
		},
		{
			id = "fixture_westfall_night",
			zones = { 40 },
			tags = { "coast", "night", "high" },
			skill = { 290, 300 },
			band = "high",
			rotation = true,
			hunts = {
				{ id = "fixture_westfall_night_haul", class = "species.any", tiers = { 8 } },
			},
		},
	},
}
