---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The Curio crate's opening, played (wallet-and-shop.md › UI: Motion and sound, "A crate opens"; SHOP-R55): the crate
-- drops, rattles and bursts open, the reel runs, and the card lifts out and turns over to the good, or the Coins paid
-- back. logic/CrateReel.lua says when (its beats, its reveal's parameters), adapter/ShopCrate.lua draws the pieces, and
-- this plays them on adapter/ShopMotion.lua's timeline, every part and cue on the case's one clock so that stopping it
-- stops it all, and the rays and the particles on the inside's, which have no end. Only translate, rotate, scale and
-- opacity move, as the toast renderer's do (ANN-R82). With the Animations setting off nothing plays: the result is at
-- once (ns.SettleShopCrate). The prototype's px are 0.8 UI units.
local UI = 0.8
local layout = ns.CRATE_STAGE
local CX = layout.cx

--- What a crate's opening needs from adapter/Shop.lua: the stage it plays on, the result it ends on (its tier's reveal and
--- its words), the purse paying out and, for a payback, counting back, and what to run when the whole of it has played.
---@class PagleShopCrateMotion
---@field stage PagleCrateStage
---@field reveal PagleCrateReveal
---@field closeBill fun(owner: Frame) lifts the bill away on `owner`'s clock (ns.CloseShopBill)
---@field pay PagleShopPayMotion the purse paying the crate's price out
---@field count PagleShopPayMotion? a payback's purse counting its Coins back
---@field settlePurse fun() writes the balance as it ends
---@field onDone fun() runs once it has all played

--- A random number, for the straw, sparks and coins: cosmetic, so math.random. `ns.CrateRandom` is the one place to give
--- another (`random()` is a float from 0 to 1, `random(n)` a whole number from 1 to n).
---@type fun(n: integer?): number
ns.CrateRandom = math.random

local function random(n)
	if n then
		return ns.CrateRandom(n)
	end
	return ns.CrateRandom()
end

-- Plays a beat's sound on the SFX channel (ANN-R73), with the Animations setting on only.
---@param name string
---@param index integer?
local function sound(name, index)
	if ns.MotionOn() then
		PlaySoundFile(ns.CrateSoundPath(name, index), "SFX")
	end
end

-- CSS's effect easing as the prototype's Web Animations give it: `ease` shapes the whole run, and the keys, each an
-- offset of what it gives with its values, are straight lines between. `apply` is given the values (the same table each
-- time).
---@param dur number
---@param ease PagleEase
---@param keys number[][] { offset, value, value, ... }
---@param apply fun(v: number[])
---@param delay number?
---@return PagleAnimation
local function along(dur, ease, keys, apply, delay)
	local out = {}
	local last, count = #keys, #keys[1] - 1
	return {
		dur = dur,
		delay = delay,
		ease = ns.EASE.linear,
		keys = { { 0, { 0 } }, { 1, { 1 } } },
		apply = function(v)
			local u = ease(v[1])
			local i = 1
			while i < last - 1 and keys[i + 1][1] < u do
				i = i + 1
			end
			local a, b = keys[i], keys[i + 1]
			local span = b[1] - a[1]
			local k = span > 0 and math.max(0, math.min(1, (u - a[1]) / span)) or 1
			for j = 1, count do
				out[j] = a[j + 1] + (b[j + 1] - a[j + 1]) * k
			end
			apply(out)
		end,
	}
end

