-- Clams' pure logic: the clam table (QOL-R57) and which clam opens next (QOL-R55, QOL-R56).

describe("QoL's clam logic", function()
	local ns = loadAddon("Pagle_QoL", FOREVER_GLOBALS).ns

	local SMALL_BARNACLED, THICK_SHELLED, BIG_MOUTH = 5523, 5524, 7973

	describe("ns.CLAMS", function()
		it("is Small Barnacled, Thick-shelled and Big-mouth Clam, by item ID (QOL-R57)", function()
			-- qol.md › Clams, QOL-R57, and its Tunables row: 5523, 5524, 7973.
			assert.are.same({ SMALL_BARNACLED, THICK_SHELLED, BIG_MOUTH }, ns.CLAMS)
		end)
	end)

	describe("ns.ChooseClam", function()
		-- An availability test over these item IDs, as the adapter's bags and usability give it.
		---@param ... integer
		---@return fun(itemID: integer): boolean
		local function have(...)
			local items = {}
			for _, itemID in ipairs({ ... }) do
				items[itemID] = true
			end
			return function(itemID)
				return items[itemID] == true
			end
		end

		it("opens the lowest item ID in the bags first (QOL-R55)", function()
			assert.are.equal(THICK_SHELLED, ns.ChooseClam(true, have(BIG_MOUTH, THICK_SHELLED)))
			assert.are.equal(SMALL_BARNACLED, ns.ChooseClam(true, have(BIG_MOUTH, SMALL_BARNACLED, THICK_SHELLED)))
			assert.are.equal(BIG_MOUTH, ns.ChooseClam(true, have(BIG_MOUTH)))
		end)

		it("is none with no clam available (QOL-R55)", function()
			assert.is_nil(ns.ChooseClam(true, have()))
		end)

		it("is none while Open clams between Casts is off (QOL-R56)", function()
			assert.is_nil(ns.ChooseClam(false, have(THICK_SHELLED)))
		end)

		it("never picks an item outside the clam table, such as a locked box (QOL-R57, QOL-R96)", function()
			local everything = function()
				return true
			end
			local onlyOthers = have(6529, 6354) -- a Shiny Bauble, a Small Locked Chest

			assert.are.equal(SMALL_BARNACLED, ns.ChooseClam(true, everything))
			assert.is_nil(ns.ChooseClam(true, onlyOthers))
		end)
	end)
end)
