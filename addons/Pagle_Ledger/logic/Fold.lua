if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Ledger's fold (LED-R3): a pure function of the entries applied and the catalogue, the same in every mode.
-- Core's lookups are passed in (CORE-R7). M2's stage (LED-R4): classification without the Legend class or the
-- Uncharted list, the XP rows Catch XP, new Species, Species in a zone, first Catch in a zone and Skill Milestones,
-- Fresh Water, the first climb, Skill Milestones, lifetime Catches as a count, and Coins for level-ups and new Species.

--- The Ledger's projection state (ledger.md › Data, LedgerState), holding only what M2 fills. Levels, XP into the
--- level and Fresh Water shown are computed from it (logic/Progress.lua), never stored.
---@class LedgerState
---@field casts integer                       -- caught and got-away Casts applied (LED-R93)
---@field catches integer                     -- lifetime Catches (LED-R42)
---@field xp integer                          -- the climb's XP (LED-R31)
---@field prestige integer                    -- prestige rank: 0 until M4's Prestige
---@field fresh number                        -- Fresh Water F after the last Catch (LED-R22)
---@field lastCatch? integer                  -- server time of the last Catch's Cast
---@field coins integer                       -- lifetime Coins earned (LED-R88)
---@field skill { [integer]: integer }        -- Skill Milestone threshold -> time credited (LED-R40)
---@field species { [integer]: LedgerSpecies } -- by Species ID (LED-R5)
---@field zones { [integer]: LedgerZone }     -- every zone fished, never 0 (LED-R6)

--- A Species' Catches (ledger.md › Data, LedgerSpecies, M2's fields).
---@class LedgerSpecies
---@field n integer                           -- Catches of the Species
---@field zones { [integer]: true }           -- zones caught in (never 0)

