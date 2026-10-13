describe("the generated catalogue", function()
	local loaded = loadAddon("Pagle", FOREVER_GLOBALS)

	it("is ns.catalogue once Core loads through its TOC (DATA-R75, DATA-R76)", function()
		assert.is_table(loaded.ns.catalogue)
	end)

	it("carries a 16-hex fingerprint (DATA-R70)", function()
		assert.is_truthy(tostring(loaded.ns.catalogue.fingerprint):match("^" .. ("%x"):rep(16) .. "$"))
	end)

	describe("Pagle.GetItem (LOG-R55)", function()
		local GetItem = loaded.env.Pagle.GetItem

		it("returns each Extravaganza rare as a Legend fish (DATA-R22, DATA-R77)", function()
			-- Brownell's Blue Striped Racer, Keefer's Angelfish, Dezian Queenfish: uncommon (quality 2) in DB2.
			for _, itemID in ipairs({ 19803, 19805, 19806 }) do
				assert.are.same({
					category = "fish",
					species = itemID,
					quality = 2,
					legend = true,
					noise = false,
					removed = false,
					pool = false,
				}, GetItem(itemID))
			end
		end)

		it("returns a trophy with its family and its weight from the enUS name (DATA-R21)", function()
			-- 13876 is "40 Pound Yellowtail" in items.csv.
			local item = GetItem(13876)
			assert.are.equal("trophy", item.category)
			assert.are.equal(40, item.weight)
			assert.is_number(item.family)
		end)

		it("returns a Noise item as other (DATA-R16)", function()
			-- 118, Minor Healing Potion: DB2 class 0, Consumable.
			assert.are.same(
				{ category = "other", quality = 1, legend = false, noise = true, removed = false, pool = false },
				GetItem(118)
			)
		end)

		it("returns nil for an item outside the universe, which is Uncharted (DATA-R15)", function()
			assert.is_nil(GetItem(25))
			assert.is_nil(GetItem(999999))
		end)
	end)
end)
