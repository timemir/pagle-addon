-- PagleArtGuide / World.lua
-- What onboarding puts on the world, outside the guide: the letter (ONB-R10–R14, board 1), the First evening
-- list with the next-action button (ONB-R60–R62, "First evening"), the margin notes on first moments (ONB-R52,
-- "Margin notes on first moments") and the first-look sets over each window (ONB-R55–R57, "First look · …").
-- Canvas coordinates are a 1440 x 810 screen; P.Screen maps them onto UIParent's centre.

local ADDON, P = ...
local C = P.C
local GP = "GuideParts"

-- a full-screen layer with the canvas's 1440 x 810 coordinates, centred on UIParent (wider screens get margins)
local layers = {}
function P.Screen(name, strata)
  local f = layers[name]
  if f then return f end
  f = CreateFrame("Frame", nil, UIParent); f:SetSize(1440, 810); f:SetPoint("CENTER")
  f:SetFrameStrata(strata or "HIGH")
  local s = math.min(1, UIParent:GetWidth() / 1440, UIParent:GetHeight() / 810)
  f:SetScale(s)
  layers[name] = f
  return f
end
function P.ClearScreens() for _, f in pairs(layers) do f:Hide() end end
local function fresh(name, strata)
  local old = layers[name]; if old then old:Hide(); layers[name] = nil end
  local f = P.Screen(name, strata); f:Show(); return f
end

-- a note appears: it fades in, then its arrow draws on and its ring pops (MOTION.md)
local function noteIn(note, arrow, delay)
  P.Sound("noteIn")
  note:SetAlpha(0); if arrow then arrow:SetAlpha(0) end
  local anims = { { dur = 0.25, delay = delay or 0, ease = P.Ease.out, keys = { { 0, { 0, 6 } }, { 1, { 1, 0 } } }, apply = function(v) note:SetAlpha(v[1]) end } }
  if arrow then
    local n = #arrow.lines
    anims[#anims + 1] = { dur = 0.35, delay = (delay or 0) + 0.2, ease = P.Ease.inOut, keys = { { 0, { 0 } }, { 1, { 1 } } }, apply = function(v)
      arrow:SetAlpha(1)
      local shown = v[1] * (n - 2)
      for i, l in ipairs(arrow.lines) do l:SetShown(i <= shown or (i > n - 2 and v[1] >= 1)) end
      if arrow.ring then arrow.ring:SetShown(v[1] >= 1) end
    end }
    if arrow.ring then
      anims[#anims + 1] = { dur = 0.15, delay = (delay or 0) + 0.55, ease = P.Bezier(0.3, 1.6, 0.6, 1), keys = { { 0, { 0.4 } }, { 1, { 1 } } }, apply = function(v)
        local b = arrow.ring.box; arrow.ring:SetSize(arrow.ring.w0 * v[1], arrow.ring.h0 * v[1])
      end }
      arrow.ring.w0, arrow.ring.h0 = arrow.ring:GetSize()
    end
  end
  P.Animate(note, anims)
end
P.NoteIn = noteIn

