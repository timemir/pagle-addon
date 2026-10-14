-- The fake client's slash commands and context menus (Blizzard_ChatFrameBase and Blizzard_Menu at the forever
-- 1.60.1 commit, see .luacheckrc), for /pagle and the compartment menu (CORE-R50, CORE-R60). spec/support/addon.lua
-- adds these stubs to every load.
--
--   loaded.env.SlashCmdList.PAGLE("settings")   -- /pagle settings, as the client calls a slash handler
--   loaded.client.menus[1].texts()              -- the buttons of the first context menu opened
--   loaded.client.menus[1].click("Settings")    -- clicks one
--   loaded.client.menus[1].enabled("Settings")  -- false once the addon called SetEnabled(false) on it
--   loaded.client.compartment[1].text           -- an Addon Compartment entry's label as it reads now
--   loaded.client.clickCompartment("Pagle")     -- opens the compartment and clicks the entry reading "Pagle"

---@class FakeClient
---@field menus table[] Every context menu MenuUtil.CreateContextMenu opened, in order. Each has `buttons`
--- ({ text, callback, enabled }), `texts()`, `enabled(text)` and `click(text)`.
---@field compartment AddonCompartmentEntry[] Each table AddonCompartmentFrame:RegisterAddon was given, in order.
---@field clickCompartment fun(text: string) Opens the Addon Compartment and clicks the entry whose text reads `text`
--- now, as Blizzard_Minimap's AddonCompartment does: its menu lists each entry by its current text, and a click calls
--- the entry's func(nil, { buttonName = "LeftButton" }, menu). An error when no entry reads `text`.

---@param client FakeClient
---@param stubs table<string, any> The fake client's stubs, which this adds to.
return function(client, stubs)
	stubs.SlashCmdList = {}
	client.menus = {}
	-- Blizzard_Minimap/Mainline/AddonCompartment at the forever 1.60.1 commit (.luacheckrc): RegisterAddon keeps the
	-- table, and the menu reads its text each time it opens. No addon lists itself through its TOC here.
	client.compartment = {}
	stubs.AddonCompartmentFrame = {
		RegisterAddon = function(_, addonData)
			client.compartment[#client.compartment + 1] = addonData
		end,
	}
	function client.clickCompartment(text)
		for _, entry in ipairs(client.compartment) do
			if entry.text == text then
				entry.func(nil, { buttonName = "LeftButton" }, {})
				return
			end
		end
		error("no compartment entry reads " .. tostring(text))
	end
	-- FrameXML's number formatting, for the Curio Shop entry's balance.
	stubs.BreakUpLargeNumbers = breakUpLargeNumbers

	-- As MenuUtil.CreateContextMenu: the generator fills a root description now, and the menu opens at the cursor.
	stubs.MenuUtil = {
		CreateContextMenu = function(owner, generator, ...)
			local menu = { owner = owner, buttons = {} }
			local root = {}
			function root.CreateButton(_, text, callback, data)
				local button = { text = text, callback = callback, data = data, enabled = true }
				-- As an element description's SetEnabled: a disabled button is greyed and ignores clicks.
				function button.SetEnabled(_, enabled)
					button.enabled = enabled
				end
				menu.buttons[#menu.buttons + 1] = button
				return button
			end
			generator(owner, root, ...)
			-- The texts of its buttons, in order.
			function menu.texts()
				local texts = {}
				for i, button in ipairs(menu.buttons) do
					texts[i] = button.text
				end
				return texts
			end
			-- Whether the button with this text is enabled (not greyed).
			function menu.enabled(text)
				for _, button in ipairs(menu.buttons) do
					if button.text == text then
						return button.enabled
					end
				end
				error("no menu button " .. tostring(text))
			end
			-- Clicks the button with this text, as a mouse click does: a disabled one does nothing.
			function menu.click(text)
				for _, button in ipairs(menu.buttons) do
					if button.text == text then
						if not button.enabled then
							return nil
						end
						return button.callback(button.data, { buttonName = "LeftButton" }, menu)
					end
				end
				error("no menu button " .. tostring(text))
			end
			client.menus[#client.menus + 1] = menu
			return menu
		end,
	}
end
