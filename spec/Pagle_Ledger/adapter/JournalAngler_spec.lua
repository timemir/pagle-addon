-- The Journal's Angler page on FakePagle (LED-R146, LED-R40, LED-R41, LED-R71): the bookplate over a fixture log of
-- two characters' Catches on a hand-made catalogue, with the crest (LED-R112), the active title (LED-R77), the
-- Prestige emblem and button (LED-R33, LED-R34) and the next Catch Milestone (LED-R42); Hands on the Rod from
-- Pagle.GetAngler().skill, the Skill Milestones, Signed As (LED-R75–R77, SET-R70) and the Bindings (LED-R110,
-- SHOP-R32, SHOP-R40).

local MACKEREL, NIGHTFISH, BOOT, CHEST, TROPHY = 6303, 13759, 2, 3, 13901
local ELWYNN, DUSKWOOD = 12, 10
local T0 = 1791731000 -- Sunday 11 October 2026, 15:03 UTC; realm minute 494 makes it 11 Oct on the realm too

-- A catalogue in the shape of ns.catalogue (DATA-R76): Elwynn charted, listing two Species (one gated at night), a
-- piece of junk, a chest and a trophy; Duskwood without data. So Ledger completion's world is 2 Species, 1 junk,
-- 1 treasure, 1 trophy weight and 1 charted zone (LED-R70, LED-R71).
local function catalogue()
	local night = { time = { { 1260, 360 } } }
	local function item(category, fields)
		local record = { category = category, legend = false, noise = false, removed = false, pool = false }
		for key, value in pairs(fields) do
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
	return {
		fingerprint = "0123456789abcdef",
		items = {
			[MACKEREL] = item("fish", { species = MACKEREL }),
			[NIGHTFISH] = item("fish", { species = NIGHTFISH }),
			[BOOT] = item("junk", {}),
			[CHEST] = item("container", {}),
			[TROPHY] = item("trophy", { family = 1, weight = 19 }),
		},
		areas = {
			[ELWYNN] = area({
				skillBase = 25,
				catches = {
					{ itemID = MACKEREL, confirmed = false },
					{ itemID = NIGHTFISH, confirmed = false, window = "night", gate = night, gateConfirmed = false },
					{ itemID = BOOT, confirmed = false },
					{ itemID = CHEST, confirmed = false },
					{ itemID = TROPHY, confirmed = false },
				},
			}),
			[DUSKWOOD] = area({ hasData = false }),
		},
		aliases = {},
		pools = {},
		windows = { night = { spec = night, confirmed = false } },
		events = {},
		fishingSpells = {},
		auras = {},
	}
end

-- A caught Cast of `itemID` by character `char` in Elwynn at `time`.
local function cast(char, time, itemID)
	return {
		kind = "cast",
		char = char,
		time = time,
		outcome = "caught",
		conditions = { minute = 494, zone = ELWYNN, subzone = 0, events = {}, auras = {} },
		items = { { itemID = itemID, quantity = 1 } },
	}
end

-- The fixture log's three characters: Angler (the fake client's, index 1), Bea and Cora. Cora has no Skill Reading.
local function characters()
	local function character(guid, name)
		return { guid = guid, name = name, classID = 1, raceID = 1, faction = "Alliance", realmID = 4618 }
	end
	return {
		character(PLAYER_GUID, "Angler"),
		character("Player-4618-0B0B0B0B", "Bea"),
		character("Player-4618-0C0C0C0C", "Cora"),
	}
end

-- The fixture log: Bea's Skill Reading first, then Angler's (so the log's order isn't the index order), and three
-- Catches across the two: Angler's Mackerel, Bea's boot and Bea's second Mackerel.
local FIXTURE = {
	{ kind = "skill", char = 2, time = T0 - 600, rank = 160, max = 225, mod = 0 },
	{ kind = "skill", char = 1, time = T0 - 300, rank = 80, max = 150, mod = 0 },
	cast(1, T0, MACKEREL),
	cast(2, T0 + 60, BOOT),
	cast(2, T0 + 120, MACKEREL),
}

