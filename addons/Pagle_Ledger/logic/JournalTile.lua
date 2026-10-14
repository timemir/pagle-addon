if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- A zone tile (LED-R131) as page data, and the zones that have one. Pure logic over the spread context (CORE-R7);
-- adapter/JournalWidgets.lua draws the tile.

--- The zones with a tile (LED-R131), in tile order (skill base, zones without one last, then areaID): every charted
--- zone and every fished zone that isn't charted. Home shows them, and search matches their names (LED-R148).
---@param context LedgerSpreadContext
---@return integer[]
function ns.HomeZones(context)
	local world, state = context.world, context.state
	local set = {}
	for _, zone in ipairs(world.charted) do
		set[zone] = true
	end
	for zone in pairs(state.zones) do
		set[zone] = true
	end
	return ns.SortZonesBySkill(ns.SortedKeys(set), world.skillBase)
end

--- A zone's tile (LED-R131): its name, then fished and charted, its shown rank and completion ("Local · 63%"), an ink
--- bar of the completion, a wax seal at Master and a red "{N} new!" note with new to find; charted and never fished,
--- faded, "unfished · skill ~{skillBase}" ("unfished · any skill" at 0 or below, DATA-R30; just "unfished" without
--- one); not charted, "uncharted waters". It opens the zone's spread.
---@param zone integer
---@param context LedgerSpreadContext
---@return LedgerZoneTile
function ns.JournalZoneTile(zone, context)
	local L = ns.L
	local world, state = context.world, context.state
	---@type LedgerZoneTile
	local tile = { name = context.text:Zone(zone), place = ns.JournalPlace.zone(zone) }
	if not world.zones[zone] then
		tile.line = L.TILE_UNCHARTED
	elseif not state.zones[zone] then
		local skill = world.skillBase[zone]
		if not skill then
			tile.line = L.UNFISHED
		else
			tile.line = skill > 0 and L.TILE_UNFISHED_SKILL:format(skill) or L.TILE_UNFISHED_ANY_SKILL
		end
		tile.faded = true
	else
		local celebrated = context.celebrated
		local rank = ns.ShownZoneRank(world, state, celebrated, zone)
		local completion = ns.ZoneCompletion(world, state, zone) --[[@as integer]]
		tile.line = L.TILE_RANK:format(L.ZONE_RANKS[rank] or L.UNFISHED, completion)
		tile.bar = completion / 100
		tile.seal = rank == ns.ZONE_MASTER and L.ZONE_RANKS[rank] or nil
		local newToFind = ns.NewToFind(world, state, celebrated, zone)
		tile.note = newToFind > 0 and L.TILE_NEW:format(newToFind) or nil
	end
	return tile
end
