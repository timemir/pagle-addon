if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Which Catches qualify for a Hunt (HNT-R10–R14, HNT-R196), and what they do to its count, tiers and completion
-- (HNT-R15–R17), with the tier trims (HNT-R18). Pure logic: Core's calls and the Hunt list's classes come in as lookups
-- (CORE-R7). The projection's apply (logic/Projection.lua) calls CountCatches for every Hunt that exists at each Cast.

--- What the rules read besides the Hunt and the Cast: Core's `Pagle.GetItem` (LOG-R55) and
--- `Pagle.MatchesConditions` (LOG-R49), and the Hunt list's class members (`ns.hunts:Class`, HNT-R12), which is the
--- only place class membership comes from.
---@class HuntsLookups
---@field GetItem fun(itemID: integer): PagleItem?
---@field MatchesConditions fun(spec: table, snapshot: table): boolean
---@field Class fun(classID: string): table<integer, true>?

--- Every read Hunts makes of Core's catalogue and rules, as one table (ADR 0001: through Pagle.* only): Where's
--- (HuntsWaterLookups, HNT-R30–R34) and the rules' (HuntsLookups), the class members from the Hunt list.
---@class HuntsCoreLookups: HuntsLookups, HuntsWaterLookups

--- Hunts' lookups over `core` (Pagle) and `list`: adapter/Hunts.lua builds them once at OnInitialize, and the specs
--- the same way.
---@param core table Pagle
---@param list HuntList
---@return HuntsCoreLookups
function ns.NewLookups(core, list)
	return {
		GetItem = core.GetItem,
		GetZones = core.GetZones,
		GetZoneCatches = core.GetZoneCatches,
		GetZoneOf = core.GetZoneOf,
		GetArea = core.GetArea,
		GetWindowSpec = core.GetWindowSpec,
		MatchesConditions = core.MatchesConditions,
		Class = function(classID)
			return list:Class(classID)
		end,
	}
end

-- Whether a Catch's item is the Hunt's target (HNT-R10 step 2): its Species for a `species` target (every item of
-- the Species, DATA-R19), or a member of its class for a `class` target (HNT-R12). Item 0 and an Uncharted item
-- match nothing (HNT-R196).
---@param hunt HuntDef
---@param itemID integer
---@param lookups HuntsLookups
---@return boolean
local function isTarget(hunt, itemID, lookups)
	if itemID == 0 then
		return false
	end
	if hunt.species then
		local item = lookups.GetItem(itemID)
		return item ~= nil and item.species == hunt.species
	end
	local members = hunt.class and lookups.Class(hunt.class)
	return members ~= nil and members[itemID] == true
end

