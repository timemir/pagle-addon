-- An event pool of three rotating events per skill band (HNT-R152, HNT-R156), in the shape the generator emits into
-- addons/Pagle_Hunts/data/EventList.lua (DATA-R98), for the rotation's and the run log's specs: they load it in place of
-- spec/Pagle_Hunts/fixtures/EventList.lua through support.load's `events` (support.bandedEvents()). Its zones and
-- classes are the fixture catalogue's and the fixture Hunt list's. Every event has the same three Hunts' shapes, so
-- any Cast in its zones counts for its Haul: a Haul of any fish (tiers 1 / 3), a Named fish (Raw Nightfin Snapper, 1)
-- and a Named fish (Oily Blackmouth, 1).
--
--   low:  fixture_brook (Westfall), fixture_shore (Darkshore), fixture_vale (Ashenvale and Elwynn Forest)
--   mid:  fixture_cove (Darkshore), fixture_firth (Westfall), fixture_glen (Elwynn Forest)
--   high: fixture_reef (Darkshore), fixture_sound (Ashenvale), fixture_tarn (Westfall)
--
-- Returns a new EventListData each time it is run.

local DARKSHORE, ASHENVALE, ELWYNN, WESTFALL = 148, 331, 12, 40
local NIGHTFIN, BLACKMOUTH = 13759, 6358
local SKILL = { low = { 25, 150 }, mid = { 175, 275 }, high = { 300, 375 } }

local function event(id, band, zones)
	return {
		id = id,
		zones = zones,
		tags = { band },
		skill = { SKILL[band][1], SKILL[band][2] },
		band = band,
		rotation = true,
		hunts = {
			{ id = id .. "_haul", class = "species.any", tiers = { 1, 3 } },
			{ id = id .. "_snapper", species = NIGHTFIN, tiers = { 1 } },
			{ id = id .. "_blackmouth", species = BLACKMOUTH, tiers = { 1 } },
		},
	}
end

return {
	fingerprint = "b1b1b1b1b1b1b1b1",
	events = {
		event("fixture_brook", "low", { WESTFALL }),
		event("fixture_cove", "mid", { DARKSHORE }),
		event("fixture_firth", "mid", { WESTFALL }),
		event("fixture_glen", "mid", { ELWYNN }),
		event("fixture_reef", "high", { DARKSHORE }),
		event("fixture_shore", "low", { DARKSHORE }),
		event("fixture_sound", "high", { ASHENVALE }),
		event("fixture_tarn", "high", { WESTFALL }),
		event("fixture_vale", "low", { ASHENVALE, ELWYNN }),
	},
}
