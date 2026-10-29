if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The active title on the client (LED-R77): logic/Titles.lua over the Ledger's projection, world and saved
-- celebrated set, stored in PagleLedgerDB.profile.activeTitle. The Collection's Titles shelf is its only caller (LED-R170).

--- What the titles read now: nothing of the state while the projection is updating (LOG-R74), so only celebrated
--- titles count then; the celebrated set as saved (asking makes none of its keys, LED-R90).
---@return LedgerTitleView
local function titleView()
	return {
		world = ns.world,
		state = ns.StateNow(),
		celebrated = ns.SavedCelebrated(),
		getItem = Pagle.GetItem,
		ownsAll = Pagle.GetTestLogGrant("devGoods") == true,
	}
end

--- Sets the active title (LED-R77): an earned title key, or nil for automatic. The frame after, the title record logs
--- it if it isn't the one last logged (LED-R157).
---@param key string?
---@return boolean set false, and nothing stored, for a key that isn't earned
function ns.SetActiveTitle(key)
	if not ns.StoreActiveTitle(ns.db.profile, titleView(), key) then
		return false
	end
	ns.QueueChoiceRecords()
	return true
end

--- The Collection's "Sign with it" (LED-R170, LED-R173): sets the active title, an earned key or nil for automatic, and redraws the
--- open Journal in it (ns.SetActiveTitle draws nothing).
---@param key string?
function ns.PickActiveTitle(key)
	if ns.SetActiveTitle(key) then
		ns.journal:Draw()
	end
end
