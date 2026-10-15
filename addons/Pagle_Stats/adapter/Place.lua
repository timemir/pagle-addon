if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- A place's page in the Stats book (stats.md › UI › Place spread; STA-R17, STA-R18, STA-R42, STA-R96): the left page
-- with the place's name, my Casts there and its no-junk sentence, a zone's waters, and its rows in their groups, each
-- row with ★ when watched, its short odds and its Dry spell in the margin; and the right page before an item is
-- chosen, the place's own numbers. Clicking a row chooses its item (STA-R74), and the right page then shows the item's
-- entry, drawn by the renderer registered with ns.RegisterPlaceEntry (#214). The rules are logic/Groups.lua's.
--
-- Every line of a page is anchored by its top left at its depth down the page, so the page lays out top to bottom.

local L = ns.L
local LOOK = ns.BOOK_LOOK

-- Heights and gaps down a page, in pixels: a kicker's line, a title's line, the gap before a heading, a heading, a
-- row, a short list's line, and the gap after a paragraph.
local KICKER, TITLE, HEADING_GAP, HEADING, ROW, LINE, PARAGRAPH = 16, 32, 12, 22, 24, 20, 6

-- A pool of one kind of block on a page, made on first use and reused at each draw.
---@class StatsPlacePool
---@field made Frame[]
---@field used integer
---@field make fun(): Frame

---@param make fun(): Frame
---@return StatsPlacePool
local function newPool(make)
	return { made = {}, used = 0, make = make }
end

-- The pool's next block, made if it has none spare.
---@param pool StatsPlacePool
---@return Frame
local function take(pool)
	pool.used = pool.used + 1
	local block = pool.made[pool.used]
	if not block then
		block = pool.make()
		pool.made[pool.used] = block
	end
	return block
end

-- Hides every block of the pool, before a draw takes what it needs again.
---@param pool StatsPlacePool
local function reset(pool)
	for _, block in ipairs(pool.made) do
		block:Hide()
	end
	pool.used = 0
end

-- Shows `block` at depth `y` down its page.
---@param block Frame|FontString
---@param y number
local function put(block, y)
	block:ClearAllPoints()
	block:SetPoint("TOPLEFT", 0, -y)
	block:Show()
end

-- A place's zone: its projection record's `zone`, else the catalogue's, else the place itself, as Your odds reads it.
---@param state StatsState
---@param area integer
---@return integer
local function zoneOf(state, area)
	local record = state.places[area]
	return record and record.zone or Pagle.GetZoneOf(area) or area
end

-- An item's quality: Core's record's, else the client's for an Uncharted item it has described; nil for none known.
---@param item integer
---@return integer?
local function qualityOf(item)
	local record = Pagle.GetItem(item)
	if record and record.quality ~= nil then
		return record.quality
	end
	return C_Item.GetItemQualityByID(item)
end

---@class StatsPlaceLeftView
---@field kicker FontString
---@field titleLine Frame
---@field title FontString
---@field here FontString
---@field casts FontString
---@field noChart FontString
---@field across FontString
---@field headings StatsPlacePool
---@field rows StatsPlacePool
---@field lines StatsPlacePool

---@class StatsPlaceRightView
---@field numbers Frame
---@field entry Frame
---@field kicker FontString
---@field title FontString
---@field casts StatsBookLineView
---@field catches StatsBookLineView
---@field gotAway StatsBookLineView
---@field pick FontString

-- Each content frame's view, made at its first draw.
---@type table<Frame, StatsPlaceLeftView>
local lefts = setmetatable({}, { __mode = "k" })
---@type table<Frame, StatsPlaceRightView>
local rights = setmetatable({}, { __mode = "k" })

-- The left page's widgets on `content`.
---@param content Frame
---@return StatsPlaceLeftView
local function leftView(content)
	local view = lefts[content]
	if view then
		return view
	end
	local width, faces = content:GetWidth(), ns.BookFonts()
	local function paragraph(font, color)
		local text = ns.BookText(content, font, color)
		text:SetWidth(width)
		text:SetWordWrap(true)
		return text
	end
	local kicker = ns.NewBookKicker(content)
	local titleLine = CreateFrame("Frame", nil, content)
	titleLine:SetSize(width, TITLE)
	local title = ns.NewBookTitle(titleLine)
	title:SetPoint("LEFT", 0, 0)
	local here = ns.BookText(titleLine, faces.hand, LOOK.green)
	here:SetPoint("LEFT", title, "RIGHT", 10, 0)
	here:SetText(L.PLACE_HERE)
	local casts = paragraph(faces.small, LOOK.small)
	local noChart = paragraph(faces.small, LOOK.small)
	noChart:SetText(L.PLACE_NO_CHART)
	view = {
		kicker = kicker,
		titleLine = titleLine,
		title = title,
		here = here,
		casts = casts,
		noChart = noChart,
		across = paragraph(faces.note, LOOK.note),
		headings = newPool(function()
			return ns.NewBookHeading(content, width)
		end),
		rows = newPool(function()
			return ns.NewBookRow(content, width)
		end),
		lines = newPool(function()
			return ns.NewBookLine(content, width)
		end),
	}
	lefts[content] = view
	return view
end

-- A heading at depth `y`, after its gap; returns the depth under it.
---@param view StatsPlaceLeftView
---@param y number
---@param text string
---@param note string
---@return number
local function heading(view, y, text, note)
	local block = take(view.headings) --[[@as StatsBookHeadingView]]
	block:SetHeading(text, note)
	put(block, y + HEADING_GAP)
	return y + HEADING_GAP + HEADING
end

-- *Its waters* on a zone's page (UI › Place spread): every subzone with its own list or my Casts, alphabetical, with my
-- Casts ("—" for none) and "I'm here", each opening its page. Nothing when it has none. Returns the depth under it.
---@param view StatsPlaceLeftView
---@param y number
---@param state StatsState
---@param zone integer
---@param conditions ConditionsSnapshot
---@return number
local function drawWaters(view, y, state, zone, conditions)
	local waters = ns.PlaceWaters(state, zone, Pagle --[[@as StatsLookups]])
	if #waters == 0 then
		return y
	end
	y = heading(view, y, L.PLACE_WATERS, L.PLACE_WATERS_NOTE)
	for _, water in ipairs(waters) do
		local line = take(view.lines) --[[@as StatsBookLineView]]
		local area = water.area
		line:SetLine({
			label = water.name,
			value = water.casts and ns.Number(water.casts) or L.PLACE_NONE,
			here = conditions.subzone == area and L.PLACE_HERE or nil,
			onClick = function()
				ns.OpenBook({ page = "place", area = area })
			end,
		})
		put(line, y)
		y = y + LINE
	end
	return y
end

-- One row (UI › Place spread): its icon and name (asking the client for an item it hasn't loaded, STA-R73), ★ when
-- watched from this place, the short odds and the margin's Dry spell; clicking it chooses the item.
---@param row StatsBookRowView
---@param reading StatsReading
---@param area integer
---@param chosen boolean
local function drawRow(row, reading, area, chosen)
	local item = reading.item
	local name, icon, loaded = ns.Item(item)
	if not loaded then
		ns.book:RequestItem(item)
	end
	local margin, band = ns.DrySpellShort(reading)
	row:SetRow({
		icon = icon,
		name = name,
		ink = ns.BookQualityInk(qualityOf(item)),
		watched = ns.IsWatched(item, area),
		odds = ns.OddsShort(reading),
		oddsState = reading.state,
		margin = margin,
		band = band,
		chosen = chosen,
		onClick = function()
			ns.OpenBook({ page = "place", area = area, item = item })
		end,
	})
end

--- Draws a place's left page (UI › Place spread) on `content`.
---@param content Frame
---@param place StatsBookTarget
---@return number height
local function drawLeft(content, place)
	local area = place.area --[[@as integer]]
	local state = ns.State()
	local zone = zoneOf(state, area)
	local isZone = zone == area
	local conditions = Pagle.GetConditions()
	local live = ns.EffectiveSkill(conditions)
	local view = leftView(content)
	reset(view.headings)
	reset(view.rows)
	reset(view.lines)

	view.kicker:SetText(isZone and L.PLACE_ZONE_KICKER or ns.AreaName(zone))
	put(view.kicker, 0)
	view.title:SetText(ns.AreaName(area))
	view.here:SetShown((isZone and conditions.zone or conditions.subzone) == area)
	put(view.titleLine, KICKER)
	local y = KICKER + TITLE

	local record = state.places[area]
	local text = L.PLACE_CASTS:format(ns.Number(record and record.casts or 0))
	local sentence = ns.NoJunkSentence(area, live)
	view.casts:SetText(sentence and (text .. " " .. sentence) or text)
	put(view.casts, y)
	y = y + view.casts:GetStringHeight() + PARAGRAPH
	local chart = Pagle.GetArea(area)
	if chart and chart.hasData then
		view.noChart:Hide()
	else
		put(view.noChart, y)
		y = y + view.noChart:GetStringHeight() + PARAGRAPH
	end

	if isZone then
		y = drawWaters(view, y, state, zone, conditions)
	end
	local groups = ns.Groups(state, area, live)
	for _, group in ipairs(groups) do
		y = heading(view, y, group.heading, group.note)
		for _, reading in ipairs(group.readings) do
			local row = take(view.rows) --[[@as StatsBookRowView]]
			drawRow(row, reading, area, reading.item == place.item)
			put(row, y)
			y = y + ROW
		end
	end

	if not isZone and ns.ReadsAcrossZone(groups) then
		view.across:SetText(L.PLACE_ACROSS_ZONE:format(ns.ODDS_THRESHOLD, ns.AreaName(area), ns.AreaName(zone)))
		y = y + HEADING_GAP
		put(view.across, y)
		y = y + view.across:GetStringHeight()
	else
		view.across:Hide()
	end
	return y + PARAGRAPH
end

-- The right page's widgets on `content`: the place's numbers, and a frame for the chosen item's entry.
---@param content Frame
---@return StatsPlaceRightView
local function rightView(content)
	local view = rights[content]
	if view then
		return view
	end
	local width = content:GetWidth()
	local numbers = CreateFrame("Frame", nil, content)
	numbers:SetAllPoints()
	local entry = CreateFrame("Frame", nil, content)
	entry:SetAllPoints()
	entry:SetWidth(width)
	local kicker = ns.NewBookKicker(numbers)
	kicker:SetText(L.PLACE_ABOUT)
	local title = ns.NewBookTitle(numbers)
	local casts = ns.NewBookLine(numbers, width)
	local catches = ns.NewBookLine(numbers, width)
	local gotAway = ns.NewBookLine(numbers, width)
	local pick = ns.NewBookHand(numbers)
	pick:SetWidth(width)
	pick:SetText(L.PLACE_PICK)
	view = {
		numbers = numbers,
		entry = entry,
		kicker = kicker,
		title = title,
		casts = casts,
		catches = catches,
		gotAway = gotAway,
		pick = pick,
	}
	rights[content] = view
	return view
end

-- The renderer of a chosen item's entry on the place page's right side (#214), if registered.
---@type StatsBookRenderer?
local entryRenderer

--- Registers `renderer` to draw the entry of the item chosen on a place's page (UI › Place spread, #214) on the right
--- page: it is given its own frame there, as wide as the page, and the place (`area`, `item`), and returns the height
--- it drew. A later registration replaces it. Until one is registered, the right page keeps the place's numbers.
---@param renderer StatsBookRenderer
function ns.RegisterPlaceEntry(renderer)
	assert(type(renderer) == "function", "a place entry's renderer is a function")
	entryRenderer = renderer
end

--- Draws a place's right page (UI › Place spread) on `content`: the chosen item's entry, or with none chosen "About
--- these waters": the place's Casts, Catches and Got away as "{n} ({rate}%)" ("—" before any Cast), and the hint.
---@param content Frame
---@param place StatsBookTarget
---@return number? height
local function drawRight(content, place)
	local view = rightView(content)
	if place.item and entryRenderer then
		view.numbers:Hide()
		view.entry:Show()
		return entryRenderer(view.entry, place)
	end
	view.entry:Hide()
	view.numbers:Show()
	local area = place.area --[[@as integer]]
	local record = ns.State().places[area]
	local casts, catches, gotAway = 0, 0, 0
	if record then
		casts, catches, gotAway = record.casts, record.catches, record.gotAway
	end
	put(view.kicker, 0)
	view.title:SetText(ns.AreaName(area))
	put(view.title, KICKER)
	local y = KICKER + TITLE + PARAGRAPH
	local rate = ns.GotAwayRate({ casts = casts, gotAway = gotAway })
	for _, line in ipairs({
		{ view.casts, L.PLACE_CASTS_LABEL, ns.Number(casts) },
		{ view.catches, L.PLACE_CATCHES_LABEL, ns.Number(catches) },
		{
			view.gotAway,
			L.PLACE_GOT_AWAY_LABEL,
			rate and L.PLACE_GOT_AWAY:format(ns.Number(gotAway), rate) or L.PLACE_NONE,
		},
	}) do
		line[1]:SetLine({ label = line[2], value = line[3] })
		put(line[1], y)
		y = y + LINE
	end
	y = y + 2 * PARAGRAPH
	put(view.pick, y)
	return y + view.pick:GetStringHeight() + PARAGRAPH
end

ns.book:RegisterPage("place", "left", drawLeft)
ns.book:RegisterPage("place", "right", drawRight)
