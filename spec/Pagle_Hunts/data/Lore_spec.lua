-- Hunts' generated lore (DATA-R104, DATA-R105, HNT-R130): addons/Pagle_Hunts/data/Lore.lua adds to ns.L the name and
-- note of every Hunt and the name, title and note of every set, from data/hunts/hunts.toml, and the name and
-- description of each of Hunts' goods, from data/lore/hunts.toml: the M5 batch (DATA-R111). The M8 batch adds each
-- pool event's name and note and its Hunts' names, from data/hunts/events/, and the ladder's three titles, from
-- data/lore/hunts.toml (HNT-R130). Read from the shipped Hunt list and event pool, without the fixtures.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

-- HNT-R121, HNT-R122: Hunts' goods (support.lua's GOODS and BINDINGS): its eight tracker frames and its three earned
-- bindings.
local GOODS = {}
for _, list in ipairs({ hunts.GOODS["hunts.trackerframe"], hunts.BINDINGS }) do
	for _, row in ipairs(list) do
		GOODS[#GOODS + 1] = row[1]
	end
end

describe("Hunts' committed lore (DATA-R111, its M5 and M8 batches)", function()
	local ns

	setup(function()
		ns = newFakePagle().load("Pagle_Hunts").ns
	end)

	---@param key string
	---@return string
	local function text(key)
		local value = rawget(ns.L, key)
		assert(type(value) == "string" and value:find("%S"), key .. " has no text")
		return value
	end

	it("names each of the 12 Standing Hunts once Pagle_Hunts loads (HNT-R1, DATA-R105)", function()
		assert.are.equal(12, #ns.huntList.hunts)
		for _, hunt in ipairs(ns.huntList.hunts) do
			assert.are.equal(text(("hunt.%s.name"):format(hunt.id)), ns.hunts:HuntName(hunt.id))
		end
	end)

	it("gives each of the 4 sets a name and a title (HNT-R1, HNT-R22, DATA-R105)", function()
		assert.are.equal(4, #ns.huntList.sets)
		for _, set in ipairs(ns.huntList.sets) do
			assert.are.equal(text(("set.%s.name"):format(set.id)), ns.hunts:SetName(set.id))
			assert.are.equal(text(("set.%s.title"):format(set.id)), ns.hunts:SetTitle(set.id))
		end
	end)

	it("keeps Sunday Showdown's note: the Extravaganza, at level 60 (hunts.md › Data)", function()
		local note = ns.hunts:SetNote("sunday_showdown")
		assert.is_truthy(note and note:find("Extravaganza", 1, true))
		assert.is_truthy(note and note:find("level 60", 1, true))
	end)

	it(
		"has a name and a description for each of Hunts' goods, Night Watch too (HNT-R121, HNT-R123, HNT-R130)",
		function()
			text("huntgood.hunts.soundset.nightwatch.name")
			text("huntgood.hunts.soundset.nightwatch.description")
			assert.are.equal(11, #GOODS)
			for _, good in ipairs(GOODS) do
				text(("huntgood.%s.name"):format(good))
				text(("huntgood.%s.description"):format(good))
			end
		end
	)

	it(
		"names each of the pool's 24 events and its Hunts, with each event's note (HNT-R130, DATA-R97, the M8 batch)",
		function()
			local events = ns.events:Events()
			assert.are.equal(24, #events)
			for _, event in ipairs(events) do
				assert.are.equal(text(("event.%s.name"):format(event.id)), ns.events:EventName(event))
				assert.are.equal(text(("event.%s.note"):format(event.id)), ns.events:EventNote(event))
				for _, hunt in ipairs(event.hunts) do
					assert.are.equal(text(("hunt.%s.name"):format(hunt.id)), ns.events:HuntName(hunt))
				end
			end
		end
	)

	it("has a title for each of the ladder's three steps, 25 being Bookmaker's Bane (HNT-R148, HNT-R130)", function()
		assert.are.same({ 25, 50, 100 }, ns.LADDER_STEPS)
		for _, step in ipairs(ns.LADDER_STEPS) do
			text(("ladder.%d.title"):format(step))
		end
		assert.are.equal("Bookmaker's Bane", ns.L["ladder.25.title"])
	end)

	it("keeps the hand-written interface strings beside the lore (CORE-R8)", function()
		assert.are.equal("Hunts", ns.L.TITLE)
	end)
end)
