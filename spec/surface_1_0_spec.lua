-- The 1.0 surface, frozen at the release (roadmap.md › Before the tag, step 3): the `Pagle` API (CORE-R15), the
-- Catch log's format number and entry tags (LOG-R17, ADR 0003) and each DB's first schemaVersion (ADR 0003). Every
-- list below is what 1.0 shipped. A name removed or changed fails here, naming the rule; one added passes, so the
-- lists only ever grow (CORE-R15, LOG-R17: an additive change is a new name or a new tag, never an edit).
-- `ns.RULE_SET_ID` is left out on purpose: it names the shipped rule set and changes with each shipped rule change
-- (LOG-R36 logs a B1 when it does), so a release may bump it without breaking any log.

-- Fails naming `rule` and every item in `broken`, or passes if there are none.
local function expectNone(broken, rule, what)
	assert(#broken == 0, ("%s: 1.0 froze %s, but %s"):format(rule, what, table.concat(broken, "; ")))
end

-- A sorted copy of the keys of `set`.
local function names(set)
	local sorted = {}
	for name in pairs(set) do
		sorted[#sorted + 1] = name
	end
	table.sort(sorted)
	return sorted
end

--- What `Pagle` held on 5 November 2026, by name and Lua type: every function, and every field (CORE-R15).
local API = {
	API_VERSION = "number",
	Animate = "function",
	Bezier = "function",
	CONTENT_FINGERPRINT = "string",
	Cue = "function",
	DrawGoodPreview = "function",
	EASE = "table",
	FitToScreen = "function",
	FormatClock = "function",
	FormatLength = "function",
	GetActivityXP = "function",
	GetAngler = "function",
	GetArea = "function",
	GetBalance = "function",
	GetBindingLook = "function",
	GetClockFormat = "function",
	GetCompanionState = "function",
	GetConditions = "function",
	GetEarnedProgress = "function",
	GetEquipped = "function",
	GetFieldReportCount = "function",
	GetFishingState = "function",
	GetFollowedAnglers = "function",
	GetGood = "function",
	GetItem = "function",
	GetPrestigeFrame = "function",
	GetPushedContent = "function",
	GetPutAwayGoods = "function",
	GetSession = "function",
	GetSlotGoods = "function",
	GetSlots = "function",
	GetTestLogGrant = "function",
	GetTickets = "function",
	GetVarieties = "function",
	GetVarietiesCaught = "function",
	GetWindowSpec = "function",
	GetZoneCatches = "function",
	GetZoneOf = "function",
	GetZones = "function",
	IsAnimationsOn = "function",
	IsOwned = "function",
	IsRestricted = "function",
	IsUpdating = "function",
	IterateCatches = "function",
	MatchesConditions = "function",
	NewBook = "function",
	NewBookBinding = "function",
	NewLegendCrest = "function",
	NewPrestigeFrame = "function",
	NextWindow = "function",
	OpenFieldReport = "function",
	OpenPasteExport = "function",
	OpenSettings = "function",
	OpenShop = "function",
	PrestigeEmblemMarkup = "function",
	RegisterCallback = "function",
	RegisterEvent = "function",
	RegisterModule = "function",
	RegisterTrailerPart = "function",
	RegisterUnitEvent = "function",
	SESSION_GAP = "number",
	SESSION_RULES_VERSION = "number",
	SIZE_BANDS = "table",
	SIZE_RULES_VERSION = "number",
	SetEquipped = "function",
	SetPrestigeEmblem = "function",
	StopMotion = "function",
	UnregisterAllCallbacks = "function",
	UnregisterCallback = "function",
	UnregisterEvent = "function",
	VARIETY_RARITIES = "table",
	WheelScroll = "function",
}

--- The events Core fired on 5 November 2026 (CORE-R15, CORE-R20): each is fired by name in Core's own files.
local EVENTS = {
	"ActivityXPChanged",
	"AppearanceChanged",
	"BalanceChanged",
	"CastEnded",
	"CastStarted",
	"Catch",
	"ClockFormatChanged",
	"ConditionsChanged",
	"FishingStateChanged",
	"GuideClosed",
	"GuideOpened",
	"ModulesChanged",
	"Prestige",
	"PushedContentReady",
	"RestrictionChanged",
	"SessionEnded",
	"SessionStarted",
	"SkillChanged",
	"TicketsChanged",
}

--- The entry tags 1.0 shipped and the record kind each decodes to (LOG-R17, ADR 0003), each with an example entry from
--- catch-log.md. A Module record is read by its Module and a Companion entry by Core (LOG-R41, LOG-R37).
local TAGS = {
	{
		tag = "C1",
		kind = "cast",
		entry = "C1|1|1791731747|0|c|494|1439|1|148|453|86|25|263|||6358x1",
	},
	{ tag = "S1", kind = "skill", entry = "S1|1|1791731750|0|86|150|0" },
	{ tag = "P1", kind = "prestige", entry = "P1|1|1791731760|0|2|1850" },
	{ tag = "B1", kind = "build", entry = "B1|1|1791731770|0|70338|1.60.1|pagle-2026d" },
	{ tag = "U1", kind = "purchase", entry = "U1|1|1791731780|0|core.crest.plain|250" },
	{ tag = "A1", kind = "module", entry = "A1|1|1791731790|0|Ledger|title|title:level1", reader = "Ledger" },
	{ tag = "K1", kind = "companion", entry = "K1|1|1791731800|0|testKey|42", reader = "Core" },
}

--- Each DB's first schemaVersion, as 1.0 ships it: PagleDB's third migration step is the last of the dev steps, and
--- every Module's DB starts at 1 (ADR 0003). A later schema adds a step above these, never beneath.
local DBS = {
	{ variable = "PagleDB", addon = "Pagle", first = 3 },
	{ variable = "PagleLedgerDB", addon = "Pagle_Ledger", first = 1 },
	{ variable = "PagleHuntsDB", addon = "Pagle_Hunts", first = 1 },
	{ variable = "PagleStatsDB", addon = "Pagle_Stats", first = 1 },
	{ variable = "PagleTackleBoardDB", addon = "Pagle_TackleBoard", first = 1 },
	{ variable = "PagleQoLDB", addon = "Pagle_QoL", first = 1 },
}

describe("the 1.0 surface", function()
	describe("the Pagle API (CORE-R15)", function()
		local loaded = enterWorld(
			loadAddon("Pagle", foreverWith({ PagleLog = savedLog({ BUILD_ENTRY }) }), {
				also = { "Pagle_Ledger", "Pagle_Hunts", "Pagle_Stats", "Pagle_TackleBoard", "Pagle_QoL" },
			}),
			3
		)

		it("keeps every function and field 1.0 had, under its name and type; an addition passes", function()
			local broken = {}
			for _, name in ipairs(names(API)) do
				local now = type(loaded.env.Pagle[name])
				if now ~= API[name] then
					broken[#broken + 1] = ("Pagle.%s is %s, was %s"):format(name, now, API[name])
				end
			end
			expectNone(broken, "CORE-R15", "the Pagle API as additive only")
		end)

		it("is at API_VERSION 1 or later: it rises with each addition, never falls (CORE-R15)", function()
			local version = loaded.env.Pagle.API_VERSION
			assert(type(version) == "number" and version >= 1, "CORE-R15: Pagle.API_VERSION fell below 1")
			assert(version == math.floor(version), "CORE-R15: Pagle.API_VERSION is a whole number")
		end)

		it("fires every event 1.0 fired, by the name it had (CORE-R15, CORE-R20)", function()
			local sources = {}
			for _, file in ipairs(addonFiles("Pagle")) do
				if file:find("%.lua$") then
					sources[#sources + 1] = withoutComments(readFile("addons/Pagle/" .. file))
				end
			end
			local code = table.concat(sources, "\n")
			local broken = {}
			for _, event in ipairs(EVENTS) do
				if not (code:find('[Ff]ire%(%s*"' .. event .. '"')) then
					broken[#broken + 1] = ("Core no longer fires %s"):format(event)
				end
			end
			expectNone(broken, "CORE-R15", "the events Core fires")
		end)
	end)

	describe("the Catch log (LOG-R17, ADR 0003)", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		local ns = loaded.ns

		it("is format 3, the number PagleLog.format has held since 1.0 (LOG-R17, LOG-R18)", function()
			assert(
				ns.LOG_FORMAT == 3,
				"LOG-R17: the Catch log's format number was frozen at 3, but is " .. ns.LOG_FORMAT
			)
		end)

		it("reads every entry tag 1.0 wrote, into the record kind it had (LOG-R17)", function()
			local broken = {}
			for _, example in ipairs(TAGS) do
				local catchLog = ns.OpenCatchLog(savedLog({ example.entry }), {})
				local record = catchLog:Iterate(0, example.reader)()
				if not record then
					broken[#broken + 1] = ("%s no longer decodes (%s)"):format(example.tag, example.entry)
				elseif record.kind ~= example.kind then
					broken[#broken + 1] = ("%s decodes to a %s, was a %s"):format(
						example.tag,
						record.kind,
						example.kind
					)
				end
			end
			expectNone(broken, "LOG-R17", "the entry tags")
		end)
	end)

	describe("each DB's first schemaVersion (ADR 0003)", function()
		local loaded = enterWorld(
			loadAddon("Pagle", foreverWith({ PagleLog = savedLog({ BUILD_ENTRY }) }), {
				also = { "Pagle_Ledger", "Pagle_Hunts", "Pagle_Stats", "Pagle_TackleBoard", "Pagle_QoL" },
			}),
			3
		)

		it("is stored in a new DB at or above the first, under `global.schemaVersion`", function()
			local broken = {}
			for _, db in ipairs(DBS) do
				local saved = loaded.env[db.variable]
				local version = type(saved) == "table" and saved.global and saved.global.schemaVersion
				if type(version) ~= "number" or version < db.first then
					broken[#broken + 1] = ("%s stores schemaVersion %s, 1.0 stored %d"):format(
						db.variable,
						tostring(version),
						db.first
					)
				end
			end
			expectNone(broken, "ADR 0003", "each DB's first schemaVersion")
		end)

		it("keeps the DB of a 1.0 install as it is, never resetting it (ADR 0003)", function()
			local broken = {}
			local steps = loaded.namespaces.Pagle.PAGLEDB_MIGRATIONS
			if #steps < 3 then
				broken[#broken + 1] = ("PagleDB has %d migration steps, 1.0 had 3"):format(#steps)
			end
			local core = { global = { schemaVersion = 3, marker = "kept" } }
			loaded.namespaces.Pagle.Migrate(core, steps, { catchLog = loaded.namespaces.Pagle.catchLog })
			if core.global.marker ~= "kept" or core.global.schemaVersion < 3 then
				broken[#broken + 1] = "PagleDB at schemaVersion 3 loses its data or its version"
			end
			for _, db in ipairs(DBS) do
				local ns = loaded.namespaces[db.addon]
				if db.addon ~= "Pagle" then
					local global = { schemaVersion = db.first, marker = "kept" }
					ns.MigrateDB(global)
					if global.marker ~= "kept" or global.schemaVersion < db.first then
						broken[#broken + 1] = ("%s at schemaVersion %d loses its data or its version"):format(
							db.variable,
							db.first
						)
					end
				end
			end
			expectNone(broken, "ADR 0003", "each DB's first schemaVersion")
		end)
	end)
end)
