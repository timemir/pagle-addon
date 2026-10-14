-- The Journal's Species on FakePagle (LED-R124, LED-R140–R142, LED-R148, DATA-R112): a fixture catalogue and Catch
-- log, the Ledger's projection built at login, and the fish spread's pages and the search box's results as data.

local MACKEREL, NIGHTFISH, SECRET, STRAY, GONE = 6303, 13759, 6522, 6291, 6299
local DUSKWOOD, ELWYNN, WESTFALL, REDRIDGE = 10, 12, 40, 44
local NAMES = {
	[MACKEREL] = "Raw Slitherskin Mackerel",
	[NIGHTFISH] = "Raw Nightfin Snapper",
	[SECRET] = "Deviate Fish",
	[STRAY] = "Raw Brilliant Smallfish",
	[GONE] = "Sickly Looking Fish",
}
local ZONES = { [DUSKWOOD] = "Duskwood", [ELWYNN] = "Elwynn Forest", [WESTFALL] = "Westfall", [REDRIDGE] = "Redridge" }
local T0 = 1791000000
local MINUTE = 60
-- Realm minutes of day: 08:14, and 21:40, inside the fixture's night (20:00 to 06:00).
local DAY_MINUTE, NIGHT_MINUTE = 494, 1300

-- A catalogue in the shape of ns.catalogue (DATA-R76). MACKEREL any time in Duskwood, Elwynn and Westfall; NIGHTFISH
-- by night in Duskwood, from pools; SECRET by night in all three, from pools in Duskwood; STRAY in Redridge; GONE
-- removed, on no list. Skill bases: Elwynn 25, Westfall 55, Duskwood 150; Redridge none.
local function fixture()
	local night = { time = { { 1200, 360 } } }
	local function fish(id, fields)
		local record = { category = "fish", species = id, legend = false, noise = false, removed = false, pool = false }
		for key, value in pairs(fields or {}) do
			record[key] = value
		end
		return record
	end
	local function area(skillBase, catches)
		return { parent = 0, continent = 0, hasData = true, skillBase = skillBase, skillBaseConfirmed = false, catches = catches }
	end
	local function entry(itemID, window)
		return { itemID = itemID, confirmed = false, window = window, gate = window and night, gateConfirmed = false }
	end
	return {
		fingerprint = "0123456789abcdef",
		items = {
			[MACKEREL] = fish(MACKEREL),
			[NIGHTFISH] = fish(NIGHTFISH, { pool = true }),
			[SECRET] = fish(SECRET, { pool = true }),
			[STRAY] = fish(STRAY),
			[GONE] = fish(GONE, { removed = true }),
		},
		areas = {
			[ELWYNN] = area(25, { entry(MACKEREL), entry(SECRET, "night") }),
			[WESTFALL] = area(55, { entry(MACKEREL), entry(SECRET, "night") }),
			[DUSKWOOD] = area(150, { entry(MACKEREL), entry(NIGHTFISH, "night"), entry(SECRET, "night") }),
			[REDRIDGE] = area(nil, { entry(STRAY) }),
		},
		aliases = {},
		pools = {},
		windows = { night = { spec = night, confirmed = false } },
		events = {},
		fishingSpells = {},
		auras = {},
	}
end

-- A caught Cast of one `itemID` by character 1 in `zone` at realm `minute`. The log works its realm date out from the
-- time and minute (LOG-R49): 3 Oct 2026 by day, 2 Oct by night.
local function cast(time, itemID, zone, minute)
	return {
		kind = "cast",
		char = 1,
		time = time,
		outcome = "caught",
		conditions = { minute = minute, zone = zone, subzone = 0, events = {}, auras = {} },
		items = { { itemID = itemID, quantity = 1 } },
	}
end

