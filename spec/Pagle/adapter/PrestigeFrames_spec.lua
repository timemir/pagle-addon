-- The Prestige frames and Prestige emblems on the client, through the real TOC and Pagle's API (ledger.md › LED-R154,
-- LED-R152; announcements.md › Contracts): each rank's frame built from its layers (Core's layered art, the composed
-- toast styles' renderer), drawn at a scale with its label, its well and its crest's pin; its motion played and
-- stopped, and still with Animations off; and the emblems at their sizes. Sprites, places and texture coordinates are
-- asserted, not pixels.

local NUMERALS = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }
local KEYS = {
	[0] = "none",
	"jetty",
	"castoff",
	"lighthouse",
	"opensea",
	"storm",
	"dive",
	"coral",
	"midnight",
	"leviathan",
	"starward",
	"constellation",
}

-- Core logged in on Forever. With `motion` false, Animations are off (SET-R30).
local function core(options)
	local loaded = loadCore(history(1), {})
	if options and options.motion == false then
		loaded.ns.db.profile.announcements.motion = false
	end
	enterWorld(loaded, 3)
	loaded.client.runTimers()
	return loaded
end

-- A Prestige frame on a frame of the screen, through Pagle's API.
local function newFrame(loaded)
	local parent = loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent)
	return loaded.env.Pagle.NewPrestigeFrame(parent), parent
end

local function near(a, b)
	return math.abs(a - b) < 1e-6
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
	for _, slot in ipairs(frame.art.active) do
		if slot.layer.name == name then
			return slot
		end
	end
	return nil
end

