if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Angler's titles (LED-R75–R77): which are earned, in what order, how each is named and the one the Angler signs
-- with. Computed from the state, the world and the celebrated set when asked, never stored (ledger.md › Data). Pure
-- logic, everything passed in (CORE-R7); the Journal and the moments show them.

--- The celebrated set's title keys (LED-R90), filled as titles are celebrated.
---@class LedgerCelebrated
---@field titles? { [string]: true }

--- What the titles read. A Journal context that isn't updating is one (LedgerJournalContext).
---@class LedgerTitleView
---@field world LedgerWorld                         -- the world index (LED-R10)
---@field state? LedgerState                        -- nil before the projection is built: celebrated titles only
---@field celebrated LedgerCelebrated               -- the celebrated set (LED-R90), read as saved
---@field getItem fun(itemID: integer): PagleItem?  -- Pagle.GetItem
---@field activeTitle? string                       -- the stored active title (LED-R77), for ns.ActiveTitle
---@field text? LedgerJournalText                   -- the Journal's words, for ns.ActiveTitle's name
---@field activityXPTotal? integer                  -- Core's Activity XP total, ns.ActivityXPTotal() when nil
---@field ownsAll? boolean                          -- a test log's `devGoods` (SHOP-R37): every title counts as earned

-- The level titles and the prestige titles (LED-R75, Tunables): `level<L>` once the peak level reaches L,
-- `prestige<R>` once the prestige rank reaches R.
local LEVELS = { 1, 10, 20, 30, 40, 50, 60 }
local PRESTIGES = { 1, 5, 10 }
-- The completion parts (ns.COMPLETION_PARTS) with a title each (LED-R75), in its order: `complete.<part>` once that
-- part's count (LED-R71) is done, at a total above 0; `complete.varieties` when every fish with varieties is
-- complete (VAR-R22). Species and zones have none.
local TITLED_PARTS = { "junk", "treasure", "trophy", "varieties" }

