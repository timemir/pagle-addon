if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- PagleLedgerDB's schema (ledger.md › Data): pure logic, everything passed in (CORE-R7). Each ticket adds the keys it
-- uses, and a migration step when it changes one that has shipped.

--- The schema PagleLedgerDB is at once the Ledger has loaded.
ns.SCHEMA_VERSION = 1

--- PagleLedgerDB's AceDB defaults (ledger.md › Data). `global.projection` has none: Core owns it (LOG-R70).
--- `profile.activeTitle` defaults to nil, automatic (LED-R77). The celebrated set starts empty, with `coins = 0`
--- (LED-R90).
ns.DB_DEFAULTS = {
	global = {
		celebrated = { coins = 0 },
	},
}

--- Brings PagleLedgerDB.global up to SCHEMA_VERSION, one ordered step at a time (ledger.md › Data). A new DB starts
--- at SCHEMA_VERSION; schema 1 has no steps yet.
---@param global table PagleLedgerDB's global section
function ns.MigrateDB(global)
	if global.schemaVersion == nil then
		global.schemaVersion = ns.SCHEMA_VERSION
	end
end
