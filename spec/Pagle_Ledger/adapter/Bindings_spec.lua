-- The Ledger's Journal bindings on FakePagle (LED-R110–R112, LED-R35, LED-R92, LED-R93; SHOP-R21–R23, SHOP-R30–R33):
-- the slot and its ten goods, the level bindings earned by the peak or celebrated level, M:RefreshGoods only from a
-- live entry or done, the Journal drawn in the equipped binding, and the closed-book swatch on the shop's stage.

local SLOT = "ledger.binding"

-- LED-R110's goods, in its order, with their kinds.
local GOODS = {
	{ "ledger.binding.field", "default" },
	{ "ledger.binding.level10", "earned", "Angler Level 10" },
	{ "ledger.binding.level20", "earned", "Angler Level 20" },
	{ "ledger.binding.level30", "earned", "Angler Level 30" },
	{ "ledger.binding.level40", "earned", "Angler Level 40" },
	{ "ledger.binding.level50", "earned", "Angler Level 50" },
	{ "ledger.binding.level60", "earned", "Angler Level 60" },
	{ "ledger.binding.birch", "tier 1" },
	{ "ledger.binding.buckram", "tier 2" },
	{ "ledger.binding.sharkskin", "tier 3" },
}

-- A good's kind as LED-R110's table writes it.
---@param good PagleRegisteredGood
---@return string
local function kindOf(good)
	if good.default then
		return "default"
	elseif good.tier then
		return "tier " .. good.tier
	end
	return "earned"
end

-- A zone the catalogue knows but doesn't chart, so no Zone Mastery rank adds XP (LED-R54).
local DUSKWOOD = 10
local T0 = 1791731000

-- A catalogue in the shape of ns.catalogue (DATA-R76) listing `count` Species, items 1001 on, and Duskwood without
-- data; `fingerprint` names the release.
---@param count integer
---@param fingerprint string
local function catalogue(count, fingerprint)
	local items = {}
	for id = 1001, 1000 + count do
		items[id] = { category = "fish", species = id, legend = false, noise = false, removed = false, pool = false }
	end
	return {
		fingerprint = fingerprint,
		items = items,
		areas = {
			[DUSKWOOD] = { parent = 0, continent = 0, hasData = false, skillBaseConfirmed = false, catches = {} },
		},
		aliases = {},
		pools = {},
		windows = {},
		events = {},
		fishingSpells = {},
		auras = {},
	}
end

