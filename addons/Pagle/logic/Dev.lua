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
---@field showGlyphs fun(fonts: PagleDevGlyphFont[], probe: string) -- shows `probe` once in each of `fonts`
---@field tour fun(args: string)        -- runs `/pagle dev tour <args>` (CORE-R66–R68, logic/Tour.lua)
---@field probe fun()                   -- runs `/pagle dev probe` (#261, logic/Probe.lua)
---@field onboarding fun(args: string)  -- runs `/pagle dev onboarding <args>` (ONB-R83, logic/Onboarding.lua)
---@field content fun(): string[]       -- `/pagle dev content`'s lines (PUSH-R14, logic/PushedContent.lua)
---@field views fun(): string[]         -- `/pagle dev views`' lines (VIEW-R12, logic/AnglersInGame.lua)
---@field showPaste fun(view: PaglePasteView) -- opens the export window with this view (PST-R60, logic/PasteExport.lua)
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
--- of that rung, with stamps and Coins where the form shows them. Nil for another kind. With `text`, its headline's
--- text reads that instead of the dev preview's line (the Field guide's Moments samples, ONB-R34).
---@param kind string
---@param text string?
---@return PagleAnnouncement?
function ns.DevPreviewAnnouncement(kind, text)
	local L = ns.L
	text = text or L.DEV_SAMPLE_TEXT
	if kind == "toast" then
		return ns.MakeAnnouncement({
			sample({ rung = "toast", title = L.DEV_SAMPLE_TOAST, text = text, icon = ICON, coins = 10 }),
			sample({ rung = "toast.low", title = L.DEV_SAMPLE_STAMP, stamp = L.DEV_SAMPLE_STAMP, coins = 2 }),
		})
	elseif kind == "nod" then
		return ns.MakeAnnouncement({ sample({ rung = "nod", title = L.DEV_SAMPLE_NOD, text = text }) })
	elseif kind == "banner" then
		return ns.MakeAnnouncement({
			sample({ rung = "banner", title = L.DEV_SAMPLE_BANNER, text = text, coins = 20 }),
		})
	elseif kind == "splash" then
		return ns.MakeAnnouncement({
			sample({ rung = "splash", title = L.DEV_SAMPLE_SPLASH, text = text, icon = ICON, coins = 50 }),
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

--- A sample Write-up card (ANN-R61), for `/pagle dev tour` (CORE-R68): one section of Core's. Marked `preview`, so
--- closing it removes no stored section.
---@return PagleCard
function ns.DevPreviewWriteUp()
	local L = ns.L
	return {
		title = L.CARD_WRITE_UP,
		preview = true,
		writeUp = {
			{
				module = "Pagle",
				order = 0,
				title = "Pagle",
				heading = L.DEV_SAMPLE_WRITE_UP,
				lines = { L.DEV_SAMPLE_LINE, L.DEV_SAMPLE_TEXT },
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

-- `/pagle dev glyphs` (#248): CORE-R9 allows only the characters the client's fonts have. These are the candidates
-- whose rendering is in question, by code point: en dash, em dash, ellipsis, curly single and double quotes,
-- bullet, middle dot, guillemets, multiplication sign, right arrow, star and tick. They're built from their code
-- points here, so no string literal in the package holds one (spec/glyphs_spec.lua).
local GLYPH_CODE_POINTS = {
	0x2013,
	0x2014,
	0x2026,
	0x2018,
	0x2019,
	0x201C,
	0x201D,
	0x2022,
	0x00B7,
	0x00AB,
	0x00BB,
	0x00D7,
	0x2192,
	0x2605,
	0x2713,
}

-- The UTF-8 bytes of code point `point`, below U+10000.
---@param point integer
---@return string
local function utf8(point)
	if point < 0x80 then
		return string.char(point)
	elseif point < 0x800 then
		return string.char(0xC0 + math.floor(point / 0x40), 0x80 + point % 0x40)
	end
	return string.char(0xE0 + math.floor(point / 0x1000), 0x80 + math.floor(point / 0x40) % 0x40, 0x80 + point % 0x40)
end

--- The glyph probe line: each candidate character after its code point in hex ("2013 –  2014 —  …"), so a box can
--- be told apart from its neighbours.
---@return string
function ns.DevGlyphProbe()
	local items = {}
	for i, point in ipairs(GLYPH_CODE_POINTS) do
		items[i] = ("%04X %s"):format(point, utf8(point))
	end
	return table.concat(items, "  ")
end

--- A font Pagle draws text in: a font object by name (`object`), or a font file (`file`), with what uses it.
---@class PagleDevGlyphFont
---@field object string?  -- a font object's name, such as "GameFontHighlight"
---@field file string?    -- a font file, such as Core's bundled faces, for a face no font object has
---@field usedBy string   -- what draws with it, for the probe's label

-- Where Core's bundled fonts are (adapter/Art.lua).
local ART_FONTS = "Interface\\AddOns\\Pagle\\media\\fonts\\"

--- Every font Pagle draws text in (#248), for `/pagle dev glyphs`: Core's frames and Settings rows (GameFont*, all
--- FRIZQT__ in enUS), chat and the Field report's text, QoL's key label, the Fish Journal's small capitals, and the
--- announcements' bundled faces (Caveat's other cuts have the same characters), which the art kits share.
---@type PagleDevGlyphFont[]
ns.DEV_GLYPH_FONTS = {
	{ object = "GameFontHighlight", usedBy = "Core's frames" },
	{ object = "ChatFontNormal", usedBy = "chat, the Field report's text" },
	{ object = "NumberFontNormalSmallGray", usedBy = "QoL's key label" },
	{ file = ART_FONTS .. "IMFeENsc28P.ttf", usedBy = "the Fish Journal's small capitals" },
	{ file = ART_FONTS .. "IMFeENrm28P.ttf", usedBy = "the announcements' print" },
	{ file = ART_FONTS .. "Caveat-SemiBold.ttf", usedBy = "the announcements' hand" },
	{ file = ART_FONTS .. "Marcellus-Regular.ttf", usedBy = "the announcements' gilt and stamps" },
	-- The Curio Shop's own face beside those three, which it shares (adapter/ShopArt.lua).
	{ file = ART_FONTS .. "IMFeENit28P.ttf", usedBy = "the Curio Shop's italic" },
}

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
	elseif name == "glyphs" then
		local probe = ns.DevGlyphProbe()
		options.print(L.DEV_GLYPHS_CHAT:format(probe))
		options.showGlyphs(ns.DEV_GLYPH_FONTS, probe)
		options.print(L.DEV_GLYPHS_SHOWN)
	elseif name == "tour" then
		options.tour(rest)
	elseif name == "probe" then
		options.probe()
	elseif name == "onboarding" then
		options.onboarding(rest)
	elseif name == "content" then
		for _, line in ipairs(options.content()) do
			options.print(line)
		end
	elseif name == "views" then
		for _, line in ipairs(options.views()) do
			options.print(line)
		end
	elseif name == "pastetest" then
		local view = rest:match("^%d+$") and ns.PasteTestView(tonumber(rest) --[[@as integer]])
		if view then
			options.showPaste(view)
			options.print(L.DEV_PASTE_TEST_SHOWN:format(view.testKB))
		else
			options.print(L.DEV_PASTE_TEST_USAGE:format(ns.PASTE_TEST_MIN_KB, ns.PASTE_TEST_MAX_KB))
		end
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
