if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- Search on the Stats book's leather (STA-R76): a parchment box in the book's search anchor, "Find a fish or a
-- water…", and a dropdown under it that lists what logic/Search.lua finds as the player types, from the first
-- character. Clicking a result opens its page and Enter opens the first; either empties the box. The box is disabled
-- while the projection updates (STA-R72). The names it lacks are asked for when the book opens, and the dropdown is
-- refreshed at every draw of the book, so an item matches once its name loads (STA-R73). Variant D's look; no code
-- shared with the Journal's search (ADR 0001).

local L = ns.L
local LOOK = ns.BOOK_LOOK

-- A dropdown row's height, its inset, and the padding round the rows (variant D: 3px 6px rows in 4px).
local ROW_HEIGHT, ROW_INSET, DROP_PAD = 20, 8, 4

---@class StatsSearchRowView: Button
---@field name FontString
---@field label FontString         -- the small label, in italic note ink
---@field target StatsBookTarget?  -- nil for the no-results line

---@class StatsSearchDropView: Frame
---@field rows StatsSearchRowView[]

---@class StatsSearchAnchor: Frame
---@field box EditBox
---@field hint FontString           -- the box's hint, while it is empty
---@field drop StatsSearchDropView
---@field results StatsSearchResult[]
---@field opened boolean            -- the book has opened since the names were last asked for

-- The client's names for search (logic/Search.lua): an item's once loaded, an area's from C_Map.
---@type StatsSearchNames
local NAMES = {
	item = function(itemID)
		local name, _, loaded = ns.Item(itemID)
		return loaded and name or nil
	end,
	area = function(areaID)
		local name = C_Map.GetAreaInfo(areaID)
		return name ~= "" and name or nil
	end,
}

-- Opens `target` and empties the box, which hides the dropdown.
---@param anchor StatsSearchAnchor
---@param target StatsBookTarget
local function open(anchor, target)
	anchor.box:SetText("")
	anchor.box:ClearFocus()
	ns.OpenBook(target)
end

-- Row `i` of the dropdown, made on first use: a result's name with its small label after it, opening its page.
---@param anchor StatsSearchAnchor
---@param i integer
---@return StatsSearchRowView
local function rowAt(anchor, i)
	local drop = anchor.drop
	local row = drop.rows[i]
	if not row then
		row = CreateFrame("Button", nil, drop) --[[@as StatsSearchRowView]]
		row:SetHeight(ROW_HEIGHT)
		row:SetPoint("TOPLEFT", 0, -(DROP_PAD + (i - 1) * ROW_HEIGHT))
		row:SetPoint("TOPRIGHT", 0, -(DROP_PAD + (i - 1) * ROW_HEIGHT))
		local shade = ns.BookSolid(row, LOOK.shade, "BACKGROUND", LOOK.shadeAlpha)
		shade:Hide()
		row.name = ns.BookText(row, ns.BookFonts().text, LOOK.ink)
		row.name:SetPoint("LEFT", ROW_INSET, 0)
		row.label = ns.BookText(row, ns.BookFonts().note, LOOK.note)
		row.label:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
		row:SetScript("OnEnter", function(self)
			shade:SetShown(self.target ~= nil)
		end)
		row:SetScript("OnLeave", function()
			shade:Hide()
		end)
		row:SetScript("OnClick", function(self)
			if self.target then
				open(anchor, self.target)
			end
		end)
		drop.rows[i] = row
	end
	return row
end