-- A Ledger on a fake over a catalogue (the one above by default) and `log` (the fixture by default), with
-- PagleLedgerDB `saved` if given (its celebrated set kept: the log's logId is "log"), logged in, in the world (unless
-- `updating`: the projection still building) and on the Angler page.
---@param log table[]?
---@param options { catalogue: table?, saved: table?, updating: boolean? }?
---@return FakePagle fake
---@return LoadedAddon loaded
local function anglerPage(log, options)
	options = options or {}
	local fake = newFakePagle()
	fake.setCatalogue(options.catalogue or catalogue())
	fake.catchLog.data.characters = characters()
	fake.catchLog.data.logId = "log"
	for _, record in ipairs(log or FIXTURE) do
		fake.catchLog:Append(record)
	end
	fake.globals.BreakUpLargeNumbers = breakUpLargeNumbers
	fake.globals.PagleLedgerDB = options.saved
	local loaded = fake.load("Pagle_Ledger")
	fake.login()
	if not options.updating then
		fake.enterWorld()
	end
	assert.is_true(loaded.ns.journal:Open("angler"))
	return fake, loaded
end

-- The texts of a page's blocks, in order (a block without text, such as the XP bar, as its kind in brackets).
---@param blocks LedgerBlock[]
---@return string[]
local function texts(blocks)
	local list = {}
	for i, block in ipairs(blocks) do
		list[i] = block.text or ("[" .. block.kind .. "]")
	end
	return list
end

