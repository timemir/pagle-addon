if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- PagleStatsDB's schema (stats.md › Data): pure logic, everything passed in (CORE-R7). Every key stats.md › Data
-- lists has its default here from the start; a ticket that changes one that has shipped adds a migration step.

--- The schema PagleStatsDB is at once Stats has loaded.
ns.SCHEMA_VERSION = 1

--- PagleStatsDB's AceDB defaults (stats.md › Data). `global.projection` has none: Core owns that table (LOG-R70).
--- `global.schemaVersion` has none either: ns.MigrateDB stamps it, so it is saved even while it equals the current
--- version and a later version can tell an old DB from a new one. There is no celebrated set: Stats celebrates
--- nothing (STA-R2, LOG-R77).
ns.DB_DEFAULTS = {
	profile = {
		tracker = false, -- "Show the live tracker" (STA-R81)
		watched = {}, -- { { item = itemID, area = areaID } }, at most 3, oldest first (STA-R60)
	},
}

--- Brings PagleStatsDB.global up to SCHEMA_VERSION, one ordered step at a time (stats.md › Data). A new DB starts
--- at SCHEMA_VERSION; schema 1 has no steps yet.
---@param global table PagleStatsDB's global section
function ns.MigrateDB(global)
	if global.schemaVersion == nil then
		global.schemaVersion = ns.SCHEMA_VERSION
	end
end
