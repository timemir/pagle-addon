-- Pagle's backend folds the Catch log through logic/ alone (#223, #76 item 5). Its projection driver (pagle-backend's
-- src/main/lua/driver.lua) loads each addon's logic/ files, Core's data/Catalogue.lua and Hunts' data/HuntList.lua and
-- data/EventList.lua in TOC order (LOG-R79), never adapter/ or locale/, into globals that hold only Lua 5.1, `bit`, the Pagle API it builds over Core's
-- logic/, and GetServerTime. It then asks Core's logic/ for its projections (ns.BindCoreProjections) and each roster
-- Module's for its own (ns.BindProjections), folds every record through them, and reads each paying Module's Coins
-- (ns.CoinsEarned) and Activity XP (ns.ActivityXPEarned, #76 item 15) from its state after done, passing the Activity
-- XP's sum to the Ledger's level reads as their `total` (AXP-R9, LED-R37).
--
-- This spec hosts the tree the way the driver does and checks what it reads against what the client computes for the
-- same log: the Modules loaded whole on FakePagle (CORE-R18), adapter/ and locale/ included.

local T0 = SERVER_TIME - 90000
local MACKEREL, SMALLFISH, OILY, FIREFIN = 6303, 6291, 6358, 6359
local ELWYNN, WESTFALL, DARKSHORE = 12, 40, 148
--- The paying Modules (SHOP-R2): each reports its lifetime Coins, so each exposes them to the backend.
local PAYING = { "Ledger", "Hunts", "TackleBoard" }
--- The Modules that pay Activity XP (AXP-R1, AXP-R2): each reports its lifetime total, so each exposes it to the
--- backend (AXP-R9).
local PAYING_XP = { "Hunts", "TackleBoard" }

-- The globals the driver gives Pagle's code: Lua 5.1's pure functions and LuaBitOp. Reading any other global
-- raises, as in the driver, so a WoW or adapter call logic/ makes fails the spec.
---@return table
local function driverGlobals()
	local given = {
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no require
		bit = require("bit"),
	}
	for _, name in ipairs({
		"assert",
		"coroutine",
		"error",
		"getmetatable",
		"ipairs",
		"math",
		"next",
		"pairs",
		"pcall",
		"rawequal",
		"rawget",
		"rawset",
		"select",
		"setmetatable",
		"string",
		"table",
		"tonumber",
		"tostring",
		"type",
		"unpack",
		"xpcall",
	}) do
		given[name] = _G[name]
	end
	local globals = setmetatable({}, {
		__index = function(_, name)
			local value = given[name]
			if value == nil then
				error(tostring(name) .. " is not hosted by the backend's driver", 2)
			end
			return value
		end,
	})
	rawset(globals, "_G", globals)
	return globals
end

-- Loads what the driver loads of `addon`, in TOC order, each file called with (addon, ns).
---@param addon string
---@param globals table
---@param ns table
local function loadLogic(addon, globals, ns)
	for _, file in ipairs(addonFiles(addon)) do
		if
			file:find("^logic/")
			or (addon == "Pagle" and file == "data/Catalogue.lua")
			or (addon == "Pagle_Hunts" and (file == "data/HuntList.lua" or file == "data/EventList.lua"))
		then
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
			local chunk = assert(loadfile("addons/" .. addon .. "/" .. file))
			setfenv(chunk, globals)
			chunk(addon, ns)
		end
	end
end

---@class LogicAloneProjection
---@field key string        -- "Core.<name>" for Core's, else the Module's roster name
---@field module string?
---@field def PagleProjectionDef
---@field state table?

---@class LogicAlone
---@field core table                          -- Core's ns
---@field modules table<string, table>        -- each roster Module's ns, by roster name
---@field projections LogicAloneProjection[]  -- in the order they were bound
---@field byKey table<string, LogicAloneProjection>
---@field see fun(record: PagleRecord)          -- keeps each character's latest Skill Reading for Pagle.GetAngler
---@field forget fun()                          -- forgets them, before a projection's pass
---@field catchLog table?                       -- the log being folded, which IterateCatches reads

-- Hosts the tree as the driver does, at server time `now`, with the log's `characters`, and binds every projection.
---@param now integer
---@param characters table[]
---@return LogicAlone
local function host(now, characters)
	local globals = driverGlobals()
	local core = {}
	loadLogic("Pagle", globals, core)
	rawset(globals, "GetServerTime", function()
		return now
	end)
	local catalogue = core.NewCatalogue(core.catalogue)
	core.Catalogue = catalogue
	-- The Angler's latest Skill Reading per character, as the driver keeps them while it folds (fold's `see`).
	local skill = {}
	local Pagle = {
		API_VERSION = 1,
		CONTENT_FINGERPRINT = catalogue.CONTENT_FINGERPRINT,
		SESSION_RULES_VERSION = core.SESSION_RULES_VERSION,
		SIZE_RULES_VERSION = core.SIZE_RULES_VERSION,
		MatchesConditions = core.MatchesConditions,
		GetAngler = function()
			return { logId = "0000000000000000", characters = characters, current = 1, skill = skill, bestBaseSkill = 0 }
		end,
	}
	for _, name in ipairs({ "GetItem", "GetZones", "GetArea", "GetZoneOf", "GetZoneCatches", "GetWindowSpec" }) do
		Pagle[name] = catalogue[name]
	end
	rawset(globals, "Pagle", Pagle)

	local hosted = { core = core, modules = {}, projections = {}, byKey = {} }
	function hosted.see(record)
		if record.kind == "skill" then
			skill[record.char] = record
		end
	end
	-- Before each projection's pass over the log: no Skill Reading seen yet.
	function hosted.forget()
		for char in pairs(skill) do
			skill[char] = nil
		end
	end
	local function add(key, module, def)
		assert(hosted.byKey[key] == nil, key .. " binds a second projection")
		local projection = { key = key, module = module, def = def }
		hosted.projections[#hosted.projections + 1] = projection
		hosted.byKey[key] = projection
		return projection
	end

	if type(core.BindCoreProjections) == "function" then
		core.BindCoreProjections(function(name, def)
			add("Core." .. name, nil, def)
		end)
	end

	-- The Module handle as the driver hosts it: projections bind; IterateCatches reads the log being folded back, with
	-- the Module's own records, as Core's does (LOG-R42; Hunts' late `run` records, HNT-R149); moments, Write-ups,
	-- summary lines and Coins reports are dropped; appending raises.
	local Handle = {}
	Handle.__index = Handle
	function Handle:IterateCatches(afterSeq)
		return hosted.catchLog:Iterate(afterSeq, self.name)
	end
	function Handle:NewProjection(def)
		local projection = add(self.name, self.name, def)
		return {
			GetState = function()
				return projection.state
			end,
			IsUpdating = function()
				return projection.state == nil
			end,
			Rebuild = function() end,
		}
	end
	for _, method in ipairs({ "RaiseMoment", "RaiseWriteUp", "SetSummaryLine", "ReportCoinsEarned" }) do
		Handle[method] = function() end
	end
	function Handle.AppendRecord()
		error("a fold appends nothing")
	end

	for _, name in ipairs(core.MODULE_ROSTER) do
		local ns = {}
		loadLogic(core.ModuleAddOn(name), globals, ns)
		hosted.modules[name] = ns
		if type(ns.BindProjections) == "function" then
			ns.BindProjections(setmetatable({ name = name }, Handle))
		end
	end
	return hosted
end

-- Folds the PagleLog `saved` through every projection `hosted` binds, as the driver does: each from reset, every
-- record as Core's M:IterateCatches reads it for its Module (a Module record to its own Module only, LOG-R41, LOG-R42;
-- none to Core's), then done as a first build from seq 0. The handle's IterateCatches reads the same log meanwhile.
---@param hosted LogicAlone
---@param saved table
---@param now integer
local function fold(hosted, saved, now)
	local core = hosted.core
	local catchLog = core.OpenCatchLog(saved, {}, now, core.Catalogue.GetItem)
	hosted.catchLog = catchLog
	for _, projection in ipairs(hosted.projections) do
		projection.state = projection.def.reset() or {}
		local casts = 0
		hosted.forget()
		for record in catchLog:Iterate(0, projection.module) do
			hosted.see(record)
			projection.def.apply(projection.state, record, "rebuild")
			if record.kind == "cast" then
				casts = casts + 1
			end
		end
		if projection.def.done then
			projection.def.done(projection.state, { firstBuild = casts > 0, rebuilt = true, replayed = 0 })
		end
	end
end

-- A Cast record for fake.catchLog:Append, by character 1.
---@param time integer
---@param zone integer
---@param itemIDs integer[]? nil for a got-away Cast
local function cast(time, zone, itemIDs)
	return castRecord({ time = time, zone = zone, items = itemIDs, outcome = itemIDs and "caught" or "gotAway" })
end

-- The first event of the shipped pool (data/EventList.lua, DATA-R98).
---@return string
local function firstPoolEvent()
	local ns = {}
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
	local chunk = assert(loadfile("addons/Pagle_Hunts/data/EventList.lua"))
	setfenv(chunk, { Pagle = {}, select = select })
	chunk("Pagle_Hunts", ns)
	return ns.eventList.events[1].id
end

-- Its `run` record (HNT-R150) for the three days from T0, logged at T0 before the Casts, as the run log logs a slot.
---@return table
local function poolRun()
	local payload = ("%s|%d|%d|r"):format(firstPoolEvent(), T0, T0 + 3 * 86400)
	return { kind = "module", char = 1, time = T0, module = "Hunts", recordKind = "run", payload = payload }
end

-- A Tackle Board record (TKB-R80) at `time`, its payload as written (tackle-board.md › Data).
---@param kind string
---@param time integer
---@param payload string
---@return table
local function boardRecord(kind, time, payload)
	return { kind = "module", char = 1, time = time, module = "TackleBoard", recordKind = kind, payload = payload }
end

-- The board started at T0, on the board day and week it falls in (daily reset 15:00 UTC, weekly Tuesday's; SERVER_TIME
-- is Sunday 11 October 2026 15:15 UTC), with a tier-1 Notice and an Expedition for one Catch in Elwynn, which the
-- first Cast completes: 100 + 600 Activity XP (TKB-R65), enough to count in the Angler Level.
---@return table[]
local function board()
	local dayStart, weekStart = SERVER_TIME - 900 - 2 * 86400, SERVER_TIME - 900 - 5 * 86400
	return {
		boardRecord("start", T0 + 1, dayStart .. ";" .. weekStart),
		boardRecord("issue", T0 + 2, "n;haul;1;10;1;" .. ELWYNN),
		boardRecord("issue", T0 + 3, "e;haul;0;60;1;" .. ELWYNN),
	}
end

-- A FakePagle whose log holds Casts in three zones, a Skill Reading, a purchase, a pool event's run, a started
-- Tackle Board, all ten Firefin varieties and the Ledger's crest record, and every paying Module loaded whole on it and
-- logged in: the client's side of the comparison.
---@return FakePagle fake
---@return table<string, LoadedAddon> loaded each Module by roster name
local function clientSide()
	local fake = newFakePagle()
	fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
	fake.catchLog:Append({ kind = "skill", char = 1, time = T0, rank = 150, max = 225, mod = 0 })
	fake.catchLog:Append(poolRun())
	for _, record in ipairs(board()) do
		fake.catchLog:Append(record)
	end
	fake.catchLog:Append(cast(T0 + 10, ELWYNN, { MACKEREL, SMALLFISH }))
	fake.catchLog:Append(cast(T0 + 70, ELWYNN))
	fake.catchLog:Append(cast(T0 + 130, WESTFALL, { MACKEREL, OILY }))
	fake.catchLog:Append(cast(T0 + 190, DARKSHORE, { OILY, FIREFIN }))
	fake.catchLog:Append({ kind = "purchase", char = 1, time = T0 + 250, good = "core.toaststyle.ripple", price = 120 })
	-- All ten Firefin varieties (VAR-R3), one Catch each, so its fish crest is earned (VAR-R12).
	local from = T0 + 300
	for index = 1, 10 do
		while fake.ns.VarietyIndex(("%s-%d-0:1"):format(PLAYER_GUID, from)) ~= index do
			from = from + 1
		end
		fake.catchLog:Append(cast(from, DARKSHORE, { FIREFIN }))
		from = from + 60
	end
	-- The Ledger's crest record (#76 item 19, LED-R156): Firefin's fish crest equipped.
	fake.catchLog:Append({
		kind = "module",
		char = 1,
		time = from,
		module = "Ledger",
		recordKind = "crest",
		payload = "core.crest.fish." .. FIREFIN,
	})
	local loaded = {}
	for _, name in ipairs({ "Ledger", "Hunts", "Stats", "TackleBoard" }) do
		loaded[name] = fake.load("Pagle_" .. name)
	end
	fake.login()
	fake.enterWorld()
	return fake, loaded
end

describe("logic/ alone, as the backend's driver loads it (#223)", function()
	it("loads every addon's logic/ without adapter/ or locale/", function()
		assert.has_no_error(function()
			host(SERVER_TIME, {})
		end)
	end)

	it("binds Core's wallet and variety projections and every Module's but QoL's, which has none", function()
		local keys = {}
		for _, projection in ipairs(host(SERVER_TIME, {}).projections) do
			keys[#keys + 1] = projection.key
		end

		assert.are.same({ "Core.wallet", "Core.varieties", "Ledger", "Hunts", "Stats", "TackleBoard" }, keys)
	end)

	it("binds each projection with the rules version the client binds it with", function()
		local fake, loaded = clientSide()
		local hosted = host(SERVER_TIME, fake.catchLog.data.characters)

		for name, module in pairs(loaded) do
			assert.are.equal(module.ns.projection.def.rulesVersion, hosted.byKey[name].def.rulesVersion, name)
		end
		assert.are.equal(fake.ns.WALLET_RULES_VERSION, hosted.byKey["Core.wallet"].def.rulesVersion)
		assert.are.equal(fake.ns.VARIETY_RULES_VERSION, hosted.byKey["Core.varieties"].def.rulesVersion)
	end)

	describe("folding a log", function()
		local fake, loaded, hosted
		setup(function()
			fake, loaded = clientSide()
			hosted = host(SERVER_TIME, fake.catchLog.data.characters)
			fold(hosted, fake.catchLog.data, SERVER_TIME)
		end)

		it("gives the wallet the Coins spent (SHOP-R11)", function()
			assert.are.equal(120, hosted.byKey["Core.wallet"].state.spent)
		end)

		it("gives Core's varieties caught as the client's variety projection holds them (VAR-R10)", function()
			local state = hosted.byKey["Core.varieties"].state

			assert.are.same(fake.global.projections.varieties.projection, state)
			assert(next(state.bySpecies[FIREFIN]) ~= nil, "the comparison isn't of empty sets")
		end)

		-- Core's Activity XP total as the backend counts it: the paying Modules' reads, summed (AXP-R9).
		---@return integer
		local function activityXPTotal()
			local total = 0
			for _, name in ipairs(PAYING_XP) do
				total = total + hosted.modules[name].ActivityXPEarned(hosted.byKey[name].state)
			end
			return total
		end

		for _, name in ipairs(PAYING) do
			it("gives " .. name .. " the lifetime Coins earned the client reports (SHOP-R2)", function()
				local reported = fake.global.coins.earned[name] or 0
				-- The Ledger's Coins count the levels its climb's Activity XP adds (LED-R38).
				local total = name == "Ledger" and activityXPTotal() or nil

				assert.are.equal(reported, hosted.modules[name].CoinsEarned(hosted.byKey[name].state, total))
			end)
		end

		it("earns the Ledger some Coins, so the comparison above isn't of zeros", function()
			assert.is_true(hosted.modules.Ledger.CoinsEarned(hosted.byKey.Ledger.state) > 0)
		end)

		for _, name in ipairs(PAYING_XP) do
			it("gives " .. name .. " the lifetime Activity XP the client reports (AXP-R2, AXP-R9)", function()
				local reported = fake.global.activityXP.earned[name] or 0

				assert.are.equal(reported, hosted.modules[name].ActivityXPEarned(hosted.byKey[name].state))
			end)
		end

		it("sums the Modules' Activity XP to the total Pagle.GetActivityXP() reports in game (AXP-R9)", function()
			assert.are.equal(fake.Pagle.GetActivityXP().total, activityXPTotal())
			assert(activityXPTotal() > 0, "the comparison isn't of zeros")
		end)

		it("leaves out no Module that reports Activity XP in game (AXP-R2)", function()
			for name in pairs(fake.Pagle.GetActivityXP().bySource) do
				assert(type(hosted.modules[name].ActivityXPEarned) == "function", name .. " has no ActivityXPEarned")
			end
		end)

		it("reads the Ledger's measures, titles and tallies from its state as the client reads them", function()
			local ledger, client = hosted.modules.Ledger, loaded.Ledger.ns
			local state, clientState = hosted.byKey.Ledger.state, client.StateNow()
			local total = activityXPTotal()

			for _, read in ipairs({
				"Measures",
				"AnglerLevel",
				"MeasureRises",
				"FirstComplete",
				"EarnedTitles",
				"AutomaticTitle",
				"ZonesMastered",
				"LifetimeCatches",
			}) do
				assert.are.same(client[read](clientState), ledger[read](state, total), read)
			end
			assert.are.equal(16, ledger.LifetimeCatches(state)) -- two on each of three Casts, and ten Firefin
		end)

		it("gives the rise times the driver read from Measures after every Ledger record (LED-R158)", function()
			local ledger, def = hosted.modules.Ledger, hosted.byKey.Ledger.def
			-- The driver's way before LED-R158 (pagle-backend's PRJ-R8): a measure rose on a record when Measures read
			-- after it is greater than just before, Ledger completion by its percentage.
			local state = def.reset()
			local before, at = ledger.Measures(state), {}
			for record in hosted.catchLog:Iterate(0, "Ledger") do
				def.apply(state, record, "rebuild")
				local after = ledger.Measures(state)
				if after.ledgerCompletion.percent > before.ledgerCompletion.percent then
					at.ledgerCompletion = record.time
				end
				for _, count in ipairs({ "speciesCaught", "legendsCaught" }) do
					if after[count] > before[count] then
						at[count] = record.time
					end
				end
				before = after
			end

			assert.are.same(at, ledger.MeasureRises(hosted.byKey.Ledger.state))
			assert.is_number(at.ledgerCompletion)
			assert.is_number(at.speciesCaught)
		end)

		it("reads the Angler Level alone as Measures reads it, Activity XP counted (LED-R159)", function()
			local ledger, state, total = hosted.modules.Ledger, hosted.byKey.Ledger.state, activityXPTotal()

			assert.are.same(ledger.Measures(state, total).anglerLevel, ledger.AnglerLevel(state, total))
			assert.are.equal(ledger.AnglerLevel(state).xp + total, ledger.AnglerLevel(state, total).xp)
		end)

		it("counts the Activity XP in the Ledger's Angler Level, so the comparison above has it (LED-R37)", function()
			local ledger, state, total = hosted.modules.Ledger, hosted.byKey.Ledger.state, activityXPTotal()

			-- logic/ alone sets no source, so without a total the climb is the Ledger's own XP.
			local own = ledger.Measures(state).anglerLevel.xp
			assert.are.equal(own + total, ledger.Measures(state, total).anglerLevel.xp)
		end)

		it("gives each Module's Journal values as the client's logic/ gives them, no key from two Modules", function()
			local from = {}
			for name, module in pairs(loaded) do
				local total = name == "Ledger" and activityXPTotal() or nil
				local values = hosted.modules[name].JournalValues(hosted.byKey[name].state, 20, total)
				local clientState = name == "Ledger" and module.ns.StateNow() or module.ns.projection:GetState()

				assert.are.same(module.ns.JournalValues(clientState, 20), values, name)
				for key in pairs(values) do
					assert(from[key] == nil, key .. " comes from two Modules")
					from[key] = name
				end
			end
			assert.are.same({
				level = "Ledger",
				parts = "Ledger",
				titles = "Ledger",
				nextCatchMilestone = "Ledger",
				skillMilestones = "Ledger",
				characters = "Ledger",
				zones = "Ledger",
				species = "Ledger",
				legends = "Ledger",
				trophies = "Ledger",
				xp = "Ledger",
				varieties = "Ledger",
				crests = "Ledger",
				stats = "Stats",
				sessions = "Stats",
				odds = "Stats",
				hunts = "Hunts",
				sets = "Hunts",
				ladder = "Hunts",
				flies = "TackleBoard",
			}, from)
		end)

		-- The Ledger's Journal values as the driver reads them, its `total` the Modules' Activity XP summed.
		---@return table
		local function ledgerJournal()
			return hosted.modules.Ledger.JournalValues(hosted.byKey.Ledger.state, 20, activityXPTotal())
		end

		it("gives the Ledger's own XP, without the Activity XP its level counts (LED-R150, LED-R155)", function()
			local xp = ledgerJournal().xp.ledger

			assert.are.equal(hosted.byKey.Ledger.state.lifetimeXP, xp)
			assert.are.equal(loaded.Ledger.ns.XPSourceLines(loaded.Ledger.ns.StateNow())[1].total, xp)
			assert.is_true(xp > 0)
		end)

		it("gives Firefin's varieties as Core's variety projection holds them in game (VAR-R10, LED-R155)", function()
			local caught = {}
			for _, entry in ipairs(ledgerJournal().varieties) do
				if entry.species == FIREFIN then
					for _, variety in ipairs(entry.caught) do
						caught[variety.position] = true
					end
				end
			end

			assert.are.same(fake.global.projections.varieties.projection.bySpecies[FIREFIN], caught)
			assert.is_true(caught[10])
		end)

		it("gives the crests the client owns, Firefin's fish crest among them (VAR-R12, LED-R155)", function()
			local crests = ledgerJournal().crests

			assert.is_true(#crests > 0)
			for _, crest in ipairs(crests) do
				assert(fake.Pagle.IsOwned(crest.id), crest.id .. " isn't owned in game")
			end
			assert.are.equal("core.crest.fish." .. FIREFIN, crests[#crests].id)
		end)

		it("reads the crest record the Ledger logged as the equipped crest (#76 item 19, LED-R156)", function()
			local ledger, equipped = hosted.modules.Ledger, nil
			for record in hosted.catchLog:Iterate(0, "Ledger") do
				if record.kind == "module" then
					equipped = ledger.EquippedCrest(record)
				end
			end

			assert.are.equal("core.crest.fish." .. FIREFIN, equipped)
			assert.are.equal(equipped, hosted.byKey.Ledger.state.crest.good)
		end)

		it("gives the Pagle Wagers ladder as the client's spread marks it (HNT-R148, HNT-R178)", function()
			local state = hosted.byKey.Hunts.state
			local spread = loaded.Hunts.ns.BuildWagersLadder(state.settled, state.ladder)
			local ladder = hosted.modules.Hunts.JournalValues(state, 20).ladder

			assert.are.equal(#spread.marks, #ladder)
			for i, mark in ipairs(spread.marks) do
				assert.are.same({ step = mark.step, earned = mark.reached }, ladder[i])
			end
		end)

		it("lists the release's Legends as the client's Ledger does (PRJ-R15)", function()
			local list = hosted.modules.Ledger.LegendList()

			assert.are.same(loaded.Ledger.ns.LegendList(), list)
			assert.is_true(#list > 0)
		end)

		it("credits the pool event's run, as the client's Hunts does (LOG-R79, HNT-R150)", function()
			local key = firstPoolEvent() .. "@" .. T0

			assert.is_truthy(hosted.byKey.Hunts.state.runs[key])
			assert.are.same(loaded.Hunts.ns.projection:GetState().runs[key], hosted.byKey.Hunts.state.runs[key])
		end)

		it("lists the release's event pool as the client's Hunts does, every event (LOG-R79, DATA-R98)", function()
			local pool = hosted.modules.Hunts.EventPool()

			assert.are.same(loaded.Hunts.ns.EventPool(), pool)
			assert.are.equal(#loaded.Hunts.ns.events:Events(), #pool)
			assert.is_true(#pool > 0)
		end)

		for _, name in ipairs({ "Ledger", "Hunts", "Stats", "TackleBoard" }) do
			it("folds " .. name .. "'s projection to the state the client's holds", function()
				assert.are.same(loaded[name].ns.projection:GetState(), hosted.byKey[name].state)
			end)
		end
	end)
end)
