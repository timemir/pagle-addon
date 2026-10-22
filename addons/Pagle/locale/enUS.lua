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
	-- LOG-R67: the Size band names, Tiddler to Monster, in band order (Pagle.SIZE_BANDS), signed off for 1.0 (#264).
	SIZE_BANDS = { "Tiddler", "Decent", "Hefty", "Whopper", "Monster" },
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
	-- The Trackers page's first row (SET-R40): its label, its button and the tooltip.
	SETTINGS_TRACKER_POSITION = "Tracker position",
	SETTINGS_TRACKER_RESET = "Reset",
	SETTINGS_TRACKER_RESET_TOOLTIP = "Shift-drag any Pagle tracker to move them all. This puts them back under the minimap.",
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
	-- The root's Pagle menu section (SET-R10 row 10): its header, the checkbox's label and its tooltip (CORE-R56).
	SETTINGS_PAGLE_MENU = "Pagle menu",
	SETTINGS_MINIMAP_ICON = "Show the minimap icon",
	SETTINGS_MINIMAP_ICON_TOOLTIP = "A round Pagle button on the minimap's edge that opens the Pagle menu. The menu is also in the AddOns button by the minimap.",
	-- The Announcements page's Core rows (SET-R30): labels and tooltips, and Per's value in minutes.
	SETTINGS_COZY = "Cozy mode",
	SETTINGS_COZY_TOOLTIP = "Nothing pops up or plays. Every moment waits in the Session summary. A Legend's splash still shows, silently.",
	SETTINGS_BUDGET = "Interruption budget",
	SETTINGS_BUDGET_TOOLTIP = "When toasts come close together, the smaller ones step down to a quiet Nod. Records always keep their ruler. Greyed out in Cozy mode, which holds everything anyway.",
	SETTINGS_BUDGET_COUNT = "Interruptions",
	SETTINGS_BUDGET_WINDOW = "Per",
	SETTINGS_EVERY_CATCH = "Show every catch",
	SETTINGS_MOTION = "Animations",
	SETTINGS_MOTION_TOOLTIP = "Toasts slide in and stamp themselves, banners drop their seal, and the Legend's rays turn. Off, each appears as it settles.",
	SETTINGS_EVERY_CATCH_TOOLTIP = "A quiet line for each catch: its name, size band and length. A toast or banner for the same catch shows instead. Greyed out in Cozy mode, which shows nothing.",
	-- Look and Feel (SET-R50, SET-R51): the paragraph, a slot dropdown's note with N, and the Curio Shop section's
	-- header, row label and button caption. Its category headers are SHOP_CATEGORIES.
	SETTINGS_LOOK_PARAGRAPH = "Looks you own. Pick one here or with Use in the Curio Shop; both change the same thing.",
	SETTINGS_SLOT_MORE = "%d more in the Curio Shop",
	SETTINGS_SHOP = "Curio Shop",
	SETTINGS_SHOP_ROW = "Buy more looks with Pagle Coins",
	SETTINGS_SHOP_BUTTON = "Open the Curio Shop",
	-- A number of minutes: the budget's window (SET-R10) and a card's time fished (ANN-R53).
	MINUTES = "%d min",
	-- The Announcement frames (announcements.md › UI): "While you were fighting"'s headlines past its rows (ANN-R36), stamps beyond the 4 shown
	-- (ANN-R11), the Coins beside the drawn coin with their sum (ANN-R23), the record ruler's stamp (ANN-R22) and the
	-- splash's hint.
	ANNOUNCEMENT_MORE = "+%d more",
	ANNOUNCEMENT_STAMPS_MORE = "+%d",
	ANNOUNCEMENT_COINS = "+%s",
	ANNOUNCEMENT_NEW_RECORD = "New record",
	ANNOUNCEMENT_SPLASH_HINT = "Click anywhere to continue",
	-- The toast listing the toast headlines held through combat (ANN-R36).
	ANNOUNCEMENT_WHILE_FIGHTING = "While you were fighting",
	-- The catch Nod (ANN-R13): a Catch's name, its Size band and its length; an item the client hasn't named yet.
	CATCH_NOD = "%s · %s · %s",
	CATCH_NOD_ITEM = "Item %d",
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
	-- A Module's keybinding row (SET-R20): a key slot with no key, and the slot waiting for the next key press.
	SETTINGS_KEY_NOT_BOUND = "Not Bound",
	SETTINGS_KEY_WAITING = "Press a key",
	-- The Field guide's binding field (ONB-R40–R43): its dashed cap and note when Not bound and while Listening, the
	-- word when Bound, and the conflict box. Each action's own words, by binding action: the question (with the old
	-- action's name, in red), the Use button (with the key) and the chat line after Use (the key, the old name).
	GUIDE_BIND_CLICK = "click to bind",
	GUIDE_BIND_DEFAULT = "default: nothing is bound",
	GUIDE_BIND_LISTEN = "press a key…",
	GUIDE_BIND_ESC = "Esc leaves it as it was",
	GUIDE_BIND_BOUND = "Bound",
	GUIDE_BIND_PICK = "Pick another key",
	GUIDE_BIND_KEPT = "the old use is listed, never silently lost",
	GUIDE_BIND_ASK = {
		PAGLE_FISHING_KEY = "already does %s. Use it for fishing instead?",
		PAGLE_SWAP_GEAR = "already does %s. Use it to swap gear instead?",
	},
	GUIDE_BIND_USE = {
		PAGLE_FISHING_KEY = "Use %s for fishing",
		PAGLE_SWAP_GEAR = "Use %s to swap gear",
	},
	GUIDE_BIND_TOLD = {
		PAGLE_FISHING_KEY = "Pagle: %s now casts. It used to do %s; rebind that in Key Bindings if you need it.",
		PAGLE_SWAP_GEAR = "Pagle: %s now swaps your gear. It used to do %s; rebind that in Key Bindings if you need it.",
	},
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
	-- line above the text (REP-R37), the hint beside it and the label before the URL (the field art kit's chart), the
	-- part line between its arrows, Close, the lines shown instead of the text (REP-R41, REP-R42), and the chat line an
	-- entry point prints while restricted (REP-R44).
	FIELD_REPORT_PRIVACY = "This will be posted publicly. It contains no character names.",
	FIELD_REPORT_COPY_HINT = "Ctrl+C to copy",
	FIELD_REPORT_POST_AT = "POST IT AT",
	FIELD_REPORT_PART = "Part %d of %d",
	FIELD_REPORT_CLOSE = "Close",
	FIELD_REPORT_NOTHING = "Nothing to report. Thanks for checking!",
	FIELD_REPORT_UPDATING = "Updating... try again in a moment.",
	FIELD_REPORT_AFTER_COMBAT = "Pagle: the Field report opens after combat.",
	-- The Settings root's HELP_CHART section (SET-R10 row 4): the row's label, the button's caption, with the count
	-- while it is above 0, and the tooltip.
	SETTINGS_FIELD_REPORT_ROW = "Field report",
	SETTINGS_FIELD_REPORT_BUTTON = "Open Field report",
	SETTINGS_FIELD_REPORT_BUTTON_COUNT = "Open Field report (%d)",
	SETTINGS_FIELD_REPORT_TOOLTIP = "Copy what you've caught that Pagle's data doesn't know yet, and paste it into the issue form.",
	-- The Curio Shop (wallet-and-shop.md › UI; its "Curio Shop" trade label is drawn in the case's art): the chat line
	-- its entry points print while restricted (SHOP-R41); the purse (its label, a Module's legend entry with its total,
	-- the segment's tooltip lines); the list (the search slip's hint, the filters, the category
	-- chips, a slot's owned count, the Put away group and its note, a list with no row); a row's and the stage's tags;
	-- the stage (the line under the name, with the slot and its owner, Core's owner name, Buy with the price, the Coins
	-- still needed, an earned good's line, a Module off, the hint with nothing selected, Use).
	SHOP_AFTER_COMBAT = "Pagle: the Curio Shop opens after combat.",
	SHOP_COINS = "Pagle Coins",
	SHOP_LEGEND = "%s %s",
	SHOP_ALL_TIME = "%s Coins all time",
	SHOP_OFF_NOTE = "Off: pays nothing new, keeps what it paid.",
	SHOP_SEARCH = "Find a look…",
	SHOP_FILTERS = { all = "All", owned = "Owned", notOwned = "Not owned", canAfford = "Can afford" },
	SHOP_ALL_CATEGORIES = "All",
	SHOP_CATEGORIES = {
		Announcements = "Announcements",
		Bookplate = "Bookplate",
		["Fish Journal"] = "Fish Journal",
		Hunts = "Hunts",
		Trackers = "Trackers",
	},
	SHOP_OWNED_COUNT = "%d of %d",
	SHOP_PUT_AWAY = "Put away: Module off",
	SHOP_KEEP = "Yours to keep",
	SHOP_NO_MATCH = "No looks match.",
	SHOP_OWNED = "Owned",
	SHOP_IN_USE = "In use",
	SHOP_DEFAULT = "default",
	SHOP_SLOT_LINE = "%s · %s",
	SHOP_CORE = "Pagle",
	SHOP_BUY = "Buy for %s",
	SHOP_MORE_NEEDED = "%s more Coins",
	SHOP_REWARD = "A %s reward, not for sale",
	SHOP_MODULE_OFF = "%s is off",
	SHOP_PICK = "Pick a look to see it here.",
	SHOP_USE = "Use",
	-- Buying (wallet-and-shop.md › UI: Buy): the bill of sale's head (spaced out: the client has no letter spacing),
	-- its question with the good's name, its two lines, its fine print, its checkbox and buttons; and SHOP-R12's held
	-- line under the purse, which never mentions debt or a negative number.
	SHOP_BILL_HEAD = "C U R I O   S H O P",
	SHOP_BUY_CONFIRM = "Buy %s?",
	SHOP_PRICE_LINE = "Price",
	SHOP_LEFT_AFTER = "Pagle Coins left after",
	SHOP_FOR_GOOD = "Looks are yours for good.",
	SHOP_USE_NOW = "Use it now",
	SHOP_BUY_ACCEPT = "Buy",
	SHOP_BUY_CANCEL = "Cancel",
	SHOP_HELD = "Your balance is 0 while Pagle re-counts earlier Coins. New Coins fill that in first.",

	-- The compartment entry's label (CORE-R51): Pagle, with the moments Cozy mode holds for a summary (ANN-R42).
	COMPARTMENT = "Pagle",
	COMPARTMENT_WAITING = "Pagle · %d waiting",
	-- The tooltip of Pagle's menu (CORE-R55), on the minimap icon and the compartment entry: its first line, then
	-- the waiting count (CORE-R51) and the Letter's line (ONB-R13).
	MENU_NAME = "Pagle",
	MENU_TOOLTIP_WAITING = "%d waiting",
	MENU_TOOLTIP_LETTER = "A letter for you",

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
	DEV_USAGE = "Pagle dev: /pagle dev on | off | endsession | preview <kind> | catch <itemID> [areaID] | glyphs"
		.. " | tour [module | list | stop] | probe | onboarding <command>",
	-- /pagle dev onboarding (ONB-R83): its subcommands' usages, " | " between them, in the order added.
	DEV_ONBOARDING_USAGE = "Pagle dev: /pagle dev onboarding %s",
	DEV_ONBOARDING_RESET = "Pagle dev: onboarding is back as a new Angler's, with the Letter waiting; /reload to"
		.. " start from there.",
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
	DEV_SAMPLE_WRITE_UP = "Your Ledger was written up from 2,340 Casts",
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
	-- /pagle dev glyphs (#248, CORE-R9): the probe line, then where the rest of it is.
	DEV_GLYPHS_CHAT = "Pagle dev: the glyph probe in the chat font: %s",
	DEV_GLYPHS_SHOWN = "Pagle dev: the same line in each font Pagle uses is on screen; a box is a character that font"
		.. " lacks. Click it or press Esc to close.",
	-- A probe row: the font (its object's name or its file), what uses it, the probe line.
	DEV_GLYPHS_ROW = "%s (%s): %s",
	-- /pagle dev probe (#261): one check's line ("probe 19: GetCurrentRegion() = 1"), built in logic/Probe.lua from
	-- API names and values, then the last line.
	DEV_PROBE_LINE = "Pagle dev: %s",
	DEV_PROBE_SAVED = "Pagle dev: Probe saved; /reload to write it.",
	-- /pagle dev tour (CORE-R65–R68): how many stops, as DEV_TOUR_START puts it.
	DEV_TOUR_ONE_STOP = "1 stop",
	-- The number of stops.
	DEV_TOUR_STOPS = "%d stops",
	-- How many stops (DEV_TOUR_STOPS), the local time screenshot files are named by.
	DEV_TOUR_START = "Pagle dev: touring %s from %s; a screenshot of each goes to the Screenshots folder.",
	DEV_TOUR_START_MANUAL = "Pagle dev: touring %s from %s; this client can't take screenshots, so press Print Screen"
		.. " as each stop's line appears.",
	-- The stop's number, how many stops, its name ("ledger.journal.home"): one line per stop, as it shows.
	DEV_TOUR_STOP = "Pagle dev: tour %d/%d: %s",
	-- The local time.
	DEV_TOUR_DONE = "Pagle dev: the tour is done at %s.",
	-- The stop on screen's number, how many stops.
	DEV_TOUR_STOPPED = "Pagle dev: the tour stopped at %d/%d.",
	DEV_TOUR_RESTRICTED_STOPPED = "Pagle dev: the tour stopped at %d/%d: combat started.",
	DEV_TOUR_STOPPING = "Pagle dev: the tour stops once this stop hides.",
	DEV_TOUR_NOT_RUNNING = "Pagle dev: no tour is running.",
	DEV_TOUR_RUNNING = "Pagle dev: a tour is running; /pagle dev tour stop ends it.",
	DEV_TOUR_RESTRICTED = "Pagle dev: the tour waits until combat ends; try again then.",
	DEV_TOUR_NO_STOPS = "Pagle dev: no tour stops are registered.",
	-- The name typed, the names with stops, comma-separated.
	DEV_TOUR_NO_STOPS_FOR = "Pagle dev: no tour stops for %s; stops are registered for %s.",
	-- How many stops.
	DEV_TOUR_LIST = "Pagle dev: %d tour stops:",
	DEV_TOUR_LIST_ONE = "Pagle dev: 1 tour stop:",
	-- Core's own stops' labels (CORE-R68). The Announcement form: toast, nod, banner or splash.
	DEV_TOUR_ANNOUNCE = "a sample %s",
	-- The card: session or writeup.
	DEV_TOUR_CARD = "a sample %s card",
	DEV_TOUR_SHOP = "the Curio Shop",
	DEV_TOUR_FIELD_REPORT = "the Field report box",
	DEV_TOUR_GLYPHS = "the glyph probe panel",
	-- The Settings page's name.
	DEV_TOUR_SETTINGS = "Settings: %s",
	-- A stop's name and label.
	DEV_TOUR_LIST_LINE = "  %s: %s",
	SLASH_CORE_HELP = {
		{ name = "settings", help = "open Pagle's settings (also /pagle on its own)" },
		{ name = "shop", help = "open or close the Curio Shop" },
		{ name = "report", help = "open the Field report, to help chart the waters" },
		{ name = "guide", help = "open the Field guide; /pagle guide notes shows the margin notes again" },
		{ name = "help", help = "list these commands" },
	},
	-- /pagle guide notes (ONB-R80): every Margin note and First look shows again, once each.
	GUIDE_NOTES_AGAIN = "Pagle: margin notes will show again, once each.",
	-- The Field guide's book (ONB-R20): its strip's crumbs and its count, "{n} of {m}" with n in brighter gilt.
	GUIDE_CRUMB_PAGLE = "Pagle",
	GUIDE_CRUMB_GUIDE = "A field guide",
	GUIDE_COUNT = "|cfff6e3a8%d|r of %d",
	-- Each step's foot (ONB-R23): the skip link's default label, Next, « back, and Off to the water (ONB-R38). » and «
	-- are Latin-1; the client's fonts have no › (CORE-R9).
	GUIDE_SKIP = "Skip the rest",
	GUIDE_NEXT = "Next »",
	GUIDE_BACK = "« back",
	GUIDE_OFF = "Off to the water",
	-- /pagle guide, the Letter or a Write-up's link while restricted (ONB-R25): the guide opens when it ends.
	GUIDE_AFTER_COMBAT = "Pagle: the Field guide opens after combat.",
	-- A Write-up section's link, from a Module with a guide step (ANN-R64, ONB-R82).
	GUIDE_SHOW_ME_AROUND = "Show me around »",
	-- /pagle dev onboarding step <id> (ONB-R83): a step that isn't registered, and the registered ones' ids.
	DEV_GUIDE_NO_STEP = "Pagle dev: no guide step %s; the steps are %s.",
	-- A tour stop per guide step (ONB-R84): its label for /pagle dev tour list.
	DEV_TOUR_GUIDE_STEP = "the Field guide at its %s step",
	-- Core's own steps (ONB-R30, ONB-R31, ONB-R34, ONB-R38): their ribbons, the Welcome step's foot (ONB-R26), and
	-- their pages, verbatim from the probe (PagleArtGuide's Guide.lua) with › written » (CORE-R9). A *term* between
	-- asterisks is in the red pencil (ns.GuideRedPencil).
	GUIDE_RIBBON_WELCOME = "Welcome",
	GUIDE_RIBBON_BOX = "What’s in the box",
	GUIDE_RIBBON_MOMENTS = "Moments",
	GUIDE_RIBBON_OFF = "Off you go",
	GUIDE_WELCOME_SKIP = "I’ll find my own way",
	GUIDE_WELCOME_NEXT = "Show me around »",
	GUIDE_WELCOME_KICKER = "A letter, left on the dock",
	GUIDE_WELCOME_TITLE = "Dear Angler,",
	GUIDE_WELCOME_RIGHT_KICKER = "Before anything else",
	GUIDE_WELCOME_RIGHT_TITLE = "Three promises",
	GUIDE_BOX_KICKER = "The kit",
	GUIDE_BOX_TITLE = "What came in the box",
	GUIDE_MOMENTS_KICKER = "Moments",
	GUIDE_MOMENTS_TITLE = "When something good happens",
	GUIDE_MOMENTS_RIGHT_KICKER = "Your choice",
	GUIDE_MOMENTS_RIGHT_TITLE = "How chatty should Pagle be?",
	GUIDE_OFF_KICKER = "That’s all for now",
	GUIDE_OFF_TITLE = "The rest you learn by fishing",
	GUIDE_OFF_RIGHT_KICKER = "Your first evening",
	GUIDE_OFF_RIGHT_TITLE = "A short list, if you like",
	GUIDE_OFF_AGAIN = "|cff3e220c/pagle guide|r opens this guide again.",
	-- A count on the pages in words, from 0 (ns.GuideCountWord); past ten, in figures. A list's joins.
	GUIDE_COUNT_WORDS = { "no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten" },
	GUIDE_LIST_COMMA = ", ",
	GUIDE_LIST_AND = " and ",
	-- Welcome (ONB-R30, board 2): the letter in the hand, its signature and foot, then the three promises.
	GUIDE_WELCOME_LETTER = {
		"From now on, every fish you pull out of the water gets written down: where, when, how big, and what it took to land it.",
		"Fish long enough and the water starts telling you things: what bites only at night, which fish you keep missing, how far you’ve come.",
		"Let me show you around. It takes two minutes, and you can change everything later.",
	},
	GUIDE_WELCOME_SIGNED = "Pagle",
	GUIDE_WELCOME_FOOT = "Everything here is also in Options » AddOns » Pagle.",
	GUIDE_WELCOME_PROMISES = {
		{
			"I",
			"I never fish for you.",
			"Pagle watches and writes things down. Every key press does one thing at most, and your hands do the fishing.",
		},
		{
			"II",
			"Nothing expires.",
			"There are no dailies to miss. Goals wait for you, and a day away costs you nothing.",
		},
		{ "III", "Every part is optional." },
	},
	-- The third promise's line: the roster's size in words (ONB-R30).
	GUIDE_WELCOME_PARTS = "Pagle comes in %s parts. Turn any of them off in the AddOns list and it leaves no trace.",
	-- What's in the box (ONB-R31, board 3): the paragraph (Pagle in the title's ink), the menu drawing's header and
	-- its note, the right page's kicker (the registered Modules in words), the Curio Shop's row, and ONB-R103's line.
	GUIDE_BOX_TEXT = "Pagle is a small kit, not one big window. Each part has its own place, and every one of them opens from the |cff3e220cPagle|r entry under the addons button by your minimap.",
	GUIDE_BOX_MENU = "Pagle",
	GUIDE_BOX_MENU_NOTE = "Click a name to open it. */pagle* opens Settings.",
	GUIDE_BOX_PARTS = "%s parts, and a shop",
	GUIDE_BOX_PART = "%s part, and a shop",
	GUIDE_BOX_SHOP = "Curio Shop",
	GUIDE_BOX_SHOP_BLURB = "Pagle Coins come from things you achieve, and buy looks, never power.",
	GUIDE_BOX_NONE = "Turn parts on in the AddOns list.",
	-- Moments (ONB-R34, ONB-R35, board 6): the left page's lines, each sample's name and line, the budget paragraph
	-- (the Lively preset's count and minutes); the presets' cards, Your own mix, and the note under them.
	GUIDE_MOMENTS_TEXT = "Pagle tells you, in one of three sizes. The bigger the moment, the bigger the note.",
	GUIDE_MOMENTS_SAMPLES = {
		nod = { "A Nod", "Every Catch. One line, gone in 3 seconds." },
		toast = { "A toast", "A new fish, a record, Coins earned." },
		banner = { "A banner", "A new Angler Level, and the title that comes with it." },
	},
	GUIDE_MOMENTS_BUDGET = "At most %d pop-ups every %d minutes: past that, small ones step down to a Nod. Everything lands on the Session summary when you stop.",
	-- The samples' catch, in place of /pagle dev preview's "(a /pagle dev preview)" line.
	GUIDE_MOMENTS_SAMPLE_TEXT = "Oily Blackmouth",
	GUIDE_PRESETS = {
		lively = { "Lively", "Every Catch gets its Nod; toasts and banners with sound.", "as it comes" },
		quieter = { "Quieter", "No Nod for ordinary Catches, and fewer pop-ups. The big moments still show." },
		cozy = { "Cozy", "Nothing pops up and nothing plays. It all waits for your Session summary." },
	},
	-- A preset card's pencilled line: its budget's count and minutes; Cozy's.
	GUIDE_PRESET_POPUPS = "%d pop-ups in %d minutes",
	GUIDE_PRESET_COZY_WHAT = "a Legend still shows, silently",
	GUIDE_PRESET_OWN = "Your own mix, kept as it is.",
	GUIDE_MOMENTS_NOTE = "Each one only sets the switches in Settings » Announcements, where you can fine-tune them later.",
	-- Off you go (ONB-R38, board 9): the paragraph, the sample Nod's note, the margin-notes paragraph naming the
	-- windows with First looks (one, or a list), the right page's line, and the First evening list as it will look.
	GUIDE_OFF_TEXT = "The first time something new happens (your first Nod, your first new fish, your first Session summary) I’ll leave a note beside it. Once. After that the margins stay clean.",
	GUIDE_OFF_NOD_NOTE = "That’s a *Nod*: every Catch gets one. It’s gone in three seconds.",
	GUIDE_OFF_LOOKS = "Don’t want notes? Turn off Margin notes in Settings. %s each get a short set the first time you open them.",
	GUIDE_OFF_LOOKS_ONE = "Don’t want notes? Turn off Margin notes in Settings. %s gets a short set the first time you open it.",
	GUIDE_LOOK_WINDOWS = {
		Ledger = "the Fish Journal",
		Hunts = "Hunts",
		Stats = "Stats",
		TackleBoard = "the Tackle Board",
		Core = "the Curio Shop",
	},
	GUIDE_OFF_LIST_TEXT = "It sits under your quests and ticks itself off. Close it whenever you like.",
	-- The First evening list (ONB-R61): its header, "{done} of {total}", each item and the hints the board shows.
	GUIDE_EVENING_TITLE = "First evening",
	GUIDE_EVENING_COUNT = "%d of %d",
	GUIDE_EVENING_ITEMS = {
		cast = "Make a Cast",
		catch = "Land a Catch",
		journal = "Open the Fish Journal",
		hunts = "See what’s biting on Hunts",
		session = "Finish a Session",
		shop = "Peek into the Curio Shop",
	},
	GUIDE_EVENING_HINTS = {
		cast = "press your Fishing key, or double right-click",
		castNoQoL = "right-click the water with Fishing",
		session = "step away 5 minutes for your summary",
	},

	-- Core's own slots (SHOP-R25): their labels. Their goods' names and descriptions are lore (DATA-R101), in
	-- data\Lore.lua as `good.<goodID>.name` and `good.<goodID>.description`.
	SLOT_TOAST_STYLE = "Toast style",
	SLOT_SOUND_SET = "Sound set",
	SLOT_CREST = "Bookplate crest",
	-- A sound set's preview on the Curio Shop's stage (wallet-and-shop.md › UI): a button per sound, and a note. » is
	-- Latin-1: the client's fonts have no ▶ (CORE-R9, #248).
	PREVIEW_TOAST = "» Toast",
	PREVIEW_BANNER = "» Banner",
	PREVIEW_LEGEND = "» Legend",
	PREVIEW_STING_SHARED = "The Legend sting is the same in every set.",
	-- A crest's preview (wallet-and-shop.md › UI): a small bookplate, then where it shows.
	PREVIEW_EX_LIBRIS = "Ex Libris",
	PREVIEW_CREST_NOTE = "On the Fish Journal's bookplate.",
}
