-- Core's text helper (CORE-R8, DATA-R114): named {fields}, CLDR plural selection and number separators, as pure logic
-- over the active Locale's record. The fixture rules below stand in for the generated ones (#517).

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

--- Fixture plural rules, the CLDR ones for the languages the issue names (n is the count's absolute value).
local RULES = {
	enUS = function(n)
		return n == 1 and "one" or "other"
	end,
	esES = function(n)
		if n == 1 then
			return "one"
		end
		if n ~= 0 and n % 1000000 == 0 then
			return "many"
		end
		return "other"
	end,
	ruRU = function(n)
		local i = math.floor(n)
		if n ~= i then
			return "other"
		end
		local ten, hundred = i % 10, i % 100
		if ten == 1 and hundred ~= 11 then
			return "one"
		end
		if ten >= 2 and ten <= 4 and (hundred < 12 or hundred > 14) then
			return "few"
		end
		return "many"
	end,
	arSA = function(n)
		local i = math.floor(n)
		if n ~= i then
			return "other"
		end
		local hundred = i % 100
		if i == 0 then
			return "zero"
		elseif i == 1 then
			return "one"
		elseif i == 2 then
			return "two"
		elseif hundred >= 3 and hundred <= 10 then
			return "few"
		elseif hundred >= 11 then
			return "many"
		end
		return "other"
	end,
	frFR = function(n)
		if math.floor(n) == 0 or math.floor(n) == 1 then
			return "one"
		end
		if n ~= 0 and n % 1000000 == 0 then
			return "many"
		end
		return "other"
	end,
}

--- A fixture Locale record.
local function locale(rule, decimal, thousands)
	return { plural = rule, decimal = decimal, thousands = thousands }
end

after_each(function()
	ns.SetTextLocale(nil)
end)

describe("named fields", function()
	it("fills a template by name, so a translator can reorder them", function()
		assert.are.equal("2 1", ns.RenderText("{b} {a}", { a = 1, b = 2 }))
		assert.are.equal(
			"Mackerel weighs 3",
			ns.RenderText("{fish} weighs {weight}", { fish = "Mackerel", weight = 3 })
		)
	end)

	it("leaves a missing field as written and ignores an extra one", function()
		assert.are.equal("{b} 1", ns.RenderText("{b} {a}", { a = 1, c = 9 }))
		assert.are.equal("{b:1} {n:n}", ns.RenderText("{b:1} {n:n}", {}))
		assert.are.equal("plain", ns.RenderText("plain"))
	end)

	it(
		"writes a value as tostring makes it: an ID, a name and a pre-formatted length pass through untouched",
		function()
			assert.are.equal(
				"Area 6303 of 34.2 cm",
				ns.RenderText("Area {id} of {len}", { id = 6303, len = "34.2 cm" })
			)
			assert.are.equal("1234567", ns.RenderText("{n}", { n = 1234567 }))
			assert.are.equal("false", ns.RenderText("{b}", { b = false }))
		end
	)

	it("takes a letter, a digit and an underscore as a field name", function()
		assert.are.equal("7 8", ns.RenderText("{zone_2} {Zone}", { zone_2 = 7, Zone = 8 }))
	end)

	it("writes a literal brace as a doubled one, and keeps a brace that starts no field", function()
		assert.are.equal("{count} is a field", ns.RenderText("{{count}} is a field", { count = 3 }))
		assert.are.equal("{ 3 }", ns.RenderText("{ {count} }", { count = 3 }))
		assert.are.equal("{{3}}", ns.RenderText("{{{{{count}}}}}", { count = 3 }))
		assert.are.equal("a } b { c {}", ns.RenderText("a } b { c {}", {}))
		assert.are.equal("{x:zz}", ns.RenderText("{x:zz}", { x = 1 }))
	end)

	it("returns the same string for a template with no braces, and rejects a source that is not text", function()
		assert.are.equal("", ns.RenderText(""))
		assert.has_error(function()
			ns.RenderText(nil)
		end)
	end)
end)

describe("a counted string", function()
	local FISH = { one = "{count} fish", other = "{count} fishes" }

	it("picks English one for 1 and other for the rest, and returns a plain string as it is", function()
		assert.are.same({ "1 fish", "0 fishes", "2 fishes", "1.5 fishes" }, {
			ns.RenderText(FISH, { count = 1 }),
			ns.RenderText(FISH, { count = 0 }),
			ns.RenderText(FISH, { count = 2 }),
			ns.RenderText(FISH, { count = 1.5 }),
		})
		assert.are.equal("Fish: 3", ns.RenderText("Fish: {count}", { count = 3 }))
	end)

	it("falls back to other for a category the string lacks, and for a missing or non-numeric count", function()
		ns.SetTextLocale(locale(RULES.esES, ",", "."))
		local forms = { one = "un pez", other = "{count} peces" }
		assert.are.equal("1000000 peces", ns.RenderText(forms, { count = 1000000 })) -- many, which the string lacks
		assert.are.equal("{count} peces", ns.RenderText(forms, {}))
		assert.are.equal("x peces", ns.RenderText({ other = "x peces" }, { count = "lots" }))
		assert.are.equal("un pez", ns.RenderText(forms, { count = "1" }))
	end)

	it("raises for a counted string with no other form", function()
		assert.has_error(function()
			ns.RenderText({ one = "a" }, { count = 5 })
		end)
	end)

	it("hands the rule the count's absolute value", function()
		local seen
		ns.SetTextLocale(locale(function(n)
			seen = n
			return "other"
		end, ".", ","))
		ns.RenderText({ other = "x" }, { count = -3 })
		assert.are.equal(3, seen)
	end)

	it("selects Spanish one, many and other", function()
		ns.SetTextLocale(locale(RULES.esES, ",", "."))
		local forms = { one = "{count} pez", many = "{count} de peces", other = "{count} peces" }
		assert.are.same({ "1 pez", "2 peces", "0 peces", "1000000 de peces" }, {
			ns.RenderText(forms, { count = 1 }),
			ns.RenderText(forms, { count = 2 }),
			ns.RenderText(forms, { count = 0 }),
			ns.RenderText(forms, { count = 1000000 }),
		})
	end)

	it("selects Russian one, few, many and other", function()
		ns.SetTextLocale(locale(RULES.ruRU, ",", "\194\160"))
		local forms =
			{ one = "{count} рыба", few = "{count} рыбы", many = "{count} рыб", other = "{count} рыбы" }
		local function word(n)
			return ns.RenderText(forms, { count = n })
		end
		assert.are.same({
			"1 рыба",
			"2 рыбы",
			"5 рыб",
			"11 рыб",
			"21 рыба",
			"24 рыбы",
			"112 рыб",
			"1.5 рыбы",
		}, { word(1), word(2), word(5), word(11), word(21), word(24), word(112), word(1.5) })
	end)

	it("selects Arabic from zero to other", function()
		ns.SetTextLocale(locale(RULES.arSA, "٫", "٬"))
		local forms = { zero = "z", one = "o", two = "t", few = "f", many = "m", other = "x" }
		local function word(n)
			return ns.RenderText(forms, { count = n })
		end
		assert.are.same(
			{ "z", "o", "t", "f", "f", "m", "m", "x", "x" },
			{ word(0), word(1), word(2), word(3), word(10), word(11), word(99), word(100), word(1.5) }
		)
	end)

	it("treats 0 and 1 as one in French", function()
		ns.SetTextLocale(locale(RULES.frFR, ",", "\226\128\175"))
		local forms = { one = "{count} poisson", many = "{count} de poissons", other = "{count} poissons" }
		assert.are.same({ "0 poisson", "1 poisson", "1.5 poisson", "2 poissons", "1000000 de poissons" }, {
			ns.RenderText(forms, { count = 0 }),
			ns.RenderText(forms, { count = 1 }),
			ns.RenderText(forms, { count = 1.5 }),
			ns.RenderText(forms, { count = 2 }),
			ns.RenderText(forms, { count = 1000000 }),
		})
	end)

	it("fills the other fields of a counted string too, and formats a count that asks for it", function()
		local forms = { one = "{name} caught {count:n} fish", other = "{name} caught {count:n} fishes" }
		assert.are.equal("Ann caught 1,200 fishes", ns.RenderText(forms, { name = "Ann", count = 1200 }))
	end)
end)

describe("numbers", function()
	it("writes English with a comma for thousands and a point for the decimal", function()
		assert.are.equal("1,234.5", ns.RenderText("{n:n}", { n = 1234.5 }))
		assert.are.equal("1,234.5", ns.FormatNumber(1234.5))
		assert.are.equal("1,234,567", ns.FormatNumber(1234567))
	end)

	it("writes a fixture Locale with the separators swapped", function()
		ns.SetTextLocale(locale(RULES.enUS, ",", "."))
		assert.are.equal("1.234,5", ns.RenderText("{n:n}", { n = 1234.5 }))
		assert.are.equal("1.234.567,00", ns.RenderText("{n:2}", { n = 1234567 }))
	end)

	it("takes a separator of several bytes, and none for thousands", function()
		ns.SetTextLocale(locale(RULES.frFR, ",", "\226\128\175"))
		assert.are.equal("1\226\128\175234,5", ns.FormatNumber(1234.5))
		ns.SetTextLocale(locale(RULES.enUS, ".", ""))
		assert.are.equal("1234567.5", ns.FormatNumber(1234567.5))
	end)

	it("handles negatives, zero and numbers under 1000", function()
		assert.are.same({ "-1,234.5", "0", "7", "999", "1,000", "-0.5", "0.5" }, {
			ns.FormatNumber(-1234.5),
			ns.FormatNumber(0),
			ns.FormatNumber(7),
			ns.FormatNumber(999),
			ns.FormatNumber(1000),
			ns.FormatNumber(-0.5),
			ns.FormatNumber(0.5),
		})
	end)

	it("fixes the decimals a field asks for, rounding, as %.1f and %d do today", function()
		assert.are.same({ "1,234.6", "0.0", "3.0", "1,235", "0", "12.35" }, {
			ns.RenderText("{n:1}", { n = 1234.56 }),
			ns.RenderText("{n:1}", { n = 0 }),
			ns.RenderText("{n:1}", { n = 3 }),
			ns.RenderText("{n:0}", { n = 1234.6 }),
			ns.RenderText("{n:0}", { n = 0.2 }),
			ns.RenderText("{n:2}", { n = 12.346 }),
		})
	end)

	it("leaves no minus sign on a negative that rounds to zero", function()
		assert.are.same(
			{ "0.0", "0", "-0.1" },
			{ ns.FormatNumber(-0.04, 1), ns.FormatNumber(-0.4, 0), ns.FormatNumber(-0.1, 1) }
		)
	end)

	it("reads a number given as a string, and passes any other string through untouched", function()
		assert.are.equal("1,234.5", ns.RenderText("{n:n}", { n = "1234.5" }))
		assert.are.equal("1,234.50", ns.RenderText("{n:2}", { n = "1234.5" }))
		assert.are.equal("34.2 cm", ns.RenderText("{n:1}", { n = "34.2 cm" }))
		assert.are.equal("12345", ns.RenderText("{n}", { n = "12345" }))
	end)

	it("writes a number with no decimals as an integer, and a long fraction without exponent", function()
		assert.are.same(
			{ "10", "1,000,000,000,000", "0.000001", "0.1" },
			{ ns.FormatNumber(10.0), ns.FormatNumber(1e12), ns.FormatNumber(0.000001), ns.FormatNumber(0.1) }
		)
	end)

	it("passes infinity, NaN and a non-number through as tostring makes them", function()
		assert.are.same(
			{ "inf", "-inf", "abc" },
			{ ns.FormatNumber(math.huge), ns.FormatNumber(-math.huge), ns.FormatNumber("abc") }
		)
	end)
end)

describe("the Locale record", function()
	it("is English with none set: one for 1, a comma and a point", function()
		assert.are.equal("1 fish", ns.RenderText({ one = "{count} fish", other = "{count} fishes" }, { count = 1 }))
		assert.are.equal("1,000.5", ns.FormatNumber(1000.5))
	end)

	it("goes back to English when set to nil", function()
		ns.SetTextLocale(locale(RULES.esES, ",", "."))
		ns.SetTextLocale(nil)
		assert.are.equal("1,000.5", ns.FormatNumber(1000.5))
	end)

	it("refuses a record that is not whole and keeps the one it had", function()
		ns.SetTextLocale(locale(RULES.esES, ",", "."))
		for _, bad in ipairs({
			"esES",
			{ decimal = ",", thousands = "." },
			{ plural = RULES.esES, thousands = "." },
			{ plural = RULES.esES, decimal = "", thousands = "." },
			{ plural = RULES.esES, decimal = "," },
			{ plural = "one", decimal = ",", thousands = "." },
		}) do
			assert.has_error(function()
				ns.SetTextLocale(bad)
			end)
		end
		assert.are.equal("1.000,5", ns.FormatNumber(1000.5))
	end)

	it("is copied, so a later change to the record does not change the helper", function()
		local record = locale(RULES.enUS, ",", ".")
		ns.SetTextLocale(record)
		record.decimal = "!"
		assert.are.equal("1.000,5", ns.FormatNumber(1000.5))
	end)
end)

describe("the helper on its own", function()
	it("reads no global but Lua 5.1's pure functions, and works with no Locale and no GetLocale", function()
		local given = {}
		for _, name in ipairs({ "error", "math", "select", "string", "table", "tonumber", "tostring", "type" }) do
			given[name] = _G[name]
		end
		local read = {}
		local env = setmetatable({}, {
			__index = function(_, name)
				read[#read + 1] = name
				return given[name]
			end,
		})
		local own = {}
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1
		local chunk = assert(loadfile("addons/Pagle/logic/Text.lua"))
		setfenv(chunk, env)
		chunk("Pagle", own)

		assert.are.equal("1 fish, 1,234.5", own.RenderText("{a:n}, {b:n}", { a = "1 fish", b = 1234.5 }))
		assert.are.equal("2 fishes", own.RenderText({ one = "{count} fish", other = "{count} fishes" }, { count = 2 }))
		local Pagle = {}
		own.PublishText(Pagle)
		assert.are.equal(own.RenderText, Pagle.Text)
		for _, name in ipairs(read) do
			if given[name] == nil then
				error(name .. " is not a pure Lua 5.1 function")
			end
		end
	end)
end)

describe("Pagle.Text", function()
	it("is on the Module API, in English until a Locale is set", function()
		local fake = newFakePagle()

		assert.are.equal("2 1", fake.Pagle.Text("{b} {a}", { a = 1, b = 2 }))
		assert.are.equal("1,234.5", fake.Pagle.Text("{n:n}", { n = 1234.5 }))
		fake.ns.SetTextLocale(locale(RULES.esES, ",", "."))
		assert.are.equal("1.234,5", fake.Pagle.Text("{n:n}", { n = 1234.5 }))
	end)
end)
