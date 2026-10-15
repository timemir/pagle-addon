-- The Ledger's M4 moments (LED-R90–R92, LED-R97): Legends, Prestige ready and Prestiges, Catch Milestones, titles,
-- size records and the size on a New Species toast; their Write-up lines (LED-R93, LED-R94) and the Prestige in the
-- summary line (LED-R95), on FakePagle over a fixture catalogue with Core's own Simulated Sizes (LOG-R65): the
-- Announcements, Write-up sections and summary line Core would show.

local T0 = SERVER_TIME - 700
-- The fake log's logId, which a saved celebrated set names to belong to it (LED-R90).
local LOG_ID = "0123456789abcdef"
-- A zone the catalogue doesn't chart: no Zone Mastery rank adds to the numbers (LED-R54).
local ZONE = 12
-- Fish of their own Species, typical length 30 cm (LOG-R67). Landing TO_60 of them new in one Cast in a new zone
-- reaches level 60 at rank 0 with 240 XP carried (as adapter/Prestige_spec.lua works out): 200 for the zone, then 610
-- per Species (Catch 10, new 500, in the zone 100) and 10 more for each of the first 300 in Fresh Water (LED-R20,
-- LED-R22), 200,840 against the 200,600 reaching 60 costs (LED-R30).
local FIRST_FISH, FISH_COUNT, TO_60 = 100001, 524, 324
-- One Species with three items of very different typical lengths, so a Catch of the next is always longer.
local PIKE, BIG_PIKE, HUGE_PIKE = 90040, 90041, 90042
-- A Legend item (LED-R5), with its title in the Ledger's lore batch: "Racer-Chaser" (LED-R75).
local LEGEND = 19803
-- The one charted zone, listing one junk item: the Junk Museum's whole total (LED-R71).
local COVE, JUNK = 9001, 90010

local ITEM_NAMES = {
	[JUNK] = "Soggy Boot",
	[PIKE] = "Cove Pike",
	[BIG_PIKE] = "Big Cove Pike",
	[HUGE_PIKE] = "Huge Cove Pike",
	[LEGEND] = "Brownell's Blue Striped Racer",
}

-- A fish item of Species `species`, `typicalLength` mm (DATA-R19, LOG-R55).
local function fish(species, typicalLength, legend)
	return fishRecord(species, { typicalLength = typicalLength, legend = legend or false })
end

-- A catalogue in the shape of ns.catalogue (DATA-R76), charting Cove with its junk alone.
---@param fingerprint string?
local function catalogue(fingerprint)
	local items = {
		[PIKE] = fish(PIKE, 300),
		[BIG_PIKE] = fish(PIKE, 3000),
		[HUGE_PIKE] = fish(PIKE, 30000),
		[LEGEND] = fish(LEGEND, 900, true),
		[JUNK] = itemRecord("junk"),
	}
	for id = FIRST_FISH, FIRST_FISH + FISH_COUNT - 1 do
		items[id] = fish(id, 300)
	end
	return catalogueWith({
		fingerprint = fingerprint,
		items = items,
		areas = { [COVE] = areaRecord(0, { catches = { catchEntry(JUNK) } }) },
	})
end

-- `count` of the fish from fish number `from` (1 for the first), as item IDs.
---@param from integer
---@param count integer
---@return integer[]
local function fishes(from, count)
	local ids = {}
	for i = 1, count do
		ids[i] = FIRST_FISH + from + i - 2
	end
	return ids
end

-- `n` of `itemID`.
---@param itemID integer
---@param n integer
---@return integer[]
local function times(itemID, n)
	local ids = {}
	for i = 1, n do
		ids[i] = itemID
	end
	return ids
end

-- A caught Cast record for fake.catchLog:Append by the player's character, in `zone` (ZONE by default).
---@param time integer
---@param itemIDs integer[]
---@param zone integer?
local function cast(time, itemIDs, zone)
	return castRecord({ time = time, zone = zone or ZONE, items = itemIDs })
end

-- A Prestige record to `rank` (LOG-R38) for fake.catchLog:Append.
local function prestige(time, rank)
	return { kind = "prestige", char = 1, time = time, rank = rank }
end

-- Loot of one item each, for fake.playCast.
---@param itemIDs integer[]
---@return PagleLootItem[]
local function loot(itemIDs)
	local items = {}
	for i, itemID in ipairs(itemIDs) do
		items[i] = { itemID = itemID, quantity = 1 }
	end
	return items
end

