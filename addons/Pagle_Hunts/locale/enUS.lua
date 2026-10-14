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

	-- Labels in realm time (HNT-R50–R55): logic/Labels.lua. A name not loaded yet reads "…".
	NAME_UNKNOWN = "…",
	-- Durations, rounded down to the minute (HNT-R50): "37m", "2h", "2h 10m", "1d", "1d 4h".
	DURATION_MINUTES = "%dm",
	DURATION_HOURS = "%dh",
	DURATION_HOURS_MINUTES = "%dh %dm",
	DURATION_DAYS = "%dd",
	DURATION_DAYS_HOURS = "%dd %dh",
	-- Clock times "06:00", a time on another realm day "Sun 16:00", dates "12 Oct" and "12 Oct 2026" (HNT-R50).
	CLOCK = "%02d:%02d",
	WEEKDAY_CLOCK = "%s %s",
	DATE_SHORT = "%d %s",
	DATE_FULL = "%s %d",
	-- By C_DateAndTime's weekday, 1 = Sunday.
	WEEKDAYS_SHORT = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" },
	WEEKDAYS_PLURAL = { "Sundays", "Mondays", "Tuesdays", "Wednesdays", "Thursdays", "Fridays", "Saturdays" },
	MONTHS_SHORT = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" },
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
	-- The margin label (board) and the tracker label (HNT-R51).
	LABEL_NEED = "need %d",
	TRACKER_NEED = "needs %d",
	LABEL_UP_NOW = "up now",
	LABEL_ON_DEMAND = "on demand",
	LABEL_ANY_TIME = "any time",
	LABEL_WHILE_EVENT = "while the event runs",
	TRACKER_NOW = "now",
	LABEL_UNTIL = "until %s",
	TRACKER_ENDS_IN = "ends in %s",
	LABEL_IN = "in %s",
	LABEL_BACK_IN = "back in %s",
	LABEL_NO_DATE = "no date known",
	-- The window line (HNT-R52).
	LINE_UP_NOW = "Up now.",
	LINE_ON_DEMAND = "Whenever I set up %s.",
	LINE_ANY_TIME = "Open any time.",
	LINE_WHILE_EVENT = "Open while the event runs.",
	LINE_CLOSES = "Open now. Closes in %s, at %s.",
	LINE_UNTIL = "Open now, until %s.",
	LINE_SOON = "Opens in %s, at %s.",
	LINE_OPENS_AT = "Opens at %s.",
	LINE_OPENS_ON = "Opens %s.",
	LINE_BACK = "Back in %s.",
	LINE_NO_DATE = "No date known.",
	LINE_NEEDS = "Needs %d; my best is %d.",
	LINE_LURE = "A lure gets me there.",
	-- The conditions line (HNT-R53): fields joined by " · ", ranges by ", ", areas, events and auras by " or ".
	JOIN_FIELDS = " · ",
	JOIN_RANGES = ", ",
	JOIN_OR = " or ",
	TIME_RANGE = "%s–%s",
	SEASON_RANGE = "%s – %s",
	CONDITION_NIGHT = "Night %s",
	CONDITION_DAY = "Day %s",
	CONDITION_TIME = "Realm time %s",
	CONDITION_SEASON = "%s (%s)",
	SEASONS = { spring = "Spring", summer = "Summer", autumn = "Autumn", winter = "Winter" },
	CONDITION_EVENT = "%s, %s %s for %s",
	EVENT_UNKNOWN = "a calendar event",
	CONDITION_AREAS = "In %s",
	CONDITION_AURAS = "While %s is up",
	CONDITION_LURE = "With a lure on",
	CONDITION_SKILL = "Skill %d or more (lures count)",
	-- The target line (HNT-R54).
	TARGET_UNCOMMON = "Any uncommon-or-better Catch",
	TARGET_RARE = "Any rare-or-better Catch",
	TARGET_ANY = "Any fish",
	TARGET_MIN_BAND = "%s, %s or better",

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

	-- Sets on the board (HNT-R61, HNT-R66, HNT-R69): logic/Sets.lua. The nameplate's titles reuse SUMMARY_TITLES_*.
	RIBBON_BOARD = "Board",
	CRUMB_HUNTS = "Hunts",
	UPDATING = "Updating from your Catch log…",
	NAMEPLATE = "%s · %s", -- "2 titles · 5 Hunts done"
	NAMEPLATE_DONE_ONE = "%s Hunt done",
	NAMEPLATE_DONE_OTHER = "%s Hunts done",
	NAMEPLATE_TITLE = "%s, earned %s", -- the tooltip: "Clockwatcher, earned 12 Oct 2026"
	SET_EARNS = "Earns the title %s",
	SET_EARNED = "Earned: %s",
	SET_SEAL = "Title earned %s", -- the seal, with the full date
	SET_PROGRESS = "%d / %d", -- done current Hunts / current Hunts
	SET_RULE = "The first tier of every Hunt earns the title.",
	SET_RETIRED = "Retired",
}
