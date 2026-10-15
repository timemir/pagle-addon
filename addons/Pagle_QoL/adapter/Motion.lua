if not Pagle then
	return
end

-- Motion.lua (shared by the Pagle art probes)
-- The canvases' CSS keyframes, played in game. One OnUpdate drives every running animation; each animation is
-- a list of keyframes over a duration, eased per segment with the canvas's cubic-bezier (AnimationGroup's
-- smoothing can't overshoot, step, or ease each segment), and applied through a setter, so it works on any
-- property: alpha, size, rotation, texture coordinates, an anchor offset.
--
--   P.Animate(owner, {
--     { dur = 0.6, ease = P.Ease.out, keys = { { 0, { 0 } }, { 1, { 1 } } }, apply = function(v) f:SetAlpha(v[1]) end },
--     { dur = 1.4, ease = ..., iter = "infinite", dir = "alternate", keys = ..., apply = ... },
--   }, onDone)
--
-- keys: { progress 0..1, { values } }, as the CSS percentages; a key's ease applies to the segment after it.
-- iter: a count or "infinite"; dir: "normal", "alternate" or "alternate-reverse"; delay in seconds;
-- done: called once when that animation finishes.
-- The first frame is applied at once, so nothing flashes in its final state. P.motion = false jumps to the end.
--
-- The field art kit's Motion.lua (PagleArtField, v2), copied as it is but for the Core guard above, P's annotation and
-- one change: the driver holds its OnUpdate only while something animates, set as it shows and cleared as it hides,
-- so QoL runs no tick while nothing moves (QOL-R25). A Module can't reach Core's adapter/Motion.lua (ADR 0001), so QoL
-- keeps its own copy of the driver, as the Tackle Board does. QoL sets P.motion from Core's Animations setting,
-- Pagle.IsAnimationsOn(), before it starts anything (adapter/Conflict.lua).

---@class PagleQoLNS
local P = select(2, ...)
P.motion = true

-- cubic-bezier(x1, y1, x2, y2), as CSS: solve x(s) = t, return y(s)
local function bezier(x1, y1, x2, y2)
	local function at(a, b, s)
		local u = 1 - s
		return 3 * u * u * s * a + 3 * u * s * s * b + s * s * s
	end
	return function(t)
		if t <= 0 then
			return 0
		elseif t >= 1 then
			return 1
		end
		local lo, hi, s = 0, 1, t -- luacheck: ignore 311
		for _ = 1, 22 do
			s = (lo + hi) / 2
			if at(x1, x2, s) < t then
				lo = s
			else
				hi = s
			end
		end
		return at(y1, y2, (lo + hi) / 2)
	end
end
P.Bezier = bezier
P.Ease = {
	linear = function(t)
		return t
	end,
	ease = bezier(0.25, 0.1, 0.25, 1),
	out = bezier(0, 0, 0.58, 1), -- ease-out
	inOut = bezier(0.42, 0, 0.58, 1), -- ease-in-out
}
function P.Steps(n)
	return function(t)
		return t >= 1 and 1 or math.floor(t * n) / n
	end
end

-- the value of one animation at time t (seconds since it started)
local function sample(a, t)
	t = t - (a.delay or 0)
	if t < 0 then
		t = 0
	end
	local d, iter = a.dur, a.iter or 1
	local n, p
	if iter ~= "infinite" and t >= d * iter then
		n, p = iter - 1, 1
	else
		n = math.floor(t / d)
		p = (t - n * d) / d
	end
	if a.dir == "alternate" and n % 2 == 1 then
		p = 1 - p
	elseif a.dir == "alternate-reverse" and n % 2 == 0 then
		p = 1 - p
	end
	local keys = a.keys
	local i = 1
	while i < #keys and keys[i + 1][1] < p do
		i = i + 1
	end
	local k0, k1 = keys[i], keys[math.min(i + 1, #keys)]
	local span = k1[1] - k0[1]
	local u = span > 0 and math.max(0, math.min(1, (p - k0[1]) / span)) or 1
	u = (k0.ease or a.ease or P.Ease.ease)(u)
	local v = {}
	for j = 1, #k0[2] do
		v[j] = k0[2][j] + (k1[2][j] - k0[2][j]) * u
	end
	return v, (iter ~= "infinite" and t >= d * iter)
end

local running = {}
local driver = CreateFrame("Frame")
driver:Hide()

-- the driver stops: hidden, with no OnUpdate
local function idle()
	driver:Hide()
	driver:SetScript("OnUpdate", nil)
end

local function step(_, elapsed)
	-- callbacks may start or stop animations, so walk a snapshot of the owners
	local owners = {}
	for owner in pairs(running) do
		owners[#owners + 1] = owner
	end
	for _, owner in ipairs(owners) do
		local set = running[owner]
		if set then
			set.t = set.t + elapsed
			local done = true
			for _, a in ipairs(set.anims) do
				local v, fin = sample(a, set.t - (a._t0 or 0))
				a.apply(v)
				if fin and a.done and not a._fired then
					a._fired = true
					a.done()
				end
				if not fin then
					done = false
				end
			end
			if running[owner] == set and (done or (owner.IsVisible and not owner:IsVisible())) then
				running[owner] = nil
				if done and set.onDone then
					set.onDone()
				end
			end
		end
	end
	if not next(running) then
		idle()
	end
end

function P.Animate(owner, anims, onDone)
	if not P.motion then
		for _, a in ipairs(anims) do
			local last = a.keys[#a.keys][2]
			if a.iter == "infinite" then
				a.apply(a.keys[1][2])
			else
				a.apply(last)
			end
		end
		if onDone then
			onDone()
		end
		return
	end
	local set = running[owner]
	if set then
		for _, a in ipairs(anims) do
			a._t0 = set.t
			set.anims[#set.anims + 1] = a
		end
	else
		set = { t = 0, anims = anims, onDone = onDone }
		running[owner] = set
	end
	for _, a in ipairs(anims) do
		a.apply((sample(a, 0)))
	end
	driver:SetScript("OnUpdate", step)
	driver:Show()
end

function P.StopMotion(owner)
	running[owner] = nil
	if not next(running) then
		idle()
	end
end

-- call fn after t seconds (a sound on a beat, the next step of a sequence); skipped when motion is off
local function noop() end
function P.Cue(owner, t, fn)
	if not P.motion then
		return
	end
	P.Animate(owner, {
		{
			dur = math.max(0.001, t),
			ease = P.Ease.linear,
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = noop,
			done = fn,
		},
	})
end
