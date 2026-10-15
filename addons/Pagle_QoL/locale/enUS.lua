if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

-- QoL's string table (CORE-R8). Every user-facing string goes through ns.L; enUS only in 1.0.

---@class PagleQoLNS
local ns = select(2, ...)

---@class PagleQoLStrings
ns.L = {
	-- QoL in the Settings status list, and its button there (QOL-R2, CORE-R44).
	TITLE = "QoL",
	SETTINGS_ACTION = "Fishing settings »",
	-- Key Bindings › AddOns (QOL-R1, QOL-R10).
	BINDING_HEADER = "Pagle",
	BINDING_FISHING_KEY = "Pagle: Fishing key",
	-- The Fishing page (qol.md › Settings, SET-R20).
	SETTINGS_CASTING = "Casting",
	SETTINGS_CAST_WITH = "Cast with",
	SETTINGS_CAST_WITH_TOOLTIP = "Also on the compartment menu and /pagle qol input.",
	SETTINGS_CAST_WITH_KEY = "Fishing key",
	SETTINGS_CAST_WITH_CLICK = "Double right-click",
	SETTINGS_CAST_WITH_BOTH = "Both",
	SETTINGS_FISHING_KEY = "Fishing key",
	SETTINGS_FISHING_KEY_TOOLTIP = "Each press does the next single thing: cast, reel, or a lure, gear or clam when needed.",
	-- The Fishing page's Lures and clams section (qol.md › Settings, QOL-R50).
	SETTINGS_LURES_AND_CLAMS = "Lures and clams",
	SETTINGS_LURES = "Lures",
	SETTINGS_LURES_TOOLTIP = "A press before a cast applies a lure when none is on.",
	SETTINGS_LURES_OFF = "Off",
	SETTINGS_LURES_BEST = "Best I have",
	SETTINGS_LURES_ONE = "Only this one",
	SETTINGS_LURE = "Lure",
	-- A lure whose name the client hasn't loaded yet, by item ID (QOL-R54).
	SETTINGS_LURE_UNNAMED = "Item %d",
	-- Open clams between Casts (qol.md › Settings, QOL-R56).
	SETTINGS_CLAMS = "Open clams between Casts",
	SETTINGS_CLAMS_TOOLTIP = "One clam per press, never during a cast.",
	-- The Fishing page's While you fish section (qol.md › Settings, QOL-R62).
	SETTINGS_WHILE_YOU_FISH = "While you fish",
	SETTINGS_AUDIO_MIX = "Fishing audio mix",
	SETTINGS_AUDIO_MIX_TOOLTIP = "While you fish: effects at full; music, ambience and dialog muted; master untouched. Put back afterwards.",
	SETTINGS_BACKGROUND_SOUND = "Keep sound when the game is in the background",
	SETTINGS_AUTO_LOOT = "Auto-loot while fishing",
	SETTINGS_AUTO_LOOT_TOOLTIP = "Only while you fish. Skipped if you already have auto-loot on.",
	-- Input on the compartment menu (QOL-R16) and through /pagle qol (QOL-R2, QOL-R17).
	MENU_INPUT = "Input: %s",
	INPUT_KEY = "Fishing key",
	INPUT_CLICK = "Double-click",
	INPUT_BOTH = "Both",
	SLASH_HELP = "input key|click|both: choose how you cast",
	SLASH_USAGE = "Pagle: /pagle qol input key|click|both",
	INPUT_SET_KEY = "Pagle: cast with the Fishing key.",
	INPUT_SET_CLICK = "Pagle: cast with a double right-click.",
	INPUT_SET_BOTH = "Pagle: cast with the Fishing key or a double right-click.",
	-- The conflict popup and what its choices print (QOL-R81, QOL-R83).
	CONFLICT_TEXT = "Two addons want your fishing key.",
	CONFLICT_USE_PAGLE = "Use Pagle",
	CONFLICT_USE_OTHER = "Use %s",
	CONFLICT_USE_OTHERS = "Use the others",
	CONFLICT_TURNED_OFF = "Pagle: turned off %s. Type /reload to finish.",
	CONFLICT_TURNED_OFF_QOL = "Pagle: turned off Pagle QoL. Type /reload to finish. Pagle keeps recording your Catches.",
	-- The Reload now popup after a choice (QOL-R83).
	CONFLICT_RELOAD_TEXT = "Reload the interface now to finish?",
	CONFLICT_RELOAD_NOW = "Reload now",
	CONFLICT_RELOAD_LATER = "Later",
	-- The out-of-lures Nudge (QOL-R53): under Best I have, and under Only this one with the lure's name.
	NUDGE_OUT_OF_LURES = "Your lure is gone and there are none left in your bags.",
	NUDGE_OUT_OF_LURE = "Your lure is gone and there's no %s left in your bags.",
	-- Gear: Swap gear in Key Bindings › AddOns (QOL-R1, QOL-R46), the Fishing page's Gear section (qol.md › Settings,
	-- QOL-R40, QOL-R41), the free-slot lines with the set names filled in (QOL-R42), and the swap-back Nudge (QOL-R77).
	BINDING_SWAP_GEAR = "Pagle: Swap gear",
	SETTINGS_GEAR = "Gear",
	SETTINGS_FISHING_SET = "Fishing set",
	SETTINGS_FISHING_SET_TOOLTIP = "The Fishing key puts it on when no pole is in hand. Double-click skips this.",
	SETTINGS_FISHING_SET_NONE = "None (gear stays as it is)",
	SETTINGS_SAVE_FISHING_SET = "Save what I'm wearing as my fishing set",
	SETTINGS_SWAP_GEAR = "Swap gear",
	SETTINGS_SWAP_GEAR_TOOLTIP = "Swaps between your fishing set and what you wore before (saved as Pagle Previous).",
	GEAR_NEEDS_SLOT = "Pagle: needs a free equipment set slot for %s.",
	GEAR_NEEDS_TWO_SLOTS = "Pagle: needs two free equipment set slots for %s and %s.",
	NUDGE_SWAP_BACK = "Still holding your pole. Press %s to swap back.",
	-- Filled with BINDING_SWAP_GEAR, which the Nudge prints in red.
	NUDGE_SWAP_BACK_UNBOUND = "Still holding your pole. Bind %s to swap back in one press.",
	-- The next-action button: its one-word labels (QOL-R71), its tooltips (QOL-R74), and its rows in the Fishing
	-- page's While you fish section (qol.md › Settings, QOL-R73).
	BUTTON_CAST = "Cast",
	BUTTON_REEL = "Reel",
	BUTTON_GEAR = "Gear",
	BUTTON_LURE = "Lure",
	BUTTON_CLAM = "Clam",
	BUTTON_TOOLTIP_CAST = "Cast",
	BUTTON_TOOLTIP_REEL = "Reel in",
	BUTTON_TOOLTIP_GEAR = "Put on %s",
	BUTTON_TOOLTIP_LURE = "Apply %s",
	BUTTON_TOOLTIP_CLAM = "Open %s",
	BUTTON_TOOLTIP_NOTHING = "Nothing to do",
	SETTINGS_SHOW_BUTTON = "Show the next-action button",
	SETTINGS_SHOW_BUTTON_TOOLTIP = "Shows what your next press will do. Shift-drag to move.",
	SETTINGS_BUTTON_POSITION = "Button position",
	SETTINGS_BUTTON_RESET = "Reset",
	-- QoL's tour stops' labels, for `/pagle dev tour list` (CORE-R68): dev-only, never shown to players.
	TOUR_SETTINGS = "QoL's rows on the Fishing page",
	TOUR_NUDGE = "a sample swap-back Nudge",
	TOUR_NOTES = "samples of the conflict note and the Reload now note",
}
