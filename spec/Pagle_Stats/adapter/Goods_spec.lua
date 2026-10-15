-- Stats' goods on FakePagle (STA-R88, STA-R84; SHOP-R21–R23, SHOP-R26, SHOP-R30–R33, SHOP-R90; SET-R44, SET-R50,
-- SET-R51): the tracker-frame slot and its three goods in Core's goods registry, their names from lore, and their
-- previews on the shop's stage.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local SLOT = "stats.trackerframe"

-- STA-R88's goods (stats.GOODS), in its order, with their kinds.
local GOODS = {
	{ stats.GOODS[1], "default" },
	{ stats.GOODS[2], "tier 1" },
	{ stats.GOODS[3], "tier 2" },
}

-- A good's kind as STA-R88's table writes it; "earned" for one with isEarned (Stats has none).
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

-- Pagle_Stats on a fake that has logged in (its projection's first build still to come), no item named.
---@param options { catalogue: table?, prepare: fun(loaded: LoadedAddon)? }?
local function loggedIn(options)
	options = options or {}
	local loaded, fake = stats.start({
		items = {},
		updating = true,
		catalogue = options.catalogue,
		prepare = options.prepare,
	})
	return loaded, fake
end

describe("Stats' goods", function()
	it(
		'register the slot stats.trackerframe ("Stats tracker frame", Trackers) with No frame the default, Logbook tier 1 and Brass tier 2, none earned (STA-R88, SHOP-R21, SHOP-R22)',
		function()
			local _, fake = loggedIn()
			local goods = fake.ns.goods

			local slots = {}
			for _, slot in ipairs(goods:Slots()) do
				if slot.module == "Stats" then
					slots[#slots + 1] = { slot.id, slot.label, slot.category }
				end
			end
			assert.are.same({ { SLOT, "Stats tracker frame", "Trackers" } }, slots)
			local registered = {}
			for i, good in ipairs(goods:GoodsOf(SLOT)) do
				registered[i] = { good.id, kindOf(good) }
			end
			assert.are.same(GOODS, registered)
			assert.are.equal("stats.trackerframe.none", fake.Pagle.GetEquipped(SLOT))
		end
	)

	it("sell for 150 and 400 Coins in the Curio Shop, as Stats' (STA-R88, SHOP-R22)", function()
		local _, fake = loggedIn()
		local shop = fake.ns.ShopModel(tostring)

		assert.are.same({ 150, 400 }, {
			shop:Entry("stats.trackerframe.logbook").price,
			shop:Entry("stats.trackerframe.brass").price,
		})
		assert.are.equal("Stats", fake.Pagle.GetGood("stats.trackerframe.none").module)
	end)

	it("are named by their IDs, with no description, while their statsgood lore keys have no text (STA-R88)", function()
		-- Any lore the shipped data/Lore.lua may hold taken out, as before the M6 batch (#210).
		local _, fake = loggedIn({
			prepare = function(loaded)
				for key in pairs(loaded.ns.L) do
					if type(key) == "string" and key:find("^statsgood%.") then
						loaded.ns.L[key] = nil
					end
				end
			end,
		})

		for _, row in ipairs(GOODS) do
			local good = fake.Pagle.GetGood(row[1])
			assert.are.same({ row[1] }, { good.name, good.description })
		end
	end)

	it("are named and described from their statsgood lore keys (STA-R88, SHOP-R26)", function()
		-- Fixture lore in place of the shipped M6 batch's (#210), as data/Lore.lua adds it to ns.L.
		local _, fake = loggedIn({
			prepare = function(loaded)
				for key in pairs(loaded.ns.L) do
					if type(key) == "string" and key:find("^statsgood%.") then
						loaded.ns.L[key] = nil
					end
				end
				loaded.ns.L["statsgood.stats.trackerframe.logbook.name"] = "Logbook"
				loaded.ns.L["statsgood.stats.trackerframe.logbook.description"] = "Ruled like a ledger."
				loaded.ns.L["statsgood.stats.trackerframe.brass.name"] = "Brass"
			end,
		})

		local logbook = fake.Pagle.GetGood("stats.trackerframe.logbook")
		local brass = fake.Pagle.GetGood("stats.trackerframe.brass")
		assert.are.same({ "Logbook", "Ruled like a ledger." }, { logbook.name, logbook.description })
		assert.are.same({ "Brass" }, { brass.name, brass.description })
		assert.are.equal("stats.trackerframe.none", fake.Pagle.GetGood("stats.trackerframe.none").name)
	end)

	it("are named and described by the shipped M6 lore batch, never by their IDs (STA-R88, DATA-R111)", function()
		local loaded, fake = loggedIn()

		for _, row in ipairs(GOODS) do
			local good = fake.Pagle.GetGood(row[1])
			assert.are.same({
				loaded.ns.L["statsgood." .. row[1] .. ".name"],
				loaded.ns.L["statsgood." .. row[1] .. ".description"],
			}, { good.name, good.description })
			assert.are_not.equal(row[1], good.name)
		end
	end)

	it("show each good's own icon as its swatch in the Curio Shop's list (STA-R88, SHOP-R26)", function()
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

local textsOf = stats.fontTexts

-- STA-R88's sample items and areas: a normal watch (item 4603 in area 35) and an unlucky one (13759 in 357).
local YELLOWTAIL, NIGHTFIN, BOOTY_BAY, FERALAS = 4603, 13759, 35, 357

-- The sample tracker STA-R88 lists, its names as the enUS client has them loaded.
local SAMPLE = {
	"Stats",
	"Session · 21m",
	"38 Casts · 31 Catches · 7 got away",
	"62 per hour · skill +3",
	"Raw Spotted Yellowtail",
	"40",
	"Booty Bay · normal",
	"Raw Nightfin Snapper",
	"212",
	"Feralas · by night · unlucky",
}

-- Stats logged in, with the sample's item and area names in the client.
local function withNames()
	local loaded, fake = loggedIn()
	loaded.client.itemNames[YELLOWTAIL] = "Raw Spotted Yellowtail"
	loaded.client.itemNames[NIGHTFIN] = "Raw Nightfin Snapper"
	loaded.client.areaNames[BOOTY_BAY] = "Booty Bay"
	loaded.client.areaNames[FERALAS] = "Feralas"
	return loaded, fake
end

describe("A tracker frame's preview", function()
	it(
		"draws the sample tracker's five parts in that frame, on the good's own stage frame (STA-R88, STA-R82, STA-R84)",
		function()
			local loaded, fake = withNames()
			local ns = loaded.ns
			assert.is_nil(ns.TRACKER_FRAMES["stats.trackerframe.none"]) -- the plain native block

			for _, row in ipairs(GOODS) do
				local id = row[1]
				local stage = loaded.env.CreateFrame("Frame") -- each good's own stage frame (#157)

				fake.ns.goods:Good(id).preview(stage)
				fake.ns.goods:Good(id).preview(stage) -- the shop draws it again at each selection

				assert.are.equal(1, #stage.children, id) -- one sample, drawn afresh
				local block = stage.children[1]
				assert.is_true(block:IsShown())
				local look = ns.TRACKER_FRAMES[id]
				local expected = { unpack(SAMPLE) }
				if look and look.caps then
					expected[1] = expected[1]:upper() -- "Stats" in small caps on the paper
				end
				assert.are.same(expected, textsOf(block), id)
				assert.are.equal(look ~= nil, block.paper:IsShown(), id)
				if look then
					assert.are.equal(ns.ATLASES[look.frame].file, block.paper.top.texture, id)
				end
			end
		end
	)

	it("dots the normal watch green and the unlucky one amber (STA-R88, STA-R82)", function()
		local loaded, fake = withNames()
		local stage = loaded.env.CreateFrame("Frame")

		fake.ns.goods:Good("stats.trackerframe.none").preview(stage)

		local dots = {}
		for _, row in ipairs(stage.children[1].rows) do
			if row.dot:IsShown() then
				local tint = row.dot.vertexColor
				dots[#dots + 1] = { tint[1], tint[2], tint[3] }
			end
		end
		local colours = loaded.ns.BAND_DOT_COLORS
		assert.are.same({ colours.normal, colours.unlucky }, dots)
	end)

	it(
		'reads "Item {id}" for an item the client hasn\'t loaded, asks for it, and redraws with its name when it loads (STA-R88, STA-R59)',
		function()
			local loaded, fake = loggedIn()
			loaded.client.areaNames[BOOTY_BAY] = "Booty Bay"
			loaded.client.areaNames[FERALAS] = "Feralas"
			local stage = loaded.env.CreateFrame("Frame")

			fake.ns.goods:Good("stats.trackerframe.logbook").preview(stage)

			local texts = textsOf(stage.children[1])
			assert.are.same({ "Item 4603", "Item 13759" }, { texts[5], texts[8] })
			assert.are.same({ YELLOWTAIL, NIGHTFIN }, loaded.client.itemRequests)

			stats.loadItem(loaded, NIGHTFIN)

			texts = textsOf(stage.children[1])
			assert.are.same({ "Item 4603", "Raw Nightfin Snapper" }, { texts[5], texts[8] })
		end
	)

	it(
		"dresses Logbook in ruled paper with dark ink, its rulings repeated at their pitch, and Brass in its riveted plate with bright words (STA-R88)",
		function()
			local loaded = loggedIn()
			local ns = loaded.ns
			local logbook = ns.TRACKER_FRAMES["stats.trackerframe.logbook"]
			local brass = ns.TRACKER_FRAMES["stats.trackerframe.brass"]

			assert.are.same({ "TrackerLogbook", "TrackerBrass" }, { logbook.frame, brass.frame })
			assert.are.equal(40, logbook.period) -- the ruled lines stay evenly spaced as it grows
			assert.is_nil(brass.period)
			assert.is_true(logbook.paper) -- band dots in ink on the page
			assert.are_not.same(ns.TRACKER_INKS.header, logbook.ink.header) -- dark words on the pale page
			assert.are.same(ns.TRACKER_INKS.text, brass.ink.text) -- bright words on the dark plate
		end
	)
end)

describe("Settings", function()
	it("Look and Feel lists the tracker frame under Trackers, offering only owned frames (SET-R50, SET-R51)", function()
		local _, fake = loggedIn()

		local listed = {}
		for _, section in ipairs(fake.ns.LookAndFeelSections(fake.ns.goods)) do
			for _, slot in ipairs(section.slots) do
				if slot.module == "Stats" then
					listed[#listed + 1] = { section.category, slot.id }
				end
			end
		end
		assert.are.same({ { "Trackers", SLOT } }, listed)
		local choices = {}
		for _, choice in ipairs(fake.ns.SlotChoices(fake.ns.goods, SLOT)) do
			choices[#choices + 1] = choice.value
		end
		assert.are.same({ "stats.trackerframe.none" }, choices)
		fake.setPurchased({ ["stats.trackerframe.brass"] = true })
		choices = {}
		for _, choice in ipairs(fake.ns.SlotChoices(fake.ns.goods, SLOT)) do
			choices[#choices + 1] = choice.value
		end
		assert.are.same({ "stats.trackerframe.none", "stats.trackerframe.brass" }, choices)
	end)

	it(
		"ends Stats' section of the Trackers page with Core's \"Stats tracker frame\", unindented, after Stats' own rows (SET-R44, CORE-R42)",
		function()
			local _, fake = loggedIn()

			local section = {}
			for _, row in ipairs(fake.settingsPage("trackers")) do
				if row.module == "Stats" then
					section[#section + 1] = row
				end
			end
			local last = section[#section]
			assert.are.same(
				{ "slot", "Stats tracker frame", SLOT, false },
				{ last.kind, last.label, last.slot, last.indented }
			)
			for i = 1, #section - 1 do
				assert.are_not.equal("slot", section[i].kind) -- Stats' own rows (adapter/Settings.lua) come first
			end
		end
	)

	it(
		"draws the frame row on Core's Trackers page last in Stats' section, unhung and never greyed out (SET-R44, SET-R2)",
		function()
			local loaded = loadAddon("Pagle_Stats", FOREVER_GLOBALS)
			enterWorld(loaded)
			local settings = loaded.client.settings

			local rows = settings.show(settings.page("Trackers"))
			local last = rows[#rows]

			assert.are.equal("Stats tracker frame", last.initializer:GetName())
			assert.is_nil(last.initializer:GetParentInitializer())
			-- Core's slot row (SET-R6): its own dropdown, the fake's DropdownButton, holds the equipped frame. Never
			-- greyed out: nothing to grey it by, and its dropdown takes clicks (the fake panel greys only Blizzard's
			-- native controls, as the client does, #120).
			assert.are.equal("PagleSettingsSlotRowTemplate", last.initializer:GetTemplate())
			assert.are.same({}, last.initializer.modifyPredicates)
			assert.is_true(settings.dropdownOf(last):IsEnabled())
			assert.are.equal("stats.trackerframe.none", settings.dropdownOf(last).selected)
		end
	)

	it(
		"falls back to No frame while Stats is disabled, keeping the pick, which comes back with Stats (SHOP-R32, SHOP-R90)",
		function()
			local _, first = loggedIn()
			first.setPurchased({ ["stats.trackerframe.brass"] = true })
			assert.is_true(first.Pagle.SetEquipped(SLOT, "stats.trackerframe.brass"))

			-- The next session, Stats disabled: it runs no code, so it registers nothing (CORE-R17).
			local off = newFakePagle()
			off.global.goods = first.global.goods
			off.profile.appearance = first.profile.appearance
			off.setPurchased({ ["stats.trackerframe.brass"] = true })
			off.login()

			assert.are.equal("stats.trackerframe.none", off.Pagle.GetEquipped(SLOT))
			assert.are.equal("stats.trackerframe.brass", off.profile.appearance[SLOT])

			-- Enabled again: Brass is equipped with no SetEquipped.
			local on = newFakePagle()
			on.global.goods = first.global.goods
			on.profile.appearance = off.profile.appearance
			on.setPurchased({ ["stats.trackerframe.brass"] = true })
			stats.load(on)
			on.login()

			assert.are.equal("stats.trackerframe.brass", on.Pagle.GetEquipped(SLOT))
		end
	)
end)
