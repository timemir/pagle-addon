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
---@param owner Frame
---@param animations PagleAnimation[]
---@param onDone fun()?
function ns.Animate(owner, animations, onDone)
	player:Animate(owner, animations, onDone)
end

--- Stops what `owner` plays, where it is.
---@param owner Frame
function ns.StopMotion(owner)
	player:Stop(owner)
end

--- Runs `fn` `seconds` from now on `owner`'s clock (a sound on a beat); with motion off, never.
---@param owner Frame
---@param seconds number
---@param fn fun()
function ns.Cue(owner, seconds, fn)
	player:Cue(owner, seconds, fn)
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
Pagle.Bezier = ns.Bezier
Pagle.EASE = ns.EASE
