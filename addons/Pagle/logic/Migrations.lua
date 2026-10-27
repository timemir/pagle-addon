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
		coins = { earned = {} }, -- SHOP-R3; `logId` too, no default (migration step 3)
		activityXP = { earned = {} }, -- AXP-R3; `logId` too, no default (activity-xp.md › Data)
		tickets = { earned = {}, spent = {} }, -- REF-R3; `logId` too, no default (refresh.md › Data)
		pushed = {}, -- PUSH-R13: `seq`, the last accepted file's, no default (pushed-content.md › Data)
		goods = {}, -- SHOP-R26: every registered good, by ID
		-- announcements.md › Data: the open Session's summary, moments raised with no Session open, the stored
		-- Session summary cards and the Write-up sections waiting (ANN-R50–R54, ANN-R61).
		summary = { moments = {}, lines = {} },
		pending = {},
		cards = {},
		writeUp = {},
		-- catch-log.md › Data: Core's own projections (LOG-R78), and the diagnostics buffer (LOG-R81).
		-- REP-R25; wallet-and-shop.md › Data; varieties.md › Data (VAR-R10).
		projections = { fieldReport = {}, wallet = {}, varieties = {} },
		diagnostics = {},
		-- catch-log.md › Data: the minimap icon's angle round the minimap and its shown state (CORE-R53, CORE-R56).
		minimap = { angle = ns.MINIMAP_ICON_ANGLE, hide = false },
		-- paste-string.md › Data: each log's last exported seq, by logId (PST-R40).
		pasteExports = {},
	},
	profile = {
		books = {}, -- core/book.md › Data: each movable book's saved position by its id (BOOK-R5)
		reloadReminder = false, -- LOG-R86
		lengthUnit = nil, -- LOG-R69: "cm", "in", or nil (no default key) for the region default
		clockFormat = nil, -- CORE-R87: "24h", "12h", or nil (no default key) to follow the game's clock
		anglerTooltips = true, -- VIEW-R30: "Show other Anglers on player tooltips"
		appearance = {}, -- SHOP-R32: each slot's pick, by slot ID
		-- announcements.md › Data; everyCatch is "Show every catch" (ANN-R13), motion is "Animations".
		announcements = {
			cozy = false,
			everyCatch = true,
			motion = true,
			budget = { on = true, count = 40, window = 300 },
		},
		-- core/README.md › Data: `dock.point`, the tracker dock's saved place, nil (no key) until the player moves it.
		dock = { point = nil }, -- CORE-R70, CORE-R71
	},
}

--- What a migration step may read besides the DB: login step 1 opens the Catch log before it migrates (LOG-R1).
---@class PagleMigrationContext
---@field catchLog PagleCatchLog

--- PagleDB's migration steps, in order: step n brings a DB below schemaVersion n up to n.
---@type fun(db: table, context: PagleMigrationContext)[]
ns.PAGLEDB_MIGRATIONS = {
	-- 1: the first schema, so nothing to migrate.
	function() end,
	-- 2 (M8.5): the onboarding state, new or returning by the Catch log (ONB-R1, ONB-R2, logic/Onboarding.lua).
	function(db, context)
		ns.AddOnboarding(db.global, context.catchLog)
	end,
	-- 3 (M8): the Coins totals belong to the log's logId (SHOP-R3). A DB from before stored none, and its totals are
	-- this log's: they take its logId, so ADDON_LOADED keeps them (a disabled Module's too, SHOP-R4).
	function(db, context)
		local coins = db.global.coins
		if type(coins) == "table" then
			coins.logId = context.catchLog.data.logId
		end
	end,
}

--- Runs every step above `db.global.schemaVersion`, in order, each with `context`, and records the last one run. A DB
--- already at or past the last step is left as it is.
---@param db { global: table }
---@param steps fun(db: table, context: table?)[]
---@param context table? what the steps read besides the DB (PagleMigrationContext for PAGLEDB_MIGRATIONS)
function ns.Migrate(db, steps, context)
	local version = db.global.schemaVersion or 0
	for n = version + 1, #steps do
		steps[n](db, context)
		db.global.schemaVersion = n
	end
end
