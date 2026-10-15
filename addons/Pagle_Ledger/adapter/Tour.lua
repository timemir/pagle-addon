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
		M:RegisterTourStop(stop.id, stop.label, function()
			saved = { shown = journal:IsShown(), place = journal.router:Place() }
			local context = journal:Context()
			local ready = not context.updating and context --[[@as LedgerSpreadContext]]
			journal:OpenPlace(ready and stop.place(ready) or ns.JournalPlace.home())
			if ready and stop.search then
				journal.frame.search:SetText(stop.search(ready))
			end
		end, function()
			local frame = journal.frame
			if not saved or not frame then
				return
			end
			frame.search:SetText("")
			frame.search:ClearFocus()
			journal.router:Open(saved.place.id, saved.place.args)
			if saved.shown then
				journal:Draw()
			else
				frame:Hide()
			end
			saved = nil
		end)
	end
end
