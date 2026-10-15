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

	-- The board's words (TKB-R36, TKB-R102, TKB-R105, TKB-R122; logic/Words.lua). Templates fill `{name}` fields; a
	-- `{ one, other }` pair is a count's singular and plural (ns.Plural).
	-- A name the client doesn't have yet (TKB-R36).
	NAME_UNKNOWN = "…",
	-- A goal's text by type ("n" Notice, "e" Expedition) and kind (TKB-R36): {n} is its need.
	GOAL_TEXT = {
		n = {
			haul = { one = "{n} Catch in {zone}", other = "{n} Catches in {zone}" },
			variety = { one = "{n} Species in {zone}", other = "{n} different Species in {zone}" },
			wanderer = { one = "Catches in {n} zone in one Session", other = "Catches in {n} zones in one Session" },
			quality = { one = "A {quality}-or-better Catch", other = "{n} {quality}-or-better Catches" },
			size = { one = "A {band}-or-better Catch", other = "{n} {band}-or-better Catches" },
			collector = "A junk item and a container in one Session",
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
	WHERE_THIS_SESSION = "this Session · {where}",
	WHERE_HERE = "{where} · here",
	-- Realm dates and times (TKB-R102, TKB-R105): the posted time, 24-hour; weekdays from Sunday, as the client's
	-- calendar counts them; months from January.
	POSTED = "Posted {weekday} {day} {month}, {time}",
	WEEKDAYS = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" },
	MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" },
	-- A countdown to a reset (TKB-R105): whole hours from one hour up, whole minutes below.
	HOURS_LEFT = "{n}h",
	MINUTES_LEFT = "{n}m",
	-- Counts (ns.Plural).
	CATCHES = { one = "{n} Catch", other = "{n} Catches" },
	COINS = { one = "{n} Coin", other = "{n} Coins" },

	-- The pins (TKB-R44, TKB-R55, TKB-R102, TKB-R105; logic/Pins.lua). Plain ASCII only: the client's fonts lack
	-- many symbols (#248).
	-- A pinned goal: its handwritten progress over its need (TKB-R104), its pay, "I'm here", a stranded goal's mark,
	-- the button and the stamp.
	PROGRESS = "{n} of {need}",
	PROGRESS_SESSION = "{n} of {need} this Session",
	PAYS = { one = "pays {n} Coin", other = "pays {n} Coins" },
	IM_HERE = "I'm here",
	NO_LONGER_CATCHABLE = "no longer catchable",
	TAKE_IT_DOWN = "take it down",
	REPOSTED = "RE-POSTED",
	-- Its hover, under the posted time (POSTED).
	ONLY_SINCE = "Only my Catches since then count",
	ONLY_SINCE_SESSION = "Only my Catches since then count, all within one Session",
	-- Empty pins (TKB-R105): {time} is the countdown to the daily reset, {weekday} the weekly reset's realm weekday.
	EMPTY_NOTICE = "A fresh Notice at reset (in {time})",
	EMPTY_NOTICE_LATER = "More Notices at later resets",
	EMPTY_EXPEDITION = "Next Expedition at the weekly reset ({weekday})",
	EMPTY_EXPEDITION_LATER = "Another at the weekly reset after",
	-- The overflow strip (TKB-R101): a goal's chip, its kind and text, and the last chip when more wait.
	OVERFLOW_CHIP = "{kind}: {text}",
	OVERFLOW_MORE = "+{n} more waiting for a pin",

	-- The spike (TKB-R103; logic/Ledge.lua). Plain ASCII only (#248).
	SPIKE_DONE = "{n} done today. The fire's lit.",
	SPIKE_EMPTY = "Done ones go on the spike.",
	-- A done goal's hover: its Coins and the fly it tied.
	SPIKE_COINS = { one = "Paid {n} Coin", other = "Paid {n} Coins" },
	SPIKE_FLY = "Tied for your Fly Box: {fly}",

	-- The Campfire on the ledge (TKB-R106): its count (DAYS, with the moments' below), or a fire gone out, or none
	-- yet; and its longest.
	CAMPFIRE_OUT = "Gone out",
	CAMPFIRE_UNLIT = "Not lit yet",
	CAMPFIRE_LONGEST = "longest {n}",
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
	-- The brass tally plate (TKB-R106): the goals done for life (NOTICES, EXPEDITIONS, with the moments' below),
	-- joined by a comma (plain ASCII, #248).
	TALLY_PLATE = "{notices}, {expeditions}",
	-- The shop link (TKB-R106, SHOP-R41): a pointing hand is drawn after it, as a texture.
	SHOP_LINK = "Coins go to the Curio Shop",
	-- The Campfire card's and the Fly Box drawer's headings.
	CARD_TITLE = "The Campfire",
	CARD_FIRE = "{fire}, {longest}",
	CARD_NEED_COINS = "{need}, {coins}",
	FLY_BOX = "Fly Box",
	DRAWER_NOTE = "Gilt-edged patterns are tied only by Expeditions.",
	CARD_MILESTONES = "Milestones",
	CARD_TALLY = "The tally",
	CARD_FLY_BOX = "The Fly Box",
	DRAWER_TITLE = "The Fly Box: {label}",

	-- The moments, the Write-up and the summary line (TKB-R85–R87; logic/Moments.lua). Plain ASCII only (#248): ", "
	-- stands for the spec's middle dot. {fly} and {title} are lore names (TKB-R130).
	DAYS = { one = "{n} day", other = "{n} days" },
	-- A done goal's toast: its title, its text with the fly it tied, and its stamp when it rides on a banner.
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
	CAMPFIRE_BURNED = "{campfire}, {k} Kindling burned",
	CAMPFIRE_WENT_OUT = "Your Campfire went out; your longest, {longest}, is kept",
	-- The summary line: {done} the goals done today, {campfire} the Campfire's days or CAMPFIRE_NOT_LIT.
	SUMMARY_LINE = "Tackle Board: {done}, {campfire}",
	SUMMARY_LINE_NOTHING_DONE = "Tackle Board: {campfire}",
	DONE_TODAY = "{n} done today",
	CAMPFIRE_NOT_LIT = "Campfire not lit",
}
