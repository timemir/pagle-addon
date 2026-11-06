---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Pagle's one motion driver on the client (announcements.md › Motion, › Contracts): one OnUpdate steps every animation
-- playing, Core's and each Module's (logic/Motion.lua's player), set as the first starts and cleared once none plays,
-- so nothing ticks at rest. It reads the Animations setting itself: off, an animation jumps to where it settles.

--- Whether things move: the Animations setting (SET-R30), on by default.
---@return boolean
function ns.MotionOn()
	return ns.db.profile.announcements.motion ~= false
end

local driver = CreateFrame("Frame")
driver:Hide()

---@type PagleMotionPlayer
local player

local function step(_, elapsed)
	player:Step(elapsed)
end

player = ns.NewMotionPlayer({
	isOn = ns.MotionOn,
	wake = function()
		driver:SetScript("OnUpdate", step)
		driver:Show()
	end,
	sleep = function()
		driver:Hide()
		driver:SetScript("OnUpdate", nil)
	end,
})

--- Plays `animations` on `owner` (logic/Motion.lua's PagleMotionPlayer:Animate).
---@param owner PagleMotionOwner
---@param animations PagleAnimation[]
---@param onDone fun()?
function ns.Animate(owner, animations, onDone)
	player:Animate(owner, animations, onDone)
end

--- Stops what `owner` plays, where it is.
---@param owner PagleMotionOwner
function ns.StopMotion(owner)
	player:Stop(owner)
end

--- Runs `fn` `seconds` from now on `owner`'s clock (a sound on a beat); with motion off, never.
---@param owner PagleMotionOwner
---@param seconds number
---@param fn fun()
function ns.Cue(owner, seconds, fn)
	player:Cue(owner, seconds, fn)
end

--- Scrolls `scroll` by `delta` mouse wheel notches, a third of its view each, gliding there (logic/Motion.lua's
--- PagleMotionPlayer:Wheel).
---@param scroll ScrollFrame
---@param delta number
---@param options PagleWheelOptions?
function ns.WheelScroll(scroll, delta, options)
	player:Wheel(scroll, delta, options)
end

-- A text too long for its room scrolls to and fro inside a clip (ANN-R101): it glides at MARQUEE_SPEED units a
-- second, steady enough to read, and holds MARQUEE_HOLD seconds at each end.
ns.MARQUEE_SPEED, ns.MARQUEE_HOLD = 40, 1

--- The animation that scrolls a text `distance` units longer than its clip shows (ANN-R101): after `delay` it holds at
--- its start, glides along until its end shows, holds there, glides back, and again, for as long as its owner plays it.
--- `apply(offset)` places the text `offset` units along. Played with ns.Animate, it stops with its owner (ns.StopMotion,
--- or hidden), and with Animations off rests at its start.
---@param distance number
---@param apply fun(offset: number)
---@param delay number?
---@return PagleAnimation
function ns.MarqueeAnimation(distance, apply, delay)
	local glide = distance / ns.MARQUEE_SPEED
	local period = 2 * (ns.MARQUEE_HOLD + glide)
	local hold = ns.MARQUEE_HOLD / period
	return {
		dur = period,
		delay = delay,
		iter = "infinite",
		ease = ns.EASE.linear,
		keys = { { 0, { 0 } }, { hold, { 0 } }, { 0.5, { distance } }, { 0.5 + hold, { distance } }, { 1, { 0 } } },
		apply = function(v)
			apply(v[1])
		end,
	}
end

-- What a Module moves its own frames with (announcements.md › Contracts).

--- The Animations setting: true unless the player turned it off.
---@return boolean
function Pagle.IsAnimationsOn()
	return ns.MotionOn()
end

Pagle.Animate = ns.Animate
Pagle.StopMotion = ns.StopMotion
Pagle.Cue = ns.Cue
Pagle.WheelScroll = ns.WheelScroll
Pagle.Bezier = ns.Bezier
Pagle.EASE = ns.EASE
