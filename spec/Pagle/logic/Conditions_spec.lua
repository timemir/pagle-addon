-- Condition specs and Pagle.MatchesConditions (LOG-R48, LOG-R49), through the Pagle global Modules call.

local Pagle = loadAddon("Pagle", FOREVER_GLOBALS).env.Pagle

-- Marks a snapshot field as nil (secret or unknown) in snapshot()'s overrides.
local NONE = {}

-- A ConditionsSnapshot (LOG-R20, LOG-R45): The Long Wash (148/453) at realm 08:14 on Wednesday 14 Oct 2026, skill
-- 86+25 with lure 263, no listed event or aura. `fields` overrides any of these; NONE makes one nil.
local function snapshot(fields)
	local s = {
		time = 1791731747,
		minute = 494,
		date = { year = 2026, month = 10, day = 14, weekday = 4 },
		zone = 148,
		subzone = 453,
		skillRank = 86,
		skillMod = 25,
		lure = 263,
		events = {},
		auras = {},
	}
	for key, value in pairs(fields or {}) do
		if value == NONE then
			s[key] = nil
		else
			s[key] = value
		end
	end
	return s
end

describe("Pagle.MatchesConditions", function()
	it("matches any snapshot with an empty spec: an absent field doesn't constrain (LOG-R48)", function()
		assert.is_true(Pagle.MatchesConditions({}, snapshot()))
	end)

	describe("areas", function()
		it("matches when the zone or the subzone is one of them (LOG-R48)", function()
			assert.is_true(Pagle.MatchesConditions({ areas = { 148 } }, snapshot()))
			assert.is_true(Pagle.MatchesConditions({ areas = { 453 } }, snapshot()))
			assert.is_true(Pagle.MatchesConditions({ areas = { 12, 453 } }, snapshot()))
		end)

		it("doesn't match when neither is (LOG-R48)", function()
			assert.is_false(Pagle.MatchesConditions({ areas = { 12, 40 } }, snapshot()))
		end)

		it("never matches a 0 zone or subzone (LOG-R48)", function()
			assert.is_false(Pagle.MatchesConditions({ areas = { 148 } }, snapshot({ zone = 0, subzone = 0 })))
		end)

		it("never matches a nil zone or subzone (LOG-R48)", function()
			assert.is_false(Pagle.MatchesConditions({ areas = { 148 } }, snapshot({ zone = NONE, subzone = NONE })))
		end)
	end)

	describe("time", function()
		local function atMinute(spec, minute)
			return Pagle.MatchesConditions({ time = spec }, snapshot({ minute = minute }))
		end

		it("matches from `from`, inclusive, up to `to`, exclusive (LOG-R48)", function()
			local day = { { 360, 1080 } } -- 06:00 to 18:00
			assert.is_false(atMinute(day, 359))
			assert.is_true(atMinute(day, 360))
			assert.is_true(atMinute(day, 1079))
			assert.is_false(atMinute(day, 1080))
		end)

		it("wraps past midnight when `to` < `from` (LOG-R48)", function()
			local night = { { 1080, 360 } } -- 18:00 to 06:00
			assert.is_false(atMinute(night, 1079))
			assert.is_true(atMinute(night, 1080))
			assert.is_true(atMinute(night, 1439))
			assert.is_true(atMinute(night, 0))
			assert.is_true(atMinute(night, 359))
			assert.is_false(atMinute(night, 360))
			assert.is_false(atMinute(night, 720))
		end)

		it("ends at midnight with `to` = 0 (LOG-R48, DATA-R36)", function()
			assert.is_true(atMinute({ { 1200, 0 } }, 1439))
			assert.is_false(atMinute({ { 1200, 0 } }, 0))
		end)

		it("matches a minute in any of its ranges (LOG-R48)", function()
			local twilight = { { 300, 420 }, { 1080, 1200 } }
			assert.is_true(atMinute(twilight, 350))
			assert.is_true(atMinute(twilight, 1100))
			assert.is_false(atMinute(twilight, 720))
		end)

		it("matches midnight, minute 0, like any other minute (LOG-R48)", function()
			assert.is_true(atMinute({ { 0, 60 } }, 0))
		end)

		it("never matches a nil realm minute (LOG-R48)", function()
			assert.is_false(atMinute({ { 0, 1439 } }, NONE))
		end)
	end)

	describe("season", function()
		local function onDate(spec, month, day)
			local date = { year = 2026, month = month, day = day, weekday = 1 }
			return Pagle.MatchesConditions({ season = spec }, snapshot({ date = date }))
		end

		it("matches from `from` to `to`, both days inclusive (LOG-R48)", function()
			local summer = { { from = { 6, 21 }, to = { 9, 22 } } }
			assert.is_false(onDate(summer, 6, 20))
			assert.is_true(onDate(summer, 6, 21))
			assert.is_true(onDate(summer, 7, 31))
			assert.is_true(onDate(summer, 9, 22))
			assert.is_false(onDate(summer, 9, 23))
		end)

		it("wraps the year when `to` < `from` (LOG-R48)", function()
			local winter = { { from = { 12, 21 }, to = { 3, 19 } } }
			assert.is_false(onDate(winter, 12, 20))
			assert.is_true(onDate(winter, 12, 21))
			assert.is_true(onDate(winter, 12, 31))
			assert.is_true(onDate(winter, 1, 1))
			assert.is_true(onDate(winter, 3, 19))
			assert.is_false(onDate(winter, 3, 20))
			assert.is_false(onDate(winter, 7, 1))
		end)

		it("matches a date in any of its ranges (LOG-R48)", function()
			local solstices = { { from = { 6, 20 }, to = { 6, 22 } }, { from = { 12, 20 }, to = { 12, 22 } } }
			assert.is_true(onDate(solstices, 6, 21))
			assert.is_true(onDate(solstices, 12, 22))
			assert.is_false(onDate(solstices, 9, 21))
		end)
	end)

	-- events and auras test the snapshot's lists the same way.
	for _, field in ipairs({ "events", "auras" }) do
		describe(field, function()
			local function with(spec, active)
				return Pagle.MatchesConditions({ [field] = spec }, snapshot({ [field] = active }))
			end

			it("matches when any of them is active (LOG-R48)", function()
				assert.is_true(with({ 301 }, { 301 }))
				assert.is_true(with({ 7, 301 }, { 2, 301 }))
			end)

			it("doesn't match when none of them is active (LOG-R48)", function()
				assert.is_false(with({ 301 }, {}))
				assert.is_false(with({ 301, 7 }, { 2 }))
			end)

			it("never matches a nil list (LOG-R48)", function()
				assert.is_false(with({ 301 }, NONE))
			end)
		end)
	end

	describe("lure", function()
		local function withLure(spec, lure)
			return Pagle.MatchesConditions({ lure = spec }, snapshot({ lure = lure }))
		end

		it("`true` matches any lure (LOG-R48)", function()
			assert.is_true(withLure(true, 263))
			assert.is_true(withLure(true, 264))
		end)

		it("a list matches one of its enchant IDs (LOG-R48)", function()
			assert.is_true(withLure({ 263, 264 }, 264))
			assert.is_false(withLure({ 263, 264 }, 265))
		end)

		it("never matches a nil or 0 lure, whether `true` or a list (LOG-R48)", function()
			for _, none in ipairs({ NONE, 0 }) do
				assert.is_false(withLure(true, none))
				assert.is_false(withLure({ 263 }, none))
			end
		end)
	end)

	describe("skill", function()
		local function withSkill(min, rank, mod)
			return Pagle.MatchesConditions({ skill = { min = min } }, snapshot({ skillRank = rank, skillMod = mod }))
		end

		it("matches when rank + modifier is at least `min` (LOG-R48)", function()
			assert.is_true(withSkill(111, 86, 25))
			assert.is_true(withSkill(100, 86, 25))
			assert.is_false(withSkill(112, 86, 25))
			assert.is_true(withSkill(86, 86, 0))
		end)

		it("never matches a nil or 0 rank (LOG-R48)", function()
			assert.is_false(withSkill(1, NONE, 25))
			assert.is_false(withSkill(1, 0, 25))
		end)

		it("never matches a nil modifier, since it can't tell the effective skill (LOG-R48)", function()
			assert.is_false(withSkill(1, 86, NONE))
		end)
	end)

	it("needs every field to match: fields combine with AND (LOG-R48)", function()
		local spec = { areas = { 148 }, time = { { 360, 600 } }, lure = true }
		assert.is_true(Pagle.MatchesConditions(spec, snapshot()))
		assert.is_false(Pagle.MatchesConditions(spec, snapshot({ zone = 12, subzone = 0 })))
		assert.is_false(Pagle.MatchesConditions(spec, snapshot({ minute = 700 })))
		assert.is_false(Pagle.MatchesConditions(spec, snapshot({ lure = NONE })))
	end)

	describe("with an invalid spec", function()
		local function rejects(spec, why)
			assert.error_matches(function()
				Pagle.MatchesConditions(spec, snapshot())
			end, "invalid condition spec: " .. why, 1, true)
		end

		it("raises an error for an empty list in any field (LOG-R48)", function()
			for _, field in ipairs({ "areas", "time", "season", "events", "auras", "lure" }) do
				rejects({ [field] = {} }, field .. " is an empty list")
			end
		end)

		it("raises an error for a time range with from == to (LOG-R48)", function()
			rejects({ time = { { 360, 1080 }, { 600, 600 } } }, "time[2] has from == to")
		end)

		it("raises an error for a season range with from == to (LOG-R48)", function()
			rejects({ season = { { from = { 3, 1 }, to = { 3, 1 } } } }, "season[1] has from == to")
		end)

		it("raises an error even when the snapshot would fail an earlier field (LOG-R48)", function()
			rejects({ areas = { 12 }, time = { { 600, 600 } } }, "time[1] has from == to")
		end)

		it("raises an error for a field LOG-R48 doesn't define, such as pools or weather (LOG-R48)", function()
			rejects({ weather = { 1 } }, "weather is not a condition field")
			rejects({ pools = { 1 } }, "pools is not a condition field")
		end)

		it("raises an error for a value of the wrong shape (LOG-R48)", function()
			rejects({ areas = 148 }, "areas must be a list of IDs")
			rejects({ areas = { 148, "453" } }, "areas must be a list of IDs")
			rejects({ events = { 0 } }, "events must be a list of IDs")
			rejects({ lure = false }, "lure must be true or a list of IDs")
			rejects({ time = { { 360 } } }, "time[1] must be { from, to } realm minutes of day")
			rejects({ time = { { 360, 1440 } } }, "time[1] must be { from, to } realm minutes of day")
			rejects({ time = { { -1, 60 } } }, "time[1] must be { from, to } realm minutes of day")
			rejects({ season = { { from = { 13, 1 }, to = { 1, 1 } } } }, "season[1] must be")
			rejects({ season = { { from = { 2, 30 }, to = { 3, 1 } } } }, "season[1] must be")
			rejects({ season = { { from = { 2, 1 } } } }, "season[1] must be")
			rejects({ skill = 100 }, "skill must be { min = n }")
			rejects({ skill = { min = "100" } }, "skill must be { min = n }")
			rejects({ skill = { min = 100, max = 200 } }, "skill must be { min = n }")
		end)

		it("raises an error when the spec isn't a table (LOG-R48)", function()
			rejects("night", "it must be a table")
		end)
	end)
end)
