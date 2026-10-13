---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The conditions Core reads from the client: a Cast's snapshot (LOG-R20), Pagle.GetConditions (LOG-R45) and
-- ConditionsChanged (LOG-R47). Its own owner, so no other Core file's registration replaces these.
local OWNER = "Pagle conditions"

-- Tunables: the lure and calendar polls (LOG-R47).
local LURE_POLL, CALENDAR_POLL = 5, 60

-- The Fishing skill line (LOG-R30).
local FISHING_SKILL_LINE = 356

--- Payload of `ConditionsChanged`: the keys whose conditions changed, in a fixed order (LOG-R47).
---@alias PagleConditionsChangedHandler fun(event: "ConditionsChanged", changedKeys: PagleConditionKey[])

-- Whether a value, or anything in it down to `depth` tables deep, is secret (CORE-R31).
---@param value any
---@param depth integer
---@return boolean
local function holdsSecret(value, depth)
	if issecretvalue(value) then
		return true
	end
	if type(value) == "table" and depth > 0 then
		for _, inner in pairs(value) do
			if holdsSecret(inner, depth - 1) then
				return true
			end
		end
	end
	return false
end

-- A value the client gave, or nil if it's secret (CORE-R31).
---@generic T
---@param value T
---@return T?
local function unlessSecret(value)
	if issecretvalue(value) then
		return nil
	end
	return value
end

--- Fishing's rank, max rank and modifier (LOG-R30): `GetProfessions()`, then `GetProfessionInfo` on its 4th
--- return, skill line 356. Each is nil while secret, all three without the profession.
---@return integer? rank
---@return integer? max
---@return integer? mod
function ns.ReadFishingSkill()
	local fishing = select(4, GetProfessions())
	if fishing == nil or issecretvalue(fishing) then
		return nil, nil, nil
	end
	local _, _, rank, max, _, _, line, mod = GetProfessionInfo(fishing)
	if issecretvalue(line) or line ~= FISHING_SKILL_LINE then
		return nil, nil, nil
	end
	return unlessSecret(rank), unlessSecret(max), unlessSecret(mod)
end

-- The realm's calendar time now, or nil while any of it is secret.
---@return CalendarTime?
local function readCalendarTime()
	local now = C_DateAndTime.GetCurrentCalendarTime()
	if now == nil or holdsSecret(now, 1) then
		return nil
	end
	return now
end

