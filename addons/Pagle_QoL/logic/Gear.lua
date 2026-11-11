if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- Gear (QOL-R40–R47, QOL-R77): the fishing set's choice, the free-slot check, when the gear step is ready, what
-- Swap gear does, the wait for a swap's result and the swap-back Nudge's text. Pure logic, everything passed in
-- (CORE-R7); adapter/Gear.lua reads the equipment sets and swaps.

--- The set "Save what I'm wearing" saves (QOL-R41), and the set a swap saves the gear worn before into (QOL-R44).
--- Both are lookup keys, never translated (QOL-R42).
ns.FISHING_SET_NAME = "Pagle Fishing"
ns.PREVIOUS_SET_NAME = "Pagle Previous"

--- The Fishing set dropdown's value for None. Set IDs start at 0 (probe B9), so None is below them.
ns.NO_FISHING_SET = -1

--- The chosen fishing set as the game reads it now (QOL-R40, QOL-R43, QOL-R46).
---@class PagleQoLFishingSet
---@field setID integer
---@field name string
---@field hasPole boolean its main-hand item (`C_EquipmentSet.GetItemIDs(setID)[16]`) is a fishing pole (QOL-R21)
---@field numLost integer how many of its items are missing (`GetEquipmentSetInfo`'s numLost)
---@field isEquipped boolean it is fully worn (`GetEquipmentSetInfo`'s isEquipped)

--- A character's choice as `PagleQoLDB.global.gear[guid]` stores it (QOL-R40, qol.md › Data).
---@class PagleQoLGearChoice
---@field setID integer
---@field name string

--- The chosen fishing set's ID (QOL-R40): the stored choice while a set has both its ID and its name, else none.
--- *Pagle Previous* is never chosen.
---@param stored PagleQoLGearChoice?
---@param nameOf fun(setID: integer): string? the name of the character's set with this ID, nil for none
---@return integer?
function ns.ChosenSetID(stored, nameOf)
	if not stored or stored.name == ns.PREVIOUS_SET_NAME or nameOf(stored.setID) ~= stored.name then
		return nil
	end
	return stored.setID
end

--- The Fishing set dropdown's options (SET-R20, QOL-R40): None, then the character's sets in the order given,
--- except *Pagle Previous*.
---@param sets { setID: integer, name: string }[]
---@return { value: integer, label: string }[]
function ns.FishingSetOptions(sets)
	local options = { { value = ns.NO_FISHING_SET, label = ns.L.SETTINGS_FISHING_SET_NONE } }
	for _, set in ipairs(sets) do
		if set.name ~= ns.PREVIOUS_SET_NAME then
			options[#options + 1] = { value = set.setID, label = set.name }
		end
	end
	return options
end

--- The chat line when the free equipment set slots don't cover the sets QoL would create, or nil when they do
--- (QOL-R42): `free` is `MAX_EQUIPMENT_SETS_PER_PLAYER` minus the sets the character has.
---@param free integer
---@param needFishing boolean *Pagle Fishing* would be created (QOL-R41)
---@param needPrevious boolean *Pagle Previous* would be created
---@return string?
function ns.SlotsMessage(free, needFishing, needPrevious)
	local needed = (needFishing and 1 or 0) + (needPrevious and 1 or 0)
	if free >= needed then
		return nil
	elseif needed == 2 then
		return ns.Text(
			ns.L.GEAR_NEEDS_TWO_SLOTS,
			{ fishingSetName = ns.FISHING_SET_NAME, previousSetName = ns.PREVIOUS_SET_NAME }
		)
	end
	return ns.Text(ns.L.GEAR_NEEDS_SLOT, { setName = needFishing and ns.FISHING_SET_NAME or ns.PREVIOUS_SET_NAME })
end

--- Whether the gear step is ready (QOL-R43): a fishing set is chosen, no fishing pole is in hand, the set's main
--- hand is a pole, none of its items is missing, and no swap is settling (QOL-R29). So a set without a pole, or
--- with its pole in the bank, never offers the step, and a second press can't save a half-swapped outfit.
---@param set PagleQoLFishingSet? the chosen fishing set; nil while none is
---@param poleInHand boolean
---@param settling boolean a swap's result is awaited (QOL-R29)
---@return boolean
function ns.GearStepReady(set, poleInHand, settling)
	return set ~= nil and not poleInHand and set.hasPole and set.numLost == 0 and not settling
end

--- Whether the gear worn now may be saved into *Pagle Previous* (QOL-R42, QOL-R44): never with a fishing pole in hand,
--- so *Pagle Previous* never holds the fishing outfit, and Swap gear's swap back always takes the pole off.
---@param poleInHand boolean
---@return boolean
function ns.MaySavePrevious(poleInHand)
	return not poleInHand
end

---@alias PagleQoLSwapGear "equip"|"back"|"nothing"

--- *Pagle Previous* as the game reads it now (QOL-R46).
---@class PagleQoLPreviousSet
---@field hasPole boolean its main-hand item (`C_EquipmentSet.GetItemIDs(setID)[16]`) is a fishing pole (QOL-R21)

--- Swap gear's body (QOL-R46): nothing while disarmed, with no set chosen, or while a swap settles (QOL-R29). With
--- the set fully worn, a swap back if *Pagle Previous* is there, its main hand no fishing pole (one with a pole counts
--- as absent); otherwise a swap to the set if none of its items is missing.
---@param armed boolean QoL is armed (QOL-R30)
---@param set PagleQoLFishingSet? the chosen fishing set; nil while none is
---@param previous PagleQoLPreviousSet? *Pagle Previous*; nil while it doesn't exist
---@param settling boolean
---@return PagleQoLSwapGear
function ns.SwapGearAction(armed, set, previous, settling)
	if not armed or not set or settling then
		return "nothing"
	elseif set.isEquipped then
		return (previous and not previous.hasPole) and "back" or "nothing"
	end
	return set.numLost == 0 and "equip" or "nothing"
end

--- QoL's live gear state: the swap whose result it awaits (QOL-R29). It lives for the session.
---@class PagleQoLGearState
---@field due number? when the result wait of the swap awaited ends; nil while none is
local GearState = {}
GearState.__index = GearState

--- A gear state with no swap awaited.
---@return PagleQoLGearState
function ns.NewGearState()
	return setmetatable({}, GearState)
end

--- A swap started (QOL-R44, QOL-R45): its result is awaited for ns.RESULT_WAIT (QOL-R29).
---@param now number seconds, as GetTime() reads them
function GearState:Swapped(now)
	self.due = now + ns.RESULT_WAIT
end

--- The swap's result arrived (`EQUIPMENT_SWAP_FINISHED`).
function GearState:SwapFinished()
	self.due = nil
end

--- Whether a swap's result is still awaited: until EQUIPMENT_SWAP_FINISHED or the result wait, whichever comes first.
---@param now number
---@return boolean
function GearState:Settling(now)
	if self.due and now >= self.due then
		self.due = nil
	end
	return self.due ~= nil
end

--- The swap-back Nudge's line (QOL-R77), as the pieces its strip draws (ns.NudgeParts): the key bound to Swap gear, in
--- its short form, on a key cap; or, while it is unbound, the binding's name in printed red.
---@param keyText string? the first key bound to Swap gear, as `GetBindingText` abbreviates it; nil while unbound
---@return PagleQoLNudgePart[]
function ns.SwapBackNudge(keyText)
	if keyText then
		return ns.NudgeParts(ns.L.NUDGE_SWAP_BACK, keyText, "key")
	end
	return ns.NudgeParts(ns.L.NUDGE_SWAP_BACK_UNBOUND, ns.L.BINDING_SWAP_GEAR, "em")
end

--- The icon *Pagle Fishing* is created with (QOL-R41): the main-hand item's if it is a fishing pole, else the Fishing
--- spell's.
---@param poleInHand boolean
---@param mainHandIcon integer? the main-hand item's icon file ID
---@param fishingIcon integer? the Fishing spell's icon file ID
---@return integer?
function ns.FishingSetIcon(poleInHand, mainHandIcon, fishingIcon)
	if poleInHand and mainHandIcon then
		return mainHandIcon
	end
	return fishingIcon
end

-- With no fishing set chosen (QOL-R48, QOL-R49; from 1.7): the best pole from the bags goes on, the main-hand and
-- off-hand items it replaced are remembered per character, and Swap gear puts them back.

--- A pole's Fishing bonus in the pole table (QOL-R48); a fishing pole the table doesn't list counts 0.
---@param itemID integer
---@return integer
function ns.PoleBonus(itemID)
	for _, pole in ipairs(ns.POLES) do
		if pole.itemID == itemID then
			return pole.bonus
		end
	end
	return 0
end

--- The best pole (QOL-R48): of the available fishing poles in the bags, the one with the highest Fishing bonus, ties
--- to the lower item ID, as *Best I have* picks a lure (QOL-R51); nil when none is available.
---@param available integer[] the item IDs of the fishing poles in the bags that the character can use
---@return integer?
function ns.ChoosePole(available)
	local best, bestBonus
	for _, itemID in ipairs(available) do
		local bonus = ns.PoleBonus(itemID)
		if not best or bonus > bestBonus or (bonus == bestBonus and itemID < best) then
			best, bestBonus = itemID, bonus
		end
	end
	return best
end

--- Whether the gear step is ready with no fishing set chosen (QOL-R48): no fishing pole is in hand, a pole is
--- available, and no equip is settling (QOL-R29).
---@param poleInHand boolean
---@param pole integer? the best pole (ns.ChoosePole)
---@param settling boolean
---@return boolean
function ns.PoleStepReady(poleInHand, pole, settling)
	return not poleInHand and pole ~= nil and not settling
end

--- One remembered weapon (QOL-R48): its item ID, and its link, which the swap back equips by.
---@class PagleQoLWeapon
---@field itemID integer
---@field link string

--- The weapons a pole replaced, as `PagleQoLDB.global.poleSwap[guid]` keeps them (QOL-R48, qol.md › Data): an empty
--- slot, or a slot whose item is back on, has none.
---@class PagleQoLPoleSwap
---@field mainHand PagleQoLWeapon?
---@field offHand PagleQoLWeapon?

--- What to remember when a pole goes on (QOL-R48): the main-hand and off-hand items worn now, read at every pole
--- equip, which happens only with no pole in hand; nil when both hands are empty.
---@param mainHand PagleQoLWeapon?
---@param offHand PagleQoLWeapon?
---@return PagleQoLPoleSwap?
function ns.RememberWeapons(mainHand, offHand)
	if not mainHand and not offHand then
		return nil
	end
	return { mainHand = mainHand, offHand = offHand }
end

--- The hands and bags as a swap back reads them (QOL-R49).
---@class PagleQoLHands
---@field mainHand integer? the item ID worn in the main hand (slot 16)
---@field mainIsPole boolean the main hand holds a fishing pole (QOL-R21)
---@field offHand integer? the item ID worn in the off hand (slot 17)
---@field inBags fun(itemID: integer): boolean the item is in the bags
---@field twoHanded fun(itemID: integer): boolean the item is a two-handed weapon (`INVTYPE_2HWEAPON`)

--- One equip of a swap back: the slot and the link of the item that goes in it.
---@class PagleQoLEquip
---@field slot integer
---@field link string

--- A swap back's equips, in order, and what stays remembered (QOL-R49). The main hand comes back first; the off hand
--- comes back only once the main hand will hold a one-handed item that isn't a pole (or nothing), so a pole the main
--- hand couldn't replace stays, the off hand with it, and a two-hander coming back leaves the off hand in the bags.
--- An entry whose item is already worn in its slot is spent, and one whose item is in neither the bags nor that slot is
--- dropped; every other stays until its item is worn (ns.ClearWornWeapons), so a second press finishes a half-done
--- swap back.
---@param memory PagleQoLPoleSwap?
---@param hands PagleQoLHands
---@return PagleQoLEquip[] equips
---@return PagleQoLPoleSwap? kept
function ns.SwapBackPlan(memory, hands)
	local equips = {}
	if not memory then
		return equips, nil
	end
	local kept = {}
	local main, off = memory.mainHand, memory.offHand
	-- What the main hand will hold after this press: its item now, or the remembered one going on.
	local mainAfter, mainAfterIsPole = hands.mainHand, hands.mainIsPole
	if main and hands.mainHand ~= main.itemID then
		if hands.inBags(main.itemID) then
			equips[#equips + 1] = { slot = 16, link = main.link }
			kept.mainHand = main
			mainAfter, mainAfterIsPole = main.itemID, false
		end
	end
	if off and hands.offHand ~= off.itemID then
		local oneHanded = mainAfter == nil or (not mainAfterIsPole and not hands.twoHanded(mainAfter))
		if mainAfterIsPole then
			kept.offHand = off
		elseif oneHanded and hands.inBags(off.itemID) then
			equips[#equips + 1] = { slot = 17, link = off.link }
			kept.offHand = off
		end
	end
	if not kept.mainHand and not kept.offHand then
		return equips, nil
	end
	return equips, kept
end

--- The remembered weapons once the hands change (QOL-R49): with no fishing pole in hand, each entry whose item is
--- worn in its slot again is spent; nil once none is left. With a pole in hand nothing is spent, so the press that put
--- the pole on never clears what it remembered.
---@param memory PagleQoLPoleSwap?
---@param mainHand integer? the item ID worn in the main hand
---@param offHand integer? the item ID worn in the off hand
---@param poleInHand boolean
---@return PagleQoLPoleSwap?
function ns.ClearWornWeapons(memory, mainHand, offHand, poleInHand)
	if not memory or poleInHand then
		return memory
	end
	local main = memory.mainHand
	local off = memory.offHand
	if main and main.itemID == mainHand then
		main = nil
	end
	if off and off.itemID == offHand then
		off = nil
	end
	if not main and not off then
		return nil
	end
	return { mainHand = main, offHand = off }
end

---@alias PagleQoLPoleSwapGear "pole"|"back"|"nothing"

--- Swap gear's body with no fishing set chosen (QOL-R46, QOL-R48, QOL-R49): nothing while disarmed or while an equip
--- settles; with no pole in hand, the best pole if there is one; with a pole in hand, the swap back while it has an
--- equip to make; otherwise nothing.
---@param armed boolean
---@param poleInHand boolean
---@param pole integer? the best pole (ns.ChoosePole)
---@param backEquips integer how many equips the swap back would make (ns.SwapBackPlan)
---@param settling boolean
---@return PagleQoLPoleSwapGear
function ns.PoleSwapGearAction(armed, poleInHand, pole, backEquips, settling)
	if not armed or settling then
		return "nothing"
	elseif not poleInHand then
		return pole and "pole" or "nothing"
	end
	return backEquips > 0 and "back" or "nothing"
end
