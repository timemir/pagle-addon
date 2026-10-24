if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Curio Shop's second and third rounds' earned goods (LED-R118, LED-R119, LED-R164): the counts the fold keeps for
-- them, each good's count and mark, and their texts. Seventeen toast styles in Core's toast style slot (seven of the
-- second round, ten race and faction styles of the third) and nine bindings in Core's binding slot (ADR 0015), whose
-- look and art are Core's. Pure logic, everything passed in (CORE-R7); logic/EarnedGoods.lua
-- turns each into a rule, logic/Fold.lua counts, adapter/Bindings.lua registers.

-- Tunables (ledger.md › Tunables, LED-R118, LED-R119).
--- Through the Ice's zones: Dun Morogh, Alterac Mountains and Winterspring.
local ICE_ZONES = { [1] = true, [36] = true, [618] = true }
--- Breaking Wave's open sea, zone or subzone: The Great Sea, The Veiled Sea, The Forbidding Sea and the South Seas.
local OPEN_SEA = {}
for _, areaID in ipairs({
	214,
	308,
	332,
	457,
	2317,
	2318,
	2319,
	2320,
	2321,
	2322,
	2323,
	2324,
	2325,
	2326,
	2338,
	2339,
	2364,
	2365,
	2397,
	2398,
	2399,
	2400,
	2401,
	2402,
	2403,
	2477,
	16361,
}) do
	OPEN_SEA[areaID] = true
end
--- The third round's race styles (LED-R164): the race ID (the third return of UnitRace) each style counts fish for, and
--- the fish a race or a faction needs. The faction styles count a faction's fish over every race of it.
ns.RACE_STYLES = {
	crier = 1, -- Human
	drum = 2, -- Orc
	hall = 3, -- Dwarf
	glade = 4, -- Night Elf
	shroud = 5, -- Undead
	totem = 6, -- Tauren
	blueprint = 7, -- Gnome
	hex = 8, -- Troll
}
local RACE_FISH = 100
local FACTION_FISH = 300
--- The Catch classes that are fish for those counts (LED-R5, LED-R164): the Species, the Legends and the trophy fish.
local FISH_CLASSES = { species = true, legend = true, trophy = true }
--- The Cross-Stitch Sampler's twenty Species, in the kit's order.
ns.SAMPLER_SPECIES = {
	6291,
	6289,
	6303,
	6308,
	6317,
	6358,
	6359,
	6361,
	6362,
	4603,
	8365,
	21071,
	21153,
	13422,
	13754,
	13758,
	13759,
	13760,
	13889,
	13888,
}
--- The Big-mouth Clam, Crab Carapace's item.
local CLAM = 7973
--- The Deep Lure's hours: realm minutes below this, 00:00 to 03:59.
local DEEP_BEFORE_MINUTE = 240
--- Carved Heartwood's run of got-away Casts.
local HEARTWOOD_RUN = 10
--- Realm dates a zone must rest before its next first Catch of the day is a glass shard (LED-R119).
local SHARD_REST_DAYS = 6

--- The fallback price of the second and third rounds' earned goods (SHOP-R28), which ship in the same release: tier 5,
--- from 90 days after the release that ships them. That release sets its server time here; nil until then, and the goods register with no fallback.
---@type integer?
ns.ROUND_TWO_RELEASE = nil
local FALLBACK_TIER = 5
local FALLBACK_DAYS = 90
local SECONDS_PER_DAY = 86400

--- What a good's count counts (LED-R118): `shards` glass shards (LED-R119), `deep` caught Casts at realm minute < 240,
--- `pairs` back-to-back Species pairs, `records` size records beaten (LED-R82), `species` Species caught (LED-R5),
--- `ice` caught Casts in the ice zones, `sampler` the sampler's Species caught, `sea` caught Casts at sea, `zones`
--- zones fished (LED-R6), `afterRun` a caught Cast after a run of got-away ones (0 or 1), `masters` zones at Master
--- (LED-R52), `days` realm dates fished, `casts` Casts (LED-R93), `lures` different lures, `clams` Big-mouth Clams,
--- `prestige` the prestige rank (LED-R34).
--- The third round's are `race1`–`race8` (fish caught by characters of that race ID) and `alliance` and `horde`
--- (fish caught by characters of that faction), LED-R164.
---@alias LedgerCountName "shards"|"deep"|"pairs"|"records"|"species"|"ice"|"sampler"|"sea"|"zones"|"afterRun"|"masters"|"days"|"casts"|"lures"|"clams"|"prestige"|"race1"|"race2"|"race3"|"race4"|"race5"|"race6"|"race7"|"race8"|"alliance"|"horde"

