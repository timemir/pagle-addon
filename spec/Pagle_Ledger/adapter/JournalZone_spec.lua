-- The Journal's zone spread on FakePagle (LED-R135–R138, LED-R124–R127): a charted zone's ladder and groups, its
-- Species rows with live window states, "About these waters", and an uncharted zone's loose pages, over a hand-made
-- catalogue and a fixture log.

-- Darkshore's list: Mackerel (any time), Blackmouth (pools), Firefin (pools, but gated at night), Nightfin (night),
-- Summer Bass (summer) and Tastyfish (the Extravaganza), a Catfish and a Redgill trophy, a skull (junk) and a crate
-- (treasure). Elwynn's: Smallfish, Mud Snapper and a heavier Catfish. Stormwind has no data.
local MACKEREL, BLACKMOUTH, FIREFIN, NIGHTFIN, BASS, TASTYFISH = 6303, 6358, 6359, 13759, 13756, 19807
local SMALLFISH, MUD_SNAPPER = 6291, 6289
local CATFISH_17, CATFISH_22, REDGILL_34 = 6309, 6311, 13901
local SKULL, CRATE = 6297, 6351
local UNKNOWN = 99999 -- an item the catalogue doesn't know: Uncharted (LED-R64)
local DARKSHORE, ELWYNN, STORMWIND = 148, 12, 1519
local T0 = SERVER_TIME - 700 -- Sunday 11 October 2026, 15:03 UTC
local MINUTE = 60

-- Night is 20:00 to 06:00 realm time, so at the fake's realm 08:15 it opens in 11 h 45 min (LED-R127).
local NIGHT = { time = { { 1200, 360 } } }
local SUMMER = { season = { { from = { 3, 20 }, to = { 9, 18 } } } }
local EXTRAVAGANZA = { events = { 301 } }

-- A catalogue in the shape of ns.catalogue (DATA-R76).
local function catalogue()
	local function listed(itemID, window, gate)
		return { itemID = itemID, confirmed = false, window = window, gate = gate, gateConfirmed = gate and false }
	end
	return catalogueWith({
		items = {
			[MACKEREL] = fishRecord(MACKEREL),
			[BLACKMOUTH] = fishRecord(BLACKMOUTH, { pool = true }),
			[FIREFIN] = fishRecord(FIREFIN, { pool = true }),
			[NIGHTFIN] = fishRecord(NIGHTFIN),
			[BASS] = fishRecord(BASS),
			[TASTYFISH] = fishRecord(TASTYFISH),
			[SMALLFISH] = fishRecord(SMALLFISH),
			[MUD_SNAPPER] = fishRecord(MUD_SNAPPER),
			[CATFISH_17] = itemRecord("trophy", { family = 2, weight = 17 }),
			[CATFISH_22] = itemRecord("trophy", { family = 2, weight = 22 }),
			[REDGILL_34] = itemRecord("trophy", { family = 4, weight = 34 }),
			[SKULL] = itemRecord("junk"),
			[CRATE] = itemRecord("container"),
		},
		areas = {
			[DARKSHORE] = areaRecord(0, {
				continent = 1,
				skillBase = 75,
				catches = {
					listed(MACKEREL),
					listed(BLACKMOUTH),
					listed(FIREFIN, "night", NIGHT),
					listed(NIGHTFIN, "night", NIGHT),
					listed(BASS, "summer", SUMMER),
					listed(TASTYFISH, "event.301", EXTRAVAGANZA),
					listed(CATFISH_17),
					listed(REDGILL_34),
					listed(SKULL),
					listed(CRATE),
				},
			}),
			[ELWYNN] = areaRecord(0, {
				skillBase = 25,
				catches = { listed(SMALLFISH), listed(MUD_SNAPPER), listed(CATFISH_22) },
			}),
			[STORMWIND] = areaRecord(0, { hasData = false }),
		},
		windows = {
			night = { spec = NIGHT, confirmed = false },
			summer = { spec = SUMMER, confirmed = false },
			["event.301"] = { spec = EXTRAVAGANZA, confirmed = false },
		},
	})
