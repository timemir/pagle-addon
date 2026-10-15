-- The Hunts board's art (HNT-R60's second paragraph, HNT-R18, HNT-R55, HNT-R61, HNT-R63, HNT-R64, HNT-R76): what each
-- widget maker draws on the fake client, in the books art kit's sprites (adapter/BookAtlas.lua) and faces.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local BOOK = "Interface\\AddOns\\Pagle\\media\\books\\BookAtlas"
local PARTS = "Interface\\AddOns\\Pagle\\media\\books\\BookParts"

-- Hunts' ns, and a frame to draw on.
local function kit()
	local loaded = hunts.load()
	local parent = loaded.env.CreateFrame("Frame")
	parent:SetSize(400, 300)
	return loaded.ns, parent, loaded
end

-- The texture coordinates of `w` × `h` texels at `x`, `y` in an atlas `width` × `height`.
local function coords(x, y, w, h, width, height)
	return { x / width, (x + w) / width, y / height, (y + h) / height }
end

-- The sprite a texture shows: its atlas file and its texel rectangle's top left, read back from its coordinates.
local function spriteAt(ns, texture)
	for _, atlas in pairs(ns.ATLASES) do
		if atlas.file == texture.texture then
			for name, sprite in pairs(atlas.sprites) do
				local c = texture.texCoord
				if
					math.abs(c[1] - sprite.x / atlas.width) < 1e-9
					and math.abs(c[3] - sprite.y / atlas.height) < 1e-9
					and math.abs(c[2] - (sprite.x + sprite.w) / atlas.width) < 1e-9
				then
					return name
				end
			end
		end
	end
end

