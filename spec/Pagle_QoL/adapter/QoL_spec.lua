-- Pagle_QoL attaching to Core (QOL-R1, QOL-R2, CORE-R11–R13, CORE-R41, CORE-R86).

-- Each roster Module's state, by name, as Core's Settings status list reads it (CORE-R41).
local function statesOf(core)
	local states = {}
	for _, entry in ipairs(core.ModuleStates()) do
		states[entry.name] = entry.state
	end
	return states
end

describe("Pagle_QoL with Core", function()
	it("loads after Core, registers once from OnInitialize and reads On (QOL-R2, CORE-R12, CORE-R41)", function()
		local loaded = loadAddon("Pagle_QoL", FOREVER_GLOBALS)
		local core = loaded.namespaces.Pagle

		local modules = core.Modules:Modules()
		assert.are.equal(1, #modules)
		assert.are.same({ "QoL", "QoL", 50 }, { modules[1].def.name, modules[1].def.title, modules[1].def.order })
		assert.are.equal(modules[1].handle, loaded.ns.Module)
		assert.are.equal("on", statesOf(core).QoL)
	end)

	it("registers no menu, slash or views entries in M1 (QOL-R2)", function()
		local def = loadAddon("Pagle_QoL", FOREVER_GLOBALS).namespaces.Pagle.Modules:Modules()[1].def

		assert.is_nil(def.menu)
		assert.is_nil(def.slash)
		assert.is_nil(def.views)
	end)

	it("has a settingsAction, Fishing settings ›, that opens Core's Fishing page (QOL-R2)", function()
		local loaded = loadAddon("Pagle_QoL", FOREVER_GLOBALS)
		loaded.client.bindings = { "PAGLE_FISHING_KEY" }
		loaded.client.fire("PLAYER_LOGIN")

		local action = loaded.namespaces.Pagle.Modules:Modules()[1].def.settingsAction
		action.onClick()

		assert.are.equal("Fishing settings ›", action.label)
		local opened = loaded.client.settings.opened
		assert.are.equal(1, #opened)
		assert.are.equal(loaded.client.settings.category("Fishing"), opened[1])
	end)

	it("keeps PagleQoLDB account-wide in one shared profile, at schema 1 (QOL-R1, qol.md › Data)", function()
		local loaded = loadAddon("Pagle_QoL", FOREVER_GLOBALS)

		assert.are.equal("Default", loaded.ns.db:GetCurrentProfile())
		assert.are.equal(1, rawget(loaded.env.PagleQoLDB.global, "schemaVersion"))
	end)

	it("names the Fishing key and its header for Key Bindings › AddOns (QOL-R1, QOL-R10)", function()
		local env = loadAddon("Pagle_QoL", FOREVER_GLOBALS).env

		assert.are.equal("Pagle", env.BINDING_HEADER_PAGLE)
		assert.are.equal("Pagle: Fishing key", env.BINDING_NAME_PAGLE_FISHING_KEY)
	end)
end)

describe("Pagle_QoL with FakePagle", function()
	it("registers once with the fake and reads On (QOL-R2, CORE-R12, CORE-R18)", function()
		local fake = newFakePagle()

		local loaded = fake.load("Pagle_QoL")

		assert.are.equal("QoL", fake.registry:ModuleOf(loaded.ns.Module).def.name)
		assert.are.equal("on", fake.moduleState("QoL"))
		assert.has_no_error(fake.login)
	end)

	it("stops while inert, with no SavedVariables touched (CORE-R13)", function()
		local fake = newFakePagle()
		fake.addons.Pagle_QoL.metadata["X-Pagle-API"] = "2"

		local loaded = fake.load("Pagle_QoL")

		assert.is_nil(loaded.ns.Module)
		assert.are.equal("needsNewerPagle", fake.moduleState("QoL"))
		assert.is_nil(loaded.env.PagleQoLDB)
		assert.are.same({ "Pagle: Pagle QoL needs a newer Pagle." }, fake.printed)
	end)
end)

describe("Pagle_QoL without Pagle", function()
	it("depends on Pagle, so the client won't load it with Core missing or disabled (CORE-R86, CORE-R3)", function()
		local fields = assert(loadAddon("Pagle_QoL", FOREVER_GLOBALS).client.addons.Pagle_QoL.metadata)

		assert.are.equal("Pagle", fields.Dependencies)
	end)

	it("off Forever, with no Pagle global, registers nothing and raises no error (CORE-R4, CORE-R11)", function()
		local loaded
		assert.has_no_error(function()
			loaded = loadAddon("Pagle_QoL", { WOW_PROJECT_ID = PROJECT_IDS.MAINLINE, WOW_PROJECT_CAMELOT = 18 })
		end)

		assert.is_nil(loaded.env.Pagle)
		assert.are.same({}, loaded.ns)
		assert.is_nil(loaded.env.LibStub("AceAddon-3.0"):GetAddon("Pagle_QoL", true))
		assert.is_nil(loaded.env.PagleQoLDB)
		assert.is_nil(loaded.env.BINDING_NAME_PAGLE_FISHING_KEY)
	end)

	-- A broken install: no Pagle, and nothing else either. Each file must stop at its first line, so it reads no
	-- global but Pagle and writes none.
	for _, file in ipairs(addonFiles("Pagle_QoL")) do
		it(file .. " starts with the Core guard and does nothing without Pagle (CORE-R11)", function()
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
			local chunk = assert(loadfile("addons/Pagle_QoL/" .. file))
			local touched = {}
			setfenv(
				chunk,
				setmetatable({}, {
					__index = function(_, key)
						if key ~= "Pagle" then
							touched[#touched + 1] = "read " .. key
						end
					end,
					__newindex = function(_, key)
						touched[#touched + 1] = "wrote " .. key
					end,
				})
			)
			local ns = {}

			chunk("Pagle_QoL", ns)

			assert.are.same({}, touched)
			assert.are.same({}, ns)
		end)
	end
end)
