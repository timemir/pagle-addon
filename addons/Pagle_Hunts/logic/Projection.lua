if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Hunts' one projection (HNT-R136–R138): the def it hands `M:NewProjection`, over the Catch log's Casts and Hunts' own
-- `run` and `def` records. Pure logic, everything passed in (CORE-R7); the Hunt list (`ns.hunts`), the event pool
-- (`ns.events`), where each Hunt bites (`ns.where`) and the outlets are read at call time. The state is hunts.md ›
-- Projection state (`HuntsState`, logic/Seams.lua); the runs' part of the fold is logic/Runs.lua.

--- Tunables (hunts.md): the Hunts rules version, which rises whenever a rule changes what the projection holds
--- (HNT-R138): 1 before Hunt Events, 2 with runs, Activity XP and the ladder (HNT-R136), 3 for the retuned Coins (HNT-R110, #412),
--- 4 with the Refreshes a run earns (HNT-R116).
ns.HUNTS_RULES_VERSION = 4

--- Tunables (hunts.md): the Coins paid when a Hunt completes, for each further tier, and for each set title
--- (HNT-R110).
ns.COINS_COMPLETED, ns.COINS_TIER, ns.COINS_TITLE = 30, 15, 100

--- What a `"live"` entry newly reached (HNT-R91): the Standing Hunts' tiers in Hunt-list order, each Hunt's
--- ascending, and the set titles in file order; then the runs' marks, completions and ladder steps
--- (HuntsRunsReached, logic/Runs.lua). A tier's HuntTier is `state.hunts[hunt].reached[tier]`; a title's record is
--- `state.sets[set]`. A `run` record reaches only runs' parts, for the Casts it credits late (HNT-R149).
---@class HuntsReached: HuntsRunsReached
---@field tiers { hunt: string, tier: integer }[]
---@field sets string[]

--- Where the projection hands what it found to Hunts' moments (logic/Moments.lua), which replaces each field; called
--- through `ns.outlets` at call time, so the replacement reaches the projection. Stand-ins: do nothing;
--- logic/Moments.lua replaces Reached, Credited and Done when it loads.
---   Reached(cast, reached)  after a `"live"` Cast that newly reached a tier, a set title, a mark, a completed run
---                           or a ladder step, before Coins and Activity XP are reported (HNT-R137 step 4)
---   Credited(record, reached) after a `"live"` `run` record whose earlier Casts reached a mark, a completed run or
---                           a ladder step (HNT-R149), before Coins and Activity XP are reported: the wager moments,
---                           summary-only (logic/WagerMoments.lua)
---   Done(state, info)       from `done`, after the titles are checked and Coins and Activity XP reported (HNT-R111,
---                           HNT-R112)
---   Diagnostic(line)        a dev diagnostic line: a logged or pushed definition that fails the in-game checks, or a
---                           pushed run that isn't one (HNT-R140, logic/Runs.lua, logic/RunLog.lua). Stand-in:
---                           nothing; Core has no dev-line call for Modules yet.
---   StepDue()               from `done`, last: the run log's live step is due, on a later frame (HNT-R151, HNT-R155,
---                           LOG-R40). Stand-in: nothing; adapter/RunLog.lua replaces it.
---   RefreshGoods()          after a `"live"` entry that earned a set title, completed a run or reached an event
---                           Hunt's tier in a run, and from `done`, after
---                           Done marks what it celebrates: `M:RefreshGoods()` for the earned goods (HNT-R122,
---                           SHOP-R31). Stand-in: nothing; adapter/Goods.lua replaces it.
ns.outlets = {
	---@param cast PagleCast
	---@param reached HuntsReached
	Reached = function(cast, reached) end, -- luacheck: no unused args
	---@param record PagleModuleRecord
	---@param reached HuntsReached
	Credited = function(record, reached) end, -- luacheck: no unused args
	---@param line string
	Diagnostic = function(line) end, -- luacheck: no unused args
	StepDue = function() end,
	RefreshGoods = function() end,
	---@param state HuntsState
	---@param info PagleProjectionInfo
	Done = function(state, info) end, -- luacheck: no unused args
}

