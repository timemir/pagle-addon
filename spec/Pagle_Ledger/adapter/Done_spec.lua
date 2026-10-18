-- The Ledger's done (LED-R89, LED-R90, LED-R93, LED-R94, LED-R190–R192, LED-R197; ANN-R60, ANN-R63) on FakePagle:
-- what it raises when its projection finishes a first build, a catch-up or a rebuild after login.

local MACKEREL, SMALLFISH, OILY = 6303, 6291, 6358
-- Two zones the generated catalogue doesn't chart (no catch data), so no Zone Mastery rank adds its XP and Coins to
-- these numbers (LED-R54). ZoneMastery_spec.lua has the ranks.
local BADLANDS, BLASTED_LANDS = 3, 4
local T0 = SERVER_TIME - 700

-- The names the fake client's C_Item knows.
local ITEM_NAMES = { [MACKEREL] = "Raw Spotted Yellowtail", [SMALLFISH] = "Raw Brilliant Smallfish" }

-- A Cast record for fake.catchLog:Append, by the player's character (char 1).
---@param time integer
---@param zone integer
---@param itemIDs integer[]? nil for a got-away Cast
local function cast(time, zone, itemIDs)
	return castRecord({ time = time, zone = zone, items = itemIDs, outcome = itemIDs and "caught" or "gotAway" })
end

-- History before the first login: two Species in Badlands, a got-away Cast and a known Species in Blasted Lands. XP: 820 +
-- 620 + 320 = 1,760, level 2 (1,080); Coins 10 + 10 + 20 (LED-R20, LED-R22, LED-R30, LED-R88).
local HISTORY = {
	cast(T0, BADLANDS, { MACKEREL, SMALLFISH }),
	cast(T0 + 60, BADLANDS),
	cast(T0 + 120, BLASTED_LANDS, { MACKEREL }),
}