describe("the books kit's sprite helpers (adapter/BookArt.lua)", function()
	it("show a sprite at its designed size, two texels a unit, its drawn element's box with it", function()
		local ns, parent = kit()

		local pin = ns.ArtSprite(parent, "Parts", "ic-pin")

		assert.are.equal(PARTS, pin.texture)
		assert.are.same(coords(450, 898, 28, 28, 512, 1024), pin.texCoord)
		assert.are.same({ 14, 14 }, { pin.width, pin.height })
		assert.are.same({ 1, 1, 12, 12 }, pin.box)
	end)

	it("scale a sprite so its drawn element is the size asked, its box with it", function()
		local ns, parent = kit()

		local ring = ns.ArtSprite(parent, "Parts", "ic-ring", "ARTWORK", 0, 44)

		assert.are.same({ 56, 56 }, { ring.width, ring.height })
		assert.are.same({ 6, 6, 44, 44 }, ring.box)
	end)

	it("place a sprite by its drawn element's top left, not the sprite's", function()
		local ns, parent = kit()
		local pin = ns.ArtSprite(parent, "Parts", "ic-pin")

		ns.PlaceSprite(pin, parent, 15, -4)

		assert.are.same({ "TOPLEFT", parent, "TOPLEFT", 14, 5 }, pin.points[1])
	end)

	it("cut a bar to length from its left end, unstretched", function()
		local ns, parent = kit()
		local texture = parent:CreateTexture()

		ns.SetCrop(texture, "Parts", "bar-hatch", 120)

		-- bar-hatch is at 18, 818 in BookParts, its stroke from its left edge
		assert.are.same(coords(18, 818, 240, 24, 512, 1024), texture.texCoord)
		assert.are.same({ 120, 12 }, { texture.width, texture.height })
	end)

	it("three-slice a sprite across: the caps keep their size, the middle stretches to the width", function()
		local ns, parent = kit()
		local slice = ns.NewBoardPlate(parent).brass

		ns.SetThreeSlice(slice, "Book", "plate", 120, 8, "ARTWORK")

		-- the plate is 128 × 64 texels at 274, 136: 8-unit caps at each end, the middle between them
		assert.are.same({ 120, 32 }, { slice.width, slice.height })
		assert.are.same(coords(274, 136, 16, 64, 512, 256), slice.left.texCoord)
		assert.are.same(coords(274 + 112, 136, 16, 64, 512, 256), slice.right.texCoord)
		assert.are.same(coords(274 + 16, 136, 96, 64, 512, 256), slice.middle.texCoord)
	end)

	it("slice a frame down to any height, repeating its middle in steps when it keeps a pitch", function()
		local ns, parent = kit()
		local frame = ns.NewTrackerBlock(parent).paper

		ns.SetVSlice(frame, "TrackerInk", "frame", 300, 30, 20)
		local stretched = 0
		for _, middle in ipairs(frame.middles) do
			stretched = stretched + (middle:IsShown() and 1 or 0)
		end
		assert.are.equal(1, stretched)
		assert.are.same({ 268, 300 }, { frame.width, frame.height })
		assert.are.equal(250, frame.middles[1].height)

		ns.SetVSlice(frame, "TrackerInk", "frame", 150, 30, 20, 40)
		local steps = {}
		for _, middle in ipairs(frame.middles) do
			if middle:IsShown() then
				steps[#steps + 1] = middle.height
			end
		end
		assert.are.same({ 40, 40, 20 }, steps)
	end)

	it("set every font in the kit's faces from Core's media", function()
		local ns = kit()
		local fonts = ns.BoardFonts()

		assert.are.equal("Interface\\AddOns\\Pagle\\media\\fonts\\IMFeENrm28P.ttf", fonts.text.font[1])
		assert.are.equal("Interface\\AddOns\\Pagle\\media\\fonts\\IMFeENit28P.ttf", fonts.note.font[1])
		assert.are.equal("Interface\\AddOns\\Pagle\\media\\fonts\\Caveat-Medium.ttf", fonts.hand.font[1])
		assert.are.equal("Interface\\AddOns\\Pagle\\media\\fonts\\Marcellus-Regular.ttf", fonts.crumb.font[1])
		assert.are.same({ 29, 14 }, { fonts.title.font[2], fonts.text.font[2] })
	end)
end)

describe("the board's art kit", function()
	describe("the wax seal (HNT-R64)", function()
		it("is the kit's red wax, tilted, with its word, date and year stacked, once done", function()
			local ns, parent = kit()
			local seal = ns.NewBoardSeal(parent, 88)

			seal:SetSeal("Hunted 12 Oct 2026", true, { "Hunted", "12 Oct", "2026" })

			assert.is_true(seal.wax:IsShown())
			assert.is_false(seal.empty:IsShown())
			assert.are.equal("seal", spriteAt(ns, seal.wax))
			assert.are.same(
				{ "HUNTED", "12 Oct", "2026" },
				{ seal.lines[1]:GetText(), seal.lines[2]:GetText(), seal.lines[3]:GetText() }
			)
			assert.is_false(seal.label:IsShown())
			assert.are.equal("Hunted 12 Oct 2026", seal.label:GetText())
		end)

		it('is the dashed ring with faded words for "not yet", or a wrapped line with no stack', function()
			local ns, parent = kit()
			local seal = ns.NewBoardSeal(parent, 88)
			seal:SetSeal("Hunted 12 Oct 2026", true, { "Hunted", "12 Oct", "2026" })

			seal:SetSeal("not yet", false)

			assert.is_false(seal.wax:IsShown())
			assert.are.equal("seal-empty", spriteAt(ns, seal.empty))
			assert.is_true(seal.empty:IsShown())
			assert.is_true(seal.label:IsShown())
			assert.is_false(seal.lines[2]:IsShown())
			assert.are.same({ unpack(ns.BOARD_LOOK.sealOff) }, { unpack(seal.label.textColor, 1, 3) })
			assert.are.equal("not yet", seal.label:GetText())
		end)
	end)

	describe("the ink bar (HNT-R64, HNT-R66)", function()
		it("lays the full stroke over the empty one, cut to its share, with its words in the hand", function()
			local ns, parent = kit()
			local bar = ns.NewBoardInkBar(parent, 160)

			bar:SetBar(0.5, "5 / 10")

			assert.is_true(bar.fill:IsShown())
			assert.are.equal(80, bar.fill.width)
			assert.are.same(coords(18 + 2, 790, 160, 24, 512, 1024), bar.fill.texCoord)
			assert.are.equal(160, bar.empty.width)
			assert.are.equal("5 / 10", bar.label:GetText())
			assert.are.equal(0.5, bar.value)
		end)

		it("shows no fill at nothing, and slices the full stroke past the sprite's own length", function()
			local ns, parent = kit()
			local bar = ns.NewBoardInkBar(parent, 261)

			bar:SetBar(0)
			assert.is_false(bar.fill:IsShown())
			assert.is_false(bar.fillSlice:IsShown())
			assert.are.equal("", bar.label:GetText())

			bar:SetBar(3, "52 caught")
			assert.is_false(bar.fill:IsShown())
			assert.is_true(bar.fillSlice:IsShown())
			assert.are.equal(261, bar.fillSlice.width)
		end)
	end)

	describe("the timeline's bar styles (HNT-R63)", function()
		it("draws each style in its own stroke: hatched, dashed, pencil, and the camp's blue", function()
			local ns, parent = kit()
			local bar = ns.NewBoardTimelineBar(parent)
			local expected = { hatched = 818, dashed = 846, pencil = 874, camp = 902 }

			for style, y in pairs(expected) do
				bar:SetBar(style, 120)
				assert.are.equal(y / 1024, bar.body.texCoord[3], style)
				assert.are.equal(y / 1024, bar.tip.texCoord[3], style)
			end
		end)

		it("cuts a bar to length and keeps its own right end, so both ends stay square-on", function()
			local ns, parent = kit()
			local bar = ns.NewBoardTimelineBar(parent)

			bar:SetBar("hatched", 60)

			assert.are.equal(60, bar.width)
			assert.are.equal(56, bar.body.width)
			assert.are.same(coords(18 + 380 - 8, 818, 8, 24, 512, 1024), bar.tip.texCoord)
			assert.is_true(bar.tip:IsShown())

			bar:SetBar("hatched", 6) -- too short for an end of its own
			assert.are.equal(6, bar.body.width)
			assert.is_false(bar.tip:IsShown())
		end)

		it("refuses a style it doesn't have", function()
			local ns, parent = kit()

			assert.has_error(function()
				ns.NewBoardTimelineBar(parent):SetBar("dotted", 40)
			end, "a timeline bar has no style dotted")
		end)
	end)

	describe("the tier trims (HNT-R18)", function()
		it("are bronze for tier 1, silver for 2, and gold for 3 and any later tier; none before tier 1", function()
			local ns = kit()
			local trims = ns.BOARD_LOOK.trims

			assert.is_nil(ns.BoardTrimColor(nil))
			assert.are.equal(trims.bronze, ns.BoardTrimColor(ns.Trim(1)))
			assert.are.equal(trims.silver, ns.BoardTrimColor(ns.Trim(2)))
			assert.are.equal(trims.gold, ns.BoardTrimColor(ns.Trim(3)))
			assert.are.equal(trims.gold, ns.BoardTrimColor(ns.Trim(5)))
		end)

		it("ring an icon in its highest tier's ring, and in the plain ring before the first", function()
			local ns, parent = kit()
			local icon = ns.NewBoardIcon(parent, 19, 22)
			assert.are.equal("ic-ring", spriteAt(ns, icon.ring))

			for tier = 1, 3 do
				icon:SetTrim(ns.Trim(tier))
				assert.are.equal("ic-ring-" .. ns.Trim(tier), spriteAt(ns, icon.ring))
				assert.are.equal(ns.Trim(tier), icon.trimName)
			end
			icon:SetTrim(nil)

			assert.are.equal("ic-ring", spriteAt(ns, icon.ring))
			assert.is_nil(icon.trimName)
		end)

		it("fill a reached tier's mark in its trim's ink, and leave one not reached an outline", function()
			local ns, parent = kit()
			local mark = ns.NewBoardDiamond(parent, 12)

			mark:SetDiamond("silver", true)
			assert.are.equal("tier-on", spriteAt(ns, mark.mark))
			assert.are.same({ unpack(ns.BOARD_LOOK.tierInks.silver) }, { unpack(mark.mark.vertexColor, 1, 3) })
			mark:SetDiamond("gold", false)
			assert.are.equal("tier-off", spriteAt(ns, mark.mark))
			assert.are.same({ unpack(ns.BOARD_LOOK.tierInks.gold) }, { unpack(mark.mark.vertexColor, 1, 3) })
		end)
	end)

	describe("item icons (HNT-R55)", function()
		it("are sepia and round: the icon in greys under the sepia tint, through the disc", function()
			local ns, parent = kit()
			local icon = ns.NewBoardIcon(parent, 19)

			icon:SetIcon(133890)

			assert.are.equal(133890, icon.icon.texture)
			assert.is_true(icon.icon.desaturated)
			assert.are.same({ unpack(ns.BOARD_LOOK.sepia) }, { unpack(icon.icon.vertexColor, 1, 3) })
			assert.are.equal("Interface\\CharacterFrame\\TempPortraitAlphaMask", icon.icon.masks[1].texture)
		end)

		it("take the tint given in place of sepia: a generated class's quality colour", function()
			local ns, parent = kit()
			local icon = ns.NewBoardIcon(parent, 19)

			icon:SetIcon("Interface\\Icons\\Trade_Fishing", { 0.12, 1, 0 })

			assert.are.same({ 0.12, 1, 0 }, { unpack(icon.icon.vertexColor, 1, 3) })
		end)
	end)

	describe("the group dots (HNT-R76)", function()
		it("are discs in Now green, Soon amber, Later grey and On demand blue, bright or in ink on paper", function()
			local ns, parent = kit()
			local expected = {
				now = { 0x4a, 0xa8, 0x4a, 0x3a, 0x8a, 0x3a },
				soon = { 0xe0, 0xa0, 0x30, 0xc8, 0x90, 0x30 },
				later = { 0x8a, 0x8a, 0x8a, 0x8a, 0x80, 0x70 },
				onDemand = { 0x4a, 0x8a, 0xd0, 0x3a, 0x6a, 0xa0 },
			}

			for group, bytes in pairs(expected) do
				local dot = ns.NewBoardDot(parent, 8)
				dot:SetGroup(group)
				assert.are.equal("Interface\\CharacterFrame\\TempPortraitAlphaMask", dot.face.texture)
				assert.are.same(
					{ bytes[1] / 255, bytes[2] / 255, bytes[3] / 255 },
					{ unpack(dot.face.vertexColor, 1, 3) }
				)
				dot:SetGroup(group, true)
				assert.are.same(
					{ bytes[4] / 255, bytes[5] / 255, bytes[6] / 255 },
					{ unpack(dot.face.vertexColor, 1, 3) }
				)
			end
		end)

		it("refuse a group there isn't", function()
			local ns, parent = kit()

			assert.has_error(function()
				ns.NewBoardDot(parent, 8):SetGroup("never")
			end, "no group never")
		end)
	end)

	describe("the marks (HNT-R60)", function()
		it("draw the kit's fleuron and the pointing hand as textures, the hand in red ink", function()
			local ns, parent = kit()

			local fleuron = ns.NewBoardMark(parent, "fleuron", 16)
			local hand = ns.NewBoardMark(parent, "hand", 16)

			assert.are.same({ "Texture", BOOK }, { fleuron.kind, fleuron.texture })
			assert.are.equal("fleuron", spriteAt(ns, fleuron))
			assert.are.same({ "Texture", "Interface\\Cursor\\Point" }, { hand.kind, hand.texture })
			assert.are.same({ unpack(ns.BOARD_LOOK.red) }, { unpack(hand.vertexColor, 1, 3) })
		end)

		it("refuse a mark there isn't", function()
			local ns, parent = kit()

			assert.has_error(function()
				ns.NewBoardMark(parent, "leather", 12)
			end, "no mark leather")
		end)

		it("are never font glyphs: no Hunts file writes ❧ or ☚", function()
			local glyphs = {}
			for _, file in ipairs(addonFiles("Pagle_Hunts")) do
				local text = readFile("addons/Pagle_Hunts/" .. file)
				if text:find("❧", 1, true) or text:find("☚", 1, true) then
					glyphs[#glyphs + 1] = file
				end
			end
			assert.are.same({}, glyphs)
		end)
	end)

	describe("the ribbons (HNT-R61)", function()
		it("hang a tinted grosgrain with its stitch and words, longer and brighter when chosen", function()
			local ns, parent = kit()
			local ribbon = ns.NewBoardRibbon(parent)
			local color = ns.BOARD_LOOK.boardRibbon

			ribbon:SetRibbon("Board", color, true)
			assert.are.equal("Board", ribbon.label:GetText())
			assert.are.same({ 104, 120 }, { ribbon.width, ribbon.height })
			assert.are.equal(PARTS, ribbon.body.texture)
			assert.are.same(
				{ color[1] * 1.13, color[2] * 1.13, color[3] * 1.13 },
				{ unpack(ribbon.body.vertexColor, 1, 3) }
			)
			assert.are.same({ unpack(ns.BOARD_LOOK.ribbonLabelOn) }, { unpack(ribbon.label.textColor, 1, 3) })

			ribbon:SetRibbon("Round the Clock", ns.BoardRibbonColor(1), false)
			assert.are.same({ 104, 104 }, { ribbon.width, ribbon.height })
			-- its bottom 104 of 140 units: the top 36 units (72 texels) dropped, the swallowtail end kept
			assert.are.equal((474 + 72) / 1024, ribbon.body.texCoord[3])
			assert.are.equal((474 + 284) / 1024, ribbon.body.texCoord[4])
			assert.are.same({ unpack(ns.BoardRibbonColor(1)) }, { unpack(ribbon.body.vertexColor, 1, 3) })
			assert.is_nil(ribbon.stitch.vertexColor) -- the gold stitch keeps its own colour
		end)

		it("brighten under the mouse, and show their tooltip", function()
			local ns, parent, loaded = kit()
			local ribbon = ns.NewBoardRibbon(parent)
			local color = ns.BoardRibbonColor(2)
			ribbon:SetRibbon("Turn of the Year", color, false)
			ribbon.tooltip = { "Turn of the Year" }

			ribbon:GetScript("OnEnter")(ribbon)

			assert.are.same(
				{ color[1] * 1.13, color[2] * 1.13, color[3] * 1.13 },
				{ unpack(ribbon.body.vertexColor, 1, 3) }
			)
			assert.are.same({ "Turn of the Year" }, loaded.client.tooltipLines())
		end)

		it("take the set colours in turn, round again after the last", function()
			local ns = kit()
			local colors = ns.BOARD_LOOK.ribbons

			assert.are.equal(colors[1], ns.BoardRibbonColor(1))
			assert.are.equal(colors[2], ns.BoardRibbonColor(2))
			assert.are.equal(colors[1], ns.BoardRibbonColor(#colors + 1))
		end)
	end)

	describe("the nameplate (HNT-R61)", function()
		it("is the brass plate sized to its words, and hidden with none", function()
			local ns, parent = kit()
			local plate = ns.NewBoardPlate(parent)

			plate:SetPlate("2 titles · 9 Hunts done")
			assert.is_true(plate:IsShown())
			assert.are.equal(BOOK, plate.brass.left.texture)
			assert.are.equal("2 titles · 9 Hunts done", plate.label:GetText())
			assert.are.equal(plate.label:GetStringWidth() + 22, plate.width)

			plate:SetPlate(nil)
			assert.is_false(plate:IsShown())
		end)
	end)

	describe("the leather and the parchment (HNT-R60)", function()
		it("lay the kit's grain, tiled, under its vignette, with the band round it above the ribbons", function()
			local ns, parent = kit()

			local leather = ns.NewBoardLeather(parent)

			assert.are.equal("Interface\\AddOns\\Pagle\\media\\books\\Leather", leather.fill.texture)
			-- 400 × 300 less the band's 7 at each side, 128 units a repeat
			assert.are.same({ 0, 386 / 128, 0, 286 / 128 }, leather.fill.texCoord)
			assert.are.same(coords(103, 3, 126, 126, 512, 256), leather.vignette.texCoord)
			assert.is_true(leather.band:IsShown())
			assert.are.equal(parent:GetFrameLevel() + 6, leather.band:GetFrameLevel())
			assert.are.same({ 16, 16 }, { leather.bandPieces.TL.width, leather.bandPieces.TL.height })
			assert.is_false(leather.grain:IsShown())
		end)

		it("wear an old cover's tint, grain and rule in place of the kit's leather", function()
			local ns, parent = kit()
			local leather = ns.NewBoardLeather(parent)

			leather:SetCover(ns.CoverLook("hunts.notebookcover.oilcloth"))

			assert.is_false(leather.fill:IsShown())
			assert.is_false(leather.band:IsShown())
			assert.is_true(leather.grain:IsShown())
			assert.are.equal("Interface\\FrameGeneral\\UI-Background-Marble", leather.grain.texture)
		end)

		it("lay the kit's parchment, mirrored on a right page, with the gutter at the spine", function()
			local ns, parent = kit()

			local left = ns.NewBoardParchment(parent, "RIGHT")
			local right = ns.NewBoardParchment(parent, "LEFT")

			assert.are.equal("Interface\\AddOns\\Pagle\\media\\books\\Parchment", left.paper.texture)
			assert.is_nil(left.paper.texCoord)
			assert.are.same({ 1, 0, 0, 1 }, right.paper.texCoord)
			assert.are.same({ "TOPRIGHT" }, left.gutter.points[1])
			assert.are.same({ "TOPLEFT" }, right.gutter.points[1])
			assert.are.equal(40, left.gutter.width)
		end)

		it("set headings in small caps: capitals in the small kicker face", function()
			assert.are.equal("NATURAL HUNT", kit().BoardSmallCaps("Natural Hunt"))
		end)
	end)
end)
