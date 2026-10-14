if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The item page on the Stats book (stats.md › UI › Item page): one fish, found by search or from an entry's "Every
-- water it bites in ☛". Its left page names it and says when it bites, what I've caught of it and how it stands where
-- I am; its right page tiles every water I've fished for it, each opening that place's page with it chosen. The lines
-- are logic/Item.lua's; this file lays them out in adapter/BookWidgets.lua's art, after prototypes/stats-window/
-- variant D. An item the client hasn't loaded is asked for, and the page redraws when it arrives (STA-R73).

local L = ns.L
local LOOK = ns.BOOK_LOOK

-- Variant D's measures: the title's icon, the facts' rows, two tiles a row as on the home spread, and the gaps.
local ICON_SIZE, ICON_GAP = 28, 8
local FACT_HEIGHT, TILE_HEIGHT, TILE_GAP = 20, 84, 9
local KICKER_GAP, TITLE_HEIGHT, PARA_GAP, GROUP_GAP = 18, 32, 8, 14

---@class StatsItemFactView: Frame
---@field label FontString
---@field value FontString

---@class StatsItemFactsView
---@field kicker FontString
---@field icon StatsBookIconView
---@field title FontString
---@field bites FontString
---@field facts StatsItemFactView[]
---@field here StatsBookHeadingView
---@field hereText FontString
---@field open StatsBookLinkView

---@class StatsItemWatersView
---@field kicker FontString
---@field title FontString
---@field empty FontString
---@field tiles StatsBookTileView[]

---@class StatsItemContent: Frame
---@field facts StatsItemFactsView?
---@field waters StatsItemWatersView?

-- Puts `region` at the top left of `content`, `x` across and `y` down.
---@param region Region
---@param content Frame
---@param y number
---@param x number?
local function at(region, content, y, x)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", content, "TOPLEFT", x or 0, -y)
end

-- A row of my records: its words at the left, its value at the right.
---@param content Frame
---@param label string
---@return StatsItemFactView
local function newFact(content, label)
	local fact = CreateFrame("Frame", nil, content) --[[@as StatsItemFactView]]
	fact:SetSize(content:GetWidth(), FACT_HEIGHT)
	fact.label = ns.BookText(fact, ns.BookFonts().text, LOOK.ink)
	fact.label:SetPoint("LEFT")
	fact.label:SetText(label)
	fact.value = ns.BookText(fact, ns.BookFonts().text, LOOK.ink)
	fact.value:SetPoint("RIGHT")
	fact.value:SetJustifyH("RIGHT")
	return fact
end

---@param content StatsItemContent
---@return StatsItemFactsView
local function buildFacts(content)
	local width = content:GetWidth()
	local view = {
		kicker = ns.NewBookKicker(content),
		icon = ns.NewBookIcon(content, ICON_SIZE),
		title = ns.NewBookTitle(content),
		bites = ns.BookText(content, ns.BookFonts().small, LOOK.small),
		facts = {
			newFact(content, L.ITEM_CAUGHT),
			newFact(content, L.ITEM_FIRST_CAUGHT),
			newFact(content, L.ITEM_LAST_CAUGHT),
		},
		here = ns.NewBookHeading(content, width),
		hereText = ns.NewBookHand(content),
		open = ns.NewBookLink(content),
	}
	view.kicker:SetText(L.ITEM_KICKER)
	view.title:SetWidth(width - ICON_SIZE - ICON_GAP)
	view.bites:SetWordWrap(true)
	view.bites:SetWidth(width)
	view.hereText:SetWidth(width)
	content.facts = view
	return view
end

