if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Fish Journal's router (LED-R120, LED-R122, LED-R125): the spreads registered by ID, the one open, its
-- breadcrumbs and back link, and what both pages show, as data. Pure logic, everything passed in (CORE-R7);
-- adapter/Journal.lua draws the pages and adapter/JournalWidgets.lua each block.

--- Where the Journal is: a spread's ID and its args (a zone, a fish chosen, a tab).
---@class LedgerJournalPlace
---@field id string
---@field args? table

--- One breadcrumb (LED-R125): its label and the place it opens.
---@class LedgerCrumb
---@field label string
---@field place LedgerJournalPlace

--- What a spread draw, and every crumb and page, reads (LED-R123): the projection's state and the celebrated set
--- while it isn't updating, the server time now and the client's number format.
---@class LedgerJournalContext
---@field updating boolean               -- the projection is catching up or rebuilding (LOG-R74)
---@field state? LedgerState             -- nil while updating
---@field celebrated? LedgerCelebrated   -- nil while updating
---@field activeTitle? string            -- the stored active title (LED-R77), for ns.ActiveTitle; nil while updating
---@field now integer                    -- GetServerTime()
---@field formatNumber fun(n: integer): string -- BreakUpLargeNumbers
---@field text LedgerJournalText         -- names, dates, window lines and lore (LED-R126, LED-R127, LED-R161)
---@field world? LedgerWorld            -- the world index (LED-R10); nil while updating
---@field getItem? fun(itemID: integer): PagleItem? -- Pagle.GetItem; nil while updating
---@field getArea? fun(areaID: integer): PagleArea? -- Pagle.GetArea; nil while updating
---@field angler? Angler                 -- Pagle.GetAngler(), read at each draw (LED-R41); nil while updating
---@field openFieldReport? fun()         -- Pagle.OpenFieldReport (REP-R43); nil while updating
---@field sizeText? fun(size: { length: integer, band: integer }?): string? -- ns.SizeText on Core's bands and unit (LED-R81)

