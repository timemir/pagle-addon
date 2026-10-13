-- What QoL never does (QOL-R3, QOL-R6) and the edge cases where it has nothing to do (QOL-R91, QOL-R92, QOL-R95,
-- QOL-R96), checked over every file QoL ships: each name below fails the spec wherever QoL's code says it.

local DIR = "addons/Pagle_QoL/"

-- Each forbidden thing: a Lua pattern over code with comments removed, and the rule it breaks.
local FORBIDDEN = {
	-- QOL-R3, QOL-R91, QOL-R92: no projection, Module records, moments, summary line, Write-up, Coins, goods,
	-- slots or tracker (the Module handle calls for them, core/README.md › Contracts).
	{ "%f[%w_]NewProjection%f[^%w_]", "QOL-R3, QOL-R91: QoL keeps no projection" },
	{ "%f[%w_]AppendRecord%f[^%w_]", "QOL-R3: QoL appends no Module records" },
	{ "%f[%w_]RecordPrestige%f[^%w_]", "QOL-R3: QoL appends no Module records" },
	{ "%f[%w_]RaiseMoment%f[^%w_]", "QOL-R3: QoL raises no moments" },
	{ "%f[%w_]SetSummaryLine%f[^%w_]", "QOL-R3: QoL sets no summary line" },
	{ "%f[%w_]RaiseWriteUp%f[^%w_]", "QOL-R92: QoL has no Write-up" },
	{ "%f[%w_]ReportCoinsEarned%f[^%w_]", "QOL-R3: QoL pays no Coins" },
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
	-- QOL-R6: never ReloadUI(), no secure snippets.
	{ "%f[%w_]ReloadUI%f[^%w_]", "QOL-R6: QoL never calls ReloadUI()" },
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

-- Code with its comments removed: Lua's --[[ ]] and -- comments, XML's <!-- -->.
---@param text string
---@return string
local function withoutComments(text)
	text = text:gsub("<!%-%-.-%-%->", "")
	text = text:gsub("%-%-%[(=*)%[.-%]%1%]", "")
	text = text:gsub("%-%-[^\n]*", "")
	return text
end

-- Each forbidden thing the code says, as "<why>: <match>".
---@param text string
---@return string[]
local function offences(text)
	local found = {}
	local code = withoutComments(text)
	for _, rule in ipairs(FORBIDDEN) do
		local match = code:match(rule[1])
		if match then
			found[#found + 1] = rule[2] .. ": " .. match
		end
	end
	return found
end

---@return string[]
local function shippedFiles()
	local files = {}
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
	local find = assert(io.popen("find " .. DIR .. " -type f \\( -name '*.lua' -o -name '*.xml' \\)"))
	for path in find:lines() do
		files[#files + 1] = path
	end
	find:close()
	table.sort(files)
	return files
end

---@param path string
---@return string
local function read(path)
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
	local file = assert(io.open(path, "r"))
	local text = file:read("*a")
	file:close()
	return text
end

describe("QoL's boundary", function()
	it("covers both the Lua and the XML QoL ships", function()
		local files = shippedFiles()

		assert.is_true(#files > 1)
		assert.are.equal(DIR .. "Bindings.xml", files[1])
	end)

	for _, path in ipairs(shippedFiles()) do
		it(path .. " does nothing QOL-R3 and QOL-R6 forbid (QOL-R91, QOL-R92, QOL-R95, QOL-R96)", function()
			assert.are.same({}, offences(read(path)))
		end)
	end

	describe("catches", function()
		local planted = {
			{ "ReloadUI()", "QOL-R6: QoL never calls ReloadUI()" },
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

		it("but not what only a comment says, nor QoL's own PagleQoLDB", function()
			assert.are.same({}, offences("-- never ReloadUI()\n--[[ SecureHandlerWrapScript ]]\nlocal db = PagleQoLDB"))
		end)
	end)
end)
