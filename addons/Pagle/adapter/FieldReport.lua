---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The Field report's rows and count on the client (field-report.md › The projection): logic/FieldReport.lua's
-- projection, bound in PagleDB.global.projections.fieldReport on Core's projection machinery (REP-R25, LOG-R78), and
-- the P rows read from PagleDB.global.diagnostics when asked for (REP-R22). It reads only Core's log, catalogue and
-- buffer, so enabled Modules change nothing (REP-R90), and it raises no moment and no Write-up (REP-R45, REP-R92).

local readRows, readCount

--- Login step 1 (LOG-R1), once PagleDB is open and the catalogue built: binds the Field report projection, ahead of
--- every Module's, so login step 3 catches it up or rebuilds it with the rest (LOG-R71, LOG-R72).
function ns.StartFieldReport()
	local global = ns.db.global
	---@cast global table -- AceDB always has a global section
	if type(global.projections) ~= "table" then
		global.projections = {}
	end
	if type(global.projections.fieldReport) ~= "table" then
		global.projections.fieldReport = {}
	end
	readRows, readCount = ns.AddFieldReport({
		projections = ns.projections,
		db = global.projections.fieldReport,
		catalogue = ns.Catalogue,
		iterate = function(afterSeq)
			return Pagle.IterateCatches(afterSeq)
		end,
		buffer = function()
			return global.diagnostics
		end,
		casts = function()
			return ns.catchLog:Reverse("cast")
		end,
	})
end

--- Every I, K and P row of the Field report, as plain tables, unsorted (REP-R20–R22; ticket #122 sorts and writes
--- them). nil while the projection is updating (REP-R42), and before login step 1.
---@return table[]?
function ns.FieldReportRows()
	return readRows and readRows() or nil
end

--- The number of I, K and P rows a Field report has now (REP-R26): the projection's count plus the P rows built
--- from the buffer now; while it updates, its last stored count plus those.
---@return integer
function Pagle.GetFieldReportCount()
	return readCount and readCount() or 0
end
