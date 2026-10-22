if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- What the Ledger registers with Core (LED-R1): pure logic, everything passed in (CORE-R7).

--- The Ledger's def for `Pagle.RegisterModule` (LED-R1): its one view, the Fish Journal, and `/pagle journal`, both
--- toggling the Journal (any text after the command is ignored), and its line on the Field guide's What's in the box
--- step (ONB-R91). No menu entry, `settingsAction` or settings rows, so its status button is "Open Fish Journal"
--- (CORE-R44, SET-R11).
---@param toggleJournal fun() opens or closes the Fish Journal
---@return PagleModuleDef
function ns.ModuleDef(toggleJournal)
	return {
		name = "Ledger",
		title = ns.L.TITLE,
		order = 10,
		guideBlurb = ns.L.GUIDE_BLURB,
		views = { { id = "journal", label = ns.L.JOURNAL, open = toggleJournal } },
		slash = {
			{
				name = "journal",
				fn = function()
					toggleJournal()
				end,
				help = ns.L.JOURNAL_SLASH_HELP,
			},
		},
	}
end
