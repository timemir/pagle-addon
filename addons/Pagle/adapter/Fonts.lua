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

ns.PublishFaces(Pagle, ns.faces)
