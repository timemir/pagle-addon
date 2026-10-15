-- The Tackle Board's goods on FakePagle (TKB-R125; SHOP-R20–R23, SHOP-R26, SHOP-R30–R33, SHOP-R90; SET-R44,
-- SET-R50, SET-R51): the tracker-frame slot and its three goods in Core's goods registry, their names from lore, and
-- their previews on the shop's stage, drawn by the tracker block maker (CORE-R73).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

local SLOT = "tackleboard.trackerframe"

-- TKB-R125's goods, in its order, with their kinds.
local GOODS = {
	{ "tackleboard.trackerframe.none", "default" },
	{ "tackleboard.trackerframe.corkboard", "tier 1" },
	{ "tackleboard.trackerframe.driftwood", "tier 2" },
}

-- A good's kind as TKB-R125 writes it; "earned" for one with isEarned (the Tackle Board has none).
---@param good PagleRegisteredGood
---@return string
local function kindOf(good)
	if good.isEarned then
		return "earned"
	elseif good.default then
		return "default"
	end
	return "tier " .. tostring(good.tier)
end

-- Pagle_TackleBoard on a fake that has logged in; support.load has left the shipped lore out of ns.L.
---@param options table? support.load's
local function loggedIn(options)
	local loaded, fake = board.load(nil, options)
	fake.login()
	return loaded, fake
end

