-- PagleQoLProbe / Tests.lua
-- One entry per panel button. Each entry is either
--   * a "key" test: arm() prepares the secure button out of combat, and
--     bind(fishing) says what the probe key does right now, or
--   * a "run" test: run() does its single thing on this click.
-- The event observers at the bottom only log. They never act.

local ADDON, P = ...
local isSecret = P.IsSecret

P.testList, P.testsById, P.testsByLower = {}, {}, {}
local function add(t)
  P.testList[#P.testList + 1] = t
  P.testsById[t.id] = t
  P.testsByLower[t.id:lower()] = t
end

local function clickButton() return "click", P.btn:GetName() end
local function castOr(step)
  return function(fishing)
    if fishing then return "command", step end
    return "spell", P.FishingName()
  end
end

-- Facts about the main-hand slot (where a Classic fishing pole sits).
local function slotFacts(rid)
  local id = GetInventoryItemID("player", 16)
  P.Fact(rid, "slot 16 item", P.Str(id) .. " " .. (id and P.ItemName(id) or "") ..
    " (GetItemInfoInstant: " .. P.Try(C_Item.GetItemInfoInstant, id or 0) .. ")")
  if INVSLOT_FISHING_TOOL then
    P.Fact(rid, "INVSLOT_FISHING_TOOL " .. P.Str(INVSLOT_FISHING_TOOL) .. " item",
      P.Try(GetInventoryItemID, "player", INVSLOT_FISHING_TOOL))
  end
end

local function isPole(id)
  local ok, _, _, _, _, _, classID, subclassID = pcall(C_Item.GetItemInfoInstant, id)
  return ok and classID == 2 and subclassID == 20
end

local function lure()
  local id = P.db.config.lure or P.FindInBags(P.LURES)
  if not id then P.Print("No lure found. Put one in your bags, or type /qprobe lure <shift-click the lure>.") end
  return id
end

local function setID()
  if not C_EquipmentSet then return nil end
  local ok, id = pcall(C_EquipmentSet.GetEquipmentSetID, P.SET_NAME)
  if ok and not isSecret(id) and id then return id end
  return nil
end

---------------------------------------------------------------------------
-- B1 / B2: one key casts, then reels (Angleur's A1 and A3)
---------------------------------------------------------------------------

add({
  id = "B1", rid = "B1", label = "B1 soft-interact",
  help = "Stand at fishable water. Press the probe key: it casts Fishing. While the bobber is out, " ..
    "point the mouse AWAY from the bobber and press the probe key again: it is now 'Interact With Target' " ..
    "(soft-interact is switched on for this test). Try 3+ casts: press after the splash, and once before it. " ..
    "If you have your own Interact key, try it too. Then: /qprobe yes|no|partial B1 [note]",
  arm = function()
    P.TempCVar("SoftTargetInteract", "3")
    P.TempCVar("SoftTargetInteractRange", "15")
    P.TempCVar("SoftTargetInteractRangeIsHard", "0")
    P.Fact("B1", "your own Interact With Target key(s)", P.Try(GetBindingKey, "INTERACTTARGET"))
    slotFacts("B1")
  end,
  bind = castOr("INTERACTTARGET"),
})

add({
  id = "B2", rid = "B2", label = "B2 key cast+reel",
  help = "Press the probe key: it should cast Fishing (SetOverrideBindingSpell). While the bobber is out, " ..
    "put the mouse pointer ON the bobber and press the probe key again (INTERACTMOUSEOVER). " ..
    "Do 3+ casts. Then: /qprobe yes|no|partial B2 [note]",
  arm = function()
    for _, id in ipairs(P.ANGLEUR_VANILLA_IDS) do
      P.Fact("B2", "spell " .. id, P.Try(C_Spell and C_Spell.GetSpellName, id) ..
        "; known: " .. P.Try(C_SpellBook and C_SpellBook.IsSpellKnown, id))
    end
    P.Fact("B2", "PROFESSIONS_FISHING", PROFESSIONS_FISHING)
  end,
  bind = castOr("INTERACTMOUSEOVER"),
})

---------------------------------------------------------------------------
-- B3: double right-click casts (Angleur's A2). The probe key is unused.
---------------------------------------------------------------------------

add({
  id = "B3", rid = "B3", label = "B3 double-click",
  help = "Point the mouse at open water (not at a window) and double-click the RIGHT mouse button quickly. " ..
    "The second click should cast Fishing. Try 3 times. Single right-clicks should still work as normal. " ..
    "Then: /qprobe yes|no|partial B3 [note]",
  arm = function()
    P.SetButton({ type = "spell", spell = P.FishingName(), useOnKeyDown = true })
  end,
  bind = function() return nil end,
})

local b3 = { window = 0, open = false }

P.On("GLOBAL_MOUSE_DOWN", function(_, button)
  if P.armedRid == "B3" then
    P.Note("B3", "GLOBAL_MOUSE_DOWN " .. P.Str(button) .. (b3.open and " (window open)" or ""))
  end
end)

-- On a right-click release, bind BUTTON2 to the cast button for 0.4 s, so a
-- second click casts. Changing a binding is not a game action.
P.On("GLOBAL_MOUSE_UP", function(_, button)
  if P.armedRid ~= "B3" or InCombatLockdown() then return end
  if isSecret(button) or button ~= "RightButton" or b3.open then return end
  b3.window = b3.window + 1
  local mine = b3.window
  local ok, err = pcall(SetOverrideBindingClick, P.mouseOwner, true, "BUTTON2", P.btn:GetName(), "LeftButton")
  b3.open = ok
  P.Note("B3", "right-click released: BUTTON2 -> cast button for 0.4 s (" .. (ok and "ok" or P.Str(err)) .. ")")
  P.After(0.4, function()
    if b3.window ~= mine then return end
    b3.open = false
    if not InCombatLockdown() then pcall(ClearOverrideBindings, P.mouseOwner) end
  end)
end)

---------------------------------------------------------------------------
-- B4: lure from the secure button, two ways
---------------------------------------------------------------------------

add({
  id = "B4", rid = "B4", label = "B4 lure (macro)",
  help = "Equip the fishing pole, have a lure in your bags. Press the probe key ONCE: it runs " ..
    "'/use <lure>' + '/use 16'. Is the lure on the pole now (hover the pole in the character pane)? " ..
    "Then also try 'B4 lure (item)'. Then: /qprobe yes|no|partial B4 [which way worked]",
  arm = function()
    local id = lure()
    if not id then return false end
    slotFacts("B4")
    P.Note("B4", "macro variant, lure " .. id .. " " .. P.ItemName(id) .. "; before: " .. P.EnchantText())
    P.SetButton({ type = "macro", macrotext = "/use item:" .. id .. "\n/use 16" })
  end,
  bind = clickButton,
})

add({
  id = "B4i", rid = "B4", label = "B4 lure (item)",
  help = "Press the probe key ONCE: the secure button uses type=item with target-slot=16. " ..
    "If the game asks to replace the existing lure, click Yes. Did the lure go on the pole?",
  arm = function()
    local id = lure()
    if not id then return false end
    P.Note("B4", "item variant, lure " .. id .. " " .. P.ItemName(id) .. "; before: " .. P.EnchantText())
    P.SetButton({ type = "item", item = "item:" .. id, ["target-slot"] = 16 })
  end,
  bind = clickButton,
})

---------------------------------------------------------------------------
-- B5: secret values (read-only)
---------------------------------------------------------------------------

function P.SecretSnapshot(why)
  local parts = { "snapshot (" .. why .. "): combat " .. P.Str(InCombatLockdown()) .. ", fishing " .. P.Str(P.fishing) }
  parts[#parts + 1] = "ShouldAurasBeSecret " .. P.Try(C_Secrets and C_Secrets.ShouldAurasBeSecret)
  local item = P.db.config.lure or P.FindInBags(P.LURES) or GetInventoryItemID("player", 16)
  if item then parts[#parts + 1] = "GetItemCount(" .. item .. ") " .. P.CountText(item) end
  parts[#parts + 1] = P.EnchantText()
  P.Note("B5", table.concat(parts, "; "))
end

add({
  id = "B5", rid = "B5", label = "B5 secrets",
  help = "Out of combat: cast Fishing, and while the bobber is out click this button. The probe also takes " ..
    "this snapshot by itself at every cast. Look for '<secret>' in the report. " ..
    "Then: /qprobe yes|no|partial B5 (yes = everything readable)",
  run = function() P.SecretSnapshot("button") end,
})

---------------------------------------------------------------------------
-- B6: open a clam or container
---------------------------------------------------------------------------

add({
  id = "B6", rid = "B6", label = "B6 clam",
  help = "Have a clam (or any openable item) in your bags, or set one: /qprobe clam <shift-click item>. " ..
    "Press the probe key ONCE: it runs '/use <item>'. Did it open? If you own Forever camp objects " ..
    "(Fish Bowl, Fishing Rack, Fishing Hut), set one with /qprobe clam <item>, click B6 again and try it. " ..
    "Then: /qprobe yes|no|partial B6 [note]",
  arm = function()
    local id = P.db.config.clam or P.FindInBags(P.CLAMS)
    if not id then
      P.Print("No clam found. Type /qprobe clam <shift-click an item>.")
      return false
    end
    P.armedItem = id
    P.Note("B6", "item " .. id .. " " .. P.ItemName(id) .. ", count before " .. P.CountText(id))
    P.SetButton({ type = "macro", macrotext = "/use item:" .. id })
  end,
  bind = clickButton,
})

---------------------------------------------------------------------------
-- B7: aura reads (read-only)
---------------------------------------------------------------------------

add({
  id = "B7", rid = "B7", label = "B7 auras",
  help = "Out of combat, have a buff on you (eat food, or any buff), then click. The probe lists your buffs " ..
    "with duration. Then: /qprobe yes|no|partial B7 (yes = names and durations readable, no '<secret>')",
  run = function()
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
      P.Fact("B7", "C_UnitAuras.GetAuraDataByIndex", "missing")
      return
    end
    local n = 0
    for i = 1, 40 do
      local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
      if not ok then
        P.Note("B7", "error at aura " .. i .. ": " .. P.Str(a))
        break
      elseif isSecret(a) then
        P.Note("B7", "aura " .. i .. " is <secret>")
      elseif a == nil then
        break
      else
        n = n + 1
        P.Note("B7", "aura " .. i .. ": " .. P.Str(a.name) .. " (spellId " .. P.Str(a.spellId) ..
          ") duration " .. P.Str(a.duration) .. ", expirationTime " .. P.Str(a.expirationTime))
      end
    end
    P.Fact("B7", "buffs read at last click", n)
    P.Fact("B7", "GetTime() at last click", GetTime())
    P.Fact("B7", "ShouldAurasBeSecret", P.Try(C_Secrets and C_Secrets.ShouldAurasBeSecret))
  end,
})

---------------------------------------------------------------------------
-- B8: toys
---------------------------------------------------------------------------

add({
  id = "B8", rid = "B8", label = "B8 toys",
  help = "Click once: the probe checks the Toy Box API. Open Collections > Toy Box and search 'fish', " ..
    "'raft', 'bobber'. If you own a fishing toy: /qprobe toy <shift-click it>, click B8 again and press " ..
    "the probe key ONCE. Then: /qprobe yes|no|partial B8 [toys you saw]",
  arm = function()
    local tb = C_ToyBox
    P.Fact("B8", "C_ToyBox", tb and "present" or "missing")
    P.Fact("B8", "GetNumToys", P.Try(tb and tb.GetNumToys))
    P.Fact("B8", "GetNumLearnedDisplayedToys", P.Try(tb and tb.GetNumLearnedDisplayedToys))
    P.Fact("B8", "GetToyInfo(85500 raft)", P.Try(tb and tb.GetToyInfo, P.RAFT_TOY))
    P.Fact("B8", "PlayerHasToy(85500 raft)", P.Try(PlayerHasToy, P.RAFT_TOY))
    local toy = P.db.config.toy
    if not toy then
      P.Print("Toy Box checked. To test using a toy: /qprobe toy <item>, then click B8 again.")
      return false
    end
    P.Fact("B8", "PlayerHasToy(" .. toy .. ")", P.Try(PlayerHasToy, toy))
    P.Fact("B8", "IsToyUsable(" .. toy .. ")", P.Try(tb and tb.IsToyUsable, toy))
    P.SetButton({ type = "toy", toy = toy })
  end,
  bind = clickButton,
})

---------------------------------------------------------------------------
-- B9: equipment sets
---------------------------------------------------------------------------

add({
  id = "B9s", rid = "B9", label = "B9 save set",
  help = "Wear your normal gear WITH the fishing pole and click ONCE: the probe checks the equipment-set API " ..
    "and saves your gear as set 'PagleProbe'. Also open the character pane (C): is there an Equipment " ..
    "Manager / sets button? Next: 'B9 /equipset key' and 'B9 API equip'.",
  run = function()
    local es = C_EquipmentSet
    P.Fact("B9", "C_EquipmentSet", es and "present" or "missing")
    if not es then return end
    P.Fact("B9", "CanUseEquipmentSets", P.Try(es.CanUseEquipmentSets))
    P.Fact("B9", "GetNumEquipmentSets", P.Try(es.GetNumEquipmentSets))
    local id = setID()
    if id then
      P.Note("B9", "set " .. P.SET_NAME .. " already exists (id " .. P.Str(id) .. ")")
      return
    end
    P.Note("B9", "CreateEquipmentSet('" .. P.SET_NAME .. "'): " .. P.Try(es.CreateEquipmentSet, P.SET_NAME))
    P.After(1, function() P.Note("B9", "set id after create: " .. P.Str(setID())) end)
  end,
})

add({
  id = "B9k", rid = "B9", label = "B9 /equipset key",
  help = "After 'B9 save set': take the pole off (drag it into your bags). Press the probe key ONCE: " ..
    "it runs '/equipset PagleProbe'. Is the pole back on?",
  arm = function()
    if not setID() then
      P.Print("Save the set first: click 'B9 save set'.")
      return false
    end
    P.SetButton({ type = "macro", macrotext = "/equipset " .. P.SET_NAME })
  end,
  bind = clickButton,
})

add({
  id = "B9a", rid = "B9", label = "B9 API equip",
  help = "Take the pole off again, then click ONCE: the probe calls C_EquipmentSet.UseEquipmentSet on this " ..
    "click. Is the pole back on? Then: /qprobe yes|no|partial B9 [note]",
  run = function()
    local id = setID()
    if not id then
      P.Print("Save the set first: click 'B9 save set'.")
      return
    end
    P.Note("B9", "UseEquipmentSet(" .. P.Str(id) .. "): " .. P.Try(C_EquipmentSet.UseEquipmentSet, id))
  end,
})

add({
  id = "B9d", rid = "B9", label = "B9 delete set",
  help = "Cleanup: deletes the 'PagleProbe' equipment set.",
  run = function()
    local id = setID()
    if not id then
      P.Note("B9", "no " .. P.SET_NAME .. " set to delete")
      return
    end
    P.Note("B9", "DeleteEquipmentSet(" .. P.Str(id) .. "): " .. P.Try(C_EquipmentSet.DeleteEquipmentSet, id))
  end,
})

---------------------------------------------------------------------------
-- B10: in-combat weapon swap (a visible secure button you click)
---------------------------------------------------------------------------

add({
  id = "B10", rid = "B10", label = "B10 combat swap", keepInCombat = true,
  help = "Equip your normal weapon and click this: a green button appears at the top of the screen. " ..
    "Now equip the fishing pole. Start a fight (a low-level mob). IN COMBAT, click the green button ONCE. " ..
    "Is your weapon back? After combat click 'Disarm'. Then: /qprobe yes|no|partial B10 [note]",
  arm = function()
    local id = P.db.config.weapon or GetInventoryItemID("player", 16)
    if not id or isPole(id) then
      P.Print("Equip your normal weapon first (or /qprobe weapon <item>), then click B10 again.")
      return false
    end
    local okN, name = pcall(C_Item.GetItemNameByID, id)
    P.b10:SetAttribute("type", "macro")
    P.b10:SetAttribute("macrotext", "/equip " .. ((okN and not isSecret(name) and name) or ("item:" .. id)))
    P.b10.label:SetText("B10: equip " .. P.ItemName(id) .. "\nclick me ONCE in combat")
    P.b10:Show()
    P.Note("B10", "weapon " .. id .. " " .. P.ItemName(id) .. "; green button shown")
  end,
  bind = function() return nil end,
})

P.b10:SetScript("PostClick", P.Safe("B10 PostClick", function(_, button, down)
  P.Note("B10", "green button clicked (" .. P.Str(button) .. ", down " .. P.Str(down) ..
    ", in combat " .. P.Str(InCombatLockdown()) .. ")")
end))

---------------------------------------------------------------------------
-- B11: CVars (read, flip for one moment, put back)
---------------------------------------------------------------------------

local CVARS = {
  "SoftTargetInteract", "SoftTargetInteractRange", "SoftTargetInteractRangeIsHard",
  "autoLootDefault", "autoInteract", "ActionButtonUseKeyDown",
  "Sound_EnableAllSound", "Sound_EnableSFX", "Sound_EnableMusic", "Sound_EnableAmbience",
  "Sound_EnableDialog", "Sound_EnableSoundWhenGameIsInBG", "Sound_MasterVolume", "Sound_SFXVolume",
  "Sound_MusicVolume", "Sound_AmbienceVolume", "Sound_DialogVolume",
}

add({
  id = "B11", rid = "B11", label = "B11 CVars",
  help = "Click ONCE out of combat. For each CVar the probe reads it, changes it for one moment and puts it " ..
    "straight back (you may hear a short sound blip). Then: /qprobe yes|no|partial B11",
  run = function()
    for _, name in ipairs(CVARS) do
      local ok, orig = pcall(P.GetCV, name)
      if not ok or isSecret(orig) or orig == nil then
        P.Fact("B11", name, "missing or unreadable (" .. P.Str(orig) .. ")")
      else
        local mine = P.db.savedCVars[name] == nil
        if mine then P.db.savedCVars[name] = orig end -- crash safety
        local alt = (orig == "0") and "1" or "0"
        local okSet, err = pcall(P.SetCV, name, alt)
        local changed = P.Try(P.GetCV, name)
        local okBack = pcall(P.SetCV, name, orig)
        local back = P.Try(P.GetCV, name)
        if okBack and mine then P.db.savedCVars[name] = nil end
        P.Fact("B11", name, "was " .. P.Str(orig) .. "; set " .. alt .. ": " .. (okSet and "ok" or P.Str(err)) ..
          ", read " .. changed .. "; restored: " .. back)
      end
    end
  end,
})

---------------------------------------------------------------------------
-- B12: secure snippet (Fishing Buddy's pattern). No game action at all.
---------------------------------------------------------------------------

local SNIPPET = [[
  local n = (self:GetAttribute("pagle-count") or 0) + 1
  self:SetAttribute("pagle-count", n)
  self:ClearBindings()
]]

add({
  id = "B12", rid = "B12", label = "B12 snippet",
  help = "Click, then press the probe key ONCE. Nothing happens in the game: the key runs a secure snippet " ..
    "that counts the press and removes the key binding. The report shows whether it ran. " ..
    "Then: /qprobe yes|no|partial B12",
  arm = function()
    if not P.snipWrapped then
      local ok, err = pcall(SecureHandlerWrapScript, P.snip, "OnClick", P.header, SNIPPET)
      P.snipWrapped = ok
      P.Fact("B12", "SecureHandlerWrapScript", ok and "ok" or ("error: " .. P.Str(err)))
      if not ok then return false end
    end
    P.Note("B12", "snippet count before: " .. P.Str(P.snip:GetAttribute("pagle-count")))
  end,
  bind = function() return "click", P.snip:GetName(), P.snip end,
})

P.snip:SetScript("PostClick", P.Safe("B12 PostClick", function()
  P.After(0.3, function()
    P.Note("B12", "after press: snippet count " .. P.Str(P.snip:GetAttribute("pagle-count")) ..
      ", probe key now bound to '" .. P.Try(GetBindingAction, P.db.key, true) .. "' (empty = snippet cleared it)")
  end)
end))

---------------------------------------------------------------------------
-- B13: pet summon from addon code, on this click
---------------------------------------------------------------------------

add({
  id = "B13", rid = "B13", label = "B13 pet",
  help = "Click ONCE out of combat: the probe calls C_PetJournal.SummonPetByGUID for your first pet. " ..
    "Did a pet appear (or get dismissed)? A 'blocked' message is also a result. " ..
    "Then: /qprobe yes|no|partial B13",
  run = function()
    local pj = C_PetJournal
    P.Fact("B13", "C_PetJournal", pj and "present" or "missing")
    if not pj then return end
    P.Fact("B13", "GetNumPets", P.Try(pj.GetNumPets))
    local guid
    local okN, n = pcall(pj.GetNumPets)
    if okN and type(n) == "number" then
      for i = 1, math.min(n, 300) do
        local ok, petID, _, owned = pcall(pj.GetPetInfoByIndex, i)
        if ok and petID and owned then
          guid = petID
          break
        end
      end
    end
    if not guid then
      P.Note("B13", "no owned pet found in the Pet Journal")
      return
    end
    P.Note("B13", "SummonPetByGUID(" .. P.Str(guid) .. "): " .. P.Try(pj.SummonPetByGUID, guid))
    P.After(1.5, function()
      P.Note("B13", "summoned pet now: " .. P.Try(pj.GetSummonedPetGUID))
    end)
  end,
})

---------------------------------------------------------------------------
-- B14: beta hygiene
---------------------------------------------------------------------------

add({
  id = "B14", rid = "B14", label = "B14 hygiene",
  help = "Click once. Then 1) type /reload and run /qprobe report: are your results still there? " ..
    "2) Copy the report, quit the game fully, start it, log in, /qprobe report again: still there? " ..
    "3) Optional: type /run ReloadUI() in chat: does the UI reload, or is it blocked? " ..
    "Then: /qprobe yes|no|partial B14 [what happened]",
  run = function() P.RefreshFacts() end,
})

-- Facts that are re-read every time the report is built.
function P.RefreshFacts()
  local db = P.db
  P.Fact("B1", "PLAYER_SOFT_INTERACT_CHANGED registered", P.eventOK.PLAYER_SOFT_INTERACT_CHANGED and "yes" or
    ("no: " .. P.Str(P.eventFailed.PLAYER_SOFT_INTERACT_CHANGED)))
  P.Fact("B3", "GLOBAL_MOUSE_DOWN registered / fired this session",
    (P.eventOK.GLOBAL_MOUSE_DOWN and "yes" or "no") .. " / " .. P.Str(P.eventCount.GLOBAL_MOUSE_DOWN or 0))
  P.Fact("B3", "GLOBAL_MOUSE_UP registered / fired this session",
    (P.eventOK.GLOBAL_MOUSE_UP and "yes" or "no") .. " / " .. P.Str(P.eventCount.GLOBAL_MOUSE_UP or 0))
  local secrets = {}
  for k, v in pairs(db.secretEvents) do secrets[#secrets + 1] = k .. " x" .. v end
  table.sort(secrets)
  P.Fact("B5", "event payloads with secret values", #secrets > 0 and table.concat(secrets, "; ") or "none seen")
  P.Fact("B5", "secret values met by the probe (all time)", db.secretHits or 0)
  P.Fact("B14", "saved data found at this login", P.svHadData and "yes" or "no")
  P.Fact("B14", "last logout/reload written", db.lastLogout and date("%Y-%m-%d %H:%M:%S", db.lastLogout) or "never")
  P.Fact("B14", "ADDON_RESTRICTION_STATE_CHANGED registered / fired this session",
    (P.eventOK.ADDON_RESTRICTION_STATE_CHANGED and "yes" or ("no: " .. P.Str(P.eventFailed.ADDON_RESTRICTION_STATE_CHANGED))) ..
    " / " .. P.Str(P.eventCount.ADDON_RESTRICTION_STATE_CHANGED or 0))
  P.Fact("B14", "logins recorded", #db.sessions)
end

---------------------------------------------------------------------------
-- Observers (log only)
---------------------------------------------------------------------------

-- Every press of the probe key that reaches the secure button.
-- Observation only: notice when the probe key goes down while a test is
-- armed, so the log can tie a cast or a reel to a key press. It never acts.
local watcher = CreateFrame("Frame")
local wasDown = false
watcher:SetScript("OnUpdate", function()
  local ok, err = pcall(function()
    if not P.armed then
      wasDown = false
      return
    end
    local down = P.KeyHeld()
    if down and not wasDown then
      P.lastKeyDown = GetTime()
      P.Note(nil, "probe key pressed (key does '" .. P.boundTo .. "'" ..
        (P.fishing and (", fishing, soft target " .. P.Try(UnitGUID, "softinteract")) or "") .. ")")
    end
    wasDown = down
  end)
  if not ok then
    watcher:SetScript("OnUpdate", nil)
    P.ProbeError("key watcher", err)
  end
end)

local function keyPressedWithin(sec)
  return (P.KeyHeld() or (P.lastKeyDown ~= nil and GetTime() - P.lastKeyDown < sec)) and true or false
end

-- Every press of the probe key that reaches the secure button.
P.btn:SetScript("PostClick", P.Safe("button PostClick", function(self, button, down)
  local rid = P.armedRid
  P.lastClick = { t = GetTime(), rid = rid }
  P.Note(rid, "secure button fired (type " .. P.Str(self:GetAttribute("type")) .. ", " .. P.Str(button) ..
    ", down " .. P.Str(down) .. ", in combat " .. P.Str(InCombatLockdown()) .. ")")
  if down == false then return end
  P.After(1.5, function()
    local text = "1.5 s later: slot 16 = " .. P.Str(GetInventoryItemID("player", 16))
    if rid == "B4" then text = text .. "; " .. P.EnchantText() end
    if rid == "B6" and P.armedItem then text = text .. "; count " .. P.CountText(P.armedItem) end
    P.Note(rid, text)
  end)
end))

P.On("UNIT_SPELLCAST_SENT", function(_, _, _, _, spellID)
  if not P.armed then return end
  local byKey = keyPressedWithin(0.5)
  P.Note(nil, "SENT " .. P.SpellText(spellID) .. ", probe key just pressed " .. P.Str(byKey))
  if byKey and P.IsFishingSpell(spellID) then
    P.Fact(P.armedRid, "Fishing cast sent by the probe key", "yes")
  end
end)

P.On("UNIT_SPELLCAST_CHANNEL_START", function(_, _, _, spellID)
  local fishing = P.IsFishingSpell(spellID)
  P.Note(nil, "CHANNEL_START " .. P.SpellText(spellID) .. ", fishing " .. P.Str(fishing) ..
    ", probe key held " .. P.Str(P.KeyHeld()))
  -- Spell unreadable (secret): if B1/B2 just cast with the probe key, assume Fishing.
  if fishing == nil and (P.armedRid == "B1" or P.armedRid == "B2") and keyPressedWithin(1.0) then
    fishing = true
    P.Note(nil, "spell ID unreadable; assuming this channel is Fishing (cast by the probe key)")
  end
  if not fishing then return end
  P.fishing = true
  P.Fact("B2", "Fishing spell seen in cast events", P.SpellText(spellID))
  local rid = P.armedRid
  if rid and P.lastClick and GetTime() - P.lastClick.t < 1.5 then
    P.Fact(rid, "Fishing cast started right after the secure button fired", "yes")
  end
  P.After(1, function()
    if P.fishing then P.Note(nil, "1 s into cast: UnitGUID('softinteract') = " .. P.Try(UnitGUID, "softinteract")) end
  end)
  P.After(0.5, function() P.SecretSnapshot("auto, at cast") end)
  P.Refresh()
end)

P.On("UNIT_SPELLCAST_CHANNEL_STOP", function(_, _, _, spellID)
  if not P.fishing then return end
  P.fishing = false
  local pressed = keyPressedWithin(1.0)
  P.Note(nil, "CHANNEL_STOP " .. P.SpellText(spellID) .. ", probe key pressed in the last second " ..
    P.Str(pressed) .. ", key was '" .. P.boundTo .. "'")
  local rid = P.armedRid
  if rid and pressed and P.boundTo:find("INTERACT") then
    P.Fact(rid, "bobber interaction fired by the probe key (" .. P.boundTo .. ")", "yes")
  end
  P.Refresh()
end)

for _, e in ipairs({ "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
  P.On(e, function(event, _, _, spellID)
    if P.armed or P.fishing then P.Note(nil, event:sub(16) .. " " .. P.SpellText(spellID)) end
  end)
end

P.On("PLAYER_SOFT_INTERACT_CHANGED", function(_, _, new)
  if isSecret(new) then
    P.Note(P.armedRid or "B1", "soft-interact target: <secret>")
    return
  end
  if type(new) ~= "string" then return end
  local kind, _, _, _, _, objID = strsplit("-", new)
  if kind == "GameObject" and P.fishing then
    P.Fact("B1", "GameObject soft-targeted while fishing", "yes, object ID " .. P.Str(objID) .. " (" .. new .. ")")
  end
  if P.armed or P.fishing then
    P.Note(P.armedRid or "B1", "soft-interact target: '" .. P.Str(new) .. "'" .. (P.fishing and " (fishing)" or ""))
  end
end)

for _, e in ipairs({ "LOOT_READY", "LOOT_OPENED", "LOOT_CLOSED" }) do
  P.On(e, function(event, ...)
    if not P.armed then return end
    P.Note(nil, event .. " (" .. P.Args(...) .. "), IsFishingLoot " .. P.Try(IsFishingLoot))
    local okF, fishLoot = pcall(IsFishingLoot)
    if event == "LOOT_OPENED" and okF and not isSecret(fishLoot) and fishLoot and keyPressedWithin(2) then
      P.Fact(P.armedRid, "fishing loot opened within 2 s of a probe key press", "yes")
    end
  end)
end

for _, e in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "EQUIPMENT_SWAP_FINISHED", "EQUIPMENT_SETS_CHANGED" }) do
  P.On(e, function(event, ...)
    local rid = P.armedRid or ((event ~= "PLAYER_EQUIPMENT_CHANGED") and "B9") or nil
    if InCombatLockdown() then rid = "B10" end
    if rid then P.Note(rid, event .. " (" .. P.Args(...) .. "), in combat " .. P.Str(InCombatLockdown())) end
  end)
end

P.On("UNIT_INVENTORY_CHANGED", function()
  if P.armedRid == "B4" then P.Note("B4", "UNIT_INVENTORY_CHANGED; " .. P.EnchantText()) end
end)

P.On("COMPANION_UPDATE", function(_, ...)
  P.Note("B13", "COMPANION_UPDATE (" .. P.Args(...) .. ")")
end)

-- Blocked and forbidden actions, and red error messages.
for _, e in ipairs({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "MACRO_ACTION_BLOCKED", "MACRO_ACTION_FORBIDDEN" }) do
  P.On(e, function(event, ...)
    local line = date("%H:%M:%S") .. " " .. event .. " (" .. P.Args(...) .. ") while " .. P.Str(P.armedRid or "nothing armed")
    P.Push(P.db.errors, line, 50)
    P.Note(nil, event .. " (" .. P.Args(...) .. ")")
    P.Print(event .. ": " .. P.Args(...))
  end)
end

P.On("UI_ERROR_MESSAGE", function(_, ...)
  if P.armed then P.Note(nil, "UI_ERROR_MESSAGE (" .. P.Args(...) .. ")") end
end)

P.On("ADDON_RESTRICTION_STATE_CHANGED", function(_, ...)
  P.Note("B14", "ADDON_RESTRICTION_STATE_CHANGED (" .. P.Args(...) .. "), in combat " .. P.Str(InCombatLockdown()))
end)

-- Combat: drop everything. PLAYER_REGEN_DISABLED fires just before the combat
-- lockdown starts, so bindings can still be cleared here.
P.On("PLAYER_REGEN_DISABLED", function()
  if P.armed and P.armed.keepInCombat then
    P.Note("B10", "entered combat (green button stays)")
    return
  end
  if P.armed then P.Disarm("entered combat") end
  pcall(ClearOverrideBindings, P.mouseOwner)
end)

P.On("PLAYER_REGEN_ENABLED", function()
  if P.armedRid == "B10" then P.Note("B10", "left combat") end
end)

---------------------------------------------------------------------------
-- Loading, saved data, logout (B14)
---------------------------------------------------------------------------

P.On("ADDON_LOADED", function(_, name)
  if name ~= ADDON then return end
  if type(PagleQoLProbeDB) == "table" and PagleQoLProbeDB.schema == 1 then
    P.svHadData = true
    P.db = PagleQoLProbeDB
  else
    P.svHadData = false
    PagleQoLProbeDB = P.db
  end
  local fresh = { key = P.KEY_DEFAULT, results = {}, log = {}, errors = {}, sessions = {},
    savedCVars = {}, config = {}, secretEvents = {} }
  for k, v in pairs(fresh) do
    if P.db[k] == nil then P.db[k] = v end
  end
end)

local entered = false
P.On("PLAYER_ENTERING_WORLD", function(_, isInitialLogin, isReloadingUi)
  P.fishing = false
  if entered then return end
  entered = true
  local db = P.db
  table.insert(db.sessions, { t = time(), initial = isInitialLogin, reload = isReloadingUi, hadData = P.svHadData })
  P.Note("B14", "login: initial " .. P.Str(isInitialLogin) .. ", reload " .. P.Str(isReloadingUi) ..
    ", saved data found " .. P.Str(P.svHadData) .. " (last written " ..
    (db.lastLogout and date("%Y-%m-%d %H:%M:%S", db.lastLogout) or "never") .. ")")
  P.RestoreCVars() -- leftovers from a crash, if any
  P.Print("loaded. Type /qprobe for the test panel. Probe key: " .. P.db.key .. ".")
end)

P.On("PLAYER_LOGOUT", function()
  pcall(P.RestoreCVars)
  P.db.lastLogout = time()
end)
