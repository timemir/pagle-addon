-- The Field report's rows and count on the client (REP-R25, REP-R26, REP-R91, LOG-R78): Core's own projection in
-- PagleDB.global.projections.fieldReport, built at the first PLAYER_ENTERING_WORLD over a saved log and the generated
-- catalogue, and the P rows read from PagleDB.global.diagnostics.

local LOG_ID = "3f9a2c1e7b0d4a65" -- savedLog's
local GUID = "Player-4618-0A1B2C3D" -- savedLog's Ada
local UNCHARTED = 9999 -- in no catalogue
local FIRST = SERVER_TIME - 4000 -- the history's Casts are at FIRST + 1, + 2, …

-- Core over a saved log holding `entries` and PagleDB `saved`, logged in and in the world.
local function core(entries, saved)
	return enterWorld(loadCore(entries, saved))
end

-- A Cast in Darkshore catching `itemID`, recorded live now.
local function liveCast(loaded, itemID)
	loaded.ns.projections:Live(loaded.ns.catchLog:Append({
		kind = "cast",
		char = 1,
		time = SERVER_TIME,
		outcome = "caught",
		conditions = {
			minute = 600,
			zone = 148,
			subzone = 0,
			skillRank = 86,
			skillMod = 25,
			events = {},
			auras = {},
		},
		items = { { itemID = itemID, quantity = 1 } },
	}))
end

-- The I rows of one item.
local function iRows(rows, item)
	local picked = {}
	for _, row in ipairs(rows) do
		if row.kind == "I" and row.item == item then
			picked[#picked + 1] = row
		end
	end
	return picked
end

describe("the Field report projection", function()
	it(
		"is Core's own, bound to PagleDB.global.projections.fieldReport with rules version 2 and the content"
			.. " fingerprint alone (REP-R25, LOG-R70, LOG-R78)",
		function()
			local loaded = core(unchartedHistory(2, FIRST, UNCHARTED))
			local Pagle = loaded.env.Pagle

			local db = loaded.env.PagleDB.global.projections.fieldReport
			assert.are.equal(2, db.rulesVersion) -- field-report.md › Tunables
			assert.are.equal(Pagle.CONTENT_FINGERPRINT, db.fingerprint)
			assert.are.equal(LOG_ID, db.logId)
			assert.are.equal(#loaded.env.PagleLog.entries, db.lastSeq, "up to date, login's Skill Reading too")
		end
	)

	it("yields the I row of two Uncharted Catches on one build, with the count (REP-R11, REP-R20, REP-R26)", function()
		local loaded = core(unchartedHistory(2, FIRST, UNCHARTED))

		local rows = assert(loaded.ns.FieldReportRows())

		assert.are.same({
			{
				kind = "I",
				area = 148,
				item = UNCHARTED,
				build = 70338,
				count = 2,
				auras = {},
				events = {},
				t = 480,
				m = 10,
			},
		}, iRows(rows, UNCHARTED))
		assert.are.equal(#rows, loaded.env.Pagle.GetFieldReportCount())
	end)

	it("takes a Cast recorded later live, and the count follows (LOG-R73, REP-R26)", function()
		local loaded = core(unchartedHistory(1, FIRST, UNCHARTED))
		local before = loaded.env.Pagle.GetFieldReportCount()

		liveCast(loaded, 9998)

		assert.are.equal(1, #iRows(loaded.ns.FieldReportRows(), 9998))
		assert.are.equal(before + 1, loaded.env.Pagle.GetFieldReportCount())
	end)

	it(
		"rebuilds on a changed content fingerprint, giving no rows and the last stored count plus the P rows"
			.. " meanwhile (REP-R26, REP-R91, LOG-R72)",
		function()
			local saved = {
				global = {
					projections = {
						fieldReport = {
							projection = { build = 0, count = 7, I = {}, K = {} },
							lastSeq = 601,
							logId = LOG_ID,
							fingerprint = "an older release",
							rulesVersion = 2,
						},
					},
					diagnostics = {
						{
							id = GUID .. "-" .. FIRST + 600 .. "-0",
							zone = 148,
							subzone = 0,
							locale = "enUS",
							texts = { "School" },
						},
					},
				},
			}
			local loaded = core(unchartedHistory(600, FIRST, UNCHARTED), saved)
			local Pagle = loaded.env.Pagle

			assert.is_nil(loaded.ns.FieldReportRows()) -- no rows while the projection rebuilds (REP-R42)
			assert.are.equal(8, Pagle.GetFieldReportCount())

			loaded.client.runTimers() -- the entries
			loaded.client.runTimers() -- done, in a frame of its own

			local rows = assert(loaded.ns.FieldReportRows())
			assert.are.equal(600, iRows(rows, UNCHARTED)[1].count)
			assert.are.equal(#rows, Pagle.GetFieldReportCount())
			assert.are.equal(Pagle.CONTENT_FINGERPRINT, loaded.env.PagleDB.global.projections.fieldReport.fingerprint)
		end
	)
end)

describe("the Field report projection, beside a Module's", function()
	it("runs ahead of it, so the Module's live apply already sees the Catch counted (LOG-R78)", function()
		local loaded = loadCore(unchartedHistory(1, FIRST, UNCHARTED))
		local Pagle = loaded.env.Pagle
		local M = Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
		local seen = {}
		M:NewProjection({
			db = {},
			rulesVersion = 1,
			reset = function()
				return {}
			end,
			apply = function(_, record, mode)
				if mode == "live" and record.kind == "cast" then
					seen[#seen + 1] = Pagle.GetFieldReportCount()
				end
			end,
		})
		enterWorld(loaded)
		local before = Pagle.GetFieldReportCount()

		liveCast(loaded, 9998)

		assert.are.same({ before + 1 }, seen)
	end)
end)

describe("Pagle.GetFieldReportCount", function()
	it("adds the P rows built from the diagnostics buffer now, never stored (REP-R22, REP-R26)", function()
		local saved = {
			global = {
				diagnostics = {
					{
						id = GUID .. "-" .. FIRST + 1 .. "-0",
						zone = 148,
						subzone = 0,
						locale = "enUS",
						texts = { "A", "B" },
					},
				},
			},
		}
		local loaded = core(unchartedHistory(1, FIRST, UNCHARTED), saved)

		local rows = loaded.ns.FieldReportRows()
		local p = {}
		for _, row in ipairs(rows) do
			if row.kind == "P" then
				p[#p + 1] = row.text
			end
		end
		table.sort(p)
		assert.are.same({ "A", "B" }, p)
		assert.are.equal(#rows, loaded.env.Pagle.GetFieldReportCount())
		assert.is_nil(loaded.env.PagleDB.global.projections.fieldReport.projection.P)
	end)
end)
