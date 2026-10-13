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

	it("registers the Fish Journal view and /pagle journal, and no menu entry or settingsAction (LED-R1)", function()
		local def = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).namespaces.Pagle.Modules:Modules()[1].def

		assert.are.equal(1, #def.views)
		assert.are.same({ "journal", "Fish Journal" }, { def.views[1].id, def.views[1].label })
		assert.are.equal(1, #def.slash)
		assert.are.same({ "journal", "Open or close the Fish Journal" }, { def.slash[1].name, def.slash[1].help })
		assert.is_nil(def.menu)
		assert.is_nil(def.settingsAction)
	end)

	it('shows On in the status list, with an "Open Fish Journal" button (SET-R11, CORE-R44, LED-R1)', function()
		local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)
		loaded.client.fire("PLAYER_LOGIN")

		local texts, buttons = statusList(loaded)

		assert.are.same({ "Ledger", "@project-version@", "On", "Open Fish Journal" }, { unpack(texts, 1, 4) })
		assert.are.equal(1, #buttons)
		assert.are.equal("Open Fish Journal", buttons[1]:GetText())
	end)

	it('adds "Fish Journal" to the compartment menu and journal to /pagle help (LED-R1, CORE-R50, CORE-R60)', function()
		local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)
		local plain = loadAddon("Pagle", FOREVER_GLOBALS)
		loaded.client.fire("PLAYER_LOGIN")
		plain.client.fire("PLAYER_LOGIN")

		loaded.env.SlashCmdList.PAGLE("help")

		local texts = compartmentMenu(plain).texts()
		table.insert(texts, 1, "Fish Journal")
		assert.are.same(texts, compartmentMenu(loaded).texts())
		assert.are.same({
			"Pagle commands:",
			"/pagle settings: open Pagle's settings (also /pagle on its own)",
			"/pagle help: list these commands",
			"/pagle journal: Open or close the Fish Journal",
		}, loaded.printed)
	end)

	it(
		"toggles the Fish Journal from /pagle journal, any text after it ignored (LED-R1, LED-R120, CORE-R62)",
		function()
			local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)
			loaded.client.fire("PLAYER_LOGIN")

			loaded.env.SlashCmdList.PAGLE("journal")
			assert.is_true(loaded.ns.journal:IsShown())
			loaded.env.SlashCmdList.PAGLE("Journal anything at all")
			assert.is_false(loaded.ns.journal:IsShown())
			loaded.env.SlashCmdList.PAGLE("journal anything")
			assert.is_true(loaded.ns.journal:IsShown())
		end
	)

	it('toggles the Fish Journal from the compartment\'s "Fish Journal" (LED-R120, CORE-R50)', function()
		local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)
		loaded.client.fire("PLAYER_LOGIN")

		compartmentMenu(loaded).click("Fish Journal")
		assert.is_true(loaded.ns.journal:IsShown())
		compartmentMenu(loaded).click("Fish Journal")
		assert.is_false(loaded.ns.journal:IsShown())
	end)

	it('toggles the Fish Journal from "Open Fish Journal", closing Settings first (LED-R120, SET-R12)', function()
		local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)
		loaded.client.fire("PLAYER_LOGIN")
		local panel = loaded.client.settings.panel
		local journal = loaded.ns.journal
		local toggle = journal.Toggle
		local panelShownAtToggle
		journal.Toggle = function(...)
			panelShownAtToggle = panel:IsShown()
			return toggle(...)
		end
		loaded.env.Pagle.OpenSettings()
		assert.is_true(panel:IsShown())

		local _, buttons = statusList(loaded)
		buttons[1]:Click()

		assert.is_false(panelShownAtToggle)
		assert.is_true(journal:IsShown())
		loaded.env.Pagle.OpenSettings()
		_, buttons = statusList(loaded)
		buttons[1]:Click()
		assert.is_false(journal:IsShown())
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

	it(
		"adds the Fish Journal to the fake's compartment menu and /pagle help, and no settings pages (LED-R1)",
		function()
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
			local expected = labels(plain.menu())
			table.insert(expected, 1, "Fish Journal")
			assert.are.same(expected, labels(fake.menu()))
			assert.are.same({ "/pagle journal: Open or close the Fish Journal" }, { unpack(fake.printed, 4) })
			for _, topic in ipairs({ "fishing", "announcements", "trackers", "looks" }) do
				assert.is_nil(fake.settingsPage(topic))
			end
		end
	)

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
