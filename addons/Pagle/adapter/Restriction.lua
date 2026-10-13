local addonName = ...
---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Core alone tracks restriction state (CORE-R30): combat from PLAYER_REGEN_*, addon restrictions from
-- ADDON_RESTRICTION_STATE_CHANGED. Its own owner, so no other Core file's registration replaces these.
local OWNER = "Pagle restriction state"

--- Payload of `RestrictionChanged`, fired on every change of `Pagle.IsRestricted()` after load, never for the
--- starting state (CORE-R30).
---@alias PagleRestrictionChangedHandler fun(event: "RestrictionChanged", isRestricted: boolean)

---@type PagleRestriction? nil until ADDON_LOADED
local restriction
local queue = ns.NewWorkQueue()

-- Whether a restriction type is restricting. Activating counts: it's about to be active.
---@param state Enum.AddOnRestrictionState
local function isActive(state)
	return state ~= Enum.AddOnRestrictionState.Inactive
end

-- The state as the client reports it now.
---@return PagleRestriction
local function readState()
	local restrictions = {}
	for _, restrictionType in pairs(Enum.AddOnRestrictionType) do
		restrictions[restrictionType] = isActive(C_RestrictedActions.GetAddOnRestrictionState(restrictionType))
	end
	return ns.NewRestriction(InCombatLockdown(), restrictions)
end

--- Whether Pagle is restricted: in combat, or with an addon restriction active (CORE-R30). While it is, nothing in
--- the package registers Settings, creates secure frames or changes bindings (CORE-R32).
---@return boolean
function Pagle.IsRestricted()
	return (restriction or readState()):IsRestricted()
end

--- Runs `work` now if Pagle isn't restricted. Otherwise queues it, to run in order at `RestrictionChanged(false)`,
--- each piece through `securecallfunction` (CORE-R32). Everything that registers Settings, creates secure frames or
--- changes bindings goes through here. Clearing override bindings doesn't: it's allowed while `InCombatLockdown()`
--- is still false (CORE-R32, QOL-R31).
---@param work fun()
function ns.RunWhenUnrestricted(work)
	if Pagle.IsRestricted() then
		queue:Push(work)
	else
		work()
	end
end

-- After a flip: the queue runs first, so listeners see its work done.
---@param isRestricted boolean
local function changed(isRestricted)
	if not isRestricted then
		queue:Drain(securecallfunction)
	end
	ns.Fire("RestrictionChanged", isRestricted)
end

Pagle.RegisterEvent(OWNER, "ADDON_LOADED", function(_, loadedName)
	if loadedName == addonName then
		restriction = readState()
		Pagle.UnregisterEvent(OWNER, "ADDON_LOADED")
	end
end)

-- Before ADDON_LOADED there's nothing to change: the starting state is read then.
Pagle.RegisterEvent(OWNER, "PLAYER_REGEN_DISABLED", function()
	if restriction and restriction:SetCombat(true) then
		changed(true)
	end
end)
Pagle.RegisterEvent(OWNER, "PLAYER_REGEN_ENABLED", function()
	if restriction and restriction:SetCombat(false) then
		changed(false)
	end
end)
-- The payload, not the API: IsAddOnRestrictionActive answers false while this event is dispatched.
Pagle.RegisterEvent(OWNER, "ADDON_RESTRICTION_STATE_CHANGED", function(_, restrictionType, state)
	if restriction and restriction:SetRestriction(restrictionType, isActive(state)) then
		changed(restriction:IsRestricted())
	end
end)
