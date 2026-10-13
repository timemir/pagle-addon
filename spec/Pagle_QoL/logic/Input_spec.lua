-- Input's pure logic: what each value arms (QOL-R12), the compartment entry's label and cycle (QOL-R16), and
-- `/pagle qol` (QOL-R17).

describe("QoL's Input logic", function()
	local ns = loadAddon("Pagle_QoL", FOREVER_GLOBALS).ns

	describe("what each value arms", function()
		-- Each row: Input, whether the Fishing key is armed, whether the double-click is live.
		local ARMS = {
			{ "key", true, false },
			{ "click", false, true },
			{ "both", true, true },
		}
		for _, row in ipairs(ARMS) do
			it(
				("arms the key: %s, the double-click: %s under %s (QOL-R12)"):format(
					tostring(row[2]),
					tostring(row[3]),
					row[1]
				),
				function()
					assert.are.equal(row[2], ns.InputArmsKey(row[1]))
					assert.are.equal(row[3], ns.InputArmsClick(row[1]))
				end
			)
		end
	end)

	describe("the compartment entry", function()
		it("reads Input: Fishing key, Input: Double-click or Input: Both (QOL-R16)", function()
			assert.are.equal("Input: Fishing key", ns.InputMenuLabel("key"))
			assert.are.equal("Input: Double-click", ns.InputMenuLabel("click"))
			assert.are.equal("Input: Both", ns.InputMenuLabel("both"))
		end)

		it("cycles Both, Fishing key, Double-click, then Both again (QOL-R16)", function()
			local seen = { "both" }
			for i = 1, 3 do
				seen[i + 1] = ns.NextInput(seen[i])
			end

			assert.are.same({ "both", "key", "click", "both" }, seen)
		end)
	end)

	describe("ns.QoLSlash", function()
		-- Runs `/pagle qol <line>` and returns what it set, what it opened and what it printed.
		---@param line string the rest of the line, trimmed, as Core hands it over (CORE-R62)
		---@return string[] set
		---@return string[] opened
		---@return string[] printed
		local function run(line)
			local set, opened, printed = {}, {}, {}
			ns.QoLSlash(line, {
				setInput = function(input)
					set[#set + 1] = input
				end,
				openSettings = function(topic)
					opened[#opened + 1] = topic
				end,
				print = function(text)
					printed[#printed + 1] = text
				end,
			})
			return set, opened, printed
		end

		-- Each row: the argument, the Input it sets, the line it prints (QOL-R17, word for word).
		local INPUTS = {
			{ "key", "key", "Pagle: cast with the Fishing key." },
			{ "click", "click", "Pagle: cast with a double right-click." },
			{ "both", "both", "Pagle: cast with the Fishing key or a double right-click." },
		}
		for _, row in ipairs(INPUTS) do
			it(("sets Input with input %s and says so (QOL-R17)"):format(row[1]), function()
				local set, opened, printed = run("input " .. row[1])

				assert.are.same({ row[2] }, set)
				assert.are.same({}, opened)
				assert.are.same({ row[3] }, printed)
			end)
		end

		it("matches input and its value in any case, with any spacing between (QOL-R17, CORE-R62)", function()
			local set = run("Input   CLICK")

			assert.are.same({ "click" }, set)
		end)

		it("opens the Fishing page with no argument (QOL-R17)", function()
			local set, opened, printed = run("")

			assert.are.same({}, set)
			assert.are.same({ "fishing" }, opened)
			assert.are.same({}, printed)
		end)

		for _, line in ipairs({ "foo", "input", "input foo", "input key both", "key", "inputkey" }) do
			it(("prints the usage line for %q and changes nothing (QOL-R17)"):format(line), function()
				local set, opened, printed = run(line)

				assert.are.same({}, set)
				assert.are.same({}, opened)
				assert.are.same({ "Pagle: /pagle qol input key|click|both" }, printed)
			end)
		end
	end)
end)

describe("ns.ModuleDef with a fake store", function()
	-- QoL's logic with PagleQoLDB never opened: a menu or slash call that read ns.db would fail (CORE-R7).
	local ns = loadAddon("Pagle_QoL", FOREVER_GLOBALS, { holdAddonLoaded = true }).ns

	-- QoL's def over a store holding only Input; returns it, each Input set, each page opened and each line printed.
	---@return PagleModuleDef def
	---@return string[] set
	---@return string[] opened
	---@return string[] printed
	local function define()
		local input, set, opened, printed = "both", {}, {}, {}
		---@type PagleQoLStore
		---@diagnostic disable-next-line: missing-fields -- the menu and /pagle qol read and set only Input
		local store = {
			input = function()
				return input
			end,
			setInput = function(value)
				set[#set + 1] = value
				input = value
			end,
		}
		local def = ns.ModuleDef(function(topic)
			opened[#opened + 1] = topic
		end, function(text)
			printed[#printed + 1] = text
		end, store)
		return def, set, opened, printed
	end

	it("labels and cycles the compartment entry from the store's Input (QOL-R16)", function()
		local def, set = define()
		local entry = def.menu[1]

		assert.are.equal("Input: Both", entry.label())
		entry.onClick()
		assert.are.equal("Input: Fishing key", entry.label())
		entry.onClick()

		assert.are.same({ "key", "click" }, set)
		assert.are.equal("Input: Double-click", entry.label())
		assert.is_nil(ns.db)
	end)

	it("sets Input through the store with /pagle qol input, and opens the Fishing page with none (QOL-R17)", function()
		local def, set, opened, printed = define()
		local qol = def.slash[1]

		qol.fn("input key")
		qol.fn("")

		assert.are.same({ "key" }, set)
		assert.are.same({ "fishing" }, opened)
		assert.are.same({ "Pagle: cast with the Fishing key." }, printed)
	end)
end)
