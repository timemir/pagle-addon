-- What the Tackle Board never does (ADR 0001, tackle-board.md › Purpose and boundary). It reads only Core: never the
-- Catch log's SavedVariables or Core's, never another Module's DB, and it names no other Module, so it pays no Ledger XP
-- and never references a Hunt. It appends its Module records only from live code (TKB-R80): only
-- adapter/LiveStep.lua (the start, day and issue records) and adapter/Reroll.lua (the reroll and post records) may call
-- AppendRecord, and only adapter/Moments.lua, which reports the Coins, reports Activity XP (TKB-R65) and the Refreshes
-- spent (TKB-R58). And its logic/ reaches Core and the client only through ns.api and the seams (CORE-R7,
-- logic/Seams.lua): never Core's API, the Module handle, the DB or a timer itself. Checked over every file the Tackle
-- Board ships: each name below fails the spec wherever its code says it.

local DIR = "addons/Pagle_TackleBoard/"

local READS_ONLY_CORE = "ADR 0001: the Tackle Board reads Catches only through its projection"
local NO_CORE_DB = "ADR 0001: the Tackle Board never reads Core's SavedVariables"
local NO_MODULE = "ADR 0001: the Tackle Board names no other Module"
local NO_MODULE_DB = "ADR 0001: the Tackle Board never reads another Module's DB"
local ONLY_PAGLE_API = "ADR 0001: the Tackle Board reaches Core only through Pagle.*, never its AceAddon"
local LIVE_RECORDS = "TKB-R80: only adapter/LiveStep.lua and adapter/Reroll.lua append records"
local LOGIC_SEAMS = "CORE-R7: logic/ reaches Core and the client only through ns.api and the seams"
local XP_REPORTS = "TKB-R65: only adapter/Moments.lua, which reports the Coins, reports Activity XP"
local TICKET_REPORTS = "TKB-R58: only adapter/Moments.lua, which reports the Coins, reports the Refreshes spent"

-- The files that may append the Tackle Board's records (TKB-R80), relative to the addon folder.
local APPENDS = { ["adapter/LiveStep.lua"] = true, ["adapter/Reroll.lua"] = true }

-- The one file that may report Activity XP (TKB-R65) and the Refreshes spent (TKB-R58): the one that reports the
-- Coins (TKB-R63).
local REPORTS_XP = "adapter/Moments.lua"

