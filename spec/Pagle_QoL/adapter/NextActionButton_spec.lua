-- The next-action button (QOL-R70–R74): what the next press will do, drawn from each of the Fishing key's evaluations,
-- driven through FakePagle and the fake client's game side (spec/support/fake_game.lua), widgets and GameTooltip.

local FISHING_POLE, SWORD = 6256, 25
local SHINY_BAUBLE = 6529
local FISHING = 3
local FISHING_ICON, SET_ICON, BAUBLE_ICON = 136245, 132940, 134335

-- QoL loaded against FakePagle and logged in: F bound to the Fishing key, a fishing pole in hand with no lure on, and
-- Shiny Baubles in the bags. `before(fake, client, loaded)` runs after the load and before PLAYER_LOGIN.
---@param before fun(fake: FakePagle, client: FakeClient, loaded: LoadedAddon)?
---@return FakePagle fake
---@return FakeClient client
---@return LoadedAddon loaded
local function start(before)
	local fake = newFakePagle()
	local loaded = fake.load("Pagle_QoL")
	local client = loaded.client
	client.boundKeys.PAGLE_FISHING_KEY = { "F" }
	client.mainHand = FISHING_POLE
	client.bags[SHINY_BAUBLE] = 5
	client.itemIcons[SHINY_BAUBLE] = BAUBLE_ICON
	if before then
		before(fake, client, loaded)
	end
	fake.login()
	fake.fireGameEvent("PLAYER_LOGIN")
	return fake, client, loaded
end

-- No pole in hand, and the set "Fishing" (a pole) chosen as the fishing set: the gear step is ready (QOL-R43).
---@param client FakeClient
---@param loaded LoadedAddon
local function withGearStep(_, client, loaded)
	client.mainHand = SWORD
	client.equipmentSets[FISHING] = { name = "Fishing", icon = SET_ICON, items = { [16] = FISHING_POLE } }
	loaded.ns.db.global.gear[PLAYER_GUID] = { setID = FISHING, name = "Fishing" }
end

-- The button, found as the frame with an action button's Icon and HotKey; nil until QoL has made it.
---@param loaded LoadedAddon
---@return table?
local function buttonOf(loaded)
	for _, frame in ipairs(loaded.client.frames) do
		if frame.Icon and frame.HotKey then
			return frame
		end
	end
	return nil
end

-- The button, which QoL must have made.
---@param loaded LoadedAddon
---@return table
local function theButton(loaded)
	return assert(buttonOf(loaded))
end

-- What the button shows now: nil while it is hidden or not made, else its icon, whether that is desaturated, its
-- label and its hotkey text (nil for a hidden one).
---@param loaded LoadedAddon
---@return { icon: integer?, desaturated: boolean, label: string?, hotkey: string? }?
local function shown(loaded)
	local button = buttonOf(loaded)
	if not button or not button.shown then
		return nil
	end
	return {
		icon = button.Icon.texture,
		desaturated = button.Icon.desaturated == true,
		label = button.Label.shown and button.Label.text or nil,
		hotkey = button.HotKey.shown and button.HotKey.text or nil,
	}
end

-- Hovers the button and returns the tooltip's text, or nil while no tooltip shows for it.
---@param loaded LoadedAddon
---@return string?
local function hover(loaded)
	local button = theButton(loaded)
	button.scripts.OnEnter(button)
	local tooltip = loaded.env.GameTooltip
	return tooltip.shown and tooltip.owner == button and tooltip.text or nil
end

