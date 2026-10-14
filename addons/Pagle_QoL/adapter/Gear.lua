if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- Gear (QOL-R40–R47, QOL-R77): QoL reads the character's equipment sets for the ladder's gear step (logic/Gear.lua
-- decides), swaps to the fishing set on a press of the Fishing key or Swap gear, swaps back on Swap gear, keeps the
-- fishing set's choice and shows the swap-back Nudge. On its own it changes only equipment-set definitions and
-- frames (QOL-R5); every swap is one press's one game action (QOL-R47).

-- The owner of gear's WoW event registrations.
local OWNER = "Pagle_QoL gear"
--- The Fishing spell, whose icon a new *Pagle Fishing* takes without a pole in hand (QOL-R41).
local FISHING_SPELL = 7620

local gear = ns.NewGearState()

-- PagleQoLDB.global.gear, by character GUID. AceDB drops it while empty at PLAYER_LOGOUT.
---@return table<string, PagleQoLGearChoice>
local function choices()
	---@type table QoL's OnInitialize opened PagleQoLDB before anything here runs
	local global = ns.db.global
	global.gear = global.gear or {}
	return global.gear
end

---@param setID integer
---@return string?
local function setName(setID)
	return (C_EquipmentSet.GetEquipmentSetInfo(setID))
end

-- The chosen fishing set's ID for this character, while a set has its ID and name (QOL-R40).
---@return integer?
local function chosenSetID()
	return ns.ChosenSetID(choices()[UnitGUID("player")], setName)
end

-- Whether the set's main-hand item is a fishing pole (QOL-R21).
---@param setID integer
---@return boolean
local function holdsPole(setID)
	local mainHand = C_EquipmentSet.GetItemIDs(setID)[16]
	local classID, subclassID
	if mainHand then
		classID, subclassID = select(6, C_Item.GetItemInfoInstant(mainHand))
	end
	return ns.IsFishingPole(classID, subclassID)
end

-- The chosen fishing set as the game reads it now, or nil while none is chosen.
---@return PagleQoLFishingSet?
local function readFishingSet()
	local setID = chosenSetID()
	if not setID then
		return nil
	end
	local name, _, _, isEquipped, _, _, _, numLost = C_EquipmentSet.GetEquipmentSetInfo(setID)
	return {
		setID = setID,
		name = name,
		hasPole = holdsPole(setID),
		numLost = numLost or 0,
		isEquipped = isEquipped == true,
	}
end

---@return integer?
local function previousSetID()
	return C_EquipmentSet.GetEquipmentSetID(ns.PREVIOUS_SET_NAME)
end

-- *Pagle Previous* as the game reads it now, and its set ID; nil while it doesn't exist (QOL-R46).
---@return PagleQoLPreviousSet?
---@return integer?
local function readPrevious()
	local setID = previousSetID()
	if not setID then
		return nil
	end
	return { hasPole = holdsPole(setID) }, setID
end

-- The character's free equipment set slots (QOL-R42), as the game's own equipment manager counts them.
---@return integer
local function freeSlots()
	return MAX_EQUIPMENT_SETS_PER_PLAYER - C_EquipmentSet.GetNumEquipmentSets()
end

-- Saves the gear worn now, with no ignored slots, into the set named `name`: over it if it exists, else as a new
-- set with `icon` while a slot is free (QOL-R41, QOL-R44). Saving a set isn't a game action (QOL-R5).
---@param name string
---@param icon integer?
local function saveWorn(name, icon)
	local setID = C_EquipmentSet.GetEquipmentSetID(name)
	if not setID and freeSlots() < 1 then
		return
	end
	C_EquipmentSet.ClearIgnoredSlotsForSave()
	if setID then
		C_EquipmentSet.SaveEquipmentSet(setID)
	else
		-- A file ID, as the game's own equipment manager passes its chosen icon (Gethe/wow-ui-source branch forever,
		-- Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua, GearManagerPopupFrameMixin:OkayButton_OnClick).
		---@diagnostic disable-next-line: param-type-mismatch -- the annotations type the icon as a string only
		C_EquipmentSet.CreateEquipmentSet(name, icon)
	end
