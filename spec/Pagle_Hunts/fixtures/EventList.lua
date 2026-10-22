-- An event pool for specs, in the shape the generator emits into addons/Pagle_Hunts/data/EventList.lua (DATA-R98):
-- Hunts' specs run on it, never on the shipped pool (hunts.md › Data). Its zones, items and classes are the fixture
-- catalogue's and the fixture Hunt list's (spec/Pagle_Hunts/fixtures/Catalogue.lua, HuntList.lua). Later tickets add
-- events at the end and never change one already here.
--
--   fixture_shore: Darkshore (148). A Haul of any fish (tiers 2 / 4), a Named fish (Raw Nightfin Snapper, 1) and a
--                  Timed oddity at 18:00–21:00 realm time (1).
--   fixture_vale:  Ashenvale (331) and Elwynn Forest (12). A Haul (1 / 3), a Named fish (Oily Blackmouth, 1) and a
--                  Quality Hunt (quality.uncommon, 1): one Cast in Elwynn with a Blackmouth and an uncommon item
--                  completes a run, and no Standing Hunt counts those Catches (no size, no Rack's aura).

if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

local ns = select(2, ...)

ns.eventList = {
	fingerprint = "e1e1e1e1e1e1e1e1",
	events = {
		{
			id = "fixture_shore",
			zones = { 148 },
			tags = { "coast", "low" },
			skill = { 75, 150 },
			band = "low",
			rotation = true,
			hunts = {
				{ id = "fixture_shore_haul", class = "species.any", tiers = { 2, 4 } },
				{ id = "fixture_shore_snapper", species = 13759, tiers = { 1 } },
				{
					id = "fixture_shore_oddity",
					class = "fixed.oddity",
					conditions = { time = { { 1080, 1260 } } },
					tiers = { 1 },
				},
			},
		},
		{
			id = "fixture_vale",
			zones = { 331, 12 },
			tags = { "lake", "low" },
			skill = { 25, 150 },
			band = "low",
			rotation = true,
			hunts = {
				{ id = "fixture_vale_haul", class = "species.any", tiers = { 1, 3 } },
				{ id = "fixture_vale_blackmouth", species = 6358, tiers = { 1 } },
				{ id = "fixture_vale_uncommon", class = "quality.uncommon", tiers = { 1 } },
			},
		},
	},
}
