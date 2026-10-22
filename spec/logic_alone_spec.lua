-- Pagle's backend folds the Catch log through logic/ alone (#223, #76 item 5). Its projection driver (pagle-backend's
-- src/main/lua/driver.lua) loads each addon's logic/ files, Core's data/Catalogue.lua and Hunts' data/HuntList.lua in
-- TOC order, never adapter/ or locale/, into globals that hold only Lua 5.1, `bit`, the Pagle API it builds over Core's
-- logic/, and GetServerTime. It then asks Core's logic/ for its projections (ns.BindCoreProjections) and each roster
-- Module's for its own (ns.BindProjections), folds every record through them, and reads each paying Module's Coins
-- (ns.CoinsEarned) from its state after done.
--
-- This spec hosts the tree the way the driver does and checks what it reads against what the client computes for the
-- same log: the Modules loaded whole on FakePagle (CORE-R18), adapter/ and locale/ included.

local T0 = SERVER_TIME - 90000
local MACKEREL, SMALLFISH, OILY, FIREFIN = 6303, 6291, 6358, 6359
local ELWYNN, WESTFALL, DARKSHORE = 12, 40, 148
--- The paying Modules (SHOP-R2): each reports its lifetime Coins, so each exposes them to the backend.
local PAYING = { "Ledger", "Hunts", "TackleBoard" }

-- The globals the driver gives wow-fish's code: Lua 5.1's pure functions and LuaBitOp. Reading any other global
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
			or (addon == "Pagle_Hunts" and file == "data/HuntList.lua")
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

	-- The Module handle as the driver hosts it: projections bind; moments, Write-ups, summary lines and Coins reports
	-- are dropped; appending raises.
	local Handle = {}
	Handle.__index = Handle
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
-- record (a Module record to its own Module only, LOG-R41), then done as a first build from seq 0.
---@param hosted LogicAlone
---@param saved table
---@param now integer
local function fold(hosted, saved, now)
	local core = hosted.core
	local catchLog = core.OpenCatchLog(saved, {}, now, core.Catalogue.GetItem)
	local casts = {}
	for _, projection in ipairs(hosted.projections) do
		projection.state = projection.def.reset() or {}
		casts[projection] = 0
	end
	for record in catchLog:Iterate(0) do
		hosted.see(record)
		for _, projection in ipairs(hosted.projections) do
			if record.kind ~= "module" or record.module == projection.module then
				projection.def.apply(projection.state, record, "rebuild")
				if record.kind == "cast" then
					casts[projection] = casts[projection] + 1
				end
			end
		end
	end
	for _, projection in ipairs(hosted.projections) do
		if projection.def.done then
			projection.def.done(projection.state, { firstBuild = casts[projection] > 0, rebuilt = true, replayed = 0 })
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

-- A FakePagle whose log holds Casts in three zones, a Skill Reading and a purchase, and every paying Module loaded
-- whole on it and logged in: the client's side of the comparison.
---@return FakePagle fake
---@return table<string, LoadedAddon> loaded each Module by roster name
local function clientSide()
	local fake = newFakePagle()
	fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
	fake.catchLog:Append({ kind = "skill", char = 1, time = T0, rank = 150, max = 225, mod = 0 })
	fake.catchLog:Append(cast(T0 + 10, ELWYNN, { MACKEREL, SMALLFISH }))
	fake.catchLog:Append(cast(T0 + 70, ELWYNN))
	fake.catchLog:Append(cast(T0 + 130, WESTFALL, { MACKEREL, OILY }))
	fake.catchLog:Append(cast(T0 + 190, DARKSHORE, { OILY, FIREFIN }))
	fake.catchLog:Append({ kind = "purchase", char = 1, time = T0 + 250, good = "core.crest.elwynn", price = 120 })
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

	it("binds Core's wallet projection and every Module's but QoL's, which has none", function()
		local keys = {}
		for _, projection in ipairs(host(SERVER_TIME, {}).projections) do
			keys[#keys + 1] = projection.key
		end

		assert.are.same({ "Core.wallet", "Ledger", "Hunts", "Stats", "TackleBoard" }, keys)
	end)

	it("binds each projection with the rules version the client binds it with", function()
		local fake, loaded = clientSide()
		local hosted = host(SERVER_TIME, fake.catchLog.data.characters)

		for name, module in pairs(loaded) do
			assert.are.equal(module.ns.projection.def.rulesVersion, hosted.byKey[name].def.rulesVersion, name)
		end
		assert.are.equal(fake.ns.WALLET_RULES_VERSION, hosted.byKey["Core.wallet"].def.rulesVersion)
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

		for _, name in ipairs(PAYING) do
			it("gives " .. name .. " the lifetime Coins earned the client reports (SHOP-R2)", function()
				local reported = fake.global.coins.earned[name] or 0

				assert.are.equal(reported, hosted.modules[name].CoinsEarned(hosted.byKey[name].state))
			end)
		end

		it("earns the Ledger some Coins, so the comparison above isn't of zeros", function()
			assert.is_true(hosted.modules.Ledger.CoinsEarned(hosted.byKey.Ledger.state) > 0)
		end)

		it("reads the Ledger's measures, titles and tallies from its state as the client reads them", function()
			local ledger, client = hosted.modules.Ledger, loaded.Ledger.ns
			local state, clientState = hosted.byKey.Ledger.state, client.StateNow()

			for _, read in ipairs({ "Measures", "EarnedTitles", "AutomaticTitle", "ZonesMastered", "LifetimeCatches" }) do
				assert.are.same(client[read](clientState), ledger[read](state), read)
			end
			assert.are.equal(6, ledger.LifetimeCatches(state)) -- two on each of three Casts
		end)

		it("gives each Module's Journal values as the client's logic/ gives them, no key from two Modules", function()
			local from = {}
			for name, module in pairs(loaded) do
				local values = hosted.modules[name].JournalValues(hosted.byKey[name].state, 20)
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
				stats = "Stats",
				sessions = "Stats",
				odds = "Stats",
				hunts = "Hunts",
				sets = "Hunts",
				flies = "TackleBoard",
			}, from)
		end)

		it("lists the release's Legends as the client's Ledger does (PRJ-R15)", function()
			local list = hosted.modules.Ledger.LegendList()

			assert.are.same(loaded.Ledger.ns.LegendList(), list)
			assert.is_true(#list > 0)
		end)

		for _, name in ipairs({ "Ledger", "Hunts", "Stats", "TackleBoard" }) do
			it("folds " .. name .. "'s projection to the state the client's holds", function()
				assert.are.same(loaded[name].ns.projection:GetState(), hosted.byKey[name].state)
			end)
		end
	end)
end)
