---@class PagleNS
local ns = select(2, ...)

-- The Prestige frames and Prestige emblems (ledger.md › LED-R152, LED-R153; announcements.md › ANN-R83), as the
-- Prestige frames kit's art.json has them: written by scripts/prestige-art.py, so change the kit and run it, not this
-- file. Core's, since the Ledger's bookplate and Core's Prestige banner both draw them. Each frame's atlas joins
-- ns.ATLASES by name (its sprites' boxes are the whole sprite, at 1.5 texels a unit); its art, by prestige rank in
-- ns.PRESTIGE_FRAME_ART (0 is No Prestige's, 11 the Master's), has its key, its label (the text's top and its ink:
-- face, size, "RRGGBB" colour, capitals, a shadow with an offset), the point its bookplate crest is pinned at with
-- the shield's width, and its layers in draw order, each on the host it draws on (logic/LayeredArt.lua): "back"
-- behind the likeness, "front" over it. A layer's `motion` is the composed toast styles' (data/ToastStyleArt2.lua).
-- Every unit is the kit's 260 × 280 box's, the likeness's well a circle in it (ns.PRESTIGE_WELL).

local DIR = "Interface\\AddOns\\Pagle\\media\\prestige\\"

ns.ATLASES = ns.ATLASES or {}

--- The kit's box, in UI units, and the likeness's well in it.
ns.PRESTIGE_BOX = { w = 260, h = 280 }
ns.PRESTIGE_WELL = { cx = 130, cy = 124, r = 56 }

---@type table<integer, PaglePrestigeFrameArt>
ns.PRESTIGE_FRAME_ART = {}

-- Unwritten (rank 0)
ns.ATLASES["PrestigeNone"] = {
	file = DIR .. "FrameNone",
	width = 512,
	height = 512,
	sprites = { body = { x = 2, y = 2, w = 276, h = 281, box = { 0, 0, 184, 187.333 } } },
	scale = 1.5,
}
ns.PRESTIGE_FRAME_ART[0] = {
	key = "none",
	atlas = "PrestigeNone",
	pin = { x = 195.9, y = 179.3, w = 76.923 },
	layers = {
		{ name = "body", sprite = "body", x = 38, y = 28.67, w = 184, h = 187.33, host = "front" },
	},
}

-- The Jetty (rank 1)
ns.ATLASES["PrestigeJetty"] = {
	file = DIR .. "FrameJetty",
	width = 512,
	height = 512,
	sprites = {
		body = { x = 2, y = 2, w = 281, h = 276, box = { 0, 0, 187.333, 184 } },
		lab = { x = 287, y = 2, w = 220, h = 77, box = { 0, 0, 146.667, 51.333 } },
	},
	scale = 1.5,
}
ns.PRESTIGE_FRAME_ART[1] = {
	key = "jetty",
	atlas = "PrestigeJetty",
	label = {
		top = 222,
		ink = {
			face = "gilt",
			size = 13,
			color = "F2EAD6",
			caps = true,
			shadow = { color = "281C0E", alpha = 0.8, x = 0, y = 1 },
		},
	},
	pin = { x = 195.9, y = 179.3, w = 76.923 },
	layers = {
		{ name = "body", sprite = "body", x = 28, y = 29.33, w = 187.33, h = 184, host = "front" },
		{ name = "lab", sprite = "lab", x = 56, y = 198, w = 146.67, h = 51.33, host = "front" },
	},
}

-- Casting Off (rank 2)
ns.ATLASES["PrestigeCastoff"] = {
	file = DIR .. "FrameCastoff",
	width = 512,
	height = 1024,
	sprites = {
		back = { x = 2, y = 2, w = 384, h = 329, box = { 0, 0, 256, 219.333 } },
		body = { x = 2, y = 335, w = 270, h = 269, box = { 0, 0, 180, 179.333 } },
		lab = { x = 276, y = 335, w = 216, h = 55, box = { 0, 0, 144, 36.667 } },
	},
	scale = 1.5,
}
ns.PRESTIGE_FRAME_ART[2] = {
	key = "castoff",
	atlas = "PrestigeCastoff",
	label = {
		top = 216,
		ink = {
			face = "gilt",
			size = 13,
			color = "F0CD6A",
			caps = true,
			shadow = { color = "06140F", alpha = 1, x = 0, y = 1 },
		},
	},
	pin = { x = 195.9, y = 179.3, w = 76.923 },
	layers = {
		{ name = "back", sprite = "back", x = 2, y = 13.33, w = 256, h = 219.33, host = "back" },
		{ name = "body", sprite = "body", x = 40, y = 37.33, w = 180, h = 179.33, host = "front" },
		{ name = "lab", sprite = "lab", x = 58, y = 203.33, w = 144, h = 36.67, host = "front" },
	},
}

-- The Lighthouse (rank 3)
ns.ATLASES["PrestigeLighthouse"] = {
	file = DIR .. "FrameLighthouse",
	width = 512,
	height = 1024,
	sprites = {
		back = { x = 2, y = 693, w = 390, h = 145, box = { 0, 0, 260, 96.667 } },
		body = { x = 2, y = 2, w = 248, h = 352, box = { 0, 0, 165.333, 234.667 } },
		front = { x = 2, y = 358, w = 258, h = 331, box = { 0, 0, 172, 220.667 } },
		lab = { x = 264, y = 2, w = 168, h = 44, box = { 0, 0, 112, 29.333 } },
	},
	scale = 1.5,
}
ns.PRESTIGE_FRAME_ART[3] = {
	key = "lighthouse",
	atlas = "PrestigeLighthouse",
	label = {
		top = 241,
		ink = {
			face = "gilt",
			size = 11.5,
			color = "3A2404",
			caps = true,
			shadow = { color = "FFF4C8", alpha = 0.7, x = 0, y = 1 },
		},
	},
	pin = { x = 195.9, y = 179.3, w = 76.923 },
	layers = {
		{ name = "back", sprite = "back", x = 0, y = 69.33, w = 260, h = 96.67, host = "back" },
		{
			name = "body",
			sprite = "body",
			x = 47.33,
			y = 45.33,
			w = 165.33,
			h = 234.67,
			host = "front",
		},
		{ name = "front", sprite = "front", x = 44, y = 0, w = 172, h = 220.67, host = "front" },
		{ name = "lab", sprite = "lab", x = 74, y = 232.67, w = 112, h = 29.33, host = "front" },
	},
}

-- The Open Sea (rank 4)
ns.ATLASES["PrestigeOpensea"] = {
	file = DIR .. "FrameOpensea",
	width = 512,
	height = 1024,
	sprites = {
		back = { x = 2, y = 2, w = 378, h = 376, box = { 0, 0, 252, 250.667 } },
		body = { x = 2, y = 382, w = 248, h = 249, box = { 0, 0, 165.333, 166 } },
		lab = { x = 254, y = 382, w = 250, h = 52, box = { 0, 0, 166.667, 34.667 } },
	},
	scale = 1.5,
}
ns.PRESTIGE_FRAME_ART[4] = {
	key = "opensea",
	atlas = "PrestigeOpensea",
	label = { top = 237, ink = { face = "gilt", size = 12.5, color = "1E3A5E", caps = true } },
	pin = { x = 195.9, y = 179.3, w = 76.923 },
	layers = {
		{ name = "back", sprite = "back", x = 6, y = 0, w = 252, h = 250.67, host = "back" },
		{ name = "body", sprite = "body", x = 47.33, y = 44, w = 165.33, h = 166, host = "front" },
		{
			name = "lab",
			sprite = "lab",
			x = 46.67,
			y = 227.33,
			w = 166.67,
			h = 34.67,
			host = "front",
		},
	},
}

-- The Storm (rank 5)
ns.ATLASES["PrestigeStorm"] = {
	file = DIR .. "FrameStorm",
	width = 1024,
	height = 1024,
	sprites = {
		back = { x = 2, y = 2, w = 366, h = 398, box = { 0, 0, 244, 265.333 } },
		fx2 = { x = 370, y = 404, w = 333, h = 345, box = { 0, 0, 222, 230 } },
		fx1 = { x = 2, y = 772, w = 94, h = 165, box = { 0, 0, 62.667, 110 } },
		body = { x = 2, y = 404, w = 364, h = 364, box = { 0, 0, 242.667, 242.667 } },
		lab = { x = 2, y = 941, w = 236, h = 57, box = { 0, 0, 157.333, 38 } },
	},
	scale = 1.5,
}
ns.PRESTIGE_FRAME_ART[5] = {
	key = "storm",
	atlas = "PrestigeStorm",
	label = { top = 246, ink = { face = "gilt", size = 12.5, color = "2A2418", caps = true } },
	pin = { x = 195.9, y = 179.3, w = 76.923 },
	layers = {
		{ name = "back", sprite = "back", x = 2.67, y = 0, w = 244, h = 265.33, host = "back" },
		{
			name = "fx2",
			sprite = "fx2",
			x = 16,
			y = 0,
			w = 222,
			h = 230,
			blend = "ADD",
			motion = {
				keyframes = "pf-glow",
				dur = 7,
				ease = "linear",
				loop = true,
				origin = { x = 130, y = 140 },
				alpha = {
					{ 0, 0 },
					{ 0.86, 0 },
					{ 0.87, 0.35 },
					{ 0.88, 0 },
					{ 0.9, 0.45 },
					{ 0.96, 0 },
					{ 1, 0 },
				},
			},
			host = "back",
		},
		{
			name = "fx1",
			sprite = "fx1",
			x = 182,
			y = -8,
			w = 62.67,
			h = 110,
			motion = {
				keyframes = "pf-flash",
				dur = 7,
				ease = "linear",
				loop = true,
				origin = { x = 213, y = 47 },
				alpha = {
					{ 0, 0 },
					{ 0.86, 0 },
					{ 0.87, 0.9 },
					{ 0.88, 0.1 },
					{ 0.9, 1 },
					{ 0.94, 0 },
					{ 1, 0 },
				},
			},
			host = "back",
		},
		{
			name = "body",
			sprite = "body",
			x = 8.67,
			y = 6.67,
			w = 242.67,
			h = 242.67,
			motion = {
				keyframes = "pf-helm",
				dur = 4.6,
				ease = "inOut",
				loop = true,
				origin = { x = 130, y = 124 },
				transform = {
					{ 0, 0, 0, -7, 1, 1 },
					{ 0.5, 0, 0, 7, 1, 1 },
					{ 1, 0, 0, -7, 1, 1 },
				},
			},
			host = "front",
		},
		{ name = "lab", sprite = "lab", x = 50, y = 234, w = 157.33, h = 38, host = "front" },
	},
}

-- The Dive (rank 6)
ns.ATLASES["PrestigeDive"] = {
	file = DIR .. "FrameDive",
	width = 512,
	height = 512,
	sprites = {
		body = { x = 2, y = 2, w = 372, h = 381, box = { 0, 0, 248, 254 } },
		fx1 = { x = 186, y = 387, w = 42, h = 83, box = { 0, 0, 28, 55.333 } },
		fx2 = { x = 2, y = 438, w = 47, h = 67, box = { 0, 0, 31.333, 44.667 } },
		lab = { x = 2, y = 387, w = 180, h = 47, box = { 0, 0, 120, 31.333 } },
	},
	scale = 1.5,
}
ns.PRESTIGE_FRAME_ART[6] = {
	key = "dive",
	atlas = "PrestigeDive",
	label = {
		top = 238,
		ink = {
			face = "gilt",
			size = 11.5,
			color = "3A2404",
			caps = true,
			shadow = { color = "FFF4C8", alpha = 0.7, x = 0, y = 1 },
		},
	},
	pin = { x = 195.9, y = 179.3, w = 76.923 },
	layers = {
		{ name = "body", sprite = "body", x = 12, y = 26, w = 248, h = 254, host = "front" },
		{
			name = "fx1",
			sprite = "fx1",
			x = 195.33,
			y = 2,
			w = 28,
			h = 55.33,
			motion = {
				keyframes = "pf-bubble",
				dur = 3.2,
				ease = "in",
				loop = true,
				origin = { x = 211, y = 55 },
				alpha = {
					{ 0, 0 },
					{ 0.15, 1 },
					{ 1, 0 },
				},
				transform = {
					{ 0, 0, 18, 0, 1, 1 },
					{ 1, 0, -16, 0, 1, 1 },
				},
			},
			host = "front",
		},
		{
			name = "fx2",
			sprite = "fx2",
			x = 210,
			y = 23.33,
			w = 31.33,
			h = 44.67,
			motion = {
				keyframes = "pf-bubble",
				dur = 3.2,
				ease = "in",
				loop = true,
				origin = { x = 225, y = 61 },
				delay = 1.6,
				alpha = {
					{ 0, 0 },
					{ 0.15, 1 },
					{ 1, 0 },
				},
				transform = {
					{ 0, 0, 18, 0, 1, 1 },
					{ 1, 0, -16, 0, 1, 1 },
				},
			},
			host = "front",
		},
		{ name = "lab", sprite = "lab", x = 70, y = 228.67, w = 120, h = 31.33, host = "front" },
	},
}

-- The Coral Gardens (rank 7)
ns.ATLASES["PrestigeCoral"] = {
	file = DIR .. "FrameCoral",
	width = 512,
	height = 1024,
	sprites = {
		back = { x = 2, y = 2, w = 326, h = 201, box = { 0, 0, 217.333, 134 } },
		fx2 = { x = 248, y = 207, w = 223, h = 135, box = { 0, 0, 148.667, 90 } },
		body = { x = 2, y = 207, w = 242, h = 243, box = { 0, 0, 161.333, 162 } },
		front = { x = 2, y = 454, w = 328, h = 160, box = { 0, 0, 218.667, 106.667 } },
		fx1 = { x = 334, y = 346, w = 97, h = 261, box = { 0, 0, 64.667, 174 } },
		lab = { x = 2, y = 618, w = 222, h = 49, box = { 0, 0, 148, 32.667 } },
	},
	scale = 1.5,
}
ns.PRESTIGE_FRAME_ART[7] = {
	key = "coral",
	atlas = "PrestigeCoral",
	label = { top = 235, ink = { face = "gilt", size = 12.5, color = "7A3A5A", caps = true } },
	pin = { x = 195.9, y = 179.3, w = 76.923 },
	layers = {
		{ name = "back", sprite = "back", x = 22.67, y = 132, w = 217.33, h = 134, host = "back" },
		{
			name = "fx2",
			sprite = "fx2",
			x = 110.67,
			y = 44.67,
			w = 148.67,
			h = 90,
			motion = {
				keyframes = "pf-fan",
				dur = 5,
				ease = "inOut",
				loop = true,
				origin = { x = 184, y = 126 },
				transform = {
					{ 0, 0, 0, -3, 1, 1 },
					{ 0.5, 0, 0, 3, 1, 1 },
					{ 1, 0, 0, -3, 1, 1 },
				},
			},
			host = "back",
		},
		{ name = "body", sprite = "body", x = 49.33, y = 46, w = 161.33, h = 162, host = "front" },
		{
			name = "front",
			sprite = "front",
			x = 4.67,
			y = 118.67,
			w = 218.67,
			h = 106.67,
			host = "front",
		},
		{
			name = "fx1",
			sprite = "fx1",
			x = 103.33,
			y = 36.67,
			w = 64.67,
			h = 174,
			motion = {
				keyframes = "pf-orbit",
				dur = 22,
				ease = "linear",
				loop = true,
				origin = { x = 130, y = 124 },
				transform = {
					{ 0, 0, 0, 0, 1, 1 },
					{ 1, 0, 0, 0, 1, 1 },
				},
			},
			host = "front",
		},
		{ name = "lab", sprite = "lab", x = 56, y = 225.33, w = 148, h = 32.67, host = "front" },
	},
}

-- The Midnight Zone (rank 8)
ns.ATLASES["PrestigeMidnight"] = {
	file = DIR .. "FrameMidnight",
	width = 512,
	height = 1024,
	sprites = {
		back = { x = 2, y = 2, w = 370, h = 362, box = { 0, 0, 246.667, 241.333 } },
		body = { x = 266, y = 368, w = 237, h = 237, box = { 0, 0, 158, 158 } },
		fx2 = { x = 266, y = 609, w = 224, h = 224, box = { 0, 0, 149.333, 149.333 } },
		fx1 = { x = 2, y = 368, w = 260, h = 316, box = { 0, 0, 173.333, 210.667 } },
		lab = { x = 2, y = 688, w = 218, h = 48, box = { 0, 0, 145.333, 32 } },
	},
	scale = 1.5,
}
ns.PRESTIGE_FRAME_ART[8] = {
	key = "midnight",
	atlas = "PrestigeMidnight",
	label = { top = 232, ink = { face = "gilt", size = 12.5, color = "BFF8FF", caps = true } },
	pin = { x = 195.9, y = 179.3, w = 76.923 },
	layers = {
		{ name = "back", sprite = "back", x = 6.67, y = 0, w = 246.67, h = 241.33, host = "back" },
		{ name = "body", sprite = "body", x = 50.67, y = 48, w = 158, h = 158, host = "front" },
		{
			name = "fx2",
			sprite = "fx2",
			x = 55.33,
			y = 49.33,
			w = 149.33,
			h = 149.33,
			motion = {
				keyframes = "pf-photo",
				dur = 3.4,
				ease = "inOut",
				loop = true,
				origin = { x = 130, y = 140 },
				alpha = {
					{ 0, 0.35 },
					{ 0.5, 1 },
					{ 1, 0.35 },
				},
			},
			host = "front",
		},
		{
			name = "fx1",
			sprite = "fx1",
			x = 43.33,
			y = 0,
			w = 173.33,
			h = 210.67,
			motion = {
				keyframes = "pf-jelly",
				dur = 2.8,
				ease = "inOut",
				loop = true,
				origin = { x = 130, y = -2 },
				transform = {
					{ 0, 0, 0, 0, 1, 1 },
					{ 0.4, 0, 0, 0, 1.04, 0.93 },
					{ 0.7, 0, 0, 0, 0.98, 1.03 },
					{ 1, 0, 0, 0, 1, 1 },
				},
			},
			host = "front",
		},
		{ name = "lab", sprite = "lab", x = 57.33, y = 222, w = 145.33, h = 32, host = "front" },
	},
}

-- The Leviathan (rank 9)
ns.ATLASES["PrestigeLeviathan"] = {
	file = DIR .. "FrameLeviathan",
	width = 512,
	height = 1024,
	sprites = {
		back = { x = 2, y = 2, w = 306, h = 297, box = { 0, 0, 204, 198 } },
		body = { x = 271, y = 303, w = 225, h = 225, box = { 0, 0, 150, 150 } },
		front = { x = 2, y = 303, w = 265, h = 305, box = { 0, 0, 176.667, 203.333 } },
		fx1 = { x = 271, y = 532, w = 29, h = 28, box = { 0, 0, 19.333, 18.667 } },
		lab = { x = 2, y = 612, w = 270, h = 60, box = { 0, 0, 180, 40 } },
	},
	scale = 1.5,
}
ns.PRESTIGE_FRAME_ART[9] = {
	key = "leviathan",
	atlas = "PrestigeLeviathan",
	label = {
		top = 237,
		ink = {
			face = "gilt",
			size = 12.5,
			color = "F0CD6A",
			caps = true,
			shadow = { color = "021410", alpha = 1, x = 0, y = 1 },
		},
	},
	pin = { x = 195.9, y = 179.3, w = 76.923 },
	layers = {
		{ name = "back", sprite = "back", x = 27.33, y = 34, w = 204, h = 198, host = "back" },
		{ name = "body", sprite = "body", x = 54.67, y = 52, w = 150, h = 150, host = "front" },
		{
			name = "front",
			sprite = "front",
			x = 40.67,
			y = 10,
			w = 176.67,
			h = 203.33,
			host = "front",
		},
		{
			name = "fx1",
			sprite = "fx1",
			x = 128.67,
			y = 28.67,
			w = 19.33,
			h = 18.67,
			motion = {
				keyframes = "pf-eye",
				dur = 5,
				ease = "inOut",
				loop = true,
				origin = { x = 130, y = 140 },
				alpha = {
					{ 0, 0 },
					{ 0.7, 0 },
					{ 0.8, 1 },
					{ 0.9, 0.3 },
					{ 1, 0 },
				},
			},
			host = "front",
		},
		{ name = "lab", sprite = "lab", x = 40, y = 226, w = 180, h = 40, host = "front" },
	},
}

-- The Starward Sea (rank 10)
ns.ATLASES["PrestigeStarward"] = {
	file = DIR .. "FrameStarward",
	width = 512,
	height = 1024,
	sprites = {
		back = { x = 2, y = 2, w = 314, h = 313, box = { 0, 0, 209.333, 208.667 } },
		fx2 = { x = 244, y = 319, w = 256, h = 197, box = { 0, 0, 170.667, 131.333 } },
		body = { x = 2, y = 319, w = 238, h = 303, box = { 0, 0, 158.667, 202 } },
		fx1 = { x = 2, y = 626, w = 318, h = 179, box = { 0, 0, 212, 119.333 } },
		lab = { x = 2, y = 809, w = 270, h = 60, box = { 0, 0, 180, 40 } },
	},
	scale = 1.5,
}
ns.PRESTIGE_FRAME_ART[10] = {
	key = "starward",
	atlas = "PrestigeStarward",
	label = {
		top = 241,
		ink = {
			face = "gilt",
			size = 12.5,
			color = "F0CD6A",
			caps = true,
			shadow = { color = "02061A", alpha = 1, x = 0, y = 1 },
		},
	},
	pin = { x = 195.9, y = 179.3, w = 76.923 },
	layers = {
		{
			name = "back",
			sprite = "back",
			x = 25.33,
			y = 22.67,
			w = 209.33,
			h = 208.67,
			host = "back",
		},
		{
			name = "fx2",
			sprite = "fx2",
			x = 48,
			y = 81.33,
			w = 170.67,
			h = 131.33,
			motion = {
				keyframes = "pf-twinkle",
				dur = 3,
				ease = "inOut",
				loop = true,
				origin = { x = 130, y = 140 },
				alpha = {
					{ 0, 0.2 },
					{ 0.5, 1 },
					{ 1, 0.2 },
				},
			},
			host = "back",
		},
		{ name = "body", sprite = "body", x = 55.33, y = 0, w = 158.67, h = 202, host = "front" },
		{
			name = "fx1",
			sprite = "fx1",
			x = 24,
			y = 67.33,
			w = 212,
			h = 119.33,
			motion = {
				keyframes = "pf-armil",
				dur = 9,
				ease = "inOut",
				loop = true,
				origin = { x = 130, y = 124 },
				transform = {
					{ 0, 0, 0, -6, 1, 1 },
					{ 0.5, 0, 0, 6, 1, 1 },
					{ 1, 0, 0, -6, 1, 1 },
				},
			},
			host = "front",
		},
		{ name = "lab", sprite = "lab", x = 40, y = 230, w = 180, h = 40, host = "front" },
	},
}

-- The Angler’s Constellation (rank 11)
ns.ATLASES["PrestigeConstellation"] = {
	file = DIR .. "FrameConstellation",
	width = 1024,
	height = 1024,
	sprites = {
		fx2 = { x = 2, y = 2, w = 390, h = 393, box = { 0, 0, 260, 262 } },
		back = { x = 2, y = 399, w = 302, h = 303, box = { 0, 0, 201.333, 202 } },
		fx1 = { x = 255, y = 706, w = 236, h = 244, box = { 0, 0, 157.333, 162.667 } },
		body = { x = 2, y = 706, w = 249, h = 308, box = { 0, 0, 166, 205.333 } },
		lab = { x = 255, y = 954, w = 285, h = 60, box = { 0, 0, 190, 40 } },
	},
	scale = 1.5,
}
ns.PRESTIGE_FRAME_ART[11] = {
	key = "constellation",
	atlas = "PrestigeConstellation",
	label = {
		top = 241,
		ink = {
			face = "gilt",
			size = 12.5,
			color = "F4F0E0",
			caps = true,
			shadow = { color = "02061A", alpha = 1, x = 0, y = 1 },
		},
	},
	pin = { x = 195.9, y = 179.3, w = 76.923 },
	layers = {
		{
			name = "fx2",
			sprite = "fx2",
			x = 0,
			y = 0,
			w = 260,
			h = 262,
			motion = {
				keyframes = "pf-rays",
				dur = 90,
				ease = "linear",
				loop = true,
				origin = { x = 130, y = 124 },
				transform = {
					{ 0, 0, 0, 0, 1, 1 },
					{ 1, 0, 0, 0, 1, 1 },
				},
			},
			host = "back",
		},
		{ name = "back", sprite = "back", x = 29.33, y = 26, w = 201.33, h = 202, host = "back" },
		{
			name = "fx1",
			sprite = "fx1",
			x = 39.33,
			y = 41.33,
			w = 157.33,
			h = 162.67,
			motion = {
				keyframes = "pf-twinkle",
				dur = 2.6,
				ease = "inOut",
				loop = true,
				origin = { x = 130, y = 140 },
				alpha = {
					{ 0, 0.2 },
					{ 0.5, 1 },
					{ 1, 0.2 },
				},
			},
			host = "back",
		},
		{ name = "body", sprite = "body", x = 42, y = 0, w = 166, h = 205.33, host = "front" },
		{ name = "lab", sprite = "lab", x = 35.33, y = 230, w = 190, h = 40, host = "front" },
	},
}

-- The Prestige emblems: one per rank I to X and the Master's, each its frame in miniature with its numeral.
ns.ATLASES["PrestigeEmblems"] = {
	file = DIR .. "Emblems",
	width = 512,
	height = 1024,
	scale = 2,
	sprites = {
		["emblem-i"] = { x = 2, y = 2, w = 128, h = 128, box = { 0, 0, 64, 64 } },
		["emblem-ii"] = { x = 134, y = 2, w = 128, h = 128, box = { 0, 0, 64, 64 } },
		["emblem-iii"] = { x = 266, y = 2, w = 128, h = 128, box = { 0, 0, 64, 64 } },
		["emblem-iv"] = { x = 2, y = 134, w = 128, h = 128, box = { 0, 0, 64, 64 } },
		["emblem-v"] = { x = 134, y = 134, w = 128, h = 128, box = { 0, 0, 64, 64 } },
		["emblem-vi"] = { x = 266, y = 134, w = 128, h = 128, box = { 0, 0, 64, 64 } },
		["emblem-vii"] = { x = 2, y = 266, w = 128, h = 128, box = { 0, 0, 64, 64 } },
		["emblem-viii"] = { x = 134, y = 266, w = 128, h = 128, box = { 0, 0, 64, 64 } },
		["emblem-ix"] = { x = 266, y = 266, w = 128, h = 128, box = { 0, 0, 64, 64 } },
		["emblem-x"] = { x = 2, y = 398, w = 128, h = 128, box = { 0, 0, 64, 64 } },
		["emblem-master"] = { x = 134, y = 398, w = 128, h = 128, box = { 0, 0, 64, 64 } },
	},
}

--- The emblems' sprites by rank, I to X; past X, `emblem-master`.
ns.PRESTIGE_EMBLEMS = {
	"emblem-i",
	"emblem-ii",
	"emblem-iii",
	"emblem-iv",
	"emblem-v",
	"emblem-vi",
	"emblem-vii",
	"emblem-viii",
	"emblem-ix",
	"emblem-x",
}
