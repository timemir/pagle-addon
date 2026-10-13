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

-- Adds every achievement in the state to the celebrated set (LED-R93's first build), and the zones it fished.
---@param celebrated LedgerCelebrated
---@param state LedgerState
local function celebrateAll(celebrated, state)
	local level = ns.Level(state)
	if level > (celebrated.levels[state.prestige] or 0) then
		celebrated.levels[state.prestige] = level
	end
	for id, species in pairs(state.species) do
		celebrated.species[id] = true
		for zone in pairs(species.zones) do
			celebrated.speciesZones[id .. ":" .. zone] = true
		end
	end
	for threshold in pairs(state.skill) do
		celebrated.skill[threshold] = true
	end
	for zone in pairs(state.zones) do
		if celebrated.zones[zone] == nil then
			celebrated.zones[zone] = 0
		end
	end
end

-- The Coins line (LED-R94): the Coins earned since the celebrated total, only when above 0.
---@param lines string[]
---@param coins integer
---@param outlets LedgerOutlets
local function addCoinsLine(lines, coins, outlets)
	if coins > 0 then
		lines[#lines + 1] = ns.L.WRITE_UP_COINS:format(outlets.FormatNumber(coins))
	end
end

-- A first build (LED-R93, LED-R94, LED-R192): everything in the state celebrated, with no moment, and one section
-- listing it, headed by the Casts applied. A state with no Cast raises nothing (LOG-R76).
---@param celebrated LedgerCelebrated
---@param state LedgerState
---@param coinsBefore integer the celebrated Coins before this done
---@param outlets LedgerOutlets
local function firstBuild(celebrated, state, coinsBefore, outlets)
	celebrateAll(celebrated, state)
	if state.casts == 0 then
		return
	end
	local L = ns.L
	local lines = { L.WRITE_UP_LEVEL:format(ns.ShownLevel(state, celebrated)) }
	local species = count(state.species)
	if species > 0 then
		lines[#lines + 1] = ns.CountText(species, L.WRITE_UP_SPECIES_ONE, L.WRITE_UP_SPECIES_OTHER)
	end
	local skill = count(state.skill)
	if skill > 0 then
		lines[#lines + 1] = ns.CountText(skill, L.WRITE_UP_SKILL_ONE, L.WRITE_UP_SKILL_OTHER)
	end
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

-- The moments of the scratch list's achievements not yet celebrated, each added to the set (LED-R91, LED-R93).
---@param celebrated LedgerCelebrated
---@param state LedgerState
---@param scratch LedgerAchievement[]
---@param outlets LedgerOutlets
---@return PagleMoment[]
local function celebrateScratch(celebrated, state, scratch, outlets)
	local moments = {}
	for _, achievement in ipairs(mergeLevelUps(scratch)) do
		local moment = ns.CelebrateAchievement(celebrated, state, achievement, outlets)
		if moment then
			moments[#moments + 1] = moment
		end
	end
	return moments
end

-- A catch-up (LED-R93, LED-R94, LED-R190): what the replayed entries newly earned, celebrated with no moment and
-- counted in one "While the Ledger was off" section. A Species new in a zone has no line: alone, it raises none.
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
	local moments = celebrateScratch(celebrated, state, scratch, outlets)
	if #moments == 0 then
		return
	end
	local kinds = { levelUp = 0, newSpecies = 0, newInZone = 0, skillMilestone = 0 }
	for _, moment in ipairs(moments) do
		kinds[moment.kind] = kinds[moment.kind] + 1
	end
	local L = ns.L
	local lines = {}
	if kinds.levelUp > 0 then
		lines[#lines + 1] = L.WRITE_UP_LEVEL_ROSE:format(before, ns.ShownLevel(state, celebrated))
	end
	if kinds.newSpecies > 0 then
		lines[#lines + 1] = ns.CountText(kinds.newSpecies, L.WRITE_UP_SPECIES_ONE, L.WRITE_UP_SPECIES_OTHER)
	end
	if kinds.skillMilestone > 0 then
		lines[#lines + 1] = ns.CountText(kinds.skillMilestone, L.WRITE_UP_SKILL_ONE, L.WRITE_UP_SKILL_OTHER)
	end
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
---@return LedgerCelebrated
function ns.CelebrateDone(global, state, scratch, info, outlets)
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
		firstBuild(celebrated, state, coinsBefore, outlets)
	elseif info.rebuilt then
		-- Raised as live, but summary-only: no pop-up (LED-R191, ANN-R63).
		for _, moment in ipairs(celebrateScratch(celebrated, state, scratch, outlets)) do
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
