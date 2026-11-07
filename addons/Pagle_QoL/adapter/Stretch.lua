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

--- The client's sound output devices, by index from 0, as Game › Sound lists them (QOL-R68): read at each call, so a
--- headset plugged in or out since shows. None on a client without the calls.
---@return string[]
function ns.OutputDevices()
	local devices = {}
	if Sound_GameSystem_GetNumOutputDrivers and Sound_GameSystem_GetOutputDriverNameByIndex then
		for index = 0, (Sound_GameSystem_GetNumOutputDrivers() or 0) - 1 do
			devices[index + 1] = Sound_GameSystem_GetOutputDriverNameByIndex(index) or ""
		end
	end
	return devices
end

-- Windows-1252's 0x80–0x9F as Unicode code points, nil where the code page leaves the byte undefined; 0xA0–0xFF are
-- Latin-1's, the byte's own code point.
local CP1252 = {
	[0x80] = 0x20AC,
	[0x82] = 0x201A,
	[0x83] = 0x0192,
	[0x84] = 0x201E,
	[0x85] = 0x2026,
	[0x86] = 0x2020,
	[0x87] = 0x2021,
	[0x88] = 0x02C6,
	[0x89] = 0x2030,
	[0x8A] = 0x0160,
	[0x8B] = 0x2039,
	[0x8C] = 0x0152,
	[0x8E] = 0x017D,
	[0x91] = 0x2018,
	[0x92] = 0x2019,
	[0x93] = 0x201C,
	[0x94] = 0x201D,
	[0x95] = 0x2022,
	[0x96] = 0x2013,
	[0x97] = 0x2014,
	[0x98] = 0x02DC,
	[0x99] = 0x2122,
	[0x9A] = 0x0161,
	[0x9B] = 0x203A,
	[0x9C] = 0x0153,
	[0x9E] = 0x017E,
	[0x9F] = 0x0178,
}

-- A high byte read as Windows-1252, in UTF-8; "?" for one the code page leaves undefined.
---@param byte integer 0x80–0xFF
---@return string
local function fromCP1252(byte)
	local code = byte >= 0xA0 and byte or CP1252[byte]
	if not code then
		return "?"
	elseif code < 0x800 then
		return string.char(0xC0 + math.floor(code / 0x40), 0x80 + code % 0x40)
	end
	return string.char(0xE0 + math.floor(code / 0x1000), 0x80 + math.floor(code / 0x40) % 0x40, 0x80 + code % 0x40)
end

