---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The Field guide's book (ONB-R20, ONB-R24, ONB-R27) on Core's book shell (Pagle.NewBook, core/book.md, ADR 0016): the
-- window, its fades and sounds, the binding, the two parchment pages, the strip, the wax close, the ribbons and the page
-- turn are the shell's. The guide asks for what is its own: fixed at the screen's centre (never dragged or saved), in
-- DIALOG over the world's dim, pinned to Field Leather, since the guide is read before the Angler owns anything (ADR
-- 0015); the crumbs "Pagle ❧ A field guide" with "{n} of {m}" at the strip's right; a page per registered step, in the
-- steps' order, its body the whole page (no padding: a step lays its pages from their top left, the onboarding kit's
-- 442 x 546); and a ribbon per step, the current one the chosen, a seen one ticked from the guide's own art
-- (GuideParts), one not yet seen dimmed. adapter/Guide.lua draws each step's pages and drives it.

local rgb = ns.Rgb

--- The book's measures (ONB-R20; Tunables), in UI units: the frame, each page (the shell's: the frame less its
--- leather's 18-unit sides, 38-unit strip and 16-unit foot), and the world's dim behind it.
ns.GUIDE_BOOK = { width = 920, height = 600, pageWidth = 442, pageHeight = 546, dim = 0.58 }
local BOOK = ns.GUIDE_BOOK

--- The frame's global name: UISpecialFrames takes names, and Esc closes the frames it lists (ONB-R20, BOOK-R2).
ns.GUIDE_FRAME_NAME = "PagleGuide"

--- The step ribbons' inks (ONB-R24): the guide's red (the kit's ribbon), a step not yet seen at 82% of it, and the
--- tick a seen step's ribbon carries, from GuideParts, inked in the ribbons' gilt.
ns.GUIDE_RIBBON = { color = rgb("A23A28"), unseen = 0.82, tick = rgb("FFF0BC") }
local RIBBON = ns.GUIDE_RIBBON

-- Where a tick sits on its ribbon: its top this far below the ribbon's (just under the book's edge, past the 2 units
-- the shell tucks under the band), centred across it.
local TICK_DROP = 11

--- The guide's book: the shell's handle, the ribbons as they hang now, and the ticks drawn on the shell's ribbons.
---@class PagleGuideBook
---@field book PagleBook
---@field ribbons PagleGuideRibbon[]
---@field shownKey string?                -- the ribbons last handed to the shell, as words and colours
---@field ticks table<Button, PagleSprite> -- by the shell's ribbon frame, made as needed

-- A step's place in the book: its page, the step's id.
---@param id string
---@return PagleBookPlace
function ns.GuidePlace(id)
	return { page = id }
end

-- The tick on `ribbon` (one of the shell's ribbon frames), made at its first use: the red pencil's tick (GuideParts),
-- desaturated and lit in gilt so it reads on the red, a layer over the ribbon's grosgrain and stitch.
---@param guideBook PagleGuideBook
---@param ribbon Button
---@return PagleSprite
local function tickOn(guideBook, ribbon)
	local tick = guideBook.ticks[ribbon]
	if not tick then
		tick = ns.ArtSprite(ribbon, "GuideParts", "tick-red", "OVERLAY")
		tick:SetDesaturated(true)
		tick:SetVertexColor(RIBBON.tick[1], RIBBON.tick[2], RIBBON.tick[3])
		tick:SetBlendMode("ADD")
		local box = tick.box
		ns.PlaceSprite(tick, ribbon, (ribbon:GetWidth() - (box[3] - box[1])) / 2, TICK_DROP)
		guideBook.ticks[ribbon] = tick
	end
	return tick
end

--- Ticks the shell's ribbon of each seen step but the current one (ONB-R24), through the shell's ribbon frames
--- (BOOK-R19): nothing before the book's first opening has made them.
---@param guideBook PagleGuideBook
function ns.DrawGuideTicks(guideBook)
	for _, tick in pairs(guideBook.ticks) do
		tick:Hide()
	end
	for _, ribbon in ipairs(guideBook.ribbons) do
		local frame = guideBook.book:RibbonFrame(ribbon.id)
		if frame then
			tickOn(guideBook, frame):SetShown(ribbon.seen and not ribbon.current)
		end
	end
end

--- Hangs the ribbons as `ribbons` says (ONB-R24): one per step, its words the step's, the current one the shell's
--- chosen (longer and brighter), a seen one ticked in full colour, one not yet seen dimmed; a click turns to its step.
--- The shell is handed them only when their words or colours change, since that hangs them at once and a change of
--- the chosen one runs as the book draws.
---@param guideBook PagleGuideBook
---@param ribbons PagleGuideRibbon[]
function ns.SetGuideRibbons(guideBook, ribbons)
	local list, keys = {}, {}
	for i, ribbon in ipairs(ribbons) do
		local k = (ribbon.current or ribbon.seen) and 1 or RIBBON.unseen
		list[i] = {
			id = ribbon.id,
			text = ribbon.label,
			color = { RIBBON.color[1] * k, RIBBON.color[2] * k, RIBBON.color[3] * k },
			target = ns.GuidePlace(ribbon.id),
		}
		keys[i] = ribbon.id .. "=" .. ribbon.label .. "@" .. k
	end
	guideBook.ribbons = ribbons
	local key = table.concat(keys, "\n")
	if key ~= guideBook.shownKey then
		guideBook.shownKey = key
		guideBook.book:SetRibbons(list)
	end
	ns.DrawGuideTicks(guideBook)
end

--- What the guide's book is fed by adapter/Guide.lua.
---@class PagleGuideBookOptions
---@field steps PagleGuideEntry[]                        -- the registered steps, in order: a page each
---@field render fun(side: PagleBookSide): fun(content: Frame, place: PagleBookPlace): number?
---@field onDraw fun(place: PagleBookPlace)
---@field onTurn fun(turn: PagleBookTurn, phase: PagleBookTurnPhase)
---@field onHide fun()

--- Makes the guide's book on Core's shell, with a page per step (its order the step's), each side drawn by
--- `options.render(side)`. Made at the guide's first opening, once every Module has registered its steps (ONB-R21).
---@param options PagleGuideBookOptions
---@return PagleGuideBook
function ns.NewGuideBook(options)
	local pages = {}
	for _, entry in ipairs(options.steps) do
		pages[entry.step.id] = { order = entry.step.order }
	end
	local L = ns.L
	local book = Pagle.NewBook({
		id = "core.guide",
		name = ns.GUIDE_FRAME_NAME,
		width = BOOK.width,
		height = BOOK.height,
		pages = pages,
		home = ns.GuidePlace(options.steps[1].step.id),
		strata = "DIALOG",
		fixed = true,
		dim = BOOK.dim,
		-- Field Leather, never the equipped binding: the guide is read before the Angler owns anything (ADR 0015)
		pinned = ns.DEFAULT_BINDING,
		pad = { x = 0, top = 0, bottom = 0 },
		trail = function()
			return { { text = L.GUIDE_CRUMB_PAGLE }, { text = L.GUIDE_CRUMB_GUIDE } }
		end,
		chosenRibbon = function(place)
			return place.page
		end,
		onDraw = options.onDraw,
		onTurn = options.onTurn,
		onHide = options.onHide,
	})
	for _, entry in ipairs(options.steps) do
		for _, side in ipairs({ "left", "right" }) do
			book:RegisterPage(entry.step.id, side, options.render(side))
		end
	end
	return { book = book, ribbons = {}, ticks = {} }
end
