-- Dry spells (STA-R50–R55): the count, the luck reading, its band and its wording, computed when shown from a reading
-- in the shape the M6 graph fixes for Your odds (#206): `n`, `k`, `hit = { n, at, last }` or nil, `state` and `where`.
-- The readings here are made by hand in that shape, so these specs don't wait on #206.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local HOUR = 3600

--- A reading in the fixed shape (M6 graph, conventions): `n` Casts in the scope, `k` of them caught the item, the last
--- at the scope's count `at`, `ago` seconds before FakePagle's SERVER_TIME. No `at` means never caught in the scope.
---@param fields { n: integer, k: integer?, at: integer?, ago: integer?, state: string?, where: string?, item: integer? }
---@return table
local function reading(fields)
	local k = fields.k or 0
	local hit = nil
	if fields.at then
		hit = { n = k, at = fields.at, last = SERVER_TIME - (fields.ago or HOUR) }
	end
	return {
		item = fields.item or 13759,
		area = 148,
		n = fields.n,
		k = k,
		hit = hit,
		state = fields.state or (fields.n < 100 and "learning" or (k == 0 and "unseen" or "known")),
		where = fields.where or "here",
	}
end

describe("Dry spells", function()
	describe("the count and the luck reading (STA-R50, STA-R51, STA-R52)", function()
		it("counts n − at since the last catch and reads P = (1 − k/n)^since: 412, 9, at 200 is 212, unlucky", function()
			local ns = stats.load().ns

			local dry = ns.DrySpell(reading({ n = 412, k = 9, at = 200 }))

			assert.are.equal(212, dry.since)
			assert.is_true(dry.caught)
			-- (1 − 9/412)^212, worked out apart from Stats: 0.0092567808662081
			assert.is_true(math.abs(dry.P - 0.0092567808662081) < 1e-12)
			assert.are.equal("unlucky", dry.band)
		end)

		it("is the bare n when never caught in the scope, with no luck reading", function()
			local ns = stats.load().ns

			local dry = ns.DrySpell(reading({ n = 412, k = 0 }))

			assert.are.equal(412, dry.since)
			assert.is_false(dry.caught)
			assert.is_nil(dry.P)
			assert.is_nil(dry.band)
		end)
	end)

	describe("its wording (STA-R50, STA-R53)", function()
		it("reads the entry's first sentence, then the band's wording: 412, 9, at 200", function()
			local ns = stats.load().ns

			local first, luck = ns.DrySpellText(reading({ n = 412, k = 9, at = 200, ago = 3 * HOUR }))

			assert.are.equal("212 Casts since my last one, 3h ago.", first)
			-- 1/P is 108.03 (above), which nice() reads as 110 (STA-R44)
			assert.are.equal("Roughly 1 angler in 110 waits this long. Unlucky, not broken.", luck)
		end)

		it("reads the tracker hover's first sentence with the item's name", function()
			local ns = stats.load().ns

			local first, luck = ns.DrySpellText(reading({ n = 412, k = 9, at = 200 }), "Nightfin Snapper")

			assert.are.equal("212 Casts since my last Nightfin Snapper.", first)
			assert.are.equal("Roughly 1 angler in 110 waits this long. Unlucky, not broken.", luck)
		end)

		it("reads a never-caught Dry spell as a bare count: 412 Casts here, none yet.", function()
			local ns = stats.load().ns

			local first, luck = ns.DrySpellText(reading({ n = 412, k = 0 }))

			assert.are.equal("412 Casts here, none yet.", first)
			assert.is_nil(luck)
		end)

		it("says where as the odds do, and counts in the singular and with thousands separators (STA-R46, STA-R59)", function()
			local ns = stats.load().ns

			assert.are.equal(
				"1,204 Casts across Darkshore, none yet.",
				(ns.DrySpellText(reading({ n = 1204, k = 0, where = "across Darkshore" })))
			)
			assert.are.equal(
				"1 Cast since my last one, 1h ago.",
				(ns.DrySpellText(reading({ n = 412, k = 9, at = 411 })))
			)
			assert.are.equal(
				"1 Cast since my last Nightfin Snapper.",
				(ns.DrySpellText(reading({ n = 412, k = 9, at = 411 }), "Nightfin Snapper"))
			)
		end)
	end)

	describe("bands at their boundaries (STA-R52, Tunables: Band cut-offs)", function()
		it("reads normal at 1 in 100 and above, unlucky just below", function()
			local ns = stats.load().ns

			assert.are.equal("normal", ns.Band(1))
			assert.are.equal("normal", ns.Band(0.01))
			assert.are.equal("unlucky", ns.Band(0.00999))
		end)

		it("reads unlucky at 1 in 10,000, very unlucky just below and on down to 0", function()
			local ns = stats.load().ns

			assert.are.equal("unlucky", ns.Band(0.0001))
			assert.are.equal("veryUnlucky", ns.Band(0.0000999))
			assert.are.equal("veryUnlucky", ns.Band(1e-6))
			assert.are.equal("veryUnlucky", ns.Band(0))
		end)
	end)

	describe("the luck wording at each step's boundary (STA-R53, Tunables: Wording steps, Floor)", function()
		local LONG = "A long wait, but well within normal luck."
		local ROLL = "Very unlucky, and every Cast is still its own roll."

		it("reads Nothing unusual. from P = ½ up", function()
			local ns = stats.load().ns

			assert.are.equal("Nothing unusual.", ns.LuckWording(1))
			assert.are.equal("Nothing unusual.", ns.LuckWording(0.5))
		end)

		it("counts anglers in 100 below ½ and from 5% up, rounded half up (STA-R44)", function()
			local ns = stats.load().ns

			assert.are.equal("About 50 anglers in 100 wait this long. Nothing unusual.", ns.LuckWording(0.4999))
			assert.are.equal("About 38 anglers in 100 wait this long. Nothing unusual.", ns.LuckWording(0.375))
			assert.are.equal("About 5 anglers in 100 wait this long. Nothing unusual.", ns.LuckWording(0.05))
		end)

		it("reads a long wait below 5% and down to 1 in 100", function()
			local ns = stats.load().ns

			-- 1/0.0499 is 20.04: nice() reads 20
			assert.are.equal("Roughly 1 angler in 20 waits this long. " .. LONG, ns.LuckWording(0.0499))
			assert.are.equal("Roughly 1 angler in 100 waits this long. " .. LONG, ns.LuckWording(0.01))
		end)

		it("reads unlucky below 1 in 100 and down to 1 in 10,000", function()
			local ns = stats.load().ns

			-- 1/0.00999 is 100.1: nice() reads 100
			assert.are.equal(
				"Roughly 1 angler in 100 waits this long. Unlucky, not broken.",
				ns.LuckWording(0.00999)
			)
			assert.are.equal(
				"Roughly 1 angler in 10,000 waits this long. Unlucky, not broken.",
				ns.LuckWording(0.0001)
			)
		end)

		it("reads very unlucky below 1 in 10,000 and down to 1 in a million", function()
			local ns = stats.load().ns

			-- 1/0.0000999 is 10,010: nice() reads 10,000
			assert.are.equal("Only about 1 angler in 10,000 waits this long. " .. ROLL, ns.LuckWording(0.0000999))
			assert.are.equal("Only about 1 angler in 1,000,000 waits this long. " .. ROLL, ns.LuckWording(1e-6))
		end)

		it("reads Fewer than 1 angler in a million below 10⁻⁶, and at 0", function()
			local ns = stats.load().ns

			assert.are.equal("Fewer than 1 angler in a million waits this long. " .. ROLL, ns.LuckWording(9.99e-7))
			assert.are.equal("Fewer than 1 angler in a million waits this long. " .. ROLL, ns.LuckWording(0))
		end)

		it("rounds 1 in {nice(1/P)} as STA-R44 says: two significant figures with thousands separators", function()
			local ns = stats.load().ns

			assert.are.equal(
				"Roughly 1 angler in 1,400 waits this long. Unlucky, not broken.",
				ns.LuckWording(1 / 1447)
			)
			assert.are.equal("Roughly 1 angler in 40 waits this long. " .. LONG, ns.LuckWording(1 / 39.6))
			assert.are.equal("Roughly 1 angler in 210 waits this long. Unlucky, not broken.", ns.LuckWording(1 / 212))
		end)

		it("reaches the half step from a reading: 200 Casts, 100 caught, 1 since", function()
			local ns = stats.load().ns

			-- (1 − 100/200)^1 is exactly ½
			local first, luck = ns.DrySpellText(reading({ n = 200, k = 100, at = 199 }))

			assert.are.equal("1 Cast since my last one, 1h ago.", first)
			assert.are.equal("Nothing unusual.", luck)
		end)
	end)

	describe("zero and learning (STA-R54)", function()
		it("reads a Dry spell of 0 as Caught one on my last Cast here., with no luck reading, in every state", function()
			local ns = stats.load().ns

			for _, state in ipairs({ "learning", "unseen", "known" }) do
				local zero = reading({ n = 412, k = 9, at = 412, state = state })
				local first, after = ns.DrySpellText(zero)
				local dry = ns.DrySpell(zero)

				assert.are.equal("Caught one on my last Cast here.", first, state)
				assert.is_nil(after, state)
				assert.are.equal(0, dry.since, state)
				assert.is_nil(dry.P, state) -- no luck wording, no ruler
				assert.is_nil(dry.band, state)
				assert.are.equal("Caught one on my last Cast here.", (ns.DrySpellText(zero, "Nightfin Snapper")), state)
			end
		end)

		it("says where for a Dry spell of 0 as the odds do", function()
			local ns = stats.load().ns

			assert.are.equal(
				"Caught one on my last Cast across Darkshore.",
				(ns.DrySpellText(reading({ n = 60, k = 2, at = 60, where = "across Darkshore" })))
			)
		end)

		it("reads the first sentence, then A luck reading comes …, with no band, while learning with a hit", function()
			local ns = stats.load().ns

			local learning = reading({ n = 37, k = 2, at = 30, ago = 21 * 60 })
			local first, after = ns.DrySpellText(learning)
			local dry = ns.DrySpell(learning)

			assert.are.equal("learning", learning.state)
			assert.are.equal("7 Casts since my last one, 21m ago.", first)
			assert.are.equal("A luck reading comes once Your odds have a number.", after)
			assert.are.equal(7, dry.since)
			assert.is_nil(dry.P)
			assert.is_nil(dry.band)
		end)

		it("reads a bare count while learning without a hit", function()
			local ns = stats.load().ns

			local first, after = ns.DrySpellText(reading({ n = 37, k = 0 }))

			assert.are.equal("37 Casts here, none yet.", first)
			assert.is_nil(after)
		end)
	end)

	describe("short forms (stats.md › UI, Place spread and Home spread; STA-R82)", function()
		-- Readings in each band, worked out apart from Stats: (1 − 9/412)^212 = 0.0093 (unlucky); (1 − 9/412)^20 =
		-- 0.64 (normal); (1 − 20/1000)^500 = 4.1e-5 (very unlucky); (1 − 50/5000)^2000 = 1.9e-9.
		local function readings()
			return {
				unlucky = reading({ n = 412, k = 9, at = 200 }),
				normal = reading({ n = 412, k = 9, at = 392 }),
				veryUnlucky = reading({ n = 1000, k = 20, at = 500, ago = 4 * 86400 }),
				zero = reading({ n = 412, k = 9, at = 412 }),
				learning = reading({ n = 37, k = 2, at = 30 }),
				never = reading({ n = 412, k = 0 }),
				thousands = reading({ n = 5000, k = 50, at = 3000 }),
			}
		end

		it("writes a row's margin: {since} since, the band's word apart, just now for 0, nothing when never caught", function()
			local ns = stats.load().ns
			local r = readings()

			assert.are.same({ "212 since", ", unlucky" }, { ns.DrySpellShort(r.unlucky) })
			assert.are.same({ "20 since" }, { ns.DrySpellShort(r.normal) })
			assert.are.same({ "500 since", ", very unlucky" }, { ns.DrySpellShort(r.veryUnlucky) })
			assert.are.same({ "just now" }, { ns.DrySpellShort(r.zero) })
			assert.are.same({ "7 since" }, { ns.DrySpellShort(r.learning) })
			assert.are.same({}, { ns.DrySpellShort(r.never) })
		end)

		it("writes a home spread watch line's end: since the last, caught on my last Cast, or a count, none yet", function()
			local ns = stats.load().ns
			local r = readings()

			assert.are.equal("212 since the last, unlucky.", ns.DrySpellWatchText(r.unlucky))
			assert.are.equal("20 since the last.", ns.DrySpellWatchText(r.normal))
			assert.are.equal("500 since the last, very unlucky.", ns.DrySpellWatchText(r.veryUnlucky))
			assert.are.equal("caught on my last Cast.", ns.DrySpellWatchText(r.zero))
			assert.are.equal("7 since the last.", ns.DrySpellWatchText(r.learning))
			assert.are.equal("412 Casts, none yet.", ns.DrySpellWatchText(r.never))
		end)

		it("writes the tracker's count: since, the bare n when never caught, just now for 0 (STA-R82)", function()
			local ns = stats.load().ns
			local r = readings()

			assert.are.equal("212", ns.DrySpellCount(r.unlucky))
			assert.are.equal("just now", ns.DrySpellCount(r.zero))
			assert.are.equal("412", ns.DrySpellCount(r.never))
		end)

		it("separates thousands in every count (STA-R59)", function()
			local ns = stats.load().ns
			local r = readings()

			assert.are.equal("2,000 since", (ns.DrySpellShort(r.thousands)))
			assert.are.equal("2,000", ns.DrySpellCount(r.thousands))
			assert.are.equal("5,000 Casts, none yet.", ns.DrySpellWatchText(reading({ n = 5000, k = 0 })))
		end)

		it("names each band in a word, normal included, for the tracker's line (STA-R82)", function()
			local ns = stats.load().ns

			assert.are.equal("normal", ns.BandWord("normal"))
			assert.are.equal("unlucky", ns.BandWord("unlucky"))
			assert.are.equal("very unlucky", ns.BandWord("veryUnlucky"))
		end)
	end)

	describe("the luck ruler's mark (stats.md › UI, Place spread: a log scale of P from 1 to 10⁻⁶)", function()
		local function near(expected, actual)
			assert.is_true(math.abs(expected - actual) < 1e-9, ("expected %s, got %s"):format(expected, actual))
		end

		it("puts 1 at the left end, 10⁻⁶ at the right and each tick a sixth along", function()
			local ns = stats.load().ns

			near(0, ns.RulerPosition(1))
			near(1 / 6, ns.RulerPosition(0.1))
			near(2 / 6, ns.RulerPosition(0.01)) -- where unlucky starts
			near(4 / 6, ns.RulerPosition(0.0001)) -- where very unlucky starts
			near(1, ns.RulerPosition(1e-6))
		end)

		it("puts a P between ticks on the log scale: 1 in √10 halfway to 1 in 10", function()
			local ns = stats.load().ns

			near(1 / 12, ns.RulerPosition(1 / math.sqrt(10)))
			near(0.5, ns.RulerPosition(0.001))
		end)

		it("clamps at both ends: below 10⁻⁶ (and 0) at the right, above 1 at the left", function()
			local ns = stats.load().ns

			near(1, ns.RulerPosition(1e-9))
			near(1, ns.RulerPosition(0))
			near(0, ns.RulerPosition(1.5))
		end)

		it("marks the reading's own P: 412, 9, at 200 sits just past 1 in 100", function()
			local ns = stats.load().ns

			-- log10(1/0.0092567808662081) = 2.0336, a sixth of which is 0.33893
			local position = ns.RulerPosition(ns.DrySpell(reading({ n = 412, k = 9, at = 200 })).P)
			assert.is_true(math.abs(position - 0.33893) < 1e-5)
		end)
	end)

	describe("nothing else (STA-R55, STA-R2)", function()
		it("raises nothing, prints nothing and pops nothing up when a Dry spell is shown or has just ended", function()
			local loaded, fake = stats.load()
			local ns = loaded.ns
			fake.login()
			fake.nextFrame()
			local printed, announced, summarized = #fake.printed, #fake.announcements, #fake.summarized

			for _, r in ipairs({
				reading({ n = 412, k = 9, at = 412 }), -- just ended
				reading({ n = 1000, k = 20, at = 500 }), -- very unlucky
				reading({ n = 412, k = 0 }),
			}) do
				ns.DrySpell(r)
				ns.DrySpellText(r)
				ns.DrySpellText(r, "Nightfin Snapper")
				ns.DrySpellShort(r)
				ns.DrySpellWatchText(r)
				ns.DrySpellCount(r)
			end
			fake.nextFrame()

			assert.are.equal(printed, #fake.printed)
			assert.are.equal(announced, #fake.announcements)
			assert.are.equal(summarized, #fake.summarized)
		end)
	end)
end)
