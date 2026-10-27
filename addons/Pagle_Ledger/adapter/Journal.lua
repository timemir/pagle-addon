if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Fish Journal's book on the client (LED-R120–R123, LED-R125; ledger.md › UI): Core's book shell
-- (`Pagle.NewBook`, core/book.md, ADR 0016) drawing what logic/Journal.lua's router says the pages show with
-- adapter/JournalWidgets.lua's widgets. The shell owns the window, its fades and sounds, the binding, the pages, the
-- crumbs, the back link, the brass plate, the wax close and the "?", the page turn and the crossfade; the Journal keeps
-- its pages, its search slip (a leather anchor), the Legend's plate over the spread, and which way it moves between two
-- places (a turn, a crossfade when a fish is picked, or in place). It makes no secure frames (LED-R121).

local L = ns.L
local INK = ns.JOURNAL_INK
local rgb = ns.JournalRGB

-- The book's measures (the kit's Ledger.lua): 920 × 600, the shell's leather at the sides, the strip and the foot.
local WIDTH, HEIGHT = 920, 600
local SIDE, STRIP = 18, 38
-- A page body's padding on its paper (the kit's 30 in, 24 down), and the room the left page leaves for the back link
-- under its body.
local PAD = { x = 30, top = 24, bottom = 24 }
local BACK_ROOM = 22
-- A page body's size: half the room between the leather's sides, and from the strip to the foot, inside its padding.
local PAGE_W = (WIDTH - 2 * SIDE) / 2
local BODY_W = PAGE_W - 2 * PAD.x
local BODY_H = HEIGHT - STRIP - 16 - PAD.top - PAD.bottom
-- The search slip (the kit's 252 × 23), at the strip's right and centred in it between the band's inner edge (7 units
-- in) and the pages; the crumbs stop short of it.
local SEARCH_W, SEARCH_H = 252, 23
local STRIP_MIDDLE = (7 + STRIP) / 2

-- Each spread is a page of the book (BOOK-R20), the page of every spread registered, now or later: its place keeps
-- the spread's args whole. The order plays no part: the Journal says how each move goes (Journal:How).
---@type PagleBookPageDef
local SPREAD_PAGE = { keeps = { "args" } }
---@type table<string, PagleBookPageDef>
local PAGES = setmetatable({ [ns.JOURNAL_HOME] = SPREAD_PAGE }, {
	__index = function(_, id)
		return ns.journalSpreads[id] and SPREAD_PAGE or nil
	end,
})

--- The Journal's place `place` as the book's: its spread as the page, its args whole.
---@param place LedgerJournalPlace
---@return PagleBookPlace
local function toBook(place)
	return { page = place.id, args = place.args }
end

--- The book's place `place` as the Journal's.
---@param place PagleBookPlace
---@return LedgerJournalPlace
local function fromBook(place)
	return { id = place.page, args = place.args }
end

