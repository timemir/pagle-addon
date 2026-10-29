-- The round two's composed toast styles on the client, through the real TOC (announcements.md › Toast styles,
-- ANN-R82): a toast and Nod in a composed style are drawn from its rung's layers, each sprite at its place on its host,
-- its stamps as the style's plates; the layers rest with Animations off and on the Curio Shop's stage, and move from
-- the toast's landing while it shows, a sweep's strip scrolling through its mask's window, until it goes. Each frame's
-- sprites, places and texture coordinates are asserted, not pixels.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local bounds = dofile("spec/support/bounds.lua")

local STORM = "core.toaststyle.storm"
local DEEP = "ledger.toaststyle.deep"
local GLASS = "ledger.toaststyle.glass"
local RIPPLE = "core.toaststyle.ripple"
local LEDGER_STYLES = {
	DEEP,
	GLASS,
	"ledger.toaststyle.koi",
	"ledger.toaststyle.trophy",
	"ledger.toaststyle.slate",
	"ledger.toaststyle.ice",
	"ledger.toaststyle.stitch",
}

-- Core logged in on Forever over Ada's log, in which she bought Ripple and Storm Front, with the Ledger registered and
-- its seven round two styles earned in Core's slot (LED-R118). With `motion` false, Animations are off (SET-R30).
local function composedCore(options)
	options = options or {}
	local entries = history(2)
	entries[#entries + 1] = purchaseEntry(SERVER_TIME - 2000, RIPPLE, 150)
	entries[#entries + 1] = purchaseEntry(SERVER_TIME - 1900, STORM, 5000)
	local loaded = loadCore(entries, {})
	loaded.env.PagleDB.global.onboarding.notesOn = false
	if options.motion == false then
		loaded.ns.db.profile.announcements.motion = false
	end
	local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
	for _, id in ipairs(LEDGER_STYLES) do
		M:RegisterGood({
			id = id,
			slot = "core.toaststyle",
			name = id,
			isEarned = function()
				return true
			end,
			earnedText = "Earned",
		})
	end
	enterWorld(loaded, 3)
	loaded.client.runTimers()
	return loaded, M
end

local function equip(loaded, goodID)
	assert.is_true(loaded.env.Pagle.SetEquipped("core.toaststyle", goodID))
end

-- Raises a toast with a stamp riding on it and 5 Coins, both on one Cast, and runs the frame Core shows it on.
local function raiseStamped(loaded, M, rung)
	local cast = ("%s-%d-0"):format(PLAYER_GUID, SERVER_TIME)
	M:RaiseMoment({
		rung = rung or "toast",
		kind = "spec",
		title = "New Species",
		text = "Nightfin Snapper",
		cast = cast,
	})
	M:RaiseMoment({ rung = "nod", kind = "spec", title = "Rank up", cast = cast, coins = 5 })
	loaded.client.advance(0)
end

-- A composed style's rung's art and atlas.
local function artOf(loaded, styleID, rung)
	local style = loaded.ns.ToastStyleOf(styleID)
	return style.art.rungs[rung], loaded.ns.ATLASES[style.atlas]
end

-- A sprite's texture coordinates in its atlas.
local function coordsOf(atlas, name)
	local sprite = atlas.sprites[name]
	return {
		sprite.x / atlas.width,
		(sprite.x + sprite.w) / atlas.width,
		sprite.y / atlas.height,
		(sprite.y + sprite.h) / atlas.height,
	}
end

-- The drawn slot of the layer `name`.
local function slotOf(frame, name)
	for _, slot in ipairs(frame.toastLayers.active) do
		if slot.layer.name == name then
			return slot
		end
	end
	error("no layer " .. name)
end

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

describe("a toast in a composed toast style", function()
	it(
		"builds each layer of its rung in order: its sprite from the style's atlas, at its place, under the"
			.. " medallion, over its icon or over the words, in its blend (ANN-R82)",
		function()
			local loaded, M = composedCore()
			equip(loaded, STORM)

			raiseStamped(loaded, M)

			local toast = loaded.ns.announcementFrames.toast
			local rung, atlas = artOf(loaded, STORM, "toast")
			local layers = toast.toastLayers
			local parents = { under = toast.body, front = toast.bezel, over = layers.over }
			local drawLayers = { under = "BORDER", front = "OVERLAY", over = "ARTWORK" }
			assert.are.equal(#rung.layers, #layers.active)
			local sublevels = {}
			for i, layer in ipairs(rung.layers) do
				local slot = layers.active[i]
				local texture = slot.texture
				assert.are.equal(layer, slot.layer)
				assert.are.equal(atlas.file, texture.texture)
				assert.are.same(coordsOf(atlas, layer.sprite), texture.texCoord)
				assert.are.equal(parents[layer.host], texture:GetParent())
				local drawLayer, sublevel = texture:GetDrawLayer()
				assert.are.equal(drawLayers[layer.host], drawLayer)
				sublevels[layer.host] = sublevels[layer.host] or -9
				assert(sublevel > sublevels[layer.host], layer.name)
				sublevels[layer.host] = sublevel
				assert.are.equal(layer.blend or "BLEND", texture.blendMode)
				-- The toast's own page is its rung: each sprite by its centre, at its size, unturned.
				local _, anchor, relative, x, y = texture:GetPoint()
				assert.are.same({ toast.body, "TOPLEFT" }, { anchor, relative })
				assert(near(layer.x + layer.w / 2, x) and near(-(layer.y + layer.h / 2), y), layer.name)
				assert.are.same({ layer.w, layer.h, 0 }, { texture.width, texture.height, texture.rotation })
			end
			-- The words and stamps sit between: over the medallion, under its frame's over-host.
			assert.is_true(layers.over:GetFrameLevel() > toast.stamps[1].border:GetFrameLevel())
			assert.are.same(
				{ "ADD", "BLEND" },
				{ slotOf(toast, "fx1").texture.blendMode, slotOf(toast, "fx2").texture.blendMode }
			)
		end
	)

	it(
		"lays its medallion, words, stamp and Coins in the rung's boxes and inks, without the page, the trim or the"
			.. " wax (ANN-R82)",
		function()
			local loaded, M = composedCore()
			equip(loaded, STORM)

			raiseStamped(loaded, M, "toast.high")

			local toast = loaded.ns.announcementFrames.toast
			local rung, atlas = artOf(loaded, STORM, "high")
			assert.are.same({ false, false, false, false }, {
				toast.page.shown,
				toast.wax.shown,
				toast.bezel.Ring.shown,
				toast.bezel.Gloss.shown,
			})
			assert.are.same({ "TOPLEFT", toast.body, "TOPLEFT", rung.icon.x, -rung.icon.y }, { toast.bezel:GetPoint() })
			assert.are.same({ rung.icon.w, rung.icon.w }, { toast.bezel.Icon.width, toast.bezel.Icon.height })
			-- Its kicker and name block centred down the page, as the medallion is (#424), by what its two lines measure
			-- (the fake's are a flat 14 each, with a gap of 5), not by their fonts' sizes (#467).
			local block = 14 + 5 + 14
			assert.are.same(
				{ "TOPLEFT", toast.body, "TOPLEFT", rung.text.x, -(toast.body:GetHeight() - block) / 2 },
				{ toast.title:GetPoint() }
			)
			-- Its kicker in its own small caps, as written, set 16/13 larger than the kit's as the ledger's is (#467); its
			-- name in its hand and ink.
			assert.are.equal("New Species", toast.title:GetText())
			local what = rung.inks.what
			local size = math.floor(what.size * 16 / 13 + 0.5)
			assert.are.same({ loaded.ns.ArtFaceFont(what.face, size) }, { toast.title.fontObject })
			local name = loaded.ns.ANNOUNCE_COLORS[STORM .. ".high.name"]
			assert.are.same({ name[1], name[2], name[3] }, { unpack(toast.text.textColor, 1, 3) })
			-- The stamp: the style's plate three-sliced round its word, tilted, at the stamp's top right.
			local stamp = toast.stamps[1]
			local spec = loaded.ns.ToastStampArt(
				loaded.ns.ToastStyleOf(STORM),
				loaded.ns.ToastPage({
					headline = { rung = "toast.high", title = "T" },
				})
			)
			assert.are.same({ true, "RANK UP" }, { stamp.shown, stamp.label:GetText() })
			assert.are.same({ false, false }, { stamp.border.left ~= nil and stamp.border.left.shown, false })
			local plate = coordsOf(atlas, spec.sprite)
			-- Storm Front's pennant snaps: its plate turns from its motion's first frame, -4° (its tilt at rest).
			assert.are.equal(-4, spec.motion.transform[1][4])
			for i, slice in ipairs(stamp.plate) do
				assert.are.equal(atlas.file, slice.texture)
				assert(near(-4 * math.pi / 180, -slice.rotation), "slice " .. i)
			end
			assert.is_true(near(plate[1], stamp.plate[1].texCoord[1]) and near(plate[2], stamp.plate[3].texCoord[2]))
			assert.are.equal(spec.h, stamp.height)
			local _, _, _, x, y = toast.pivots[1]:GetPoint()
			assert.is_true(near(spec.x + spec.w - stamp.width / 2, x) and near(-(spec.y + spec.h / 2), y))
			-- The Coins: the brass coin centred in the coin's box, the amount ending at the amount's right.
			assert.are.same({ true, "+5" }, { toast.coins.shown, toast.coins.label:GetText() })
			local _, _, _, ax, ay = toast.coins.label:GetPoint()
			assert.is_true(near(rung.amt.x + rung.amt.w, ax) and near(-(rung.amt.y + rung.amt.h / 2), ay))
		end
	)

	it(
		"stands still in its resting frame with Animations off: every sprite as the kit drew it, but the lightning,"
			.. " which only flashes, unseen (ANN-R82, SET-R30)",
		function()
			local loaded, M = composedCore({ motion = false })
			equip(loaded, STORM)
			raiseStamped(loaded, M)
			local toast = loaded.ns.announcementFrames.toast

			local function look()
				local out = {}
				for _, slot in ipairs(toast.toastLayers.active) do
					local _, _, _, x, y = slot.texture:GetPoint()
					out[slot.layer.name] = { slot.texture.shown, slot.texture.alpha, x, y }
				end
				return out
			end
			local resting = look()
			loaded.client.nextFrame(4)
			loaded.client.nextFrame(3)

			assert.are.same({ true, false, false, true }, {
				resting.body[1],
				resting.fx1[1],
				resting.fx2[1],
				resting.mfront[1],
			})
			assert.are.same(resting, look())
			assert.is_nil(toast.toastLayers.playing)
			-- The pennant at its own tilt, not snapping.
			local tilt = loaded.ns.ToastStyleOf(STORM).art.rungs.toast.stamp.tilt
			assert.is_true(near(tilt * math.pi / 180, -toast.stamps[1].plate[1].rotation))
		end
	)

	it(
		"fits its rung to a taller page with a record ruler: the body stretched, the medallion centred, the stamp at"
			.. " the top right and the ruler under the name (ANN-R82, ANN-R22)",
		function()
			local loaded, M = composedCore({ motion = false })
			equip(loaded, STORM)
			M:RaiseMoment({
				rung = "toast",
				kind = "spec",
				title = "Size record",
				text = "Raw Glossy Mightfish",
				ruler = { old = 10, new = 12, unit = "lb", label = "weight" },
			})
			loaded.client.advance(0)

			local toast = loaded.ns.announcementFrames.toast
			local rung = artOf(loaded, STORM, "toast")
			local body = slotOf(toast, "body").texture
			local grow = 122 - rung.h
			assert.are.same({ 464, 122 }, { toast.width, toast.height })
			assert.are.same({ 464, 122 }, { body.width, body.height })
			assert.are.same(
				{ "TOPLEFT", toast.body, "TOPLEFT", rung.icon.x, -(rung.icon.y + grow / 2) },
				{ toast.bezel:GetPoint() }
			)
			assert.is_true(toast.ruler.shown)
			assert.are.equal(rung.text.x, select(4, toast.ruler:GetPoint()))
			-- The medallion's front keeps its size, centred down the taller page.
			local front = slotOf(toast, "mfront")
			local _, _, _, _, y = front.texture:GetPoint()
			local layer = front.layer
			assert.is_true(near(-(layer.y + grow / 2 + layer.h / 2), y))
			assert.are.same({ layer.w, layer.h }, { front.texture.width, front.texture.height })
		end
	)

	it(
		"keeps a ruled toast's words at the rung's top in every composed style, so the ruler and its label end within"
			.. " the page and clear the words, whatever the headline's rung (#468, ANN-R82)",
		function()
			local loaded, M = composedCore({ motion = false })
			local ids = {}
			for id in pairs(loaded.ns.TOAST_STYLE_ART2) do
				ids[#ids + 1] = id
			end
			table.sort(ids)
			assert.is_true(#ids >= 28)
			for _, rungName in ipairs({ "toast.low", "toast", "toast.high" }) do
				M:RaiseMoment({
					rung = rungName,
					kind = "spec",
					title = "Size record",
					text = "Raw Glossy Mightfish",
					ruler = { old = 10, new = 12, unit = "lb", label = "weight" },
				})
				loaded.client.advance(0)
				local toast = loaded.ns.announcementFrames.toast
				local announcement = toast.display.announcement
				local page = loaded.ns.ToastPage(announcement)
				assert.is_true(page.ruled)
				for _, id in ipairs(ids) do
					announcement.style = id
					loaded.ns.DrawAnnouncement(toast, toast.display)
					local label = ("%s on %s"):format(id, rungName)
					local rung = loaded.ns.ToastRungArt(loaded.ns.ToastStyleOf(id), page) --[[@as PagleToastRung]]
					local titleTop = -select(5, toast.title:GetPoint())
					local rulerTop = -select(5, toast.ruler:GetPoint())
					-- The words from the rung's own top, not moved down with the page's lower half.
					assert(titleTop == rung.text.y, label .. ": the words start at " .. titleTop)
					-- The ruler is 28 tall (its track's foot is 26 down) and the label stands under it.
					assert(rulerTop + 28 <= page.h, label .. ": the ruler ends at " .. rulerTop + 28)
					-- It starts below the kicker, the gap and the name line, at their fonts' sizes.
					local words = math.floor(rung.inks.what.size * 16 / 13 + 0.5) + 5 + rung.inks.name.size
					assert(rulerTop >= titleTop + words, label .. ": the ruler starts at " .. rulerTop)
				end
				loaded.client.advance(10)
			end
		end
	)

	it("moves its layers from the toast's landing while it shows, and stops them as it goes (ANN-R82)", function()
		local loaded, M = composedCore()
		local Ledger = M
		equip(loaded, DEEP)
		raiseStamped(loaded, Ledger)
		local toast = loaded.ns.announcementFrames.toast
		local bob = slotOf(toast, "fx1")
		local function bobY()
			local _, _, _, _, y = bob.texture:GetPoint()
			return y
		end
		local rest = bobY()

		assert.is_not_nil(toast.toastLayers.playing)
		loaded.client.nextFrame(0.5) -- not landed yet: it holds its first frame
		assert.is_true(near(rest, bobY()))
		loaded.client.nextFrame(0.48 + 1.3) -- landed, and half its 2.6 s bob on: 3 units down
		assert.is_true(near(rest - 3, bobY()))
		loaded.client.nextFrame(1.3) -- and back
		assert.is_true(near(rest, bobY()))

		loaded.client.nextFrame(8.7 + 0.4 - 3.58) -- it settles, stays its 6 s and leaves
		assert.is_false(toast.shown)
		assert.is_nil(toast.toastLayers.playing)
		local gone = bobY()
		loaded.client.nextFrame(1.3)
		assert.are.equal(gone, bobY())
	end)

	it(
		"sweeps Chapel Glass's band of light across the glass: its strip scrolled through a window the size of its"
			.. " mask, under the mask (ANN-R82)",
		function()
			local loaded, M = composedCore()
			equip(loaded, GLASS)
			raiseStamped(loaded, M)
			local toast = loaded.ns.announcementFrames.toast
			local rung, atlas = artOf(loaded, GLASS, "toast")
			local sweep = slotOf(toast, "fx1")
			local layer = sweep.layer
			local window = layer.motion.window
			local strip = coordsOf(atlas, layer.sprite)
			local k = window.w / layer.w

			-- Its mask: the panel's sprite at the mask's place, on the strip.
			local mask = sweep.mask
			assert.are.same({ mask }, sweep.texture.masks)
			assert.are.same({ atlas.file, coordsOf(atlas, layer.mask.sprite) }, { mask.texture, mask.texCoord })
			assert.are.same({ "TOPLEFT", toast.body, "TOPLEFT", layer.mask.x, -layer.mask.y }, { mask:GetPoint() })
			assert.are.same({ layer.mask.w, layer.mask.h }, { mask.width, mask.height })
			-- The strip shows through its window: the window's size, at the window's place.
			assert.are.same({ window.w, window.h }, { sweep.texture.width, sweep.texture.height })
			assert.are.same({ "TOPLEFT", toast.body, "TOPLEFT", window.x, -window.y }, { sweep.texture:GetPoint() })
			assert.are.equal(rung.w, window.w)
			-- At first the strip's far end (CSS's 100%): empty glass.
			local du = strip[2] - strip[1]
			assert.is_true(sweep.texture.shown)
			assert.is_true(near(strip[1] + du * (1 - k), sweep.texture.texCoord[1]))
			assert.is_true(near(strip[2], sweep.texture.texCoord[2]))
			-- Landed, the band crosses from 55% of its 6 s to 85%: midway it is the strip's middle.
			loaded.client.nextFrame(0.98 + 6 * 0.7)
			assert.is_true(near(strip[1] + du * (1 - k) / 2, sweep.texture.texCoord[1]))
			loaded.client.nextFrame(6 * 0.15)
			assert.is_true(near(strip[1], sweep.texture.texCoord[1]))
			assert.is_true(near(strip[1] + du * k, sweep.texture.texCoord[2]))
		end
	)
end)

describe("a Nod in a composed toast style", function()
	it(
		"draws its rung's body three-sliced to its line, the medallion's icon in its box and its words from its text"
			.. " box (ANN-R82)",
		function()
			local loaded, M = composedCore()
			equip(loaded, STORM)

			M:RaiseMoment({ rung = "nod", kind = "spec", title = "New here", text = "Oily Blackmouth" })
			loaded.client.advance(0)

			local nod = loaded.ns.announcementFrames.nod
			local rung, atlas = artOf(loaded, STORM, "nod")
			local slices = nod.toastLayers.slices
			local body = coordsOf(atlas, "nod-body")
			local width = nod:GetWidth()
			assert.are.same({ true, true, true }, { slices[1].shown, slices[2].shown, slices[3].shown })
			assert.are.same({ rung.slice.left, rung.slice.right }, { slices[1].width, slices[3].width })
			assert.is_true(near(width, rung.slice.left + slices[2].width + rung.slice.right))
			assert.is_true(near(body[1], slices[1].texCoord[1]) and near(body[2], slices[3].texCoord[2]))
			assert.are.same({ "TOPLEFT", nod, "TOPLEFT", width - rung.slice.right, 0 }, { slices[3]:GetPoint() })
			assert.are.same({ "LEFT", nod, "LEFT", rung.text.x, 0 }, { nod.title:GetPoint() })
			assert.are.same({ "TOPLEFT", nod, "TOPLEFT", rung.icon.x, -rung.icon.y }, { nod.bezel:GetPoint() })
			assert.is_false(nod.strip.left ~= nil and nod.strip.left.shown)
		end
	)

	it("crops an item icon's own square border off the medallion, as the standard medallion does (#421)", function()
		local loaded, M = composedCore()
		equip(loaded, STORM)

		M:RaiseMoment({ rung = "nod", kind = "spec", title = "New here", text = "Oily Blackmouth", icon = 136245 })
		loaded.client.advance(0)

		local crop = loaded.ns.ICON_CROP
		local icon = loaded.ns.announcementFrames.nod.icon
		assert.are.same({ 136245, { crop, 1 - crop, crop, 1 - crop } }, { icon.texture, icon.texCoord })
	end)
end)

describe("a toast announcing a variety in a composed toast style (#424, VAR-R26, ANN-R80, ANN-R82)", function()
	local ART = { texture = "Interface\\Varieties1", left = 0.09375, right = 0.1875, top = 0, bottom = 0.046875 }
	local CAST = ("%s-%d-0"):format(PLAYER_GUID, SERVER_TIME)

	local function rgb(color)
		return { color[1], color[2], color[3] }
	end

	-- The drawn slots of the medallion's back and front, whichever of them the style has.
	local function medallionSlots(toast)
		local slots = {}
		for _, slot in ipairs(toast.toastLayers.active) do
			if slot.layer.name == "mfront" or slot.layer.name == "mback" then
				slots[#slots + 1] = slot
			end
		end
		return slots
	end

	-- A size record and a first catch of a Rare variety on one Cast, as the Ledger raises them (LED-R97), and the
	-- toast Core shows for them.
	local function raiseRecord(loaded, M)
		M:RaiseMoment({
			rung = "toast.low",
			kind = "sizeRecord",
			order = 100,
			title = "Size record",
			text = "Raw Bristle Whisker Catfish",
			stamp = "Record",
			icon = 6291,
			cast = CAST,
			ruler = { old = 303, new = 304, unit = "length", label = "Tiddler" },
		})
		M:RaiseMoment({
			rung = "toast.low",
			kind = "newVariety",
			order = 120,
			title = "New variety",
			text = "Coral",
			stamp = "New variety",
			icon = 6291,
			cast = CAST,
			art = ART,
			variety = { name = "Coral", rarity = "rare" },
		})
		loaded.client.advance(0)
		return loaded.ns.announcementFrames.toast
	end

	it(
		"shows the art in the medallion, tints its front and back in the rarity's colour, writes the gem and name and"
			.. " inks the stamp's plate and word, the band beside the ruler (VAR-R26, ANN-R22)",
		function()
			local loaded, M = composedCore()
			equip(loaded, DEEP)
			local rare = loaded.ns.VARIETY_RARITIES[3]

			local toast = raiseRecord(loaded, M)

			assert.are.same({ ART.texture, { loaded.ns.HeadCrop(ART) } }, { toast.icon.texture, toast.icon.texCoord })
			local rings = medallionSlots(toast)
			assert.is_true(#rings > 0)
			for _, slot in ipairs(rings) do
				assert.are.same(
					{ true, rgb(rare.color) },
					{ slot.texture.desaturated == true, rgb(slot.texture.vertexColor) }
				)
			end
			assert.are.same({ "Raw Bristle Whisker Catfish ·", "Coral", true }, {
				toast.text:GetText(),
				toast.variety:GetText(),
				toast.gem.shown,
			})
			assert.are.same(
				{ rgb(rare.ink), rgb(rare.color) },
				{ rgb(toast.variety.textColor), rgb(toast.gem.fill.color) }
			)
			local stamp = toast.stamps[1]
			assert.are.same({ "NEW VARIETY", rgb(rare.ink) }, { stamp.label:GetText(), rgb(stamp.label.textColor) })
			for _, slice in ipairs(stamp.plate) do
				assert.are.same({ true, rgb(rare.ink) }, { slice.desaturated == true, rgb(slice.vertexColor) })
			end
			assert.are.equal("TIDDLER", toast.ruler.label:GetText())
			-- An opaque disc behind the art fills the icon's box, the rarity's tint over deep water (#424).
			local back = toast.bezel.Back
			assert.are.same(
				{ true, toast.bezel.Icon.width, toast.bezel.Icon.height, rgb(loaded.ns.ArtBacking(rare.color)) },
				{ back.shown, back.width, back.height, rgb(back.color) }
			)
		end
	)

	it("leaves the next toast's medallion, gem and stamp plate as the style draws them (VAR-R27)", function()
		local loaded, M = composedCore()
		equip(loaded, DEEP)
		local toast = raiseRecord(loaded, M)
		loaded.client.advance(10)

		raiseStamped(loaded, M)

		assert.are.equal(toast, loaded.ns.announcementFrames.toast)
		local rings = medallionSlots(toast)
		assert.is_true(#rings > 0)
		for _, slot in ipairs(rings) do
			assert.are.same({ false, { 1, 1, 1 } }, { slot.texture.desaturated == true, rgb(slot.texture.vertexColor) })
		end
		assert.are.same({ false, false, false }, { toast.gem.shown, toast.variety.shown, toast.gleams })
		assert.is_false(toast.bezel.Back.shown)
		for _, slice in ipairs(toast.stamps[1].plate) do
			assert.are.same({ false, { 1, 1, 1 } }, { slice.desaturated == true, rgb(slice.vertexColor) })
		end
	end)
end)

describe("a new variety's own toast in a composed toast style (#422, VAR-R28, ANN-R82)", function()
	local ART = { texture = "Interface\\Varieties1", left = 0.09375, right = 0.1875, top = 0, bottom = 0.046875 }
	local CAST = ("%s-%d-0"):format(PLAYER_GUID, SERVER_TIME)
	local FISH = "Raw Bristle Whisker Catfish"

	local function rgb(color)
		return { color[1], color[2], color[3] }
	end

	-- A first catch of Coral as the Ledger raises it (LED-R97), and the toast Core shows for it.
	local function raiseVariety(loaded, M, rarity, fish)
		local rare = rarity == "rare"
		M:RaiseMoment({
			rung = rare and "toast" or "toast.low",
			kind = rare and "rareVariety" or "newVariety",
			order = rare and 105 or 120,
			title = rare and "Rare variety" or "New variety",
			text = "Coral",
			stamp = not rare and "New variety" or nil,
			icon = 6291,
			cast = CAST,
			art = ART,
			ownStamp = true,
			kicker = "Decent · 34.2 cm",
			variety = { name = "Coral", rarity = rarity, fish = fish or FISH },
		})
		loaded.client.advance(0)
		return loaded.ns.announcementFrames.toast
	end

	it(
		"is drawn on the style's toast rung: the size as the kicker, the fish then the gem and the variety, its stamp's"
			.. " plate and word in the rarity's ink, within the page",
		function()
			local loaded, M = composedCore()
			equip(loaded, DEEP)
			for _, key in ipairs({ "common", "uncommon", "rare" }) do
				local rarity = loaded.ns.VARIETY_RARITIES[({ common = 1, uncommon = 2, rare = 3 })[key]]

				local toast = raiseVariety(loaded, M, key)
				local page = loaded.ns.ToastPage(toast.display.announcement)

				assert.are.same({ "toast", 464, 92 }, { page.page, toast:GetWidth(), toast:GetHeight() })
				-- Set in the style's own face, as its other titles are.
				assert.are.same({ "Decent · 34.2 cm", FISH .. " ·", "Coral" }, {
					toast.title:GetText(),
					toast.text:GetText(),
					toast.variety:GetText(),
				})
				local stamp = toast.stamps[1]
				assert.are.same(
					{ key == "rare" and "RARE VARIETY" or "NEW VARIETY", rgb(rarity.ink), false },
					{ stamp.label:GetText(), rgb(stamp.label.textColor), toast.stamps[2].shown == true }
				)
				for _, slice in ipairs(stamp.plate) do
					assert.are.same({ true, rgb(rarity.ink) }, { slice.desaturated == true, rgb(slice.vertexColor) })
				end
				assert.are.same({}, bounds.overflows(toast))
				assert.are.equal(key == "rare", toast.gleams)
				loaded.client.advance(10)
			end
		end
	)

	it(
		"fits the name line as the ledger's does: the font steps down before the variety's name is cut, and the fish's"
			.. " name stays whole while it can (#467, VAR-R28)",
		function()
			local loaded, M = composedCore()
			equip(loaded, DEEP)
			local rung = loaded.ns.ToastStyleOf(DEEP).art.rungs.toast
			local name = rung.inks.name
			-- Raises the variety's toast over `fish`, its words measured as the client's grow with the font (0.4 a byte
			-- a unit), and draws it again.
			local function drawn(fish)
				local toast = raiseVariety(loaded, M, "common", fish)
				for _, fontString in ipairs({ toast.text, toast.variety }) do
					fontString.GetStringWidth = function(self)
						return #(self.text or "") * 0.4 * self.fontObject.font[2]
					end
				end
				loaded.ns.DrawAnnouncement(toast, toast.display)
				loaded.client.advance(10)
				return toast
			end

			-- Whole at the ink's size: no step, nothing cut.
			local toast = drawn("Cat")
			assert.are.same(
				{ name.size, name.size },
				{ toast.text.fontObject.font[2], toast.variety.fontObject.font[2] }
			)
			assert.are.equal(#toast.text:GetText() * 0.4 * name.size, toast.text:GetWidth())

			-- A long fish name steps the font down, by whole units to no less than 70%, before anything is cut.
			toast = drawn(("F"):rep(14))
			local size = toast.text.fontObject.font[2]
			assert.is_true(size < name.size and size >= math.ceil(name.size * 0.7))
			assert.are.equal(size, toast.variety.fontObject.font[2])
			assert.are.equal(#toast.text:GetText() * 0.4 * size, toast.text:GetWidth())
			assert.are.equal(#"Coral" * 0.4 * size, toast.variety:GetWidth())
		end
	)

	it("steps down to the style's old Nod, with no own stamp, once the budget is spent", function()
		local loaded, M = composedCore()
		equip(loaded, DEEP)
		loaded.ns.db.profile.announcements.budget.count = 0

		raiseVariety(loaded, M, "common")
		local nod = loaded.ns.announcementFrames.nod

		assert.are.same(
			{ "New variety", "Coral", false },
			{ nod.title:GetText(), nod.text:GetText(), nod.stamps[1].shown == true }
		)
	end)
end)

describe("a composed toast style on the Curio Shop's stage", function()
	it("draws its sample toast in its resting frame, standing still (ANN-R82, wallet-and-shop.md › UI)", function()
		local loaded = composedCore()
		local stage = loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent)

		local sample = loaded.ns.DrawSampleToast(stage, STORM)
		loaded.client.nextFrame(7)

		assert.are.same({ true, false, true }, {
			sample.shown,
			sample.page.shown,
			slotOf(sample, "body").texture.shown,
		})
		assert.is_false(slotOf(sample, "fx2").texture.shown)
		assert.is_nil(sample.toastLayers.playing)
	end)
end)

describe("a round one toast style after a composed one", function()
	it(
		"draws as it always has: its page and trim back, the composed layers and plates gone and still (ANN-R80,"
			.. " ANN-R82)",
		function()
			local loaded, M = composedCore()
			equip(loaded, STORM)
			raiseStamped(loaded, M)
			local toast = loaded.ns.announcementFrames.toast

			equip(loaded, RIPPLE)

			assert.are.same({ true, true, true }, { toast.page.shown, toast.bezel.Ring.shown, toast.bezel.Gloss.shown })
			for _, pool in pairs(toast.toastLayers.pools) do
				for _, slot in pairs(pool) do
					assert.is_false(slot.texture.shown)
				end
			end
			assert.is_nil(toast.toastLayers.playing)
			local stamp = toast.stamps[1]
			assert.are.same(
				{ true, false, "RANK UP" },
				{ stamp.border.left.shown, stamp.plate[1].shown, stamp.label:GetText() }
			)
			assert.are.equal(loaded.ns.ART_FONTS.Stamp, stamp.label.fontObject)
			assert.are.equal(loaded.ns.ART_FONTS.Amt, toast.coins.label.fontObject)
		end
	)
end)
