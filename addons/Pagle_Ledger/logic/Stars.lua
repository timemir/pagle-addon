if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- Species Mastery and trophy family stars (LED-R45–R48): three stars per Species and three per trophy family, each
-- earned on its own. They are computed from the projection state and the world index when needed and never stored
-- (ledger.md › Data); the fold keeps only each Species' element windows met, and earns the star achievements here.
-- Pure logic, Core's lookups passed in (CORE-R7). Stars come from Catches only, never from a Simulated Size (LED-R46).

--- Which of a Species' or family's three stars are inked: `{ [1|2|3] = true }`, the celebrated set's shape (LED-R90).
---@alias LedgerStars { [integer]: true }

-- ★★ zones needed, and ★★★ Catches (LED-R45, Tunables).
local ZONES_NEEDED = 3
--- A Species' ★★★ Catches (LED-R45, Tunables); Home's next-star note counts down to it (LED-R133).
ns.REGULAR_CATCHES = 50
local REGULAR_CATCHES = ns.REGULAR_CATCHES

-- The achievement a Species' ★★ and ★★★ earn (LED-R97).
local SPECIES_STAR_KINDS = { [2] = "elementStar", [3] = "regularStar" }

-- Whether a caught Species is in its element (LED-R45): under each of its element windows when it has some, else
-- caught in `min(3, max(1, listed zones))` distinct zones (`zones` never holds 0, LED-R6).
---@param listing LedgerWorldSpecies? the Species in the world index, nil when on no list
---@param species LedgerSpecies
---@return boolean
local function inElement(listing, species)
	local elements = listing and listing.elements
	if elements then
		local met = species.windowsMet or {}
		for window in pairs(elements) do
			if not met[window] then
				return false
			end
		end
		return true
	end
	local needed = math.min(ZONES_NEEDED, math.max(1, listing and #listing.zones or 0))
	local caught = 0
	for _ in pairs(species.zones) do
		caught = caught + 1
	end
	return caught >= needed
end

--- A Species' computed stars (LED-R45): ★ caught, ★★ in its element, ★★★ 50 Catches.
---@param world LedgerWorld
---@param state LedgerState
---@param id integer the Species ID
---@return LedgerStars
function ns.SpeciesStars(world, state, id)
	local stars = {}
	local species = state.species[id]
	if species then
		stars[1] = true
		stars[2] = inElement(world.species[id], species) or nil
		stars[3] = species.n >= REGULAR_CATCHES or nil
	end
	return stars
end

--- A trophy family's computed stars (LED-R47): ★ any of its trophy items landed, listed or not; ★★ at least
--- `ceil(n / 2)` of its `n` listed weights landed; ★★★ its heaviest listed weight landed. Without a listed weight
--- (`n` = 0) only ★ can be earned.
---@param world LedgerWorld
---@param state LedgerState
---@param family integer
---@return LedgerStars
function ns.FamilyStars(world, state, family)
	local getItem = world.getItem
	local stars = {}
	for itemID in pairs(state.items) do
		local item = getItem(itemID)
		if item and item.category == "trophy" and item.family == family then
			stars[1] = true
			break
		end
	end
	local listed = world.families[family]
	if listed then
		local landed = 0
		for _, itemID in ipairs(listed.weights) do
			if state.items[itemID] then
				landed = landed + 1
			end
		end
		stars[2] = landed >= math.ceil(#listed.weights / 2) or nil
		stars[3] = state.items[listed.heaviest] and true or nil
	end
	return stars
end

-- The union of computed stars and celebrated ones (LED-R48): each star on its own.
---@param computed LedgerStars
---@param celebrated LedgerStars?
---@return LedgerStars
local function union(computed, celebrated)
	for star in pairs(celebrated or {}) do
		computed[star] = true
	end
	return computed
end

--- A Species' shown stars (LED-R48, LED-R92): its computed stars and the celebrated ones, `celebrated.stars`
--- (LED-R90), so a star once celebrated never goes blank.
---@param world LedgerWorld
---@param state LedgerState
---@param celebrated table the celebrated set (LED-R90): its `stars`, if any
---@param id integer the Species ID
---@return LedgerStars
function ns.ShownSpeciesStars(world, state, celebrated, id)
	return union(ns.SpeciesStars(world, state, id), celebrated.stars and celebrated.stars[id])
end

--- A trophy family's shown stars (LED-R48, LED-R92): its computed stars and the celebrated ones,
--- `celebrated.familyStars` (LED-R90), so a family whose `n` grew with the data keeps a star already celebrated.
---@param world LedgerWorld
---@param state LedgerState
---@param celebrated table the celebrated set (LED-R90): its `familyStars`, if any
---@param family integer
---@return LedgerStars
function ns.ShownFamilyStars(world, state, celebrated, family)
	local familyStars = celebrated.familyStars
	return union(ns.FamilyStars(world, state, family), familyStars and familyStars[family])
end

--- The stars a Catch could change, as they stood before it: its Species', or its trophy family's when it lands a
--- weight for the first time. Nil for any other Catch.
---@class LedgerStarsMark
---@field species? integer   -- the Species ID
---@field family? integer    -- the trophy family
---@field itemID integer     -- the item caught
---@field stars LedgerStars  -- the computed stars before the Catch

--- The fold's part in the stars (LED-R45, LED-R47): `mark` before a Catch is credited, `credit` after, which keeps the
--- Species' element windows met and appends an achievement for each star the Catch newly computes.
---@class LedgerStarsFold
---@field mark fun(state: LedgerState, class: string, itemID: integer, item: PagleItem?): LedgerStarsMark?
---@field credit fun(state: LedgerState, record: PagleCast, mark: LedgerStarsMark?, earned: LedgerAchievement[])

--- The stars' part of the fold over its lookups (LED-R3): the world index, which changes only with the catalogue
--- (LED-R10), and Core's `Pagle.MatchesConditions`.
---@param lookups LedgerLookups
---@return LedgerStarsFold
function ns.NewStarsFold(lookups)
	local world, matches = lookups.world, lookups.MatchesConditions

	---@param state LedgerState
	---@param class string the Catch's class (LED-R5)
	---@param itemID integer
	---@param item PagleItem?
	---@return LedgerStarsMark?
	local function mark(state, class, itemID, item)
		if not item then
			return nil
		elseif class == "species" then
			local id = item.species --[[@as integer]]
			return { species = id, itemID = itemID, stars = ns.SpeciesStars(world, state, id) }
		elseif class == "trophy" and not state.items[itemID] then
			local family = item.family --[[@as integer]]
			return { family = family, itemID = itemID, stars = ns.FamilyStars(world, state, family) }
		end
		return nil
	end

	-- Each of the Species' element windows this Catch is under (LED-R45), judged against the window's spec in any zone.
	---@param species LedgerSpecies
	---@param id integer
	---@param record PagleCast
	local function meetWindows(species, id, record)
		local met = species.windowsMet
		if not met then
			met = {}
			species.windowsMet = met
		end
		local listing = world.species[id]
		for window, spec in pairs(listing and listing.elements or {}) do
			if not met[window] and matches(spec, record.conditions) then
				met[window] = true
			end
		end
	end

	---@param state LedgerState
	---@param record PagleCast
	---@param marked LedgerStarsMark?
	---@param earned LedgerAchievement[]
	local function credit(state, record, marked, earned)
		if not marked then
			return
		end
		local before = marked.stars
		local id = marked.species
		if id then
			meetWindows(state.species[id], id, record)
			local after = ns.SpeciesStars(world, state, id)
			-- ★ has no achievement of its own: the New Species moment covers it (LED-R97).
			for star = 2, 3 do
				if after[star] and not before[star] then
					earned[#earned + 1] = {
						kind = SPECIES_STAR_KINDS[star],
						cast = record.id,
						coins = 0,
						species = id,
						itemID = marked.itemID,
					}
				end
			end
			return
		end
		local family = marked.family --[[@as integer]]
		local after = ns.FamilyStars(world, state, family)
		local stars = {}
		for star = 2, 3 do
			if after[star] and not before[star] then
				stars[#stars + 1] = star
			end
		end
		if #stars > 0 then
			earned[#earned + 1] = { kind = "familyStar", cast = record.id, coins = 0, family = family, stars = stars }
		end
	end

	return { mark = mark, credit = credit }
end
