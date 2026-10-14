-- A catalogue for the Tackle Board's specs, in the shape of Core's generated ns.catalogue (DATA-R76), served through
-- FakePagle's fake.setCatalogue: the Tackle Board's specs run on it, never on the shipped catalogue (M7 graph,
-- conventions). spec/Pagle_TackleBoard/support.lua serves it; a spec reads it with
--
--   local catalogue = dofile("spec/Pagle_TackleBoard/fixtures/Catalogue.lua")
--
-- which returns a new table each time, so a spec may change its copy. The fixture Angler's skill is 150
-- (support.SKILL), so a candidate zone has data and a skillBase at or below 150 (TKB-R30). What each piece is for
-- (tackle-board.md; "eligible" is TKB-R31's eligible Species):
--
--   Kalimdor (continent 1): six candidate zones, so a Wanderer Expedition can target it (TKB-R32)
--     Durotar (14)            skillBase 25; exactly 3 eligible Species (6291, 6303, 6289), with a gated one, a Noise
--                             item, a junk item and a quest fish beside them
--     Teldrassil (141)        skillBase 25; 2 eligible Species, too few for a Variety Notice (TKB-R32), and Noise junk
--     Darkshore (148)         skillBase 75; 5 eligible Species (4–12, a Variety Expedition's zone), two of them only
--       Auberdine (442)       through its subzone; the Mightfish Species twice, as 13893 in Darkshore and 13754 in
--                             Auberdine (its representative is 13754, the lowest, though listed second); two gated
--                             fish, a Legend and a removed fish
--     The Barrens (17)        skillBase 75; 13 eligible Species (13 or more: no Variety Expedition), a gated fish, junk
--     Thousand Needles (400)  skillBase 130; no eligible Species (a gated fish only), a gated container and a treasure
--     Ashenvale (331)         skillBase 150, equal to the Angler's: still a candidate; 3 eligible Species and a trophy
--     Feralas (357)           skillBase 205, above the Angler: never a candidate, and its trophy 92042 is the one
--                             Sub-collection item outside every candidate zone
--     Moonglade (493)         no skillBase: never a candidate (TKB-R30)
--   Eastern Kingdoms (continent 0): two candidate zones, too few for a Wanderer Expedition
--     Elwynn Forest (12)      skillBase 25; a container and a removed container
--     Westfall (40)           skillBase 55; 4 eligible Species
--     Stormwind City (1519)   skillBase 25 but hasData = false: never a candidate (TKB-R30)
--
--   Fish (category fish, quality 1, their own Species) unless listed: Lightning Eel 13757 has quality 2;
--   Large Raw Mightfish 13893 is Species 13754; Oily Blackmouth 6358 is pool-associated.
--   92001 a Legend (quality 4)            92002 a quest fish (category questFish)   92003 a removed fish
--   2455  Minor Mana Potion: Noise         92013 junk that is Noise                   92023 a removed container
--   Sub-collection items (TKB-R46), 7 in candidate zones: junk 92011 (Durotar) and 92012 (The Barrens), containers
--   92021 (Elwynn) and 92022 (quality 2, gated in Thousand Needles), treasures 92031 (quality 2, Thousand Needles) and
--   92032 (quality 3, Auberdine), trophy 92041 (quality 2, Ashenvale); and trophy 92042 (quality 3) in Feralas only.
--   Quality 2: 13757, 92022, 92031, 92041. Quality 3: 92032, 92042. Junk has quality 0.
--
-- Windows (LOG-R48, DATA-R35), only so the gated entries have one: day 06:00–18:00 and night 18:00–06:00 realm
-- time, summer 20 March to 18 September. Generation never uses one (TKB-R31, TKB-R35).
--
-- Later tickets add items, areas, entries and windows at the end of their lists and never change one already here.

local DUROTAR, TELDRASSIL, DARKSHORE, AUBERDINE, BARRENS = 14, 141, 148, 442, 17
local NEEDLES, ASHENVALE, FERALAS, MOONGLADE = 400, 331, 357, 493
local ELWYNN, WESTFALL, STORMWIND = 12, 40, 1519

local SMALLFISH, MACKEREL, MUD_SNAPPER, LOCH_FRENZY, CATFISH = 6291, 6303, 6289, 6317, 6308
local BLACKMOUTH, FIREFIN, ALBACORE, COD, TROUT = 6358, 6359, 6361, 6362, 8365
local MIGHTFISH, LARGE_MIGHTFISH, SQUID, BASS, EEL = 13754, 13893, 13755, 13756, 13757
local REDGILL, NIGHTFIN, SALMON, YELLOWTAIL, GROUPER, SAGEFISH = 13758, 13759, 13760, 4603, 12238, 21071
local LEGEND, QUEST_FISH, REMOVED_FISH, MANA_POTION = 92001, 92002, 92003, 2455
local JUNK_A, JUNK_B, NOISY_JUNK = 92011, 92012, 92013
local CONTAINER_A, CONTAINER_B, REMOVED_CONTAINER = 92021, 92022, 92023
local TREASURE_A, TREASURE_B, TROPHY_A, TROPHY_B = 92031, 92032, 92041, 92042

local DAY = { time = { { 360, 1080 } } }
local NIGHT = { time = { { 1080, 360 } } }
local SUMMER = { season = { { from = { 3, 20 }, to = { 9, 18 } } } }

-- An item record (PagleItem): every boolean false unless `fields` says otherwise.
---@param category string
---@param fields table
---@return table
local function item(category, fields)
	local record = { category = category, legend = false, noise = false, removed = false, pool = false }
	for key, value in pairs(fields) do
		record[key] = value
	end
	return record
end

-- A fish of its own Species, quality 1 and 300 mm typical, unless `fields` says otherwise.
---@param itemID integer
---@param fields table?
---@return table
local function fish(itemID, fields)
	local record = item("fish", { species = itemID, quality = 1, typicalLength = 300 })
	for key, value in pairs(fields or {}) do
		record[key] = value
	end
	return record
end

-- A zone record (PagleArea) on `continent` with `skillBase` and these catches; data, no confirmed line.
---@param continent integer
---@param skillBase integer?
---@param catches table[]
---@return table
local function zone(continent, skillBase, catches)
	return {
		parent = 0,
		continent = continent,
		skillBase = skillBase,
		skillBaseConfirmed = false,
		hasData = true,
		catches = catches,
	}
end

-- A catch entry (PagleCatchEntry), ungated and unconfirmed.
---@param itemID integer
---@return table
local function listed(itemID)
	return { itemID = itemID, confirmed = false }
end

-- A catch entry gated by window `window` with spec `gate`, the gate unconfirmed.
---@param itemID integer
---@param window string
---@param gate table
---@return table
local function gated(itemID, window, gate)
	return { itemID = itemID, confirmed = false, window = window, gate = gate, gateConfirmed = false }
end

return {
	fingerprint = "7ac7b0a47ac7b0a4",
	items = {
		[SMALLFISH] = fish(SMALLFISH, { typicalLength = 150 }),
		[MACKEREL] = fish(MACKEREL),
		[MUD_SNAPPER] = fish(MUD_SNAPPER),
		[LOCH_FRENZY] = fish(LOCH_FRENZY),
		[CATFISH] = fish(CATFISH),
		[BLACKMOUTH] = fish(BLACKMOUTH, { pool = true }),
		[FIREFIN] = fish(FIREFIN),
		[ALBACORE] = fish(ALBACORE),
		[COD] = fish(COD),
		[TROUT] = fish(TROUT),
		[MIGHTFISH] = fish(MIGHTFISH),
		[LARGE_MIGHTFISH] = fish(LARGE_MIGHTFISH, { species = MIGHTFISH }),
		[SQUID] = fish(SQUID),
		[BASS] = fish(BASS),
		[EEL] = fish(EEL, { quality = 2 }),
		[REDGILL] = fish(REDGILL),
		[NIGHTFIN] = fish(NIGHTFIN),
		[SALMON] = fish(SALMON),
		[YELLOWTAIL] = fish(YELLOWTAIL),
		[GROUPER] = fish(GROUPER),
		[SAGEFISH] = fish(SAGEFISH),
		[LEGEND] = fish(LEGEND, { legend = true, quality = 4, typicalLength = 900 }),
		[QUEST_FISH] = item("questFish", { species = QUEST_FISH, quality = 1, typicalLength = 400 }),
		[REMOVED_FISH] = fish(REMOVED_FISH, { removed = true }),
		[MANA_POTION] = item("other", { quality = 1, noise = true }),
		[JUNK_A] = item("junk", { quality = 0 }),
		[JUNK_B] = item("junk", { quality = 0 }),
		[NOISY_JUNK] = item("junk", { quality = 0, noise = true }),
		[CONTAINER_A] = item("container", { quality = 1 }),
		[CONTAINER_B] = item("container", { quality = 2 }),
		[REMOVED_CONTAINER] = item("container", { quality = 1, removed = true }),
		[TREASURE_A] = item("treasure", { quality = 2 }),
		[TREASURE_B] = item("treasure", { quality = 3 }),
		[TROPHY_A] = item("trophy", { quality = 2, family = 1, weight = 8.5 }),
		[TROPHY_B] = item("trophy", { quality = 3, family = 2, weight = 20 }),
	},
	areas = {
		[DUROTAR] = zone(1, 25, {
			listed(SMALLFISH),
			listed(MACKEREL),
			listed(MUD_SNAPPER),
			gated(BASS, "summer", SUMMER),
			listed(MANA_POTION),
			listed(JUNK_A),
			listed(QUEST_FISH),
		}),
		[TELDRASSIL] = zone(1, 25, { listed(SMALLFISH), listed(LOCH_FRENZY), listed(NOISY_JUNK) }),
		[DARKSHORE] = zone(1, 75, {
			{ itemID = MACKEREL, confirmed = true },
			listed(BLACKMOUTH),
			listed(GROUPER),
			listed(LARGE_MIGHTFISH),
			gated(NIGHTFIN, "night", NIGHT),
			gated(FIREFIN, "night", NIGHT),
			listed(LEGEND),
			listed(REMOVED_FISH),
		}),
		[AUBERDINE] = {
			parent = DARKSHORE,
			continent = 1,
			skillBaseConfirmed = false,
			hasData = true,
			catches = { listed(MIGHTFISH), listed(SMALLFISH), listed(TREASURE_B) },
		},
		[BARRENS] = zone(1, 75, {
			listed(SMALLFISH),
			listed(MACKEREL),
			listed(MUD_SNAPPER),
			listed(LOCH_FRENZY),
			listed(CATFISH),
			listed(BLACKMOUTH),
			listed(ALBACORE),
			listed(COD),
			listed(TROUT),
			listed(SQUID),
			listed(REDGILL),
			listed(YELLOWTAIL),
			listed(SAGEFISH),
			gated(SALMON, "day", DAY),
			listed(JUNK_B),
		}),
		[NEEDLES] = zone(1, 130, {
			gated(EEL, "day", DAY),
			gated(CONTAINER_B, "night", NIGHT),
			listed(TREASURE_A),
			listed(MANA_POTION),
		}),
		[ASHENVALE] = zone(1, 150, { listed(ALBACORE), listed(COD), listed(EEL), listed(TROPHY_A) }),
		[FERALAS] = zone(1, 205, { listed(SALMON), listed(YELLOWTAIL), listed(MIGHTFISH), listed(TROPHY_B) }),
		[MOONGLADE] = zone(1, nil, { listed(SMALLFISH), listed(MACKEREL) }),
		[ELWYNN] = zone(0, 25, {
			listed(SMALLFISH),
			listed(MUD_SNAPPER),
			listed(MACKEREL),
			listed(CONTAINER_A),
			listed(REMOVED_CONTAINER),
		}),
		[WESTFALL] = zone(0, 55, { listed(SMALLFISH), listed(MACKEREL), listed(CATFISH), listed(BLACKMOUTH) }),
		[STORMWIND] = {
			parent = 0,
			continent = 0,
			skillBase = 25,
			skillBaseConfirmed = false,
			hasData = false,
			catches = {},
		},
	},
	aliases = {},
	pools = { oilyBlackmouthSchool = { BLACKMOUTH } },
	windows = {
		day = { spec = DAY, confirmed = false },
		night = { spec = NIGHT, confirmed = false },
		summer = { spec = SUMMER, confirmed = false },
	},
	events = {},
	fishingSpells = { 7620, 7731, 7732, 18248 },
	auras = {},
}
