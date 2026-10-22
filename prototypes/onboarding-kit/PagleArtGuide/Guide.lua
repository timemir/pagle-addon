-- PagleArtGuide / Guide.lua
-- The field guide (ONB-R20–R38): the Fish Journal's book shell over a dimmed world, eight steps as views with
-- the books' page turn between them, the step ribbons hanging under the book, and each step's two pages as the
-- canvas draws them (boards 2–9 of "Onboarding redesign"). Coordinates are the canvas's, from the page's top left.

local ADDON, P = ...
local C = P.C
local GP = "GuideParts"
local W = 382 -- text column on a page (30 to 412)
local FISH = [[Interface\Icons\Trade_Fishing]]
local LURE = [[Interface\Icons\INV_Misc_Orb_03]]
local POLE = [[Interface\Icons\INV_Fishingpole_02]]

local function kicker(p, t) return P.T(p, "sc", 14, C.kicker, t, 30, 24, 14) end
local function title(p, t, size) return P.T(p, "print", size or 29, C.title, t, 30, 41, (size or 29) * 1.05) end
local function body(p, t, y, size, hex, lh, x, w)
  return P.T(p, "print", size or 15, hex or C.body, t, x or 30, y, lh or 20.7, { wrap = true, width = w or W })
end
local function small(p, t, y) return body(p, t, y, 13.5, C.small, 18.225) end
local function note(p, t, y, x, w) return P.T(p, "italic", 13, C.note, t, x or 30, y, 17.55, { wrap = true, width = w or W }) end
local function color(hex, t) return "|cff" .. hex .. t .. "|r" end
local function bigButton(p, text, y, onClick)
  local b = P.LButton(p, text, 30, y, W, nil, 46, onClick)
  b.label:SetFontObject(P.Font("gilt", 18, "F4DFA8", true))
  return b
end

