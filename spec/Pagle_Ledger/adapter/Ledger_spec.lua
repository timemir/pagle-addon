-- Pagle_Ledger attaching to Core (LED-R1, LED-R4, CORE-R11–R13, CORE-R41, CORE-R44, CORE-R86; ledger.md › Data).

-- Each roster Module's state, by name, as Core's Settings status list reads it (CORE-R41).
local function statesOf(core)
	local states = {}
	for _, entry in ipairs(core.ModuleStates()) do
		states[entry.name] = entry.state
	end
	return states
end

-- Shows the Settings root and returns the texts and the shown buttons of its status list (SET-R11).
local function statusList(loaded)
	local settings = loaded.client.settings
	for _, row in ipairs(settings.show(settings.category("Pagle"))) do
		if row.initializer.searchTags[1] == "MODULES" then
			return settings.textsOf(row.frame), settings.buttonsOf(row.frame)
		end
	end
end

-- Clicks Pagle in the Addon Compartment and returns the menu Core opens on the next frame (CORE-R50).
local function compartmentMenu(loaded)
	local opened = #loaded.client.menus
	loaded.client.clickCompartment("Pagle")
	loaded.client.runTimers()
	return loaded.client.menus[opened + 1]
end

describe("Pagle_Ledger with Core", function()
	it("loads after Core, registers once from OnInitialize and reads On (LED-R1, CORE-R12, CORE-R41)", function()
		local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)
		local core = loaded.namespaces.Pagle

		local modules = core.Modules:Modules()
		assert.are.equal(1, #modules)
		assert.are.same({ "Ledger", "Ledger", 10 }, { modules[1].def.name, modules[1].def.title, modules[1].def.order })
		assert.are.equal(modules[1].handle, loaded.ns.Module)
		assert.are.equal("on", statesOf(core).Ledger)
	end)

	it("registers no view, slash command, menu entry or settingsAction in M2 (LED-R1, LED-R4)", function()
		local def = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns.ModuleDef()

		assert.is_nil(def.views)
		assert.is_nil(def.slash)
		assert.is_nil(def.menu)
		assert.is_nil(def.settingsAction)
	end)

	it("shows On in the status list, with no button (SET-R11, CORE-R44, roadmap M2)", function()
		local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)
		loaded.client.fire("PLAYER_LOGIN")

		local texts, buttons = statusList(loaded)

		assert.are.same({ "Ledger", "@project-version@", "On" }, { unpack(texts, 1, 3) })
		assert.are.equal("Hunts", texts[4])
		assert.are.same({}, buttons)
	end)

	it("adds nothing to the compartment menu or /pagle help (LED-R1, CORE-R50, CORE-R60)", function()
		local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)
		local plain = loadAddon("Pagle", FOREVER_GLOBALS)
		loaded.client.fire("PLAYER_LOGIN")
		plain.client.fire("PLAYER_LOGIN")

		loaded.env.SlashCmdList.PAGLE("help")

		assert.are.same(compartmentMenu(plain).texts(), compartmentMenu(loaded).texts())
		assert.are.same({
			"Pagle commands:",
			"/pagle settings: open Pagle's settings (also /pagle on its own)",
			"/pagle help: list these commands",
		}, loaded.printed)
	end)

	it("adds no settings rows: the Ledger has no settings page (LED-R1, CORE-R42)", function()
		local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)
		local plain = loadAddon("Pagle", FOREVER_GLOBALS)
		loaded.client.fire("PLAYER_LOGIN")
		plain.client.fire("PLAYER_LOGIN")

		local function categories(client)
			local names = {}
			for i, category in ipairs(client.settings.categories) do
				names[i] = category.name
			end
			return names
		end
		assert.are.same(categories(plain.client), categories(loaded.client))
	end)

	it("keeps PagleLedgerDB account-wide in one shared profile, at schema 1 (ledger.md › Data)", function()
		local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)
		local db = loaded.ns.db

		assert.are.equal("Default", db:GetCurrentProfile())
		assert.are.equal(1, rawget(loaded.env.PagleLedgerDB.global, "schemaVersion"))
	end)

	it("starts with ledger.md › Data's keys: an empty projection, an empty celebrated set, no title", function()
		local db = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns.db

		assert.are.same({}, db.global.projection) -- Core's, empty until login step 3 (LOG-R70, LOG-R72)
		assert.are.same({ coins = 0 }, db.global.celebrated) -- LED-R90
		assert.is_nil(db.profile.activeTitle) -- automatic (LED-R77)
	end)

	it("keeps what an earlier session saved (ledger.md › Data)", function()
		local saved = {
			global = { schemaVersion = 1, celebrated = { coins = 30, species = { [6358] = true } } },
			profileKeys = { ["Angler - Testrealm"] = "Default" },
			profiles = { Default = { activeTitle = "angler" } },
		}
		local db = loadAddon("Pagle_Ledger", foreverWith({ PagleLedgerDB = saved })).ns.db

		assert.are.equal(1, db.global.schemaVersion)
		assert.are.equal(30, db.global.celebrated.coins)
		assert.is_true(db.global.celebrated.species[6358])
		assert.are.equal("angler", db.profile.activeTitle)
	end)