--- One thing drawn on a page, top to bottom, as data; adapter/JournalWidgets.lua draws each kind:
--- - `kicker`, `title`, `text` (`text`, in the serif face; `hand` for the handwriting face, `color` "faded", "red" or
---   "blue" over the ink)
--- - `link` (`text`, opening `place`, or calling `action` instead when it has one)
--- - `leader` (a dotted-leader line: `text` left, `value` right, opening `place` if set)
--- - `seal` (a wax seal reading `text`)
--- - `stamps` (`stamps`: ink stamps, each `{ text, inked }`)
--- - `tiles` (`tiles`: zone tiles, LedgerZoneTile)
--- - `icon` (`icon`, an item ID or texture, drawn `look` "sepia" or "silhouette", `large` on an entry, LED-R140)
--- - `xpBar` (`bar`: the ink XP bar, ns.InkXpBar)
--- - `tabs` (`tabs`: tabs side by side, each `{ text, on, place }`, the chosen one `on`, LED-R130)
--- - `bookplate` (the level `text` in large numerals, its caption `value` with the Prestige `mark` beside it and the
---   active title `signature` in handwriting under it, and a wax seal reading `seal`, LED-R132)
--- - `board` (`ticks`: the Trophy Room's measuring board, LED-R143) and `plinth` (`icon` and `look`, `text` the name,
---   `value` the plaque, LED-R144), drawn by adapter/JournalCollections.lua
--- - `emblem` (`mark`: a prestige rank's emblem and stars, ns.PrestigeMark; nothing drawn without an emblem)
--- - `ladder` (`rungs` side by side, each `{ text, inked, circled }`: Zone Mastery's ranks, LED-R135) and `row` (a list
---   row: a small `icon` drawn `look`, `text` in `color`, its `margin` notes in handwriting, its `stars`, a `value` at
---   the right, `selected` marked, opening `place`; LED-R136, LED-R137), drawn by adapter/JournalZone.lua
--- - `plate` (a Legend's plate filling its page: an `icon` over its `text`, or its `lines`, with `value` at its foot;
---   a click anywhere opens `place`; LED-R147), drawn by adapter/JournalLegends.lua
---@class LedgerBlock
---@field kind "kicker"|"title"|"text"|"link"|"leader"|"seal"|"stamps"|"tiles"|"icon"|"xpBar"|"tabs"|"bookplate"|"board"|"plinth"|"ladder"|"row"|"emblem"|"plate"
---@field text? string
---@field hand? boolean
---@field color? "faded"|"red"|"blue"
---@field place? LedgerJournalPlace
---@field value? string
---@field stamps? { text: string, inked: boolean }[]
---@field tiles? LedgerZoneTile[]
---@field icon? integer|string
---@field look? "sepia"|"silhouette"
---@field large? boolean
---@field bar? LedgerInkXpBar
---@field tabs? { text: string, on: boolean, place: LedgerJournalPlace }[]
---@field seal? string
---@field action? fun()
---@field ticks? LedgerBoardTick[]
---@field mark? LedgerPrestigeMark
---@field signature? string
---@field rungs? { text: string, inked: boolean, circled: boolean }[]
---@field margin? string[]
---@field stars? LedgerStars
---@field selected? boolean
---@field lines? string[]

--- One weight's tick on a measuring board (LED-R143): its pounds, where it sits from the lightest weight (0) to the
--- heaviest (1), and whether it is landed.
---@class LedgerBoardTick
---@field text string
---@field at number
---@field inked boolean

--- A zone tile (LED-R131): the zone's name, up to two lines under it, a thin ink bar, a wax seal and a red note.
---@class LedgerZoneTile
---@field name string
---@field line? string        -- "Local · 63%", "unfished · skill ~45", "uncharted waters"
---@field line2? string
---@field bar? number         -- the ink bar's fill, 0 to 1; nil for none
---@field seal? string        -- the seal's text; nil for none
---@field note? string        -- the red note, e.g. "3 new!"
---@field faded? boolean      -- charted, never fished
---@field place? LedgerJournalPlace

--- A spread's two pages.
---@class LedgerSpreadPages
---@field left LedgerBlock[]
---@field right LedgerBlock[]

--- A spread, registered by ID: its crumbs after Home's (none for Home itself) and its pages, both for its args.
---@class LedgerSpread
---@field crumbs fun(args: table, context: LedgerJournalContext): LedgerCrumb[]
---@field draw fun(args: table, context: LedgerJournalContext): LedgerSpreadPages

--- What the open book shows (LED-R122, LED-R125): both pages, and while not updating, the crumbs (Home first) and
--- the back link's place (nil on Home). The search box shows whenever the crumbs do.
---@class LedgerJournalPages
---@field updating boolean
---@field crumbs? LedgerCrumb[]
---@field back? LedgerJournalPlace
---@field left LedgerBlock[]
---@field right LedgerBlock[]

--- Home's ID: the spread the Journal shows at its first opening after a login or `/reload` (LED-R120). logic/Home.lua
--- registers it.
ns.JOURNAL_HOME = "home"

--- The spreads, by ID. Each spread's ticket registers it with ns.RegisterJournalSpread when its file loads.
---@type table<string, LedgerSpread>
ns.journalSpreads = {}

--- Registers spread `spread` as `id`, replacing any spread registered as `id` before.
---@param id string
---@param spread LedgerSpread
function ns.RegisterJournalSpread(id, spread)
	ns.journalSpreads[id] = spread
end

---@class LedgerJournalRouter
---@field private spreads table<string, LedgerSpread>
---@field private place LedgerJournalPlace
local Router = {}
Router.__index = Router

--- A router over `spreads` (by ID, read when used, so later registrations count), on Home (LED-R120).
---@param spreads table<string, LedgerSpread>
---@return LedgerJournalRouter
function ns.NewJournalRouter(spreads)
	return setmetatable({ spreads = spreads, place = { id = ns.JOURNAL_HOME } }, Router)
end

--- Opens spread `id` with `args`; does nothing and returns false when no spread is registered as `id`, so a link
--- can name a spread that lands later (LED-R125).
---@param id string
---@param args table?
---@return boolean opened
function Router:Open(id, args)
	if not self.spreads[id] then
		return false
	end
	self.place = { id = id, args = args }
	return true
end

--- The open spread's place.
---@return LedgerJournalPlace
function Router:Place()
	return self.place
end

--- What the book shows now (LED-R122, LED-R125): while updating, LED-R122's line on both pages and no crumbs;
--- else the open spread's pages, its crumbs after Home's, and the crumb above the last as the back link's place.
---@param context LedgerJournalContext
---@return LedgerJournalPages
function Router:Pages(context)
	if context.updating then
		return {
			updating = true,
			left = { { kind = "text", text = ns.L.JOURNAL_UPDATING } },
			right = { { kind = "text", text = ns.L.JOURNAL_UPDATING } },
		}
	end
	local spread = self.spreads[self.place.id]
	local args = self.place.args or {}
	local crumbs = { { label = ns.L.JOURNAL_HOME, place = { id = ns.JOURNAL_HOME } } }
	for _, crumb in ipairs(spread.crumbs(args, context)) do
		crumbs[#crumbs + 1] = crumb
	end
	local pages = spread.draw(args, context)
	return {
		updating = false,
		crumbs = crumbs,
		back = crumbs[#crumbs - 1] and crumbs[#crumbs - 1].place,
		left = pages.left,
		right = pages.right,
	}
end