describe("The Tackle Board's goods", function()
	it(
		'register the slot tackleboard.trackerframe ("Tackle Board tracker frame", Trackers) with No frame the default, Corkboard tier 1 and Driftwood Plank tier 2, none earned (TKB-R125, SHOP-R21, SHOP-R22)',
		function()
			local _, fake = loggedIn()
			local goods = fake.ns.goods

			local slots = {}
			for _, slot in ipairs(goods:Slots()) do
				if slot.module == "TackleBoard" then
					slots[#slots + 1] = { slot.id, slot.label, slot.category }
				end
			end
			assert.are.same({ { SLOT, "Tackle Board tracker frame", "Trackers" } }, slots)
			local registered = {}
			for i, good in ipairs(goods:GoodsOf(SLOT)) do
				registered[i] = { good.id, kindOf(good) }
			end
			assert.are.same(GOODS, registered)
			assert.are.equal("tackleboard.trackerframe.none", fake.Pagle.GetEquipped(SLOT))
		end
	)

	it("are its only goods: no title or fly is a good (TKB-R125, SHOP-R20)", function()
		local _, fake = loggedIn()

		local ids = {}
		for id, good in pairs(fake.goods) do
			if good.module == "TackleBoard" then
				ids[#ids + 1] = id
			end
		end
		table.sort(ids)
		assert.are.same({
			"tackleboard.trackerframe.corkboard",
			"tackleboard.trackerframe.driftwood",
			"tackleboard.trackerframe.none",
		}, ids)
	end)

	it("sell for 150 and 400 Coins in the Curio Shop, as the Tackle Board's (TKB-R125, SHOP-R22)", function()
		local _, fake = loggedIn()
		local shop = fake.ns.ShopModel(tostring)

		assert.are.same({ 150, 400 }, {
			shop:Entry("tackleboard.trackerframe.corkboard").price,
			shop:Entry("tackleboard.trackerframe.driftwood").price,
		})
		assert.are.equal("TackleBoard", fake.Pagle.GetGood("tackleboard.trackerframe.none").module)
	end)

	it(
		"are named by their IDs, with no description, while their boardgood lore keys have no text (TKB-R130)",
		function()
			local _, fake = loggedIn()

			for _, row in ipairs(GOODS) do
				local good = fake.Pagle.GetGood(row[1])
				assert.are.same({ row[1] }, { good.name, good.description })
			end
		end
	)

	it("are named and described from their boardgood lore keys (TKB-R130, SHOP-R26)", function()
		-- Fixture lore in place of the shipped batch's, as data/Lore.lua adds it to ns.L.
		local _, fake = loggedIn({
			prepare = function(loaded)
				loaded.ns.L["boardgood.tackleboard.trackerframe.corkboard.name"] = "Corkboard"
				loaded.ns.L["boardgood.tackleboard.trackerframe.corkboard.description"] = "Pinned up like a Notice."
				loaded.ns.L["boardgood.tackleboard.trackerframe.driftwood.name"] = "Driftwood Plank"
			end,
		})

		local cork = fake.Pagle.GetGood("tackleboard.trackerframe.corkboard")
		local plank = fake.Pagle.GetGood("tackleboard.trackerframe.driftwood")
		assert.are.same({ "Corkboard", "Pinned up like a Notice." }, { cork.name, cork.description })
		assert.are.same({ "Driftwood Plank" }, { plank.name, plank.description })
		assert.are.equal("tackleboard.trackerframe.none", fake.Pagle.GetGood("tackleboard.trackerframe.none").name)
	end)

	it("show each good's own icon as its swatch in the Curio Shop's list (TKB-R125, SHOP-R26)", function()
		local _, fake = loggedIn()

		local icons = {}
		for _, row in ipairs(GOODS) do
			local icon = fake.Pagle.GetGood(row[1]).icon
			assert.matches("^Interface\\Icons\\", icon)
			icons[icon] = true
		end
		local distinct = 0
		for _ in pairs(icons) do
			distinct = distinct + 1
		end
		assert.are.equal(3, distinct)
	end)
end)

-- Every shown widget under `widget`, depth first, skipping hidden ones and what they hold.
local function shownDescendants(widget, list)
	list = list or {}
	for _, child in ipairs(widget.children) do
		if child.shown then
			list[#list + 1] = child
			shownDescendants(child, list)
		end
	end
	return list
end

-- The texts of every shown font string under `widget`, depth first.
local function textsOf(widget)
	local texts = {}
	for _, child in ipairs(shownDescendants(widget)) do
		if child.kind == "FontString" and child.text then
			texts[#texts + 1] = child.text
		end
	end
	return texts
end

-- Elwynn Forest's area ID (TKB-R125; its name is read from the client, TKB-R36).
local ELWYNN = 12

-- The sample tracker TKB-R125 gives, in the enUS client: the header (the Campfire's days by the flame and the open
-- goals), then its two goal lines, each a text with its count, then where (TKB-R122).
local SAMPLE = {
	"Tackle Board",
	"5 · 2 open",
	"30 Catches in Elwynn Forest",
	"12/30",
	"Elwynn Forest · here",
	"5 uncommon-or-better Catches",
	"2/5",
	"anywhere",
}

-- The Tackle Board logged in, with Elwynn Forest's name in the client as `name` (default the enUS one).
---@param name string?
local function withNames(name)
	local loaded, fake = loggedIn()
	loaded.client.areaNames[ELWYNN] = name or "Elwynn Forest"
	return loaded, fake
end

describe("Look and Feel", function()
	it("lists the tracker frame under Trackers, offering only owned frames (SET-R50, SET-R51, SHOP-R30)", function()
		local _, fake = loggedIn()

		local listed = {}
		for _, section in ipairs(fake.ns.LookAndFeelSections(fake.ns.goods)) do
			for _, slot in ipairs(section.slots) do
				if slot.module == "TackleBoard" then
					listed[#listed + 1] = { section.category, slot.id }
				end
			end
		end
		assert.are.same({ { "Trackers", SLOT } }, listed)
		local function choices()
			local values = {}
			for _, choice in ipairs(fake.ns.SlotChoices(fake.ns.goods, SLOT)) do
				values[#values + 1] = choice.value
			end
			return values
		end
		assert.are.same({ "tackleboard.trackerframe.none" }, choices())
		fake.setPurchased({ ["tackleboard.trackerframe.driftwood"] = true })
		assert.are.same({ "tackleboard.trackerframe.none", "tackleboard.trackerframe.driftwood" }, choices())
	end)
end)

describe("A tracker frame's preview", function()
	it(
		"draws the header and the two sample goal lines in that frame, on the good's own stage frame (TKB-R125, TKB-R122, SHOP-R23)",
		function()
			local loaded, fake = withNames()
			local ns = loaded.ns
			assert.is_nil(ns.TRACKER_FRAMES["tackleboard.trackerframe.none"]) -- the plain native block

			for _, row in ipairs(GOODS) do
				local id = row[1]
				local stage = loaded.env.CreateFrame("Frame") -- each good's own stage frame (#157)

				fake.ns.goods:Good(id).preview(stage)
				fake.ns.goods:Good(id).preview(stage) -- the shop draws it again at each selection

				assert.are.equal(1, #stage.children, id) -- one sample, drawn afresh
				local block = stage.children[1]
				assert.is_true(block:IsShown())
				assert.are.same(SAMPLE, textsOf(block), id)
				local look, dressed = ns.TRACKER_FRAMES[id], block.frame
				assert.are.equal(look ~= nil, dressed.backing:IsShown(), id)
				if look then
					assert.are.equal(look.texture, dressed.grain.texture, id)
				end
			end
		end
	)

	it("reads the zone's name from the client each time it draws (TKB-R125, TKB-R36)", function()
		local loaded, fake = withNames("Wald von Elwynn")
		local stage = loaded.env.CreateFrame("Frame")

		fake.ns.goods:Good("tackleboard.trackerframe.corkboard").preview(stage)

		local texts = textsOf(stage.children[1])
		assert.are.same({ "30 Catches in Wald von Elwynn", "Wald von Elwynn · here" }, { texts[3], texts[5] })
	end)

	it("shows a small flame by the Campfire's days, and the header's expanded mark (TKB-R122)", function()
		local loaded, fake = withNames()
		local stage = loaded.env.CreateFrame("Frame")

		fake.ns.goods:Good("tackleboard.trackerframe.driftwood").preview(stage)

		local header = stage.children[1].rows[1]
		assert.is_true(header.flame:IsShown())
		assert.are.equal(loaded.ns.BOARD_TEXTURES.flame, header.flame.texture)
		assert.is_true(header.mark:IsShown())
		assert.are.equal("Interface\\Buttons\\UI-MinusButton-Up", header.mark.texture)
	end)

	it(
		"dresses Corkboard in cork with a thin wooden border and dark ink, and Driftwood Plank in weathered wood with the native words (TKB-R125)",
		function()
			local loaded = loggedIn()
			local ns = loaded.ns
			local cork = ns.TRACKER_FRAMES["tackleboard.trackerframe.corkboard"]
			local plank = ns.TRACKER_FRAMES["tackleboard.trackerframe.driftwood"]

			assert.are.equal(ns.BOARD_TEXTURES.fleck, cork.texture) -- the board's cork flecks
			assert.is_true(cork.borderSize <= 3) -- a thin border
			assert.is_not_nil(cork.ink) -- dark words on the pale cork
			assert.are.equal(ns.BOARD_TEXTURES.grain, plank.texture) -- the board's wood grain
			assert.is_nil(plank.ink) -- the native colours on dark wood
		end
	)
end)
