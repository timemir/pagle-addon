---@class PagleNS
local ns = select(2, ...)

-- The goods registry (ADR 0009, wallet-and-shop.md › Goods, Owning and equipping): the slots and goods Core and the
-- Modules register, their cache in PagleDB.global.goods, what is owned and what is equipped. Pure logic, everything
-- passed in (CORE-R7); logic/Wiring.lua builds Core's one registry, and adapter/Goods.lua publishes it.

--- A slot a Module or Core registers (wallet-and-shop.md › Contracts).
---@class PagleSlot
---@field id string              -- "core.toaststyle", "hunts.notebookcover", "stats.trackerframe"
---@field label string           -- "Toast style"
---@field category "Announcements"|"Bookplate"|"Fish Journal"|"Hunts"|"Trackers" -- ns.SLOT_CATEGORY_ORDER
---@field openToEarned? boolean  -- Core's slots only: any Module may add earned goods to it (SHOP-R23)
---@field preview? fun(stage: Frame, good: PagleRegisteredGood) -- Core's slots only: draws a good of the slot that
--- has no preview of its own on the shop's stage (an open slot's goods from other Modules, SHOP-R25)
---@field groups? PagleSlotGroup[] -- the slot's groups, in the order the shop lists them (SHOP-R27)

--- One group of a slot's goods (SHOP-R27): the shop lists its goods together under its name.
---@class PagleSlotGroup
---@field key string             -- what a good names in its `group`, matching [%w_]+
---@field name string            -- its header on the shop's list, interface text ("Zone crests")

--- One dot of an earned good's progress (SHOP-R22), on the shop's stage: filled in its colour, or ringed in it.
---@class PagleProgressDot
---@field color number[]         -- { r, g, b }, each 0 to 1
---@field filled boolean

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
---@field earnedText? string|fun(): string?, string? -- earned: "Angler Level 30", or the row's tag and the stage's
--- note, worked out each time the shop draws the good while it isn't owned (SHOP-R22)
---@field progress? fun(): PagleProgressDot[] -- earned: the dots the stage shows while it isn't owned (SHOP-R22)
---@field group? string           -- the key of one of its slot's groups (SHOP-R27)
---@field preview? fun(stage: Frame)   -- draws the look on the shop's preview stage

