---@class PagleNS
local ns = select(2, ...)

-- PagleDB's schema migrations (catch-log.md › Data): pure logic over the AceDB object (CORE-R7). Migrations exist
-- only for PagleDB and each Pagle<Module>DB, never for PagleLog (ADR 0003).

--- PagleDB's defaults, the one place every PagleDB key gets its default: catch-log.md › Data, wallet-and-shop.md ›
--- Data and announcements.md › Data. Core hands them to AceDB (adapter/CatchLog.lua) and FakePagle copies them into
--- its PagleDB. schemaVersion has none, so a DB that never stored it reads as unmigrated.
ns.PAGLEDB_DEFAULTS = {
	global = {
		decodeErrors = 0, -- LOG-R16
		dev = false, -- the /pagle dev switch (#247)
		coins = { earned = {} }, -- SHOP-R3
		goods = {}, -- SHOP-R26: every registered good, by ID
		-- announcements.md › Data: the open Session's summary, moments raised with no Session open, the stored
		-- Session summary cards and the Write-up sections waiting (ANN-R50–R54, ANN-R61).
		summary = { moments = {}, lines = {} },
		pending = {},
		cards = {},
		writeUp = {},
		-- catch-log.md › Data: Core's own projections (LOG-R78), and the diagnostics buffer (LOG-R81).
		projections = { fieldReport = {} }, -- REP-R25
		diagnostics = {},
	},
	profile = {
		reloadReminder = false, -- LOG-R86
		lengthUnit = nil, -- LOG-R69: "cm", "in", or nil (no default key) for the region default
		appearance = {}, -- SHOP-R32: each slot's pick, by slot ID
		-- announcements.md › Data; everyCatch is "Show every catch" (ANN-R13).
		announcements = { cozy = false, everyCatch = true, budget = { on = true, count = 4, window = 300 } },
	},
}

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