--- What the projection reads besides the Hunt list: Qualify's lookups (`HuntsLookups`, logic/Qualify.lua), and the
--- log's records again (`M:IterateCatches`, LOG-R42), for a `run` record's earlier Casts (HNT-R149). What it does
--- outside its state: the Coins, Activity XP and Refresh reports (`M:ReportCoinsEarned`, SHOP-R2; `M:ReportXPEarned`,
--- AXP-R2; `M:ReportTicketsEarned`, REF-R2) and the server time `done` checks the set titles at (HNT-R23).
---@class HuntsProjectionClient
---@field ReportCoinsEarned fun(total: integer)
---@field ReportXPEarned fun(total: integer)
---@field ReportTicketsEarned fun(total: integer)
---@field IterateCatches (fun(afterSeq: integer): fun(): PagleRecord?)?
---@field ServerTime fun(): integer

--- A HuntsState before any Cast (hunts.md › Projection state).
---@return HuntsState
function ns.NewHuntsState()
	return {
		casts = 0,
		coins = 0,
		xp = 0,
		tickets = 0,
		runs = {},
		defs = {},
		settled = 0,
		ladder = {},
		hunts = {},
		sets = {},
		hours = {},
	}
end

--- Nothing reached yet (HuntsReached).
---@return HuntsReached
function ns.NewReached()
	return { tiers = {}, sets = {}, marks = {}, settled = {}, ladder = {} }
end

--- Whether `reached` holds anything (HuntsReached).
---@param reached HuntsReached
---@return boolean
function ns.AnyReached(reached)
	return #reached.tiers + #reached.sets + #reached.marks + #reached.settled + #reached.ladder > 0
end

