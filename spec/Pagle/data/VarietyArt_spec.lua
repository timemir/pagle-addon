describe("the variety art table", function()
	local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
	local ns = loaded.ns

	it("names the two atlases and the image size (core/varieties.md › UI)", function()
		assert.are.same({
			"Interface\\AddOns\\Pagle\\media\\varieties\\Varieties1",
			"Interface\\AddOns\\Pagle\\media\\varieties\\Varieties2",
		}, ns.VARIETY_ATLASES)
		assert.are.same({ w = 192, h = 96, atlas = 2048 }, ns.VARIETY_ART_SIZE)
	end)

	it("has ten images, inside an atlas, for every Species with varieties and no other (VAR-R11)", function()
		local size = ns.VARIETY_ART_SIZE
		local species = 0
		for itemID, item in pairs(ns.catalogue.items) do
			if item.varieties and item.species == itemID then
				species = species + 1
				local art = ns.VARIETY_ART[itemID]
				assert.is_table(art, tostring(itemID))
				assert.are.equal(#item.varieties, #art)
				for _, cell in ipairs(art) do
					assert.is_truthy(ns.VARIETY_ATLASES[cell[1]])
					assert.is_true(cell[2] >= 0 and cell[2] + size.w <= size.atlas)
					assert.is_true(cell[3] >= 0 and cell[3] + size.h <= size.atlas)
				end
			end
		end
		assert.are.equal(37, species)
		local entries = 0
		for _ in pairs(ns.VARIETY_ART) do
			entries = entries + 1
		end
		assert.are.equal(species, entries)
	end)
end)
