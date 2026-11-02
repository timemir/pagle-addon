-- The 1.0 surface, frozen at the release (roadmap.md › Before the tag, step 3): the `Pagle` API and the Module
-- handle (CORE-R15), the events Core fires and their payloads, the Catch log's format number and entry tags with their
-- fields (LOG-R17, ADR 0003) and each DB's first schemaVersion (ADR 0003). Every list below is what 1.0 shipped. A name,
-- field or shape removed or changed fails here, naming the rule. A name added passes only with `Pagle.API_VERSION`
-- above 1 (CORE-R15: it "rises by one with each addition"), so the lists only ever grow, and each growth is a bump.
-- `ns.RULE_SET_ID` is left out on purpose: it names the shipped rule set and changes with each shipped rule change
-- (LOG-R36 logs a B1 when it does), so a release may bump it without breaking any log.

-- The Catch log's format number (LOG-R17, LOG-R18) is this one constant: 1.0 ships format 4, the block store (LOG-R103).
-- A later change of format changes it and `openLog` and `storedEntries` below, which hold the way the entries are
-- stored; GOLDEN's `stored` entries are the entry encoding (LOG-R11), and the decoded fields stay.
local LOG_FORMAT = 4

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

--- Names on `Pagle` that are not API (CORE-R15 binds only what core/README.md lists, and the topic files it links):
--- `GetTestLogGrant` reads a test log's grants (catch-log.md › Test logs: "on a player's log the fields mean nothing"),
--- and `RegisterTrailerPart` is the development-only recording adapters' hook (adapter/Trailer.lua), in no spec file.
--- Neither is frozen, and neither needs an API_VERSION bump to change or go.
local INTERNAL = { GetTestLogGrant = true, RegisterTrailerPart = true }

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
	VERSION = "string",
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

--- The Module handle's methods (core/README.md › Module handle), every one the spec lists as API, `RegisterLetter` and
--- `ShowLetter` among them (onboarding.md).
local HANDLE = {
	"AddSetting",
	"AppendRecord",
	"CompleteEveningItem",
	"IterateCatches",
	"NewProjection",
	"RaiseMoment",
	"RaiseWriteUp",
	"RecordPrestige",
	"RefreshGoods",
	"RegisterFirstLook",
	"RegisterGood",
	"RegisterGuideStep",
	"RegisterLetter",
	"RegisterSlot",
	"RegisterTourStop",
	"RegisterTracker",
	"ReportCoinsEarned",
	"ReportTicketsEarned",
	"ReportTicketsSpent",
	"ReportXPEarned",
	"SetDialogOpen",
	"SetSummaryLine",
	"ShowFirstLook",
	"ShowLetter",
	"ShowMarginNote",
}

--- The shape of what each event passes after its name (CORE-R15, CORE-R20): one entry per argument, a Lua type name
--- or, for a table, the fields it holds and their types. Where a flow below reaches the event, the live payload must
--- hold every one of them (more fields pass).
local PAYLOADS = {
	ModulesChanged = {},
	PushedContentReady = { "string" },
	BalanceChanged = { { balance = "number", earned = "table", held = "boolean" } },
	SkillChanged = {
		{
			char = "number",
			id = "string",
			kind = "string",
			max = "number",
			mod = "number",
			rank = "number",
			seq = "number",
			time = "number",
		},
	},
	CastStarted = {},
	FishingStateChanged = { "string" },
	SessionStarted = {
		{
			id = "string",
			startTime = "number",
			endTime = "number",
			firstSeq = "number",
			lastSeq = "number",
			casts = "number",
			catches = "number",
			gotAway = "number",
			characters = "table",
			zones = "table",
		},
	},
	Catch = {
		{
			cast = "table",
			catchId = "string",
			itemID = "number",
			n = "number",
			quantity = "number",
			size = "table",
			variety = "table",
		},
	},
	CastEnded = {
		"string",
		{
			id = "string",
			kind = "string",
			outcome = "string",
			conditions = "table",
			items = "table",
			session = "string",
			seq = "number",
			char = "number",
			time = "number",
		},
	},
	RestrictionChanged = { "boolean" },
	GuideOpened = {},
}

