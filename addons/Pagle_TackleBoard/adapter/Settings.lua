if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The Tackle Board's section on the Trackers page (SET-R43, tackle-board.md › Settings): the "Show goals workable here"
-- checkbox, added with M:AddSetting before ModulesChanged (CORE-R42). Core draws it natively under the "Tackle Board"
-- header, then adds the tracker frame dropdown as the section's last row (SET-R44); the Trackers page's Defaults
-- restores both (SET-R45). Nothing here writes onto Blizzard's rows or calls their code (SET-R5).

--- Adds the Tackle Board's Trackers rows (SET-R43), from OnInitialize once PagleTackleBoardDB is open.
---@param M PagleModuleHandle
function ns.AddSettings(M)
	M:AddSetting("trackers", {
		kind = "checkbox",
		id = "tracker",
		label = ns.L.SETTINGS_TRACKER,
		tooltip = ns.L.SETTINGS_TRACKER_TOOLTIP,
		default = ns.DB_DEFAULTS.profile.tracker,
		get = function()
			return ns.db.profile.tracker
		end,
		set = function(value)
			ns.db.profile.tracker = value
			ns.Redraw("tracker") -- the live tracker shows or hides at once (TKB-R120)
		end,
		-- Greyed out until the board is started (TKB-R5); Core asks again each time the page shows (SET-R61). While the
		-- projection updates it reads whether the board is started all the same (SET-R91).
		isEnabled = function()
			return ns.IsStarted()
		end,
	})
end
