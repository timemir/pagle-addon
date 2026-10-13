if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

-- The Ledger's string table (CORE-R8). Every user-facing string goes through ns.L; enUS only in 1.0.

---@class PagleLedgerNS
local ns = select(2, ...)

---@class PagleLedgerStrings
ns.L = {
	-- The Ledger's def title (LED-R1).
	TITLE = "Ledger",

	-- The summary line (LED-R95), without the completion part until M3.
	SUMMARY_LINE = "Ledger: Angler Level %d",

	-- Names the client doesn't have (LED-R97, LED-R126).
	ITEM_FALLBACK = "Item %d",
	NAME_UNKNOWN = "…",

	-- The moments (LED-R97). A level-up's text counts the levels it raised.
	LEVEL_UP_TITLE = "Angler Level %d",
	LEVEL_UP_STAMP = "Level %d",
	LEVELS_RAISED_ONE = "+%d level",
	LEVELS_RAISED_OTHER = "+%d levels",
	NEW_SPECIES_TITLE = "New Species",
	NEW_SPECIES_STAMP = "New!",
	NEW_IN_ZONE_TITLE = "New here",
	NEW_IN_ZONE_TEXT = "%s in %s",
	NEW_IN_ZONE_STAMP = "New here",
	SKILL_MILESTONE_TITLE = "Skill Milestone",
	SKILL_MILESTONE_TEXT = "Fishing %d",

	-- Write-up sections (LED-R93) and their lines (LED-R94). Numbers in %s are BreakUpLargeNumbers'.
	WRITE_UP_FIRST_BUILD_ONE = "Your Ledger was written up from %s Cast",
	WRITE_UP_FIRST_BUILD_OTHER = "Your Ledger was written up from %s Casts",
	WRITE_UP_WHILE_OFF = "While the Ledger was off",
	WRITE_UP_LEVEL = "Angler Level %d",
	WRITE_UP_LEVEL_ROSE = "Angler Level %d → %d",
	WRITE_UP_SPECIES_ONE = "%d Species",
	WRITE_UP_SPECIES_OTHER = "%d Species",
	WRITE_UP_SKILL_ONE = "%d Skill Milestone",
	WRITE_UP_SKILL_OTHER = "%d Skill Milestones",
	WRITE_UP_COINS = "Pagle Coins +%s",
}
