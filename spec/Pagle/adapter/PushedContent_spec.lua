-- Core's pushed-content reader through the real TOC and the fake client (core/pushed-content.md, ADR 0013):
-- PagleContentData as Pagle_Content leaves it before PLAYER_LOGIN, the check over frames, Pagle.GetCompanionState,
-- Pagle.GetPushedContent, PushedContentReady, PagleDB.global.pushed.seq and `/pagle dev content`.

---@class PushedContentCore: LoadedAddon
---@field fired PagleCompanionState[] each PushedContentReady's state, in order

describe("Pagle_Content", function()
	local fixtures = pushedContentFixtures()

	-- Types `/pagle <msg>` in chat.
	local function pagle(loaded, msg)
		loaded.env.SlashCmdList.PAGLE(msg)
	end

	-- Core over a saved log with PagleDB `saved`, up to PLAYER_LOGIN's eve: Pagle_Content, installed and loaded when
	-- `data` is given, has set PagleContentData to it, as its data file does after Pagle's load (PUSH-R1). With
	-- `testKey`, a local-only build that adds the test key to Core's keys. Each PushedContentReady is in `fired`.
	---@return PushedContentCore
	local function core(data, options)
		options = options or {}
		local loaded = loadCore(options.log or history(1), options.saved) --[[@as PushedContentCore]]
		if data ~= nil then
			loaded.client.addons.Pagle_Content = { metadata = {} }
			loaded.env.PagleContentData = data
		end
		if options.testKey then
			loaded.ns.PUSHED_KEYS.testKey = fixtures.testKey
		end
		loaded.fired = {}
		loaded.env.Pagle.RegisterCallback("spec", "PushedContentReady", function(_, state)
			loaded.fired[#loaded.fired + 1] = state
		end)
		return loaded
	end

	-- `/pagle dev content`'s lines, with dev mode on.
	local function devContent(loaded)
		pagle(loaded, "dev on")
		local from = #loaded.printed + 1
		pagle(loaded, "dev content")
		local lines = {}
		for i = from, #loaded.printed do
			lines[#lines + 1] = loaded.printed[i]
		end
		return lines
	end

	it(
		"reads missing at login on a first install with no Pagle_Content, and says why in dev mode (PUSH-R13, PUSH-R90)",
		function()
			local loaded = core(nil)
			assert.are.equal("checking", loaded.env.Pagle.GetCompanionState())

			loaded.client.fire("PLAYER_LOGIN")

			assert.are.equal("missing", loaded.env.Pagle.GetCompanionState())
			assert.are.same({ "missing" }, loaded.fired)
			assert.are.same({}, loaded.env.Pagle.GetPushedContent("huntRun"))
			assert.are.same(
				{ "Pagle dev: pushed content is missing: no file (Pagle_Content isn't installed)." },
				devContent(loaded)
			)
		end
	)

	it(
		"checks a file signed with the test key over the frames after login, in a build with that key (PUSH-R10–R16, PUSH-R22)",
		function()
			local loaded = core(fixtures.good, { testKey = true })

			loaded.client.fire("PLAYER_LOGIN")
			assert.are.equal("checking", loaded.env.Pagle.GetCompanionState())
			assert.are.same({}, loaded.env.Pagle.GetPushedContent("huntRun"))
			loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)
			loaded.client.advance(0)

			local Pagle = loaded.env.Pagle
			assert.are.equal("connected", Pagle.GetCompanionState())
			assert.are.same({ "connected" }, loaded.fired)
			local runs = Pagle.GetPushedContent("huntRun")
			assert.are.equal(1, #runs)
			assert.are.equal("p_test_tide", runs[1].event)
			assert.are_not.equal(runs, Pagle.GetPushedContent("huntRun"))
			assert.are.same({}, Pagle.GetPushedContent("notice"))
			assert.are.equal(42, loaded.ns.db.global.pushed.seq)
			assert.are.equal("Pagle dev: pushed content is connected.", devContent(loaded)[1])
		end
	)

	it("reports a hand-made, unsigned file absent, and why (PUSH-R13, PUSH-R14, the M8 exit check's step 6)", function()
		local unsigned = {}
		for key, value in pairs(fixtures.good) do
			unsigned[key] = value
		end
		unsigned.sig = nil
		local loaded = core(unsigned)

		enterWorld(loaded, 1)

		assert.are.equal("missing", loaded.env.Pagle.GetCompanionState())
		assert.are.same({}, loaded.env.Pagle.GetPushedContent("huntRun"))
		assert.are.same({
			"Pagle dev: pushed content is missing: a missing field, sig.",
			"Pagle dev: generatedAt 1791728100, keyId testKey, seq 42, expires 1792336500.",
			"Pagle dev: frames the check ran in: 1, the longest 0.00 ms (budget 4 ms).",
		}, devContent(loaded))
	end)

	it(
		"reports a file signed with the test key absent in a shipped build, whose keys don't hold it (PUSH-R12)",
		function()
			local loaded = core(fixtures.good)

			enterWorld(loaded, 1)

			assert.are.equal("missing", loaded.env.Pagle.GetCompanionState())
			assert.is_nil(loaded.ns.PUSHED_KEYS.testKey)
			assert.are.equal("Pagle dev: pushed content is missing: an unknown keyId, testKey.", devContent(loaded)[1])
		end
	)

	it(
		"checks again at each /reload, refusing a replayed older file by the seq it stored (PUSH-R92, PUSH-R93)",
		function()
			local first = core(fixtures.good, { testKey = true })
			enterWorld(first, 1)
			local saved = first.env.PagleDB
			assert.are.equal(42, saved.global.pushed.seq)

			local again = core(fixtures.good, { testKey = true, saved = saved })
			enterWorld(again, 1)
			assert.are.equal("connected", again.env.Pagle.GetCompanionState())

			saved.global.pushed.seq = 43
			local replayed = core(fixtures.good, { testKey = true, saved = saved })
			enterWorld(replayed, 1)
			assert.are.equal("missing", replayed.env.Pagle.GetCompanionState())
			assert.are.same({ "missing" }, replayed.fired)
		end
	)

	-- The log's Companion entries (LOG-R37), as entry strings.
	local function companionEntries(loaded)
		local found = {}
		for _, entry in ipairs(loaded.env.PagleLog.entries) do
			if entry:sub(1, 3) == "K1|" then
				found[#found + 1] = entry
			end
		end
		return found
	end

	it(
		"appends one Companion entry the first time a file passes the check, and Sonar Scope is owned (LOG-R37,"
			.. " SHOP-R29)",
		function()
			local loaded = core(fixtures.good, { testKey = true })
			enterWorld(loaded)
			assert.are.equal("checking", loaded.env.Pagle.GetCompanionState())
			assert.is_false(loaded.env.Pagle.IsOwned("core.toaststyle.sonar"), "before the check ends")

			loaded.client.advance(0)

			assert.are.equal("connected", loaded.env.Pagle.GetCompanionState())
			-- For the logged-in character (the fake client's, character 2 beside the history's Ada), with the file's keyId
			-- and seq.
			assert.are.same({ ("K1|2|%d|1|testKey|42"):format(SERVER_TIME) }, companionEntries(loaded))
			assert.is_true(loaded.env.Pagle.IsOwned("core.toaststyle.sonar"))
			assert.are.same(
				{},
				(function()
					local kinds = {}
					for record in loaded.env.Pagle.IterateCatches(0) do
						if record.kind == "companion" then
							kinds[#kinds + 1] = record.kind
						end
					end
					return kinds
				end)(),
				"Pagle.IterateCatches never yields it"
			)

			-- A /reload: the file passes again, and the log already holds its one.
			local again = core(fixtures.good, { testKey = true, log = loaded.env.PagleLog, saved = loaded.env.PagleDB })
			enterWorld(again, 2)
			assert.are.equal("connected", again.env.Pagle.GetCompanionState())
			assert.are.equal(1, #companionEntries(again))
			assert.is_true(again.env.Pagle.IsOwned("core.toaststyle.sonar"))
		end
	)

	it("appends none for a file that fails the check, and Sonar Scope stays unearned (LOG-R37, SHOP-R29)", function()
		local loaded = core(fixtures.good) -- a shipped build: the test key is unknown

		enterWorld(loaded, 2)

		assert.are.equal("missing", loaded.env.Pagle.GetCompanionState())
		assert.are.same({}, companionEntries(loaded))
		assert.is_false(loaded.env.Pagle.IsOwned("core.toaststyle.sonar"))
	end)

	it("never writes PagleContentData, and Pagle's addons never hold Pagle_Content (PUSH-R1)", function()
		local data = {}
		for key, value in pairs(fixtures.good) do
			data[key] = value
		end
		local loaded = core(data, { testKey = true })
		enterWorld(loaded, 1)

		assert.are.equal(data, loaded.env.PagleContentData)
		assert.are.same(fixtures.good, data)
		for _, path in ipairs(shippedFiles("addons/")) do
			assert.are.equal(nil, (path:find("Pagle_Content", 1, true)), path)
			assert.are.equal(nil, (readFile(path):find("PagleContentData%s*=[^=]")), path)
		end
	end)

	it("prints nothing with dev mode off (PUSH-R14)", function()
		local loaded = core(nil)
		enterWorld(loaded)

		pagle(loaded, "dev content")

		assert.are.equal(
			"Pagle dev: dev commands are off; /pagle dev on turns them on.",
			loaded.printed[#loaded.printed]
		)
	end)
end)
