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
}
