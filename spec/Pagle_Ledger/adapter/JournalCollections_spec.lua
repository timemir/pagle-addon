-- The Journal's collections on FakePagle (LED-R143, LED-R144, LED-R62, LED-R12, LED-R124, LED-R161): the Trophy Room
-- and Curios over a hand-made catalogue and a fixture log. Junk and treasure items use real item IDs, so their
-- plaques are the committed lore's (data/Lore.lua).

local ELWYNN, DUSKWOOD, WESTFALL = 12, 10, 40
-- Family 2 (Catfish in the lore) lists four weights in Elwynn, and has a removed fifth; family 1 (Mud Snapper) lists
-- one in Duskwood.
local CAT17, CAT19, CAT22, CAT26, CAT30, SNAPPER10 = 9017, 9019, 9022, 9026, 9030, 9010
-- The Junk Museum: an Old Skull and a Message in a Bottle listed, an Old Wagonwheel removed (DATA-R26).
local SKULL, BOTTLE, WAGONWHEEL = 6297, 6307, 6455
-- Treasures: a Dented Crate (container) and a Small Chest (treasure), listed.
local CRATE, CHEST = 6351, 6353
-- Items the catalogue doesn't know: Uncharted (LED-R64).
local ODD, STRANGE = 777001, 777002
local T0 = 1791731000 -- Sunday 11 October 2026, 15:03 UTC; realm minute 494 makes it 11 Oct on the realm too

-- A catalogue in the shape of ns.catalogue (DATA-R76): Elwynn and Duskwood charted, Westfall without data.
local function catalogue()
	local function item(category, fields)
		local record = { category = category, legend = false, noise = false, removed = false, pool = false }
		for key, value in pairs(fields or {}) do
			record[key] = value
		end
		return record
	end
	local function area(fields)
		local record = { parent = 0, continent = 0, hasData = true, skillBaseConfirmed = false, catches = {} }
		for key, value in pairs(fields) do
			record[key] = value
		end
		return record
	end
	local function listed(...)
		local catches = {}
		for i, itemID in ipairs({ ... }) do
			catches[i] = { itemID = itemID, confirmed = false }
		end
		return catches
	end
	return {
		fingerprint = "0123456789abcdef",
		items = {
			[CAT17] = item("trophy", { family = 2, weight = 17 }),
			[CAT19] = item("trophy", { family = 2, weight = 19 }),
			[CAT22] = item("trophy", { family = 2, weight = 22 }),
			[CAT26] = item("trophy", { family = 2, weight = 26 }),
			[CAT30] = item("trophy", { family = 2, weight = 30, removed = true }),
			[SNAPPER10] = item("trophy", { family = 1, weight = 10 }),
			[SKULL] = item("junk"),
			[BOTTLE] = item("junk"),
			[WAGONWHEEL] = item("junk", { removed = true }),
			[CRATE] = item("container"),
			[CHEST] = item("treasure"),
		},
		areas = {
			[ELWYNN] = area({ skillBase = 25, catches = listed(CAT26, CAT17, CAT22, CAT19, SKULL, CRATE) }),
			[DUSKWOOD] = area({ skillBase = 150, catches = listed(SNAPPER10, BOTTLE, CHEST) }),
			[WESTFALL] = area({ hasData = false }),
		},
		aliases = {},
		pools = {},
		windows = {},
		events = {},
		fishingSpells = {},
		auras = {},
	}
end

-- A caught Cast of `itemID` in `zone` at `time`.
local function cast(time, zone, itemID)
	return {
		kind = "cast",
		char = 1,
		time = time,
		outcome = "caught",
		conditions = { minute = 494, zone = zone, subzone = 0, events = {}, auras = {} },
		items = { { itemID = itemID, quantity = 1 } },
	}
end

-- The fixture log: two Catfish weights (17 and 22 lb) landed, the skull, the removed wagonwheel and the crate.
local FIXTURE = {
	cast(T0, ELWYNN, CAT17),
	cast(T0 + 60, ELWYNN, CAT22),
	cast(T0 + 120, ELWYNN, SKULL),
	cast(T0 + 180, ELWYNN, WAGONWHEEL),
	cast(T0 + 240, ELWYNN, CRATE),
}

-- The fake client's item and zone names.
local NAMES = {
	[SKULL] = "Old Skull",
	[BOTTLE] = "Message in a Bottle",
	[WAGONWHEEL] = "Old Wagonwheel",
	[CRATE] = "Dented Crate",
	[CHEST] = "Small Chest",
}
local ZONES = { [ELWYNN] = "Elwynn Forest", [DUSKWOOD] = "Duskwood", [WESTFALL] = "Westfall" }

-- A Ledger on a fake over the catalogue and `log` (the fixture by default), logged in, in the world, with the
-- Journal open on spread `id` with `args`.
---@param id string
---@param args table?
---@param log table[]?
---@return FakePagle fake
---@return LoadedAddon loaded
local function spread(id, args, log)
	local fake = newFakePagle()
	fake.setCatalogue(catalogue())
	fake.catchLog.data.characters = {
		{ guid = PLAYER_GUID, name = "Angler", classID = 1, raceID = 1, faction = "Alliance", realmID = 4618 },
	}
	for _, record in ipairs(log or FIXTURE) do
		fake.catchLog:Append(record)
	end
	fake.globals.BreakUpLargeNumbers = breakUpLargeNumbers
	local loaded = fake.load("Pagle_Ledger")
	for itemID, name in pairs(NAMES) do
		loaded.client.itemNames[itemID] = name
	end
	for areaID, name in pairs(ZONES) do
		loaded.client.areaNames[areaID] = name
	end
	fake.login()
	fake.enterWorld()
	assert.is_true(loaded.ns.journal:Open(id, args))
	return fake, loaded
