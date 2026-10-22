if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The zone crests (LED-R113–R115): fifty-three earned goods in Core's crest slot, one per zone in the table below, each
-- earned when its zone's shown rank is Master and saying, until then, how far the zone has come. Pure logic,
-- everything passed in (CORE-R7); adapter/Bindings.lua registers them after the bindings.

--- Core's crest slot (SHOP-R25): open to earned goods (SHOP-R23), so the Ledger's zone crests go in it.
ns.CREST_SLOT = "core.crest"

--- The zone crests' group in the crest slot's list: the slot names its groups, and each good its group's key.
ns.ZONE_CREST_GROUP = "zone"

-- The crests' textures, the Ledger's own (SHOP-R25): each 256 x 256, the shield 120:140 at its full height, centred.
local ICONS = "Interface\\AddOns\\Pagle_Ledger\\media\\crests\\"

--- A zone crest (LED-R113): its key (`ledger.crest.<key>`, its lore `crest.<key>.*` and its texture), its zone's
--- areaID and the zone's ContinentID (0 the Eastern Kingdoms, 1 Kalimdor, 2991 Forever's isles).
---@class LedgerZoneCrest
---@field key string
---@field areaID integer
---@field continent integer

--- LED-R113's table: the two continents' outdoor zones (the mountain's gate, the lake and the sea among them, areaIDs
--- 25, 170 and 457), their capital cities and Forever's new zones, the six not yet charted among them, each
--- continent's in its zones' enUS order. No dungeon, raid or battleground.
---@type LedgerZoneCrest[]
ns.ZONE_CRESTS = {
	{ key = "alterac", areaID = 36, continent = 0 },
	{ key = "arathi", areaID = 45, continent = 0 },
	{ key = "badlands", areaID = 3, continent = 0 },
	{ key = "blackrock", areaID = 25, continent = 0 },
	{ key = "blastedlands", areaID = 4, continent = 0 },
	{ key = "burningsteppes", areaID = 46, continent = 0 },
	{ key = "deadwind", areaID = 41, continent = 0 },
	{ key = "dunmorogh", areaID = 1, continent = 0 },
	{ key = "duskwood", areaID = 10, continent = 0 },
	{ key = "easternplague", areaID = 139, continent = 0 },
	{ key = "elwynn", areaID = 12, continent = 0 },
	{ key = "hillsbrad", areaID = 267, continent = 0 },
	{ key = "hinterlands", areaID = 47, continent = 0 },
	{ key = "ironforge", areaID = 1537, continent = 0 },
	{ key = "lochmodan", areaID = 38, continent = 0 },
	{ key = "lordamere", areaID = 170, continent = 0 },
	{ key = "redridge", areaID = 44, continent = 0 },
	{ key = "riverglades", areaID = 16591, continent = 0 },
	{ key = "searinggorge", areaID = 51, continent = 0 },
	{ key = "silverpine", areaID = 130, continent = 0 },
	{ key = "stormwind", areaID = 1519, continent = 0 },
	{ key = "stranglethorn", areaID = 33, continent = 0 },
	{ key = "swampofsorrows", areaID = 8, continent = 0 },
	{ key = "tirisfal", areaID = 85, continent = 0 },
	{ key = "undercity", areaID = 1497, continent = 0 },
	{ key = "westernplague", areaID = 28, continent = 0 },
	{ key = "westfall", areaID = 40, continent = 0 },
	{ key = "wetlands", areaID = 11, continent = 0 },
	{ key = "ashenvale", areaID = 331, continent = 1 },
	{ key = "azshara", areaID = 16, continent = 1 },
	{ key = "barrens", areaID = 17, continent = 1 },
	{ key = "darkshore", areaID = 148, continent = 1 },
	{ key = "darnassus", areaID = 1657, continent = 1 },
	{ key = "desolace", areaID = 405, continent = 1 },
	{ key = "durotar", areaID = 14, continent = 1 },
	{ key = "dustwallow", areaID = 15, continent = 1 },
	{ key = "felwood", areaID = 361, continent = 1 },
	{ key = "feralas", areaID = 357, continent = 1 },
	{ key = "moonglade", areaID = 493, continent = 1 },
	{ key = "hyjal", areaID = 616, continent = 1 },
	{ key = "mulgore", areaID = 215, continent = 1 },
	{ key = "orgrimmar", areaID = 1637, continent = 1 },
	{ key = "shendralas", areaID = 16651, continent = 1 },
	{ key = "silithus", areaID = 1377, continent = 1 },
	{ key = "stonetalon", areaID = 406, continent = 1 },
	{ key = "tanaris", areaID = 440, continent = 1 },
	{ key = "teldrassil", areaID = 141, continent = 1 },
	{ key = "thousandneedles", areaID = 400, continent = 1 },
	{ key = "thunderbluff", areaID = 1638, continent = 1 },
	{ key = "ungoro", areaID = 490, continent = 1 },
	{ key = "veiledsea", areaID = 457, continent = 1 },
	{ key = "winterspring", areaID = 618, continent = 1 },
	{ key = "zephras", areaID = 16593, continent = 2991 },
}

