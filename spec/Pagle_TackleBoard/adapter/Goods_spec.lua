-- The Tackle Board's goods on FakePagle (TKB-R125, TKB-R126; SHOP-R20–R23, SHOP-R26, SHOP-R30–R33, SHOP-R90; SET-R44,
-- SET-R50, SET-R51): the tracker-frame slot and its goods in Core's goods registry, their names from lore, their
-- previews on the shop's stage, drawn by the tracker block maker (CORE-R73), and the earned ones owned at their
-- Campfire milestones through the projection (TKB-R73).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

local SLOT = "tackleboard.trackerframe"

-- TKB-R125's goods, in its order, with their kinds: the three at first, then the Curio Shop expansion's, Live Embers
-- earned (TKB-R126).
local GOODS = {
	{ "tackleboard.trackerframe.none", "default" },
	{ "tackleboard.trackerframe.corkboard", "tier 1" },
	{ "tackleboard.trackerframe.driftwood", "tier 2" },
	{ "tackleboard.trackerframe.net", "tier 1" },
	{ "tackleboard.trackerframe.bamboo", "tier 1" },
	{ "tackleboard.trackerframe.tin", "tier 2" },
	{ "tackleboard.trackerframe.bobber", "tier 2" },
	{ "tackleboard.trackerframe.embers", "earned" },
}

-- A good's kind as TKB-R125 and TKB-R126 write it; "earned" for one with isEarned.
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
		'register the slot tackleboard.trackerframe ("Tackle Board tracker frame", Trackers) with No frame the default, Corkboard, Fishing Net and Bamboo Slats tier 1, Tideworn Plank, Tackle Tin and Bobber tier 2, and Live Embers earned (TKB-R125, TKB-R126, SHOP-R21, SHOP-R22)',
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
		for id, good in pairs(fake.global.goods) do
			if good.module == "TackleBoard" then
				ids[#ids + 1] = id
			end
		end
		table.sort(ids)
		assert.are.same({
			"tackleboard.trackerframe.bamboo",
			"tackleboard.trackerframe.bobber",
			"tackleboard.trackerframe.corkboard",
			"tackleboard.trackerframe.driftwood",
			"tackleboard.trackerframe.embers",
			"tackleboard.trackerframe.net",
			"tackleboard.trackerframe.none",
			"tackleboard.trackerframe.tin",
		}, ids)
	end)

	it(
		"sell for 150 Coins at tier 1 and 400 at tier 2 in the Curio Shop, as the Tackle Board's (TKB-R125, SHOP-R22)",
		function()
			local _, fake = loggedIn()
			local shop = fake.ns.ShopModel(tostring)

			local prices = {}
			for _, name in ipairs({ "corkboard", "driftwood", "net", "bamboo", "tin", "bobber" }) do
				prices[#prices + 1] = shop:Entry("tackleboard.trackerframe." .. name).price
			end
			assert.are.same({ 150, 400, 150, 150, 400, 400 }, prices)
			assert.are.equal("TackleBoard", fake.Pagle.GetGood("tackleboard.trackerframe.none").module)
		end
	)

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
				loaded.ns.L["boardgood.tackleboard.trackerframe.driftwood.name"] = "Tideworn Plank"
			end,
		})

		local cork = fake.Pagle.GetGood("tackleboard.trackerframe.corkboard")
		local plank = fake.Pagle.GetGood("tackleboard.trackerframe.driftwood")
		assert.are.same({ "Corkboard", "Pinned up like a Notice." }, { cork.name, cork.description })
		assert.are.same({ "Tideworn Plank" }, { plank.name, plank.description })
		assert.are.equal("tackleboard.trackerframe.none", fake.Pagle.GetGood("tackleboard.trackerframe.none").name)
	end)

	it("show Live Embers' earnedText, \"Campfire: 365 days\", while it isn't earned (TKB-R126, SHOP-R22)", function()
		local _, fake = loggedIn()

		assert.are.same({ "Campfire: 365 days", "Campfire: 365 days" }, {
			fake.ns.goods:EarnedTexts("tackleboard.trackerframe.embers"),
		})
		assert.is_false(fake.Pagle.IsOwned("tackleboard.trackerframe.embers"))
	end)

	it("register each good with its authored icon (TKB-R125, SHOP-R26)", function()
		local loaded, fake = loggedIn()

		for _, good in ipairs(loaded.ns.BOARD_GOODS.goods) do
			assert.are.equal(good.icon, fake.Pagle.GetGood(good.id).icon)
		end
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
	"Elwynn Forest",
	" · here",
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
				local expected = { unpack(SAMPLE) }
				if id == "tackleboard.trackerframe.driftwood" then
					expected[1] = "TACKLE BOARD" -- the plank's title in capitals
				end
				assert.are.same(expected, textsOf(block), id)
				local style, dressed = ns.TRACKER_FRAMES[id], block.frame
				assert.are.equal(style ~= nil, dressed ~= nil and dressed:IsShown(), id)
				if style and style.slice then
					assert.are.equal(ns.BOARD_ATLASES.TrackerFrames2.file, dressed.pieces[1].texture, id)
				elseif style then
					assert.are.equal(ns.BOARD_ATLASES.Tracker.file, dressed.top.texture, id)
				end
			end
		end
	)

	it("reads the zone's name from the client each time it draws (TKB-R125, TKB-R36)", function()
		local loaded, fake = withNames("Wald von Elwynn")
		local stage = loaded.env.CreateFrame("Frame")

		fake.ns.goods:Good("tackleboard.trackerframe.corkboard").preview(stage)

		local texts = textsOf(stage.children[1])
		assert.are.same({ "30 Catches in Wald von Elwynn", "Wald von Elwynn" }, { texts[3], texts[5] })
	end)

	it("shows the small flame by the Campfire's days, and the header's chevron (TKB-R122)", function()
		local loaded, fake = withNames()
		local stage = loaded.env.CreateFrame("Frame")

		fake.ns.goods:Good("tackleboard.trackerframe.driftwood").preview(stage)

		local header = stage.children[1].rows[1]
		assert.is_true(header.flame:IsShown())
		assert.are.equal(loaded.ns.BOARD_ATLASES.Marks.file, header.flame.texture)
		assert.is_true(header.chevron:IsShown())
	end)

	it(
		"dresses Corkboard as the kit's cork panel with its goals on slips, and Tideworn Plank as its ruled grey plank (TKB-R125)",
		function()
			local loaded = loggedIn()
			local ns = loaded.ns
			local cork = ns.TRACKER_FRAMES["tackleboard.trackerframe.corkboard"]
			local plank = ns.TRACKER_FRAMES["tackleboard.trackerframe.driftwood"]

			assert.are.same({ "trk-cork", true }, { cork.frame, cork.slips })
			assert.are.same({ "trk-drift", true }, { plank.frame, plank.rules })
		end
	)

	it(
		"dresses the Curio Shop expansion's frames in their own kit styles, each a panel of TrackerFrames2 (TKB-R125)",
		function()
			local ns = loggedIn().ns

			for _, name in ipairs({ "net", "bamboo", "tin", "bobber", "embers" }) do
				local style = ns.TRACKER_FRAMES["tackleboard.trackerframe." .. name]
				assert.are.equal(ns.TRACKER_STYLES[name], style, name)
				assert.are.same({ "TrackerFrames2", "frame-" .. name }, { style.atlas, style.frame }, name)
			end
		end
	)
