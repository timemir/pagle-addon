-- scripts/make-test-log.lua: the test logs the M4 and M7 exit checks play (#172, #174, #243). It runs over a copy
-- of the fixture account spec/scripts/fixtures/WTF/Account/M4-Test#1/, written the way the client writes it (CRLF,
-- no indent, a leading blank line): Ada and Bram, the dev's real PagleLog with Bram's Casts last, a PagleDB,
-- Pagle.lua.bak, Pagle_Ledger.lua and Pagle_QoL.lua (and no Pagle_Ledger.lua.bak or Pagle_QoL.lua.bak). The world is
-- spec/scripts/fixtures/TestLogCatalogue.lua (--catalogue), which lists a Legend, Noise, a gated Species and a
-- container beside ordinary Species, junk and trophies. What a test log holds is read back here with Core's own
-- codec and folded with the Ledger's own logic/, the same oracle the game uses (catch-log.md › Entry formats, LED-R3).
-- The boardday preset (#243) runs over spec/scripts/fixtures/WTF/Account/M7-Test#1/: the same account with a started
-- Tackle Board (Bram's `start`, an `issue` and, last, a `day` record of Tuesday 13 October 15:00 UTC, the weekly
-- reset too) and a Pagle_TackleBoard.lua (no .bak); its test log is folded with the Tackle Board's own logic/
-- (TKB-R81). The wagers preset (#310) runs over the M4-Test#1 account with a fixture Hunt list and event pool and the
-- rotation's origin moved; its test log is folded with Hunts' own logic/ (HNT-R136) and logged into on FakePagle.
-- Each test cites #172's doc, in-game-verification.md › Test logs, by its bullet, or the rule it checks.

local FIXTURE = "spec/scripts/fixtures/WTF/Account/M4-Test#1"
local BOARD_FIXTURE = "spec/scripts/fixtures/WTF/Account/M7-Test#1"
local CATALOGUE = "spec/scripts/fixtures/TestLogCatalogue.lua"
local NOW = 1792000000 -- 2026-10-14 17:46:40 UTC, the server time the script runs at
local ORIGINAL_LOG_ID = "5d2e8a0c4b1f7e93"
-- Every Pagle addon's SavedVariables file and its .bak: Core, the Ledger and QoL now, Hunts, Stats and the Tackle
-- Board once they ship.
local SV_FILES = {}
for _, addon in ipairs({ "Pagle", "Pagle_Ledger", "Pagle_QoL", "Pagle_Hunts", "Pagle_Stats", "Pagle_TackleBoard" }) do
	SV_FILES[#SV_FILES + 1] = addon .. ".lua"
	SV_FILES[#SV_FILES + 1] = addon .. ".lua.bak"
end

local core = loadAddon("Pagle", FOREVER_GLOBALS).ns

-- busted runs on stock Lua 5.1, which has the os and loadfile the WoW client lacks.
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os
local os = os
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
local loadfile = loadfile
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local script = dofile("spec/support/script.lua")

-- The script's own file helpers (scripts/lib/wtf.lua). readFileOrNil is nil for a missing file, where the helpers'
-- readFile raises.
local quote, readFileOrNil, folders = script.wtf.quote, script.wtf.readFile, script.wtf.listFolder

-- A copy of the fixture account in a new folder whose path has a space and a `#`, as
-- World of Warcraft/_classic_beta_/WTF/Account/<ACCOUNT>#1/ has, and a folder for the test logs beside it.
local function newAccount(fixture)
	local base = os.tmpname()
	os.remove(base)
	local account, out = base .. " Account#1", base .. " test logs"
	local from = quote(fixture or FIXTURE)
	assert(os.execute(("mkdir -p %s && cp -R %s/. %s"):format(quote(account), from, quote(account))) == 0)
	return account, out
end

local function writeFile(path, text)
	script.wtf.writeFile(path, text)
end

--- Runs the script as `lua scripts/make-test-log.lua <args>` would at server time `now` (NOW by default), with
--- `globals` in its environment if given, and returns its output lines, what it wrote to stderr, and its exit code.
---@return string[] out, string err, integer code
local function run(args, now, globals)
	return script.run("scripts/make-test-log.lua", args, { now = now or NOW, globals = globals })
end

-- Loads a SavedVariables text as data, as the client does: the globals it assigns.
local function globalsOf(text)
	return assert(script.wtf.loadSavedVariables(text, "Pagle.lua"))
end

-- The Ledger's world and fold over the fixture catalogue, as the Ledger builds them (LED-R3, LED-R10).
local function ledgerOver(path)
	local catalogue = assert(script.wtf.loadCatalogue(path))
	local ledger = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns
	local world = ledger.NewWorld(catalogue)
	local fold = ledger.NewLedgerFold({
		GetItem = catalogue.GetItem,
		MatchesConditions = core.MatchesConditions,
		world = world,
	})
	return ledger, fold, catalogue
end

local ledger, fold, catalogue = ledgerOver(CATALOGUE)

-- A PagleLog read back with Core's codec (LOG-R16), each Species Catch sized as the game sizes it (LOG-R65): its
-- records, and how many entries didn't decode.
local function decoded(log)
	local global = { decodeErrors = 0 }
	local records = {}
	for record in core.OpenCatchLog(log, global, NOW, catalogue.GetItem):Iterate() do
		records[#records + 1] = record
	end
	return records, global.decodeErrors
end

-- The Ledger's state after every record (LED-R3).
local function folded(records)
	local state = fold.reset()
	for _, record in ipairs(records) do
		fold.apply(state, record, "rebuild")
	end
	return state
end

-- How many Species hold a Simulated Size record in a state (LED-R80).
local function sizeRecords(state)
	local n = 0
	for _, entry in pairs(state.species) do
		n = n + (entry.record and 1 or 0)
	end
	return n
end

-- Makes a test log on a new copy of the fixture account (`fixture`, else M4-Test#1) at server time `now` (else NOW),
-- with `globals` in the script's environment and the files in `planted` (name to text) added to its SavedVariables
-- first, and `extra` after the other arguments; returns the account, the test logs' folder, the one stage folder the
-- run made (nil if none) and the run's output.
local function make(preset, now, fixture, globals, planted, extra)
	local account, out = newAccount(fixture)
	for name, text in pairs(planted or {}) do
		writeFile(account .. "/SavedVariables/" .. name, text)
	end
	local args = { "--account", account, "--preset", preset, "--out", out, "--catalogue", CATALOGUE }
	for _, word in ipairs(extra or {}) do
		args[#args + 1] = word
	end
	local lines, err, code = run(args, now, globals)
	local stages = folders(out .. "/" .. account:match("[^/]*$"))
	local stage = stages[1] and out .. "/" .. account:match("[^/]*$") .. "/" .. stages[1]
	return { account = account, out = out, stage = stage, stages = stages, lines = lines, err = err, code = code }
end

describe("scripts/make-test-log.lua (#172, in-game-verification.md › Test logs)", function()
	describe("--preset level10 on the fixture account (the --preset bullet)", function()
		local made = make("level10")
		local text = made.stage and readFileOrNil(made.stage .. "/Pagle.lua")
		local log = text and globalsOf(text).PagleLog

		it("exits 0 and makes one stage folder, <UTC time>-<preset>, under the account's name (--preset)", function()
			assert.are.equal("", made.err)
			assert.are.equal(0, made.code)
			assert.are.same({ "20261014-174640-level10" }, made.stages)
		end)

		it(
			"writes a PagleLog Core's codec decodes whole, with the fixture's characters and a new logId (LOG-R15)",
			function()
				local records, undecodable = decoded(log)
				assert.are.equal(0, undecodable)
				assert.are.equal(#log.entries, #records)
				assert.are.same(
					globalsOf(readFileOrNil(FIXTURE .. "/SavedVariables/Pagle.lua")).PagleLog.characters,
					log.characters
				)
				assert.are.equal(1, log.format)
				assert.matches("^%x+$", log.logId)
				assert.are.equal(16, #log.logId)
				assert.are.equal(log.logId:lower(), log.logId)
				assert.are_not.equal(ORIGINAL_LOG_ID, log.logId)
			end
		)

		it("marks the log a test log, so /pagle dev catch works on it (catch-log.md › Data: test)", function()
			assert.is_true(log.test)
		end)

		it(
			"folds to Angler Level 9 within three Catches of level 10, as it prints (LED-R20, LED-R22, LED-R30)",
			function()
				local state = folded((decoded(log)))
				local level, into, cost = ledger.ClimbOf(state.xp, state.prestige)
				assert.are.equal(9, level)
				-- Three Catches give 10 XP each, doubled while Fresh Water lasts: at least 3 of it is there now.
				assert.is_true(cost - into > 0 and cost - into <= 60)
				assert.is_true(ledger.FreshWaterShown(state, NOW) >= 3)
				assert.are.equal(
					(
						"fold: Angler Level 9, %d XP, %d XP to level 10; one more Catch gives 20 XP, %d Catches reach level 10;"
						.. " %d lifetime Catches, %d Simulated Size records"
					):format(
						state.xp,
						cost - into,
						math.ceil((cost - into) / 20),
						state.catches,
						sizeRecords(state)
					),
					made.lines[4]
				)
			end
		)

		it(
			"folds the Casts sized, as the game reads them, so the fixture's Species set records (LOG-R65, LED-R80)",
			function()
				local state = folded((decoded(log)))
				assert.is_true(sizeRecords(state) > 0)
				assert.matches((", %d Simulated Size records$"):format(sizeRecords(state)), made.lines[4])
			end
		)

		it(
			"prints each entry tag's count, as Core's codec tagged the entries (catch-log.md › Entry formats)",
			function()
				local tags = {}
				for _, entry in ipairs(log.entries) do
					local tag = entry:match("^(%u%d)|")
					tags[tag] = (tags[tag] or 0) + 1
				end
				assert.are.same({ B1 = 1, C1 = tags.C1, S1 = 2 }, tags)
				assert.matches(("(B1 1, C1 %d, S1 2)"):format(tags.C1), made.lines[3], 1, true)
			end
		)

		it(
			"marks it a test log, PagleLog.test = true, so /pagle dev catch appends on it (catch-log.md › Data)",
			function()
				assert.is_true(log.test)
				assert.is_nil(globalsOf(readFileOrNil(FIXTURE .. "/SavedVariables/Pagle.lua")).PagleLog.test)
			end
		)

		it(
			"copies the last build entry and each character's last Skill Reading: Core appends neither (LOG-R31, LOG-R36)",
			function()
				local records = decoded(log)
				local build, skills = {}, {}
				for _, record in ipairs(records) do
					if record.kind == "build" then
						build[#build + 1] = { record.build, record.version }
					elseif record.kind == "skill" then
						skills[#skills + 1] = { record.char, record.rank, record.max, record.mod }
					end
				end
				assert.are.same({ { 70412, "1.60.2" } }, build)
				assert.are.same({ { 1, 85, 150, 25 }, { 2, 160, 225, 0 } }, skills)
			end
		)

		it(
			"fishes with Bram, whose Cast is the log's last, one item a caught Cast, at server times in the past (LOG-R20)",
			function()
				local casts = 0
				for _, record in ipairs((decoded(log))) do
					if record.kind == "cast" then
						casts = casts + 1
						assert.are.equal(2, record.char)
						assert.are.equal("caught", record.outcome)
						assert.are.equal(1, #record.items)
						assert.are.equal(1, record.items[1].quantity)
						assert.is_true(record.time < NOW)
						assert.are.equal(160, record.conditions.skillRank)
					end
				end
				assert.is_true(casts > 0)
			end
		)

		it(
			"catches only ordinary Species, junk and trophies from charted zones' lists, outside any window (LED-R5, LED-R10)",
			function()
				local world = ledger.NewWorld(catalogue)
				for _, record in ipairs((decoded(log))) do
					if record.kind == "cast" then
						local itemID = record.items[1].itemID
						local item = catalogue.GetItem(itemID)
						assert.is_truthy(item)
						assert.is_false(item.legend or item.noise)
						assert.is_truthy(({ fish = true, junk = true, trophy = true })[item.category])
						local listed = false
						for _, entry in ipairs(world.zones[record.conditions.zone].list) do
							local area = record.conditions.subzone ~= 0 and record.conditions.subzone
								or record.conditions.zone
							listed = listed or (entry.itemID == itemID and entry.areaID == area and not entry.window)
						end
						assert.is_true(listed)
					end
				end
			end
		)

		it(
			"keeps every other line of Pagle.lua, PagleDB's included, byte for byte, in the client's layout (the intro)",
			function()
				local fixture = readFileOrNil(FIXTURE .. "/SavedVariables/Pagle.lua")
				local fixtureDB = fixture:sub((fixture:find("\r\nPagleDB = {\r\n", 1, true)))
				assert.are.equal("\r\nPagleLog = {\r\n", text:sub(1, #"\r\nPagleLog = {\r\n"))
				assert.are.equal(fixtureDB, text:sub(-#fixtureDB))
				assert.is_nil(text:gsub("\r\n", ""):find("[\r\n]"))
				assert.are.same(globalsOf(fixture).PagleDB, globalsOf(text).PagleDB)
			end
		)

		it(
			"backs up every Pagle SavedVariables file and .bak there is byte for byte, leaving out the missing ones",
			function()
				local present = { "Pagle.lua", "Pagle.lua.bak", "Pagle_Ledger.lua", "Pagle_QoL.lua" }
				assert.are.same(present, folders(made.stage .. "/original"))
				for _, name in ipairs(present) do
					assert.are.equal(
						readFileOrNil(FIXTURE .. "/SavedVariables/" .. name),
						readFileOrNil(made.stage .. "/original/" .. name)
					)
				end
			end
		)

		it("changes nothing in the account folder: --preset only reads it", function()
			assert.are.same(folders(FIXTURE .. "/SavedVariables"), folders(made.account .. "/SavedVariables"))
			for _, name in ipairs(folders(FIXTURE .. "/SavedVariables")) do
				local path = "/SavedVariables/" .. name
				assert.are.equal(readFileOrNil(FIXTURE .. path), readFileOrNil(made.account .. path))
			end
		end)

		it(
			"prints how to install the test log and how to restore, and what the new logId does (LED-R90, LED-R93)",
			function()
				local printed = table.concat(made.lines, "\n")
				assert.matches("--install", printed, 1, true)
				assert.matches("--restore", printed, 1, true)
				assert.matches("then log in as Bram Reed.", printed, 1, true)
				assert.matches("first build", printed, 1, true)
				assert.matches("LED-R90, LED-R93", printed, 1, true)
				assert.matches("byte for byte", printed, 1, true)
			end
		)
	end)

	describe("--preset level60 on the fixture account (the presets table) #slow", function()
		local made = make("level60")
		local log = globalsOf(readFileOrNil(made.stage .. "/Pagle.lua")).PagleLog
		local records, undecodable = decoded(log)

		it("folds to Angler Level 59 within three Catches of level 60 (LED-R20, LED-R22, LED-R30)", function()
			assert.are.equal(0, made.code)
			assert.are.equal(0, undecodable)
			local state = folded(records)
			local level, into, cost = ledger.ClimbOf(state.xp, state.prestige)
			assert.are.equal(59, level)
			assert.is_true(cost - into > 0 and cost - into <= 60)
			assert.is_true(ledger.FreshWaterShown(state, NOW) >= 3)
		end)

		it("marks it a test log, PagleLog.test = true (catch-log.md › Data)", function()
			assert.is_true(log.test)
		end)

		it("holds no Legend, Noise or Uncharted item (LED-R5)", function()
			local caught = {}
			for _, record in ipairs(records) do
				for _, item in ipairs(record.kind == "cast" and record.items or {}) do
					caught[item.itemID] = true
				end
			end
			for itemID in pairs(caught) do
				local item = catalogue.GetItem(itemID)
				assert.is_truthy(item)
				assert.is_false(item.legend or item.noise)
			end
			assert.is_nil(caught[19803])
			assert.is_nil(caught[6358])
			assert.is_nil(caught[999001])
		end)
	end)

	describe("--preset catches1000 on the fixture account (the presets table)", function()
		local made = make("catches1000")
		local log = globalsOf(readFileOrNil(made.stage .. "/Pagle.lua")).PagleLog

		it("folds to 995 lifetime Catches, five short of the 1,000-Catch Catch Milestone (LED-R42)", function()
			assert.are.equal(0, made.code)
			local state = folded((decoded(log)))
			assert.are.equal(995, state.catches)
			assert.matches("; 995 lifetime Catches, %d+ Simulated Size records$", made.lines[4])
		end)

		it("marks it a test log, PagleLog.test = true (catch-log.md › Data)", function()
			assert.is_true(log.test)
		end)
	end)

	-- The big presets (#262): a Pagle.lua of about 5 or 20 MiB for launch re-verification checks 2 and 10. Each builds
	-- its log in full, so they're #slow, out of the default run.
	-- big20's log holds more distinct strings than Lua 5.1 loads in one piece (`split`), so it's read back in parts.
	local bigPresets = { { preset = "big5", mib = 5, split = false }, { preset = "big20", mib = 20, split = true } }
	for _, big in ipairs(bigPresets) do
		describe(("--preset %s on the fixture account (#262, the presets table) #slow"):format(big.preset), function()
			local made = make(big.preset)
			local text = made.stage and readFileOrNil(made.stage .. "/Pagle.lua")
			local log = text and globalsOf(text).PagleLog
			-- The log read back with Core's codec in one walk, keeping only what the tests ask, as a 20 MiB log's
			-- records would take a lot of memory.
			local seen = { records = 0, chars = {}, zones = {}, away = 0, first = math.huge, last = 0, ordered = true }
			seen.minutes, seen.items = true, true
			local global = { decodeErrors = 0 }
			for record in core.OpenCatchLog(log, global, NOW, catalogue.GetItem):Iterate() do
				seen.records = seen.records + 1
				if record.kind == "cast" then
					seen.chars[record.char] = true
					seen.zones[record.conditions.zone] = true
					seen.away = seen.away + (record.outcome == "gotAway" and 1 or 0)
					seen.ordered = seen.ordered and record.time >= seen.last
					seen.first, seen.last = math.min(seen.first, record.time), math.max(seen.last, record.time)
					seen.minutes = seen.minutes and type(record.conditions.minute) == "number"
					seen.items = seen.items and #record.items == (record.outcome == "caught" and 1 or 0)
				end
			end
			collectgarbage()

			it(("exits 0 and writes a Pagle.lua within 10%% of %d MiB"):format(big.mib), function()
				assert.are.equal("", made.err)
				assert.are.equal(0, made.code)
				assert.are.same({ "20261014-174640-" .. big.preset }, made.stages)
				local bytes = big.mib * 1024 * 1024
				assert.is_true(math.abs(#text - bytes) <= 0.1 * bytes)
				local size = "^size: Pagle.lua [%d,]+ bytes %(%d+%.%d+ MiB%), [-+]%d+%.%d%% of the preset's "
				assert.matches(size .. big.mib .. " MiB$", made.lines[4])
			end)

			it("writes a test log Core's codec decodes whole, with a new logId (LOG-R15, LOG-R16)", function()
				assert.are.equal(0, global.decodeErrors)
				assert.are.equal(#log.entries, seen.records)
				assert.is_true(log.test)
				assert.are.equal(16, #log.logId)
				assert.are_not.equal(ORIGINAL_LOG_ID, log.logId)
			end)

			it(
				"fishes on every character, in both charted zones, over several months, some Casts got away (LOG-R20)",
				function()
					assert.are.same({ true, true }, seen.chars)
					assert.are.same({ [12] = true, [40] = true }, seen.zones)
					assert.is_true(seen.away > 0)
					assert.is_true(seen.ordered, "in time order")
					assert.is_true(seen.minutes, "every Cast has its realm minute")
					assert.is_true(seen.items, "one item a caught Cast, none a got-away one")
					assert.is_true(seen.last - seen.first > 90 * 86400)
					assert.is_true(seen.last < NOW - 3600)
				end
			)

			it("says when Lua 5.1 can load it only in parts: more distinct strings than 262,143", function()
				local note
				for _, line in ipairs(made.lines) do
					note = note or (line:sub(1, 10) == "note: its " and line or nil)
				end
				assert.are.equal(big.split, #log.entries > 262143)
				if big.split then
					local says = 'more distinct strings than Lua 5.1 loads in one piece (262,143: "constant'
					assert.matches(says, note, 1, true)
				else
					assert.is_nil(note)
				end
			end)

			it("keeps PagleDB and the rest of Pagle.lua byte for byte (the intro)", function()
				local fixture = readFileOrNil(FIXTURE .. "/SavedVariables/Pagle.lua")
				local fixtureDB = fixture:sub((fixture:find("\r\nPagleDB = {\r\n", 1, true)))
				assert.are.equal(fixtureDB, text:sub(-#fixtureDB))
			end)

			it("--install and --restore round-trip byte for byte (the --install and --restore bullets)", function()
				local _, installErr, installCode =
					run({ "--account", made.account, "--install", "--out", made.out }, NOW + 10)
				assert.are.equal(text, readFileOrNil(made.account .. "/SavedVariables/Pagle.lua"))
				local _, restoreErr, restoreCode =
					run({ "--account", made.account, "--restore", "--out", made.out }, NOW + 20)
				assert.are.same({ "", 0, "", 0 }, { installErr, installCode, restoreErr, restoreCode })
				for _, name in ipairs(SV_FILES) do
					assert.are.equal(
						readFileOrNil(FIXTURE .. "/SavedVariables/" .. name),
						readFileOrNil(made.account .. "/SavedVariables/" .. name),
						name
					)
				end
			end)
		end)
	end

	-- The Tackle Board's own logic/ (TKB-R81) as the game loads it, its catalogue calls over the fixture catalogue.
	local boardNs = loadAddon("Pagle_TackleBoard", FOREVER_GLOBALS).ns
	boardNs.api.pagle = catalogue

	-- A PagleLog folded with the Tackle Board's projection from nothing, as a first build does (TKB-R81, TKB-R82):
	-- the state and how many entries didn't decode.
	local function boardFolded(log)
		local global = { decodeErrors = 0 }
		local state = boardNs.NewBoardState()
		for record in core.OpenCatchLog(log, global, NOW, catalogue.GetItem):Iterate(0, "TackleBoard") do
			boardNs.ApplyEntry(state, record, "rebuild")
		end
		return state, global.decodeErrors
	end

	-- The Tackle Board's records in a PagleLog, in order, as "kind payload" (Data › Module records).
	local function boardRecords(log)
		local out = {}
		for record in core.OpenCatchLog(log, { decodeErrors = 0 }, NOW):Iterate(0, "TackleBoard") do
			if record.kind == "module" then
				out[#out + 1] = record.recordKind .. " " .. record.payload
			end
		end
		return out
	end

	-- The open goals of each type.
	local function openGoals(state)
		local open = { n = 0, e = 0 }
		for _, goal in pairs(state.goals) do
			if goal.doneDay == nil then
				open[goal.type] = open[goal.type] + 1
			end
		end
		return open
	end

	-- The fixture's latest boundary is its `day` record: Tuesday 13 October 15:00 UTC, the daily and weekly reset. At
	-- NOW (Wednesday 17:46) the board day began at 15:00 today, so day 0 of the test board is Monday 12 October 15:00
	-- (1791817200), two board days back, in the week that began Tuesday 6 October 15:00 (1791298800).
	describe("--preset boardday on an account with a started board (in-game-verification.md › Test logs)", function()
		local made = make("boardday", NOW, BOARD_FIXTURE)
		local text = made.stage and readFile(made.stage .. "/Pagle.lua")
		local log = text and globalsOf(text).PagleLog

		it("exits 0 and makes one dated test log for the account", function()
			assert.are.equal("", made.err)
			assert.are.equal(0, made.code)
			assert.are.same({ "20261014-174640-boardday" }, made.stages)
		end)

		it("writes a test log Core's codec decodes whole, with a new logId (LOG-R15, LOG-R16)", function()
			local records, undecodable = decoded(log)
			assert.are.equal(0, undecodable)
			-- Pagle.IterateCatches' read yields no Module record (LOG-R42); the board's own read yields its 5
			assert.are.equal(#log.entries, #records + #boardRecords(log))
			assert.is_true(log.test)
			assert.are.equal(16, #log.logId)
			assert.are_not.equal(ORIGINAL_LOG_ID, log.logId)
		end)

		it(
			"starts the board two board days back, then issues an Expedition and three Notices, a Haul Notice in charted Westfall among them (TKB-R12, TKB-R21, TKB-R80)",
			function()
				assert.are.same({
					"start 1791817200;1791298800",
					"issue e;haul;0;60;150;40",
					"issue n;haul;1;10;20;40",
					"issue n;lure;1;10;15;",
					"issue n;wanderer;3;20;3;",
				}, boardRecords(log))
			end
		)

		it("catches on day 0 just enough in Westfall for the Haul Notice, and nothing after (TKB-R42)", function()
			local casts, last = 0, 0
			for _, record in ipairs((decoded(log))) do
				last = math.max(last, record.time)
				if record.kind == "cast" then
					casts = casts + 1
					assert.are.equal(2, record.char)
					assert.are.equal("caught", record.outcome)
					assert.are.equal(40, record.conditions.zone)
					assert.is_true(record.time >= 1791817200 and record.time < 1791817200 + 86400)
				end
			end
			assert.are.equal(20, casts)
			assert.is_true(last < 1791817200 + 86400)
		end)

		it(
			"folds to day 0 lit by the Haul Notice: Campfire 1, 2 Kindling, tally 1, a fly tied, 2 Notices and 1 Expedition open (TKB-R60, TKB-R70, TKB-R71)",
			function()
				local state, undecodable = boardFolded(log)
				assert.are.equal(0, undecodable)
				assert.is_truthy(state.started)
				assert.are.equal(0, state.day)
				assert.are.same({ 1, 2, "lit" }, { state.fire.count, state.fire.kindling, state.fire.log[0] })
				assert.are.same({ notices = 1, expeditions = 0 }, state.tally)
				local flies = 0
				for _ in pairs(state.flies) do
					flies = flies + 1
				end
				assert.are.equal(1, flies)
				assert.are.same({ n = 2, e = 1 }, openGoals(state))
				for _, goal in pairs(state.goals) do
					assert.are.equal(goal.kind == "haul" and goal.type == "n" and 0 or nil, goal.doneDay)
				end
			end
		)

		it(
			"advanced to today, day 2, closes day 1 burned: 1 Kindling, Campfire still 1, 4 Notices and the week's Expedition owed (TKB-R14, TKB-R20, TKB-R72)",
			function()
				local state = boardFolded(log)
				local result = boardNs.AdvanceTo(state, boardNs.DayOf(state.boundary, NOW), "rebuild")
				assert.are.same({ { day = 0, log = "lit" }, { day = 1, log = "burned" } }, result.closed)
				assert.are.same({ 2, 1, 1 }, { state.day, state.fire.count, state.fire.kindling })
				assert.are.same({ notices = 4, expeditions = 1 }, state.owed)
			end
		)

		it(
			"leaves the Wanderer Notice day 0's one zone, which reads 0 once advanced to today (TKB-R41, TKB-R104)",
			function()
				local state = boardFolded(log)
				local wanderer
				for _, goal in pairs(state.goals) do
					if goal.kind == "wanderer" then
						wanderer = goal
					end
				end

				assert.are.same({ 1, 0 }, { wanderer.progress, wanderer.progressDay })
				boardNs.AdvanceTo(state, boardNs.DayOf(state.boundary, NOW), "rebuild")
				assert.are.equal(0, boardNs.DisplayedProgress(wanderer, state.day))
			end
		)

		it("prints what the fold found, and when to play it (TKB-R13, TKB-R86)", function()
			assert.are.equal(
				"== Test log boardday: a started board, day 0 lit and day 1 not, two board days old (M7 exit check step 5)",
				made.lines[1]
			)
			assert.are.equal(
				"board: day 0 began 2026-10-12 15:00 UTC, the reset time of the day record at seq 12; today is day 2",
				made.lines[4]
			)
			assert.are.equal(
				"fold: day 0 lit by the Haul Notice (20 Catches in zone 40): Campfire 1 day, 2 Kindling, tally 1, 1 fly tied;"
					.. " 2 Notices and 1 Expedition open",
				made.lines[5]
			)
			assert.are.equal(
				"advanced to day 2: day 1 burned, 1 Kindling left, Campfire still 1 day; 4 Notices owed, 1 Expedition owed"
					.. " (a weekly reset falls in days 1-2)",
				made.lines[6]
			)
			local printed = table.concat(made.lines, "\n")
			assert.matches("before the next daily reset, 2026-10-15 15:00 UTC", printed, 1, true)
			assert.matches("kept burning while you were away", printed, 1, true)
		end)

		it("backs up Pagle_TackleBoard.lua with the rest, byte for byte", function()
			assert.are.same(
				{ "Pagle.lua", "Pagle.lua.bak", "Pagle_Ledger.lua", "Pagle_TackleBoard.lua" },
				folders(made.stage .. "/original")
			)
			for _, name in ipairs(folders(made.stage .. "/original")) do
				assert.are.equal(
					readFile(BOARD_FIXTURE .. "/SavedVariables/" .. name),
					readFile(made.stage .. "/original/" .. name)
				)
			end
		end)
	end)

	-- The boardday test log made at NOW, logged into on FakePagle at NOW with the Tackle Board over the fixture
	-- catalogue and the board specs' reset API (spec/Pagle_TackleBoard/support.lua: a US realm, daily resets at 15:00
	-- UTC, the weekly one on Tuesdays), as the dev does after --install: the first build, then the live step.
	describe("a boardday test log at its login", function()
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
		local board = dofile("spec/Pagle_TackleBoard/support.lua")
		local made = make("boardday", NOW, BOARD_FIXTURE)
		local fake = newFakePagle()
		fake.catchLog.data = globalsOf(readFile(made.stage .. "/Pagle.lua")).PagleLog
		fake.wait(NOW - SERVER_TIME)
		local catalogueNs = {}
		local chunk = assert(loadfile(CATALOGUE))
		setfenv(chunk, setmetatable({}, { __index = _G }))
		chunk("Pagle", catalogueNs)
		local advances = {}
		local loaded = board.load(fake, {
			catalogue = catalogueNs.catalogue,
			prepare = function(loading)
				loading.ns.outlets.Advanced = function(result, mode)
					advances[#advances + 1] = {
						closed = result.closed,
						burned = result.burned,
						wentOut = result.wentOut,
						count = result.count,
						mode = mode,
						atLogin = loading.ns.InLoginWindow(),
					}
				end
			end,
		})
		fake.login()
		fake.enterWorld()
		loaded.client.runTimers()
		local ns = loaded.ns

		it(
			"closes day 1 live at login, burning a Kindling: the kept-burning nod's advance (TKB-R13, TKB-R72, TKB-R86)",
			function()
				assert.are.same({
					{
						closed = { { day = 0, log = "lit" }, { day = 1, log = "burned" } },
						burned = 1,
						wentOut = false,
						count = 1,
						mode = "live",
						atLogin = true,
					},
				}, advances)
				local state = ns.State()
				assert.are.same({ 2, 1, 1 }, { state.day, state.fire.count, state.fire.kindling })
			end
		)

		it("fills the Notice pins to 6 and issues the week's Expedition (TKB-R20, TKB-R21)", function()
			local records = boardRecords(fake.catchLog.data)
			assert.are.equal("day 1791990000;1791903600", records[6])
			local issued = {}
			for i = 7, #records do
				issued[#issued + 1] = records[i]:match("^issue (%a);")
			end
			assert.are.same({ "e", "n", "n", "n", "n" }, issued)
			assert.are.same({ n = 6, e = 2 }, openGoals(ns.State()))
		end)
	end)

	-- showcase over the board fixture: its latest boundary (Tuesday 13 October 15:00 UTC) gives the reset time. At NOW
	-- today's board day began at 15:00, 2 h 46 min before, so today is the last lit day: day 108 of a board whose day 0
	-- is Sunday 28 June 15:00 UTC (1782658800), in the week of Tuesday 23 June's reset (1782226800). Days 27, 61, 86, 95
	-- and 103 are left unlit; the other 104 are lit.
	local SHOWCASE_DAY0, SHOWCASE_UNLIT =
		1782658800, { [27] = true, [61] = true, [86] = true, [95] = true, [103] = true }

	-- The board days a PagleLog's Tackle Board records and caught Casts fall on, numbered from its `start` record.
	local function boardDays(log)
		local days = { records = {}, casts = {} }
		for _, record in ipairs((decoded(log))) do
			local day = math.floor((record.time - SHOWCASE_DAY0) / 86400)
			if record.kind == "cast" and record.outcome == "caught" then
				days.casts[day] = true
			end
		end
		for record in core.OpenCatchLog(log, { decodeErrors = 0 }, NOW):Iterate(0, "TackleBoard") do
			if record.kind == "module" then
				local day = math.floor((record.time - SHOWCASE_DAY0) / 86400)
				days.records[day] = days.records[day] or {}
				table.insert(days.records[day], record.recordKind)
			end
		end
		return days
	end

	describe("--preset showcase on an account with a started board (in-game-verification.md › Test logs)", function()
		local made = make("showcase", NOW, BOARD_FIXTURE)
		local text = made.stage and readFile(made.stage .. "/Pagle.lua")
		local log = text and globalsOf(text).PagleLog
		local state = boardFolded(log)
		local ledgerState = folded((decoded(log)))

		it("exits 0 and makes one dated test log for the account", function()
			assert.are.equal("", made.err)
			assert.are.equal(0, made.code)
			assert.are.same({ "20261014-174640-showcase" }, made.stages)
		end)

		it(
			"writes a test log Core's codec decodes whole, with a new logId, its Casts by the fixture's last fisher (LOG-R15, LOG-R16)",
			function()
				local records, undecodable = decoded(log)
				assert.are.equal(0, undecodable)
				assert.is_true(log.test)
				assert.are.equal(16, #log.logId)
				assert.are_not.equal(ORIGINAL_LOG_ID, log.logId)
				local away = 0
				for _, record in ipairs(records) do
					if record.kind == "cast" then
						assert.are.equal(2, record.char)
						away = away + (record.outcome == "gotAway" and 1 or 0)
					end
				end
				assert.is_true(away > 0)
			end
		)

		it(
			"starts the board 108 board days back on the fixture's reset time, and writes the live step's records on each lit day only (TKB-R12, TKB-R13, TKB-R80)",
			function()
				assert.are.equal("start 1782658800;1782226800", boardRecords(log)[1])
				local days = boardDays(log)
				for day = 0, 108 do
					local kinds = days.records[day]
					if SHOWCASE_UNLIT[day] then
						assert.is_nil(kinds, "day " .. day)
						assert.is_nil(days.casts[day], "day " .. day)
					else
						assert.are.equal(day == 0 and "start" or "day", kinds[1], "day " .. day)
						assert.is_true(days.casts[day], "day " .. day)
					end
				end
				assert.is_nil(days.records[109])
			end
		)

		it("issues only the goals owed, so the board owes none at the end (TKB-R20, TKB-R21)", function()
			assert.are.same({ notices = 0, expeditions = 0 }, state.owed)
			assert.are.equal(108, state.day)
		end)

		it(
			"folds to a Campfire of 104 days lit today, with 2 Kindling, its 100-day milestone and 3 burned days in its four weeks (TKB-R70–R73, TKB-R106)",
			function()
				local fire = state.fire
				assert.are.same({ 104, 104, 2, "lit" }, { fire.count, fire.longest, fire.kindling, fire.log[108] })
				assert.are.same(
					{ 7, 30, 100 },
					(function()
						local reached = {}
						for days in pairs(fire.milestones) do
							reached[#reached + 1] = days
						end
						table.sort(reached)
						return reached
					end)()
				)
				local outcomes = {}
				for _, outcome in pairs(fire.log) do
					outcomes[outcome] = (outcomes[outcome] or 0) + 1
				end
				assert.are.same({ lit = 25, burned = 3 }, outcomes)
			end
		)

		it(
			"closes today lit at the next reset, and burns a Kindling only at the one after it (TKB-R14, TKB-R72)",
			function()
				local next = boardFolded(log)
				local result = boardNs.AdvanceTo(next, 109, "rebuild")
				assert.are.same({ { day = 108, log = "lit" } }, result.closed)
				assert.are.same({ 104, 2 }, { next.fire.count, next.fire.kindling })
				result = boardNs.AdvanceTo(next, 110, "rebuild")
				assert.are.same({ { day = 109, log = "burned" } }, result.closed)
				assert.are.same({ 104, 1 }, { next.fire.count, next.fire.kindling })
			end
		)

		it(
			"earns 5,000 Coins or more between the Ledger and the Tackle Board, as it prints (TKB-R63, LED-R88, SHOP-R2)",
			function()
				assert.is_true(ledgerState.coins + state.coins >= 5000)
				assert.is_true(state.tally.notices > 0 and state.tally.expeditions > 0)
				local function thousands(n)
					local s = tostring(n)
					repeat
						local done
						s, done = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
					until done == 0
					return s
				end
				local printed = table.concat(made.lines, "\n")
				assert.matches(
					("Coins: Ledger %s, Tackle Board %s, Hunts 0 (no Hunt is open yet): %s in all"):format(
						thousands(ledgerState.coins),
						thousands(state.coins),
						thousands(ledgerState.coins + state.coins)
					),
					printed,
					1,
					true
				)
				assert.matches("Campfire: 104 days (longest 104), 2 Kindling, the last lit day today", printed, 1, true)
			end
		)

		it("prints by when to log in, and keeps it in stage.txt for --install (TKB-R13)", function()
			local printed = table.concat(made.lines, "\n")
			assert.matches(
				"Before the next daily reset, 2026-10-15 15:00 UTC, the Campfire shows today lit",
				printed,
				1,
				true
			)
			assert.matches("reset after that, 2026-10-16 15:00 UTC, at the latest", printed, 1, true)
			assert.matches("\nnextReset 1792162800\n$", readFile(made.stage .. "/stage.txt"))
		end)
	end)

	-- The showcase test log logged into on FakePagle at NOW, as the boardday one is: the first build, then the live step.
	describe("a showcase test log at its login", function()
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
		local board = dofile("spec/Pagle_TackleBoard/support.lua")
		local made = make("showcase", NOW, BOARD_FIXTURE)
		local fake = newFakePagle()
		fake.catchLog.data = globalsOf(readFile(made.stage .. "/Pagle.lua")).PagleLog
		fake.wait(NOW - SERVER_TIME)
		local catalogueNs = {}
		local chunk = assert(loadfile(CATALOGUE))
		setfenv(chunk, setmetatable({}, { __index = _G }))
		chunk("Pagle", catalogueNs)
		local live = {}
		local loaded = board.load(fake, {
			catalogue = catalogueNs.catalogue,
			prepare = function(loading)
				loading.ns.outlets.Advanced = function(result, mode)
					if mode == "live" then
						live[#live + 1] = result
					end
				end
			end,
		})
		local written = #boardRecords(fake.catchLog.data)
		fake.login()
		fake.enterWorld()
		loaded.client.runTimers()

		it(
			"closes no day, burns no Kindling and appends no record at login: today is the board's day, lit (TKB-R13, TKB-R72)",
			function()
				assert.are.same({}, live)
				local state = loaded.ns.State()
				assert.are.same(
					{ 108, 104, 2, "lit" },
					{ state.day, state.fire.count, state.fire.kindling, state.fire.log[108] }
				)
				assert.are.equal(written, #boardRecords(fake.catchLog.data))
			end
		)
	end)

	describe("--preset showcase less than an hour after the daily reset", function()
		-- Wednesday 14 October 15:30: today's board day began half an hour ago, so yesterday is the last lit day.
		local early = 1791991800
		local made = make("showcase", early, BOARD_FIXTURE)
		local log = globalsOf(readFile(made.stage .. "/Pagle.lua")).PagleLog

		it("lights yesterday last, and must be played before the reset after today's (TKB-R12, TKB-R72)", function()
			assert.are.equal(0, made.code)
			-- Day 0 is a day earlier: Saturday 27 June 15:00.
			assert.are.equal("start 1782572400;1782226800", boardRecords(log)[1])
			local state = boardFolded(log)
			assert.are.same({ 108, 104, "lit" }, { state.day, state.fire.count, state.fire.log[108] })
			assert.are.equal(109, boardNs.DayOf(state.boundary, early))
			assert.matches("the last lit day yesterday", table.concat(made.lines, "\n"), 1, true)
			assert.matches("\nnextReset 1792076400\n$", readFile(made.stage .. "/stage.txt"))
		end)
	end)

	describe("--preset boardday when no weekly reset falls in the two days", function()
		-- Friday 16 October 17:46: day 0 is Wednesday 14 October 15:00, in the week of Tuesday 13 October's reset.
		local later = NOW + 2 * 86400
		local made = make("boardday", later, BOARD_FIXTURE)
		local log = globalsOf(readFile(made.stage .. "/Pagle.lua")).PagleLog

		it("keeps the latest boundary's week and owes no Expedition by day 2 (TKB-R12, TKB-R20)", function()
			assert.are.equal(0, made.code)
			assert.are.equal("start 1791990000;1791903600", boardRecords(log)[1])
			local state = boardFolded(log)
			boardNs.AdvanceTo(state, boardNs.DayOf(state.boundary, later), "rebuild")
			assert.are.same({ notices = 4, expeditions = 0 }, state.owed)
			assert.matches("; 4 Notices owed, 0 Expeditions owed$", made.lines[6])
		end)
	end)

	-- The account's SavedVariables files by name, nil for a missing one.
	local function savedFiles(account)
		local files = {}
		for _, name in ipairs(SV_FILES) do
			files[name] = readFileOrNil(account .. "/SavedVariables/" .. name)
		end
		return files
	end

	local function fixtureFiles()
		return savedFiles(FIXTURE)
	end

	local function modeRun(made, mode, now)
		local _, err, code = run({ "--account", made.account, mode, "--out", made.out }, now)
		return err, code
	end

	describe("--install, a game played, then --restore (the --install and --restore bullets)", function()
		local made = make("level10")
		local test = readFileOrNil(made.stage .. "/Pagle.lua")
		local installErr, installCode = modeRun(made, "--install", NOW + 10)
		local installed = savedFiles(made.account)
		local afterInstall = folders(made.stage)
		-- What the client writes at the logout after playing the test log: one more Cast, the old file as .bak, and
		-- the Ledger rebuilt from the test log, with a .bak there wasn't before.
		local played = test:gsub('"C1|', '"C1|2|1792000500|0|c|1001|1436|0|40|0|160|0||||6303x1", -- [0]\r\n"C1|', 1)
		writeFile(made.account .. "/SavedVariables/Pagle.lua", played)
		writeFile(made.account .. "/SavedVariables/Pagle.lua.bak", test)
		writeFile(made.account .. "/SavedVariables/Pagle_Ledger.lua", "\r\nPagleLedgerDB = {\r\n}\r\n")
		writeFile(
			made.account .. "/SavedVariables/Pagle_Ledger.lua.bak",
			readFileOrNil(FIXTURE .. "/SavedVariables/Pagle_Ledger.lua")
		)
		local restoreErr, restoreCode = modeRun(made, "--restore", NOW + 20)

		it(
			"--install puts the test log in as the account's Pagle.lua and keeps the one it replaced in replaced-<time>/",
			function()
				assert.are.equal("", installErr)
				assert.are.equal(0, installCode)
				local fixture = fixtureFiles()
				assert.are.equal(test, installed["Pagle.lua"])
				assert.are.equal(fixture["Pagle.lua.bak"], installed["Pagle.lua.bak"])
				assert.are.equal(fixture["Pagle_Ledger.lua"], installed["Pagle_Ledger.lua"])
				assert.is_nil(installed["Pagle_Ledger.lua.bak"])
				assert.are.same({ "Pagle.lua", "original", "replaced-20261014-174650", "stage.txt" }, afterInstall)
				assert.are.equal(
					fixture["Pagle.lua"],
					readFileOrNil(made.stage .. "/replaced-20261014-174650/Pagle.lua")
				)
			end
		)

		it("--restore puts the original files back byte for byte and removes the one that wasn't there", function()
			assert.are.equal("", restoreErr)
			assert.are.equal(0, restoreCode)
			assert.are.same(fixtureFiles(), savedFiles(made.account))
		end)

		it("--restore keeps the played test files it replaced", function()
			local kept = made.stage .. "/replaced-20261014-174700"
			assert.are.equal(played, readFileOrNil(kept .. "/Pagle.lua"))
			assert.are.equal(test, readFileOrNil(kept .. "/Pagle.lua.bak"))
			assert.are.equal("\r\nPagleLedgerDB = {\r\n}\r\n", readFileOrNil(kept .. "/Pagle_Ledger.lua"))
		end)
	end)

	describe("a second preset made while a test log is installed (--preset: the backup from its stage)", function()
		local made = make("level10")
		local first = made.stage
		modeRun(made, "--install", NOW + 1)
		local _, err, code = run(
			{ "--account", made.account, "--preset", "catches1000", "--out", made.out, "--catalogue", CATALOGUE },
			NOW + 2
		)
		local second = made.out .. "/" .. made.account:match("[^/]*$") .. "/20261014-174642-catches1000"
		local switchErr, switchCode = modeRun(made, "--install", NOW + 3)
		local switched = readFileOrNil(made.account .. "/SavedVariables/Pagle.lua")
		local restoreErr, restoreCode = modeRun(made, "--restore", NOW + 4)

		it("backs up the real files from the installed test log's stage, not the test log", function()
			assert.are.equal("", err)
			assert.are.equal(0, code)
			for name, text in pairs(fixtureFiles()) do
				assert.are.equal(text, readFileOrNil(second .. "/original/" .. name))
			end
			assert.are.equal(fixtureFiles()["Pagle.lua"], readFileOrNil(first .. "/original/Pagle.lua"))
		end)

		it("installs over the first test log, and --restore then brings back the real files", function()
			assert.are.equal("", switchErr .. restoreErr)
			assert.are.equal(0, switchCode)
			assert.are.equal(readFileOrNil(second .. "/Pagle.lua"), switched)
			assert.are.equal(0, restoreCode)
			assert.are.same(fixtureFiles(), savedFiles(made.account))
		end)
	end)

	describe(
		"every Pagle addon's SavedVariables file, through --preset, a game played and --restore (--preset, --restore)",
		function()
			-- A SavedVariables file holding one table, as the client writes it.
			local function svFile(name, key)
				return "\r\n" .. name .. ' = {\r\n["' .. key .. '"] = true,\r\n}\r\n'
			end
			-- An account that has Hunts, Stats and the Tackle Board too, and another addon's file beside them.
			local made = make("level10", nil, nil, nil, {
				["Pagle_Hunts.lua"] = svFile("PagleHuntsDB", "real"),
				["Pagle_Hunts.lua.bak"] = svFile("PagleHuntsDB", "older"),
				["Pagle_Stats.lua"] = svFile("PagleStatsDB", "real"),
				["Pagle_TackleBoard.lua.bak"] = svFile("PagleTackleBoardDB", "older"),
				["Angleur.lua"] = svFile("AngleurDB", "real"),
			})
			local before = savedFiles(made.account)
			local backedUp = folders(made.stage .. "/original")
			modeRun(made, "--install", NOW + 10)
			-- The logout after the play rewrites every Pagle file but the test log, adding the ones that weren't there, and
			-- Angleur's file too.
			local played = {}
			for _, name in ipairs(SV_FILES) do
				if name ~= "Pagle.lua" then
					played[name] = svFile("Played", name)
					writeFile(made.account .. "/SavedVariables/" .. name, played[name])
				end
			end
			writeFile(made.account .. "/SavedVariables/Angleur.lua", svFile("AngleurDB", "played"))
			local restoreErr, restoreCode = modeRun(made, "--restore", NOW + 20)

			it("--preset backs up each one there is, and no other addon's file", function()
				assert.are.same({
					"Pagle.lua",
					"Pagle.lua.bak",
					"Pagle_Hunts.lua",
					"Pagle_Hunts.lua.bak",
					"Pagle_Ledger.lua",
					"Pagle_QoL.lua",
					"Pagle_Stats.lua",
					"Pagle_TackleBoard.lua.bak",
				}, backedUp)
				for _, name in ipairs(backedUp) do
					assert.are.equal(before[name], readFileOrNil(made.stage .. "/original/" .. name))
				end
			end)

			it("--restore puts each one back byte for byte and removes the ones the play added", function()
				assert.are.equal("", restoreErr)
				assert.are.equal(0, restoreCode)
				assert.are.same(before, savedFiles(made.account))
				assert.is_nil(readFileOrNil(made.account .. "/SavedVariables/Pagle_TackleBoard.lua"))
				assert.is_nil(readFileOrNil(made.account .. "/SavedVariables/Pagle_QoL.lua.bak"))
			end)

			it("--restore keeps every file it replaced, and leaves another addon's file as the play left it", function()
				local kept = made.stage .. "/replaced-20261014-174700/"
				for name, text in pairs(played) do
					assert.are.equal(text, readFileOrNil(kept .. name))
				end
				assert.is_nil(readFileOrNil(kept .. "Angleur.lua"))
				assert.are.equal(
					svFile("AngleurDB", "played"),
					readFileOrNil(made.account .. "/SavedVariables/Angleur.lua")
				)
			end)
		end
	)

	describe("--install and --restore of a boardday test log (in-game-verification.md › Test logs)", function()
		local made = make("boardday", NOW, BOARD_FIXTURE)
		local test = readFile(made.stage .. "/Pagle.lua")
		local installErr, installCode = modeRun(made, "--install", NOW + 10)
		local installed = savedFiles(made.account)
		-- What the client writes at the logout after playing it: the live step's day record, the old files as .bak, and
		-- the Tackle Board's projection rebuilt for the test log, with a .bak there wasn't before.
		local played = test:gsub('"C1|', '"A1|2|1792000010|0|TackleBoard|day|1791990000;1791903600", -- [0]\r\n"C1|', 1)
		local sv = made.account .. "/SavedVariables/"
		writeFile(sv .. "Pagle.lua", played)
		writeFile(sv .. "Pagle.lua.bak", test)
		writeFile(sv .. "Pagle_TackleBoard.lua", "\r\nPagleTackleBoardDB = {\r\n}\r\n")
		writeFile(sv .. "Pagle_TackleBoard.lua.bak", readFile(BOARD_FIXTURE .. "/SavedVariables/Pagle_TackleBoard.lua"))
		local restoreErr, restoreCode = modeRun(made, "--restore", NOW + 20)

		it("--install puts only the test log in, leaving Pagle_TackleBoard.lua as it was", function()
			assert.are.equal("", installErr)
			assert.are.equal(0, installCode)
			assert.are.equal(test, installed["Pagle.lua"])
			assert.are.equal(savedFiles(BOARD_FIXTURE)["Pagle_TackleBoard.lua"], installed["Pagle_TackleBoard.lua"])
		end)

		it(
			"--restore puts Pagle.lua and Pagle_TackleBoard.lua back byte for byte and removes the .bak that wasn't there",
			function()
				assert.are.equal("", restoreErr)
				assert.are.equal(0, restoreCode)
				assert.are.same(savedFiles(BOARD_FIXTURE), savedFiles(made.account))
				local kept = made.stage .. "/replaced-20261014-174700"
				assert.are.equal(played, readFile(kept .. "/Pagle.lua"))
				assert.are.equal("\r\nPagleTackleBoardDB = {\r\n}\r\n", readFile(kept .. "/Pagle_TackleBoard.lua"))
			end
		)
	end)

	-- The wagers preset (#310, M8 exit check step 7) over the fixture account, with the fixture Hunt list and event pool
	-- (spec/scripts/fixtures/TestLogHuntList.lua and TestLogEventList.lua: one event per band) and the rotation's origin
	-- moved to Thursday 8 October 15:00 UTC (1791471600) by a loadfile that sets it after logic/Rotation.lua loads, as a
	-- spec moves it in `prepare` (ns.ROTATION_ORIGIN is read at call time). At NOW (Wednesday 14 October 17:46) the
	-- current fallback slot is 2, the high band's fixture_westfall_night, from 14 October 15:00 (1791990000); slot 1, the
	-- one before, is the mid band's fixture_westfall_dawn, 11 October 15:00 (1791730800) to 14 October 15:00; slot 3,
	-- ahead, the low band's fixture_elwynn_evening (HNT-R152, HNT-R156).
	local WAGERS_ORIGIN, SLOT = 1791471600, 72 * 3600
	local PREVIOUS, CURRENT = WAGERS_ORIGIN + SLOT, WAGERS_ORIGIN + 2 * SLOT
	local WAGERS_ARGS = {
		"--huntlist",
		"spec/scripts/fixtures/TestLogHuntList.lua",
		"--eventlist",
		"spec/scripts/fixtures/TestLogEventList.lua",
	}

	-- A loadfile that loads every file as loadfile does, but runs Hunts' logic/Rotation.lua with the rotation's origin
	-- at `origin` (HNT-R152, Tunables).
	local function withOrigin(origin)
		return function(path)
			local chunk = loadfile(path)
			if not (chunk and path:match("Pagle_Hunts/logic/Rotation%.lua$")) then
				return chunk
			end
			return function(addon, ns)
				setfenv(chunk, getfenv(1))
				chunk(addon, ns)
				ns.ROTATION_ORIGIN = origin
			end
		end
	end

	-- What a data file in an addon's shape (`ns.<field> = …`) sets, run as the client runs an addon's files.
	local function fixtureData(path, field)
		local data = {}
		local chunk = assert(loadfile(path))
		setfenv(chunk, setmetatable({ Pagle = {} }, { __index = _G }))
		chunk("Pagle_Hunts", data)
		return data[field]
	end
	local WAGERS_LIST = fixtureData("spec/scripts/fixtures/TestLogHuntList.lua", "huntList")
	local WAGERS_POOL = fixtureData("spec/scripts/fixtures/TestLogEventList.lua", "eventList")
	local CATALOGUE_DATA = fixtureData(CATALOGUE, "catalogue")

	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
	local huntsSupport = dofile("spec/Pagle_Hunts/support.lua")

	-- Hunts' own logic/ as OnInitialize builds it (HNT-R136), on FakePagle over the fixture catalogue, Hunt list and
	-- pool, with the origin moved: the oracle a wagers test log is folded with.
	local huntsNs = (function()
		local fake = newFakePagle()
		fake.setCatalogue(CATALOGUE_DATA)
		local loaded = huntsSupport.load(fake, {
			list = WAGERS_LIST,
			events = WAGERS_POOL,
			prepare = function(loading)
				loading.ns.ROTATION_ORIGIN = WAGERS_ORIGIN
			end,
		})
		return loaded.ns
	end)()

	-- A PagleLog folded with Hunts' projection from nothing, as a first build does (HNT-R136, HNT-R149): the state and
	-- how many entries didn't decode. A `run` record's earlier Casts are read back through the same log.
	local function huntsFolded(log)
		local global = { decodeErrors = 0 }
		local catchLog = core.OpenCatchLog(log, global, NOW, catalogue.GetItem)
		local def = huntsNs.ProjectionDef({}, huntsNs.lookups, {
			ReportCoinsEarned = function() end,
			ReportXPEarned = function() end,
			IterateCatches = function(afterSeq)
				return catchLog:Iterate(afterSeq, "Hunts")
			end,
			ServerTime = function()
				return NOW
			end,
		})
		local state = def.reset()
		for record in catchLog:Iterate(0, "Hunts") do
			def.apply(state, record, "rebuild")
		end
		return state, global.decodeErrors
	end

	-- Hunts' records in a PagleLog, in order, as "kind payload" (hunts.md › Contracts), and the time of each.
	local function huntsRecords(log)
		local out, times = {}, {}
		for record in core.OpenCatchLog(log, { decodeErrors = 0 }, NOW):Iterate(0, "Hunts") do
			if record.kind == "module" then
				out[#out + 1] = record.recordKind .. " " .. record.payload
				times[#times + 1] = record.time
			end
		end
		return out, times
	end

	describe("--preset wagers at NOW (#310, in-game-verification.md › Test logs)", function()
		local made = make("wagers", NOW, nil, { loadfile = withOrigin(WAGERS_ORIGIN) }, nil, WAGERS_ARGS)
		local text = made.stage and readFile(made.stage .. "/Pagle.lua")
		local log = text and globalsOf(text).PagleLog
		local key = "fixture_westfall_dawn@" .. PREVIOUS

		it("exits 0 and makes one dated test log for the account", function()
			assert.are.equal("", made.err)
			assert.are.equal(0, made.code)
			assert.are.same({ "20261014-174640-wagers" }, made.stages)
		end)

		it("writes a test log Core's codec decodes whole, with a new logId (LOG-R15, LOG-R16)", function()
			local records, undecodable = decoded(log)
			assert.are.equal(0, undecodable)
			assert.are.equal(#log.entries, #records + #huntsRecords(log))
			assert.is_true(log.test)
			assert.are.equal(16, #log.logId)
			assert.are_not.equal(ORIGINAL_LOG_ID, log.logId)
		end)

		it(
			"logs slot 1's run of its pick, source r, an hour into the slot, and the current slot's not at all (HNT-R150, HNT-R152)",
			function()
				local records, times = huntsRecords(log)
				assert.are.same({ ("run fixture_westfall_dawn|%d|%d|r"):format(PREVIOUS, CURRENT) }, records)
				assert.are.same({ PREVIOUS + 3600 }, times)
				assert.are.equal("fixture_westfall_dawn", huntsNs.RotationPick(huntsNs.events:Events(), 1).id)
			end
		)

		it(
			"catches with Bram in Westfall, the event's zone, after the run record and before the slot's end (HNT-R144)",
			function()
				local casts = 0
				for _, record in ipairs((decoded(log))) do
					assert.is_true(record.time >= PREVIOUS and record.time < CURRENT)
					if record.kind == "cast" then
						casts = casts + 1
						assert.are.equal(2, record.char)
						assert.are.equal("caught", record.outcome)
						assert.are.equal(40, record.conditions.zone)
						assert.are.equal(160, record.conditions.skillRank)
						assert.is_true(record.time > PREVIOUS + 3600)
					end
				end
				assert.is_true(casts > 0)
			end
		)

		it(
			"folds through Hunts' own logic/ to one known run, completed, 1 settled, and no run on now (HNT-R143, HNT-R146, HNT-R148)",
			function()
				local state, undecodable = huntsFolded(log)
				assert.are.equal(0, undecodable)
				local keys = {}
				for runKey in pairs(state.runs) do
					keys[#keys + 1] = runKey
				end
				assert.are.same({ key }, keys)
				local known = state.runs[key]
				assert.are.same({ PREVIOUS, CURRENT, "r" }, { known.start, known.end_, known.source })
				assert.is_true(known.completedAt > PREVIOUS and known.completedAt < CURRENT)
				assert.are.equal(1, state.settled)
				for _, hunt in ipairs(huntsNs.events:Event("fixture_westfall_dawn").hunts) do
					assert.is_truthy(known.hunts[hunt.id].reached[1])
				end
				assert.are.same({}, huntsNs.RunOn(state, NOW))
			end
		)

		it("catches the Timed Hunt's tier inside its realm window, from the realm offset (HNT-R5, LOG-R49)", function()
			local state = huntsFolded(log)
			local tier = state.runs[key].hunts.fixture_westfall_dawn_mackerel.reached[1]
			for _, record in ipairs((decoded(log))) do
				if record.kind == "cast" and record.items[1].catchId == tier.catchId then
					assert.is_true(record.conditions.minute >= 300 and record.conditions.minute < 480)
				end
			end
		end)

		it("draws the Big ones Hunt's Catches until their Size bands qualify (HNT-R14, LOG-R65)", function()
			local state = huntsFolded(log)
			local progress = state.runs[key].hunts.fixture_westfall_dawn_big
			assert.are.equal(2, progress.count)
			local bands = {}
			for _, record in ipairs((decoded(log))) do
				if record.kind == "cast" and record.items[1].itemID == 6299 then
					bands[#bands + 1] = record.items[1].size.band
				end
			end
			-- Every Catch but the two that counted came short of band 2, so the last one is a qualifying one.
			assert.is_true(#bands > 2)
			assert.is_true(bands[#bands] >= 2)
			local short = 0
			for _, band in ipairs(bands) do
				short = short + (band < 2 and 1 or 0)
			end
			assert.are.equal(#bands - 2, short)
		end)

		it(
			"leaves the live step at login to log the current slot's run, its pick, and nothing else (HNT-R151, HNT-R153)",
			function()
				local plan = huntsNs.PlanRunLog({
					state = (huntsFolded(log)),
					now = NOW,
					snapshot = { companion = "missing", events = {}, runs = {} },
					pool = huntsNs.events:Events(),
				})
				assert.are.same({
					{
						kind = "run",
						payload = ("fixture_westfall_night|%d|%d|r"):format(CURRENT, CURRENT + SLOT),
					},
				}, plan)
			end
		)

		it("prints the rotation, the run and its fold, and what the login logs (HNT-R151, HNT-R160)", function()
			assert.are.equal(
				"== Test log wagers: the last fallback slot's run settled, the current slot's not logged yet"
					.. " (M8 exit check step 7)",
				made.lines[1]
			)
			local state = huntsFolded(log)
			local casts = 0
			for _, record in ipairs((decoded(log))) do
				casts = casts + (record.kind == "cast" and 1 or 0)
			end
			assert.matches(("(A1 1, B1 1, C1 %d, S1 2)"):format(casts), made.lines[3], 1, true)
			assert.are.equal(
				"rotation: origin 2026-10-08 15:00 UTC; now in slot 2, 2026-10-14 15:00 UTC to 2026-10-17 15:00 UTC, high band;"
					.. " 3 events in the pool (spec/scripts/fixtures/TestLogEventList.lua)",
				made.lines[4]
			)
			assert.are.equal(
				(
					"run: slot 1's pick, fixture_westfall_dawn, mid band, 2026-10-11 15:00 UTC to 2026-10-14 15:00 UTC, logged"
					.. " 2026-10-11 16:00 UTC; settled %s by %d Casts in zone 40"
				):format(os.date("!%Y-%m-%d %H:%M UTC", state.runs[key].completedAt), casts),
				made.lines[5]
			)
			local known = state.runs[key]
			assert.are.equal(
				("hunts: fixture_westfall_dawn_haul %d (tier %d), fixture_westfall_dawn_mackerel %d (tier %d),"):format(
					known.hunts.fixture_westfall_dawn_haul.count,
					#known.hunts.fixture_westfall_dawn_haul.reached,
					known.hunts.fixture_westfall_dawn_mackerel.count,
					#known.hunts.fixture_westfall_dawn_mackerel.reached
				)
					.. (" fixture_westfall_dawn_big %d (tier %d)"):format(
						known.hunts.fixture_westfall_dawn_big.count,
						#known.hunts.fixture_westfall_dawn_big.reached
					),
				made.lines[6]
			)
			assert.are.equal(
				("fold: 1 run known, 1 wager settled, no run on now; Hunts' Coins %d, Angler XP %d (catalogue: %s)"):format(
					state.coins,
					state.xp,
					CATALOGUE
				),
				made.lines[7]
			)
			assert.are.equal(
				"at login: the live step logs slot 2's run of fixture_westfall_night, on until 2026-10-17 15:00 UTC;"
					.. " the board then shows it on and fixture_elwynn_evening ahead, and nothing of fixture_westfall_dawn",
				made.lines[8]
			)
			local printed = table.concat(made.lines, "\n")
			assert.matches("log in as Bram Reed before 2026-10-17 15:00 UTC", printed, 1, true)
			assert.matches("1 wager settled", printed, 1, true)
		end)

		it("keeps the current slot's end in stage.txt, so --install refuses after it (HNT-R152)", function()
			assert.matches(("\nnextReset %d\n$"):format(CURRENT + SLOT), readFile(made.stage .. "/stage.txt"))
		end)
	end)

	describe("--preset veteran at NOW (in-game-verification.md › Test logs)", function()
		local made = make("veteran", NOW, nil, { loadfile = withOrigin(WAGERS_ORIGIN) }, nil, {
			"--huntlist",
			"spec/scripts/fixtures/TestLogVeteranHuntList.lua",
			"--eventlist",
			"spec/scripts/fixtures/TestLogEventList.lua",
		})
		local text = made.stage and readFile(made.stage .. "/Pagle.lua")
		local log = text and globalsOf(text).PagleLog

		it("exits 0 and makes one dated test log for the account", function()
			assert.are.equal("", made.err)
			assert.are.equal(0, made.code)
			assert.are.same({ "20261014-174640-veteran" }, made.stages)
		end)

		it("writes a test log Core's codec decodes whole, with its grants (catch-log.md › Data)", function()
			local records, undecodable = decoded(log)
			assert.are.equal(0, undecodable)
			assert.are.equal(#log.entries, #records + #huntsRecords(log))
			assert.is_true(log.test)
			assert.are.equal(3 * 201000 + 60000, log.devXP)
			assert.is_true(log.devCoins > 0 and log.devCoins <= 50000)
			assert.are.equal(PREVIOUS - 22 * 86400, log.devHuntsSince)
		end)

		it(
			"puts the standing Hunt out from the release date, so the history's Casts give it a tier (HNT-R2)",
			function()
				local list = huntsNs.HuntListFrom(
					fixtureData("spec/scripts/fixtures/TestLogVeteranHuntList.lua", "huntList"),
					log.devHuntsSince
				)
				assert.are.equal(log.devHuntsSince, list.hunts[1].since)
				local printed = table.concat(made.lines, "\n")
				assert.matches("Hunts: 1 standing Hunt with a tier", printed, 1, true)
			end
		)

		it("holds three Prestige entries, ranks 1 to 3, each snapshot a full climb above the last (AXP-R5)", function()
			local prestiges = {}
			for _, record in ipairs((decoded(log))) do
				if record.kind == "prestige" then
					prestiges[#prestiges + 1] = { record.rank, record.activityXP }
				end
			end
			assert.are.same({ { 1, 201000 }, { 2, 402000 }, { 3, 603000 } }, prestiges)
		end)

		it("leaves the old run settled and the current slot's run on, part played (HNT-R143, HNT-R148)", function()
			local state = huntsFolded(log)
			local old = state.runs["fixture_westfall_dawn@" .. PREVIOUS]
			assert.is_truthy(old and old.completedAt)
			local on = huntsNs.RunOn(state, NOW)
			assert.are.equal(1, #on)
			assert.are.equal(("fixture_westfall_night@%d"):format(CURRENT), on[1].key)
		end)

		it("prints its aim and keeps the current slot's end in stage.txt", function()
			assert.are.equal(
				"== Test log veteran: Prestige 3, Hunts under way, a Pagle Wagers run on and 50,000 Coins to spend"
					.. " (a seasoned account to play and look around as)",
				made.lines[1]
			)
			assert.matches(("\nnextReset %d\n$"):format(CURRENT + SLOT), readFile(made.stage .. "/stage.txt"))
		end)
	end)

	-- The wagers test log made at NOW, logged into on FakePagle at NOW with Hunts over the fixture catalogue, Hunt list
	-- and pool, the origin moved, and no companion (Pagle_Content missing), as the dev does after --install: the first
	-- build, then the live step once PushedContentReady has fired (HNT-R111, HNT-R151).
	describe("a wagers test log at its login", function()
		local made = make("wagers", NOW, nil, { loadfile = withOrigin(WAGERS_ORIGIN) }, nil, WAGERS_ARGS)
		local log = globalsOf(readFile(made.stage .. "/Pagle.lua")).PagleLog
		local state = huntsFolded(log)
		local casts = 0
		for _, record in ipairs((decoded(log))) do
			casts = casts + (record.kind == "cast" and 1 or 0)
		end
		local r = huntsSupport.start({
			catalogue = CATALOGUE_DATA,
			list = WAGERS_LIST,
			events = WAGERS_POOL,
			prepare = function(loading)
				loading.ns.ROTATION_ORIGIN = WAGERS_ORIGIN
			end,
			history = function(fake)
				fake.catchLog.data = log
			end,
			from = NOW - SERVER_TIME,
		})
		r.fake.nextFrame()
		r.loaded.client.runTimers()
		local fake = r.fake

		it("writes Hunts up from the test log: 1 wager settled, its Coins and Angler XP (HNT-R111)", function()
			local sections = {}
			for _, section in ipairs(fake.writeUps) do
				if section.module == "Hunts" then
					sections[#sections + 1] = { section.heading, unpack(section.lines) }
				end
			end
			assert.are.same({
				{
					("Your Hunts were written up from %d Casts"):format(casts),
					"1 wager settled",
					("Pagle Coins +%d"):format(state.coins),
					("Angler XP +%d"):format(state.xp),
				},
			}, sections)
			assert.are.equal(
				"Hunts: 0 of 0 done · 0 titles · 1 wager settled",
				fake.global.summary.lines.Hunts.lines.hunts
			)
		end)

		it("logs the current slot's run live, after the old one (HNT-R150, HNT-R151)", function()
			assert.are.same({
				("run fixture_westfall_dawn|%d|%d|r"):format(PREVIOUS, CURRENT),
				("run fixture_westfall_night|%d|%d|r"):format(CURRENT, CURRENT + SLOT),
			}, huntsRecords(fake.catchLog.data))
		end)

		it(
			"shows the current slot's run on and the next ahead, and nothing of the ended run (HNT-R143, HNT-R160)",
			function()
				local shown = {}
				for i, entry in ipairs(r.ns.RunsShown(r.ns.State(), NOW)) do
					shown[i] = entry.key .. (entry.on and " on" or " ahead")
				end
				assert.are.same({
					"fixture_westfall_night@" .. CURRENT .. " on",
					"fixture_elwynn_evening@" .. CURRENT + SLOT .. " ahead",
				}, shown)
				assert.are.equal(1, r.ns.State().settled)
			end
		)
	end)

	describe("--install and --restore of a wagers test log (in-game-verification.md › Test logs)", function()
		local made = make("wagers", NOW, nil, { loadfile = withOrigin(WAGERS_ORIGIN) }, nil, WAGERS_ARGS)
		local test = readFile(made.stage .. "/Pagle.lua")
		local installErr, installCode = modeRun(made, "--install", NOW + 10)
		local installed = savedFiles(made.account)
		-- What the client writes at the logout after playing it: the live step's run record, the old file as .bak, and
		-- Hunts' projection rebuilt for the test log, in a Pagle_Hunts.lua there wasn't before.
		local played = test:gsub(
			'"C1|',
			('"A1|2|%d|0|Hunts|run|fixture_westfall_night|%d|%d|r", -- [0]\r\n"C1|'):format(
				NOW + 30,
				CURRENT,
				CURRENT + SLOT
			),
			1
		)
		local sv = made.account .. "/SavedVariables/"
		writeFile(sv .. "Pagle.lua", played)
		writeFile(sv .. "Pagle.lua.bak", test)
		writeFile(sv .. "Pagle_Hunts.lua", "\r\nPagleHuntsDB = {\r\n}\r\n")
		local restoreErr, restoreCode = modeRun(made, "--restore", NOW + 20)

		it("--install puts the test log in as the account's Pagle.lua", function()
			assert.are.equal("", installErr)
			assert.are.equal(0, installCode)
			assert.are.equal(test, installed["Pagle.lua"])
		end)

		it(
			"--restore puts the real files back byte for byte and removes Pagle_Hunts.lua, which wasn't there",
			function()
				assert.are.equal("", restoreErr)
				assert.are.equal(0, restoreCode)
				assert.are.same(fixtureFiles(), savedFiles(made.account))
				assert.are.equal(played, readFile(made.stage .. "/replaced-20261014-174700/Pagle.lua"))
			end
		)
	end)

	describe("refusing (every refusal exits 1 and changes nothing; usage errors exit 2)", function()
		it("refuses without a Pagle.lua, writing nothing", function()
			local account, out = newAccount()
			os.remove(account .. "/SavedVariables/Pagle.lua")
			local _, err, code = run({ "--account", account, "--preset", "level10", "--out", out })
			assert.are.equal(1, code)
			assert.matches("no .*/SavedVariables/Pagle.lua", err)
			assert.are.same({}, folders(out))
		end)

		it("refuses to write when the Ledger's fold of the written log misses the preset (LED-R3)", function()
			-- A Ledger whose fold credits 1,000 XP more at a build entry at real times (the script plans with times
			-- of its own, then folds the log it wrote at real times), so the written log folds past level 9.
			local function loadLying(path)
				local chunk = loadfile(path)
				if not (chunk and path:match("Pagle_Ledger/logic/Fold%.lua$")) then
					return chunk
				end
				return function(addon, ns)
					setfenv(chunk, getfenv(1))
					chunk(addon, ns)
					local newFold = ns.NewLedgerFold
					ns.NewLedgerFold = function(lookups)
						local foldOf = newFold(lookups)
						local apply = foldOf.apply
						foldOf.apply = function(state, record, ...)
							local earned = apply(state, record, ...)
							if record.kind == "build" and record.time > NOW - 365 * 86400 then
								state.xp = state.xp + 1000
							end
							return earned
						end
						return foldOf
					end
				end
			end
			local account, out = newAccount()
			local args = { "--account", account, "--preset", "level10", "--out", out, "--catalogue", CATALOGUE }
			local _, err, code = run(args, NOW, { loadfile = loadLying })
			assert.are.equal(1, code)
			assert.matches("misses the preset: the fold lands at level 10", err, 1, true)
			assert.are.same({}, folders(out))
		end)

		it(
			"--install refuses when the account's Pagle.lua changed since the backup, changing nothing (--install)",
			function()
				local made = make("level10")
				local real = readFileOrNil(made.account .. "/SavedVariables/Pagle.lua") .. "\r\n"
				writeFile(made.account .. "/SavedVariables/Pagle.lua", real)
				local err, code = modeRun(made, "--install", NOW + 1)
				assert.are.equal(1, code)
				assert.matches("isn't the one backed up", err, 1, true)
				assert.are.equal(real, readFileOrNil(made.account .. "/SavedVariables/Pagle.lua"))
				assert.are.same({ "Pagle.lua", "original", "stage.txt" }, folders(made.stage))
			end
		)

		it("--restore refuses while the real log is in place, changing nothing (--restore)", function()
			local made = make("level10")
			local err, code = modeRun(made, "--restore", NOW + 1)
			assert.are.equal(1, code)
			assert.matches("not a test log made here", err, 1, true)
			assert.are.same(fixtureFiles(), savedFiles(made.account))
		end)

		it("boardday refuses, writing nothing, when the log has no start or day record (TKB-R80)", function()
			local made = make("boardday")
			assert.are.equal(1, made.code)
			assert.matches("no Tackle Board start or day record", made.err, 1, true)
			assert.are.same({}, made.stages)
		end)

		it(
			"boardday refuses, writing nothing, when the board's latest boundary is older than a week (TKB-R12)",
			function()
				local made = make("boardday", NOW + 8 * 86400, BOARD_FIXTURE)
				assert.are.equal(1, made.code)
				assert.matches("older than a week", made.err, 1, true)
				assert.are.same({}, made.stages)
			end
		)

		it("boardday refuses to write when the Casts fall short of the Haul Notice's need (TKB-R45)", function()
			-- A record encoder that writes the Haul Notice's need one higher than the Casts the script plans for it.
			local function loadShort(path)
				local chunk = loadfile(path)
				if not (chunk and path:match("Pagle_TackleBoard/logic/Records%.lua$")) then
					return chunk
				end
				return function(addon, ns)
					setfenv(chunk, getfenv(1))
					chunk(addon, ns)
					local encode = ns.EncodeIssue
					ns.EncodeIssue = function(def)
						local short = {}
						for key, value in pairs(def) do
							short[key] = value
						end
						if def.type == "n" and def.kind == "haul" then
							short.need = def.need + 1
						end
						return encode(short)
					end
				end
			end
			local made = make("boardday", NOW, BOARD_FIXTURE, { loadfile = loadShort })
			assert.are.equal(1, made.code)
			assert.matches("misses the preset: no goal is done on day 0", made.err, 1, true)
			assert.are.same({}, made.stages)
		end)

		it(
			"--install refuses a boardday test log once its board day has ended, changing nothing (TKB-R12, TKB-R13)",
			function()
				local made = make("boardday", NOW, BOARD_FIXTURE)
				local err, code = modeRun(made, "--install", 1792076400)
				assert.are.equal(1, code)
				assert.matches("its board day ended at 2026-10-15 15:00 UTC", err, 1, true)
				assert.are.same(savedFiles(BOARD_FIXTURE), savedFiles(made.account))
			end
		)

		it(
			"--install refuses a showcase test log once the day after its last lit one has ended, changing nothing (TKB-R72)",
			function()
				local made = make("showcase", NOW, BOARD_FIXTURE)
				local err, code = modeRun(made, "--install", 1792162800)
				assert.are.equal(1, code)
				assert.matches("its last lit day's next day ended at 2026-10-16 15:00 UTC", err, 1, true)
				assert.are.same(savedFiles(BOARD_FIXTURE), savedFiles(made.account))
			end
		)

		it(
			"wagers refuses, writing nothing, when the current fallback slot is the rotation's first (HNT-R152)",
			function()
				local made = make("wagers", NOW, nil, { loadfile = withOrigin(NOW - 3600) }, nil, WAGERS_ARGS)
				assert.are.equal(1, made.code)
				assert.matches(
					"the current fallback slot, 0 (from 2026-10-14 16:46 UTC), is the rotation's first",
					made.err,
					1,
					true
				)
				assert.are.same({}, made.stages)
			end
		)

		it("wagers refuses, writing nothing, before the rotation's starting point (HNT-R152, HNT-R204)", function()
			local made = make("wagers", NOW, nil, { loadfile = withOrigin(NOW + 3600) }, nil, WAGERS_ARGS)
			assert.are.equal(1, made.code)
			assert.matches("the fallback rotation starts at 2026-10-14 18:46 UTC, after now", made.err, 1, true)
			assert.are.same({}, made.stages)
		end)

		it("wagers refuses, writing nothing, when the event pool is empty (HNT-R152, DATA-R98)", function()
			local pool = os.tmpname() .. ".lua"
			writeFile(pool, 'local ns = select(2, ...)\nns.eventList = { fingerprint = "0", events = {} }\n')
			local made = make("wagers", NOW, nil, { loadfile = withOrigin(WAGERS_ORIGIN) }, nil, {
				"--huntlist",
				"spec/scripts/fixtures/TestLogHuntList.lua",
				"--eventlist",
				pool,
			})
			os.remove(pool)
			assert.are.equal(1, made.code)
			assert.matches("the event pool " .. pool .. " has no event", made.err, 1, true)
			assert.are.same({}, made.stages)
		end)

		it("wagers refuses to write when the run doesn't settle in its slot (HNT-R146)", function()
			-- A record encoder that logs every run an hour long, so the slot's run has ended before its Casts.
			local origin = withOrigin(WAGERS_ORIGIN)
			local function loadShortRun(path)
				local chunk = origin(path)
				if not (chunk and path:match("Pagle_Hunts/logic/Records%.lua$")) then
					return chunk
				end
				return function(addon, ns)
					setfenv(chunk, getfenv(1))
					chunk(addon, ns)
					local encode = ns.EncodeRun
					ns.EncodeRun = function(id, start, _, source)
						return encode(id, start, start + 3600, source)
					end
				end
			end
			local made = make("wagers", NOW, nil, { loadfile = loadShortRun }, nil, WAGERS_ARGS)
			assert.are.equal(1, made.code)
			assert.matches(
				"misses the preset: the run fixture_westfall_dawn@" .. PREVIOUS .. " isn't settled",
				made.err,
				1,
				true
			)
			assert.are.same({}, made.stages)
		end)

		it(
			"--install refuses a wagers test log once its fallback slot has ended, changing nothing (HNT-R152)",
			function()
				local made = make("wagers", NOW, nil, { loadfile = withOrigin(WAGERS_ORIGIN) }, nil, WAGERS_ARGS)
				local err, code = modeRun(made, "--install", CURRENT + SLOT)
				assert.are.equal(1, code)
				assert.matches("its fallback slot ended at 2026-10-17 15:00 UTC", err, 1, true)
				assert.are.same(fixtureFiles(), savedFiles(made.account))
			end
		)

		it("exits 2 on a usage error", function()
			local _, err, code = run({ "--account", "x", "--preset", "level99" })
			assert.are.equal(2, code)
			assert.matches("no preset level99", err, 1, true)
			assert.matches(
				"the presets are level10, level60, catches1000, boardday, big5, big20, showcase, wagers",
				err,
				1,
				true
			)
			_, err, code = run({ "--account", "x", "--install", "--restore" })
			assert.are.equal(2, code)
			assert.matches("name one of --preset, --install and --restore", err, 1, true)
		end)
	end)
end)
