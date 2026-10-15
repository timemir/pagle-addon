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
local T0 = SERVER_TIME - 700 -- Sunday 11 October 2026, 15:03 UTC; realm minute 494 makes it 11 Oct on the realm too

-- A catalogue in the shape of ns.catalogue (DATA-R76): Elwynn and Duskwood charted, Westfall without data.
local function catalogue()
	local function listed(...)
		local catches = {}
		for i, itemID in ipairs({ ... }) do
			catches[i] = { itemID = itemID, confirmed = false }
		end
		return catches
	end
	return catalogueWith({
		items = {
			[CAT17] = itemRecord("trophy", { family = 2, weight = 17 }),
			[CAT19] = itemRecord("trophy", { family = 2, weight = 19 }),
			[CAT22] = itemRecord("trophy", { family = 2, weight = 22 }),
			[CAT26] = itemRecord("trophy", { family = 2, weight = 26 }),
			[CAT30] = itemRecord("trophy", { family = 2, weight = 30, removed = true }),
			[SNAPPER10] = itemRecord("trophy", { family = 1, weight = 10 }),
			[SKULL] = itemRecord("junk"),
			[BOTTLE] = itemRecord("junk"),
			[WAGONWHEEL] = itemRecord("junk", { removed = true }),
			[CRATE] = itemRecord("container"),
			[CHEST] = itemRecord("treasure"),
		},
		areas = {
			[ELWYNN] = areaRecord(0, { skillBase = 25, catches = listed(CAT26, CAT17, CAT22, CAT19, SKULL, CRATE) }),
			[DUSKWOOD] = areaRecord(0, { skillBase = 150, catches = listed(SNAPPER10, BOTTLE, CHEST) }),
			[WESTFALL] = areaRecord(0, { hasData = false }),
		},
	})
end