-- ---------------------------------------------------------------- the letter
function P.ShowLetter()
  local S = fresh("letter", "DIALOG")
  local f = CreateFrame("Frame", nil, S); f:SetSize(534, 132); P.At(f, S, 486, 600)
  local seal = CreateFrame("Frame", nil, f); seal:SetSize(82, 82); P.At(seal, f, 0, 25); seal:SetFrameLevel(f:GetFrameLevel() + 3)
  local st = P.Sprite(seal, GP, "letter-seal", "ARTWORK"); P.Place(st, seal, 0, 0)
  P.T(seal, "gilt", 26, "F4DFA8", "P", 41, 25, 32, { center = true, shadow = true })
  local slip = CreateFrame("Frame", nil, f); slip:SetSize(470, 132); P.At(slip, f, 64, 0)
  local sp = P.Sprite(slip, GP, "letter-slip", "BACKGROUND"); P.Place(sp, slip, 0, 0)
  P.T(slip, "sc", 14, C.kicker, "A letter, left on the dock", 34, 12, 18)
  P.T(slip, "hand", 25, C.hand, "Pagle has arrived. Open it whenever you’re ready; it’ll keep.", 34, 30, 27.5, { wrap = true, width = 392 })
  local open = P.LButton(slip, "Open the letter", 34, 92, nil, nil, 28, function() S:Hide(); P.ShowGuide("welcome") end)
  P.LButton(slip, "Later", 34 + open:GetWidth() + 14, 92, nil, "light", 28, function() S:Hide() end)
  -- motion: up 30 and in (0.5 s); the seal drops from 1.6x (0.15–0.55 s)
  P.Sound("letter")
  f:SetAlpha(0)
  P.Animate(f, {
    { dur = 0.5, ease = P.Ease.out, keys = { { 0, { 0, 30 } }, { 1, { 1, 0 } } }, apply = function(v) f:SetAlpha(v[1]); P.At(f, S, 486, 600 + v[2]) end },
    { dur = 0.4, delay = 0.15, ease = P.Bezier(0.3, 1.4, 0.6, 1), keys = { { 0, { 1.6, 0 } }, { 1, { 1, 1 } } }, apply = function(v) seal:SetScale(v[1]); seal:SetAlpha(v[2]) end },
  })
  -- the compartment tooltip the canvas shows beside it (ONB-R13)
  local tip = P.Lacquer(S, 1086, 52, 128, 46)
  P.T(tip, "gilt", 14, "FFD100", "Pagle", 11, 8, 16)
  P.T(tip, "print", 13.5, "E6D8B8", "A letter for you", 11, 25, 18)
  return f
end

-- ---------------------------------------------------------------- the First evening list, in the world
local evening = { done = {} }
function P.ShowEvening(done)
  local S = fresh("evening")
  evening.done = done or evening.done
  evening.S = S
  evening.trk = P.Tracker(S, 1100, 190, P.EVENING, evening.done, { hints = "now" })
  return S
end

-- the canvas's scene: two done, the Journal next, the button at the water, two notes, a Nod
function P.ShowEveningScene()
  local S = P.ShowEvening({ cast = true, catch = true })
  local nod = P.Sample(S, "nod-elem", 500, 650, 424, 36)
  local tip = P.Lacquer(S, 890, 480, 68, 30); P.T(tip, "gilt", 14, "E8C96A", "Reel in", 34, 7, 16, { center = true })
  P.NAB(S, 820, 470, [[Interface\Icons\Trade_Fishing]], "Reel", "F")
  local n1, a1 = P.Pointed(S, "Your bobber dipped. The button shows your next press: *F* reels in.", 540, 518, 226, 1, 812, 500)
  local n2, a2 = P.Pointed(S, "Your list ticks itself off, and folds away when it’s done.", 900, 300, 180, 2, 1104, 265)
  noteIn(n1, a1, 0.2); noteIn(n2, a2, 0.6)
end

-- tick the next item: the box inks in, the line strikes through; the last one folds the list away (ONB-R62)
function P.TickEvening()
  if not evening.trk then P.ShowEvening() end
  for _, it in ipairs(P.EVENING) do
    if not evening.done[it.id] then
      evening.done[it.id] = true
      evening.trk.Redraw()
      P.Sound("tick")
      local all = true; for _, i2 in ipairs(P.EVENING) do if not evening.done[i2.id] then all = false end end
      if all then
        P.Sound("listDone")
        local t = evening.trk
        P.Cue(t, 2.5, function()
          local h = t:GetHeight()
          P.Animate(t, { { dur = 0.4, ease = P.Bezier(0.42, 0, 1, 1), keys = { { 0, { 1, 0 } }, { 1, { 0, 14 } } }, apply = function(v) t:SetAlpha(v[1]); P.At(t, evening.S, 1100, 190 - v[2]) end } },
            function() t:Hide(); evening.done = {} end)
        end)
      else
        -- the tick: the new box pops from 0.6
        local f = evening.trk
        P.Animate(f, { { dur = 0.3, ease = P.Bezier(0.3, 1.5, 0.6, 1), keys = { { 0, { 0.6 } }, { 1, { 1 } } }, apply = function() end } })
      end
      return
    end
  end
end

