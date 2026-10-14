---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The diagnostics buffer (LOG-R80–R82): the world objects the player hovers, and one entry per recorded Cast in
-- PagleDB.global.diagnostics, for the Field report. It stays out of the Catch log and the sync rules (LOG-R82).

local hovers = ns.NewHoverLog()

-- The first line of a world object's tooltip, or nil if it has none or any step to it is secret (CORE-R31).
---@param data TooltipData
---@return string?
local function firstLine(data)
	if issecretvalue(data) or type(data) ~= "table" then
		return nil
	end
	local lines = data.lines
	if issecretvalue(lines) or type(lines) ~= "table" then
		return nil
	end
	local line = lines[1]
	if issecretvalue(line) or type(line) ~= "table" then
		return nil
	end
	local text = line.leftText
	if issecretvalue(text) or type(text) ~= "string" or text == "" then
		return nil
	end
	return text
end

-- Each world object the player hovers: its tooltip's first line, at GetTime() (LOG-R80).
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, function(_, data)
	local text = firstLine(data)
	if text then
		hovers:Hovered(text, GetTime())
	end
end)

--- Adds the diagnostics entry of a Cast just recorded (LOG-R81): its entry ID, zone and subzone, the client's
--- locale, the texts hovered in the 60 s before its channel started (before now for a Cast with no channel seen),
--- and the zone and subzone texts when either didn't resolve. ns.PAGLEDB_DEFAULTS gives a new PagleDB an empty
--- buffer; a saved one that isn't a table is started again, since it may be dropped (LOG-R82).
---@param cast PagleCast
---@param unresolved PagleUnresolvedAreas?
---@param startedAt number? GetTime() when the Cast's channel started
function ns.AddCastDiagnostic(cast, unresolved, startedAt)
	local global = ns.db.global
	---@cast global table -- AceDB always has a global section
	if type(global.diagnostics) ~= "table" then
		global.diagnostics = {}
	end
	ns.AddDiagnostic(global.diagnostics, {
		id = cast.id,
		zone = cast.conditions.zone,
		subzone = cast.conditions.subzone,
		locale = GetLocale(),
		texts = hovers:TextsBefore(startedAt or GetTime()),
		unresolved = unresolved,
	})
end