-- Each forbidden thing: a Lua pattern over code with comments removed, and the rule it breaks.
local FORBIDDEN = {
	{ "%f[%w_]PagleLog%f[^%w_]", READS_ONLY_CORE },
	{ "%f[%w_]PagleDB%f[^%w_]", NO_CORE_DB },
}
-- Every other roster Module (CORE-R1): its addon (its AceAddon and its folder name), any global named after it, and
-- its DB.
for _, name in ipairs(newFakePagle().ns.MODULE_ROSTER) do
	if name ~= "TackleBoard" then
		FORBIDDEN[#FORBIDDEN + 1] = { "%f[%w_]Pagle_" .. name, NO_MODULE }
		FORBIDDEN[#FORBIDDEN + 1] = { "%f[%w_]Pagle" .. name .. "DB%f[^%w_]", NO_MODULE_DB }
	end
end
-- Any addon's AceAddon object, Core's among them: Core's own is reached only through its API (CORE-R6 lets the board
-- make its own with NewAddon).
FORBIDDEN[#FORBIDDEN + 1] = { "%f[%w_]GetAddon%s*%(", ONLY_PAGLE_API }
-- A Module record, however it's reached: M:AppendRecord, M.AppendRecord(M, …), M["AppendRecord"] or a local copy.
local APPEND = { "%f[%w_]AppendRecord%f[^%w_]", LIVE_RECORDS }
-- An Activity XP report, however it's reached: M:ReportXPEarned, M["ReportXPEarned"](M, …) or a local copy.
local REPORT_XP = { "%f[%w_]ReportXPEarned%f[^%w_]", XP_REPORTS }
-- A Refreshes-spent report, however it's reached: M:ReportTicketsSpent, M["ReportTicketsSpent"](M, …) or a local copy.
local REPORT_TICKETS = { "%f[%w_]ReportTicketsSpent%f[^%w_]", TICKET_REPORTS }

-- What logic/ never reaches itself (logic/Seams.lua): Core's API (ns.api.pagle instead; the CORE-R11 guard is a bare
-- `Pagle`), the Module handle, the DB and the client's timers.
local LOGIC_FORBIDDEN = {
	{ "%f[%w_]Pagle%s*[%.:%[]", LOGIC_SEAMS },
	{ "%f[%w_]ns%.Module%f[^%w_]", LOGIC_SEAMS },
	{ "%f[%w_]ns%.db%f[^%w_]", LOGIC_SEAMS },
	{ "%f[%w_]C_Timer%f[^%w_]", LOGIC_SEAMS },
}

-- Each forbidden thing the code of `file` (relative to the addon folder) says, as "<why>: <match>".
---@param file string
---@param text string
---@return string[]
local function offences(file, text)
	local forbidden = { unpack(FORBIDDEN) }
	if not APPENDS[file] then
		forbidden[#forbidden + 1] = APPEND
	end
	if file ~= REPORTS_XP then
		forbidden[#forbidden + 1] = REPORT_XP
		forbidden[#forbidden + 1] = REPORT_TICKETS
	end
	if file:match("^logic/") then
		for _, rule in ipairs(LOGIC_FORBIDDEN) do
			forbidden[#forbidden + 1] = rule
		end
	end
	return forbiddenIn(withoutComments(text), forbidden)
end

describe("the Tackle Board's boundary (ADR 0001, TKB-R80)", function()
	it("covers every file the Tackle Board ships", function()
		assert.are.equal(#addonFiles("Pagle_TackleBoard"), #shippedFiles(DIR))
	end)

	for _, path in ipairs(shippedFiles(DIR)) do
		it(path .. " reads only Core, names no other Module and appends records only from live code", function()
			-- ADR 0001, TKB-R80
			assert.are.same({}, offences(path:sub(#DIR + 1), readFile(path)))
		end)
	end

	describe("catches", function()
		local planted = {
			{ "logic/Generate.lua", "local log = PagleLog", READS_ONLY_CORE },
			{ "logic/Projection.lua", "local entries = _G.PagleLog.entries", READS_ONLY_CORE },
			{ "adapter/TackleBoard.lua", "local db = PagleDB", NO_CORE_DB },
			{ "logic/Progress.lua", "local ledger = PagleLedgerDB.global.celebrated", NO_MODULE_DB },
			{ "logic/Generate.lua", "local pins = PagleHuntsDB.profile.pins", NO_MODULE_DB },
			{ "adapter/Tracker.lua", "local watched = PagleStatsDB.profile.watched", NO_MODULE_DB },
			{ "logic/Words.lua", "local lease = PagleQoLDB.global.lease", NO_MODULE_DB },
			{ "adapter/TackleBoard.lua", 'C_AddOns.IsAddOnLoaded("Pagle_Stats")', NO_MODULE },
			{ "adapter/TackleBoard.lua", 'LibStub("AceAddon-3.0"):GetAddon("Pagle_Ledger")', NO_MODULE },
			{ "adapter/Board.lua", 'local core = LibStub("AceAddon-3.0"):GetAddon("Pagle")', ONLY_PAGLE_API },
			{ "logic/Completions.lua", 'local hunts = _G["Pagle_Hunts"]', NO_MODULE },
			{ "adapter/Board.lua", "Pagle_QoL_Toggle()", NO_MODULE },
			{ "logic/Generate.lua", 'ns.Module:AppendRecord("issue", payload)', LIVE_RECORDS },
			{ "logic/Projection.lua", 'M.AppendRecord(M, "day", payload)', LIVE_RECORDS },
			{ "logic/Seams.lua", 'M["AppendRecord"](M, "start", payload)', LIVE_RECORDS },
			{ "adapter/TackleBoard.lua", "local append = M.AppendRecord", LIVE_RECORDS },
			{ "logic/LiveStep.lua", 'ns.Module:AppendRecord("start", payload)', LIVE_RECORDS },
			{ "logic/Words.lua", "local conditions = Pagle.GetConditions()", LOGIC_SEAMS },
			{ "logic/Pins.lua", "Pagle:GetSession()", LOGIC_SEAMS },
			{ "logic/Moments.lua", "ns.Module:RaiseMoment(moment)", LOGIC_SEAMS },
			{ "logic/Moments.lua", "local set = ns.db.global.celebrated", LOGIC_SEAMS },
			{ "logic/Tracker.lua", "C_Timer.After(3, done)", LOGIC_SEAMS },
			{ "adapter/LiveStep.lua", "ns.Module:ReportXPEarned(ns.State().xp)", XP_REPORTS },
			{ "logic/Projection.lua", 'M["ReportXPEarned"](M, state.xp)', XP_REPORTS },
			{ "adapter/TackleBoard.lua", "local report = M.ReportXPEarned", XP_REPORTS },
			{ "adapter/Reroll.lua", "ns.Module:ReportTicketsSpent(ns.State().ticketsSpent)", TICKET_REPORTS },
			{ "logic/Projection.lua", 'M["ReportTicketsSpent"](M, state.ticketsSpent)', TICKET_REPORTS },
		}
		for _, case in ipairs(planted) do
			it(case[2] .. " in " .. case[1], function()
				local found = offences(case[1], case[2])

				assert.is_true(#found > 0)
				assert.are.equal(case[3], found[1]:sub(1, #case[3]))
			end)
		end

		it("but not an AppendRecord in adapter/LiveStep.lua or adapter/Reroll.lua (TKB-R80)", function()
			assert.are.same({}, offences("adapter/LiveStep.lua", 'ns.Module:AppendRecord("start", payload)'))
			assert.are.same({}, offences("adapter/Reroll.lua", 'ns.Module:AppendRecord("reroll", payload)'))
			assert.are.same({}, offences("adapter/Reroll.lua", 'ns.Module:AppendRecord("post", payload)'))
		end)

		it("but not a ReportTicketsSpent in adapter/Moments.lua, beside ReportCoinsEarned (TKB-R58)", function()
			assert.are.same(
				{},
				offences(
					"adapter/Moments.lua",
					"module:ReportCoinsEarned(c)\nmodule:ReportTicketsSpent(ns.State().ticketsSpent)"
				)
			)
		end)

		it("but not a ReportXPEarned in adapter/Moments.lua, beside ReportCoinsEarned (TKB-R65)", function()
			assert.are.same(
				{},
				offences(
					"adapter/Moments.lua",
					"module:ReportCoinsEarned(ns.State().coins)\nmodule:ReportXPEarned(ns.State().xp)"
				)
			)
		end)

		it(
			"nor in logic/ the CORE-R11 guard, ns.api.pagle, ns.ModuleDef or ns.DB_DEFAULTS (CORE-R7, CORE-R11)",
			function()
				assert.are.same(
					{},
					offences(
						"logic/Words.lua",
						"if not Pagle then return end\nlocal z = ns.api.pagle.GetConditions()\n"
							.. "local def = ns.ModuleDef()\nlocal d = ns.DB_DEFAULTS"
					)
				)
			end
		)

		it("nor Core's API, the Module handle, the DB or a timer in adapter/ (CORE-R7 is logic/'s)", function()
			assert.are.same(
				{},
				offences(
					"adapter/Moments.lua",
					"Pagle.GetSession()\nns.Module:RaiseMoment(m)\nlocal db = ns.db\nC_Timer.After(0, step)"
				)
			)
		end)

		it(
			"nor what only a comment says, nor the Tackle Board's own PagleTackleBoardDB and Pagle_TackleBoard",
			function()
				assert.are.same(
					{},
					offences(
						"logic/Seams.lua",
						"-- never PagleLog, never M:AppendRecord\n--[[ PagleLedgerDB ]]\n"
							.. 'local db = PagleTackleBoardDB\nlocal _ = "Pagle_TackleBoard"'
					)
				)
			end
		)

		it("nor the Core calls tackle-board.md › Contracts lists (ADR 0001 allows Core)", function()
			assert.are.same(
				{},
				offences(
					"adapter/Moments.lua",
					'M:RaiseMoment(moment)\nM:SetSummaryLine("board", text)\nM:RaiseWriteUp(section)\n'
						.. "M:ReportCoinsEarned(60)\nlocal p = M:NewProjection(def)\nlocal a = Pagle.GetAngler()"
				)
			)
		end)
	end)
end)
