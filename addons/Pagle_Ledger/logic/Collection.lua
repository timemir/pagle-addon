if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Collection's model (LED-R166–R172, LED-R175): every shelf, every look and title on it with its state, the counts,
-- the filters, "Within reach", "Lately added", the new and looked bookkeeping and the search. Pure logic, everything
-- read from the Journal's context (CORE-R7): Core's registry through `context.goods` (SHOP-R36), the titles through
-- logic/Titles.lua. It keeps no list of looks (LED-R166): a model is built at each use, from what Core holds then.
-- logic/JournalShelves.lua makes the pages from it; adapter/JournalShelves.lua draws them.

--- The Tracker frames shelf's key: every slot in Core's "Trackers" category shares it (LED-R167).
ns.COLLECTION_TRACKERS = "trackers"
--- The Titles shelf's key, last (LED-R167).
ns.COLLECTION_TITLES = "titles"
--- The look that signs the Ledger with the highest level title earned (LED-R77): the first on the Titles shelf.
ns.COLLECTION_AUTOMATIC = "automatic"
--- Tunables (LED-R168, LED-R170): how many looks "Within reach" and "Lately added" show, and the pencil (a look not owned):
--- desaturated, sepia 0.45, at alpha 0.5.
ns.COLLECTION_REACH = 4
ns.COLLECTION_LATELY = 4
ns.COLLECTION_PENCIL = { sepia = 0.45, alpha = 0.5 }
-- Search shows at most this many results (LED-R175 says "as LED-R148 does", which caps its two lists).
local SEARCH_MAX = 10
-- A Tracker frame slot's ID ends so, in a Module that is off, whose slot Core no longer lists (SHOP-R35).
local TRACKER_SLOT = "%.trackerframe$"

--- Which of a shelf's looks the filter tabs keep (LED-R169), by the tab's key, in the tabs' order.
ns.COLLECTION_TABS = { "all", "yours", "earn", "shop" }

--- PagleLedgerDB.global.collection (LED-R171, ledger.md › Data): when each look and title was first seen owned, and which
--- have been looked at. Display only, outside the projection, never rebuilt.
---@class LedgerCollectionDB
---@field seen table<string, integer>   -- a good's ID or a title key -> server time
---@field looked table<string, true>

--- Where a look's art is drawn from (adapter/JournalShelves.lua): Core's preview of the good (`preview`), a binding's
--- closed book, a crest's shield, a sound set's brass speaker or the quill of a title.
---@class LedgerLookArt
---@field kind "preview"|"book"|"shield"|"speaker"|"quill"
---@field good string?
---@field icon (integer|string)?

--- One look or title on a shelf (LED-R167).
---@class LedgerLook
---@field id string                 -- the good's ID, or the title key (`automatic` for Automatic)
---@field name string
---@field title boolean?            -- a title
---@field shelf string              -- its shelf's key
---@field slot string?              -- a good's slot
---@field slotName string           -- the slot's name, singular ("Toast style"); "Title" for a title
---@field module string?            -- a good's Module (def.name, "Core" for Core's)
---@field group string?             -- a title's group key; a good's group key
---@field state "inUse"|"owned"|"earn"|"shop"|"putAway"
---@field owned boolean             -- Pagle.IsOwned (a default counting as owned); an earned title
---@field default boolean           -- the slot's default
---@field crateOnly boolean         -- not owned, and only a Curio crate gives it
---@field info PagleGoodInfo?       -- Pagle.GetGood
---@field progress PagleEarnedProgress? -- Pagle.GetEarnedProgress, for a look to earn
---@field earnLine string?          -- a title's earning line
---@field new boolean               -- owned, seen and not looked at (LED-R171)
---@field order integer             -- its place in the Collection, for ties

--- One header's looks under it on a shelf (LED-R169): a group of the slot (SHOP-R27), a Tracker frames Module, a titles
--- group, or Put away; with none, the looks no group names.
---@class LedgerShelfGroup
---@field name string?
---@field owned integer
---@field looks LedgerLook[]

