if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- What the Ledger tells the player as they fish (LED-R89–R92, LED-R95–R97): a live entry's achievements become
-- moments unless already celebrated, and the celebrated set grows with them. Pure logic, everything passed in (CORE-R7).

--- The celebrated set (LED-R90), M2's, M3's and M4's keys. It only grows, except `coins`, which follows the total.
--- `logId` is set, and the set emptied for a new one, in the projection's `done` (logic/Done.lua).
---@class LedgerCelebrated
---@field levels { [integer]: integer }      -- the highest level celebrated, by prestige rank; 60 also stands for
--- that climb's `prestigeReady`
---@field prestige integer                   -- the highest prestige rank celebrated
---@field species { [integer]: true }        -- Species IDs
---@field stars { [integer]: LedgerStars }   -- each Species' stars, by Species ID (LED-R48)
---@field familyStars { [integer]: LedgerStars } -- each trophy family's stars, by family ID (LED-R48)
---@field speciesZones { [string]: true }    -- "<speciesID>:<zone>"
---@field zones { [integer]: integer }       -- zones fished: the shown rank, 0 for none (LED-R52)
---@field items { [integer]: true }          -- curio, trophy and Legend items (LED-R60, LED-R63)
---@field uncharted { [integer]: true }      -- Uncharted item IDs (LED-R64)
---@field skill { [integer]: true }          -- Skill Milestone thresholds
---@field milestones { [integer]: true }     -- Catch Milestones (LED-R42)
---@field varieties { [integer]: { [integer]: true } } -- each Species' varieties, by position (VAR-R25)
---@field fishComplete { [integer]: true }   -- Species with every variety caught (VAR-R25)
---@field coins integer                      -- the lifetime Coins total
---@field logId? string                      -- the PagleLog.logId it belongs to

--- What the live moments read and where they go: Core's calls, through the Module handle, and the client's names.
---@class LedgerOutlets
---@field RaiseMoment fun(moment: PagleMoment)          -- M:RaiseMoment
---@field ReportCoinsEarned fun(total: integer)         -- M:ReportCoinsEarned
---@field SetSummaryLine fun(text: string)              -- M:SetSummaryLine("ledger", text)
---@field ItemName fun(itemID: integer): string?        -- C_Item.GetItemNameByID
---@field AreaName fun(areaID: integer): string?    -- C_Map.GetAreaInfo
---@field RaiseWriteUp fun(section: PagleWriteUpSection) -- M:RaiseWriteUp
---@field LogId fun(): string?                          -- Pagle.GetAngler().logId
---@field FormatNumber fun(n: integer): string          -- BreakUpLargeNumbers
---@field RefreshGoods fun()                            -- M:RefreshGoods (LED-R111)
---@field SizeText fun(size: PagleSize?): string?       -- ns.SizeText over Pagle.SIZE_BANDS and Pagle.FormatLength
---@field Variety fun(speciesID: integer, index: integer): LedgerVarietyLook? -- Pagle.GetVarieties(speciesID)[index]
---@field Good fun(goodID: string): { name: string?, icon: (integer|string)? }? -- Pagle.GetGood (a fish crest, VAR-R25)

--- A variety as Core lists it (VAR-R11), what its moments show: its name and its art.
---@class LedgerVarietyLook
---@field name string
---@field art? { texture: integer|string, left: number, right: number, top: number, bottom: number }

