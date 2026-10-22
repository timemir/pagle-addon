if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Sets on the Hunts board (HNT-R61, HNT-R66, HNT-R69): gathers logic/Sets.lua's inputs from the Hunt list, the
-- projection and the grouping, and draws its results on the board: the set ribbons, the breadcrumbs and the nameplate
-- on the leather's anchors, and the right side of a set's page (the set mode's right page). The look is the books art
-- kit's (adapter/BoardWidgets.lua): grosgrain ribbons hanging from under the leather, gilt crumbs with the kit's
-- fleuron, the brass nameplate; the kit lays out no set page, so it is set in the entry's parts (the wax seal, the
-- ink bar, the tier marks, the kit's faces).

-- The time the sets' views judge "current" and count the checklist's labels down at: now, or the grouping's while it
-- is paused, so they freeze with it (HNT-R43).
---@return integer
local function viewTime()
	return ns.ViewNow()
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
	return ns.BuildCrumbs(ns.board:Trail(), ns.hunts, ns.BoardRunName)
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

-- The fleuron's size and the room round it.
local FLEURON, FLEURON_ROOM = 16, 8

local function hideTooltip()
	GameTooltip:Hide()
end

---@class SetsRibbonsAnchor: Frame
---@field ribbons BoardRibbonView[]

-- The set ribbons hanging from under the leather's foot (HNT-R61): Board, then each set's with its full name, in its
-- colour, the one of the mode shown hanging longer. Clicking one opens its place; each shows its full name on hover.
---@param anchor SetsRibbonsAnchor
---@param place BoardPlace
local function drawRibbons(anchor, place)
	anchor.ribbons = anchor.ribbons or {}
	local sizes = ns.BOARD_RIBBON
	local ribbons = ns.BoardRibbons(place)
	for i, data in ipairs(ribbons) do
		local ribbon = ns.BoardPooled(anchor.ribbons, i, function()
			return ns.NewBoardRibbon(anchor)
		end)
		local color = data.set and ns.BoardRibbonColor(data.index) or LOOK.boardRibbon
		ribbon:SetRibbon(data.name or data.text, color, data.chosen, true)
		ribbon.tooltip = { data.name or data.text }
		ribbon:ClearAllPoints()
		ribbon:SetPoint("TOPLEFT", (i - 1) * (sizes.width + sizes.gap), 0)
		ribbon:SetScript("OnClick", function()
			ns.board:Open(data.place)
		end)
	end
	ns.BoardHideFrom(anchor.ribbons, #ribbons)
end

---@class SetsCrumb: Button
---@field label FontString

---@class SetsCrumbsAnchor: Frame
---@field crumbs SetsCrumb[]
---@field fleurons Texture[]

-- The gilt breadcrumbs (HNT-R61): "Hunts", the set, the Hunt (or "Pagle Wagers" and the run's event, HNT-R164), the
-- kit's fleuron between each, each going back up.
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
			made.label:SetWordWrap(false)
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
		-- the last crumbs are cut short, never past the strip's room before the clock
		crumb.label:SetWidth(0)
		local width = math.max(1, math.min(crumb.label:GetStringWidth(), anchor:GetWidth() - x))
		crumb.label:SetWidth(width)
		crumb:SetSize(width, anchor:GetHeight())
		crumb:ClearAllPoints()
		crumb:SetPoint("LEFT", x, 0)
		x = x + width
		crumb:SetScript("OnClick", function()
			if data.place then
				ns.board:Open(data.place)
			else
				ns.OpenWagers(data.run) -- "Pagle Wagers" goes to its spread (HNT-R164, #303)
			end
		end)
	end
	ns.BoardHideFrom(anchor.crumbs, #crumbs)
	ns.BoardHideFrom(anchor.fleurons, #crumbs - 1)
end

---@class SetsPlate: BoardPlateView
---@field lines string[]   -- its tooltip's lines: its words, then each earned title

---@class SetsNameplateAnchor: Frame
---@field plate SetsPlate

-- The brass nameplate on the cover's corner (HNT-R61), with each earned title and its full date in its tooltip.
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

-- The set page's layout, the books kit v2's "Set" board (UI units down the page's body): the kicker and the name, the
-- seal's size and where its centre sits from the page's top right, the title line's width beside it, the ink bar's
-- width and its words, the checklist's heading and rule, a checklist line's step, its tick's room, and its leaders.
local KICKER_Y, NAME_Y, TITLE_Y = 3, 19, 55
local SEAL, SEAL_RIGHT, SEAL_DOWN, TITLE_WIDTH, BAR_WIDTH, BAR_Y = 88, 38.5, 40, 227, 238, 118
local HEADING_GAP, RULE_GAP, LIST_GAP = 18, 18, 10
local LINE_HEIGHT, TICK_ROOM, DOT, DOT_STEP, GAP = 28, 22, 1.5, 4, 8

---@class SetsLine: Button
---@field tick HuntsSpriteTexture
---@field name FontString
---@field when FontString
---@field dots Texture[]

---@class SetsPageView
---@field kicker FontString
---@field seal BoardSealView
---@field name FontString
---@field titleLine FontString
---@field bar BoardInkBarView
---@field line FontString
---@field note FontString
---@field listHeading FontString
---@field rule Texture
---@field lines SetsLine[]
---@field heading FontString
---@field retired SetsLine[]

---@class SetsPage: Frame
---@field view SetsPageView?

-- A checklist line on `page`, `width` wide: the kit's tick once done (HNT-R17), its name, its dotted leaders and its
-- date or state in the hand at the right.
---@param page Frame
---@param width number
---@return SetsLine
local function newLine(page, width)
	local line = CreateFrame("Button", nil, page) --[[@as SetsLine]]
	line:SetSize(width, LINE_HEIGHT)
	line.tick = ns.ArtSprite(line, "Hunts", "tick", "ARTWORK")
	ns.PlaceSprite(line.tick, line, 0, 0)
	line.name = ns.BoardText(line, ns.ArtFont("print", 15), LOOK.ink)
	line.name:SetWordWrap(false)
	line.name:SetPoint("TOPLEFT", TICK_ROOM, -1)
	line.when = ns.BoardText(line, ns.ArtFont("hand", 18), LOOK.group)
	line.when:SetPoint("TOPRIGHT", 0, 0)
	line.when:SetJustifyH("RIGHT")
	line.when:SetWordWrap(false)
	line.dots = {}
	line:SetScript("OnEnter", function(self)
		self.name:SetTextColor(LOOK.red[1], LOOK.red[2], LOOK.red[3])
	end)
	return line
end

-- A Hunt not yet done: its state in the margin's red-brown (the kit's #7a3a10).
local OPEN_INK = ns.BoardTint("7a3a10")

-- Fills `line` from `data`, greyed or not, and lays its leaders between its name and its date or state.
---@param line SetsLine
---@param data SetPageLine
---@param greyed boolean
local function fillLine(line, data, greyed)
	local ink = greyed and LOOK.faded or LOOK.ink
	line.tick:SetShown(data.done)
	line.name:SetText(data.name)
	line.name:SetTextColor(ink[1], ink[2], ink[3])
	line.when:SetText(data.when)
	local whenInk = greyed and LOOK.faded or data.done and LOOK.group or OPEN_INK
	line.when:SetTextColor(whenInk[1], whenInk[2], whenInk[3])
	line:SetAlpha(greyed and 0.6 or 1)
	line:SetScript("OnLeave", function(self)
		self.name:SetTextColor(ink[1], ink[2], ink[3])
	end)
	line:SetScript("OnClick", function()
		ns.board:Open(data.place)
	end)
	-- the date or state keeps to the right half at most; the name stops before it, cut short with an ellipsis when it
	-- must
	local width = line:GetWidth()
	line.when:SetWidth(0)
	local whenWidth = math.min(line.when:GetStringWidth() + 1, width / 2)
	line.when:SetWidth(whenWidth)
	line.name:SetWidth(0)
	local room = width - TICK_ROOM - whenWidth - 2 * DOT_STEP
	local nameWidth = math.min(line.name:GetStringWidth() + 1, room)
	line.name:SetWidth(math.max(1, nameWidth))
	local from = TICK_ROOM + nameWidth + DOT_STEP
	local to = width - whenWidth - DOT_STEP
	local count = math.max(0, math.floor((to - from) / DOT_STEP))
	for i = 1, count do
		local dot = ns.BoardPooled(line.dots, i, function()
			return ns.BoardSolid(line, LOOK.note, "ARTWORK")
		end)
		dot:ClearAllPoints()
		dot:SetSize(DOT, DOT)
		dot:SetPoint("TOPLEFT", from + (i - 1) * DOT_STEP, -12)
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
	view.kicker = ns.BoardText(page, fonts.kicker, LOOK.kicker)
	view.kicker:SetText(ns.BoardSmallCaps(ns.L.SET_KICKER))
	view.kicker:SetPoint("TOPLEFT", 0, -KICKER_Y)
	view.seal = ns.NewBoardSeal(page, SEAL)
	view.seal:SetPoint("CENTER", page, "TOPLEFT", width - SEAL_RIGHT, -SEAL_DOWN)
	view.name = ns.BoardText(page, fonts.title, LOOK.title)
	view.name:SetPoint("TOPLEFT", 0, -NAME_Y)
	view.name:SetWidth(width - 2 * SEAL_RIGHT)
	view.name:SetWordWrap(false)
	view.titleLine = ns.BoardText(page, ns.ArtFont("hand", 21), LOOK.hand)
	ns.BoardWrap(view.titleLine, TITLE_WIDTH, 2)
	view.bar = ns.NewBoardInkBar(page, BAR_WIDTH)
	view.bar.label:SetWidth(width - BAR_WIDTH - 10)
	view.bar.label:SetWordWrap(false)
	view.line = ns.BoardText(page, fonts.note, LOOK.count)
	ns.BoardWrap(view.line, width, 4)
	view.note = ns.BoardText(page, fonts.note, LOOK.count)
	ns.BoardWrap(view.note, width, 4)
	view.listHeading = ns.BoardText(page, ns.ArtFont("print", 12.5), LOOK.kicker)
	view.listHeading:SetText(ns.BoardSmallCaps(ns.L.SET_HUNTS_HEADING))
	view.rule = ns.BoardSolid(page, LOOK.rule, "ARTWORK")
	view.rule:ClearAllPoints()
	view.rule:SetSize(width, 1)
	view.lines, view.retired = {}, {}
	view.heading = ns.BoardText(page, fonts.kicker, LOOK.kicker)
	page.view = view
	return view
end

-- Places `region`'s top left `y` down the page, and returns the y under it.
---@param region Region
---@param y number
---@param height number
---@return number
local function put(region, y, height)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", 0, -y)
	return y + height
end

-- The right side of a set's page (HNT-R66), as the kit v2 lays it: the kicker, the name and the seal (pressed with
-- the date once its title is earned, the dashed "not yet" before), the title line in the hand, the progress bar, the
-- line and the set's note, then "Hunts in this set" over a rule and the checklist of its current Hunts, then its done
-- Retired Hunts under "Retired", greyed. Clicking a Hunt opens its entry or retired entry. Each block sits under the one
-- before, so a long note pushes the checklist down.
---@param page SetsPage
---@param place BoardPlace
local function drawSetPage(page, place)
	local view = viewOf(page)
	local data = ns.BoardSetPage(place.set --[[@as string]])
	view.seal:SetSeal(data.seal or ns.L.SEAL_NOT_YET, data.seal ~= nil, data.sealLines)
	view.name:SetText(data.name)
	view.titleLine:SetText(data.titleLine)
	local y = put(view.titleLine, TITLE_Y, view.titleLine:GetStringHeight())
	y = math.max(y + GAP, BAR_Y)
	view.bar:SetBar(data.progress.fill, data.progress.label)
	y = put(view.bar, y, 22)
	view.line:SetText(data.line)
	y = put(view.line, y, view.line:GetStringHeight())
	view.note:SetText(data.note or "")
	view.note:SetShown(data.note ~= nil)
	if data.note then
		y = put(view.note, y + 4, view.note:GetStringHeight())
	end
	y = put(view.listHeading, y + HEADING_GAP, RULE_GAP)
	y = put(view.rule, y, LIST_GAP)
	local width = page:GetWidth()
	for i, lineData in ipairs(data.hunts) do
		local line = ns.BoardPooled(view.lines, i, function()
			return newLine(page, width)
		end)
		y = put(line, y, LINE_HEIGHT)
		fillLine(line, lineData, false)
	end
	ns.BoardHideFrom(view.lines, #data.hunts)
	view.heading:SetShown(#data.retired > 0)
	view.heading:SetText(ns.BoardSmallCaps(data.retiredHeading))
	y = put(view.heading, y + 10, 18)
	for i, lineData in ipairs(data.retired) do
		local line = ns.BoardPooled(view.retired, i, function()
			return newLine(page, width)
		end)
		y = put(line, y, LINE_HEIGHT)
		fillLine(line, lineData, true)
	end
	ns.BoardHideFrom(view.retired, #data.retired)
end

ns.board:RegisterPage("set", "right", drawSetPage)
