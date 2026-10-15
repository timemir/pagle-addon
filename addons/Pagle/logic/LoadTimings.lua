---@class PagleNS
local ns = select(2, ...)

-- Login's load timings (#262), for launch re-verification checks 2 and 10 (roadmap.md › Launch re-verification
-- checklist): how long a large Catch log takes to load and to rebuild every projection. While dev mode is on at
-- ADDON_LOADED, Core keeps clock marks (debugprofilestop, in ms) of its own login steps in
-- PagleDB.global.probe.timings, and its projection machinery adds one timing per catch-up or rebuild
-- (PagleProjectionTiming). They're saved at the next /reload or logout, and scripts/read-wtf.lua's Re-verification
-- section reads them. With dev mode off nothing is kept and PagleDB is never touched. Pure logic (CORE-R7): the
-- adapter (adapter/Login.lua) reads the clock.

--- The marks, in the order Core's login reaches them, each with what it marks (read-wtf prints these).
---@type { [1]: string, [2]: string }[]
ns.LOAD_MARKS = {
	{ "filesLoaded", "Core's files loaded" },
	{ "addonLoaded", "ADDON_LOADED" },
	{ "logOpened", "log opened" },
	{ "playerLogin", "PLAYER_LOGIN" },
	{ "enteringWorld", "PLAYER_ENTERING_WORLD" },
	{ "idle", "projections idle" },
}

--- This login's load timings, as PagleDB.global.probe.timings holds them.
---@class PagleLoadTimings
---@field time integer        -- the server time at Core's ADDON_LOADED
---@field entries integer     -- the Catch log's length at load (loginSeq)
---@field budget number       -- the projections' time budget per frame, in ms (LOG-R71)
---@field syncLimit integer   -- above this many pending entries a catch-up or rebuild is chunked (LOG-R71)
---@field marks table<string, number> -- the clock at each of ns.LOAD_MARKS reached
---@field projections PagleProjectionTiming[] -- each catch-up or rebuild, in the order they finished

---@class PagleNS
---@field loadTimings PagleLoadTimings? This login's load timings, while dev mode was on at ADDON_LOADED (#262).

--- Starts this login's load timings at Core's ADDON_LOADED, once PagleDB is open: with dev mode on, a fresh
--- PagleLoadTimings in `global.probe.timings` (the probe itself, if one is stored, is kept), holding `marks` so far;
--- with it off, nothing, and `global` is left as it was. Sets and returns ns.loadTimings.
---@param global table PagleDB.global
---@param time integer the server time now
---@param entries integer the Catch log's length at load
---@param marks table<string, number> the marks reached so far
---@return PagleLoadTimings?
function ns.StartLoadTimings(global, time, entries, marks)
	ns.loadTimings = nil
	if global.dev ~= true then
		return nil
	end
	local probe = type(global.probe) == "table" and global.probe or {}
	global.probe = probe
	local timings = {
		time = time,
		entries = entries,
		budget = ns.PROJECTION_BUDGET,
		syncLimit = ns.PROJECTION_SYNC_LIMIT,
		marks = marks,
		projections = {},
	}
	probe.timings = timings
	ns.loadTimings = timings
	return timings
end

--- Notes the clock `ms` at mark `name` (ns.LOAD_MARKS), while this login's load timings are kept; else nothing.
---@param name string
---@param ms number
function ns.MarkLoadTiming(name, ms)
	if ns.loadTimings then
		ns.loadTimings.marks[name] = ms
	end
end
