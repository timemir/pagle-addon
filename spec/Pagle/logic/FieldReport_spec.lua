-- The Field report's rows (field-report.md, REP-R1–R26): ns.NewFieldReport's projection def over hand-made records
-- and a fixture catalogue, read back as the plain I and K rows ticket #122 writes out, and ns.FieldReportPRows over a
-- hand-made diagnostics buffer.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

local NIGHT = { time = { { 1260, 360 } } } -- 21:00 to 06:00 realm time
local EXTRAVAGANZA = { events = { 301 } }

-- Items: Oily Blackmouth (6358) and Raw Brilliant Smallfish (6291), fish; Winter Squid (13755), fish caught at night
-- in Darkshore; Raw Sunscale Salmon (13760), fish gated by the Extravaganza in The Long Wash; Raw Rockscale Cod
-- (6362), a fish no list carries; Sealed Crate (6352) treasure; Waterlogged Envelope (6292, junk); a Noise item
-- (2934). Areas: Darkshore (148, skill base 55, confirmed) with The Long Wash (453, its own list) and Auberdine
-- (442, no list); The Barrens (17, skill base 100, unconfirmed); Elwynn Forest (12, no skill base). Listed: aura
-- 1280341, event 301.
local function fixture()
	local function item(category, extra)
		local record = { category = category, legend = false, noise = false, removed = false, pool = false }
		for key, value in pairs(extra or {}) do
			record[key] = value
		end
		return record
	end
	local function area(parent, skillBase, skillBaseConfirmed, catches)
		return {
			parent = parent,
			continent = 1,
			skillBase = skillBase,
			skillBaseConfirmed = skillBaseConfirmed or false,
			hasData = #(catches or {}) > 0,
			catches = catches or {},
		}
	end
	return {
		fingerprint = "0123456789abcdef",
		items = {
			[6358] = item("fish"),
			[6291] = item("fish"),
			[13755] = item("fish"),
			[13760] = item("fish"),
			[6362] = item("fish"),
			[6352] = item("treasure"),
			[6292] = item("junk"),
			[2934] = item("other", { noise = true }),
		},
		areas = {
			[148] = area(0, 55, true, {
				{ itemID = 6358, confirmed = true },
				{ itemID = 6291, confirmed = false },
				{ itemID = 6292, confirmed = true },
				{ itemID = 13755, confirmed = true, window = "night", gate = NIGHT, gateConfirmed = true },
			}),
			[453] = area(148, nil, false, {
				{ itemID = 6358, confirmed = true },
				{ itemID = 13760, confirmed = true, window = "event.301", gate = EXTRAVAGANZA, gateConfirmed = false },
			}),
			[442] = area(148),
			[17] = area(0, 100, false, { { itemID = 6358, confirmed = true } }),
			[12] = area(0, nil, false, { { itemID = 6358, confirmed = true } }),
		},
		aliases = {},
		pools = {},
		windows = {},
		events = { [301] = {} },
		fishingSpells = { 7731 },
		auras = { 1280341 },
	}
end

local seq = 0

-- A Cast record as the codec decodes it: caught by default, in Darkshore (148, subzone 0) at realm 08:15 on
-- 11 October 2026 with Fishing 86+25, no event or aura. `fields` overrides any of these (`secretClock` leaves out
-- the realm minute and date, as for a Cast recorded while the realm clock was secret), and `items` lists
-- `{ itemID, quantity }`.
local function cast(items, fields)
	seq = seq + 1
	fields = fields or {}
	local record = {
		seq = seq,
		id = "Player-4618-0A1B2C3D-" .. (1791731000 + seq) .. "-0",
		kind = "cast",
		char = 1,
		time = 1791731000 + seq,
		outcome = fields.outcome or (items and "caught" or "gotAway"),
		conditions = {
			time = 1791731000 + seq,
			minute = not fields.secretClock and (fields.minute or 495) or nil,
			date = not fields.secretClock and { year = 2026, month = fields.month or 10, day = 11, weekday = 1 } or nil,
			zone = fields.zone or 148,
			subzone = fields.subzone or 0,
			skillRank = fields.skillRank == nil and 86 or fields.skillRank or nil,
			skillMod = fields.skillMod or 0,
			events = fields.events or {},
			auras = fields.auras or {},
		},
		items = {},
	}
	for n, entry in ipairs(items or {}) do
		record.items[n] = { n = n, itemID = entry[1], quantity = entry[2] or 1, catchId = record.id .. ":" .. n }
	end
	return record
