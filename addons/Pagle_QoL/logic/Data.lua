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
	global = { lease = {}, gear = {}, poleSwap = {} },
	profile = {
		-- Casting: how the player casts, with the Fishing key, a double right-click or both (QOL-R12).
		input = "both",
		-- Lures and clams: Lures, and the lure chosen for Only this one (QOL-R50).
		lures = { mode = "best", item = 6529 },
		-- Open clams between Casts (QOL-R56).
		clams = true,
		-- While you fish: what a Fishing stretch leases besides soft-interact (QOL-R62). Each channel is whether the mix
		-- changes it and its volume in percent, 0 being Off, and the output device a name, "" for Don't change
		-- (QOL-R68): the defaults are the mix 1.1 leased.
		audio = {
			on = true,
			background = false,
			master = { on = false, volume = 100 },
			effects = { on = true, volume = 100 },
			music = { on = true, volume = 0 },
			ambience = { on = true, volume = 0 },
			dialog = { on = true, volume = 0 },
			device = "",
		},
		autoLoot = true,
		-- The next-action button: Show the next-action button, Hide until a fishing pole is in hand, and its place once
		-- Shift-drag moved it, as { point, relativeTo = "UIParent", relativePoint, x, y } by name; nil (no default) is
		-- the default place (QOL-R72, QOL-R73).
		indicator = { shown = true, untilPole = false },
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
