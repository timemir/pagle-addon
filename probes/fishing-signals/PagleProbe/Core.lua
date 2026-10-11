-- PagleProbe/Core.lua
-- Throwaway, READ-ONLY diagnostic for Pagle issue #7 ("which fishing signals
-- can the Forever client see?"). It never casts, clicks the bobber, loots,
-- applies lures or takes any other game action. It only reads game APIs and
-- writes what it saw into its own SavedVariables.
--
-- This file: shared helpers, saved data, persistence counters, the Settings
-- root category, the public API the Module talks to, and the bulk-data test.

local ADDON, ns = ...

-- Load-time test: the client runs our files, then loads our SavedVariables,
-- then fires ADDON_LOADED. The gap between this line and ADDON_LOADED is
-- therefore mostly SavedVariables parse time.
ns.fileStartMs = debugprofilestop and debugprofilestop() or nil

ns.VERSION = "1"
ns.MAX_EVENTS = 1500 -- session log entries kept (oldest dropped first)
ns.MAX_CATCHES = 800 -- loot windows kept (oldest dropped first)
ns.flags = {}        -- set by the inline [AllowLoadGameType ...] test files
ns.pending = {}      -- errors raised before the saved data is ready

-- The one public global. The Module reaches the Core only through this table.
PagleProbe = { version = ns.VERSION }

----------------------------------------------------------------------
-- Secret values (Midnight rules). A secret can't be compared, indexed or
-- saved, so every secret becomes nil and we note where it was.
----------------------------------------------------------------------
local issecret = issecretvalue or function() return false end
local issecrettable = issecrettable or function() return false end
ns.issecret = issecret

