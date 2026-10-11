-- PagleProbe/Report.lua
-- Builds the Markdown report, shows it in a copyable window, and handles
-- the /pprobe slash command. Nothing here touches the game world.

local ADDON, ns = ...
local fmt, fmtTry = ns.fmt, ns.fmtTry

local L -- report lines being built
-- Add a line. GitHub needs a blank line between a table and other text.
local function add(s)
  local prev = L[#L]
  if prev and prev:sub(1, 1) == "|" and s:sub(1, 1) ~= "|" and s ~= "" then L[#L + 1] = "" end
  L[#L + 1] = s
end
local function row(...) add("| " .. table.concat({ ... }, " | ") .. " |") end
local function header(...)
  if L[#L] and L[#L] ~= "" then L[#L + 1] = "" end
  row(...)
  local seps = {}
  for i = 1, select("#", ...) do seps[i] = "---" end
  add("|" .. table.concat(seps, "|") .. "|")
end

-- A value as cell text, without quotes around strings.
local function plain(v, maxLen)
  if v == nil then return "" end
  local s = fmt(v, 2, maxLen or 80)
  if type(v) == "string" then s = s:sub(2, -2) end
  return s
end

local function yesno(v) return v and "yes" or "no" end

local function when(t)
  return type(t) == "number" and date("%m-%d %H:%M", t) or "?"
end

-- "Name#1234" -> "N***#9999 (masked)". Your battleTag stays out of GitHub.
local function maskTag(tag)
  if type(tag) ~= "string" then return fmt(tag) end
  local n, d = tag:match("^(.-)#(%d+)$")
  if n then
    local first = n:match("^[%z\1-\127\194-\244][\128-\191]*") or "?" -- first UTF-8 character
    return '"' .. first .. "***#" .. string.rep("9", #d) .. '" (masked)'
  end
  return "(present, " .. #tag .. " characters, masked)"
end

local function specTable(list)
  if type(list) ~= "table" or #list == 0 then
    add("_Not collected yet: wait 5 seconds after login, or type /pprobe env._")
    return
  end
  header("Call", "Result")
  for _, e in ipairs(list) do
    local v
    if e.l == "BNGetInfo()" and type(e.v) == "table" and e.v.ok then
      local copy = ns.copy(e.v)
      copy.r[2] = nil
      v = fmtTry(copy) .. "; battleTag = " .. maskTag(e.v.r[2])
    else
      v = fmtTry(e.v, e.long and 900 or 160)
    end
    row("`" .. e.l .. "`", v)
  end
end

local function areaText(r)
  if type(r) ~= "table" then return r == nil and "?" or plain(r) end
  if r.exact and #r.exact > 0 then return table.concat(r.exact, ",") end
  if r.loose then return "loose only: " .. table.concat(r.loose, ",") end
  return "NO MATCH"
end

local function itemText(it)
  if it.coin then return "coin" end
  return string.format("%s %s x%s (q%s)", tostring(it.id or "?"), plain(it.name, 30), tostring(it.qty), tostring(it.q))
end

local function sourceText(c)
  local it = c.items and c.items[1]
  if not it then return "no slot" end
  if it.srcMissing then return "API missing" end
  if it.srcErr then return "error" end
  if it.srcSecret then return "secret" end
  if not it.src then return "nil (" .. tostring(it.srcN) .. " values)" end
  return tostring(it.srcKind) .. ":" .. tostring(it.srcObj)
end

local function hoverText(ctx)
  if type(ctx) ~= "table" then return "" end
  local parts = {}
  for _, o in ipairs(ctx.objects or {}) do
    parts[#parts + 1] = "obj " .. tostring(o.id) .. " " .. plain(o.name, 24) .. " (" .. tostring(o.ago) .. "s)"
    if #parts >= 2 then break end
  end
  if #parts == 0 and ctx.tips and ctx.tips[1] then parts[1] = "tip " .. plain(ctx.tips[1], 40) end
  if ctx.soft then parts[#parts + 1] = "soft " .. tostring(ctx.soft.kind) .. ":" .. tostring(ctx.soft.obj) end
  return table.concat(parts, "; ")
end

local function buffText(ctx)
  if type(ctx) ~= "table" then return "" end
  if ctx.auraStatus ~= "ok" then return tostring(ctx.auraStatus) end
  local out = {}
  for _, id in ipairs(ctx.auras or {}) do
    local name = ns.db.spellNames[id]
    local tag = ns.FISHING_AURAS[id]
    if not tag and type(name) == "string" and (name:find("Fish") or name:find("Lure") or name:find("Angl")) then tag = name end
    if tag then out[#out + 1] = tag .. "(" .. id .. ")" end
  end
  return #out > 0 and table.concat(out, ", ") or "none"
end

local function skillText(s)
  if type(s) ~= "table" or not s.rank then return type(s) == "table" and tostring(s.src) or "" end
  return tostring(s.rank) .. "/" .. tostring(s.max) .. (s.mod and s.mod ~= 0 and ("+" .. tostring(s.mod)) or "") .. " " .. tostring(s.src)
end

local function lureText(l)
  if type(l) ~= "table" then return "" end
  if not l.has then return "no" end
  return "yes id " .. tostring(l.id) .. ", " .. tostring(l.left) .. "s"
end

----------------------------------------------------------------------
-- Report sections
----------------------------------------------------------------------
local function secPackaging(db)
  add("### 2. Packaging, Settings and events")
  header("Check", "Result")
  row("Core loaded with `AllowLoadGameType: camelot` + `ExcludeLoadGameType: standard, classic`", "yes (this report exists)")
  row("Inline `[AllowLoadGameType camelot]` file loaded", yesno(ns.flags.camelotFile))
  row("Inline `[AllowLoadGameType standard]` file loaded", yesno(ns.flags.standardFile))
  local l = ns.load or {}
  row("Module this session", tostring(l.module) .. (l.moduleReason and (" (loadable/reason: " .. l.moduleReason .. ")") or ""))
  row("Core Settings root \"PagleProbe\"", table.concat(db.settingsSteps or { "?" }, "; "))
  local m = ns.moduleThisSession
  row("Module Settings subcategory", m and table.concat(m.settings or { "?" }, "; ") or "Module not loaded")
  row("Module test checkbox value read back", m and tostring(m.check) or "-")
  row("Tooltip post-call hook (type Object)", tostring(ns.flags.objectHook) .. "; fired " .. tostring(db.agg.objectHookFired or 0) .. " times")
  local failed = {}
  for ev, res in pairs(ns.regResults) do if res ~= "ok" then failed[#failed + 1] = ev .. " " .. plain(res, 60) end end
  table.sort(failed)
  row("Event registrations that failed", #failed > 0 and table.concat(failed, "; ") or "none")
  row("Seen by eye (fill in)", "Module nested under PagleProbe in the AddOns list? __ / Options > AddOns shows PagleProbe > Module? __")
  add("")
end

local function secPersistence(db)
  add("### 3. SavedVariables persistence")
  local p = db.persist
  add(string.format("- Core data created %s. Logout writes so far: %d (this session's write happens at the next /reload, logout or quit).",
    when(db.createdAt), p.writes or 0))
  header("Session", "Loaded", "Your mark", "Login type", "Saved data read back?", "Writes read back", "Round-trip", "Per-char read back", "SV load ms", "Lua KB", "Bulk records", "Module")
  local first = math.max(1, #db.loads - 19)
  for i = first, #db.loads do
    local d = db.loads[i]
    local kind = d.reloadUi and "reload" or (d.initial and "login" or "?")
    row(tostring(d.session), when(d.at), plain(d.mark), kind, d.fresh and "**NO (fresh)**" or "yes",
      tostring(d.readWrites), tostring(d.roundtrip), d.charFresh and "NO (fresh)" or ("yes, " .. tostring(d.charWrites)),
      tostring(d.svMs), tostring(d.memKB), d.bulk and (d.bulk .. " (~" .. tostring(d.bulkMB) .. " MB)") or "-", plain(d.module, 60))
  end
  add("")
  local h = db.module.history
  if #h > 0 then
    add("Module saved data (written only while the Module is enabled):")
    header("Session", "Loaded", "Read back?", "Writes read back", "Expected", "Verdict", "SV load ms")
    for i = math.max(1, #h - 9), #h do
      local r = h[i]
      row(tostring(r.session), when(r.at), r.fresh and "NO (fresh)" or "yes", tostring(r.writes), tostring(r.expected), plain(r.verdict, 70), tostring(r.svMs))
    end
    add("")
  end
  local b = PagleProbeBulkDB
  add("- Synthetic bulk data now: " .. (type(b) == "table" and (tostring(b.count) .. " records, ~" .. tostring(b.mb) .. " MB") or "none"))
  add("")
end

local function secFishing(db, maxRows)
  add("### 4. Fishing: channel, Catches, pool vs open water")
  local fish, other = {}, {}
  for _, c in ipairs(db.catches) do
    if c.fishing then fish[#fish + 1] = c else other[#other + 1] = c end
  end

  -- Channel spells and counts from the session log.
  local spells, starts, stops = {}, 0, 0
  for _, e in ipairs(db.events) do
    if e.k == "chanStart" then
      starts = starts + 1
      local key = tostring(e.spell)
      spells[key] = spells[key] or { name = e.name, n = 0, dur = e.dur, fishing = e.fishing }
      spells[key].n = spells[key].n + 1
    elseif e.k == "chanStop" then
      stops = stops + 1
    end
  end
  local sp = {}
  for id, s in pairs(spells) do
    sp[#sp + 1] = id .. " " .. plain(s.name, 30) .. " x" .. s.n .. " (channel " .. tostring(s.dur or "?") .. "s" .. (s.fishing and ", fishing" or "") .. ")"
  end
  add("- Channels seen (UNIT_SPELLCAST_CHANNEL_START/STOP): " .. starts .. " starts, " .. stops .. " stops. Spells: " .. (#sp > 0 and table.concat(sp, "; ") or "none"))

  local ready, opened, fr, fo, autoOn, autoOff, fromItem = 0, 0, 0, 0, 0, 0, 0
  for _, c in ipairs(db.catches) do
    for _, ev in ipairs(c.ev or {}) do
      if ev == "LOOT_READY" then ready = ready + 1 else opened = opened + 1 end
    end
    if c.fishReady then fr = fr + 1 end
    if c.fishOpened then fo = fo + 1 end
    local auto = c.autoReady
    if auto == nil then auto = c.autoOpened end
    if c.fishing then
      if auto then autoOn = autoOn + 1 elseif auto == false then autoOff = autoOff + 1 end
    end
    if c.fromItem then fromItem = fromItem + 1 end
  end
  add(string.format("- Loot windows: %d (fishing %d, other %d). LOOT_READY events %d, LOOT_OPENED events %d. IsFishingLoot() true at LOOT_READY %d, at LOOT_OPENED %d.",
    #db.catches, #fish, #other, ready, opened, fr, fo))
  add(string.format("- Fishing windows with auto-loot on %d, off %d. Windows opened from an item (clam, crate, Bloated fish) %d.", autoOn, autoOff, fromItem))

  -- Items caught.
  local items, order = {}, {}
  local lureN, lureMulti, noLureN, noLureMulti = 0, 0, 0, 0
  for _, c in ipairs(fish) do
    local total = 0
    for _, it in ipairs(c.items or {}) do
      if not it.coin then
        local key = tostring(it.id or it.name)
        local rec = items[key]
        if not rec then
          rec = { id = it.id, name = it.name, q = it.q, class = it.class, sub = it.subclass, qty = 0, n = 0, where = {} }
          items[key] = rec
          order[#order + 1] = key
        end
        rec.qty = rec.qty + (tonumber(it.qty) or 0)
        rec.n = rec.n + 1
        local place = c.ctx and plain(c.ctx.sub ~= "" and c.ctx.sub or c.ctx.zone, 30) or "?"
        rec.where[place] = true
        total = total + (tonumber(it.qty) or 0)
      end
    end
    local lure = c.ctx and c.ctx.lure and c.ctx.lure.has
    if lure then
      lureN = lureN + 1
      if total > 1 then lureMulti = lureMulti + 1 end
    else
      noLureN = noLureN + 1
      if total > 1 then noLureMulti = noLureMulti + 1 end
    end
  end
  add(string.format("- Lure / Luremaster: fishing windows with a lure %d (more than 1 item: %d); without a lure %d (more than 1 item: %d).",
    lureN, lureMulti, noLureN, noLureMulti))
  add("")
  if #order > 0 then
    add("Items from fishing loot:")
    header("Item ID", "Name", "Quality", "Class/sub", "Qty", "Windows", "Where")
    for _, key in ipairs(order) do
      local r = items[key]
      local places = {}
      for pl in pairs(r.where) do places[#places + 1] = pl end
      table.sort(places)
      row(tostring(r.id), plain(r.name, 40), tostring(r.q), tostring(r.class) .. "/" .. tostring(r.sub),
        tostring(r.qty), tostring(r.n), table.concat(places, ", "))
    end
    add("")
  end

  -- Loot sources: a pool's GUID would name the pool by entry ID.
  local slotGuid, slotSecret, slotNil, slotErr = 0, 0, 0, 0
  for _, c in ipairs(fish) do
    for _, it in ipairs(c.items or {}) do
      if it.src then slotGuid = slotGuid + 1
      elseif it.srcSecret then slotSecret = slotSecret + 1
      elseif it.srcMissing or it.srcErr then slotErr = slotErr + 1
      else slotNil = slotNil + 1 end
    end
  end
  add(string.format("- `GetLootSourceInfo(slot)` over all fishing loot slots: GUID %d, secret %d, nil %d, missing/error %d.",
    slotGuid, slotSecret, slotNil, slotErr))
  local srcs, srcOrder = {}, {}
  for _, c in ipairs(fish) do
    local key = sourceText(c)
    if not srcs[key] then
      srcs[key] = { n = 0, guid = c.items and c.items[1] and c.items[1].src, hover = {} }
      srcOrder[#srcOrder + 1] = key
    end
    srcs[key].n = srcs[key].n + 1
    local h = hoverText(c.ctx)
    if h ~= "" then srcs[key].hover[h] = true end
  end
  if #srcOrder > 0 then
    add("Loot source per fishing window (`GetLootSourceInfo(1)`, kind:entry ID):")
    header("Source", "Windows", "Example GUID", "Hovered before (examples)")
    for _, key in ipairs(srcOrder) do
      local s = srcs[key]
      local hs = {}
      for h in pairs(s.hover) do hs[#hs + 1] = h if #hs >= 3 then break end end
      row(key, tostring(s.n), plain(s.guid, 60), table.concat(hs, " // "))
    end
    add("")
  end

  -- Hover signals.
  local objs = {}
  for key, o in pairs(db.agg.objects) do objs[#objs + 1] = { key = key, o = o } end
  table.sort(objs, function(a, b) return a.o.n > b.o.n end)
  if #objs > 0 then
    add("Object tooltips (tooltip post-call, `data.type`/`data.id`/`lines[1]`):")
    header("data.id", "Name", "data.type", "Seen", "Name secret?")
    for i = 1, math.min(#objs, 25) do
      local o = objs[i].o
      row(tostring(o.id), plain(o.name, 40), tostring(o.type), tostring(o.n), yesno(o.nameSecret))
    end
    add("")
  else
    add("- Object tooltips: none recorded (hover a pool with the mouse before casting).")
  end
  local tips = {}
  for text, n in pairs(db.agg.tooltips) do tips[#tips + 1] = plain(text, 40) .. " x" .. n end
  table.sort(tips)
  add("- World tooltip texts (GameTooltip line 1): " .. (#tips > 0 and table.concat(tips, "; ") or "none") ..
    (ns.tipSecret and (" (secret " .. ns.tipSecret .. " times)") or ""))
  local soft = {}
  for key, s in pairs(db.agg.soft) do soft[#soft + 1] = tostring(s.kind) .. ":" .. key .. " " .. plain(s.name, 30) .. " x" .. s.n end
  table.sort(soft)
  add("- Soft-target interact (PLAYER_SOFT_INTERACT_CHANGED): " .. (#soft > 0 and table.concat(soft, "; ") or "never fired"))
  add("")

  -- The last fishing Catches with their context.
  if #fish > 0 then
    add("Last " .. math.min(#fish, maxRows) .. " fishing Catches (of " .. #fish .. "). A * means IsFishingLoot was missing and a recent fishing channel was used instead:")
    header("#", "Realm time", "Zone / Subzone / Minimap", "uiMap / mapID", "Area IDs zone; sub", "Items", "Source", "Hovered / soft", "Lure", "Fishing buffs", "Skill", "Weather", "Auto-loot")
    for i = math.max(1, #fish - maxRows + 1), #fish do
      local c = fish[i]
      local x = c.ctx or {}
      local its = {}
      for _, it in ipairs(c.items or {}) do its[#its + 1] = itemText(it) end
      row(tostring(c.id) .. (c.fishingBy ~= "IsFishingLoot" and "*" or ""), tostring(x.gt), plain(x.zone, 25) .. " / " .. plain(x.sub, 25) .. " / " .. plain(x.mini, 25),
        tostring(x.map) .. " / " .. tostring(x.inst), areaText(x.areaZone) .. "; " .. areaText(x.areaSub),
        table.concat(its, "; "), sourceText(c), hoverText(x), lureText(x.lure), buffText(x), skillText(x.skill),
        plain(x.weather, 40), tostring(c.autoReady == nil and c.autoOpened or c.autoReady) .. " (cvar " .. tostring(x.autoLootCVar) .. ")")
    end
    add("")
  end
  if #other > 0 then
    add("Last non-fishing loot windows (expect IsFishingLoot false for mobs and containers):")
    header("#", "IsFishingLoot", "From item", "Items", "Source", "Zone")
    for i = math.max(1, #other - 7), #other do
      local c = other[i]
      local its = {}
      for _, it in ipairs(c.items or {}) do its[#its + 1] = itemText(it) end
      row(tostring(c.id), tostring(c.fishReady) .. "/" .. tostring(c.fishOpened), tostring(c.fromItem),
        table.concat(its, "; "), sourceText(c), plain(c.ctx and c.ctx.zone, 25))
    end
    add("")
  end
end

local function secConditions(db, env, maxRows)
  add("### 5. Conditions: time, calendar, weather")
  specTable(env.time)
  add("")
  local cal = env.calendar
  if type(cal) == "table" then
    add("- `C_Calendar.GetMonthInfo(0)`: " .. fmtTry(cal.monthInfo, 200))
    local today = {}
    for _, e in ipairs(cal.today or {}) do
      today[#today + 1] = plain(e.title, 40) .. " [" .. tostring(e.calendarType) .. ", eventID " .. tostring(e.eventID) .. "]"
    end
    add("- Today's calendar events (" .. tostring(cal.todayCount) .. "): " .. (#today > 0 and table.concat(today, "; ") or "none"))
    local hol = {}
    for _, h in ipairs(cal.holidays or {}) do
      hol[#hol + 1] = plain(h.title, 40) .. " (" .. tostring(h.type) .. ", id " .. tostring(h.eventID) .. ", days " .. tostring(h.first) .. "-" .. tostring(h.last) .. ")"
    end
    add("- Events this month: " .. (#hol > 0 and table.concat(hol, "; ") or "none (open the in-game calendar once, then /pprobe env)"))
  end
  add("- `C_Weather.GetCurrentWeather()` at the environment dump: " .. fmtTry(env.weather))
  local w = db.weather
  local distinct = {}
  for _, s in ipairs(w) do distinct[fmt(s.w, 2, 60)] = true end
  local nd = 0
  for _ in pairs(distinct) do nd = nd + 1 end
  add("- Weather samples kept: " .. #w .. " (distinct values: " .. nd .. "). Last " .. math.min(#w, maxRows) .. ":")
  if #w > 0 then
    header("Time", "Realm time", "Zone / Subzone", "uiMap", "Value", "Why")
    for i = math.max(1, #w - maxRows + 1), #w do
      local s = w[i]
      row(when(s.t), tostring(s.gt), plain(s.zone, 25) .. " / " .. plain(s.sub, 25), tostring(s.map), plain(s.w, 70), tostring(s.why))
    end
  end
  add("")
end

local function secLocation(db, env)
  add("### 6. Location and area IDs")
  specTable(env.location)
  add("")
  add("- `ns.where()` at the dump: " .. fmt(env.where, 3, 60))
  local st = ns.areaStats or db.areaStats
  if type(st) == "table" then
    add(string.format("- Area name index (`C_Map.GetAreaInfo` 1..40000, this session): %s named areas, highest ID %s, duplicate names %s, built in %s ms, locale %s.",
      tostring(st.named), tostring(st.maxID), tostring(st.collisions), tostring(st.ms), tostring(st.locale)))
  else
    add("- Area name index: not built yet (it builds at the first Catch or /pprobe env).")
  end
  local wh = {}
  for _, e in ipairs(db.events) do if e.k == "where" then wh[#wh + 1] = e end end
  if #wh > 0 then
    add("Places logged with /pprobe where:")
    header("Note", "Zone / Subzone / Minimap", "uiMap / mapID", "Instance type", "Area IDs zone; sub", "x, y")
    for i = math.max(1, #wh - 19), #wh do
      local e = wh[i]
      row(plain(e.note, 40), plain(e.zone, 25) .. " / " .. plain(e.sub, 25) .. " / " .. plain(e.mini, 25),
        tostring(e.map) .. " / " .. tostring(e.inst), tostring(e.instType),
        tostring(e.areaZone) .. "; " .. tostring(e.areaSub), tostring(e.x) .. ", " .. tostring(e.y))
    end
  end
  local names = {}
  for text, r in pairs(db.areaIDs) do names[#names + 1] = { text = text, r = r } end
  table.sort(names, function(a, b) return a.text < b.text end)
  if #names > 0 then
    add("Zone and subzone texts seen this session, matched against area names:")
    header("Text", "Area IDs (exact)", "Loose match (case/space)")
    for i = 1, math.min(#names, 40) do
      local r = names[i].r
      row(plain(names[i].text, 40), type(r) == "table" and r.exact and #r.exact > 0 and table.concat(r.exact, ",") or "NONE",
        type(r) == "table" and r.loose and table.concat(r.loose, ",") or "")
    end
  end
  add("")
end

local function secState(db, env)
  add("### 7. Fishing state: skill, spells, lure, buffs")
  local sk = env.skill
  if type(sk) == "table" then
    add("- Best fishing-skill reading: " .. fmt(sk.best))
    specTable(sk.list)
    local rows = {}
    for _, l in ipairs(sk.lines or {}) do
      if not l.header then rows[#rows + 1] = plain(l.name, 30) .. " " .. tostring(l.rank) .. "/" .. tostring(l.max) end
    end
    add("- `GetSkillLineInfo` rows: " .. (#rows > 0 and table.concat(rows, "; ") or "none"))
  end
  add("")
  if type(env.spells) == "table" then
    header("Spell ID", "Expected", "Client name", "IsPlayerSpell", "C_SpellBook.IsSpellKnown")
    for _, s in ipairs(env.spells) do
      row(tostring(s.id), s.label, plain(s.name, 40), tostring(s.known), tostring(s.known2))
    end
  end
  add("- Luremaster text: " .. fmt(env.luremasterText, 1, 200))
  add("")
  specTable(env.gear)
  add("- Main-hand tooltip lines: " .. fmt(env.tip16, 2, 60))
  add("- Slot 28 tooltip lines: " .. fmt(env.tip28, 2, 60))
  local buffs = {}
  for _, a in ipairs(env.auras or {}) do buffs[#buffs + 1] = tostring(a.id) .. " " .. plain(a.name, 30) end
  add("- Buffs at the dump (" .. tostring(env.auraStatus) .. "): " .. (#buffs > 0 and table.concat(buffs, "; ") or "none"))
  local cv = {}
  for _, c in ipairs(env.cvars or {}) do cv[#cv + 1] = c[1] .. "=" .. tostring(c[2]) end
  add("- CVars: " .. table.concat(cv, ", "))
  add("")
  specTable(env.misc)
  add("")
end

local function secItems(db)
  add("### 8. Items and quests: do they exist?")
  if type(db.items) == "table" and #db.items > 0 then
    if not ns.itemsDone then add("_Server replies still pending: reopen the report in 15 seconds._") end
    header("Item ID", "Expected", "DoesItemExistByID", "GetItemInfoInstant", "Server reply / load result", "GetItemInfo name (quality)")
    for _, r in ipairs(db.items) do
      row(tostring(r.id), r.label, tostring(r.exists), tostring(r.instant) .. " class " .. tostring(r.class),
        tostring(r.reply) .. " / " .. tostring(r.loadResult), r.name and (plain(r.name, 40) .. " (" .. tostring(r.quality) .. ")") or "nil")
    end
    add("")
    header("Quest ID", "Expected", "Title", "Load result", "Completed")
    for _, q in ipairs(db.quests or {}) do
      row(tostring(q.id), q.label, plain(q.title, 50), tostring(q.reply), tostring(q.done))
    end
  else
    add("_Not collected yet._")
  end
  add("")
end

function ns.buildReport(compact)
  local db = ns.db
  if not db then return "PagleProbe has no saved data yet. Log in fully, wait 5 seconds and try again." end
  local maxRows = compact and 10 or 25
  L = {}
  local env = db.env or {}
  add("## PagleProbe report (probe v" .. ns.VERSION .. ")")
  add("")
  add(string.format("- Generated %s (server epoch %s, realm time %s), session %d, locale %s. Environment dump from session %s.",
    date("%Y-%m-%d %H:%M"), tostring(ns.now()), tostring(ns.gameTime()), db.session,
    tostring(ns.call("GetLocale")), tostring(env.session)))
  add("- Secret values are never stored: they are saved as nil and marked **(secret -> nil)**.")
  add("")
  add("### 1. Client and character identity")
  specTable(env.identity)
  add("")
  specTable(env.names)
  add("")
  secPackaging(db)
  secPersistence(db)
  secFishing(db, maxRows)
  secConditions(db, env, maxRows)
  secLocation(db, env)
  secState(db, env)
  secItems(db)
  add("### 9. Probe errors")
  if #db.errors == 0 then
    add("none")
  else
    for i = math.max(1, #db.errors - 14), #db.errors do
      local e = db.errors[i]
      add("- session " .. tostring(e.session) .. " " .. when(e.at) .. " `" .. tostring(e.where) .. "`: " .. plain(e.msg, 200))
    end
  end
  add("")
  add("_Full data: the SavedVariables file PagleProbe.lua (see the README for where it is)._")
  local text = table.concat(L, "\n")
  -- GitHub comments are limited to 65,536 characters.
  if #text > 60000 and not compact then return ns.buildReport(true) end
  return text
end

----------------------------------------------------------------------
-- The copy window: a scrollable multi-line EditBox
----------------------------------------------------------------------
local frame

local function makeButton(parent, template, text)
  local ok, b = pcall(CreateFrame, "Button", nil, parent, template)
  if not ok or not b then
    b = CreateFrame("Button", nil, parent)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetAllPoints()
    fs:SetText(text or "X")
  elseif text then
    b:SetText(text)
  end
  return b
end

local function getFrame()
  if frame then return frame end
  local f = CreateFrame("Frame", "PagleProbeReportFrame", UIParent)
  f:SetSize(820, 540)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.05, 0.05, 0.08, 0.95)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", 12, -12)
  title:SetText("PagleProbe report: click Select all, press Ctrl+C, paste into GitHub")

  local close = makeButton(f, "UIPanelCloseButton")
  close:SetSize(24, 24)
  close:SetPoint("TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function() f:Hide() end)

  local scroll = CreateFrame("ScrollFrame", nil, f)
  scroll:SetPoint("TOPLEFT", 12, -40)
  scroll:SetPoint("BOTTOMRIGHT", -12, 12)

  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetMaxLetters(0)
  edit:SetFontObject(ChatFontNormal)
  edit:SetWidth(790)
  edit:SetHeight(500)
  edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() f:Hide() end)
  -- Read-only: undo anything typed.
  edit:SetScript("OnTextChanged", function(self, userInput)
    if userInput and f.text then self:SetText(f.text) end
  end)
  scroll:SetScrollChild(edit)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local range = self:GetVerticalScrollRange() or 0
    local new = math.max(0, math.min(self:GetVerticalScroll() - delta * 80, range))
    self:SetVerticalScroll(new)
  end)

  local sel = makeButton(f, "UIPanelButtonTemplate", "Select all")
  sel:SetSize(110, 22)
  sel:SetPoint("TOPRIGHT", -36, -8)
  sel:SetScript("OnClick", function()
    edit:SetFocus()
    edit:HighlightText()
  end)

  f.edit, f.scroll = edit, scroll
  frame = f
  return f
end

function ns.showReport()
  local text = ns.buildReport()
  local f = getFrame()
  f.text = text
  f.edit:SetText(text)
  f.edit:SetCursorPosition(0)
  f.scroll:SetVerticalScroll(0)
  f:Show()
  ns.print("report ready (" .. #text .. " characters). Click Select all, then Ctrl+C.")
end

-- Clicking PagleProbe in the AddOn compartment (minimap menu) opens the report.
function PagleProbe_OnCompartmentClick()
  ns.safe(ns.showReport)
end

----------------------------------------------------------------------
-- /pprobe
----------------------------------------------------------------------
local HELP = {
  "/pprobe - this status and help",
  "/pprobe report - open the copyable report",
  "/pprobe mark <what> - say what you do next: reload, relog, restart, module-off, module-on, crash, bulk5, bulk20",
  "/pprobe where <note> - log where you are (zone texts, map IDs, area IDs) with a note",
  "/pprobe weather - sample C_Weather now and print it",
  "/pprobe env - redo the environment checks (identity, calendar, items...)",
  "/pprobe verbose - turn the chat line per Catch on or off",
  "/pprobe settings - open the PagleProbe settings page",
  "/pprobe bulk 5 | 20 | off - synthetic saved data for the load-time test (do this LAST)",
  "/pprobe reset - clear the fishing log (keeps the persistence counters)",
}

local function status()
  local db = ns.db
  if not db then ns.print("not initialised yet.") return end
  local l = ns.load or {}
  local fishN = 0
  for _, c in ipairs(db.catches) do if c.fishing then fishN = fishN + 1 end end
  ns.print(string.format("v%s, session %d, locale %s. Saved data: %s. Module: %s.", ns.VERSION, db.session,
    tostring(ns.call("GetLocale")), l.fresh and "NOTHING READ BACK (fresh)" or ("read back, round-trip " .. tostring(l.roundtrip)),
    tostring(l.module)))
  ns.print(string.format("Loot windows %d (fishing %d). Weather samples %d. Probe errors %d. SV load %s ms.",
    #db.catches, fishN, #db.weather, #db.errors, tostring(l.svMs)))
  for _, line in ipairs(HELP) do print("   " .. line) end
end

function ns.slash(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = (cmd or ""):lower()
  local db = ns.db
  if cmd == "" or cmd == "help" or cmd == "status" then
    status()
  elseif not db then
    ns.print("not initialised yet.")
  elseif cmd == "report" then
    ns.showReport()
  elseif cmd == "mark" then
    if rest == "" then ns.print("usage: /pprobe mark reload (or relog, restart, module-off, ...)") return end
    ns.mark(rest)
    ns.print("marked '" .. rest .. "'. Now do it; the next load will be labelled with it.")
  elseif cmd == "where" then
    if InCombatLockdown() then ns.print("not in combat, try again after.") return end
    local w = ns.where()
    local entry = {
      note = rest, zone = w.zone, sub = w.sub, mini = w.mini, map = w.map, inst = w.inst,
      instType = w.instType, x = w.x, y = w.y, locale = w.locale,
      areaZone = areaText(w.areaZone), areaSub = areaText(w.areaSub),
    }
    ns.log("where", entry)
    ns.print(string.format("logged: %s / %s / %s, uiMap %s, mapID %s (%s), area IDs %s; %s",
      tostring(w.zone), tostring(w.sub), tostring(w.mini), tostring(w.map), tostring(w.inst),
      tostring(w.instType), entry.areaZone, entry.areaSub))
  elseif cmd == "weather" then
    local s = ns.sampleWeather("manual")
    ns.print("weather in " .. tostring(s and s.zone) .. ": " .. fmt(s and s.w))
  elseif cmd == "env" then
    if InCombatLockdown() then ns.print("not in combat, try again after.") return end
    ns.areaIndex = nil
    ns.runEnv("manual")
    ns.print("environment checks redone. Item answers arrive within 15 seconds.")
  elseif cmd == "verbose" then
    db.settings.verbose = not db.settings.verbose
    ns.print("chat line per Catch: " .. (db.settings.verbose and "on" or "off"))
  elseif cmd == "settings" then
    if InCombatLockdown() then ns.print("not in combat, try again after.") return end
    local root = PagleProbe.settingsRoot
    local ok = root and pcall(function() Settings.OpenToCategory(root:GetID()) end)
    if not ok then ns.print("could not open settings; look under Options > AddOns > PagleProbe.") end
  elseif cmd == "bulk" then
    if InCombatLockdown() then ns.print("not in combat, try again after.") return end
    if rest == "off" then
      PagleProbeBulkDB = nil
      ns.print("synthetic data removed. It disappears from the file at your next /reload.")
    elseif rest == "5" or rest == "20" then
      local n = ns.makeBulk(tonumber(rest))
      ns.print(string.format("created ~%s MB of synthetic data (%d records). Next: /pprobe mark bulk%s, then quit the game fully, restart, and time the loading screen.", rest, n, rest))
    else
      ns.print("usage: /pprobe bulk 5 | 20 | off")
    end
  elseif cmd == "reset" then
    db.events, db.catches, db.weather, db.errors = {}, {}, {}, {}
    db.agg = { tooltips = {}, soft = {}, objects = {} }
    ns.print("fishing log cleared. Persistence counters kept.")
  else
    status()
  end
end

SLASH_PAGLEPROBE1 = "/pprobe"
SlashCmdList.PAGLEPROBE = function(msg) ns.safe(ns.slash, msg) end
