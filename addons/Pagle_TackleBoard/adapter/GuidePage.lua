if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The Tackle Board's step in the Field guide (ONB-R37; board 8 of the onboarding kit, its Guide.lua's "7 · Tackle
-- Board"): its two pages, drawn once with the board's own art (adapter/BoardArt.lua, adapter/BoardWidgets.lua) and the
-- guide's coin bullet (nav.Part), as ONB-R92 has a Module draw its step. Core draws the book, the ribbons and the foot
-- (« back, the skip link "Not now" and Next »). The left page shows a sample strip of two Notices, the Campfire and
-- the Fly Box, standing still: the pins' own papers and the ledge's own art, taking no mouse and never moving. The
-- right page's Start my board is the board's own start (TKB-R5); once the board is up it reads "Your board is up",
-- disabled, re-read each time the step shows and at each of the board's redraws. Coordinates are the kit's, in UI
-- units from each page's top left (y down).

-- A page's text column: from 30, 382 wide (the kit's W).
local COLUMN_X, COLUMN_WIDTH = 30, 382
-- The sample strip: the Notices on a cut of cork, 396 × 108, the board's 495 × 135 at 0.8; the Campfire and the Fly
-- Box each on a 140 × 70 cut of the ledge, its 300 × 150 at 140 / 300.
local STRIP_Y, STRIP_WIDTH, STRIP_HEIGHT, STRIP_SCALE = 140.8, 396, 108, 0.8
local SAMPLE_WIDTH, SAMPLE_HEIGHT, SAMPLE_CUT = 140, 70, 300
local FIRE_Y, BOX_Y = 264.8, 350.8
-- Where each sample Notice hangs on the cork (its top left, in the board's units) and how it leans.
local NOTICE_AT = { { 10, 12, -0.6 }, { 252, 12, 0.8 } }
-- The cuts of the ledge (the frame art's element, which puts the ledge at 500 down): the Campfire's from 15, 505 and
-- the Fly Box's from 279, 505, so each sits in its cut as on the ledge, 15 and 279 to the left of it, 5 above.
local FIRE_CUT, BOX_CUT = { 15, 505 }, { 279, 505 }
-- The facts' tops on the right page, their coin bullets 11 under each (8 units of the guide's coin, which is 13
-- with a unit of margin round its 11), and Start my board's top.
local FACT_Y, COIN_SIZE = { 83.3, 113.8, 163.9, 214.1 }, 13 * 8 / 11
local START_Y = 264.6
-- The terms printed in the title's ink in the lines by the samples, and the Curio Shop's aside in a lighter one.
local TERM_INK, ASIDE_INK = "3E220C", "6A4A28"

--- The page as its build drew it, for its refreshes and the specs: Start my board, the coin bullets, and the sample's
--- Notices, Campfire and Fly Box.
---@class TackleGuidePage
---@field start TackleButtonView
---@field bullets Texture[]
---@field notices TackleGoalSlipView[]
---@field fire { ledge: Texture, burning: TackleBoardFire }
---@field box { ledge: Texture }

---@type TackleGuidePage?
ns.guidePage = nil

-- Words in an ink ("RRGGBB").
---@param hex string
---@param text string
---@return string
local function inked(hex, text)
	return "|cff" .. hex:lower() .. text .. "|r"
end

-- Puts `region`'s top left `x`, `y` from `page`'s top left (y down).
---@param region Region
---@param page Region
---@param x number
---@param y number
local function at(region, page, x, y)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", page, "TOPLEFT", x, -y)
end

-- Text on `page` in the board's font `key`, laid as the kit's P.T lays it: its line box `lineHeight` high from `y`,
-- wrapped to `width` when given (its lines that far apart), the glyphs in the box's middle.
---@param page Frame
---@param key string
---@param text string
---@param x number
---@param y number
---@param lineHeight number
---@param width number?
---@return FontString
local function write(page, key, text, x, y, lineHeight, width)
	local size = ns.BOARD_FONTS[key][2]
	local fontString = width and ns.ArtWrap(page, key, width, lineHeight - size) or ns.ArtText(page, key)
	fontString:SetText(text)
	at(fontString, page, x, y + (lineHeight - size) / 2)
	return fontString
end

-- A dotted rule across `page`, `width` long from `x`, `y`: the kit's P.Dots between the facts.
---@param page Frame
---@param x number
---@param y number
---@param width number
local function dots(page, x, y, width)
	local color = ns.BoardHex("8A5A2A")
	for i = 0, math.floor((width - 1) / 3) do
		local dot = page:CreateTexture(nil, "ARTWORK")
		dot:SetColorTexture(color[1], color[2], color[3], 0.45)
		dot:SetSize(1, 1)
		at(dot, page, x + i * 3, y)
	end
end

-- The sample's frame: a dark edge and a gilt rule inside it, over the sample, as the board's tooltip edges itself.
---@param sample Frame
local function edge(sample)
	local over = CreateFrame("Frame", nil, sample)
	over:SetAllPoints()
	over:SetFrameLevel(sample:GetFrameLevel() + 20)
	for _, ring in ipairs({ { 0, 2, "2A1A08" }, { 2, 1, "C9A24A" } }) do
		local inset, thickness, hex = ring[1], ring[2], ring[3]
		for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
			local rule = ns.BoardSolid(over, hex, 1, "OVERLAY")
			rule:ClearAllPoints()
			if side == "TOP" or side == "BOTTOM" then
				local y = side == "TOP" and -inset or inset
				rule:SetPoint(side .. "LEFT", inset, y)
				rule:SetPoint(side .. "RIGHT", -inset, y)
				rule:SetHeight(thickness)
			else
				local x = side == "LEFT" and inset or -inset
				rule:SetPoint("TOP" .. side, x, -inset)
				rule:SetPoint("BOTTOM" .. side, x, inset)
				rule:SetWidth(thickness)
			end
		end
	end
end

-- A sample's frame on `page` at `x`, `y`, `width` × `height`, cutting off what overflows it, with the board's art drawn
-- on a frame inside it at `scale`, `width / scale` × `height / scale` of the board's units. Returns that frame.
---@param page Frame
---@param x number
---@param y number
---@param width number
---@param height number
---@param scale number
---@return Frame
local function sampleFrame(page, x, y, width, height, scale)
	local sample = CreateFrame("Frame", nil, page)
	sample:SetSize(width, height)
	at(sample, page, x, y)
	sample:SetClipsChildren(true)
	local inner = CreateFrame("Frame", nil, sample)
	inner:SetScale(scale)
	inner:SetSize(width / scale, height / scale)
	inner:SetPoint("TOPLEFT")
	edge(sample)
	return inner
end

-- The two sample Notices on cork (TKB-R100, TKB-R102): the pins' own papers, leaning, taking no mouse.
---@param page Frame
---@param sample TackleGuideSample
---@return TackleGoalSlipView[]
local function drawNotices(page, sample)
	local cork = sampleFrame(page, COLUMN_X, STRIP_Y, STRIP_WIDTH, STRIP_HEIGHT, STRIP_SCALE)
	local tile = cork:CreateTexture(nil, "BACKGROUND", nil, -8)
	tile:SetTexture(ns.CORK_TEXTURE, "REPEAT", "REPEAT")
	tile:SetAllPoints()
	tile:SetTexCoord(0, cork:GetWidth() / ns.CORK_TILE, 0, cork:GetHeight() / ns.CORK_TILE)
	ns.ArtSprite(cork, "Glow", "cork-shade", "BACKGROUND", -7):SetAllPoints()
	local slips = {}
	for i, notice in ipairs(sample.notices) do
		local place = NOTICE_AT[i]
		local slot = CreateFrame("Frame", nil, cork)
		slot:SetSize(236, 116)
		at(slot, cork, place[1], place[2])
		local slip = ns.NewGoalSlip(slot, false)
		ns.DrawGoalSlip(slip, notice.goal, notice.view, place[3])
		slip:EnableMouse(false)
		slip.takeDown:EnableMouse(false)
		slips[i] = slip
	end
	return slips
end

-- The sample Campfire (TKB-R106): a cut of the ledge, the fire in its stage at rest with its glow, its days, its
-- Kindling and its longest, as the ledge draws them.
---@param page Frame
---@param sample TackleGuideSample
---@return { ledge: Texture, burning: TackleBoardFire }
local function drawFire(page, sample)
	local inner = sampleFrame(page, COLUMN_X, FIRE_Y, SAMPLE_WIDTH, SAMPLE_HEIGHT, SAMPLE_WIDTH / SAMPLE_CUT)
	local cutX, cutY = FIRE_CUT[1], FIRE_CUT[2]
	local ledge = ns.SetSpriteCut(
		inner:CreateTexture(nil, "BACKGROUND"),
		"Frame",
		"frame",
		cutX,
		cutY,
		SAMPLE_CUT,
		SAMPLE_CUT / 2
	)
	ledge:SetPoint("TOPLEFT")
	-- Each place on the ledge (adapter/Ledge.lua's), less the cut's corner on the ledge.
	local function onLedge(x, y)
		return x - cutX, y - (cutY - 500)
	end
	local view = sample.fire
	local glow = ns.ArtSprite(inner, "Fire", "fire-glow", "BACKGROUND", 1)
	ns.PlaceSprite(glow, inner, onLedge(20, 54))
	glow:SetAlpha(0.6 + 0.4 * view.bright)
	local burning = ns.NewBoardFire(inner, onLedge(30, 14))
	ns.SetBoardFire(burning, ns.CampfireStage(view))
	local days = ns.ArtText(inner, "FireDays")
	at(days, inner, onLedge(176, 48))
	days:SetText(tostring(sample.fireDays))
	local word = ns.ArtText(inner, "FireWord")
	word:SetPoint("BOTTOMLEFT", days, "BOTTOMRIGHT", 5, 2)
	word:SetText(ns.Plural(sample.fireDays, "DAYS_WORD"))
	for i = 1, ns.KINDLING_CAP do
		local stick = ns.ArtSprite(inner, "Board", "kindling", "ARTWORK")
		ns.PlaceSprite(stick, inner, onLedge(176 + (i - 1) * 44, 79))
		stick:SetAlpha(i <= view.kindling and 1 or 0.28)
	end
	local longest = ns.ArtText(inner, "Longest")
	at(longest, inner, onLedge(176, 98))
	longest:SetText(view.longest)
	return { ledge = ledge, burning = burning }
end

-- The sample Fly Box (TKB-R106): a cut of the ledge, the box with its name in gilt and its count by hand.
---@param page Frame
---@param sample TackleGuideSample
---@return { ledge: Texture }
local function drawBox(page, sample)
	local inner = sampleFrame(page, COLUMN_X, BOX_Y, SAMPLE_WIDTH, SAMPLE_HEIGHT, SAMPLE_WIDTH / SAMPLE_CUT)
	local cutX, cutY = BOX_CUT[1], BOX_CUT[2]
	local ledge = ns.SetSpriteCut(
		inner:CreateTexture(nil, "BACKGROUND"),
		"Frame",
		"frame",
		cutX,
		cutY,
		SAMPLE_CUT,
		SAMPLE_CUT / 2
	)
	ledge:SetPoint("TOPLEFT")
	local x, y = 322 - cutX, 30 - (cutY - 500)
	ns.PlaceSprite(ns.ArtSprite(inner, "Board", "flybox", "ARTWORK"), inner, x, y)
	local title = ns.ArtText(inner, "BoxLabel")
	title:SetJustifyH("CENTER")
	title:SetPoint("TOP", inner, "TOPLEFT", x + 107, -(y + 35))
	title:SetText(ns.Spaced(ns.L.FLY_BOX))
	local count = ns.ArtText(inner, "BoxCount")
	count:SetJustifyH("CENTER")
	count:SetPoint("TOP", inner, "TOPLEFT", x + 107, -(y + 50))
	count:SetText(sample.flies)
	return { ledge = ledge }
end

-- Shows Start my board as the board is now (ONB-R37, TKB-R5, TKB-R108): "Start my board", usable unless the
-- projection is updating, or "Your board is up", disabled. Nothing before the page is built.
local function refresh()
	local page = ns.guidePage
	if not page then
		return
	end
	local shows = ns.GuideStartShows(ns.KnownStarted(), ns.IsUpdating())
	page.start.label:SetText(shows.label)
	page.start:SetUsable(shows.usable)
end

-- Start my board (TKB-R5): the board's own start, which starts it unless the projection is updating or it is started
-- already, with its pin (the kit's SOUND.md) when it did; then the button reads what the board is now.
local function start()
	local was = ns.IsStarted()
	ns.board:Start()
	if not was and ns.IsStarted() then
		ns.BoardSound("pin")
	end
	refresh()
end

-- The left page: the kicker, the title and the paragraph, then the sample strip and its lines.
---@param left Frame
---@return TackleGuidePage
local function buildLeft(left)
	local L = ns.L
	write(left, "GuideKicker", L.GUIDE_KICKER, COLUMN_X, 24, 14)
	write(left, "GuideTitle", L.GUIDE_TITLE, COLUMN_X, 41, 29 * 1.05)
	write(left, "GuideBody", L.GUIDE_BODY, COLUMN_X, 83.4, 20.7, COLUMN_WIDTH)
	local sample = ns.GuideSample()
	local page = {
		notices = drawNotices(left, sample),
		fire = drawFire(left, sample),
		box = drawBox(left, sample),
	}
	local campfire = ns.Fill(L.GUIDE_CAMPFIRE, {
		campfire = inked(TERM_INK, L.GUIDE_CAMPFIRE_TERM),
		kindling = inked(TERM_INK, L.GUIDE_KINDLING_TERM),
	})
	write(left, "GuideSide", campfire, 184, 271.5, 18.9, 228)
	write(left, "GuideSide", ns.Fill(L.GUIDE_FLY_BOX, { flybox = inked(TERM_INK, L.FLY_BOX) }), 184, 366.9, 18.9, 228)
	return page --[[@as TackleGuidePage]]
end

-- The right page: the kicker and the title, the four facts by their coin bullets with dotted rules between them,
-- Start my board and the line under it.
---@param right Frame
---@param nav PagleGuideNav
---@param page TackleGuidePage
local function buildRight(right, nav, page)
	local L = ns.L
	write(right, "GuideKicker", L.GUIDE_ASK_KICKER, COLUMN_X, 24, 14)
	write(right, "GuideAsk", L.GUIDE_ASK_TITLE, COLUMN_X, 41, 25 * 1.05)
	page.bullets = {}
	for i, fact in ipairs(L.GUIDE_FACTS) do
		local y = FACT_Y[i]
		local coin = nav.Part(right, "coin")
		coin:SetSize(COIN_SIZE, COIN_SIZE)
		coin:ClearAllPoints()
		coin:SetPoint("CENTER", right, "TOPLEFT", 33 + 4, -(y + 11 + 4))
		page.bullets[i] = coin
		write(right, "GuideFact", ns.Fill(fact, { shop = inked(ASIDE_INK, L.GUIDE_FACT_SHOP) }), 52, y + 5, 19.575, 360)
		if FACT_Y[i + 1] then
			dots(right, COLUMN_X, FACT_Y[i + 1] - 1, COLUMN_WIDTH)
		end
	end
	page.start = ns.NewBoardButton(right, L.START_MY_BOARD, COLUMN_WIDTH, "GuideButton", start)
	at(page.start, right, COLUMN_X, START_Y)
	local leave = write(right, "GuideNote", L.GUIDE_LEAVE, COLUMN_X, 322.6, 17.55, COLUMN_WIDTH)
	leave:SetJustifyH("CENTER")
end

-- Draws the two pages, once (Contracts' build): the step shows them from then on.
---@param left Frame
---@param right Frame
---@param nav PagleGuideNav
local function build(left, right, nav)
	local page = buildLeft(left)
	buildRight(right, nav, page)
	ns.guidePage = page
	refresh()
end

--- Registers the Tackle Board's step with Core (ONB-R21, ONB-R37), at OnInitialize, before ModulesChanged: on a Core
--- without M:RegisterGuideStep, nothing (ONB-R90). The step shows whatever the board is: started, it reads "Your board
--- is up" from the first.
---@param module PagleModuleHandle
function ns.RegisterGuidePage(module)
	if not module.RegisterGuideStep then
		return
	end
	local L = ns.L
	module:RegisterGuideStep({
		id = ns.GUIDE_STEP.id,
		order = ns.GUIDE_STEP.order,
		ribbon = L.GUIDE_RIBBON,
		skipLabel = L.GUIDE_SKIP,
		skipTo = ns.GUIDE_STEP.skipTo,
		build = build,
		onShow = refresh,
	})
end

-- The board's redraws (the projection done updating, the board started from elsewhere) re-read Start my board.
ns.OnRedraw(function()
	refresh()
end)
