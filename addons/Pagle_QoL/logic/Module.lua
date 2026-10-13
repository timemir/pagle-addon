if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- What QoL registers with Core (QOL-R2): pure logic, everything passed in (CORE-R7).

--- QoL's def for `Pagle.RegisterModule` (QOL-R2). Its `menu` and `slash` entries come with Input (Track Q).
---@param openSettings fun(topic: string) opens a Settings topic page, as `Pagle.OpenSettings` does
---@return PagleModuleDef
function ns.ModuleDef(openSettings)
	return {
		name = "QoL",
		title = ns.L.TITLE,
		order = 50,
		settingsAction = {
			label = ns.L.SETTINGS_ACTION,
			onClick = function()
				openSettings("fishing")
			end,
		},
	}
end