-- Moves the opening on to `phase`, and says so (adapter/Shop.lua's catcher stops taking clicks in the reveal).
---@param stage PagleCrateStage
---@param phase "crate"|"reel"|"landed"|"reveal"
local function setPhase(stage, phase)
	stage.phase = phase
	if stage.onPhase then
		stage.onPhase(phase)
	end
end

-- The easings the prototype names.
local ACCEL = ns.Bezier(0.55, 0, 1, 0.45)
local PUFF = ns.Bezier(0.2, 0.7, 0.4, 1)
local SEAL_EASE = ns.Bezier(0.3, 0.6, 0.6, 1)
local LID_EASE = ns.Bezier(0.2, 0.8, 0.4, 1)
local REEL_EASE = ns.Bezier(0.2, 0.9, 0.3, 1)
local PLAQUE_EASE = ns.Bezier(0.2, 0.9, 0.3, 1.2)
local LIFT_EASE = ns.Bezier(0.2, 0.8, 0.3, 1)
local TURN_EASE = ns.Bezier(0.45, 0, 0.2, 1)
local WHIP_EASE = ns.Bezier(0.1, 0.7, 0.2, 1)
local STAMP_EASE = ns.Bezier(0.6, 0, 0.9, 0.4)
local EASE_IN = ns.EASE["in"]
local OUT = ns.EASE.out

-- How long the particles' clock runs: longer than any of them lives.
local FX_SPAN = 60

-- Poses the crate as a whole (about its foot): moved down `ty`, turned `deg`, squashed to `sx` and `sy`, `tx` across.
---@param stage PagleCrateStage
---@param ty number
---@param deg number
---@param sx number
---@param sy number
---@param tx number?
local function setGroup(stage, ty, deg, sx, sy, tx)
	local g = stage.group
	g.tx, g.ty, g.deg, g.sx, g.sy = tx or 0, ty, deg, sx, sy
	for _, part in ipairs(stage.parts) do
		if part.group then
			ns.PoseCratePart(stage, part)
		end
	end
end

-- Draws a part of the crate at its own pose `x`, `y` over it, `deg` turned, `sx` by `sy` the size, opacity `a`.
---@param stage PagleCrateStage
---@param part PagleCratePart
---@param x number
---@param y number
---@param deg number
---@param s number
---@param a number
local function setPart(stage, part, x, y, deg, s, a)
	local own = part.own --[[@as number[] ]]
	own[1], own[2], own[3], own[4], own[5] = x, y, deg, s, s
	ns.PoseCratePart(stage, part)
	ns.FadeCratePart(stage, part, a)
end

-- Shows how much of the crate's light and beam there is: the burst, the beam (grown `sy` up from its foot) and the
-- crate's rays.
---@param stage PagleCrateStage
---@param burst number
---@param burstScale number
local function setBurst(stage, burst, burstScale)
	local part = stage.burst
	ns.FadeCratePart(stage, part, burst)
	local own = part.own --[[@as number[] ]]
	own[4], own[5] = burstScale, burstScale
	ns.PoseCratePart(stage, part)
end

---@param stage PagleCrateStage
---@param opacity number
---@param sy number
local function setBeam(stage, opacity, sy)
	local part = stage.beam
	ns.FadeCratePart(stage, part, opacity)
	local own = part.own --[[@as number[] ]]
	own[5] = sy
	ns.PoseCratePart(stage, part)
end

-- Turns the three fans: the crate's rays, then the reveal's two (which the whip turns further).
---@param stage PagleCrateStage
local function turnFans(stage)
	for i = 1, 3 do
		local deg = stage.rayTurn[i] + (i > 1 and stage.whip or 0)
		stage.fans[i].tex:SetRotation(-math.rad(deg))
	end
end

-- Starts the fans turning, and the particles' clock: one turn in 40 s for the crate's rays, 14 s and, the other way,
-- 22 s for the reveal's (Motion row). They end with the opening.
---@param stage PagleCrateStage
local function startLoops(stage)
	local reveal = ns.CRATE_REVEAL
	ns.StopMotion(stage.root)
	stage.swarmNow = 0
	ns.Animate(stage.root, {
		{
			dur = 40,
			ease = ns.EASE.linear,
			iter = "infinite",
			keys = { { 0, { 0 } }, { 1, { 360 } } },
			apply = function(v)
				stage.rayTurn[1] = v[1]
				turnFans(stage)
			end,
		},
		{
			dur = reveal.spinA,
			ease = ns.EASE.linear,
			iter = "infinite",
			keys = { { 0, { 0 } }, { 1, { 360 } } },
			apply = function(v)
				stage.rayTurn[2] = v[1]
				turnFans(stage)
			end,
		},
		{
			dur = reveal.spinB,
			ease = ns.EASE.linear,
			iter = "infinite",
			keys = { { 0, { 360 } }, { 1, { 0 } } },
			apply = function(v)
				stage.rayTurn[3] = v[1]
				turnFans(stage)
			end,
		},
		{
			dur = FX_SPAN,
			ease = ns.EASE.linear,
			keys = { { 0, { 0 } }, { 1, { FX_SPAN } } },
			apply = function(v)
				ns.StepCrateFx(stage, v[1])
			end,
		},
	})
end

-- One particle's start: what it flies for, a little after `delay`.
---@param p PagleCrateParticle
---@param now number
---@param delay number
---@param dur number
local function launch(p, now, delay, dur)
	p.live, p.start, p.dur, p.ease = true, now + delay, dur, PUFF
end

-- Fills a particle's keys, each a table of seven numbers: its offset of the run from 0 to 1, then its x, y, scale,
-- opacity, turn in degrees and width.
---@param p PagleCrateParticle
---@param ... number[]
local function path(p, ...)
	local n = select("#", ...)
	p.n = n
	for i = 1, n do
		local k = select(i, ...)
		p.o[i], p.x[i], p.y[i], p.s[i], p.a[i], p.r[i], p.f[i] = k[1], k[2], k[3], k[4], k[5], k[6], k[7]
	end
end

-- Straw: a wisp thrown up out of the open crate, which falls (the prototype's straw()).
---@param stage PagleCrateStage
---@param now number
local function straw(stage, now)
	local swarm = ns.CrateSwarmOf(stage, "straw")
	local ink = { { 0.96, 0.86, 0.6 }, { 0.72, 0.56, 0.23 } }
	for i, p in ipairs(swarm.parts) do
		local a = -math.pi / 2 + (random() - 0.5) * 2.2
		local v = (200 + random() * 260) * UI
		local dx, dy = math.cos(a) * v, math.sin(a) * v
		local r = random() * 720 - 360
		local x0, y0 = CX + (random() - 0.5) * 140 * UI, layout.lightY
		local c = ink[i % 2 + 1]
		p.tex:SetVertexColor(c[1], c[2], c[3])
		path(
			p,
			{ 0, x0, y0, 1, 1, 0, 1 },
			{ 0.45, x0 + dx * 0.7, y0 + dy * 0.8, 1, 1, r * 0.6, 1 },
			{ 1, x0 + dx, y0 + dy * 0.3 + 260 * UI, 1, 0, r, 1 }
		)
		launch(p, now, random() * 0.12, 1.3 + random() * 0.7)
	end
end

-- Dust: two puffs each side of the crate as it lands.
---@param stage PagleCrateStage
---@param now number
local function dust(stage, now)
	local swarm = ns.CrateSwarmOf(stage, "dust")
	local i = 0
	for _, side in ipairs({ -1, 1 }) do
		for j = 0, 1 do
			i = i + 1
			local p = swarm.parts[i]
			local x0, y0 = CX + side * (120 + j * 40) * UI, 276.8
			path(
				p,
				{ 0, x0, y0, 0.4, 0.9, 0, 1 },
				{ 1, x0 + side * (70 + j * 40) * UI, y0 - 14 * UI, 1.6 + j * 0.5, 0, 0, 1 }
			)
			launch(p, now, j * 0.04, 0.7 + j * 0.2)
		end
	end
end

-- Sparks: a burst out of the card in the tier's colour, which fall (the prototype's sparks()).
---@param stage PagleCrateStage
---@param count integer
---@param spread number
---@param c number[]
local function sparks(stage, count, spread, c)
	local swarm = ns.CrateSwarmOf(stage, "spark")
	local x0, y0 = layout.heroX, layout.heroY
	for i = 1, math.min(count, #swarm.parts) do
		local p = swarm.parts[i]
		local a = random() * math.pi * 2
		local d = 90 * UI + random() * spread
		local s = 0.5 + random() * 1.3
		p.tex:SetVertexColor(c[1], c[2], c[3])
		path(
			p,
			{ 0, x0, y0, s, 1, 0, 1 },
			{ 0.6, x0 + math.cos(a) * d * 0.8, y0 + math.sin(a) * d * 0.8, s, 1, 0, 1 },
			{ 1, x0 + math.cos(a) * d, y0 + math.sin(a) * d + 40 * UI, 0, 0, 0, 1 }
		)
		launch(p, stage.swarmNow, random() * 0.1, 0.9 + random() * 0.7)
	end
end

-- One ember rising from the foot of the inside (the prototype's embers()).
---@param stage PagleCrateStage
local function ember(stage)
	local swarm = ns.CrateSwarmOf(stage, "ember")
	local p = ns.FreeCrateParticle(swarm)
	if not p then
		return
	end
	local c = stage.rayColour
	local s = 0.4 + random() * 0.9
	local x0, y0 = 160 + random() * (layout.width - 320), layout.height - 8
	p.tex:SetVertexColor(c[1], c[2], c[3])
	path(
		p,
		{ 0, x0, y0, s, 0, 0, 1 },
		{ 0.3, x0 + (random() - 0.5) * 60 * UI, y0 - 180 * UI, s, 1, 0, 1 },
		{ 1, x0 + (random() - 0.5) * 160 * UI, y0 - (380 + random() * 200) * UI, 0, 0, 0, 1 }
	)
	launch(p, stage.swarmNow, 0, 2.2 + random() * 1.2)
end

-- Coins: a shower of `count` thrown up from the card, which turn over as they fall (the prototype's coinsBurst()), about
-- `wide` units across, each in the air `base` seconds and up to `extra` more.
---@param stage PagleCrateStage
---@param count integer
---@param wide number
---@param base number
---@param extra number
local function coins(stage, count, wide, base, extra)
	local swarm = ns.CrateSwarmOf(stage, "coin")
	local x0, y0 = layout.heroX, layout.heroY
	for i = 1, math.min(count, #swarm.parts) do
		local p = swarm.parts[i]
		local dx, up = (random() - 0.5) * wide, (160 + random() * 220) * UI
		path(
			p,
			{ 0, x0, y0, 1, 1, 0, 1 },
			{ 0.4, x0 + dx * 0.5, y0 - up, 1, 1, 0, -1 },
			{ 0.65, x0 + dx * 0.8, y0 - up * 0.4, 1, 1, 0, 1 },
			{ 1, x0 + dx, y0 + 380 * UI, 1, 0, 0, -1 }
		)
		launch(p, stage.swarmNow, random() * 0.2, base + random() * extra)
	end
end

--- Moves the particles to where the swarm clock `now` has them, and sends one more ember up while the embers rise.
---@param stage PagleCrateStage
---@param now number
function ns.StepCrateFx(stage, now)
	stage.swarmNow = now
	local embers = stage.embers
	if embers then
		while embers.nextAt <= now and embers.nextAt < embers.endAt do
			ember(stage)
			embers.nextAt = embers.nextAt + 0.07
		end
	end
	for _, swarm in pairs(stage.swarms) do
		ns.StepCrateSwarm(stage, swarm, now)
	end
end

-- Fades the stage's dark in or out: `a` of its whole.
---@param stage PagleCrateStage
---@param a number
local function setDim(stage, a)
	for _, sheet in ipairs(stage.dim) do
		sheet:SetAlpha(a)
	end
end

-- Moves the case's stage, everything but the dim, `dx`, `dy` units: the shake.
---@param stage PagleCrateStage
---@param dx number
---@param dy number
local function setShake(stage, dx, dy)
	stage.box:ClearAllPoints()
	stage.box:SetPoint("TOPLEFT", stage.root, "TOPLEFT", dx, -dy)
end

-- Opens the reel's wipe `sx` across and `sy` up, its opacity `a`, and lowers it `dy` units.
---@param stage PagleCrateStage
---@param sx number
---@param sy number
---@param a number
---@param dy number
local function setReel(stage, sx, sy, a, dy)
	local reel = stage.reel
	reel.clip:SetAlpha(a)
	reel.clip:SetSize(math.max(0.01, layout.clipWidth * sx), math.max(0.01, layout.clipHeight * sy))
	reel.clip:ClearAllPoints()
	reel.clip:SetPoint("CENTER", stage.box, "TOPLEFT", CX, -(layout.clipY + dy))
	reel.root:ClearAllPoints()
	reel.root:SetPoint("TOPLEFT", stage.box, "TOPLEFT", layout.reelX, -(layout.reelY + dy))
end

-- The track where the run has it `t` of the way along.
---@param stage PagleCrateStage
---@param t number
---@return number x
local function setTrack(stage, t)
	local reel = stage.reel
	local x = ns.CrateReelTrackX(t, stage.offset)
	reel.track:ClearAllPoints()
	reel.track:SetPoint("TOPLEFT", reel.window, "TOPLEFT", layout.windowWidth / 2 + x, -layout.cardTop)
	return x
end

-- Draws the light under the line and its glow in the colour of the card it is over.
---@param stage PagleCrateStage
---@param c number[]
local function setLight(stage, c)
	local reel = stage.reel
	reel.light.tex:SetVertexColor(c[1], c[2], c[3])
	reel.glow.tex:SetVertexColor(c[1], c[2], c[3])
end

-- The bobber dipped `k` of the way out of a dip: turned back 16 degrees and down 3 units, then up (a card crossed).
---@param stage PagleCrateStage
---@param k number 0 to 1
local function setBobber(stage, k)
	local bobber = stage.reel.bobber
	local own = bobber.own --[[@as number[] ]]
	own[2], own[3] = 3 * (1 - k), -16 * (1 - k)
	ns.PoseCratePart(stage, bobber)
end

-- The card the light has taken, and when the bobber last dipped, per run.
---@class PagleCrateRun
---@field ticks PagleCrateTicks
---@field dipped number
---@field dipping boolean

-- The reel's run (Motion row): 6.4 s from the 4th card to the line inside the 53rd, easing out; each card the line
-- crosses dips the bobber (0.14 s), sounds a tick (three in turn) and gives its colour to the light under the line.
---@param owner Frame
---@param stage PagleCrateStage
local function spin(owner, stage)
	local reel = ns.CRATE_REEL
	local run = { ticks = ns.NewCrateTicks(), dipped = -1, dipping = false } --[[@as PagleCrateRun]]
	ns.Animate(owner, {
		{
			dur = reel.duration,
			ease = ns.EASE.linear,
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				local seconds = v[1] * reel.duration
				local x = setTrack(stage, v[1])
				local index = ns.CrateReelCardAt(x)
				local before = run.ticks.index
				if before ~= index then
					setLight(stage, stage.reel.cards[index].colour)
				end
				if ns.CrateReelTick(run.ticks, index, seconds) then
					sound("tick", (run.ticks.count - 1) % 3 + 1)
					run.dipped, run.dipping = seconds, true
				end
				if run.dipping then
					local k = (seconds - run.dipped) / 0.14
					setBobber(stage, math.min(1, k))
					run.dipping = k < 1
				end
			end,
		},
	})
end

--- The crate and the reel up to where the line lands, as it plays: each beat's handler, on `owner`'s clock.
---@type table<string, fun(owner: Frame, m: PagleShopCrateMotion, beat: PagleCrateBeat)>
local RUN = {}

function RUN.dim(owner, m)
	local stage = m.stage
	m.closeBill(owner)
	ns.Animate(owner, {
		{
			dur = ns.CRATE_TIMES.dim,
			ease = OUT,
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				setDim(stage, v[1])
			end,
		},
	})
	startLoops(stage)
	-- the crate's rays come in as the lid goes: ns.CRATE_TIMES.lid
	ns.FadeCratePart(stage, stage.fans[1], 0)
end

function RUN.purse(owner, m)
	ns.ShopPayOut(owner, m.pay)
end

function RUN.drop(owner, m)
	local stage = m.stage
	local fall = ns.CRATE_TIMES.fall
	ns.Animate(owner, {
		-- the crate falls (accelerating) to land at 0.7 s, squashes to 110% wide and 86% tall, bounces 21 units and settles
		{
			dur = ns.CRATE_TIMES.settle - ns.CRATE_TIMES.drop,
			ease = OUT,
			keys = {
				{ 0, { -fall, -6, 1, 1, 1 }, ease = ACCEL },
				{ 0.6, { 0, 0, 1, 1, 1 } },
				{ 0.72, { 0, 0, 1.1, 0.86, 1 } },
				{ 0.84, { -21, 0, 0.96, 1.05, 1 } },
				{ 1, { 0, 0, 1, 1, 1 } },
			},
			apply = function(v)
				setGroup(stage, v[1], v[2], v[3], v[4])
				ns.SetCrateGroupAlpha(stage, v[5])
			end,
		},
	})
end

function RUN.crateLand(_, m)
	dust(m.stage, m.stage.swarmNow)
end

function RUN.plaque(owner, m)
	local stage = m.stage
	ns.Animate(owner, {
		-- the plaque drops in at the crate's top, overshooting a little, and the odds line fades in along its foot
		{
			dur = ns.CRATE_TIMES.plaqueDur,
			ease = PLAQUE_EASE,
			keys = { { 0, { -14 * UI, 0 } }, { 1, { 0, 1 } } },
			apply = function(v)
				ns.SetCratePlaque(stage, v[1], math.min(1, v[2]))
			end,
		},
		{
			dur = ns.CRATE_TIMES.plaqueDur,
			ease = OUT,
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				ns.SetCrateOdds(stage, v[1])
			end,
		},
	})
end

function RUN.rattle(owner, m, beat)
	local stage = m.stage
	local n = beat.index or 1
	local tilt = ns.CRATE_TIMES.rattleTilt[n]
	ns.Animate(owner, {
		-- the crate tips and lifts, then back, each rattle harder
		{
			dur = ns.CRATE_TIMES.rattleDur,
			ease = ns.EASE.inOut,
			keys = {
				{ 0, { 0, 0 } },
				{ 1 / 3, { -tilt, -tilt * UI } },
				{ 2 / 3, { tilt * 0.7, -tilt * 0.5 * UI } },
				{ 1, { 0, 0 } },
			},
			apply = function(v)
				setGroup(stage, v[2], v[1], 1, 1)
			end,
		},
		-- and its seal glows warmer
		{
			dur = 0.3,
			ease = OUT,
			keys = {
				{ 0, { 0.25 + (n - 1) * 0.3, 0.8 } },
				{ 1, { 0.12 + (n - 1) * 0.25, 1 + (n - 1) * 0.2 } },
			},
			apply = function(v)
				setPart(stage, stage.crate.glow, 0, 0, 0, v[2], v[1])
			end,
		},
	})
end

function RUN.crack(owner, m)
	local stage = m.stage
	local crate = stage.crate
	ns.Animate(owner, {
		-- the seal's glow flares and goes
		{
			dur = 0.4,
			ease = OUT,
			keys = { { 0, { 1, 1.6 } }, { 1, { 0, 2.4 } } },
			apply = function(v)
				setPart(stage, crate.glow, 0, 0, 0, v[2], v[1])
			end,
		},
		-- its two halves spin away and fall
		along(0.9, SEAL_EASE, {
			{ 0, 0, 0, 0, 1 },
			{ 0.3, -34 * UI, -20 * UI, -30, 0.7 },
			{ 1, -80 * UI, 170 * UI, -120, 0 },
		}, function(v)
			setPart(stage, crate.sealLeft, v[1], v[2], v[3], 1, v[4])
		end),
		along(0.9, SEAL_EASE, {
			{ 0, 0, 0, 0, 1 },
			{ 0.3, 34 * UI, -24 * UI, 30, 0.7 },
			{ 1, 90 * UI, 170 * UI, 140, 0 },
		}, function(v)
			setPart(stage, crate.sealRight, v[1], v[2], v[3], 1, v[4])
		end),
		-- and the ribbons drop
		{
			dur = 0.7,
			ease = EASE_IN,
			keys = { { 0, { 0, 0, 1 } }, { 1, { 120 * UI, 14, 0 } } },
			apply = function(v)
				setPart(stage, crate.ribbon, 0, v[1], v[2], 1, v[3])
			end,
		},
	})
end

function RUN.lid(owner, m)
	local stage = m.stage
	local lid = stage.crate.lid
	ns.Animate(owner, {
		-- the lid flies up and away, turning 48 degrees, fading
		along(ns.CRATE_TIMES.lidDur, LID_EASE, {
			{ 0, 0, 0, 0, 1, 1 },
			{ 0.35, 40 * UI, -150 * UI, 14, 1.06, 0.65 },
			{ 1, 170 * UI, -460 * UI, 48, 1.15, 0 },
		}, function(v)
			setPart(stage, lid, v[1], v[2], v[3], v[4], v[5])
		end),
		-- light bursts from the open crate, a beam rises, the rays come in
		{
			dur = 0.9,
			ease = OUT,
			keys = { { 0, { 0, 0.3 } }, { 0.2, { 1, 1.1 } }, { 1, { 0.45, 1.4 } } },
			apply = function(v)
				setBurst(stage, v[1], v[2])
			end,
		},
		{
			dur = 0.9,
			ease = OUT,
			keys = { { 0, { 0, 0.2 } }, { 0.25, { 1, 1 } }, { 1, { 0.55, 1 } } },
			apply = function(v)
				setBeam(stage, v[1], v[2])
			end,
		},
		{
			dur = 0.6,
			ease = OUT,
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				ns.FadeCratePart(stage, stage.fans[1], v[1])
			end,
		},
		-- the crate gives a little as it opens
		{
			dur = 0.36,
			ease = OUT,
			keys = { { 0, { 0, 1, 1 } }, { 0.3, { 8 * UI, 1.03, 0.95 } }, { 1, { 0, 1, 1 } } },
			apply = function(v)
				setGroup(stage, v[1], 0, v[2], v[3])
			end,
		},
	})
	straw(stage, stage.swarmNow)
end

function RUN.reelOpen(owner, m)
	local stage = m.stage
	setPhase(stage, "reel")
	setTrack(stage, 0)
	setLight(stage, stage.reel.cards[ns.CRATE_REEL.first].colour)
	stage.reel.clip:Show()
	ns.Animate(owner, {
		-- the crate sinks away and fades
		{
			dur = 0.5,
			ease = EASE_IN,
			keys = { { 0, { 0, 1, 1 } }, { 1, { 90 * UI, 0, 0.82 } } },
			apply = function(v)
				setGroup(stage, v[1], 0, v[3], v[3])
				ns.SetCrateGroupAlpha(stage, v[2])
			end,
		},
		{
			dur = 0.5,
			ease = OUT,
			keys = { { 0, { 0.55 } }, { 1, { 0 } } },
			apply = function(v)
				setBeam(stage, v[1], 1)
			end,
		},
		{
			dur = 0.6,
			ease = OUT,
			keys = { { 0, { 0.45 } }, { 1, { 0 } } },
			apply = function(v)
				setBurst(stage, v[1], 1.4)
			end,
		},
		{
			dur = 0.8,
			ease = OUT,
			keys = { { 0, { 1 } }, { 1, { 0.35 } } },
			apply = function(v)
				ns.FadeCratePart(stage, stage.fans[1], v[1])
			end,
		},
		-- the reel opens sideways out of the light, overshooting a little
		along(ns.CRATE_TIMES.reelDur, REEL_EASE, {
			{ 0, 0, 0.4, 0 },
			{ 0.7, 1.03, 1, 1 },
			{ 1, 1, 1, 1 },
		}, function(v)
			setReel(stage, v[1], v[2], v[3], 0)
		end),
	})
end

function RUN.spin(owner, m)
	spin(owner, m.stage)
end

function RUN.cardLand(owner, m)
	local stage = m.stage
	setPhase(stage, "landed")
	local cards = stage.reel.cards
	local win = ns.CRATE_REEL.win
	ns.ShowCrateRing(stage, true)
	ns.Animate(owner, {
		-- the other cards dim, and the card rings in its colour
		{
			dur = ns.CRATE_TIMES.ring,
			ease = OUT,
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				for i, card in ipairs(cards) do
					if i ~= win then
						card:SetAlpha(1 - 0.78 * v[1])
					end
				end
				ns.SetCrateRing(stage, v[1])
			end,
		},
	})
end

-- The reveal's beats, from its start: each one's handler, on `owner`'s clock.
---@type table<string, fun(owner: Frame, m: PagleShopCrateMotion, beat: PagleCrateBeat)>
local REVEAL = {}

function REVEAL.lift(owner, m)
	local stage = m.stage
	local reveal = ns.CRATE_REVEAL
	setPhase(stage, "reveal")
	local shown = stage.plaque:GetAlpha()
	ns.Animate(owner, {
		-- the crate's rays fade out as the card's come, and the plaque and the odds put away
		{
			dur = 0.5,
			ease = OUT,
			keys = { { 0, { 0.35, shown } }, { 1, { 0, 0 } } },
			apply = function(v)
				ns.FadeCratePart(stage, stage.fans[1], v[1])
				ns.SetCratePlaque(stage, 0, v[2])
				ns.SetCrateOdds(stage, v[2])
			end,
		},
		-- the card lifts out of the reel to the middle, growing to 1.5x, overshooting a little
		along(reveal.lift, LIFT_EASE, {
			{ 0, layout.heroX - stage.offset, layout.cardY, 1 },
			{ 0.7, layout.heroX, layout.heroY - 14 * UI, 1.62 },
			{ 1, layout.heroX, layout.heroY, reveal.scale },
		}, function(v)
			ns.SetCrateHero(stage, v[1], v[2], v[3])
		end),
	})
	ns.ShowCrateHero(stage, true)
end

function REVEAL.reelDrop(owner, m)
	local stage = m.stage
	local reveal = ns.CRATE_REVEAL
	ns.Animate(owner, {
		-- the reel drops 48 units and fades
		{
			dur = reveal.reelDur,
			ease = EASE_IN,
			keys = { { 0, { 1, 0 } }, { 1, { 0, reveal.reelDrop } } },
			apply = function(v)
				setReel(stage, 1, 1, v[1], v[2])
				if v[1] <= 0 then
					stage.reel.clip:Hide()
				end
			end,
		},
	})
end

function REVEAL.rays(owner, m)
	local stage = m.stage
	local reveal = ns.CRATE_REVEAL
	ns.Animate(owner, {
		-- behind it two fans of rays in the tier's colour, and its halo, fade in
		{
			dur = reveal.raysDur,
			ease = OUT,
			keys = { { 0, { 0, 0.4 } }, { 1, { 1, 1 } } },
			apply = function(v)
				ns.SetCrateRays(stage, v[1] * m.reveal.raysAlpha, v[1], v[2])
			end,
		},
	})
end

function REVEAL.tremble(owner, m, beat)
	local stage = m.stage
	local n = m.reveal.tier
	local amp = (1 + (n - 1) * 0.4) * UI
	local steps = {}
	for i = 0, 9 do
		steps[#steps + 1] = { i / 9, { (i % 2 == 1 and 1 or -1) * amp, (i % 3 - 1) * UI } }
	end
	local dur = beat.dur or 0.4
	ns.Animate(owner, {
		-- it trembles, and its light swells, before it turns
		{
			dur = dur,
			ease = ns.EASE.linear,
			keys = steps,
			apply = function(v)
				ns.SetCrateTremble(stage, v[1], v[2])
			end,
		},
		{
			dur = dur,
			ease = OUT,
			keys = { { 0, { 0.6, 0.8 } }, { 1, { 1, 1.15 } } },
			apply = function(v)
				ns.SetCrateHalo(stage, v[1], v[2])
			end,
		},
	})
end

function REVEAL.turn(owner, m, beat)
	local stage = m.stage
	local total = m.reveal.halfTurns * 180
	ns.Animate(owner, {
		-- it squashes to nothing and swaps faces, half a turn, or more, to its result
		{
			dur = beat.dur,
			ease = TURN_EASE,
			keys = { { 0, { 0 } }, { 1, { total } } },
			apply = function(v)
				ns.TurnCrateHero(stage, v[1])
			end,
		},
	})
end

function REVEAL.face(owner, m)
	local stage = m.stage
	local reveal, params = ns.CRATE_REVEAL, m.reveal
	local c = stage.data.color
	-- the rays whip back round, slowing into their steady turn
	if params.whip then
		ns.Animate(owner, {
			along(params.whip.dur, WHIP_EASE, { { 0, -params.whip.degrees }, { 1, 0 } }, function(v)
				stage.whip = v[1]
				turnFans(stage)
			end),
		})
	end
	if params.sparks then
		sparks(stage, params.sparks.count, params.sparks.spread, c)
	end
	if params.embers then
		stage.embers = { nextAt = stage.swarmNow, endAt = stage.swarmNow + params.embers }
	end
	if params.shake then
		local shake = params.shake --[[@as { amplitude: number, dur: number }]]
		local steps = {}
		for i = 0, 9 do
			local fade = 1 - i / 10
			steps[#steps + 1] = {
				i / 10,
				{ (random() - 0.5) * 2 * shake.amplitude * fade, (random() - 0.5) * 2 * shake.amplitude * fade },
			}
		end
		steps[#steps + 1] = { 1, { 0, 0 } }
		ns.Animate(owner, {
			{
				dur = shake.dur,
				ease = ns.EASE.linear,
				keys = steps,
				apply = function(v)
					setShake(stage, v[1], v[2])
				end,
			},
		})
	end
	if params.flash then
		local top = params.flash
		ns.Animate(owner, {
			{
				dur = 0.5,
				ease = OUT,
				keys = { { 0, { top } }, { 1, { 0 } } },
				apply = function(v)
					stage.flash:SetAlpha(v[1])
				end,
			},
		})
	end
	if params.coins then
		if params.payback then
			coins(stage, params.coins, 240 * UI, reveal.showerDur - 0.2, 0.2)
		else
			coins(stage, params.coins, 700 * UI, 1.5, 0.7)
		end
	end
	if params.payback and m.count then
		ns.ShopPayOut(owner, m.count)
	end
end

-- Fades a piece of the reveal's words in over 0.45 s, rising into its place.
---@param owner Frame
---@param piece fun(a: number, dy: number)
---@param rise number
local function comeIn(owner, piece, rise)
	ns.Animate(owner, {
		{
			dur = ns.CRATE_REVEAL.inDur,
			ease = OUT,
			keys = { { 0, { 0, rise } }, { 1, { 1, 0 } } },
			apply = function(v)
				piece(v[1], v[2])
			end,
		},
	})
end

function REVEAL.tier(owner, m)
	local stage = m.stage
	comeIn(owner, function(a)
		ns.SetCrateTier(stage, a)
	end, 0)
end

function REVEAL.name(owner, m)
	local stage = m.stage
	comeIn(owner, function(a, dy)
		ns.SetCrateName(stage, a, dy)
	end, 10 * UI)
end

function REVEAL.kind(owner, m)
	local stage = m.stage
	comeIn(owner, function(a, dy)
		ns.SetCrateKind(stage, a, dy)
	end, 10 * UI)
end

function REVEAL.stamp(owner, m)
	local stage = m.stage
	local reveal = ns.CRATE_REVEAL
	ns.Animate(owner, {
		-- the stamp lands on the card from 2.6x
		along(reveal.stampDur, STAMP_EASE, {
			{ 0, reveal.stampFrom, 0 },
			{ 0.7, 0.92, 1 },
			{ 1, 1, 0.92 },
		}, function(v)
			ns.SetCrateStamp(stage, v[1], v[2])
		end),
	})
end

function REVEAL.buttons(owner, m)
	local stage = m.stage
	ns.ShowCrateButtons(stage, true)
	ns.Animate(owner, {
		{
			dur = ns.CRATE_REVEAL.buttonsDur,
			ease = OUT,
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				ns.SetCrateButtons(stage, v[1])
			end,
		},
	})
end

-- Each beat of `beats`, `offset` seconds taken off, as a step of ns.ShopTimeline: its sound, then its handler.
---@param owner Frame
---@param m PagleShopCrateMotion
---@param beats PagleCrateBeat[]
---@param handlers table<string, fun(owner: Frame, m: PagleShopCrateMotion, beat: PagleCrateBeat)>
---@param offset number
---@return { [1]: number, [2]: fun() }[]
local function steps(owner, m, beats, handlers, offset)
	local list = {}
	for _, beat in ipairs(beats) do
		list[#list + 1] = {
			beat.t + offset,
			function()
				if beat.sound then
					sound(beat.sound, beat.index)
				end
				local handler = handlers[beat.beat]
				if handler then
					handler(owner, m, beat)
				end
			end,
		}
	end
	return list
end

--- Plays a Curio crate's opening on `owner` (the case), every beat on its clock (SHOP-R55), the stage prepared
--- (ns.PrepareCrateStage) and the crate already bought: the crate and the reel to the line's landing (ns.CrateRunBeats),
--- then the reveal (ns.CrateRevealBeats, from 10.35 s). `m.onDone` runs once it has all played. Only with motion on.
---@param owner Frame
---@param m PagleShopCrateMotion
function ns.PlayShopCrate(owner, m)
	local stage = m.stage
	ns.StopMotion(owner)
	ns.ResetCrateStage(stage)
	setPhase(stage, "crate")
	local list = steps(owner, m, ns.CrateRunBeats(), RUN, 0)
	for _, step in ipairs(steps(owner, m, ns.CrateRevealBeats(m.reveal), REVEAL, ns.CRATE_TIMES.reveal)) do
		list[#list + 1] = step
	end
	ns.ShopTimeline(owner, list, m.onDone)
end

-- What the purse shows as the crate's price is paid, whether or not the count has run.
---@param m PagleShopCrateMotion
local function paidOut(m)
	local pay = m.pay
	pay.balance(pay.balanceTo)
	pay.coin:SetWidth(pay.coin.w0 or pay.coin:GetWidth())
end

--- A click anywhere, or Esc, during the crate or the reel (Motion row): straight to the reveal. What was playing stops
--- where it is and what only it showed goes; the card lifts out of the reel where it stopped, and the reveal plays on.
---@param owner Frame
---@param m PagleShopCrateMotion
function ns.SkipShopCrate(owner, m)
	local stage = m.stage
	if stage.phase == "reveal" then
		return
	end
	ns.StopMotion(owner)
	ns.StopMotion(stage.root)
	paidOut(m)
	ns.LandCrateStage(stage)
	setPhase(stage, "reveal")
	startLoops(stage)
	ns.ShopTimeline(owner, steps(owner, m, ns.CrateRevealBeats(m.reveal), REVEAL, 0), m.onDone)
end

--- Settles the opening at once, from wherever it is (anything that redraws the window meanwhile, or its closing; or
--- with the Animations setting off, where nothing plays): the reveal as it ends, with its card turned to the result, its
--- words, stamp and buttons, and the purse at its balance.
---@param owner Frame
---@param m PagleShopCrateMotion
function ns.SettleShopCrate(owner, m)
	local stage = m.stage
	ns.StopMotion(owner)
	ns.StopMotion(stage.root)
	paidOut(m)
	ns.ResetCrateStage(stage)
	ns.LandCrateStage(stage)
	ns.RevealCrateStage(stage, m.reveal)
	setPhase(stage, "reveal")
	m.settlePurse()
	startLoops(stage)
end

--- Puts the stage as it is at the start of an opening: shown, the dark not yet in, the crate whole above the case and
--- unseen, the light, plaque, odds, reel and reveal not yet in, no particle in the air.
---@param stage PagleCrateStage
function ns.ResetCrateStage(stage)
	stage.root:Show()
	setShake(stage, 0, 0)
	setDim(stage, 0)
	setPhase(stage, "crate")
	stage.whip, stage.embers = 0, nil
	stage.rayTurn[1], stage.rayTurn[2], stage.rayTurn[3] = 0, 0, 0
	stage.tremble[1], stage.tremble[2] = 0, 0
	for _, part in ipairs(stage.parts) do
		local own = part.own
		own[1], own[2], own[3], own[4], own[5] = 0, 0, 0, 1, 1
		part.fade = 1
	end
	stage.crate.glow.fade = 0
	setGroup(stage, 0, 0, 1, 1)
	ns.SetCrateGroupAlpha(stage, 0)
	for _, fan in ipairs(stage.fans) do
		fan.fade = 0
		ns.FadeCratePart(stage, fan, 0)
	end
	turnFans(stage)
	setBurst(stage, 0, 1)
	setBeam(stage, 0, 1)
	ns.SetCratePlaque(stage, -14 * UI, 0)
	ns.SetCrateOdds(stage, 0)
	local reel = stage.reel
	reel.clip:Hide()
	setReel(stage, 1, 1, 1, 0)
	setTrack(stage, 0)
	for _, card in ipairs(reel.cards) do
		card:SetAlpha(1)
		card.glow.tex:Hide()
	end
	reel.cards[ns.CRATE_REEL.win].ringing = nil
	setBobber(stage, 1)
	-- the reveal
	ns.ShowCrateHero(stage, false)
	ns.SetCrateHero(stage, layout.heroX, layout.heroY, ns.CRATE_REVEAL.scale)
	ns.TurnCrateHero(stage, 0)
	ns.SetCrateRays(stage, 0, 0, 1)
	ns.SetCrateTier(stage, 0)
	ns.SetCrateName(stage, 0, 0)
	ns.SetCrateKind(stage, 0, 0)
	ns.SetCrateStamp(stage, 1, 0)
	ns.ShowCrateButtons(stage, false)
	ns.SetCrateButtons(stage, 1)
	stage.flash:SetAlpha(0)
	for _, swarm in pairs(stage.swarms) do
		ns.ClearCrateSwarm(swarm)
	end
end

--- Puts the stage as it is when the line has landed, whatever came before: the dark in, the crate and its light gone,
--- the reel open with the line at its stop, the other cards dimmed and the one it stopped on ringing, no particle in
--- the air. The reveal begins from it.
---@param stage PagleCrateStage
function ns.LandCrateStage(stage)
	setDim(stage, 1)
	ns.SetCrateGroupAlpha(stage, 0)
	setBurst(stage, 0, 1)
	setBeam(stage, 0, 1)
	ns.FadeCratePart(stage, stage.fans[1], 0.35)
	ns.SetCratePlaque(stage, 0, 0)
	ns.SetCrateOdds(stage, 0)
	local reel = stage.reel
	reel.clip:Show()
	setReel(stage, 1, 1, 1, 0)
	setTrack(stage, 1)
	setLight(stage, reel.cards[ns.CRATE_REEL.win].colour)
	setBobber(stage, 1)
	ns.ShowCrateRing(stage, true)
	ns.SetCrateRing(stage, 1)
	for i, card in ipairs(reel.cards) do
		if i ~= ns.CRATE_REEL.win then
			card:SetAlpha(0.22)
		end
	end
	stage.embers = nil
	for _, swarm in pairs(stage.swarms) do
		ns.ClearCrateSwarm(swarm)
	end
	setShake(stage, 0, 0)
	stage.flash:SetAlpha(0)
	ns.ShowCrateHero(stage, false)
	ns.SetCrateHero(stage, layout.heroX - stage.offset, layout.cardY, 1)
	ns.TurnCrateHero(stage, 0)
end

--- Puts the stage as the reveal ends, on top of ns.LandCrateStage: the reel gone, the card at the middle at 1.5x turned
--- to its result, the rays and halo in the tier's colour, the words, the stamp and the buttons in.
---@param stage PagleCrateStage
---@param params PagleCrateReveal
function ns.RevealCrateStage(stage, params)
	stage.reel.clip:Hide()
	ns.FadeCratePart(stage, stage.fans[1], 0)
	stage.whip = 0
	turnFans(stage)
	ns.SetCrateHero(stage, layout.heroX, layout.heroY, ns.CRATE_REVEAL.scale)
	ns.TurnCrateHero(stage, params.halfTurns * 180)
	ns.ShowCrateHero(stage, true)
	ns.SetCrateRays(stage, params.raysAlpha, 1, 1)
	ns.SetCrateTier(stage, 1)
	ns.SetCrateName(stage, 1, 0)
	ns.SetCrateKind(stage, 1, 0)
	ns.SetCrateStamp(stage, 1, 0.92)
	ns.ShowCrateButtons(stage, true)
	ns.SetCrateButtons(stage, 1)
end

--- Closes the opening: nothing of it shows or moves.
---@param stage PagleCrateStage
function ns.CloseCrateStage(stage)
	ns.StopMotion(stage.root)
	stage.embers = nil
	for _, swarm in pairs(stage.swarms) do
		ns.ClearCrateSwarm(swarm)
	end
	stage.root:Hide()
end
