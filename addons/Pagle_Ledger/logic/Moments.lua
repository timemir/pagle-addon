if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- What the Ledger tells the player as they fish (LED-R89–R92, LED-R95–R97): a live entry's achievements become
-- moments unless already celebrated, and the celebrated set grows with them. Pure logic, everything passed in (CORE-R7).

--- The celebrated set (LED-R90), M2's and M3's keys. It only grows, except `coins`, which follows the total. `logId`
--- is set, and the set emptied for a new one, in the projection's `done` (logic/Done.lua).
---@class LedgerCelebrated
---@field levels { [integer]: integer }      -- the highest level celebrated, by prestige rank
---@field species { [integer]: true }        -- Species IDs
---@field stars { [integer]: LedgerStars }   -- each Species' stars, by Species ID (LED-R48)
---@field familyStars { [integer]: LedgerStars } -- each trophy family's stars, by family ID (LED-R48)
---@field speciesZones { [string]: true }    -- "<speciesID>:<zone>"
---@field zones { [integer]: integer }       -- zones fished: the shown rank, 0 for none (LED-R52)
---@field items { [integer]: true }          -- curio and trophy items (LED-R60)
---@field uncharted { [integer]: true }      -- Uncharted item IDs (LED-R64)
---@field skill { [integer]: true }          -- Skill Milestone thresholds
---@field coins integer                      -- the lifetime Coins total
---@field logId? string                      -- the PagleLog.logId it belongs to

--- What the live moments read and where they go: Core's calls, through the Module handle, and the client's names.
---@class LedgerOutlets
---@field RaiseMoment fun(moment: PagleMoment)          -- M:RaiseMoment
---@field ReportCoinsEarned fun(total: integer)         -- M:ReportCoinsEarned
---@field SetSummaryLine fun(text: string)              -- M:SetSummaryLine("ledger", text)
---@field ItemName fun(itemID: integer): string?        -- C_Item.GetItemNameByID
---@field ZoneName fun(zone: integer): string?          -- C_Map.GetAreaInfo
---@field RaiseWriteUp fun(section: PagleWriteUpSection) -- M:RaiseWriteUp
---@field LogId fun(): string?                          -- Pagle.GetAngler().logId
---@field FormatNumber fun(n: integer): string          -- BreakUpLargeNumbers

-- In-client textures for the moments that have no item (LED-R97): the level's ledger book and Fishing's own icon.
local LEVEL_ICON = "Interface\\Icons\\INV_Misc_Book_09"
local SKILL_ICON = "Interface\\Icons\\Trade_Fishing"
-- A zone rank's map, Zone Master's spyglass and a trophy family's mounted fish.
local ZONE_RANK_ICON = "Interface\\Icons\\INV_Misc_Map_01"
local ZONE_MASTER_ICON = "Interface\\Icons\\INV_Misc_Spyglass_03"
local FAMILY_STAR_ICON = "Interface\\Icons\\INV_Misc_Fish_02"

--- The celebrated set in PagleLedgerDB.global, with M2's and M3's keys made if missing (LED-R90).
---@param global table PagleLedgerDB's global section
---@return LedgerCelebrated
function ns.CelebratedSet(global)
	local celebrated = global.celebrated
	if type(celebrated) ~= "table" then
		celebrated = {}
		global.celebrated = celebrated
	end
	for _, key in ipairs({
		"levels",
		"species",
		"stars",
		"familyStars",
		"speciesZones",
		"zones",
		"items",
		"uncharted",
		"skill",
	}) do
		if type(celebrated[key]) ~= "table" then
			celebrated[key] = {}
		end
	end
	celebrated.coins = celebrated.coins or 0
	return celebrated
end