-- The fixture's log: MACKEREL first in Westfall on 3 March, then in Elwynn; NIGHTFISH at night in Elwynn; STRAY in
-- zone 0; GONE in Elwynn. SECRET is never caught.
local function log()
	return {
		cast(T0, MACKEREL, WESTFALL, DAY_MINUTE),
		cast(T0 + 60, MACKEREL, ELWYNN, DAY_MINUTE),
		cast(T0 + 120, NIGHTFISH, ELWYNN, NIGHT_MINUTE),
		cast(T0 + 180, STRAY, 0, DAY_MINUTE),
		cast(T0 + 240, GONE, ELWYNN, DAY_MINUTE),
	}
end

-- A Ledger on a fake over the fixture and its log, logged in with the projection built, every name loaded, and lore
-- for MACKEREL and SECRET only.
local function loggedIn()
	local fake = newFakePagle()
	fake.setCatalogue(fixture())
	fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
	for _, record in ipairs(log()) do
		fake.catchLog:Append(record)
	end
	local loaded = fake.load("Pagle_Ledger")
	for id, name in pairs(NAMES) do
		loaded.client.itemNames[id] = name
	end
	for zone, name in pairs(ZONES) do
		loaded.client.areaNames[zone] = name
	end
	local L = loaded.ns.L
	for key in pairs(L) do
		if type(key) == "string" and key:find("^species%.") then
			L[key] = nil
		end
	end
	L["species.6303.blurb"] = "Slippery enough to earn the name."
	L["species.6522.riddle"] = "Strange schools out on the dry plains."
	fake.login()
	fake.enterWorld()
	return fake, loaded
end

-- Opens the fish spread on Species `id` (with the plain hint open when `hint`).
local function openFish(loaded, id, hint)
	assert.is_true(loaded.ns.journal:Open("fish", { species = id, hint = hint }))
	return loaded.ns.journal.pages
end

-- The texts of a page's text blocks, in order.
local function textsOf(blocks)
	local texts = {}
	for _, block in ipairs(blocks) do
		if block.kind == "text" then
			texts[#texts + 1] = block.text
		end
	end
	return texts
end

-- A page's first block of `kind`.
local function first(blocks, kind)
	for _, block in ipairs(blocks) do
		if block.kind == kind then
			return block
		end
	end
	return nil
end

describe("a caught Species' entry (LED-R140)", function()
	it("shows its sepia icon, name, stamps, first Catch, blurb and listed zones (LED-R140)", function()
		local _, loaded = loggedIn()

		local left = openFish(loaded, MACKEREL).left

		assert.are.same({ kind = "icon", icon = MACKEREL, look = "sepia", large = true }, first(left, "icon"))
		assert.are.equal("Raw Slitherskin Mackerel", first(left, "title").text)
		assert.are.same({
			{ text = "Caught", inked = true },
			{ text = "In its element", inked = false },
			{ text = "Regular", inked = false },
		}, first(left, "stamps").stamps)
		assert.are.same({
			"First landed 3 Oct in Westfall, by Angler. 2 caught.",
			"Slippery enough to earn the name.",
			"Found in Duskwood, Elwynn Forest and Westfall.",
		}, textsOf(left))
	end)

	it('adds " Only by night." for a night-only fish, and leaves a missing blurb out (LED-R140, LED-R161)', function()
		local _, loaded = loggedIn()

		assert.are.same({
			"First landed 2 Oct in Elwynn Forest, by Angler. 1 caught.",
			"Found in Duskwood. Only by night.",
		}, textsOf(openFish(loaded, NIGHTFISH).left))
	end)

	it("drops the zone part for a first Catch in zone 0 (LED-R140, LED-R6)", function()
		local _, loaded = loggedIn()

		assert.are.equal("First landed 3 Oct, by Angler. 1 caught.", textsOf(openFish(loaded, STRAY).left)[1])
	end)

	it("shows the removed line, and no listed zones, for a removed one (LED-R140, LED-R12)", function()
		local _, loaded = loggedIn()

		assert.are.same({
			"First landed 3 Oct in Elwynn Forest, by Angler. 1 caught.",
			"No longer found in Forever's waters.",
		}, textsOf(openFish(loaded, GONE).left))
	end)
end)
