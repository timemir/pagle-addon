-- Pagle's menu: the minimap icon, Core's own round button on the minimap's edge, beside the compartment entry, with
-- one tooltip for both, Show the minimap icon on the root, and Pagle's menu button (CORE-R6, CORE-R50–R56;
-- settings.md SET-R10 row 10; onboarding.md ONB-R13, ONB-R52, ONB-R108). The compartment's menu itself:
-- Menu_spec.lua; the icon's angles: spec/Pagle/logic/MinimapIcon_spec.lua.

-- The textures the icon is drawn with: the favicon, and the client's own minimap-button parts, each listed in build
-- 70338's ManifestInterfaceData (CORE-R9).
local ICON = "Interface\\AddOns\\Pagle\\media\\minimap\\Pagle"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local RING = "Interface\\Minimap\\MiniMap-TrackingBorder"
local BACKGROUND = "Interface\\Minimap\\UI-Minimap-Background"
local HIGHLIGHT = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"

-- How far the icon's centre sits from the minimap's: half the fake minimap's 198 units, and 5 more.
local RADIUS = 104

-- The Curio Shop entry with this balance, as CORE-R50 writes it: two spaces, the balance, a coin icon.
local function curioShop(balance)
	return "Curio Shop  " .. balance .. " |TInterface\\MoneyFrame\\UI-GoldIcon:0|t"
end

-- Core on the fake client with QoL and Hunts installed, so either can register, and `saved` as its PagleDB.
local function loadCore(saved)
	local loaded = loadAddon("Pagle", foreverWith({ PagleDB = saved }))
	for _, name in ipairs({ "QoL", "Hunts" }) do
		loaded.client.addons["Pagle_" .. name] = { metadata = { ["X-Pagle-API"] = "1" } }
	end
	return loaded
end

-- Core logged in, with its icon made; returns it and the icon.
local function loggedIn(saved)
	local loaded = loadCore(saved)
	loaded.client.fire("PLAYER_LOGIN")
	return loaded, loaded.env.PagleMinimapButton
end

