-- Core's case helper (CORE-R8, ADR 0019 "The text helper", #520): upper and lower case and a search fold for UTF-8 text,
-- as pure logic. Latin-1, Latin Extended-A and basic Cyrillic change case; every other script passes through. The
-- literals below are in the spec only: the shipped file builds its tables from code points (CORE-R9).

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

describe("ns.Upper and ns.Lower", function()
	it("map ASCII as the client's do", function()
		assert.are.equal("OILY BLACKMOUTH 12", ns.Upper("Oily Blackmouth 12"))
		assert.are.equal("oily blackmouth 12", ns.Lower("Oily BlackMouth 12"))
	end)

	it("map Latin-1 letters, leaving the sign and the division sign alone", function()
		assert.are.equal("SEÑOR ÜBER ÉCLAIR ÅNGSTRÖM", ns.Upper("señor über éclair ångström"))
		assert.are.equal("señor über éclair ångström", ns.Lower("SEÑOR ÜBER ÉCLAIR ÅNGSTRÖM"))
		assert.are.equal("× ÷", ns.Upper("× ÷"))
		assert.are.equal("× ÷", ns.Lower("× ÷"))
		assert.are.equal("ŸŸŸ", ns.Upper("ŸÿŸ"))
		assert.are.equal("ÿÿÿ", ns.Lower("ŸÿŸ"))
	end)

	it("map Latin Extended-A by its even and odd pairs", function()
		assert.are.equal("ŁÓDŹ", ns.Upper("łódź"))
		assert.are.equal("łódź", ns.Lower("ŁÓDŹ"))
		assert.are.equal("ĀĂĄĆĈĊČĎĐ", ns.Upper("āăąćĉċčďđ"))
		assert.are.equal("ĹĽĿŁŃŇ", ns.Upper("ĺľŀłńň"))
		assert.are.equal("ŅŇŊŌŐŒ", ns.Upper("ņňŋōőœ"))
		assert.are.equal("ŹŻŽ", ns.Upper("źżž"))
		assert.are.equal("źżž", ns.Lower("ŹŻŽ"))
	end)

	it("map basic Cyrillic, with Ukrainian Ґ", function()
		assert.are.equal("РЫБАЛКА ЁЖ ЄЇ", ns.Upper("рыбалка ёж єї"))
		assert.are.equal("рыбалка ёж єї", ns.Lower("РЫБАЛКА ЁЖ ЄЇ"))
		assert.are.equal("ҐЄ", ns.Upper("ґє"))
	end)

	it("pass other scripts through whole", function()
		local text = "釣り 낚시 ΑΒΓ αβγ"
		assert.are.equal(text, ns.Upper(text))
		assert.are.equal(text, ns.Lower(text))
	end)

	it("map a string that mixes scripts letter by letter", function()
		assert.are.equal("FISH ÜBER РЫБА 釣り ŁÓDŹ", ns.Upper("fish über рыба 釣り łódź"))
		assert.are.equal("fish über рыба 釣り łódź", ns.Lower("FISH ÜBER РЫБА 釣り ŁÓDŹ"))
	end)

	it(
		"leave ß, the Turkish dotted and dotless I, the long s and the unpaired Latin Extended-A letters as they are",
		function()
			-- ß has no one-letter capital in the bundled faces (U+1E9E is outside them), and SS would change the length.
			assert.are.equal("STRAßE", ns.Upper("straße"))
			assert.are.equal("straße", ns.Lower("STRAßE"))
			assert.are.equal("İıĸŉſ", ns.Upper("İıĸŉſ"))
			assert.are.equal("İıĸŉſ", ns.Lower("İıĸŉſ"))
		end
	)

	it("keep every byte of text that is not UTF-8 it knows", function()
		assert.are.equal("A\255B", ns.Upper("a\255b"))
		assert.are.equal("a\195", ns.Lower("A\195"))
		assert.are.equal("", ns.Upper(""))
	end)

	it("round-trip a lower-case text through both", function()
		local text = "señor über éclair łódź рыбалка"
		assert.are.equal(text, ns.Lower(ns.Upper(text)))
	end)
end)

describe("ns.UpperFirst", function()
	it("capitalises the first letter, whole code points", function()
		assert.are.equal("Five parts", ns.UpperFirst("five parts"))
		assert.are.equal("Éclair du jour", ns.UpperFirst("éclair du jour"))
		assert.are.equal("Рыба", ns.UpperFirst("рыба"))
		assert.are.equal("1 fish", ns.UpperFirst("1 fish"))
		assert.are.equal("", ns.UpperFirst(""))
	end)
end)

describe("ns.FoldCase", function()
	it("is the lower case of ASCII", function()
		assert.are.equal("oily blackmouth", ns.FoldCase("Oily BLACKMOUTH"))
	end)

	it("drops the accents of Latin-1 and Latin Extended-A letters, so a plain query finds an accented name", function()
		assert.are.equal("cafe", ns.FoldCase("Café"))
		assert.are.equal("senor uber angstrom", ns.FoldCase("Señor ÜBER Ångström"))
		assert.are.equal("lodz", ns.FoldCase("Łódź"))
		assert.are.equal("strasse", ns.FoldCase("Straße"))
		assert.are.equal("aegir oeuvre", ns.FoldCase("Ægir Œuvre"))
	end)

	it("folds a Cyrillic ё to е and otherwise only the case", function()
		assert.are.equal("елка", ns.FoldCase("Ёлка"))
		assert.are.equal("рыбалка", ns.FoldCase("РЫБАЛКА"))
	end)

	it("matches a name by its folded plain substring", function()
		local name = ns.FoldCase("Señor Pescador")
		assert.is_truthy(name:find(ns.FoldCase("SENOR"), 1, true))
		assert.is_truthy(name:find(ns.FoldCase("ñor p"), 1, true))
		assert.is_nil(name:find(ns.FoldCase("sener"), 1, true))
	end)

	it("passes other scripts through", function()
		assert.are.equal("釣り 낚시", ns.FoldCase("釣り 낚시"))
	end)
end)

describe("the case helper as pure logic", function()
	it("loads and runs with Lua 5.1's string functions alone, and reads no ns.L", function()
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
		local chunk = assert(loadfile("addons/Pagle/logic/Case.lua"))
		setfenv(chunk, env)
		chunk("Pagle", own)

		assert.are.equal("ÜBER", own.Upper("über"))
		assert.are.equal("uber", own.FoldCase("Über"))
		local Pagle = {}
		own.PublishCase(Pagle)
		assert.are.equal(own.Upper, Pagle.Upper)
		assert.are.equal(own.Lower, Pagle.Lower)
		assert.are.equal(own.FoldCase, Pagle.FoldCase)
		for _, name in ipairs(read) do
			if given[name] == nil then
				error(name .. " is not a pure Lua 5.1 function")
			end
		end
	end)
end)

describe("Pagle.Upper, Pagle.Lower and Pagle.FoldCase", function()
	it("are on the Module API (API version 2)", function()
		local fake = newFakePagle()

		assert.are.equal("ÑANDÚ", fake.Pagle.Upper("ñandú"))
		assert.are.equal("ñandú", fake.Pagle.Lower("ÑANDÚ"))
		assert.are.equal("nandu", fake.Pagle.FoldCase("Ñandú"))
		assert.is_true(fake.Pagle.API_VERSION >= 2)
	end)
end)