end)

describe("Live Embers, earned at the Campfire's 365-day milestone (TKB-R126, TKB-R73, SHOP-R31)", function()
	local EMBERS = "tackleboard.trackerframe.embers"
	local DAY, T = board.DAY, board.DAY0 + 3600 -- the start record's time, on board day 0
	local DUROTAR, BLACKMOUTH = 14, 6358 -- a Haul Notice counts a Catch of any item in its zone
	local NOTICE = "n;haul;1;10;1;14" -- a tier-1 Notice done by one Catch in Durotar

	-- A tier-1 Notice issued and done on board day `day`: it lights the day (TKB-R70).
	local function litDay(day)
		local t = T + day * DAY
		return { board.issue(t + 1, NOTICE), board.cast(t + 2, DUROTAR, { BLACKMOUTH }) }
	end

	-- The board started on day 0 and lit on each of its first `days` days.
	local function litDays(days)
		local log = { board.start(T) }
		for day = 0, days - 1 do
			for _, entry in ipairs(litDay(day)) do
				log[#log + 1] = entry
			end
		end
		return log
	end

	-- Notes the projections' mode at each M:RefreshGoods (SHOP-R31): "live", a done's or "idle".
	local function noteRefreshes(fake)
		local modes = {}
		local goods = fake.ns.goods
		local refresh = goods.Refresh
		goods.Refresh = function(self, module)
			if module == "TackleBoard" then
				modes[#modes + 1] = fake.projections:Mode() or "idle"
			end
			return refresh(self, module)
		end
		return modes
	end

	it(
		"isn't owned with 364 days lit, and is after the one M:RefreshGoods of the live entry lighting the 365th",
		function()
			local fake = board.withHistory(litDays(364))
			local loaded = board.load(fake)
			local modes = noteRefreshes(fake)
			fake.login()
			fake.enterWorld()
			local ns = loaded.ns
			assert.are.equal(364, ns.State().fire.count)
			assert.is_false(fake.Pagle.IsOwned(EMBERS))
			local entries = litDay(364)

			board.live(fake, entries[1]) -- the Notice goes up: nothing reached
			assert.are.same({ "done" }, modes)
			board.live(fake, entries[2]) -- done: the 365th day lit

			assert.is_not_nil(ns.State().fire.milestones[365])
			assert.are.same({ "done", "live" }, modes)
			assert.is_true(fake.Pagle.IsOwned(EMBERS))
		end
	)

	it(
		"is owned from a build over a year-long fire, and stays owned through its rebuild, refreshed from done",
		function()
			local fake = board.withHistory(litDays(365))
			local loaded = board.load(fake)
			local modes = noteRefreshes(fake)
			fake.login()
			fake.enterWorld()
			assert.is_true(fake.Pagle.IsOwned(EMBERS))

			loaded.ns.projection:Rebuild()

			assert.are.same({ "done", "done" }, modes) -- never mid-rebuild
			assert.is_true(fake.Pagle.IsOwned(EMBERS))
		end
	)

	it("isn't owned at the 100-day milestone, only at its own (TKB-R126)", function()
		local fake = board.withHistory(litDays(100))
		board.built(fake)

		assert.is_false(fake.Pagle.IsOwned(EMBERS))
	end)

	it(
		"stays owned once reached, through a rebuild that no longer reaches it: its title is celebrated (TKB-R73, TKB-R83)",
		function()
			local first = board.withHistory(litDays(365))
			local _, loaded = board.built(first)
			assert.is_true(first.Pagle.IsOwned(EMBERS))
			-- a new log (another logId, LOG-R72) whose board has no fire, over the same PagleTackleBoardDB
			local fake = board.withHistory({ board.start(T) })
			fake.globals.PagleTackleBoardDB = { global = loaded.env.PagleTackleBoardDB.global }

			local ns = board.built(fake)

			assert.are.equal(0, ns.State().fire.count)
			assert.is_true(fake.Pagle.IsOwned(EMBERS))
		end
	)
end)
