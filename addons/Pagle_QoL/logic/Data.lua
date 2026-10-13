if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- PagleQoLDB's schema (qol.md › Data): pure logic, everything passed in (CORE-R7). Each ticket adds the keys it
-- uses, and a migration step when it changes one that has shipped.

--- The schema PagleQoLDB is at once QoL has loaded.
ns.SCHEMA_VERSION = 1

--- Brings PagleQoLDB.global up to SCHEMA_VERSION, one ordered step at a time (qol.md › Data). A new DB starts at
--- SCHEMA_VERSION; schema 1 has no steps yet.
---@param global table PagleQoLDB's global section
function ns.MigrateDB(global)
	if global.schemaVersion == nil then
		global.schemaVersion = ns.SCHEMA_VERSION
	end
end
