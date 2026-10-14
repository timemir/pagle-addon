-- Core's string table (CORE-R8). Every user-facing string goes through ns.L; enUS only in 1.0.

---@class PagleNS
local ns = select(2, ...)

-- The Pagle Coin icon after a Coins amount (ANN-R23, ANN-R53, SHOP-R12): the gold coin texture stands in until
-- Pagle has its own coin art.
local COIN = "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t"
-- The Field report's one name on Core's surfaces: the compartment entry, the box's title and the Settings section
-- (REP-R40, REP-R43, SET-R10).
local HELP_CHART = "Help chart the waters"

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
		look = "Look and Feel",
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
	-- Look and Feel (SET-R50, SET-R51): the paragraph, a slot dropdown's note with N, and the Curio Shop section's
	-- header, row label and button caption. Its category headers are SHOP_CATEGORIES.
	SETTINGS_LOOK_PARAGRAPH = "Looks you own. Pick one here or with Use in the Curio Shop; both change the same thing.",
	SETTINGS_SLOT_MORE = "%d more in the Curio Shop",
	SETTINGS_SHOP = "Curio Shop",
	SETTINGS_SHOP_ROW = "Buy more looks with Pagle Coins",
	SETTINGS_SHOP_BUTTON = "Open the Curio Shop",
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
	-- A toast style's sample on the Curio Shop's preview stage (wallet-and-shop.md › UI, ANN-R80): its headline, its
	-- one stamp, and the button that shows it through the lanes.
	TOAST_SAMPLE_TITLE = "New Species",
	TOAST_SAMPLE_TEXT = "A sample toast",
	TOAST_SAMPLE_STAMP = "New here",
	TOAST_SHOW_ON_SCREEN = "Show on screen",
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
	-- Its Field report entry (CORE-R50, REP-R43), which is also the box's title (REP-R40) and the Settings root's
	-- section header (SET-R10 row 4); the entry adds the count while it is above 0.
	HELP_CHART = HELP_CHART,
	HELP_CHART_COUNT = HELP_CHART .. " (%d)",

	-- The Field report box (field-report.md › The box and its entry points), titled HELP_CHART (REP-R40): the privacy
	-- line above the text (REP-R37), the part line and its buttons, Close, the lines shown instead of the text
	-- (REP-R41, REP-R42), and the chat line an entry point prints while restricted (REP-R44).
	FIELD_REPORT_PRIVACY = "This will be posted publicly. It contains no character names.",
	FIELD_REPORT_PART = "Part %d of %d",
	FIELD_REPORT_PREVIOUS = "Previous",
	FIELD_REPORT_NEXT = "Next",
	FIELD_REPORT_CLOSE = "Close",
	FIELD_REPORT_NOTHING = "Nothing to report. Thanks for checking!",
	FIELD_REPORT_UPDATING = "Updating… try again in a moment.",
	FIELD_REPORT_AFTER_COMBAT = "Pagle: the Field report opens after combat.",
	-- The Settings root's HELP_CHART section (SET-R10 row 4): the row's label, the button's caption, with the count
	-- while it is above 0, and the tooltip.
	SETTINGS_FIELD_REPORT_ROW = "Field report",
	SETTINGS_FIELD_REPORT_BUTTON = "Open Field report",
	SETTINGS_FIELD_REPORT_BUTTON_COUNT = "Open Field report (%d)",
	SETTINGS_FIELD_REPORT_TOOLTIP = "Copy what you've caught that Pagle's data doesn't know yet, and paste it into the issue form.",
	-- The Curio Shop (wallet-and-shop.md › UI): its title, the chat line its entry points print while restricted
	-- (SHOP-R41); the purse (its label, a Module's legend entry with its total, the segment's tooltip lines, who pays
	-- nothing); the list (the search box's hint, the filters, the category chips, a slot's owned count, the Put away
	-- group and its note, a list with no row); a row's and the stage's tags; the stage (the line under the name, with
	-- the slot and its owner, Core's owner name, a price, Buy, the Coins still needed, an earned good's line, a Module
	-- off, the hint with nothing selected, Use).
	SHOP_TITLE = "Curio Shop",
	SHOP_AFTER_COMBAT = "Pagle: the Curio Shop opens after combat.",
	SHOP_COINS = "Pagle Coins",
	SHOP_LEGEND = "%s %s",
	SHOP_ALL_TIME = "%s Coins all time",
	SHOP_OFF_NOTE = "Off: pays nothing new, keeps what it paid.",
	SHOP_PAY_NONE = "Stats and QoL pay none",
	SHOP_SEARCH = "Search looks",
	SHOP_FILTERS = { all = "All", owned = "Owned", notOwned = "Not owned", canAfford = "Can afford" },
	SHOP_ALL_CATEGORIES = "All",
	SHOP_CATEGORIES = {
		Announcements = "Announcements",
		Bookplate = "Bookplate",
		["Fish Journal"] = "Fish Journal",
		Hunts = "Hunts",
		Trackers = "Trackers",
	},
	SHOP_OWNED_COUNT = "%d/%d",
	SHOP_PUT_AWAY = "Put away: Module off",
	SHOP_KEEP = "Yours to keep",
	SHOP_NO_MATCH = "No looks match.",
	SHOP_OWNED = "Owned",
	SHOP_IN_USE = "In use",
	SHOP_DEFAULT = "default",
	SHOP_SLOT_LINE = "%s · %s",
	SHOP_CORE = "Pagle",
	SHOP_PRICE = "%s " .. COIN,
	SHOP_BUY = "Buy for %s " .. COIN,
	SHOP_MORE_NEEDED = "%s more needed",
	SHOP_REWARD = "A %s reward, not for sale",
	SHOP_MODULE_OFF = "%s is off",
	SHOP_PICK = "Pick a look to see it here.",
	SHOP_USE = "Use",
	-- Buying (wallet-and-shop.md › UI: Buy): the popup's question with the good's name, the Coins left after, its
	-- checkbox and buttons; and SHOP-R12's held line under the purse, which never mentions debt or a negative number.
	SHOP_BUY_CONFIRM = "Buy %s?",
	SHOP_LEFT_AFTER = "Pagle Coins left after: %s. Looks are yours for good.",
	SHOP_USE_NOW = "Use it now",
	SHOP_BUY_ACCEPT = "Buy",
	SHOP_BUY_CANCEL = "Cancel",
	SHOP_HELD = "Your balance is 0 while Pagle re-counts earlier Coins. New Coins fill that in first.",

	-- The compartment entry's label (CORE-R51): Pagle, with the moments Cozy mode holds for a summary (ANN-R42).
	COMPARTMENT = "Pagle",
	COMPARTMENT_WAITING = "Pagle · %d waiting",

	-- /pagle help (CORE-R60, CORE-R61): the header, then a line per command (its name, its help). Core lists the
	-- reserved commands.
	SLASH_HELP_HEADER = "Pagle commands:",
	SLASH_HELP_LINE = "/pagle %s: %s",
	-- CORE-R62: a Module's /pagle entry skipped, reported. Each takes the Module's def.name and the entry's name, then
	-- the reserved name, or the def.name of the Module that already uses it.
	SLASH_SKIPPED_NO_NAME = "Pagle: %s's /pagle entry %s has no one-word name; it is skipped",
	SLASH_SKIPPED_NO_FN = "Pagle: %s's /pagle %s has no fn; it is skipped",
	SLASH_SKIPPED_RESERVED = "Pagle: %s's /pagle %s is skipped: Pagle reserves %s",
	SLASH_SKIPPED_TAKEN = "Pagle: %s's /pagle %s is skipped: %s already uses it",
	-- /pagle dev (#247): hidden dev commands, never in the help list.
	DEV_ON = "Pagle dev: dev commands are on.",
	DEV_OFF = "Pagle dev: dev commands are off.",
	DEV_IS_OFF = "Pagle dev: dev commands are off; /pagle dev on turns them on.",
	DEV_USAGE = "Pagle dev: /pagle dev on | off | endsession | preview <kind> | catch <itemID> [areaID]",
	-- The kinds, comma-separated.
	DEV_PREVIEW_KINDS = "Pagle dev: /pagle dev preview <kind>, where kind is one of %s",
	-- The kind.
	DEV_PREVIEWING = "Pagle dev: previewing a %s.",
	DEV_CARD_HELD = "Pagle dev: cards wait until combat ends; try again then.",
	DEV_SAMPLE_TOAST = "New Species",
	DEV_SAMPLE_STAMP = "Size record",
	DEV_SAMPLE_NOD = "New here",
	DEV_SAMPLE_BANNER = "Angler Level 12",
	DEV_SAMPLE_SPLASH = "A Legend",
	DEV_SAMPLE_TEXT = "Oily Blackmouth (a /pagle dev preview)",
	DEV_SAMPLE_LINE = "A sample summary line",
	DEV_SESSION_ENDED = "Pagle dev: the Session ended, as if its gap had passed.",
	DEV_NO_SESSION = "Pagle dev: no Session is open.",
	DEV_CATCH_USAGE = "Pagle dev: /pagle dev catch <itemID> [areaID]",
	DEV_REAL_LOG = "Pagle dev: catch writes to the Catch log, so it runs on a test log only (PagleLog.test); "
		.. "this log is real, and nothing was added.",
	-- The areaID as typed.
	DEV_UNKNOWN_AREA = "Pagle dev: %s isn't an area in Pagle's catalogue.",
	DEV_NO_CHARACTER = "Pagle dev: no character is logged in yet.",
	-- The item ID, the zone areaID and the entry's seq.
	DEV_CAUGHT = "Pagle dev: caught item %d in zone %d (entry %d).",
	SLASH_CORE_HELP = {
		{ name = "settings", help = "open Pagle's settings (also /pagle on its own)" },
		{ name = "shop", help = "open or close the Curio Shop" },
		{ name = "report", help = "open the Field report, to help chart the waters" },
		{ name = "help", help = "list these commands" },
	},

	-- Core's own slots (SHOP-R25): their labels. Their goods' names and descriptions are lore (DATA-R101), in
	-- data\Lore.lua as `good.<goodID>.name` and `good.<goodID>.description`.
	SLOT_TOAST_STYLE = "Toast style",
	SLOT_SOUND_SET = "Sound set",
	SLOT_CREST = "Bookplate crest",
	-- A sound set's preview on the Curio Shop's stage (wallet-and-shop.md › UI): a button per sound, and a note.
	PREVIEW_TOAST = "▶ Toast",
	PREVIEW_BANNER = "▶ Banner",
	PREVIEW_LEGEND = "▶ Legend",
	PREVIEW_STING_SHARED = "The Legend sting is the same in every set.",
	-- A crest's preview (wallet-and-shop.md › UI): a small bookplate, then where it shows.
	PREVIEW_EX_LIBRIS = "Ex Libris",
	PREVIEW_CREST_NOTE = "On the Fish Journal's bookplate.",
}
