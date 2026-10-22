if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Ledger's parts of onboarding on the client (core/onboarding.md): the Field guide's Your Ledger step (ONB-R36),
-- drawn with the Ledger's own art (the Angler page's crest holding the likeness, its fonts and inks) and the guide's
-- parts through `nav.Part`; and, as the Fish Journal opens, the First evening list's `journal` item (ONB-R61) and the
-- `ledger.fresh` Margin note (ONB-R52). Margin notes are Core's frames (ONB-R92); every call is made only when Core
-- has it (ONB-R90), so the Ledger runs on a Core without them.

local L = ns.L
local INK = ns.JOURNAL_INK

-- The guide's page: its text column (30 to 412) and the kit's inks the Journal has no name for.
local W = 382
local NAME_INK, RULE_INK, SINCE_INK, LINE_INK, BOX_INK = "6a4a28", "8a5a2a", "8a8070", "6a4a28", "fbf3de"

-- A label on `parent` in the Ledger's `face`, its top at (x, y) from the page's top left: its left edge there, or
-- centred on x (`center`), or its right edge there (`right`). `width` wraps it.
---@param parent Frame
---@param face LedgerArtFace
---@param size number
---@param hex string
---@param words string
---@param x number
---@param y number
---@param options { center: boolean?, right: boolean?, width: number? }?
---@return FontString
local function text(parent, face, size, hex, words, x, y, options)
	options = options or {}
	local label = ns.JournalLabel(parent, face, size, hex, words, {
		wrap = options.width ~= nil,
		width = options.width,
		justify = options.center and "CENTER" or options.right and "RIGHT" or "LEFT",
	})
	local point = options.center and "TOP" or options.right and "TOPRIGHT" or "TOPLEFT"
	label:SetPoint(point, parent, "TOPLEFT", x, -y)
	return label
end

-- Places a guide part (a sprite of the guide's atlas, `nav.Part`'s) so its drawn element's top left is at (x, y).
---@param part Texture
---@param parent Frame
---@param x number
---@param y number
local function place(part, parent, x, y)
	local box = (part --[[@as LedgerSpriteTexture]]).box or { 0, 0 }
	part:ClearAllPoints()
	part:SetPoint("TOPLEFT", parent, "TOPLEFT", x - box[1], -(y - box[2]))
end

-- ---------------------------------------------------------------- the Your Ledger step (ONB-R36)

-- The bookplate's crest drawn at this scale of the Angler page's (LED-R146), so the plain frame stands 72 high in the
-- plate, where the kit's ring sits.
local CREST_SCALE = 0.48
-- The box of Skill Milestones (the kit's): its top, a row's height, and a row's height when four share it.
local BOX_Y, ROW_H, ROW_H_FOUR = 125.7, 50, 40

--- One line of the box: its mark, title, line and XP, and the dots under it.
---@class LedgerGuideRowView
---@field tick Texture
---@field ring Texture
---@field title FontString
---@field line FontString
---@field xp FontString
---@field dots LedgerDotLine

--- What the step drew, refilled each time it shows.
---@class LedgerGuideStepView
---@field left Frame
---@field right Frame
---@field name FontString
---@field crestHolder Frame
---@field crest LedgerJournalWidget
---@field since FontString
---@field heading FontString
---@field fill Texture
---@field shadow Texture
---@field edges Texture[]
---@field rows LedgerGuideRowView[]
---@field account FontString
---@field note Frame

-- The step's live parts now (logic/Onboarding.lua).
---@return LedgerGuidePage
local function pageNow()
	local celebrated = ns.SavedCelebrated()
	return ns.GuideLedgerPage({
		state = ns.StateNow(),
		celebrated = { skill = celebrated.skill or {} },
		angler = Pagle.GetAngler(),
		text = ns.journalText,
		formatNumber = BreakUpLargeNumbers,
	})
end

-- Draws the bookplate's crest (the Angler page's: the Prestige crest for the rank holding the likeness, the equipped
-- bookplate crest pinned on it, LED-R112) centred on the plate at the page's x 221, its top at y 207.
---@param view LedgerGuideStepView
---@param prestige integer
local function fillCrest(view, prestige)
	local crest = view.crest
	crest:Fill({ kind = "crest", rank = prestige, icon = ns.CrestIcon() }, 0, function() end, { same = false })
	local w, h = (crest.floatW or 18) - 18, (crest.floatH or 6) - 6
	crest:SetSize(w, h)
	local holder = view.crestHolder
	holder:SetSize(w * CREST_SCALE, h * CREST_SCALE)
	ns.JournalAt(holder, view.left, 221 - w * CREST_SCALE / 2, 207)
end

