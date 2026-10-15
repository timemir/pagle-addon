---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The announcements' motion on the client (announcements.md › Motion): one OnUpdate runs every animation playing
-- (logic/Motion.lua's), and hides itself when none is. Copied from the art kit's Motion.lua. With the Animations
-- setting off, an animation jumps to where it settles.

---@class PagleMotionSet
---@field t number seconds since its owner's first animation started
---@field animations PagleAnimation[]
---@field onDone fun()?

-- What each owner frame has playing.
---@type table<Frame, PagleMotionSet>
local running = {}

local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(self, elapsed)
	-- A callback may start or stop animations, so this walks the owners as they were.
	local owners = {}
	for owner in pairs(running) do
		owners[#owners + 1] = owner
	end
	for _, owner in ipairs(owners) do
		local set = running[owner]
		if set then
			set.t = set.t + elapsed
			local done = true
			for _, animation in ipairs(set.animations) do
				local values, finished = ns.MotionSample(animation, set.t - (animation.startedAt or 0))
				animation.apply(values)
				if finished and animation.done and not animation.fired then
					animation.fired = true
					animation.done()
				end
				done = done and finished
			end
			-- An owner off screen stops where it is: its next showing starts it again.
			if running[owner] == set and (done or not owner:IsVisible()) then
				running[owner] = nil
				if done and set.onDone then
					set.onDone()
				end
			end
		end
	end
	if next(running) == nil then
		self:Hide()
	end
end)

--- Whether the announcements move: the Animations setting (SET-R30), on by default.
---@return boolean
function ns.MotionOn()
	return ns.db.profile.announcements.motion ~= false
end

--- The Animations setting, for a Module that moves its own frames (announcements.md › Contracts): true unless the
--- player turned it off.
---@return boolean
function Pagle.IsAnimationsOn()
	return ns.MotionOn()
end

--- Plays `animations` on `owner`, each at its first frame at once so nothing shows its settled state first; with
--- motion off, each jumps to its settled state. `onDone` runs when all have finished (at once with motion off). An
--- owner already playing keeps what it plays and starts these beside it.
---@param owner Frame
---@param animations PagleAnimation[]
---@param onDone fun()?
function ns.Animate(owner, animations, onDone)
	if not ns.MotionOn() then
		for _, animation in ipairs(animations) do
			animation.apply(ns.MotionSettled(animation))
		end
		if onDone then
			onDone()
		end
		return
	end
	local set = running[owner]
	if set then
		for _, animation in ipairs(animations) do
			animation.startedAt = set.t
			set.animations[#set.animations + 1] = animation
		end
	else
		running[owner] = { t = 0, animations = animations, onDone = onDone }
	end
	for _, animation in ipairs(animations) do
		animation.apply((ns.MotionSample(animation, 0)))
	end
	driver:Show()
end

--- Stops what `owner` plays, where it is; the driver too when nothing else plays.
---@param owner Frame
function ns.StopMotion(owner)
	-- One not playing changes nothing: the driver may be walking what plays.
	if running[owner] == nil then
		return
	end
	running[owner] = nil
	if next(running) == nil then
		driver:Hide()
	end
end

-- An animation's apply that sets nothing: a cue only waits.
local function still() end

--- Runs `fn` `seconds` from now on `owner`'s clock (a sound on a beat), unless its motion is stopped first; with
--- motion off, never.
---@param owner Frame
---@param seconds number
---@param fn fun()
function ns.Cue(owner, seconds, fn)
	if not ns.MotionOn() then
		return
	end
	ns.Animate(owner, {
		{
			dur = math.max(0.001, seconds),
			ease = ns.EASE.linear,
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = still,
			done = fn,
		},
	})
end