-- A caught Cast of `itemID` in `zone` at `time`.
local function cast(time, zone, itemID)
	return castRecord({ time = time, zone = zone, items = { itemID } })
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
-- Journal open at `place` (openJournal's: an ns.JournalPlace constructor and its args).
---@param place table
---@param log table[]?
---@return FakePagle fake
---@return LoadedAddon loaded
local function spread(place, log)
	return openJournal({
		catalogue = catalogue(),
		log = log or FIXTURE,
		itemNames = NAMES,
		areaNames = ZONES,
		place = place,
	})
end

-- Curios' right page from its "Loose pages: Uncharted" kicker on.
---@param right LedgerBlock[]
---@return LedgerBlock[]
local function loosePages(right)
	for i, block in ipairs(right) do
		if block.text == "Loose pages: Uncharted" then
			return { unpack(right, i) }
		end
	end
	return {}
end

describe("the Journal's Trophy Room", function()
	it(
		"lists each family by its lore name with its shown stars and its weights landed, x / N (LED-R143, LED-R47, LED-R48)",
		function()
			local _, loaded = spread({ "trophyRoom" })
			local left = loaded.ns.journal.pages.left

			assert.are.same({
				"The Trophy Room",
				"2 of 5 weights.",
				drawnSymbols("Mud Snapper ☆☆☆"),
				drawnSymbols("Catfish ★★☆"),
			}, blockTexts(left))
			assert.are.same({ "0 / 1", "2 / 4" }, { left[3].value, left[4].value })
			assert.are.same({ id = "trophy", args = { family = 2 } }, left[4].place)
		end
	)

	it(
		"shows a family's stamps, a measuring board ticking the weights landed, and its heaviest so far (LED-R143, LED-R62)",
		function()
			local _, loaded = spread({ "trophyRoom", 2 })
			local right = loaded.ns.journal.pages.right

			assert.are.same({
				"Catfish",
				"[stamps]",
				"[board]",
				"pounds",
				"Landed 2 of 4. Heaviest so far: 22 lb.",
				"Found in Elwynn Forest.",
			}, blockTexts(right))
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
		local _, loaded = spread({ "trophyRoom" })
		local right = loaded.ns.journal.pages.right

		assert.are.same({
			"Mud Snapper",
			"[stamps]",
			"[board]",
			"pounds",
			"Not one of this family yet.",
			"Found in Duskwood.",
		}, blockTexts(right))
		assert.are.same({ { text = "10", at = 0.5, inked = false } }, right[3].ticks)
	end)

	it("leaves out the index line and the title of a family whose lore name has no text (LED-R161)", function()
		local _, loaded = spread({ "trophyRoom" })
		-- Mud Snapper (family 1) before the Ledger's lore check turns on: its key has no text.
		loaded.ns.L["family.1.name"] = nil
		loaded.ns.journal:Draw()
		local pages = loaded.ns.journal.pages

		assert.are.same({
			"The Trophy Room",
			"2 of 5 weights.",
			drawnSymbols("Catfish ★★☆"),
		}, blockTexts(pages.left))
		assert.are.same({
			"[stamps]",
			"[board]",
			"pounds",
			"Not one of this family yet.",
			"Found in Duskwood.",
		}, blockTexts(pages.right))
	end)

	it("is the spread Home ❧ The Trophy Room, whichever family it is open on (LED-R125)", function()
		local _, loaded = spread({ "trophyRoom", 2 })
		local pages = loaded.ns.journal.pages

		assert.are.same({ "Home", "The Trophy Room" }, { pages.crumbs[1].label, pages.crumbs[2].label })
		assert.are.same({ id = "trophy" }, pages.crumbs[2].place)
		assert.are.same({ id = "home" }, pages.back)
	end)

	it("opens a family from its index line (LED-R143)", function()
		local _, loaded = spread({ "trophyRoom" })
		local journal = loaded.ns.journal

		journal.frame.left.drawn.leader[2]:Click()

		assert.are.equal("Catfish", journal.pages.right[1].text)
	end)

	it(
		"keeps the index's scroll as a family opens, starting the family's page at the top (LED-R129, LED-R143)",
		function()
			local _, loaded = spread({ "trophyRoom" })
			scrollPage(loaded, "left", 120)
			scrollPage(loaded, "right", 80)

			loaded.ns.journal.frame.left.drawn.leader[2]:Click()

			assert.are.equal("Catfish", loaded.ns.journal.pages.right[1].text)
			assert.are.same({ 120, 0 }, { pageScroll(loaded, "left"), pageScroll(loaded, "right") })
		end
	)

	it(
		"leaves a removed weight out of both sides of every x of N, off the board and out of the heaviest so far (LED-R12, LED-R143)",
		function()
			local log = { unpack(FIXTURE) }
			log[#log + 1] = cast(T0 + 300, ELWYNN, CAT30)
			local _, loaded = spread({ "trophyRoom", 2 }, log)
			local pages = loaded.ns.journal.pages

			assert.are.equal("2 of 5 weights.", pages.left[2].text)
			assert.are.equal("2 / 4", pages.left[4].value)
			assert.are.equal(4, #pages.right[3].ticks)
			assert.are.equal("Landed 2 of 4. Heaviest so far: 22 lb.", pages.right[5].text)
		end
	)

	it("reads Not one of this family yet when only a removed weight of it is landed (LED-R12, LED-R143)", function()
		local _, loaded = spread({ "trophyRoom", 2 }, { cast(T0, ELWYNN, CAT30) })

		assert.are.equal("Not one of this family yet.", loaded.ns.journal.pages.right[5].text)
	end)

	it("draws the measuring board: each weight in pounds, a ✓ over those landed (LED-R143, LED-R62)", function()
		local _, loaded = spread({ "trophyRoom", 2 })

		local board = loaded.ns.journal.frame.right.drawn.board[1]

		assert.are.same({ drawnSymbols("✓"), "17", "19", drawnSymbols("✓"), "22", "26" }, shownTexts(board))
	end)
end)

describe("the Journal's Curios", function()
	it("is the spread Home ❧ Curios (LED-R125)", function()
		local _, loaded = spread({ "curios" })
		local pages = loaded.ns.journal.pages

		assert.are.same({ "Home", "Curios" }, { pages.crumbs[1].label, pages.crumbs[2].label })
		assert.are.same({ id = "curios" }, pages.crumbs[2].place)
		assert.are.same({ id = "home" }, pages.back)
	end)

	it(
		"shows the Junk Museum: a plinth per junk item, caught with its icon, name and plaque, uncaught empty (LED-R144, LED-R124, LED-R12)",
		function()
			local _, loaded = spread({ "curios" })
			local left = loaded.ns.journal.pages.left

			-- The removed wagonwheel keeps its plinth but is out of both sides of the count.
			assert.are.same({ "The Junk Museum", "1 of 2 exhibits" }, { left[1].text, left[2].text })
			assert.are.same({
				{
					kind = "plinth",
					icon = SKULL,
					look = "sepia",
					text = "Old Skull",
					value = "Donated by the water. Owner unknown, and preferably staying that way.",
				},
				{
					kind = "plinth",
					icon = BOTTLE,
					look = "silhouette",
					text = "An empty plinth",
					value = "The plinth is dusted and ready. The exhibit is late.",
				},
				{
					kind = "plinth",
					icon = WAGONWHEEL,
					look = "sepia",
					text = "Old Wagonwheel",
					value = "Where the wagon went is still under investigation.",
				},
			}, { left[3], left[4], left[5] })
			assert.are.equal(5, #left)
		end
	)

	it("leaves an empty plinth's lore line out while its key has no text (LED-R161)", function()
		local _, loaded = spread({ "curios" })

		loaded.ns.L["line.uncaughtjunk.text"] = nil
		loaded.ns.journal:Draw()

		local plinth = loaded.ns.journal.pages.left[4]
		assert.are.same({ "silhouette", "An empty plinth" }, { plinth.look, plinth.text })
		assert.is_nil(plinth.value)
	end)

	it("draws an empty plinth's icon as a silhouette, with its words (LED-R144, LED-R124)", function()
		local _, loaded = spread({ "curios" })

		local plinths = loaded.ns.journal.frame.left.drawn.plinth

		assert.are.same(
			{ "An empty plinth", "The plinth is dusted and ready. The exhibit is late." },
			shownTexts(plinths[2])
		)
		assert.are.same({ 0, 0, 0 }, plinths[2].texture.vertexColor)
		assert.are_not.same({ 0, 0, 0 }, plinths[1].texture.vertexColor)
	end)

	it(
		"shows Treasures: each container or treasure item, caught by name and plaque, uncaught by the lore line (LED-R144)",
		function()
			local _, loaded = spread({ "curios" })
			local right = loaded.ns.journal.pages.right

			assert.are.same({
				"Treasures",
				"1 of 2 opened",
				"Dented Crate",
				"Dropped once, by the look of it, and then again for good measure.",
				"Something sealed, not yet found.",
				"Loose pages: Uncharted",
				"None. Every catch is in the Ledger.",
				"Help chart the waters",
			}, blockTexts(right))
		end
	)

	it("never names an uncaught curio anywhere on the spread (LED-R124)", function()
		local _, loaded = spread({ "curios" })

		for _, side in ipairs({ "left", "right" }) do
			for _, text in ipairs(shownTexts(loaded.ns.journal.frame[side])) do
				assert.is_nil(text:find("Message in a Bottle", 1, true))
				assert.is_nil(text:find("Small Chest", 1, true))
			end
		end
	end)

	it(
		"writes a loose page per Uncharted item by first Catch: Item {id} until its name loads, its zones or unknown waters (LED-R144, LED-R64, LED-R126)",
		function()
			local log = {
				cast(T0, 0, STRANGE),
				cast(T0 + 60, ELWYNN, ODD),
				cast(T0 + 120, DUSKWOOD, ODD),
				cast(T0 + 180, ELWYNN, ODD),
			}
			local _, loaded = spread({ "curios" }, log)
			local pages = loosePages(loaded.ns.journal.pages.right)

			assert.are.same({
				"Loose pages: Uncharted",
				"Item 777002: 1× at unknown waters, first 11 Oct. Unknown to Pagle. Logged.",
				"Item 777001: 3× at Duskwood, Elwynn Forest, first 11 Oct. Unknown to Pagle. Logged.",
				"Help chart the waters",
			}, blockTexts(pages))
			assert.is_true(pages[2].hand and pages[3].hand)
		end
	)

	it("names an Uncharted item once the client has loaded it (LED-R126)", function()
		local _, loaded = spread({ "curios" }, { cast(T0, ELWYNN, ODD) })

		loaded.client.itemNames[ODD] = "Curious Pebble"
		loaded.ns.journal:Draw()

		assert.are.equal(
			"Curious Pebble: 1× at Elwynn Forest, first 11 Oct. Unknown to Pagle. Logged.",
			loosePages(loaded.ns.journal.pages.right)[2].text
		)
	end)

	it("opens the Field report from Help chart the waters (LED-R144, REP-R43)", function()
		local fake, loaded = spread({ "curios" })
		local links = loaded.ns.journal.frame.right.drawn.link

		links[#links]:Click()

		assert.are.equal(1, #fake.fieldReportsOpened)
	end)

	it("prints Core's line instead while restricted, the Journal still open (LED-R121, REP-R44)", function()
		local fake, loaded = spread({ "curios" })
		fake.setRestricted(true)
		local links = loaded.ns.journal.frame.right.drawn.link

		links[#links]:Click()

		assert.are.same({}, fake.fieldReportsOpened)
		assert.are.same({ "Pagle: the Field report opens after combat." }, fake.printed)
		assert.is_true(loaded.ns.journal:IsShown())
	end)
end)

describe("the Journal's ways into the collections", function()
	-- Clicks the drawn leader on Home's right page whose words begin with `label`.
	local function clickContents(loaded, label)
		for _, leader in ipairs(loaded.ns.journal.frame.right.drawn.leader) do
			if shownTexts(leader)[1] == label then
				leader:Click()
				return
			end
		end
		error("no contents line " .. label)
	end

	it("opens the Trophy Room and Curios from Home's contents (LED-R132, LED-R125)", function()
		local _, loaded = spread({ "home" })
		local journal = loaded.ns.journal

		clickContents(loaded, "The Trophy Room")
		assert.are.same({ "Home", "The Trophy Room" }, { journal.pages.crumbs[1].label, journal.pages.crumbs[2].label })

		journal:OpenPlace(loaded.ns.JournalPlace.home())
		clickContents(loaded, "Curios: junk, treasure, uncharted")
		assert.are.same({ "Home", "Curios" }, { journal.pages.crumbs[1].label, journal.pages.crumbs[2].label })
	end)
end)
