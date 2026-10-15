if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The item page's lines (stats.md › UI › Item page): one fish found without knowing where it is. Its left page says
-- when it bites, what I've caught of it and, when it is on the current place's rows, how it stands where I am; its
-- right page tiles every water I've fished for it. Pure logic: the projection's state, the live snapshot and the
-- server time come in as arguments (CORE-R7); adapter/Item.lua draws what these return.

--- The left page's lines, below the kicker and the item's icon and name (which the adapter writes from ns.Item).
---@class StatsItemFacts
---@field bites string?          -- "Bites at any hour." or "Bites only {window} ({from}–{to} realm time)."; nil when
---                                 no zone I've fished, or the current one, lists it
---@field pool string?           -- the pool line, for a pool-associated item
---@field caught string          -- my catches of it, anywhere (STA-R25)
---@field first string           -- the first one's date, or "—"
---@field last string            -- the latest one's date and time ago, or "—"
---@field here StatsItemHere?    -- *Where I am*, when the item is on the current place's rows (STA-R17)

--- *Where I am* on the item page: the current place, its line, and the place page it opens with the item chosen.
---@class StatsItemHere
---@field area integer
---@field place string           -- the place's name, the heading's small note
---@field text string            -- "{short odds}; {since} since the last." and its other two forms
---@field target StatsBookTarget

-- The zones whose lists name the item, among those I've fished (a `places` record whose `zone` is its own areaID) and
-- the current zone, with my Casts in each (0 for the current zone with none).
---@param state StatsState
---@param item integer
---@param here integer the current zone, 0 for none
---@param lookups StatsLookups
---@return integer? zone the one with the most of my Casts, ties by areaID
local function bitingZone(state, item, here, lookups)
	local casts = {} ---@type table<integer, integer>
	for area, record in pairs(state.places) do
		if record.zone == area then
			casts[area] = record.casts
		end
	end
	if here ~= 0 and not casts[here] then
		casts[here] = 0
	end
	local best
	for zone, n in pairs(casts) do
		local lists = false
		for _, entry in ipairs(lookups.GetZoneCatches(zone) or {}) do
			lists = lists or entry.itemID == item
		end
		if lists and (best == nil or n > casts[best] or (n == casts[best] and zone < best)) then
			best = zone
		end
	end
	return best
end

-- "Bites at any hour." with no window in the zone (STA-R14), or "Bites only {window name}." (STA-R47), with the
-- window's realm-time ranges in brackets when its spec has a `time` field.
---@param zone integer
---@param item integer
---@param places StatsPlaceTables
---@return string
local function bitesText(zone, item, places)
	local L = ns.L
	local window = places:ItemWindow(zone, item)
	if not window then
		return L.ITEM_BITES_ANY
	end
	local spec = places.lookups.GetWindowSpec(window)
	local ranges = {}
	for i, range in ipairs(spec and spec.time or {}) do
		ranges[i] = L.ITEM_RANGE:format(ns.WindowTime(range[1]), ns.WindowTime(range[2]))
	end
	if #ranges == 0 then
		return L.ITEM_BITES_ONLY:format(ns.WindowName(window))
	end
	return L.ITEM_BITES_ONLY_TIMED:format(ns.WindowName(window), table.concat(ranges, L.ITEM_RANGES_JOIN))
end

-- Whether `item` is on `rows`.
---@param rows StatsRow[]
---@param item integer
---@return boolean
local function onRows(rows, item)
	for _, row in ipairs(rows) do
		if row.item == item then
			return true
		end
	end
	return false
end

-- *Where I am*: when the item is on the current place's rows (STA-R17), its reading there in short (STA-R43) and its
-- Dry spell (STA-R50): "{since} since the last.", "caught on my last Cast." for 0, "none yet." when never caught in
-- the scope.
---@param state StatsState
---@param item integer
---@param conditions ConditionsSnapshot
---@param places StatsPlaceTables
---@return StatsItemHere?
local function hereOf(state, item, conditions, places)
	local L = ns.L
	local area = ns.CurrentPlace(conditions)
	if area == nil or not onRows(places:Rows(state, area), item) then
		return nil
	end
	local reading = ns.Reading(state, item, area, ns.EffectiveSkill(conditions), places)
	local short, dry = ns.OddsShort(reading), ns.DrySpell(reading)
	local text
	if not dry.caught then
		text = L.ITEM_HERE_NONE_YET:format(short)
	elseif dry.since == 0 then
		text = L.ITEM_HERE_CAUGHT_LAST:format(short)
	else
		text = L.ITEM_HERE_SINCE:format(short, ns.Number(dry.since))
	end
	return {
		area = area,
		place = ns.AreaName(area),
		text = text,
		target = { page = "place", area = area, item = item },
	}
end

