if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- What Pagle's backend reads from the Ledger's state (#223, #76 item 5): its projection driver folds the Catch log
-- through logic/ alone and computes none of these itself, so each is a function of a projection state, read through
-- the world index the projection was bound with (ns.world: the adapter's OnInitialize sets it, and ns.BindProjections
-- in the driver). Each counts what the state computes, never the celebrated set, which never leaves the client
-- (LOG-R77). The reads that work out the level take Core's Activity XP total as `total` (LED-R37): the backend passes
-- the sum of the paying Modules' ns.ActivityXPEarned (AXP-R9, #76 item 15); without it, ns.ActivityXPTotal() reads
-- the source the adapter sets (Pagle.GetActivityXP().total), 0 in logic/ alone. Pure logic (CORE-R7).

---@class LedgerMeasures
---@field anglerLevel { prestige: integer, level: integer, xp: integer }   -- prestige rank, the climb's level and XP
---@field ledgerCompletion { percent: integer, done: integer, total: integer } -- LED-R70, the percentage floored
---@field speciesCaught integer   -- Species caught, removed ones left out (LED-R71's species part)
---@field legendsCaught integer   -- distinct Legends caught, removed ones left out (LED-R63)

-- The title view of a state alone: no celebrated set, no stored active title.
---@param state LedgerState
---@param total integer? Core's Activity XP total; ns.ActivityXPTotal() when nil
---@return LedgerTitleView
local function computedView(state, total)
	return { world = ns.world, state = state, celebrated = {}, getItem = ns.world.getItem, activityXPTotal = total }
end

--- The four leaderboard measures of a Ledger state: the Angler Level (LED-R30–R32, its Activity XP included,
--- LED-R37), Ledger completion (LED-R70, LED-R71), Species caught and Legends caught (LED-R63). Every number is a
--- whole number, 0 or more.
---@param state LedgerState
---@param total integer? Core's Activity XP total; ns.ActivityXPTotal() when nil
---@return LedgerMeasures
function ns.Measures(state, total)
	local completion = ns.LedgerCompletion(ns.world, state)
	return {
		anglerLevel = ns.AnglerLevel(state, total),
		ledgerCompletion = { percent = completion.percent, done = completion.done, total = completion.total },
		speciesCaught = completion.species.done,
		legendsCaught = completion.legends.done,
	}
end

--- The Angler Level measure alone (LED-R159): Measures' `anglerLevel`, the prestige rank and the climb's level and
--- XP, its Activity XP included (LED-R30–R32, LED-R37), without working out Ledger completion. The backend reads it
--- after every record of any Module, since Hunts and Tackle Board records raise the level through Activity XP.
---@param state LedgerState
---@param total integer? Core's Activity XP total; ns.ActivityXPTotal() when nil
---@return { prestige: integer, level: integer, xp: integer }
function ns.AnglerLevel(state, total)
	return { prestige = state.prestige, level = ns.Level(state, total), xp = ns.ClimbXP(state, total) }
end

--- Ledger completion's counts and when three leaderboard measures last rose (LED-R158), kept by the fold so the
--- backend needn't read Measures after every record. `done` and `total` are LED-R70's, `species` and `legends`
--- Measures' Species caught and Legends caught; `at` holds, by Measures' keys, the entry `time` of the Cast whose
--- apply last made each greater than it was before it (Ledger completion by its percentage), nil while it never rose.
---@class LedgerRises
---@field done integer
---@field total integer
---@field species integer
---@field legends integer
---@field at { ledgerCompletion?: integer, speciesCaught?: integer, legendsCaught?: integer }

--- A fresh state's rises (LED-R158): nothing caught, so nothing done or risen, of the total Ledger completion counts
--- over the world before any Catch.
---@param world LedgerWorld
---@return LedgerRises
function ns.NewRises(world)
	local nothing = { species = {}, items = {}, zones = {}, varieties = {} } -- all LedgerCompletion reads
	local total = ns.LedgerCompletion(world, nothing --[[@as LedgerState]]).total
	return { done = 0, total = total, species = 0, legends = 0, at = {} }
end

-- Ledger completion's percentage (LED-R70): 0 with nothing in total.
---@param done integer
---@param total integer
---@return integer
local function percentOf(done, total)
	return total > 0 and math.floor(100 * done / total) or 0
end

--- Notes what one Cast's apply changed in the measures (LED-R158), from the achievements it appended after `from`,
--- each counted as ns.LedgerCompletion counts it, removed items on neither side (LED-R12): a `newSpecies` adds a
--- Species caught and a completion part done, with one more in total for a Species on no zone list, and one more in
--- the varieties' total too when it has varieties; a `fishComplete` a varieties part done; a `newCurio` or
--- `trophyWeight` a Sub-collection item done, with one more in total for an item on no list; a `zoneRank` that
--- reaches Master a zone done; a `legend` a Legend caught. Each measure that rose takes the Cast's `time`.
---@param state LedgerState
---@param world LedgerWorld
---@param earned LedgerAchievement[]
---@param from integer the achievements before the Cast's
---@param time integer the Cast's entry time
function ns.NoteRises(state, world, earned, from, time)
	local rises, getItem = state.rises, world.getItem
	local done, total, species, legends = rises.done, rises.total, rises.species, rises.legends
	-- Whether an item or Species counts: removed ones are left out of both sides (LED-R12).
	local function counted(id)
		local item = getItem(id)
		return not (item and item.removed)
	end
	for i = from + 1, #earned do
		local achievement = earned[i]
		local kind = achievement.kind
		if kind == "newSpecies" then
			local id = achievement.species --[[@as integer]]
			if counted(id) then
				species, done = species + 1, done + 1
				if not world.species[id] then
					total = total + 1 + (ns.VarietyCount(getItem, id) > 0 and 1 or 0)
				end
			end
		elseif kind == "fishComplete" then
			local id = achievement.species --[[@as integer]]
			done = done + (counted(id) and 1 or 0)
		elseif kind == "newCurio" or kind == "trophyWeight" then
			local itemID = achievement.itemID --[[@as integer]]
			if ns.CollectionOf(getItem(itemID)) and counted(itemID) then
				done = done + 1
				total = total + (world.items[itemID] and 0 or 1)
			end
		elseif kind == "zoneRank" then
			local ranks = achievement.ranks --[[@as integer[] ]]
			done = done + (ranks[#ranks] == ns.ZONE_MASTER and 1 or 0)
		elseif kind == "legend" then
			local itemID = achievement.itemID --[[@as integer]]
			if ns.CollectionOf(getItem(itemID)) == "legends" and counted(itemID) then
				legends = legends + 1
			end
		end
	end
	local at = rises.at
	if percentOf(done, total) > percentOf(rises.done, rises.total) then
		at.ledgerCompletion = time
	end
	if species > rises.species then
		at.speciesCaught = time
	end
	if legends > rises.legends then
		at.legendsCaught = time
	end
	rises.done, rises.total, rises.species, rises.legends = done, total, species, legends
end

--- When Ledger completion, Species caught and Legends caught last rose (LED-R158), by Measures' keys: each the entry
--- `time` of the Cast whose apply last made the measure greater than it was before it, Ledger completion by its
--- percentage, as the backend compared Measures read after every record; nil while it never rose. The Angler Level
--- isn't among them: Hunts and Tackle Board records raise it through Activity XP, and the Ledger never sees them.
---@param state LedgerState
---@return { ledgerCompletion?: integer, speciesCaught?: integer, legendsCaught?: integer }
function ns.MeasureRises(state)
	local at = state.rises.at
	return { ledgerCompletion = at.ledgerCompletion, speciesCaught = at.speciesCaught, legendsCaught = at.legendsCaught }
end

--- The title keys a Ledger state earns (LED-R75, LED-R76), in LED-R75's order: computed only, so a title the
--- celebrated set keeps after a rebalance isn't listed. The level titles count the climb's Activity XP (LED-R37).
---@param state LedgerState
---@param total integer? Core's Activity XP total; ns.ActivityXPTotal() when nil
---@return string[]
function ns.EarnedTitles(state, total)
	return ns.TitleKeys(computedView(state, total))
end

--- The automatic title's key (LED-R77): the highest level title a Ledger state earns, or nil with none.
---@param state LedgerState
---@param total integer? Core's Activity XP total; ns.ActivityXPTotal() when nil
---@return string?
function ns.AutomaticTitle(state, total)
	return (ns.ActiveTitle(computedView(state, total)))
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
--- - `level`: XP into the level, the next step's cost (nil at 60) and the carried XP (0 below 60) (LED-R30, LED-R145),
---   the climb's Activity XP included (LED-R37);
--- - `parts`: each part of Ledger completion as { done, total } (LED-R71);
--- - `titles`: ns.EarnedTitles with the same `total`; `nextCatchMilestone` (nil after the last, LED-R42);
--- - `skillMilestones`: every threshold, ascending, with whether it is credited (LED-R40);
--- - `characters`: each character with a Skill Reading, by index: its latest rank and max (LED-R41);
--- - `zones`: a tile per charted zone and per fished uncharted one, in tile order (LED-R131): its continent (nil
---   when Core doesn't know the area), charted, computed rank (0 unfished or uncharted) and completion (nil
---   uncharted) (LED-R50, LED-R53, LED-R54);
--- - `species`: every Species of the world by ID: caught, computed stars, removed (LED-R11, LED-R12, LED-R45);
--- - `legends`: LED-R63's N, removed Legends left out, and every caught Legend by item ID, with removed;
--- - `trophies`: every listed trophy family by ID: computed stars and its listed weights, lightest first, each with
---   whether it is landed (LED-R47, LED-R61);
--- - `xp`: `ledger`, the Ledger's own XP all told, every climb's, without Activity XP (LED-R150, LED-R155);
--- - `varieties`: every Species with varieties by ID, its caught ones in position order, each with its variety ID,
---   position, rarity and the time of its first Catch (VAR-R2, VAR-R20, LED-R155);
--- - `crests`: the earned crests, ns.EarnedCrests (LED-R155).
---@param state LedgerState
---@param sessionRows integer
---@param total integer? Core's Activity XP total; ns.ActivityXPTotal() when nil
---@return table
function ns.JournalValues(state, sessionRows, total) -- luacheck: no unused args (the driver's one shape for every Module)
	local pagle = Pagle -- luacheck: read globals Pagle (#223: the Angler's Skill Readings and the areas, from Core)
	local world = ns.world
	local completion = ns.LedgerCompletion(world, state)

	local level, into, cost = ns.Climb(state, total)
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

	local varieties = {}
	for _, id in ipairs(worlds.species) do
		local item = world.getItem(id)
		local keys = item and item.varieties
		if keys and ns.VarietyCount(world.getItem, id) > 0 then
			local caught, ofSpecies = {}, state.varieties[id] or {}
			for _, position in ipairs(ns.SortedKeys(ofSpecies)) do
				caught[#caught + 1] = {
					id = id .. "." .. keys[position],
					position = position,
					rarity = ns.VARIETY_RARITY_OF[position],
					first = ofSpecies[position].first.time,
				}
			end
			varieties[#varieties + 1] = { species = id, caught = caught }
		end
	end

	return {
		level = { into = into, cost = cost, carried = level == ns.LEVEL_CAP and into or 0 },
		parts = parts,
		titles = ns.EarnedTitles(state, total),
		nextCatchMilestone = ns.NextCatchMilestone(state.catches),
		skillMilestones = skillMilestones,
		characters = characters,
		zones = zones,
		species = species,
		legends = { total = completion.legends.total, caught = caughtLegends },
		trophies = trophies,
		xp = { ledger = state.lifetimeXP },
		varieties = varieties,
		crests = ns.EarnedCrests(state),
	}
end

---@class LedgerEarnedCrest
---@field id string          -- the crest's good ID: `ledger.crest.<key>` or `core.crest.fish.<speciesID>`
---@field kind "zone"|"fish"
---@field zone? integer      -- a zone crest's areaID
---@field species? integer   -- a fish crest's Species ID
---@field earnedAt integer   -- server time of the record that earned it

--- The crests a Ledger state earns, for Pagle's backend (LED-R155): the zone crests in the zone crest table's order
--- (ns.ZONE_CRESTS, LED-R113), each once its zone's computed rank is Master (LED-R50), never by the celebrated set's
--- shown rank, which never leaves the client (LOG-R77), at the time of the Cast that reached Master; then the fish
--- crests by Species ID, each once all its varieties are caught (VAR-R12, VAR-R20), at the latest of its varieties'
--- first Catches, the Cast that completed it.
---@param state LedgerState
---@return LedgerEarnedCrest[]
function ns.EarnedCrests(state)
	local crests = {}
	for _, crest in ipairs(ns.ZONE_CRESTS) do
		local zoneState = state.zones[crest.areaID]
		if zoneState and zoneState.rank >= ns.ZONE_MASTER then
			crests[#crests + 1] = {
				id = ns.ZoneCrestID(crest),
				kind = "zone",
				zone = crest.areaID,
				earnedAt = zoneState.masterAt,
			}
		end
	end
	local getItem = ns.world.getItem
	for _, species in ipairs(ns.SortedKeys(state.varieties)) do
		if ns.FishComplete(state, getItem, species) then
			local last = 0
			for _, variety in pairs(state.varieties[species]) do
				last = math.max(last, variety.first.time)
			end
			crests[#crests + 1] = { id = ns.FishCrestID(species), kind = "fish", species = species, earnedAt = last }
		end
	end
	return crests
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

--- The record kind of the Ledger's crest record (LED-R156, #76 item 19): its payload is the good ID of the crest the
--- bookplate pins (`Pagle.GetEquipped("core.crest")`, LED-R112), or "" for Plain, the slot's default.
ns.CREST_RECORD = "crest"

--- The crest a Ledger Module record equips (LED-R156): nil when it isn't a crest record, false when it equips Plain,
--- else the crest's good ID. The backend takes the latest by entry time and shows it only when its fold earns it.
---@param record PagleModuleRecord
---@return (string|false)?
function ns.EquippedCrest(record)
	if record.recordKind ~= ns.CREST_RECORD then
		return nil
	end
	if record.payload == "" then
		return false
	end
	return record.payload
end

--- Folds a Ledger Module record into the state (LED-R156): a crest record becomes `state.crest` unless the one there
--- is later by entry time, so the latest wins, the later in log order on equal time. Every other record changes
--- nothing.
---@param state LedgerState
---@param record PagleModuleRecord
function ns.NoteCrestRecord(state, record)
	if ns.EquippedCrest(record) == nil then
		return
	end
	local logged = state.crest
	if logged == nil or record.time >= logged.time then
		state.crest = { good = record.payload, time = record.time }
	end
end

--- The crest record to append for the crest the bookplate pins now (LED-R156): its payload ("" for the slot's
--- default, Plain), or nil when the state's latest crest record already names it. A log with none names Plain.
---@param state LedgerState
---@param equipped string Pagle.GetEquipped("core.crest")
---@param isDefault boolean whether `equipped` is the slot's default (Plain)
---@return string?
function ns.CrestRecordFor(state, equipped, isDefault)
	local payload = isDefault and "" or equipped
	local logged = state.crest and state.crest.good or ""
	if payload == logged then
		return nil
	end
	return payload
end
