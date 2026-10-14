-- Core's string table (CORE-R8). Every user-facing string goes through ns.L; enUS only in 1.0.

---@class PagleNS
local ns = select(2, ...)

-- The Pagle Coin icon after a Coins amount (ANN-R23, ANN-R53, SHOP-R12): the gold coin texture stands in until
-- Pagle has its own coin art.
local COIN = "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t"

---@class PagleStrings
ns.L = {
	-- LOG-R18: PagleLog was in another format, so Core started a new log.
	LOG_FORMAT_CHANGED = "Pagle: dev log format changed; started a new log.",
	NOT_FOREVER = "Pagle: this isn't World of Warcraft: Forever, so Pagle stays off.",
	-- LOG-R67: the Size band names, Tiddler to Monster, in band order (Pagle.SIZE_BANDS). Drafts for the lore pass.
	SIZE_BANDS = { "Tiddler", "Typical", "Hefty", "Whopper", "Monster" },
	-- LOG-R69: a length in each length unit, to 0.1 of it; ANN-R22: a size record's margin that rounds to zero.
	LENGTH = { cm = "%.1f cm", ["in"] = "%.1f in" },
	LENGTH_MARGIN_UNDER = { cm = "+<0.1 cm", ["in"] = "+<0.1 in" },
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
	-- The root's Units section (SET-R10 row 6): its header, the dropdown's label, tooltip and options (LOG-R69).
	SETTINGS_UNITS = "Units",
	SETTINGS_LENGTH_UNIT = "Length unit",
	SETTINGS_LENGTH_UNIT_TOOLTIP = "How Pagle shows the length of your Catches. Records are kept in millimetres, so switching changes only what you see.",
	SETTINGS_LENGTH_UNITS = { cm = "Centimetres", ["in"] = "Inches" },
	-- The Announcements page's Core rows (SET-R30): labels and tooltips, and Per's value in minutes.
	SETTINGS_COZY = "Cozy mode",
	SETTINGS_COZY_TOOLTIP = "Nothing pops up or plays. Every moment waits in the Session summary. A Legend's splash still shows, silently.",
	SETTINGS_BUDGET = "Interruption budget",
	SETTINGS_BUDGET_TOOLTIP = "When toasts come close together, the smaller ones step down to a quiet Nod. Records always keep their ruler. Greyed out in Cozy mode, which holds everything anyway.",
	SETTINGS_BUDGET_COUNT = "Interruptions",
	SETTINGS_BUDGET_WINDOW = "Per",
	-- A number of minutes: the budget's window (SET-R10) and a card's time fished (ANN-R53).
	MINUTES = "%d min",
	-- The Announcement frames (announcements.md › UI): the toast lane's overflow (ANN-R20), stamps beyond the 4 shown
	-- (ANN-R11), the Coins stamp with its sum (ANN-R23), the record ruler's stamp (ANN-R22) and the splash's hint.
	ANNOUNCEMENT_MORE = "+%d more",
	ANNOUNCEMENT_STAMPS_MORE = "+%d",
	ANNOUNCEMENT_COINS = "+%s " .. COIN,
	ANNOUNCEMENT_NEW_RECORD = "New record",
	ANNOUNCEMENT_SPLASH_HINT = "Click anywhere to continue",
	-- The toast listing the toast headlines held through combat (ANN-R36), and each line: a headline's title and text.
	ANNOUNCEMENT_WHILE_FIGHTING = "While you were fighting",
	ANNOUNCEMENT_FIGHTING_LINE = "%s: %s",
	-- The cards (announcements.md › UI): a Session summary's title, "Your last session" for one that ended while away
	-- (ANN-R54), and the Write-up's (ANN-R61); Core's numbers (ANN-R53), time fished in MINUTES or hours and minutes;
	-- the Coins line with its sum (ANN-R53); the close button (closing also takes Esc).
	CARD_SESSION = "Fishing session",
	CARD_LAST_SESSION = "Your last session",
	CARD_WRITE_UP = "Write-up",
	CARD_CASTS = "Casts",
	CARD_CATCHES = "Catches",
	CARD_GOT_AWAY = "Got away",
	CARD_TIME = "Time fished",
	CARD_HOURS = "%d h %02d min",
	CARD_COINS = "Pagle Coins +%s " .. COIN,
	CARD_CLOSE = "Close",
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
	MENU_CURIO_SHOP = "Curio Shop  %s " .. COIN,
	-- Its Field report entry (CORE-R50, REP-R43), with the count while it is above 0.
	MENU_FIELD_REPORT = "Help chart the waters",
	MENU_FIELD_REPORT_COUNT = "Help chart the waters (%d)",

	-- The Field report box (field-report.md › The box and its entry points): its title (REP-R40), the privacy line
	-- above the text (REP-R37), the part line and its buttons, Close, the lines shown instead of the text (REP-R41,
	-- REP-R42), and the chat line an entry point prints while restricted (REP-R44).
	REPORT_TITLE = "Help chart the waters",
	REPORT_PRIVACY = "This will be posted publicly. It contains no character names.",
	REPORT_PART = "Part %d of %d",
	REPORT_PREVIOUS = "Previous",
	REPORT_NEXT = "Next",
	REPORT_CLOSE = "Close",
	REPORT_NOTHING = "Nothing to report. Thanks for checking!",
	REPORT_UPDATING = "Updating… try again in a moment.",
	REPORT_AFTER_COMBAT = "Pagle: the Field report opens after combat.",
	-- The Settings root's Help chart the waters section (SET-R10 row 4): its header, the row's label, the button's
	-- caption, with the count while it is above 0, and the tooltip.
	SETTINGS_FIELD_REPORT = "Help chart the waters",
	SETTINGS_FIELD_REPORT_ROW = "Field report",
	SETTINGS_FIELD_REPORT_BUTTON = "Open Field report",
	SETTINGS_FIELD_REPORT_BUTTON_COUNT = "Open Field report (%d)",
	SETTINGS_FIELD_REPORT_TOOLTIP = "Copy what you've caught that Pagle's data doesn't know yet, and paste it into the issue form.",
	-- The compartment entry's label (CORE-R51): Pagle, with the moments Cozy mode holds for a summary (ANN-R42).
	COMPARTMENT = "Pagle",
	COMPARTMENT_WAITING = "Pagle · %d waiting",

	-- /pagle help (CORE-R60, CORE-R61): the header, then a line per command (its name, its help). Core lists the
	-- reserved commands that work; shop joins with the Curio Shop (M4).
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
		{ name = "report", help = "open the Field report, to help chart the waters" },
		{ name = "help", help = "list these commands" },
	},
}