-- Whether `cast` is an effort Cast for `hunt`, which exists at its time (HNT-R25): its snapshot matches the Hunt's
-- board spec (a natural Hunt's window spec, an imposed Hunt's conditions; an aura-only Hunt's is just its aura), and
-- it was fished in the Hunt's waters if it has any. A Hunt without a board spec has none (HNT-R7).
---@param hunt HuntDef
---@param cast PagleCast
---@param lookups HuntsLookups
---@return boolean
local function isEffort(hunt, cast, lookups)
	local spec = ns.where[hunt.id].boardSpec
	return spec ~= nil and lookups.MatchesConditions(spec, cast.conditions) and ns.InWaters(hunt, cast)
end

--- The Standing Hunts' Cast index (HNT-R139): the Hunt list's Hunts by what a Cast must have for one to change it
--- (where it was fished, what it caught, the auras it was under), so a Cast is tested only against Hunts that can
--- match it. Each bucket holds positions in `hunts`, ascending.
---@class HuntsCastIndex
---@field hunts HuntDef[]                         -- the Hunt list's Hunts, in list order
---@field always integer[]                        -- tested on every Cast: effort bound to no area
---@field byArea table<integer, integer[]>        -- the Cast's zone or subzone
---@field byItem table<integer, integer[]>        -- a caught item: a class target's members
---@field bySpecies table<integer, integer[]>     -- a caught item's Species: a Species target
---@field byAura table<integer, integer[]>        -- an aura the Cast was under

-- Adds position `i` to `index[key]`, once: positions arrive ascending, so a repeat is the bucket's last.
---@param index table<integer, integer[]>
---@param key integer
---@param i integer
local function file(index, key, i)
	local bucket = index[key]
	if not bucket then
		index[key] = { i }
	elseif bucket[#bucket] ~= i then
		bucket[#bucket + 1] = i
	end
end

-- Files position `i` under each of `keys`.
---@param index table<integer, integer[]>
---@param keys integer[]
---@param i integer
local function fileAll(index, keys, i)
	for _, key in ipairs(keys) do
		file(index, key, i)
	end
end

-- Files the Hunt at position `i` by its effort apart from its Catches: effort (isEffort) by its waters (ns.InWaters),
-- or for an imposed Hunt without waters by its board spec's `areas` or else in `always`, and none for a Hunt with no
-- board spec or a natural Hunt with no waters; a qualifying Catch (ns.MatchingCatches) by its target, its Species
-- (read first, as isTarget does) or its class's members (an unknown class has none).
---@param index HuntsCastIndex
---@param hunt HuntDef
---@param bites HuntWhere
---@param i integer
---@param lookups HuntsLookups
local function fileByEffortAndTarget(index, hunt, bites, i, lookups)
	local spec = bites.boardSpec
	if spec ~= nil then
		if #bites.waters > 0 then
			fileAll(index.byArea, bites.waters, i)
		elseif hunt.kind ~= "natural" then
			if spec.areas then
				fileAll(index.byArea, spec.areas, i)
			else
				index.always[#index.always + 1] = i
			end
		end
	end
	if hunt.species then
		file(index.bySpecies, hunt.species, i)
	elseif hunt.class then
		for itemID in pairs(lookups.Class(hunt.class) or {}) do
			file(index.byItem, itemID, i)
		end
	end
end

--- The Cast index over `list` (HNT-R139), from where each Hunt bites (`where`, ns.NewWhere) and the class members
--- (`lookups.Class`), once per load. It files each Hunt under what a Cast must have for HNT-R25 or HNT-R10 to let the
--- Hunt change it:
--- - an imposed Hunt whose conditions (HNT-R5) and board spec (HNT-R6) both name `auras`, or both `areas`: one of
---   those (LOG-R48's matchers), since its conditions gate its Catches and its board spec its effort;
--- - any other Hunt by its effort and by its target, apart (fileByEffortAndTarget).
--- A Hunt a Cast finds under none of its keys fails both tests, so the Cast leaves its progress as it was.
---@param list HuntList
---@param where table<string, HuntWhere>
---@param lookups HuntsLookups
---@return HuntsCastIndex
function ns.NewCastIndex(list, where, lookups)
	local index = { hunts = list:Hunts(), always = {}, byArea = {}, byItem = {}, bySpecies = {}, byAura = {} }
	for i, hunt in ipairs(index.hunts) do
		local bites = where[hunt.id]
		local spec = bites.boardSpec
		local gate = hunt.kind == "imposed" and hunt.conditions or nil
		if spec and gate and gate.auras and spec.auras then
			fileAll(index.byAura, gate.auras, i)
			fileAll(index.byAura, spec.auras, i)
		elseif spec and gate and gate.areas and spec.areas then
			fileAll(index.byArea, gate.areas, i)
			fileAll(index.byArea, spec.areas, i)
		else
			fileByEffortAndTarget(index, hunt, bites, i, lookups)
		end
	end
	return index
end

-- Adds a bucket's positions not yet `seen` to `picked`.
---@param seen table<integer, true>
---@param picked integer[]
---@param bucket integer[]?
local function take(seen, picked, bucket)
	if not bucket then
		return
	end
	for _, i in ipairs(bucket) do
		if not seen[i] then
			seen[i] = true
			picked[#picked + 1] = i
		end
	end
end

--- The Standing Hunts `cast` may change, in Hunt-list order, each once (HNT-R139): those of `index.always`, those
--- filed under the Cast's zone, its subzone or an aura it was under, and, for a caught Cast, those filed under each
--- Catch's item or its item's Species (item 0 matches nothing, HNT-R196). No other Hunt can change the Cast's fold.
---@param index HuntsCastIndex
---@param cast PagleCast
---@param lookups HuntsLookups
---@return HuntDef[]
function ns.CastHunts(index, cast, lookups)
	local seen, picked = {}, {}
	take(seen, picked, index.always)
	local conditions = cast.conditions
	take(seen, picked, index.byArea[conditions.zone])
	take(seen, picked, index.byArea[conditions.subzone])
	if conditions.auras then
		for _, aura in ipairs(conditions.auras) do
			take(seen, picked, index.byAura[aura])
		end
	end
	if cast.outcome == "caught" then
		for _, catch in ipairs(cast.items) do
			local itemID = catch.itemID
			if itemID ~= 0 then
				take(seen, picked, index.byItem[itemID])
				local item = lookups.GetItem(itemID)
				if item and item.species then
					take(seen, picked, index.bySpecies[item.species])
				end
			end
		end
	end
	table.sort(picked)
	local out = {}
	for k, i in ipairs(picked) do
		out[k] = index.hunts[i]
	end
	return out
end

-- The Cast index ns.HuntsToTest last built, and the Hunt list, where and lookups it was built over.
---@type { list: HuntList, where: table<string, HuntWhere>, lookups: HuntsLookups, index: HuntsCastIndex }?
local built

--- The Standing Hunts ApplyCast tests `cast` against (HNT-R139): ns.CastHunts over the Cast index of `ns.hunts`,
--- `ns.where` and `lookups`, built the first time a Cast needs it and again only when one of them is replaced (a new
--- load, the tour's sample list). Read through `ns` at call time, so a spec can hand back every Hunt instead.
---@param cast PagleCast
---@param lookups HuntsLookups
---@return HuntDef[]
function ns.HuntsToTest(cast, lookups)
	local list, where = ns.hunts, ns.where
	if not (built and built.list == list and built.where == where and built.lookups == lookups) then
		built = { list = list, where = where, lookups = lookups, index = ns.NewCastIndex(list, where, lookups) }
	end
	return ns.CastHunts(built.index, cast, lookups)
end

--- Applies one Cast to `state` (HNT-R137 steps 1–3): its count of Casts (and the hour index, logic/Runs.lua); for
--- every Standing Hunt that exists at its time and may change it (HNT-R139), then the event Hunts of each known run on
--- at its time (HNT-R144), the effort counter, then its qualifying Catches in loot-slot order (count, tiers, Coins,
--- Activity XP); then the set titles at its time, each run on for completion and the ladder. Returns what it newly
--- reached.
---@param state HuntsState
---@param cast PagleCast
---@param lookups HuntsCoreLookups
---@return HuntsReached
function ns.ApplyCast(state, cast, lookups)
	local reached = ns.NewReached()
	state.casts = state.casts + 1
	ns.NoteCastHour(state, cast)
	-- Only the Standing Hunts the Cast can change: the rest would leave their progress as it was (HNT-R139).
	for _, hunt in ipairs(ns.HuntsToTest(cast, lookups)) do
		-- Casts before its since or from its retired on don't count (HNT-R2, HNT-R13).
		if ns.Exists(hunt, cast.time) then
			local progress = state.hunts[hunt.id] or ns.NewHuntProgress()
			-- The effort counter first (HNT-R25, HNT-R26).
			if isEffort(hunt, cast, lookups) then
				progress.effort = progress.effort + 1
				progress.sinceLast = progress.sinceLast + 1
			end
			-- Then its qualifying Catches (HNT-R11, HNT-R15).
			local count = progress.count
			for _, k in ipairs(ns.CountCatches(progress, hunt, cast, lookups)) do
				state.coins = state.coins + (k == 1 and ns.COINS_COMPLETED or ns.COINS_TIER)
				state.xp = state.xp + ns.TierAmount(ns.XP_STANDING, k) -- Retired Hunts' too, once each (HNT-R113)
				reached.tiers[#reached.tiers + 1] = { hunt = hunt.id, tier = k }
			end
			-- A Cast holding a qualifying Catch resets the second number, after it was counted (HNT-R26).
			if progress.count > count then
				progress.sinceLast = 0
			end
			-- A Hunt has an entry once it has effort or a Catch (hunts.md › Projection state).
			if progress.effort > 0 or progress.count > 0 then
				state.hunts[hunt.id] = progress
			end
		end
	end
	-- The event Hunts of each known run on at the Cast's time, by the Cast entry's server time alone (HNT-R144).
	local on = ns.RunsOnAt(state, cast.time)
	local events = {}
	for i, run in ipairs(on) do
		events[i] = ns.KnownEvent(state, run.run.event, lookups) or false
		if events[i] then
			ns.CreditRunCast(state, run, events[i], cast, lookups, reached)
		end
	end
	-- The set titles, up to the Cast's time (HNT-R23).
	for _, setID in ipairs(ns.CheckTitles(state, cast.time, cast.time)) do
		state.coins = state.coins + ns.COINS_TITLE
		reached.sets[#reached.sets + 1] = setID
	end
	-- Then each run on for completion, and the ladder (HNT-R146, HNT-R148).
	for i, run in ipairs(on) do
		if events[i] then
			ns.SettleRun(state, run, events[i], reached)
		end
	end
	return reached
end

--- What Hunts hands Core as its projection's extraFingerprint (LOG-R70, HNT-R136): the Hunt list's fingerprint joined
--- with the event pool's, `<hunt list>+<event pool>`, so a new Hunt list or pool rebuilds (DATA-R72, DATA-R98,
--- LOG-R72). scripts/read-wtf.lua checks the stored one against it.
---@param list HuntList
---@param events EventListData? ns.eventList (DATA-R98); nil reads as no pool
---@return string
function ns.HuntsExtraFingerprint(list, events)
	return tostring(list:Fingerprint()) .. "+" .. tostring(events and events.fingerprint)
end

--- Hunts' projection for Pagle's backend (#223, #76 item 5), whose projection driver folds the Catch log through
--- logic/ alone, without adapter/ or locale/ (CORE-R7). Makes the Hunt list, Qualify's lookups, where each Hunt
--- bites and the event pool as the adapter's OnInitialize does (ns.hunts, ns.lookups, ns.where, ns.events), then binds
--- ns.ProjectionDef with `M:NewProjection` over a table of its own making, reading the log back through
--- `M:IterateCatches` as the client does. Coins, Activity XP and Refreshes aren't reported (the driver reads
--- ns.CoinsEarned, ns.ActivityXPEarned and ns.TicketsEarned), and `done` checks the set titles at GetServerTime(), which the driver answers with its fold's
--- time. Without locale/, the Hunt list has no text, which the fold never reads. The client's adapter never calls it.
---@param M PagleModuleHandle
---@return PagleProjection
function ns.BindProjections(M)
	-- The driver hands over only M, so Core comes from the Pagle API it hosts, and the time from its GetServerTime.
	local pagle = Pagle -- luacheck: read globals Pagle (#223: the backend's driver passes no Core)
	ns.hunts = ns.NewHuntList(ns.huntList, ns.L)
	ns.lookups = ns.NewLookups(pagle, ns.hunts)
	ns.where = ns.NewWhere(ns.hunts, ns.lookups)
	ns.events = ns.NewEventList(ns.eventList, ns.L, ns.lookups)
	return M:NewProjection(ns.ProjectionDef({}, ns.lookups, {
		ReportCoinsEarned = function() end,
		ReportXPEarned = function() end,
		ReportTicketsEarned = function() end,
		IterateCatches = function(afterSeq)
			return M:IterateCatches(afterSeq)
		end,
		ServerTime = function()
			return GetServerTime() -- luacheck: read globals GetServerTime (#223: the driver's fold time)
		end,
	}))
end

--- A Hunts state's lifetime Coins earned (SHOP-R2, HNT-R110), as Hunts reports them with M:ReportCoinsEarned: for
--- Pagle's backend (#223), read after done.
---@param state HuntsState
---@return integer
function ns.CoinsEarned(state)
	return state.coins
end

--- A Hunts state's lifetime Activity XP (HNT-R113–R115, AXP-R2), as Hunts reports it with M:ReportXPEarned: for
--- Pagle's backend (AXP-R9, #76 item 15), which sums it with the other paying Modules' into the Ledger's `total`.
---@param state HuntsState
---@return integer
function ns.ActivityXPEarned(state)
	return state.xp
end

--- A Hunts state's lifetime Refreshes earned (HNT-R116, REF-R2, REF-R9), as Hunts reports them with
--- M:ReportTicketsEarned: for Pagle's backend, read after done.
---@param state HuntsState
---@return integer
function ns.TicketsEarned(state)
	return state.tickets
end

---@class HuntsJournalHunt
---@field id string
---@field set string
---@field current boolean    -- it exists now (HNT-R2)
---@field retired boolean    -- its retired date has come (HNT-R3)
---@field tiers integer[]
---@field trim integer       -- its highest reached tier's trim: 0 none, 1 bronze, 2 silver, 3 gold (HNT-R18)
---@field target { kind: string, items: integer[], minBand: integer? } -- "species", "fixed" or a generated class's ID

--- Hunts' Journal values for Pagle's backend (#223, the Angler page's Journal values) at GetServerTime(), the driver's
--- fold time:
--- - `hunts`: every Hunt of the list that exists now or has a reached tier, in list order (HNT-R2, HNT-R3, HNT-R15,
---   HNT-R17, HNT-R18, HNT-R54);
--- - `sets`: every set in list order, with its Hunts current now and how many of those are done (HNT-R17, HNT-R20);
--- - `ladder`: the Pagle Wagers ladder's marks in step order (ns.LADDER_STEPS), each with whether its title is earned
---   in the state, never lost (HNT-R148, HNT-R178), as the spread's ladder inks it (ns.BuildWagersLadder, HNT-R162).
--- Reads the Hunt list ns.BindProjections (or the adapter) made.
---@param state HuntsState
---@param sessionRows integer
---@return { hunts: HuntsJournalHunt[], sets: { id: string, hunts: integer, done: integer }[], ladder: { step: integer, earned: boolean }[] }
function ns.JournalValues(state, sessionRows) -- luacheck: no unused args (the driver's one shape for every Module)
	local now = GetServerTime() -- luacheck: read globals GetServerTime (#223: the driver's fold time)
	local list = ns.hunts
	local hunts = {}
	for _, hunt in ipairs(list:Hunts()) do
		local progress = state.hunts[hunt.id]
		local reached = progress and #progress.reached or 0
		if ns.Exists(hunt, now) or reached > 0 then
			local target
			if hunt.species then
				target = { kind = "species", items = { hunt.species } }
			elseif ns.GENERATED_CLASSES[hunt.class] then
				target = { kind = hunt.class, items = {} }
			else
				target = { kind = "fixed", items = ns.HuntClassMembers(hunt, list) }
			end
			target.minBand = hunt.minBand
			local tiers = {}
			for i, tier in ipairs(hunt.tiers) do
				tiers[i] = tier
			end
			hunts[#hunts + 1] = {
				id = hunt.id,
				set = hunt.set,
				current = ns.IsCurrent(hunt, now),
				retired = ns.IsRetired(hunt, now),
				tiers = tiers,
				trim = math.min(reached, 3),
				target = target,
			}
		end
	end
	local sets = {}
	for _, set in ipairs(list:Sets()) do
		local done, current = ns.DoneOfCurrent(list, state, now, set.id)
		sets[#sets + 1] = { id = set.id, hunts = current, done = done }
	end
	local ladder = {}
	for i, step in ipairs(ns.LADDER_STEPS) do
		ladder[i] = { step = step, earned = state.ladder[step] ~= nil }
	end
	return { hunts = hunts, sets = sets, ladder = ladder }
end

--- Hunts' projection def (HNT-R136, LOG-R70), bound to `global.projection`, which it makes if missing: Core owns it
--- from here on. `apply` reads Casts and Hunts' own `run` and `def` records (logic/Runs.lua); every other kind is
--- ignored. A `"live"` entry hands what it newly reached to `ns.outlets.Reached` (a Cast) or `ns.outlets.Credited` (a
--- `run` record), reports Coins and Activity XP if they changed (HNT-R110, HNT-R115) and redraws the views (HNT-R42);
--- a `"replay"` or `"rebuild"` one only changes the state, which `done` then reads and reports.
---@param global table PagleHuntsDB's global section
---@param lookups HuntsCoreLookups
---@param client HuntsProjectionClient
---@return PagleProjectionDef
function ns.ProjectionDef(global, lookups, client)
	if type(global.projection) ~= "table" then
		global.projection = {}
	end
	-- Notes each earned good whose rule now holds in the celebrated set (HNT-R122), when there is one to note in (the
	-- backend's driver binds no saved DB).
	---@param state HuntsState
	local function noteGoods(state)
		local celebrated = global.celebrated
		if type(celebrated) == "table" then
			ns.NoteHuntsGoods(celebrated, state, ns.hunts:Sets())
		end
	end
	return {
		db = global.projection,
		rulesVersion = ns.HUNTS_RULES_VERSION,
		extraFingerprint = ns.HuntsExtraFingerprint(ns.hunts, ns.eventList),
		reset = ns.NewHuntsState,
		---@param state HuntsState
		---@param record PagleRecord
		---@param mode PagleApplyMode
		apply = function(state, record, mode)
			local coins, xp, tickets = state.coins, state.xp, state.tickets
			local live = mode == "live"
			-- HNT-R137 step 4, live only: the moments for what is newly reached, then Coins and Activity XP if they
			-- changed. A replay or rebuild only changes the state, which done reads after.
			local reached
			if record.kind == "cast" then
				---@cast record PagleCast
				-- A replayed Cast may fall in a fallback slot nobody logged: the run log's next step logs it (HNT-R155).
				if mode == "replay" then
					ns.NoteReplayedCast(record.time)
				end
				reached = ns.ApplyCast(state, record, lookups)
				if live and ns.AnyReached(reached) then
					ns.outlets.Reached(record, reached)
				end
			elseif record.kind == "module" then
				---@cast record PagleModuleRecord
				reached = ns.ApplyRunRecord(state, record, lookups, client.IterateCatches)
				if live and reached and ns.AnyReached(reached) then
					ns.outlets.Credited(record, reached)
				end
			end
			-- A record that changed nothing.
			if not reached or not live then
				return
			end
			if state.coins ~= coins then
				client.ReportCoinsEarned(state.coins)
			end
			if state.xp ~= xp then
				client.ReportXPEarned(state.xp)
			end
			if state.tickets ~= tickets then
				client.ReportTicketsEarned(state.tickets)
			end
			-- A set title, a completed run or an event Hunt's tier in a run may earn a good (HNT-R122), noted once its rule
			-- holds.
			if #reached.sets + #reached.settled + #reached.marks > 0 then
				noteGoods(state)
				ns.outlets.RefreshGoods()
			end
			-- A Cast always changes the state (its count of Casts at least), and so does a record folded.
			ns.Redraw("projection")
		end,
		---@param state HuntsState
		---@param info PagleProjectionInfo
		done = function(state, info)
			-- Titles a retirement completed since the last Cast applied (HNT-R23, HNT-R197).
			for _ in ipairs(ns.CheckTitles(state, client.ServerTime())) do
				state.coins = state.coins + ns.COINS_TITLE
			end
			client.ReportCoinsEarned(state.coins) -- after every catch-up or rebuild (HNT-R110, SHOP-R2)
			client.ReportXPEarned(state.xp) -- on the same timing (HNT-R115, AXP-R2)
			client.ReportTicketsEarned(state.tickets) -- and the Refreshes (HNT-R116, REF-R2)
			ns.outlets.Done(state, info)
			noteGoods(state)
			ns.outlets.RefreshGoods() -- the earned goods, never mid-catch-up or mid-rebuild (HNT-R122, SHOP-R31)
			ns.Redraw("projection")
			-- The run log's step, never from here (LOG-R40): what this catch-up or rebuild leaves to log (HNT-R151).
			ns.outlets.StepDue()
		end,
	}
end
