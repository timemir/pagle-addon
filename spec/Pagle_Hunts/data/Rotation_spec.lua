-- The fallback rotation over the shipped 1.0 event pool (HNT-R152, DATA-R98): HNT-R152's three worked slots, so the
-- spec's words and the addon's arithmetic can't drift apart. Read from the shipped pool, without the fixture.

describe("the fallback rotation over the shipped pool (HNT-R152's worked slots)", function()
	local ns

	setup(function()
		ns = newFakePagle().load("Pagle_Hunts").ns
	end)

	-- The rotating events of `band` at the origin, in event-ID order.
	local function band(name)
		local ids = {}
		for i, event in ipairs(ns.RotationBand(ns.events:Events(), name, ns.ROTATION_ORIGIN)) do
			ids[i] = event.id
		end
		return ids
	end

	it("splits the 24 rotating events 8 per band (HNT-R156, the 1.0 pool)", function()
		assert.are.equal(8, #band("low"))
		assert.are.equal(8, #band("mid"))
		assert.are.equal(8, #band("high"))
	end)

	it(
		'seeds the low band\'s first pass with FNV-1a of "low:0", 3703032707, and shuffles it as HNT-R152 works',
		function()
			assert.are.equal(3703032707, ns.Fnv1a("low:0"))
			assert.are.same({
				"duskwood_witching",
				"tirisfal_silverpine_dusk",
				"stranglethorn_coast",
				"loch_modan_frenzy",
				"barrens_oddities",
				"alterac_dawn_trout",
				"darkshore_moonlight",
				"dustwallow_marsh_night",
			}, ns.SeededShuffle(band("low"), "low:0"))
		end
	)

	it("picks Duskwood, the Hinterlands' coast and Winterspring's salmon for slots 0, 1 and 2", function()
		local picks = {}
		for k = 0, 2 do
			picks[k + 1] = ns.RotationPick(ns.events:Events(), k).id
		end
		assert.are.same({ "duskwood_witching", "hinterlands_coast", "winterspring_salmon" }, picks)
	end)
end)
