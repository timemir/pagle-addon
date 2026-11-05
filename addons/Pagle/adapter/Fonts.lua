---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Core's faces on the client (CORE-R9, logic/Fonts.lua): the file that draws each bundled face in the Pagle language
-- applied this session, or in the client's own language on a ruRU, koKR, zhCN or zhTW client. Core's kits ask `ns.faces`; Modules ask `Pagle.FaceFile` and `Pagle.SetFace` (API version 2).
-- Core's own font objects are made as its files load, before the Language applies at ADDON_LOADED, so the ones made
-- through `ns.faces:Track` are set again once it has (ns.ApplyLanguage).

-- The language the faces are chosen by: on a ruRU, koKR, zhCN or zhTW client the client's own, whatever the Pagle
-- language, since the names the client gives (items, zones) come in its script and the bundled faces can't draw it
-- (CORE-R9, 1.0.2's #553); on any other client the Pagle language.
local function faceLanguage()
	local client = GetLocale()
	if ns.CLIENT_FONTS[client] then
		return client
	end
	return ns.language
end

---@type PagleFaces
ns.faces = ns.NewFaces(faceLanguage)

-- The order a face's file is followed by the locale's other client faces when it won't load.
local ROLE_ORDER = { "body", "heading", "hand", "mono" }

--- The files Faces:Set tries for the bundled face `face` in the faces' language `language`, in order (CORE-R9): the
--- file ns.FaceFile gives, then for a client that swaps its faces (ns.CLIENT_FONTS) the locale's other faces in role
--- order (body, heading, hand, mono), then ns.FALLBACK_FONT, each once. A client that lacks its role's file draws in
--- another face of its own script before FRIZQT__, which has no Cyrillic, Hangul or Han: zhTW without bHEI00M and
--- bHEI01B draws in bKAI00M, koKR without K_Pagetext in 2002, zhCN without ARKai_C in ARKai_T, ruRU without
--- FRIZQT___CYR in ARIALN. The paths are logic/Fonts.lua's; none is written here.
---@param face string
---@param language string
---@return string[]
function ns.FaceCandidates(face, language)
	local files, seen = {}, {}
	local function add(file)
		if file and not seen[file] then
			seen[file] = true
			files[#files + 1] = file
		end
	end
	add(ns.FaceFile(face, language))
	local fonts = ns.CLIENT_FONTS[language]
	if fonts then
		for _, role in ipairs(ROLE_ORDER) do
			add(fonts[role])
		end
	end
	add(ns.FALLBACK_FONT)
	return files
end

-- logic/Fonts.lua's Faces:Set falls straight back to FRIZQT__; Core's faces try the locale's other faces first
-- (ns.FaceCandidates). Faces:Track, Faces:Refit and Pagle.SetFace all set through this, so Core's kits and every
-- Module's get it. Returns the file that loaded.
---@param target Font|FontString
---@param face string
---@param size number
---@param flags string?
---@return string file
function ns.faces.Set(_, target, face, size, flags)
	local files = ns.FaceCandidates(face, faceLanguage())
	for i, file in ipairs(files) do
		if target:SetFont(file, size, flags or "") ~= false or i == #files then
			return file
		end
	end
	return ns.FALLBACK_FONT
end

ns.PublishFaces(Pagle, ns.faces)

--- What a client's own faces lack of the characters Pagle's strings use, and what is drawn in its place, by client
--- code (CORE-R9). On a ruRU, koKR, zhCN or zhTW client every face is the client's whatever the Language
--- (faceLanguage), so English, Spanish or German there draws in fonts made for another script. From the fonts' cmaps
--- (ruRU's on build 1.60.1.70790 and in game; the others from the client's CASC files, unchanged since 6.0.1, not yet
--- seen in game): FRIZQT___CYR (ruRU's body, heading and hand) has no middle dot, so the separator draws as the bullet,
--- which it and ARIALN both have; ARKai_T and ARKai_C (zhCN) and bHEI00M, bHEI01B and bKAI00M (zhTW) have no
--- guillemets but have the curly double quotes, so a guillemet draws as swapGuillemets says. koKR's 2002 and 2002B have
--- every character the strings use; K_Pagetext, its hand, lacks the dashes and the bullet but is left alone, as the
--- body text would lose them for it. A Locale's own strings already keep to its fonts (data/glyphs.toml [without]), so
--- the swap changes nothing in them.

-- The guillemets « and » in UTF-8: the lead byte 0xC2, which no other character's bytes contain past their first,
-- then 0xAB or 0xBB. And the curly double quotes “ and ”.
local GUILLEMET, LEFT_GUILLEMET = "\194[\171\187]", "\194\171"
local OPEN_QUOTE, CLOSE_QUOTE = "\226\128\156", "\226\128\157"

-- Whether `char` (a string's byte, "" past either end) leaves a guillemet beside it standing apart: an end of the
-- string, a space, or the pseudo-locale's brackets round the whole string.
---@param char string
---@return boolean
local function apart(char)
	return char == "" or char:find("^[%s%[%]]") ~= nil
end

-- `text` with each guillemet given its zhCN and zhTW stand-in. The strings use them two ways. An arrow stands apart,
-- between spaces or at an end ("Next »", "« back", "Settings » Announcements", in every Language), and draws as "<"
-- or ">". A quotation mark touches the words it holds (German's »Wie im Spiel«, Spanish's and Russian's «…»), and
-- draws as the curly quotes, “ then ”, by turns along the string, whichever way the Language points them: as ">" and
-- "<" German's would read backwards.
---@param text string
---@return string
local function swapGuillemets(text)
	local at = text:find(GUILLEMET)
	if not at then
		return text
	end
	local parts, from, open = {}, 1, false
	while at do
		local stand
		if apart(text:sub(at - 1, at - 1)) and apart(text:sub(at + 2, at + 2)) then
			stand = text:sub(at, at + 1) == LEFT_GUILLEMET and "<" or ">"
		else
			stand = open and CLOSE_QUOTE or OPEN_QUOTE
			open = not open
		end
		parts[#parts + 1] = text:sub(from, at - 1)
		parts[#parts + 1] = stand
		from = at + 2
		at = text:find(GUILLEMET, from)
	end
	parts[#parts + 1] = text:sub(from)
	return table.concat(parts)
end

---@type table<string, fun(text: string): string>
ns.CLIENT_GLYPHS = {
	ruRU = function(text)
		return (text:gsub("\194\183", "\226\128\162"))
	end,
	zhCN = swapGuillemets,
	zhTW = swapGuillemets,
}

-- Gives every string of `t` at any depth the stand-ins `swap` makes; answers whether one changed.
---@param t table
---@param swap fun(text: string): string
---@param seen table<table, true>
---@return boolean
local function swapGlyphs(t, swap, seen)
	local changed = false
	for key, value in pairs(t) do
		if type(value) == "string" then
			local text = swap(value)
			if text ~= value then
				t[key] = text
				changed = true
			end
		elseif type(value) == "table" and not seen[value] then
			seen[value] = true
			changed = swapGlyphs(value, swap, seen) or changed
		end
	end
	return changed
end

--- Draws the string table `L` in the client's faces (CORE-R9): every string and every form of a counted string, at
--- any depth, takes ns.CLIENT_GLYPHS' stand-in for each character the client `client`'s faces lack, in place, as the
--- Locale's function and the pseudo-locale write it (files cache `local L = ns.L`). Dev text too, as it draws in the
--- same faces. Nothing on a client not in ns.CLIENT_GLYPHS. Answers whether it changed `L`. Nothing machine-read
--- (the Paste string, the Field report) is built from `ns.L`, so it keeps every byte.
---@param L any
---@param client any The client's `GetLocale()`.
---@return boolean changed
function ns.ApplyClientGlyphs(L, client)
	local swap = ns.CLIENT_GLYPHS[client]
	if type(L) ~= "table" or not swap then
		return false
	end
	return swapGlyphs(L, swap, { [L] = true })
end

--- Applies ns.ApplyClientGlyphs to a Module's string table `L` as its files load, after its Locale and the pseudo-locale
--- (locale/Apply.lua), on this client. Answers whether it changed `L`. A version-2 name (CORE-R15), added in 1.1.1.
---@param L table
---@return boolean
function Pagle.ApplyClientGlyphs(L)
	return ns.ApplyClientGlyphs(L, GetLocale())
end
