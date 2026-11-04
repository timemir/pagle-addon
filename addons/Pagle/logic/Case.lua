---@class PagleNS
local ns = select(2, ...)

-- Core's one case helper (CORE-R8, ADR 0019 "The text helper"): upper case, lower case and a search fold for UTF-8
-- text. The client's `string.upper` and `string.lower` are ASCII-only, so "ñ" stays "ñ" and a small-capitals heading in
-- Spanish, German or Russian keeps its lower-case letters. This maps Latin-1, Latin Extended-A and basic Cyrillic and
-- passes every other script through whole. Pure Lua 5.1 (CORE-R7): it reads no global but `string`, `table` and
-- `math`, no `ns.L` and no client call, so it loads under the backend's replay driver (spec/logic_alone_spec.lua).
-- Nothing on the fold path calls it. Its tables are built from code points, not written as letters, since `logic/`
-- keeps CORE-R9's base glyph set.

--- Code point `code` (below U+0800) as UTF-8.
---@param code integer
---@return string
local function utf8(code)
	if code < 0x80 then
		return string.char(code)
	end
	return string.char(0xC0 + math.floor(code / 64), 0x80 + code % 64)
end

-- Upper case by lower case, and the reverse, as UTF-8 byte pairs: the letters that have a one-letter other case.
---@type table<string, string>
local UPPER, LOWER = {}, {}

--- Records that lower-case letter `small` and upper-case letter `capital` (code points) are a pair.
---@param small integer
---@param capital integer
local function pair(small, capital)
	UPPER[utf8(small)] = utf8(capital)
	LOWER[utf8(capital)] = utf8(small)
end

-- Latin-1: à to þ over À to Þ, but for the multiplication and division signs. ß (U+00DF) has no capital of one letter in
-- the bundled faces (U+1E9E is outside them) and "SS" would change the text's length, so it stays as it is in both.
for small = 0xE0, 0xFE do
	if small ~= 0xF7 then
		pair(small, small - 0x20)
	end
end
pair(0xFF, 0x178)

-- Latin Extended-A: most of it pairs an even capital with the odd small letter after it, and the middle run (U+0139 to
-- U+0148) and the last (U+0179 to U+017E) the other way round. The Turkish dotted and dotless I (U+0130, U+0131), ĸ, ŉ
-- and the long s (U+017F) have no pair in the language-neutral mapping and stay as they are.
for capital = 0x100, 0x136, 2 do
	if capital ~= 0x130 then
		pair(capital + 1, capital)
	end
end
for capital = 0x139, 0x147, 2 do
	pair(capital + 1, capital)
end
for capital = 0x14A, 0x176, 2 do
	pair(capital + 1, capital)
end
for capital = 0x179, 0x17D, 2 do
	pair(capital + 1, capital)
end

-- Basic Cyrillic: а to я over А to Я, ѐ to џ over Ѐ to Џ, and Ukrainian ґ over Ґ.
for small = 0x430, 0x44F do
	pair(small, small - 0x20)
end
for small = 0x450, 0x45F do
	pair(small, small - 0x50)
end
pair(0x491, 0x490)

-- What a search ignores besides case: the accents of the lower-case Latin-1 and Latin Extended-A letters, as the plain
-- letters (or letter pairs) they are written with, and ё as е. A search folds both the typed text and the name.
---@type table<string, string>
local PLAIN = {}

--- Records that each of `codes` (lower-case code points) folds to `plain`.
---@param plain string
---@param codes integer[]
local function plainly(plain, codes)
	for i = 1, #codes do
		PLAIN[utf8(codes[i])] = plain
	end
end

