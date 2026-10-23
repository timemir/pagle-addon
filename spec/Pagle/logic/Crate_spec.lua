-- The Curio crate's draw (SHOP-R50–R54) as pure logic: ns.CrateCandidates, ns.CrateDraw, ns.CrateOdds and
-- ns.CratePityLeft over the pool, its weights and its pity.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

local ADA = "Player-4618-0A1B2C3D"
local FOIL, STORM, SHAGREEN = "core.toaststyle.foil", "core.toaststyle.storm", "core.binding.shagreenbone"

-- Ada's crate entry ID at server time 1791731700 + `t` (LOG-R13).
local function crateID(t)
	return ("%s-%d-0"):format(ADA, 1791731700 + t)
end

-- The pool as the list of IDs.
local function ids(list)
	local all = {}
	for i, item in ipairs(list) do
		all[i] = item.id
	end
	return all
end

describe("The Curio crate's pool", function()
	it(
		"is Prize Foil (crate only), Storm Front and Shagreen and Bone, in that frozen order, at tier 4, pity 8"
			.. " (SHOP-R50–R53, Tunables)",
		function()
			assert.are.same({ FOIL, STORM, SHAGREEN }, ids(ns.CRATE_POOL))
			assert.is_true(ns.CRATE_POOL[1].crateOnly)
			assert.are.same({ crateOnly = 1, other = 2 }, ns.CRATE_WEIGHTS)
			assert.are.equal(8, ns.CRATE_PITY)
			assert.are.equal(2000, ns.TIER_PRICES[ns.CRATE_TIER])
			assert.are.equal("core.crate", ns.CRATE_ID)
			local crateOnly = 0
			for _, good in ipairs(ns.CRATE_POOL) do
				crateOnly = crateOnly + (good.crateOnly and 1 or 0)
			end
			assert(crateOnly <= 2, "at most two goods are ever crate only (SHOP-R53)")
		end
	)
end)

describe("ns.CrateDraw", function()
	it(
		"gives the first candidate whose running share of the weights is above the entry ID's hash (SHOP-R51)",
		function()
			-- LOG-R66's hash over 2^32, then the weights 1 / 2 / 2: Foil below 0.2, Storm below 0.6, Shagreen above.
			assert.are.equal(1729001476, ns.SizeHash(crateID(0))) -- u 0.402565
			assert.are.same({ STORM, false }, { ns.CrateDraw(crateID(0), {}, 0, 1791731700) })
			assert.are.same({ FOIL, true }, { ns.CrateDraw(crateID(1), {}, 0, 1791731700) }) -- u 0.035683
			assert.are.same({ SHAGREEN, false }, { ns.CrateDraw(crateID(6), {}, 0, 1791731700) }) -- u 0.795256
		end
	)

	it("gives the same good for the same entry and owned set, every time (SHOP-R51, ADR 0004)", function()
		for t = 0, 40 do
			local first = ns.CrateDraw(crateID(t), { [FOIL] = true }, 2, 1791731700)
			assert.are.equal(first, ns.CrateDraw(crateID(t), { [FOIL] = true }, 2, 1791731700))
		end
	end)

	it("never gives a good already owned, so no crate is wasted, and nothing once all three are (SHOP-R50)", function()
		for t = 0, 200 do
			local given = ns.CrateDraw(crateID(t), { [STORM] = true }, 0, 1791731700)
			assert.are_not.equal(STORM, given)
			assert.are.equal(SHAGREEN, ns.CrateDraw(crateID(t), { [STORM] = true, [FOIL] = true }, 0, 1791731700))
		end
		assert.is_nil(ns.CrateDraw(crateID(0), { [STORM] = true, [FOIL] = true, [SHAGREEN] = true }, 0, 1791731700))
	end)

	it("can give a pool good no slot has registered yet: it reads the log alone (SHOP-R50)", function()
		-- Shagreen and Bone, though its slot registers it now; the draw knows nothing of the registry.
		assert.are.equal(SHAGREEN, (ns.CrateDraw(crateID(6), {}, 0, 1791731700)))
	end)

	it("weighs a crate-only good 1 and any other 2: about 20%, 40% and 40% over many crates (SHOP-R51)", function()
		local counts, n = { [FOIL] = 0, [STORM] = 0, [SHAGREEN] = 0 }, 30000
		for t = 1, n do
			local given = ns.CrateDraw(crateID(t), {}, 0, 1791731700)
			counts[given] = counts[given] + 1
		end
		assert(math.abs(counts[FOIL] / n - 0.2) < 0.015, "Foil " .. counts[FOIL] / n)
		assert(math.abs(counts[STORM] / n - 0.4) < 0.015, "Storm " .. counts[STORM] / n)
		assert(math.abs(counts[SHAGREEN] / n - 0.4) < 0.015, "Shagreen " .. counts[SHAGREEN] / n)
	end)

	it("gives the crate-only good to the crate after 7 in a row without one, while it is unowned (SHOP-R52)", function()
		local owned = { [STORM] = true }
		for t = 0, 200 do
			assert.are.equal(FOIL, (ns.CrateDraw(crateID(t), owned, 7, 1791731700)))
		end
		assert.are.same({ { id = FOIL, crateOnly = true, weight = 1 } }, ns.CrateCandidates({}, 7, 1791731700))
		assert.are.same({ FOIL, STORM, SHAGREEN }, ids(ns.CrateCandidates({}, 6, 1791731700)))
		assert.are.same({ STORM, SHAGREEN }, ids(ns.CrateCandidates({ [FOIL] = true }, 9, 1791731700)))
	end)
end)

