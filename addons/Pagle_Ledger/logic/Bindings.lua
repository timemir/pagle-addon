if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Journal bindings (LED-R110–R112): the Ledger's one slot, its ten goods and each one's tints, and when a level
-- binding is earned. Pure logic, everything passed in (CORE-R7); adapter/Bindings.lua registers them and draws the
-- swatch, adapter/Journal.lua tints the book.

--- The Ledger's slot (LED-R110).
ns.BINDING_SLOT = "ledger.binding"

--- Every binding's icon, the shop's swatch for one put away (wallet-and-shop.md › UI): the ledger book the level-up
--- moment shows (LED-R97).
ns.BINDING_ICON = "Interface\\Icons\\INV_Misc_Book_09"

--- A binding: its good's last ID part (`ledger.binding.<name>`, and its lore keys `binding.<name>.*`, LED-R160),
--- its kind (exactly one of `default`, `level` for an earned one, `tier` for one for sale), and its look as the Ledger
--- art kit's Bindings.lua measured it from the canvas's swatches: the leather's texture (`leather`, Core's own Field
--- Leather; `leatherGrey` under a vertex `tint`; or Birch Bark's `bark` and Buckram's `cloth`), the gilt of the
--- crumbs, fleurons and plate ("RRGGBB"), the band's tone for a cloth or bark binding, and its closed-book swatch.
---@class LedgerBinding
---@field name string
---@field default? true
---@field level? integer -- earned at this peak or celebrated level (LED-R111)
---@field tier? 1|2|3
---@field texture "leather"|"leatherGrey"|"bark"|"cloth"
---@field tint? number[]  -- the grey leather's vertex tint, { r, g, b }
---@field gilt string
---@field band? string    -- the band's tone over a bark or cloth binding, "RRGGBB"
---@field swatch string   -- its closed book in the Bindings atlas

--- LED-R110's bindings, in its order: the kit's ten, one to one with the goods (its Bindings.lua, `bindings.json`).
---@type LedgerBinding[]
ns.BINDINGS = {
	{ name = "field", default = true, texture = "leather", gilt = "e8c96a", swatch = "binding-field-leather" },
	{
		name = "level10", -- Tanned Hide
		level = 10,
		texture = "leatherGrey",
		tint = { 0.736, 0.386, 0.008 },
		gilt = "f0d890",
		swatch = "binding-tanned-hide",
	},
	{
		name = "level20", -- Tidewater Blue
		level = 20,
		texture = "leatherGrey",
		tint = { 0.188, 0.363, 0.563 },
		gilt = "c9ccd3",
		swatch = "binding-tidewater-blue",
	},
	{
		name = "level30", -- Reed Green
		level = 30,
		texture = "leatherGrey",
		tint = { 0.207, 0.422, 0.192 },
		gilt = "d8c47a",
		swatch = "binding-reed-green",
	},
	{
		name = "level40", -- Oxblood
		level = 40,
		texture = "leatherGrey",
		tint = { 0.689, 0.179, 0.179 },
		gilt = "f2c230",
		swatch = "binding-oxblood",
	},
	{
		name = "level50", -- Storm Grey
		level = 50,
		texture = "leatherGrey",
		tint = { 0.296, 0.341, 0.381 },
		gilt = "c9ccd3",
		swatch = "binding-storm-grey",
	},
	{
		name = "level60", -- Nat's Own
		level = 60,
		texture = "leatherGrey",
		tint = { 0.213, 0.174, 0.147 },
		gilt = "ffd100",
		swatch = "binding-nats-own",
	},
	{ name = "birch", tier = 1, texture = "bark", gilt = "6a4a20", band = "b8a888", swatch = "binding-birch-bark" },
	{
		name = "buckram", -- Sea-Green Buckram
		tier = 2,
		texture = "cloth",
		gilt = "efe0bb",
		band = "6a9a8c",
		swatch = "binding-sea-green-buckram",
	},
	{
		name = "sharkskin",
		tier = 3,
		texture = "leatherGrey",
		tint = { 0.235, 0.282, 0.306 },
		gilt = "dfe2e8",
		swatch = "binding-sharkskin",
	},
}

--- A binding's good ID (LED-R110).
---@param binding LedgerBinding
---@return string
function ns.BindingID(binding)
	return ns.BINDING_SLOT .. "." .. binding.name
end

--- A tint from its hex code, as the prototypes' CSS writes it: { r, g, b }, 0 to 1.
---@param hex string "RRGGBB"
---@return number[]
function ns.HexTint(hex)
	return {
		tonumber(hex:sub(1, 2), 16) / 255,
		tonumber(hex:sub(3, 4), 16) / 255,
		tonumber(hex:sub(5, 6), 16) / 255,
	}
end

-- How near a gilt's red and blue are for it to read as silver, which turns the brass plate silver (the kit's).
local SILVER = 0.12
-- How much of the binding's hue the page paper takes ("the page paper cools slightly").
local PAPER_SHARE = 0.1
-- A bark or cloth leather's tile, in UI units (its texture is 512 texels at 2 a unit); a leather's is 128.
local CLOTH_TILE = 256

