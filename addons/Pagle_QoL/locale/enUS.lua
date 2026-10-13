if not Pagle then
	return
end

-- QoL's string table (CORE-R8). Every user-facing string goes through ns.L; enUS only in 1.0.

---@class PagleQoLNS
local ns = select(2, ...)

---@class PagleQoLStrings
ns.L = {
	-- QoL in the Settings status list, and its button there (QOL-R2, CORE-R44).
	TITLE = "QoL",
	SETTINGS_ACTION = "Fishing settings ›",
	-- Key Bindings › AddOns (QOL-R1, QOL-R10).
	BINDING_HEADER = "Pagle",
	BINDING_FISHING_KEY = "Pagle: Fishing key",
	-- The Fishing page (qol.md › Settings, SET-R20).
	SETTINGS_CASTING = "Casting",
	SETTINGS_FISHING_KEY = "Fishing key",
	SETTINGS_FISHING_KEY_TOOLTIP = "Each press does the next single thing: cast, reel, or a lure, gear or clam when needed.",
}