-- Whether `byte` is a UTF-8 continuation byte, within `low`–`high` when given (the second byte's narrower range).
---@param byte integer?
---@param low integer?
---@param high integer?
---@return boolean
local function continues(byte, low, high)
	return byte ~= nil and byte >= (low or 0x80) and byte <= (high or 0xBF)
end

-- The length of the valid UTF-8 sequence at `i` in `text` (RFC 3629: no overlong form, no surrogate, nothing past
-- U+10FFFF), or nil when the byte there starts none.
---@param text string
---@param i integer
---@return integer?
local function utf8Length(text, i)
	local b1, b2, b3, b4 = text:byte(i, i + 3)
	if b1 < 0x80 then
		return 1
	elseif b1 >= 0xC2 and b1 <= 0xDF then
		return continues(b2) and 2 or nil
	elseif b1 >= 0xE0 and b1 <= 0xEF then
		local low, high = b1 == 0xE0 and 0xA0 or 0x80, b1 == 0xED and 0x9F or 0xBF
		return continues(b2, low, high) and continues(b3) and 3 or nil
	elseif b1 >= 0xF0 and b1 <= 0xF4 then
		local low, high = b1 == 0xF0 and 0x90 or 0x80, b1 == 0xF4 and 0x8F or 0xBF
		return continues(b2, low, high) and continues(b3) and continues(b4) and 4 or nil
	end
	return nil
end

--- `text` as the font can draw it (QOL-R68, #597). The client names a sound output device in the Windows code page,
--- not UTF-8: "Kopfh\246rer", whose lone 0xF6 the font draws as a box. So each byte outside a valid UTF-8 sequence is
--- read as Windows-1252 ("ö"), and valid UTF-8 is kept byte for byte: text that is all valid UTF-8 comes back as it
--- was. For what is shown only: a device's name is still matched and saved as the client gives it.
---@param text string
---@return string
function ns.ReadableText(text)
	local parts, from, i = {}, 1, 1
	while i <= #text do
		local length = utf8Length(text, i)
		if length then
			i = i + length
		else
			parts[#parts + 1] = text:sub(from, i - 1)
			parts[#parts + 1] = fromCP1252(text:byte(i))
			i = i + 1
			from = i
		end
	end
	if #parts == 0 then
		return text
	end
	parts[#parts + 1] = text:sub(from)
	return table.concat(parts)
end

-- Whether PLAYER_LOGOUT has come: the client reloads its sound from the CVars after a logout or /reload anyway.
local loggingOut = false

-- Runs `change`, a lease or a restore, then restarts the sound system if it changed the output device, so the sound
-- moves to the device now (QOL-R68). A lease or restore that leaves the device as it was restarts nothing, nor does
-- one at logout or /reload.
---@param change fun()
local function changingSound(change)
	if loggingOut then
		change()
		return
	end
	local before = GetCVar(ns.OUTPUT_DEVICE_CVAR)
	change()
	local after = GetCVar(ns.OUTPUT_DEVICE_CVAR)
	if
		before ~= nil
		and after ~= nil
		and not ns.SameCVarValue(before, after)
		and Sound_GameSystem_RestartSoundSystem
	then
		Sound_GameSystem_RestartSoundSystem()
	end
end

-- Restores every leased CVar now, or with `only` just the ones it names, or, under lockdown, leaves the lease to
-- wait for RestrictionChanged(false) (QOL-R63, QOL-R65, QOL-R66). It doesn't restart the sound system.
---@param only table<string, true>?
local function restoreLease(only)
	if not InCombatLockdown() then
		-- The player's own device by its name, where the client lists it now (QOL-R68).
		ns.ResolveLeasedDevice(lease(), ns.OutputDevices())
		ns.RestoreLease(lease(), cvars, only)
	end
end

-- restoreLease, restarting the sound system if it put the output device back (QOL-R68).
---@param only table<string, true>?
local function restore(only)
	changingSound(function()
		restoreLease(only)
	end)
end

--- Changes a While you fish setting with `change(profile)` (QOL-R62). During a stretch, the CVars of a feature it
--- turned off are restored at once and those it turned on or gave a new value (a channel's level, the output device)
--- are leased at once; the rest of the lease stays as it is (QOL-R65). Outside one, the next stretch follows the new
--- setting.
---@param change fun(profile: PagleQoLLeaseSettings) changes `PagleQoLDB.profile` in place
function ns.ChangeLeaseSetting(change)
	---@type PagleQoLLeaseSettings QoL's OnInitialize opened PagleQoLDB before its page has any row to change
	local profile = ns.db.profile
	local devices = ns.OutputDevices()
	local before = ns.LeaseRows(profile, devices)
	change(profile)
	if not stretch:IsRunning() then
		return
	end
	local rows, names = ns.LeaseChange(before, ns.LeaseRows(profile, devices))
	-- One restart at most, for the restore and the lease together (QOL-R68).
	changingSound(function()
		restoreLease(names)
		ns.Lease(lease(), rows, cvars)
		ns.NameLeasedDevice(lease(), devices)
	end)
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
	-- soft-interact and each While you fish feature that is on (QOL-R62), the output device among them (QOL-R68).
	Pagle.RegisterCallback(OWNER, "CastStarted", function()
		if stretch:CastStarted(ns.IsArmed()) then
			changingSound(function()
				local devices = ns.OutputDevices()
				ns.Lease(lease(), ns.LeaseRows(ns.db.profile, devices), cvars)
				ns.NameLeasedDevice(lease(), devices)
			end)
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
	-- Logout or /reload. QoL logs out first: each restore's SetCVar fires CVAR_UPDATE, which then evaluates nothing, as
	-- AceDB may have stripped the profile's defaults already (QOL-R30, QOL-R63). A restore that must wait stays in the
	-- lease, saved for the leftover restore (QOL-R64).
	Pagle.RegisterEvent(OWNER, "PLAYER_LOGOUT", function()
		loggingOut = true
		ns.LogOut()
		ns.EndStretch()
	end)
	-- Restriction starting ends the stretch from adapter/Combat.lua (QOL-R31). Its end runs the restores that fell
	-- due under lockdown (QOL-R66); no stretch can have started since.
	Pagle.RegisterCallback(OWNER, "RestrictionChanged", function(_, isRestricted)
		if not isRestricted and not stretch:IsRunning() then
			restore()
		end
	end)
end