--- One of the second round's earned goods (LED-R118): its rule is its count at its mark or above.
---@class LedgerCountedGood
---@field id string
---@field earn string          -- its rule's name, the good's key: L.EARNED_TEXT and L.EARNED_UNIT are keyed by it
---@field count LedgerCountName
---@field mark integer
---@field slot? string         -- the toast styles' Core slot; the bindings' is Core's binding slot (LED-R110)
---@field icon? string         -- the toast styles' icon on the shop's row (Core draws the style itself, ANN-R82); the
---                               bindings' is the ledger book (ns.BINDING_ICON)

local ICONS = "Interface\\Icons\\"

--- LED-R118's goods, in its order: the seven toast styles, then the nine bindings; then LED-R164's ten toast styles, the
--- race styles and the faction styles.
---@type LedgerCountedGood[]
ns.COUNTED_GOODS = {
	{
		id = "ledger.toaststyle.glass",
		earn = "glass",
		count = "shards",
		mark = 12,
		slot = "core.toaststyle",
		icon = ICONS .. "Spell_Holy_HolyBolt",
	},
	{
		id = "ledger.toaststyle.deep",
		earn = "deep",
		count = "deep",
		mark = 100,
		slot = "core.toaststyle",
		icon = ICONS .. "INV_Misc_Orb_03",
	},
	{
		id = "ledger.toaststyle.koi",
		earn = "koi",
		count = "pairs",
		mark = 25,
		slot = "core.toaststyle",
		icon = ICONS .. "INV_Misc_Fish_09",
	},
	{
		id = "ledger.toaststyle.trophy",
		earn = "trophy",
		count = "records",
		mark = 25,
		slot = "core.toaststyle",
		icon = ICONS .. "INV_Misc_Fish_02",
	},
	{
		id = "ledger.toaststyle.slate",
		earn = "slate",
		count = "species",
		mark = 30,
		slot = "core.toaststyle",
		icon = ICONS .. "INV_Misc_StoneTablet_05",
	},
	{
		id = "ledger.toaststyle.ice",
		earn = "ice",
		count = "ice",
		mark = 100,
		slot = "core.toaststyle",
		icon = ICONS .. "Spell_Frost_FrostNova",
	},
	{
		id = "ledger.toaststyle.stitch",
		earn = "stitch",
		count = "sampler",
		mark = #ns.SAMPLER_SPECIES,
		slot = "core.toaststyle",
		icon = ICONS .. "INV_Fabric_Linen_01",
	},
	-- LED-R164's race styles (a race's fish) and faction styles (a faction's fish), in the kit's order.
	{
		id = "ledger.toaststyle.crier",
		earn = "crier",
		count = "race1",
		mark = RACE_FISH,
		slot = "core.toaststyle",
		icon = ICONS .. "INV_Scroll_05",
	},
	{
		id = "ledger.toaststyle.hall",
		earn = "hall",
		count = "race3",
		mark = RACE_FISH,
		slot = "core.toaststyle",
		icon = ICONS .. "Trade_BlackSmithing",
	},
	{
		id = "ledger.toaststyle.glade",
		earn = "glade",
		count = "race4",
		mark = RACE_FISH,
		slot = "core.toaststyle",
		icon = ICONS .. "Spell_Nature_WispSplode",
	},
	{
		id = "ledger.toaststyle.blueprint",
		earn = "blueprint",
		count = "race7",
		mark = RACE_FISH,
		slot = "core.toaststyle",
		icon = ICONS .. "Trade_Engineering",
	},
	{
		id = "ledger.toaststyle.drum",
		earn = "drum",
		count = "race2",
		mark = RACE_FISH,
		slot = "core.toaststyle",
		icon = ICONS .. "Ability_Warrior_BattleShout",
	},
	{
		id = "ledger.toaststyle.shroud",
		earn = "shroud",
		count = "race5",
		mark = RACE_FISH,
		slot = "core.toaststyle",
		icon = ICONS .. "Spell_Shadow_RaiseDead",
	},
	{
		id = "ledger.toaststyle.totem",
		earn = "totem",
		count = "race6",
		mark = RACE_FISH,
		slot = "core.toaststyle",
		icon = ICONS .. "Spell_Nature_StrengthOfEarthTotem02",
	},
	{
		id = "ledger.toaststyle.hex",
		earn = "hex",
		count = "race8",
		mark = RACE_FISH,
		slot = "core.toaststyle",
		icon = ICONS .. "INV_Misc_Bone_TrollSkull_01",
	},
	{
		id = "ledger.toaststyle.lion",
		earn = "lion",
		count = "alliance",
		mark = FACTION_FISH,
		slot = "core.toaststyle",
		icon = ICONS .. "INV_Shield_06",
	},
	{
		id = "ledger.toaststyle.warband",
		earn = "warband",
		count = "horde",
		mark = FACTION_FISH,
		slot = "core.toaststyle",
		icon = ICONS .. "Ability_Warrior_WarCry",
	},
	{ id = "ledger.binding.wave", earn = "wave", count = "sea", mark = 300 },
	{ id = "ledger.binding.logbook", earn = "logbook", count = "zones", mark = 25 },
	{ id = "ledger.binding.heartwood", earn = "heartwood", count = "afterRun", mark = 1 },
	{ id = "ledger.binding.stormglass", earn = "stormglass", count = "masters", mark = 10 },
	{ id = "ledger.binding.lacquer", earn = "lacquer", count = "days", mark = 30 },
	{ id = "ledger.binding.knit", earn = "knit", count = "casts", mark = 10000 },
	{ id = "ledger.binding.flywallet", earn = "flywallet", count = "lures", mark = 5 },
	{ id = "ledger.binding.carapace", earn = "carapace", count = "clams", mark = 50 },
	{ id = "ledger.binding.ember", earn = "ember", count = "prestige", mark = 7 },
}