end

-- The texts of a page's blocks, in order (a block without text as its kind in brackets).
---@param blocks LedgerBlock[]
---@return string[]
local function texts(blocks)
	local list = {}
	for i, block in ipairs(blocks) do
		list[i] = block.text or ("[" .. block.kind .. "]")
	end
	return list
end

-- The words a drawn widget shows, in the order its parts were made.
---@param widget table
---@param list string[]?
---@return string[]
local function textsOf(widget, list)
	list = list or {}
	for _, child in ipairs(widget.children) do
		if child.shown then
			if child.text ~= nil and child.text ~= "" then
				list[#list + 1] = child.text
			end
			textsOf(child, list)
		end
	end
	return list
end

describe("the Journal's Trophy Room", function()
	it(
		"lists each family by its lore name with its shown stars and its weights landed, x / N (LED-R143, LED-R47, LED-R48)",
		function()
			local _, loaded = spread("trophy")
			local left = loaded.ns.journal.pages.left

			assert.are.same({
				"The Trophy Room",
				"2 of 5 weights. Real weights, from the game's own trophy fish.",
				"Mud Snapper ☆☆☆",
				"Catfish ★★☆",
			}, texts(left))
			assert.are.same({ "0 / 1", "2 / 4" }, { left[3].value, left[4].value })
			assert.are.same({ id = "trophy", args = { family = 2 } }, left[4].place)
		end
	)

	it(
		"shows a family's stamps, a measuring board ticking the weights landed, and its heaviest so far (LED-R143, LED-R62)",
		function()
			local _, loaded = spread("trophy", { family = 2 })
			local right = loaded.ns.journal.pages.right

			assert.are.same({
				"Catfish",
				"[stamps]",
				"[board]",
				"pounds, as the game weighs them",
				"Landed 2 of 4. Heaviest so far: 22 lb.",
				"Found in Elwynn Forest.",
			}, texts(right))
			assert.are.same({
				{ text = "Any weight", inked = true },
				{ text = "Half the weights", inked = true },
				{ text = "The heaviest", inked = false },
			}, right[2].stamps)
			-- A tick per weight, placed along the board by its pounds (17 to 26), inked where landed.
			assert.are.same({
				{ text = "17", at = 0, inked = true },
				{ text = "19", at = 2 / 9, inked = false },
				{ text = "22", at = 5 / 9, inked = true },
				{ text = "26", at = 1, inked = false },
			}, right[3].ticks)
			assert.is_true(right[5].hand)
		end
	)

	it("opens on the first family by default, and says so when none of it is landed yet (LED-R143)", function()
		local _, loaded = spread("trophy")
		local right = loaded.ns.journal.pages.right

		assert.are.same({
			"Mud Snapper",
			"[stamps]",
			"[board]",
			"pounds, as the game weighs them",
			"Not one of this family yet.",
			"Found in Duskwood.",
		}, texts(right))
		assert.are.same({ { text = "10", at = 0.5, inked = false } }, right[3].ticks)
	end)

	it("is the spread Home ❧ The Trophy Room, whichever family it is open on (LED-R125)", function()
		local _, loaded = spread("trophy", { family = 2 })
		local pages = loaded.ns.journal.pages

		assert.are.same({ "Home", "The Trophy Room" }, { pages.crumbs[1].label, pages.crumbs[2].label })
		assert.are.same({ id = "trophy" }, pages.crumbs[2].place)
		assert.are.same({ id = "home" }, pages.back)
	end)

	it("opens a family from its index line (LED-R143)", function()
		local _, loaded = spread("trophy")
		local journal = loaded.ns.journal

		journal.frame.left.drawn.leader[2]:Click()

		assert.are.equal("Catfish", journal.pages.right[1].text)
	end)

	it(
		"leaves a removed weight out of both sides of every x of N and off the board, keeping its record (LED-R12)",
		function()
			local log = { unpack(FIXTURE) }
			log[#log + 1] = cast(T0 + 300, ELWYNN, CAT30)
			local _, loaded = spread("trophy", { family = 2 }, log)
			local pages = loaded.ns.journal.pages

			assert.are.equal("2 of 5 weights. Real weights, from the game's own trophy fish.", pages.left[2].text)
			assert.are.equal("2 / 4", pages.left[4].value)
			assert.are.equal(4, #pages.right[3].ticks)
			assert.are.equal("Landed 2 of 4. Heaviest so far: 30 lb.", pages.right[5].text)
		end
	)

	it("draws the measuring board: each weight in pounds, a ✓ over those landed (LED-R143, LED-R62)", function()
		local _, loaded = spread("trophy", { family = 2 })

		local board = loaded.ns.journal.frame.right.drawn.board[1]

		assert.are.same({ "✓", "17", "19", "✓", "22", "26" }, textsOf(board))
	end)
end)
