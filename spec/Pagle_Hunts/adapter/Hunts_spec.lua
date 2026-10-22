-- Pagle_Hunts attaching to Core (HNT-R135, CORE-R11–R13, CORE-R41, CORE-R44, CORE-R86, SET-R11; hunts.md › Data).

-- Each roster Module's state, by name, as Core's Settings status list reads it (CORE-R41).
local function statesOf(core)
	local states = {}
	for _, entry in ipairs(core.ModuleStates()) do
		states[entry.name] = entry.state
	end
	return states
end

-- Puts a counting stand-in at ns.ToggleBoard, where adapter/Board.lua puts the real toggle, and returns
-- what it counted.
local function countToggles(loaded)
	local toggles = { n = 0 }
	loaded.ns.ToggleBoard = function()
		toggles.n = toggles.n + 1
	end
	return toggles
end

describe("Pagle_Hunts with Core", function()
	it("loads after Core, registers once from OnInitialize and reads On (HNT-R135, CORE-R12, CORE-R41)", function()
		local loaded = loadAddon("Pagle_Hunts", FOREVER_GLOBALS)
		local core = loaded.namespaces.Pagle

		local modules = core.Modules:Modules()
		assert.are.equal(1, #modules)
		assert.are.same({ "Hunts", "Hunts", 20 }, { modules[1].def.name, modules[1].def.title, modules[1].def.order })
		assert.are.equal(modules[1].handle, loaded.ns.Module)
		assert.are.equal("on", statesOf(core).Hunts)
	end)

	it("registers the board view and /pagle hunts, and no menu entry or settingsAction (HNT-R135)", function()
		local def = loadAddon("Pagle_Hunts", FOREVER_GLOBALS).ns.ModuleDef(function() end)

		assert.are.equal(1, #def.views)
		assert.are.same({ "board", "Hunts" }, { def.views[1].id, def.views[1].label })
		assert.are.equal(1, #def.slash)
		assert.are.same({ "hunts", "Open or close the Hunts board" }, { def.slash[1].name, def.slash[1].help })
		assert.is_nil(def.menu)
		assert.is_nil(def.settingsAction)
	end)

	it('shows On in the status list, with an "Open Hunts" button (SET-R11, CORE-R44, HNT-R135)', function()
		local loaded = loadAddon("Pagle_Hunts", FOREVER_GLOBALS)
		loaded.client.fire("PLAYER_LOGIN")

		local texts, buttons = loaded.client.settings.statusList()

		-- The roster in CORE-R1 order: the Ledger's row (not installed here, with no button) comes first.
		local at = 1
		while texts[at] ~= "Hunts" do
			at = assert(texts[at + 1] and at + 1, "no Hunts row in the status list")
		end
		assert.are.same({ "Hunts", "@project-version@", "On", "Open Hunts" }, { unpack(texts, at, at + 3) })
		assert.are.equal(1, #buttons)
		assert.are.equal("Open Hunts", buttons[1]:GetText())
	end)

	it('adds "Hunts" to the compartment menu and hunts to /pagle help (HNT-R135, CORE-R50, CORE-R60)', function()
		local loaded = loadAddon("Pagle_Hunts", FOREVER_GLOBALS)
		local plain = loadAddon("Pagle", FOREVER_GLOBALS)
		loaded.client.fire("PLAYER_LOGIN")
		plain.client.fire("PLAYER_LOGIN")

		loaded.env.SlashCmdList.PAGLE("help")

		local texts = plain.client.openCompartmentMenu("Pagle").texts()
		table.insert(texts, 1, "Hunts")
		assert.are.same(texts, loaded.client.openCompartmentMenu("Pagle").texts())
		assert.are.same({
			"Pagle commands:",
			"/pagle settings: open Pagle's settings (also /pagle on its own)",
			"/pagle shop: open or close the Curio Shop",
			"/pagle report: open the Field report, to help chart the waters",
			"/pagle guide: open the Field guide; /pagle guide notes shows the margin notes again",
			"/pagle help: list these commands",
			"/pagle hunts: Open or close the Hunts board",
		}, loaded.printed)
	end)

	it(
		"reaches ns.ToggleBoard as it is when called, from /pagle hunts, the compartment and the status button",
		function()
			-- HNT-R135, HNT-R68: every entry point toggles the board through ns.ToggleBoard.
			local loaded = loadAddon("Pagle_Hunts", FOREVER_GLOBALS)
			loaded.client.fire("PLAYER_LOGIN")
			local toggles = countToggles(loaded)

			loaded.env.SlashCmdList.PAGLE("hunts")
			loaded.env.SlashCmdList.PAGLE("Hunts anything at all")
			loaded.client.openCompartmentMenu("Pagle").click("Hunts")
			local _, buttons = loaded.client.settings.statusList()
			buttons[1]:Click()

			assert.are.equal(4, toggles.n)
		end
	)

	it("toggles the same board from /pagle hunts, the compartment's Hunts and the status button (HNT-R68)", function()
		local loaded = loadAddon("Pagle_Hunts", FOREVER_GLOBALS)
		loaded.client.fire("PLAYER_LOGIN")
		local board = loaded.ns.board

		loaded.env.SlashCmdList.PAGLE("hunts")
		local frame = board.frame
		assert.is_true(board:IsShown())
		loaded.client.openCompartmentMenu("Pagle").click("Hunts")
		assert.is_false(board:IsShown())
		loaded.client.openCompartmentMenu("Pagle").click("Hunts")
		assert.is_true(board:IsShown())
		loaded.env.SlashCmdList.PAGLE("Hunts anything at all")
		assert.is_false(board:IsShown())

		assert.are.equal(frame, board.frame)
		local made = 0
		for _, each in ipairs(loaded.client.frames) do
			made = made + (each.name == "PagleHuntsBoard" and 1 or 0)
		end
		assert.are.equal(1, made)
	end)

	it('toggles the board from "Open Hunts", closing Settings first (HNT-R68, SET-R12)', function()
		local loaded = loadAddon("Pagle_Hunts", FOREVER_GLOBALS)
		loaded.client.fire("PLAYER_LOGIN")
		local panel = loaded.client.settings.panel
		local board = loaded.ns.board
		local toggle = board.Toggle
		local panelShownAtToggle
		board.Toggle = function(...)
			panelShownAtToggle = panel:IsShown()
			return toggle(...)
		end
		loaded.env.Pagle.OpenSettings()
		assert.is_true(panel:IsShown())

		local _, buttons = loaded.client.settings.statusList()
		buttons[1]:Click()

		assert.is_false(panelShownAtToggle)
		assert.is_true(board:IsShown())
		loaded.env.Pagle.OpenSettings()
		_, buttons = loaded.client.settings.statusList()
		buttons[1]:Click()
		assert.is_false(board:IsShown())
	end)

	it("opens the board from each entry point while restricted (HNT-R68)", function()
		local loaded = loadAddon("Pagle_Hunts", FOREVER_GLOBALS)
		loaded.client.fire("PLAYER_LOGIN")
		setCombat(loaded, true)
		assert.is_true(loaded.env.Pagle.IsRestricted())

		loaded.env.SlashCmdList.PAGLE("hunts")
		assert.is_true(loaded.ns.board:IsShown())
		loaded.client.openCompartmentMenu("Pagle").click("Hunts")
		assert.is_false(loaded.ns.board:IsShown())
		loaded.client.openCompartmentMenu("Pagle").click("Hunts")
		assert.is_true(loaded.ns.board:IsShown())
	end)

	it(
		"adds no settings page but Trackers, for its tracker frame's dropdown (HNT-R135, HNT-R120, CORE-R42, SET-R44)",
		function()
			local loaded = loadAddon("Pagle_Hunts", FOREVER_GLOBALS)
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
			local expected = categories(plain.client)
			assert.are.equal("Look and Feel", expected[#expected])
			table.insert(expected, #expected, "Trackers") -- before Look and Feel, the last (SET-R1)
			assert.are.same(expected, categories(loaded.client))
		end
	)

	it("keeps PagleHuntsDB account-wide in one shared profile, at schema 1 (hunts.md › Data)", function()
		local loaded = loadAddon("Pagle_Hunts", FOREVER_GLOBALS)
		local db = loaded.ns.db

		assert.are.equal("Default", db:GetCurrentProfile())
		assert.are.equal(1, rawget(loaded.env.PagleHuntsDB.global, "schemaVersion"))
	end)

	it("starts with hunts.md › Data's defaults: tracker shown, nothing pinned, nothing celebrated", function()
		local db = loadAddon("Pagle_Hunts", FOREVER_GLOBALS).ns.db

		assert.are.same({ shown = true, collapsed = false }, db.profile.tracker) -- HNT-R75–R79
		assert.is_false(db.profile.windowMoments) -- HNT-R88
		assert.is_false(db.profile.showCompleted) -- HNT-R82
		assert.are.same({}, db.profile.pins) -- HNT-R81
		assert.are.same({ tiers = {}, sets = {}, runs = {}, ladder = {} }, db.global.celebrated) -- HNT-R90
	end)

	it("keeps what an earlier login saved (hunts.md › Data)", function()
		local saved = {
			global = { schemaVersion = 1, celebrated = { tiers = { night_run = 2 }, sets = { camp_hours = true } } },
			profileKeys = { ["Angler - Testrealm"] = "Default" },
			profiles = {
				Default = {
					tracker = { shown = false, collapsed = true },
					windowMoments = true,
					showCompleted = true,
					pins = { dawn_trout = true },
				},
			},
		}
		local db = loadAddon("Pagle_Hunts", foreverWith({ PagleHuntsDB = saved })).ns.db

		assert.are.equal(1, db.global.schemaVersion)
		-- A set saved before Hunt Events gains empty run and ladder entries (HNT-R90).
		assert.are.same(
			{ tiers = { night_run = 2 }, sets = { camp_hours = true }, runs = {}, ladder = {} },
			db.global.celebrated
		)
		assert.are.same({ shown = false, collapsed = true }, db.profile.tracker)
		assert.is_true(db.profile.windowMoments)
		assert.is_true(db.profile.showCompleted)
		-- dawn_trout isn't a current Hunt at SERVER_TIME, so its pin is dropped at load (HNT-R81, adapter/Groups_spec).
		assert.are.same({}, db.profile.pins)
	end)
end)

describe("Pagle_Hunts with FakePagle", function()
	it("registers once with the fake and reads On (HNT-R135, CORE-R12, CORE-R18)", function()
		local fake = newFakePagle()

		local loaded = fake.load("Pagle_Hunts")

		assert.are.equal("Hunts", fake.registry:ModuleOf(loaded.ns.Module).def.name)
		assert.are.equal("on", fake.moduleState("Hunts"))
		assert.has_no_error(fake.login)
	end)

	it("adds Hunts to the fake's compartment menu and /pagle help (HNT-R135)", function()
		local plain = newFakePagle()
		plain.login()
		local fake = newFakePagle()
		fake.load("Pagle_Hunts")
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
		table.insert(expected, 1, "Hunts")
		assert.are.same(expected, labels(fake.menu()))
		assert.are.same({ "/pagle hunts: Open or close the Hunts board" }, { unpack(fake.printed, 7) })
	end)

	it("stops after RegisterModule returns nil, with no SavedVariables touched (CORE-R13)", function()
		local fake = newFakePagle()
		fake.addons.Pagle_Hunts.metadata["X-Pagle-API"] = "2"

		local loaded = fake.load("Pagle_Hunts")

		assert.is_nil(loaded.ns.Module)
		assert.are.equal("needsNewerPagle", fake.moduleState("Hunts"))
		assert.is_nil(loaded.env.PagleHuntsDB)
		assert.is_nil(loaded.ns.db)
		assert.is_nil(loaded.ns.hunts)
		assert.are.same({ "Pagle: Pagle Hunts needs a newer Pagle." }, fake.printed)
	end)
end)

describe("Pagle_Hunts without Pagle", function()
	it("depends on Pagle, so the client won't load it with Core missing or disabled (CORE-R86, CORE-R3)", function()
		local fields = assert(loadAddon("Pagle_Hunts", FOREVER_GLOBALS).client.addons.Pagle_Hunts.metadata)

		assert.are.equal("Pagle", fields.Dependencies)
	end)

	it("off Forever, with no Pagle global, registers nothing and raises no error (CORE-R4, CORE-R11)", function()
		local loaded
		assert.has_no_error(function()
			loaded = loadAddon("Pagle_Hunts", { WOW_PROJECT_ID = PROJECT_IDS.MAINLINE, WOW_PROJECT_CAMELOT = 18 })
		end)

		assert.is_nil(loaded.env.Pagle)
		assert.are.same({}, loaded.ns)
		assert.is_nil(loaded.env.LibStub("AceAddon-3.0"):GetAddon("Pagle_Hunts", true))
		assert.is_nil(loaded.env.PagleHuntsDB)
	end)

	-- A broken install: no Pagle, and nothing else either. Each file must stop at its first line, so it reads no
	-- global but Pagle and writes none.
	for _, file in ipairs(addonFiles("Pagle_Hunts")) do
		it(file .. " starts with the Core guard and does nothing without Pagle (CORE-R11)", function()
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
			local chunk = assert(loadfile("addons/Pagle_Hunts/" .. file))
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

			chunk("Pagle_Hunts", ns)

			assert.are.same({}, touched)
			assert.are.same({}, ns)
		end)
	end
end)
