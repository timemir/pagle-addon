-- The Ledger's world index built from Core's catalogue at OnInitialize (LED-R10, CORE-R10), on FakePagle: a spec's
-- own catalogue through fake.setCatalogue, and the generated one.

local MACKEREL, NIGHTFISH, LEGEND, TROPHY = 6303, 13759, 19803, 13901
local ELWYNN, GOLDSHIRE, DUSKWOOD = 12, 87, 10

-- A catalogue in the shape of ns.catalogue (DATA-R76): Elwynn and Goldshire with a list, Duskwood without data.
local function fixture()
	local night = NIGHT_WINDOW
	return catalogueWith({
		items = {
			[MACKEREL] = fishRecord(MACKEREL),
			[NIGHTFISH] = fishRecord(NIGHTFISH),
			[LEGEND] = fishRecord(LEGEND, { legend = true }),
			[TROPHY] = itemRecord("trophy", { family = 1, weight = 19 }),
		},
		areas = {
			[ELWYNN] = areaRecord(0, { skillBase = 25, catches = { { itemID = MACKEREL, confirmed = false } } }),
			[GOLDSHIRE] = areaRecord(ELWYNN, {
				catches = {
					{ itemID = NIGHTFISH, confirmed = false, window = "night", gate = night, gateConfirmed = false },
					{ itemID = LEGEND, confirmed = false },
					{ itemID = TROPHY, confirmed = false },
				},
			}),
			[DUSKWOOD] = areaRecord(0, { hasData = false }),
		},
		windows = { night = { spec = night, confirmed = false } },
	})
end

-- The keys of a set, ascending.
local function keys(set)
	local list = {}
	for key in pairs(set or {}) do
		list[#list + 1] = key
	end
	table.sort(list)
	return list
end

describe("the Ledger's world index (LED-R10)", function()
	it("is built at OnInitialize from Core's catalogue (LED-R10, CORE-R10)", function()
		local fake = newFakePagle()
		fake.setCatalogue(fixture())

		local world = fake.load("Pagle_Ledger").ns.world

		assert.are.same({ ELWYNN }, world.charted)
		assert.are.same({ MACKEREL, NIGHTFISH }, keys(world.species))
		assert.are.same({ "night" }, keys(world.species[NIGHTFISH].elements))
		assert.are.same({ LEGEND }, keys(world.legends))
		assert.are.same({ weights = { TROPHY }, heaviest = TROPHY }, world.families[1])
		assert.are.same({ [ELWYNN] = 25 }, world.skillBase)
	end)

	it("is never stored: PagleLedgerDB gets no world (LED-R10)", function()
		local fake = newFakePagle()
		fake.setCatalogue(fixture())
		local loaded = fake.load("Pagle_Ledger")

		for _, section in pairs(loaded.env.PagleLedgerDB) do
			if type(section) == "table" then
				assert.is_nil(section.world)
			end
		end
	end)

	it("is the world the projection's fold ranks zones by (LED-R10, LED-R50)", function()
		local fake = newFakePagle()
		fake.setCatalogue(fixture())
		fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
		fake.catchLog:Append(castRecord({ zone = ELWYNN, items = { MACKEREL } }))
		local loaded = fake.load("Pagle_Ledger")

		fake.login()
		fake.enterWorld()

		-- Elwynn's one ungated Species makes the Angler a Local there at once; its night fish and trophy are still to
		-- come.
		assert.are.equal(3, loaded.ns.projection:GetState().zones[ELWYNN].rank)
	end)

	it("charts Stranglethorn over the generated catalogue, Tastyfish gated there (LED-R10, DATA-R28)", function()
		local world = newFakePagle().load("Pagle_Ledger").ns.world
		local stranglethorn = world.zones[33]

		assert.is_not_nil(stranglethorn)
		assert.are.equal(130, world.skillBase[33])
		-- Speckled Tastyfish, a Species, is listed there under the Extravaganza only; the rare Legends sit outside.
		assert.is_true(stranglethorn.species[19807].gated)
		assert.are.same({ "event.301" }, keys(stranglethorn.species[19807].windows))
		assert.is_nil(stranglethorn.species[19803])
		assert.is_true(world.legends[19803])
	end)
end)
