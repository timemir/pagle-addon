if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- What Pagle's backend reads from the Ledger's state (#223, #76 item 5): its projection driver folds the Catch log
-- through logic/ alone and computes none of these itself, so each is a function of a projection state, read through
-- the world index the projection was bound with (ns.world: the adapter's OnInitialize sets it, and ns.BindProjections
-- in the driver). Each counts what the state computes, never the celebrated set, which never leaves the client
-- (LOG-R77). Pure logic (CORE-R7).

---@class LedgerMeasures
---@field anglerLevel { prestige: integer, level: integer, xp: integer }   -- prestige rank, the climb's level and XP
---@field ledgerCompletion { percent: integer, done: integer, total: integer } -- LED-R70, the percentage floored
---@field speciesCaught integer   -- Species caught, removed ones left out (LED-R71's species part)
---@field legendsCaught integer   -- distinct Legends caught, removed ones left out (LED-R63)

-- The title view of a state alone: no celebrated set, no stored active title.
---@param state LedgerState
---@return LedgerTitleView
local function computedView(state)
	return { world = ns.world, state = state, celebrated = {}, getItem = ns.world.getItem }
end

--- The four leaderboard measures of a Ledger state: the Angler Level (LED-R30–R32), Ledger completion (LED-R70,
--- LED-R71), Species caught and Legends caught (LED-R63). Every number is a whole number, 0 or more.
---@param state LedgerState
---@return LedgerMeasures
function ns.Measures(state)
	local completion = ns.LedgerCompletion(ns.world, state)
	return {
		anglerLevel = { prestige = state.prestige, level = ns.Level(state), xp = state.xp },
		ledgerCompletion = { percent = completion.percent, done = completion.done, total = completion.total },
		speciesCaught = completion.species.done,
		legendsCaught = completion.legends.done,
	}
end

--- The title keys a Ledger state earns (LED-R75, LED-R76), in LED-R75's order: computed only, so a title the
--- celebrated set keeps after a rebalance isn't listed.
---@param state LedgerState
---@return string[]
function ns.EarnedTitles(state)
	return ns.TitleKeys(computedView(state))
end

--- The automatic title's key (LED-R77): the highest level title a Ledger state earns, or nil with none.
---@param state LedgerState
---@return string?
function ns.AutomaticTitle(state)
	return (ns.ActiveTitle(computedView(state)))
end

--- The charted zones a Ledger state ranks Master (LED-R50, LED-R71): Ledger completion's zone part.
---@param state LedgerState
---@return integer
function ns.ZonesMastered(state)
	return ns.LedgerCompletion(ns.world, state).zones.done
end

--- A Ledger state's lifetime Catches (LED-R42).
---@param state LedgerState
---@return integer
function ns.LifetimeCatches(state)
	return state.catches
end

--- The release's Legends (PRJ-R15): the item IDs of every Legend LED-R63's "x of N" counts for an Angler with no
--- Catches, so listed and not removed (LED-R11, LED-R12), ascending. Empty when the release lists none.
---@return integer[]
function ns.LegendList()
	local noCatches = {} -- CollectionWorlds reads only `species` and `items`, each empty when missing
	return ns.CollectionWorlds(ns.world, noCatches --[[@as LedgerState]]).legends
end

-- Stars as the Journal values write them: three booleans.
---@param stars LedgerStars
---@return boolean[]
local function starList(stars)
	return { stars[1] == true, stars[2] == true, stars[3] == true }
end

-- Whether an item is removed (LED-R12).
---@param itemID integer
---@return boolean
local function removed(itemID)
	local item = ns.world.getItem(itemID)
	return item ~= nil and item.removed == true
end

--- The Ledger's Journal values for Pagle's backend (#223, the Angler page's Journal values), from a state, the world
--- index and Core's Pagle API (the characters' Skill Readings and the zones' continents):
--- - `level`: XP into the level, the next step's cost (nil at 60) and the carried XP (0 below 60) (LED-R30, LED-R145);
--- - `parts`: each part of Ledger completion as { done, total } (LED-R71);
--- - `titles`: ns.EarnedTitles; `nextCatchMilestone` (nil after the last, LED-R42);
--- - `skillMilestones`: every threshold, ascending, with whether it is credited (LED-R40);
--- - `characters`: each character with a Skill Reading, by index: its latest rank and max (LED-R41);
--- - `zones`: a tile per charted zone and per fished uncharted one, in tile order (LED-R131): its continent (nil
---   when Core doesn't know the area), charted, computed rank (0 unfished or uncharted) and completion (nil
---   uncharted) (LED-R50, LED-R53, LED-R54);
--- - `species`: every Species of the world by ID: caught, computed stars, removed (LED-R11, LED-R12, LED-R45);
--- - `legends`: LED-R63's N, removed Legends left out, and every caught Legend by item ID, with removed;
--- - `trophies`: every listed trophy family by ID: computed stars and its listed weights, lightest first, each with
---   whether it is landed (LED-R47, LED-R61).
---@param state LedgerState
---@param sessionRows integer
---@return table
function ns.JournalValues(state, sessionRows) -- luacheck: no unused args (the driver's one shape for every Module)
	local pagle = Pagle -- luacheck: read globals Pagle (#223: the Angler's Skill Readings and the areas, from Core)
	local world = ns.world
	local completion = ns.LedgerCompletion(world, state)

	local level, into, cost = ns.ClimbOf(state.xp, state.prestige)
	local parts = {}
	for _, part in ipairs(ns.COMPLETION_PARTS) do
		parts[part] = { completion[part].done, completion[part].total }
	end

	local skillMilestones = {}
	for i, threshold in ipairs(ns.SKILL_MILESTONES) do
		skillMilestones[i] = { skill = threshold, reached = state.skill[threshold] ~= nil }
	end
	local characters = {}
	local readings = pagle.GetAngler().skill or {}
	for _, index in ipairs(ns.SortedKeys(readings)) do
		local reading = readings[index]
		characters[#characters + 1] = { index = index, skill = reading.rank, max = reading.max }
	end

	local zones = {}
	local tiles = { world = world, state = state } -- HomeZones reads only these two
	local tileZones = ns.HomeZones(tiles --[[@as LedgerSpreadContext]])
	for _, zone in ipairs(tileZones) do
		local area = pagle.GetArea(zone)
		local charted = world.zones[zone] ~= nil
		local zoneState = state.zones[zone]
		zones[#zones + 1] = {
			area = zone,
			continent = area and area.continent,
			charted = charted,
			rank = charted and zoneState and zoneState.rank or 0,
			completion = ns.ZoneCompletion(world, state, zone),
		}
	end

	local worlds = ns.CollectionWorlds(world, state)
	local species = {}
	for i, id in ipairs(worlds.species) do
		species[i] = {
			id = id,
			caught = state.species[id] ~= nil,
			stars = starList(ns.SpeciesStars(world, state, id)),
			removed = removed(id),
		}
	end
	local caughtLegends = {}
	for _, itemID in ipairs(ns.SortedKeys(state.items)) do
		if ns.ClassifyCatch(itemID, world.getItem(itemID)) == "legend" then
			caughtLegends[#caughtLegends + 1] = { item = itemID, removed = removed(itemID) }
		end
	end
	local trophies = {}
	for _, family in ipairs(ns.SortedKeys(world.families)) do
		local weights = {}
		for _, itemID in ipairs(world.families[family].weights) do
			weights[#weights + 1] = {
				item = itemID,
				weight = world.getItem(itemID).weight or 0,
				landed = state.items[itemID] ~= nil,
			}
		end
		table.sort(weights, function(a, b)
			if a.weight ~= b.weight then
				return a.weight < b.weight
			end
			return a.item < b.item
		end)
		trophies[#trophies + 1] =
			{ family = family, stars = starList(ns.FamilyStars(world, state, family)), weights = weights }
	end

	return {
		level = { into = into, cost = cost, carried = level == ns.LEVEL_CAP and into or 0 },
		parts = parts,
		titles = ns.EarnedTitles(state),
		nextCatchMilestone = ns.NextCatchMilestone(state.catches),
		skillMilestones = skillMilestones,
		characters = characters,
		zones = zones,
		species = species,
		legends = { total = completion.legends.total, caught = caughtLegends },
		trophies = trophies,
	}
end

--- The record kind of the Ledger's title record (#76 item 2): its payload is the picked title key, or "" for
--- automatic (LED-R77).
ns.TITLE_RECORD = "title"

--- The title a Ledger Module record picks (#76 item 2): nil when it isn't a title record, false when it picks
--- automatic, else the picked title key. The Ledger doesn't append it yet; the backend reads it from the log.
---@param record PagleModuleRecord
---@return (string|false)?
function ns.PickedTitle(record)
	if record.recordKind ~= ns.TITLE_RECORD then
		return nil
	end
	if record.payload == "" then
		return false
	end
	return record.payload
end
