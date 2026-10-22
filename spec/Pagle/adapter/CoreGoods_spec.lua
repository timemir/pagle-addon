-- Core's own goods as Core runs them, through the real TOC (wallet-and-shop.md › Goods, SHOP-R25; announcements.md
-- › Sounds, ANN-R72; content-data.md › Lore, DATA-R101; ADR 0015): the toast style, sound set, bookplate crest and
-- book binding slots Core registers at login, their goods' names from lore, and the previews they draw on the Curio
-- Shop's stage.

-- The generator's Core Lore.lua for a few good keys (DATA-R104), in its shape: plain assignments to ns.L.
local FIXTURE = "spec/Pagle/fixtures/Lore.lua"

-- Core over an empty log with the fixture Lore.lua loaded in place of the committed data\Lore.lua, in its TOC place
-- (DATA-R75).
---@return LoadedAddon
local function loadCoreWithLore()
	return loadAddon("Pagle", foreverWith({ PagleLog = savedLog() }), { replace = { ["data/Lore.lua"] = FIXTURE } })
end

describe("Core's slots and goods", function()
	it("equip and own Torn Page, Driftwood and Plain after login (SHOP-R22, SHOP-R25, SHOP-R30, SHOP-R32)", function()
		local loaded = loadCore()
		loaded.client.fire("PLAYER_LOGIN")
		local Pagle = loaded.env.Pagle

		assert.are.same({ "core.toaststyle.page", "core.soundset.driftwood", "core.crest.plain" }, {
			Pagle.GetEquipped("core.toaststyle"),
			Pagle.GetEquipped("core.soundset"),
			Pagle.GetEquipped("core.crest"),
		})
		assert.are.same({ true, true, true }, {
			Pagle.IsOwned("core.toaststyle.page"),
			Pagle.IsOwned("core.soundset.driftwood"),
			Pagle.IsOwned("core.crest.plain"),
		})
	end)

	it(
		"register the four slots first, in the Curio Shop's categories, with every good's tier in SHOP-R25's order, the"
			.. " crest slot holding Plain then the fish crests, earned, by Species ID, and the binding slot Field Leather"
			.. " then every binding for sale by tier (SHOP-R22, SHOP-R25, VAR-R12, ADR 0015)",
		function()
			local loaded = loadCore()
			loaded.client.fire("PLAYER_LOGIN")
			local goods = loaded.ns.goods
			local Pagle = loaded.env.Pagle

			local slots = {}
			for _, slot in ipairs(goods:Slots()) do
				local list = {}
				for _, good in ipairs(goods:GoodsOf(slot.id)) do
					local kind = good.default and "default"
						or good.isEarned and "earned " .. tostring(good.group)
						or "tier " .. tostring(good.tier)
					list[#list + 1] = good.id .. " " .. kind
				end
				slots[#slots + 1] = { slot.id, slot.label, slot.category, slot.module, list }
			end
			local crests = { "core.crest.plain default" }
			for _, speciesID in ipairs(FISH_CREST_SPECIES) do
				crests[#crests + 1] = "core.crest.fish." .. speciesID .. " earned fish"
			end
			local bindings = {}
			for i, binding in ipairs(loaded.ns.CoreBindings()) do
				bindings[i] = binding.id .. (binding.default and " default" or " tier " .. binding.tier)
			end
			assert.are.same({ "core.binding.field default", "core.binding.birch tier 1" }, { bindings[1], bindings[2] })
			assert.are.same({ 34, "core.binding.trophycase tier 5" }, { #bindings, bindings[34] })

			assert.are.same({
				{
					"core.toaststyle",
					"Toast style",
					"Announcements",
					"Core",
					{
						"core.toaststyle.page default",
						"core.toaststyle.ripple tier 1",
						"core.toaststyle.lanternglow tier 2",
						"core.toaststyle.ship tier 1",
						"core.toaststyle.birch tier 1",
						"core.toaststyle.tidepool tier 1",
						"core.toaststyle.chart tier 2",
						"core.toaststyle.frost tier 2",
						"core.toaststyle.goblin tier 2",
						"core.toaststyle.kelp tier 3",
						"core.toaststyle.moon tier 3",
						"core.toaststyle.leaf tier 3",
						"core.toaststyle.bottle tier 3",
						"core.toaststyle.rune tier 4",
						"core.toaststyle.folio tier 5",
						"core.toaststyle.storm tier 5",
					},
				},
				{
					"core.soundset",
					"Sound set",
					"Announcements",
					"Core",
					{
						"core.soundset.driftwood default",
						"core.soundset.gilded tier 2",
						"core.soundset.rain tier 1",
						"core.soundset.marimba tier 1",
						"core.soundset.shipbell tier 1",
						"core.soundset.kalimba tier 2",
						"core.soundset.musicbox tier 2",
						"core.soundset.glass tier 2",
						"core.soundset.steelpan tier 2",
						"core.soundset.dulcimer tier 2",
						"core.soundset.frost tier 3",
						"core.soundset.harp tier 3",
						"core.soundset.gizmo tier 3",
						"core.soundset.wardrums tier 4",
					},
				},
				{
					"core.crest",
					"Crests",
					"Crests",
					"Core",
					crests,
				},
				{ "core.binding", "Book binding", "Books", "Core", bindings },
			}, slots)
			assert.are.same({ false, false }, {
				Pagle.IsOwned("core.toaststyle.ripple"),
				Pagle.IsOwned("core.soundset.gilded"),
			})
			assert.are.equal("core.binding.field", Pagle.GetEquipped("core.binding"))
			assert.is_false(Pagle.IsOwned("core.binding.birch"))
			-- All four are open to other Modules' earned goods: the earned toast styles and sound sets, the Ledger's
			-- zone crests, and the Ledger's and Hunts' earned bindings (SHOP-R23, SHOP-R25).
			local open = {}
			for _, slot in ipairs(goods:Slots()) do
				open[#open + 1] = slot.openToEarned == true
			end
			assert.are.same({ true, true, true, true }, open)
		end
	)

	it(
		"take another Module's earned toast style and sound set, owned and equipped like Core's own (SHOP-R23, SHOP-R25, SHOP-R32)",
		function()
			local loaded = loadCore()
			loaded.client.fire("PLAYER_LOGIN")
			local Pagle = loaded.env.Pagle
			local M = Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			local function earned(id, slot)
				return M:RegisterGood({
					id = id,
					slot = slot,
					name = id,
					isEarned = function()
						return true
					end,
					earnedText = "Land a Legend",
				})
			end

			assert.is_nil(earned("ledger.toaststyle.legend", "core.toaststyle"))
			assert.is_nil(earned("ledger.soundset.concertina", "core.soundset"))
			assert.are.same({ true, true }, {
				Pagle.SetEquipped("core.toaststyle", "ledger.toaststyle.legend"),
				Pagle.SetEquipped("core.soundset", "ledger.soundset.concertina"),
			})
			assert.are.same({ "ledger.toaststyle.legend", "ledger.soundset.concertina" }, {
				Pagle.GetEquipped("core.toaststyle"),
				Pagle.GetEquipped("core.soundset"),
			})
		end
	)

	it(
		"tell Pagle.GetGood's readers that Plain is the crest slot's default, and another Module's crest isn't (SHOP-R25)",
		function()
			local loaded = loadCore()
			loaded.client.fire("PLAYER_LOGIN")
			local Pagle = loaded.env.Pagle
			assert.is_nil(loaded.ns.goods:RegisterGood("Ledger", {
				id = "ledger.crest.elwynn",
				slot = "core.crest",
				name = "The Old Oak",
				isEarned = function()
					return true
				end,
			}))

			assert.are.same({ true, false }, {
				Pagle.GetGood(Pagle.GetEquipped("core.crest")).isDefault,
				Pagle.GetGood("ledger.crest.elwynn").isDefault,
			})
		end
	)

	it(
		"each have an icon, the Curio Shop's swatch: Plain's and the fish crests' are Core's own textures, a shop"
			.. " expansion cover's its material, the rest in-client (SHOP-R25, VAR-R12, wallet-and-shop.md › UI)",
		function()
			local loaded = loadCore()
			loaded.client.fire("PLAYER_LOGIN")
			local Pagle = loaded.env.Pagle

			local without = {}
			local count = 0
			for _, slot in ipairs(loaded.ns.goods:Slots()) do
				for _, good in ipairs(loaded.ns.goods:GoodsOf(slot.id)) do
					count = count + 1
					local icon = Pagle.GetGood(good.id).icon
					local key = good.id:match("^core%.crest%.(%a+)$")
					local fish = good.id:match("^core%.crest%.fish%.(%d+)$")
					local cover = good.id:match("^core%.binding%.(%a+)$")
					cover = cover and loaded.ns.BindingLook(good.id).swatchAtlas == "Covers2" and cover
					local expected = key and "^Interface\\AddOns\\Pagle\\media\\crests\\" .. key .. "$"
						or cover and "^Interface\\AddOns\\Pagle\\media\\books\\bindings\\" .. cover .. "$"
						or fish and "^Interface\\AddOns\\Pagle\\media\\crests\\fish\\" .. fish .. "$"
						or "^Interface\\Icons\\%S+$"
					if type(icon) ~= "string" or not icon:find(expected) then
						without[#without + 1] = good.id
					end
				end
			end

			assert.are.same({ 31 + #FISH_CREST_SPECIES + 34, {} }, { count, without })
		end
	)
end)

describe("Core's fish crests on the client (VAR-R12, VAR-R13)", function()
	-- Core held at ADDON_LOADED over `saved` (a PagleDB), with the client's locale `locale` (enUS by default), so a
	-- spec caches item names before login step 1 registers the crests.
	---@param locale string?
	---@param saved table?
	---@return LoadedAddon
	local function held(locale, saved)
		return loadAddon(
			"Pagle",
			foreverWith({
				PagleLog = savedLog(),
				PagleDB = saved,
				GetLocale = function()
					return locale or "enUS"
				end,
			}),
			{ holdAddonLoaded = true }
		)
	end

	it(
		"are named {fish} Crest from the item names the client has, less an enUS client's Raw, Item {itemID} until"
			.. " then, and renamed when the item arrives (SHOP-R26)",
		function()
			local loaded = held()
			loaded.client.itemNames[4603] = "Raw Spotted Yellowtail"
			loaded.client.itemNames[1467] = "Spotted Sunfish"
			loaded.client.fire("ADDON_LOADED", "Pagle")
			local Pagle = loaded.env.Pagle

			assert.are.same({ "Spotted Yellowtail Crest", "Spotted Sunfish Crest", "Item 6289 Crest" }, {
				Pagle.GetGood("core.crest.fish.4603").name,
				Pagle.GetGood("core.crest.fish.1467").name,
				Pagle.GetGood("core.crest.fish.6289").name,
			})
			-- Each fish not cached is asked for, once; the named ones aren't.
			local asked = {}
			for _, itemID in ipairs(loaded.client.itemRequests) do
				asked[itemID] = (asked[itemID] or 0) + 1
			end
			assert.are.same({ 1, nil, nil }, { asked[6289], asked[4603], asked[1467] })

			loaded.client.itemNames[6289] = "Raw Longjaw Mud Snapper"
			loaded.client.fire("GET_ITEM_INFO_RECEIVED", 6289, true)

			assert.are.equal("Longjaw Mud Snapper Crest", Pagle.GetGood("core.crest.fish.6289").name)
			assert.are.equal("Longjaw Mud Snapper Crest", loaded.env.PagleDB.global.goods["core.crest.fish.6289"].name)
		end
	)

	it("leave another locale's item names as the client gives them (VAR-R12)", function()
		local loaded = held("deDE")
		loaded.client.itemNames[4603] = "Raw Spotted Yellowtail"
		loaded.client.fire("ADDON_LOADED", "Pagle")

		assert.are.equal("Raw Spotted Yellowtail Crest", loaded.env.Pagle.GetGood("core.crest.fish.4603").name)
	end)

	it(
		"are owned once all ten of a Species are in Core's variety projection, at its done (VAR-R12, VAR-R13)",
		function()
			local all = {}
			for index = 1, 10 do
				all[index] = true
			end
			local loaded = held()
			loaded.client.fire("ADDON_LOADED", "Pagle")
			local Pagle = loaded.env.Pagle
			assert.is_false(Pagle.IsOwned("core.crest.fish.6358"))

			-- Ten caught in the stored state, then Core's goods asked again, as its variety hook asks them (VAR-R13).
			local stored = loaded.env.PagleDB.global.projections.varieties
			enterWorld(loaded)
			loaded.client.runTimers()
			stored.projection.bySpecies[6358] = all
			loaded.ns.goods:Refresh("Core")

			assert.are.same({ true, false }, {
				Pagle.IsOwned("core.crest.fish.6358"),
				Pagle.IsOwned("core.crest.fish.6359"),
			})
		end
	)
end)

describe("Core's goods' names", function()
	it("are each good's ID, with no description, while its lore key has no text (SHOP-R25, DATA-R104)", function()
		local loaded = loadCoreWithLore() -- the fixture has no key for Lantern Glow

		assert.are.same({
			name = "core.toaststyle.lanternglow",
			slot = "core.toaststyle",
			icon = "Interface\\Icons\\INV_Misc_Lantern_01",
			module = "Core",
			isDefault = false,
		}, loaded.env.Pagle.GetGood("core.toaststyle.lanternglow"))
	end)

	it("are read from lore, good.<goodID>.name and .description, once Lore.lua has them (DATA-R101)", function()
		local loaded = loadCoreWithLore()
		local Pagle = loaded.env.Pagle

		local ripple = Pagle.GetGood("core.toaststyle.ripple")
		local gilded = Pagle.GetGood("core.soundset.gilded")
		assert.are.same(
			{ "Leaping Trout", "A trout mid-leap, rings spreading under it." },
			{ ripple.name, ripple.description }
		)
		assert.are.same({ "Gilded", nil }, { gilded.name, gilded.description })
		assert.are.equal("Driftglass Bottle", Pagle.GetGood("core.toaststyle.bottle").name) -- SHOP-R25
		assert.are.equal("core.toaststyle.lanternglow", Pagle.GetGood("core.toaststyle.lanternglow").name)
		assert.are.equal("Leaping Trout", loaded.env.PagleDB.global.goods["core.toaststyle.ripple"].name) -- SHOP-R26
	end)

	it(
		"read a binding's from Core's lore kind binding, binding.<key>.name and .description (SHOP-R25, DATA-R102)",
		function()
			local loaded = loadCoreWithLore()
			local Pagle = loaded.env.Pagle

			local birch = Pagle.GetGood("core.binding.birch")
			assert.are.same({ "Birch Bark", "Pale bark with dark flecks." }, { birch.name, birch.description })
			assert.are.equal("core.binding.buckram", Pagle.GetGood("core.binding.buckram").name) -- no key in the fixture
		end
	)
end)

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

-- The shown widget on `stage` whose text is `text`, or nil.
---@param stage table
---@param text string
---@return table?
local function withText(stage, text)
	for _, widget in ipairs(shownOn(stage)) do
		if widget.text == text then
			return widget
		end
	end
	return nil
end

-- What the textures shown on `stage` show, in drawing order.
---@param stage table
---@return any[]
local function texturesOn(stage)
	local textures = {}
	for _, widget in ipairs(shownOn(stage)) do
		if widget.kind == "Texture" and widget.texture then
			textures[#textures + 1] = widget.texture
		end
	end
	return textures
end

-- Core logged in, and a stage frame as the Curio Shop hands one to a preview.
---@return LoadedAddon loaded
---@return table stage
local function stageOf()
	local loaded = loadCore()
	loaded.client.fire("PLAYER_LOGIN")
	return loaded, loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent)
end

describe("Core's goods' previews", function()
	it(
		"give Plain and each fish crest its own shipped texture, the look the Ledger draws (SHOP-R25, VAR-R12, LED-R112)",
		function()
			local loaded = loadCore()
			loaded.client.fire("PLAYER_LOGIN")

			local missing = {}
			for _, good in ipairs(loaded.ns.goods:GoodsOf("core.crest")) do
				local file =
					loaded.env.Pagle.GetGood(good.id).icon:match("^Interface\\AddOns\\Pagle\\(media\\crests\\[%w\\]+)$")
				---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
				local handle = file and io.open("addons/Pagle/" .. file:gsub("\\", "/") .. ".blp", "rb")
				if handle then
					handle:close()
				else
					missing[#missing + 1] = good.id
				end
			end

			assert.are.same({}, missing)
			assert.are.equal(1 + #FISH_CREST_SPECIES, #loaded.ns.goods:GoodsOf("core.crest"))
		end
	)

	it("play a sound set's toast, its banner and the first Legend's sting from its buttons (ANN-R72)", function()
		local loaded, stage = stageOf()
		local GILDED = "Interface\\AddOns\\Pagle\\media\\sounds\\gilded\\"

		loaded.ns.goods:Good("core.soundset.gilded").preview(stage)
		for _, label in ipairs({ "» Toast", "» Banner", "» Legend" }) do
			withText(stage, label):Click()
		end

		assert.are.same({
			GILDED .. "toast_1.ogg SFX",
			GILDED .. "banner.ogg SFX",
			"Interface\\AddOns\\Pagle\\media\\sounds\\legend\\19803.ogg SFX",
		}, loaded.client.sounds)
		assert.is_table(withText(stage, "The Legend sting is the same in every set."))
	end)

	it("play Driftwood's toast variants in turn, for the set drawn last on the stage (ANN-R72)", function()
		local loaded, stage = stageOf()
		local DRIFTWOOD = "Interface\\AddOns\\Pagle\\media\\sounds\\driftwood\\"
		local goods = loaded.ns.goods

		goods:Good("core.soundset.gilded").preview(stage)
		goods:Good("core.soundset.driftwood").preview(stage)
		for _ = 1, 4 do
			withText(stage, "» Toast"):Click()
		end

		assert.are.same({
			DRIFTWOOD .. "toast_1.ogg SFX",
			DRIFTWOOD .. "toast_2.ogg SFX",
			DRIFTWOOD .. "toast_3.ogg SFX",
			DRIFTWOOD .. "toast_1.ogg SFX",
		}, loaded.client.sounds)
		assert.are.same({ "Interface\\Icons\\INV_Misc_Drum_01" }, texturesOn(stage))
	end)

	it(
		"draw another Module's crest, with the crest slot's preview, on a small bookplate with the Angler's name (SHOP-R25, wallet-and-shop.md › UI)",
		function()
			local loaded, stage = stageOf()
			local goods = loaded.ns.goods
			local REDRIDGE = "Interface\\AddOns\\Pagle_Ledger\\media\\crests\\redridge"
			local crestSlot = goods:Slots()[3]
			assert.are.equal("core.crest", crestSlot.id)

			goods:Good("core.soundset.gilded").preview(stage)
			goods:Good("core.crest.plain").preview(stage)
			crestSlot.preview(stage, { id = "ledger.crest.redridge", icon = REDRIDGE })

			assert.are.same({ REDRIDGE }, texturesOn(stage))
			local shown = {}
			for _, text in ipairs({ "Ex Libris", "Angler", "On the Fish Journal's bookplate.", "» Toast" }) do
				shown[#shown + 1] = withText(stage, text) ~= nil
			end
			assert.are.same({ true, true, true, false }, shown)
			-- The plate is scaled so its top inset, the plate and the note under it (10 below, one 14-high line) fit the
			-- Curio Shop's 190-high stage.
			local plate = withText(stage, "Ex Libris").parent
			assert.are.equal(0.85, plate:GetScale())
			assert.is_true((16 + 170) * plate:GetScale() + 10 + 14 <= 190)
			-- the crest's shield, 60 x 70 where the icon stood, cropped to the shield and drawn square, not masked round
			local crest
			for _, widget in ipairs(shownOn(stage)) do
				if widget.texture == REDRIDGE then
					crest = widget
				end
			end
			assert.are.same({ 60, 70 }, { crest:GetSize() })
			assert.are.same({ 0.5 - 60 / 140, 0.5 + 60 / 140, 0, 1 }, crest.texCoord)
			assert.is_nil(crest.masks)
		end
	)

	it(
		"draw another Module's toast style as a sample toast and its sound set with the sound buttons, with each slot's preview (SHOP-R25)",
		function()
			local loaded, stage = stageOf()
			local slots = loaded.ns.goods:Slots()
			assert.are.same({ "core.toaststyle", "core.soundset" }, { slots[1].id, slots[2].id })
			local ICON = "Interface\\Icons\\INV_Misc_Note_02"

			slots[2].preview(stage, { id = "ledger.soundset.concertina", icon = ICON })
			assert.are.same({ ICON }, texturesOn(stage))
			assert.is_table(withText(stage, "» Toast"))
			slots[1].preview(stage, { id = "ledger.toaststyle.legend", icon = ICON })
			assert.are.same(
				{ true, false },
				{ withText(stage, "Show on screen") ~= nil, withText(stage, "» Toast") ~= nil }
			)
		end
	)

	it(
		"draw a binding's closed book from the kits' swatch, its drawn book 104 wide 16 down the stage, a Module's earned one with the slot's preview (SHOP-R25, ADR 0015)",
		function()
			local loaded, stage = stageOf()
			local goods, ns = loaded.ns.goods, loaded.ns
			local slot = goods:Slots()[4]
			assert.are.equal("core.binding", slot.id)

			for _, case in ipairs({
				{ "core.binding.field", "Bindings", "binding-field-leather" },
				{ "core.binding.driftwood", "Bindings2", "swatch-driftwood" },
				{ "core.binding.lacquer", "Covers2", "swatch-lacquer" },
			}) do
				goods:Good(case[1]).preview(stage)

				local atlas, sprite = ns.ATLASES[case[2]], ns.ATLASES[case[2]].sprites[case[3]]
				assert.are.same({ atlas.file }, texturesOn(stage), case[1])
				local book
				for _, widget in ipairs(shownOn(stage)) do
					if widget.texture == atlas.file then
						book = widget
					end
				end
				assert.are.same({ sprite.x / atlas.width, (sprite.x + sprite.w) / atlas.width }, {
					book.texCoord[1],
					book.texCoord[2],
				}, case[1])
				assert.are.equal(104, book.box[3], case[1])
				assert.is_table(withText(stage, "Every book of yours wears it."))
			end
			-- the Ledger's earned one, and Hunts', drawn by Core from its own art
			slot.preview(stage, { id = "ledger.binding.keeper", icon = "Interface\\Icons\\INV_Misc_Book_09" })
			assert.are.same({ ns.ATLASES.Bindings2.file }, texturesOn(stage))
			slot.preview(stage, { id = "hunts.binding.wagersilk", icon = "x" })
			assert.are.same({ ns.ATLASES.Covers2.file }, texturesOn(stage))
		end
	)

	it(
		"draw a binding no kit drew closed as a live closed book, 104 x 134, the renderer pinned to it, one per stage, hidden for a swatch (SHOP-R25, BIND-R1, BIND-R2)",
		function()
			local loaded, stage = stageOf()
			local goods, ns, Pagle = loaded.ns.goods, loaded.ns, loaded.env.Pagle
			local made, newBinding = {}, Pagle.NewBookBinding
			Pagle.NewBookBinding = function(frame, options)
				local binding = newBinding(frame, options)
				made[#made + 1] = { frame = frame, options = options, binding = binding }
				return binding
			end

			goods:Good("core.binding.oilcloth").preview(stage)

			assert.are.equal(1, #made)
			local live = made[1]
			assert.are.equal("core.binding.oilcloth", live.options.pinned)
			assert.is_true(live.options.cornerSize < 44 and live.options.giltCornerSize < 40)
			assert.is_true(live.frame:IsShown())
			assert.are.same({ 104, 134 }, { live.frame:GetSize() })
			assert.are.same(ns.BindingLook("core.binding.oilcloth"), live.binding:Look())
			assert.is_table(withText(stage, "Every book of yours wears it."))

			goods:Good("core.binding.tooled").preview(stage) -- the same live book, pinned to the next one

			assert.are.equal(1, #made)
			assert.are.equal("core.binding.tooled", live.binding.pinned)
			assert.are.same(ns.BindingLook("core.binding.tooled"), live.binding:Look())

			goods:Good("core.binding.birch").preview(stage) -- a swatch again after it

			assert.is_false(live.frame:IsShown())
			assert.are.same({ ns.ATLASES.Bindings.file }, texturesOn(stage))
			assert.are.equal(1, #made)
		end
	)

	it("draw a toast style with the drawer its slot has when it is drawn, added after login (ANN-R80)", function()
		local loaded, stage = stageOf()
		local drawn = {}

		loaded.ns.goods:Good("core.toaststyle.ripple").preview(stage) -- no drawer yet: nothing, and no error
		loaded.ns.CORE_PREVIEWS["core.toaststyle"] = function(on, good)
			drawn[#drawn + 1] = { on, good.id }
		end
		loaded.ns.goods:Good("core.toaststyle.ripple").preview(stage)

		assert.are.same({ { stage, "core.toaststyle.ripple" } }, drawn)
	end)
end)
