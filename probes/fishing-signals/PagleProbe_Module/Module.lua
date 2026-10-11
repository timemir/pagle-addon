-- PagleProbe_Module/Module.lua
-- A tiny test Module. It checks that a dependent addon loads after the Core,
-- keeps its own saved data (PagleProbeModuleDB), and adds a Settings
-- subcategory under the Core's "PagleProbe" root. Read-only like the Core.

local ADDON = ...
local fileStart = debugprofilestop and debugprofilestop() or nil

local frame = CreateFrame("Frame")
pcall(frame.RegisterEvent, frame, "ADDON_LOADED")
pcall(frame.RegisterEvent, frame, "PLAYER_LOGOUT")

-- Register the subcategory and one checkbox. Returns a list of step results.
local function registerSettings(db)
  local steps = {}
  local function step(name, fn)
    local ok, a = pcall(fn)
    steps[#steps + 1] = name .. ": " .. (ok and "ok" or ("ERROR " .. tostring(a)))
    return ok and a
  end
  if type(Settings) ~= "table" then
    steps[1] = "Settings API missing"
    return steps
  end
  local root = PagleProbe and PagleProbe.settingsRoot
  if not root then
    steps[1] = "Core root category not found"
    return steps
  end
  local sub = step("RegisterVerticalLayoutSubcategory", function()
    return (Settings.RegisterVerticalLayoutSubcategory(root, "Module"))
  end)
  if not sub then return steps end
  step("RegisterAddOnSetting + checkbox", function()
    local vt = (Settings.VarType and Settings.VarType.Boolean) or "boolean"
    local setting = Settings.RegisterAddOnSetting(sub, "PagleProbeModule_Check", "check", db, vt,
      "Module test checkbox (tick it, then /reload)", false)
    local create = Settings.CreateCheckbox or Settings.CreateCheckBox
    create(sub, setting, "Only tests that a Module setting is saved. It does nothing else.")
  end)
  return steps
end

local function onLoaded()
  local fresh = type(PagleProbeModuleDB) ~= "table"
  if fresh then PagleProbeModuleDB = { writes = 0, loads = 0 } end
  local db = PagleProbeModuleDB
  db.loads = (db.loads or 0) + 1
  if db.check == nil then db.check = false end
  local info = {
    fresh = fresh, writes = db.writes or 0, loads = db.loads, lastWriteAt = db.lastWriteAt, check = db.check,
    svMs = fileStart and math.floor(debugprofilestop() - fileStart + 0.5) or nil,
  }
  local ok, steps = pcall(registerSettings, db)
  info.settings = ok and steps or { "ERROR " .. tostring(steps) }
  -- Tell the Core what we read back (the Core keeps the history).
  if PagleProbe and PagleProbe.ModuleCheckIn then pcall(PagleProbe.ModuleCheckIn, info) end
end

frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    pcall(onLoaded)
  elseif event == "PLAYER_LOGOUT" and type(PagleProbeModuleDB) == "table" then
    PagleProbeModuleDB.writes = (PagleProbeModuleDB.writes or 0) + 1
    PagleProbeModuleDB.lastWriteAt = GetServerTime()
  end
end)
