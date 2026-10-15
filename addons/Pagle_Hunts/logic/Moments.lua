if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- What the Angler is told about Hunts (HNT-R85–R87, HNT-R89–R91, HNT-R111, HNT-R112): a moment for each tier and set
-- title a live apply newly reaches, guarded by the celebrated set; the Write-up or summary-only moments from done;
-- and Hunts' line in the Session summary. Pure logic, everything passed in (CORE-R7): the projection's outlets
-- (logic/Projection.lua) and the redraws (logic/Seams.lua) reach it through `ns.moments`, which the adapter makes in
-- OnInitialize; the Hunt list (`ns.hunts`) is read at call time.

--- Where Hunts' moments, Write-up sections and summary line go, and what they read (HNT-R86, HNT-R89, HNT-R111).
---@class HuntsMomentsClient
---@field RaiseMoment fun(moment: PagleMoment)
---@field RaiseWriteUp fun(section: PagleWriteUpSection)
---@field SetSummaryLine fun(text: string)
---@field FormatNumber fun(n: integer): string
---@field ServerTime fun(): integer

--- The celebrated set (HNT-R90): each Hunt's highest tier already shown and each set title already shown.
---@class HuntsCelebrated
---@field tiers table<string, integer>
---@field sets table<string, true>

--- PagleHuntsDB.global.celebrated (HNT-R90, LOG-R77), its default from ns.DB_DEFAULTS (logic/Data.lua, the one place
--- each key gets one). Core never touches it; nothing here clears or lowers it.
---@param global table PagleHuntsDB's global section
---@return HuntsCelebrated
function ns.HuntsCelebrated(global)
	return global.celebrated
end

--- The moment for tier `k` of `hunt` (HNT-R86): its completion at tier 1, a further tier after; `huntTier` is the
--- HuntTier that reached it, whose Catch's item is the icon (HNT-R55). No `cast`: the caller adds it.
---@param hunt HuntDef
---@param k integer
---@param huntTier HuntTier
---@return PagleMoment
function ns.HuntTierMoment(hunt, k, huntTier)
	local L = ns.L
	local name = ns.hunts:HuntName(hunt.id)
	if k == 1 then
		return {
			rung = "toast.high",
			kind = "huntCompleted",
			title = L.HUNT_COMPLETE,
			text = name,
			stamp = L.HUNT_COMPLETE_STAMP,
			icon = ns.HuntMomentIcon(huntTier.itemID),
			coins = ns.COINS_COMPLETED,
		}
	end
	local trim = L.TRIMS[ns.Trim(k)]
	return {
		rung = "toast.high",
		kind = "huntTier",
		title = L.HUNT_TIER:format(trim),
		text = L.HUNT_TIER_TEXT:format(name, hunt.tiers[k]),
		stamp = trim,
		icon = ns.HuntMomentIcon(huntTier.itemID),
		coins = ns.COINS_TIER,
	}
end

--- The moment for a set's title (HNT-R86). No `cast` or `summaryOnly`: the caller adds them.
---@param setID string
---@return PagleMoment
function ns.HuntSetTitleMoment(setID)
	local L = ns.L
	return {
		rung = "banner",
		kind = "huntSetTitle",
		title = L.TITLE_EARNED,
		text = ns.hunts:SetTitle(setID),
		stamp = L.TITLE_EARNED_STAMP,
		icon = ns.HuntMomentIcon(nil), -- no Catch: Trade_Fishing (HNT-R55)
		coins = ns.COINS_TITLE,
	}
end

