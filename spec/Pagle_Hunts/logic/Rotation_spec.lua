-- The fallback rotation (HNT-R152, HNT-R156; ADR 0012 and its note): logic/Rotation.lua over hand-made pools of three
-- events per band. The fixed picks below were worked out apart from the addon, by a separate implementation of
-- HNT-R152's arithmetic, so a change to the hash, the generator or the shuffle fails here: every client must agree.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local DAY = 86400

describe("the fallback rotation", function()
	local fake = newFakePagle()
	fake.setCatalogue(hunts.catalogue.base())
	local ns = hunts.load(fake).ns
	local ORIGIN = ns.ROTATION_ORIGIN

	-- A pool event as the rotation reads it (HuntEvent's id, band, rotation, pushed and retired).
	local function event(id, band, fields)
		local e = { id = id, band = band, rotation = true, pushed = false }
		for key, value in pairs(fields or {}) do
			e[key] = value
		end
		return e
	end

	-- Three events per band, listed out of ID order: the rotation sorts each band itself.
	local function pool()
		return {
			event("fixture_vale", "low"),
			event("fixture_shore", "low"),
			event("fixture_brook", "low"),
			event("fixture_glen", "mid"),
			event("fixture_firth", "mid"),
			event("fixture_cove", "mid"),
			event("fixture_tarn", "high"),
			event("fixture_sound", "high"),
			event("fixture_reef", "high"),
		}
	end

	local function picks(events, from, to)
		local out = {}
		for k = from, to do
			local pick = ns.RotationPick(events, k)
			out[#out + 1] = pick and pick.id or false
		end
		return out
	end

	describe("its arithmetic (HNT-R152)", function()
		it("hashes the seed with FNV-1a 32-bit (LOG-R66 step 1)", function()
			assert.are.equal(2166136261, ns.Fnv1a(""))
			assert.are.equal(3826002220, ns.Fnv1a("a"))
			assert.are.equal(3703032707, ns.Fnv1a("low:0"))
			assert.are.equal(973479943, ns.Fnv1a("mid:0"))
			assert.are.equal(940069935, ns.Fnv1a("high:0"))
		end)

		it("steps x = (1664525 x + 1013904223) mod 2^32, exactly", function()
			local x = ns.Fnv1a("low:0")
			local steps = {}
			for i = 1, 3 do
				x = ns.RotationStep(x)
				steps[i] = x
			end
			assert.are.same({ 2359655174, 1399887533, 202672168 }, steps)
			assert.are.equal(1013904223, ns.RotationStep(0))
			-- The largest product, 1664525 × (2^32 − 1), is still exact.
			assert.are.equal((1664525 * 4294967295 + 1013904223) % 4294967296, ns.RotationStep(4294967295))
		end)

		it("shuffles a new list by Fisher–Yates, the seed's hash drawing each swap, and leaves the list", function()
			local list = { "fixture_cove", "fixture_firth", "fixture_glen" }
			assert.are.same({ "fixture_firth", "fixture_cove", "fixture_glen" }, ns.SeededShuffle(list, "mid:0"))
			assert.are.same({ "fixture_glen", "fixture_cove", "fixture_firth" }, ns.SeededShuffle(list, "mid:1"))
			assert.are.same({ "fixture_cove", "fixture_firth", "fixture_glen" }, list)
			assert.are.same({}, ns.SeededShuffle({}, "low:0"))
			assert.are.same({ "a" }, ns.SeededShuffle({ "a" }, "low:0"))
		end)
	end)

	describe("its slots (HNT-R152)", function()
		it("are 72 hours each from the origin, and there is none before it", function()
			assert.is_nil(ns.RotationSlotAt(ORIGIN - 1))
			assert.are.equal(0, ns.RotationSlotAt(ORIGIN))
			assert.are.equal(0, ns.RotationSlotAt(ORIGIN + 3 * DAY - 1))
			assert.are.equal(1, ns.RotationSlotAt(ORIGIN + 3 * DAY))
			assert.are.same(
				{ slot = 4, start = ORIGIN + 12 * DAY, end_ = ORIGIN + 15 * DAY, band = "mid" },
				ns.RotationSlot(4)
			)
		end)

		it("start from the placeholder origin, Monday 19 October 2026 at 15:00 UTC (Tunables)", function()
			assert.are.equal(1792422000, ORIGIN)
			assert.are.equal(15 * 3600, ORIGIN % DAY)
			-- 1 January 1970 was a Thursday: day 4 of a week starting Monday is a Monday here.
			assert.are.equal(4, math.floor(ORIGIN / DAY) % 7)
			assert.are.equal(72 * 3600, ns.RUN_LENGTH)
		end)

		it("cycle low, mid, high (HNT-R152)", function()
			local bands = {}
			for k = 0, 5 do
				bands[k + 1] = ns.RotationSlot(k).band
			end
			assert.are.same({ "low", "mid", "high", "low", "mid", "high" }, bands)
			local events = pool()
			for k = 0, 17 do
				assert.are.equal(ns.RotationSlot(k).band, ns.RotationPick(events, k).band)
			end
		end)
	end)

	describe("its picks (HNT-R152)", function()
		it("are fixed: the same pick for a slot on every run", function()
			assert.are.same({
				"fixture_vale",
				"fixture_firth",
				"fixture_reef",
				"fixture_brook",
				"fixture_cove",
				"fixture_tarn",
				"fixture_shore",
				"fixture_glen",
				"fixture_sound",
				"fixture_vale",
				"fixture_glen",
				"fixture_reef",
			}, picks(pool(), 0, 11))
			assert.are.same(picks(pool(), 0, 30), picks(pool(), 0, 30))
		end)

		it("pick every event of a band once in each pass through it, shuffled anew each pass", function()
			local events = pool()
			for b = 0, 2 do
				for pass = 0, 3 do
					local seen = {}
					for visit = 0, 2 do
						local pick = ns.RotationPick(events, 3 * (3 * pass + visit) + b)
						assert.is_nil(seen[pick.id])
						seen[pick.id] = true
					end
				end
			end
			-- The mid band's first two passes differ: cove, firth, glen shuffled by "mid:0", then by "mid:1".
			local function mid(pass)
				return {
					picks(events, 9 * pass + 1, 9 * pass + 1)[1],
					picks(events, 9 * pass + 4, 9 * pass + 4)[1],
					picks(events, 9 * pass + 7, 9 * pass + 7)[1],
				}
			end
			assert.are.same({ "fixture_firth", "fixture_cove", "fixture_glen" }, mid(0))
			assert.are.same({ "fixture_glen", "fixture_cove", "fixture_firth" }, mid(1))
		end)

		it("don't depend on the pool's order, only on event IDs", function()
			local reversed = {}
			for _, e in ipairs(pool()) do
				table.insert(reversed, 1, e)
			end
			assert.are.same(picks(pool(), 0, 20), picks(reversed, 0, 20))
		end)

		it("skip an event from its retired date on, and events that don't rotate (HNT-R152, DATA-R98)", function()
			local events = pool()
			-- Retired at slot 3's start: slot 0 still picks it, and from slot 3 on the low band is brook and shore.
			events[1].retired = ORIGIN + 9 * DAY
			assert.are.equal("fixture_vale", ns.RotationPick(events, 0).id)
			local low = {}
			for k = 3, 30, 3 do
				low[ns.RotationPick(events, k).id] = true
			end
			assert.are.same({ fixture_brook = true, fixture_shore = true }, low)
			-- An event with rotation = false is never picked.
			events[2].rotation = false
			for k = 3, 30, 3 do
				assert.are.equal("fixture_brook", ns.RotationPick(events, k).id)
			end
			-- A pushed event never rotates (HNT-R140).
			local pushed = { event("p_fixture_tide", "low", { pushed = true }) }
			assert.is_nil(ns.RotationPick(pushed, 0))
		end)

		it("leave a slot empty when its band is empty", function()
			local events = { event("fixture_vale", "low") }
			assert.are.same({ "fixture_vale", false, false, "fixture_vale" }, picks(events, 0, 3))
		end)

		it("take the band's next pick when the slot's own is busy, and none when all are (HNT-R153)", function()
			local events = pool()
			-- Slot 0's picks in order: vale (visit 0), brook (visit 1), shore (visit 2).
			assert.are.same(
				{ "fixture_vale", "fixture_brook", "fixture_shore" },
				hunts.ids(ns.RotationPicks(events, 0))
			)
			local busy = { fixture_vale = true }
			local function isBusy(e)
				return busy[e.id] == true
			end
			assert.are.equal("fixture_brook", ns.RotationPick(events, 0, isBusy).id)
			busy.fixture_brook = true
			assert.are.equal("fixture_shore", ns.RotationPick(events, 0, isBusy).id)
			busy.fixture_shore = true
			assert.is_nil(ns.RotationPick(events, 0, isBusy))
			-- The last visit of a pass runs on into the next pass for its next picks: slot 6 is low's visit 2.
			assert.are.same(
				{ "fixture_shore", "fixture_vale", "fixture_brook" },
				hunts.ids(ns.RotationPicks(events, 6))
			)
		end)
	end)
end)
