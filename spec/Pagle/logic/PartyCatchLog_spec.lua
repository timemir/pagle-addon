-- The Party Catch entry and record (LOG-R115–R119), who reads it (LOG-R117), and the projection machinery's opt-in
-- and filter (LOG-R114), through ns.OpenCatchLog and ns.NewProjections, the logic/ seams Core's adapter wraps. From
-- 1.6 (pagle-2026j, #644). As in CatchLog_spec.lua, each entry string here stands next to the record it makes.

local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
local ns = loaded.ns

local ADA = "Player-4618-0A1B2C3D"

-- The copy of a groupmate's Cast (LOG-R115): its time and tie, then its C1 fields from minute to items. Catalogue's
-- example: a second before the receiver's G1, at realm 08:14 in The Long Wash (148/453), skill 120, no lure.
local COPY = "1791731748|0|494|148|453|120|0||||6358x1"
local G1 = "G1|1|1791731749|0|" .. COPY

-- A PagleLog holding Ada and these entries.
local function adaLog(entries)
	return savedLog(entries, 4, {
		{ guid = ADA, name = "Ada", classID = 1, raceID = 1, faction = "Alliance", realmID = 4618 },
	})
end

local function cast(time)
	return ("C1|1|%d|0|c|494|1439|1|148|453|86|25|263|||6358x1"):format(time)
end

-- Every record `iterate` yields, in order.
local function all(iterate)
	local list = {}
	for record in iterate do
		list[#list + 1] = record
	end
	return list
end

local function kinds(list)
	local out = {}
	for i, record in ipairs(list) do
		out[i] = record.kind
	end
	return out
end

describe("the Party Catch entry (G1)", function()
	it("is appended as the receiver's header and the copy, byte for byte, with no GUID (LOG-R115)", function()
		local catchLog = ns.OpenCatchLog(adaLog(), {})

		local record = catchLog:Append({ kind = "party", char = 1, time = 1791731749, copy = COPY })

		assert.are.same({ G1 }, logEntries(catchLog.data))
		assert.are.equal("party", record.kind)
		assert.is_nil(logEntries(catchLog.data)[1]:find("Player", 1, true))
	end)

	it("keeps the copy's lists exactly as the groupmate wrote them (LOG-R115)", function()
		local catchLog = ns.OpenCatchLog(adaLog(), {})
		local copy = "1791731748|0|1439|148|453|86|-25|263|5,9|11,40,41|6358x1,0x1,6358x2"

		catchLog:Append({ kind = "party", char = 1, time = 1791731749, copy = copy })

		assert.are.same({ "G1|1|1791731749|0|" .. copy }, logEntries(catchLog.data))
	end)

	it("takes a tie after a Cast of the same second, as any entry does (LOG-R12, LOG-R115)", function()
		local catchLog = ns.OpenCatchLog(adaLog({ cast(1791731749) }), {})

		local record = catchLog:Append({ kind = "party", char = 1, time = 1791731749, copy = COPY })

		assert.are.equal(ADA .. "-1791731749-1", record.id)
		assert.are.equal("G1|1|1791731749|1|" .. COPY, logEntries(catchLog.data)[2])
	end)

	it("refuses a copy that isn't one, appending nothing (LOG-R113 item 3, LOG-R115)", function()
		local catchLog = ns.OpenCatchLog(adaLog(), {})
		for _, copy in ipairs({
			"1791731748|0|494|0|453|120|0||||6358x1", -- zone 0
			"1791731748|0|494|148|453|120|0||||0x1", -- only item 0
			"1791731748|0|494|148|453|120|0||||", -- no item
			"Player-4618-0B000000|1791731748|0|494|148|453|120|0||||6358x1", -- a GUID
			"1791731748|0|494|148|453|120|0||||6358x1\n", -- a line feed (LOG-R101)
			"1791731748|0|494|148|453|120|0|||9,5|6358x1", -- auras out of order
		}) do
			assert.has_error(function()
				catchLog:Append({ kind = "party", char = 1, time = 1791731749, copy = copy })
			end)
		end
		assert.are.same({}, logEntries(catchLog.data))
	end)

	it("is an additive kind: format 4 stays, and a log holding one opens as it is (LOG-R119)", function()
		local catchLog = ns.OpenCatchLog(adaLog({ cast(1791731700), G1 }), { decodeErrors = 0 })
		assert.are.equal(4, catchLog.data.format)
		assert.are.equal(2, catchLog:Count())
		assert.is_nil(ns.CanonicalRecordProblem(G1))
	end)

	it("drafts the record an append would make, appending nothing (LOG-R114)", function()
		local catchLog = ns.OpenCatchLog(adaLog({ cast(1791731749) }), {})

		local draft = catchLog:Draft({ kind = "party", char = 1, time = 1791731749, copy = COPY })

		assert.are.equal(1, catchLog:Count())
		assert.are.equal(2, draft.seq)
		assert.are.equal(ADA .. "-1791731749-1", draft.id)
		assert.are.equal("party", draft.kind)
	end)
end)

describe("the Party Catch record", function()
	it(
		"carries the header, the copied time and tie, the conditions built from the copy and the items with their"
			.. " Party Catch IDs (LOG-R116)",
		function()
			local catchLog = ns.OpenCatchLog(adaLog({ G1 }), {}, nil, ns.CatalogueItem)

			local record = all(catchLog:Iterate(0, "Hunts", true))[1]

			assert.are.equal("party", record.kind)
			assert.are.equal(1, record.seq)
			assert.are.equal(ADA .. "-1791731749-0", record.id)
			assert.are.equal(1, record.char)
			assert.are.equal(1791731749, record.time)
			assert.are.equal(1791731748, record.catchTime)
			assert.are.equal(0, record.catchTie)
			local c = record.conditions
			assert.are.equal(1791731748, c.time)
			assert.are.equal(494, c.minute)
			assert.are.same(ns.RealmDate(1791731748, 494), c.date)
			assert.are.same({ 148, 453, 120, 0 }, { c.zone, c.subzone, c.skillRank, c.skillMod })
			assert.is_nil(c.lure)
			assert.is_nil(c.uiMap)
			assert.is_nil(c.instance)
			assert.are.same({}, c.events)
			assert.are.same({}, c.auras)
			assert.are.same(
				{ { n = 1, itemID = 6358, quantity = 1, catchId = ADA .. "-1791731749-0:1" } },
				record.items
			)
		end
	)

	it("has no size, no variety and no Session: it is no Catch of the Angler's (LOG-R116, LOG-R118)", function()
		local catchLog = ns.OpenCatchLog(adaLog({ cast(1791731700), G1, cast(1791731800) }), {}, nil, ns.CatalogueItem)

		local list = all(catchLog:Iterate(0, "Hunts", true))

		assert.are.same({ "cast", "party", "cast" }, kinds(list))
		local party = list[2]
		assert.is_nil(party.session)
		assert.is_nil(party.items[1].size)
		assert.is_nil(party.items[1].variety)
		-- The Casts around it make one Session, as if it weren't there.
		assert.are.equal(list[1].session, list[3].session)
	end)

	it("is never counted among the earlier Catches of a Simulated Size (LOG-R118, LOG-R100)", function()
		local function sizeAfter(entries)
			local catchLog = ns.OpenCatchLog(adaLog(entries), {}, nil, ns.CatalogueItem)
			local list = all(catchLog:Iterate(0))
			return list[#list].items[1].size
		end
		local withParty = sizeAfter({ G1, G1:gsub("1791731749", "1791731750", 1), cast(1791731800) })
		local without = sizeAfter({ cast(1791731800) })
		assert.are.same(without, withParty)
	end)

	it("carries neither the groupmate's name nor the source ID when read back (LOG-R116, LOG-R120)", function()
		local catchLog = ns.OpenCatchLog(adaLog({ G1 }), {})
		local record = all(catchLog:Iterate(0, "Hunts", true))[1]
		assert.is_nil(record.name)
		assert.is_nil(record.sourceId)
	end)
end)

describe("who reads Party Catches", function()
	it("is never Pagle.IterateCatches, nor a Module that doesn't take them, nor Core's own (LOG-R117)", function()
		local catchLog = ns.OpenCatchLog(adaLog({ cast(1791731700), G1, cast(1791731800) }), { decodeErrors = 0 })

		assert.are.same({ "cast", "cast" }, kinds(all(catchLog:Iterate(0))))
		assert.are.same({ "cast", "cast" }, kinds(all(catchLog:Iterate(0, "Ledger"))))
		assert.are.same({ "cast", "cast" }, kinds(all(catchLog:Iterate(0, ns.COMPANION_READER))))
		assert.are.same({ "cast", "party", "cast" }, kinds(all(catchLog:Iterate(0, "Hunts", true))))
		-- Skipped by a reader, never counted as an entry the codec can't read (LOG-R16).
		assert.are.equal(0, catchLog.global.decodeErrors)
	end)

	it("finds the newest Cast without sizing it, past a later Party Catch (LOG-R113 item 7)", function()
		local catchLog = ns.OpenCatchLog(
			adaLog({ cast(1791731700), "C1|1|1791731710|0|g|494|1439|1|12|0|86|25||||", G1 }),
			{},
			nil,
			ns.CatalogueItem
		)

		local last = catchLog:Last("cast")

		assert.are.equal(1791731710, last.time)
		assert.are.equal("gotAway", last.outcome)
		assert.are.equal(12, last.conditions.zone)
		assert.is_nil(ns.OpenCatchLog(adaLog({ G1 }), {}):Last("cast"))
	end)
end)

-- A machinery over `catchLog`, every catch-up at once, Module errors raised.
local function machinery(catchLog)
	return ns.NewProjections({
		length = function()
			return catchLog.data.count
		end,
		logId = function()
			return catchLog.data.logId
		end,
		fingerprint = function()
			return "fp"
		end,
		clock = function()
			return 0
		end,
		nextFrame = function() end,
		call = function(fn, ...)
			return fn(...)
		end,
		syncLimit = math.huge,
	})
end

-- A projection def noting each record it's applied, as "<kind> <mode>".
local function noting(extra)
	local seen = {}
	local def = {
		db = {},
		rulesVersion = 1,
		reset = function()
			return {}
		end,
		apply = function(_, record, mode)
			seen[#seen + 1] = record.kind .. " " .. mode
		end,
	}
	for key, value in pairs(extra or {}) do
		def[key] = value
	end
	return def, seen
end

-- Adds `def` as `module`'s projection, its records read as M:IterateCatches reads them (LOG-R42, LOG-R117).
local function add(projections, catchLog, def, module)
	return projections:Add(def, function(afterSeq)
		return catchLog:Iterate(afterSeq, module, projections:TakesPartyCatches(module))
	end, module)
end

describe("projections and Party Catches", function()
	it("replays and rebuilds Party Catches only to a projection that takes them (LOG-R117, LOG-R122)", function()
		local catchLog = ns.OpenCatchLog(adaLog({ cast(1791731700), G1 }), {})
		local projections = machinery(catchLog)
		local takes, takesSeen = noting({ partyCatches = true })
		local ignores, ignoresSeen = noting()
		add(projections, catchLog, takes, "Hunts")
		add(projections, catchLog, ignores, "Ledger")

		projections:Start(2)

		assert.are.same({ "cast rebuild", "party rebuild" }, takesSeen)
		assert.are.same({ "cast rebuild" }, ignoresSeen)
		assert.are.equal(2, ignores.db.lastSeq)
		assert.is_true(projections:TakesPartyCatches("Hunts"))
		assert.is_false(projections:TakesPartyCatches("Ledger"))
	end)

	it(
		"hands a live Party Catch only to a projection that takes it; the others pass it by (LOG-R115, LOG-R117)",
		function()
			local catchLog = ns.OpenCatchLog(adaLog({ cast(1791731700) }), {})
			local projections = machinery(catchLog)
			local takes, takesSeen = noting({ partyCatches = true })
			local ignores, ignoresSeen = noting()
			add(projections, catchLog, takes, "Hunts")
			add(projections, catchLog, ignores, "Ledger")
			projections:Start(1)

			local record = catchLog:Append({ kind = "party", char = 1, time = 1791731749, copy = COPY })
			projections:Live(record)

			assert.are.same({ "cast rebuild", "party live" }, takesSeen)
			assert.are.same({ "cast rebuild" }, ignoresSeen)
			assert.are.equal(2, ignores.db.lastSeq)
		end
	)

	it("refuses a def whose partyCatches or wantsPartyCatch has the wrong type (Projection definition)", function()
		local catchLog = ns.OpenCatchLog(adaLog(), {})
		local projections = machinery(catchLog)
		local projection, problem = projections:Add(noting({ partyCatches = "yes" }), function() end, "Hunts")
		assert.is_nil(projection)
		assert.matches("partyCatches", problem)
		projection, problem = projections:Add(noting({ wantsPartyCatch = true }), function() end, "Hunts")
		assert.is_nil(projection)
		assert.matches("wantsPartyCatch", problem)
	end)

	describe("the Hunts filter", function()
		local function draft(catchLog)
			return catchLog:Draft({ kind = "party", char = 1, time = 1791731749, copy = COPY })
		end

		it("logs nothing when no projection takes Party Catches (LOG-R114, LOG-R122)", function()
			local catchLog = ns.OpenCatchLog(adaLog({ cast(1791731700) }), {})
			local projections = machinery(catchLog)
			add(projections, catchLog, noting(), "Ledger")
			projections:Start(1)
			assert.is_false(projections:WantsPartyCatch(draft(catchLog)))
		end)

		it("asks each projection that takes them, with the record the entry would make (LOG-R114)", function()
			local catchLog = ns.OpenCatchLog(adaLog({ cast(1791731700) }), {})
			local projections = machinery(catchLog)
			local asked = {}
			local answer = false
			add(
				projections,
				catchLog,
				noting({
					partyCatches = true,
					wantsPartyCatch = function(state, record)
						asked[#asked + 1] = { state = state, record = record }
						return answer
					end,
				}),
				"Hunts"
			)
			projections:Start(1)

			assert.is_false(projections:WantsPartyCatch(draft(catchLog)))
			answer = true
			assert.is_true(projections:WantsPartyCatch(draft(catchLog)))
			assert.are.equal(2, #asked)
			assert.are.equal("party", asked[1].record.kind)
			assert.are.equal(1791731748, asked[1].record.catchTime)
			assert.is_table(asked[1].state)
		end)

		it("logs every Party Catch while a projection that takes them is updating (LOG-R114)", function()
			local catchLog = ns.OpenCatchLog(adaLog({ cast(1791731700) }), {})
			local projections = machinery(catchLog)
			local asked = 0
			add(
				projections,
				catchLog,
				noting({
					partyCatches = true,
					wantsPartyCatch = function()
						asked = asked + 1
						return false
					end,
				}),
				"Hunts"
			)
			-- Before login step 3, nothing is caught up.
			assert.is_true(projections:WantsPartyCatch(draft(catchLog)))
			assert.are.equal(0, asked)
		end)

		it("takes every Party Catch for a projection that takes them with no filter (LOG-R114)", function()
			local catchLog = ns.OpenCatchLog(adaLog({ cast(1791731700) }), {})
			local projections = machinery(catchLog)
			add(projections, catchLog, noting({ partyCatches = true }), "Hunts")
			projections:Start(1)
			assert.is_true(projections:WantsPartyCatch(draft(catchLog)))
		end)
	end)
end)
