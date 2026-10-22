-- Core's fish crests (VAR-R12–R14, SHOP-R22) as logic: their names, their texts and dots while not earned, over Core's
-- committed lore, and their registration on FakePagle's Core, owned from its variety projection.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

-- Each of a Species' positions in `list` caught, as Pagle.GetVarietiesCaught returns them.
---@param list integer[]
---@return table<integer, true>
local function caught(list)
	local set = {}
	for _, index in ipairs(list) do
		set[index] = true
	end
	return set
end

-- Hooks naming the fish from `names` with the enUS client's prefix dropped, nothing caught and nothing owned.
---@param names table<integer, string>
---@return PagleFishCrestHooks
local function hooks(names)
	return {
		species = FISH_CREST_SPECIES,
		caught = function()
			return {}
		end,
		itemName = function(itemID)
			return names[itemID]
		end,
		dropPrefix = "Raw ",
		owned = function()
			return false
		end,
	}
end

describe("A fish crest's name (VAR-R12)", function()
	it("is lore's {fish} Crest with the fish's item name, less the client's prefix where it starts with it", function()
		local names = { [4603] = "Raw Spotted Yellowtail", [1467] = "Spotted Sunfish", [6289] = "Raw" }

		assert.are.same({ "Spotted Yellowtail Crest", "Spotted Sunfish Crest", "Raw Crest" }, {
			ns.FishCrestName(4603, ns.FishCrestFish(hooks(names), 4603)),
			ns.FishCrestName(1467, ns.FishCrestFish(hooks(names), 1467)),
			ns.FishCrestName(6289, ns.FishCrestFish(hooks(names), 6289)),
		})
	end)

	it("says Item {itemID} while the client hasn't the fish cached", function()
		assert.is_nil(ns.FishCrestFish(hooks({}), 6359))
		assert.are.equal("Item 6359 Crest", ns.FishCrestName(6359, nil))
	end)

	it("keeps a fish name with % in it whole", function()
		assert.are.equal("100% Fish Crest", ns.FishCrestName(6359, "100% Fish"))
	end)
end)

describe("A fish crest's texts and dots while not earned (VAR-R13, VAR-R14)", function()
	it(
		'tags the row "{n} of 10 varieties" and counts the uncaught by rarity, Common first, never naming one',
		function()
			local row, note = ns.FishCrestTexts(caught({ 1, 2, 5, 8 }), "Spotted Yellowtail")

			assert.are.equal("4 of 10 varieties", row)
			assert.are.equal(
				"4 of 10 Spotted Yellowtail varieties. Still out there: 2 Common, 2 Uncommon, 1 Rare, 1 Epic.",
				note
			)
		end
	)

	it("leaves a rarity with none uncaught out of the count", function()
		local _, note = ns.FishCrestTexts(caught({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }), "Item 6359")

		assert.are.equal("9 of 10 Item 6359 varieties. Still out there: 1 Epic.", note)
	end)

	it("draws ten dots in variety order, each in its rarity's colour, filled when caught", function()
		local dots = ns.FishCrestDots(caught({ 1, 10 }))

		assert.are.equal(10, #dots)
		local filled, colors = {}, {}
		for i, dot in ipairs(dots) do
			filled[i] = dot.filled
			colors[i] = dot.color
		end
		assert.are.same({ true, false, false, false, false, false, false, false, false, true }, filled)
		local rarities = ns.VARIETY_RARITIES
		assert.are.same(rarities[1].color, colors[4])
		assert.are.same(rarities[2].color, colors[5])
		assert.are.same(rarities[3].color, colors[9])
		assert.are.same(rarities[4].color, colors[10])
		assert.are_not.equal(rarities[4].color, colors[10], "a copy: Core's rarities stay its own")
	end)
end)

describe("Core's fish crests on FakePagle (VAR-R12, VAR-R13)", function()
	-- Every position but `missing` of Oily Blackmouth (6358) caught in Core's stored variety projection, logged in.
	---@param missing integer
	---@return FakePagle
	local function nearlyAll(missing)
		local fake = newFakePagle()
		fake.login()
		fake.enterWorld()
		local all = {}
		for index = 1, 10 do
			all[index] = index ~= missing or nil
		end
		fake.global.projections.varieties.projection.bySpecies[6358] = all
		return fake
	end

	it("register one per Species with varieties, in the fish group, earned, with the crest's own texture", function()
		local fake = newFakePagle()

		local ids = {}
		for _, good in ipairs(fake.ns.goods:GoodsOf("core.crest")) do
			if good.group == "fish" then
				ids[#ids + 1] = good.id
				assert.is_function(good.isEarned)
				assert.are.equal("Interface\\AddOns\\Pagle\\media\\crests\\fish\\" .. good.id:match("%d+$"), good.icon)
			end
		end
		local expected = {}
		for i, speciesID in ipairs(FISH_CREST_SPECIES) do
			expected[i] = "core.crest.fish." .. speciesID
		end
		assert.are.same(expected, ids)
	end)

	it("are owned after the live Catch that catches the tenth, with no other refresh (VAR-R13)", function()
		local fake = nearlyAll(1)
		local refreshes = fake.varietyRefreshes
		assert.is_false(fake.Pagle.IsOwned("core.crest.fish.6358"))

		-- Casts until one is position 1, the one missing (a Common, one Catch in about six).
		for _ = 1, 60 do
			local cast = assert(fake.playCast("caught", { { itemID = 6358, quantity = 1 } }))
			if assert(cast.items[1].variety).index == 1 then
				break
			end
			assert.is_false(fake.Pagle.IsOwned("core.crest.fish.6358"))
		end

		assert.is_true(fake.Pagle.IsOwned("core.crest.fish.6358"))
		assert.are.equal(refreshes + 1, fake.varietyRefreshes)
	end)

	it("give the shop their texts and dots while not owned, and none once owned (SHOP-R22, VAR-R14)", function()
		local fake = nearlyAll(10)
		local goods = fake.ns.goods

		local row, note = goods:EarnedTexts("core.crest.fish.6358")
		local dots = goods:Progress("core.crest.fish.6358")

		assert.are.same({ "9 of 10 varieties", "9 of 10 Item 6358 varieties. Still out there: 1 Epic." }, { row, note })
		assert.are.same({ true, false }, { dots[9].filled, dots[10].filled })
		fake.global.projections.varieties.projection.bySpecies[6358][10] = true
		goods:Refresh("Core")
		assert.is_true(fake.Pagle.IsOwned("core.crest.fish.6358"))
		assert.is_nil(goods:EarnedTexts("core.crest.fish.6358"))
		assert.is_nil(goods:Progress("core.crest.fish.6358"))
	end)

	it("stay owned when a rebuild finds fewer caught (VAR-R90)", function()
		local fake = nearlyAll(0)
		fake.ns.goods:Refresh("Core")
		assert.is_true(fake.Pagle.IsOwned("core.crest.fish.6358"))

		fake.global.projections.varieties.projection.bySpecies[6358] = { [1] = true }
		fake.ns.goods:Refresh("Core")

		assert.is_true(fake.Pagle.IsOwned("core.crest.fish.6358"))
	end)
end)
