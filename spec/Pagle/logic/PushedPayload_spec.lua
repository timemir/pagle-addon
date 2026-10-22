-- The pushed payload's reader (PUSH-R20, PUSH-R21; core/pushed-content.md › The payload): a strict parser of
-- Lua-data-only text that never runs it.

describe("ns.ParsePayload", function()
	local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
	local ns = loaded.ns

	-- The items of `text`, or fails the spec with where and why it didn't parse.
	local function items(text)
		local parsed, at, key, arg = ns.ParsePayload(text)
		assert(parsed, ("%s at byte %s (%s)"):format(tostring(key), tostring(at), tostring(arg)))
		return parsed
	end

	-- Where `text` fails to parse and why: the byte, the ns.L key and its argument.
	local function failure(text)
		local parsed, at, key, arg = ns.ParsePayload(text)
		assert.are.equal(nil, parsed, "it parsed")
		return { at = at, key = key, arg = arg }
	end

	-- A payload of one huntRun item whose `event` field is written `value`.
	local function withEvent(value)
		return '{items={{kind="huntRun",v=1,event=' .. value .. ",},},}"
	end

	describe("over the grammar (PUSH-R20)", function()
		it("reads tables, strings, integers and booleans into plain Lua values, items in payload order", function()
			local read = items(readFile("spec/Pagle/fixtures/content/good.txt"))

			assert.are.equal(4, #read)
			assert.are.same({ "huntEvent", "huntRun", "notice", "huntRun" }, {
				read[1].kind,
				read[2].kind,
				read[3].kind,
				read[4].kind,
			})
			local event = read[1]
			assert.are.same({ 85, 10 }, event.zones)
			assert.are.same({ 75, 150 }, event.skill)
			assert.is_false(event.rotation)
			assert.are.equal('A line with "quotes", a \\ and\na second line.', event.note)
			assert.are.same({ time = { { 1260, 240 } } }, event.hunts[1].conditions)
			assert.are.same({ 20, 50, 100 }, event.hunts[1].tiers)
			assert.are.same(
				{ kind = "huntRun", v = 1, event = "p_test_tide", start = 1791720000, ["end"] = 1791979200 },
				read[2]
			)
		end)

		it("reads an empty list of items, and whitespace and line ends between tokens", function()
			assert.are.same({}, items("{items={},}"))
			assert.are.same({}, items(" \r\n{ items = { } , }\n\t"))
			assert.are.same(
				{ { kind = "a", v = -2, list = {} } },
				items('{\n  items = {\n    { kind = "a", v = -2, list = { }, },\n  },\n}\n')
			)
		end)

		it(
			'reads a field named ["name"], as hunts.md writes huntRun\'s end, and a last element with no comma',
			function()
				assert.are.same(
					{ { kind = "huntRun", v = 1, ["end"] = 5, list = { 1, 2 } } },
					items('{items={{kind="huntRun",v=1,["end"]=5,list={1,2}}}}')
				)
			end
		)

		it('reads only the \\\\, \\" and \\n escapes in a string', function()
			assert.are.equal('\\"\n', items(withEvent('"\\\\\\"\\n"'))[1].event)
			for _, escape in ipairs({ "\\t", "\\065", "\\x41", "\\r", "\\'", "\\z", "\\\n" }) do
				assert.are.equal("PAYLOAD_BAD_ESCAPE", failure(withEvent('"a' .. escape .. '"')).key, escape)
			end
		end)

		it("reads integers up to 15 digits, negative ones too, and nothing else numeric", function()
			assert.are.equal(999999999999999, items(withEvent("999999999999999"))[1].event)
			assert.are.equal(-7, items(withEvent("-7"))[1].event)
			assert.are.equal("PAYLOAD_TOO_LARGE", failure(withEvent("1000000000000000")).key)
			for _, number in ipairs({ "1.5", "1e5", "0x10", "1.", "5_000", "2a" }) do
				assert.are.equal("PAYLOAD_NOT_INTEGER", failure(withEvent(number)).key, number)
			end
			assert.are.equal("PAYLOAD_UNEXPECTED", failure(withEvent(".5")).key)
			assert.are.equal("PAYLOAD_UNEXPECTED", failure(withEvent("- 5")).key)
		end)
	end)

	describe("refusing what isn't Lua data (PUSH-R20)", function()
		it("refuses a function call, at the name being called", function()
			local text = readFile("spec/Pagle/fixtures/content/function-call.txt")
			local failed = failure(text)

			assert.are.same({ at = text:find("print", 1, true), key = "PAYLOAD_NAME_AS_VALUE", arg = "print" }, failed)
		end)

		it("refuses a single-quoted string, at its quote", function()
			local text = readFile("spec/Pagle/fixtures/content/single-quote.txt")
			local failed = failure(text)

			assert.are.same({ at = text:find("'", 1, true), key = "PAYLOAD_UNEXPECTED", arg = "'" }, failed)
		end)

		it("refuses every other piece of Lua syntax", function()
			local cases = {
				{ withEvent("nil"), "PAYLOAD_NAME_AS_VALUE" },
				{ withEvent("x"), "PAYLOAD_NAME_AS_VALUE" },
				{ withEvent("[[long]]"), "PAYLOAD_UNEXPECTED" },
				{ withEvent('"a" .. "b"'), "PAYLOAD_EXPECTED" },
				{ withEvent("function() end"), "PAYLOAD_NAME_AS_VALUE" },
				{ withEvent("1 + 1"), "PAYLOAD_EXPECTED" },
				{ withEvent("-- a comment\n1"), "PAYLOAD_UNEXPECTED" },
				{ withEvent("#t"), "PAYLOAD_UNEXPECTED" },
				{ withEvent("{1;2}"), "PAYLOAD_EXPECTED" },
				{ withEvent("{[1]=2}"), "PAYLOAD_EXPECTED" },
				{ withEvent('{["a b"]=2}'), "PAYLOAD_BAD_NAME" },
				{ withEvent("{a=1,2}"), "PAYLOAD_EXPECTED_FIELD" },
				{ withEvent("{1,a=2}"), "PAYLOAD_MIXED" },
				{ withEvent("{a=1,a=2}"), "PAYLOAD_DUPLICATE" },
				{ withEvent("{a==1}"), "PAYLOAD_NAME_AS_VALUE" },
				{ withEvent('"two\nlines"'), "PAYLOAD_LINE_IN_STRING" },
				{ withEvent('"no end'), "PAYLOAD_UNENDED_STRING" },
				{ withEvent("{,}"), "PAYLOAD_UNEXPECTED" },
				{ withEvent("{1,,}"), "PAYLOAD_UNEXPECTED" },
			}
			for _, case in ipairs(cases) do
				assert.are.equal(case[2], failure(case[1]).key, case[1])
			end
		end)

		it("refuses a payload that isn't one { items = { … }, } table", function()
			local cases = {
				{ "", "PAYLOAD_EXPECTED" },
				{ "return {items={},}", "PAYLOAD_EXPECTED" },
				{ "{}", "PAYLOAD_EXPECTED_FIELD" },
				{ "{other={},}", "PAYLOAD_EXPECTED" },
				{ "{items=1,}", "PAYLOAD_EXPECTED" },
				{ "{items={},other=1,}", "PAYLOAD_EXPECTED" },
				{ "{items={}", "PAYLOAD_ENDED" },
				{ "{items={},} {}", "PAYLOAD_AFTER_TABLE" },
				{ "{items={},};", "PAYLOAD_AFTER_TABLE" },
				{ "{items={1,},}", "PAYLOAD_EXPECTED_ITEM" },
			}
			for _, case in ipairs(cases) do
				assert.are.equal(case[2], failure(case[1]).key, case[1])
			end
		end)

		it('refuses an item that doesn\'t start kind = "[%w_]+", v = <integer>', function()
			for _, item in ipairs({
				"{}",
				'{v=1,kind="huntRun",}',
				'{kind="huntRun",}',
				'{kind="hunt run",v=1,}',
				'{kind="",v=1,}',
				"{kind=1,v=1,}",
				'{kind="huntRun",v="1",}',
				'{kind="huntRun",x=1,v=1,}',
				'{"huntRun",1,}',
			}) do
				local text = "{items={" .. item .. ",},}"
				assert.are.same({ at = 9, key = "PAYLOAD_BAD_ITEM" }, failure(text), item)
			end
		end)

		it("refuses tables nested deeper than PAYLOAD_DEPTH_LIMIT, the payload's own table counting 1", function()
			assert.are.equal(16, ns.PAYLOAD_DEPTH_LIMIT)
			-- The item is at depth 3, so 13 tables inside it reach the limit and 14 pass it.
			local function nested(count)
				return withEvent(("{"):rep(count) .. ("}"):rep(count))
			end

			items(nested(13))
			local start = #'{items={{kind="huntRun",v=1,event=' + 1
			assert.are.same({ at = start + 13, key = "PAYLOAD_TOO_DEEP", arg = 16 }, failure(nested(14)))
		end)

		it("never runs the payload: loadstring, load, loadfile, dofile and setfenv are never called", function()
			local forbidden = { "loadstring", "load", "loadfile", "dofile", "setfenv", "getfenv", "require" }
			local saved = {}
			for _, name in ipairs(forbidden) do
				saved[name] = rawget(loaded.env, name)
				loaded.env[name] = function()
					error(name .. " called", 2)
				end
			end
			finally(function()
				for _, name in ipairs(forbidden) do
					loaded.env[name] = saved[name]
				end
			end)

			items(readFile("spec/Pagle/fixtures/content/good.txt"))
			failure(readFile("spec/Pagle/fixtures/content/function-call.txt"))
			local rules = {}
			for i, name in ipairs(forbidden) do
				rules[i] = { "%f[%w_]" .. name .. "%f[^%w_]", "calls " .. name }
			end
			for _, file in ipairs({ "PushedPayload", "PushedContent" }) do
				local code = withoutComments(readFile("addons/Pagle/logic/" .. file .. ".lua"))
				assert.are.same({}, forbiddenIn(code, rules), file)
			end
		end)
	end)

	it("calls pause every few hundred values, where the check's coroutine yields (PUSH-R10)", function()
		local runs = {}
		for i = 1, 1000 do
			runs[i] = ('{kind="huntRun",v=1,event="e%d",start=%d,},'):format(i, i)
		end
		local pauses = 0
		local parsed = ns.ParsePayload("{items={" .. table.concat(runs) .. "},}", function()
			pauses = pauses + 1
		end)

		assert.are.equal(1000, #parsed)
		-- 1000 items of 5 values each: one pause per 200 values.
		assert.are.equal(25, pauses)
	end)
end)

describe("ns.KeepPushedItems", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	it(
		"keeps huntEvent 1 and huntRun 1 by kind, in payload order, and counts every other kind and version (PUSH-R21)",
		function()
			assert.are.same({ huntEvent = 1, huntRun = 1 }, ns.PUSHED_KINDS)
			local items = {
				{ kind = "huntRun", v = 1, n = 1 },
				{ kind = "notice", v = 1 },
				{ kind = "huntEvent", v = 1, n = 2 },
				{ kind = "huntRun", v = 2 },
				{ kind = "huntRun", v = 1, n = 3 },
				{ kind = "notice", v = 1 },
			}

			local kept, dropped = ns.KeepPushedItems(items)

			assert.are.same({ items[1], items[5] }, kept.huntRun)
			assert.are.same({ items[3] }, kept.huntEvent)
			assert.are.same({ ["notice v1"] = 2, ["huntRun v2"] = 1 }, dropped)
		end
	)
end)
