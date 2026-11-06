if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- The Fishing stretch (QOL-R61) and the lease of its CVars (QOL-R62, QOL-R63, QOL-R65): pure logic, everything
-- passed in (CORE-R7). adapter/Stretch.lua hears the events and reads and sets the CVars.

--- Seconds after the last CastEnded, with no fishing channel since, that a stretch ends (qol.md › Tunables).
ns.STRETCH_IDLE_END = 60

--- A Fishing stretch: QoL's own live state, separate from the Session (QOL-R61).
---@class PagleQoLStretch
---@field running boolean
---@field idle number? seconds since the last CastEnded, while no channel has started since; nil otherwise
---@field started integer how many stretches have started
local Stretch = {}
Stretch.__index = Stretch

--- A stretch that isn't running.
---@return PagleQoLStretch
function ns.NewStretch()
	return setmetatable({ running = false, started = 0 }, Stretch)
end

---@return boolean
function Stretch:IsRunning()
	return self.running
end

--- The running stretch's number, counting from 1, or nil while none runs: what tells one stretch from the next, so
--- the out-of-lures Nudge shows once per stretch (QOL-R53).
---@return integer?
function Stretch:Number()
	return self.running and self.started or nil
end

--- Whether the idle end counts down: a stretch runs and no channel started since its last CastEnded.
---@return boolean
function Stretch:IsCounting()
	return self.idle ~= nil
end

--- Core's CastStarted. A stretch starts here while none is running and QoL is armed (QOL-R61, QOL-R30). Any
--- channel stops the idle count.
---@param armed boolean
---@return boolean started whether this started a stretch
function Stretch:CastStarted(armed)
	self.idle = nil
	if self.running or not armed then
		return false
	end
	self.running = true
	self.started = self.started + 1
	return true
end

--- Core's CastEnded, any outcome: the idle count starts again from 0 (QOL-R61).
function Stretch:CastEnded()
	if self.running then
		self.idle = 0
	end
end

--- Time passing. The stretch ends once the idle count reaches STRETCH_IDLE_END (QOL-R61).
---@param seconds number
---@return boolean ended whether this ended the stretch
function Stretch:Elapse(seconds)
	if not self.idle then
		return false
	end
	self.idle = self.idle + seconds
	if self.idle < ns.STRETCH_IDLE_END then
		return false
	end
	return self:End()
end

--- Ends the stretch: the pole came off, the player mounted, restriction started or logout (QOL-R61).
---@return boolean ended whether a stretch was running
function Stretch:End()
	local wasRunning = self.running
	self.running, self.idle = false, nil
	return wasRunning
end

--- The client's CVars, as the adapter passes them in: `get` is GetCVar, `set` is SetCVar.
---@class PagleQoLCVars
---@field get fun(name: string): string?
---@field set fun(name: string, value: string)

--- One CVar QoL leases for a stretch, and the value it sets (QOL-R62).
---@class PagleQoLLeaseRow
---@field name string
---@field value string
---@field atLeast boolean? leased only while the player's value is below `value`, read as numbers

--- An entry of `PagleQoLDB.global.lease`: a CVar leased now, the player's value and what QoL's set read back as
--- (QOL-R63, qol.md › Data).
---@class PagleQoLLeaseEntry
---@field name string
---@field orig string
---@field set string?
---@field origName string? the output device's entry only: the name of the player's device at `orig` (QOL-R68)

--- The soft-interact row, which the reel needs and can't be turned off (QOL-R62, probe B1).
---@type PagleQoLLeaseRow[]
ns.SOFT_INTERACT_LEASE = {
	{ name = "SoftTargetInteract", value = "3" },
	{ name = "SoftTargetInteractRange", value = "15", atLeast = true },
	{ name = "SoftTargetInteractRangeIsHard", value = "0" },
}

