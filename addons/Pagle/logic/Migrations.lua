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
		-- catch-log.md › Data: the minimap icon's angle round the minimap and its shown state (CORE-R53, CORE-R56);
		-- from 1.5, whether it is detached from the minimap, and `point`, its spot on the screen while detached, nil (no
		-- key) until it is first detached.
		minimap = { angle = ns.MINIMAP_ICON_ANGLE, hide = false, detached = false, point = nil },
		-- paste-string.md › Data: each log's last exported seq, by logId (PST-R40), and the content checkpoints kept
		-- for the next export (PST-R42).
		pasteExports = {},
		pasteCheckpoints = {},
	},
	profile = {
		books = {}, -- core/book.md › Data: each movable book's saved position by its id (BOOK-R5)
		reloadReminder = false, -- LOG-R86
		lengthUnit = nil, -- LOG-R69: "cm", "in", or nil (no default key) for the region default
		clockFormat = nil, -- CORE-R87: "24h", "12h", or nil (no default key) to follow the game's clock
		anglerTooltips = true, -- VIEW-R30: "Show other Anglers on player tooltips"
		-- LOG-R121, SET-R35 (from 1.6): "Party Hunts", sending and counting alike, `partyHunts`, has no default: nil
		-- (no key) is not asked yet, which reads off until the party letter is accepted (ANN-R113, ANN-R115).
		appearance = {}, -- SHOP-R32: each slot's pick, by slot ID
		-- announcements.md › Data; everyCatch is "Show every catch" (ANN-R13), motion is "Animations".
		announcements = {
			cozy = false,
			everyCatch = true,
			motion = true,
			budget = { on = true, count = 40, window = 300 },
			point = nil, -- ANN-R98: the Toast column's saved foot, nil (no key) until the Angler moves it
		},
		-- core/README.md › Data: `dock.point`, the tracker dock's saved place, nil (no key) until the player moves it;
		-- `dock.onlyWhileFishing`, "Show trackers only while fishing" (from 1.3), which AceDB's default gives a profile
		-- that has none.
		dock = { point = nil, onlyWhileFishing = false }, -- CORE-R70, CORE-R71, CORE-R88
	},
}

-- The party letter's id among the letters Core sends (announcements.md ANN-R115, onboarding.md ONB-R15).
local PARTY_LETTER = "core.party"

-- 1.5.3's answers to the party letter in `profile.party.letter` (ANN-R115), the letter service's state each becomes
-- (ONB-R16), and which wins where profiles differ: accepted over declined over Not now.
local PARTY_ANSWERS = { later = { "later", 1 }, declined = { "declined", 2 }, accepted = { "opened", 3 } }

-- Step 4 (1.6, #665): the party letter's answer moves from each profile's `party` (1.5.3 kept it there, beside the
-- switches, ANN-R115) into the letter service's account-wide state, `onboarding.letters["core.party"]` and, for Not now,
-- `onboarding.laterAt["core.party"]` (ONB-R16); the strongest answer of any profile wins, and of Not nows the latest.
-- A profile whose player accepted it keeps Party Hunts on (`partyHunts = true`, SET-R35). With no answer in any
-- profile, the service's own state of it, which 1.5.3 cleared before each send, is dropped unless it is `waiting`.
-- Every profile's `letter` and `laterAt` go. A DB that lost `onboarding` gets it back first (ONB-R1).
---@param db table
---@param context PagleMigrationContext?
local function movePartyLetterAnswer(db, context)
	local best, at
	for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
		local party = type(profile) == "table" and profile.party or nil
		if type(party) == "table" then
			local answer = PARTY_ANSWERS[party.letter]
			if answer then
				if party.letter == "accepted" then
					profile.partyHunts = true
				end
				if not best or answer[2] > best[2] then
					best, at = answer, nil
				end
				if answer == best and party.letter == "later" and type(party.laterAt) == "number" then
					at = math.max(at or 0, party.laterAt)
				end
			end
			party.letter, party.laterAt = nil, nil
		end
	end
	if type(db.global.onboarding) ~= "table" and best and context then
		ns.AddOnboarding(db.global, context.catchLog)
	end
	local onboarding = db.global.onboarding
	if type(onboarding) ~= "table" then
		return
	end
	local letters = type(onboarding.letters) == "table" and onboarding.letters or nil
	if not best then
		if letters and letters[PARTY_LETTER] ~= "waiting" then
			letters[PARTY_LETTER] = nil
		end
		return
	end
	letters = letters or {}
	onboarding.letters = letters
	letters[PARTY_LETTER] = best[1]
	if at then
		onboarding.laterAt = type(onboarding.laterAt) == "table" and onboarding.laterAt or {}
		onboarding.laterAt[PARTY_LETTER] = at
	end
end

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
	-- 4 (1.6, pagle-2026j, #665): the party letter's 1.5.3 answer into the letter service's state, and Party Hunts on
	-- where it was accepted (ANN-R113, ANN-R115, SET-R35).
	movePartyLetterAnswer,
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