-- A FakePagle over `log` (a PagleLog table, shared between sessions as the saved one is) with `history` appended
-- before login, and `saved` as PagleLedgerDB: the Ledger loaded, logged in and in the world, fishing live in Blasted
-- Lands (fake.conditions' zone).
---@param options { log: table?, history: table[]?, saved: table?, prepare: fun(fake: FakePagle)? }
---@return FakePagle fake
---@return LoadedAddon loaded
local function session(options)
	local fake = newFakePagle()
	fake.conditions.zone = BLASTED_LANDS
	if options.log then
		fake.catchLog.data = options.log
	end
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
	if options.prepare then
		options.prepare(fake)
	end
	local loaded = fake.load("Pagle_Ledger")
	fake.login()
	fake.enterWorld()
	fake.nextFrame()
	return fake, loaded
end

-- Each Write-up section the Ledger raised, as its heading followed by its lines.
---@param fake FakePagle
---@return string[][]
local function writeUps(fake)
	local sections = {}
	for i, section in ipairs(fake.writeUps) do
		assert.are.equal("Ledger", section.module)
		sections[i] = { section.heading, unpack(section.lines) }
	end
	return sections
end

describe("the Ledger's done", function()
	it(
		"writes up a first build in one section, raising no moment, and marks it all celebrated (LED-R93, LED-R94, LED-R192)",
		function()
			local fake, loaded = session({ history = HISTORY })

			assert.are.same({
				{ "Your Ledger was written up from 3 Casts", "Angler Level 2", "2 Species", "Pagle Coins +40" },
			}, writeUps(fake))
			assert.are.same({}, fake.summarized)
			assert.are.same({}, fake.announcements)
			assert.are.same({ { module = "Ledger", total = 40 } }, fake.coinReports)
			local celebrated = loaded.env.PagleLedgerDB.global.celebrated
			assert.are.same({
				levels = { [0] = 2 },
				species = { [MACKEREL] = true, [SMALLFISH] = true },
				-- No star yet: neither has the 5 Catches of ★ nor is in its element (LED-R45, LED-R90).
				stars = {},
				familyStars = {},
				speciesZones = { ["6303:3"] = true, ["6291:3"] = true, ["6303:4"] = true },
				zones = { [BADLANDS] = 0, [BLASTED_LANDS] = 0 },
				items = {},
				uncharted = {},
				skill = {},
				-- M4's keys: no Prestige or Catch Milestone yet, and the title held from the start (LED-R75).
				prestige = 0,
				milestones = {},
				titles = { ["title:level1"] = true },
				coins = 40,
				logId = fake.catchLog.data.logId,
			}, celebrated)
			assert.are.same(
				{ ledger = "Ledger: Angler Level 2 · 1% complete" },
				fake.global.summary.lines.Ledger.lines
			)
		end
	)

	it("raises nothing for a log with no Cast, and reports a total of 0 (LED-R89, LED-R93, LOG-R76)", function()
		local fake, loaded = session({})

		assert.are.same({}, fake.writeUps)
		assert.are.same({}, fake.summarized)
		assert.are.same({ { module = "Ledger", total = 0 } }, fake.coinReports)
		assert.are.equal(fake.catchLog.data.logId, loaded.env.PagleLedgerDB.global.celebrated.logId)
	end)

	it(
		"empties the celebrated set of another logId and handles the done as a first build (LED-R90, LED-R197)",
		function()
			local _, lastLoaded = session({ history = { cast(T0, BLASTED_LANDS, { OILY }) } })
			local saved = lastLoaded.env.PagleLedgerDB
			saved.global.celebrated.levels[0] = 9
			local oldLogId = saved.global.celebrated.logId

			-- A new log (LOG-R18): its own logId, so Core rebuilds a projection that isn't new (no info.firstBuild).
			local fake, loaded = session({ history = HISTORY, saved = saved })

			assert.are.same({
				{ "Your Ledger was written up from 3 Casts", "Angler Level 2", "2 Species", "Pagle Coins +40" },
			}, writeUps(fake))
			assert.are.same({}, fake.summarized)
			local celebrated = loaded.env.PagleLedgerDB.global.celebrated
			assert.are.same({ [MACKEREL] = true, [SMALLFISH] = true }, celebrated.species)
			assert.are.same({ [0] = 2 }, celebrated.levels)
			assert.are.same({ fake.catchLog.data.logId, 40 }, { celebrated.logId, celebrated.coins })
			assert.are_not.equal(oldLogId, celebrated.logId)
		end
	)

	-- The next session over the last one's log and saved PagleLedgerDB, with `between` recorded before login: the
	-- Casts Core recorded while the Ledger was disabled (LED-R190).
	---@param last FakePagle
	---@param lastLoaded LoadedAddon
	---@param between table[]
	---@param prepare fun(fake: FakePagle)?
	local function nextSession(last, lastLoaded, between, prepare)
		return session({
			log = last.catchLog.data,
			history = between,
			saved = lastLoaded.env.PagleLedgerDB,
			prepare = prepare,
		})
	end

	it(
		"writes up a catch-up's new Species, the level it brought and its Coins, with no moment (LED-R93, LED-R190)",
		function()
			local last, lastLoaded = session({ history = HISTORY })

			-- A new Species, 620 XP to 2,380: level 3 (2,240); and a known one new in Blasted Lands, 120 XP (LED-R20).
			local fake, loaded = nextSession(last, lastLoaded, {
				cast(T0 + 600, BLASTED_LANDS, { OILY }),
				cast(T0 + 660, BLASTED_LANDS, { SMALLFISH }),
			})

			assert.are.same(
				{ { "While the Ledger was off", "Angler Level 2 to 3", "1 Species", "Pagle Coins +30" } },
				writeUps(fake)
			)
			assert.are.same({}, fake.summarized)
			assert.are.same({}, fake.announcements)
			assert.are.same({ { module = "Ledger", total = 70 } }, fake.coinReports)
			local celebrated = loaded.env.PagleLedgerDB.global.celebrated
			assert.is_true(celebrated.species[OILY])
			assert.is_true(celebrated.speciesZones["6291:4"])
			assert.are.same({ [0] = 3 }, celebrated.levels)
			assert.are.equal(70, celebrated.coins)
			assert.are.same(
				{ ledger = "Ledger: Angler Level 3 · 2% complete" },
				fake.global.summary.lines.Ledger.lines
			)
		end
	)

	it(
		"writes up no catch-up whose only new achievement is a Species new in a zone: it has no line (LED-R93, LED-R94)",
		function()
			local last, lastLoaded = session({ history = HISTORY })

			local fake, loaded = nextSession(last, lastLoaded, { cast(T0 + 600, BLASTED_LANDS, { SMALLFISH }) })

			assert.are.same({}, fake.writeUps)
			assert.are.same({}, fake.summarized)
			assert.is_true(loaded.env.PagleLedgerDB.global.celebrated.speciesZones["6291:4"])
		end
	)

	-- An item the catalogue doesn't chart: Uncharted, earning the base only (LED-R5, LED-R196).
	local CHARTED_LATER = 99001

	it(
		"raises a Species a new release charts as a summary-only newSpecies, with its level-up (LED-R93, LED-R191, ANN-R63)",
		function()
			local last, lastLoaded = session({ history = HISTORY })
			local record = assert(last.playCast("caught", { { itemID = CHARTED_LATER, quantity = 1 } }))
			-- 20 XP: still level 2. Uncharted, it raises only its Nod (LED-R97).
			assert.are.same({ "uncharted" }, { last.summarized[1].kind, last.summarized[2] })

			-- The release charts it as a Species: 500 + 100 XP more, past level 3 (2,240), and 10 + 20 Coins.
			local fake, loaded = nextSession(last, lastLoaded, {}, function(next)
				local getItem = next.Pagle.GetItem
				next.Pagle.GetItem = function(itemID)
					if itemID == CHARTED_LATER then
						return { itemID = itemID, category = "fish", species = CHARTED_LATER }
					end
					return getItem(itemID)
				end
				next.Pagle.CONTENT_FINGERPRINT = "a release charting " .. CHARTED_LATER
			end)

			local raised = {}
			for i, moment in ipairs(fake.summarized) do
				raised[i] = ("%s %s / %s %s %s %s"):format(
					moment.kind,
					moment.title,
					tostring(moment.text),
					tostring(moment.coins),
					tostring(moment.cast == record.id),
					tostring(moment.summaryOnly)
				)
			end
			-- On no list, one zone puts it in its element: ★★ with its first Catch (LED-R45, LED-R97).
			assert.are.same({
				"newSpecies New Species / Item 99001 10 true true",
				"elementStar In its element / Item 99001 nil true true",
				"levelUp Angler Level 3 / nil 20 true true",
			}, raised)
			fake.nextFrame()
			assert.are.same({}, fake.announcements)
			assert.are.same({}, fake.writeUps)
			assert.are.same({ { module = "Ledger", total = 70 } }, fake.coinReports)
			local celebrated = loaded.env.PagleLedgerDB.global.celebrated
			assert.is_true(celebrated.species[CHARTED_LATER])
			assert.are.same({ [0] = 3 }, celebrated.levels)
		end
	)

	it("raises nothing at a second login with nothing new (LED-R93)", function()
		local last, lastLoaded = session({ history = HISTORY })

		local fake = nextSession(last, lastLoaded, {})

		assert.are.same({}, fake.writeUps)
		assert.are.same({}, fake.summarized)
		assert.are.same({}, fake.announcements)
		assert.are.same({ { module = "Ledger", total = 40 } }, fake.coinReports)
	end)

	it("empties the set for a new, empty log, raising nothing: its achievements celebrate afresh (LED-R197)", function()
		local _, lastLoaded = session({ history = HISTORY })

		local fake, loaded = session({ saved = lastLoaded.env.PagleLedgerDB })
		fake.playCast("caught", { { itemID = MACKEREL, quantity = 1 } })

		assert.are.same({}, fake.writeUps)
		assert.are.equal("newSpecies", fake.summarized[1].kind)
		assert.are.same({ [MACKEREL] = true }, loaded.env.PagleLedgerDB.global.celebrated.species)
	end)
end)
