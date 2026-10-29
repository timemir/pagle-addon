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

	-- Hunts' slot (HNT-R120) and the sample tracker a tracker frame's preview draws (HNT-R121).
	SLOT_TRACKER_FRAME = "Hunts tracker frame",
	-- Its two Hunts ("Night Run · in 37m", "Rack Hour · on demand"), the name at the left and the label at the right.
	PREVIEW_TRACKER_HUNTS = { { "Night Run", "in 37m" }, { "Rack Hour", "on demand" } },
	-- What earns each earned good, its `earnedText` in the Curio Shop, by its rule (HNT-R122): a set title, every set
	-- title, ns.WAGER_GOODS_RUNS and ns.WAGER_STUDY_RUNS completed runs, three night Wager Hunts at tier 3 and the
	-- lobster Wager's every Hunt at tier 3.
	EARNED_TEXT = {
		anySetTitle = "Finish a Hunt set",
		everySetTitle = "Finish every Hunt set",
		wagerRuns = "%d Wager runs completed",
		wagerCentury = "%d Wager runs completed",
		nightTide = "Tier 3 in three night Wager Hunts",
		deepTrench = "Tier 3 in every Hunt of the lobster Wager",
	},
	-- Window moments (HNT-R88) and their row on the Announcements page (SET-R32): logic/WindowMoments.lua.
	WINDOW_MOMENTS_SETTING = "Tell me when a pinned Hunt's window opens",
	WINDOW_MOMENTS_TOOLTIP = "A quiet Nod when a pinned Hunt's window opens. It fades when the window closes.",
	WINDOW_OPEN = "%s is open",
	WINDOW_OPENED = "%s window opened %s",
	WINDOW_OPENED_UNTIL = "%s window opened %s–%s",

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

	-- The board's timeline (HNT-R61–R63, HNT-R66, HNT-R67): logic/Timeline.lua and adapter/Timeline.lua.
	TIMELINE_TITLE = "What's biting, and when",
	GROUP_HEADINGS = {
		now = "Now: open right now",
		soon = "Soon: opens within 3 hours",
		later = "Later: opens after that, or needs more skill",
		onDemand = "On demand: starts when you do",
		wagers = "Wagers: on for days, not hours",
	},
	-- The headings as the page sets them: the group's name in small caps, then its note in italic.
	GROUP_NAMES = { now = "Now", soon = "Soon", later = "Later", onDemand = "On demand", wagers = "Wagers" },
	GROUP_NOTES = {
		now = "open right now",
		soon = "opens within 3 hours",
		later = "opens after that, or needs more skill",
		onDemand = "starts when you do",
		wagers = "on for days, not hours",
	},
	TIMELINE_LEGEND = "Hatched: open · Dashed: window unconfirmed · Pencil: needs more skill · Blue: your camp is up",
	-- The legend as the page draws it: each bar style's own stroke, then its words.
	LEGEND_ITEMS = {
		hatched = "open",
		dashed = "window unconfirmed",
		pencil = "needs more skill",
		camp = "your camp is up",
	},
	TIMELINE_KICKER = "The Board",
	-- A set's pages' kicker, both sides, and its checklist's heading (HNT-R66, the books kit v2's "Set" board).
	SET_KICKER = "Hunt set",
	SET_HUNTS_HEADING = "Hunts in this set",
	RULER_REALM_TIME = "Realm time", -- in small caps over the names, level with the ruler
	RULER_NEXT = "next %dh", -- in the hand at the ruler's right: how far ahead it reaches
	RULER_HOUR = "%02d", -- a labelled tick: the realm hour, 24-hour
	RULER_HOUR_12 = { am = "%da", pm = "%dp" }, -- a labelled tick in 12-hour (CORE-R87): "6a", "12p"
	OUT_OF_SEASON = "out of season",
	-- A set's page, its left side (HNT-R66): "{set name}: earns {title}", or "{set name}: {title}" once earned.
	SET_HEADING_EARNS = "%s: earns %s",
	SET_HEADING_EARNED = "%s: %s",
	NO_HUNTS = "No Hunts yet.",
	-- The leather's realm clock ("14:05 · Tue 14 Oct · Autumn") and checkbox (HNT-R61, HNT-R43, HNT-R82).
	WEEKDAY_DATE = "%s %s",
	CLOCK_PAUSED = "%s (paused in combat)",
	SHOW_COMPLETED = "show completed",

	-- The Hunts tracker (HNT-R75–R78) and its setting on the Trackers page (SET-R41).
	TRACKER_EMPTY = "Pin a Hunt to keep it here.",
	TRACKER_MORE = "+%d more",
	TRACKER_FIRST = "%s · %s", -- "Night Run · in 37m": the name and the tracker label
	TRACKER_JOIN = " · ", -- between the second line's target, "you're here" and the progress
	TRACKER_HERE = "you're here",
	TRACKER_PROGRESS = "%d / %d",
	TRACKER_ALL_TIERS = "all tiers",
	TRACKER_UPDATING = "updating…",
	-- The tracker's Pagle Wagers block (HNT-R175), under its header WAGERS_KICKER: a run's tracker label is "settled"
	-- or TRACKER_ENDS_IN's; its second line its first marks and its closest Hunt, joined by TRACKER_JOIN.
	TRACKER_SETTLED = "settled",
	TRACKER_FIRST_MARKS = "%d of %d first marks",
	TRACKER_CLOSEST = "%s: %d / %d", -- "Shore Snapper: 1 / 2": the closest Hunt, its count and its next threshold
	TRACKER_WAGERS_MORE = "+%d more wagers on the table",
	SETTING_SHOW_TRACKER = "Show the Hunts tracker",
	SETTING_SHOW_TRACKER_TOOLTIP = "A small tracker under the minimap with the Hunts you've pinned on the board.",

	-- Hunts' moments, Write-up and summary line (HNT-R86, HNT-R89, HNT-R111). Counts come in singular and plural
	-- pairs, *_ONE and *_OTHER.
	HUNT_COMPLETE = "Hunt complete",
	HUNT_COMPLETE_STAMP = "Hunt",
	HUNT_TIER = "%s tier", -- "Silver tier"
	HUNT_TIER_TEXT = "%s · %d caught", -- "Night Run · 10 caught"
	TRIMS = { bronze = "Bronze", silver = "Silver", gold = "Gold" }, -- HNT-R18
	TITLE_EARNED = "Title earned",
	TITLE_EARNED_STAMP = "Title",
	-- Pagle Wagers' moments (HNT-R86's wager rows): logic/WagerMoments.lua. A further mark's text is HUNT_TIER_TEXT's.
	WAGER_MARK = "Pagle Wagers",
	WAGER_MARK_TEXT = "%s · first mark", -- "Shore Snapper · first mark"
	WAGER_MARK_STAMP = "Mark",
	WAGER_TIER = "%s mark", -- "Silver mark"
	WAGER_SETTLED = "Wager settled",
	WAGER_SETTLED_STAMP = "Settled",
	WRITE_UP_FIRST_BUILD_ONE = "Your Hunts were written up from %s Cast",
	WRITE_UP_FIRST_BUILD_OTHER = "Your Hunts were written up from %s Casts",
	WRITE_UP_WHILE_OFF = "While Hunts was off",
	WRITE_UP_COMPLETED_ONE = "%s Hunt completed",
	WRITE_UP_COMPLETED_OTHER = "%s Hunts completed",
	WRITE_UP_FURTHER_ONE = "%s further tier",
	WRITE_UP_FURTHER_OTHER = "%s further tiers",
	WRITE_UP_SETTLED_ONE = "%s wager settled",
	WRITE_UP_SETTLED_OTHER = "%s wagers settled",
	WRITE_UP_TITLE = "Title: %s",
	WRITE_UP_COINS = "Pagle Coins +%s",
	WRITE_UP_XP = "Angler XP +%s",
	SUMMARY_LINE = "Hunts: %s of %s done · %s", -- "Hunts: 3 of 16 done · 1 title"
	-- Once a run is settled (HNT-R89): "Hunts: 3 of 16 done · 1 title · 2 wagers settled".
	SUMMARY_LINE_SETTLED = "Hunts: %s of %s done · %s · %s",
	SUMMARY_TITLES_ONE = "%s title",
	SUMMARY_TITLES_OTHER = "%s titles",
	SUMMARY_SETTLED_ONE = "%s wager settled",
	SUMMARY_SETTLED_OTHER = "%s wagers settled",

	-- A Hunt's entry on the board's right page (HNT-R3, HNT-R64–R66, HNT-R69): logic/Entry.lua.
	ENTRY_KICKER = "%s · %s",
	ENTRY_NATURAL = "Natural",
	ENTRY_IMPOSED = "Imposed",
	ENTRY_RETIRED = "Retired %s",
	ENTRY_BACK = "back to %s",
	ENTRY_PIN = "Pin to the tracker",
	ENTRY_UNPIN = "Unpin",
	-- The wax seal: the full date tier 1 was reached, or the dashed ring before it.
	SEAL_HUNTED = "Hunted %s",
	SEAL_NOT_YET = "not yet",
	-- The pressed seal's words as it stacks them: the word in small caps over the short date, the year under it.
	SEAL_HUNTED_WORD = "Hunted",
	-- The pin toggle's words beside its pin.
	ENTRY_PINNED = "Pinned",
	ENTRY_PIN_WORD = "Pin",
	-- A tier not yet reached, in italic beside its threshold.
	LADDER_NOT_YET = "not yet",
	-- The tier ladder: each tier's threshold, its Catch's short date and zone, and the ink bar's words.
	LADDER_WHEN_ZONE = "%s, %s",
	LADDER_PROGRESS = "%d / %d",
	LADDER_CAUGHT = "%d caught",
	-- The effort counter (HNT-R26) and HNT-R27's note: plain counts, no link; "1 Cast", "2 Casts".
	EFFORT_CASTS_ONE = "%d Cast",
	EFFORT_CASTS_OTHER = "%d Casts",
	EFFORT = "%s under these conditions.",
	EFFORT_SINCE = "%s under these conditions, %d since my last one.",
	EFFORT_ODDS = "Odds live in Stats.",
	-- The set line: "{set}: {done} of {current} · earns {title}", or "· earned {title}".
	SET_LINE = "%s: %d of %d · %s",
	SET_EARNS = "earns %s",
	SET_EARNED = "earned %s",
	SET_LINE_UPDATING = "%s: %s",
	-- Chips (HNT-R65).
	CHIP_HERE = "you're here",
	CHIP_MORE = "+%d more",
	CHIP_SKILL = "skill %d",
	CHIP_SHORT = "needs %d, best: %d",
	CHIP_LURE = "needs a lure",
	CHIP_UNCONFIRMED = "unconfirmed",
	UNCONFIRMED_WINDOW = "This window is an estimate.",
	UNCONFIRMED_GATING = "Not yet seen biting only in this window.",
	-- HNT-R67's right page on the Board when no row is visible.
	ENTRY_ALL_DONE = 'Every Hunt here is done. Tick "show completed" to see them again.',

	-- Sets on the board (HNT-R61, HNT-R66, HNT-R69): logic/Sets.lua. The nameplate's titles reuse SUMMARY_TITLES_*.
	RIBBON_BOARD = "Board",
	CRUMB_HUNTS = "Hunts",
	UPDATING = "Updating from your Catch log…", -- the entry's lines say it too (logic/Entry.lua)
	NAMEPLATE = "%s · %s", -- "2 titles · 5 Hunts done"
	NAMEPLATE_DONE_ONE = "%s Hunt done",
	NAMEPLATE_DONE_OTHER = "%s Hunts done",
	NAMEPLATE_TITLE = "%s, earned %s", -- the tooltip: "Clockwatcher, earned 12 Oct 2026"
	SET_PAGE_EARNS = "Earns the title %s",
	SET_PAGE_EARNED = "Earned: %s",
	SET_SEAL = "Title earned %s", -- the seal, with the full date
	SET_SEAL_WORD = "Earned", -- the pressed seal's word over the short date and the year
	SET_PROGRESS = "%d of %d done", -- done current Hunts, current Hunts
	SET_RULE = "The first tier of every Hunt earns the title.",
	SET_RETIRED = "Retired",

	-- Hunts' tour stops' labels, for `/pagle dev tour list` (CORE-R68): dev-only, never shown to players.
	TOUR_BOARD = "the Hunts board: the Board, on the Hunt it picks",
	TOUR_BOARD_NOW = "the Hunts board: a Hunt in Now",
	TOUR_BOARD_SOON = "the Hunts board: a Hunt in Soon",
	TOUR_BOARD_LATER = "the Hunts board: a Hunt in Later",
	TOUR_BOARD_ON_DEMAND = "the Hunts board: a Hunt in On demand",
	TOUR_BOARD_WAGERS = "the Hunts board: the wager strip and the WAGERS group, a run's entry",
	TOUR_WAGERS = "the Hunts board: the Pagle Wagers spread, its tickets and ladder",
	TOUR_SET = "the Hunts board: a set's page, its title earned",
	TOUR_SET_ENTRY = "the Hunts board: an entry opened from its set's page",
	TOUR_RETIRED = "the Hunts board: a Retired Hunt's entry",
	TOUR_TRACKER = "the Hunts tracker in the dock, with three pins",
	TOUR_BINDING = "the Hunts board in the %s binding",
	TOUR_TRACKER_FRAME = "the Hunts tracker in the %s frame",

	-- Pagle Wagers on the Board (HNT-R161, HNT-R163, HNT-R164): logic/Wagers.lua. Hunt Events are only ever
	-- "Pagle Wagers" to players (CONTEXT.md), and nothing here claims odds, a due fish or a chance (HNT-R27).
	WAGERS_KICKER = "Pagle Wagers", -- the spread's kicker, the breadcrumb between "Hunts" and the run, and the
	-- tracker's Pagle Wagers header (HNT-R175)
	JOIN_ZONES = " & ",
	STRIP_CLOSES = "closes in %s", -- a server-time duration (HNT-R203)
	STRIP_MORE = "+%d more on the table",
	RUN_KICKER_ROTATION = "From the rotation · %s waters",
	BANDS = { low = "low", mid = "mid", high = "high" }, -- an event's skill band (HNT-R156)
	RUN_KICKER_PUSHED = "Sent by the companion",
	-- The run's time block (HNT-R163): in the hand "closes in {duration}" (STRIP_CLOSES), once settled its own line, or
	-- for a run ahead when it opens; under it its end and its length.
	RUN_SETTLED_OPEN = "settled, and still open",
	RUN_OPENS = "opens %s", -- "opens Sat 17:00"
	RUN_UNTIL_ALL = "until %s · %s in all", -- "until Sat 17:00 · 3d in all"
	RUN_UNTIL_TABLE = "until %s · %s on the table", -- a run ahead: "until Tue 17:00 · 3d on the table"
	SEAL_SETTLED_WORD = "Settled", -- the seal pressed over a settled run's mark, over its short date
	-- An event Hunt's shape (HNT-R163), then its target line: "Timed · Darkshore Grouper, 22:00–04:00".
	SHAPES = { timed = "Timed", big = "Big ones", quality = "Quality", haul = "Haul", named = "Named fish" },
	RUN_HUNT_LINE = "%s · %s",
	RUN_TARGET_TIME = "%s, %s",
	-- A Hunt's count at its row's right, the count (the %s) in the hand: "61 / 135", or "12 caught" past its last tier.
	RUN_HUNT_PROGRESS = "%s / %d",
	RUN_HUNT_CAUGHT = "%s caught",
	-- A Timed Hunt's window under its row, in realm time.
	RUN_WINDOW_OPEN = "open now, until %s", -- "open now, until 04:00"
	RUN_WINDOW_SHUT = "opens at %s, in %s", -- "opens at 22:00, in 2h 50m"
	-- The Casts made in the run's waters, with its Hunts' first marks: "84 Casts in these waters this run · 1 of 4 first
	-- marks".
	RUN_CASTS_ONE = "%s Cast in these waters this run · %d of %d first marks",
	RUN_CASTS_OTHER = "%s Casts in these waters this run · %d of %d first marks",
	-- The two pay boxes: what the run has paid, and what settling it pays (Tunables) or that it has.
	PAY_SO_FAR = "Paid so far",
	PAY_AMOUNT = "+%d XP · %d Coins",
	PAY_SETTLE = "Settle it",
	PAY_SETTLED = "Settled",
	PAY_PAID_OUT = "paid out",
	-- The pay rule, from the Tunables: tier 1's XP and Coins, a further tier's, then a settled run's.
	RUN_PAY_RULE = "Each Hunt's first mark pays +%d XP and %d Coins, each tier after it +%d XP and %d Coins, and "
		.. "settling the wager +%d XP and %d Coins more.",
	-- The Refreshes a run pays (HNT-R117): a pay box's line beside its Coins, a count in the pay rule, and the rule's
	-- last sentence by which of the two pay (a third mark, settling the wager, or both).
	PAY_REFRESH_ONE = "+%s Refresh",
	PAY_REFRESH_OTHER = "+%s Refreshes",
	REFRESH_ONE = "%s Refresh",
	REFRESH_OTHER = "%s Refreshes",
	RUN_PAY_RULE_REFRESH_BOTH = " A Hunt's third mark also pays %s, and settling the wager %d more.",
	RUN_PAY_RULE_REFRESH_TIER = " A Hunt's third mark also pays %s.",
	RUN_PAY_RULE_REFRESH_RUN = " Settling the wager also pays %s.",
	-- The right page on the Pagle Wagers spread with no run at all.
	ENTRY_NONE_TITLE = "Nothing to read yet",
	ENTRY_NONE_HAND = "When a wager goes up it will be written here: its waters, its Hunts and what it pays.",

	-- The Pagle Wagers ribbon and spread (HNT-R162, HNT-R204): logic/Sets.lua's ribbon, logic/WagersSpread.lua's
	-- tickets, rows ahead and ladder. As above, nothing here claims odds, a due fish or a chance (HNT-R27).
	RIBBON_ON = "%d on", -- under the ribbon's name while runs are on
	SPREAD_TITLE = "On the table",
	-- The note under the title, which follows the table.
	SPREAD_NOTE_MANY = "%d wagers on. Land every Hunt's first mark before its wager closes.",
	SPREAD_NOTE_ONE = "One wager on. Land every Hunt's first mark before it closes.",
	SPREAD_NOTE_AHEAD = "Nothing on just now. The next wager opens %s.", -- the first run ahead's start, "Sat 17:00"
	SPREAD_NOTE_NONE = "Nothing on the table, and nothing posted yet.",
	-- The closing note in the margin: the event's name up to its first comma, and the time to its end.
	SPREAD_CLOSING = "%s closes in %s!",
	SPREAD_ON_NOW = "On now",
	SPREAD_AHEAD = "Ahead",
	SPREAD_AHEAD_CAPTION = "posted, and may change before it opens",
	SPREAD_EMPTY = "No wagers on the table, and none posted ahead. The rotation puts one on at the next turn.",
	-- A wager ticket: its zones and its end, "Darkshore · until Sat 17:00", or once it closed "closed Sat 17:00"; its
	-- first marks; "closed" in its stub.
	TICKET_LINE = "%s · %s",
	TICKET_CLOSED_AT = "closed %s",
	TICKET_CLOSED = "closed",
	TICKET_MARKS = "%d of %d first marks",
	TICKET_UPDATING = "updating…", -- its marks while the projection updates (HNT-R69)
	-- An event short of skill (HNT-R156), in pencil on its ticket, its row ahead and its entry: its skill's lower end.
	NEEDS_SKILL = "needs skill %d",
	-- A run ahead's row: when it opens, and its length.
	AHEAD_OPENS = "opens %s",
	AHEAD_FOR = "for %s",
	LADDER_LABEL = "The ladder",
	-- A holiday run's tag (DATA-R97), on its ticket and as its entry's chip: interface text, keyed by tag ID.
	HOLIDAYS = {
		hallows_end = "Hallow's End",
		winter_veil = "Feast of Winter Veil",
		lunar_festival = "Lunar Festival",
		noblegarden = "Noblegarden",
		midsummer = "Midsummer Fire Festival",
		harvest_festival = "Harvest Festival",
		stv_extravaganza = "Stranglethorn Fishing Extravaganza",
	},
	-- The ladder (HNT-R148): "0 wagers settled · 25 more for Bookmaker's Bane", or past the last mark its count alone.
	WAGERS_SETTLED_ONE = "%s wager settled",
	WAGERS_SETTLED_OTHER = "%s wagers settled",
	WAGERS_LADDER_LINE = "%s · %d more for %s",

	-- Onboarding (core/onboarding.md; adapter/Look.lua). Hunts' line on the Field guide's What's in the box (ONB-R91);
	-- the board's First look (ONB-R57): its window's name on the coach bar ("First look · Hunts") and its five notes,
	-- verbatim from the canvas (board 13, the kit's World.lua), each *term* pencilled in red by Core. The fifth is
	-- ONB-R57's, naming Pagle Wagers as its ribbon reads (WAGERS_KICKER) and its wagers as players see them, never as
	-- Hunt Events. Then the "?" beside the board's close (ONB-R59).
	GUIDE_BLURB = "Fish that only bite at night, in winter or at the fair, and which of them bite right now.",
	LOOK_TITLE = "Hunts",
	LOOK_GROUPS = "*Now*, *Soon* and *Later*: what’s open, what opens within three hours, and the rest.",
	LOOK_NOW_LINE = "The red line is *now*, in realm time. Hatched bars are when each Hunt is open.",
	LOOK_NATURAL = "*Natural* means the game itself keeps this fish to its hours. Imposed Hunts are Pagle’s own rules.",
	LOOK_PIN = "*Pin* a Hunt to keep it on your tracker while you fish.",
	LOOK_SETS = "Each ribbon is a *Hunt set*. Finish every Hunt in one and its title is yours. *Pagle Wagers* holds the "
		.. "wagers on the table now.",
	LOOK_HELP = "?",
	LOOK_AGAIN = "Show the notes for this page again",
	-- The companion hint (HNT-R170–R172, HNT-R176): logic/Companion.lua and adapter/Companion.lua, shown only while the
	-- hint switch is on. Interface text, not lore; as above, nothing here claims odds, a due fish or a chance
	-- (HNT-R27). Missing, its two lines (the second for a first install, PUSH-R90); not running, its one. The weekly
	-- Nod's line is its own, shorter (HNT-R171).
	HINT_MISSING = "New wagers are out there. The Pagle companion brings them: more XP, more Coins, and the Sonar Scope toast style.",
	HINT_NOD = "New wagers are out there. The Pagle companion brings them: more XP, more Coins.",
	HINT_FIRST_INSTALL = "Installed it just now? Log out to character select once.",
	HINT_NOT_RUNNING = "The Pagle companion isn't running. Start it to get this week's wagers.",
	HINT_GET_IT = "Get it",
	HINT_DISMISS = "Dismiss",
	-- Get it's box, holding the companion's address selected for Ctrl+C (as the Field report's link, REP-R40).
	HINT_ADDRESS_KICKER = "The Pagle companion",
	HINT_ADDRESS_COPY = "Ctrl+C to copy",
	HINT_ADDRESS_CLOSE = "Close",
	-- The tracker's Pagle Wagers block with no run on (HNT-R176), and its link to the Pagle Wagers spread.
	TRACKER_HINT_MISSING = "New wagers with the Pagle companion",
	TRACKER_HINT_NOT_RUNNING = "Pagle companion not running",
	TRACKER_HINT_WHY = "why?",
	-- Its row on the Announcements page, under Hunts' header (SET-R32), only while the switch is on.
	COMPANION_HINT_SETTING = "Remind me about the Pagle companion",
	COMPANION_HINT_TOOLTIP = "A line on the Hunts board, and a Nod once a week, while the Pagle companion isn't "
		.. "bringing you new wagers.",

	-- The run log's dev diagnostic lines (HNT-R140, HNT-R151, logic/RunLog.lua): dev-only, never shown to players.
	RUN_LOG_EVENT_IGNORED = "Hunts: the pushed definition of %s is ignored: %s (HNT-R140)",
	RUN_LOG_RUN_IGNORED = "Hunts: a pushed run of %s is ignored: it needs an event ID and times start < end (HNT-R151)",
}
