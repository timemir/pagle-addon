-- The toast styles as data (announcements.md › Toast styles, ANN-R80; wallet-and-shop.md › SHOP-R25): Timber, Ripple
-- and Lantern Glow, keyed by Core's toast style good IDs, with Timber for any other ID.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

local TIMBER = "core.toaststyle.timber"
local RIPPLE = "core.toaststyle.ripple"
local LANTERN = "core.toaststyle.lanternglow"

describe("the toast styles", function()
	it("are Timber, Ripple and Lantern Glow, by SHOP-R25's good IDs in the core.toaststyle slot (ANN-R80)", function()
		local ids = {}
		for id in pairs(ns.TOAST_STYLES) do
			ids[#ids + 1] = id
		end
		table.sort(ids)

		assert.are.same({ LANTERN, RIPPLE, TIMBER }, ids)
		assert.are.same({ "core.toaststyle", TIMBER }, { ns.TOAST_STYLE_SLOT, ns.TOAST_STYLE_DEFAULT })
	end)

	it(
		"keep Timber as M2 drew it: its colours, no backdrop texture, no glow and the frames' own fonts (ANN-R80)",
		function()
			local timber = ns.ToastStyleOf(TIMBER)

			assert.are.same({ 0.16, 0.11, 0.07, 0.94 }, timber.colors.wood)
			assert.are.same({ 0.54, 0.42, 0.25, 1 }, timber.colors.edge)
			assert.are.same({ 1, 0.82, 0 }, timber.colors.title)
			assert.are.same({ 0.70, 0.13, 0.10, 1 }, timber.colors.stamp)
			assert.are.same({ 0.93, 0.87, 0.72, 1 }, timber.colors.parchment)
			assert.are.same({ nil, nil, nil }, { timber.backdrop, timber.glow, timber.titleFace })
		end
	)

	it("each name every colour role Timber does, so a frame finds each in any style (ANN-R80)", function()
		local timber = ns.ToastStyleOf(TIMBER)
		for _, id in ipairs({ RIPPLE, LANTERN }) do
			local style = ns.ToastStyleOf(id)
			assert.are.equal(id, style.id)
			for role, color in pairs(timber.colors) do
				assert.are.equal(#color, #style.colors[role], ("%s's %s"):format(id, role))
			end
		end
	end)

	it("give Ripple and Lantern Glow a look of their own: in-client textures and their own edge (ANN-R80)", function()
		local ripple, lantern = ns.ToastStyleOf(RIPPLE), ns.ToastStyleOf(LANTERN)

		assert.are.same(
			{ "Interface\\FrameGeneral\\UI-Background-Marble", "Interface\\Cooldown\\ping4" },
			{ ripple.backdrop.file, ripple.glow.file }
		)
		assert.are.same(
			{ "Interface\\CharacterFrame\\TempPortraitAlphaMask", "Fonts\\MORPHEUS.TTF" },
			{ lantern.glow.file, lantern.titleFace.file }
		)
		assert.are_not.same(ns.ToastStyleOf(TIMBER).colors.edge, ripple.colors.edge)
		assert.are_not.same(ripple.colors.edge, lantern.colors.edge)
	end)

	for _, id in ipairs({ "core.toaststyle.moonlit", "hunts.cover.velvet", "", 7 }) do
		it(("draw %s, which is no toast style, as Timber (ANN-R80)"):format(tostring(id)), function()
			assert.are.equal(ns.TOAST_STYLES[TIMBER], ns.ToastStyleOf(id))
		end)
	end

	it("draw Timber before Core's slot is registered, when GetEquipped has no good for it (ANN-R80)", function()
		assert.are.equal(ns.TOAST_STYLES[TIMBER], ns.ToastStyleOf(nil))
	end)
end)

describe("a toast style's glow cropped to its frame (ANN-R80)", function()
	it("is the whole square when it fits", function()
		assert.are.same(
			{ x = 10, y = 20, width = 40, height = 40, left = 0, right = 1, top = 0, bottom = 1 },
			ns.CroppedSquare(30, 40, 40, 300, 100)
		)
	end)

	it("keeps only the part inside the frame, with the texture coordinates of that part", function()
		assert.are.same(
			{ x = 0, y = 0, width = 60, height = 64, left = 0.25, right = 1, top = 0.2, bottom = 1 },
			ns.CroppedSquare(20, 24, 80, 350, 64)
		)
	end)

	it("is nil when none of it is inside the frame", function()
		assert.is_nil(ns.CroppedSquare(-50, 10, 20, 100, 100))
	end)
end)

describe("the sample toast", function()
	it(
		"is a toast in the given style, with sample stamps and Coins, raised by no Module and on no Cast (ANN-R80,"
			.. " SHOP-R25)",
		function()
			local sample = ns.SampleAnnouncement(RIPPLE)

			assert.are.same({ "toast", RIPPLE, nil }, { sample.rung, sample.style, sample.cast })
			assert.are.same(
				{ ns.L.TOAST_SAMPLE_TITLE, ns.L.TOAST_SAMPLE_TEXT },
				{ sample.headline.title, sample.headline.text }
			)
			assert.are.same({ ns.L.TOAST_SAMPLE_STAMP }, sample.stamps)
			assert.are.same({ 0, 5, sample.headline }, { sample.more, sample.coins, sample.moments[1] })
		end
	)
end)
