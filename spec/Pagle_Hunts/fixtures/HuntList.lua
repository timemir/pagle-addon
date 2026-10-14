-- A Hunt list for specs, in the shape the generator emits into addons/Pagle_Hunts/data/HuntList.lua (DATA-R93):
-- Hunts' specs run on it, never on the shipped list (hunts.md › Data: "Tests inject their own Hunt list and `since`
-- dates"). Its items, windows and auras are FakePagle's catalogue's. Later tickets add sets, Hunts and class members
-- at the end and never change an entry already here.
--
-- Server times (DATA-R87: a date means 00:00 UTC that day): 1767225600 is 2026-01-01, 1780272000 is 2026-06-01 and
-- 1793750400 is 2026-11-04. FakePagle's clock starts at SERVER_TIME, 2026-10-11 15:15 UTC.

if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

local ns = select(2, ...)

ns.huntList = {
	fingerprint = "f1x7f1x7f1x7f1x7f1x7f1x7f1x7f1x7f1x7f1x7f1x7f1x7f1x7f1x7f1x7f1x7",
	sets = {
		{ id = "fixture_dusk" },
		{ id = "fixture_wagers" },
	},
	hunts = {
		-- A natural Hunt: a Species and its window (DATA-R86).
		{
			id = "fixture_snapper",
			set = "fixture_dusk",
			kind = "natural",
			since = 1767225600,
			species = 13759,
			window = "night",
			tiers = { 1, 10, 40 },
		},
		-- An imposed Hunt on a fixed class, with its own conditions (DATA-R86, DATA-R90).
		{
			id = "fixture_oddity",
			set = "fixture_wagers",
			kind = "imposed",
			since = 1767225600,
			class = "fixed.oddity",
			conditions = { time = { { 1080, 1260 } } },
			tiers = { 1, 10 },
		},
		-- An imposed Hunt on a generated class, under an aura the player starts (DATA-R91).
		{
			id = "fixture_rack",
			set = "fixture_wagers",
			kind = "imposed",
			since = 1767225600,
			class = "quality.uncommon",
			conditions = { auras = { 1280341 } },
			tiers = { 1, 5 },
		},
		-- An imposed Species Hunt with a minBand (DATA-R89).
		{
			id = "fixture_hefty_blackmouth",
			set = "fixture_dusk",
			kind = "imposed",
			since = 1767225600,
			species = 6358,
			minBand = 3,
			conditions = { time = { { 1320, 240 } } },
			tiers = { 1, 5 },
		},
		-- A Retired Hunt: it existed from 2026-01-01 until 2026-06-01 (HNT-R3).
		{
			id = "fixture_sunscale",
			set = "fixture_dusk",
			kind = "natural",
			since = 1767225600,
			retired = 1780272000,
			species = 13760,
			window = "day",
			tiers = { 1 },
		},
		-- A Hunt shipped early: its since, 2026-11-04, is after FakePagle's clock (HNT-R2).
		{
			id = "fixture_grouper",
			set = "fixture_wagers",
			kind = "imposed",
			since = 1793750400,
			species = 12238,
			conditions = { time = { { 1320, 240 } } },
			tiers = { 1, 5 },
		},
	},
	-- Every generated class and the fixed class; the generated ones hold a few of the catalogue's members.
	classes = {
		["fixed.oddity"] = { [6522] = true, [251524] = true },
		["quality.uncommon"] = { [6643] = true, [19803] = true },
		["quality.rare"] = {},
		["species.any"] = { [6358] = true, [6522] = true, [12238] = true, [13759] = true, [13760] = true },
	},
}
