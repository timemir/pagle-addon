if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

-- Stats' string table (CORE-R8). Every user-facing string goes through ns.L; enUS only in 1.0. The lore keys of
-- Stats' goods are added by the generated data/Lore.lua from the M6 lore batch on (STA-R88, DATA-R107).

---@class PagleStatsNS
local ns = select(2, ...)

---@class PagleStatsStrings
ns.L = {
	-- The Module's def title, its one view and its slash entry (STA-R4).
	TITLE = "Stats",
	BOOK = "Stats",
	BOOK_SLASH_HELP = "Open or close the Stats book.",

	-- STA-R58's one allowed line: no other Stats string says or implies a Catch is owed (spec/Pagle_Stats/copy_spec.lua).
	NOTHING_IS_OWED = "Every Cast is its own roll; nothing is owed.",

	-- Stats' words (STA-R59), as logic/Text.lua writes them. Counts by noun, singular and plural, each with the count
	-- through BreakUpLargeNumbers (ns.Count).
	COUNTS = {
		Casts = { one = "%s Cast", other = "%s Casts" },
		Catches = { one = "%s Catch", other = "%s Catches" },
		Sessions = { one = "%s Session", other = "%s Sessions" },
		waters = { one = "%s water", other = "%s waters" },
		anglers = { one = "%s angler in 100 waits", other = "%s anglers in 100 wait" },
	},
	-- Durations (ns.Duration) and times ago (ns.TimeAgo).
	DURATION_UNDER_MINUTE = "under 1m",
	DURATION_MINUTES = "%dm",
	DURATION_HOURS = "%dh %02dm",
	AGO_NOW = "just now",
	AGO_MINUTES = "%dm ago",
	AGO_HOURS = "%dh ago",
	AGO_DAYS = "%dd ago",
	-- A date, "5 Oct 2026": the day without a leading zero, the month's abbreviation and the year, as `date` gives them.
	DATE = "%d %s %s",
	-- A Session's heading, "Monday 5 October": the weekday, the day without a leading zero and the month.
	SESSION_HEADING = "%s %d %s",
	-- A window's bound in realm time, "18:00".
	WINDOW_TIME = "%02d:%02d",
	-- Names (ns.Item, ns.AreaName, ns.CharacterName, ns.QualityName) and their fallbacks.
	ITEM_FALLBACK = "Item %d",
	AREA_FALLBACK = "Area %d",
	CHARACTER_NAME = "%s %s",
	CHARACTER_FALLBACK = "Character %d",
	QUALITY_FALLBACK = "Quality %d",

	-- Dry spells (STA-R50, STA-R53, STA-R54), as logic/DrySpell.lua writes them. The first sentence: never caught in
	-- the scope ("412 Casts here, none yet."), on an item's entry, in the tracker's hover, or a Dry spell of 0.
	DRY_NONE_YET = "%s %s, none yet.",
	DRY_SINCE_ENTRY = "%s since my last one, %s.",
	DRY_SINCE_TRACKER = "%s since my last %s.",
	DRY_CAUGHT_LAST = "Caught one on my last Cast %s.",
	DRY_LEARNING = "A luck reading comes once Your odds have a number.",
	-- The luck wording after it, by band and the steps inside normal ("About 38 anglers in 100 wait this long.").
	LUCK_NOTHING_UNUSUAL = "Nothing unusual.",
	LUCK_ABOUT = "About %s this long. Nothing unusual.",
	LUCK_LONG_WAIT = "Roughly 1 angler in %s waits this long. A long wait, but well within normal luck.",
	LUCK_UNLUCKY = "Roughly 1 angler in %s waits this long. Unlucky, not broken.",
	LUCK_VERY_UNLUCKY = "Only about 1 angler in %s waits this long. %s",
	LUCK_UNDER_A_MILLION = "Fewer than 1 angler in a million waits this long. %s",
	LUCK_VERY_UNLUCKY_ROLL = "Very unlucky, and every Cast is still its own roll.",
	-- Each band in a word, as the tracker's line and the short forms' ", unlucky" name it (STA-R52, STA-R82).
	BANDS = { normal = "normal", unlucky = "unlucky", veryUnlucky = "very unlucky" },
	-- The short forms: a row's margin and a tile ("212 since", ", unlucky", "just now"), a home spread watch line's
	-- end ("212 since the last, unlucky.", "caught on my last Cast.", "412 Casts, none yet.").
	DRY_SHORT_SINCE = "%s since",
	DRY_SHORT_BAND = ", %s",
	DRY_JUST_NOW = "just now",
	DRY_WATCH_SINCE = "%s since the last%s.",
	DRY_WATCH_CAUGHT_LAST = "caught on my last Cast.",
	DRY_WATCH_NONE_YET = "%s, none yet.",
}
