-- The variety projection on the client (VAR-R10, VAR-R11, VAR-R13, LOG-R78): Core's own projection in
-- PagleDB.global.projections.varieties, over a saved log's Casts and the release's catalogue, through the real TOC,
-- feeding Pagle.GetVarietiesCaught and the hooks of Core's earned goods.

local LOG_ID = "3f9a2c1e7b0d4a65" -- savedLog's
local GUID = characterRecord().guid
local OILY, FIREFIN = 6358, 6359

-- The position of the Catch of Ada's Cast at `time` (VAR-R3): its Catch ID is "<GUID>-<time>-0:1".
local function positionAt(loaded, time)
	return loaded.ns.VarietyIndex(("%s-%d-0:1"):format(GUID, time))
end

-- Ada's history: `n` Casts of a Firefin Snapper, at SERVER_TIME - 90000 + 1, + 2, …, then the build entry.
local function firefins(n)
	local entries = {}
	for i = 1, n do
		entries[i] = castEntry(SERVER_TIME - 90000 + i, FIREFIN)
	end
	entries[n + 1] = BUILD_ENTRY
	return entries
end

-- The positions of the Firefin Snapper in `firefins(n)`, as a set.
local function positions(loaded, n)
	local set = {}
	for i = 1, n do
		set[positionAt(loaded, SERVER_TIME - 90000 + i)] = true
	end
	return set
end

describe("the variety projection", function()
	it(
		"is Core's own, after the wallet's, bound to PagleDB.global.projections.varieties with rules version 1 and the"
			.. " content fingerprint alone (VAR-R10, LOG-R70, LOG-R78)",
		function()
			local loaded = enterWorld(loadCore(firefins(3)))

			local global = loaded.env.PagleDB.global
			local db = global.projections.varieties
			assert.are.same({ 1, loaded.env.Pagle.CONTENT_FINGERPRINT, LOG_ID, #loaded.env.PagleLog.entries }, {
				db.rulesVersion,
				db.fingerprint,
				db.logId,
				db.lastSeq,
			})
			-- Core's projections come first, in the order login step 1 binds them.
			local list = loaded.ns.projections.list
			assert.are.same(
				{ global.projections.fieldReport, global.projections.wallet, db },
				{ list[1].def.db, list[2].def.db, list[3].def.db }
			)
		end
	)

	it("keeps each Species' positions caught from the log's Casts (VAR-R10)", function()
		local loaded = enterWorld(loadCore(firefins(20)))

		local stored = loaded.env.PagleDB.global.projections.varieties.projection
		assert.are.same({ bySpecies = { [FIREFIN] = positions(loaded, 20) } }, stored)
	end)

	it("binds to a PagleDB saved before the varieties, which holds no variety projection (VAR-R10)", function()
		local saved = { global = { projections = { fieldReport = {}, wallet = {} } } }
		local loaded = enterWorld(loadCore(firefins(3), saved))

		assert.are.same(positions(loaded, 3), loaded.env.Pagle.GetVarietiesCaught(FIREFIN))
	end)

	it(
		"gives Pagle.GetVarietiesCaught a fresh set of a Species' positions caught, empty for one with none"
			.. " (VAR-R11)",
		function()
			local loaded = enterWorld(loadCore(firefins(5)))
			local Pagle = loaded.env.Pagle

			local caught = Pagle.GetVarietiesCaught(FIREFIN)
			caught[11] = true

			assert.are.same(positions(loaded, 5), Pagle.GetVarietiesCaught(FIREFIN))
			assert.are.same({}, Pagle.GetVarietiesCaught(OILY))
			assert.are.same({}, Pagle.GetVarietiesCaught(9999))
		end
	)

	it(
		"runs Core's earned-goods hooks after its done and after a live Catch that adds a variety, not one that"
			.. " adds none (VAR-R13)",
		function()
			local loaded = loadCore(firefins(3))
			local Pagle = loaded.env.Pagle
			local runs = {}
			loaded.ns.OnVarietiesCaught(function()
				runs[#runs + 1] = loaded.ns.projections:IsUpdating() and loaded.ns.projections:Mode() ~= "done"
			end)

			enterWorld(loaded)
			assert.are.same({ false }, runs, "once, from the done")

			catchOne(loaded) -- the first Oily Blackmouth: a new variety
			local last
			for record in Pagle.IterateCatches(#loaded.env.PagleLog.entries - 1) do
				last = record
			end
			local variety = last.items[1].variety
			assert.are.same({ [variety.index] = true }, Pagle.GetVarietiesCaught(OILY))
			assert.are.same({ false, false }, runs)

			loaded.ns.RecordPurchase("core.crest.elwynn", 0)
			assert.are.equal(2, #runs, "a purchase adds no variety")
		end
	)
end)
