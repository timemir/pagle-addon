-- A catalogue in the shape of addons/Pagle/data/Catalogue.lua (ns.catalogue, DATA-R76), for make-test-log_spec.lua's
-- --catalogue runs, so the test logs don't move with the generated data. Elwynn Forest (12) and Westfall (40) are
-- charted; Duskwood (10) has no catch data. Their catches hold every kind a test log must leave out: a Legend
-- (19803), Noise (6358), a gated Species (13759, only at night) and a container (6351), beside ordinary Species,
-- junk and trophies. Item 999001 is in no catalogue: Uncharted.

local ns = select(2, ...)

-- The builders both fixture catalogues share, from this file's own folder.
local build = dofile(debug.getinfo(1, "S").source:match("^@(.-)[^/\\]*$") .. "catalogue_builders.lua")
local night, item, area = build.night, build.item, build.area

ns.catalogue = {
	fingerprint = "0123456789abcdef",
	items = {
		[6291] = item("fish", { species = 6291, typicalLength = 300 }),
		[6299] = item("fish", { species = 6299, typicalLength = 250 }),
		[6303] = item("fish", { species = 6303, typicalLength = 350 }),
		[13759] = item("fish", { species = 13759, typicalLength = 400 }),
		[19803] = item("fish", { species = 19803, legend = true }),
		[6358] = item("other", { noise = true }),
		[13901] = item("trophy", { family = 1, weight = 19 }),
		[13902] = item("trophy", { family = 1, weight = 25 }),
		[6309] = item("junk", {}),
		[6351] = item("container", {}),
	},
	areas = {
		[10] = area(0, { hasData = false, catches = { { itemID = 6303, confirmed = false } } }),
		[12] = area(0, {
			skillBase = 25,
			catches = {
				{ itemID = 6303, confirmed = false },
				{ itemID = 6358, confirmed = false },
				{ itemID = 13759, confirmed = false, window = "night", gate = night, gateConfirmed = false },
				{ itemID = 13901, confirmed = false },
			},
		}),
		[87] = area(12, { catches = { { itemID = 6291, confirmed = false }, { itemID = 6309, confirmed = false } } }),
		[40] = area(0, {
			skillBase = 55,
			catches = {
				{ itemID = 6303, confirmed = false },
				{ itemID = 6299, confirmed = false },
				{ itemID = 6351, confirmed = false },
				{ itemID = 13902, confirmed = false },
				{ itemID = 19803, confirmed = false },
			},
		}),
	},
	aliases = {},
	pools = {},
	windows = { night = { spec = night, confirmed = false } },
	events = {},
	fishingSpells = {},
	auras = {},
}
