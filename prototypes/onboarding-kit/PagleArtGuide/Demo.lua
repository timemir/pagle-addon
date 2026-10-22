-- PagleArtGuide / Demo.lua
-- /pagleguide shows onboarding with the real art: the letter, the field guide, the First evening list, the margin
-- notes on first moments and the first-look sets. Sample data only; it reads no game data but your name, portrait
-- and key bindings (read, never changed), and does nothing on its own.

local ADDON, P = ...

local HELP = {
  "letter | guide [step] | welcome | box | casting | clothes | moments | ledger | board | off | without (no Tackle Board: 7 steps) | turn",
  "evening (the scene) | list | tick | first [nod|toast|summary|uncharted|lure|fresh] | look journal|hunts|stats|board|shop",
  "sounds | sound | motion | hide",
}

local function hideAll() P.HideGuide(); P.ClearScreens() end

SLASH_PAGLEGUIDE1 = "/pagleguide"
SlashCmdList.PAGLEGUIDE = function(msg)
  local cmd, arg = strsplit(" ", strtrim(msg or "")); cmd = (cmd or ""):lower(); arg = arg and arg:lower()
  if cmd == "" or cmd == "letter" then hideAll(); P.ShowLetter()
  elseif cmd == "guide" then P.ClearScreens(); P.ShowGuide(arg ~= "" and arg or nil, true)
  elseif P.stepIndex(cmd) then P.ClearScreens(); P.ShowGuide(cmd, true)
  elseif cmd == "without" then P.ClearScreens(); P.ShowGuide("casting", false, P.GuideWithout("board"))
  elseif cmd == "turn" then
    P.ClearScreens(); local b = P.ShowGuide("welcome", false)
    P.Cue(b, 0.6, function() P.ShowView(b, "box", true) end)
  elseif cmd == "evening" then hideAll(); P.ShowEveningScene()
  elseif cmd == "list" then hideAll(); P.ShowEvening({})
  elseif cmd == "tick" then P.HideGuide(); P.TickEvening()
  elseif cmd == "first" then hideAll(); P.ShowFirst(arg ~= "" and arg or nil)
  elseif cmd == "look" then hideAll(); P.ShowLook(arg or "journal")
  elseif cmd == "hide" then hideAll()
  elseif cmd == "sounds" then P.AuditionSounds({ letter = 1, noteIn = 1, tick = 1, listDone = 1, bookOpen = 1, bookClose = 1, pageTurn = 1, click = 1, check = 1 })
  elseif cmd == "sound" then P.sound = not P.sound; print("|cffe8c96a[Pagle art]|r sound " .. (P.sound and "on" or "off"))
  elseif cmd == "motion" then P.motion = not P.motion; print("|cffe8c96a[Pagle art]|r motion " .. (P.motion and "on" or "off"))
  else for _, l in ipairs(HELP) do print("|cffe8c96a[Pagle art]|r /pagleguide " .. l) end end
end

local ev = CreateFrame("Frame"); ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  print("|cffe8c96a[Pagle art]|r Guide kit loaded. Type /pagleguide (or /pagleguide help).")
  if #P.fontProblems > 0 then print("|cffff4d3a[Pagle art]|r these fonts failed to load: " .. table.concat(P.fontProblems, ", ")) end
end)
