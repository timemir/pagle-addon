-- The Legend crests as data and logic (ledger.md › LED-R153, LED-R124; announcements.md › UI › Splash): which crest a
-- Legend shows and what sits in its well, each crest's art from the Prestige frames kit, its layers' motion, and a
-- crest's SetLegend, Play and Stop over the host that draws it.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

local RACER, ANGELFISH, QUEENFISH = 19803, 19805, 19806
-- A Legend added after 1.0, with no crest of its own.
local NEWCOMER = 777200
local KEYS = { [RACER] = "racer", [ANGELFISH] = "angelfish", [QUEENFISH] = "queenfish" }

describe("a Legend's crest (LED-R153)", function()
	it("is a caught Legend's own, its icon in the well", function()
		for itemID, key in pairs(KEYS) do
			local look = ns.LegendCrestLook(itemID, true)

			assert.are.same({ key, itemID }, { look.key, look.icon })
			assert.are.equal(ns.LEGEND_CREST_ART[key], look.art)
		end
	end)

	it("is the Unwritten crest for a Legend not caught, with nothing of the Legend in it (LED-R124)", function()
		for itemID in pairs(KEYS) do
			local look = ns.LegendCrestLook(itemID, false)

			assert.are.same({ "unwritten", nil }, { look.key, look.icon })
		end
		-- the same for every uncaught Legend, so it never gives away which one is still out there
		assert.are.same(ns.LegendCrestLook(RACER, false), ns.LegendCrestLook(QUEENFISH, false))
		assert.are.same(ns.LegendCrestLook(RACER, false), ns.LegendCrestLook(nil, false))
	end)

	it("is the Unwritten crest with its icon for a caught Legend with no crest of its own", function()
		local look = ns.LegendCrestLook(NEWCOMER, true)

		assert.are.same({ "unwritten", NEWCOMER }, { look.key, look.icon })
	end)

	it("shows the Unwritten crest's own plain fish in its well only while no icon sits there", function()
		local art = ns.LEGEND_CREST_ART.unwritten
		local well
		for _, layer in ipairs(art.layers) do
			if layer.name == "well" then
				well = layer
			end
		end

		assert.is_true(ns.LegendCrestLayerShown(ns.LegendCrestLook(QUEENFISH, false), well))
		assert.is_false(ns.LegendCrestLayerShown(ns.LegendCrestLook(NEWCOMER, true), well))
		assert.is_true(ns.LegendCrestLayerShown(ns.LegendCrestLook(NEWCOMER, true), art.layers[1]))
	end)
end)

describe("the Legend crests' art (LED-R153)", function()
	it("keys the three Legends' crests by item ID, every other Legend's the Unwritten crest's", function()
		assert.are.same({ [RACER] = "racer", [ANGELFISH] = "angelfish", [QUEENFISH] = "queenfish" }, ns.LEGEND_CRESTS)
	end)

	it("draws each crest from Core's media/legends/Legend<Key>, a BLP the package ships", function()
		for key, atlasName in pairs({
			racer = "LegendRacer",
			angelfish = "LegendAngelfish",
			queenfish = "LegendQueenfish",
			unwritten = "LegendUnwritten",
		}) do
			local art = ns.LEGEND_CREST_ART[key]
			local atlas = ns.ATLASES[art.atlas]
			assert.are.equal(atlasName, art.atlas)
			assert.are.equal("Interface\\AddOns\\Pagle\\media\\legends\\" .. atlasName, atlas.file)
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
			local file = assert(io.open("addons/Pagle/media/legends/" .. atlasName .. ".blp", "rb"))
			assert.are.equal("BLP2", file:read(4))
			file:close()
			-- every layer's sprite in its atlas, in draw order, inside the crest's box
			local z = -math.huge
			for _, layer in ipairs(art.layers) do
				assert(type(atlas.sprites[layer.sprite]) == "table", key .. " " .. layer.sprite)
				assert.is_true(layer.z >= z)
				z = layer.z
				assert.is_true(layer.x >= 0 and layer.x + layer.w <= ns.LEGEND_CREST_BOX.w + 0.01)
				assert.is_true(layer.y >= 0 and layer.y + layer.h <= ns.LEGEND_CREST_BOX.h + 0.01)
			end
		end
	end)

	it('labels a Legend\'s own crest "Legend" and the Unwritten crest "Unwritten"', function()
		for _, key in ipairs({ "racer", "angelfish", "queenfish" }) do
			assert.are.equal("legend", ns.LEGEND_CREST_ART[key].label.word)
		end
		assert.are.equal("unwritten", ns.LEGEND_CREST_ART.unwritten.label.word)
		assert.are.same({ "Legend", "Unwritten" }, { ns.LegendCrestLabel("legend"), ns.LegendCrestLabel("unwritten") })
	end)

	it("puts the well, where the icon sits, at the kit's circle in the 260 x 280 box", function()
		assert.are.same({ w = 260, h = 280 }, ns.LEGEND_CREST_BOX)
		assert.are.same({ x = 130, y = 124, r = 56 }, ns.LEGEND_CREST_WELL)
	end)
end)

