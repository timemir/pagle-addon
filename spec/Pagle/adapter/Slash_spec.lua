-- /pagle: Core's subcommands and each registered Module's (CORE-R60–R62; settings.md SET-R75).

-- Loads Core with QoL and Hunts installed on the fake client, so either can register.
local function loadCore()
	local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
	for _, name in ipairs({ "QoL", "Hunts" }) do
		loaded.client.addons["Pagle_" .. name] = { metadata = { ["X-Pagle-API"] = "1" } }
	end
	return loaded
end

-- Types `/pagle <msg>` in chat, as the client calls the handler: with the text after the command.
local function pagle(loaded, msg)
	loaded.env.SlashCmdList.PAGLE(msg)
end

describe("/pagle", function()
	it("is the command Core registers (CORE-R60)", function()
		local loaded = loadCore()

		assert.are.equal("/pagle", loaded.env.SLASH_PAGLE1)
		assert.is_function(loaded.env.SlashCmdList.PAGLE)
	end)

	it("opens the Settings root with no argument, and so does /pagle settings (CORE-R60, CORE-R61, SET-R75)", function()
		local loaded = loadCore()
		loaded.client.fire("PLAYER_LOGIN")

		pagle(loaded, "")
		pagle(loaded, "settings")
		pagle(loaded, "  SETTINGS  ")

		assert.are.same({ "Pagle", "Pagle", "Pagle" }, openedNames(loaded))
		assert.are.same({}, loaded.printed)
	end)

	it("opens the Field report box with /pagle report (CORE-R61, REP-R40)", function()
		local loaded = loadCore()
		enterWorld(loaded, 2)

		pagle(loaded, " Report ")

		assert.is_true(assert(loaded.ns.fieldReportBox):IsShown())
		assert.are.same({}, openedNames(loaded))
		assert.are.same({}, loaded.printed)
	end)

	it("prints REP-R44's line for /pagle report while restricted, opening nothing (REP-R44, CORE-R33)", function()
		local loaded = loadCore()
		enterWorld(loaded, 2)
		setCombat(loaded, true)

		pagle(loaded, "report")

		assert.is_nil(loaded.ns.fieldReportBox)
		assert.are.same({ "Pagle: the Field report opens after combat." }, loaded.printed)
	end)
end)

-- Registers QoL (order 50), then Hunts (order 20), each with the slash entries given, and logs in.
local function registerBoth(loaded, qolSlash, huntsSlash)
	local Pagle = loaded.env.Pagle
	Pagle.RegisterModule({ name = "QoL", title = "QoL", order = 50, slash = qolSlash })
	Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20, slash = huntsSlash })
	loaded.client.fire("PLAYER_LOGIN")
end

-- The help list: Core's commands, then each registered Module's by def.order.
local HELP = {
	"Pagle commands:",
	"/pagle settings: open Pagle's settings (also /pagle on its own)",
	"/pagle report: open the Field report, to help chart the waters",
	"/pagle help: list these commands",
	"/pagle hunts: open the Hunts board",
	"/pagle qol: cycle Input",
}

describe("/pagle help", function()
	local function both(loaded)
		registerBoth(
			loaded,
			{ { name = "qol", fn = function() end, help = "cycle Input" } },
			{ { name = "hunts", fn = function() end, help = "open the Hunts board" } }
		)
	end

	it("lists Core's commands, then each registered Module's with its help, by def.order (CORE-R60)", function()
		local loaded = loadCore()
		both(loaded)

		pagle(loaded, "help")

		assert.are.same(HELP, loaded.printed)
		assert.are.same({}, openedNames(loaded))
	end)

	for _, line in ipairs({ "shop", "fly away", "HELP" }) do
		it(("prints the help list for /pagle %s (CORE-R61, CORE-R62, roadmap M1, M3)"):format(line), function()
			local loaded = loadCore()
			both(loaded)

			pagle(loaded, line)

			assert.are.same(HELP, loaded.printed)
			assert.are.same({}, openedNames(loaded))
		end)
	end
end)