--- The handler signature of every event Core documents one for, as it stands in Core's annotations: the payloads the
--- flows below cannot reach (a Prestige, a Session's end, the clock format, the Refresh tickets) are held by these.
--- `GuideClosed` passes the step it was on (onboarding.md › Contracts) and has no alias.
local SIGNATURES = {
	'fun(event: "ActivityXPChanged", entry: PagleRecord?)',
	'fun(event: "AppearanceChanged", slot: string, goodID: string)',
	'fun(event: "BalanceChanged", balance: Balance)',
	'fun(event: "CastEnded", outcome: "caught"|"gotAway"|"interrupted", cast: PagleCast?)',
	'fun(event: "CastStarted")',
	'fun(event: "Catch", catch: PagleCatch)',
	'fun(event: "ClockFormatChanged", format: PagleClockFormat)',
	'fun(event: "ConditionsChanged", changedKeys: PagleConditionKey[])',
	'fun(event: "FishingStateChanged", state: PagleFishingState)',
	'fun(event: "ModulesChanged")',
	'fun(event: "Prestige", record: PaglePrestige)',
	'fun(event: "PushedContentReady", state: PagleCompanionState)',
	'fun(event: "RestrictionChanged", isRestricted: boolean)',
	'fun(event: "SessionEnded", session: PagleSession)',
	'fun(event: "SessionStarted", session: PagleSession)',
	'fun(event: "SkillChanged", reading: PagleSkillReading)',
	'fun(event: "TicketsChanged", tickets: PagleTickets)',
}

--- An example entry of each tag 1.0 shipped (LOG-R17, ADR 0003), the record it decodes to (`fields`: every one must be
--- there, under that name and value; `reader` is who is handed it, LOG-R41 and LOG-R37) and the record that appends it
--- back (`record`, by default the same fields). Decoding, then appending the decoded fields, round-trips: a reordered
--- or renamed field fails one or the other.
local GOLDEN = {
	{
		tag = "C1",
		stored = "C1|1|1791731747|0|c|494|1439|1|148|453|86|25|263|12,301|8087|6358x1,6303x2",
		fields = {
			kind = "cast",
			char = 1,
			time = 1791731747,
			outcome = "caught",
			conditions = {
				minute = 494,
				uiMap = 1439,
				instance = 1,
				zone = 148,
				subzone = 453,
				skillRank = 86,
				skillMod = 25,
				lure = 263,
				events = { 12, 301 },
				auras = { 8087 },
			},
			items = { { n = 1, itemID = 6358, quantity = 1 }, { n = 2, itemID = 6303, quantity = 2 } },
		},
		record = {
			kind = "cast",
			char = 1,
			time = 1791731747,
			outcome = "caught",
			conditions = {
				minute = 494,
				uiMap = 1439,
				instance = 1,
				zone = 148,
				subzone = 453,
				skillRank = 86,
				skillMod = 25,
				lure = 263,
				events = { 12, 301 },
				auras = { 8087 },
			},
			items = { { itemID = 6358, quantity = 1 }, { itemID = 6303, quantity = 2 } },
		},
	},
	{
		tag = "S1",
		stored = "S1|1|1791731750|0|86|150|-3",
		fields = { kind = "skill", char = 1, time = 1791731750, rank = 86, max = 150, mod = -3 },
	},
	{
		tag = "P1",
		stored = "P1|1|1791731760|0|2|1850",
		fields = { kind = "prestige", char = 1, time = 1791731760, rank = 2, activityXP = 1850 },
	},
	{
		tag = "B1",
		stored = "B1|1|1791731770|0|70338|1.60.1|pagle-2026a",
		fields = {
			kind = "build",
			char = 1,
			time = 1791731770,
			build = 70338,
			version = "1.60.1",
			rules = "pagle-2026a",
		},
	},
	{
		tag = "U1",
		stored = "U1|1|1791731780|0|core.crest.plain|250",
		fields = { kind = "purchase", char = 1, time = 1791731780, good = "core.crest.plain", price = 250 },
	},
	{
		tag = "A1",
		stored = "A1|1|1791731790|0|Ledger|title|title:level1",
		reader = "Ledger",
		fields = {
			kind = "module",
			char = 1,
			time = 1791731790,
			module = "Ledger",
			recordKind = "title",
			payload = "title:level1",
		},
	},
	{
		tag = "K1",
		stored = "K1|1|1791731800|0|testKey|42",
		reader = "Core",
		fields = { kind = "companion", char = 1, time = 1791731800, keyId = "testKey", pushedSeq = 42 },
	},
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

-- Every field of `expected` is in `actual` under the same name, value and nested shape; `actual` may hold more.
local function missingFields(expected, actual, path, problems)
	problems = problems or {}
	if type(expected) ~= "table" then
		if expected ~= actual then
			problems[#problems + 1] = ("%s is %s, was %s"):format(path, tostring(actual), tostring(expected))
		end
	elseif type(actual) ~= "table" then
		problems[#problems + 1] = ("%s is %s, was a table"):format(path, tostring(actual))
	else
		for key, value in pairs(expected) do
			missingFields(value, actual[key], path .. "." .. tostring(key), problems)
		end
	end
	return problems
end

-- Every field a payload shape names is in `value`, with its Lua type; a table shape holds its fields' types.
local function payloadProblems(event, shape, args)
	local problems = {}
	for i, want in ipairs(shape) do
		local got = args[i]
		if type(want) == "string" then
			if type(got) ~= want then
				problems[#problems + 1] = ("%s's argument %d is %s, was %s"):format(event, i, type(got), want)
			end
		elseif type(got) ~= "table" then
			problems[#problems + 1] = ("%s's argument %d is %s, was a table"):format(event, i, type(got))
		else
			for field, kind in pairs(want) do
				if type(got[field]) ~= kind then
					problems[#problems + 1] = ("%s's argument %d has %s as %s, was %s"):format(
						event,
						i,
						field,
						type(got[field]),
						kind
					)
				end
			end
		end
	end
	return problems
end

-- Core's own Lua files, as text with their comments (the annotations are in them) and without.
local function coreSources()
	local raw, code = {}, {}
	for _, file in ipairs(addonFiles("Pagle")) do
		if file:find("%.lua$") and not file:find("^libs") then
			local text = readFile("addons/Pagle/" .. file)
			raw[#raw + 1] = text
			code[#code + 1] = withoutComments(text)
		end
	end
	return table.concat(raw, "\n"), table.concat(code, "\n")
end

-- The log as the client loads it from SavedVariables, holding `entries` in its storage for LOG_FORMAT (format 4's
-- blocks, packed by savedLog).
local function openLog(ns, entries)
	return ns.OpenCatchLog(savedLog(entries, LOG_FORMAT), {})
end

-- The entries a log holds in its storage, as a list of the strings GOLDEN's `stored` are: each block split at its line
-- feeds.
local function storedEntries(catchLog)
	return logEntries(catchLog.data)
end

describe("the 1.0 surface", function()
	describe("the Pagle API (CORE-R15)", function()
		local loaded = enterWorld(
			loadAddon("Pagle", foreverWith({ PagleLog = savedLog({ BUILD_ENTRY }) }), {
				also = { "Pagle_Ledger", "Pagle_Hunts", "Pagle_Stats", "Pagle_TackleBoard", "Pagle_QoL" },
			}),
			3
		)
		local Pagle = loaded.env.Pagle

		-- CORE-R15: an addition raises API_VERSION by one, so any name beyond the lists needs a version above 1.
		local function requireBumpFor(additions, what)
			assert(
				#additions == 0 or Pagle.API_VERSION > 1,
				("CORE-R15: %s gained %s but API_VERSION is still 1; an addition raises it by one"):format(
					what,
					table.concat(additions, ", ")
				)
			)
		end

		it("keeps every function and field 1.0 had, under its name and type", function()
			local broken = {}
			for _, name in ipairs(names(API)) do
				local now = type(Pagle[name])
				if now ~= API[name] then
					broken[#broken + 1] = ("Pagle.%s is %s, was %s"):format(name, now, API[name])
				end
			end
			expectNone(broken, "CORE-R15", "the Pagle API as additive only")
		end)

		it("needs API_VERSION above 1 for any name added to Pagle (CORE-R15)", function()
			local added = {}
			for name in pairs(Pagle) do
				if API[name] == nil and not INTERNAL[name] then
					added[#added + 1] = name
				end
			end
			table.sort(added)
			requireBumpFor(added, "Pagle")
		end)

		it(
			"carries Core's TOC version as Pagle.VERSION, a string set when the API is built (core/README.md)",
			function()
				local tocLoad = loadAddon("Pagle", FOREVER_GLOBALS, { holdAddonLoaded = true })
				assert(type(tocLoad.env.Pagle.VERSION) == "string", "CORE-R15: Pagle.VERSION is no string")
				-- The fake client serves the TOC's own field, which a development checkout reads unfilled.
				assert(
					tocLoad.env.Pagle.VERSION == tocLoad.client.addons.Pagle.metadata.Version,
					"CORE-R15: Pagle.VERSION is not the TOC's Version"
				)
				assert(tocLoad.env.Pagle.VERSION ~= "", "CORE-R15: Pagle.VERSION is empty")
			end
		)

		it("is at API_VERSION 1 or later: it rises with each addition, never falls (CORE-R15)", function()
			local version = Pagle.API_VERSION
			assert(type(version) == "number" and version >= 1, "CORE-R15: Pagle.API_VERSION fell below 1")
			assert(version == math.floor(version), "CORE-R15: Pagle.API_VERSION is a whole number")
		end)

		it(
			"gives a Module handle every method 1.0 had, and needs API_VERSION above 1 for one more (CORE-R12, CORE-R15)",
			function()
				local freshCore = loadCore()
				local handle =
					assert(freshCore.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 }))
				local broken, added, known = {}, {}, {}
				for _, name in ipairs(HANDLE) do
					known[name] = true
					if type(handle[name]) ~= "function" then
						broken[#broken + 1] = ("M:%s is %s"):format(name, type(handle[name]))
					end
				end
				for name in pairs(getmetatable(handle).__index) do
					if not known[name] and name ~= "__index" then
						added[#added + 1] = name
					end
				end
				table.sort(added)
				expectNone(broken, "CORE-R15", "the Module handle's methods")
				requireBumpFor(added, "the Module handle")
			end
		)

		it(
			"fires every event 1.0 fired, by the name it had; one more needs API_VERSION above 1 (CORE-R15, CORE-R20)",
			function()
				local _, code = coreSources()
				local broken, added, known = {}, {}, {}
				for _, event in ipairs(EVENTS) do
					known[event] = true
					if not code:find('[Ff]ire%(%s*"' .. event .. '"') then
						broken[#broken + 1] = ("Core no longer fires %s"):format(event)
					end
				end
				for event in code:gmatch('[Ff]ire%(%s*"(%u%w+)"') do
					if not known[event] then
						known[event] = true
						added[#added + 1] = event
					end
				end
				table.sort(added)
				expectNone(broken, "CORE-R15", "the events Core fires")
				requireBumpFor(added, "the events")
			end
		)

		it("keeps the signature of every event handler that has one (CORE-R15, CORE-R20)", function()
			local raw = coreSources()
			local broken = {}
			for _, signature in ipairs(SIGNATURES) do
				if not raw:find("---@alias Pagle%w+Handler " .. signature:gsub("%p", "%%%0")) then
					broken[#broken + 1] = signature .. " is gone or changed"
				end
			end
			expectNone(broken, "CORE-R15", "the events' payloads")
		end)

		it("passes the payload 1.0 passed with each event a login and a Cast reach (CORE-R15, CORE-R20)", function()
			local flow = loadAddon("Pagle", foreverWith({ PagleLog = savedLog({ BUILD_ENTRY }) }), {
				also = { "Pagle_Ledger", "Pagle_Hunts", "Pagle_Stats", "Pagle_TackleBoard", "Pagle_QoL" },
			})
			local first = {}
			for _, event in ipairs(EVENTS) do
				flow.env.Pagle.RegisterCallback("Surface " .. event, event, function(_, ...)
					first[event] = first[event] or { n = select("#", ...), ... }
				end)
			end
			enterWorld(flow, 3)
			catchOne(flow)
			flow.client.advance(0)
			setCombat(flow, true)
			setCombat(flow, false)
			flow.env.SlashCmdList.PAGLE("guide")
			flow.client.advance(1)

			local broken = {}
			for _, event in ipairs(names(PAYLOADS)) do
				local args = first[event]
				if not args then
					broken[#broken + 1] = ("%s was not fired by a login, a Cast and the guide"):format(event)
				else
					for _, problem in ipairs(payloadProblems(event, PAYLOADS[event], args)) do
						broken[#broken + 1] = problem
					end
				end
			end
			expectNone(broken, "CORE-R15", "the events' payloads")
		end)
	end)

	describe("the Catch log (LOG-R17, ADR 0003)", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		local ns = loaded.ns

		it("is the format number 1.0 shipped, " .. LOG_FORMAT .. " (LOG-R17, LOG-R18)", function()
			assert(
				ns.LOG_FORMAT == LOG_FORMAT,
				("LOG-R17: the Catch log's format number was frozen at %d, but is %s"):format(
					LOG_FORMAT,
					tostring(ns.LOG_FORMAT)
				)
			)
		end)

		it("decodes an example of every entry tag 1.0 wrote into the fields it had (LOG-R17)", function()
			local broken = {}
			for _, golden in ipairs(GOLDEN) do
				local record = openLog(ns, { golden.stored }):Iterate(0, golden.reader)()
				if not record then
					broken[#broken + 1] = ("%s no longer decodes (%s)"):format(golden.tag, golden.stored)
				else
					for _, problem in ipairs(missingFields(golden.fields, record, golden.tag)) do
						broken[#broken + 1] = problem
					end
				end
			end
			expectNone(broken, "LOG-R17", "the entry tags and their fields")
		end)

		it("appends the decoded fields of every tag back into the entry it came from (LOG-R17)", function()
			local broken = {}
			for _, golden in ipairs(GOLDEN) do
				local catchLog = openLog(ns, {})
				local ok, problem = pcall(catchLog.Append, catchLog, golden.record or golden.fields)
				local stored = ok and storedEntries(catchLog)[1]
				if not ok then
					broken[#broken + 1] = ("%s no longer encodes: %s"):format(golden.tag, tostring(problem))
				elseif stored ~= golden.stored then
					broken[#broken + 1] = ("%s encodes as %s, was %s"):format(
						golden.tag,
						tostring(stored),
						golden.stored
					)
				end
			end
			expectNone(broken, "LOG-R17", "the entry tags and their fields")
		end)
	end)

	describe("the block store of format 4 (LOG-R17, LOG-R103, LOG-R104, LOG-R105)", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		local ns = loaded.ns
		local E1, E2, E3 = "S1|1|1791731750|0|86|150|0", "S1|1|1791731751|0|87|150|0", "S1|1|1791731752|0|88|150|0"

		-- A format 4 log written out by hand, the way the client would hand it back: three entries, two to a block.
		local function ownLog()
			return {
				format = LOG_FORMAT,
				logId = "3f9a2c1e7b0d4a65",
				characters = savedLog().characters,
				blockSize = 2,
				count = 3,
				blocks = { E1 .. "\n" .. E2, E3 },
			}
		end

		it("keeps its entries in `blockSize`, `count` and `blocks`, line-feed-joined, as 1.0 wrote them", function()
			local data = ownLog()
			assert(ns.LogBlocks.Problem(data) == nil, "LOG-R103: a log laid out as 1.0 wrote it no longer opens")
			local catchLog = ns.OpenCatchLog(data, {})
			assert(
				catchLog:Count() == 3 and catchLog:Get(1) == E1 and catchLog:Get(2) == E2 and catchLog:Get(3) == E3,
				"LOG-R103: entry seq is line (seq - 1) % blockSize + 1 of block (seq - 1) // blockSize + 1, no longer"
			)
			assert.are.same({ E1, E2, E3 }, storedEntries(catchLog))
		end)

		it("appends into the open block with a line feed, then into a new block once it is full (LOG-R103)", function()
			local data = ownLog()
			local catchLog = ns.OpenCatchLog(data, {})
			catchLog:Append({ kind = "skill", char = 1, time = 1791731753, rank = 89, max = 150, mod = 0 })
			catchLog:Append({ kind = "skill", char = 1, time = 1791731754, rank = 90, max = 150, mod = 0 })
			assert(
				data.count == 5 and #data.blocks == 3 and data.blockSize == 2,
				"LOG-R103: count, blockSize and blocks no longer move as 1.0's did"
			)
			assert(
				data.blocks[2] == E3 .. "\nS1|1|1791731753|0|89|150|0"
					and data.blocks[3] == "S1|1|1791731754|0|90|150|0",
				"LOG-R103: blocks are no longer joined by a line feed with no trailing one"
			)
			assert(data.format == LOG_FORMAT, "LOG-R17: an append changed the log's format")
		end)

		it(
			"reserves a first byte below 0x20 and refuses the entries that would leave a log unreadable (LOG-R104)",
			function()
				local reserved = ownLog()
				reserved.blocks[2] = "\1" .. E3
				assert(
					ns.LogBlocks.Problem(reserved) ~= nil,
					"LOG-R104: a block starting with a byte below 0x20 is readable"
				)
				local broken = {}
				for what, entry in pairs({
					["a line feed"] = E1 .. "\n" .. E2,
					["nothing"] = "",
					["a control byte"] = "\1" .. E1,
				}) do
					local data = ownLog()
					if pcall(ns.LogBlocks.Append, data, entry) or data.count ~= 3 then
						broken[#broken + 1] = ("an entry of %s is appended"):format(what)
					end
				end
				expectNone(broken, "LOG-R104", "the block store's refusals")
			end
		)

		it("packs a log whole with LogBlocks.Pack, `blockSize` to a block (LOG-R105)", function()
			local blocks, count = ns.LogBlocks.Pack({ E1, E2, E3 }, 2)
			assert.are.same({ E1 .. "\n" .. E2, E3 }, blocks)
			assert.are.equal(3, count)
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
