---@class PagleNS
local ns = select(2, ...)

-- The announcements art kit's motion as data and maths (announcements.md › Motion): the canvases' CSS keyframes, each
-- eased per segment with the canvas's cubic-bezier, which AnimationGroup's smoothing can't do (no overshoot, no steps,
-- no easing per segment). Copied from the kit's Motion.lua; adapter/Motion.lua drives them from one OnUpdate.
--
-- An animation is { dur, keys, apply, ease?, delay?, iter?, dir? }: keys are { progress 0..1, { values } } as the
-- CSS percentages, and a key's `ease` applies to the segment after it, as in CSS; `iter` is a count or "infinite",
-- `dir` "normal", "alternate" or "alternate-reverse", `delay` in seconds. `apply(values)` sets the property, and
-- `done`, if given, runs once when it finishes.

---@alias PagleEase fun(t: number): number

---@class PagleAnimation
---@field dur number seconds per iteration
---@field keys { [1]: number, [2]: number[], ease: PagleEase? }[]
---@field apply fun(values: number[])
---@field ease PagleEase? every segment's easing unless its key has its own (default `ns.EASE.ease`)
---@field delay number?
---@field iter integer|"infinite"|nil default 1
---@field dir "normal"|"alternate"|"alternate-reverse"|nil
---@field startedAt number? when it joined its owner's clock, if it joined late
---@field done fun()? runs once when it finishes
---@field fired boolean? its `done` has run

--- cubic-bezier(x1, y1, x2, y2), as CSS: the easing that solves x(s) = t and returns y(s).
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@return PagleEase
function ns.Bezier(x1, y1, x2, y2)
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
		local lo, hi = 0, 1
		for _ = 1, 22 do
			local s = (lo + hi) / 2
			if at(x1, x2, s) < t then
				lo = s
			else
				hi = s
			end
		end
		return at(y1, y2, (lo + hi) / 2)
	end
end

--- CSS's named easings.
---@type table<string, PagleEase>
ns.EASE = {
	linear = function(t)
		return t
	end,
	ease = ns.Bezier(0.25, 0.1, 0.25, 1),
	out = ns.Bezier(0, 0, 0.58, 1),
	inOut = ns.Bezier(0.42, 0, 0.58, 1),
}

--- CSS's steps(n): `n` jumps, the last at the end.
---@param n integer
---@return PagleEase
function ns.Steps(n)
	return function(t)
		return t >= 1 and 1 or math.floor(t * n) / n
	end
end

--- An animation's values `t` seconds after it started, and whether it has finished (never, for "infinite").
---@param animation PagleAnimation
---@param t number
---@return number[] values
---@return boolean finished
function ns.MotionSample(animation, t)
	t = math.max(0, t - (animation.delay or 0))
	local dur, iter = animation.dur, animation.iter or 1
	local finished = iter ~= "infinite" and t >= dur * iter
	local n, p
	if finished then
		n, p = iter - 1, 1
	else
		n = math.floor(t / dur)
		p = (t - n * dur) / dur
	end
	if (animation.dir == "alternate" and n % 2 == 1) or (animation.dir == "alternate-reverse" and n % 2 == 0) then
		p = 1 - p
	end
	local keys = animation.keys
	local i = 1
	while i < #keys and keys[i + 1][1] < p do
		i = i + 1
	end
	local from, to = keys[i], keys[math.min(i + 1, #keys)]
	local span = to[1] - from[1]
	local u = span > 0 and math.max(0, math.min(1, (p - from[1]) / span)) or 1
	u = (from.ease or animation.ease or ns.EASE.ease)(u)
	local values = {}
	for j = 1, #from[2] do
		values[j] = from[2][j] + (to[2][j] - from[2][j]) * u
	end
	return values, finished
end

--- An animation's settled values: its last key's, or its first's for one that never ends (it would loop).
---@param animation PagleAnimation
---@return number[]
function ns.MotionSettled(animation)
	local keys = animation.keys
	return animation.iter == "infinite" and keys[1][2] or keys[#keys][2]
end
