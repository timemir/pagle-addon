---@class PagleNS
local ns = select(2, ...)

-- `/pagle dev …` (#247): hidden dev commands for fast exit checks, which `/pagle help` never lists. Pure logic over
-- what it's handed (CORE-R7); logic/Wiring.lua's ns.WireDev hands it Core's Sessions, fishing and PagleDB, so Core's
-- adapter and FakePagle run the same commands.

--- What the dev commands are fed. Every function is called when needed, never stored.
---@class PagleDevOptions
---@field global fun(): table          -- PagleDB.global, which keeps the `dev` switch
---@field testLog fun(): boolean       -- the Catch log is a test log (`PagleLog.test == true`)
---@field endSession fun(): boolean    -- ends the Session open now (LOG-R62); false when none is open
---@field area fun(areaID: integer): integer?, integer? -- the zone and subzone an areaID stands for; nil if unknown
---@field catch fun(itemID: integer, zone: integer?, subzone: integer?): PagleCast? -- records a synthetic caught Cast
---@field print fun(line: string)      -- prints a chat line

--- The dev commands.
---@class PagleDevCommands
---@field package options PagleDevOptions
local Dev = {}
Dev.__index = Dev

---@param options PagleDevOptions
---@return PagleDevCommands
function ns.NewDevCommands(options)
	return setmetatable({ options = options }, Dev)
end

-- `/pagle dev catch <itemID> [areaID]`: one caught Cast of one item, through Core's real append path, on a test log
-- only. The area defaults to the current one; a zone's areaID stands for the zone with no subzone, a subzone's for
-- itself in its zone.
---@param dev PagleDevCommands
---@param args string
local function catch(dev, args)
	local L, options = ns.L, dev.options
	local itemText, areaText = args:match("^(%S+)%s*(%S*)$")
	local itemID, areaID = tonumber(itemText or ""), tonumber(areaText)
	if
		not (itemText and itemText:match("^%d+$") and itemID > 0) or (areaText ~= "" and not areaText:match("^%d+$"))
	then
		options.print(L.DEV_CATCH_USAGE)
		return
	end
	---@cast itemID integer
	if not options.testLog() then
		options.print(L.DEV_REAL_LOG)
		return
	end
	local zone, subzone
	if areaID then
		zone, subzone = options.area(areaID)
		if not zone then
			options.print(L.DEV_UNKNOWN_AREA:format(areaText))
			return
		end
	end
	local cast = options.catch(itemID, zone, subzone)
	if cast then
		options.print(L.DEV_CAUGHT:format(itemID, cast.conditions.zone, cast.seq))
	else
		options.print(L.DEV_NO_CHARACTER)
	end
end

--- Runs `/pagle dev <args>`. `on` and `off` set `PagleDB.global.dev`; while it's off every other dev command prints
--- one line saying how to turn it on, and does nothing.
---@param args string what follows `/pagle dev`
function Dev:Run(args)
	local L, options = ns.L, self.options
	local name, rest = ns.ParseSlash(args)
	local global = options.global()
	if name == "on" or name == "off" then
		global.dev = name == "on"
		options.print(global.dev and L.DEV_ON or L.DEV_OFF)
	elseif not global.dev then
		options.print(L.DEV_IS_OFF)
	elseif name == "endsession" then
		options.print(options.endSession() and L.DEV_SESSION_ENDED or L.DEV_NO_SESSION)
	elseif name == "catch" then
		catch(self, rest)
	else
		options.print(L.DEV_USAGE)
	end
end

--- The zone and subzone `areaID` stands for in `catalogue` (LOG-R55): a zone with subzone 0, or a subzone in its
--- zone. Nil for an area outside the catalogue's slice.
---@param catalogue PagleCatalogue
---@param areaID integer
---@return integer? zone
---@return integer? subzone
function ns.DevArea(catalogue, areaID)
	local zone = catalogue.GetZoneOf(areaID)
	if not zone then
		return nil, nil
	end
	return zone, zone == areaID and 0 or areaID
end
