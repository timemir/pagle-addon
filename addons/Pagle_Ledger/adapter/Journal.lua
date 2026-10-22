if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Fish Journal's book on the client (LED-R120–R123, LED-R125; ledger.md › UI): the Ledger art kit's book (its
-- shell in adapter/JournalBook.lua) with the gilt breadcrumbs and the search slip on the strip above the pages and the
-- back link on the left page, drawing what logic/Journal.lua's router says the pages show with
-- adapter/JournalWidgets.lua's widgets. It makes no secure frames, so it opens and works while restricted (LED-R121).
-- Between spreads it turns the page, and a fish picked on a zone page crossfades the right page; the book fades as
-- it opens and closes, with its sounds (the kit's Views.lua and MOTION.md). It shrinks to fit a small screen.

local L = ns.L
local INK = ns.JOURNAL_INK
local rgb = ns.JournalRGB
local BOOK = ns.JOURNAL_BOOK

-- The frame's global name: UISpecialFrames takes names, and Esc hides the frames it lists (LED-R120).
local FRAME_NAME = "PagleLedgerJournal"
-- A page body's place on its paper (the kit's 30 in, 24 down) and its size; the left one leaves room for the back
-- link under it.
local BODY_X, BODY_Y = 30, 24
local BODY_W = ns.JOURNAL_PAGE_W - 2 * BODY_X
local BODY_H = { left = ns.JOURNAL_PAGE_H - BODY_Y - 46, right = ns.JOURNAL_PAGE_H - 2 * BODY_Y }
-- The page turn's two halves (MOTION.md: the page lifts toward the spine, then lands from the spine outward), and the
-- right page's crossfade when a fish is picked.
local LIFT, LAND, CROSSFADE = 0.22, 0.28, 0.2
-- How the book fits the screen (Pagle.FitToScreen, core/README.md › Contracts): its whole extent, what hangs outside
-- its frame included (the wax close, the brass plate), centred.
local FIT = { width = BOOK.extentW, height = BOOK.extentH }

---@class LedgerJournalCrumbView: LedgerJournalClickable
---@field label FontString
---@field fleuron Texture?
---@field gilt number[]?       -- the binding's gilt it was drawn in

--- One page's leaf: a clip frame on the paper whose visible strip the page turn narrows, and the page body on it.
---@class LedgerJournalLeaf
---@field clip Frame
---@field content Frame
---@field body LedgerJournalPage

---@class LedgerJournalFold: Frame
---@field shade Texture
---@field cast Texture
---@field edge Texture

---@class LedgerJournalUpdatingView: Frame
---@field quill LedgerSpriteTexture

---@class LedgerJournalFrame: LedgerJournalShell
---@field leaves table<"left"|"right", LedgerJournalLeaf[]> -- each side's two leaves, the one shown and the next
---@field shownLeaf table<"left"|"right", integer>
---@field left LedgerJournalPage   -- the page bodies shown now
---@field right LedgerJournalPage
---@field crumbButtons LedgerJournalCrumbView[]
---@field searchDrop LedgerJournalSearchDrop -- its results (adapter/JournalSearch.lua)
---@field back LedgerJournalCrumbView  -- "« back", under the left page (LED-R125)
---@field updatingView LedgerJournalUpdatingView
---@field legendPlate LedgerLegendPlate
---@field fold LedgerJournalFold
---@field closing boolean?

--- The Fish Journal: its router, its frame once made, and what its pages and brass plate show as last drawn.
---@class LedgerJournal
---@field router LedgerJournalRouter
---@field frame LedgerJournalFrame?
---@field pages LedgerJournalPages?
---@field plate string?                -- the brass plate's words as last read; nil until first read (LED-R149)
---@field binding string?              -- the binding it was last drawn in (LED-R112)
---@field prestigeCard LedgerPrestigeCard? -- the Prestige confirm, made at its first asking (adapter/Prestige.lua)
---@field private redrawQueued boolean
---@field private bindOwner table?    -- the motion driver's owner of a binding change
---@field private drawnSubjects { left: string?, right: string? }? -- each page's subject as last drawn (LED-R129)
---@field private drawnId string?      -- the spread last drawn, and its depth in crumbs
---@field private drawnDepth integer?
---@field private drawnPlate boolean?  -- whether the last drawing was a Legend's plate
---@field private turnDirection ("fwd"|"back")? -- the next drawing turns the page this way (a Prestige)
---@field turnOwner table              -- the motion driver's owner of the page turn
---@field finishTurn fun()?            -- settles the page turn or crossfade under way
---@field private justOpened boolean?  -- the book has just opened: its first drawing neither turns nor fades
local Journal = {}
Journal.__index = Journal