--- A zone crest's good ID (LED-R113).
---@param crest LedgerZoneCrest
---@return string
function ns.ZoneCrestID(crest)
	return "ledger.crest." .. crest.key
end

-- Each continent's place in LED-R113's order: the Eastern Kingdoms, Kalimdor, then any other.
local CONTINENT_ORDER = { [0] = 1, [1] = 2 }

--- The zone crests in LED-R113's order, as a new list: by continent (the Eastern Kingdoms, Kalimdor, then any other,
--- by ContinentID), each continent's by its zones' names from `areaName`, then by key. A zone the client has no name
--- for comes after its continent's named ones.
---@param areaName fun(areaID: integer): string? C_Map.GetAreaInfo
---@return LedgerZoneCrest[]
function ns.SortedZoneCrests(areaName)
	local names, sorted = {}, {}
	for i, crest in ipairs(ns.ZONE_CRESTS) do
		names[crest] = areaName(crest.areaID)
		sorted[i] = crest
	end
	table.sort(sorted, function(a, b)
		local orderA, orderB = CONTINENT_ORDER[a.continent] or 3, CONTINENT_ORDER[b.continent] or 3
		if orderA ~= orderB then
			return orderA < orderB
		elseif a.continent ~= b.continent then
			return a.continent < b.continent
		end
		local nameA, nameB = names[a], names[b]
		if (nameA == nil) ~= (nameB == nil) then
			return nameA ~= nil
		elseif nameA ~= nameB then
			return nameA < nameB
		end
		return a.key < b.key
	end)
	return sorted
end

--- Whether the zone crest of `areaID` is earned (LED-R114): its zone's rank is Master, the higher of the computed
--- rank and the celebrated one (LED-R52), so it is never lost, not to new data, a rebuild or a Prestige (LED-R92),
--- nor when the zone stops being charted (LED-R54 keeps its celebrated rank). Without a state (the projection not
--- built yet), the celebrated rank alone.
---@param state LedgerState?
---@param celebrated LedgerCelebrated
---@param areaID integer
---@return boolean
function ns.ZoneCrestEarned(state, celebrated, areaID)
	local zoneState = state and state.zones[areaID]
	local rank = math.max(zoneState and zoneState.rank or 0, celebrated.zones and celebrated.zones[areaID] or 0)
	return rank >= ns.ZONE_MASTER
end

-- A state with nothing caught, for the texts before the projection has one.
local NO_STATE = { zones = {} }