describe("A Module's /pagle subcommand", function()
	it("matches case-insensitively and gets the rest of the line, trimmed (CORE-R62)", function()
		local loaded = loadCore()
		local got = {}
		registerBoth(loaded, {
			{
				name = "QoL",
				fn = function(args)
					got[#got + 1] = args
				end,
				help = "cycle Input",
			},
		})

		pagle(loaded, "qol")
		pagle(loaded, "  QOL   input   both  ")
		pagle(loaded, "Qol\tinput")

		assert.are.same({ "", "input   both", "input" }, got)
		assert.are.same({}, loaded.printed)
	end)

	it(
		"skips a name that collides with a reserved one or an earlier Module's, reports each, and adds the rest (CORE-R62)",
		function()
			local loaded = loadCore()
			local reported = {}
			loaded.env.geterrorhandler = function()
				return function(err)
					reported[#reported + 1] = err
				end
			end
			local ran = {}
			local function runs(label)
				return function()
					ran[#ran + 1] = label
				end
			end
			registerBoth(loaded, {
				{ name = "Settings", fn = runs("QoL settings"), help = "x" },
				{ name = "BOARD", fn = runs("QoL board"), help = "x" },
				{ name = "qol", fn = runs("QoL qol"), help = "cycle Input" },
			}, {
				{ name = "board", fn = runs("Hunts board"), help = "open the Hunts board" },
				{ name = "report", fn = runs("Hunts report"), help = "x" },
			})

			pagle(loaded, "board")
			pagle(loaded, "qol")
			pagle(loaded, "settings")

			-- Hunts (order 20) adds its entries before QoL (order 50), so Hunts keeps "board".
			assert.are.same({ "Hunts board", "QoL qol" }, ran)
			assert.are.same({ "Pagle" }, openedNames(loaded))
			assert.are.equal(3, #reported)
			local L = loaded.ns.L
			assert.are.same({
				L.SLASH_SKIPPED_RESERVED:format("Hunts", "report", "report"),
				L.SLASH_SKIPPED_RESERVED:format("QoL", "Settings", "settings"),
				L.SLASH_SKIPPED_TAKEN:format("QoL", "BOARD", "Hunts"),
			}, reported)
		end
	)

	it("skips and reports an entry with no one-word name or no fn, and adds the rest (CORE-R62)", function()
		local loaded = loadCore()
		local reported = {}
		loaded.env.geterrorhandler = function()
			return function(err)
				reported[#reported + 1] = err
			end
		end
		local ran = 0
		registerBoth(loaded, {
			{ name = "two words", fn = function() end, help = "x" },
			{ name = "input", help = "x" },
			{
				name = "qol",
				fn = function()
					ran = ran + 1
				end,
				help = "cycle Input",
			},
		})

		pagle(loaded, "qol")

		assert.are.equal(1, ran)
		assert.are.same({
			loaded.ns.L.SLASH_SKIPPED_NO_NAME:format("QoL", "two words"),
			loaded.ns.L.SLASH_SKIPPED_NO_FN:format("QoL", "input"),
		}, reported)
		assert.are.same({
			"Pagle: QoL's /pagle entry two words has no one-word name; it is skipped",
			"Pagle: QoL's /pagle input has no fn; it is skipped",
		}, reported)
	end)

	it("is gone with its Module: an unregistered Module's name prints the help list (CORE-R17, CORE-R62)", function()
		local loaded = loadCore()
		loaded.client.fire("PLAYER_LOGIN")

		pagle(loaded, "qol")

		assert.are.same({ HELP[1], HELP[2], HELP[3], HELP[4] }, loaded.printed)
	end)
end)

describe("/pagle while restricted", function()
	it("prints CORE-R33's line for /pagle and /pagle settings, and opens nothing (CORE-R33, SET-R75)", function()
		local loaded = loadCore()
		loaded.client.fire("PLAYER_LOGIN")
		setCombat(loaded, true)

		pagle(loaded, "")
		pagle(loaded, "settings")

		assert.are.same({}, openedNames(loaded))
		assert.are.same({ "Pagle: settings open after combat.", "Pagle: settings open after combat." }, loaded.printed)
	end)
end)
