if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- Fish varieties (VAR-R20–R25, core/varieties.md), the Ledger's part: each Species' varieties caught, kept in the
-- Ledger's own projection (it never reads Core's, ADR 0001), the completion part they make and the moments of a
-- variety's first Catch and of a fish complete. Pure logic, everything passed in (CORE-R7).

--- A Catch's variety as Core decodes it (VAR-R4: `id` "<speciesID>.<key>", `index` its position 1–10 and `rarity`):
--- never stored in the log, so a Catch without one has none.
---@alias LedgerCatchVariety PagleVariety

--- One variety caught (ledger.md › Data, core/varieties.md › Data): its Catches and the first of them.
---@class LedgerVariety
---@field count integer
---@field first LedgerVarietyFirst

--- A variety's first Catch (VAR-R24's "First landed {date} in {zone}, by {character}"): the Cast's entry ID, realm
--- date, zone and character.
---@class LedgerVarietyFirst
---@field entryId string
---@field date? LedgerDate                    -- nil only for a Cast stored without its realm minute
---@field zone integer
---@field char integer

--- The number of varieties of a Species (VAR-R2): its catalogue item's `varieties` keys, ten for a Species with
--- varieties and 0 for one without (a Legend, a Species not sized, VAR-R1).
---@param getItem fun(itemID: integer): PagleItem?
---@param speciesID integer
---@return integer
function ns.VarietyCount(getItem, speciesID)
	local item = getItem(speciesID)
	local keys = item and item.varieties
	return type(keys) == "table" and #keys or 0
end

--- The varieties of a Species caught in a state (VAR-R20).
---@param state LedgerState
---@param speciesID integer
---@return integer
function ns.VarietiesCaught(state, speciesID)
	local n = 0
	for _ in pairs(state.varieties and state.varieties[speciesID] or {}) do
		n = n + 1
	end
	return n
end

--- Whether a state has caught every variety of a Species with varieties (VAR-R20: the fish complete).
---@param state LedgerState
---@param getItem fun(itemID: integer): PagleItem?
---@param speciesID integer
---@return boolean
function ns.FishComplete(state, getItem, speciesID)
	local count = ns.VarietyCount(getItem, speciesID)
	return count > 0 and ns.VarietiesCaught(state, speciesID) >= count
end

--- A Species Catch with a variety (VAR-R4): its variety's count, and at its first Catch the first Catch's entry ID,
--- realm date, zone and character, with a `newVariety` achievement (its rarity for the moment, VAR-R25); the one that
--- completes the Species' varieties adds a `fishComplete` (VAR-R20, VAR-R25). Neither pays Coins or XP (VAR-R25).
---@param state LedgerState
---@param record PagleCast
---@param speciesID integer
---@param itemID integer the item caught
---@param variety LedgerCatchVariety
---@param earned LedgerAchievement[]
---@param getItem fun(itemID: integer): PagleItem?
function ns.CreditVariety(state, record, speciesID, itemID, variety, earned, getItem)
	local caught = state.varieties[speciesID]
	if not caught then
		caught = {}
		state.varieties[speciesID] = caught
	end
	local index = variety.index
	local entry = caught[index]
	if entry then
		entry.count = entry.count + 1
		return
	end
	caught[index] = {
		count = 1,
		first = {
			entryId = record.id,
			date = ns.CopyDate(record.conditions.date),
			zone = record.conditions.zone,
			char = record.char,
		},
	}
	earned[#earned + 1] = {
		kind = "newVariety",
		cast = record.id,
		coins = 0,
		species = speciesID,
		itemID = itemID,
		index = index,
		rarity = variety.rarity,
	}
	if ns.FishComplete(state, getItem, speciesID) then
		earned[#earned + 1] =
			{ kind = "fishComplete", cast = record.id, coins = 0, species = speciesID, itemID = itemID }
	end
end

--- The varieties part of Ledger completion (VAR-R20, LED-R70, LED-R71): every Species of `species` with varieties,
--- removed ones left out of both sides (LED-R12), done when all its varieties are caught.
---@param species integer[] the Species' world (ns.CollectionWorlds)
---@param state LedgerState
---@param getItem fun(itemID: integer): PagleItem?
---@return LedgerCount
function ns.VarietiesCount(species, state, getItem)
	local count = { done = 0, total = 0 }
	for _, id in ipairs(species) do
		local item = getItem(id)
		if not (item and item.removed) and ns.VarietyCount(getItem, id) > 0 then
			count.total = count.total + 1
			if ns.FishComplete(state, getItem, id) then
				count.done = count.done + 1
			end
		end
	end
	return count
end
