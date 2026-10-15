-- What Hunts never does (ADR 0001, Modules only see Core): it never reads the Catch log's SavedVariables or Core's,
-- never reads another Module's DB and calls no other Module, the Ledger included, even for the board's art. Nor does
-- it read an item's quality or class from the client: class membership comes only from the Hunt list (HNT-R12). Nor
-- does it give a set title to the game (HNT-R22).
-- Checked over every file Hunts ships: each name below fails the spec wherever Hunts' code says it.

local DIR = "addons/Pagle_Hunts/"

local QUALITY_OR_CLASS = "HNT-R12: Hunts never reads item quality or class from C_Item"

-- Each forbidden thing: a Lua pattern over code with comments removed, and the rule it breaks.
local FORBIDDEN = {
	{ "%f[%w_]PagleLog%f[^%w_]", "ADR 0001: Hunts reads Catches only through its projection" },
	{ "%f[%w_]PagleDB%f[^%w_]", "ADR 0001: Hunts never reads Core's SavedVariables" },
	-- Its state is rebuilt from Catches alone; only the Tackle Board appends Module records (ADR 0008, LOG-R41).
	{ "%f[%w_]AppendRecord%f[^%w_]", "ADR 0008: Hunts appends no Module records" },
	-- C_Item.GetItemInfo and GetItemInfoInstant, global or not, return the quality, class and subclass.
	{ "%f[%w_]GetItemInfo", QUALITY_OR_CLASS },
	{ "%f[%w_]GetItemQualityByID%f[^%w_]", QUALITY_OR_CLASS },
	-- ItemMixin's item:GetItemQuality().
	{ "[:.]GetItemQuality%f[^%w_]", QUALITY_OR_CLASS },
	{ "%f[%w_]GetItemClassInfo%f[^%w_]", QUALITY_OR_CLASS },
	{ "%f[%w_]GetItemSubClassInfo%f[^%w_]", QUALITY_OR_CLASS },
	-- The game's own titles: a set title is never given to the game (HNT-R22).
	{ "%f[%w_]SetCurrentTitle%f[^%w_]", "HNT-R22: set titles stay in Hunts' own views" },
}
-- Every other roster Module (CORE-R1): its addon (its AceAddon and its folder name), any global named after it, and
-- its DB.
for _, name in ipairs(newFakePagle().ns.MODULE_ROSTER) do
	if name ~= "Hunts" then
		FORBIDDEN[#FORBIDDEN + 1] = { "%f[%w_]Pagle_" .. name, "ADR 0001: Hunts calls no other Module" }
		FORBIDDEN[#FORBIDDEN + 1] =
			{ "%f[%w_]Pagle" .. name .. "DB%f[^%w_]", "ADR 0001: Hunts never reads another Module's DB" }
	end
end

-- Each forbidden thing the code says, as "<why>: <match>".
---@param text string
---@return string[]
local function offences(text)
	return forbiddenIn(withoutComments(text), FORBIDDEN)
end

describe("Hunts' boundary", function()
	it("covers every file Hunts ships", function()
		assert.are.equal(#addonFiles("Pagle_Hunts"), #shippedFiles(DIR))
	end)

	for _, path in ipairs(shippedFiles(DIR)) do
		it(path .. " reads no other addon's data, calls no other Module and reads no item quality or class", function()
			-- ADR 0001, HNT-R12
			assert.are.same({}, offences(readFile(path)))
		end)
	end

	describe("catches", function()
		local planted = {
			{ "local log = PagleLog", "ADR 0001: Hunts reads Catches only through its projection" },
			{ "local entries = _G.PagleLog.entries", "ADR 0001: Hunts reads Catches only through its projection" },
			{ "local db = PagleDB", "ADR 0001: Hunts never reads Core's SavedVariables" },
			{ "local ledger = PagleLedgerDB.global.celebrated", "ADR 0001: Hunts never reads another Module's DB" },
			{ "local lease = PagleQoLDB.global.lease", "ADR 0001: Hunts never reads another Module's DB" },
			{ "local stats = PagleStatsDB", "ADR 0001: Hunts never reads another Module's DB" },
			{ "local board = PagleTackleBoardDB", "ADR 0001: Hunts never reads another Module's DB" },
			{ 'LibStub("AceAddon-3.0"):GetAddon("Pagle_Ledger")', "ADR 0001: Hunts calls no other Module" },
			{ 'C_AddOns.IsAddOnLoaded("Pagle_Stats")', "ADR 0001: Hunts calls no other Module" },
			{ 'local qol = _G["Pagle_QoL"]', "ADR 0001: Hunts calls no other Module" },
			{ "Pagle_TackleBoard_Open()", "ADR 0001: Hunts calls no other Module" },
			{ 'M:AppendRecord("completed", "trout")', "ADR 0008: Hunts appends no Module records" },
			{ "local _, _, quality = C_Item.GetItemInfo(itemID)", QUALITY_OR_CLASS },
			{ "local _, _, _, _, _, classID = GetItemInfoInstant(itemID)", QUALITY_OR_CLASS },
			{ "local quality = C_Item.GetItemQualityByID(itemID)", QUALITY_OR_CLASS },
			{ "local quality = Item:CreateFromItemID(itemID):GetItemQuality()", QUALITY_OR_CLASS },
			{ "local name = C_Item.GetItemClassInfo(classID)", QUALITY_OR_CLASS },
			{ "local name = GetItemSubClassInfo(classID, subClassID)", QUALITY_OR_CLASS },
			{ "SetCurrentTitle(titleID)", "HNT-R22: set titles stay in Hunts' own views" },
		}
		for _, case in ipairs(planted) do
			it(case[1], function()
				local found = offences(case[1])

				assert.is_true(#found > 0)
				assert.are.equal(case[2], found[1]:sub(1, #case[2]))
			end)
		end

		it("but not what only a comment says, nor Hunts' own PagleHuntsDB and Pagle_Hunts", function()
			assert.are.same(
				{},
				offences('-- never PagleLog\n--[[ PagleLedgerDB ]]\nlocal db = PagleHuntsDB\nlocal _ = "Pagle_Hunts"')
			)
		end)

		it("nor the item calls Hunts needs for names and icons (HNT-R54)", function()
			assert.are.same(
				{},
				offences(
					"local item = Item:CreateFromItemID(itemID)\nlocal name = item:GetItemName()\n"
						.. "local icon = C_Item.GetItemIconByID(itemID)\nlocal n = C_Item.GetItemNameByID(itemID)"
				)
			)
		end)
	end)
end)
