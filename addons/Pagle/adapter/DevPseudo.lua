---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The development pseudo-locale (#524, CORE-R8, ADR 0019 "Scripts and fonts"): a runtime transform of an addon's English
-- `ns.L` that pads each string by about 40%, swaps its Latin letters for accented ones and, for some, Cyrillic
-- look-alikes, and wraps it in [brackets], so a layout that would break under a long translation breaks now. It ships no
-- locale file, so CORE-R9 gives it no glyph range to need: every accented and Cyrillic letter below is written as a
-- code point, and spec/Pagle/adapter/DevPseudo_spec.lua fails on a non-ASCII byte in this file. Cyrillic is drawn only by
-- Caveat among the bundled faces; in the Latin-only ones a Cyrillic letter is a box, so what the box shows is its width.
-- The point is length and wrapping, not legibility.
--
-- It is not a Language: it is never registered with `ns.Locale`, never listed or offered, and `Pagle.GetLanguage()` stays
-- "enUS" while it is on, so the font table swaps no face for it. `/pagle dev pseudo on` saves PagleDB.global.devPseudo
-- (logic/Dev.lua); Core applies it at the next ADDON_LOADED in place of the Language (adapter/Text.lua's
-- ns.ApplyLanguage), a Module through `Pagle.ApplyPseudoLocale` as its files load (locale/Apply.lua).

--- The letter a Latin letter becomes, as a code point. Accented Latin-1 and Latin Extended-A letters, which every
--- bundled face draws, and for c, p, x, y and some capitals the Cyrillic letter that looks like it. b, f, m, q and v
--- stay as they are.
---@type table<string, integer>
local LOOKALIKES = {
	a = 0xE5,
	c = 0x441,
	d = 0x10F,
	e = 0xE9,
	g = 0x11F,
	h = 0x127,
	i = 0xEF,
	j = 0x135,
	k = 0x137,
	l = 0x13A,
	n = 0xF1,
	o = 0xF6,
	p = 0x440,
	r = 0x155,
	s = 0x161,
	t = 0x163,
	u = 0xFC,
	w = 0x175,
	x = 0x445,
	y = 0x443,
	z = 0x17E,
	A = 0x410,
	B = 0x412,
	C = 0x10C,
	D = 0x10E,
	E = 0x415,
	G = 0x11E,
	H = 0x41D,
	I = 0xCF,
	J = 0x134,
	K = 0x41A,
	L = 0x139,
	M = 0x41C,
	N = 0xD1,
	O = 0xD6,
	P = 0x420,
	R = 0x154,
	S = 0x160,
	T = 0x422,
	U = 0xDC,
	W = 0x174,
	X = 0x425,
	Y = 0xDD,
	Z = 0x17D,
}

--- The letters the padding is made of, as code points (accented Latin Extended-A).
---@type integer[]
local PAD = { 0x115, 0x16D, 0x151, 0x129, 0x11D }

--- A code point below U+0800 as UTF-8, which is all the tables above hold.
---@param point integer
---@return string
local function utf8Char(point)
	return string.char(0xC0 + math.floor(point / 0x40), 0x80 + point % 0x40)
end

---@type table<string, string>
local REPLACEMENT = {}
for letter, point in pairs(LOOKALIKES) do
	REPLACEMENT[letter] = utf8Char(point)
end
---@type string[]
local PAD_CHARS = {}
for i, point in ipairs(PAD) do
	PAD_CHARS[i] = utf8Char(point)
end

--- The padding a string of `length` code points gets: ceil(2 * length / 5) code points, so the whole is at least 1.4
--- times as long once the two brackets are added. Words of five letters, a space before each, never ending in a space.
---@param length integer
---@return string
local function padding(length)
	local count = math.floor((length * 2 + 4) / 5)
	local out = {}
	for i = 1, count do
		if i % 6 == 1 and i < count then
			out[i] = " "
		else
			out[i] = PAD_CHARS[i % #PAD_CHARS + 1]
		end
	end
	return table.concat(out)
end

--- The last byte of the protected span that starts at `at` in `text`, or nil if a literal character starts there. A
--- span is a field (`{name}`, `{name:spec}`), a brace escape (`{{`, `}}`), a colour code (`|c` and eight hex digits),
--- a texture, atlas, link payload or key-binding escape up to its closing letter (`|T...|t`, `|A...|a`, `|H...|h`, `|K...|k`),
--- any other `|` and the character after it (`|r`, `|n`, `||`), and a slash command word (`/pagle`) that does not follow
--- a letter or digit. Only the literal text outside them changes.
---@param text string
---@param at integer
---@param afterWord boolean Whether the character before `at` is a letter or digit.
---@return integer?
local function span(text, at, afterWord)
	local char = text:sub(at, at)
	if char == "{" then
		if text:sub(at + 1, at + 1) == "{" then
			return at + 1
		end
		local _, close = text:find("^{[%w_]+}", at)
		if not close then
			_, close = text:find("^{[%w_]+:%w+}", at)
		end
		return close
	elseif char == "}" then
		return text:sub(at + 1, at + 1) == "}" and at + 1 or nil
	elseif char == "|" then
		local kind = text:sub(at + 1, at + 1)
		if kind == "c" and text:find("^%x%x%x%x%x%x%x%x", at + 2) then
			return at + 9
		elseif kind == "T" or kind == "A" or kind == "H" or kind == "K" then
			local _, close = text:find("|" .. kind:lower(), at + 2, true)
			return close or #text
		end
		return kind == "" and at or at + 1
	elseif char == "/" and not afterWord then
		local _, close = text:find("^/%a[%w_]*", at)
		return close
	end
	return nil
end

--- A string as the pseudo-locale writes it: its literal letters swapped, about 40% more characters after them, and
--- the whole in [brackets]. A string with no literal letter (a join such as ", ", a symbol, a bare field or an icon) and
--- anything that is not a string comes back as it is.
---@param text any
---@return any
function ns.PseudoText(text)
	if type(text) ~= "string" then
		return text
	end
	local out, at, letters, afterWord = {}, 1, 0, false
	while at <= #text do
		local close = span(text, at, afterWord)
		if close then
			out[#out + 1] = text:sub(at, close)
			at, afterWord = close + 1, false
		else
			local char = text:sub(at, at)
			local replacement = REPLACEMENT[char]
			if char:find("%a") then
				letters = letters + 1
			end
			out[#out + 1] = replacement or char
			afterWord = char:find("%w") ~= nil
			at = at + 1
		end
	end
	if letters == 0 then
		return text
	end
	local _, length = text:gsub("[^\128-\191]", "")
	return "[" .. table.concat(out) .. padding(length) .. "]"
end

---@type table<table, true>
local applied = setmetatable({}, { __mode = "k" })

---@param t table
---@param top boolean
---@param seen table<table, true>
local function overlay(t, top, seen)
	for key, value in pairs(t) do
		-- Dev text stays English (ADR 0019): a top-level DEV_ key, a counted string's forms included.
		if not (top and type(key) == "string" and key:find("^DEV_")) then
			if type(value) == "string" then
				t[key] = ns.PseudoText(value)
			elseif type(value) == "table" and not seen[value] then
				seen[value] = true
				overlay(value, false, seen)
			end
		end
	end
end

--- Writes the pseudo-locale into the string table `L` in place, every string and every form of a counted string, at any
--- depth, the way a Locale's function does (about 36 files cache `local L = ns.L`). A top-level `DEV_` key stays
--- English. A table is done once: a second call changes nothing and answers false.
---@param L table
---@return boolean changed
function ns.PseudoLocalize(L)
	if type(L) ~= "table" or applied[L] then
		return false
	end
	applied[L] = true
	overlay(L, true, { [L] = true })
	return true
end

--- Whether the pseudo-locale is on, read from the raw `_G.PagleDB` before AceDB wraps it, as ns.ReadLanguageSetting
--- reads the Language: `PagleDB.global.dev` and `PagleDB.global.devPseudo` both exactly `true`. The flag is the dev
--- mode's, so with dev mode off it applies nothing. Anything else, however it came to be, is false. It never raises.
---@param saved any The raw PagleDB the client loaded, or nil on a first login.
---@return boolean
function ns.ReadPseudoSetting(saved)
	local ok, on = pcall(function()
		local global = rawget(saved, "global")
		return rawget(global, "dev") == true and rawget(global, "devPseudo") == true
	end)
	return ok and on == true
end

--- Whether the pseudo-locale is applied this session: `ns.ApplyLanguage` sets it from the saved flag, and a change
--- through `/pagle dev pseudo` waits for the next /reload.
---@type boolean
ns.pseudo = false

--- Applies the pseudo-locale to a Module's string table `L` as its files load, when it is on this session (locale/Apply.lua),
--- and answers whether it changed `L`. Does nothing with it off. Added in API version 2.
---@param L table
---@return boolean
function Pagle.ApplyPseudoLocale(L)
	if not ns.pseudo then
		return false
	end
	return ns.PseudoLocalize(L)
end
