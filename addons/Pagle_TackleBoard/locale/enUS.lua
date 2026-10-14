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
}
