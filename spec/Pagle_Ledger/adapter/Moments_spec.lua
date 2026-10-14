-- The Ledger's live moments, the celebrated set, Coins and the summary line (LED-R36, LED-R89–R92, LED-R95–R97,
-- LED-R193, LED-R194) on FakePagle: the Announcements Core would show for each live entry.

local MACKEREL, SMALLFISH, BLACKMOUTH, TROUT = 6303, 6291, 6289, 6308
local ELWYNN, WESTFALL, DARKSHORE = 12, 40, 148
-- Where the live Casts here are fished: a zone the generated catalogue doesn't chart (no catch data), so no Zone
-- Mastery rank adds its XP and Coins to these numbers (LED-R54). ZoneMastery_spec.lua has the ranks.
local BLASTED_LANDS = 4
local T0 = 1791731000
-- The fake log's logId, which a saved celebrated set names to belong to it (LED-R90).
local LOG_ID = "0123456789abcdef"

-- The names the fake client's C_Item and C_Map know.
local ITEM_NAMES = { [MACKEREL] = "Raw Spotted Yellowtail", [SMALLFISH] = "Raw Brilliant Smallfish" }
local ZONE_NAMES = {
	[ELWYNN] = "Elwynn Forest",
	[WESTFALL] = "Westfall",
	[DARKSHORE] = "Darkshore",
	[BLASTED_LANDS] = "Blasted Lands",
}

-- A Cast record for fake.catchLog:Append, by the player's character (char 1).
---@param time integer
---@param zone integer
---@param itemIDs integer[]
local function cast(time, zone, itemIDs)
	local items = {}
	for i, itemID in ipairs(itemIDs) do
		items[i] = { itemID = itemID, quantity = 1 }
	end
	return {
		kind = "cast",
		char = 1,
		time = time,
		outcome = "caught",
		conditions = { minute = 494, zone = zone, subzone = 0, events = {}, auras = {} },
		items = items,
	}
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

-- A FakePagle with `history` (Cast records) in its log and `saved` as PagleLedgerDB, the Ledger loaded on it,
-- logged in and in the world: every live Cast after this is fished in Blasted Lands, fake.conditions' zone. The
-- log's logId is LOG_ID.
---@param history table[]?
---@param saved table?
---@param extra table? more client globals for the Ledger's load
---@return FakePagle fake
---@return LoadedAddon loaded
local function session(history, saved, extra)
	local fake = newFakePagle()
	fake.conditions.zone = BLASTED_LANDS
	fake.catchLog.data.logId = LOG_ID
	fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
	for _, record in ipairs(history or {}) do
		fake.catchLog:Append(record)
	end
	if saved then
		fake.globals.PagleLedgerDB = saved
	end
	fake.globals.C_Item = {
		GetItemNameByID = function(itemID)
			return ITEM_NAMES[itemID]
		end,
	}
	fake.globals.C_Map = {
		GetAreaInfo = function(areaID)
			return ZONE_NAMES[areaID]
		end,
	}
	fake.globals.BreakUpLargeNumbers = breakUpLargeNumbers
	for key, value in pairs(extra or {}) do
		fake.globals[key] = value
	end
	local loaded = fake.load("Pagle_Ledger")
	fake.login()
	fake.enterWorld()
	return fake, loaded
end

-- The Announcements shown since the spec last looked, once the frame after runs.
---@param fake FakePagle
---@param seen integer? how many were already looked at
---@return PagleAnnouncement[]
local function shown(fake, seen)
	fake.nextFrame()
	return { unpack(fake.announcements, (seen or 0) + 1) }
end

-- Each moment of an Announcement as "<kind> <title> / <text> <coins>".
---@param announcement PagleAnnouncement
---@return string[]
local function momentsOf(announcement)
	local lines = {}
	for i, moment in ipairs(announcement.moments) do
		lines[i] = ("%s %s / %s %s"):format(moment.kind, moment.title, tostring(moment.text), tostring(moment.coins))
	end
	return lines
end