--- A fished zone (ledger.md › Data, LedgerZone, M2's fields).
---@class LedgerZone
---@field species { [integer]: true }         -- Species caught here

--- What one `apply` earned (LED-R97's rows that M2 raises). `cast` is the Cast's entry ID (nil for a Skill
--- Reading) and `coins` its Coins (LED-R88; 0 when it pays none). Tickets #101 and #102 turn them into moments and
--- Write-up lines; the fold never reads the celebrated set (LED-R3).
---@class LedgerAchievement
---@field kind "levelUp"|"newSpecies"|"newInZone"|"skillMilestone"
---@field cast? string
---@field coins integer
---@field levels? integer[]                   -- levelUp: the levels it raised, ascending
---@field species? integer                    -- newSpecies, newInZone: the Species ID
---@field itemID? integer                     -- newSpecies, newInZone: the item caught
---@field zone? integer                       -- newSpecies, newInZone: the Cast's zone
---@field threshold? integer                  -- skillMilestone

--- The lookups the fold reads: Core's `Pagle.GetItem` (LOG-R55).
---@class LedgerLookups
---@field GetItem fun(itemID: integer): PagleItem?

--- The Ledger's fold (LED-R3).
---@class LedgerFold
---@field reset fun(): LedgerState
---@field apply fun(state: LedgerState, record: PagleRecord, mode: PagleApplyMode, earned: LedgerAchievement[]?): LedgerAchievement[]

--- The Ledger's rules version (LED-R2, LED-R4, Tunables): 1 in M2, 2 in M3, 3 in M4, then +1 per change.
ns.LEDGER_RULES_VERSION = 1

-- XP (LED-R20, Tunables), M2's rows.
local CATCH_XP = 10
local NEW_SPECIES_XP = 500
local SPECIES_IN_ZONE_XP = 100
local FIRST_IN_ZONE_XP = 200
local SKILL_MILESTONE_XP = 1000
-- Fresh Water's Catch XP multiplier (LED-R22, Tunables).
local FRESH_WATER_MULTIPLIER = 2
-- Coins (LED-R88), M2's rows.
local LEVEL_UP_COINS = 20
local NEW_SPECIES_COINS = 10
-- Skill Milestones, ascending (LED-R40, Tunables).
local SKILL_MILESTONES = { 75, 150, 225, 300 }

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

--- The class of one Catch (LED-R5), first match wins: "zero" (item 0), "uncharted" (GetItem knows nothing),
--- "noise", "species", "trophy", "curio" or "other". M2 has no Legend class: a Legend counts as its category (LED-R4).
---@param itemID integer
---@param item PagleItem?
---@return "zero"|"uncharted"|"noise"|"species"|"trophy"|"curio"|"other"
function ns.ClassifyCatch(itemID, item)
	if itemID == 0 then
		return "zero"
	elseif item == nil then
		return "uncharted"
	elseif item.noise then
		return "noise"
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
		prestige = 0,
		fresh = ns.FRESH_WATER_CAP,
		coins = 0,
		skill = {},
		species = {},
		zones = {},
	}
end

--- The Ledger's fold over Core's lookups (LED-R3). `apply` folds one record into the state and appends what it earned
--- to `earned` (a new list if none is passed), which it returns. `mode` is Core's apply mode (LOG-R75); the fold is the
--- same in every mode.
---@param lookups LedgerLookups
---@return LedgerFold
function ns.NewLedgerFold(lookups)
	local getItem = lookups.GetItem

	---@param state LedgerState
	---@param record PagleCast
	---@param earned LedgerAchievement[]
	local function applyCast(state, record, earned)
		state.casts = state.casts + 1
		if record.outcome ~= "caught" then
			return
		end
		local zone = record.conditions.zone
		for _, catch in ipairs(record.items) do
			local itemID = catch.itemID
			local item = itemID ~= 0 and getItem(itemID) or nil
			-- The base, for every class (LED-R5): lifetime Catches, Catch XP with Fresh Water, the zone fished.
			state.catches = state.catches + 1
			state.xp = state.xp + CATCH_XP * spendFreshWater(state, record.time)
			local zoneState
			if zone ~= 0 then
				zoneState = state.zones[zone]
				if not zoneState then
					zoneState = { species = {} }
					state.zones[zone] = zoneState
					state.xp = state.xp + FIRST_IN_ZONE_XP
				end
			end
			local id = item and ns.ClassifyCatch(itemID, item) == "species" and item.species or nil
			if id then
				local species = state.species[id]
				local new = not species
				if not species then
					species = { n = 0, zones = {} }
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
			end
		end
	end

	-- A Skill Reading (LED-R40): each Skill Milestone not yet credited, at or below its rank, ascending.
	---@param state LedgerState
	---@param record PagleSkillReading
	---@param earned LedgerAchievement[]
	local function applySkill(state, record, earned)
		for _, threshold in ipairs(SKILL_MILESTONES) do
			if record.rank >= threshold and not state.skill[threshold] then
				state.skill[threshold] = record.time
				state.xp = state.xp + SKILL_MILESTONE_XP
				earned[#earned + 1] = { kind = "skillMilestone", coins = 0, threshold = threshold }
			end
		end
	end

	---@param state LedgerState
	---@param record PagleRecord
	---@param mode PagleApplyMode
	---@param earned LedgerAchievement[]?
	---@return LedgerAchievement[]
	local function apply(state, record, mode, earned) -- luacheck: no unused args (mode: the same in every mode, LED-R3)
		earned = earned or {}
		local kind = record.kind
		if kind ~= "cast" and kind ~= "skill" then
			return earned
		end
		local before = ns.Level(state)
		if kind == "cast" then
			applyCast(state, record --[[@as PagleCast]], earned)
		else
			applySkill(state, record --[[@as PagleSkillReading]], earned)
		end
		-- One levelUp per entry, however many levels it raised (LED-R97), with 20 Coins each (LED-R88).
		local after = ns.Level(state)
		if after > before then
			local levels = {}
			for level = before + 1, after do
				levels[#levels + 1] = level
			end
			local coins = LEVEL_UP_COINS * #levels
			state.coins = state.coins + coins
			earned[#earned + 1] =
				{ kind = "levelUp", cast = kind == "cast" and record.id or nil, coins = coins, levels = levels }
		end
		return earned
	end

	return { reset = reset, apply = apply }
end
