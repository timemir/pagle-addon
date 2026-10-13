-- The Session summary as Core runs it, through the real TOC (announcements.md › Session summary): moments Modules
-- raise reach PagleDB.global.summary, and SessionEnded (#80) turns a Session that earned one into a card in
-- PagleDB.global.cards, which spec/Pagle/adapter/Cards_spec.lua shows.

local OILY_BLACKMOUTH = "|cffffffff|Hitem:6358::::::::15:::::::::|h[Oily Blackmouth]|h|r"
local FISHING = 7731

-- The build entry the fake client's build matches, so login appends no B1.
local BUILD = ("B1|1|%d|0|70338|1.60.1"):format(SERVER_TIME - 5000)

-- Ada's caught Cast of one Oily Blackmouth at server time `time`.
local function cast(time)
	return ("C1|1|%d|0|c|494|1439|1|148|453|86|25|263|||6358x1"):format(time)
end

-- Core over a saved log holding `entries` and PagleDB `saved`, if given, its server time SERVER_TIME plus the
-- client's clock, with the Ledger and Hunts installed.
local function core(entries, saved)
	local clock
	local loaded = loadAddon(
		"Pagle",
		foreverWith({
			PagleLog = savedLog(entries),
			PagleDB = saved,
			GetServerTime = function()
				return SERVER_TIME + math.floor(clock and clock() or 0)
			end,
		})
	)
	clock = loaded.client.time
	for _, name in ipairs({ "Ledger", "Hunts" }) do
		loaded.client.addons["Pagle_" .. name] = { metadata = { ["X-Pagle-API"] = "1" } }
	end
	return loaded
end

-- Registers a Module whose projection raises `raise(record)`'s moment for each live Cast it applies.
local function moduleRaising(loaded, name, order, raise)
	local M = loaded.env.Pagle.RegisterModule({ name = name, title = name, order = order })
	M:NewProjection({
		db = {},
		rulesVersion = 1,
		reset = function()
			return {}
		end,
		apply = function(_, record, mode)
			if record.kind == "cast" and mode == "live" then
				M:RaiseMoment(raise(record))
			end
		end,
	})
	return M
end

local function login(loaded)
	loaded.client.fire("PLAYER_LOGIN")
	loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)
	loaded.client.advance(0)
end

-- Plays a caught Cast of one Oily Blackmouth on the fake client, then lets the next frame flush its moments.
local function catchOne(loaded)
	loaded.client.fire("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-1", FISHING)
	loaded.client.loot = { fishing = true, slots = { { link = OILY_BLACKMOUTH, quantity = 1 } } }
	loaded.client.fire("LOOT_READY", true)
	loaded.client.fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-1", FISHING)
	loaded.client.fire("LOOT_CLOSED")
	loaded.client.advance(0)
end

-- Each card's moments as { module, { titles } } pairs, card by card.
local function cardMoments(cards)
	local all = {}
	for c, card in ipairs(cards) do
		all[c] = {}
		for g, group in ipairs(card.moments) do
			local titles = {}
			for i, moment in ipairs(group.moments) do
				titles[i] = moment.title
			end
			all[c][g] = { group.module, titles }
		end
	end
	return all
end