--- The Journal, on Home until it is first left (LED-R120): a login or `/reload` starts it afresh.
ns.journal = setmetatable({
	router = ns.NewJournalRouter(ns.journalSpreads),
	redrawQueued = false,
	turnOwner = {},
}, Journal)

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
		goods = {
			isOwned = Pagle.IsOwned,
			getEquipped = Pagle.GetEquipped,
			setEquipped = Pagle.SetEquipped,
			openShop = Pagle.OpenShop,
		},
		-- The varieties (VAR-R23, VAR-R24): a Species' ten, the rarities and its fish crest.
		getVarieties = Pagle.GetVarieties,
		rarities = Pagle.VARIETY_RARITIES,
		fishCrest = ns.FishCrest,
		-- "Where your XP came from" and the XP bar's tooltip (LED-R150, LED-R145): Core's totals now, and each source's
		-- at the latest Prestige
		activityXP = Pagle.GetActivityXP(),
		prestigeSources = ns.db.global.prestigeSources,
		-- Home's Following line and the Following spread read the Followed Anglers as they draw (LED-R151)
		followedAnglers = Pagle.GetFollowedAnglers,
	}
end

-- One leaf on `paper`: its clip frame and the page body, `height` tall, in it.
---@param paper Frame
---@param height number
---@return LedgerJournalLeaf
local function newLeaf(paper, height)
	local clip = CreateFrame("Frame", nil, paper)
	clip:SetClipsChildren(true)
	clip:SetAllPoints()
	local content = CreateFrame("Frame", nil, clip)
	content:SetAllPoints(paper)
	local body = ns.NewJournalPage(content, BODY_W, height)
	body:SetPoint("TOPLEFT", content, "TOPLEFT", BODY_X, -BODY_Y)
	return { clip = clip, content = content, body = body }
end

