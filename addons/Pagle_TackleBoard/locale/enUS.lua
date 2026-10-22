if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

-- The Tackle Board's string table (CORE-R8). Every user-facing string goes through ns.L; enUS only in 1.0. The lore
-- keys (fly patterns, titles, goods) are added by the generated data/Lore.lua from the M7 lore batch on (TKB-R130,
-- DATA-R107).

---@class PagleTackleBoardNS
local ns = select(2, ...)

---@class PagleTackleBoardStrings
ns.L = {
	-- The Module's def title, its one view and its slash entry (TKB-R1).
	TITLE = "Tackle Board",
	BOARD = "Tackle Board",
	BOARD_SLASH_HELP = "Open or close the Tackle Board",
	-- Its button in the Settings status list (TKB-R1, SET-R11): before and after the board is started.
	START_MY_BOARD = "Start my board",
	OPEN_BOARD = "Open Tackle Board",
	-- The board (TKB-R100, TKB-R107, TKB-R108): the empty board's pinned slip, and what shows over the cork while the
	-- projection is updating. The plaque reads TITLE and the Start button START_MY_BOARD.
	EMPTY_SLIP = "Three Notices go up each day and an Expedition each week. Fish as you like: they fill in as you go. "
		.. "Nothing is ever taken down for being late.",
	UPDATING = "Updating…",
	UPDATING_NOTE = "Reading back every Cast since the board went up. Taking goals down waits until it's done.",

	-- The board's words (TKB-R36, TKB-R102, TKB-R105, TKB-R122; logic/Words.lua). Templates fill `{name}` fields; a
	-- `{ one, other }` pair is a count's singular and plural (ns.Plural).
	-- A name the client doesn't have yet (TKB-R36).
	NAME_UNKNOWN = "…",
	-- A zone or continent the client has no name for (TKB-R36): its area ID, or the continent's ID (GetArea().continent).
	AREA_UNKNOWN = "Area {id}",
	CONTINENT_UNKNOWN = "Continent {id}",
	-- A goal's text by type ("n" Notice, "e" Expedition) and kind (TKB-R36): {n} is its need.
	GOAL_TEXT = {
		n = {
			haul = { one = "{n} Catch in {zone}", other = "{n} Catches in {zone}" },
			variety = { one = "{n} Species in {zone}", other = "{n} different Species in {zone}" },
			wanderer = { one = "Catches in {n} zone today", other = "Catches in {n} zones today" },
			quality = { one = "A {quality}-or-better Catch", other = "{n} {quality}-or-better Catches" },
			size = { one = "A {band}-or-better Catch", other = "{n} {band}-or-better Catches" },
			collector = "A junk item and a container today",
			lure = { one = "A Catch with a lure on", other = "{n} Catches with a lure on" },
			species = "{n} {species}",
		},
		e = {
			haul = { one = "{n} Catch in {zone}", other = "{n} Catches in {zone}" },
			variety = "Every Species of {zone}",
			wanderer = { one = "Catches in {n} zone of {continent}", other = "Catches in {n} zones of {continent}" },
			quality = { one = "A {quality}-or-better Catch", other = "{n} {quality}-or-better Catches" },
			size = { one = "A {band}-or-better Catch", other = "{n} {band}-or-better Catches" },
			collector = {
				one = "A Sub-collection item you don't have",
				other = "{n} Sub-collection items you don't have",
			},
		},
	},
	-- A quality goal's minimum quality, by item quality (TKB-R36).
	QUALITY_NAMES = { [2] = "uncommon", [3] = "rare" },
	-- Each kind's label on a slip, in small caps there (TKB-R102; M7 graph, open question 8).
	KINDS = {
		haul = "Haul",
		variety = "Variety",
		wanderer = "Wanderer",
		quality = "Quality",
		size = "Size",
		collector = "Collector",
		lure = "Lure",
		species = "Species",
	},
	-- Where a goal is worked (TKB-R102), and the tracker's where line around it (TKB-R122).
	WHEREVER_IT_BITES = "wherever it bites",
	ANYWHERE = "anywhere",
	WHERE_TODAY = "today · {where}",
	WHERE_HERE = "{where} · here",
	-- Realm dates and times (TKB-R102, TKB-R105): the posted time, 24-hour; weekdays from Sunday, as the client's
	-- calendar counts them; months from January.
	POSTED = "Posted {weekday} {day} {month}, {time}",
	WEEKDAYS = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" },
	MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" },
	-- A countdown to a reset (TKB-R105): whole hours from one hour up, whole minutes below.
	HOURS_LEFT = "{n}h",
	MINUTES_LEFT = "{n}m",
	-- The reroll confirm (TKB-R56): its question by type, then what is lost ({progress}: the displayed progress over
	-- the need, "12/30"), then the two buttons.
	TAKE_DOWN_TITLE = { n = "Take down this Notice?", e = "Take down this Expedition?" },
	TAKE_DOWN_TEXT = "Its progress ({progress}) is lost, and the new one can't be taken down.",
	TAKE_DOWN_PROGRESS = "{n}/{need}",
	TAKE_DOWN_YES = "Take it down",
	TAKE_DOWN_NO = "Keep it",
	-- Counts (ns.Plural).
	CATCHES = { one = "{n} Catch", other = "{n} Catches" },
	COINS = { one = "{n} Coin", other = "{n} Coins" },

	-- The pins (TKB-R44, TKB-R55, TKB-R102, TKB-R105; logic/Pins.lua).
	-- A pinned goal: its handwritten progress over its need (TKB-R104), its pay, "I'm here", a stranded goal's mark,
	-- the button and the stamp.
	PROGRESS = "{n} of {need}",
	PROGRESS_TODAY = "{n} of {need} today",
	PAYS = { one = "pays {n} Coin", other = "pays {n} Coins" },
	-- A Notice's pay, its Coins on the coin after it.
	PAYS_WORD = "pays",
	-- An Expedition poster's header, before its kind.
	EXPEDITION = "Expedition",
	IM_HERE = "I'm here",
	NO_LONGER_CATCHABLE = "no longer catchable",
	TAKE_IT_DOWN = "take it down",
	-- Its tooltip (TKB-R55, TKB-R56, TKB-R44, TKB-R108): what it does, by type, then the one rule that applies.
	TAKE_DOWN_TIP_TITLE = "Take it down",
	TAKE_DOWN_TIP = {
		n = "Pin a fresh Notice of another kind in its place. Any progress on this one is lost.",
		e = "Pin a fresh Expedition of another kind in its place. Any progress on this one is lost.",
	},
	TAKE_DOWN_TIP_ONCE = "The new one can't be taken down in turn, unless it stops being catchable.",
	TAKE_DOWN_TIP_STRANDED = "This one is no longer catchable, so it can come down even though it was re-posted.",
	TAKE_DOWN_TIP_STRANDED_FIRST = "This one is no longer catchable: it can never be finished where it hangs.",
	TAKE_DOWN_TIP_UPDATING = "Not while the board is updating. It can come down once that's done.",
	REPOSTED = "RE-POSTED",
	-- Its hover, under the posted time (POSTED).
	ONLY_SINCE = "Only my Catches since then count",
	ONLY_SINCE_TODAY = "Only my Catches since then count, all on one board day",
	-- Empty pins (TKB-R105): {time} is the countdown to the daily reset, {weekday} the weekly reset's realm weekday.
	EMPTY_NOTICE = "A fresh Notice at reset (in {time})",
	EMPTY_NOTICE_LATER = "More Notices at later resets",
	EMPTY_EXPEDITION = "Next Expedition at the weekly reset ({weekday})",
	EMPTY_EXPEDITION_LATER = "Another at the weekly reset after",
	-- The overflow strip (TKB-R101): a goal's chip, its kind and text, and the last chip when more wait.
	OVERFLOW_CHIP = "{kind}: {text}",
	OVERFLOW_MORE = "+{n} more waiting for a pin",

	-- The spike (TKB-R103; logic/Ledge.lua).
	SPIKE_DONE = "{n} done today. The fire's lit.",
	SPIKE_EMPTY = "Done ones go on the spike.",
	-- The spike's heading, and a done slip's hand note: the Coins it paid, and the fly it tied.
	SPIKE_HEAD = "Done today",
	SPIKE_NOTE = "+{coins} · {fly}",
	SPIKE_NOTE_PLAIN = "+{coins}",
	-- A done goal's hover: its Coins and the fly it tied.
	SPIKE_COINS = { one = "Paid {n} Coin", other = "Paid {n} Coins" },
	SPIKE_FLY = "Tied for your Fly Box: {fly}",

	-- The Campfire on the ledge (TKB-R106): its count (DAYS, with the moments' below), or a fire gone out, or none
	-- yet; and its longest.
	CAMPFIRE_OUT = "Gone out",
	CAMPFIRE_UNLIT = "Not lit yet",
	CAMPFIRE_LONGEST = "longest {n}",
	-- The word after the Campfire's count on the ledge ("13 days": the count in print, the word in italics).
	DAYS_WORD = { one = "day", other = "days" },
	-- The Campfire card (TKB-R106): each day of its four-week log, dated in realm time, and what it was.
	CARD_DATE = "{weekday} {day} {month}",
	CARD_DAYS = {
		lit = "lit",
		burned = "Kindling burned",
		out = "went out",
		unlit = "not lit",
		before = "before the board",
		today = "today",
	},
	-- What a title needs, by what earns it ({n} its count).
	CARD_NEEDS = {
		campfire = "a Campfire of {n} days",
		tally = "{n} goals done",
		flybox = "every Fly Box pattern tied",
	},
	-- The Fly Box (TKB-R106): the box, and its drawer's compartments and their hovers ({date} a realm date, CARD_DATE).
	FLY_BOX_TIED = "{n} of {total} tied",
	FLY_UNTIED = "not tied yet",
	FLY_TIED = "Tied {date}",
	FLY_GOAL = "by: {goal}",
	FLY_RARE = "tied only by Expeditions",
	-- The brass tally plate (TKB-R106): the goals done for life (NOTICES, EXPEDITIONS, with the moments' below).
	TALLY_PLATE = "{notices} · {expeditions}",
	TALLY_NO_TITLE = "no title yet",
	-- The shop link (TKB-R106, SHOP-R41): a pointing hand is drawn after it, as a texture.
	SHOP_LINK = "Coins go to the Curio Shop",
	-- The Campfire card's and the Fly Box drawer's headings.
	CARD_TITLE = "The Campfire",
	CARD_FIRE = "{fire} · {longest} · {kindling}",
	KINDLING = "{n} Kindling",
	FLY_BOX = "Fly Box",
	-- The card's sections: the four-week log (its weeks headed by their first day's date, CARD_SHORT_DATE), the
	-- milestones and the titles, each with a note; each title's threshold, and what is still to go.
	CARD_WEEKS = "The last four weeks",
	CARD_WEEKS_NOTE = "board days, realm time",
	CARD_SHORT_DATE = "{day} {month}",
	CARD_MILESTONES = "Milestones",
	CARD_MILESTONES_NOTE = "each pays once",
	CARD_TITLES = "Titles",
	CARD_TITLES_NOTE = "shown on the board only",
	CARD_LABELS = { campfire = "{n} days", tally = "{n} goals", flybox = "Fly Box" },
	CARD_MORE_CAMPFIRE = { one = "{n} more day", other = "{n} more days" },
	CARD_MORE_TALLY = { one = "{n} more goal", other = "{n} more goals" },
	CARD_MORE_FLYBOX = { one = "{n} more pattern", other = "{n} more patterns" },
	-- The card's and the drawer's close mark.
	CLOSE_MARK = "×",

	-- The moments, the Write-up and the summary line (TKB-R85–R87; logic/Moments.lua). {fly} and {title} are lore
	-- names (TKB-R130).
	DAYS = { one = "{n} day", other = "{n} days" },
	-- A done goal's toast: its title, its text with the fly it tied, and its stamp when it rides on another
	-- Announcement (ANN-R11).
	NOTICE_COMPLETE = "Notice complete",
	EXPEDITION_COMPLETE = "Expedition complete",
	TIED_FOR_FLY_BOX = "{goal}. Tied for your Fly Box: {fly}",
	NOTICE_DONE = "Notice done",
	EXPEDITION_DONE = "Expedition done",
	-- A title's banner: what earned it, then the title.
	CAMPFIRE_MILESTONE = "Campfire: {n} days",
	TALLY_TITLE = "{n} goals done",
	FLY_BOX_COMPLETE = "Every pattern tied",
	TITLE_LINE = "Title: {title}",
	-- The Campfire nods: {k} Kindling used, {count} the Campfire's days, {longest} its longest; at login ("_AWAY") and
	-- at any other time.
	KINDLING_AWAY = "Your Campfire kept burning while you were away: {k} Kindling used, still {count}.",
	KINDLING_BURNED = "A day went by without a goal: {k} Kindling used. Campfire still {count}.",
	FIRE_OUT_AWAY = "Your Campfire went out while you were away. Your longest, {longest}, is kept for good. "
		.. "Any goal lights a new one, with 2 fresh Kindling.",
	FIRE_OUT = "Your Campfire went out. Your longest, {longest}, is kept for good. "
		.. "Any goal lights a new one, with 2 fresh Kindling.",
	-- The Write-up's headings ({n} formatted with BreakUpLargeNumbers) and lines.
	WRITE_UP_FIRST = {
		one = "Your Tackle Board was written up from {n} Cast",
		other = "Your Tackle Board was written up from {n} Casts",
	},
	WRITE_UP_WHILE_OFF = "While Tackle Board was off",
	NOTICES = { one = "{n} Notice", other = "{n} Notices" },
	EXPEDITIONS = { one = "{n} Expedition", other = "{n} Expeditions" },
	GOALS_AND = "{notices} and {expeditions}",
	GOALS_DONE = "{goals} done",
	COINS_LINE = "Pagle Coins +{coins}",
	FLIES_TIED = { one = "{n} fly tied for your Fly Box", other = "{n} flies tied for your Fly Box" },
	CAMPFIRE_DAYS = { one = "Campfire {n} day", other = "Campfire {n} days" },
	CAMPFIRE_BURNED = "{campfire} · {k} Kindling burned",
	CAMPFIRE_WENT_OUT = "Your Campfire went out; your longest, {longest}, is kept",
	-- The summary line: {done} the goals done today, {campfire} the Campfire's days or CAMPFIRE_NOT_LIT.
	SUMMARY_LINE = "Tackle Board: {done} · {campfire}",
	SUMMARY_LINE_NOTHING_DONE = "Tackle Board: {campfire}",
	DONE_TODAY = "{n} done today",
	CAMPFIRE_NOT_LIT = "Campfire not lit",

	-- The goods and the tracker block (TKB-R122, TKB-R125; logic/Goods.lua, adapter/TrackerBlock.lua).
	-- The tracker frame slot's label, in the Curio Shop and on Settings (TKB-R125, SET-R43).
	SLOT_TRACKER_FRAME = "Tackle Board tracker frame",
	-- The tracker's header, right of the title: the Campfire's days by the flame, then the open goals; or the open
	-- goals alone with no fire lit.
	TRACKER_OPEN = "{n} open",
	TRACKER_FIRE_OPEN = "{fire} · {open}",
	-- A goal line's count (TKB-R122): its displayed progress over its need.
	TRACKER_COUNT = "{n}/{need}",
	-- The live tracker's lines (TKB-R122, TKB-R123; logic/Tracker.lua): an Expedition's text, the line for the open
	-- goals not workable here, the line with nothing open, and a goal completed live, flashing in its count's place.
	-- While the projection is updating it reads UPDATING (TKB-R124).
	TRACKER_EXPEDITION = "Expedition: {text}",
	TRACKER_MORE = "+{n} more on the board (elsewhere)",
	TRACKER_ALL_DONE = "All done. Fresh Notices at reset.",
	TRACKER_COMPLETE = "Complete",

	-- The Tackle Board's section on the Trackers page (SET-R43, tackle-board.md › Settings).
	SETTINGS_TRACKER = "Show goals workable here",
	SETTINGS_TRACKER_TOOLTIP = "Lists the goals you can work on where you are. Before your board is started, use "
		.. "Start my board on the Pagle page.",

	-- Onboarding (core/onboarding.md; logic/Onboarding.lua, adapter/GuidePage.lua). The Module's line on the Field
	-- guide's What's in the box step (ONB-R91).
	GUIDE_BLURB = "Small goals pinned to a cork board, if you want them. They wait while you’re away.",
	-- Its step (ONB-R37): the ribbon and the foot's skip link, then the left page: its kicker, title and paragraph,
	-- and the lines by the Campfire and the Fly Box samples ({campfire}, {kindling} and {flybox} the terms after them,
	-- printed in the title's ink).
	GUIDE_RIBBON = "Tackle Board",
	GUIDE_SKIP = "Not now",
	GUIDE_KICKER = "The Tackle Board",
	GUIDE_TITLE = "Goals that wait for you",
	GUIDE_BODY = "Small Notices pinned to a cork board: a fish to find, a water to visit. Fish when you like; "
		.. "they’ll still be there.",
	GUIDE_CAMPFIRE = "{campfire} grows with each day you finish a Notice. Miss a day and {kindling} burns instead; "
		.. "it isn’t put out.",
	GUIDE_CAMPFIRE_TERM = "Your Campfire",
	GUIDE_KINDLING_TERM = "Kindling",
	GUIDE_FLY_BOX = "Each Notice you finish ties one fly for your {flybox}.",
	-- The right page: its kicker and title, the four facts ({shop} the last one's aside, in a lighter ink), Start my
	-- board (START_MY_BOARD) and what it reads once the board is up, and the line under it.
	GUIDE_ASK_KICKER = "Only if you want one",
	GUIDE_ASK_TITLE = "Shall I put up a board?",
	GUIDE_FACTS = {
		"Three Notices a day, and one bigger Expedition a week.",
		"None of them expire. Away a while? Up to six Notices and two Expeditions wait for you.",
		"Don’t fancy one? Take it down and another goes up, once each.",
		"They pay Pagle Coins, {shop}",
	},
	GUIDE_FACT_SHOP = "which buy looks in the Curio Shop.",
	BOARD_IS_UP = "Your board is up",
	GUIDE_LEAVE = "Or leave it for now. The board waits under Tackle Board in the Pagle menu, and in Settings.",
	-- The board's First look (ONB-R55–R57; adapter/FirstLook.lua): its name on the coach bar ("First look · {title}"),
	-- and its five notes, each {term} printed in the red pencil.
	LOOK_TITLE = "the Tackle Board",
	LOOK_NOTES = {
		{ text = "{term} are the bigger weekly ones. They wait too, up to two.", term = "Expeditions" },
		{ text = "A Notice {term}. Don’t fancy it? Take it down, once, for another.", term = "never expires" },
		{ text = "Your {term}: days in a row with one done. A missed day burns Kindling instead.", term = "Campfire" },
		{ text = "Each one done ties a fly for your {term}.", term = "Fly Box" },
		{ text = "They pay {term}, spent on looks in the Curio Shop.", term = "Pagle Coins" },
	},
	-- The "?" beside the board's close (ONB-R59): its mark on the pin, and its tooltip.
	LOOK_AGAIN_MARK = "?",
	LOOK_AGAIN = "Show the notes for this page again",
}
