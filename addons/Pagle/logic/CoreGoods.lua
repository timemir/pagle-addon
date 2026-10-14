---@class PagleNS
local ns = select(2, ...)

-- Core's own goods (wallet-and-shop.md › Goods, SHOP-R25): the toast style, sound set and bookplate crest slots and
-- their goods, as data, and their registration on Core's goods registry (logic/Goods.lua, logic/Wiring.lua's
-- ns.RegisterCoreSlot and ns.RegisterCoreGood). Pure logic (CORE-R7): adapter/CoreGoods.lua draws the previews, and
-- login step 1 registers them (adapter/Login.lua); FakePagle registers them too, so a Module's specs meet Core's
-- crests.

--- One of Core's goods, as data: exactly one of `default` or `tier` (SHOP-R22). Its name and description are lore
--- (DATA-R101).
---@class PagleCoreGood
---@field id string
---@field default? true
---@field tier? 1|2|3               -- Tunables: Core goods' tiers
---@field icon? string              -- a texture path in the client: the shop's swatch, and a crest's look (LED-R112)
---@field soundSet? string          -- a sound set's name in ns.SOUND_SETS (ANN-R72)

--- One of Core's slots, with its goods in the order the shop lists them.
---@class PagleCoreSlot
---@field id string
---@field label string
---@field category "Announcements"|"Bookplate"
---@field goods PagleCoreGood[]

local ICONS = "Interface\\Icons\\"

--- Core's slots and goods at M4 (SHOP-R25), in the order they register and the shop lists them. A toast style's
--- look is the toast styles' (ANN-R80); a sound set's sounds are ns.SOUND_SETS[soundSet]; a crest's look is its
--- icon, which the Ledger draws on the Journal's bookplate through Pagle.GetGood (LED-R112). Each icon is an
--- in-client texture, standing in until Pagle has its own art.
---@type PagleCoreSlot[]
ns.CORE_GOODS = {
	{
		id = "core.toaststyle",
		label = ns.L.SLOT_TOAST_STYLE,
		category = "Announcements",
		goods = {
			{ id = "core.toaststyle.timber", default = true },
			{ id = "core.toaststyle.ripple", tier = 1 },
			{ id = "core.toaststyle.lanternglow", tier = 2 },
		},
	},
	{
		id = "core.soundset",
		label = ns.L.SLOT_SOUND_SET,
		category = "Announcements",
		goods = {
			{
				id = "core.soundset.driftwood",
				default = true,
				icon = ICONS .. "INV_Misc_Drum_01",
				soundSet = "driftwood",
			},
			{ id = "core.soundset.gilded", tier = 2, icon = ICONS .. "INV_Misc_Bell_01", soundSet = "gilded" },
		},
	},
	{
		id = "core.crest",
		label = ns.L.SLOT_CREST,
		category = "Bookplate",
		goods = {
			{ id = "core.crest.plain", default = true, icon = ICONS .. "INV_Misc_Note_01" },
			{ id = "core.crest.crest1", tier = 1, icon = ICONS .. "INV_Fishingpole_02" },
			{ id = "core.crest.crest2", tier = 2, icon = ICONS .. "INV_Misc_Gem_Pearl_04" },
			{ id = "core.crest.crest3", tier = 3, icon = ICONS .. "Spell_Frost_SummonWaterElemental" },
		},
	},
}

--- The sound set a sound set good plays (ANN-R70, ANN-R72): the good's ns.SOUND_SETS entry, or Driftwood for any
--- other ID or none, as before the slot is registered.
---@param goodID string?
---@return PagleSoundSet
function ns.SoundSetOf(goodID)
	for _, slot in ipairs(ns.CORE_GOODS) do
		for _, good in ipairs(slot.goods) do
			if good.id == goodID and good.soundSet then
				return ns.SOUND_SETS[good.soundSet]
			end
		end
	end
	return ns.SOUND_SETS.driftwood
end

-- A good's lore text for `field` (DATA-R101: `good.<goodID>.<field>`), or nil while the key has none.
---@param goodID string
---@param field "name"|"description"
---@return string?
local function lore(goodID, field)
	local text = rawget(ns.L, ("good.%s.%s"):format(goodID, field))
	if type(text) == "string" and text ~= "" then
		return text
	end
	return nil
end

--- Draws a good's look on the Curio Shop's stage (wallet-and-shop.md › UI): one per slot, by slot ID.
---@alias PagleCorePreview fun(stage: Frame, good: PagleCoreGood)

--- Registers Core's slots and goods (SHOP-R25), each good named from lore, or by its ID while its key has no text
--- (graph.md open question 3), with its lore description if any. Login step 1 calls it, once PagleDB is open and
--- before any Module registers. Each good's `preview` draws with `previews[slotID]`, looked up when the shop draws
--- it, so a slot's drawer may be added after this (the toast styles'); with no `previews`, goods have none.
---@param previews table<string, PagleCorePreview>?
function ns.RegisterCoreGoods(previews)
	for _, slot in ipairs(ns.CORE_GOODS) do
		ns.RegisterCoreSlot({ id = slot.id, label = slot.label, category = slot.category })
		for _, good in ipairs(slot.goods) do
			ns.RegisterCoreGood({
				id = good.id,
				slot = slot.id,
				name = lore(good.id, "name") or good.id,
				description = lore(good.id, "description"),
				icon = good.icon,
				default = good.default,
				tier = good.tier,
				preview = previews and function(stage)
					local draw = previews[slot.id]
					if draw then
						draw(stage, good)
					end
				end,
			})
		end
	end
end
