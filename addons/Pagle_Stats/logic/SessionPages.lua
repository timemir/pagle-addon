if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The Session pages' order and paging (stats.md › UI › This Session, Sessions): which Sessions the ruled ledgers
-- list, newest first, which page of the Sessions ledger a Session falls on, which Sessions come before the one shown,
-- and the order of a Session entry's zones and characters. Pure logic over the Session records' indices (oldest
-- first, STA-R30); adapter/Sessions.lua draws the pages.

--- The Sessions This Session's ruled ledger lists before the one shown (Tunables: Earlier Sessions on This Session).
ns.EARLIER_SESSIONS = 10

--- The Sessions on one page of the Sessions ledger (Tunables: Sessions per ledger page).
ns.SESSIONS_PER_LEDGER_PAGE = 16

--- Core's Session gap in seconds (LOG-R60, catch-log.md › Tunables), for the Sessions page's note. Core keeps it in
--- its own namespace and offers no constant on `Pagle`, so Stats repeats it here; it changes with Core's.
ns.SESSION_GAP = 900

--- One page of the Sessions ledger: its number and the count of pages (at least 1), the Sessions on it (indices into
--- the records, newest first), and whether "☚ later" and "earlier ☛" show (each hidden at its end).
---@class StatsSessionLedger
---@field page integer
---@field pages integer
---@field indices integer[]
---@field later boolean
---@field earlier boolean

--- Page `ledgerPage` of the Sessions ledger over `count` Sessions (stats.md › UI › Sessions): page 1 holds the newest
--- 16, newest first. A nil page is page 1; a page past either end is that end's.
---@param count integer the Session records
---@param ledgerPage integer? StatsBookTarget.ledgerPage
---@return StatsSessionLedger
function ns.SessionLedger(count, ledgerPage)
	local per = ns.SESSIONS_PER_LEDGER_PAGE
	local pages = math.max(1, math.ceil(count / per))
	local page = math.max(1, math.min(ledgerPage or 1, pages))
	local indices = {}
	local newest = count - (page - 1) * per
	for index = newest, math.max(1, newest - per + 1), -1 do
		indices[#indices + 1] = index
	end
	return { page = page, pages = pages, indices = indices, later = page > 1, earlier = page < pages }
end

--- The page of the Sessions ledger the Session at `index` falls on, over `count` Sessions.
---@param count integer
---@param index integer
---@return integer
function ns.LedgerPageOf(count, index)
	return math.floor((count - index) / ns.SESSIONS_PER_LEDGER_PAGE) + 1
end

--- The Sessions before the one at `index` that This Session's ledger lists (stats.md › UI › This Session): up to 10,
--- newest first.
---@param index integer the shown Session's index
---@return integer[]
function ns.EarlierSessions(index)
	local indices = {}
	for earlier = index - 1, math.max(1, index - ns.EARLIER_SESSIONS), -1 do
		indices[#indices + 1] = earlier
	end
	return indices
end

--- The index of the Session record whose ID is `id` (Core's Session ID), or nil when none has it.
---@param sessions StatsSession[]
---@param id string?
---@return integer?
function ns.FindSession(sessions, id)
	if id == nil then
		return nil
	end
	for index = #sessions, 1, -1 do
		if sessions[index].id == id then
			return index
		end
	end
	return nil
end

--- A Session's zones by its Casts in each, most first, ties by areaID (stats.md › UI: Where and who, Where).
---@param zones table<integer, integer> a Session record's `zones`: Casts by zone areaID
---@return { zone: integer, casts: integer }[]
function ns.ZonesByCasts(zones)
	local sorted = {}
	for zone, casts in pairs(zones) do
		sorted[#sorted + 1] = { zone = zone, casts = casts }
	end
	table.sort(sorted, function(a, b)
		if a.casts ~= b.casts then
			return a.casts > b.casts
		end
		return a.zone < b.zone
	end)
	return sorted
end

--- A Session's characters alphabetically by name, ties by character index (stats.md › UI: Where and who), each with
--- its Casts.
---@param chars table<integer, integer> a Session record's `chars`: Casts by character index
---@param nameOf fun(index: integer): string a character's name (ns.CharacterName)
---@return { char: integer, casts: integer, name: string }[]
function ns.CharactersByName(chars, nameOf)
	local sorted = {}
	for char, casts in pairs(chars) do
		sorted[#sorted + 1] = { char = char, casts = casts, name = nameOf(char) }
	end
	table.sort(sorted, function(a, b)
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.char < b.char
	end)
	return sorted
end
