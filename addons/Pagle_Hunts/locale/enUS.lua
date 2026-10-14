if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

-- Hunts' string table (CORE-R8). Every user-facing string goes through ns.L; enUS only in 1.0. The lore keys
-- (`hunt.<id>.name`, `set.<id>.title`, …, HNT-R130) are added by the generated data/Lore.lua from the M5 lore batch
-- on; until a key has text, the Hunt list falls back to the ID (HNT-R1).

---@class PagleHuntsNS
local ns = select(2, ...)

---@class PagleHuntsStrings
ns.L = {
	-- The Module's def title and its one view (HNT-R135).
	TITLE = "Hunts",
	BOARD = "Hunts",
	BOARD_SLASH_HELP = "Open or close the Hunts board",

	-- Hunts' slots (HNT-R120) and the sample tracker a tracker frame's preview draws (HNT-R121).
	SLOT_NOTEBOOK_COVER = "Notebook cover",
	SLOT_TRACKER_FRAME = "Hunts tracker frame",
	PREVIEW_TRACKER_LINE_1 = "Night Run · in 37m",
	PREVIEW_TRACKER_LINE_2 = "Rack Hour · on demand",
}