--- The Catches of `cast` that qualify for `hunt`, in loot-slot order (HNT-R10, HNT-R15).
---@param hunt HuntDef
---@param cast PagleCast
---@param lookups HuntsLookups
---@return { n: integer, itemID: integer, quantity: integer, catchId: string, size: PagleSize? }[]
function ns.QualifyingCatches(hunt, cast, lookups)
	local out = {}
	-- Step 1: a caught Cast while the Hunt exists, from its since and before its retired (HNT-R2, HNT-R13).
	if cast.outcome ~= "caught" or not ns.Exists(hunt, cast.time) then
		return out
	end
	-- Step 4: an imposed Hunt's own conditions, at the Cast (HNT-R5). A natural Hunt's window is never consulted, so a
	-- wrong window never refuses a real Catch (HNT-R4, HNT-R196).
	if hunt.kind == "imposed" and not lookups.MatchesConditions(hunt.conditions, cast.conditions) then
		return out
	end
	local minBand = hunt.minBand
	for _, catch in ipairs(cast.items) do
		-- Step 3: a size of at least minBand; a Catch without a size never qualifies for such a Hunt (HNT-R14).
		local sized = not minBand or (catch.size ~= nil and catch.size.band >= minBand)
		-- Step 2: the target, items[n] in ascending n (HNT-R15).
		if sized and isTarget(hunt, catch.itemID, lookups) then
			out[#out + 1] = catch
		end
	end
	return out
end

--- A Hunt's progress before anything has counted (hunts.md › Projection state). `effort` and `sinceLast` are the
--- projection's (HNT-R25, HNT-R26); CountCatches leaves them alone.
---@return HuntProgress
function ns.NewHuntProgress()
	return { count = 0, effort = 0, sinceLast = 0, caught = false, reached = {} }
end

--- Counts `cast`'s qualifying Catches for `hunt` into `progress` (HNT-R11): 1 each, whatever its quantity, in
--- loot-slot order. Tier k is reached when the count first reaches `tiers[k]`, and stores the Catch that reached it
--- (HNT-R15); after the last tier the count keeps rising and nothing more is reached (HNT-R16). Returns the tiers newly
--- reached, ascending (empty for none); their HuntTiers are `progress.reached[k]`.
---@param progress HuntProgress
---@param hunt HuntDef
---@param cast PagleCast
---@param lookups HuntsLookups
---@return integer[]
function ns.CountCatches(progress, hunt, cast, lookups)
	local newly = {}
	local conditions = cast.conditions
	for _, catch in ipairs(ns.QualifyingCatches(hunt, cast, lookups)) do
		progress.count = progress.count + 1
		progress.caught = true
		local k = #progress.reached + 1
		local threshold = hunt.tiers[k]
		if threshold and progress.count >= threshold then
			-- A Cast with no realm minute (a secret clock, LOG-R49) has no realm date: its UTC day stands in.
			local date = conditions.date or ns.UtcDate(cast.time)
			progress.reached[k] = {
				time = cast.time,
				catchId = catch.catchId,
				itemID = catch.itemID,
				zone = conditions.zone or 0,
				date = { year = date.year, month = date.month, day = date.day },
			}
			newly[#newly + 1] = k
		end
	end
	return newly
end

--- Whether a Hunt is done: tier 1, its completion, is reached (HNT-R17). `progress` is nil for a Hunt nothing has
--- touched.
---@param progress HuntProgress?
---@return boolean
function ns.HuntDone(progress)
	return progress ~= nil and progress.reached[1] ~= nil
end

--- How many of the Hunts current at `now` are done in `state`, and how many are current (HNT-R2, HNT-R17): every
--- current Hunt's, or set `setID`'s alone. The summary line, an entry's set line and a set's page count with it.
---@param list HuntList
---@param state HuntsState
---@param now integer
---@param setID string?
---@return integer done
---@return integer current
function ns.DoneOfCurrent(list, state, now, setID)
	local done, current = 0, 0
	for _, hunt in ipairs(setID and list:SetHunts(setID) or list:Hunts()) do
		if ns.IsCurrent(hunt, now) then
			current = current + 1
			if ns.HuntDone(state.hunts[hunt.id]) then
				done = done + 1
			end
		end
	end
	return done, current
end

--- Whether a Hunt is finished: every one of its tiers is reached (HNT-R17).
---@param progress HuntProgress?
---@param hunt HuntDef
---@return boolean
function ns.HuntFinished(progress, hunt)
	return progress ~= nil and #progress.reached >= #hunt.tiers
end

--- A tier's trim (HNT-R18, Tunables): tier 1 bronze, tier 2 silver, tier 3 and any later tier gold.
---@param k integer
---@return "bronze"|"silver"|"gold"
function ns.Trim(k)
	if k == 1 then
		return "bronze"
	elseif k == 2 then
		return "silver"
	end
	return "gold"
end

--- The trim a Hunt's icon wears: its highest reached tier's, or nil before tier 1 (HNT-R18).
---@param progress HuntProgress?
---@return ("bronze"|"silver"|"gold")?
function ns.HuntTrim(progress)
	local highest = progress and #progress.reached or 0
	return highest > 0 and ns.Trim(highest) or nil
end