describe("The next-action button", function()
	describe("its look", function()
		it("is a 36 px display-only frame on UIParent, not a secure button (QOL-R70, QOL-R73)", function()
			local _, _, loaded = start()

			local button = theButton(loaded)
			assert.are.equal("Frame", button.kind)
			-- No template and no name: not secure, and no global (QOL-R5).
			assert.is_nil(button.template)
			assert.is_nil(button.name)
			assert.are.equal(loaded.env.UIParent, button.parent)
			assert.are.equal(36, button.width)
			assert.are.equal(36, button.height)
			-- Clicking does nothing.
			assert.is_nil(button.scripts.OnClick)
			assert.is_nil(button.scripts.OnMouseDown)
			assert.is_nil(button.scripts.OnMouseUp)
		end)

		it(
			"shows the lure's icon, Lure and the key's short text with a pole in hand and no lure on (QOL-R70, QOL-R71)",
			function()
				local _, _, loaded = start()

				assert.are.same(
					{ icon = BAUBLE_ICON, desaturated = false, label = "Lure", hotkey = "F" },
					shown(loaded)
				)
			end
		)

		it("shows the first key bound, in the short form action bars use (QOL-R70)", function()
			local _, _, loaded = start(function(_, client)
				client.boundKeys.PAGLE_FISHING_KEY = { "SHIFT-F", "G" }
			end)

			assert.are.equal("s-F", assert(shown(loaded)).hotkey)
		end)

		it("shows no hotkey under Input Double-click, or with no key bound (QOL-R70, QOL-R11)", function()
			local fake, client, loaded = start()

			loaded.ns.SetInput("click")
			assert.are.same({ icon = BAUBLE_ICON, desaturated = false, label = "Lure" }, shown(loaded))

			loaded.ns.SetInput("both")
			client.boundKeys.PAGLE_FISHING_KEY = nil
			fake.fireGameEvent("UPDATE_BINDINGS")
			assert.is_nil(assert(shown(loaded)).hotkey)
		end)

		it("shows the Fishing icon with Cast, then with Reel once the bobber is out (QOL-R71)", function()
			local fake, client, loaded = start(function(_, client)
				client.mainHandEnchant = 263 -- a lure is on
			end)
			assert.are.same({ icon = FISHING_ICON, desaturated = false, label = "Cast", hotkey = "F" }, shown(loaded))

			fake.fire("CastStarted")
			assert.are.same({ icon = FISHING_ICON, desaturated = false, label = "Reel", hotkey = "F" }, shown(loaded))

			client.mainHandEnchant = nil
			fake.fireGameEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
			assert.are.equal("Lure", assert(shown(loaded)).label)
		end)

		it("shows Cast once a reel press didn't take, as the key casts then (QOL-R71, QOL-R35)", function()
			local fake, client, loaded = start(function(_, client)
				client.mainHandEnchant = 263
			end)
			fake.fire("CastStarted")
			assert.are.equal("Reel", assert(shown(loaded)).label)

			-- A press of F, then the reel wait passing with the channel still on.
			client.keysDown.F = true
			client.nextFrame()
			client.keysDown.F = nil
			client.nextFrame()
			client.nextFrame(0.5)

			assert.are.equal("SPELL Fishing", client.overrideAction("F"))
			assert.are.same({ icon = FISHING_ICON, desaturated = false, label = "Cast", hotkey = "F" }, shown(loaded))
		end)

		it("shows the fishing set's icon with Gear while the gear step is ready (QOL-R71)", function()
			local _, _, loaded = start(withGearStep)

			assert.are.same({ icon = SET_ICON, desaturated = false, label = "Gear", hotkey = "F" }, shown(loaded))
		end)
	end)

	describe("when it shows", function()
		it("is hidden with no stretch, no pole and no gear step (QOL-R72)", function()
			local _, _, loaded = start(function(_, client)
				client.mainHand = SWORD
			end)

			assert.is_nil(shown(loaded))
		end)

		it("shows while a Fishing stretch runs, even with no pole in hand (QOL-R72, QOL-R61)", function()
			local fake, client, loaded = start(function(_, client)
				client.mainHand = nil
			end)
			assert.is_nil(shown(loaded))

			fake.fire("CastStarted")
			assert.are.equal("Reel", assert(shown(loaded)).label)

			fake.fireGameEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
			fake.fire("CastEnded")
			assert.are.equal("Cast", assert(shown(loaded)).label)
			-- The stretch's idle end, 60 s after the last Cast, hides it at the next tick.
			client.nextFrame(60)
			client.nextFrame(0.5)
			assert.is_nil(shown(loaded))
		end)

		it("hides when the pole comes off, and shows again when it goes back on (QOL-R72)", function()
			local fake, client, loaded = start()

			client.mainHand = SWORD
			fake.fireGameEvent("PLAYER_EQUIPMENT_CHANGED", 16, true)
			assert.is_nil(shown(loaded))

			client.mainHand = FISHING_POLE
			fake.fireGameEvent("PLAYER_EQUIPMENT_CHANGED", 16, true)
			assert.are.equal("Lure", assert(shown(loaded)).label)
		end)

		it("is hidden with Show the next-action button off, at once (QOL-R72, QOL-R25)", function()
			local fake, _, loaded = start()

			local show
			for _, row in ipairs(assert(fake.settingsPage("fishing"))) do
				show = row.label == "Show the next-action button" and row.setting or show
			end
			show.set(false)
			assert.is_nil(shown(loaded))

			show.set(true)
			assert.are.equal("Lure", assert(shown(loaded)).label)
		end)

		it("is never made while QoL stands down (QOL-R72, QOL-R82)", function()
			local _, _, loaded = start(function(_, client)
				client.addons.Angleur = { metadata = { Title = "Angleur" } }
			end)

			assert.is_nil(buttonOf(loaded))
		end)

		it("shows nothing in combat: the last icon, desaturated, with no label (QOL-R71, QOL-R72, QOL-R93)", function()
			local fake, _, loaded = start()

			fake.fireGameEvent("PLAYER_REGEN_DISABLED")
			fake.setRestricted(true)
			assert.are.same({ icon = BAUBLE_ICON, desaturated = true, hotkey = "F" }, shown(loaded))

			-- Still nothing while restricted, whatever changes.
			fake.fireGameEvent("BAG_UPDATE_DELAYED")
			assert.are.same({ icon = BAUBLE_ICON, desaturated = true, hotkey = "F" }, shown(loaded))

			fake.setRestricted(false)
			assert.are.same({ icon = BAUBLE_ICON, desaturated = false, label = "Lure", hotkey = "F" }, shown(loaded))
		end)

		it("in combat keeps showing nothing with the gear step ready, and hides with neither (QOL-R72)", function()
			local fake, _, loaded = start(withGearStep)

			fake.setRestricted(true)
			assert.are.same({ icon = SET_ICON, desaturated = true, hotkey = "F" }, shown(loaded))

			loaded.ns.db.global.gear[PLAYER_GUID] = nil
			fake.fireGameEvent("PLAYER_EQUIPMENT_CHANGED", 16, true)
			assert.is_nil(shown(loaded))
		end)

		it("shows the Fishing icon for nothing when it has shown no icon yet (QOL-R71)", function()
			local fake = newFakePagle()
			local loaded = fake.load("Pagle_QoL")
			loaded.client.mainHand = FISHING_POLE
			fake.login()
			fake.setRestricted(true)
			fake.fireGameEvent("PLAYER_LOGIN")
			fake.fireGameEvent("PLAYER_EQUIPMENT_CHANGED", 16, true)

			assert.are.same({ icon = FISHING_ICON, desaturated = true }, shown(loaded))
		end)
	end)

	describe("its place", function()
		local DEFAULT = { "BOTTOM", "UIParent", "BOTTOM", 0, 230 }

		-- The button's one anchor, with UIParent by name.
		---@param loaded LoadedAddon
		---@return table
		local function anchor(loaded)
			local button = theButton(loaded)
			assert.are.equal(1, #button.points)
			local point, relativeTo, relativePoint, x, y = button:GetPoint(1)
			return { point, relativeTo == loaded.env.UIParent and "UIParent" or relativeTo, relativePoint, x, y }
		end

		it("is the bottom centre of the screen, 230 px up, by default (QOL-R73)", function()
			local _, _, loaded = start()

			assert.are.same(DEFAULT, anchor(loaded))
		end)

		it("is the saved point (QOL-R73, qol.md › Data)", function()
			local _, _, loaded = start(function(_, _, loaded)
				loaded.ns.db.profile.indicator.point =
					{ point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = -40, y = 12 }
			end)

			assert.are.same({ "CENTER", "UIParent", "CENTER", -40, 12 }, anchor(loaded))
		end)

		it("moves with Shift-drag and saves the point in profile.indicator.point (QOL-R73)", function()
			local _, client, loaded = start()
			local button = theButton(loaded)
			client.keysDown.SHIFT = true

			button:Drag({ "BOTTOMLEFT", nil, "BOTTOMLEFT", 612, 340 })

			assert.are.same({ "BOTTOMLEFT", "UIParent", "BOTTOMLEFT", 612, 340 }, anchor(loaded))
			assert.are.same(
				{ point = "BOTTOMLEFT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT", x = 612, y = 340 },
				loaded.env.PagleQoLDB.profiles.Default.indicator.point
			)
			assert.is_false(button.moving)
		end)

		it("doesn't move with a drag that isn't a Shift-drag (QOL-R73)", function()
			local _, _, loaded = start()

			theButton(loaded):Drag({ "BOTTOMLEFT", nil, "BOTTOMLEFT", 612, 340 })

			assert.are.same(DEFAULT, anchor(loaded))
			assert.is_nil(loaded.env.PagleQoLDB.profiles.Default.indicator.point)
		end)

		it("never moves while restricted (QOL-R73)", function()
			local fake, client, loaded = start()
			client.keysDown.SHIFT = true
			fake.setRestricted(true)

			theButton(loaded):Drag({ "BOTTOMLEFT", nil, "BOTTOMLEFT", 612, 340 })

			assert.are.same(DEFAULT, anchor(loaded))
			assert.is_nil(loaded.env.PagleQoLDB.profiles.Default.indicator.point)
		end)

		it("stops a Shift-drag that restriction starts during, keeping where it got to (QOL-R73)", function()
			local fake, client, loaded = start()
			local button = theButton(loaded)
			client.keysDown.SHIFT = true
			button.scripts.OnDragStart(button, "LeftButton")
			button.movedTo = { "CENTER", nil, "CENTER", 5, 6 }

			fake.setRestricted(true)

			assert.is_false(button.moving)
			assert.are.same({ "CENTER", "UIParent", "CENTER", 5, 6 }, anchor(loaded))
			assert.are.same(
				{ point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 5, y = 6 },
				loaded.env.PagleQoLDB.profiles.Default.indicator.point
			)
		end)

		it("goes back to the default with Reset (QOL-R73)", function()
			local _, client, loaded = start()
			client.keysDown.SHIFT = true
			theButton(loaded):Drag({ "BOTTOMLEFT", nil, "BOTTOMLEFT", 612, 340 })

			loaded.ns.ResetNextActionButton()

			assert.are.same(DEFAULT, anchor(loaded))
			assert.is_nil(loaded.env.PagleQoLDB.profiles.Default.indicator.point)
		end)
	end)

	describe("its tooltip", function()
		it("names the lure, from C_Item (QOL-R74)", function()
			local _, _, loaded = start()

			assert.are.equal("Apply Shiny Bauble", hover(loaded))
			assert.are.equal("ANCHOR_RIGHT", loaded.env.GameTooltip.anchor)
		end)

		it("names the fishing set (QOL-R74)", function()
			local _, _, loaded = start(withGearStep)

			assert.are.equal("Put on Fishing", hover(loaded))
		end)

		it("reads Cast, Reel in and, in combat, Nothing to do (QOL-R74)", function()
			local fake, _, loaded = start(function(_, client)
				client.mainHandEnchant = 263
			end)
			assert.are.equal("Cast", hover(loaded))

			fake.fire("CastStarted")
			assert.are.equal("Reel in", hover(loaded))

			fake.setRestricted(true)
			assert.are.equal("Nothing to do", hover(loaded))
		end)

		it("follows the next action while the mouse stays over it, and hides when it leaves (QOL-R74)", function()
			local fake, _, loaded = start()
			assert.are.equal("Apply Shiny Bauble", hover(loaded))

			fake.fire("CastStarted")
			assert.are.equal("Reel in", loaded.env.GameTooltip.text)

			local button = theButton(loaded)
			button.scripts.OnLeave(button)
			assert.is_false(loaded.env.GameTooltip.shown)
			fake.fireGameEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
			assert.is_false(loaded.env.GameTooltip.shown)
		end)

		it("waits for an item that isn't cached to load, then names it (QOL-R74)", function()
			local _, client, loaded = start(function(_, client)
				client.itemNames[SHINY_BAUBLE] = nil
			end)

			assert.is_nil(hover(loaded))
			client.loadItem(SHINY_BAUBLE, "Shiny Bauble")
			assert.is_true(loaded.env.GameTooltip.shown)
			assert.are.equal("Apply Shiny Bauble", loaded.env.GameTooltip.text)
		end)

		it("shows nothing when the item loads after the mouse has left (QOL-R74)", function()
			local _, client, loaded = start(function(_, client)
				client.itemNames[SHINY_BAUBLE] = nil
			end)
			hover(loaded)
			local button = theButton(loaded)
			button.scripts.OnLeave(button)

			client.loadItem(SHINY_BAUBLE, "Shiny Bauble")

			assert.is_false(loaded.env.GameTooltip.shown)
		end)
	end)
end)
