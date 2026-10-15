-- Prestiging on FakePagle (LED-R33, LED-R194, LOG-R38): ns.CanPrestige, the confirm ns.AskPrestige shows, the P1 it
-- appends through M:RecordPrestige, the Journal hiding it, and the emblem block (LED-R34) the Journal's widgets draw.

local T0 = SERVER_TIME - 700
local ZONE = 12 -- uncharted in the catalogue below: no Zone Mastery rank adds to the numbers (LED-R54)
local FIRST_FISH = 100001
-- One Cast landing this many new Species in a new zone reaches level 60 at prestige rank 0: 200 for the zone's first
-- Catch, then 10 + 500 + 100 per Species and 10 more for each of the first 300 in Fresh Water (LED-R20, LED-R22):
-- 200,840 XP against the 200,600 that reaching 60 costs (LED-R30), with 240 carried.
local TO_60_SPECIES = 324

-- A catalogue in the shape of ns.catalogue (DATA-R76): TO_60_SPECIES fish, each its own Species, and no area.
local function catalogue()
	local items = {}
	for i = 0, TO_60_SPECIES - 1 do
		items[FIRST_FISH + i] = fishRecord(FIRST_FISH + i)
	end
	return catalogueWith({ items = items })
end

-- A caught Cast by the player's character (char 1) at `time`, of `count` of the fish from the first.
local function cast(time, count)
	local items = {}
	for i = 1, count do
		items[i] = FIRST_FISH + i - 1
	end
	return castRecord({ time = time, zone = ZONE, items = items })
end

-- A Ledger on a fake over the catalogue, its log holding `records` (a Cast reaching 60 by default) or the saved
-- entries `entries`, logged in and, unless `updating`, in the world (the projection built); the Journal closed.
---@param options { records: table[]?, entries: string[]?, updating: boolean? }?
---@return FakePagle fake
---@return LoadedAddon loaded
local function ledger(options)
	options = options or {}
	return openJournal({
		catalogue = catalogue(),
		log = not options.entries and (options.records or { cast(T0, TO_60_SPECIES) }) or nil,
		entries = options.entries,
		building = options.updating,
		id = false,
	})
end