-- ---------------------------------------------------------------- the steps
local STEPS = {}
P.GUIDE_STEPS = STEPS
local function step(def) STEPS[#STEPS + 1] = def; def.order = #STEPS * 10 end

-- 1 · Welcome (board 2)
step({ key = "welcome", ribbon = "Welcome", build = function(L, R, nav)
  kicker(L, "A letter, left on the dock"); title(L, "Dear Angler,")
  local hand = { "From now on, every fish you pull out of the water gets written down: where, when, how big, and what it took to land it.",
    "Fish long enough and the water starts telling you things: what bites only at night, which fish you keep missing, how far you’ve come.",
    "Let me show you around. It takes two minutes, and you can change everything later." }
  local ys = { 87.4, 183.6, 279.7 }
  for i, t in ipairs(hand) do P.T(L, "hand", 23, C.hand, t, 30, ys[i], 28.06, { wrap = true, width = W }) end
  P.T(L, "handBold", 30, C.body, "Pagle", 30, 345.8, 30)
  P.T(L, "italic", 13, C.note, "Everything here is also in Options › AddOns › Pagle.", 30, 505.8, 18.2)
  kicker(R, "Before anything else"); title(R, "Three promises", 25)
  local promises = {
    { "I", "I never fish for you.", "Pagle watches and writes things down. Every key press does one thing at most, and your hands do the fishing." },
    { "II", "Nothing expires.", "There are no dailies to miss. Goals wait for you, and a day away costs you nothing." },
    { "III", "Every part is optional.", "Pagle comes in five parts. Turn any of them off in the AddOns list and it leaves no trace." } }
  for i, pr in ipairs(promises) do
    local y = 89.3 + (i - 1) * 85.8
    local d = P.Sprite(R, GP, "disc", "ARTWORK"); P.Place(d, R, 30, y)
    P.T(R, "gilt", 15, "F4DFA8", pr[1], 53, y + 13.5, 19, { center = true, shadow = true })
    P.T(R, "print", 19, C.title, pr[2], 90, y + 4, 21.85)
    P.T(R, "print", 14.5, C.small, pr[3], 90, y + 27.8, 20.01, { wrap = true, width = 322 })
  end
  P.Foot(R, "I’ll find my own way", nil, nav.Skip)
  local b = P.LButton(R, "Show me around ›", 252.6, 490, 159.4, nil, 34, nav.Next)
end })

-- 2 · What's in the box (board 3)
local PARTS = {
  { "journal", "Fish Journal", "Your book: every water and every fish, your Angler Level, records and titles." },
  { "hunts", "Hunts", "Fish that only bite at night, in winter or at the fair, and which of them bite right now." },
  { "stats", "Stats", "Your own numbers: your odds, from your own Casts, and how long you’ve waited. It never pops up." },
  { "board", "Tackle Board", "Small goals pinned to a cork board, if you want them. They wait while you’re away." },
  { "qol", "QoL", "The Fishing key, your fishing clothes, lures and clams: one press, one action." },
  { "shop", "Curio Shop", "Pagle Coins come from things you achieve, and buy looks, never power." },
}
step({ key = "box", ribbon = "What’s in the box", build = function(L, R, nav)
  kicker(L, "The kit"); title(L, "What came in the box")
  body(L, "Pagle is a small kit, not one big window. Each part has its own place, and every one of them opens from the " .. color(C.title, "Pagle") .. " entry under the addons button by your minimap.", 85.4)
  -- the compartment menu, drawn from its labels (CORE-R50)
  local m = CreateFrame("Frame", nil, L); m:SetSize(214, 230); P.At(m, L, 56, 169.5); m:SetFrameLevel(L:GetFrameLevel() + 2)
  local bg = P.Nine(m, "menu", 214, 230, 8); bg:SetPoint("TOPLEFT")
  P.T(m, "gilt", 13, "FFD100", "Pagle", 14, 6 + 6, 13)
  local rows = { "Fish Journal", "Hunts", "Stats", "Tackle Board", "Input: Both" }
  local y = 31
  for i, t in ipairs(rows) do
    if i == 1 then local hl = P.Solid(m, "FFD100", 1, "ARTWORK"); hl:SetSize(214, 23); P.At(hl, m, 0, y); hl:SetGradient("HORIZONTAL", CreateColor(1, 0.82, 0, 0.22), CreateColor(1, 0.82, 0, 0)) end
    P.T(m, "gilt", 13, "F2F2F2", t, 14, y + 5, 13); y = y + 23
  end
  local sep = P.Solid(m, "3A3A3A", 1, "ARTWORK"); sep:SetSize(194, 1); P.At(sep, m, 10, y + 4); y = y + 9
  P.T(m, "gilt", 13, "F2F2F2", "Curio Shop", 14, y + 5, 13)
  P.T(m, "gilt", 13, "F2F2F2", "0", 183, y + 5, 13, { right = true })
  local coin = P.Sprite(m, GP, "coin", "ARTWORK", 1); P.Place(coin, m, 189, y + 6)
  y = y + 23
  for _, t in ipairs({ "Help chart the waters", "Settings" }) do P.T(m, "gilt", 13, "F2F2F2", t, 14, y + 5, 13); y = y + 23 end
  P.Pointed(L, "Click a name to open it. *\/pagle* opens Settings.", 292, 196, 136, nil, 262, 212)
  P.Back(L, nav.Back)
  kicker(R, "Five parts, and a shop")
  for i, p in ipairs(PARTS) do
    local y0 = 55 + (i - 1) * 73.98
    local ic = P.Sprite(R, GP, "ic-" .. p[1], "ARTWORK"); P.Place(ic, R, 30, y0)
    P.T(R, "print", 17, C.title, p[2], 79, y0, 19.55)
    P.T(R, "print", 13.5, C.small, p[3], 79, y0 + 21.5, 18.225, { wrap = true, width = 333 })
    if i < #PARTS then local r = P.Solid(R, "C4A874", 0.6); r:SetSize(W, 1); P.At(r, R, 30, y0 + 66) end
  end
  P.Foot(R, "Skip the rest", "Next ›", nav.Skip, nav.Next)
end })

-- 3 · Casting (board 4)
step({ key = "casting", ribbon = "Casting", build = function(L, R, nav)
  kicker(L, "Casting"); title(L, "One key for the whole cast")
  body(L, "Press the Fishing key and Pagle does the one next thing, then waits for your next press. It never does two things at once, and it never does anything on its own.", 85.4)
  local seq = { { POLE, "Gear", "your fishing clothes go on" }, { LURE, "Lure", "the best lure you have" }, { FISH, "Cast", "out it goes" }, { FISH, "Reel", "when the bobber dips" } }
  for i, s in ipairs(seq) do
    local x = 34 + (i - 1) * 97.6
    P.NAB(L, x + 13, 173.5, s[1], s[2], "F")
    P.T(L, "italic", 12.5, "6A4A28", s[3], x + 39, 263.5, 15.625, { center = true, wrap = true, width = 78 })
    if i < #seq then P.T(L, "hand", 26, C.kicker, "›", x + 82 + 5.8, 191.5, 33, { center = true }) end
  end
  small(L, "Steps you don’t need are passed over: no fishing clothes saved, no gear step; a lure already on, no lure step. A small button by the water shows what your next press will do.", 320.8)
  P.Note(L, "A *double right-click* on the water casts and reels too, but never changes your clothes.", 56, 400, 300)
  P.Back(L, nav.Back)
  kicker(R, "Your choice"); title(R, "How would you like to cast?", 25)
  local cards = {
    P.Choice(R, 30, 81.3, W, 61.8, "The Fishing key", "One key does the next thing, clothes and lures included.", false),
    P.Choice(R, 30, 151, W, 61.8, "Double right-click", "Right-click twice, as you would anyway. No key to give up.", false),
    P.Choice(R, 30, 220.8, W, 61.8, "Both", "The key when you want it, the mouse when you don’t.", true, "the usual") }
  P.ChoiceGroup(cards)
  nav.BindingField(R, 30, 298.5, "Fishing key", "Esc leaves it unbound", "fishing")
  local chk = P.CheckRow(R, 30, 374.5, true, "Show the next-action button", "Shift-drag it wherever you like.")
  P.Foot(R, "Skip the rest", "Next ›", nav.Skip, nav.Next)
  -- the margin note beside the book (on the world, right of the right page)
  nav.Outside(function(book)
    return P.Pointed(book, "Pick a key you don’t use near water. If it already does something, Pagle *asks before taking it*.", 928, 338, 196, nil, 868, 360, { level = 30 })
  end)
end })

-- 4 · Fishing clothes (board 5)
local PREV = { [[Interface\Icons\INV_Helmet_01]], [[Interface\Icons\INV_Chest_Chain_05]], [[Interface\Icons\INV_Gauntlets_04]], [[Interface\Icons\INV_Sword_04]] }
local FISHSET = { [[Interface\Icons\INV_Misc_Bandana_03]], [[Interface\Icons\INV_Shirt_05]], [[Interface\Icons\INV_Gauntlets_05]], POLE }
local function kit(p, x, name, icons, line, tint)
  local f = CreateFrame("Frame", nil, p); f:SetSize(166, 108.6); P.At(f, p, x, 171.5); f:SetFrameLevel(p:GetFrameLevel() + 1)
  local bg = P.Nine(f, "card", 166, 108.6, 6); bg:SetPoint("TOPLEFT")
  P.T(f, "sc", 15, C.title, name, 83, 11, 19, { center = true })
  for i, ic in ipairs(icons) do
    local x0 = 7.5 + (i - 1) * 39
    local t = P.crisp(f:CreateTexture(nil, "ARTWORK", nil, 0)); t:SetTexture(ic); t:SetSize(32, 32); P.At(t, f, x0 + 1, 39)
    t:SetTexCoord(0.08, 0.92, 0.08, 0.92); t:SetVertexColor(tint[1], tint[2], tint[3])
    local r = P.Sprite(f, GP, "slot", "ARTWORK", 1); P.Place(r, f, x0, 38)
  end
  P.T(f, "italic", 12.5, "6A4A28", line, 83, 80, 15.6, { center = true })
end
step({ key = "clothes", ribbon = "Fishing clothes", skip = "I don’t keep fishing clothes", skipTo = "next", build = function(L, R, nav)
  kicker(L, "Fishing clothes"); title(L, "Your hat, your pole")
  body(L, "If you keep a fishing outfit, Pagle can put it on for you: the Fishing key’s first press at the water changes your clothes, and what you were wearing is kept, ready to put back.", 85.4)
  kit(L, 36, "Pagle Previous", PREV, "what you wore before", { 0.85, 0.88, 0.95 })
  kit(L, 268, "Pagle Fishing", FISHSET, "your fishing clothes", { 0.85, 1, 0.95 })
  local ar = P.Sprite(L, GP, "arrows", "ARTWORK"); P.Place(ar, L, 212, 203)
  P.T(L, "hand", 17, C.hand, "one key", 235, 233, 17, { center = true })
  small(L, "Both are ordinary equipment sets, so you’ll see them in your character sheet too. When you walk away with your pole still in hand, a small note reminds you how to change back. Pagle never changes your clothes without a press.", 302.1)
  P.Back(L, nav.Back)
  kicker(R, "If you have a fishing outfit"); title(R, "Put it on, then save it", 25)
  small(R, "Wear your fishing hat, gloves and pole now, then press the button. You can do this later from Settings › Fishing.", 75.3)
  local save = P.LButton(R, "Save what I’m wearing as my fishing set", 30, 127.7, W, nil, 42)
  save.label:SetFontObject(P.Font("gilt", 16, "F4DFA8", true))
  P.T(R, "italic", 13.5, "6A4A28", "or use a set you made", 30, 189, 18)
  local dd = P.Nine(R, "field", 272.8, 32, 6); P.At(dd, R, 139.2, 181.7)
  P.T(R, "print", 14.5, C.title, "None (gear stays as it is)", 150, 188.7, 18)
  local caret = P.Sprite(R, GP, "caret", "ARTWORK", 2); P.Place(caret, R, 394, 191)
  nav.BindingField(R, 30, 231.7, "Swap gear", "changes you in and out in one press", "swap")
  P.T(R, "italic", 13, C.note, "Needs two free equipment set slots: one for your fishing clothes and one for Pagle Previous.", 30, 307.7, 17.55, { wrap = true, width = W })
  P.T(R, "sc", 14, C.kicker, "If you walk off still dressed for it", 30, 370, 14)
  local n = P.Lacquer(R, 30, 390.8, W, 40)
  local t1 = P.T(n, "print", 14, "E6D8B8", "Still holding your pole. Press", 12, 11, 18)
  local kx = 12 + math.ceil(t1:GetStringWidth()) + 6
  local k = P.KeyCap(n, "G", kx, 8)
  P.T(n, "print", 14, "E6D8B8", "to swap back.", kx + k.w + 6, 11, 18)
  P.Foot(R, "I don’t keep fishing clothes", "Next ›", nav.Next, nav.Next)
end })

-- 5 · Moments (board 6)
step({ key = "moments", ribbon = "Moments", build = function(L, R, nav)
  kicker(L, "Moments"); title(L, "When something good happens")
  small(L, "Pagle tells you, in one of three sizes. The bigger the moment, the bigger the note.", 79.4)
  -- the samples as the canvas crops them (in the addon: the real frames, standing still)
  P.SampleCut(L, "nod-new", 1, 0, 385, 54 / 0.556 > 54 and 54 or 54, 30, 137.6, 214, 30, true)
  P.SampleCut(L, "toast", 0, 0, 465, 95, 30, 189.3, 214, 62, true)
  P.SampleCut(L, "banner", 0, 0, 695, 290, 30, 261.3, 214, 104, true)
  local smp = { { "A Nod", "Every Catch. One line, gone in 3 seconds.", 125.9 }, { "A toast", "A new fish, a record, Coins earned.", 193.6 }, { "A banner", "A new Angler Level, and the title that comes with it.", 286.6 } }
  for _, s in ipairs(smp) do
    P.T(L, "sc", 16, C.title, s[1], 256, s[3], 17.6)
    P.T(L, "italic", 13, "6A4A28", s[2], 256, s[3] + 19.6, 16.9, { wrap = true, width = 156 })
  end
  small(L, "At most four pop-ups every five minutes: past that, small ones step down to a Nod. Everything lands on the Session summary when you stop.", 377.3)
  P.Back(L, nav.Back)
  kicker(R, "Your choice"); title(R, "How chatty should Pagle be?", 25)
  local function card(y, h, ttl, line, what, on, tag)
    local b = P.Choice(R, 30, y, W, h, ttl, line, on, tag)
    local lines = math.max(1, math.ceil(P.Txt(R, "italic", 13.5, "6A4A28", line):GetStringWidth() / (W - 49 - (tag and 40 or 0))))
    P.T(b, "hand", 16, C.hand, what, 37, 32.5 + lines * 18.2 + 4, 17.6)
    return b
  end
  local cards = {
    card(81.3, 83.4, "Lively", "Every Catch gets its Nod; toasts and banners with sound.", "4 pop-ups in 5 minutes", true, "as it comes"),
    card(172.6, 101.6, "Quieter", "No Nod for ordinary Catches, and fewer pop-ups. The big moments still show.", "2 pop-ups in 5 minutes", false),
    card(282.2, 101.6, "Cozy", "Nothing pops up and nothing plays. It all waits for your Session summary.", "a Legend still shows, silently", false) }
  P.ChoiceGroup(cards)
  note(R, "Each one only sets the switches in Settings › Announcements, where you can fine-tune them later.", 397.8)
  P.Foot(R, "Skip the rest", "Next ›", nav.Skip, nav.Next)
end })

-- 6 · Your Ledger (board 7)
step({ key = "ledger", ribbon = "Your Ledger", build = function(L, R, nav)
  kicker(L, "Your Ledger"); title(L, "It starts with your next fish")
  body(L, "Pagle writes down only what it sees. Fish you caught before today aren’t in your Ledger, and Pagle won’t pretend they are. Your first Catch is page one.", 85.4)
  local pl = P.Sprite(L, GP, "plate", "ARTWORK"); P.Place(pl, L, 96, 160)
  P.T(L, "sc", 13, C.red, "EX LIBRIS", 221, 186.6, 20.8, { center = true })
  local face = CreateFrame("Frame", nil, L); face:SetSize(64, 64); P.At(face, L, 189, 215); face:SetFrameLevel(L:GetFrameLevel() + 2)
  local por = face:CreateTexture(nil, "ARTWORK", nil, 0); por:SetSize(58, 58); por:SetPoint("CENTER")
  if SetPortraitTexture then SetPortraitTexture(por, "player") end
  local m = face:CreateMaskTexture(); m:SetTexture([[Interface\CharacterFrame\TempPortraitAlphaMask]], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); m:SetAllPoints(por); por:AddMaskTexture(m)
  local ring = P.Sprite(face, GP, "face", "ARTWORK", 1); P.Place(ring, face, 0, 0)
  local name = (UnitName and UnitName("player")) or "Kukli Vail"
  P.T(L, "print", 19, C.title, "The Angler’s Ledger", 221, 285.6, 20.9, { center = true })
  P.T(L, "italic", 14, "6A4A28", name, 221, 312, 18, { center = true })
  local rule = P.Solid(L, "8A5A2A", 0.5); rule:SetSize(216, 1); P.At(rule, L, 113, 338.5)
  P.T(L, "hand", 18, "8A8070", "kept since … your first Catch", 221, 347, 22, { center = true })
  P.Back(L, nav.Back)
  kicker(R, "Already written in"); title(R, "What Pagle could see", 25)
  small(R, "Your Fishing skill is the one thing that tells your past honestly, so it counts from the start.", 75.3)
  local wu = P.Nine(R, "opt", W, 196, 6); P.At(wu, R, 30, 125.7)
  local skill = 125
  P.T(R, "sc", 15, C.title, name .. " · Fishing " .. skill, 45, 141, 19)
  P.T(R, "italic", 12.5, "8A5A2A", "read just now", 397, 141.7, 16, { right = true })
  local hr = P.Solid(R, "C4A874", 1); hr:SetSize(352, 1); P.At(hr, R, 45, 162)
  local rows = { { true, "Skill Milestone 75", "reached before Pagle came", "+1,000 XP" }, { false, "Skill Milestone 150", (150 - skill) .. " skill to go", "+1,000 XP" }, { false, "Skill Milestones 225 and 300", "for later" } }
  for i, r in ipairs(rows) do
    local y = 162.7 + (i - 1) * 50
    local mk = P.Sprite(R, GP, r[1] and "tick-red" or "ring-ghost", "ARTWORK"); P.Place(mk, R, 46, y + 10)
    P.T(R, "print", 15, C.title, r[2], 71, y + 10, 18.75)
    P.T(R, "italic", 12.5, "6A4A28", r[3], 71, y + 28.7, 16.25)
    if r[4] then P.T(R, "hand", 18, r[1] and C.red or "8A8070", r[4], 397, y + 8, 22, { right = true }) end
    if i < #rows then P.Dots(R, 45, y + 49.5, 352, "8A5A2A", 0.45, 3) end
  end
  small(R, "Every character on this account writes in the same Ledger. Log in with another and Pagle reads their Fishing skill too.", 337.7)
  P.Note(R, "Turn a part on later and it reads back through *every Catch* since today, then writes up what you’d earned.", 70, 384, 290)
  P.Foot(R, "Skip the rest", "Next ›", nav.Skip, nav.Next)
end })

-- 7 · Tackle Board (board 8)
step({ key = "board", ribbon = "Tackle Board", skip = "Not now", skipTo = "next", build = function(L, R, nav)
  kicker(L, "The Tackle Board"); title(L, "Goals that wait for you")
  body(L, "Small Notices pinned to a cork board: a fish to find, a water to visit. Fish when you like; they’ll still be there.", 83.4)
  P.Sample(L, "notices", 30, 140.8, 396, 108, true)
  P.SampleCut(L, "campfire", 0, 0, 280, 140, 30, 264.8, 140, 70, true)
  body(L, color(C.title, "Your Campfire") .. " grows with each day you finish a Notice. Miss a day and " .. color(C.title, "Kindling") .. " burns instead; it isn’t put out.", 271.5, 14, "4A3018", 18.9, 184, 228)
  P.SampleCut(L, "flybox", 0, 0, 280, 140, 30, 350.8, 140, 70, true)
  body(L, "Each Notice you finish ties one fly for your " .. color(C.title, "Fly Box") .. ".", 366.9, 14, "4A3018", 18.9, 184, 228)
  P.Back(L, nav.Back)
  kicker(R, "Only if you want one"); title(R, "Shall I put up a board?", 25)
  local facts = { "Three Notices a day, and one bigger Expedition a week.", "None of them expire. Away a while? Up to six Notices and two Expeditions wait for you.",
    "Don’t fancy one? Take it down and another goes up, once each.", "They pay Pagle Coins, " .. color("6A4A28", "which buy looks in the Curio Shop.") }
  local ys = { 83.3, 113.8, 163.9, 214.1 }
  for i, f in ipairs(facts) do
    local c = P.Sprite(R, GP, "coin", "ARTWORK"); c:SetSize(c:GetWidth() * 8 / 11, c:GetHeight() * 8 / 11); c.box = { c.box[1] * 8 / 11, c.box[2] * 8 / 11, 8, 8 }; P.Place(c, R, 33, ys[i] + 11)
    P.T(R, "print", 14.5, C.title, f, 52, ys[i] + 5, 19.575, { wrap = true, width = 360 })
    if i < #facts then P.Dots(R, 30, ys[i + 1] - 1, W, "8A5A2A", 0.45, 3) end
  end
  local start
  start = bigButton(R, "Start my board", 264.6, function()
    start.label:SetText("Your board is up"); P.Sound("pin")
  end)
  P.T(R, "italic", 13, C.note, "Or leave it for now. The board waits under Tackle Board in the Pagle menu, and in Settings.", 221, 322.6, 17.55, { wrap = true, width = W, center = true, justify = "CENTER" })
  P.Foot(R, "Not now", "Next ›", nav.Next, nav.Next)
end })

-- 8 · Off you go (board 9)
step({ key = "off", ribbon = "Off you go", build = function(L, R, nav)
  kicker(L, "That’s all for now"); title(L, "The rest you learn by fishing")
  body(L, "The first time something new happens (your first Nod, your first new fish, your first Session summary) I’ll leave a note beside it. Once. After that the margins stay clean.", 85.4)
  P.SampleCut(L, "nod-new", 1, 0, 385, 54, 40, 191.5, 214, 30, true)
  P.Pointed(L, "That’s a *Nod*: every Catch gets one. It’s gone in three seconds.", 226, 222, 216, 1, 186, 222 - 2)
  small(L, "Don’t want notes? Turn off Margin notes in Settings. The Fish Journal, Hunts, Stats, the Tackle Board and the Curio Shop each get a short set the first time you open them.", 317.5)
  P.Back(L, nav.Back)
  kicker(R, "Your first evening"); title(R, "A short list, if you like", 25)
  small(R, "It sits under your quests and ticks itself off. Close it whenever you like.", 73.3)
  P.Tracker(R, 84, 124, P.EVENING, {}, { hints = { cast = true, session = true }, now = false }) -- as the canvas previews it
  bigButton(R, "Off to the water", 359.7, nav.Done)
  P.T(R, "italic", 13, C.note, color(C.title, "/pagle guide") .. " opens this guide again.", 221, 415.7, 17.55, { center = true })
end })

-- ---------------------------------------------------------------- the binding field (ONB-R40–R43, the probe only reads bindings)
local function bindingField(page, x, y, label, hint, which)
  local f = CreateFrame("Button", nil, page); f:SetSize(W, 62); P.At(f, page, x, y); f:SetFrameLevel(page:GetFrameLevel() + 2)
  local bg = P.Nine(f, "bind", W, 62, 8); bg:SetPoint("TOPLEFT")
  P.T(f, "print", 15, C.body, label, 13, 21.5, 19)
  local capX = 13 + math.ceil(P.Txt(f, "print", 15, C.body, label):GetStringWidth()) + 12
  local states = {}
  local function clear() for _, r in ipairs(states) do r:Hide() end; wipe(states) end
  local function keep(...) for i = 1, select("#", ...) do local r = select(i, ...); if r then states[#states + 1] = r end end end
  local hintFS = P.T(f, "italic", 13, C.note, hint, W - 13, 22.3, 17.55, { right = true, wrap = true, width = 130, justify = "RIGHT" })
  function f.Show_(state, key, old)
    clear(); hintFS:Show()
    if f.conf then f.conf:Hide() end
    if state == "unbound" then keep(P.WaitCap(f, "click to bind", capX, 11))
    elseif state == "listen" then keep(P.WaitCap(f, "press a key…", capX, 11, true)); hintFS:SetText("Esc leaves it as it was")
    elseif state == "bound" then
      local k = P.KeyCap(f, key, capX, 11, true); keep(k)
      keep(P.T(f, "hand", 17, C.green, "Bound", W - 13, 20, 22, { right = true })); hintFS:Hide()
    elseif state == "conflict" then
      hintFS:Hide()
      local c = CreateFrame("Frame", nil, f); c:SetSize(W, 76); P.At(c, f, 0, 0); c:SetFrameLevel(f:GetFrameLevel() + 4)
      local cb = P.Nine(c, "conf", W, 76, 8); cb:SetPoint("TOPLEFT")
      local k = P.KeyCap(c, key, 12, 10)
      P.T(c, "print", 15, C.title, "already does " .. color(C.red, old) .. ". Use it for " .. (which == "swap" and "swapping gear" or "fishing") .. " instead?", 12 + k.w + 6, 12, 19.5)
      P.LButton(c, "Use " .. key .. (which == "swap" and " to swap gear" or " for fishing"), 12, 38, nil, nil, 28, function() f.Show_("bound", key) end)
      P.LButton(c, "Pick another key", 170, 38, nil, "light", 28, function() f.Show_("listen") end)
      f.conf = c
    end
  end
  f:EnableKeyboard(false)
  f:SetScript("OnClick", function() P.Sound("click"); f.listening = true; f:EnableKeyboard(true); f.Show_("listen") end)
  f:SetScript("OnKeyDown", function(self, key)
    if not f.listening then return end
    if key == "ESCAPE" then f.listening = false; f:EnableKeyboard(false); f.Show_("unbound"); return end
    if key:find("SHIFT$") or key:find("CTRL$") or key:find("ALT$") or key == "UNKNOWN" then return end
    local chord = (IsAltKeyDown and IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown and IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown and IsShiftKeyDown() and "SHIFT-" or "") .. key
    f.listening = false; f:EnableKeyboard(false)
    local action = GetBindingAction and GetBindingAction(chord) or ""
    local text = GetBindingText and GetBindingText(chord, true) or chord
    if action ~= "" then f.Show_("conflict", text, (GetBindingName and GetBindingName(action)) or action)
    else f.Show_("bound", text) end
  end)
  f.Show_("listen")
  return f
end

-- ---------------------------------------------------------------- the book, the dim, the ribbons
local function stepIndex(key) for i, s in ipairs(STEPS) do if s.key == key then return i end end end

function P.ShowGuide(key, animate, steps)
  steps = steps or STEPS
  local G = P.guide
  if not G or G.steps ~= steps then
    if G then G.dim:Hide(); G.book:Hide() end
    G = { steps = steps, visited = {} }
    local dim = CreateFrame("Frame", nil, UIParent); dim:SetAllPoints(UIParent); dim:SetFrameStrata("HIGH"); dim:SetFrameLevel(1)
    local dt = P.Solid(dim, "060808", 0.58, "BACKGROUND"); dt:SetAllPoints()
    dim:EnableMouse(true)
    G.dim = dim
    local book = CreateFrame("Frame", "PagleArtGuideBook", UIParent, "PagleGuideBookTemplate")
    book:SetFrameStrata("DIALOG") -- over the dim (HIGH)
    book:SetBookSize(920, 600)
    book:SetSearchShown(false)
    G.book = book
    G.stepTxt = P.Txt(book.Strip, "gilt", 14, "C9B27A", "", { shadow = true, justify = "RIGHT" })
    G.stepTxt:SetPoint("RIGHT", book.Strip, "RIGHT", 0, 0)
    local views = {}
    for i, s in ipairs(steps) do
      local nav = {}
      local v = { key = s.key, order = i, crumbs = { "Pagle", "A field guide" } }
      nav.Next = function() local n = steps[i + 1]; if n then P.ShowView(book, n.key, true) end end
      nav.Back = function() local n = steps[i - 1]; if n then P.ShowView(book, n.key, true) end end
      nav.Skip = function() if i == 1 then P.HideGuide() else P.ShowView(book, steps[#steps].key, true) end end
      nav.Done = function() P.HideGuide(); if P.ShowEvening then P.ShowEvening() end end
      nav.BindingField = bindingField
      nav.Outside = function(fn) v.outside = fn end
      v.build = function(L, R) s.build(L, R, nav) end
      v.onShow = function(view)
        G.visited[i] = true
        G.stepTxt:SetText("|cfff6e3a8" .. i .. "|r of " .. #steps)
        if G.ribbons then G.ribbons.Set(i, G.visited, G.shown) end
        for _, o in ipairs(G.outside or {}) do o:Hide(); if o.arrow then o.arrow:Hide() end end
        G.outside = {}
        if view.outside then
          local n, a = view.outside(book)
          if n then G.outside = { n }; n:SetFrameStrata("DIALOG"); n:SetFrameLevel(book:GetFrameLevel() + 40); a:SetFrameStrata("DIALOG"); a:SetFrameLevel(book:GetFrameLevel() + 39) end
        end
      end
      views[i] = v
    end
    P.InitViews(book, views)
    G.ribbons = P.StepRibbons(book, steps, function(i) P.ShowView(book, steps[i].key, true) end)
    book:HookScript("OnHide", function() dim:Hide() end)
    P.guide = G
    book:Hide()
  end
  G.dim:Show()
  local was = G.book:IsShown()
  G.book:Show()
  P.FitToScreen(G.book, 950, 760, 40, 1) -- 920 x 600, the wax close and the ribbons below (ONB-R27)
  G.shown = was
  P.ShowView(G.book, key or (steps[1].key), animate and was)
  G.shown = true
  return G.book
end

function P.HideGuide()
  local G = P.guide
  if not G then return end
  for _, o in ipairs(G.outside or {}) do o:Hide(); if o.arrow then o.arrow:Hide() end end
  if G.book:IsShown() then P.CloseBook(G.book) end
  G.dim:Hide()
end

-- the guide with one part turned off (ONB-R21, "3 of 7"): every step but the Tackle Board's
function P.GuideWithout(key)
  local list = {}
  for _, s in ipairs(STEPS) do if s.key ~= key then list[#list + 1] = s end end
  return list
end
P.stepIndex = stepIndex