plainly("a", { 0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0x101, 0x103, 0x105 })
plainly("ae", { 0xE6 })
plainly("c", { 0xE7, 0x107, 0x109, 0x10B, 0x10D })
plainly("d", { 0xF0, 0x10F, 0x111 })
plainly("e", { 0xE8, 0xE9, 0xEA, 0xEB, 0x113, 0x115, 0x117, 0x119, 0x11B })
plainly("g", { 0x11D, 0x11F, 0x121, 0x123 })
plainly("h", { 0x125, 0x127 })
plainly("i", { 0xEC, 0xED, 0xEE, 0xEF, 0x129, 0x12B, 0x12D, 0x12F, 0x131 })
plainly("j", { 0x135 })
plainly("k", { 0x137 })
plainly("l", { 0x13A, 0x13C, 0x13E, 0x140, 0x142 })
plainly("n", { 0xF1, 0x144, 0x146, 0x148 })
plainly("o", { 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF8, 0x14D, 0x14F, 0x151 })
plainly("oe", { 0x153 })
plainly("r", { 0x155, 0x157, 0x159 })
plainly("s", { 0x15B, 0x15D, 0x15F, 0x161 })
plainly("ss", { 0xDF })
plainly("t", { 0x163, 0x165, 0x167 })
plainly("th", { 0xFE })
plainly("u", { 0xF9, 0xFA, 0xFB, 0xFC, 0x169, 0x16B, 0x16D, 0x16F, 0x171, 0x173 })
plainly("w", { 0x175 })
plainly("y", { 0xFD, 0xFF, 0x177 })
plainly("z", { 0x17A, 0x17C, 0x17E })
PLAIN[utf8(0x451)] = utf8(0x435)

-- A two-byte letter: its lead byte (U+00C0 to U+04BF) and its continuation byte.
local LETTER = "[\195-\210][\128-\191]"

--- `text` in upper case: ASCII, Latin-1, Latin Extended-A and basic Cyrillic letters become capitals, ß and every other
--- script stay as they are. A byte that is not UTF-8 this knows is kept.
---@param text string
---@return string
function ns.Upper(text)
	text = text:gsub("[a-z]+", string.upper)
	if text:find("[\195-\210]") then
		text = text:gsub(LETTER, UPPER)
	end
	return text
end

--- `text` in lower case: the reverse of ns.Upper, letter by letter (what ns.Upper leaves, this leaves).
---@param text string
---@return string
function ns.Lower(text)
	text = text:gsub("[A-Z]+", string.lower)
	if text:find("[\195-\210]") then
		text = text:gsub(LETTER, LOWER)
	end
	return text
end

--- `text` with its first letter in capitals (a whole code point, so "éclair" becomes "Éclair").
---@param text string
---@return string
function ns.UpperFirst(text)
	local first = text:match("^[%z\1-\127\194-\244][\128-\191]*")
	if not first then
		return text
	end
	return ns.Upper(first) .. text:sub(#first + 1)
end

--- `text` folded for a search: lower case, and without the accents of Latin-1 and Latin Extended-A letters (ß as "ss",
--- æ as "ae", ё as е), so a plain "cafe" finds "Café". Two texts are equal for a search exactly when their folds are
--- equal, and one holds the other when the fold of one holds the fold of the other. Never for a name that is drawn.
---@param text string
---@return string
function ns.FoldCase(text)
	text = ns.Lower(text)
	if text:find("[\195-\210]") then
		text = text:gsub(LETTER, PLAIN)
	end
	return text
end

--- Publishes the case helper on `Pagle` as `Pagle.Upper`, `Pagle.Lower` and `Pagle.FoldCase` (CORE-R8), for Modules'
--- small capitals, headings and searches. Added in API version 2.
---@param Pagle table
function ns.PublishCase(Pagle)
	---@class Pagle
	local api = Pagle
	--- `text` in capitals, UTF-8 aware (Latin-1, Latin Extended-A, basic Cyrillic; ß and other scripts as they are).
	---@type fun(text: string): string
	api.Upper = ns.Upper
	--- `text` in lower case, the reverse of Pagle.Upper.
	---@type fun(text: string): string
	api.Lower = ns.Lower
	--- `text` folded for a search: lower case without accents. Compare or search folded text, never draw it.
	---@type fun(text: string): string
	api.FoldCase = ns.FoldCase
end