-- Turn any value into plain saveable data (strings, numbers, booleans,
-- tables). Secrets become nil; their path is appended to `secrets`.
local function clean(v, depth, path, secrets)
  if issecret(v) then
    if secrets then secrets[#secrets + 1] = path end
    return nil
  end
  local t = type(v)
  if t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then return tostring(v) end
    return v
  elseif t == "string" then
    if #v > 400 then return v:sub(1, 400) .. "..." end
    return v
  elseif t == "boolean" or t == "nil" then
    return v
  elseif t == "table" then
    if issecrettable(v) then
      if secrets then secrets[#secrets + 1] = path end
      return nil
    end
    if depth <= 0 then return "<table>" end
    local out, count = {}, 0
    for k, val in pairs(v) do
      local kt = type(k)
      if not issecret(k) and (kt == "string" or kt == "number") then
        count = count + 1
        if count > 60 then out._truncated = true break end
        out[k] = clean(val, depth - 1, path .. "." .. tostring(k), secrets)
      end
    end
    return out
  end
  return "<" .. t .. ">"
end
ns.clean = function(v, depth) return clean(v, depth or 3, "v", nil) end

-- Find a global API by dotted name, e.g. "C_Map.GetBestMapForUnit".
function ns.resolve(path)
  local obj = _G
  for part in path:gmatch("[^%.]+") do
    if type(obj) ~= "table" then return nil end
    obj = obj[part]
  end
  return obj
end

local function pack(...) return { n = select("#", ...), ... } end

-- Call an API safely and return a plain record for the saved data:
--   { missing = true }                 the function doesn't exist
--   { ok = false, err = "..." }        it threw
--   { ok = true, n = 2, r = {...} }    it returned n values (secrets -> nil)
function ns.try(path, ...)
  local fn = ns.resolve(path)
  if type(fn) ~= "function" then return { missing = true } end
  local p = pack(pcall(fn, ...))
  if not p[1] then
    return { ok = false, err = issecret(p[2]) and "<secret error>" or tostring(p[2]) }
  end
  local secrets, r = {}, {}
  for i = 2, p.n do r[i - 1] = clean(p[i], 4, "r" .. (i - 1), secrets) end
  return { ok = true, n = p.n - 1, r = r, secret = (#secrets > 0) and secrets or nil }
end

-- Same as ns.try, but just return the (cleaned) values, or nothing.
function ns.call(path, ...)
  local rec = ns.try(path, ...)
  if rec.ok then return unpack(rec.r, 1, rec.n) end
end

function ns.now() return (GetServerTime and GetServerTime()) or time() end

function ns.round(x, places)
  if type(x) ~= "number" then return nil end
  local m = 10 ^ (places or 0)
  return math.floor(x * m + 0.5) / m
end

function ns.print(msg)
  print("|cff33ccffPagleProbe:|r " .. tostring(msg))
end

-- "GameObject-0-1234-0-5678-35591-0000ABCD" -> "GameObject", 35591
function ns.guidInfo(guid)
  if type(guid) ~= "string" then return nil end
  local parts = {}
  for p in guid:gmatch("[^%-]+") do parts[#parts + 1] = p end
  local kind = parts[1]
  local id
  if kind == "GameObject" or kind == "Creature" or kind == "Vehicle" or kind == "Pet" then
    id = tonumber(parts[6])
  end
  return kind, id
end

-- Record an internal error without ever showing a Lua error popup.
function ns.err(where, msg)
  msg = issecret(msg) and "<secret>" or tostring(msg)
  ns.errCount = (ns.errCount or 0) + 1
  local e = { at = ns.now(), where = tostring(where), msg = msg }
  if ns.db then
    e.session = ns.db.session
    local list = ns.db.errors
    list[#list + 1] = e
    if #list > 40 then table.remove(list, 1) end
  else
    ns.pending[#ns.pending + 1] = e
  end
  if ns.errCount == 1 then
    ns.print("an internal probe error was recorded (it is in /pprobe report). Fishing is not affected.")
  end
end

-- Run fn(...) and swallow any error into the error list.
function ns.safe(fn, ...)
  local ok, e = pcall(fn, ...)
  if not ok then ns.err("safe", e) end
end

-- Append one entry to the session log. Payloads are cleaned here, so callers
-- may pass raw event arguments.
function ns.log(kind, data)
  local db = ns.db
  if not db then return end
  local entry = clean(data or {}, 3, "log", nil) or {}
  entry.k = kind
  entry.t = ns.now()
  entry.s = db.session
  local ev = db.events
  ev[#ev + 1] = entry
  if #ev > ns.MAX_EVENTS then table.remove(ev, 1) end
end

----------------------------------------------------------------------
-- Value formatting for the report (Markdown-safe: no raw "|" escapes).
----------------------------------------------------------------------
local function fmt(v, depth, maxLen)
  depth = depth or 3
  maxLen = maxLen or 160
  if issecret(v) then return "<secret>" end
  local t = type(v)
  if t == "nil" then
    return "nil"
  elseif t == "string" then
    v = v:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", "/"):gsub("\r?\n", " / ")
    if #v > maxLen then v = v:sub(1, maxLen - 3) .. "..." end
    return '"' .. v .. '"'
  elseif t == "number" then
    if v == math.floor(v) then return tostring(v) end
    return tostring(math.floor(v * 1000 + 0.5) / 1000)
  elseif t == "boolean" then
    return tostring(v)
  elseif t == "table" then
    if depth <= 0 then return "{...}" end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
      local ta, tb = type(a), type(b)
      if ta ~= tb then return ta == "number" end
      if ta == "number" or ta == "string" then return a < b end
      return tostring(a) < tostring(b)
    end)
    local parts = {}
    for i, k in ipairs(keys) do
      if i > 25 then parts[#parts + 1] = "..." break end
      if type(k) == "number" then
        parts[#parts + 1] = fmt(v[k], depth - 1, maxLen)
      else
        parts[#parts + 1] = tostring(k) .. "=" .. fmt(v[k], depth - 1, maxLen)
      end
    end
    return "{" .. table.concat(parts, ", ") .. "}"
  end
  return "<" .. t .. ">"
end
ns.fmt = fmt

-- Format an ns.try record as one line.
function ns.fmtTry(rec, maxLen)
  if type(rec) ~= "table" then return fmt(rec, 3, maxLen) end
  if rec.missing then return "_missing (function does not exist)_" end
  if rec.ok == false then return "ERROR: " .. fmt(rec.err, 1, maxLen) end
  local parts = {}
  for i = 1, rec.n or 0 do parts[i] = fmt(rec.r and rec.r[i], 3, maxLen) end
  local s = ((rec.n or 0) == 0) and "(no values)" or table.concat(parts, ", ")
  if rec.secret then s = s .. " **(secret -> nil: " .. table.concat(rec.secret, ",") .. ")**" end
  return s
end

----------------------------------------------------------------------
-- Saved data and persistence round-trip
----------------------------------------------------------------------
-- A fixed value written at every logout and compared at every load.
local ROUNDTRIP = {
  n = 42, f = 1.25, neg = -7, s = 'quote " back\\slash', b = true,
  list = { 1, 2, 3 }, nested = { a = { b = "deep" } },
}
local function same(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do if not same(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end
local function copy(t)
  if type(t) ~= "table" then return t end
  local o = {}
  for k, v in pairs(t) do o[k] = copy(v) end
  return o
end
ns.copy = copy

-- Called from ADDON_LOADED for this addon, i.e. right after the client
-- has (or hasn't) read our SavedVariables back.
function ns.initDB()
  local svMs
  if ns.fileStartMs and debugprofilestop then
    svMs = ns.round(debugprofilestop() - ns.fileStartMs, 1)
  end

  local fresh = type(PagleProbeDB) ~= "table"
  if fresh then PagleProbeDB = {} end
  local db = PagleProbeDB
  ns.db = db
  db.probeVersion = ns.VERSION
  db.createdAt = db.createdAt or ns.now()
  if type(db.persist) ~= "table" then db.persist = {} end
  for _, key in ipairs({ "loads", "events", "catches", "weather", "env", "errors",
                         "settings", "areaIDs", "module", "spellNames", "agg" }) do
    if type(db[key]) ~= "table" then db[key] = {} end
  end
  if db.settings.verbose == nil then db.settings.verbose = true end
  db.agg.tooltips = db.agg.tooltips or {}
  db.agg.soft = db.agg.soft or {}
  db.agg.objects = db.agg.objects or {} -- tooltip post-call: object entry ID -> name, count
  db.areaIDs = {} -- text -> area IDs, rebuilt every session (names can change per build)
  db.module.history = db.module.history or {}
  db.session = (db.session or 0) + 1
  db.nextCatch = db.nextCatch or 1

  local p = db.persist
  p.loads = (p.loads or 0) + 1
  local load = {
    session = db.session,
    at = ns.now(),
    fresh = fresh,                      -- true = nothing was read back
    readWrites = p.writes or 0,         -- logout-write counter read back
    readLastWriteAt = p.lastWriteAt,
    mark = p.mark and p.mark.label,     -- what the tester said they did
    roundtrip = fresh and "n/a" or (same(db.roundtrip, ROUNDTRIP) and "ok" or "MISMATCH"),
    svMs = svMs,
    memKB = ns.round(collectgarbage("count"), 0),
    build = select(2, GetBuildInfo()),
  }
  p.mark = nil

  -- Per-character SavedVariable: same idea, tiny.
  local charFresh = type(PagleProbeCharDB) ~= "table"
  if charFresh then PagleProbeCharDB = { writes = 0, loads = 0 } end
  PagleProbeCharDB.loads = (PagleProbeCharDB.loads or 0) + 1
  load.charFresh = charFresh
  load.charWrites = PagleProbeCharDB.writes or 0

  -- Synthetic bulk data (load-time test), if present.
  if type(PagleProbeBulkDB) == "table" and type(PagleProbeBulkDB.records) == "table" then
    load.bulk = #PagleProbeBulkDB.records
    load.bulkMB = PagleProbeBulkDB.mb
  end

  table.insert(db.loads, load)
  if #db.loads > 40 then table.remove(db.loads, 1) end
  ns.load = load

  -- Errors that happened before the DB existed.
  for _, e in ipairs(ns.pending) do
    e.session = db.session
    db.errors[#db.errors + 1] = e
  end
  ns.pending = {}
end

-- PLAYER_LOGOUT: the last moment before the client writes SavedVariables
-- (it fires for /reload, logout and quit; not for a crash).
function ns.onLogout()
  local db = ns.db
  if not db then return end
  local p = db.persist
  p.writes = (p.writes or 0) + 1
  p.lastWriteAt = ns.now()
  p.lastWriteSession = db.session
  db.roundtrip = copy(ROUNDTRIP)
  if type(PagleProbeCharDB) == "table" then
    PagleProbeCharDB.writes = (PagleProbeCharDB.writes or 0) + 1
    PagleProbeCharDB.lastWriteAt = ns.now()
  end
  if type(PagleProbeBulkDB) == "table" then PagleProbeBulkDB.lastWriteAt = ns.now() end
  -- The Module writes its own file at this same logout, adding 1 to its counter.
  if ns.moduleThisSession then
    db.module.expectWrites = (ns.moduleThisSession.writes or 0) + 1
  end
end

-- "/pprobe mark <label>": remember what the tester is about to do, so the
-- next load can say e.g. "after restart: data read back".
function ns.mark(label)
  if not ns.db then return end
  ns.db.persist.mark = { label = label, at = ns.now(), session = ns.db.session }
end

----------------------------------------------------------------------
-- Module check-in (disabled-Module test)
----------------------------------------------------------------------
-- The Module calls this from its own ADDON_LOADED with what it read back.
function PagleProbe.ModuleCheckIn(info)
  local db = ns.db
  if not db or type(info) ~= "table" then return end
  local expected = db.module.expectWrites
  local row = {
    session = db.session, at = ns.now(), fresh = info.fresh, writes = info.writes,
    loads = info.loads, lastWriteAt = info.lastWriteAt, expected = expected,
    check = info.check, svMs = info.svMs, settings = info.settings,
  }
  if info.fresh then
    row.verdict = expected and "LOST: Module saved data was not read back" or "first run"
  elseif expected == nil then
    row.verdict = "no expectation yet"
  elseif info.writes == expected then
    row.verdict = "intact"
  else
    row.verdict = "changed (expected writes " .. tostring(expected) .. ", got " .. tostring(info.writes) .. ")"
  end
  ns.moduleThisSession = row
  local h = db.module.history
  h[#h + 1] = row
  if #h > 30 then table.remove(h, 1) end
end

----------------------------------------------------------------------
-- Settings: the "PagleProbe" root category (the Module adds a subcategory)
----------------------------------------------------------------------
function ns.registerSettings()
  local steps = {}
  local function step(name, fn)
    local ok, a = pcall(fn)
    steps[#steps + 1] = name .. ": " .. (ok and "ok" or ("ERROR " .. tostring(a)))
    return ok and a
  end
  ns.db.settingsSteps = steps
  if type(Settings) ~= "table" then
    steps[1] = "Settings API missing"
    return
  end
  local cat = step("RegisterVerticalLayoutCategory", function()
    return (Settings.RegisterVerticalLayoutCategory("PagleProbe"))
  end)
  if not cat then return end
  step("RegisterAddOnSetting + checkbox", function()
    local vt = (Settings.VarType and Settings.VarType.Boolean) or "boolean"
    local setting = Settings.RegisterAddOnSetting(cat, "PagleProbe_Verbose", "verbose",
      ns.db.settings, vt, "Print a chat line for each Catch", true)
    local create = Settings.CreateCheckbox or Settings.CreateCheckBox
    create(cat, setting, "PagleProbe prints one line in chat whenever it records a loot window.")
  end)
  step("RegisterAddOnCategory", function() Settings.RegisterAddOnCategory(cat) end)
  PagleProbe.settingsRoot = cat
end

----------------------------------------------------------------------
-- Synthetic bulk data for the load-time test (off by default)
----------------------------------------------------------------------
-- Each record looks like a compact Catch record. In the SavedVariables file
-- one record takes roughly 150 bytes, so 7000 records ~ 1 MB.
function ns.makeBulk(mb)
  local n = math.floor(mb * 7000)
  local t = ns.now()
  local recs = {}
  for i = 1, n do
    recs[i] = { i, t - i, 6291 + (i % 50), 1400 + (i % 300), i % 5, "Player-0000-0000ABCD" }
  end
  PagleProbeBulkDB = { mb = mb, count = n, createdAt = t, records = recs }
  return n
end
