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
--- its kind (exactly one of `default`, `level` for an earned one, `tier` for one for sale), and its three tints as
--- the prototype's CSS writes them: the leather, the gilt (breadcrumbs, plate, rules) and the page paper.
---@class LedgerBinding
---@field name string
---@field default? true
---@field level? integer -- earned at this peak or celebrated level (LED-R111)
---@field tier? 1|2|3
---@field leather string "RRGGBB"
---@field gilt string
---@field paper string

--- LED-R110's bindings, in its order. Field Leather keeps the Journal's first look (#138's ns.JOURNAL_LOOK); the rest
--- take the leather and gilt of prototypes/curio-shop/'s swatches, with a page paper picked to sit with each.
---@type LedgerBinding[]
ns.BINDINGS = {
	{ name = "field", default = true, leather = "4e2c16", gilt = "e8c96a", paper = "ead6ac" },
	{ name = "level10", level = 10, leather = "7a4a26", gilt = "e0b870", paper = "eedcb4" }, -- Tanned Hide
	{ name = "level20", level = 20, leather = "1f3a5a", gilt = "c9d6e0", paper = "e6e0cc" }, -- Tidewater Blue
	{ name = "level30", level = 30, leather = "2e4a2a", gilt = "d6c88a", paper = "e6dcb2" }, -- Reed Green
	{ name = "level40", level = 40, leather = "5a1414", gilt = "e0b84a", paper = "ecd6ac" }, -- Oxblood
	{ name = "level50", level = 50, leather = "3a3e44", gilt = "d0d4da", paper = "e4dfd2" }, -- Storm Grey
	{ name = "level60", level = 60, leather = "2a1a0e", gilt = "ffd100", paper = "f0dcaa" }, -- Nat's Own
	{ name = "birch", tier = 1, leather = "d8d0bc", gilt = "3a3026", paper = "f2ead8" }, -- Birch Bark
	{ name = "buckram", tier = 2, leather = "2a6a62", gilt = "e8e0c0", paper = "e8e2c8" }, -- Sea-green Buckram
	{ name = "sharkskin", tier = 3, leather = "59636a", gilt = "f0f0f0", paper = "e6e2d8" }, -- Sharkskin
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

-- `from` moved `share` of the way to `to`, channel by channel.
---@param from number[]
---@param to number[]
---@param share number
---@return number[]
local function mix(from, to, share)
	return {
		from[1] + (to[1] - from[1]) * share,
		from[2] + (to[2] - from[2]) * share,
		from[3] + (to[3] - from[3]) * share,
	}
end

-- How far the gilt shows through in a rule on the leather (#138's Field Leather rule, #8a5a2a, is about this much of
-- its gilt), and in the brass plate's face (Field Leather's comes near #138's brass, #c19e45).
local RULE_SHARE, PLATE_SHARE = 0.3, 0.8

-- Below this luminance a plate's face takes words in the page paper's tint, above it in dark ink.
local LIGHT_PLATE = 0.45
local PLATE_INK = ns.HexTint("2a1a04")

--- What a binding draws (LED-R110): its three tints, and from them the rules on the leather, the brass plate's face
--- and the words on it.
---@class LedgerBindingLook
---@field leather number[]
---@field gilt number[]       -- the breadcrumbs (LED-R125)
---@field paper number[]
---@field rule number[]       -- the gilt rules and the crumbs' ❧, the gilt toned into the leather
---@field plate number[]      -- the brass plate's face (LED-R149)
---@field plateText number[]  -- its words

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
	local leather, gilt, paper = ns.HexTint(found.leather), ns.HexTint(found.gilt), ns.HexTint(found.paper)
	local plate = mix(leather, gilt, PLATE_SHARE)
	local luminance = 0.299 * plate[1] + 0.587 * plate[2] + 0.114 * plate[3]
	return {
		leather = leather,
		gilt = gilt,
		paper = paper,
		rule = mix(leather, gilt, RULE_SHARE),
		plate = plate,
		plateText = luminance < LIGHT_PLATE and paper or PLATE_INK,
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
