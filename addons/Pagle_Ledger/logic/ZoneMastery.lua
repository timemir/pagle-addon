if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- Zone Mastery (LED-R50–R54, LED-R134): each charted zone's rank, Visitor to Master, from the breadth of what was
-- caught there. The fold notes each Catch in its zone and credits the ranks a Cast passes; the shown rank, new to
-- find, completion and the next requirement are computed from the state, the world index (LED-R10) and the
-- celebrated set (LED-R90). Pure logic, everything passed in (CORE-R7).

--- Zone Mastery's top rank, Master (LED-R50): Ledger completion counts the zones at it (LED-R70).
ns.ZONE_MASTER = 5

-- The ranks (LED-R50).
local VISITOR, REGULAR, LOCAL, EXPERT, MASTER = 1, 2, 3, 4, ns.ZONE_MASTER
-- Each rank reached earns 250 × rank XP (LED-R20) and 2 × rank Coins (LED-R88, Tunables).
local RANK_XP = 250
--- Coins for each Zone Mastery rank reached, × the rank (LED-R88); a zoneRank moment pays them for the ranks it
--- raises above the celebrated one (LED-R97).
ns.ZONE_RANK_COINS = 2
local RANK_COINS = ns.ZONE_RANK_COINS

--- A zone's first Catch makes its state (ledger.md › Data, LedgerZone): nothing noted yet, rank 0.
---@return LedgerZone
function ns.NewZoneState()
	return { species = {}, families = {}, items = {}, junk = false, treasure = false, rank = 0 }
end

--- Notes a trophy or curio Catch in its fished zone (LED-R50, LED-R138): the item, and the family it lands or the
--- junk or treasure requirement it meets. Species Catches are noted by the fold's Species branch; other classes, and
--- zone 0 (no `zoneState`), note nothing.
---@param zoneState LedgerZone?
---@param class string the Catch's class (ns.ClassifyCatch)
---@param itemID integer
---@param item PagleItem?
function ns.NoteZoneCatch(zoneState, class, itemID, item)
	if not (zoneState and item and (class == "trophy" or class == "curio")) then
		return
	end
	zoneState.items[itemID] = true
	local collection = ns.CollectionOf(item)
	if collection == "trophy" then
		if item.family then
			zoneState.families[item.family] = true
		end
	elseif collection == "junk" then
		zoneState.junk = true
	else
		zoneState.treasure = true
	end
end

--- What a charted zone still lacks (LED-R50, LED-R52, LED-R53). Only what is on the zone's list counts.
---@class LedgerZoneNeeds
---@field missing integer[] -- [r]: what rank r needs beyond the ranks below it
---@field gated integer     -- its gated Species not caught there
---@field junk boolean      -- its junk requirement, unmet
---@field treasure boolean  -- its treasure requirement, unmet
---@field done integer      -- completion's parts met (LED-R53)
---@field needed integer    -- completion's parts: listed Species, families, junk and treasure requirements
---@field counts LedgerZoneCounts

--- A charted zone's catches counted against its list (LED-R135, LED-R137): only what is on the list counts.
---@class LedgerZoneCounts
---@field fish integer      -- its listed Species
---@field fishKnown integer -- of those, caught there
---@field families integer  -- its listed trophy families
---@field landed integer    -- of those, landed there

