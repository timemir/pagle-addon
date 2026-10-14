-- The Journal's Angler page on FakePagle (LED-R146 as far as M3 goes, LED-R4, LED-R40, LED-R41, LED-R71): the
-- bookplate over a fixture log of two characters' Catches on a hand-made catalogue, Hands on the Rod from
-- Pagle.GetAngler().skill and the Skill Milestones.

local MACKEREL, NIGHTFISH, BOOT, CHEST, TROPHY = 6303, 13759, 2, 3, 13901
local ELWYNN, DUSKWOOD = 12, 10
local T0 = SERVER_TIME - 700 -- Sunday 11 October 2026, 15:03 UTC; realm minute 494 makes it 11 Oct on the realm too

-- A catalogue in the shape of ns.catalogue (DATA-R76): Elwynn charted, listing two Species (one gated at night), a
-- piece of junk, a chest and a trophy; Duskwood without data. So Ledger completion's world is 2 Species, 1 junk,
-- 1 treasure, 1 trophy weight and 1 charted zone (LED-R70, LED-R71).
local function catalogue()
	local night = { time = { { 1260, 360 } } }
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

-- A Ledger on a fake over the catalogue and `log` (the fixture by default), logged in, in the world and on the
-- Angler page.
---@param log table[]?
---@return FakePagle fake
---@return LoadedAddon loaded
local function anglerPage(log)
	return openJournal({
		catalogue = catalogue(),
		characters = characters(),
		log = log or FIXTURE,
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
		"shows the bookplate: kept since, the shown level, the ink XP bar, completion and its five parts, and the lifetime Catches (LED-R146, LED-R71, LED-R4)",
		function()
			local _, loaded = anglerPage()

			-- XP: Mackerel's first Catch 500 + in Elwynn 100 + Elwynn's first Catch 200; the boot, a curio, 150; two
			-- Skill Milestones 2,000; Local in Elwynn at once 250 + 500 + 750; three Catches in Fresh Water 60.
			-- 4,510 XP is level 4 (steps 1,080 + 1,160 + 1,240 = 3,480), 1,030 into its 1,320 step (LED-R30).
			-- Completion: 1 of 2 Species, 1 of 1 junk, 0 of 1 treasure, 0 of 1 weight, 0 of 1 zone mastered, so
			-- 2 of 6 is 33% (LED-R70).
			assert.are.same({
				"Ex Libris",
				"The Angler's Ledger",
				"kept since 11 Oct",
				"Angler Level 4",
				"[xpBar]",
				"33% of the Ledger complete (2 of 6)",
				"Species 1 of 2",
				"Junk Museum 1 of 1",
				"Treasures 0 of 1",
				"Trophy Room weights 0 of 1",
				"Zones mastered 0 of 1",
				"3 Catches",
			}, blockTexts(loaded.ns.journal.pages.left))
			assert.are.equal("1,030 of 1,320.", loaded.ns.journal.pages.left[5].bar.text)
		end
	)

	it("leaves out the kept since line before the first Catch (LED-R146)", function()
		local _, loaded = anglerPage({ FIXTURE[1], FIXTURE[2] })
		local left = blockTexts(loaded.ns.journal.pages.left)

		assert.are.same({ "Ex Libris", "The Angler's Ledger", "Angler Level 2" }, { left[1], left[2], left[3] })
		assert.are.equal("0 Catches", left[#left])
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
		assert.are.equal("☑ 75   ☑ 150   ☐ 225   ☐ 300", right[#right].text)
	end)

	it("ticks a Skill Milestone the celebrated set holds, though the state doesn't (LED-R146, LED-R92)", function()
		local _, loaded = anglerPage()

		loaded.env.PagleLedgerDB.global.celebrated.skill[225] = true
		loaded.ns.journal:Draw()

		local right = loaded.ns.journal.pages.right
		assert.are.equal("☑ 75   ☑ 150   ☑ 225   ☐ 300", right[#right].text)
	end)

	it("draws none of M4's elements (LED-R4, LED-R112, LED-R146)", function()
		local _, loaded = anglerPage()
		local pages = loaded.ns.journal.pages

		-- Every M4 block found: the crest (an icon), the Prestige emblems (seals), the Prestige button and the
		-- "Signed As" and "Bindings" pick lists (links), the active title (handwriting on the bookplate), and the
		-- words of the rest.
		local found = {}
		for _, side in ipairs({ "left", "right" }) do
			for _, block in ipairs(pages[side]) do
				if block.kind == "icon" or block.kind == "seal" or block.kind == "link" then
					found[#found + 1] = block.kind
				end
				if block.hand and side == "left" then
					found[#found + 1] = block.text
				end
				for _, word in ipairs({ "Prestige", "Signed As", "Bindings", "Automatic", "next milestone" }) do
					if (block.text or ""):find(word, 1, true) then
						found[#found + 1] = block.text
					end
				end
			end
		end
		assert.are.same({}, found)
	end)
end)
