-- CORE-R8, ADR 0019: the Language writes what the Angler reads, never what a machine reads. The Paste string the
-- website's upload decoder reads (paste-string.md, UPL Contracts) and the Field report text the issue form parses
-- (field-report.md) are the same bytes in every Language (Spanish here, on an English client), while the lines shown beside them take the Language's
-- separators: 1,202 entries (1,200 Casts and their build entries) read "1,202" in English and "1.202" in Spanish under the Paste string, and in neither inside it.

local FIRST = SERVER_TIME - 2000 -- the history's Casts are at FIRST + 1, + 2, …
local CASTS = 1200

-- Core logged in over the same history, in `language`.
local function inLanguage(language, entries)
	return enterWorld(loadCore(entries, { global = { language = language } }), 2)
end

describe("machine-read text in every Language (CORE-R8)", function()
	it("keeps the Paste string byte for byte, and writes the window's line in the Language", function()
		local pastes, lines = {}, {}
		for _, language in ipairs({ "enUS", "esES" }) do
			local loaded = inLanguage(language, history(CASTS, FIRST))
			assert.are.equal(language, loaded.ns.language)
			loaded.env.SlashCmdList.PAGLE("export")
			local frame = assert(loaded.ns.pasteExportWindow)
			pastes[language], lines[language] = frame.paste:GetText(), frame.line:GetText()
		end

		assert.are.equal(pastes.enUS, pastes.esES)
		assert(lines.enUS:find("1,202", 1, true), lines.enUS)
		assert(lines.esES:find("1.202", 1, true), lines.esES)
	end)

	it("keeps the Field report text byte for byte", function()
		local reports = {}
		for _, language in ipairs({ "enUS", "esES" }) do
			local loaded = inLanguage(language, unchartedHistory(CASTS, FIRST))
			assert.are.equal(language, loaded.ns.language)
			loaded.env.Pagle.OpenFieldReport()
			reports[language] = assert(loaded.ns.fieldReportBox).text:GetText()
		end

		assert.truthy(reports.enUS:find("^PAGLE%-REPORT 1\n"))
		assert.are.equal(reports.enUS, reports.esES)
	end)
end)
