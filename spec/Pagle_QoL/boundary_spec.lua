-- What QoL never does (QOL-R3, QOL-R6) and the edge cases where it has nothing to do (QOL-R91, QOL-R92, QOL-R95,
-- QOL-R96), checked over every file QoL ships: each name below fails the spec wherever QoL's code says it. And what
-- its logic/ never does (CORE-R7), checked over every file there.

local DIR = "addons/Pagle_QoL/"

-- Each forbidden thing: a Lua pattern over code with comments removed, and the rule it breaks.
local FORBIDDEN = {
	-- QOL-R3, QOL-R91, QOL-R92: no projection, Module records, moments, summary line, Write-up, Coins, Activity XP
	-- (AXP-R1), goods, slots or tracker (the Module handle calls for them, core/README.md › Contracts).
	{ "%f[%w_]NewProjection%f[^%w_]", "QOL-R3, QOL-R91: QoL keeps no projection" },
	{ "%f[%w_]AppendRecord%f[^%w_]", "QOL-R3: QoL appends no Module records" },
	{ "%f[%w_]RecordPrestige%f[^%w_]", "QOL-R3: QoL appends no Module records" },
	{ "%f[%w_]RaiseMoment%f[^%w_]", "QOL-R3: QoL raises no moments" },
	{ "%f[%w_]SetSummaryLine%f[^%w_]", "QOL-R3: QoL sets no summary line" },
	{ "%f[%w_]RaiseWriteUp%f[^%w_]", "QOL-R92: QoL has no Write-up" },
	{ "%f[%w_]ReportCoinsEarned%f[^%w_]", "QOL-R3: QoL pays no Coins" },
	{ "%f[%w_]ReportXPEarned%f[^%w_]", "AXP-R1: QoL pays no Activity XP" },
	{ "%f[%w_]RegisterGood%f[^%w_]", "QOL-R3: QoL registers no goods" },
	{ "%f[%w_]RefreshGoods%f[^%w_]", "QOL-R3: QoL registers no goods" },
	{ "%f[%w_]RegisterSlot%f[^%w_]", "QOL-R3: QoL registers no slots" },
	{ "%f[%w_]RegisterTracker%f[^%w_]", "QOL-R3: QoL docks no tracker" },
	-- QOL-R3, QOL-R96: it never reads the Catch log, and writes nothing to Core's SavedVariables (qol.md › Data).
	{ "%f[%w_]IterateCatches%f[^%w_]", "QOL-R3, QOL-R96: QoL never reads the Catch log" },
	{ "%f[%w_]PagleLog%f[^%w_]", "QOL-R3, QOL-R96: QoL never reads the Catch log" },
	{ "%f[%w_]PagleDB%f[^%w_]", "qol.md › Data: QoL writes nothing to PagleDB" },
	-- QOL-R95: no rule depends on the daily or weekly reset.
	{ "%f[%w_]GetQuestResetTime%f[^%w_]", "QOL-R95: no QoL rule depends on the reset" },
	{ "%f[%w_]GetSecondsUntil%a*Reset%f[^%w_]", "QOL-R95: no QoL rule depends on the reset" },
	-- QOL-R6: ReloadUI() only from a click on Reload now (RELOAD_NOW below takes that one call out), no secure
	-- snippets.
	{ "%f[%w_]ReloadUI%f[^%w_]", "QOL-R6: ReloadUI() only from a click on Reload now" },
	{ "SecureHandler", "QOL-R6: QoL uses no secure snippets" },
	{ "WrapScript", "QOL-R6: QoL uses no secure snippets" },
	{ "[\"']_on%a", "QOL-R6: QoL uses no secure snippets (a _on… snippet attribute)" },
	-- QOL-R6: no macro text with more than one command. Commands in macro text are split by line breaks, and QoL
	-- builds no text with one, so none of its macro text can hold a second command.
	{ "\\n", "QOL-R6: no line break, so no macro text with a second command" },
	{ "\\r", "QOL-R6: no line break, so no macro text with a second command" },
	{ "\\0*1[03]%f[%D]", "QOL-R6: no line break, so no macro text with a second command" },
	{ "char%(%s*1[03]%s*[,)]", "QOL-R6: no line break, so no macro text with a second command" },
	{ "%[=*%[", "QOL-R6: no long string, which can hold a line break, so no macro text with a second command" },
	{ "&#0*1[03];", "QOL-R6: no line break, so no macro text with a second command" },
	{ "&#[xX]0*[aAdD];", "QOL-R6: no line break, so no macro text with a second command" },
}