--- `n` with the singular or the plural form, as every count in the Ledger has both (LED-R94): `%d` in each, or `%s`
--- with `format`, which writes the number (the client's BreakUpLargeNumbers, LED-R146).
---@param n integer
---@param one string
---@param other string
---@param format? fun(n: integer): string
---@return string
function ns.CountText(n, one, other, format)
	return (n == 1 and one or other):format(format and format(n) or n)
end

--- The shown level (LED-R36, LED-R92): the higher of the computed level and the highest celebrated in this climb.
---@param state LedgerState
---@param celebrated LedgerCelebrated
---@return integer
function ns.ShownLevel(state, celebrated)
	return math.max(ns.Level(state), celebrated.levels[state.prestige] or 0)
end

--- The Ledger's summary line (LED-R95): the shown level and Ledger completion's percent (LED-R70). The Prestige
--- part is M4's.
---@param state LedgerState
---@param celebrated LedgerCelebrated
---@param lookups LedgerLookups the world index, for completion
---@return string
function ns.SummaryLine(state, celebrated, lookups)
	local completion = ns.LedgerCompletion(lookups.world, state)
	return ns.L.SUMMARY_LINE:format(ns.ShownLevel(state, celebrated), completion.percent)
end

-- An item's name, or "Item {id}" when the client doesn't have it yet (LED-R97).
---@param outlets LedgerOutlets
---@param itemID integer
---@return string
local function itemName(outlets, itemID)
	return outlets.ItemName(itemID) or ns.L.ITEM_FALLBACK:format(itemID)
end

--- Adds `stars` to the celebrated stars of `key` (a Species or a trophy family, LED-R90), returning those that weren't
--- celebrated yet, ascending.
---@param set { [integer]: LedgerStars } celebrated.stars or celebrated.familyStars
---@param key integer
---@param stars integer[] ascending
---@return integer[]
function ns.CelebrateStars(set, key, stars)
	local celebrated = set[key]
	if not celebrated then
		celebrated = {}
		set[key] = celebrated
	end
	local new = {}
	for _, star in ipairs(stars) do
		if not celebrated[star] then
			celebrated[star] = true
			new[#new + 1] = star
		end
	end
	return new
end

-- Stars as text, "★★" for 2 (LED-R97).
---@param n integer
---@return string
local function starsText(n)
	return ns.L.STAR:rep(n)
end

-- A Species × zone key of the celebrated set (ledger.md › Data).
---@param species integer
---@param zone integer
---@return string
local function speciesZone(species, zone)
	return species .. ":" .. zone
end

-- Each kind's moment (LED-R97) for an achievement not yet celebrated, which it adds to the set; nil when already
-- celebrated (LED-R91).
---@type { [string]: fun(celebrated: LedgerCelebrated, state: LedgerState, earned: LedgerAchievement, outlets: LedgerOutlets): PagleMoment? }
local celebrate = {}

function celebrate.newSpecies(celebrated, _, earned, outlets)
	local species = earned.species --[[@as integer]]
	local zone = earned.zone --[[@as integer]]
	-- The first Catch ever of a Species is also its first in the zone: it covers the pair (LED-R97).
	if zone ~= 0 then
		celebrated.speciesZones[speciesZone(species, zone)] = true
	end
	-- Its ★ rides on the New Species moment (LED-R97).
	ns.CelebrateStars(celebrated.stars, species, { 1 })
	if celebrated.species[species] then
		return nil
	end
	celebrated.species[species] = true
	local L = ns.L
	return {
		rung = "toast",
		kind = "newSpecies",
		order = 100,
		title = L.NEW_SPECIES_TITLE,
		text = itemName(outlets, earned.itemID --[[@as integer]]),
		stamp = L.NEW_SPECIES_STAMP,
		icon = earned.itemID,
		cast = earned.cast,
		coins = earned.coins,
	}
end

function celebrate.newInZone(celebrated, _, earned, outlets)
	local key = speciesZone(earned.species --[[@as integer]], earned.zone --[[@as integer]])
	if celebrated.speciesZones[key] then
		return nil
	end
	celebrated.speciesZones[key] = true
	local L = ns.L
	return {
		rung = "nod",
		kind = "newInZone",
		order = 100,
		title = L.NEW_IN_ZONE_TITLE,
		text = L.NEW_IN_ZONE_TEXT:format(
			itemName(outlets, earned.itemID --[[@as integer]]),
			outlets.ZoneName(earned.zone --[[@as integer]]) or L.NAME_UNKNOWN
		),
		stamp = L.NEW_IN_ZONE_STAMP,
		icon = earned.itemID,
		cast = earned.cast,
	}
end

-- A Catch moment titled `title` with the item's name as its text and the item as its icon (LED-R97).
---@param kind string
---@param rung PagleRung
---@param order integer
---@param title string
---@param stamp string
---@param earned LedgerAchievement
---@param outlets LedgerOutlets
---@return PagleMoment
local function itemMoment(kind, rung, order, title, stamp, earned, outlets)
	local itemID = earned.itemID --[[@as integer]]
	return {
		rung = rung,
		kind = kind,
		order = order,
		title = title,
		text = itemName(outlets, itemID),
		stamp = stamp,
		icon = itemID,
		cast = earned.cast,
		coins = earned.coins > 0 and earned.coins or nil,
	}
end

-- A new trophy weight (LED-R61), its ruler from the family's heaviest when it is heavier. The family's ★ rides on it.
function celebrate.trophyWeight(celebrated, _, earned, outlets)
	local itemID = earned.itemID --[[@as integer]]
	if earned.family then
		ns.CelebrateStars(celebrated.familyStars, earned.family, { 1 })
	end
	if celebrated.items[itemID] then
		return nil
	end
	celebrated.items[itemID] = true
	local L = ns.L
	local moment =
		itemMoment("trophyWeight", "toast", 110, L.TROPHY_WEIGHT_TITLE, L.TROPHY_WEIGHT_STAMP, earned, outlets)
	if earned.old and earned.new then
		moment.ruler = { old = earned.old, new = earned.new, unit = "lb", label = "weight" }
	end
	return moment
end

-- A curio item's first Catch (LED-R60).
function celebrate.newCurio(celebrated, _, earned, outlets)
	local itemID = earned.itemID --[[@as integer]]
	if celebrated.items[itemID] then
		return nil
	end
	celebrated.items[itemID] = true
	local L = ns.L
	return itemMoment("newCurio", "toast.low", 110, L.NEW_CURIO_TITLE, L.NEW_CURIO_STAMP, earned, outlets)
end

-- An Uncharted item's first Catch (LED-R64).
function celebrate.uncharted(celebrated, _, earned, outlets)
	local itemID = earned.itemID --[[@as integer]]
	if celebrated.uncharted[itemID] then
		return nil
	end
	celebrated.uncharted[itemID] = true
	local L = ns.L
	return itemMoment("uncharted", "nod", 140, L.UNCHARTED_TITLE, L.UNCHARTED_STAMP, earned, outlets)
end

-- A Species' ★★ (`elementStar`) or ★★★ (`regularStar`), each once (LED-R45, LED-R48).
---@param star integer
---@param kind string
---@param order integer
---@param title string its title's key in ns.L
local function speciesStar(star, kind, order, title)
	celebrate[kind] = function(celebrated, _, earned, outlets)
		if
			#ns.CelebrateStars(celebrated.stars, earned.species --[[@as integer]], { star }) == 0
		then
			return nil
		end
		return itemMoment(kind, "nod", order, ns.L[title], starsText(star), earned, outlets)
	end
end
speciesStar(2, "elementStar", 110, "ELEMENT_STAR_TITLE")
speciesStar(3, "regularStar", 120, "REGULAR_STAR_TITLE")

-- A trophy family's ★★ and ★★★ (LED-R47, LED-R48): one moment for the stars not yet celebrated, the highest as its
-- stamp, after the family's name from lore, left out while it has none (LED-R161).
function celebrate.familyStar(celebrated, _, earned)
	local family = earned.family --[[@as integer]]
	local new = ns.CelebrateStars(celebrated.familyStars, family, earned.stars --[[@as integer[] ]])
	if #new == 0 then
		return nil
	end
	local L = ns.L
	local stars = starsText(new[#new])
	local name = L["family." .. family .. ".name"]
	return {
		rung = "nod",
		kind = "familyStar",
		order = 130,
		title = L.FAMILY_STAR_TITLE,
		text = name and L.FAMILY_STAR_TEXT:format(name, stars) or stars,
		stamp = stars,
		icon = FAMILY_STAR_ICON,
		cast = earned.cast,
	}
end

function celebrate.skillMilestone(celebrated, _, earned)
	local threshold = earned.threshold --[[@as integer]]
	if celebrated.skill[threshold] then
		return nil
	end
	celebrated.skill[threshold] = true
	local L = ns.L
	-- No stamp (it rides as its title) and no `cast`: a Skill Reading's (LED-R96, LED-R97).
	return {
		rung = "toast",
		kind = "skillMilestone",
		order = 130,
		title = L.SKILL_MILESTONE_TITLE,
		text = L.SKILL_MILESTONE_TEXT:format(threshold),
		icon = SKILL_ICON,
	}
end

-- One per entry, for the levels above the celebrated one, with 20 Coins for each of those (LED-R97). The levels at
-- or below it raise nothing again, and their Coins count only in the total (LED-R36). M2 has no titles.
function celebrate.levelUp(celebrated, state, earned)
	local levels = earned.levels --[[@as integer[] ]]
	local top = levels[#levels]
	local above = celebrated.levels[state.prestige] or 0
	if top <= above then
		return nil
	end
	celebrated.levels[state.prestige] = top
	local raised = 0
	for _, level in ipairs(levels) do
		if level > above then
			raised = raised + 1
		end
	end
	local L = ns.L
	return {
		rung = "banner",
		kind = "levelUp",
		order = 100,
		title = L.LEVEL_UP_TITLE:format(top),
		text = raised > 1 and ns.CountText(raised, L.LEVELS_RAISED_ONE, L.LEVELS_RAISED_OTHER) or nil,
		stamp = L.LEVEL_UP_STAMP:format(top),
		icon = LEVEL_ICON,
		cast = earned.cast,
		coins = ns.LEVEL_UP_COINS * raised,
	}
end

-- One per zone per entry, for the ranks above the celebrated one, with 2 Coins × each of those ranks (LED-R97):
-- "Zone rank" up to Expert, and "Zone Master" in its place when the zone reaches Master. The celebrated set keeps the
-- zone's shown rank (LED-R90, LED-R92). M3 has no titles: the Zone Master's waits for M4.
function celebrate.zoneRank(celebrated, _, earned, outlets)
	local zone = earned.zone --[[@as integer]]
	local ranks = earned.ranks --[[@as integer[] ]]
	local top = ranks[#ranks]
	local above = celebrated.zones[zone] or 0
	if top <= above then
		return nil
	end
	celebrated.zones[zone] = top
	local coins = 0
	for _, rank in ipairs(ranks) do
		if rank > above then
			coins = coins + ns.ZONE_RANK_COINS * rank
		end
	end
	local L = ns.L
	local name = outlets.ZoneName(zone) or L.NAME_UNKNOWN
	if top == ns.ZONE_MASTER then
		return {
			rung = "banner",
			kind = "zoneMaster",
			order = 120,
			title = L.ZONE_MASTER_TITLE,
			text = name,
			stamp = L.ZONE_MASTER_STAMP,
			icon = ZONE_MASTER_ICON,
			cast = earned.cast,
			coins = coins,
		}
	end
	return {
		rung = "toast",
		kind = "zoneRank",
		order = 120,
		title = L.ZONE_RANK_TITLE:format(L.ZONE_RANKS[top]),
		text = name,
		stamp = L.ZONE_RANK_STAMP,
		icon = ZONE_RANK_ICON,
		cast = earned.cast,
		coins = coins,
	}
end

--- One achievement's moment (LED-R97) when it isn't celebrated yet, adding it to the set; nil when it already is
--- (LED-R91). A projection's done raises them too, from the scratch list (LED-R93).
---@param celebrated LedgerCelebrated
---@param state LedgerState
---@param achievement LedgerAchievement
---@param outlets LedgerOutlets
---@return PagleMoment?
function ns.CelebrateAchievement(celebrated, state, achievement, outlets)
	local moment = celebrate[achievement.kind]
	return moment and moment(celebrated, state, achievement, outlets)
end

--- Celebrates one `"live"` entry (LED-R91, LED-R96, LED-R97): the moment of each achievement it earned that isn't
--- celebrated yet, in the order earned, each added to the set. The zone a Cast fished joins the set too.
---@param celebrated LedgerCelebrated
---@param state LedgerState the state with the entry applied
---@param record PagleRecord
---@param earned LedgerAchievement[] what the fold reported for the entry
---@param outlets LedgerOutlets
---@return PagleMoment[]
function ns.Celebrate(celebrated, state, record, earned, outlets)
	if record.kind == "cast" then
		local zone = (record --[[@as PagleCast]]).conditions.zone
		if state.zones[zone] and celebrated.zones[zone] == nil then
			celebrated.zones[zone] = 0
		end
	end
	local moments = {}
	for _, achievement in ipairs(earned) do
		local moment = ns.CelebrateAchievement(celebrated, state, achievement, outlets)
		if moment then
			moments[#moments + 1] = moment
		end
	end
	return moments
end