-- ---------------------------------------------------------------- margin notes on first moments (ONB-R52)
-- each as the canvas's board lays them out, over the dimmed world
local FIRST = {
  nod = { cell = { 60, 150 }, label = "First Catch", sub = "the Nod", draw = function(S, x, y)
    P.Sample(S, "nod-new", x, y + 44, 360, 36)
    return P.Pointed(S, "That’s a *Nod*: one quiet line for every Catch. It’s gone in three seconds, and it’s in your Ledger for good.", x + 150, y + 108, 250, 1, x + 110 + 10, y + 82 + 4)
  end },
  toast = { cell = { 510, 150 }, label = "First new fish", sub = "a toast", draw = function(S, x, y)
    P.Sample(S, "toast", x, y + 40, 400, 82)
    return P.Pointed(S, "A new Species for your Ledger. The coin is *Pagle Coins*: earned by doing things, never bought, spent on looks in the Curio Shop.", x + 90, y + 148, 280, 1, x + 363, y + 112)
  end },
  summary = { cell = { 960, 150 }, label = "First Session ends", sub = "the summary", draw = function(S, x, y)
    P.SampleCut(S, "summary", 0, 0, 580, 324, x, y + 40, 383, 214)
    return (P.Note(S, "You stepped away five minutes, so the Session closed. Everything it earned is here, *even what never popped up*.", x + 150, y + 214, 260, 1))
  end },
  uncharted = { cell = { 60, 500 }, label = "First Uncharted Catch", sub = "Pagle doesn’t know it yet", draw = function(S, x, y)
    P.Sample(S, "nod-unk", x, y + 44, 392, 40)
    return P.Pointed(S, "Pagle hasn’t charted this one yet. It’s kept, and credited the day it is. *Help chart the waters* in the Pagle menu copies it out, to share if you like.", x + 100, y + 110, 300, 1, x + 74, y + 86)
  end },
  lure = { cell = { 510, 500 }, label = "First bare hook", sub = "the next-action button", draw = function(S, x, y)
    P.NAB(S, x + 20, y + 56, [[Interface\Icons\INV_Misc_Orb_03]], "Lure", "F")
    local tip = P.Lacquer(S, x + 92, y + 68, 150, 30); P.T(tip, "gilt", 14, "E8C96A", "Apply Shiny Bauble", 75, 7, 16, { center = true })
    return (P.Note(S, "Your pole has no lure on. Your next press puts the best one in your bags on. *Only that*; then you cast.", x + 120, y + 134, 270, 1))
  end },
  fresh = { cell = { 960, 500 }, label = "Back after a break", sub = "Fresh Water", draw = function(S, x, y)
    P.Sample(S, "fresh", x, y + 40, 400, 54)
    return P.Pointed(S, "You’ve been away, so your next Catches earn bonus XP. That’s *Fresh Water*, the blue in your bar. A rest is never a penalty.", x + 110, y + 124, 280, 1, x + 318, y + 64)
  end },
}
local ORDER = { "nod", "toast", "summary", "uncharted", "lure", "fresh" }
function P.ShowFirst(which)
  local S = fresh("first")
  local dim = P.Solid(S, "060808", 0.58, "BACKGROUND"); dim:SetAllPoints()
  local list = which and FIRST[which] and { which } or ORDER
  for i, k in ipairs(list) do
    local d = FIRST[k]
    local x, y = d.cell[1], d.cell[2]
    local h = P.T(S, "sc", 14, "E8C96A", d.label, x, y, 18)
    P.T(S, "italic", 13, "8FA39C", d.sub, x + math.ceil(h:GetStringWidth()) + 8, y + 1, 17)
    local n, a = d.draw(S, x, y)
    noteIn(n, a, 0.15 * (i - 1))
  end
  if not which then
    P.T(S, "print", 34, "F1E6C8", "Margin notes: the first time, and only then", 60, 40, 40)
  end
end

