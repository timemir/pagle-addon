-- The generated catalogue's windows on Pagle (LOG-R55's window part, DATA-R35–R37): every window ID has its spec,
-- with confirmed false (DATA-R56), and Pagle.MatchesConditions takes every one.

-- Each window's spec as DATA-R36 and DATA-R37 give it from the committed data: day and night from windows.toml at
-- VMaNGOS's events 47 and 48 (06:00 and 18:00, each for 1080 minutes, #175), summer and winter from 45 and 46 (20 Mar
-- and 23 Sep, each for 182.5 days), spring and autumn from windows.toml at their Tunables dates, event.301 its event
-- alone.
local EXPECTED = {
	day = { time = { { 360, 0 } } },
	night = { time = { { 1080, 720 } } },
	spring = { season = { { from = { 3, 20 }, to = { 6, 20 } } } },
	summer = { season = { { from = { 3, 20 }, to = { 9, 18 } } } },
	autumn = { season = { { from = { 9, 23 }, to = { 12, 20 } } } },
	winter = { season = { { from = { 9, 23 }, to = { 3, 24 } } } },
	["event.301"] = { events = { 301 } },
}

-- A ConditionsSnapshot (LOG-R20) at `minute` on `month`/`day` of 2026, with `events` active, in The Long Wash.
local function snapshot(minute, month, day, events)
	return {
		time = 1791965670,
		minute = minute,
		date = { year = 2026, month = month, day = day, weekday = 4 },
		zone = 148,
		subzone = 453,
		events = events or {},
		auras = {},
	}
end

-- A window's spec and its confirmed from Pagle.GetWindowSpec. LOG-R55 returns one condition-spec table carrying
-- confirmed; until the M1 review fix to that shape lands, confirmed is the second return.
local function windowSpec(Pagle, windowID)
	local spec, confirmed = Pagle.GetWindowSpec(windowID)
	if spec ~= nil and spec.confirmed ~= nil then
		confirmed = spec.confirmed
	end
	return spec, confirmed
end

describe("the generated catalogue's windows on Pagle", function()
	local Pagle = loadAddon("Pagle", FOREVER_GLOBALS).env.Pagle

	it("give every window ID its spec, unconfirmed (LOG-R55, DATA-R35–R37, DATA-R56)", function()
		local got, want = {}, {}
		for windowID, expected in pairs(EXPECTED) do
			local spec, confirmed = windowSpec(Pagle, windowID)
			local fields = {}
			for field, value in pairs(spec or {}) do
				if field ~= "confirmed" then
					fields[field] = value
				end
			end
			got[windowID] = { spec = fields, confirmed = confirmed }
			want[windowID] = { spec = expected, confirmed = false }
		end
		assert.are.same(want, got)
	end)

	it("give no other window: an event with no weekly rule has none (LOG-R55, DATA-R35)", function()
		assert.is_nil(Pagle.GetWindowSpec("event.14"))
		assert.is_nil(Pagle.GetWindowSpec("dusk"))
	end)

	it("are each a spec Pagle.MatchesConditions accepts (LOG-R48, LOG-R55)", function()
		for windowID in pairs(EXPECTED) do
			local spec = windowSpec(Pagle, windowID)
			assert.has_no_error(function()
				Pagle.MatchesConditions(spec, snapshot(494, 10, 14))
			end)
		end
	end)

	it("match the hours, dates and events they name (LOG-R48)", function()
		local function matches(windowID, s)
			return Pagle.MatchesConditions((windowSpec(Pagle, windowID)), s)
		end
		-- The day runs 06:00 to midnight and the night 18:00 to noon (wrapping past midnight), so they overlap, as
		-- Classic's four 6-hour fishing periods do (#175): 14:00 is day only, 02:00 night only, 08:14 and 20:00 both.
		assert.is_true(matches("day", snapshot(840, 10, 14)))
		assert.is_false(matches("night", snapshot(840, 10, 14)))
		assert.is_true(matches("night", snapshot(120, 10, 14)))
		assert.is_false(matches("day", snapshot(120, 10, 14)))
		assert.is_true(matches("day", snapshot(494, 10, 14)) and matches("night", snapshot(494, 10, 14)))
		assert.is_true(matches("day", snapshot(1200, 10, 14)) and matches("night", snapshot(1200, 10, 14)))
		-- 1 Jul is summer, 10 Jan winter (wrapping the year), 1 Apr spring, 14 Oct autumn and winter.
		assert.is_true(matches("summer", snapshot(494, 7, 1)))
		assert.is_false(matches("winter", snapshot(494, 7, 1)))
		assert.is_true(matches("winter", snapshot(494, 1, 10)))
		assert.is_true(matches("spring", snapshot(494, 4, 1)))
		assert.is_true(matches("autumn", snapshot(494, 10, 14)))
		assert.is_true(matches("winter", snapshot(494, 10, 14)))
		-- event.301 only while the Extravaganza is active.
		assert.is_true(matches("event.301", snapshot(840, 10, 18, { 301 })))
		assert.is_false(matches("event.301", snapshot(840, 10, 18)))
	end)
end)
