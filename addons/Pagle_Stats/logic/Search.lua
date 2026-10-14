if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- Search on the Stats book's leather (STA-R76): finding a fish or a water by name, in my own records. Pure logic: the
-- projection's state, the place tables and the client's names come in as arguments (CORE-R7); adapter/Search.lua
-- draws the box and its dropdown. Shares no code with the Journal's search (ADR 0001).

--- Search results (stats.md › Tunables): up to 6 fish, then up to 5 places.
ns.SEARCH_FISH_RESULTS = 6
ns.SEARCH_PLACE_RESULTS = 5

--- The client's names, nil for one it hasn't got (yet): an item's by `C_Item.GetItemNameByID`, an area's by
--- `C_Map.GetAreaInfo`.
---@class StatsSearchNames
---@field item fun(itemID: integer): string?
---@field area fun(areaID: integer): string?

--- One result: its name, its small label ("fish", "zone", or a subzone's zone's name) and the page it opens.
---@class StatsSearchResult
---@field name string
---@field label string
---@field target StatsBookTarget

---@class StatsSearchFound
---@field results StatsSearchResult[]
---@field none string?           -- "Nothing by that name in my records." with no results

--- The items search looks among (STA-R76), by item ID: every item on the rows (STA-R17) of a zone with my Casts, and
--- every item in my records (`items`, STA-R25). The book asks the client for the names it lacks when it opens.
---@param state StatsState
---@param places StatsPlaceTables? ns.places by default
---@return integer[]
function ns.SearchItems(state, places)
	places = places or ns.places
	local seen, items = {}, {}
	local function add(item)
		if not seen[item] then
			seen[item] = true
			items[#items + 1] = item
		end
	end
	for area, record in pairs(state.places) do
		if record.zone == area then
			for _, row in ipairs(places:Rows(state, area)) do
				add(row.item)
			end
		end
	end
	for item in pairs(state.items) do
		add(item)
	end
	table.sort(items)
	return items
end

-- The matches among `ids` by their names, alphabetical (ties by ID), at most `limit`.
---@param ids integer[]
---@param nameOf fun(id: integer): string?
---@param query string the query, in lower case
---@param limit integer
---@return { id: integer, name: string }[]
local function matching(ids, nameOf, query, limit)
	local found = {}
	for _, id in ipairs(ids) do
		local name = nameOf(id)
		if name and name:lower():find(query, 1, true) then
			found[#found + 1] = { id = id, name = name, key = name:lower() }
		end
	end
	table.sort(found, function(a, b)
		if a.key ~= b.key then
			return a.key < b.key
		end
		return a.id < b.id
	end)
	for i = #found, limit + 1, -1 do
		found[i] = nil
	end
	return found
end

--- What `query` finds (STA-R76): case-insensitively anywhere in the name, up to 6 items (ns.SearchItems, by the
--- client's names: one not loaded yet doesn't match) then up to 5 places (every zone and subzone in `places`), each
--- list alphabetical, each result with its label and the page it opens; "Nothing by that name in my records." with
--- none. Nil for an empty query: the dropdown hides.
---@param query string
---@param state StatsState
---@param names StatsSearchNames
---@param places StatsPlaceTables? ns.places by default
---@return StatsSearchFound?
function ns.Search(query, state, names, places)
	if query == "" then
		return nil
	end
	local L, lowered = ns.L, query:lower()
	local results = {} ---@type StatsSearchResult[]
	for _, item in ipairs(matching(ns.SearchItems(state, places), names.item, lowered, ns.SEARCH_FISH_RESULTS)) do
		results[#results + 1] = { name = item.name, label = L.SEARCH_FISH, target = { page = "item", item = item.id } }
	end
	local areas = {}
	for area in pairs(state.places) do
		areas[#areas + 1] = area
	end
	for _, area in ipairs(matching(areas, names.area, lowered, ns.SEARCH_PLACE_RESULTS)) do
		local zone = state.places[area.id].zone
		results[#results + 1] = {
			name = area.name,
			label = zone == area.id and L.SEARCH_ZONE or ns.AreaName(zone),
			target = { page = "place", area = area.id },
		}
	end
	return { results = results, none = #results == 0 and L.SEARCH_NONE or nil }
end
