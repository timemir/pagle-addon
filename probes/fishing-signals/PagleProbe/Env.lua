-- PagleProbe/Env.lua
-- One-shot environment dumps (run once per session, a few seconds after
-- login, never in combat) plus the small readers the fishing log reuses:
-- skill, lure, buffs, weather, location and area IDs. All read-only.

local ADDON, ns = ...
local issecret = ns.issecret

----------------------------------------------------------------------
-- IDs to check (from the content-data research, docs/research/)
----------------------------------------------------------------------
ns.ITEMS = {
  -- Missing from Forever's client item table: removed, or only sent by the server?
  { 16082, "Artisan Fishing - The Way of the Lure (book)" },
  { 19808, "Rockhide Strongfish" },
  { 6366, "Darkwood Fishing Pole" },
  { 8350, "The 1 Ring" },
  { 6987, "Fish Scale" },
  { 19944, "Nat Pagle's Fish Terminator" },
  { 19947, "Nat Pagle's Broken Reel" },
  -- Nat Pagle's quest fish and rewards
  { 16967, "Feralas Ahi" },
  { 16968, "Misty Reed Mahi Mahi" },
  { 16969, "Savage Coast Blue Sailfin" },
  { 16970, "Sar'theris Striker" },
  { 19022, "Nat Pagle's Extreme Angler FC-5000" },
  { 19969, "Nat Pagle's Extreme Anglin' Boots" },
  { 16083, "Expert Fishing - The Bass and You (book)" },
  -- Stranglethorn Extravaganza (Riggle Bassbait)
  { 19803, "Brownell's Blue Striped Racer" },
  { 19805, "Keefer's Angelfish" },
  { 19806, "Dezian Queenfish" },
  { 19807, "Speckled Tastyfish" },
  { 19970, "Arcanite Fishing Pole" },
  { 19979, "Hook of the Master Angler" },
  { 19972, "Lucky Fishing Hat" },
  -- New or changed in Forever's client data
  { 251524, "Whimsyfin" },
  { 279967, "Fish Bowl (camp, tier 1)" },
  { 279965, "Fishing Rack (camp, tier 2)" },
  { 279966, "Fishing Hut (camp, tier 3)" },
  { 273141, "Blueprint: Fishing Rack" },
  { 273119, "Blueprint: Fishing Hut" },
  { 273636, "Chef's Knife" },
  { 273295, "Seasonal Fish Steaks" },
  { 274026, "Extravagant Extravaganza Coin" },
  { 276272, "Master Angler's Fishing Hat" },
  { 276275, "Bitter Baitling" },
  { 276203, "Primitive Fishing Pole" },
  { 259846, "Wide-Brimmed Fishing Hat" },
  { 274800, "Fishing Trip" },
  { 13890, "Raw Plated Armorfish" },
  { 13876, "40 Pound Yellowtail (was Grouper)" },
  -- Controls that should certainly exist
  { 6256, "Fishing Pole (control)" },
  { 6291, "Raw Brilliant Smallfish (control)" },
  { 6529, "Shiny Bauble (control)" },
  { 13759, "Raw Nightfin Snapper (control)" },
}

ns.QUESTS = {
  { 6607, "Nat Pagle, Angler Extreme" },
  { 8193, "Master Angler (Riggle Bassbait)" },
  { 96561, "quest started by Fishing Trip 274800" },
}

ns.SPELLS = {
  { 7620, "Fishing (Classic Apprentice)" },
  { 7731, "Fishing (Classic Journeyman)" },
  { 7732, "Fishing (Classic Expert)" },
  { 18248, "Fishing (Classic Artisan)" },
  { 1240948, "Forever fishing rank 1" },
  { 1240959, "Forever fishing rank 2" },
  { 1240970, "Forever fishing rank 3" },
  { 1240983, "Forever fishing rank 4" },
  { 131474, "Fishing (Retail)" },
  { 1225455, "Luremaster (Legacy perk)" },
  { 1280341, "Uncommon Fishing (Fishing Rack aura)" },
  { 1280342, "Rare Fishing (Fishing Hut aura)" },
  { 1265220, "Fishing Hat Lure" },
  { 1299323, "Master Angler! (Extravaganza)" },
  { 1299291, "Snacking on Tastyfish" },
  { 1278067, "Bait and Tackle (camp crafting)" },
  { 1307247, "Fishing Rack" },
  { 1307246, "Fishing Hut" },
  { 1292332, "Prepare Fish" },
}

