-- The Ledger's moments marked for the player's party (announcements.md ANN-R104, from 1.5.x, #640): the adapter's
-- ns.PartyKind reads each moment as raised and marks a Legend, a Rare or Epic variety, a Monster-size record, a Zone
-- Master, a Prestige and Ledger completion's title, and nothing else; the outlets' RaiseMoment carries the mark.

-- The Ledger loaded on FakePagle and logged in.
local function ledger()
	local fake = newFakePagle()
	fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
	local loaded = fake.load("Pagle_Ledger")
	fake.login()
	return loaded, fake
end

describe("the Ledger's party moments (ANN-R104)", function()
	it("marks a Legend, a Rare or Epic variety, a Zone Master and a Prestige, and not their neighbours", function()
		local loaded = ledger()
		local kind = loaded.ns.PartyKind
		assert.are.equal("legend", kind({ kind = "legend", title = "Legend" }))
		assert.are.equal("colour", kind({ kind = "rareVariety", title = "Rare variety" }))
		assert.are.equal("colour", kind({ kind = "epicVariety", title = "Epic variety" }))
		assert.are.equal("zone", kind({ kind = "zoneMaster", title = "Zone Master" }))
		assert.are.equal("prestige", kind({ kind = "prestige", title = "Prestige I" }))
		for _, other in ipairs({ "newVariety", "newSpecies", "zoneRank", "prestigeReady", "levelUp", "everyColour" }) do
			assert(kind({ kind = other, title = other }) == nil, other)
		end
	end)

	it("marks a size record only in the Monster band, by its ruler's label", function()
		local loaded = ledger()
		local kind = loaded.ns.PartyKind
		local function record(label)
			return {
				kind = "sizeRecord",
				title = "Size record",
				ruler = { old = 1, new = 2, unit = "length", label = label },
			}
		end
		assert.are.equal("monster", kind(record("Monster")))
		assert.is_nil(kind(record("Whopper")))
		assert.is_nil(kind(record("length")))
	end)

	it("marks the title moment of complete.ledger, and not another completion title", function()
		local loaded = ledger()
		local kind = loaded.ns.PartyKind
		assert.are.equal("ledger", kind({ kind = "completeTitle", title = "Title earned", text = "Angler of Azeroth" }))
		assert.is_nil(kind({ kind = "completeTitle", title = "Title earned", text = "Collector of Boots" }))
	end)

	it("carries the mark through its outlets' RaiseMoment, and clears none it doesn't set", function()
		local loaded = ledger()
		local raised = {}
		local outlets = loaded.ns.Outlets({
			RaiseMoment = function(_, moment)
				raised[#raised + 1] = moment
			end,
		})
		outlets.RaiseMoment({ rung = "splash", kind = "legend", title = "Legend", icon = 19805 })
		outlets.RaiseMoment({ rung = "toast", kind = "newSpecies", title = "New Species" })
		assert.are.same({ "legend" }, { raised[1].party })
		assert.is_nil(raised[2].party)
	end)
end)
