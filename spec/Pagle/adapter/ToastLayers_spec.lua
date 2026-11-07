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

	it("ends the name before the Coins' amount as it draws, wider than the amount's box (ANN-R82)", function()
		local loaded, M = composedCore()
		equip(loaded, STORM)

		M:RaiseMoment({
			rung = "toast",
			kind = "spec",
			title = "Nueva especie",
			text = "Pargo de aleta nocturna del Mar de la Bruma, el grande",
			coins = 12345,
		})
		loaded.client.advance(0)

		local toast = loaded.ns.announcementFrames.toast
		local rung = artOf(loaded, STORM, "toast")
		local amountLeft = rung.amt.x + rung.amt.w - toast.coins.label:GetStringWidth()
		assert(amountLeft < rung.amt.x, "the amount fits its box: the spec needs a wider one")
		-- A name too long for its room scrolls in its clip (ANN-R101), so what shows of it ends where the clip does,
		-- once the name is written out: 4 past its room, which ends 4 before the amount.
		loaded.client.update(7.1)
		local shownRight = rung.text.x - 4 + toast.nameClip:GetWidth()
		assert(shownRight <= amountLeft + 1e-6, "the name runs under the amount")
	end)

	it(
		"hangs a stamp that doesn't fit beside the kicker in a second row under the style's own, its plate's height and"
			.. " 4 lower, ending before the Coins and the name line ending before it (#582, ANN-R80, ANN-R82)",
		function()
			local loaded, M = composedCore()
			equip(loaded, STORM)
			local cast = ("%s-%d-0"):format(PLAYER_GUID, SERVER_TIME)
			-- A kicker 26 letters long, at the fake's 6 a letter, leaves the first row room for one plate of two.
			M:RaiseMoment({
				rung = "toast",
				kind = "spec",
				title = "New Species of the Far Sea",
				text = "Nightfin Snapper of the Misty Sea, the big one",
				cast = cast,
			})
			M:RaiseMoment({ rung = "nod", kind = "spec", title = "Rank up", cast = cast, coins = 5 })
			M:RaiseMoment({ rung = "nod", kind = "spec", title = "New here", cast = cast })
			loaded.client.advance(0)

			local toast = loaded.ns.announcementFrames.toast
			local rung = artOf(loaded, STORM, "toast")
			local spec =
				loaded.ns.ToastStampArt(loaded.ns.ToastStyleOf(STORM), loaded.ns.ToastPage(toast.display.announcement))
			local kickerRight = rung.text.x + toast.title:GetWidth()
			local rows = {}
			for i = 1, 2 do
				local stamp = toast.stamps[i]
				local _, _, _, x, y = toast.pivots[i]:GetPoint()
				rows[i] =
					{ text = stamp.label:GetText(), left = x - stamp.width / 2, right = x + stamp.width / 2, y = -y }
				assert(rows[i].left >= kickerRight + 10, rows[i].text .. " reaches the kicker")
			end
			assert.are.same({ "RANK UP", "NEW HERE" }, { rows[1].text, rows[2].text })
			assert.is_true(near(spec.x + spec.w, rows[1].right) and near(spec.y + spec.h / 2, rows[1].y))
			assert.is_true(near(rows[1].y + spec.h + 4, rows[2].y))
			-- The second row hangs as low as the Coins stand, so it ends 4 before their amount as it draws.
			local amountLeft = math.min(rung.amt.x, rung.amt.x + rung.amt.w - toast.coins.label:GetStringWidth())
			assert.is_true(rows[2].y + spec.h / 2 > math.min(rung.amt.y, rung.coin.y))
			assert.is_true(near(amountLeft - 4, rows[2].right))
			-- The name line's room ends 8 before the second row, and its clip with it (ANN-R101).
			loaded.client.update(7.1)
			assert(toast.nameScroll and toast.nameScroll > 0, "the name scrolls")
			assert.is_true(near(rows[2].left - 8, rung.text.x - 4 + toast.nameClip:GetWidth()))
		end
	)

	-- Pushes a toast in style `styleID` whose kicker leaves the first row room for one plate of two (the second-row
	-- spec's above), as `/pagle dev preview` pushes its sample in the style it names, and returns its frame.
	local function twoStamped(loaded, styleID)
		local function raised(moment)
			moment.kind, moment.module, moment.moduleTitle, moment.moduleOrder, moment.raised =
				"spec", "Pagle", "Pagle", 0, 0
			return moment
		end
		local announcement = loaded.ns.MakeAnnouncement({
			raised({ rung = "toast", title = "New Species of the Far Sea", text = "Nightfin Snapper", coins = 5 }),
			raised({ rung = "nod", title = "Rank up" }),
			raised({ rung = "nod", title = "New here" }),
		}) --[[@as PagleAnnouncement]]
		announcement.style = styleID
		loaded.ns.lanes:Push(announcement)
		loaded.client.advance(0)
		return loaded.ns.announcementFrames.toast
	end

	-- Each stamp's centre's depth down the page.
	local function depths(toast)
		local out = {}
		for i, stamp in ipairs(toast.stamps) do
			if stamp.shown then
				out[#out + 1] = -select(5, toast.pivots[i]:GetPoint())
			end
		end
		return out
	end

	it(
		"hangs the same toast's stamps in two rows in Storm Front, whose art leaves the second row clear (#582)",
		function()
			local loaded = composedCore()

			local rows = depths(twoStamped(loaded, STORM))

			assert.are.equal(2, #rows)
			assert.is_true(rows[2] > rows[1])
		end
	)

	for _, case in ipairs({
		{ "core.toaststyle.spider", "Widow's Web's spider on its thread" },
		{ "ledger.toaststyle.cartographer", "the Cartographer's Folio's compass rose" },
	}) do
		it(
			"keeps the stamps to one row in "
				.. case[1]
				.. ", where "
				.. case[2]
				.. " is drawn over a second row's place (#582, #584, ANN-R82)",
			function()
				local loaded = composedCore()

				local rows = depths(twoStamped(loaded, case[1]))

				assert.are.equal(2, #rows)
				assert.are.equal(rows[1], rows[2])
			end
		)
	end

	it(
		"keeps a ruled toast's stamps to one row in a style whose second row would reach down to the ruler's numbers"
			.. " (#582, ANN-R22, ANN-R82)",
		function()
			local loaded, M = composedCore()
			-- The Deep Lure's plate is 41 tall: a second row would end 73 down, past its ruler's numbers.
			equip(loaded, DEEP)
			local cast = ("%s-%d-0"):format(PLAYER_GUID, SERVER_TIME)
			M:RaiseMoment({
				rung = "toast",
				kind = "spec",
				title = "Size record of the Far Sea",
				text = "Nightfin Snapper",
				cast = cast,
				ruler = { old = 30, new = 34, unit = "length", label = "Decent" },
			})
			M:RaiseMoment({ rung = "nod", kind = "spec", title = "New variety", cast = cast })
			loaded.client.advance(0)

			local toast = loaded.ns.announcementFrames.toast
			local _, _, _, _, first = toast.pivots[1]:GetPoint()
			local _, _, _, _, record = toast.recordPivot:GetPoint()
			assert.are.equal(first, record)
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
			-- Round two's ten, round three's eighteen and the epic five (ANN-R85): every one is walked.
			assert.are.equal(33, #ids)
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

	it(
		"keeps the kicker's top where it is in every composed style, stamps riding or not, the name line short or long,"
			.. " and keeps it clear of the stamp row and of the name line (ANN-R82)",
		function()
			local loaded, M = composedCore({ motion = false })
			local ids = {}
			for id in pairs(loaded.ns.TOAST_STYLE_ART2) do
				ids[#ids + 1] = id
			end
			table.sort(ids)
			-- Round two's ten, round three's eighteen and the epic five (ANN-R85): every one is walked.
			assert.are.equal(33, #ids)
			-- The size a font string is set to, a composed style's ink as a font object, and the client's lines and
			-- letters as they grow with it: a kicker 1.25 a unit and 0.62 wide, a name line 42/31 and 0.4.
			local function sizeOf(fontString)
				local font = fontString.font or (fontString.fontObject and fontString.fontObject.font)
				return font and font[2] or 14
			end
			local function measure(toast)
				toast.title.GetStringHeight = function(self)
					return 1.25 * sizeOf(self)
				end
				toast.title.GetStringWidth = function(self)
					return #(self.text or "") * 0.62 * sizeOf(self)
				end
				for _, line in ipairs({ toast.text, toast.variety }) do
					line.GetStringHeight = function(self)
						return 42 / 31 * sizeOf(self)
					end
					line.GetStringWidth = function(self)
						return #(self.text or "") * 0.4 * sizeOf(self)
					end
				end
				for _, stamp in ipairs(toast.stamps) do
					stamp.label.GetStringWidth = function(self)
						return #(self.text or "") * 0.62 * sizeOf(self)
					end
				end
			end
			local function leftEdge(toast)
				local left = math.huge
				for i, stamp in ipairs(toast.stamps) do
					if stamp.shown then
						left = math.min(left, select(4, toast.pivots[i]:GetPoint()) - stamp:GetWidth() / 2)
					end
				end
				return left
			end
			-- Draws a toast named `text` in the style `id`, with the Nods `stamps` ride on it, and reads where its
			-- kicker and name line are: the kicker's top, foot and right edge, the name line's top, the stamps' left.
			local function read(id, text, stamps)
				local cast = ("%s-%d-0"):format(PLAYER_GUID, SERVER_TIME)
				M:RaiseMoment({ rung = "toast", kind = "spec", title = "New Species", text = text, cast = cast })
				for _, stamp in ipairs(stamps) do
					M:RaiseMoment({ rung = "nod", kind = "spec", title = stamp, stamp = stamp, cast = cast })
				end
				loaded.client.advance(0)
				local toast = loaded.ns.announcementFrames.toast
				toast.display.announcement.style = id
				measure(toast)
				loaded.ns.DrawAnnouncement(toast, toast.display)
				local top = -select(5, toast.title:GetPoint())
				local where = {
					top = top,
					foot = top + toast.title:GetStringHeight(),
					right = select(4, toast.title:GetPoint()) + toast.title:GetWidth(),
					nameTop = top + toast.title:GetStringHeight() - select(5, toast.text:GetPoint()),
					stamps = leftEdge(toast),
					size = sizeOf(toast.text),
				}
				loaded.client.advance(10)
				return where
			end
			for _, id in ipairs(ids) do
				local alone = read(id, "Pike", {})
				local stamped =
					read(id, "Raw Bristle Whisker Catfish of the Sunken Reach", { "New variety", "Rank up" })
				assert(
					alone.top == stamped.top,
					("%s: the kicker is at %s, then %s"):format(id, alone.top, stamped.top)
				)
				assert(stamped.size < alone.size, id .. ": the name line didn't step down")
				assert(
					stamped.stamps >= stamped.right,
					("%s: stamps at %s, kicker to %s"):format(id, stamped.stamps, stamped.right)
				)
				assert(stamped.foot <= stamped.nameTop, id .. ": the kicker reaches the name line")
				assert(alone.foot <= alone.nameTop, id .. ": the kicker reaches the name line")
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

	-- A size record and a first catch of a variety of `rarity` (Rare if none) on one Cast, as the Ledger raises them
	-- (LED-R97), and the toast Core shows for them.
	local function raiseRecord(loaded, M, rarity)
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
			variety = { name = "Coral", rarity = rarity or "rare" },
		})
		loaded.client.advance(0)
		return loaded.ns.announcementFrames.toast
	end

	it(
		"shows the art in the medallion, tints its front and back in the rarity's colour, writes the gem and name, the"
			.. " name light on the Deep Lure's dark page (#582, 1.2.3), and inks the stamp's plate, its word cream on it"
			.. " (#582), the band beside the ruler (VAR-R26, ANN-R22)",
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
			-- The Deep Lure writes light on its dark page: the name is Rare's blue lifted toward white, not its dark ink.
			local name = toast.variety.textColor
			assert.are.same(
				{ true, true, rgb(rare.color) },
				{ name[3] > name[2] and name[2] > name[1], name[1] > rare.color[1], rgb(toast.gem.fill.color) }
			)
			local stamp = toast.stamps[1]
			assert.are.same(
				{ "NEW VARIETY", rgb(loaded.ns.ANNOUNCE_COLORS.cream) },
				{ stamp.label:GetText(), rgb(stamp.label.textColor) }
			)
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

	-- Rec. 709 luminance over an ink's values, and WCAG's contrast ratio of two inks, each { r, g, b } from 0 to 1.
	local function luminance(color)
		return 0.2126 * color[1] + 0.7152 * color[2] + 0.0722 * color[3]
	end
	local function contrast(a, b)
		local function relative(color)
			local linear = {}
			for i = 1, 3 do
				local c = color[i]
				linear[i] = c <= 0.03928 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
			end
			return luminance(linear)
		end
		local la, lb = relative(a), relative(b)
		return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
	end

	it(
		"keeps the New variety stamp's word readable on its tinted plate, in every style and every rarity: light on a"
			.. " composed plate tinted dark, and on a round one style's outlined border as the style writes on its page"
			.. " (#582, VAR-R28)",
		function()
			local loaded, M = composedCore({ motion = false })
			local ids = {}
			for id in pairs(loaded.ns.TOAST_STYLES) do
				ids[#ids + 1] = id
			end
			table.sort(ids)
			for _, rarity in ipairs(loaded.ns.VARIETY_RARITIES) do
				local toast = raiseRecord(loaded, M, rarity.key)
				local announcement = toast.display.announcement
				for _, id in ipairs(ids) do
					announcement.style = id
					loaded.ns.DrawAnnouncement(toast, toast.display)
					local style = loaded.ns.ToastStyleOf(id)
					local label = ("%s, %s"):format(id, rarity.key)
					local stamp
					for _, shown in ipairs(toast.stamps) do
						if shown.shown and shown.label:GetText():upper() == "NEW VARIETY" then
							stamp = shown
						end
					end
					assert(stamp, label .. ": no New variety stamp")
					local word = rgb(stamp.label.textColor)
					if style.layered then
						-- The plate is the sprite greyed, then tinted in the ink: never lighter than the ink itself.
						for _, slice in ipairs(stamp.plate) do
							assert.are.same(
								{ true, rgb(rarity.ink) },
								{ slice.desaturated == true, rgb(slice.vertexColor) },
								label
							)
						end
						assert(
							contrast(word, rarity.ink) >= 4.5,
							("%s: the word contrasts %.2f with its plate"):format(label, contrast(word, rarity.ink))
						)
					else
						-- The round one stamp is an outlined border: the word stands on the page, so it is as light or
						-- as dark as the style's own words there, and in the rarity's ink where the page is light.
						local border = stamp.border.left
						assert.are.same(
							{ true, rgb(rarity.ink) },
							{ border.desaturated == true, rgb(border.vertexColor) },
							label
						)
						local name = loaded.ns.ANNOUNCE_COLORS[style.name]
						if luminance(name) <= 0.45 then
							assert.are.same(rgb(rarity.ink), word, label)
						else
							assert(
								contrast(word, rarity.ink) >= 4.5 and contrast(word, name) < 2,
								label .. ": the word is not light on a dark page"
							)
						end
					end
				end
				loaded.client.advance(10)
			end
		end
	)

	-- The lightest page behind the name line among the styles that write light on theirs (Arcane's ruled page, WCAG
	-- relative luminance 0.083), measured by compositing each style's toast, ruled and gilt pages from their textures
	-- where the variety's name stands (#582, 1.2.3). Four styles that write light have a mid-tone page there, lighter
	-- than this: the Blueprint, the Hall, the Shroud and the Gala, on which their own name ink reads 2.2–7.6:1.
	local DARK_PAGE_LUMINANCE = 0.083

	-- An ink's WCAG relative luminance, and its contrast ratio with a page of relative luminance `page`.
	local function relative(color)
		local linear = {}
		for i = 1, 3 do
			local c = color[i]
			linear[i] = c <= 0.03928 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
		end
		return luminance(linear)
	end
	local function onPage(color, page)
		return (relative(color) + 0.05) / (page + 0.05)
	end

	-- Whether `color` is `base` lifted toward white, every channel by one share of what it lacks, so its hue is kept.
	local function liftedFrom(color, base)
		local share
		for i = 1, 3 do
			if base[i] < 1 then
				local this = (color[i] - base[i]) / (1 - base[i])
				if this < -1e-3 or (share and math.abs(this - share) > 0.01) then
					return false
				end
				share = share or this
			elseif math.abs(color[i] - 1) > 1e-3 then
				return false
			end
		end
		return true
	end

	-- The variety's name a frame shows once the style `id` is drawn on it, and the style's own name ink on that page or
	-- Nod.
	local function drawnIn(loaded, frame, id)
		local announcement = frame.display.announcement
		announcement.style = id
		loaded.ns.DrawAnnouncement(frame, frame.display)
		local style = loaded.ns.ToastStyleOf(id)
		local page = frame.display.form == "toast" and loaded.ns.ToastPage(announcement) or nil
		return rgb(frame.variety.textColor), loaded.ns.ANNOUNCE_COLORS[loaded.ns.ToastInks(style, page).name]
	end

	it(
		"keeps the variety's name on the name line readable in every style and every rarity, on the toast, ruled and"
			.. " gilt pages and the Nod: in the rarity's ink where the style writes dark, its colour lifted toward white"
			.. " where it writes light (#582, 1.2.3, VAR-R28)",
		function()
			local loaded, M = composedCore({ motion = false })
			local ids = {}
			for id in pairs(loaded.ns.TOAST_STYLES) do
				ids[#ids + 1] = id
			end
			table.sort(ids)
			-- Each case raises a toast or Nod naming a variety of the rarity `key`, and returns its frame and its page.
			local cases = {}
			function cases.catch(key)
				loaded.ns.moments:RaiseCatchToast({
					rung = "toast.low",
					kind = "catch",
					title = "Decent · 34.2 cm",
					text = "Firefin Snapper",
					nodLine = "Firefin Snapper · Coral · Decent · 34.2 cm",
					icon = 6359,
					cast = CAST,
					variety = {
						name = "Coral",
						rarity = key,
						before = "Firefin Snapper ·",
						after = "· Decent · 34.2 cm",
					},
				})
				loaded.client.advance(0)
				return loaded.ns.announcementFrames.toast, "toast"
			end
			function cases.ruled(key)
				return raiseRecord(loaded, M, key), "toast-ruled"
			end
			function cases.gilt(key)
				M:RaiseMoment({
					rung = "toast.high",
					kind = "spec",
					title = "Zone Master",
					text = "Raw Bristle Whisker Catfish",
					icon = 6291,
					cast = CAST,
				})
				M:RaiseMoment({
					rung = "toast.low",
					kind = "newVariety",
					title = "New variety",
					text = "Coral",
					icon = 6291,
					cast = CAST,
					art = ART,
					variety = { name = "Coral", rarity = key },
				})
				loaded.client.advance(0)
				return loaded.ns.announcementFrames.toast, "high"
			end
			-- The catch toast with the Interruption budget spent, stepped down to a Nod (ANN-R31).
			function cases.nod(key)
				local budget = loaded.ns.db.profile.announcements.budget
				budget.count = 0
				cases.catch(key)
				budget.count = 40
				return loaded.ns.announcementFrames.nod, nil
			end
			local light = 0
			for _, case in ipairs({ "catch", "ruled", "gilt", "nod" }) do
				for _, rarity in ipairs(loaded.ns.VARIETY_RARITIES) do
					local frame, page = cases[case](rarity.key)
					local label = ("%s, %s"):format(case, rarity.key)
					assert(frame.variety.shown, label .. ": no variety's name")
					if page then
						assert.are.equal(page, loaded.ns.ToastPage(frame.display.announcement).page, label)
					else
						assert.are.equal("nod", frame.display.form, label)
					end
					for _, id in ipairs(ids) do
						label = ("%s, %s, %s"):format(case, id, rarity.key)
						local name, own = drawnIn(loaded, frame, id)
						if luminance(own) <= 0.45 then
							assert.are.same(rgb(rarity.ink), name, label)
						else
							light = light + 1
							assert(
								liftedFrom(name, rarity.color),
								("%s: %.3f,%.3f,%.3f is not the rarity's colour lifted toward white"):format(
									label,
									name[1],
									name[2],
									name[3]
								)
							)
							assert(
								onPage(name, DARK_PAGE_LUMINANCE) >= 4.5,
								("%s: the name contrasts %.2f with a dark page"):format(
									label,
									onPage(name, DARK_PAGE_LUMINANCE)
								)
							)
							-- The rarity still shows: a Rare or Epic name is no near-white.
							if rarity.key == "rare" or rarity.key == "epic" then
								assert(
									math.max(unpack(name)) - math.min(unpack(name)) >= 0.15,
									label .. ": the rarity's colour is lost"
								)
							end
						end
					end
					loaded.client.advance(10)
				end
			end
			-- Twenty styles write light, on every page and the Nod, in each rarity.
			assert.are.equal(20 * 4 * 4, light)
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
			.. " plate in the rarity's ink and its word cream on it (#582), within the page",
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
					{ key == "rare" and "RARE VARIETY" or "NEW VARIETY", rgb(loaded.ns.ANNOUNCE_COLORS.cream), false },
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

-- The epic five, earned in Core's toast style slot: Hunts' three and the Ledger's two (ANN-R85).
local EPIC_FIVE = {
	{ "Ledger", "ledger.toaststyle.cartographer" },
	{ "Hunts", "hunts.toaststyle.nightfin" },
	{ "Hunts", "hunts.toaststyle.trench" },
	{ "Ledger", "ledger.toaststyle.gala" },
	{ "Hunts", "hunts.toaststyle.study" },
}
local FOLIO, GALA = "ledger.toaststyle.cartographer", "ledger.toaststyle.gala"

-- Core logged in on Forever with the Ledger and Hunts registered and the epic five earned in Core's slot. `stage` is the
-- Folio's stageCount's count: the table's `value`, nil for none known.
local function epicCore(stage)
	local loaded = loadCore(history(2), {})
	loaded.env.PagleDB.global.onboarding.notesOn = false
	loaded.ns.db.profile.announcements.motion = false
	local modules = {
		Ledger = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 }),
		Hunts = loaded.env.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 }),
	}
	for _, entry in ipairs(EPIC_FIVE) do
		modules[entry[1]]:RegisterGood({
			id = entry[2],
			slot = "core.toaststyle",
			name = entry[2],
			isEarned = function()
				return true
			end,
			earnedText = "Earned",
			stageCount = entry[2] == FOLIO and function()
				return stage and stage.value
			end or nil,
		})
	end
	enterWorld(loaded, 3)
	loaded.client.runTimers()
	return loaded, modules.Ledger
end

describe("the epic five on the client (ANN-R85)", function()
	it(
		"each draw a toast, a toast.high and a Nod from their own rungs with every word within the page (ANN-R82, ANN-R85)",
		function()
			local loaded, M = epicCore()
			for _, entry in ipairs(EPIC_FIVE) do
				local id = entry[2]
				equip(loaded, id)
				for _, rungName in ipairs({ "toast", "toast.high" }) do
					raiseStamped(loaded, M, rungName)
					local toast = loaded.ns.announcementFrames.toast
					local page = loaded.ns.ToastPage(toast.display.announcement)
					local rung, atlas = artOf(loaded, id, page.high and "high" or "toast")
					assert.are.same({ page.w, page.h }, { toast.width, toast.height })
					assert.are.same({ rung.w, rung.h }, { page.w, page.h })
					assert(#toast.toastLayers.active > 0, id)
					for _, slot in ipairs(toast.toastLayers.active) do
						assert.are.equal(atlas.file, slot.texture.texture, id)
					end
					assert.are.same({}, bounds.overflows(toast), id .. " on " .. rungName)
					loaded.client.advance(10)
				end
				-- A Nod, from the Nod rung, its body three-sliced to the line.
				loaded.ns.moments:RaiseCatchToast({ rung = "nod", kind = "spec", title = "Rank up", text = "Lure" })
				loaded.client.advance(0)
				local nod = loaded.ns.announcementFrames.nod
				if nod and nod.toastLayers then
					assert.are.same({}, bounds.overflows(nod), id)
				end
				loaded.client.advance(10)
			end
		end
	)

	describe("the Extravaganza Gala's burst of confetti", function()
		local CAST = ("%s-%d-0"):format(PLAYER_GUID, SERVER_TIME)

		-- Whether toast.high's page draws the burst layer (gala-pop), for a headline with a variety of `rarity` riding on
		-- it, or none (nil).
		local function bursts(loaded, M, rarity, rung)
			M:RaiseMoment({
				rung = rung or "toast.high",
				kind = "spec",
				title = "New Species",
				text = "Raw Bristle Whisker Catfish",
				icon = 6291,
				cast = CAST,
			})
			if rarity then
				M:RaiseMoment({
					rung = "toast.low",
					kind = "newVariety",
					order = 120,
					title = "New variety",
					text = "Coral",
					stamp = "New variety",
					icon = 6291,
					cast = CAST,
					variety = { name = "Coral", rarity = rarity },
				})
			end
			loaded.client.advance(0)
			local toast = loaded.ns.announcementFrames.toast
			local found = false
			for _, slot in ipairs(toast.toastLayers.active) do
				found = found or (slot.layer.motion ~= nil and slot.layer.motion.keyframes == "gala-pop")
			end
			local isHigh = loaded.ns.ToastPage(toast.display.announcement).high == true
			loaded.client.advance(10)
			return found, isHigh
		end

		it(
			"plays on toast.high and on the toast page with a Rare or Epic variety, and with none else (ANN-R85, VAR-R26)",
			function()
				local loaded, M = epicCore()
				equip(loaded, GALA)

				assert.are.same({ true, true }, { bursts(loaded, M, "rare") })
				assert.are.same({ true, true }, { bursts(loaded, M, "epic") })
				assert.are.same({ false, true }, { bursts(loaded, M, "common") })
				assert.are.same({ false, true }, { bursts(loaded, M, "uncommon") })
				assert.are.same({ false, true }, { bursts(loaded, M, nil) })
				-- The toast page has it too, as a Rare variety's own toast is drawn on it (VAR-R25).
				assert.are.same({ true, false }, { bursts(loaded, M, "rare", "toast") })
				assert.are.same({ true, false }, { bursts(loaded, M, "epic", "toast") })
				assert.are.same({ false, false }, { bursts(loaded, M, "common", "toast") })
				assert.are.same({ false, false }, { bursts(loaded, M, nil, "toast") })
			end
		)

		it("is the kit's toast.high burst on the toast rung too: its sprite and beat, centred on the rung", function()
			local loaded = epicCore()
			local style = loaded.ns.ToastStyleOf(GALA)
			local function burstOf(rung)
				for _, layer in ipairs(style.art.rungs[rung].layers) do
					if layer.motion and layer.motion.keyframes == "gala-pop" then
						return layer, style.art.rungs[rung]
					end
				end
			end
			local high, highRung = burstOf("high")
			local toast, toastRung = burstOf("toast")

			assert.are.same({ high.sprite, high.w, high.h, high.y }, { toast.sprite, toast.w, toast.h, toast.y })
			assert.is_false(toast.motion.loop)
			assert.are.same(high.motion.alpha, toast.motion.alpha)
			assert.are.same(high.motion.transform, toast.motion.transform)
			-- Centred on its rung as the kit's is on its: the same distance from the middle.
			assert.is_true(near(high.x + high.w / 2 - highRung.w / 2, toast.x + toast.w / 2 - toastRung.w / 2))
			assert.is_true(near(high.motion.origin.x - highRung.w / 2, toast.motion.origin.x - toastRung.w / 2))
			assert.are_not.equal("front", toast.name)
		end)

		-- Raises an Epic variety's moment as the Ledger does (VAR-R25): a banner "Epic variety". Returns the toast and the
		-- banner on screen, nil for one that isn't.
		local function epic(loaded, M)
			M:RaiseMoment({
				rung = "banner",
				kind = "epicVariety",
				order = 97,
				title = "Epic variety",
				text = "Phoenix-fin",
				icon = 6291,
				cast = CAST,
				variety = { name = "Phoenix-fin", rarity = "epic" },
			})
			loaded.client.advance(0)
			local frames = loaded.ns.announcementFrames
			local toast, banner = frames.toast, frames.banner
			return toast and toast.shown and toast or nil, banner and banner.shown and banner or nil
		end

		it(
			"shows an Epic variety as a toast.high with the burst while the Gala is equipped, not a banner (ANN-R85, VAR-R25)",
			function()
				local loaded, M = epicCore()
				equip(loaded, GALA)

				local toast, banner = epic(loaded, M)

				assert.is_nil(banner)
				assert.is_not_nil(toast)
				local announcement = (toast --[[@as table]]).display.announcement
				assert.are.same({ "toast.high", true }, { announcement.rung, loaded.ns.ToastPage(announcement).high })
				local found = false
				for _, slot in
					ipairs((toast --[[@as table]]).toastLayers.active)
				do
					found = found or (slot.layer.motion ~= nil and slot.layer.motion.keyframes == "gala-pop")
				end
				assert.is_true(found)
			end
		)

		it(
			"gives that Epic toast an EPIC VARIETY stamp, first in the row, its plate in the epic ink and its word cream on it (#582), as a Rare variety's toast has RARE VARIETY, with the kicker clear of it (ANN-R85, VAR-R28)",
			function()
				local loaded, M = epicCore()
				equip(loaded, GALA)
				-- Another moment on the Cast rides as a stamp behind it.
				M:RaiseMoment({
					rung = "toast",
					kind = "spec",
					title = "New Species",
					stamp = "New!",
					text = "Raw Bristle Whisker Catfish",
					icon = 6291,
					cast = CAST,
				})
				local toast = epic(loaded, M) --[[@as table]]

				local stamps = {}
				for i, stamp in ipairs(toast.stamps) do
					if stamp.shown then
						stamps[#stamps + 1] = { stamp.label:GetText(), i }
					end
				end
				assert.are.same({ "EPIC VARIETY", "NEW!" }, { stamps[1][1], stamps[2][1] })
				local epicInk = loaded.ns.VARIETY_RARITIES[4].ink
				local cream = loaded.ns.ANNOUNCE_COLORS.cream
				local epicStamp = toast.stamps[stamps[1][2]]
				assert.are.same(
					{ { epicInk[1], epicInk[2], epicInk[3] }, { cream[1], cream[2], cream[3] } },
					{ { unpack(epicStamp.plate[2].vertexColor, 1, 3) }, { unpack(epicStamp.label.textColor, 1, 3) } }
				)
				-- The kicker, "Epic variety", ends before the leftmost stamp starts.
				local left = math.huge
				for i, stamp in ipairs(toast.stamps) do
					if stamp.shown then
						left = math.min(left, select(4, toast.pivots[i]:GetPoint()) - stamp:GetWidth() / 2)
					end
				end
				local _, _, _, x = toast.title:GetPoint()
				assert.are.equal("EPIC VARIETY", toast.stamps[stamps[1][2]].label:GetText())
				assert.is_true(x + toast.title:GetStringWidth() <= left)
				loaded.client.advance(20)

				-- A Rare variety's own toast already has its stamp, from its title (VAR-R28).
				M:RaiseMoment({
					rung = "toast",
					kind = "rareVariety",
					ownStamp = true,
					title = "Rare variety",
					text = "Coral",
					icon = 6291,
					cast = CAST,
					variety = { name = "Coral", rarity = "rare" },
				})
				loaded.client.advance(0)
				local rare = loaded.ns.announcementFrames.toast
				assert.are.equal("RARE VARIETY", rare.stamps[1].label:GetText())
			end
		)

		it("keeps the banner for an Epic variety in every other style (VAR-R25)", function()
			local loaded, M = epicCore()
			for _, entry in ipairs(EPIC_FIVE) do
				if entry[2] ~= GALA then
					equip(loaded, entry[2])
					local toast, banner = epic(loaded, M)
					assert(toast == nil, entry[2])
					assert(banner ~= nil, entry[2])
					loaded.client.advance(20)
				end
			end
		end)

		it("is left off every other epic style, whatever the variety", function()
			local loaded, M = epicCore()
			for _, entry in ipairs(EPIC_FIVE) do
				if entry[2] ~= GALA then
					equip(loaded, entry[2])
					assert.are.same({ false, true }, { bursts(loaded, M, "epic") }, entry[2])
				end
			end
		end)

		it("goes off once as the toast lands with Animations on, and is unseen before and after (ANN-R85)", function()
			local loaded, M = epicCore()
			loaded.ns.db.profile.announcements.motion = true
			equip(loaded, GALA)
			M:RaiseMoment({
				rung = "toast.high",
				kind = "spec",
				title = "New Species",
				text = "Pike",
				icon = 6291,
				cast = CAST,
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
				variety = { name = "Coral", rarity = "rare" },
			})
			loaded.client.advance(0)
			local toast = loaded.ns.announcementFrames.toast
			local burst = slotOf(toast, "front").texture
			assert.are.equal(0, burst.alpha) -- it only flashes: unseen before it lands

			-- Landing at 0.98 s and a beat (0.1 s) on, it blooms (alpha 1 by 12% of its 1.6 s) and fades out.
			assert.is_not_nil(toast.toastLayers.playing)
			loaded.client.nextFrame(0.5)
			assert.are.equal(0, burst.alpha)
			loaded.client.nextFrame(0.98 + 0.1 + 0.3 - 0.5) -- landed, a beat on, and past its bloom (12% of 1.6 s)
			assert.is_true(burst.shown)
			assert.is_true(burst.alpha > 0.9)
			loaded.client.nextFrame(2) -- its 1.6 s over
			assert.are.equal(0, burst.alpha)
			-- Once: it doesn't come round again while the toast stays up.
			loaded.client.nextFrame(1.5)
			assert.are.equal(0, burst.alpha)
		end)
	end)

	describe("the Cartographer's Folio's stages", function()
		-- The Folio's deco on a `rung` toast, with the Ledger's count `value`: the layer drawn and its slot.
		local function decoSlot(loaded, M, stage, value, rung, style)
			stage.value = value
			raiseStamped(loaded, M, rung)
			local toast = loaded.ns.announcementFrames.toast
			if style then
				-- Not registered, so not equippable: drawn in the style as a sample of it is.
				toast.display.announcement.style = style
				loaded.ns.DrawAnnouncement(toast, toast.display)
			end
			local slot = slotOf(toast, "deco")
			local atlas = loaded.ns.ATLASES[loaded.ns.ToastStyleOf(FOLIO).atlas]
			assert.are.same(coordsOf(atlas, slot.layer.sprite), slot.texture.texCoord)
			local sprite, width, height = slot.layer.sprite, slot.texture.width, slot.texture.height
			loaded.client.advance(10)
			return sprite, width, height
		end

		it("draw the stage the Ledger's count of zones at Master gives, on toast and toast.high (ANN-R85)", function()
			local stage = {}
			local loaded, M = epicCore(stage)
			equip(loaded, FOLIO)

			for value, suffix in pairs({
				[5] = "-st1",
				[14] = "-st1",
				[15] = "-st2",
				[30] = "-st3",
				[45] = "",
				[54] = "-st5",
			}) do
				assert.are.equal("toast-deco" .. suffix, decoSlot(loaded, M, stage, value), value)
				assert.are.equal("high-deco" .. suffix, decoSlot(loaded, M, stage, value, "toast.high"), value)
			end
		end)

		it("draw the first stage below the first count, and while no count is known at all (ANN-R85)", function()
			local stage = {}
			local loaded, M = epicCore(stage)
			equip(loaded, FOLIO)

			assert.are.equal("toast-deco-st1", decoSlot(loaded, M, stage, 2))
			assert.are.equal("toast-deco-st1", decoSlot(loaded, M, stage, nil))
			assert.are.equal("high-deco-st1", decoSlot(loaded, M, stage, nil, "toast.high"))
		end)

		it(
			"draw the first stage with the Ledger off: the good isn't registered, so there is no count to ask",
			function()
				local loaded = loadCore(history(2), {})
				loaded.env.PagleDB.global.onboarding.notesOn = false
				loaded.ns.db.profile.announcements.motion = false
				local M = loaded.env.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
				enterWorld(loaded, 3)
				loaded.client.runTimers()

				assert.is_nil(loaded.ns.goods:StageCount(FOLIO))
				assert.are.equal("toast-deco-st1", decoSlot(loaded, M, {}, nil, nil, FOLIO))
			end
		)

		it("draw each stage at its own box, stage 5's a little bigger than the others' (ANN-R85)", function()
			local stage = {}
			local loaded, M = epicCore(stage)
			equip(loaded, FOLIO)
			local art = loaded.ns.ToastStyleOf(FOLIO).art.stages

			local _, w1, h1 = decoSlot(loaded, M, stage, 5)
			local _, w5, h5 = decoSlot(loaded, M, stage, 54)
			assert.are.same({ art[1].toast.w, art[1].toast.h }, { w1, h1 })
			assert.are.same({ art[5].toast.w, art[5].toast.h }, { w5, h5 })
			assert.is_true(w5 > w1 and h5 > h1)
		end)

		it("draw as `/pagle dev stage` says, whatever the Ledger counts, until it is off (ANN-R85)", function()
			local stage = { value = 54 }
			local loaded, M = epicCore(stage)
			equip(loaded, FOLIO)

			loaded.ns.devStageCount = 16
			assert.are.equal("toast-deco-st2", decoSlot(loaded, M, stage, 54))
			loaded.ns.devStageCount = nil
			assert.are.equal("toast-deco-st5", decoSlot(loaded, M, stage, 54))
		end)

		it("take the count from the good's stageCount through Core's registry, and a Nod has no stage", function()
			local stage = { value = 31 }
			local loaded, M = epicCore(stage)
			equip(loaded, FOLIO)

			assert.are.equal(31, loaded.ns.goods:StageCount(FOLIO))
			assert.are.equal("toast-deco-st3", decoSlot(loaded, M, stage, 31))
			loaded.ns.moments:RaiseCatchToast({ rung = "nod", kind = "spec", title = "Rank up", text = "Lure" })
			loaded.client.advance(0)
			local nod = loaded.ns.announcementFrames.nod
			for _, slot in ipairs(nod.toastLayers.active) do
				assert(slot.layer.sprite:find("^nod%-"), slot.layer.sprite)
			end
		end)
	end)
end)

describe("a composed style's long name line on the client (ANN-R101)", function()
	it("scrolls in its clip as the Torn Page's does, its room the line's before the Coins (ANN-R101)", function()
		local loaded, M = composedCore({})
		equip(loaded, STORM)
		local cast = ("%s-%d-0"):format(PLAYER_GUID, SERVER_TIME)
		local text = ("x"):rep(80)

		M:RaiseMoment({ rung = "toast", kind = "spec", title = "New Species", text = text, cast = cast })
		M:RaiseMoment({ rung = "nod", kind = "spec", title = "Rank up", cast = cast, coins = 5 })
		loaded.client.advance(0)
		local toast = loaded.ns.announcementFrames.toast

		-- The fake measures 6 a byte: 80 bytes are 480, wider than any rung's text box.
		assert(toast.composed, "drawn composed")
		assert.are.same({ text, 80 * 6 }, { toast.text:GetText(), toast.text:GetWidth() })
		local written, hold = 0.26 * 7, loaded.ns.MARQUEE_HOLD
		loaded.client.update(written + hold + 1)
		local room = toast.nameClip:GetWidth() - 4
		local _, _, _, x = toast.text:GetPoint(1)
		-- A second into its glide, the line is a second's speed along, and the clip's left edge hasn't moved.
		assert.are.equal(80 * 6, room + toast.nameScroll)
		assert(math.abs(x + loaded.ns.MARQUEE_SPEED) < 1e-6, "the line is at " .. x)
		assert(math.abs(x + toast.nameClip.points[1][4] + 4) < 1e-6, "the clip moved")
	end)
end)
