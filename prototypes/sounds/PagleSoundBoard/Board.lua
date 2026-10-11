-- PagleSoundBoard / Board.lua  (PROTOTYPE, throwaway)
-- Question (wow-fish "Prototype Pagle's sounds"): what do Pagle's Announcements
-- sound like, heard in the real game mix over a real fishing session?
-- The board plays candidates on demand; "Fish with it" plays them on your own
-- Catches at the densities the Catch feedback simulator predicted. It never
-- casts, loots or presses anything: it only listens to events and plays sounds.

local ADDON, B = ...

local ROOT = "Interface\\AddOns\\" .. ADDON .. "\\sounds\\"
local CHANNELS = { "SFX", "Master", "Ambience", "Dialog" }
-- Interruptions per Catch, from the Catch feedback simulator (~160 Casts/hour).
local DENSITIES = {
  { label = "Day one (1 in 6)", n = 6 },
  { label = "Mid-game (1 in 23)", n = 23 },
  { label = "Level 59 (1 in 160)", n = 160 },
}
local BANNER_SHARE = 8 -- 1 in 8 of the sounds in Fish mode is a banner

local db
local setByKey = {}
for _, s in ipairs(B.SETS) do setByKey[s.key] = s end

local function say(msg) print("|cff66ccff[Sound board]|r " .. msg) end

---------------------------------------------------------------------------
-- Playing
---------------------------------------------------------------------------

local rotation = {} -- candidate -> next index
local lastPlayed = "nothing yet"

local function playOne(src, channel)
  if src.kit then
    return PlaySound(src.kit, channel)
  end
  local f = src.file
  if type(f) == "function" then f = f() end
  if f then return PlaySoundFile(f, channel) end
  return PlaySoundFile(ROOT .. src.path:gsub("/", "\\"), channel)
end

local function sources(c)
  if c.layers then return c.layers end
  if c.rotate then
    local i = rotation[c] or 1
    rotation[c] = i % #c.rotate + 1
    return { { path = c.rotate[i] } }
  end
  return { c }
end

-- Plays a candidate; returns whether its first layer will play.
local function play(c, why)
  local first
  for _, src in ipairs(sources(c)) do
    if (src.at or 0) > 0 then
      C_Timer.After(src.at, function() playOne(src, db.channel) end)
    else
      local willPlay = playOne(src, db.channel)
      if first == nil then first = willPlay end
    end
  end
  lastPlayed = (why or "") .. c.name
  if not first then say("|cffff6666did not play|r: " .. lastPlayed .. " (missing file, or sound/channel muted?)") end
  return first
end

local function pickIndex(set, weight)
  return db.picks[set.key .. "." .. weight] or 1
end

local function current(set, weight)
  local list = set[weight]
  return list[(pickIndex(set, weight) - 1) % #list + 1]
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------

local W, COLW = 820, 232
local panel = CreateFrame("Frame", "PagleSoundBoardFrame", UIParent)
panel:SetSize(W, 470)
panel:SetPoint("CENTER")
panel:SetFrameStrata("DIALOG")
panel:SetClampedToScreen(true)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:Hide()
local bg = panel:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0, 0, 0, 0.88)
local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -10)
title:SetText("Pagle Sound Board (prototype)")
CreateFrame("Button", nil, panel, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -2, -2)

local function button(parent, w, text, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, 22)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

local function label(text, template)
  local fs = panel:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
  fs:SetText(text)
  fs:SetJustifyH("LEFT")
  return fs
end

local refreshers = {}
local function refresh()
  for _, r in ipairs(refreshers) do r() end
end

