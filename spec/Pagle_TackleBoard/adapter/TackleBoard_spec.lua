-- Pagle_TackleBoard attaching to Core (TKB-R1–R3, CORE-R11–R13, CORE-R41, CORE-R44, CORE-R50, CORE-R86, SET-R11,
-- SET-R12; tackle-board.md › Data).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

-- Each roster Module's state, by name, as Core's Settings status list reads it (CORE-R41).
local function statesOf(core)
	local states = {}
	for _, entry in ipairs(core.ModuleStates()) do
		states[entry.name] = entry.state
	end
	return states
end

-- Shows the Settings root and returns the texts and the shown buttons of its status list, a row per Module (SET-R11).
local function statusList(loaded)
	return loaded.client.settings.statusList()
end

-- The Tackle Board's row of the status list: its name, version, state and button text (SET-R11).
local function boardRow(loaded)
	local texts = statusList(loaded)
	for at, text in ipairs(texts) do
		if text == "Tackle Board" then
			return { unpack(texts, at, at + 3) }
		end
	end
	error("no Tackle Board row in the status list")
end

-- Clicks Pagle in the Addon Compartment and returns the menu Core opens on the next frame (CORE-R50).
local function compartmentMenu(loaded)
	local opened = #loaded.client.menus
	loaded.client.clickCompartment("Pagle")
	loaded.client.runTimers()
	return loaded.client.menus[opened + 1]
end

