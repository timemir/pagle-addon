-- Attaching a Module: Pagle.RegisterModule, the Module handle, each roster entry's state and ModulesChanged
-- (CORE-R12–R14, CORE-R16, CORE-R17, CORE-R19, CORE-R41).

-- Loads Core with the given roster Modules installed on the fake client, by roster name: { QoL = { ... } } puts
-- Pagle_QoL in client.addons, enabled and loaded unless it says otherwise, with X-Pagle-API 1.
local function loadWith(modules)
	local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
	for name, addon in pairs(modules or {}) do
		addon.metadata = addon.metadata or { ["X-Pagle-API"] = "1" }
		loaded.client.addons["Pagle_" .. name] = addon
	end
	return loaded
end

-- A def that passes CORE-R14, with `overrides` applied.
local function qolDef(overrides)
	local def = { name = "QoL", title = "QoL", order = 50 }
	for key, value in pairs(overrides or {}) do
		def[key] = value
	end
	return def
end

-- RegisterModule's error, called from this file, or "" if it didn't raise.
---@return string
local function registerError(Pagle, def)
	local ok, err = pcall(function()
		Pagle.RegisterModule(def)
	end)
	return ok and "" or tostring(err)
end

describe("Pagle.RegisterModule", function()
	it("returns a Module handle for a roster Module (CORE-R12)", function()
		local Pagle = loadWith({ QoL = {} }).env.Pagle

		assert.is_table(Pagle.RegisterModule(qolDef()))
	end)

	it("raises an error at the caller for a name not in the roster, registering nothing (CORE-R14)", function()
		local Pagle = loadWith({ QoL = {} }).env.Pagle

		for _, name in ipairs({ "Fishbook", "Pagle_QoL", "qol", 5 }) do
			local err = registerError(Pagle, qolDef({ name = name }))
			assert.matches("Modules_spec%.lua:%d+: .*not a Pagle Module", err)
		end
		assert.has_error(function()
			Pagle.RegisterModule()
		end)
	end)

	it("raises an error at the caller for a missing title or order, registering nothing (CORE-R14)", function()
		local loaded = loadWith({ QoL = {} })
		local Pagle = loaded.env.Pagle

		assert.matches("Modules_spec%.lua:%d+: .*title", registerError(Pagle, qolDef({ title = false })))
		assert.matches("Modules_spec%.lua:%d+: .*order", registerError(Pagle, qolDef({ order = false })))
		assert.matches("Modules_spec%.lua:%d+: .*title", registerError(Pagle, qolDef({ title = "" })))
		assert.matches("Modules_spec%.lua:%d+: .*order", registerError(Pagle, qolDef({ order = "50" })))

		-- Nothing was registered, so the valid call still goes through.
		assert.is_table(Pagle.RegisterModule(qolDef()))
	end)

	it(
		"takes an optional guideBlurb, and raises an error at the caller for one that isn't a string (ONB-R91)",
		function()
			local loaded = loadWith({ QoL = {} })
			local Pagle = loaded.env.Pagle

			assert.matches("Modules_spec%.lua:%d+: .*guideBlurb", registerError(Pagle, qolDef({ guideBlurb = 5 })))
			assert.matches("Modules_spec%.lua:%d+: .*guideBlurb", registerError(Pagle, qolDef({ guideBlurb = "" })))

			assert.is_table(Pagle.RegisterModule(qolDef({ guideBlurb = "One press, one action." })))
			assert.are.equal("One press, one action.", loaded.ns.Modules:Modules()[1].def.guideBlurb)
		end
	)

	it("takes an optional collection function, and raises an error at the caller for any other (CORE-R45)", function()
		local loaded = loadWith({ QoL = {} })
		local Pagle = loaded.env.Pagle

		assert.matches(
			"Modules_spec%.lua:%d+: .*def%.collection",
			registerError(Pagle, qolDef({ collection = "open" }))
		)
		assert.matches("Modules_spec%.lua:%d+: .*def%.collection", registerError(Pagle, qolDef({ collection = {} })))

		local collection = function() end
		assert.is_table(Pagle.RegisterModule(qolDef({ collection = collection })))
		assert.are.equal(collection, loaded.ns.Modules:Modules()[1].def.collection)
	end)

	it("raises an error at the caller for a second registration, keeping the first (CORE-R14)", function()
		local Pagle = loadWith({ QoL = {} }).env.Pagle
		Pagle.RegisterModule(qolDef())

		assert.matches("Modules_spec%.lua:%d+: .*already registered", registerError(Pagle, qolDef()))
	end)
end)

-- The state ns.ModuleStates gives a roster Module.
local function stateOf(loaded, name)
	for _, entry in ipairs(loaded.ns.ModuleStates()) do
		if entry.name == name then
			return entry.state
		end
	end
end

