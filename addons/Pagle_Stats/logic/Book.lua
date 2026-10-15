if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The Stats book's page router (STA-R70, STA-R74): pure logic, everything passed in (CORE-R7). The book shows one
-- page at a time, and the router decides which: the place it is on (a StatsBookTarget: the page and what is chosen
-- on it), which renderer draws each side of it, the breadcrumb trail back up, and where the ribbons go.
-- adapter/Book.lua draws what it decides on the book.
--
-- The pages, and the files whose renderers draw them (`ns.book:RegisterPage(page, side, renderer)`):
--   "home"      the home spread (adapter/Home.lua): where I've fished on the left, right now on the right
--   "place"     a place's page (`area`, a zone or subzone): its rows on the left (adapter/Place.lua); on the right,
--               its numbers, or the entry of the item chosen on it (`item`, adapter/Entry.lua)
--   "item"      an item's page (`item`; `area` when it was opened from a place): its waters (adapter/Item.lua)
--   "session"   This Session, the ribbon (adapter/Sessions.lua): the current Session, or My last Session
--   "lifetime"  Lifetime, the ribbon (adapter/Lifetime.lua)
--   "sessions"  Sessions, the ribbon (adapter/Sessions.lua): the ruled ledger at page `ledgerPage` (1 when nil, the
--               newest), and the chosen Session's entry (`session`, Core's Session ID; the newest when nil)
-- A page with no renderer for a side leaves that side blank.

---@alias StatsBookSide "left"|"right"

--- Draws one side of one page: `content` is that side's own frame inside the page's scrolling body, as wide as the
--- body; `place` is where the book is (a copy). It returns the height it drew, so the body scrolls when that overflows
--- (STA-R70); nil fits the body. Renderers never run while the projection is updating: the book then writes
--- "Updating my records…" on both sides itself (STA-R72).
---@alias StatsBookRenderer fun(content: Frame, place: StatsBookTarget): number?

--- One breadcrumb (STA-R74): what it names, and where it goes. adapter/Book.lua gives it its words: "Stats", the
--- area's or the item's name, the ribbon page's kicker.
---@class StatsBookCrumb
---@field kind "stats"|"zone"|"subzone"|"item"|"ribbon"
---@field id (integer|string)?          -- the area ID, the item ID, or the ribbon page ("session", …)
---@field target StatsBookTarget?        -- where it goes; nil for the item crumb on a place page, which does nothing

--- One ribbon (STA-R74, stats.md › UI › On the leather), top to bottom: its ID, the page it opens (nil for Where I
--- am, which goes where ns.WhereIAm says) and whether it is green.
---@class StatsBookRibbon
---@field id "here"|"session"|"lifetime"|"sessions"
---@field page StatsBookPage?
---@field green boolean

--- The book's pages and sides, in drawing order.
ns.BOOK_PAGES = { "home", "place", "item", "session", "lifetime", "sessions" }
ns.BOOK_SIDES = { "left", "right" }

---@type StatsBookRibbon[]
ns.BOOK_RIBBONS = {
	{ id = "here", green = true },
	{ id = "session", page = "session", green = false },
	{ id = "lifetime", page = "lifetime", green = false },
	{ id = "sessions", page = "sessions", green = false },
}

--- What each page keeps of a target besides its page, and what it can't do without.
---@type table<StatsBookPage, { keeps: string[], needs: string? }>
local PAGES = {
	home = { keeps = {} },
	place = { keeps = { "area", "item" }, needs = "area" },
	item = { keeps = { "item", "area" }, needs = "item" },
	session = { keeps = {} },
	lifetime = { keeps = {} },
	sessions = { keeps = { "session", "ledgerPage" } },
}

-- A copy of `target` with only what its page keeps.
---@param target StatsBookTarget
---@return StatsBookTarget
local function copy(target)
	local place = { page = target.page }
	for _, field in ipairs(PAGES[target.page].keeps) do
		place[field] = target[field]
	end
	return place
end

---@class StatsBookRouter
---@field private place StatsBookTarget
---@field private renderers table<string, StatsBookRenderer> -- by "page:side"
local Router = {}
Router.__index = Router

