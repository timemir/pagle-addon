if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Curio Shop expansion's earned goods (LED-R116, LED-R117): the five earned bindings and the Ledger's four goods in
-- Core's open slots, each owned by a rule over the projection's state and the celebrated set together (LED-R90), and
-- kept once earned; and the second round's, by their counts (LED-R118, logic/EarnedCounts.lua). Pure logic, everything
-- passed in (CORE-R7); adapter/Bindings.lua registers them.

--- A rule an expansion good is earned by (LED-R116, LED-R117): `legend` its first Legend caught, `legends` every
--- Legend item caught (LED-R63), `monster` a sized Catch in the Monster band (LED-R80), `prestige<R>` Prestige rank R
--- or higher (LED-R34), `ledger` the `complete.ledger` title earned (LED-R75), `varieties` the `complete.varieties`
--- title earned (VAR-R22). The second round's goods are each earned by a rule of their own, named by the good's key: its
--- count at its mark (LED-R118, logic/EarnedCounts.lua).
---@alias LedgerEarnedRule "legend"|"legends"|"monster"|"prestige1"|"prestige5"|"prestige10"|"ledger"|"varieties"|string

--- What the rules read.
---@class LedgerEarnedView
---@field state? LedgerState            -- the projection's state; nil before it is built
---@field celebrated LedgerCelebrated   -- the celebrated set (LED-R90), as saved
---@field world LedgerWorld             -- the world index (LED-R10)
---@field sizeBands? integer           -- how many Size bands Core has (ns.SizeBandCount of Pagle.SIZE_BANDS, LOG-R67)

--- The celebrated set's earned goods (LED-R116): each expansion good's ID once a rule earned it, so it is never lost.
---@class LedgerCelebrated
---@field goods? { [string]: true }

--- One of the Ledger's goods in Core's open slots (LED-R117): Core draws and plays it, keyed by its ID; the Ledger
--- decides when it is earned.
---@class LedgerCoreSlotGood
---@field id string
---@field slot string    -- Core's slot: "core.toaststyle" or "core.soundset" (SHOP-R25)
---@field earn LedgerEarnedRule
---@field icon string

local ICONS = "Interface\\Icons\\"

--- LED-R117's four goods, in its order.
---@type LedgerCoreSlotGood[]
ns.LEDGER_CORE_SLOT_GOODS = {
	{ id = "ledger.toaststyle.legend", slot = "core.toaststyle", earn = "legend", icon = ICONS .. "INV_Misc_Note_01" },
	{
		id = "ledger.toaststyle.prestige",
		slot = "core.toaststyle",
		earn = "prestige5",
		icon = ICONS .. "INV_Scroll_03",
	},
	{
		id = "ledger.soundset.concertina",
		slot = "core.soundset",
		earn = "prestige1",
		icon = ICONS .. "INV_Misc_Drum_02",
	},
	{ id = "ledger.soundset.choir", slot = "core.soundset", earn = "legends", icon = ICONS .. "INV_Misc_Horn_01" },
}

--- How many Size bands Core has (LOG-R67), from `Pagle.SIZE_BANDS` as it hands them over: the last is the Monster
--- band (LED-R80). Counted by index, since a read-only copy (CORE-R18) has no length; nil without bands.
---@param bands { key: string, name: string }[]? Pagle.SIZE_BANDS
---@return integer?
function ns.SizeBandCount(bands)
	if not bands then
		return nil
	end
	local count = 0
	while bands[count + 1] ~= nil do
		count = count + 1
	end
	return count > 0 and count or nil
end

-- A state with nothing in it, for the rules before the projection has one.
local NO_STATE = { species = {}, items = {}, zones = {}, prestige = 0 }

-- Whether item `itemID` was caught: in the state's items or the celebrated set's (LED-R90).
---@param view LedgerEarnedView
---@param itemID integer
---@return boolean
local function caught(view, itemID)
	local state, celebrated = view.state, view.celebrated
	return (state and state.items[itemID] ~= nil) or (celebrated.items ~= nil and celebrated.items[itemID] == true)
end

-- The higher of the state's prestige rank and the highest celebrated (LED-R34, LED-R90).
---@param view LedgerEarnedView
---@return integer
local function prestigeRank(view)
	return math.max(view.state and view.state.prestige or 0, view.celebrated.prestige or 0)
end

---@param rank integer
---@return fun(view: LedgerEarnedView): boolean
local function prestigeOf(rank)
	return function(view)
		return prestigeRank(view) >= rank
	end
end

