-- Hunts' moments marked for the player's party (announcements.md ANN-R104, from 1.5.2, #640): the moment of a Hunt's
-- first gold tier, as the adapter wraps logic's ns.HuntTierMoment, carries `party = "gold"` and the Hunt's ID, and no
-- other tier does; Hunts' def names a Hunt by its ID for a groupmate's toast (ANN-R106).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

-- A Hunt of the fixture list with three tiers or more.
local function threeTiered(loaded)
	for _, hunt in ipairs(loaded.ns.hunts:Hunts()) do
		if #hunt.tiers >= 3 then
			return hunt
		end
	end
	error("no Hunt with three tiers in the fixture list")
end

describe("Hunts' party moments (ANN-R104)", function()
	it("mark the gold tier's moment with its Hunt, and not bronze or silver, and say what it says as before", function()
		local loaded = hunts.login(nil, {})
		local hunt = threeTiered(loaded)
		local marks = {}
		for k = 1, 3 do
			local moment = loaded.ns.HuntTierMoment(hunt, k, { itemID = 6303 })
			marks[k] = { tostring(moment.party), tostring(moment.partyHunt), moment.stamp }
		end
		local L = loaded.ns.L
		assert.are.same({
			{ "nil", "nil", L.HUNT_COMPLETE_STAMP },
			{ "nil", "nil", L.TRIMS.silver },
			{ "gold", hunt.id, L.TRIMS.gold },
		}, marks)
	end)

	it("name a Hunt it knows by its ID through its def, and nothing for one it doesn't (ANN-R106)", function()
		local loaded, fake = hunts.login(nil, {})
		local hunt = threeTiered(loaded)
		local def = fake.registry:ModuleOf(loaded.ns.Module).def
		assert(def.partyHuntName, "Hunts' def has no partyHuntName")
		assert.are.equal(loaded.ns.hunts:HuntName(hunt.id), def.partyHuntName(hunt.id))
		assert.is_nil(def.partyHuntName("no_such_hunt"))
	end)
end)