--- One shelf (LED-R167).
---@class LedgerShelf
---@field key string
---@field kind "slot"|"trackers"|"titles"
---@field slots PagleSlotInfo[]
---@field label string               -- plural
---@field singular string
---@field looks LedgerLook[]         -- in the order the shelf draws them
---@field groups LedgerShelfGroup[]
---@field owned integer              -- looks owned, put away ones too (LED-R172)
---@field new integer                -- looks owned and new
---@field wearing string?            -- what is worn, as the row says it (LED-R168)
---@field worn LedgerLook?           -- the look in use (the first slot's, on Tracker frames)

--- The Collection as built at one drawing.
---@class LedgerCollection
---@field shelves LedgerShelf[]
---@field byKey table<string, LedgerShelf>
---@field byID table<string, LedgerLook>
---@field owned integer
---@field total integer
---@field new integer
---@field forSale integer            -- looks the Curio Shop sells now that the Angler doesn't have (LED-R168)

-- A slot's name, singular and plural (LED-R167): the locale's for Core's slots, else the slot's label and that with an "s".
---@param slotID string
---@param label string?
---@return string singular
---@return string plural
local function slotNames(slotID, label)
	local named = ns.L.COLLECTION_SLOT_NAMES[slotID]
	if named then
		return named[1], named[2]
	elseif slotID:find(TRACKER_SLOT) then
		return ns.L.COLLECTION_TRACKER_FRAME, ns.L.COLLECTION_TRACKER_FRAMES
	end
	label = label or slotID
	return label, label:sub(-1) == "s" and label or label .. "s"
end

--- The shelves of `slots` (Pagle.GetSlots, LED-R167), empty and in their order: one per slot, in GetSlots' order, except
--- that every slot in the "Trackers" category shares one, "Tracker frames", where the first of them stands; then Titles,
--- last. Each has its key, its `slots`, its plural `label` and its `singular`.
---@param slots PagleSlotInfo[]
---@return LedgerShelf[]
function ns.CollectionShelves(slots)
	local L = ns.L
	local shelves, trackers = {}, nil
	for _, slot in ipairs(slots) do
		if slot.category == "Trackers" then
			if not trackers then
				trackers = {
					key = ns.COLLECTION_TRACKERS,
					kind = "trackers",
					slots = {},
					label = L.COLLECTION_TRACKER_FRAMES,
					singular = L.COLLECTION_TRACKER_FRAME,
				}
				shelves[#shelves + 1] = trackers
			end
			trackers.slots[#trackers.slots + 1] = slot
		else
			local singular, plural = slotNames(slot.id, slot.label)
			shelves[#shelves + 1] =
				{ key = slot.id, kind = "slot", slots = { slot }, label = plural, singular = singular }
		end
	end
	shelves[#shelves + 1] = {
		key = ns.COLLECTION_TITLES,
		kind = "titles",
		slots = {},
		label = L.COLLECTION_TITLE_OTHER,
		singular = L.COLLECTION_TITLE_ONE,
	}
	return shelves
end

--- How a shelf's looks are drawn (LED-R169): "look" two across (toast styles and tracker frames, the look at card size,
--- and any slot a Module adds), "speaker" two across, "book" four across, "shield" five across, "pick" a list of radios.
---@param shelf LedgerShelf
---@return "look"|"speaker"|"book"|"shield"|"pick"
function ns.CollectionLayout(shelf)
	if shelf.kind == "titles" then
		return "pick"
	end
	local slot = shelf.slots[1] and shelf.slots[1].id
	if slot == "core.soundset" then
		return "speaker"
	elseif slot == ns.BINDING_SLOT then
		return "book"
	elseif slot == ns.CREST_SLOT then
		return "shield"
	end
	return "look"
end

--- A Module's name, for a Tracker frames group's header and a source ("{Module} reward").
---@param module string def.name, or "Core"
---@return string
function ns.CollectionModuleName(module)
	return ns.L.COLLECTION_MODULES[module] or module
end

-- The shelf in `byKey`/`shelves` a good of slot `slotID` stands on: its slot's, or Tracker frames for a tracker slot
-- whose Module is off, so Core no longer lists it (SHOP-R35); nil for a slot nothing says.
---@param model { shelves: LedgerShelf[] }
---@param slotID string
---@return LedgerShelf?
local function shelfOfSlot(model, slotID)
	for _, shelf in ipairs(model.shelves) do
		for _, slot in ipairs(shelf.slots) do
			if slot.id == slotID then
				return shelf
			end
		end
	end
	if slotID:find(TRACKER_SLOT) then
		for _, shelf in ipairs(model.shelves) do
			if shelf.kind == "trackers" then
				return shelf
			end
		end
		-- every tracker Module is off: the shelf is there for their put away looks
	end
	return nil
end

--- The shelf's key of the good `goodID` (LED-R174), for `def.collection(goodID)` to open: nil for a good Core has never
--- cached.
---@param goods LedgerJournalGoods
---@param goodID string
---@return string?
function ns.CollectionShelfOf(goods, goodID)
	local info = goods.getGood(goodID)
	if not info then
		return nil
	end
	local shelves = ns.CollectionShelves(goods.slots())
	local shelf = shelfOfSlot({ shelves = shelves }, info.slot)
	return shelf and shelf.key
end

-- A good's look (LED-R167): its state, in LED-R167's order (in use; owned; to earn; in the shop), or put away.
---@param context LedgerSpreadContext
---@param id string
---@param shelf LedgerShelf
---@param equipped table<string, string?>
---@param labels table<string, string> the slots' labels, by ID
---@param putAway boolean
---@param light boolean? leave out what only a drawing needs: how far a look to earn is
---@return LedgerLook?
local function goodLook(context, id, shelf, equipped, labels, putAway, light)
	local goods = context.goods
	local info = goods.getGood(id)
	if not info then
		return nil
	end
	local owned = goods.isOwned(id)
	local singular = slotNames(info.slot, labels[info.slot])
	---@type LedgerLook
	local look = {
		id = id,
		name = info.name,
		shelf = shelf.key,
		slot = info.slot,
		slotName = singular,
		module = info.module,
		group = info.group,
		owned = owned,
		default = info.isDefault == true,
		crateOnly = false,
		info = info,
		new = false,
		order = 0,
		state = "owned",
	}
	if putAway then
		look.state = "putAway"
	elseif equipped[info.slot] == id then
		look.state = "inUse"
	elseif owned then
		look.state = "owned"
	elseif info.kind == "earned" then
		look.state = "earn"
		look.progress = not light and goods.earnedProgress(id) or nil
	else
		look.state = "shop"
		look.crateOnly = info.kind == "crate"
	end
	return look
end

-- One title's earning line (LED-R169): "Angler Level 40", "Prestige V", "Master in {zone}", "First Catch of {Legend}",
-- or the `complete.*` ones'. A Legend not caught is never named (LED-R124), so its line says only to land one.
---@param context LedgerSpreadContext
---@param key string
---@param earned boolean
---@return string
local function earnLine(context, key, earned)
	local L = ns.L
	local kind, n = ns.TitleKind(key)
	if kind == "level" then
		return L.LEVEL_UP_TITLE:format(n)
	elseif kind == "prestige" then
		return ns.PrestigeName(n --[[@as integer]]) or L.ANGLER_NO_PRESTIGE
	elseif kind == "zonemaster" then
		return L.COLLECTION_EARN_MASTER:format(context.text:Zone(n --[[@as integer]]))
	elseif kind == "legend" then
		return earned and L.COLLECTION_EARN_LEGEND:format(context.text:Item(n --[[@as integer]]))
			or L.EARNED_TEXT.legend
	end
	local part = n
	if part == "ledger" or part == "varieties" then
		return L.EARNED_TEXT[part]
	end
	return L["COLLECTION_EARN_" .. tostring(part):upper()] or ""
end

-- A title's group key (LED-R169): the levels and Prestige, the Wardens, the Legends and the whole Ledger's.
---@param key string
---@return string
local function titleGroup(key)
	local kind = ns.TitleKind(key)
	if kind == "level" or kind == "prestige" then
		return "levels"
	elseif kind == "zonemaster" then
		return "wardens"
	elseif kind == "legend" then
		return "legends"
	end
	return "ledger"
end
local TITLE_GROUPS = { "levels", "wardens", "legends", "ledger" }

-- The Titles shelf's looks (LED-R167, LED-R169): Automatic first, then every title with lore text (LED-R161) in
-- LED-R75's order, each earned or not; the stored pick, or Automatic, in use (LED-R77).
---@param context LedgerSpreadContext
---@param shelf LedgerShelf
---@return LedgerLook[]
local function titleLooks(context, shelf)
	local L = ns.L
	local earned = {}
	for _, key in
		ipairs(ns.TitleKeys(context --[[@as LedgerTitleView]]))
	do
		earned[key] = true
	end
	local stored = context.activeTitle
	local inUse = stored and earned[stored] and stored or ns.COLLECTION_AUTOMATIC
	---@param id string
	---@param name string
	---@param owned boolean
	---@param group string
	---@param line string
	---@return LedgerLook
	local function look(id, name, owned, group, line)
		return {
			id = id,
			name = name,
			title = true,
			shelf = shelf.key,
			slotName = L.COLLECTION_TITLE_ONE,
			group = group,
			state = id == inUse and "inUse" or (owned and "owned" or "earn"),
			owned = owned,
			default = false,
			crateOnly = false,
			earnLine = line,
			new = false,
			order = 0,
		}
	end
	local looks = { look(ns.COLLECTION_AUTOMATIC, L.ANGLER_AUTOMATIC, true, "levels", L.COLLECTION_AUTOMATIC_NOTE) }
	for _, key in
		ipairs(ns.TitleCatalogue(context --[[@as LedgerTitleView]]))
	do
		local name = ns.TitleName(key, context.text)
		if name then
			looks[#looks + 1] =
				look(key, name, earned[key] == true, titleGroup(key), earnLine(context, key, earned[key] == true))
		end
	end
	return looks
end

-- A shelf's groups from its looks, in the order the shelf draws them (LED-R169): `groups` is the list as `build` makes
-- it; counts each one's owned looks.
---@param groups LedgerShelfGroup[]
local function countGroups(groups)
	for _, group in ipairs(groups) do
		group.owned = 0
		for _, look in ipairs(group.looks) do
			if look.owned then
				group.owned = group.owned + 1
			end
		end
	end
end

-- A slot shelf's groups (SHOP-R27): the looks no group names first, with no header, then each group of the slot in
-- its order under its name; a group with no look isn't made, and a good naming a group its slot doesn't have stands with
-- the looks no group names.
---@param slot PagleSlotInfo
---@param looks LedgerLook[]
---@return LedgerShelfGroup[]
local function slotGroups(slot, looks)
	local known = {}
	for _, group in ipairs(slot.groups or {}) do
		known[group.key] = true
	end
	local byGroup, plain = {}, {}
	for _, look in ipairs(looks) do
		if look.group and known[look.group] then
			byGroup[look.group] = byGroup[look.group] or {}
			table.insert(byGroup[look.group], look)
		else
			plain[#plain + 1] = look
		end
	end
	local groups = {}
	if #plain > 0 then
		groups[1] = { looks = plain, owned = 0 }
	end
	for _, group in ipairs(slot.groups or {}) do
		if byGroup[group.key] then
			groups[#groups + 1] = { name = group.name, looks = byGroup[group.key], owned = 0 }
		end
	end
	return groups
end

--- The Collection now (LED-R166): each shelf with its looks and groups, the counts and what is worn, built from Core's
--- registry through `context.goods` and the titles through the Ledger's own. A look is new (LED-R171) while it is owned,
--- in `context.collection.seen` and not in its `looked`.
---@param context LedgerSpreadContext
---@param light boolean? without each look to earn's progress (Pagle.GetEarnedProgress): what noting the owned needs
---@return LedgerCollection
function ns.BuildCollection(context, light)
	local L = ns.L
	local goods, collection = context.goods, context.collection
	local shelves = ns.CollectionShelves(goods.slots())
	local model = { shelves = shelves, byKey = {}, byID = {}, owned = 0, total = 0, new = 0, forSale = 0 }
	-- every Tracker frame Module off, with its looks put away: the shelf is there for them (LED-R172)
	local putAway = goods.putAway()
	local hasTrackers = false
	for _, shelf in ipairs(shelves) do
		hasTrackers = hasTrackers or shelf.kind == "trackers"
	end
	if not hasTrackers then
		for _, id in ipairs(putAway) do
			local info = goods.getGood(id)
			if info and info.slot:find(TRACKER_SLOT) then
				table.insert(shelves, #shelves, {
					key = ns.COLLECTION_TRACKERS,
					kind = "trackers",
					slots = {},
					label = L.COLLECTION_TRACKER_FRAMES,
					singular = L.COLLECTION_TRACKER_FRAME,
				})
				break
			end
		end
	end
	local equipped, labels = {}, {}
	for _, shelf in ipairs(shelves) do
		model.byKey[shelf.key] = shelf
		for _, slot in ipairs(shelf.slots) do
			equipped[slot.id] = goods.getEquipped(slot.id)
			labels[slot.id] = slot.label
		end
	end
	-- the put away looks, by shelf (LED-R172), each shelf's in the order Core gives them: roster order of their Module
	local away = {}
	for _, id in ipairs(putAway) do
		local info = goods.getGood(id)
		local shelf = info and shelfOfSlot(model, info.slot)
		if shelf then
			away[shelf.key] = away[shelf.key] or {}
			table.insert(away[shelf.key], id)
		end
	end
	for _, shelf in ipairs(shelves) do
		if shelf.kind == "titles" then
			shelf.looks = titleLooks(context, shelf)
			local byGroup = {}
			for _, look in ipairs(shelf.looks) do
				byGroup[look.group] = byGroup[look.group] or {}
				table.insert(byGroup[look.group], look)
			end
			shelf.groups = {}
			for _, key in ipairs(TITLE_GROUPS) do
				if byGroup[key] then
					shelf.groups[#shelf.groups + 1] =
						{ name = L.COLLECTION_TITLE_GROUPS[key], looks = byGroup[key], owned = 0 }
				end
			end
		else
			shelf.groups = {}
			for _, slot in ipairs(shelf.slots) do
				local looks = {}
				for _, id in ipairs(goods.slotGoods(slot.id)) do
					looks[#looks + 1] = goodLook(context, id, shelf, equipped, labels, false, light)
				end
				if shelf.kind == "trackers" then
					-- grouped by Module, each its own slot and look in use (LED-R167)
					shelf.groups[#shelf.groups + 1] =
						{ name = ns.CollectionModuleName(slot.module), looks = looks, owned = 0 }
				else
					for _, group in ipairs(slotGroups(slot, looks)) do
						shelf.groups[#shelf.groups + 1] = group
					end
				end
			end
			-- Put away, last (LED-R172): a Tracker frames group of a Module that is off holds only its put away looks
			local byModule, order = {}, {}
			for _, id in ipairs(away[shelf.key] or {}) do
				local look = goodLook(context, id, shelf, equipped, labels, true, light)
				if look then
					local module = look.module or ""
					if not byModule[module] then
						byModule[module] = {}
						order[#order + 1] = module
					end
					table.insert(byModule[module], look)
				end
			end
			for _, module in ipairs(order) do
				local name = ns.CollectionModuleName(module)
				shelf.groups[#shelf.groups + 1] = {
					name = shelf.kind == "trackers" and name or L.COLLECTION_PUT_AWAY:format(name),
					looks = byModule[module],
					owned = 0,
				}
			end
			shelf.looks = {}
			for _, group in ipairs(shelf.groups) do
				for _, look in ipairs(group.looks) do
					shelf.looks[#shelf.looks + 1] = look
				end
			end
		end
		countGroups(shelf.groups)
		shelf.owned, shelf.new = 0, 0
	end
	local order = 0
	for _, shelf in ipairs(shelves) do
		for _, look in ipairs(shelf.looks) do
			order = order + 1
			look.order = order
			look.new = look.owned and collection.seen[look.id] ~= nil and not collection.looked[look.id]
			model.byID[look.id] = look
			if look.owned then
				shelf.owned = shelf.owned + 1
			end
			if look.new then
				shelf.new = shelf.new + 1
			end
			local price = look.info and look.info.price
			if not look.owned and look.state ~= "putAway" and price then
				model.forSale = model.forSale + 1
			end
		end
		model.owned, model.total, model.new =
			model.owned + shelf.owned, model.total + #shelf.looks, model.new + shelf.new
		ns.CollectionWear(context, shelf)
	end
	return model
end

-- The model built for each context, once: a Journal context lasts one drawing, which asks for it from the spread, its
-- crumbs and its contents line.
---@type table<LedgerSpreadContext, LedgerCollection>
local built = setmetatable({}, { __mode = "k" })

--- The Collection for `context` (ns.BuildCollection), built once for it.
---@param context LedgerSpreadContext
---@return LedgerCollection
function ns.CollectionModel(context)
	local model = built[context]
	if not model then
		model = ns.BuildCollection(context)
		built[context] = model
	end
	return model
end

--- What a shelf wears (LED-R168): the look in use, and the row's words for it: "Wearing {name}", "Signed “{title}”" for
--- Titles, and for Tracker frames the frames' names, one per slot, joined. Sets `shelf.worn` and `shelf.wearing`.
---@param context LedgerSpreadContext
---@param shelf LedgerShelf
function ns.CollectionWear(context, shelf)
	local L = ns.L
	local names = {}
	for _, look in ipairs(shelf.looks) do
		if look.state == "inUse" then
			shelf.worn = shelf.worn or look
			if not look.title or look.id ~= ns.COLLECTION_AUTOMATIC then
				names[#names + 1] = look.name
			end
		end
	end
	if shelf.kind == "titles" then
		-- Automatic in use signs with the highest level title earned (LED-R77)
		local _, name = ns.ActiveTitle(context --[[@as LedgerTitleView]])
		shelf.wearing = name and L.COLLECTION_SIGNED:format(name) or nil
	elseif #names > 0 then
		shelf.wearing = shelf.kind == "trackers" and table.concat(names, L.COLLECTION_FRAMES_JOIN)
			or L.COLLECTION_WEARING:format(names[1])
	end
end

--- A look's art (LED-R168–R170): a binding's closed book, a crest's shield and a sound set's speaker are the Ledger's to
--- draw from the good's icon and Core's binding look; any other good's is Core's preview of it (`Pagle.DrawGoodPreview`).
--- A title's is a quill.
---@param look LedgerLook
---@return LedgerLookArt
function ns.CollectionArt(look)
	if look.title then
		return { kind = "quill" }
	end
	local icon = look.info and look.info.icon
	if look.slot == ns.BINDING_SLOT then
		return { kind = "book", good = look.id, icon = icon }
	elseif look.slot == ns.CREST_SLOT then
		return { kind = "shield", good = look.id, icon = icon }
	elseif look.slot == "core.soundset" then
		return { kind = "speaker", good = look.id, icon = icon }
	end
	return { kind = "preview", good = look.id, icon = icon }
end

--- A shelf's looks that filter tab `tab` keeps (LED-R169): "yours" every one owned, put away ones too; "earn" and "shop"
--- the looks in that state; "all" every one. An unknown tab is "all".
---@param looks LedgerLook[]
---@param tab string?
---@return LedgerLook[]
function ns.CollectionFilter(looks, tab)
	if tab ~= "yours" and tab ~= "earn" and tab ~= "shop" then
		return looks
	end
	local kept = {}
	for _, look in ipairs(looks) do
		if (tab == "yours" and look.owned) or look.state == tab then
			kept[#kept + 1] = look
		end
	end
	return kept
end

--- The filter tabs a shelf shows (LED-R169): each with its key and its count; one with nothing in it is left out unless
--- it is the one on, and Titles has none for the shop, having nothing in it.
---@param looks LedgerLook[]
---@param on string the tab on
---@return { key: string, count: integer, on: boolean }[]
function ns.CollectionTabs(looks, on)
	local tabs = {}
	for _, key in ipairs(ns.COLLECTION_TABS) do
		local count = #ns.CollectionFilter(looks, key)
		if count > 0 or key == on then
			tabs[#tabs + 1] = { key = key, count = count, on = key == on }
		end
	end
	return tabs
end

--- The tab named by `tab`, "all" for anything else.
---@param tab any
---@return "all"|"yours"|"earn"|"shop"
function ns.CollectionTabOf(tab)
	for _, key in ipairs(ns.COLLECTION_TABS) do
		if key == tab then
			return key
		end
	end
	return "all"
end

--- The look chosen on a shelf (LED-R170): `chosen` when it is on the shelf, else the shelf's look in use, else its first.
---@param shelf LedgerShelf
---@param chosen string?
---@return LedgerLook?
function ns.CollectionChosen(shelf, chosen)
	for _, look in ipairs(shelf.looks) do
		if look.id == chosen then
			return look
		end
	end
	return shelf.worn or shelf.looks[1]
end

--- When a look came to the Angler (LED-R171): the time of the entry that bought it or the crate that gave it
--- (GetGood's `ownedAt`), else when the Ledger first saw it owned (`seen`). Nil for one not yet seen.
---@param look LedgerLook
---@param collection LedgerCollectionDB
---@return integer?
function ns.CollectionLookTime(look, collection)
	local info = look.info
	if info and (info.purchased or info.fromCrate) and info.ownedAt then
		return info.ownedAt
	end
	return collection.seen[look.id]
end

--- How a look came (LED-R168, LED-R170): "default", "bought", "crate" or "earned".
---@param look LedgerLook
---@return "default"|"bought"|"crate"|"earned"
function ns.CollectionSource(look)
	local info = look.info
	if look.default then
		return "default"
	elseif info and info.fromCrate then
		return "crate"
	elseif info and info.purchased then
		return "bought"
	end
	return "earned"
end

--- A look's progress as a share (LED-R168): have / need of its GetEarnedProgress, nil without a count.
---@param look LedgerLook
---@return number?
local function share(look)
	local progress = look.progress
	if progress and progress.have and progress.need and progress.need > 0 then
		return progress.have / progress.need
	end
	return nil
end

--- "Within reach" (LED-R168): the looks to earn with the highest share of their count, above 0 and below 1, at most four;
--- only a look whose `earnedCount` gives a count can be here. Highest first, ties in the Collection's order.
---@param model LedgerCollection
---@return { look: LedgerLook, share: number }[]
function ns.CollectionReach(model)
	local found = {}
	for _, shelf in ipairs(model.shelves) do
		for _, look in ipairs(shelf.looks) do
			local at = look.state == "earn" and share(look)
			if at and at > 0 and at < 1 then
				found[#found + 1] = { look = look, share = at }
			end
		end
	end
	table.sort(found, function(a, b)
		if a.share ~= b.share then
			return a.share > b.share
		end
		return a.look.order < b.look.order
	end)
	local reach = {}
	for i = 1, math.min(ns.COLLECTION_REACH, #found) do
		reach[i] = found[i]
	end
	return reach
end

--- "Lately added" (LED-R168, LED-R171): the four looks owned most recently, newest first, ties in the Collection's order,
--- each with the time it came. A default was never added, a title is no look and a Curio crate that paid its Coins back
--- gave nothing to list.
---@param model LedgerCollection
---@param collection LedgerCollectionDB
---@return { look: LedgerLook, time: integer }[]
function ns.CollectionLately(model, collection)
	local found = {}
	for _, shelf in ipairs(model.shelves) do
		for _, look in ipairs(shelf.looks) do
			local time = look.owned and not look.title and not look.default and ns.CollectionLookTime(look, collection)
			if time then
				found[#found + 1] = { look = look, time = time }
			end
		end
	end
	table.sort(found, function(a, b)
		if a.time ~= b.time then
			return a.time > b.time
		end
		return a.look.order < b.look.order
	end)
	local lately = {}
	for i = 1, math.min(ns.COLLECTION_LATELY, #found) do
		lately[i] = found[i]
	end
	return lately
end

--- The IDs of every look and title the Angler owns (LED-R171), for the Ledger to note as seen: owned goods, put away ones
--- too, and earned titles with lore text (Automatic among them).
---@param context LedgerSpreadContext
---@return string[]
function ns.CollectionOwnedIDs(context)
	local ids = {}
	for _, shelf in ipairs(ns.BuildCollection(context, true).shelves) do
		for _, look in ipairs(shelf.looks) do
			if look.owned then
				ids[#ids + 1] = look.id
			end
		end
	end
	return ids
end

--- Notes `ids` as seen (LED-R171) in `global.collection` (PagleLedgerDB.global), making it at the first noting: each one not in
--- `seen` gets `now`, and with no `collection` yet (a first opening, a lost PagleLedgerDB) each is looked at too, so
--- nothing starts out new. Returns the collection.
---@param global table PagleLedgerDB's global section
---@param ids string[]
---@param now integer
---@return LedgerCollectionDB
function ns.NoteCollectionSeen(global, ids, now)
	local first = type(global.collection) ~= "table"
	---@type LedgerCollectionDB
	local collection = first and { seen = {}, looked = {} } or global.collection
	collection.seen, collection.looked = collection.seen or {}, collection.looked or {}
	global.collection = collection
	for _, id in ipairs(ids) do
		if collection.seen[id] == nil then
			collection.seen[id] = now
			if first then
				collection.looked[id] = true
			end
		end
	end
	return collection
end

--- Notes the owned looks of shelf `shelf` as looked at (LED-R171), as drawing its spread does.
---@param collection LedgerCollectionDB
---@param shelf LedgerShelf
function ns.NoteShelfLooked(collection, shelf)
	for _, look in ipairs(shelf.looks) do
		if look.owned and collection.seen[look.id] ~= nil then
			collection.looked[look.id] = true
		end
	end
end

--- One search result (LED-R175): a look's name and the shelf's, opening the shelf with it chosen.
---@class LedgerLookResult
---@field label string
---@field shelf string       -- the shelf's name
---@field place LedgerJournalPlace

--- Search on the Collection's spreads (LED-R175): a case-insensitive substring of the name of every look, and of every
--- earned title, sorted by name, at most ten; a result opens its shelf with it chosen. Nil for an empty box (no drop-down), an
--- empty list for no match.
---@param query string
---@param context LedgerSpreadContext
---@return LedgerLookResult[]?
function ns.CollectionSearch(query, context)
	if query == "" then
		return nil
	end
	query = query:lower()
	local found = {}
	for _, shelf in ipairs(ns.CollectionModel(context).shelves) do
		for _, look in ipairs(shelf.looks) do
			if (not look.title or look.owned) and look.name:lower():find(query, 1, true) then
				found[#found + 1] = { look = look, shelf = shelf }
			end
		end
	end
	table.sort(found, function(a, b)
		if a.look.name ~= b.look.name then
			return a.look.name < b.look.name
		end
		return a.look.order < b.look.order
	end)
	local results = {}
	for i = 1, math.min(SEARCH_MAX, #found) do
		local at = found[i]
		results[i] = {
			label = at.look.name,
			shelf = at.shelf.singular,
			place = ns.JournalPlace.shelf(at.shelf.key, at.look.id),
		}
	end
	return results
end

--- Home's contents line for the Collection (LED-R132): "The Collection: looks and titles" with "x / N" of both and "{n}
--- new" in red hand while any is new (LED-R171), opening the Collection.
---@param context LedgerSpreadContext
---@param numeral string
---@return LedgerBlock
function ns.CollectionContentsLine(context, numeral)
	local L = ns.L
	local model = ns.CollectionModel(context)
	local format = context.formatNumber
	return {
		kind = "leader",
		numeral = numeral,
		text = L.COLLECTION_CONTENTS,
		value = L.COUNT_OF:format(format(model.owned), format(model.total)),
		note = model.new > 0 and L.COLLECTION_NEW_COUNT:format(format(model.new)) or nil,
		place = ns.JournalPlace.collection(),
	}
end
