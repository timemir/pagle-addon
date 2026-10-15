-- scripts/make-test-log.lua: the test logs the M4 exit check plays (#172, #174). It runs over a copy of the fixture
-- account spec/scripts/fixtures/WTF/Account/M4-Test#1/, written the way the client writes it (CRLF, no indent, a
-- leading blank line): Ada and Bram, the dev's real PagleLog with Bram's Casts last, a PagleDB, Pagle.lua.bak and
-- Pagle_Ledger.lua (and no Pagle_Ledger.lua.bak). The world is spec/scripts/fixtures/TestLogCatalogue.lua
-- (--catalogue), which lists a Legend, Noise, a gated Species and a container beside ordinary Species, junk and
-- trophies. What a test log holds is read back here with Core's own codec and folded with the Ledger's own logic/,
-- the same oracle the game uses (catch-log.md › Entry formats, LED-R3). The boardday preset (#243) runs over
-- spec/scripts/fixtures/WTF/Account/M7-Test#1/: the same account with a started Tackle Board (Bram's `start`, an
-- `issue` and, last, a `day` record of Tuesday 13 October 15:00 UTC, the weekly reset too) and a
-- Pagle_TackleBoard.lua (no .bak); its test log is folded with the Tackle Board's own logic/ (TKB-R81).

local FIXTURE = "spec/scripts/fixtures/WTF/Account/M4-Test#1"
local BOARD_FIXTURE = "spec/scripts/fixtures/WTF/Account/M7-Test#1"
local CATALOGUE = "spec/scripts/fixtures/TestLogCatalogue.lua"
local NOW = 1792000000 -- 2026-10-14 17:46:40 UTC, the server time the script runs at
local ORIGINAL_LOG_ID = "5d2e8a0c4b1f7e93"
local SV_FILES = {
	"Pagle.lua",
	"Pagle.lua.bak",
	"Pagle_Ledger.lua",
	"Pagle_Ledger.lua.bak",
	"Pagle_TackleBoard.lua",
	"Pagle_TackleBoard.lua.bak",
}

local core = loadAddon("Pagle", FOREVER_GLOBALS).ns

-- busted runs on stock Lua 5.1, which has the io, os and loadfile the WoW client lacks.
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
local io = io
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os
local os = os
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
local loadfile = loadfile

local function quote(path)
	return "'" .. path:gsub("'", "'\\''") .. "'"
end

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

local function readFile(path)
	local file = io.open(path, "rb")
	if not file then
		return nil
	end
	local text = file:read("*a")
	file:close()
	return text
end

local function writeFile(path, text)
	local file = assert(io.open(path, "wb"))
	file:write(text)
	file:close()
end