--- A router on the home spread, with no renderers yet: the book makes one when its file loads, so the first opening
--- after a login or `/reload` shows the home spread (STA-R70).
---@return StatsBookRouter
function ns.NewBookRouter()
	return setmetatable({ place = { page = "home" }, renderers = {} }, Router)
end

--- Registers `renderer` to draw side `side` of page `page`; a later registration replaces it. Raises on a page or side
--- the book doesn't have, so a typo fails when the file loads.
---@param page StatsBookPage
---@param side StatsBookSide
---@param renderer StatsBookRenderer
function Router:Register(page, side, renderer)
	assert(PAGES[page], "the Stats book has no page " .. tostring(page))
	assert(side == "left" or side == "right", "a Stats book page's side is left or right, not " .. tostring(side))
	assert(type(renderer) == "function", "a Stats book page's renderer is a function")
	self.renderers[page .. ":" .. side] = renderer
end

--- The renderer of side `side` of page `page`, or nil when none is registered: that side is left blank.
---@param page StatsBookPage
---@param side StatsBookSide
---@return StatsBookRenderer?
function Router:Renderer(page, side)
	return self.renderers[page .. ":" .. side]
end

--- Shows `target`, keeping what its page shows (STA-R70: the book reopens on it). Raises when its page is unknown or
--- it lacks what the page needs (a place page its area, an item page its item), and the book stays where it was.
---@param target StatsBookTarget
function Router:Open(target)
	local page = PAGES[target.page]
	assert(page, "the Stats book has no page " .. tostring(target.page))
	assert(
		not page.needs or target[page.needs] ~= nil,
		"a Stats book " .. target.page .. " page needs its " .. tostring(page.needs)
	)
	self.place = copy(target)
end

--- Where the book is, as a copy.
---@return StatsBookTarget
function Router:Place()
	return copy(self.place)
end

--- The breadcrumb trail (STA-R74): "Stats" (home); on a place page its zone, then its subzone, then the chosen item,
--- which does nothing; on an item page the item; on a ribbon page its kicker. Each other crumb opens what it names:
--- an area's crumb its place page with nothing chosen, the last crumb the page as it is.
---@param zoneOf fun(area: integer): integer the zone an area is in: itself for a zone
---@return StatsBookCrumb[]
function Router:Trail(zoneOf)
	local place = self.place
	local trail = { { kind = "stats", target = { page = "home" } } } ---@type StatsBookCrumb[]
	local page = place.page
	if page == "place" then
		local area = place.area --[[@as integer]]
		local zone = zoneOf(area)
		trail[#trail + 1] = { kind = "zone", id = zone, target = { page = "place", area = zone } }
		if zone ~= area then
			trail[#trail + 1] = { kind = "subzone", id = area, target = { page = "place", area = area } }
		end
		if place.item then
			trail[#trail + 1] = { kind = "item", id = place.item }
		end
	elseif page == "item" then
		trail[#trail + 1] = { kind = "item", id = place.item, target = copy(place) }
	elseif page ~= "home" then
		trail[#trail + 1] = { kind = "ribbon", id = page, target = copy(place) }
	end
	return trail
end

--- Where the *Where I am* ribbon goes (STA-R74): the current subzone's place page, the zone's when the subzone is 0,
--- the home spread when the zone is 0.
---@param conditions ConditionsSnapshot the live snapshot, `Pagle.GetConditions()` (LOG-R45)
---@return StatsBookTarget
function ns.WhereIAm(conditions)
	local area = ns.CurrentPlace(conditions)
	if area == nil then
		return { page = "home" }
	end
	return { page = "place", area = area }
end

--- The ribbon of the page shown (it stands out): Where I am on the current place's page, an entry chosen or not; This
--- Session, Lifetime and Sessions on their own pages; none elsewhere.
---@param place StatsBookTarget
---@param here integer? the current place (ns.CurrentPlace), nil with zone 0
---@return ("here"|"session"|"lifetime"|"sessions")?
function ns.ChosenRibbon(place, here)
	local page = place.page
	if page == "place" then
		return (here ~= nil and place.area == here) and "here" or nil
	end
	if page == "session" or page == "lifetime" or page == "sessions" then
		return page --[[@as "session"|"lifetime"|"sessions"]]
	end
	return nil
end
