---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The Field guide on the client (core/onboarding.md › The Field guide): logic/Guide.lua's guide, wired over Core's host
-- by logic/Wiring.lua's ns.WireGuide, drawn in adapter/GuideBook.lua's book. Each step's two pages are made at its
-- first showing, inside clip frames on the book's papers, with Core's foot (ONB-R23: « back on the left page, the skip
-- link and Next » on the right, Off to the water on the last); its build draws the rest with its nav. The book opens
-- with the books' fade and sound over a dim of the world, turns with their page turn, drops the current ribbon, and
-- fits the screen (ONB-R27); every motion is settled at once with Animations off. Announcements are held under
-- "guide" while it is open (ONB-R70). Core's own four steps are placeholders here, their kicker and title alone,
-- until #323 draws them (ns.GUIDE_CORE_STEPS).

local L = ns.L
local BOOK = ns.GUIDE_BOOK

--- One page of one step: the clip frame on its paper that the turn narrows, and the content the build draws on, a
--- page's size (442 x 546) from the paper's top left.
---@class PagleGuideSide: PagleGuideTurnSide
---@field content Frame

--- The book's state on the client.
---@class PagleGuideBookState
---@field frame PagleGuideBookFrame?                         -- made at the first opening
---@field sides table<string, table<"left"|"right", PagleGuideSide>> -- each step's pages, by id, made at its first showing
---@field shown table<"left"|"right", PagleGuideSide>?      -- the step on the pages now
---@field turning { owner: table, from: table<"left"|"right", PagleGuideSide> }? -- a page turn under way
---@field closing table?                                     -- the close fading out now: its owner
local book = { sides = {} }
ns.guideBook = book

-- One page of a step on `paper`: a clip frame filling it, and the content inside, fixed to the paper.
---@param paper Frame
---@return PagleGuideSide
local function sideOn(paper)
	local clip = CreateFrame("Frame", nil, paper)
	clip:SetClipsChildren(true)
	clip:SetAllPoints()
	clip:Hide()
	local content = CreateFrame("Frame", nil, clip)
	content:SetSize(BOOK.pageWidth, BOOK.pageHeight)
	content:SetPoint("TOPLEFT", paper, "TOPLEFT")
	return { clip = clip, paper = paper, content = content }
end

