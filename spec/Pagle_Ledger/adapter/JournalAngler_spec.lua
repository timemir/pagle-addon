-- The Journal's Angler page on FakePagle (LED-R146, LED-R40, LED-R41, LED-R71): the bookplate over a fixture log of
-- two characters' Catches on a hand-made catalogue, with the crest (LED-R112), the active title (LED-R77), the
-- Prestige emblem and button (LED-R33, LED-R34) and the next Catch Milestone (LED-R42); Hands on the Rod from
-- Pagle.GetAngler().skill, the Skill Milestones, Signed As (LED-R75–R77, SET-R70), the Bindings (LED-R110,
-- SHOP-R32, SHOP-R40) and Where your XP came from (LED-R150), with the ink XP bar's tooltip (LED-R145).

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
-- `updating`: the projection still building) and on the Angler page. `modules` registers other Modules before the
-- Ledger loads (openJournal's).
---@param log table[]?
---@param options { catalogue: table?, saved: table?, updating: boolean?, modules: fun(fake: FakePagle)?, motion: boolean? }?
---@return FakePagle fake
---@return LoadedAddon loaded
local function anglerPage(log, options)
	options = options or {}
	return openJournal({
		motion = options.motion,
		catalogue = options.catalogue or catalogue(),
		characters = characters(),
		logId = "log",
		log = log or FIXTURE,
		globals = { PagleLedgerDB = options.saved },
		building = options.updating,
		place = { "angler" },
		modules = options.modules,
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
		"shows the bookplate: the Prestige frame, kept since, the shown level, the active title, the ink XP bar, the Prestige line, completion and its six parts, and the lifetime Catches with the next milestone (LED-R146, LED-R154, LED-R112, LED-R77, LED-R34, LED-R42, LED-R71)",
		function()
			local _, loaded = anglerPage()

			-- XP: Mackerel's first Catch 500 + in Elwynn 100 + Elwynn's first Catch 200; the boot, a curio, 150; two
			-- Skill Milestones 2,000; Local in Elwynn at once 250 + 500 + 750; three Catches in Fresh Water 60.
			-- 4,510 XP is level 4 (steps 1,080 + 1,160 + 1,240 = 3,480), 1,030 into its 1,320 step (LED-R30).
			-- Completion: 1 of 2 Species, no Species with varieties (VAR-R21), 1 of 1 junk, 0 of 1 treasure, 0 of 1 weight, 0 of 1 zone mastered, so
			-- 2 of 6 is 33% (LED-R70).
			-- No crest: Core's default, Plain, is "No emblem, only the owner's name" (LED-R112, SHOP-R25); the active
			-- title under the level, automatic: the highest level title, level 1's Minnow (LED-R77); no Prestige yet
			-- (LED-R34), and below 60 no button (LED-R33); and the next Catch Milestone (LED-R42).
			assert.are.same({
				"[prestigeFrame]",
				"Ex Libris",
				"The Angler's Ledger",
				"kept since 11 Oct",
				"4",
				"[xpBar]",
				"The Ledger",
				"Species",
				"Varieties",
				"Junk Museum",
				"Treasures",
				"Trophy Room weights",
				"Zones mastered",
				"3 Catches · next milestone 1,000",
			}, blockTexts(loaded.ns.journal.pages.left))
			local left = loaded.ns.journal.pages.left
			-- No Prestige's frame, holding the likeness, no bookplate crest on it
			assert.are.same({ kind = "prestigeFrame", rank = 0 }, left[1])
			assert.are.same({
				kind = "bookplate",
				text = "4",
				value = "Angler Level",
				signature = "Minnow",
				note = "No Prestige yet",
			}, left[5])
			assert.are.equal("1,030 of 1,320.", left[6].bar.text)
			assert.are.equal("33% of the Ledger complete (2 of 6)", left[7].value)
			local parts = {}
			for i = 8, 13 do
				parts[#parts + 1] = left[i].value
			end
			assert.are.same({ "1 of 2", "0 of 0", "1 of 1", "0 of 1", "0 of 1", "0 of 1" }, parts)
			-- the likeness is the player's portrait
			local crest = loaded.ns.journal.frame.left.drawn.prestigeFrame[1]
			assert.are.equal("player", crest.frame:GetWell().portrait)
			assert.is_false(crest.pin:IsShown())
		end
	)

	it("leaves out the kept since line before the first Catch (LED-R146)", function()
		local _, loaded = anglerPage({ FIXTURE[1], FIXTURE[2] })
		local left = blockTexts(loaded.ns.journal.pages.left)

		assert.are.same(
			{ "[prestigeFrame]", "Ex Libris", "The Angler's Ledger", "2" },
			{ left[1], left[2], left[3], left[4] }
		)
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
	it("shows no emblem and no Prestige button at rank 0 below 60 (LED-R146, LED-R34, LED-R33)", function()
		local _, loaded = anglerPage()
		local left = loaded.ns.journal.pages.left

		assert.are.same({}, ofKind(left, "button"))
		local bookplate = assert(blockOfKind(left, "bookplate"))
		assert.are.same({ nil, "No Prestige yet" }, { bookplate.mark, bookplate.note })
	end)

	it("shows emblem II at rank 2, in place of No Prestige yet (LED-R146, LED-R34)", function()
		local _, loaded = anglerPage(fixturePlus({ prestige(T0 + 600, 1), prestige(T0 + 900, 2) }))
		local left = loaded.ns.journal.pages.left

		local bookplate = assert(blockOfKind(left, "bookplate"))
		assert.are.same({ { emblem = "II", stars = 0, rank = 2 }, "Prestige II" }, { bookplate.mark, bookplate.note })
		-- the frame is Prestige II's, Casting Off
		assert.are.same({ kind = "prestigeFrame", rank = 2 }, left[1])
		assert.are.equal("castoff", loaded.ns.journal.frame.left.drawn.prestigeFrame[1].frame.key)
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
		fake.setPurchased({ ["ledger.crest.elwynn"] = true }) -- owned: a purchased ID is (SHOP-R30)

		assert.is_true(fake.Pagle.SetEquipped("core.crest", "ledger.crest.elwynn"))

		assert.are.same(
			{ kind = "prestigeFrame", rank = 0, icon = "Interface\\AddOns\\Pagle_Ledger\\media\\crests\\elwynn" },
			loaded.ns.journal.pages.left[1]
		)
		local crest = loaded.ns.journal.frame.left.drawn.prestigeFrame[1]
		assert.is_true(crest.pin:IsShown())
		assert.is_true(fake.Pagle.SetEquipped("core.crest", "core.crest.plain"))
		assert.are.same({ kind = "prestigeFrame", rank = 0 }, loaded.ns.journal.pages.left[1])
		assert.is_false(crest.pin:IsShown())
	end)

	-- The pin's centre from the frame's top left (y down) on the bookplate and the square texture's side: the frame's
	-- pin point at 0.65 of the kit's box, the shield 50 units wide and 140:120 tall, its full height (LED-R146).
	local function pinCentre(fake, rank)
		local pin = fake.ns.PrestigeFrameArt(rank).pin
		return 50 * 140 / 120, pin.x * 0.65, pin.y * 0.65
	end

	local function near(a, b)
		return math.abs(a - b) < 0.01
	end

	-- `region`'s one anchor as { point, relativeTo, relativePoint, x, y }.
	local function anchorOf(region)
		return { region:GetPoint(1) }
	end

	it(
		"pins the equipped crest's whole shield, 50 units wide, centred on the frame's pin point, turned 6° clockwise, with its shadow and pin (LED-R146, LED-R112)",
		function()
			local fake, loaded = anglerPage()
			fake.setPurchased({ ["ledger.crest.westfall"] = true }) -- owned: a purchased ID is (SHOP-R30)
			assert.is_true(fake.Pagle.SetEquipped("core.crest", "ledger.crest.westfall"))

			local crest = loaded.ns.journal.frame.left.drawn.prestigeFrame[1]
			local pin = crest.pin
			local side, x, y = pinCentre(fake, 0)
			local w, h = pin:GetSize()
			assert.is_true(near(side, w) and near(side, h))
			local point, relativeTo, relativePoint, px, py = pin:GetPoint(1)
			assert.are.same({ "CENTER", crest, "TOPLEFT" }, { point, relativeTo, relativePoint })
			assert.is_true(near(x, px) and near(-y, py))
			local icon = "Interface\\AddOns\\Pagle_Ledger\\media\\crests\\westfall"
			assert.are.same({ icon, nil, nil }, { pin.shield.texture, pin.shield.texCoord, pin.shield.masks })
			assert.are.equal(-math.rad(6), pin.shield.rotation)
			-- the shadow: the same texture, half black, offset (1, -2.5), turned with it
			assert.are.same({ icon, { 0, 0, 0, 0.5 }, -math.rad(6) }, {
				pin.shadow.texture,
				pin.shadow.vertexColor,
				pin.shadow.rotation,
			})
			assert.are.same({ "CENTER", pin, "CENTER", 1, -2.5 }, anchorOf(pin.shadow))
			assert.is_true(pin.head:IsShown())
		end
	)

	it("pins it at a Prestige frame's own pin point (LED-R146, LED-R154)", function()
		local fake, loaded = anglerPage(fixturePlus({ prestige(T0 + 600, 1), prestige(T0 + 900, 2) }))
		fake.setPurchased({ ["ledger.crest.winterspring"] = true }) -- owned: a purchased ID is (SHOP-R30)
		assert.is_true(fake.Pagle.SetEquipped("core.crest", "ledger.crest.winterspring"))

		local crest = loaded.ns.journal.frame.left.drawn.prestigeFrame[1]
		local _, x, y = pinCentre(fake, 2)
		local _, _, _, px, py = crest.pin:GetPoint(1)
		assert.is_true(near(x, px) and near(-y, py))
		-- over the frame: the pin's frame drawn above Core's
		assert.is_true(crest.pin:GetFrameLevel() > crest.frame:GetFrameLevel())
	end)

	it(
		"draws the rank's Prestige frame at 0.65 of its box with the likeness in its well, and takes its room at the"
			.. " page's left (LED-R146, LED-R154)",
		function()
			local _, loaded = anglerPage(fixturePlus({ prestige(T0 + 600, 1), prestige(T0 + 900, 2) }))

			local widget = loaded.ns.journal.frame.left.drawn.prestigeFrame[1]
			assert.are.same({ "castoff", 169, 182, "II" }, {
				widget.frame.key,
				widget.frame.width,
				widget.frame.height,
				widget.frame.label:GetText(),
			})
			assert.are.equal("player", widget.frame:GetWell().portrait)
			assert.are.same({ 173, 182 }, { widget.floatW, widget.floatH })
		end
	)

	it(
		"moves a frame from V up while the Angler page is open, and stops as the Journal closes (LED-R154, SET-R30)",
		function()
			local ranks = {}
			for rank = 1, 5 do
				ranks[#ranks + 1] = prestige(T0 + 600 + rank, rank)
			end
			local _, loaded = anglerPage(fixturePlus(ranks), { motion = true })
			local frame = loaded.ns.journal.frame.left.drawn.prestigeFrame[1].frame

			assert.are.equal("storm", frame.key)
			assert.are.equal(frame, frame.art.playing)
			loaded.ns.journal.frame:Hide()
			loaded.client.update(0.1)
			assert.is_nil(frame.art.playing)
		end
	)

	it("stands a moving frame still with Animations off (LED-R154, SET-R30)", function()
		local ranks = {}
		for rank = 1, 5 do
			ranks[#ranks + 1] = prestige(T0 + 600 + rank, rank)
		end
		local _, loaded = anglerPage(fixturePlus(ranks)) -- the Journal's specs draw with Animations off

		local frame = loaded.ns.journal.frame.left.drawn.prestigeFrame[1].frame
		assert.are.equal("storm", frame.key)
		assert.is_nil(frame.art.playing)
	end)

	it(
		"names the frame when hovered: its name in gilt, its description, and the rank with its emblem at 22 (LED-R154)",
		function()
			local _, loaded = anglerPage(fixturePlus({ prestige(T0 + 600, 1), prestige(T0 + 900, 2) }))
			local frame = loaded.ns.journal.frame.left.drawn.prestigeFrame[1].frame

			frame.scripts.OnEnter(frame)

			local lines = loaded.client.tooltipLines()
			assert.are.equal("Casting Off", lines[1])
			assert.matches("clinker%-built rowboat", lines[2])
			assert.matches("^|T.*Emblems:22:22:.*|t Prestige II$", lines[3])
		end
	)

	it("leaves the pin upright on a client whose textures can't turn (LED-R146)", function()
		local _, loaded = anglerPage()
		local texture = loaded.env.CreateFrame("Frame"):CreateTexture()
		texture.SetRotation = nil

		loaded.ns.TurnPin(texture)

		assert.is_nil(texture.rotation)
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

	it("comes after Hands on the Rod and Milestones, and before Bindings (LED-R146, LED-R150)", function()
		local _, loaded = anglerPage()
		local titles = {}
		for _, block in ipairs(loaded.ns.journal.pages.right) do
			if block.kind == "title" or block.kind == "kicker" then
				titles[#titles + 1] = block.text
			end
		end

		assert.are.same(
			{ "Hands on the Rod", "Milestones", "Signed As", "Bindings", "Where your XP came from" },
			titles
		)
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
		"lists every binding in Core's slot in the shop's order: Field Leather in use, those for sale in the Curio Shop, then the Ledger's earned ones by how they are earned, the second round's last (LED-R146, SHOP-R25, LED-R110, LED-R116, LED-R118)",
		function()
			local _, loaded = anglerPage()

			assert.are.same({
				{ "Field Leather", "In use" },
				{ "Birch Bark", "In the Curio Shop" },
				{ "Tide-Chart Linen", "In the Curio Shop" },
				{ "Tarred Sailcloth", "In the Curio Shop" },
				{ "Oilskin Yellow", "In the Curio Shop" },
				{ "Oilcloth", "In the Curio Shop" },
				{ "Canvas Field Pad", "In the Curio Shop" },
				{ "Waxed Kraft", "In the Curio Shop" },
				{ "Tartan Wool", "In the Curio Shop" },
				{ "Sea-Green Buckram", "In the Curio Shop" },
				{ "Mossbound", "In the Curio Shop" },
				{ "Driftwood Boards", "In the Curio Shop" },
				{ "Eelskin", "In the Curio Shop" },
				{ "Kodo Hide", "In the Curio Shop" },
				{ "Frost-Tanned Hide", "In the Curio Shop" },
				{ "Net over Cork", "In the Curio Shop" },
				{ "Tooled Leather", "In the Curio Shop" },
				{ "Map Linen", "In the Curio Shop" },
				{ "Bound Planks", "In the Curio Shop" },
				{ "Sharkskin", "In the Curio Shop" },
				{ "Riveted Copper", "In the Curio Shop" },
				{ "Night Velvet", "In the Curio Shop" },
				{ "Turtle Shell", "In the Curio Shop" },
				{ "Gilded Morocco", "In the Curio Shop" },
				{ "Verdigris", "In the Curio Shop" },
				{ "Snakeskin", "In the Curio Shop" },
				{ "Stingray Shagreen", "In the Curio Shop" },
				{ "Lacquered Red", "In the Curio Shop" },
				{ "Bone & Rawhide", "In the Curio Shop" },
				{ "Brass Hunter's Case", "In the Curio Shop" },
				{ "Coral Inlay", "In the Curio Shop" },
				{ "Scrimshaw Panel", "In the Curio Shop" },
				{ "Shagreen and Bone", "In the Curio Shop" },
				{ "Mother-of-Pearl", "In the Curio Shop" },
				{ "Gilded Trophy Case", "In the Curio Shop" },
				{ "Tanned Hide", "Angler Level 10" },
				{ "Tidewater Blue", "Angler Level 20" },
				{ "Reed Green", "Angler Level 30" },
				{ "Oxblood", "Angler Level 40" },
				{ "Storm Grey", "Angler Level 50" },
				{ "Nat's Own", "Angler Level 60" },
				{ "Three Gilt Fish", "Land all three Legends" },
				{ "Monster Hide", "Land a Monster" },
				{ "Abyssal Black", "Prestige X" },
				{ "Keeper's Gold", "Complete the Ledger" },
				{ "Iridescent Scale", "Every fish in every colour" },
				{ "Breaking Wave", "300 catches at sea" },
				{ "Captain's Logbook", "25 zones fished" },
				{ "Carved Heartwood", "A catch after 10 got away" },
				{ "Stormglass Reliquary", "Master in 10 zones" },
				{ "Black Lacquer Koi", "30 days fished" },
				{ "Cable Knit", "10,000 Casts" },
				{ "Fly Wallet", "5 different lures" },
				{ "Crab Carapace", "50 Big-mouth Clams" },
				{ "Ember Scale", "Prestige VII" },
			}, lines(loaded))
		end
	)

	it(
		"draws each line's closed book from its binding's atlas, an expansion one's from Bindings2, 11 wide, and none for a cover with no book of the Journal's (LED-R146, LED-R110)",
		function()
			local _, loaded = anglerPage()
			local ns = loaded.ns
			local books = {}
			for _, widget in ipairs(ns.journal.frame.right.drawn.leader) do
				if widget.swatch:IsShown() then
					books[widget.label.text] = widget.swatch
				end
			end

			local field, coral = books["Field Leather"], books["Coral Inlay"]
			assert.is_nil(books["Oilcloth"])
			assert.is_nil(books["Lacquered Red"])
			assert.is_truthy(books["Monster Hide"])
			assert.are.equal(ns.JOURNAL_ATLASES.Bindings.file, field.texture)
			assert.are.equal(ns.JOURNAL_ATLASES.Bindings2.file, coral.texture)
			assert.are.same({ ns.JournalCoords("Bindings2", "swatch-coral") }, coral.texCoord)
			assert.are.same({ 11, 11 }, { field.box[3], coral.box[3] })
		end
	)

	it(
		"offers Use for an expansion binding earned, its rule kept in the celebrated set (LED-R146, LED-R116)",
		function()
			local _, loaded = anglerPage(nil, {
				saved = {
					global = {
						celebrated = {
							coins = 0,
							prestige = 10,
							goods = { ["ledger.binding.monster"] = true },
							logId = "log",
						},
					},
				},
			})

			local list = lines(loaded)
			assert.are.same({ "Monster Hide", "Use" }, list[43])
			assert.are.same({ "Abyssal Black", "Use" }, list[44])
			assert.are.same({ "Keeper's Gold", "Complete the Ledger" }, list[45])
		end
	)

	it("offers Use for a level binding once its level is reached, and for one bought (LED-R146, LED-R111)", function()
		local fake, loaded = anglerPage(nil, { saved = LEVEL_10 })
		fake.setPurchased({ ["core.binding.birch"] = true })
		loaded.ns.journal:Draw()

		local list = lines(loaded)
		assert.are.same({ "Tanned Hide", "Use" }, list[36])
		assert.are.same({ "Tidewater Blue", "Angler Level 20" }, list[37])
		assert.are.same({ "Birch Bark", "Use" }, list[2])
	end)

	it("opens the Curio Shop at a binding for sale (LED-R146, SHOP-R40)", function()
		local fake, loaded = anglerPage()

		-- The tenth of the lines reading so: Sea-Green Buckram's.
		local widgets = {}
		for _, widget in ipairs(loaded.ns.journal.frame.right.drawn.leader) do
			if widget.value.text == "In the Curio Shop" then
				widgets[#widgets + 1] = widget
			end
		end
		widgets[9].scripts.OnClick(widgets[9])

		assert.are.equal("core.binding.buckram", fake.shopsOpened[#fake.shopsOpened].goodID)
	end)

	it(
		"equips a binding on Use, the book redrawn in it and the line reading In use (LED-R146, LED-R112, SHOP-R32)",
		function()
			local fake, loaded = anglerPage(nil, { saved = LEVEL_10 })

			click(loaded, "right", "Tanned Hide")

			assert.are.equal("ledger.binding.level10", fake.Pagle.GetEquipped("core.binding"))
			assert.are.same(fake.ns.BindingLook("ledger.binding.level10"), loaded.ns.journal.frame.binding:Look())
			local list = lines(loaded)
			assert.are.same({ { "Field Leather", "Use" }, { "Tanned Hide", "In use" } }, { list[1], list[36] })
		end
	)

	it("follows a pick made elsewhere, as Look and Feel's (SHOP-R32, LED-R112)", function()
		local fake, loaded = anglerPage(nil, { saved = LEVEL_10 })

		assert.is_true(fake.Pagle.SetEquipped("core.binding", "ledger.binding.level10"))

		assert.are.same({ "Tanned Hide", "In use" }, lines(loaded)[36])
	end)
end)

-- The roster's Module order (CORE-R41), for the stub paying Modules.
local ORDER = { Hunts = 20, TackleBoard = 40 }

-- Registers stub paying Modules on `fake` (AXP-R2), as Hunts and the Tackle Board are, each reporting its lifetime
-- Activity XP in `totals` from its projection's done, in the order of `names`. Returns their handles by name, whose
-- ReportXPEarned reports a new total.
---@param fake FakePagle
---@param names string[]
---@param totals table<string, integer>
---@return table<string, table>
local function payingModules(fake, names, totals)
	local handles = {}
	for _, name in ipairs(names) do
		local handle = fake.Pagle.RegisterModule({ name = name, title = name, order = ORDER[name] })
		handle:NewProjection({
			db = {},
			rulesVersion = 1,
			reset = function()
				return {}
			end,
			apply = function() end,
			done = function()
				handle:ReportXPEarned(totals[name])
			end,
		})
		handles[name] = handle
	end
	return handles
end

-- "Where your XP came from"'s lines: each as { name, this climb, all told, struck through }.
---@param loaded LoadedAddon
---@return table[]
local function sourceLines(loaded)
	local list = {}
	for _, block in ipairs(section(loaded, "Where your XP came from")) do
		list[#list + 1] = { block.text or "", block.value, block.total, block.off == true }
	end
	return list
end

-- The ink XP bar widget drawn on page `side`.
---@param loaded LoadedAddon
---@param side "left"|"right"
---@return table
local function xpBarWidget(loaded, side)
	return assert(loaded.ns.journal.frame[side].drawn.xpBar[1], "no XP bar drawn")
end

describe("the Angler page's Where your XP came from", function()
	-- The fixture's own XP: 4,510, all in this first climb (the bookplate spec above works it out).
	it(
		"lists This climb and All told after Bindings: the Ledger's own XP, then Hunts and the Tackle Board in Core's Module order (LED-R150)",
		function()
			local _, loaded = anglerPage(nil, {
				modules = function(fake)
					-- the Tackle Board registered first: the page still lists Hunts before it
					payingModules(fake, { "TackleBoard", "Hunts" }, { Hunts = 1500, TackleBoard = 900 })
				end,
			})

			assert.are.same({
				{ "", "This climb", "All told", false },
				{ "Catches and discoveries", "4,510", "4,510", false },
				{ "Hunts", "1,500", "1,500", false },
				{ "Tackle Board", "900", "900", false },
			}, sourceLines(loaded))
			local right = loaded.ns.journal.pages.right
			assert.are.equal("Where your XP came from", right[#right - 4].text)
			-- drawn: the line's name and both figures, not struck through
			local drawn = loaded.ns.journal.frame.right.drawn.xpSource
			assert.are.same({ "Hunts", "1,500", "1,500" }, shownTexts(drawn[3]))
			assert.is_false(drawn[3].strikes[1]:IsShown())
		end
	)

	it("shows only the Ledger's own line with no source reported yet (LED-R150)", function()
		local _, loaded = anglerPage()

		assert.are.same({
			{ "", "This climb", "All told", false },
			{ "Catches and discoveries", "4,510", "4,510", false },
		}, sourceLines(loaded))
	end)

	it(
		"greys a disabled Tackle Board's line and strikes it through in red ink, and still counts it in the climb (LED-R150, AXP-R90)",
		function()
			local fake, loaded = anglerPage(nil, {
				modules = function(fake)
					payingModules(fake, { "Hunts" }, { Hunts = 1500 })
				end,
			})
			-- The Tackle Board is off this session: its last total stays (AXP-R3).
			fake.setActivityXP("TackleBoard", 900)
			loaded.ns.journal:Draw()

			assert.are.same({ "Tackle Board", "900", "900", true }, sourceLines(loaded)[4])
			local drawn = loaded.ns.journal.frame.right.drawn.xpSource[4]
			for _, strike in ipairs(drawn.strikes) do
				assert.is_true(strike:IsShown())
			end
			-- it still counts: 4,510 + 1,500 + 900 = 6,910 XP is level 6, 710 into its 1,480 step (LED-R30, LED-R37)
			assert.are.equal("710 of 1,480.", blockOfKind(loaded.ns.journal.pages.left, "xpBar").bar.text)
		end
	)

	it("redraws when another Module's Activity XP changes while the Journal is open (LED-R150, LED-R39)", function()
		local handles
		local _, loaded = anglerPage(nil, {
			modules = function(fake)
				handles = payingModules(fake, { "Hunts" }, { Hunts = 1500 })
			end,
		})

		handles.Hunts:ReportXPEarned(1650)
		loaded.client.runTimers()

		assert.are.same({ "Hunts", "1,650", "1,650", false }, sourceLines(loaded)[3])
	end)

	it("shows this climb's lines in the ink XP bar's tooltip, by source, roughly (LED-R145, LED-R150)", function()
		local _, loaded = anglerPage(nil, {
			modules = function(fake)
				payingModules(fake, { "Hunts", "TackleBoard" }, { Hunts = 1500, TackleBoard = 900 })
			end,
		})
		local bar = xpBarWidget(loaded, "left")

		bar.scripts.OnEnter(bar)

		assert.are.same({
			"Where this climb's XP came from",
			"Catches and discoveries",
			"4,510",
			"Hunts",
			"1,500",
			"Tackle Board",
			"900",
			"by source, roughly",
		}, loaded.client.tooltipLines())
		bar.scripts.OnLeave(bar)
		assert.are.same({}, loaded.client.tooltipLines())
	end)

	it("shows the tooltip on Home's ink XP bar too (LED-R145, LED-R132)", function()
		local _, loaded = openJournal({
			catalogue = catalogue(),
			characters = characters(),
			log = FIXTURE,
			modules = function(fake)
				payingModules(fake, { "Hunts" }, { Hunts = 1500 })
			end,
		})
		local bar = xpBarWidget(loaded, "right")

		bar.scripts.OnEnter(bar)

		assert.are.same({
			"Where this climb's XP came from",
			"Catches and discoveries",
			"4,510",
			"Hunts",
			"1,500",
			"by source, roughly",
		}, loaded.client.tooltipLines())
	end)

	it("reads Updating while the projection updates, and the section once it is built (LED-R150, LED-R122)", function()
		local fake, loaded = anglerPage(nil, {
			updating = true,
			modules = function(fake)
				payingModules(fake, { "Hunts" }, { Hunts = 1500 })
			end,
		})

		assert.is_true(loaded.ns.journal.pages.updating)
		assert.is_true(loaded.ns.journal.frame.updatingView:IsShown())

		fake.enterWorld()

		assert.are.same({ "Hunts", "1,500", "1,500", false }, sourceLines(loaded)[3])
	end)

	it("keeps its words on the parchment at the default size, large totals too (LED-R150, CORE-R65)", function()
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
		local bounds = dofile("spec/support/bounds.lua")
		local fake, loaded = anglerPage(nil, {
			modules = function(host)
				payingModules(host, { "Hunts" }, { Hunts = 1234567 })
			end,
		})
		fake.setActivityXP("TackleBoard", 7654321)
		loaded.ns.journal:Draw()
		local frame = loaded.ns.journal.frame

		local overflows = bounds.overflows(frame.leaves.right[frame.shownLeaf.right].body)

		assert.are.same({}, overflows)
		assert.is_true(bounds.measured > 0)
		assert.are.same({ "Tackle Board", "7,654,321", "7,654,321" }, shownTexts(frame.right.drawn.xpSource[4]))
	end)
end)
