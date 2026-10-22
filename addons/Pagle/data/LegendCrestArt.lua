---@class PagleNS
local ns = select(2, ...)

-- The Legend crests (ledger.md › LED-R153, announcements.md › UI › Splash), as the Prestige frames kit's art.json has
-- them: each crest's atlas (media/legends/Legend<Key>, 1.5 texels a unit) joins ns.ATLASES by name, and its art, by
-- key in ns.LEGEND_CREST_ART, has its layers in draw order (each sprite's box in the kit's 260 x 280 crest box, its
-- z, blend and motion: `alpha` keys { at, alpha }, `transform` keys { at, x, y, rotate, sx, sy } about `origin`, in
-- box units, as data/ToastStyleArt2.lua's) and its label (the plaque's word, where its line's top sits and its ink).
-- The well, where a Legend's icon sits masked round, is ns.LEGEND_CREST_WELL. Change the kit and this file together.

local DIR = "Interface\\AddOns\\Pagle\\media\\legends\\"

ns.ATLASES = ns.ATLASES or {}

--- The crest box every crest is drawn in, in UI units at full size, and its well's circle.
ns.LEGEND_CREST_BOX = { w = 260, h = 280 }
ns.LEGEND_CREST_WELL = { x = 130, y = 124, r = 56 }

---@type table<string, PagleLegendCrestArt>
ns.LEGEND_CREST_ART = {}

-- racer: item 19803
ns.ATLASES["LegendRacer"] = {
	file = DIR .. "LegendRacer",
	width = 512,
	height = 1024,
	scale = 1.5,
	sprites = {
		["back"] = { x = 329, y = 256, w = 91, h = 257, box = { 0, 0, 60.667, 171.333 } },
		["fx2"] = { x = 329, y = 2, w = 147, h = 250, box = { 0, 0, 98, 166.667 } },
		["body"] = { x = 2, y = 2, w = 240, h = 299, box = { 0, 0, 160, 199.333 } },
		["fx1"] = { x = 246, y = 517, w = 104, h = 77, box = { 0, 0, 69.333, 51.333 } },
		["front"] = { x = 2, y = 305, w = 323, h = 202, box = { 0, 0, 215.333, 134.667 } },
		["lab"] = { x = 2, y = 511, w = 240, h = 60, box = { 0, 0, 160, 40 } },
	},
}
ns.LEGEND_CREST_ART.racer = {
	atlas = "LegendRacer",
	label = { word = "legend", top = 239, ink = { face = "gilt", size = 13, color = "F4F8FF", caps = true } },
	layers = {
		{ name = "back", sprite = "back", x = 0, y = 27.33, w = 60.67, h = 171.33, z = 1 },
		{
			name = "fx2",
			sprite = "fx2",
			x = 0,
			y = 37.33,
			w = 98,
			h = 166.67,
			z = 2,
			motion = {
				keyframes = "lc-flutter",
				dur = 0.9,
				ease = "inOut",
				loop = true,
				origin = { x = 90, y = 124 },
				transform = { { 0, 0, 0, -2.5, 1, 1 }, { 0.5, 0, 0, 2, 1, 1 }, { 1, 0, 0, -2.5, 1, 1 } },
			},
		},
		{ name = "body", sprite = "body", x = 50, y = 8, w = 160, h = 199.33, z = 4 },
		{
			name = "fx1",
			sprite = "fx1",
			x = 67.33,
			y = 51.33,
			w = 69.33,
			h = 51.33,
			z = 5,
			blend = "ADD",
			motion = {
				keyframes = "lc-lap",
				dur = 1.6,
				ease = "linear",
				loop = true,
				origin = { x = 130, y = 124 },
				transform = { { 0, 0, 0, 0, 1, 1 }, { 1, 0, 0, 360, 1, 1 } },
			},
		},
		{ name = "front", sprite = "front", x = 44, y = 74.67, w = 215.33, h = 134.67, z = 6 },
		{ name = "lab", sprite = "lab", x = 50, y = 228, w = 160, h = 40, z = 8 },
	},
}

-- angelfish: item 19805
ns.ATLASES["LegendAngelfish"] = {
	file = DIR .. "LegendAngelfish",
	width = 512,
	height = 1024,
	scale = 1.5,
	sprites = {
		["back"] = { x = 2, y = 2, w = 378, h = 369, box = { 0, 0, 252, 246 } },
		["fx1"] = { x = 248, y = 375, w = 143, h = 173, box = { 0, 0, 95.333, 115.333 } },
		["fx2"] = { x = 248, y = 552, w = 143, h = 173, box = { 0, 0, 95.333, 115.333 } },
		["body"] = { x = 2, y = 375, w = 242, h = 243, box = { 0, 0, 161.333, 162 } },
		["fx3"] = { x = 2, y = 686, w = 148, h = 64, box = { 0, 0, 98.667, 42.667 } },
		["lab"] = { x = 2, y = 622, w = 240, h = 60, box = { 0, 0, 160, 40 } },
	},
}
ns.LEGEND_CREST_ART.angelfish = {
	atlas = "LegendAngelfish",
	label = { word = "legend", top = 235, ink = { face = "gilt", size = 13, color = "6A4A10", caps = true } },
	layers = {
		{
			name = "back",
			sprite = "back",
			x = 4,
			y = 0,
			w = 252,
			h = 246,
			z = 0,
			motion = {
				keyframes = "lc-aura",
				dur = 4,
				ease = "inOut",
				loop = true,
				origin = { x = 130, y = 140 },
				alpha = { { 0, 0.65 }, { 0.5, 1 }, { 1, 0.65 } },
			},
		},
		{
			name = "fx1",
			sprite = "fx1",
			x = 0,
			y = 34.67,
			w = 95.33,
			h = 115.33,
			z = 1,
			motion = {
				keyframes = "lc-wingL",
				dur = 3.2,
				ease = "inOut",
				loop = true,
				origin = { x = 86, y = 104 },
				transform = { { 0, 0, 0, 0, 1, 1 }, { 0.5, 0, 0, 5, 1, 1 }, { 1, 0, 0, 0, 1, 1 } },
			},
		},
		{
			name = "fx2",
			sprite = "fx2",
			x = 164.67,
			y = 34.67,
			w = 95.33,
			h = 115.33,
			z = 1,
			motion = {
				keyframes = "lc-wingR",
				dur = 3.2,
				ease = "inOut",
				loop = true,
				origin = { x = 174, y = 104 },
				transform = { { 0, 0, 0, 0, 1, 1 }, { 0.5, 0, 0, -5, 1, 1 }, { 1, 0, 0, 0, 1, 1 } },
			},
		},
		{ name = "body", sprite = "body", x = 49.33, y = 46, w = 161.33, h = 162, z = 4 },
		{
			name = "fx3",
			sprite = "fx3",
			x = 80.67,
			y = 12.67,
			w = 98.67,
			h = 42.67,
			z = 6,
			motion = {
				keyframes = "lc-halo",
				dur = 3.2,
				ease = "inOut",
				loop = true,
				origin = { x = 130, y = 140 },
				alpha = { { 0, 0.9 }, { 0.5, 1 }, { 1, 0.9 } },
				transform = { { 0, 0, 0, 0, 1, 1 }, { 0.5, 0, -4, 0, 1, 1 }, { 1, 0, 0, 0, 1, 1 } },
			},
		},
		{ name = "lab", sprite = "lab", x = 50, y = 224, w = 160, h = 40, z = 8 },
	},
}

-- queenfish: item 19806
ns.ATLASES["LegendQueenfish"] = {
	file = DIR .. "LegendQueenfish",
	width = 512,
	height = 1024,
	scale = 1.5,
	sprites = {
		["back"] = { x = 2, y = 2, w = 384, h = 377, box = { 0, 0, 256, 251.333 } },
		["body"] = { x = 224, y = 383, w = 240, h = 240, box = { 0, 0, 160, 160 } },
		["front"] = { x = 2, y = 674, w = 192, h = 109, box = { 0, 0, 128, 72.667 } },
		["fx1"] = { x = 224, y = 627, w = 218, h = 225, box = { 0, 0, 145.333, 150 } },
		["fx2"] = { x = 2, y = 383, w = 218, h = 287, box = { 0, 0, 145.333, 191.333 } },
		["lab"] = { x = 2, y = 856, w = 240, h = 60, box = { 0, 0, 160, 40 } },
	},
}
ns.LEGEND_CREST_ART.queenfish = {
	atlas = "LegendQueenfish",
	label = { word = "legend", top = 241, ink = { face = "gilt", size = 13, color = "F6E6B0", caps = true } },
	layers = {
		{ name = "back", sprite = "back", x = 2, y = 9.33, w = 256, h = 251.33, z = 1 },
		{ name = "body", sprite = "body", x = 50, y = 47.33, w = 160, h = 160, z = 4 },
		{ name = "front", sprite = "front", x = 66, y = 0, w = 128, h = 72.67, z = 6 },
		{
			name = "fx1",
			sprite = "fx1",
			x = 59.33,
			y = 44.67,
			w = 145.33,
			h = 150,
			z = 7,
			motion = {
				keyframes = "lc-glint",
				dur = 3.6,
				ease = "out",
				loop = true,
				origin = { x = 130, y = 140 },
				alpha = { { 0, 0 }, { 0.12, 1 }, { 0.3, 0 }, { 1, 0 } },
				transform = { { 0, 0, 0, 0, 0.6, 0.6 }, { 1, 0, 0, 0, 0.6, 0.6 } },
			},
		},
		{
			name = "fx2",
			sprite = "fx2",
			x = 59.33,
			y = 3.33,
			w = 145.33,
			h = 191.33,
			z = 7,
			motion = {
				keyframes = "lc-glint",
				dur = 3.6,
				ease = "out",
				delay = 1.8,
				loop = true,
				origin = { x = 130, y = 140 },
				alpha = { { 0, 0 }, { 0.12, 1 }, { 0.3, 0 }, { 1, 0 } },
				transform = { { 0, 0, 0, 0, 0.6, 0.6 }, { 1, 0, 0, 0, 0.6, 0.6 } },
			},
		},
		{ name = "lab", sprite = "lab", x = 50, y = 230, w = 160, h = 40, z = 8 },
	},
}

-- unwritten: any Legend not caught, or with no crest of its own
ns.ATLASES["LegendUnwritten"] = {
	file = DIR .. "LegendUnwritten",
	width = 512,
	height = 1024,
	scale = 1.5,
	sprites = {
		["fx1"] = { x = 2, y = 2, w = 390, h = 365, box = { 0, 0, 260, 243.333 } },
		["body"] = { x = 2, y = 371, w = 240, h = 264, box = { 0, 0, 160, 176 } },
		["lab"] = { x = 246, y = 543, w = 240, h = 60, box = { 0, 0, 160, 40 } },
		["well"] = { x = 246, y = 371, w = 168, h = 168, box = { 0, 0, 112, 112 } },
	},
}
ns.LEGEND_CREST_ART.unwritten = {
	atlas = "LegendUnwritten",
	label = { word = "unwritten", top = 235, ink = { face = "gilt", size = 13, color = "E6DCC0", caps = true } },
	layers = {
		{
			name = "fx1",
			sprite = "fx1",
			x = 0,
			y = 2,
			w = 260,
			h = 243.33,
			z = 1,
			motion = {
				keyframes = "lc-mist",
				dur = 6,
				ease = "inOut",
				loop = true,
				origin = { x = 130, y = 140 },
				alpha = { { 0, 0.8 }, { 0.5, 1 }, { 1, 0.8 } },
				transform = { { 0, -6, 0, 0, 1, 1 }, { 0.5, 6, 0, 0, 1, 1 }, { 1, -6, 0, 0, 1, 1 } },
			},
		},
		{ name = "well", sprite = "well", x = 74, y = 68, w = 112, h = 112, z = 3 },
		{ name = "body", sprite = "body", x = 50, y = 30.67, w = 160, h = 176, z = 4 },
		{ name = "lab", sprite = "lab", x = 50, y = 224, w = 160, h = 40, z = 8 },
	},
}

--- Each Legend item's crest key (LED-R153): every other Legend item's is the Unwritten crest's.
ns.LEGEND_CRESTS = {
	[19803] = "racer",
	[19805] = "angelfish",
	[19806] = "queenfish",
}
