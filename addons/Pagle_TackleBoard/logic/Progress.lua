if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- How a goal's progress moves, one Catch at a time (tackle-board.md › Progress, TKB-R40–R46, TKB-R104, TKB-R196).
-- Pure logic over a TackleGoal (logic/Seams.lua) and Core's catalogue calls, handed in as `pagle` (CORE-R7). Of the
-- goal it writes only `progress`, `seen` and `progressDay`. logic/Completions.lua runs it inside the fold: for
-- each caught Cast, ns.EnterCast on every open goal, then for each Catch in item order ns.CountCatch on the open goals
-- in board order, completing a goal when ns.IsComplete turns true (TKB-R45).

--- What CountCatch reads besides the goal and the Cast.
---@class TackleProgressContext
---@field pagle table Core's calls: GetItem, GetArea and GetZones (LOG-R55)
---@field caughtBefore fun(itemID: integer): boolean whether an earlier Catch in the whole log has the item (TKB-R46)
---@field day integer the Cast's board day: the projection's day once advanced to it (TKB-R12, TKB-R14)

-- Progress that counts every Catch: +1.
---@param goal TackleGoal
---@return true
local function addOne(goal)
	goal.progress = goal.progress + 1
	return true
end

-- Progress that counts distinct keys: +1 the first time `key` is seen, nothing after.
---@param goal TackleGoal
---@param key any
---@return boolean counted
local function addDistinct(goal, key)
	if goal.seen[key] then
		return false
	end
	goal.seen[key] = true
	goal.progress = goal.progress + 1
	return true
end

-- The Species a Variety Expedition still has (TKB-R44): the `species` of each stored representative item that the
-- catalogue still has, with a `species` and not `removed`, as a set, and how many.
---@param goal TackleGoal
---@param pagle table
---@return { [integer]: true } species
---@return integer count
local function storedSpecies(goal, pagle)
	local species, count = {}, 0
	for _, itemID in ipairs(goal.items or {}) do
		local item = pagle.GetItem(itemID)
		if item and item.species and not item.removed and not species[item.species] then
			species[item.species] = true
			count = count + 1
		end
	end
	return species, count
end

-- How each kind counts one Catch that passed TKB-R40 (TKB-R42). `item` is the Catch's catalogue record, nil for an
-- Uncharted item or item 0, which only the kinds that don't need the catalogue count (TKB-R43). True when it counted.
---@type table<string, fun(goal: TackleGoal, cast: table, slot: table, item: table?, ctx: TackleProgressContext): boolean>
local COUNT = {}

function COUNT.haul(goal, cast)
	return cast.conditions.zone == goal.target and addOne(goal)
end

function COUNT.variety(goal, cast, _, item, ctx)
	if not item or cast.conditions.zone ~= goal.target or not item.species then
		return false
	end
	if goal.type == "e" then
		return storedSpecies(goal, ctx.pagle)[item.species] == true and addDistinct(goal, item.species)
	end
	return not item.noise and addDistinct(goal, item.species)
end

function COUNT.wanderer(goal, cast, _, _, ctx)
	local zone = cast.conditions.zone
	if zone == 0 then
		return false
	end
	if goal.type == "e" then
		local area = ctx.pagle.GetArea(zone)
		return area ~= nil and area.continent == goal.target and addDistinct(goal, zone)
	end
	return addDistinct(goal, zone)
end

-- The rank of a Variety rarity key (VAR-R2): its place in Core's Pagle.VARIETY_RARITIES, Common 1 to Epic 4; nil for
-- a key the list doesn't have.
---@param pagle table
---@param key string
---@return integer?
local function rarityRank(pagle, key)
	for rank, rarity in ipairs(pagle.VARIETY_RARITIES) do
		if rarity.key == key then
			return rank
		end
	end
	return nil
end

-- A Catch counts when the Variety its Cast item carries (VAR-R4) is of the target rank or rarer (TKB-R42). An item
-- with no Variety, junk and containers among them, never counts; nor does Noise.
function COUNT.rarity(goal, _, slot, item, ctx)
	if item == nil or item.noise or slot.variety == nil then
		return false
	end
	local rank = rarityRank(ctx.pagle, slot.variety.rarity)
	return rank ~= nil and rank >= goal.target and addOne(goal)
end

-- The Collector Notice's two keys (TKB-R42): what each category counts as.
local COLLECTOR_NOTICE_KEYS = { junk = "junk", container = "container" }

-- The categories of a Sub-collection item (TKB-R46).
local SUB_COLLECTION = { junk = true, container = true, treasure = true, trophy = true }

function COUNT.collector(goal, _, slot, item, ctx)
	if not item or item.noise then
		return false
	end
	if goal.type == "e" then
		return SUB_COLLECTION[item.category] == true
			and not item.removed
			and not ctx.caughtBefore(slot.itemID)
			and addDistinct(goal, slot.itemID)
	end
	local key = COLLECTOR_NOTICE_KEYS[item.category]
	return key ~= nil and addDistinct(goal, key)
end

function COUNT.lure(goal, cast)
	local lure = cast.conditions.lure
	return lure ~= nil and lure ~= 0 and addOne(goal)
end

function COUNT.species(goal, _, _, item, ctx)
	local representative = ctx.pagle.GetItem(goal.target)
	return item ~= nil
		and item.species ~= nil
		and representative ~= nil
		and item.species == representative.species
		and addOne(goal)
end

--- Whether a goal is day-bound (TKB-R41): the `wanderer` and `collector` Notices count only Catches from Casts of one
--- board day, and display 0 on any other (TKB-R104).
---@param goal TackleGoalDef
---@return boolean
function ns.IsDayBound(goal)
	return goal.type == "n" and (goal.kind == "wanderer" or goal.kind == "collector")
