-- Simulated Size (LOG-R65–R68, ADR 0010): the percentile hash of a Catch ID, its Size band and its length, as pure
-- logic over the Catch ID and the Species' typical length.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

-- THE 1.0 FREEZE (#267, LOG-R68, ADR 0010). From the 1.0 tag, a Catch's Size band never changes: Hunts and Notices
-- that target a minimum band are rebuilt from the Catch log, and a moved band could revoke a completed one. So this
-- spec pins the hash (every `h` below) and the cut points (the Catch IDs either side of each). If it fails, don't
-- edit these numbers: a change to how bands are drawn ships as new bands with new IDs (ADR 0010).
local FROZEN = "the Simulated Size hash and cut points are frozen at 1.0 (ADR 0010, LOG-R68): a change to how bands"
	.. " are drawn ships as new bands with new IDs, never by editing these. "

describe("the Simulated Size percentile, frozen at 1.0 (ADR 0010)", function()
	-- LOG-R66's test vectors: the Catch ID, `h` after step 2, `u` to six places, the band and the length at a typical
	-- length of 300 mm.
	local VECTORS = {
		{ "Player-4395-0A1B2C3D-1791731747-0:1", 2657620567, 0.618776, 2, 314 },
		{ "Player-4395-0A1B2C3D-1791731747-0:2", 4227872046, 0.984378, 4, 453 },
		{ "Player-4395-0A1B2C3D-1791731762-1:1", 1190098033, 0.277091, 2, 249 },
		{ "Player-1-00000001-1700000000-0:1", 3063819173, 0.713351, 3, 333 },
	}

	for _, vector in ipairs(VECTORS) do
		local catchId, h, u, band, length = unpack(vector)

		it(("gives %s LOG-R66's h, u, band and length (LOG-R66, LOG-R67)"):format(catchId), function()
			assert.are.equal(h, ns.SizeHash(catchId), FROZEN .. "The hash of " .. catchId .. " moved.")
			assert.are.equal(
				h / 2 ^ 32,
				ns.SizePercentile(catchId),
				FROZEN .. "The percentile of " .. catchId .. " moved."
			)
			assert.is_true(math.abs(ns.SizePercentile(catchId) - u) < 0.0000005, FROZEN .. "u moved.")
			assert.are.equal(
				band,
				ns.SimulatedSize(catchId, 300).band,
				FROZEN .. "The band of " .. catchId .. " moved."
			)
			-- The length follows the multipliers, which stay tunable after 1.0 (LOG-R68): a retune updates LOG-R66's
			-- table and this column, and bumps SIZE_RULES_VERSION.
			assert.are.equal(
				length,
				ns.SimulatedSize(catchId, 300).length,
				"the length at a typical 300 mm moved: if the multipliers were retuned (LOG-R68), update LOG-R66's"
					.. " table and this vector, and bump SIZE_RULES_VERSION; the band must not move (ADR 0010)"
			)
		end)
	end

	-- The Catch IDs whose percentiles lie closest below and at-or-above each cut point (0.15, 0.70, 0.93, 0.995) among
	-- 30,000,000 synthetic ones (sequential times, items 1–3), found once by search: each `u` is within 0.00000005 of
	-- its cut, so moving a cut point by more than that moves one of these Catches between bands (LOG-R67). Each row:
	-- the Catch ID, its `h` and its band.
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

	it("puts the Catch IDs either side of each cut point in the bands LOG-R67 gives (LOG-R67, LOG-R68)", function()
		for _, vector in ipairs(CUT_VECTORS) do
			local catchId, h, band = unpack(vector)
			assert.are.equal(h, ns.SizeHash(catchId), FROZEN .. "The hash of " .. catchId .. " moved.")
			for _, typicalLength in ipairs({ 100, 300, 2200 }) do
				local got = ns.SimulatedSize(catchId, typicalLength).band
				assert.are.equal(band, got, FROZEN .. "A cut point moved: " .. catchId .. " left band " .. band .. ".")
			end
		end
	end)

	-- #slow: 500,000 hashes take 2 s, and ten times that under luacov's line hook, so scripts/check.sh runs it once,
	-- in a pass without coverage.
	it(
		"spreads 300,000 synthetic Catch IDs over the bands as LOG-R67's cut points do, items 1 and 2 of a Cast uncorrelated (LOG-R66, LOG-R67) #slow",
		function()
			-- Casts at sequential times, 1–3 items each, cycling, until 300,000 Catch IDs; the share each band should get.
			local SHARES = { 0.15, 0.55, 0.23, 0.065, 0.005 }
			local counts, total = { 0, 0, 0, 0, 0 }, 0
			local firsts, seconds = {}, {} -- the percentiles of items 1 and 2 of each Cast with a second item
			local cast = 0
			while total < 300000 do
				cast = cast + 1
				local entryId = "Player-4618-0A1B2C3D-" .. (1791731747 + cast) .. "-0"
				local first
				for n = 1, math.min(cast % 3 + 1, 300000 - total) do
					local catchId = entryId .. ":" .. n
					local band = ns.SimulatedSize(catchId, 300).band
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

describe("a Simulated Size retuned", function()
	-- Forty Catches of one Species, with their sizes at a typical length of 300 mm and the shipped multipliers.
	local catchIds = {}
	for i = 1, 40 do
		catchIds[i] = ("Player-4618-0A1B2C3D-%d-0:%d"):format(1791731700 + i, i % 3 + 1)
	end

	-- The Catch ID of the longest Catch, and every Catch's size, at this typical length and these multipliers.
	local function sizes(typicalLength, multipliers)
		local all, longest = {}, nil
		for _, catchId in ipairs(catchIds) do
			all[catchId] = ns.SimulatedSize(catchId, typicalLength, multipliers)
			if not longest or all[catchId].length > all[longest].length then
				longest = catchId
			end
		end
		return all, longest
	end

	it("moves no Catch between bands and keeps the Species' longest Catch the longest (LOG-R68, ADR 0010)", function()
		local before, longest = sizes(300)
		local bands = {}
		for _, size in pairs(before) do
			bands[size.band] = true
		end
		assert.are.same({ true, true, true, true }, { bands[1], bands[2], bands[3], bands[4] }) -- the fixture spans them

		for _, retuned in ipairs({
			{ 420 }, -- a typical length
			{ 300, { 0.5, 0.7, 1.0, 1.4, 1.7, 2.2 } }, -- the multipliers
			{ 180, { 0.6, 0.8, 1.05, 1.2, 1.4, 1.5 } }, -- both
		}) do
			local after = sizes(retuned[1], retuned[2])
			for catchId, size in pairs(before) do
				assert.are.equal(size.band, after[catchId].band)
				assert.is_true(after[catchId].length <= after[longest].length)
			end
			assert.are_not.equal(before[longest].length, after[longest].length)
		end
	end)
end)
