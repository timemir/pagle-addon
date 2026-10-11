-- PagleQoLProbe / UI.lua
-- The test panel, the copyable report window and the /qprobe command.
-- Nothing here is secure: the panel can open and close in combat, and its
-- buttons refuse to do anything in combat.

local _, P = ...

local function plainFrame(name, width, height, titleText)
  local f = CreateFrame("Frame", name, UIParent)
  f:SetSize(width, height)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.88)
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -10)
  title:SetText(titleText)
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -2, -2)
  f:Hide()
  return f
end

---------------------------------------------------------------------------
-- Test panel
---------------------------------------------------------------------------

local COLS, BW, BH, GAP = 4, 130, 22, 4
local panel = plainFrame("PagleQoLProbeFrame", 14 * 2 + COLS * BW + (COLS - 1) * GAP, 500, "Pagle QoL Probe")

local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
status:SetPoint("TOPLEFT", 14, -38)
status:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
status:SetJustifyH("LEFT")

local buttons = {}
for _, t in ipairs(P.testList) do
  buttons[#buttons + 1] = { label = t.label, click = function() P.Press(t.id) end }
end
buttons[#buttons + 1] = { label = "Disarm", click = function()
  if not P.Refuse() then P.Disarm("Disarm button") end
end }
buttons[#buttons + 1] = { label = "Report", click = function() P.ShowReport() end }

local rows = math.ceil(#buttons / COLS)
for i, def in ipairs(buttons) do
  local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  b:SetSize(BW, BH)
  local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
  b:SetPoint("TOPLEFT", 14 + col * (BW + GAP), -80 - row * (BH + GAP))
  b:SetText(def.label)
  b:SetScript("OnClick", P.Safe("panel button " .. def.label, def.click))
end

local help = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
help:SetPoint("TOPLEFT", 14, -80 - rows * (BH + GAP) - 10)
help:SetPoint("BOTTOMRIGHT", -14, 12)
help:SetJustifyH("LEFT")
help:SetJustifyV("TOP")
help:SetText("Click a test button. Its steps appear here and in chat.\n\n" ..
  "Buttons B1, B2, B3, B4 (both), B6, B8, B9 /equipset key and B12 arm the probe key (" .. P.KEY_DEFAULT ..
  " unless you changed it). Other buttons do their one thing on the click.\n\n" ..
  "Answer each item with /qprobe yes|no|partial B# [note]. Then click Report.")

function P.UpdateStatus()
  status:SetText("Probe key: " .. P.db.key .. "    Armed: " .. (P.armed and P.armed.label or "nothing") ..
    "\nKey does: " .. P.boundTo .. "    Fishing: " .. (P.fishing and "yes" or "no"))
end

function P.ShowHelp(t)
  help:SetText(t.rid .. " - " .. P.TITLES[t.rid] .. "\n\n" .. t.help)
  P.Print(t.label .. ": " .. t.help)
end

function P.ShowPanel()
  P.UpdateStatus()
  panel:Show()
end

---------------------------------------------------------------------------
-- Report window: a scrollable multi-line EditBox you can copy from
---------------------------------------------------------------------------

local report = plainFrame("PagleQoLProbeReport", 720, 500, "QoL probe report: Select all, Ctrl+C, paste on GitHub")

local scroll = CreateFrame("ScrollFrame", "PagleQoLProbeReportScroll", report, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 12, -36)
scroll:SetPoint("BOTTOMRIGHT", -32, 44)

local edit = CreateFrame("EditBox", "PagleQoLProbeReportText", scroll)
edit:SetMultiLine(true)
edit:SetAutoFocus(false)
edit:SetMaxLetters(0)
edit:SetFontObject(ChatFontNormal)
edit:SetWidth(660)
edit:SetHeight(400)
edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
scroll:SetScrollChild(edit)

local selectAll = CreateFrame("Button", nil, report, "UIPanelButtonTemplate")
selectAll:SetSize(140, 22)
selectAll:SetPoint("BOTTOMLEFT", 12, 12)
selectAll:SetText("Select all")
selectAll:SetScript("OnClick", function()
  edit:SetFocus()
  edit:HighlightText()
end)

local refresh = CreateFrame("Button", nil, report, "UIPanelButtonTemplate")
refresh:SetSize(140, 22)
refresh:SetPoint("LEFT", selectAll, "RIGHT", 8, 0)
refresh:SetText("Refresh")
refresh:SetScript("OnClick", function() P.ShowReport() end)

local hint = report:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hint:SetPoint("LEFT", refresh, "RIGHT", 12, 0)
hint:SetText("Also saved in WTF\\...\\SavedVariables\\PagleQoLProbe.lua")

function P.ShowReport()
  local ok, text = pcall(P.BuildReport)
  if not ok then
    P.ProbeError("report", text)
    text = "Report failed: " .. P.Str(text)
  end
  edit:SetText(text)
  edit:SetCursorPosition(0)
  scroll:SetVerticalScroll(0)
  report:Show()
end

---------------------------------------------------------------------------
-- /qprobe
---------------------------------------------------------------------------

local VERDICT = { yes = "works", no = "doesnt", partial = "partial" }

function P.PrintHelp()
  P.Print("commands:")
  print("  /qprobe - this help and the test panel")
  print("  /qprobe report - copyable report")
  print("  /qprobe yes|no|partial B# [note] - record your answer, e.g. /qprobe no B1 key did nothing")
  print("  /qprobe <test> - same as the panel button, e.g. /qprobe b4i")
  print("  /qprobe key <KEY> - change the probe key (now " .. P.db.key .. ")")
  print("  /qprobe lure|clam|toy|weapon <item> - choose an item (shift-click it into the chat line)")
  print("  /qprobe off - disarm    /qprobe restore - put changed settings back")
  P.Print("checklist:")
  for _, id in ipairs(P.RESULT_IDS) do
    local r = P.db.results[id]
    local v = (r and r.verdict) and P.VERDICT_TEXT[r.verdict] or "not answered"
    print("  " .. id .. " " .. P.TITLES[id] .. ": " .. v)
  end
end

function P.Slash(msg)
  local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
  cmd = (cmd or ""):lower()
  rest = rest or ""
  if cmd == "" or cmd == "help" then
    P.PrintHelp()
    P.ShowPanel()
  elseif cmd == "report" then
    P.ShowReport()
  elseif VERDICT[cmd] then
    local id, note = rest:match("^(%S+)%s*(.-)$")
    id = id and id:upper()
    if not id or not P.TITLES[id] then
      P.Print("Usage: /qprobe yes|no|partial B1..B14 [note]")
      return
    end
    local r = P.R(id)
    r.verdict = VERDICT[cmd]
    if note and note ~= "" then r.note = note end
    P.Note(id, "you answered: " .. P.VERDICT_TEXT[r.verdict] .. (note ~= "" and (" - " .. note) or ""))
    P.Print(id .. " = " .. P.VERDICT_TEXT[r.verdict])
  elseif cmd == "off" then
    if not P.Refuse() then P.Disarm("/qprobe off") end
  elseif cmd == "restore" then
    if not P.Refuse() then
      P.RestoreCVars()
      P.Print("Changed settings restored.")
    end
  elseif cmd == "key" then
    if rest == "" then
      P.Print("Probe key is " .. P.db.key .. ".")
    elseif not P.Refuse() then
      P.Disarm("key change")
      P.db.key = rest:upper()
      P.Print("Probe key is now " .. P.db.key .. ". Arm a test again.")
      P.UpdateStatus()
    end
  elseif cmd == "lure" or cmd == "clam" or cmd == "toy" or cmd == "weapon" then
    local id = P.ParseItem(rest)
    P.db.config[cmd] = id
    P.Print(cmd .. " = " .. (id and (id .. " " .. P.ItemName(id)) or "automatic"))
  elseif P.testsByLower[cmd] then
    P.Press(P.testsByLower[cmd].id)
  else
    P.Print("Unknown command '" .. cmd .. "'.")
    P.PrintHelp()
  end
end

SLASH_PAGLEQOLPROBE1 = "/qprobe"
SlashCmdList.PAGLEQOLPROBE = function(msg)
  local ok, err = pcall(P.Slash, msg or "")
  if not ok then P.ProbeError("/qprobe", err) end
end
