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
local Stretch = {}
Stretch.__index = Stretch

--- A stretch that isn't running.
---@return PagleQoLStretch
function ns.NewStretch()
	return setmetatable({ running = false }, Stretch)
end

---@return boolean
function Stretch:IsRunning()
	return self.running
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

--- The soft-interact row, which the reel needs and can't be turned off (QOL-R62, probe B1).
---@type PagleQoLLeaseRow[]
ns.SOFT_INTERACT_LEASE = {
	{ name = "SoftTargetInteract", value = "3" },
	{ name = "SoftTargetInteractRange", value = "15", atLeast = true },
	{ name = "SoftTargetInteractRangeIsHard", value = "0" },
}

--- The Fishing audio mix row: effects on at full; music, ambience and dialog off. Master volume and
--- Sound_EnableAllSound are never leased (QOL-R62, qol.md › Tunables).
---@type PagleQoLLeaseRow[]
ns.AUDIO_MIX_LEASE = {
	{ name = "Sound_EnableSFX", value = "1" },
	{ name = "Sound_SFXVolume", value = "1.0" },
	{ name = "Sound_EnableMusic", value = "0" },
	{ name = "Sound_EnableAmbience", value = "0" },
	{ name = "Sound_EnableDialog", value = "0" },
}

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

--- The While you fish settings a stretch's lease follows: `PagleQoLDB.profile`'s `audio` and `autoLoot` (qol.md ›
--- Data).
---@class PagleQoLLeaseSettings
---@field audio { on: boolean, background: boolean }
---@field autoLoot boolean

--- The rows a stretch leases under `settings` (QOL-R62): soft-interact always, then each feature that is on, the
--- background row only while the audio mix is on too.
---@param settings PagleQoLLeaseSettings
---@return PagleQoLLeaseRow[]
function ns.LeaseRows(settings)
	local rows = {}
	local function add(feature)
		for _, row in ipairs(feature) do
			rows[#rows + 1] = row
		end
	end
	add(ns.SOFT_INTERACT_LEASE)
	if settings.audio.on then
		add(ns.AUDIO_MIX_LEASE)
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
--- new settings (ns.LeaseRows). The rows it turned on are leased now; the CVars it turned off are restored now.
---@param before PagleQoLLeaseRow[]
---@param after PagleQoLLeaseRow[]
---@return PagleQoLLeaseRow[] lease the rows to lease now, in order
---@return table<string, true> restore the names of the CVars to restore now
function ns.LeaseChange(before, after)
	local was, is = {}, {}
	for _, row in ipairs(before) do
		was[row.name] = true
	end
	local lease = {}
	for _, row in ipairs(after) do
		is[row.name] = true
		if not was[row.name] then
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
--- `cvars.set`, then what `cvars.get` reads back is stored as `set`. A CVar the client doesn't know is skipped. An
--- entry still waiting for its restore (QOL-R66) stays while its CVar holds the leased value; one the player has
--- overruled since is replaced, so `orig` is the player's latest value.
---@param lease PagleQoLLeaseEntry[] `PagleQoLDB.global.lease`, changed in place
---@param rows PagleQoLLeaseRow[]
---@param cvars PagleQoLCVars
function ns.Lease(lease, rows, cvars)
	for _, row in ipairs(rows) do
		local current = cvars.get(row.name)
		if current ~= nil and wantsLease(row, current) then
			local others = {}
			for _, entry in ipairs(lease) do
				if entry.name ~= row.name then
					others[#others + 1] = entry
				end
			end
			replaceAll(lease, others)
			local entry = { name = row.name, orig = current }
			lease[#lease + 1] = entry
			cvars.set(row.name, row.value)
			entry.set = cvars.get(row.name)
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
