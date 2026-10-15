-- The fake Settings panel (spec/support/settings.lua) greys a row only where Blizzard's own code does, so a spec can't
-- pass on greying the client never shows (#120, SET-R20).

describe("The fake Settings panel", function()
	-- A category with a native checkbox, a native keybinding row and a custom row under it, each greyed out by a
	-- modify predicate reading `state.live`; returns the loaded client, the category, its checkbox setting and `state`.
	local function page()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		local env = loaded.env
		local state = { live = true, on = true }
		local function live()
			return state.live
		end
		local category = env.Settings.RegisterVerticalLayoutCategory("Fake")
		local setting = env.Settings.RegisterProxySetting(category, "Fake_on", "boolean", "On", true, function()
			return state.on
		end, function(value)
			state.on = value
			state.live = value
		end)
		local checkbox = env.Settings.CreateCheckbox(category, setting)
		local child = env.Settings.CreateCheckbox(
			category,
			env.Settings.RegisterProxySetting(category, "Fake_child", "boolean", "Child", true, live, function() end)
		)
		local key = env.CreateKeybindingEntryInitializer(1, true)
		local custom = env.Settings.CreateElementInitializer("CustomTemplate", {})
		category.layout:AddInitializer(key)
		category.layout:AddInitializer(custom)
		for _, initializer in ipairs({ child, key, custom }) do
			initializer:SetParentInitializer(checkbox)
			initializer:AddModifyPredicate(live)
		end
		return loaded, category, setting, state
	end

	it("greys a native control by its modify predicates, at a show and at its parent's change (SET-R61)", function()
		local loaded, category, setting = page()
		local rows = loaded.client.settings.show(category)
		assert.is_true(rows[2].frame.enabled)

		setting:SetValue(false)

		assert.is_false(rows[2].frame.enabled)
		assert.is_false(loaded.client.settings.show(category)[2].frame.enabled)
	end)

	it(
		"never greys a native keybinding row or a custom row, which don't read modify predicates (#120, SET-R20)",
		function()
			local loaded, category, setting, state = page()
			state.live = false

			local rows = loaded.client.settings.show(category)
			setting:SetValue(false)

			-- KeyBindingFrameBindingTemplateMixin:Init (Blizzard_Keybindings.lua) and a custom template's own Init.
			assert.is_nil(rows[3].frame.enabled)
			assert.is_nil(rows[4].frame.enabled)
		end
	)
end)
