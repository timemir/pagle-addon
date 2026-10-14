-- Simulated Size records through the Ledger's projection on FakePagle (LED-R80, LED-R85): Core sizes each Catch from
-- the shipped catalogue's typical length (LOG-R65), and the Ledger keeps each Species' longest in millimetres.

local MACKEREL = 6303

describe("Simulated Size records on Core's sizes", function()
	it("keeps the longest of a Species' live Catches, the earliest on a tie, and since (LED-R80, LOG-R65)", function()
		local fake = newFakePagle()
		local loaded = fake.load("Pagle_Ledger")
		fake.login()
		fake.enterWorld()
		local sizes = {}
		fake.Pagle.RegisterCallback("Spec", "Catch", function(_, catch)
			sizes[#sizes + 1] = { catchId = catch.catchId, length = catch.size.length, band = catch.size.band }
		end)

		for _ = 1, 12 do
			fake.playCast("caught", { { itemID = MACKEREL, quantity = 1 } })
		end

		local longest, at = sizes[1], 1
		for i, size in ipairs(sizes) do
			if size.length > longest.length then
				longest, at = size, i
			end
		end
		local species = loaded.ns.projection:GetState().species[MACKEREL]
		assert.are.equal(12, #sizes)
		-- These Catch IDs' sizes beat the first Catch's at least once, so the record moved (LED-R82).
		assert.is_true(at > 1)
		assert.are.same(
			{ longest.catchId, longest.length, longest.band, 12 - at },
			{ species.record.catchId, species.record.length, species.record.band, species.since }
		)
	end)
end)
