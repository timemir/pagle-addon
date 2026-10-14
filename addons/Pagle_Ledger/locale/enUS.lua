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

	-- The summary line (LED-R95): the shown level and Ledger completion's percent.
	SUMMARY_LINE = "Ledger: Angler Level %d · %d%% complete",

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
	ZONE_RANK_TITLE = "Zone rank: %s",
	ZONE_RANK_STAMP = "Rank up",
	ZONE_MASTER_TITLE = "Zone Master",
	ZONE_MASTER_STAMP = "Master",
	TROPHY_WEIGHT_TITLE = "Trophy weight",
	TROPHY_WEIGHT_STAMP = "Trophy",
	NEW_CURIO_TITLE = "New curio",
	NEW_CURIO_STAMP = "New!",
	UNCHARTED_TITLE = "Unknown catch, logged",
	UNCHARTED_STAMP = "Logged",
	ELEMENT_STAR_TITLE = "In its element",
	REGULAR_STAR_TITLE = "Regular",
	FAMILY_STAR_TITLE = "Trophy family",
	-- The family's name (lore, LED-R160) and its stars.
	FAMILY_STAR_TEXT = "%s %s",
	-- One star; a moment's stars repeat it (LED-R97).
	STAR = "★",

	-- Zone Mastery's ranks, Visitor to Master (LED-R50).
	ZONE_RANKS = { "Visitor", "Regular", "Local", "Expert", "Master" },

	-- A zone's next requirement (LED-R134), from its shown rank, and new to find (LED-R52) after it.
	ZONE_NEXT_VISITOR = "Catch anything here to become a Visitor",
	ZONE_NEXT_REGULAR_ONE = "Regular: %d more any-time Species",
	ZONE_NEXT_REGULAR_OTHER = "Regular: %d more any-time Species",
	ZONE_NEXT_LOCAL_ONE = "Local: %d more any-time Species",
	ZONE_NEXT_LOCAL_OTHER = "Local: %d more any-time Species",
	ZONE_NEXT_EXPERT = "Expert: %s",
	ZONE_NEXT_GATED_ONE = "%d more day, night, seasonal or event catch",
	ZONE_NEXT_GATED_OTHER = "%d more day, night, seasonal or event catches",
	ZONE_NEXT_JUNK = "a piece of junk",
	ZONE_NEXT_TREASURE = "a treasure",
	ZONE_NEXT_SEPARATOR = ", ",
	ZONE_NEXT_MASTER_ONE = "Master: a trophy from %d more family",
	ZONE_NEXT_MASTER_OTHER = "Master: a trophy from %d more families",
	ZONE_NEXT_MASTERED = "Master of these waters",
	ZONE_NEXT_WITH_NEW = "%s · %s",
	ZONE_NEW_TO_FIND_ONE = "%d new to find: the data grew, and your seal stays",
	ZONE_NEW_TO_FIND_OTHER = "%d new to find: the data grew, and your seal stays",

	-- Write-up sections (LED-R93) and their lines (LED-R94). Numbers in %s are BreakUpLargeNumbers'.
	WRITE_UP_FIRST_BUILD_ONE = "Your Ledger was written up from %s Cast",
	WRITE_UP_FIRST_BUILD_OTHER = "Your Ledger was written up from %s Casts",
	WRITE_UP_WHILE_OFF = "While the Ledger was off",
	WRITE_UP_LEVEL = "Angler Level %d",
	WRITE_UP_LEVEL_ROSE = "Angler Level %d → %d",
	WRITE_UP_SPECIES_ONE = "%d Species",
	WRITE_UP_SPECIES_OTHER = "%d Species",
	WRITE_UP_ZONES_ONE = "%d zone ranked",
	WRITE_UP_ZONES_OTHER = "%d zones ranked",
	WRITE_UP_MASTERED_ONE = "%d mastered",
	WRITE_UP_MASTERED_OTHER = "%d mastered",
	-- Zones ranked, then those mastered.
	WRITE_UP_ZONES_MASTERED = "%s · %s",
	WRITE_UP_TROPHY_ONE = "%d trophy weight",
	WRITE_UP_TROPHY_OTHER = "%d trophy weights",
	WRITE_UP_CURIO_ONE = "%d curio",
	WRITE_UP_CURIO_OTHER = "%d curios",
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
	-- Home (LED-R130–R133, LED-R149). Its left page's kicker and title; its tiles are TILE_*'s.
	HOME_KICKER = "The Waters",
	HOME_TITLE = "Where I've Fished",
	-- Notes to self (LED-R133): the next rank ("{zone}: {rank}. {next requirement}"), new to find, the next star.
	HOME_NOTES = "Notes to self",
	HOME_NOTE_RANK = "%s: %s. %s",
	HOME_NOTE_NEW = "%s: %d new to find",
	HOME_NOTE_STAR = "%s: %d to ★★★",
	HOME_NOTE_NONE = "Go fishing!",
	-- Its bookplate summary and contents (LED-R132), and the brass plate (LED-R149, without the title in M3).
	HOME_LEVEL = "Angler Level",
	HOME_PERCENT = "%d%%",
	HOME_CONTENTS = "In this Ledger",
	HOME_TROPHY_ROOM = "The Trophy Room",
	HOME_CURIOS = "Curios: junk, treasure, uncharted",
	HOME_ANGLER = "The Angler: hands, titles, bindings",
	HOME_COUNT = "%d / %d",
	BRASS_PLATE = "Lv %d · Ledger %d%%",

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

	-- The plain hint (LED-R141, DATA-R112): "night · pools · Ashenvale · Darkshore +1 · skill ~150".
	HINT_ANY_TIME = "Any time",
	HINT_POOLS = "pools",
	HINT_SEPARATOR = " · ",
	HINT_WINDOW_SEPARATOR = ", ",
	HINT_MORE = "%s +%d",
	HINT_SKILL = "skill ~%d",

	-- A zone tile's lines (LED-R131): "Local · 63%", "2 new!".
	TILE_RANK = "%s · %d%%",
	TILE_NEW = "%d new!",
	TILE_UNFISHED = "unfished",
	TILE_UNFISHED_SKILL = "unfished · skill ~%d",
	TILE_UNCHARTED = "uncharted waters",

	-- A list as prose: "A, B and C" (LED-R140).
	LIST_SEPARATOR = ", ",
	LIST_LAST = " and ",
	-- A Species' entry (LED-R140, LED-R141). "First landed {date} in {zone}, by {character}. {n} caught."
	ENTRY_STAMPS = { "Caught", "In its element", "Regular" },
	ENTRY_FIRST = "First landed %s in %s, by %s. %s caught.",
	ENTRY_FIRST_NO_ZONE = "First landed %s, by %s. %s caught.",
	ENTRY_FOUND_IN = "Found in %s.",
	ENTRY_ONLY_BY = " Only by %s.",
	ENTRY_REMOVED = "No longer found in Forever's waters.",
	ENTRY_UNKNOWN = "An unknown fish",
	ENTRY_RIDDLE = "“%s”",
	ENTRY_HINT_LINK = "Read the plain hint ▸",
	-- The fish spread's right page (LED-R142): "☑ In its element (1/1)", "☐ Regular (12/50)".
	FISH_KICKER = "Where to find it",
	FISH_TITLE = "Its waters",
	FISH_CAUGHT_HERE = "caught ✓",
	FISH_WHEN = "When",
	FISH_ELEMENT = "%s In its element (%d/%d)",
	FISH_REGULAR = "%s Regular (%d/%d)",
	CHECK_ON = "☑",
	CHECK_OFF = "☐",
	-- Search with no match (LED-R148).
	SEARCH_NONE = "Nothing by that name in the Ledger yet.",

	-- The Angler page (LED-R146), M3's part (LED-R4): its crumb, the bookplate and the hands on the rod. Numbers in
	-- %s are BreakUpLargeNumbers'.
	ANGLER_CRUMB = "The Angler",
	ANGLER_EX_LIBRIS = "Ex Libris",
	ANGLER_LEDGER = "The Angler's Ledger",
	ANGLER_KEPT_SINCE = "kept since %s",
	ANGLER_LEVEL = "Angler Level %d",
	ANGLER_COMPLETE = "%d%% of the Ledger complete (%s of %s)",
	-- The parts of Ledger completion (LED-R71), by part.
	ANGLER_PARTS = {
		species = "Species %s of %s",
		junk = "Junk Museum %s of %s",
		treasure = "Treasures %s of %s",
		trophy = "Trophy Room weights %s of %s",
		zones = "Zones mastered %s of %s",
	},
	ANGLER_CATCHES_ONE = "%s Catch",
	ANGLER_CATCHES_OTHER = "%s Catches",
	ANGLER_HANDS = "Hands on the Rod",
	ANGLER_HAND = "%s: skill %d / %d",
	-- The Skill Milestones (LED-R40): ☑ credited, ☐ not yet.
	ANGLER_MILESTONES = "Milestones",
	ANGLER_MILESTONE_DONE = "☑ %d",
	ANGLER_MILESTONE_OPEN = "☐ %d",
	ANGLER_MILESTONE_SEPARATOR = "   ",

	-- Stars as the Journal prints them (LED-R48): a shown star, a blank one.
	STAR_ON = "★",
	STAR_OFF = "☆",
	-- The Trophy Room (LED-R143, LED-R62). Numbers in %s are BreakUpLargeNumbers'.
	TROPHY_TITLE = "The Trophy Room",
	TROPHY_WEIGHTS = "%s of %s weights. Real weights, from the game's own trophy fish.",
	TROPHY_INDEX_LINE = "%s %s",
	TROPHY_INDEX_COUNT = "%s / %s",
	TROPHY_STAMPS = { "Any weight", "Half the weights", "The heaviest" },
	TROPHY_POUNDS = "pounds, as the game weighs them",
	TROPHY_LANDED = "Landed %s of %s. Heaviest so far: %s lb.",
	TROPHY_NONE_LANDED = "Not one of this family yet.",
	TROPHY_TICK_MARK = "✓",
	-- Curios (LED-R144): the Junk Museum, Treasures and the loose pages. "{item}: {n}× at {zones}, first {date}. …"
	CURIOS_CRUMB = "Curios",
	CURIOS_JUNK_TITLE = "The Junk Museum",
	CURIOS_EXHIBITS = "%s of %s exhibits",
	CURIOS_EMPTY_PLINTH = "An empty plinth",
	CURIOS_TREASURES_TITLE = "Treasures",
	CURIOS_OPENED = "%s of %s opened",
	CURIOS_LOOSE_PAGES = "Loose pages: Uncharted",
	CURIOS_LOOSE_PAGE = "%s: %s× at %s, first %s. Unknown to Pagle. Logged.",
	CURIOS_UNKNOWN_WATERS = "unknown waters",
	CURIOS_NONE_UNCHARTED = "None. Every catch is in the Ledger.",
	CURIOS_HELP_CHART = "Help chart the waters",
	-- The Prestige confirm (LED-R33), and a Master Prestige's star stamp beside emblem X (LED-R34).
	PRESTIGE_CONFIRM = "Begin a new Ledger? Your Angler Level starts again at 1, and climbs at half the cost. Nothing you've earned is taken away.",
	PRESTIGE_CONFIRM_YES = "Prestige",
	PRESTIGE_CONFIRM_NO = "Not yet",
	PRESTIGE_STAR = "★",
}