describe("the Journal's Angler page", function()
	it("is the spread Home ❧ The Angler (LED-R146, LED-R125)", function()
		local _, loaded = anglerPage()
		local pages = loaded.ns.journal.pages

		assert.are.same({ "Home", "The Angler" }, { pages.crumbs[1].label, pages.crumbs[2].label })
		assert.are.same({ id = "angler" }, pages.crumbs[2].place)
		assert.are.same({ id = "home" }, pages.back)
	end)

	it(
		"shows the bookplate: the crest, kept since, the shown level, the active title, the ink XP bar, the Prestige seals, completion and its five parts, and the lifetime Catches with the next milestone (LED-R146, LED-R112, LED-R77, LED-R34, LED-R42, LED-R71)",
		function()
			local _, loaded = anglerPage()

			-- XP: Mackerel's first Catch 500 + in Elwynn 100 + Elwynn's first Catch 200; the boot, a curio, 150; two
			-- Skill Milestones 2,000; Local in Elwynn at once 250 + 500 + 750; three Catches in Fresh Water 60.
			-- 4,510 XP is level 4 (steps 1,080 + 1,160 + 1,240 = 3,480), 1,030 into its 1,320 step (LED-R30).
			-- Completion: 1 of 2 Species, 1 of 1 junk, 0 of 1 treasure, 0 of 1 weight, 0 of 1 zone mastered, so
			-- 2 of 6 is 33% (LED-R70).
			-- The crest first: Core's default, Plain (SHOP-R25); the active title under the level, automatic: the
			-- highest level title, level 1's Minnow (LED-R77); no Prestige yet (LED-R34), and below 60 no button
			-- (LED-R33); and the next Catch Milestone (LED-R42).
			assert.are.same({
				"[icon]",
				"Ex Libris",
				"The Angler's Ledger",
				"kept since 11 Oct",
				"Angler Level 4",
				"Minnow",
				"[xpBar]",
				"No Prestige seals yet",
				"33% of the Ledger complete (2 of 6)",
				"Species 1 of 2",
				"Junk Museum 1 of 1",
				"Treasures 0 of 1",
				"Trophy Room weights 0 of 1",
				"Zones mastered 0 of 1",
				"3 Catches · next milestone 1,000",
			}, texts(loaded.ns.journal.pages.left))
			local left = loaded.ns.journal.pages.left
			assert.are.equal("Interface\\Icons\\INV_Misc_Note_01", left[1].icon)
			assert.is_true(left[6].hand)
			assert.are.equal("1,030 of 1,320.", left[7].bar.text)
		end
	)

	it("leaves out the kept since line before the first Catch (LED-R146)", function()
		local _, loaded = anglerPage({ FIXTURE[1], FIXTURE[2] })
		local left = texts(loaded.ns.journal.pages.left)

		assert.are.same({ "Ex Libris", "The Angler's Ledger", "Angler Level 2" }, { left[2], left[3], left[4] })
		assert.are.equal("0 Catches · next milestone 1,000", left[#left])
		for _, text in ipairs(left) do
			assert.is_nil(text:find("kept since", 1, true))
		end
	end)

	it(
		"lists the hands on the rod by character index from Pagle.GetAngler().skill, leaving out one without a Skill Reading (LED-R146, LED-R41)",
		function()
			local _, loaded = anglerPage()
			local right = loaded.ns.journal.pages.right

			assert.are.same(
				{ "Hands on the Rod", "Angler: skill 80 / 150", "Bea: skill 160 / 225" },
				{ right[1].text, right[2].text, right[3].text }
			)
			assert.are.equal("Milestones", right[4].text)
		end
	)

	it("reads the hands live from the Angler, not the projection (LED-R41, LOG-R31)", function()
		local fake, loaded = anglerPage()

		fake.readSkill(95, 150, 0)
		loaded.ns.journal:Draw()

		assert.are.equal("Angler: skill 95 / 150", loaded.ns.journal.pages.right[2].text)
	end)

	it("ticks the Skill Milestones credited in the state (LED-R146, LED-R40)", function()
		local _, loaded = anglerPage()
		local right = loaded.ns.journal.pages.right

		-- Bea's 160 credits 75 and 150.
		assert.are.equal("☑ 75   ☑ 150   ☐ 225   ☐ 300", right[5].text)
	end)

	it("ticks a Skill Milestone the celebrated set holds, though the state doesn't (LED-R146, LED-R92)", function()
		local _, loaded = anglerPage()

		loaded.env.PagleLedgerDB.global.celebrated.skill[225] = true
		loaded.ns.journal:Draw()

		local right = loaded.ns.journal.pages.right
		assert.are.equal("☑ 75   ☑ 150   ☑ 225   ☐ 300", right[5].text)
	end)
end)

-- A caught Cast by character 1 in Elwynn at `time` of `count` items, the item `itemID` each, or with `itemID` nil,
-- the fish from FIRST_FISH on.
local FIRST_FISH = 100001
---@param time integer
---@param count integer
---@param itemID integer?
local function haul(time, count, itemID)
	local record = cast(1, time, MACKEREL)
	record.items = {}
	for i = 1, count do
		record.items[i] = { itemID = itemID or FIRST_FISH + i - 1, quantity = 1 }
	end
	return record
end

-- One Cast landing this many new Species in an uncharted zone reaches level 60 (adapter/Prestige_spec.lua):
-- 200,840 XP against the 200,600 that reaching 60 costs (LED-R30).
local TO_60_SPECIES = 324

-- A catalogue of TO_60_SPECIES fish, each its own Species, and no area (DATA-R76).
local function sixtyCatalogue()
	local items = {}
	for i = 0, TO_60_SPECIES - 1 do
		local id = FIRST_FISH + i
		items[id] = { category = "fish", species = id, legend = false, noise = false, removed = false, pool = false }
	end
	return {
		fingerprint = "0123456789abcdef",
		items = items,
		areas = {},
		aliases = {},
		pools = {},
		windows = {},
		events = {},
		fishingSpells = {},
		auras = {},
	}
end

-- Character 1's Prestige to `rank` at `time` (LOG-R38).
local function prestige(time, rank)
	return { kind = "prestige", char = 1, time = time, rank = rank }
end

-- The fixture log, then `extra` records.
---@param extra table[]
---@return table[]
local function fixtureAnd(extra)
	local log = {}
	for _, record in ipairs(FIXTURE) do
		log[#log + 1] = record
	end
	for _, record in ipairs(extra) do
		log[#log + 1] = record
	end
	return log
end

-- The blocks of `kind` on a page, in order.
---@param blocks LedgerBlock[]
---@param kind string
---@return LedgerBlock[]
local function ofKind(blocks, kind)
	local found = {}
	for _, block in ipairs(blocks) do
		if block.kind == kind then
			found[#found + 1] = block
		end
	end
	return found
end

-- The blocks of the right page after the title `heading`, up to the next title.
---@param loaded LoadedAddon
---@param heading string
---@return LedgerBlock[]
local function section(loaded, heading)
	local found, inside = {}, false
	for _, block in ipairs(loaded.ns.journal.pages.right) do
		if block.kind == "title" then
			inside = block.text == heading
		elseif inside then
			found[#found + 1] = block
		end
	end
	return found
end

-- Clicks the widget drawn on page `side` whose label reads `text`, as the player does (its OnClick, or its face's
-- for a button).
---@param loaded LoadedAddon
---@param side "left"|"right"
---@param text string
local function click(loaded, side, text)
	for _, widgets in pairs(loaded.ns.journal.frame[side].drawn) do
		for _, widget in ipairs(widgets) do
			if widget.label and widget.label.text == text then
				local target = widget.face or widget
				target.scripts.OnClick(target)
				return
			end
		end
	end
	error("nothing drawn reads " .. text)
end

describe("the Angler page's bookplate in M4", function()
	it("shows no seals and no Prestige button at rank 0 below 60 (LED-R146, LED-R34, LED-R33)", function()
		local _, loaded = anglerPage()
		local left = loaded.ns.journal.pages.left

		assert.are.same({}, ofKind(left, "emblem"))
		assert.are.same({}, ofKind(left, "button"))
		assert.are.same({ "No Prestige seals yet" }, { left[8].text })
	end)

	it("shows emblem II at rank 2, in place of No Prestige seals yet (LED-R146, LED-R34)", function()
		local _, loaded = anglerPage(fixtureAnd({ prestige(T0 + 600, 1), prestige(T0 + 900, 2) }))
		local left = loaded.ns.journal.pages.left

		assert.are.same({ { kind = "emblem", mark = { emblem = "II", stars = 0 } } }, ofKind(left, "emblem"))
		for _, text in ipairs(texts(left)) do
			assert.are_not.equal("No Prestige seals yet", text)
		end
	end)

	it(
		"shows Begin a new Ledger (Prestige) at 60, under the emblems, and it opens the confirm (LED-R146, LED-R33)",
		function()
			local _, loaded = anglerPage({ haul(T0, TO_60_SPECIES) }, { catalogue = sixtyCatalogue() })
			local left = loaded.ns.journal.pages.left

			local buttons = ofKind(left, "button")
			assert.are.equal(1, #buttons)
			assert.are.equal("Begin a new Ledger (Prestige)", buttons[1].text)
			local shown = texts(left)
			assert.are.same({ "No Prestige seals yet", "Begin a new Ledger (Prestige)" }, { shown[8], shown[9] })

			click(loaded, "left", "Begin a new Ledger (Prestige)")

			assert.are.equal("PAGLE_LEDGER_PRESTIGE", loaded.client.popup.which)
		end
	)

	it("shows no Prestige button while the projection updates (LED-R33, LED-R122)", function()
		local fake, loaded = anglerPage({ haul(T0, TO_60_SPECIES) }, { catalogue = sixtyCatalogue(), updating = true })

		assert.is_true(loaded.ns.journal.pages.updating)
		assert.are.same({}, ofKind(loaded.ns.journal.pages.left, "button"))

		fake.enterWorld()

		assert.are.equal(1, #ofKind(loaded.ns.journal.pages.left, "button"))
	end)

	it(
		"reads 1,200 Catches · next milestone 5,000, and after the last milestone just the count (LED-R146, LED-R42)",
		function()
			local _, at1200 = anglerPage(fixtureAnd({ haul(T0 + 600, 1197, MACKEREL) }))
			local left = at1200.ns.journal.pages.left
			assert.are.equal("1,200 Catches · next milestone 5,000", left[#left].text)

			local _, at50000 = anglerPage(fixtureAnd({ haul(T0 + 600, 49997, MACKEREL) }))
			left = at50000.ns.journal.pages.left
			assert.are.equal("50,000 Catches", left[#left].text)
		end
	)

	it("reads 1 Catch · next milestone 1,000 at one Catch (LED-R146, LED-R42)", function()
		local _, loaded = anglerPage({ cast(1, T0, MACKEREL) })
		local left = loaded.ns.journal.pages.left

		assert.are.equal("1 Catch · next milestone 1,000", left[#left].text)
	end)

	it("draws the equipped crest, and redraws when it changes (LED-R112, SHOP-R33)", function()
		local fake, loaded = anglerPage()
		fake.setPurchased({ ["core.crest.crest1"] = true })

		assert.is_true(fake.Pagle.SetEquipped("core.crest", "core.crest.crest1"))

		assert.are.same(
			{ kind = "icon", icon = "Interface\\Icons\\INV_Fishingpole_02" },
			loaded.ns.journal.pages.left[1]
		)
	end)
end)

describe("the Angler page's Signed As", function()
	-- The fixture earns level 1's Minnow and, its one junk caught, Collector of Boots (LED-R75); the celebrated set
	-- adds Dabbler, Returning Tide, a Legend's title with no lore text and a key naming no title (LED-R76).
	local function signedPage()
		local fake, loaded = anglerPage()
		loaded.env.PagleLedgerDB.global.celebrated.titles = {
			["title:level10"] = true,
			["title:prestige1"] = true,
			["legend:99999"] = true,
			["title:bogus"] = true,
		}
		loaded.ns.journal:Draw()
		return fake, loaded
	end

	it(
		"lists Automatic, then the earned titles in LED-R75's order, leaving out one without lore text, Automatic marked (LED-R146, LED-R75, LED-R77, LED-R161)",
		function()
			local _, loaded = signedPage()

			assert.are.same(
				{ "» Automatic", "· Minnow", "· Dabbler", "· Returning Tide", "· Collector of Boots" },
				texts(section(loaded, "Signed As"))
			)
			for _, block in ipairs(section(loaded, "Signed As")) do
				assert.are.equal("link", block.kind)
			end
			-- Automatic: the highest level title earned (LED-R77).
			assert.are.equal("Dabbler", loaded.ns.journal.pages.left[6].text)
		end
	)

	it(
		"makes the title picked the active one on the bookplate, and Automatic clears it (LED-R146, LED-R77, SET-R70)",
		function()
			local _, loaded = signedPage()
			local profile = loaded.ns.db.profile

			click(loaded, "right", "· Returning Tide")

			assert.are.equal("title:prestige1", profile.activeTitle)
			assert.are.equal("Returning Tide", loaded.ns.journal.pages.left[6].text)
			assert.are.same(
				{ "· Automatic", "· Minnow", "· Dabbler", "» Returning Tide", "· Collector of Boots" },
				texts(section(loaded, "Signed As"))
			)

			click(loaded, "right", "· Automatic")

			assert.is_nil(profile.activeTitle)
			assert.are.equal("Dabbler", loaded.ns.journal.pages.left[6].text)
			assert.are.equal("» Automatic", section(loaded, "Signed As")[1].text)
		end
	)

	it("comes after Hands on the Rod and Milestones, and before Bindings (LED-R146)", function()
		local _, loaded = anglerPage()
		local titles = {}
		for _, block in ipairs(loaded.ns.journal.pages.right) do
			if block.kind == "title" or block.kind == "kicker" then
				titles[#titles + 1] = block.text
			end
		end

		assert.are.same({ "Hands on the Rod", "Milestones", "Signed As", "Bindings" }, titles)
	end)
end)

describe("the Angler page's Bindings", function()
	-- Each binding line: its name and its state.
	local function lines(loaded)
		local list = {}
		for i, block in ipairs(section(loaded, "Bindings")) do
			list[i] = { block.text, block.value }
		end
		return list
	end

	-- Celebrated at level 10 before (LED-R90): Tanned Hide is earned (LED-R111).
	local LEVEL_10 = { global = { celebrated = { coins = 0, levels = { [0] = 10 }, logId = "log" } } }

	it(
		"lists the ten bindings in LED-R110's order: Field Leather in use, the level bindings by level, the three for sale in the Curio Shop (LED-R146, LED-R110)",
		function()
			local _, loaded = anglerPage()

			assert.are.same({
				{ "Field Leather", "In use" },
				{ "Tanned Hide", "Angler Level 10" },
				{ "Tidewater Blue", "Angler Level 20" },
				{ "Reed Green", "Angler Level 30" },
				{ "Oxblood", "Angler Level 40" },
				{ "Storm Grey", "Angler Level 50" },
				{ "Nat's Own", "Angler Level 60" },
				{ "Birch Bark", "In the Curio Shop" },
				{ "Sea-green Buckram", "In the Curio Shop" },
				{ "Sharkskin", "In the Curio Shop" },
			}, lines(loaded))
		end
	)

	it("offers Use for a level binding once its level is reached, and for one bought (LED-R146, LED-R111)", function()
		local fake, loaded = anglerPage(nil, { saved = LEVEL_10 })
		fake.setPurchased({ ["ledger.binding.birch"] = true })
		loaded.ns.journal:Draw()

		local list = lines(loaded)
		assert.are.same({ "Tanned Hide", "Use" }, list[2])
		assert.are.same({ "Tidewater Blue", "Angler Level 20" }, list[3])
		assert.are.same({ "Birch Bark", "Use" }, list[8])
	end)

	it("opens the Curio Shop at a binding for sale (LED-R146, SHOP-R40)", function()
		local fake, loaded = anglerPage()

		-- The second of the three lines reading so: Sea-green Buckram's.
		local widgets = {}
		for _, widget in ipairs(loaded.ns.journal.frame.right.drawn.leader) do
			if widget.value.text == "In the Curio Shop" then
				widgets[#widgets + 1] = widget
			end
		end
		widgets[2].scripts.OnClick(widgets[2])

		assert.are.equal("ledger.binding.buckram", fake.shopsOpened[#fake.shopsOpened].goodID)
	end)

	it(
		"equips a binding on Use, the book redrawn in it and the line reading In use (LED-R146, LED-R112, SHOP-R32)",
		function()
			local fake, loaded = anglerPage(nil, { saved = LEVEL_10 })

			click(loaded, "right", "Tanned Hide")

			assert.are.equal("ledger.binding.level10", fake.Pagle.GetEquipped("ledger.binding"))
			assert.are.equal("ledger.binding.level10", loaded.ns.journal.binding)
			local leather = loaded.ns.journal.frame.leather.color
			assert.are.same(
				loaded.ns.BindingLook("ledger.binding.level10").leather,
				{ leather[1], leather[2], leather[3] }
			)
			local list = lines(loaded)
			assert.are.same({ { "Field Leather", "Use" }, { "Tanned Hide", "In use" } }, { list[1], list[2] })
		end
	)

	it("follows a pick made elsewhere, as Look and Feel's (SHOP-R32, LED-R112)", function()
		local fake, loaded = anglerPage(nil, { saved = LEVEL_10 })

		assert.is_true(fake.Pagle.SetEquipped("ledger.binding", "ledger.binding.level10"))

		assert.are.same({ "Tanned Hide", "In use" }, lines(loaded)[2])
	end)
end)
