if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Hunts' one projection (HNT-R136–R138): the def it hands `M:NewProjection`, over the Catch log's Casts. Pure logic,
-- everything passed in (CORE-R7); the Hunt list (`ns.hunts`), where each Hunt bites (`ns.where`) and the outlets are
-- read at call time. The state is hunts.md › Projection state (`HuntsState`, logic/Seams.lua).

--- Tunables (hunts.md): the Hunts rules version, which rises whenever a rule changes what the projection holds
--- (HNT-R138). Not bumped within M5.
ns.HUNTS_RULES_VERSION = 1

--- Tunables (hunts.md): the Coins paid when a Hunt completes, for each further tier, and for each set title
--- (HNT-R110).
ns.COINS_COMPLETED, ns.COINS_TIER, ns.COINS_TITLE = 30, 15, 100

--- What a `"live"` Cast newly reached (HNT-R91): the tiers in Hunt-list order, each Hunt's ascending, and the set
--- titles in file order. A tier's HuntTier is `state.hunts[hunt].reached[tier]`; a title's record is
--- `state.sets[set]`.
---@class HuntsReached
---@field tiers { hunt: string, tier: integer }[]
---@field sets string[]

--- Where the projection hands what it found to Hunts' moments (logic/Moments.lua), which replaces each field; called
--- through `ns.outlets` at call time, so the replacement reaches the projection. Stand-ins: do nothing;
--- logic/Moments.lua replaces both when it loads.
---   Reached(cast, reached)  after a `"live"` Cast that newly reached a tier or a set title, before Coins are
---                           reported (HNT-R137 step 4)
---   Done(state, info)       from `done`, after the titles are checked and Coins reported (HNT-R111, HNT-R112)
ns.outlets = {
	---@param cast PagleCast
	---@param reached HuntsReached
	Reached = function(cast, reached) end, -- luacheck: no unused args
	---@param state HuntsState
	---@param info PagleProjectionInfo
	Done = function(state, info) end, -- luacheck: no unused args
}

--- What the projection reads besides the Hunt list: Qualify's lookups (`HuntsLookups`, logic/Qualify.lua).
--- What it does outside its state: the Coins report (`M:ReportCoinsEarned`, SHOP-R2) and the server time `done`
--- checks the set titles at (HNT-R23).
---@class HuntsProjectionClient
---@field ReportCoinsEarned fun(total: integer)
---@field ServerTime fun(): integer

--- A HuntsState before any Cast (hunts.md › Projection state).
---@return HuntsState
function ns.NewHuntsState()
	return { casts = 0, coins = 0, hunts = {}, sets = {} }
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

--- Applies one Cast to `state` (HNT-R137 steps 1–3): its count of Casts; for every Hunt that exists at its time, the
--- effort counter, then its qualifying Catches in loot-slot order (count, tiers, Coins); then the set titles at its
--- time. Returns what it newly reached.
---@param state HuntsState
---@param cast PagleCast
---@param lookups HuntsLookups
---@return HuntsReached
function ns.ApplyCast(state, cast, lookups)
	local reached = { tiers = {}, sets = {} }
	state.casts = state.casts + 1
	for _, hunt in ipairs(ns.hunts:Hunts()) do
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
	-- The set titles, up to the Cast's time (HNT-R23).
	for _, setID in ipairs(ns.CheckTitles(state, cast.time, cast.time)) do
		state.coins = state.coins + ns.COINS_TITLE
		reached.sets[#reached.sets + 1] = setID
	end
	return reached
end

--- What Hunts hands Core as its projection's extraFingerprint (LOG-R70): the Hunt list's fingerprint, so a new Hunt
--- list rebuilds (DATA-R72, LOG-R72). scripts/read-wtf.lua checks the stored one against it.
---@param list HuntList
---@return string?
function ns.HuntsExtraFingerprint(list)
	return list:Fingerprint()
end

--- Hunts' projection for Pagle's backend (#223, #76 item 5), whose projection driver folds the Catch log through
--- logic/ alone, without adapter/ or locale/ (CORE-R7). Makes the Hunt list, Qualify's lookups and where each Hunt
--- bites as the adapter's OnInitialize does (ns.hunts, ns.lookups, ns.where), then binds ns.ProjectionDef with
--- `M:NewProjection` over a table of its own making. Coins aren't reported (the driver reads ns.CoinsEarned instead),
--- and `done` checks the set titles at GetServerTime(), which the driver answers with its fold's time. Without
--- locale/, the Hunt list has no text, which the fold never reads. The client's adapter never calls it.
---@param M PagleModuleHandle
---@return PagleProjection
function ns.BindProjections(M)
	-- The driver hands over only M, so Core comes from the Pagle API it hosts, and the time from its GetServerTime.
	local pagle = Pagle -- luacheck: read globals Pagle (#223: the backend's driver passes no Core)
	ns.hunts = ns.NewHuntList(ns.huntList, ns.L)
	ns.lookups = ns.NewLookups(pagle, ns.hunts)
	ns.where = ns.NewWhere(ns.hunts, ns.lookups)
	return M:NewProjection(ns.ProjectionDef({}, ns.lookups, {
		ReportCoinsEarned = function() end,
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
--- - `sets`: every set in list order, with its Hunts current now and how many of those are done (HNT-R17, HNT-R20).
--- Reads the Hunt list ns.BindProjections (or the adapter) made.
---@param state HuntsState
---@param sessionRows integer
---@return { hunts: HuntsJournalHunt[], sets: { id: string, hunts: integer, done: integer }[] }
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
	return { hunts = hunts, sets = sets }
end

--- Hunts' projection def (HNT-R136, LOG-R70), bound to `global.projection`, which it makes if missing: Core owns it
--- from here on. `apply` reads only Casts (Hunts appends no records). A `"live"` Cast hands what it newly reached to
--- `ns.outlets.Reached`, reports Coins if they changed (HNT-R110) and redraws the views (HNT-R42); a `"replay"` or
--- `"rebuild"` one only changes the state, which `done` then reads.
---@param global table PagleHuntsDB's global section
---@param lookups HuntsLookups
---@param client HuntsProjectionClient
---@return PagleProjectionDef
function ns.ProjectionDef(global, lookups, client)
	if type(global.projection) ~= "table" then
		global.projection = {}
	end
	return {
		db = global.projection,
		rulesVersion = ns.HUNTS_RULES_VERSION,
		extraFingerprint = ns.HuntsExtraFingerprint(ns.hunts),
		reset = ns.NewHuntsState,
		---@param state HuntsState
		---@param record PagleRecord
		---@param mode PagleApplyMode
		apply = function(state, record, mode)
			if record.kind ~= "cast" then
				return
			end
			---@cast record PagleCast
			local coins = state.coins
			local reached = ns.ApplyCast(state, record, lookups)
			if mode ~= "live" then
				return
			end
			-- HNT-R137 step 4: the moments for what is newly reached, then Coins if they changed.
			if #reached.tiers > 0 or #reached.sets > 0 then
				ns.outlets.Reached(record, reached)
			end
			if state.coins ~= coins then
				client.ReportCoinsEarned(state.coins)
			end
			-- A Cast always changes the state: its count of Casts at least.
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
			ns.outlets.Done(state, info)
			ns.Redraw("projection")
		end,
	}
end
