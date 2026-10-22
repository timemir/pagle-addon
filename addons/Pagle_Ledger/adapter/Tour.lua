if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Fish Journal's tour stops on the client (CORE-R65, CORE-R68): each of logic/Tour.lua's stops opens the book on
-- its place, read from the Journal's context as it shows, and types its search; its hide empties the search box and
-- puts the book back on the place it was on, closed if it was closed. The book makes no secure frames (LED-R121).

-- What the book was before a stop showed: open or closed, and on which place.
---@class LedgerTourSaved
---@field shown boolean
---@field place LedgerJournalPlace

--- Registers each of the Journal's tour stops on `M` (CORE-R65). Called from OnInitialize only when
--- `M.RegisterTourStop` exists, so the Ledger runs on a Core without it.
---@param M PagleModuleHandle
function ns.RegisterTourStops(M)
	local journal = ns.journal
	for _, stop in ipairs(ns.JOURNAL_TOUR) do
		---@type LedgerTourSaved?
		local saved
		M:RegisterTourStop(stop.id, ns.L[stop.label], function()
			saved = { shown = journal:IsShown(), place = journal:Place() }
			local context = journal:Context()
			local ready = not context.updating and context --[[@as LedgerSpreadContext]]
			journal:OpenPlace(ready and stop.place(ready) or ns.JournalPlace.home())
			-- the screenshot shows the spread settled, never mid-turn
			journal:Settle()
			if ready and stop.search and journal.search then
				journal.search:SetText(stop.search(ready))
			end
		end, function()
			local search = journal.search
			if not saved or not search then
				return
			end
			search:SetText("")
			search:ClearFocus()
			-- back on its place, drawn there in place; a book that was closed closes again
			journal:OpenPlace(saved.place, "still")
			if not saved.shown then
				journal:Close()
				journal:Settle()
			end
			saved = nil
		end)
	end
end
