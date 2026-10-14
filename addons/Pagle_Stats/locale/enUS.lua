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

	-- The book's leather (STA-R72, STA-R74, STA-R75; stats.md › UI › On the leather): the breadcrumbs' root, the ribbons
	-- and the ribbon pages' kickers, the nameplate, the live line, and what the nameplate and every page body read while
	-- the projection is updating.
	BOOK_ROOT = "Stats",
	BOOK_WHERE_I_AM = "Where I am",
	BOOK_THIS_SESSION = "This Session",
	BOOK_LAST_SESSION = "My last Session",
	BOOK_LIFETIME = "Lifetime",
	BOOK_SESSIONS = "Sessions",
	-- "1,840 Casts · 31 Sessions · since 5 Oct 2026": the Casts and Sessions counts (ns.Count) and the first Cast's date.
	BOOK_NAMEPLATE = "%s · %s · since %s",
	-- The same without a date, should no Session record hold the Casts.
	BOOK_NAMEPLATE_UNDATED = "%s · %s",
	BOOK_NO_CASTS = "No Casts yet",
	-- "Session: 51 Casts · 46 Catches · 21m", after the live line's gilt dot.
	BOOK_LIVE_LINE = "Session: %s · %s · %s",
	BOOK_UPDATING = "Updating my records…",

	-- The Session pages (stats.md › UI › This Session, Sessions; STA-R97). A Session's entry: its kicker on the Sessions
	-- page ("Session 12", numbered from the oldest), "21:04 to now, 25m at the water.", its figures and headings.
	SESSION_NUMBERED = "Session %s",
	SESSION_SPAN = "%s to %s, %s at the water.",
	SESSION_NOW = "now",
	SESSION_CASTS = "Casts",
	SESSION_CATCHES = "Catches",
	SESSION_GOT_AWAY = "Got away",
	-- "7 (12%)": the got-away count and its rate.
	SESSION_GOT_AWAY_VALUE = "%s (%d%%)",
	SESSION_PER_HOUR = "Catches per hour",
	SESSION_SKILL = "Skill gained",
	SESSION_SKILL_VALUE = "+%s",
	SESSION_BY_QUALITY = "By quality",
	SESSION_WHERE_AND_WHO = "Where and who",
	-- This Session's right page, and the ruled ledgers' columns: "Started" reads "5 Oct 2026 21:04" (date, time), and
	-- "Where" the zones joined by ", ".
	SESSIONS_BEFORE_THAT = "Before that",
	SESSIONS_EARLIER = "Earlier Sessions",
	SESSIONS_EVERY = "Every Session",
	SESSIONS_STARTED = "Started",
	SESSIONS_WHERE = "Where",
	SESSIONS_LENGTH = "Length",
	SESSIONS_CASTS = "Casts",
	SESSIONS_CATCHES = "Catches",
	SESSIONS_STARTED_AT = "%s %s",
	SESSIONS_WHERE_JOIN = ", ",
	-- The Sessions page's note, by Core's Session gap in minutes (LOG-R60), and its pager.
	SESSIONS_NOTE = "A Session ends after %d minutes without a Cast.",
	SESSIONS_LATER = "later",
	SESSIONS_EARLIER_PAGE = "earlier",
	SESSIONS_PAGE = "page %d of %d",
	NO_SESSIONS = "No Sessions yet.",

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

	-- Your odds (logic/Odds.lua, STA-R43, STA-R45–R47). Every odds view carries the heading (STA-R46).
	ODDS_HEADING = "Your odds",
	ODDS_LEARNING_SHORT = "learning %d/%d",
	ODDS_LEARNING = "Learning…",
	ODDS_UNSEEN = "not seen yet",
	ODDS_KNOWN_SHORT = "1 in %s",
	ODDS_KNOWN = "about 1 in %s",
	-- What a reading rests on (STA-R46): where, then " {window}", then ", {side}".
	ODDS_HERE = "here",
	ODDS_ACROSS = "across %s",
	ODDS_WITH_WINDOW = "%s %s",
	ODDS_WITH_SIDE = "%s, %s",
	ODDS_SIDE_HI = "at or above %d skill",
	ODDS_SIDE_LO = "below %d skill",
	ODDS_LEARNING_SENTENCE = "%s of the %d Casts I need %s before Your odds show a number.",
	ODDS_SCOPE_LINE = "From %s of my Casts %s; %s caught.",
	ODDS_UNSEEN_SENTENCE = "In %s Casts %s: rarer than about 1 in %s, if it bites here at all.",
	ODDS_RANGE = "Likely between 1 in %s and 1 in %s (95%%).",
	ODDS_RANGE_ROUNDING = "Within rounding of 1 in %s (95%%).",
	-- The extra sentences after a reading's own, each when it applies (STA-R46).
	ODDS_NOTE_ENTRY = "Pagle hasn't confirmed it bites here yet.",
	ODDS_NOTE_WINDOW = "The window isn't confirmed yet.",
	ODDS_NOTE_LINE = "The no-junk line isn't confirmed yet.",
	ODDS_NOTE_POOL = "Open water and pools combined: there is no pool data.",
	-- Window names by ID (STA-R47): `event` for any `event.<eventID>`, `other` for any other ID.
	WINDOW_NAMES = {
		day = "by day",
		night = "by night",
		spring = "in spring",
		summer = "in summer",
		autumn = "in autumn",
		winter = "in winter",
		event = "during its event",
		other = "in its window",
	},
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
