-- Core's own goods as Core runs them, through the real TOC (wallet-and-shop.md › Goods, SHOP-R25; announcements.md
-- › Sounds, ANN-R72; content-data.md › Lore, DATA-R101): the toast style, sound set and bookplate crest slots Core
-- registers at login, their goods' names from lore, and the previews they draw on the Curio Shop's stage.

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
		"register the three slots first, in the Curio Shop's categories, with every good's tier, the crest slot holding Plain alone (SHOP-R25)",
		function()
			local loaded = loadCore()
			loaded.client.fire("PLAYER_LOGIN")
			local goods = loaded.ns.goods
			local Pagle = loaded.env.Pagle

			local slots = {}
			for _, slot in ipairs(goods:Slots()) do
				local list = {}
				for _, good in ipairs(goods:GoodsOf(slot.id)) do
					list[#list + 1] = good.id .. " " .. (good.default and "default" or "tier " .. tostring(good.tier))
				end
				slots[#slots + 1] = { slot.id, slot.label, slot.category, slot.module, list }
			end

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
					},
				},
				{
					"core.soundset",
					"Sound set",
					"Announcements",
					"Core",
					{ "core.soundset.driftwood default", "core.soundset.gilded tier 2" },
				},
				{
					"core.crest",
					"Bookplate crest",
					"Bookplate",
					"Core",
					{ "core.crest.plain default" },
				},
			}, slots)
			assert.are.same({ false, false }, {
				Pagle.IsOwned("core.toaststyle.ripple"),
				Pagle.IsOwned("core.soundset.gilded"),
			})
			-- All three are open to other Modules' earned goods: the earned toast styles and sound sets, and the Ledger's
			-- zone crests (SHOP-R23, SHOP-R25).
			local open = {}
			for _, slot in ipairs(goods:Slots()) do
				open[#open + 1] = slot.openToEarned == true
			end
			assert.are.same({ true, true, true }, open)
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
		"each have an icon, the Curio Shop's swatch: Plain's is Core's own texture, the rest in-client (SHOP-R25, wallet-and-shop.md › UI)",
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
					local expected = key and "^Interface\\AddOns\\Pagle\\media\\crests\\" .. key .. "$"
						or "^Interface\\Icons\\%S+$"
					if type(icon) ~= "string" or not icon:find(expected) then
						without[#without + 1] = good.id
					end
				end
			end

			assert.are.same({ 6, {} }, { count, without })
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
		assert.are.equal("core.toaststyle.lanternglow", Pagle.GetGood("core.toaststyle.lanternglow").name)
		assert.are.equal("Leaping Trout", loaded.env.PagleDB.global.goods["core.toaststyle.ripple"].name) -- SHOP-R26
	end)
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
		"give Plain, Core's one crest, its own shipped texture, the look the Ledger draws (SHOP-R25, LED-R112)",
		function()
			local loaded = loadCore()
			loaded.client.fire("PLAYER_LOGIN")

			local missing = {}
			for _, good in ipairs(loaded.ns.goods:GoodsOf("core.crest")) do
				local file =
					loaded.env.Pagle.GetGood(good.id).icon:match("^Interface\\AddOns\\Pagle\\(media\\crests\\%a+)$")
				---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
				local handle = file and io.open("addons/Pagle/" .. file:gsub("\\", "/") .. ".blp", "rb")
				if handle then
					handle:close()
				else
					missing[#missing + 1] = good.id
				end
			end

			assert.are.same({}, missing)
			assert.are.equal(1, #loaded.ns.goods:GoodsOf("core.crest"))
		end
	)

	it("play a sound set's toast, its banner and the shared Legend sting from its buttons (ANN-R72)", function()
		local loaded, stage = stageOf()
		local GILDED = "Interface\\AddOns\\Pagle\\media\\sounds\\gilded\\"

		loaded.ns.goods:Good("core.soundset.gilded").preview(stage)
		for _, label in ipairs({ "» Toast", "» Banner", "» Legend" }) do
			withText(stage, label):Click()
		end

		assert.are.same({
			GILDED .. "toast_1.ogg SFX",
			GILDED .. "banner.ogg SFX",
			"Interface\\AddOns\\Pagle\\media\\sounds\\legend.ogg SFX",
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
