-- Core's motion driver as Modules use it (announcements.md › Contracts): Pagle.Animate, Pagle.Cue and Pagle.StopMotion
-- on the client's one OnUpdate, which reads the Animations setting itself and runs no tick at rest (QOL-R25). An owner
-- hidden while it moves settles where its motion ends (logic/Motion_spec.lua has the player's rules).

-- Core logged in on Forever.
local function loadCore()
	local loaded = loadAddon("Pagle", foreverWith({ PagleLog = savedLog() }))
	loaded.client.fire("PLAYER_LOGIN")
	loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)
	loaded.client.runTimers()
	return loaded
end

-- The frames with an OnUpdate now.
local function ticking(loaded)
	local frames = {}
	for _, frame in ipairs(loaded.client.frames) do
		if frame.scripts.OnUpdate then
			frames[#frames + 1] = frame
		end
	end
	return frames
end

-- A 1 s fade of `frame`'s alpha from 0 to 1.
local function fadeIn(loaded, frame)
	return {
		dur = 1,
		ease = loaded.env.Pagle.EASE.linear,
		keys = { { 0, { 0 } }, { 1, { 1 } } },
		apply = function(v)
			frame:SetAlpha(v[1])
		end,
	}
end

describe("Pagle.Animate", function()
	it("moves a Module's frame on Core's OnUpdate, runs onDone at its end, and ticks no more at rest", function()
		local loaded = loadCore()
		local Pagle = loaded.env.Pagle
		local frame = loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent)
		local atRest = #ticking(loaded)
		local done = false

		Pagle.Animate(frame, { fadeIn(loaded, frame) }, function()
			done = true
		end)
		local first, playing = frame.alpha, #ticking(loaded)
		loaded.client.update(0.5)
		local half = frame.alpha
		loaded.client.update(0.6)

		assert.are.same({ 0, atRest + 1, 0.5 }, { first, playing, half })
		assert.are.same({ 1, true, atRest }, { frame.alpha, done, #ticking(loaded) })
	end)

	it("settles a frame hidden while it moves, the UI hidden too, with its cue and onDone run", function()
		local loaded = loadCore()
		local Pagle = loaded.env.Pagle
		local frame = loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent)
		local events = {}
		Pagle.Animate(frame, { fadeIn(loaded, frame) }, function()
			events[#events + 1] = "done"
		end)
		Pagle.Cue(frame, 0.8, function()
			events[#events + 1] = "cue"
		end)
		loaded.client.update(0.25)

		loaded.env.UIParent:Hide() -- Alt-Z
		loaded.client.update(0.1)

		assert.are.same({ 1, { "cue", "done" } }, { frame.alpha, events })
	end)

	it("settles at once with Animations off, and never runs a cue", function()
		local loaded = loadCore()
		local Pagle = loaded.env.Pagle
		loaded.ns.db.profile.announcements.motion = false
		local frame = loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent)
		local cued = false

		Pagle.Animate(frame, { fadeIn(loaded, frame) })
		Pagle.Cue(frame, 0.1, function()
			cued = true
		end)
		loaded.client.update(0.2)

		assert.are.same({ 1, false, false }, { frame.alpha, cued, Pagle.IsAnimationsOn() })
	end)

	it("stops where it is with Pagle.StopMotion", function()
		local loaded = loadCore()
		local Pagle = loaded.env.Pagle
		local frame = loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent)
		Pagle.Animate(frame, { fadeIn(loaded, frame) })
		loaded.client.update(0.5)

		Pagle.StopMotion(frame)
		loaded.client.update(0.5)

		assert.are.equal(0.5, frame.alpha)
	end)
end)