end

-- Whether a Cast is one a goal counts at all (TKB-R40): caught, and after the record that issued the goal.
---@param goal TackleGoal
---@param cast table
---@return boolean
local function after(goal, cast)
	return cast.outcome == "caught" and cast.seq > goal.seq
end

--- The progress a goal needs (TKB-R34, TKB-R44): its record's need, except that a Variety Expedition needs only the
--- stored Species the catalogue still has (a stored representative item now `removed`, or without a `species`, drops
--- out of its need, as it drops out of its progress).
---@param goal TackleGoal
---@param pagle table Core's catalogue calls (LOG-R55)
---@return integer
function ns.GoalNeed(goal, pagle)
	if goal.type == "e" and goal.kind == "variety" then
		local _, count = storedSpecies(goal, pagle)
		return count
	end
	return goal.need
end

-- Whether a goal's target no longer resolves in the current catalogue (TKB-R44). A Wanderer Expedition's continent is
-- looked for among GetZones' zones only when `scanContinents` is set: CountCatch skips the scan, since a Catch counts
-- for it only in a zone on that continent, which a stranded one has none of.
---@param goal TackleGoal
---@param pagle table
---@param scanContinents boolean
---@return boolean
local function stranded(goal, pagle, scanContinents)
	local kind = goal.kind
	if kind == "haul" or kind == "variety" then
		if pagle.GetArea(goal.target) == nil then
			return true
		end
		return goal.type == "e" and kind == "variety" and ns.GoalNeed(goal, pagle) == 0
	end
	if kind == "species" then
		local item = pagle.GetItem(goal.target)
		return item == nil or item.species == nil or item.removed == true
	end
	if kind == "wanderer" and goal.type == "e" and scanContinents then
		for _, zone in ipairs(pagle.GetZones()) do
			local area = pagle.GetArea(zone)
			if area and area.continent == goal.target then
				return false
			end
		end
		return true
	end
	return false
end

--- Whether a goal is stranded (TKB-R44): its target no longer resolves in the current catalogue. That is a Variety
--- Expedition with no Species left (ns.GoalNeed 0), a Species goal whose representative item is Uncharted, has no
--- `species` or is `removed`, a zone goal (Haul, Variety) whose zone GetArea no longer knows, and a Wanderer
--- Expedition whose continent no zone of GetZones is on. A stranded goal counts nothing and never completes.
---@param goal TackleGoal
---@param pagle table Core's catalogue calls (LOG-R55)
---@return boolean
function ns.IsStranded(goal, pagle)
	return stranded(goal, pagle, true)
end

--- Whether a goal is complete (TKB-R45): its progress has reached its need, and it isn't stranded (TKB-R44).
---@param goal TackleGoal
---@param pagle table Core's catalogue calls (LOG-R55)
---@return boolean
function ns.IsComplete(goal, pagle)
	return goal.progress >= ns.GoalNeed(goal, pagle) and not stranded(goal, pagle, true)
end

--- Starts a caught Cast for a goal (TKB-R41): a day-bound goal whose progress belongs to another board day than the
--- Cast's `day` (the projection's day once advanced to the Cast, TKB-R12, TKB-R14) resets its progress and `seen` and
--- belongs to the Cast's day. Call it once per caught Cast, before the Cast's Catches; it ignores a got-away Cast, one
--- from before the goal (TKB-R40) and a goal already complete (TKB-R45).
---@param goal TackleGoal
---@param cast table the Cast record (LOG-R42)
---@param day integer the Cast's board day
function ns.EnterCast(goal, cast, day)
	if not ns.IsDayBound(goal) or not after(goal, cast) or goal.progressDay == day then
		return
	end
	if goal.progress >= goal.need then
		return -- complete: its progress stays (a day-bound need never depends on the catalogue)
	end
	goal.progress, goal.seen, goal.progressDay = 0, {}, day
end

--- Counts one Catch for a goal (TKB-R40–R46): true when the goal's progress counted it.
---@param goal TackleGoal
---@param cast table the Cast record (LOG-R42) the Catch belongs to
---@param slot table the Catch: one element of `cast.items`
---@param ctx TackleProgressContext
---@return boolean counted
function ns.CountCatch(goal, cast, slot, ctx)
	if not after(goal, cast) then
		return false
	end
	if ns.IsDayBound(goal) and goal.progressDay ~= ctx.day then
		return false -- not entered (EnterCast): its progress belongs to another board day (TKB-R41)
	end
	if stranded(goal, ctx.pagle, false) or goal.progress >= ns.GoalNeed(goal, ctx.pagle) then
		return false -- stranded (TKB-R44), or complete: later Catches don't count for it (TKB-R45)
	end
	local item = slot.itemID ~= 0 and ctx.pagle.GetItem(slot.itemID) or nil
	local count = COUNT[goal.kind]
	return count ~= nil and count(goal, cast, slot, item, ctx) -- a kind the board no longer knows counts nothing
end

--- The progress the board shows for a goal (TKB-R104): its progress, except that a day-bound goal (TKB-R41) shows 0
--- on any board day but the one its progress belongs to. The pins (logic/Pins.lua), the tracker (logic/Tracker.lua)
--- and the reroll's confirm (logic/Reroll.lua) read it.
---@param goal TackleGoal
---@param today integer the board day now: the projection's day, which the live step advances at each reset (TKB-R13)
---@return integer
function ns.DisplayedProgress(goal, today)
	if ns.IsDayBound(goal) and goal.progressDay ~= today then
		return 0
	end
	return goal.progress
end
