-- A Hunt list in the shape of addons/Pagle_Hunts/data/HuntList.lua (ns.huntList, DATA-R93), for read-wtf_spec.lua's
-- --huntlist runs, so the Hunts lines don't move with the generated list. It borrows v1 IDs (hunts.md › The v1 Hunt
-- list) with its own dates. Server times (DATA-R87: a date means 00:00 UTC that day): 1767225600 is 2026-01-01,
-- 1788220800 is 2026-09-01 and 1793750400 is 2026-11-04. At the specs' --now, 1792000000 (2026-10-14 17:46:40 UTC),
-- night_run, first_light, rack_hour and dawn_trout are current, grouper_by_moonlight is retired and witching_hour
-- isn't out yet.

if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

local ns = select(2, ...)

ns.huntList = {
	fingerprint = "5eed5eed5eed5eed",
	sets = {
		{ id = "round_the_clock" },
		{ id = "camp_hours" },
		{ id = "pagles_wagers" },
	},
	hunts = {
		{
			id = "night_run",
			set = "round_the_clock",
			kind = "natural",
			since = 1767225600,
			species = 13759,
			window = "night",
			tiers = { 1, 10, 40 },
		},
		{
			id = "first_light",
			set = "round_the_clock",
			kind = "natural",
			since = 1767225600,
			species = 13760,
			window = "day",
			tiers = { 1, 10, 40 },
		},
		{
			id = "rack_hour",
			set = "camp_hours",
			kind = "imposed",
			since = 1767225600,
			class = "quality.uncommon",
			conditions = { auras = { 1280341 } },
			tiers = { 1, 10, 25 },
		},
		{
			id = "dawn_trout",
			set = "pagles_wagers",
			kind = "imposed",
			since = 1767225600,
			species = 8365,
			conditions = { time = { { 300, 480 } } },
			tiers = { 1, 10, 25 },
		},
		{
			id = "grouper_by_moonlight",
			set = "pagles_wagers",
			kind = "imposed",
			since = 1767225600,
			retired = 1788220800,
			species = 12238,
			conditions = { areas = { 148 }, time = { { 1320, 240 } } },
			tiers = { 1, 5, 20 },
		},
		{
			id = "witching_hour",
			set = "pagles_wagers",
			kind = "imposed",
			since = 1793750400,
			class = "species.any",
			conditions = { areas = { 10 }, time = { { 0, 180 } } },
			tiers = { 1, 10, 30 },
		},
	},
	classes = {
		["fixed.oddity"] = { [6522] = true, [251524] = true },
		["quality.uncommon"] = { [6643] = true, [19803] = true },
		["quality.rare"] = {},
		["species.any"] = { [8365] = true, [12238] = true, [13759] = true, [13760] = true },
	},
}
