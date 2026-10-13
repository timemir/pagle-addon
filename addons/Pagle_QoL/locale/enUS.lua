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
	-- The Fishing page's While you fish section (qol.md › Settings, QOL-R62).
	SETTINGS_WHILE_YOU_FISH = "While you fish",
	SETTINGS_AUDIO_MIX = "Fishing audio mix",
	SETTINGS_AUDIO_MIX_TOOLTIP = "While you fish: effects at full; music, ambience and dialog muted; master untouched. Put back afterwards.",
	SETTINGS_BACKGROUND_SOUND = "Keep sound when the game is in the background",
	SETTINGS_AUTO_LOOT = "Auto-loot while fishing",
	SETTINGS_AUTO_LOOT_TOOLTIP = "Only while you fish. Skipped if you already have auto-loot on.",
	-- The conflict popup and what its choices print (QOL-R81, QOL-R83).
	CONFLICT_TEXT = "Two addons want your fishing key.",
	CONFLICT_USE_PAGLE = "Use Pagle",
	CONFLICT_USE_OTHER = "Use %s",
	CONFLICT_USE_OTHERS = "Use the others",
	CONFLICT_TURNED_OFF = "Pagle: turned off %s. Type /reload to finish.",
	CONFLICT_TURNED_OFF_QOL = "Pagle: turned off Pagle QoL. Type /reload to finish. Pagle keeps recording your Catches.",
}
