if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- How a goal's progress moves, one Catch at a time (tackle-board.md › Progress, TKB-R40–R46, TKB-R104, TKB-R196).
-- Pure logic over a TackleGoal (logic/Seams.lua) and Core's catalogue calls, handed in as `pagle` (CORE-R7). Of the
-- goal it writes only `progress`, `seen` and `session`. The completions' ticket (#232) runs it inside the fold: for
-- each caught Cast, ns.EnterCast on every open goal, then for each Catch in item order ns.CountCatch on the open goals
-- in board order, completing a goal when ns.IsComplete turns true (TKB-R45).

--- What CountCatch reads besides the goal and the Cast (M7 graph, shapes).
---@class TackleProgressContext
---@field pagle table Core's calls: GetItem, GetArea and GetZones (LOG-R55)
---@field caughtBefore fun(itemID: integer): boolean whether an earlier Catch in the whole log has the item (TKB-R46)

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
---@type { [string]: fun(goal: TackleGoal, cast: table, slot: table, item: table?, ctx: TackleProgressContext): boolean }
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

--- Whether a goal is session-bound (TKB-R41): the `wanderer` and `collector` Notices count only Catches from Casts
--- of one Session, and display 0 outside it (TKB-R104).
---@param goal TackleGoalDef
---@return boolean
function ns.IsSessionBound(goal)
	return goal.type == "n" and (goal.kind == "wanderer" or goal.kind == "collector")
end

-- Whether a Cast is one a goal counts at all (TKB-R40): caught, and after the record that issued the goal.
---@param goal TackleGoal
---@param cast table
---@return boolean
local function after(goal, cast)
	return cast.outcome == "caught" and cast.seq > goal.seq
end

--- Starts a caught Cast for a goal (TKB-R41): a session-bound goal whose progress belongs to another Session than the
--- Cast's (Core's `session` tag, LOG-R98) resets its progress and `seen` and belongs to the Cast's Session. Call it once
--- per caught Cast, before the Cast's Catches; it ignores a got-away Cast, one from before the goal (TKB-R40) and a
--- goal already complete (TKB-R45).
---@param goal TackleGoal
---@param cast table the Cast record (LOG-R42)
function ns.EnterCast(goal, cast)
	if not ns.IsSessionBound(goal) or not after(goal, cast) or goal.session == cast.session then
		return
	end
	if goal.progress >= goal.need then
		return -- complete: its progress stays (a session-bound need never depends on the catalogue)
	end
	goal.progress, goal.seen, goal.session = 0, {}, cast.session
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
	if ns.IsSessionBound(goal) and goal.session ~= cast.session then
		return false -- not entered (EnterCast): its progress belongs to another Session (TKB-R41)
	end
	local item = slot.itemID ~= 0 and ctx.pagle.GetItem(slot.itemID) or nil
	return COUNT[goal.kind](goal, cast, slot, item, ctx)
end
