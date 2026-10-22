---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The Field guide on the client (core/onboarding.md › The Field guide): logic/Guide.lua's guide, wired over Core's host
-- by logic/Wiring.lua's ns.WireGuide, drawn in adapter/GuideBook.lua's book on Core's shell (Pagle.NewBook, ADR 0016).
-- The guide drives the book: each step shown opens the book there, or turns to it forward or back (BOOK-R30), and a
-- ribbon the shell turns to (BOOK-R18) is followed by the guide. Each step's two pages are made at its first draw,
-- with Core's foot (ONB-R23: « back on the left page, the skip link and Next » on the right, Off to the water on the
-- last); its build draws the rest with its nav. The shell fades the book and its dim, plays its sounds, turns its pages
-- and fits it to the screen (ONB-R27), each settled at once with Animations off. Announcements are held under "guide"
-- while it is open (ONB-R70). Core's own four steps are drawn by adapter/GuidePages.lua (ns.GUIDE_CORE_STEPS).

local L = ns.L
local BOOK = ns.GUIDE_BOOK

--- One page of one step: the sheet its build draws on, a page's size (442 x 546), made on the shell's content frame
--- for that side of the step's page at its first draw.
---@class PagleGuideSide
---@field content Frame

--- The book's state on the client.
---@class PagleGuideBookState
---@field book PagleGuideBook?                                       -- made at the first opening
---@field sides table<string, table<PagleBookSide, PagleGuideSide>>   -- each step's pages, by id, made at its first draw
---@field count string?                                               -- "{n} of {m}" for the step shown
---@field turning boolean                                             -- a page turn under way: the count waits for the spine
---@field following boolean                                           -- the guide follows a turn the shell began
local state = { sides = {}, turning = false, following = false }
ns.guideBook = state

-- Core's foot on a step's pages (ONB-R23): « back at the left page's foot on every step but the first; on the right,
-- the skip link (the step's skipLabel, or "Skip the rest") and Next » (Core's Welcome step: "Show me around »"), or on
-- the last step Off to the water. A step with its own foot (Core's Off you go) draws its own right foot.
---@param sides table<PagleBookSide, PagleGuideSide>
---@param step PagleGuideStep
---@param first boolean
---@param last boolean
local function drawFoot(sides, step, first, last)
	local guide = ns.guide
	if not first then
		ns.NewGuideBack(sides.left.content, function()
			guide:Back()
		end)
	end
	if step.ownFoot then
		return
	end
	if last then
		ns.NewGuideFoot(sides.right.content, nil, function() end, L.GUIDE_OFF, function()
			guide:Finish()
		end)
		return
	end
	ns.NewGuideFoot(
		sides.right.content,
		step.skipLabel or L.GUIDE_SKIP,
		function()
			guide:Skip()
		end,
		step.nextLabel or L.GUIDE_NEXT,
		function()
			guide:Next()
		end
	)
end

-- The renderer of each step's `side` (BOOK-R21). A step's page keeps its content frames (it never turns onto itself),
-- so each side's sheet is made once on its content frame, the page's size from its top left, and fits the body (nil).
-- When both of a step's sheets are made, at its first draw, its build draws them (through securecallfunction, so a
-- Module's mistake costs only its pages), then Core's foot goes on.
---@param side PagleBookSide
---@return fun(content: Frame, place: PagleBookPlace): number?
local function render(side)
	return function(content, place)
		local id = place.page
		local sides = state.sides[id]
		if not sides then
			sides = {}
			state.sides[id] = sides
		end
		if sides[side] then
			return nil
		end
		local sheet = CreateFrame("Frame", nil, content)
		sheet:SetSize(BOOK.pageWidth, BOOK.pageHeight)
		sheet:SetPoint("TOPLEFT", content, "TOPLEFT")
		sides[side] = { content = sheet }
		if sides.left and sides.right then
			local steps = ns.guideSteps
			local index = steps:Index(id) --[[@as integer]]
			local step = steps:List()[index].step
			local nav = ns.NewGuideNav(ns.guide, ns.GUIDE_WIDGETS)
			ns.host.call(step.build, sides.left.content, sides.right.content, nav)
			drawFoot(sides, step, index == 1, index == steps:Count())
		end
		return nil
	end
end

-- Writes "{n} of {m}" at the strip's right (BOOK-R12).
local function writeCount()
	if state.book and state.count then
		state.book.book:SetStripText(state.count)
	end
end

-- The shell drew `place` (BOOK-R21): a ribbon it turned to (BOOK-R18) is followed by the guide (ONB-R24), which marks
-- the step shown and hangs the ribbons anew.
---@param place PagleBookPlace
local function drawn(place)
	local guide = ns.guide
	local current = guide:Current()
	if state.following or not current or current.step.id == place.page then
		return
	end
	state.following = true
	guide:GoTo(place.page)
	state.following = false
end

-- The turn's hook (BOOK-R33): the count changes as the page passes the spine.
---@param _ PagleBookTurn
---@param phase PagleBookTurnPhase
local function turned(_, phase)
	if phase == "start" then
		state.turning = true
	elseif phase == "midway" or phase == "done" then
		writeCount()
		if phase == "done" then
			state.turning = false
		end
	end
end

-- The book, made at the first opening with a page and a ribbon for every step registered (ONB-R21). However it closes
-- (Esc through UISpecialFrames, the wax close), the guide closes with it, keeping guideStep (ONB-R22).
---@return PagleGuideBook
local function bookOf()
	local made = state.book
	if not made then
		made = ns.NewGuideBook({
			steps = ns.guideSteps:List(),
			render = render,
			onDraw = drawn,
			onTurn = turned,
			onHide = function()
				state.turning = false
				if ns.guide:IsOpen() then
					ns.guide:Close()
				end
			end,
		})
		state.book = made
	end
	return made
end

--- The view the guide drives (PagleGuideView): `show` opens the book on a page or turns to it, `close` closes it.
---@param page PagleGuidePage
---@param how PagleGuideShow
local function show(page, how)
	local made = bookOf()
	local book = made.book
	ns.SetGuideRibbons(made, page.ribbons)
	state.count = L.GUIDE_COUNT:format(page.index, page.count)
	if state.following then
		-- the shell is turning there already
		if not state.turning then
			writeCount()
		end
		return
	end
	local place = ns.GuidePlace(page.entry.step.id)
	if how == "open" or not book:IsShown() then
		writeCount()
		book:Open(place, { motion = "still" })
	else
		book:Open(place, { motion = "turn", forward = how == "forward" })
		if not state.turning then
			writeCount()
		end
	end
	ns.DrawGuideTicks(made)
end

-- Closes the book: the shell fades it out, dim and all, then hides it (at once with Animations off).
local function close()
	local made = state.book
	if made and made.book:IsShown() then
		made.book:Close()
	end
end

ns.WireGuide(ns.host, {
	show = show,
	close = close,
	hold = function(reason)
		ns.HoldAnnouncements(reason)
	end,
	release = function(reason)
		ns.ReleaseAnnouncements(reason)
	end,
	coreSteps = ns.GUIDE_CORE_STEPS,
})

-- ONB-R84: a tour stop per step, Modules' included, once every enabled Module has registered its steps (CORE-R19).
Pagle.RegisterCallback("Pagle guide tour", "ModulesChanged", function()
	ns.AddGuideTourStops()
end)
