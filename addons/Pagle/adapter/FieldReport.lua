---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The Field report's rows and count on the client (field-report.md › The projection): ns.fieldReport, which login
-- step 1 wires over Core's host (ns.WireFieldReport in logic/Wiring.lua).

--- Every I, K and P row of the Field report, as plain tables, unsorted (REP-R20–R22; ns.FieldReportText sorts and
--- writes them). nil while the projection is updating (REP-R42), and before login step 1.
---@return PagleReportRow[]?
function ns.FieldReportRows()
	return ns.fieldReport and ns.fieldReport.rows()
end

--- The number of I, K and P rows a Field report has now (REP-R26): the projection's count plus the P rows built
--- from the buffer now; while it updates, its last stored count plus those. 0 before login step 1.
---@return integer
function Pagle.GetFieldReportCount()
	return ns.fieldReport and ns.fieldReport.count() or 0
end
