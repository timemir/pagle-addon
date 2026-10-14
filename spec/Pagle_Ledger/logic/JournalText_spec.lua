-- The Journal's words with no Core (LED-R126, LED-R127, LED-R161): the realm offset and dates, window labels and
-- states from hand-made Windows, and names and lore through ns.NewJournalText over a hand-made client.

describe("the Journal's words", function()
	local ns = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns

	-- 2026-03-03 00:00:00 UTC, a Tuesday.
	local MARCH_3 = 1772496000
	local HOUR, MINUTE = 3600, 60

	describe("the realm offset", function()
		it(
			"is the realm minute less the server time's UTC minute, rounded to 15 minutes (LED-R126, LOG-R49)",
			function()
				-- 23:50 UTC, realm 01:50 the next day.
				local serverTime = MARCH_3 + 23 * HOUR + 50 * MINUTE

				assert.are.equal(120, ns.RealmOffset(serverTime, 1 * 60 + 50))
			end
		)

		it("rounds a clock a few minutes off to the nearest 15 minutes (LED-R126, LOG-R49)", function()
			-- 15:15 UTC, realm 08:22: −6 h 53 min reads −7 h.
			assert.are.equal(-420, ns.RealmOffset(MARCH_3 + 15 * HOUR + 15 * MINUTE, 8 * 60 + 22))
		end)

		it("takes it after −10 h, up to and including +14 h (LED-R126, LOG-R49)", function()
			local noon = MARCH_3 + 12 * HOUR
			-- Realm 02:00 at 12:00 UTC is +14 h, not −10 h.
			assert.are.equal(14 * 60, ns.RealmOffset(noon, 2 * 60))
			-- Realm 02:15 is −9 h 45 min.
			assert.are.equal(-(9 * 60 + 45), ns.RealmOffset(noon, 2 * 60 + 15))
		end)
	end)

	describe("realm dates", function()
		it("are the day a server time falls on at the realm's offset (LED-R126)", function()
			-- 23:50 UTC on 3 March is 01:50 on 4 March at +2 h, and 16:50 on 3 March at −7 h.
			local serverTime = MARCH_3 + 23 * HOUR + 50 * MINUTE

			assert.are.same({ year = 2026, month = 3, day = 4 }, ns.RealmDateAt(serverTime, 120))
			assert.are.same({ year = 2026, month = 3, day = 3 }, ns.RealmDateAt(serverTime, -420))
			-- Across a year's end: 23:30 UTC on 31 December 2025 is 1 January 2026 at +1 h.
			assert.are.same({ year = 2026, month = 1, day = 1 }, ns.RealmDateAt(1767223800, 60))
		end)

		it('read "{day} {month abbreviation}" in the current realm year (LED-R126)', function()
			assert.are.equal("3 Mar", ns.FormatJournalDate({ year = 2026, month = 3, day = 3 }, 2026))
			assert.are.equal("28 Dec", ns.FormatJournalDate({ year = 2026, month = 12, day = 28 }, 2026))
		end)

		it("add the year in any other year (LED-R126)", function()
			assert.are.equal("3 Mar 2025", ns.FormatJournalDate({ year = 2025, month = 3, day = 3 }, 2026))
			assert.are.equal("1 Jan 2027", ns.FormatJournalDate({ year = 2027, month = 1, day = 1 }, 2026))
		end)

		it('read "…" for a Cast with no realm date (LED-R126)', function()
			assert.are.equal("…", ns.FormatJournalDate(nil, 2026))
		end)
	end)

	describe("window labels", function()
		it("name each named window through ns.L (LED-R127)", function()
			local labels = {}
			for _, id in ipairs({ "day", "night", "spring", "summer", "autumn", "winter" }) do
				labels[#labels + 1] = ns.WindowLabel(id)
			end

			assert.are.same({ "day", "night", "spring", "summer", "autumn", "winter" }, labels)
		end)

		it('call event.301 "Extravaganza" and any other event "event" (LED-R127)', function()
			assert.are.equal("Extravaganza", ns.WindowLabel("event.301"))
			assert.are.equal("event", ns.WindowLabel("event.999"))
		end)

		it('read "…" for an ID that is no window (LED-R126)', function()
			assert.are.equal("…", ns.WindowLabel("dusk"))
		end)
	end)

	describe("window states", function()
		local NOW = MARCH_3 + 12 * HOUR

		it('read "biting now" while the window is open (LED-R127)', function()
			assert.are.equal(
				"biting now",
				ns.WindowState({ openNow = true, closesAt = NOW + HOUR, confirmed = true }, NOW, 0)
			)
		end)

		it('read "back in {n} h", hours rounded up, under 48 h away (LED-R127)', function()
			assert.are.equal("back in 2 h", ns.WindowState({ opensAt = NOW + 90 * MINUTE, confirmed = true }, NOW, 0))
			assert.are.equal("back in 1 h", ns.WindowState({ opensAt = NOW + HOUR, confirmed = true }, NOW, 0))
			assert.are.equal(
				"back in 48 h",
				ns.WindowState({ opensAt = NOW + 48 * HOUR - 1, confirmed = true }, NOW, 0)
			)
		end)

		it('read "back in {n} min", rounded up, under an hour away (LED-R127)', function()
			assert.are.equal(
				"back in 20 min",
				ns.WindowState({ opensAt = NOW + 20 * MINUTE, confirmed = true }, NOW, 0)
			)
			assert.are.equal("back in 1 min", ns.WindowState({ opensAt = NOW + 1, confirmed = true }, NOW, 0))
			assert.are.equal("back in 60 min", ns.WindowState({ opensAt = NOW + HOUR - 1, confirmed = false }, NOW, 0))
		end)

		it('read "back in {month}" of the opening\'s realm date from 48 h away (LED-R127)', function()
			assert.are.equal("back in March", ns.WindowState({ opensAt = NOW + 3 * 86400, confirmed = true }, NOW, 0))
			assert.are.equal("back in March", ns.WindowState({ opensAt = NOW + 48 * HOUR, confirmed = true }, NOW, 0))
			-- 23:00 UTC on 31 March is 1 April at +2 h, and still March at −7 h.
			local opensAt = 1775001600 - HOUR
			local now = opensAt - 3 * 86400
			assert.are.equal("back in April", ns.WindowState({ opensAt = opensAt, confirmed = true }, now, 120))
			assert.are.equal("back in March", ns.WindowState({ opensAt = opensAt, confirmed = true }, now, -420))
		end)

		it("is nil for a nil Window, and for one with no opening (LED-R127)", function()
			assert.is_nil(ns.WindowState(nil, NOW, 0))
			assert.is_nil(ns.WindowState({ always = true, confirmed = true }, NOW, 0))
		end)
	end)

	describe("ns.NewJournalText", function()
		-- A client at 23:50 UTC on 3 March 2026, realm 01:50 (+2 h): Ada and Bo, two zones, one continent map, the
		-- item names in `names`, and night's spec. Each RequestItem is kept in `requested`, and each NextWindow call
		-- answers from `windows` (by the spec's time), counting the calls.
		local function newClient()
			local client = {
				now = MARCH_3 + 23 * HOUR + 50 * MINUTE,
				minute = 1 * 60 + 50,
				names = { [6303] = "Raw Slitherskin Mackerel" },
				requested = {},
				forecasts = 0,
			}
			client.window = { opensAt = client.now + 90 * MINUTE, confirmed = true }
			return client,
				ns.NewJournalText({
					ItemName = function(itemID)
						return client.names[itemID]
					end,
					RequestItem = function(itemID)
						client.requested[#client.requested + 1] = itemID
					end,
					AreaName = function(areaID)
						return ({ [148] = "Darkshore", [1519] = "Stormwind City" })[areaID]
					end,
					MapName = function(uiMapID)
						return ({ [1414] = "Kalimdor", [1415] = "Eastern Kingdoms" })[uiMapID]
					end,
					Characters = function()
						return { { name = "Ada" }, { name = "Bo" } }
					end,
					ServerTime = function()
						return client.now
					end,
					RealmMinute = function()
						return client.minute
					end,
					WindowSpec = function(windowID)
						return ({ night = { time = { from = 1200, to = 360 }, confirmed = true } })[windowID]
					end,
					NextWindow = function(spec, fromTime)
						assert.are.equal(1200, spec.time.from)
						assert.are.equal(client.now, fromTime)
						client.forecasts = client.forecasts + 1
						return client.window
					end,
				})
		end

		describe("item names", function()
			it("come from the client's cache (LED-R126)", function()
				local client, text = newClient()

				assert.are.equal("Raw Slitherskin Mackerel", text:Item(6303))
				assert.are.same({}, client.requested)
			end)

			it('read "…" for an uncached item and request it, once until it arrives (LED-R126)', function()
				local client, text = newClient()

				assert.are.equal("…", text:Item(6358))
				assert.are.equal("…", text:Item(6358))
				assert.are.same({ 6358 }, client.requested)
			end)

			it('read "Item {id}" where the caller asks, as the Uncharted list does (LED-R126)', function()
				local client, text = newClient()

				assert.are.equal("Item 6358", text:Item(6358, true))
				assert.are.equal("Raw Slitherskin Mackerel", text:Item(6303, true))
				assert.are.same({ 6358 }, client.requested)
			end)

			it("say an arrival is worth a redraw only for an item they asked for, once (LED-R126)", function()
				local _, text = newClient()
				text:Item(6358)

				assert.is_false(text:ItemArrived(6359, true))
				assert.is_true(text:ItemArrived(6358, true))
				assert.is_false(text:ItemArrived(6358, true))
			end)

			it("ask again after a failed load, without a redraw for the failure (LED-R126)", function()
				local client, text = newClient()
				text:Item(6358)

				assert.is_false(text:ItemArrived(6358, false))
				text:Item(6358)
				assert.are.same({ 6358, 6358 }, client.requested)
			end)
		end)

		it('names zones from GetAreaInfo, and one it doesn\'t know as "…" (LED-R126)', function()
			local _, text = newClient()

			assert.are.equal("Darkshore", text:Zone(148))
			assert.are.equal("…", text:Zone(0))
		end)

		it(
			'label the Eastern Kingdoms and Kalimdor tabs from GetMapInfo, any other continent "Other waters" (LED-R126)',
			function()
				local _, text = newClient()

				assert.are.equal("Eastern Kingdoms", text:Continent(0))
				assert.are.equal("Kalimdor", text:Continent(1))
				assert.are.equal("Other waters", text:Continent(530))
				assert.are.equal("Other waters", text:Continent(nil))
			end
		)

		it('names characters by index from the Angler, and one it doesn\'t have as "…" (LED-R126)', function()
			local _, text = newClient()

			assert.are.equal("Bo", text:Character(2))
			assert.are.equal("…", text:Character(3))
		end)

		it("print dates against the current realm year, worked out live (LED-R126)", function()
			local client, text = newClient()

			assert.are.equal("3 Mar", text:Date({ year = 2026, month = 3, day = 3 }))
			assert.are.equal("3 Mar 2025", text:Date({ year = 2025, month = 3, day = 3 }))
			-- 23:50 UTC on 31 December 2025 is already 2026 on the +2 h realm.
			client.now, client.minute = 1767225000, 1 * 60 + 50
			assert.are.equal("3 Mar", text:Date({ year = 2026, month = 3, day = 3 }))
		end)

		describe("a window's line", function()
			it('reads "{label}, {state}" from a fresh forecast at each call (LED-R127)', function()
				local client, text = newClient()

				assert.are.equal("night, back in 2 h", text:WindowLine("night"))
				client.window = { openNow = true, confirmed = false }
				assert.are.equal("night, biting now", text:WindowLine("night"))
				assert.are.equal(2, client.forecasts)
			end)

			it("reads the label alone with no state (LED-R127)", function()
				local client, text = newClient()
				client.window = nil

				assert.are.equal("night", text:WindowLine("night"))
			end)

			it("reads the label alone, unforecast, for an ID GetWindowSpec doesn't know (LED-R127)", function()
				local client, text = newClient()

				assert.are.equal("event", text:WindowLine("event.999"))
				assert.are.equal(0, client.forecasts)
			end)

			it("takes the month at the realm's offset (LED-R127)", function()
				local client, text = newClient()
				-- 23:00 UTC on 31 March is 1 April on the +2 h realm.
				client.window = { opensAt = 1775001600 - HOUR, confirmed = true }

				assert.are.equal("night, back in April", text:WindowLine("night"))
			end)

			it("has the label alone on request, unforecast (LED-R127)", function()
				local client, text = newClient()

				assert.are.equal("night", text:WindowLabel("night"))
				assert.are.equal(0, client.forecasts)
			end)
		end)

		describe("lore", function()
			it("returns a key's text (LED-R160)", function()
				local _, text = newClient()
				ns.L["species.6303.riddle"] = "Salt water, short casts."

				assert.are.equal("Salt water, short casts.", text:Lore("species.6303.riddle"))
				ns.L["species.6303.riddle"] = nil
			end)

			it("returns nil for a key with no text, so its line is left out (LED-R161)", function()
				local _, text = newClient()

				assert.is_nil(text:Lore("line.neverwritten.text"))
				assert.is_nil(text:Lore("MONTHS"))
			end)

			it("fills {zone} with the zone's name (LED-R161, DATA-R108)", function()
				local _, text = newClient()
				ns.L["title.zonemaster.text"] = "Master of {zone}"

				assert.are.equal("Master of Darkshore", text:Lore("title.zonemaster.text", 148))
				assert.are.equal("Master of …", text:Lore("title.zonemaster.text", 0))
				ns.L["title.zonemaster.text"] = nil
			end)
		end)
	end)
end)
