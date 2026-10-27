if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Collection on the client (LED-R166, LED-R171, LED-R174): the Ledger notes which looks and titles it has seen owned
-- in PagleLedgerDB.global.collection, and opens the Journal on a look's shelf for Core's `def.collection`, `/pagle
-- collection` and Home's line. logic/Collection.lua is what it notes and opens; the Journal draws it (adapter/Journal.lua,
-- adapter/JournalShelves.lua). Nothing here makes a secure frame, so all of it works while restricted (LED-R121).

--- Notes every look and title the Angler owns and the Ledger hasn't seen yet in `PagleLedgerDB.global.collection`
--- (LED-R171), with the time now: after each live entry and the projection's done, and at each drawing of any spread.
--- `context` is the Journal's context just read, when there is one; nothing while the projection updates (LOG-R74).
---@param context LedgerJournalContext?
function ns.NoteCollection(context)
	context = context or ns.journal:Context()
	if context.updating then
		return
	end
	ns.NoteCollectionSeen(ns.db.global, ns.CollectionOwnedIDs(context --[[@as LedgerSpreadContext]]), GetServerTime())
end

--- Drawing a shelf's spread has the Angler look at every owned look on it (LED-R171): they are no longer new once it is
--- drawn again.
---@param context LedgerSpreadContext
---@param shelf string? the shelf's key
function ns.NoteShelfLookedNow(context, shelf)
	local found = shelf and ns.CollectionModel(context).byKey[shelf]
	if found and ns.db.global.collection then
		ns.NoteShelfLooked(ns.db.global.collection, found)
	end
end

--- Opens the Fish Journal on the look `goodID`'s shelf with it chosen, or on the Collection's own spread without one or
--- for a good Core has never cached (LED-R166, LED-R174): Core's `def.collection`, `/pagle collection` and, through
--- `Pagle.OpenShop`, an earned good the shop doesn't list (SHOP-R40). The Journal opens if it is closed.
---@param goodID string?
function ns.OpenCollection(goodID)
	local shelf = goodID and ns.CollectionShelfOf(ns.JournalGoods(), goodID)
	if shelf then
		ns.journal:Open(ns.JOURNAL_SHELF, { shelf = shelf, look = goodID })
	else
		ns.journal:Open(ns.JOURNAL_COLLECTION)
	end
end
