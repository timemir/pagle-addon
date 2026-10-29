---@class PagleNS
local ns = select(2, ...)

-- The book binding's own art (core/book-binding.md, BIND-R13), added to ns.ATLASES by name beside the books' shell
-- (data/GuideArt.lua's Book atlas: the band and the vignette). The textures are in media/books, BLP (DXT5).
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

-- A part of BindingParts2 at its 2 texels a unit: its rectangle in texels, drawn w / 2 x h / 2.
---@param x integer
---@param y integer
---@param w integer
---@param h integer
---@return PagleAtlasSprite
local function part(x, y, w, h)
	return { x = x, y = y, w = w, h = h, box = { 0, 0, w / 2, h / 2 } }
end

-- BindingParts2 (1024 x 1024, 2 texels a unit, with mips): the Curio Shop's round-two bindings' own parts, from the
-- round-two kit's goods.json (BIND-R14, BIND-R15, BIND-R17): each one's corner piece (76 square, the top-left one,
-- mirrored for the others), its clasp (110 high) and its silk ribbon (32 x 136, of which the renderer shows the foot, BIND-R15). Shagreen and Bone's are the kit's
-- `-shagreen` sprites.
ns.ATLASES.BindingParts2 = {
	file = "Interface\\AddOns\\Pagle\\media\\books\\BindingParts2",
	width = 1024,
	height = 1024,
	scale = 2,
	sprites = {
		["corner-wave"] = part(314, 226, 152, 152),
		["corner-logbook"] = part(322, 2, 152, 152),
		["corner-heartwood"] = part(306, 674, 152, 152),
		["corner-shagreenbone"] = part(306, 830, 152, 152),
		["corner-stormglass"] = part(430, 382, 152, 152),
		["corner-lacquer"] = part(470, 158, 152, 152),
		["corner-knit"] = part(478, 2, 152, 152),
		["corner-flywallet"] = part(634, 2, 152, 152),
		["corner-carapace"] = part(790, 2, 152, 152),
		["corner-ember"] = part(626, 158, 152, 152),
		["clasp-wave"] = part(158, 674, 144, 220),
		["clasp-logbook"] = part(2, 226, 176, 220),
		["clasp-heartwood"] = part(198, 2, 120, 220),
		["clasp-shagreenbone"] = part(182, 226, 128, 220),
		["clasp-stormglass"] = part(2, 450, 160, 220),
		["clasp-lacquer"] = part(782, 158, 100, 220),
		["clasp-knit"] = part(306, 450, 120, 220),
		["clasp-flywallet"] = part(2, 674, 152, 220),
		["clasp-carapace"] = part(2, 2, 192, 220),
		["clasp-ember"] = part(166, 450, 136, 220),
		["ribbon-wave"] = part(946, 2, 64, 272),
		["ribbon-logbook"] = part(886, 278, 64, 272),
		["ribbon-heartwood"] = part(954, 278, 64, 272),
		["ribbon-shagreenbone"] = part(586, 314, 64, 272),
		["ribbon-stormglass"] = part(462, 538, 64, 272),
		["ribbon-lacquer"] = part(654, 314, 64, 272),
		["ribbon-knit"] = part(722, 382, 64, 272),
		["ribbon-flywallet"] = part(790, 382, 64, 272),
		["ribbon-carapace"] = part(530, 658, 64, 272),
		["ribbon-ember"] = part(598, 590, 64, 272),
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