-- The rows the root ends with: the Pagle menu section's header and its checkbox.
local function menuRows(loaded)
	local initializers = loaded.client.settings.category("Pagle").layout.initializers
	return initializers[#initializers - 1], initializers[#initializers]
end

-- The icon's textures, by the file each shows.
local function texturesOf(button)
	local byFile = {}
	for _, child in ipairs(button.children) do
		if child.kind == "Texture" and child.texture then
			byFile[child.texture] = child
		end
	end
	return byFile
end

-- `value` rounded to 0.001.
local function round(value)
	return math.floor(value * 1000 + 0.5) / 1000
end

-- Where the icon sits now, as { x, y } off the minimap's centre, rounded; nil unless it is anchored by its centre to
-- the minimap's alone.
local function placeOf(loaded, button)
	local point, relativeTo, relativePoint, x, y = button:GetPoint()
	local centred = point == "CENTER" and relativePoint == "CENTER" and relativeTo == loaded.env.Minimap
	if button:GetNumPoints() ~= 1 or not centred then
		return nil
	end
	return { round(x), round(y) }
end

-- The place the icon has at `angle` degrees round the minimap, rounded as placeOf rounds.
local function at(angle)
	local radians = math.rad(angle)
	return { round(math.cos(radians) * RADIUS), round(math.sin(radians) * RADIUS) }
end

-- A drag of the icon with the mouse, the minimap's centre at 1700, 900 on the screen: the drag starts, the cursor
-- goes to `to` (screen pixels) over one frame, and the drag ends.
local function drag(loaded, button, to)
	loaded.env.Minimap.screenCenter = { 1700, 900 }
	button:GetScript("OnDragStart")(button, "LeftButton")
	loaded.client.cursor = to
	loaded.client.update(0.016)
	button:GetScript("OnDragStop")(button)
end

-- The tooltip's lines as the mouse going over something shows them on GameTooltip (`enter`), whether GameTooltip
-- is owned by `owner` then (when given), and whether it still shows once the mouse leaves (`leave`).
local function hover(loaded, owner, enter, leave)
	local entered = enter()
	local lines = loaded.client.tooltipLines()
	local owned = loaded.env.GameTooltip:IsOwned(owner or entered)
	leave(entered)
	return lines, owned, loaded.env.GameTooltip.shown
end

-- The icon's tooltip, as hover reads it.
local function hoverIcon(loaded, button)
	return hover(loaded, button, function()
		button:GetScript("OnEnter")(button)
	end, function()
		button:GetScript("OnLeave")(button)
	end)
end

-- The compartment entry's tooltip, as hover reads it, the mouse over the entry's row.
local function hoverCompartment(loaded, text)
	return hover(loaded, nil, function()
		return loaded.client.hoverCompartment(text)
	end, function(row)
		loaded.client.leaveCompartment(text, row)
	end)
end

-- Holds two moments in Cozy mode, from a QoL registered before login, so both waiting counts read 2 (CORE-R51).
local function twoWaiting()
	local loaded = loadCore()
	local M = loaded.env.Pagle.RegisterModule({ name = "QoL", title = "QoL", order = 50 })
	loaded.client.fire("PLAYER_LOGIN")
	loaded.ns.db.profile.announcements.cozy = true
	M:RaiseMoment({ rung = "nod", kind = "spec", title = "Lure on" })
	M:RaiseMoment({ rung = "toast", kind = "spec", title = "Gear swapped" })
	return loaded, loaded.env.PagleMinimapButton
end

describe("The minimap icon", function()
	it("is PagleMinimapButton, Core's own button on the minimap, made at login (CORE-R6, CORE-R53)", function()
		local loaded = loadCore()
		assert.is_nil(loaded.env.PagleMinimapButton)

		loaded.client.fire("PLAYER_LOGIN")

		local button = loaded.env.PagleMinimapButton
		assert.are.same({ "Button", loaded.env.Minimap }, { button.kind, button:GetParent() })
		assert.is_nil(loaded.env.LibStub("LibDBIcon-1.0", true))
	end)

	it("draws the favicon in a round mask inside the client's tracking-border ring (CORE-R53, CORE-R9)", function()
		local _, button = loggedIn()

		local textures = texturesOf(button)
		local icon = assert(textures[ICON])
		assert.are.equal(1, #icon.masks)
		assert.are.equal(MASK, icon.masks[1].texture)
		assert.are.same(
			{ "ARTWORK", "OVERLAY", "BACKGROUND" },
			{ icon.layer, assert(textures[RING]).layer, assert(textures[BACKGROUND]).layer }
		)
		assert.are.equal(HIGHLIGHT, button.highlightTexture)
		assert.are.same({ "LeftButton" }, button.dragButtons)
	end)

	it("shows the favicon from a 64 x 64 BLP in Pagle's media/minimap (CORE-R53)", function()
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
		local file = assert(io.open("addons/Pagle/media/minimap/Pagle.blp", "rb"))
		local header = file:read(20)
		file:close()
		-- BLP2's magic, type, four encoding bytes, then its width and height.
		assert.are.equal("BLP2", header:sub(1, 4))
		local function u32(offset)
			local a, b, c, d = header:byte(offset, offset + 3)
			return a + b * 256 + c * 65536 + d * 16777216
		end
		assert.are.same({ 64, 64 }, { u32(13), u32(17) })
	end)

	it("is shown by default at the minimap's bottom left, 225 degrees round (CORE-R53, CORE-R56)", function()
		local loaded, button = loggedIn()

		assert.is_true(button:IsShown())
		assert.are.same(at(225), placeOf(loaded, button))
		local minimap = loaded.ns.db.global.minimap
		assert.are.same({ false, 225 }, { minimap.hide, minimap.angle })
	end)

	it("follows the cursor round the minimap's edge while dragged, and saves its angle (CORE-R53)", function()
		local loaded, button = loggedIn()

		drag(loaded, button, { 1700, 1000 }) -- straight above the minimap's centre

		assert.are.same({ at(90), 90 }, { placeOf(loaded, button), loaded.ns.db.global.minimap.angle })
		assert.is_nil(button:GetScript("OnUpdate"))
		assert.is_false(button.highlightLocked)

		drag(loaded, button, { 1900, 900 }) -- far out to the right: still on the edge
		assert.are.same({ at(0), 0 }, { placeOf(loaded, button), loaded.ns.db.global.minimap.angle })
	end)

	it("reads the cursor in the minimap's own units at any UI scale (CORE-R53)", function()
		local loaded, button = loggedIn()
		loaded.env.MinimapCluster:SetScale(2)

		-- The minimap's centre is at 1700, 900 in its own units, 3400, 1800 screen pixels at scale 2: this is below it.
		drag(loaded, button, { 3400, 1600 })

		assert.are.equal(270, loaded.ns.db.global.minimap.angle)
	end)

	it("never moves while restricted, nor once restriction starts mid-drag (CORE-R53, CORE-R30)", function()
		local loaded, button = loggedIn()
		setCombat(loaded, true)

		drag(loaded, button, { 1700, 1000 })
		assert.are.same({ at(225), 225 }, { placeOf(loaded, button), loaded.ns.db.global.minimap.angle })

		setCombat(loaded, false)
		loaded.env.Minimap.screenCenter = { 1700, 900 }
		button:GetScript("OnDragStart")(button, "LeftButton")
		setCombat(loaded, true)
		loaded.client.cursor = { 1700, 1000 }
		loaded.client.update(0.016)
		assert.are.same({ at(225), 225 }, { placeOf(loaded, button), loaded.ns.db.global.minimap.angle })
		assert.is_nil(button:GetScript("OnUpdate"))
		button:GetScript("OnDragStop")(button)
		assert.are.same({ at(225), 225 }, { placeOf(loaded, button), loaded.ns.db.global.minimap.angle })
	end)

	it("comes back after a /reload at its saved angle, and hidden if it was (CORE-R53)", function()
		local loaded, button = loggedIn({ global = { minimap = { angle = 90, hide = true } } })

		assert.is_false(button:IsShown())
		assert.are.same(at(90), placeOf(loaded, button))
	end)

	it("isn't made off Forever, where Core never starts (CORE-R4)", function()
		local loaded = loadAddon("Pagle", { WOW_PROJECT_ID = PROJECT_IDS.MAINLINE, WOW_PROJECT_CAMELOT = 18 })

		loaded.client.fire("PLAYER_LOGIN")

		assert.is_nil(loaded.env.PagleMinimapButton)
		assert.are.same({ loaded.ns.L.NOT_FOREVER }, loaded.printed)
	end)
end)

describe("A click on the minimap icon", function()
	it("opens the compartment's menu at once, owned by the icon (CORE-R54, CORE-R50)", function()
		local loaded, button = loggedIn()

		button:Click("LeftButton")

		assert.are.equal(1, #loaded.client.menus)
		local menu = loaded.client.menus[1]
		assert.are.equal(button, menu.owner)
		assert.are.same(loaded.client.openCompartmentMenu("Pagle").texts(), menu.texts())
		assert.are.same({ curioShop(0), "Help chart the waters", "Settings" }, menu.texts())
	end)

	it("lists each Module's entries as the compartment does, read as it opens (CORE-R54, CORE-R52)", function()
		local loaded = loadCore()
		local reads = 0
		loaded.env.Pagle.RegisterModule({
			name = "QoL",
			title = "QoL",
			order = 50,
			menu = {
				{
					label = function()
						reads = reads + 1
						return "Input: Both " .. reads
					end,
					onClick = function() end,
				},
			},
		})
		loaded.env.Pagle.RegisterModule({
			name = "Hunts",
			title = "Hunts",
			order = 20,
			views = { { id = "board", label = "Hunts", open = function() end } },
		})
		loaded.client.fire("PLAYER_LOGIN")
		local button = loaded.env.PagleMinimapButton

		button:Click("LeftButton")
		button:Click("LeftButton")

		assert.are.same(
			{ "Hunts", "Input: Both 2", curioShop(0), "Help chart the waters", "Settings" },
			loaded.client.menus[2].texts()
		)
	end)

	it("runs an entry when clicked: Settings opens the root (CORE-R54, SET-R75)", function()
		local loaded, button = loggedIn()

		button:Click("LeftButton")
		loaded.client.menus[1].click("Settings")

		assert.are.same({ "Pagle" }, openedNames(loaded))
	end)

	it("with any other button does nothing (CORE-R54)", function()
		local loaded, button = loggedIn()

		for _, mouse in ipairs({ "RightButton", "MiddleButton", "Button4" }) do
			button:Click(mouse)
		end

		assert.are.same({}, loaded.client.menus)
	end)
end)

describe("The tooltip of Pagle's menu", function()
	it("reads Pagle on the icon and on the compartment entry, each beside its own (CORE-R55)", function()
		local loaded, button = loggedIn()

		assert.are.same({ { "Pagle" }, true, false }, { hoverIcon(loaded, button) })
		assert.are.same({ { "Pagle" }, true, false }, { hoverCompartment(loaded, "Pagle") })
	end)

	it("adds the waiting count on both while Cozy mode holds moments (CORE-R55, CORE-R51, ANN-R42)", function()
		local loaded, button = twoWaiting()

		assert.are.same({ "Pagle", "2 waiting" }, (hoverIcon(loaded, button)))
		assert.are.same({ "Pagle", "2 waiting" }, (hoverCompartment(loaded, "Pagle · 2 waiting")))
	end)

	it("adds A letter for you on both while the Letter shows, after the count (CORE-R55, ONB-R13)", function()
		local loaded, button = twoWaiting()
		assert.is_false(loaded.ns.LetterShows())

		-- The Letter's file (#327) replaces the hook with one that reads whether it shows.
		loaded.ns.LetterShows = function()
			return true
		end

		assert.are.same({ "Pagle", "2 waiting", "A letter for you" }, (hoverIcon(loaded, button)))
		assert.are.same({ "Pagle", "2 waiting", "A letter for you" }, (hoverCompartment(loaded, "Pagle · 2 waiting")))
	end)

	it("hides as a drag of the icon starts (CORE-R55)", function()
		local loaded, button = loggedIn()
		loaded.env.Minimap.screenCenter = { 1700, 900 }
		button:GetScript("OnEnter")(button)

		button:GetScript("OnDragStart")(button, "LeftButton")

		assert.are.same({}, loaded.client.tooltipLines())
		button:GetScript("OnDragStop")(button)
	end)
end)

describe("Show the minimap icon", function()
	it("is a checkbox under a Pagle menu header, the root's last rows, with its tooltip (SET-R10 row 10)", function()
		local loaded = loggedIn()

		local header, row = menuRows(loaded)

		assert.are.same({ "Pagle menu", "SettingsListSectionHeaderTemplate" }, { header:GetName(), header.template })
		assert.are.same({ "Show the minimap icon", "SettingsCheckboxControlTemplate" }, { row:GetName(), row.template })
		assert.are.equal(
			"A round Pagle button on the minimap's edge that opens the Pagle menu. The menu is also in the AddOns button"
				.. " by the minimap.",
			row.data.tooltip
		)
	end)

	it(
		"reads on by default, and has no default for the root's Defaults button to restore (CORE-R56, SET-R13)",
		function()
			local loaded = loggedIn()
			local setting = select(2, menuRows(loaded)):GetSetting()

			assert.is_true(setting:GetValue())
			assert.is_nil(setting:GetDefaultValue())
		end
	)

	it("hides and shows the icon at once, keeping it in PagleDB.global.minimap (CORE-R56)", function()
		local loaded, button = loggedIn()
		local setting = select(2, menuRows(loaded)):GetSetting()

		setting:SetValue(false)
		assert.are.same(
			{ false, true, false },
			{ button:IsShown(), loaded.ns.db.global.minimap.hide, setting:GetValue() }
		)

		setting:SetValue(true)
		assert.are.same(
			{ true, false, true },
			{ button:IsShown(), loaded.ns.db.global.minimap.hide, setting:GetValue() }
		)
	end)

	it("leaves the compartment entry and its menu as they are while the icon is hidden (CORE-R56)", function()
		local loaded = loggedIn()
		select(2, menuRows(loaded)):GetSetting():SetValue(false)

		assert.are.equal(1, #loaded.client.compartment)
		assert.are.same(
			{ curioShop(0), "Help chart the waters", "Settings" },
			loaded.client.openCompartmentMenu("Pagle").texts()
		)
	end)
end)

describe("Pagle's menu button", function()
	it("is the minimap icon while it shows, else the compartment's button (ONB-R52, ONB-R108, CORE-R56)", function()
		local loaded, button = loggedIn()
		local setting = select(2, menuRows(loaded)):GetSetting()
		local changed = 0
		-- Margin notes (#325) replace this hook, to move an arrow pointing at the menu button (ONB-R108).
		loaded.ns.MenuButtonChanged = function()
			changed = changed + 1
		end
		assert.are.equal(button, loaded.ns.MenuButton())

		setting:SetValue(false)
		assert.are.same({ loaded.env.AddonCompartmentFrame, 1 }, { loaded.ns.MenuButton(), changed })

		setting:SetValue(true)
		assert.are.same({ button, 2 }, { loaded.ns.MenuButton(), changed })
	end)

	it("is the compartment's button before login, and after a /reload with the icon hidden (ONB-R52)", function()
		local loaded = loadCore({ global = { minimap = { hide = true } } })
		assert.are.equal(loaded.env.AddonCompartmentFrame, loaded.ns.MenuButton())

		loaded.client.fire("PLAYER_LOGIN")

		assert.are.equal(loaded.env.AddonCompartmentFrame, loaded.ns.MenuButton())
	end)
end)
