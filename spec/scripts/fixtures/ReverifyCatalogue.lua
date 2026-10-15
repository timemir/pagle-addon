-- A catalogue in the shape of addons/Pagle/data/Catalogue.lua (ns.catalogue, DATA-R76), for read-wtf_spec.lua's
-- Re-verification run (#262) over M8-Reverify#1, so check 6's flags don't move with the generated data. Elwynn
-- Forest (12, with its subzone Goldshire, 87) and Westfall (40) are charted; Duskwood (10) has no catch data
-- (DATA-R31); 16510 is an alias source standing for Elwynn Forest (DATA-R32), shipped with hasData = false and no
-- catches. The night window is the builders' 21:00 to 06:00.

local ns = select(2, ...)

-- The builders the fixture catalogues share, from this file's own folder.
local build = dofile(debug.getinfo(1, "S").source:match("^@(.-)[^/\\]*$") .. "catalogue_builders.lua")
local night, item, area = build.night, build.item, build.area

ns.catalogue = {
	fingerprint = "0123456789abcdef",
	items = {
		[6291] = item("fish", { species = 6291 }),
		[6303] = item("fish", { species = 6303 }),
		[6309] = item("junk", {}),
	},
	areas = {
		[10] = area(0, { hasData = false }),
		[12] = area(0, {
			catches = {
				{ itemID = 6303, confirmed = false },
				{ itemID = 6291, confirmed = false },
			},
		}),
		[87] = area(12, {}),
		[40] = area(0, { catches = { { itemID = 6309, confirmed = false } } }),
		[16510] = area(0, { continent = 2940, hasData = false }),
	},
	aliases = { [16510] = 12 },
	pools = {},
	windows = { night = { spec = night, confirmed = false } },
	events = {},
	fishingSpells = {},
	auras = {},
}
