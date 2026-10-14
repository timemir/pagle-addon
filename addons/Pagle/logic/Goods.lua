---@class PagleNS
local ns = select(2, ...)

-- The goods registry (ADR 0009, wallet-and-shop.md › Goods, Owning and equipping): the slots and goods Core and the
-- Modules register, their cache in PagleDB.global.goods, what is owned and what is equipped. Pure logic, everything
-- passed in (CORE-R7); logic/Wiring.lua builds Core's one registry, and adapter/Goods.lua publishes it.

--- A slot a Module or Core registers (wallet-and-shop.md › Contracts).
---@class PagleSlot
---@field id string              -- "core.toaststyle", "hunts.notebookcover", "stats.trackerframe"
---@field label string           -- "Toast style"
---@field category "Announcements"|"Bookplate"|"Fish Journal"|"Hunts"|"Trackers"

--- A good a Module or Core registers (wallet-and-shop.md › Contracts): exactly one of default, for sale (tier) or
--- earned (isEarned).
---@class PagleGood
---@field id string
---@field slot string
---@field name string
---@field description? string
---@field icon? integer|string
---@field default? boolean        -- SHOP-R22
---@field tier? 1|2|3             -- for sale
---@field isEarned? fun(): boolean -- earned
---@field earnedText? string      -- earned: "Angler Level 30"
---@field preview? fun(stage: Frame)   -- draws the look on the shop's preview stage

--- A registered slot, with who registered it.
---@class PagleRegisteredSlot: PagleSlot
---@field module string           -- def.name, or "Core"
---@field goods PagleRegisteredGood[] -- its goods, in registration order
---@field package seq integer       -- registration order among all slots

--- A registered good: a copy of what was registered, with who registered it.
---@class PagleRegisteredGood: PagleGood
---@field module string           -- def.name, or "Core"

--- Fires whenever `Pagle.GetEquipped(slot)`'s result changes, whatever the reason (SHOP-R33): a SetEquipped, a
--- Module enabled or disabled, an earned good lost or regained, a purchase. Never before ModulesChanged.
---@alias PagleAppearanceChangedHandler fun(event: "AppearanceChanged", slot: string, goodID: string)

--- What the registry needs from where it runs. Every function is called when needed, never stored.
---@class PagleGoodsOptions
---@field db fun(): { global: table, profile: table } -- PagleDB: global.goods is the cache, profile.appearance the picks
---@field modules fun(): PagleModule[]   -- the Modules On (registered), by def.order
---@field fire fun(event: "AppearanceChanged", slot: string, goodID: string) -- fires AppearanceChanged
---@field call fun(fn: function, ...: any): ... -- calls a Module's isEarned; an error is reported, not raised
---@field report fun(message: string)    -- reports a mistake and carries on (geterrorhandler())

---@class PagleGoods
---@field private options PagleGoodsOptions
---@field private slots table<string, PagleRegisteredSlot>  -- registered this session, by ID
---@field private goods table<string, PagleRegisteredGood>  -- registered this session, by ID
---@field private purchased table<string, true>
---@field private registered integer  -- slots registered so far, for their order
---@field private shown table<string, string>? -- each slot's look as last noted; nil before Start
local Goods = {}
Goods.__index = Goods

--- An empty registry: nothing registered or purchased.
---@param options PagleGoodsOptions
---@return PagleGoods
function ns.NewGoods(options)
	return setmetatable({ options = options, slots = {}, goods = {}, purchased = {}, registered = 0 }, Goods)
end

---@private
---@return table<string, table>
function Goods:Cache()
	return self.options.db().global.goods
end