end

-- A build entry (B1).
local function build(number)
	seq = seq + 1
	return {
		seq = seq,
		id = "Player-4618-0A1B2C3D-" .. seq .. "-0",
		kind = "build",
		char = 1,
		time = seq,
		build = number,
	}
end

-- Applies `records` in order to a fresh state of the report over `data` (the fixture by default) and returns the
-- report and the state.
local function project(records, data)
	local report = ns.NewFieldReport(ns.NewCatalogue(data or fixture()))
	local state = report.reset()
	for _, record in ipairs(records) do
		report.apply(state, record, "rebuild")
	end
	return report, state
end

-- The rows of one kind, sorted by a readable key so a spec can compare them as a list.
local function rowsOf(kind, rows)
	local picked = {}
	for _, row in ipairs(rows) do
		if row.kind == kind then
			picked[#picked + 1] = row
		end
	end
	table.sort(picked, function(a, b)
		return (a.area * 1e7 + (a.item or 0)) * 1e6 + a.build < (b.area * 1e7 + (b.item or 0)) * 1e6 + b.build
	end)
	return picked
end

describe("ns.NewFieldReport's I rows", function()
	it("make a row, with t and m, for an Uncharted Catch (REP-R10 Uncharted, REP-R20)", function()
		local report, state = project({ build(70338), cast({ { 9999, 1 } }, { minute = 497 }) })

		assert.are.same({
			{ kind = "I", area = 148, item = 9999, build = 70338, count = 1, auras = {}, events = {}, t = 495, m = 10 },
		}, rowsOf("I", report.Rows(state)))
	end)

	it("make a row, without t and m, for a known non-Noise item on neither list (REP-R10 unlisted pair)", function()
		local report, state = project({ build(70338), cast({ { 6362, 3 } }, { subzone = 453 }) })

		assert.are.same(
			{ { kind = "I", area = 453, item = 6362, build = 70338, count = 1, auras = {}, events = {} } },
			rowsOf("I", report.Rows(state))
		)
	end)

	it("never come from a Noise item or item 0 (REP-R10)", function()
		local report, state = project({ cast({ { 2934, 1 }, { 0, 1 } }, { auras = { 1280341 } }) })

		assert.are.same({}, report.Rows(state))
		assert.are.equal(0, report.Count(state))
	end)

	it("make a row for an unconfirmed pair (REP-R10)", function()
		local report, state = project({ cast({ { 6291, 1 } }) })

		assert.are.same(
			{ { kind = "I", area = 148, item = 6291, build = 0, count = 1, auras = {}, events = {} } },
			rowsOf("I", report.Rows(state))
		)
	end)

	it("make a row with t and m for a gated entry caught outside its window (REP-R10, REP-R20)", function()
		-- Winter Squid is gated to night in Darkshore; 08:15 is outside it, 23:40 inside it.
		local report, state = project({ cast({ { 13755, 1 } }), cast({ { 13755, 1 } }, { minute = 1420 }) })

		assert.are.same({
			{ kind = "I", area = 148, item = 13755, build = 0, count = 1, auras = {}, events = {}, t = 495, m = 10 },
		}, rowsOf("I", report.Rows(state)))
	end)

	it("make a row with t and m for an unconfirmed window, even caught inside it (REP-R10, REP-R20)", function()
		local report, state =
			project({ cast({ { 13760, 1 } }, { subzone = 453, events = { 301 }, minute = 1007, month = 5 }) })

		assert.are.same({
			{
				kind = "I",
				area = 453,
				item = 13760,
				build = 0,
				count = 1,
				auras = {},
				events = { 301 },
				t = 1005,
				m = 5,
			},
		}, rowsOf("I", report.Rows(state)))
	end)

	it("make none for a confirmed, ungated entry caught with no listed aura or event (REP-R10)", function()
		-- Aura 99 and event 999 aren't on the catalogue's lists (LOG-R56).
		local report, state = project({ cast({ { 6358, 1 } }, { auras = { 99 }, events = { 999 } }) })

		assert.are.same({}, report.Rows(state))
	end)

	it("make a row for any non-Noise item caught with a listed aura or event, junk too (REP-R10, REP-R20)", function()
		local report, state = project({
			cast({ { 6358, 1 }, { 6292, 1 } }, { auras = { 1280341, 99 } }),
			cast({ { 6358, 1 } }, { events = { 301 } }),
		})

		assert.are.same({
			{ kind = "I", area = 148, item = 6292, build = 0, count = 1, auras = { 1280341 }, events = {} },
			{ kind = "I", area = 148, item = 6358, build = 0, count = 1, auras = { 1280341 }, events = {} },
			{ kind = "I", area = 148, item = 6358, build = 0, count = 1, auras = {}, events = { 301 } },
		}, rowsOf("I", report.Rows(state)))
	end)

	it("count Catches on one key in one row, not quantities (REP-R11)", function()
		local report, state = project({ build(70338), cast({ { 6362, 5 } }), cast({ { 6362, 2 } }) })

		assert.are.same(
			{ { kind = "I", area = 148, item = 6362, build = 70338, count = 2, auras = {}, events = {} } },
			report.Rows(state)
		)
		assert.are.equal(1, report.Count(state))
	end)

	it("split the same item by build: the latest B1 before each Cast, else 0 (REP-R4, REP-R11)", function()
		local report, state = project({ cast({ { 6362, 1 } }), build(70338), cast({ { 6362, 1 } }) })

		local rows = rowsOf("I", report.Rows(state))
		assert.are.equal(2, #rows)
		assert.are.same({ 0, 70338 }, { rows[1].build, rows[2].build })
		assert.are.equal(2, report.Count(state))
	end)

	it("split timed rows by 15-minute realm bucket and realm month (REP-R5, REP-R11, REP-R20)", function()
		local report, state = project({
			cast({ { 9999, 1 } }, { minute = 600 }),
			cast({ { 9999, 1 } }, { minute = 614 }),
			cast({ { 9999, 1 } }, { minute = 615 }),
			cast({ { 9999, 1 } }, { minute = 600, month = 11 }),
		})

		local keys = {}
		for _, row in ipairs(report.Rows(state)) do
			keys[#keys + 1] = row.t .. "/" .. row.m .. "x" .. row.count
		end
		table.sort(keys)
		assert.are.same({ "600/10x2", "600/11x1", "615/10x1" }, keys)
	end)

	it("make a timed row without t and m for a Cast with no realm minute, never a made-up time (REP-R20)", function()
		local report, state = project({
			cast({ { 9999, 1 } }, { secretClock = true }),
			cast({ { 9999, 1 } }, { secretClock = true }),
			cast({ { 9999, 1 } }, { minute = 0 }),
		})

		local rows = report.Rows(state)
		table.sort(rows, function(a, b)
			return (a.t or -1) < (b.t or -1)
		end)
		assert.are.same({
			{ kind = "I", area = 148, item = 9999, build = 0, count = 2, auras = {}, events = {} },
			{ kind = "I", area = 148, item = 9999, build = 0, count = 1, auras = {}, events = {}, t = 0, m = 10 },
		}, rows)
	end)

	it("look an item up in its subzone's list, else its zone's, never another subzone's (REP-R10)", function()
		-- Auberdine (442) has no list: Raw Brilliant Smallfish is unconfirmed on Darkshore's. Raw Sunscale Salmon is
		-- only on The Long Wash's list, so in Auberdine it is an unlisted pair.
		local report, state = project({
			cast({ { 6291, 1 } }, { subzone = 442 }),
			cast({ { 6358, 1 } }, { subzone = 442 }),
			cast({ { 13760, 1 } }, { subzone = 442 }),
		})

		assert.are.same({
			{ kind = "I", area = 442, item = 6291, build = 0, count = 1, auras = {}, events = {} },
			{ kind = "I", area = 442, item = 13760, build = 0, count = 1, auras = {}, events = {} },
		}, rowsOf("I", report.Rows(state)))
	end)

	it("leave out a Cast in zone and subzone 0 (REP-R3)", function()
		local report, state = project({ cast({ { 9999, 1 } }, { zone = 0 }) })

		assert.are.same({}, report.Rows(state))
		assert.are.equal(0, report.Count(state))
	end)

	it("name no character and carry no server time (REP-R1, REP-R5)", function()
		local report, state = project({ build(70338), cast({ { 9999, 1 } }) })

		local row = report.Rows(state)[1]
		local keys = {}
		for key in pairs(row) do
			keys[#keys + 1] = key
		end
		table.sort(keys)
		assert.are.same({ "area", "auras", "build", "count", "events", "item", "kind", "m", "t" }, keys)
	end)
end)

describe("ns.NewFieldReport's K rows", function()
	it(
		"give an area with an unconfirmed skill base one row per build with Casts, land and lost only when there is"
			.. " such a Cast (REP-R21)",
		function()
			-- The Barrens' skill base 100 is unconfirmed. On build 0: Oily Blackmouth at 120+5 and 90+0, junk at
			-- 60+0 (no land), Uncharted at 70+0 (not known, no land), got away at 110+0 and 95+10. On 70338: only got
			-- away, at 80+0. On 70400: only caught, at 130+0.
			local report, state = project({
				cast({ { 6358, 1 } }, { zone = 17, skillRank = 120, skillMod = 5 }),
				cast({ { 6358, 1 } }, { zone = 17, skillRank = 90 }),
				cast({ { 6292, 1 } }, { zone = 17, skillRank = 60 }),
				cast({ { 9999, 1 } }, { zone = 17, skillRank = 70 }),
				cast(nil, { zone = 17, skillRank = 110 }),
				cast(nil, { zone = 17, skillRank = 95, skillMod = 10 }),
				build(70338),
				cast(nil, { zone = 17, skillRank = 80 }),
				build(70400),
				cast({ { 6358, 1 } }, { zone = 17, skillRank = 130 }),
			})

			assert.are.same({
				{ kind = "K", area = 17, build = 0, casts = 6, away = 2, land = 90, lost = 110 },
				{ kind = "K", area = 17, build = 70338, casts = 1, away = 1, lost = 80 },
				{ kind = "K", area = 17, build = 70400, casts = 1, away = 0, land = 130 },
			}, rowsOf("K", report.Rows(state)))
		end
	)

	it(
		"give a confirmed skill base rows only once a Cast lands a non-junk item below it, then for every build"
			.. " (REP-R21, REP-R26)",
		function()
			-- Darkshore's skill base 55 is confirmed. Junk and an Uncharted item below it contradict nothing.
			local report, state = project({
				cast({ { 6358, 1 } }, { skillRank = 86 }),
				cast({ { 6292, 1 } }, { skillRank = 40 }),
				cast({ { 9999, 1 } }, { skillRank = 40 }),
				build(70338),
				cast(nil, { skillRank = 50 }),
			})
			assert.are.same({}, rowsOf("K", report.Rows(state)))
			local before = report.Count(state)

			report.apply(state, cast({ { 6358, 1 } }, { skillRank = 50, skillMod = 4 }), "live")

			assert.are.same({
				{ kind = "K", area = 148, build = 0, casts = 3, away = 0, land = 86 },
				{ kind = "K", area = 148, build = 70338, casts = 2, away = 1, land = 54, lost = 50 },
			}, rowsOf("K", report.Rows(state)))
			assert.are.equal(before + 2, report.Count(state), "the count follows the area's rows")
		end
	)

	it(
		"take a subzone Cast's skill base from its zone when the subzone has none, as the zone's row (REP-R21)",
		function()
			local report, state = project({ cast({ { 6358, 1 } }, { subzone = 453, skillRank = 30 }) })

			assert.are.same(
				{ { kind = "K", area = 148, build = 0, casts = 1, away = 0, land = 30 } },
				rowsOf("K", report.Rows(state))
			)
		end
	)

	it("count a Cast with an unknown skill in casts and away only (REP-R21)", function()
		local report, state = project({
			cast({ { 6358, 1 } }, { zone = 17, skillRank = false }),
			cast(nil, { zone = 17, skillRank = false }),
		})

		assert.are.same({ { kind = "K", area = 17, build = 0, casts = 2, away = 1 } }, rowsOf("K", report.Rows(state)))
	end)

	it("give an area with no skill base no row (REP-R21)", function()
		local report, state = project({ cast({ { 6358, 1 } }, { zone = 12, skillRank = 1 }) })

		assert.are.same({}, report.Rows(state))
	end)
end)

describe("ns.FieldReportPRows", function()
	-- The Casts newest first, as CatchLog:Reverse("cast") walks them, noting how many it was asked for.
	local function newestFirst(records)
		local i, walked = #records + 1, { n = 0 }
		return function()
			i = i - 1
			if records[i] then
				walked.n = walked.n + 1
			end
			return records[i]
		end,
			walked
	end

	-- A diagnostics entry (LOG-R81) for `record`, in its zone and subzone.
	local function diagnostic(record, texts, locale)
		return {
			id = record.id,
			zone = record.conditions.zone,
			subzone = record.conditions.subzone,
			locale = locale or "deDE",
			texts = texts,
		}
	end

	-- P rows sorted by area, locale and text.
	local function sorted(rows)
		table.sort(rows, function(a, b)
			return ("%d %s %s"):format(a.area, a.locale, a.text) < ("%d %s %s"):format(b.area, b.locale, b.text)
		end)
		return rows
	end

	it(
		"count a Cast with three hovered texts toward three rows, got-away Casts in casts, and every item caught"
			.. " as total quantities, ascending (REP-R22)",
		function()
			local first = cast({ { 6358, 2 }, { 6292, 1 } }, { subzone = 453 })
			local second = cast(nil, { subzone = 453 })
			local third = cast({ { 6291, 1 }, { 6358, 3 } }, { subzone = 453 })
			local buffer = {
				diagnostic(first, { "Schwarm öliger Schwarzmaulfische", "Fischernetz", "Angelschwimmer" }),
				diagnostic(second, { "Schwarm öliger Schwarzmaulfische" }),
				diagnostic(third, { "Schwarm öliger Schwarzmaulfische" }),
			}

			local rows = sorted(ns.FieldReportPRows(buffer, newestFirst({ first, second, third })))

			local function row(text, casts, items)
				return { kind = "P", area = 453, locale = "deDE", text = text, casts = casts, items = items }
			end
			assert.are.same({
				row("Angelschwimmer", 1, { { item = 6292, count = 1 }, { item = 6358, count = 2 } }),
				row("Fischernetz", 1, { { item = 6292, count = 1 }, { item = 6358, count = 2 } }),
				row("Schwarm öliger Schwarzmaulfische", 3, {
					{ item = 6291, count = 1 },
					{ item = 6292, count = 1 },
					{ item = 6358, count = 5 },
				}),
			}, rows)
		end
	)

	it("keep areas and locales apart, and leave out a Cast in zone and subzone 0 (REP-R3, REP-R22)", function()
		local darkshore = cast({ { 6358, 1 } })
		local english = cast({ { 6358, 1 } })
		local nowhere = cast({ { 6358, 1 } }, { zone = 0 })
		local buffer = {
			diagnostic(darkshore, { "Oily Blackmouth School" }, "enUS"),
			diagnostic(english, { "Oily Blackmouth School" }, "enGB"),
			diagnostic(nowhere, { "Oily Blackmouth School" }, "enUS"),
		}

		local rows = sorted(ns.FieldReportPRows(buffer, newestFirst({ darkshore, english, nowhere })))

		assert.are.same({ "enGB", "enUS" }, { rows[1].locale, rows[2].locale })
		assert.are.equal(2, #rows)
	end)

	it("make no row for a Cast with no hovered text, or one no longer in the log (REP-R22)", function()
		local quiet = cast({ { 6358, 1 } })
		local gone = cast({ { 6358, 1 } })

		local rows =
			ns.FieldReportPRows({ diagnostic(quiet, {}), diagnostic(gone, { "Fischernetz" }) }, newestFirst({ quiet }))

		assert.are.same({}, rows)
	end)

	it("reads the buffer's Casts in one walk back that stops at the oldest one (REP-R22, LOG-R81)", function()
		local older = { cast({ { 6358, 1 } }), cast({ { 6358, 1 } }), cast({ { 6358, 1 } }) }
		local wanted = cast({ { 6358, 1 } })
		local newer = cast({ { 6358, 1 } })
		local casts, walked = newestFirst({ older[1], older[2], older[3], wanted, newer })

		local rows = ns.FieldReportPRows({ diagnostic(wanted, { "Fischernetz" }) }, casts)

		assert.are.equal(1, #rows)
		assert.are.equal(2, walked.n, "the walk stopped at the buffer's oldest Cast")
	end)
end)
