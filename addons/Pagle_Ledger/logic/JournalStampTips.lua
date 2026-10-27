if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The tooltips on the three stamps of a caught Species' entry and of a trophy family's entry (LED-R165): each is a
-- short rule and where the Angler stands. Pure logic over the world index and the state (CORE-R7), as data; the
-- Journal's stamps widget shows them (adapter/JournalWidgets.lua). A Species that is not caught has no stamps, so no
-- tips, and the tips of a caught one name no other Species (LED-R124).

--- A stamp's tooltip: its title, the stamp's own word, then its lines, the rule first.
---@class LedgerStampTip
---@field title string
---@field lines string[]

--- The singular form `one` when `n` is 1, else `other`, either one formatted with `...`.
---@param n integer
---@param one string
---@param other string
---@param ... any
---@return string
local function counted(n, one, other, ...)
	return (n == 1 and one or other):format(...)
end

--- "Land it {n} times." and "{have} of {n} landed.", for the stars that count Catches (LED-R45): ★ and ★★★.
---@param title string
---@param species LedgerSpecies
---@param need integer
---@return LedgerStampTip
local function landTip(title, species, need)
	local L = ns.L
	return {
		title = title,
		lines = {
			counted(need, L.STAMP_TIP_LAND_ONE, L.STAMP_TIP_LAND_OTHER, need),
			L.STAMP_TIP_LANDED:format(math.min(species.n, need), need),
		},
	}
end

--- ★★'s lines (LED-R45): with element windows, each is named, the ones still to be met or, once all are, all of them;
--- without, the zones it is caught in of the zones needed.
---@param listing LedgerWorldSpecies?
---@param species LedgerSpecies
---@param text LedgerJournalText
---@return string[]
local function elementLines(listing, species, text)
	local L = ns.L
	local have, need = ns.ElementProgress(listing, species)
	if listing and listing.elements then
		local met, missing, all = species.windowsMet or {}, {}, {}
		for _, window in ipairs(ns.SortedKeys(listing.elements)) do
			local label = text:WindowLabel(window)
			all[#all + 1] = label
			if not met[window] then
				missing[#missing + 1] = label
			end
		end
		local rule = need == 1 and L.STAMP_TIP_ELEMENT_WINDOW or L.STAMP_TIP_ELEMENT_WINDOWS:format(need)
		if #missing > 0 then
			return { rule, L.STAMP_TIP_ELEMENT_NEEDED:format(have, need, ns.JoinAnd(missing)) }
		end
		return { rule, L.STAMP_TIP_ELEMENT_MET:format(ns.JoinAnd(all)) }
	end
	return {
		need == 1 and L.STAMP_TIP_ZONE or L.STAMP_TIP_ZONES:format(need),
		counted(need, L.STAMP_TIP_ZONES_ONE, L.STAMP_TIP_ZONES_OTHER, have, need),
	}
end

--- The three tooltips of a caught Species' stamps (LED-R165): Caught, In its element and Regular, in that order
--- (LED-R140). nil for a Species not caught, which has none (LED-R124).
---@param world LedgerWorld
---@param state LedgerState
---@param id integer the Species ID
---@param text LedgerJournalText
---@return LedgerStampTip[]?
function ns.SpeciesStampTips(world, state, id, text)
	local species = state.species[id]
	if not species then
		return nil
	end
	local labels = ns.L.ENTRY_STAMPS
	return {
		landTip(labels[1], species, ns.CAUGHT_STAR_CATCHES),
		{ title = labels[2], lines = elementLines(world.species[id], species, text) },
		landTip(labels[3], species, ns.REGULAR_CATCHES),
	}
end

--- The three tooltips of a trophy family's stamps (LED-R165, LED-R47): Any weight, Half the weights and The heaviest,
--- in that order (LED-R143). `stars` are the family's shown stars (LED-R48), so a star already celebrated reads as
--- landed (LED-R92); a weight lands by `state.items`. Without a listed weight only Any weight can be earned.
---@param world LedgerWorld
---@param state LedgerState
---@param family integer
---@param stars LedgerStars
---@param formatNumber? fun(n: number): string BreakUpLargeNumbers; tostring when nil
---@return LedgerStampTip[]
function ns.FamilyStampTips(world, state, family, stars, formatNumber)
	local L = ns.L
	local labels = L.TROPHY_STAMPS
	local listed = world.families[family]
	local weights = listed and listed.weights or {}
	local total, done = #weights, 0
	for _, itemID in ipairs(weights) do
		if state.items[itemID] then
			done = done + 1
		end
	end
	local function landedLine()
		return counted(total, L.TROPHY_TIP_LANDED_ONE, L.TROPHY_TIP_LANDED_OTHER, done, total)
	end
	local any = { L.TROPHY_TIP_ANY }
	if done > 0 then
		any[2] = landedLine()
	elseif stars[1] then
		any[2] = L.TROPHY_TIP_UNLISTED
	else
		any[2] = L.TROPHY_TIP_NONE_YET
	end
	local half, heaviest
	if total == 0 then
		half, heaviest = { L.TROPHY_TIP_NO_WEIGHTS }, { L.TROPHY_TIP_NO_WEIGHTS }
	else
		local need = math.ceil(total / 2)
		half = {
			total == 1 and L.TROPHY_TIP_HALF_ONE or L.TROPHY_TIP_HALF_OTHER:format(need, total),
			landedLine(),
		}
		local format = formatNumber or tostring
		local weight = world.getItem(listed.heaviest).weight or 0
		heaviest = {
			L.TROPHY_TIP_HEAVIEST:format(format(weight)),
			(state.items[listed.heaviest] or stars[3]) and L.TROPHY_TIP_HEAVIEST_DONE or L.TROPHY_TIP_HEAVIEST_TODO,
		}
	end
	return {
		{ title = labels[1], lines = any },
		{ title = labels[2], lines = half },
		{ title = labels[3], lines = heaviest },
	}
end