-- Lists what the box's text finds in the dropdown (STA-R76): each result's name and label, or the no-results line in
-- faded italic; an empty box hides it, and so does the projection updating (STA-R72).
---@param anchor StatsSearchAnchor
local function refresh(anchor)
	local text = anchor.box:GetText() or ""
	anchor.hint:SetShown(text == "")
	local found = not ns.IsUpdating() and ns.Search(text, ns.State(), NAMES, ns.places) or nil
	anchor.results = found and found.results or {}
	if not found then
		anchor.drop:Hide()
		return
	end
	local lines = #found.results
	for i, result in ipairs(found.results) do
		local row = rowAt(anchor, i)
		row.name:SetText(result.name)
		row.name:SetTextColor(LOOK.ink[1], LOOK.ink[2], LOOK.ink[3])
		row.label:SetText(result.label)
		row.label:Show()
		row.target = result.target
		row:Show()
	end
	if found.none then
		local row = rowAt(anchor, 1)
		row.name:SetText(found.none)
		row.name:SetTextColor(LOOK.faded[1], LOOK.faded[2], LOOK.faded[3])
		row.label:Hide()
		row.target = nil
		row:Show()
		lines = 1
	end
	for i = lines + 1, #anchor.drop.rows do
		anchor.drop.rows[i]:Hide()
	end
	anchor.drop:SetHeight(lines * ROW_HEIGHT + 2 * DROP_PAD)
	anchor.drop:Show()
end

-- Builds the box and its dropdown in `anchor`: the parchment box with its outline and hint, the dropdown under it on a
-- higher strata than the book, so it lies over the pages. Closing the book empties the box.
---@param anchor StatsSearchAnchor
local function build(anchor)
	local fonts = ns.BookFonts()
	ns.BookSolid(anchor, LOOK.searchEdge, "BACKGROUND")
	local box = CreateFrame("EditBox", nil, anchor) --[[@as EditBox]]
	box:SetPoint("TOPLEFT", 1, -1)
	box:SetPoint("BOTTOMRIGHT", -1, 1)
	box:SetAutoFocus(false)
	box:SetFontObject(fonts.text)
	box:SetTextColor(LOOK.ink[1], LOOK.ink[2], LOOK.ink[3])
	box:SetTextInsets(8, 8, 0, 0)
	ns.BookSolid(box, LOOK.searchPaper, "BACKGROUND")
	anchor.box = box
	anchor.hint = ns.BookText(box, fonts.note, LOOK.note) -- the kit's italic placeholder
	anchor.hint:SetPoint("LEFT", 8, 0)
	anchor.hint:SetText(L.SEARCH_HINT)

	local drop = CreateFrame("Frame", nil, anchor) --[[@as StatsSearchDropView]]
	drop:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
	drop:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
	drop:SetFrameStrata("DIALOG")
	drop:EnableMouse(true)
	ns.BookSolid(drop, LOOK.ledgerRule, "BACKGROUND")
	local paper = ns.BookSolid(drop, LOOK.paper, "BORDER")
	paper:SetPoint("TOPLEFT", 1, -1)
	paper:SetPoint("BOTTOMRIGHT", -1, 1)
	drop.rows = {}
	drop:Hide()
	anchor.drop = drop
	anchor.results = {}

	box:SetScript("OnTextChanged", function()
		refresh(anchor)
	end)
	box:SetScript("OnEnterPressed", function()
		local first = anchor.results[1]
		if first then
			open(anchor, first.target)
		end
	end)
	box:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)
	anchor:GetParent():HookScript("OnHide", function()
		box:SetText("")
		box:ClearFocus()
		anchor.opened = true
	end)
	anchor.opened = true
end

--- Draws search at every draw of the book: built at the first, enabled unless the projection updates (STA-R72), the
--- names it lacks asked for when the book has opened since, and the dropdown refreshed with the names loaded since.
---@param anchor StatsSearchAnchor
---@param _ StatsBookTarget
---@param updating boolean
local function draw(anchor, _, updating)
	if not anchor.box then
		build(anchor)
	end
	anchor.box:SetEnabled(not updating)
	if updating then
		anchor.box:ClearFocus()
	elseif anchor.opened then
		anchor.opened = false
		for _, item in ipairs(ns.SearchItems(ns.State(), ns.places)) do
			ns.book:Item(item)
		end
	end
	refresh(anchor)
end

ns.book:RegisterLeather("search", draw)
