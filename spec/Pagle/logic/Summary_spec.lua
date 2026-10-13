-- The Session summary's data (announcements.md › Session summary, › Data): logic/Summary.lua over a PagleDB.global
-- table, whether a Session is open, the registered Modules and Cozy mode. logic/Cards.lua shows the cards.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

local LEDGER = { def = { name = "Ledger", title = "Ledger", order = 10 } }
local HUNTS = { def = { name = "Hunts", title = "Hunts", order = 20 } }

-- A Session as SessionEnded hands it out (catch-log.md › Events): 12 Casts, 9 Catches, 2 got away, 40 min.
local SESSION = {
	id = "Player-4618-0A1B2C3D-1791731000-0",
	startTime = 1791731000,
	endTime = 1791733400,
	firstSeq = 3,
	lastSeq = 20,
	casts = 12,
	catches = 9,
	gotAway = 2,
	characters = { 1 },
	zones = { 148 },
}

-- A raised moment as logic/Moments.lua hands it to the summary (PagleRaisedMoment).
local function raised(module, fields)
	local moment = {
		module = module.def.name,
		moduleTitle = module.def.title,
		moduleOrder = module.def.order,
		raised = 1,
		order = 100,
		sound = true,
	}
	for key, value in pairs(fields) do
		moment[key] = value
	end
	return moment
end

-- A summary over `world`: `world.global` is PagleDB.global, `world.open` whether a Session is open,
-- `world.modules` the registered Modules, by order, and `world.cozy` the player's Cozy mode.
local function newWorld()
	local world = { global = {}, open = true, modules = { LEDGER, HUNTS }, cozy = false }
	world.summary = ns.NewSummary({
		global = function()
			return world.global
		end,
		isOpen = function()
			return world.open
		end,
		modules = function()
			return world.modules
		end,
		cozy = function()
			return world.cozy
		end,
	})
	return world
end

