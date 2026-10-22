if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- PagleHuntsDB's schema (hunts.md › Data), and the Tunables of what Hunt Events and runs pay and keep (hunts.md ›
-- Tunables): pure logic, everything passed in (CORE-R7). Every key hunts.md › Data lists has its default here from
-- the start; a ticket that changes one that has shipped adds a migration step.

--- The schema PagleHuntsDB is at once Hunts has loaded.
ns.SCHEMA_VERSION = 1

--- PagleHuntsDB's AceDB defaults (hunts.md › Data). `global.projection` has none: Core owns that table (LOG-R70).
--- `global.schemaVersion` has none either: ns.MigrateDB stamps it, so it is saved even while it equals the current
--- version and a later version can tell an old DB from a new one.
ns.DB_DEFAULTS = {
	profile = {
		-- the Hunts tracker (HNT-R75–R79) and its Pagle Wagers block's own collapsed state (HNT-R177)
		tracker = { shown = true, collapsed = false, wagersCollapsed = false },
		windowMoments = false, -- "Tell me when a pinned Hunt's window opens" (HNT-R88)
		showCompleted = false, -- the board's "show completed" filter (HNT-R82)
		pins = {}, -- { [huntID] = true } (HNT-R81)
		companionHint = true, -- "Remind me about the Pagle companion": false once dismissed (HNT-R170)
		lastHintNod = 0, -- the server time of the last companion Nod (HNT-R171)
	},
	global = {
		-- { tiers = { [huntID] = highestTier }, sets = { [setID] = true }, runs = { [runKey] = { tiers = { [huntID] =
		-- highestTier }, settled = true?, endsAt } }, ladder = { [n] = true }, goods = { [goodID] = true } } (HNT-R90,
		-- HNT-R92; `goods` made with the first earned good noted, HNT-R122)
		celebrated = { tiers = {}, sets = {}, runs = {}, ladder = {} },
	},
}

--- Brings PagleHuntsDB.global up to SCHEMA_VERSION, one ordered step at a time (hunts.md › Data). A new DB starts
--- at SCHEMA_VERSION; schema 1 has no steps yet.
---@param global table PagleHuntsDB's global section
function ns.MigrateDB(global)
	if global.schemaVersion == nil then
		global.schemaVersion = ns.SCHEMA_VERSION
	end
end

--- Tunables (hunts.md): the Activity XP a Standing Hunt pays by tier position, `{ tier 1, each further tier }`, once
--- each (HNT-R113).
ns.XP_STANDING = { 500, 250 }

--- Tunables (hunts.md): the Activity XP an event Hunt pays by tier position, `{ tier 1, each further tier }`, and a
--- completed run, all paid again in every run (HNT-R114).
ns.XP_EVENT, ns.XP_RUN = { 150, 100 }, 250

--- Tunables (hunts.md): the Coins an event Hunt pays by tier position, `{ tier 1, each further tier }`, and a completed
--- run, all paid again in every run (HNT-R110).
ns.COINS_EVENT, ns.COINS_RUN = { 15, 10 }, 50

--- Tunables (hunts.md): the completed-run counts that earn a ladder title, ascending (HNT-R148).
ns.LADDER_STEPS = { 25, 50, 100 }

--- Tunables (hunts.md): how long the celebrated set keeps a run's entry after the run ends, in seconds: 30 days
--- (HNT-R92). A rebuild raises nothing for a run that ended longer ago than that.
ns.CELEBRATED_RUN_KEEP = 30 * 86400

--- Tunables (hunts.md): how many hours back the projection's hour index reaches from its latest Cast (hunts.md ›
--- Projection state, `hours`): 14 days. A run record credits its earlier Casts from it (HNT-R149).
ns.HOUR_INDEX_HOURS = 14 * 24

--- Tunables (hunts.md): the companion hint switch (HNT-R170–R172), off at 1.0 (#288): while it is off there is no
--- hint, no Nod, no placeholder slip, no tracker line and no Settings row. The companion state is still read and pushed
--- runs still used (HNT-R153). The release that turns it on, once `Pagle_Content` works end to end, flips it here.
ns.COMPANION_HINT_ON = false

--- Tunables (hunts.md): the companion's address that Get it shows (HNT-R170). A placeholder until it is decided
--- (#289 left it to the build): the release that turns the hint switch on sets the real one.
ns.COMPANION_URL = "https://github.com/timemir/pagle-companion"

--- Tunables (hunts.md): the least time between two companion Nods, in seconds: 7 days (HNT-R171).
ns.HINT_NOD_INTERVAL = 7 * 86400

--- What `amounts` (`{ tier 1, each further tier }`, the Tunables above) pays for reaching tier `k` (HNT-R110,
--- HNT-R113, HNT-R114): amounts go by tier position, never per Hunt or per event.
---@param amounts integer[]
---@param k integer
---@return integer
function ns.TierAmount(amounts, k)
	return k == 1 and amounts[1] or amounts[2]
end