describe("a Legend crest's motion (LED-R153)", function()
	-- The resting frame of each moving layer of `key`'s crest, by layer name and kind.
	local function rest(key)
		local art = ns.LEGEND_CREST_ART[key]
		local out = {}
		for _, animation in
			ipairs(ns.LegendCrestAnimations(art, function(i, kind, values)
				out[art.layers[i].name .. " " .. kind] = values
			end))
		do
			animation.apply(ns.MotionSettled(animation))
		end
		return out
	end

	it("moves all four crests, every layer's motion looping for as long as it plays", function()
		for key, art in pairs(ns.LEGEND_CREST_ART) do
			local animations = ns.LegendCrestAnimations(art, function() end)
			assert(#animations > 0, key)
			for _, animation in ipairs(animations) do
				assert.are.equal("infinite", animation.iter)
			end
		end
	end)

	it("starts at once, but the Queen's second glint, half a beat behind the first", function()
		local art = ns.LEGEND_CREST_ART.queenfish
		local delays = {}
		for _, animation in ipairs(ns.LegendCrestAnimations(art, function() end)) do
			delays[#delays + 1] = animation.delay
		end

		assert.are.same({ 0, 0, 1.8, 1.8 }, delays)
	end)

	it("rests in each motion's first frame, and a glint that only flashes is unseen", function()
		-- the Racer's streamers turned back 2.5°, its lap at the start
		assert.are.same({ 0, 0, -2.5, 1, 1 }, rest("racer")["fx2 transform"])
		assert.are.same({ 0, 0, 0, 1, 1 }, rest("racer")["fx1 transform"])
		-- the Angel's light at 0.65, its halo at 0.9
		assert.are.same({ 0.65 }, rest("angelfish")["back alpha"])
		assert.are.same({ 0.9 }, rest("angelfish")["fx3 alpha"])
		-- the Queen's glints unseen
		assert.are.same({ 0 }, rest("queenfish")["fx1 alpha"])
		assert.are.same({ 0 }, rest("queenfish")["fx2 alpha"])
		-- the Unwritten crest's mist drifted left at 0.8
		assert.are.same(
			{ { 0.8 }, { -6, 0, 0, 1, 1 } },
			{ rest("unwritten")["fx1 alpha"], rest("unwritten")["fx1 transform"] }
		)
	end)
end)

describe("a Legend crest's SetLegend, Play and Stop (LED-R153)", function()
	-- A crest over a host that records what it draws and moves, on a real motion player whose Animations setting is
	-- `on.value`.
	local function newCrest()
		local on = { value = true }
		local player = ns.NewMotionPlayer({
			isOn = function()
				return on.value
			end,
			wake = function() end,
			sleep = function() end,
		})
		local drawn, moved = {}, {}
		local crest = {}
		ns.AttachLegendCrest(crest, {
			draw = function(look)
				drawn[#drawn + 1] = look.key
				moved = {}
			end,
			move = function(i, kind, values)
				moved[i .. " " .. kind] = values
			end,
			animate = function(owner, animations, onDone)
				player:Animate(owner, animations, onDone)
			end,
			stop = function(owner)
				player:Stop(owner)
			end,
		})
		return crest, player, on, drawn, function()
			return moved
		end
	end

	-- The racer's streamers' turn now, in degrees: layer 2's transform.
	local function streamers(moved)
		return moved()["2 transform"][3]
	end

	it("draws its look in the resting frame, and again only when the look changes", function()
		local crest, _, _, drawn, moved = newCrest()

		crest:SetLegend(RACER, true)
		crest:SetLegend(RACER, true)

		assert.are.same({ "racer" }, drawn)
		assert.are.equal(-2.5, streamers(moved))
		crest:SetLegend(RACER, false)
		assert.are.same({ "racer", "unwritten" }, drawn)
	end)

	it("moves while it plays, carrying on when played again, and rests when stopped", function()
		local crest, player, _, _, moved = newCrest()
		crest:SetLegend(RACER, true)

		crest:Play()
		player:Step(0.225)
		local turned = streamers(moved)
		crest:Play()
		player:Step(0.001)

		assert.is_true(turned > -2.5)
		assert.is_true(streamers(moved) >= turned)
		crest:Stop()
		assert.are.equal(-2.5, streamers(moved))
		player:Step(0.2)
		assert.are.equal(-2.5, streamers(moved))
	end)

	it("stops as it is drawn as another Legend's", function()
		local crest, player, _, _, moved = newCrest()
		crest:SetLegend(RACER, true)
		crest:Play()
		player:Step(0.2)

		crest:SetLegend(ANGELFISH, true)
		player:Step(0.4)

		-- the Angel's light at rest: nothing plays until it is played again
		assert.are.same({ 0.65 }, moved()["1 alpha"])
	end)

	it("keeps the resting frame with Animations off (SET-R30)", function()
		local crest, player, on, _, moved = newCrest()
		on.value = false
		crest:SetLegend(RACER, true)

		crest:Play()
		player:Step(0.3)

		assert.are.equal(-2.5, streamers(moved))
	end)

	it("plays again once the motion driver has settled it (hidden while it moved)", function()
		local crest, player, _, _, moved = newCrest()
		local shown = true
		function crest.IsVisible()
			return shown
		end
		crest:SetLegend(RACER, true)
		crest:Play()
		shown = false
		player:Step(0.2)
		assert.are.equal(-2.5, streamers(moved))

		shown = true
		crest:Play()
		player:Step(0.225)

		assert.is_true(streamers(moved) > -2.5)
	end)
end)
