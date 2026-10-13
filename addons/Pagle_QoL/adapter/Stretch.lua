if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- The Fishing stretch (QOL-R61) and the CVars leased for it (QOL-R62–R66): QoL hears when a stretch starts and ends
-- (logic/Stretch.lua decides), leases soft-interact and each While you fish feature that is on for it, follows those
-- settings mid-stretch, and restores the lease when it ends, at load and when lockdown ends. It changes only CVars
-- (QOL-R5); what it reads, it uses only to decide (QOL-R4).

-- The owner of the stretch's Core event callbacks and WoW event registrations.
local OWNER = "Pagle_QoL Fishing stretch"

local stretch = ns.NewStretch()
local frame ---@type Frame? its OnUpdate counts the idle end while it counts (QOL-R61)

--- The running Fishing stretch's number this session, or nil while none runs (QOL-R61): the out-of-lures Nudge
--- shows once per stretch (QOL-R53).
---@return integer?
function ns.RunningStretch()
	return stretch:Number()
end

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

-- Restores every leased CVar now, or with `only` just the ones it names, or, under lockdown, leaves the lease to
-- wait for RestrictionChanged(false) (QOL-R63, QOL-R65, QOL-R66).
---@param only table<string, true>?
local function restore(only)
	if not InCombatLockdown() then
		ns.RestoreLease(lease(), cvars, only)
	end
end

--- Changes a While you fish setting with `change(profile)` (QOL-R62). During a stretch, the CVars of a feature it
--- turned off are restored at once and those of one it turned on are leased at once; the rest of the lease stays
--- as it is (QOL-R65). Outside one, the next stretch follows the new setting.
---@param change fun(profile: PagleQoLLeaseSettings) changes `PagleQoLDB.profile` in place
function ns.ChangeLeaseSetting(change)
	---@type PagleQoLLeaseSettings QoL's OnInitialize opened PagleQoLDB before its page has any row to change
	local profile = ns.db.profile
	local before = ns.LeaseRows(profile)
	change(profile)
	if not stretch:IsRunning() then
		return
	end
	local rows, names = ns.LeaseChange(before, ns.LeaseRows(profile))
	restore(names)
	ns.Lease(lease(), rows, cvars)
end

local onUpdate

-- The idle count runs only while it counts (QOL-R61). Its frame is made the first time it counts, which is always
-- while armed, so never in combat (QOL-R33).
local function setOnUpdate()
	local counting = stretch:IsCounting()
	if counting and not frame then
		frame = CreateFrame("Frame")
	end
	if frame then
		frame:SetScript("OnUpdate", counting and onUpdate or nil)
	end
end

--- Ends the stretch, if one runs, and restores its lease now or, under lockdown, once it ends (QOL-R61, QOL-R63,
--- QOL-R66). adapter/Combat.lua calls it as restriction starts, in or out of lockdown (QOL-R31).
function ns.EndStretch()
	if stretch:End() then
		restore()
	end
	setOnUpdate()
end

-- The stretch ends on its own: the pole came off or the player mounted (QOL-R61). Then the swap-back Nudge may show;
-- restriction and logout end it through ns.EndStretch alone, with none (QOL-R77).
local function endOnItsOwn()
	local running = stretch:IsRunning()
	ns.EndStretch()
	if running then
		ns.NudgeSwapBack()
	end
end

---@param _ Frame
---@param elapsed number
function onUpdate(_, elapsed)
	if stretch:Elapse(elapsed) then
		restore()
		-- The idle end is the stretch ending on its own too (QOL-R77).
		ns.NudgeSwapBack()
	end
	setOnUpdate()
end

--- Restores any lease left over from the last session (QOL-R64), then follows the Fishing stretch. QoL's
--- OnInitialize calls it at ADDON_LOADED, before anything else, once it has registered and opened PagleQoLDB.
function ns.StartStretch()
	restore()

	-- A stretch starts only while armed, so never while restricted or standing down (QOL-R30, QOL-R82). It leases
	-- soft-interact and each While you fish feature that is on (QOL-R62).
	Pagle.RegisterCallback(OWNER, "CastStarted", function()
		if stretch:CastStarted(ns.IsArmed()) then
			ns.Lease(lease(), ns.LeaseRows(ns.db.profile), cvars)
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
			endOnItsOwn()
		end
	end)
	-- The player mounts.
	Pagle.RegisterEvent(OWNER, "PLAYER_MOUNT_DISPLAY_CHANGED", function()
		if IsMounted() then
			endOnItsOwn()
		end
	end)
	-- Logout or /reload. A restore that must wait stays in the lease, saved for the leftover restore (QOL-R64).
	Pagle.RegisterEvent(OWNER, "PLAYER_LOGOUT", ns.EndStretch)
	-- Restriction starting ends the stretch from adapter/Combat.lua (QOL-R31). Its end runs the restores that fell
	-- due under lockdown (QOL-R66); no stretch can have started since.
	Pagle.RegisterCallback(OWNER, "RestrictionChanged", function(_, isRestricted)
		if not isRestricted and not stretch:IsRunning() then
			restore()
		end
	end)
end
