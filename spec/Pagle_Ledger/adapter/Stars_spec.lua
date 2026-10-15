-- Species stars through the Ledger's projection on FakePagle (LED-R45, LED-R3): the world index and Core's
-- Pagle.MatchesConditions reach the fold as lookups, so a night Catch meets a night-only Species' element window.

local NIGHTFISH = 13759
local ELWYNN, GOLDSHIRE = 12, 87
local T0 = SERVER_TIME - 700
-- Realm minutes of day (LOG-R48): 08:14, and 21:40, inside the night window.
local DAY_MINUTE, NIGHT_MINUTE = 494, 1300

-- A catalogue in the shape of ns.catalogue (DATA-R76): NIGHTFISH listed in Goldshire under the night window only.
local function fixture()
	local night = NIGHT_WINDOW
	local function area(parent, catches)
		return areaRecord(parent, { catches = catches })
	end
	return catalogueWith({
		items = {
			[NIGHTFISH] = fishRecord(NIGHTFISH),
		},
		areas = {
			[ELWYNN] = area(0, {}),
			[GOLDSHIRE] = area(ELWYNN, {
				{ itemID = NIGHTFISH, confirmed = false, window = "night", gate = night, gateConfirmed = false },
			}),
		},
		windows = { night = { spec = night, confirmed = false } },
	})
end

-- A caught Cast of one NIGHTFISH in Elwynn at realm `minute`, for fake.catchLog:Append.
---@param time integer
---@param minute integer
local function cast(time, minute)
	return castRecord({ time = time, zone = ELWYNN, minute = minute, items = { NIGHTFISH } })
end

describe("Species stars in the Ledger's projection (LED-R45)", function()
	it("meets a night-only Species' element window at a night Catch, judged by Core (LED-R45, LED-R3)", function()
		local fake = newFakePagle()
		fake.setCatalogue(fixture())
		fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
		fake.catchLog:Append(cast(T0, DAY_MINUTE))
		local loaded = fake.load("Pagle_Ledger")
		fake.login()
		fake.enterWorld()
		local ns = loaded.ns
		local state = ns.projection:GetState()
		assert.are.same(
			{ [1] = true },
			ns.ShownSpeciesStars(ns.world, state, ns.CelebratedSet(ns.db.global), NIGHTFISH)
		)

		-- A live Cast at night, in Elwynn though only Goldshire lists it: the window counts in any zone.
		local night = {}
		for key, value in pairs(fake.conditions) do
			night[key] = value
		end
		night.minute, night.zone, night.subzone = NIGHT_MINUTE, ELWYNN, 0
		fake.setConditions(night)
		fake.playCast("caught", { { itemID = NIGHTFISH, quantity = 1 } })

		assert.are.equal(2, state.species[NIGHTFISH].n)
		assert.are.same({ night = true }, state.species[NIGHTFISH].windowsMet)
		assert.are.same(
			{ [1] = true, [2] = true },
			ns.ShownSpeciesStars(ns.world, state, ns.CelebratedSet(ns.db.global), NIGHTFISH)
		)
	end)
end)