describe("the Ledger's live moments", function()
	it(
		"raise one Announcement for a new Species in a new zone: New Species, +10, no New here (LED-R96, LED-R97)",
		function()
			local fake = session()

			local record = assert(fake.playCast("caught", loot(MACKEREL)))

			local announcements = shown(fake)
			assert.are.equal(1, #announcements)
			local announcement = announcements[1]
			assert.are.same({ "newSpecies New Species / Raw Spotted Yellowtail 10" }, momentsOf(announcement))
			assert.are.same(
				{ "New Species", "toast", 10 },
				{ announcement.headline.title, announcement.rung, announcement.coins }
			)
			assert.are.same({ MACKEREL, record.id, "New!", 100 }, {
				announcement.headline.icon,
				announcement.headline.cast,
				announcement.headline.stamp,
				announcement.headline.order,
			})
		end
	)

	it(
		"raise a New here Nod for a known Species in a new zone, and celebrate the pair and the zone (LED-R90, LED-R97)",
		function()
			-- Caught before with no zone (0), so the two stay below level 2: 520 + 320 XP.
			local fake, loaded = session({ cast(T0, 0, { MACKEREL }) })

			local record = assert(fake.playCast("caught", loot(MACKEREL)))

			local announcements = shown(fake)
			assert.are.equal(1, #announcements)
			assert.are.same(
				{ "newInZone New here / Raw Spotted Yellowtail in Blasted Lands nil" },
				momentsOf(announcements[1])
			)
			local headline = announcements[1].headline
			assert.are.same(
				{ "nod", 100, "New here", MACKEREL, record.id },
				{ headline.rung, headline.order, headline.stamp, headline.icon, headline.cast }
			)
			local celebrated = loaded.env.PagleLedgerDB.global.celebrated
			assert.are.same({ ["6303:4"] = true }, celebrated.speciesZones)
			assert.are.same({ [BLASTED_LANDS] = 0 }, celebrated.zones)
		end
	)

	it("name an item the client doesn't have yet Item {id}, and a zone with no name … (LED-R97, LED-R126)", function()
		local fake = session({ cast(T0, 0, { TROUT }) })
		fake.conditions.zone = 999 -- a zone C_Map.GetAreaInfo has no name for

		fake.playCast("caught", loot(TROUT))

		assert.are.same({ "newInZone New here / Item 6308 in … nil" }, momentsOf(shown(fake)[1]))
	end)

	it("raise nothing and report no Coins for an ordinary Catch or a got-away Cast (LED-R89, LED-R96)", function()
		local fake = session()
		fake.playCast("caught", loot(MACKEREL))
		local seen = #shown(fake)

		fake.playCast("caught", loot(MACKEREL))
		fake.playCast("gotAway")

		assert.are.same({}, shown(fake, seen))
		-- The first is the projection's done's, at login (LED-R89).
		assert.are.same({ { module = "Ledger", total = 0 }, { module = "Ledger", total = 10 } }, fake.coinReports)
	end)

	it(
		"report a Zone Mastery rank's Coins with its Cast's, raising no moment for the rank (LED-R51, LED-R88)",
		function()
			local fake, loaded = session()
			fake.conditions.zone = DARKSHORE -- charted: its first Catch makes the Angler a Visitor there

			fake.playCast("caught", loot(MACKEREL))

			assert.are.same({ "newSpecies New Species / Raw Spotted Yellowtail 10" }, momentsOf(shown(fake)[1]))
			assert.are.same(
				{ { module = "Ledger", total = 0 }, { module = "Ledger", total = 10 + 2 } },
				fake.coinReports
			)
			assert.are.equal(1, loaded.ns.projection:GetState().zones[DARKSHORE].rank)
		end
	)

	it("report the Coins total after each live entry that changes it (LED-R89, SHOP-R2)", function()
		local fake, loaded = session()

		fake.playCast("caught", loot(MACKEREL))
		fake.playCast("caught", loot(MACKEREL))
		fake.playCast("caught", loot(SMALLFISH))

		-- The second Species also takes the climb to level 2 (820 + 20 + 620 XP): 10, then 10 + 10 + 20.
		assert.are.same(
			{ { module = "Ledger", total = 0 }, { module = "Ledger", total = 10 }, { module = "Ledger", total = 40 } },
			fake.coinReports
		)
		assert.are.equal(40, loaded.env.PagleLedgerDB.global.celebrated.coins)
	end)

	-- Four new Species in a new zone in one Cast: 200 + 4 × (2 × 10 + 500 + 100) = 2,680 XP, past level 2 (1,080) and
	-- level 3 (1,080 + 1,160) (LED-R20, LED-R22, LED-R30).
	local FOUR = { MACKEREL, SMALLFISH, BLACKMOUTH, TROUT }

	it(
		"raise one levelUp for the higher level of a Cast crossing two, with +2 levels and 40 Coins (LED-R97)",
		function()
			local fake = session()

			local record = assert(fake.playCast("caught", loot(unpack(FOUR))))

			local announcements = shown(fake)
			assert.are.equal(1, #announcements)
			local announcement = announcements[1]
			assert.are.same({ "levelUp Angler Level 3 / +2 levels 40" }, { momentsOf(announcement)[1] })
			assert.are.equal(5, #announcement.moments) -- and four New Species
			local headline = announcement.headline
			assert.are.same(
				{ "banner", 100, "Level 3", record.id },
				{ headline.rung, headline.order, headline.stamp, headline.cast }
			)
			assert.are.equal("string", type(headline.icon))
			assert.are.equal(80, announcement.coins)
			assert.are.same({ { module = "Ledger", total = 0 }, { module = "Ledger", total = 80 } }, fake.coinReports)
		end
	)

	it("set the summary line to the shown level after a live entry changes it (LED-R95)", function()
		local fake = session()

		fake.playCast("caught", loot(unpack(FOUR)))

		assert.are.same({ ledger = "Ledger: Angler Level 3" }, fake.global.summary.lines.Ledger.lines)
	end)

	it("raise Skill Milestone with no cast for a Skill Reading past 75 (LED-R96, LED-R97)", function()
		local fake = session()

		fake.readSkill(80, 150, 0)

		local announcements = shown(fake)
		assert.are.equal(1, #announcements)
		assert.are.same({ "skillMilestone Skill Milestone / Fishing 75 nil" }, momentsOf(announcements[1]))
		local headline = announcements[1].headline
		assert.are.same({ "toast", 130 }, { headline.rung, headline.order })
		assert.is_nil(headline.cast)
		assert.is_nil(headline.stamp)
		assert.are.equal("string", type(headline.icon))
	end)

	it(
		"raise nothing for an achievement celebrated earlier and earned again after a rebuild dropped it (LED-R91)",
		function()
			-- The celebrated set holds what the log no longer earns before login: Skill Milestone 75, the Species and
			-- level 2, which the two reach again (1,000 + 820 XP).
			local celebrated = {
				coins = 30,
				skill = { [75] = true },
				species = { [MACKEREL] = true },
				levels = { [0] = 2 },
				logId = LOG_ID,
			}
			local fake = session(nil, { global = { celebrated = celebrated } })

			fake.readSkill(80, 150, 0)
			fake.playCast("caught", loot(MACKEREL))

			assert.are.same({}, shown(fake))
			-- The Cast's level's 20 and new Species' 10 Coins still count, in the total only (LED-R97).
			assert.are.same({ { module = "Ledger", total = 0 }, { module = "Ledger", total = 30 } }, fake.coinReports)
		end
	)

	it(
		"use the celebrated level when above the computed one, raising no level at or below it (LED-R36, LED-R92)",
		function()
			local fake, loaded =
				session(nil, { global = { celebrated = { coins = 0, levels = { [0] = 9 }, logId = LOG_ID } } })

			fake.playCast("caught", loot(unpack(FOUR)))

			local kinds = {}
			for _, moment in ipairs(shown(fake)[1].moments) do
				kinds[moment.kind] = true
			end
			assert.is_nil(kinds.levelUp)
			assert.are.same({ ledger = "Ledger: Angler Level 9" }, fake.global.summary.lines.Ledger.lines)
			local state = loaded.ns.projection:GetState()
			assert.are.equal(3, loaded.ns.Level(state))
			assert.are.equal(9, loaded.ns.ShownLevel(state, loaded.env.PagleLedgerDB.global.celebrated))
			-- Their 40 Coins count, in the total only (LED-R36).
			assert.are.same({ { module = "Ledger", total = 0 }, { module = "Ledger", total = 80 } }, fake.coinReports)
		end
	)

	it("pay a levelUp only the levels above the celebrated one (LED-R97)", function()
		local fake, loaded =
			session(nil, { global = { celebrated = { coins = 0, levels = { [0] = 2 }, logId = LOG_ID } } })

		fake.playCast("caught", loot(unpack(FOUR)))

		assert.are.same({ "levelUp Angler Level 3 / nil 20" }, { momentsOf(shown(fake)[1])[1] })
		assert.are.same({ [0] = 3 }, loaded.env.PagleLedgerDB.global.celebrated.levels)
	end)

	it("keep raising in combat, for Core to hold (LED-R193)", function()
		local fake, loaded = session()
		setCombat(loaded, true)

		fake.playCast("caught", loot(MACKEREL))

		assert.are.equal("newSpecies", fake.summarized[1].kind)
	end)

	-- A deep copy, as SavedVariables would hand back what was last saved.
	local function copy(value)
		if type(value) ~= "table" then
			return value
		end
		local result = {}
		for key, item in pairs(value) do
			result[key] = copy(item)
		end
		return result
	end

	it("celebrate again what a crash lost with its Casts (LED-R194)", function()
		local history = { cast(T0, ELWYNN, { SMALLFISH }) }
		local fake, loaded = session(history)
		local lastSaved = copy(loaded.env.PagleLedgerDB)
		fake.playCast("caught", loot(MACKEREL))
		local celebrated = momentsOf(shown(fake)[1])
		assert.are.same({
			"levelUp Angler Level 2 / nil 20",
			"newSpecies New Species / Raw Spotted Yellowtail 10",
		}, celebrated)

		-- The crash: neither that Cast nor the celebrated set's growth was saved.
		local after = session(history, lastSaved)
		after.playCast("caught", loot(MACKEREL))

		assert.are.same(celebrated, momentsOf(shown(after)[1]))
	end)
end)