-- In-client textures for the moments that have no item (LED-R97): the level's ledger book and Fishing's own icon.
local LEVEL_ICON = ns.BINDING_ICON
local SKILL_ICON = "Interface\\Icons\\Trade_Fishing"
-- A zone rank's map, Zone Master's spyglass and a trophy family's mounted fish.
local ZONE_RANK_ICON = "Interface\\Icons\\INV_Misc_Map_01"
local ZONE_MASTER_ICON = "Interface\\Icons\\INV_Misc_Spyglass_03"
local FAMILY_STAR_ICON = "Interface\\Icons\\INV_Misc_Fish_02"
-- M4's: a fresh book for Prestige ready, a ribbon for a Prestige, a fish for a Catch Milestone and a scroll for a
-- completion title.
local PRESTIGE_READY_ICON = "Interface\\Icons\\INV_Misc_Book_11"
local PRESTIGE_ICON = "Interface\\Icons\\INV_Misc_Ribbon_01"
local CATCH_MILESTONE_ICON = "Interface\\Icons\\INV_Misc_Fish_14"
local TITLE_ICON = "Interface\\Icons\\INV_Scroll_03"

--- The celebrated set in PagleLedgerDB.global, with M2's, M3's and M4's keys and the varieties' made if missing
--- (LED-R90, VAR-R25).
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
		"milestones",
		"titles",
		"varieties",
		"fishComplete",
	}) do
		if type(celebrated[key]) ~= "table" then
			celebrated[key] = {}
		end
	end
	celebrated.prestige = celebrated.prestige or 0
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

--- The shown level (LED-R36, LED-R92): the higher of the computed level, its Activity XP included (LED-R38), and the
--- highest celebrated in this climb.
---@param state LedgerState
---@param celebrated LedgerCelebrated
---@param total integer? Core's Activity XP total; ns.ActivityXPTotal() when nil
---@return integer
function ns.ShownLevel(state, celebrated, total)
	return math.max(ns.Level(state, total), celebrated.levels[state.prestige] or 0)
end

--- The Ledger's summary line (LED-R95): the prestige rank when above 0, the shown level and Ledger completion's
--- percent (LED-R70).
---@param state LedgerState
---@param celebrated LedgerCelebrated
---@param lookups LedgerLookups the world index, for completion
---@return string
function ns.SummaryLine(state, celebrated, lookups)
	local percent = ns.LedgerCompletion(lookups.world, state).percent
	local level = ns.ShownLevel(state, celebrated)
	if state.prestige > 0 then
		return ns.L.SUMMARY_LINE_PRESTIGE:format(state.prestige, level, percent)
	end
	return ns.L.SUMMARY_LINE:format(level, percent)
end

-- An item's name, or "Item {id}" when the client doesn't have it yet (LED-R97).
---@param outlets LedgerOutlets
---@param itemID integer
---@return string
local function itemName(outlets, itemID)
	return outlets.ItemName(itemID) or ns.L.ITEM_FALLBACK:format(itemID)
end

-- A Catch moment's "{item} · {size text}" (LED-R81, LED-R97): the item alone, with no separator, when the Catch has
-- no size.
---@param outlets LedgerOutlets
---@param earned LedgerAchievement
---@return string
local function itemWithSize(outlets, earned)
	local name = itemName(outlets, earned.itemID --[[@as integer]])
	local size = outlets.SizeText(earned.size)
	return size and ns.L.ITEM_SIZE:format(name, size) or name
end

--- Adds `stars` to the celebrated stars of `key` (a Species or a trophy family, LED-R90), returning those that weren't
--- celebrated yet, ascending. With no stars (a Species short of ★, LED-R45) it adds no entry for `key`.
---@param set { [integer]: LedgerStars } celebrated.stars or celebrated.familyStars
---@param key integer
---@param stars integer[] ascending
---@return integer[]
function ns.CelebrateStars(set, key, stars)
	if #stars == 0 then
		return {}
	end
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
-- celebrated (LED-R91). `before` is the celebrated levels as they were before the list being celebrated, for
-- `prestigeReady`, which a climb's celebrated 60 stands for (LED-R90).
---@type { [string]: fun(celebrated: LedgerCelebrated, state: LedgerState, earned: LedgerAchievement, outlets: LedgerOutlets, before: { [integer]: integer }): PagleMoment? }
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
		text = itemWithSize(outlets, earned),
		stamp = L.NEW_SPECIES_STAMP,
		icon = earned.itemID,
		cast = earned.cast,
		coins = earned.coins,
		-- the first one's Margin note, before Core's on its coin (ONB-R53)
		firstNote = L.NEW_SPECIES_FIRST_NOTE,
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
			outlets.AreaName(earned.zone --[[@as integer]]) or L.NAME_UNKNOWN
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