-- Top row: channel and volumes.
local channelBtn = button(panel, 150, "", function()
  for i, c in ipairs(CHANNELS) do
    if c == db.channel then db.channel = CHANNELS[i % #CHANNELS + 1] break end
  end
  refresh()
end)
channelBtn:SetPoint("TOPLEFT", 14, -40)
local volumes = label("", "GameFontHighlightSmall")
volumes:SetPoint("LEFT", channelBtn, "RIGHT", 10, 0)
refreshers[#refreshers + 1] = function()
  channelBtn:SetText("Channel: " .. db.channel)
  local function v(cvar) return math.floor((tonumber(GetCVar(cvar)) or 0) * 100 + 0.5) .. "%" end
  volumes:SetText(("Master %s  SFX %s  Music %s  Ambience %s  Dialog %s   SFX on: %s"):format(
    v("Sound_MasterVolume"), v("Sound_SFXVolume"), v("Sound_MusicVolume"), v("Sound_AmbienceVolume"),
    v("Sound_DialogVolume"), GetCVar("Sound_EnableSFX") == "1" and "yes" or "NO"))
end

-- Grid: one row per weight, one column per set.
for col, set in ipairs(B.SETS) do
  local head = label(set.label, "GameFontNormal")
  head:SetPoint("TOPLEFT", 110 + (col - 1) * COLW, -80)
end
for row, wt in ipairs(B.WEIGHTS) do
  local y = -104 - (row - 1) * 32
  label(wt.label, "GameFontNormal"):SetPoint("TOPLEFT", 14, y - 4)
  for col, set in ipairs(B.SETS) do
    local x = 110 + (col - 1) * COLW
    local playBtn = button(panel, 168, "", function() play(current(set, wt.key), set.label .. " / ") end)
    local function step(d)
      db.picks[set.key .. "." .. wt.key] = (pickIndex(set, wt.key) - 1 + d) % #set[wt.key] + 1
      refresh()
      play(current(set, wt.key), set.label .. " / ")
    end
    local prev = button(panel, 26, "<", function() step(-1) end)
    prev:SetPoint("TOPLEFT", x, y)
    playBtn:SetPoint("LEFT", prev, "RIGHT", 2, 0)
    button(panel, 26, ">", function() step(1) end):SetPoint("LEFT", playBtn, "RIGHT", 2, 0)
    refreshers[#refreshers + 1] = function()
      local i = (pickIndex(set, wt.key) - 1) % #set[wt.key] + 1
      playBtn:SetText(i .. "/" .. #set[wt.key] .. "  " .. current(set, wt.key).name)
    end
  end
end

-- References and tools.
local refY = -104 - #B.WEIGHTS * 32 - 8
local lastRef
for _, r in ipairs(B.REFERENCES) do
  local b = button(panel, 150, r.name, function() play(r, "") end)
  if lastRef then b:SetPoint("LEFT", lastRef, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", 110, refY) end
  lastRef = b
end
local checkBtn = button(panel, 150, "Check all files", function() B.Check() end)
checkBtn:SetPoint("LEFT", lastRef, "RIGHT", 6, 0)
local reportBtn = button(panel, 110, "Report", function() B.ShowReport() end)
reportBtn:SetPoint("LEFT", checkBtn, "RIGHT", 6, 0)

-- Fish with it.
local fishY = refY - 44
label("Fish with it", "GameFontNormal"):SetPoint("TOPLEFT", 14, fishY - 4)
local fishModes = { "off" }
for _, s in ipairs(B.SETS) do fishModes[#fishModes + 1] = s.key end
local fishBtn = button(panel, 200, "", function()
  for i, k in ipairs(fishModes) do
    if k == db.fishSet then db.fishSet = fishModes[i % #fishModes + 1] break end
  end
  refresh()
end)
fishBtn:SetPoint("TOPLEFT", 110, fishY)
local densityBtn = button(panel, 170, "", function()
  db.density = db.density % #DENSITIES + 1
  refresh()
end)
densityBtn:SetPoint("LEFT", fishBtn, "RIGHT", 6, 0)
local recastBtn = button(panel, 150, "", function()
  db.recastCue = not db.recastCue
  refresh()
end)
recastBtn:SetPoint("LEFT", densityBtn, "RIGHT", 6, 0)
local resetBtn = button(panel, 90, "Reset count", function()
  B.stats = { catches = 0, toasts = 0, banners = 0, cues = 0, started = time() }
  refresh()
end)
resetBtn:SetPoint("LEFT", recastBtn, "RIGHT", 6, 0)

local fishStatus = label("", "GameFontHighlightSmall")
fishStatus:SetPoint("TOPLEFT", 110, fishY - 28)
fishStatus:SetPoint("RIGHT", panel, "RIGHT", -14, 0)

B.stats = { catches = 0, toasts = 0, banners = 0, cues = 0, started = time() }
refreshers[#refreshers + 1] = function()
  local s = setByKey[db.fishSet]
  fishBtn:SetText("Sounds: " .. (s and s.label or "off"))
  densityBtn:SetText(DENSITIES[db.density].label)
  recastBtn:SetText("Recast cue: " .. (db.recastCue and "on" or "off"))
  local st = B.stats
  local mins = math.max(1, math.floor((time() - st.started) / 60))
  fishStatus:SetText(("Catches %d   toasts %d   banners %d   recast cues %d   over %d min   last: %s"):format(
    st.catches, st.toasts, st.banners, st.cues, mins, lastPlayed))
end

local help = label("", "GameFontHighlightSmall")
help:SetPoint("TOPLEFT", 14, fishY - 56)
help:SetPoint("BOTTOMRIGHT", -14, 12)
help:SetJustifyV("TOP")
help:SetText(
  "Click a sound to play it; < > pick another candidate. Fish mode and the recast cue use the picked candidates.\n" ..
  "Fish with it: on your Catches, plays the picked toast at the chosen density (1 in " .. BANNER_SHARE ..
  " of them a banner instead). Nothing plays in combat.\n" ..
  "Recast cue: plays the picked cue if no new Cast starts within 2 s of Fishing ending (the QoL recast reminder).\n" ..
  "Ref buttons are the game's own sounds, to judge masking and loudness against. Legends are click-only.\n\n" ..
  "Whenever a sound pleases or grates: /psb note <what you felt>.  Done: Report, Select all, copy, paste on the issue.")

---------------------------------------------------------------------------
-- Fish mode and recast cue
---------------------------------------------------------------------------

local lastLoot, castSerial = 0, 0

local function isFishing(spellID)
  if spellID == nil then return false end
  local ok, known = pcall(function() return B.FISHING_IDS[spellID] end)
  if ok and known then return true end
  local ok2, name = pcall(C_Spell.GetSpellName, spellID)
  return ok2 and name ~= nil and name == (PROFESSIONS_FISHING or "Fishing")
end

local function onCatch()
  local set = setByKey[db.fishSet]
  if not set or InCombatLockdown() then return end
  if GetTime() - lastLoot < 1.5 then return end -- one loot window, not one per event
  lastLoot = GetTime()
  B.stats.catches = B.stats.catches + 1
  if math.random(DENSITIES[db.density].n) == 1 then
    local banner = math.random(BANNER_SHARE) == 1
    local w = banner and "banner" or "toast"
    play(current(set, w), "auto " .. w .. ": " .. set.label .. " / ")
    if banner then B.stats.banners = B.stats.banners + 1 else B.stats.toasts = B.stats.toasts + 1 end
  end
  refresh()
end

local function onFishingEnded()
  if not db.recastCue then return end
  castSerial = castSerial + 1
  local mine = castSerial
  C_Timer.After(2, function()
    if mine ~= castSerial or InCombatLockdown() then return end
    local set = setByKey[db.fishSet] or setByKey.own
    play(current(set, "recast"), "recast cue: " .. set.label .. " / ")
    B.stats.cues = B.stats.cues + 1
    refresh()
  end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("LOOT_READY")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
events:SetScript("OnEvent", function(_, event, a1, _, a3)
  if event == "ADDON_LOADED" and a1 == ADDON then
    PagleSoundBoardDB = PagleSoundBoardDB or {}
    db = PagleSoundBoardDB
    db.channel = db.channel or "SFX"
    db.fishSet = db.fishSet or "off"
    db.density = db.density or 1
    db.picks = db.picks or {}
    db.notes = db.notes or {}
    db.checks = db.checks or {}
    refresh()
    say("loaded. Type /psb.")
  elseif not db then
    return
  elseif event == "LOOT_READY" then
    if IsFishingLoot() then onCatch() end
  elseif event == "UNIT_SPELLCAST_CHANNEL_START" and isFishing(a3) then
    castSerial = castSerial + 1 -- a new Cast cancels a pending cue
  elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" and isFishing(a3) then
    onFishingEnded()
  end
end)

---------------------------------------------------------------------------
-- File check: plays every candidate on Master and stops it at once, to learn
-- which files exist on this client. You may hear short blips.
---------------------------------------------------------------------------

function B.Check()
  local missing, total = {}, 0
  local function try(where, src)
    total = total + 1
    local ok, willPlay, handle = pcall(playOne, src, "Master")
    if ok and handle then StopSound(handle) end
    if not (ok and willPlay) then missing[#missing + 1] = where end
  end
  for _, set in ipairs(B.SETS) do
    for _, wt in ipairs(B.WEIGHTS) do
      for _, c in ipairs(set[wt.key]) do
        local where = set.key .. "/" .. wt.key .. "/" .. c.name
        if c.layers then
          for _, l in ipairs(c.layers) do try(where, l) end
        elseif c.rotate then
          for _, p in ipairs(c.rotate) do try(where, { path = p }) end
        else
          try(where, c)
        end
      end
    end
  end
  for _, r in ipairs(B.REFERENCES) do try("reference/" .. r.name, r) end
  local summary = ("%d of %d play; missing: %s"):format(total - #missing, total,
    #missing == 0 and "none" or table.concat(missing, ", "))
  db.checks[#db.checks + 1] = date("%Y-%m-%d %H:%M") .. "  " .. summary
  say(summary .. (GetCVar("Sound_EnableAllSound") == "0" and "  (all sound is OFF, so nothing could play)" or ""))
end

---------------------------------------------------------------------------
-- Report window
---------------------------------------------------------------------------

local report = CreateFrame("Frame", "PagleSoundBoardReport", UIParent)
report:SetSize(720, 480)
report:SetPoint("CENTER")
report:SetFrameStrata("DIALOG")
report:SetMovable(true)
report:EnableMouse(true)
report:RegisterForDrag("LeftButton")
report:SetScript("OnDragStart", report.StartMoving)
report:SetScript("OnDragStop", report.StopMovingOrSizing)
report:Hide()
local rbg = report:CreateTexture(nil, "BACKGROUND")
rbg:SetAllPoints()
rbg:SetColorTexture(0, 0, 0, 0.92)
CreateFrame("Button", nil, report, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -2, -2)
local scroll = CreateFrame("ScrollFrame", "PagleSoundBoardReportScroll", report, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 12, -30)
scroll:SetPoint("BOTTOMRIGHT", -32, 44)
local edit = CreateFrame("EditBox", nil, scroll)
edit:SetMultiLine(true)
edit:SetAutoFocus(false)
edit:SetMaxLetters(0)
edit:SetFontObject(ChatFontNormal)
edit:SetWidth(660)
edit:SetHeight(400)
edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
scroll:SetScrollChild(edit)
button(report, 140, "Select all", function()
  edit:SetFocus()
  edit:HighlightText()
end):SetPoint("BOTTOMLEFT", 12, 12)

local function buildReport()
  local out = {}
  local function add(s) out[#out + 1] = s end
  local version, build = GetBuildInfo()
  add("Pagle Sound Board report, " .. date("%Y-%m-%d %H:%M") .. ", client " .. version .. " build " .. build)
  add("Channel: " .. db.channel .. "   " .. volumes:GetText())
  add("")
  add("Picked candidates:")
  for _, set in ipairs(B.SETS) do
    local parts = {}
    for _, wt in ipairs(B.WEIGHTS) do parts[#parts + 1] = wt.label .. " = " .. current(set, wt.key).name end
    add("  " .. set.label .. ": " .. table.concat(parts, "; "))
  end
  add("")
  local st = B.stats
  add(("Fish mode: %s, %s; this session %d Catches, %d toasts, %d banners, %d recast cues over %d min"):format(
    setByKey[db.fishSet] and setByKey[db.fishSet].label or "off", DENSITIES[db.density].label,
    st.catches, st.toasts, st.banners, st.cues, math.floor((time() - st.started) / 60)))
  add("")
  add("File checks:")
  for _, c in ipairs(db.checks) do add("  " .. c) end
  if #db.checks == 0 then add("  (none run; click Check all files)") end
  add("")
  add("Notes:")
  for _, n in ipairs(db.notes) do add("  " .. n) end
  if #db.notes == 0 then add("  (none; /psb note <text>)") end
  return table.concat(out, "\n")
end

function B.ShowReport()
  refresh()
  edit:SetText(buildReport())
  edit:SetCursorPosition(0)
  report:Show()
end

---------------------------------------------------------------------------
-- /psb
---------------------------------------------------------------------------

SLASH_PAGLESOUNDBOARD1 = "/psb"
SlashCmdList.PAGLESOUNDBOARD = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = cmd:lower()
  if cmd == "note" and rest ~= "" then
    local entry = ("%s  [%s, %s]  %s"):format(date("%H:%M:%S"), setByKey[db.fishSet] and db.fishSet or "board",
      "last: " .. lastPlayed, rest)
    db.notes[#db.notes + 1] = entry
    say("noted: " .. rest)
  elseif cmd == "report" then
    B.ShowReport()
  elseif cmd == "check" then
    B.Check()
  else
    refresh()
    panel:SetShown(not panel:IsShown())
    say("/psb (panel), /psb note <text>, /psb report, /psb check")
  end
end