-- A key equal for two book places exactly when they are the same place.
---@param place PagleBookPlace
---@return string
local function keyOf(place)
	local names = {}
	for key in pairs(place) do
		names[#names + 1] = key
	end
	table.sort(names)
	local parts = {}
	for i, name in ipairs(names) do
		parts[i] = name .. "=" .. tostring(place[name])
	end
	return table.concat(parts, " ")
end

---@class LedgerJournalSearchView: EditBox

--- The "being written up" pages (LED-R122), on the book's notice layers (BOOK-R25).
---@class LedgerJournalUpdatingView
---@field quill LedgerSpriteTexture
---@field words FontString
---@field fleuron Texture   -- the right page's
---@field swaying boolean   -- the quill sways now; it stops when the layer hides

--- The Fish Journal: its book (Core's shell), its router, and what its pages and brass plate show as last drawn.
---@class LedgerJournal
---@field book PagleBook               -- Core's shell (BOOK-R1); its frame from the first opening
---@field router LedgerJournalRouter   -- the spreads' pages, at the book's place as last drawn
---@field frame PagleBookFrame?        -- the book's frame, once first opened
---@field pages LedgerJournalPages?    -- what the pages show as last drawn
---@field shown { left: LedgerJournalPage?, right: LedgerJournalPage? } -- the page bodies shown now
---@field search EditBox?              -- the search slip's box (LED-R148), from the first opening
---@field searchHint FontString?
---@field searchDrop LedgerJournalSearchDrop? -- its results (adapter/JournalSearch.lua)
---@field legendPlate LedgerLegendPlate? -- a Legend's plate over the spread (LED-R147)
---@field plate string?                -- the brass plate's words as last read; nil until first read (LED-R149)
---@field prestigeCard LedgerPrestigeCard? -- the Prestige confirm, made at its first asking (adapter/Prestige.lua)
---@field redrawQueued boolean
---@field bodies table<Frame, LedgerJournalPage> -- the page body drawn on each of the shell's content frames
---@field drawnSubjects { left: string?, right: string? } -- each side's subject as last drawn (LED-R129)
---@field drawnDepth integer?  -- the crumbs' depth as last drawn
---@field drawnPlate boolean?  -- whether the last drawing was a Legend's plate
---@field turnDirection ("fwd"|"back")? -- the next drawing turns the page this way (a Prestige)
---@field cacheKey string?     -- the place `pages` was read for in this drawing
---@field context LedgerJournalContext? -- what `pages` was read from
---@field updatingView LedgerJournalUpdatingView? -- the "being written up" pages, from the first update shown (LED-R122)
local Journal = {}
Journal.__index = Journal

--- Core's goods calls the Journal's pages make: the Angler page's Bindings (LED-R146) and the Collection (LED-R166, LED-R169,
--- LED-R170). The Collection's `Pagle.GetBalance` is read when a page asks, never kept.
---@return LedgerJournalGoods
function ns.JournalGoods()
	return {
		isOwned = Pagle.IsOwned,
		getEquipped = Pagle.GetEquipped,
		setEquipped = Pagle.SetEquipped,
		openShop = Pagle.OpenShop,
		slotGoods = Pagle.GetSlotGoods,
		getGood = Pagle.GetGood,
		bindingLook = Pagle.GetBindingLook,
		slots = Pagle.GetSlots,
		earnedProgress = Pagle.GetEarnedProgress,
		putAway = Pagle.GetPutAwayGoods,
		balance = function()
			return Pagle.GetBalance().balance
		end,
	}
end

--- What the spreads, and the search box, read now (LED-R122, LED-R123, LED-R148): nothing of the state while the
--- projection is updating.
---@return LedgerJournalContext
function Journal:Context() -- luacheck: no self
	local state = ns.StateNow()
	if not state then
		return { updating = true, now = GetServerTime(), formatNumber = BreakUpLargeNumbers, text = ns.journalText }
	end
	return {
		updating = false,
		state = state,
		celebrated = ns.CelebratedSet(ns.db.global),
		activeTitle = ns.db.profile.activeTitle,
		now = GetServerTime(),
		formatNumber = BreakUpLargeNumbers,
		text = ns.journalText,
		world = ns.world,
		getItem = Pagle.GetItem,
		getArea = Pagle.GetArea,
		angler = Pagle.GetAngler(),
		openFieldReport = Pagle.OpenFieldReport,
		sizeText = ns.ClientSizeText,
		-- The Angler page's M4 parts (LED-R146): the crest, Prestige, the title pick and the bindings.
		crest = ns.CrestIcon(),
		canPrestige = ns.CanPrestige(),
		askPrestige = ns.AskPrestige,
		pickTitle = ns.PickActiveTitle,
		goods = ns.JournalGoods(),
		collection = ns.db.global.collection or { seen = {}, looked = {} },
		-- The varieties (VAR-R23, VAR-R24): a Species' ten, the rarities and its fish crest.
		getVarieties = Pagle.GetVarieties,
		rarities = Pagle.VARIETY_RARITIES,
		fishCrest = ns.FishCrest,
		-- "Where your XP came from" and the XP bar's tooltip (LED-R150, LED-R145): Core's totals now, and each source's
		-- at the latest Prestige
		activityXP = Pagle.GetActivityXP(),
		prestigeSources = ns.db.global.prestigeSources,
		-- Home's Following line and the Following spread read the Followed Anglers as they draw (LED-R163)
		followedAnglers = Pagle.GetFollowedAnglers,
	}
end

--- What the pages show at book place `place` (LED-R122, LED-R125), read once in a drawing however many of its parts
--- ask (the pages, the crumbs, the back link, the search slip), and kept as `journal.pages`.
---@param place PagleBookPlace
---@return LedgerJournalPages
function Journal:PagesAt(place)
	local key = keyOf(place)
	if self.cacheKey == key and self.pages then
		return self.pages
	end
	local at = fromBook(place)
	self.router:Open(at.id, at.args)
	local context = self:Context()
	-- every owned look and earned title not seen yet is noted, before any spread reads which are new (LED-R171)
	if not context.updating then
		ns.NoteCollection(context)
		context.collection = ns.db.global.collection
	end
	self.context = context
	self.pages = self.router:Pages(context)
	self.cacheKey = key
	return self.pages
end

-- Whether `pages` are a Legend's plate over the spread (LED-R147).
---@param pages LedgerJournalPages
---@return LedgerBlock?
local function plateOf(pages)
	local first = not pages.updating and pages.left[1]
	return first and first.kind == "plate" and first or nil
end

--- How the open book moves from `from` to `to` (BOOK-R30), the Journal's own choice for every move it isn't told
--- (its links, crumbs, back link and search): it turns the page to another spread, or to another subject on the
--- left page but Home's (forward when the crumbs go deeper), crossfades the right page when only its subject
--- changes (a fish picked, with its sound), and draws in place otherwise, and into or out of a Legend's plate.
---@param from PagleBookPlace?
---@param to PagleBookPlace
---@return PagleBookOpenHow?
function Journal:How(from, to)
	if not from or not self:IsShown() or not self.drawnSubjects.left or not ns.StateNow() then
		return nil
	end
	local pages = self:PagesAt(to)
	if self.drawnPlate or plateOf(pages) then
		return { motion = "still" }
	end
	local drawn, subjects = self.drawnSubjects, pages.subjects or {}
	local leftChanged, rightChanged = subjects.left ~= drawn.left, subjects.right ~= drawn.right
	if to.page ~= from.page or (leftChanged and to.page ~= ns.JOURNAL_HOME) then
		return { motion = "turn", forward = #(pages.crumbs or {}) >= (self.drawnDepth or 0) }
	end
	if rightChanged then
		ns.JournalSound("pick") -- a fish picked sounds whether or not things move
		return { motion = "fade" }
	end
	return { motion = "still" }
end

-- The page body on the shell's content frame `content` of side `side`, made at its first drawing: as wide as the body,
-- and on the left page short of the back link. It scrolls itself, under its ink scrollbar.
---@param journal LedgerJournal
---@param content Frame
---@param side "left"|"right"
---@return LedgerJournalPage
local function bodyOn(journal, content, side)
	local body = journal.bodies[content]
	if not body then
		body = ns.NewJournalPage(content, BODY_W, BODY_H - (side == "left" and BACK_ROOM or 0))
		body:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
		journal.bodies[content] = body
	end
	return body
end

-- What draws side `side` of every page (BOOK-R21): the spread's blocks on that side's body, keeping its scroll while
-- its subject stays (LED-R129). Under a Legend's plate the page stands as it was.
---@param journal LedgerJournal
---@param side "left"|"right"
---@return fun(content: Frame, place: PagleBookPlace): number?
local function sideRenderer(journal, side)
	return function(content, place)
		local pages = journal:PagesAt(place)
		local body = bodyOn(journal, content, side)
		local previous = journal.shown[side]
		journal.shown[side] = body
		if plateOf(pages) then
			return nil
		end
		local subject = pages.subjects and pages.subjects[side]
		local kept = journal.drawnSubjects[side] == subject
		ns.DrawJournalPage(body, pages[side], function(target)
			journal:OpenPlace(target)
		end, not kept or body.subject ~= subject)
		-- the same subject drawn on the other leaf (a crossfade) takes up the scroll it had
		if kept and previous and previous ~= body then
			ns.ScrollJournalPage(body, previous.scroll:GetVerticalScroll())
		end
		body.subject = subject
		journal.drawnSubjects[side] = subject
		return nil
	end
end

-- The search slip on its leather anchor (LED-R148): a parchment field in a leather trim, its magnifier, and the
-- placeholder in italic until something is typed; its drop-down on the book. Made at its first drawing.
---@param journal LedgerJournal
---@param anchor Frame
local function buildSearch(journal, anchor)
	local search = CreateFrame("EditBox", nil, anchor) --[[@as EditBox]]
	search:SetAllPoints()
	search:SetAutoFocus(false)
	search:SetFontObject(ns.JournalFont("print", 14))
	search:SetTextColor(rgb(INK.body))
	search:SetTextInsets(26, 8, 0, 0)
	local trim = ns.JournalTint(search, INK.trim, 1, "BACKGROUND", 0)
	trim:SetAllPoints()
	local field = ns.JournalTint(search, INK.field, 1, "BACKGROUND", 1)
	field:SetPoint("TOPLEFT", 1, -1)
	field:SetPoint("BOTTOMRIGHT", -1, 1)
	local glass = ns.JournalSprite(search, "Parts", "glass", "ARTWORK")
	glass:SetPoint("LEFT", search, "LEFT", 9 - glass.box[1], 0)
	journal.searchHint =
		ns.JournalLabel(search, "italic", 14, INK.noteLight, L.JOURNAL_SEARCH_HINT, { layer = "ARTWORK" })
	journal.searchHint:SetPoint("LEFT", 26, 0)
	search:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	search:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	journal.search = search
	journal.searchDrop = ns.AttachJournalSearch(journal, search, journal.book.frame --[[@as Frame]])
end

-- The Legend's plate (LED-R147) on a frame over both papers, made at the first drawing.
---@param journal LedgerJournal
---@return LedgerLegendPlate
local function legendPlateOf(journal)
	if not journal.legendPlate then
		local frame = journal.book.frame --[[@as PagleBookFrame]]
		local over = CreateFrame("Frame", nil, frame)
		over:SetPoint("TOPLEFT", frame.papers.left, "TOPLEFT")
		over:SetPoint("BOTTOMRIGHT", frame.papers.right, "BOTTOMRIGHT")
		over:SetFrameLevel(frame:GetFrameLevel() + 1)
		journal.legendPlate = ns.BuildLegendPlate(over)
	end
	return journal.legendPlate
end

-- The "being written up" pages (LED-R122): the quill over the left page with the line under it and the fleuron rule,
-- a fleuron alone on the right (the kit's Home.lua: updating), on the notice layers over each paper (BOOK-R25).
---@param sides table<PagleBookSide, Frame>
---@return LedgerJournalUpdatingView
local function buildUpdating(sides)
	local left = sides.left
	local quill = ns.JournalSprite(left, "Parts", "quill", "ARTWORK")
	ns.JournalBoxAt(quill, left, 189, 192.2)
	local words = ns.JournalLabel(left, "print", 18, INK.body, nil, {
		justify = "CENTER",
		wrap = true,
		width = 300,
		spacing = 6,
	})
	words:SetPoint("TOP", left, "TOPLEFT", PAGE_W / 2, -273)
	ns.JournalRule(left, 146, 333.8, 150)
	local fleuron = ns.JournalPiece(sides.right, "Book", "fleuron", "ARTWORK")
	fleuron:SetSize(22, 22)
	fleuron:SetAlpha(0.5)
	fleuron:SetPoint("TOPLEFT", sides.right, "TOPLEFT", 210, -259)
	---@type LedgerJournalUpdatingView
	local view = { quill = quill, words = words, fleuron = fleuron, swaying = false }
	-- the update over (or the book closed), the quill rests
	left:HookScript("OnHide", function()
		Pagle.StopMotion(quill)
		view.swaying = false
	end)
	return view
end

-- The quill writes while the Ledger is being written up: it sways about its nib, 4° each way (0.8 s, ease-in-out,
-- alternating, for as long as it shows); with Animations off it rests at its first lean.
---@param view LedgerJournalUpdatingView
local function swayQuill(view)
	if view.swaying then
		return
	end
	view.swaying = true
	local quill = view.quill
	Pagle.StopMotion(quill)
	Pagle.Animate(quill, {
		{
			dur = 0.8,
			ease = Pagle.EASE.inOut,
			iter = "infinite",
			dir = "alternate",
			keys = { { 0, { -4 } }, { 1, { 4 } } },
			apply = function(v)
				quill:SetRotation(math.rad(v[1]))
			end,
		},
	})
end

-- Last at each drawing (BOOK-R21): the brass plate's words, and a Legend's plate opened over the spread or closed.
---@param journal LedgerJournal
---@param place PagleBookPlace
---@param notice string?
local function afterDraw(journal, place, notice)
	local pages = journal:PagesAt(place)
	journal.cacheKey = nil
	-- The brass plate always shows (LED-R149): LED-R122 hides only the pages' contents, so while the projection updates
	-- it keeps the words last read. Only an update before anything was read (the login rebuild) leaves it unwritten.
	if not notice and not pages.updating then
		journal.plate = ns.BrassPlate(journal:Context() --[[@as LedgerSpreadContext]])
	end
	if journal.plate then
		journal.book:SetPlate(journal.plate)
	end
	local plate = legendPlateOf(journal)
	local block = not notice and plateOf(pages)
	if block then
		ns.FillLegendPlate(plate, block, function(target)
			journal:OpenPlace(target)
		end)
		if not journal.drawnPlate then
			ns.OpenLegendPlate(plate)
			-- it covers both pages: under it, each starts again at the top (LED-R129)
			for _, body in pairs(journal.shown) do
				body.scroll:SetVerticalScroll(0)
			end
		end
		journal.drawnPlate = true
	elseif journal.drawnPlate and not notice then
		journal.drawnPlate = false
		ns.CloseLegendPlate(plate)
	else
		-- an update hides it; it opens again when the update finishes
		journal.drawnPlate = false
		plate:Hide()
	end
	if not pages.updating then
		journal.drawnDepth = #(pages.crumbs or {})
	end
	-- drawing a shelf's spread has the Angler look at every owned look on it (LED-R171)
	if not notice and not pages.updating and place.page == ns.JOURNAL_SHELF then
		ns.NoteShelfLookedNow(journal.context --[[@as LedgerSpreadContext]], place.args and place.args.shelf)
	end
end

--- The Journal, on Home until it is first left (LED-R120): a login or `/reload` starts it afresh. Its book is made at
--- once and builds its frame at the first opening (BOOK-R1); it is movable, and saves where it is left (BOOK-R5).
---@type LedgerJournal
ns.journal = setmetatable({
	router = ns.NewJournalRouter(ns.journalSpreads),
	redrawQueued = false,
	shown = {},
	bodies = setmetatable({}, { __mode = "k" }),
	drawnSubjects = {},
}, Journal)

do
	local journal = ns.journal
	journal.book = Pagle.NewBook({
		id = "ledger.journal",
		-- Esc closes it through UISpecialFrames (LED-R120)
		name = "PagleLedgerJournal",
		width = WIDTH,
		height = HEIGHT,
		pages = PAGES,
		home = { page = ns.JOURNAL_HOME },
		pad = PAD,
		stripRoom = SEARCH_W + SIDE + 12,
		-- the crumbs (LED-R125): Home first, each opening its level but the last; none while updating (LED-R122)
		trail = function(place)
			local crumbs = {}
			for i, crumb in ipairs(journal:PagesAt(place).crumbs or {}) do
				crumbs[i] = { text = crumb.label, target = crumb.place and toBook(crumb.place) or nil }
			end
			if crumbs[#crumbs] then
				crumbs[#crumbs].target = nil
			end
			return crumbs
		end,
		-- "« back" on the left page, one crumb up (LED-R125)
		back = {
			text = L.JOURNAL_BACK,
			target = function(place)
				local back = journal:PagesAt(place).back
				return back and toBook(back) or nil
			end,
		},
		-- the brass plate over the leather's lower left corner (LED-R149)
		plate = { x = -12, y = HEIGHT - 18 },
		-- the "?" beside the wax close, while the Journal's First look is registered (ONB-R59)
		help = {
			tooltip = L.FIRST_LOOK_AGAIN,
			onClick = function()
				ns.ShowJournalLookAgain()
			end,
		},
		anchors = {
			search = {
				point = "TOPRIGHT",
				x = -(SIDE + 6),
				y = -(STRIP_MIDDLE - SEARCH_H / 2),
				width = SEARCH_W,
				height = SEARCH_H,
			},
		},
		-- LED-R122: while the projection is updating, both pages show only its line
		-- (asked first at each drawing, so each drawing reads its pages afresh)
		notice = function()
			journal.cacheKey = nil
			return not ns.StateNow() and L.JOURNAL_UPDATING or nil
		end,
		-- LED-R122's pages are the Journal's own: the quill, its line and the fleurons (BOOK-R25)
		noticeView = function(sides, words)
			journal.updatingView = journal.updatingView or buildUpdating(sides)
			journal.updatingView.words:SetText(words)
			swayQuill(journal.updatingView)
		end,
		how = function(from, to)
			return journal:How(from, to)
		end,
		onDraw = function(place, notice)
			afterDraw(journal, place, notice)
		end,
		-- what opening it does for onboarding, on its pages as drawn (adapter/Onboarding.lua)
		onShow = function()
			ns.JournalOpened(journal)
		end,
		-- closing however it closes hides the Prestige confirm (LED-R33, adapter/Prestige.lua)
		onHide = function()
			ns.HidePrestigeConfirm()
		end,
	})
	-- every spread's sides, those registered later too
	local left, right = sideRenderer(journal, "left"), sideRenderer(journal, "right")
	local function registerPage(id)
		journal.book:RegisterPage(id, "left", left)
		journal.book:RegisterPage(id, "right", right)
	end
	for id in pairs(ns.journalSpreads) do
		registerPage(id)
	end
	local register = ns.RegisterJournalSpread
	---@diagnostic disable-next-line: duplicate-set-field -- wrapping logic/Journal.lua's, so a later spread gets its pages
	function ns.RegisterJournalSpread(id, spread)
		register(id, spread)
		registerPage(id)
	end
	-- the search slip, hidden while updating (LED-R122) and under a Legend's plate
	journal.book:RegisterLeather("search", function(anchor, place, notice)
		if not journal.search then
			buildSearch(journal, anchor)
		end
		local hidden = notice ~= nil or plateOf(journal:PagesAt(place)) ~= nil
		-- the slip asks for a look on the Collection's spreads, a fish or a water elsewhere (LED-R175)
		journal.searchHint:SetText(
			(place.page == ns.JOURNAL_COLLECTION or place.page == ns.JOURNAL_SHELF) and L.COLLECTION_SEARCH_HINT
				or L.JOURNAL_SEARCH_HINT
		)
		local search = journal.search --[[@as EditBox]]
		local drop = journal.searchDrop --[[@as Frame]]
		search:SetShown(not hidden)
		if hidden then
			drop:Hide()
		end
	end)
end

--- Whether the book is open: shown, and not fading out as it closes.
---@return boolean
function Journal:IsShown()
	return self.book:IsShown()
end

--- The place the book is at, as the Journal's (LED-R125).
---@return LedgerJournalPlace
function Journal:Place()
	return fromBook(self.book:Place())
end

--- Opens the book at the spread it was left on (Home at the first opening after a login or `/reload`), or closes it
--- (LED-R120). Every entry point calls it.
function Journal:Toggle()
	if self:IsShown() then
		self:Close()
	else
		self:Show()
	end
end

-- After each opening: the frame as the Journal's, and the "?" shown while its First look is registered (ONB-R59).
---@param journal LedgerJournal
local function opened(journal)
	journal.frame = journal.book.frame
	journal.book:SetHelpShown(ns.JournalHelpShown())
end

--- Opens the book where it was left, drawn as it stands now; opening it ticks the First evening list's item and may
--- show the Ledger's Margin note (ONB-R61, ONB-R52).
function Journal:Show()
	self.book:Open()
	opened(self)
end

--- Closes the book (BOOK-R4).
function Journal:Close()
	self.book:Close()
end

--- Opens spread `id` with `args`, opening the book if it is closed (LED-R125), moving as Journal:How says unless
--- `motion` says how. Does nothing, and returns false, when no spread is registered as `id`.
---@param id string
---@param args table?
---@param motion ("turn"|"fade"|"still")?
---@return boolean opened
function Journal:Open(id, args, motion)
	if not ns.journalSpreads[id] then
		return false
	end
	self.book:Open(toBook({ id = id, args = args }), motion and { motion = motion } or nil)
	opened(self)
	return true
end

--- Opens `place`: its spread with its args (LED-R125). Every link, tile and search result opens through it.
---@param place LedgerJournalPlace
---@param motion ("turn"|"fade"|"still")?
---@return boolean opened
function Journal:OpenPlace(place, motion)
	return self:Open(place.id, place.args, motion)
end

--- The next drawing turns the page in `direction` even on the same spread (a Prestige turns to the new rank).
---@param direction "fwd"|"back"
function Journal:TurnNext(direction)
	self.turnDirection = direction
end

--- Ends every motion of the book at once, as settled (a tour stop's screenshot).
function Journal:Settle()
	self.book:Settle()
end

--- Draws the open book again where it is (LED-R122, LED-R123), keeping each page's scroll while its subject stays
--- (LED-R129) as its widgets play their moments of change; a turn asked for (Journal:TurnNext) turns the page.
function Journal:Draw()
	if not self:IsShown() then
		return
	end
	local direction = self.turnDirection
	self.turnDirection = nil
	if direction then
		self.book:Open(nil, { motion = "turn", forward = direction == "fwd" })
	else
		self.book:Draw()
	end
end

--- A live entry was applied (LED-R123): the open spread redraws on the next frame, once however many arrive in it,
--- keeping its place and selection.
function Journal:LiveApplied()
	self:QueueDraw()
end

--- The open spread redraws on the next frame, once however many ask in this one (LED-R123, LED-R126), keeping its
--- place and selection; nothing while the book is closed.
function Journal:QueueDraw()
	if self.redrawQueued or not self:IsShown() then
		return
	end
	self.redrawQueued = true
	C_Timer.After(0, function()
		self.redrawQueued = false
		self:Draw()
	end)
end

--- Opens or closes the Fish Journal: the view's `open` and `/pagle journal` (LED-R1).
function ns.ToggleJournal()
	ns.journal:Toggle()
end

--- `def` with the Journal's redraws added (LED-R122, LED-R123): after each live entry, on the next frame, and as the
--- projection's catch-up or rebuild finishes, after its own `done`. A copy: `def` itself is left as it was.
---@param def PagleProjectionDef
---@return PagleProjectionDef
function ns.WithJournalRedraws(def)
	local apply, done = def.apply, def.done
	local wrapped = {}
	for key, value in pairs(def) do
		wrapped[key] = value
	end
	wrapped.apply = function(state, record, mode)
		apply(state, record, mode)
		if mode == "live" then
			-- a look this entry earned is seen now (LED-R171)
			ns.NoteCollection()
			ns.journal:LiveApplied()
		end
	end
	wrapped.done = function(state, info)
		if done then
			done(state, info)
		end
		ns.NoteCollection()
		ns.journal:Draw()
	end
	return wrapped
end
