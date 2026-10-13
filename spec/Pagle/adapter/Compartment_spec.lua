-- The Addon Compartment entry "Pagle" and its menu (CORE-R33, CORE-R50, CORE-R52; settings.md SET-R75).

-- Loads Core with QoL and Hunts installed on the fake client, so either can register.
local function loadCore(globals)
	local loaded = loadAddon("Pagle", globals or FOREVER_GLOBALS)
	for _, name in ipairs({ "QoL", "Hunts" }) do
		loaded.client.addons["Pagle_" .. name] = { metadata = { ["X-Pagle-API"] = "1" } }
	end
	return loaded
end

-- Clicks Pagle in the Addon Compartment, as Blizzard_Minimap's AddonCompartment does: it calls the global the TOC's
-- AddonCompartmentFunc names, with the addon and mouse button, then closes its own menu. Returns the menu Core
-- opens on the next frame, or nil.
local function clickCompartment(loaded)
	local opened = #loaded.client.menus
	local func = assert(loaded.client.addons.Pagle.metadata).AddonCompartmentFunc
	loaded.env[func]("Pagle", "LeftButton")
	loaded.client.runTimers()
	return loaded.client.menus[opened + 1]
end

-- The names of the categories Settings.OpenToCategory opened, in order.
local function openedNames(loaded)
	local names = {}
	for i, category in ipairs(loaded.client.settings.opened) do
		names[i] = category and category.name
	end
	return names
end

describe("The compartment entry", function()
	it("is Pagle's, from the TOC's AddonCompartmentFunc and title (CORE-R50)", function()
		local loaded = loadCore()
		local metadata = assert(loaded.client.addons.Pagle.metadata)

		assert.are.equal("Pagle", metadata.Title)
		assert.is_function(loaded.env[metadata.AddonCompartmentFunc])
	end)

	it("opens its menu on the next frame, once the compartment's own menu has closed (CORE-R50)", function()
		local loaded = loadCore()
		loaded.client.fire("PLAYER_LOGIN")
		local func = assert(loaded.client.addons.Pagle.metadata).AddonCompartmentFunc

		loaded.env[func]("Pagle", "LeftButton")
		assert.are.equal(0, #loaded.client.menus)
		loaded.client.runTimers()

		assert.are.equal(1, #loaded.client.menus)
	end)

	it("holds only Settings with no Module registered, and Settings opens the root (CORE-R50, SET-R75)", function()
		local loaded = loadCore()
		loaded.client.fire("PLAYER_LOGIN")

		local menu = clickCompartment(loaded)
		assert.are.same({ "Settings" }, menu.texts())
		menu.click("Settings")

		assert.are.same({ "Pagle" }, openedNames(loaded))
	end)
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

	it("lists each Module's views then its menu entries, by def.order, then Settings (CORE-R50)", function()
		local loaded = loadCore()
		registerBoth(loaded)

		local menu = clickCompartment(loaded)

		assert.are.same({ "Hunts", "Hunt map", "Pin a Hunt", "Input: Both 1", "Settings" }, menu.texts())
	end)

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

		assert.are.same({ "Settings" }, clickCompartment(loaded).texts())
		assert.are.equal(1, #reported)
		assert.matches("no input yet", reported[1], 1, true)
	end)
end)

-- A combat flip on the fake client: PLAYER_REGEN_DISABLED or _ENABLED, with InCombatLockdown agreeing.
local function setCombat(loaded, inCombat)
	loaded.env.InCombatLockdown = function()
		return inCombat
	end
	loaded.client.fire(inCombat and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
end

describe("The compartment menu while restricted", function()
	it("still opens, and Settings prints CORE-R33's line instead of opening (CORE-R33, SET-R75)", function()
		local loaded = loadCore()
		loaded.client.fire("PLAYER_LOGIN")
		setCombat(loaded, true)

		local menu = clickCompartment(loaded)
		assert.are.same({ "Settings" }, menu.texts())
		menu.click("Settings")

		assert.are.same({}, openedNames(loaded))
		assert.are.same({ "Pagle: settings open after combat." }, loaded.printed)
	end)
end)

describe("The compartment entry off Forever", function()
	it("does nothing when clicked, as Core never started (CORE-R4)", function()
		local loaded = loadCore({ WOW_PROJECT_ID = PROJECT_IDS.MAINLINE, WOW_PROJECT_CAMELOT = PROJECT_IDS.CAMELOT })

		assert.is_nil(clickCompartment(loaded))
		assert.are.same({ loaded.ns.L.NOT_FOREVER }, loaded.printed)
	end)
end)