end

-- A swap started: its result is awaited (QOL-R29), and that wait's end is re-evaluated even with no event to hear.
local function swapped()
	gear:Swapped(GetTime())
	C_Timer.After(ns.RESULT_WAIT, ns.EvaluateFishingKey)
	ns.EvaluateFishingKey()
end

-- A swap to the fishing set (QOL-R44): the gear worn now goes into *Pagle Previous* first, created with the main
-- hand's icon if it's missing and a slot is free, unless a fishing pole is in hand; then the one game action. With no
-- *Pagle Previous* to save into, the swap still happens, and there is nothing to swap back to.
---@param setID integer
local function swapToFishingSet(setID)
	if ns.MaySavePrevious(ns.PoleInHand()) then
		saveWorn(ns.PREVIOUS_SET_NAME, GetInventoryItemTexture("player", 16))
	end
	C_EquipmentSet.UseEquipmentSet(setID)
	swapped()
end

--- The ladder's gear step (QOL-R20 step 3, QOL-R43), read at each of the Fishing key's evaluations while armed.
---@param poleInHand boolean
---@return boolean
function ns.ReadGearStep(poleInHand)
	return ns.GearStepReady(readFishingSet(), poleInHand, gear:Settling(GetTime()))
end

--- PagleQoLGearButton's OnClick: the Fishing key's gear step (QOL-R24). It swaps only while the step is still
--- ready, so an override not yet re-pointed never saves a half-swapped outfit into *Pagle Previous* (QOL-R43).
function ns.PressGearButton()
	if not ns.IsArmed() then
		return
	end
	local set = readFishingSet()
	if set and ns.GearStepReady(set, ns.PoleInHand(), gear:Settling(GetTime())) then
		swapToFishingSet(set.setID)
	end
end

--- Swap gear (QOL-R46), the body of the binding PAGLE_SWAP_GEAR in Bindings.xml: a swap back to *Pagle Previous*
--- with the fishing set fully worn (unless its main hand is a pole, so it counts as absent), else a swap to the set,
--- or nothing.
function PagleQoL_SwapGear()
	if not ns.IsArmed() then
		return
	end
	local set = readFishingSet()
	local previous, previousID = readPrevious()
	local action = ns.SwapGearAction(true, set, previous, gear:Settling(GetTime()))
	if action == "back" then
		---@cast previousID integer
		C_EquipmentSet.UseEquipmentSet(previousID)
		swapped()
	elseif action == "equip" then
		---@cast set PagleQoLFishingSet
		swapToFishingSet(set.setID)
	end
end

--- The swap-back Nudge (QOL-R77): the Fishing stretch ended on its own (not by restriction or logout), so it shows
--- if Swap gear would swap back, naming Swap gear's first key in its short form.
function ns.NudgeSwapBack()
	if ns.SwapGearAction(true, readFishingSet(), (readPrevious()), false) ~= "back" then
		return
	end
	local key = GetBindingKey("PAGLE_SWAP_GEAR")
	-- The second argument asks for the short form, as the game's action buttons pass it (Gethe/wow-ui-source branch
	-- forever, Blizzard_ActionBar/Shared/ActionButton.lua: `GetBindingText(key, 1)`; QOL-R70).
	---@diagnostic disable-next-line: param-type-mismatch -- the annotations name it a prefix string
	ns.ShowNudge(ns.SwapBackText(key and GetBindingText(key, true)))
end

--- Whether the Fishing set and "Save what I'm wearing" rows can change anything: not while restricted (QOL-R41).
---@return boolean
function ns.CanEditGear()
	return not Pagle.IsRestricted()
end

--- The Fishing set dropdown's value: the chosen set's ID, or ns.NO_FISHING_SET (QOL-R40).
---@return integer
function ns.FishingSetChoice()
	return chosenSetID() or ns.NO_FISHING_SET
end

