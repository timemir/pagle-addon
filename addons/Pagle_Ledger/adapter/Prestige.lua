if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- Prestiging on the client (LED-R33): whether it is allowed now, and the native StaticPopup that asks before the
-- Ledger calls `M:RecordPrestige()` (LOG-R38). The Ledger is the only Module that calls it. The Journal's button
-- (the Angler page) calls ns.AskPrestige, and closing the Journal hides the popup.

-- The popup's StaticPopupDialogs key, the one field .luacheckrc lets the Ledger set.
local DIALOG = "PAGLE_LEDGER_PRESTIGE"

--- Whether the Angler may Prestige now (LED-R33): the computed level of the climb is 60 and the projection isn't
--- updating. False while the Ledger is inert (no projection).
---@return boolean
function ns.CanPrestige()
	local projection = ns.projection
	if not projection then
		return false
	end
	return ns.PrestigeAllowed(projection:GetState() --[[@as LedgerState?]], projection:IsUpdating())
end

--- Asks "Begin a new Ledger?" with "Prestige" and "Not yet" (LED-R33), when Prestige is allowed now. Confirming
--- checks again and calls `M:RecordPrestige()` only if it still is; otherwise nothing happens. Esc is "Not yet".
function ns.AskPrestige()
	if not ns.CanPrestige() then
		return
	end
	local L = ns.L
	StaticPopupDialogs.PAGLE_LEDGER_PRESTIGE = {
		text = L.PRESTIGE_CONFIRM,
		button1 = L.PRESTIGE_CONFIRM_YES,
		button2 = L.PRESTIGE_CONFIRM_NO,
		OnAccept = function()
			if ns.CanPrestige() then
				ns.Module:RecordPrestige()
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
	}
	StaticPopup_Show(DIALOG)
end

--- Hides the Prestige popup if it is up, choosing nothing (LED-R33): the Journal calls it as it closes.
function ns.HidePrestigeConfirm()
	StaticPopup_Hide(DIALOG)
end
