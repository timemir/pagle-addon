-- A catalogue for Stats' specs, in the shape of Core's generated ns.catalogue (DATA-R76), served to Stats through
-- FakePagle's fake.setCatalogue: Stats' specs run on it, never on the shipped catalogue. spec/Pagle_Stats/support.lua
-- serves it, and holds its IDs (stats.IDS) and the client's names for them (stats.NAMES); a spec reads it with
--
--   local catalogue = dofile("spec/Pagle_Stats/fixtures/Catalogue.lua")
--
-- which returns a new table each time, so a spec may change its copy. What each piece is for (stats.md):
--
--   Darkshore (148)       a zone with a skillBase and a confirmed line (STA-R12): 75, skillBaseConfirmed = true
--     Auberdine (442)     a subzone with its own catches (STA-R17)
--     Bashal'Aran (446)   a subzone with none, whose rows are its zone's own catches (STA-R17)
--   Elwynn Forest (12)    a zone with no skillBase, so no line and side `na` (STA-R12, STA-R13)
--   Stranglethorn (33)    a zone whose line isn't confirmed: skillBase 130, skillBaseConfirmed = false
--   Stormwind City (1519) an area with hasData = false: no catch data (LOG-R55)
--   Feralas (357)         skillBase 205, so its line is 300 (STA-R12); its windows come from a Noise item (day), a fish
--                         (night) and a removed item (summer), so a zone's windows include Noise's and removed ones'
--                         (STA-R16)
--     Feathermoon Stronghold (1116)  a subzone with its own skillBase (300), which its zone's line overrides (STA-R12)
--
--   Nightfin (13759)      gated by `night` in Darkshore, ungated in Elwynn (STA-R14)
--   Firefin (6359)        gated by `night` in Darkshore's own list, ungated in Auberdine's: mixed entries in one zone,
--                         so no window in Darkshore (STA-R14)
--   Blackmouth (6358)     pool-associated (`pool`, LOG-R55, LOG-R56; STA-R18's Pools group)
--   Summer Bass (13756)   gated by `summer` in Elwynn; Mud Snapper (6289) by `day` in Elwynn (STA-R15, STA-R16)
--   Minor Mana Potion (2455)  a Noise item, on Stranglethorn's list (STA-R16, STA-R17)
--   Rusted Lure (90001)   a removed item, still on Darkshore's list as STA-R17's guard sees it; no quality
--   Mackerel (6303)       an entry with confirmed = true; most entries have confirmed = false
--   Smallfish (6291)      on Auberdine's and Elwynn's lists
--   gateConfirmed         Nightfin's gate in Darkshore is unconfirmed (false), Summer Bass's in Elwynn confirmed
--
-- Windows (LOG-R48, DATA-R35): day is 06:00–18:00 and night 18:00–06:00 realm time, so every minute is in exactly one
-- of them; summer runs 20 March to 18 September. FakePagle's clock starts at realm 08:15 on 11 October: day, not
-- summer.
--
-- Later tickets add items, areas, entries and windows at the end of their lists and never change an entry already here.

local DARKSHORE, AUBERDINE, BASHAL_ARAN = 148, 442, 446
local ELWYNN, STRANGLETHORN, STORMWIND = 12, 33, 1519
local FERALAS, FEATHERMOON = 357, 1116

local MACKEREL, BLACKMOUTH, FIREFIN, NIGHTFIN = 6303, 6358, 6359, 13759
local BASS, MUD_SNAPPER, SMALLFISH = 13756, 6289, 6291
local MANA_POTION, RUSTED_LURE = 2455, 90001

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

-- A fish of its own Species, with a quality.
---@param itemID integer
---@param quality integer
---@param fields table?
---@return table
local function fish(itemID, quality, fields)
	local record = item("fish", { species = itemID, quality = quality })
	for key, value in pairs(fields or {}) do
		record[key] = value
	end
	return record
end

-- An area record (PagleArea): a zone with data, no line and no catches unless `fields` says otherwise.
---@param fields table
---@return table
local function area(fields)
	local record = { parent = 0, continent = 0, hasData = true, skillBaseConfirmed = false, catches = {} }
	for key, value in pairs(fields) do
		record[key] = value
	end
	return record
end

-- A catch entry (PagleCatchEntry), ungated and unconfirmed.
---@param itemID integer
---@return table
local function listed(itemID)
	return { itemID = itemID, confirmed = false }
end

-- A catch entry gated by window `window` with spec `gate`, the gate unconfirmed unless `gateConfirmed`.
---@param itemID integer
---@param window string
---@param gate table
---@param gateConfirmed boolean?
---@return table
local function gated(itemID, window, gate, gateConfirmed)
	return { itemID = itemID, confirmed = false, window = window, gate = gate, gateConfirmed = gateConfirmed == true }
end

return {
	fingerprint = "57a757a757a757a7",
	items = {
		[MACKEREL] = fish(MACKEREL, 1),
		[BLACKMOUTH] = fish(BLACKMOUTH, 1, { pool = true }),
		[FIREFIN] = fish(FIREFIN, 1),
		[NIGHTFIN] = fish(NIGHTFIN, 1),
		[BASS] = fish(BASS, 1),
		[MUD_SNAPPER] = fish(MUD_SNAPPER, 1),
		[SMALLFISH] = fish(SMALLFISH, 1),
		[MANA_POTION] = item("other", { quality = 1, noise = true }),
		[RUSTED_LURE] = item("other", { removed = true }),
	},
	areas = {
		[DARKSHORE] = area({
			continent = 1,
			skillBase = 75,
			skillBaseConfirmed = true,
			catches = {
				{ itemID = MACKEREL, confirmed = true },
				listed(BLACKMOUTH),
				gated(FIREFIN, "night", NIGHT),
				gated(NIGHTFIN, "night", NIGHT),
				listed(RUSTED_LURE),
			},
		}),
		[AUBERDINE] = area({
			parent = DARKSHORE,
			continent = 1,
			catches = { listed(FIREFIN), listed(SMALLFISH) },
		}),
		[BASHAL_ARAN] = area({ parent = DARKSHORE, continent = 1 }),
		[ELWYNN] = area({
			catches = {
				listed(NIGHTFIN),
				gated(BASS, "summer", SUMMER, true),
				gated(MUD_SNAPPER, "day", DAY),
				listed(SMALLFISH),
			},
		}),
		[STRANGLETHORN] = area({
			skillBase = 130,
			catches = { listed(MACKEREL), listed(MANA_POTION) },
		}),
		[STORMWIND] = area({ hasData = false }),
		[FERALAS] = area({
			continent = 1,
			skillBase = 205,
			catches = {
				gated(NIGHTFIN, "night", NIGHT),
				gated(MANA_POTION, "day", DAY),
				gated(RUSTED_LURE, "summer", SUMMER),
			},
		}),
		[FEATHERMOON] = area({ parent = FERALAS, continent = 1, skillBase = 300 }),
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
