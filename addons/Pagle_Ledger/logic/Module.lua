if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- What the Ledger registers with Core (LED-R1): pure logic, everything passed in (CORE-R7).

--- The Ledger's def for `Pagle.RegisterModule` (LED-R1). In M2 it has no view, slash command, menu entry,
--- `settingsAction` or settings rows, so its status row has no button (SET-R11, LED-R4). Its Fish Journal view and
--- `/pagle journal` come in M3.
---@return PagleModuleDef
function ns.ModuleDef()
	return {
		name = "Ledger",
		title = ns.L.TITLE,
		order = 10,
	}
end
