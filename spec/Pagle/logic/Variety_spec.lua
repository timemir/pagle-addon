-- Fish varieties (VAR-R1–R5, VAR-R11): the variety hash of a Catch ID, its position and rarity, which Catches have
-- one, and a Species' ten as Core lists them, as pure logic over the Catch ID and the catalogue.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

-- THE FREEZE (VAR-R5, ADR 0010). Once shipped, a Catch's variety never changes: Core's and the Ledger's projections
-- are rebuilt from the Catch log, and a moved variety could take back a fish crest's tenth colour. So this spec pins
-- the hash (every `h` below), the salt and the weights (the Catch IDs either side of each cut point). If it fails,
-- don't edit these numbers: the variety hash is its own frozen copy, and nothing may move it.
local FROZEN = "the variety hash, its salt and its weights are frozen once shipped (VAR-R5, ADR 0010): a Catch's"
	.. " variety never changes, so never edit these. "

-- A Species item of the catalogue's shape with its ten variety keys (VAR-R4); `fields` overrides any of it.
---@param fields table?
---@return PagleItem
local function fish(fields)
	local item = {
		category = "fish",
		species = 6359,
		typicalLength = 300,
		legend = false,
		noise = false,
		removed = false,
		pool = true,
		varieties = { "k1", "k2", "k3", "k4", "k5", "k6", "k7", "k8", "k9", "k10" },
	}
	for key, value in pairs(fields or {}) do
		item[key] = value
	end
	return item
end

