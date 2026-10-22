if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- Generating a goal (tackle-board.md › Generating a goal, TKB-R30–R35): which zones and Species a new Notice or
-- Expedition may name, which kind it gets, its target, and its need, tier and pay. Pure logic: Core's catalogue calls,
-- the Angler's skill, the clock, the projection's tables and the random source all come in the context (CORE-R7).
-- Generation runs live only (TKB-R21, TKB-R55), so it may draw at random; a rebuild never calls it (TKB-R22), and its
-- weights and needs may change freely for future goals.

-- The Tunables (tackle-board.md › Tunables).

local RECENT_WEIGHT = 8 -- a candidate zone with a Cast in the recent window (TKB-R30)
local OTHER_WEIGHT = 1 -- every other candidate zone (TKB-R30)
local RECENT_WINDOW = 14 * ns.DAY_SECONDS -- seconds before now (TKB-R30)

-- The kinds in the table's order (TKB-R32), which is the order weighted draws walk them in.
local KINDS = { "haul", "variety", "wanderer", "quality", "collector", "lure", "species" }

-- Each kind's weight by goal type (TKB-R32); a kind a type doesn't list is never drawn for it. There is no `size`
-- kind: under a Reach a band goal is out of a new Angler's range and trivial for a veteran's (ADR 0014).
local KIND_WEIGHTS = {
	n = { haul = 2, variety = 2, wanderer = 1, quality = 1, collector = 1, lure = 1, species = 1 },
	e = { haul = 1, variety = 1, wanderer = 1, quality = 1, collector = 1 },
}

local VARIETY_NOTICE_MIN = 3 -- eligible Species a Variety Notice's zone has at least (TKB-R32)
local VARIETY_EXPEDITION_MIN, VARIETY_EXPEDITION_MAX = 4, 12 -- a Variety Expedition's zone's eligible Species (TKB-R32)
local WANDERER_EXPEDITION_ZONES = 5 -- candidate zones a Wanderer Expedition's continent has at least (TKB-R32)
local COLLECTOR_EXPEDITION_ITEMS = 6 -- never-caught Sub-collection items in candidate zones, at least (TKB-R32)

local NOTICE_TIERS = 3 -- a Notice's tier is drawn from 1 to this, unless its kind fixes it (TKB-R34)
local EXPEDITION_TIER = 0 -- TKB-R34; the pay by tier and the Expedition pay are ns.NOTICE_PAY and ns.EXPEDITION_PAY

--- A Notice's need by kind and tier (TKB-R34). The kinds that fix their tier list only that tier.
ns.NOTICE_NEEDS = {
	haul = { 20, 30, 40 },
	variety = { 3, 4, 5 }, -- capped at the zone's eligible Species; the tier follows the need
	wanderer = { [3] = 3 },
	quality = { 3, 5, 8 },
	collector = { [2] = 2 },
	lure = { 15, 20, 25 },
	species = { 5, 10, 15 },
}
local NOTICE_NEEDS = ns.NOTICE_NEEDS
local FIXED_TIERS = { wanderer = 3, collector = 2 } -- the Notice kinds whose tier the table fixes (TKB-R34)

--- An Expedition's need by kind (TKB-R34); a Variety Expedition's is its stored Species.
ns.EXPEDITION_NEEDS = { haul = 150, wanderer = 5, quality = 3, collector = 3 }
local EXPEDITION_NEEDS = ns.EXPEDITION_NEEDS

local QUALITY_TARGETS = { n = 2, e = 3 } -- uncommon for Notices, rare for Expeditions (TKB-R34)

-- The Sub-collection item categories (TKB-R46).
local SUB_COLLECTION = { junk = true, container = true, treasure = true, trophy = true }

--- What generation reads (TKB-R30–R36). `ns.GenerationContext` (adapter/Generate.lua) builds it live.
---@class TackleCatalogueCalls       -- the Core calls generation reads (catch-log.md › Contracts)
---@field GetZones fun(): integer[]
---@field GetArea fun(areaID: integer): table?
---@field GetZoneCatches fun(zone: integer): table[]
---@field GetItem fun(itemID: integer): table?

---@class TackleGenerationContext
---@field pagle TackleCatalogueCalls
---@field bestBaseSkill integer       -- Pagle.GetAngler().bestBaseSkill (LOG-R27)
---@field now integer                 -- server time
---@field zones { [integer]: integer } -- the projection's zone areaID -> time of the Angler's last Cast there
---@field caught { [integer]: true }  -- the projection's every item ID ever caught (TKB-R46)
---@field open TackleGoalDef[]        -- the open goals of every type
---@field random fun(m: integer, n: integer): integer -- like math.random