--- The Fishing set dropdown's options: None and the character's sets, except *Pagle Previous* (SET-R20, QOL-R40).
---@return { value: integer, label: string }[]
function ns.ReadFishingSetOptions()
	local sets = {}
	for _, setID in ipairs(C_EquipmentSet.GetEquipmentSetIDs()) do
		sets[#sets + 1] = { setID = setID, name = setName(setID) }
	end
	return ns.FishingSetOptions(sets)
end

-- Chooses the set `setID` for this character, creating *Pagle Previous* from the gear worn now if it doesn't exist,
-- so its slot is taken up front (QOL-R40, QOL-R42). With a fishing pole in hand it creates none: the slot check is
-- then all that reserves the slot, and the first swap to the set creates it (QOL-R44). With no slot free for it,
-- nothing is created or chosen, and the chat says why. A change re-points the Fishing key at once (QOL-R25).
---@param setID integer
local function choose(setID)
	local name = setName(setID)
	if not name or name == ns.PREVIOUS_SET_NAME then
		return
	end
	local needPrevious = previousSetID() == nil
	local message = ns.SlotsMessage(freeSlots(), false, needPrevious)
	if message then
		print(message)
		ns.Module:RefreshSetting("fishingSet") -- the dropdown shows the choice kept (QOL-R42, CORE-R42)
		return
	end
	if needPrevious and ns.MaySavePrevious(ns.PoleInHand()) then
		saveWorn(ns.PREVIOUS_SET_NAME, GetInventoryItemTexture("player", 16))
	end
	choices()[UnitGUID("player")] = { setID = setID, name = name }
	ns.EvaluateFishingKey()
end

--- The Fishing set dropdown's change: a set, or None (QOL-R40). Nothing changes while restricted (QOL-R41).
---@param setID integer
function ns.ChooseFishingSet(setID)
	if not ns.CanEditGear() then
		ns.Module:RefreshSetting("fishingSet") -- the dropdown shows the choice kept (QOL-R42, CORE-R42)
		return
	elseif setID == ns.NO_FISHING_SET then
		choices()[UnitGUID("player")] = nil
		ns.EvaluateFishingKey()
	else
		choose(setID)
	end
end

--- "Save what I'm wearing as my fishing set" (QOL-R41): the gear worn now goes into *Pagle Fishing*, created with
--- the pole's icon (or the Fishing spell's) if it doesn't exist, and that set is chosen (QOL-R42). It checks the free
--- slots for both sets it may create first, so it creates all or nothing.
function ns.SaveFishingSet()
	if not ns.CanEditGear() then
		return
	end
	local needFishing = C_EquipmentSet.GetEquipmentSetID(ns.FISHING_SET_NAME) == nil
	local message = ns.SlotsMessage(freeSlots(), needFishing, previousSetID() == nil)
	if message then
		print(message)
		return
	end
	local icon = ns.FishingSetIcon(
		ns.PoleInHand(),
		GetInventoryItemTexture("player", 16),
		(C_Spell.GetSpellTexture(FISHING_SPELL))
	)
	saveWorn(ns.FISHING_SET_NAME, icon)
	local setID = C_EquipmentSet.GetEquipmentSetID(ns.FISHING_SET_NAME)
	if setID then
		choose(setID)
		ns.Module:RefreshSetting("fishingSet") -- the dropdown shows Pagle Fishing (QOL-R41, CORE-R42)
	end
end

--- Follows swaps' results and the character's sets. QoL's OnInitialize calls it once it has registered.
function ns.StartGear()
	-- The swap's result arrived, whether it worked or not: the gear step and Swap gear may act again (QOL-R29).
	Pagle.RegisterEvent(OWNER, "EQUIPMENT_SWAP_FINISHED", function()
		gear:SwapFinished()
		ns.EvaluateFishingKey()
	end)
	-- A set was deleted or renamed: a choice no set has both the ID and the name of any more is dropped (QOL-R40).
	-- Only on a change, so sets the client hasn't sent yet at login never drop the choice.
	Pagle.RegisterEvent(OWNER, "EQUIPMENT_SETS_CHANGED", function()
		local guid = UnitGUID("player")
		if guid and choices()[guid] and not chosenSetID() then
			choices()[guid] = nil
		end
	end)
end
