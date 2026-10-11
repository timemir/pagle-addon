-- PagleQoLProbe / Core.lua
-- Throwaway diagnostic for Pagle issue #15. This file holds the shared
-- helpers: saved data, logging, events, the probe key, combat safety and
-- the report text.
--
-- THE RULE: at most one game action per hardware keypress, and the probe
-- never acts on its own. Game actions only happen through
--   * the probe key (an override binding the player presses), or
--   * a button the player clicks.
-- Event handlers and timers only log, read values, or re-point the probe key
-- out of combat. Re-pointing a key binding is not a game action.

local ADDON, P = ...
PagleQoLProbe = P -- the only global table (handy for /dump while debugging)

P.KEY_DEFAULT = "F9"
P.SET_NAME = "PagleProbe" -- equipment set created by the B9 test

-- Fishing spell IDs: Angleur's Vanilla table plus the Retail ones.
P.FISHING_IDS = {
  [7620] = true, [7731] = true, [7732] = true, [18248] = true, [33095] = true,
  [51294] = true, [88868] = true, [110410] = true, [131474] = true, [131476] = true,
}
P.ANGLEUR_VANILLA_IDS = { 7620, 7731, 7732, 18248, 33095, 51294 }
-- Classic lures and clams the probe looks for in your bags.
P.LURES = { 6529, 6530, 6532, 6533, 6811, 7307, 34861, 46006 }
P.CLAMS = { 5523, 5524, 7973, 24476 }
P.RAFT_TOY = 85500 -- Angler's Fishing Raft

P.RESULT_IDS = { "B1", "B2", "B3", "B4", "B5", "B6", "B7", "B8", "B9", "B10", "B11", "B12", "B13", "B14" }
P.TITLES = {
  B1 = "Soft-interact picks up the bobber",
  B2 = "Override bindings: key casts Fishing, reels by mouseover",
  B3 = "GLOBAL_MOUSE events and double-click cast",
  B4 = "Lure from a secure button; enchant readable",
  B5 = "Secret values out of combat",
  B6 = "Opening clams and containers (and camp objects)",
  B7 = "Aura reads (buff durations)",
  B8 = "Fishing toys in Collections; type=toy",
  B9 = "Equipment sets",
  B10 = "In-combat weapon swap button",
  B11 = "CVar names exist and addons can set them",
  B12 = "Secure snippets (SecureHandlerWrapScript)",
  B13 = "Pet summon from addon code",
  B14 = "Beta hygiene: SavedVariables, ReloadUI, ADDON_RESTRICTION_STATE_CHANGED",
}

P.armed = nil     -- the test whose key is armed (a table from Tests.lua)
P.armedRid = nil  -- its result id, e.g. "B4"
P.fishing = false -- true while the Fishing channel runs

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

local function newDB()
  return {
    schema = 1, key = P.KEY_DEFAULT, results = {}, log = {}, errors = {},
    sessions = {}, savedCVars = {}, config = {}, secretEvents = {},
  }
end
P.db = newDB() -- replaced by the SavedVariable at ADDON_LOADED

local function isSecret(v)
  return issecretvalue ~= nil and issecretvalue(v) == true
end
P.IsSecret = isSecret

-- Turn any value into report-safe text. Secret values are never touched.
function P.Str(v)
  if isSecret(v) then
    P.db.secretHits = (P.db.secretHits or 0) + 1
    return "<secret>"
  end
  if v == nil then return "nil" end
  local s = tostring(v)
  s = s:gsub("|", "/")  -- '|' starts WoW escape codes; keep the report copyable
  s = s:gsub("\n", " ")
  return s
end

function P.Args(...)
  local out = {}
  for i = 1, select("#", ...) do
    out[i] = P.Str((select(i, ...)))
  end
  return table.concat(out, ", ")
end

local function pack(...)
  return { n = select("#", ...), ... }
end

