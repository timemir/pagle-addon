-- Lore for the fixture Hunt list (fixtures/HuntList.lua), in the shape the generator emits into Pagle_Hunts'
-- data/Lore.lua (DATA-R104, DATA-R105, HNT-R130). Some keys are left out on purpose, so the fallbacks show (HNT-R1):
-- fixture_rack and fixture_grouper have no name, only fixture_snapper and fixture_dusk have notes, and
-- fixture_wagers has no title. Later tickets add keys and never change one already here.

if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

local L = select(2, ...).L

L["hunt.fixture_hefty_blackmouth.name"] = "Hefty Blackmouth"
L["hunt.fixture_oddity.name"] = "Oddity Hour"
L["hunt.fixture_snapper.name"] = "Snapper Run"
L["hunt.fixture_snapper.note"] = "Keeps late hours."
L["hunt.fixture_sunscale.name"] = "Old Sunscale"
L["set.fixture_dusk.name"] = "Dusk"
L["set.fixture_dusk.note"] = "After the lamps are lit."
L["set.fixture_dusk.title"] = "the Duskwatcher"
L["set.fixture_wagers.name"] = "Wagers"
-- Two of Hunts' goods (HNT-R121, from #192); the other five have no keys, so they read their IDs.
L["huntgood.hunts.notebookcover.oilcloth.description"] = "Black-green oilcloth that keeps the rain off the pages."
L["huntgood.hunts.notebookcover.oilcloth.name"] = "Oilcloth"
L["huntgood.hunts.trackerframe.inkwash.description"] = "A wash of thinned ink behind your pinned Hunts."
L["huntgood.hunts.trackerframe.inkwash.name"] = "Ink Wash"
-- The fixture event pool's lore (fixtures/EventList.lua, DATA-R97): fixture_shore and one of its Hunts have names and
-- a note; fixture_vale and the other Hunts have none, so they read their IDs (HNT-R140).
L["event.fixture_shore.name"] = "Shore Wager"
L["event.fixture_shore.note"] = "Darkshore's tide, three days long."
L["hunt.fixture_shore_snapper.name"] = "Shore Snapper"
