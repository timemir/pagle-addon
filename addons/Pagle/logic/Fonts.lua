---@class PagleNS
local ns = select(2, ...)

-- Core's one per-locale font table (CORE-R9, ADR 0019 "Scripts and fonts"): which file draws a face in the active Pagle
-- language. A Latin language draws with the faces Pagle bundles; ruRU, koKR, zhCN and zhTW swap every face to the
-- client's own, because Pagle bundles no fonts for Cyrillic, Korean or Chinese. Every kit that sets a font (Core's art,
-- the Curio Shop, the Field kit, and each Module's) asks here, so the swap is written once. Pure Lua 5.1 (CORE-R7): it
-- reads no global, no `ns.L` and no client call, so it loads under the backend's replay driver
-- (spec/logic_alone_spec.lua). Nothing on the fold path calls it.

--- Where the bundled faces are (media/fonts/OFL-*.txt).
ns.BUNDLED_FONT_DIR = "Interface\\AddOns\\Pagle\\media\\fonts\\"

--- What draws if a face's file won't load: the client's own Latin face, in every language.
ns.FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"

--- The role of each bundled face, which is what the client's fonts are chosen by: `body` for IM Fell English and its
--- italic and small capitals (the print), `heading` for Marcellus (gilt, stamps and labels), `hand` for Caveat's three
--- cuts (the Angler's handwriting) and `mono` for Cutive Mono (a typewriter's text). The client has no italic, small
--- capitals or weights of its own, so a role is one file.
---@type table<string, "body"|"heading"|"hand"|"mono">
ns.FACE_ROLES = {
	["IMFeENrm28P.ttf"] = "body",
	["IMFeENit28P.ttf"] = "body",
	["IMFeENsc28P.ttf"] = "body",
	["Marcellus-Regular.ttf"] = "heading",
	["Caveat-Medium.ttf"] = "hand",
	["Caveat-SemiBold.ttf"] = "hand",
	["Caveat-Bold.ttf"] = "hand",
	["CutiveMono-Regular.ttf"] = "mono",
}

--- The client's face for each role, in each language that swaps (a language not here draws the bundled faces). The
--- paths are the standard Blizzard filenames of that client, and candidates until `/pagle dev fonts` shows which a
--- client really carries (#522, #523): a path the client lacks falls back to `ns.FALLBACK_FONT` (Faces:Set).
--- Cyrillic: the standard text font of the ruRU client; Korean: 2002 for text and 2002 Bold for headings, K_Pagetext
--- (the page text) for the hand; Simplified Chinese: AR Kai (standard text and heading) and AR Kai in its cursive
--- cut for the hand; Traditional Chinese: bHEI for text and heading, bKAI for the hand.
---@type table<string, table<string, string>>
ns.CLIENT_FONTS = {
	ruRU = {
		body = "Fonts\\FRIZQT___CYR.TTF",
		heading = "Fonts\\FRIZQT___CYR.TTF",
		hand = "Fonts\\FRIZQT___CYR.TTF",
		mono = "Fonts\\ARIALN.TTF",
	},
	koKR = {
		body = "Fonts\\2002.ttf",
		heading = "Fonts\\2002B.ttf",
		hand = "Fonts\\K_Pagetext.TTF",
		mono = "Fonts\\2002.ttf",
	},
	zhCN = {
		body = "Fonts\\ARKai_T.ttf",
		heading = "Fonts\\ARKai_T.ttf",
		hand = "Fonts\\ARKai_C.ttf",
		mono = "Fonts\\ARKai_T.ttf",
	},
	zhTW = {
		body = "Fonts\\bHEI00M.ttf",
		heading = "Fonts\\bHEI01B.ttf",
		hand = "Fonts\\bKAI00M.ttf",
		mono = "Fonts\\bHEI00M.ttf",
	},
}

--- The file that draws the bundled face `face` (its file name, such as "Caveat-Medium.ttf") in the Pagle language
--- `language`: the bundled face itself for a Latin language, the client's face for its role for ruRU, koKR, zhCN and
--- zhTW. A face with no role draws as the body.
---@param face string
---@param language string The Pagle language's Locale code ("enUS" for English).
---@return string
function ns.FaceFile(face, language)
	local fonts = ns.CLIENT_FONTS[language]
	if not fonts then
		return ns.BUNDLED_FONT_DIR .. face
	end
	return fonts[ns.FACE_ROLES[face] or "body"]
end

--- The faces of one Pagle language, read through `language` each time so a Language applied later is followed.
---@class PagleFaces
---@field package language fun(): string
---@field package tracked { font: Font, face: string, size: number, flags: string }[]
local Faces = {}
Faces.__index = Faces

--- A face set that follows `language`, the Pagle language applied this session as its Locale code.
---@param language fun(): string
---@return PagleFaces
function ns.NewFaces(language)
	return setmetatable({ language = language, tracked = {} }, Faces)
end

--- The file that draws `face` now (ns.FaceFile for the language applied).
---@param face string
---@return string
function Faces:File(face)
	return ns.FaceFile(face, self.language())
end

--- Puts `face` at `size` on a font object or a font string. If the client won't load the face's file, it draws in
--- `ns.FALLBACK_FONT`. Returns the file that loaded.
---@param target Font|FontString
---@param face string
---@param size number
---@param flags string?
---@return string file
function Faces:Set(target, face, size, flags)
	local file = self:File(face)
	if target:SetFont(file, size, flags or "") == false then
		file = ns.FALLBACK_FONT
		target:SetFont(file, size, flags or "")
	end
	return file
end

--- Like Set for a font object that may be made before the Language is applied (Core's art is built as its files load,
--- and the Language applies at ADDON_LOADED): the object is kept, and Refit sets it again.
---@param font Font
---@param face string
---@param size number
---@param flags string?
---@return string file
function Faces:Track(font, face, size, flags)
	self.tracked[#self.tracked + 1] = { font = font, face = face, size = size, flags = flags or "" }
	return self:Set(font, face, size, flags)
end

--- Sets every tracked font object again, after the Language applied.
function Faces:Refit()
	for _, kept in ipairs(self.tracked) do
		self:Set(kept.font, kept.face, kept.size, kept.flags)
	end
end

--- Gives Modules the swap (CORE-R9, API version 2): `Pagle.FaceFile(face)` is the file that draws a bundled face in
--- the active Pagle language, and `Pagle.SetFace(target, face, size, flags)` puts the face on a font object or a font
--- string, falling back to the client's FRIZQT__ if its file won't load. `face` is the bundled file's name, as a kit's
--- own face table holds it.
---@param Pagle table
---@param faces PagleFaces
function ns.PublishFaces(Pagle, faces)
	---@class Pagle
	local api = Pagle

	---@param face string
	---@return string
	function api.FaceFile(face)
		return faces:File(face)
	end

	---@param target Font|FontString
	---@param face string
	---@param size number
	---@param flags string?
	---@return string file
	function api.SetFace(target, face, size, flags)
		return faces:Set(target, face, size, flags)
	end
end