-- Spell IDs we treat as "the fishing cast".
ns.FISHING_SPELLS = {
  [7620] = true, [7731] = true, [7732] = true, [18248] = true, [131474] = true,
  [1240948] = true, [1240959] = true, [1240970] = true, [1240983] = true,
}

-- Buffs that matter for a Catch.
ns.FISHING_AURAS = {
  [1280341] = "Rack", [1280342] = "Hut", [1265220] = "HatLure",
  [1299323] = "MasterAngler", [1299291] = "Tastyfish", [1225455] = "Luremaster",
}

local CVARS = {
  "autoLootDefault", "SoftTargetInteract", "SoftTargetInteractRange", "SoftTargetInteractArc",
  "SoftTargetIconGameObject", "SoftTargetTooltipInteract", "interactOnLeftClick", "autoInteract",
}

----------------------------------------------------------------------
-- Small readers (also used for every Catch)
----------------------------------------------------------------------
function ns.cvar(name)
  local v = ns.call("C_CVar.GetCVar", name)
  if v == nil then v = ns.call("GetCVar", name) end
  return v
end

function ns.spellName(id)
  return ns.call("C_Spell.GetSpellName", id) or ns.call("GetSpellInfo", id)
end

function ns.fishingName()
  if not ns._fishName then ns._fishName = ns.spellName(7620) or "Fishing" end
  return ns._fishName
end

function ns.isFishingSpell(id, name)
  if type(id) == "number" and ns.FISHING_SPELLS[id] then return true end
  return type(name) == "string" and name == ns.fishingName()
end

-- Fishing skill: try the Retail profession APIs, then the Classic skill list.
function ns.fishingSkill()
  local _, _, _, fishIdx = ns.call("GetProfessions")
  if fishIdx then
    local _, _, rank, max, _, _, line, mod = ns.call("GetProfessionInfo", fishIdx)
    if rank then return { src = "GetProfessionInfo", rank = rank, max = max, mod = mod, line = line } end
  end
  local info = ns.call("C_TradeSkillUI.GetProfessionInfoBySkillLineID", 356)
  if type(info) == "table" and type(info.skillLevel) == "number" and info.skillLevel > 0 then
    return { src = "C_TradeSkillUI", rank = info.skillLevel, max = info.maxSkillLevel, mod = info.skillModifier }
  end
  local n = ns.call("GetNumSkillLines")
  if type(n) == "number" then
    local fname = ns.fishingName()
    for i = 1, math.min(n, 80) do
      local name, _, _, rank, _, mod, max = ns.call("GetSkillLineInfo", i)
      if name == fname then return { src = "GetSkillLineInfo", rank = rank, max = max, mod = mod } end
    end
  end
  return { src = "none" }
end

-- Lure on the main-hand weapon (Classic-style lures are temporary enchants).
function ns.lureState()
  local has, expMs, _, enchID = ns.call("GetWeaponEnchantInfo")
  return {
    has = has and true or false,
    left = type(expMs) == "number" and math.floor(expMs / 1000) or nil,
    id = enchID,
    pole = ns.call("GetInventoryItemID", "player", 16),
  }
end

