-- The Curio crate's draw (SHOP-R50–R54) as pure logic: ns.CrateCandidates, ns.CrateDraw, ns.CrateOdds and
-- ns.CratePityLeft over the pool, its weights and its pity.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

local ADA = "Player-4618-0A1B2C3D"
local FOIL, STORM, SHAGREEN = "core.toaststyle.foil", "core.toaststyle.storm", "core.binding.shagreenbone"
local ARCANE = "core.toaststyle.arcane"

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
		"is Prize Foil (crate only), Storm Front, Shagreen and Bone and Arcane Sigil, in that frozen order, at tier 4, pity 8"
			.. " (SHOP-R50–R53, Tunables)",
		function()
			assert.are.same({ FOIL, STORM, SHAGREEN, ARCANE }, ids(ns.CRATE_POOL))
			assert.is_true(ns.CRATE_POOL[1].crateOnly)
			assert.are.same({ crateOnly = 1, other = 2 }, ns.CRATE_WEIGHTS)
			assert.are.equal(8, ns.CRATE_PITY)
			assert.are.equal(3000, ns.TIER_PRICES[ns.CRATE_TIER])
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
	-- The good LOG-R66's hash picks over the weights 1 / 2 / 2 / 2: Foil below 1/7, Storm below 3/7, Shagreen below
	-- 5/7, Arcane above.
	local function expected(u)
		if u < 1 / 7 then
			return FOIL
		elseif u < 3 / 7 then
			return STORM
		elseif u < 5 / 7 then
			return SHAGREEN
		end
		return ARCANE
	end

	it(
		"gives the first candidate whose running share of the weights is above the entry ID's hash (SHOP-R51)",
		function()
			assert.are.equal(1729001476, ns.SizeHash(crateID(0))) -- u 0.402565
			assert.are.same({ STORM, false }, { ns.CrateDraw(crateID(0), {}, 0, 1791731700) })
			assert.are.same({ FOIL, true }, { ns.CrateDraw(crateID(1), {}, 0, 1791731700) }) -- u 0.035683
			assert.are.same({ ARCANE, false }, { ns.CrateDraw(crateID(6), {}, 0, 1791731700) }) -- u 0.795256
			local seen = {}
			for t = 0, 200 do
				local given = ns.CrateDraw(crateID(t), {}, 0, 1791731700)
				assert.are.equal(expected(ns.SizeHash(crateID(t)) / 2 ^ 32), given, t)
				seen[given] = true
			end
			assert.are.same({ [FOIL] = true, [STORM] = true, [SHAGREEN] = true, [ARCANE] = true }, seen)
		end
	)

	it("gives the same good for the same entry and owned set, every time (SHOP-R51, ADR 0004)", function()
		for t = 0, 40 do
			local first = ns.CrateDraw(crateID(t), { [FOIL] = true }, 2, 1791731700)
			assert.are.equal(first, ns.CrateDraw(crateID(t), { [FOIL] = true }, 2, 1791731700))
		end
	end)

	it("never gives a good already owned, so no crate is wasted, and nothing once all four are (SHOP-R50)", function()
		for t = 0, 200 do
			local given = ns.CrateDraw(crateID(t), { [STORM] = true }, 0, 1791731700)
			assert.are_not.equal(STORM, given)
			local last = ns.CrateDraw(crateID(t), { [STORM] = true, [FOIL] = true, [ARCANE] = true }, 0, 1791731700)
			assert.are.equal(SHAGREEN, last)
		end
		local all = { [STORM] = true, [FOIL] = true, [SHAGREEN] = true, [ARCANE] = true }
		assert.is_nil(ns.CrateDraw(crateID(0), all, 0, 1791731700))
	end)

	it("can give a pool good no slot has registered yet: it reads the log alone (SHOP-R50)", function()
		-- Shagreen and Bone, though its slot registers it now; the draw knows nothing of the registry.
		local owned = { [STORM] = true, [FOIL] = true, [ARCANE] = true }
		assert.are.equal(SHAGREEN, (ns.CrateDraw(crateID(6), owned, 0, 1791731700)))
	end)

	it("weighs a crate-only good 1 and any other 2: about 14%, 29%, 29% and 29% over many crates (SHOP-R51)", function()
		local counts, n = { [FOIL] = 0, [STORM] = 0, [SHAGREEN] = 0, [ARCANE] = 0 }, 30000
		for t = 1, n do
			local given = ns.CrateDraw(crateID(t), {}, 0, 1791731700)
			counts[given] = counts[given] + 1
		end
		assert(math.abs(counts[FOIL] / n - 1 / 7) < 0.015, "Foil " .. counts[FOIL] / n)
		assert(math.abs(counts[STORM] / n - 2 / 7) < 0.015, "Storm " .. counts[STORM] / n)
		assert(math.abs(counts[SHAGREEN] / n - 2 / 7) < 0.015, "Shagreen " .. counts[SHAGREEN] / n)
		assert(math.abs(counts[ARCANE] / n - 2 / 7) < 0.015, "Arcane " .. counts[ARCANE] / n)
	end)

	it("gives the crate-only good to the crate after 7 in a row without one, while it is unowned (SHOP-R52)", function()
		local owned = { [STORM] = true }
		for t = 0, 200 do
			assert.are.equal(FOIL, (ns.CrateDraw(crateID(t), owned, 7, 1791731700)))
		end
		assert.are.same({ { id = FOIL, crateOnly = true, weight = 1 } }, ns.CrateCandidates({}, 7, 1791731700))
		assert.are.same({ FOIL, STORM, SHAGREEN, ARCANE }, ids(ns.CrateCandidates({}, 6, 1791731700)))
		assert.are.same({ STORM, SHAGREEN, ARCANE }, ids(ns.CrateCandidates({ [FOIL] = true }, 9, 1791731700)))
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
	-- The chances as ids, owned flags and chances rounded to 4 places.
	local function rounded(list)
		local out = {}
		for i, row in ipairs(list) do
			out[i] = { id = row.id, owned = row.owned, chance = math.floor(row.chance * 10000 + 0.5) / 10000 }
		end
		return out
	end

	it("gives each pool good its chance of coming next, 0 for one owned (SHOP-R54)", function()
		assert.are.same({
			{ id = FOIL, owned = false, chance = 0.1429 },
			{ id = STORM, owned = false, chance = 0.2857 },
			{ id = SHAGREEN, owned = false, chance = 0.2857 },
			{ id = ARCANE, owned = false, chance = 0.2857 },
		}, rounded(ns.CrateOdds({}, 0, 1791731700)))
		assert.are.same({
			{ id = FOIL, owned = true, chance = 0 },
			{ id = STORM, owned = false, chance = 0.3333 },
			{ id = SHAGREEN, owned = false, chance = 0.3333 },
			{ id = ARCANE, owned = false, chance = 0.3333 },
		}, rounded(ns.CrateOdds({ [FOIL] = true }, 0, 1791731700)))
		assert.are.same({
			{ id = FOIL, owned = false, chance = 1 },
			{ id = STORM, owned = false, chance = 0 },
			{ id = SHAGREEN, owned = false, chance = 0 },
			{ id = ARCANE, owned = false, chance = 0 },
		}, rounded(ns.CrateOdds({}, 7, 1791731700)))
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
