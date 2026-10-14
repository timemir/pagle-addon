-- The Session summary as Core runs it, through the real TOC (announcements.md › Session summary): moments Modules
-- raise reach PagleDB.global.summary, and SessionEnded (#80) turns a Session that earned one into a card in
-- PagleDB.global.cards, which spec/Pagle/adapter/Cards_spec.lua shows.

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
			local loaded = loadCore({ BUILD_ENTRY })
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
			enterWorld(loaded, 1)
			catchAndFlush(loaded)
			ledger:RaiseMoment({ rung = "banner", kind = "levelUp", title = "Angler Level 12" })
			loaded.client.advance(60)
			catchAndFlush(loaded)
			local log = loaded.env.PagleLog
			local entries = { unpack(log.entries) }

			loaded.client.advance(300)

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
		local loaded = loadCore({ BUILD_ENTRY })
		local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
		M:SetSummaryLine("level", "Angler Level 12")
		enterWorld(loaded, 1)
		catchAndFlush(loaded)

		loaded.client.advance(300)

		assert.are.same({}, loaded.env.PagleDB.global.cards)
		assert.are.equal("Angler Level 12", loaded.env.PagleDB.global.summary.lines.Ledger.lines.level)
	end)

	it("puts a moment raised before the first Cast on that Session's card (ANN-R52)", function()
		local loaded = loadCore({ BUILD_ENTRY })
		local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
		enterWorld(loaded, 1)
		M:RaiseMoment({ rung = "nod", kind = "loginNod", title = "Welcome back" })
		loaded.client.advance(0)
		assert.are.equal("Welcome back", loaded.env.PagleDB.global.pending[1].title)

		catchAndFlush(loaded)
		loaded.client.advance(300)

		assert.are.same({ { { "Ledger", { "Welcome back" } } } }, cardMoments(loaded.env.PagleDB.global.cards))
		assert.are.same({}, loaded.env.PagleDB.global.pending)
	end)

	it(
		"leaves a disabled Module's lines off a card, and puts them back on the next card once it registers again"
			.. " (ANN-R51, ANN-R90)",
		function()
			-- Last login, with both Modules on, each set a line, and a Session raised a moment and ended.
			local first = loadCore({ BUILD_ENTRY })
			local ledger = first.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			local hunts = first.env.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
			ledger:SetSummaryLine("level", "Angler Level 12")
			hunts:SetSummaryLine("pinned", "Hunts: 2 pinned")
			enterWorld(first, 1)
			catchAndFlush(first)
			ledger:RaiseMoment({ rung = "toast", kind = "newSpecies", title = "New Species" })
			first.client.advance(300)

			-- This login, Hunts is disabled, so it never registers.
			local second = loadCore({ BUILD_ENTRY }, first.env.PagleDB)
			local again = second.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			enterWorld(second, 1)
			catchAndFlush(second)
			again:RaiseMoment({ rung = "toast", kind = "newSpecies", title = "New Species" })
			second.client.advance(300)

			-- The next login, Hunts is back.
			local third = loadCore({ BUILD_ENTRY }, second.env.PagleDB)
			local ledger3 = third.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			third.env.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
			enterWorld(third, 1)
			catchAndFlush(third)
			ledger3:RaiseMoment({ rung = "toast", kind = "newSpecies", title = "New Species" })
			third.client.advance(300)

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
			local loaded =
				loadCore({ BUILD_ENTRY, castEntry(SERVER_TIME - 2000), castEntry(SERVER_TIME - 1990) }, saved)
			local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			enterWorld(loaded, 1)
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
		local loaded = loadCore({ BUILD_ENTRY })
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
