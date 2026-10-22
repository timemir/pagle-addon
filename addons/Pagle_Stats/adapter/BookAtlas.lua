if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The books art kit's atlases (the Stats book and the Hunts board, post-1.0 art): texel rectangles in its textures, 2
-- texels per UI unit. `box` is where the drawn element sits in its sprite, in UI units from the sprite's top left (x,
-- y, w, h): code places the box, and the sprite's margin carries its shadow or glow. The book shell (leather,
-- parchment, the binding and wax atlas) and the kit's parts are Core's media (Pagle/media/books), which Hunts reads too;
-- each tracker frame is Stats' own (Pagle_Stats/media/books), so a tracker loads only the frame it wears. Repacked from
-- the kit's BookParts.tga (art/books/generate.py in the dev's kit) with its tracker frames split out; the textures are
-- BLP (DXT5), encoded by scripts/encode-blp.py.

local CORE = "Interface\\AddOns\\Pagle\\media\\books\\"
local OWN = "Interface\\AddOns\\Pagle_Stats\\media\\books\\"

--- The leather's grain (tiled, 128 UI units a repeat) and the page paper, whole textures.
ns.BOOK_FILES = { leather = CORE .. "Leather", parchment = CORE .. "Parchment" }

---@type table<string, StatsArtAtlas>
ns.ATLASES = {
	-- The book shell: the binding band (a nine-slice), the leather's vignette, the wax seal and its "not yet" ring,
	-- the wax close button, the brass nameplate (a three-slice), the fleuron and the spine's gutter.
	Book = {
		file = CORE .. "BookAtlas",
		width = 512,
		height = 256,
		scale = 2,
		sprites = {
			["binding"] = { x = 2, y = 2, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["vignette"] = { x = 102, y = 2, w = 128, h = 128, box = { 0, 0, 64, 64 } },
			["seal"] = { x = 234, y = 2, w = 128, h = 128, box = { 0, 0, 64, 64 } },
			["seal-empty"] = { x = 366, y = 2, w = 128, h = 128, box = { 0, 0, 64, 64 } },
			["close"] = { x = 2, y = 136, w = 64, h = 64, box = { 0, 0, 32, 32 } },
			["close-pushed"] = { x = 70, y = 136, w = 64, h = 64, box = { 0, 0, 32, 32 } },
			["close-highlight"] = { x = 138, y = 136, w = 64, h = 64, box = { 0, 0, 32, 32 } },
			["plate"] = { x = 274, y = 136, w = 128, h = 64, box = { 0, 0, 64, 32 } },
			["fleuron"] = { x = 406, y = 136, w = 32, h = 32, box = { 0, 0, 16, 16 } },
			["gutter"] = { x = 442, y = 136, w = 64, h = 8, box = { 0, 0, 32, 4 } },
		},
	},
	-- The kit's parts: the grosgrain ribbon and its stitch, chips, the pinned pill, item rings, tier marks, the ink
	-- bar, the timeline's bars, the pin, the brass corner, the luck ruler's mark and the star.
	Parts = {
		file = CORE .. "BookParts",
		width = 512,
		height = 1024,
		scale = 2,
		sprites = {
			["bar-blue"] = { x = 6, y = 902, w = 380, h = 24, box = { 0, 0, 190, 12 } },
			["bar-dash"] = { x = 6, y = 846, w = 380, h = 24, box = { 0, 0, 190, 12 } },
			["bar-hatch"] = { x = 18, y = 818, w = 380, h = 24, box = { 0, 0, 190, 12 } },
			["bar-pencil"] = { x = 6, y = 874, w = 380, h = 24, box = { 0, 0, 190, 12 } },
			["chip"] = { x = 46, y = 418, w = 244, h = 48, box = { 1, 1, 120, 22 } },
			["chip-here"] = { x = 218, y = 470, w = 244, h = 48, box = { 1, 1, 120, 22 } },
			["chip-red"] = { x = 218, y = 522, w = 244, h = 48, box = { 1, 1, 120, 22 } },
			["chip-unc"] = { x = 218, y = 574, w = 244, h = 48, box = { 1, 1, 120, 22 } },
			["corner"] = { x = 402, y = 818, w = 76, h = 76, box = { 0, 0, 34, 34 } },
			["ic-pin"] = { x = 450, y = 898, w = 28, h = 28, box = { 1, 1, 12, 12 } },
			["ic-ring"] = { x = 250, y = 354, w = 56, h = 56, box = { 3, 3, 22, 22 } },
			["ic-ring-bronze"] = { x = 390, y = 898, w = 56, h = 56, box = { 3, 3, 22, 22 } },
			["ic-ring-gold"] = { x = 370, y = 354, w = 56, h = 56, box = { 3, 3, 22, 22 } },
			["ic-ring-silver"] = { x = 310, y = 354, w = 56, h = 56, box = { 3, 3, 22, 22 } },
			["ink-empty"] = { x = 18, y = 762, w = 404, h = 24, box = { 1, 1, 200, 10 } },
			["ink-full"] = { x = 18, y = 790, w = 404, h = 24, box = { 1, 1, 200, 10 } },
			["me"] = { x = 430, y = 354, w = 40, h = 72, box = { 0, 6, 20, 30 } },
			["pill"] = { x = 46, y = 354, w = 200, h = 60, box = { 0, 0, 100, 30 } },
			["pin-glyph"] = { x = 294, y = 430, w = 32, h = 32, box = { 0, 0, 16, 16 } },
			["ribbon"] = { x = 6, y = 474, w = 208, h = 284, box = { 2, 0, 100, 140 } },
			["ribbon-stitch"] = { x = 218, y = 2, w = 208, h = 284, box = { 2, 0, 100, 140 } },
			["scroll"] = { x = 466, y = 430, w = 8, h = 120, box = { 0, 0, 4, 60 } },
			["sic-ring"] = { x = 430, y = 90, w = 40, h = 40, box = { 1, 1, 18, 18 } },
			["star"] = { x = 330, y = 430, w = 30, h = 30, box = { 0, 0, 15, 15 } },
			["tier-off"] = { x = 430, y = 46, w = 40, h = 40, box = { 4, 4, 12, 12 } },
			["tier-on"] = { x = 430, y = 2, w = 40, h = 40, box = { 4, 4, 12, 12 } },
			["watch"] = { x = 218, y = 290, w = 220, h = 60, box = { 0, 0, 110, 30 } },
		},
	},
	-- The kit v2's parts only the book draws, Stats' own: the home spread's zone tiles (plain, and the one I'm in), the
	-- dark tooltip slip of Every fish, and the pen. Repacked from the kit's BookParts.tga, with mips.
	Stats = {
		file = OWN .. "StatsParts",
		width = 512,
		height = 512,
		scale = 2,
		sprites = {
			["tile"] = { x = 0, y = 0, w = 412, h = 142, box = { 1, 1, 202, 66 } },
			["tile-here"] = { x = 0, y = 148, w = 412, h = 142, box = { 1, 1, 202, 66 } },
			["tip"] = { x = 0, y = 296, w = 472, h = 142, box = { 18, 12, 200, 33 } },
			["pen"] = { x = 480, y = 0, w = 30, h = 30, box = { 0, 0, 15, 15 } },
		},
	},
	-- The search slip: the Curio Shop's paper slip with its magnifier, from Core's shop atlas (Pagle/media/shop/Shop,
	-- data/ShopArt.lua's "find"), so the book's search and the shop's match. Stats reads Core's file, not Core's table
	-- (ADR 0001), so its rectangle is copied here.
	Slip = {
		file = "Interface\\AddOns\\Pagle\\media\\shop\\Shop",
		width = 1024,
		height = 512,
		scale = 2,
		sprites = { ["find"] = { x = 2, y = 102, w = 900, h = 96, box = { 6, 6, 438, 36 } } },
	},
	-- The tracker frames for sale (STA-R88): the Logbook's ruled paper, the Brass plate with its rivets, and the Curio
	-- Shop expansion's five in one sheet, TrackerFrames2 (the shop expansion kit's goods.json): each 262 x 200 UI units
	-- drawn, with its shadow below.
	TrackerLogbook = {
		file = OWN .. "TrackerLogbook",
		width = 1024,
		height = 512,
		scale = 2,
		sprites = { ["frame"] = { x = 0, y = 0, w = 556, h = 428, box = { 2, 2, 274, 202 } } },
	},
	TrackerBrass = {
		file = OWN .. "TrackerBrass",
		width = 1024,
		height = 512,
		scale = 2,
		sprites = { ["frame"] = { x = 0, y = 0, w = 532, h = 432, box = { 2, 2, 262, 204 } } },
	},
	TrackerFrames2 = {
		file = OWN .. "TrackerFrames2",
		width = 2048,
		height = 1024,
		scale = 2,
		sprites = {
			["frame-greenbar"] = { x = 2, y = 2, w = 556, h = 440, box = { 8, 6, 262, 200 } },
			["frame-chalkboard"] = { x = 2, y = 446, w = 556, h = 440, box = { 8, 6, 262, 200 } },
			["frame-tidegauge"] = { x = 562, y = 2, w = 556, h = 440, box = { 8, 6, 262, 200 } },
			["frame-abacus"] = { x = 562, y = 446, w = 556, h = 440, box = { 8, 6, 262, 200 } },
			["frame-astrolabe"] = { x = 1122, y = 2, w = 556, h = 440, box = { 8, 6, 262, 200 } },
		},
	},
}
