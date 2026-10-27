---@class PagleNS
local ns = select(2, ...)

-- The Curio crate's opening as data and maths (wallet-and-shop.md › UI: Motion and sound, "A crate opens"; SHOP-R55):
-- the reel's 60 cards, its run (the easing, where it stops, the card the line is over), the opening's key times, and what
-- each crate tier adds to the reveal. Pure logic (CORE-R7): adapter/ShopMotion.lua plays it, adapter/ShopCrate.lua draws
-- it. The result is already the draw's (SHOP-R51); everything here is how it is shown, so a card the reel shows is
-- cosmetic and may come from math.random.

--- The reel (Motion row): 60 cards, 120 wide and 130 apart, the 53rd the result's; it runs from the 4th card for 6.4 s,
--- easing out, to stop with the line inside the 53rd, up to 48 units off its middle either way.
ns.CRATE_REEL = {
	cards = 60,
	first = 4,
	win = 53,
	cardWidth = 120,
	pitch = 130,
	offset = 48,
	duration = 6.4,
	power = 4.6,
	-- Two ticks of one card crossing never sound closer than this (the prototype's 28 ms).
	tickGap = 0.028,
}

--- The kind of emblem a card shows for each kind of pool good (SHOP-R50); the coin card's is "coin". A kind with no good
--- in the pool needs none (the crest, today).
---@type table<string, string>
ns.CRATE_EMBLEMS = {
	toaststyle = "toast",
	soundset = "sound",
	binding = "book",
	trackerframe = "tracker",
}

--- The emblem for a pool good's kind: the coin's for a kind that has none.
---@param kind string?
---@return string
function ns.CrateEmblem(kind)
	return ns.CRATE_EMBLEMS[kind or ""] or "coin"
end

--- The kind of pool good `goodID` (SHOP-R50), nil for a good not in the pool.
---@param goodID string
---@return string?
function ns.CrateKindOf(goodID)
	for _, row in ipairs(ns.CRATE_POOL) do
		if row.id == goodID then
			return row.kind
		end
	end
	return nil
end

--- A crate tier as a number: 1 to 6, and 7 for Curio.
---@param tier 1|2|3|4|5|6|"curio"
---@return integer
function ns.CrateTierIndex(tier)
	return tier == "curio" and 7 or tier --[[@as integer]]
end

--- One card on the reel: the crate tier whose colour it takes, and what it shows: the kind's emblem ("kind", with its
--- pool kind), the coin ("coin", a tier with no good left, or a payback) or the Curio "?" ("curio").
---@class PagleCrateCard
---@field tier 1|2|3|4|5|6|"curio"
---@field face "kind"|"coin"|"curio"
---@field kind string? the pool kind, for a "kind" card

