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
---@field announce fun(announcement: PagleAnnouncement) -- hands an Announcement to the display (the lanes, ANN-R20)
---@field showCard fun(card: PagleCard): boolean -- puts a card on screen now; false while cards are held (ANN-R35)
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

--- The kinds `/pagle dev preview` shows, in the order it lists them.
ns.DEV_PREVIEW_KINDS = { "toast", "nod", "banner", "splash", "card" }

-- A sample moment as Core would hold it once raised (PagleRaisedMoment), from Core itself.
---@param moment table
---@return PagleRaisedMoment
local function sample(moment)
	moment.kind, moment.module, moment.moduleTitle, moment.moduleOrder, moment.raised =
		"devPreview", "Pagle", "Pagle", 0, 0
	return moment
end

-- Oily Blackmouth, a sample icon.
local ICON = 6358

--- The sample Announcement `/pagle dev preview <kind>` shows (#247), for a toast, Nod, banner or splash: a headline
--- of that rung, with stamps and Coins where the form shows them. Nil for another kind.
---@param kind string
---@return PagleAnnouncement?
function ns.DevPreviewAnnouncement(kind)
	local L = ns.L
	if kind == "toast" then
		return ns.MakeAnnouncement({
			sample({ rung = "toast", title = L.DEV_SAMPLE_TOAST, text = L.DEV_SAMPLE_TEXT, icon = ICON, coins = 10 }),
			sample({ rung = "toast.low", title = L.DEV_SAMPLE_STAMP, stamp = L.DEV_SAMPLE_STAMP, coins = 2 }),
		})
	elseif kind == "nod" then
		return ns.MakeAnnouncement({ sample({ rung = "nod", title = L.DEV_SAMPLE_NOD, text = L.DEV_SAMPLE_TEXT }) })
	elseif kind == "banner" then
		return ns.MakeAnnouncement({
			sample({ rung = "banner", title = L.DEV_SAMPLE_BANNER, text = L.DEV_SAMPLE_TEXT, coins = 20 }),
		})
	elseif kind == "splash" then
		return ns.MakeAnnouncement({
			sample({ rung = "splash", title = L.DEV_SAMPLE_SPLASH, text = L.DEV_SAMPLE_TEXT, icon = ICON, coins = 50 }),
		})
	end
	return nil
end

--- The sample Session summary card `/pagle dev preview card` shows (#247): Core's numbers, Coins, a line and moments.
--- It's marked `preview`, so showing it ends no waiting count, and closing it removes nothing.
---@return PagleCard
function ns.DevPreviewCard()
	local L = ns.L
	return {
		title = L.CARD_SESSION,
		preview = true,
		numbers = { casts = 24, catches = 21, gotAway = 3, seconds = 2580 },
		coins = 32,
		lines = { { module = "Pagle", title = "Pagle", lines = { L.DEV_SAMPLE_LINE } } },
		moments = {
			{
				module = "Pagle",
				title = "Pagle",
				order = 0,
				moments = {
					{ title = L.DEV_SAMPLE_BANNER, text = L.DEV_SAMPLE_TEXT },
					{ title = L.DEV_SAMPLE_TOAST, text = L.DEV_SAMPLE_TEXT, icon = ICON },
				},
			},
		},
	}
end

-- `/pagle dev preview [kind]`: a sample of the kind, through the real display, changing no saved state; the kinds
-- with none or an unknown one.
---@param dev PagleDevCommands
---@param kind string
local function preview(dev, kind)
	local L, options = ns.L, dev.options
	local announcement = ns.DevPreviewAnnouncement(kind)
	if announcement then
		options.announce(announcement)
		options.print(L.DEV_PREVIEWING:format(kind))
	elseif kind == "card" then
		options.print(options.showCard(ns.DevPreviewCard()) and L.DEV_PREVIEWING:format(kind) or L.DEV_CARD_HELD)
	else
		options.print(L.DEV_PREVIEW_KINDS:format(table.concat(ns.DEV_PREVIEW_KINDS, ", ")))
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
	elseif name == "preview" then
		preview(self, rest:lower())
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
