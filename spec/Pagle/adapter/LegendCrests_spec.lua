-- The Legend crests on the client, through the real TOC (ledger.md › LED-R153, LED-R124; announcements.md › UI ›
-- Splash): a crest drawn from its atlas, layer by layer in the crest's box scaled to its width, with the Legend's icon
-- in sepia in its well and its plaque's word; its motion while it plays and its resting frame otherwise; the Legend
-- splash's crest at full size; and Pagle.NewLegendCrest for a Module. Sprites, places and coordinates are asserted,
-- not pixels.

local RACER, ANGELFISH, QUEENFISH = 19803, 19805, 19806
-- A Legend added after 1.0, with no crest of its own.
local NEWCOMER = 777200

-- Core logged in on Forever with the Ledger registered, its Letter answered and its Margin notes off. With `motion`
-- false, Animations are off (SET-R30).
local function loadCore(motion)
	local loaded = loadAddon("Pagle", foreverWith({ PagleLog = savedLog() }))
	loaded.client.addons.Pagle_Ledger = { metadata = { ["X-Pagle-API"] = "1" } }
	local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
	loaded.env.PagleDB.global.onboarding.notesOn = false
	loaded.client.fire("PLAYER_LOGIN")
	loaded.ns.onboarding:State().letter = "declined"
	loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)
	loaded.client.runTimers()
	if motion == false then
		loaded.ns.db.profile.announcements.motion = false
	end
	return loaded, M
end

-- A crest `width` wide on a frame of the screen's, through Core's API as a Module draws one.
local function newCrest(loaded, width)
	local parent = loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent)
	return loaded.env.Pagle.NewLegendCrest(parent, width), parent
end

-- The texture coordinates of `sprite` in `atlas`.
local function coordsOf(atlas, sprite)
	local s = atlas.sprites[sprite]
	return { s.x / atlas.width, (s.x + s.w) / atlas.width, s.y / atlas.height, (s.y + s.h) / atlas.height }
end

-- The drawn texture of the crest's layer `name`, and the layer.
local function layerOf(crest, name)
	for i, layer in ipairs(crest.look.art.layers) do
		if layer.name == name then
			return crest.box.layeredPiece.slots[i].texture, layer
		end
	end
	error("no layer " .. name)
end

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

