-- The Ledger's M3 moments (LED-R90–R92, LED-R97), their Write-up lines (LED-R93, LED-R94) and completion in the
-- summary line (LED-R95) on FakePagle, over a fixture catalogue: the Announcements, Write-up sections and summary
-- line Core would show.

-- Cove lists three ungated Species, one gated (night) Species, a junk item and a trophy family of two weights.
local ANY_1, ANY_2, ANY_3, NIGHTFISH = 90001, 90002, 90003, 90004
local JUNK, CHEST = 90010, 90011
local LIGHT, HEAVY = 90020, 90021
-- On no list and not in the catalogue: Uncharted (LED-R5).
local UNKNOWN = 99001
-- A trophy family no lore batch names (LED-R161): a spec gives it a name where it needs one.
local FAMILY = 999
local COVE = 9001
local T0 = SERVER_TIME - 700
-- The fake log's logId, which a saved celebrated set names to belong to it (LED-R90).
local LOG_ID = "0123456789abcdef"
-- Realm minutes of day (LOG-R48): 08:14, and 21:40, inside the night window.
local DAY, NIGHT = 494, 1300

local ITEM_NAMES = {
	[ANY_1] = "Cove Perch",
	[ANY_2] = "Cove Bream",
	[ANY_3] = "Cove Dace",
	[NIGHTFISH] = "Moonlit Eel",
	[JUNK] = "Soggy Boot",
	[CHEST] = "Barnacled Chest",
	[LIGHT] = "40 Pound Snapper",
	[HEAVY] = "60 Pound Snapper",
}

local NIGHT_SPEC = NIGHT_WINDOW

-- A catch entry (LOG-R55): ungated, or gated by the night window.
local function entry(itemID, night)
	return night and catchEntry(itemID, "night", NIGHT_SPEC) or catchEntry(itemID)
end

