if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Ledger's fold (LED-R3): a pure function of the entries applied and the catalogue, the same in every mode.
-- Core's lookups are passed in (CORE-R7). M2's stage (LED-R4): classification without the Legend class, the XP rows
-- Catch XP, new Species, Species in a zone, first Catch in a zone and Skill Milestones, Fresh Water, the first climb,
-- Skill Milestones, lifetime Catches as a count, and Coins for level-ups and new Species. M3's catches (LED-R4): the
-- Uncharted list (LED-R64), the collections' items (LED-R60, LED-R61) with their XP and Coins, and first-Catch facts.
-- M4's catches (LED-R4): the Legend class (LED-R63, logic/Legends.lua) and Catch Milestones (LED-R42,
-- logic/CatchMilestones.lua). M4's Prestige (LED-R30–R32): Prestige entries start a new climb (logic/Prestige.lua)
-- and a climb at 60 is ready. M4's Simulated Size records (LED-R80–R83): logic/Records.lua. Fish varieties
-- (VAR-R20, VAR-R25): logic/Varieties.lua.

--- A realm date (LOG-R49), as the Journal prints it.
---@alias LedgerDate { year: integer, month: integer, day: integer }

--- The Ledger's projection state (ledger.md › Data, LedgerState), holding what M2, M3 and M4's catches fill. Levels,
--- XP into the level and Fresh Water shown are computed from it (logic/Progress.lua), never stored, and so is the
--- current climb's Activity XP, read from Core (LED-R37).
---@class LedgerState
---@field casts integer                       -- caught and got-away Casts applied (LED-R93)
---@field catches integer                     -- lifetime Catches (LED-R42)
---@field xp integer                          -- the climb's own XP: the Ledger's own since the latest Prestige
--- and the carried XP (LED-R31); the climb's Activity XP adds to it (logic/Progress.lua)
---@field lifetimeXP integer                  -- the Ledger's own XP, all told (LED-R20, LED-R150)
---@field prestigeActivityXP integer          -- the latest Prestige entry's `activityXP`, 0 before the first (LED-R37)
---@field prestige integer                    -- prestige rank: 0 until the first Prestige (LED-R32)
---@field fresh number                        -- Fresh Water F after the last Catch (LED-R22)
---@field lastCatch? integer                  -- server time of the last Catch's Cast
---@field firstDate? LedgerDate               -- realm date of the first Catch of any class with one (LED-R146)
---@field firstTime? integer                  -- server time of the first Catch of any class (LED-R146)
---@field coins integer                       -- lifetime Coins earned (LED-R88)
---@field skill { [integer]: integer }        -- Skill Milestone threshold -> time credited (LED-R40)
---@field milestones { [integer]: integer }   -- Catch Milestone -> time reached (LED-R42)
---@field species { [integer]: LedgerSpecies } -- by Species ID (LED-R5); Species Catches only, never Legends
---@field items { [integer]: LedgerFirst }    -- trophy, curio and Legend items, by item ID (LED-R60, LED-R63)
---@field uncharted { [integer]: LedgerFirst } -- Uncharted item IDs, with zones (LED-R64)
---@field zones { [integer]: LedgerZone }     -- every zone fished, never 0 (LED-R6)
---@field varieties { [integer]: { [integer]: LedgerVariety } } -- by Species ID, each variety caught by its position
--- (VAR-R20, logic/Varieties.lua)
---@field counts LedgerCounts                 -- the second round's counts (LED-R118, logic/EarnedCounts.lua)
---@field crest? LedgerCrestLogged            -- the latest crest record (LED-R156, logic/Derived.lua); nil before one

--- The crest the Ledger's latest crest record names (LED-R156): its good ID, "" for Plain, and the record's time.
---@class LedgerCrestLogged
---@field good string
---@field time integer

