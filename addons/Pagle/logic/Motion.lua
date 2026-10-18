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

-- An owner is a frame or region (with IsVisible), or any table a caller keys its motion by, which never counts as
-- hidden.
---@class PagleMotionOwner
---@field IsVisible (fun(self): boolean)?

--- What a motion player needs from its client: the Animations setting, and its ticks asked for (`wake`, at the first
--- animation) and given up (`sleep`, once nothing plays).
---@class PagleMotionHost
---@field isOn fun(): boolean
---@field wake fun()
---@field sleep fun()

---@class PagleMotionSet
---@field t number seconds since its owner's first animation started
---@field animations PagleAnimation[]
---@field onDone fun()?

--- Every animation playing, by owner, stepped a frame at a time (adapter/Motion.lua's one OnUpdate).
---@class PagleMotionPlayer
---@field host PagleMotionHost
---@field running table<PagleMotionOwner, PagleMotionSet>
local MotionPlayer = {}
MotionPlayer.__index = MotionPlayer

---@param host PagleMotionHost
---@return PagleMotionPlayer
function ns.NewMotionPlayer(host)
	return setmetatable({ host = host, running = {} }, MotionPlayer)
end

--- Plays `animations` on `owner`, each at its first frame at once so nothing shows its settled state first; with
--- motion off, each jumps to its settled state. `onDone` runs when all have finished (at once with motion off). An
--- owner already playing keeps what it plays and starts these beside it.
---@param owner PagleMotionOwner
---@param animations PagleAnimation[]
---@param onDone fun()?
function MotionPlayer:Animate(owner, animations, onDone)
	if not self.host.isOn() then
		for _, animation in ipairs(animations) do
			animation.apply(ns.MotionSettled(animation))
		end
		if onDone then
			onDone()
		end
		return
	end
	local set = self.running[owner]
	if set then
		for _, animation in ipairs(animations) do
			animation.startedAt = set.t
			set.animations[#set.animations + 1] = animation
		end
	else
		self.running[owner] = { t = 0, animations = animations, onDone = onDone }
	end
	for _, animation in ipairs(animations) do
		animation.apply((ns.MotionSample(animation, 0)))
	end
	self.host.wake()
end

-- Gives up the ticks once nothing plays.
---@param player PagleMotionPlayer
local function rest(player)
	if next(player.running) == nil then
		player.host.sleep()
	end
end

--- Stops what `owner` plays, where it is.
---@param owner PagleMotionOwner
function MotionPlayer:Stop(owner)
	-- One not playing changes nothing: Step may be walking what plays.
	if self.running[owner] == nil then
		return
	end
	self.running[owner] = nil
	rest(self)
end

-- An animation's apply that sets nothing: a cue only waits.
local function still() end

--- Runs `fn` `seconds` from now on `owner`'s clock (a sound on a beat), unless its motion is stopped first; with
--- motion off, never.
---@param owner PagleMotionOwner
---@param seconds number
---@param fn fun()
function MotionPlayer:Cue(owner, seconds, fn)
	if not self.host.isOn() then
		return
	end
	self:Animate(owner, {
		{
			dur = math.max(0.001, seconds),
			ease = ns.EASE.linear,
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = still,
			done = fn,
		},
	})
end

-- Runs an animation's `done` once.
---@param animation PagleAnimation
local function fire(animation)
	if animation.done and not animation.fired then
		animation.fired = true
		animation.done()
	end
end

--- One frame, `elapsed` seconds after the last: every owner's animations move on, and an owner that has finished
--- leaves, with its onDone. An owner no longer visible (closed, or the UI hidden) settles there instead: each of its
--- animations jumps to where it settles (a loop to its rest), each cue still to come runs, and then its onDone, so what
--- its end does (hiding a card, closing a note) is never lost. Its next showing starts anything it loops again.
---@param elapsed number
function MotionPlayer:Step(elapsed)
	-- A callback may start or stop animations, so this walks the owners as they were.
	local owners = {}
	for owner in pairs(self.running) do
		owners[#owners + 1] = owner
	end
	for _, owner in ipairs(owners) do
		local set = self.running[owner]
		if set then
			set.t = set.t + elapsed
			local hidden = owner.IsVisible ~= nil and not owner:IsVisible()
			local done = true
			for _, animation in ipairs(set.animations) do
				if hidden then
					animation.apply(ns.MotionSettled(animation))
					fire(animation)
				else
					local values, finished = ns.MotionSample(animation, set.t - (animation.startedAt or 0))
					animation.apply(values)
					if finished then
						fire(animation)
					end
					done = done and finished
				end
			end
			if self.running[owner] == set and (done or hidden) then
				self.running[owner] = nil
				if set.onDone then
					set.onDone()
				end
			end
		end
	end
	rest(self)
end
