---@class PagleNS
local ns = select(2, ...)

-- The diagnostics buffer's pure parts (LOG-R80–R82): the world-object texts the player hovered, and the ring buffer
-- of one entry per recorded Cast. The adapter (adapter/Diagnostics.lua) feeds in the hovers and the clock.

--- Tunable: how long before a Cast's channel started a hovered text still counts, in seconds (LOG-R81).
ns.DIAGNOSTICS_WINDOW = 60
--- Tunable: how many hovered texts an entry keeps (LOG-R81).
ns.DIAGNOSTICS_TEXTS = 3
--- Tunable: how many entries the diagnostics buffer keeps (LOG-R81).
ns.DIAGNOSTICS_SIZE = 500

-- How long a hover is kept, in seconds: the window, plus room for the time between a channel's start and its Cast's
-- record (the channel and the grace time, well under a minute), since the log is trimmed as hovers come in.
local HOVER_KEEP = 2 * ns.DIAGNOSTICS_WINDOW

--- A run of hovers of one text with nothing else hovered between them: from `first` to `last` (`GetTime()`).
---@class PagleHoverSpan
---@field text string
---@field first number
---@field last number

--- The world-object texts hovered lately, oldest first (LOG-R80). The spans never overlap.
---@class PagleHoverLog
---@field spans PagleHoverSpan[]
local HoverLog = {}
HoverLog.__index = HoverLog

--- An empty hover log: hovers live only in memory, for one login.
---@return PagleHoverLog
function ns.NewHoverLog()
	return setmetatable({ spans = {} }, HoverLog)
end

--- The player hovered a world object whose tooltip's first line is `text`, at `now` (LOG-R80). Hovers older than
--- any Cast could still ask for are dropped.
---@param text string
---@param now number
function HoverLog:Hovered(text, now)
	local spans = self.spans
	local stale = 0
	while spans[stale + 1] and spans[stale + 1].last < now - HOVER_KEEP do
		stale = stale + 1
	end
	if stale > 0 then
		local kept = {}
		for i = stale + 1, #spans do
			kept[#kept + 1] = spans[i]
		end
		spans = kept
		self.spans = kept
	end
	local latest = spans[#spans]
	if latest and latest.text == text then
		latest.last = now
	else
		spans[#spans + 1] = { text = text, first = now, last = now }
	end
end

--- Up to `ns.DIAGNOSTICS_TEXTS` distinct texts hovered in the `ns.DIAGNOSTICS_WINDOW` seconds up to `startedAt`,
--- most recently hovered first (LOG-R81).
---@param startedAt number
---@return string[]
function HoverLog:TextsBefore(startedAt)
	local texts, seen = {}, {}
	local from = startedAt - ns.DIAGNOSTICS_WINDOW
	for i = #self.spans, 1, -1 do
		local span = self.spans[i]
		if span.last < from or #texts == ns.DIAGNOSTICS_TEXTS then
			break
		end
		if span.first <= startedAt and not seen[span.text] then
			seen[span.text] = true
			texts[#texts + 1] = span.text
		end
	end
	return texts
end

--- One entry of `PagleDB.global.diagnostics`, for one recorded Cast (LOG-R81).
---@class PagleDiagnostic
---@field id string                         -- the Cast's entry ID
---@field zone integer                      -- the Cast's zone areaID, 0 if unresolved
---@field subzone integer                   -- the Cast's subzone areaID, 0 if none or unresolved
---@field locale string                     -- GetLocale()
---@field texts string[]                    -- hovered object texts, most recent first
---@field unresolved PagleUnresolvedAreas?  -- the zone and subzone texts, only when either didn't resolve
---@field devSkill integer?                 -- the rank `/pagle dev skill` had overridden the Cast's skill to (#465)

--- Adds `entry` at the end of the diagnostics buffer, dropping the oldest entries past `ns.DIAGNOSTICS_SIZE`
--- (LOG-R81).
---@param buffer PagleDiagnostic[]
---@param entry PagleDiagnostic
function ns.AddDiagnostic(buffer, entry)
	buffer[#buffer + 1] = entry
	while #buffer > ns.DIAGNOSTICS_SIZE do
		table.remove(buffer, 1)
	end
end
