if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- What the Ledger tells the player as they fish (LED-R89–R92, LED-R95–R97): a live entry's achievements become
-- moments unless already celebrated, and the celebrated set grows with them. Pure logic, everything passed in (CORE-R7).

--- The celebrated set (LED-R90), M2's keys. It only grows, except `coins`, which follows the total. `logId` is set,
--- and the set emptied for a new one, in the projection's `done` (logic/Done.lua).
---@class LedgerCelebrated
---@field levels { [integer]: integer }      -- the highest level celebrated, by prestige rank
---@field species { [integer]: true }        -- Species IDs
---@field speciesZones { [string]: true }    -- "<speciesID>:<zone>"
---@field zones { [integer]: integer }       -- zones fished: the shown rank (0, no rank, in M2)
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

--- The celebrated set in PagleLedgerDB.global, with M2's keys made if missing (LED-R90).
---@param global table PagleLedgerDB's global section
---@return LedgerCelebrated
function ns.CelebratedSet(global)
	local celebrated = global.celebrated
	if type(celebrated) ~= "table" then
		celebrated = {}
		global.celebrated = celebrated
	end
	for _, key in ipairs({ "levels", "species", "speciesZones", "zones", "skill" }) do
		if type(celebrated[key]) ~= "table" then
			celebrated[key] = {}
		end
	end
	celebrated.coins = celebrated.coins or 0
	return celebrated
end

--- `n` with the singular or the plural form (`%d` in each), as every count in the Ledger has both (LED-R94).
---@param n integer
---@param one string
---@param other string
---@return string
function ns.CountText(n, one, other)
	return (n == 1 and one or other):format(n)
end

--- The shown level (LED-R36, LED-R92): the higher of the computed level and the highest celebrated in this climb.
---@param state LedgerState
---@param celebrated LedgerCelebrated
---@return integer
function ns.ShownLevel(state, celebrated)
	return math.max(ns.Level(state), celebrated.levels[state.prestige] or 0)
end

--- The Ledger's summary line (LED-R95), without the completion part until M3.
---@param state LedgerState
---@param celebrated LedgerCelebrated
---@return string
function ns.SummaryLine(state, celebrated)
	return ns.L.SUMMARY_LINE:format(ns.ShownLevel(state, celebrated))
end

-- An item's name, or "Item {id}" when the client doesn't have it yet (LED-R97).
---@param outlets LedgerOutlets
---@param itemID integer
---@return string
local function itemName(outlets, itemID)
	return outlets.ItemName(itemID) or ns.L.ITEM_FALLBACK:format(itemID)
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

--- One achievement's moment (LED-R97) when it isn't celebrated yet, adding it to the set; nil when it already is
--- (LED-R91). A projection's done raises them too, from the scratch list (LED-R93).
---@param celebrated LedgerCelebrated
---@param state LedgerState
---@param achievement LedgerAchievement
---@param outlets LedgerOutlets
---@return PagleMoment?
function ns.CelebrateAchievement(celebrated, state, achievement, outlets)
	return celebrate[achievement.kind](celebrated, state, achievement, outlets)
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
