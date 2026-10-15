-- Pagle_Stats attaching to Core (STA-R1, STA-R4, CORE-R11–R13, CORE-R41, CORE-R44, CORE-R50, CORE-R86, SET-R11;
-- stats.md › Data).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

-- Each roster Module's state, by name, as Core's Settings status list reads it (CORE-R41).
local function statesOf(core)
	local states = {}
	for _, entry in ipairs(core.ModuleStates()) do
		states[entry.name] = entry.state
	end
	return states
end

-- Clicks Pagle in the Addon Compartment and returns the menu Core opens on the next frame (CORE-R50).
local function compartmentMenu(loaded)
	local opened = #loaded.client.menus
	loaded.client.clickCompartment("Pagle")
	loaded.client.runTimers()
	return loaded.client.menus[opened + 1]
end

-- Puts a counting stand-in at ns.ToggleBook, as adapter/Book.lua puts the real toggle there, and returns
-- what it counted.
local function countToggles(loaded)
	local toggles = { n = 0 }
	loaded.ns.ToggleBook = function()
		toggles.n = toggles.n + 1
	end
	return toggles
end

-- The names of the globals `env` holds, as a set.
local function globalNames(env)
	local names = {}
	for name in pairs(env) do
		names[name] = true
	end
	return names
end

describe("Pagle_Stats with Core", function()
	it("loads after Core, registers once from OnInitialize and reads On (STA-R4, CORE-R12, CORE-R41)", function()
		local loaded = loadAddon("Pagle_Stats", FOREVER_GLOBALS)
		local core = loaded.namespaces.Pagle

		local modules = core.Modules:Modules()
		assert.are.equal(1, #modules)
		assert.are.same({ "Stats", "Stats", 30 }, { modules[1].def.name, modules[1].def.title, modules[1].def.order })
		assert.are.equal(modules[1].handle, loaded.ns.Module)
		assert.are.equal("on", statesOf(core).Stats)
	end)

	it(
		"registers stats.md's def exactly: the book view, /pagle stats, no menu and no settingsAction (STA-R4)",
		function()
			local def = loadAddon("Pagle_Stats", FOREVER_GLOBALS).ns.ModuleDef(function() end)

			assert.are.equal(1, #def.views)
			assert.are.same({ "book", "Stats" }, { def.views[1].id, def.views[1].label })
			assert.are.equal(1, #def.slash)
			assert.are.same({ "stats", "Open or close the Stats book." }, { def.slash[1].name, def.slash[1].help })
			assert.is_nil(def.menu)
			assert.is_nil(def.settingsAction)
		end
	)

	it('shows On in the status list, with an "Open Stats" button (SET-R11, CORE-R44, STA-R4)', function()
		local loaded = loadAddon("Pagle_Stats", FOREVER_GLOBALS)
		loaded.client.fire("PLAYER_LOGIN")

		local texts, buttons = loaded.client.settings.statusList()

		-- The roster in CORE-R1 order: the Ledger's and Hunts' rows (not installed here, with no button) come first.
		local at = 1
		while texts[at] ~= "Stats" do
			at = assert(texts[at + 1] and at + 1, "no Stats row in the status list")
		end
		assert.are.same({ "Stats", "@project-version@", "On", "Open Stats" }, { unpack(texts, at, at + 3) })
		assert.are.equal(1, #buttons)
		assert.are.equal("Open Stats", buttons[1]:GetText())
	end)

	it('adds "Stats" to the compartment menu and stats to /pagle help (STA-R4, CORE-R50, CORE-R60)', function()
		local loaded = loadAddon("Pagle_Stats", FOREVER_GLOBALS)
		local plain = loadAddon("Pagle", FOREVER_GLOBALS)
		loaded.client.fire("PLAYER_LOGIN")
		plain.client.fire("PLAYER_LOGIN")

		loaded.env.SlashCmdList.PAGLE("help")

		local texts = compartmentMenu(plain).texts()
		table.insert(texts, 1, "Stats")
		assert.are.same(texts, compartmentMenu(loaded).texts())
		assert.are.same({
			"Pagle commands:",
			"/pagle settings: open Pagle's settings (also /pagle on its own)",
			"/pagle shop: open or close the Curio Shop",
			"/pagle report: open the Field report, to help chart the waters",
			"/pagle help: list these commands",
			"/pagle stats: Open or close the Stats book.",
		}, loaded.printed)
	end)

	it(
		"reaches ns.ToggleBook as it is when called, from /pagle stats, the compartment and the status button"
			.. " (STA-R4, CORE-R44, CORE-R50, CORE-R62)",
		function()
			-- Every entry point toggles the book; adapter/Book.lua fills ns.ToggleBook in.
			local loaded = loadAddon("Pagle_Stats", FOREVER_GLOBALS)
			loaded.client.fire("PLAYER_LOGIN")
			local toggles = countToggles(loaded)

			loaded.env.SlashCmdList.PAGLE("stats")
			loaded.env.SlashCmdList.PAGLE("Stats anything at all")
			compartmentMenu(loaded).click("Stats")
			local _, buttons = loaded.client.settings.statusList()
			buttons[1]:Click()

			assert.are.equal(4, toggles.n)
		end
	)

	it(
		"toggles PagleStatsBook from /pagle stats, /pagle stats with any text, the compartment and the status button"
			.. " (STA-R70, STA-R4, CORE-R44, CORE-R50, CORE-R62, SET-R12)",
		function()
			-- Each entry point toggles the book.
			local loaded = loadAddon("Pagle_Stats", FOREVER_GLOBALS)
			loaded.client.fire("PLAYER_LOGIN")
			local function shown()
				for _, frame in ipairs(loaded.client.frames) do
					if frame.name == "PagleStatsBook" then
						return frame:IsShown()
					end
				end
				return false
			end

			local seen = {}
			loaded.env.SlashCmdList.PAGLE("stats")
			seen[#seen + 1] = shown()
			loaded.env.SlashCmdList.PAGLE("stats anything at all")
			seen[#seen + 1] = shown()
			compartmentMenu(loaded).click("Stats")
			seen[#seen + 1] = shown()
			local _, buttons = loaded.client.settings.statusList()
			buttons[1]:Click()
			seen[#seen + 1] = shown()

			assert.are.same({ true, false, true, false }, seen)
		end
	)

	it("opens and toggles the book in combat, while restricted (STA-R70, STA-R93)", function()
		local loaded = loadAddon("Pagle_Stats", FOREVER_GLOBALS)
		loaded.client.fire("PLAYER_LOGIN")
		setCombat(loaded, true)

		loaded.env.SlashCmdList.PAGLE("stats")

		assert.is_true(loaded.ns.book:IsShown())
	end)

	it(
		"adds no settings pages of its own, only Core's Trackers page for its section (STA-R4, CORE-R42, SET-R44)",
		function()
			local loaded = loadAddon("Pagle_Stats", FOREVER_GLOBALS)
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
			assert.are.same({ "Pagle", "Announcements", "Look and Feel" }, categories(plain.client))
			-- Core's own pages, with its Trackers page for Stats' section: Core's frame dropdown at least (STA-R88).
			assert.are.same({ "Pagle", "Announcements", "Trackers", "Look and Feel" }, categories(loaded.client))
		end
	)

	it(
		"sets no global but PagleStatsDB and its row's mixin: its AceAddon is reached through LibStub (STA-R1)",
		function()
			local loaded = loadAddon("Pagle_Stats", FOREVER_GLOBALS)
			local plain = loadAddon("Pagle", FOREVER_GLOBALS)
			loaded.client.fire("PLAYER_LOGIN")
			plain.client.fire("PLAYER_LOGIN")

			local added = {}
			local before = globalNames(plain.env)
			for name in pairs(globalNames(loaded.env)) do
				if not before[name] then
					added[#added + 1] = name
				end
			end

			-- The Watched Dry spells row's mixin, which its XML template names (adapter/Settings.xml, SET-R5).
			table.sort(added)
			assert.are.same({ "PagleStatsDB", "PagleStatsWatchedRowMixin" }, added)
			assert.are.equal(loaded.ns.Stats, loaded.env.LibStub("AceAddon-3.0"):GetAddon("Pagle_Stats"))
		end
	)

	it("keeps PagleStatsDB account-wide in one shared profile, at schema 1 (stats.md › Data)", function()
		local loaded = loadAddon("Pagle_Stats", FOREVER_GLOBALS)
		local db = loaded.ns.db

		assert.are.equal("Default", db:GetCurrentProfile())
		assert.are.equal(1, rawget(loaded.env.PagleStatsDB.global, "schemaVersion"))
	end)

	it("starts with stats.md › Data's defaults: no tracker, nothing watched, the book centred", function()
		local db = loadAddon("Pagle_Stats", FOREVER_GLOBALS).ns.db

		assert.is_false(db.profile.tracker) -- "Show the live tracker" (STA-R81)
		assert.are.same({}, db.profile.watched) -- STA-R60
		assert.is_nil(db.profile.window) -- centred (STA-R71)
	end)

	it(
		"keeps no celebrated set and makes an empty projection table for Core (stats.md › Data, LOG-R70, LOG-R77)",
		function()
			local db = loadAddon("Pagle_Stats", FOREVER_GLOBALS).ns.db

			assert.is_nil(db.global.celebrated)
			assert.are.same({}, db.global.projection) -- before login: Core writes its keys at the first build
		end
	)

	it("keeps what an earlier login saved (stats.md › Data)", function()
		local saved = {
			global = { schemaVersion = 1 },
			profileKeys = { ["Angler - Testrealm"] = "Default" },
			profiles = {
				Default = {
					tracker = true,
					watched = { { item = 13759, area = 148 }, { item = 6358, area = 331 } },
					window = { "TOPLEFT", "TOPLEFT", 120, -80 },
				},
			},
		}
		local db = loadAddon("Pagle_Stats", foreverWith({ PagleStatsDB = saved })).ns.db

		assert.are.equal(1, db.global.schemaVersion)
		assert.is_true(db.profile.tracker)
		assert.are.same({ { item = 13759, area = 148 }, { item = 6358, area = 331 } }, db.profile.watched)
		assert.are.same({ "TOPLEFT", "TOPLEFT", 120, -80 }, db.profile.window)
	end)
end)

describe("Pagle_Stats with FakePagle", function()
	it("registers once with the fake and reads On (STA-R4, CORE-R12, CORE-R18)", function()
		local loaded, fake = stats.load()

		assert.are.equal("Stats", fake.registry:ModuleOf(loaded.ns.Module).def.name)
		assert.are.equal("on", fake.moduleState("Stats"))
		assert.has_no_error(fake.login)
	end)

	it("adds Stats to the fake's compartment menu and /pagle help (STA-R4)", function()
		local plain = newFakePagle()
		plain.login()
		local _, fake = stats.load()
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
		table.insert(expected, 1, "Stats")
		assert.are.same(expected, labels(fake.menu()))
		assert.are.same({ "/pagle stats: Open or close the Stats book." }, { unpack(fake.printed, 6) })
	end)

	it(
		"reads places, lines and windows from Core's catalogue, afresh after a content update (STA-R12–R17, LOG-R72)",
		function()
			local loaded, fake = stats.load()
			local places = loaded.ns.places

			assert.are.same({ 170, true }, { places:NoJunkLine(442) })
			assert.are.equal("night", (places:ItemWindow(148, 13759)))
			assert.are.equal("hi", places:Side(148, 170))
			assert.are.same(
				{ { item = 6359, added = false }, { item = 6291, added = false } },
				places:Rows({ places = {} }, 442)
			)

			local updated = stats.catalogue()
			updated.fingerprint = "0000000000000003"
			updated.areas[148].skillBase = 200
			fake.setCatalogue(updated)

			assert.are.equal("lo", places:Side(148, 170))
		end
	)

	it("stops after RegisterModule returns nil, with no SavedVariables touched (CORE-R13)", function()
		local fake = newFakePagle()
		fake.addons.Pagle_Stats.metadata["X-Pagle-API"] = "2"

		local loaded = stats.load(fake)

		assert.is_nil(loaded.ns.Module)
		assert.are.equal("needsNewerPagle", fake.moduleState("Stats"))
		assert.is_nil(loaded.env.PagleStatsDB)
		assert.is_nil(loaded.ns.db)
		assert.are.same({ "Pagle: Pagle Stats needs a newer Pagle." }, fake.printed)
	end)
end)

describe("Pagle_Stats without Pagle", function()
	it("depends on Pagle, so the client won't load it with Core missing or disabled (CORE-R86, CORE-R3)", function()
		local fields = assert(loadAddon("Pagle_Stats", FOREVER_GLOBALS).client.addons.Pagle_Stats.metadata)

		assert.are.equal("Pagle", fields.Dependencies)
	end)

	it("off Forever, with no Pagle global, registers nothing and raises no error (CORE-R4, CORE-R11)", function()
		local loaded
		assert.has_no_error(function()
			loaded = loadAddon("Pagle_Stats", { WOW_PROJECT_ID = PROJECT_IDS.MAINLINE, WOW_PROJECT_CAMELOT = 18 })
		end)

		assert.is_nil(loaded.env.Pagle)
		assert.are.same({}, loaded.ns)
		assert.is_nil(loaded.env.LibStub("AceAddon-3.0"):GetAddon("Pagle_Stats", true))
		assert.is_nil(loaded.env.PagleStatsDB)
	end)

	-- A broken install: no Pagle, and nothing else either. Each file must stop at its first line, so it reads no
	-- global but Pagle and writes none. An XML file only defines templates, which the client builds without running
	-- Lua (adapter/Settings.xml).
	local luaFiles = {}
	for _, file in ipairs(addonFiles("Pagle_Stats")) do
		if file:match("%.lua$") then
			luaFiles[#luaFiles + 1] = file
		end
	end
	for _, file in ipairs(luaFiles) do
		it(file .. " starts with the Core guard and does nothing without Pagle (CORE-R11)", function()
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
			local chunk = assert(loadfile("addons/Pagle_Stats/" .. file))
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

			chunk("Pagle_Stats", ns)

			assert.are.same({}, touched)
			assert.are.same({}, ns)
		end)
	end
end)