--- The Fishing audio mix's channels, in lease order: each one's setting in `PagleQoLDB.profile.audio`, its volume CVar
--- and its on/off CVar. Master has no on/off CVar, so it is never turned off, and Sound_EnableAllSound is never leased
--- (QOL-R62, qol.md › Tunables).
---@type { key: string, volume: string, enable: string? }[]
ns.AUDIO_CHANNELS = {
	{ key = "master", volume = "Sound_MasterVolume" },
	{ key = "effects", volume = "Sound_SFXVolume", enable = "Sound_EnableSFX" },
	{ key = "music", volume = "Sound_MusicVolume", enable = "Sound_EnableMusic" },
	{ key = "ambience", volume = "Sound_AmbienceVolume", enable = "Sound_EnableAmbience" },
	{ key = "dialog", volume = "Sound_DialogVolume", enable = "Sound_EnableDialog" },
}

--- The lowest master volume the audio mix sets, in percent, so the bobber's splash stays audible: master has no Off
--- (QOL-R62, qol.md › Tunables).
ns.AUDIO_MASTER_MIN = 10

--- The CVar that picks the game's sound output device, by its index in the client's list from 0 (QOL-R68).
ns.OUTPUT_DEVICE_CVAR = "Sound_OutputDriverIndex"

-- A volume in percent as its CVar value: 100 is "1.0", 50 "0.5", 35 "0.35" (QOL-R62).
---@param percent number
---@return string
local function volumeValue(percent)
	percent = math.max(0, math.min(100, percent))
	return (("%.2f"):format(percent / 100):gsub("0$", ""))
end

