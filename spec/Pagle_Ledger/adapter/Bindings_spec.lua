-- The Ledger's Journal bindings on FakePagle (LED-R110–R115, LED-R35, LED-R92, LED-R93; SHOP-R21–R23, SHOP-R30–R33):
-- the slot and its ten goods, the level bindings earned by the peak or celebrated level, M:RefreshGoods only from a
-- live entry or done, the Journal drawn in the equipped binding, the closed-book swatch on the shop's stage, and the
-- zone crests in Core's crest slot.

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
local T0 = SERVER_TIME - 700

-- A catalogue in the shape of ns.catalogue (DATA-R76) listing `count` Species, items 1001 on, and Duskwood without
-- data; `fingerprint` names the release.
---@param count integer
---@param fingerprint string
local function catalogue(count, fingerprint)
	local items = {}
	for id = 1001, 1000 + count do
		items[id] = fishRecord(id)
	end
	return catalogueWith({
		fingerprint = fingerprint,
		items = items,
		areas = { [DUSKWOOD] = areaRecord(0, { hasData = false }) },
	})
end

-- One caught Cast in Duskwood of items `first` to `last`, one each.
---@param time integer
---@param first integer
---@param last integer
local function cast(time, first, last)
	local items = {}
	for id = first, last do
		items[#items + 1] = id
	end
	return castRecord({ time = time, zone = DUSKWOOD, items = items })
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

-- A Ledger on a fresh fake, logged in and in the world over an empty log, the Journal closed.
---@return FakePagle fake
---@return LoadedAddon loaded
local function ledger()
	return openJournal({ id = false })
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
			-- As before the committed Lore.lua had them (LED-R161): level10's keys with no text.
			loaded.ns.L["binding.level10.name"] = nil
			loaded.ns.L["binding.level10.description"] = nil
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

	-- The open Journal's leather (its texture and tint), its band's tone, each page's paper tint and the plate's
	-- silver.
	---@param frame LedgerJournalFrame
	local function bookTints(frame)
		local function rgb(texture)
			local color = texture.vertexColor or { 1, 1, 1 }
			return { color[1], color[2], color[3] }
		end
		return {
			leather = (frame.leatherFill --[[@as table]]).texture,
			tint = frame.leatherTint,
			band = rgb(frame.band[1]),
			paper = { rgb(frame.papers.left.parchment), rgb(frame.papers.right.parchment) },
			silver = (frame.plate.slices[1] --[[@as table]]).desaturated == true,
		}
	end

	-- What binding `goodID` draws those in (logic/Bindings.lua).
	---@param ns PagleLedgerNS
	---@param goodID string
	local function lookOf(ns, goodID)
		local look = ns.BindingLook(goodID)
		return {
			leather = ns.JOURNAL_FILES[look.texture],
			tint = look.tint or { 1, 1, 1 },
			band = look.band or { 1, 1, 1 },
			paper = { look.paperTint, look.paperTint },
			silver = look.silver,
		}
	end

	it(
		"draw the open Journal in the equipped binding, and redraw it when the binding or the crest changes (LED-R112, SHOP-R33)",
		function()
			local fake = newFakePagle()
			fake.profile.announcements.motion = false -- the binding changes at once, without the kit's dip
			fake.catchLog.data.logId = "log"
			-- Celebrated at level 10 before (LED-R90): Tanned Hide is earned (LED-R111); and zone 12 at Master, so its
			-- crest is too (LED-R114).
			fake.globals.PagleLedgerDB = {
				global = { celebrated = { coins = 0, levels = { [0] = 10 }, zones = { [12] = 5 }, logId = "log" } },
			}
			local loaded = fake.load("Pagle_Ledger")
			fake.login()
			fake.enterWorld()
			local ns = loaded.ns
			ns.ToggleJournal()
			local journal = ns.journal
			assert.are.same(lookOf(ns, "ledger.binding.field"), bookTints(journal.frame))
			assert.is_nil(ns.CrestIcon()) -- Plain, the default: no emblem (LED-R112, SHOP-R25)

			assert.is_true(fake.Pagle.SetEquipped("ledger.binding", "ledger.binding.level10"))

			assert.are.equal("ledger.binding.level10", journal.binding)
			assert.are.same(lookOf(ns, "ledger.binding.level10"), bookTints(journal.frame))
			assert.are_not.same(lookOf(ns, "ledger.binding.field"), lookOf(ns, "ledger.binding.level10"))

			local drawn = journal.pages
			assert.is_true(fake.Pagle.SetEquipped("core.crest", "ledger.crest.elwynn"))

			assert.are_not.equal(drawn, journal.pages)
			assert.are.equal("Interface\\AddOns\\Pagle_Ledger\\media\\crests\\elwynn", ns.CrestIcon())
		end
	)

	it("preview each binding as the kit's closed book of it on the shop's stage, no pages (LED-R110)", function()
		local fake, loaded = ledger()
		local ns = loaded.ns
		local stage = loaded.env.CreateFrame("Frame")
		local atlas = ns.JOURNAL_ATLASES.Bindings

		for _, row in ipairs(GOODS) do
			local id = row[1]
			local look = ns.BindingLook(id)

			fake.ns.goods:Good(id).preview(stage)

			assert.are.equal(1, #stage.children) -- one swatch, drawn afresh for each good
			local swatch = stage.children[1]
			assert.is_true(swatch:IsShown())
			assert.are.equal(atlas.file, swatch.book.texture)
			assert.are.same({ ns.JournalCoords("Bindings", look.swatch) }, swatch.book.texCoord, id)
		end
	end)
end)

describe("the Ledger's zone crests", function()
	-- A Ledger on a fresh fake whose client names each crest's zone by its key backwards (C_Map.GetAreaInfo), with
	-- `celebrated` saved (LED-R90), logged in and in the world over an empty log: no zone is charted.
	---@param celebrated table?
	---@return FakePagle fake
	---@return LoadedAddon loaded
	local function crested(celebrated)
		local fake = newFakePagle()
		fake.catchLog.data.logId = "log"
		if celebrated then
			celebrated.logId = "log"
			fake.globals.PagleLedgerDB = { global = { celebrated = celebrated } }
		end
		local loaded = fake.load("Pagle_Ledger", { holdAddonLoaded = true })
		for _, crest in ipairs(loaded.ns.ZONE_CRESTS) do
			loaded.client.areaNames[crest.areaID] = crest.key:reverse()
		end
		loaded.client.fire("ADDON_LOADED", "Pagle_Ledger")
		fake.login()
		fake.enterWorld()
		return fake, loaded
	end

	it(
		"register in Core's crest slot after Plain, the fifty-three earned goods in LED-R113's order, the Ledger's, in the zone group (LED-R113, SHOP-R23)",
		function()
			local fake, loaded = crested()
			local ns = loaded.ns
			local sorted = ns.SortedZoneCrests(function(areaID)
				return loaded.client.areaNames[areaID]
			end)

			local registered = fake.ns.goods:GoodsOf("core.crest")
			assert.are.equal(54, #registered)
			assert.are.equal("core.crest.plain", registered[1].id)
			for i, crest in ipairs(sorted) do
				local good = registered[i + 1]
				assert.are.same({
					ns.ZoneCrestID(crest),
					"Ledger",
					"zone",
					"Interface\\AddOns\\Pagle_Ledger\\media\\crests\\" .. crest.key,
					ns.L["crest." .. crest.key .. ".name"],
				}, { good.id, good.module, good.group, good.icon, good.name })
				assert.is_false(fake.Pagle.IsOwned(good.id))
			end
			assert.are.equal("Ledger", fake.Pagle.GetGood("ledger.crest.zephras").module)
			assert.are.equal("core.crest.plain", fake.Pagle.GetEquipped("core.crest"))
		end
	)

	it(
		"own the crest of a zone celebrated at Master, which the Journal's bookplate then shows (LED-R114, LED-R112)",
		function()
			local fake, loaded = crested({ coins = 0, zones = { [1] = 5, [12] = 4 } })

			assert.is_true(fake.Pagle.IsOwned("ledger.crest.dunmorogh"))
			assert.is_false(fake.Pagle.IsOwned("ledger.crest.elwynn"))
			assert.is_true(fake.Pagle.SetEquipped("core.crest", "ledger.crest.dunmorogh"))
			assert.are.equal("Interface\\AddOns\\Pagle_Ledger\\media\\crests\\dunmorogh", loaded.ns.CrestIcon())
		end
	)

	it(
		"say on the shop's row and stage how a crest not yet earned is earned, its zone named by the client (LED-R115, SHOP-R22)",
		function()
			local fake = crested()
			local shop = fake.ns.ShopModel()

			-- The fake's catalogue charts zone 12, unfished over the empty log; the new zones aren't charted (LED-R54).
			assert.are.equal("Unfished", shop:Row("ledger.crest.elwynn").tag)
			assert.are.same({
				"Earned when nnywle reaches Master in the Fish Journal. Catch anything there to begin.",
				"A Ledger reward, not for sale",
			}, shop:Stage("ledger.crest.elwynn").notes)
			assert.are.equal("Not yet charted", shop:Row("ledger.crest.riverglades").tag)
			assert.are.same({
				"Earned when sedalgrevir reaches Master in the Fish Journal, once its waters are charted.",
				"A Ledger reward, not for sale",
			}, shop:Stage("ledger.crest.riverglades").notes)
			assert.are.equal("Bookplate crest · Ledger", shop:Stage("ledger.crest.elwynn").slotLine)
		end
	)
end)
