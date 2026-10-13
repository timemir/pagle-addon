-- The fake client's popups and addon switches, for QoL's conflict popup (QOL-R81–R84). spec/support/addon.lua adds
-- these stubs to every load.
--
--   loaded.client.popup                  -- the shown popup: { which, text, buttons = { [index] = label } }, or nil
--   loaded.client.clickPopup(3)          -- clicks a shown popup's button, as StaticPopup_OnClick does
--   loaded.client.pressEscape()          -- Esc on the shown popup, as StaticPopup_EscapePressed does
--   loaded.client.disabledAddOns         -- each C_AddOns.DisableAddOn call: { name, character }
--   loaded.client.reloads                -- how many times ReloadUI() was called
--
-- How a dialog's callbacks run follows Gethe/wow-ui-source branch forever at
-- 943764493e6b16d63ded3ab304150d1f05e58b57 ("1.60.1 (70338)"): Interface/AddOns/Blizzard_StaticPopup/StaticPopup.lua
-- (StaticPopup_OnClick without selectCallbackByIndex: button 1 → OnAccept, 3 → OnAlt, any other → OnCancel;
-- StaticPopup_EscapePressed: OnEscape, else OnCancel unless noCancelOnEscape, then hide) and
-- Interface/AddOns/Blizzard_StaticPopup_Game/GameDialog.lua (SetupButtons shows button N when it has a label).

---@class FakeClient
---@field popup { which: string, text: string, buttons: table<integer, string> }? The popup shown now, if any.
---@field clickPopup fun(index: integer) Clicks the shown popup's button `index`; raises if it isn't shown.
---@field pressEscape fun() Presses Esc on the shown popup; raises if none is shown.
---@field disabledAddOns { name: string, character: string? }[] Each C_AddOns.DisableAddOn call, in order.
---@field reloads integer How many times ReloadUI() was called.

---@param client FakeClient
---@param stubs table<string, any> The fake client's stubs, which this adds to.
return function(client, stubs)
	client.disabledAddOns, client.reloads = {}, 0
	local dialogs = {}
	stubs.StaticPopupDialogs = dialogs

	local shown -- { which, info, data }

	stubs.StaticPopup_Show = function(which, _, _, data)
		local info = dialogs[which]
		if not info then
			error("Dialog " .. which .. " does not exist.")
		end
		local buttons = {}
		for index = 1, 4 do
			local label = info["button" .. index]
			local display = info["DisplayButton" .. index]
			if label and (not display or display(nil, data)) then
				buttons[index] = label
			end
		end
		shown = { which = which, info = info, data = data }
		client.popup = { which = which, text = info.text, buttons = buttons }
		return {}
	end

	local function hide()
		shown, client.popup = nil, nil
	end

	function client.clickPopup(index)
		assert(client.popup and client.popup.buttons[index], "FakeClient: no shown popup button " .. index)
		local info, data = shown.info, shown.data
		local hides = true
		if index == 1 then
			if info.OnAccept then
				hides = not info.OnAccept({}, data)
			end
		elseif index == 3 then
			if info.OnAlt then
				info.OnAlt({}, data, "clicked")
			end
		elseif info.OnCancel then
			hides = not info.OnCancel({}, data, "clicked")
		end
		if hides and (index ~= 3 or not info.noCloseOnAlt) then
			hide()
		end
	end

	function client.pressEscape()
		assert(shown, "FakeClient: Esc pressed with no popup shown")
		if not shown.info.hideOnEscape then
			return
		end
		local info, data = shown.info, shown.data
		if info.OnEscape then
			info.OnEscape({}, data, "clicked")
		elseif info.OnCancel and not info.noCancelOnEscape then
			info.OnCancel({}, data, "clicked")
		end
		hide()
	end

	stubs.C_AddOns = stubs.C_AddOns or {}
	stubs.C_AddOns.DisableAddOn = function(name, character)
		client.disabledAddOns[#client.disabledAddOns + 1] = { name = name, character = character }
	end
	stubs.ReloadUI = function()
		client.reloads = client.reloads + 1
	end
end
