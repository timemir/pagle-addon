-- A file that reads ns.L while it loads, which spec/top_level_l_spec.lua must flag (CORE-R8, #514). The line numbers
-- the spec names are this file's, so edit it with the spec.
local _, ns = ...
local L = ns.L

local TITLE = L.TITLE
local HINT = ns.L.HINT
local ROWS = {
	{ label = L["ROW_ONE"] },
}
local COPY = L
local SHORT = COPY.SHORT
local OK = L.ONLY_CACHED and 1 or 0

if ns then
	TITLE = L.OTHER
end

ns.fixture = {
	TITLE,
	HINT,
	ROWS,
	SHORT,
	OK,
	label = function()
		return L.FINE
	end,
}