-- Today's calendar day events (LOG-R46), or nil if anything read is secret: secret calendar data counts as no
-- events. Read from the current month, whichever month the calendar shows.
---@param now CalendarTime?
---@return PagleDayEvent[]?
local function readDayEvents(now)
	if now == nil then
		return nil
	end
	local shown = C_Calendar.GetMonthInfo(0)
	if shown == nil or holdsSecret(shown, 1) then
		return nil
	end
	local offset = ns.CalendarMonthOffset(shown, now)
	local count = C_Calendar.GetNumDayEvents(offset, now.monthDay)
	if issecretvalue(count) then
		return nil
	end
	local events = {}
	for i = 1, count or 0 do
		local event = C_Calendar.GetDayEvent(offset, now.monthDay, i)
		if holdsSecret(event, 2) then
			return nil
		end
		events[#events + 1] = event
	end
	return events
end

-- The fishing auras from the catalogue's list that the player has, ascending (LOG-R20); nil if a read is secret or
-- raises, as aura reads do while auras are secret.
---@return integer[]?
local function readAuras()
	local active = {}
	for _, spellID in ipairs(ns.Catalogue.GetFishingAuras()) do
		local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
		if not ok or issecretvalue(aura) then
			return nil
		end
		if aura then
			active[#active + 1] = spellID
		end
	end
	return active
end

-- The main-hand lure's enchant ID (LOG-R20), nil with none on.
---@return integer?
local function readLure()
	local hasEnchant, _, _, enchantID = GetWeaponEnchantInfo()
	if not hasEnchant or issecretvalue(hasEnchant) then
		return nil
	end
	return enchantID
end

-- How each ConditionsChanged key's fields are read into a snapshot (LOG-R20, LOG-R47). The area reader also keeps
-- the texts of a zone or subzone that didn't resolve in `extra.unresolved`.
---@type table<PagleConditionKey, fun(snapshot: table, now: CalendarTime?, extra: { unresolved: PagleUnresolvedAreas? })>
local readers = {
	area = function(snapshot, _, extra)
		snapshot.zone, snapshot.subzone, extra.unresolved = ns.ReadAreas()
	end,
	auras = function(snapshot)
		snapshot.auras = readAuras()
	end,
	lure = function(snapshot)
		snapshot.lure = readLure()
	end,
	events = function(snapshot, now)
		local minute = now and now.hour * 60 + now.minute
		snapshot.events = ns.ActiveEvents(readDayEvents(now), ns.Catalogue.GetEventIDs(), minute)
	end,
	skill = function(snapshot)
		local rank, _, mod = ns.ReadFishingSkill()
		snapshot.skillRank, snapshot.skillMod = rank, mod
	end,
}

-- The fields of `keys`, read now, each secret value nil (CORE-R31), and the texts of a zone or subzone that didn't
-- resolve when `keys` holds "area".
---@param keys PagleConditionKey[]
---@param now CalendarTime?
---@return table snapshot
---@return PagleUnresolvedAreas? unresolved
local function readKeys(keys, now)
	local snapshot, extra = {}, {}
	for _, key in ipairs(keys) do
		readers[key](snapshot, now, extra)
	end
	return (ns.StripSecrets(issecretvalue, snapshot)), extra.unresolved
end

-- Every raw observation of the snapshot (LOG-R20), each secret value nil (CORE-R31), and the texts of a zone or
-- subzone that didn't resolve.
---@param now CalendarTime?
---@return ConditionsSnapshot snapshot
---@return PagleUnresolvedAreas? unresolved
local function readSnapshot(now)
	local snapshot, unresolved = readKeys(ns.CONDITION_KEYS, now)
	snapshot.time = GetServerTime()
	local hour, minute = GetGameTime()
	if hour and not issecretvalue(hour) and not issecretvalue(minute) then
		snapshot.minute = hour * 60 + minute
	end
	snapshot.uiMap = C_Map.GetBestMapForUnit("player")
	snapshot.instance = select(8, GetInstanceInfo())
	return (ns.StripSecrets(issecretvalue, snapshot)), unresolved
end

--- A Cast's snapshot of raw observations (LOG-R20), read now: everything but the items, which the Cast adds.
--- Secret values are nil (CORE-R31); a zone or subzone that didn't resolve is 0, and its texts come back as
--- `unresolved` for the diagnostics buffer (LOG-R81). No realm date (a Cast's is derived, LOG-R49) and no
--- restriction flag.
---@return ConditionsSnapshot snapshot
---@return PagleUnresolvedAreas? unresolved
function ns.TakeSnapshot()
	return readSnapshot(readCalendarTime())
end

--- The conditions now (LOG-R45): a Cast snapshot's fields (LOG-R20), plus the realm date from
--- `C_DateAndTime.GetCurrentCalendarTime()` and whether Pagle is restricted. Secret values are nil (CORE-R31). A
--- new table each call, shared and never changed once handed out (CORE-R18).
---@return ConditionsSnapshot
function Pagle.GetConditions()
	local now = readCalendarTime()
	local snapshot = readSnapshot(now)
	if now then
		snapshot.date = { year = now.year, month = now.month, day = now.monthDay, weekday = now.weekday }
	end
	snapshot.restricted = Pagle.IsRestricted()
	return snapshot
end

-- The last reading of each key, from the baseline taken at login on.
local tracker = ns.NewConditionsTracker()
local started = false

--- Re-reads the given keys and fires `ConditionsChanged` with those that changed since their last reading, if any
--- did (LOG-R47). Nothing happens before `ns.StartConditions`. The skill reader (LOG-R32) calls it with "skill".
---@param ... PagleConditionKey
function ns.RefreshConditions(...)
	if not started then
		return
	end
	local keys = { ... }
	local changed = tracker:Update((readKeys(keys, readCalendarTime())), keys)
	if #changed > 0 then
		ns.Fire("ConditionsChanged", changed)
	end
end

--- Starts the conditions service, once, at PLAYER_LOGIN after the area index is built (LOG-R1 step 2): asks the
--- server for calendar data, takes every key's baseline, then follows the zone-change events, the player's
--- UNIT_AURA, CALENDAR_UPDATE_EVENT_LIST and the lure and calendar polls (LOG-R47).
function ns.StartConditions()
	if started then
		return
	end
	started = true
	C_Calendar.OpenCalendar()
	tracker:Update((readKeys(ns.CONDITION_KEYS, readCalendarTime())))

	local function refresher(key)
		return function()
			ns.RefreshConditions(key)
		end
	end
	for _, event in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }) do
		Pagle.RegisterEvent(OWNER, event, refresher("area"))
	end
	Pagle.RegisterUnitEvent(OWNER, "UNIT_AURA", "player", refresher("auras"))
	Pagle.RegisterEvent(OWNER, "CALENDAR_UPDATE_EVENT_LIST", refresher("events"))
	C_Timer.NewTicker(LURE_POLL, refresher("lure"))
	C_Timer.NewTicker(CALENDAR_POLL, refresher("events"))
end

-- After the area index (adapter/Catalogue.lua, earlier in the TOC) and before ModulesChanged (adapter/Modules.lua),
-- so the baseline has real areas and a Module that reads the conditions at ModulesChanged meets a running service.
Pagle.RegisterEvent(OWNER, "PLAYER_LOGIN", function()
	Pagle.UnregisterEvent(OWNER, "PLAYER_LOGIN")
	ns.StartConditions()
end)
