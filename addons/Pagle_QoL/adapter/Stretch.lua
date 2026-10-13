if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- The Fishing stretch (QOL-R61) and the CVars leased for it (QOL-R62–R64, QOL-R66): QoL hears when a stretch
-- starts and ends (logic/Stretch.lua decides), leases the soft-interact row for it, and restores the lease when it
-- ends, at load and when lockdown ends. It changes only CVars (QOL-R5); what it reads, it uses only to decide
-- (QOL-R4).

-- The owner of the stretch's Core event callbacks and WoW event registrations.
local OWNER = "Pagle_QoL Fishing stretch"

local stretch = ns.NewStretch()
local frame ---@type Frame its OnUpdate counts the idle end while it counts (QOL-R61)

-- The client's CVars, looked up at each call.
---@type PagleQoLCVars
local cvars = {
	get = function(name)
		return GetCVar(name)
	end,
	set = function(name, value)
		SetCVar(name, value)
	end,
}

-- PagleQoLDB.global.lease. AceDB drops it while empty at PLAYER_LOGOUT, which it may hear before QoL does.
---@return PagleQoLLeaseEntry[]
local function lease()
	---@type table QoL's OnInitialize opened PagleQoLDB before anything here runs
	local global = ns.db.global
	global.lease = global.lease or {}
	return global.lease
end

-- Restores every leased CVar now, or, under lockdown, leaves the lease to wait for RestrictionChanged(false)
-- (QOL-R63, QOL-R66).
local function restore()
	if not InCombatLockdown() then
		ns.RestoreLease(lease(), cvars)
	end
end

local onUpdate

-- The idle count runs only while it counts (QOL-R61).
local function setOnUpdate()
	frame:SetScript("OnUpdate", stretch:IsCounting() and onUpdate or nil)
end

-- Ends the stretch, if one runs, and restores its lease (QOL-R61, QOL-R63).
local function endStretch()
	if stretch:End() then
		restore()
	end
	setOnUpdate()
end

---@param _ Frame
---@param elapsed number
function onUpdate(_, elapsed)
	if stretch:Elapse(elapsed) then
		restore()
	end
	setOnUpdate()
end

--- Restores any lease left over from the last session (QOL-R64), then follows the Fishing stretch. QoL's
--- OnInitialize calls it at ADDON_LOADED, before anything else, once it has registered and opened PagleQoLDB.
function ns.StartStretch()
	frame = CreateFrame("Frame")
	restore()

	Pagle.RegisterCallback(OWNER, "CastStarted", function()
		if stretch:CastStarted(ns.IsArmed()) then
			ns.Lease(lease(), ns.SOFT_INTERACT_LEASE, cvars)
		end
		setOnUpdate()
	end)
	Pagle.RegisterCallback(OWNER, "CastEnded", function()
		stretch:CastEnded()
		setOnUpdate()
	end)

	-- The pole comes off (QOL-R21 stops holding).
	Pagle.RegisterEvent(OWNER, "PLAYER_EQUIPMENT_CHANGED", function()
		if not ns.PoleInHand() then
			endStretch()
		end
	end)
	-- The player mounts.
	Pagle.RegisterEvent(OWNER, "PLAYER_MOUNT_DISPLAY_CHANGED", function()
		if IsMounted() then
			endStretch()
		end
	end)
	-- Restriction starts: PLAYER_REGEN_DISABLED runs before lockdown, so the restores can run then (QOL-R31).
	Pagle.RegisterEvent(OWNER, "PLAYER_REGEN_DISABLED", endStretch)
	-- Logout or /reload. A restore that must wait stays in the lease, saved for the leftover restore (QOL-R64).
	Pagle.RegisterEvent(OWNER, "PLAYER_LOGOUT", endStretch)

	Pagle.RegisterCallback(OWNER, "RestrictionChanged", function(_, isRestricted)
		if isRestricted then
			endStretch()
		elseif not stretch:IsRunning() then
			-- The restores that fell due under lockdown run now (QOL-R66).
			restore()
		end
	end)
end
