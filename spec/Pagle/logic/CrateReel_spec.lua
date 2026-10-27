-- The Curio crate's opening as pure logic (SHOP-R55, wallet-and-shop.md › UI: Motion and sound, "A crate opens"):
-- ns.CrateReelCards, the reel's easing and where it stops, the opening's key times and beats, what each crate tier adds
-- to the reveal (ns.CrateRevealOf), the sound each beat plays, and what a click or Esc does in each phase.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

local realPool = ns.CRATE_POOL

-- A pool of three goods in tier 1, one in tiers 2 and 3, none in 4 to 6, and Prize Foil as the Curio tier's.
local function fixturePool()
	return {
		{ id = "t1.a", tier = 1, kind = "toaststyle" },
		{ id = "t1.b", tier = 1, kind = "soundset" },
		{ id = "t2.a", tier = 2, kind = "binding" },
		{ id = "t1.c", tier = 1, kind = "trackerframe" },
		{ id = "t3.a", tier = 3, kind = "toaststyle" },
		{ id = "foil", tier = "curio", kind = "toaststyle" },
	}
end

-- A `rand(n)` that gives each of `rolls` in turn, wrapping; asking for n clamps it to 1..n. `asked` lists every n.
local function rolls(sequence)
	local i, asked = 0, {}
	return function(n)
		asked[#asked + 1] = n
		i = i % #sequence + 1
		return math.max(1, math.min(n, sequence[i]))
	end,
		asked
end

after_each(function()
	ns.CRATE_POOL = realPool
end)

describe("The reel's cards (SHOP-R55, Motion row)", function()
	it("holds 60 cards, the 53rd the result's, and the run starts at the 4th", function()
		assert.are.same({ 60, 53, 4 }, { ns.CRATE_REEL.cards, ns.CRATE_REEL.win, ns.CRATE_REEL.first })
		ns.CRATE_POOL = fixturePool()

		local cards = ns.CrateReelCards({ tier = 2, good = "t2.a" }, { ["t2.a"] = true }, nil, rolls({ 1 }))

		assert.are.equal(60, #cards)
		assert.are.same({ tier = 2, face = "kind", kind = "binding" }, cards[53])
	end)

	it("makes the result's card the Curio '?' for a crate-only good, and the coin card for a payback", function()
		ns.CRATE_POOL = fixturePool()
		local rand = rolls({ 1 })

		local curio = ns.CrateReelCards({ tier = "curio", good = "foil", crateOnly = true }, { foil = true }, nil, rand)
		local payback = ns.CrateReelCards({ tier = 4, payback = 1500 }, {}, nil, rand)

		assert.are.same({ tier = "curio", face = "curio" }, curio[53])
		assert.are.same({ tier = 4, face = "coin" }, payback[53])
	end)

	it("draws every other card as SHOP-R51 draws: a crate tier by the odds", function()
		ns.CRATE_POOL = fixturePool()
		-- Each roll of 1 to 1000 lands in the tier whose running odds (400 / 660 / 820 / 920 / 970 / 995 / 1000) reach it.
		for roll, tier in pairs({ [1] = 1, [400] = 1, [401] = 2, [660] = 2, [661] = 3, [820] = 3, [821] = 4 }) do
			local rand = rolls({ roll, 1 })
			local cards = ns.CrateReelCards({ tier = 1, good = "t1.a" }, { ["t1.a"] = true }, nil, rand)
			assert.are.equal(tier, cards[1].tier, "roll " .. roll)
		end
		for roll, tier in pairs({ [921] = 5, [970] = 5, [971] = 6, [995] = 6, [996] = "curio", [1000] = "curio" }) do
			local cards = ns.CrateReelCards({ tier = 1, good = "t1.a" }, {}, nil, rolls({ roll, 1 }))
			assert.are.equal(tier, cards[1].tier, "roll " .. roll)
		end
	end)

	it("shows the kind of one of that tier's candidates, by a second roll, in the pool's order", function()
		ns.CRATE_POOL = fixturePool()
		-- Tier 1's candidates, with t1.a given by this crate (so still a candidate): its three goods' kinds in pool order.
		local given = { good = "t1.a", tier = 1 }
		local owned = { ["t1.a"] = true }

		for second, kind in ipairs({ "toaststyle", "soundset", "trackerframe" }) do
			local rand = rolls({ 1, second, 1, 1 }) -- the first card's tier (1), then its candidate
			local cards = ns.CrateReelCards(given, owned, nil, rand)
			assert.are.same({ tier = 1, face = "kind", kind = kind }, cards[1])
		end
	end)

	it(
		"counts the crate's own good among the candidates: the cards are drawn from what the Angler could win",
		function()
			ns.CRATE_POOL = { { id = "only", tier = 1, kind = "binding" } }

			local cards = ns.CrateReelCards({ tier = 1, good = "only" }, { only = true }, nil, rolls({ 1, 1 }))

			assert.are.same({ tier = 1, face = "kind", kind = "binding" }, cards[1])
		end
	)

	it("shows a coin card in the tier's colour where that tier has no candidate left", function()
		ns.CRATE_POOL = fixturePool()
		local owned = { ["t2.a"] = true, ["t1.a"] = true, ["t1.b"] = true, ["t1.c"] = true }

		-- tier 2's only good is owned and the crate's good is a tier 1 one: tier 2 (a roll of 500) has none left
		local cards = ns.CrateReelCards({ tier = 3, good = "t3.a" }, owned, nil, rolls({ 500, 1 }))

		assert.are.same({ tier = 2, face = "coin" }, cards[1])
		assert.are.equal("coin", cards[2].face) -- a roll of 1: tier 1 has none either
	end)

	it("makes Curio's card the '?' while a crate-only good is a candidate, else a gilt coin card", function()
		ns.CRATE_POOL = fixturePool()

		local open = ns.CrateReelCards({ tier = 1, good = "t1.a" }, { ["t1.a"] = true }, nil, rolls({ 1000, 1 }))
		local spent = ns.CrateReelCards(
			{ tier = 1, good = "t1.a" },
			{ ["t1.a"] = true, foil = true },
			nil,
			rolls({ 1000, 1 })
		)

		assert.are.same({ tier = "curio", face = "curio" }, open[1])
		assert.are.same({ tier = "curio", face = "coin" }, spent[1])
	end)

	it("reads the candidates as of the crate's time (SHOP-R53)", function()
		local pool = fixturePool()
		pool[#pool + 1] = { id = "later", tier = 2, kind = "soundset", since = 2000 }
		ns.CRATE_POOL = pool

		-- a roll of 500 is tier 2; the second roll of 2 asks for its second candidate, which only the later time has
		local before = ns.CrateReelCards({ tier = 1, good = "t1.a" }, { ["t1.a"] = true }, 1000, rolls({ 500, 2 }))
		local after = ns.CrateReelCards({ tier = 1, good = "t1.a" }, { ["t1.a"] = true }, 3000, rolls({ 500, 2 }))

		assert.are.same({ tier = 2, face = "kind", kind = "binding" }, before[1])
		assert.are.same({ tier = 2, face = "kind", kind = "soundset" }, after[1])
	end)

	it("draws the same cards from the same rolls, and doesn't change what it is given", function()
		ns.CRATE_POOL = fixturePool()
		local owned = { ["t1.a"] = true }

		local first = ns.CrateReelCards({ tier = 1, good = "t1.a" }, owned, nil, rolls({ 17, 3, 912, 2, 640, 1 }))
		local second = ns.CrateReelCards({ tier = 1, good = "t1.a" }, owned, nil, rolls({ 17, 3, 912, 2, 640, 1 }))

		assert.are.same(first, second)
		assert.are.same({ ["t1.a"] = true }, owned)
	end)

	it(
		"gives each kind of good in the real pool an emblem in the crate kit (a kind with no good needs none)",
		function()
			local kinds = {}
			for _, row in ipairs(realPool) do
				kinds[row.kind] = true
			end
			for kind in pairs(kinds) do
				local emblem = ns.CrateEmblem(kind)
				assert.are_not.equal("coin", emblem, kind)
				assert(ns.ATLASES.Crate.sprites["emblem-" .. emblem] ~= nil, kind)
				assert(ns.ATLASES.Crate.sprites["emblem-" .. emblem .. "-hi"] ~= nil, kind)
			end
			assert.are.equal("coin", ns.CrateEmblem("crest"))
			assert.is_not_nil(ns.ATLASES.Crate.sprites["emblem-coin"])
		end
	)

	it("draws a real crate's reel from the real pool: 60 cards, each of a tier, none a kind with no emblem", function()
		local result = { tier = 3, good = "core.binding.sharkskin" }
		local cards = ns.CrateReelCards(result, { ["core.binding.sharkskin"] = true }, nil, math.random)

		assert.are.equal(60, #cards)
		assert.are.same({ tier = 3, face = "kind", kind = "binding" }, cards[53])
		for _, card in ipairs(cards) do
			assert.is_true(card.face == "kind" or card.face == "coin" or card.face == "curio")
			assert.is_not_nil(ns.CRATE_TIER_COLORS[card.tier])
		end
	end)
end)

describe("The reel's run (SHOP-R55, Motion row)", function()
	it("eases out as 1 − (1 − t)^4.6, from 0 to 1", function()
		assert.are.equal(0, ns.CrateReelEase(0))
		assert.are.equal(1, ns.CrateReelEase(1))
		assert.is_near(1 - 0.5 ^ 4.6, ns.CrateReelEase(0.5), 1e-12)
		assert.is_true(ns.CrateReelEase(0.1) > 0.3) -- fast at first
		local last = 0
		for i = 1, 100 do
			local e = ns.CrateReelEase(i / 100)
			assert.is_true(e > last)
			last = e
		end
		assert.are.equal(6.4, ns.CRATE_REEL.duration)
	end)

	it("stops the line anywhere up to 48 units off the 53rd card's middle, either way", function()
		local seen = {}
		for roll = 1, 97 do
			local offset = ns.CrateReelOffset(function(n)
				assert.are.equal(97, n)
				return roll
			end)
			seen[offset] = true
			assert.is_true(math.abs(offset) <= 48)
		end
		assert.is_true(seen[-48] and seen[0] and seen[48])
	end)

	it("runs the track from the 4th card under the line to the 53rd, the line inside it", function()
		local first = ns.CrateReelTrackAt(4, 0)
		assert.are.equal(first, ns.CrateReelTrackX(0, 17))
		assert.are.equal(ns.CrateReelTrackAt(53, 17), ns.CrateReelTrackX(1, 17))
		-- a card is 120 wide, 130 apart: the 4th's middle is 3 pitches and half a card from the track's start
		assert.are.equal(-(3 * 130 + 60), first)
		for offset = -48, 48 do
			assert.are.equal(53, ns.CrateReelCardAt(ns.CrateReelTrackX(1, offset)), offset)
		end
		assert.are.equal(4, ns.CrateReelCardAt(first))
		assert.are.equal(1, ns.CrateReelCardAt(100))
		assert.are.equal(60, ns.CrateReelCardAt(-100000))
	end)

	it("passes from card to card across the gap, a card's slot being its width and half the gap each side", function()
		-- card 10 is [1170, 1290] along the track: its slot is [1165, 1295)
		assert.are.equal(10, ns.CrateReelCardAt(-1165))
		assert.are.equal(10, ns.CrateReelCardAt(-1294.9))
		assert.are.equal(11, ns.CrateReelCardAt(-1295))
		assert.are.equal(9, ns.CrateReelCardAt(-1164.9))
	end)

	it("ticks once for each card the line crosses, never for the first, and not twice within 28 ms", function()
		local ticks = ns.NewCrateTicks()

		assert.is_false(ns.CrateReelTick(ticks, 4, 0)) -- the run's first card
		assert.is_false(ns.CrateReelTick(ticks, 4, 0.05)) -- the same card
		assert.is_true(ns.CrateReelTick(ticks, 5, 0.1))
		assert.is_false(ns.CrateReelTick(ticks, 6, 0.12)) -- 20 ms after the last tick
		assert.is_true(ns.CrateReelTick(ticks, 7, 0.14))
		assert.are.equal(2, ticks.count)
	end)
end)

describe("What each crate tier adds to the reveal (SHOP-R55, Motion row)", function()
	-- crate tiers 1 to 6, then Curio, as the numbers 1 to 7
	local TIERS = { 1, 2, 3, 4, 5, 6, "curio" }

	it("waits 0.76 s and 0.11 s for each tier above 1", function()
		for n, tier in ipairs(TIERS) do
			assert.is_near(0.76 + 0.11 * (n - 1), ns.CrateRevealOf(tier).wait, 1e-9)
		end
	end)

	it(
		"trembles from tier 4 up, and turns half a turn to tier 3, one and a half from tier 4, two and a half for Curio",
		function()
			local turns = { 1, 1, 1, 3, 3, 3, 5 }
			local seconds = { 0.48, 0.48, 0.48, 0.9, 0.9, 0.9, 1.5 }
			for n, tier in ipairs(TIERS) do
				local reveal = ns.CrateRevealOf(tier)
				assert.are.same(
					{ n >= 4, turns[n], seconds[n] },
					{ reveal.tremble, reveal.halfTurns, reveal.turn },
					tostring(tier)
				)
			end
		end
	)

	it(
		"whips the rays back 60° and 30° more a tier above 1, slowing into their turn in 1.6 s and 0.1 s more",
		function()
			for n, tier in ipairs(TIERS) do
				local whip = ns.CrateRevealOf(tier).whip
				assert.are.same({ 60 + 30 * (n - 1), 1.6 + 0.1 * (n - 1) }, { whip.degrees, whip.dur }, tostring(tier))
			end
		end
	)

	it("adds sparks from tier 4, embers and the shake from tier 5, a white flash at tier 6", function()
		for n, tier in ipairs(TIERS) do
			local reveal = ns.CrateRevealOf(tier)
			assert.are.equal(n >= 4, reveal.sparks ~= nil, "sparks " .. tostring(tier))
			assert.are.equal(n >= 5, reveal.embers ~= nil, "embers " .. tostring(tier))
			assert.are.equal(n >= 5, reveal.shake ~= nil, "shake " .. tostring(tier))
			assert.are.equal(n >= 6, reveal.flash ~= nil, "flash " .. tostring(tier))
		end
		assert.are.equal(5, ns.CrateRevealOf(5).embers)
		assert.are.same({ amplitude = 4, dur = 0.38 }, ns.CrateRevealOf(5).shake)
		assert.are.same({ amplitude = 7, dur = 0.6 }, ns.CrateRevealOf(6).shake)
		assert.are.equal(56, ns.CrateRevealOf(4).sparks.count) -- the prototype's 20 + 12 a tier
		assert.are.equal(80, ns.CrateRevealOf(6).sparks.count)
	end)

	it("gives Curio a flash, a shake and a shower of coins, and a good no other coins", function()
		local curio = ns.CrateRevealOf("curio")

		assert.is_not_nil(curio.flash)
		assert.is_not_nil(curio.shake)
		assert.are.equal(46, curio.coins)
		assert.are.equal("curio", curio.sting)
		for _, tier in ipairs({ 1, 2, 3, 4, 5, 6 }) do
			assert.is_nil(ns.CrateRevealOf(tier).coins)
			assert.are.same({ "sting" }, { ns.CrateRevealOf(tier).sting })
		end
	end)

	it(
		"gives a payback none of the tier's fanfare, whatever the tier: no tremble, whip, sparks, embers, shake or flash",
		function()
			for _, tier in ipairs(TIERS) do
				local reveal = ns.CrateRevealOf(tier, true)
				assert.are.same(
					{ 0.76, false, 1, 0.48, true },
					{ reveal.wait, reveal.tremble, reveal.halfTurns, reveal.turn, reveal.payback },
					tostring(tier)
				)
				assert(reveal.whip == nil, tostring(tier))
				assert(reveal.sparks == nil, tostring(tier))
				assert(reveal.embers == nil, tostring(tier))
				assert(reveal.shake == nil, tostring(tier))
				assert(reveal.flash == nil, tostring(tier))
				assert.are.same({ 8, "payback" }, { reveal.coins, reveal.sting }, tostring(tier))
			end
		end
	)

	it("lets the tier's colour still tint a payback's steady rays, as bright as a good's of that tier", function()
		for _, tier in ipairs(TIERS) do
			assert.are.equal(ns.CrateRevealOf(tier).raysAlpha, ns.CrateRevealOf(tier, true).raysAlpha)
		end
		assert.is_true(ns.CrateRevealOf(1).raysAlpha < ns.CrateRevealOf(5).raysAlpha)
		assert.are.equal(1, ns.CrateRevealOf(6).raysAlpha)
	end)
end)

describe("The opening's key times (SHOP-R55, Motion row)", function()
	-- The beats by name.
	local function at(beats, name, index)
		for _, beat in ipairs(beats) do
			if beat.beat == name and (index == nil or beat.index == index) then
				return beat.t
			end
		end
		error("no beat " .. name)
	end

	it("drops the crate to land at 0.7 s, settle at 1.0 s, and puts the plaque and odds up at 1.0 s", function()
		local beats = ns.CrateRunBeats()

		assert.is_near(0.7, at(beats, "crateLand"), 1e-9)
		assert.are.equal(0.25, at(beats, "drop"))
		assert.is_near(0.75, beats[3].dur, 1e-9)
		assert.are.same({ 1.0, 0.5 }, { at(beats, "plaque"), beats[5].dur })
		assert.are.equal(0.25, at(beats, "purse"))
	end)

	it("rattles at 1.25, 1.6 and 1.9 s, cracks at 2.2 s, flies the lid at 2.38 s, opens the reel at 2.9 s", function()
		local beats = ns.CrateRunBeats()

		assert.are.same({ 1.25, 1.6, 1.9 }, { at(beats, "rattle", 1), at(beats, "rattle", 2), at(beats, "rattle", 3) })
		assert.are.same({ 3, 5, 8 }, ns.CRATE_TIMES.rattleTilt)
		assert.are.same({ 2.2, 2.38, 2.9 }, { at(beats, "crack"), at(beats, "lid"), at(beats, "reelOpen") })
	end)

	it("runs the reel from 3.3 s for 6.4 s, lands at 9.7 s, and begins the reveal at 10.35 s", function()
		local beats = ns.CrateRunBeats()

		assert.are.equal(3.3, at(beats, "spin"))
		assert.is_near(9.7, at(beats, "spin") + 6.4, 1e-9)
		assert.is_near(9.7, at(beats, "cardLand"), 1e-9)
		assert.are.equal(10.35, ns.CRATE_TIMES.reveal)
		assert.is_near(0.65, ns.CRATE_TIMES.reveal - ns.CRATE_TIMES.landed, 1e-9)
		assert.is_true(beats[#beats].t < ns.CRATE_TIMES.reveal)
	end)

	it("shows a tier 6 good at about 12.4 s and its buttons at about 13.3 s", function()
		local beats, shown, buttons = ns.CrateTimeline(6, false)

		assert.is_near(12.38, shown, 0.005)
		assert.is_near(13.33, buttons, 0.005)
		assert.is_near(13.33, at(beats, "buttons"), 1e-9)
		assert.is_near(shown, at(beats, "face"), 1e-9)
	end)

	it("shows a tier 1 good at about 11.5 s", function()
		local _, shown = ns.CrateTimeline(1, false)

		assert.is_near(11.49, shown, 0.005)
	end)

	it("shows a payback's coins at about 11.5 s and its button at about 12.4 s", function()
		for _, tier in ipairs({ 1, 6, "curio" }) do
			local beats, shown, buttons = ns.CrateTimeline(tier, true)
			assert.is_near(11.49, shown, 0.005)
			assert.is_near(12.44, buttons, 0.005)
			assert.is_near(buttons, at(beats, "buttons"), 1e-9)
		end
	end)

	it(
		"brings the tier's name, the good's name and its kind in 0.2 s, 0.32 s and 0.45 s after the face, the stamp at 0.65 s",
		function()
			local reveal = ns.CrateRevealBeats(ns.CrateRevealOf(3))
			local face = at(reveal, "face")

			local seen = {}
			for _, name in ipairs({ "tier", "name", "kind", "stamp", "buttons" }) do
				seen[#seen + 1] = math.floor((at(reveal, name) - face) * 100 + 0.5) / 100
			end
			assert.are.same({ 0.2, 0.32, 0.45, 0.65, 0.95 }, seen)
			assert.are.equal(0.45, ns.CRATE_REVEAL.inDur)
		end
	)

	it("brings a payback's tier name alone, with no good's name or kind", function()
		local reveal = ns.CrateRevealBeats(ns.CrateRevealOf(2, true))
		local names = {}
		for _, beat in ipairs(reveal) do
			names[beat.beat] = true
		end

		assert.is_true(names.tier)
		assert.is_nil(names.name)
		assert.is_nil(names.kind)
		assert.is_nil(names.tremble)
	end)

	it(
		"lifts the card as the reel drops, waits, then turns: trembling between lifting and turning from tier 4",
		function()
			local reveal = ns.CrateRevealBeats(ns.CrateRevealOf(5))

			assert.are.same({ 0, 0.15, 0.3 }, { at(reveal, "lift"), at(reveal, "reelDrop"), at(reveal, "rays") })
			assert.is_near(0.7, at(reveal, "tremble"), 1e-9)
			assert.is_near(0.76 + 0.44, at(reveal, "turn"), 1e-9)
			for _, beat in ipairs(ns.CrateRevealBeats(ns.CrateRevealOf(3))) do
				assert.are_not.equal("tremble", beat.beat)
			end
		end
	)

	it("lists every beat in time order", function()
		for _, tier in ipairs({ 1, 4, 6, "curio" }) do
			for _, payback in ipairs({ false, true }) do
				local beats = ns.CrateTimeline(tier, payback)
				local last = -1
				for _, beat in ipairs(beats) do
					assert(beat.t >= last or beat.beat == "dim", beat.beat)
					last = math.max(last, beat.t)
				end
			end
		end
	end)
end)

describe("The opening's sounds (SHOP-R55, Motion row: the sounds paragraph)", function()
	-- Every beat that sounds, as "<time> <file name>", for a crate of `tier`.
	local function sounds(tier, payback)
		local list = {}
		for _, beat in ipairs((ns.CrateTimeline(tier, payback))) do
			if beat.sound then
				local path = ns.CrateSoundPath(beat.sound, beat.index)
				list[#list + 1] = ("%.2f %s"):format(beat.t, path:match("([^\\]+)%.ogg$"))
			end
		end
		return list
	end

	it(
		"sounds the crate landing, each rattle, the seal and straps, the lid, the reel opening and the card landing",
		function()
			local list = sounds(1, false)

			assert.are.same({
				"0.70 crate_land",
				"1.25 crate_knock_1",
				"1.60 crate_knock_2",
				"1.90 crate_knock_3",
				"2.20 seal_crack",
				"2.20 straps_snap",
				"2.38 lid_whoosh",
				"2.90 reel_open",
				"9.70 card_land",
			}, { unpack(list, 1, 9) })
		end
	)

	it("sounds a turn at each half turn, a sting as a good's face comes round, then the stamp landing", function()
		-- tier 1: half a turn, its sound in the middle of it (11.35 s); its face at 11.49 s; the stamp lands 0.83 s after
		local one = sounds(1, false)
		assert.are.same({ "11.35 card_turn", "11.49 sting_1", "12.32 stamp" }, { unpack(one, 10, 12) })
		-- tier 4: one and a half turns, a sound for each of its three half turns
		local four = sounds(4, false)
		local turns = 0
		for _, line in ipairs(four) do
			turns = turns + (line:find("card_turn") and 1 or 0)
		end
		assert.are.equal(3, turns)
		assert.are.equal(
			5,
			(function()
				local n = 0
				for _, line in ipairs(sounds("curio", false)) do
					n = n + (line:find("card_turn") and 1 or 0)
				end
				return n
			end)()
		)
	end)

	it("sounds a sting for each crate tier, Curio's own, and a payback's own coin sound in its place", function()
		for tier = 1, 6 do
			local found
			for _, line in ipairs(sounds(tier, false)) do
				found = found or line:match("sting_%d")
			end
			assert.are.equal("sting_" .. tier, found, tostring(tier))
		end
		local curio, payback = sounds("curio", false), sounds("curio", true)
		assert.is_truthy(table.concat(curio, " "):find("sting_curio", 1, true))
		assert.is_falsy(table.concat(curio, " "):find("payback", 1, true))
		for _, tier in ipairs({ 1, 6, "curio" }) do
			local text = table.concat(sounds(tier, true), " ")
			assert(text:find("payback", 1, true), tostring(tier))
			assert(not text:find("sting", 1, true), tostring(tier))
			assert(text:find("stamp", 1, true), tostring(tier))
		end
		assert.is_truthy(table.concat(payback, " "):find("1%d%.%d+ payback"))
	end)

	it("plays each sound from the files in ns.CRATE_SOUNDS, a tick in three pitches in turn", function()
		for _, name in ipairs({
			"crateLand",
			"sealCrack",
			"strapsSnap",
			"lidWhoosh",
			"reelOpen",
			"cardLand",
			"cardTurn",
			"stamp",
			"payback",
			"curio",
		}) do
			assert.are.equal(ns.CRATE_SOUNDS[name], ns.CrateSoundPath(name), name)
		end
		for i = 1, 3 do
			assert.are.equal(ns.CRATE_SOUNDS.ticks[i], ns.CrateSoundPath("tick", i))
			assert.are.equal(ns.CRATE_SOUNDS.knocks[i], ns.CrateSoundPath("knock", i))
		end
		assert.are.equal(ns.CRATE_SOUNDS.stings[6], ns.CrateSoundPath("sting", 6))
	end)
end)

describe("What a click or Esc does in each phase (SHOP-R55, Motion row)", function()
	it("takes a click or Esc in the crate, the reel or as it lands straight to the reveal", function()
		for _, phase in ipairs({ "crate", "reel", "landed" }) do
			assert.are.equal("skip", ns.CrateInput(phase, nil), phase .. " click")
			assert.are.equal("skip", ns.CrateInput(phase, "ESCAPE"), phase .. " Esc")
		end
	end)

	it("lets a click on the reveal do nothing, and Esc there be Back to the shop", function()
		assert.is_nil(ns.CrateInput("reveal", nil))
		assert.are.equal("back", ns.CrateInput("reveal", "ESCAPE"))
	end)

	it("lets every other key go on to the game", function()
		for _, phase in ipairs({ "crate", "reel", "landed", "reveal" }) do
			assert((ns.CrateInput(phase, "SPACE")) == nil, phase)
		end
	end)
end)
