if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The Stats book's pages and crumbs (STA-R70, STA-R74): pure logic, everything passed in (CORE-R7). The book is Core's
-- shell (Pagle.NewBook, core/book.md), which routes between the pages below, keeping of a target what each page keeps;
-- this file says what the pages are, the crumb trail back up, and where the ribbons go. adapter/Book.lua hands them
-- to the shell.
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
--- "Updating my records…" on both sides (STA-R72, BOOK-R22).
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

---@type StatsBookRibbon[]
ns.BOOK_RIBBONS = {
	{ id = "here", green = true },
	{ id = "session", page = "session", green = false },
	{ id = "lifetime", page = "lifetime", green = false },
	{ id = "sessions", page = "sessions", green = false },
}

--- The book's pages as Core's shell takes them (BOOK-R20): what each keeps of a target besides its page, what it can't
--- do without, and its place in the turn order: the ribbons' order, the home spread first, an item's page after a
--- place's.
---@type table<StatsBookPage, PagleBookPageDef>
ns.BOOK_PAGES = {
	home = { keeps = {}, order = 0 },
	place = { keeps = { "area", "item" }, needs = "area", order = 1 },
	item = { keeps = { "item", "area" }, needs = "item", order = 1.5 },
	session = { keeps = {}, order = 2 },
	lifetime = { keeps = {}, order = 3 },
	sessions = { keeps = { "session", "ledgerPage" }, order = 4 },
}

-- A copy of `target` with only what its page keeps.
---@param target StatsBookTarget
---@return StatsBookTarget
local function copy(target)
	local place = { page = target.page }
	for _, field in ipairs(ns.BOOK_PAGES[target.page].keeps) do
		place[field] = target[field]
	end
	return place
end

--- The breadcrumb trail at `place` (STA-R74): "Stats" (home); on a place page its zone, then its subzone, then the
--- chosen item, which does nothing; on an item page the item; on a ribbon page its kicker. Each other crumb opens what
--- it names: an area's crumb its place page with nothing chosen, the last crumb the page as it is.
---@param place StatsBookTarget
---@param zoneOf fun(area: integer): integer the zone an area is in: itself for a zone
---@return StatsBookCrumb[]
function ns.BookTrail(place, zoneOf)
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

--- The spread the book's First look shows on (ONB-R57, board 14): `area`'s place page with an item's entry chosen,
--- so every note has its region: the first row whose Dry spell has a luck reading (its ruler and "nothing is owed",
--- STA-R51, STA-R54), else the first row. Nil with no area (zone 0) or no rows.
---@param area integer? the place, nil for none
---@param groups StatsGroup[] its row groups (ns.Groups), in their order
---@return StatsBookTarget?
function ns.BookLookTarget(area, groups)
	if area == nil then
		return nil
	end
	local first
	for _, group in ipairs(groups) do
		for _, reading in ipairs(group.readings) do
			local dry = ns.DrySpell(reading)
			if dry.P and dry.since > 0 then
				return { page = "place", area = area, item = reading.item }
			end
			first = first or reading.item
		end
	end
	return first and { page = "place", area = area, item = first } or nil
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
