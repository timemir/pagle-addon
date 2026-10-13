---@class PagleNS
local ns = select(2, ...)

-- The Cast state machine (LOG-R2–R9): pure logic fed the client's fishing signals and a clock (CORE-R7). The adapter
-- reads the client, and hands in how a Cast is recorded and how an event is fired, so the order of LOG-R9 lives here.

--- Tunable: how long after a fishing channel stops Core waits for its loot or the escaped message, in seconds
--- (LOG-R6, LOG-R7).
ns.FISHING_GRACE = 2

--- The fishing state `Pagle.GetFishingState()` reports (LOG-R2, LOG-R3).
---@alias PagleFishingState "idle"|"channeling"|"looting"

--- Payload of the `Catch` event, one per item of a recorded Cast (LOG-R9). Its fields are the Cast's item's, and
--- `cast` is the Cast record itself, as `Pagle.IterateCatches` yields it (LOG-R43).
---@class PagleCatch
---@field catchId string
---@field itemID integer         -- 0 if it was secret (LOG-R8)
---@field quantity integer
---@field n integer              -- position in the Cast's items
---@field cast PagleCast

--- One offered item, as the Cast entry stores it (LOG-R8).
---@class PagleLootItem
---@field itemID integer
---@field quantity integer

--- What the state machine is given: which spells are fishing (LOG-R2), how a Cast that ended caught or got away is
--- recorded (LOG-R9 steps 1 and 2: snapshot, then append; it returns the appended record, or nil when nothing could
--- be written) and how a Core event is fired.
---@class PagleFishingDeps
---@field isFishingSpell fun(spellID: integer?): boolean
---@field record fun(outcome: "caught"|"gotAway", items: PagleLootItem[], startedAt: number?): PagleCast?
---@field fire fun(event: string, ...: any)

--- The Cast in progress: when its channel started (nil for loot with no channel seen) and stopped.
---@class PagleCastInProgress
---@field startedAt number?
---@field stoppedAt number?

--- Core's fishing state for one login. Times (`now`) are the client's clock in seconds (`GetTime()`).
---@class PagleFishing
---@field deps PagleFishingDeps
---@field state PagleFishingState
---@field cast PagleCastInProgress? nil when no Cast is in progress
---@field window boolean whether a fishing loot window is open (from its LOOT_READY to LOOT_CLOSED)
local Fishing = {}
Fishing.__index = Fishing

-- Sets the state, firing FishingStateChanged if it changed.
---@param self PagleFishing
---@param state PagleFishingState
local function setState(self, state)
	if self.state ~= state then
		self.state = state
		self.deps.fire("FishingStateChanged", state)
	end
end

-- The state once no Cast is running: looting while a fishing loot window is open, idle otherwise.
---@param self PagleFishing
---@return PagleFishingState
local function restingState(self)
	return self.window and "looting" or "idle"
end

-- Ends the Cast in progress as interrupted (LOG-R7): CastEnded("interrupted") and nothing written.
---@param self PagleFishing
local function interrupt(self)
	self.cast = nil
	self.deps.fire("CastEnded", "interrupted")
end

-- Ends the Cast in progress as interrupted if its grace time ran out before `now` (LOG-R7), so a signal that comes
-- after it, but before the grace timer has run, finds the Cast already ended.
---@param self PagleFishing
---@param now number
local function expire(self, now)
	local cast = self.cast
	if cast and cast.stoppedAt and now - cast.stoppedAt > ns.FISHING_GRACE then
		interrupt(self)
		setState(self, restingState(self))
	end
end

-- Ends the Cast in progress (or one with no channel seen) caught or got away, in LOG-R9's order: record it (the
-- snapshot, then the entry), fire Catch per item then CastEnded, then set the state. A Cast ends once: it is gone
-- before anything is recorded, so a later signal for it is ignored (LOG-R7).
---@param self PagleFishing
---@param outcome "caught"|"gotAway"
---@param items PagleLootItem[]
local function finish(self, outcome, items)
	local startedAt = self.cast and self.cast.startedAt
	self.cast = nil
	local ok, cast = pcall(self.deps.record, outcome, items, startedAt)
	if ok and cast then
		for _, item in ipairs(cast.items) do
			self.deps.fire("Catch", {
				catchId = item.catchId,
				itemID = item.itemID,
				quantity = item.quantity,
				n = item.n,
				cast = cast,
			})
		end
		self.deps.fire("CastEnded", outcome, cast)
	end
	setState(self, restingState(self))
	if not ok then
		error(cast, 0)
	end
end