describe("A Module whose X-Pagle-API this Core can't serve", function()
	it("gets nil, one chat line naming it, and reads Needs a newer Pagle (CORE-R13, CORE-R41)", function()
		-- Pagle.API_VERSION is 1 before 1.0 (CORE-R15).
		for _, metadata in ipairs({ {}, { ["X-Pagle-API"] = "one" }, { ["X-Pagle-API"] = "2" } }) do
			local loaded = loadWith({ Hunts = { metadata = metadata } })

			local handle = loaded.env.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })

			assert.is_nil(handle)
			assert.are.same({ "Pagle: Pagle Hunts needs a newer Pagle." }, loaded.printed)
			assert.are.equal("needsNewerPagle", stateOf(loaded, "Hunts"))
		end
	end)

	it("can't register again once inert (CORE-R13, CORE-R14)", function()
		local loaded = loadWith({ Hunts = { metadata = {} } })
		local def = { name = "Hunts", title = "Hunts", order = 20 }
		loaded.env.Pagle.RegisterModule(def)

		assert.matches("already registered", registerError(loaded.env.Pagle, def))
		assert.are.equal(1, #loaded.printed)
	end)

	it("registers when its X-Pagle-API is this Core's or older (CORE-R13)", function()
		local loaded = loadWith({
			QoL = { metadata = { ["X-Pagle-API"] = "1" } },
			Stats = { metadata = { ["X-Pagle-API"] = "0" } },
		})

		assert.is_table(loaded.env.Pagle.RegisterModule(qolDef()))
		assert.is_table(loaded.env.Pagle.RegisterModule({ name = "Stats", title = "Stats", order = 30 }))
		assert.are.same({}, loaded.printed)
	end)
end)

describe("Each roster Module's state", function()
	it("lists the whole roster in CORE-R1 order (CORE-R41)", function()
		local names = {}
		for i, entry in ipairs(loadWith().ns.ModuleStates()) do
			names[i] = entry.name
		end

		assert.are.same({ "Ledger", "Hunts", "Stats", "TackleBoard", "QoL" }, names)
	end)

	it("reads On, Failed to start, Off and Not installed as CORE-R41 defines them (CORE-R41)", function()
		local loaded = loadWith({
			QoL = {}, -- enabled, loaded, registers below
			Ledger = {}, -- enabled, loaded, never registers
			Stats = { enabled = false, loaded = false },
			-- Hunts and TackleBoard aren't installed.
		})
		loaded.env.Pagle.RegisterModule(qolDef())

		local states = {}
		for _, entry in ipairs(loaded.ns.ModuleStates()) do
			states[entry.name] = entry.state
		end

		assert.are.same({
			QoL = "on",
			Ledger = "failedToStart",
			Stats = "off",
			Hunts = "notInstalled",
			TackleBoard = "notInstalled",
		}, states)
	end)

	it("reads enable state for the player's character, and stays On once registered (CORE-R16, CORE-R41)", function()
		local loaded = loadWith({ QoL = {} })
		local asked
		local getEnableState = loaded.env.C_AddOns.GetAddOnEnableState
		loaded.env.C_AddOns.GetAddOnEnableState = function(name, character)
			asked = { name, character }
			return getEnableState(name, character)
		end
		loaded.env.Pagle.RegisterModule(qolDef())
		-- Disabled in the AddOns list during the session: it keeps running until the next one.
		loaded.client.addons.Pagle_QoL.enabled = false

		assert.are.equal("on", stateOf(loaded, "QoL"))
		assert.are.same({ "Pagle_QoL", PLAYER_GUID }, asked)
	end)

	it("reads Off for a Module enabled after this session loaded without it (CORE-R41)", function()
		local loaded = loadWith({ Ledger = { enabled = true, loaded = false } })

		assert.are.equal("off", stateOf(loaded, "Ledger"))
	end)
end)

describe("ModulesChanged", function()
	-- Loads Core holding ADDON_LOADED, and counts ModulesChanged.
	local function loadCounting()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS, { holdAddonLoaded = true })
		local count = { n = 0 }
		loaded.env.Pagle.RegisterCallback("Spec", "ModulesChanged", function(...)
			count.n = count.n + 1
			count.args = { ... }
		end)
		return loaded, count
	end

	it("fires once, at PLAYER_LOGIN, after every addon's ADDON_LOADED (CORE-R19)", function()
		local loaded, count = loadCounting()

		loaded.client.fire("ADDON_LOADED", "Pagle")
		loaded.client.fire("ADDON_LOADED", "Pagle_QoL")
		assert.are.equal(0, count.n)

		loaded.client.fire("PLAYER_LOGIN")
		loaded.client.fire("PLAYER_LOGIN")
		assert.are.equal(1, count.n)
		assert.are.same({ "ModulesChanged" }, count.args)
	end)
end)

