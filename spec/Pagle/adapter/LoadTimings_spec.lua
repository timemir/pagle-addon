-- Login's load timings (#262), for launch re-verification checks 2 and 10: while dev mode is on at ADDON_LOADED,
-- Core keeps debugprofilestop() marks of its login steps and each projection's catch-up or rebuild in
-- PagleDB.global.probe.timings, through the real TOC and the fake client's login. With it off, nothing is kept.

-- Core over a saved log of `entries`, with dev mode on unless `dev` is false, on a clock that moves 0.01 ms each time it's
-- read, so every step takes time, with a Ledger whose projection applies every record it's handed. ADDON_LOADED
-- fires once the clock is in place; PagleDB `saved`, if given, is the saved PagleDB.
local function devCore(entries, dev, saved)
	local ticks = 0
	saved = saved or { global = {} }
	saved.global.dev = dev ~= false
	local loaded = loadAddon(
		"Pagle",
		foreverWith({
			PagleLog = savedLog(entries),
			PagleDB = saved,
			debugprofilestop = function()
				ticks = ticks + 1
				return ticks / 100
			end,
		}),
		{ holdAddonLoaded = true }
	)
	loaded.client.fire("ADDON_LOADED", "Pagle")
	loaded.client.addons.Pagle_Ledger = { metadata = { ["X-Pagle-API"] = "1" } }
	local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
	M:NewProjection({
		db = {},
		rulesVersion = 1,
		reset = function()
			return {}
		end,
		apply = function() end,
	})
	return loaded
end

-- The login through the first PLAYER_ENTERING_WORLD, then frames until no projection is updating.
local function logIn(loaded)
	loaded.client.fire("PLAYER_LOGIN")
	loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)
	for _ = 1, 1000 do
		if not loaded.ns.projections:IsUpdating() then
			break
		end
		loaded.client.runTimers()
	end
	assert.is_false(loaded.ns.projections:IsUpdating())
	return loaded
end

describe("load timings (#262)", function()
	describe("a login with dev mode on, over a log that rebuilds in chunks (LOG-R71, LOG-R72)", function()
		local loaded = logIn(devCore(history(600)))
		local timings = loaded.env.PagleDB.global.probe and loaded.env.PagleDB.global.probe.timings

		it("keeps the timings in PagleDB.global.probe.timings, with the log's length at load and the budget", function()
			assert.is_table(timings)
			assert.are.same(
				{ 601, SERVER_TIME, 4, 500 },
				{ timings.entries, timings.time, timings.budget, timings.syncLimit }
			)
		end)

		it(
			"marks Core's login steps in order: files, ADDON_LOADED, the log opened, login, entering world, idle",
			function()
				local marks = timings.marks
				local order = {}
				for _, mark in ipairs(loaded.ns.LOAD_MARKS) do
					order[#order + 1] = mark[1]
					assert.is_number(marks[mark[1]])
				end
				assert.are.same(
					{ "filesLoaded", "addonLoaded", "logOpened", "playerLogin", "enteringWorld", "idle" },
					order
				)
				for i = 2, #order do
					assert.is_true(marks[order[i]] >= marks[order[i - 1]])
				end
				assert.is_true(marks.logOpened > marks.addonLoaded)
				assert.is_true(marks.idle > marks.enteringWorld)
			end
		)

		it(
			"times each projection's rebuild, Core's own first: the entries applied, the frames, the longest frame",
			function()
				local names = {}
				for _, timing in ipairs(timings.projections) do
					names[#names + 1] = timing.name
					assert.are.equal("rebuild", timing.mode)
					assert.are.equal(601, timing.applied)
					assert.is_true(timing.started >= timings.marks.enteringWorld)
					assert.is_true(timing.finished > timing.started)
					-- It ran in chunks across frames (LOG-R71).
					assert.is_true(timing.frames > 1)
					assert.is_true(timing.longest > 0 and timing.longest <= timing.finished - timing.started)
					-- Each frame's chunk stops within the budget (LOG-R71), so no projection's share of one is over it.
					assert.is_true(timing.longest <= timings.budget)
				end
				assert.are.same({ "fieldReport", "wallet", "varieties", "Ledger" }, names)
			end
		)
	end)

	it("times a catch-up or rebuild of 500 entries or fewer as one frame, the login's (LOG-R71)", function()
		local loaded = logIn(devCore(history(10)))
		for _, timing in ipairs(loaded.env.PagleDB.global.probe.timings.projections) do
			assert.are.same({ "rebuild", 11, 1 }, { timing.mode, timing.applied, timing.frames })
			assert.is_true(timing.longest > 0)
		end
	end)

	it("with dev mode off keeps none, and leaves PagleDB.global.probe as it was", function()
		assert.is_nil(logIn(devCore(history(600), false)).env.PagleDB.global.probe)
		local probe = { time = 1, checks = {}, timings = { entries = 3 } }
		local loaded = logIn(devCore(history(10), false, { global = { probe = probe } }))
		assert.are.equal(probe, loaded.env.PagleDB.global.probe)
		assert.are.same({ time = 1, checks = {}, timings = { entries = 3 } }, probe)
	end)

	it("keeps a stored probe's checks beside the new timings, and /pagle dev probe keeps the timings", function()
		local loaded = logIn(devCore(history(10), true, { global = { probe = { time = 1, checks = { [19] = {} } } } }))
		local global = loaded.env.PagleDB.global
		local timings = global.probe.timings
		assert.are.same(
			{ time = 1, checks = { [19] = {} } },
			{ time = global.probe.time, checks = global.probe.checks }
		)

		loaded.env.SlashCmdList.PAGLE("dev probe")

		assert.are_not.equal(1, global.probe.time)
		assert.are.equal(timings, global.probe.timings)
	end)
end)