--- A registered slot, with who registered it. `openToEarned` and `preview` are kept for Core's slots only.
---@class PagleRegisteredSlot: PagleSlot
---@field module string           -- def.name, or "Core"
---@field goods PagleRegisteredGood[] -- its goods, in registration order, another Module's in an open slot included
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
	if type(id) ~= "string" or not id:match(ns.GOOD_ID_PATTERN) then
		return ("M:%s: the id must be a string of letters, digits, _ and ., got %s"):format(call, tostring(id))
	end
	local prefix = module:lower() .. "."
	if id:sub(1, #prefix) ~= prefix or #id == #prefix then
		return ("M:%s: %s doesn't start with %s"):format(call, id, prefix)
	end
	return nil
end

-- Why `slot`'s groups can't be (SHOP-R23, SHOP-R27), or nil if they can: none, or a list of { key, name }, each key
-- matching [%w_]+ and given once, each name a string that isn't empty.
---@param slot table
---@return string?
local function groupsProblem(slot)
	local groups = slot.groups
	if groups == nil then
		return nil
	elseif type(groups) ~= "table" then
		return ("M:RegisterSlot: %s's groups must be a list of { key, name }"):format(slot.id)
	end
	local seen = {}
	for i, group in ipairs(groups) do
		local key = type(group) == "table" and group.key
		if type(key) ~= "string" or not key:match("^[%w_]+$") then
			return ("M:RegisterSlot: %s's group %d needs a key of letters, digits and _"):format(slot.id, i)
		elseif seen[key] then
			return ("M:RegisterSlot: %s has the group %s twice"):format(slot.id, key)
		elseif type(group.name) ~= "string" or group.name == "" then
			return ("M:RegisterSlot: %s's group %s has no name"):format(slot.id, key)
		end
		seen[key] = true
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
		return ("M:RegisterSlot: %s's category must be one of %s; got %s"):format(
			slot.id,
			table.concat(ns.SLOT_CATEGORY_ORDER, ", "),
			tostring(slot.category)
		)
	end
	return groupsProblem(slot)
end

--- Who registered Core's own slots and goods, where a Module's def.name goes (SHOP-R21, SHOP-R25).
ns.CORE_OWNER = "Core"

--- The slot categories (wallet-and-shop.md › Contracts), in the order the shop's chips and Look and Feel list them.
ns.SLOT_CATEGORY_ORDER = { "Announcements", "Bookplate", "Fish Journal", "Hunts", "Trackers" }

--- Each slot category, as a set.
---@type table<string, true>
ns.SLOT_CATEGORIES = {}
for _, category in ipairs(ns.SLOT_CATEGORY_ORDER) do
	ns.SLOT_CATEGORIES[category] = true
end

--- One category's slots, in the order they were handed in.
---@class PagleSlotSection
---@field category string        -- the slot category, as registered ("Fish Journal")
---@field slots PagleRegisteredSlot[]

--- `slots` grouped by category, in ns.SLOT_CATEGORY_ORDER, each category's in the order given; a category with none
--- isn't listed. The shop's chips and Look and Feel's headers (wallet-and-shop.md › UI, SET-R50).
---@param slots PagleRegisteredSlot[]
---@return PagleSlotSection[]
function ns.SlotsByCategory(slots)
	local byCategory = {}
	for _, slot in ipairs(slots) do
		local list = byCategory[slot.category] or {}
		byCategory[slot.category] = list
		list[#list + 1] = slot
	end
	local sections = {}
	for _, category in ipairs(ns.SLOT_CATEGORY_ORDER) do
		if byCategory[category] then
			sections[#sections + 1] = { category = category, slots = byCategory[category] }
		end
	end
	return sections
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
	local core = module == ns.CORE_OWNER
	local groups
	for i, group in ipairs(slot.groups or {}) do
		groups = groups or {}
		groups[i] = { key = group.key, name = group.name }
	end
	self.slots[slot.id] = {
		id = slot.id,
		label = slot.label,
		category = slot.category,
		openToEarned = core and slot.openToEarned == true or nil,
		preview = core and type(slot.preview) == "function" and slot.preview or nil,
		groups = groups,
		module = module,
		goods = {},
		seq = self.registered,
	}
	self:Settle()
	return nil
end

-- Whether `good`, of `module`, may go in `slot` (SHOP-R23): a slot of the same owner, or an earned good (isEarned
-- set, neither a default nor a tier) of another Module in a Core slot open to earned goods.
---@param slot PagleRegisteredSlot
---@param module string
---@param good table
---@return boolean
local function mayUse(slot, module, good)
	if slot.module == module then
		return true
	end
	return slot.openToEarned == true and good.isEarned ~= nil and not good.default and good.tier == nil
end

-- The group of `slot` whose key is `key` (SHOP-R27), or nil.
---@param slot PagleRegisteredSlot
---@param key any
---@return PagleSlotGroup?
local function groupOf(slot, key)
	for _, group in ipairs(slot.groups or {}) do
		if group.key == key then
			return group
		end
	end
	return nil
end

-- Why a good can't register for `module`, or nil if it can (SHOP-R22, SHOP-R23, SHOP-R27).
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
	elseif not mayUse(slot, module, good) then
		return ("M:RegisterGood: %s's slot %s is %s's"):format(id, slot.id, slot.module)
	elseif type(good.name) ~= "string" or good.name == "" then
		return ("M:RegisterGood: %s has no name"):format(id)
	end
	if good.default ~= nil and type(good.default) ~= "boolean" then
		return ("M:RegisterGood: %s's default must be true or false"):format(id)
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
	if good.description ~= nil and type(good.description) ~= "string" then
		return ("M:RegisterGood: %s's description must be a string"):format(id)
	elseif good.earnedText ~= nil and type(good.earnedText) ~= "string" and type(good.earnedText) ~= "function" then
		return ("M:RegisterGood: %s's earnedText must be a string or a function"):format(id)
	elseif good.progress ~= nil and (type(good.progress) ~= "function" or good.isEarned == nil) then
		return ("M:RegisterGood: %s's progress must be a function, on an earned good"):format(id)
	elseif good.group ~= nil and not groupOf(slot, good.group) then
		return ("M:RegisterGood: %s's slot %s has no group %s"):format(id, slot.id, tostring(good.group))
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

-- A text an earnedText function gave, or nil for anything but a string with something in it.
---@param text any
---@return string?
local function textOf(text)
	return type(text) == "string" and text ~= "" and text or nil
end

--- An earned good's texts as the shop draws them now (SHOP-R22): the row's tag and the stage's note. An earnedText
--- string is both; a function is called now, through `call`, every time the good isn't owned (never cached, never for
--- ownership, SHOP-R30), and gives the tag and, optionally, the note. Nothing for a function that raises (reported) or
--- gives no text, an owned good's function, a good with no earnedText, and a good that isn't earned or registered.
---@param goodID any
---@return string? tag
---@return string? note
function Goods:EarnedTexts(goodID)
	local good = self.goods[goodID]
	local earnedText = good and good.isEarned and good.earnedText
	if type(earnedText) == "string" then
		return earnedText, earnedText
	elseif type(earnedText) ~= "function" or self:IsOwned(goodID) then
		return nil, nil
	end
	local tag, note
	self.options.call(function()
		tag, note = earnedText()
	end)
	tag = textOf(tag)
	return tag, tag and textOf(note)
end

--- An earned good's progress as the shop's stage draws it now (SHOP-R22): its progress function's result, called now,
--- through `call`, every time the good isn't owned, never cached and never for ownership; the shop keeps the well-made
--- dots. Nothing for a function that raises (reported), an owned good, a good without progress, and a good that isn't
--- earned or registered.
---@param goodID any
---@return any dots
function Goods:Progress(goodID)
	local good = self.goods[goodID]
	local progress = good and good.isEarned and good.progress
	if type(progress) ~= "function" or self:IsOwned(goodID) then
		return nil
	end
	local dots
	self.options.call(function()
		dots = progress()
	end)
	return dots
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
	local order = { [ns.CORE_OWNER] = 0 }
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

--- The slots, as Slots orders them, that have a good to pick (a slot with none has nothing to show, SET-R50), and
--- that `keep` keeps when given.
---@param keep (fun(slot: PagleRegisteredSlot): boolean)?
---@return PagleRegisteredSlot[]
function Goods:SlotsWithGoods(keep)
	local list = {}
	for _, slot in ipairs(self:Slots()) do
		if #slot.goods > 0 and (keep == nil or keep(slot)) then
			list[#list + 1] = slot
		end
	end
	return list
end

--- The goods registered this session in a slot, in registration order (empty for a slot not registered), but for
--- another Module's in an open Core slot while that Module isn't On (SHOP-R23, SHOP-R90). Core's own; nothing in them
--- may be changed.
---@param slotID string
---@return PagleRegisteredGood[]
function Goods:GoodsOf(slotID)
	local slot = self.slots[slotID]
	if not slot then
		return {}
	elseif not slot.openToEarned then
		return slot.goods
	end
	local order, list = self:OrderOn(), {}
	for _, good in ipairs(slot.goods) do
		if good.module == slot.module or order[good.module] then
			list[#list + 1] = good
		end
	end
	return list
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
		if type(cached) == "table" and cached.slot == slotID and cached.default and (not found or goodID < found) then
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

--- A slot's owned goods (SHOP-R30), in registration order. Core's own; nothing in them may be changed.
---@param slotID string
---@return PagleRegisteredGood[]
function Goods:OwnedOf(slotID)
	local owned = {}
	for _, good in ipairs(self:GoodsOf(slotID)) do
		if self:IsOwned(good.id) then
			owned[#owned + 1] = good
		end
	end
	return owned
end

--- Whether a good registered this session is for sale (a tier, SHOP-R22) and not owned yet (SHOP-R30).
---@param goodID any
---@return boolean
function Goods:IsForSale(goodID)
	local good = self.goods[goodID]
	return good ~= nil and good.tier ~= nil and not self:IsOwned(goodID)
end

--- The good equipped in a slot (SHOP-R32): the stored pick while it is owned and registered by a Module On (its
--- slot's, and its own in an open Core slot, SHOP-R23), else the slot's default. Reading never clears the pick, so it comes back with its Module (SHOP-R90). Nil for a slot with
--- no goods.
---@param slotID any
---@return string?
function Goods:GetEquipped(slotID)
	if type(slotID) ~= "string" then
		return nil
	end
	local stored = self.options.db().profile.appearance[slotID]
	local good = self.goods[stored]
	if
		good
		and good.slot == slotID
		and self:IsLive(slotID)
		and self:OrderOn()[good.module]
		and self:IsOwned(stored)
	then
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
---@field isDefault boolean        -- the slot's default (SHOP-R22), or the good standing in for one (SHOP-R23)

--- A good's name, slot, icon, Module and description, from the cache, and whether it is its slot's default, as a
--- fresh copy; nil for a good never cached.
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
		isDefault = self:DefaultOf(cached.slot) == goodID,
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
		if type(cached) == "table" and type(cached.slot) == "string" then
			seen[cached.slot] = true
		end
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
			hasDefault = hasDefault or good.default == true
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
