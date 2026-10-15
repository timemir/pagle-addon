if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

--- QoL's stop for `/pagle dev tour` (CORE-R65, CORE-R68): the Fishing page, where QoL's rows are, opened through Core
--- and closed through Blizzard's own path (HideUIPanel, SET-R12). Called from OnInitialize only when
--- `M.RegisterTourStop` exists, so QoL runs on a Core without it.
---@param M PagleModuleHandle
function ns.RegisterTourStops(M)
	M:RegisterTourStop("settings", ns.L.TOUR_SETTINGS, function()
		Pagle.OpenSettings("fishing")
	end, function()
		HideUIPanel(SettingsPanel)
	end)
end