-- A Species' ★ (`caughtStar`), ★★ (`elementStar`) or ★★★ (`regularStar`), each once (LED-R45, LED-R48).
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
speciesStar(1, "caughtStar", 105, "CAUGHT_STAR_TITLE")
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
	local name = ns.FamilyName(family)
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

-- One per entry, for the levels above the celebrated one in its climb, with 20 Coins for each of those (LED-R97).
-- The levels at or below it raise nothing again, and their Coins count only in the total (LED-R36). The titles earned
-- with it ride in its text (celebrateTitles).
function celebrate.levelUp(celebrated, state, earned)
	local levels = earned.levels --[[@as integer[] ]]
	local top = levels[#levels]
	local rank = earned.rank or state.prestige
	local above = celebrated.levels[rank] or 0
	if top <= above then
		return nil
	end
	celebrated.levels[rank] = top
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
		seal = top,
	}
end

-- One per zone per entry, for the ranks above the celebrated one, with 2 Coins × each of those ranks (LED-R97):
-- "Zone rank" up to Expert, and "Zone Master" in its place when the zone reaches Master. The celebrated set keeps the
-- zone's shown rank (LED-R90, LED-R92). The Zone Master's title rides in its text (celebrateTitles).
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
	local name = outlets.AreaName(zone) or L.NAME_UNKNOWN
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
			seal = "waves",
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

-- A Legend item's first Catch (LED-R63): the splash, its size text and 100 Coins. Its title rides in its text
-- (celebrateTitles). The item joins the celebrated items (LED-R90).
function celebrate.legend(celebrated, _, earned, outlets)
	local itemID = earned.itemID --[[@as integer]]
	if celebrated.items[itemID] then
		return nil
	end
	celebrated.items[itemID] = true
	local L = ns.L
	return {
		rung = "splash",
		kind = "legend",
		order = 100,
		title = L.LEGEND_TITLE,
		text = itemWithSize(outlets, earned),
		stamp = L.LEGEND_STAMP,
		icon = itemID,
		cast = earned.cast,
		coins = earned.coins,
	}
end

-- A climb reaching 60 (LED-R97), once per climb: its celebrated 60 stands for it (LED-R90), so it raises nothing when
-- the climb's 60 was celebrated before this list, however the level-up just before it moved the set.
function celebrate.prestigeReady(celebrated, _, earned, _, before)
	local rank = earned.rank --[[@as integer]]
	if (before[rank] or 0) >= ns.LEVEL_CAP then
		return nil
	end
	celebrated.levels[rank] = math.max(celebrated.levels[rank] or 0, ns.LEVEL_CAP)
	local L = ns.L
	return {
		rung = "banner",
		kind = "prestigeReady",
		order = 110,
		title = L.PRESTIGE_READY_TITLE,
		text = L.PRESTIGE_READY_TEXT,
		stamp = L.PRESTIGE_READY_STAMP,
		icon = PRESTIGE_READY_ICON,
		cast = earned.cast,
		seal = "book",
	}
end

-- A Prestige (LED-R32, LED-R34): "Prestige {I…X}", or "Master Prestige {rank − 10}" from rank 11, with its 100 Coins
-- and no `cast` (LED-R96). Its title rides in its text (celebrateTitles); the new climb's levels ride on their own
-- cast-less levelUp beside it.
function celebrate.prestige(celebrated, _, earned)
	local rank = earned.rank --[[@as integer]]
	if rank <= celebrated.prestige then
		return nil
	end
	celebrated.prestige = rank
	local L = ns.L
	local mark = ns.PrestigeMark(rank)
	return {
		rung = "banner",
		kind = "prestige",
		order = 90,
		title = mark.stars > 0 and L.MASTER_PRESTIGE_TITLE:format(mark.stars) or L.PRESTIGE_TITLE:format(mark.emblem),
		icon = PRESTIGE_ICON,
		coins = earned.coins,
		seal = "crest",
	}
