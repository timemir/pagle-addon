-- PagleArtGuide / (forked from PagleArtBook) Fonts.lua
-- Design-system colours used by the book, and the book's font objects.
-- Fonts are bundled OFL faces (see Fonts/OFL-*.txt): IM Fell English for print, Caveat for the Angler's
-- handwriting, Marcellus for gilt, ribbons and brass. Sizes match the design system's type styles.

local ADDON, P = ...

local function hex(h) return CreateColorFromHexString("FF" .. h) end

P.Colors = {
  ["ink"] = hex("3A2614"), ["ink-title"] = hex("3E220C"), ["ink-small"] = hex("5A4028"),
  ["ink-kicker"] = hex("8A5A2A"), ["ink-note"] = hex("8A6A40"), ["ink-ghost"] = hex("B8A080"),
  ["hand-blue"] = hex("23407A"), ["hand-red"] = hex("9A2A1A"), ["hand-green"] = hex("2A6A2A"), ["hand-brown"] = hex("7A3A10"),
  ["gilt"] = hex("E8C96A"), ["gilt-light"] = hex("FFF4C8"),
  ["brass-text"] = hex("2A1A04"), ["wax-text"] = hex("F4DFA8"),
  ["parchment-field"] = hex("EFE0BB"), ["leather-trim"] = hex("8A5A2A"),
  ["ribbon"] = hex("9A2A1C"), ["wax"] = hex("D0402A"),
  ["ribbon-here"] = hex("2E5A28"), ["ribbon-here-on"] = hex("3E7A34"),
}

local DIR = [[Interface\AddOns\]] .. ADDON .. [[\Fonts\]]
local PRINT, ITALIC = DIR .. "IMFeENrm28P.ttf", DIR .. "IMFeENit28P.ttf"
local HAND, GILT = DIR .. "Caveat-Medium.ttf", DIR .. "Marcellus-Regular.ttf"

P.Fonts = {}
P.fontProblems = {}

local function font(key, file, size, color, shadow)
  local f = CreateFont("PagleArtGuideFont_" .. key)
  local ok = f:SetFont(file, size, "")
  if ok == false then
    -- the bundled file didn't load: fall back to a client font so the probe still shows something
    P.fontProblems[#P.fontProblems + 1] = key
    f:SetFontObject(GameFontNormal)
    f:SetFont((GameFontNormal:GetFont()), size, "")
  end
  f:SetTextColor(P.Colors[color]:GetRGB())
  if shadow then f:SetShadowColor(0, 0, 0, 1); f:SetShadowOffset(0, -1) else f:SetShadowOffset(0, 0) end
  f:SetJustifyH("LEFT")
  P.Fonts[key] = f
  return f
end

-- printed text on parchment
font("Title", PRINT, 26, "ink-title")
font("Kicker", PRINT, 12, "ink-kicker")        -- set in capitals: the client has no small caps
font("Body", PRINT, 14, "ink")
font("Small", PRINT, 13, "ink-small")
font("Note", ITALIC, 12, "ink-note")
font("Number", PRINT, 34, "ink-title")
font("Group", PRINT, 13, "ink-kicker")
-- handwriting
font("Hand", HAND, 20, "hand-blue")
font("HandRed", HAND, 18, "hand-red")
font("HandGreen", HAND, 18, "hand-green")
font("HandBrown", HAND, 18, "hand-brown")
-- on the leather, ribbons, brass, wax
font("Crumb", GILT, 14, "gilt", true)
font("CrumbHover", GILT, 14, "gilt-light", true)
font("Field", PRINT, 14, "ink")
font("FieldPlaceholder", ITALIC, 14, "ink-note")
font("Ribbon", GILT, 13, "wax-text", true)
font("Plate", GILT, 12, "brass-text")
font("Seal", GILT, 12, "wax-text")
font("SealEmpty", GILT, 12, "ink-ghost")
P.Fonts.Seal:SetJustifyH("CENTER"); P.Fonts.SealEmpty:SetJustifyH("CENTER")