--- The second round's good of ID `goodID` (LED-R118), or nil for any other good.
---@param goodID string?
---@return LedgerCountedGood?
function ns.CountedGood(goodID)
	for _, good in ipairs(ns.COUNTED_GOODS) do
		if good.id == goodID then
			return good
		end
	end
	return nil
end

--- Fresh counts (ledger.md › Data, LedgerCounts), for a fresh state.
---@return LedgerCounts
function ns.NewEarnedCounts()
	return {
		shards = 0,
		lastDay = {},
		deep = 0,
		pairs = 0,
		lastSpecies = {},
		records = 0,
		ice = 0,
		sea = 0,
		gotAwayRun = 0,
		afterRun = false,
		days = {},
		lures = {},
		clams = 0,
		races = {},
		factions = {},
	}
end

--- A realm date's day number: days since 1970-01-01 (Howard Hinnant's days_from_civil), so dates subtract.
---@param date { year: integer, month: integer, day: integer }
---@return integer
function ns.DayNumber(date)
	local year, month = date.year, date.month
	year = month <= 2 and year - 1 or year
	local era = math.floor(year / 400)
	local yearOfEra = year - era * 400
	local dayOfYear = math.floor((153 * (month > 2 and month - 3 or month + 9) + 2) / 5) + date.day - 1
	local dayOfEra = yearOfEra * 365 + math.floor(yearOfEra / 4) - math.floor(yearOfEra / 100) + dayOfYear
	return era * 146097 + dayOfEra - 719468
end

-- A glass shard (LED-R119): the caught Cast's zone (≠ 0) with no caught Cast on its realm date or the six before.
---@param counts LedgerCounts
---@param zone integer
---@param day integer?
local function countShard(counts, zone, day)
	if zone == 0 or not day then
		return
	end
	local last = counts.lastDay[zone]
	if not last or day - last > SHARD_REST_DAYS then
		counts.shards = counts.shards + 1
	end
	if not last or day > last then
		counts.lastDay[zone] = day
	end
end

