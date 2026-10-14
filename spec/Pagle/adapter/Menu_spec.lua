-- The Addon Compartment entry "Pagle" and its menu (CORE-R33, CORE-R50–R52; settings.md SET-R75).

-- The Curio Shop entry with this balance, as CORE-R50 writes it: two spaces, the balance, a coin icon.
local function curioShop(balance)
	return "Curio Shop  " .. balance .. " |TInterface\\MoneyFrame\\UI-GoldIcon:0|t"
end

-- Loads Core with QoL and Hunts installed on the fake client, so either can register.
local function loadCore(globals)
	local loaded = loadAddon("Pagle", globals or FOREVER_GLOBALS)
	for _, name in ipairs({ "QoL", "Hunts" }) do
		loaded.client.addons["Pagle_" .. name] = { metadata = { ["X-Pagle-API"] = "1" } }
	end
	return loaded
end

-- Clicks Pagle in the Addon Compartment, which then closes its own menu, and returns the menu Core opens on the next
-- frame, or nil.
local function clickCompartment(loaded)
	local opened = #loaded.client.menus
	loaded.client.clickCompartment("Pagle")
	loaded.client.runTimers()
	return loaded.client.menus[opened + 1]
end

describe("The compartment entry", function()
	it("is registered once at login, reading Pagle, with no TOC compartment field (CORE-R50, CORE-R51)", function()
		local loaded = loadCore()
		assert.are.same({}, loaded.client.compartment)

		loaded.client.fire("PLAYER_LOGIN")

		assert.are.equal(1, #loaded.client.compartment)
		assert.are.equal("Pagle", loaded.client.compartment[1].text)
		for field in pairs(assert(loaded.client.addons.Pagle.metadata)) do
			assert.is_nil(field:match("^AddonCompartment"))
		end
	end)

	it("opens its menu on the next frame, once the compartment's own menu has closed (CORE-R50)", function()
		local loaded = loadCore()
		loaded.client.fire("PLAYER_LOGIN")

		loaded.client.clickCompartment("Pagle")
		assert.are.equal(0, #loaded.client.menus)
		loaded.client.runTimers()

		assert.are.equal(1, #loaded.client.menus)
	end)

	it("counts the moments Cozy mode holds for a summary in its label (CORE-R51, ANN-R42)", function()
		local loaded = loadCore()
		local M = loaded.env.Pagle.RegisterModule({ name = "QoL", title = "QoL", order = 50 })
		loaded.client.fire("PLAYER_LOGIN")
		loaded.ns.db.profile.announcements.cozy = true

		M:RaiseMoment({ rung = "nod", kind = "spec", title = "Lure on" })
		M:RaiseMoment({ rung = "toast", kind = "spec", title = "Gear swapped" })

		assert.are.equal("Pagle · 2 waiting", loaded.client.compartment[1].text)
		loaded.client.clickCompartment("Pagle · 2 waiting")
		loaded.client.runTimers()
		assert.are.same({ curioShop(0), "Help chart the waters", "Settings" }, loaded.client.menus[1].texts())
	end)

	it(
		"holds the Curio Shop and Settings with no Module registered; Settings opens the root (CORE-R50, SET-R75)",
		function()
			local loaded = loadCore()
			loaded.client.fire("PLAYER_LOGIN")

			local menu = clickCompartment(loaded)
			assert.are.same({ curioShop(0), "Help chart the waters", "Settings" }, menu.texts())
			menu.click("Settings")

			assert.are.same({ "Pagle" }, openedNames(loaded))
		end
	)
end)

describe("The compartment menu with Modules", function()
	-- Registers QoL (order 50) before Hunts (order 20), each with views and menu entries, and logs in. Returns what
	-- was clicked, in order, and how often QoL's function label was read.
	local function registerBoth(loaded)
		local Pagle = loaded.env.Pagle
		local clicked, reads = {}, { count = 0 }
		local function click(label)
			return function()
				clicked[#clicked + 1] = label
			end
		end
		Pagle.RegisterModule({
			name = "QoL",
			title = "QoL",
			order = 50,
			menu = {
				{
					label = function()
						reads.count = reads.count + 1
						return "Input: Both " .. reads.count
					end,
					onClick = click("input"),
				},
			},
		})
		Pagle.RegisterModule({
			name = "Hunts",
			title = "Hunts",
			order = 20,
			views = {
				{ id = "board", label = "Hunts", open = click("board") },
				{ id = "map", label = "Hunt map", open = click("map") },
			},
			menu = { { label = "Pin a Hunt", onClick = click("pin") } },
		})
		loaded.client.fire("PLAYER_LOGIN")
		return clicked, reads
	end

	it(
		"lists each Module's views then its menu entries, by def.order, then the Curio Shop and Settings (CORE-R50)",
		function()
			local loaded = loadCore()
			registerBoth(loaded)

			local menu = clickCompartment(loaded)

			assert.are.same({
				"Hunts",
				"Hunt map",
				"Pin a Hunt",
				"Input: Both 1",
				curioShop(0),
				"Help chart the waters",
				"Settings",
			}, menu.texts())
		end
	)

	it("calls a function label each time the menu opens (CORE-R52)", function()
		local loaded = loadCore()
		local _, reads = registerBoth(loaded)

		assert.are.equal(0, reads.count)
		clickCompartment(loaded)
		local menu = clickCompartment(loaded)

		assert.are.equal(2, reads.count)
		assert.are.equal("Input: Both 2", menu.texts()[4])
	end)

	it("opens a view or runs a menu entry when clicked (CORE-R50)", function()
		local loaded = loadCore()
		local clicked = registerBoth(loaded)

		clickCompartment(loaded).click("Hunt map")
		clickCompartment(loaded).click("Pin a Hunt")
		clickCompartment(loaded).click("Input: Both 3")

		assert.are.same({ "map", "pin", "input" }, clicked)
		assert.are.same({}, openedNames(loaded))
	end)

	it("leaves out an entry whose function label fails, reporting it, and keeps the rest (CORE-R52)", function()
		local loaded = loadCore()
		local reported = {}
		loaded.env.geterrorhandler = function()
			return function(err)
				reported[#reported + 1] = err
			end
		end
		loaded.env.Pagle.RegisterModule({
			name = "QoL",
			title = "QoL",
			order = 50,
			menu = {
				{
					label = function()
						error("no input yet")
					end,
					onClick = function() end,
				},
			},
		})
		loaded.client.fire("PLAYER_LOGIN")

		assert.are.same({ curioShop(0), "Help chart the waters", "Settings" }, clickCompartment(loaded).texts())
		assert.are.equal(1, #reported)
		assert.matches("no input yet", reported[1], 1, true)
	end)
end)

describe("The compartment menu's Curio Shop entry", function()
	-- Core with the Ledger and the Tackle Board registered and logged in; returns their handles.
	local function withPayers(loaded)
		for _, name in ipairs({ "Ledger", "TackleBoard" }) do
			loaded.client.addons["Pagle_" .. name] = { metadata = { ["X-Pagle-API"] = "1" } }
		end
		local Pagle = loaded.env.Pagle
		local ledger = Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
		local board = Pagle.RegisterModule({ name = "TackleBoard", title = "Tackle Board", order = 40 })
		loaded.client.fire("PLAYER_LOGIN")
		return ledger, board
	end

	it("shows the balance with BreakUpLargeNumbers, read each time the menu opens (CORE-R50, CORE-R52)", function()
		local loaded = loadCore()
		local ledger, board = withPayers(loaded)
		ledger:ReportCoinsEarned(1200)
		board:ReportCoinsEarned(150)
		assert.are.same({ curioShop("1,350"), "Help chart the waters", "Settings" }, clickCompartment(loaded).texts())

		board:ReportCoinsEarned(750)

		assert.are.same({ curioShop("1,950"), "Help chart the waters", "Settings" }, clickCompartment(loaded).texts())
	end)

	it("is enabled and opens the Curio Shop (CORE-R50, SHOP-R40)", function()
		local loaded = loadCore()
		withPayers(loaded)

		local menu = clickCompartment(loaded)
		menu.click(curioShop(0))

		assert.is_true(menu.enabled(curioShop(0)))
		assert.is_true(assert(loaded.ns.shopFrame):IsShown())
		assert.are.same({}, openedNames(loaded))
		assert.are.same({}, loaded.printed)
	end)

	it("reads 0 while the balance is held (CORE-R50, SHOP-R12)", function()
		local loaded = loadCore()
		local ledger = withPayers(loaded)
		ledger:ReportCoinsEarned(400)
		loaded.ns.wallet:SetSpent(900)

		assert.are.same({ curioShop(0), "Help chart the waters", "Settings" }, clickCompartment(loaded).texts())
	end)
end)

describe("The compartment menu while restricted", function()
	it("still opens, and Settings prints CORE-R33's line instead of opening (CORE-R33, SET-R75)", function()
		local loaded = loadCore()
		loaded.client.fire("PLAYER_LOGIN")
		setCombat(loaded, true)

		local menu = clickCompartment(loaded)
		assert.are.same({ curioShop(0), "Help chart the waters", "Settings" }, menu.texts())
		menu.click("Settings")

		assert.are.same({}, openedNames(loaded))
		assert.are.same({ "Pagle: settings open after combat." }, loaded.printed)
	end)
end)

describe("The compartment entry off Forever", function()
	it("isn't registered, as Core never started (CORE-R4)", function()
		local loaded = loadCore({ WOW_PROJECT_ID = PROJECT_IDS.MAINLINE, WOW_PROJECT_CAMELOT = PROJECT_IDS.CAMELOT })

		loaded.client.fire("PLAYER_LOGIN")

		assert.are.same({}, loaded.client.compartment)
		assert.are.same({ loaded.ns.L.NOT_FOREVER }, loaded.printed)
	end)
end)
