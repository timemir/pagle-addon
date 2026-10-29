-- The active title on FakePagle (LED-R77; ledger.md › Data, `profile.activeTitle`): ns.SetActiveTitle stores only an
-- earned key or nil, and the Journal's context carries the stored key, read as automatic while it isn't earned.

-- A Ledger on a fresh fake, logged in and in the world over an empty log, the Journal closed.
---@return FakePagle fake
---@return LoadedAddon loaded
local function ledger()
	return openJournal({ id = false })
end

describe("the active title", function()
	it("is set by ns.SetActiveTitle to an earned key or nil, never to one not earned (LED-R77)", function()
		local _, loaded = ledger()
		local ns = loaded.ns

		-- level1 is earned from the start (LED-R75); level60 isn't on an empty log.
		assert.is_true(ns.SetActiveTitle("title:level1"))
		assert.are.equal("title:level1", ns.db.profile.activeTitle)
		assert.is_false(ns.SetActiveTitle("title:level60"))
		assert.are.equal("title:level1", ns.db.profile.activeTitle)
		assert.is_true(ns.SetActiveTitle(nil))
		assert.is_nil(ns.db.profile.activeTitle)
	end)

	it("reads a stored key that isn't earned as automatic in the Journal, and keeps it stored (LED-R77)", function()
		local _, loaded = ledger()
		local ns = loaded.ns
		-- Stored while Darkshore's title was celebrated, before a new dev log emptied the set (LED-R90).
		ns.db.profile.activeTitle = "zonemaster:148"
		local context = ns.journal.Context()

		assert.are.equal("zonemaster:148", context.activeTitle)
		assert.are.equal("title:level1", (ns.ActiveTitle(context)))
		assert.are.equal("zonemaster:148", ns.db.profile.activeTitle)
	end)

	it("names every LED-R75 title from the committed lore batch (LED-R75, LED-R160, DATA-R111)", function()
		local _, loaded = ledger()
		local ns = loaded.ns
		local keys = {
			"title:level1",
			"title:level10",
			"title:level20",
			"title:level30",
			"title:level40",
			"title:level50",
			"title:level60",
			"title:prestige1",
			"title:prestige5",
			"title:prestige10",
			"title:complete.ledger",
			"title:complete.junk",
			"title:complete.treasure",
			"title:complete.trophy",
		}

		for _, key in ipairs(keys) do
			assert(ns.TitleName(key, ns.journalText), key .. " has no name")
		end
		assert.matches("^Warden of .+ Waters$", ns.TitleName("zonemaster:148", ns.journalText))
	end)

	it("takes a celebrated key as earned (LED-R76, LED-R77)", function()
		local _, loaded = ledger()
		local ns = loaded.ns
		-- Darkshore's title celebrated (#168 fills the set's `titles`), its zone not mastered in this state.
		ns.db.global.celebrated.titles = { ["zonemaster:148"] = true }

		assert.is_true(ns.SetActiveTitle("zonemaster:148"))
		assert.are.equal("zonemaster:148", (ns.ActiveTitle(ns.journal.Context())))
	end)

	it("takes any title on a test log with devGoods, and none more on one without it (SHOP-R37)", function()
		local fake, loaded = ledger()
		local ns = loaded.ns
		assert.is_false(ns.SetActiveTitle("title:level60"))

		fake.catchLog.data.test, fake.catchLog.data.devGoods = true, true

		assert.is_true(ns.journal.Context().ownsAll)
		assert.is_true(ns.SetActiveTitle("title:level60"))
		assert.is_true(ns.SetActiveTitle("zonemaster:148"))
		assert.are.equal("zonemaster:148", (ns.ActiveTitle(ns.journal.Context())))

		fake.catchLog.data.devGoods = nil
		assert.is_false(ns.journal.Context().ownsAll)
		assert.is_false(ns.SetActiveTitle("title:level60"))
	end)
end)
