-- CORE-R8, ADR 0019: the Language writes what the Angler reads, never what a machine reads. The Paste string the
-- website's upload decoder reads (paste-string.md, UPL Contracts) and the Field report text the issue form parses
-- (field-report.md) are the same bytes in every Language (Spanish here, on an English client), while the lines shown beside them take the Language's
-- separators: 1,202 entries (1,200 Casts and their build entries) read "1,202" in English and "1.202" in Spanish under the Paste string, and in neither inside it.

local FIRST = SERVER_TIME - 2000 -- the history's Casts are at FIRST + 1, + 2, …
local CASTS = 1200

-- Core logged in over the same history, in `language`, on a `client` client (enUS when not given).
local function inLanguage(language, entries, client)
	local globals = client and {
		GetLocale = function()
			return client
		end,
	} or nil
	return enterWorld(loadCore(entries, { global = { language = language } }, globals), 2)
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

	-- CORE-R9: on a ruRU client every face is FRIZQT___CYR, which has no "·", so the strings Pagle draws take "•" for it
	-- (adapter/Fonts.lua). The machine-read text is not built from them and keeps every byte but the client's locale,
	-- which the Field report's header names.
	it("keeps the Paste string and the Field report byte for byte in English on a ruRU client", function()
		local pastes, reports = {}, {}
		for _, client in ipairs({ "enUS", "ruRU" }) do
			local loaded = inLanguage("enUS", history(CASTS, FIRST), client)
			assert.are.equal("enUS", loaded.ns.language)
			loaded.env.SlashCmdList.PAGLE("export")
			pastes[client] = assert(loaded.ns.pasteExportWindow).paste:GetText()
			local charted = inLanguage("enUS", unchartedHistory(CASTS, FIRST), client)
			charted.env.Pagle.OpenFieldReport()
			reports[client] = assert(charted.ns.fieldReportBox).text:GetText()
			if client == "ruRU" then
				-- The glyph overlay ran in this session: the strings drawn around the Paste string take the bullet.
				assert.are.equal(" \226\128\162 ", loaded.ns.L.SHOP_TAG_SEPARATOR)
			end
		end

		assert.are.equal(pastes.enUS, pastes.ruRU)
		assert.truthy(reports.enUS:find("^PAGLE%-REPORT 1\n"))
		-- The header names the client's locale (field-report.md); every other byte is the same.
		assert.truthy(reports.ruRU:find(" locale ruRU ", 1, true))
		assert.are.equal((reports.enUS:gsub(" locale enUS ", " locale ruRU ", 1)), reports.ruRU)
	end)
end)
