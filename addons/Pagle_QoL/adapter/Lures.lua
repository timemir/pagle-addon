if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- Lures on the Fishing key (QOL-R29, QOL-R50–R53): QoL reads the bags and the pole's lure for the ladder's step 4
-- (logic/Lures.lua decides), waits for each use's result, skips a lure whose use failed, and shows the out-of-lures
-- Nudge. What it reads, it uses only to choose (QOL-R4); on its own it changes only frames (QOL-R5).

-- The owner of the lures' WoW event registrations.
local OWNER = "Pagle_QoL lures"

local lures = ns.NewLureState()
local targeted ---@type integer? the lure the Fishing key last pointed at, until it points at a cast or reel (QOL-R29)

-- A lure is available when it is in the bags, usable and not skipped (QOL-R51).
---@param itemID integer
---@return boolean
local function isAvailable(itemID)
	return C_Item.GetItemCount(itemID) > 0 and C_Item.IsUsableItem(itemID) == true and not lures:IsSkipped(itemID)
end

--- The ladder's lure fields (QOL-R20 step 4), read at each of the Fishing key's evaluations while armed. It also
--- shows the out-of-lures Nudge when the pole's lure has just gone (QOL-R53).
---@param poleInHand boolean
---@return integer? lure the lure QOL-R51 picks; nil while Lures is *Off* or none is available
---@return boolean lured the pole has a lure on, or counts as lured while a use's result is awaited (QOL-R29)
function ns.ReadLures(poleInHand)
	---@type { mode: PagleQoLLuresMode, item: integer } QoL's OnInitialize opened PagleQoLDB before the key arms
	local settings = ns.db.profile.lures
	local enchanted ---@type boolean? the main hand's lure, read only for a fishing pole
	local lured = false
	if poleInHand then
		enchanted = GetWeaponEnchantInfo() == true
		-- Before the choice, so a lure whose result wait just ran out is skipped already.
		lured = lures:Lured(enchanted, GetTime())
	end
	local lure = ns.ChooseLure(settings.mode, settings.item, isAvailable)
	if lures:OutOfLures(enchanted, ns.RunningStretch(), settings.mode, lure) then
		-- The lure's name from C_Item (adapter/Items.lua); its ID stands in until the client has loaded it (QOL-R54).
		local name = ns.ItemName(settings.item) or ns.L.SETTINGS_LURE_UNNAMED:format(settings.item)
		ns.ShowNudge(ns.OutOfLuresText(settings.mode, name))
	end
	return lure, lured
end

--- The Fishing key arms a target (QOL-R11): the item PagleQoLActionButton now uses, or nil for a cast or a reel. Only
--- a lure is awaited (QOL-R29); a clam has no item spell, and would make any spell of the player's count as its use.
---@param itemID integer?
function ns.LureTargeted(itemID)
	targeted = ns.IsLure(itemID) and itemID or nil
end

-- Whether a spell the player cast is the use of the lure the key pointed at: its item's spell, as C_Item.GetItemSpell
-- reads it (8087 for Shiny Bauble, probe B4). While that isn't known, any spell of the player's counts.
---@param spellID integer?
---@return boolean
local function isTargetedUse(spellID)
	if not targeted then
		return false
	end
	local _, lureSpell = C_Item.GetItemSpell(targeted)
	return lureSpell == nil or lureSpell == spellID
end

--- Waits for each lure use's result and skips a lure that failed (QOL-R29). QoL's OnInitialize calls it once it
--- has registered.
function ns.StartLures()
	-- The use finished casting: the pole counts as lured until the lure shows or the result wait passes, and that
	-- wait's end is re-evaluated even with no event to hear.
	Pagle.RegisterUnitEvent(OWNER, "UNIT_SPELLCAST_SUCCEEDED", "player", function(_, _, _, spellID)
		if isTargetedUse(spellID) then
			---@cast targeted integer
			lures:Applied(targeted, GetTime())
			C_Timer.After(ns.RESULT_WAIT, ns.EvaluateFishingKey)
			ns.EvaluateFishingKey()
		end
	end)
	-- The use failed: that lure is skipped, so it never blocks the key.
	Pagle.RegisterUnitEvent(OWNER, "UNIT_SPELLCAST_FAILED", "player", function(_, _, _, spellID)
		if isTargetedUse(spellID) then
			---@cast targeted integer
			lures:Skip(targeted)
			ns.EvaluateFishingKey()
		end
	end)
	-- Fishing skill may have changed: every skipped lure is tried again. A login or /reload starts afresh anyway.
	Pagle.RegisterEvent(OWNER, "SKILL_LINES_CHANGED", function()
		lures:ClearSkips()
		ns.EvaluateFishingKey()
	end)
end
