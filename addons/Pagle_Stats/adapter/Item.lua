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

-- Variant D's measures: the facts' rows and the gaps.
local FACT_HEIGHT = 20
local KICKER_GAP, TITLE_HEIGHT, PARA_GAP, GROUP_GAP = 18, 32, 8, 14

---@class StatsItemFactsView
---@field kicker FontString
---@field name StatsBookItemTitleView
---@field bites FontString
---@field facts StatsBookLineView[]
---@field here StatsBookHeadingView
---@field hereText FontString
---@field open StatsBookLinkView

---@class StatsItemWatersView
---@field kicker FontString
---@field title FontString
---@field empty FontString
---@field grid StatsBookTileGridView

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

---@param content StatsItemContent
---@return StatsItemFactsView
local function buildFacts(content)
	local width = content:GetWidth()
	local view = {
		kicker = ns.NewBookKicker(content),
		name = ns.NewBookItemTitle(content, width),
		bites = ns.BookText(content, ns.BookFonts().small, LOOK.small),
		facts = {
			ns.NewBookLine(content, width),
			ns.NewBookLine(content, width),
			ns.NewBookLine(content, width),
		},
		here = ns.NewBookHeading(content, width),
		hereText = ns.NewBookHand(content),
		open = ns.NewBookLink(content),
	}
	view.kicker:SetText(L.ITEM_KICKER)
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
	local data = ns.ItemFacts(ns.State(), item, Pagle.GetConditions(), GetServerTime(), ns.places)
	at(view.kicker, content, 0)
	view.name:SetItem(item, KICKER_GAP)
	local y = KICKER_GAP + TITLE_HEIGHT + PARA_GAP
	local lines = {}
	lines[#lines + 1] = data.bites
	lines[#lines + 1] = data.pool
	view.bites:SetText(table.concat(lines, L.SENTENCE_JOIN))
	view.bites:SetShown(#lines > 0)
	if #lines > 0 then
		at(view.bites, content, y)
		y = y + view.bites:GetStringHeight() + PARA_GAP
	end
	for i, fact in ipairs({
		{ label = L.ITEM_CAUGHT, value = data.caught },
		{ label = L.ITEM_FIRST_CAUGHT, value = data.first },
		{ label = L.ITEM_LAST_CAUGHT, value = data.last },
	}) do
		view.facts[i]:SetLine(fact)
		at(view.facts[i], content, y)
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
		grid = ns.NewBookTileGrid(content),
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
	at(view.kicker, content, 0)
	at(view.title, content, KICKER_GAP)
	local y = KICKER_GAP + TITLE_HEIGHT + GROUP_GAP
	view.empty:SetText(data.empty or "")
	view.empty:SetShown(data.empty ~= nil)
	at(view.empty, content, y)
	local height = view.grid:SetTiles(data.tiles, y)
	return y + (height > 0 and height or view.empty:GetStringHeight())
end

ns.book:RegisterPage("item", "left", drawFacts)
ns.book:RegisterPage("item", "right", drawWaters)