-- One caught Cast in Duskwood of items `first` to `last`, one each.
---@param time integer
---@param first integer
---@param last integer
local function cast(time, first, last)
	local items = {}
	for id = first, last do
		items[#items + 1] = { itemID = id, quantity = 1 }
	end
	return {
		kind = "cast",
		char = 1,
		time = time,
		outcome = "caught",
		conditions = { minute = 494, zone = DUSKWOOD, subzone = 0, events = {}, auras = {} },
		items = items,
	}
end

-- Notes the projection mode Core is in at each M:RefreshGoods (the fake's Core registry's Refresh), "idle" outside
-- any apply or done.
---@param fake FakePagle
---@return string[]
local function noteRefreshes(fake)
	local modes = {}
	local goods = fake.ns.goods
	local refresh = goods.Refresh
	goods.Refresh = function(self, module)
		modes[#modes + 1] = fake.projections:Mode() or "idle"
		return refresh(self, module)
	end
	return modes
end

-- A Ledger on a fresh fake, logged in and in the world over an empty log.
---@return FakePagle fake
---@return LoadedAddon loaded
local function ledger()
	local fake = newFakePagle()
	local loaded = fake.load("Pagle_Ledger")
	fake.login()
	fake.enterWorld()
	return fake, loaded
end

describe("the Ledger's Journal bindings", function()
	it(
		"register the slot ledger.binding and its ten goods in LED-R110's order, with their kinds, and Field Leather equipped (LED-R110, SHOP-R21, SHOP-R22, SHOP-R32)",
		function()
			local fake = ledger()
			local goods = fake.ns.goods

			local ledgerSlots = {}
			for _, slot in ipairs(goods:Slots()) do
				if slot.module == "Ledger" then
					ledgerSlots[#ledgerSlots + 1] = { slot.id, slot.label, slot.category }
				end
			end
			assert.are.same({ { SLOT, "Journal binding", "Fish Journal" } }, ledgerSlots)
			local registered = {}
			for i, good in ipairs(goods:GoodsOf(SLOT)) do
				registered[i] = { good.id, kindOf(good), good.earnedText }
			end
			assert.are.same(GOODS, registered)
			assert.are.equal("ledger.binding.field", fake.Pagle.GetEquipped(SLOT))
		end
	)

	it(
		"name each binding from its lore keys, and by its good's ID while a key has no text (LED-R110, LED-R160, SHOP-R26)",
		function()
			local fake = newFakePagle()
			local loaded = fake.load("Pagle_Ledger", { holdAddonLoaded = true })
			loaded.ns.L["binding.birch.name"] = "Birch Bark"
			loaded.ns.L["binding.birch.description"] = "Pale bark with dark flecks."
			loaded.client.fire("ADDON_LOADED", "Pagle_Ledger")

			assert.are.same({ "Birch Bark", "Pale bark with dark flecks." }, {
				fake.Pagle.GetGood("ledger.binding.birch").name,
				fake.Pagle.GetGood("ledger.binding.birch").description,
			})
			assert.are.equal("ledger.binding.level10", fake.Pagle.GetGood("ledger.binding.level10").name)
			assert.is_nil(fake.Pagle.GetGood("ledger.binding.level10").description)
		end
	)

	it(
		"own a level binding after the one M:RefreshGoods of the live entry reaching its level, and keep it through a rebuild that lowers the level (LED-R111, LED-R92, LED-R35, SHOP-R30, SHOP-R31)",
		function()
			local fake = newFakePagle()
			fake.setCatalogue(catalogue(20, "first release"))
			fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
			-- 19 new Species in a new zone: 200 + 19 × (20 + 500 + 100) = 11,980 XP, level 9 (LED-R20, LED-R30).
			fake.catchLog:Append(cast(T0, 1001, 1019))
			local loaded = fake.load("Pagle_Ledger")
			local modes = noteRefreshes(fake)
			fake.login()
			fake.enterWorld()
			local ns = loaded.ns
			assert.are.equal(9, ns.PeakLevel(ns.projection:GetState()))
			assert.are.same({ "done" }, modes)
			assert.is_false(fake.Pagle.IsOwned("ledger.binding.level10"))

			-- A 20th Species: + 620 XP, 12,600, level 10.
			fake.playCast("caught", { { itemID = 1020, quantity = 1 } })

			assert.are.equal(10, ns.PeakLevel(ns.projection:GetState()))
			assert.are.same({ "done", "live" }, modes)
			assert.is_true(fake.Pagle.IsOwned("ledger.binding.level10"))
			assert.is_false(fake.Pagle.IsOwned("ledger.binding.level20"))

			-- The next login: a release that lists only the first 10 Species rebuilds the projection (LED-R191), and
			-- the other ten become Uncharted, so the climb falls below level 10.
			local later = newFakePagle()
			later.setCatalogue(catalogue(10, "second release"))
			later.catchLog.data = fake.catchLog.data
			later.globals.PagleLedgerDB = loaded.env.PagleLedgerDB
			local reloaded = later.load("Pagle_Ledger")
			local laterModes = noteRefreshes(later)
			later.login()
			later.enterWorld()

			assert.is_true(reloaded.ns.PeakLevel(reloaded.ns.projection:GetState()) < 10)
			assert.are.same({ "done" }, laterModes) -- never mid-rebuild (SHOP-R31)
			assert.is_true(later.Pagle.IsOwned("ledger.binding.level10"))
			assert.is_false(later.Pagle.IsOwned("ledger.binding.level20"))
		end
	)

	-- The leather, the two pages' paper, the leather's rules and the brass plate's face of the open Journal, as
	-- { r, g, b } each.
	---@param frame LedgerJournalFrame
	local function bookTints(frame)
		local function rgb(texture)
			return { texture.color[1], texture.color[2], texture.color[3] }
		end
		return {
			leather = rgb(frame.leather),
			paper = rgb(frame.papers[1]),
			rule = rgb(frame.rules[1]),
			plate = rgb(frame.plate.brass),
		}
	end

	-- What binding `goodID` tints those three in (logic/Bindings.lua).
	---@param ns PagleLedgerNS
	---@param goodID string
	local function lookOf(ns, goodID)
		local look = ns.BindingLook(goodID)
		return { leather = look.leather, paper = look.paper, rule = look.rule, plate = look.plate }
	end

	it(
		"draw the open Journal in the equipped binding, and redraw it when the binding or the crest changes (LED-R112, SHOP-R33)",
		function()
			local fake = newFakePagle()
			fake.catchLog.data.logId = "log"
			-- Celebrated at level 10 before (LED-R90): Tanned Hide is earned (LED-R111).
			fake.globals.PagleLedgerDB =
				{ global = { celebrated = { coins = 0, levels = { [0] = 10 }, logId = "log" } } }
			local loaded = fake.load("Pagle_Ledger")
			fake.login()
			fake.enterWorld()
			fake.setPurchased({ ["core.crest.crest1"] = true }) -- one of Core's crests bought (SHOP-R25, SHOP-R11)
			local ns = loaded.ns
			ns.ToggleJournal()
			local journal = ns.journal
			assert.are.same(lookOf(ns, "ledger.binding.field"), bookTints(journal.frame))
			assert.are.equal("Interface\\Icons\\INV_Misc_Note_01", ns.CrestIcon()) -- Plain's

			assert.is_true(fake.Pagle.SetEquipped("ledger.binding", "ledger.binding.level10"))

			assert.are.equal("ledger.binding.level10", journal.binding)
			assert.are.same(lookOf(ns, "ledger.binding.level10"), bookTints(journal.frame))
			assert.are_not.same(lookOf(ns, "ledger.binding.field"), lookOf(ns, "ledger.binding.level10"))

			local drawn = journal.pages
			assert.is_true(fake.Pagle.SetEquipped("core.crest", "core.crest.crest1"))

			assert.are_not.equal(drawn, journal.pages)
			assert.are.equal("Interface\\Icons\\INV_Fishingpole_02", ns.CrestIcon())
		end
	)

	it(
		"preview each binding as a closed book on the shop's stage: its leather, gilt rules and brass plate, no pages (LED-R110)",
		function()
			local fake, loaded = ledger()
			local ns = loaded.ns
			local stage = loaded.env.CreateFrame("Frame")
			local paperTexture = ns.JOURNAL_TEXTURES.paper

			for _, row in ipairs(GOODS) do
				local id = row[1]
				local look = ns.BindingLook(id)
				local function same(color, tint)
					return color ~= nil and color[1] == tint[1] and color[2] == tint[2] and color[3] == tint[3]
				end

				fake.ns.goods:Good(id).preview(stage)

				assert.are.equal(1, #stage.children) -- one swatch, drawn afresh for each good
				local swatch = stage.children[1]
				assert.is_true(swatch:IsShown())
				local leather, rules, plate, pages = 0, 0, 0, 0
				for _, texture in ipairs(swatch.children) do
					leather = leather + (same(texture.color, look.leather) and 1 or 0)
					rules = rules + (same(texture.color, look.gilt) and 1 or 0)
					plate = plate + (same(texture.color, look.plate) and 1 or 0)
					pages = pages + ((same(texture.color, look.paper) or texture.texture == paperTexture) and 1 or 0)
				end
				assert.are.same({ 1, 4, 1, 0 }, { leather, rules, plate, pages }, id)
			end
		end
	)
end)
