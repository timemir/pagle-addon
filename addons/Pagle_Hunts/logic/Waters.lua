if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Where a Hunt bites (HNT-R6, HNT-R7, HNT-R30–R34): pure logic over the catalogue calls passed in (CORE-R7). The
-- adapter builds it once, at OnInitialize, as `ns.where[huntID]`; nothing here is worked out per Cast (HNT-R137).

--- The catalogue calls where-it-bites reads (LOG-R55): Core's own, as Pagle publishes them.
---@class HuntsWaterLookups
---@field GetItem fun(itemID: integer): PagleItem?
---@field GetZones fun(): integer[]
---@field GetZoneCatches fun(zoneAreaID: integer): PagleZoneCatchEntry[]?
---@field GetZoneOf fun(areaID: integer): integer?
---@field GetArea fun(areaID: integer): PagleArea?
---@field GetWindowSpec fun(windowID: string): PagleWindowSpec?

--- Where one Hunt bites, worked out at load.
---@class HuntWhere
---@field boardSpec table?      -- the condition spec that drives the board (HNT-R6); nil per HNT-R7
---@field unconfirmedWindow "window"|"gating"|nil   -- a natural Hunt's own reason to be unconfirmed (HNT-R34)
---@field waters integer[]      -- areaIDs, ascending (HNT-R30); empty when it has none
---@field isWater table<integer, true>   -- the same areaIDs as a set, for ns.InWaters
---@field places integer[]      -- its waters, or its `areas` as listed (HNT-R31)
---@field zones integer[]       -- its places' zones, without duplicates, ascending (HNT-R31)
---@field skillNeed integer?    -- HNT-R32; nil when it has none

---@class PagleHuntsNS
---@field where table<string, HuntWhere>   -- by Hunt ID, built at OnInitialize (HNT-R137)