-- Each title's place in LED-R75's table, by title key; `zonemaster:` and `legend:` keys by their prefix, then by
-- their number.
local PLACE = {}
for _, level in ipairs(LEVELS) do
	PLACE[#PLACE + 1] = "title:level" .. level
end
for _, rank in ipairs(PRESTIGES) do
	PLACE[#PLACE + 1] = "title:prestige" .. rank
end
PLACE[#PLACE + 1] = "zonemaster"
PLACE[#PLACE + 1] = "legend"
PLACE[#PLACE + 1] = "title:complete.ledger"
for _, part in ipairs(TITLED_PARTS) do
	PLACE[#PLACE + 1] = "title:complete." .. part
end
local PLACE_OF = {}
for i, key in ipairs(PLACE) do
	PLACE_OF[key] = i
end

-- A title key's place in LED-R75's order and its number within it (a zone's or an item's ID); a key the table
-- doesn't have comes last.
---@param key string
---@return integer place
---@return integer n
local function placeOf(key)
	local prefix, n = key:match("^(%a+):(%d+)$")
	if prefix and PLACE_OF[prefix] then
		return PLACE_OF[prefix], tonumber(n) --[[@as integer]]
	end
	return PLACE_OF[key] or #PLACE + 1, 0
end

-- Whether title key `a` comes before `b` (LED-R75): by place, then number, then the key itself.
---@param a string
---@param b string
---@return boolean
local function before(a, b)
	local placeA, nA = placeOf(a)
	local placeB, nB = placeOf(b)
	if placeA ~= placeB then
		return placeA < placeB
	elseif nA ~= nB then
		return nA < nB
	end
	return a < b
end

-- The title keys the projection computes now (LED-R75), as a set.
---@param view LedgerTitleView
---@param made LedgerState
---@return { [string]: true }
local function computed(view, made)
	local keys = {}
	local peak = ns.PeakLevel(made, view.activityXPTotal)
	for _, level in ipairs(LEVELS) do
		if peak >= level then
			keys["title:level" .. level] = true
		end
	end
	for _, rank in ipairs(PRESTIGES) do
		if made.prestige >= rank then
			keys["title:prestige" .. rank] = true
		end
	end
	for _, zone in ipairs(view.world.charted) do
		if ns.ShownZoneRank(view.world, made, view.celebrated, zone) >= ns.ZONE_MASTER then
			keys["zonemaster:" .. zone] = true
		end
	end
	for itemID in pairs(made.items) do
		if ns.ClassifyCatch(itemID, view.getItem(itemID)) == "legend" then
			keys["legend:" .. itemID] = true
		end
	end
	local completion = ns.LedgerCompletion(view.world, made)
	if completion.percent == 100 then
		keys["title:complete.ledger"] = true
	end
	for _, part in ipairs(TITLED_PARTS) do
		local count = completion[part]
		if count.total > 0 and count.done >= count.total then
			keys["title:complete." .. part] = true
		end
	end
	return keys
end

-- The keys of `set`, in LED-R75's order.
---@param set { [string]: true }
---@return string[]
local function ordered(set)
	local keys = {}
	for key in pairs(set) do
		keys[#keys + 1] = key
	end
	table.sort(keys, before)
	return keys
end

-- Every title there is, as a set: the level and Prestige titles, a `zonemaster` title for each charted zone, a Legend's
-- for each Legend of the world and the `complete.*` ones.
---@param view LedgerTitleView
---@return { [string]: true }
local function catalogue(view)
	local set = {}
	for _, level in ipairs(LEVELS) do
		set["title:level" .. level] = true
	end
	for _, rank in ipairs(PRESTIGES) do
		set["title:prestige" .. rank] = true
	end
	for _, zone in ipairs(view.world.charted) do
		set["zonemaster:" .. zone] = true
	end
	for _, itemID in ipairs(ns.CollectionWorlds(view.world, view.state or { species = {}, items = {} }).legends) do
		set["legend:" .. itemID] = true
	end
	set["title:complete.ledger"] = true
	for _, part in ipairs(TITLED_PARTS) do
		set["title:complete." .. part] = true
	end
	return set
end

--- The earned title keys (LED-R75, LED-R76), in LED-R75's order: the ones computed now plus every key in the
--- celebrated set, so a title is never taken away (LED-R92), even when its zone stops being charted (LED-R54) or the
--- data grows (LED-R72). A view with `ownsAll` (a test log's `devGoods`, SHOP-R37) has every title there is, for display
--- only: the projection, the celebrated set and the moments never read it.
---@param view LedgerTitleView
---@return string[]
function ns.TitleKeys(view)
	local set = view.ownsAll and catalogue(view) or {}
	for key in pairs(view.state and computed(view, view.state) or {}) do
		set[key] = true
	end
	for key in pairs(view.celebrated.titles or {}) do
		set[key] = true
	end
	return ordered(set)
end

--- Every title there is (LED-R75), earned or not, in LED-R75's order: the level and Prestige titles, a `zonemaster`
--- title for each charted zone, a Legend's for each Legend of the world (LED-R11) and the `complete.*` ones, with any
--- earned key the table no longer lists (a zone no longer charted, LED-R54). The Collection's Titles shelf (LED-R167).
---@param view LedgerTitleView
---@return string[]
function ns.TitleCatalogue(view)
	local set = catalogue(view)
	for _, key in ipairs(ns.TitleKeys(view)) do
		set[key] = true
	end
	return ordered(set)
end

--- The titles earned now that the celebrated set doesn't have yet (LED-R75, LED-R90), in LED-R75's order: what a
--- state change newly earns, for the moments to raise ("Title: {title}" on the moment each rides on, a `completeTitle`
--- per `complete.*`, LED-R97). Never `level1`, which is earned from the start and raises no moment (LED-R75).
---@param view LedgerTitleView
---@return string[]
function ns.NewTitles(view)
	local set = view.state and computed(view, view.state) or {}
	set["title:level1"] = nil
	for key in pairs(view.celebrated.titles or {}) do
		set[key] = nil
	end
	return ordered(set)
end

--- What a title key is (LED-R75), so a moment can take the titles that ride on it: "level" with the level,
--- "prestige" with the rank, "zonemaster" with the zone, "legend" with the item ID, or "complete" with the part
--- ("ledger", "junk", "treasure", "trophy" or "varieties"). Nothing for a key that names no title.
---@param key string
---@return ("level"|"prestige"|"zonemaster"|"legend"|"complete")? kind
---@return (integer|string)? n
function ns.TitleKind(key)
	if not PLACE_OF[key] then
		local prefix, n = key:match("^(%a+):(%d+)$")
		if prefix == "zonemaster" or prefix == "legend" then
			return prefix, tonumber(n)
		end
		return nil, nil
	end
	local kind, n = key:match("^title:(%a+)(%d+)$")
	if kind then
		return kind, tonumber(n)
	end
	return "complete", key:match("^title:complete%.(%a+)$")
end

--- A title key's name (LED-R75): its lore text, `title.<titleID>.text` (the `zonemaster` one with `{zone}` filled
--- with the zone's name, LED-R161), or `legend.<itemID>.title` for a Legend (LED-R160), read through `text` (#139's
--- lore lookup). nil when the key has no text, so a line naming it is left out (LED-R161).
---@param key string a title key (LED-R76)
---@param text LedgerJournalText
---@return string?
function ns.TitleName(key, text)
	local titleID = key:match("^title:(.+)$")
	if titleID then
		return text:Lore("title." .. titleID .. ".text")
	end
	local zone = key:match("^zonemaster:(%d+)$")
	if zone then
		return text:Lore("title.zonemaster.text", tonumber(zone))
	end
	local itemID = key:match("^legend:(%d+)$")
	return itemID and text:Lore("legend." .. itemID .. ".title")
end

-- Whether `key` is in the list `keys`.
---@param keys string[]
---@param key string
---@return boolean
local function listed(keys, key)
	for _, earned in ipairs(keys) do
		if earned == key then
			return true
		end
	end
	return false
end

--- The active title (LED-R77): the stored key (`view.activeTitle`, PagleLedgerDB.profile.activeTitle) when it is
--- earned, else automatic, the highest level title earned. A stored key that isn't earned is read as automatic and
--- left stored. Its name too, through `view.text` (nil without text, LED-R161). Both nil with no title earned.
---@param view LedgerTitleView
---@return string? key
---@return string? name
function ns.ActiveTitle(view)
	local keys = ns.TitleKeys(view)
	local stored = view.activeTitle
	local key = stored and listed(keys, stored) and stored or nil
	if not key then
		for _, earned in ipairs(keys) do
			if earned:find("^title:level%d+$") then
				key = earned
			end
		end
	end
	if not key then
		return nil, nil
	end
	return key, view.text and ns.TitleName(key, view.text) or nil
end

--- Sets the active title (LED-R77) in `profile` (PagleLedgerDB.profile): an earned key, or nil for automatic.
---@param profile table
---@param view LedgerTitleView
---@param key string?
---@return boolean set false, and nothing stored, for a key that isn't earned
function ns.StoreActiveTitle(profile, view, key)
	if key ~= nil and not listed(ns.TitleKeys(view), key) then
		return false
	end
	profile.activeTitle = key
	return true
end