end

-- A caught Cast of `itemIDs` in `zone` at `time`, by the fake client's character.
local function cast(time, zone, itemIDs)
	return castRecord({ time = time, zone = zone, items = itemIDs })
end

-- The fixture log: in Darkshore, Mackerel, Blackmouth, the 17 lb Catfish and the skull, and Smallfish (on Elwynn's
-- list, not Darkshore's); in Elwynn, Nightfin; in Stormwind, Mackerel, the crate and the unknown item twice.
local FIXTURE = {
	cast(T0, DARKSHORE, { MACKEREL }),
	cast(T0 + 60, DARKSHORE, { BLACKMOUTH, CATFISH_17 }),
	cast(T0 + 120, DARKSHORE, { SKULL, SMALLFISH }),
	cast(T0 + 180, ELWYNN, { NIGHTFIN }),
	cast(T0 + 240, STORMWIND, { MACKEREL, CRATE, UNKNOWN }),
	cast(T0 + 300, STORMWIND, { UNKNOWN }),
}

-- The names the fake client knows (LED-R126).
local ITEM_NAMES = {
	[MACKEREL] = "Raw Slitherskin Mackerel",
	[BLACKMOUTH] = "Oily Blackmouth",
	[FIREFIN] = "Firefin Snapper",
	[NIGHTFIN] = "Raw Nightfin Snapper",
	[BASS] = "Raw Summer Bass",
	[TASTYFISH] = "Speckled Tastyfish",
	[SMALLFISH] = "Raw Brilliant Smallfish",
	[CATFISH_17] = "17 Pound Catfish",
	[SKULL] = "Old Skull",
	[CRATE] = "Dented Crate",
}

-- A Ledger on a fake over the catalogue and `log` (the fixture by default), logged in, in the world, with the names
-- above, and the book open on zone `zone`'s spread.
---@param zone integer
---@param log table[]?
---@return FakePagle fake
---@return LoadedAddon loaded
local function zoneSpread(zone, log)
	return openJournal({
		catalogue = catalogue(),
		log = log or FIXTURE,
		itemNames = ITEM_NAMES,
		areaNames = { [DARKSHORE] = "Darkshore", [ELWYNN] = "Elwynn Forest", [STORMWIND] = "Stormwind City" },
		mapNames = { [1414] = "Kalimdor", [1415] = "Eastern Kingdoms" },
		place = { "zone", zone },
	})
end

-- The crumbs' labels.
local function crumbLabels(loaded)
	local labels = {}
	for i, crumb in ipairs(loaded.ns.journal.pages.crumbs) do
		labels[i] = crumb.label
	end
	return labels
end

describe("the Journal's zone spread", function()
	describe("for a charted zone", function()
		it(
			"lists the catches in groups, in order, each headed with its counts, the Pools note, a gated pool-associated Species in its window's group, and no empty group (LED-R135)",
			function()
				local _, loaded = zoneSpread(DARKSHORE)
				local left = blockTexts(loaded.ns.journal.pages.left)

				assert.are.same({
					"Kalimdor",
					"Darkshore",
					"Local",
					"[ladder]",
					"Next: Expert: 4 more day, night, seasonal or event catches, a treasure",
					"Any time · 1 / 1",
					"Raw Slitherskin Mackerel",
					"Pools · 1 / 1",
					"open water and pools combined",
					"Oily Blackmouth",
					"Day and night · 0 / 2",
					"— unknown —",
					"Raw Nightfin Snapper (caught elsewhere)",
					"Seasonal · 0 / 1",
					"— unknown —",
					"Events · 0 / 1",
					"— unknown —",
					"Trophies · 1 / 2",
					drawnSymbols("☑ a Catfish trophy, any weight"),
					drawnSymbols("☐ a Redgill trophy, any weight"),
					"Curios · 1 / 2",
					drawnSymbols("☑ a piece of junk"),
					drawnSymbols("☐ a treasure"),
					"Also caught here · 1",
					"Raw Brilliant Smallfish",
					"Not in Pagle's list for these waters yet.",
					"Help chart the waters",
				}, left)
			end
		)

		it(
			'draws an uncaught Species as a silhouette reading "— unknown —", never its name (LED-R136, LED-R124)',
			function()
				local _, loaded = zoneSpread(DARKSHORE)
				local firefin = loaded.ns.journal.pages.left[12]

				assert.are.same({ "row", FIREFIN, "silhouette", "— unknown —" }, {
					firefin.kind,
					firefin.icon,
					firefin.look,
					firefin.text,
				})
				assert.is_nil(firefin.stars)
			end
		)

		it(
			'reads "(caught elsewhere)" for a Species caught only in another zone, in sepia and without stars (LED-R136)',
			function()
				local _, loaded = zoneSpread(DARKSHORE)
				local nightfin = blockWithText(loaded.ns.journal.pages.left, "Raw Nightfin Snapper (caught elsewhere)")

				assert.are.equal("sepia", nightfin.look)
				assert.is_nil(nightfin.stars)
			end
		)

		it("shows a Species caught here with its shown stars and no margin when ungated (LED-R136, LED-R48)", function()
			local _, loaded = zoneSpread(DARKSHORE)
			local mackerel = blockWithText(loaded.ns.journal.pages.left, "Raw Slitherskin Mackerel")

			-- Listed in Darkshore alone, so caught in one zone is ★★ (LED-R45).
			assert.are.same({ [1] = true, [2] = true }, mackerel.stars)
			assert.is_nil(mackerel.margin)
		end)

		it(
			'notes each window here as "{label}, {state}" and "pools" for a pool-associated Species, in the margin (LED-R136, LED-R127)',
			function()
				local _, loaded = zoneSpread(DARKSHORE)
				local left = loaded.ns.journal.pages.left

				-- Realm 08:15 on 11 October: night opens at 20:00, 11 h 45 min away; summer is back in March; the
				-- Extravaganza has no weekly rule in this catalogue, so no state (LED-R127).
				assert.are.same({ "night, back in 12 h", "pools" }, left[12].margin)
				assert.are.same({ "night, back in 12 h" }, left[13].margin)
				assert.are.same({ "summer, back in March" }, left[15].margin)
				assert.are.same({ "Extravaganza" }, left[17].margin)
				assert.are.same({ "pools" }, blockWithText(left, "Oily Blackmouth").margin)
			end
		)

		it(
			'reads a night-gated Species\' margin live: "back in {n} h" at realm 08:15, "biting now" when drawn again in the night (LED-R127, LED-R195)',
			function()
				local fake, loaded = zoneSpread(DARKSHORE)
				local function nightfin()
					return blockWithText(loaded.ns.journal.pages.left, "Raw Nightfin Snapper (caught elsewhere)").margin[1]
				end
				assert.are.equal("night, back in 12 h", nightfin())

				-- Realm 20:15: the realm clock and the server's both move on 12 h.
				local snapshot = {}
				for key, value in pairs(fake.conditions) do
					snapshot[key] = value
				end
				snapshot.time = snapshot.time + 12 * 60 * MINUTE
				snapshot.minute = (snapshot.minute + 12 * 60) % 1440
				fake.setConditions(snapshot)
				loaded.env.GetServerTime = function()
					return snapshot.time
				end
				loaded.env.GetGameTime = function()
					return math.floor(snapshot.minute / 60), snapshot.minute % 60
				end
				loaded.ns.journal:Draw()

				assert.are.equal("night, biting now", nightfin())
			end
		)

		it("inks the ranks reached on the ladder and circles the shown one (LED-R135, LED-R52)", function()
			local _, loaded = zoneSpread(DARKSHORE)

			local ladder = loaded.ns.journal.pages.left[4]
			assert.are.same({
				{ text = "Visitor", inked = true, circled = false },
				{ text = "Regular", inked = true, circled = false },
				{ text = "Local", inked = true, circled = true },
				{ text = "Expert", inked = false, circled = false },
				{ text = "Master", inked = false, circled = false },
			}, ladder.rungs)
		end)

		it(
			'shows a celebrated rank above the computed one on the seal and ladder, with "{N} new to find here! My seal stays." (LED-R135, LED-R52, LED-R134)',
			function()
				local _, loaded = zoneSpread(DARKSHORE)

				loaded.env.PagleLedgerDB.global.celebrated.zones[DARKSHORE] = 4
				loaded.ns.journal:Draw()

				-- Expert shown, Local computed: Expert lacks the 4 gated Species and the treasure (LED-R52).
				local left = loaded.ns.journal.pages.left
				assert.are.same({ "Expert", "Expert" }, { left[3].text, left[4].rungs[4].text })
				assert.is_true(left[4].rungs[4].circled)
				assert.are.equal(
					"Next: Master: a trophy from 1 more family · 5 new to find: the data grew, and your seal stays",
					left[5].text
				)
				assert.are.same({ "text", "5 new to find here! My seal stays.", true }, {
					left[6].kind,
					left[6].text,
					left[6].hand,
				})
			end
		)

		it('seals an unfished zone "unfished", with nothing on the ladder inked (LED-R135, LED-R134)', function()
			local _, loaded = zoneSpread(ELWYNN, { FIXTURE[1] })
			local left = loaded.ns.journal.pages.left

			assert.are.same({
				"Eastern Kingdoms",
				"Elwynn Forest",
				"unfished",
				"[ladder]",
				"Next: Catch anything here to become a Visitor",
				"Any time · 0 / 2",
				"— unknown —",
				"— unknown —",
				"Trophies · 0 / 1",
				drawnSymbols("☐ a Catfish trophy, any weight"),
			}, blockTexts(left))
			for _, rung in ipairs(left[4].rungs) do
				assert.is_false(rung.inked or rung.circled)
			end
		end)
	end)

	describe("on the book", function()
		it(
			"draws a row's name, its margin in handwriting and its three stars, inked or blank (LED-R136, ledger.md › UI)",
			function()
				local _, loaded = zoneSpread(DARKSHORE)
				local rows = loaded.ns.journal.frame.left.drawn.row

				-- Blackmouth: pools, ★★ of three.
				assert.are.same(
					{ "Oily Blackmouth", "pools", drawnSymbols("★★☆") },
					{ rows[2].name.text, rows[2].margin.text, rows[2].stars.text }
				)
				assert.are.same({ "night, back in 12 h · pools", false }, { rows[3].margin.text, rows[3].stars.shown })
				assert.is_true(rows[3].icon.desaturated)
				assert.are.same({ 0, 0, 0 }, rows[3].icon.vertexColor)
			end
		)

		it("draws the ladder's ranks with the shown one boxed in red (LED-R135)", function()
			local _, loaded = zoneSpread(DARKSHORE)
			local ladder = loaded.ns.journal.frame.left.drawn.ladder[1]

			-- Each rung is a frame holding its word and the four edges of its box.
			local words, boxed = {}, {}
			for _, rung in ipairs(ladder.children) do
				if rung.kind == "Frame" then
					local edges = 0
					for _, part in ipairs(rung.children) do
						if part.kind == "FontString" then
							words[#words + 1] = part.text
						elseif part.shown then
							edges = edges + 1
						end
					end
					boxed[#boxed + 1] = edges
				end
			end
			assert.are.same({ "Visitor", "Regular", "Local", "Expert", "Master" }, words)
			assert.are.same({ 0, 0, 4, 0, 0 }, boxed)
		end)
	end)

	describe("for a zone that isn't charted", function()
		it(
			"shows its name, the uncharted waters lore line and the note on the left; its loose pages and what else was caught on the right (LED-R138, LED-R64)",
			function()
				local _, loaded = zoneSpread(STORMWIND)
				local pages = loaded.ns.journal.pages

				assert.are.same({ "Home", "Eastern Kingdoms", "Stormwind City" }, crumbLabels(loaded))
				assert.are.same({
					"Stormwind City",
					"Uncharted waters. No map of these yet.",
					"Every catch here is still written down, and counted once Pagle's data catches up.",
				}, blockTexts(pages.left))
				-- The unknown item's name isn't loaded: "Item {id}" (LED-R126).
				assert.are.same({
					"Loose pages",
					"Item 99999: 2×",
					"Also caught here",
					"Raw Slitherskin Mackerel",
					"Dented Crate",
					"Help chart the waters",
				}, blockTexts(pages.right))
			end
		)

		it("draws its Species caught as rows without a margin, with their stars (LED-R138, LED-R136)", function()
			local _, loaded = zoneSpread(STORMWIND)
			local mackerel = blockWithText(loaded.ns.journal.pages.right, "Raw Slitherskin Mackerel")

			assert.are.same({ "row", "sepia" }, { mackerel.kind, mackerel.look })
			assert.is_nil(mackerel.margin)
			assert.are.same({ [1] = true, [2] = true }, mackerel.stars)
		end)

		it('reads "Nothing caught here yet." with nothing caught there (LED-R138)', function()
			local _, loaded = zoneSpread(STORMWIND, { FIXTURE[1] })

			assert.are.same(
				{ "Loose pages", "Also caught here", "Nothing caught here yet.", "Help chart the waters" },
				blockTexts(loaded.ns.journal.pages.right)
			)
		end)

		it("leaves the lore line out while it has no text (LED-R138, LED-R161)", function()
			local _, loaded = zoneSpread(STORMWIND)

			loaded.ns.L["line.unchartedwaters.text"] = nil
			loaded.ns.journal:Draw()

			assert.are.same({
				"Stormwind City",
				"Every catch here is still written down, and counted once Pagle's data catches up.",
			}, blockTexts(loaded.ns.journal.pages.left))
		end)

		it("opens the Field report from its Help chart the waters link (LED-R138, REP-R43)", function()
			local fake, loaded = zoneSpread(STORMWIND)

			loaded.ns.journal.frame.right.drawn.link[1]:Click()

			assert.are.equal(1, #fake.fieldReportsOpened)
		end)

		it("prints Core's line from the link while restricted, opening nothing (LED-R121, REP-R44)", function()
			local fake, loaded = zoneSpread(STORMWIND)
			fake.setRestricted(true)

			loaded.ns.journal.frame.right.drawn.link[1]:Click()

			assert.are.same({}, fake.fieldReportsOpened)
			assert.are.equal("Pagle: the Field report opens after combat.", fake.printed[#fake.printed])
		end)
	end)

	it("opens the Field report from a charted zone's Also caught here link (LED-R135, REP-R43)", function()
		local fake, loaded = zoneSpread(DARKSHORE)

		loaded.ns.journal.frame.left.drawn.link[1]:Click()

		assert.are.equal(1, #fake.fieldReportsOpened)
	end)

	it("is where a Home tile leads, and its continent crumb opens Home on that tab (LED-R131, LED-R125)", function()
		local _, loaded = zoneSpread(DARKSHORE)
		local journal = loaded.ns.journal
		journal.frame.crumbButtons[2]:Click()

		-- Home on the Kalimdor tab, whose one tile is Darkshore's.
		local tabs = {}
		for _, block in ipairs(journal.pages.left) do
			for _, tab in ipairs(block.tabs or {}) do
				tabs[#tabs + 1] = tab.text .. (tab.on and " (on)" or "")
			end
		end
		assert.are.same({ "Eastern Kingdoms", "Kalimdor (on)" }, tabs)
		local tile = journal.frame.left.drawn.tiles[1].children[1]
		assert.are.equal("Darkshore", tile.name.text)
		tile:Click()

		assert.are.same({ id = "zone", args = { zone = DARKSHORE } }, journal.router:Place())
		assert.are.same({ "Home", "Kalimdor", "Darkshore" }, crumbLabels(loaded))
	end)

	describe("with a fish selected", function()
		-- Clicks Species row `i` of the left page, as drawn.
		local function clickRow(loaded, i)
			loaded.ns.journal.frame.left.drawn.row[i]:Click()
		end

		it(
			"selects a row on a click: the crumbs add it and the right page shows its entry (LED-R136, LED-R125, LED-R140)",
			function()
				local _, loaded = zoneSpread(DARKSHORE)

				clickRow(loaded, 1)

				local pages = loaded.ns.journal.pages
				assert.are.same({ "Home", "Kalimdor", "Darkshore", "Raw Slitherskin Mackerel" }, crumbLabels(loaded))
				assert.are.same({ id = "zone", args = { zone = DARKSHORE, species = MACKEREL } }, pages.crumbs[4].place)
				assert.is_true(pages.left[7].selected)
				assert.is_nil(pages.left[10].selected)
				local right = blockTexts(pages.right)
				assert.are.same({ "[icon]", "Raw Slitherskin Mackerel", "[stamps]" }, { right[1], right[2], right[3] })
			end
		)

		it(
			'names an uncaught fish selected nowhere: the crumb and entry read "An unknown fish" and the hint opens in place (LED-R124, LED-R141)',
			function()
				local _, loaded = zoneSpread(DARKSHORE)

				clickRow(loaded, 3)

				local pages = loaded.ns.journal.pages
				assert.are.equal("An unknown fish", pages.crumbs[4].label)
				local link = blockWithText(pages.right, "Read the plain hint »")
				assert.are.same(
					{ id = "zone", args = { zone = DARKSHORE, species = FIREFIN, hint = true } },
					link.place
				)

				loaded.ns.journal.frame.right.drawn.link[1]:Click()

				-- night · pools · Darkshore · skill ~75 (DATA-R112).
				local right = loaded.ns.journal.pages.right
				assert.are.equal("night · pools · Darkshore · skill ~75", right[#right].text)
				assert.are.equal("An unknown fish", loaded.ns.journal.pages.crumbs[4].label)
			end
		)

		it("goes back one crumb at a time: to the zone, then to Home on its continent's tab (LED-R125)", function()
			local _, loaded = zoneSpread(DARKSHORE)
			clickRow(loaded, 1)
			local journal = loaded.ns.journal

			journal.frame.back:Click()

			assert.are.same({ id = "zone", args = { zone = DARKSHORE } }, journal.router:Place())
			assert.are.same({ "Home", "Kalimdor", "Darkshore" }, crumbLabels(loaded))
			assert.are.equal("About these waters", journal.pages.right[1].text)

			journal.frame.back:Click()

			assert.are.same({ id = "home", args = { tab = 1 } }, journal.router:Place())
			assert.are.same({ "Home" }, crumbLabels(loaded))
		end)

		it("redraws on the next frame after a live Catch, keeping the selection (LED-R123)", function()
			local fake, loaded = zoneSpread(DARKSHORE)
			clickRow(loaded, 3)

			-- The fake fishes in Darkshore (148).
			fake.playCast("caught", { { itemID = FIREFIN, quantity = 1 } })
			loaded.client.runTimers()

			local pages = loaded.ns.journal.pages
			assert.are.same({ "Home", "Kalimdor", "Darkshore", "Firefin Snapper" }, crumbLabels(loaded))
			assert.are.equal("Day and night · 1 / 2", pages.left[11].text)
			assert.are.same({ "Firefin Snapper", true }, { pages.left[12].text, pages.left[12].selected })
			assert.are.equal("Firefin Snapper", pages.right[2].text)
		end)

		it("is where the fish spread's tiles lead, with that fish selected (LED-R142, LED-R136)", function()
			local _, loaded = zoneSpread(DARKSHORE)
			local journal = loaded.ns.journal
			journal:OpenPlace(loaded.ns.JournalPlace.fish(BLACKMOUTH))

			-- Its one tile, Darkshore's: the tiles widget's first child.
			local tile = journal.frame.right.drawn.tiles[1].children[1]
			assert.are.equal("Darkshore", tile.name.text)
			tile:Click()

			assert.are.same({ "Home", "Kalimdor", "Darkshore", "Oily Blackmouth" }, crumbLabels(loaded))
			assert.is_true(blockWithText(journal.pages.left, "Oily Blackmouth").selected)
			assert.are.equal("Oily Blackmouth", journal.pages.right[2].text)
		end)
	end)

	describe("with nothing selected", function()
		it(
			"shows \"About these waters\": the skill, the zone's completion, its families' stars and weights, and the reward with the Master title naming the zone (LED-R137, LED-R161)",
			function()
				local _, loaded = zoneSpread(DARKSHORE)
				local right = loaded.ns.journal.pages.right

				-- Completion: 2 of 6 Species, 1 of 2 families, the junk but not the treasure: 4 of 10 (LED-R53).
				assert.are.same({
					"About these waters",
					"Skill ~75",
					"40% of these waters known: 2 of 6 fish, 1 of 2 trophy families",
					"Trophies landed here",
					"Catfish",
					"Redgill",
					"Reward for mastery: each new seal earns XP. The Master seal earns the title Warden of Darkshore Waters.",
					"Pick a fish on the left to read its page.",
				}, blockTexts(right))
			end
		)

		it(
			'ends the reward after "earns XP." while the zonemaster title has no lore text (LED-R137, LED-R161)',
			function()
				local _, loaded = zoneSpread(DARKSHORE)
				loaded.ns.L["title.zonemaster.text"] = nil
				loaded.ns.journal:Draw()

				local right = loaded.ns.journal.pages.right
				assert.are.same(
					{ "Reward for mastery: each new seal earns XP.", "Pick a fish on the left to read its page." },
					{ right[#right - 1].text, right[#right].text }
				)
			end
		)

		it(
			"gives each family its shown stars and its overall weights landed, opening it in the Trophy Room (LED-R137, LED-R47)",
			function()
				local _, loaded = zoneSpread(DARKSHORE)
				local right = loaded.ns.journal.pages.right
				local catfish, redgill = blockWithText(right, "Catfish"), blockWithText(right, "Redgill")

				-- The Catfish's weights are the 17 lb (landed here) and Elwynn's 22 lb: ★ and ★★ (ceil(2 / 2) = 1
				-- landed), not ★★★, as its heaviest isn't landed.
				assert.are.same({ "row", "1 / 2", { [1] = true, [2] = true } }, {
					catfish.kind,
					catfish.value,
					catfish.stars,
				})
				assert.are.same({ id = "trophy", args = { family = 2 } }, catfish.place)
				assert.are.same({ "0 / 1", {} }, { redgill.value, redgill.stars })
			end
		)

		it("opens a family's line in the Trophy Room on that family (LED-R137, LED-R143)", function()
			local _, loaded = zoneSpread(DARKSHORE)
			local journal = loaded.ns.journal

			-- The right page's rows are its families: Catfish, then Redgill.
			journal.frame.right.drawn.row[2]:Click()

			assert.are.same({ id = "trophy", args = { family = 4 } }, journal.router:Place())
			assert.are.same({ "Home", "The Trophy Room" }, crumbLabels(loaded))
			assert.are.equal("Redgill", journal.pages.right[1].text)
		end)

		it(
			"leaves out a family's lines on both pages while its lore name has no text (LED-R161, LED-R135, LED-R137)",
			function()
				local _, loaded = zoneSpread(DARKSHORE)
				-- Redgill (family 4) before the Ledger's lore check turns on: its key has no text.
				loaded.ns.L["family.4.name"] = nil
				loaded.ns.journal:Draw()
				local pages = loaded.ns.journal.pages

				local trophies = {}
				for _, text in ipairs(blockTexts(pages.left)) do
					if text:find("trophy, any weight", 1, true) then
						trophies[#trophies + 1] = text
					end
				end
				assert.are.same({ drawnSymbols("☑ a Catfish trophy, any weight") }, trophies)
				assert.are.same({
					"Trophies landed here",
					"Catfish",
					"Reward for mastery: each new seal earns XP. The Master seal earns the title Warden of Darkshore Waters.",
				}, {
					pages.right[4].text,
					pages.right[5].text,
					pages.right[6].text,
				})
			end
		)

		it('reads "Any skill" for a zone whose skill base is 0 or below (LED-R137, DATA-R30)', function()
			local startingZone = catalogue()
			startingZone.areas[DARKSHORE].skillBase = -70
			local _, loaded = openJournal({ catalogue = startingZone, place = { "zone", DARKSHORE } })

			assert.are.same(
				{ "About these waters", "Any skill" },
				{ unpack(blockTexts(loaded.ns.journal.pages.right), 1, 2) }
			)
		end)

		it('leaves out "Skill ~" for a zone without a skill base (LED-R137)', function()
			local noSkill = catalogue()
			noSkill.areas[DARKSHORE].skillBase = nil
			local _, loaded = openJournal({ catalogue = noSkill, place = { "zone", DARKSHORE } })

			local right = blockTexts(loaded.ns.journal.pages.right)
			assert.are.same(
				{ "About these waters", "0% of these waters known: 0 of 6 fish, 0 of 2 trophy families" },
				{ right[1], right[2] }
			)
		end)
	end)

	describe("scrolling", function()
		it("keeps the left page's scroll when the right page opens a fish's plain hint (LED-R129, LED-R141)", function()
			local _, loaded = zoneSpread(DARKSHORE)
			loaded.ns.journal.frame.left.drawn.row[3]:Click()
			scrollPage(loaded, "left", 120)

			-- The right page's "Read the plain hint ▸".
			loaded.ns.journal.frame.right.drawn.link[1]:Click()

			local right = loaded.ns.journal.pages.right
			assert.are.equal("night · pools · Darkshore · skill ~75", right[#right].text)
			assert.are.equal(120, pageScroll(loaded, "left"))
		end)

		it(
			"keeps the left page's scroll when a fish is selected on it, and starts the right page's new entry at the top (LED-R129, LED-R136)",
			function()
				local _, loaded = zoneSpread(DARKSHORE)
				loaded.ns.journal.frame.left.drawn.row[1]:Click()
				scrollPage(loaded, "left", 120)
				scrollPage(loaded, "right", 80)

				loaded.ns.journal.frame.left.drawn.row[3]:Click()

				assert.are.equal("An unknown fish", loaded.ns.journal.pages.crumbs[4].label)
				assert.are.same({ 120, 0 }, { pageScroll(loaded, "left"), pageScroll(loaded, "right") })
			end
		)

		it("keeps both pages' scroll through a live redraw (LED-R129, LED-R123)", function()
			local fake, loaded = zoneSpread(DARKSHORE)
			scrollPage(loaded, "left", 120)
			scrollPage(loaded, "right", 80)

			fake.playCast("caught", { { itemID = FIREFIN, quantity = 1 } })
			loaded.client.runTimers()

			assert.are.equal("Day and night · 1 / 2", loaded.ns.journal.pages.left[11].text)
			assert.are.same({ 120, 80 }, { pageScroll(loaded, "left"), pageScroll(loaded, "right") })
		end)

		it("starts both pages at the top when another zone opens (LED-R129)", function()
			local _, loaded = zoneSpread(DARKSHORE)
			local journal = loaded.ns.journal
			journal.frame.left.drawn.row[1]:Click()
			scrollPage(loaded, "left", 120)
			scrollPage(loaded, "right", 80)

			journal:OpenPlace(loaded.ns.JournalPlace.zone(ELWYNN))

			assert.are.equal("Elwynn Forest", journal.pages.left[2].text)
			assert.are.same({ 0, 0 }, { pageScroll(loaded, "left"), pageScroll(loaded, "right") })
		end)

		it(
			"keeps the left page's scroll going back to the zone from its fish, starting the right page at the top (LED-R129, LED-R125)",
			function()
				local _, loaded = zoneSpread(DARKSHORE)
				local journal = loaded.ns.journal
				journal.frame.left.drawn.row[1]:Click()
				scrollPage(loaded, "left", 120)
				scrollPage(loaded, "right", 80)

				journal.frame.back:Click()

				assert.are.equal("About these waters", journal.pages.right[1].text)
				assert.are.same({ 120, 0 }, { pageScroll(loaded, "left"), pageScroll(loaded, "right") })
			end
		)
	end)
end)