describe("the Session summary on the client", function()
	it(
		"ends a Session with two Modules' moments as one card: Core's numbers, the Coins sum and both Modules'"
			.. " moments by Module order, highest rung first, writing nothing to PagleLog (ANN-R25, ANN-R53, ANN-R56)",
		function()
			local loaded = core({ BUILD })
			moduleRaising(loaded, "Hunts", 20, function(record)
				return {
					rung = "toast.high",
					kind = "huntCompleted",
					title = "Hunt completed",
					cast = record.id,
					coins = 5,
				}
			end)
			local ledger = moduleRaising(loaded, "Ledger", 10, function(record)
				return { rung = "toast.low", kind = "sizeRecord", title = "Size record", cast = record.id, coins = 3 }
			end)
			login(loaded)
			catchOne(loaded)
			ledger:RaiseMoment({ rung = "banner", kind = "levelUp", title = "Angler Level 12" })
			loaded.client.advance(60)
			catchOne(loaded)
			local log = loaded.env.PagleLog
			local entries = { unpack(log.entries) }

			loaded.client.advance(900)

			local cards = loaded.env.PagleDB.global.cards
			assert.are.equal(1, #cards)
			assert.are.same({ casts = 2, catches = 2, gotAway = 0, seconds = 60 }, cards[1].numbers)
			assert.are.equal(16, cards[1].coins)
			assert.are.same({
				{
					{ "Ledger", { "Angler Level 12", "Size record", "Size record" } },
					{ "Hunts", { "Hunt completed", "Hunt completed" } },
				},
			}, cardMoments(cards))
			assert.are.same({}, loaded.env.PagleDB.global.summary.moments)
			assert.are.equal(log, loaded.env.PagleLog)
			assert.are.same(entries, log.entries)
		end
	)

	it("ends a Session with no moment with no card, even with summary lines set (ANN-R51, ANN-R53)", function()
		local loaded = core({ BUILD })
		local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
		M:SetSummaryLine("level", "Angler Level 12")
		login(loaded)
		catchOne(loaded)

		loaded.client.advance(900)

		assert.are.same({}, loaded.env.PagleDB.global.cards)
		assert.are.equal("Angler Level 12", loaded.env.PagleDB.global.summary.lines.Ledger.lines.level)
	end)

	it("puts a moment raised before the first Cast on that Session's card (ANN-R52)", function()
		local loaded = core({ BUILD })
		local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
		login(loaded)
		M:RaiseMoment({ rung = "nod", kind = "loginNod", title = "Welcome back" })
		loaded.client.advance(0)
		assert.are.equal("Welcome back", loaded.env.PagleDB.global.pending[1].title)

		catchOne(loaded)
		loaded.client.advance(900)

		assert.are.same({ { { "Ledger", { "Welcome back" } } } }, cardMoments(loaded.env.PagleDB.global.cards))
		assert.are.same({}, loaded.env.PagleDB.global.pending)
	end)

	it(
		"leaves a disabled Module's lines off a card, and puts them back on the next card once it registers again"
			.. " (ANN-R51, ANN-R90)",
		function()
			-- Last login, with both Modules on, each set a line, and a Session raised a moment and ended.
			local first = core({ BUILD })
			local ledger = first.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			local hunts = first.env.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
			ledger:SetSummaryLine("level", "Angler Level 12")
			hunts:SetSummaryLine("pinned", "Hunts: 2 pinned")
			login(first)
			catchOne(first)
			ledger:RaiseMoment({ rung = "toast", kind = "newSpecies", title = "New Species" })
			first.client.advance(900)

			-- This login, Hunts is disabled, so it never registers.
			local second = core({ BUILD }, { global = first.env.PagleDB.global })
			local again = second.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			login(second)
			catchOne(second)
			again:RaiseMoment({ rung = "toast", kind = "newSpecies", title = "New Species" })
			second.client.advance(900)

			-- The next login, Hunts is back.
			local third = core({ BUILD }, { global = second.env.PagleDB.global })
			local ledger3 = third.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			third.env.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
			login(third)
			catchOne(third)
			ledger3:RaiseMoment({ rung = "toast", kind = "newSpecies", title = "New Species" })
			third.client.advance(900)

			local lines = {}
			for c, card in ipairs(third.env.PagleDB.global.cards) do
				lines[c] = {}
				for g, group in ipairs(card.lines) do
					lines[c][g] = { group.module, group.lines }
				end
			end
			assert.are.same({
				{ { "Ledger", { "Angler Level 12" } }, { "Hunts", { "Hunts: 2 pinned" } } },
				{ { "Ledger", { "Angler Level 12" } } },
				{ { "Ledger", { "Angler Level 12" } }, { "Hunts", { "Hunts: 2 pinned" } } },
			}, lines)
		end
	)

	it(
		"makes the card of a Session that ended while away, from the moments saved before a crash, marked whileAway"
			.. ' and titled "Your last session" (ANN-R54, ANN-R94)',
		function()
			-- The last login crashed mid-Session: its Casts and one moment were saved, its end never came.
			local saved = {
				global = {
					summary = {
						moments = {
							{
								module = "Ledger",
								moduleTitle = "Ledger",
								moduleOrder = 10,
								kind = "newSpecies",
								rung = "toast",
								title = "New Species",
							},
						},
						lines = {},
					},
				},
			}
			local loaded = core({ BUILD, cast(SERVER_TIME - 2000), cast(SERVER_TIME - 1990) }, saved)
			local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			login(loaded)
			M:RaiseMoment({ rung = "nod", kind = "loginNod", title = "Welcome back" })
			loaded.client.advance(0)

			local cards = loaded.env.PagleDB.global.cards
			assert.are.equal(1, #cards)
			assert.is_true(cards[1].whileAway)
			assert.are.equal("Your last session", cards[1].title)
			assert.are.same({ casts = 2, catches = 2, gotAway = 0, seconds = 10 }, cards[1].numbers)
			assert.are.same({ { { "Ledger", { "New Species" } } } }, cardMoments(cards))
			assert.are.equal("Welcome back", loaded.env.PagleDB.global.pending[1].title)
		end
	)

	it("raises an error at the Module's call for a bad key or text, setting nothing (ANN-R51)", function()
		local loaded = core({ BUILD })
		local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })

		for _, args in ipairs({ { nil, "text" }, { "", "text" }, { 1, "text" }, { "level", 12 } }) do
			local ok, err = pcall(M.SetSummaryLine, M, args[1], args[2])
			assert.is_false(ok)
			assert.matches("SetSummaryLine", err)
		end
		local ok, err = pcall(M.SetSummaryLine, {}, "level", "x")
		assert.is_false(ok)
		assert.matches("SetSummaryLine is a Module handle method", err)
		assert.is_nil(next(loaded.env.PagleDB.global.summary and loaded.env.PagleDB.global.summary.lines or {}))
	end)
end)