end

-- A Catch Milestone (LED-R42): "{N} Catches" as its title and stamp, N with BreakUpLargeNumbers.
function celebrate.catchMilestone(celebrated, _, earned, outlets)
	local n = earned.n --[[@as integer]]
	if celebrated.milestones[n] then
		return nil
	end
	celebrated.milestones[n] = true
	local L = ns.L
	local catches = (n == 1 and L.CATCHES_ONE or L.CATCHES_OTHER):format(outlets.FormatNumber(n))
	return {
		rung = "banner",
		kind = "catchMilestone",
		order = 130,
		title = catches,
		stamp = catches,
		icon = CATCH_MILESTONE_ICON,
		cast = earned.cast,
		seal = n,
	}
end

-- A Simulated Size record beaten live (LED-R82): `toast.low`, or `toast` with the rare-record flair, and the ruler
-- from the old length to the new, always (ANN-R22). Records are never in the celebrated set (LED-R84).
function celebrate.sizeRecord(_, _, earned, outlets)
	local L = ns.L
	return {
		rung = earned.flair and "toast" or "toast.low",
		kind = "sizeRecord",
		order = 100,
		title = L.SIZE_RECORD_TITLE,
		text = itemWithSize(outlets, earned),
		stamp = L.SIZE_RECORD_STAMP,
		icon = earned.itemID,
		cast = earned.cast,
		ruler = { old = earned.old, new = earned.new, unit = "length", label = "length" },
	}
end

--- The good ID of a Species' fish crest (VAR-R12), which Core registers in its `core.crest` slot.
---@param speciesID integer
---@return string
function ns.FishCrestID(speciesID)
	return "core.crest.fish." .. speciesID
end

-- A copy of a variety's art (VAR-R11), for a moment: Core's lists are shared (CORE-R18). Nil without one.
---@param look LedgerVarietyLook?
---@return table?
local function copyArt(look)
	local art = look and look.art
	if not art then
		return nil
	end
	return { texture = art.texture, left = art.left, right = art.right, top = art.top, bottom = art.bottom }
end

-- A variety's first Catch (VAR-R25, VAR-R27), where its name and art are first shown: a Common or Uncommon one a
-- `toast.low` "New variety · {name}", riding as "New variety" on the Cast's toast when there is one; a Rare one a
-- `toast` "Rare variety" with its name, its art in the bezel; an Epic one a `banner` "Epic variety" with its name, its
-- art on the seal's ribbon. Each carries the item caught as its icon, for where the art isn't drawn, and no Coins.
function celebrate.newVariety(celebrated, _, earned, outlets)
	local species = earned.species --[[@as integer]]
	local index = earned.index --[[@as integer]]
	local caught = celebrated.varieties[species]
	if not caught then
		caught = {}
		celebrated.varieties[species] = caught
	end
	if caught[index] then
		return nil
	end
	caught[index] = true
	local L = ns.L
	local look = outlets.Variety(species, index)
	local name = look and look.name or L.NAME_UNKNOWN
	local moment = { icon = earned.itemID, art = copyArt(look), cast = earned.cast }
	local rarity = earned.rarity
	if rarity == "epic" then
		moment.rung, moment.kind, moment.order = "banner", "epicVariety", 97
		moment.title, moment.text = L.EPIC_VARIETY_TITLE, name
	elseif rarity == "rare" then
		moment.rung, moment.kind, moment.order = "toast", "rareVariety", 105
		moment.title, moment.text = L.RARE_VARIETY_TITLE, name
	else
		moment.rung, moment.kind, moment.order = "toast.low", "newVariety", 120
		moment.title, moment.stamp = L.NEW_VARIETY_TITLE:format(name), L.NEW_VARIETY_STAMP
	end
	return moment
