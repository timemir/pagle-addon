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
---@field tier? 1|2|3|4|5           -- Tunables: Core goods' tiers
---@field icon? string              -- a texture path in the client: the shop's swatch, and a crest's look (LED-R112)
---@field soundSet? string          -- a sound set's name in ns.SOUND_SETS (ANN-R72)

--- One of Core's slots, with its goods in the order the shop lists them.
---@class PagleCoreSlot
---@field id string
---@field label string
---@field category "Announcements"|"Bookplate"
---@field openToEarned? true        -- other Modules may add earned goods to it (SHOP-R23): the crest slot
---@field groups? PagleSlotGroup[]  -- its groups on the shop's list (SHOP-R27)
---@field goods PagleCoreGood[]

local ICONS = "Interface\\Icons\\"
-- Plain's own texture (SHOP-R25): 256 x 256, the dashed shield 120:140 at its full height, centred. The zone crests'
-- are the Ledger's (LED-R113).
local CRESTS = "Interface\\AddOns\\Pagle\\media\\crests\\"
-- The slots' labels. logic/ also loads without locale/, in the backend's driver (#223), and then they have none.
local L = ns.L or {}

--- Core's toast style slot (SHOP-R25, ANN-R80).
ns.TOAST_STYLE_SLOT = "core.toaststyle"
--- Torn Page's good ID: the toast style slot's default, and the style for any ID that isn't one.
ns.TOAST_STYLE_DEFAULT = "core.toaststyle.page"
--- Core's sound set slot (SHOP-R25, ANN-R72).
ns.SOUND_SET_SLOT = "core.soundset"
--- Core's bookplate crest slot (SHOP-R25, LED-R112).
ns.CREST_SLOT = "core.crest"

--- Core's slots and goods at M4 (SHOP-R25), in the order they register and the shop lists them. A toast style's
--- look is the toast styles' (ANN-R80); a sound set's sounds are ns.SOUND_SETS[soundSet]; a crest's look is its
--- icon, which the Ledger draws on the Journal's bookplate through Pagle.GetGood (LED-R112). Every good has an icon,
--- the shop's swatch (wallet-and-shop.md › UI). Plain's is Core's own texture, drawn as the shield (SHOP-R25); every
--- other is an in-client texture listed in build 70338's ManifestInterfaceData, standing in until Pagle has its own art.
--- The crest slot holds Plain alone: it is open to earned goods (SHOP-R23), and its zone crests are the Ledger's
--- (LED-R113), drawn on the stage by the slot's preview.
---@type PagleCoreSlot[]
ns.CORE_GOODS = {
	{
		id = ns.TOAST_STYLE_SLOT,
		label = L.SLOT_TOAST_STYLE,
		category = "Announcements",
		goods = {
			{ id = ns.TOAST_STYLE_DEFAULT, default = true, icon = ICONS .. "INV_Crate_01" },
			{ id = "core.toaststyle.ripple", tier = 1, icon = ICONS .. "Ability_Shaman_WaterShield" },
			{ id = "core.toaststyle.lanternglow", tier = 2, icon = ICONS .. "INV_Misc_Lantern_01" },
		},
	},
	{
		id = ns.SOUND_SET_SLOT,
		label = L.SLOT_SOUND_SET,
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
		id = ns.CREST_SLOT,
		label = L.SLOT_CREST,
		category = "Bookplate",
		openToEarned = true,
		-- The Ledger's zone crests and Core's fish crests name these; Plain names none, so it lists first (SHOP-R27).
		groups = {
			{ key = "zone", name = L.SLOT_CREST_ZONES },
			{ key = "fish", name = L.SLOT_CREST_FISH },
		},
		goods = {
			{ id = "core.crest.plain", default = true, icon = CRESTS .. "plain" },
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

--- Draws a good's look on the Curio Shop's stage (wallet-and-shop.md › UI): one per slot, by slot ID. In an open slot
--- it draws other Modules' goods too, from what they registered (their id and icon).
---@alias PagleCorePreview fun(stage: Frame, good: PagleCoreGood|PagleRegisteredGood)

--- Registers Core's slots and goods (SHOP-R25), each good named from lore, or by its ID while its key has no text
--- (graph.md open question 3), with its lore description if any. Login step 1 calls it, once PagleDB is open and
--- before any Module registers. Each good's `preview` draws with `previews[slotID]`, looked up when the shop draws
--- it, so a slot's drawer may be added after this (the toast styles'); with no `previews`, goods have none. A slot
--- open to earned goods takes the same drawer as its `preview`, for the goods other Modules add without one (SHOP-R25).
---@param previews table<string, PagleCorePreview>?
function ns.RegisterCoreGoods(previews)
	for _, slot in ipairs(ns.CORE_GOODS) do
		ns.RegisterCoreSlot({
			id = slot.id,
			label = slot.label,
			category = slot.category,
			groups = slot.groups,
			openToEarned = slot.openToEarned,
			preview = slot.openToEarned and previews and function(stage, good)
				local draw = previews[slot.id]
				if draw then
					draw(stage, good)
				end
			end or nil,
		})
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
