-- A Hunt's entry as data (HNT-R3, HNT-R17, HNT-R18, HNT-R26, HNT-R27, HNT-R64, HNT-R65, HNT-R66, HNT-R69): each line's
-- text and state from logic/Entry.lua, its inputs passed in: the fixture Hunt list, hand-made progress, where it
-- bites and the grouping's row, and name lookups as stand-ins (adapter/Names.lua builds the real ones).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local HOUR = hunts.HOUR
-- Sunday 11 October 2026 at realm 08:15 (FakePagle's clock), fished in Darkshore.
local NOW = SERVER_TIME
local SUNDAY = hunts.deepCopy(hunts.SUNDAY)
SUNDAY.zone = hunts.catalogue.DARKSHORE

local AREAS, ITEMS = hunts.catalogue.NAMES.areas, hunts.catalogue.NAMES.items

---@type HuntNameSources
local SOURCES = {
	ItemName = function(itemID)
		return ITEMS[itemID]
	end,
	ItemIcon = function()
		return nil
	end,
	AreaName = function(areaID)
		return AREAS[areaID]
	end,
	AuraName = function()
		return "Fishing Camp"
	end,
	EventName = function()
		return nil
	end,
	BandName = function()
		return "Hefty"
	end,
	QualityColor = function()
		return nil
	end,
	NextWindow = function()
		return nil
	end,
}

-- A tier reached on realm date 12 October 2026 (or `day`) in `zone`.
local function tier(zone, day)
	return {
		time = NOW,
		catchId = "c1",
		itemID = 13759,
		zone = zone,
		date = { year = 2026, month = 10, day = day or 12 },
	}
end

-- Progress with `count` qualifying Catches and the tiers in `reached`.
local function progress(count, effort, sinceLast, reached)
	return { count = count, effort = effort, sinceLast = sinceLast, caught = count > 0, reached = reached or {} }
end

-- Where a Hunt bites with no waters, no skill need and nothing unconfirmed, over `fields`.
local function where(fields)
	local out = { waters = {}, isWater = {}, places = {}, zones = {} }
	for key, value in pairs(fields or {}) do
		out[key] = value
	end
	return out
end

describe("a Hunt's entry", function()
	local ns = hunts.load().ns

	-- The entry of fixture Hunt `huntID` with `fields` over a plain input: not updating, not pinned, on the Board.
	local function entry(huntID, fields)
		local input = {
			hunt = ns.hunts:Hunt(huntID),
			list = ns.hunts,
			where = where(),
			state = ns.NewHuntsState(),
			updating = false,
			pinned = false,
			now = NOW,
			snapshot = SUNDAY,
			best = 300,
			sources = SOURCES,
		}
		for key, value in pairs(fields or {}) do
			input[key] = value
		end
		return ns.HuntEntry(input)
	end

	-- `state` with `huntProgress` for Hunt `huntID`.
	local function stateWith(huntID, huntProgress)
		local state = ns.NewHuntsState()
		state.hunts[huntID] = huntProgress
		return state
	end

	describe("the seal, the ladder and the effort counter (HNT-R64, HNT-R17, HNT-R26)", function()
		it("seals a done Hunt 'Hunted {full date}', fills tier 1 with its date and zone, and inks '1 / 10'", function()
			local state = stateWith("fixture_snapper", progress(1, 96, 11, { tier(148) }))

			local e = entry("fixture_snapper", { state = state })

			assert.are.same(
				{ text = "Hunted 12 Oct 2026", filled = true, lines = { "Hunted", "12 Oct", "2026" } },
				e.seal
			)
			assert.are.same({
				{ tier = 1, threshold = 1, reached = true, when = "12 Oct, Darkshore" },
				{ tier = 2, threshold = 10, reached = false },
				{ tier = 3, threshold = 40, reached = false },
			}, e.ladder.tiers)
			assert.are.same({ fill = 0.1, label = "1 / 10" }, e.ladder.bar)
			assert.are.equal("96 Casts under these conditions, 11 since my last one.", e.effort.text)
			assert.are.equal("Odds live in Stats.", e.effort.odds)
		end)

		it("seals an undone Hunt with a dashed 'not yet' and counts only its effort Casts (HNT-R26)", function()
			local state = stateWith("fixture_snapper", progress(0, 96, 96))

			local e = entry("fixture_snapper", { state = state })

			assert.are.same({ text = "not yet", filled = false }, e.seal)
			assert.is_false(e.ladder.tiers[1].reached)
			assert.are.same({ fill = 0, label = "0 / 1" }, e.ladder.bar)
			assert.are.equal("96 Casts under these conditions.", e.effort.text)
		end)

		it("reads a Hunt nothing has touched as no Casts and no tier", function()
			local e = entry("fixture_snapper")

			assert.are.same({ text = "not yet", filled = false }, e.seal)
			assert.are.same({ fill = 0, label = "0 / 1" }, e.ladder.bar)
			assert.are.equal("0 Casts under these conditions.", e.effort.text)
		end)

		it("says '1 Cast' for a single effort Cast", function()
			local state = stateWith("fixture_snapper", progress(1, 1, 0, { tier(148) }))

			assert.are.equal(
				"1 Cast under these conditions, 0 since my last one.",
				entry("fixture_snapper", {
					state = state,
				}).effort.text
			)
		end)

		it("dates a tier with no zone name when its Catch's zone was 0, and '…' for a name not known", function()
			local state = stateWith("fixture_snapper", progress(10, 30, 2, { tier(0, 3), tier(9999, 20) }))

			local tiers = entry("fixture_snapper", { state = state }).ladder.tiers

			assert.are.equal("3 Oct", tiers[1].when)
			assert.are.equal("20 Oct, …", tiers[2].when)
		end)

		it("reads a finished Hunt's count, '52 caught', on a full ink bar (HNT-R16, HNT-R17)", function()
			local state = stateWith("fixture_oddity", progress(52, 400, 3, { tier(148), tier(148) }))

			local e = entry("fixture_oddity", { state = state })

			assert.are.same({ fill = 1, label = "52 caught" }, e.ladder.bar)
			assert.is_true(e.ladder.tiers[2].reached)
		end)
	end)

	describe("its heading, window and conditions lines and set line (HNT-R64, HNT-R52–R54)", function()
		local NIGHT = { time = { { 1200, 360 } } }

		it("heads it with the set and the kind, the Hunt's name and its target line", function()
			local natural = entry("fixture_snapper")
			local imposed = entry("fixture_oddity")

			assert.are.same(
				{ "Dusk · Natural", "Snapper Run", "Raw Nightfin Snapper" },
				{ natural.kicker, natural.name, natural.target }
			)
			assert.are.same(
				{ "Wagers · Imposed", "Oddity Hour", "Deviate Fish or Whimsyfin" },
				{ imposed.kicker, imposed.name, imposed.target }
			)
		end)

		it("writes the window line from its row and the conditions line from its board spec", function()
			local row =
				{ group = "soon", auraUp = false, window = { opensAt = NOW + 37 * 60, closesAt = NOW + 10 * HOUR } }

			local e = entry("fixture_snapper", { row = row, where = where({ boardSpec = NIGHT }) })

			assert.are.equal("Opens in 37m, at 08:52.", e.window)
			assert.are.equal("Night 20:00–06:00", e.conditions)
		end)

		it("adds the skill need to the window line when short of skill, and the lure within its reach", function()
			-- The row as the grouping makes it: short, and the lure reaches (HNT-R33).
			local row = {
				group = "later",
				auraUp = false,
				short = true,
				lureGetsThere = true,
				window = { opensAt = NOW + 37 * 60, closesAt = NOW + 10 * HOUR },
			}

			local e = entry(
				"fixture_snapper",
				{ row = row, where = where({ boardSpec = NIGHT, skillNeed = 225 }), best = 180 }
			)

			assert.are.equal("Opens in 37m, at 08:52. Needs 225; my best is 180. A lure gets me there.", e.window)
		end)

		it("leaves out the window line with no row yet, and the conditions line with no board spec (HNT-R7)", function()
			local e = entry("fixture_snapper")

			assert.is_nil(e.window)
			assert.is_nil(e.conditions)
		end)

		it("counts the set's done current Hunts in the set line, toward the title or after it (HNT-R20)", function()
			-- fixture_dusk: Snapper Run and Hefty Blackmouth are current, Old Sunscale retired on 1 June.
			local state = stateWith("fixture_snapper", progress(1, 5, 0, { tier(148) }))
			state.hunts.fixture_sunscale = progress(1, 5, 0, { tier(148) })

			assert.are.equal(
				"Dusk: 1 of 2 · earns the Duskwatcher",
				entry("fixture_snapper", { state = state }).setLine
			)
			state.sets.fixture_dusk =
				{ earnedAt = NOW, date = { year = 2026, month = 10, day = 12 }, fromRetirement = false }
			assert.are.equal(
				"Dusk: 1 of 2 · earned the Duskwatcher",
				entry("fixture_snapper", { state = state }).setLine
			)
		end)

		it("carries the pin toggle's state (HNT-R80)", function()
			assert.are.same({ pinned = false }, entry("fixture_snapper").pin)
			assert.are.same({ pinned = true }, entry("fixture_snapper", { pinned = true }).pin)
		end)
	end)

	describe("chips (HNT-R65)", function()
		-- The chips' kinds and words, in order.
		local function words(chips)
			local out = {}
			for i, chip in ipairs(chips) do
				out[i] = chip.kind .. ": " .. chip.text
			end
			return out
		end

		it("shows up to 3 zones, the live zone first with 'you're here', then '+N more' listing the rest", function()
			-- The live zone is Darkshore (148), fourth in ID order; Oddity Hour and its set have no notes.
			local e = entry("fixture_oddity", { where = where({ zones = { 10, 12, 40, 148, 331 } }) })

			assert.are.same(
				{ "zone: Darkshore", "zone: Duskwood", "zone: Elwynn Forest", "more: +2 more" },
				words(e.chips)
			)
			assert.are.same({ true, "you're here" }, { e.chips[1].here, e.chips[1].badge })
			assert.is_nil(e.chips[2].here)
			assert.are.same({ "Westfall", "Ashenvale" }, e.chips[4].tooltip)
		end)

		it("keeps the zones' order (HNT-R31), no badge off the live zone, and no '+N more' for 3", function()
			local e = entry("fixture_oddity", { where = where({ zones = { 12, 40, 331 } }) })

			assert.are.same({ "zone: Elwynn Forest", "zone: Westfall", "zone: Ashenvale" }, words(e.chips))
			assert.is_nil(e.chips[1].here)
		end)

		it("shows the skill need, or 'needs 225, best: 180' in red when short of skill (HNT-R33)", function()
			local enough = entry("fixture_oddity", { where = where({ skillNeed = 225 }), best = 225 })
			local short = entry("fixture_oddity", { where = where({ skillNeed = 225 }), best = 180 })

			assert.are.same({ "skill: skill 225" }, words(enough.chips))
			assert.is_falsy(enough.chips[1].short)
			assert.are.same({ "skill: needs 225, best: 180" }, words(short.chips))
			assert.is_true(short.chips[1].short)
		end)

		it("says 'needs a lure' when the board spec has lure", function()
			local e = entry("fixture_oddity", { where = where({ boardSpec = { lure = true } }) })

			assert.are.same({ "lure: needs a lure" }, words(e.chips))
		end)

		it("shows the Hunt's note, then its set's", function()
			assert.are.same(
				{ "note: Keeps late hours.", "note: After the lamps are lit." },
				words(entry("fixture_snapper").chips)
			)
			assert.are.same({ "note: After the lamps are lit." }, words(entry("fixture_hefty_blackmouth").chips))
		end)

		it(
			"marks it unconfirmed with the window's tooltip, or the gating's when only the gating is (HNT-R34)",
			function()
				-- ns.Unconfirmed's reason (logic/Waters.lua): "window" when the window or a weekly rule is, "gating" when only that is.
				local estimate = entry("fixture_oddity", { unconfirmed = "window" })
				local gating = entry("fixture_oddity", { unconfirmed = "gating" })

				assert.are.same({ "unconfirmed: unconfirmed" }, words(estimate.chips))
				assert.are.same({ "This window is an estimate." }, estimate.chips[1].tooltip)
				assert.are.same({ "Not yet seen biting only in this window." }, gating.chips[1].tooltip)
				assert.are.same({}, entry("fixture_oddity").chips)
			end
		)

		it("puts every chip that applies in order: zone, skill, lure, notes, unconfirmed", function()
			local e = entry("fixture_snapper", {
				where = where({
					boardSpec = { time = { { 1200, 360 } }, lure = true },
					zones = { 148 },
					skillNeed = 75,
				}),
				unconfirmed = "window",
			})

			assert.are.same({
				"zone: Darkshore",
				"skill: skill 75",
				"lure: needs a lure",
				"note: Keeps late hours.",
				"note: After the lamps are lit.",
				"unconfirmed: unconfirmed",
			}, words(e.chips))
		end)
	end)

	describe("the retired entry (HNT-R3)", function()
		-- Old Sunscale, retired on 1 June 2026 after it was done.
		local function retired(fields)
			local state = stateWith("fixture_sunscale", progress(3, 40, 7, { tier(148, 2) }))
			local input = {
				state = state,
				retired = true,
				fromSet = "fixture_dusk",
				where = where({ boardSpec = { time = { { 360, 1200 } } }, zones = { 148 }, skillNeed = 25 }),
				row = { group = "now", auraUp = false, window = { openNow = true, closesAt = NOW + HOUR } },
				unconfirmed = "window",
			}
			for key, value in pairs(fields or {}) do
				input[key] = value
			end
			return entry("fixture_sunscale", input)
		end

		it("shows its name, target line, 'Retired {date}', its seal, tier ladder and effort counter", function()
			local e = retired()

			assert.are.equal("Old Sunscale", e.name)
			assert.are.equal("Retired 1 Jun 2026", e.retiredLine)
			assert.are.same(
				{ text = "Hunted 2 Oct 2026", filled = true, lines = { "Hunted", "2 Oct", "2026" } },
				e.seal
			)
			assert.are.same({ fill = 1, label = "3 caught" }, e.ladder.bar)
			assert.are.equal("40 Casts under these conditions, 7 since my last one.", e.effort.text)
		end)

		it("has no window line, conditions line, chips or pin toggle", function()
			local e = retired()

			assert.are.same(
				{ window = "none", conditions = "none", pin = "none" },
				{ window = e.window or "none", conditions = e.conditions or "none", pin = e.pin or "none" }
			)
			assert.are.same({}, e.chips)
		end)

		it("is no current Hunt's entry: no 'Retired' line on a Hunt that isn't retired", function()
			assert.is_nil(entry("fixture_snapper").retiredLine)
		end)
	end)

	describe("opened from a set's page (HNT-R66)", function()
		it("reads 'back to {set}', going back to that set's page", function()
			local e = entry("fixture_hefty_blackmouth", { fromSet = "fixture_dusk" })

			assert.are.same({ "back to Dusk", "fixture_dusk" }, { e.back, e.backSet })
		end)

		it("has no way back on the Board", function()
			assert.is_nil(entry("fixture_hefty_blackmouth").back)
		end)
	end)

	describe("while the projection is updating (HNT-R69)", function()
		it(
			"reads the updating line in the seal, the tier ladder and the effort counter, and the set's progress",
			function()
				local state = stateWith("fixture_snapper", progress(1, 96, 11, { tier(148) }))

				local e = entry("fixture_snapper", { state = state, updating = true })

				assert.are.same({ text = "Updating from your Catch log…", filled = false }, e.seal)
				assert.are.same({ updating = "Updating from your Catch log…" }, e.ladder)
				assert.are.equal("Updating from your Catch log…", e.effort.text)
				assert.are.equal("Odds live in Stats.", e.effort.odds)
				assert.are.equal("Dusk: Updating from your Catch log…", e.setLine)
			end
		)

		it("still writes the lines that aren't drawn from the state", function()
			local e = entry("fixture_snapper", { updating = true, where = where({ zones = { 148 } }) })

			assert.are.same({ "Snapper Run", "Darkshore" }, { e.name, e.chips[1].text })
		end)
	end)

	describe("the Board's right page with no entry (HNT-R67)", function()
		it("reads that every Hunt is done when Hunts are current but no row is visible", function()
			assert.are.equal(
				'Every Hunt here is done. Tick "show completed" to see them again.',
				ns.EntryEmptyLine(4, 0)
			)
		end)

		it("is empty with rows visible, or with no Hunt current at all", function()
			assert.is_nil(ns.EntryEmptyLine(4, 2))
			assert.is_nil(ns.EntryEmptyLine(0, 0))
		end)
	end)
end)
