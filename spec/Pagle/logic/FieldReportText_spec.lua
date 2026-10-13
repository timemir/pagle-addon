describe("ns.FieldReportParts", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	-- The names REP-R30's example shows, by item and by area. Item 6359's name isn't cached.
	local ITEM_NAMES = {
		[6362] = "Raw Spotted Yellowtail",
		[13755] = "Winter Squid",
		[13760] = "Raw Sunscale Salmon",
	}
	local AREA_NAMES = {
		[33] = "Stranglethorn Vale",
		[331] = "Ashenvale",
		[1519] = "Stormwind City",
		[2657] = "Feralas",
	}
	local NAMES = {
		item = function(itemID)
			return ITEM_NAMES[itemID]
		end,
		area = function(areaID)
			return AREA_NAMES[areaID]
		end,
	}
	-- REP-R30's header: logId 3f9a2c1e7b0d4a65 is reporter f38e76b0 (REP-R36).
	local HEADER = {
		addon = "0.9.0",
		fingerprint = "3f9a2c1e5d7b4a8c9e0f1a2b3c4d5e6f",
		locale = "deDE",
		logId = "3f9a2c1e7b0d4a65",
	}

	-- An I row in ticket #121's shape, with no aura, event, t or m unless `extra` sets them.
	local function iRow(item, area, build, count, extra)
		local row = { kind = "I", item = item, area = area, build = build, count = count, auras = {}, events = {} }
		for key, value in pairs(extra or {}) do
			row[key] = value
		end
		return row
	end

	-- The file's bytes, exactly.
	local function readFile(path)
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
		local file = assert(io.open(path, "rb"))
		local text = file:read("*a")
		file:close()
		return text
	end

	-- The lines of one part, without their line ends.
	local function linesOf(part)
		local lines = {}
		for line in part:gmatch("([^\n]*)\n") do
			lines[#lines + 1] = line
		end
		return lines
	end

	-- The row lines of one part: the lines between the two header lines and END.
	local function rowLines(part)
		local lines = linesOf(part)
		return { unpack(lines, 3, #lines - 1) }
	end

	it("writes REP-R30's rows and names as REP-R30's example, the golden file ticket #125 parses (REP-R30)", function()
		-- Out of order, so the example's order is the sort's (REP-R23).
		local rows = {
			{
				kind = "P",
				area = 1519,
				locale = "deDE",
				text = "Schwarm öliger Schwarzmaulfische",
				casts = 5,
				items = { { item = 6358, count = 5 } },
			},
			iRow(13760, 2657, 70338, 3, { t = 21 * 60 + 15, m = 11 }),
			{ kind = "K", area = 1519, build = 70338, casts = 40, away = 6, land = 75, lost = 60 },
			iRow(6359, 1519, 70338, 14),
			iRow(13755, 331, 70338, 6, { events = { 301 }, t = 14 * 60 + 30, m = 5 }),
			iRow(6362, 33, 70338, 2, { auras = { 1280341 } }),
		}

		local parts = ns.FieldReportParts(rows, HEADER, NAMES)

		assert.are.same({ readFile("scripts/tests/fixtures/reports/rep-r30.txt") }, parts)
	end)

	it("sorts by kind, then area as a number, then an I row's item, build, aura, event, t and m (REP-R23)", function()
		local rows = {
			iRow(7, 33, 2, 1, { auras = { 5, 7 } }),
			{ kind = "P", area = 12, locale = "enUS", text = "a", casts = 1, items = {} },
			iRow(7, 33, 2, 1, { auras = { 5 } }),
			{ kind = "K", area = 12, build = 1, casts = 1, away = 0 },
			iRow(7, 33, 2, 1, { auras = { 5 }, events = { 1 } }),
			iRow(7, 33, 2, 1),
			iRow(7, 33, 2, 1, { auras = { 7 } }),
			iRow(7, 33, 2, 1, { t = 60, m = 1 }),
			iRow(7, 33, 2, 1, { t = 45, m = 2 }),
			iRow(7, 33, 2, 1, { t = 45, m = 1 }),
			iRow(7, 33, 1, 1, { auras = { 9 } }),
			iRow(6, 33, 2, 1, { auras = { 9 } }),
			iRow(7, 331, 1, 1),
			iRow(7, 4, 1, 1),
		}

		local parts = ns.FieldReportParts(rows, HEADER, { item = function() end, area = function() end })

		assert.are.same({
			"I 7 4 1 1",
			"I 6 33 2 1 aura=9",
			"I 7 33 1 1 aura=9",
			-- An absent aura first; then a list that is a prefix of another before it, compared as numbers.
			"I 7 33 2 1",
			"I 7 33 2 1 t=00:45 m=1",
			"I 7 33 2 1 t=00:45 m=2",
			"I 7 33 2 1 t=01:00 m=1",
			"I 7 33 2 1 aura=5",
			"I 7 33 2 1 aura=5 event=1",
			"I 7 33 2 1 aura=5,7",
			"I 7 33 2 1 aura=7",
			"I 7 331 1 1",
			"K 12 1 casts=1 away=0",
			'P 12 enUS "a" casts=1',
		}, rowLines(parts[1]))
	end)

	it("sorts K rows by build and P rows by locale, then text by byte order (REP-R23)", function()
		local function pRow(locale, text)
			return { kind = "P", area = 1, locale = locale, text = text, casts = 1, items = {} }
		end
		local rows = {
			pRow("enUS", "ab"),
			pRow("enUS", "öl"),
			{ kind = "K", area = 1, build = 70338, casts = 1, away = 0 },
			pRow("enUS", "a"),
			pRow("deDE", "z"),
			pRow("enUS", "Z"),
			{ kind = "K", area = 1, build = 9999, casts = 1, away = 0 },
		}

		local parts = ns.FieldReportParts(rows, HEADER, { item = function() end, area = function() end })

		assert.are.same({
			"K 1 9999 casts=1 away=0",
			"K 1 70338 casts=1 away=0",
			'P 1 deDE "z" casts=1',
			'P 1 enUS "Z" casts=1',
			'P 1 enUS "a" casts=1',
			'P 1 enUS "ab" casts=1',
			'P 1 enUS "öl" casts=1',
		}, rowLines(parts[1]))
	end)

	it("leaves out a K row's missing land or lost, and lists a P row's items in order (REP-R21, REP-R22)", function()
		local rows = {
			{ kind = "K", area = 1, build = 1, casts = 3, away = 0, land = 40 },
			{ kind = "K", area = 1, build = 2, casts = 3, away = 3, lost = 12 },
			{ kind = "K", area = 1, build = 3, casts = 0, away = 0 },
			{
				kind = "P",
				area = 1,
				locale = "enUS",
				text = "Oily Blackmouth School",
				casts = 4,
				items = { { item = 6358, count = 5 }, { item = 6359, count = 1 } },
			},
		}

		local parts = ns.FieldReportParts(rows, HEADER, { item = function() end, area = function() end })

		assert.are.same({
			"K 1 1 casts=3 away=0 land=40",
			"K 1 2 casts=3 away=3 lost=12",
			"K 1 3 casts=0 away=0",
			'P 1 enUS "Oily Blackmouth School" casts=4 6358x5 6359x1',
		}, rowLines(parts[1]))
	end)

	it('writes a P text\'s ", \\ and newline as \\", \\\\ and \\n (REP-R32)', function()
		local rows = {
			{ kind = "P", area = 1, locale = "enUS", text = 'say "hi"\\\nbye # not', casts = 1, items = {} },
		}

		local parts = ns.FieldReportParts(rows, HEADER, { item = function() end, area = function() end })

		assert.are.same({ 'P 1 enUS "say \\"hi\\"\\\\\\nbye # not" casts=1' }, rowLines(parts[1]))
	end)

	it(
		"comments an I row with its item and area names, leaving out a missing one, and writes none with no names (REP-R30)",
		function()
			local rows = {
				iRow(13755, 331, 1, 1),
				iRow(6359, 1519, 1, 1),
				iRow(13755, 9999, 1, 1),
				iRow(6359, 9999, 1, 2),
				{ kind = "K", area = 9999, build = 1, casts = 1, away = 0 },
			}

			local parts = ns.FieldReportParts(rows, HEADER, NAMES)

			-- The I rows' comments line up with the widest I row that has one; a row with none has no trailing spaces.
			assert.are.same({
				"I 13755 331 1 1  # Winter Squid, Ashenvale",
				"I 6359 1519 1 1  # Stormwind City",
				"I 6359 9999 1 2",
				"I 13755 9999 1 1 # Winter Squid",
				"K 9999 1 casts=1 away=0",
			}, rowLines(parts[1]))
		end
	)

	it("keeps a line break in a name out of the text (REP-R30)", function()
		local names = {
			item = function()
				return "Odd\nFish"
			end,
			area = function()
				return "Far\r\nAway"
			end,
		}

		local parts = ns.FieldReportParts({ iRow(1, 2, 3, 4) }, HEADER, names)

		assert.are.same({ "I 1 2 3 4 # Odd Fish, Far  Away" }, rowLines(parts[1]))
	end)

	it("writes no rows as one part: the two header lines and END (REP-R30)", function()
		local parts = ns.FieldReportParts({}, HEADER, NAMES)

		assert.are.same({
			"PAGLE-REPORT 1\naddon 0.9.0 data 3f9a2c1e locale deDE reporter f38e76b0 part 1/1\nEND\n",
		}, parts)
	end)

	it(
		"splits over 60,000 bytes into parts 1/n to n/n, each full and at most 60,000 bytes, no row cut (REP-R33)",
		function()
			-- 30,000 rows of 22 or 23 bytes: about 11 parts, so the part count has two digits.
			local rows, expected = {}, {}
			for item = 100000, 129999 do
				rows[#rows + 1] = iRow(item, 1519, 70338, 1)
				expected[#expected + 1] = "I " .. item .. " 1519 70338 1"
			end
			-- Handed over in reverse, so the parts follow the sort, not the input.
			local reversed = {}
			for i = #rows, 1, -1 do
				reversed[#reversed + 1] = rows[i]
			end

			local parts = ns.FieldReportParts(reversed, HEADER, { item = function() end, area = function() end })

			assert.is_true(#parts >= 10)
			local written = {}
			for n, part in ipairs(parts) do
				assert.is_true(#part <= 60000)
				local lines = linesOf(part)
				assert.are.equal("PAGLE-REPORT 1", lines[1])
				assert.are.equal(
					"addon 0.9.0 data 3f9a2c1e locale deDE reporter f38e76b0 part " .. n .. "/" .. #parts,
					lines[2]
				)
				assert.are.equal("END", lines[#lines])
				assert.are.equal(part, table.concat(lines, "\n") .. "\n")
				local partRows = rowLines(part)
				for _, line in ipairs(partRows) do
					written[#written + 1] = line
				end
				-- Full: the next part's first row wouldn't have fit in this one.
				if parts[n + 1] then
					local nextFirst = rowLines(parts[n + 1])[1]
					assert.is_true(#part + #nextFirst + 1 > 60000)
				end
			end
			assert.are.same(expected, written)
		end
	)

	it("counts a two-digit part count in each part's size (REP-R33)", function()
		-- 30,000 rows of 23 bytes make 12 parts. The addon version is padded so part 1's header and END leave room
		-- for 22 bytes less than a whole row: a part sized as if its header said "part 1/1" would take one row more
		-- and end 1 byte over the limit.
		local rows = {}
		for item = 1000000, 1029999 do
			rows[#rows + 1] = iRow(item, 1519, 70338, 1)
		end
		local header = { fingerprint = HEADER.fingerprint, locale = "deDE", logId = HEADER.logId }
		for pad = 0, 22 do
			header.addon = "0.9." .. string.rep("0", pad + 1)
			local overhead = #(
				"PAGLE-REPORT 1\naddon "
				.. header.addon
				.. " data 3f9a2c1e locale deDE reporter f38e76b0 part 1/12\nEND\n"
			)
			if (60000 - overhead) % 23 == 22 then
				break
			end
		end

		local parts = ns.FieldReportParts(rows, header, { item = function() end, area = function() end })

		assert.are.equal(12, #parts)
		for _, part in ipairs(parts) do
			assert.is_true(#part <= 60000)
		end
		assert.are.equal(60000 - 22, #parts[1])
	end)
end)

describe("ns.ReporterKey", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	it("is REP-R36's test vector: logId 3f9a2c1e7b0d4a65 gives f38e76b0 (REP-R36)", function()
		assert.are.equal("f38e76b0", ns.ReporterKey("3f9a2c1e7b0d4a65"))
	end)

	it("is the key data/observed/dev.toml holds for the dev's logId 314ca8bd2fb83d86 (REP-R36)", function()
		assert.are.equal("38d9e978", ns.ReporterKey("314ca8bd2fb83d86"))
	end)

	-- FNV-1a 32-bit's published vectors (Fowler, Noll and Vo's test suite).
	it("matches FNV-1a 32-bit on the empty string, 'a' and 'foobar' (REP-R36)", function()
		assert.are.equal("811c9dc5", ns.ReporterKey(""))
		assert.are.equal("e40c292c", ns.ReporterKey("a"))
		assert.are.equal("bf9cf968", ns.ReporterKey("foobar"))
	end)

	-- Python's arbitrary-precision FNV-1a gives 0x71890c for this logId.
	it("zero-pads a hash below 0x10000000 to 8 characters (REP-R36)", function()
		assert.are.equal("0071890c", ns.ReporterKey("000000000000020a"))
	end)
end)