-- The areaIDs of a set, ascending.
---@param set table<integer, true>
---@return integer[]
local function sorted(set)
	local list = {}
	for areaID in pairs(set) do
		list[#list + 1] = areaID
	end
	table.sort(list)
	return list
end

-- Which catch entries make a Hunt's waters (HNT-R30), or nil for a Hunt that has none by rule: one with `areas`,
-- or a generated class target (only `fixed.*` classes are walked).
---@param hunt HuntDef
---@param list HuntList
---@param getItem fun(itemID: integer): PagleItem?
---@return (fun(entry: PagleZoneCatchEntry): boolean)?
local function watersTest(hunt, list, getItem)
	local function ofSpecies(entry)
		local item = getItem(entry.itemID)
		return item ~= nil and item.species == hunt.species
	end
	if hunt.kind == "natural" then
		-- Its Species, by its own window: a natural Hunt targets a Species (DATA-R86).
		return function(entry)
			return entry.window == hunt.window and ofSpecies(entry)
		end
	end
	if hunt.conditions and hunt.conditions.areas then
		return nil
	end
	if hunt.species then
		return ofSpecies
	end
	if hunt.class and hunt.class:sub(1, 6) == "fixed." then
		local members = list:Class(hunt.class) or {}
		return function(entry)
			return members[entry.itemID] == true
		end
	end
	return nil
end

-- The zones of a Hunt's places, without duplicates, ascending (HNT-R31). A place outside the slice has none.
---@param places integer[]
---@param getZoneOf fun(areaID: integer): integer?
---@return integer[]
local function zonesOf(places, getZoneOf)
	local zones = {}
	for _, areaID in ipairs(places) do
		local zone = getZoneOf(areaID)
		if zone then
			zones[zone] = true
		end
	end
	return sorted(zones)
end

-- A Hunt's skill need (HNT-R32): the larger of the lowest skill base among its places (an area's own, else its
-- zone's; places with neither skipped) and its `skill.min`; nil when it has neither, or it is 0 or less.
---@param places integer[]
---@param skill { min: integer }?
---@param lookups HuntsWaterLookups
---@return integer?
local function skillNeedOf(places, skill, lookups)
	local lowest
	for _, areaID in ipairs(places) do
		local area = lookups.GetArea(areaID)
		local base = area and area.skillBase
		if area and not base then
			local zone = lookups.GetZoneOf(areaID)
			local zoneArea = zone and lookups.GetArea(zone)
			base = zoneArea and zoneArea.skillBase
		end
		if base and (not lowest or base < lowest) then
			lowest = base
		end
	end
	local need = math.max(lowest or 0, skill and skill.min or 0)
	if need <= 0 then
		return nil
	end
	return need
end

-- A Hunt's board spec (HNT-R6): a natural Hunt's window spec, carrying its `confirmed`, or nil when the window has
-- none (HNT-R7); an imposed Hunt's own conditions.
---@param hunt HuntDef
---@param getWindowSpec fun(windowID: string): PagleWindowSpec?
---@return table?
local function boardSpecOf(hunt, getWindowSpec)
	if hunt.kind == "natural" then
		return getWindowSpec(hunt.window)
	end
	return hunt.conditions
end

--- Where every Hunt of `list` bites, by Hunt ID, Retired Hunts and Hunts not yet out included (HNT-R30).
---@param list HuntList
---@param lookups HuntsWaterLookups
---@return table<string, HuntWhere>
function ns.NewWhere(list, lookups)
	-- Every catch entry of the catalogue, walked once (HNT-R30).
	local entries = {}
	for _, zone in ipairs(lookups.GetZones()) do
		for _, entry in ipairs(lookups.GetZoneCatches(zone) or {}) do
			entries[#entries + 1] = entry
		end
	end

	local where = {}
	for _, hunt in ipairs(list:Hunts()) do
		local waters, gateConfirmed = {}, false
		local test = watersTest(hunt, list, lookups.GetItem)
		if test then
			for _, entry in ipairs(entries) do
				if test(entry) then
					waters[entry.areaID] = true
					gateConfirmed = gateConfirmed or entry.gateConfirmed == true
				end
			end
		end
		local conditions = hunt.conditions or {}
		local waterList = sorted(waters)
		local places = conditions.areas and { unpack(conditions.areas) } or waterList
		local boardSpec = boardSpecOf(hunt, lookups.GetWindowSpec)
		local unconfirmed
		if hunt.kind == "natural" and boardSpec then
			if boardSpec.confirmed == false then
				unconfirmed = "window"
			elseif not gateConfirmed then
				unconfirmed = "gating"
			end
		end
		where[hunt.id] = {
			boardSpec = boardSpec,
			waters = waterList,
			isWater = waters,
			places = places,
			zones = zonesOf(places, lookups.GetZoneOf),
			skillNeed = skillNeedOf(places, conditions.skill, lookups),
			unconfirmedWindow = unconfirmed,
		}
	end
	return where
end

--- Why the Hunt is unconfirmed (HNT-R34), or nil when it isn't: "window" when its window or a weekly rule its
--- forecast read is unconfirmed (the window is an estimate), "gating" when only its gating is (a natural Hunt none of
--- whose waters' entries has gateConfirmed). `window` is the Hunt's NextWindow result now, nil when there is none.
--- A Hunt without a board spec is never unconfirmed (HNT-R7). Reads `ns.where`.
---@param hunt HuntDef
---@param window Window?
---@return "window"|"gating"|nil
function ns.Unconfirmed(hunt, window)
	local where = ns.where[hunt.id]
	if not where.boardSpec then
		return nil
	end
	if window and window.confirmed == false then
		return "window"
	end
	return where.unconfirmedWindow
end

--- Tunables (hunts.md): how far a lure's skill bonus reaches, for "A lure gets me there." (HNT-R33, HNT-R52).
ns.LURE_REACH = 100

--- Whether a skill need is short of skill (HNT-R33): above the Angler's best, and whether by at most the lure reach.
---@param need integer? the Hunt's skill need (HNT-R32); nil with none
---@param best integer the Angler's bestBaseSkill
---@return boolean short
---@return boolean lureGetsThere -- short by at most the lure reach
function ns.SkillShortfall(need, best)
	if not need or need <= best then
		return false, false
	end
	return true, need - best <= ns.LURE_REACH
end

--- Whether the Angler is short of skill for the Hunt (HNT-R33): it has a skill need above the Angler's
--- bestBaseSkill. A function of the Angler, which changes at runtime (SkillChanged). Reads `ns.where`.
---@param hunt HuntDef
---@param angler { bestBaseSkill: integer } Pagle.GetAngler()
---@return boolean short
---@return boolean lureGetsThere -- short by at most the lure reach
function ns.ShortOfSkill(hunt, angler)
	return ns.SkillShortfall(ns.where[hunt.id].skillNeed, angler.bestBaseSkill)
end

--- Whether a Cast was fished in the Hunt's waters (HNT-R25, HNT-R30): its subzone or zone is one of them. A Hunt
--- without waters holds everywhere (its `areas`, if any, constrain it through MatchesConditions), except a natural
--- Hunt, whose waters the data left empty: it has no effort Casts. Reads `ns.where`, built at load.
---@param hunt HuntDef
---@param cast { conditions: { zone: integer?, subzone: integer? } }
---@return boolean
function ns.InWaters(hunt, cast)
	local where = ns.where[hunt.id]
	if #where.waters == 0 then
		return hunt.kind ~= "natural"
	end
	local conditions = cast.conditions
	return where.isWater[conditions.subzone] == true or where.isWater[conditions.zone] == true
end
