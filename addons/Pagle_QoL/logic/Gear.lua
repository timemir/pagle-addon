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
		return ns.L.GEAR_NEEDS_TWO_SLOTS:format(ns.FISHING_SET_NAME, ns.PREVIOUS_SET_NAME)
	end
	return ns.L.GEAR_NEEDS_SLOT:format(needFishing and ns.FISHING_SET_NAME or ns.PREVIOUS_SET_NAME)
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

--- The swap-back Nudge's text (QOL-R77), naming the key bound to Swap gear in its short form.
---@param keyText string? the first key bound to Swap gear, as `GetBindingText` abbreviates it; nil while unbound
---@return string
function ns.SwapBackText(keyText)
	if keyText then
		return ns.L.NUDGE_SWAP_BACK:format(keyText)
	end
	return ns.L.NUDGE_SWAP_BACK_UNBOUND
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
