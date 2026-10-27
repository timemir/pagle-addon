-- The Curio crate's draw (SHOP-R50–R54) as pure logic: ns.CrateRoll, ns.CrateCandidates, ns.CratePayback, ns.CrateOdds,
-- ns.CratePityLeft and ns.CrateHasCandidates over the pool, its fixed odds, its payback and its Curio pity. The draw's
-- edges run on a fixture pool and a stubbed hash, so every threshold is hit exactly; the real hash and the real pool
-- run in the last blocks.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

local ADA = "Player-4618-0A1B2C3D"
local PRICE = 1500

-- Ada's crate entry ID at server time 1791731700 + `t` (LOG-R13).
local function crateID(t)
	return ("%s-%d-0"):format(ADA, 1791731700 + t)
end

local realHash, realPool, realTierPrices = ns.SizeHash, ns.CRATE_POOL, { unpack(ns.TIER_PRICES) }

-- The hash of the entry ID "e" is `tierHash`, of "e/good" `goodHash`: LOG-R66's frozen hash over 2^32, stubbed.
local function hashes(tierHash, goodHash)
	ns.SizeHash = function(id)
		if id == "e" then
			return tierHash
		end
		assert(id == "e/good", "unexpected hash input " .. id)
		return goodHash
	end
end

-- The running thresholds of the odds (400 / 660 / 820 / 920 / 970 / 995 / 1000 per mille): the last hash of each crate
-- tier, `running × 2^32 > h × 1000`, and the first of the next.
local EDGES = {
	{ tier = 1, last = 1717986918, nextTier = 2 },
	{ tier = 2, last = 2834678415, nextTier = 3 },
	{ tier = 3, last = 3521873182, nextTier = 4 },
	{ tier = 4, last = 3951369912, nextTier = 5 },
	{ tier = 5, last = 4166118277, nextTier = 6 },
	{ tier = 6, last = 4273492459, nextTier = "curio" },
	{ tier = "curio", last = 4294967295 },
}

-- A pool of three goods in tier 1, one in each of tiers 2 to 5, none in tier 6, and Prize Foil as the Curio tier's.
local function fixturePool()
	return {
		{ id = "t1.a", tier = 1, kind = "toaststyle" },
		{ id = "t1.b", tier = 1, kind = "soundset" },
		{ id = "t2.a", tier = 2, kind = "toaststyle" },
		{ id = "t1.c", tier = 1, kind = "binding" },
		{ id = "t3.a", tier = 3, kind = "trackerframe" },
		{ id = "t4.a", tier = 4, kind = "binding" },
		{ id = "t5.a", tier = 5, kind = "toaststyle" },
		{ id = "foil", tier = "curio", kind = "toaststyle" },
	}
end

after_each(function()
	ns.SizeHash, ns.CRATE_POOL = realHash, realPool
	for i, price in ipairs(realTierPrices) do
		ns.TIER_PRICES[i] = price
	end
end)

