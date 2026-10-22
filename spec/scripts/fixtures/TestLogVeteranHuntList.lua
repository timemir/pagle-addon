-- A Hunt list in the shape of addons/Pagle_Hunts/data/HuntList.lua (ns.huntList, DATA-R93), for make-test-log_spec.lua's
-- veteran runs (--huntlist): TestLogHuntList.lua's classes, and one Standing Hunt on Raw Slitherskin Mackerel released
-- far after the run, so only the test log's release date (devHuntsSince) puts it out for the history's Casts.

if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

local ns = select(2, ...)

ns.huntList = {
	fingerprint = "7e5710c0000000b2",
	sets = { { id = "fixture_set" } },
	hunts = {
		{
			id = "fixture_mackerel",
			kind = "natural",
			set = "fixture_set",
			since = 1893456000,
			species = 6303,
			tiers = { 1, 10 },
		},
	},
	classes = {
		["fixed.oddity"] = {},
		["quality.uncommon"] = {},
		["quality.rare"] = {},
		["species.any"] = { [6291] = true, [6299] = true, [6303] = true, [13759] = true },
	},
}