-- Shows only the strip from `a` to `b` (fractions of the page's width) of `leaf` on `paper`; hides it when empty.
---@param leaf LedgerJournalLeaf
---@param paper Frame
---@param a number
---@param b number
local function reveal(leaf, paper, a, b)
	local clip = leaf.clip
	if b - a <= 0.002 then
		clip:Hide()
		return
	end
	local w = ns.JOURNAL_PAGE_W
	clip:Show()
	clip:ClearAllPoints()
	clip:SetPoint("TOPLEFT", paper, "TOPLEFT", a * w, 0)
	clip:SetPoint("BOTTOMLEFT", paper, "BOTTOMLEFT", a * w, 0)
	clip:SetWidth((b - a) * w)
end

-- The fold over the pages as a leaf turns: a shade over the turning strip, a cast shadow beside its moving edge and a
-- light line along it.
---@param frame LedgerJournalFrame
---@return LedgerJournalFold
local function buildFold(frame)
	local fold = CreateFrame("Frame", nil, frame.pagesFrame) --[[@as LedgerJournalFold]]
	fold:SetAllPoints()
	fold:SetFrameLevel(frame.pagesFrame:GetFrameLevel() + 40)
	fold.shade = fold:CreateTexture(nil, "OVERLAY", nil, 0)
	fold.shade:SetColorTexture(0.16, 0.08, 0.02, 1)
	fold.cast = fold:CreateTexture(nil, "OVERLAY", nil, 1)
	fold.cast:SetColorTexture(1, 1, 1, 1)
	fold.edge = fold:CreateTexture(nil, "OVERLAY", nil, 2)
	fold.edge:SetColorTexture(1, 0.97, 0.85, 1)
	fold:Hide()
	return fold
end

-- Places the fold: the turning strip from `x0` to `x1` on `paper` (units from its left), its moving edge at `ex`, the
-- cast shadow on the side `side` (-1 left of the edge, 1 right of it), at `shade` and `cast` strength.
---@param fold LedgerJournalFold
---@param paper Frame
---@param x0 number
---@param x1 number
---@param ex number
---@param side number
---@param shade number
---@param cast number
local function placeFold(fold, paper, x0, x1, ex, side, shade, cast)
	fold.shade:ClearAllPoints()
	fold.shade:SetPoint("TOPLEFT", paper, "TOPLEFT", x0, 0)
	fold.shade:SetPoint("BOTTOMLEFT", paper, "BOTTOMLEFT", x0, 0)
	fold.shade:SetWidth(math.max(0.01, x1 - x0))
	fold.shade:SetAlpha(shade)
	local castW = 26
	local castX = side > 0 and ex or ex - castW
	fold.cast:ClearAllPoints()
	fold.cast:SetPoint("TOPLEFT", paper, "TOPLEFT", castX, 0)
	fold.cast:SetPoint("BOTTOMLEFT", paper, "BOTTOMLEFT", castX, 0)
	fold.cast:SetWidth(castW)
	local dark, clear = CreateColor(0.12, 0.06, 0.02, 0.32 * cast), CreateColor(0.12, 0.06, 0.02, 0)
	if side > 0 then
		fold.cast:SetGradient("HORIZONTAL", dark, clear)
	else
		fold.cast:SetGradient("HORIZONTAL", clear, dark)
	end
	local edgeX = ex - (side > 0 and 1.5 or 0)
	fold.edge:ClearAllPoints()
	fold.edge:SetPoint("TOPLEFT", paper, "TOPLEFT", edgeX, 0)
	fold.edge:SetPoint("BOTTOMLEFT", paper, "BOTTOMLEFT", edgeX, 0)
	fold.edge:SetWidth(1.5)
	fold.edge:SetAlpha(0.55 * cast)
end

-- The "being written up" pages (LED-R122): the quill over the left page with the line under it and the fleuron rule,
-- a fleuron alone on the right (the kit's Home.lua: updating).
---@param frame LedgerJournalFrame
---@return LedgerJournalUpdatingView
local function buildUpdating(frame)
	local view = CreateFrame("Frame", nil, frame.pagesFrame) --[[@as LedgerJournalUpdatingView]]
	view:SetAllPoints()
	view:SetFrameLevel(frame.pagesFrame:GetFrameLevel() + 20)
	local left = frame.papers.left
	view.quill = ns.JournalSprite(view, "Parts", "quill", "ARTWORK")
	ns.JournalBoxAt(view.quill, left, 189, 192.2)
	local words = ns.JournalLabel(view, "print", 18, INK.body, L.JOURNAL_UPDATING, {
		justify = "CENTER",
		wrap = true,
		width = 300,
		spacing = 6,
	})
	words:SetPoint("TOP", left, "TOPLEFT", ns.JOURNAL_PAGE_W / 2, -273)
	ns.JournalRule(view, 146, 333.8, 150)
	local fleuron = ns.JournalPiece(view, "Book", "fleuron", "ARTWORK")
	fleuron:SetSize(22, 22)
	fleuron:SetAlpha(0.5)
	fleuron:SetPoint("TOPLEFT", frame.papers.right, "TOPLEFT", 210, -259)
	view:Hide()
	return view
end

-- The quill writes while the Ledger is being written up: it sways about its nib, 4° each way (0.8 s, ease-in-out,
-- alternating, for as long as it shows).
---@param view LedgerJournalUpdatingView
local function swayQuill(view)
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

-- The back link (LED-R125): "« back" in the hand at the left page's foot, turning red under the mouse.
---@param journal LedgerJournal
---@param frame LedgerJournalFrame
---@return LedgerJournalCrumbView
local function buildBack(journal, frame)
	local back = CreateFrame("Button", nil, frame.papers.left) --[[@as LedgerJournalCrumbView]]
	back:SetFrameLevel(frame.papers.left:GetFrameLevel() + 8)
	ns.JournalClickable(back)
	function back.open(place)
		journal:OpenPlace(place)
	end
	back.label = ns.JournalLabel(back, "hand", 19, INK.brown, L.JOURNAL_BACK)
	back.label:SetPoint("LEFT")
	back:SetSize(back.label:GetStringWidth() + 4, 24)
	ns.JournalAt(back, frame.papers.left, BODY_X, ns.JOURNAL_PAGE_H - 38)
	back:SetScript("OnEnter", function(self)
		self.label:SetTextColor(rgb(INK.red))
	end)
	back:SetScript("OnLeave", function(self)
		self.label:SetTextColor(rgb(INK.brown))
	end)
	return back
end

-- Builds the book, hidden: the kit's shell, two leaves on each page, the back link, the "being written up" pages,
-- the Legend plate, the fold and the search box's drop-down. Centred and not movable (ledger.md › UI); Esc hides it
-- through UISpecialFrames.
---@param journal LedgerJournal
---@return LedgerJournalFrame
local function build(journal)
	local frame = CreateFrame("Frame", FRAME_NAME, UIParent) --[[@as LedgerJournalFrame]]
	frame:Hide() -- hidden before its scripts are set: being made isn't closing
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH")
	frame:EnableMouse(true)
	ns.BuildJournalShell(frame)
	frame.leaves, frame.shownLeaf = { left = {}, right = {} }, { left = 1, right = 1 }
	for _, side in ipairs({ "left", "right" }) do
		for i = 1, 2 do
			local leaf = newLeaf(frame.papers[side], BODY_H[side])
			frame.leaves[side][i] = leaf
			if i == 2 then
				leaf.clip:Hide()
			end
		end
	end
	frame.left, frame.right = frame.leaves.left[1].body, frame.leaves.right[1].body
	frame.crumbButtons = {}
	frame.back = buildBack(journal, frame)
	frame.updatingView = buildUpdating(frame)
	frame.legendPlate = ns.BuildLegendPlate(frame.pagesFrame)
	frame.fold = buildFold(frame)
	frame.searchDrop = ns.AttachJournalSearch(journal, frame.search, frame)

	frame.close:SetScript("OnClick", function()
		journal:Close()
	end)
	-- its "?", beside the close, while it has a First look (adapter/Onboarding.lua, ONB-R59)
	ns.AttachJournalLook(frame)
	table.insert(UISpecialFrames, FRAME_NAME)
	-- Opening: the book's sound, and it fades in (0.16 s). Closing however it closes (Esc, the close button, a
	-- toggle) hides the Prestige confirm (LED-R33, adapter/Prestige.lua), with the closing sound unless Close played
	-- it already.
	frame:SetScript("OnShow", function(self)
		ns.JournalSound("bookOpen")
		Pagle.StopMotion(self)
		Pagle.Animate(self, {
			{
				dur = 0.16,
				ease = Pagle.EASE.out,
				keys = { { 0, { 0 } }, { 1, { 1 } } },
				apply = function(v)
					self:SetAlpha(v[1])
				end,
			},
		})
	end)
	frame:SetScript("OnHide", function(self)
		-- Hidden with the whole UI as it fades out, it still ends closed: Core's driver settles the fade, whose end
		-- hides it (Journal:Close).
		if self.closing and self:IsShown() then
			return
		end
		if not self.closing then
			ns.JournalSound("bookClose")
		end
		self.closing = false
		self:SetAlpha(1)
		ns.HidePrestigeConfirm()
	end)
	return frame
end

-- Crumb `i` of the strip, made on first use: its gilt words and, after the first, the fleuron before them.
---@param journal LedgerJournal
---@param i integer
---@return LedgerJournalCrumbView
local function crumbAt(journal, i)
	local frame = journal.frame --[[@as LedgerJournalFrame]]
	local crumb = frame.crumbButtons[i]
	if not crumb then
		crumb = CreateFrame("Button", nil, frame.crumbs) --[[@as LedgerJournalCrumbView]]
		ns.JournalClickable(crumb)
		function crumb.open(place)
			journal:OpenPlace(place)
		end
		if i > 1 then
			crumb.fleuron = ns.JournalPiece(crumb, "Book", "fleuron", "OVERLAY")
			crumb.fleuron:SetSize(16, 16)
			crumb.fleuron:SetPoint("LEFT", 8, 0)
		end
		crumb.label = ns.JournalLabel(crumb, "gilt", 14, INK.gilt, "", { shadow = true })
		crumb.label:SetPoint("LEFT", i > 1 and 32 or 0, 0)
		crumb:SetScript("OnEnter", function(self)
			if self.place then
				self.label:SetTextColor(rgb(INK.giltLight))
			end
		end)
		crumb:SetScript("OnLeave", function(self)
			self.label:SetTextColor(unpack(self.gilt or ns.HexTint(INK.gilt)))
		end)
		frame.crumbButtons[i] = crumb
	end
	return crumb
end

-- Lays the crumbs along the strip in the binding's gilt, the fleurons between them, each opening its level but the
-- last (LED-R125, LED-R110); the last are cut short before the search slip.
---@param journal LedgerJournal
---@param crumbs LedgerCrumb[]
---@param look LedgerBindingLook
local function drawCrumbs(journal, crumbs, look)
	local frame = journal.frame --[[@as LedgerJournalFrame]]
	local room = frame.crumbs:GetWidth()
	local x = 0
	for i, data in ipairs(crumbs) do
		local crumb = crumbAt(journal, i)
		crumb.gilt = look.gilt
		crumb.label:SetTextColor(unpack(look.gilt))
		if crumb.fleuron then
			-- the fleuron's gilt toward the binding's (the kit tints it from its own #e8c96a)
			crumb.fleuron:SetVertexColor(
				math.min(1, look.gilt[1] / 0.91),
				math.min(1, look.gilt[2] / 0.79),
				math.min(1, look.gilt[3] / 0.42)
			)
		end
		local lead = i > 1 and 32 or 0
		crumb.label:SetText(data.label)
		ns.JournalBound(crumb.label, math.max(1, room - x - lead))
		local width = crumb.label:GetWidth() + lead
		crumb:SetSize(width, 20)
		crumb:ClearAllPoints()
		crumb:SetPoint("LEFT", x, 0)
		crumb.place = i < #crumbs and data.place or nil
		crumb:Show()
		x = x + width
	end
	for i = #crumbs + 1, #frame.crumbButtons do
		frame.crumbButtons[i]:Hide()
	end
end

--- Whether the book is open: shown, and not fading out as it closes.
---@return boolean
function Journal:IsShown()
	return self.frame ~= nil and self.frame:IsShown() and not self.frame.closing
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

--- Opens the book, drawn as it stands now, fitted to the screen; opening it ticks the First evening list's item and
--- may show the Ledger's Margin note (ONB-R61, ONB-R52).
function Journal:Show()
	local fresh = not self.frame
	local frame = self.frame or build(self)
	self.frame = frame
	local opening = not frame:IsShown() or frame.closing
	if opening then
		Pagle.StopMotion(frame)
		frame.closing = false
		-- fitted again by Core as the UI scale or the screen's size changes
		Pagle.FitToScreen(frame, FIT)
		-- a book opened anew draws its spread in place, never turning to it
		self.justOpened = true
		frame:Show()
	end
	if fresh then
		self.binding = nil
	end
	self:Draw()
	-- what opening it does for onboarding, on its pages as drawn (adapter/Onboarding.lua)
	if opening then
		ns.JournalOpened(self)
	end
end

--- Closes the book with its sound: it fades out (0.12 s), then hides, left at rest for its next showing. Hidden with
--- the whole UI as it fades, it still ends closed: Core's driver settles the fade.
function Journal:Close()
	local frame = self.frame
	if not frame or not frame:IsShown() or frame.closing then
		return
	end
	ns.JournalSound("bookClose")
	frame.closing = true
	Pagle.StopMotion(frame)
	Pagle.Animate(frame, {
		{
			dur = 0.12,
			ease = Pagle.Bezier(0.42, 0, 1, 1),
			keys = { { 0, { 1 } }, { 1, { 0 } } },
			apply = function(v)
				frame:SetAlpha(v[1])
			end,
		},
	}, function()
		if frame.closing then
			frame:Hide()
			-- its OnHide already did this, unless the whole UI hid it first
			frame.closing = false
			frame:SetAlpha(1)
			ns.HidePrestigeConfirm()
		end
	end)
end

--- Opens spread `id` with `args`, opening the book if it is closed (LED-R125). Does nothing, and returns false, when
--- no spread is registered as `id`.
---@param id string
---@param args table?
---@return boolean opened
function Journal:Open(id, args)
	if not self.router:Open(id, args) then
		return false
	end
	self:Show()
	return true
end

--- Opens `place`: its spread with its args (LED-R125). Every link, crumb, tile and search result opens through it.
---@param place LedgerJournalPlace
---@return boolean opened
function Journal:OpenPlace(place)
	return self:Open(place.id, place.args)
end

--- The next drawing turns the page in `direction` even on the same spread (a Prestige turns to the new rank).
---@param direction "fwd"|"back"
function Journal:TurnNext(direction)
	self.turnDirection = direction
end

--- Ends every motion of the book at once, as settled: the page turn, the crossfade, the opening fade (a tour stop's
--- screenshot).
function Journal:Settle()
	local frame = self.frame
	if not frame then
		return
	end
	if self.finishTurn then
		self.finishTurn()
	end
	Pagle.StopMotion(frame)
	frame:SetAlpha(1)
end

--- Draws the book in binding `look` (LED-R112); `changing` from another one while open, as the kit changes binding
--- (MOTION.md): the page-turn sound, the leather dipping to 25% and back and the band to 55% (0.4 s), the binding
--- changing underneath at the dip.
---@param look LedgerBindingLook
---@param changing boolean
function Journal:Rebind(look, changing)
	local frame = self.frame --[[@as LedgerJournalFrame]]
	local owner = self.bindOwner or {}
	self.bindOwner = owner
	Pagle.StopMotion(owner)
	frame.leatherFill:SetAlpha(1)
	frame.bandFrame:SetAlpha(1)
	if changing then
		ns.JournalSound("rebind") -- whether or not things move
	end
	if not (changing and ns.MotionOn()) then
		ns.TintJournalShell(frame, look)
		return
	end
	Pagle.Animate(owner, {
		{
			dur = 0.4,
			ease = Pagle.EASE.inOut,
			keys = { { 0, { 1 } }, { 0.5, { 0.25 } }, { 1, { 1 } } },
			apply = function(v)
				frame.leatherFill:SetAlpha(v[1])
				frame.bandFrame:SetAlpha(0.4 + 0.6 * v[1])
			end,
		},
	})
	Pagle.Cue(owner, 0.2, function()
		ns.TintJournalShell(frame, look)
	end)
end

-- The leaf of `side` not shown now, made ready: shown whole and drawn on.
---@param frame LedgerJournalFrame
---@param side "left"|"right"
---@return LedgerJournalLeaf next
---@return LedgerJournalLeaf shown
local function swapLeaf(frame, side)
	local shown = frame.leaves[side][frame.shownLeaf[side]]
	local index = 3 - frame.shownLeaf[side]
	frame.shownLeaf[side] = index
	local nextLeaf = frame.leaves[side][index]
	frame[side] = nextLeaf.body
	return nextLeaf, shown
end

-- Turns the page from the leaves `from` to the leaves `to` (MOTION.md): forward, the right page lifts toward the spine
-- uncovering the new right page, then lands on the left from the spine outward; backward is the mirror image. A fold
-- shade darkens the lifting page and a soft shadow falls beside its edge. The crumbs change as it passes the spine.
---@param journal LedgerJournal
---@param from { left: LedgerJournalLeaf, right: LedgerJournalLeaf }
---@param to { left: LedgerJournalLeaf, right: LedgerJournalLeaf }
---@param forward boolean
---@param crumbs fun()
local function turn(journal, from, to, forward, crumbs)
	local frame = journal.frame --[[@as LedgerJournalFrame]]
	local papers = frame.papers
	local lw, rw = ns.JOURNAL_PAGE_W, ns.JOURNAL_PAGE_W
	local owner = journal.turnOwner
	Pagle.StopMotion(owner)
	local function finish()
		journal.finishTurn = nil
		Pagle.StopMotion(owner)
		from.left.clip:Hide()
		from.right.clip:Hide()
		reveal(to.left, papers.left, 0, 1)
		reveal(to.right, papers.right, 0, 1)
		frame.fold:Hide()
		crumbs()
	end
	journal.finishTurn = finish
	if not ns.MotionOn() then
		finish()
		return
	end
	ns.JournalSound("pageTurn")
	local fold = frame.fold
	fold:Show()
	if forward then
		reveal(to.left, papers.left, 1, 1)
		reveal(from.left, papers.left, 0, 1)
	else
		reveal(to.right, papers.right, 0, 0)
		reveal(from.right, papers.right, 0, 1)
	end
	Pagle.Animate(owner, {
		-- the page lifts toward the spine
		{
			dur = LIFT,
			ease = Pagle.Bezier(0.5, 0, 0.9, 0.6),
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				local k = v[1]
				if forward then
					reveal(from.right, papers.right, 0, 1 - k)
					reveal(to.right, papers.right, 1 - k, 1)
					placeFold(fold, papers.right, 0, (1 - k) * rw, (1 - k) * rw, 1, 0.28 * k, 1)
				else
					reveal(from.left, papers.left, k, 1)
					reveal(to.left, papers.left, 0, k)
					placeFold(fold, papers.left, k * lw, lw, k * lw, -1, 0.28 * k, 1)
				end
			end,
		},
		-- it lands on the other page, from the spine outward
		{
			dur = LAND,
			delay = LIFT,
			ease = Pagle.Bezier(0.1, 0.4, 0.4, 1),
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				local k = v[1]
				if k <= 0 then
					return
				end
				if forward then
					from.right.clip:Hide()
					reveal(to.right, papers.right, 0, 1)
					reveal(to.left, papers.left, 1 - k, 1)
					reveal(from.left, papers.left, 0, 1 - k)
					placeFold(fold, papers.left, (1 - k) * lw, lw, (1 - k) * lw, -1, 0.28 * (1 - k), 1 - k)
				else
					from.left.clip:Hide()
					reveal(to.left, papers.left, 0, 1)
					reveal(to.right, papers.right, 0, k)
					reveal(from.right, papers.right, k, 1)
					placeFold(fold, papers.right, 0, k * rw, k * rw, 1, 0.28 * (1 - k), 1 - k)
				end
			end,
		},
	}, finish)
	Pagle.Cue(owner, LIFT, crumbs)
end

-- Crossfades the right page from leaf `from` to leaf `to` (MOTION.md › Picking a fish on a zone page): the old one
-- fades out as the new one fades in, drifting up 3 units (0.2 s, ease-in-out), with the page-turn sound.
---@param journal LedgerJournal
---@param from LedgerJournalLeaf
---@param to LedgerJournalLeaf
local function crossfade(journal, from, to)
	local frame = journal.frame --[[@as LedgerJournalFrame]]
	local paper = frame.papers.right
	local owner = journal.turnOwner
	Pagle.StopMotion(owner)
	reveal(to, paper, 0, 1)
	local function finish()
		journal.finishTurn = nil
		from.clip:Hide()
		from.clip:SetAlpha(1)
		to.clip:SetAlpha(1)
		to.content:ClearAllPoints()
		to.content:SetAllPoints(paper)
	end
	journal.finishTurn = finish
	ns.JournalSound("pick") -- a fish picked sounds whether or not things move
	if not ns.MotionOn() then
		finish()
		return
	end
	Pagle.Animate(owner, {
		{
			dur = CROSSFADE,
			ease = Pagle.EASE.inOut,
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				from.clip:SetAlpha(1 - v[1])
				to.clip:SetAlpha(v[1])
				to.content:ClearAllPoints()
				to.content:SetPoint("TOPLEFT", paper, "TOPLEFT", 0, -3 * (1 - v[1]))
				to.content:SetPoint("BOTTOMRIGHT", paper, "BOTTOMRIGHT", 0, -3 * (1 - v[1]))
			end,
		},
	}, finish)
end

--- Draws both pages, the crumbs, the search slip and the back link from the router now, in the equipped binding, if
--- the book is open (LED-R122, LED-R125, LED-R112). Another spread turns the page to it, a fish picked crossfades the
--- right page, a Legend's plate opens over the spread; the same spread is drawn again in place, keeping each page's
--- scroll while its subject stays (LED-R129), and its widgets play their moments of change.
function Journal:Draw()
	local frame = self.frame
	if not frame or not frame:IsShown() then
		return
	end
	local binding = Pagle.GetEquipped(ns.BINDING_SLOT)
	local look = ns.BindingLook(binding)
	if binding ~= self.binding or not frame.leatherTint then
		self:Rebind(look, self.binding ~= nil and frame.leatherTint ~= nil)
	end
	self.binding = binding
	local context = self:Context()
	local pages = self.router:Pages(context)
	self.pages = pages
	-- The brass plate always shows (LED-R149): LED-R122 hides only the pages' contents, so while the projection updates
	-- it keeps the words last read. Only an update before anything was read (the login rebuild) leaves it hidden.
	if not pages.updating then
		self.plate = ns.BrassPlate(context --[[@as LedgerSpreadContext]])
	end
	ns.SetJournalPlate(frame, self.plate)

	local plate = frame.legendPlate
	frame.updatingView:SetShown(pages.updating)
	if pages.updating then
		-- LED-R122: only the quill and its line, the crumbs, search and back link hidden; each page keeps its scroll
		frame.crumbs:Hide()
		frame.search:Hide()
		frame.searchDrop:Hide()
		frame.back:Hide()
		frame.leaves.left[frame.shownLeaf.left].clip:Hide()
		frame.leaves.right[frame.shownLeaf.right].clip:Hide()
		plate:Hide()
		self.drawnPlate = false -- a Legend's plate opens again when the update finishes
		swayQuill(frame.updatingView)
		return
	end
	local function open(target)
		self:OpenPlace(target)
	end
	frame.crumbs:Show()
	frame.back.place = pages.back
	frame.back:SetShown(pages.back ~= nil)

	-- A Legend's plate over the spread (LED-R147): it opens over the pages as they stand
	local plateBlock = pages.left[1] and pages.left[1].kind == "plate" and pages.left[1] or nil
	if plateBlock then
		ns.FillLegendPlate(plate, plateBlock, open)
		if not self.drawnPlate then
			ns.OpenLegendPlate(plate)
			-- it covers both pages: under it, each starts again at the top (LED-R129), and stands again where an update
			-- hid it (LED-R122)
			for _, side in ipairs({ "left", "right" }) do
				frame[side].scroll:SetVerticalScroll(0)
				local leaf = frame.leaves[side][frame.shownLeaf[side]]
				if not leaf.clip:IsShown() then
					reveal(leaf, frame.papers[side], 0, 1)
				end
			end
		end
		self.drawnPlate = true
		frame.search:Hide()
		frame.searchDrop:Hide()
		drawCrumbs(self, pages.crumbs or {}, look)
		self.drawnSubjects, self.drawnId = pages.subjects, self.router:Place().id
		return
	end
	frame.search:Show()
	local leavingPlate = self.drawnPlate == true
	self.drawnPlate = false
	if leavingPlate then
		ns.CloseLegendPlate(plate)
	elseif plate:IsShown() then
		plate:Hide()
	end

	-- How it moves from what was drawn: turn to another spread, crossfade the right page, or draw again in place
	local place = self.router:Place()
	local drawn = self.drawnSubjects
	local subjects = pages.subjects or drawn or { left = "", right = "" }
	local leftChanged = drawn ~= nil and subjects.left ~= drawn.left
	local rightChanged = drawn ~= nil and subjects.right ~= drawn.right
	local depth = #(pages.crumbs or {})
	local forced = self.turnDirection
	self.turnDirection = nil
	local settled = self.justOpened
	self.justOpened = false
	local turning = drawn ~= nil
		and not settled
		and not leavingPlate
		and (forced ~= nil or place.id ~= self.drawnId or (leftChanged and place.id ~= ns.JOURNAL_HOME))
	local fading = drawn ~= nil
		and not settled
		and not turning
		and not leavingPlate
		and rightChanged
		and not leftChanged
	local forward = forced == "fwd" or (forced == nil and depth >= (self.drawnDepth or 0))
	self.drawnSubjects, self.drawnId, self.drawnDepth = subjects, place.id, depth
	if self.finishTurn then
		self.finishTurn()
	end
	local crumbs = function()
		drawCrumbs(self, pages.crumbs or {}, look)
	end

	if turning then
		local toLeft, fromLeft = swapLeaf(frame, "left")
		local toRight, fromRight = swapLeaf(frame, "right")
		ns.DrawJournalPage(toLeft.body, pages.left, open, true)
		ns.DrawJournalPage(toRight.body, pages.right, open, true)
		turn(self, { left = fromLeft, right = fromRight }, { left = toLeft, right = toRight }, forward, crumbs)
		return
	end
	crumbs()
	local leftLeaf = frame.leaves.left[frame.shownLeaf.left]
	reveal(leftLeaf, frame.papers.left, 0, 1)
	ns.DrawJournalPage(leftLeaf.body, pages.left, open, drawn == nil or leftChanged)
	if fading then
		local toRight, fromRight = swapLeaf(frame, "right")
		ns.DrawJournalPage(toRight.body, pages.right, open, true)
		crossfade(self, fromRight, toRight)
		return
	end
	local rightLeaf = frame.leaves.right[frame.shownLeaf.right]
	reveal(rightLeaf, frame.papers.right, 0, 1)
	ns.DrawJournalPage(rightLeaf.body, pages.right, open, drawn == nil or rightChanged)
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
			ns.journal:LiveApplied()
		end
	end
	wrapped.done = function(state, info)
		if done then
			done(state, info)
		end
		ns.journal:Draw()
	end
	return wrapped
end