--- The crate tier the odds give for a roll `r` of 1 to 1000 (SHOP-R51's odds, in per mille).
---@param r integer
---@return 1|2|3|4|5|6|"curio"
local function tierByOdds(r)
	local running = 0
	for i, tier in ipairs(ns.CRATE_TIERS) do
		running = running + ns.CRATE_ODDS[i]
		if r <= running then
			return tier
		end
	end
	return "curio"
end

--- The card for a good or a payback `result` (SHOP-R55): the good's crate tier and kind, the Curio "?" for a crate-only
--- good, or the coin card for a payback.
---@param result PagleCrateResult
---@return PagleCrateCard
function ns.CrateResultCard(result)
	if not result.good then
		return { tier = result.tier, face = "coin" }
	end
	if result.crateOnly then
		return { tier = result.tier, face = "curio" }
	end
	return { tier = result.tier, face = "kind", kind = ns.CrateKindOf(result.good) }
end

--- The reel's 60 cards for a crate that gave `result` (Motion row): the 53rd is the result's, every other one is drawn as
--- SHOP-R51 draws, from what the Angler could still win: a crate tier by the odds, then, if that tier has candidates, the
--- kind of one of them, and if not, a coin card in the tier's colour; Curio's card, while a crate-only good is a
--- candidate, is the "?". `owned` is what the Angler owns now, the crate's own good among it (it gave a good not owned
--- before), `now` the server time, and `rand(n)` a whole number from 1 to n (math.random).
---@param result PagleCrateResult
---@param owned table<string, true>
---@param now integer?
---@param rand fun(n: integer): integer
---@return PagleCrateCard[]
function ns.CrateReelCards(result, owned, now, rand)
	local before = {}
	for id in pairs(owned) do
		before[id] = true
	end
	if result.good then
		before[result.good] = nil
	end
	local candidates = {}
	for _, tier in ipairs(ns.CRATE_TIERS) do
		candidates[tier] = ns.CrateCandidates(tier, before, now)
	end
	local reel = ns.CRATE_REEL
	local cards = {}
	for i = 1, reel.cards do
		if i == reel.win then
			cards[i] = ns.CrateResultCard(result)
		else
			local tier = tierByOdds(rand(1000))
			local left = candidates[tier]
			if #left == 0 then
				cards[i] = { tier = tier, face = "coin" }
			elseif tier == "curio" then
				cards[i] = { tier = tier, face = "curio" }
			else
				cards[i] = { tier = tier, face = "kind", kind = left[rand(#left)].kind }
			end
		end
	end
	return cards
end

--- How far off the 53rd card's middle the line stops: a whole number of units from -48 to 48, either way by chance
--- (`rand(n)` is 1 to n).
---@param rand fun(n: integer): integer
---@return integer
function ns.CrateReelOffset(rand)
	local range = ns.CRATE_REEL.offset
	return rand(2 * range + 1) - range - 1
end

--- The reel's easing (Motion row): `1 − (1 − t)^4.6`.
---@param t number
---@return number
function ns.CrateReelEase(t)
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	return 1 - (1 - t) ^ ns.CRATE_REEL.power
end

--- Where the track's left edge lies from the line when card `index` has the line `offset` units right of its middle
--- (card i's left edge is (i - 1) pitches along the track).
---@param index integer
---@param offset number
---@return number
function ns.CrateReelTrackAt(index, offset)
	local reel = ns.CRATE_REEL
	return -((index - 1) * reel.pitch + reel.cardWidth / 2 + offset)
end

--- Where the track lies `t` (0 to 1) of the way through the run to a stop `offset` units off the result's middle: from
--- the 4th card under the line to the 53rd, eased.
---@param t number
---@param offset number
---@return number
function ns.CrateReelTrackX(t, offset)
	local reel = ns.CRATE_REEL
	local from = ns.CrateReelTrackAt(reel.first, 0)
	local to = ns.CrateReelTrackAt(reel.win, offset)
	return from + (to - from) * ns.CrateReelEase(t)
end

--- The card the line is over when the track's left edge lies `x` from it: a card's slot is its own width and half the
--- gap either side, so the line is always over one.
---@param x number
---@return integer
function ns.CrateReelCardAt(x)
	local reel = ns.CRATE_REEL
	local slack = (reel.pitch - reel.cardWidth) / 2
	local index = math.floor((-x + slack) / reel.pitch) + 1
	return math.max(1, math.min(reel.cards, index))
end

--- A run's tick state: the card the line was last over, and when a tick last sounded.
---@class PagleCrateTicks
---@field index integer?
---@field at number?
---@field count integer ticks so far

--- A new run's tick state.
---@return PagleCrateTicks
function ns.NewCrateTicks()
	return { count = 0 }
end

--- Whether a tick sounds now, `seconds` into the run with the line over card `index`: when the line has crossed into
--- another card (the first card of a run, never) and the last tick was more than ns.CRATE_REEL.tickGap ago. Returns the
--- card's crossing as true and counts it.
---@param ticks PagleCrateTicks
---@param index integer
---@param seconds number
---@return boolean
function ns.CrateReelTick(ticks, index, seconds)
	local last = ticks.index
	ticks.index = index
	if last == nil or last == index then
		return false
	end
	if ticks.at and seconds - ticks.at <= ns.CRATE_REEL.tickGap then
		return false
	end
	ticks.at = seconds
	ticks.count = ticks.count + 1
	return true
end

--- The opening's key times in seconds from the click (Motion row), before the reveal.
ns.CRATE_TIMES = {
	-- the case's inside darkens, and the purse counts down as its coin turns
	dim = 0.35,
	purse = 0.25,
	-- the crate drops from 450 units up (0.25 s to 1.0 s), landing at 0.7 s and settling at 1.0 s
	drop = 0.25,
	land = 0.7,
	settle = 1.0,
	fall = 450,
	-- the plaque and the odds line
	plaque = 1.0,
	plaqueDur = 0.5,
	-- three rattles, each tipping the crate more
	rattles = { 1.25, 1.6, 1.9 },
	rattleDur = 0.24,
	rattleTilt = { 3, 5, 8 },
	-- the seal cracks and the ribbons drop; the lid flies off
	crack = 2.2,
	lid = 2.38,
	lidDur = 0.9,
	-- the reel opens out of the light, then runs
	reel = 2.9,
	reelDur = 0.52,
	spin = 3.3,
	-- landed, the card rings; the reveal begins
	landed = 9.7,
	ring = 0.3,
	reveal = 10.35,
}

--- The reveal's constants (Motion row), seconds from its start: the card lifts to the middle at 1.5x (0.7 s) as the reel
--- drops 48 units and fades, the rays fade in (0.9 s from 0.3 s), then the wait; after the face comes round (a turn's
--- 0.8) the tier's name, the good's name and its kind come in, the stamp lands and the buttons come.
ns.CRATE_REVEAL = {
	lift = 0.7,
	reelDrop = 48,
	reelFrom = 0.15,
	reelDur = 0.5,
	raysFrom = 0.3,
	raysDur = 0.9,
	scale = 1.5,
	-- the wait: 0.76 s, and 0.11 s for each tier above 1
	wait = 0.76,
	waitPerTier = 0.11,
	-- the face comes round this far through the turn
	faceAt = 0.8,
	-- from the face: the tier's name, the good's name, its kind, each 0.45 s; the stamp (0.26 s), the buttons (0.4 s)
	tierIn = 0.2,
	nameIn = 0.32,
	kindIn = 0.45,
	inDur = 0.45,
	stamp = 0.65,
	stampDur = 0.26,
	stampLand = 0.18,
	stampFrom = 2.6,
	buttons = 0.95,
	buttonsDur = 0.4,
	-- the steady rays: one turn in 14 s, the other the other way in 22 s
	spinA = 14,
	spinB = 22,
	-- a payback's small shower of coins, and the purse counting up
	paybackCoins = 8,
	showerDur = 1.2,
	count = 0.9,
}

--- What a crate tier adds to the reveal (Motion row).
---@class PagleCrateReveal
---@field tier integer the crate tier as a number, 1 to 7 (Curio)
---@field payback boolean a payback has none of the tier's fanfare
---@field wait number seconds the card waits after it lifts out, before it turns
---@field tremble boolean it trembles while it waits (tier 4 up)
---@field halfTurns integer
---@field turn number seconds the turn takes
---@field face number seconds from the reveal's start to the face coming round
---@field raysAlpha number how bright the steady rays are, 0 to 1
---@field whip { degrees: number, dur: number }? the rays whip back round as the face comes
---@field sparks { count: integer, spread: number }? a burst of sparks, the spread in units
---@field embers number? seconds of embers rising
---@field shake { amplitude: number, dur: number }? the case shakes, in units
---@field flash number? a white flash's opacity
---@field coins integer? a shower of coins: Curio's, or a payback's small one
---@field sting string the sound as the face comes round: "sting" (with `index`), "curio" or "payback"

--- What crate tier `tier` adds to the reveal of a good, or of a payback (which has none of the tier's fanfare: it waits
--- 0.76 s with no tremble, whatever the tier, and turns over once, with no whip, sparks, embers, shake or flash, a small
--- shower of 8 coins in their place; the tier's colour still tints the card and the steady rays).
---@param tier 1|2|3|4|5|6|"curio"
---@param payback boolean?
---@return PagleCrateReveal
function ns.CrateRevealOf(tier, payback)
	local reveal = ns.CRATE_REVEAL
	local n = ns.CrateTierIndex(tier)
	-- (UI px 0.8: the prototype's 20 + 12 a tier of sparks spread 240 + 30 a tier px wide, in units)
	local params = {
		tier = n,
		payback = payback == true,
		wait = reveal.wait,
		tremble = false,
		halfTurns = 1,
		turn = 0.48,
		raysAlpha = n >= 6 and 1 or 0.4 + (n - 1) * 0.1,
		sting = "sting",
	}
	if payback then
		params.coins = reveal.paybackCoins
		params.sting = "payback"
	else
		params.wait = reveal.wait + reveal.waitPerTier * (n - 1)
		params.tremble = n >= 4
		params.halfTurns = n == 7 and 5 or n >= 4 and 3 or 1
		params.turn = n == 7 and 1.5 or n >= 4 and 0.9 or 0.48
		params.whip = { degrees = 60 + 30 * (n - 1), dur = 1.6 + 0.1 * (n - 1) }
		if n >= 4 then
			params.sparks = n == 7 and { count = 70, spread = 380 * 0.8 }
				or { count = 20 + 12 * (n - 1), spread = (240 + 30 * (n - 1)) * 0.8 }
		end
		if n >= 5 then
			params.embers = 5
			params.shake = n == 5 and { amplitude = 4, dur = 0.38 } or { amplitude = n == 7 and 8 or 7, dur = 0.6 }
		end
		if n >= 6 then
			params.flash = n == 7 and 0.8 or 0.7
		end
		if n == 7 then
			params.coins = 46
			params.sting = "curio"
		end
	end
	params.face = params.wait + reveal.faceAt * params.turn
	return params
end

--- A beat of the opening: its time in seconds (from the click, or for the reveal's from its start), what it is, and the
--- sound that plays on it (a key of ns.CRATE_SOUNDS, `index` picking one of a list), none for a beat that is only seen.
---@class PagleCrateBeat
---@field t number
---@field beat string
---@field sound string?
---@field index integer?
---@field dur number?

--- The opening's beats from the click to the line landing on the result's card (Motion row), in time order.
---@return PagleCrateBeat[]
function ns.CrateRunBeats()
	local at = ns.CRATE_TIMES
	local beats = {
		{ t = 0, beat = "dim", dur = at.dim },
		{ t = at.purse, beat = "purse" },
		{ t = at.drop, beat = "drop", dur = at.settle - at.drop },
		{ t = at.land, beat = "crateLand", sound = "crateLand" },
		{ t = at.plaque, beat = "plaque", dur = at.plaqueDur },
	}
	for i, t in ipairs(at.rattles) do
		beats[#beats + 1] = { t = t, beat = "rattle", index = i, sound = "knock", dur = at.rattleDur }
	end
	beats[#beats + 1] = { t = at.crack, beat = "crack", sound = "sealCrack" }
	beats[#beats + 1] = { t = at.crack, beat = "straps", sound = "strapsSnap" }
	beats[#beats + 1] = { t = at.lid, beat = "lid", sound = "lidWhoosh", dur = at.lidDur }
	beats[#beats + 1] = { t = at.reel, beat = "reelOpen", sound = "reelOpen", dur = at.reelDur }
	beats[#beats + 1] = { t = at.spin, beat = "spin", dur = ns.CRATE_REEL.duration }
	beats[#beats + 1] = { t = at.landed, beat = "cardLand", sound = "cardLand", dur = at.ring }
	return beats
end

--- The reveal's beats for `params` (ns.CrateRevealOf), seconds from its start, in time order: the card lifts out, the
--- reel drops, the rays come in, the card trembles (tier 4 up), turns (a sound for each half turn), the face comes round
--- (the sting, or a payback's coin sound), and from it the tier's name, the good's name and its kind (a good's alone),
--- the stamp (landing with its sound), and the buttons. A payback's face also pours its coins and counts the purse up.
---@param params PagleCrateReveal
---@return PagleCrateBeat[]
function ns.CrateRevealBeats(params)
	local reveal = ns.CRATE_REVEAL
	local beats = {
		{ t = 0, beat = "lift", dur = reveal.lift },
		{ t = reveal.reelFrom, beat = "reelDrop", dur = reveal.reelDur },
		{ t = reveal.raysFrom, beat = "rays", dur = reveal.raysDur },
	}
	if params.tremble then
		beats[#beats + 1] = { t = reveal.lift, beat = "tremble", dur = params.wait - reveal.lift }
	end
	beats[#beats + 1] = { t = params.wait, beat = "turn", dur = params.turn }
	for i = 0, params.halfTurns - 1 do
		beats[#beats + 1] = {
			t = params.wait + (i + 0.5) * params.turn / params.halfTurns,
			beat = "halfTurn",
			index = i + 1,
			sound = "cardTurn",
		}
	end
	local face = params.face
	local sting = params.sting
	beats[#beats + 1] = {
		t = face,
		beat = "face",
		sound = sting,
		index = sting == "sting" and math.min(params.tier, 6) or nil,
	}
	beats[#beats + 1] = { t = face + reveal.tierIn, beat = "tier", dur = reveal.inDur }
	if not params.payback then
		beats[#beats + 1] = { t = face + reveal.nameIn, beat = "name", dur = reveal.inDur }
		beats[#beats + 1] = { t = face + reveal.kindIn, beat = "kind", dur = reveal.inDur }
	end
	beats[#beats + 1] = { t = face + reveal.stamp, beat = "stamp", dur = reveal.stampDur }
	beats[#beats + 1] = { t = face + reveal.stamp + reveal.stampLand, beat = "stampLand", sound = "stamp" }
	beats[#beats + 1] = { t = face + reveal.buttons, beat = "buttons", dur = reveal.buttonsDur }
	table.sort(beats, function(a, b)
		return a.t < b.t
	end)
	return beats
end

--- The whole opening of a crate of `tier`, `payback` or not, as absolute times from the click: the run's beats, then the
--- reveal's from ns.CRATE_TIMES.reveal. The seconds the good (or the coins) show, and the seconds the buttons come.
---@param tier 1|2|3|4|5|6|"curio"
---@param payback boolean?
---@return PagleCrateBeat[] beats
---@return number shown
---@return number buttons
function ns.CrateTimeline(tier, payback)
	local params = ns.CrateRevealOf(tier, payback)
	local start = ns.CRATE_TIMES.reveal
	local beats = ns.CrateRunBeats()
	for _, beat in ipairs(ns.CrateRevealBeats(params)) do
		local placed = {}
		for key, value in pairs(beat) do
			placed[key] = value
		end
		placed.t = beat.t + start
		beats[#beats + 1] = placed
	end
	return beats, start + params.face, start + params.face + ns.CRATE_REVEAL.buttons
end

--- What a click or Esc does in `phase` of an opening: "crate", "reel" or "landed" go straight to the reveal ("skip"), a
--- click in the reveal does nothing (its buttons take their own), and Esc there is "Back to the shop" ("back"). Any
--- other key goes on to the game.
---@param phase "crate"|"reel"|"landed"|"reveal"
---@param key string? "ESCAPE", or nil for a click
---@return "skip"|"back"|nil
function ns.CrateInput(phase, key)
	if phase == "reveal" then
		return key == "ESCAPE" and "back" or nil
	end
	return (key == nil or key == "ESCAPE") and "skip" or nil
end

--- The sound file for a beat's `sound` (ns.CRATE_SOUNDS: a name, `index` picking from a list; a sting's tier 1 to 6).
---@param sound string
---@param index integer?
---@return string
function ns.CrateSoundPath(sound, index)
	local file =
		ns.CRATE_SOUNDS[sound == "knock" and "knocks" or sound == "tick" and "ticks" or sound == "sting" and "stings" or sound]
	if type(file) == "table" then
		return file[index or 1]
	end
	return file
end