describe("a Prestige frame", function()
	it(
		"builds each rank's frame from its own atlas: No Prestige's, I to X, and the Master's from XI on, each layer"
			.. " behind or over the well, in the kit's order (LED-R154)",
		function()
			local loaded = core()
			local frame = newFrame(loaded)
			for _, rank in ipairs({ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 25 }) do
				frame:SetRank(rank, 1)
				local art = loaded.ns.PrestigeFrameArt(rank)
				local atlas = loaded.ns.ATLASES[art.atlas]
				assert.are.equal(KEYS[math.min(rank, 11)], frame.key)
				assert.are.equal(KEYS[math.min(rank, 11)], loaded.env.Pagle.GetPrestigeFrame(rank).key)
				assert.are.equal(#art.layers, #frame.art.active)
				for i, layer in ipairs(art.layers) do
					local texture = frame.art.active[i].texture
					assert.are.equal(atlas.file, texture.texture)
					assert.are.same(coordsOf(atlas, layer.sprite), texture.texCoord)
					-- behind the likeness on BORDER, the frame and what crosses it on ARTWORK over the well's -7
					local drawLayer, sublevel = texture:GetDrawLayer()
					assert.are.equal(layer.host == "back" and "BORDER" or "ARTWORK", drawLayer)
					if layer.host == "front" then
						assert.is_true(sublevel > -7)
					end
					local _, anchor, relative, x, y = texture:GetPoint()
					assert.are.same({ frame, "TOPLEFT" }, { anchor, relative })
					assert.is_true(near(layer.x + layer.w / 2, x) and near(-(layer.y + layer.h / 2), y), layer.name)
				end
			end
			assert.matches("FrameStorm$", loaded.ns.ATLASES[loaded.ns.PrestigeFrameArt(5).atlas].file)
		end
	)

	it(
		"draws at a scale of its 260 × 280 box: its sprites, its well and the crest's pin with it (LED-R146, LED-R154)",
		function()
			local loaded = core()
			local frame = newFrame(loaded)
			frame:SetRank(3, 0.65)
			local well = loaded.ns.PRESTIGE_WELL

			assert.are.same({ 169, 182 }, { frame.width, frame.height })
			local body = slotOf(frame, "body")
			assert.are.same({ body.layer.w * 0.65, body.layer.h * 0.65 }, { body.texture.width, body.texture.height })
			-- The likeness 73 across, centred on the well.
			local likeness = frame:GetWell()
			assert.is_true(near(2 * well.r * 0.65, likeness.width))
			assert.are.same({ "CENTER", frame, "TOPLEFT", well.cx * 0.65, -well.cy * 0.65 }, { likeness:GetPoint() })
			-- The crest's shield 50 units wide, at the frame's pin.
			local x, y, w = frame:GetPin()
			local pin = loaded.ns.PrestigeFrameArt(3).pin
			assert.are.same({ pin.x * 0.65, pin.y * 0.65 }, { x, y })
			assert.is_true(math.abs(w - 50) < 0.01)
		end
	)

	it(
		"labels its plaque with the rank's numeral, or Master with a star stamp for each Master Prestige, at most five"
			.. " and then +n, in the kit's ink; No Prestige's has none (LED-R154)",
		function()
			local loaded = core()
			local frame = newFrame(loaded)
			local function label(rank)
				frame:SetRank(rank, 0.65)
				local stars = 0
				for _, star in ipairs(frame.stars) do
					stars = stars + (star.shown and 1 or 0)
				end
				return {
					frame.label.shown and frame.label:GetText() or false,
					stars,
					frame.more.shown and frame.more:GetText() or false,
				}
			end

			for rank = 1, 10 do
				assert.are.same({ NUMERALS[rank], 0, false }, label(rank))
			end
			assert.are.same({ false, 0, false }, label(0))
			assert.are.same({ "MASTER", 1, false }, label(11))
			assert.are.same({ "MASTER", 5, false }, label(15))
			assert.are.same({ "MASTER", 5, "+3" }, label(18))
			-- The kit's size at the frame's scale, along the plaque's line.
			frame:SetRank(7, 0.65)
			local ink = loaded.ns.PrestigeFrameArt(7).label.ink
			assert.is_true(near(ink.size * 0.65, frame.label.fontObject.font[2]))
			assert.is_true(near(-loaded.ns.PrestigeFrameArt(7).label.top * 0.65, select(5, frame.label:GetPoint())))
		end
	)

	it(
		"moves from V up while asked to, each layer on its own keyframes, and stops when it hides or is told; I to IV"
			.. " stand still (LED-R154)",
		function()
			local loaded = core()
			local frame, parent = newFrame(loaded)
			for rank = 0, 4 do
				assert.is_false(loaded.env.Pagle.GetPrestigeFrame(rank).moving)
			end
			for rank = 5, 12 do
				assert.is_true(loaded.env.Pagle.GetPrestigeFrame(rank).moving)
			end

			frame:SetRank(6, 1)
			frame:Play()
			local bubble = slotOf(frame, "fx1")
			assert.are.equal(frame, frame.art.playing)
			loaded.client.nextFrame(0.48) -- 0.15 of its 3.2 s rise: in full view, 3.6 units down from its start
			local _, _, _, _, y = bubble.texture:GetPoint()
			local layer = bubble.layer
			assert.is_true(bubble.texture.shown)
			assert.is_true(near(1, bubble.texture.alpha))
			assert.is_true(y > -(layer.y + layer.h / 2 + 18) and y < -(layer.y + layer.h / 2 - 16))

			-- Hidden (its page closed), it settles and stops; shown again and asked, it starts afresh.
			parent:Hide()
			loaded.client.nextFrame(0.1)
			assert.is_nil(frame.art.playing)
			parent:Show()
			frame:Play()
			assert.are.equal(frame, frame.art.playing)
			frame:Stop()
			assert.is_nil(frame.art.playing)
		end
	)

	it(
		"stands still with Animations off: unmoved, and what only flashes or rises unseen (LED-R154, SET-R30)",
		function()
			local loaded = core({ motion = false })
			local frame = newFrame(loaded)
			frame:SetRank(5, 1)
			frame:Play()

			assert.is_nil(frame.art.playing)
			local look = {}
			for _, slot in ipairs(frame.art.active) do
				look[slot.layer.name] = { slot.texture.shown, slot.texture.rotation, slot.texture.alpha }
			end
			assert.are.same({
				back = { true, 0, 1 },
				fx2 = { false, 0, 1 },
				fx1 = { false, 0, 1 },
				body = { true, 0, 1 },
				lab = { true, 0, 1 },
			}, look)
			loaded.client.nextFrame(3)
			assert.are.same(0, slotOf(frame, "body").texture.rotation)
		end
	)
end)

describe("a Prestige emblem", function()
	it(
		"shows the rank's emblem, I to X and the Master's past X, at the size asked: 64, 34 or 22; none at rank 0"
			.. " (LED-R152)",
		function()
			local loaded = core()
			local Pagle = loaded.env.Pagle
			local texture = loaded.env.UIParent:CreateTexture()
			local atlas = loaded.ns.ATLASES.PrestigeEmblems

			for _, case in ipairs({ { 1, "emblem-i", 64 }, { 10, "emblem-x", 34 }, { 13, "emblem-master", 22 } }) do
				assert.is_true(Pagle.SetPrestigeEmblem(texture, case[1], case[3]))
				assert.are.same(
					{ atlas.file, coordsOf(atlas, case[2]), case[3], case[3], true },
					{ texture.texture, texture.texCoord, texture.width, texture.height, texture.shown }
				)
			end
			assert.is_false(Pagle.SetPrestigeEmblem(texture, 0, 34))
			assert.is_false(texture.shown)
			assert.are.equal("Interface\\AddOns\\Pagle\\media\\prestige\\Emblems", atlas.file)
		end
	)

	it("writes the rank's emblem into a line of text at 22, and nothing at rank 0 (LED-R152)", function()
		local loaded = core()
		local Pagle = loaded.env.Pagle

		assert.are.equal(
			"|TInterface\\AddOns\\Pagle\\media\\prestige\\Emblems:22:22:0:0:512:1024:2:130:266:394|t",
			Pagle.PrestigeEmblemMarkup(7, 22)
		)
		assert.are.equal("", Pagle.PrestigeEmblemMarkup(0, 22))
	end)
end)