describe("the Session summary", function()
	it(
		"ends a Session with two Modules' moments as one card: Core's numbers, the Coins sum and the moments by Module"
			.. " order, highest rung first (ANN-R53)",
		function()
			local world = newWorld()
			world.summary:Add(raised(HUNTS, { rung = "toast.high", kind = "huntCompleted", title = "Hunt", coins = 5 }))
			world.summary:Add(raised(LEDGER, { rung = "toast", kind = "newSpecies", title = "New Species", coins = 3 }))
			world.summary:Add(raised(LEDGER, { rung = "banner", kind = "levelUp", title = "Level 12" }))

			local card = world.summary:Ended(SESSION)

			assert.are.same({ casts = 12, catches = 9, gotAway = 2, seconds = 2400 }, card.numbers)
			assert.are.equal(8, card.coins)
			local groups = {}
			for i, group in ipairs(card.moments) do
				local titles = {}
				for j, moment in ipairs(group.moments) do
					titles[j] = moment.title
				end
				groups[i] = { group.module, group.title, titles }
			end
			assert.are.same({
				{ "Ledger", "Ledger", { "Level 12", "New Species" } },
				{ "Hunts", "Hunts", { "Hunt" } },
			}, groups)
			assert.are.same({ card }, world.global.cards)
		end
	)

	it("stores only announcements.md › Data's fields of a moment, its Module's title and order included", function()
		local world = newWorld()
		world.summary:Add(raised(LEDGER, {
			rung = "toast.low",
			kind = "sizeRecord",
			title = "Size record",
			text = "Oily Blackmouth",
			icon = 6358,
			stamp = "Record!",
			coins = 2,
			cast = "Player-4618-0A1B2C3D-1791731000-0",
			ruler = { old = 300, new = 320, unit = "length", label = "Pagle size" },
			expiresAt = 1791740000,
			pastText = "was a record",
			summaryOnly = true,
		}))

		assert.are.same({
			{
				module = "Ledger",
				moduleTitle = "Ledger",
				moduleOrder = 10,
				kind = "sizeRecord",
				rung = "toast.low",
				title = "Size record",
				text = "Oily Blackmouth",
				icon = 6358,
				stamp = "Record!",
				coins = 2,
				expiresAt = 1791740000,
				pastText = "was a record",
			},
		}, world.global.summary.moments)
	end)

	it(
		"keeps the open Session's moments in global.summary until it ends, then clears them (ANN-R50, ANN-R53)",
		function()
			local world = newWorld()
			world.summary:Add(raised(LEDGER, { rung = "nod", kind = "uncharted", title = "Uncharted" }))
			assert.are.equal("Uncharted", world.global.summary.moments[1].title)

			world.summary:Ended(SESSION)

			assert.are.same({}, world.global.summary.moments)
		end
	)

	it("ends a Session with no moment quietly, with no card, even with summary lines set (ANN-R51, ANN-R53)", function()
		local world = newWorld()
		world.summary:SetLine(LEDGER, "level", "Angler Level 12")

		assert.is_nil(world.summary:Ended(SESSION))

		assert.are.same({}, world.global.cards)
		assert.are.same({}, world.global.summary.moments)
	end)

	it("sums no Coins line for moments without coins: coins is 0 (ANN-R53)", function()
		local world = newWorld()
		world.summary:Add(raised(LEDGER, { rung = "nod", kind = "uncharted", title = "Uncharted" }))

		assert.are.equal(0, world.summary:Ended(SESSION).coins)
	end)

	it(
		"keeps a moment raised with no Session open in global.pending, and moves it into the summary at"
			.. " SessionStarted, so it lands on that Session's card (ANN-R52)",
		function()
			local world = newWorld()
			world.open = false
			world.summary:Add(raised(LEDGER, { rung = "nod", kind = "loginNod", title = "Welcome back" }))

			assert.are.same({}, world.global.summary.moments)
			assert.are.equal("Welcome back", world.global.pending[1].title)

			world.open = true
			world.summary:Started()
			world.summary:Add(raised(LEDGER, { rung = "toast", kind = "newSpecies", title = "New Species" }))

			assert.are.same({}, world.global.pending)
			local titles = {}
			for i, moment in ipairs(world.summary:Ended(SESSION).moments[1].moments) do
				titles[i] = moment.title
			end
			assert.are.same({ "New Species", "Welcome back" }, titles)
		end
	)

	it("leaves pending moments out of a card for a Session that ends before the next one starts (ANN-R52)", function()
		local world = newWorld()
		world.summary:Add(raised(LEDGER, { rung = "toast", kind = "newSpecies", title = "New Species" }))
		world.open = false
		world.summary:Add(raised(LEDGER, { rung = "nod", kind = "loginNod", title = "Welcome back" }))

		local card = world.summary:Ended(SESSION)

		assert.are.equal(1, #card.moments[1].moments)
		assert.are.equal("Welcome back", world.global.pending[1].title)
	end)

	it("marks a card from a whileAway end whileAway, and only that one (ANN-R54)", function()
		local world = newWorld()
		world.summary:Add(raised(LEDGER, { rung = "toast", kind = "newSpecies", title = "New Species" }))
		world.summary:Add(raised(LEDGER, { rung = "toast", kind = "newSpecies", title = "New Species" }))
		local away = {}
		for key, value in pairs(SESSION) do
			away[key] = value
		end
		away.whileAway = true

		assert.is_true(world.summary:Ended(away).whileAway)
		world.summary:Add(raised(LEDGER, { rung = "toast", kind = "newSpecies", title = "New Species" }))
		assert.is_nil(world.summary:Ended(SESSION).whileAway)
	end)

	describe("summary lines", function()
		-- The card's lines as { module, { texts } } pairs.
		local function linesOf(card)
			local lines = {}
			for i, group in ipairs(card.lines) do
				lines[i] = { group.module, group.lines }
			end
			return lines
		end

		local function endWithAMoment(world)
			world.summary:Add(raised(LEDGER, { rung = "nod", kind = "uncharted", title = "Uncharted" }))
			return world.summary:Ended(SESSION)
		end

		it(
			"copies each registered Module's lines onto the card by Module order, its keys in order (ANN-R51, ANN-R53)",
			function()
				local world = newWorld()
				world.summary:SetLine(HUNTS, "pinned", "Hunts: 2 pinned")
				world.summary:SetLine(LEDGER, "zone", "Ledger: Elwynn 8/9")
				world.summary:SetLine(LEDGER, "level", "Angler Level 12")

				assert.are.same({
					{ "Ledger", { "Angler Level 12", "Ledger: Elwynn 8/9" } },
					{ "Hunts", { "Hunts: 2 pinned" } },
				}, linesOf(endWithAMoment(world)))
			end
		)

		it("keeps lines across Sessions until the Module changes them, and nil removes one (ANN-R51)", function()
			local world = newWorld()
			world.summary:SetLine(LEDGER, "level", "Angler Level 12")
			world.summary:SetLine(LEDGER, "zone", "Ledger: Elwynn 8/9")
			local first = endWithAMoment(world)

			world.summary:SetLine(LEDGER, "level", "Angler Level 13")
			world.summary:SetLine(LEDGER, "zone", nil)
			local second = endWithAMoment(world)

			assert.are.same({ { "Ledger", { "Angler Level 12", "Ledger: Elwynn 8/9" } } }, linesOf(first))
			assert.are.same({ { "Ledger", { "Angler Level 13" } } }, linesOf(second))
		end)

		it(
			"leaves an unregistered Module's lines off a card, keeping them stored for the next card after it"
				.. " registers again (ANN-R51, ANN-R90)",
			function()
				local world = newWorld()
				world.summary:SetLine(HUNTS, "pinned", "Hunts: 2 pinned")
				world.summary:SetLine(LEDGER, "level", "Angler Level 12")

				world.modules = { LEDGER }
				local disabled = endWithAMoment(world)
				world.modules = { LEDGER, HUNTS }
				local again = endWithAMoment(world)

				assert.are.same({ { "Ledger", { "Angler Level 12" } } }, linesOf(disabled))
				assert.are.same(
					{ { "Ledger", { "Angler Level 12" } }, { "Hunts", { "Hunts: 2 pinned" } } },
					linesOf(again)
				)
			end
		)

		it("keeps a card's copied lines when the Module changes its line later (ANN-R51, ANN-R55)", function()
			local world = newWorld()
			world.summary:SetLine(LEDGER, "level", "Angler Level 12")
			local card = endWithAMoment(world)

			world.summary:SetLine(LEDGER, "level", "Angler Level 13")

			assert.are.same({ { "Ledger", { "Angler Level 12" } } }, linesOf(card))
		end)

		it("stores lines as announcements.md › Data's global.summary.lines (ANN-R50)", function()
			local world = newWorld()
			world.summary:SetLine(LEDGER, "level", "Angler Level 12")

			assert.are.same(
				{ Ledger = { order = 10, title = "Ledger", lines = { level = "Angler Level 12" } } },
				world.global.summary.lines
			)
			world.summary:SetLine(LEDGER, "level", nil)
			assert.are.same({}, world.global.summary.lines)
		end)
	end)

	it("keeps what PagleDB saved: a crash's moments end on the next login's whileAway card (ANN-R94)", function()
		local world = newWorld()
		world.summary:Add(raised(LEDGER, { rung = "toast", kind = "newSpecies", title = "New Species" }))
		local saved = world.global

		local again = newWorld()
		again.global = saved
		local away = {}
		for key, value in pairs(SESSION) do
			away[key] = value
		end
		away.whileAway = true
		local card = again.summary:Ended(away)

		assert.are.same({ true, "New Species" }, { card.whileAway, card.moments[1].moments[1].title })
	end)
	it(
		'titles a card "Your last session" when its Session ended while away, else "Fishing session" (ANN-R54)',
		function()
			local world = newWorld()
			world.summary:Add(raised(LEDGER, { rung = "toast", kind = "newSpecies", title = "New Species" }))
			local live = world.summary:Ended(SESSION)
			local away = {}
			for key, value in pairs(SESSION) do
				away[key] = value
			end
			away.whileAway = true
			world.summary:Add(raised(LEDGER, { rung = "toast", kind = "newSpecies", title = "New Species" }))

			local last = world.summary:Ended(away)

			assert.are.same({ "Fishing session", "Your last session" }, { live.title, last.title })
		end
	)

	it("keeps at most 3 cards: a 4th drops the oldest (ANN-R54)", function()
		local world = newWorld()
		for i = 1, 4 do
			world.summary:Add(raised(LEDGER, { rung = "toast", kind = "newSpecies", title = "Species " .. i }))
			world.summary:Ended(SESSION)
		end

		local kept = {}
		for i, card in ipairs(world.global.cards) do
			kept[i] = card.moments[1].moments[1].title
		end
		assert.are.same({ "Species 2", "Species 3", "Species 4" }, kept)
	end)

	it(
		"in Cozy mode, puts the waiting Write-up sections on the next card, by Module order, and makes that card"
			.. " although its Session raised no moment (ANN-R53, ANN-R62)",
		function()
			local world = newWorld()
			world.cozy = true
			world.global.writeUp = {
				{
					module = "Hunts",
					order = 20,
					title = "Hunts",
					heading = "While Hunts was off",
					lines = { "2 Hunts" },
				},
				{ module = "Ledger", order = 10, title = "Ledger", heading = "Your Ledger was written up", lines = {} },
			}

			local card = world.summary:Ended(SESSION)

			assert.are.same({ "Your Ledger was written up", "While Hunts was off" }, {
				card.writeUp[1].heading,
				card.writeUp[2].heading,
			})
			assert.are.same({}, card.moments)
			assert.are.same({ card }, world.global.cards)
			assert.are.same({}, world.global.writeUp)
		end
	)

	it(
		"out of Cozy mode, leaves the Write-up waiting: a quiet Session still makes no card (ANN-R53, ANN-R61)",
		function()
			local world = newWorld()
			local section = { module = "Ledger", order = 10, title = "Ledger", heading = "Written up", lines = {} }
			world.global.writeUp = { section }

			assert.is_nil(world.summary:Ended(SESSION))
			world.summary:Add(raised(LEDGER, { rung = "toast", kind = "newSpecies", title = "New Species" }))
			local card = world.summary:Ended(SESSION)

			assert.is_nil(card.writeUp)
			assert.are.same({ section }, world.global.writeUp)
		end
	)
end)