--- The second round's counts (ledger.md › Data, LedgerCounts; LED-R118, LED-R119).
---@class LedgerCounts
---@field shards integer                      -- glass shards (LED-R119)
---@field lastDay { [integer]: integer }      -- zone -> day number of its latest caught Cast (LED-R119)
---@field deep integer                        -- caught Casts at realm minute < 240
---@field pairs integer                       -- caught Casts sharing a Species with the caught Cast before
---@field lastSpecies { [integer]: true }     -- the Species among the last caught Cast's Catches
---@field records integer                     -- size records beaten (LED-R82)
---@field ice integer                         -- caught Casts in the ice zones
---@field sea integer                         -- caught Casts at sea
---@field gotAwayRun integer                  -- got-away Casts since the last caught one
---@field afterRun boolean                    -- a caught Cast came after 10 or more got away
---@field days { [integer]: true }            -- day numbers with a caught Cast
---@field lures { [integer]: true }           -- lure IDs on caught Casts
---@field clams integer                       -- Big-mouth Clam Catches

--- An item's Catches and its first Catch (ledger.md › Data, LedgerFirst): that Cast's time, character, zone and realm
--- date. Legend items also keep their Simulated Size record and `since` (LED-R80, logic/Records.lua).
---@class LedgerFirst
---@field n integer                           -- Catches of the item
---@field time integer
---@field char integer
---@field zone integer
---@field date? LedgerDate                    -- nil only for a Cast stored without its realm minute
---@field zones? { [integer]: integer }       -- Uncharted only: Catches per zone (never 0)
---@field record? LedgerRecord                -- Legend items only, from their first sized Catch (LED-R80)
---@field since? integer                      -- with `record`: Catches of the item after it

--- A Species' Catches (ledger.md › Data, LedgerSpecies) and its first Catch, as in LedgerFirst (LED-R140). Its `zones`
--- is a set, where an Uncharted item's counts.
---@class LedgerSpecies: LedgerFirst
---@field zones { [integer]: true }           -- zones caught in (never 0)
---@field windowsMet? { [string]: true }     -- element windows met (LED-R45): made at its first Catch, logic/Stars.lua
---@field record? LedgerRecord                -- its longest Catch, from its first sized Catch (LED-R80)
---@field since? integer                      -- with `record`: Catches of the Species after it

