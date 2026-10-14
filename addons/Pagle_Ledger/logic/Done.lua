if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- What the Ledger does when its projection finishes a catch-up or rebuild (LED-R93): a Write-up for history it never
-- saw, summary-only moments for what a rebuild newly earned, and nothing that pops up. Pure logic, everything passed
-- in (CORE-R7).

-- The number of keys in `set`.
---@param set table
---@return integer
local function count(set)
	local n = 0
	for _ in pairs(set) do
		n = n + 1
	end
	return n
end

-- The stars set in `stars` ({ [1|2|3] = true }), ascending.
---@param stars LedgerStars
---@return integer[]
local function starList(stars)
	local list = {}
	for star = 1, 3 do
		if stars[star] then
			list[#list + 1] = star
		end
	end
	return list
end

-- Adds every achievement in the state to the celebrated set (LED-R93's first build): the level, Species and their
-- stars, Species × zone pairs, Skill Milestones, the zones fished at their computed rank, curio and trophy items, their
-- families' stars and the Uncharted items.
---@param celebrated LedgerCelebrated
---@param state LedgerState
---@param lookups LedgerLookups
local function celebrateAll(celebrated, state, lookups)
	local world, getItem = lookups.world, lookups.GetItem
	local level = ns.Level(state)
	if level > (celebrated.levels[state.prestige] or 0) then
		celebrated.levels[state.prestige] = level
	end
	for id, species in pairs(state.species) do
		celebrated.species[id] = true
		ns.CelebrateStars(celebrated.stars, id, starList(ns.SpeciesStars(world, state, id)))
		for zone in pairs(species.zones) do
			celebrated.speciesZones[id .. ":" .. zone] = true
		end
	end
	for threshold in pairs(state.skill) do
		celebrated.skill[threshold] = true
	end
	for zone, zoneState in pairs(state.zones) do
		celebrated.zones[zone] = math.max(celebrated.zones[zone] or 0, zoneState.rank)
	end
	for itemID in pairs(state.items) do
		celebrated.items[itemID] = true
		local item = getItem(itemID)
		if item and item.category == "trophy" and item.family then
			local stars = ns.FamilyStars(world, state, item.family, getItem)
			ns.CelebrateStars(celebrated.familyStars, item.family, starList(stars))
		end
	end
	for itemID in pairs(state.uncharted) do
		celebrated.uncharted[itemID] = true
	end
end

--- What a Write-up section counts (LED-R94); each line only when its count is above 0.
---@class LedgerWriteUpCounts
---@field species integer        -- Species
---@field zones integer          -- zones ranked: with a shown rank
---@field mastered integer       -- of those, at Master
---@field trophy integer         -- trophy weights
---@field curio integer          -- curio items
---@field skill integer          -- Skill Milestones

-- Write-up lines after the level's, in LED-R94's order: Species, zones ranked and mastered, trophy weights, curios
-- and Skill Milestones. Stars and Uncharted items have none.
---@param lines string[] holding the level's line, when there is one
---@param counts LedgerWriteUpCounts
local function addLines(lines, counts)
	local L = ns.L
	if counts.species > 0 then
		lines[#lines + 1] = ns.CountText(counts.species, L.WRITE_UP_SPECIES_ONE, L.WRITE_UP_SPECIES_OTHER)
	end
	if counts.zones > 0 then
		local zones = ns.CountText(counts.zones, L.WRITE_UP_ZONES_ONE, L.WRITE_UP_ZONES_OTHER)
		if counts.mastered > 0 then
			local mastered = ns.CountText(counts.mastered, L.WRITE_UP_MASTERED_ONE, L.WRITE_UP_MASTERED_OTHER)
			zones = L.WRITE_UP_ZONES_MASTERED:format(zones, mastered)
		end
		lines[#lines + 1] = zones
	end
	if counts.trophy > 0 then
		lines[#lines + 1] = ns.CountText(counts.trophy, L.WRITE_UP_TROPHY_ONE, L.WRITE_UP_TROPHY_OTHER)
	end
	if counts.curio > 0 then
		lines[#lines + 1] = ns.CountText(counts.curio, L.WRITE_UP_CURIO_ONE, L.WRITE_UP_CURIO_OTHER)
	end
	if counts.skill > 0 then
		lines[#lines + 1] = ns.CountText(counts.skill, L.WRITE_UP_SKILL_ONE, L.WRITE_UP_SKILL_OTHER)
	end
end

-- The Coins line (LED-R94), last: the Coins earned since the celebrated total, only when above 0.
---@param lines string[]
---@param coins integer
---@param outlets LedgerOutlets
local function addCoinsLine(lines, coins, outlets)
	if coins > 0 then
		lines[#lines + 1] = ns.L.WRITE_UP_COINS:format(outlets.FormatNumber(coins))
	end
end

-- What a first build's section counts (LED-R94): everything in the state, zones by their shown rank.
---@param celebrated LedgerCelebrated
---@param state LedgerState
---@param lookups LedgerLookups
---@return LedgerWriteUpCounts
local function stateCounts(celebrated, state, lookups)
	local world = lookups.world
	local counts =
		{ species = count(state.species), zones = 0, mastered = 0, trophy = 0, curio = 0, skill = count(state.skill) }
	for _, zone in ipairs(world.charted) do
		local rank = ns.ShownZoneRank(world, state, celebrated, zone)
		if rank > 0 then
			counts.zones = counts.zones + 1
		end
		if rank == ns.ZONE_MASTER then
			counts.mastered = counts.mastered + 1
		end
	end
	for itemID in pairs(state.items) do
		local class = ns.ClassifyCatch(itemID, lookups.GetItem(itemID))
		if class == "trophy" or class == "curio" then
			counts[class] = counts[class] + 1
		end
	end
	return counts
end

-- A first build (LED-R93, LED-R94, LED-R192): everything in the state celebrated, with no moment, and one section
-- listing it, headed by the Casts applied. A state with no Cast raises nothing (LOG-R76).
---@param celebrated LedgerCelebrated
---@param state LedgerState
---@param coinsBefore integer the celebrated Coins before this done
---@param outlets LedgerOutlets
---@param lookups LedgerLookups
local function firstBuild(celebrated, state, coinsBefore, outlets, lookups)
	celebrateAll(celebrated, state, lookups)
	if state.casts == 0 then
		return
	end
	local L = ns.L
	local lines = { L.WRITE_UP_LEVEL:format(ns.ShownLevel(state, celebrated)) }
	addLines(lines, stateCounts(celebrated, state, lookups))
	addCoinsLine(lines, state.coins - coinsBefore, outlets)
	local heading = state.casts == 1 and L.WRITE_UP_FIRST_BUILD_ONE or L.WRITE_UP_FIRST_BUILD_OTHER
	outlets.RaiseWriteUp({ heading = heading:format(outlets.FormatNumber(state.casts)), lines = lines })
end

-- The scratch list's achievements with its level-ups merged into one, at the last one's place: every level they
-- raised, that entry's `cast` (LED-R93). celebrate.levelUp then pays it for the levels above the celebrated one.
---@param scratch LedgerAchievement[]
---@return LedgerAchievement[]
local function mergeLevelUps(scratch)
	local levels, last = {}, nil
	for i, achievement in ipairs(scratch) do
		if achievement.kind == "levelUp" then
			local raised = achievement.levels --[[@as integer[] ]]
			for _, level in ipairs(raised) do
				levels[#levels + 1] = level
			end
			last = i
		end
	end
	local merged = {}
	for i, achievement in ipairs(scratch) do
		if i == last then
			merged[#merged + 1] =
				{ kind = "levelUp", cast = achievement.cast, coins = ns.LEVEL_UP_COINS * #levels, levels = levels }
		elseif achievement.kind ~= "levelUp" then
			merged[#merged + 1] = achievement
		end
	end
	return merged
end

-- The moments of the scratch list's achievements not yet celebrated, each added to the set (LED-R91, LED-R93), and
-- the achievement each was raised for.
---@param celebrated LedgerCelebrated
---@param state LedgerState
---@param scratch LedgerAchievement[]
---@param outlets LedgerOutlets
---@return PagleMoment[] moments
---@return LedgerAchievement[] achievements
local function celebrateScratch(celebrated, state, scratch, outlets)
	local moments, achievements = {}, {}
	for _, achievement in ipairs(mergeLevelUps(scratch)) do
		local moment = ns.CelebrateAchievement(celebrated, state, achievement, outlets)
		if moment then
			moments[#moments + 1] = moment
			achievements[#achievements + 1] = achievement
		end
	end
	return moments, achievements
end

-- What a catch-up's section counts (LED-R94): only the moments it newly celebrated, a zone counted once however many
-- of its ranks rose, as ranked, and as mastered when one of them was its Zone Master.
---@param moments PagleMoment[]
---@param achievements LedgerAchievement[] the achievement of each moment
---@return LedgerWriteUpCounts counts
---@return boolean levelUp a level-up among them
local function newCounts(moments, achievements)
	local counts = { species = 0, zones = 0, mastered = 0, trophy = 0, curio = 0, skill = 0 }
	local kinds = { newSpecies = "species", trophyWeight = "trophy", newCurio = "curio", skillMilestone = "skill" }
	local ranked, mastered, levelUp = {}, {}, false
	for i, moment in ipairs(moments) do
		local kind = moment.kind
		if kinds[kind] then
			counts[kinds[kind]] = counts[kinds[kind]] + 1
		elseif kind == "zoneRank" or kind == "zoneMaster" then
			local zone = achievements[i].zone --[[@as integer]]
			ranked[zone] = true
			mastered[zone] = mastered[zone] or kind == "zoneMaster" or nil
		elseif kind == "levelUp" then
			levelUp = true
		end
	end
	counts.zones, counts.mastered = count(ranked), count(mastered)
	return counts, levelUp
end

-- A catch-up (LED-R93, LED-R94, LED-R190): what the replayed entries newly earned, celebrated with no moment and
-- counted in one "While the Ledger was off" section. Achievements with no line (a Species new in a zone, stars,
-- Uncharted items) alone raise none.
---@param celebrated LedgerCelebrated
---@param state LedgerState
---@param scratch LedgerAchievement[]
---@param coinsBefore integer the celebrated Coins before this done
---@param outlets LedgerOutlets
local function catchUp(celebrated, state, scratch, coinsBefore, outlets)
	-- The shown level before the catch-up (LED-R36): the celebrated one, or the one its first level-up left.
	local before = celebrated.levels[state.prestige] or 1
	for _, achievement in ipairs(scratch) do
		if achievement.kind == "levelUp" then
			before = math.max(before, achievement.levels[1] - 1)
			break
		end
	end
	local moments, achievements = celebrateScratch(celebrated, state, scratch, outlets)
	if #moments == 0 then
		return
	end
	local counts, levelUp = newCounts(moments, achievements)
	local L = ns.L
	local lines = {}
	if levelUp then
		lines[1] = L.WRITE_UP_LEVEL_ROSE:format(before, ns.ShownLevel(state, celebrated))
	end
	addLines(lines, counts)
	addCoinsLine(lines, state.coins - coinsBefore, outlets)
	if #lines > 0 then
		outlets.RaiseWriteUp({ heading = L.WRITE_UP_WHILE_OFF, lines = lines })
	end
end

--- The projection's done (LED-R93), up to the summary line, which the def sets: the celebrated set emptied for a new
--- log, then the first build's, rebuild's or catch-up's celebration, then the Coins total kept and reported (LED-R89).
---@param global table PagleLedgerDB's global section
---@param state LedgerState
---@param scratch LedgerAchievement[] what the replayed or rebuilt entries earned (LED-R98)
---@param info PagleProjectionInfo
---@param outlets LedgerOutlets
---@param lookups LedgerLookups the fold's: the world index and Core's GetItem, for the first build's stars and lines
---@return LedgerCelebrated
function ns.CelebrateDone(global, state, scratch, info, outlets, lookups)
	local celebrated = ns.CelebratedSet(global)
	local first = info.firstBuild
	-- A set of another log is emptied, and this done is a first build (LED-R90, LED-R197).
	local logId = outlets.LogId()
	if celebrated.logId ~= logId then
		global.celebrated = { logId = logId }
		celebrated = ns.CelebratedSet(global)
		first = true
	end
	local coinsBefore = celebrated.coins
	if first then
		firstBuild(celebrated, state, coinsBefore, outlets, lookups)
	elseif info.rebuilt then
		-- Raised as live, but summary-only: no pop-up (LED-R191, ANN-R63).
		for _, moment in ipairs((celebrateScratch(celebrated, state, scratch, outlets))) do
			moment.summaryOnly = true
			outlets.RaiseMoment(moment)
		end
	elseif info.replayed > 0 then
		catchUp(celebrated, state, scratch, coinsBefore, outlets)
	end
	celebrated.coins = state.coins
	outlets.ReportCoinsEarned(state.coins)
	return celebrated
end
