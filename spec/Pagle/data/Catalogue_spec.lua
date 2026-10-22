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
			-- Brownell's Blue Striped Racer, Keefer's Angelfish, Dezian Queenfish: uncommon (quality 2) in DB2, and
			-- pool, as School of Tastyfish's catches (DATA-R43). Each carries its Species' typical length (DATA-R20,
			-- from #160), whose value the dev tunes in species.toml.
			for _, itemID in ipairs({ 19803, 19805, 19806 }) do
				local item = GetItem(itemID)
				assert.is_number(item.typicalLength)
				assert.is_true(item.typicalLength >= 1 and item.typicalLength % 1 == 0)
				assert.are.same({
					category = "fish",
					species = itemID,
					quality = 2,
					legend = true,
					noise = false,
					removed = false,
					pool = true,
					typicalLength = item.typicalLength,
				}, item)
			end
		end)

		it("returns pool = true for an item from a pool type's catches, false otherwise (LOG-R55, DATA-R77)", function()
			-- 251524, Whimsyfin: School of Whimsyfin's catch (DATA-R43). 6358, Oily Blackmouth: its school's.
			-- 6303, Raw Slitherskin Mackerel: area loot only.
			assert.is_true(GetItem(251524).pool)
			assert.is_true(GetItem(6358).pool)
			assert.is_false(GetItem(6303).pool)
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

		it("returns a Species item's ten variety keys in order, and none for a Legend or junk (VAR-R4)", function()
			-- 6359, Firefin Snapper: a sized Species; 6887, Spotted Yellowtail, folds into 4603 and carries its ten.
			-- 19803 is a Legend; 6717, Gaffer Jack, is junk (core/varieties.md › Data).
			local firefin = GetItem(6359).varieties
			assert.are.equal(10, #firefin)
			assert.are.equal("coral", firefin[2])
			assert.are.same(GetItem(4603).varieties, GetItem(6887).varieties)
			assert.is_nil(GetItem(19803).varieties)
			assert.are.equal("junk", GetItem(6717).category)
			assert.is_nil(GetItem(6717).varieties)
		end)

		it("returns nil for an item outside the universe, which is Uncharted (DATA-R15)", function()
			assert.is_nil(GetItem(25))
			assert.is_nil(GetItem(999999))
		end)
	end)
end)
