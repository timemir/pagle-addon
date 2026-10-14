---@class PagleNS
local ns = select(2, ...)

-- The Curio Shop as data (wallet-and-shop.md › UI, SHOP-R35, SHOP-R40): the purse, the list of goods and the stage
-- for the selected good, read from the goods registry, its cache and the wallet when the window draws. Pure logic,
-- everything passed in (CORE-R7); adapter/Shop.lua draws it, and logic/Wiring.lua's ns.WireShop opens it.

--- What the shop reads, as it is now.
---@class PagleShopSources
---@field goods PagleGoods                 -- Core's goods registry (ns.goods)
---@field cache table<string, table>       -- PagleDB.global.goods, every good ever registered (SHOP-R26)
---@field modules PagleModule[]            -- the Modules On, by def.order
---@field balance Balance                  -- Pagle.GetBalance()
---@field updating boolean                 -- a projection, Core's or a Module's, is updating (SHOP-R13)
---@field format? fun(value: number): string -- writes a number of Coins (BreakUpLargeNumbers); tostring by default

---@class PagleShopModel
---@field private sources PagleShopSources
---@field private on table<string, true>               -- Core and each Module On, by def.name
---@field private slots table<string, PagleRegisteredSlot> -- the live slots, by ID
---@field private slotList PagleRegisteredSlot[]        -- the live slots, Core's first, then by Module order
---@field private format fun(value: number): string
local Model = {}
Model.__index = Model

--- The shop's model over `sources`, read once: build a new one whenever the window redraws.
---@param sources PagleShopSources
---@return PagleShopModel
function ns.NewShopModel(sources)
	local on = { Core = true }
	for _, module in ipairs(sources.modules) do
		on[module.def.name] = true
	end
	local slotList = sources.goods:Slots()
	local slots = {}
	for _, slot in ipairs(slotList) do
		slots[slot.id] = slot
	end
	return setmetatable({
		sources = sources,
		on = on,
		slots = slots,
		slotList = slotList,
		format = sources.format or tostring,
	}, Model)
end

-- Each roster Module's place in CORE-R1's order, for the purse and Put away.
---@param name string
---@return integer
local function rosterIndex(name)
	for i, roster in ipairs(ns.MODULE_ROSTER) do
		if roster == name then
			return i
		end
	end
	return #ns.MODULE_ROSTER + 1
end

-- Sorts def.names in roster order, any other by name.
---@param a string
---@param b string
---@return boolean
local function byRoster(a, b)
	local indexA, indexB = rosterIndex(a), rosterIndex(b)
	if indexA ~= indexB then
		return indexA < indexB
	end
	return a < b
end

--- Whose good or Coins these are, as the shop names them: a Module's title (CORE-R41's names), or "Pagle" for Core.
---@param module string def.name, or "Core"
---@return string
local function ownerName(module)
	if module == "Core" then
		return ns.L.SHOP_CORE
	end
	return ns.L.MODULE_NAMES[module] or module
end

--- One Module's part of the purse's bar.
---@class PagleShopSegment
---@field module string     -- def.name
---@field share number      -- its part of every Coin earned, 0 to 1
---@field off boolean       -- its Module isn't On: faded, its legend struck through
---@field legend string     -- "Ledger 1,500"
---@field tooltip string[]  -- its name, its lifetime total, and while off what that means

--- The purse (wallet-and-shop.md › UI): the balance, and income by source.
---@class PagleShopPurse
---@field label string               -- "Pagle Coins"
---@field balance string             -- the balance, 0 while held (SHOP-R12)
---@field held boolean               -- SHOP-R12's held line shows: earned is below spent
---@field segments PagleShopSegment[] -- one per Module that has reported Coins, in roster order
---@field payNone string             -- "Stats and QoL pay none"

