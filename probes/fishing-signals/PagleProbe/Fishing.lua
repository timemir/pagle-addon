-- PagleProbe/Fishing.lua
-- Event wiring and the fishing log: the fishing channel, every loot window
-- (a "Catch" record with its context), mouseover and soft-target hints for
-- pool vs open water, and periodic weather samples. All read-only.

local ADDON, ns = ...
local issecret = ns.issecret

local frame = CreateFrame("Frame")
local handlers = {}
ns.regResults = {}

-- Unknown events throw on Forever, so every registration goes through pcall
-- and the outcome is kept for the report.
local function on(event, fn, unit)
  handlers[event] = fn
  local ok, e
  if unit then
    ok, e = pcall(frame.RegisterUnitEvent, frame, event, unit)
  else
    ok, e = pcall(frame.RegisterEvent, frame, event)
  end
  ns.regResults[event] = ok and "ok" or ("FAILED: " .. tostring(e))
end

-- Every handler runs inside pcall: a probe bug never shows an error popup
-- and never stops other handlers.
frame:SetScript("OnEvent", function(_, event, ...)
  local fn = handlers[event]
  if fn then
    local ok, e = pcall(fn, ...)
    if not ok then ns.err(event, e) end
  end
end)

local function clean(v) return ns.clean(v, 2) end

----------------------------------------------------------------------
-- Hover and soft-target hints (pool vs open water)
----------------------------------------------------------------------
-- World-object tooltips (a pool, the bobber) are owned by UIParent. We poll
-- the tooltip text 5 times a second, out of combat only. Nothing is hooked.
ns.tips = {}      -- recent distinct tooltip texts: { text, t }
local lastTip
local function pollTooltip()
  local tip = GameTooltip
  if not tip or not tip:IsShown() then lastTip = nil return end
  if tip:GetOwner() ~= UIParent then return end
  local isUnit = UnitExists("mouseover")
  if issecret(isUnit) or isUnit then return end
  local fs = _G.GameTooltipTextLeft1
  local text = fs and fs:GetText()
  if issecret(text) then ns.tipSecret = (ns.tipSecret or 0) + 1 return end
  if type(text) ~= "string" or text == "" or text == lastTip then return end
  lastTip = text
  table.insert(ns.tips, 1, { text = text, t = GetTime() })
  if #ns.tips > 6 then table.remove(ns.tips) end
  -- Count each distinct text (at most 80 distinct texts are kept).
  local agg = ns.db and ns.db.agg.tooltips
  if agg then
    local count = 0
    for _ in pairs(agg) do count = count + 1 end
    if agg[text] or count < 80 then agg[text] = (agg[text] or 0) + 1 end
  end
end

local elapsedSum = 0
frame:SetScript("OnUpdate", function(_, elapsed)
  elapsedSum = elapsedSum + elapsed
  if elapsedSum < 0.2 then return end
  elapsedSum = 0
  if InCombatLockdown() or not ns.db then return end
  local ok, e = pcall(pollTooltip)
  if not ok then ns.err("tooltip", e) end
end)

