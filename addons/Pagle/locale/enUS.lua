-- Core's string table (CORE-R8). Every user-facing string goes through ns.L; enUS only in 1.0.

---@class PagleNS
local ns = select(2, ...)

---@class PagleStrings
ns.L = {
	-- LOG-R18: PagleLog was in another format, so Core started a new log.
	LOG_FORMAT_CHANGED = "Pagle: dev log format changed; started a new log.",
	NOT_FOREVER = "Pagle: this isn't World of Warcraft: Forever, so Pagle stays off.",
	-- Error reports (CORE-R23): owner, event, the error.
	EVENT_REGISTER_FAILED = "Pagle: %s couldn't register the event %s: %s",
	EVENT_HANDLER_FAILED = "Pagle: %s's handler for the event %s failed: %s",
	-- An inert Module (CORE-R13): its def.title.
	MODULE_NEEDS_NEWER_PAGLE = "Pagle: Pagle %s needs a newer Pagle.",

	-- CORE-R42: a Module's AddSetting after ModulesChanged, reported and dropped; the Module's def.name.
	SETTING_TOO_LATE = "Pagle: %s's AddSetting came after ModulesChanged, so the row is dropped",

	-- Settings (CORE-R40–R44, settings.md SET-R10, SET-R11). The category, then its topic pages by topic.
	SETTINGS_CATEGORY = "Pagle",
	SETTINGS_PAGES = {
		fishing = "Fishing",
		announcements = "Announcements",
		trackers = "Trackers",
	},
	SETTINGS_NO_MODULE = "Recording your Catches. Enable a Module to see them.",
	SETTINGS_MODULES = "Modules",
	SETTINGS_MODULES_NOTE = "Turn Modules on or off in the AddOns list.",
	-- The root's Saving section (SET-R10 row 5): its header, the reminder's label, and its tooltip with LOG-R86's step.
	SETTINGS_SAVING = "Saving",
	SETTINGS_RELOAD_REMINDER = "Remind me to /reload when Casts are unsaved",
	SETTINGS_RELOAD_REMINDER_TOOLTIP = "A chat line every %d Casts not yet saved. WoW saves only on /reload or logout, so a crash loses them.",
	-- The Announcements page's Core rows (SET-R30): labels and tooltips, and Per's value in minutes.
	SETTINGS_COZY = "Cozy mode",
	SETTINGS_COZY_TOOLTIP = "Nothing pops up or plays. Every moment waits in the Session summary. A Legend's splash still shows, silently.",
	SETTINGS_BUDGET = "Interruption budget",
	SETTINGS_BUDGET_TOOLTIP = "When toasts come close together, the smaller ones step down to a quiet Nod. Records always keep their ruler. Greyed out in Cozy mode, which holds everything anyway.",
	SETTINGS_BUDGET_COUNT = "Interruptions",
	SETTINGS_BUDGET_WINDOW = "Per",
	SETTINGS_MINUTES = "%d min",
	-- LOG-R86: the unsaved-Casts reminder, with the number of Casts recorded since load.
	RELOAD_REMINDER = "Pagle: %d Casts not yet saved. /reload to keep them safe.",
	-- CORE-R33: Settings opened while restricted.
	SETTINGS_AFTER_COMBAT = "Pagle: settings open after combat.",
	-- The status list (CORE-R41): each roster Module's name, by def.name, and each state.
	MODULE_NAMES = {
		Ledger = "Ledger",
		Hunts = "Hunts",
		Stats = "Stats",
		TackleBoard = "Tackle Board",
		QoL = "QoL",
	},
	MODULE_STATES = {
		on = "On",
		needsNewerPagle = "Needs a newer Pagle",
		failedToStart = "Failed to start",
		off = "Off",
		notInstalled = "Not installed",
	},
	-- A status button for a Module's first view (CORE-R44): its label.
	OPEN_VIEW = "Open %s",

	-- The compartment menu's last entry (CORE-R50).
	MENU_SETTINGS = "Settings",
	-- Its Curio Shop entry (CORE-R50): the balance as BreakUpLargeNumbers writes it, then a coin icon.
	MENU_CURIO_SHOP = "Curio Shop  %s |TInterface\\MoneyFrame\\UI-GoldIcon:0|t",

	-- /pagle help (CORE-R60, CORE-R61): the header, then a line per command (its name, its help). Core lists the
	-- reserved commands that work; shop and report join with their surfaces (M4, M3).
	SLASH_HELP_HEADER = "Pagle commands:",
	SLASH_HELP_LINE = "/pagle %s: %s",
	-- CORE-R62: a Module's /pagle entry skipped, reported. Each takes the Module's def.name and the entry's name, then
	-- the reserved name, or the def.name of the Module that already uses it.
	SLASH_SKIPPED_NO_NAME = "Pagle: %s's /pagle entry %s has no one-word name; it is skipped",
	SLASH_SKIPPED_NO_FN = "Pagle: %s's /pagle %s has no fn; it is skipped",
	SLASH_SKIPPED_RESERVED = "Pagle: %s's /pagle %s is skipped: Pagle reserves %s",
	SLASH_SKIPPED_TAKEN = "Pagle: %s's /pagle %s is skipped: %s already uses it",
	SLASH_CORE_HELP = {
		{ name = "settings", help = "open Pagle's settings (also /pagle on its own)" },
		{ name = "help", help = "list these commands" },
	},
}
