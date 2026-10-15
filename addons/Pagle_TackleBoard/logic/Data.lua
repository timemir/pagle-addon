if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- PagleTackleBoardDB's schema (tackle-board.md › Data) and the Tunables several Tackle Board tickets share: pure
-- logic, everything passed in (CORE-R7). A Tunable only one ticket reads lives in that ticket's own logic/ file.

--- The schema PagleTackleBoardDB is at once the Tackle Board has loaded.
ns.SCHEMA_VERSION = 1

--- PagleTackleBoardDB's AceDB defaults (tackle-board.md › Data). `global.board` has none: Core owns that table, the
--- projection's (LOG-R70). `global.schemaVersion` has none either: ns.MigrateDB stamps it, so it is saved even while
--- it equals the current version and a later version can tell an old DB from a new one.
ns.DB_DEFAULTS = {
	global = {
		-- The goals and titles already celebrated (TKB-R83): { goals = { [goalID] = true }, titles = { [titleID] = true } }
		celebrated = { goals = {}, titles = {} },
	},
	profile = {
		tracker = true, -- "Show goals workable here" (tackle-board.md › Settings, TKB-R120)
		trackerCollapsed = false, -- the tracker block collapsed (TKB-R122)
		lean = true, -- the board's papers lean; `/pagle board lean` turns it off for a client that draws them wrong
	},
}

--- Brings PagleTackleBoardDB.global up to SCHEMA_VERSION, one ordered step at a time (tackle-board.md › Data). A new
--- DB starts at SCHEMA_VERSION; schema 1 has no steps yet.
---@param global table PagleTackleBoardDB's global section
function ns.MigrateDB(global)
	if global.schemaVersion == nil then
		global.schemaVersion = ns.SCHEMA_VERSION
	end
end

-- The shared Tunables (tackle-board.md › Tunables).

--- Expedition pins on the board's top row; the Expedition cap matches it (TKB-R20, TKB-R101).
ns.EXPEDITION_PINS = 2

--- Notice pins in the two rows below; the Notice cap matches it (TKB-R20, TKB-R101).
ns.NOTICE_PINS = 6

--- Board days of history kept: the Campfire's four-week log and completed goals (TKB-R106, Data).
ns.KEPT_DAYS = 28

--- Each continent's uiMapID by its continent ID, `GetArea().continent` (the instance map ID), for its name through
--- C_Map.GetMapInfo (TKB-R36). Only a continent listed here can be a Wanderer Expedition's target (TKB-R33).
ns.CONTINENT_MAPS = {
	[0] = 1415, -- Eastern Kingdoms
	[1] = 1414, -- Kalimdor
}
