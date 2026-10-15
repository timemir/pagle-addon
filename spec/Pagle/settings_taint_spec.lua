-- What no Pagle addon's code does to Blizzard's Settings (SET-R6): each pattern below fails the spec wherever an
-- addon's shipped code says it. Each one makes Blizzard's own Settings code run in, or read, a value Pagle's
-- insecure code wrote, which taints the Settings list (#246): a Blizzard row initialised after it, like Audio's
-- Discord checkbox, then calls a protected function and the client blocks it as Pagle's
-- (ADDON_ACTION_FORBIDDEN).

local ADDONS = { "addons/Pagle/", "addons/Pagle_Ledger/", "addons/Pagle_QoL/" }

-- Each forbidden thing: a Lua pattern over code with comments removed, and why.
local FORBIDDEN = {
	-- A setting's NotifyUpdate or SetValue, called from Pagle's code, runs Blizzard's value-changed dispatch and every
	-- shown control's handler in Pagle's taint (Blizzard_Setting.lua SettingMixin:NotifyUpdate, TriggerValueChanged).
	{ "%f[%w_]NotifyUpdate%f[^%w_]", "SET-R6: Pagle never makes a setting notify its controls" },
	{ "%f[%w_]Settings%.SetValue%f[^%w_]", "SET-R6: Pagle never sets a setting's value itself" },
	{ "%f[%w_]Settings%.GetSetting%f[^%w_]", "SET-R6: Pagle never looks up a native setting to drive it" },
	{ "%f[%w_]SetValueToDefault%f[^%w_]", "SET-R6: Pagle never sets a setting's value itself" },
	{ "%f[%w_]SettingsCallbackRegistry%f[^%w_]", "SET-R6: Pagle never touches the Settings callback registry" },
	{ "%f[%w_]SettingsInbound%f[^%w_]", "SET-R6: Pagle never calls Settings' internal inbound API" },
	-- The Settings list reads an initializer's Factory, InitFrame, Resetter, GetExtent and GetTemplate in its own
	-- secure update (Blizzard_SettingsList.lua); one Pagle wrote taints that update. A custom row draws through its
	-- own template's Init and Release instead.
	{ "[%.:]InitFrame%s*=[^=]", "SET-R6: Pagle writes no field onto an initializer" },
	{ "[%.:]Resetter%s*=[^=]", "SET-R6: Pagle writes no field onto an initializer" },
	{ "[%.:]GetExtent%s*=[^=]", "SET-R6: Pagle writes no field onto an initializer" },
	{ "[%.:]Factory%s*=[^=]", "SET-R6: Pagle writes no field onto an initializer" },
	{ "[%.:]GetTemplate%s*=[^=]", "SET-R6: Pagle writes no field onto an initializer" },
	{ "function%s+[%w_]+[%.:]InitFrame%f[^%w_]", "SET-R6: Pagle writes no field onto an initializer" },
	{ "function%s+[%w_]+[%.:]GetExtent%f[^%w_]", "SET-R6: Pagle writes no field onto an initializer" },
	{ "[Ii]nitializer%s*%.[%w_]+%s*=[^=]", "SET-R6: Pagle writes no field onto an initializer" },
	{ "[Ii]nitializer%s*%[[^%]]+%]%s*=[^=]", "SET-R6: Pagle writes no field onto an initializer" },
	-- The panel and its list are Blizzard's: Pagle reads and writes none of their fields, calls none of their methods
	-- and hooks none of them. HideUIPanel(SettingsPanel) goes through Blizzard's own secure path (SET-R12).
	{ "%f[%w_]SettingsPanel%s*[%.:%[]", "SET-R6: Pagle never reaches into SettingsPanel" },
	{ "%f[%w_]hooksecurefunc%s*%(%s*[\"']?Settings", "SET-R6: Pagle hooks nothing of Settings" },
	{ "%f[%w_]hooksecurefunc%s*%(%s*SettingsPanel", "SET-R6: Pagle hooks nothing of Settings" },
}

-- Each forbidden thing the code says, as "<why>: <match>".
---@param text string
---@return string[]
local function offences(text)
	return forbiddenIn(withoutComments(text), FORBIDDEN)
end

describe("Pagle and Blizzard's Settings list (SET-R6, #246)", function()
	for _, dir in ipairs(ADDONS) do
		for _, path in ipairs(shippedFiles(dir)) do
			if not path:find("/libs/", 1, true) then
				it(path .. " leaves Blizzard's Settings code and data alone (SET-R6)", function()
					assert.are.same({}, offences(readFile(path)))
				end)
			end
		end
	end

	describe("catches", function()
		local planted = {
			{ "securecallfunction(native.NotifyUpdate, native)", "SET-R6: Pagle never makes a setting notify" },
			{ "setting:NotifyUpdate()", "SET-R6: Pagle never makes a setting notify" },
			{ 'Settings.NotifyUpdate("Pagle_QoL_fishing_3")', "SET-R6: Pagle never makes a setting notify" },
			{ 'Settings.SetValue("Pagle_Core_reloadReminder", true)', "SET-R6: Pagle never sets a setting's value" },
			{ "native:SetValueToDefault()", "SET-R6: Pagle never sets a setting's value" },
			{ 'local native = Settings.GetSetting("voiceProvider")', "SET-R6: Pagle never looks up a native setting" },
			{ "SettingsCallbackRegistry:TriggerEvent(variable)", "SET-R6: Pagle never touches the Settings callback" },
			{ "SettingsInbound.RepairDisplay()", "SET-R6: Pagle never calls Settings' internal" },
			{ "initializer.InitFrame = function(_, frame) end", "SET-R6: Pagle writes no field onto an initializer" },
			{ "row.Resetter = release", "SET-R6: Pagle writes no field onto an initializer" },
			{ "initializer.GetExtent = function() return 26 end", "SET-R6: Pagle writes no field onto an" },
			{ "function initializer:InitFrame(frame) end", "SET-R6: Pagle writes no field onto an initializer" },
			{ "headerInitializer.hideText = true", "SET-R6: Pagle writes no field onto an initializer" },
			{ 'initializer["data"] = {}', "SET-R6: Pagle writes no field onto an initializer" },
			{ "SettingsPanel:Close()", "SET-R6: Pagle never reaches into SettingsPanel" },
			{ "local list = SettingsPanel.Container.SettingsList", "SET-R6: Pagle never reaches into SettingsPanel" },
			{ 'hooksecurefunc(SettingsPanel, "Open", f)', "SET-R6: Pagle hooks nothing of Settings" },
			{ 'hooksecurefunc("SettingsPanel_EscapePressed", f)', "SET-R6: Pagle hooks nothing of Settings" },
		}
		for _, case in ipairs(planted) do
			it(case[1], function()
				local found = offences(case[1])

				assert.is_true(#found > 0)
				assert.are.equal(case[2], found[1]:sub(1, #case[2]))
			end)
		end

		it("nothing in a comment, an equality test or the panel passed to HideUIPanel", function()
			assert.are.same({}, offences("-- securecallfunction(native.NotifyUpdate, native)"))
			assert.are.same({}, offences("if row.initializer == initializer then end"))
			assert.are.same({}, offences("HideUIPanel(SettingsPanel)"))
			assert.are.same({}, offences("local initializer = Settings.CreateElementInitializer(TEMPLATE, data)"))
			assert.are.same({}, offences("initializer:SetParentInitializer(parent)"))
		end)
	end)
end)