--- The item page's left page (stats.md › UI › Item page): when it bites, its window (STA-R14) in the zone with the
--- most of my Casts among those I've fished, and the current zone, whose `GetZoneCatches` lists it, left out when none
--- does or the item is Noise or removed; the pool line; my records of it; and *Where I am*.
---@param state StatsState
---@param item integer
---@param conditions ConditionsSnapshot the live snapshot, `Pagle.GetConditions()`
---@param now integer the server time
---@param places StatsPlaceTables? ns.places by default
---@return StatsItemFacts
function ns.ItemFacts(state, item, conditions, now, places)
	places = places or ns.places
	local L, lookups = ns.L, places.lookups
	local record = lookups.GetItem(item)
	local bites
	if not (record and (record.noise or record.removed)) then
		local zone = bitingZone(state, item, conditions.zone or 0, lookups)
		bites = zone and bitesText(zone, item, places)
	end
	local total = state.items[item]
	return {
		bites = bites,
		pool = record and record.pool and L.ITEM_POOL or nil,
		caught = ns.Number(total and total.n or 0),
		first = total and ns.Date(total.first) or L.ITEM_NEVER,
		last = total and L.ITEM_LAST_VALUE:format(ns.Date(total.last), ns.TimeAgo(total.last, now)) or L.ITEM_NEVER,
		here = hereOf(state, item, conditions, places),
	}
end

--- One tile on the right page: a water I've fished for the item, and its entry there.
---@class StatsItemTile: StatsTile
---@field area integer
---@field name string            -- the place's name
---@field line string            -- its short odds (STA-R43), after its zone's name on a subzone's tile
---@field here string?           -- "I'm here" on the current place
---@field note string?           -- "{since} since", in red, when the Dry spell is unlucky or very unlucky (STA-R52)
---@field target StatsBookTarget -- its place page with the item chosen

---@class StatsItemWaters
---@field tiles StatsItemTile[]
---@field empty string?          -- "I haven't fished anywhere it bites." with no tiles

-- An item's tile in a place: the place, its zone on a subzone, "I'm here", the short odds, and the Dry spell in red
-- when its band is unlucky or very unlucky.
---@param state StatsState
---@param item integer
---@param area integer
---@param conditions ConditionsSnapshot
---@param places StatsPlaceTables
---@return StatsItemTile
local function tileOf(state, item, area, conditions, places)
	local L = ns.L
	local reading = ns.Reading(state, item, area, ns.EffectiveSkill(conditions), places)
	local short = ns.OddsShort(reading)
	local zone = state.places[area].zone
	local dry = ns.DrySpell(reading)
	local note
	if ns.IsUnlucky(dry.band) then
		note = L.DRY_SHORT_SINCE:format(ns.Number(dry.since))
	end
	return {
		area = area,
		name = ns.AreaName(area),
		line = zone == area and short or L.ITEM_TILE_LINE:format(ns.AreaName(zone), short),
		here = ns.CurrentPlace(conditions) == area and L.HOME_HERE or nil,
		note = note,
		target = { page = "place", area = area, item = item },
	}
end

--- The item page's right page, Where I've fished for it (stats.md › UI › Item page): tiles from places in my records
--- only, grouped by zone, zones by my Casts (most first, ties by areaID): the zone itself when the item is on its rows
--- (STA-R17), then each of its subzones in my records whose rows include the item, by name. Rows hold what I caught
--- there, so an Uncharted item has tiles; a Noise item has none. With no tiles, "I haven't fished anywhere it bites."
---@param state StatsState
---@param item integer
---@param conditions ConditionsSnapshot the live snapshot, `Pagle.GetConditions()`
---@param places StatsPlaceTables? ns.places by default
---@return StatsItemWaters
function ns.ItemWaters(state, item, conditions, places)
	places = places or ns.places
	local zones, subzones = {}, {} ---@type integer[], table<integer, integer[]>
	for area, record in pairs(state.places) do
		if record.zone == area then
			zones[#zones + 1] = area
		elseif onRows(places:Rows(state, area), item) then
			subzones[record.zone] = subzones[record.zone] or {}
			table.insert(subzones[record.zone], area)
		end
	end
	table.sort(zones, function(a, b)
		local casts, other = state.places[a].casts, state.places[b].casts
		if casts ~= other then
			return casts > other
		end
		return a < b
	end)
	local tiles = {} ---@type StatsItemTile[]
	for _, zone in ipairs(zones) do
		if onRows(places:Rows(state, zone), item) then
			tiles[#tiles + 1] = tileOf(state, item, zone, conditions, places)
		end
		local inZone = subzones[zone] or {}
		local names = {}
		for _, area in ipairs(inZone) do
			names[area] = ns.AreaName(area)
		end
		table.sort(inZone, function(a, b)
			if names[a] ~= names[b] then
				return names[a] < names[b]
			end
			return a < b
		end)
		for _, area in ipairs(inZone) do
			tiles[#tiles + 1] = tileOf(state, item, area, conditions, places)
		end
	end
	return { tiles = tiles, empty = #tiles == 0 and ns.L.ITEM_NO_WATERS or nil }
end
