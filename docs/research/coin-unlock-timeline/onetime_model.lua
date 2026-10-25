-- #396 copy of docs/research/coin-onetime-income/model.lua (branch research/coin-onetime-income, commit e5757f98, ticket #394).
-- Three changes, nothing else:
--   1. HOUR_MARKS is denser (0.25 h ... 3000 h) so the first hours and the long tail are not interpolated from 11 marks.
--   2. --activity-xp feeds the Ledger the Tackle Board goals' and Hunt Event runs' Activity XP per calendar day that #395
--      measured (ACTIVITY_XP_PER_DAY, from results.json ledger.*.activity_xp_per_day), per profile. #394's base run
--      assumed none. The Ledger's real fold turns it into levels and Prestige climbs.
--   3. (the path pattern for ROOT does not match here, so ROOT is "."): run from the repo root:
--        luajit docs/research/coin-unlock-timeline/onetime_model.lua --seeds 10 --hours 3000 --out <dir>
--        luajit docs/research/coin-unlock-timeline/onetime_model.lua --seeds 10 --hours 3000 --activity-xp --out <dir>
--      and copy <dir>/by_hour.csv to inputs/onetime_base_by_hour.csv / inputs/onetime_activity_by_hour.csv.
-- The rest of this file is #394's model unchanged; its own header follows.
-- Coin economy research, ticket #394 (map #393): how many Pagle Coins a simulated fisher earns from the ONE-TIME and
-- DISCOVERY sources (Ledger: level-ups, new Species, curios, trophy weights, Zone Mastery ranks, Legends, Prestige;
-- Hunts: Standing Hunts tier 1 / further tiers / set titles), by hours fished.
--
-- Run (from the repo root; LuaJIT, which has the `bit` library the Hunts logic needs):
--
--   luajit docs/research/coin-onetime-income/model.lua [--seeds N] [--hours H] [--out DIR]
--       [--only PROFILE[,PROFILE]] [--variant NAME[,NAME]|all] [--variant-seeds N]
--
-- It does not re-implement any payout. It loads the repo's OWN pure logic and folds a synthetic Catch stream through
-- it: the real catalogue (addons/Pagle/data/Catalogue.lua), the Ledger's fold (ns.NewLedgerFold, Prestige, Zone
-- Mastery, Legends, the climb and Fresh Water) and Hunts' projection (ns.ApplyCast, set titles), the way
-- scripts/make-test-log.lua does. Only the Catch stream is modelled: where the fisher fishes, when, and what drops
-- (data/baseline/area_loot.csv, read here exactly as scripts/pagle_data/propose_events.py reads it). Every modelling
-- assumption is listed in the ASSUMPTIONS block below and in FINDINGS.md.
--
-- Nothing here changes economy code or data.

local ROOT
do
	local here = (arg and arg[0] or ""):gsub("\\", "/")
	ROOT = here:match("^(.*)/docs/research/coin%-onetime%-income/model%.lua$") or "."
end

local OUT = ROOT .. "/docs/research/coin-onetime-income/results"
local SEEDS, HOURS, ONLY = 12, 1000, nil
local DEBUG_ZONES = false
-- #396: Activity XP of the Tackle Board goals and the Hunt Event runs, per calendar day and profile, from #395 (results.json,
-- ledger.*.activity_xp_per_day). Set by --activity-xp; nil in the #394 base run.
local BOARD_XP_BY_PROFILE = nil
local ACTIVITY_XP_PER_DAY = { casual = 877.04, dedicated = 1044.97, ["minmax_1.5h"] = 943.98, ["minmax_4h"] = 1055.94 }
local VARIANT_ARG, VARIANT_SEEDS = nil, 8
do
	local i = 1
	while arg and arg[i] do
		if arg[i] == "--seeds" then
			SEEDS = tonumber(arg[i + 1])
			i = i + 1
		elseif arg[i] == "--hours" then
			HOURS = tonumber(arg[i + 1])
			i = i + 1
		elseif arg[i] == "--out" then
			OUT = arg[i + 1]
			i = i + 1
		elseif arg[i] == "--variant" then
			VARIANT_ARG = arg[i + 1]
			i = i + 1
		elseif arg[i] == "--variant-seeds" then
			VARIANT_SEEDS = tonumber(arg[i + 1])
			i = i + 1
		elseif arg[i] == "--activity-xp" then
			BOARD_XP_BY_PROFILE = ACTIVITY_XP_PER_DAY
		elseif arg[i] == "--debug-zones" then
			DEBUG_ZONES = true
		elseif arg[i] == "--only" then
			ONLY = {}
			for name in arg[i + 1]:gmatch("[^,]+") do
				ONLY[name] = true
			end
			i = i + 1
		end
		i = i + 1
	end
end