-- Core's foot on a step's pages (ONB-R23): « back at the left page's foot on every step but the first; on the right,
-- the skip link (the step's skipLabel, or "Skip the rest") and Next » (Core's Welcome step: "Show me around »"), or on
-- the last step Off to the water. A step with its own foot (Core's Off you go) draws its own right foot.
---@param sides table<"left"|"right", PagleGuideSide>
---@param page PagleGuidePage
local function drawFoot(sides, page)
	local guide, step = ns.guide, page.entry.step
	if not page.first then
		ns.NewGuideBack(sides.left.content, function()
			guide:Back()
		end)
	end
	if step.ownFoot then
		return
	end
	if page.last then
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

-- The pages of `page`'s step, made at its first showing: its build draws them (through securecallfunction, so a
-- Module's mistake costs only its pages), then Core's foot goes on.
---@param page PagleGuidePage
---@return table<"left"|"right", PagleGuideSide>
local function pagesOf(page)
	local id = page.entry.step.id
	local sides = book.sides[id]
	if not sides then
		local frame = book.frame --[[@as PagleGuideBookFrame]]
		sides = { left = sideOn(frame.papers.left), right = sideOn(frame.papers.right) }
		book.sides[id] = sides
		local nav = ns.NewGuideNav(ns.guide, ns.GUIDE_WIDGETS)
		ns.host.call(page.entry.step.build, sides.left.content, sides.right.content, nav)
		drawFoot(sides, page)
	end
	return sides
end

-- Settles the page turn under way, if any, at once: the step it turned to whole, the one it turned from gone.
local function settleTurn()
	local turning = book.turning
	if not turning then
		return
	end
	book.turning = nil
	Pagle.StopMotion(turning.owner)
	for _, side in pairs(turning.from) do
		side.clip:Hide()
	end
	for _, side in pairs(book.shown or {}) do
		ns.RevealGuideSide(side, 0, 1)
	end
	local frame = book.frame
	if frame and frame.turnFold then
		frame.turnFold:Hide()
	end
end

-- Ribbon i's click (ONB-R24): the guide turns to its step.
---@param i integer
local function ribbonClicked(i)
	local entry = ns.guideSteps:List()[i]
	if entry then
		ns.guide:GoTo(entry.step.id)
	end
end

-- The book's frame, made at the first opening with a ribbon for every step registered.
---@return PagleGuideBookFrame
local function frameOf()
	local frame = book.frame
	if not frame then
		frame = ns.NewGuideBook(ns.guideSteps:Count(), function()
			ns.guide:Close()
		end, function()
			-- however it hid: Esc closes the guide too; after the close's own fade the guide is closed already
			if book.closing then
				Pagle.StopMotion(book.closing)
				book.closing = nil
			end
			settleTurn()
			local hidden = book.frame --[[@as PagleGuideBookFrame]]
			hidden:SetAlpha(1)
			hidden.dim:Hide()
			ns.GuideSound("bookClose")
			if ns.guide:IsOpen() then
				ns.guide:Close()
			end
		end, ribbonClicked)
		book.frame = frame
	end
	return frame
end

-- Opens the book on the screen, fitted (ONB-R27), over the dim, fading in (MOTION.md: 0.16 s, ease-out; the dim at
-- once); a close fading out gives way and the book stays.
---@param frame PagleGuideBookFrame
local function openBook(frame)
	if book.closing then
		Pagle.StopMotion(book.closing)
		book.closing = nil
		frame:SetAlpha(1)
		frame.dim:SetAlpha(1)
	end
	if frame:IsShown() then
		return
	end
	Pagle.FitToScreen(frame, { width = BOOK.extentWidth, height = BOOK.extentHeight, lift = BOOK.lift })
	frame.dim:SetAlpha(1)
	frame.dim:Show()
	frame:Show()
	ns.GuideSound("bookOpen")
	Pagle.Animate(frame, {
		{
			dur = BOOK.openFade,
			ease = Pagle.EASE.out,
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				frame:SetAlpha(v[1])
			end,
		},
	})
end

--- The view the guide drives (PagleGuideView): `show` opens the book on a page or turns to it, `close` closes it.
---@param page PagleGuidePage
---@param how PagleGuideShow
local function show(page, how)
	local frame = frameOf()
	local to = pagesOf(page)
	for i, ribbon in ipairs(page.ribbons) do
		ns.GuideRibbonAt(frame, i, ribbonClicked):SetRibbon(ribbon, how ~= "open")
	end
	local count = L.GUIDE_COUNT:format(page.index, page.count)
	settleTurn()
	local from = book.shown
	book.shown = to
	if how == "open" or not from or from == to or not frame:IsShown() then
		for _, sides in pairs(book.sides) do
			sides.left.clip:Hide()
			sides.right.clip:Hide()
		end
		ns.RevealGuideSide(to.left, 0, 1)
		ns.RevealGuideSide(to.right, 0, 1)
		frame.count:SetText(count)
		openBook(frame)
		return
	end
	---@type { owner: table, from: table<"left"|"right", PagleGuideSide> }
	local turning = { owner = {}, from = from }
	book.turning = turning
	turning.owner = ns.PlayGuideTurn(frame, {
		from = from,
		to = to,
		forward = how == "forward",
		papers = frame.papers,
		midway = function()
			frame.count:SetText(count)
		end,
		done = function()
			if book.turning == turning then
				settleTurn()
			end
		end,
	})
end

-- Closes the book: it fades out (MOTION.md: 0.12 s, easing in), dim and all, then hides; at once with Animations off.
-- The fade runs on an owner of its own, and the close ends on the clock too, so it ends whether or not frames draw.
local function close()
	local frame = book.frame
	if not frame or not frame:IsShown() or book.closing then
		return
	end
	if not Pagle.IsAnimationsOn() then
		frame:Hide()
		return
	end
	local closing = {}
	book.closing = closing
	Pagle.StopMotion(frame) -- an opening fade still running gives way
	local function finish()
		if book.closing == closing then
			book.closing = nil
			Pagle.StopMotion(closing)
			frame:Hide()
		end
	end
	Pagle.Animate(closing, {
		{
			dur = BOOK.closeFade,
			ease = Pagle.Bezier(0.42, 0, 1, 1),
			keys = { { 0, { 1 } }, { 1, { 0 } } },
			apply = function(v)
				frame:SetAlpha(v[1])
				frame.dim:SetAlpha(v[1])
			end,
		},
	}, finish)
	C_Timer.After(BOOK.closeFade, finish)
end

-- Core's own steps until #323 draws them (ONB-R30, ONB-R31, ONB-R34, ONB-R38): each page's kicker and title, and Off
-- you go's Off to the water, so the guide is whole end to end.

-- A placeholder: the left page's kicker and title, and the right page's when given.
---@param left string[] kicker, title
---@param right string[]?
---@return PagleCoreGuideStepDrawing
local function placeholder(left, right)
	return {
		build = function(leftPage, rightPage)
			ns.NewGuideKicker(leftPage, left[1])
			ns.NewGuideTitle(leftPage, left[2])
			if right then
				ns.NewGuideKicker(rightPage, right[1])
				ns.NewGuideTitle(rightPage, right[2], 25)
			end
		end,
	}
end

--- What draws each of Core's own steps, by id (logic/Guide.lua's ns.CoreGuideSteps), looked up as each step first
--- draws: #323 replaces these entries with its pages.
---@type table<string, PagleCoreGuideStepDrawing>
ns.GUIDE_CORE_STEPS = {
	welcome = placeholder(
		{ L.GUIDE_WELCOME_KICKER, L.GUIDE_WELCOME_TITLE },
		{ L.GUIDE_WELCOME_RIGHT_KICKER, L.GUIDE_WELCOME_RIGHT_TITLE }
	),
	box = placeholder({ L.GUIDE_BOX_KICKER, L.GUIDE_BOX_TITLE }),
	moments = placeholder(
		{ L.GUIDE_MOMENTS_KICKER, L.GUIDE_MOMENTS_TITLE },
		{ L.GUIDE_MOMENTS_RIGHT_KICKER, L.GUIDE_MOMENTS_RIGHT_TITLE }
	),
	off = {
		build = function(left, right, nav)
			placeholder(
				{ L.GUIDE_OFF_KICKER, L.GUIDE_OFF_TITLE },
				{ L.GUIDE_OFF_RIGHT_KICKER, L.GUIDE_OFF_RIGHT_TITLE }
			).build(left, right, nav)
			-- Off to the water (ONB-R38): the kit's big leather button, and the line under it
			local off = ns.NewGuideButton(right, L.GUIDE_OFF, nav.Finish, 382, 46, 18)
			ns.GuideAt(off, right, 30, 359.7)
			local again = ns.GuideText(right, "italic", 13, "note", L.GUIDE_OFF_AGAIN, { justify = "CENTER" })
			again:SetPoint("TOP", right, "TOPLEFT", 221, -(415.7 + 2.275))
		end,
	},
}

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
