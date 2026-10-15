if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Hunts' tour stops for `/pagle dev tour` (CORE-R65, CORE-R68), and the sample they show. Real data shows little
-- before the first Hunts are out (2026-11-04), so each stop shows a sample instead, in memory only: the Hunt list with
-- every Hunt out, one Retired Hunt done, a HuntsState with Hunts at each stage and a set's title earned, and three
-- pins. Pure logic over the Hunt list's data (CORE-R7); adapter/Tour.lua swaps the sample in at each stop's show and
-- back out at its hide, so nothing is saved.

--- One of Hunts' tour stops: the board on a place, or the tracker; either in one of Hunts' goods.
---@class HuntsTourStop
---@field id string      -- the stop's ID under "hunts.": "board.home"
---@field label string   -- its label's key in ns.L, read when the stop registers (scripts load logic/ without locale)
---@field good string?   -- the good it wears (HNT-R121), whose name fills the label's %s
---@field place (fun(context: HuntsTourContext): BoardPlace)? -- the board's place; nil for the tracker

--- What a stop's place reads, once the sample is in.
---@class HuntsTourContext
---@field sample HuntsTourSample
---@field rows HuntRow[]  -- the board's rows, as its groups show them: ns.groups:Rows({ filtered = true })
---@field list HuntList   -- the sample's Hunt list
---@field now integer

--- The tour's sample, made at one server time.
---@class HuntsTourSample
---@field data HuntListData   -- the Hunt list's data with every Hunt out, and one Retired Hunt
---@field state HuntsState
---@field pins table<string, true>
---@field earnedSet string?   -- the set whose title the state has earned
---@field retired HuntDef?    -- the Retired Hunt the state has done