describe("Core and a disabled Module", function()
	it("never enables or loads one: no Core file names that client API (CORE-R16, CORE-R17)", function()
		-- A disabled Module registers nothing because the client never loads it; Core must not load it either.
		local forbidden = { "EnableAddOn", "EnableAllAddOns", "LoadAddOn", "ResetAddOns", "SaveAddOns" }
		-- Core explicitly loads only the Anglers data and an installed Recovery package, never a Module.
		-- Only their fixed calls, the inventory and the docs naming those calls are taken out.
		local allowedLoads = {
			["adapter/Recovery.lua"] = 'C_AddOns.LoadAddOn("Pagle_Recovery")',
			["adapter/AnglersInGame.lua"] = "pcall(C_AddOns.LoadAddOn, ANGLERS_ADDON)",
			["data/ApiInventory.lua"] = '"C_AddOns.LoadAddOn",',
			["logic/AnglersInGame.lua"] = 'C_AddOns.LoadAddOn("Pagle_Anglers")',
			["logic/Wiring.lua"] = 'C_AddOns.LoadAddOn("Pagle_Anglers")',
		}
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
		local adapter = assert(io.open("addons/Pagle/adapter/AnglersInGame.lua", "r")):read("*a")
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
		local logic = assert(io.open("addons/Pagle/logic/AnglersInGame.lua", "r")):read("*a")
		-- ANGLERS_ADDON, the name that one call loads, is the Companion's Pagle_Anglers.
		assert.is_truthy(
			adapter:find("local FOLLOWING_ADDON, ANGLERS_ADDON = ns.FOLLOWING_ADDON, ns.ANGLERS_ADDON\n", 1, true)
		)
		assert.is_truthy(
			logic:find('ns.FOLLOWING_ADDON, ns.ANGLERS_ADDON = "Pagle_Following", "Pagle_Anglers"\n', 1, true)
		)
		for _, file in ipairs(addonFiles("Pagle")) do
			if not file:match("^libs/") then
				---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
				local source = assert(io.open("addons/Pagle/" .. file, "r")):read("*a")
				local allowed = allowedLoads[file]
				if allowed then
					local found
					source, found = source:gsub(allowed:gsub("%p", "%%%0"), "")
					assert.are.equal(1, found, file)
				end
				for _, name in ipairs(forbidden) do
					assert(not source:find(name, 1, true), file .. " names " .. name)
				end
			end
		end
	end)
end)

describe("The Collection Core opens (CORE-R45)", function()
	-- Core with the Ledger (order 10) and Hunts (order 20) registered, each with `collections`' function for its
	-- def.collection if given.
	local function withModules(collections)
		local loaded = loadWith({ Ledger = {}, Hunts = {} })
		local Pagle = loaded.env.Pagle
		for _, def in ipairs({ { "Ledger", 10 }, { "Hunts", 20 } }) do
			Pagle.RegisterModule({ name = def[1], title = def[1], order = def[2], collection = collections[def[1]] })
		end
		return loaded
	end

	it("calls the first On Module's def.collection by def.order, with the good given (CORE-R45)", function()
		local calls = {}
		local loaded = withModules({
			Ledger = function(...)
				calls[#calls + 1] = { "Ledger", ... }
			end,
			Hunts = function(...)
				calls[#calls + 1] = { "Hunts", ... }
			end,
		})

		assert.is_true(loaded.ns.OpenCollection("core.toaststyle.foil"))
		assert.is_true(loaded.ns.OpenCollection())

		assert.are.same({ { "Ledger", "core.toaststyle.foil" }, { "Ledger" } }, calls)
	end)

	it("skips a Module with none for the next, and opens nothing with none at all (CORE-R45)", function()
		local calls = {}
		local loaded = withModules({
			Hunts = function(goodID)
				calls[#calls + 1] = goodID
			end,
		})

		assert.is_true(loaded.ns.OpenCollection("core.crest.plain"))
		assert.are.same({ "core.crest.plain" }, calls)
		assert.are.equal(loaded.ns.Modules:Modules()[2].def.collection, loaded.ns.CollectionOffered())

		local none = withModules({})
		assert.is_nil(none.ns.CollectionOffered())
		assert.is_false(none.ns.OpenCollection("core.crest.plain"))
	end)

	it("leaves a Module that isn't On out, as it never registered: the next one is called (CORE-R45)", function()
		local calls = {}
		local loaded = loadWith({ Hunts = {} })
		loaded.env.Pagle.RegisterModule({
			name = "Hunts",
			title = "Hunts",
			order = 20,
			collection = function(goodID)
				calls[#calls + 1] = goodID
			end,
		})

		assert.is_true(loaded.ns.OpenCollection("core.crest.plain")) -- the Ledger is off
		assert.are.same({ "core.crest.plain" }, calls)
	end)

	it("reports a def.collection that raises through the error handler (CORE-R45)", function()
		local loaded = withModules({
			Ledger = function()
				error("Collection broke")
			end,
		})

		assert.is_true(loaded.ns.OpenCollection())

		assert.are.equal(1, #loaded.client.errors)
		assert.matches("Collection broke", loaded.client.errors[1])
	end)
end)
