-- What the Tackle Board never does (ADR 0001, tackle-board.md › Purpose and boundary). It reads only Core: never the
-- Catch log's SavedVariables or Core's, never another Module's DB, and it names no other Module, so it pays no Ledger XP
-- and never references a Hunt. And it appends its Module records only from live code (TKB-R80): only
-- logic/LiveStep.lua (the start, day and issue records, #233) and logic/Reroll.lua (the reroll record, #234) may call
-- AppendRecord. Checked over every file the Tackle Board ships: each name below fails the spec wherever its code says
-- it.

local DIR = "addons/Pagle_TackleBoard/"

local READS_ONLY_CORE = "ADR 0001: the Tackle Board reads Catches only through its projection"
local NO_CORE_DB = "ADR 0001: the Tackle Board never reads Core's SavedVariables"
local NO_MODULE = "ADR 0001: the Tackle Board names no other Module"
local NO_MODULE_DB = "ADR 0001: the Tackle Board never reads another Module's DB"
local LIVE_RECORDS = "TKB-R80: only logic/LiveStep.lua and logic/Reroll.lua append records"

-- The files that may append the Tackle Board's records (TKB-R80), relative to the addon folder.
local APPENDS = { ["logic/LiveStep.lua"] = true, ["logic/Reroll.lua"] = true }

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
-- A Module record, however it's reached: M:AppendRecord, M.AppendRecord(M, …), M["AppendRecord"] or a local copy.
local APPEND = { "%f[%w_]AppendRecord%f[^%w_]", LIVE_RECORDS }

-- Each forbidden thing the code of `file` (relative to the addon folder) says, as "<why>: <match>".
---@param file string
---@param text string
---@return string[]
local function offences(file, text)
	local forbidden = { unpack(FORBIDDEN) }
	if not APPENDS[file] then
		forbidden[#forbidden + 1] = APPEND
	end
	return forbiddenIn(withoutComments(text), forbidden)
end

describe("the Tackle Board's boundary", function()
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
			{ "logic/Completions.lua", 'local hunts = _G["Pagle_Hunts"]', NO_MODULE },
			{ "adapter/Board.lua", "Pagle_QoL_Toggle()", NO_MODULE },
			{ "logic/Generate.lua", 'ns.Module:AppendRecord("issue", payload)', LIVE_RECORDS },
			{ "logic/Projection.lua", 'M.AppendRecord(M, "day", payload)', LIVE_RECORDS },
			{ "logic/Seams.lua", 'M["AppendRecord"](M, "start", payload)', LIVE_RECORDS },
			{ "adapter/TackleBoard.lua", "local append = M.AppendRecord", LIVE_RECORDS },
		}
		for _, case in ipairs(planted) do
			it(case[2] .. " in " .. case[1], function()
				local found = offences(case[1], case[2])

				assert.is_true(#found > 0)
				assert.are.equal(case[3], found[1]:sub(1, #case[3]))
			end)
		end

		it("but not an AppendRecord in logic/LiveStep.lua or logic/Reroll.lua (TKB-R80)", function()
			assert.are.same({}, offences("logic/LiveStep.lua", 'ns.Module:AppendRecord("start", payload)'))
			assert.are.same({}, offences("logic/Reroll.lua", 'ns.Module:AppendRecord("reroll", payload)'))
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
					"logic/Moments.lua",
					'M:RaiseMoment(moment)\nM:SetSummaryLine("board", text)\nM:RaiseWriteUp(section)\n'
						.. "M:ReportCoinsEarned(60)\nlocal p = M:NewProjection(def)\nlocal a = Pagle.GetAngler()"
				)
			)
		end)
	end)
end)
