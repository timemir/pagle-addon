-- The cards (announcements.md › The display queue, › Session summary, › Write-up): logic/Cards.lua over a
-- PagleDB.global table, the projection machinery's seams, a frame scheduler, the lanes' empty state and Cozy mode.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

local LEDGER = { def = { name = "Ledger", title = "Ledger", order = 10 } }
local HUNTS = { def = { name = "Hunts", title = "Hunts", order = 20 } }

-- Cards over `world`: `world.global` is PagleDB.global; `world.updating` whether a projection is updating, and
-- `world.idle()` its end, running the WhenIdle hooks; `world.frame()` runs the next frame; `world.mode` the apply in
-- progress; `world.lanesEmpty`, `world.held` and `world.cozy` the lanes' state, their combat hold and Cozy mode.
-- `world.shown` is every card shown and `world.hidden` every card the hold took off screen.
local function newWorld()
	local world = {
		global = { cards = {}, writeUp = {} },
		updating = true,
		hooks = {},
		frames = {},
		lanesEmpty = true,
		held = false,
		cozy = false,
		shown = {},
		hidden = {},
	}
	function world.idle()
		world.updating = false
		while #world.hooks > 0 do
			table.remove(world.hooks, 1)()
		end
	end
	function world.frame()
		local steps = world.frames
		world.frames = {}
		for _, step in ipairs(steps) do
			step()
		end
	end
	world.cards = ns.NewCards({
		global = function()
			return world.global
		end,
		mode = function()
			return world.mode
		end,
		whenIdle = function(fn)
			if world.updating then
				world.hooks[#world.hooks + 1] = fn
			else
				fn()
			end
		end,
		nextFrame = function(step)
			world.frames[#world.frames + 1] = step
		end,
		lanesEmpty = function()
			return world.lanesEmpty
		end,
		held = function()
			return world.held
		end,
		cozy = function()
			return world.cozy
		end,
		show = function(card)
			world.shown[#world.shown + 1] = card
		end,
		hide = function(card)
			world.hidden[#world.hidden + 1] = card
		end,
	})
	world.cards:Start()
	-- A Module's M:RaiseWriteUp, on Core's registry.
	world.registry = ns.NewModuleRegistry(1)
	world.raiseWriteUp = ns.RaiseWriteUpMethod(world.registry, world.cards)
	return world
end

-- Registers `module` in `world`'s registry and returns its handle.
local function register(world, module)
	return (world.registry:Register(module.def, function()
		return "1"
	end))
end

-- A stored summary card titled `title`.
local function card(title)
	return {
		title = title,
		numbers = { casts = 1, catches = 1, gotAway = 0, seconds = 60 },
		coins = 0,
		lines = {},
		moments = {},
	}
end

-- The titles of the cards shown so far.
local function titles(world)
	local list = {}
	for i, shown in ipairs(world.shown) do
		list[i] = shown.title
	end
	return list
end

-- Lets login finish: the projections go idle and two frames pass.
local function settle(world)
	world.idle()
	world.frame()
	world.frame()
end

describe("when cards show", function()
	it(
		"shows nothing until no projection is updating and the held Announcements have had their frame, then the"
			.. " Write-up before the stored cards (ANN-R21, ANN-R61)",
		function()
			local world = newWorld()
			world.global.cards = { card("Your last session") }
			world.global.writeUp =
				{ { module = "Ledger", order = 10, title = "Ledger", heading = "Written up", lines = {} } }
			world.cards:Next()
			assert.are.same({}, world.shown)

			world.idle()
			world.frame()
			assert.are.same({}, world.shown)
			world.frame()

			assert.are.same({ "Write-up" }, titles(world))
			assert.are.equal("Written up", world.shown[1].writeUp[1].heading)
		end
	)

	it("shows a card only while the toast and big lanes are empty, then when they empty (ANN-R21)", function()
		local world = newWorld()
		world.global.cards = { card("Fishing session") }
		world.lanesEmpty = false
		settle(world)
		assert.are.same({}, world.shown)

		world.lanesEmpty = true
		world.cards:Next()

		assert.are.same({ "Fishing session" }, titles(world))
	end)

	it("shows cards one at a time, oldest first, each removed from global.cards when closed (ANN-R54)", function()
		local world = newWorld()
		world.global.cards = { card("First"), card("Second") }
		settle(world)
		world.cards:Next()
		assert.are.same({ "First" }, titles(world))

		world.cards:Close(world.shown[1])
		assert.are.same({ "First", "Second" }, titles(world))
		assert.are.same({ "Second" }, { world.global.cards[1].title })
		world.cards:Close(world.shown[2])

		assert.are.same({}, world.global.cards)
		assert.are.equal(2, #world.shown)
	end)

	it("shows a card made while one is showing after that one is closed (ANN-R54)", function()
		local world = newWorld()
		world.global.cards = { card("First") }
		settle(world)
		world.global.cards[2] = card("Second")
		world.cards:Next()
		assert.are.same({ "First" }, titles(world))

		world.cards:Close(world.shown[1])

		assert.are.same({ "First", "Second" }, titles(world))
	end)

	it("keeps the Write-up's sections in global.writeUp until its card is closed (ANN-R61)", function()
		local world = newWorld()
		local section = { module = "Ledger", order = 10, title = "Ledger", heading = "Written up", lines = {} }
		world.global.writeUp = { section }
		settle(world)
		assert.are.same({ section }, world.global.writeUp)

		world.cards:Close(world.shown[1])

		assert.are.same({}, world.global.writeUp)
	end)

	it("in Cozy mode shows the summary cards but not the Write-up, whose sections wait (ANN-R55, ANN-R62)", function()
		local world = newWorld()
		world.cozy = true
		local section = { module = "Ledger", order = 10, title = "Ledger", heading = "Written up", lines = {} }
		world.global.writeUp = { section }
		world.global.cards = { card("Fishing session") }
		settle(world)

		world.cards:Close(world.shown[1])

		assert.are.same({ "Fishing session" }, titles(world))
		assert.are.same({ section }, world.global.writeUp)
	end)

	it(
		"hands a Cozy-mode Session card the waiting sections by Module order, keeping those on screen until their"
			.. " card is closed (ANN-R61, ANN-R62)",
		function()
			local world = newWorld()
			local shown = { module = "Ledger", order = 10, title = "Ledger", heading = "On screen", lines = {} }
			world.global.writeUp = { shown }
			settle(world)
			local hunts = { module = "Hunts", order = 20, title = "Hunts", heading = "While off", lines = {} }
			local ledger = { module = "Ledger", order = 10, title = "Ledger", heading = "Later", lines = {} }
			table.insert(world.global.writeUp, hunts)
			table.insert(world.global.writeUp, ledger)

			assert.are.same({ ledger, hunts }, world.cards:TakeWriteUp())
			assert.are.same({ shown }, world.global.writeUp)
			world.cards:Close(world.shown[1])
			assert.are.same({}, world.global.writeUp)
		end
	)

	it("holds cards through combat: none shows while the lanes are held (ANN-R35, ANN-R55)", function()
		local world = newWorld()
		world.global.cards = { card("Fishing session") }
		world.held = true
		settle(world)
		assert.are.same({}, world.shown)

		world.held = false
		world.cards:Next()

		assert.are.same({ "Fishing session" }, titles(world))
	end)

	it(
		"takes the card on screen off it when combat starts, keeping it to show again after (ANN-R35, ANN-R36)",
		function()
			local world = newWorld()
			world.global.cards = { card("First"), card("Second") }
			settle(world)

			world.held = true
			world.cards:Hold()
			assert.are.same({ "First" }, titles({ shown = world.hidden }))
			world.cards:Close(world.shown[1])
			assert.are.equal(2, #world.global.cards)
			world.held = false
			world.cards:Next()

			assert.are.same({ "First", "First" }, titles(world))
		end
	)

	it("ignores closing a card that isn't the one showing", function()
		local world = newWorld()
		world.global.cards = { card("First") }
		settle(world)

		world.cards:Close(card("Other"))

		assert.are.same({ "First" }, { world.global.cards[1].title })
		assert.are.equal(1, #world.shown)
	end)
end)

describe("the Write-up", function()
	it(
		"puts two Modules' sections raised in one login on one Write-up card, one each, by Module order (ANN-R61)",
		function()
			local world = newWorld()
			local hunts, ledger = register(world, HUNTS), register(world, LEDGER)
			world.mode = "done"
			world.raiseWriteUp(hunts, { heading = "While Hunts was off", lines = { "2 Hunts completed" } })
			world.raiseWriteUp(
				ledger,
				{ heading = "Your Ledger was written up from 2,340 Casts", lines = { "3 Species" } }
			)
			world.mode = nil

			settle(world)

			assert.are.equal(1, #world.shown)
			assert.are.same({
				{
					module = "Ledger",
					order = 10,
					title = "Ledger",
					heading = "Your Ledger was written up from 2,340 Casts",
					lines = { "3 Species" },
				},
				{
					module = "Hunts",
					order = 20,
					title = "Hunts",
					heading = "While Hunts was off",
					lines = { "2 Hunts completed" },
				},
			}, world.shown[1].writeUp)
		end
	)

	it("raises an error at the Module's call outside a projection's done, keeping nothing (ANN-R60)", function()
		local world = newWorld()
		local ledger = register(world, LEDGER)

		for _, mode in ipairs({ false, "live", "replay", "rebuild" }) do
			world.mode = mode or nil
			local ok, err = pcall(world.raiseWriteUp, ledger, { heading = "Written up", lines = {} })
			assert.is_false(ok)
			assert.matches("RaiseWriteUp", err)
		end

		assert.are.same({}, world.global.writeUp)
	end)

	it("raises an error for a bad section or a non-handle, keeping nothing (announcements.md › Contracts)", function()
		local world = newWorld()
		local ledger = register(world, LEDGER)
		world.mode = "done"

		for _, section in ipairs({
			"Written up",
			{ lines = {} },
			{ heading = "", lines = {} },
			{ heading = "Written up" },
			{ heading = "Written up", lines = { 12 } },
		}) do
			local ok, err = pcall(world.raiseWriteUp, ledger, section)
			assert.is_false(ok)
			assert.matches("RaiseWriteUp", err)
		end
		local ok, err = pcall(world.raiseWriteUp, {}, { heading = "Written up", lines = {} })
		assert.is_false(ok)
		assert.matches("RaiseWriteUp is a Module handle method", err)

		assert.are.same({}, world.global.writeUp)
	end)

	it("copies a section when raised, adding nothing to its heading or lines (ANN-R60)", function()
		local world = newWorld()
		local ledger = register(world, LEDGER)
		local lines = { "Angler Level 12", "Pagle Coins +120" }
		world.mode = "done"
		world.raiseWriteUp(ledger, { heading = "Your Ledger was written up from 2,340 Casts", lines = lines })
		lines[1] = "changed"

		assert.are.same({ "Angler Level 12", "Pagle Coins +120" }, world.global.writeUp[1].lines)
		assert.are.equal("Your Ledger was written up from 2,340 Casts", world.global.writeUp[1].heading)
	end)
end)

describe("a card's rows", function()
	local function format(number)
		return "<" .. number .. ">"
	end

	it(
		"list the Coins line above 0, the Modules' lines, each Module's moments under its title, then the Write-up"
			.. " sections (ANN-R53)",
		function()
			local rows = ns.CardRows({
				title = "Fishing session",
				coins = 1200,
				lines = { { module = "Ledger", title = "Ledger", lines = { "Angler Level 12" } } },
				moments = {
					{
						module = "Ledger",
						title = "Ledger",
						order = 10,
						moments = {
							{ title = "New Species", text = "Nightfin Snapper", icon = 13759 },
							{ title = "Size record" },
						},
					},
				},
				writeUp = { { heading = "While Hunts was off", lines = { "2 Hunts" } } },
			}, format)

			assert.are.same({
				{ kind = "line", text = "Pagle Coins +<1200>" },
				{ kind = "line", text = "Angler Level 12" },
				{ kind = "heading", text = "Ledger" },
				{ kind = "moment", text = "New Species", detail = "Nightfin Snapper", icon = 13759 },
				{ kind = "moment", text = "Size record" },
				{ kind = "heading", text = "While Hunts was off" },
				{ kind = "line", text = "2 Hunts" },
			}, rows)
		end
	)

	it("leave out the Coins line at 0 (ANN-R53)", function()
		assert.are.same({}, ns.CardRows({ title = "Fishing session", coins = 0, lines = {}, moments = {} }, format))
	end)

	it("show a since-disabled Module's stored moments under their stored title (ANN-R55, ANN-R90)", function()
		local rows = ns.CardRows({
			coins = 0,
			lines = {},
			moments = { { module = "Hunts", title = "Hunts", order = 20, moments = { { title = "Hunt completed" } } } },
		}, format)

		assert.are.same({ { kind = "heading", text = "Hunts" }, { kind = "moment", text = "Hunt completed" } }, rows)
	end)

	it("show an expired moment's pastText, or its title if it has none (ANN-R45)", function()
		local rows = ns.CardRows({
			coins = 0,
			lines = {},
			moments = {
				{
					module = "Hunts",
					title = "Hunts",
					order = 20,
					moments = {
						{
							title = "Nightfin window open",
							text = "21:00–06:00",
							pastText = "Nightfin window opened 21:00–06:00",
							expired = true,
						},
						{ title = "Sagefish window open", text = "Until 12:00", expired = true },
						{ title = "Hunt completed", pastText = "Unused" },
					},
				},
			},
		}, format)

		assert.are.same({
			{ kind = "heading", text = "Hunts" },
			{ kind = "moment", text = "Nightfin window opened 21:00–06:00" },
			{ kind = "moment", text = "Sagefish window open", detail = "Until 12:00" },
			{ kind = "moment", text = "Hunt completed" },
		}, rows)
	end)
end)

describe("time fished", function()
	it("reads in minutes, rounded, at least 1, and in hours and minutes from an hour (ANN-R53)", function()
		assert.are.same({ "1 min", "1 min", "40 min", "1 h 00 min", "2 h 05 min" }, {
			ns.CardDuration(0),
			ns.CardDuration(89),
			ns.CardDuration(2400),
			ns.CardDuration(3600),
			ns.CardDuration(7500),
		})
	end)
end)