--- Counts one Cast (LED-R118, LED-R119), live or not, after the fold has credited it: a got-away Cast only lengthens the
--- run of them; a caught one counts its shard, hour, pair, zones, day, lure and clams, and `beaten`, the size records
--- its Catches beat (LED-R82), and the fish by the race and faction of the character who caught them (LED-R164).
--- `getItem` is Core's (LOG-R55); `getCharacter` gives a character's record by its index in the log (LOG-R25), nil for
--- one it doesn't know.
---@param counts LedgerCounts
---@param record PagleCast
---@param getItem fun(itemID: integer): PagleItem?
---@param beaten integer
---@param getCharacter? fun(index: integer): { raceID: integer?, faction: string? }?
function ns.CountCast(counts, record, getItem, beaten, getCharacter)
	if record.outcome ~= "caught" then
		counts.gotAwayRun = counts.gotAwayRun + 1
		return
	end
	if counts.gotAwayRun >= HEARTWOOD_RUN then
		counts.afterRun = true
	end
	counts.gotAwayRun = 0
	local conditions = record.conditions
	local zone, date = conditions.zone, conditions.date
	local day = date and ns.DayNumber(date) or nil
	countShard(counts, zone, day)
	if day then
		counts.days[day] = true
	end
	local minute = conditions.minute
	if minute and minute < DEEP_BEFORE_MINUTE then
		counts.deep = counts.deep + 1
	end
	if ICE_ZONES[zone] then
		counts.ice = counts.ice + 1
	end
	if OPEN_SEA[zone] or OPEN_SEA[conditions.subzone or 0] then
		counts.sea = counts.sea + 1
	end
	local lure = conditions.lure
	if lure and lure ~= 0 then
		counts.lures[lure] = true
	end
	-- The caught Cast's character, whose race and faction its fish count for (LED-R164).
	local character = getCharacter and getCharacter(record.char) or nil
	-- The Species among its Catches, for the pair with the caught Cast before it.
	local species, paired = {}, false
	for _, catch in ipairs(record.items) do
		local itemID = catch.itemID
		if itemID == CLAM then
			counts.clams = counts.clams + 1
		end
		local item = itemID ~= 0 and getItem(itemID) or nil
		local class = ns.ClassifyCatch(itemID, item)
		if class == "species" and item and item.species then
			species[item.species] = true
			paired = paired or counts.lastSpecies[item.species] == true
		end
		if FISH_CLASSES[class] and character then
			local race, faction = character.raceID, character.faction
			if race then
				counts.races[race] = (counts.races[race] or 0) + 1
			end
			if faction then
				counts.factions[faction] = (counts.factions[faction] or 0) + 1
			end
		end
	end
	if paired then
		counts.pairs = counts.pairs + 1
	end
	counts.lastSpecies = species
	counts.records = counts.records + beaten
end

-- How many entries `set` has, up to `mark`: enough to say whether it is reached.
---@param set table?
---@param mark integer
---@return integer
local function countUpTo(set, mark)
	local n = 0
	for _ in pairs(set or {}) do
		n = n + 1
		if n >= mark then
			break
		end
	end
	return n
end

-- Counts a state saved before LEDGER_RULES_VERSION 7 lacks, until its rebuild.
local NO_COUNTS = ns.NewEarnedCounts()

---@type table<LedgerCountName, fun(view: LedgerEarnedView, counts: LedgerCounts, mark: integer): integer>
local COUNTS = {
	shards = function(_, counts)
		return counts.shards
	end,
	deep = function(_, counts)
		return counts.deep
	end,
	pairs = function(_, counts)
		return counts.pairs
	end,
	records = function(_, counts)
		return counts.records
	end,
	ice = function(_, counts)
		return counts.ice
	end,
	sea = function(_, counts)
		return counts.sea
	end,
	clams = function(_, counts)
		return counts.clams
	end,
	afterRun = function(_, counts)
		return counts.afterRun and 1 or 0
	end,
	days = function(_, counts, mark)
		return countUpTo(counts.days, mark)
	end,
	lures = function(_, counts, mark)
		return countUpTo(counts.lures, mark)
	end,
	species = function(view, _, mark)
		return countUpTo(view.state and view.state.species, mark)
	end,
	zones = function(view, _, mark)
		return countUpTo(view.state and view.state.zones, mark)
	end,
	casts = function(view)
		return view.state and view.state.casts or 0
	end,
	-- The sampler's Species with a Catch.
	sampler = function(view)
		local species = view.state and view.state.species or {}
		local n = 0
		for _, id in ipairs(ns.SAMPLER_SPECIES) do
			if species[id] then
				n = n + 1
			end
		end
		return n
	end,
	-- Zones at Master, the higher of the computed and the celebrated rank, as the zone crests (LED-R114).
	masters = function(view)
		local n = 0
		local seen = {}
		local zones = view.state and view.state.zones or {}
		for _, set in ipairs({ zones, view.celebrated.zones or {} }) do
			for zone in pairs(set) do
				if not seen[zone] then
					seen[zone] = true
					if ns.ZoneCrestEarned(view.state, view.celebrated, zone) then
						n = n + 1
					end
				end
			end
		end
		return n
	end,
	-- The higher of the state's prestige rank and the highest celebrated (LED-R34, LED-R90).
	prestige = function(view)
		return math.max(view.state and view.state.prestige or 0, view.celebrated.prestige or 0)
	end,
}

