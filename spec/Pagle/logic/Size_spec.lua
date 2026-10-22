-- Simulated Size (LOG-R65–R68, ADR 0014): the percentile hash of a Catch ID, the Reach of skill and experience that
-- bounds a Species Catch, its Size band and its length, as pure logic over the Catch ID, the Species' typical length,
-- the Cast's skill rank, the Angler's earlier Catches of the item and whether it is a Legend (ns.CatchSize).

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

-- THE 1.0 FREEZE (#267, LOG-R68, ADR 0014). From the 1.0 tag, a Catch's Size band never changes: Hunts and Notices
-- that target a minimum band are rebuilt from the Catch log, and a moved band could revoke a completed one. So this
-- spec pins the hash (every `h` below), the Reach's 300 and 1,000 and both its curves, the exponent 3, the band edges
-- (the Catch IDs either side of each), the full range's ends and, for Legends, ADR 0010's cut points. If it fails,
-- don't edit these numbers: a change to how bands are drawn ships as new bands with new IDs (ADR 0014).
local FROZEN = "the Simulated Size is frozen at 1.0 (ADR 0014, LOG-R68): its hash, the Reach's 300 and 1,000 and"
	.. " curves, the exponent 3, the band edges, the range's ends and a Legend's cut points never change; a change"
	.. " to how bands are drawn ships as new bands with new IDs, never by editing these. "

-- LOG-R66's test vectors.
local A = "Player-4395-0A1B2C3D-1791731747-0:1"
local B = "Player-4395-0A1B2C3D-1791731747-0:2"
local C = "Player-4395-0A1B2C3D-1791731762-1:1"
local D = "Player-1-00000001-1700000000-0:1"

-- The Simulated Size of a Species Catch that isn't a Legend: `catchId` at a typical length of `typical` mm, with this
-- skill rank and this many earlier Catches of its item.
local function sized(catchId, typical, skillRank, earlier)
	return ns.CatchSize(catchId, typical, skillRank, earlier, false)
end

describe("the Simulated Size percentile, frozen at 1.0 (ADR 0010, ADR 0014)", function()
	-- LOG-R66's test vectors: the Catch ID, `h` after step 2 and `u` to six places.
	local VECTORS = {
		{ A, 2657620567, 0.618776 },
		{ B, 4227872046, 0.984378 },
		{ C, 1190098033, 0.277091 },
		{ D, 3063819173, 0.713351 },
	}

	for _, vector in ipairs(VECTORS) do
		local catchId, h, u = unpack(vector)

		it(("gives %s LOG-R66's h and u (LOG-R66)"):format(catchId), function()
			assert.are.equal(h, ns.SizeHash(catchId), FROZEN .. "The hash of " .. catchId .. " moved.")
			assert.are.equal(
				h / 2 ^ 32,
				ns.SizePercentile(catchId),
				FROZEN .. "The percentile of " .. catchId .. " moved."
			)
			assert(math.abs(ns.SizePercentile(catchId) - u) < 0.0000005, FROZEN .. "u moved.")
		end)
	end
end)

describe("a Simulated Size bounded by a Reach, frozen at 1.0 (ADR 0014)", function()
	-- LOG-R67's worked examples, each the Catch ID, the skill rank, the earlier Catches, then the band and the length at
	-- a typical length of 300 mm, worked by hand from `u`: p = R × u^(1/3), length = floor(300 × (0.55 + 1.25p) + 0.5).
	local VECTORS = {
		-- R = 1 (skill 300 and 1,000 earlier Catches): p = u^(1/3), the full range.
		{ A, 300, 1000, 5, 485 }, -- p 0.852140
		{ B, 300, 1000, 5, 538 }, -- p 0.994765
		{ C, 300, 1000, 4, 409 }, -- p 0.651940
		{ D, 300, 1000, 5, 500 }, -- p 0.893513
		-- R = 0.75, by skill: 225 ÷ 300.
		{ A, 225, 1000, 4, 405 }, -- p 0.639105
		{ B, 225, 1000, 4, 445 }, -- p 0.746074
		{ C, 225, 1000, 3, 348 }, -- p 0.488955
		{ D, 225, 1000, 4, 416 }, -- p 0.670135
		-- R = √(300 ÷ 1,000) = 0.547723, by experience under a skill of 200 (0.667).
		{ A, 200, 300, 3, 340 }, -- p 0.466736
		{ B, 200, 300, 3, 369 }, -- p 0.544855
		{ C, 200, 300, 2, 299 }, -- p 0.357082
		{ D, 200, 300, 3, 349 }, -- p 0.489397
		-- R = 0.1: 10 earlier Catches, √0.01.
		{ A, 300, 10, 1, 197 }, -- p 0.085214
		{ B, 300, 10, 1, 202 }, -- p 0.099477
		{ C, 300, 10, 1, 189 }, -- p 0.065194
		{ D, 300, 10, 1, 199 }, -- p 0.089351
	}

	it("gives LOG-R67's worked examples their band and length (LOG-R67)", function()
		for _, vector in ipairs(VECTORS) do
			local catchId, skillRank, earlier, band, length = unpack(vector)
			local label = ("%s at skill %d after %d Catches"):format(catchId, skillRank, earlier)
			local size = sized(catchId, 300, skillRank, earlier)
			assert.are.equal(band, size.band, FROZEN .. "The band of " .. label .. " moved.")
			assert.are.equal(length, size.length, FROZEN .. "The length of " .. label .. " at 300 mm moved.")
		end
	end)

	-- The Catch IDs whose percentiles lie closest below and at or above `c³` for each band edge `c` (0.16, 0.44, 0.60,
	-- 0.80) among 30,000,000 synthetic ones (sequential times, items 1–3), found once by search: at R = 1 the band
	-- reads u^(1/3), so each `u` lies within 0.00000011 of its edge's cube, and moving that cube (or the exponent)
	-- by more than that moves one between bands (LOG-R67). Each row: the Catch ID, its `h` and its band
	-- at R = 1.
	local EDGE_VECTORS = {
		{ "Player-4618-0A1B2C3D-1806609840-0:1", 17592106, 1 }, -- u 0.004095981363
		{ "Player-4618-0A1B2C3D-1802530079-0:1", 17592643, 2 }, -- u 0.004096106393
		{ "Player-4618-0A1B2C3D-1806485069-0:1", 365862461, 2 }, -- u 0.085183992283
		{ "Player-4618-0A1B2C3D-1793990922-0:2", 365862958, 3 }, -- u 0.085184108000
		{ "Player-4618-0A1B2C3D-1794806097-0:1", 927712747, 3 }, -- u 0.215999956010
		{ "Player-4618-0A1B2C3D-1805007265-0:1", 927712947, 4 }, -- u 0.216000002576
		{ "Player-4618-0A1B2C3D-1805795550-0:2", 2199023138, 4 }, -- u 0.511999972630
		{ "Player-4618-0A1B2C3D-1800687898-0:2", 2199023326, 5 }, -- u 0.512000016402
	}

	it("puts the Catch IDs either side of each band edge in the bands LOG-R67 gives at full Reach (LOG-R67)", function()
		for _, vector in ipairs(EDGE_VECTORS) do
			local catchId, h, band = unpack(vector)
			assert.are.equal(h, ns.SizeHash(catchId), FROZEN .. "The hash of " .. catchId .. " moved.")
			for _, typical in ipairs({ 100, 300, 2200 }) do
				local got = sized(catchId, typical, 300, 1000).band
				assert.are.equal(band, got, FROZEN .. "A band edge moved: " .. catchId .. " left band " .. band .. ".")
			end
		end
	end)

	-- The Catch IDs closest below and at or above u = 0.421875 in the same search, where a Reach of exactly 0.8 puts p
	-- at Whopper's edge (0.8 × 0.421875^(1/3) = 0.6): Hefty below, Whopper above, whether skill (240 ÷ 300) or
	-- experience (√(640 ÷ 1,000)) gives the 0.8. One rank or one Catch either way moves one of them across.
	local BELOW, ABOVE = "Player-4618-0A1B2C3D-1793475348-0:2", "Player-4618-0A1B2C3D-1801592179-0:2"

	it("puts a Reach of 0.8 at Whopper's edge by skill ÷ 300 and by √(Catches ÷ 1,000) (LOG-R67)", function()
		assert.are.equal(1811939168, ns.SizeHash(BELOW), FROZEN .. "The hash of " .. BELOW .. " moved.") -- u 0.421874963
		assert.are.equal(1811939753, ns.SizeHash(ABOVE), FROZEN .. "The hash of " .. ABOVE .. " moved.") -- u 0.421875099
		local function bands(skillRank, earlier)
			return { sized(BELOW, 300, skillRank, earlier).band, sized(ABOVE, 300, skillRank, earlier).band }
		end

		local SKILL = FROZEN .. "The skill reach moved: skill counts in 300ths."
		local EXPERIENCE = FROZEN .. "The experience reach moved: √(n ÷ 1,000)."
		assert.are.same({ 3, 4 }, bands(240, 1000), SKILL)
		assert.are.same({ 3, 3 }, bands(239, 1000), SKILL)
		assert.are.same({ 4, 4 }, bands(241, 1000), SKILL)
		assert.are.same({ 3, 4 }, bands(300, 640), EXPERIENCE)
		assert.are.same({ 3, 3 }, bands(300, 639), EXPERIENCE)
		assert.are.same({ 4, 4 }, bands(300, 641), EXPERIENCE)
	end)

	-- #slow: 300,000 hashes take 2 s, and ten times that under luacov's line hook, so scripts/check.sh runs it once,
	-- in a pass without coverage.
	it(
		"spreads 300,000 synthetic Catch IDs at full Reach over the bands as u ≥ c³ does, items 1 and 2 of a Cast uncorrelated (LOG-R66, LOG-R67) #slow",
		function()
			-- Casts at sequential times, 1–3 items each, cycling, until 300,000 Catch IDs; the share each band should get
			-- at R = 1: band i from u ≥ c³ of its low edge.
			local SHARES = { 0.004096, 0.081088, 0.130816, 0.296, 0.488 }
			local counts, total = { 0, 0, 0, 0, 0 }, 0
			local firsts, seconds = {}, {} -- the percentiles of items 1 and 2 of each Cast with a second item
			local cast = 0
			while total < 300000 do
				cast = cast + 1
				local entryId = "Player-4618-0A1B2C3D-" .. (1791731747 + cast) .. "-0"
				local first
				for n = 1, math.min(cast % 3 + 1, 300000 - total) do
					local catchId = entryId .. ":" .. n
					local band = sized(catchId, 300, 300, 1000).band
					counts[band] = counts[band] + 1
					total = total + 1
					if n == 1 then
						first = ns.SizePercentile(catchId)
					elseif n == 2 then
						firsts[#firsts + 1], seconds[#seconds + 1] = first, ns.SizePercentile(catchId)
					end
				end
			end

			local outside = {} -- each band whose share is more than 0.5 points off
			for band, share in ipairs(SHARES) do
				if math.abs(counts[band] / total - share) > 0.005 then
					outside[#outside + 1] = ("band %d: %d of %d"):format(band, counts[band], total)
				end
			end
			assert.are.same({}, outside)
			-- Pearson's r of item 1's and item 2's percentiles over every Cast with a second item: for independent draws
			-- its standard error is 1/sqrt(pairs), about 0.003 here, so 0.02 is far outside chance.
			local n, sx, sy, sxx, syy, sxy = #seconds, 0, 0, 0, 0, 0
			for i = 1, n do
				local x, y = firsts[i], seconds[i]
				sx, sy, sxx, syy, sxy = sx + x, sy + y, sxx + x * x, syy + y * y, sxy + x * y
			end
			local r = (n * sxy - sx * sy) / math.sqrt((n * sxx - sx * sx) * (n * syy - sy * sy))
			assert.is_true(math.abs(r) < 0.02)
		end
	)
end)

describe("a Legend's Simulated Size, frozen at 1.0 (ADR 0010, ADR 0014)", function()
	it("gives a Legend ADR 0010's hash-only size, with no Reach (LOG-R67, LOG-R68)", function()
		-- LOG-R66's vectors under ADR 0010's cut points and the multipliers, at a typical length of 300 mm: whatever
		-- the skill and earlier Catches, even a first Catch at skill 1.
		for _, vector in ipairs({ { A, 2, 314 }, { B, 4, 453 }, { C, 2, 249 }, { D, 3, 333 } }) do
			local catchId, band, length = unpack(vector)
			for _, case in ipairs({ { 1, 0 }, { 300, 1000 }, { 150, 40 } }) do
				local size = ns.CatchSize(catchId, 300, case[1], case[2], true)
				assert.are.same({ length = length, band = band }, size, FROZEN .. "A Legend's size moved.")
			end
		end
	end)

	-- The Catch IDs closest below and at or above each of ADR 0010's cut points (0.15, 0.70, 0.93, 0.995) among
	-- 30,000,000 synthetic ones, found once by search (#267): each `u` is within 0.00000005 of its cut. Each row: the
	-- Catch ID, its `h` and a Legend's band.
	local CUT_VECTORS = {
		{ "Player-4618-0A1B2C3D-1799314201-0:1", 644245050, 1 }, -- u 0.149999989662
		{ "Player-4618-0A1B2C3D-1795694143-0:2", 644245166, 2 }, -- u 0.150000016671
		{ "Player-4618-0A1B2C3D-1792991317-0:1", 3006476924, 2 }, -- u 0.699999957345
		{ "Player-4618-0A1B2C3D-1801127160-0:1", 3006477711, 3 }, -- u 0.700000140583
		{ "Player-4618-0A1B2C3D-1795545976-0:3", 3994319574, 3 }, -- u 0.929999997374
		{ "Player-4618-0A1B2C3D-1794590578-0:2", 3994319676, 4 }, -- u 0.930000021122
		{ "Player-4618-0A1B2C3D-1801458363-0:3", 4273492334, 4 }, -- u 0.994999970775
		{ "Player-4618-0A1B2C3D-1801712766-0:1", 4273492493, 5 }, -- u 0.995000007795
	}

	it("puts the Catch IDs either side of each Legend cut point in ADR 0010's bands (LOG-R67, LOG-R68)", function()
		for _, vector in ipairs(CUT_VECTORS) do
			local catchId, h, band = unpack(vector)
			assert.are.equal(h, ns.SizeHash(catchId), FROZEN .. "The hash of " .. catchId .. " moved.")
			for _, typical in ipairs({ 100, 300, 2200 }) do
				local got = ns.CatchSize(catchId, typical, 1, 0, true).band
				assert.are.equal(
					band,
					got,
					FROZEN .. "A Legend's cut point moved: " .. catchId .. " left " .. band .. "."
				)
			end
		end
	end)

	it("spans a Legend over the same full range as every other Species, 0.55× to 1.80× (LOG-R67, LOG-R68)", function()
		assert.are.equal(0.55, ns.SIZE_MULTIPLIERS[1], FROZEN .. "The range's low end moved.")
		assert.are.equal(1.80, ns.SIZE_MULTIPLIERS[6], FROZEN .. "The range's top moved.")
	end)
end)

describe("a Simulated Size bounded by a Reach", function()
	it("makes the first Catch of an item its smallest length, a Tiddler, whatever the skill (LOG-R67)", function()
		for _, catchId in ipairs({ A, B, C, D }) do
			assert.are.same({ length = 165, band = 1 }, sized(catchId, 300, 300, 0)) -- 0.55 × 300
			assert.are.same({ length = 231, band = 1 }, sized(catchId, 420, 1, 0)) -- 0.55 × 420
		end
	end)

	it("counts skill to 300 and earlier Catches to 1,000, no further (LOG-R67)", function()
		for _, catchId in ipairs({ A, B, C, D }) do
			local full = sized(catchId, 300, 300, 1000)
			assert.are.same(full, sized(catchId, 300, 375, 1000))
			assert.are.same(full, sized(catchId, 300, 300, 25000))
		end
	end)

	it("bounds by the lesser of the skill and experience reaches, whichever it is (LOG-R67)", function()
		-- R = 0.5 either way: skill 150 ÷ 300 with a full experience, or √(250 ÷ 1,000) with full skill.
		for _, vector in ipairs({
			{ A, 2, 325 }, -- p 0.426070
			{ B, 3, 352 }, -- p 0.497383
			{ C, 2, 287 }, -- p 0.325970
			{ D, 3, 333 }, -- p 0.446757
		}) do
			local catchId, band, length = unpack(vector)
			assert.are.same({ length = length, band = band }, sized(catchId, 300, 150, 1000))
			assert.are.same({ length = length, band = band }, sized(catchId, 300, 300, 250))
			assert.are.same({ length = length, band = band }, sized(catchId, 300, 150, 250))
		end
	end)

	it("keeps a skill of 1 at the bottom of the range, however many earlier Catches (LOG-R67)", function()
		-- R = 1/300: 165 mm plus at most 1.25 mm.
		assert.are.same({ { length = 166, band = 1 }, { length = 166, band = 1 }, { length = 166, band = 1 } }, {
			sized(A, 300, 1, 1000),
			sized(B, 300, 1, 1000),
			sized(D, 300, 1, 1000),
		})
	end)

	it("never sizes a Catch beyond its Reach (LOG-R67)", function()
		-- 600 synthetic Catch IDs at a spread of skills and earlier Catches: no length past the Reach's own, no band
		-- past the band the Reach itself is in.
		for i = 1, 600 do
			local catchId = ("Player-4618-0A1B2C3D-%d-0:%d"):format(1791731700 + i, i % 3 + 1)
			local skillRank, earlier = (i * 37) % 301, (i * 53) % 1201
			local reach = math.min(skillRank / 300, math.sqrt(math.min(earlier, 1000) / 1000))
			local size = sized(catchId, 300, skillRank, earlier)
			local reachBand = 1
			for band, edge in ipairs({ 0.16, 0.44, 0.60, 0.80 }) do
				if reach >= edge then
					reachBand = band + 1
				end
			end
			assert.is_true(size.length <= math.floor(300 * (0.55 + 1.25 * reach) + 0.5))
			assert.is_true(size.band <= reachBand)
		end
	end)

	it("reaches the full range at skill 300 after 1,000 Catches: Hefty to Monster, near 1.80× (LOG-R67)", function()
		local longest, bands = 0, {}
		for i = 1, 300 do
			local size = sized(("Player-4618-0A1B2C3D-%d-0:1"):format(1791731700 + i), 300, 300, 1000)
			longest, bands[size.band] = math.max(longest, size.length), true
		end
		assert.are.same({ true, true, true }, { bands[3], bands[4], bands[5] })
		assert.is_true(longest > 530 and longest <= 540) -- 1.80 × 300
	end)
end)

describe("a Simulated Size retuned", function()
	-- Forty Catches of one Species, at a spread of skills and earlier Catches.
	local catches = {}
	for i = 1, 40 do
		catches[i] = { ("Player-4618-0A1B2C3D-%d-0:%d"):format(1791731700 + i, i % 3 + 1), 150 + i * 4, i * 30 }
	end

	-- Every Catch's size at this typical length, under a Reach or (`legend`) as a Legend's with these multipliers,
	-- and the index of the longest.
	local function sizes(typical, legend, multipliers)
		local all, longest = {}, 1
		for i, catch in ipairs(catches) do
			if legend then
				all[i] = ns.SimulatedSize(catch[1], typical, multipliers)
			else
				all[i] = ns.CatchSize(catch[1], typical, catch[2], catch[3], false)
			end
			if all[i].length > all[longest].length then
				longest = i
			end
		end
		return all, longest
	end

	-- The bands `all` spans, as a set.
	local function spanned(all)
		local bands = {}
		for _, size in ipairs(all) do
			bands[size.band] = true
		end
		return bands
	end

	it("moves no Catch between bands, and keeps the longest the longest, at a new typical length (LOG-R68)", function()
		local before, longest = sizes(300)
		local bands = spanned(before)
		assert.are.same({ true, true, true, true }, { bands[1], bands[2], bands[3], bands[4] }) -- the fixture spans them

		for _, typical in ipairs({ 180, 420, 2200 }) do
			local after = sizes(typical)
			for i, size in ipairs(before) do
				assert.are.equal(size.band, after[i].band)
				assert.is_true(after[i].length <= after[longest].length)
			end
			assert.are_not.equal(before[longest].length, after[longest].length)
		end
	end)

	it("moves no Legend between bands at new inner multipliers or a new typical length (LOG-R68)", function()
		local before, longest = sizes(300, true)
		local bands = spanned(before)
		assert.are.same({ true, true, true, true }, { bands[1], bands[2], bands[3], bands[4] }) -- the fixture spans them

		for _, retuned in ipairs({
			{ 420 }, -- a typical length
			{ 300, { 0.55, 0.7, 1.0, 1.4, 1.7, 1.80 } }, -- the inner multipliers
			{ 180, { 0.55, 0.8, 1.05, 1.2, 1.4, 1.80 } }, -- both
		}) do
			local after = sizes(retuned[1], true, retuned[2])
			for i, size in ipairs(before) do
				assert.are.equal(size.band, after[i].band)
				assert.is_true(after[i].length <= after[longest].length)
			end
			assert.are_not.equal(before[longest].length, after[longest].length)
		end
	end)
end)
