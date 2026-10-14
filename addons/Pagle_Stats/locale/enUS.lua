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
}
