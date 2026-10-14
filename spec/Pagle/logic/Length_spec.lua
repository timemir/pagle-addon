-- The length unit (LOG-R69): how a length in millimetres reads, "34.2 cm" or "13.5 in", in the Angler's unit or the
-- region default, as pure logic over the stored unit and GetCurrentRegion()'s answer.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

describe("a length", function()
	it("reads 342 mm as 34.2 cm in centimetres and 13.5 in in inches, to 0.1 of the unit (LOG-R69)", function()
		assert.are.same({ "34.2 cm", "13.5 in" }, { ns.FormatLength(342, "cm"), ns.FormatLength(342, "in") })
	end)

	it("keeps the tenth when it is 0, and reads 254 mm as 10.0 in (LOG-R69)", function()
		assert.are.same({ "30.0 cm", "10.0 in" }, { ns.FormatLength(300, "cm"), ns.FormatLength(254, "in") })
	end)
end)

describe("the length unit", function()
	it("is the stored one, whatever the region (LOG-R69)", function()
		assert.are.same({ "cm", "in" }, { ns.LengthUnitOf("cm", 1), ns.LengthUnitOf("in", 3) })
	end)

	it(
		"defaults to inches on region 1 and to centimetres otherwise, including when GetCurrentRegion is missing (LOG-R69)",
		function()
			assert.are.same(
				{ "in", "cm", "cm", "cm" },
				{ ns.LengthUnitOf(nil, 1), ns.LengthUnitOf(nil, 3), ns.LengthUnitOf(nil, 2), ns.LengthUnitOf(nil, nil) }
			)
		end
	)

	it("treats a stored value that isn't cm or in as no choice: the region default (LOG-R69)", function()
		assert.are.same({ "in", "cm" }, { ns.LengthUnitOf("ft", 1), ns.LengthUnitOf("ft", 3) })
	end)
end)

describe("a length margin", function()
	it("reads +4.2 cm for 42 mm in centimetres and +1.7 in in inches (ANN-R22, LOG-R69)", function()
		assert.are.same({ "+4.2 cm", "+1.7 in" }, { ns.FormatLengthMargin(42, "cm"), ns.FormatLengthMargin(42, "in") })
	end)

	it("reads +<0.1 when it rounds to zero in the unit (ANN-R22)", function()
		assert.are.same(
			{ "+<0.1 in", "+<0.1 cm", "+<0.1 in" },
			{ ns.FormatLengthMargin(0.2, "in"), ns.FormatLengthMargin(0.4, "cm"), ns.FormatLengthMargin(1.2, "in") }
		)
	end)

	it("shows the tenth once the margin rounds to it (ANN-R22)", function()
		assert.are.same({ "+0.1 cm", "+0.1 in" }, { ns.FormatLengthMargin(1, "cm"), ns.FormatLengthMargin(2.54, "in") })
	end)
end)
