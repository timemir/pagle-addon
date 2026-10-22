---@class PagleNS
local ns = select(2, ...)

-- The book binding's own art (core/book-binding.md, BIND-R13), added to ns.ATLASES by name beside the books' shell
-- (data/GuideArt.lua's Book atlas: the band and the vignette). Both textures are in media/books, BLP (DXT5).
--   BindingCorners (1024 x 128, 128 / 44 texels a UI unit): the open book's corner pieces of each metal, each the
--     top-left corner, 44 units square, mirrored for the other three. No kit has them: they were drawn for the Curio
--     Shop expansion from its kit's corner shapes and encoded with scripts/encode-blp.py, and this entry written by
--     hand to match (moved from the Ledger's media/journal, #351).
--   BindingGilt (128 x 128, 2 texels a unit, with mips): Verdigris's gilt corner, from the books kit v2's
--     BookParts.tga. It is a copy of Hunts' HuntsParts texture, whose other sprites Core never reads.

ns.ATLASES = ns.ATLASES or {}

ns.ATLASES.BindingCorners = {
	file = "Interface\\AddOns\\Pagle\\media\\books\\BindingCorners",
	width = 1024,
	height = 128,
	scale = 128 / 44,
	sprites = {
		["corner-brass"] = { x = 0, y = 0, w = 128, h = 128, box = { 0, 0, 44, 44 } },
		["corner-gold"] = { x = 128, y = 0, w = 128, h = 128, box = { 0, 0, 44, 44 } },
		["corner-silver"] = { x = 256, y = 0, w = 128, h = 128, box = { 0, 0, 44, 44 } },
		["corner-iron"] = { x = 384, y = 0, w = 128, h = 128, box = { 0, 0, 44, 44 } },
		["corner-bone"] = { x = 512, y = 0, w = 128, h = 128, box = { 0, 0, 44, 44 } },
		["corner-pearl"] = { x = 640, y = 0, w = 128, h = 128, box = { 0, 0, 44, 44 } },
		["corner-silverfiligree"] = { x = 768, y = 0, w = 128, h = 128, box = { 0, 0, 44, 44 } },
	},
}

ns.ATLASES.BindingGilt = {
	file = "Interface\\AddOns\\Pagle\\media\\books\\BindingGilt",
	width = 128,
	height = 128,
	scale = 2,
	sprites = {
		["corner"] = { x = 0, y = 0, w = 80, h = 80, box = { 0, 0, 40, 40 } },
	},
}
