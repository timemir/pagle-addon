if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The books art kit's atlases (the Hunts board and the Stats book, post-1.0 art): texel rectangles in its textures, 2
-- texels per UI unit. `box` is where the drawn element sits in its sprite, in UI units from the sprite's top left (x,
-- y, w, h): code places the box, and the sprite's margin carries its shadow or glow. The book shell (leather,
-- parchment, the binding and wax atlas) and the kit's parts are Core's media (Pagle/media/books), which Stats reads too;
-- each tracker frame is Hunts' own (Pagle_Hunts/media/books), so a tracker loads only the frame it wears. Repacked from
-- the kit's BookParts.tga (art/books/generate.py in the dev's kit) with its tracker frames split out; the textures are
-- BLP (DXT5), encoded by scripts/encode-blp.py.

local CORE = "Interface\\AddOns\\Pagle\\media\\books\\"
local OWN = "Interface\\AddOns\\Pagle_Hunts\\media\\books\\"

--- The leather's grain (tiled, 128 UI units a repeat) and the page paper, whole textures.
ns.BOOK_FILES = { leather = CORE .. "Leather", parchment = CORE .. "Parchment" }

--- The notebook covers that swap the leather's grain for a fill drawn at the board's size (HNT-R70, HNT-R121): the kit
--- v2's Oilcloth and Verdigris, Hunts' own media, loaded only when worn.
ns.COVER_FILES = { oilcloth = OWN .. "Cover-oil", verdigris = OWN .. "Cover-verd" }

-- The expansion kit's sprites (goods.json): Covers2's closed-notebook swatches, each 230 x 295 texels at 1.25 to the UI
-- unit, the notebook 150 x 196 in it; TrackerFrames2's frames, 556 x 440 texels at 2, the frame 262 x 200 in it.
---@param at table<string, integer[]>
---@param w integer
---@param h integer
---@param box number[]
---@return table<string, HuntsArtSprite>
local function grid(at, w, h, box)
	local sprites = {}
	for name, xy in pairs(at) do
		sprites[name] = { x = xy[1], y = xy[2], w = w, h = h, box = box }
	end
	return sprites
end

---@type table<string, HuntsArtAtlas>
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
	-- The kit v2's parts only the board draws, Hunts' own: Verdigris's gilt corner, the checklist's tick and the pen
	-- mark of a Hunt that waits on the player. Repacked from the kit's BookParts.tga, with mips.
	Hunts = {
		file = OWN .. "HuntsParts",
		width = 128,
		height = 128,
		scale = 2,
		sprites = {
			["verd-corner"] = { x = 0, y = 0, w = 80, h = 80, box = { 0, 0, 40, 40 } },
			["tick"] = { x = 88, y = 0, w = 36, h = 44, box = { 2, 2, 14, 18 } },
			["pen"] = { x = 88, y = 48, w = 30, h = 30, box = { 0, 0, 15, 15 } },
		},
	},
	-- The tracker frames for sale (HNT-R121): Ink Wash's paper with its wash, Wax Seal's parchment with the seal.
	TrackerInk = {
		file = OWN .. "TrackerInk",
		width = 1024,
		height = 512,
		scale = 2,
		sprites = { ["frame"] = { x = 0, y = 0, w = 544, h = 456, box = { 2, 2, 268, 216 } } },
	},
	TrackerWax = {
		file = OWN .. "TrackerWax",
		width = 1024,
		height = 512,
		scale = 2,
		sprites = { ["frame"] = { x = 0, y = 0, w = 584, h = 468, box = { 4, 16, 272, 208 } } },
	},
	-- The Curio Shop expansion kit's (HNT-R123): each expansion cover's closed notebook, the shop's swatch and stage.
	Covers2 = {
		file = OWN .. "Covers2",
		width = 1024,
		height = 2048,
		scale = 1.25,
		sprites = grid({
			["swatch-canvas"] = { 2, 2 },
			["swatch-kraft"] = { 236, 2 },
			["swatch-tartan"] = { 470, 2 },
			["swatch-maplinen"] = { 704, 2 },
			["swatch-planks"] = { 2, 301 },
			["swatch-snakeskin"] = { 236, 301 },
			["swatch-shagreen"] = { 470, 301 },
			["swatch-lacquer"] = { 704, 301 },
			["swatch-bone"] = { 2, 600 },
			["swatch-brasscase"] = { 236, 600 },
			["swatch-scrimshaw"] = { 470, 600 },
			["swatch-trophycase"] = { 704, 600 },
			["swatch-pathfinder"] = { 2, 899 },
			["swatch-fiveseal"] = { 2, 1198 },
			["swatch-wagersilk"] = { 2, 1497 },
		}, 230, 295, { 12, 10, 150, 196 }),
	},
	-- The expansion's tracker frames (HNT-R123): one atlas, so a tracker in any of them loads the five.
	TrackerFrames2 = {
		file = OWN .. "TrackerFrames2",
		width = 2048,
		height = 1024,
		scale = 2,
		sprites = grid({
			["frame-slate"] = { 2, 2 },
			["frame-mapscrap"] = { 2, 446 },
			["frame-bounty"] = { 562, 2 },
			["frame-spyglass"] = { 562, 446 },
			["frame-wagerribbon"] = { 1122, 2 },
		}, 556, 440, { 8, 6, 262, 200 }),
	},
}
