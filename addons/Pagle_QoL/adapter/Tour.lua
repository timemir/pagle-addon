if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

--- QoL's stops for `/pagle dev tour` (CORE-R65, CORE-R68): the Fishing page, where QoL's rows are, opened through Core
--- and closed through Blizzard's own path (HideUIPanel, SET-R12); a sample swap-back Nudge, its key on a brass cap;
--- and inert samples of the conflict note and the Reload now note. Called from OnInitialize only when
--- `M.RegisterTourStop` exists, so QoL runs on a Core without it.
---@param M PagleModuleHandle
function ns.RegisterTourStops(M)
	M:RegisterTourStop("settings", ns.L.TOUR_SETTINGS, function()
		Pagle.OpenSettings("fishing")
	end, function()
		HideUIPanel(SettingsPanel)
	end)
	M:RegisterTourStop("nudge", ns.L.TOUR_NUDGE, function()
		ns.ShowNudge(ns.SwapBackNudge("G"))
	end, ns.HideNudge)
	M:RegisterTourStop("notes", ns.L.TOUR_NOTES, function()
		ns.PreviewNotes(true)
	end, function()
		ns.PreviewNotes(false)
	end)
end