end

-- A Species' every variety caught (VAR-R25): a `banner` "Every colour of {Species}", sealed with its fish crest (the
-- crest's icon, VAR-R12) and its "Earned" line, no Coins. Without the crest registered, the seal shows its waves and
-- no line.
function celebrate.fishComplete(celebrated, _, earned, outlets)
	local species = earned.species --[[@as integer]]
	if celebrated.fishComplete[species] then
		return nil
	end
	celebrated.fishComplete[species] = true
	local L = ns.L
	local crest = outlets.Good(ns.FishCrestID(species))
	return {
		rung = "banner",
		kind = "everyColour",
		order = 95,
		title = L.EVERY_COLOUR_TITLE:format(itemName(outlets, species)),
		text = crest and crest.name and L.CREST_EARNED:format(crest.name) or nil,
		stamp = L.EVERY_COLOUR_STAMP,
		icon = earned.itemID,
		cast = earned.cast,
		seal = crest and crest.icon and "crest" or nil,
		crest = crest and crest.icon or nil,
	}
end

-- The titles' names (LED-R75, LED-R161): the Journal's lore lookup, with zone names from the outlets.
---@param outlets LedgerOutlets
---@return LedgerJournalText
local function titleText(outlets)
	return ns.NewLoreText(outlets.AreaName)
end

