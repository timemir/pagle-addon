-- The Tackle Board's art kit (TKB-R100, TKB-R102, TKB-R107): what each widget maker draws on the fake client, in
-- variant C's tints, in-client textures and the two in-client faces.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

-- The Tackle Board's ns, and a frame to draw on.
local function kit()
	local loaded = board.load()
	return loaded.ns, loaded.env.CreateFrame("Frame"), loaded
end

-- `color` as a texture keeps it: { r, g, b, alpha }.
local function rgba(color, alpha)
	return { color[1], color[2], color[3], alpha or 1 }
end

-- The first three of a colour as a widget keeps it.
local function rgb(kept)
	return { kept[1], kept[2], kept[3] }
end

describe("the board's art kit", function()
	it("uses only in-client textures, as listed for the dev to judge (TKB-R100)", function()
		local ns = kit()

		assert.are.same({
			grain = "Interface\\FrameGeneral\\UI-Background-Rock",
			fleck = "Interface\\FrameGeneral\\UI-Background-Marble",
			paper = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal",
			disc = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
			hatch = "Interface\\RaidFrame\\Shield-Overlay",
			tick = "Interface\\Buttons\\UI-CheckBox-Check",
			box = "Interface\\Buttons\\UI-CheckBox-Up",
			flame = "Interface\\Icons\\Spell_Fire_Fire",
			pointer = "Interface\\CURSOR\\Point",
		}, ns.BOARD_TEXTURES)
	end)

	it(
		"draws the Campfire in textures: logs, a flame sized by its step, embers for a fire gone out (TKB-R106)",
		function()
			local ns, parent = kit()

			local fire = ns.NewBoardFlame(parent, 100)
			fire:SetFire({ state = "lit", step = 1, bright = 0.5 })
			local small = fire.flame.width
			fire:SetFire({ state = "lit", step = 2, bright = 0.5 })

			assert.are.equal(ns.BOARD_TEXTURES.flame, fire.flame.texture)
			assert.are.equal("ADD", fire.flame.blendMode)
			assert.are.same({ 50, 66 }, { small, fire.flame.width })
			assert.is_false(fire.embers[1]:IsShown())

			fire:SetFire({ state = "out", step = 0, bright = 0 })

			assert.is_false(fire.flame:IsShown())
			assert.is_true(fire.embers[1]:IsShown())
			assert.is_true(fire.ash:IsShown())
			assert.are.equal(2, #fire.logs)
		end
	)

	it("draws Kindling as sticks, the ones not held faint (TKB-R106)", function()
		local ns, parent = kit()

		local sticks = ns.NewBoardSticks(parent, 3)
		sticks:SetSticks(1)

		assert.are.equal(3, #sticks.sticks)
		assert.are.same(rgba(ns.BOARD_LOOK.logLight), sticks.sticks[1].color)
		assert.are.same(rgba(ns.BOARD_LOOK.stickOff), sticks.sticks[2].color)
		assert.are.equal(0.45, sticks.sticks[3]:GetAlpha())
	end)

	it("edges a rare compartment of the drawer in gilt, and shows a tied pattern's icon (TKB-R106)", function()
		local ns, parent = kit()

		local cell = ns.NewBoardFeltCell(parent, 94, 70)
		cell:SetCell({ id = "phoenix_hackle", rare = true, tied = true, icon = "Interface\\Icons\\X", text = "x" })

		assert.are.same(rgba(ns.BOARD_LOOK.gilt), cell.edges[1].color)
		assert.is_true(cell.icon:IsShown())
		assert.are.equal("Interface\\Icons\\X", cell.icon.texture)

		cell:SetCell({ id = "murloc_nymph", rare = false, tied = false, text = "not tied yet" })

		assert.are.same(rgba(ns.BOARD_LOOK.feltEdge), cell.edges[1].color)
		assert.is_false(cell.icon:IsShown())
	end)

	it("mirrors the pointing hand to point right (TKB-R106)", function()
		local ns, parent = kit()

		local hand = ns.NewBoardPointer(parent, 16)

		assert.are.equal(ns.BOARD_TEXTURES.pointer, hand.texture)
		assert.are.same({ 1, 0, 0, 1 }, hand.texCoord)
	end)

	it("outlines an empty pin in dashes with a lone tack and its words by hand (TKB-R105)", function()
		local ns, parent = kit()

		local pin = ns.NewBoardEmptyPin(parent, 150, 96)
		pin:SetEmpty("A fresh Notice at reset (in 13h)")

		assert.are.same({ 150, 96 }, { pin.width, pin.height })
		-- 10-pixel steps (a 6-pixel dash and its gap): 15 along each long side, 9 along each short one.
		assert.are.equal(48, #pin.dashes)
		assert.are.same(rgba(ns.BOARD_LOOK.corkFleck, 0.35), pin.dashes[1].color)
		assert.are.equal(pin, pin.tack:GetParent())
		assert.are.equal("A fresh Notice at reset (in 13h)", pin.label:GetText())
		assert.are.equal(ns.BoardFonts().hand, pin.label.fontObject)
	end)

	it("rings a highlighted pin in brass, hidden until shown (TKB-R109)", function()
		local ns, parent = kit()

		local ring = ns.NewBoardHighlight(parent)

		assert.is_false(ring:IsShown())
		assert.are.equal(4, #ring.edges)
		assert.are.same(rgba(ns.BOARD_LOOK.tackShine), ring.edges[1].color)
	end)

	it("sets printed text in the client's serif face and notes in its handwriting face (TKB-R100)", function()
		local ns = kit()
		local fonts = ns.BoardFonts()

		assert.are.equal("Fonts\\FRIZQT__.TTF", fonts.text.font[1])
		assert.are.equal("Fonts\\FRIZQT__.TTF", fonts.kicker.font[1])
		assert.are.equal("Fonts\\MORPHEUS.TTF", fonts.hand.font[1])
		assert.are.equal("Fonts\\MORPHEUS.TTF", fonts.updating.font[1])
	end)

	it("prints a line in ink, an Expedition's larger and darker (TKB-R102)", function()
		local ns, parent = kit()
		local fonts = ns.BoardFonts()

		local line = ns.NewBoardPrinted(parent)
		local large = ns.NewBoardPrinted(parent, true)

		assert.are.same({ fonts.text, ns.BOARD_LOOK.ink }, { line.fontObject, rgb(line.textColor) })
		assert.are.same({ fonts.title, ns.BOARD_LOOK.title }, { large.fontObject, rgb(large.textColor) })
	end)

	it('writes a line by hand in blue ink, or in the ink given (TKB-R102: the green "I\'m here")', function()
		local ns, parent = kit()

		local note = ns.NewBoardHand(parent)
		local here = ns.NewBoardHand(parent, ns.BOARD_LOOK.here)

		assert.are.equal(ns.BoardFonts().hand, note.fontObject)
		assert.are.same(ns.BOARD_LOOK.hand, rgb(note.textColor))
		assert.are.same(ns.BOARD_LOOK.here, rgb(here.textColor))
	end)

	it("sets a kicker in small caps: capitals in the kicker face (TKB-R102)", function()
		local ns, parent = kit()
		local kicker = ns.NewBoardKicker(parent)

		kicker:SetKicker("Expedition · Variety")

		assert.are.equal("EXPEDITION · VARIETY", kicker:GetText())
		assert.are.equal(ns.BoardFonts().kicker, kicker.fontObject)
	end)

	it("fills an ink bar with tiled hatching from the left, empty at 0 (TKB-R102)", function()
		local ns, parent = kit()
		local bar = ns.NewBoardInkBar(parent, 162, 9)
		assert.is_false(bar.fill:IsShown())

		bar:SetBar(12 / 30)

		assert.is_true(bar.hatch:IsShown())
		assert.are.equal(ns.BOARD_TEXTURES.hatch, bar.hatch.texture)
		assert.are.equal(64, bar.fill.width)
		assert.are.same({ 0, 4, 0, 7 / 16 }, bar.hatch.texCoord)
		bar:SetBar(2)
		assert.are.equal(1, bar.value)
	end)

	it("stamps words in capitals in a red-ink outline (TKB-R102: RE-POSTED)", function()
		local ns, parent = kit()
		local stamp = ns.NewBoardStamp(parent)

		stamp:SetStamp("Re-posted")

		assert.are.equal("RE-POSTED", stamp.label:GetText())
		assert.are.same(rgba(ns.BOARD_LOOK.red, 0.75), stamp.edges[1].color)
		assert.are.equal(4, #stamp.edges)
	end)

	it("makes a brass tack of discs: a dark rim, a brass head and its shine (TKB-R102, TKB-R105)", function()
		local ns, parent = kit()
		local tack = ns.NewBoardTack(parent, 12)

		for _, part in ipairs({ tack.rim, tack.head, tack.shine }) do
			assert.are.equal(ns.BOARD_TEXTURES.disc, part.texture)
		end
		assert.are.same(ns.BOARD_LOOK.tack, rgb(tack.head.vertexColor))
		assert.are.same(ns.BOARD_LOOK.tackShine, rgb(tack.shine.vertexColor))
	end)

	it("seals with red wax and its words (TKB-R102: an Expedition's pay)", function()
		local ns, parent = kit()
		local seal = ns.NewBoardSeal(parent, 40)

		seal:SetSeal("60")

		assert.are.equal(ns.BOARD_TEXTURES.disc, seal.wax.texture)
		assert.are.same(ns.BOARD_LOOK.seal, rgb(seal.wax.vertexColor))
		assert.are.equal("60", seal.label:GetText())
	end)

	it("pins a parchment slip with a brass tack, and a poster in darker paper with a red top (TKB-R102)", function()
		local ns, parent = kit()

		local slip = ns.NewBoardSlip(parent, 196, 118)
		local poster = ns.NewBoardSlip(parent, 250, 150, true)

		assert.are.same(rgba(ns.BOARD_LOOK.paper), slip.paper.color)
		assert.are.equal(ns.BOARD_TEXTURES.paper, slip.grain.texture)
		assert.is_nil(slip.top)
		assert.are.equal(slip, slip.tack:GetParent())
		assert.are.same(rgba(ns.BOARD_LOOK.poster), poster.paper.color)
		assert.are.same(rgba(ns.BOARD_LOOK.posterTop), poster.top.color)
	end)

	it("makes a wooden button that calls back, and greys its words while disabled (TKB-R107)", function()
		local ns, parent = kit()
		local clicks = 0
		local button = ns.NewBoardButton(parent, "Start my board", function()
			clicks = clicks + 1
		end)

		button:Click()
		button:SetUsable(false)
		button:Click()

		assert.are.equal(1, clicks)
		assert.are.equal("Start my board", button.label:GetText())
		assert.is_false(button:IsEnabled())
		assert.are.same(ns.BOARD_LOOK.buttonOff, rgb(button.label.textColor))
		button:SetUsable(true)
		assert.are.same(ns.BOARD_LOOK.sealText, rgb(button.label.textColor))
	end)

	it("brightens a wooden button's wood under the mouse, only while enabled (TKB-R107)", function()
		local ns, parent = kit()
		local button = ns.NewBoardButton(parent, "Start my board", function() end)
		local wood = rgba(ns.BOARD_LOOK.button)

		button:GetScript("OnEnter")(button)
		assert.are_not.same(wood, button.face.color)
		button:GetScript("OnLeave")(button)
		assert.are.same(wood, button.face.color)

		button:SetUsable(false)
		button:GetScript("OnEnter")(button)
		assert.are.same(wood, button.face.color)
	end)

	it(
		"lays the shell's wood, cork and ledge in their tints and grain, and a brass plaque in capitals (TKB-R100)",
		function()
			local ns, parent = kit()
			local look = ns.BOARD_LOOK

			local wood = ns.NewBoardWood(parent, 1000, 660)
			local cork = ns.NewBoardCork(parent, 948, 534)
			parent:SetSize(1000, 86)
			local ledge = ns.NewBoardLedge(parent)
			local plaque = ns.NewBoardPlaque(parent)
			plaque:SetPlaque("Tackle Board")

			assert.are.same(rgba(look.wood), wood.wood.color)
			assert.are.equal(ns.BOARD_TEXTURES.grain, wood.grain.texture)
			assert.are.same(rgba(look.cork), cork.cork.color)
			assert.are.equal(ns.BOARD_TEXTURES.fleck, cork.flecks.texture)
			assert.are.same(rgba(look.ledgeLip), ledge.lip.color)
			assert.are.equal(43, ledge.bottom.height)
			assert.are.equal("TACKLE BOARD", plaque.label:GetText())
			assert.are.same(rgba(look.brass), plaque.face.color)
		end
	)
end)
