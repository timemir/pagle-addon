if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The active title on the client (LED-R77): logic/Titles.lua over the Ledger's projection, world and saved
-- celebrated set, stored in PagleLedgerDB.profile.activeTitle. The Journal's "Signed as" is its only caller (SET-R70).

--- What the titles read now: nothing of the state while the projection is updating (LOG-R74), so only celebrated
--- titles count then; the celebrated set as saved (asking makes none of its keys, LED-R90).
---@return LedgerTitleView
local function titleView()
	local projection = ns.projection
	return {
		world = ns.world,
		state = projection and not projection:IsUpdating() and projection:GetState() --[[@as LedgerState?]] or nil,
		celebrated = ns.db.global.celebrated or {},
		getItem = Pagle.GetItem,
	}
end

--- Sets the active title (LED-R77): an earned title key, or nil for automatic.
---@param key string?
---@return boolean set false, and nothing stored, for a key that isn't earned
function ns.SetActiveTitle(key)
	return ns.StoreActiveTitle(ns.db.profile, titleView(), key)
end

--- "Signed As"'s pick (LED-R146, SET-R70): sets the active title, an earned key or nil for automatic, and redraws the
--- open Journal in it (ns.SetActiveTitle draws nothing).
---@param key string?
function ns.PickActiveTitle(key)
	if ns.SetActiveTitle(key) then
		ns.journal:Draw()
	end
end