--- A fished zone (ledger.md › Data, LedgerZone). logic/ZoneMastery.lua makes it and fills all but `species`.
---@class LedgerZone
---@field species { [integer]: true }         -- Species caught here
---@field families { [integer]: true }        -- trophy families landed here (LED-R50)
---@field items { [integer]: true }           -- trophy and curio items caught here (LED-R138)
---@field junk boolean                        -- a `junk` Catch here (LED-R50)
---@field treasure boolean                    -- a `container` or `treasure` Catch here (LED-R50)
---@field rank integer                        -- computed rank, 0 if not charted (LED-R50, LED-R54)
---@field masterAt? integer                   -- server time of the Cast that raised the computed rank to Master
--- (LED-R155: its zone crest's time); nil below Master

--- What one `apply` earned (LED-R97's rows). `cast` is the Cast's entry ID (nil for a Skill Reading) and `coins` its
--- Coins (LED-R88; 0 when it pays none). Tickets #101 and #102 turn M2's kinds into moments and Write-up lines, ticket
--- #137 M3's; the fold never reads the celebrated set (LED-R3).
---@class LedgerAchievement
---@field kind "levelUp"|"newSpecies"|"newInZone"|"skillMilestone"|"newCurio"|"trophyWeight"|"uncharted"|"caughtStar"|"elementStar"|"regularStar"|"familyStar"|"zoneRank"|"prestigeReady"|"prestige"|"legend"|"catchMilestone"|"sizeRecord"|"completeTitle"|"newVariety"|"fishComplete"
---@field cast? string
---@field coins integer
---@field levels? integer[]                   -- levelUp: the levels it raised, ascending
---@field n? integer                          -- catchMilestone: the lifetime Catches it marks (LED-R42)
---@field species? integer                    -- newSpecies, newInZone, caughtStar, elementStar, regularStar,
--- newVariety, fishComplete: the Species ID
---@field index? integer                      -- newVariety: the variety's position (VAR-R2)
---@field rarity? "common"|"uncommon"|"rare"|"epic" -- newVariety: its rarity, which picks its moment (VAR-R25)
---@field itemID? integer                     -- the item caught, for every Catch's kind but familyStar and catchMilestone
---@field zone? integer                       -- newSpecies, newInZone, zoneRank: the Cast's zone
---@field ranks? integer[]                    -- zoneRank: the Zone Mastery ranks it passed, ascending (LED-R51)
---@field threshold? integer                  -- skillMilestone
---@field family? integer                     -- trophyWeight, familyStar: the trophy family
---@field stars? integer[]                    -- familyStar: the stars it newly computed, 2 and/or 3, ascending
---@field old? number                         -- trophyWeight with a ruler (LED-R61): the family's heaviest before
---@field new? number                         -- trophyWeight with a ruler: the new item's weight
---@field flair? boolean                      -- sizeRecord (LED-R82): the rare-record flair; old and new are its mm
---@field rank? integer                       -- prestigeReady: the climb's prestige rank; prestige: the new rank;
--- levelUp in the scratch list: its climb's rank (logic/Projection.lua)
---@field size? PagleSize                     -- newSpecies, legend, sizeRecord: the Catch's Simulated Size (LED-R81)

--- The lookups the fold reads: Core's `Pagle.GetItem` (LOG-R55) and `Pagle.MatchesConditions` (LOG-R49), and the
--- world index, which changes only with the catalogue, whose new fingerprint rebuilds the projection (LED-R10). The
--- earned goods read how many Size bands Core has (LED-R116).
---@class LedgerLookups
---@field GetItem fun(itemID: integer): PagleItem?
---@field MatchesConditions fun(spec: table, snapshot: table): boolean
---@field world LedgerWorld
---@field sizeBands? integer -- ns.SizeBandCount of Pagle.SIZE_BANDS (LOG-R67): the last is the Monster band (LED-R80)

--- The Ledger's fold (LED-R3).
---@class LedgerFold
---@field reset fun(): LedgerState
---@field apply fun(state: LedgerState, record: PagleRecord, mode: PagleApplyMode, earned: LedgerAchievement[]?, activity: integer?): LedgerAchievement[]

--- The Ledger's rules version (LED-R2, LED-R4, Tunables): 1 in M2, 2 in M3, 3 in M4, then +1 per change: 4 when ★
--- moved to a Species' 5th Catch (LED-R45), 5 for the full Prestige cost and Activity XP in the climb (LED-R30–R32,
--- LED-R37), 6 for the varieties caught (VAR-R20), 7 for the second round's counts (LED-R118, LED-R119), 8 for the
--- times a zone reached Master and a variety was first caught, and the crest record (LED-R155, LED-R156).
ns.LEDGER_RULES_VERSION = 8

-- XP (LED-R20, Tunables), M2's rows and M3's curio items and trophy weights.
--- Catch XP, before Fresh Water (LED-R20); one Fresh Water doubles it (LED-R22), as the ink XP bar shows (LED-R145).
ns.CATCH_XP = 10
local NEW_SPECIES_XP = 500
local SPECIES_IN_ZONE_XP = 100
local FIRST_IN_ZONE_XP = 200
--- XP for each Skill Milestone (LED-R40, Tunables), which the Field guide's Your Ledger step shows (ONB-R36).
ns.SKILL_MILESTONE_XP = 1000
local SKILL_MILESTONE_XP = ns.SKILL_MILESTONE_XP
local CURIO_XP = 150
local TROPHY_WEIGHT_XP = 100
-- Fresh Water's Catch XP multiplier (LED-R22, Tunables).
local FRESH_WATER_MULTIPLIER = 2
-- Coins (LED-R88), M2's rows and M3's curio items and trophy weights.
--- Coins for each level-up (LED-R88); a levelUp moment pays them for the levels it raises (LED-R97).
ns.LEVEL_UP_COINS = 20
local NEW_SPECIES_COINS = 10
local CURIO_COINS = 5
local TROPHY_WEIGHT_COINS = 5
--- Skill Milestones, ascending (LED-R40, Tunables); the Angler page ticks them (LED-R146).
ns.SKILL_MILESTONES = { 75, 150, 225, 300 }

-- Fresh Water at one Catch (LED-R22): refills from the previous Catch's time (none at the first Catch ever), then
-- spends 1 when F ≥ 1. Returns the Catch XP multiplier.
---@param state LedgerState
---@param time integer the Catch's Cast time
---@return integer
local function spendFreshWater(state, time)
	if state.lastCatch then
		state.fresh = ns.FreshWaterAt(state.fresh, state.lastCatch, time)
	end
	state.lastCatch = time
	if state.fresh >= 1 then
		state.fresh = state.fresh - 1
		return FRESH_WATER_MULTIPLIER
	end
	return 1
end

-- A copy of a Cast's realm date (records are shared, CORE-R18), nil when it has none (a Cast stored without its
-- realm minute, LOG-R49).
---@param date { year: integer, month: integer, day: integer }?
---@return LedgerDate?
local function copyDate(date)
	return date and { year = date.year, month = date.month, day = date.day } or nil