--- `UNIT_SPELLCAST_CHANNEL_START` for the player (LOG-R2). A fishing spell starts a Cast: a Cast still in progress
--- ends interrupted first (LOG-R7), then the state is channeling, CastStarted fires, and FishingStateChanged if the
--- state changed. Any other spell starts nothing.
---@param spellID integer? nil when secret
---@param now number
function Fishing:ChannelStarted(spellID, now)
	if not self.deps.isFishingSpell(spellID) then
		return
	end
	expire(self, now)
	if self.cast then
		interrupt(self)
	end
	self.cast = { startedAt = now }
	local changed = self.state ~= "channeling"
	self.state = "channeling"
	self.deps.fire("CastStarted")
	if changed then
		self.deps.fire("FishingStateChanged", "channeling")
	end
end

--- `UNIT_SPELLCAST_CHANNEL_STOP` for the player (LOG-R7). The fishing channel of the Cast in progress stopped: its
--- grace time starts. Returns the function the grace timer calls once `ns.FISHING_GRACE` seconds have passed: it
--- ends the Cast interrupted if nothing ended it meanwhile. Nil when there is nothing to wait for.
---@param spellID integer? nil when secret
---@param now number
---@return fun()? graceEnded
function Fishing:ChannelStopped(spellID, now)
	if not self.deps.isFishingSpell(spellID) then
		return nil
	end
	expire(self, now)
	local cast = self.cast
	if not cast or cast.stoppedAt then
		return nil
	end
	cast.stoppedAt = now
	return function()
		if self.cast == cast then
			interrupt(self)
			setState(self, restingState(self))
		end
	end
end

--- `LOOT_READY` (LOG-R3–R5). A fishing loot window ends the Cast caught, with the items `readItems` returns, whether
--- or not a channel was seen (LOG-R5). A further LOOT_READY before LOOT_CLOSED belongs to the same window and is
--- ignored (LOG-R4). `isFishing` is `IsFishingLoot()`; when it's secret (nil), the window counts as fishing while a
--- Cast is in progress.
---@param isFishing boolean?
---@param readItems fun(): PagleLootItem[]
---@param now number
function Fishing:LootReady(isFishing, readItems, now)
	expire(self, now)
	if self.window then
		return
	end
	if isFishing == nil then
		isFishing = self.cast ~= nil
	end
	if not isFishing then
		return
	end
	self.window = true
	finish(self, "caught", readItems())
end

--- `LOOT_CLOSED` (LOG-R3): the loot window is gone, and the state goes from looting to idle.
---@param now number
function Fishing:LootClosed(now)
	expire(self, now)
	self.window = false
	if not self.cast then
		setState(self, "idle")
	end
end

--- The game reported the fish escaped (LOG-R6): during the channel or within the grace time after it, the Cast in
--- progress ends got away, with no items. Any other time it's ignored.
---@param now number
function Fishing:Escaped(now)
	expire(self, now)
	if self.cast then
		finish(self, "gotAway", {})
	end
end

--- The fishing state now (LOG-R2, LOG-R3). A Cast stays channeling through its grace time, until it ends.
---@return PagleFishingState
function Fishing:GetState()
	return self.state
end

--- Core's fishing state machine, idle (LOG-R2–R9).
---@param deps PagleFishingDeps
---@return PagleFishing
function ns.NewFishing(deps)
	return setmetatable({ deps = deps, state = "idle", window = false }, Fishing)
end

--- One loot slot as Core keeps it (LOG-R3, LOG-R8): the offered item's ID and quantity, or nil for a slot that holds
--- no item (money, currency). An item's ID comes from its link; a secret link is item 0. A quantity that's secret or
--- missing counts as 1, the least a slot offers.
---@param isSecret fun(value: any): boolean `issecretvalue`
---@param link string? `GetLootSlotLink(slot)`
---@param quantity integer? `GetLootSlotInfo(slot)`'s 3rd return
---@param currencyID integer? its 4th
---@param isCoin boolean? its 10th
---@return PagleLootItem?
function ns.LootItem(isSecret, link, quantity, currencyID, isCoin)
	if (isCoin and not isSecret(isCoin)) or (currencyID ~= nil and not isSecret(currencyID)) then
		return nil
	end
	local itemID
	if isSecret(link) then
		itemID = 0
	elseif type(link) == "string" then
		itemID = tonumber(string.match(link, "item:(%d+)"))
	end
	if not itemID then
		return nil
	end
	if isSecret(quantity) or type(quantity) ~= "number" then
		quantity = 1
	end
	return { itemID = itemID, quantity = quantity }
end
