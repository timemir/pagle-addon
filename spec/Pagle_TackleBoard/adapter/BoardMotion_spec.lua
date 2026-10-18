-- The board's motion (tackle-board.md › UI, the board art kit's MOTION.md): on Core's motion driver (Pagle.Animate),
-- the Campfire's layers flickering, the glow breathing on the cork, the highlight's ring pulsing, and Core's Animations
-- setting, Pagle.IsAnimationsOn() read through ns.MotionOn, leaving everything at rest. The fake client runs the
-- driver's OnUpdate with client.update.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")
local record = board.record

local W, TODAY = board.WEEK0, board.DAILY_RESET
local DUROTAR, BLACKMOUTH = 14, 6358
local S = TODAY + 60

-- A board started today with one Notice done: a Campfire of 1 day, its fire at its first stage.
local LIT = {
	board.skill(S - 30),
	record("start", S, TODAY .. ";" .. W),
	record("issue", S + 1, "e;haul;0;60;150;12"),
	record("issue", S + 2, "n;haul;1;10;1;14"),
	board.cast(S + 10, DUROTAR, { BLACKMOUTH }),
}

-- The board open on LIT, its login's live step run, with Core's Animations setting off when `on` is false.
local function opened(on)
	return board.opened(LIT, { step = true, motion = on })
end

describe("Core's Animations setting (ns.MotionOn)", function()
	it("reads Pagle.IsAnimationsOn(): on by default, off once the player turns it off", function()
		local loaded, fake = board.load()

		assert.is_true(loaded.ns.MotionOn())
		fake.profile.announcements.motion = false
		assert.is_false(loaded.ns.MotionOn())
	end)

	it("leaves the motion copy and the fit copy to Core: the board moves on Pagle.Animate", function()
		local ns = board.load().ns

		assert.is_nil(rawget(ns, "Animate"))
		assert.is_nil(rawget(ns, "FitToScreen"))
		assert.is_nil(rawget(ns, "motion"))
	end)
end)

describe("the Campfire's motion (tackle-board.md › UI)", function()
	it("flickers its three flames out of step while the board shows", function()
		local loaded, _, frame = opened()
		local flames = frame.parts.ledge.fire.burning.layers
		local rest = { flames["-fl1"]:GetWidth(), flames["-fl2"]:GetWidth(), flames["-fl3"]:GetWidth() }

		loaded.client.update(0.7)

		local now = { flames["-fl1"]:GetWidth(), flames["-fl2"]:GetWidth(), flames["-fl3"]:GetWidth() }
		for i = 1, 3 do
			assert.are_not.equal(rest[i], now[i])
		end
		assert.is_true(math.abs(now[1] / rest[1] - now[2] / rest[2]) > 0.001) -- not in step
	end)

	it("breathes its light on the cork", function()
		local loaded, _, frame = opened()
		local before = frame.glow:GetAlpha()

		loaded.client.update(1.76) -- 55% of 3.2 s: the breath's low

		assert.is_true(frame.glow:GetAlpha() < before)
	end)

	it("stays at rest with Core's Animations off: the flames still, the light steady", function()
		local loaded, _, frame = opened(false)
		local flame = frame.parts.ledge.fire.burning.layers["-fl1"]
		local width, glow = flame:GetWidth(), frame.glow:GetAlpha()

		loaded.client.update(0.7)

		assert.are.same({ width, glow }, { flame:GetWidth(), frame.glow:GetAlpha() })
	end)

	it("doesn't restart the flicker at every redraw, only when the fire changes", function()
		local loaded, _, frame = opened()
		local flame = frame.parts.ledge.fire.burning.layers["-fl1"]
		loaded.client.update(0.7)
		local width = flame:GetWidth()

		loaded.ns.Redraw("minute")

		assert.are.equal(width, flame:GetWidth())
	end)

	it("flickers again once the whole UI shows again after hiding it (Alt-Z)", function()
		local loaded, _, frame = opened()
		local flame = frame.parts.ledge.fire.burning.layers["-fl1"]
		local UIParent = loaded.env.UIParent
		frame.IsVisible = function(self)
			return self:IsShown() and UIParent:IsShown()
		end

		-- The client runs the OnHide of each shown frame under UIParent, then its OnShow as UIParent shows again.
		UIParent:Hide()
		frame:GetScript("OnHide")(frame)
		loaded.client.update(0.1)
		local hidden = flame:GetWidth()
		loaded.client.update(0.5)
		assert.are.equal(hidden, flame:GetWidth()) -- settled while hidden
		UIParent:Show()
		frame:GetScript("OnShow")(frame)
		loaded.client.update(0.7)

		assert.are_not.equal(hidden, flame:GetWidth())
	end)

	it("stops once the board no longer shows", function()
		local loaded, _, frame = opened()
		local flame = frame.parts.ledge.fire.burning.layers["-fl1"]
		frame.IsVisible = function(self)
			return self:IsShown()
		end

		loaded.ns.board:Hide()
		loaded.client.update(0.1)
		local width = flame:GetWidth()
		loaded.client.update(0.5)

		assert.are.equal(width, flame:GetWidth())
	end)
end)

describe("the highlight's ring (TKB-R109)", function()
	it("pulses twice as it shows, then stays lit", function()
		local loaded = board.load()
		local ns = loaded.ns
		local parent = loaded.env.CreateFrame("Frame")
		parent:SetSize(236, 116)
		local highlight = ns.NewBoardHighlight(parent, false)

		highlight:Show()
		assert.are.equal(0.4, highlight.ring:GetAlpha())
		loaded.client.update(1)
		loaded.client.update(1.1)

		assert.are.equal(1, highlight.ring:GetAlpha())
	end)
end)
