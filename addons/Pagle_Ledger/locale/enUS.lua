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
	-- The tab of every continent but the Eastern Kingdoms and Kalimdor (LED-R126, LED-R130).
	OTHER_WATERS = "Other waters",

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

	-- The Fish Journal's view and command (LED-R1), and its pages while the projection updates (LED-R122).
	JOURNAL = "Fish Journal",
	JOURNAL_SLASH_HELP = "Open or close the Fish Journal",
	JOURNAL_UPDATING = "The Ledger is being written up from your Catch log.",
	-- Navigation (LED-R125): the first crumb, the separator between crumbs and the back link.
	JOURNAL_HOME = "Home",
	JOURNAL_CRUMB_SEPARATOR = "❧",
	JOURNAL_BACK = "☚ back",
	-- Home's left page's title (LED-R130), all the placeholder Home draws until the Home ticket.
	HOME_TITLE = "Where I've Fished",

	-- Dates (LED-R126): "3 Mar", and "3 Mar 2025" outside the current realm year.
	DATE_SHORT = "%d %s",
	DATE_WITH_YEAR = "%s %d",
	MONTHS_SHORT = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" },
	-- "back in {month}" (LED-R127).
	MONTHS = {
		"January",
		"February",
		"March",
		"April",
		"May",
		"June",
		"July",
		"August",
		"September",
		"October",
		"November",
		"December",
	},

	-- Window labels (LED-R127), by window ID; any other `event.<id>` is WINDOW_EVENT.
	WINDOWS = {
		day = "day",
		night = "night",
		spring = "spring",
		summer = "summer",
		autumn = "autumn",
		winter = "winter",
		["event.301"] = "Extravaganza",
	},
	WINDOW_EVENT = "event",
	-- Window states (LED-R127), and a window's line: "{label}, {state}".
	WINDOW_OPEN = "biting now",
	WINDOW_BACK_HOURS = "back in %d h",
	WINDOW_BACK_MINUTES = "back in %d min",
	WINDOW_BACK_MONTH = "back in %s",
	WINDOW_LINE = "%s, %s",

	-- The ink XP bar (LED-R145). Numbers in %s are BreakUpLargeNumbers'.
	XP_BAR_TEXT = "%s of %s.",
	XP_BAR_FRESH_ONE = " Fresh Water for %d more Catch.",
	XP_BAR_FRESH_OTHER = " Fresh Water for %d more Catches.",
	XP_BAR_SET_ASIDE = "%s XP set aside for the next Prestige",
}
