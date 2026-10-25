if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- What the Angler is told about Pagle Wagers (HNT-R86's wager rows, HNT-R90–R92, HNT-R111, HNT-R112, HNT-R148,
-- HNT-R149): a moment for each mark an event Hunt reaches in a run, for each settled run and each ladder title, all
-- guarded by the celebrated set's run and ladder entries. Pure logic, everything passed in (CORE-R7); the Hunt list
-- (`ns.hunts`, for a fixed class's members) and the event pool (`ns.events`, for names) are read at call time.
-- logic/Moments.lua calls it for a live Cast, a live `run` record and `done`, beside the Standing Hunts' moments.

--- The celebrated set's entry for one run, by run key (HNT-R90, HNT-R92): each event Hunt's highest tier already
--- shown, whether its completion was, and the run's end, which says when `done` drops the entry.
---@class HuntsCelebratedRun
---@field tiers table<string, integer>
---@field settled true?
---@field endsAt integer

--- One thing Pagle Wagers celebrates: an event Hunt's tier in a run (`mark`), a completed run (`settled`), or a ladder
--- step's title (`ladder`).
---@class HuntsWager
---@field kind "mark"|"settled"|"ladder"
---@field run string?    -- the run key, for a mark or a settled run
---@field hunt string?   -- the event Hunt's ID, for a mark
---@field tier integer?  -- the tier, for a mark
---@field step integer?  -- the ladder step, for a ladder title

--- An event's icon in a moment (HNT-R161: its first Hunt's, by HNT-R55's moment rule): a `species` target's item, a
--- fixed class's first member, else `Trade_Fishing` untinted (a moment has no tint).
---@param event HuntEvent
---@return integer|string
function ns.EventMomentIcon(event)
	local first = event.hunts[1]
	if not first then
		return ns.HuntMomentIcon(nil)
	elseif first.species then
		return ns.HuntMomentIcon(first.species)
	elseif ns.GENERATED_CLASSES[first.class] then
		return ns.HuntMomentIcon(nil)
	end
	-- A fixed class's first member, in ascending item ID order, as ns.HuntClassMembers orders a Standing Hunt's.
	local firstMember
	for itemID in pairs(ns.hunts:Class(first.class) or {}) do
		if not firstMember or itemID < firstMember then
			firstMember = itemID
		end
	end
	return ns.HuntMomentIcon(firstMember)
end

--- A ladder step's title (HNT-R130, HNT-R148): its lore, `ladder.<n>.title`, else its key `ladder.<n>` while the lore
--- has none (HNT-R1's fallback to the ID).
---@param step integer
---@return string
function ns.LadderTitle(step)
	return ns.Lore(ns.L, "ladder." .. step .. ".title") or ("ladder." .. step)
end

--- The Refreshes a moment carries (HNT-R117, REF-R7): `n`, or nil for none, since a moment with no Refreshes has no
--- `tickets` field.
---@param n integer
---@return integer?
local function momentTickets(n)
	return n > 0 and n or nil
end

--- The moment for tier `k` of event Hunt `hunt` in a run (HNT-R86): the first mark at tier 1, a further mark after;
--- `huntTier` is the HuntTier that reached it, whose Catch's item is the icon (HNT-R55). No `cast`: the caller adds it.
---@param hunt HuntEventHunt
---@param k integer
---@param huntTier HuntTier
---@return PagleMoment
function ns.WagerMarkMoment(hunt, k, huntTier)
	local L = ns.L
	local name = ns.events:HuntName(hunt)
	if k == 1 then
		return {
			rung = "toast",
			kind = "wagerMark",
			title = L.WAGER_MARK,
			text = L.WAGER_MARK_TEXT:format(name),
			stamp = L.WAGER_MARK_STAMP,
			icon = ns.HuntMomentIcon(huntTier.itemID),
			coins = ns.TierAmount(ns.COINS_EVENT, k),
		}
	end
	local trim = L.TRIMS[ns.Trim(k)]
	return {
		rung = "toast.low",
		kind = "wagerTier",
		title = L.WAGER_TIER:format(trim),
		text = L.HUNT_TIER_TEXT:format(name, hunt.tiers[k]),
		stamp = trim,
		icon = ns.HuntMomentIcon(huntTier.itemID),
		coins = ns.TierAmount(ns.COINS_EVENT, k),
		tickets = momentTickets(ns.TierTickets(k)),
	}
end

--- The moment for a completed run of `event` (HNT-R86). No `cast`: the caller adds it.
---@param event HuntEvent
---@return PagleMoment
function ns.WagerSettledMoment(event)
	local L = ns.L
	return {
		rung = "toast.high",
		kind = "wagerSettled",
		title = L.WAGER_SETTLED,
		text = ns.events:EventName(event),
		stamp = L.WAGER_SETTLED_STAMP,
		icon = ns.EventMomentIcon(event),
		coins = ns.COINS_RUN,
		tickets = momentTickets(ns.TICKETS_RUN),
	}
end

--- The moment for a ladder step's title (HNT-R86): a banner like a set title's, with no Coins (HNT-R110). No `cast`:
--- the caller adds it.
---@param step integer
---@return PagleMoment
function ns.WagerTitleMoment(step)
	local L = ns.L
	return {
		rung = "banner",
		kind = "wagerTitle",
		title = L.TITLE_EARNED,
		text = ns.LadderTitle(step),
		stamp = L.TITLE_EARNED_STAMP,
		icon = ns.HuntMomentIcon(nil), -- no Catch: Trade_Fishing (HNT-R55)
		seal = "quill", -- the banner's wax seal (announcements.md › Contracts)
	}
end

--- Whether `run` ended more than 30 days (Tunables) before `now` (HNT-R92): nothing is raised for it any more, and
--- what it earned counts in the totals only.
---@param run HuntRun
---@param now integer
---@return boolean
function ns.RunLongEnded(run, now)
	return now - run.end_ > ns.CELEBRATED_RUN_KEEP
end

-- The event Hunt with this ID, or nil.
---@param event HuntEvent
---@param id string
---@return HuntEventHunt?
local function eventHunt(event, id)
	for _, hunt in ipairs(event.hunts) do
		if hunt.id == id then
			return hunt
		end
	end
	return nil
end

--- The moment for `wager` over `state` (HNT-R86), or nil for a run whose event `state` doesn't know. No `cast` or
--- `summaryOnly`: the caller adds them.
---@param state HuntsState
---@param wager HuntsWager
---@return PagleMoment?
function ns.WagerMoment(state, wager)
	if wager.kind == "ladder" then
		return ns.WagerTitleMoment(wager.step)
	end
	local run = state.runs[wager.run]
	local event = run and ns.KnownEvent(state, run.event)
	if not event then
		return nil
	elseif wager.kind == "settled" then
		return ns.WagerSettledMoment(event)
	end
	local hunt, progress = eventHunt(event, wager.hunt), run.hunts[wager.hunt]
	local huntTier = progress and progress.reached[wager.tier]
	return hunt and huntTier and ns.WagerMarkMoment(hunt, wager.tier, huntTier) or nil
end

--- Whether `wager` is already in the celebrated set (HNT-R90): a mark at or below its run's tier for that Hunt, a
--- settled run already shown, a ladder title already shown.
---@param celebrated HuntsCelebrated
---@param wager HuntsWager
---@return boolean
function ns.WagerCelebrated(celebrated, wager)
	if wager.kind == "ladder" then
		return celebrated.ladder[wager.step] == true
	end
	local entry = celebrated.runs[wager.run]
	if not entry then
		return false
	elseif wager.kind == "mark" then
		return (entry.tiers[wager.hunt] or 0) >= wager.tier
	end
	return entry.settled == true
end

--- Adds `wagers` to the celebrated set, never lowering a Hunt's tier (HNT-R90): a run's entry is made with the run's
--- end as `endsAt` (HNT-R92).
---@param celebrated HuntsCelebrated
---@param state HuntsState
---@param wagers HuntsWager[]
function ns.CelebrateWagers(celebrated, state, wagers)
	for _, wager in ipairs(wagers) do
		if wager.kind == "ladder" then
			celebrated.ladder[wager.step] = true
		else
			local entry = celebrated.runs[wager.run]
			if not entry then
				entry = { tiers = {}, endsAt = state.runs[wager.run].end_ }
				celebrated.runs[wager.run] = entry
			end
			if wager.kind == "mark" then
				entry.tiers[wager.hunt] = math.max(entry.tiers[wager.hunt] or 0, wager.tier)
			else
				entry.settled = true
			end
		end
	end
end

--- What `state` holds above the celebrated set (HNT-R90), in order: for each known run (ns.RunsKnown's order), each
--- event Hunt's tiers above its celebrated one in file order, then its completion; then each ladder step earned and
--- not shown. With `now`, a run that ended more than 30 days before it has none (HNT-R92). A run whose celebrated
--- tier is above what the state holds (a rebuild that no longer finds it, HNT-R112) has none either.
---@param celebrated HuntsCelebrated
---@param state HuntsState
---@param now integer?
---@return HuntsWager[]
function ns.UncelebratedWagers(celebrated, state, now)
	local wagers = {}
	for _, on in ipairs(ns.RunsKnown(state)) do
		local run = on.run
		local event = not (now and ns.RunLongEnded(run, now)) and ns.KnownEvent(state, run.event)
		if event then
			local entry = celebrated.runs[on.key]
			for _, hunt in ipairs(event.hunts) do
				local progress = run.hunts[hunt.id]
				for k = (entry and entry.tiers[hunt.id] or 0) + 1, progress and #progress.reached or 0 do
					wagers[#wagers + 1] = { kind = "mark", run = on.key, hunt = hunt.id, tier = k }
				end
			end
			if run.completedAt and not (entry and entry.settled) then
				wagers[#wagers + 1] = { kind = "settled", run = on.key }
			end
		end
	end
	for _, step in ipairs(ns.LADDER_STEPS) do
		if state.ladder and state.ladder[step] and not celebrated.ladder[step] then
			wagers[#wagers + 1] = { kind = "ladder", step = step }
		end
	end
	return wagers
end

--- The wagers a live entry newly reached (HuntsRunsReached), in the order HNT-R86 raises them: its marks, then its
--- settled runs, then its ladder steps.
---@param reached HuntsRunsReached
---@return HuntsWager[]
function ns.ReachedWagers(reached)
	local wagers = {}
	for _, at in ipairs(reached.marks) do
		wagers[#wagers + 1] = { kind = "mark", run = at.run, hunt = at.hunt, tier = at.tier }
	end
	for _, key in ipairs(reached.settled) do
		wagers[#wagers + 1] = { kind = "settled", run = key }
	end
	for _, step in ipairs(reached.ladder) do
		wagers[#wagers + 1] = { kind = "ladder", step = step }
	end
	return wagers
end

--- The moments for the wagers a live entry newly reached (HNT-R86, HNT-R91, HNT-R149), each added to the celebrated
--- set; one already there raises nothing. A Cast's carry `castID`, so Core merges them into its Announcement
--- (ANN-R10). Without one (a `run` record crediting Casts late), they are summary-only, and with `now` a run that
--- ended more than 30 days before it raises nothing and isn't added (HNT-R92).
---@param celebrated HuntsCelebrated
---@param state HuntsState
---@param reached HuntsRunsReached
---@param castID string?
---@param now integer?
---@return PagleMoment[]
function ns.CelebrateWagersReached(celebrated, state, reached, castID, now)
	local moments = {}
	for _, wager in ipairs(ns.ReachedWagers(reached)) do
		local old = now and wager.run and ns.RunLongEnded(state.runs[wager.run], now)
		if not old and not ns.WagerCelebrated(celebrated, wager) then
			local moment = ns.WagerMoment(state, wager)
			if moment then
				if castID then
					moment.cast = castID
				else
					moment.summaryOnly = true
				end
				moments[#moments + 1] = moment
			end
			ns.CelebrateWagers(celebrated, state, { wager })
		end
	end
	return moments
end

--- The moments for `wagers`, summary-only and with no `cast` (HNT-R112, ANN-R63).
---@param state HuntsState
---@param wagers HuntsWager[]
---@return PagleMoment[]
function ns.SummaryOnlyWagers(state, wagers)
	local moments = {}
	for _, wager in ipairs(wagers) do
		local moment = ns.WagerMoment(state, wager)
		if moment then
			moment.summaryOnly = true
			moments[#moments + 1] = moment
		end
	end
	return moments
end

--- Drops the celebrated set's run entries whose run ended more than 30 days before `now` (HNT-R92), from `done`.
---@param celebrated HuntsCelebrated
---@param now integer
function ns.PruneCelebratedRuns(celebrated, now)
	for key, entry in pairs(celebrated.runs) do
		if now - entry.endsAt > ns.CELEBRATED_RUN_KEEP then
			celebrated.runs[key] = nil
		end
	end
end