describe("The Curio crate's tunables", function()
	it(
		"are 1,500 Coins, fixed odds of 400 / 260 / 160 / 100 / 50 / 25 / 5 per mille and a pity of 100 (Tunables)",
		function()
			assert.are.equal("core.crate", ns.CRATE_ID)
			assert.are.equal(1500, ns.CRATE_PRICE)
			assert.are.same({ 1, 2, 3, 4, 5, 6, "curio" }, ns.CRATE_TIERS)
			assert.are.same({ 400, 260, 160, 100, 50, 25, 5 }, ns.CRATE_ODDS)
			assert.are.equal(
				1000,
				ns.CRATE_ODDS[1]
					+ ns.CRATE_ODDS[2]
					+ ns.CRATE_ODDS[3]
					+ ns.CRATE_ODDS[4]
					+ ns.CRATE_ODDS[5]
					+ ns.CRATE_ODDS[6]
					+ ns.CRATE_ODDS[7]
			)
			assert.are.equal(100, ns.CRATE_PITY)
			assert.is_nil(ns.CRATE_TIER)
			assert.is_nil(ns.CRATE_WEIGHTS)
		end
	)

	it(
		"pool the whole shop: 102 rows, 28 / 35 / 27 / 9 / 2 by price tier, none in tier 6, Prize Foil crate only (SHOP-R50)",
		function()
			local byTier, kinds = {}, {}
			for _, row in ipairs(realPool) do
				byTier[row.tier] = (byTier[row.tier] or 0) + 1
				kinds[row.kind] = (kinds[row.kind] or 0) + 1
				assert(row.since == nil, row.id .. " is one of the pool's first rows")
			end
			assert.are.equal(102, #realPool)
			assert.are.same(
				{ 28, 35, 27, 9, 2, nil, 1 },
				{ byTier[1], byTier[2], byTier[3], byTier[4], byTier[5], byTier[6], byTier.curio }
			)
			assert.are.same({ toaststyle = 24, soundset = 26, binding = 33, trackerframe = 19 }, kinds)
			local crateOnly = {}
			for _, row in ipairs(realPool) do
				if row.tier == "curio" then
					crateOnly[#crateOnly + 1] = row.id
				end
			end
			assert.are.same({ "core.toaststyle.foil" }, crateOnly)
		end
	)
end)

describe("ns.CrateRoll's crate tier", function()
	it("is the first of 1 to 6 and Curio whose running odds satisfy running × 2^32 > h × 1000 (SHOP-R51)", function()
		ns.CRATE_POOL = fixturePool()
		assert.are.equal(1717986918, math.ceil(400 * 2 ^ 32 / 1000) - 1)
		for _, edge in ipairs(EDGES) do
			hashes(edge.last, 0)
			assert.are.equal(edge.tier, ns.CrateRoll("e", {}, 0, 0, PRICE).tier, "at the last hash of " .. edge.tier)
			if edge.nextTier then
				hashes(edge.last + 1, 0)
				assert.are.equal(edge.nextTier, ns.CrateRoll("e", {}, 0, 0, PRICE).tier, "just above " .. edge.tier)
			end
		end
		hashes(0, 0)
		assert.are.equal(1, ns.CrateRoll("e", {}, 0, 0, PRICE).tier)
	end)

	it("keeps its odds, never rescaled, as tiers empty (SHOP-R51)", function()
		ns.CRATE_POOL = fixturePool()
		local owned = { ["t1.a"] = true, ["t1.b"] = true, ["t1.c"] = true, ["t2.a"] = true }
		for _, edge in ipairs(EDGES) do
			hashes(edge.last, 0)
			assert.are.equal(edge.tier, ns.CrateRoll("e", owned, 0, 0, PRICE).tier)
			if edge.nextTier then
				hashes(edge.last + 1, 0)
				assert.are.equal(edge.nextTier, ns.CrateRoll("e", owned, 0, 0, PRICE).tier)
			end
		end
		local odds = ns.CrateOdds(owned, 0)
		assert.are.same({ 400, 260, 160, 100, 50, 25, 5 }, {
			odds[1].permille,
			odds[2].permille,
			odds[3].permille,
			odds[4].permille,
			odds[5].permille,
			odds[6].permille,
			odds[7].permille,
		})
	end)
end)

describe("ns.CrateRoll's good", function()
	it(
		'is the candidate at ⌊h(entry ID .. "/good") × n / 2^32⌋ + 1 in pool order, at each edge (SHOP-R51)',
		function()
			ns.CRATE_POOL = fixturePool()
			-- Tier 1 has three candidates, in pool order t1.a, t1.b, t1.c: their edges are 2^32 / 3 and 2^32 × 2 / 3.
			local function good(goodHash, owned)
				hashes(0, goodHash)
				return ns.CrateRoll("e", owned or {}, 0, 0, PRICE).good
			end
			assert.are.equal("t1.a", good(0))
			assert.are.equal("t1.a", good(1431655765))
			assert.are.equal("t1.b", good(1431655766))
			assert.are.equal("t1.b", good(2863311530))
			assert.are.equal("t1.c", good(2863311531))
			assert.are.equal("t1.c", good(4294967295))
			-- With one owned, two are left: their edge is 2^32 / 2, and the owned one is skipped in pool order.
			local owned = { ["t1.b"] = true }
			assert.are.equal("t1.a", good(2147483647, owned))
			assert.are.equal("t1.c", good(2147483648, owned))
		end
	)

	it("is the only candidate of a tier whatever the good hash says (SHOP-R51)", function()
		ns.CRATE_POOL = fixturePool()
		for _, goodHash in ipairs({ 0, 1431655766, 4294967295 }) do
			hashes(EDGES[2].last, goodHash)
			assert.are.same({ tier = 2, good = "t2.a" }, ns.CrateRoll("e", {}, 0, 0, PRICE))
		end
	end)

	it("is crate only when it is a Curio tier's (SHOP-R52)", function()
		ns.CRATE_POOL = fixturePool()
		hashes(4294967295, 0)
		assert.are.same({ tier = "curio", good = "foil", crateOnly = true }, ns.CrateRoll("e", {}, 0, 0, PRICE))
	end)

	it("is never one already owned, nor one given twice, over a long run of the real pool (SHOP-R51)", function()
		local owned, seen = {}, {}
		for t = 0, 399 do
			local roll = ns.CrateRoll(crateID(t), owned, 0, 1791731700, PRICE)
			if roll.good then
				assert(seen[roll.good] == nil, roll.good .. " came twice")
				seen[roll.good] = true
				owned[roll.good] = true
			end
		end
		local count = 0
		for _ in pairs(seen) do
			count = count + 1
		end
		assert(count > 90, "a long run empties most of the pool")
	end)

	it("is the same for the same entry and owned set, every time (SHOP-R51, ADR 0004)", function()
		for t = 0, 40 do
			local first = ns.CrateRoll(crateID(t), { ["core.toaststyle.foil"] = true }, 2, 1791731700, PRICE)
			assert.are.same(first, ns.CrateRoll(crateID(t), { ["core.toaststyle.foil"] = true }, 2, 1791731700, PRICE))
		end
	end)

	it("comes from the pool's rows by `since`: a candidate only for a crate bought from then on (SHOP-R53)", function()
		ns.CRATE_POOL = { { id = "late.a", tier = 1, kind = "binding", since = 1000 } }
		hashes(0, 0)
		assert.are.same({ tier = 1, payback = 250 }, ns.CrateRoll("e", {}, 0, 999, PRICE))
		assert.are.same({ tier = 1, payback = 250 }, ns.CrateRoll("e", {}, 0, nil, PRICE))
		assert.are.same({ tier = 1, good = "late.a" }, ns.CrateRoll("e", {}, 0, 1000, PRICE))
		assert.are.same({}, ns.CrateCandidates(1, {}, 999))
		assert.are.same({ "late.a" }, { ns.CrateCandidates(1, {}, 1001)[1].id })
		assert.is_false(ns.CrateHasCandidates({}, 999))
		assert.is_true(ns.CrateHasCandidates({}, 1000))
	end)
end)

describe("ns.CrateRoll's payback", function()
	it(
		"is 250 / 400 / 900 / 1,500 / 1,500 / 1,500 and, for Curio, 1,500 for a tier with no candidate (SHOP-R51)",
		function()
			ns.CRATE_POOL = {}
			local paid = {}
			for _, edge in ipairs(EDGES) do
				hashes(edge.last, 0)
				local roll = ns.CrateRoll("e", {}, 0, 0, PRICE)
				assert.are.equal(edge.tier, roll.tier)
				assert.is_nil(roll.good)
				paid[#paid + 1] = roll.payback
			end
			assert.are.same({ 250, 400, 900, 1500, 1500, 1500, 1500 }, paid)
		end
	)

	it("pays a tier with every good owned too, its price at 1.0 capped by the crate's price (SHOP-R51)", function()
		ns.CRATE_POOL = fixturePool()
		local owned = { ["t1.a"] = true, ["t1.b"] = true, ["t1.c"] = true, ["t5.a"] = true, foil = true }
		hashes(EDGES[1].last, 0)
		assert.are.same({ tier = 1, payback = 250 }, ns.CrateRoll("e", owned, 0, 0, PRICE))
		hashes(EDGES[5].last, 0)
		assert.are.same({ tier = 5, payback = 1500 }, ns.CrateRoll("e", owned, 0, 0, PRICE))
		hashes(EDGES[7].last, 0)
		assert.are.same({ tier = "curio", payback = 1500 }, ns.CrateRoll("e", owned, 0, 0, PRICE))
	end)

	it("is capped by the price in the entry, whatever the crate costs now (SHOP-R50, SHOP-R51)", function()
		ns.CRATE_POOL = {}
		local function payback(edge, price)
			hashes(edge.last, 0)
			return ns.CrateRoll("e", {}, 0, 0, price).payback
		end
		assert.are.same({ 250, 300, 300, 300, 300, 300, 300 }, {
			payback(EDGES[1], 300),
			payback(EDGES[2], 300),
			payback(EDGES[3], 300),
			payback(EDGES[4], 300),
			payback(EDGES[5], 300),
			payback(EDGES[6], 300),
			payback(EDGES[7], 300),
		})
		-- an entry recorded at a higher price: a tier's price at 1.0 is the cap below it, Curio's is the entry's
		assert.are.same({ 250, 900, 3000, 3000, 2000 }, {
			payback(EDGES[1], 2000),
			payback(EDGES[3], 2000),
			payback(EDGES[4], 3000),
			payback(EDGES[4], 5000),
			payback(EDGES[7], 2000),
		})
	end)

	it("reads the price tiers as they stood at 1.0, so a later retune moves no payback (SHOP-R53)", function()
		ns.CRATE_POOL = {}
		for i = 1, #ns.TIER_PRICES do
			ns.TIER_PRICES[i] = ns.TIER_PRICES[i] * 2
		end
		local paid = {}
		for _, edge in ipairs(EDGES) do
			hashes(edge.last, 0)
			paid[#paid + 1] = ns.CrateRoll("e", {}, 0, 0, 100000).payback
		end
		assert.are.same({ 250, 400, 900, 3000, 10000, 25000, 100000 }, paid)
		assert.are.equal(25000, ns.CratePayback(6, 100000))
	end)
end)

describe("ns.CrateRoll's Curio pity", function()
	it(
		"makes the 100th crate in a row without a crate-only good a Curio crate, whatever the hash (SHOP-R52)",
		function()
			ns.CRATE_POOL = fixturePool()
			hashes(0, 0)
			assert.are.equal(1, ns.CrateRoll("e", {}, 98, 0, PRICE).tier)
			assert.are.same({ tier = "curio", good = "foil", crateOnly = true }, ns.CrateRoll("e", {}, 99, 0, PRICE))
			assert.are.same({ tier = "curio", good = "foil", crateOnly = true }, ns.CrateRoll("e", {}, 250, 0, PRICE))
		end
	)

	it("gives a crate-only candidate by the good hash, as any Curio crate does (SHOP-R52)", function()
		ns.CRATE_POOL = fixturePool()
		table.insert(ns.CRATE_POOL, { id = "foil2", tier = "curio", kind = "soundset" })
		hashes(0, 0)
		assert.are.equal("foil", ns.CrateRoll("e", {}, 99, 0, PRICE).good)
		hashes(0, 2147483648)
		assert.are.equal("foil2", ns.CrateRoll("e", {}, 99, 0, PRICE).good)
	end)

	it("does not apply once no crate-only good is a candidate (SHOP-R52)", function()
		ns.CRATE_POOL = fixturePool()
		hashes(0, 0)
		local roll = ns.CrateRoll("e", { foil = true }, 99, 0, PRICE)
		assert.are.same({ tier = 1, good = "t1.a" }, roll)
		hashes(EDGES[7].last, 0)
		assert.are.same({ tier = "curio", payback = 1500 }, ns.CrateRoll("e", { foil = true }, 500, 0, PRICE))
	end)

	it(
		"counts what is left to the next Curio crate, at least 1, none without a crate-only candidate (SHOP-R54)",
		function()
			ns.CRATE_POOL = fixturePool()
			assert.are.equal(100, ns.CratePityLeft({}, 0, 0))
			assert.are.equal(51, ns.CratePityLeft({}, 49, 0))
			assert.are.equal(1, ns.CratePityLeft({}, 99, 0))
			assert.are.equal(1, ns.CratePityLeft({}, 300, 0))
			assert.is_nil(ns.CratePityLeft({ foil = true }, 10, 0))
		end
	)
end)

describe("ns.CrateOdds", function()
	it("lists each crate tier's fixed odds and goods left, or what it pays back with none left (SHOP-R54)", function()
		ns.CRATE_POOL = fixturePool()
		local odds = ns.CrateOdds({ ["t1.a"] = true, ["t5.a"] = true }, 0)
		local lines = {}
		for i, tier in ipairs(odds) do
			lines[i] = { tier.tier, tier.permille, tier.left, tier.payback }
		end
		assert.are.same({
			{ 1, 400, 2, nil },
			{ 2, 260, 1, nil },
			{ 3, 160, 1, nil },
			{ 4, 100, 1, nil },
			{ 5, 50, 0, 1500 },
			{ 6, 25, 0, 1500 },
			{ "curio", 5, 1, nil },
		}, lines)
	end)

	it("pays back the crate's price now, not an entry's, for a tier under it (SHOP-R51)", function()
		ns.CRATE_POOL = {}
		local odds = ns.CrateOdds({}, 0)
		assert.are.same({ 250, 400, 900, 1500, 1500, 1500, 1500 }, {
			odds[1].payback,
			odds[2].payback,
			odds[3].payback,
			odds[4].payback,
			odds[5].payback,
			odds[6].payback,
			odds[7].payback,
		})
	end)
end)