-- Fills the box of Skill Milestones and moves what follows it to fit its rows (the kit's 50 units a row, 40 when
-- four share it).
---@param view LedgerGuideStepView
---@param page LedgerGuidePage
local function fillBox(view, page)
	local right = view.right
	view.heading:SetText(page.heading)
	local pitch = #page.rows >= 4 and ROW_H_FOUR or ROW_H
	local height = 37 + #page.rows * pitch + 9
	view.fill:SetSize(W, height)
	view.shadow:SetSize(W, height)
	-- its 1-unit edges: top, bottom, left, right
	local top, bottom, left, side = unpack(view.edges)
	top:SetSize(W, 1)
	ns.JournalAt(top, right, 30, BOX_Y)
	bottom:SetSize(W, 1)
	ns.JournalAt(bottom, right, 30, BOX_Y + height - 1)
	left:SetSize(1, height)
	ns.JournalAt(left, right, 30, BOX_Y)
	side:SetSize(1, height)
	ns.JournalAt(side, right, 30 + W - 1, BOX_Y)
	for i, row in ipairs(view.rows) do
		local data = page.rows[i]
		local shown = data ~= nil
		for _, region in ipairs({ row.tick, row.ring, row.title, row.line, row.xp }) do
			region:SetShown(shown)
		end
		row.dots:Hide()
		if data then
			local y = BOX_Y + 37 + (i - 1) * pitch
			row.tick:SetShown(data.credited)
			row.ring:SetShown(not data.credited)
			place(row.tick, right, 46, y + 10)
			place(row.ring, right, 46, y + 10)
			ns.JournalAt(row.title, right, 71, y + 10)
			row.title:SetText(data.title)
			ns.JournalAt(row.line, right, 71, y + 28.7)
			row.line:SetText(data.line)
			row.xp:ClearAllPoints()
			row.xp:SetPoint("TOPRIGHT", right, "TOPLEFT", 397, -(y + 8))
			row.xp:SetText(data.xp or "")
			row.xp:SetTextColor(ns.JournalRGB(data.credited and INK.red or SINCE_INK))
			if i < #page.rows then
				row.dots:Lay(45, y + pitch - 0.5, 352)
			end
		end
	end
	local below = BOX_Y + height + 16
	ns.JournalAt(view.account, right, 30, below)
	ns.JournalAt(view.note, right, 70, below + 46.3)
end

-- Fills the step from the Ledger's state now: the crest, kept since, the box (ONB-R36).
---@param view LedgerGuideStepView
local function refresh(view)
	local page = pageNow()
	view.name:SetText(page.name)
	fillCrest(view, page.prestige)
	view.since:SetText(page.since or "")
	fillBox(view, page)
end

--- Draws the Your Ledger step's two pages (ONB-R36; board 7, the probe's Guide.lua): on the left, the bookplate on
--- the guide's plate with "Ex Libris", the Angler page's crest holding the likeness, "The Angler's Ledger", the
--- character's name and kept since; on the right, the box of Skill Milestones headed by the character's skill, the
--- account paragraph and the note. Core draws the foot (ONB-R23).
---@param left Frame
---@param right Frame
---@param nav PagleGuideNav
---@return LedgerGuideStepView
function ns.DrawGuideLedgerStep(left, right, nav)
	text(left, "sc", 14, INK.kicker, L.GUIDE_KICKER, 30, 24)
	text(left, "print", 29, INK.title, L.GUIDE_TITLE, 30, 41)
	text(left, "print", 15, INK.body, L.GUIDE_BODY, 30, 85.4, { width = W })
	place(nav.Part(left, "plate"), left, 96, 160)
	text(left, "sc", 13, INK.red, L.ANGLER_EX_LIBRIS, 221, 186.6, { center = true })
	local holder = CreateFrame("Frame", nil, left)
	holder:SetFrameLevel(left:GetFrameLevel() + 2)
	local crest = ns.NewJournalWidgetOf("crest", holder)
	crest:SetScale(CREST_SCALE)
	crest:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
	text(left, "print", 19, INK.title, L.ANGLER_LEDGER, 221, 289.6, { center = true })
	local name = text(left, "italic", 14, NAME_INK, "", 221, 316, { center = true })
	local rule = ns.JournalTint(left, RULE_INK, 0.5)
	rule:SetSize(216, 1)
	ns.JournalAt(rule, left, 113, 342.5)
	local since = text(left, "hand", 18, SINCE_INK, "", 221, 351, { center = true })

	text(right, "sc", 14, INK.kicker, L.GUIDE_RIGHT_KICKER, 30, 24)
	text(right, "print", 25, INK.title, L.GUIDE_RIGHT_TITLE, 30, 41)
	text(right, "print", 13.5, INK.small, L.GUIDE_RIGHT_BODY, 30, 75.3, { width = W })
	local shadow = ns.JournalTint(right, INK.body, 0.1, "BACKGROUND")
	ns.JournalAt(shadow, right, 32, BOX_Y + 3)
	local fill = ns.JournalTint(right, BOX_INK, 0.6, "BORDER")
	ns.JournalAt(fill, right, 30, BOX_Y)
	local edges = {}
	for i = 1, 4 do
		edges[i] = ns.JournalTint(right, INK.rule, 1, "BORDER", 1)
	end
	local heading = text(right, "sc", 15, INK.title, "", 45, BOX_Y + 15.3)
	text(right, "italic", 12.5, RULE_INK, L.GUIDE_READ_NOW, 397, BOX_Y + 16, { right = true })
	local hr = ns.JournalTint(right, INK.rule, 1)
	hr:SetSize(352, 1)
	ns.JournalAt(hr, right, 45, BOX_Y + 36.3)
	local rows = {}
	for i = 1, #ns.SKILL_MILESTONES do
		rows[i] = {
			tick = nav.Part(right, "tick-red"),
			ring = nav.Part(right, "ring-ghost"),
			title = text(right, "print", 15, INK.title, "", 71, 0),
			line = text(right, "italic", 12.5, LINE_INK, "", 71, 0),
			xp = text(right, "hand", 18, INK.red, "", 397, 0, { right = true }),
			dots = ns.JournalDotLine(right, RULE_INK, 0.45, 3),
		}
	end
	---@type LedgerGuideStepView
	local view = {
		left = left,
		right = right,
		name = name,
		crestHolder = holder,
		crest = crest,
		since = since,
		heading = heading,
		fill = fill,
		shadow = shadow,
		edges = edges,
		rows = rows,
		account = text(right, "print", 13.5, INK.small, L.GUIDE_ACCOUNT, 30, 0, { width = W }),
		note = nav.Note(right, L.GUIDE_NOTE, 70, 0, 290),
	}
	refresh(view)
	return view
