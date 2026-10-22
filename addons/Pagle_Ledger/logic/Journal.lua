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
---@field sizeText? fun(size: { length: integer, band: integer }?): string? -- ns.ClientSizeText (LED-R81)
---@field crest? integer|string          -- the equipped crest's icon (LED-R112, ns.CrestIcon); nil for none
---@field canPrestige? boolean           -- whether LED-R33 allows Prestige now (ns.CanPrestige)
---@field askPrestige? fun()             -- asks before Prestiging (ns.AskPrestige, LED-R33)
---@field pickTitle? fun(key: string?)   -- sets the active title and redraws (ns.PickActiveTitle, LED-R77)
---@field goods? LedgerJournalGoods      -- Core's goods calls, for the Angler page's Bindings (LED-R146)

--- Core's goods calls the Angler page's Bindings make (LED-R146, SHOP-R30–R34, SHOP-R40).
---@class LedgerJournalGoods
---@field isOwned fun(goodID: string): boolean           -- Pagle.IsOwned
---@field getEquipped fun(slot: string): string?         -- Pagle.GetEquipped
---@field setEquipped fun(slot: string, goodID: string): boolean -- Pagle.SetEquipped
---@field openShop fun(goodID: string?)                  -- Pagle.OpenShop

--- What a spread draws from: the Journal's context while the projection isn't updating, when every field is set (the
--- router draws no spread while it updates, LED-R122). The router casts once; spreads and their parts take this.
---@class LedgerSpreadContext: LedgerJournalContext
---@field state LedgerState
---@field celebrated LedgerCelebrated
---@field world LedgerWorld
---@field getItem fun(itemID: integer): PagleItem?
---@field getArea fun(areaID: integer): PagleArea?
---@field angler Angler
---@field openFieldReport fun()
---@field sizeText fun(size: { length: integer, band: integer }?): string?
---@field canPrestige boolean
---@field askPrestige fun()
---@field pickTitle fun(key: string?)
---@field goods LedgerJournalGoods
---@field activityXP? ActivityXP                     -- Pagle.GetActivityXP() (AXP-R6, LED-R150)
---@field prestigeSources? LedgerPrestigeSources     -- PagleLedgerDB.global.prestigeSources (LED-R150)