describe("a Legend crest on the client (LED-R153)", function()
	it("draws each layer of a caught Legend's own crest from its atlas, at its box, in draw order", function()
		local loaded = loadCore()
		for itemID, key in pairs({ [RACER] = "racer", [ANGELFISH] = "angelfish", [QUEENFISH] = "queenfish" }) do
			local crest = newCrest(loaded, 150)

			crest:SetLegend(itemID, true)

			local art = loaded.ns.LEGEND_CREST_ART[key]
			local atlas = loaded.ns.ATLASES[art.atlas]
			assert.are.equal(key, crest.look.key)
			local sublevel = -math.huge
			for i, layer in ipairs(art.layers) do
				local texture = crest.box.layeredPiece.slots[i].texture
				assert.are.equal(atlas.file, texture.texture)
				assert.are.same(texture.texCoord and { unpack(texture.texCoord, 1, 4) }, coordsOf(atlas, layer.sprite))
				local drawLayer, level = texture:GetDrawLayer()
				assert.are.equal("ARTWORK", drawLayer)
				assert.is_true(level >= sublevel)
				sublevel = level
				assert.are.equal(layer.blend or "BLEND", texture.blendMode)
				assert.is_true(texture:IsShown())
			end
		end
	end)

	it("puts an unmoving layer at its box in the crest's 260 x 280 box, scaled to the crest's width", function()
		local loaded = loadCore()
		local crest = newCrest(loaded, 150)

		crest:SetLegend(RACER, true)

		assert.are.same({ 150, 280 * 150 / 260 }, { crest:GetWidth(), crest:GetHeight() })
		assert.are.same({ 260, 280 }, { crest.box:GetWidth(), crest.box:GetHeight() })
		assert.is_true(near(150 / 260, crest.box:GetScale()))
		local body, layer = layerOf(crest, "body")
		local point, relativeTo, relativePoint, x, y = body:GetPoint()
		assert.are.same({ "CENTER", crest.box, "TOPLEFT" }, { point, relativeTo, relativePoint })
		assert.is_true(near(layer.x + layer.w / 2, x) and near(-(layer.y + layer.h / 2), y))
		assert.are.same({ layer.w, layer.h }, { body:GetWidth(), body:GetHeight() })
	end)

	it("holds a caught Legend's icon in sepia, masked round in the well, under its plaque's word", function()
		local loaded = loadCore()
		local crest = newCrest(loaded, 190)

		crest:SetLegend(ANGELFISH, true)

		local icon = crest.icon
		assert.is_true(icon:IsShown())
		assert.are.equal(loaded.ns.TextureOf(ANGELFISH), icon.texture)
		assert.is_true(icon.desaturated)
		assert.are.same({ 1, 0.94, 0.82 }, { unpack(icon.vertexColor, 1, 3) })
		assert.are.equal(1, #icon.masks)
		assert.are.same({ "CENTER", crest.box, "TOPLEFT", 130, -124 }, { icon:GetPoint() })
		assert.is_true(icon:GetWidth() >= 112)
		assert.are.equal("LEGEND", crest.label:GetText())
	end)

	it(
		"shows the Unwritten crest with its own plain fish for a Legend not caught, and nothing of it (LED-R124)",
		function()
			local loaded = loadCore()
			local crest = newCrest(loaded, 150)

			crest:SetLegend(QUEENFISH, false)

			assert.are.equal("unwritten", crest.look.key)
			assert.are.equal(loaded.ns.ATLASES.LegendUnwritten.file, layerOf(crest, "body").texture)
			assert.is_true(layerOf(crest, "well"):IsShown())
			assert.is_false(crest.icon:IsShown())
			assert.are.equal("UNWRITTEN", crest.label:GetText())
		end
	)

	it("shows a caught Legend with no crest of its own in the Unwritten crest, its icon in the well", function()
		local loaded = loadCore()
		local crest = newCrest(loaded, 150)

		crest:SetLegend(NEWCOMER, true)

		assert.are.equal("unwritten", crest.look.key)
		assert.is_false(layerOf(crest, "well"):IsShown())
		assert.is_true(crest.icon:IsShown())
		assert.are.equal(loaded.ns.TextureOf(NEWCOMER), crest.icon.texture)
	end)

	it("keeps the plaque's word legible however small the crest is drawn", function()
		local loaded = loadCore()
		local small, large = newCrest(loaded, 150), newCrest(loaded, 260)

		small:SetLegend(RACER, true)
		large:SetLegend(RACER, true)

		local smallSize, largeSize = small.label.fontObject.font[2], large.label.fontObject.font[2]
		assert.are.equal(13, largeSize)
		assert.is_true(smallSize * 150 / 260 >= 9 - 0.25)
	end)
end)

describe("a Legend crest's motion on the client (LED-R153)", function()
	-- The Racer's streamers' turn now, in degrees clockwise.
	local function streamers(crest)
		return -math.deg(layerOf(crest, "fx2").rotation)
	end

	it("rests in its first frame until it plays, then moves while it shows", function()
		local loaded = loadCore()
		local crest = newCrest(loaded, 150)
		crest:SetLegend(RACER, true)
		loaded.client.update(0.2)
		assert.is_true(near(-2.5, streamers(crest)))

		crest:Play()
		loaded.client.update(0.225)

		assert.is_true(streamers(crest) > -2.5)
	end)

	it("stops back in its resting frame when stopped, and when it no longer shows", function()
		local loaded = loadCore()
		local crest, parent = newCrest(loaded, 150)
		crest:SetLegend(RACER, true)
		crest:Play()
		loaded.client.update(0.225)

		crest:Stop()
		loaded.client.update(0.2)
		assert.is_true(near(-2.5, streamers(crest)))

		crest:Play()
		loaded.client.update(0.225)
		parent:Hide()
		loaded.client.update(0.1)
		assert.is_true(near(-2.5, streamers(crest)))
		assert.is_nil(crest.moving)
	end)

	it("keeps the resting frame with Animations off, a glint that only flashes unseen (SET-R30)", function()
		local loaded = loadCore(false)
		local crest = newCrest(loaded, 150)
		crest:SetLegend(QUEENFISH, true)

		crest:Play()
		loaded.client.update(0.3)

		assert.are.equal(0, layerOf(crest, "fx1").alpha)
		assert.are.equal(0, layerOf(crest, "fx2").alpha)
		assert.is_nil(crest.moving)
	end)
end)

describe("the Legend splash's crest (announcements.md › UI › Splash, LED-R153)", function()
	-- Raises a splash for `icon` and runs the frame Core shows it on.
	local function splashFor(loaded, M, icon)
		M:RaiseMoment({ rung = "splash", kind = "spec", title = "Legend", text = "A Legend", icon = icon })
		loaded.client.advance(0)
		return loaded.ns.announcementFrames.splash
	end

	it("takes the Legend's own crest at full size, its icon in the well", function()
		local loaded, M = loadCore()

		local splash = splashFor(loaded, M, QUEENFISH)

		local crest = splash.legendCrest
		assert.are.same({ "queenfish", QUEENFISH }, { crest.look.key, crest.look.icon })
		assert.are.same({ 260, 280 }, { crest:GetWidth(), crest:GetHeight() })
		assert.is_true(crest.icon:IsShown())
		assert.are.equal(loaded.ns.TextureOf(QUEENFISH), crest.icon.texture)
	end)

	it("shows the Unwritten crest, with its icon, for a Legend with no crest of its own", function()
		local loaded, M = loadCore()

		local crest = splashFor(loaded, M, 6292).legendCrest

		assert.are.same({ "unwritten", 6292 }, { crest.look.key, crest.look.icon })
	end)

	it("moves while the splash shows, and rests once it is clicked away", function()
		local loaded, M = loadCore()
		local splash = splashFor(loaded, M, QUEENFISH)
		local glint = layerOf(splash.legendCrest, "fx1")

		loaded.client.update(0.3)
		assert.is_true(glint.alpha > 0)

		splash:Click()
		loaded.client.update(0.1)
		assert.are.equal(0, glint.alpha)
		loaded.client.update(0.3)
		assert.are.equal(0, glint.alpha)
	end)

	it("keeps the crest's resting frame with Animations off (SET-R30)", function()
		local loaded, M = loadCore(false)
		local splash = splashFor(loaded, M, QUEENFISH)

		loaded.client.update(0.3)

		assert.are.equal(0, layerOf(splash.legendCrest, "fx1").alpha)
	end)
end)
