if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

-- The Ledger's string table (CORE-R8). Every user-facing string goes through ns.L; enUS only in 1.0.

---@class PagleLedgerNS
local ns = select(2, ...)

-- Words more than one key reads: Species Mastery's three stars (LED-R45), a check box (LED-R40, LED-R135, LED-R142).
local CAUGHT, IN_ITS_ELEMENT, REGULAR = "Caught", "In its element", "Regular"
-- The symbols the Ledger draws, as textures sized to the line's text: the client's fonts have no ★, ☆, ✓, ☑ or ☐
-- (CORE-R9, #248). Each is the Ledger art kit's sprite in its parts atlas (data/JournalArt.lua): the inked star and
-- the blank one, the tick, and the ticked and empty check boxes.
local PARTS = "Interface\\AddOns\\Pagle_Ledger\\media\\journal\\LedgerParts"
local function sprite(x, y, w, h, size)
	return ("|T%s:%s:0:0:1024:2048:%d:%d:%d:%d|t"):format(PARTS, size or "0:0", x, x + w, y, y + h)
end
local STAR = sprite(650, 1126, 23, 23)
local STAR_OFF = sprite(677, 1126, 23, 23)
local TICK = sprite(486, 1586, 27, 20, "11:15")
local CHECK_ON, CHECK_OFF = sprite(468, 1836, 34, 34), sprite(430, 1836, 34, 34)
-- Words two keys share, each built from them (LED-R33, LED-R135, LED-R147).
local BEGIN_A_NEW_LEDGER = "Begin a new Ledger"
local ZONE_REWARD = "Reward for mastery: each new seal earns XP."
local UNWRITTEN_LEGEND = "unwritten legend"

---@class PagleLedgerStrings
ns.L = {
	-- "x / N" wherever the Journal counts (LED-R132, LED-R137, LED-R143), its numbers BreakUpLargeNumbers'.
	COUNT_OF = "%s / %s",
	-- "unfished": a zone's tile and its seal with no rank (LED-R131, LED-R135); "pools" in the plain hint and a row's
	-- margin (LED-R136, LED-R141).
	UNFISHED = "unfished",
	POOLS = "pools",
	-- The Trophy Room's title, on Home's contents and its own pages (LED-R132, LED-R143).
	TROPHY_TITLE = "The Trophy Room",

	-- The Ledger's def title (LED-R1).
	TITLE = "Ledger",

	-- The summary line (LED-R95): the shown level and Ledger completion's percent, after the prestige rank above 0.
	SUMMARY_LINE = "Ledger: Angler Level %d · %d%% complete",
	SUMMARY_LINE_PRESTIGE = "Ledger: Prestige %d · Angler Level %d · %d%% complete",

	-- Names the client doesn't have (LED-R97, LED-R126).
	ITEM_FALLBACK = "Item %d",
	-- A Catch's size text (LED-R81): the Size band's name and the length in the Angler's unit, "Hefty · 13.5 in".
	SIZE_TEXT = "%s · %s",
	NAME_UNKNOWN = "...",
	-- The tab of every continent but the Eastern Kingdoms and Kalimdor (LED-R126, LED-R130).
	OTHER_WATERS = "Other waters",

	-- The Journal bindings (LED-R110): the slot's label and how a level binding is earned. Their names and
	-- descriptions are lore (LED-R160).
	BINDING_SLOT_LABEL = "Journal binding",
	BINDING_EARNED = "Angler Level %d",

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
	-- A Catch moment's item and its size text (LED-R81, LED-R97).
	ITEM_SIZE = "%s · %s",
	-- Also the Legends spread's kicker (LED-R147).
	LEGEND_TITLE = "Legend",
	LEGEND_STAMP = "Legend!",
	PRESTIGE_READY_TITLE = "Prestige ready",
	PRESTIGE_READY_TEXT = "Open the Fish Journal to begin a new Ledger.",
	PRESTIGE_READY_STAMP = "Prestige ready",
	-- A Prestige's emblem, I to X, then the Master Prestige's rank − 10 (LED-R34).
	PRESTIGE_TITLE = "Prestige %s",
	MASTER_PRESTIGE_TITLE = "Master Prestige %d",
	-- A Catch Milestone's moment and Write-up line (LED-R42, LED-R94), the count with BreakUpLargeNumbers.
	CATCHES_ONE = "%s Catch",
	CATCHES_OTHER = "%s Catches",
	SIZE_RECORD_TITLE = "Size record",
	SIZE_RECORD_STAMP = "Record",
	-- A title (lore, LED-R75) riding in a moment's text, after the text it has (LED-R97), and a completion title's own;
	-- also a Legend's page and plate (LED-R147).
	TITLE_LINE = "Title: %s",
	TEXT_WITH_TITLE = "%s. %s",
	TITLE_EARNED = "Title earned",
	CAUGHT_STAR_TITLE = CAUGHT,
	ELEMENT_STAR_TITLE = IN_ITS_ELEMENT,
	REGULAR_STAR_TITLE = REGULAR,
	FAMILY_STAR_TITLE = "Trophy family",
	-- The family's name (lore, LED-R160) and its stars.
	FAMILY_STAR_TEXT = "%s %s",
	-- One star: a moment's stars repeat it (LED-R97), the Journal prints a shown one with it (LED-R48), and a Master
	-- Prestige's stars are stamps of it (LED-R34).
	STAR = STAR,

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
	WRITE_UP_LEVEL_ROSE = "Angler Level %d to %d",
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
	-- The level's line with the prestige rank above 0.
	WRITE_UP_WITH_PRESTIGE = "%s · Prestige %d",
	WRITE_UP_LEGENDS_ONE = "%d Legend",
	WRITE_UP_LEGENDS_OTHER = "%d Legends",
	-- After the first three title lines (TITLE_LINE).
	WRITE_UP_MORE_TITLES_ONE = "+%d more title",
	WRITE_UP_MORE_TITLES_OTHER = "+%d more titles",
	WRITE_UP_SKILL_ONE = "%d Skill Milestone",
	WRITE_UP_SKILL_OTHER = "%d Skill Milestones",
	WRITE_UP_COINS = "Pagle Coins +%s",

	-- The Fish Journal's view and command (LED-R1), and its pages while the projection updates (LED-R122).
	JOURNAL = "Fish Journal",
	JOURNAL_SLASH_HELP = "Open or close the Fish Journal",
	JOURNAL_UPDATING = "The Ledger is being written up from your Catch log.",
	-- Navigation (LED-R125): the first crumb and the back link; the search slip's placeholder (LED-R148).
	JOURNAL_HOME = "Home",
	JOURNAL_BACK = "« back",
	JOURNAL_SEARCH_HINT = "Find a fish or a water…",
	-- The link to the Field report box on uncharted waters and Curios' loose pages (LED-R138, LED-R144, REP-R43), and
	-- the prompt beside it.
	JOURNAL_HELP_CHART = "Help chart the waters",
	JOURNAL_CHART_PROMPT = "Seen something Pagle doesn't know?",
	-- Home (LED-R130–R133, LED-R149). Its left page's kicker and title; its tiles are TILE_*'s.
	HOME_KICKER = "The Waters",
	HOME_TITLE = "Where I've Fished",
	-- Notes to self (LED-R133): the next rank ("{zone}: {rank}. {next requirement}"), new to find, the next star (★ or
	-- ★★★).
	HOME_NOTES = "Notes to self",
	HOME_NOTE_RANK = "%s: %s. %s",
	HOME_NOTE_NEW = "%s: %d new to find",
	HOME_NOTE_CAUGHT_STAR = "%s: %d to " .. STAR,
	HOME_NOTE_STAR = "%s: %d to " .. STAR:rep(3),
	HOME_NOTE_NONE = "Go fishing!",
	-- Its bookplate summary and contents (LED-R132), and the brass plate (LED-R149): "Lv {L} · {title} · Ledger {p}%",
	-- or BRASS_PLATE while the active title has no lore text (LED-R161).
	HOME_LEVEL = "Angler Level",
	HOME_PERCENT = "%d%%",
	HOME_CONTENTS = "In this Ledger",
	-- The contents' numerals, the Angler line's mark, and the word over the completion on Home's seal.
	HOME_NUMERALS = { "i.", "ii.", "iii.", "iv." },
	HOME_ANGLER_MARK = "»",
	HOME_SEAL_WORD = "Ledger",
	HOME_CURIOS = "Curios: junk, treasure, uncharted",
	HOME_ANGLER = "The Angler: hands, titles, bindings",
	BRASS_PLATE = "Lv %d · Ledger %d%%",
	BRASS_PLATE_TITLE = "Lv %d · %s · Ledger %d%%",

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
	HINT_SEPARATOR = " · ",
	HINT_WINDOW_SEPARATOR = ", ",
	HINT_MORE = "%s +%d",
	HINT_SKILL = "skill ~%d",
	HINT_ANY_SKILL = "any skill", -- the lowest skill base is 0 or below (DATA-R30: starting zones)

	-- A zone tile's lines (LED-R131): "Local · 63%", "2 new!".
	TILE_RANK = "%s · %d%%",
	TILE_NEW = "%d new!",
	TILE_UNFISHED_SKILL = "unfished · skill ~%d",
	TILE_UNFISHED_ANY_SKILL = "unfished · any skill", -- a skill base of 0 or below (DATA-R30)
	TILE_UNCHARTED = "uncharted waters",

	-- A list as prose: "A, B and C" (LED-R140).
	LIST_SEPARATOR = ", ",
	LIST_LAST = " and ",
	-- A Species' entry (LED-R140, LED-R141). "First landed {date} in {zone}, by {character}. {n} caught."
	ENTRY_STAMPS = { CAUGHT, IN_ITS_ELEMENT, REGULAR },
	ENTRY_FIRST = "First landed %s in %s, by %s. %s caught.",
	ENTRY_FIRST_NO_ZONE = "First landed %s, by %s. %s caught.",
	ENTRY_FOUND_IN = "Found in %s.",
	ENTRY_ONLY_BY = " Only by %s.",
	-- The size line (LED-R140): the record's size text, "{band} · {length}" (LED-R81).
	ENTRY_LARGEST = "Largest I've landed: %s",
	ENTRY_REMOVED = "No longer found in Forever's waters.",
	ENTRY_UNKNOWN = "An unknown fish",
	ENTRY_RIDDLE = '"%s"',
	ENTRY_HINT_LINK = "Read the plain hint »",
	-- The fish spread's right page (LED-R142): "☑ Caught (5/5)", "☑ In its element (1/1)", "☐ Regular (12/50)".
	FISH_KICKER = "Where to find it",
	FISH_TITLE = "Its waters",
	FISH_CAUGHT_HERE = "caught " .. TICK,
	FISH_WHEN = "When",
	FISH_CAUGHT = "%s " .. CAUGHT .. " (%d/%d)",
	FISH_ELEMENT = "%s " .. IN_ITS_ELEMENT .. " (%d/%d)",
	FISH_REGULAR = "%s " .. REGULAR .. " (%d/%d)",
	CHECK_ON = CHECK_ON,
	CHECK_OFF = CHECK_OFF,
	-- Search with no match (LED-R148).
	SEARCH_NONE = "Nothing by that name in the Ledger yet.",
	-- The search drop-down's two parts (LED-R148).
	SEARCH_WATERS = "Waters",
	SEARCH_FISH = "Fish",

	-- The Angler page (LED-R146), M3's part (LED-R4): its crumb, the bookplate and the hands on the rod. Numbers in
	-- %s are BreakUpLargeNumbers'.
	ANGLER_CRUMB = "The Angler",
	ANGLER_EX_LIBRIS = "Ex Libris",
	ANGLER_LEDGER = "The Angler's Ledger",
	ANGLER_KEPT_SINCE = "kept since %s",
	-- The Ledger's tally: its heading, its completion beside it, and each part of Ledger completion (LED-R71) by part,
	-- with its "x of N".
	ANGLER_TALLY = "The Ledger",
	ANGLER_COMPLETE = "%d%% of the Ledger complete (%s of %s)",
	ANGLER_PARTS = {
		species = "Species",
		junk = "Junk Museum",
		treasure = "Treasures",
		trophy = "Trophy Room weights",
		zones = "Zones mastered",
	},
	ANGLER_PART_COUNT = "%s of %s",
	ANGLER_CATCHES_ONE = "%s Catch",
	ANGLER_CATCHES_OTHER = "%s Catches",
	ANGLER_HANDS = "Hands on the Rod",
	ANGLER_HAND = "skill %d / %d",
	-- The Skill Milestones (LED-R40): CHECK_ON credited, CHECK_OFF not yet, then the threshold: "☑ 75".
	ANGLER_MILESTONES = "Milestones",
	ANGLER_MILESTONE = "%s %d",
	ANGLER_MILESTONE_SEPARATOR = "   ",
	-- The Angler page's M4 parts (LED-R146): the next Catch Milestone after the Catches (LED-R42), the bookplate's
	-- Prestige line and button (LED-R33, LED-R34), "Signed As" (LED-R77: the active pick marked) and "Bindings" with
	-- each binding's state (LED-R110; "Angler Level {L}" is BINDING_EARNED).
	ANGLER_NEXT_MILESTONE = " · next milestone %s",
	ANGLER_NO_PRESTIGE = "No Prestige seals yet",
	ANGLER_PRESTIGE = BEGIN_A_NEW_LEDGER .. " (Prestige)",
	ANGLER_SIGNED_AS = "Signed As",
	ANGLER_AUTOMATIC = "Automatic",
	ANGLER_BINDINGS = "Bindings",
	ANGLER_BINDING_IN_USE = "In use",
	ANGLER_BINDING_USE = "Use",
	ANGLER_BINDING_SHOP = "In the Curio Shop",

	-- The zone spread (LED-R135–R138), M3's part (LED-R4): its seal and ladder read ZONE_RANKS; UNFISHED on the
	-- seal with no rank.
	ZONE_LADDER_SEPARATOR = "·",
	ZONE_NEXT = "Next: %s",
	ZONE_NEW_HERE_ONE = "%d new to find here! My seal stays.",
	ZONE_NEW_HERE_OTHER = "%d new to find here! My seal stays.",
	-- The groups of the catches (LED-R135), by group, and a group's header: "{group} · {caught here} / {total}".
	ZONE_GROUPS = {
		anyTime = "Any time",
		pools = "Pools",
		dayNight = "Day and night",
		seasonal = "Seasonal",
		events = "Events",
		trophies = "Trophies",
		curios = "Curios",
	},
	ZONE_GROUP_COUNT = "%d / %d",
	ZONE_GROUP_NOTE = "%s · %s",
	ZONE_POOLS_NOTE = "open water and pools combined",
	-- A requirement's line, CHECK_ON or CHECK_OFF before it: "☑ a piece of junk" (the junk and treasure lines are
	-- ZONE_NEXT_JUNK and ZONE_NEXT_TREASURE).
	ZONE_REQUIREMENT = "%s %s",
	ZONE_TROPHY = "a %s trophy, any weight",
	ZONE_ALSO_NOTE = "Not in Pagle's list for these waters yet.",
	-- A Species row (LED-R136): never named until caught (LED-R124).
	ZONE_UNKNOWN_FISH = "— unknown —",
	ZONE_CAUGHT_ELSEWHERE = "%s (caught elsewhere)",
	ZONE_MARGIN_SEPARATOR = " · ",
	-- "About these waters" (LED-R137); the reward names the zone's Master title, or ends after "earns XP." while it has
	-- no lore text (LED-R161).
	ZONE_ABOUT = "About these waters",
	ZONE_SKILL = "Skill ~%d",
	ZONE_ANY_SKILL = "Any skill", -- a skill base of 0 or below (DATA-R30)
	ZONE_KNOWN = "%d%% of these waters known: %d of %d fish, %d of %d trophy families",
	ZONE_TROPHIES_HERE = "Trophies landed here",
	ZONE_REWARD = ZONE_REWARD,
	ZONE_REWARD_TITLE = ZONE_REWARD .. " The Master seal earns the title %s.",
	ZONE_PICK = "Pick a fish on the left to read its page.",
	-- A zone that isn't charted (LED-R138).
	ZONE_UNCHARTED_NOTE = "Every catch here is still written down, and counted once Pagle's data catches up.",
	ZONE_LOOSE_PAGES = "Loose pages",
	ZONE_LOOSE_TITLE = "What came up here",
	ZONE_UNCHARTED_GROUP = "Uncharted",
	ZONE_UNCHARTED_SEAL = "uncharted",
	ZONE_LOOSE_ITEM = "%s: %d×",
	ZONE_ALSO_CAUGHT_TITLE = "Also caught here",
	ZONE_NOTHING_YET = "Nothing caught here yet.",

	-- A blank star as the Journal prints it (LED-R48); a shown one is STAR.
	STAR_OFF = STAR_OFF,
	-- The Trophy Room (LED-R143, LED-R62), titled TROPHY_TITLE. Numbers in %s are BreakUpLargeNumbers'.
	TROPHY_WEIGHTS = "%s of %s weights.",
	TROPHY_KICKER = "A collection",
	TROPHY_FAMILIES = "Families",
	TROPHY_FAMILIES_NOTE = "weights",
	TROPHY_FAMILY_KICKER = "A trophy family",
	TROPHY_HEAVIEST = "heaviest",
	TROPHY_STAMPS = { "Any weight", "Half the weights", "The heaviest" },
	TROPHY_POUNDS = "pounds",
	TROPHY_LANDED = "Landed %s of %s. Heaviest so far: %s lb.",
	TROPHY_NONE_LANDED = "Not one of this family yet.",
	-- Curios (LED-R144): the Junk Museum, Treasures and the loose pages. "{item}: {n}× at {zones}, first {date}. …"
	CURIOS_CRUMB = "Curios",
	CURIOS_JUNK_KICKER = "Junk",
	CURIOS_JUNK_TITLE = "The Junk Museum",
	CURIOS_TREASURES_KICKER = "Containers and treasure",
	CURIOS_EXHIBITS = "%s of %s exhibits",
	CURIOS_EMPTY_PLINTH = "An empty plinth",
	CURIOS_TREASURES_TITLE = "Treasures",
	CURIOS_OPENED = "%s of %s opened",
	CURIOS_LOOSE_PAGES = "Loose pages: Uncharted",
	CURIOS_LOOSE_PAGE = "%s: %s× at %s, first %s. Unknown to Pagle. Logged.",
	CURIOS_UNKNOWN_WATERS = "unknown waters",
	CURIOS_NONE_UNCHARTED = "None. Every catch is in the Ledger.",
	-- Legends (LED-R147). Numbers in %s are BreakUpLargeNumbers'; the first Catch is "{date}, {zone}, {character}".
	LEGENDS_TITLE = "Legends",
	LEGENDS_KICKER = "Outside the hundred",
	LEGENDS_INDEX = "The index",
	LEGENDS_COUNT = "%s of %s. These sit outside the Ledger's hundred.",
	LEGENDS_UNWRITTEN = "an " .. UNWRITTEN_LEGEND,
	LEGENDS_UNWRITTEN_TITLE = "An " .. UNWRITTEN_LEGEND,
	-- A caught Legend's mark in the index: the star texture, as the client's fonts have no ✦ (CORE-R9, #248).
	LEGENDS_CAUGHT_MARK = STAR,
	LEGENDS_FIRST = "%s, %s, %s",
	LEGENDS_FIRST_NO_ZONE = "%s, %s",
	LEGENDS_OPEN_PLATE = "Open the plate",
	LEGENDS_PLATE_RETURN = "Click anywhere to return.",
	LEGENDS_PLATE_KICKER = "A Legend of these waters",
	LEGENDS_PLATE_SEAL = "Title",
	-- The Prestige confirm (LED-R33); a Master Prestige's stars beside emblem X are STAR stamps (LED-R34).
	PRESTIGE_CONFIRM_KICKER = "Prestige",
	PRESTIGE_CONFIRM_TITLE = BEGIN_A_NEW_LEDGER .. "?",
	PRESTIGE_CONFIRM_TEXT = "Your Angler Level starts again at 1, and climbs at half the cost. Nothing you've earned is "
		.. "taken away.",
	PRESTIGE_CONFIRM_YES = "Prestige",
	PRESTIGE_CONFIRM_NO = "Not yet",
	-- The Journal's tour stops' labels, for `/pagle dev tour list` (CORE-R68): dev-only, never shown to players.
	TOUR_HOME = "the Fish Journal: Home",
	TOUR_ZONE = "the Fish Journal: the most-fished zone, its most-caught Species open",
	TOUR_FISH = "the Fish Journal: the most-caught Species",
	TOUR_TROPHY = "the Fish Journal: the Trophy Room, on a landed family",
	TOUR_CURIOS = "the Fish Journal: Curios",
	TOUR_LEGENDS = "the Fish Journal: Legends, on a caught one",
	TOUR_ANGLER = "the Fish Journal: the Angler page",
	TOUR_SEARCH = "the Fish Journal: search results for the most-caught Species' name",
}