--- One thing drawn on a page, top to bottom, as data; adapter/JournalWidgets.lua draws each kind:
--- - `kicker`, `title`, `text` (`text`, in the serif face; `hand` for the handwriting face, `color` "faded", "red" or
---   "blue" over the ink)
--- - `link` (`text`, opening `place`, or calling `action` instead when it has one)
--- - `leader` (a dotted-leader line: `text` left, `value` right, opening `place` if set, or calling `action` instead,
---   its value then in a link's red)
--- - `button` (`text` on a button, calling `action`: the Angler page's Prestige, LED-R146)
--- - `seal` (a wax seal reading `text`)
--- - `stamps` (`stamps`: ink stamps, each `{ text, inked }`)
--- - `tiles` (`tiles`: zone tiles, LedgerZoneTile)
--- - `icon` (`icon`, an item ID or texture, drawn `look` "sepia" or "silhouette", `large` on an entry, LED-R140)
--- - `xpBar` (`bar`: the ink XP bar, ns.InkXpBar; `tip`, its tooltip, ns.XPBarTip, LED-R145)
--- - `xpSource` (a line of "Where your XP came from", LED-R150: `text` its source, `value` this climb's XP and
---   `total` all told's in two columns at the right, `off` greyed and struck through; `header` for the columns' heads)
--- - `tabs` (`tabs`: tabs side by side, each `{ text, on, place }`, the chosen one `on`, LED-R130)
--- - `bookplate` (the level `text` in large numerals, its caption `value` with the Prestige `mark` beside it and the
---   active title `signature` in handwriting under it, and a wax seal reading `seal`, LED-R132)
--- - `board` (`ticks`: the Trophy Room's measuring board, LED-R143) and `plinth` (`icon` and `look`, `text` the name,
---   `value` the plaque, LED-R144), drawn by adapter/JournalCollections.lua
--- - `emblem` (`mark`: a prestige rank's emblem and stars, ns.PrestigeMark; nothing drawn without an emblem)
--- - `ladder` (`rungs` side by side, each `{ text, inked, circled }`: Zone Mastery's ranks, LED-R135) and `row` (a list
---   row: a small `icon` drawn `look`, `text` in `color`, its `margin` notes in handwriting, its `stars`, a `value` at
---   the right, `selected` marked, opening `place`; LED-R136, LED-R137), drawn by adapter/JournalZone.lua
--- - `plate` (a Legend's plate across the spread: its `icon`, `text` the name, `lines` its first Catch and its size
---   text, `seal` its title, `value` at its foot; a click anywhere opens `place`; LED-R147), drawn by
---   adapter/JournalLegends.lua over both pages
--- - `crest` (the Angler page's Prestige crest for prestige `rank` holding the Angler's likeness, with the bookplate
---   crest's `icon` pinned on it, LED-R146), drawn by adapter/JournalAngler.lua; `rule` (the fleuron rule); `map`
---   (uncharted waters' blank chart, LED-R138)
---@class LedgerBlock
---@field kind "kicker"|"title"|"text"|"link"|"leader"|"seal"|"stamps"|"tiles"|"icon"|"xpBar"|"xpSource"|"tabs"|"bookplate"|"board"|"plinth"|"ladder"|"row"|"emblem"|"plate"|"button"|"crest"|"rule"|"map"
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
---@field tip? LedgerXpTip       -- the ink XP bar's tooltip
---@field total? string          -- an xpSource line's all told
---@field off? boolean           -- an xpSource line struck through: its Module is off
---@field header? boolean        -- the xpSource columns' heads
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
---@field style? "chart"|"button"|"radio"|"legend"|"pair" -- a link's or icon's look (adapter/JournalWidgets.lua)
---@field on? boolean            -- a radio's pick
---@field inked? boolean         -- a seal pressed (false: the empty ring)
---@field numeral? string        -- a contents line's numeral
---@field binding? string        -- a binding line's closed book
---@field bindingAtlas? "Bindings"|"Bindings2" -- and its atlas (LED-R110)
---@field state? "inUse"|"use"|"level"|"shop" -- a binding line's state
---@field columns? integer       -- tiles across
---@field rank? integer          -- a crest's prestige rank
---@field note? string           -- the bookplate's Prestige words

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

--- A spread, registered by ID: its crumbs after Home's (none for Home itself) and its pages, both for its args, and
--- the args each page is about (LED-R129): a page keeps its scroll while those stay the same. Without `subjects`,
--- every arg is both pages'.
---@class LedgerSpread
---@field crumbs fun(args: table, context: LedgerSpreadContext): LedgerCrumb[]
---@field draw fun(args: table, context: LedgerSpreadContext): LedgerSpreadPages
---@field subjects? { left: string[], right: string[] }

--- What the open book shows (LED-R122, LED-R125): both pages, and while not updating, the crumbs (Home first), the
--- back link's place (nil on Home) and each page's subject (LED-R129). The search box shows whenever the crumbs do.
---@class LedgerJournalPages
---@field updating boolean
---@field crumbs? LedgerCrumb[]
---@field back? LedgerJournalPlace
---@field subjects? { left: string, right: string }
---@field left LedgerBlock[]
---@field right LedgerBlock[]

--- Home's ID: the spread the Journal shows at its first opening after a login or `/reload` (LED-R120). Its args are
--- `{ tab = continent tab }` (LED-R130). logic/Home.lua registers it.
ns.JOURNAL_HOME = "home"
--- The zone spread's ID (LED-R135): its args are `{ zone = areaID, species = id?, hint = true? }`, the Species
--- selected if any and whether its entry's plain hint is open (LED-R136, LED-R141). logic/JournalZone.lua registers it.
ns.JOURNAL_ZONE = "zone"
--- The fish spread's ID (LED-R142): its args are `{ species = id, hint = true? }`. logic/JournalSpecies.lua registers it.
ns.JOURNAL_FISH = "fish"
--- The Trophy Room's ID (LED-R143): its args may name a `family` to open on (LED-R137's "Trophies landed here").
--- logic/JournalCollections.lua registers it.
ns.JOURNAL_TROPHY_ROOM = "trophy"
--- Curios' ID (LED-R144): the Junk Museum, Treasures and the loose pages of Uncharted catches.
--- logic/JournalCollections.lua registers it.
ns.JOURNAL_CURIOS = "curios"
--- The Angler page's ID (LED-R146). logic/JournalAngler.lua registers it.
ns.JOURNAL_ANGLER = "angler"
--- The Legends spread's ID (LED-R147): its args may name a `legend` (item ID) to choose, and `plate` to show its
--- plate. logic/JournalLegends.lua registers it.
ns.JOURNAL_LEGENDS = "legends"

--- Every spread's place, one constructor per spread (LED-R125): each link, crumb, tile and note opens one. A place
--- names its spread by ID, so a link to a spread that hasn't registered does nothing (Router:Open).
ns.JournalPlace = {}

--- Home, on continent tab `tab` when given (LED-R130).
---@param tab integer|string?
---@return LedgerJournalPlace
function ns.JournalPlace.home(tab)
	return { id = ns.JOURNAL_HOME, args = tab ~= nil and { tab = tab } or nil }
end

--- Zone `zone`'s spread, with Species `species` selected when given and its plain hint open with `hint` (LED-R136,
--- LED-R141, LED-R142).
---@param zone integer
---@param species integer?
---@param hint true?
---@return LedgerJournalPlace
function ns.JournalPlace.zone(zone, species, hint)
	return { id = ns.JOURNAL_ZONE, args = { zone = zone, species = species, hint = hint } }
end

--- Species `species`' fish spread, its plain hint open with `hint` (LED-R141, LED-R142): what search and notes open.
---@param species integer
---@param hint true?
---@return LedgerJournalPlace
function ns.JournalPlace.fish(species, hint)
	return { id = ns.JOURNAL_FISH, args = { species = species, hint = hint } }
end

--- The Trophy Room, open on family `family` when given (LED-R143, LED-R137).
---@param family integer?
---@return LedgerJournalPlace
function ns.JournalPlace.trophyRoom(family)
	return { id = ns.JOURNAL_TROPHY_ROOM, args = family and { family = family } or nil }
end

--- Curios (LED-R144).
---@return LedgerJournalPlace
function ns.JournalPlace.curios()
	return { id = ns.JOURNAL_CURIOS }
end

--- The Angler page (LED-R146).
---@return LedgerJournalPlace
function ns.JournalPlace.angler()
	return { id = ns.JOURNAL_ANGLER }
end

--- The Legends spread, with Legend `legend` (item ID) chosen when given and its plate shown with `plate` (LED-R147):
--- what Home's contents, search and the index open.
---@param legend integer?
---@param plate true?
---@return LedgerJournalPlace
function ns.JournalPlace.legends(legend, plate)
	return { id = ns.JOURNAL_LEGENDS, args = legend and { legend = legend, plate = plate } or nil }
end

--- Adds the removed line to a caught item's entry `blocks` (LED-R12): "No longer found in Forever's waters." while
--- the catalogue marks item `itemID` removed, else nothing. Returns `blocks`.
---@param blocks LedgerBlock[]
---@param context LedgerSpreadContext
---@param itemID integer
---@return LedgerBlock[]
function ns.AddJournalRemovedLine(blocks, context, itemID)
	local item = context.getItem(itemID)
	if item and item.removed then
		blocks[#blocks + 1] = { kind = "text", text = ns.L.ENTRY_REMOVED }
	end
	return blocks
end

--- The spreads, by ID. Each spread's ticket registers it with ns.RegisterJournalSpread when its file loads.
---@type table<string, LedgerSpread>
ns.journalSpreads = {}

--- Registers spread `spread` as `id`, replacing any spread registered as `id` before.
---@param id string
---@param spread LedgerSpread
function ns.RegisterJournalSpread(id, spread)
	ns.journalSpreads[id] = spread
end

--- The "Help chart the waters" link, on uncharted waters, a zone's "Also caught here" and Curios' loose pages
--- (LED-R135, LED-R138, LED-R144), drawn as the chart bar (its prompt and the button): it calls
--- Pagle.OpenFieldReport(), which prints Core's line while restricted (LED-R121, REP-R43, REP-R44).
---@param context LedgerSpreadContext
---@return LedgerBlock
function ns.JournalHelpChartLink(context)
	return { kind = "link", style = "chart", text = ns.L.JOURNAL_HELP_CHART, action = context.openFieldReport }
end

-- Every arg's name in `args`, sorted: a spread's subject when it names none (LED-R129).
---@param args table
---@return string[]
local function allArgs(args)
	local names = {}
	for name in pairs(args) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

-- A page's subject (LED-R129) as a string, equal for two places exactly when the page is about the same thing: the
-- spread's ID and the values of `names` in `args`.
---@param id string
---@param args table
---@param names string[]
---@return string
local function subject(id, args, names)
	local parts = { id }
	for _, name in ipairs(names) do
		parts[#parts + 1] = name .. "=" .. tostring(args[name])
	end
	return table.concat(parts, " ")
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
	return setmetatable({ spreads = spreads, place = ns.JournalPlace.home() }, Router)
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
--- else the open spread's pages, its crumbs after Home's, the crumb above the last as the back link's place (Home's
--- for a spread other than Home that adds no crumb; none on Home), and each page's subject (LED-R129).
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
	-- Not updating, every field of the context is set: the spreads read it as a LedgerSpreadContext.
	local ready = context --[[@as LedgerSpreadContext]]
	local spread = self.spreads[self.place.id]
	local args = self.place.args or {}
	local crumbs = { { label = ns.L.JOURNAL_HOME, place = ns.JournalPlace.home() } }
	for _, crumb in ipairs(spread.crumbs(args, ready)) do
		crumbs[#crumbs + 1] = crumb
	end
	local pages = spread.draw(args, ready)
	-- Every spread but Home goes back one crumb up; one that adds no crumb of its own goes back to Home.
	local back = crumbs[#crumbs - 1] and crumbs[#crumbs - 1].place
	if not back and self.place.id ~= ns.JOURNAL_HOME then
		back = crumbs[1].place
	end
	local id = self.place.id
	local names = spread.subjects or { left = allArgs(args), right = allArgs(args) }
	return {
		updating = false,
		crumbs = crumbs,
		back = back,
		left = pages.left,
		right = pages.right,
		subjects = { left = subject(id, args, names.left), right = subject(id, args, names.right) },
	}
end