-- Recent tooltip texts as "text (Ns ago)", within `window` seconds.
local function recentTips(window)
  local out, now = {}, GetTime()
  for _, tp in ipairs(ns.tips) do
    if now - tp.t <= window then out[#out + 1] = tp.text .. " (" .. math.floor(now - tp.t) .. "s ago)" end
  end
  return out
end

-- Tooltip data hook (the official addon API; it only reads). For a world
-- object under the mouse, data.type is Object (4) and data.id should be the
-- GameObject entry ID, a locale-free way to tell which pool it is.
ns.objTips = {} -- recent objects: { id, name, t }
local function onObjectTooltip(_, data)
  if InCombatLockdown() or not ns.db then return end
  if issecret(data) or type(data) ~= "table" then return end
  local agg = ns.db.agg
  agg.objectHookFired = (agg.objectHookFired or 0) + 1
  local id, dtype, guid = clean(data.id), clean(data.type), clean(data.guid)
  local name, nameSecret
  local lines = data.lines
  if not issecret(lines) and type(lines) == "table" then
    local line = lines[1]
    if not issecret(line) and type(line) == "table" then
      name = line.leftText
      if issecret(name) then name, nameSecret = nil, true end
    end
  end
  local key = tostring(id)
  local last = ns.objTips[1]
  if last and last.key == key and GetTime() - last.t < 5 then last.t = GetTime() return end
  table.insert(ns.objTips, 1, { key = key, id = id, name = name, t = GetTime() })
  if #ns.objTips > 6 then table.remove(ns.objTips) end
  local o = agg.objects[key]
  if not o then
    local count = 0
    for _ in pairs(agg.objects) do count = count + 1 end
    if count >= 80 then return end
    o = { n = 0, id = id, type = dtype, name = name, nameSecret = nameSecret, guid = guid }
    agg.objects[key] = o
  end
  o.n = o.n + 1
  ns.log("objectTooltip", { id = id, type = dtype, name = name, nameSecret = nameSecret, guid = guid })
end

local function hookObjectTooltips()
  local tdp = TooltipDataProcessor
  if type(tdp) ~= "table" or type(tdp.AddTooltipPostCall) ~= "function" then
    ns.flags.objectHook = "TooltipDataProcessor.AddTooltipPostCall missing"
    return
  end
  local objType = (Enum and Enum.TooltipDataType and Enum.TooltipDataType.Object) or 4
  local ok, e = pcall(tdp.AddTooltipPostCall, objType, function(tt, data)
    local ok2, e2 = pcall(onObjectTooltip, tt, data)
    if not ok2 then ns.err("objectTooltip", e2) end
  end)
  ns.flags.objectHook = ok and ("ok (TooltipDataType.Object = " .. tostring(objType) .. ")") or ("FAILED: " .. tostring(e))
end

-- Recent object tooltips as { id, name, ago }, within `window` seconds.
local function recentObjects(window)
  local out, now = {}, GetTime()
  for _, o in ipairs(ns.objTips) do
    if now - o.t <= window then out[#out + 1] = { id = o.id, name = o.name, ago = math.floor(now - o.t) } end
  end
  return out
end

-- Soft-target interact (only fires if the SoftTargetInteract option is on).
on("PLAYER_SOFT_INTERACT_CHANGED", function(_, newGUID)
  newGUID = clean(newGUID)
  if type(newGUID) ~= "string" then return end
  local kind, objID = ns.guidInfo(newGUID)
  local name = ns.call("UnitName", "softinteract")
  ns.soft = { guid = newGUID, kind = kind, obj = objID, name = name, t = GetTime() }
  local key = tostring(objID or kind)
  local agg = ns.db and ns.db.agg.soft
  if agg then
    agg[key] = agg[key] or { n = 0, kind = kind, name = name }
    agg[key].n = agg[key].n + 1
  end
  if kind == "GameObject" then ns.log("softInteract", { guid = newGUID, obj = objID, name = name }) end
end)

----------------------------------------------------------------------
-- The fishing channel
----------------------------------------------------------------------
local chan -- the current or last channel

on("UNIT_SPELLCAST_SENT", function(_, target, _, spellID)
  target, spellID = clean(target), clean(spellID)
  local name = type(spellID) == "number" and ns.spellName(spellID)
  if ns.isFishingSpell(spellID, name) then
    ns.lastSent = { target = target, t = GetTime() }
    ns.log("castSent", { spell = spellID, target = target })
  end
end, "player")

on("UNIT_SPELLCAST_CHANNEL_START", function(_, _, spellID)
  spellID = clean(spellID)
  local name, _, _, startMs, endMs, _, _, chSpell = ns.call("UnitChannelInfo", "player")
  spellID = spellID or chSpell
  local dur
  if type(startMs) == "number" and type(endMs) == "number" then dur = ns.round((endMs - startMs) / 1000, 1) end
  chan = { spell = spellID, name = name, dur = dur, start = GetTime(), at = ns.now() }
  if type(spellID) == "number" and name and ns.db and not ns.db.spellNames[spellID] then
    ns.db.spellNames[spellID] = name
  end
  local tips = recentTips(30)
  ns.log("chanStart", {
    spell = spellID, name = name, dur = dur, tip = tips[1],
    obj = (recentObjects(30)[1] or {}).id,
    soft = ns.soft and (GetTime() - ns.soft.t < 30) and ns.soft.obj or nil,
    lure = ns.lureState().has, fishing = ns.isFishingSpell(spellID, name),
  })
end, "player")

on("UNIT_SPELLCAST_CHANNEL_STOP", function(_, _, spellID)
  if chan then chan.len = ns.round(GetTime() - chan.start, 1) end
  ns.log("chanStop", { spell = clean(spellID), len = chan and chan.len })
end, "player")

on("UNIT_SPELLCAST_SUCCEEDED", function(_, _, spellID)
  if InCombatLockdown() then return end
  spellID = clean(spellID)
  ns.log("castOK", { spell = spellID, name = type(spellID) == "number" and ns.spellName(spellID) or nil })
end, "player")

local function castFail(kind)
  return function(_, _, spellID)
    spellID = clean(spellID)
    if ns.isFishingSpell(spellID, type(spellID) == "number" and ns.spellName(spellID) or nil) then
      ns.log(kind, { spell = spellID })
    end
  end
end
on("UNIT_SPELLCAST_FAILED", castFail("castFailed"), "player")
on("UNIT_SPELLCAST_INTERRUPTED", castFail("castInterrupted"), "player")

-- Lure applied or expired shows up as an inventory change.
local lastLure
on("UNIT_INVENTORY_CHANGED", function()
  local l = ns.lureState()
  local key = tostring(l.has) .. ":" .. tostring(l.id)
  if key ~= lastLure then
    lastLure = key
    ns.log("lure", l)
  end
end, "player")

----------------------------------------------------------------------
-- Catch context: everything the ticket wants next to each Catch
----------------------------------------------------------------------
function ns.context()
  local c = ns.where()
  c.gt = ns.gameTime()
  c.weather = ns.weatherNow()
  c.skill = ns.fishingSkill()
  c.lure = ns.lureState()
  local auras, status = ns.auraList(false)
  c.auras, c.auraStatus = auras, status
  c.tips = recentTips(120)
  c.objects = recentObjects(120)
  if ns.soft and GetTime() - ns.soft.t < 120 then
    c.soft = { obj = ns.soft.obj, kind = ns.soft.kind, name = ns.soft.name, ago = math.floor(GetTime() - ns.soft.t) }
  end
  if chan and GetTime() - chan.start < 60 then
    c.chan = { spell = chan.spell, name = chan.name, dur = chan.dur, len = chan.len }
  end
  if ns.lastSent and GetTime() - ns.lastSent.t < 60 then c.sentTarget = ns.lastSent.target end
  c.events = ns.todayEvents
  c.autoLootCVar = ns.cvar("autoLootDefault")
  return c
end

----------------------------------------------------------------------
-- Loot windows -> Catch records
----------------------------------------------------------------------
local open -- the loot window being recorded

local function lootItems()
  local items = {}
  local n = ns.call("GetNumLootItems") or 0
  if type(n) ~= "number" then n = 0 end
  for i = 1, n do
    local _, name, qty, currencyID, quality, _, isQuest, _, _, isCoin = ns.call("GetLootSlotInfo", i)
    local link = ns.call("GetLootSlotLink", i)
    local id = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
    -- Loot source: a pool's GUID would identify the pool by entry ID.
    local src = ns.try("GetLootSourceInfo", i)
    local srcGUID, srcQty = src.ok and src.r[1], src.ok and src.r[2]
    local srcKind, srcObj = ns.guidInfo(srcGUID)
    local item = {
      id = id, name = name, qty = qty, q = quality, coin = isCoin, quest = isQuest,
      cur = currencyID, slotType = ns.call("GetLootSlotType", i),
      src = srcGUID or nil, srcKind = srcKind, srcObj = srcObj, srcQty = srcQty or nil,
      srcN = src.n, srcSecret = src.secret and true or nil, srcMissing = src.missing,
      srcErr = src.err, src2 = src.ok and src.r[3] or nil,
    }
    if id then
      local _, _, _, _, _, classID, subID = ns.call("C_Item.GetItemInfoInstant", id)
      item.class, item.subclass = classID, subID
    end
    items[#items + 1] = item
  end
  return items, n
end

local function finishLoot()
  if not open then return end
  open.t0 = nil
  if ns.db and ns.db.settings.verbose then
    local parts = {}
    for _, it in ipairs(open.items or {}) do
      parts[#parts + 1] = tostring(it.name or it.id) .. (it.coin and "" or (" x" .. tostring(it.qty)))
    end
    ns.print(string.format("Catch #%d recorded - IsFishingLoot: %s - %s", open.id,
      tostring(open.fishing), #parts > 0 and table.concat(parts, ", ") or "no items read"))
  end
  open = nil
end

local function onLoot(event, autoLoot, isFromItem)
  local db = ns.db
  if not db then return end
  if open and GetTime() - (open.t0 or 0) > 20 then finishLoot() end
  local isFishing = ns.call("IsFishingLoot")
  local items, n = lootItems()
  if not open then
    open = { id = db.nextCatch, t = ns.now(), t0 = GetTime(), session = db.session, ev = {} }
    db.nextCatch = db.nextCatch + 1
    open.ctx = ns.context()
    db.catches[#db.catches + 1] = open
    if #db.catches > ns.MAX_CATCHES then table.remove(db.catches, 1) end
  end
  open.ev[#open.ev + 1] = event
  if event == "LOOT_READY" then
    open.fishReady, open.autoReady = isFishing, clean(autoLoot)
  else
    open.fishOpened, open.autoOpened, open.fromItem = isFishing, clean(autoLoot), clean(isFromItem)
  end
  open.fishing = (open.fishReady or open.fishOpened) and true or false
  open.fishingBy = open.fishing and "IsFishingLoot" or nil
  -- Fallback if IsFishingLoot doesn't exist: a loot window right after a
  -- fishing channel counts as fishing (labelled so the report can tell).
  if not open.fishing and type(IsFishingLoot) ~= "function" then
    local ch = open.ctx and open.ctx.chan
    if ch and ns.isFishingSpell(ch.spell, ch.name) then
      open.fishing, open.fishingBy = true, "recent fishing channel (IsFishingLoot missing)"
    end
  end
  if n > (open.n or -1) then open.items, open.n = items, n end
end

on("LOOT_READY", function(autoLoot) onLoot("LOOT_READY", autoLoot) end)
on("LOOT_OPENED", function(autoLoot, isFromItem) onLoot("LOOT_OPENED", autoLoot, isFromItem) end)
on("LOOT_CLOSED", function() finishLoot() end)

-- The loot chat line ("You receive loot: ...") as a second witness.
on("CHAT_MSG_LOOT", function(text)
  local last = ns.db and ns.db.catches[#ns.db.catches]
  if last and ns.now() - (last.t or 0) <= 5 then
    ns.log("chatLoot", { text = text, catch = last.id })
  end
end)

on("CHAT_MSG_SKILL", function(text)
  ns.log("skillMsg", { text = text, skill = ns.fishingSkill() })
end)
on("SKILL_LINES_CHANGED", function() end) -- registered only to test the event exists

----------------------------------------------------------------------
-- Location and weather
----------------------------------------------------------------------
local lastPlace
local function onZone(event)
  local zone, sub = ns.call("GetZoneText"), ns.call("GetSubZoneText")
  local key = tostring(zone) .. "/" .. tostring(sub)
  if key == lastPlace then return end
  lastPlace = key
  ns.log("zone", { ev = event, zone = zone, sub = sub, map = ns.call("C_Map.GetBestMapForUnit", "player") })
  if event == "ZONE_CHANGED_NEW_AREA" then ns.sampleWeather("zone") end
end
on("ZONE_CHANGED", function() onZone("ZONE_CHANGED") end)
on("ZONE_CHANGED_INDOORS", function() onZone("ZONE_CHANGED_INDOORS") end)
on("ZONE_CHANGED_NEW_AREA", function() onZone("ZONE_CHANGED_NEW_AREA") end)

-- Keep a weather sample when the value or the zone changes, plus one every
-- 10 minutes as a heartbeat.
function ns.sampleWeather(reason)
  local db = ns.db
  if not db then return end
  local w = ns.weatherNow()
  local key = ns.fmt(w)
  local zone, sub = ns.call("GetZoneText"), ns.call("GetSubZoneText")
  local now = ns.now()
  local last = ns.lastWeather
  if reason == "tick" and last and last.key == key and last.zone == zone and now - last.t < 600 then return end
  ns.lastWeather = { key = key, zone = zone, t = now }
  local list = db.weather
  list[#list + 1] = {
    t = now, gt = ns.gameTime(), zone = zone, sub = sub,
    map = ns.call("C_Map.GetBestMapForUnit", "player"), w = w, why = reason,
  }
  if #list > 400 then table.remove(list, 1) end
  return list[#list]
end

----------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------
on("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  ns.initDB()
  local ok, e = pcall(ns.registerSettings)
  if not ok then ns.err("settings", e) end
end)

on("SAVED_VARIABLES_TOO_LARGE", function(name)
  ns.pending[#ns.pending + 1] = { at = ns.now(), where = "SAVED_VARIABLES_TOO_LARGE", msg = tostring(clean(name)) }
  ns.log("svTooLarge", { addon = name })
end)

on("PLAYER_LOGIN", function()
  if not ns.db or not ns.load then return end
  -- Is the Module loaded this session? (it checks in from its ADDON_LOADED)
  local loaded = ns.call("C_AddOns.IsAddOnLoaded", "PagleProbe_Module")
  ns.load.module = loaded and "loaded" or "not loaded"
  if ns.moduleThisSession then ns.load.module = "loaded, data " .. ns.moduleThisSession.verdict end
  if not loaded then
    local _, _, _, loadable, reason = ns.call("C_AddOns.GetAddOnInfo", "PagleProbe_Module")
    ns.load.moduleReason = tostring(loadable) .. " / " .. tostring(reason)
  end
  hookObjectTooltips()
  -- Ask the server for calendar data (a data request, not a game action).
  ns.call("C_Calendar.OpenCalendar")
  C_Timer.NewTicker(60, function() ns.safe(ns.sampleWeather, "tick") end)

  local l = ns.load
  ns.print(string.format("loaded (session %d). Saved data: %s. Module: %s. Type /pprobe for help.",
    l.session, l.fresh and "|cffff4040NOTHING READ BACK (fresh)|r" or ("read back, round-trip " .. l.roundtrip),
    l.module))
end)

on("PLAYER_ENTERING_WORLD", function(isInitial, isReload)
  if ns.load and ns.load.initial == nil then
    ns.load.initial, ns.load.reloadUi = clean(isInitial), clean(isReload)
  end
  ns.log("enterWorld", { initial = isInitial, reload = isReload, zone = ns.call("GetZoneText") })
  C_Timer.After(3, function()
    ns.safe(ns.sampleWeather, "enterWorld")
    if not ns.envDone then ns.safe(ns.runEnv, "login") end
  end)
end)

-- Never do the heavy dump in combat; catch up afterwards.
on("PLAYER_REGEN_ENABLED", function()
  if ns.envPending then ns.safe(ns.runEnv, ns.envPending) end
end)

on("CALENDAR_UPDATE_EVENT_LIST", function()
  if not InCombatLockdown() then ns.refreshHolidays() end
end)

on("GET_ITEM_INFO_RECEIVED", function(itemID, success)
  local rec = ns.itemIndex[clean(itemID) or -1]
  if rec then rec.reply = clean(success) end
end)

on("ITEM_DATA_LOAD_RESULT", function(itemID, success)
  local rec = ns.itemIndex[clean(itemID) or -1]
  if rec then rec.loadResult = clean(success) end
end)

on("QUEST_DATA_LOAD_RESULT", function(questID, success)
  local rec = ns.questIndex[clean(questID) or -1]
  if rec then rec.reply = clean(success) end
end)

on("ADDON_RESTRICTION_STATE_CHANGED", function(...)
  ns.log("restriction", { args = { ... } })
end)

on("PLAYER_LOGOUT", function()
  finishLoot()
  ns.onLogout()
end)
