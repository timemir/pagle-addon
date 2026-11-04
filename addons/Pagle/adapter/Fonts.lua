---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Core's faces on the client (CORE-R9, logic/Fonts.lua): the file that draws each bundled face in the Pagle language
-- applied this session. Core's kits ask `ns.faces`; Modules ask `Pagle.FaceFile` and `Pagle.SetFace` (API version 2).
-- Core's own font objects are made as its files load, before the Language applies at ADDON_LOADED, so the ones made
-- through `ns.faces:Track` are set again once it has (ns.ApplyLanguage).

---@type PagleFaces
ns.faces = ns.NewFaces(function()
	return ns.language
end)

ns.PublishFaces(Pagle, ns.faces)