end

--- The Your Ledger step as drawn, once the guide first shows it (for a spec to read).
---@type LedgerGuideStepView?
ns.guideLedger = nil

--- Registers the Your Ledger step at 60 (ONB-R21, ONB-R36), from OnInitialize: before ModulesChanged. Called only
--- when `M.RegisterGuideStep` exists (ONB-R90). Each time it shows it re-reads the Ledger's state.
---@param M PagleModuleHandle
function ns.RegisterGuideLedgerStep(M)
	---@type LedgerGuideStepView?
	local view
	M:RegisterGuideStep({
		id = "ledger",
		order = 60,
		ribbon = L.GUIDE_RIBBON,
		build = function(left, right, nav)
			view = ns.DrawGuideLedgerStep(left, right, nav)
			ns.guideLedger = view
		end,
		onShow = function()
			if view then
				refresh(view)
			end
		end,
	})
end

-- ---------------------------------------------------------------- as the Journal opens

-- The shown widgets of block kind `kind` on the Journal's `side` page now, in page order.
---@param journal LedgerJournal
---@param side "left"|"right"
---@param kind string
---@return LedgerJournalWidget[]
local function drawnOf(journal, side, kind)
	local frame = journal.frame
	local page = frame and frame[side]
	return page and page.drawn[kind] or {}
end

-- The ink XP bar drawn on either page now (Home's, or the Angler page's), if any.
---@param journal LedgerJournal
---@return LedgerXpBarWidget?
local function xpBarOf(journal)
	return (drawnOf(journal, "right", "xpBar")[1] or drawnOf(journal, "left", "xpBar")[1]) --[[@as LedgerXpBarWidget?]]
end

--- The ink bar's blue part, Fresh Water's stretch, while the open Journal shows one (LED-R145); nil otherwise.
---@param journal LedgerJournal
---@return Texture?
function ns.JournalFreshPart(journal)
	local widget = xpBarOf(journal)
	local fresh = widget and widget.bar.fresh
	if widget and fresh and widget:IsShown() and fresh:IsShown() then
		return fresh
	end
	return nil
end

--- The Fish Journal has opened, drawn (adapter/Journal.lua): the First evening list's `journal` item (ONB-R61); with
--- its pages written, the `ledger.fresh` note on the ink bar's blue part while it shows (ONB-R52, once per account,
--- Core's). Each only on a Core that has it (ONB-R90).
---@param journal LedgerJournal
function ns.JournalOpened(journal)
	local M = ns.Module
	if not M then
		return
	end
	if M.CompleteEveningItem then
		M:CompleteEveningItem("journal")
	end
	if not journal.pages or journal.pages.updating then
		return
	end
	local fresh = ns.JournalFreshPart(journal)
	if fresh and M.ShowMarginNote then
		M:ShowMarginNote({ id = "ledger.fresh", text = ns.RedPencilTerms(L.NOTE_FRESH), target = fresh })
	end
end
