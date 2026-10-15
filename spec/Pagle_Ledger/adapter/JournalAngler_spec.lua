-- The Journal's Angler page on FakePagle (LED-R146, LED-R40, LED-R41, LED-R71): the bookplate over a fixture log of
-- two characters' Catches on a hand-made catalogue, with the crest (LED-R112), the active title (LED-R77), the
-- Prestige emblem and button (LED-R33, LED-R34) and the next Catch Milestone (LED-R42); Hands on the Rod from
-- Pagle.GetAngler().skill, the Skill Milestones, Signed As (LED-R75–R77, SET-R70) and the Bindings (LED-R110,
-- SHOP-R32, SHOP-R40).

local MACKEREL, NIGHTFISH, BOOT, CHEST, TROPHY = 6303, 13759, 2, 3, 13901
local ELWYNN, DUSKWOOD = 12, 10
local T0 = SERVER_TIME - 700 -- Sunday 11 October 2026, 15:03 UTC; realm minute 494 makes it 11 Oct on the realm too

-- A catalogue in the shape of ns.catalogue (DATA-R76): Elwynn charted, listing two Species (one gated at night), a
-- piece of junk, a chest and a trophy; Duskwood without data. So Ledger completion's world is 2 Species, 1 junk,
-- 1 treasure, 1 trophy weight and 1 charted zone (LED-R70, LED-R71).
local function catalogue()
	local night = NIGHT_WINDOW
	return catalogueWith({
		items = {
			[MACKEREL] = fishRecord(MACKEREL),
			[NIGHTFISH] = fishRecord(NIGHTFISH),
			[BOOT] = itemRecord("junk"),
			[CHEST] = itemRecord("container"),
			[TROPHY] = itemRecord("trophy", { family = 1, weight = 19 }),
		},
		areas = {
			[ELWYNN] = areaRecord(0, {
				skillBase = 25,
				catches = {
					{ itemID = MACKEREL, confirmed = false },
					{ itemID = NIGHTFISH, confirmed = false, window = "night", gate = night, gateConfirmed = false },
					{ itemID = BOOT, confirmed = false },
					{ itemID = CHEST, confirmed = false },
					{ itemID = TROPHY, confirmed = false },
				},
			}),
			[DUSKWOOD] = areaRecord(0, { hasData = false }),
		},
		windows = { night = { spec = night, confirmed = false } },
	})
end

