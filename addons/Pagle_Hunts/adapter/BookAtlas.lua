if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The books art kit's atlases (the Hunts board and the Stats book, post-1.0 art): texel rectangles in its textures, 2
-- texels per UI unit. `box` is where the drawn element sits in its sprite, in UI units from the sprite's top left (x,
-- y, w, h): code places the box, and the sprite's margin carries its shadow or glow. The wax atlas and the kit's parts
-- are Core's media (Pagle/media/books), which Core's book shell (ADR 0016) and Stats read too;
-- each tracker frame is Hunts' own (Pagle_Hunts/media/books), so a tracker loads only the frame it wears. Repacked from
-- the kit's BookParts.tga (art/books/generate.py in the dev's kit) with its tracker frames split out; the textures are
-- BLP (DXT5), encoded by scripts/encode-blp.py.

local CORE = "Interface\\AddOns\\Pagle\\media\\books\\"
local OWN = "Interface\\AddOns\\Pagle_Hunts\\media\\books\\"

-- The expansion kit's sprites (goods.json): TrackerFrames2's frames, 556 x 440 texels at 2, the frame 262 x 200 in it.
-- The covers' closed notebooks and fills are Core's now, as every binding's art is (ADR 0015).
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
	-- The wax seal and its "not yet" ring. The rest of the book (the close, the nameplate, the fleuron, the gutter, the
	-- paper and the leather) is Core's book shell's (ADR 0016).
	Book = {
		file = CORE .. "BookAtlas",
		width = 512,
		height = 256,
		scale = 2,
		sprites = {
			["seal"] = { x = 234, y = 2, w = 128, h = 128, box = { 0, 0, 64, 64 } },
			["seal-empty"] = { x = 366, y = 2, w = 128, h = 128, box = { 0, 0, 64, 64 } },
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
	-- The Pagle Wagers spread (HNT-R162, HNT-R163, HNT-R166, HNT-R167), the Wagers redesign's variant A: the ticket and
	-- its chosen look (three-sliced), the time dial's face, its dashed face and its fill in 36 steps (white, tinted), the
	-- event mark's layers in a 64 box (shadow, four skies, four waters, the ring, seven holiday charms), the shape glyphs
	-- and source marks (white, tinted; the companion's seal dot in red), the SETTLED stamp and a blank one, the ladder's
	-- rail, its hatched fill (cropped, not stretched), posts and token, the closing note's arrow, the pencil and holiday
	-- chips and the holiday tag. From the Pagle Wagers kit, whose sources are data/art/wagers/ (art.json there has the
	-- layout and inks, adapter/WagersArt.lua the inks as the client sets them).
	Wagers = {
		file = OWN .. "Wagers",
		width = 1024,
		height = 1024,
		scale = 2,
		sprites = {
			["arrow"] = { x = 900, y = 150, w = 120, h = 88, box = { 0, 0, 60, 44 } },
			["chip-holiday"] = { x = 134, y = 786, w = 244, h = 48, box = { 1, 1, 120, 22 } },
			["chip-pencil"] = { x = 134, y = 734, w = 244, h = 48, box = { 1, 1, 120, 22 } },
			["dial-ahead"] = { x = 234, y = 838, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-face"] = { x = 134, y = 838, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-01"] = { x = 334, y = 838, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-02"] = { x = 896, y = 242, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-03"] = { x = 896, y = 342, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-04"] = { x = 266, y = 442, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-05"] = { x = 896, y = 442, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-06"] = { x = 896, y = 542, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-07"] = { x = 896, y = 642, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-08"] = { x = 896, y = 742, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-09"] = { x = 434, y = 842, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-10"] = { x = 534, y = 842, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-11"] = { x = 634, y = 842, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-12"] = { x = 734, y = 842, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-13"] = { x = 834, y = 842, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-14"] = { x = 330, y = 542, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-15"] = { x = 382, y = 642, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-16"] = { x = 434, y = 742, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-17"] = { x = 266, y = 170, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-18"] = { x = 266, y = 270, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-19"] = { x = 534, y = 170, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-20"] = { x = 430, y = 170, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-21"] = { x = 634, y = 170, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-22"] = { x = 734, y = 170, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-23"] = { x = 366, y = 270, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-24"] = { x = 366, y = 370, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-25"] = { x = 430, y = 470, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-26"] = { x = 482, y = 570, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-27"] = { x = 534, y = 670, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-28"] = { x = 466, y = 270, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-29"] = { x = 466, y = 370, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-30"] = { x = 530, y = 470, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-31"] = { x = 582, y = 570, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-32"] = { x = 634, y = 670, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-33"] = { x = 734, y = 270, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-34"] = { x = 566, y = 370, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-35"] = { x = 566, y = 270, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["dial-fill-36"] = { x = 630, y = 470, w = 96, h = 96, box = { 0, 0, 48, 48 } },
			["mark-charm-hallows_end"] = { x = 134, y = 978, w = 44, h = 44, box = { 0, 0, 22, 22 } },
			["mark-charm-harvest_festival"] = { x = 374, y = 978, w = 44, h = 44, box = { 0, 0, 22, 22 } },
			["mark-charm-lunar_festival"] = { x = 230, y = 978, w = 44, h = 44, box = { 0, 0, 22, 22 } },
			["mark-charm-midsummer"] = { x = 326, y = 978, w = 44, h = 44, box = { 0, 0, 22, 22 } },
			["mark-charm-noblegarden"] = { x = 278, y = 978, w = 44, h = 44, box = { 0, 0, 22, 22 } },
			["mark-charm-stv_extravaganza"] = { x = 422, y = 978, w = 44, h = 44, box = { 0, 0, 22, 22 } },
			["mark-charm-winter_veil"] = { x = 182, y = 978, w = 44, h = 44, box = { 0, 0, 22, 22 } },
			["mark-ring"] = { x = 134, y = 434, w = 128, h = 128, box = { 0, 0, 64, 64 } },
			["mark-shadow"] = { x = 866, y = 2, w = 144, h = 144, box = { 4, 4, 64, 64 } },
			["mark-sky-day"] = { x = 2, y = 302, w = 128, h = 128, box = { 0, 0, 64, 64 } },
			["mark-sky-dusk"] = { x = 2, y = 434, w = 128, h = 128, box = { 0, 0, 64, 64 } },
			["mark-sky-night"] = { x = 2, y = 170, w = 128, h = 128, box = { 0, 0, 64, 64 } },
			["mark-sky-plain"] = { x = 2, y = 566, w = 128, h = 128, box = { 0, 0, 64, 64 } },
			["mark-water-coast"] = { x = 2, y = 698, w = 128, h = 128, box = { 0, 0, 64, 64 } },
			["mark-water-lake"] = { x = 2, y = 830, w = 128, h = 128, box = { 0, 0, 64, 64 } },
			["mark-water-pool"] = { x = 134, y = 302, w = 128, h = 128, box = { 0, 0, 64, 64 } },
			["mark-water-river"] = { x = 134, y = 170, w = 128, h = 128, box = { 0, 0, 64, 64 } },
			["post"] = { x = 482, y = 670, w = 48, h = 48, box = { 2, 2, 20, 20 } },
			["post-got"] = { x = 430, y = 570, w = 48, h = 48, box = { 2, 2, 20, 20 } },
			["rail-fill"] = { x = 2, y = 962, w = 890, h = 12, box = { 0, 0, 445, 6 } },
			["rail-track"] = { x = 2, y = 150, w = 894, h = 16, box = { 1, 1, 445, 6 } },
			["shape-bigones"] = { x = 470, y = 978, w = 36, h = 36, box = { 0, 0, 18, 18 } },
			["shape-haul"] = { x = 550, y = 978, w = 36, h = 36, box = { 0, 0, 18, 18 } },
			["shape-namedfish"] = { x = 590, y = 978, w = 36, h = 36, box = { 0, 0, 18, 18 } },
			["shape-quality"] = { x = 510, y = 978, w = 36, h = 36, box = { 0, 0, 18, 18 } },
			["shape-timed"] = { x = 330, y = 694, w = 36, h = 36, box = { 0, 0, 18, 18 } },
			["src-companion"] = { x = 662, y = 978, w = 28, h = 28, box = { 0, 0, 14, 14 } },
			["src-companion-seal"] = { x = 694, y = 978, w = 28, h = 28, box = { 0, 0, 14, 14 } },
			["src-rotation"] = { x = 630, y = 978, w = 28, h = 28, box = { 0, 0, 14, 14 } },
			["stamp-blank"] = { x = 134, y = 650, w = 192, h = 80, box = { 0, 0, 96, 40 } },
			["stamp-settled"] = { x = 134, y = 566, w = 192, h = 80, box = { 0, 0, 96, 40 } },
			["tag-holiday"] = { x = 2, y = 978, w = 128, h = 44, box = { 2, 1, 60, 18 } },
			["ticket"] = { x = 446, y = 2, w = 416, h = 120, box = { 4, 2, 200, 52 } },
			["ticket-sel"] = { x = 2, y = 2, w = 440, h = 130, box = { 6, 4, 200, 52 } },
			["token"] = { x = 330, y = 642, w = 48, h = 48, box = { 0, 0, 24, 24 } },
		},
	},
}
