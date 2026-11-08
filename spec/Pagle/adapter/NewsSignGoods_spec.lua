-- The news sign's looks as Curio Shop goods, from 1.6 (wallet-and-shop.md SHOP-R60–R62; core/news-sign.md SIGN-R57):
-- Core's slot `core.newssign`, Wood free and its default, the five for sale at the dev's tiers; owning, equipping and
-- the sign wearing the equipped look; and the slot's preview with Show on screen. Through the real TOC and the fake
-- client. The crate pool's side is spec/Pagle/logic/Crate_spec.lua's and spec/crate_pool_spec.lua's.

local SLOT = "core.newssign"
local LOOKS = { "wood", "scroll", "lantern", "kraken", "astro", "coral" }
local SIGN_MEDIA = "Interface\\AddOns\\Pagle\\media\\sign\\"

-- Runs `seconds` of frames at 30 a second.
local function run(loaded, seconds)
	for _ = 1, math.floor(seconds * 30 + 0.5) do
		loaded.client.nextFrame(1 / 30)
	end
end

-- Core in the world over a log holding `entries` after BUILD_ENTRY, and PagleDB `saved`.
---@param entries string[]?
---@param saved table?
---@return LoadedAddon
local function core(entries, saved)
	local log = { BUILD_ENTRY }
	for _, entry in ipairs(entries or {}) do
		log[#log + 1] = entry
	end
	return enterWorld(loadCore(log, saved), 2)
end

-- Every widget drawn on `widget`, depth first, shown ones only: what the player sees on it.
---@param widget table
---@param found table[]?
---@return table[]
local function shownOn(widget, found)
	found = found or {}
	for _, child in ipairs(widget.children) do
		if child.shown then
			found[#found + 1] = child
			shownOn(child, found)
		end
	end
	return found
end

-- The textures' files and the font strings' texts shown on `widget`.
---@param widget table
---@return table<string, true> files
---@return table<string, true> texts
local function drawnOn(widget)
	local files, texts = {}, {}
	for _, region in ipairs(shownOn(widget)) do
		if region.kind == "Texture" and type(region.texture) == "string" then
			files[region.texture] = true
		elseif region.kind == "FontString" and region.text then
			texts[region.text] = true
		end
	end
	return files, texts
end

-- The shown button on `widget` labelled `text`, or nil.
local function buttonOn(widget, text)
	for _, region in ipairs(shownOn(widget)) do
		if region.kind == "Button" then
			for _, child in ipairs(region.children) do
				if child.kind == "FontString" and child.text == text then
					return region
				end
			end
			if region.text == text then
				return region
			end
		end
	end
	return nil
end

describe("The news sign's slot (SHOP-R60)", function()
	it("registers core.newssign, News sign, in Announcements, after Core's other slots, with no groups", function()
		local loaded = core()
		local slots = loaded.env.Pagle.GetSlots()
		local last = slots[5]

		assert.are.same(
			{ "core.toaststyle", "core.soundset", "core.crest", "core.binding", SLOT },
			{ slots[1].id, slots[2].id, slots[3].id, slots[4].id, last.id }
		)
		assert.are.same({ "News sign", "Announcements", "Core" }, { last.label, last.category, last.module })
		assert.is_nil(last.groups)
		local slot
		for _, registered in ipairs(loaded.ns.goods:Slots()) do
			slot = registered.id == SLOT and registered or slot
		end
		assert.are_not.equal(true, slot.openToEarned)
	end)

	it("holds six goods in SIGN-R50's order, each ID its look's key, Wood the default (SIGN-R50, SIGN-R57)", function()
		local loaded = core()

		local ids = loaded.env.Pagle.GetSlotGoods(SLOT)
		local expected = {}
		for i, key in ipairs(loaded.ns.NEWS_SIGN_LOOK_ORDER) do
			expected[i] = SLOT .. "." .. key
		end
		assert.are.same(LOOKS, loaded.ns.NEWS_SIGN_LOOK_ORDER)
		assert.are.same(expected, ids)
		assert.are.equal("core.newssign.wood", loaded.ns.NEWS_SIGN_DEFAULT)
	end)

	it(
		"sells the Scroll and the Lantern at tier 3 (900), the Astrolabe and the Coral at tier 4 (3,000) and the Kraken"
			.. " at tier 5 (10,000); Wood is free, the default (SHOP-R25, SHOP-R60)",
		function()
			local loaded = core()
			local Pagle = loaded.env.Pagle

			local priced = {}
			for _, key in ipairs(LOOKS) do
				local good = Pagle.GetGood(SLOT .. "." .. key)
				priced[key] = { good.kind, good.tier, good.price }
			end

			assert.are.same({
				wood = { "default", nil, nil },
				scroll = { "sale", 3, 900 },
				lantern = { "sale", 3, 900 },
				kraken = { "sale", 5, 10000 },
				astro = { "sale", 4, 3000 },
				coral = { "sale", 4, 3000 },
			}, priced)
			assert.is_true(Pagle.GetGood("core.newssign.wood").isDefault)
		end
	)

	it("names each look from lore, good.core.newssign.<look> (DATA-R101)", function()
		local loaded = core()
		local Pagle = loaded.env.Pagle

		local names = {}
		for i, key in ipairs(LOOKS) do
			local good = Pagle.GetGood(SLOT .. "." .. key)
			names[i] = good.name
			assert(type(good.description) == "string", key .. " has a description")
		end

		assert.are.same({ "Wood", "Scroll", "Lantern", "Kraken", "Astrolabe", "Coral" }, names)
	end)

	it("owns and wears Wood from the start, and none of the five (SHOP-R30, SHOP-R32)", function()
		local loaded = core()
		local Pagle = loaded.env.Pagle

		assert.are.equal("core.newssign.wood", Pagle.GetEquipped(SLOT))
		assert.is_true(Pagle.IsOwned("core.newssign.wood"))
		for i = 2, #LOOKS do
			assert(Pagle.IsOwned(SLOT .. "." .. LOOKS[i]) == false, LOOKS[i] .. " is owned")
			assert(Pagle.SetEquipped(SLOT, SLOT .. "." .. LOOKS[i]) == false, LOOKS[i] .. " is equipped")
		end
		assert.are.equal("core.newssign.wood", Pagle.GetEquipped(SLOT))
	end)

	it(
		"owns a bought look, which can then be equipped, firing AppearanceChanged (SHOP-R30, SHOP-R32, SHOP-R33)",
		function()
			local loaded = core({ purchaseEntry(SERVER_TIME - 1000, "core.newssign.kraken", 10000) })
			local Pagle = loaded.env.Pagle
			local changed = {}
			Pagle.RegisterCallback("spec", "AppearanceChanged", function(_, slot, goodID)
				changed[#changed + 1] = { slot, goodID }
			end)

			assert.is_true(Pagle.IsOwned("core.newssign.kraken"))
			assert.is_true(Pagle.SetEquipped(SLOT, "core.newssign.kraken"))

			assert.are.equal("core.newssign.kraken", Pagle.GetEquipped(SLOT))
			assert.are.same({ { SLOT, "core.newssign.kraken" } }, changed)
			assert.is_true(Pagle.GetGood("core.newssign.kraken").purchased)
		end
	)
end)

describe("The look the sign wears (SIGN-R57)", function()
	it("is the equipped look's key, Wood's for any ID that isn't one of the slot's", function()
		local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

		assert.are.same({ "wood", "scroll", "kraken", "astro", "wood", "wood", "wood" }, {
			ns.NewsSignLookOf("core.newssign.wood"),
			ns.NewsSignLookOf("core.newssign.scroll"),
			ns.NewsSignLookOf("core.newssign.kraken"),
			ns.NewsSignLookOf("core.newssign.astro"),
			ns.NewsSignLookOf("core.toaststyle.ripple"),
			ns.NewsSignLookOf(nil),
			ns.NewsSignLookOf("core.newssign."),
		})
	end)

	it("drops the sign in the equipped look when a drop names none", function()
		local loaded = core({ purchaseEntry(SERVER_TIME - 1000, "core.newssign.coral", 3000) })
		local ns = loaded.ns

		ns.DropNewsSign(nil, ns.NewsSignSample("first"))
		run(loaded, 0.5)
		assert.are.equal("wood", ns.NewsSignState().look)
		ns.SendNewsSignUp()
		run(loaded, 2)

		assert.is_true(loaded.env.Pagle.SetEquipped(SLOT, "core.newssign.coral"))
		assert.are.equal("coral", ns.EquippedNewsSignLook())
		ns.DropNewsSign(nil, ns.NewsSignSample("first"))
		run(loaded, 0.5)
		assert.are.equal("coral", ns.NewsSignState().look)
	end)

	it("changes from the next drop: one showing finishes in its look", function()
		local loaded = core({ purchaseEntry(SERVER_TIME - 1000, "core.newssign.lantern", 900) })
		local ns = loaded.ns
		ns.DropNewsSign(nil, ns.NewsSignSample("legend"))
		run(loaded, 1)

		assert.is_true(loaded.env.Pagle.SetEquipped(SLOT, "core.newssign.lantern"))
		run(loaded, 1)
		assert.are.equal("wood", ns.NewsSignState().look)

		run(loaded, 12)
		assert.is_nil(ns.NewsSignState())
		ns.DropNewsSign(nil, ns.NewsSignSample("legend"))
		run(loaded, 0.5)
		assert.are.equal("lantern", ns.NewsSignState().look)
	end)

	it(
		"is Wood when the look equipped isn't owned, after a reset of the log, and comes back once it is (SHOP-R32)",
		function()
			local saved = { profiles = { Default = { appearance = { [SLOT] = "core.newssign.astro" } } } }
			local loaded = core(nil, saved)
			local ns = loaded.ns

			assert.are.equal("core.newssign.wood", loaded.env.Pagle.GetEquipped(SLOT))
			assert.are.equal("wood", ns.EquippedNewsSignLook())
			ns.DropNewsSign(nil, ns.NewsSignSample("first"))
			run(loaded, 0.5)
			assert.are.equal("wood", ns.NewsSignState().look)
			-- The stored choice is kept (SHOP-R32).
			assert.are.equal("core.newssign.astro", ns.db.profile.appearance[SLOT])
		end
	)
end)

describe("The news sign's preview (SHOP-R61)", function()
	-- Core logged in, and a stage frame, 390 x 190, as the Curio Shop hands one to a preview.
	---@return LoadedAddon loaded
	---@return table stage
	local function stageOf(entries)
		local loaded = core(entries)
		local stage = loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent)
		stage:SetSize(390, 190)
		return loaded, stage
	end

	it(
		"draws each look at rest with the Legend sample, its own atlas and the shared one, scaled to fit the well",
		function()
			local loaded, stage = stageOf()
			local sample = loaded.ns.NewsSignSample("legend")

			for _, key in ipairs(LOOKS) do
				loaded.ns.goods:Good(SLOT .. "." .. key).preview(stage)

				local files, texts = drawnOn(stage)
				local atlas = loaded.ns.ATLASES[loaded.ns.NEWS_SIGN_LOOKS[key].atlas].file
				assert(files[atlas], key .. " draws its own atlas")
				for file in pairs(files) do
					if file:find(SIGN_MEDIA, 1, true) then
						assert(file == atlas or file == SIGN_MEDIA .. "SignCommon", key .. " draws " .. file)
					end
				end
				assert(texts[sample.head], key .. " shows the sample's headline")
				assert(texts[sample.detail], key .. " shows the sample's detail")
				-- Scaled into the well, 370 x 132, whole: the tallest, the Scroll, sets the scale for all.
				local sign = loaded.ns.NewsSignPreviewOf(stage)
				local look = loaded.ns.NEWS_SIGN_LOOKS[key]
				local scale = sign:GetScale()
				assert.are.equal(0.75, scale)
				assert(look.w * scale <= 370 and look.h * scale <= 132, key .. " fits the well")
			end
		end
	)

	it("stands still: nothing moves it after it is drawn (announcements.md › Motion)", function()
		local loaded, stage = stageOf()
		loaded.ns.goods:Good("core.newssign.kraken").preview(stage)
		local before = {}
		for i, region in ipairs(shownOn(stage)) do
			before[i] = region.points and region.points[1] and table.concat(region.points[1], ",", 4, 5) or ""
		end

		run(loaded, 2)

		local after = {}
		for i, region in ipairs(shownOn(stage)) do
			after[i] = region.points and region.points[1] and table.concat(region.points[1], ",", 4, 5) or ""
		end
		assert.are.same(before, after)
	end)

	it("has Show on screen under the well, inside the stage", function()
		local loaded, stage = stageOf()
		loaded.ns.goods:Good("core.newssign.scroll").preview(stage)

		local button = assert(buttonOn(stage, "Show on screen"))
		local _, _, _, _, y = button:GetPoint(1)
		local height = button:GetHeight()
		assert(-y >= 132, "under the well")
		assert(-y + height <= 190, "inside the stage")
	end)

	it(
		"drops the real sign in that look with the Legend sample on Show on screen, owned or not, dev mode off",
		function()
			local loaded, stage = stageOf()
			loaded.ns.goods:Good("core.newssign.astro").preview(stage)

			assert.is_false(loaded.env.Pagle.IsOwned("core.newssign.astro"))
			buttonOn(stage, "Show on screen"):Click()
			run(loaded, 0.5)

			local state = assert(loaded.ns.NewsSignState())
			assert.are.equal("astro", state.look)
			assert.are.equal(loaded.ns.NewsSignSample("legend").head, state.words.lines[2].f:GetText())
			assert.are.equal("core.newssign.wood", loaded.env.Pagle.GetEquipped(SLOT)) -- it equips nothing
		end
	)

	it("opens nothing on a left click, and goes up (SIGN-R42)", function()
		local loaded, stage = stageOf()
		local opened = 0
		loaded.ns.OpenNewsSignNews = function()
			opened = opened + 1
		end
		loaded.ns.goods:Good("core.newssign.coral").preview(stage)
		buttonOn(stage, "Show on screen"):Click()
		run(loaded, 3)
		local frame = loaded.ns.NewsSignFrame()

		frame:GetScript("OnMouseDown")(frame, "LeftButton")
		frame:GetScript("OnClick")(frame, "LeftButton")

		assert.are.equal(0, opened)
		assert.is_true(loaded.ns.NewsSignState().exiting)
	end)

	it("waits while restricted, as any drop does (SIGN-R40)", function()
		local loaded, stage = stageOf()
		loaded.ns.goods:Good("core.newssign.lantern").preview(stage)
		setCombat(loaded, true)

		buttonOn(stage, "Show on screen"):Click()
		run(loaded, 1)
		assert.is_nil(loaded.ns.NewsSignState())

		setCombat(loaded, false)
		run(loaded, 1)
		assert.are.equal("lantern", loaded.ns.NewsSignState().look)
	end)

	it("is what Pagle.DrawGoodPreview draws, as a card and as a stage (SHOP-R36, LED-R170)", function()
		local loaded = core()
		local card = loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent)
		card:SetSize(185, 66)

		loaded.env.Pagle.DrawGoodPreview(card, "core.newssign.kraken", "card")

		local files = drawnOn(card)
		assert.is_true(files[SIGN_MEDIA .. "SignKraken"] == true)
		assert.is_table(buttonOn(card, "Show on screen"))
	end)
end)

describe("Buying a look in the Curio Shop (SHOP-R10, SHOP-R60)", function()
	it("buys the Scroll for 900 Coins, in use at once, and the sign then wears it (SIGN-R57)", function()
		local loaded = core()
		local Pagle = loaded.env.Pagle
		local ledger = Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
		ledger:ReportCoinsEarned(1000)

		Pagle.OpenShop("core.newssign.scroll")
		local frame = loaded.ns.shopFrame
		frame.stage.buy:Click()
		frame.bill.buy:Click()
		run(loaded, 3)

		assert.matches(
			"|core%.newssign%.scroll|900$",
			logEntries(loaded.env.PagleLog)[#logEntries(loaded.env.PagleLog)]
		)
		assert.are.equal(100, Pagle.GetBalance().balance)
		assert.are.equal("core.newssign.scroll", Pagle.GetEquipped(SLOT))
		loaded.ns.DropNewsSign(nil, loaded.ns.NewsSignSample("hunt"))
		run(loaded, 0.5)
		assert.are.equal("scroll", loaded.ns.NewsSignState().look)
	end)
end)