describe("the variety percentile, frozen once shipped (VAR-R3, VAR-R5)", function()
	-- VAR-R3's test vectors: the Catch ID, `h` after fmix32 over it with `#variety` appended, `v` to six places, the
	-- position and the rarity.
	local VECTORS = {
		{ "Player-4395-0A1B2C3D-1791731747-0:1", 4121951395, 0.959717, 9, "rare" },
		{ "Player-4395-0A1B2C3D-1791731747-0:2", 141524587, 0.032951, 1, "common" },
		{ "Player-4395-0A1B2C3D-1791731762-1:1", 4262029481, 0.992331, 10, "epic" },
		{ "Player-1-00000001-1700000000-0:1", 218561979, 0.050888, 1, "common" },
	}

	for _, vector in ipairs(VECTORS) do
		local catchId, h, v, index, rarity = unpack(vector)

		it(("gives %s VAR-R3's h, v, position and rarity (VAR-R3)"):format(catchId), function()
			assert.are.equal(h, ns.VarietyHash(catchId), FROZEN .. "The hash of " .. catchId .. " moved.")
			assert.are.equal(h / 2 ^ 32, ns.VarietyPercentile(catchId), FROZEN .. "v of " .. catchId .. " moved.")
			assert(math.abs(ns.VarietyPercentile(catchId) - v) < 0.0000005, FROZEN .. "v moved.")
			assert.are.equal(index, ns.VarietyIndex(catchId), FROZEN .. "The position of " .. catchId .. " moved.")
			assert.are.same(
				{ id = "6359.k" .. index, index = index, rarity = rarity },
				ns.VarietyOf(catchId, fish()),
				FROZEN .. "The variety of " .. catchId .. " moved."
			)
		end)
	end

	-- The Catch IDs whose `v` lie closest below and at-or-above each cumulative cut point (0.175, 0.35, 0.525, 0.70,
	-- 0.7734, 0.8467, 0.92, 0.955, 0.99) among 30,000,000 synthetic ones (sequential times, items 1–3), found once by
	-- search: each `v` is within 0.00000013 of its cut, so moving a weight by a Catch in 10,000 moves one of these
	-- Catches to another position (VAR-R3). Each row: the Catch ID, its `h` and its position.
	local CUT_VECTORS = {
		{ "Player-4618-0A1B2C3D-1797110119-0:2", 751619157, 1 }, -- v 0.174999972107
		{ "Player-4618-0A1B2C3D-1797668040-0:2", 751619295, 2 }, -- v 0.175000004238
		{ "Player-4618-0A1B2C3D-1797743107-0:3", 1503238152, 2 }, -- v 0.349999906495
		{ "Player-4618-0A1B2C3D-1794041317-0:1", 1503238668, 3 }, -- v 0.350000026636
		{ "Player-4618-0A1B2C3D-1798280791-0:2", 2254857755, 3 }, -- v 0.524999982445
		{ "Player-4618-0A1B2C3D-1793194807-0:1", 2254858352, 4 }, -- v 0.525000121444
		{ "Player-4618-0A1B2C3D-1795246903-0:2", 3006477016, 4 }, -- v 0.699999978766
		{ "Player-4618-0A1B2C3D-1795155778-0:1", 3006477116, 5 }, -- v 0.700000002049
		{ "Player-4618-0A1B2C3D-1795027330-0:1", 3321727629, 5 }, -- v 0.773399981903
		{ "Player-4618-0A1B2C3D-1798476105-0:2", 3321727881, 6 }, -- v 0.773400040576
		{ "Player-4618-0A1B2C3D-1797968846-0:2", 3636548732, 6 }, -- v 0.846699981950
		{ "Player-4618-0A1B2C3D-1791808243-0:1", 3636548900, 7 }, -- v 0.846700021066
		{ "Player-4618-0A1B2C3D-1800301766-0:2", 3951369686, 7 }, -- v 0.919999947306
		{ "Player-4618-0A1B2C3D-1793549736-0:3", 3951370221, 8 }, -- v 0.920000071870
		{ "Player-4618-0A1B2C3D-1791757824-0:3", 4101693707, 8 }, -- v 0.954999985872
		{ "Player-4618-0A1B2C3D-1800268609-0:3", 4101693797, 9 }, -- v 0.955000006827
		{ "Player-4618-0A1B2C3D-1798625081-0:3", 4252017581, 9 }, -- v 0.989999990212
		{ "Player-4618-0A1B2C3D-1792899976-0:2", 4252017887, 10 }, -- v 0.990000061458
	}

	it("puts the Catch IDs either side of each cut point at the positions VAR-R3 gives (VAR-R3, VAR-R5)", function()
		for _, vector in ipairs(CUT_VECTORS) do
			local catchId, h, index = unpack(vector)
			assert.are.equal(h, ns.VarietyHash(catchId), FROZEN .. "The hash of " .. catchId .. " moved.")
			assert.are.equal(
				index,
				ns.VarietyIndex(catchId),
				FROZEN .. "A cut point moved: " .. catchId .. " left position " .. index .. "."
			)
		end
	end)

	it("never calls into Size, so no change to the Simulated Size can move a variety (VAR-R5)", function()
		local sizeHash, sizePercentile, simulatedSize = ns.SizeHash, ns.SizePercentile, ns.SimulatedSize
		local function moved(...)
			error("a variety read Size's hash: " .. select("#", ...))
		end
		ns.SizeHash, ns.SizePercentile, ns.SimulatedSize = moved, moved, moved
		local ok, variety = pcall(ns.VarietyOf, VECTORS[1][1], fish())
		ns.SizeHash, ns.SizePercentile, ns.SimulatedSize = sizeHash, sizePercentile, simulatedSize

		assert(ok, tostring(variety))
		assert.are.same({ id = "6359.k9", index = 9, rarity = "rare" }, variety)
	end)

	-- #slow: 200,000 variety hashes and as many size hashes take seconds, ten times that under luacov's line hook, so
	-- scripts/check.sh runs it once, in a pass without coverage.
	it(
		"spreads 200,000 synthetic Catch IDs over the positions as VAR-R3's weights do, v uncorrelated with the size percentile (VAR-R3) #slow",
		function()
			-- Casts at sequential times, 2 items each, until 200,000 Catch IDs; the share each position should get.
			local SHARES = { 0.175, 0.175, 0.175, 0.175, 0.0734, 0.0733, 0.0733, 0.035, 0.035, 0.01 }
			local counts, total = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, 0
			local n, sx, sy, sxx, syy, sxy = 0, 0, 0, 0, 0, 0 -- for Pearson's r of v and u over every Catch
			local cast = 0
			while total < 200000 do
				cast = cast + 1
				local entryId = "Player-4618-0A1B2C3D-" .. (1791731747 + cast) .. "-0"
				for item = 1, 2 do
					local catchId = entryId .. ":" .. item
					local index = ns.VarietyIndex(catchId)
					counts[index] = counts[index] + 1
					total = total + 1
					local x, y = ns.VarietyPercentile(catchId), ns.SizePercentile(catchId)
					n, sx, sy, sxx, syy, sxy = n + 1, sx + x, sy + y, sxx + x * x, syy + y * y, sxy + x * y
				end
			end

			local outside = {} -- each position whose share is more than 0.3 points off
			for index, share in ipairs(SHARES) do
				if math.abs(counts[index] / total - share) > 0.003 then
					outside[#outside + 1] = ("position %d: %d of %d"):format(index, counts[index], total)
				end
			end
			assert.are.same({}, outside)
			-- For independent draws r's standard error is 1/sqrt(n), about 0.0022 here, so 0.01 is far outside chance:
			-- a big fish is no likelier to be a rare one (VAR-R3).
			local r = (n * sxy - sx * sy) / math.sqrt((n * sxx - sx * sx) * (n * syy - sy * sy))
			assert(math.abs(r) < 0.01, "v and u correlate: r = " .. r)
		end
	)
end)

describe("ns.VarietyOf", function()
	local CATCH = "Player-4395-0A1B2C3D-1791731747-0:2" -- position 1 (VAR-R3's second vector)

	it("gives a sized fish or quest fish its Species' variety, one per Catch (VAR-R1, VAR-R4, VAR-R92)", function()
		assert.are.same({ id = "6359.k1", index = 1, rarity = "common" }, ns.VarietyOf(CATCH, fish()))
		assert.are.same(
			{ id = "8365.k1", index = 1, rarity = "common" },
			ns.VarietyOf(CATCH, fish({ category = "questFish", species = 8365 }))
		)
	end)

	it("gives none to a Legend, Noise, a trophy, junk, an Uncharted item or an unsized Species (VAR-R1)", function()
		assert.is_nil(ns.VarietyOf(CATCH, fish({ legend = true })))
		assert.is_nil(ns.VarietyOf(CATCH, fish({ noise = true })))
		assert.is_nil(ns.VarietyOf(CATCH, fish({ category = "trophy", family = 1, weight = 17 })))
		assert.is_nil(ns.VarietyOf(CATCH, fish({ category = "junk" })))
		assert.is_nil(ns.VarietyOf(CATCH, nil))
		local unsized = fish()
		unsized.typicalLength = nil
		assert.is_nil(ns.VarietyOf(CATCH, unsized)) -- no Simulated Size, no variety (LOG-R65)
	end)

	it(
		"gives one exactly to the non-Legend items ns.SizeOf sizes, when they list varieties (VAR-R1, LOG-R65)",
		function()
			local items = {
				fish(),
				fish({ category = "questFish" }),
				fish({ legend = true }),
				fish({ noise = true }),
				fish({ category = "trophy" }),
				fish({ category = "junk" }),
				fish({ category = "container" }),
				fish({ category = "treasure" }),
				fish({ category = "other" }),
			}
			local unsized = fish()
			unsized.typicalLength = nil
			items[#items + 1] = unsized
			for n, item in ipairs(items) do
				-- A full skill and 0 earlier Catches, for a SizeOf that takes them (ADR 0014); whether there's a size
				-- never depends on them.
				local hasSize = ns.SizeOf(CATCH, item, 300, 0) ~= nil and not item.legend
				assert(
					hasSize == (ns.VarietyOf(CATCH, item) ~= nil),
					"item " .. n .. " has a size but no variety, or the reverse"
				)
			end
		end
	)

	it("gives none to a Species item whose catalogue record lists no varieties (VAR-R4)", function()
		local item = fish()
		item.varieties = nil
		assert.is_nil(ns.VarietyOf(CATCH, item))
	end)
end)

describe("the variety rarities", function()
	it("lists Common to Epic with their names, one variety's weight and the UI's colours (VAR-R2, VAR-R11)", function()
		local function rgb(hex)
			return {
				tonumber(hex:sub(1, 2), 16) / 255,
				tonumber(hex:sub(3, 4), 16) / 255,
				tonumber(hex:sub(5, 6), 16) / 255,
			}
		end
		assert.are.same({
			{ key = "common", name = "Common", weight = 1750, color = rgb("ffffff"), ink = rgb("6a5a44") },
			{ key = "uncommon", name = "Uncommon", weight = 733, color = rgb("1eff00"), ink = rgb("2f6a2a") },
			{ key = "rare", name = "Rare", weight = 350, color = rgb("0070dd"), ink = rgb("23407a") },
			{ key = "epic", name = "Epic", weight = 100, color = rgb("a335ee"), ink = rgb("7a2f8a") },
		}, ns.VARIETY_RARITIES)
	end)

	it("gives each rarity's odds as VAR-R24's one Catch in 6, 14, 29 and 100 (VAR-R3, VAR-R24)", function()
		local odds = {}
		for rarity, entry in ipairs(ns.VARIETY_RARITIES) do
			odds[rarity] = math.floor(10000 / entry.weight + 0.5)
		end
		assert.are.same({ 6, 14, 29, 100 }, odds)
	end)
end)

describe("ns.VarietyList", function()
	-- Sets lore for Species 6359's k1 and data/VarietyArt.lua's globals for its first two positions while `fn` runs.
	local function withLoreAndArt(fn)
		local L = ns.L
		local saved = { ns.VARIETY_ATLASES, ns.VARIETY_ART_SIZE, ns.VARIETY_ART }
		L["variety.6359.k1.name"], L["variety.6359.k1.description"] = "Coral", "Pink as a sunset over the shallows."
		ns.VARIETY_ATLASES = { "Interface\\AddOns\\Pagle\\media\\varieties\\Varieties1", "Interface\\Varieties2" }
		ns.VARIETY_ART_SIZE = { w = 192, h = 96, atlas = 2048 }
		ns.VARIETY_ART = { [6359] = { { 1, 0, 0 }, { 2, 1024, 192 } } }
		local ok, err = pcall(fn)
		L["variety.6359.k1.name"], L["variety.6359.k1.description"] = nil, nil
		ns.VARIETY_ATLASES, ns.VARIETY_ART_SIZE, ns.VARIETY_ART = unpack(saved, 1, 3)
		assert(ok, err)
	end

	it("lists a Species' ten in order with rarity, lore and art as texture coordinates (VAR-R11)", function()
		withLoreAndArt(function()
			local list = ns.VarietyList(6359, fish().varieties)

			assert.are.equal(10, #list)
			assert.are.same({
				id = "6359.k1",
				key = "k1",
				index = 1,
				rarity = "common",
				name = "Coral",
				description = "Pink as a sunset over the shallows.",
				art = {
					texture = "Interface\\AddOns\\Pagle\\media\\varieties\\Varieties1",
					left = 0,
					right = 192 / 2048,
					top = 0,
					bottom = 96 / 2048,
				},
			}, list[1])
			assert.are.same({
				texture = "Interface\\Varieties2",
				left = 0.5,
				right = 1216 / 2048,
				top = 192 / 2048,
				bottom = 288 / 2048,
			}, list[2].art)
			local rarities = {}
			for index, entry in ipairs(list) do
				assert.are.equal(index, entry.index)
				assert.are.equal("6359.k" .. index, entry.id)
				rarities[index] = entry.rarity
			end
			assert.are.same(
				{ "common", "common", "common", "common", "uncommon", "uncommon", "uncommon", "rare", "rare", "epic" },
				rarities
			)
			assert.is_nil(list[3].art) -- no rectangle, no art
			assert.is_nil(list[3].name) -- no lore, no name
		end)
	end)

	it("gives no art while data/VarietyArt.lua is missing (VAR-R11)", function()
		local saved = { ns.VARIETY_ATLASES, ns.VARIETY_ART_SIZE, ns.VARIETY_ART }
		ns.VARIETY_ATLASES, ns.VARIETY_ART_SIZE, ns.VARIETY_ART = nil, nil, nil
		local list = ns.VarietyList(6359, fish().varieties)
		ns.VARIETY_ATLASES, ns.VARIETY_ART_SIZE, ns.VARIETY_ART = unpack(saved, 1, 3)

		assert.is_nil(list[1].art)
	end)
end)