--- The names of title keys (LED-R75), in the order given, leaving out each key with no text (LED-R161).
---@param keys string[]
---@param outlets LedgerOutlets
---@return string[]
function ns.TitleNames(keys, outlets)
	local text, names = titleText(outlets), {}
	for _, key in ipairs(keys) do
		names[#names + 1] = ns.TitleName(key, text)
	end
	return names
end

-- Whether `moment`, raised for `achievement`, is the one a title of `kind` and `n` rides in (LED-R97): the level-up
-- that raised its level, the Prestige that reached its rank, its zone's Zone Master or its Legend.
---@param moment PagleMoment
---@param achievement LedgerAchievement
---@param kind string
---@param n integer|string
---@return boolean
local function carries(moment, achievement, kind, n)
	if kind == "level" and moment.kind == "levelUp" then
		for _, level in
			ipairs(achievement.levels --[[@as integer[] ]])
		do
			if level == n then
				return true
			end
		end
	elseif kind == "prestige" and moment.kind == "prestige" then
		local rank = achievement.rank --[[@as integer]]
		return rank >= n
	elseif kind == "zonemaster" and moment.kind == "zoneMaster" then
		return achievement.zone == n
	elseif kind == "legend" and moment.kind == "legend" then
		return achievement.itemID == n
	end
	return false
end

-- The titles the state newly earns (LED-R75, LED-R76), each added to the celebrated set's title keys: a level,
-- Prestige, Zone Master or Legend title rides as "Title: {title}" in the moment that earned it, and a `complete.*`
-- title raises its own `completeTitle` moment, with `cast` (LED-R97). A title whose moment isn't raised (its level or
-- zone celebrated before titles were) is added with no moment, as is a title with no text (LED-R161).
---@param celebrated LedgerCelebrated
---@param state LedgerState
---@param moments PagleMoment[] the moments raised so far, which this adds to
---@param achievements LedgerAchievement[] the achievement of each moment
---@param outlets LedgerOutlets
---@param lookups LedgerLookups
---@param cast string? the entry's Cast, for a completeTitle
---@return string[] keys the titles newly celebrated, in LED-R75's order
local function celebrateTitles(celebrated, state, moments, achievements, outlets, lookups, cast)
	local keys =
		ns.NewTitles({ world = lookups.world, state = state, celebrated = celebrated, getItem = lookups.GetItem })
	local L, text = ns.L, titleText(outlets)
	---@type { [integer]: string[] }
	local riding = {}
	local count = #moments
	for _, key in ipairs(keys) do
		celebrated.titles[key] = true
		local name = ns.TitleName(key, text)
		local kind, n = ns.TitleKind(key)
		if name and kind == "complete" then
			moments[#moments + 1] = {
				rung = "banner",
				kind = "completeTitle",
				order = 140,
				title = L.TITLE_EARNED,
				text = name,
				stamp = L.TITLE_LINE:format(name),
				icon = TITLE_ICON,
				cast = cast,
				seal = "quill",
			}
			achievements[#achievements + 1] = { kind = "completeTitle", cast = cast, coins = 0 }
		elseif name and kind then
			for i = 1, count do
				if
					carries(moments[i], achievements[i], kind, n --[[@as integer|string]])
				then
					riding[i] = riding[i] or {}
					table.insert(riding[i], L.TITLE_LINE:format(name))
					break
				end
			end
		end
	end
	for i, lines in pairs(riding) do
		local moment, titles = moments[i], table.concat(lines, "\n")
		-- A level-up's or Prestige's text is its titles alone; a Zone Master's or Legend's adds them (LED-R97).
		if moment.kind == "levelUp" or moment.kind == "prestige" then
			moment.text = titles
		else
			moment.text = L.TEXT_WITH_TITLE:format(moment.text, titles)
		end
	end
	return keys
end

--- The moments (LED-R97) of the achievements in `earned` not yet celebrated, in order, each added to the set
--- (LED-R91), then the titles they newly earn (LED-R75): what a live entry or a projection's done (LED-R93) raises.
---@param celebrated LedgerCelebrated
---@param state LedgerState
---@param earned LedgerAchievement[]
---@param outlets LedgerOutlets
---@param lookups LedgerLookups
---@param cast string? the entry's Cast, for a completeTitle; nil in a done
---@return PagleMoment[] moments
---@return LedgerAchievement[] achievements the achievement of each moment
---@return string[] titles the title keys newly celebrated, in LED-R75's order
function ns.CelebrateEarned(celebrated, state, earned, outlets, lookups, cast)
	local before = {}
	for rank, level in pairs(celebrated.levels) do
		before[rank] = level
	end
	local moments, achievements = {}, {}
	for _, achievement in ipairs(earned) do
		local celebrateKind = celebrate[achievement.kind]
		local moment = celebrateKind and celebrateKind(celebrated, state, achievement, outlets, before)
		if moment then
			moments[#moments + 1] = moment
			achievements[#achievements + 1] = achievement
		end
	end
	local titles = celebrateTitles(celebrated, state, moments, achievements, outlets, lookups, cast)
	return moments, achievements, titles
end

--- Celebrates one `"live"` entry (LED-R91, LED-R96, LED-R97): the moment of each achievement it earned that isn't
--- celebrated yet, in the order earned, each added to the set, and the titles it newly earns. The zone a Cast fished
--- joins the set too.
---@param celebrated LedgerCelebrated
---@param state LedgerState the state with the entry applied
---@param record PagleRecord
---@param earned LedgerAchievement[] what the fold reported for the entry
---@param outlets LedgerOutlets
---@param lookups LedgerLookups the world index and Core's GetItem, for the titles
---@return PagleMoment[]
function ns.Celebrate(celebrated, state, record, earned, outlets, lookups)
	local cast
	if record.kind == "cast" then
		cast = record.id
		local zone = (record --[[@as PagleCast]]).conditions.zone
		if state.zones[zone] and celebrated.zones[zone] == nil then
			celebrated.zones[zone] = 0
		end
	end
	return (ns.CelebrateEarned(celebrated, state, earned, outlets, lookups, cast))
end
