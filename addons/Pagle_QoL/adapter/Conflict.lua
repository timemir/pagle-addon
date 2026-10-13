if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- Coexisting with Angleur and Fishing Buddy (QOL-R80–R84). At PLAYER_LOGIN, before QoL first arms (QOL-R33), it
-- looks for an other fishing-key addon; if one is loaded, it asks the player which to keep and stands down for the
-- rest of the session, whatever the answer (QOL-R82, QOL-R97).

local standingDown = false

--- Whether QoL stands down this session: a conflict was found at login (QOL-R82). While it does, QoL is disarmed,
--- binds nothing, starts no Fishing stretch and leases no CVars; its settings and the leftover restore (QOL-R64)
--- carry on.
---@return boolean
function ns.IsStandingDown()
	return standingDown
end

---@param found PagleQoLConflict[]
local function usePagle(found)
	for _, conflict in ipairs(found) do
		C_AddOns.DisableAddOn(conflict.name)
	end
	print(ns.TurnedOffMessage(found))
end

local function useOther()
	C_AddOns.DisableAddOn("Pagle_QoL")
	print(ns.L.CONFLICT_TURNED_OFF_QOL)
end

--- The conflict check (QOL-R80). The Fishing key's PLAYER_LOGIN handler calls it right before the first arm
--- (QOL-R33). PLAYER_LOGIN fires once per load, at a login or a /reload, so the popup returns at each (QOL-R84).
function ns.CheckConflicts()
	local found = ns.FindConflicts(function(name)
		return (C_AddOns.IsAddOnLoaded(name))
	end, function(name)
		return C_AddOns.GetAddOnMetadata(name, "Title")
	end)
	if #found == 0 then
		return
	end
	standingDown = true
	-- "Use {other}" is the alt button: StaticPopup_OnClick runs OnAlt only for a click on button 3, and Esc runs
	-- OnEscape or OnCancel, which this dialog doesn't have, so Esc chooses nothing (QOL-R81, QOL-R84). Neither
	-- choice reloads the UI (QOL-R83). PAGLE_QOL_CONFLICT is the one StaticPopupDialogs field .luacheckrc lets QoL set.
	StaticPopupDialogs.PAGLE_QOL_CONFLICT = {
		text = ns.L.CONFLICT_TEXT,
		button1 = ns.L.CONFLICT_USE_PAGLE,
		button3 = ns.UseOtherLabel(found),
		OnAccept = function()
			usePagle(found)
		end,
		OnAlt = useOther,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
	}
	StaticPopup_Show("PAGLE_QOL_CONFLICT")
end