-- A charted zone's needs (LED-R50): Visitor lacks 1 until the zone is fished; Regular the shortfall to `ceil(U / 2)`
-- of its `U` ungated Species; Local each other uncaught ungated Species; Expert each uncaught gated Species plus 1 for
-- each unmet junk or treasure requirement; Master each family not landed there.
---@param zoneIndex LedgerWorldZone
---@param zoneState LedgerZone?
---@return LedgerZoneNeeds
local function needsOf(zoneIndex, zoneState)
	local caught = zoneState and zoneState.species or {}
	local landed = zoneState and zoneState.families or {}
	local ungated, ungatedCaught, gated, families = 0, 0, 0, 0
	local done, needed = 0, 0
	local counts = { fish = 0, fishKnown = 0, families = 0, landed = 0 }
	for id, listing in pairs(zoneIndex.species) do
		needed = needed + 1
		counts.fish = counts.fish + 1
		if caught[id] then
			done = done + 1
			counts.fishKnown = counts.fishKnown + 1
		end
		if not listing.gated then
			ungated = ungated + 1
			ungatedCaught = ungatedCaught + (caught[id] and 1 or 0)
		elseif not caught[id] then
			gated = gated + 1
		end
	end
	for family in pairs(zoneIndex.families) do
		needed = needed + 1
		counts.families = counts.families + 1
		if landed[family] then
			done = done + 1
			counts.landed = counts.landed + 1
		else
			families = families + 1
		end
	end
	local junk = zoneIndex.junk and not (zoneState and zoneState.junk)
	local treasure = zoneIndex.treasure and not (zoneState and zoneState.treasure)
	needed = needed + (zoneIndex.junk and 1 or 0) + (zoneIndex.treasure and 1 or 0)
	done = done + ((zoneIndex.junk and not junk) and 1 or 0) + ((zoneIndex.treasure and not treasure) and 1 or 0)
	local regular = math.max(0, math.ceil(ungated / 2) - ungatedCaught)
	return {
		missing = {
			zoneState and 0 or 1,
			regular,
			ungated - ungatedCaught - regular,
			gated + (junk and 1 or 0) + (treasure and 1 or 0),
			families,
		},
		gated = gated,
		junk = junk,
		treasure = treasure,
		done = done,
		needed = needed,
		counts = counts,
	}
end

-- The computed rank (LED-R50): the highest rank whose requirements, and every one below, are all met.
---@param missing integer[]
---@return integer
local function rankOf(missing)
	local rank = 0
	while rank < MASTER and missing[rank + 1] == 0 do
		rank = rank + 1
	end
	return rank
end