-- The log's P1 entries (LOG-R38).
---@param fake FakePagle
---@return string[]
local function prestiges(fake)
	local found = {}
	for _, entry in ipairs(fake.catchLog.data.entries) do
		if entry:sub(1, 3) == "P1|" then
			found[#found + 1] = entry
		end
	end
	return found
end

-- Closes the Journal as the player does: the frame hides and its OnHide runs, as the client runs it.
---@param loaded LoadedAddon
local function closeJournal(loaded)
	local frame = loaded.ns.journal.frame
	frame:Hide()
	frame.scripts.OnHide(frame)
end

local CONFIRM = "Begin a new Ledger? Your Angler Level starts again at 1, and climbs at half the cost. Nothing "
	.. "you've earned is taken away."

describe("Prestiging (LED-R33)", function()
	it("is allowed at level 60 once the projection is built (LED-R33)", function()
		local _, loaded = ledger()

		assert.are.equal(60, loaded.ns.Level(loaded.ns.projection:GetState()))
		assert.is_true(loaded.ns.CanPrestige())
	end)

	it("isn't allowed while the projection is updating, nor below 60 (LED-R33)", function()
		local fake, updating = ledger({ updating = true })
		assert.is_false(updating.ns.CanPrestige())
		fake.enterWorld()
		assert.is_true(updating.ns.CanPrestige())

		local _, below = ledger({ records = { cast(T0, TO_60_SPECIES - 1) } })
		assert.are.equal(59, below.ns.Level(below.ns.projection:GetState()))
		assert.is_false(below.ns.CanPrestige())
	end)

	it("asks with a native popup, Prestige or Not yet (LED-R33)", function()
		local _, loaded = ledger()

		loaded.ns.AskPrestige()

		assert.are.same(
			{ which = "PAGLE_LEDGER_PRESTIGE", text = CONFIRM, buttons = { "Prestige", "Not yet" } },
			loaded.client.popup
		)
	end)

	it(
		"appends one P1 through M:RecordPrestige when confirmed at 60, starting the next climb (LED-R33, LOG-R38)",
		function()
			local fake, loaded = ledger()
			local announced = {}
			fake.Pagle.RegisterCallback("Spec", "Prestige", function(_, record)
				announced[#announced + 1] = record.rank
			end)

			loaded.ns.AskPrestige()
			loaded.client.clickPopup(1)

			assert.are.same({ prestigeEntry(SERVER_TIME, 1) }, prestiges(fake))
			assert.are.same({ 1 }, announced)
			assert.is_nil(loaded.client.popup)
			-- Applied live: rank 1, a new climb from the 240 carried XP, so Prestige isn't allowed again yet (LED-R32).
			local state = loaded.ns.projection:GetState()
			assert.are.same({ 1, 240, 1 }, { state.prestige, state.xp, loaded.ns.Level(state) })
			assert.is_false(loaded.ns.CanPrestige())
		end
	)

	it("appends nothing for Not yet (LED-R33)", function()
		local fake, loaded = ledger()

		loaded.ns.AskPrestige()
		loaded.client.clickPopup(2)

		assert.are.same({}, prestiges(fake))
		assert.is_nil(loaded.client.popup)
	end)

	it("checks again when confirmed: once the projection is updating, confirming appends nothing (LED-R33)", function()
		local fake, loaded = ledger()
		loaded.ns.AskPrestige()

		-- The projection starts updating while the popup is up (LOG-R74).
		loaded.ns.projection.IsUpdating = function()
			return true
		end
		loaded.client.clickPopup(1)

		assert.are.same({}, prestiges(fake))
		assert.are.equal(0, loaded.ns.projection:GetState().prestige)
	end)

	it("doesn't ask below 60 (LED-R33)", function()
		local _, loaded = ledger({ records = { cast(T0, 1) } })

		loaded.ns.AskPrestige()

		assert.is_nil(loaded.client.popup)
	end)

	it("hides the popup when the Journal closes (LED-R33)", function()
		local fake, loaded = ledger()
		loaded.ns.journal:Toggle()
		loaded.ns.AskPrestige()

		closeJournal(loaded)

		assert.is_nil(loaded.client.popup)
		assert.are.same({}, prestiges(fake))
	end)

	it("is allowed again after a crash that lost the P1: the climb is still at 60 (LED-R194)", function()
		local before = ledger()
		local saved = {}
		for i, entry in ipairs(before.catchLog.data.entries) do
			saved[i] = entry
		end
		local _, crashed = ledger()
		crashed.ns.AskPrestige()
		crashed.client.clickPopup(1)

		-- The client stopped before the save: the log on disk is the one before the P1 (LOG-R85).
		local _, loaded = ledger({ entries = saved })

		assert.are.same({ 0, 60 }, {
			loaded.ns.projection:GetState().prestige,
			loaded.ns.Level(loaded.ns.projection:GetState()),
		})
		assert.is_true(loaded.ns.CanPrestige())
	end)
end)

describe("the Prestige emblem block (LED-R34)", function()
	-- Opens a spread whose left page is `blocks`, on a Ledger below 60.
	local function drawn(blocks)
		local _, loaded = ledger({ records = { cast(T0, 1) } })
		loaded.ns.RegisterJournalSpread("emblems", {
			crumbs = function()
				return {}
			end,
			draw = function()
				return { left = blocks, right = {} }
			end,
		})
		loaded.ns.journal:Open("emblems")
		return loaded.ns.journal.frame.left.drawn.emblem
	end

	-- The texts an emblem widget shows: its numeral, then each star stamp's.
	local shown = shownTexts

	it("draws the emblem's roman numeral, and a Master Prestige's stars as ink stamps", function()
		local widgets = drawn({
			{ kind = "emblem", mark = { emblem = "I", stars = 0 } },
			{ kind = "emblem", mark = { emblem = "X", stars = 2 } },
		})

		assert.are.same({ "I" }, shown(widgets[1]))
		assert.are.same({ "X", drawnSymbols("★"), drawnSymbols("★") }, shown(widgets[2]))
	end)

	it("draws nothing before the first Prestige", function()
		local widget = drawn({ { kind = "emblem", mark = { stars = 0 } } })[1]

		assert.are.same({}, shown(widget))
	end)
end)