-- Call fn safely and return its results as text ("missing" if fn is nil).
function P.Try(fn, ...)
  if type(fn) ~= "function" then return "missing" end
  local r = pack(pcall(fn, ...))
  if not r[1] then return "error: " .. P.Str(r[2]) end
  local out = {}
  for i = 2, r.n do out[#out + 1] = P.Str(r[i]) end
  if #out == 0 then return "(no value)" end
  return table.concat(out, ", ")
end

function P.Print(msg)
  print("|cff33ff99[QoL probe]|r " .. msg)
end

local function push(list, line, cap)
  list[#list + 1] = line
  if #list > cap then table.remove(list, 1) end
end
P.Push = push

function P.R(id)
  local r = P.db.results[id]
  if not r then
    r = { auto = {}, evidence = {} }
    P.db.results[id] = r
  end
  return r
end

-- Add a time-stamped line to a test's evidence (default: the armed test)
-- and to the global log.
function P.Note(id, text)
  id = id or P.armedRid
  local line = date("%H:%M:%S") .. " " .. tostring(text):gsub("|", "/")
  push(P.db.log, (id and (id .. " ") or "") .. line, 400)
  if id and P.TITLES[id] then push(P.R(id).evidence, line, 60) end
end

-- Record one automatically measured fact for a test.
function P.Fact(id, key, value)
  P.R(id).auto[key] = P.Str(value)
end

function P.ProbeError(where, err)
  push(P.db.errors, date("%H:%M:%S") .. " probe Lua error in " .. where .. ": " .. P.Str(err), 50)
  P.Print("probe error in " .. where .. " (saved in the report): " .. P.Str(err))
end

-- Wrap a script handler so a probe bug is reported instead of thrown.
function P.Safe(where, fn)
  return function(...)
    local ok, err = pcall(fn, ...)
    if not ok then P.ProbeError(where, err) end
  end
end

-- C_Timer.After with error capture. Timers in this addon only log or rebind.
function P.After(sec, fn)
  C_Timer.After(sec, P.Safe("timer", fn))
end

function P.Refuse()
  if InCombatLockdown() then
    P.Print("Disabled in combat. Leave combat first.")
    return true
  end
  return false
end

function P.ItemName(id)
  local ok, name = pcall(C_Item.GetItemNameByID, id)
  if ok and not isSecret(name) and name then return P.Str(name) end
  return "item " .. P.Str(id)
end

function P.ParseItem(s)
  if not s then return nil end
  return tonumber(s:match("item:(%d+)") or s:match("^%s*(%d+)%s*$"))
end

function P.CountText(id)
  return P.Try(C_Item and C_Item.GetItemCount, id)
end

-- Return the first item from ids that is in the bags.
function P.FindInBags(ids)
  local want = {}
  for _, id in ipairs(ids) do want[id] = true end
  for bag = 0, 5 do
    local okN, n = pcall(C_Container.GetContainerNumSlots, bag)
    if okN and type(n) == "number" then
      for slot = 1, n do
        local okI, id = pcall(C_Container.GetContainerItemID, bag, slot)
        if okI and not isSecret(id) and id and want[id] then return id end
      end
    end
  end
  return nil
end

function P.FishingName()
  return PROFESSIONS_FISHING or "Fishing"
end

function P.SpellText(spellID)
  if isSecret(spellID) then return "<secret>" end
  local name = P.Try(C_Spell and C_Spell.GetSpellName, spellID)
  return P.Str(spellID) .. " (" .. name .. ")"
end

function P.IsFishingSpell(spellID)
  if isSecret(spellID) or spellID == nil then return nil end
  if P.FISHING_IDS[spellID] then return true end
  local ok, name = pcall(C_Spell.GetSpellName, spellID)
  return ok and not isSecret(name) and name ~= nil and name == P.FishingName()
end

function P.KeyHeld()
  local ok, down = pcall(IsKeyDown, P.db.key)
  return (ok and down) and true or false
end

-- Lure state on the main hand, read through both APIs Forever offers.
function P.EnchantText()
  local parts = {}
  if C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo then
    local ok, info = pcall(C_PaperDollInfo.GetTemporaryEnchantmentInfo, 16)
    if not ok then
      parts[#parts + 1] = "PaperDoll error " .. P.Str(info)
    elseif isSecret(info) then
      parts[#parts + 1] = "PaperDoll <secret>"
    elseif type(info) == "table" then
      parts[#parts + 1] = "PaperDoll enchantID " .. P.Str(info.enchantID) .. ", remainingMs " ..
        P.Str(info.remainingTimeMs) .. ", charges " .. P.Str(info.chargesRemaining)
    else
      parts[#parts + 1] = "PaperDoll: no temp enchant"
    end
  else
    parts[#parts + 1] = "C_PaperDollInfo.GetTemporaryEnchantmentInfo missing"
  end
  parts[#parts + 1] = "GetWeaponEnchantInfo() = " .. P.Try(GetWeaponEnchantInfo)
  return table.concat(parts, "; ")
end

---------------------------------------------------------------------------
-- Events. Every RegisterEvent is wrapped in pcall; failures are reported.
---------------------------------------------------------------------------

local ev = CreateFrame("Frame")
P.handlers, P.eventOK, P.eventFailed, P.eventCount = {}, {}, {}, {}

function P.On(event, fn)
  if not P.handlers[event] then
    P.handlers[event] = {}
    local ok, ret
    if event:find("^UNIT_") then
      ok, ret = pcall(ev.RegisterUnitEvent, ev, event, "player")
    else
      ok, ret = pcall(ev.RegisterEvent, ev, event)
    end
    if ok and ret ~= false then
      P.eventOK[event] = true
    else
      P.eventFailed[event] = ok and "returned false" or P.Str(ret)
    end
  end
  table.insert(P.handlers[event], fn)
end

ev:SetScript("OnEvent", function(_, event, ...)
  P.eventCount[event] = (P.eventCount[event] or 0) + 1
  -- B5 evidence: remember which event payloads arrive as secret values.
  for i = 1, select("#", ...) do
    if isSecret((select(i, ...))) then
      local where = InCombatLockdown() and " (in combat)" or " (out of combat)"
      local k = event .. where
      P.db.secretEvents[k] = (P.db.secretEvents[k] or 0) + 1
      break
    end
  end
  local list = P.handlers[event]
  if not list then return end
  for i = 1, #list do
    local ok, err = pcall(list[i], event, ...)
    if not ok then P.ProbeError(event, err) end
  end
end)

---------------------------------------------------------------------------
-- Secure frames. Built once at load, out of combat.
---------------------------------------------------------------------------

-- Owners of the override bindings. Bindings are temporary: they vanish on
-- /reload or logout and never touch your saved keybinds.
P.owner = CreateFrame("Frame", "PagleQoLProbeKeyOwner")
P.mouseOwner = CreateFrame("Frame", "PagleQoLProbeMouseOwner")

-- The one secure button the probe key clicks. Its attributes are set out of
-- combat to "the next step" of the armed test (Angleur's pattern).
P.btn = CreateFrame("Button", "PagleQoLProbeActionButton", UIParent, "SecureActionButtonTemplate")
P.btn:SetSize(1, 1)
P.btn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
P.btn:RegisterForClicks("AnyDown", "AnyUp")

-- B12: a secure button with a wrapped snippet, and its secure header.
P.snip = CreateFrame("Button", "PagleQoLProbeSnippetButton", UIParent, "SecureActionButtonTemplate")
P.snip:SetSize(1, 1)
P.snip:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
P.snip:RegisterForClicks("AnyDown")
P.header = CreateFrame("Frame", "PagleQoLProbeSnippetHeader", UIParent, "SecureHandlerBaseTemplate")

-- B10: a visible secure button the player clicks in combat.
local w = CreateFrame("Button", "PagleQoLProbeWeaponButton", UIParent, "SecureActionButtonTemplate")
w:SetSize(260, 46)
w:SetPoint("TOP", UIParent, "TOP", 0, -120)
w:RegisterForClicks("AnyDown", "AnyUp")
local wbg = w:CreateTexture(nil, "BACKGROUND")
wbg:SetAllPoints()
wbg:SetColorTexture(0.1, 0.45, 0.1, 0.9)
w.label = w:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
w.label:SetPoint("CENTER")
w:Hide()
P.b10 = w

local BUTTON_ATTRS = { "type", "spell", "item", "macrotext", "toy", "target-slot", "useOnKeyDown" }

function P.ResetButton()
  if InCombatLockdown() then return end
  for _, a in ipairs(BUTTON_ATTRS) do P.btn:SetAttribute(a, nil) end
end

function P.SetButton(attrs)
  if InCombatLockdown() then return end
  P.ResetButton()
  for k, v in pairs(attrs) do P.btn:SetAttribute(k, v) end
  P.Note(nil, "secure button set: " .. P.Str(attrs.type) .. " " ..
    P.Str(attrs.spell or attrs.item or attrs.macrotext or attrs.toy))
end

---------------------------------------------------------------------------
-- The probe key
---------------------------------------------------------------------------

P.boundTo, P.boundAction = "nothing", ""

-- Point the probe key at kind/value ("spell", "command" or "click"), or at
-- nothing. Out of combat only.
function P.ApplyBinding(kind, value, owner)
  if InCombatLockdown() then return end
  local key = P.db.key
  pcall(ClearOverrideBindings, P.owner)
  pcall(ClearOverrideBindings, P.snip)
  owner = owner or P.owner
  local ok, err = true, nil
  if kind == "spell" then
    ok, err = pcall(SetOverrideBindingSpell, owner, true, key, value)
  elseif kind == "command" then
    ok, err = pcall(SetOverrideBinding, owner, true, key, value)
  elseif kind == "click" then
    ok, err = pcall(SetOverrideBindingClick, owner, true, key, value, "LeftButton")
  end
  local want = kind and (kind .. " " .. tostring(value)) or "nothing"
  local okA, action = pcall(GetBindingAction, key, true)
  action = okA and P.Str(action) or "?"
  if not ok then
    P.Note(nil, "binding FAILED (" .. want .. "): " .. P.Str(err))
  elseif want ~= P.boundTo then
    P.Note(nil, "probe key " .. key .. " -> " .. want .. " (GetBindingAction: '" .. action .. "')")
  end
  P.boundTo, P.boundAction = want, action
  if P.UpdateStatus then P.UpdateStatus() end
end

-- Re-point the probe key to the armed test's next step. Like Angleur, never
-- change the binding while the key is held; check again a moment later.
local waiting = false
function P.Refresh()
  if InCombatLockdown() then return end
  if P.KeyHeld() then
    if not waiting then
      waiting = true
      P.After(0.15, function() waiting = false; P.Refresh() end)
    end
    return
  end
  local t = P.armed
  if t and t.bind then
    P.ApplyBinding(t.bind(P.fishing))
  else
    P.ApplyBinding(nil)
  end
end

---------------------------------------------------------------------------
-- Temporary CVars (B1). Originals are kept in the SavedVariable so they can
-- be restored even after a crash: /qprobe restore.
---------------------------------------------------------------------------

function P.GetCV(name)
  if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
  return GetCVar(name)
end

function P.SetCV(name, value)
  if C_CVar and C_CVar.SetCVar then return C_CVar.SetCVar(name, value) end
  return SetCVar(name, value)
end

function P.TempCVar(name, value)
  local ok, orig = pcall(P.GetCV, name)
  if not ok or orig == nil then
    P.Note(nil, "CVar " .. name .. " is missing")
    return
  end
  if P.db.savedCVars[name] == nil then P.db.savedCVars[name] = orig end
  local ok2, err = pcall(P.SetCV, name, value)
  P.Note(nil, "CVar " .. name .. ": " .. P.Str(orig) .. " -> " .. value .. " (" ..
    (ok2 and "ok" or P.Str(err)) .. ", reads back " .. P.Try(P.GetCV, name) .. ")")
end

function P.RestoreCVars()
  if InCombatLockdown() then return end
  for name, orig in pairs(P.db.savedCVars) do
    local ok, err = pcall(P.SetCV, name, orig)
    if ok then
      P.db.savedCVars[name] = nil
      P.Note(nil, "CVar " .. name .. " restored to " .. P.Str(orig))
    else
      P.Note(nil, "CVar " .. name .. " restore FAILED: " .. P.Str(err))
    end
  end
end

---------------------------------------------------------------------------
-- Arming and disarming tests
---------------------------------------------------------------------------

function P.Disarm(reason)
  local was = P.armedRid
  P.armed, P.armedRid = nil, nil
  if not InCombatLockdown() then
    P.ApplyBinding(nil)
    pcall(ClearOverrideBindings, P.mouseOwner)
    P.ResetButton()
    P.RestoreCVars()
    if P.b10:IsShown() then P.b10:Hide() end
  end
  if was then P.Note(was, "disarmed (" .. reason .. ")") end
  if P.UpdateStatus then P.UpdateStatus() end
end

-- Called by a panel button or "/qprobe <test>". A "run" test does its one
-- thing right now (on this click). Other tests arm the probe key.
function P.Press(id)
  local t = P.testsById[id]
  if not t then
    P.Print("Unknown test '" .. tostring(id) .. "'.")
    return
  end
  if P.Refuse() then return end
  if P.ShowHelp then P.ShowHelp(t) end
  if t.run then
    local ok, err = pcall(t.run)
    if not ok then P.ProbeError(t.id, err) end
    return
  end
  P.Disarm("switching to " .. t.id)
  P.armed, P.armedRid = t, t.rid
  P.Note(t.rid, "armed " .. t.label)
  local ok, result = pcall(t.arm)
  if not ok then
    P.ProbeError(t.id, result)
    P.Disarm("error while arming")
    return
  end
  if result == false then
    P.Disarm("not armed: something is missing, see chat")
    return
  end
  P.Refresh()
  P.Print(t.label .. " armed. Probe key: " .. P.db.key .. ".")
end

---------------------------------------------------------------------------
-- Report
---------------------------------------------------------------------------

local VERDICT_TEXT = { works = "works", doesnt = "doesn't work", partial = "partial" }
P.VERDICT_TEXT = VERDICT_TEXT

local function sortedKeys(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys)
  return keys
end

function P.BuildReport()
  if P.RefreshFacts then pcall(P.RefreshFacts) end
  local L = {}
  local function add(s) L[#L + 1] = s end
  local db = P.db

  add("## Pagle QoL probe report (issue #15)")
  add("")
  add("- Generated: " .. date("%Y-%m-%d %H:%M:%S"))
  add("- Client (GetBuildInfo): " .. P.Try(GetBuildInfo))
  add("- WOW_PROJECT_ID: " .. P.Str(WOW_PROJECT_ID) .. ", WOW_PROJECT_CAMELOT: " .. P.Str(WOW_PROJECT_CAMELOT) ..
    ", LE_EXPANSION_LEVEL_CURRENT: " .. P.Str(LE_EXPANSION_LEVEL_CURRENT) .. ", locale: " .. P.Try(GetLocale))
  add("- Scripts disallowed for beta: " .. P.Try(C_AddOns and C_AddOns.GetScriptsDisallowedForBeta))
  add("- Probe key: " .. P.Str(db.key) .. ", ActionButtonUseKeyDown: " .. P.Try(P.GetCV, "ActionButtonUseKeyDown"))
  local failed = {}
  for _, e in ipairs(sortedKeys(P.eventFailed)) do failed[#failed + 1] = e .. " (" .. P.eventFailed[e] .. ")" end
  add("- Events that failed to register: " .. (#failed > 0 and table.concat(failed, "; ") or "none"))
  local pending = sortedKeys(db.savedCVars)
  add("- CVars still waiting to be restored: " .. (#pending > 0 and table.concat(pending, ", ") or "none"))
  add("")
  add("### Checklist")
  for _, id in ipairs(P.RESULT_IDS) do
    local r = db.results[id]
    local verdict = (r and r.verdict) and VERDICT_TEXT[r.verdict] or "not answered"
    local note = (r and r.note and r.note ~= "") and (" - " .. P.Str(r.note)) or ""
    add("- **" .. id .. "** " .. P.TITLES[id] .. ": **" .. verdict .. "**" .. note)
  end
  add("")
  add("### Blocked actions and probe errors")
  if #db.errors == 0 then add("- none") end
  for _, line in ipairs(db.errors) do add("- " .. line) end
  add("")
  add("### Evidence")
  for _, id in ipairs(P.RESULT_IDS) do
    local r = db.results[id]
    add("")
    add("#### " .. id .. " " .. P.TITLES[id])
    if not r then
      add("- (nothing recorded)")
    else
      for _, k in ipairs(sortedKeys(r.auto)) do add("- " .. k .. ": " .. r.auto[k]) end
      if #r.evidence > 0 then
        add("```")
        for _, line in ipairs(r.evidence) do add(line) end
        add("```")
      end
    end
  end
  return table.concat(L, "\n")
end