--- The purse: the balance, then a segment per Module that has reported Coins (SHOP-R3), with its lifetime total. A
--- Module that isn't On keeps its segment, faded, and its total counts. There's no "Spent" anywhere.
---@return PagleShopPurse
function Model:Purse()
	local L = ns.L
	local balance = self.sources.balance
	local names, sum = {}, 0
	for name, total in pairs(balance.earned) do
		names[#names + 1] = name
		sum = sum + total
	end
	table.sort(names, byRoster)
	local segments = {}
	for i, name in ipairs(names) do
		local total = balance.earned[name]
		local title = ownerName(name)
		local off = not self.on[name]
		local tooltip = { title, L.SHOP_ALL_TIME:format(self.format(total)) }
		if off then
			tooltip[3] = L.SHOP_OFF_NOTE
		end
		segments[i] = {
			module = name,
			share = sum > 0 and total / sum or 0,
			off = off,
			legend = L.SHOP_LEGEND:format(title, self.format(total)),
			tooltip = tooltip,
		}
	end
	return {
		label = L.SHOP_COINS,
		balance = self.format(balance.balance),
		held = balance.held,
		segments = segments,
		payNone = L.SHOP_PAY_NONE,
	}
end

--- What the shop knows of one good it can show.
---@class PagleShopEntry
---@field id string
---@field name string
---@field icon? integer|string
---@field description? string
---@field slotLabel string
---@field category string
---@field module string             -- def.name, or "Core"
---@field preview? fun(stage: Frame) -- nil for a good put away: its Module isn't loaded
---@field earned boolean            -- an earned good (SHOP-R22), whether or not it is owned yet
---@field earnedText? string
---@field default boolean           -- its slot's default (SHOP-R22, SHOP-R23)
---@field price? integer            -- a good for sale's price (SHOP-R22)
---@field state PagleShopState

--- A good's state in the shop (wallet-and-shop.md › UI: States on a row and the stage).
---@alias PagleShopState
---| "forSale"  # for sale, not owned, and the balance covers it
---| "short"    # for sale, not owned, and the balance doesn't cover it
---| "owned"    # owned, not in use
---| "equipped" # owned and in use
---| "unearned" # earned, not yet
---| "putAway"  # owned, of a Module that isn't On (SHOP-R35)

-- The states that count as owned.
local OWNED = { owned = true, equipped = true, putAway = true }

-- The states each filter keeps (wallet-and-shop.md › UI).
local FILTERS = {
	owned = OWNED,
	notOwned = { forSale = true, short = true, unearned = true },
	canAfford = { forSale = true },
}

--- The filters, in the order the list shows them.
ns.SHOP_FILTERS = { "all", "owned", "notOwned", "canAfford" }

--- A good the shop can show, or nil: a good of a live slot (Core's or a Module On's), or an owned good of a Module
--- that isn't On, from the cache (SHOP-R35). A default of a Module that isn't On is neither (SHOP-R35).
---@param goodID any
---@return PagleShopEntry?
function Model:Entry(goodID)
	if type(goodID) ~= "string" then
		return nil
	end
	local goods = self.sources.goods
	local good = goods:Good(goodID)
	local slot = good and self.slots[good.slot]
	if good and slot then
		local price = good.tier and ns.TIER_PRICES[good.tier]
		local state
		if goods:IsOwned(goodID) then
			state = goods:GetEquipped(slot.id) == goodID and "equipped" or "owned"
		elseif good.isEarned then
			state = "unearned"
		else
			state = self.sources.balance.balance >= price and "forSale" or "short"
		end
		return {
			id = goodID,
			name = good.name,
			icon = good.icon,
			description = good.description,
			slotLabel = slot.label,
			category = slot.category,
			module = slot.module,
			preview = good.preview,
			earned = good.isEarned ~= nil,
			earnedText = good.earnedText,
			default = goods:DefaultOf(slot.id) == goodID,
			price = price,
			state = state,
		}
	end
	local cached = self.sources.cache[goodID]
	if type(cached) ~= "table" or self.on[cached.module] or cached.default or not goods:IsOwned(goodID) then
		return nil
	end
	return {
		id = goodID,
		name = cached.name,
		icon = cached.icon,
		description = cached.description,
		slotLabel = cached.slotLabel,
		category = cached.category,
		module = cached.module,
		earned = false,
		default = false,
		state = "putAway",
	}
end

--- A good on the list (wallet-and-shop.md › UI): its swatch, name and state.
---@class PagleShopRow
---@field id string
---@field name string
---@field icon? integer|string
---@field state PagleShopState
---@field price? string   -- a good for sale's price, with the coin
---@field short? true     -- the balance doesn't cover the price: it shows in red
---@field tag? string     -- otherwise: "In use", "default", "Owned", its earnedText, or "Hunts is off"

-- The row for `entry`.
---@private
---@param entry PagleShopEntry
---@return PagleShopRow
function Model:RowOf(entry)
	local L = ns.L
	local row = { id = entry.id, name = entry.name, icon = entry.icon, state = entry.state }
	local state = entry.state
	if state == "forSale" or state == "short" then
		row.price = L.SHOP_PRICE:format(self.format(entry.price))
		row.short = state == "short" or nil
	elseif state == "equipped" then
		row.tag = L.SHOP_IN_USE
	elseif state == "owned" then
		row.tag = entry.default and L.SHOP_DEFAULT or L.SHOP_OWNED
	elseif state == "unearned" then
		row.tag = entry.earnedText or L.SHOP_REWARD:format(ownerName(entry.module))
	else
		row.tag = L.SHOP_MODULE_OFF:format(ownerName(entry.module))
	end
	return row
end

--- What narrows the list (wallet-and-shop.md › UI). Each is optional.
---@class PagleShopQuery
---@field search? string      -- matches names, ignoring case
---@field filter? "all"|"owned"|"notOwned"|"canAfford"
---@field category? string    -- a chip's category; nil for every one

-- Whether `entry` passes `query`.
---@param entry PagleShopEntry
---@param query PagleShopQuery
---@return boolean
local function matches(entry, query)
	local search = query.search and query.search:lower() or ""
	if search ~= "" and not entry.name:lower():find(search, 1, true) then
		return false
	end
	local states = FILTERS[query.filter]
	if states and not states[entry.state] then
		return false
	end
	return query.category == nil or entry.category == query.category
end

--- A group on the list: a slot's goods with its owned count, or the Put away group.
---@class PagleShopGroup
---@field label string          -- the slot's label, or "Put away: Module off"
---@field count? string         -- a slot's owned count, "2/3", over all its goods
---@field putAway? true         -- the Put away group: greyed
---@field note? string          -- the Put away group's "Yours to keep"
---@field rows PagleShopRow[]

--- The list (wallet-and-shop.md › UI, SHOP-R35): the goods `query` keeps, grouped by live slot (Core's first, then
--- by Module order), each with its owned count; then the owned goods of Modules that aren't On, from the cache, as
--- the last group, "Put away: Module off". A group with no row left isn't listed.
---@param query PagleShopQuery
---@return PagleShopGroup[]
function Model:List(query)
	local L = ns.L
	local goods = self.sources.goods
	local groups = {}
	for _, slot in ipairs(self.slotList) do
		local rows, owned, slotGoods = {}, 0, goods:GoodsOf(slot.id)
		for _, good in ipairs(slotGoods) do
			local entry = assert(self:Entry(good.id))
			if OWNED[entry.state] then
				owned = owned + 1
			end
			if matches(entry, query) then
				rows[#rows + 1] = self:RowOf(entry)
			end
		end
		if #rows > 0 then
			groups[#groups + 1] = {
				label = slot.label,
				count = L.SHOP_OWNED_COUNT:format(owned, #slotGoods),
				rows = rows,
			}
		end
	end
	local putAway = {}
	for goodID in pairs(self.sources.cache) do
		local entry = self:Entry(goodID)
		if entry and entry.state == "putAway" and matches(entry, query) then
			putAway[#putAway + 1] = entry
		end
	end
	table.sort(putAway, function(a, b)
		if a.module ~= b.module then
			return byRoster(a.module, b.module)
		end
		return a.id < b.id
	end)
	if #putAway > 0 then
		local rows = {}
		for i, entry in ipairs(putAway) do
			rows[i] = self:RowOf(entry)
		end
		groups[#groups + 1] = { label = L.SHOP_PUT_AWAY, note = L.SHOP_KEEP, putAway = true, rows = rows }
	end
	return groups
end

--- The good `goodID` names, if the shop shows it (SHOP-R40): a good of a live slot, or an owned good of a Module
--- that isn't On, under Put away. Nil for any other: an unknown ID, or a default or good for sale of a Module off.
---@param goodID any
---@return string?
function Model:Select(goodID)
	return self:Entry(goodID) and goodID or nil
end

--- The selected good on the stage (wallet-and-shop.md › UI): its look, name, slot and owner, description, and what
--- its state shows. Buy is shown for a good for sale, enabled per SHOP-R13 (canBuy).
---@class PagleShopStage
---@field id string
---@field name string
---@field icon? integer|string     -- the swatch: a good put away shows its cached icon
---@field preview? fun(stage: Frame) -- draws the look (PagleGood.preview); nil for a good put away
---@field slotLine string           -- "Toast style · Pagle": the slot's label and its owner
---@field description? string
---@field state PagleShopState
---@field price? string             -- a good for sale's price, with the coin
---@field short? true               -- the balance doesn't cover it: the price shows in red
---@field buy? string               -- "Buy for 400" for a good for sale not owned
---@field canBuy? true              -- Buy is enabled (SHOP-R13): the balance covers it and no projection is updating
---@field needed? string            -- "250 more needed" when the balance doesn't cover it
---@field use? true                 -- Use shows: owned, not in use, its Module On
---@field greyed? true              -- put away
---@field tags string[]             -- "Owned", "In use", "default", "Hunts is off"
---@field notes string[]            -- an earned good's earnedText and "A Ledger reward, not for sale"; "Yours to keep"

--- The stage for `goodID`, or nil when the shop doesn't show that good (Select).
---@param goodID any
---@return PagleShopStage?
function Model:Stage(goodID)
	local entry = self:Entry(goodID)
	if not entry then
		return nil
	end
	local L = ns.L
	local state = entry.state
	local owner = ownerName(entry.module)
	---@type PagleShopStage
	local stage = {
		id = entry.id,
		name = entry.name,
		icon = entry.icon,
		preview = entry.preview,
		slotLine = L.SHOP_SLOT_LINE:format(entry.slotLabel, owner),
		description = entry.description,
		state = state,
		tags = {},
		notes = {},
	}
	if state == "forSale" or state == "short" then
		local price = assert(entry.price)
		stage.price = L.SHOP_PRICE:format(self.format(price))
		stage.buy = L.SHOP_BUY:format(self.format(price))
		stage.canBuy = self:CanBuy(entry) or nil
		if state == "short" then
			stage.short = true
			stage.needed = L.SHOP_MORE_NEEDED:format(self.format(price - self.sources.balance.balance))
		end
	elseif state == "equipped" then
		stage.tags[1] = L.SHOP_IN_USE
		if entry.default then
			stage.tags[2] = L.SHOP_DEFAULT
		end
	elseif state == "owned" then
		stage.tags[1] = entry.default and L.SHOP_DEFAULT or L.SHOP_OWNED
		stage.use = true
	elseif state == "putAway" then
		stage.greyed = true
		stage.tags[1] = L.SHOP_MODULE_OFF:format(owner)
		stage.notes[1] = L.SHOP_KEEP
	end
	if entry.earned then
		if entry.earnedText then
			stage.notes[#stage.notes + 1] = entry.earnedText
		end
		stage.notes[#stage.notes + 1] = L.SHOP_REWARD:format(owner)
	end
	return stage
end

-- Whether `entry` may be bought now (SHOP-R13): for sale (a good of a live slot, so its Module is enabled), not owned,
-- the balance covering its price (the "forSale" state), and no projection updating.
---@private
---@param entry PagleShopEntry
---@return boolean
function Model:CanBuy(entry)
	return entry.state == "forSale" and not self.sources.updating
end

--- What Buy asks the Angler to confirm, and what the purchase entry records (SHOP-R10, wallet-and-shop.md › UI: Buy).
---@class PagleShopPurchase
---@field id string
---@field slot string        -- the good's slot, for "Use it now"
---@field name string
---@field icon? integer|string -- the swatch
---@field price integer      -- the price now, which the purchase entry records (SHOP-R10)
---@field priceText string   -- the price, with the coin
---@field leftAfter string   -- "Pagle Coins left after: 250. Looks are yours for good."

--- The purchase of `goodID` as it would be now, or nil unless Buy is enabled for it (SHOP-R13): a good for sale of a
--- live slot, not owned, that the balance covers, with no projection updating.
---@param goodID any
---@return PagleShopPurchase?
function Model:Purchase(goodID)
	local entry = self:Entry(goodID)
	if not entry or not self:CanBuy(entry) then
		return nil
	end
	local price = assert(entry.price)
	local L = ns.L
	return {
		id = entry.id,
		slot = assert(self.sources.goods:Good(entry.id)).slot,
		name = entry.name,
		icon = entry.icon,
		price = price,
		priceText = L.SHOP_PRICE:format(self.format(price)),
		leftAfter = L.SHOP_LEFT_AFTER:format(self.format(self.sources.balance.balance - price)),
	}
end

--- A category chip.
---@class PagleShopChip
---@field category string
---@field label string

--- The category chips (wallet-and-shop.md › UI): Announcements, Bookplate, Fish Journal, Hunts and Trackers, each
--- only if a live slot uses it.
---@return PagleShopChip[]
function Model:Chips()
	local used = {}
	for _, slot in ipairs(self.slotList) do
		used[slot.category] = true
	end
	local chips = {}
	for _, category in ipairs(ns.SLOT_CATEGORY_ORDER) do
		if used[category] then
			chips[#chips + 1] = { category = category, label = ns.L.SHOP_CATEGORIES[category] }
		end
	end
	return chips
end