end)

describe("Pagle_Ledger with FakePagle", function()
	it("registers once with the fake and reads On (LED-R1, CORE-R12, CORE-R18)", function()
		local fake = newFakePagle()

		local loaded = fake.load("Pagle_Ledger")

		assert.are.equal("Ledger", fake.registry:ModuleOf(loaded.ns.Module).def.name)
		assert.are.equal("on", fake.moduleState("Ledger"))
		assert.has_no_error(fake.login)
	end)

	it("adds nothing to the fake's compartment menu, /pagle help or settings pages (LED-R1)", function()
		local plain = newFakePagle()
		plain.login()
		local fake = newFakePagle()
		fake.load("Pagle_Ledger")
		fake.login()

		fake.slash("help")

		local function labels(menu)
			local out = {}
			for i, entry in ipairs(menu) do
				out[i] = entry.label
			end
			return out
		end
		assert.are.same(labels(plain.menu()), labels(fake.menu()))
		assert.are.equal(3, #fake.printed)
		for _, topic in ipairs({ "fishing", "announcements", "trackers", "looks" }) do
			assert.is_nil(fake.settingsPage(topic))
		end
	end)

	it("stops while inert, with no SavedVariables touched (CORE-R13)", function()
		local fake = newFakePagle()
		fake.addons.Pagle_Ledger.metadata["X-Pagle-API"] = "2"

		local loaded = fake.load("Pagle_Ledger")

		assert.is_nil(loaded.ns.Module)
		assert.are.equal("needsNewerPagle", fake.moduleState("Ledger"))
		assert.is_nil(loaded.env.PagleLedgerDB)
		assert.is_nil(loaded.ns.db)
		assert.are.same({ "Pagle: Pagle Ledger needs a newer Pagle." }, fake.printed)
	end)
end)

describe("Pagle_Ledger without Pagle", function()
	it("depends on Pagle, so the client won't load it with Core missing or disabled (CORE-R86, CORE-R3)", function()
		local fields = assert(loadAddon("Pagle_Ledger", FOREVER_GLOBALS).client.addons.Pagle_Ledger.metadata)

		assert.are.equal("Pagle", fields.Dependencies)
	end)

	it("off Forever, with no Pagle global, registers nothing and raises no error (CORE-R4, CORE-R11)", function()
		local loaded
		assert.has_no_error(function()
			loaded = loadAddon("Pagle_Ledger", { WOW_PROJECT_ID = PROJECT_IDS.MAINLINE, WOW_PROJECT_CAMELOT = 18 })
		end)

		assert.is_nil(loaded.env.Pagle)
		assert.are.same({}, loaded.ns)
		assert.is_nil(loaded.env.LibStub("AceAddon-3.0"):GetAddon("Pagle_Ledger", true))
		assert.is_nil(loaded.env.PagleLedgerDB)
	end)

	-- A broken install: no Pagle, and nothing else either. Each file must stop at its first line, so it reads no
	-- global but Pagle and writes none.
	for _, file in ipairs(addonFiles("Pagle_Ledger")) do
		it(file .. " starts with the Core guard and does nothing without Pagle (CORE-R11)", function()
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
			local chunk = assert(loadfile("addons/Pagle_Ledger/" .. file))
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

			chunk("Pagle_Ledger", ns)

			assert.are.same({}, touched)
			assert.are.same({}, ns)
		end)
	end
end)
