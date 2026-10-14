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

	-- Hunts' moments, Write-up and summary line (HNT-R86, HNT-R89, HNT-R111). Counts come in singular and plural
	-- pairs, *_ONE and *_OTHER.
	HUNT_COMPLETE = "Hunt complete",
	HUNT_COMPLETE_STAMP = "Hunt",
	HUNT_TIER = "%s tier", -- "Silver tier"
	HUNT_TIER_TEXT = "%s · %d caught", -- "Night Run · 10 caught"
	TRIMS = { bronze = "Bronze", silver = "Silver", gold = "Gold" }, -- HNT-R18
	TITLE_EARNED = "Title earned",
	TITLE_EARNED_STAMP = "Title",
	WRITE_UP_FIRST_BUILD_ONE = "Your Hunts were written up from %s Cast",
	WRITE_UP_FIRST_BUILD_OTHER = "Your Hunts were written up from %s Casts",
	WRITE_UP_WHILE_OFF = "While Hunts was off",
	WRITE_UP_COMPLETED_ONE = "%s Hunt completed",
	WRITE_UP_COMPLETED_OTHER = "%s Hunts completed",
	WRITE_UP_FURTHER_ONE = "%s further tier",
	WRITE_UP_FURTHER_OTHER = "%s further tiers",
	WRITE_UP_TITLE = "Title: %s",
	WRITE_UP_COINS = "Pagle Coins +%s",
	SUMMARY_LINE = "Hunts: %s of %s done · %s", -- "Hunts: 3 of 16 done · 1 title"
	SUMMARY_TITLES_ONE = "%s title",
	SUMMARY_TITLES_OTHER = "%s titles",
}