-- The folders in `dir`, sorted.
local function folders(dir)
	local list = {}
	local ls = io.popen("ls -1 " .. quote(dir) .. " 2>/dev/null")
	for name in ls:lines() do
		list[#list + 1] = name
	end
	ls:close()
	table.sort(list)
	return list
end

--- Runs the script as `lua scripts/make-test-log.lua <args>` would at server time `now` (NOW by default), with
--- `globals` in its environment if given, and returns its output lines, what it wrote to stderr, and its exit code.
---@return string[] out, string err, integer code
local function run(args, now, globals)
	local out, err, code = {}, {}, nil
	local chunk = assert(loadfile("scripts/make-test-log.lua"))
	local env = setmetatable({
		arg = { [0] = "scripts/make-test-log.lua", unpack(args) },
		print = function(line)
			out[#out + 1] = line
		end,
		io = setmetatable({
			stderr = {
				write = function(_, text)
					err[#err + 1] = text
				end,
			},
		}, { __index = io }),
		os = setmetatable({
			exit = function(status)
				code = status
			end,
			time = function(date)
				return date and os.time(date) or now or NOW
			end,
		}, { __index = os }),
	}, { __index = _G })
	for key, value in pairs(globals or {}) do
		env[key] = value
	end
	setfenv(chunk, env)
	chunk(unpack(args))
	return out, table.concat(err), code
end

-- Loads a SavedVariables text as data, as the client does: the globals it assigns.
local function globalsOf(text)
	local chunk = assert(loadstring(text))
	local globals = {}
	setfenv(chunk, globals)
	chunk()
	return globals
end

-- The Ledger's world and fold over the fixture catalogue, as the Ledger builds them (LED-R3, LED-R10).
local function ledgerOver(path)
	local catalogueNs = {}
	for _, file in ipairs({ path, "addons/Pagle/logic/Catalogue.lua" }) do
		local chunk = assert(loadfile(file))
		setfenv(chunk, setmetatable({}, { __index = _G }))
		chunk("Pagle", catalogueNs)
	end
	local catalogue = catalogueNs.NewCatalogue(catalogueNs.catalogue)
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

-- A PagleLog read back with Core's codec (LOG-R16): its records, and how many entries didn't decode.
local function decoded(log)
	local global = { decodeErrors = 0 }
	local records = {}
	for record in core.OpenCatchLog(log, global, NOW):Iterate() do
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

-- Makes a test log on a new copy of the fixture account (`fixture`, else M4-Test#1) at server time `now` (else NOW);
-- returns the account, the test logs' folder, the one stage folder the run made (nil if none) and the run's output.
local function make(preset, now, fixture, globals)
	local account, out = newAccount(fixture)
	local lines, err, code =
		run({ "--account", account, "--preset", preset, "--out", out, "--catalogue", CATALOGUE }, now, globals)
	local stages = folders(out .. "/" .. account:match("[^/]*$"))
	local stage = stages[1] and out .. "/" .. account:match("[^/]*$") .. "/" .. stages[1]
	return { account = account, out = out, stage = stage, stages = stages, lines = lines, err = err, code = code }
end

describe("scripts/make-test-log.lua", function()
	describe("--preset level10 on the fixture account", function()
		local made = make("level10")
		local text = made.stage and readFile(made.stage .. "/Pagle.lua")
		local log = text and globalsOf(text).PagleLog

		it("exits 0 and makes one dated test log for the account", function()
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
					globalsOf(readFile(FIXTURE .. "/SavedVariables/Pagle.lua")).PagleLog.characters,
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
						.. " %d lifetime Catches"
					):format(state.xp, cost - into, math.ceil((cost - into) / 20), state.catches),
					made.lines[4]
				)
			end
		)

		it(
			"copies the last build entry and each character's last Skill Reading, so Core appends neither at login (LOG-R31, LOG-R36)",
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

		it("keeps every other line of Pagle.lua, PagleDB's included, byte for byte, in the client's layout", function()
			local fixture = readFile(FIXTURE .. "/SavedVariables/Pagle.lua")
			local fixtureDB = fixture:sub((fixture:find("\r\nPagleDB = {\r\n", 1, true)))
			assert.are.equal("\r\nPagleLog = {\r\n", text:sub(1, #"\r\nPagleLog = {\r\n"))
			assert.are.equal(fixtureDB, text:sub(-#fixtureDB))
			assert.is_nil(text:gsub("\r\n", ""):find("[\r\n]"))
			assert.are.same(globalsOf(fixture).PagleDB, globalsOf(text).PagleDB)
		end)

		it(
			"backs up Pagle.lua, Pagle_Ledger.lua and their .bak byte for byte, leaving out the one that's missing",
			function()
				assert.are.same(
					{ "Pagle.lua", "Pagle.lua.bak", "Pagle_Ledger.lua" },
					folders(made.stage .. "/original")
				)
				for _, name in ipairs({ "Pagle.lua", "Pagle.lua.bak", "Pagle_Ledger.lua" }) do
					assert.are.equal(
						readFile(FIXTURE .. "/SavedVariables/" .. name),
						readFile(made.stage .. "/original/" .. name)
					)
				end
			end
		)

		it("changes nothing in the account folder", function()
			assert.are.same(folders(FIXTURE .. "/SavedVariables"), folders(made.account .. "/SavedVariables"))
			for _, name in ipairs(folders(FIXTURE .. "/SavedVariables")) do
				local path = "/SavedVariables/" .. name
				assert.are.equal(readFile(FIXTURE .. path), readFile(made.account .. path))
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

	describe("--preset level60 on the fixture account #slow", function()
		local made = make("level60")
		local log = globalsOf(readFile(made.stage .. "/Pagle.lua")).PagleLog
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

	describe("--preset catches1000 on the fixture account", function()
		local made = make("catches1000")
		local log = globalsOf(readFile(made.stage .. "/Pagle.lua")).PagleLog

		it("folds to 995 lifetime Catches, five short of the 1,000 Catches milestone (LED-R42)", function()
			assert.are.equal(0, made.code)
			local state = folded((decoded(log)))
			assert.are.equal(995, state.catches)
			assert.matches("; 995 lifetime Catches$", made.lines[4])
		end)
	end)

	-- The Tackle Board's own logic/ (TKB-R81) as the game loads it, its catalogue calls over the fixture catalogue.
	local boardNs = loadAddon("Pagle_TackleBoard", FOREVER_GLOBALS).ns
	boardNs.reads.pagle = catalogue

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
	describe("--preset boardday on an account with a started board", function()
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

		it("prints what the fold found, and when to play it", function()
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
			files[name] = readFile(account .. "/SavedVariables/" .. name)
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

	describe("--install, a game played, then --restore", function()
		local made = make("level10")
		local test = readFile(made.stage .. "/Pagle.lua")
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
			readFile(FIXTURE .. "/SavedVariables/Pagle_Ledger.lua")
		)
		local restoreErr, restoreCode = modeRun(made, "--restore", NOW + 20)

		it("--install puts the test log in as the account's Pagle.lua and keeps the one it replaced", function()
			assert.are.equal("", installErr)
			assert.are.equal(0, installCode)
			local fixture = fixtureFiles()
			assert.are.equal(test, installed["Pagle.lua"])
			assert.are.equal(fixture["Pagle.lua.bak"], installed["Pagle.lua.bak"])
			assert.are.equal(fixture["Pagle_Ledger.lua"], installed["Pagle_Ledger.lua"])
			assert.is_nil(installed["Pagle_Ledger.lua.bak"])
			assert.are.same({ "Pagle.lua", "original", "replaced-20261014-174650", "stage.txt" }, afterInstall)
			assert.are.equal(fixture["Pagle.lua"], readFile(made.stage .. "/replaced-20261014-174650/Pagle.lua"))
		end)

		it("--restore puts the original files back byte for byte and removes the one that wasn't there", function()
			assert.are.equal("", restoreErr)
			assert.are.equal(0, restoreCode)
			assert.are.same(fixtureFiles(), savedFiles(made.account))
		end)

		it("--restore keeps the played test files it replaced", function()
			local kept = made.stage .. "/replaced-20261014-174700"
			assert.are.equal(played, readFile(kept .. "/Pagle.lua"))
			assert.are.equal(test, readFile(kept .. "/Pagle.lua.bak"))
			assert.are.equal("\r\nPagleLedgerDB = {\r\n}\r\n", readFile(kept .. "/Pagle_Ledger.lua"))
		end)
	end)

	describe("a second preset made while a test log is installed", function()
		local made = make("level10")
		local first = made.stage
		modeRun(made, "--install", NOW + 1)
		local _, err, code = run(
			{ "--account", made.account, "--preset", "catches1000", "--out", made.out, "--catalogue", CATALOGUE },
			NOW + 2
		)
		local second = made.out .. "/" .. made.account:match("[^/]*$") .. "/20261014-174642-catches1000"
		local switchErr, switchCode = modeRun(made, "--install", NOW + 3)
		local switched = readFile(made.account .. "/SavedVariables/Pagle.lua")
		local restoreErr, restoreCode = modeRun(made, "--restore", NOW + 4)

		it("backs up the real files from the installed test log's stage, not the test log", function()
			assert.are.equal("", err)
			assert.are.equal(0, code)
			for name, text in pairs(fixtureFiles()) do
				assert.are.equal(text, readFile(second .. "/original/" .. name))
			end
			assert.are.equal(fixtureFiles()["Pagle.lua"], readFile(first .. "/original/Pagle.lua"))
		end)

		it("installs over the first test log, and --restore then brings back the real files", function()
			assert.are.equal("", switchErr .. restoreErr)
			assert.are.equal(0, switchCode)
			assert.are.equal(readFile(second .. "/Pagle.lua"), switched)
			assert.are.equal(0, restoreCode)
			assert.are.same(fixtureFiles(), savedFiles(made.account))
		end)
	end)

	describe("--install and --restore of a boardday test log", function()
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

	describe("refusing", function()
		it("refuses without a Pagle.lua, writing nothing", function()
			local account, out = newAccount()
			os.remove(account .. "/SavedVariables/Pagle.lua")
			local _, err, code = run({ "--account", account, "--preset", "level10", "--out", out })
			assert.are.equal(1, code)
			assert.matches("no .*/SavedVariables/Pagle.lua", err)
			assert.are.same({}, folders(out))
		end)

		it("refuses to write when the Ledger's fold of the written log misses the preset", function()
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

		it("--install refuses when the account's Pagle.lua changed since the backup, changing nothing", function()
			local made = make("level10")
			local real = readFile(made.account .. "/SavedVariables/Pagle.lua") .. "\r\n"
			writeFile(made.account .. "/SavedVariables/Pagle.lua", real)
			local err, code = modeRun(made, "--install", NOW + 1)
			assert.are.equal(1, code)
			assert.matches("isn't the one backed up", err, 1, true)
			assert.are.equal(real, readFile(made.account .. "/SavedVariables/Pagle.lua"))
			assert.are.same({ "Pagle.lua", "original", "stage.txt" }, folders(made.stage))
		end)

		it("--restore refuses while the real log is in place, changing nothing", function()
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

		it("boardday refuses, writing nothing, when the board's latest boundary is older than a week", function()
			local made = make("boardday", NOW + 8 * 86400, BOARD_FIXTURE)
			assert.are.equal(1, made.code)
			assert.matches("older than a week", made.err, 1, true)
			assert.are.same({}, made.stages)
		end)

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

		it("--install refuses a boardday test log once its board day has ended, changing nothing", function()
			local made = make("boardday", NOW, BOARD_FIXTURE)
			local err, code = modeRun(made, "--install", 1792076400)
			assert.are.equal(1, code)
			assert.matches("its board day ended at 2026-10-15 15:00 UTC", err, 1, true)
			assert.are.same(savedFiles(BOARD_FIXTURE), savedFiles(made.account))
		end)

		it("exits 2 on a usage error", function()
			local _, err, code = run({ "--account", "x", "--preset", "level99" })
			assert.are.equal(2, code)
			assert.matches("no preset level99", err, 1, true)
			_, err, code = run({ "--account", "x", "--install", "--restore" })
			assert.are.equal(2, code)
			assert.matches("name one of --preset, --install and --restore", err, 1, true)
		end)
	end)
end)