-- Each thing logic/ never does besides (CORE-R7), as above. luacheck's per-path std keeps WoW globals out of logic/,
-- but PagleQoLDB is reached through the addon's own table, which no std can see.
local FORBIDDEN_IN_LOGIC = {
	{ "%f[%w_]ns%.db%f[^%w_]", "CORE-R7: logic/ is passed what it reads of PagleQoLDB, never ns.db" },
}

-- QOL-R6, QOL-R83: the one ReloadUI() QoL may call, the first choice of the Reload now note in adapter/Conflict.lua,
-- whose first button says "Reload now": showNote(name, text, first, second, onFirst) runs onFirst only from a click
-- on that button, never on load, an event or a timer. The pattern captures the code around the call, so that call
-- alone can be taken out.
local RELOAD_NOW_FILE = DIR .. "adapter/Conflict.lua"
local RELOAD_NOW = "(showNote%(%s*RELOAD_NOTE%s*,%s*ns%.L%.CONFLICT_RELOAD_TEXT%s*,%s*ns%.L%.CONFLICT_RELOAD_NOW%s*,"
	.. "%s*ns%.L%.CONFLICT_RELOAD_LATER%s*,%s*function%s*%(%)%s*)ReloadUI%(%)(%s*end)"

-- Each forbidden thing the code says, as "<why>: <match>".
---@param text string
---@param path string? the file it's from; only RELOAD_NOW_FILE may hold the Reload now call
---@return string[]
local function offences(text, path)
	local code = withoutComments(text)
	if path == RELOAD_NOW_FILE then
		code = code:gsub(RELOAD_NOW, "%1%2", 1)
	end
	return forbiddenIn(code, FORBIDDEN)
end

-- Each thing logic/ never does that the code says, as "<why>: <match>" (CORE-R7).
---@param text string
---@return string[]
local function logicOffences(text)
	return forbiddenIn(withoutComments(text), FORBIDDEN_IN_LOGIC)
end