describe("A good joining the pool later", function()
	it("is a candidate only for crates bought from its release on (SHOP-R53)", function()
		local pool = ns.CRATE_POOL
		ns.CRATE_POOL = { pool[1], pool[2], pool[3], { id = "core.toaststyle.late", since = 1800000000 } }
		local before = ids(ns.CrateCandidates({}, 0, 1799999999))
		local after = ids(ns.CrateCandidates({}, 0, 1800000000))
		ns.CRATE_POOL = pool

		assert.are.same({ FOIL, STORM, SHAGREEN }, before)
		assert.are.same({ FOIL, STORM, SHAGREEN, "core.toaststyle.late" }, after)
	end)
end)

describe("The crate's odds and pity on the stage", function()
	it("gives each pool good its chance of coming next, 0 for one owned (SHOP-R54)", function()
		assert.are.same({
			{ id = FOIL, owned = false, chance = 0.2 },
			{ id = STORM, owned = false, chance = 0.4 },
			{ id = SHAGREEN, owned = false, chance = 0.4 },
		}, ns.CrateOdds({}, 0, 1791731700))
		assert.are.same({
			{ id = FOIL, owned = true, chance = 0 },
			{ id = STORM, owned = false, chance = 0.5 },
			{ id = SHAGREEN, owned = false, chance = 0.5 },
		}, ns.CrateOdds({ [FOIL] = true }, 0, 1791731700))
		assert.are.same({
			{ id = FOIL, owned = false, chance = 1 },
			{ id = STORM, owned = false, chance = 0 },
			{ id = SHAGREEN, owned = false, chance = 0 },
		}, ns.CrateOdds({}, 7, 1791731700))
	end)

	it(
		"counts the crates left until a crate-only good at most, none once each is owned (SHOP-R52, SHOP-R54)",
		function()
			assert.are.equal(8, ns.CratePityLeft({}, 0, 1791731700))
			assert.are.equal(6, ns.CratePityLeft({ [STORM] = true }, 2, 1791731700))
			assert.are.equal(1, ns.CratePityLeft({}, 7, 1791731700))
			assert.is_nil(ns.CratePityLeft({ [FOIL] = true }, 3, 1791731700))
		end
	)
end)
