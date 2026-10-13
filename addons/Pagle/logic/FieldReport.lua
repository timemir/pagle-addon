---@class PagleNS
local ns = select(2, ...)

-- What a Field report says, before any text (field-report.md › Which Catches go in I rows, Rows, The projection):
-- pure logic over Catch log records, the catalogue's accessors and ns.MatchesConditions (CORE-R7). The I and K
-- aggregates live in a projection Core runs on the projection machinery (REP-R25, LOG-R78); P rows are built from the
-- diagnostics buffer when asked for (REP-R22). Rows carry realm time and areas only, never a character or a server
-- timestamp (REP-R1, REP-R5).

--- The Field report rules version (field-report.md › Tunables): a change rebuilds the projection (REP-R25).
ns.FIELD_REPORT_RULES_VERSION = 1
--- The width of a row's realm-time bucket, in minutes (field-report.md › Tunables, REP-R20).
ns.FIELD_REPORT_TIME_BUCKET = 15

--- An `I` row as stored (REP-R20): Catches of one item in one report area on one build, with the same listed auras
--- and events and, for gated entries and Uncharted items, the same time bucket and realm month. The rows handed out
--- add `kind = "I"`.
---@class PagleFieldReportI
---@field area integer
---@field item integer
---@field build integer
---@field count integer          -- Catches, not quantities (REP-R11)
---@field auras integer[]        -- the Cast's active listed auras, ascending
---@field events integer[]       -- the Cast's active listed events, ascending
---@field t? integer             -- the realm minute its 15-minute bucket starts at
---@field m? integer             -- the realm month, 1–12

--- What the Field report projection stores (REP-R25): derived data, never report history (REP-R2).
---@class PagleFieldReportState
---@field build integer          -- the latest B1's build so far, 0 before any (REP-R4)
---@field count integer          -- I rows plus the K rows of the areas that qualify now (REP-R26)
---@field I table<string, PagleFieldReportI> -- by row key (REP-R11)
---@field K table<integer, table<integer, PagleFieldReportTally>> -- by skill-base area, then build (REP-R21)

--- One (area, build)'s skill evidence (REP-R21), kept for every area with a skill base whether or not it qualifies:
--- a later Cast can make it qualify.
---@class PagleFieldReportTally
---@field casts integer          -- every Cast, caught and got away
---@field away integer           -- the got-away ones
---@field land? integer          -- the lowest effective skill of a Cast that caught a non-junk, known item
---@field lost? integer          -- the highest effective skill of a got-away Cast

