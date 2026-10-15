-- A catalogue for Hunts' specs, in the shape of ns.catalogue (DATA-R76), for the fixture Hunt list's Species and
-- classes: nested subzones, gated and ungated catch entries, and skill bases on zones and on areas (LOG-R55). Specs
-- serve it with `fake.setCatalogue(catalogue.base())` before hunts.load(fake). Later tickets may add areas, items
-- and windows at the end of each table and never change an entry already here.
--
--   Darkshore 148 (zone, skill 75):      Nightfin night (gating unconfirmed), Blackmouth, Deviate Fish
--     Auberdine 442 (no base of its own): Nightfin night (gating confirmed)
--       Auberdine Pier 4000 (skill 150):  Forever's Nightfin night-gated by "day", Blackmouth night, Grouper
--   Ashenvale 331 (zone, skill 150):     Forever's Nightfin night (gating unconfirmed)
--   Elwynn Forest 12 (zone, skill 25):   Nightfin ungated, Sunscale day
--   Westfall 40 (zone, no skill base):   Blackmouth, Smallfish
--   Stormwind City 1519 (zone, no data)
--
-- corrected() is a later release with the night window corrected (HNT-R198): night moves from 20:00–06:00 to
-- 21:00–05:00, and Darkshore's and Auberdine's Nightfin are no longer gated, so only Ashenvale's still bites at night.

local catalogue = {}

-- Item IDs: Raw Nightfin Snapper, a Forever item folded into its Species (DATA-R19), Oily Blackmouth, Sunscale
-- Salmon, Darkshore Grouper, Raw Brilliant Smallfish, the fixed.oddity members Deviate Fish and 251524, and the
-- quality.uncommon members 6643 and 19803.
catalogue.NIGHTFIN, catalogue.NIGHTFIN_FOREVER = 13759, 213759
catalogue.BLACKMOUTH, catalogue.SUNSCALE, catalogue.GROUPER, catalogue.SMALLFISH = 6358, 13760, 12238, 6291
catalogue.DEVIATE, catalogue.ODDITY_2 = 6522, 251524
catalogue.UNCOMMON, catalogue.UNCOMMON_2 = 6643, 19803
-- Area IDs.
catalogue.DARKSHORE, catalogue.AUBERDINE, catalogue.PIER = 148, 442, 4000
catalogue.ASHENVALE, catalogue.ELWYNN, catalogue.WESTFALL, catalogue.STORMWIND = 331, 12, 40, 1519
-- The aura on the catalogue's list: Fishing Rack, fixture_rack's (LOG-R55).
catalogue.RACK_AURA = 1280341

-- The names the client gives the fixtures' items and areas, for specs that load them (spec/Pagle_Hunts/support.lua's
-- loadNames) and for logic specs' name stand-ins.
catalogue.NAMES = {
	items = {
		[catalogue.NIGHTFIN] = "Raw Nightfin Snapper",
		[catalogue.BLACKMOUTH] = "Oily Blackmouth",
		[catalogue.DEVIATE] = "Deviate Fish",
		[catalogue.ODDITY_2] = "Whimsyfin",
		[13757] = "Lightning Eel",
		[13756] = "Raw Summer Bass",
		[13755] = "Winter Squid",
	},
	areas = {
		[catalogue.DARKSHORE] = "Darkshore",
		[catalogue.ASHENVALE] = "Ashenvale",
		[catalogue.ELWYNN] = "Elwynn Forest",
		[catalogue.WESTFALL] = "Westfall",
		[10] = "Duskwood",
	},
}

local NIGHT = { time = { { 1200, 360 } } } -- 20:00 to 06:00 realm time
local NIGHT_CORRECTED = { time = { { 1260, 300 } } } -- 21:00 to 05:00
local DAY = { time = { { 360, 1200 } } }
local EXTRAVAGANZA = { events = { 301 } }

local function item(category, fields)
	local record = { category = category, legend = false, noise = false, removed = false, pool = false }
	for key, value in pairs(fields) do
		record[key] = value
	end
	return record
