if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

-- The Ledger's string table (CORE-R8). Every user-facing string goes through ns.L; enUS only in 1.0.

---@class PagleLedgerNS
local ns = select(2, ...)

---@class PagleLedgerStrings
ns.L = {
	-- The Ledger's def title (LED-R1).
	TITLE = "Ledger",
}
