-- Prestiging on FakePagle (LED-R33, LED-R194, LOG-R38): ns.CanPrestige, the Journal's confirm card ns.AskPrestige
-- shows, the P1 it appends through M:RecordPrestige, the Journal hiding it, each source's Activity XP saved with it
-- for Where your XP came from (LED-R150), and the emblem block (LED-R34) the Journal's widgets draw.

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
-- entries `entries`, logged in and, unless `updating`, in the world (the projection built); the Journal open on the
-- Angler page, or closed with `closed`. `modules` registers other Modules before the Ledger loads (openJournal's).
---@param options { records: table[]?, entries: string[]?, updating: boolean?, closed: boolean?, motion: boolean?, modules: fun(fake: FakePagle)? }?
---@return FakePagle fake
---@return LoadedAddon loaded
local function ledger(options)
	options = options or {}
	local id ---@type false?
	if options.closed then
		id = false
	end
	return openJournal({
		catalogue = catalogue(),
		log = not options.entries and (options.records or { cast(T0, TO_60_SPECIES) }) or nil,
		entries = options.entries,
		building = options.updating,
		id = id,
		place = not options.closed and { "angler" } or nil,
		motion = options.motion,
		modules = options.modules,
	})
end

-- Clicks the confirm card's "Prestige" (1) or "Not yet" (2), as the player does.
---@param loaded LoadedAddon
---@param button 1|2
local function clickCard(loaded, button)
	local card = assert(loaded.ns.journal.prestigeCard, "no confirm card")
	local target = button == 1 and card.yes or card.no
	target.scripts.OnClick(target)
end

-- The log's P1 entries (LOG-R38).
---@param fake FakePagle
---@return string[]
local function prestiges(fake)
	local found = {}
	for _, entry in ipairs(logEntries(fake.catchLog.data)) do
		if entry:sub(1, 3) == "P1|" then
			found[#found + 1] = entry
		end
	end
	return found
end

-- Closes the Journal as the player does: the frame hides, and its OnHide runs, as the client runs it.
---@param loaded LoadedAddon
local function closeJournal(loaded)
	loaded.ns.journal.frame:Hide()
end

local CONFIRM = {
	"Prestige",
	"Begin a new Ledger?",
	"Your Angler Level climbs again from 1. Nothing you've earned is taken away.",
}

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

	it(
		"asks on the Journal's own card, Prestige or Not yet, the emblem of the rank to come at 64 on its top"
			.. " (LED-R33, LED-R152)",
		function()
			local fake, loaded = ledger()

			loaded.ns.AskPrestige()

			local card = loaded.ns.journal.prestigeCard
			assert.is_true(loaded.ns.IsPrestigeConfirmShown())
			assert.are.same({ CONFIRM[1], CONFIRM[2], CONFIRM[3], "Prestige", "Not yet" }, shownTexts(card))
			local atlas, sprite = fake.ns.ATLASES.PrestigeEmblems, fake.ns.ATLASES.PrestigeEmblems.sprites["emblem-i"]
			assert.are.same({ atlas.file, sprite.x / atlas.width, sprite.y / atlas.height, 64, true }, {
				card.emblem.texture,
				card.emblem.texCoord[1],
				card.emblem.texCoord[3],
				card.emblem.width,
				card.emblem:IsShown(),
			})
			assert.is_nil(loaded.client.popup)
		end
	)

	it(
		"drops the card in over the darkened book with the open sound and the stamp as the seal lands (LED-R33)",
		function()
			local _, loaded = ledger({ motion = true })
			local sounds = #loaded.client.sounds

			loaded.ns.AskPrestige()
			local card = loaded.ns.journal.prestigeCard
			assert.are.equal(0, card.shade.alpha)
			loaded.client.update(0.5)

			assert.are.equal(0.55, card.shade.alpha)
			assert.are.same({ "850 SFX", "1204 SFX" }, { unpack(loaded.client.sounds, sounds + 1) })
		end
	)

	it(
		"appends one P1 through M:RecordPrestige when confirmed at 60, starting the next climb (LED-R33, LOG-R38)",
		function()
			local fake, loaded = ledger()
			local announced = {}
			fake.Pagle.RegisterCallback("Spec", "Prestige", function(_, record)
				announced[#announced + 1] = record.rank
			end)

			loaded.ns.AskPrestige()
			clickCard(loaded, 1)

			assert.are.same({ prestigeEntry(SERVER_TIME, 1) }, prestiges(fake))
			assert.are.same({ 1 }, announced)
			assert.is_false(loaded.ns.IsPrestigeConfirmShown())
			-- Applied live: rank 1, a new climb from the 240 carried XP, so Prestige isn't allowed again yet (LED-R32).
			local state = loaded.ns.projection:GetState()
			assert.are.same({ 1, 240, 1 }, { state.prestige, state.xp, loaded.ns.Level(state) })
			assert.is_false(loaded.ns.CanPrestige())
		end
	)

	it(
		"saves each source's Activity XP total with the Prestige, splitting the next climb by their rises (LED-R150, LED-R37)",
		function()
			local handles = {}
			local fake, loaded = ledger({
				modules = function(fake)
					for name, order in pairs({ Hunts = 20, TackleBoard = 40 }) do
						local handle = fake.Pagle.RegisterModule({ name = name, title = name, order = order })
						handle:NewProjection({
							db = {},
							rulesVersion = 1,
							reset = function()
								return {}
							end,
							apply = function() end,
							done = function()
								handle:ReportXPEarned(name == "Hunts" and 1500 or 900)
							end,
						})
						handles[name] = handle
					end
				end,
			})

			loaded.ns.AskPrestige()
			clickCard(loaded, 1)

			-- The P1 snapshots Core's 2,400 (AXP-R5); the Ledger keeps each source's part of it, outside the projection.
			assert.are.same({ prestigeEntry(SERVER_TIME, 1, 0, 1, 2400) }, prestiges(fake))
			assert.are.same(
				{ rank = 1, activityXP = 2400, totals = { Hunts = 1500, TackleBoard = 900 } },
				loaded.env.PagleLedgerDB.global.prestigeSources
			)

			-- Hunts rises to 2,100 and the Tackle Board to 1,100: this climb's 800 is their 600 and 200. The climb's own
			-- XP is the 2,640 carried: 200,840 own and 2,400 Activity XP past the 200,600 reaching 60 cost (LED-R31,
			-- LED-R32); the Ledger's own all told stays 200,840.
			handles.Hunts:ReportXPEarned(2100)
			handles.TackleBoard:ReportXPEarned(1100)
			loaded.client.runTimers()
			local climb = {}
			for _, block in ipairs(loaded.ns.journal.pages.right) do
				if block.kind == "xpSource" and not block.header then
					climb[#climb + 1] = { block.text, block.value, block.total }
				end
			end
			assert.are.same({
				{ "Catches and discoveries", "2,640", "200,840" },
				{ "Hunts", "600", "2,100" },
				{ "Tackle Board", "200", "1,100" },
			}, climb)
		end
	)

	it("appends nothing for Not yet (LED-R33)", function()
		local fake, loaded = ledger()

		loaded.ns.AskPrestige()
		clickCard(loaded, 2)

		assert.are.same({}, prestiges(fake))
		assert.is_false(loaded.ns.IsPrestigeConfirmShown())
	end)

	it("checks again when confirmed: once the projection is updating, confirming appends nothing (LED-R33)", function()
		local fake, loaded = ledger()
		loaded.ns.AskPrestige()

		-- The projection starts updating while the card is up (LOG-R74).
		loaded.ns.projection.IsUpdating = function()
			return true
		end
		clickCard(loaded, 1)

		assert.are.same({}, prestiges(fake))
		assert.are.equal(0, loaded.ns.projection:GetState().prestige)
		assert.is_nil(loaded.env.PagleLedgerDB.global.prestigeSources) -- nothing saved without a Prestige (LED-R150)
	end)

	it("doesn't ask below 60 (LED-R33)", function()
		local _, loaded = ledger({ records = { cast(T0, 1) } })

		loaded.ns.AskPrestige()

		assert.is_false(loaded.ns.IsPrestigeConfirmShown())
	end)

	it("doesn't ask with the Journal closed (LED-R33)", function()
		local _, loaded = ledger({ closed = true })

		loaded.ns.AskPrestige()

		assert.is_false(loaded.ns.IsPrestigeConfirmShown())
	end)

	it("hides the card when the Journal closes (LED-R33)", function()
		local fake, loaded = ledger()
		loaded.ns.AskPrestige()

		closeJournal(loaded)

		assert.is_false(loaded.ns.journal.prestigeCard:IsShown())
		assert.are.same({}, prestiges(fake))
	end)

	it(
		"hides the card for good when the Journal closes as Not yet's fade plays, never faint and live (LED-R33)",
		function()
			local fake, loaded = ledger({ motion = true })
			loaded.ns.AskPrestige()
			loaded.client.update(0.5)
			local card = loaded.ns.journal.prestigeCard

			clickCard(loaded, 2)
			loaded.client.update(0.05)
			closeJournal(loaded)
			loaded.client.update(0.05)

			assert.are.same({ false, 1 }, { card:IsShown(), card.alpha })
			assert.is_false(loaded.ns.IsPrestigeConfirmShown())
			assert.are.same({}, prestiges(fake))
		end
	)

	it("is allowed again after a crash that lost the P1: the climb is still at 60 (LED-R194)", function()
		local before = ledger()
		local saved = {}
		for i, entry in ipairs(logEntries(before.catchLog.data)) do
			saved[i] = entry
		end
		local _, crashed = ledger()
		crashed.ns.AskPrestige()
		clickCard(crashed, 1)

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
	local fake
	local function drawn(blocks)
		local loaded
		fake, loaded = ledger({ records = { cast(T0, 1) } })
		loaded.ns.RegisterJournalSpread("emblems", {
			crumbs = function()
				return {}
			end,
			draw = function()
				return { left = blocks, right = {} }
			end,
		})
		loaded.ns.journal:Open("emblems")
		return loaded.ns.journal.shown.left.drawn.emblem
	end

	-- Its stars shown.
	local function stars(widget)
		local count = 0
		for _, star in ipairs(widget.stars) do
			count = count + (star:IsShown() and 1 or 0)
		end
		return count
	end
	-- The emblem sprite its texture shows, by its texture coordinates in Core's emblems atlas.
	local function emblemOf(widget)
		local atlas = fake.ns.ATLASES.PrestigeEmblems
		for name, sprite in pairs(atlas.sprites) do
			if
				widget.emblem.texCoord[1] == sprite.x / atlas.width
				and widget.emblem.texCoord[3] == sprite.y / atlas.height
			then
				return name
			end
		end
		return nil
	end

	it(
		"draws Core's emblem for the rank at 34, its numeral in its art, and a Master Prestige's stars (LED-R152)",
		function()
			local widgets = drawn({
				{ kind = "emblem", mark = { emblem = "I", stars = 0, rank = 1 } },
				{ kind = "emblem", mark = { emblem = "X", stars = 2, rank = 12 } },
			})

			assert.are.same({ "emblem-i", 0, 34 }, { emblemOf(widgets[1]), stars(widgets[1]), widgets[1].emblem.width })
			assert.are.same({ "emblem-master", 2 }, { emblemOf(widgets[2]), stars(widgets[2]) })
			assert.is_true(widgets[1].emblem:IsShown())
		end
	)

	it("draws nothing before the first Prestige", function()
		local widget = drawn({ { kind = "emblem", mark = { stars = 0, rank = 0 } } })[1]

		assert.are.same({ false, 0 }, { widget.emblem:IsShown(), stars(widget) })
	end)
end)
