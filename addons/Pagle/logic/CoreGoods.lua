---@class PagleNS
local ns = select(2, ...)

-- Core's own goods (wallet-and-shop.md › Goods, SHOP-R25): the toast style, sound set, bookplate crest and book
-- binding slots and their goods, as data (the bindings' from logic/Bindings.lua), and their registration on Core's
-- goods registry (logic/Goods.lua, logic/Wiring.lua's ns.RegisterCoreSlot and ns.RegisterCoreGood). Pure logic
-- (CORE-R7): adapter/CoreGoods.lua draws the previews, and login step 1 registers them (adapter/Login.lua); FakePagle
-- registers them too, so a Module's specs meet Core's crests and bindings.

--- One of Core's goods, as data: exactly one of `default`, `tier`, `companion` or `crate` (SHOP-R22). Its name and
--- description are lore (DATA-R101).
---@class PagleCoreGood
---@field id string
---@field default? true
---@field tier? 1|2|3|4|5           -- Tunables: Core goods' tiers
---@field companion? true           -- earned once the companion is linked (Sonar Scope, SHOP-R29)
---@field crate? true               -- crate only (Prize Foil, SHOP-R22, SHOP-R50)
---@field icon? string              -- a texture path in the client: the shop's swatch, and a crest's look (LED-R112)
---@field variants? integer         -- a sound set's toast variants, if not three (ANN-R74; Tunables): Gilded's one
---@field lore? string              -- its lore keys' `<kind>.<id>` (DATA-R101): `good.<goodID>` without one

--- One of Core's slots, with its goods in the order the shop lists them.
---@class PagleCoreSlot
---@field id string
---@field label string
---@field category "Announcements"|"Crests"|"Books"
---@field openToEarned? true        -- other Modules may add earned goods to it (SHOP-R23): all four
---@field hideEarned? true          -- the shop lists none of its earned goods; Look and Feel equips them (SHOP-R25)
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
--- Driftwood's good ID: the sound set slot's default, and the set for any ID that isn't one.
ns.SOUND_SET_DEFAULT = "core.soundset.driftwood"
--- Core's bookplate crest slot (SHOP-R25, LED-R112).
ns.CREST_SLOT = "core.crest"

-- Core's book binding slot's goods (SHOP-R25): Field Leather and every binding for sale, in the shop's order
-- (ns.CoreBindings), each named from Core's lore kind `binding` (`binding.<key>.*`, DATA-R102).
---@type PagleCoreGood[]
local BINDING_GOODS = {}
for i, binding in ipairs(ns.CoreBindings()) do
	BINDING_GOODS[i] = {
		id = binding.id,
		default = binding.default,
		tier = binding.tier,
		icon = binding.icon,
		lore = "binding." .. binding.key,
	}
end

--- Core's slots and goods (SHOP-R25), in the order they register and the shop lists them. A toast style's look is
--- its ns.TOAST_STYLES entry (ANN-R80); a sound set's sounds are its ns.SOUND_SETS entry (ANN-R72); a crest's look is
--- its icon, which the Ledger draws on the Journal's bookplate through Pagle.GetGood (LED-R112). Every good has an
--- icon, the shop's swatch (wallet-and-shop.md › UI). Plain's is Core's own texture, drawn as the shield (SHOP-R25);
--- every other is an in-client texture listed in build 70338's ManifestInterfaceData, standing in until Pagle has its
--- own art. A binding's look is its ns.BindingLook (logic/Bindings.lua), which every book wears (ADR 0015). All four
--- slots are open to earned goods (SHOP-R23): the toast styles and sound sets the Ledger, Hunts and the Tackle Board
--- earn, the Ledger's zone crests (LED-R113), and the bindings the Ledger and Hunts earn (LED-R110, HNT-R122), each
--- drawn on the stage by its slot's preview. The crest slot holds Plain alone, and hides its earned crests, the zone
--- crests and Core's fish crests (VAR-R12), from the shop: Look and Feel equips them (SHOP-R25).
---@type PagleCoreSlot[]
ns.CORE_GOODS = {
	{
		id = ns.TOAST_STYLE_SLOT,
		label = L.SLOT_TOAST_STYLE,
		category = "Announcements",
		openToEarned = true,
		goods = {
			{ id = ns.TOAST_STYLE_DEFAULT, default = true, icon = ICONS .. "INV_Crate_01" },
			{ id = "core.toaststyle.ripple", tier = 1, icon = ICONS .. "Ability_Shaman_WaterShield" },
			{ id = "core.toaststyle.lanternglow", tier = 2, icon = ICONS .. "INV_Misc_Lantern_01" },
			-- The Curio Shop expansion's (ANN-R81).
			{ id = "core.toaststyle.ship", tier = 1, icon = ICONS .. "INV_Misc_Spyglass_02" },
			{ id = "core.toaststyle.birch", tier = 1, icon = ICONS .. "INV_Scroll_03" },
			{ id = "core.toaststyle.tidepool", tier = 1, icon = ICONS .. "INV_Misc_Shell_01" },
			{ id = "core.toaststyle.chart", tier = 2, icon = ICONS .. "INV_Misc_Map_01" },
			{ id = "core.toaststyle.frost", tier = 2, icon = ICONS .. "Spell_Frost_FrostArmor02" },
			{ id = "core.toaststyle.goblin", tier = 2, icon = ICONS .. "INV_Misc_Gear_01" },
			{ id = "core.toaststyle.kelp", tier = 3, icon = ICONS .. "INV_Misc_Gem_Pearl_03" },
			{ id = "core.toaststyle.moon", tier = 3, icon = ICONS .. "Spell_Nature_StarFall" },
			{ id = "core.toaststyle.leaf", tier = 3, icon = ICONS .. "INV_Misc_Herb_10" },
			{ id = "core.toaststyle.bottle", tier = 3, icon = ICONS .. "INV_Drink_07" },
			{ id = "core.toaststyle.rune", tier = 4, icon = ICONS .. "INV_Misc_Rune_01" },
			{ id = "core.toaststyle.folio", tier = 5, icon = ICONS .. "INV_Misc_Book_11" },
			-- The round two's (ANN-R82): Storm Front for sale (and in the Curio crate), Sonar Scope earned once the
			-- companion is linked (SHOP-R29), Prize Foil the crate's alone (SHOP-R50).
			{ id = "core.toaststyle.storm", tier = 5, icon = ICONS .. "Spell_Nature_Lightning" },
			{ id = "core.toaststyle.sonar", companion = true, icon = ICONS .. "Spell_Holy_MindVision" },
			{ id = "core.toaststyle.foil", crate = true, icon = ICONS .. "INV_Misc_Gem_Opal_01" },
		},
	},
	{
		id = ns.SOUND_SET_SLOT,
		label = L.SLOT_SOUND_SET,
		category = "Announcements",
		openToEarned = true,
		goods = {
			{ id = ns.SOUND_SET_DEFAULT, default = true, icon = ICONS .. "INV_Misc_Drum_01" },
			{ id = "core.soundset.gilded", tier = 2, variants = 1, icon = ICONS .. "INV_Misc_Bell_01" },
			-- The Curio Shop expansion's (ANN-R72).
			{ id = "core.soundset.rain", tier = 1, icon = ICONS .. "Spell_Nature_Tranquility" },
			{ id = "core.soundset.marimba", tier = 1, icon = ICONS .. "INV_Misc_Drum_02" },
			{ id = "core.soundset.shipbell", tier = 1, icon = ICONS .. "INV_Misc_Horn_01" },
			{ id = "core.soundset.kalimba", tier = 2, icon = ICONS .. "Spell_Frost_SummonWaterElemental" },
			{ id = "core.soundset.musicbox", tier = 2, icon = ICONS .. "INV_Box_01" },
			{ id = "core.soundset.glass", tier = 2, icon = ICONS .. "INV_Misc_Orb_01" },
			{ id = "core.soundset.steelpan", tier = 2, icon = ICONS .. "INV_Misc_Drum_03" },
			{ id = "core.soundset.dulcimer", tier = 2, icon = ICONS .. "INV_Drink_04" },
			{ id = "core.soundset.frost", tier = 3, icon = ICONS .. "Spell_Frost_FrostNova" },
			{ id = "core.soundset.harp", tier = 3, icon = ICONS .. "Spell_Nature_Regeneration" },
			{ id = "core.soundset.gizmo", tier = 3, icon = ICONS .. "INV_Gizmo_BronzeFramework_01" },
			{ id = "core.soundset.wardrums", tier = 4, icon = ICONS .. "Ability_Warrior_BattleShout" },
		},
	},
	{
		id = ns.CREST_SLOT,
		label = L.SLOT_CREST,
		category = "Crests",
		openToEarned = true,
		hideEarned = true,
		-- The Ledger's zone crests and Core's fish crests name these (SHOP-R27); the shop lists neither (hideEarned).
		groups = {
			{ key = "zone", name = L.SLOT_CREST_ZONES },
			{ key = "fish", name = L.SLOT_CREST_FISH },
		},
		goods = {
			{ id = "core.crest.plain", default = true, icon = CRESTS .. "plain" },
		},
	},
	{
		id = ns.BINDING_SLOT,
		label = L.SLOT_BOOK_BINDING,
		category = "Books",
		openToEarned = true,
		goods = BINDING_GOODS,
	},
}

-- A good's lore text for `field` (DATA-R101: `<kind>.<id>.<field>`, `good.<goodID>` unless `key` names another),
-- or nil while the key has none.
---@param goodID string
---@param field "name"|"description"
---@param key string? its lore keys' `<kind>.<id>`
---@return string?
local function lore(goodID, field, key)
	local text = rawget(ns.L, ("%s.%s"):format(key or ("good." .. goodID), field))
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
			hideEarned = slot.hideEarned,
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
				name = lore(good.id, "name", good.lore) or good.id,
				description = lore(good.id, "description", good.lore),
				icon = good.icon,
				default = good.default,
				tier = good.tier,
				crate = good.crate,
				isEarned = good.companion and function()
					return ns.CompanionLinked()
				end or nil,
				earnedText = good.companion and L.SHOP_SONAR_EARNED or nil,
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

--- The fish crests' group in the crest slot's list (SHOP-R27, VAR-R12).
ns.FISH_CREST_GROUP = "fish"

-- The fish crests' textures, Core's own (VAR-R12, UI): 256 x 256 as the zone crests, by Species ID.
local FISH_CRESTS = CRESTS .. "fish\\"
-- A Species' varieties (VAR-R2).
local VARIETIES = 10

--- A Species' fish crest's good ID (VAR-R12).
---@param speciesID integer
---@return string
function ns.FishCrestID(speciesID)
	return "core.crest.fish." .. speciesID
end

--- What the fish crests read from the client and from Core, each when asked.
---@class PagleFishCrestHooks
---@field species integer[]                            -- the Species with varieties, in the crests' order
---@field caught fun(speciesID: integer): table<integer, true> -- Pagle.GetVarietiesCaught (VAR-R11)
---@field itemName fun(itemID: integer): string?      -- the client's cached name, nil until it has it
---@field dropPrefix string?                           -- the prefix a crest's fish drops: "Raw " on an enUS client
---@field owned fun(goodID: string): boolean           -- Pagle.IsOwned: the cached isEarned() (SHOP-R26)

--- A fish crest's fish (VAR-R12): the Species' item name as the client has it, less `dropPrefix` when it starts with
--- it ("Raw Spotted Yellowtail" is "Spotted Yellowtail"), or nil while the client hasn't cached it.
---@param hooks PagleFishCrestHooks
---@param speciesID integer
---@return string?
function ns.FishCrestFish(hooks, speciesID)
	local name = hooks.itemName(speciesID)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	local prefix = hooks.dropPrefix
	if prefix and prefix ~= "" and #name > #prefix and name:sub(1, #prefix) == prefix then
		return name:sub(#prefix + 1)
	end
	return name
end

--- A fish crest's name (VAR-R12): lore's "{fish} Crest" with `fish`, else "Item {itemID}" (the fish not cached yet),
--- or the good's ID while lore has no name for it.
---@param speciesID integer
---@param fish string?
---@return string
function ns.FishCrestName(speciesID, fish)
	local id = ns.FishCrestID(speciesID)
	local pattern = ns.L and lore(id, "name")
	if not pattern then
		return id
	end
	fish = fish or L.FISH_CREST_ITEM:format(speciesID)
	return (pattern:gsub("{fish}", function()
		return fish
	end))
end

--- How many of a Species' ten are caught, in a set `{ [index] = true }`.
---@param caught table<integer, true>
---@return integer
local function countCaught(caught)
	local n = 0
	for index = 1, VARIETIES do
		if caught[index] then
			n = n + 1
		end
	end
	return n
end

--- A fish crest's texts while it isn't earned (VAR-R13, VAR-R14): the row's tag, "{n} of 10 varieties", and the
--- stage's note, "{n} of 10 {fish} varieties. Still out there: {the count of each rarity uncaught, Common first}.".
--- It counts the uncaught by rarity only, never naming one (VAR-R27).
---@param caught table<integer, true>
---@param fish string the Species' name, or "Item {itemID}"
---@return string row
---@return string note
function ns.FishCrestTexts(caught, fish)
	local n = countCaught(caught)
	local counts, order = {}, {}
	for index = 1, VARIETIES do
		local rarity = ns.VarietyRarity(index)
		if rarity and not caught[index] then
			if not counts[rarity.key] then
				order[#order + 1] = rarity
			end
			counts[rarity.key] = (counts[rarity.key] or 0) + 1
		end
	end
	local parts = {}
	for i, rarity in ipairs(order) do
		parts[i] = L.FISH_CREST_UNCAUGHT:format(counts[rarity.key], rarity.name or rarity.key)
	end
	local row = L.FISH_CREST_ROW:format(n)
	if #parts == 0 then
		return row, L.FISH_CREST_NOTE_ALL:format(n, fish)
	end
	return row, L.FISH_CREST_NOTE:format(n, fish, table.concat(parts, L.FISH_CREST_UNCAUGHT_JOIN))
end

--- A fish crest's progress (VAR-R14, SHOP-R22): ten dots in variety order, each in its rarity's colour, filled when
--- caught.
---@param caught table<integer, true>
---@return PagleProgressDot[]
function ns.FishCrestDots(caught)
	local dots = {}
	for index = 1, VARIETIES do
		local rarity = ns.VarietyRarity(index) --[[@as PagleVarietyRarity]]
		dots[index] = { color = { unpack(rarity.color) }, filled = caught[index] == true }
	end
	return dots
end

--- Core's fish crests (VAR-R12), one per Species with varieties in `hooks.species`'s order: `core.crest.fish.<id>` in
--- the crest slot's fish group, earned once all ten of its Species are caught in Core's variety projection, and kept
--- once earned (VAR-R90: the cached result stands), with the crest's own texture as its icon and lore's description.
--- Its name is ns.FishCrestName over the fish as the client has it now; its texts and dots are worked out each time
--- the shop draws it (SHOP-R22). No preview: the crest slot's draws it on the stage's bookplate (SHOP-R25).
---@param hooks PagleFishCrestHooks
---@return PagleGood[]
function ns.FishCrestGoods(hooks)
	local goods = {}
	for i, speciesID in ipairs(hooks.species) do
		local id = ns.FishCrestID(speciesID)
		goods[i] = {
			id = id,
			slot = ns.CREST_SLOT,
			group = ns.FISH_CREST_GROUP,
			name = ns.FishCrestName(speciesID, ns.FishCrestFish(hooks, speciesID)),
			description = lore(id, "description"),
			icon = FISH_CRESTS .. speciesID,
			isEarned = function()
				return hooks.owned(id) or countCaught(hooks.caught(speciesID)) >= VARIETIES
			end,
			earnedText = function()
				local fish = ns.FishCrestFish(hooks, speciesID) or L.FISH_CREST_ITEM:format(speciesID)
				return ns.FishCrestTexts(hooks.caught(speciesID), fish)
			end,
			progress = function()
				return ns.FishCrestDots(hooks.caught(speciesID))
			end,
		}
	end
	return goods
end

--- Registers Core's fish crests (VAR-R12) in its crest slot, after ns.RegisterCoreGoods, and refreshes Core's goods
--- from ns.OnVarietiesCaught's hook, so their isEarned() runs only at registration, after the variety projection's
--- done and after a live Catch adding a variety (VAR-R13, SHOP-R31). Returns the function that renames each crest
--- whose fish the client has named since (SHOP-R26): call it when an item's data arrives.
---@param hooks PagleFishCrestHooks
---@return fun(itemID: integer)
function ns.RegisterFishCrests(hooks)
	local named = {}
	for _, good in ipairs(ns.FishCrestGoods(hooks)) do
		ns.RegisterCoreGood(good)
	end
	for _, speciesID in ipairs(hooks.species) do
		named[speciesID] = ns.FishCrestFish(hooks, speciesID) ~= nil
	end
	ns.OnVarietiesCaught(function()
		ns.goods:Refresh(ns.CORE_OWNER)
	end)
	return function(itemID)
		if named[itemID] == false then
			local fish = ns.FishCrestFish(hooks, itemID)
			if fish then
				named[itemID] = true
				ns.RenameCoreGood(ns.FishCrestID(itemID), ns.FishCrestName(itemID, fish))
			end
		end
	end
end