local DAY = 86400
-- The data a Hunt list with no list loaded reads as (logic/HuntList.lua's).
local EMPTY = { fingerprint = "", sets = {}, hunts = {}, classes = {} }

-- A copy of `hunt`, out from the start of time unless it is Retired at `now`.
---@param hunt HuntDef
---@param now integer
---@return HuntDef
local function outCopy(hunt, now)
	local copy = {}
	for key, value in pairs(hunt) do
		copy[key] = value
	end
	if not ns.IsRetired(hunt, now) then
		copy.since = 0
	end
	return copy
end

-- The Hunt the sample shows as Retired: the first already Retired, else the last of a set of two or more that isn't
-- `earnedSet`, retired a day before `now`; nil when the list has neither.
---@param hunts HuntDef[] the sample's copies
---@param earnedSet string?
---@param now integer
---@return HuntDef?
local function pickRetired(hunts, earnedSet, now)
	local perSet = {}
	for _, hunt in ipairs(hunts) do
		if hunt.retired and hunt.retired <= now then
			return hunt
		end
		perSet[hunt.set] = (perSet[hunt.set] or 0) + 1
	end
	for i = #hunts, 1, -1 do
		local hunt = hunts[i]
		if hunt.set ~= earnedSet and perSet[hunt.set] >= 2 then
			hunt.retired = now - DAY
			return hunt
		end
	end
	return nil
end

-- The item a sample tier was caught as: the Hunt's Species, or its class's lowest member.
---@param hunt HuntDef
---@param classes table<string, table<integer, true>>
---@return integer
local function itemOf(hunt, classes)
	if hunt.species then
		return hunt.species
	end
	local lowest
	for itemID in pairs(classes[hunt.class or ""] or {}) do
		lowest = (not lowest or itemID < lowest) and itemID or lowest
	end
	return lowest or 0
end

-- A HuntProgress with tiers 1 to `tiers` reached and `count` qualifying Catches, the tiers reached on days before
-- `now` (the `i`th Hunt's further back).
---@param hunt HuntDef
---@param i integer
---@param tiers integer
---@param count integer
---@param classes table<string, table<integer, true>>
---@param now integer
---@return HuntProgress
local function progress(hunt, i, tiers, count, classes, now)
	local reached = {}
	for k = 1, tiers do
		local t = now - (2 + i) * DAY + k * 3600
		local date = ns.UtcDate(t)
		reached[k] = {
			time = t,
			catchId = "tour",
			itemID = itemOf(hunt, classes),
			zone = 0,
			date = { year = date.year, month = date.month, day = date.day },
		}
	end
	return { count = count, effort = 20 + 7 * i, sinceLast = i % 5, caught = count > 0, reached = reached }
end

-- Halfway from tier `k`'s count to the next tier's, or tier `k`'s with no next.
---@param hunt HuntDef
---@param k integer
---@return integer
local function between(hunt, k)
	local after = hunt.tiers[k + 1]
	return after and math.floor((hunt.tiers[k] + after) / 2) or hunt.tiers[k]
end

--- The tour's sample at server time `now` (CORE-R65), over the Hunt list's data (ns.huntList; nil reads as none):
--- every Hunt out; the first set's title earned, each of its Hunts at tier 1 (its first Hunt at tier 2 when it has
--- three); one Retired Hunt, done; and the other Hunts in turn part way past tier 1, with effort only, and untouched.
--- The three first current Hunts with tiers left are pinned.
---@param data HuntListData?
---@param now integer
---@return HuntsTourSample
function ns.HuntsTourSample(data, now)
	data = data or EMPTY
	local hunts = {}
	for i, hunt in ipairs(data.hunts) do
		hunts[i] = outCopy(hunt, now)
	end
	local earnedSet = data.sets[1] and data.sets[1].id ---@type string?
	local retired = pickRetired(hunts, earnedSet, now)

	local state = { casts = 0, coins = 0, hunts = {}, sets = {} }
	local inSet = 0
	for i, hunt in ipairs(hunts) do
		local made
		if hunt == retired then
			made = progress(hunt, i, 1, hunt.tiers[1], data.classes, now)
		elseif hunt.set == earnedSet then
			inSet = inSet + 1
			local k = (inSet == 1 and #hunt.tiers >= 3) and 2 or 1
			made = progress(hunt, i, k, between(hunt, k), data.classes, now)
		elseif i % 3 == 1 then
			made = progress(hunt, i, 1, between(hunt, 1), data.classes, now)
		elseif i % 3 == 2 then
			made = progress(hunt, i, 0, 0, data.classes, now)
		end
		if made then
			state.hunts[hunt.id] = made
			state.casts = state.casts + made.effort
			for k = 1, #made.reached do
				state.coins = state.coins + (k == 1 and ns.COINS_COMPLETED or ns.COINS_TIER)
			end
		end
	end
	if earnedSet and inSet > 0 then
		local date = ns.UtcDate(now - DAY)
		state.sets[earnedSet] = {
			earnedAt = now - DAY,
			date = { year = date.year, month = date.month, day = date.day },
			fromRetirement = false,
		}
		state.coins = state.coins + ns.COINS_TITLE
	else
		earnedSet = nil
	end

	local pins, pinned = {}, 0
	for _, hunt in ipairs(hunts) do
		if pinned < 3 and ns.IsCurrent(hunt, now) and not ns.HuntFinished(state.hunts[hunt.id], hunt) then
			pins[hunt.id], pinned = true, pinned + 1
		end
	end
	return {
		data = { fingerprint = data.fingerprint, sets = data.sets, hunts = hunts, classes = data.classes },
		state = state,
		pins = pins,
		earnedSet = earnedSet,
		retired = retired,
	}
end

-- The Board, letting the timeline pick its Hunt (HNT-R67).
---@return BoardPlace
local function home()
	return { mode = "board" }
end

-- The Board on the first row the board shows in group `group` (HNT-R40), or picking its own with none there.
---@param group HuntGroup
---@return fun(context: HuntsTourContext): BoardPlace
local function inGroup(group)
	return function(context)
		for _, row in ipairs(context.rows) do
			if row.group == group then
				return { mode = "board", hunt = row.id }
			end
		end
		return home()
	end
end

-- The earned set's page (HNT-R66), or the Board without one.
---@param context HuntsTourContext
---@return BoardPlace
local function setPage(context)
	local set = context.sample.earnedSet
	return set and { mode = "set", set = set } or home()
end

-- The earned set's first current Hunt's entry, opened from its page (HNT-R66), or the Board without one.
---@param context HuntsTourContext
---@return BoardPlace
local function setEntry(context)
	local set = context.sample.earnedSet
	for _, hunt in ipairs(set and context.list:SetHunts(set) or {}) do
		if ns.IsCurrent(hunt, context.now) then
			return { mode = "entry", set = set, hunt = hunt.id }
		end
	end
	return home()
end

-- The Retired Hunt's retired entry, from its set's page (HNT-R3), or the Board without one.
---@param context HuntsTourContext
---@return BoardPlace
local function retiredEntry(context)
	local hunt = context.sample.retired
	return hunt and { mode = "retired", set = hunt.set, hunt = hunt.id } or home()
end

--- Hunts' tour stops, in tour order (CORE-R68): the Board, on a Hunt of each group; a set's page, an entry from it
--- and a retired entry; the tracker in the dock; then the board in each notebook cover and the tracker in each tracker
--- frame Hunts sells (HNT-R121), the defaults being the stops before.
---@type HuntsTourStop[]
ns.HUNTS_TOUR = {
	{ id = "board.home", label = "TOUR_BOARD", place = home },
	{ id = "board.now", label = "TOUR_BOARD_NOW", place = inGroup("now") },
	{ id = "board.soon", label = "TOUR_BOARD_SOON", place = inGroup("soon") },
	{ id = "board.later", label = "TOUR_BOARD_LATER", place = inGroup("later") },
	{ id = "board.ondemand", label = "TOUR_BOARD_ON_DEMAND", place = inGroup("onDemand") },
	{ id = "set.page", label = "TOUR_SET", place = setPage },
	{ id = "set.entry", label = "TOUR_SET_ENTRY", place = setEntry },
	{ id = "set.retired", label = "TOUR_RETIRED", place = retiredEntry },
	{ id = "tracker", label = "TOUR_TRACKER" },
}
for _, slot in ipairs(ns.HUNTS_GOODS) do
	for _, good in ipairs(slot.goods) do
		if not good.default then
			local suffix = good.id:match("[^.]+$")
			if slot.id == ns.COVER_SLOT then
				ns.HUNTS_TOUR[#ns.HUNTS_TOUR + 1] =
					{ id = "cover." .. suffix, label = "TOUR_COVER", good = good.id, place = home }
			else
				ns.HUNTS_TOUR[#ns.HUNTS_TOUR + 1] =
					{ id = "trackerframe." .. suffix, label = "TOUR_TRACKER_FRAME", good = good.id }
			end
		end
	end
end