-- A caught Cast of `itemID` by character `char` in Elwynn at `time`.
local function cast(char, time, itemID)
	return castRecord({ char = char, time = time, zone = ELWYNN, items = { itemID } })
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
	return openJournal({
		catalogue = options.catalogue or catalogue(),
		characters = characters(),
		logId = "log",
		log = log or FIXTURE,
		globals = { PagleLedgerDB = options.saved },
		building = options.updating,
		place = { "angler" },
	})
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
			-- No crest: Core's default, Plain, is "No emblem, only the owner's name" (LED-R112, SHOP-R25); the active
			-- title under the level, automatic: the highest level title, level 1's Minnow (LED-R77); no Prestige yet
			-- (LED-R34), and below 60 no button (LED-R33); and the next Catch Milestone (LED-R42).
			assert.are.same({
				"[crest]",
				"Ex Libris",
				"The Angler's Ledger",
				"kept since 11 Oct",
				"4",
				"[xpBar]",
				"The Ledger",
				"Species",
				"Junk Museum",
				"Treasures",
				"Trophy Room weights",
				"Zones mastered",
				"3 Catches · next milestone 1,000",
			}, blockTexts(loaded.ns.journal.pages.left))
			local left = loaded.ns.journal.pages.left
			-- the plain crest, holding the likeness, no bookplate crest on it
			assert.are.same({ kind = "crest", rank = 0 }, left[1])
			assert.are.same({
				kind = "bookplate",
				text = "4",
				value = "Angler Level",
				signature = "Minnow",
				note = "No Prestige seals yet",
			}, left[5])
			assert.are.equal("1,030 of 1,320.", left[6].bar.text)
			assert.are.equal("33% of the Ledger complete (2 of 6)", left[7].value)
			local parts = {}
			for i = 8, 12 do
				parts[#parts + 1] = left[i].value
			end
			assert.are.same({ "1 of 2", "1 of 1", "0 of 1", "0 of 1", "0 of 1" }, parts)
			-- the likeness is the player's portrait
			local crest = loaded.ns.journal.frame.left.drawn.crest[1]
			assert.are.equal("player", crest.portrait.portrait)
			assert.is_false(crest.emblem:IsShown())
		end
	)

	it("leaves out the kept since line before the first Catch (LED-R146)", function()
		local _, loaded = anglerPage({ FIXTURE[1], FIXTURE[2] })
		local left = blockTexts(loaded.ns.journal.pages.left)

		assert.are.same({ "[crest]", "Ex Libris", "The Angler's Ledger", "2" }, { left[1], left[2], left[3], left[4] })
		assert.are.equal("0 Catches · next milestone 1,000", left[#left])
		for _, text in ipairs(left) do
			assert.is_nil(text:find("kept since", 1, true))
		end
	end)

	-- A Cast logged while the realm clock was secret: no realm minute, so no realm date (LOG-R49).
	local function secretCast(char, time, itemID)
		local record = cast(char, time, itemID)
		record.conditions.minute = nil
		return record
	end

	it(
		"keeps since the first Catch's server date at the realm's offset now when no Catch has a realm date (LED-R146, LED-R126)",
		function()
			local _, loaded = anglerPage({ secretCast(1, T0, MACKEREL), secretCast(1, T0 + 3 * 86400, BOOT) })

			assert.are.equal("kept since 11 Oct", loaded.ns.journal.pages.left[4].text)
		end
	)

	it("keeps since the first Catch with a realm date, past one without (LED-R146, ledger.md › Data)", function()
		local _, loaded = anglerPage({ secretCast(1, T0, MACKEREL), cast(1, T0 + 3 * 86400, BOOT) })

		assert.are.equal("kept since 14 Oct", loaded.ns.journal.pages.left[4].text)
	end)

	it(
		"lists the hands on the rod by character index from Pagle.GetAngler().skill, leaving out one without a Skill Reading (LED-R146, LED-R41)",
		function()
			local _, loaded = anglerPage()
			local right = loaded.ns.journal.pages.right

			assert.are.same(
				{ "Hands on the Rod", "Angler", "skill 80 / 150", "Bea", "skill 160 / 225" },
				{ right[1].text, right[2].text, right[2].value, right[3].text, right[3].value }
			)
			assert.are.equal("Milestones", right[4].text)
		end
	)

	it("reads the hands live from the Angler, not the projection (LED-R41, LOG-R31)", function()
		local fake, loaded = anglerPage()

		fake.readSkill(95, 150, 0)
		loaded.ns.journal:Draw()

		assert.are.equal("skill 95 / 150", loaded.ns.journal.pages.right[2].value)
	end)

	it("ticks the Skill Milestones credited in the state (LED-R146, LED-R40)", function()
		local _, loaded = anglerPage()
		local right = loaded.ns.journal.pages.right

		-- Bea's 160 credits 75 and 150.
		assert.are.equal(drawnSymbols("☑ 75   ☑ 150   ☐ 225   ☐ 300"), right[5].text)
	end)

	it("ticks a Skill Milestone the celebrated set holds, though the state doesn't (LED-R146, LED-R92)", function()
		local _, loaded = anglerPage()

		loaded.env.PagleLedgerDB.global.celebrated.skill[225] = true
		loaded.ns.journal:Draw()

		local right = loaded.ns.journal.pages.right
		assert.are.equal(drawnSymbols("☑ 75   ☑ 150   ☑ 225   ☐ 300"), right[5].text)
	end)
end)

-- A caught Cast by character 1 in Elwynn at `time` of `count` items, the item `itemID` each, or with `itemID` nil,
-- the fish from FIRST_FISH on.
local FIRST_FISH = 100001
---@param time integer
---@param count integer
---@param itemID integer?
local function bigCast(time, count, itemID)
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
		items[FIRST_FISH + i] = fishRecord(FIRST_FISH + i)
	end
	return catalogueWith({ items = items })
end

-- Character 1's Prestige to `rank` at `time` (LOG-R38).
local function prestige(time, rank)
	return { kind = "prestige", char = 1, time = time, rank = rank }
end

-- The fixture log, then `extra` records.
---@param extra table[]
---@return table[]
local function fixturePlus(extra)
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

-- The blocks of the right page after the heading `heading`, up to the next heading.
---@param loaded LoadedAddon
---@param heading string
---@return LedgerBlock[]
local function section(loaded, heading)
	local found, inside = {}, false
	for _, block in ipairs(loaded.ns.journal.pages.right) do
		if block.kind == "kicker" then
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

		assert.are.same({}, ofKind(left, "button"))
		local bookplate = blockOfKind(left, "bookplate")
		assert.are.same({ nil, "No Prestige seals yet" }, { bookplate.mark, bookplate.note })
	end)

	it("shows emblem II at rank 2, in place of No Prestige seals yet (LED-R146, LED-R34)", function()
		local _, loaded = anglerPage(fixturePlus({ prestige(T0 + 600, 1), prestige(T0 + 900, 2) }))
		local left = loaded.ns.journal.pages.left

		local bookplate = blockOfKind(left, "bookplate")
		assert.are.same({ { emblem = "II", stars = 0 }, "Prestige II" }, { bookplate.mark, bookplate.note })
		-- the crest is Prestige II's frame
		assert.are.same({ kind = "crest", rank = 2 }, left[1])
		assert.are.equal("crest-ii", loaded.ns.CrestSprite(2))
	end)

	it(
		"shows Begin a new Ledger (Prestige) at 60, under the emblems, and it opens the confirm (LED-R146, LED-R33)",
		function()
			local _, loaded = anglerPage({ bigCast(T0, TO_60_SPECIES) }, { catalogue = sixtyCatalogue() })
			local left = loaded.ns.journal.pages.left

			local buttons = ofKind(left, "button")
			assert.are.equal(1, #buttons)
			assert.are.equal("Begin a new Ledger (Prestige)", buttons[1].text)
			local shown = blockTexts(left)
			assert.are.same({ "[xpBar]", "Begin a new Ledger (Prestige)" }, { shown[6], shown[7] })

			click(loaded, "left", "Begin a new Ledger (Prestige)")

			assert.is_true(loaded.ns.IsPrestigeConfirmShown())
		end
	)

	it("shows no Prestige button while the projection updates (LED-R33, LED-R122)", function()
		local fake, loaded = anglerPage(
			{ bigCast(T0, TO_60_SPECIES) },
			{ catalogue = sixtyCatalogue(), updating = true }
		)

		assert.is_true(loaded.ns.journal.pages.updating)
		assert.are.same({}, ofKind(loaded.ns.journal.pages.left, "button"))

		fake.enterWorld()

		assert.are.equal(1, #ofKind(loaded.ns.journal.pages.left, "button"))
	end)

	it(
		"reads 1,200 Catches · next milestone 5,000, and after the last milestone just the count (LED-R146, LED-R42)",
		function()
			local _, at1200 = anglerPage(fixturePlus({ bigCast(T0 + 600, 1197, MACKEREL) }))
			local left = at1200.ns.journal.pages.left
			assert.are.equal("1,200 Catches · next milestone 5,000", left[#left].text)

			local _, at50000 = anglerPage(fixturePlus({ bigCast(T0 + 600, 49997, MACKEREL) }))
			left = at50000.ns.journal.pages.left
			assert.are.equal("50,000 Catches", left[#left].text)
		end
	)

	it("reads 1 Catch · next milestone 1,000 at one Catch (LED-R146, LED-R42)", function()
		local _, loaded = anglerPage({ cast(1, T0, MACKEREL) })
		local left = loaded.ns.journal.pages.left

		assert.are.equal("1 Catch · next milestone 1,000", left[#left].text)
	end)

	it("draws the equipped crest, and none again for the default (LED-R112, SHOP-R25, SHOP-R33)", function()
		local fake, loaded = anglerPage()
		fake.setPurchased({ ["core.crest.crest1"] = true })

		assert.is_true(fake.Pagle.SetEquipped("core.crest", "core.crest.crest1"))

		assert.are.same(
			{ kind = "crest", rank = 0, icon = "Interface\\Icons\\INV_Fishingpole_02" },
			loaded.ns.journal.pages.left[1]
		)
		local crest = loaded.ns.journal.frame.left.drawn.crest[1]
		assert.is_true(crest.emblem:IsShown())
		assert.is_true(fake.Pagle.SetEquipped("core.crest", "core.crest.plain"))
		assert.are.same({ kind = "crest", rank = 0 }, loaded.ns.journal.pages.left[1])
		assert.is_false(crest.emblem:IsShown())
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
				{ "Automatic", "Minnow", "Dabbler", "Returning Tide", "Collector of Boots" },
				blockTexts(section(loaded, "Signed As"))
			)
			local picked = {}
			for i, block in ipairs(section(loaded, "Signed As")) do
				assert.are.same({ "link", "radio" }, { block.kind, block.style })
				picked[i] = block.on
			end
			assert.are.same({ true, false, false, false, false }, picked)
			-- Automatic: the highest level title earned (LED-R77).
			assert.are.equal("Dabbler", blockOfKind(loaded.ns.journal.pages.left, "bookplate").signature)
		end
	)

	it(
		"makes the title picked the active one on the bookplate, and Automatic clears it (LED-R146, LED-R77, SET-R70)",
		function()
			local _, loaded = signedPage()
			local profile = loaded.ns.db.profile

			click(loaded, "right", "Returning Tide")

			assert.are.equal("title:prestige1", profile.activeTitle)
			assert.are.equal("Returning Tide", blockOfKind(loaded.ns.journal.pages.left, "bookplate").signature)
			local picked = {}
			for i, block in ipairs(section(loaded, "Signed As")) do
				picked[i] = block.on
			end
			assert.are.same({ false, false, false, true, false }, picked)

			click(loaded, "right", "Automatic")

			assert.is_nil(profile.activeTitle)
			assert.are.equal("Dabbler", blockOfKind(loaded.ns.journal.pages.left, "bookplate").signature)
			assert.is_true(section(loaded, "Signed As")[1].on)
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
			assert.are.same(loaded.ns.BindingLook("ledger.binding.level10").tint, loaded.ns.journal.frame.leatherTint)
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
