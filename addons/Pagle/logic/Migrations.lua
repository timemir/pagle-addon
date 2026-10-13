---@class PagleNS
local ns = select(2, ...)

-- PagleDB's schema migrations (catch-log.md › Data): pure logic over the AceDB object (CORE-R7). Migrations exist
-- only for PagleDB and each Pagle<Module>DB, never for PagleLog (ADR 0003).

--- PagleDB's migration steps, in order: step n brings a DB below schemaVersion n up to n. Step 1 is the first
--- schema, so there is nothing to migrate yet.
---@type fun(db: table)[]
ns.PAGLEDB_MIGRATIONS = {
	function() end,
}

--- Runs every step above `db.global.schemaVersion`, in order, and records the last one run. A DB already at or past
--- the last step is left as it is.
---@param db { global: table }
---@param steps fun(db: table)[]
function ns.Migrate(db, steps)
	local version = db.global.schemaVersion or 0
	for n = version + 1, #steps do
		steps[n](db)
		db.global.schemaVersion = n
	end
end
