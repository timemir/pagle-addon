if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- Watched Dry spells (STA-R60–R63): the Angler's watches, `{ item, area }` in PagleStatsDB.profile.watched, oldest
-- first. Pure logic, everything passed in (CORE-R7): the profile, the UI error and the chat line come through
-- ns.WireWatches, which adapter/Settings.lua calls when it loads. The entry's watch toggle (#214), the Settings row
-- and the tracker (#218) all go through ns.Watch and ns.StopWatching, and every view reads ns.IsWatched.

--- The most watches the Angler keeps (stats.md › Tunables › Watches; STA-R60, STA-R61).
ns.MAX_WATCHES = 3

--- The red of the game's error text, as UIErrorsFrame shows a refused action (STA-R61).
local ERROR_RED = { r = 1, g = 0.1, b = 0.1 }

--- A watch (STA-R60): an item and the place whose page it was watched from, a zone or a subzone.
---@class StatsWatch
---@field item integer
---@field area integer

--- The client's side of the watches, passed in (CORE-R7). adapter/Settings.lua passes the game's.
---@class StatsWatchesClient
---@field Profile fun(): { tracker: boolean, watched: StatsWatch[] }   -- PagleStatsDB.profile, read at each call
---@field UIError fun(text: string, r: number, g: number, b: number)      -- UIErrorsFrame:AddMessage
---@field Print fun(line: string)                                           -- a chat line

---@type StatsWatchesClient
local client

--- Passes in the client's side of the watches. adapter/Settings.lua calls it when it loads.
---@param reads StatsWatchesClient
function ns.WireWatches(reads)
	client = reads
end

-- Where the watch of `item` from `area` sits in `watched`, or nil.
---@param watched StatsWatch[]
---@param item integer
---@param area integer
---@return integer?
local function indexOf(watched, item, area)
	for i, watch in ipairs(watched) do
		if watch.item == item and watch.area == area then
			return i
		end
	end
	return nil
end

--- The watches, oldest first (STA-R60). Read-only for views.
---@return StatsWatch[]
function ns.Watches()
	return client.Profile().watched
end

--- Whether the Angler watches `item` from `area`'s page (STA-R60): the same item watched from another place is
--- another watch.
---@param item integer
---@param area integer
---@return boolean
function ns.IsWatched(item, area)
	return indexOf(ns.Watches(), item, area) ~= nil
end

--- Watches `item` from `area` (STA-R60–R62). Returns whether it is watched now. A watch already kept changes nothing.
--- A 4th is refused: nothing changes, and the red UI error shows (STA-R61). Watching while the live tracker is off
--- turns it on, with one chat line (STA-R62). Every view redraws for "watches" after a change.
---@param item integer
---@param area integer
---@return boolean
function ns.Watch(item, area)
	local profile = client.Profile()
	local watched = profile.watched
	if indexOf(watched, item, area) then
		return true
	end
	if #watched >= ns.MAX_WATCHES then
		client.UIError(ns.L.WATCH_FULL:format(ns.MAX_WATCHES), ERROR_RED.r, ERROR_RED.g, ERROR_RED.b)
		return false
	end
	watched[#watched + 1] = { item = item, area = area }
	if not profile.tracker then
		profile.tracker = true
		client.Print(ns.L.WATCH_TRACKER_ON)
	end
	ns.Redraw("watches")
	return true
end

--- Stops watching `item` from `area` (STA-R60, STA-R63), keeping the other watches in order. It never turns the live
--- tracker off, even for the last watch. Every view redraws for "watches" after a change; with no such watch,
--- nothing changes.
---@param item integer
---@param area integer
function ns.StopWatching(item, area)
	local watched = ns.Watches()
	local i = indexOf(watched, item, area)
	if i then
		table.remove(watched, i)
		ns.Redraw("watches")
	end
end
