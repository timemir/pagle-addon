-- Which Catches qualify for a Hunt (HNT-R4, HNT-R5, HNT-R10–R14, HNT-R196), and what they do to its count, tiers and
-- completion (HNT-R15–R17), with the tier trims (HNT-R18). The fixture Hunt list over FakePagle's catalogue and its
-- Core MatchesConditions (LOG-R48, LOG-R49); hand-made Cast records (LOG-R42) with their conditions and sizes.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local C = hunts.catalogue

-- Server times (DATA-R87): 00:00 UTC on 2026-01-01 and 2026-06-01, the fixture's since and retired dates.
local JAN_1, JUN_1 = hunts.JAN_1, hunts.JUN_1
-- 2026-03-10 00:00 UTC, a day both the fixture's Hunts that exist then and the retired one share.
local MAR_10 = 1773100800

-- Catalogue items (FakePagle's generated catalogue, LOG-R55): the fixture's Species and class members, and others.
local NIGHTFIN, BLACKMOUTH = C.NIGHTFIN, C.BLACKMOUTH -- Raw Nightfin Snapper and Oily Blackmouth, Species
local YELLOWTAIL, YELLOWTAIL_FOLDED = 4603, 6887 -- Raw Spotted Yellowtail, and an item folded into its Species (DATA-R19)
local DEVIATE, WHIMSYFIN = C.DEVIATE, C.ODDITY_2 -- the fixed.oddity members
local SHINY = C.UNCOMMON -- a container of quality 2, in the fixture's quality.uncommon
local LEGEND_RACER = C.UNCOMMON_2 -- a Legend of quality 2, in the fixture's quality.uncommon
local MALACHITE = 774 -- Noise of quality 2: in no generated class (DATA-R91)
local UNCHARTED = 999999 -- no catalogue record: Uncharted (LOG-R55)

local DARKSHORE = C.DARKSHORE

describe("Which Catches qualify, and a Hunt's count and tiers", function()
	local loaded = hunts.load()
	local ns = loaded.ns
	local Pagle = loaded.env.Pagle
	-- The lookups Hunts built at OnInitialize (ns.NewLookups): Core's GetItem and MatchesConditions, the list's classes.
	local lookups = ns.lookups
	local function hunt(id)
		return assert(ns.hunts:Hunt(id))
	end
	-- fixture_snapper (natural, Raw Nightfin Snapper) with other tiers.
	local function snapperWith(tiers)
		local copy = {}
		for key, value in pairs(hunt("fixture_snapper")) do
			copy[key] = value
		end
		copy.tiers = tiers
		return copy
	end

	-- A Cast record (LOG-R42) at server time `time` (MAR_10 + 1 hour by default), caught, in Darkshore, on a UTC realm
	-- (its realm minute is the time's UTC minute unless given), with one Catch per entry of `catches`: an item ID, or
	-- `{ itemID, band }` for a Catch with a Simulated Size of that band (LOG-R65). The first Catch is a stack of 3.
	-- `options` sets `outcome`, `minute`, `date` ({ year, month, day }, 2026-03-10 by default), `zone`, `auras`,
	-- `skillRank` and `skillMod`.
	local seq = 0
	local function cast(time, catches, options)
		options = options or {}
		seq = seq + 1
		time = time or MAR_10 + 3600
		local id = ("Player-4618-0A1B2C3D-%d-%d"):format(time, seq)
		local items = {}
		for n, catch in ipairs(catches) do
			local itemID, band = catch, nil
			if type(catch) == "table" then
				itemID, band = catch[1], catch[2]
			end
			items[n] = {
				n = n,
				itemID = itemID,
				quantity = n == 1 and 3 or 1,
				catchId = id .. ":" .. n,
				size = band and { length = 400, band = band } or nil,
			}
		end
		local date = options.date or { 2026, 3, 10 }
		return {
			seq = seq,
			id = id,
			kind = "cast",
			char = 1,
			time = time,
			outcome = options.outcome or "caught",
			session = "s",
			conditions = {
				time = time,
				minute = options.minute or math.floor(time / 60) % 1440,
				date = { year = date[1], month = date[2], day = date[3], weekday = 3 },
				zone = options.zone or DARKSHORE,
				subzone = 0,
				skillRank = options.skillRank or 150,
				skillMod = options.skillMod or 0,
				events = {},
				auras = options.auras or {},
			},
			items = items,
		}
	end

	-- The item IDs of the Catches of `record` that qualify for `huntDef`, in loot-slot order.
	local function qualifying(huntDef, record)
		local out = {}
		for i, catch in ipairs(ns.QualifyingCatches(huntDef, record, lookups)) do
			out[i] = catch.itemID
		end
		return out
	end

	describe("targets (HNT-R10, HNT-R12)", function()
		it("counts every item of a Species Hunt's Species, folded items too (DATA-R19)", function()
			local yellowtail = {
				id = "spec_yellowtail",
				set = "fixture_dusk",
				kind = "natural",
				since = JAN_1,
				species = YELLOWTAIL,
				window = "day",
				tiers = { 1 },
			}

			assert.are.same(
				{ YELLOWTAIL, YELLOWTAIL_FOLDED },
				qualifying(yellowtail, cast(nil, { YELLOWTAIL, YELLOWTAIL_FOLDED, BLACKMOUTH, NIGHTFIN }))
			)
			assert.are.same({ NIGHTFIN }, qualifying(hunt("fixture_snapper"), cast(nil, { BLACKMOUTH, NIGHTFIN })))
		end)

		it("counts only a class Hunt's members, from the Hunt list's classes", function()
			-- fixture_oddity: fixed.oddity at 18:00–21:00 realm time.
			local dusk = MAR_10 + 19 * 3600

			assert.are.same(
				{ DEVIATE, WHIMSYFIN },
				qualifying(hunt("fixture_oddity"), cast(dusk, { NIGHTFIN, DEVIATE, BLACKMOUTH, WHIMSYFIN }))
			)
		end)

		it("never counts a Noise item for quality.uncommon, whatever its quality in the catalogue", function()
			-- fixture_rack: quality.uncommon under aura 1280341. Malachite is quality 2 in GetItem, but Noise.
			assert.are.equal(2, Pagle.GetItem(MALACHITE).quality)
			local rack = { auras = { 1280341 } }

			assert.are.same(
				{ SHINY, LEGEND_RACER },
				qualifying(hunt("fixture_rack"), cast(nil, { MALACHITE, SHINY, BLACKMOUTH, LEGEND_RACER }, rack))
			)
		end)

		it("never counts an Uncharted Catch or item 0, for a Species or a class Hunt (HNT-R196)", function()
			local rack = { auras = { 1280341 } }

			assert.are.same({}, qualifying(hunt("fixture_snapper"), cast(nil, { 0, UNCHARTED })))
			assert.are.same({}, qualifying(hunt("fixture_rack"), cast(nil, { 0, UNCHARTED }, rack)))
		end)
	end)

	describe("when the Cast counts (HNT-R10 step 1, HNT-R13)", function()
		it("counts nothing from a Cast that got away", function()
			assert.are.same({}, qualifying(hunt("fixture_snapper"), cast(nil, { NIGHTFIN }, { outcome = "gotAway" })))
		end)

		it("counts from since on, Casts at since included, and nothing before", function()
			local snapper = hunt("fixture_snapper")

			assert.are.same({}, qualifying(snapper, cast(JAN_1 - 1, { NIGHTFIN })))
			assert.are.same({ NIGHTFIN }, qualifying(snapper, cast(JAN_1, { NIGHTFIN })))
		end)

		it("counts nothing at or after retired, and up to it before", function()
			-- fixture_sunscale: natural, species 13760, retired 2026-06-01.
			local sunscale = hunt("fixture_sunscale")
			local SUNSCALE = 13760

			assert.are.same({ SUNSCALE }, qualifying(sunscale, cast(JUN_1 - 1, { SUNSCALE })))
			assert.are.same({}, qualifying(sunscale, cast(JUN_1, { SUNSCALE })))
			assert.are.same({}, qualifying(sunscale, cast(JUN_1 + 86400, { SUNSCALE })))
		end)
	end)

	describe("natural and imposed Hunts (HNT-R4, HNT-R5, HNT-R10 step 4)", function()
		it("counts a natural Hunt's Species outside its window: the window is never consulted (HNT-R196)", function()
			-- fixture_snapper's window is night (18:00–12:00 in FakePagle's catalogue); 15:00 is outside it.
			local afternoon = MAR_10 + 15 * 3600
			assert.is_false(Pagle.MatchesConditions(Pagle.GetWindowSpec("night"), cast(afternoon, {}).conditions))

			assert.are.same({ NIGHTFIN }, qualifying(hunt("fixture_snapper"), cast(afternoon, { NIGHTFIN })))
		end)

		it("counts a natural Hunt's Species whose window has no spec at all (HNT-R7)", function()
			local snapper = hunt("fixture_snapper")
			local unwindowed = {}
			for key, value in pairs(snapper) do
				unwindowed[key] = value
			end
			unwindowed.window = "event.no_such_event"

			assert.are.same({ NIGHTFIN }, qualifying(unwindowed, cast(nil, { NIGHTFIN })))
		end)

		it("counts an imposed Hunt's Catch only when the Cast matched its own conditions", function()
			-- fixture_oddity: 18:00–21:00 realm time. fixture_rack: aura 1280341.
			local oddity, rack = hunt("fixture_oddity"), hunt("fixture_rack")

			assert.are.same({ DEVIATE }, qualifying(oddity, cast(MAR_10 + 18 * 3600, { DEVIATE })))
			assert.are.same({}, qualifying(oddity, cast(MAR_10 + 21 * 3600, { DEVIATE })))
			-- The realm minute is the Cast's own, not the server time's UTC minute (LOG-R49).
			assert.are.same({}, qualifying(oddity, cast(MAR_10 + 19 * 3600, { DEVIATE }, { minute = 600 })))
			assert.are.same({ SHINY }, qualifying(rack, cast(nil, { SHINY }, { auras = { 1280341 } })))
			assert.are.same({}, qualifying(rack, cast(nil, { SHINY }, { auras = { 1280342 } })))
			assert.are.same({}, qualifying(rack, cast(nil, { SHINY })))
		end)

		it("judges skill in an imposed Hunt's conditions as rank + modifier at the Cast (LOG-R48)", function()
			local skilled = {
				id = "spec_skilled",
				set = "fixture_wagers",
				kind = "imposed",
				since = JAN_1,
				species = BLACKMOUTH,
				conditions = { skill = { min = 200 } },
				tiers = { 1 },
			}

			assert.are.same(
				{ BLACKMOUTH },
				qualifying(skilled, cast(nil, { BLACKMOUTH }, { skillRank = 175, skillMod = 25 }))
			)
			assert.are.same({}, qualifying(skilled, cast(nil, { BLACKMOUTH }, { skillRank = 175, skillMod = 24 })))
			assert.are.same({}, qualifying(skilled, cast(nil, { BLACKMOUTH }, { skillRank = 199, skillMod = 0 })))
		end)
	end)

	describe("minBand (HNT-R10 step 3, HNT-R14)", function()
		-- fixture_hefty_blackmouth: Oily Blackmouth, minBand 3, 22:00–04:00 realm time.
		local NIGHT = MAR_10 + 3600

		it("counts a Hefty and a Monster Catch, and not a Decent one or one without a size", function()
			local hefty = hunt("fixture_hefty_blackmouth")
			local TYPICAL, HEFTY, MONSTER = 2, 3, 5

			assert.are.same(
				{ BLACKMOUTH, BLACKMOUTH },
				qualifying(
					hefty,
					cast(NIGHT, { { BLACKMOUTH, HEFTY }, { BLACKMOUTH, TYPICAL }, { BLACKMOUTH, MONSTER } })
				)
			)
			assert.are.same({}, qualifying(hefty, cast(NIGHT, { BLACKMOUTH, { BLACKMOUTH, TYPICAL } })))
		end)

		it("lets a Monster Catch count for any minBand from 2 to 4", function()
			for minBand = 2, 4 do
				local banded = {
					id = "spec_band",
					set = "fixture_dusk",
					kind = "natural",
					since = JAN_1,
					species = BLACKMOUTH,
					window = "day",
					minBand = minBand,
					tiers = { 1 },
				}

				assert.are.same({ BLACKMOUTH }, qualifying(banded, cast(nil, { { BLACKMOUTH, 5 } })), minBand)
				assert.are.same({}, qualifying(banded, cast(nil, { { BLACKMOUTH, minBand - 1 } })), minBand)
			end
		end)
	end)

	describe("count and tiers (HNT-R11, HNT-R15–R17)", function()
		it("starts a Hunt's progress with nothing counted or reached (hunts.md › Projection state)", function()
			assert.are.same(
				{ count = 0, effort = 0, sinceLast = 0, caught = false, reached = {} },
				ns.NewHuntProgress()
			)
		end)

		it("adds 1 per qualifying Catch, whatever its quantity, and reaches nothing short of a tier", function()
			local progress = ns.NewHuntProgress()
			-- Slot 1 is a stack of 3 Raw Nightfin Snapper; slot 2 doesn't qualify.
			local newly =
				ns.CountCatches(progress, snapperWith({ 2, 10 }), cast(nil, { NIGHTFIN, BLACKMOUTH }), lookups)

			assert.are.same({}, newly)
			assert.are.same({ count = 1, effort = 0, sinceLast = 0, caught = true, reached = {} }, progress)
		end)

		it("leaves the progress alone for a Cast with no qualifying Catch", function()
			local progress = ns.NewHuntProgress()

			assert.are.same({}, ns.CountCatches(progress, snapperWith({ 1 }), cast(nil, { BLACKMOUTH }), lookups))
			assert.are.same(ns.NewHuntProgress(), progress)
		end)

		it(
			"crosses tiers 1 and 2 in one Cast: adds 2, stores each tier from its slot's Catch and returns both",
			function()
				local progress = ns.NewHuntProgress()
				local record = cast(
					MAR_10 + 7200,
					{ BLACKMOUTH, NIGHTFIN, DEVIATE, NIGHTFIN },
					{ zone = 331, date = { 2026, 3, 9 } }
				)

				local newly = ns.CountCatches(progress, snapperWith({ 1, 2, 4 }), record, lookups)

				assert.are.same({ 1, 2 }, newly)
				assert.are.equal(2, progress.count)
				assert.is_true(progress.caught)
				local date = { year = 2026, month = 3, day = 9 }
				assert.are.same({
					{ time = MAR_10 + 7200, catchId = record.id .. ":2", itemID = NIGHTFIN, zone = 331, date = date },
					{ time = MAR_10 + 7200, catchId = record.id .. ":4", itemID = NIGHTFIN, zone = 331, date = date },
				}, progress.reached)
				-- The tier's date is the progress's own: a later change to the record's date doesn't reach it.
				record.conditions.date.day = 1
				assert.are.equal(9, progress.reached[1].date.day)
			end
		)

		it("stores zone 0 for a Cast whose zone was unresolved", function()
			local progress = ns.NewHuntProgress()

			ns.CountCatches(progress, snapperWith({ 1 }), cast(nil, { NIGHTFIN }, { zone = 0 }), lookups)

			assert.are.equal(0, progress.reached[1].zone)
		end)

		it("reaches a tier from the Catch that first brings the count to it, across Casts", function()
			local progress = ns.NewHuntProgress()
			local hunt3 = snapperWith({ 1, 3 })
			local first, second = cast(MAR_10 + 60, { NIGHTFIN }), cast(MAR_10 + 120, { NIGHTFIN, NIGHTFIN, NIGHTFIN })

			assert.are.same({ 1 }, ns.CountCatches(progress, hunt3, first, lookups))
			assert.are.same({ 2 }, ns.CountCatches(progress, hunt3, second, lookups))

			assert.are.equal(4, progress.count)
			assert.are.same({ first.id .. ":1", second.id .. ":2" }, {
				progress.reached[1].catchId,
				progress.reached[2].catchId,
			})
			assert.are.equal(MAR_10 + 120, progress.reached[2].time)
		end)

		it("keeps the count rising after the last tier, and reaches nothing more (HNT-R16)", function()
			local progress = ns.NewHuntProgress()
			local hunt2 = snapperWith({ 1, 2 })
			ns.CountCatches(progress, hunt2, cast(MAR_10 + 60, { NIGHTFIN, NIGHTFIN }), lookups)
			local reached = progress.reached

			assert.are.same({}, ns.CountCatches(progress, hunt2, cast(MAR_10 + 120, { NIGHTFIN, NIGHTFIN }), lookups))
			assert.are.equal(4, progress.count)
			assert.are.equal(2, #reached)
		end)

		it("counts one Catch for every Hunt it qualifies for (HNT-R11)", function()
			local anySpecies = {
				id = "spec_any",
				set = "fixture_dusk",
				kind = "natural",
				since = JAN_1,
				class = "species.any",
				window = "day",
				tiers = { 1 },
			}
			local record = cast(nil, { NIGHTFIN })
			local snapperProgress, anyProgress = ns.NewHuntProgress(), ns.NewHuntProgress()

			assert.are.same({ 1 }, ns.CountCatches(snapperProgress, snapperWith({ 1 }), record, lookups))
			assert.are.same({ 1 }, ns.CountCatches(anyProgress, anySpecies, record, lookups))
		end)

		it("is done at tier 1 and finished when every tier is reached (HNT-R17)", function()
			local progress = ns.NewHuntProgress()
			local hunt2 = snapperWith({ 1, 2 })

			assert.is_false(ns.HuntDone(progress))
			assert.is_false(ns.HuntFinished(progress, hunt2))
			ns.CountCatches(progress, hunt2, cast(nil, { NIGHTFIN }), lookups)
			assert.is_true(ns.HuntDone(progress))
			assert.is_false(ns.HuntFinished(progress, hunt2))
			ns.CountCatches(progress, hunt2, cast(nil, { NIGHTFIN }), lookups)
			assert.is_true(ns.HuntFinished(progress, hunt2))
			-- A Hunt nothing has touched yet has no progress at all (hunts.md › Projection state).
			assert.is_false(ns.HuntDone(nil))
			assert.is_false(ns.HuntFinished(nil, hunt2))
		end)
	end)

	describe("trim (HNT-R18)", function()
		it("is bronze for tier 1, silver for tier 2, and gold for tier 3 and any later tier", function()
			assert.are.same(
				{ "bronze", "silver", "gold", "gold", "gold" },
				{ ns.Trim(1), ns.Trim(2), ns.Trim(3), ns.Trim(4), ns.Trim(10) }
			)
		end)

		it("dresses a Hunt's icon in the trim of its highest reached tier, and none before tier 1", function()
			local progress = ns.NewHuntProgress()
			local hunt3 = snapperWith({ 1, 2, 3 })

			assert.is_nil(ns.HuntTrim(nil))
			assert.is_nil(ns.HuntTrim(progress))
			local trims = {}
			for i = 1, 3 do
				ns.CountCatches(progress, hunt3, cast(nil, { NIGHTFIN }), lookups)
				trims[i] = ns.HuntTrim(progress)
			end
			assert.are.same({ "bronze", "silver", "gold" }, trims)
		end)
	end)
end)