---------------------------------------------------------------------------------------------------------------------
-- ASSUMPTIONS (everything the repo's code does not say). Each is a named constant so a sensitivity run can move it.
---------------------------------------------------------------------------------------------------------------------
local A = {
	CATCHES_PER_HOUR = 180, -- map Notes / #279: a design assumption, not measured. One Catch every 20 s.
	START = { 2026, 11, 5 }, -- Forever live release (5 Nov 2026); the sim's day 0, 00:00 realm time.
	-- Fishing skill rank (Ledger Skill Milestones 75/150/225/300 pay 1000 XP each, and zones have a skillBase):
	-- Catches needed per skill point in each 75-point band. Total 3,375 Catches = 18.75 h to 300. Not in the repo.
	SKILL_CATCHES_PER_POINT = { 3, 6, 12, 24 },
	SKILL_MOD = 30, -- lure + gear: a zone opens at rank >= skillBase - SKILL_MOD (so the 330 zones open at rank 300)
	STINT_CATCHES = 360, -- casual/dedicated stay in a zone for 2 h, then move on
	STINT_CATCHES_MINMAX = 60, -- the min-maxer re-plans every 20 min
	UNVISITED_WEIGHT = 3, -- casual route: an unvisited accessible zone is 3x as likely as a visited one
	-- Quest fish (area_loot rows with a negative chance, 5 Species): bite at |chance| only once the quest is taken.
	QUEST_TAKEN = { casual = 0.35, dedicated = 0.6, minmax = 1.0 },
	-- Camp Rack / Hut auras (Hunts "Camp Hours"): the share of sessions fished under them. Unknown in the repo.
	AURA_SESSIONS = { casual = 0.2, dedicated = 0.3, minmax = 1.0 },
	-- Stranglethorn Fishing Extravaganza (event 301, Sundays 14:00 realm time for 2 h; the three Legends and the
	-- Speckled Tastyfish come only from its School of Tastyfish pool, 0.2% each Legend, data/baseline/pool_loot.csv):
	-- chance that a given Sunday's session is the Extravaganza in Stranglethorn Vale, and the share of its Catches
	-- that come from a Tastyfish school (pools are finite and the fisher moves between them).
	EXTRAVAGANZA_ATTEND = { casual = 0.15, dedicated = 0.4, minmax = 1.0 },
	EXTRAVAGANZA_POOL_SHARE = { casual = 0.5, dedicated = 0.6, minmax = 0.9 },
	TOURNAMENT_ZONE = 33, -- Stranglethorn Vale
	TOURNAMENT_POOL = { { 19803, 0.2 }, { 19805, 0.2 }, { 19806, 0.2 }, { 19808, 0.2 }, { 19807, nil } }, -- % per catch
	-- The Ledger climb: Prestige as soon as level 60 is reached (XP past 60 is carried, so the timing only shifts
	-- coins, never loses XP).
	PRESTIGE_AT_60 = true,
	-- Sensitivity stand-in for the Tackle Board's Activity XP (a day of 3 tier-2 Notices at 150 and 1 Expedition at 600):
	-- 0 in the base run, which counts Hunts' Activity XP only.
	BOARD_XP_PER_DAY = 0,
}

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end
	return copy
end
local BASE_COPY = deepCopy(A)
-- Puts the base assumptions back (a variant moves some of them).
local function resetA()
	for k in pairs(A) do
		A[k] = nil
	end
	for k, v in pairs(deepCopy(BASE_COPY)) do
		A[k] = v
	end
end

local PROFILES = {
	{ name = "casual", hoursPerDay = 1.5, kind = "casual" },
	{ name = "dedicated", hoursPerDay = 4, kind = "dedicated" },
	{ name = "minmax_1.5h", hoursPerDay = 1.5, kind = "minmax" },
	{ name = "minmax_4h", hoursPerDay = 4, kind = "minmax" },
}

-- Price points to time: the shop's five tiers (Goods.lua TIER_PRICES), then round milestones up to the whole catalogue.
local THRESHOLDS = { 150, 400, 900, 2000, 5000, 10000, 20000, 40000, 86050 }
local HOUR_MARKS = { 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 5, 7.5, 10, 15, 20, 30, 40, 50, 75, 100, 150, 200, 250, 300, 400, 500, 750, 1000, 1500, 2000, 2500, 3000 }
local DAY_MARKS = { 1, 3, 7, 14, 30, 60, 100, 180, 365 }

---------------------------------------------------------------------------------------------------------------------
-- Loading the repo's logic.
---------------------------------------------------------------------------------------------------------------------
local wtf = setfenv(assert(loadfile(ROOT .. "/scripts/lib/wtf.lua")), getfenv(1))(ROOT)
local catalogue = assert(wtf.loadCatalogue())
local core = wtf.loadCore({ "locale/enUS.lua", "logic/Conditions.lua" })
local MatchesConditions = core.MatchesConditions
local ledger = wtf.loadLedgerLogic()
local world = ledger.NewWorld(catalogue)

local hunts
do
	local bit = assert(wtf.luaBitOp(), "no LuaBitOp")
	hunts = {}
	local env = setmetatable({ Pagle = {}, bit = bit }, { __index = _G })
	local dir = ROOT .. "/addons/Pagle_Hunts/"
	for _, file in ipairs(wtf.tocEntries("Pagle_Hunts")) do
		if file:match("^locale/[^/]+%.lua$") or file:match("^data/[^/]+%.lua$") or file:match("^logic/[^/]+%.lua$") then
			assert(wtf.loadInto(hunts, env, dir .. file, "Pagle_Hunts"))
		end
	end
	hunts.hunts = hunts.NewHuntList(hunts.HuntListFrom(hunts.huntList, nil), hunts.L)
	hunts.lookups = hunts.NewLookups({
		GetItem = catalogue.GetItem,
		GetZones = catalogue.GetZones,
		GetZoneCatches = catalogue.GetZoneCatches,
		GetZoneOf = catalogue.GetZoneOf,
		GetArea = catalogue.GetArea,
		GetWindowSpec = catalogue.GetWindowSpec,
		MatchesConditions = MatchesConditions,
	}, hunts.hunts)
	hunts.where = hunts.NewWhere(hunts.hunts, hunts.lookups)
	hunts.events = hunts.NewEventList(hunts.eventList, hunts.L, hunts.lookups)
end

local lookups = { GetItem = catalogue.GetItem, MatchesConditions = MatchesConditions, world = world }

---------------------------------------------------------------------------------------------------------------------
-- Calendar (realm time = server time in the sim).
---------------------------------------------------------------------------------------------------------------------
local function daysFromCivil(y, m, d)
	y = m <= 2 and y - 1 or y
	local era = math.floor(y / 400)
	local yoe = y - era * 400
	local doy = math.floor((153 * (m + (m > 2 and -3 or 9)) + 2) / 5) + d - 1
	local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
	return era * 146097 + doe - 719468
end

local function civilFromDays(z)
	z = z + 719468
	local era = math.floor(z / 146097)
	local doe = z - era * 146097
	local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
	local y = yoe + era * 400
	local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
	local mp = math.floor((5 * doy + 2) / 153)
	local d = doy - math.floor((153 * mp + 2) / 5) + 1
	local m = mp + (mp < 10 and 3 or -9)
	return m <= 2 and y + 1 or y, m, d
end

local START_DAY = daysFromCivil(A.START[1], A.START[2], A.START[3])

local EVENT_RULES = {}
for _, id in ipairs(catalogue.GetEventIDs()) do
	local rule = catalogue.GetEventRule(id)
	if rule then
		EVENT_RULES[#EVENT_RULES + 1] = { id = id, weekday = rule.weekday, start = rule.start, duration = rule.duration }
	end
end

-- The calendar events active at realm weekday `weekday` (1 = Sunday) and minute of day `minute` (weekly rules only).
local function activeEvents(weekday, minute)
	local active = {}
	for _, rule in ipairs(EVENT_RULES) do
		if rule.weekday == weekday and minute >= rule.start and minute < rule.start + rule.duration then
			active[#active + 1] = rule.id
		end
	end
	return active
end

---------------------------------------------------------------------------------------------------------------------
-- Loot: each area's shares of Catches, as VMaNGOS rolls them (scripts/pagle_data/propose_events.py `_split`): a
-- positive chance is a percentage of Catches, the rows at 0 split what the positive ones leave, a negative (quest)
-- chance bites at |chance| once the quest is taken. A gated catch (the catalogue's window) is rolled only while its
-- window is open; a closed one yields a Catch that is not on the list (its share is NOT redistributed, as in
-- propose_events.py).
---------------------------------------------------------------------------------------------------------------------
local csvRows = {}
for line in io.lines(ROOT .. "/data/baseline/area_loot.csv") do
	local area, item, chance = line:match("^(%d+),(%d+),([%-%d%.]+),")
	if area then
		csvRows[#csvRows + 1] = { area = tonumber(area), item = tonumber(item), chance = tonumber(chance) }
	end
end
local rowsByArea = {}
for _, row in ipairs(csvRows) do
	rowsByArea[row.area] = rowsByArea[row.area] or {}
	table.insert(rowsByArea[row.area], row)
end

-- Everything about one fishable area: entries = { itemID, share (0..1), quest?, gate?, window? }.
local AREAS = {}
local ZONES = {} -- charted zone -> { id, skillBase, areas = { area... } }
for _, zone in ipairs(world.charted) do
	local info = catalogue.GetArea(zone)
	local zoneEntry = { id = zone, skillBase = info.skillBase or -1, areas = {} }
	ZONES[zone] = zoneEntry
	local listedGate = {} -- area -> item -> catch entry
	local listedAreas = {}
	for _, e in ipairs(catalogue.GetZoneCatches(zone)) do
		listedGate[e.areaID] = listedGate[e.areaID] or {}
		listedGate[e.areaID][e.itemID] = e
		listedAreas[e.areaID] = true
	end
	local ids = {}
	for a in pairs(listedAreas) do
		ids[#ids + 1] = a
	end
	table.sort(ids)
	for _, a in ipairs(ids) do
		local rows = rowsByArea[a]
		if rows then
			local given, zeros = 0, 0
			for _, r in ipairs(rows) do
				if r.chance > 0 then
					given = given + r.chance
				elseif r.chance == 0 then
					zeros = zeros + 1
				end
			end
			local rest = zeros > 0 and math.max(0, 100 - given) / zeros or 0
			local entries = {}
			for _, r in ipairs(rows) do
				local listed = listedGate[a][r.item]
				local share, quest
				if r.chance > 0 then
					share = r.chance / 100
				elseif r.chance == 0 then
					share = rest / 100
				else
					share, quest = -r.chance / 100, true
				end
				local entry = {
					itemID = r.item,
					share = share,
					quest = quest,
					listed = listed ~= nil,
					window = listed and listed.window,
					gate = listed and listed.gate,
				}
				local item = listed and catalogue.GetItem(r.item)
				if item then
					entry.class = ledger.ClassifyCatch(r.item, item)
					entry.species = item.species
					entry.family = item.family
					entry.coll = ledger.CollectionOf(item)
				end
				entries[#entries + 1] = entry
			end
			-- One area (125, two rows at 100%) sums to more than 100%: its rows split the Catches in proportion.
			local sum = 0
			for _, e in ipairs(entries) do
				if not e.quest then
					sum = sum + e.share
				end
			end
			if sum > 1 then
				for _, e in ipairs(entries) do
					e.share = e.share / sum
				end
			end
			AREAS[a] = { id = a, zone = zone, entries = entries }
			zoneEntry.areas[#zoneEntry.areas + 1] = AREAS[a]
		end
	end
end

-- The Extravaganza pool, data/baseline/pool_loot.csv entry 180248: five rows, the Legends at 0.2% each, 19807 the rest.
local TOURNAMENT = {}
do
	local given = 0
	for _, row in ipairs(A.TOURNAMENT_POOL) do
		if row[2] then
			given = given + row[2]
		end
	end
	for _, row in ipairs(A.TOURNAMENT_POOL) do
		TOURNAMENT[#TOURNAMENT + 1] = { itemID = row[1], share = (row[2] or (100 - given)) / 100 }
	end
end

---------------------------------------------------------------------------------------------------------------------
-- Random numbers: a small LCG-free xorshift is overkill; math.random with a per-run seed is enough.
---------------------------------------------------------------------------------------------------------------------

local function skillFor(catches)
	local rank, left = 0, catches
	for band, per in ipairs(A.SKILL_CATCHES_PER_POINT) do
		local points = 75
		local need = points * per
		if left >= need then
			rank, left = rank + points, left - need
		else
			return rank + math.floor(left / per)
		end
	end
	return 300
end

---------------------------------------------------------------------------------------------------------------------
-- One simulated fisher.
---------------------------------------------------------------------------------------------------------------------
local COIN_KINDS = { newSpecies = "species", newCurio = "curio", trophyWeight = "trophy", zoneRank = "zone", legend = "legend" }

local function newRun(profile, seed)
	math.randomseed(seed * 7919 + 17)
	for _ = 1, 5 do
		math.random()
	end
	local run = {
		profile = profile,
		fold = ledger.NewLedgerFold(lookups),
		huntState = hunts.NewHuntsState(),
		earned = {},
		tally = { species = 0, curio = 0, trophy = 0, zone = 0, legend = 0, prestige = 0 },
		seq = 0,
		catches = 0,
		time = 0,
		prestiges = 0,
		skillRank = 0,
		skillLogged = {},
		visited = {},
		questTaken = {},
		zone = nil,
		stintLeft = 0,
		area = nil,
		legendsCaught = 0,
		tournaments = 0,
		boardXP = 0,
		prestigeHours = {},
	}
	run.state = run.fold.reset()
	ledger.SetActivityXPSource(function()
		return run.huntState.xp + run.boardXP
	end)
	return run
end

-- The activity XP total Core hands the Ledger: Hunts' Standing Hunts, plus A.BOARD_XP_PER_DAY a day when a sensitivity
-- run stands in for the Tackle Board (0 in the base run: the Board's Notices/Expeditions and Hunt Event runs are other
-- tickets' sources, see FINDINGS.md).
local function activity(run)
	return run.huntState.xp + run.boardXP
end

local function tallyEarned(run, earned)
	for _, a in ipairs(earned) do
		local kind = COIN_KINDS[a.kind]
		if kind then
			run.tally[kind] = run.tally[kind] + a.coins
			if a.kind == "legend" then
				run.legendsCaught = run.legendsCaught + 1
			end
		elseif a.kind == "prestige" then
			run.tally.prestige = run.tally.prestige + a.coins
		end
	end
end

local function applyLedger(run, record)
	local earned = run.earned
	for i = #earned, 1, -1 do
		earned[i] = nil
	end
	run.fold.apply(run.state, record, "live", earned, activity(run))
	tallyEarned(run, earned)
end

local function newCast(run, conditions, itemID)
	run.seq = run.seq + 1
	local id = "c" .. run.seq
	return {
		kind = "cast",
		seq = run.seq,
		id = id,
		char = 1,
		time = conditions.time,
		session = "s",
		outcome = "caught",
		conditions = conditions,
		items = { { n = 1, itemID = itemID, quantity = 1, catchId = id .. ":1" } },
	}
end

-- Whether an area entry can bite now: listed + gated entries need their window open; quest entries need the quest.
local function open(run, entry, conditions, cache)
	if entry.quest and not run.questTaken[entry.itemID] then
		return false
	end
	if entry.gate then
		local hit = cache[entry.window]
		if hit == nil then
			hit = MatchesConditions(entry.gate, conditions)
			cache[entry.window] = hit
		end
		return hit
	end
	return true
end

local function drawItem(run, area, conditions)
	local cache = {}
	-- A quest fish (negative chance) rolls first, at |chance|, while its quest is taken; the quest ends with the first
	-- one caught (it is handed in), so it never bites again.
	for _, entry in ipairs(area.entries) do
		if entry.quest and run.questTaken[entry.itemID] and math.random() < entry.share then
			run.questTaken[entry.itemID] = false
			return entry.itemID
		end
	end
	local roll = math.random()
	local acc = 0
	for _, entry in ipairs(area.entries) do
		if not entry.quest and open(run, entry, conditions, cache) then
			acc = acc + entry.share
			if roll < acc then
				return entry.itemID
			end
		end
	end
	return 0 -- not on the list: Catch XP only
end

local function drawTournament()
	local roll = math.random()
	local acc = 0
	for _, entry in ipairs(TOURNAMENT) do
		acc = acc + entry.share
		if roll < acc then
			return entry.itemID
		end
	end
	return 19807
end

-- The min-maxer's planner (a greedy rate heuristic, not a proven optimum). It values an area by the coins its Catches
-- are expected to add per Catch: the first Catch of each undiscovered Species / curio / trophy weight (the coins plus
-- the XP it pays, valued at LEVEL_UP_COINS per average step of XP), the zone-first and Species-in-zone XP, and the
-- progress each Catch makes towards the zone's NEXT Zone Mastery rank (its coins split over the rank's needs).
local XP_COIN = 20 / 3500 -- coins a level pays per XP in the middle of the climb (step 1,000 + 80 L, L ~ 30)
local V = {
	species = 10 + 500 * XP_COIN,
	speciesInZone = 100 * XP_COIN,
	item = 5 + 150 * XP_COIN, -- a curio
	trophy = 5 + 100 * XP_COIN, -- a trophy weight
	zoneFirst = 200 * XP_COIN,
}

-- Whether an entry can bite for planning: quest fish only once taken, season gates by the date; time-of-day windows
-- are assumed lined up by the min-maxer (who picks the hour of the session), event windows are not plannable.
local function plannedOpen(run, entry, conditions)
	if entry.quest and not run.questTaken[entry.itemID] then
		return false
	end
	if entry.gate and entry.gate.season then
		return MatchesConditions(entry.gate, conditions)
	end
	return not (entry.gate and entry.gate.events)
end

-- What a Catch must be to count towards zone `zoneEntry`'s next Zone Mastery rank (LED-R50, ZoneMastery.lua needsOf):
-- the rank's coins (2 x rank) and XP (250 x rank) split evenly over the things still missing. nil at Master.
local function nextRankNeeds(run, zoneEntry)
	local zoneState = run.state.zones[zoneEntry.id]
	local index = world.zones[zoneEntry.id]
	local rank = zoneState and zoneState.rank or 0
	if rank >= ledger.ZONE_MASTER then
		return nil
	end
	local r = rank + 1
	local worth = 2 * r + 250 * r * XP_COIN
	local needs = { species = {}, families = {}, junk = false, treasure = false, visit = false }
	if not zoneState then
		needs.visit = worth
		needs.each = 0
		return needs
	end
	local count = 0
	if r >= 2 and r <= 4 then
		local U, caughtU = 0, 0
		for id, listing in pairs(index.species) do
			if not listing.gated then
				U = U + 1
				if zoneState.species[id] then
					caughtU = caughtU + 1
				end
			end
		end
		for id, listing in pairs(index.species) do
			if not zoneState.species[id] and ((r <= 3 and not listing.gated) or (r == 4 and listing.gated)) then
				needs.species[id] = true
				count = count + 1
			end
		end
		if r == 2 then
			count = math.max(1, math.ceil(U / 2) - caughtU)
		elseif r == 4 then
			if index.junk and not zoneState.junk then
				needs.junk = true
				count = count + 1
			end
			if index.treasure and not zoneState.treasure then
				needs.treasure = true
				count = count + 1
			end
		end
	elseif r == 5 then
		for family in pairs(index.families) do
			if not zoneState.families[family] then
				needs.families[family] = true
				count = count + 1
			end
		end
	end
	if count == 0 then
		return nil
	end
	needs.each = worth / count
	return needs
end

local function areaValue(run, area, conditions, needs)
	local value = 0
	local zoneState = run.state.zones[area.zone]
	if needs and needs.visit then
		value = value + needs.visit
	end
	if not zoneState then
		value = value + V.zoneFirst
	end
	for _, e in ipairs(area.entries) do
		if e.class and plannedOpen(run, e, conditions) then
			local w = 0
			if e.class == "species" then
				local sp = run.state.species[e.species]
				if not sp then
					w = V.species + V.speciesInZone
				elseif not (zoneState and sp.zones[area.zone]) then
					w = V.speciesInZone
				end
				if needs and needs.species[e.species] then
					w = w + needs.each
				end
			elseif e.class == "trophy" or e.class == "curio" then
				if not run.state.items[e.itemID] then
					w = e.class == "trophy" and V.trophy or V.item
				end
				if needs then
					if e.coll == "trophy" and needs.families[e.family] then
						w = w + needs.each
					elseif e.coll == "junk" and needs.junk then
						w = w + needs.each
					elseif e.coll == "treasure" and needs.treasure then
						w = w + needs.each
					end
				end
			end
			value = value + w * e.share
		end
	end
	return value
end

local function zoneOpen(run, zone)
	return zone.skillBase - A.SKILL_MOD <= run.skillRank
end

local function snapshotAt(run, time)
	local day = math.floor(time / 86400)
	local minute = math.floor((time % 86400) / 60)
	local y, m, d = civilFromDays(day)
	local weekday = (day + 4) % 7 + 1 -- 1 = Sunday
	return {
		time = time,
		minute = minute,
		date = { year = y, month = m, day = d, weekday = weekday },
		events = activeEvents(weekday, minute),
		auras = {},
		zone = 0,
		subzone = 0,
		skillRank = math.max(run.skillRank, 1),
		skillMod = 0,
	}
end

local function pickZone(run, conditions)
	local kind = run.profile.kind
	local candidates = {}
	for _, id in ipairs(world.charted) do
		local zone = ZONES[id]
		if #zone.areas > 0 and zoneOpen(run, zone) then
			candidates[#candidates + 1] = zone
		end
	end
	if #candidates == 0 then
		candidates[1] = ZONES[world.charted[1]]
	end
	if kind == "minmax" then
		local best, bestValue = nil, -1
		for _, zone in ipairs(candidates) do
			local needs = nextRankNeeds(run, zone)
			local v = 0
			for _, area in ipairs(zone.areas) do
				v = math.max(v, areaValue(run, area, conditions, needs))
			end
			v = v + math.random() * 1e-9
			if v > bestValue then
				best, bestValue = zone, v
			end
		end
		return best
	end
	local total = 0
	local weights = {}
	for i, zone in ipairs(candidates) do
		weights[i] = run.visited[zone.id] and 1 or A.UNVISITED_WEIGHT
		total = total + weights[i]
	end
	local roll = math.random() * total
	for i, zone in ipairs(candidates) do
		roll = roll - weights[i]
		if roll <= 0 then
			return zone
		end
	end
	return candidates[#candidates]
end

local function pickArea(run, zone, conditions)
	if run.profile.kind == "minmax" then
		local best, bestValue = nil, -1
		local needs = nextRankNeeds(run, zone)
		for _, area in ipairs(zone.areas) do
			local v = areaValue(run, area, conditions, needs) + math.random() * 1e-9
			if v > bestValue then
				best, bestValue = area, v
			end
		end
		return best
	end
	return zone.areas[math.random(#zone.areas)]
end

local function logSkill(run, time)
	local rank = skillFor(run.catches)
	if rank == run.skillRank then
		return
	end
	run.skillRank = rank
	for _, threshold in ipairs(ledger.SKILL_MILESTONES) do
		if rank >= threshold and not run.skillLogged[threshold] then
			run.skillLogged[threshold] = true
			run.seq = run.seq + 1
			applyLedger(run, { kind = "skill", seq = run.seq, id = "k" .. run.seq, char = 1, time = time, rank = rank, max = 300, mod = 0 })
		end
	end
end

local function maybePrestige(run, time)
	if A.PRESTIGE_AT_60 and ledger.PrestigeAllowed(run.state, false) then
		run.seq = run.seq + 1
		run.prestiges = run.prestiges + 1
		run.prestigeHours[run.prestiges] = run.catches / A.CATCHES_PER_HOUR
		applyLedger(run, {
			kind = "prestige",
			seq = run.seq,
			id = "p" .. run.seq,
			char = 1,
			time = time,
			rank = run.state.prestige + 1,
			activityXP = activity(run),
		})
	end
end

local function coinsOf(run)
	local ledgerCoins = ledger.CoinsEarned(run.state)
	local huntCoins = hunts.CoinsEarned(run.huntState)
	local t = run.tally
	-- Level coins = everything in the Ledger's total that is not a discovery payout or a Prestige.
	local levels = ledgerCoins - t.species - t.curio - t.trophy - t.zone - t.legend - t.prestige
	local firstClimb = math.min(levels, 20 * (ledger.LEVEL_CAP - 1))
	local loop = (levels - firstClimb) + t.prestige
	return {
		total = ledgerCoins + huntCoins,
		levelsFirst = firstClimb,
		prestigeLoop = loop,
		species = t.species,
		curio = t.curio,
		trophy = t.trophy,
		zone = t.zone,
		legend = t.legend,
		hunts = huntCoins,
		-- Everything but the repeating Prestige climbs.
		oneTime = ledgerCoins + huntCoins - loop,
	}
end

local function stats(run)
	local s = run.state
	local species, items, zonesMaster, zonesVisited = 0, 0, 0, 0
	for _ in pairs(s.species) do
		species = species + 1
	end
	for _ in pairs(s.items) do
		items = items + 1
	end
	local ranks = 0
	for _, z in pairs(s.zones) do
		zonesVisited = zonesVisited + 1
		ranks = ranks + z.rank
		if z.rank >= ledger.ZONE_MASTER then
			zonesMaster = zonesMaster + 1
		end
	end
	local tiers = 0
	for _, p in pairs(run.huntState.hunts) do
		tiers = tiers + 1
	end
	return {
		species = species,
		items = items,
		zonesVisited = zonesVisited,
		zoneRankSum = ranks,
		zonesMaster = zonesMaster,
		level = ledger.Level(s),
		prestiges = run.prestiges,
		legends = run.legendsCaught,
		skill = run.skillRank,
		huntsTouched = tiers,
		huntXP = run.huntState.xp,
	}
end

-- Plays one profile for HOURS hours of fishing; returns the snapshots at the hour and day marks.
local function play(profile, seed)
	local run = newRun(profile, seed)
	local kind = profile.kind
	local perDay = profile.hoursPerDay * A.CATCHES_PER_HOUR
	local totalCatches = HOURS * A.CATCHES_PER_HOUR
	local hourSnaps, daySnaps = {}, {}
	local reached, nextThreshold = {}, 1
	local nextHour, nextDay = 1, 1
	local questMode = A.QUEST_TAKEN[kind]
	local auraMode = A.AURA_SESSIONS[kind]
	local attendMode, poolMode = A.EXTRAVAGANZA_ATTEND[kind], A.EXTRAVAGANZA_POOL_SHARE[kind]
	local carry = 0 -- fractional catches carried between days
	local day = 0
	local dayStartTime = 0
	local lastQuestRoll = {}
	-- Quest fish: decide once per run which quest Species the fisher will have taken (all bite from the start).
	for _, row in pairs(csvRows) do
		if row.chance < 0 and run.questTaken[row.item] == nil then
			run.questTaken[row.item] = math.random() < questMode
		end
	end
	while run.catches < totalCatches do
		-- A day's session.
		carry = carry + perDay
		run.boardXP = run.boardXP + (BOARD_XP_BY_PROFILE and BOARD_XP_BY_PROFILE[profile.name] or A.BOARD_XP_PER_DAY)
		local today = math.floor(carry)
		carry = carry - today
		local startMinute
		if kind == "minmax" then
			startMinute = 360 + math.random(0, 59) -- 06:00-07:00: day AND night fish are both open until 12:00
		else
			startMinute = math.random(0, 1439)
		end
		local weekday = (START_DAY + day + 4) % 7 + 1
		local extravaganza = weekday == 1 and math.random() < attendMode
		if extravaganza then
			startMinute = 840 -- 14:00, the tournament's start
		end
		local auras = math.random() < auraMode
		local time = (START_DAY + day) * 86400 + startMinute * 60
		local session = 0
		run.stintLeft = 0
		while session < today and run.catches < totalCatches do
			time = time + math.floor(3600 / A.CATCHES_PER_HOUR + 0.5)
			session = session + 1
			local conditions = snapshotAt(run, time)
			local tournament = extravaganza and (session * 3600 / A.CATCHES_PER_HOUR) <= 7200
			local itemID
			if tournament then
				run.zone = ZONES[A.TOURNAMENT_ZONE]
				run.visited[run.zone.id] = true
				conditions.zone = run.zone.id
				run.area = run.zone.areas[1]
				conditions.subzone = run.area.id ~= run.zone.id and run.area.id or 0
			elseif run.stintLeft <= 0 or not run.zone then
				run.zone = pickZone(run, conditions)
				run.visited[run.zone.id] = true
				run.stintLeft = kind == "minmax" and A.STINT_CATCHES_MINMAX or A.STINT_CATCHES
			end
			if not tournament then
				run.stintLeft = run.stintLeft - 1
				run.area = pickArea(run, run.zone, conditions)
				conditions.zone = run.zone.id
				conditions.subzone = run.area.id ~= run.zone.id and run.area.id or 0
			end
			if auras then
				conditions.auras = { 1280341, 1280342 }
			end
			if tournament and math.random() < poolMode then
				itemID = drawTournament()
			else
				itemID = drawItem(run, run.area, conditions)
			end
			run.catches = run.catches + 1
			run.time = time
			if DEBUG_ZONES then
				run.areaCasts = run.areaCasts or {}
				run.areaCasts[run.area.id] = (run.areaCasts[run.area.id] or 0) + 1
			end
			local cast = newCast(run, conditions, itemID)
			logSkill(run, time)
			-- Hunts first (Activity XP reaches the Ledger's climb), then the Ledger.
			hunts.ApplyCast(run.huntState, cast, hunts.lookups)
			applyLedger(run, cast)
			maybePrestige(run, time)
			-- When each price point is first reached (checked every 18 Catches, six minutes of fishing).
			if run.catches % 18 == 0 and nextThreshold <= #THRESHOLDS then
				local coins = coinsOf(run)
				while THRESHOLDS[nextThreshold] and coins.total >= THRESHOLDS[nextThreshold] do
					reached[THRESHOLDS[nextThreshold]] = { hours = run.catches / A.CATCHES_PER_HOUR, day = day + 1, oneTime = coins.oneTime >= THRESHOLDS[nextThreshold] }
					nextThreshold = nextThreshold + 1
				end
			end
			-- Snapshots.
			while HOUR_MARKS[nextHour] and run.catches >= HOUR_MARKS[nextHour] * A.CATCHES_PER_HOUR do
				hourSnaps[HOUR_MARKS[nextHour]] = { coins = coinsOf(run), stats = stats(run), day = day + 1 }
				nextHour = nextHour + 1
			end
		end
		day = day + 1
		while DAY_MARKS[nextDay] and day >= DAY_MARKS[nextDay] do
			daySnaps[DAY_MARKS[nextDay]] = { coins = coinsOf(run), stats = stats(run), hours = run.catches / A.CATCHES_PER_HOUR }
			nextDay = nextDay + 1
		end
	end
	if DEBUG_ZONES and seed == 1 then
		-- Where the fisher stands at the end: each zone's rank and what its next rank still lacks.
		for _, id in ipairs(world.charted) do
			local zone = ZONES[id]
			local needs = nextRankNeeds(run, zone)
			local zs = run.state.zones[id]
			local lacking = {}
			if needs then
				for sp in pairs(needs.species) do
					lacking[#lacking + 1] = "sp" .. sp
				end
				for fam in pairs(needs.families) do
					lacking[#lacking + 1] = "fam" .. fam
				end
				if needs.junk then
					lacking[#lacking + 1] = "junk"
				end
				if needs.treasure then
					lacking[#lacking + 1] = "treasure"
				end
			end
			local cond = snapshotAt(run, run.time)
			local best, bestArea = 0, nil
			for _, area in ipairs(zone.areas) do
				local v = areaValue(run, area, cond, needs)
				if v > best then
					best, bestArea = v, area.id
				end
			end
			lacking[#lacking + 1] = ("[value %.4f in area %s; casts here %s]"):format(best, tostring(bestArea), tostring(run.areaCasts and run.areaCasts[bestArea]))
			io.stderr:write(("zone %d skillBase %d areas %d rank %s lacks %s\n"):format(id, zone.skillBase, #zone.areas, zs and zs.rank or "-", table.concat(lacking, " ")))
		end
	end
	return hourSnaps, daySnaps, run.prestigeHours, reached
end

---------------------------------------------------------------------------------------------------------------------
-- Driver: seeds x profiles, aggregate, write tables.
---------------------------------------------------------------------------------------------------------------------
local FIELDS = { "total", "oneTime", "levelsFirst", "prestigeLoop", "species", "curio", "trophy", "zone", "legend", "hunts" }
local STAT_FIELDS =
	{ "species", "items", "zonesVisited", "zoneRankSum", "zonesMaster", "level", "prestiges", "legends", "skill", "huntsTouched", "huntXP", "day", "hours" }
local NAMES = { "casual", "dedicated", "minmax_1.5h", "minmax_4h" }

local function quantile(sorted, q)
	local n = #sorted
	if n == 0 then
		return 0
	end
	local pos = 1 + (n - 1) * q
	local lo, hi = math.floor(pos), math.ceil(pos)
	return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo)
end

local function summarise(values)
	table.sort(values)
	local sum = 0
	for _, v in ipairs(values) do
		sum = sum + v
	end
	return { mean = sum / #values, p10 = quantile(values, 0.1), p50 = quantile(values, 0.5), p90 = quantile(values, 0.9) }
end

local function collect(snapsList, marks)
	local out = {}
	for _, mark in ipairs(marks) do
		local present = false
		for _, snaps in ipairs(snapsList) do
			present = present or snaps[mark] ~= nil
		end
		if present then
			local entry = { mark = mark, coins = {}, stats = {} }
			for _, field in ipairs(FIELDS) do
				local values = {}
				for _, snaps in ipairs(snapsList) do
					if snaps[mark] then
						values[#values + 1] = snaps[mark].coins[field]
					end
				end
				entry.coins[field] = summarise(values)
			end
			for _, field in ipairs(STAT_FIELDS) do
				local values = {}
				for _, snaps in ipairs(snapsList) do
					local snap = snaps[mark]
					if snap then
						local v = snap.stats[field]
						if field == "day" then
							v = snap.day
						elseif field == "hours" then
							v = snap.hours
						end
						if v then
							values[#values + 1] = v
						end
					end
				end
				if #values > 0 then
					entry.stats[field] = summarise(values)
				end
			end
			out[#out + 1] = entry
		end
	end
	return out
end

local function mkdir(path)
	if package.config:sub(1, 1) == "\\" then
		os.execute('mkdir "' .. path:gsub("/", "\\") .. '" 2>nul')
	else
		os.execute('mkdir -p "' .. path .. '"')
	end
end

local function f0(v)
	return ("%.0f"):format(v)
end

local function write(path, lines)
	local f = assert(io.open(path, "w"))
	f:write(table.concat(lines, "\n"), "\n")
	f:close()
end

-- The most one-time coins each source can ever pay, from the catalogue and the repo's constants (not from the sim).
local function ceilings()
	local species = 0
	for _ in pairs(world.species) do
		species = species + 1
	end
	local trophies, curios = 0, 0
	for itemID in pairs(world.items) do
		if ledger.CollectionOf(catalogue.GetItem(itemID)) == "trophy" then
			trophies = trophies + 1
		else
			curios = curios + 1
		end
	end
	local legends = 0
	for _ in pairs(world.legends) do
		legends = legends + 1
	end
	local standing = 0
	for _, hunt in ipairs(hunts.hunts:Hunts()) do
		standing = standing + hunts.COINS_COMPLETED + (#hunt.tiers - 1) * hunts.COINS_TIER
	end
	local sets = 0
	for _ in pairs(hunts.huntList.sets) do
		sets = sets + 1
	end
	local zoneCoins = 0
	for rank = 1, ledger.ZONE_MASTER do
		zoneCoins = zoneCoins + ledger.ZONE_RANK_COINS * rank
	end
	local c = {
		{ "Species (new Species)", species, species * 10 },
		{ "Trophy weights", trophies, trophies * 5 },
		{ "Curios (junk, containers, treasure)", curios, curios * 5 },
		{ "Legends", legends, legends * ledger.LEGEND_COINS },
		{ "Zone Mastery (charted zones x 30)", #world.charted, #world.charted * zoneCoins },
		{ "Levels 1 to 60, first climb", 59, 59 * ledger.LEVEL_UP_COINS },
		{ "Standing Hunts (tiers)", #hunts.hunts:Hunts(), standing },
		{ "Standing Hunt set titles", sets, sets * hunts.COINS_TITLE },
	}
	local total = 0
	for _, row in ipairs(c) do
		total = total + row[3]
	end
	c.total = total
	return c
end

local function runVariant(variant, outDir, seeds, hours)
	mkdir(outDir)
	local results = {}
	local clock0 = os.clock()
	for _, profile in ipairs(PROFILES) do
		if not ONLY or ONLY[profile.name] then
			local hourList, dayList, prestigeList, reachedList = {}, {}, {}, {}
			for seed = 1, seeds do
				local hs, ds, ph, rc = play(profile, seed)
				reachedList[#reachedList + 1] = rc
				hourList[#hourList + 1] = hs
				dayList[#dayList + 1] = ds
				prestigeList[#prestigeList + 1] = ph
			end
			results[profile.name] = {
				profile = profile,
				byHour = collect(hourList, HOUR_MARKS),
				byDay = collect(dayList, DAY_MARKS),
				prestigeHours = prestigeList,
				reached = reachedList,
			}
			io.stderr:write(("%s / %s: %d runs, %.0fs\n"):format(variant, profile.name, seeds, os.clock() - clock0))
		end
	end

	local lines = { "profile,hours,days_mean,coins_mean,coins_p10,coins_p90,one_time_mean,levels_first_climb,prestige_loop,species,curio,trophy,zone,legend,hunts" }
	for _, name in ipairs(NAMES) do
		local r = results[name]
		if r then
			for _, e in ipairs(r.byHour) do
				local c = e.coins
				lines[#lines + 1] = table.concat({
					name, e.mark, ("%.1f"):format(e.stats.day.mean), f0(c.total.mean), f0(c.total.p10), f0(c.total.p90),
					f0(c.oneTime.mean), f0(c.levelsFirst.mean), f0(c.prestigeLoop.mean), f0(c.species.mean), f0(c.curio.mean),
					f0(c.trophy.mean), f0(c.zone.mean), f0(c.legend.mean), f0(c.hunts.mean),
				}, ",")
			end
		end
	end
	write(outDir .. "/by_hour.csv", lines)

	lines = { "profile,day,hours_mean,coins_mean,coins_p10,coins_p90,one_time_mean,prestige_loop" }
	for _, name in ipairs(NAMES) do
		local r = results[name]
		if r then
			for _, e in ipairs(r.byDay) do
				local c = e.coins
				lines[#lines + 1] = table.concat({
					name, e.mark, ("%.1f"):format(e.stats.hours.mean), f0(c.total.mean), f0(c.total.p10), f0(c.total.p90),
					f0(c.oneTime.mean), f0(c.prestigeLoop.mean),
				}, ",")
			end
		end
	end
	write(outDir .. "/by_day.csv", lines)

	lines = { "profile,hours,species,items,zones_visited,zone_rank_sum,zones_master,level,prestiges,legends,skill,hunts_touched,hunt_xp" }
	for _, name in ipairs(NAMES) do
		local r = results[name]
		if r then
			for _, e in ipairs(r.byHour) do
				local s2 = e.stats
				lines[#lines + 1] = table.concat({
					name, e.mark, ("%.1f"):format(s2.species.mean), ("%.1f"):format(s2.items.mean), ("%.1f"):format(s2.zonesVisited.mean),
					("%.1f"):format(s2.zoneRankSum.mean), ("%.1f"):format(s2.zonesMaster.mean), ("%.1f"):format(s2.level.mean),
					("%.1f"):format(s2.prestiges.mean), ("%.2f"):format(s2.legends.mean), ("%.0f"):format(s2.skill.mean),
					("%.1f"):format(s2.huntsTouched.mean), f0(s2.huntXP.mean),
				}, ",")
			end
		end
	end
	write(outDir .. "/discovery_by_hour.csv", lines)

	-- Hours at which the n-th Prestige is reached (mean over runs that got there).
	lines = { "profile,prestige,hours_mean,runs_reaching" }
	for _, name in ipairs(NAMES) do
		local r = results[name]
		if r then
			for n = 1, 12 do
				local sum, count = 0, 0
				for _, ph in ipairs(r.prestigeHours) do
					if ph[n] then
						sum, count = sum + ph[n], count + 1
					end
				end
				if count > 0 then
					lines[#lines + 1] = ("%s,%d,%.1f,%d"):format(name, n, sum / count, count)
				end
			end
		end
	end
	write(outDir .. "/prestige_hours.csv", lines)

	-- Hours and days at which each price point is first reached; "reached" counts the runs that got there by HOURS.
	lines = { "profile,coins,runs_reaching,of_runs,hours_mean,hours_p10,hours_p90,days_mean" }
	for _, name in ipairs(NAMES) do
		local r = results[name]
		if r then
			for _, threshold in ipairs(THRESHOLDS) do
				local hoursList, daysList = {}, {}
				for _, rc in ipairs(r.reached) do
					if rc[threshold] then
						hoursList[#hoursList + 1] = rc[threshold].hours
						daysList[#daysList + 1] = rc[threshold].day
					end
				end
				if #hoursList > 0 then
					local h, d = summarise(hoursList), summarise(daysList)
					lines[#lines + 1] = ("%s,%d,%d,%d,%.1f,%.1f,%.1f,%.1f"):format(name, threshold, #hoursList, #r.reached, h.mean, h.p10, h.p90, d.mean)
				end
			end
		end
	end
	write(outDir .. "/price_points.csv", lines)

	local md = {}
	local function row(label, r, field)
		local cells = { label }
		for _, mark in ipairs({ 1, 5, 10, 20, 50, 100, 200, 300, 500 }) do
			for _, e in ipairs(r.byHour) do
				if e.mark == mark then
					cells[#cells + 1] = f0(e.coins[field].mean)
				end
			end
		end
		return "| " .. table.concat(cells, " | ") .. " |"
	end
	md[#md + 1] = ("Variant `%s`: mean cumulative Pagle Coins over %d runs per profile (seeds 1..%d)."):format(variant, seeds, seeds)
	md[#md + 1] = ""
	md[#md + 1] = "| Profile | 1 h | 5 h | 10 h | 20 h | 50 h | 100 h | 200 h | 300 h | 500 h |"
	md[#md + 1] = "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|"
	for _, name in ipairs(NAMES) do
		if results[name] then
			md[#md + 1] = row(name .. ", all sources", results[name], "total")
			md[#md + 1] = row(name .. ", without the repeat Prestige climbs", results[name], "oneTime")
		end
	end
	write(outDir .. "/headline.md", md)
	return results, md
end

-- Sensitivity variants (each moves one assumption of the base run).
local VARIANTS = {
	base = function() end,
	no_camp_auras = function()
		A.AURA_SESSIONS = { casual = 0, dedicated = 0, minmax = 0 }
	end,
	all_camp_auras = function()
		A.AURA_SESSIONS = { casual = 1, dedicated = 1, minmax = 1 }
	end,
	no_extravaganza = function()
		A.EXTRAVAGANZA_ATTEND = { casual = 0, dedicated = 0, minmax = 0 }
	end,
	no_quest_fish = function()
		A.QUEST_TAKEN = { casual = 0, dedicated = 0, minmax = 0 }
	end,
	catches_120_per_hour = function()
		A.CATCHES_PER_HOUR = 120
	end,
	catches_240_per_hour = function()
		A.CATCHES_PER_HOUR = 240
	end,
	board_xp = function()
		A.BOARD_XP_PER_DAY = 1050
	end,
	no_prestige = function()
		A.PRESTIGE_AT_60 = false
	end,
}
local VARIANT_ORDER =
	{ "base", "no_camp_auras", "all_camp_auras", "no_extravaganza", "no_quest_fish", "catches_120_per_hour", "catches_240_per_hour", "board_xp", "no_prestige" }

local chosen = {}
for name in (VARIANT_ARG or "base"):gmatch("[^,]+") do
	chosen[#chosen + 1] = name
end
if VARIANT_ARG == "all" then
	chosen = VARIANT_ORDER
end

local summary = { "variant,profile,hours,coins_mean,one_time_mean" }
for _, name in ipairs(chosen) do
	assert(VARIANTS[name], "unknown variant " .. name)
	VARIANTS[name]()
	local outDir = name == "base" and OUT or (OUT .. "/variants/" .. name)
	local results, md = runVariant(name, outDir, name == "base" and SEEDS or math.min(SEEDS, VARIANT_SEEDS), HOURS)
	if name == "base" then
		local zoneLines = { "zone,skill_base,loot_areas,species_ungated,species_gated,families,junk,treasure,needs_for_master" }
		for _, id in ipairs(world.charted) do
			local idx, zone = world.zones[id], ZONES[id]
			local ungated, gated, families = 0, 0, 0
			for _, listing in pairs(idx.species) do
				if listing.gated then
					gated = gated + 1
				else
					ungated = ungated + 1
				end
			end
			for _ in pairs(idx.families) do
				families = families + 1
			end
			zoneLines[#zoneLines + 1] = ("%d,%d,%d,%d,%d,%d,%d,%d,%d"):format(
				id, zone.skillBase, #zone.areas, ungated, gated, families, idx.junk and 1 or 0, idx.treasure and 1 or 0,
				ungated + gated + families + (idx.junk and 1 or 0) + (idx.treasure and 1 or 0)
			)
		end
		write(OUT .. "/zones.csv", zoneLines)
		local c = ceilings()
		local lines = { "| Source | Count | Coins when everything is found |", "|---|---:|---:|" }
		for _, row in ipairs(c) do
			lines[#lines + 1] = ("| %s | %d | %d |"):format(row[1], row[2], row[3])
		end
		lines[#lines + 1] = ("| **All one-time sources** | | **%d** |"):format(c.total)
		write(OUT .. "/ceilings.md", lines)
		print(table.concat(lines, "\n"))
		print()
	end
	print(table.concat(md, "\n"))
	print()
	for _, pname in ipairs(NAMES) do
		local r = results[pname]
		if r then
			for _, e in ipairs(r.byHour) do
				summary[#summary + 1] = ("%s,%s,%d,%.0f,%.0f"):format(name, pname, e.mark, e.coins.total.mean, e.coins.oneTime.mean)
			end
		end
	end
	-- Put the base assumptions back for the next variant.
	resetA()
end
write(OUT .. "/variants_summary.csv", summary)
