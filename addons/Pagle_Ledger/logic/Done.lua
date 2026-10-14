if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- What the Ledger does when its projection finishes a catch-up or rebuild (LED-R93): a Write-up for history it never
-- saw, summary-only moments for what a rebuild newly earned, and nothing that pops up. Pure logic, everything passed
-- in (CORE-R7).

-- Title lines a Write-up lists before "+{k} more titles" (LED-R94, Tunables).
local TITLE_LINES = 3
-- The title held from the start, which no Write-up lists (LED-R75).
local FROM_THE_START = "title:level1"

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

-- Adds every achievement in the state to the celebrated set (LED-R93's first build): the level, the prestige rank,
-- Species and their stars, Species × zone pairs, Skill and Catch Milestones, the zones fished at their computed rank,
-- curio, trophy and Legend items, their families' stars, the Uncharted items and the titles earned.
---@param celebrated LedgerCelebrated
---@param state LedgerState
---@param lookups LedgerLookups
local function celebrateAll(celebrated, state, lookups)
	local world, getItem = lookups.world, lookups.GetItem
	local level = ns.Level(state)
	if level > (celebrated.levels[state.prestige] or 0) then
		celebrated.levels[state.prestige] = level
	end
	-- Each earlier climb is history written up whole: its 60 stands for its Prestige ready too (LED-R90).
	for rank = 0, state.prestige - 1 do
		celebrated.levels[rank] = math.max(celebrated.levels[rank] or 0, ns.LEVEL_CAP)
	end
	celebrated.prestige = math.max(celebrated.prestige, state.prestige)
	for n in pairs(state.milestones) do
		celebrated.milestones[n] = true
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
	-- After the zones: a Zone Master title follows the shown rank (LED-R75).
	for _, key in ipairs(ns.TitleKeys({ world = world, state = state, celebrated = celebrated, getItem = getItem })) do
		celebrated.titles[key] = true
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
---@field legends integer        -- Legend items
---@field catches integer        -- the highest Catch Milestone reached, 0 for none new
---@field titles string[]        -- title keys, in LED-R75's order

-- The title lines (LED-R94): "Title: {title}" for each of the first 3 with a name (LED-R161), then "+{k} more
-- titles".
---@param lines string[]
---@param keys string[] in LED-R75's order
---@param outlets LedgerOutlets
local function addTitleLines(lines, keys, outlets)
	local L = ns.L
	local names = ns.TitleNames(keys, outlets)
	for i = 1, math.min(#names, TITLE_LINES) do
		lines[#lines + 1] = L.TITLE_LINE:format(names[i])
	end
	if #names > TITLE_LINES then
		lines[#lines + 1] = ns.CountText(#names - TITLE_LINES, L.WRITE_UP_MORE_TITLES_ONE, L.WRITE_UP_MORE_TITLES_OTHER)
	end
end

-- Write-up lines after the level's, in LED-R94's order: Species, zones ranked and mastered, trophy weights, curios,
-- Legends, Skill Milestones, the Catch Milestone and titles. Stars and Uncharted items have none.
---@param lines string[] holding the level's line, when there is one
---@param counts LedgerWriteUpCounts
---@param outlets LedgerOutlets
local function addLines(lines, counts, outlets)
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
	if counts.legends > 0 then
		lines[#lines + 1] = ns.CountText(counts.legends, L.WRITE_UP_LEGENDS_ONE, L.WRITE_UP_LEGENDS_OTHER)
	end
	if counts.skill > 0 then
		lines[#lines + 1] = ns.CountText(counts.skill, L.WRITE_UP_SKILL_ONE, L.WRITE_UP_SKILL_OTHER)
	end
	if counts.catches > 0 then
		local n = counts.catches
		lines[#lines + 1] = (n == 1 and L.CATCHES_ONE or L.CATCHES_OTHER):format(outlets.FormatNumber(n))
	end
	addTitleLines(lines, counts.titles, outlets)
end

-- The level's line with " · Prestige {R}" when the rank is above 0 (LED-R94).
---@param line string
---@param rank integer
---@return string
local function withPrestige(line, rank)
	return rank > 0 and ns.L.WRITE_UP_WITH_PRESTIGE:format(line, rank) or line
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

-- What a first build's section counts (LED-R94): everything in the state, zones by their shown rank, every title
-- earned but the one held from the start (LED-R75).
---@param celebrated LedgerCelebrated
---@param state LedgerState
---@param lookups LedgerLookups
---@return LedgerWriteUpCounts
local function stateCounts(celebrated, state, lookups)
	local world = lookups.world
	local counts = {
		species = count(state.species),
		zones = 0,
		mastered = 0,
		trophy = 0,
		curio = 0,
		skill = count(state.skill),
		legends = 0,
		catches = 0,
		titles = {},
	}
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
		elseif class == "legend" then
			counts.legends = counts.legends + 1
		end
	end
	for n in pairs(state.milestones) do
		counts.catches = math.max(counts.catches, n)
	end
	local view = { world = world, state = state, celebrated = celebrated, getItem = lookups.GetItem }
	for _, key in ipairs(ns.TitleKeys(view)) do
		if key ~= FROM_THE_START then
			counts.titles[#counts.titles + 1] = key
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
	local lines = { withPrestige(L.WRITE_UP_LEVEL:format(ns.ShownLevel(state, celebrated)), state.prestige) }
	addLines(lines, stateCounts(celebrated, state, lookups), outlets)
	addCoinsLine(lines, state.coins - coinsBefore, outlets)
	local heading = state.casts == 1 and L.WRITE_UP_FIRST_BUILD_ONE or L.WRITE_UP_FIRST_BUILD_OTHER
	outlets.RaiseWriteUp({ heading = heading:format(outlets.FormatNumber(state.casts)), lines = lines })
end

-- The scratch list's achievements with each climb's level-ups merged into one, at that climb's last one's place:
-- every level they raised in it, that entry's `cast` and the climb's rank (LED-R93), so a Prestige among them never
-- mixes two climbs' levels. celebrate.levelUp then pays it for the levels above the climb's celebrated one. Size
-- records are left out: only live Catches raise them (LED-R84).
---@param scratch LedgerAchievement[]
---@param rank integer the state's prestige rank, for a level-up the scratch list didn't mark with its climb
---@return LedgerAchievement[]
local function mergeLevelUps(scratch, rank)
	---@type { [integer]: integer[] }
	local levels = {}
	---@type { [integer]: integer }
	local last = {}
	for i, achievement in ipairs(scratch) do
		if achievement.kind == "levelUp" then
			local climb = achievement.rank or rank
			levels[climb] = levels[climb] or {}
			for _, level in
				ipairs(achievement.levels --[[@as integer[] ]])
			do
				table.insert(levels[climb], level)
			end
			last[climb] = i
		end
	end
	local merged = {}
	for i, achievement in ipairs(scratch) do
		local kind = achievement.kind
		if kind == "levelUp" then
			local climb = achievement.rank or rank
			if last[climb] == i then
				local raised = levels[climb]
				merged[#merged + 1] = {
					kind = "levelUp",
					cast = achievement.cast,
					coins = ns.LEVEL_UP_COINS * #raised,
					levels = raised,
					rank = climb,
				}
			end
		elseif kind ~= "sizeRecord" then
			merged[#merged + 1] = achievement
		end
	end
	return merged
end

-- The moments of the scratch list's achievements not yet celebrated, each added to the set (LED-R91, LED-R93), the
-- achievement each was raised for, and the titles newly earned (LED-R75).
---@param celebrated LedgerCelebrated
---@param state LedgerState
---@param scratch LedgerAchievement[]
---@param outlets LedgerOutlets
---@param lookups LedgerLookups
---@return PagleMoment[] moments
---@return LedgerAchievement[] achievements
---@return string[] titles
local function celebrateScratch(celebrated, state, scratch, outlets, lookups)
	return ns.CelebrateEarned(celebrated, state, mergeLevelUps(scratch, state.prestige), outlets, lookups)
end

-- What a catch-up's section counts (LED-R94): only the moments it newly celebrated, a zone counted once however many
-- of its ranks rose, as ranked, and as mastered when one of them was its Zone Master; the highest Catch Milestone
-- among them; the titles newly earned.
---@param moments PagleMoment[]
---@param achievements LedgerAchievement[] the achievement of each moment
---@param titles string[] the title keys newly celebrated
---@param rank integer the current climb's prestige rank
---@return LedgerWriteUpCounts counts
---@return boolean levelUp a level-up of the current climb among them
---@return boolean prestige a Prestige among them
local function newCounts(moments, achievements, titles, rank)
	local counts = {
		species = 0,
		zones = 0,
		mastered = 0,
		trophy = 0,
		curio = 0,
		skill = 0,
		legends = 0,
		catches = 0,
		titles = titles,
	}
	local kinds = {
		newSpecies = "species",
		trophyWeight = "trophy",
		newCurio = "curio",
		skillMilestone = "skill",
		legend = "legends",
	}
	local ranked, mastered, levelUp, prestige = {}, {}, false, false
	for i, moment in ipairs(moments) do
		local kind, achievement = moment.kind, achievements[i]
		if kinds[kind] then
			counts[kinds[kind]] = counts[kinds[kind]] + 1
		elseif kind == "zoneRank" or kind == "zoneMaster" then
			local zone = achievement.zone --[[@as integer]]
			ranked[zone] = true
			mastered[zone] = mastered[zone] or kind == "zoneMaster" or nil
		elseif kind == "catchMilestone" then
			counts.catches = math.max(counts.catches, achievement.n --[[@as integer]])
		elseif kind == "levelUp" then
			levelUp = levelUp or (achievement.rank or rank) == rank
		elseif kind == "prestige" then
			prestige = true
		end
	end
	counts.zones, counts.mastered = count(ranked), count(mastered)
	return counts, levelUp, prestige
end

-- A catch-up (LED-R93, LED-R94, LED-R190): what the replayed entries newly earned, celebrated with no moment and
-- counted in one "While the Ledger was off" section. Achievements with no line (a Species new in a zone, stars,
-- Uncharted items, size records) alone raise none. The level line is the current climb's, with the rank; a Prestige
-- among them gives it even when that climb's level didn't rise.
---@param celebrated LedgerCelebrated
---@param state LedgerState
---@param scratch LedgerAchievement[]
---@param coinsBefore integer the celebrated Coins before this done
---@param outlets LedgerOutlets
---@param lookups LedgerLookups
local function catchUp(celebrated, state, scratch, coinsBefore, outlets, lookups)
	local rank = state.prestige
	-- The shown level before the catch-up (LED-R36): the celebrated one, or the one its first level-up left.
	local before = celebrated.levels[rank] or 1
	for _, achievement in ipairs(scratch) do
		if achievement.kind == "levelUp" and (achievement.rank or rank) == rank then
			before = math.max(before, achievement.levels[1] - 1)
			break
		end
	end
	local moments, achievements, titles = celebrateScratch(celebrated, state, scratch, outlets, lookups)
	if #moments == 0 and #titles == 0 then
		return
	end
	local counts, levelUp, prestige = newCounts(moments, achievements, titles, rank)
	local L = ns.L
	local lines = {}
	local shown = ns.ShownLevel(state, celebrated)
	if levelUp then
		lines[1] = withPrestige(L.WRITE_UP_LEVEL_ROSE:format(before, shown), rank)
	elseif prestige then
		lines[1] = withPrestige(L.WRITE_UP_LEVEL:format(shown), rank)
	end
	addLines(lines, counts, outlets)
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
---@param lookups LedgerLookups the fold's: the world index and Core's GetItem, for the stars, titles and lines
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
		for _, moment in ipairs((celebrateScratch(celebrated, state, scratch, outlets, lookups))) do
			moment.summaryOnly = true
			outlets.RaiseMoment(moment)
		end
	elseif info.replayed > 0 then
		catchUp(celebrated, state, scratch, coinsBefore, outlets, lookups)
	end
	celebrated.coins = state.coins
	outlets.ReportCoinsEarned(state.coins)
	return celebrated
end
