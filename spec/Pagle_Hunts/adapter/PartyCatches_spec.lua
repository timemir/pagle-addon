-- A live Party Catch in Hunts on FakePagle (HNT-R185's first half, HNT-R182, HNT-R184, ANN-R110), through Core's
-- receiver path as fake.partyCatch drives it (#644): a real `G1` appended and handed live to the projections that take
-- Party Catches. The moments of what it newly reaches merge under its entry ID, and the Coins it earns are reported,
-- as a Cast's are; Core's filter asks Hunts' def. The groupmate's name on the moments and the party toast are #646's.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local C = hunts.catalogue
local NIGHT = hunts.NIGHT
local cast, append = hunts.cast, hunts.append

local ELWYNN = { zone = C.ELWYNN }

-- Hunts' moments Core kept, as kind, text and cast.
---@param fake table
---@return table[]
local function kept(fake)
	local out = {}
	for _, moment in ipairs(fake.summarized) do
		if moment.module == "Hunts" then
			out[#out + 1] = { kind = moment.kind, text = moment.text, cast = moment.cast }
		end
	end
	return out
end

-- Each Coins total Core accepted from Hunts, in order (SHOP-R2).
---@param fake table
---@return integer[]
local function coinReports(fake)
	local totals = {}
	for _, report in ipairs(fake.coinReports) do
		if report.module == "Hunts" then
			totals[#totals + 1] = report.total
		end
	end
	return totals
end

describe("a live Party Catch in Hunts", function()
	it("raises the tier it reaches merged under its entry ID, and reports the Coins (HNT-R185, ANN-R110)", function()
		-- Nine Nightfin of the Angler's own: fixture_snapper done, one short of tier 2.
		local loaded, fake = hunts.login(function(fake)
			local records = {}
			for i = 1, 9 do
				records[i] = cast(0, NIGHT + i, ELWYNN, { C.NIGHTFIN })
			end
			return append(fake, records)
		end)
		local before = loaded.ns.State().coins

		local copy, sourceId = hunts.partyCopy(cast(0, NIGHT + 20, ELWYNN, { C.NIGHTFIN }))
		local pc = fake.partyCatch(copy, hunts.GROUPMATE_NAME, sourceId)
		fake.nextFrame()

		local state = loaded.ns.State()
		assert.are.same(
			{ 10, true },
			{ state.hunts.fixture_snapper.count, state.hunts.fixture_snapper.reached[2].party }
		)
		assert.are.same({ { kind = "huntTier", text = "Snapper Run · 10 caught", cast = pc.id } }, kept(fake))
		assert.are.same({ pc.id }, { fake.announcements[1].cast })
		assert.are.same({ before + loaded.ns.COINS_TIER }, { coinReports(fake)[#coinReports(fake)] })
		assert.are.equal(2, loaded.env.PagleHuntsDB.global.celebrated.tiers.fixture_snapper)
		assert.are.same({}, fake.reported)
	end)

	it("is asked by Core's filter through Hunts' def, which takes what could count (HNT-R184, LOG-R114)", function()
		local _, fake = hunts.login()
		local projections = fake.projections

		local wanted = hunts.partyCatch(cast(0, NIGHT, ELWYNN, { C.NIGHTFIN }))
		local unwanted = hunts.partyCatch(cast(0, NIGHT, ELWYNN, { C.SMALLFISH }))

		assert.are.same({ true, false }, { projections:WantsPartyCatch(wanted), projections:WantsPartyCatch(unwanted) })
	end)

	it(
		"is walked by a later run record through M:IterateCatches, and a rebuild folds to the same state (HNT-R183)",
		function()
			local S, E = hunts.MARCH_1, hunts.MARCH_1 + 4 * 86400
			local DARKSHORE = { zone = C.DARKSHORE }
			local loaded, fake = hunts.login(function(fake)
				return append(fake, { cast(1, hunts.DUSK, DARKSHORE, { C.DEVIATE }) })
			end)
			local copy, sourceId = hunts.partyCopy(cast(1, NIGHT, DARKSHORE, { C.NIGHTFIN }))
			local pc = fake.partyCatch(copy, hunts.GROUPMATE_NAME, sourceId)

			loaded.ns.Module:AppendRecord("run", hunts.runPayload("fixture_shore", S, E))

			local run = loaded.ns.State().runs["fixture_shore@" .. S]
			local snapper = run.hunts.fixture_shore_snapper.reached[1]
			assert.are.same({ pc.items[1].catchId, true }, { snapper.catchId, snapper.party })
			assert.are.same({ 2, true }, { run.hunts.fixture_shore_haul.count, run.completedAt ~= nil })
			local live = hunts.deepCopy(loaded.ns.State())

			-- A new Hunt list fingerprint rebuilds from the log, its G1 included (LOG-R122, HNT-R191).
			local rebuilt = hunts.login(nil, {
				fake = hunts.nextLogin(fake, loaded),
				prepare = function(l)
					l.ns.huntList.fingerprint = "f1c7f1c7f1c70002"
				end,
			})
			assert.are.same(live, rebuilt.ns.State())
		end
	)
end)
