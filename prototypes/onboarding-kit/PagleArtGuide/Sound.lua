-- Sound.lua (shared by the Pagle art probes)
-- Every sound the kits play, by event. Each uses one of the client's own sound kits (no files to ship),
-- named from SOUNDKIT in the client's SoundKitConstants.lua, with the numeric id as a fallback.
-- These are first picks: audition them with the kit's "sounds" command and swap any that don't fit.

local ADDON, P = ...
P.sound = true

-- event = { SOUNDKIT name, id }
P.SOUNDS = {
  -- announcements
  toast        = { "IG_QUEST_LIST_SELECT", 877 },          -- a toast arrives (not toast.low: those stay quiet)
  toastHigh    = { "IG_QUEST_LIST_COMPLETE", 878 },        -- toast.high: a Hunt complete, a tier
  write        = { "IG_WRITE_QUEST", 3093 },               -- the name writes itself
  stamp        = { "PUT_DOWN_GEMS", 1204 },                -- a rubber stamp or the DONE stamp lands
  coin         = { "LOOT_WINDOW_COIN_SOUND", 120 },         -- Coins: a coin flips in, the purse counts
  banner       = { "UI_CHALLENGES_NEW_RECORD", 33338 },    -- a banner's seal drops
  legend       = { "UI_LEGENDARY_LOOT_TOAST", 63971 },     -- the Legend splash
  -- books
  bookOpen     = { "IG_SPELLBOOK_OPEN", 829 },
  bookClose    = { "IG_SPELLBOOK_CLOSE", 830 },
  pageTurn     = { "IG_ABILITY_PAGE_TURN", 836 },          -- switching ribbons
  check        = { "IG_MAINMENU_OPTION_CHECKBOX_ON", 856 },
  uncheck      = { "IG_MAINMENU_OPTION_CHECKBOX_OFF", 857 },
  huntOpens    = { "MAP_PING", 3175 },                     -- a Hunt's window opens while the board is open
  -- QoL and the Field report
  popupOpen    = { "IG_MAINMENU_OPEN", 850 },              -- a wax-pinned note or the Field report appears
  popupClose   = { "IG_MAINMENU_CLOSE", 851 },             -- ...and is closed
  click        = { "IG_MAINMENU_OPTION", 852 },            -- a button on them (Copy, Use Pagle, Reload now)
  -- the Tackle Board
  boardOpen    = { "IG_QUEST_LOG_OPEN", 844 },
  boardClose   = { "IG_QUEST_LOG_CLOSE", 845 },
  noticeDone   = { "IG_QUEST_LIST_COMPLETE", 878 },
  pin          = { "PUT_DOWN_SMALL_CHAIN", 1212 },         -- a tack pressed in, a slip on the spike
  fireUp       = { "UI_POWER_AURA_GENERIC", 23287 },       -- the Campfire steps up
  fireOut      = { "IG_QUEST_CANCEL", 879 },               -- the Campfire goes out
  kindling     = { "IG_ABILITY_ICON_DROP", 838 },          -- a Kindling stick burns
  flyTied      = { "UI_PROFESSIONS_NEW_RECIPE_LEARNED_TOAST", 73919 },
  drawerOpen   = { "IG_BACKPACK_OPEN", 862 },
  drawerClose  = { "IG_BACKPACK_CLOSE", 863 },
  -- onboarding (the guide kit)
  letter       = { "TUTORIAL_POPUP", 7355 },               -- the letter arrives
  noteIn       = { "IG_CHAT_SCROLL_DOWN", 827 },           -- a margin note or a first-look set appears
  tick         = { "IG_MAINMENU_OPTION_CHECKBOX_ON", 856 }, -- a First evening item is done
  listDone     = { "IG_QUEST_LIST_COMPLETE", 878 },        -- the list's last tick
  -- the Curio Shop
  shopOpen     = { "AUCTION_WINDOW_OPEN", 5274 },
  shopClose    = { "AUCTION_WINDOW_CLOSE", 5275 },
  buy          = { "IG_BACKPACK_COIN_OK", 865 },
}

function P.Sound(event)
  if not P.sound then return end
  local s = P.SOUNDS[event]
  if not s then return end
  local id = (SOUNDKIT and SOUNDKIT[s[1]]) or s[2]
  if PlaySound then PlaySound(id, "SFX") end
end

-- play every sound in turn, a second apart, naming each in chat
function P.AuditionSounds(only)
  local list = {}
  for k, v in pairs(P.SOUNDS) do if not only or only[k] then list[#list + 1] = k end end
  table.sort(list)
  local i = 0
  local f = CreateFrame("Frame"); local t = 1
  f:SetScript("OnUpdate", function(self, el)
    t = t + el
    if t < 1.2 then return end
    t = 0; i = i + 1
    local k = list[i]
    if not k then self:SetScript("OnUpdate", nil); print("|cffe8c96a[Pagle art]|r that's every sound."); return end
    print(("|cffe8c96a[Pagle art]|r %s: %s (%d)"):format(k, P.SOUNDS[k][1], P.SOUNDS[k][2]))
    local was = P.sound; P.sound = true; P.Sound(k); P.sound = was
  end)
end