--- The left page: kicker "A fish", the icon and name, when it bites and the pool line, Caught, First caught and Last
--- caught, then *Where I am* with its line and "Open its page here ☛" when the item is on the current place's rows.
---@param content StatsItemContent
---@param place StatsBookTarget
---@return number height
local function drawFacts(content, place)
	local view = content.facts or buildFacts(content)
	local item = place.item --[[@as integer]]
	local name, icon, loaded = ns.Item(item)
	if not loaded then
		ns.book:RequestItem(item)
	end
	local data = ns.ItemFacts(ns.State(), item, Pagle.GetConditions(), GetServerTime(), ns.places)
	at(view.kicker, content, 0)
	view.icon:SetIcon(icon)
	at(view.icon, content, KICKER_GAP)
	view.title:SetText(name)
	at(view.title, content, KICKER_GAP + 2, ICON_SIZE + ICON_GAP)
	local y = KICKER_GAP + TITLE_HEIGHT + PARA_GAP
	local lines = {}
	lines[#lines + 1] = data.bites
	lines[#lines + 1] = data.pool
	view.bites:SetText(table.concat(lines, " "))
	view.bites:SetShown(#lines > 0)
	if #lines > 0 then
		at(view.bites, content, y)
		y = y + view.bites:GetStringHeight() + PARA_GAP
	end
	for i, value in ipairs({ data.caught, data.first, data.last }) do
		local fact = view.facts[i]
		fact.value:SetText(value)
		at(fact, content, y)
		y = y + FACT_HEIGHT
	end
	local here = data.here
	view.here:SetShown(here ~= nil)
	view.hereText:SetShown(here ~= nil)
	view.open:SetShown(here ~= nil)
	if not here then
		return y
	end
	y = y + GROUP_GAP
	view.here:SetHeading(L.BOOK_WHERE_I_AM, here.place)
	at(view.here, content, y)
	y = y + view.here:GetHeight() + 4
	view.hereText:SetText(here.text)
	at(view.hereText, content, y)
	y = y + view.hereText:GetStringHeight() + 4
	local target = here.target
	view.open:SetLink(L.ITEM_OPEN_HERE, function()
		ns.OpenBook(target)
	end)
	at(view.open, content, y)
	return y + view.open:GetHeight()
end

---@param content StatsItemContent
---@return StatsItemWatersView
local function buildWaters(content)
	local width = content:GetWidth()
	local view = {
		kicker = ns.NewBookKicker(content),
		title = ns.NewBookTitle(content),
		empty = ns.NewBookHand(content),
		tiles = {},
	}
	view.kicker:SetText(L.ITEM_WATERS_KICKER)
	view.title:SetText(L.ITEM_WATERS_TITLE)
	for _, text in ipairs({ view.kicker, view.title, view.empty }) do
		text:SetWidth(width)
	end
	content.waters = view
	return view
end

--- The right page, Where I've fished for it: a tile per water, two a row, each opening that place's page with the
--- item chosen; with none, "I haven't fished anywhere it bites."
---@param content StatsItemContent
---@param place StatsBookTarget
---@return number height
local function drawWaters(content, place)
	local view = content.waters or buildWaters(content)
	local data = ns.ItemWaters(ns.State(), place.item --[[@as integer]], Pagle.GetConditions(), ns.places)
	local width = content:GetWidth()
	local tileWidth = (width - TILE_GAP) / 2
	at(view.kicker, content, 0)
	at(view.title, content, KICKER_GAP)
	local y = KICKER_GAP + TITLE_HEIGHT + GROUP_GAP
	view.empty:SetText(data.empty or "")
	view.empty:SetShown(data.empty ~= nil)
	at(view.empty, content, y)
	for i, tile in ipairs(data.tiles) do
		local tileView = view.tiles[i]
		if not tileView then
			tileView = ns.NewBookTile(content, tileWidth, TILE_HEIGHT)
			view.tiles[i] = tileView
		end
		local target = tile.target
		tileView:SetTile({
			name = tile.name,
			line = tile.line,
			here = tile.here,
			note = tile.note,
			onClick = function()
				ns.OpenBook(target)
			end,
		})
		local row, column = math.floor((i - 1) / 2), (i - 1) % 2
		at(tileView, content, y + row * (TILE_HEIGHT + TILE_GAP), column * (tileWidth + TILE_GAP))
		tileView:Show()
	end
	for i = #data.tiles + 1, #view.tiles do
		view.tiles[i]:Hide()
	end
	local rows = math.ceil(#data.tiles / 2)
	if rows == 0 then
		return y + view.empty:GetStringHeight()
	end
	return y + rows * TILE_HEIGHT + (rows - 1) * TILE_GAP
end

ns.book:RegisterPage("item", "left", drawFacts)
ns.book:RegisterPage("item", "right", drawWaters)