describe("QoL's boundary", function()
	it("covers both the Lua and the XML QoL ships", function()
		local files = shippedFiles(DIR)

		assert.is_true(#files > 1)
		assert.are.equal(DIR .. "Bindings.xml", files[1])
	end)

	for _, path in ipairs(shippedFiles(DIR)) do
		it(path .. " does nothing QOL-R3 and QOL-R6 forbid (QOL-R91, QOL-R92, QOL-R95, QOL-R96)", function()
			assert.are.same({}, offences(readFile(path), path))
		end)
		if path:find("/logic/", 1, true) then
			it(path .. " never reads ns.db (CORE-R7)", function()
				assert.are.same({}, logicOffences(readFile(path)))
			end)
		end
	end

	it("calls ReloadUI() from the Reload now button alone (QOL-R6, QOL-R83)", function()
		local code = withoutComments(readFile(RELOAD_NOW_FILE))
		local _, allowed = code:gsub(RELOAD_NOW, "")
		local _, calls = code:gsub("%f[%w_]ReloadUI%f[^%w_]", "")

		assert.are.equal(1, allowed)
		assert.are.equal(1, calls)
	end)

	describe("catches", function()
		local planted = {
			{ "ReloadUI()", "QOL-R6: ReloadUI() only from a click on Reload now" },
			{ 'SecureHandlerWrapScript(button, "OnClick", header, "")', "QOL-R6: QoL uses no secure snippets" },
			{ 'header:WrapScript(button, "OnClick", "")', "QOL-R6: QoL uses no secure snippets" },
			{ 'button:SetAttribute("_onclick", "")', "QOL-R6: QoL uses no secure snippets" },
			{ 'button:SetAttribute("macrotext", "/cast A\\n/cast B")', "QOL-R6: no line break" },
			{ 'local text = "/cast A" .. string.char(10) .. "/cast B"', "QOL-R6: no line break" },
			{ 'local text = "/cast A\\10/cast B"', "QOL-R6: no line break" },
			{ "local text = [[/cast A\n/cast B]]", "QOL-R6: no long string" },
			{ '<Attribute name="macrotext" value="/cast A&#10;/cast B"/>', "QOL-R6: no line break" },
			{ '<Attribute name="macrotext" value="/cast A&#xA;/cast B"/>', "QOL-R6: no line break" },
			{ "M:NewProjection({})", "QOL-R3, QOL-R91: QoL keeps no projection" },
			{ "M:AppendRecord(kind, payload)", "QOL-R3: QoL appends no Module records" },
			{ "M:RaiseMoment(moment)", "QOL-R3: QoL raises no moments" },
			{ "M:RaiseWriteUp(section)", "QOL-R92: QoL has no Write-up" },
			{ "M:ReportCoinsEarned(1)", "QOL-R3: QoL pays no Coins" },
			{ "M:ReportXPEarned(1)", "AXP-R1: QoL pays no Activity XP" },
			{ "M:RegisterGood(good)", "QOL-R3: QoL registers no goods" },
			{ "M:RegisterSlot(slot)", "QOL-R3: QoL registers no slots" },
			{ "M:RegisterTracker({})", "QOL-R3: QoL docks no tracker" },
			{ "for record in Pagle.IterateCatches(0) do end", "QOL-R3, QOL-R96: QoL never reads the Catch log" },
			{ "local log = PagleLog", "QOL-R3, QOL-R96: QoL never reads the Catch log" },
			{ "C_DateAndTime.GetSecondsUntilDailyReset()", "QOL-R95" },
		}
		for _, case in ipairs(planted) do
			it(case[1], function()
				local found = offences(case[1])

				assert.is_true(#found > 0)
				assert.are.equal(case[2], found[1]:sub(1, #case[2]))
			end)
		end

		it("ns.db in logic/, but not ns.dbx or a comment's ns.db (CORE-R7)", function()
			local found = logicOffences("return ns.db.profile.input")

			assert.are.same({ "CORE-R7: logic/ is passed what it reads of PagleQoLDB, never ns.db: ns.db" }, found)
			assert.are.same({}, logicOffences("local x = ns.dbx -- ns.db"))
		end)

		-- QOL-R6: the one ReloadUI() QoL may make, from a click on the Reload now note's button (QOL-R83).
		local PLANTED_RELOAD = table.concat({
			"showNote(RELOAD_NOTE, ns.L.CONFLICT_RELOAD_TEXT, ns.L.CONFLICT_RELOAD_NOW, ns.L.CONFLICT_RELOAD_LATER, function()",
			"	ReloadUI()",
			"end)",
		}, "\n")

		it("but not ReloadUI() from a click on Reload now, in adapter/Conflict.lua", function()
			assert.are.same({}, offences(PLANTED_RELOAD, DIR .. "adapter/Conflict.lua"))
		end)

		local reloads = {
			{ "the Reload now handler in another file", PLANTED_RELOAD, DIR .. "adapter/QoL.lua" },
			{ "a second ReloadUI()", PLANTED_RELOAD .. "\nReloadUI()", DIR .. "adapter/Conflict.lua" },
			{
				"ReloadUI() on another note's button",
				(PLANTED_RELOAD:gsub("RELOAD_NOTE", "CONFLICT_NOTE")),
				DIR .. "adapter/Conflict.lua",
			},
			{
				"ReloadUI() on a button that doesn't say Reload now",
				(PLANTED_RELOAD:gsub("CONFLICT_RELOAD_NOW", "CONFLICT_USE_PAGLE")),
				DIR .. "adapter/Conflict.lua",
			},
			{
				"ReloadUI() when the note shows",
				(PLANTED_RELOAD:gsub("showNote", 'note:SetScript("OnShow", '):gsub("RELOAD_NOTE, ", "")),
				DIR .. "adapter/Conflict.lua",
			},
		}
		for _, case in ipairs(reloads) do
			it(case[1], function()
				assert.are.same(
					{ "QOL-R6: ReloadUI() only from a click on Reload now: ReloadUI" },
					offences(case[2], case[3])
				)
			end)
		end

		it("but not what only a comment says, nor QoL's own PagleQoLDB", function()
			assert.are.same({}, offences("-- never ReloadUI()\n--[[ SecureHandlerWrapScript ]]\nlocal db = PagleQoLDB"))
		end)
	end)
end)