--- The moments for what a `"live"` Cast newly reached (HNT-R86, HNT-R87, HNT-R91), each added to the celebrated set:
--- a tier above the Hunt's celebrated one, or a title not yet shown. A tier and a title from a Catch carry the Cast's
--- entry ID, so Core merges them into its Announcement (ANN-R10); a title from a retirement is summary-only and
--- carries none.
---@param celebrated HuntsCelebrated
---@param state HuntsState
---@param cast PagleCast
---@param reached HuntsReached
---@return PagleMoment[]
function ns.CelebrateReached(celebrated, state, cast, reached)
	local moments = {}
	for _, at in ipairs(reached.tiers) do
		local hunt = ns.hunts:Hunt(at.hunt)
		if hunt and at.tier > (celebrated.tiers[at.hunt] or 0) then
			local moment = ns.HuntTierMoment(hunt, at.tier, state.hunts[at.hunt].reached[at.tier])
			moment.cast = cast.id
			moments[#moments + 1] = moment
			celebrated.tiers[at.hunt] = at.tier
		end
	end
	for _, setID in ipairs(reached.sets) do
		if not celebrated.sets[setID] then
			local moment = ns.HuntSetTitleMoment(setID)
			if state.sets[setID].fromRetirement then
				moment.summaryOnly = true
			else
				moment.cast = cast.id
			end
			moments[#moments + 1] = moment
			celebrated.sets[setID] = true
		end
	end
	return moments
end

--- What a Write-up section lists (HNT-R111): Hunts completed (tier 1), further tiers, the set titles in file order.
---@class HuntsWriteUpCounts
---@field completed integer
---@field further integer
---@field titles string[]

-- The Coins what `counts` lists paid (HNT-R110).
---@param counts HuntsWriteUpCounts
---@return integer
local function coinsOf(counts)
	return counts.completed * ns.COINS_COMPLETED + counts.further * ns.COINS_TIER + #counts.titles * ns.COINS_TITLE
end

-- A Write-up section's lines (HNT-R111): "{n} Hunts completed", "{n} further tiers", "Title: {title}" for each title,
-- "Pagle Coins +{n}"; each count only when above 0.
---@param counts HuntsWriteUpCounts
---@param coins integer
---@param format fun(n: integer): string
---@return string[]
local function writeUpLines(counts, coins, format)
	local L = ns.L
	local lines = {}
	if counts.completed > 0 then
		lines[#lines + 1] = ns.CountText(counts.completed, "WRITE_UP_COMPLETED", format)
	end
	if counts.further > 0 then
		lines[#lines + 1] = ns.CountText(counts.further, "WRITE_UP_FURTHER", format)
	end
	for _, setID in ipairs(counts.titles) do
		lines[#lines + 1] = L.WRITE_UP_TITLE:format(ns.hunts:SetTitle(setID))
	end
	if coins > 0 then
		lines[#lines + 1] = L.WRITE_UP_COINS:format(format(coins))
	end
	return lines
end

-- What the state holds above the celebrated set, in Hunt-list and set-file order (HNT-R90): each tier above its
-- Hunt's celebrated one, as `{ hunt, k }`, and each earned set title not yet shown. A Hunt whose celebrated tier is
-- above what the state holds (a rebuild that no longer finds it, HNT-R112) has none.
---@param celebrated HuntsCelebrated
---@param state HuntsState
---@return { hunt: HuntDef, k: integer }[] tiers
---@return string[] sets
local function uncelebrated(celebrated, state)
	local tiers, sets = {}, {}
	for _, hunt in ipairs(ns.hunts:Hunts()) do
		local progress = state.hunts[hunt.id]
		for k = (celebrated.tiers[hunt.id] or 0) + 1, progress and #progress.reached or 0 do
			tiers[#tiers + 1] = { hunt = hunt, k = k }
		end
	end
	for _, set in ipairs(ns.hunts:Sets()) do
		if state.sets[set.id] and not celebrated.sets[set.id] then
			sets[#sets + 1] = set.id
		end
	end
	return tiers, sets
end

-- Adds tiers and titles to the celebrated set, never lowering a Hunt's tier (HNT-R90).
---@param celebrated HuntsCelebrated
---@param tiers { hunt: HuntDef, k: integer }[]
---@param sets string[]
local function celebrate(celebrated, tiers, sets)
	for _, at in ipairs(tiers) do
		local id = at.hunt.id
		celebrated.tiers[id] = math.max(celebrated.tiers[id] or 0, at.k)
	end
	for _, setID in ipairs(sets) do
		celebrated.sets[setID] = true
	end
end

-- Counts tiers into a Write-up's completions and further tiers.
---@param tiers { hunt: HuntDef, k: integer }[]
---@param titles string[]
---@return HuntsWriteUpCounts
local function countsOf(tiers, titles)
	local counts = { completed = 0, further = 0, titles = titles }
	for _, at in ipairs(tiers) do
		if at.k == 1 then
			counts.completed = counts.completed + 1
		else
			counts.further = counts.further + 1
		end
	end
	return counts
end

-- Raises a summary-only moment for each tier and title (HNT-R112, ANN-R63): no pop-up and no `cast`.
---@param state HuntsState
---@param tiers { hunt: HuntDef, k: integer }[]
---@param sets string[]
---@param client HuntsMomentsClient
local function raiseSummaryOnly(state, tiers, sets, client)
	for _, at in ipairs(tiers) do
		local moment = ns.HuntTierMoment(at.hunt, at.k, state.hunts[at.hunt.id].reached[at.k])
		moment.summaryOnly = true
		client.RaiseMoment(moment)
	end
	for _, setID in ipairs(sets) do
		local moment = ns.HuntSetTitleMoment(setID)
		moment.summaryOnly = true
		client.RaiseMoment(moment)
	end
end

--- The projection's done (HNT-R111, HNT-R112, HNT-R190–R192), after the titles are checked: what is newly in the
--- state against the celebrated set, raised and then marked, never popping up (ANN-R4).
---   - first build: everything is marked, and one section headed by the Casts applied lists it, if anything was
---     earned (a fresh install, with no Cast, gets no first build at all, LOG-R76)
---   - a rebuild that isn't one: every new tier and title raised summary-only
---   - a catch-up: what the replayed entries earned in one "While Hunts was off" section, if anything; a title from a
---     retirement is raised summary-only instead
---@param celebrated HuntsCelebrated
---@param state HuntsState
---@param info PagleProjectionInfo
---@param client HuntsMomentsClient
function ns.CelebrateHuntsDone(celebrated, state, info, client)
	local L, format = ns.L, client.FormatNumber
	local tiers, sets = uncelebrated(celebrated, state)
	if info.firstBuild then
		-- Everything the state holds is written up, not only what is above a celebrated set kept from before.
		local all, titles = uncelebrated({ tiers = {}, sets = {} }, state)
		celebrate(celebrated, all, titles)
		if #all > 0 or #titles > 0 then
			client.RaiseWriteUp({
				heading = ns.CountText(state.casts, "WRITE_UP_FIRST_BUILD", format),
				lines = writeUpLines(countsOf(all, titles), state.coins, format),
			})
		end
	elseif info.rebuilt then
		raiseSummaryOnly(state, tiers, sets, client)
		celebrate(celebrated, tiers, sets)
	else
		-- A catch-up: titles from a retirement are summary-only, the rest go in the section (HNT-R87).
		local retired, titles = {}, {}
		for _, setID in ipairs(sets) do
			local list = state.sets[setID].fromRetirement and retired or titles
			list[#list + 1] = setID
		end
		raiseSummaryOnly(state, {}, retired, client)
		if #tiers > 0 or #titles > 0 then
			local counts = countsOf(tiers, titles)
			client.RaiseWriteUp({
				heading = L.WRITE_UP_WHILE_OFF,
				lines = writeUpLines(counts, coinsOf(counts), format),
			})
		end
		celebrate(celebrated, tiers, sets)
	end
end

--- Hunts' Session summary line (HNT-R89), with lifetime numbers: "Hunts: {done} of {current} done · {n} titles",
--- {current} the Hunts current at `now`, {done} those of them done, {n} the set titles earned.
---@param state HuntsState
---@param now integer
---@param format fun(n: integer): string
---@return string
function ns.HuntsSummaryLine(state, now, format)
	local L = ns.L
	local done, current = ns.DoneOfCurrent(ns.hunts, state, now)
	local titles = 0
	for _ in pairs(state.sets) do
		titles = titles + 1
	end
	return L.SUMMARY_LINE:format(format(done), format(current), ns.CountText(titles, "SUMMARY_TITLES", format))
end

---@class HuntsMoments
---@field line string? the summary line last set this login
---@field global table PagleHuntsDB's global section, whose `celebrated` it reads at each call
---@field client HuntsMomentsClient
local Moments = {}
Moments.__index = Moments

--- Hunts' moments over PagleHuntsDB's global section and `client`: what `ns.outlets` and the redraws call.
---@param global table
---@param client HuntsMomentsClient
---@return HuntsMoments
function ns.NewHuntsMoments(global, client)
	return setmetatable({ global = global, client = client }, Moments)
end

--- A `"live"` Cast newly reached tiers or titles (ns.outlets.Reached, HNT-R137 step 4).
---@param cast PagleCast
---@param reached HuntsReached
function Moments:Reached(cast, reached)
	local celebrated = ns.HuntsCelebrated(self.global)
	for _, moment in ipairs(ns.CelebrateReached(celebrated, ns.State(), cast, reached)) do
		self.client.RaiseMoment(moment)
	end
end

--- The projection finished a catch-up or rebuild (ns.outlets.Done, HNT-R111, HNT-R112).
---@param state HuntsState
---@param info PagleProjectionInfo
function Moments:Done(state, info)
	ns.CelebrateHuntsDone(ns.HuntsCelebrated(self.global), state, info, self.client)
	-- The first summary line after login (HNT-R89).
	self:SetSummaryLine(state)
end

--- Sets the summary line from `state` (HNT-R89), when its text changed since the last set this login.
---@param state HuntsState
function Moments:SetSummaryLine(state)
	local client = self.client
	local line = ns.HuntsSummaryLine(state, client.ServerTime(), client.FormatNumber)
	if line ~= self.line then
		self.line = line
		client.SetSummaryLine(line)
	end
end

--- A redraw (HNT-R42, ns.Redraw): the summary line follows it, but never while the projection is updating (HNT-R89).
function Moments:Redraw()
	if not ns.IsUpdating() then
		self:SetSummaryLine(ns.State())
	end
end

--- Hunts' moments, made in OnInitialize (adapter/Hunts.lua); nil while Hunts is inert.
---@class PagleHuntsNS
---@field moments HuntsMoments?

-- The projection's outlets (logic/Projection.lua) reach the moments made in OnInitialize, at call time.
---@param cast PagleCast
---@param reached HuntsReached
function ns.outlets.Reached(cast, reached)
	if ns.moments then
		ns.moments:Reached(cast, reached)
	end
end

---@param state HuntsState
---@param info PagleProjectionInfo
function ns.outlets.Done(state, info)
	if ns.moments then
		ns.moments:Done(state, info)
	end
end

-- The summary line is one of the views every redraw reaches (logic/Seams.lua).
ns.OnRedraw(function()
	if ns.moments then
		ns.moments:Redraw()
	end
end)
