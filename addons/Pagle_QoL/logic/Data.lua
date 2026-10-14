if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- PagleQoLDB's schema (qol.md › Data): pure logic, everything passed in (CORE-R7). Each ticket adds the keys it
-- uses, and a migration step when it changes one that has shipped.

--- The schema PagleQoLDB is at once QoL has loaded.
ns.SCHEMA_VERSION = 1

--- PagleQoLDB's AceDB defaults (qol.md › Data). Each ticket adds the keys it uses.
ns.DB_DEFAULTS = {
	-- gear: each character's fishing set, by character GUID (QOL-R40).
	global = { lease = {}, gear = {} },
	profile = {
		-- Casting: how the player casts, with the Fishing key, a double right-click or both (QOL-R12).
		input = "both",
		-- Lures and clams: Lures, and the lure chosen for Only this one (QOL-R50).
		lures = { mode = "best", item = 6529 },
		-- Open clams between Casts (QOL-R56).
		clams = true,
		-- While you fish: what a Fishing stretch leases besides soft-interact (QOL-R62).
		audio = { on = true, background = false },
		autoLoot = true,
		-- The next-action button: Show the next-action button, and its place once Shift-drag moved it, as
		-- { point, relativeTo = "UIParent", relativePoint, x, y } by name; nil (no default) is the default place
		-- (QOL-R72, QOL-R73).
		indicator = { shown = true },
	},
}

--- Brings PagleQoLDB.global up to SCHEMA_VERSION, one ordered step at a time (qol.md › Data). A new DB starts at
--- SCHEMA_VERSION; schema 1 has no steps yet.
---@param global table PagleQoLDB's global section
function ns.MigrateDB(global)
	if global.schemaVersion == nil then
		global.schemaVersion = ns.SCHEMA_VERSION
	end
end
