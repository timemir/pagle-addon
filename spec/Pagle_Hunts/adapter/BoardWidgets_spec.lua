-- The Hunts board's art kit (HNT-R60's second paragraph, HNT-R18, HNT-R55, HNT-R61, HNT-R63, HNT-R64, HNT-R76): what
-- each widget maker draws on the fake client, in variant E's tints and in-client textures.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

-- Hunts' ns, and a frame to draw on.
local function kit()
	local loaded = hunts.load()
	return loaded.ns, loaded.env.CreateFrame("Frame"), loaded
end

-- `color` as a texture keeps it: { r, g, b, alpha }.
local function rgba(color, alpha)
	return { color[1], color[2], color[3], alpha or 1 }
end

-- The shown textures in `list`.
local function shown(list)
	local out = {}
	for _, texture in ipairs(list) do
		if texture:IsShown() then
			out[#out + 1] = texture
		end
	end
	return out
end

describe("the board's art kit", function()
	describe("the wax seal (HNT-R64)", function()
		it("is red wax on the disc texture with its words, once done", function()
			local ns, parent = kit()
			local seal = ns.NewBoardSeal(parent, 72)

			seal:SetSeal("Hunted 12 Oct 2026", true)

			assert.is_true(seal.wax:IsShown())
			assert.are.equal("Interface\\CharacterFrame\\TempPortraitAlphaMask", seal.wax.texture)
			assert.are.same({ unpack(ns.BOARD_LOOK.seal) }, { unpack(seal.wax.vertexColor, 1, 3) })
			assert.are.equal("Hunted 12 Oct 2026", seal.label:GetText())
			assert.are.same({}, shown(seal.ring))
		end)

		it('is a dashed ring with faded words for "not yet"', function()
			local ns, parent = kit()
			local seal = ns.NewBoardSeal(parent, 72)
			seal:SetSeal("Hunted 12 Oct 2026", true)

			seal:SetSeal("not yet", false)

			assert.is_false(seal.wax:IsShown())
			assert.are.equal(18, #shown(seal.ring))
			assert.are.same(rgba(ns.BOARD_LOOK.sealOff), seal.ring[1].color)
			assert.are.same({ unpack(ns.BOARD_LOOK.sealOff) }, { unpack(seal.label.textColor, 1, 3) })
			assert.are.equal("not yet", seal.label:GetText())
		end)
	end)

	describe("the ink bar (HNT-R64, HNT-R66)", function()
		it("fills with tiled hatching from the left, in an ink outline, with its label", function()
			local ns, parent = kit()
			local bar = ns.NewBoardInkBar(parent, 102, 10)

			bar:SetBar(0.5, "5 / 10")

			assert.are.equal(50, bar.fill.width)
			assert.are.equal("Interface\\RaidFrame\\Shield-Overlay", bar.hatch.texture)
			assert.are.same({ 0, 50 / 16, 0, 8 / 16 }, bar.hatch.texCoord)
			assert.is_true(bar.hatch:IsShown())
			assert.are.same(rgba(ns.BOARD_LOOK.barInk), bar.outline.edges[1].color)
			assert.are.equal("5 / 10", bar.label:GetText())
		end)

		it("shows no fill at nothing, and no more than full past the end", function()
			local ns, parent = kit()
			local bar = ns.NewBoardInkBar(parent, 102, 10)

			bar:SetBar(0)
			assert.is_false(bar.fill:IsShown())
			assert.are.equal("", bar.label:GetText())
			bar:SetBar(3, "52 caught")
			assert.are.equal(100, bar.fill.width)
		end)
	end)

	describe("the timeline's bar styles (HNT-R63)", function()
		it("draws an open window as hatched ink in a solid outline", function()
			local ns, parent = kit()
			local bar = ns.NewBoardTimelineBar(parent, 12)

			bar:SetBar("hatched", 120, "22:00–04:00")

			assert.are.equal(120, bar.width)
			assert.are.same(rgba(ns.BOARD_LOOK.barFill), bar.fill.color)
			assert.is_true(bar.fill:IsShown())
			assert.is_true(bar.hatch:IsShown())
			assert.are.equal(4, #shown(bar.outline.edges))
			assert.are.same({}, shown(bar.outline.dashes))
			assert.are.equal("22:00–04:00", bar.label:GetText())
		end)

		it("draws an unconfirmed window as faint hatching in a dashed outline", function()
			local ns, parent = kit()
			local bar = ns.NewBoardTimelineBar(parent, 12)

			bar:SetBar("dashed", 120)

			assert.is_false(bar.fill:IsShown())
			assert.is_true(bar.hatch:IsShown())
			assert.are.equal(0.45, bar.hatch.vertexColor[4])
			assert.are.same({}, shown(bar.outline.edges))
			assert.is_true(#shown(bar.outline.dashes) > 0)
			assert.are.same(rgba(ns.BOARD_LOOK.barInk), bar.outline.dashes[1].color)
		end)

		it("draws a Hunt short of skill as a dashed pencil outline with nothing inside", function()
			local ns, parent = kit()
			local bar = ns.NewBoardTimelineBar(parent, 12)
			bar:SetBar("hatched", 120)

			bar:SetBar("pencil", 60)

			assert.is_false(bar.fill:IsShown())
			assert.is_false(bar.hatch:IsShown())
			assert.are.same({}, shown(bar.outline.edges))
			local dashes = shown(bar.outline.dashes)
			assert.are.same(rgba(ns.BOARD_LOOK.pencil), dashes[#dashes].color)
		end)

		it("draws a camp that is up as a solid blue bar", function()
			local ns, parent = kit()
			local bar = ns.NewBoardTimelineBar(parent, 12)

			bar:SetBar("camp", 40)

			assert.are.same(rgba(ns.BOARD_LOOK.camp), bar.fill.color)
			assert.is_false(bar.hatch:IsShown())
			assert.are.same(rgba(ns.BOARD_LOOK.campEdge), bar.outline.edges[1].color)
		end)

		it("has a dash for every 7 pixels round a dashed outline, and drops the rest when it shrinks", function()
			local ns, parent = kit()
			local bar = ns.NewBoardTimelineBar(parent, 12)

			bar:SetBar("dashed", 70)
			-- 10 dashes along each of the top and bottom, 2 down each side.
			assert.are.equal(24, #shown(bar.outline.dashes))
			bar:SetBar("dashed", 14)
			assert.are.equal(8, #shown(bar.outline.dashes))
		end)

		it("refuses a style it doesn't have", function()
			local ns, parent = kit()

			assert.has_error(function()
				ns.NewBoardTimelineBar(parent, 12):SetBar("dotted", 40)
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
			-- variant E's bronze, silver and gold
			assert.are.same({ 0xa8 / 255, 0x65 / 255, 0x2a / 255 }, trims.bronze)
			assert.are.same({ 0xc9 / 255, 0xcc / 255, 0xd3 / 255 }, trims.silver)
			assert.are.same({ 0xf2 / 255, 0xc2 / 255, 0x30 / 255 }, trims.gold)
		end)

		it("ring an icon in its highest tier's trim, and nothing before the first", function()
			local ns, parent = kit()
			local icon = ns.NewBoardIcon(parent, 22)
			assert.is_false(icon.trim:IsShown())

			for tier = 1, 3 do
				icon:SetTrim(ns.Trim(tier))
				assert.is_true(icon.trim:IsShown())
				assert.are.same(rgba(ns.BOARD_LOOK.trims[ns.Trim(tier)]), icon.trim.color)
				assert.are.equal(2, #shown(icon.rings))
			end
			icon:SetTrim(nil)

			assert.is_false(icon.trim:IsShown())
			assert.are.same({}, shown(icon.rings))
		end)

		it("fill a reached tier's diamond in its trim, and leave one not reached in paper", function()
			local ns, parent = kit()
			local diamond = ns.NewBoardDiamond(parent, 14)

			diamond:SetDiamond("silver", true)
			assert.are.same(rgba(ns.BOARD_LOOK.trims.silver), diamond.face.color)
			diamond:SetDiamond("silver", false)
			assert.are.same(rgba(ns.BOARD_LOOK.paper), diamond.face.color)
		end)
	end)

	describe("item icons (HNT-R55)", function()
		it("are sepia: the icon in greys under the sepia tint", function()
			local ns, parent = kit()
			local icon = ns.NewBoardIcon(parent, 22)

			icon:SetIcon(133890)

			assert.are.equal(133890, icon.icon.texture)
			assert.is_true(icon.icon.desaturated)
			assert.are.same({ unpack(ns.BOARD_LOOK.sepia) }, { unpack(icon.icon.vertexColor, 1, 3) })
		end)

		it("take the tint given in place of sepia: a generated class's quality colour", function()
			local ns, parent = kit()
			local icon = ns.NewBoardIcon(parent, 22)

			icon:SetIcon("Interface\\Icons\\Trade_Fishing", { 0.12, 1, 0 })

			assert.are.same({ 0.12, 1, 0 }, { unpack(icon.icon.vertexColor, 1, 3) })
		end)
	end)

	describe("the group dots (HNT-R76)", function()
		it("are discs in Now green, Soon amber, Later grey and On demand blue", function()
			local ns, parent = kit()
			local expected = {
				now = { 0x4c, 0xc9, 0x4c },
				soon = { 0xff, 0xb7, 0x33 },
				later = { 0x9a, 0x9a, 0x9a },
				onDemand = { 0x6f, 0xb6, 0xff },
			}

			for group, bytes in pairs(expected) do
				local dot = ns.NewBoardDot(parent, 8)
				dot:SetGroup(group)
				assert.are.equal("Interface\\CharacterFrame\\TempPortraitAlphaMask", dot.texture)
				assert.are.same(
					{ bytes[1] / 255, bytes[2] / 255, bytes[3] / 255 },
					{ unpack(dot.vertexColor, 1, 3) },
					group
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
		it("draw the fleuron and the pointing hand as textures, in the gilt's tint and red ink", function()
			local ns, parent = kit()

			local fleuron = ns.NewBoardMark(parent, "fleuron", 12)
			local hand = ns.NewBoardMark(parent, "hand", 16)

			assert.are.same(
				{ "Texture", "Interface\\QuestFrame\\UI-Quest-BulletPoint" },
				{ fleuron.kind, fleuron.texture }
			)
			assert.are.same({ "Texture", "Interface\\Cursor\\Point" }, { hand.kind, hand.texture })
			assert.are.same({ unpack(ns.BOARD_LOOK.fleuron) }, { unpack(fleuron.vertexColor, 1, 3) })
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
		it("stack their words letter by letter down a cloth tab, standing out when chosen", function()
			local ns, parent = kit()
			local ribbon = ns.NewBoardRibbon(parent)

			ribbon:SetRibbon("Board", ns.BOARD_LOOK.boardRibbon, true)
			assert.are.equal("B\no\na\nr\nd", ribbon.label:GetText())
			assert.are.same(rgba(ns.BOARD_LOOK.boardRibbon), ribbon.face.color)
			assert.are.equal(1, ribbon:GetAlpha())
			assert.are.same({ "TOPLEFT", 6, 0 }, ribbon.face.points[1])

			ribbon:SetRibbon("Dusk", ns.BoardRibbonColor(1), false)
			assert.are.equal("D\nu\ns\nk", ribbon.label:GetText())
			assert.are.equal(0.85, ribbon:GetAlpha())
			assert.are.same({ "TOPLEFT", 0, 0 }, ribbon.face.points[1])
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
		it("is a gold plate sized to its words, and hidden with none", function()
			local ns, parent = kit()
			local plate = ns.NewBoardPlate(parent)

			plate:SetPlate("2 titles · 9 Hunts done")
			assert.is_true(plate:IsShown())
			assert.are.same(rgba(ns.BOARD_LOOK.plate), plate.face.color)
			assert.are.equal("2 titles · 9 Hunts done", plate.label:GetText())
			assert.is_true(plate.width > plate.label:GetStringWidth())

			plate:SetPlate(nil)
			assert.is_false(plate:IsShown())
		end)
	end)

	describe("the leather and the parchment (HNT-R60)", function()
		it("lay the leather's grain and the paper's texture over their tints", function()
			local ns, parent = kit()

			local leather = ns.NewBoardLeather(parent)
			local paper = ns.NewBoardParchment(parent, "RIGHT")

			assert.are.equal("Interface\\FrameGeneral\\UI-Background-Rock", leather.grain.texture)
			assert.are.same(rgba(ns.BOARD_COVER.leather), leather.leather.color)
			assert.are.equal("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal", paper.grain.texture)
			assert.are.same(rgba(ns.BOARD_LOOK.paper), paper.paper.color)
			assert.are.equal(6, #paper.spine)
		end)

		it("set text in the serif face, and notes in the handwriting face", function()
			local fonts = kit().BoardFonts()

			assert.are.equal("Fonts\\FRIZQT__.TTF", fonts.text.font[1])
			assert.are.equal("Fonts\\MORPHEUS.TTF", fonts.hand.font[1])
			assert.are.equal("Fonts\\MORPHEUS.TTF", fonts.margin.font[1])
		end)

		it("set headings in small caps: capitals in the small kicker face", function()
			assert.are.equal("NATURAL HUNT", kit().BoardSmallCaps("Natural Hunt"))
		end)
	end)
end)
