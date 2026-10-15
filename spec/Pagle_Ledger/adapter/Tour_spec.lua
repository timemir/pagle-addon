-- The Fish Journal's tour stops on FakePagle (CORE-R65, CORE-R68): each Journal spread, opened on the Ledger's own
-- representative state (the most-fished zone, the most-caught Species, a landed trophy family, a caught Legend, and a
-- search for that Species' name), shot, and the book put back as it was.

local MACKEREL, SECRET, STRAY, CATFISH_17 = 6303, 6522, 6291, 6309
local DUSKWOOD, ELWYNN, DARKSHORE = 10, 12, 148
local NAMES = {
	[MACKEREL] = "Raw Slitherskin Mackerel",
	[SECRET] = "Deviate Fish",
	[STRAY] = "Raw Brilliant Smallfish",
	[CATFISH_17] = "17 Pound Catfish",
}
local ZONES = { [DUSKWOOD] = "Duskwood", [ELWYNN] = "Elwynn Forest", [DARKSHORE] = "Darkshore" }

-- A catalogue in the shape of ns.catalogue (DATA-R76): MACKEREL and SECRET in Duskwood and Elwynn, STRAY and a trophy
-- CATFISH_17 (family 2) in Darkshore.
local function fixture()
	local function area(catches)
		local entries = {}
		for i, itemID in ipairs(catches) do
			entries[i] = { itemID = itemID, confirmed = false, gateConfirmed = false }
		end
		return areaRecord(0, { skillBase = 25, catches = entries })
	end
	return catalogueWith({
		items = {
			[MACKEREL] = fishRecord(MACKEREL),
			[SECRET] = fishRecord(SECRET),
			[STRAY] = fishRecord(STRAY),
			[CATFISH_17] = itemRecord("trophy", { family = 2, weight = 17 }),
		},
		areas = {
			[DUSKWOOD] = area({ MACKEREL, SECRET }),
			[ELWYNN] = area({ MACKEREL, SECRET }),
			[DARKSHORE] = area({ STRAY, CATFISH_17 }),
		},
	})
end

-- The log: Duskwood has two Species caught (MACKEREL three times, SECRET once), Elwynn one (MACKEREL), Darkshore one
-- (STRAY) and the trophy.
local LOG = {
	castRecord({ time = 1791000000, zone = DUSKWOOD, items = { MACKEREL } }),
	castRecord({ time = 1791000060, zone = DUSKWOOD, items = { MACKEREL } }),
	castRecord({ time = 1791000120, zone = DUSKWOOD, items = { SECRET } }),
	castRecord({ time = 1791000180, zone = ELWYNN, items = { MACKEREL } }),
	castRecord({ time = 1791000240, zone = DARKSHORE, items = { STRAY } }),
	castRecord({ time = 1791000300, zone = DARKSHORE, items = { CATFISH_17 } }),
}

-- One stop's span on the tour's clock: shown, shot 1.5 s in, hidden 0.5 s later, the next 0.3 s after that.
local STOP = 1.5 + 0.5 + 0.3

-- A Ledger on FakePagle with the log above, the book closed, and dev on.
---@param id string? the spread the book is open on, closed without
local function ledger(id)
	local fake, loaded = openJournal({
		catalogue = fixture(),
		log = LOG,
		itemNames = NAMES,
		areaNames = ZONES,
		id = id or false,
	})
	fake.slash("dev on")
	fake.printed = {}
	return fake, loaded
end

describe("the Fish Journal's tour stops (CORE-R65, CORE-R68)", function()
	it("are each spread, in the order the tour shows them", function()
		local fake = ledger()

		fake.slash("dev tour list ledger")

		assert.are.same({
			"Pagle dev: 8 tour stops:",
			"  ledger.journal.home: the Fish Journal: Home",
			"  ledger.journal.zone: the Fish Journal: the most-fished zone, its most-caught Species open",
			"  ledger.journal.fish: the Fish Journal: the most-caught Species",
			"  ledger.journal.trophy: the Fish Journal: the Trophy Room, on a landed family",
			"  ledger.journal.curios: the Fish Journal: Curios",
			"  ledger.journal.legends: the Fish Journal: Legends, on a caught one",
			"  ledger.journal.angler: the Fish Journal: the Angler page",
			"  ledger.journal.search: the Fish Journal: search results for the most-caught Species' name",
		}, fake.printed)
	end)

	it("open each spread on the Ledger's own state as it is shot (LED-R125, LED-R148)", function()
		local fake, loaded = ledger()
		local journal = loaded.ns.journal
		local seen = {}

		fake.slash("dev tour ledger")
		fake.wait(1.6)
		for i = 1, 8 do
			assert(journal:IsShown(), "stop " .. i .. " left the book closed")
			local search = journal.frame.search:GetText()
			seen[i] = { place = journal.router:Place(), search = search ~= "" and search or nil }
			fake.wait(STOP)
		end

		assert.are.same({
			{ place = { id = "home" } },
			{ place = { id = "zone", args = { zone = DUSKWOOD, species = MACKEREL } } },
			{ place = { id = "fish", args = { species = MACKEREL } } },
			{ place = { id = "trophy", args = { family = 2 } } },
			{ place = { id = "curios" } },
			{ place = { id = "legends" } },
			{ place = { id = "angler" } },
			{ place = { id = "home" }, search = "raw" },
		}, seen)
	end)

	it("show search results in the dropdown for its stop (LED-R148)", function()
		local fake, loaded = ledger()
		local journal = loaded.ns.journal

		fake.slash("dev tour ledger")
		fake.wait(1.6 + 7 * STOP)

		assert.is_true(journal.frame.searchDrop:IsShown())
		assert.are.equal("Raw Brilliant Smallfish", journal.frame.searchDrop.rows[1].label:GetText())
	end)

	it("leave the book closed, on Home, when it was closed (LED-R120)", function()
		local fake, loaded = ledger()
		local journal = loaded.ns.journal

		fake.slash("dev tour ledger")
		fake.wait(60)

		assert.is_false(journal:IsShown())
		assert.are.same({ id = "home" }, journal.router:Place())
		assert.are.equal("", journal.frame.search:GetText())
		assert.are.equal(8, #fake.tourShots)
	end)

	it("leave the book open on the spread it was on", function()
		local fake, loaded = ledger("curios")
		local journal = loaded.ns.journal

		fake.slash("dev tour ledger")
		fake.wait(60)

		assert.is_true(journal:IsShown())
		assert.are.same({ id = "curios" }, journal.router:Place())
		assert.is_false(journal.frame.searchDrop:IsShown())
	end)

	it("aren't registered on a Core without M:RegisterTourStop, and the Ledger still starts", function()
		local fake = newFakePagle()
		fake.ns.ModuleHandle.RegisterTourStop = nil

		local loaded = fake.load("Pagle_Ledger")

		assert.is_not_nil(loaded.ns.Module)
		assert.are.same({}, fake.ns.tourStops:List(fake.registry:Modules(), "ledger"))
	end)
end)