--- A zone crest's texts while it isn't earned (LED-R115): the row's tag and the stage's note. A charted zone fished
--- gives its shown rank and completion (LED-R52, LED-R53) and the next requirement (LED-R134); one not fished says
--- so; a zone that isn't charted (LED-R54), that it isn't yet.
---@param world LedgerWorld
---@param state LedgerState?
---@param celebrated LedgerCelebrated
---@param areaID integer
---@param zoneName string the zone's name (LED-R126)
---@return string row
---@return string stage
function ns.ZoneCrestTexts(world, state, celebrated, areaID, zoneName)
	local L = ns.L
	if not world.zones[areaID] then
		return L.CREST_UNCHARTED, L.CREST_NOTE_UNCHARTED:format(zoneName)
	end
	state = state or NO_STATE
	local shown = ns.ShownZoneRank(world, state, celebrated, areaID)
	if shown == 0 then
		return L.CREST_UNFISHED, L.CREST_NOTE_UNFISHED:format(zoneName)
	end
	local rank = L.ZONE_RANKS[shown]
	local completion = ns.ZoneCompletion(world, state, areaID) or 0
	local nextLine = ns.NextRequirement(world, state, celebrated, areaID) or ""
	return L.CREST_PROGRESS:format(rank, completion), L.CREST_NOTE_PROGRESS:format(zoneName, rank, completion, nextLine)
end

--- Whether a live entry's achievements raise a zone to Master (LED-R114): a `zoneRank` reaching it, the moment the
--- Ledger calls `M:RefreshGoods()` (SHOP-R31).
---@param earned LedgerAchievement[]
---@return boolean
function ns.ZoneMasterReached(earned)
	for _, achievement in ipairs(earned) do
		if achievement.kind == "zoneRank" then
			for _, rank in ipairs(achievement.ranks) do
				if rank >= ns.ZONE_MASTER then
					return true
				end
			end
		end
	end
	return false
end

--- What the zone crests read, each when Core or the shop asks.
---@class LedgerZoneCrestHooks
---@field state fun(): LedgerState?           -- the projection's state as it stands, mid-update too
---@field updating fun(): boolean             -- the projection is updating (LOG-R74)
---@field celebrated fun(): LedgerCelebrated  -- the celebrated set (LED-R90)
---@field world fun(): LedgerWorld            -- the world index (LED-R10)
---@field areaName fun(areaID: integer): string? -- C_Map.GetAreaInfo (LED-R126)

--- The zone crests' goods, in LED-R113's order: `ledger.crest.<key>` in Core's crest slot, in the zone group, named
--- and described by lore (or named by its ID while its key has no text, LED-R161), with the Ledger's texture. Each is
--- earned (LED-R114) from the state as it stands when Core asks: only at registration, after a live entry and after
--- a done (SHOP-R31). Its earnedText is a function (SHOP-R22, LED-R115) the shop calls while drawing it unearned:
--- from the projection's last finished state, and while it updates, the texts it gave last (none before any). No
--- preview: Core's crest slot draws a crest's bookplate (SHOP-R25).
---@param hooks LedgerZoneCrestHooks
---@return PagleGood[]
function ns.ZoneCrestGoods(hooks)
	local goods = {}
	for i, crest in ipairs(ns.SortedZoneCrests(hooks.areaName)) do
		local id, areaID = ns.ZoneCrestID(crest), crest.areaID
		---@type string?, string?
		local lastRow, lastStage
		goods[i] = {
			id = id,
			slot = ns.CREST_SLOT,
			group = ns.ZONE_CREST_GROUP,
			name = ns.Lore("crest." .. crest.key .. ".name") or id,
			description = ns.Lore("crest." .. crest.key .. ".description"),
			icon = ICONS .. crest.key,
			isEarned = function()
				return ns.ZoneCrestEarned(hooks.state(), hooks.celebrated(), areaID)
			end,
			earnedText = function()
				if not hooks.updating() then
					local zoneName = hooks.areaName(areaID) or ns.L.NAME_UNKNOWN
					lastRow, lastStage =
						ns.ZoneCrestTexts(hooks.world(), hooks.state(), hooks.celebrated(), areaID, zoneName)
				end
				return lastRow, lastStage
			end,
		}
	end
	return goods
end