-- A FakePagle over `options.log` (a PagleLog shared between sessions) with `history` appended and `saved` as
-- PagleLedgerDB, serving `options.catalogue` (the fixture by default): the Ledger loaded, logged in and in the world,
-- fishing live in ZONE. Each Catch's size, as Core made it, is noted in `sizes` by item ID, latest last.
---@param options { log: table?, history: table[]?, saved: table?, catalogue: table? }?
---@return FakePagle fake
---@return LoadedAddon loaded
---@return { [integer]: PagleSize[] } sizes
local function session(options)
	options = options or {}
	local fake = newFakePagle()
	fake.setCatalogue(options.catalogue or catalogue())
	fake.conditions.zone = ZONE
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
		GetAreaInfo = function() end,
	}
	fake.globals.BreakUpLargeNumbers = breakUpLargeNumbers
	local loaded = fake.load("Pagle_Ledger")
	local sizes = {}
	fake.Pagle.RegisterCallback("Spec", "Catch", function(_, catch)
		sizes[catch.itemID] = sizes[catch.itemID] or {}
		table.insert(sizes[catch.itemID], catch.size)
	end)
	fake.login()
	fake.enterWorld()
	fake.nextFrame()
	return fake, loaded, sizes
end

-- The next session over the last one's log and saved PagleLedgerDB, with `history` recorded before login.
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

-- Every moment of `announcements` by kind (the last of a kind wins).
---@param announcements PagleAnnouncement[]
---@return { [string]: PagleMoment }
local function byKind(announcements)
	local kinds = {}
	for _, announcement in ipairs(announcements) do
		for _, moment in ipairs(announcement.moments) do
			kinds[moment.kind] = moment
		end
	end
	return kinds
end

-- A size's text as Core's band names and length unit write it (LED-R81: "{band} · {length}").
---@param fake FakePagle
---@param size PagleSize
---@return string
local function sizeText(fake, size)
	return fake.Pagle.SIZE_BANDS[size.band].name .. " · " .. fake.Pagle.FormatLength(size.length)
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

-- The Ledger's summary line as Core holds it (LED-R95).
---@param fake FakePagle
---@return string
local function summaryLine(fake)
	return fake.global.summary.lines.Ledger.lines.ledger
end

