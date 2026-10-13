---@class PagleNS
local ns = select(2, ...)

--- Restriction state (CORE-R30): restricted while in combat or while any addon restriction is active.
---@class PagleRestriction
---@field private inCombat boolean
---@field private active table<any, true> restriction type -> true while it's active
local Restriction = {}
Restriction.__index = Restriction

--- The state as Core reads it at ADDON_LOADED.
---@param inCombat boolean `InCombatLockdown()`
---@param restrictions table<any, boolean> Whether each addon restriction type is active, by type.
---@return PagleRestriction
function ns.NewRestriction(inCombat, restrictions)
	local active = {}
	for restrictionType, isActive in pairs(restrictions) do
		if isActive then
			active[restrictionType] = true
		end
	end
	return setmetatable({ inCombat = inCombat, active = active }, Restriction)
end

---@return boolean
function Restriction:IsRestricted()
	return self.inCombat or next(self.active) ~= nil
end

-- Runs `change`, then says whether IsRestricted flipped.
---@param state PagleRestriction
---@param change fun()
---@return boolean
local function flips(state, change)
	local before = state:IsRestricted()
	change()
	return state:IsRestricted() ~= before
end

--- Combat started or ended. Returns whether IsRestricted flipped.
---@param inCombat boolean
---@return boolean
function Restriction:SetCombat(inCombat)
	return flips(self, function()
		self.inCombat = inCombat
	end)
end

--- An addon restriction type became active or inactive. Returns whether IsRestricted flipped.
---@param restrictionType any
---@param isActive boolean
---@return boolean
function Restriction:SetRestriction(restrictionType, isActive)
	return flips(self, function()
		self.active[restrictionType] = isActive or nil
	end)
end