-- The IDs of `active` that `listed` holds, ascending and once each.
---@param active integer[]?
---@param listed integer[]
---@return integer[]
local function listedOf(active, listed)
	local known = {}
	for _, id in ipairs(listed) do
		known[id] = true
	end
	local seen, picked = {}, {}
	for _, id in ipairs(active or {}) do
		if known[id] and not seen[id] then
			seen[id] = true
			picked[#picked + 1] = id
		end
	end
	table.sort(picked)
	return picked
end

-- An item's entry in an area's own catch list, or nil.
---@param area PagleArea?
---@param itemID integer
---@return PagleCatchEntry?
local function entryIn(area, itemID)
	if not area then
		return nil
	end
	for _, entry in ipairs(area.catches) do
		if entry.itemID == itemID then
			return entry
		end
	end
	return nil
end

-- A Cast's report area (REP-R3): its subzone, else its zone; 0 when both are 0. Takes a Cast's conditions or its
-- diagnostics entry, which carry the same two fields.
---@param conditions { zone: integer?, subzone: integer? }
---@return integer
local function reportAreaOf(conditions)
	local subzone = conditions.subzone or 0
	if subzone ~= 0 then
		return subzone
	end
	return conditions.zone or 0
end

--- The Field report's projection (REP-R25) over a catalogue: the def's `reset` and `apply`, and its rows and count
--- read back from a state.
---@param catalogue PagleCatalogue
function ns.NewFieldReport(catalogue)
	local report = {}

	--- A fresh, empty state.
	---@return PagleFieldReportState
	function report.reset()
		return { build = 0, count = 0, I = {}, K = {} }
	end

	-- How many K rows an area has now (REP-R21): one per build it has tallies for, when its skill base is
	-- unconfirmed or contradicted (a Cast landed a non-junk, known item below it), else none.
	---@param state PagleFieldReportState
	---@param areaID integer
	---@return integer
	local function kRowsOf(state, areaID)
		local area, tallies = catalogue.GetArea(areaID), state.K[areaID]
		if not tallies or not area or not area.skillBase then
			return 0
		end
		local builds, lowest = 0, nil
		for _, tally in pairs(tallies) do
			builds = builds + 1
			if tally.land and (not lowest or tally.land < lowest) then
				lowest = tally.land
			end
		end
		if area.skillBaseConfirmed == false or (lowest and lowest < area.skillBase) then
			return builds
		end
		return 0
	end

	-- The area whose skill base a Cast is judged by (REP-R21): its report area's, else its zone's; nil when neither
	-- has one.
	---@param conditions ConditionsSnapshot
	---@param area integer
	---@return integer?
	local function skillBaseAreaOf(conditions, area)
		for _, areaID in ipairs({ area, conditions.zone or 0 }) do
			local record = catalogue.GetArea(areaID)
			if record and record.skillBase then
				return areaID
			end
		end
		return nil
	end

	-- Adds a Cast to its skill-base area's tally for the current build (REP-R21), and moves the count by the K rows
	-- that area gains (REP-R26).
	---@param state PagleFieldReportState
	---@param cast PagleCast
	---@param area integer
	local function tallySkill(state, cast, area)
		local conditions = cast.conditions
		local areaID = skillBaseAreaOf(conditions, area)
		if not areaID then
			return
		end
		local before = kRowsOf(state, areaID)
		local tallies = state.K[areaID] or {}
		state.K[areaID] = tallies
		local tally = tallies[state.build] or { casts = 0, away = 0 }
		tallies[state.build] = tally
		tally.casts = tally.casts + 1
		-- Effective skill is rank + modifier; with either unknown (secret) it can't be told (LOG-R48).
		local rank, mod = conditions.skillRank, conditions.skillMod
		local skill = (rank and rank ~= 0 and mod) and rank + mod or nil
		if cast.outcome == "gotAway" then
			tally.away = tally.away + 1
			if skill and (not tally.lost or skill > tally.lost) then
				tally.lost = skill
			end
		elseif skill and (not tally.land or skill < tally.land) then
			for _, catch in ipairs(cast.items) do
				local item = catalogue.GetItem(catch.itemID)
				if item and item.category ~= "junk" then
					tally.land = skill
					break
				end
			end
		end
		state.count = state.count + kRowsOf(state, areaID) - before
	end

	-- Whether a Catch qualifies for an I row (REP-R10), and whether its row carries t and m (REP-R20).
	---@param cast PagleCast
	---@param area integer
	---@param itemID integer
	---@param listedActive boolean
	---@return boolean qualifies
	---@return boolean timed
	local function qualifies(cast, area, itemID, listedActive)
		local item = catalogue.GetItem(itemID)
		if item == nil then
			return true, true -- Uncharted
		end
		if item.noise then
			return false, false
		end
		local conditions = cast.conditions
		local entry = entryIn(catalogue.GetArea(area), itemID)
			or entryIn(catalogue.GetArea(conditions.zone or 0), itemID)
		if entry == nil then
			return true, false -- unlisted pair
		end
		local gate = entry.gate
		if gate then
			local outside = not ns.MatchesConditions(gate, conditions)
			return outside or entry.gateConfirmed == false or entry.confirmed == false or listedActive, true
		end
		return entry.confirmed == false or listedActive, false
	end

	-- Counts each qualifying Catch of a caught Cast in its one I row (REP-R10, REP-R11).
	---@param state PagleFieldReportState
	---@param cast PagleCast
	---@param area integer
	local function countCatches(state, cast, area)
		local conditions = cast.conditions
		local auras = listedOf(conditions.auras, catalogue.GetFishingAuras())
		local events = listedOf(conditions.events, catalogue.GetEventIDs())
		local listedActive = #auras > 0 or #events > 0
		for _, catch in ipairs(cast.items) do
			local itemID = catch.itemID
			local qualified, timed = false, false
			if itemID ~= 0 then
				qualified, timed = qualifies(cast, area, itemID, listedActive)
			end
			if qualified then
				local t, m
				if timed then
					local minute = conditions.minute or 0
					t = minute - minute % ns.FIELD_REPORT_TIME_BUCKET
					m = conditions.date and conditions.date.month
				end
				local key = table.concat({
					area,
					itemID,
					state.build,
					table.concat(auras, ","),
					table.concat(events, ","),
					t or "",
					m or "",
				}, "|")
				local row = state.I[key]
				if row then
					row.count = row.count + 1
				else
					state.I[key] = {
						area = area,
						item = itemID,
						build = state.build,
						count = 1,
						auras = auras,
						events = events,
						t = t,
						m = m,
					}
					state.count = state.count + 1
				end
			end
		end
	end

	--- Applies one Catch log record (REP-R4, REP-R10–R12). The mode changes nothing: the report raises no moments.
	---@param state PagleFieldReportState
	---@param record PagleRecord
	function report.apply(state, record)
		if record.kind == "build" then
			---@cast record PagleBuild
			state.build = record.build
		elseif record.kind == "cast" then
			---@cast record PagleCast
			local area = reportAreaOf(record.conditions)
			if area ~= 0 then
				if record.outcome == "caught" then
					countCatches(state, record, area)
				end
				tallySkill(state, record, area)
			end
		end
	end

	--- The I and K rows a state holds now, as fresh plain tables, unsorted (REP-R20, REP-R21).
	---@param state PagleFieldReportState
	---@return table[]
	function report.Rows(state)
		local rows = {}
		for _, stored in pairs(state.I) do
			local auras, events = {}, {}
			for i, id in ipairs(stored.auras) do
				auras[i] = id
			end
			for i, id in ipairs(stored.events) do
				events[i] = id
			end
			rows[#rows + 1] = {
				kind = "I",
				area = stored.area,
				item = stored.item,
				build = stored.build,
				count = stored.count,
				auras = auras,
				events = events,
				t = stored.t,
				m = stored.m,
			}
		end
		-- Which areas qualify is decided now: a Cast after the tallies were kept can contradict a skill base.
		for areaID, tallies in pairs(state.K) do
			if kRowsOf(state, areaID) > 0 then
				for build, tally in pairs(tallies) do
					rows[#rows + 1] = {
						kind = "K",
						area = areaID,
						build = build,
						casts = tally.casts,
						away = tally.away,
						land = tally.land,
						lost = tally.lost,
					}
				end
			end
		end
		return rows
	end

	--- How many I and K rows a state holds now (REP-R26). While the projection rebuilds, Core reads it from the
	--- last stored state.
	---@param state PagleFieldReportState
	---@return integer
	function report.Count(state)
		return state.count
	end

	return report
end

--- What Core's Field report is fed (adapter/FieldReport.lua, and FakePagle's part).
---@class PagleFieldReportOptions
---@field projections PagleProjections   -- Core's projection machinery
---@field db table                         -- PagleDB.global.projections.fieldReport (REP-R25)
---@field catalogue PagleCatalogue
---@field iterate fun(afterSeq: integer?): fun(): PagleRecord? -- the log's records (Pagle.IterateCatches)
---@field buffer fun(): PagleDiagnostic[] -- PagleDB.global.diagnostics now (LOG-R81)
---@field casts fun(): fun(): PagleCast?  -- a walk over the log's Casts, newest first

