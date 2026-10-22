-- A Hunt list in the shape of addons/Pagle_Hunts/data/HuntList.lua (ns.huntList, DATA-R93), for make-test-log_spec.lua's
-- wagers runs (--huntlist), so their test logs don't move with the generated list. It has no Standing Hunt, only the
-- class an event Hunt reads (HNT-R12): species.any over spec/scripts/fixtures/TestLogCatalogue.lua's Species.

if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

local ns = select(2, ...)

ns.huntList = {
	fingerprint = "7e5710c0000000a1",
	sets = {},
	hunts = {},
	classes = {
		["fixed.oddity"] = {},
		["quality.uncommon"] = {},
		["quality.rare"] = {},
		["species.any"] = { [6291] = true, [6299] = true, [6303] = true, [13759] = true },
	},
}
