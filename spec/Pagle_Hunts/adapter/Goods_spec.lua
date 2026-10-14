-- Hunts' goods on FakePagle (HNT-R120–R122, HNT-R70; SHOP-R21–R23, SHOP-R26, SHOP-R30–R33, SHOP-R90): the two slots
-- and seven goods in Core's goods registry, their names from lore, their previews on the shop's stage, and the board's
-- leather in the equipped cover.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local COVER, FRAME = "hunts.notebookcover", "hunts.trackerframe"

-- HNT-R121's goods, in its order, with their kinds.
local GOODS = {
	[COVER] = {
		{ "hunts.notebookcover.leather", "default" },
		{ "hunts.notebookcover.oilcloth", "tier 1" },
		{ "hunts.notebookcover.tooled", "tier 2" },
		{ "hunts.notebookcover.verdigris", "tier 3" },
	},
	[FRAME] = {
		{ "hunts.trackerframe.none", "default" },
		{ "hunts.trackerframe.inkwash", "tier 1" },
		{ "hunts.trackerframe.waxseal", "tier 2" },
	},
}

-- A good's kind as HNT-R121's table writes it; "earned" for one with isEarned (Hunts has none, HNT-R122).
---@param good PagleRegisteredGood
---@return string
local function kindOf(good)
	if good.isEarned then
		return "earned"
	elseif good.default then
		return "default"
	end
	return "tier " .. tostring(good.tier)
end

-- Pagle_Hunts on a fake that has logged in.
---@param options { lore: boolean? }?
local function loggedIn(options)
	local loaded, fake = hunts.load(nil, options)
	fake.login()
	return loaded, fake
end

describe("Hunts' goods", function()
	it(
		"register the slots hunts.notebookcover (Hunts) and hunts.trackerframe (Trackers), with HNT-R121's goods, defaults and tiers, none earned (HNT-R120, HNT-R121, HNT-R122, SHOP-R21, SHOP-R22)",
		function()
			local _, fake = loggedIn()
			local goods = fake.ns.goods

			local slots = {}
			for _, slot in ipairs(goods:Slots()) do
				if slot.module == "Hunts" then
					slots[#slots + 1] = { slot.id, slot.label, slot.category }
				end
			end
			assert.are.same({
				{ COVER, "Notebook cover", "Hunts" },
				{ FRAME, "Hunts tracker frame", "Trackers" },
			}, slots)
			for slot, expected in pairs(GOODS) do
				local registered = {}
				for i, good in ipairs(goods:GoodsOf(slot)) do
					registered[i] = { good.id, kindOf(good) }
				end
				assert.are.same(expected, registered)
			end
			assert.are.same({ "hunts.notebookcover.leather", "hunts.trackerframe.none" }, {
				fake.Pagle.GetEquipped(COVER),
				fake.Pagle.GetEquipped(FRAME),
			})
		end
	)

	it("sell for 150, 400 and 900 Coins at tiers 1, 2 and 3, in the Curio Shop (HNT-R121, SHOP-R22)", function()
		local _, fake = loggedIn()
		local shop = fake.ns.ShopModel(tostring)

		local prices = {}
		for _, id in ipairs({
			"hunts.notebookcover.oilcloth",
			"hunts.notebookcover.tooled",
			"hunts.notebookcover.verdigris",
			"hunts.trackerframe.inkwash",
			"hunts.trackerframe.waxseal",
		}) do
			prices[#prices + 1] = shop:Entry(id).price
		end
		assert.are.same({ 150, 400, 900, 150, 400 }, prices)
		assert.are.same({ "Hunts", "Hunts" }, {
			fake.Pagle.GetGood("hunts.notebookcover.oilcloth").module,
			fake.Pagle.GetGood("hunts.trackerframe.none").module,
		})
	end)

	it("are named by their IDs, with no description, while their lore keys have no text (HNT-R121, HNT-R130)", function()
		local _, fake = loggedIn({ lore = false })

		for _, slot in ipairs({ COVER, FRAME }) do
			for _, row in ipairs(GOODS[slot]) do
				local good = fake.Pagle.GetGood(row[1])
				assert.are.same({ row[1] }, { good.name, good.description })
			end
		end
	end)

	it("are named and described from their huntgood lore keys (HNT-R121, HNT-R130, SHOP-R26)", function()
		local _, fake = loggedIn()

		assert.are.same({
			{ "Oilcloth", "Black-green oilcloth that keeps the rain off the pages." },
			{ "Ink Wash", "A wash of thinned ink behind your pinned Hunts." },
		}, {
			{
				fake.Pagle.GetGood("hunts.notebookcover.oilcloth").name,
				fake.Pagle.GetGood("hunts.notebookcover.oilcloth").description,
			},
			{
				fake.Pagle.GetGood("hunts.trackerframe.inkwash").name,
				fake.Pagle.GetGood("hunts.trackerframe.inkwash").description,
			},
		})
	end)
end)