-- LED-R164's fish counts. A state saved before LEDGER_RULES_VERSION 10 has no `races` or `factions` until it rebuilds.
for raceID = 1, 8 do
	COUNTS["race" .. raceID] = function(_, counts)
		return (counts.races or {})[raceID] or 0
	end
end
COUNTS.alliance = function(_, counts)
	return (counts.factions or {}).Alliance or 0
end
COUNTS.horde = function(_, counts)
	return (counts.factions or {}).Horde or 0
end

--- Good `good`'s count now (LED-R118), over the state and the celebrated set; 0 without a state, and a state saved
--- before the counts were kept counts nothing of its own until it rebuilds.
---@param good LedgerCountedGood
---@param view LedgerEarnedView
---@return integer
function ns.EarnedCount(good, view)
	local counts = view.state and view.state.counts or NO_COUNTS
	return COUNTS[good.count](view, counts, good.mark)
end

--- A counted good's texts while it isn't earned (LED-R118, SHOP-R22): the row's tag, "{n} of {mark} {unit}" (the
--- plain earned text for a good without a unit, whose mark is one step), and the stage's note, the earned text.
---@param good LedgerCountedGood
---@param n integer its count
---@param formatNumber fun(n: integer): string BreakUpLargeNumbers
---@return string tag
---@return string note
function ns.EarnedCountTexts(good, n, formatNumber)
	local L = ns.L
	local text, unit = L.EARNED_TEXT[good.earn], L.EARNED_UNIT[good.earn]
	if not unit then
		return text, text
	end
	return L.EARNED_COUNT:format(formatNumber(math.min(n, good.mark)), formatNumber(good.mark), unit), text
end

--- The fallback the second round's earned goods register with (SHOP-R28): tier 5 from 90 days after
--- `ns.ROUND_TWO_RELEASE`, or nothing while that is nil.
---@return integer? tier
---@return integer? from server time
function ns.RoundTwoFallback()
	local release = ns.ROUND_TWO_RELEASE
	if not release then
		return nil, nil
	end
	return FALLBACK_TIER, release + FALLBACK_DAYS * SECONDS_PER_DAY
end

--- What LED-R118's goods read when the shop asks.
---@class LedgerCountedHooks
---@field earnedBy fun(goodID: string, rule: string): boolean -- the good's rule or the celebrated set (LED-R118)
---@field count fun(good: LedgerCountedGood): integer?        -- its count now; nil while the projection updates
---@field formatNumber fun(n: integer): string                -- BreakUpLargeNumbers

--- LED-R118's sixteen goods to register, in its order (SHOP-R23, SHOP-R25): the seven toast styles in Core's
--- `core.toaststyle` slot, then the nine bindings in Core's `core.binding` slot (LED-R110, ADR 0015) with the ledger
--- book's icon (ns.BINDING_ICON). Each is named and described by lore (`ledgergood.<goodID>.name`, `.description`,
--- LED-R160), by its ID while the name has no text (LED-R161), earned by `hooks.earnedBy`, with no preview (Core draws
--- them, ANN-R82, SHOP-R25) and the fallback of ns.RoundTwoFallback. Its earnedText is a function (SHOP-R22): the
--- count's texts, from the count as it stands, and while the projection updates, the texts it gave last (the plain
--- earned text before any).
---@param hooks LedgerCountedHooks
---@return PagleGood[]
function ns.CountedGoods(hooks)
	local tier, from = ns.RoundTwoFallback()
	local goods = {}
	for _, good in ipairs(ns.COUNTED_GOODS) do
		local id, earn = good.id, good.earn
		local lastTag, lastNote = ns.L.EARNED_TEXT[earn], ns.L.EARNED_TEXT[earn]
		goods[#goods + 1] = {
			id = id,
			slot = good.slot or ns.BINDING_SLOT,
			name = ns.Lore("ledgergood." .. id .. ".name") or id,
			description = ns.Lore("ledgergood." .. id .. ".description"),
			icon = good.icon or ns.BINDING_ICON,
			isEarned = function()
				return hooks.earnedBy(id, earn)
			end,
			earnedText = function()
				local n = hooks.count(good)
				if n then
					lastTag, lastNote = ns.EarnedCountTexts(good, n, hooks.formatNumber)
				end
				return lastTag, lastNote
			end,
			fallbackTier = tier,
			fallbackFrom = from,
		}
	end
	return goods
end