-- Player buffs. Returns a list (IDs, or detail tables if withDetail) and a
-- status string. Remembers spell names for the report.
function ns.auraList(withDetail)
  if ns.call("C_Secrets.ShouldAurasBeSecret") then return nil, "secret" end
  local get = ns.resolve("C_UnitAuras.GetAuraDataByIndex")
  if type(get) ~= "function" then return nil, "missing" end
  local out = {}
  for i = 1, 40 do
    local ok, a = pcall(get, "player", i, "HELPFUL")
    if not ok then return out, "error" end
    a = ns.clean(a, 1)
    if type(a) ~= "table" then break end
    if a.spellId then
      if ns.db and a.name and not ns.db.spellNames[a.spellId] then ns.db.spellNames[a.spellId] = a.name end
      out[#out + 1] = withDetail and { id = a.spellId, name = a.name, dur = a.duration } or a.spellId
    end
  end
  return out, "ok"
end

function ns.weatherNow()
  local rec = ns.try("C_Weather.GetCurrentWeather")
  if rec.missing then return "missing" end
  if not rec.ok then return "error: " .. tostring(rec.err) end
  return rec.r
end

function ns.gameTime()
  local h, m = ns.call("GetGameTime")
  if type(h) == "number" and type(m) == "number" then return string.format("%02d:%02d", h, m) end
end

-- Text -> area ID reverse index. Loot data is keyed by AreaTable ID, but the
-- client only gives us localized zone/subzone text. We scan
-- C_Map.GetAreaInfo(1..40000) once per session (Forever's new areas start at
-- 16144) and index the names exactly and "loosely" (lowercase, trimmed) to
-- spot case or whitespace differences. Built lazily, never in combat.
local AREA_MAX = 40000
local function loose(s) return (s:lower():gsub("^%s+", ""):gsub("%s+$", "")) end

local function buildIndex(get, careful)
  local exact, looseIdx, stats = {}, {}, { named = 0, maxID = 0, collisions = 0 }
  for id = 1, AREA_MAX do
    local n
    if careful then
      local ok, v = pcall(get, id)
      n = ok and v or nil
    else
      n = get(id)
    end
    if not issecret(n) and type(n) == "string" and n ~= "" then
      stats.named, stats.maxID = stats.named + 1, id
      local list = exact[n]
      if list then stats.collisions = stats.collisions + 1 else list = {} exact[n] = list end
      list[#list + 1] = id
      local l = loose(n)
      looseIdx[l] = looseIdx[l] or {}
      table.insert(looseIdx[l], id)
    end
  end
  return exact, looseIdx, stats
end

function ns.buildAreaIndex()
  if ns.areaIndex then return true end
  if InCombatLockdown() then return false end
  local get = ns.resolve("C_Map.GetAreaInfo")
  if type(get) ~= "function" then ns.areaStats = { missing = true } return false end
  local t0 = debugprofilestop and debugprofilestop()
  local ok, exact, looseIdx, stats = pcall(buildIndex, get, false)
  if not ok then exact, looseIdx, stats = buildIndex(get, true) end
  stats.ms = t0 and ns.round(debugprofilestop() - t0, 0)
  stats.locale = ns.call("GetLocale")
  ns.areaIndex, ns.areaLoose, ns.areaStats = exact, looseIdx, stats
  if ns.db then ns.db.areaStats = stats end
  return true
end

-- Area IDs for a zone or subzone text: { exact = {ids} } or, when nothing
-- matches exactly, { exact = {}, loose = {ids} }. Remembered per session in
-- db.areaIDs so the report can show every name seen at a Catch.
function ns.areaIDsFor(name)
  if type(name) ~= "string" or name == "" or not ns.db then return nil end
  local cache = ns.db.areaIDs
  if cache[name] then return cache[name] end
  if not ns.buildAreaIndex() then return nil end
  local r = { exact = ns.areaIndex[name] or {} }
  if #r.exact == 0 then r.loose = ns.areaLoose[loose(name)] end
  cache[name] = r
  return r
end

-- Where the player is, by every API we know.
function ns.where()
  local c = {}
  c.zone = ns.call("GetZoneText")
  c.real = ns.call("GetRealZoneText")
  c.sub = ns.call("GetSubZoneText")
  c.mini = ns.call("GetMinimapZoneText")
  c.map = ns.call("C_Map.GetBestMapForUnit", "player")
  if c.map then
    local getPos = ns.resolve("C_Map.GetPlayerMapPosition")
    if type(getPos) == "function" then
      local ok, pos = pcall(getPos, c.map, "player")
      if ok and not issecret(pos) and type(pos) == "table" then
        local ok2, x, y = pcall(pos.GetXY, pos)
        if ok2 and type(x) == "number" and type(y) == "number" then
          c.x, c.y = ns.round(x, 4), ns.round(y, 4)
        end
        local explored = ns.resolve("C_MapExplorationInfo.GetExploredAreaIDsAtPosition")
        if type(explored) == "function" then
          local ok3, ids = pcall(explored, c.map, pos)
          if ok3 then c.explored = ns.clean(ids, 1) end
        end
      end
    end
  end
  c.areaSub = ns.areaIDsFor(c.sub)
  c.areaZone = ns.areaIDsFor(c.zone)
  local _, instType, _, _, _, _, _, instID = ns.call("GetInstanceInfo")
  c.inst, c.instType = instID, instType -- instID = map ID (continent or instance)
  c.indoors = ns.call("IsIndoors")
  c.locale = ns.call("GetLocale")
  return c
end

-- Titles of today's calendar events (cached; used for each Catch).
function ns.refreshHolidays()
  local ct = ns.call("C_DateAndTime.GetCurrentCalendarTime")
  local day = type(ct) == "table" and ct.monthDay
  if type(day) ~= "number" then return end
  local n = ns.call("C_Calendar.GetNumDayEvents", 0, day)
  local today = {}
  if type(n) == "number" then
    for i = 1, math.min(n, 30) do
      local e = ns.call("C_Calendar.GetDayEvent", 0, day, i)
      if type(e) == "table" and e.title then today[#today + 1] = e.title end
    end
  end
  ns.todayEvents = today
end

----------------------------------------------------------------------
-- The one-shot dump
----------------------------------------------------------------------
local function label(spec)
  local args = {}
  for i = 2, #spec do
    local a = spec[i]
    args[#args + 1] = type(a) == "string" and ('"' .. a .. '"') or tostring(a)
  end
  return spec[1] .. "(" .. table.concat(args, ", ") .. ")"
end

-- Run a list of specs. A spec is { "Api.Name", args... }, or { const = "NAME" }
-- to read a global value, or { keys = "C_Table" } to list a table's functions.
local function runList(list)
  local out = {}
  for _, spec in ipairs(list) do
    if spec.const then
      out[#out + 1] = { l = spec.const, v = { ok = true, n = 1, r = { ns.clean(_G[spec.const], 2) } } }
    elseif spec.keys then
      local t = ns.resolve(spec.keys)
      local v = { missing = true }
      if type(t) == "table" then
        local names = {}
        for k in pairs(t) do if type(k) == "string" then names[#names + 1] = k end end
        table.sort(names)
        v = { ok = true, n = 1, r = { table.concat(names, ", ") } }
      end
      out[#out + 1] = { l = spec.keys .. " (contents)", v = v, long = true }
    else
      out[#out + 1] = { l = label(spec), v = ns.try(unpack(spec)) }
    end
  end
  return out
end

local IDENTITY = {
  { const = "WOW_PROJECT_ID" }, { const = "WOW_PROJECT_CAMELOT" }, { const = "WOW_PROJECT_MAINLINE" },
  { const = "WOW_PROJECT_CLASSIC" }, { const = "LE_EXPANSION_LEVEL_CURRENT" }, { const = "LE_EXPANSION_CLASSIC" },
  { "GetBuildInfo" }, { "GetLocale" }, { "GetCurrentRegion" }, { "GetCurrentRegionName" },
  { "GetExpansionLevel" }, { "GetServerExpansionLevel" }, { "GetClassicExpansionLevel" },
  { "GetMaxLevelForPlayerExpansion" }, { "IsTestBuild" }, { "IsBetaBuild" }, { "IsPublicBuild" },
  { "RegionalUniqueNamesEnabled" }, { "C_GameRules.GetForeverExperiencePreset" },
  { "C_GameRules.IsHardcoreActive" }, { "C_GameRules.GetActiveGameMode" },
  { "GetRealmName" }, { "GetNormalizedRealmName" }, { "GetRealmID" },
  { keys = "C_GameRules" }, { keys = "C_Weather" },
}

local NAMES = {
  { "UnitName", "player" }, { "UnitNameUnmodified", "player" }, { "GetUnitName", "player", true },
  { "GetUnitName", "player", false }, { "UnitFullName", "player" }, { "UnitGUID", "player" },
  { "UnitRace", "player" }, { "UnitClass", "player" }, { "UnitLevel", "player" },
  { "UnitFactionGroup", "player" }, { "BNGetInfo" }, { "BNConnected" }, { "BNFeaturesEnabled" },
}

local TIME = {
  { "GetGameTime" }, { "GetServerTime" }, { "time" }, { "date", "%Y-%m-%d %H:%M:%S" },
  { "date", "!%Y-%m-%d %H:%M:%S" }, { "C_DateAndTime.GetCurrentCalendarTime" },
  { "C_DateAndTime.GetServerTimeLocal" }, { "C_DateAndTime.GetSecondsUntilDailyReset" },
  { "C_DateAndTime.GetSecondsUntilWeeklyReset" }, { "GetTime" }, { "GetTimePreciseSec" },
  { "GetSessionTime" },
}

local MISC = {
  { const = "issecretvalue" }, { const = "ReloadUI" }, { const = "IsFishingLoot" },
  { const = "TooltipDataProcessor" }, { "InCombatLockdown" },
  { "C_Secrets.ShouldAurasBeSecret" }, { "C_ChatInfo.InChatMessagingLockdown" },
  { "C_AddOns.GetAddOnInfo", "PagleProbe_Module" }, { "C_AddOns.IsAddOnLoaded", "PagleProbe_Module" },
  { "C_AddOns.GetAddOnEnableState", "PagleProbe_Module" },
  { "C_AddOns.GetAddOnMetadata", "PagleProbe", "Group" },
  { "C_AddOns.GetAddOnMetadata", "PagleProbe", "Category" },
  { "C_AddOns.GetAddOnMetadata", "PagleProbe", "X-Probe-Issue" },
  { "C_AddOns.GetAddOnMetadata", "PagleProbe_Module", "Group" },
}

local function locationList(where)
  local list = {
    { "C_Map.GetBestMapForUnit", "player" }, { "GetZoneText" }, { "GetRealZoneText" },
    { "GetSubZoneText" }, { "GetMinimapZoneText" }, { "GetAreaText" }, { "GetZonePVPInfo" }, { "GetInstanceInfo" },
    { "IsIndoors" }, { "IsResting" },
  }
  if type(where.map) == "number" then
    list[#list + 1] = { "C_Map.GetMapInfo", where.map }
    list[#list + 1] = { "C_Map.GetMapGroupID", where.map }
  end
  local sub = type(where.areaSub) == "table" and where.areaSub.exact
  if type(sub) == "table" and sub[1] then
    list[#list + 1] = { "C_Map.GetAreaInfo", sub[1] }
  end
  return list
end

local function skillDump()
  local d = { best = ns.fishingSkill() }
  local a, b, c, fish, cook = ns.call("GetProfessions")
  local list = { { "GetProfessions" }, { "C_TradeSkillUI.GetProfessionInfoBySkillLineID", 356 }, { "GetNumSkillLines" } }
  for _, idx in ipairs({ a or false, b or false, c or false, fish or false, cook or false }) do
    if idx then list[#list + 1] = { "GetProfessionInfo", idx } end
  end
  d.list = runList(list)
  -- The Classic-style skill list, if the client has one (compact rows).
  local n = ns.call("GetNumSkillLines")
  if type(n) == "number" then
    d.lines = {}
    for i = 1, math.min(n, 60) do
      local name, header, _, rank, _, mod, max = ns.call("GetSkillLineInfo", i)
      d.lines[#d.lines + 1] = { name = name, header = header, rank = rank, mod = mod, max = max }
    end
  end
  return d
end

local function spellDump()
  local out = {}
  for _, s in ipairs(ns.SPELLS) do
    out[#out + 1] = {
      id = s[1], label = s[2], name = ns.spellName(s[1]),
      known = ns.call("IsPlayerSpell", s[1]),
      known2 = ns.call("C_SpellBook.IsSpellKnown", s[1]),
    }
  end
  return out
end

local function slotTooltip(slot)
  local data = ns.call("C_TooltipInfo.GetInventoryItem", "player", slot)
  if type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
  local out = {}
  for i = 1, 20 do
    local l = data.lines[i]
    if type(l) == "table" and l.leftText then out[#out + 1] = l.leftText end
  end
  return out
end

-- The whole calendar month: holiday titles with their first and last day.
local function calendarDump()
  local d = {}
  d.monthInfo = ns.try("C_Calendar.GetMonthInfo", 0)
  local ct = ns.call("C_DateAndTime.GetCurrentCalendarTime")
  local day = type(ct) == "table" and ct.monthDay
  if type(day) == "number" then
    d.today = {}
    local n = ns.call("C_Calendar.GetNumDayEvents", 0, day)
    d.todayCount = n
    for i = 1, math.min(type(n) == "number" and n or 0, 15) do
      d.today[#d.today + 1] = ns.clean(ns.call("C_Calendar.GetDayEvent", 0, day, i), 2)
    end
  end
  local mi = d.monthInfo.ok and d.monthInfo.r[1]
  local days = type(mi) == "table" and type(mi.numDays) == "number" and mi.numDays or 0
  d.holidays = {}
  local seen = {}
  for dd = 1, days do
    local n = ns.call("C_Calendar.GetNumDayEvents", 0, dd)
    for i = 1, math.min(type(n) == "number" and n or 0, 20) do
      local e = ns.call("C_Calendar.GetDayEvent", 0, dd, i)
      if type(e) == "table" and type(e.title) == "string" then
        local h = seen[e.title]
        if not h and #d.holidays < 40 then
          h = { title = e.title, type = e.calendarType, eventID = e.eventID, first = dd }
          seen[e.title] = h
          d.holidays[#d.holidays + 1] = h
        end
        if h then h.last = dd end
      end
    end
  end
  return d
end

function ns.runEnv(reason)
  local db = ns.db
  if not db then return end
  if InCombatLockdown() then ns.envPending = reason return end
  ns.envPending = nil
  local env = { at = ns.now(), session = db.session, reason = reason }
  env.identity = runList(IDENTITY)
  env.names = runList(NAMES)
  env.where = ns.where()
  env.location = runList(locationList(env.where))
  env.time = runList(TIME)
  env.calendar = calendarDump()
  env.weather = ns.try("C_Weather.GetCurrentWeather")
  env.skill = skillDump()
  env.spells = spellDump()
  env.luremasterText = ns.call("C_Spell.GetSpellDescription", 1225455)
  env.gear = runList({
    { "GetWeaponEnchantInfo" }, { "GetInventoryItemID", "player", 16 },
    { "GetInventoryItemID", "player", 17 }, { "GetInventoryItemID", "player", 28 },
    { const = "INVSLOT_MAINHAND" }, { const = "INVSLOT_RANGED" },
  })
  env.tip16 = slotTooltip(16)
  env.tip28 = slotTooltip(28)
  local auras, auraStatus = ns.auraList(true)
  env.auras, env.auraStatus = auras, auraStatus
  env.cvars = {}
  for _, name in ipairs(CVARS) do env.cvars[#env.cvars + 1] = { name, ns.cvar(name) } end
  env.misc = runList(MISC)
  env.events = ns.copy(ns.regResults)
  env.flags = ns.copy(ns.flags)
  db.env = env
  ns.refreshHolidays()
  ns.checkItems()
  ns.envDone = true
end

----------------------------------------------------------------------
-- Item and quest existence. Ask the client, then ask the server
-- (RequestLoad... is a data query, not a game action) and read again.
----------------------------------------------------------------------
ns.itemIndex, ns.questIndex = {}, {}

function ns.checkItems()
  local db = ns.db
  db.items, db.quests = {}, {}
  for i, it in ipairs(ns.ITEMS) do
    local id = it[1]
    local rec = { id = id, label = it[2] }
    rec.exists = ns.call("C_Item.DoesItemExistByID", id)
    local instID, _, _, _, _, classID, subID = ns.call("C_Item.GetItemInfoInstant", id)
    rec.instant = instID ~= nil
    rec.class, rec.subclass = classID, subID
    db.items[i] = rec
    ns.itemIndex[id] = rec
    ns.call("C_Item.RequestLoadItemDataByID", id)
  end
  for i, q in ipairs(ns.QUESTS) do
    local rec = { id = q[1], label = q[2] }
    rec.done = ns.call("C_QuestLog.IsQuestFlaggedCompleted", q[1])
    db.quests[i] = rec
    ns.questIndex[q[1]] = rec
    ns.call("C_QuestLog.RequestLoadQuestByID", q[1])
  end
  C_Timer.After(15, function() ns.safe(ns.finishItems) end)
end

function ns.finishItems()
  local db = ns.db
  for _, rec in ipairs(db.items or {}) do
    local name, _, quality = ns.call("C_Item.GetItemInfo", rec.id)
    if name == nil then name, _, quality = ns.call("GetItemInfo", rec.id) end
    rec.name, rec.quality = name, quality
  end
  for _, rec in ipairs(db.quests or {}) do
    rec.title = ns.call("C_QuestLog.GetTitleForQuestID", rec.id)
  end
  ns.itemsDone = true
end