--- Credits the ranks one Cast passed in its zone (LED-R50, LED-R51): its computed rank only rises, and each rank it
--- passes earns 250 × rank XP (LED-R20) and 2 × rank Coins (LED-R88) once, in one `zoneRank` achievement carrying
--- the ranks, ascending, however many the Cast passed. A zone that isn't charted keeps rank 0 (LED-R54).
---@param state LedgerState
---@param world LedgerWorld
---@param zone integer the Cast's zone; 0 credits nothing (LED-R6)
---@param cast string the Cast's entry ID
---@param earned LedgerAchievement[]
function ns.CreditZoneRank(state, world, zone, cast, earned)
	local zoneState, zoneIndex = state.zones[zone], world.zones[zone]
	if not (zoneState and zoneIndex) then
		return
	end
	local rank = rankOf(needsOf(zoneIndex, zoneState).missing)
	if rank <= zoneState.rank then
		return
	end
	local ranks, coins = {}, 0
	for passed = zoneState.rank + 1, rank do
		ranks[#ranks + 1] = passed
		state.xp = state.xp + RANK_XP * passed
		coins = coins + RANK_COINS * passed
	end
	zoneState.rank = rank
	state.coins = state.coins + coins
	earned[#earned + 1] = { kind = "zoneRank", cast = cast, coins = coins, zone = zone, ranks = ranks }
end

--- The shown rank (LED-R52, LED-R92): the higher of the computed rank and the celebrated one. 0 for a zone that
--- isn't charted, whose celebrated rank is kept but not shown (LED-R54), and for a charted zone neither fished nor
--- celebrated.
---@param world LedgerWorld
---@param state LedgerState
---@param celebrated LedgerCelebrated
---@param zone integer
---@return integer
function ns.ShownZoneRank(world, state, celebrated, zone)
	if not world.zones[zone] then
		return 0
	end
	local zoneState = state.zones[zone]
	return math.max(zoneState and zoneState.rank or 0, celebrated.zones and celebrated.zones[zone] or 0)
end

--- New to find (LED-R52): while the shown rank is above the computed one, the things missing for the shown rank's
--- requirements, summed over every rank from Regular up to it; otherwise 0.
---@param world LedgerWorld
---@param state LedgerState
---@param celebrated LedgerCelebrated
---@param zone integer
---@return integer
function ns.NewToFind(world, state, celebrated, zone)
	local zoneIndex, zoneState = world.zones[zone], state.zones[zone]
	local shown = ns.ShownZoneRank(world, state, celebrated, zone)
	if not zoneIndex or shown <= (zoneState and zoneState.rank or 0) then
		return 0
	end
	local missing = needsOf(zoneIndex, zoneState).missing
	local count = 0
	for rank = REGULAR, shown do
		count = count + missing[rank]
	end
	return count
end

--- A zone's completion (LED-R53): `floor(100 × done / needed)` over its listed Species, its families and 1 each for
--- its junk and treasure requirements; 100 exactly when the computed rank is Master. nil for a zone that isn't
--- charted (LED-R54).
---@param world LedgerWorld
---@param state LedgerState
---@param zone integer
---@return integer?
function ns.ZoneCompletion(world, state, zone)
	local zoneIndex = world.zones[zone]
	if not zoneIndex then
		return nil
	end
	local needs = needsOf(zoneIndex, state.zones[zone])
	return math.floor(100 * needs.done / needs.needed)
end

--- A charted zone's catches counted against its list (LED-R135, LED-R137): its listed Species and those caught there,
--- its families and those landed there; nil for a zone that isn't charted (LED-R54).
---@param world LedgerWorld
---@param state LedgerState
---@param zone integer
---@return LedgerZoneCounts?
function ns.ZoneCounts(world, state, zone)
	local zoneIndex = world.zones[zone]
	return zoneIndex and needsOf(zoneIndex, state.zones[zone]).counts
end

--- The next requirement (LED-R134), from the shown rank: what the rank above it still needs beyond the shown rank's
--- own requirements, with new to find appended (for Master, in place of "Master of these waters"). nil for a zone
--- that isn't charted (LED-R54). When new to find leaves the rank above needing nothing more of its own, the line is
--- new to find alone.
---@param world LedgerWorld
---@param state LedgerState
---@param celebrated LedgerCelebrated
---@param zone integer
---@return string?
function ns.NextRequirement(world, state, celebrated, zone)
	local zoneIndex = world.zones[zone]
	if not zoneIndex then
		return nil
	end
	local L = ns.L
	local shown = ns.ShownZoneRank(world, state, celebrated, zone)
	local needs = needsOf(zoneIndex, state.zones[zone])
	local missing = needs.missing
	---@type string?
	local line
	if shown == 0 then
		line = L.ZONE_NEXT_VISITOR
	elseif shown == VISITOR and missing[REGULAR] > 0 then
		line = ns.CountText(missing[REGULAR], L.ZONE_NEXT_REGULAR_ONE, L.ZONE_NEXT_REGULAR_OTHER)
	elseif shown == REGULAR and missing[LOCAL] > 0 then
		line = ns.CountText(missing[LOCAL], L.ZONE_NEXT_LOCAL_ONE, L.ZONE_NEXT_LOCAL_OTHER)
	elseif shown == LOCAL and missing[EXPERT] > 0 then
		local parts = {}
		if needs.gated > 0 then
			parts[#parts + 1] = ns.CountText(needs.gated, L.ZONE_NEXT_GATED_ONE, L.ZONE_NEXT_GATED_OTHER)
		end
		if needs.junk then
			parts[#parts + 1] = L.ZONE_NEXT_JUNK
		end
		if needs.treasure then
			parts[#parts + 1] = L.ZONE_NEXT_TREASURE
		end
		line = L.ZONE_NEXT_EXPERT:format(table.concat(parts, L.ZONE_NEXT_SEPARATOR))
	elseif shown == EXPERT and missing[MASTER] > 0 then
		line = ns.CountText(missing[MASTER], L.ZONE_NEXT_MASTER_ONE, L.ZONE_NEXT_MASTER_OTHER)
	end
	local newToFind = ns.NewToFind(world, state, celebrated, zone)
	if newToFind > 0 then
		local found = ns.CountText(newToFind, L.ZONE_NEW_TO_FIND_ONE, L.ZONE_NEW_TO_FIND_OTHER)
		return line and L.ZONE_NEXT_WITH_NEW:format(line, found) or found
	end
	return line or L.ZONE_NEXT_MASTERED
end
