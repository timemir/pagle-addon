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

	it("register the three slots first, in the Curio Shop's categories, with every good's tier (SHOP-R25)", function()
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
				{
					"core.crest.plain default",
					"core.crest.crest1 tier 1",
					"core.crest.crest2 tier 2",
					"core.crest.crest3 tier 3",
				},
			},
		}, slots)
		assert.are.same({ false, false, false }, {
			Pagle.IsOwned("core.toaststyle.ripple"),
			Pagle.IsOwned("core.soundset.gilded"),
			Pagle.IsOwned("core.crest.crest3"),
		})
	end)

	it(
		"tell Pagle.GetGood's readers that Plain is the crest slot's default, a crest no one bought (SHOP-R25)",
		function()
			local loaded = loadCore()
			loaded.client.fire("PLAYER_LOGIN")
			local Pagle = loaded.env.Pagle

			assert.are.same({ true, false }, {
				Pagle.GetGood(Pagle.GetEquipped("core.crest")).isDefault,
				Pagle.GetGood("core.crest.crest1").isDefault,
			})
		end
	)

	it("each have an in-client icon, the Curio Shop's swatch (SHOP-R25, wallet-and-shop.md › UI)", function()
		local loaded = loadCore()
		loaded.client.fire("PLAYER_LOGIN")
		local Pagle = loaded.env.Pagle

		local without = {}
		local count = 0
		for _, slot in ipairs(loaded.ns.goods:Slots()) do
			for _, good in ipairs(loaded.ns.goods:GoodsOf(slot.id)) do
				count = count + 1
				local icon = Pagle.GetGood(good.id).icon
				if type(icon) ~= "string" or not icon:find("^Interface\\Icons\\%S+$") then
					without[#without + 1] = good.id
				end
			end
		end

		assert.are.same({ 9, {} }, { count, without })
	end)
end)

describe("Core's goods' names", function()
	it("are each good's ID, with no description, while its lore key has no text (SHOP-R25, DATA-R104)", function()
		local loaded = loadCoreWithLore() -- the fixture has no key for crest2

		assert.are.same({
			name = "core.crest.crest2",
			slot = "core.crest",
			icon = "Interface\\Icons\\INV_Misc_Gem_Pearl_04",
			module = "Core",
			isDefault = false,
		}, loaded.env.Pagle.GetGood("core.crest.crest2"))
	end)

	it("are read from lore, good.<goodID>.name and .description, once Lore.lua has them (DATA-R101)", function()
		local loaded = loadCoreWithLore()
		local Pagle = loaded.env.Pagle

		local crest = Pagle.GetGood("core.crest.crest1")
		local gilded = Pagle.GetGood("core.soundset.gilded")
		assert.are.same(
			{ "Leaping Trout", "A trout mid-leap, on the bookplate of your Journal." },
			{ crest.name, crest.description }
		)
		assert.are.same({ "Gilded", nil }, { gilded.name, gilded.description })
		assert.are.equal("core.crest.crest2", Pagle.GetGood("core.crest.crest2").name)
		assert.are.equal("Leaping Trout", loaded.env.PagleDB.global.goods["core.crest.crest1"].name) -- SHOP-R26
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
	it("give each crest an in-client icon, the look the Ledger draws (SHOP-R25, LED-R112)", function()
		local loaded = loadCore()

		local icons = {}
		for _, id in ipairs({ "core.crest.plain", "core.crest.crest1", "core.crest.crest2", "core.crest.crest3" }) do
			icons[#icons + 1] = loaded.env.Pagle.GetGood(id).icon
		end

		assert.are.same({
			"Interface\\Icons\\INV_Misc_Note_01",
			"Interface\\Icons\\INV_Fishingpole_02",
			"Interface\\Icons\\INV_Misc_Gem_Pearl_04",
			"Interface\\Icons\\Spell_Frost_SummonWaterElemental",
		}, icons)
	end)

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

	it("draw a crest on a small bookplate with the Angler's name (wallet-and-shop.md › UI)", function()
		local loaded, stage = stageOf()
		local goods = loaded.ns.goods

		goods:Good("core.soundset.gilded").preview(stage)
		goods:Good("core.crest.crest2").preview(stage)

		assert.are.same({ "Interface\\Icons\\INV_Misc_Gem_Pearl_04" }, texturesOn(stage))
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
	end)

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