---@class TackleCandidateZone
---@field zone integer                -- the zone's areaID
---@field weight integer              -- TKB-R30
---@field continent integer           -- GetArea(zone).continent, the continent's instance map ID

--- The candidate zones (TKB-R30), ascending by areaID: zones with catch data and a skillBase at or below the Angler's
--- best base skill, weighted by whether the Angler cast there within the recent window before now.
---@param ctx TackleGenerationContext
---@return TackleCandidateZone[]
function ns.CandidateZones(ctx)
	local candidates = {}
	for _, zone in ipairs(ctx.pagle.GetZones()) do
		local area = ctx.pagle.GetArea(zone)
		if area and area.hasData and area.skillBase and area.skillBase <= ctx.bestBaseSkill then
			local last = ctx.zones[zone]
			local recent = last ~= nil and ctx.now - last <= RECENT_WINDOW
			local weight = recent and RECENT_WEIGHT or OTHER_WEIGHT
			candidates[#candidates + 1] = { zone = zone, weight = weight, continent = area.continent }
		end
	end
	return candidates
end

---@class TackleSpecies
---@field species integer             -- the Species ID (the items' `species`)
---@field item integer                -- its representative item: the lowest eligible item ID in the zone (TKB-R31)

--- A zone's eligible Species (TKB-R31), ascending by representative item: one per Species among the zone's and its
--- subzones' ungated entries whose item is a fish that isn't a Legend, Noise or removed. `confirmed` doesn't matter.
---@param pagle TackleCatalogueCalls Core's catalogue calls
---@param zone integer the zone's areaID
---@return TackleSpecies[]
function ns.EligibleSpecies(pagle, zone)
	local lowest = {} -- species -> lowest eligible item
	for _, entry in ipairs(pagle.GetZoneCatches(zone)) do
		local item = entry.gate == nil and pagle.GetItem(entry.itemID)
		if
			item
			and item.category == "fish"
			and item.species
			and not item.legend
			and not item.noise
			and not item.removed
		then
			local known = lowest[item.species]
			if not known or entry.itemID < known then
				lowest[item.species] = entry.itemID
			end
		end
	end
	local species = {}
	for id, itemID in pairs(lowest) do
		species[#species + 1] = { species = id, item = itemID }
	end
	table.sort(species, function(a, b)
		return a.item < b.item
	end)
	return species
end

-- Whether `item` is a Sub-collection item (TKB-R46).
---@param item table? Pagle.GetItem's record, nil for an Uncharted item
---@return boolean
local function isSubCollection(item)
	return item ~= nil and SUB_COLLECTION[item.category] == true and not item.noise and not item.removed
end

-- What the candidate zones offer, worked out once per goal.
---@class TackleSurvey
---@field candidates TackleCandidateZone[]
---@field species { [integer]: TackleSpecies[] }  -- each candidate zone's eligible Species
---@field continents integer[]                    -- ascending: named in ns.CONTINENT_MAPS, with enough candidate zones
---@field uncaught integer                        -- never-caught Sub-collection items in candidate zones' catch lists

---@param ctx TackleGenerationContext
---@return TackleSurvey
local function survey(ctx)
	local candidates = ns.CandidateZones(ctx)
	local species, perContinent, uncaught, uncaughtCount = {}, {}, {}, 0
	for _, candidate in ipairs(candidates) do
		local zone = candidate.zone
		species[zone] = ns.EligibleSpecies(ctx.pagle, zone)
		local continent = candidate.continent
		perContinent[continent] = (perContinent[continent] or 0) + 1
		-- Gated entries included (TKB-R32).
		for _, entry in ipairs(ctx.pagle.GetZoneCatches(zone)) do
			local itemID = entry.itemID
			if not uncaught[itemID] and not ctx.caught[itemID] and isSubCollection(ctx.pagle.GetItem(itemID)) then
				uncaught[itemID] = true
				uncaughtCount = uncaughtCount + 1
			end
		end
	end
	local continents = {}
	for continent in pairs(ns.CONTINENT_MAPS) do
		if (perContinent[continent] or 0) >= WANDERER_EXPEDITION_ZONES then
			continents[#continents + 1] = continent
		end
	end
	table.sort(continents)
	return { candidates = candidates, species = species, continents = continents, uncaught = uncaughtCount }
end

-- The candidate zones with from `min` to `max` eligible Species.
---@param found TackleSurvey
---@param min integer
---@param max integer?
---@return TackleCandidateZone[]
local function zonesWithSpecies(found, min, max)
	local zones = {}
	for _, candidate in ipairs(found.candidates) do
		local count = #found.species[candidate.zone]
		if count >= min and (max == nil or count <= max) then
			zones[#zones + 1] = candidate
		end
	end
	return zones
end

local ELIGIBLE = { true } -- the options of an eligible kind without a target to draw

-- The targets each kind may draw from (TKB-R32, TKB-R33): candidate zones, continents, or ELIGIBLE; none when the
-- kind isn't eligible.
---@type { [TackleGoalKind]: fun(found: TackleSurvey, goalType: TackleGoalType): table[] }
local OPTIONS = {
	haul = function(found)
		return found.candidates
	end,
	variety = function(found, goalType)
		if goalType == "n" then
			return zonesWithSpecies(found, VARIETY_NOTICE_MIN)
		end
		return zonesWithSpecies(found, VARIETY_EXPEDITION_MIN, VARIETY_EXPEDITION_MAX)
	end,
	wanderer = function(found, goalType)
		return goalType == "n" and ELIGIBLE or found.continents
	end,
	quality = function()
		return ELIGIBLE
	end,
	collector = function(found, goalType)
		return (goalType == "n" or found.uncaught >= COLLECTOR_EXPEDITION_ITEMS) and ELIGIBLE or {}
	end,
	lure = function()
		return ELIGIBLE
	end,
	species = function(found)
		return zonesWithSpecies(found, 1)
	end,
}

-- Draws one entry of `list` by `weightOf(entry)`, walking it in order.
---@generic T
---@param random fun(m: integer, n: integer): integer
---@param list T[]
---@param weightOf fun(entry: T): integer
---@return T
local function draw(random, list, weightOf)
	local total = 0
	for _, entry in ipairs(list) do
		total = total + weightOf(entry)
	end
	local roll = random(1, total)
	for _, entry in ipairs(list) do
		roll = roll - weightOf(entry)
		if roll <= 0 then
			return entry
		end
	end
	return list[#list]
end

local function zoneWeight(candidate)
	return candidate.weight
end

local function uniform()
	return 1
end

local function itself(value)
	return value
end

-- The entries of `list` whose `key(entry)` isn't in `taken`, or all of `list` if that leaves none (TKB-R32, TKB-R33).
---@generic T
---@param list T[]
---@param taken { [any]: true }
---@param key fun(entry: T): any
---@return T[]
local function avoiding(list, taken, key)
	local left = {}
	for _, entry in ipairs(list) do
		if not taken[key(entry)] then
			left[#left + 1] = entry
		end
	end
	return #left > 0 and left or list
end

-- The targets (or kinds, with `field` "kind") the open goals of `goalType`, and of `kind` if given, already have.
---@param ctx TackleGenerationContext
---@param goalType TackleGoalType
---@param kind TackleGoalKind?
---@param field "kind"|"target"
---@return { [any]: true }
local function openSet(ctx, goalType, kind, field)
	local taken = {}
	for _, goal in ipairs(ctx.open) do
		if goal.type == goalType and (kind == nil or goal.kind == kind) and goal[field] ~= nil then
			taken[goal[field]] = true
		end
	end
	return taken
end

-- Picks the kind (TKB-R32): of the type's eligible kinds but `dropKind`, the ones not already open in the type (all
-- of them if each is), by weight.
---@param ctx TackleGenerationContext
---@param found TackleSurvey
---@param goalType TackleGoalType
---@param dropKind TackleGoalKind?
---@return TackleGoalKind kind
---@return table[] options its targets (OPTIONS)
local function pickKind(ctx, found, goalType, dropKind)
	local weights = KIND_WEIGHTS[goalType]
	local allowed, options = {}, {}
	for _, kind in ipairs(KINDS) do
		if weights[kind] and kind ~= dropKind then
			local offered = OPTIONS[kind](found, goalType)
			if #offered > 0 then
				allowed[#allowed + 1] = kind
				options[kind] = offered
			end
		end
	end
	local kind = draw(ctx.random, avoiding(allowed, openSet(ctx, goalType, nil, "kind"), itself), function(k)
		return weights[k]
	end)
	return kind, options[kind]
end

-- Draws a Species goal's target (TKB-R33): a zone by weight among `zones` with an eligible Species that no open
-- Species goal of the type names (compared by `species`), then one of those Species uniformly; with every Species
-- named already, among all of them again.
---@param ctx TackleGenerationContext
---@param found TackleSurvey
---@param goalType TackleGoalType
---@param zones TackleCandidateZone[]
---@return TackleSpecies
local function drawSpecies(ctx, found, goalType, zones)
	local named = {}
	for item in pairs(openSet(ctx, goalType, "species", "target")) do
		local record = ctx.pagle.GetItem(item)
		if record and record.species then
			named[record.species] = true
		end
	end
	local fresh = {}
	for _, candidate in ipairs(zones) do
		local left = {}
		for _, entry in ipairs(found.species[candidate.zone]) do
			if not named[entry.species] then
				left[#left + 1] = entry
			end
		end
		if #left > 0 then
			fresh[#fresh + 1] = { zone = candidate.zone, weight = candidate.weight, species = left }
		end
	end
	if #fresh == 0 then
		for _, candidate in ipairs(zones) do
			fresh[#fresh + 1] =
				{ zone = candidate.zone, weight = candidate.weight, species = found.species[candidate.zone] }
		end
	end
	local zone = draw(ctx.random, fresh, zoneWeight)
	return draw(ctx.random, zone.species, uniform)
end

-- Draws a zone by weight among `zones` that no open goal of the type and kind targets, or among all of them if each
-- is targeted (TKB-R33).
---@param ctx TackleGenerationContext
---@param goalType TackleGoalType
---@param kind TackleGoalKind
---@param zones TackleCandidateZone[]
---@return integer zone
local function drawZone(ctx, goalType, kind, zones)
	local taken = openSet(ctx, goalType, kind, "target")
	return draw(
		ctx.random,
		avoiding(zones, taken, function(candidate)
			return candidate.zone
		end),
		zoneWeight
	).zone
end

--- Generates a goal definition (TKB-R30–R35): the kind (TKB-R32), its target (TKB-R33), then its need, tier and pay
--- (TKB-R34). On a reroll, `dropKind` is the old goal's kind, never drawn again (TKB-R55). Draws from ctx.random in
--- that order: the kind, the target's zone or continent, a Species goal's Species, a Notice's tier.
---@param ctx TackleGenerationContext
---@param goalType TackleGoalType
---@param dropKind TackleGoalKind?
---@return TackleGoalDef
function ns.GenerateGoal(ctx, goalType, dropKind)
	local found = survey(ctx)
	local kind, options = pickKind(ctx, found, goalType, dropKind)
	local target ---@type integer?
	local items ---@type integer[]?
	local zoneSpecies -- a Variety goal's zone's eligible Species count
	if kind == "haul" then
		target = drawZone(ctx, goalType, kind, options)
	elseif kind == "variety" then
		target = drawZone(ctx, goalType, kind, options)
		local species = found.species[target]
		zoneSpecies = #species
		if goalType == "e" then
			items = {}
			for i, entry in ipairs(species) do
				items[i] = entry.item -- ascending, as EligibleSpecies lists them
			end
		end
	elseif kind == "wanderer" and goalType == "e" then
		target = draw(ctx.random, avoiding(options, openSet(ctx, goalType, kind, "target"), itself), uniform) --[[@as integer]]
	elseif kind == "quality" then
		target = QUALITY_TARGETS[goalType]
	elseif kind == "species" then
		target = drawSpecies(ctx, found, goalType, options).item
	end

	if goalType == "e" then
		local need = items and #items or EXPEDITION_NEEDS[kind]
		return {
			type = goalType,
			kind = kind,
			tier = EXPEDITION_TIER,
			pay = ns.EXPEDITION_PAY,
			need = need,
			target = target,
			items = items,
		}
	end
	local needs = NOTICE_NEEDS[kind]
	local tier = FIXED_TIERS[kind] or ctx.random(1, NOTICE_TIERS)
	local need = needs[tier]
	if zoneSpecies and need > zoneSpecies then
		-- A Variety Notice asks for at most the zone's Species, and its tier follows the need (TKB-R34).
		need = zoneSpecies
		for t, n in pairs(needs) do
			if n == need then
				tier = t
			end
		end
	end
	return { type = goalType, kind = kind, tier = tier, pay = ns.NOTICE_PAY[tier], need = need, target = target }
end