-- ---------------------------------------------------------------- first looks (ONB-R55–R57)
-- each window stands in as its kit's render; the notes are the canvas's, numbered, with the coach bar
local LOOKS = {
  journal = { "Screen-journal", 1040, 700, 200, 34, 1, "the Fish Journal", {
    { 16, 230, 176, "Every water you fish gets a tile. Its rank climbs from *Visitor* to *Master*.", 150, 250 },
    { 1254, 150, 176, "Your Angler Level. The *blue* stretch is Fresh Water: bonus XP after a break.", 868, 206 },
    { 1254, 330, 176, "Notes to self: what’s closest to done. They rewrite themselves as you fish.", 700, 330 },
    { 1254, 12, 176, "Find a water or a fish. A fish you haven’t caught is *never named*.", 830, 69 },
    { 16, 500, 176, "Dashed tiles are waters you haven’t fished yet, with the skill they ask.", 170, 345 } } },
  hunts = { "Screen-hunts", 1040, 770, 242, 18, 0.92, "Hunts", {
    { 16, 150, 196, "*Now*, *Soon* and *Later*: what’s open, what opens within three hours, and the rest.", 118, 212 },
    { 16, 400, 196, "The red line is *now*, in realm time. Hatched bars are when each Hunt is open.", 295, 470 },
    { 1222, 20, 200, "*Natural* means the game itself keeps this fish to its hours. Imposed Hunts are Pagle’s own rules.", 735, 116 },
    { 1222, 210, 200, "*Pin* a Hunt to keep it on your tracker while you fish.", 650, 199 },
    { 1222, 520, 200, "Each ribbon is a *Hunt set*. Finish every Hunt in one and its title is yours.", 745, 690 } } },
  stats = { "Screen-stats", 1100, 800, 236, 18, 0.88, "Stats", {
    { 16, 180, 196, "Every fish of this water: your odds, and how many Casts since you last caught it.", 372, 247 },
    { 1228, 130, 196, "*Your odds* come only from your own Casts, and always say how many.", 700, 205 },
    { 1228, 330, 196, "A *Dry spell* is how long you’ve waited. Unlucky isn’t broken: nothing is owed.", 745, 400 },
    { 1228, 10, 196, "*Watch* up to three fish to keep their Dry spells on your tracker.", 948, 124 },
    { 16, 470, 196, "Stats *never pops up* and never announces. It’s here when you ask.", 230, 671 } } },
  board = { "Screen-board", 1160, 800, 210, 18, 0.88, "the Tackle Board", {
    { 12, 90, 186, "*Expeditions* are the bigger weekly ones. They wait too, up to two.", 150, 160 },
    { 12, 300, 186, "A Notice *never expires*. Don’t fancy it? Take it down, once, for another.", 318, 418 },
    { 12, 540, 186, "Your *Campfire*: days in a row with one done. A missed day burns Kindling instead.", 170, 668 },
    { 600, 412, 240, "Each one done ties a fly for your *Fly Box*.", 510, 640, "bottom" },
    { 1238, 520, 190, "They pay *Pagle Coins*, spent on looks in the Curio Shop.", 980, 645 } } },
  shop = { "Screen-shop", 1440, 810, 0, 0, 1, "the Curio Shop", {
    { 16, 230, 200, "Coins come only from things you’ve done. The bar shows what paid them.", 364, 141 },
    { 16, 470, 200, "Everything here is a *look*: toasts, sounds, bindings, crests. Nothing makes you fish better.", 290, 484 },
    { 1222, 380, 200, "*Show on screen* plays it for real before you buy.", 1046, 450 },
    { 1222, 560, 200, "The stock *never rotates*. What’s here today is here next month.", 980, 628 } } },
}
function P.ShowLook(key)
  local L = LOOKS[key]
  if not L then return end
  local S = fresh("look")
  local file, iw, ih, left, top, scale, title, notes = unpack(L)
  if key ~= "shop" then local dim = P.Solid(S, "081316", 0.75, "BACKGROUND"); dim:SetAllPoints() end
  local shot = S:CreateTexture(nil, "BORDER")
  shot:SetTexture([[Interface\AddOns\PagleArtGuide\Textures\]] .. file)
  local k = 1024 / iw
  shot:SetTexCoord(0, 1, 0, ih * k / 1024)
  shot:SetSize(iw * scale, ih * scale); P.At(shot, S, left, top)
  for i, n in ipairs(notes) do
    local note, arrow = P.Pointed(S, n[4], n[1], n[2], n[3], i, left + n[5] * scale, top + n[6] * scale, { side = n[7] })
    noteIn(note, arrow, 0.12 * (i - 1))
  end
  local bar = P.CoachBar(S, "First look · " .. title, #notes, function() S:Hide() end)
  bar:ClearAllPoints(); bar:SetPoint("TOP", S, "TOPLEFT", 720, -756)
end