-- Why `id` can't be an ID of `module`'s, or nil if it can (SHOP-R21): `<def.name lowercased>.<name>`, matching
-- [%w_.]+. `call` names the registering call in the message.
---@param call string
---@param module string
---@param id any
---@return string?
local function idProblem(call, module, id)
	if type(id) ~= "string" or not id:match("^[%w_.]+$") then
		return ("M:%s: the id must be a string of letters, digits, _ and ., got %s"):format(call, tostring(id))
	end
	local prefix = module:lower() .. "."
	if id:sub(1, #prefix) ~= prefix or #id == #prefix then
		return ("M:%s: %s doesn't start with %s"):format(call, id, prefix)
	end
	return nil
end

-- Why a slot can't register for `module`, or nil if it can (SHOP-R23).
---@private
---@param module string
---@param slot any
---@return string?
function Goods:SlotProblem(module, slot)
	if type(slot) ~= "table" then
		return "M:RegisterSlot takes a slot table, got " .. type(slot)
	end
	local problem = idProblem("RegisterSlot", module, slot.id)
	if problem then
		return problem
	elseif self.slots[slot.id] then
		return ("M:RegisterSlot: %s is already registered"):format(slot.id)
	elseif type(slot.label) ~= "string" or slot.label == "" then
		return ("M:RegisterSlot: %s has no label"):format(slot.id)
	elseif not ns.SLOT_CATEGORIES[slot.category] then
		return ("M:RegisterSlot: %s's category must be one of Announcements, Bookplate, Fish Journal, Hunts, Trackers; got %s"):format(
			slot.id,
			tostring(slot.category)
		)
	end
	return nil
end

--- The slot categories (wallet-and-shop.md › Contracts), in the order the shop's chips and Look and Feel list them.
ns.SLOT_CATEGORY_ORDER = { "Announcements", "Bookplate", "Fish Journal", "Hunts", "Trackers" }

--- Each slot category, as a set.
---@type table<string, true>
ns.SLOT_CATEGORIES = {}
for _, category in ipairs(ns.SLOT_CATEGORY_ORDER) do
	ns.SLOT_CATEGORIES[category] = true
end

--- The price of each tier of goods for sale, in Pagle Coins (SHOP-R22, Tunables).
ns.TIER_PRICES = { 150, 400, 900 }

--- Registers a slot for `module` (SHOP-R21). Returns why it can't (SHOP-R23), registering nothing, or nil.
---@param module string def.name, or "Core"
---@param slot PagleSlot
---@return string? problem
function Goods:RegisterSlot(module, slot)
	local problem = self:SlotProblem(module, slot)
	if problem then
		return problem
	end
	self.registered = self.registered + 1
	self.slots[slot.id] = {
		id = slot.id,
		label = slot.label,
		category = slot.category,
		module = module,
		goods = {},
		seq = self.registered,
	}
	self:Settle()
	return nil
end

-- Why a good can't register for `module`, or nil if it can (SHOP-R22, SHOP-R23).
---@private
---@param module string
---@param good any
---@return string?
function Goods:GoodProblem(module, good)
	if type(good) ~= "table" then
		return "M:RegisterGood takes a good table, got " .. type(good)
	end
	local id = good.id
	local problem = idProblem("RegisterGood", module, id)
	if problem then
		return problem
	elseif self.goods[id] then
		return ("M:RegisterGood: %s is already registered"):format(id)
	end
	local slot = self.slots[good.slot]
	if not slot then
		return ("M:RegisterGood: %s's slot %s isn't registered"):format(id, tostring(good.slot))
	elseif slot.module ~= module then
		return ("M:RegisterGood: %s's slot %s is %s's"):format(id, slot.id, slot.module)
	elseif type(good.name) ~= "string" or good.name == "" then
		return ("M:RegisterGood: %s has no name"):format(id)
	end
	local kinds = (good.default and 1 or 0) + (good.tier ~= nil and 1 or 0) + (good.isEarned ~= nil and 1 or 0)
	if kinds ~= 1 then
		return ("M:RegisterGood: %s must be exactly one of default, for sale (tier) or earned (isEarned)"):format(id)
	elseif good.tier ~= nil and not ns.TIER_PRICES[good.tier] then
		return ("M:RegisterGood: %s's tier must be 1, 2 or 3, got %s"):format(id, tostring(good.tier))
	elseif good.isEarned ~= nil and type(good.isEarned) ~= "function" then
		return ("M:RegisterGood: %s's isEarned must be a function"):format(id)
	elseif good.default then
		for _, other in ipairs(slot.goods) do
			if other.default then
				return ("M:RegisterGood: %s already has a default, %s"):format(slot.id, other.id)
			end
		end
	end
	for _, field in ipairs({ "description", "earnedText" }) do
		if good[field] ~= nil and type(good[field]) ~= "string" then
			return ("M:RegisterGood: %s's %s must be a string"):format(id, field)
		end
	end
	if good.icon ~= nil and type(good.icon) ~= "string" and type(good.icon) ~= "number" then
		return ("M:RegisterGood: %s's icon must be a texture path or file ID"):format(id)
	elseif good.preview ~= nil and type(good.preview) ~= "function" then
		return ("M:RegisterGood: %s's preview must be a function"):format(id)
	end
	return nil
end

--- Registers a good for `module` (SHOP-R21, SHOP-R22) and caches it (SHOP-R26), calling its isEarned() if it is
--- earned (SHOP-R31). Returns why it can't (SHOP-R23), registering nothing, or nil.
---@param module string def.name, or "Core"
---@param good PagleGood
---@return string? problem
function Goods:RegisterGood(module, good)
	local problem = self:GoodProblem(module, good)
	if problem then
		return problem
	end
	local slot = self.slots[good.slot]
	local registered = { module = module }
	for key, value in pairs(good) do
		registered[key] = value
	end
	self.goods[good.id] = registered
	slot.goods[#slot.goods + 1] = registered
	local cache = self:Cache()
	local before = cache[good.id]
	cache[good.id] = {
		name = good.name,
		slot = slot.id,
		slotLabel = slot.label,
		category = slot.category,
		module = module,
		icon = good.icon,
		default = good.default or nil,
		tier = good.tier,
		description = good.description,
		earned = before and before.earned,
	}
	self:CallIsEarned(registered)
	self:Settle()
	return nil
end

-- Calls an earned good's isEarned() and caches its result (SHOP-R26, SHOP-R31). When it raises, the cache keeps
-- what it had (false for a good never cached), so a broken check takes no look away.
---@private
---@param good PagleRegisteredGood
function Goods:CallIsEarned(good)
	if not good.isEarned then
		return
	end
	local result
	self.options.call(function()
		result = good.isEarned() == true
	end)
	local cached = self:Cache()[good.id]
	if result ~= nil then
		cached.earned = result
	elseif cached.earned == nil then
		cached.earned = false
	end
end

--- `M:RefreshGoods()` for `module` (SHOP-R31): calls each of its earned goods' isEarned() and caches the results.
---@param module string def.name, or "Core"
function Goods:Refresh(module)
	for _, good in pairs(self.goods) do
		if good.module == module then
			self:CallIsEarned(good)
		end
	end
	self:Settle()
end

--- The purchased goods, from the wallet projection (SHOP-R11): `{ [goodID] = true }`, kept as handed over. Empty
--- until the projection hands one over.
---@param purchased table<string, true>
function Goods:SetPurchased(purchased)
	self.purchased = purchased
	self:Settle()
end

-- The order of each Module On, by def.name: Core is 0, before every Module (wallet-and-shop.md › UI: Core's slots
-- first, then by Module order).
---@private
---@return table<string, integer>
function Goods:OrderOn()
	local order = { Core = 0 }
	for i, module in ipairs(self.options.modules()) do
		order[module.def.name] = i
	end
	return order
end

--- The slots registered this session by Core and the Modules On: Core's first, then by Module order, each Module's
--- in registration order. Core's own; nothing in them may be changed.
---@return PagleRegisteredSlot[]
function Goods:Slots()
	local order = self:OrderOn()
	local list = {}
	for _, slot in pairs(self.slots) do
		if order[slot.module] then
			list[#list + 1] = slot
		end
	end
	table.sort(list, function(a, b)
		local orderA, orderB = order[a.module], order[b.module]
		if orderA ~= orderB then
			return orderA < orderB
		end
		return a.seq < b.seq
	end)
	return list
end

--- The goods registered this session in a slot, in registration order (empty for a slot not registered). Core's
--- own; nothing in them may be changed.
---@param slotID string
---@return PagleRegisteredGood[]
function Goods:GoodsOf(slotID)
	local slot = self.slots[slotID]
	return slot and slot.goods or {}
end

--- A good registered this session, as registered (with its preview, isEarned and earnedText), or nil. Core's own;
--- nothing in it may be changed.
---@param goodID string
---@return PagleRegisteredGood?
function Goods:Good(goodID)
	return self.goods[goodID]
end

--- Whether a slot is registered this session by Core or a Module On.
---@param slotID any
---@return boolean
function Goods:IsLive(slotID)
	local slot = self.slots[slotID]
	return slot ~= nil and self:OrderOn()[slot.module] ~= nil
end

--- The default of a slot (SHOP-R22): for a live slot, its registered default good, or else its first registered good
--- (SHOP-R23); for a slot whose Module is off, the default good cached for it (SHOP-R90). Nil for a slot with none.
---@param slotID string
---@return string?
function Goods:DefaultOf(slotID)
	if self:IsLive(slotID) then
		local goods = self.slots[slotID].goods
		for _, good in ipairs(goods) do
			if good.default then
				return good.id
			end
		end
		return goods[1] and goods[1].id
	end
	local found
	for goodID, cached in pairs(self:Cache()) do
		if cached.slot == slotID and cached.default and (not found or goodID < found) then
			found = goodID
		end
	end
	return found
end

--- Whether a good is owned (SHOP-R30): a registered slot's default, a purchased good, or an earned good whose cached
--- isEarned() result is true. It reads the cache only, never isEarned().
---@param goodID any
---@return boolean
function Goods:IsOwned(goodID)
	if type(goodID) ~= "string" then
		return false
	end
	if self.purchased[goodID] then
		return true
	end
	local cached = self:Cache()[goodID]
	if cached and cached.earned == true then
		return true
	end
	local good = self.goods[goodID]
	return good ~= nil and self:IsLive(good.slot) and self:DefaultOf(good.slot) == goodID
end

--- The good equipped in a slot (SHOP-R32): the stored pick while it is owned and registered by a Module On, else the
--- slot's default. Reading never clears the pick, so it comes back with its Module (SHOP-R90). Nil for a slot with
--- no goods.
---@param slotID any
---@return string?
function Goods:GetEquipped(slotID)
	if type(slotID) ~= "string" then
		return nil
	end
	local stored = self.options.db().profile.appearance[slotID]
	local good = self.goods[stored]
	if good and good.slot == slotID and self:IsLive(slotID) and self:IsOwned(stored) then
		return stored
	end
	return self:DefaultOf(slotID)
end

--- Stores `goodID` as the slot's pick (SHOP-R32) if it is an owned good of that slot, registered or cached. Returns
--- whether it did; a refused pick changes nothing. AppearanceChanged follows if the look changed (SHOP-R33).
---@param slotID any
---@param goodID any
---@return boolean
function Goods:SetEquipped(slotID, goodID)
	if type(slotID) ~= "string" or type(goodID) ~= "string" then
		return false
	end
	local good = self.goods[goodID] or self:Cache()[goodID]
	if not good or good.slot ~= slotID or not self:IsOwned(goodID) then
		return false
	end
	self.options.db().profile.appearance[slotID] = goodID
	self:Settle()
	return true
end

--- What `Pagle.GetGood` returns: a good's look as cached (SHOP-R26), registered this session or not.
---@class PagleGoodInfo
---@field name string
---@field slot string
---@field icon? integer|string
---@field module string           -- def.name, or "Core"
---@field description? string

--- A good's name, slot, icon, Module and description, from the cache, as a fresh copy; nil for a good never cached.
---@param goodID any
---@return PagleGoodInfo?
function Goods:GetGood(goodID)
	local cached = type(goodID) == "string" and self:Cache()[goodID]
	if not cached then
		return nil
	end
	return {
		name = cached.name,
		slot = cached.slot,
		icon = cached.icon,
		module = cached.module,
		description = cached.description,
	}
end

-- Every slot anything knows of: registered, cached, picked or shown, sorted so events fire in one order.
---@private
---@return string[]
function Goods:KnownSlots()
	local seen = {}
	for slotID in pairs(self.slots) do
		seen[slotID] = true
	end
	for _, cached in pairs(self:Cache()) do
		seen[cached.slot] = true
	end
	for slotID in pairs(self.options.db().profile.appearance) do
		seen[slotID] = true
	end
	for slotID in pairs(self.shown or {}) do
		seen[slotID] = true
	end
	local list = {}
	for slotID in pairs(seen) do
		list[#list + 1] = slotID
	end
	table.sort(list)
	return list
end

--- ModulesChanged (CORE-R19): every enabled Module has registered. Reports each live slot with no default good
--- through `report` (its first good stands in, SHOP-R23), and notes each slot's look: from now on, AppearanceChanged
--- fires whenever one changes (SHOP-R33).
function Goods:Start()
	for _, slot in ipairs(self:Slots()) do
		local hasDefault = false
		for _, good in ipairs(slot.goods) do
			hasDefault = hasDefault or good.default ~= nil
		end
		if not hasDefault then
			local first = slot.goods[1]
			self.options.report(
				("Pagle: the slot %s has no default good%s"):format(
					slot.id,
					first and ("; %s stands in"):format(first.id) or ""
				)
			)
		end
	end
	self.shown = {}
	for _, slotID in ipairs(self:KnownSlots()) do
		self.shown[slotID] = self:GetEquipped(slotID)
	end
end

--- Fires AppearanceChanged(slot, goodID) for each slot whose look changed since it was last noted (SHOP-R33). Every
--- change in this registry settles itself; a Module turned On or off needs a call. Nothing fires before Start.
function Goods:Settle()
	local shown = self.shown
	if not shown then
		return
	end
	for _, slotID in ipairs(self:KnownSlots()) do
		local equipped = self:GetEquipped(slotID)
		if equipped ~= shown[slotID] then
			shown[slotID] = equipped
			if equipped then
				self.options.fire("AppearanceChanged", slotID, equipped)
			end
		end
	end
end