-- The rows of one channel under its setting (QOL-R62): unticked leases nothing; ticked at 0% its on/off CVar at 0
-- (Off); ticked at a volume its on/off CVar at 1, then its volume. Master has no on/off CVar: it leases only its
-- volume, never below AUDIO_MASTER_MIN.
---@param channel { key: string, volume: string, enable: string? }
---@param level PagleQoLAudioChannel
---@param rows PagleQoLLeaseRow[] added to in place
local function addChannel(channel, level, rows)
	if not level.on then
		return
	end
	local volume = level.volume
	if not channel.enable then
		rows[#rows + 1] = { name = channel.volume, value = volumeValue(math.max(ns.AUDIO_MASTER_MIN, volume)) }
	elseif volume <= 0 then
		rows[#rows + 1] = { name = channel.enable, value = "0" }
	else
		rows[#rows + 1] = { name = channel.enable, value = "1" }
		rows[#rows + 1] = { name = channel.volume, value = volumeValue(volume) }
	end
end

--- The output device's index in `devices`, the client's device names in its order from index 0, or nil when the
--- device isn't there now: unplugged, say (QOL-R68). The first of two devices with one name is the one.
---@param devices string[]?
---@param name string
---@return integer?
function ns.OutputDeviceIndex(devices, name)
	if name == "" then
		return nil
	end
	for i, device in ipairs(devices or {}) do
		if device == name then
			return i - 1
		end
	end
	return nil
end

--- Notes on the output device's lease entry, once, the name of the player's own device: the one at its `orig` index
--- in `devices`, the client's device names by index from 0 (QOL-R68).
---@param lease PagleQoLLeaseEntry[] `PagleQoLDB.global.lease`, changed in place
---@param devices string[]
function ns.NameLeasedDevice(lease, devices)
	for _, entry in ipairs(lease) do
		if entry.name == ns.OUTPUT_DEVICE_CVAR and entry.origName == nil then
			local name = devices[(tonumber(entry.orig) or -1) + 1]
			if name ~= "" then
				entry.origName = name
			end
		end
	end
end

--- Points the output device's lease entry's `orig` at the player's own device where `devices` lists it now, so a
--- restore after the devices reordered (one unplugged, then a /reload) puts back that device, not whatever took its
--- index. A device no longer listed keeps the raw `orig` (QOL-R68).
---@param lease PagleQoLLeaseEntry[] `PagleQoLDB.global.lease`, changed in place
---@param devices string[]
function ns.ResolveLeasedDevice(lease, devices)
	for _, entry in ipairs(lease) do
		if entry.name == ns.OUTPUT_DEVICE_CVAR and entry.origName then
			local index = ns.OutputDeviceIndex(devices, entry.origName)
			if index then
				entry.orig = tostring(index)
			end
		end
	end
end

--- The Fishing audio mix's rows under `audio` (QOL-R62, QOL-R68): each channel by its setting, then the output device
--- while the one chosen is there. A setting `audio` lacks is its default, the mix 1.1 leased.
---@param audio PagleQoLAudioSettings
---@param devices string[]? the client's output devices, by index from 0
---@return PagleQoLLeaseRow[]
function ns.AudioMixRows(audio, devices)
	local defaults = ns.DB_DEFAULTS.profile.audio
	local rows = {}
	for _, channel in ipairs(ns.AUDIO_CHANNELS) do
		local level = audio[channel.key] or defaults[channel.key]
		addChannel(channel, level --[[@as PagleQoLAudioChannel]], rows)
	end
	local index = ns.OutputDeviceIndex(devices, audio.device or defaults.device)
	if index then
		rows[#rows + 1] = { name = ns.OUTPUT_DEVICE_CVAR, value = tostring(index) }
	end
	return rows
end

--- The background row, leased only while the audio mix is on too (QOL-R62).
---@type PagleQoLLeaseRow[]
ns.BACKGROUND_SOUND_LEASE = {
	{ name = "Sound_EnableSoundWhenGameIsInBG", value = "1" },
}

--- The auto-loot row (QOL-R62).
---@type PagleQoLLeaseRow[]
ns.AUTO_LOOT_LEASE = {
	{ name = "autoLootDefault", value = "1" },
}

--- A channel's setting in the Fishing audio mix (QOL-R62): whether the mix changes it, and its volume in percent; 0 is
--- Off for a channel with an on/off CVar.
---@class PagleQoLAudioChannel
---@field on boolean
---@field volume number

--- `PagleQoLDB.profile.audio` (qol.md › Data). A level or device it lacks is its default (ns.DB_DEFAULTS).
---@class PagleQoLAudioSettings
---@field on boolean
---@field background boolean
---@field master PagleQoLAudioChannel?
---@field effects PagleQoLAudioChannel?
---@field music PagleQoLAudioChannel?
---@field ambience PagleQoLAudioChannel?
---@field dialog PagleQoLAudioChannel?
---@field device string? the output device's name, or "" for Don't change (QOL-R68)

--- The While you fish settings a stretch's lease follows: `PagleQoLDB.profile`'s `audio` and `autoLoot` (qol.md ›
--- Data).
---@class PagleQoLLeaseSettings
---@field audio PagleQoLAudioSettings
---@field autoLoot boolean

--- The rows a stretch leases under `settings` (QOL-R62): soft-interact always, then each feature that is on, the
--- background row only while the audio mix is on too.
---@param settings PagleQoLLeaseSettings
---@param devices string[]? the client's output devices, by index from 0 (QOL-R68)
---@return PagleQoLLeaseRow[]
function ns.LeaseRows(settings, devices)
	local rows = {}
	local function add(feature)
		for _, row in ipairs(feature) do
			rows[#rows + 1] = row
		end
	end
	add(ns.SOFT_INTERACT_LEASE)
	if settings.audio.on then
		add(ns.AudioMixRows(settings.audio, devices))
		if settings.audio.background then
			add(ns.BACKGROUND_SOUND_LEASE)
		end
	end
	if settings.autoLoot then
		add(ns.AUTO_LOOT_LEASE)
	end
	return rows
end

--- What a settings change does to a running stretch (QOL-R65): `before` and `after` are its rows under the old and
--- new settings (ns.LeaseRows). The rows it turned on or gave a new value are leased now; the CVars it turned off are
--- restored now.
---@param before PagleQoLLeaseRow[]
---@param after PagleQoLLeaseRow[]
---@return PagleQoLLeaseRow[] lease the rows to lease now, in order
---@return table<string, true> restore the names of the CVars to restore now
function ns.LeaseChange(before, after)
	local was, is = {}, {}
	for _, row in ipairs(before) do
		was[row.name] = row.value
	end
	local lease = {}
	for _, row in ipairs(after) do
		is[row.name] = true
		if was[row.name] ~= row.value then
			lease[#lease + 1] = row
		end
	end
	local restore = {}
	for name in pairs(was) do
		if not is[name] then
			restore[name] = true
		end
	end
	return lease, restore
end

--- Whether two CVar values are the same: compared as numbers when both parse as numbers, else as strings
--- (QOL-R62, QOL-R63).
---@param a string
---@param b string
---@return boolean
function ns.SameCVarValue(a, b)
	local x, y = tonumber(a), tonumber(b)
	if x and y then
		return x == y
	end
	return a == b
end

-- Whether a row wants its CVar changed from `current` (QOL-R62): not if it already holds the leased value, nor, for
-- an at-least row, if it's already that high.
---@param row PagleQoLLeaseRow
---@param current string
---@return boolean
local function wantsLease(row, current)
	if row.atLeast then
		local number = tonumber(current)
		return number ~= nil and number < tonumber(row.value)
	end
	return not ns.SameCVarValue(current, row.value)
end

-- Empties `lease` in place (it is the saved table) and refills it with `entries`.
---@param lease PagleQoLLeaseEntry[]
---@param entries PagleQoLLeaseEntry[]
local function replaceAll(lease, entries)
	for i = #lease, 1, -1 do
		lease[i] = nil
	end
	for i, entry in ipairs(entries) do
		lease[i] = entry
	end
end

--- Leases each row's CVar that wants it (QOL-R62, QOL-R63): `{ name, orig }` goes into `lease` first, then
--- `cvars.set`, then what `cvars.get` reads back is stored as `set`, or the value set if it reads back nothing, as
--- while the sound system restarts (QOL-R68). A CVar the client doesn't know is skipped. A CVar whose entry it still
--- reads `set` of is leased again at the row's value, keeping that entry's `orig`: a value changed mid-stretch
--- (QOL-R65), or an entry still waiting for its restore (QOL-R66), which stays as it is while its CVar holds the
--- row's value. One the player has overruled since is replaced, so `orig` is the player's latest value.
---@param lease PagleQoLLeaseEntry[] `PagleQoLDB.global.lease`, changed in place
---@param rows PagleQoLLeaseRow[]
---@param cvars PagleQoLCVars
function ns.Lease(lease, rows, cvars)
	for _, row in ipairs(rows) do
		local current = cvars.get(row.name)
		if current ~= nil and wantsLease(row, current) then
			local held
			local others = {}
			for _, entry in ipairs(lease) do
				if entry.name ~= row.name then
					others[#others + 1] = entry
				elseif entry.set ~= nil and ns.SameCVarValue(current, entry.set) then
					held = entry
				end
			end
			local entry = held
			if not entry then
				replaceAll(lease, others)
				entry = { name = row.name, orig = current }
				lease[#lease + 1] = entry
			end
			cvars.set(row.name, row.value)
			entry.set = cvars.get(row.name) or row.value
		end
	end
end

--- Restores every entry in `lease`, or with `only` just the entries it names (QOL-R63, QOL-R64, QOL-R65): a CVar
--- that still reads `set` goes back to `orig`; one the player changed since stays theirs. Each entry is then removed,
--- unless its restore didn't take (the CVar doesn't read `orig` back), which stays for the leftover restore at the
--- next load. Entries `only` doesn't name stay as they are.
---@param lease PagleQoLLeaseEntry[] `PagleQoLDB.global.lease`, changed in place
---@param cvars PagleQoLCVars
---@param only table<string, true>? the names of the CVars to restore; every entry when nil
function ns.RestoreLease(lease, cvars, only)
	local kept = {}
	for _, entry in ipairs(lease) do
		if only and not only[entry.name] then
			kept[#kept + 1] = entry
		else
			local current = cvars.get(entry.name)
			if current ~= nil and entry.set ~= nil and ns.SameCVarValue(current, entry.set) then
				cvars.set(entry.name, entry.orig)
				local after = cvars.get(entry.name)
				if after == nil or not ns.SameCVarValue(after, entry.orig) then
					kept[#kept + 1] = entry
				end
			end
		end
	end
	replaceAll(lease, kept)
end
