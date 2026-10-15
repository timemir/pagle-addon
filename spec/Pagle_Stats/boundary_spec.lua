-- What Stats never does. It reads only Core (STA-R1, ADR 0001: Modules only see Core): never the Catch log's
-- SavedVariables or Core's, never another Module's DB, and it calls no other Module. And it celebrates nothing
-- (STA-R2): no Moment, Session summary line, Write-up section or Coins, and no Module record. Checked over every file
-- Stats ships: each name below fails the spec wherever Stats' code says it.

local DIR = "addons/Pagle_Stats/"

local READS_ONLY_CORE = "STA-R1: Stats reads Catches only through its projection"
local NO_CORE_DB = "STA-R1: Stats never reads Core's SavedVariables"
local NO_MODULE = "STA-R1: Stats calls no other Module"
local NO_MODULE_DB = "STA-R1: Stats never reads another Module's DB"
local CELEBRATES_NOTHING = "STA-R2: Stats celebrates nothing"

-- Each forbidden thing: a Lua pattern over code with comments removed, and the rule it breaks.
local FORBIDDEN = {
	{ "%f[%w_]PagleLog%f[^%w_]", READS_ONLY_CORE },
	{ "%f[%w_]PagleDB%f[^%w_]", NO_CORE_DB },
	-- The handle's calls that celebrate (CORE-R12), however they're reached: M:RaiseMoment, M.RaiseMoment(M, …),
	-- M["RaiseMoment"] or a local copy of one.
	{ "%f[%w_]RaiseMoment%f[^%w_]", CELEBRATES_NOTHING },
	{ "%f[%w_]SetSummaryLine%f[^%w_]", CELEBRATES_NOTHING },
	{ "%f[%w_]RaiseWriteUp%f[^%w_]", CELEBRATES_NOTHING },
	{ "%f[%w_]ReportCoinsEarned%f[^%w_]", CELEBRATES_NOTHING },
	-- A Module record (LOG-R14); none arrive before M7, but Stats appends none ever.
	{ "%f[%w_]AppendRecord%f[^%w_]", CELEBRATES_NOTHING },
}
-- Every other roster Module (CORE-R1): its addon (its AceAddon and its folder name), any global named after it, and
-- its DB.
for _, name in ipairs(newFakePagle().ns.MODULE_ROSTER) do
	if name ~= "Stats" then
		FORBIDDEN[#FORBIDDEN + 1] = { "%f[%w_]Pagle_" .. name, NO_MODULE }
		FORBIDDEN[#FORBIDDEN + 1] = { "%f[%w_]Pagle" .. name .. "DB%f[^%w_]", NO_MODULE_DB }
	end
end

-- Each forbidden thing the code says, as "<why>: <match>".
---@param text string
---@return string[]
local function offences(text)
	return forbiddenIn(withoutComments(text), FORBIDDEN)
end

describe("Stats' boundary (ADR 0001, STA-R1, STA-R2)", function()
	it("covers every file Stats ships", function()
		assert.are.equal(#addonFiles("Pagle_Stats"), #shippedFiles(DIR))
	end)

	for _, path in ipairs(shippedFiles(DIR)) do
		it(path .. " reads only Core, calls no other Module and celebrates nothing", function()
			-- STA-R1, STA-R2, ADR 0001
			assert.are.same({}, offences(readFile(path)))
		end)
	end

	describe("catches", function()
		local planted = {
			{ "local log = PagleLog", READS_ONLY_CORE },
			{ "local entries = _G.PagleLog.entries", READS_ONLY_CORE },
			{ "local db = PagleDB", NO_CORE_DB },
			{ "local ledger = PagleLedgerDB.global.celebrated", NO_MODULE_DB },
			{ "local pins = PagleHuntsDB.profile.pins", NO_MODULE_DB },
			{ "local lease = PagleQoLDB.global.lease", NO_MODULE_DB },
			{ "local board = PagleTackleBoardDB", NO_MODULE_DB },
			{ 'LibStub("AceAddon-3.0"):GetAddon("Pagle_Hunts")', NO_MODULE },
			{ 'C_AddOns.IsAddOnLoaded("Pagle_Ledger")', NO_MODULE },
			{ 'local qol = _G["Pagle_QoL"]', NO_MODULE },
			{ "Pagle_TackleBoard_Open()", NO_MODULE },
			{ 'ns.Module:RaiseMoment("stats.drySpell", { rung = 1 })', CELEBRATES_NOTHING },
			{ "M.RaiseMoment(M, moment)", CELEBRATES_NOTHING },
			{ 'M["RaiseMoment"](M, moment)', CELEBRATES_NOTHING },
			{ 'M:SetSummaryLine("Best Session yet")', CELEBRATES_NOTHING },
			{ "M:RaiseWriteUp(section)", CELEBRATES_NOTHING },
			{ "M:ReportCoinsEarned(5)", CELEBRATES_NOTHING },
			{ 'M:AppendRecord({ kind = "stats" })', CELEBRATES_NOTHING },
		}
		for _, case in ipairs(planted) do
			it(case[1], function()
				local found = offences(case[1])

				assert.is_true(#found > 0)
				assert.are.equal(case[2], found[1]:sub(1, #case[2]))
			end)
		end

		it("but not what only a comment says, nor Stats' own PagleStatsDB and Pagle_Stats", function()
			assert.are.same(
				{},
				offences(
					"-- never PagleLog, never M:RaiseMoment\n--[[ PagleLedgerDB ]]\n"
						.. 'local db = PagleStatsDB\nlocal _ = "Pagle_Stats"'
				)
			)
		end)

		it("nor the Core and item calls stats.md › Contracts lists (STA-R1 allows Core)", function()
			assert.are.same(
				{},
				offences(
					"local session = Pagle.GetSession()\nlocal spec = Pagle.GetWindowSpec(id)\n"
						.. "local quality = C_Item.GetItemQualityByID(itemID)\n"
						.. "local name = C_Item.GetItemNameByID(itemID)\nlocal p = M:NewProjection(def)"
				)
			)
		end)
	end)
end)