---@type table<LedgerEarnedRule, fun(view: LedgerEarnedView): boolean>
local RULES = {
	-- Any Legend item caught (LED-R63), as its title counts it (LED-R75).
	legend = function(view)
		local getItem = view.world.getItem
		for _, held in ipairs({ view.state and view.state.items or {}, view.celebrated.items or {} }) do
			for itemID in pairs(held) do
				if ns.ClassifyCatch(itemID, getItem(itemID)) == "legend" then
					return true
				end
			end
		end
		return false
	end,
	-- Every Legend item caught (LED-R63): every one of the Legends' world but the removed ones (LED-R11, LED-R12), and
	-- at least one.
	legends = function(view)
		local getItem = view.world.getItem
		local total = 0
		for _, itemID in ipairs(ns.CollectionWorlds(view.world, view.state or NO_STATE).legends) do
			local item = getItem(itemID)
			if not (item and item.removed) then
				if not caught(view, itemID) then
					return false
				end
				total = total + 1
			end
		end
		return total > 0
	end,
	-- A Species' or Legend item's record in the Monster band, the last of Core's (LED-R80): its longest Catch, so any
	-- Catch of it there.
	monster = function(view)
		local state, monsterBand = view.state, view.sizeBands
		if not (state and monsterBand) then
			return false
		end
		for _, entries in ipairs({ state.species, state.items }) do
			for _, entry in pairs(entries) do
				if entry.record and entry.record.band >= monsterBand then
					return true
				end
			end
		end
		return false
	end,
	prestige1 = prestigeOf(1),
	prestige5 = prestigeOf(5),
	prestige10 = prestigeOf(10),
	-- The `complete.ledger` title (LED-R75): celebrated, or Ledger completion at 100% now (LED-R70).
	ledger = function(view)
		local titles = view.celebrated.titles
		if titles and titles["title:complete.ledger"] then
			return true
		end
		return view.state ~= nil and ns.LedgerCompletion(view.world, view.state).percent == 100
	end,
	-- The `complete.varieties` title (VAR-R22): celebrated, or every Species with varieties complete now, at a total
	-- above 0 (VAR-R20).
	varieties = function(view)
		local titles = view.celebrated.titles
		if titles and titles["title:complete.varieties"] then
			return true
		end
		if not view.state then
			return false
		end
		local count = ns.LedgerCompletion(view.world, view.state).varieties
		return count.total > 0 and count.done >= count.total
	end,
}

-- The second round's (LED-R118): each good's count at its mark.
for _, good in ipairs(ns.COUNTED_GOODS) do
	RULES[good.earn] = function(view)
		return ns.EarnedCount(good, view) >= good.mark
	end
end

--- Whether rule `rule` holds now (LED-R116, LED-R117), over the state and the celebrated set together.
---@param rule LedgerEarnedRule
---@param view LedgerEarnedView
---@return boolean
function ns.EarnedRuleHolds(rule, view)
	return RULES[rule](view)
end

--- Whether expansion good `goodID`, earned by `rule`, is owned (LED-R116, LED-R117): the celebrated set has it, or the
--- rule holds now.
---@param goodID string
---@param rule LedgerEarnedRule
---@param view LedgerEarnedView
---@return boolean
function ns.EarnedGoodOwned(goodID, rule, view)
	local goods = view.celebrated.goods
	return (goods ~= nil and goods[goodID] == true) or RULES[rule](view)
end

--- Every expansion and second-round good earned by a rule (LED-R116–R118), as `{ id, earn }`: the earned bindings in
--- LED-R110's order, then LED-R117's goods, then LED-R118's, its nine bindings among them though they aren't
--- registered until ADR 0015 lands, so each is kept from the moment it is earned.
---@return { id: string, earn: LedgerEarnedRule }[]
function ns.EarnedGoods()
	local list = {}
	for _, binding in ipairs(ns.BINDINGS) do
		if binding.earn then
			list[#list + 1] = { id = ns.BindingID(binding), earn = binding.earn }
		end
	end
	for _, good in ipairs(ns.LEDGER_CORE_SLOT_GOODS) do
		list[#list + 1] = { id = good.id, earn = good.earn }
	end
	for _, good in ipairs(ns.COUNTED_GOODS) do
		list[#list + 1] = { id = good.id, earn = good.earn }
	end
	return list
end

--- Adds to the celebrated set (LED-R90) each good of ns.EarnedGoods whose rule now holds and that it doesn't have yet,
--- so a good once earned is never lost (LED-R116, LED-R118): after a live entry and in a done, before the Ledger calls
--- `M:RefreshGoods()` (SHOP-R31). True when it added one, a live entry's moment to refresh.
---@param celebrated LedgerCelebrated its `goods` made with the first good noted
---@param view LedgerEarnedView over the same set
---@return boolean
function ns.NoteEarnedGoods(celebrated, view)
	local noted = false
	for _, good in ipairs(ns.EarnedGoods()) do
		local goods = celebrated.goods
		if not (goods and goods[good.id]) and RULES[good.earn](view) then
			if type(goods) ~= "table" then
				goods = {}
				celebrated.goods = goods
			end
			goods[good.id] = true
			noted = true
		end
	end
	return noted
end

--- LED-R117's goods to register in Core's open slots (SHOP-R23, SHOP-R25), in its order: named and described by lore
--- (`ledgergood.<goodID>.name`, `.description`, LED-R160), by its ID while the name has no text (LED-R161), earned by
--- `earnedBy`, with no preview: Core draws and plays them.
---@param earnedBy fun(goodID: string, rule: LedgerEarnedRule): boolean
---@return PagleGood[]
function ns.CoreSlotGoods(earnedBy)
	local goods = {}
	for i, good in ipairs(ns.LEDGER_CORE_SLOT_GOODS) do
		local id, earn = good.id, good.earn
		goods[i] = {
			id = id,
			slot = good.slot,
			name = ns.Lore("ledgergood." .. id .. ".name") or id,
			description = ns.Lore("ledgergood." .. id .. ".description"),
			icon = good.icon,
			isEarned = function()
				return earnedBy(id, earn)
			end,
			earnedText = ns.L.EARNED_TEXT[earn],
		}
	end
	return goods
end