--- Binds the Field report projection on Core's machinery (REP-R25, LOG-R78), with the Field report rules version and
--- no extraFingerprint, and returns its two readers.
---@param options PagleFieldReportOptions
---@return fun(): table[]? rows every I, K and P row, unsorted; nil while the projection is updating (REP-R20–R22)
---@return fun(): integer count the I and K rows stored, plus the P rows built now (REP-R26)
function ns.AddFieldReport(options)
	local report = ns.NewFieldReport(options.catalogue)
	local db = options.db
	local projection = ns.AddCoreProjection(options.projections, {
		db = db,
		rulesVersion = ns.FIELD_REPORT_RULES_VERSION,
		reset = report.reset,
		apply = report.apply,
	}, options.iterate)

	local function pRows()
		local buffer = options.buffer()
		return ns.FieldReportPRows(type(buffer) == "table" and buffer or {}, options.casts())
	end

	local function rows()
		local state = projection:GetState()
		if projection:IsUpdating() or not state then
			return nil
		end
		local all = report.Rows(state)
		for _, row in ipairs(pRows()) do
			all[#all + 1] = row
		end
		return all
	end

	-- While it rebuilds, the state being built isn't stored yet: the last stored one still is (LOG-R72).
	local function count()
		local stored = db.projection
		local storedCount = type(stored) == "table" and tonumber(report.Count(stored)) or 0
		return storedCount + #pRows()
	end

	return rows, count
end

-- The server time in an entry ID (LOG-R13: <character GUID>-<time>-<tie>), or nil.
---@param id string
---@return integer?
local function timeOf(id)
	return tonumber(string.match(id, "%-(%d+)%-%d+$"))
end

--- The P rows (REP-R22), built now from the diagnostics buffer (LOG-R81) and never stored: one per report area ×
--- locale × hovered text, counting each buffered Cast once toward each of its texts, got-away Casts included, with
--- the total quantity of every item caught on those Casts, junk too, ascending by item ID. Item 0 (secret) is left
--- out, as everywhere in the report. A buffered Cast in zone and subzone 0 (REP-R3), or no longer in the log, counts
--- for nothing. The buffer holds entry IDs only, so the Casts are read in one walk back from the log's end, which
--- stops once it has them all or has passed the oldest.
---@param buffer PagleDiagnostic[] PagleDB.global.diagnostics; it may hold anything (LOG-R82)
---@param casts fun(): PagleCast? the log's Casts, newest first (CatchLog:Reverse("cast"))
---@return table[] rows `{ kind = "P", area, locale, text, casts, items = { { item, count }, … } }`, unsorted
function ns.FieldReportPRows(buffer, casts)
	local wanted, missing, oldest = {}, 0, math.huge
	for _, entry in ipairs(buffer) do
		local time = type(entry) == "table" and type(entry.id) == "string" and timeOf(entry.id) or nil
		local texts = time and entry.texts
		if time and type(texts) == "table" and #texts > 0 and reportAreaOf(entry) ~= 0 and not wanted[entry.id] then
			wanted[entry.id] = false
			missing = missing + 1
			oldest = math.min(oldest, time)
		end
	end
	while missing > 0 do
		local cast = casts()
		if cast == nil or cast.time < oldest then
			break
		end
		if wanted[cast.id] == false then
			wanted[cast.id] = cast
			missing = missing - 1
		end
	end

	local rows, byKey = {}, {}
	for _, entry in ipairs(buffer) do
		local cast = type(entry) == "table" and wanted[entry.id]
		if cast then
			wanted[entry.id] = nil -- a Cast buffered twice counts once
			local area, seen = reportAreaOf(entry), {}
			for _, text in ipairs(entry.texts) do
				local key = area .. "|" .. tostring(entry.locale) .. "|" .. tostring(text)
				if not seen[key] then
					seen[key] = true
					local row = byKey[key]
					if not row then
						row = { kind = "P", area = area, locale = entry.locale, text = text, casts = 0, totals = {} }
						byKey[key] = row
						rows[#rows + 1] = row
					end
					row.casts = row.casts + 1
					for _, catch in ipairs(cast.items) do
						if catch.itemID ~= 0 then
							row.totals[catch.itemID] = (row.totals[catch.itemID] or 0) + catch.quantity
						end
					end
				end
			end
		end
	end
	for _, row in ipairs(rows) do
		local items = {}
		for item, count in pairs(row.totals) do
			items[#items + 1] = { item = item, count = count }
		end
		table.sort(items, function(a, b)
			return a.item < b.item
		end)
		row.items, row.totals = items, nil
	end
	return rows
end
