-- An event pool in the shape of addons/Pagle_Hunts/data/EventList.lua (ns.eventList, DATA-R98), for read-wtf_spec.lua's
-- --eventlist runs, so the Hunts fingerprint line doesn't move with the generated pool (HNT-R136). One event, in
-- Darkshore.

if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

local ns = select(2, ...)

ns.eventList = {
	fingerprint = "e7e7e7e7e7e7e7e7",
	events = {
		{
			id = "darkshore_moonlight",
			zones = { 148 },
			tags = { "night", "coast", "low" },
			skill = { 75, 150 },
			band = "low",
			rotation = true,
			hunts = {
				{ id = "darkshore_moonlight_haul", class = "species.any", tiers = { 20, 50, 100 } },
				{ id = "darkshore_moonlight_grouper", species = 12238, tiers = { 3, 8 } },
				{
					id = "darkshore_moonlight_timed",
					species = 12238,
					conditions = { time = { { 1320, 240 } } },
					tiers = { 1 },
				},
			},
		},
	},
}
