---@class PagleNS
local ns = select(2, ...)

-- The news sign's art (core/news-sign.md, SIGN-R30): written by the sign kit's source/pack.py, so change the kit
-- and run it, not this file. One shared atlas (glows, particles, the new emblems) and one per look, 2 texels a
-- unit; each sprite's box is its size in UI units. Each joins ns.ATLASES by name.

local DIR = "Interface\\AddOns\\Pagle\\media\\sign\\"

ns.ATLASES = ns.ATLASES or {}

ns.ATLASES["SignCommon"] = {
	file = DIR .. "SignCommon",
	width = 512,
	height = 512,
	scale = 2,
	sprites = {
		["disc"] = { x = 432, y = 132, w = 64, h = 64, box = { 0, 0, 32, 32 } },
		["dot"] = { x = 28, y = 264, w = 32, h = 32, box = { 0, 0, 16, 16 } },
		["drop"] = { x = 0, y = 264, w = 24, h = 38, box = { 0, 0, 12, 19 } },
		["glow"] = { x = 0, y = 0, w = 128, h = 128, box = { 0, 0, 64, 64 } },
		["laurel"] = { x = 264, y = 0, w = 128, h = 128, box = { 0, 0, 64, 64 } },
		["medal"] = { x = 0, y = 132, w = 128, h = 128, box = { 0, 0, 64, 64 } },
		["pixel"] = { x = 92, y = 264, w = 8, h = 8, box = { 0, 0, 4, 4 } },
		["puff"] = { x = 264, y = 132, w = 96, h = 96, box = { 0, 0, 48, 48 } },
		["ring"] = { x = 132, y = 0, w = 128, h = 128, box = { 0, 0, 64, 64 } },
		["sparkle"] = { x = 364, y = 132, w = 64, h = 64, box = { 0, 0, 32, 32 } },
		["sucker"] = { x = 64, y = 264, w = 24, h = 24, box = { 0, 0, 12, 12 } },
		["tape"] = { x = 132, y = 132, w = 128, h = 128, box = { 0, 0, 64, 64 } },
	},
}
ns.ATLASES["SignWood"] = {
	file = DIR .. "SignWood",
	width = 1024,
	height = 512,
	scale = 2,
	sprites = {
		["board"] = { x = 0, y = 0, w = 856, h = 312, box = { 0, 0, 428, 156 } },
		["rope"] = { x = 500, y = 316, w = 20, h = 48, box = { 0, 0, 10, 24 } },
		["tag"] = { x = 0, y = 316, w = 496, h = 116, box = { 0, 0, 248, 58 } },
	},
}
ns.ATLASES["SignScroll"] = {
	file = DIR .. "SignScroll",
	width = 1024,
	height = 512,
	scale = 2,
	sprites = {
		["bobber"] = { x = 848, y = 0, w = 40, h = 68, box = { 0, 0, 20, 34 } },
		["paper"] = { x = 0, y = 0, w = 688, h = 312, box = { 0, 0, 344, 156 } },
		["rod"] = { x = 0, y = 316, w = 800, h = 52, box = { 0, 0, 400, 26 } },
		["roller"] = { x = 0, y = 372, w = 800, h = 52, box = { 0, 0, 400, 26 } },
		["seal"] = { x = 692, y = 0, w = 152, h = 152, box = { 0, 0, 76, 76 } },
	},
}
ns.ATLASES["SignLantern"] = {
	file = DIR .. "SignLantern",
	width = 1024,
	height = 1024,
	scale = 2,
	sprites = {
		["bar"] = { x = 132, y = 260, w = 880, h = 80, box = { 0, 0, 440, 40 } },
		["chain"] = { x = 0, y = 488, w = 24, h = 48, box = { 0, 0, 12, 24 } },
		["lantern"] = { x = 812, y = 0, w = 128, h = 224, box = { 0, 0, 64, 112 } },
		["lit"] = { x = 0, y = 260, w = 128, h = 224, box = { 0, 0, 64, 112 } },
		["pane"] = { x = 0, y = 0, w = 808, h = 256, box = { 0, 0, 404, 128 } },
	},
}
ns.ATLASES["SignKraken"] = {
	file = DIR .. "SignKraken",
	width = 1024,
	height = 512,
	scale = 2,
	sprites = {
		["tablet"] = { x = 0, y = 0, w = 824, h = 300, box = { 0, 0, 412, 150 } },
	},
}
ns.ATLASES["SignAstro"] = {
	file = DIR .. "SignAstro",
	width = 1024,
	height = 1024,
	scale = 2,
	sprites = {
		["arm"] = { x = 568, y = 0, w = 280, h = 280, box = { 0, 0, 140, 140 } },
		["inner"] = { x = 284, y = 0, w = 280, h = 280, box = { 0, 0, 140, 140 } },
		["outer"] = { x = 0, y = 0, w = 280, h = 280, box = { 0, 0, 140, 140 } },
		["plate"] = { x = 0, y = 284, w = 808, h = 256, box = { 0, 0, 404, 128 } },
	},
}
ns.ATLASES["SignCoral"] = {
	file = DIR .. "SignCoral",
	width = 1024,
	height = 1024,
	scale = 2,
	sprites = {
		["kelp1"] = { x = 0, y = 404, w = 92, h = 260, box = { 0, 0, 46, 130 } },
		["kelp2"] = { x = 96, y = 404, w = 92, h = 260, box = { 0, 0, 46, 130 } },
		["plaque"] = { x = 0, y = 0, w = 960, h = 400, box = { 0, 0, 480, 200 } },
	},
}
