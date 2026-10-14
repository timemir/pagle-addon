-- M:RaiseMoment as Core runs it, through the real TOC (announcements.md › Moments and the ladder, › One Announcement
-- per Cast; ADR 0007): Modules' projections raise moments on a live Cast, and Core hands one Announcement per Cast
-- to the display (ns.lanes, #84's) on a later frame, and each moment to the summary (ns.summary, #86's).

-- Core over a saved log holding `entries`, with the Ledger and Hunts installed. What Core hands the display and the
-- summary is in `seen.shown` and `seen.summarized`; errors reaching geterrorhandler() in `seen.reported`.
local function coreSeeing(entries)
	local loaded = loadCore(entries)
	local seen = { shown = {}, summarized = {}, reported = {} }
	function loaded.ns.lanes.Push(_, announcement)
		seen.shown[#seen.shown + 1] = announcement
	end
	function loaded.ns.summary.Add(_, moment)
		seen.summarized[#seen.summarized + 1] = moment
	end
	loaded.env.geterrorhandler = function()
		return function(err)
			seen.reported[#seen.reported + 1] = tostring(err)
		end
	end
	return loaded, seen
end

-- Registers a Module whose projection raises `raise(record)`'s moment for each entry it applies, in any mode.
local function moduleRaising(loaded, name, order, raise)
	local M = loaded.env.Pagle.RegisterModule({ name = name, title = name, order = order })
	M:NewProjection({
		db = {},
		rulesVersion = 1,
		reset = function()
			return {}
		end,
		apply = function(_, record)
			if record.kind == "cast" then
				M:RaiseMoment(raise(record))
			end
		end,
	})
	return M
end

describe("M:RaiseMoment", function()
	it(
		"merges two Modules' moments for a live Cast into one Announcement on the next frame (ANN-R10, ANN-R11,"
			.. " LOG-R73)",
		function()
			local loaded, seen = coreSeeing(history(1, 1791731000))
			moduleRaising(loaded, "Hunts", 20, function(record)
				return { rung = "toast.high", kind = "huntCompleted", title = "Hunt completed", cast = record.id }
			end)
			moduleRaising(loaded, "Ledger", 10, function(record)
				return { rung = "toast", kind = "newSpecies", title = "New Species", stamp = "New!", cast = record.id }
			end)
			enterWorld(loaded)
			loaded.client.runTimers()

			catchOne(loaded)
			assert.are.same({}, seen.shown)
			loaded.client.runTimers()

			assert.are.equal(1, #seen.shown)
			local shown = seen.shown[1]
			assert.are.same({ "Hunt completed", { "New!" } }, { shown.headline.title, shown.stamps })
			assert.are.same({ "Hunts", "Ledger" }, { seen.summarized[1].module, seen.summarized[2].module })
		end
	)

	it(
		"drops the moments a rebuild raises, reporting once per Module per login through geterrorhandler() (ANN-R4)",
		function()
			local loaded, seen = coreSeeing(history(3, 1791731000))
			moduleRaising(loaded, "Ledger", 10, function(record)
				return { rung = "toast", kind = "newSpecies", title = "New Species", cast = record.id }
			end)

			enterWorld(loaded)
			loaded.client.runTimers()

			assert.are.same({}, seen.shown)
			assert.are.same({}, seen.summarized)
			assert.are.equal(1, #seen.reported)
			assert.matches("Ledger raised a moment during a projection's rebuild apply", seen.reported[1])
		end
	)

	it("raises an error at the Module's call for an unknown rung, or no kind or title (ANN-R1)", function()
		local loaded = coreSeeing(history(0, 1791731000))
		local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })

		for _, moment in ipairs({
			{ rung = "fanfare", kind = "k", title = "t" },
			{ rung = "toast", title = "t" },
			{ rung = "toast", kind = "k" },
		}) do
			local ok, err = pcall(M.RaiseMoment, M, moment)
			assert.is_false(ok)
			assert.matches("RaiseMoment", err)
		end
		assert.has_error(function()
			M.RaiseMoment({}, { rung = "toast", kind = "k", title = "t" })
		end)
	end)

	it(
		"holds a Cast's moments while a projection updates, merging them with its live ones on the frame after it"
			.. " finishes (ANN-R10, LOG-R74)",
		function()
			local loaded, seen = coreSeeing(history(501, 1791731000))
			moduleRaising(loaded, "Ledger", 10, function(record)
				return { rung = "toast", kind = "newSpecies", title = "New Species", cast = record.id }
			end)
			local hunts = loaded.env.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
			loaded.env.Pagle.RegisterCallback("Hunts", "CastEnded", function(_, _, cast)
				hunts:RaiseMoment({ rung = "toast.high", kind = "huntCompleted", title = "Hunt", cast = cast.id })
			end)
			loaded.client.fire("PLAYER_LOGIN")
			loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)
			seen.reported = {}

			catchOne(loaded) -- Hunts raises now; the Ledger, still rebuilding, sees the Cast live when it finishes
			loaded.client.runTimers() -- Core's Field report projection rebuilds first (LOG-R78)
			loaded.client.runTimers() -- the rebuild's entries
			loaded.client.runTimers() -- the rebuild finishes in this frame: done in a frame of its own (#79)
			assert.are.same({}, seen.shown)
			loaded.client.runTimers()

			assert.are.equal(1, #seen.shown)
			assert.are.same({ "Hunt", { "New Species" } }, { seen.shown[1].headline.title, seen.shown[1].stamps })
		end
	)
end)
