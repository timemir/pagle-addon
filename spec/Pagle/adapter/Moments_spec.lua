-- M:RaiseMoment as Core runs it, through the real TOC (announcements.md › Moments and the ladder, › One Announcement
-- per Cast; ADR 0007): Modules' projections raise moments on a live Cast, and Core hands one Announcement per Cast
-- to the display (ns.lanes, #84's) on a later frame, and each moment to the summary (ns.summary, #86's).

local OILY_BLACKMOUTH = "|cffffffff|Hitem:6358::::::::15:::::::::|h[Oily Blackmouth]|h|r"
local FISHING = 7731

-- `n` Casts by Ada, then the build entry the fake client's build matches, so login appends no B1.
local function history(n)
	local entries = {}
	for i = 1, n do
		entries[i] = ("C1|1|%d|0|c|494|1439|1|148|453|86|25|263|||6358x1"):format(1791731000 + i)
	end
	entries[n + 1] = "B1|1|1791731999|0|70338|1.60.1"
	return entries
end

-- Core over a saved log holding `entries`, with the Ledger and Hunts installed. What Core hands the display and the
-- summary is in `seen.shown` and `seen.summarized`; errors reaching geterrorhandler() in `seen.reported`.
local function loadCore(entries)
	local loaded = loadAddon("Pagle", foreverWith({ PagleLog = savedLog(entries) }))
	for _, name in ipairs({ "Ledger", "Hunts" }) do
		loaded.client.addons["Pagle_" .. name] = { metadata = { ["X-Pagle-API"] = "1" } }
	end
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

-- Plays a caught Cast of one Oily Blackmouth on the fake client.
local function catchOne(loaded)
	loaded.client.fire("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-1", FISHING)
	loaded.client.loot = { fishing = true, slots = { { link = OILY_BLACKMOUTH, quantity = 1 } } }
	loaded.client.fire("LOOT_READY", true)
	loaded.client.fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-1", FISHING)
	loaded.client.fire("LOOT_CLOSED")
end

local function login(loaded)
	loaded.client.fire("PLAYER_LOGIN")
	loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)
	loaded.client.runTimers()
end

describe("M:RaiseMoment", function()
	it(
		"merges two Modules' moments for a live Cast into one Announcement on the next frame (ANN-R10, ANN-R11,"
			.. " LOG-R73)",
		function()
			local loaded, seen = loadCore(history(1))
			moduleRaising(loaded, "Hunts", 20, function(record)
				return { rung = "toast.high", kind = "huntCompleted", title = "Hunt completed", cast = record.id }
			end)
			moduleRaising(loaded, "Ledger", 10, function(record)
				return { rung = "toast", kind = "newSpecies", title = "New Species", stamp = "New!", cast = record.id }
			end)
			login(loaded)

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
			local loaded, seen = loadCore(history(3))
			moduleRaising(loaded, "Ledger", 10, function(record)
				return { rung = "toast", kind = "newSpecies", title = "New Species", cast = record.id }
			end)

			login(loaded)

			assert.are.same({}, seen.shown)
			assert.are.same({}, seen.summarized)
			assert.are.equal(1, #seen.reported)
			assert.matches("Ledger raised a moment during a projection's rebuild apply", seen.reported[1])
		end
	)

	it("raises an error at the Module's call for an unknown rung, or no kind or title (ANN-R1)", function()
		local loaded = loadCore(history(0))
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
			local loaded, seen = loadCore(history(501))
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
			loaded.client.runTimers() -- the rebuild's entries
			loaded.client.runTimers() -- the rebuild finishes in this frame: done in a frame of its own (#79)
			assert.are.same({}, seen.shown)
			loaded.client.runTimers()

			assert.are.equal(1, #seen.shown)
			assert.are.same({ "Hunt", { "New Species" } }, { seen.shown[1].headline.title, seen.shown[1].stamps })
		end
	)
end)
