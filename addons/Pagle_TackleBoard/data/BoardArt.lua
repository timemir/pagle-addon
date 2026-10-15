-- Generated from the board art kit (PagleArtBoard's Atlases/*.lua, written by its art/lib/sprites.py) for its BLP
-- textures, with the Marks atlas cut from Board. Regenerate it with the kit, never by hand.

if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The Tackle Board's art atlases (tackle-board.md › UI): where each sprite sits in its texture, from the board art
-- kit (PagleArtBoard's Atlases/*.lua, written by its art/lib/sprites.py), with the textures shipped as BLP (DXT5) in
-- media/board/. A sprite's `x`, `y`, `w`, `h` are texels; `box` is where its drawn element sits inside it, in UI units
-- from the sprite's top left (x, y, then width and height), so code places the element, not its shadow or glow.
-- `scale` is texels per UI unit. Marks is cut from Board for the tracker, so the tracker never loads Board: its
-- header's flame and chevron, and the small tack of a Corkboard slip. Cork.blp is the cork's tile, repeated every
-- ns.CORK_TILE units, and has no sprites.
--
-- adapter/BoardArt.lua draws from them; a texture loads the first time something shows one of its sprites, so the
-- Campfire card's and the Fly Box drawer's (Card, Flies) wait for their first opening, and the tracker's frames
-- (Tracker) for a Corkboard or Driftwood Plank tracker or its Curio Shop preview.

local MEDIA = "Interface\\AddOns\\Pagle_TackleBoard\\media\\board\\"

--- The cork's tile and its size in UI units.
ns.CORK_TEXTURE = MEDIA .. "Cork"
ns.CORK_TILE = 384

---@class TackleAtlasSprite
---@field x integer
---@field y integer
---@field w integer
---@field h integer
---@field box number[]

---@class TackleAtlas
---@field file string
---@field width integer
---@field height integer
---@field scale number
---@field sprites table<string, TackleAtlasSprite>

---@type table<string, TackleAtlas>
ns.BOARD_ATLASES = {
	Frame = {
		file = MEDIA .. "Frame",
		width = 2048,
		height = 1024,
		scale = 1.35,
		sprites = {
			frame = { x = 2, y = 2, w = 1415, h = 967, box = { 24, 26, 1000, 660 } },
		},
	},
	Board = {
		file = MEDIA .. "Board",
		width = 1024,
		height = 2048,
		scale = 2,
		sprites = {
			["b-collector"] = { x = 798, y = 734, w = 28, h = 28, box = { 0, 0, 14, 14 } },
			["b-haul"] = { x = 986, y = 574, w = 28, h = 28, box = { 0, 0, 14, 14 } },
			["b-lure"] = { x = 830, y = 734, w = 28, h = 28, box = { 0, 0, 14, 14 } },
			["b-quality"] = { x = 986, y = 670, w = 28, h = 28, box = { 0, 0, 14, 14 } },
			["b-size"] = { x = 766, y = 734, w = 28, h = 28, box = { 0, 0, 14, 14 } },
			["b-species"] = { x = 862, y = 734, w = 28, h = 28, box = { 0, 0, 14, 14 } },
			["b-variety"] = { x = 986, y = 606, w = 28, h = 28, box = { 0, 0, 14, 14 } },
			["b-wanderer"] = { x = 986, y = 638, w = 28, h = 28, box = { 0, 0, 14, 14 } },
			bar = { x = 2, y = 1998, w = 400, h = 22, box = { 0, 0, 200, 10.6 } },
			["bar-fill"] = { x = 2, y = 2024, w = 400, h = 22, box = { 0, 0, 200, 10.6 } },
			btn = { x = 2, y = 1882, w = 344, h = 112, box = { 6, 6, 160, 38 } },
			["cell-rare"] = { x = 734, y = 1162, w = 266, h = 180, box = { 8, 8, 117, 74 } },
			chev = { x = 1004, y = 1196, w = 18, h = 18, box = { 0, 0, 9, 9 } },
			chip = { x = 350, y = 1882, w = 344, h = 84, box = { 6, 2, 160, 30 } },
			["chip-clip"] = { x = 1004, y = 1162, w = 18, h = 30, box = { 1, 0, 7, 13 } },
			close = { x = 954, y = 294, w = 52, h = 52, box = { 0, 0, 26, 26 } },
			coin = { x = 974, y = 54, w = 42, h = 42, box = { 2, 2, 17, 17 } },
			["coin-l"] = { x = 946, y = 1346, w = 52, h = 52, box = { 2, 2, 22, 22 } },
			confirm = { x = 2, y = 2, w = 768, h = 404, box = { 12, 6, 360, 166 } },
			["cover-note"] = { x = 2, y = 1118, w = 728, h = 292, box = { 12, 6, 340, 112 } },
			["d-burn"] = { x = 954, y = 406, w = 52, h = 52, box = { 0, 0, 26, 26 } },
			["d-flame"] = { x = 954, y = 350, w = 52, h = 52, box = { 0, 0, 26, 26 } },
			["d-out"] = { x = 954, y = 462, w = 52, h = 52, box = { 0, 0, 26, 26 } },
			["d-unlit"] = { x = 954, y = 518, w = 52, h = 52, box = { 0, 0, 26, 26 } },
			day = { x = 406, y = 1970, w = 76, h = 76, box = { 0, 0, 38, 38 } },
			["day-lit"] = { x = 486, y = 1970, w = 76, h = 76, box = { 0, 0, 38, 38 } },
			["day-pre"] = { x = 566, y = 1970, w = 76, h = 76, box = { 0, 0, 38, 38 } },
			done = { x = 646, y = 770, w = 304, h = 212, box = { 8, 2, 136, 92 } },
			fl = { x = 998, y = 1694, w = 24, h = 30, box = { 0, 0, 12, 15 } },
			flybox = { x = 2, y = 1414, w = 492, h = 292, box = { 6, 30, 214, 100 } },
			hand = { x = 350, y = 1970, w = 44, h = 24, box = { 0, 0, 22, 12 } },
			here = { x = 894, y = 294, w = 26, h = 26, box = { 0, 0, 13, 13 } },
			["k-collector"] = { x = 798, y = 702, w = 28, h = 28, box = { 0, 0, 14, 14 } },
			["k-haul"] = { x = 954, y = 574, w = 28, h = 28, box = { 0, 0, 14, 14 } },
			["k-lure"] = { x = 830, y = 702, w = 28, h = 28, box = { 0, 0, 14, 14 } },
			["k-quality"] = { x = 954, y = 670, w = 28, h = 28, box = { 0, 0, 14, 14 } },
			["k-size"] = { x = 766, y = 702, w = 28, h = 28, box = { 0, 0, 14, 14 } },
			["k-species"] = { x = 862, y = 702, w = 28, h = 28, box = { 0, 0, 14, 14 } },
			["k-variety"] = { x = 954, y = 606, w = 28, h = 28, box = { 0, 0, 14, 14 } },
			["k-wanderer"] = { x = 954, y = 638, w = 28, h = 28, box = { 0, 0, 14, 14 } },
			kindling = { x = 798, y = 1346, w = 88, h = 36, box = { 2, 2, 40, 14 } },
			["mile-no"] = { x = 974, y = 100, w = 40, h = 40, box = { 0, 0, 20, 20 } },
			["mile-won"] = { x = 974, y = 2, w = 48, h = 48, box = { 2, 2, 20, 20 } },
			nail = { x = 734, y = 1346, w = 60, h = 60, box = { 0, 0, 30, 30 } },
			notice = { x = 498, y = 1414, w = 512, h = 276, box = { 10, 4, 236, 116 } },
			notick = { x = 824, y = 1386, w = 22, h = 22, box = { 0, 0, 11, 11 } },
			poster = { x = 2, y = 410, w = 760, h = 356, box = { 10, 4, 360, 156 } },
			seal = { x = 774, y = 2, w = 196, h = 196, box = { 12, 12, 74, 74 } },
			shopcard = { x = 734, y = 986, w = 288, h = 172, box = { 8, 4, 128, 66 } },
			stamp = { x = 774, y = 202, w = 248, h = 88, box = { 0, 0, 124, 44 } },
			tack = { x = 890, y = 1346, w = 52, h = 52, box = { 3, 2, 15, 15 } },
			["tack-s"] = { x = 974, y = 144, w = 28, h = 30, box = { 1, 1, 9, 9 } },
			tally = { x = 498, y = 1694, w = 496, h = 184, box = { 8, 4, 232, 70 } },
			tick = { x = 798, y = 1386, w = 22, h = 22, box = { 0, 0, 11, 11 } },
			welcome = { x = 2, y = 770, w = 640, h = 344, box = { 10, 4, 300, 150 } },
		},
	},
	Fire = {
		file = MEDIA .. "Fire",
		width = 1024,
		height = 1024,
		scale = 2,
		sprites = {
			["fire-100-base"] = { x = 282, y = 2, w = 264, h = 223, box = { -3, -13.5, 138, 130 } },
			["fire-100-fl1"] = { x = 404, y = 828, w = 144, h = 168, box = { -33, -30, 138, 130 } },
			["fire-100-fl2"] = { x = 630, y = 379, w = 104, h = 122, box = { -43, -50, 138, 130 } },
			["fire-100-fl3"] = { x = 648, y = 746, w = 78, h = 84, box = { -50.5, -68.5, 138, 130 } },
			["fire-100-front"] = { x = 716, y = 247, w = 258, h = 62, box = { -4.5, -98.5, 138, 130 } },
			["fire-3-base"] = { x = 2, y = 840, w = 228, h = 179, box = { -12, -39.5, 138, 130 } },
			["fire-3-fl1"] = { x = 642, y = 901, w = 82, h = 96, box = { -48.5, -63.5, 138, 130 } },
			["fire-3-fl2"] = { x = 518, y = 510, w = 60, h = 70, box = { -54, -75, 138, 130 } },
			["fire-3-fl3"] = { x = 582, y = 510, w = 44, h = 48, box = { -58.5, -85.5, 138, 130 } },
			["fire-3-front"] = { x = 256, y = 518, w = 258, h = 62, box = { -4.5, -98.5, 138, 130 } },
			["fire-30-base"] = { x = 2, y = 423, w = 250, h = 211, box = { -6.5, -20.5, 138, 130 } },
			["fire-30-fl1"] = { x = 322, y = 247, w = 128, h = 148, box = { -37, -39, 138, 130 } },
			["fire-30-fl2"] = { x = 552, y = 788, w = 92, h = 109, box = { -46, -56.5, 138, 130 } },
			["fire-30-fl3"] = { x = 630, y = 505, w = 69, h = 74, box = { -52.5, -73, 138, 130 } },
			["fire-30-front"] = { x = 454, y = 313, w = 258, h = 62, box = { -4.5, -98.5, 138, 130 } },
			["fire-365-base"] = { x = 2, y = 2, w = 276, h = 235, box = { 0, -6.5, 138, 130 } },
			["fire-365-fl1"] = { x = 242, y = 828, w = 158, h = 185, box = { -29.5, -22, 138, 130 } },
			["fire-365-fl2"] = { x = 474, y = 650, w = 114, h = 134, box = { -40.5, -44.5, 138, 130 } },
			["fire-365-fl3"] = { x = 552, y = 901, w = 86, h = 92, box = { -48.5, -64.5, 138, 130 } },
			["fire-365-front"] = { x = 716, y = 313, w = 258, h = 62, box = { -4.5, -98.5, 138, 130 } },
			["fire-365-rays"] = { x = 550, y = 2, w = 242, h = 241, box = { -8.5, -0.5, 138, 130 } },
			["fire-7-base"] = { x = 2, y = 638, w = 236, h = 198, box = { -10, -28.5, 138, 130 } },
			["fire-7-fl1"] = { x = 518, y = 379, w = 108, h = 127, box = { -42, -49, 138, 130 } },
			["fire-7-fl2"] = { x = 592, y = 650, w = 78, h = 92, box = { -49.5, -64.5, 138, 130 } },
			["fire-7-fl3"] = { x = 703, y = 505, w = 59, h = 64, box = { -55, -78, 138, 130 } },
			["fire-7-front"] = { x = 454, y = 247, w = 258, h = 62, box = { -4.5, -98.5, 138, 130 } },
			["fire-glow"] = { x = 2, y = 241, w = 316, h = 178, box = { -1, -1, 160, 90 } },
			["fire-none"] = { x = 256, y = 423, w = 258, h = 91, box = { -4.5, -84, 138, 130 } },
			["fire-out-base"] = { x = 242, y = 638, w = 228, h = 186, box = { -12, -26.5, 138, 130 } },
			["fire-out-embers"] = { x = 552, y = 997, w = 58, h = 24, box = { -53.5, -97.5, 138, 130 } },
			["fire-out-front"] = { x = 474, y = 584, w = 258, h = 62, box = { -4.5, -98.5, 138, 130 } },
		},
	},
	Card = {
		file = MEDIA .. "Card",
		width = 2048,
		height = 1024,
		scale = 1.25,
		sprites = {
			card = { x = 1006, y = 2, w = 1040, h = 595, box = { 16, 8, 800, 434 } },
			drawer = { x = 2, y = 2, w = 1000, h = 645, box = { 16, 8, 768, 474 } },
		},
	},
	Flies = {
		file = MEDIA .. "Flies",
		width = 1024,
		height = 1024,
		scale = 2,
		sprites = {
			["fly-ashenvale_olive"] = { x = 2, y = 582, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-barrens_dun"] = { x = 2, y = 118, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-bloodsail_streamer"] = { x = 174, y = 234, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-booty_bay_bucktail"] = { x = 346, y = 234, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-darkshore_dun"] = { x = 174, y = 698, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-deepwater_duchess"] = { x = 346, y = 582, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-desolace_drifter"] = { x = 518, y = 234, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-duskwood_shadow"] = { x = 518, y = 2, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-elwynn_royal"] = { x = 2, y = 814, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-feralas_fern"] = { x = 174, y = 466, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-gnomish_whirligig"] = { x = 2, y = 350, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-goldshire_gnat"] = { x = 346, y = 2, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-grimtotem_hackle"] = { x = 690, y = 234, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-kodo_hair_caddis"] = { x = 2, y = 698, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-kraken_ink_streamer"] = { x = 346, y = 350, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-lakeshire_coachman"] = { x = 690, y = 118, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-moonwell_silverwing"] = { x = 690, y = 350, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-mudsnout_woolly"] = { x = 2, y = 234, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-murloc_nymph"] = { x = 2, y = 2, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-nats_golden_doctor"] = { x = 174, y = 814, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-needles_ant"] = { x = 174, y = 350, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-phoenix_hackle"] = { x = 518, y = 350, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-raptor_quill"] = { x = 346, y = 118, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-redridge_ember"] = { x = 690, y = 2, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-silverpine_spinner"] = { x = 518, y = 118, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-swamp_midge"] = { x = 174, y = 118, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-tanaris_sandfly"] = { x = 174, y = 582, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-tarnished_spoon"] = { x = 2, y = 466, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-thunderhead_tiger"] = { x = 346, y = 466, w = 168, h = 112, box = { 2, 2, 80, 48 } },
			["fly-westfall_wheatwing"] = { x = 174, y = 2, w = 168, h = 112, box = { 2, 2, 80, 48 } },
		},
	},
	Glow = {
		file = MEDIA .. "Glow",
		width = 512,
		height = 512,
		scale = 0.5,
		sprites = {
			["cork-glow"] = { x = 2, y = 239, w = 476, h = 233, box = { 0, 0, 952, 466 } },
			["cork-shade"] = { x = 2, y = 2, w = 476, h = 233, box = { 0, 0, 952, 466 } },
		},
	},
	Tracker = {
		file = MEDIA .. "Tracker",
		width = 2048,
		height = 512,
		scale = 1.5,
		sprites = {
			["hl-e"] = { x = 958, y = 2, w = 615, h = 309, box = { 16, 16, 378, 174 } },
			["hl-n"] = { x = 1577, y = 2, w = 429, h = 249, box = { 16, 16, 254, 134 } },
			["trk-cork"] = { x = 2, y = 2, w = 462, h = 455, box = { 6, 6, 296, 277 } },
			["trk-drift"] = { x = 468, y = 2, w = 486, h = 419, box = { 12, 6, 306, 253 } },
			["trk-slip"] = { x = 468, y = 425, w = 426, h = 84, box = { 4, 2, 276, 46 } },
			["trk-slip-done"] = { x = 898, y = 425, w = 426, h = 84, box = { 4, 2, 276, 46 } },
		},
	},
	Marks = {
		file = MEDIA .. "Marks",
		width = 64,
		height = 64,
		scale = 2,
		sprites = {
			chev = { x = 28, y = 0, w = 18, h = 18, box = { 0, 0, 9, 9 } },
			fl = { x = 0, y = 0, w = 24, h = 30, box = { 0, 0, 12, 15 } },
			["tack-s"] = { x = 28, y = 32, w = 28, h = 30, box = { 1, 1, 9, 9 } },
		},
	},
}
