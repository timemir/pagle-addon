-- The recording command on every real addon TOC: manual catch, native navigation and purchase, then restoration.

local function ready()
	local loaded = loadAddon("Pagle", foreverWith({ PagleLog = savedLog({ BUILD_ENTRY }) }), {
		also = { "Pagle_Ledger", "Pagle_Stats", "Pagle_Hunts", "Pagle_TackleBoard", "Pagle_QoL" },
	})
	loaded.client.areaNames[148] = "Darkshore"
	loaded.env.GetRealZoneText = function()
		return "Darkshore"
	end
	enterWorld(loaded, 5)
	loaded.client.advance(20)
	return loaded
end

describe("the continuous Pagle trailer", function()
	it("records the manual catch, exercises every scene, and discards demo purchases and progression", function()
		local loaded = ready()
		local core = loaded.namespaces.Pagle
		local db, log = core.db, loaded.env.PagleLog
		local ledger = loaded.namespaces.Pagle_Ledger
		local stats = loaded.namespaces.Pagle_Stats
		local hunts = loaded.namespaces.Pagle_Hunts
		local board = loaded.namespaces.Pagle_TackleBoard
		local projections = { ledger.projection, stats.projection, hunts.projection, board.projection }
		local before = #log.entries
		local realXP = loaded.env.Pagle.GetActivityXP()
		local crest = ledger.ZoneCrestOf(core.Catalogue.GetZoneOf(148)).id
		local crestOwned = loaded.env.Pagle.IsOwned(crest)

		loaded.env.SlashCmdList.PAGLE("trailer")
		assert.are.same({}, loaded.client.errors)
		assert.matches("trailer armed", loaded.printed[#loaded.printed])
		assert.are.equal(before, #log.entries)
		catchOne(loaded)
		loaded.client.advance(0)
		assert.are.same({}, loaded.client.errors)
		assert.are.equal(1, #core.lanes.column)
		assert.are.equal("sizeRecord", core.lanes.column[1].announcement.headline.kind)
		assert.is_nil(core.lanes.centre)
		assert.are.equal(before + 1, #log.entries)
		assert.are_not.equal(db, core.db)
		assert.is_true(stats.State().places[core.Catalogue.GetZoneOf(148)].casts >= 100)
		assert.is_true(board.State().fire.count >= 100)
		assert.is_true(next(board.State().flies) ~= nil)
		assert.is_true(loaded.env.Pagle.GetBalance().balance >= 5000)
		local savedAfterCatch = core.TrailerCopy(loaded.env.PagleDB)

		-- The sample's own Activity XP, from its Hunts and Board, and the home water mastered for its crest.
		local staged = loaded.env.Pagle.GetActivityXP()
		assert.is_true(staged.bySource.Hunts.total > 0)
		assert.is_true(staged.bySource.TackleBoard.total > 0)
		assert.is_true(loaded.env.Pagle.IsOwned(crest))

		local crestBefore = loaded.env.Pagle.GetEquipped("core.crest")
		loaded.client.advance(205)
		assert.are.same({}, loaded.client.errors)
		assert.is_true(loaded.env.Pagle.IsOwned("core.toaststyle.ripple"))
		assert.are.equal("core.toaststyle.ripple", loaded.env.Pagle.GetEquipped("core.toaststyle"))
		-- The home water's crest on the Angler page's bookplate, not in the shop, which lists no earned crest (SHOP-R25).
		assert.are.equal(crest, loaded.env.Pagle.GetEquipped("core.crest"))
		assert.is_true(ledger.journal:IsShown())
		assert.is_false(core.shopFrame:IsShown())
		assert.are.equal(before + 1, #log.entries)
		loaded.client.advance(60)

		assert.are.same({}, loaded.client.errors)
		assert.are.equal(db, core.db)
		assert.are.equal(log, loaded.env.PagleLog)
		assert.are.equal(before + 1, #log.entries)
		assert.are.same(projections, { ledger.projection, stats.projection, hunts.projection, board.projection })
		assert.is_false(loaded.env.Pagle.IsOwned("core.toaststyle.ripple"))
		assert.are.same(savedAfterCatch, loaded.env.PagleDB)
		assert.are.same(realXP, loaded.env.Pagle.GetActivityXP())
		assert.are.equal(crestOwned, loaded.env.Pagle.IsOwned(crest))
		assert.are.equal(crestBefore, loaded.env.Pagle.GetEquipped("core.crest"))
		assert.matches("trailer complete", loaded.printed[#loaded.printed])
	end)

	it("leaves the Angler's onboarding alone as its scenes open the windows (CORE-R68)", function()
		local loaded = ready()
		local core = loaded.namespaces.Pagle
		assert.is_false(core.onboarding:IsEveningItemDone("shop"))
		loaded.env.SlashCmdList.PAGLE("trailer")
		catchOne(loaded)
		for _ = 1, 260 do
			loaded.client.advance(1)
			assert.is_nil(core.firstLooks:Showing())
			assert.are.same({}, core.marginNotes:Showing())
			assert.is_false(core.onboarding:IsEveningItemDone("shop"))
		end
		assert.are.same({}, loaded.client.errors)
	end)

	it("restores on cancellation and prevents old timers from acting during a new take", function()
		local loaded = ready()
		local core = loaded.namespaces.Pagle
		local db = core.db
		loaded.env.SlashCmdList.PAGLE("trailer")
		catchOne(loaded)
		loaded.client.advance(30)
		loaded.env.SlashCmdList.PAGLE("trailer stop")
		assert.are.equal(db, core.db)
		loaded.client.advance(20)
		loaded.env.SlashCmdList.PAGLE("trailer")
		loaded.client.advance(270)
		assert.are.equal(db, core.db)
		loaded.env.SlashCmdList.PAGLE("trailer status")
		assert.are.equal("Pagle trailer: armed", loaded.printed[#loaded.printed])
		loaded.client.fire("PLAYER_LOGOUT")
		loaded.env.SlashCmdList.PAGLE("trailer status")
		assert.are.equal("Pagle trailer: idle", loaded.printed[#loaded.printed])
		assert.are.same({}, loaded.client.errors)
	end)

	it("cancels the choreography and restores the account when combat starts", function()
		local loaded = ready()
		local core = loaded.namespaces.Pagle
		local db = core.db
		loaded.env.SlashCmdList.PAGLE("trailer")
		catchOne(loaded)
		loaded.client.advance(15)
		setCombat(loaded, true)
		assert.are.equal(db, core.db)
		loaded.env.SlashCmdList.PAGLE("trailer")
		assert.are.equal(core.L.TRAILER_AFTER_COMBAT, loaded.printed[#loaded.printed])
		loaded.client.advance(265)
		loaded.env.SlashCmdList.PAGLE("trailer status")
		assert.are.equal("Pagle trailer: idle", loaded.printed[#loaded.printed])
		assert.is_false(loaded.env.Pagle.IsOwned("core.toaststyle.ripple"))
		assert.are.same({}, loaded.client.errors)
	end)
end)