-- A catalogue in the shape of ns.catalogue (DATA-R76) charting Cove, with `extra` catch entries on its list. The
-- chest is in the catalogue but on no list until a release lists it.
---@param extra table[]?
---@param fingerprint string?
local function catalogue(extra, fingerprint)
	local catches = {
		entry(ANY_1),
		entry(ANY_2),
		entry(ANY_3),
		entry(NIGHTFISH, true),
		entry(JUNK),
		entry(LIGHT),
		entry(HEAVY),
	}
	for _, more in ipairs(extra or {}) do
		catches[#catches + 1] = more
	end
	return catalogueWith({
		fingerprint = fingerprint,
		items = {
			[ANY_1] = fishRecord(ANY_1),
			[ANY_2] = fishRecord(ANY_2),
			[ANY_3] = fishRecord(ANY_3),
			[NIGHTFISH] = fishRecord(NIGHTFISH),
			[JUNK] = itemRecord("junk"),
			[CHEST] = itemRecord("container"),
			[LIGHT] = itemRecord("trophy", { family = FAMILY, weight = 40 }),
			[HEAVY] = itemRecord("trophy", { family = FAMILY, weight = 60 }),
		},
		areas = { [COVE] = areaRecord(0, { catches = catches }) },
		windows = { night = { spec = NIGHT_SPEC, confirmed = false } },
	})
end

-- A caught Cast record in Cove (zone 0 with `zone` = 0) for fake.catchLog:Append, by the player's character.
---@param time integer
---@param itemIDs integer[]
---@param options { zone: integer?, minute: integer? }?
local function cast(time, itemIDs, options)
	options = options or {}
	return castRecord({ time = time, zone = options.zone or COVE, minute = options.minute or DAY, items = itemIDs })
end

-- Loot of one item each, for fake.playCast.
---@param ... integer
---@return PagleLootItem[]
local function loot(...)
	local items = {}
	for i, itemID in ipairs({ ... }) do
		items[i] = { itemID = itemID, quantity = 1 }
	end
	return items
end

-- A FakePagle over `options.log` (a PagleLog shared between sessions, as the saved one is) with `history` appended
-- and `saved` as PagleLedgerDB, serving `options.catalogue` (the fixture by default): the Ledger loaded, logged in
-- and in the world, fishing live in Cove by day. The log's logId is LOG_ID.
---@param options { log: table?, history: table[]?, saved: table?, catalogue: table?, lore: table? }?
---@return FakePagle fake
---@return LoadedAddon loaded
local function session(options)
	options = options or {}
	local fake = newFakePagle()
	fake.setCatalogue(options.catalogue or catalogue())
	fake.conditions.zone = COVE
	fake.conditions.minute = DAY
	if options.log then
		fake.catchLog.data = options.log
	end
	fake.catchLog.data.logId = LOG_ID
	fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
	for _, record in ipairs(options.history or {}) do
		fake.catchLog:Append(record)
	end
	if options.saved then
		fake.globals.PagleLedgerDB = options.saved
	end
	fake.globals.C_Item = {
		GetItemNameByID = function(itemID)
			return ITEM_NAMES[itemID]
		end,
	}
	fake.globals.C_Map = {
		GetAreaInfo = function(areaID)
			return areaID == COVE and "Cove" or nil
		end,
	}
	local loaded = fake.load("Pagle_Ledger")
	for key, text in pairs(options.lore or {}) do
		loaded.ns.L[key] = text
	end
	fake.login()
	fake.enterWorld()
	fake.nextFrame()
	return fake, loaded
end

-- The next session over the last one's log and saved PagleLedgerDB, with `between` recorded before login.
---@param last FakePagle
---@param lastLoaded LoadedAddon
---@param options { history: table[]?, catalogue: table? }?
local function nextSession(last, lastLoaded, options)
	options = options or {}
	return session({
		log = last.catchLog.data,
		history = options.history,
		saved = lastLoaded.env.PagleLedgerDB,
		catalogue = options.catalogue,
	})
end

-- The Announcements shown since the spec last looked, once the frame after runs.
---@param fake FakePagle
---@param seen integer? how many were already looked at
---@return PagleAnnouncement[]
local function shown(fake, seen)
	fake.nextFrame()
	return { unpack(fake.announcements, (seen or 0) + 1) }
end

-- Each moment of an Announcement as "<kind> <title> / <text> <stamp> <coins>".
---@param announcement PagleAnnouncement
---@return string[]
local function momentsOf(announcement)
	local lines = {}
	for i, moment in ipairs(announcement.moments) do
		lines[i] = ("%s %s / %s %s %s"):format(
			moment.kind,
			moment.title,
			tostring(moment.text),
			tostring(moment.stamp),
			tostring(moment.coins)
		)
	end
	return lines
end

-- Each moment of an Announcement by kind.
---@param announcement PagleAnnouncement
---@return { [string]: PagleMoment }
local function byKind(announcement)
	local kinds = {}
	for _, moment in ipairs(announcement.moments) do
		kinds[moment.kind] = moment
	end
	return kinds
end

-- Each moment of a Cast's Announcements by its kind: its big one and its catch one (ANN-R11). M4's completion titles
-- ride a banner of their own (LED-R97), so a curio or a weight that completes a collection comes second.
---@param announcements PagleAnnouncement[]
---@return table<string, PagleMoment>
local function castKinds(announcements)
	local kinds = {}
	for _, announcement in ipairs(announcements) do
		for kind, moment in pairs(byKind(announcement)) do
			kinds[kind] = moment
		end
	end
	return kinds
end

describe("the Ledger's M3 live moments", function()
	it(
		"raise New Species and Zone rank: Visitor in one Announcement for a first Catch in a new zone, 10 + 2 Coins (LED-R96, LED-R97)",
		function()
			local fake = session()

			local record = assert(fake.playCast("caught", loot(ANY_1)))

			local announcements = shown(fake)
			assert.are.equal(1, #announcements)
			local announcement = announcements[1]
			-- Listed in Cove alone, its first Catch also puts it in its element: ★★ (LED-R45).
			assert.are.same({
				"newSpecies New Species / Cove Perch New! 10",
				"zoneRank Zone rank: Visitor / Cove Rank up 2",
				drawnSymbols("elementStar In its element / Cove Perch ★★ nil"),
			}, momentsOf(announcement))
			assert.are.equal(12, announcement.coins)
			local rank = byKind(announcement).zoneRank
			assert.are.same({ "toast", 120, record.id }, { rank.rung, rank.order, rank.cast })
			assert.are.equal("string", type(rank.icon))
		end
	)

	-- Cove at Expert: its three ungated Species, the night one at night and its junk (LED-R50).
	local EXPERT = {
		cast(T0, { ANY_1, ANY_2, ANY_3 }),
		cast(T0 + 60, { NIGHTFISH }, { minute = NIGHT }),
		cast(T0 + 120, { JUNK }),
	}

	it(
		"raise one Zone Master banner and no Zone rank toast for a Cast taking a zone from Expert to Master, 10 Coins (LED-R97)",
		function()
			local fake, loaded = session({ history = EXPERT })
			assert.are.equal(4, loaded.ns.projection:GetState().zones[COVE].rank)

			local record = assert(fake.playCast("caught", loot(LIGHT)))

			-- The banner, then the Cast's catch Announcement of its own (ANN-R11).
			local announcements = shown(fake)
			assert.are.equal(2, #announcements)
			local moments = byKind(announcements[1])
			assert.is_nil(moments.zoneRank)
			assert.is_nil(byKind(announcements[2]).zoneRank)
			local master = moments.zoneMaster
			assert.are.same(
				-- M4: the Zone Master's title rides in it (LED-R97).
				{ "banner", 120, "Zone Master", "Cove. Title: Warden of Cove Waters", "Master", 10, record.id },
				{ master.rung, master.order, master.title, master.text, master.stamp, master.coins, master.cast }
			)
			assert.are.equal("string", type(master.icon))
			assert.are.equal(5, loaded.env.PagleLedgerDB.global.celebrated.zones[COVE])
		end
	)

	it(
		"raise Trophy weight with the 40 to 60 lb ruler for a heavier weight, and ★★★ for the family's heaviest (LED-R61, LED-R97)",
		function()
			local fake, loaded = session({
				history = { cast(T0, { LIGHT }, { zone = 0 }) },
				lore = { ["family.999.name"] = "Snappers" },
			})

			local record = assert(fake.playCast("caught", loot(HEAVY)))

			local moments = castKinds(shown(fake))
			local weight = moments.trophyWeight
			assert.are.same({ "toast", 110, "Trophy weight", "60 Pound Snapper", "Trophy", 5, HEAVY, record.id }, {
				weight.rung,
				weight.order,
				weight.title,
				weight.text,
				weight.stamp,
				weight.coins,
				weight.icon,
				weight.cast,
			})
			assert.are.same({ old = 40, new = 60, unit = "lb", label = "weight" }, weight.ruler)
			local family = moments.familyStar
			assert.are.same({
				"nod",
				130,
				"Trophy family",
				drawnSymbols("Snappers ★★★"),
				drawnSymbols("★★★"),
				record.id,
			}, { family.rung, family.order, family.title, family.text, family.stamp, family.cast })
			assert.are.equal("string", type(family.icon))
			local celebrated = loaded.env.PagleLedgerDB.global.celebrated
			assert.is_true(celebrated.items[HEAVY])
			assert.are.same({ [1] = true, [2] = true, [3] = true }, celebrated.familyStars[FAMILY])
		end
	)

	it(
		"raise a family's first Trophy weight with no ruler, and its ★★ with the family name left out while it has no lore (LED-R61, LED-R161)",
		function()
			local fake = session()

			fake.playCast("caught", loot(LIGHT))

			local moments = byKind(shown(fake)[1])
			assert.is_nil(moments.trophyWeight.ruler)
			assert.are.same(
				{ drawnSymbols("★★"), drawnSymbols("★★") },
				{ moments.familyStar.text, moments.familyStar.stamp }
			)
		end
	)

	it(
		"raise New curio for a curio item's first Catch, 5 Coins, and nothing for its second (LED-R60, LED-R97)",
		function()
			local fake, loaded = session()
			local record = assert(fake.playCast("caught", loot(JUNK)))

			local curio = castKinds(shown(fake)).newCurio
			assert.are.same(
				{ "toast.low", 110, "New curio", "Soggy Boot", "New!", 5, JUNK, record.id },
				{ curio.rung, curio.order, curio.title, curio.text, curio.stamp, curio.coins, curio.icon, curio.cast }
			)
			assert.is_true(loaded.env.PagleLedgerDB.global.celebrated.items[JUNK])
			local seen = #fake.announcements

			fake.playCast("caught", loot(JUNK))

			assert.are.same({}, shown(fake, seen))
		end
	)

	it(
		"raise Unknown catch, logged for an Uncharted item's first Catch, and nothing for its second (LED-R64, LED-R97)",
		function()
			local fake, loaded = session()
			fake.conditions.zone = 0 -- no zone: no rank to raise beside it

			local record = assert(fake.playCast("caught", loot(UNKNOWN)))

			local announcements = shown(fake)
			assert.are.same({ "uncharted Unknown catch, logged / Item 99001 Logged nil" }, momentsOf(announcements[1]))
			local headline = announcements[1].headline
			assert.are.same(
				{ "nod", 140, UNKNOWN, record.id },
				{ headline.rung, headline.order, headline.icon, headline.cast }
			)
			assert.is_true(loaded.env.PagleLedgerDB.global.celebrated.uncharted[UNKNOWN])

			fake.playCast("caught", loot(UNKNOWN))

			assert.are.same({}, shown(fake, #announcements))
		end
	)

	it("raise Regular (★★★) at a Species' 50th Catch (LED-R45, LED-R97)", function()
		local history = {}
		for i = 1, 49 do
			history[i] = cast(T0 + i, { ANY_1 })
		end
		local fake = session({ history = history })

		local record = assert(fake.playCast("caught", loot(ANY_1)))

		local regular = byKind(shown(fake)[1]).regularStar
		assert.are.same(
			{ "nod", 120, "Regular", "Cove Perch", drawnSymbols("★★★"), ANY_1, record.id },
			{ regular.rung, regular.order, regular.title, regular.text, regular.stamp, regular.icon, regular.cast }
		)
	end)

	it("raise no star already celebrated, and keep it shown (LED-R91, LED-R92)", function()
		local celebrated = { coins = 0, logId = LOG_ID, stars = { [ANY_1] = { [2] = true } } }
		local fake, loaded = session({ saved = { global = { celebrated = celebrated } } })

		fake.playCast("caught", loot(ANY_1))

		assert.is_nil(byKind(shown(fake)[1]).elementStar)
		local ns = loaded.ns
		local stars = ns.ShownSpeciesStars(ns.world, ns.projection:GetState(), ns.CelebratedSet(ns.db.global), ANY_1)
		assert.are.same({ [1] = true, [2] = true }, stars)
	end)

	it(
		"raise nothing for a zone celebrated at Expert, rebuilt to Local by a release, reaching Expert again (LED-R91, LED-R92)",
		function()
			-- The chest is caught where no zone counts it (zone 0), before any list has it.
			local history = { EXPERT[1], EXPERT[2], EXPERT[3], cast(T0 + 180, { CHEST }, { zone = 0 }) }
			local last, lastLoaded = session({ history = history })
			assert.are.equal(4, lastLoaded.env.PagleLedgerDB.global.celebrated.zones[COVE])

			-- A release lists the chest in Cove: its treasure requirement drops the computed rank to Local (LED-R50).
			local fake, loaded = nextSession(last, lastLoaded, { catalogue = catalogue({ entry(CHEST) }, "a release") })
			local ns = loaded.ns
			assert.are.equal(3, ns.projection:GetState().zones[COVE].rank)
			assert.are.equal(
				4,
				ns.ShownZoneRank(ns.world, ns.projection:GetState(), ns.CelebratedSet(ns.db.global), COVE)
			)

			fake.playCast("caught", loot(CHEST))

			assert.are.equal(4, ns.projection:GetState().zones[COVE].rank)
			assert.are.same({}, fake.summarized)
			assert.are.same({}, shown(fake))
			assert.are.equal(4, ns.db.global.celebrated.zones[COVE])
		end
	)

	it("set the summary line to the shown level and Ledger completion (LED-R70, LED-R95)", function()
		local fake = session()

		fake.playCast("caught", loot(ANY_1))

		-- Cove's world: 4 Species, 1 junk item, 2 trophy weights and 1 zone to master. One Species: 1 of 8, 12%.
		assert.are.same({ ledger = "Ledger: Angler Level 1 · 12% complete" }, fake.global.summary.lines.Ledger.lines)
	end)
end)

-- Cove's whole story: Expert by the third Cast, Master with the light trophy, and the chest caught at zone 0 (no list
-- has it). XP (LED-R20, Fresh Water doubling every Catch): 3,560 + 620 + 170 + 1,000 + 120 + 1,250 + 170 = 6,890,
-- level 6 (6,200). Coins (LED-R88): 4 Species 40, 2 curios 10, a trophy weight 5, ranks 2 × 15, 5 levels 100: 185.
local function wholeStory()
	return {
		cast(T0, { ANY_1, ANY_2, ANY_3 }),
		cast(T0 + 60, { NIGHTFISH }, { minute = NIGHT }),
		cast(T0 + 120, { JUNK }),
		cast(T0 + 180, { LIGHT }),
		cast(T0 + 240, { CHEST }, { zone = 0 }),
	}
end

-- Each Write-up section the Ledger raised, as its heading followed by its lines.
---@param fake FakePagle
---@return string[][]
local function writeUps(fake)
	local sections = {}
	for i, section in ipairs(fake.writeUps) do
		sections[i] = { section.heading, unpack(section.lines) }
	end
	return sections
end

describe("the Ledger's M3 done", function()
	it(
		"writes up a first build's zones ranked and mastered, trophy weights and curios, raising no moment (LED-R93, LED-R94)",
		function()
			local fake, loaded = session({ history = wholeStory() })

			assert.are.same({
				{
					"Your Ledger was written up from 5 Casts",
					"Angler Level 6",
					"4 Species",
					"1 zone ranked · 1 mastered",
					"1 trophy weight",
					"2 curios",
					-- M4's titles: Cove's, the Junk Museum's and the Treasures' (LED-R75, LED-R94).
					"Title: Warden of Cove Waters",
					"Title: Collector of Boots",
					"Title: Keeper of Lost Cargo",
					"Pagle Coins +185",
				},
			}, writeUps(fake))
			assert.are.same({}, fake.summarized)
			assert.are.same({}, fake.announcements)
			local celebrated = loaded.env.PagleLedgerDB.global.celebrated
			assert.are.same({ [COVE] = 5 }, celebrated.zones)
			assert.are.same({ [JUNK] = true, [LIGHT] = true, [CHEST] = true }, celebrated.items)
			assert.are.same({ [1] = true, [2] = true }, celebrated.stars[NIGHTFISH])
			assert.are.same({ [FAMILY] = { [1] = true, [2] = true } }, celebrated.familyStars)
			-- Completion: 4 of 4 Species, the junk, the chest, 1 of 2 weights and the zone: 8 of 9 (LED-R70).
			assert.are.same(
				{ ledger = "Ledger: Angler Level 6 · 88% complete" },
				fake.global.summary.lines.Ledger.lines
			)
		end
	)

	it(
		"writes up a catch-up's zone mastered, trophy weight and curio, its star with no line (LED-R93, LED-R94)",
		function()
			local story = wholeStory()
			local last, lastLoaded = session({ history = { story[1], story[2], story[3] } })

			local fake = nextSession(last, lastLoaded, { history = { story[4], story[5] } })

			assert.are.same({
				{
					"While the Ledger was off",
					"Angler Level 5 to 6",
					"1 zone ranked · 1 mastered",
					"1 trophy weight",
					"1 curio",
					"Title: Warden of Cove Waters",
					"Title: Keeper of Lost Cargo",
					"Pagle Coins +40",
				},
			}, writeUps(fake))
			assert.are.same({}, fake.summarized)
		end
	)

	it("writes up a catch-up's new rank as a zone ranked, with no mastered part (LED-R94)", function()
		local story = wholeStory()
		local last, lastLoaded = session({ history = { story[1], story[2] } })

		local fake = nextSession(last, lastLoaded, { history = { story[3] } })

		-- Expert and the junk: 1,000 + 170 XP, from 4,180 past level 5 (4,800); Coins 8 + 5 + 20.
		assert.are.same({
			{
				"While the Ledger was off",
				"Angler Level 4 to 5",
				"1 zone ranked",
				"1 curio",
				"Title: Collector of Boots", -- M4: the junk completes the Junk Museum (LED-R75, LED-R94)
				"Pagle Coins +33",
			},
		}, writeUps(fake))
	end)

	it(
		"raises only summary-only moments when an M2-stored projection is upgraded to M3 (LED-R4, LED-R93, ANN-R63)",
		function()
			local last, lastLoaded = session({ history = wholeStory() })
			-- What M2 stored: its rules version, and a celebrated set with M2's keys alone (LED-R90).
			local saved = lastLoaded.env.PagleLedgerDB
			saved.global.projection.rulesVersion = 100
			saved.global.celebrated = {
				levels = { [0] = 3 },
				species = { [ANY_1] = true, [ANY_2] = true, [ANY_3] = true, [NIGHTFISH] = true },
				speciesZones = {},
				zones = { [COVE] = 0 },
				skill = {},
				coins = 80,
				logId = LOG_ID,
			}

			local fake, loaded = nextSession(last, lastLoaded)

			local kinds = {}
			for _, moment in ipairs(fake.summarized) do
				assert.is_true(moment.summaryOnly)
				kinds[#kinds + 1] = moment.kind
			end
			-- In the order earned, the level-ups merged at the last one's place (LED-R93): the Species, celebrated in
			-- M2, raise nothing again.
			assert.are.same({
				"elementStar",
				"elementStar",
				"elementStar",
				"zoneRank",
				"elementStar",
				"newCurio",
				"zoneRank",
				"trophyWeight",
				"familyStar",
				"zoneMaster",
				"levelUp",
				"newCurio",
				-- M4's completion titles, Junk Museum and Treasures complete (LED-R75, LED-R97).
				"completeTitle",
				"completeTitle",
			}, kinds)
			fake.nextFrame()
			assert.are.same({}, fake.announcements)
			assert.are.same({}, fake.writeUps)
			local celebrated = loaded.env.PagleLedgerDB.global.celebrated
			assert.are.same({ [COVE] = 5 }, celebrated.zones)
			assert.are.same({ [0] = 6 }, celebrated.levels)
		end
	)
end)