describe("the Ledger's M4 live moments", function()
	it(
		"raise one Legend splash with its size text, its title and 100 Coins, and nothing again for its second Catch (LED-R63, LED-R97)",
		function()
			local fake, loaded, sizes = session()

			local record = assert(fake.playCast("caught", loot({ LEGEND })))

			local legend = byKind(shown(fake)).legend
			assert.are.same({
				"splash",
				100,
				"Legend",
				("Brownell's Blue Striped Racer · %s. Title: Racer-Chaser"):format(sizeText(fake, sizes[LEGEND][1])),
				"Legend!",
				100,
				LEGEND,
				record.id,
			}, {
				legend.rung,
				legend.order,
				legend.title,
				legend.text,
				legend.stamp,
				legend.coins,
				legend.icon,
				legend.cast,
			})
			local celebrated = loaded.env.PagleLedgerDB.global.celebrated
			assert.is_true(celebrated.items[LEGEND])
			assert.is_true(celebrated.titles["legend:" .. LEGEND])
			local seen = #fake.announcements

			fake.playCast("caught", loot({ LEGEND }))

			assert.is_nil(byKind(shown(fake, seen)).legend)
			assert.are.equal(2, loaded.ns.projection:GetState().items[LEGEND].n)
		end
	)

	it(
		"raise Prestige ready once with a climb's 60, then Prestige I with +100 and its title, and Prestige ready again at the next climb's 60 (LED-R32, LED-R34, LED-R90, LED-R97)",
		function()
			local fake, loaded = session({ history = { cast(T0, fishes(1, TO_60 - 1)) } })
			local ns = loaded.ns
			assert.are.equal(59, ns.Level(ns.projection:GetState()))

			local record = assert(fake.playCast("caught", loot(fishes(TO_60, 1))))

			local moments = byKind(shown(fake))
			local ready = moments.prestigeReady
			assert.are.same({
				"banner",
				110,
				"Prestige ready",
				"Open the Fish Journal to begin a new Ledger.",
				"Prestige ready",
				record.id,
			}, { ready.rung, ready.order, ready.title, ready.text, ready.stamp, ready.cast })
			assert.are.equal("string", type(ready.icon))
			-- The level title earned with the level-up rides in it (LED-R97).
			assert.are.same({ "Angler Level 60", "Title: Nat's Peer" }, { moments.levelUp.title, moments.levelUp.text })
			local seen = #fake.announcements

			fake.playCast("caught", loot(fishes(TO_60, 1)))
			assert.is_nil(byKind(shown(fake, seen)).prestigeReady)
			seen = #fake.announcements

			fake.prestige()

			local announcements = shown(fake, seen)
			assert.are.equal(1, #announcements)
			local raised = announcements[1].headline
			assert.are.same(
				{ "banner", 90, "prestige", "Prestige I", "Title: Returning Tide", 100 },
				{ raised.rung, raised.order, raised.kind, raised.title, raised.text, raised.coins }
			)
			assert.is_nil(raised.cast)
			assert.are.equal("string", type(raised.icon))
			assert.are.equal(100, announcements[1].coins)
			assert.are.equal(1, ns.db.global.celebrated.prestige)
			seen = #fake.announcements

			-- The next climb, at half the cost, reaches 60 with 200 more Species (LED-R30).
			fake.playCast("caught", loot(fishes(TO_60 + 1, 200)))

			local next = byKind(shown(fake, seen))
			assert.are.equal("Prestige ready", next.prestigeReady.title)
			assert.are.same({ [0] = 60, [1] = 60 }, ns.db.global.celebrated.levels)
		end
	)

	it("name the level-10 title on the level-up that reaches it (LED-R75, LED-R97)", function()
		-- 24 new Species at zone 0 in Fresh Water: 24 × 520 = 12,480 XP, level 9 (LED-R30); one more makes 13,000.
		local fake, loaded = session({ history = { cast(T0, fishes(1, 24), 0) } })
		assert.are.equal(9, loaded.ns.Level(loaded.ns.projection:GetState()))
		fake.conditions.zone = 0

		fake.playCast("caught", loot(fishes(25, 1)))

		local levelUp = byKind(shown(fake)).levelUp
		assert.are.same({ "Angler Level 10", "Title: Dabbler", "Level 10", 20 }, {
			levelUp.title,
			levelUp.text,
			levelUp.stamp,
			levelUp.coins,
		})
		assert.is_true(loaded.ns.db.global.celebrated.titles["title:level10"])
	end)

	it("raise a 1,000 Catches banner at the 1,000th lifetime Catch (LED-R42, LED-R97)", function()
		local fake, loaded = session({ history = { cast(T0, times(FIRST_FISH, 999), 0) } })

		local record = assert(fake.playCast("caught", loot({ FIRST_FISH })))

		local milestone = byKind(shown(fake)).catchMilestone
		assert.are.same(
			{ "banner", 130, "1,000 Catches", "1,000 Catches", record.id },
			{ milestone.rung, milestone.order, milestone.title, milestone.stamp, milestone.cast }
		)
		assert.is_nil(milestone.text)
		assert.is_nil(milestone.coins)
		assert.are.equal("string", type(milestone.icon))
		assert.is_true(loaded.ns.db.global.celebrated.milestones[1000])
	end)

	it("show the size text on a New Species toast (LED-R81, LED-R97)", function()
		local fake, _, sizes = session()

		fake.playCast("caught", loot({ PIKE }))

		local new = byKind(shown(fake)).newSpecies
		assert.are.equal("Cove Pike · " .. sizeText(fake, sizes[PIKE][1]), new.text)
		assert.is_nil(new.ruler)
		assert.are_not.equal("Record", new.stamp)
	end)

	it(
		"raise a Size record at toast.low with the Pagle size ruler for a strictly longer Catch (LED-R82, LED-R97, ANN-R22)",
		function()
			local fake, loaded, sizes = session({ history = { cast(T0, { PIKE }, 0) } })
			local old = loaded.ns.projection:GetState().species[PIKE].record

			local record = assert(fake.playCast("caught", loot({ HUGE_PIKE })))

			local new = sizes[HUGE_PIKE][1]
			local size = byKind(shown(fake)).sizeRecord
			assert.are.same({
				"toast.low",
				100,
				"Size record",
				"Huge Cove Pike · " .. sizeText(fake, new),
				"Record",
				HUGE_PIKE,
				record.id,
				{ old = old.length, new = new.length, unit = "length", label = "Pagle size" },
			}, { size.rung, size.order, size.title, size.text, size.stamp, size.icon, size.cast, size.ruler })
			assert.is_nil(size.coins)
			-- Records are never in the celebrated set (LED-R84): the item beating it isn't noted anywhere in it.
			for _, set in pairs(loaded.ns.db.global.celebrated) do
				if type(set) == "table" then
					assert.is_nil(set[HUGE_PIKE])
				end
			end
		end
	)

	it("raise a Size record at toast when the beaten record stood 50 Catches of its Species (LED-R82)", function()
		local history = { cast(T0, { BIG_PIKE }, 0), cast(T0 + 60, times(PIKE, 50), 0) }
		local fake, loaded = session({ history = history })
		assert.are.equal(50, loaded.ns.projection:GetState().species[PIKE].since)

		fake.playCast("caught", loot({ HUGE_PIKE }))

		assert.are.equal("toast", byKind(shown(fake)).sizeRecord.rung)
	end)

	it("raise Title earned for a completion title, with the title as its stamp (LED-R75, LED-R97)", function()
		local fake, loaded = session()
		fake.conditions.zone = COVE

		local record = assert(fake.playCast("caught", loot({ JUNK })))

		local title = byKind(shown(fake)).completeTitle
		assert.are.same(
			{ "banner", 140, "Title earned", "Collector of Boots", "Title: Collector of Boots", record.id },
			{ title.rung, title.order, title.title, title.text, title.stamp, title.cast }
		)
		assert.are.equal("string", type(title.icon))
		assert.is_true(loaded.ns.db.global.celebrated.titles["title:complete.junk"])
	end)

	it(
		"seal each banner: the level, the Catches, the book for Prestige ready, the crest and the quill (announcements.md › Contracts)",
		function()
			local climb = session({ history = { cast(T0, fishes(1, TO_60 - 1)) } })
			climb.playCast("caught", loot(fishes(TO_60, 1)))
			local reached = byKind(shown(climb))
			local seen = #climb.announcements
			climb.prestige()
			local prestiged = byKind(shown(climb, seen))

			local catches = session({ history = { cast(T0, times(FIRST_FISH, 999), 0) } })
			catches.playCast("caught", loot({ FIRST_FISH }))

			local titled = session()
			titled.conditions.zone = COVE
			titled.playCast("caught", loot({ JUNK }))

			assert.are.same({ 60, "book", "crest", 1000, "quill" }, {
				reached.levelUp.seal,
				reached.prestigeReady.seal,
				prestiged.prestige.seal,
				byKind(shown(catches)).catchMilestone.seal,
				byKind(shown(titled)).completeTitle.seal,
			})
		end
	)

	it("set the summary line with the prestige rank above 0 (LED-R95)", function()
		local fake = session({ history = { cast(T0, fishes(1, TO_60)) } })

		fake.prestige()

		-- Completion is World's (LED-R70): the 324 Species caught against Cove's uncaught junk.
		assert.matches("^Ledger: Prestige 1 · Angler Level 1 · %d+%% complete$", summaryLine(fake))
	end)
end)

describe("the Ledger's M4 done", function()
	it(
		"writes up a first build's Prestige, Legends, Catches and three titles plus the rest, raising no moment (LED-R93, LED-R94)",
		function()
			local history = {
				cast(T0, fishes(1, TO_60)),
				prestige(T0 + 60, 1),
				cast(T0 + 120, { LEGEND }, 0),
				cast(T0 + 180, times(FIRST_FISH, 1000 - TO_60 - 1), 0),
			}
			local fake, loaded = session({ history = history })

			local sections = writeUps(fake)
			assert.are.equal(1, #sections)
			local lines = sections[1]
			assert.are.equal("Your Ledger was written up from 3 Casts", lines[1])
			assert.matches("^Angler Level %d+ · Prestige 1$", lines[2])
			-- Titles: level 10 to 60, prestige1 and the Legend's, in LED-R75's order; Minnow is never listed.
			assert.are.same({
				"324 Species",
				"1 Legend",
				"1,000 Catches",
				"Title: Dabbler",
				"Title: Line-Caster",
				"Title: Fisher",
				"+5 more titles",
			}, { unpack(lines, 3, 9) })
			assert.matches("^Pagle Coins %+", lines[10])
			assert.are.equal(10, #lines)
			assert.are.same({}, fake.announcements)
			assert.are.same({}, fake.summarized)
			local celebrated = loaded.ns.db.global.celebrated
			assert.are.same({ [1000] = true }, celebrated.milestones)
			assert.are.equal(1, celebrated.prestige)
			assert.is_true(celebrated.items[LEGEND])
			assert.is_true(celebrated.titles["title:prestige1"])
			assert.is_true(celebrated.titles["legend:" .. LEGEND])
			assert.matches("^Ledger: Prestige 1 · Angler Level %d+ · %d+%% complete$", summaryLine(fake))
		end
	)

	it(
		"writes up a catch-up crossing a Prestige with the new climb's levels alone, and the titles it earned (LED-R36, LED-R93, LED-R94)",
		function()
			local last, lastLoaded = session({ history = { cast(T0, fishes(1, TO_60 - 1)) } })

			-- 60, the Prestige with 240 carried, then 20 Species at half cost: 12,440 XP, level 16 (LED-R30, LED-R32).
			local fake, loaded = nextSession(last, lastLoaded, {
				history = {
					cast(T0 + 60, fishes(TO_60, 1)),
					prestige(T0 + 90, 1),
					cast(T0 + 120, fishes(TO_60 + 1, 20)),
				},
			})

			assert.are.same({
				{
					"While the Ledger was off",
					"Angler Level 1 to 16 · Prestige 1",
					"21 Species",
					"Title: Nat's Peer",
					"Title: Returning Tide",
					"Pagle Coins +630",
				},
			}, writeUps(fake))
			assert.are.same({}, fake.announcements)
			assert.are.same({ [0] = 60, [1] = 16 }, loaded.ns.db.global.celebrated.levels)
		end
	)

	it(
		"raises what an M3-stored projection upgraded to M4 newly earns as summary-only moments, never a size record (LED-R4, LED-R84, LED-R93)",
		function()
			local history = {
				cast(T0, fishes(1, 24), 0),
				cast(T0 + 60, { PIKE, BIG_PIKE, LEGEND }, 0),
				cast(T0 + 120, times(FIRST_FISH, 1000 - 27), 0),
			}
			local last, lastLoaded = session({ history = history })
			-- As M3 stored it: rules version 201, its Legend a Species, and no M4 key in the celebrated set.
			local global = lastLoaded.env.PagleLedgerDB.global
			global.projection.rulesVersion = 201
			local celebrated = global.celebrated
			celebrated.items[LEGEND], celebrated.species[LEGEND] = nil, true
			celebrated.milestones, celebrated.titles, celebrated.prestige = nil, nil, nil

			local fake, loaded = nextSession(last, lastLoaded)

			assert.are.same({}, fake.announcements)
			assert.are.same({}, fake.writeUps)
			local kinds = {}
			for _, moment in ipairs(fake.summarized) do
				assert.is_true(moment.summaryOnly)
				kinds[#kinds + 1] = moment.kind
			end
			table.sort(kinds)
			assert.are.same({ "catchMilestone", "legend" }, kinds)
			local legend = fake.summarized[1].kind == "legend" and fake.summarized[1] or fake.summarized[2]
			assert.matches("Title: Racer%-Chaser$", legend.text)
			-- Titles whose moments were celebrated before titles were join the set with no moment.
			assert.is_true(loaded.ns.db.global.celebrated.titles["title:level10"])
		end
	)

	it(
		"fills the celebrated prestige rank, Catch Milestones and titles a rebuild newly earns, with no pop-up (LED-R90, LED-R93)",
		function()
			local history = {
				cast(T0, fishes(1, TO_60)),
				prestige(T0 + 60, 1),
				cast(T0 + 120, times(FIRST_FISH, 1000 - TO_60), 0),
			}
			local last, lastLoaded = session({ history = history })
			-- As M3 stored it: an older rules version, and no M4 key in the celebrated set.
			local global = lastLoaded.env.PagleLedgerDB.global
			global.projection.rulesVersion = 201
			global.celebrated.milestones, global.celebrated.titles, global.celebrated.prestige = nil, nil, nil

			local fake, loaded = nextSession(last, lastLoaded)

			local celebrated = loaded.ns.db.global.celebrated
			assert.are.same({ 1, true, true }, {
				celebrated.prestige,
				celebrated.milestones[1000],
				celebrated.titles["title:prestige1"],
			})
			assert.are.same({}, fake.announcements)
			assert.are.same({}, fake.writeUps)
		end
	)

	it("raises no size record when a rebuild changes the records (LED-R84)", function()
		local last, lastLoaded = session({ history = { cast(T0, { PIKE }, 0), cast(T0 + 60, { BIG_PIKE }, 0) } })

		-- A release retunes the Species' lengths: the projection rebuilds, its records with it.
		local fake = nextSession(last, lastLoaded, { catalogue = catalogue("a release") })

		for _, moment in ipairs(fake.summarized) do
			assert.are_not.equal("sizeRecord", moment.kind)
		end
		assert.are.same({}, fake.announcements)
	end)
end)
