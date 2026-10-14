-- What the Ledger never does (ADR 0001, Modules only see Core): it never reads the Catch log's SavedVariables or
-- Core's, never reads another Module's DB and calls no other Module. Checked over every file the Ledger ships: each
-- name below fails the spec wherever the Ledger's code says it. It reads Catches only through its Module handle
-- (LED-R2, from ticket #100 on).

local DIR = "addons/Pagle_Ledger/"

-- Each forbidden thing: a Lua pattern over code with comments removed, and the rule it breaks.
local FORBIDDEN = {
	{ "%f[%w_]PagleLog%f[^%w_]", "ADR 0001, LED-R2: the Ledger reads Catches only through M:IterateCatches" },
	{ "%f[%w_]PagleDB%f[^%w_]", "ADR 0001: the Ledger never reads Core's SavedVariables" },
	-- Its state is rebuilt from Catches alone; only the Tackle Board appends Module records (ADR 0008, LOG-R41).
	{ "%f[%w_]AppendRecord%f[^%w_]", "ADR 0008: the Ledger appends no Module records" },
}
-- Every other roster Module (CORE-R1): its addon (its AceAddon and its folder name), any global named after it, and
-- its DB.
for _, name in ipairs(newFakePagle().ns.MODULE_ROSTER) do
	if name ~= "Ledger" then
		FORBIDDEN[#FORBIDDEN + 1] = { "%f[%w_]Pagle_" .. name, "ADR 0001: the Ledger calls no other Module" }
		FORBIDDEN[#FORBIDDEN + 1] =
			{ "%f[%w_]Pagle" .. name .. "DB%f[^%w_]", "ADR 0001: the Ledger never reads another Module's DB" }
	end
end

-- Each forbidden thing the code says, as "<why>: <match>".
---@param text string
---@return string[]
local function offences(text)
	return forbiddenIn(withoutComments(text), FORBIDDEN)
end

describe("The Ledger's boundary", function()
	it("covers every file the Ledger ships", function()
		assert.are.equal(#addonFiles("Pagle_Ledger"), #shippedFiles(DIR))
	end)

	for _, path in ipairs(shippedFiles(DIR)) do
		it(path .. " reads no other addon's data and calls no other Module (ADR 0001)", function()
			assert.are.same({}, offences(readFile(path)))
		end)
	end

	describe("catches", function()
		local planted = {
			{ "local log = PagleLog", "ADR 0001, LED-R2" },
			{ "local entries = _G.PagleLog.entries", "ADR 0001, LED-R2" },
			{ "local db = PagleDB", "ADR 0001: the Ledger never reads Core's SavedVariables" },
			{ "local lease = PagleQoLDB.global.lease", "ADR 0001: the Ledger never reads another Module's DB" },
			{ "local hunts = PagleHuntsDB", "ADR 0001: the Ledger never reads another Module's DB" },
			{ "local stats = PagleStatsDB", "ADR 0001: the Ledger never reads another Module's DB" },
			{ "local board = PagleTackleBoardDB", "ADR 0001: the Ledger never reads another Module's DB" },
			{ 'LibStub("AceAddon-3.0"):GetAddon("Pagle_QoL")', "ADR 0001: the Ledger calls no other Module" },
			{ 'C_AddOns.IsAddOnLoaded("Pagle_Hunts")', "ADR 0001: the Ledger calls no other Module" },
			{ 'local stats = _G["Pagle_Stats"]', "ADR 0001: the Ledger calls no other Module" },
			{ "Pagle_TackleBoard_Open()", "ADR 0001: the Ledger calls no other Module" },
			{ 'M:AppendRecord("celebrated", "1")', "ADR 0008: the Ledger appends no Module records" },
		}
		for _, case in ipairs(planted) do
			it(case[1], function()
				local found = offences(case[1])

				assert.is_true(#found > 0)
				assert.are.equal(case[2], found[1]:sub(1, #case[2]))
			end)
		end

		it("but not what only a comment says, nor the Ledger's own PagleLedgerDB and Pagle_Ledger", function()
			assert.are.same(
				{},
				offences('-- never PagleLog\n--[[ PagleQoLDB ]]\nlocal db = PagleLedgerDB\nlocal _ = "Pagle_Ledger"')
			)
			assert.are.same({}, offences('<!--\nPagleDB, Pagle_QoL\n-->\n<Bindings name="Pagle_Ledger"/>'))
		end)
	end)
end)
