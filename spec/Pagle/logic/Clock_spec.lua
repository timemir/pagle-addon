-- The clock format (CORE-R87): how a time of day reads, "18:05" or "6:05 pm", as pure logic over the stored choice
-- and the game's clock CVar, timeMgrUseMilitaryTime.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

describe("a clock time", function()
	it("reads 24-hour with two-digit hours: 00:00, 00:05, 12:00, 18:30, 23:59 (CORE-R87)", function()
		assert.are.same({ "00:00", "00:05", "12:00", "18:30", "23:59" }, {
			ns.FormatClock(0, 0, "24h"),
			ns.FormatClock(0, 5, "24h"),
			ns.FormatClock(12, 0, "24h"),
			ns.FormatClock(18, 30, "24h"),
			ns.FormatClock(23, 59, "24h"),
		})
	end)

	it(
		"reads 12-hour without a leading zero: midnight 12:00 am, 12:05 am, 9:07 am, noon 12:00 pm, 6:30 pm,"
			.. " 11:59 pm (CORE-R87)",
		function()
			assert.are.same({ "12:00 am", "12:05 am", "9:07 am", "12:00 pm", "6:30 pm", "11:59 pm" }, {
				ns.FormatClock(0, 0, "12h"),
				ns.FormatClock(0, 5, "12h"),
				ns.FormatClock(9, 7, "12h"),
				ns.FormatClock(12, 0, "12h"),
				ns.FormatClock(18, 30, "12h"),
				ns.FormatClock(23, 59, "12h"),
			})
		end
	)

	it("takes the hour mod 24, so 24:00, a day's end, reads as midnight (CORE-R87)", function()
		assert.are.same({ "00:00", "12:00 am" }, { ns.FormatClock(24, 0, "24h"), ns.FormatClock(24, 0, "12h") })
	end)
end)

describe("the clock format", function()
	it("is the stored one, whatever the game's clock (CORE-R87)", function()
		assert.are.same({ "24h", "12h", "24h", "12h" }, {
			ns.ClockFormatOf("24h", "0"),
			ns.ClockFormatOf("12h", "1"),
			ns.ClockFormatOf("24h", nil),
			ns.ClockFormatOf("12h", nil),
		})
	end)

	it(
		"follows the game's clock with none stored: 12-hour only when timeMgrUseMilitaryTime is 0, 24-hour when it"
			.. " is 1 or missing (CORE-R87)",
		function()
			assert.are.same(
				{ "12h", "24h", "24h" },
				{ ns.ClockFormatOf(nil, "0"), ns.ClockFormatOf(nil, "1"), ns.ClockFormatOf(nil, nil) }
			)
		end
	)

	it("treats a stored value that isn't 24h or 12h as no choice: the game's clock (CORE-R87)", function()
		assert.are.same({ "12h", "24h" }, { ns.ClockFormatOf("game", "0"), ns.ClockFormatOf(12, "1") })
	end)

	it("lists the Clock row's choices in order: the game's clock, 24-hour, 12-hour (SET-R10)", function()
		assert.are.same({ "game", "24h", "12h" }, ns.CLOCK_CHOICES)
	end)
end)