end

local function area(fields)
	local record = { parent = 0, continent = 0, hasData = true, skillBaseConfirmed = false, catches = {} }
	for key, value in pairs(fields) do
		record[key] = value
	end
	return record
end

-- A catch entry: ungated, or gated by `window` (whose spec is `gate`) with its gateConfirmed (LOG-R55).
local function listed(itemID, window, gate, gateConfirmed)
	if not window then
		return { itemID = itemID, confirmed = true }
	end
	return { itemID = itemID, confirmed = true, window = window, gate = gate, gateConfirmed = gateConfirmed }
end

--- The fixture catalogue as first shipped.
---@param corrected boolean? the later release, with the night window corrected (HNT-R198)
---@return table
function catalogue.base(corrected)
	local night = corrected and NIGHT_CORRECTED or NIGHT
	local c = catalogue
	return {
		fingerprint = corrected and "c0aa3c7ed0000002" or "c0aa3c7ed0000001",
		items = {
			[c.NIGHTFIN] = item("fish", { species = c.NIGHTFIN }),
			[c.NIGHTFIN_FOREVER] = item("fish", { species = c.NIGHTFIN }),
			[c.BLACKMOUTH] = item("fish", { species = c.BLACKMOUTH }),
			[c.SUNSCALE] = item("fish", { species = c.SUNSCALE }),
			[c.GROUPER] = item("fish", { species = c.GROUPER }),
			[c.SMALLFISH] = item("fish", { species = c.SMALLFISH }),
			[c.DEVIATE] = item("fish", { species = c.DEVIATE }),
			[c.ODDITY_2] = item("other", {}),
			[c.UNCOMMON] = item("other", { quality = 2 }),
			[c.UNCOMMON_2] = item("other", { quality = 2 }),
		},
		areas = {
			[c.DARKSHORE] = area({
				continent = 1,
				skillBase = 75,
				catches = {
					corrected and listed(c.NIGHTFIN) or listed(c.NIGHTFIN, "night", night, false),
					listed(c.BLACKMOUTH),
					listed(c.DEVIATE),
				},
			}),
			[c.AUBERDINE] = area({
				parent = c.DARKSHORE,
				continent = 1,
				catches = { corrected and listed(c.NIGHTFIN) or listed(c.NIGHTFIN, "night", night, true) },
			}),
			[c.PIER] = area({
				parent = c.AUBERDINE,
				continent = 1,
				skillBase = 150,
				catches = {
					listed(c.NIGHTFIN_FOREVER, "day", DAY, true),
					listed(c.BLACKMOUTH, "night", night, false),
					listed(c.GROUPER),
				},
			}),
			[c.ASHENVALE] = area({
				continent = 1,
				skillBase = 150,
				catches = { listed(c.NIGHTFIN_FOREVER, "night", night, false) },
			}),
			[c.ELWYNN] = area({
				skillBase = 25,
				catches = { listed(c.NIGHTFIN), listed(c.SUNSCALE, "day", DAY, true) },
			}),
			[c.WESTFALL] = area({ catches = { listed(c.BLACKMOUTH), listed(c.SMALLFISH) } }),
			[c.STORMWIND] = area({ hasData = false }),
		},
		aliases = {},
		pools = {},
		windows = {
			night = { spec = night, confirmed = true },
			day = { spec = DAY, confirmed = false },
			["event.301"] = { spec = EXTRAVAGANZA, confirmed = false },
		},
		-- The Extravaganza: Sundays 14:00 for 2 hours, an unconfirmed weekly rule (LOG-R56).
		events = { [301] = { weekday = 1, start = 840, duration = 120, confirmed = false } },
		fishingSpells = { 7731 },
		auras = { c.RACK_AURA },
	}
end

--- The later release: the night window corrected (HNT-R198).
---@return table
function catalogue.corrected()
	return catalogue.base(true)
end

return catalogue