--- What a binding draws (LED-R110): the leather's texture, its tile and tint, the band's tone, the gilt, whether the
--- plate turns silver, the page paper's tint and the closed book's swatch.
---@class LedgerBindingLook
---@field texture "leather"|"leatherGrey"|"bark"|"cloth"
---@field tile integer           -- UI units a repeat
---@field tint? number[]         -- the leather's vertex tint; nil for a texture drawn as it is
---@field band? number[]         -- the band's tone (desaturated, then tinted); nil for the band as it is
---@field gilt number[]          -- the crumbs and fleurons (LED-R125)
---@field silver boolean         -- a silver gilt: the brass plate turns silver (LED-R149)
---@field paperTint number[]     -- the page paper's vertex tint
---@field swatch string          -- the closed book in the Bindings atlas (the shop's preview)

--- The look of binding good `goodID` (LED-R112): Field Leather's for an ID that isn't a binding's.
---@param goodID string?
---@return LedgerBindingLook
function ns.BindingLook(goodID)
	local found = ns.BINDINGS[1]
	for _, binding in ipairs(ns.BINDINGS) do
		if ns.BindingID(binding) == goodID then
			found = binding
		end
	end
	local gilt = ns.HexTint(found.gilt)
	local tint, band, paper = found.tint, nil, { 1, 1, 1 }
	if tint then
		local top = math.max(tint[1], tint[2], tint[3])
		band = { tint[1] / top, tint[2] / top, tint[3] / top }
		paper = {
			1 - PAPER_SHARE + PAPER_SHARE * band[1],
			1 - PAPER_SHARE + PAPER_SHARE * band[2],
			1 - PAPER_SHARE + PAPER_SHARE * band[3],
		}
	elseif found.band then
		band = ns.HexTint(found.band)
	end
	return {
		texture = found.texture,
		tile = (found.texture == "bark" or found.texture == "cloth") and CLOTH_TILE or 128,
		tint = tint,
		band = band,
		gilt = gilt,
		silver = math.abs(gilt[1] - gilt[3]) < SILVER,
		paperTint = paper,
		swatch = found.swatch,
	}
end

--- The highest level in the celebrated set, over every climb (LED-R90), or 0 with none.
---@param celebrated LedgerCelebrated
---@return integer
function ns.HighestCelebratedLevel(celebrated)
	local highest = 0
	for _, level in pairs(celebrated.levels or {}) do
		highest = math.max(highest, level)
	end
	return highest
end

--- Whether the level binding of `level` is earned (LED-R111): the higher of the peak level (LED-R35) and the highest
--- celebrated level is at least `level`, so a Prestige or a rebuild never takes one away (LED-R92). Without a state
--- (the projection not built yet), the celebrated level alone.
---@param level integer
---@param state LedgerState?
---@param celebrated LedgerCelebrated
---@return boolean
function ns.LevelBindingEarned(level, state, celebrated)
	local peak = state and ns.PeakLevel(state) or 0
	return math.max(peak, ns.HighestCelebratedLevel(celebrated)) >= level
end

--- Whether the peak level going from `before` to `after` reaches a level binding's level (LED-R111): the moment the
--- Ledger calls `M:RefreshGoods()` after a live entry (SHOP-R31).
---@param before integer
---@param after integer
---@return boolean
function ns.LevelBindingCrossed(before, after)
	for _, binding in ipairs(ns.BINDINGS) do
		local level = binding.level
		if level and before < level and level <= after then
			return true
		end
	end
	return false
end

--- What the Ledger needs to make its goods.
---@class LedgerBindingHooks
---@field earned fun(level: integer): boolean       -- whether that level binding is earned now (LED-R111)
---@field preview fun(stage: Frame, look: LedgerBindingLook) -- draws the closed book on the shop's stage

--- The Ledger's slot (LED-R110).
---@return PagleSlot
function ns.BindingSlot()
	return { id = ns.BINDING_SLOT, label = ns.L.BINDING_SLOT_LABEL, category = "Fish Journal" }
end

--- A binding's name (LED-R110): its lore, `binding.<name>.name` (LED-R160), or its good's ID while the key has no
--- text (LED-R161).
---@param binding LedgerBinding
---@return string
function ns.BindingName(binding)
	return ns.Lore("binding." .. binding.name .. ".name") or ns.BindingID(binding)
end

--- The goods to register, in LED-R110's order: named from lore (ns.BindingName, and `binding.<name>.description`,
--- LED-R160), with no description while its key has no text.
---@param hooks LedgerBindingHooks
---@return PagleGood[]
function ns.BindingGoods(hooks)
	local L = ns.L
	local goods = {}
	for i, binding in ipairs(ns.BINDINGS) do
		local id = ns.BindingID(binding)
		local look = ns.BindingLook(id)
		local level = binding.level
		goods[i] = {
			id = id,
			slot = ns.BINDING_SLOT,
			name = ns.BindingName(binding),
			description = ns.Lore("binding." .. binding.name .. ".description"),
			icon = ns.BINDING_ICON,
			default = binding.default,
			tier = binding.tier,
			isEarned = level and function()
				return hooks.earned(level)
			end,
			earnedText = level and L.BINDING_EARNED:format(level),
			preview = function(stage)
				hooks.preview(stage, look)
			end,
		}
	end
	return goods
end
