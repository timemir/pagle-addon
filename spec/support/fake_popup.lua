-- The fake client's popups and addon switches, for QoL's conflict popup and its Reload now popup (QOL-R81–R84).
-- spec/support/addon.lua adds these stubs to every load.
--
--   loaded.client.popup                  -- the popup shown last: { which, text, buttons = { [index] = label } }, or nil
--   loaded.client.clickPopup(3)          -- clicks that popup's button, as StaticPopup_OnClick does
--   loaded.client.pressEscape()          -- Esc, as StaticPopup_EscapePressed does: every shown popup with hideOnEscape
--   loaded.client.disabledAddOns         -- each C_AddOns.DisableAddOn call: { name, character }
--   loaded.client.reloads                -- how many times ReloadUI() was called (the spy for QOL-R6)
--
-- How dialogs show and their callbacks run follows Gethe/wow-ui-source branch forever at
-- 943764493e6b16d63ded3ab304150d1f05e58b57 ("1.60.1 (70338)"): Interface/AddOns/Blizzard_StaticPopup/StaticPopup.lua
-- (StaticPopup_Show reuses the shown frame of the same dialog, else takes a free one, so a callback can show a second
-- dialog; StaticPopup_OnClick without selectCallbackByIndex: button 1 → OnAccept, 3 → OnAlt, any other → OnCancel,
-- then hides the clicked frame if it still shows that dialog; StaticPopup_EscapePressed: OnEscape, else OnCancel
-- unless noCancelOnEscape, then hide) and Interface/AddOns/Blizzard_StaticPopup_Game/GameDialog.lua (SetupButtons
-- shows button N when it has a label).

---@class FakeClient
---@field popup { which: string, text: string, buttons: table<integer, string> }? The popup shown last, if any.
---@field clickPopup fun(index: integer) Clicks the last shown popup's button `index`; raises if it isn't shown.
---@field pressEscape fun() Presses Esc; raises if no popup is shown.
---@field disabledAddOns { name: string, character: string? }[] Each C_AddOns.DisableAddOn call, in order.
---@field reloads integer How many times ReloadUI() was called.

---@param client FakeClient
---@param stubs table<string, any> The fake client's stubs, which this adds to.
return function(client, stubs)
	client.disabledAddOns, client.reloads = {}, 0
	local dialogs = {}
	stubs.StaticPopupDialogs = dialogs

	---@class FakeDialogFrame
	---@field which string
	---@field info table the dialog definition (StaticPopupDialogInfo, with the fields the fake also reads)
	---@field data any
	---@field buttons table<integer, string>

	---@type FakeDialogFrame[]
	local shown = {} -- the shown dialog frames, oldest first

	local function update()
		local top = shown[#shown]
		client.popup = top and { which = top.which, text = top.info.text, buttons = top.buttons } or nil
	end

	---@param frame FakeDialogFrame
	local function hide(frame)
		for i, other in ipairs(shown) do
			if other == frame then
				table.remove(shown, i)
				break
			end
		end
		update()
	end

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
		local frame
		for _, other in ipairs(shown) do
			if other.which == which then
				frame = other
			end
		end
		if frame then
			hide(frame)
		else
			frame = {}
		end
		frame.which, frame.info, frame.data, frame.buttons = which, info, data, buttons
		shown[#shown + 1] = frame
		update()
		return frame
	end

	function client.clickPopup(index)
		assert(client.popup and client.popup.buttons[index], "FakeClient: no shown popup button " .. index)
		local frame = shown[#shown]
		local which, info, data = frame.which, frame.info, frame.data
		local hides = true
		if index == 1 then
			if info.OnAccept then
				hides = not info.OnAccept(frame, data)
			end
		elseif index == 3 then
			if info.OnAlt then
				info.OnAlt(frame, data, "clicked")
			end
		elseif info.OnCancel then
			hides = not info.OnCancel(frame, data, "clicked")
		end
		if hides and frame.which == which and (index ~= 3 or not info.noCloseOnAlt) then
			hide(frame)
		end
	end

	function client.pressEscape()
		assert(#shown > 0, "FakeClient: Esc pressed with no popup shown")
		for i = #shown, 1, -1 do
			local frame = shown[i]
			if frame and frame.info.hideOnEscape then
				local info, data = frame.info, frame.data
				if info.OnEscape then
					info.OnEscape(frame, data, "clicked")
				elseif info.OnCancel and not info.noCancelOnEscape then
					info.OnCancel(frame, data, "clicked")
				end
				hide(frame)
			end
		end
	end

	stubs.C_AddOns = stubs.C_AddOns or {}
	stubs.C_AddOns.DisableAddOn = function(name, character)
		client.disabledAddOns[#client.disabledAddOns + 1] = { name = name, character = character }
	end
	stubs.ReloadUI = function()
		client.reloads = client.reloads + 1
	end
end