end

-- A first Catch's facts (ledger.md › Data, LedgerFirst), with no Catch counted yet.
---@param record PagleCast
---@return LedgerFirst
local function firstCatch(record)
	return {
		n = 0,
		time = record.time,
		char = record.char,
		zone = record.conditions.zone,
		date = copyDate(record.conditions.date),
	}
end
--- A copy of a Cast's realm date, nil when it has none: for logic/Varieties.lua.
ns.CopyDate = copyDate
--- A first Catch's facts (ledger.md › Data, LedgerFirst), with no Catch counted yet: for logic/Legends.lua.
ns.FirstCatch = firstCatch

-- An Uncharted Catch (LED-R64): its item's count, first Catch and Catches per zone (zone 0 left out), and an
-- `uncharted` achievement at its first Catch, paying nothing (LED-R88).
---@param state LedgerState
---@param record PagleCast
---@param itemID integer
---@param earned LedgerAchievement[]
local function creditUncharted(state, record, itemID, earned)
	local entry = state.uncharted[itemID]
	if not entry then
		entry = firstCatch(record)
		entry.zones = {}
		state.uncharted[itemID] = entry
		earned[#earned + 1] = { kind = "uncharted", cast = record.id, coins = 0, itemID = itemID }
	end
	entry.n = entry.n + 1
	local zone = record.conditions.zone
	if zone ~= 0 then
		entry.zones[zone] = (entry.zones[zone] or 0) + 1
	end
end

--- The class of one Catch (LED-R5), first match wins: "zero" (item 0), "uncharted" (GetItem knows nothing),
--- "noise", "legend", "species", "trophy", "curio" or "other". A Legend is never also a Species (M4's class, LED-R4).
---@param itemID integer
---@param item PagleItem?
---@return "zero"|"uncharted"|"noise"|"legend"|"species"|"trophy"|"curio"|"other"
function ns.ClassifyCatch(itemID, item)
	if itemID == 0 then
		return "zero"
	elseif item == nil then
		return "uncharted"
	elseif item.noise then
		return "noise"
	elseif item.legend then
		return "legend"
	end
	local category = item.category
	if category == "fish" or category == "questFish" then
		return "species"
	elseif category == "trophy" then
		return "trophy"
	elseif category == "junk" or category == "container" or category == "treasure" then
		return "curio"
	end
	return "other"
end

--- A fresh, empty state (LED-R3, LOG-R72's `def.reset`).
---@return LedgerState
local function reset()
	return {
		casts = 0,
		catches = 0,
		xp = 0,
		lifetimeXP = 0,
		prestigeActivityXP = 0,
		prestige = 0,
		fresh = ns.FRESH_WATER_CAP,
		coins = 0,
		skill = {},
		milestones = {},
		species = {},
		items = {},
		uncharted = {},
		zones = {},
		varieties = {},
		counts = ns.NewEarnedCounts(),
	}
end

--- The Ledger's fold over Core's lookups (LED-R3). `apply` folds one record into the state and appends what it earned
--- to `earned` (a new list if none is passed), which it returns. `mode` is Core's apply mode (LOG-R75); the fold is the
--- same in every mode.
---@param lookups LedgerLookups
---@return LedgerFold
function ns.NewLedgerFold(lookups)
	local getItem = lookups.GetItem
	local world = lookups.world
	local stars = ns.NewStarsFold(lookups)

	-- The greatest `weight` among a trophy family's items landed so far, nil when none is (LED-R61). `state.items` holds
	-- Legend items too, which are never trophies (LED-R5).
	---@param state LedgerState
	---@param family integer?
	---@return number?
	local function heaviestLanded(state, family)
		local heaviest
		for itemID in pairs(state.items) do
			local item = getItem(itemID)
			if item and ns.ClassifyCatch(itemID, item) == "trophy" and item.family == family then
				local weight = item.weight or 0
				heaviest = heaviest and math.max(heaviest, weight) or weight
			end
		end
		return heaviest
	end

	-- A trophy or curio Catch (LED-R60): its item's count and first Catch. The first Catch of a curio item earns
	-- `newCurio`, and of a trophy item (a new trophy weight) `trophyWeight`, ruled from the family's heaviest when it is
	-- heavier (LED-R61); each with its XP and Coins (LED-R20, LED-R88).
	---@param state LedgerState
	---@param record PagleCast
	---@param itemID integer
	---@param item PagleItem
	---@param earned LedgerAchievement[]
	local function creditItem(state, record, itemID, item, earned)
		local entry = state.items[itemID]
		if entry then
			entry.n = entry.n + 1
			return
		end
		---@type LedgerAchievement
		local achievement
		if item.category == "trophy" then
			local heaviest, weight = heaviestLanded(state, item.family), item.weight
			state.xp = state.xp + TROPHY_WEIGHT_XP
			state.coins = state.coins + TROPHY_WEIGHT_COINS
			achievement = { kind = "trophyWeight", cast = record.id, coins = TROPHY_WEIGHT_COINS, itemID = itemID }
			achievement.family = item.family
			if heaviest and weight and weight > heaviest then
				achievement.old, achievement.new = heaviest, weight
			end
		else
			state.xp = state.xp + CURIO_XP
			state.coins = state.coins + CURIO_COINS
			achievement = { kind = "newCurio", cast = record.id, coins = CURIO_COINS, itemID = itemID }
		end
		entry = firstCatch(record)
		entry.n = 1
		state.items[itemID] = entry
		earned[#earned + 1] = achievement
	end

	---@param state LedgerState
	---@param record PagleCast
	---@param earned LedgerAchievement[]
	local function applyCast(state, record, earned)
		state.casts = state.casts + 1
		if record.outcome ~= "caught" then
			ns.CountCast(state.counts, record, getItem, 0)
			return
		end
		local from = #earned
		local zone = record.conditions.zone
		for _, catch in ipairs(record.items) do
			local itemID = catch.itemID
			local item = itemID ~= 0 and getItem(itemID) or nil
			-- The base, for every class (LED-R5): lifetime Catches, Catch XP with Fresh Water, the zone fished.
			state.catches = state.catches + 1
			ns.CreditCatchMilestones(state, record, earned)
			state.xp = state.xp + ns.CATCH_XP * spendFreshWater(state, record.time)
			state.firstDate = state.firstDate or copyDate(record.conditions.date)
			state.firstTime = state.firstTime or record.time
			local zoneState
			if zone ~= 0 then
				zoneState = state.zones[zone]
				if not zoneState then
					zoneState = ns.NewZoneState()
					state.zones[zone] = zoneState
					state.xp = state.xp + FIRST_IN_ZONE_XP
				end
			end
			local class = ns.ClassifyCatch(itemID, item)
			ns.NoteZoneCatch(zoneState, class, itemID, item)
			local id = class == "species" and item and item.species or nil
			local starsBefore = stars.mark(state, class, itemID, item)
			if class == "uncharted" then
				creditUncharted(state, record, itemID, earned)
			elseif item and (class == "trophy" or class == "curio") then
				creditItem(state, record, itemID, item, earned)
			elseif class == "legend" then
				ns.CreditLegend(state, record, itemID, earned, catch.size)
			elseif id then
				local species = state.species[id]
				local new = not species
				if not species then
					-- A LedgerFirst until its zones set is added on the next line.
					species = firstCatch(record) --[[@as LedgerSpecies]]
					species.zones = {}
					state.species[id] = species
					state.xp = state.xp + NEW_SPECIES_XP
					state.coins = state.coins + NEW_SPECIES_COINS
					earned[#earned + 1] = {
						kind = "newSpecies",
						cast = record.id,
						coins = NEW_SPECIES_COINS,
						species = id,
						itemID = itemID,
						zone = zone,
						size = ns.CopySize(catch.size),
					}
				end
				species.n = species.n + 1
				if zoneState and not species.zones[zone] then
					species.zones[zone] = true
					zoneState.species[id] = true
					state.xp = state.xp + SPECIES_IN_ZONE_XP
					if not new then
						earned[#earned + 1] = {
							kind = "newInZone",
							cast = record.id,
							coins = 0,
							species = id,
							itemID = itemID,
							zone = zone,
						}
					end
				end
				-- Its variety, when Core decoded one (VAR-R1, VAR-R4).
				local variety = catch.variety
				if variety then
					ns.CreditVariety(state, record, id, itemID, variety, earned, getItem)
				end
			end
			ns.CreditSizeRecord(state, class, id, record, catch, earned)
			stars.credit(state, record, starsBefore, earned)
		end
		ns.CreditZoneRank(state, world, zone, record.id, earned, record.time)
		-- The second round's counts (LED-R118), with the size records this Cast's Catches beat (LED-R82).
		local beaten = 0
		for i = from + 1, #earned do
			if earned[i].kind == "sizeRecord" then
				beaten = beaten + 1
			end
		end
		ns.CountCast(state.counts, record, getItem, beaten)
	end

	-- A Skill Reading (LED-R40): each Skill Milestone not yet credited, at or below its rank, ascending.
	---@param state LedgerState
	---@param record PagleSkillReading
	---@param earned LedgerAchievement[]
	local function applySkill(state, record, earned)
		for _, threshold in ipairs(ns.SKILL_MILESTONES) do
			if record.rank >= threshold and not state.skill[threshold] then
				state.skill[threshold] = record.time
				state.xp = state.xp + SKILL_MILESTONE_XP
				earned[#earned + 1] = { kind = "skillMilestone", coins = 0, threshold = threshold }
			end
		end
	end

	-- `activity` is Core's Activity XP total when a live entry is applied (LED-R37), so its levelUp counts the climb's
	-- Activity XP (LED-R38); nil (0) in a replay or rebuild, whose done adds the levels it brings (logic/Done.lua). The
	-- state never reads it: it holds the Coins of the climb's own levels only (LED-R88), the same in every mode.
	---@param state LedgerState
	---@param record PagleRecord
	---@param mode PagleApplyMode
	---@param earned LedgerAchievement[]?
	---@param activity integer? Core's Activity XP total
	---@return LedgerAchievement[]
	local function apply(state, record, mode, earned, activity) -- luacheck: no unused args (mode: the same in every mode, LED-R3)
		earned = earned or {}
		local kind = record.kind
		if kind == "module" then
			-- The Ledger's own Module records (LOG-R41): the crest record changes only `crest` (LED-R156).
			ns.NoteCrestRecord(state, record --[[@as PagleModuleRecord]])
			return earned
		elseif kind ~= "cast" and kind ~= "skill" and kind ~= "prestige" then
			return earned
		end
		activity = activity or 0
		local before, own, xp = ns.Level(state, activity), ns.OwnLevel(state), state.xp
		if kind == "cast" then
			applyCast(state, record --[[@as PagleCast]], earned)
		elseif kind == "skill" then
			applySkill(state, record --[[@as PagleSkillReading]], earned)
		else
			-- A new climb from level 1: its levels from the carried XP are the Prestige's (LED-R32).
			ns.ApplyPrestige(state, record --[[@as PaglePrestige]], earned)
			before, own, xp = 1, 1, state.xp
		end
		-- The Ledger's own XP, all told (LED-R150): a Prestige's carried XP is no new XP.
		state.lifetimeXP = state.lifetimeXP + state.xp - xp
		-- 20 Coins for each level the climb's own XP reaches (LED-R88); those its Activity XP adds are worked out.
		state.coins = state.coins + ns.LEVEL_UP_COINS * (ns.OwnLevel(state) - own)
		-- One levelUp per entry, however many levels it raised (LED-R97), with 20 Coins each for its moment.
		local after = ns.Level(state, activity)
		if after > before then
			local levels = {}
			for level = before + 1, after do
				levels[#levels + 1] = level
			end
			local coins = ns.LEVEL_UP_COINS * #levels
			earned[#earned + 1] =
				{ kind = "levelUp", cast = kind == "cast" and record.id or nil, coins = coins, levels = levels }
			-- The climb reaching 60 makes Prestige ready, once per climb, with that climb's rank (LED-R97).
			if after >= ns.LEVEL_CAP then
				earned[#earned + 1] = {
					kind = "prestigeReady",
					cast = kind == "cast" and record.id or nil,
					coins = 0,
					rank = state.prestige,
				}
			end
		end
		return earned
	end

	return { reset = reset, apply = apply }
end
