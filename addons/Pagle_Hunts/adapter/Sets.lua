if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Sets on the Hunts board (HNT-R61, HNT-R66, HNT-R69): gathers logic/Sets.lua's inputs from the Hunt list, the
-- projection and the grouping, and draws its results on the board: the set ribbons, the breadcrumbs and the nameplate
-- on the leather's anchors, and the right side of a set's page (the set mode's right page). The look follows
-- prototypes/hunts-board/ variant E, in adapter/BoardWidgets.lua's art.

-- The time the sets' views judge "current" and count the checklist's labels down at: now, or the grouping's while it
-- is paused, so they freeze with it (HNT-R43).
---@return integer
local function viewTime()
	return ns.TimelineNow()
end

-- logic/Sets.lua's inputs, read now.
---@return HuntsSetsInput
local function inputs()
	return { list = ns.hunts, state = ns.State(), updating = ns.IsUpdating(), now = viewTime() }
end

--- The set ribbons at `place` (HNT-R61), as data.
---@param place BoardPlace
---@return BoardRibbon[]
function ns.BoardRibbons(place)
	return ns.BuildRibbons(inputs(), place)
end

--- The breadcrumbs where the board is (HNT-R61), as data.
---@return BoardCrumbView[]
function ns.BoardCrumbs()
	return ns.BuildCrumbs(ns.board.router:Trail(), ns.hunts)
end

-- A current Hunt's tracker label (HNT-R51) from its row in the grouping, at the grouping's time; nil before the first
-- grouping.
---@param huntID string
---@return string?
local function trackerLabel(huntID)
	local row = ns.groups:Row(huntID)
	if not row then
		return nil
	end
	local _, tracker = ns.HuntLabels(ns.LabelCase(row, ns.where[huntID], viewTime(), Pagle.GetConditions()))
	return tracker
end

--- The right side of set `setID`'s page (HNT-R66), as data.
---@param setID string
---@return SetPage
function ns.BoardSetPage(setID)
	return ns.BuildSetPage(inputs(), setID, trackerLabel)
end

--- The nameplate (HNT-R61), as data.
---@return BoardNameplate
function ns.BoardNameplate()
	return ns.BuildNameplate(inputs())
end

-- Drawing. Each anchor and page keeps the widgets it made, and a redraw reuses them, hiding what it doesn't need.

local LOOK = ns.BOARD_LOOK

-- The gap between ribbons, the fleuron's size and the room round it, and a crumb's colour under the mouse.
local RIBBON_GAP, FLEURON, FLEURON_ROOM = 5, 10, 8

local function hideTooltip()
	GameTooltip:Hide()
end

---@class SetsRibbonsAnchor: Frame
---@field ribbons BoardRibbonView[]

-- The set ribbons down the leather's right edge (HNT-R61): Board, then each set's, in its colour, the one of the mode
-- shown standing out. Clicking one opens its place; a set's shows its full name on hover.
---@param anchor SetsRibbonsAnchor
---@param place BoardPlace
local function drawRibbons(anchor, place)
	anchor.ribbons = anchor.ribbons or {}
	local y = 0
	local ribbons = ns.BoardRibbons(place)
	for i, data in ipairs(ribbons) do
		local ribbon = ns.BoardPooled(anchor.ribbons, i, function()
			local made = ns.NewBoardRibbon(anchor)
			made:SetScript("OnLeave", hideTooltip)
			return made
		end)
		local color = data.set and ns.BoardRibbonColor(data.index) or LOOK.boardRibbon
		ribbon:SetRibbon(data.text, color, data.chosen)
		ribbon:ClearAllPoints()
		ribbon:SetPoint("TOPLEFT", 0, -y)
		y = y + ribbon:GetHeight() + RIBBON_GAP
		ribbon:SetScript("OnClick", function()
			ns.board:Open(data.place)
		end)
		ribbon:SetScript("OnEnter", function(self)
			ns.BoardTooltip(self, { data.name or data.text })
		end)
	end
	ns.BoardHideFrom(anchor.ribbons, #ribbons)
end

---@class SetsCrumb: Button
---@field label FontString

---@class SetsCrumbsAnchor: Frame
---@field crumbs SetsCrumb[]
---@field fleurons Texture[]

-- The gilt breadcrumbs (HNT-R61): "Hunts", the set, the Hunt, a fleuron between each, each going back up.
---@param anchor SetsCrumbsAnchor
local function drawCrumbs(anchor)
	anchor.crumbs, anchor.fleurons = anchor.crumbs or {}, anchor.fleurons or {}
	local x = 0
	local crumbs = ns.BoardCrumbs()
	for i, data in ipairs(crumbs) do
		if i > 1 then
			local fleuron = ns.BoardPooled(anchor.fleurons, i - 1, function()
				return ns.NewBoardMark(anchor, "fleuron", FLEURON)
			end)
			fleuron:ClearAllPoints()
			fleuron:SetPoint("LEFT", x + FLEURON_ROOM, 0)
			x = x + FLEURON + 2 * FLEURON_ROOM
		end
		local crumb = ns.BoardPooled(anchor.crumbs, i, function()
			local made = CreateFrame("Button", nil, anchor) --[[@as SetsCrumb]]
			made.label = ns.BoardText(made, ns.BoardFonts().crumb, LOOK.gilt)
			made.label:SetPoint("LEFT")
			made:SetScript("OnEnter", function(self)
				self.label:SetTextColor(LOOK.giltBright[1], LOOK.giltBright[2], LOOK.giltBright[3])
			end)
			made:SetScript("OnLeave", function(self)
				self.label:SetTextColor(LOOK.gilt[1], LOOK.gilt[2], LOOK.gilt[3])
			end)
			return made
		end)
		crumb.label:SetText(data.text)
		local width = crumb.label:GetStringWidth()
		crumb:SetSize(width, anchor:GetHeight())
		crumb:ClearAllPoints()
		crumb:SetPoint("LEFT", x, 0)
		x = x + width
		crumb:SetScript("OnClick", function()
			ns.board:Open(data.place)
		end)
	end
	ns.BoardHideFrom(anchor.crumbs, #crumbs)
	ns.BoardHideFrom(anchor.fleurons, #crumbs - 1)
end

---@class SetsPlate: BoardPlateView
---@field lines string[]   -- its tooltip's lines: its words, then each earned title

---@class SetsNameplateAnchor: Frame
---@field plate SetsPlate

-- The gold nameplate on the cover's corner (HNT-R61), with each earned title and its full date in its tooltip.
---@param anchor SetsNameplateAnchor
local function drawNameplate(anchor)
	if not anchor.plate then
		local plate = ns.NewBoardPlate(anchor) --[[@as SetsPlate]]
		plate:SetPoint("BOTTOMLEFT")
		plate:EnableMouse(true)
		plate:SetScript("OnEnter", function(self)
			if #self.lines > 1 then
				ns.BoardTooltip(self, self.lines)
			end
		end)
		plate:SetScript("OnLeave", hideTooltip)
		anchor.plate = plate
	end
	local data = ns.BoardNameplate()
	anchor.plate:SetPlate(data.text)
	anchor.plate.lines = { data.text, unpack(data.titles) }
end

ns.board:RegisterLeather("ribbons", drawRibbons)
ns.board:RegisterLeather("crumbs", drawCrumbs)
ns.board:RegisterLeather("nameplate", drawNameplate)

-- The set page's layout (variant E): the seal's size, the bar's height, a checklist line's height, its diamond and
-- the dots of its leaders.
local SEAL, BAR_HEIGHT, LINE_HEIGHT, DIAMOND, DOT, DOT_STEP = 72, 10, 20, 12, 1.5, 4

---@class SetsLine: Button
---@field diamond BoardDiamondView
---@field name FontString
---@field when FontString
---@field dots Texture[]

---@class SetsPageView
---@field seal BoardSealView
---@field name FontString
---@field titleLine FontString
---@field bar BoardInkBarView
---@field line FontString
---@field note FontString
---@field lines SetsLine[]
---@field heading FontString
---@field retired SetsLine[]

---@class SetsPage: Frame
---@field view SetsPageView?

-- A checklist line on `page`, `width` wide: its diamond (filled bronze once done, HNT-R17), its name, its dotted
-- leaders and its date or label.
---@param page Frame
---@param width number
---@return SetsLine
local function newLine(page, width)
	local fonts = ns.BoardFonts()
	local line = CreateFrame("Button", nil, page) --[[@as SetsLine]]
	line:SetSize(width, LINE_HEIGHT)
	line.diamond = ns.NewBoardDiamond(line, DIAMOND)
	line.diamond:SetPoint("LEFT")
	line.name = ns.BoardText(line, fonts.text, LOOK.title)
	line.name:SetPoint("LEFT", DIAMOND + 6, 0)
	line.when = ns.BoardText(line, fonts.margin, LOOK.red)
	line.when:SetPoint("RIGHT")
	line.when:SetJustifyH("RIGHT")
	line.dots = {}
	line:SetScript("OnEnter", function(self)
		self.name:SetTextColor(LOOK.red[1], LOOK.red[2], LOOK.red[3])
	end)
	return line
end

-- Fills `line` from `data`, greyed or not, and lays its leaders between its name and its date or label.
---@param line SetsLine
---@param data SetPageLine
---@param greyed boolean
local function fillLine(line, data, greyed)
	local ink = greyed and LOOK.faded or LOOK.title
	line.diamond:SetDiamond(ns.Trim(1), data.done)
	line.name:SetText(data.name)
	line.name:SetTextColor(ink[1], ink[2], ink[3])
	line.when:SetText(data.when)
	line:SetAlpha(greyed and 0.6 or 1)
	line:SetScript("OnLeave", function(self)
		self.name:SetTextColor(ink[1], ink[2], ink[3])
	end)
	line:SetScript("OnClick", function()
		ns.board:Open(data.place)
	end)
	local from = DIAMOND + 6 + line.name:GetStringWidth() + DOT_STEP
	local to = line:GetWidth() - line.when:GetStringWidth() - DOT_STEP
	local count = math.max(0, math.floor((to - from) / DOT_STEP))
	for i = 1, count do
		local dot = ns.BoardPooled(line.dots, i, function()
			return ns.BoardSolid(line, LOOK.note, "ARTWORK")
		end)
		dot:ClearAllPoints()
		dot:SetSize(DOT, DOT)
		dot:SetPoint("BOTTOMLEFT", from + (i - 1) * DOT_STEP, 5)
	end
	ns.BoardHideFrom(line.dots, count)
end

-- The set page's widgets on `page`, made once.
---@param page SetsPage
---@return SetsPageView
local function viewOf(page)
	if page.view then
		return page.view
	end
	local fonts, width = ns.BoardFonts(), page:GetWidth()
	local view = {}
	view.seal = ns.NewBoardSeal(page, SEAL)
	view.seal:SetPoint("TOPRIGHT", 0, 0)
	view.name = ns.BoardText(page, fonts.title, LOOK.title)
	view.name:SetPoint("TOPLEFT", 0, 0)
	view.name:SetWidth(width - SEAL - 8)
	view.titleLine = ns.BoardText(page, fonts.hand, LOOK.hand)
	view.titleLine:SetPoint("TOPLEFT", 0, -32)
	view.titleLine:SetWidth(width - SEAL - 8)
	view.bar = ns.NewBoardInkBar(page, width - SEAL, BAR_HEIGHT)
	view.bar:SetPoint("TOPLEFT", 0, -SEAL - 8)
	view.line = ns.BoardText(page, fonts.small, LOOK.note)
	view.line:SetPoint("TOPLEFT", 0, -SEAL - 8 - BAR_HEIGHT - 8)
	view.line:SetWidth(width)
	view.note = ns.BoardText(page, fonts.small, LOOK.small)
	view.note:SetPoint("TOPLEFT", view.line, "BOTTOMLEFT", 0, -4)
	view.note:SetWidth(width)
	view.lines, view.retired = {}, {}
	view.heading = ns.BoardText(page, fonts.kicker, LOOK.kicker)
	page.view = view
	return view
end

-- The right side of a set's page (HNT-R66): the seal once its title is earned, its name and title line, the progress
-- bar, the line and its note, the checklist of its current Hunts, then its done Retired Hunts under "Retired",
-- greyed. Clicking a Hunt opens its entry or retired entry.
---@param page SetsPage
---@param place BoardPlace
local function drawSetPage(page, place)
	local view = viewOf(page)
	local data = ns.BoardSetPage(place.set --[[@as string]])
	view.seal:SetShown(data.seal ~= nil)
	view.seal:SetSeal(data.seal or "", true)
	view.name:SetText(data.name)
	view.titleLine:SetText(data.titleLine)
	view.bar:SetBar(data.progress.fill, data.progress.label)
	view.line:SetText(data.line)
	view.note:SetText(data.note or "")
	local width = page:GetWidth()
	local y = SEAL + 8 + BAR_HEIGHT + 8 + 2 * 18 + 12
	for i, lineData in ipairs(data.hunts) do
		local line = ns.BoardPooled(view.lines, i, function()
			return newLine(page, width)
		end)
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", 0, -y)
		fillLine(line, lineData, false)
		y = y + LINE_HEIGHT
	end
	ns.BoardHideFrom(view.lines, #data.hunts)
	view.heading:SetShown(#data.retired > 0)
	view.heading:SetText(ns.BoardSmallCaps(data.retiredHeading))
	view.heading:ClearAllPoints()
	view.heading:SetPoint("TOPLEFT", 0, -(y + 10))
	y = y + 10 + 16
	for i, lineData in ipairs(data.retired) do
		local line = ns.BoardPooled(view.retired, i, function()
			return newLine(page, width)
		end)
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", 0, -y)
		fillLine(line, lineData, true)
		y = y + LINE_HEIGHT
	end
	ns.BoardHideFrom(view.retired, #data.retired)
end

ns.board:RegisterPage("set", "right", drawSetPage)