-- Puts counting stand-ins at the seams the entry points reach (ns.ToggleBoard, ns.OpenBoard, ns.Start), as the
-- board's and the live step's tickets put the real ones there, and returns what they counted, in order.
local function countCalls(loaded)
	local calls = {}
	for _, seam in ipairs({ "ToggleBoard", "OpenBoard", "Start" }) do
		loaded.ns[seam] = function(...)
			calls[#calls + 1] = select("#", ...) > 0 and (seam .. " " .. tostring((...))) or seam
		end
	end
	return calls
end

-- The names of the globals `env` holds, as a set.
local function globalNames(env)
	local names = {}
	for name in pairs(env) do
		names[name] = true
	end
	return names
end

describe("Pagle_TackleBoard with Core", function()
	it("loads after Core, registers once from OnInitialize and reads On (TKB-R1, CORE-R12, CORE-R41)", function()
		local loaded = loadAddon("Pagle_TackleBoard", FOREVER_GLOBALS)
		local core = loaded.namespaces.Pagle

		local modules = core.Modules:Modules()
		assert.are.equal(1, #modules)
		assert.are.same(
			{ "TackleBoard", "Tackle Board", 40 },
			{ modules[1].def.name, modules[1].def.title, modules[1].def.order }
		)
		assert.are.equal(modules[1].handle, loaded.ns.Module)
		assert.are.equal("on", statesOf(core).TackleBoard)
	end)

	it("registers tackle-board.md › Contracts exactly: the board view, /pagle board, no menu (TKB-R1)", function()
		local def = loadAddon("Pagle_TackleBoard", FOREVER_GLOBALS).ns.ModuleDef()

		assert.are.equal(1, #def.views)
		assert.are.same({ "board", "Tackle Board" }, { def.views[1].id, def.views[1].label })
		assert.are.equal(1, #def.slash)
		assert.are.same({ "board", "Open or close the Tackle Board" }, { def.slash[1].name, def.slash[1].help })
		assert.is_nil(def.menu)
		assert.are.equal("function", type(def.settingsAction.label))
	end)

	it(
		'shows On in the status list, with a "Start my board" button before Start (SET-R11, CORE-R44, TKB-R1)',
		function()
			local loaded = loadAddon("Pagle_TackleBoard", FOREVER_GLOBALS)
			loaded.client.fire("PLAYER_LOGIN")

			local _, buttons = statusList(loaded)

			assert.are.same({ "Tackle Board", "dev", "On", "Start my board" }, boardRow(loaded))
			assert.are.equal(1, #buttons)
			assert.are.equal("Start my board", buttons[1]:GetText())
		end
	)

	it('reads "Open Tackle Board" at the next showing once the board is started (SET-R12, TKB-R1)', function()
		local loaded = loadAddon("Pagle_TackleBoard", FOREVER_GLOBALS)
		loaded.client.fire("PLAYER_LOGIN")
		assert.are.equal("Start my board", boardRow(loaded)[4])

		loaded.ns.IsStarted = function()
			return true
		end

		assert.are.same({ "Tackle Board", "dev", "On", "Open Tackle Board" }, boardRow(loaded))
	end)

	it('adds "Tackle Board" to the compartment menu and board to /pagle help (TKB-R1, CORE-R50, CORE-R60)', function()
		local loaded = loadAddon("Pagle_TackleBoard", FOREVER_GLOBALS)
		local plain = loadAddon("Pagle", FOREVER_GLOBALS)
		loaded.client.fire("PLAYER_LOGIN")
		plain.client.fire("PLAYER_LOGIN")

		loaded.env.SlashCmdList.PAGLE("help")

		local texts = compartmentMenu(plain).texts()
		table.insert(texts, 1, "Tackle Board")
		assert.are.same(texts, compartmentMenu(loaded).texts())
		assert.are.same({
			"Pagle commands:",
			"/pagle settings: open Pagle's settings (also /pagle on its own)",
			"/pagle shop: open or close the Curio Shop",
			"/pagle report: open the Field report, to help chart the waters",
			"/pagle export: copy your Catch log as a Paste string for the Pagle website",
			"/pagle guide: open the Field guide; /pagle guide notes shows the margin notes again",
			"/pagle help: list these commands",
			"/pagle board: Open or close the Tackle Board",
		}, loaded.printed)
	end)

	it("reaches ns.ToggleBoard as it is when called, from /pagle board and the compartment (TKB-R1)", function()
		local loaded = loadAddon("Pagle_TackleBoard", FOREVER_GLOBALS)
		loaded.client.fire("PLAYER_LOGIN")
		local calls = countCalls(loaded)

		loaded.env.SlashCmdList.PAGLE("board")
		loaded.env.SlashCmdList.PAGLE("Board stop")
		compartmentMenu(loaded).click("Tackle Board")

		assert.are.same({ "ToggleBoard", "ToggleBoard", "ToggleBoard" }, calls)
	end)

	it('starts the board, then opens it, from "Start my board" (TKB-R1, TKB-R5)', function()
		local loaded = loadAddon("Pagle_TackleBoard", FOREVER_GLOBALS)
		enterWorld(loaded, 1) -- the projection's first build has ended: not updating (LOG-R74)
		local calls = countCalls(loaded)

		local _, buttons = statusList(loaded)
		buttons[1]:Click()

		assert.are.same({ "Start", "OpenBoard" }, calls)
	end)

	it('only opens the board from "Start my board" while the projection is updating (TKB-R1)', function()
		local loaded = loadAddon("Pagle_TackleBoard", FOREVER_GLOBALS)
		loaded.client.fire("PLAYER_LOGIN")
		local calls = countCalls(loaded)
		loaded.ns.IsUpdating = function()
			return true
		end

		local _, buttons = statusList(loaded)
		buttons[1]:Click()

		assert.are.same({ "OpenBoard" }, calls)
	end)

	it(
		'only opens the board from "Open Tackle Board": a started board is never started again (TKB-R1, TKB-R6)',
		function()
			local loaded = loadAddon("Pagle_TackleBoard", FOREVER_GLOBALS)
			loaded.client.fire("PLAYER_LOGIN")
			local calls = countCalls(loaded)
			loaded.ns.IsStarted = function()
				return true
			end

			local _, buttons = statusList(loaded)
			buttons[1]:Click()

			assert.are.same({ "OpenBoard" }, calls)
		end
	)

	it(
		"toggles PagleTackleBoard from /pagle board, /pagle board with any text and the compartment, and the status "
			.. "button opens it (TKB-R1, CORE-R44, CORE-R50, CORE-R62, SET-R12)",
		function()
			-- Each entry point reaches the board; the status button, Start my board or Open Tackle Board, only ever opens
			-- it.
			local loaded = loadAddon("Pagle_TackleBoard", FOREVER_GLOBALS)
			loaded.client.fire("PLAYER_LOGIN")
			local function shown()
				for _, frame in ipairs(loaded.client.frames) do
					if frame.name == "PagleTackleBoard" then
						return frame:IsShown()
					end
				end
				return false
			end
			local function statusButton()
				local _, buttons = statusList(loaded)
				buttons[1]:Click()
			end

			local seen = {}
			loaded.env.SlashCmdList.PAGLE("board")
			seen[#seen + 1] = shown()
			loaded.env.SlashCmdList.PAGLE("board anything at all")
			seen[#seen + 1] = shown()
			compartmentMenu(loaded).click("Tackle Board")
			seen[#seen + 1] = shown()
			statusButton()
			seen[#seen + 1] = shown()
			compartmentMenu(loaded).click("Tackle Board")
			seen[#seen + 1] = shown()
			statusButton()
			seen[#seen + 1] = shown()

			assert.are.same({ true, false, true, true, false, true }, seen)
		end
	)

	it("opens the board and starts it from its Start button in combat, while restricted (TKB-R193, TKB-R5)", function()
		local loaded = loadAddon("Pagle_TackleBoard", FOREVER_GLOBALS)
		enterWorld(loaded, 1) -- the projection's first build has ended: not updating (LOG-R74)
		local starts = 0
		loaded.ns.Start = function()
			starts = starts + 1
		end
		setCombat(loaded, true)

		loaded.env.SlashCmdList.PAGLE("board")
		loaded.ns.board.frame.start:Click()

		assert.is_true(loaded.ns.board:IsShown())
		assert.are.equal(1, starts)
	end)

	it(
		"sets no global but PagleTackleBoardDB, its board's frame and its reroll confirm's frame: its AceAddon is"
			.. " reached through LibStub alone (ADR 0001)",
		function()
			-- tackle-board.md › Exposed: nothing; no other Module can see the Tackle Board. The board's frame and the
			-- confirm's are named for UISpecialFrames (Esc, TKB-R100, TKB-R56).
			local loaded = loadAddon("Pagle_TackleBoard", FOREVER_GLOBALS)
			local plain = loadAddon("Pagle", FOREVER_GLOBALS)
			enterWorld(loaded, 1)
			enterWorld(plain, 1)
			local dialogs = globalNames(loaded.env.StaticPopupDialogs)
			loaded.ns.Start()
			loaded.ns.ToggleBoard()
			local goalIDs = {}
			for id in pairs(loaded.ns.State().goals) do
				goalIDs[#goalIDs + 1] = id
			end
			loaded.ns.TakeDownQuestion = function() -- as when the goal shows progress (TKB-R56)
				return { title = "Take it down?", text = "It goes.", progress = "1/2" }
			end
			loaded.ns.TakeDown(goalIDs[1])

			local added, addedDialogs = {}, {}
			local before = globalNames(plain.env)
			for name in pairs(globalNames(loaded.env)) do
				if not before[name] then
					added[#added + 1] = name
				end
			end
			for name in pairs(loaded.env.StaticPopupDialogs) do
				if not dialogs[name] then
					addedDialogs[#addedDialogs + 1] = name
				end
			end
			table.sort(added)

			assert.are.same({ "PagleTackleBoard", "PagleTackleBoardConfirm", "PagleTackleBoardDB" }, added)
			assert.are.same({}, addedDialogs)
			assert.are.equal(loaded.ns.TackleBoard, loaded.env.LibStub("AceAddon-3.0"):GetAddon("Pagle_TackleBoard"))
		end
	)

	it("keeps PagleTackleBoardDB account-wide in one shared profile, at schema 1 (tackle-board.md › Data)", function()
		local loaded = loadAddon("Pagle_TackleBoard", FOREVER_GLOBALS)
		local db = loaded.ns.db

		assert.are.equal("Default", db:GetCurrentProfile())
		assert.are.equal(1, rawget(loaded.env.PagleTackleBoardDB.global, "schemaVersion"))
	end)

	it("starts with tackle-board.md › Data's defaults: the tracker on and expanded, nothing celebrated", function()
		local db = loadAddon("Pagle_TackleBoard", FOREVER_GLOBALS).ns.db

		assert.is_true(db.profile.tracker) -- "Show goals workable here" (TKB-R120)
		assert.is_false(db.profile.trackerCollapsed) -- TKB-R122
		assert.are.same({ goals = {}, titles = {} }, db.global.celebrated) -- TKB-R83
	end)

	it("leaves the projection table to Core: no board default, the projection binds it (LOG-R70, TKB-R81)", function()
		local ns = loadAddon("Pagle_TackleBoard", FOREVER_GLOBALS).ns

		assert.is_nil(ns.DB_DEFAULTS.global.board)
		assert.are.same({}, ns.db.global.board) -- before login: bound, nothing stored yet
	end)

	it("keeps what an earlier login saved (tackle-board.md › Data)", function()
		local saved = {
			global = {
				schemaVersion = 1,
				celebrated = { goals = { ["Player-4618-0A1B2C3D-1791731747-0"] = true }, titles = { tally_25 = true } },
			},
			profileKeys = { ["Angler - Testrealm"] = "Default" },
			profiles = { Default = { tracker = false, trackerCollapsed = true } },
		}
		local db = loadAddon("Pagle_TackleBoard", foreverWith({ PagleTackleBoardDB = saved })).ns.db

		assert.are.equal(1, db.global.schemaVersion)
		assert.is_false(db.profile.tracker)
		assert.is_true(db.profile.trackerCollapsed)
		assert.are.same(
			{ goals = { ["Player-4618-0A1B2C3D-1791731747-0"] = true }, titles = { tally_25 = true } },
			db.global.celebrated
		)
	end)
end)

describe("Pagle_TackleBoard with FakePagle", function()
	it("registers once with the fake and reads On (TKB-R1, CORE-R12, CORE-R18)", function()
		local loaded, fake = board.load()

		assert.are.equal("TackleBoard", fake.registry:ModuleOf(loaded.ns.Module).def.name)
		assert.are.equal("on", fake.moduleState("TackleBoard"))
		assert.has_no_error(fake.login)
	end)

	it("adds the Tackle Board to the fake's compartment menu and /pagle help (TKB-R1)", function()
		local plain = newFakePagle()
		plain.login()
		local _, fake = board.load()
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
		table.insert(expected, 1, "Tackle Board")
		assert.are.same(expected, labels(fake.menu()))
		assert.are.same({ "/pagle board: Open or close the Tackle Board" }, { unpack(fake.printed, 8) })
	end)

	it("stops after RegisterModule returns nil, with no SavedVariables touched (CORE-R13)", function()
		local fake = newFakePagle()
		fake.addons.Pagle_TackleBoard.metadata["X-Pagle-API"] = "2"

		local loaded = board.load(fake)

		assert.is_nil(loaded.ns.Module)
		assert.are.equal("needsNewerPagle", fake.moduleState("TackleBoard"))
		assert.is_nil(loaded.env.PagleTackleBoardDB)
		assert.is_nil(loaded.ns.db)
		assert.are.same({ "Pagle: Pagle Tackle Board needs a newer Pagle." }, fake.printed)
	end)

	it(
		"stays silent until Start: loading appends nothing, raises no moment and sets no summary line (TKB-R2)",
		function()
			-- A login, a Cast and the frames after them, on a fake with the Tackle Board and on one without.
			local function play(fake)
				fake.login()
				fake.enterWorld()
				fake.nextFrame()
				fake.nextFrame()
				fake.playCast("caught", { { itemID = 6358, quantity = 1 } })
				fake.nextFrame()
				local kinds = {}
				for record in fake.Pagle.IterateCatches(0) do
					kinds[#kinds + 1] = record.kind
				end
				return kinds
			end
			local plain = newFakePagle()
			local expected = play(plain)
			local loaded, fake = board.load()

			assert.are.same(expected, play(fake)) -- the Cast the spec played, and no record of the board's
			assert.are.same({ "cast" }, expected)
			assert.is_not_nil(loaded.ns.Module)
			assert.are.same({}, fake.announcements)
			assert.are.same({}, fake.summarized)
			assert.are.same({}, fake.writeUps)
			-- SHOP-R2: done reports 0 Coins, which changes no balance and shows nowhere
			assert.are.same({ { module = "TackleBoard", total = 0 } }, fake.coinReports)
			assert.are.same({}, fake.global.summary.lines)
		end
	)
end)

describe("Pagle_TackleBoard without Pagle", function()
	it("depends on Pagle, so the client won't load it with Core missing or disabled (CORE-R86, CORE-R3)", function()
		local fields = assert(loadAddon("Pagle_TackleBoard", FOREVER_GLOBALS).client.addons.Pagle_TackleBoard.metadata)

		assert.are.equal("Pagle", fields.Dependencies)
	end)

	it("off Forever, with no Pagle global, registers nothing and raises no error (CORE-R4, CORE-R11)", function()
		local loaded
		assert.has_no_error(function()
			loaded = loadAddon("Pagle_TackleBoard", { WOW_PROJECT_ID = PROJECT_IDS.MAINLINE, WOW_PROJECT_CAMELOT = 18 })
		end)

		assert.is_nil(loaded.env.Pagle)
		assert.are.same({}, loaded.ns)
		assert.is_nil(loaded.env.LibStub("AceAddon-3.0"):GetAddon("Pagle_TackleBoard", true))
		assert.is_nil(loaded.env.PagleTackleBoardDB)
	end)

	-- A broken install: no Pagle, and nothing else either. Each file must stop at its first line, so it reads no
	-- global but Pagle and writes none.
	for _, file in ipairs(addonFiles("Pagle_TackleBoard")) do
		it(file .. " starts with the Core guard and does nothing without Pagle (CORE-R11)", function()
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
			local chunk = assert(loadfile("addons/Pagle_TackleBoard/" .. file))
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

			chunk("Pagle_TackleBoard", ns)

			assert.are.same({}, touched)
			assert.are.same({}, ns)
		end)
	end
end)
