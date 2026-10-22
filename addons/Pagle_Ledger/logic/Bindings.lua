if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Ledger's earned bindings (LED-R110, LED-R111, LED-R116; ADR 0015): its goods in Core's binding slot, and when a
-- level binding is earned (the expansion's earned bindings' rules are logic/EarnedGoods.lua's). Core owns the slot,
-- every binding for sale and every binding's look and art, the Ledger's earned ones' too; the Ledger says only when
-- its own are earned. Pure logic, everything passed in (CORE-R7); adapter/Bindings.lua registers them.

--- Core's binding slot (SHOP-R25), open to earned goods (SHOP-R23). Pagle's API doesn't name Core's slots, so the
--- Ledger names it, as it names the crest slot.
ns.BINDING_SLOT = "core.binding"

--- Every binding's icon, the shop's swatch for one put away (wallet-and-shop.md › UI): the ledger book the level-up
--- moment shows (LED-R97).
ns.BINDING_ICON = "Interface\\Icons\\INV_Misc_Book_09"

--- An earned binding of the Ledger's: its good's last ID part (`ledger.binding.<name>`, and its lore keys
--- `ledgergood.ledger.binding.<name>.*`, LED-R160), and what earns it: exactly one of a `level` (LED-R111) or an
--- `earn` rule (LED-R116).
---@class LedgerBinding
---@field name string
---@field level? integer -- earned at this peak or celebrated level (LED-R111)
---@field earn? LedgerEarnedRule -- earned by this rule (LED-R116, logic/EarnedGoods.lua)

--- LED-R110's earned bindings, in its order: the Ledger art kit's six level bindings, then the shop expansion kit's
--- five earned ones.
---@type LedgerBinding[]
ns.BINDINGS = {
	{ name = "level10", level = 10 }, -- Tanned Hide
	{ name = "level20", level = 20 }, -- Tidewater Blue
	{ name = "level30", level = 30 }, -- Reed Green
	{ name = "level40", level = 40 }, -- Oxblood
	{ name = "level50", level = 50 }, -- Storm Grey
	{ name = "level60", level = 60 }, -- Nat's Own
	{ name = "legend", earn = "legends" }, -- Three Gilt Fish
	{ name = "monster", earn = "monster" }, -- Monster Hide
	{ name = "abyssal", earn = "prestige10" }, -- Abyssal Black
	{ name = "keeper", earn = "ledger" }, -- Keeper's Gold
	{ name = "iridescent", earn = "varieties" }, -- Iridescent Scale
}

--- A binding's good ID (LED-R110).
---@param binding LedgerBinding
---@return string
function ns.BindingID(binding)
	return "ledger.binding." .. binding.name
end

--- The Ledger's binding of good `goodID`, or nil for any other good (Core's bindings among them).
---@param goodID string?
---@return LedgerBinding?
function ns.LedgerBinding(goodID)
	for _, binding in ipairs(ns.BINDINGS) do
		if ns.BindingID(binding) == goodID then
			return binding
		end
	end
	return nil
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
---@field earnedBy fun(goodID: string, rule: LedgerEarnedRule): boolean -- whether an expansion one is (LED-R116)

--- A binding's name (LED-R110): its lore, `ledgergood.<goodID>.name` (LED-R160), or its good's ID while the key has no
--- text (LED-R161).
---@param binding LedgerBinding
---@return string
function ns.BindingName(binding)
	local id = ns.BindingID(binding)
	return ns.Lore("ledgergood." .. id .. ".name") or id
end

--- A binding's `earnedText` (LED-R111, LED-R116): "Angler Level {L}" for a level binding, its rule's text for an
--- expansion one.
---@param binding LedgerBinding
---@return string
function ns.BindingEarnedText(binding)
	local L = ns.L
	if binding.level then
		return L.BINDING_EARNED:format(binding.level)
	end
	return L.EARNED_TEXT[binding.earn]
end

--- The goods to register in Core's binding slot (SHOP-R23), in LED-R110's order: named from lore (ns.BindingName, and
--- `ledgergood.<goodID>.description`, LED-R160), with no description while its key has no text. A level binding is
--- earned by its level (LED-R111), an expansion one by its rule (LED-R116), each saying how in its `earnedText`. No
--- preview: Core draws every binding, the Ledger's too, with its slot's (SHOP-R25).
---@param hooks LedgerBindingHooks
---@return PagleGood[]
function ns.BindingGoods(hooks)
	local goods = {}
	for i, binding in ipairs(ns.BINDINGS) do
		local id = ns.BindingID(binding)
		local level, earn = binding.level, binding.earn
		goods[i] = {
			id = id,
			slot = ns.BINDING_SLOT,
			name = ns.BindingName(binding),
			description = ns.Lore("ledgergood." .. id .. ".description"),
			icon = ns.BINDING_ICON,
			isEarned = level and function()
				return hooks.earned(level)
			end or function()
				return hooks.earnedBy(id, earn --[[@as LedgerEarnedRule]])
			end,
			earnedText = ns.BindingEarnedText(binding),
		}
	end
	return goods
end
