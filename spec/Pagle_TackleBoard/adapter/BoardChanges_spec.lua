-- The board's sounds, its fit to the screen and its moments of change (tackle-board.md › UI; the board art kit's
-- SOUND.md and MOTION.md): adapter/BoardSound.lua, adapter/Fit.lua and adapter/BoardChanges.lua, over a board opened
-- on the fake client, live Casts completing its goals while it shows. The fake client runs the motion driver's
-- OnUpdate with client.update, and records each PlaySound as "<id> <channel>" in client.sounds.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")
local record = board.record

local W, TODAY = board.WEEK0, board.DAILY_RESET
local DUROTAR, BARRENS, BLACKMOUTH = 14, 17, 6358
local S = TODAY + 60

-- A board started today with an Expedition and two Notices in Durotar: one done by a Catch there, one by two.
local POSTED = {
	board.skill(S - 30),
	record("start", S, TODAY .. ";" .. W),
	record("issue", S + 1, "e;haul;0;60;150;12"),
	record("issue", S + 2, "n;haul;1;10;1;14"),
	record("issue", S + 3, "n;haul;1;10;2;14"),
}

-- The board open on POSTED, its login's live step run, with ns.AnimationsOn answering `on` when given.
local function opened(on)
	return board.opened(POSTED, {
		step = true,
		load = on ~= nil and {
			prepare = function(loaded)
				loaded.ns.AnimationsOn = function()
					return on
				end
			end,
		} or nil,
	})
end

-- The sound kits played so far, as "<id> <channel>".
---@return string[]
local function kits(loaded)
	local out = {}
	for _, sound in ipairs(loaded.client.sounds) do
		if sound:find("^%d+ ") then
			out[#out + 1] = sound
		end
	end
	return out
end

-- The pin slot showing `goalID`, or nil.
local function slotOf(frame, goalID)
	for _, row in ipairs({ frame.parts.pins.slots.expeditions, frame.parts.pins.slots.notices }) do
		for _, slot in ipairs(row) do
			if slot.goalID == goalID then
				return slot
			end
		end
	end
	return nil
end

-- `seconds` of frames, a tenth of a second each.
local function frames(loaded, seconds)
	for _ = 1, math.floor(seconds * 10 + 0.5) do
		loaded.client.update(0.1)
	end
end

describe("the board's sounds (tackle-board.md › UI › Sound)", function()
	it("sounds its opening once, on the SFX channel, and its closing", function()
		local loaded, _, frame = opened()

		loaded.ns.OpenBoard() -- the tracker opening it again, open
		assert.are.same({ "844 SFX" }, kits(loaded))

		frame.close:Click()
		assert.are.same({ "844 SFX", "845 SFX" }, kits(loaded))
	end)

	it("sounds the Fly Box drawer's opening and closing", function()
		local loaded, _, frame = opened()
		local box = frame.parts.ledge.box

		box:Click()
		box:Click()

		assert.are.same({ "844 SFX", "862 SFX", "863 SFX" }, kits(loaded))
	end)
end)

describe("the board's fit to the screen (adapter/Fit.lua)", function()
	it("shrinks to fit a small screen as it opens, and never grows past 1", function()
		local loaded, _, frame = opened()
		assert.are.equal(1, frame:GetScale())
		loaded.ns.board:Hide()

		loaded.env.UIParent:SetSize(1188, 668) -- 1366 × 768 at UI scale 1.15
		loaded.ns.OpenBoard()

		assert.are.equal((668 - 48) / 690, frame:GetScale())
	end)
end)

describe("a goal done while the board shows (MOTION.md › A Notice gets done)", function()
	it("stamps it, flies it to the spike and lands its slip there, then shows its empty pin", function()
		local loaded, fake, frame = opened()
		local goalID = board.idAt(S + 2)
		local slot = slotOf(frame, goalID)

		board.live(fake, board.cast(S + 100, DUROTAR, { BLACKMOUTH }))

		local slip = slot.goal
		assert.is_true(slip:IsShown()) -- still on its way
		assert.is_true(slot.busy)
		-- the goal done, and the Campfire lit by the day's first goal
		assert.are.same({ "844 SFX", "878 SFX", "23287 SFX" }, kits(loaded))
		frames(loaded, 0.4)
		assert.are.equal("1204 SFX", kits(loaded)[4]) -- the stamp lands
		frames(loaded, 1)
		assert.are.equal("1212 SFX", kits(loaded)[5]) -- its slip is pinned on the spike
		frames(loaded, 1)

		assert.is_false(slip:IsShown())
		assert.is_nil(slot.busy)
		assert.are.same({ 1, 1 }, { slip:GetScale(), slip:GetAlpha() })
		assert.is_true(slot.empty:IsShown())
		assert.are.equal(1, slot.empty:GetAlpha())
	end)

	it("hops the Fly Box once the slip has landed, its count ticking over", function()
		local loaded, fake, frame = opened()
		local box = frame.parts.ledge.box
		local count = box.count:GetText()

		board.live(fake, board.cast(S + 100, DUROTAR, { BLACKMOUTH }))

		assert.are.equal(count, box.count:GetText())
		frames(loaded, 1.8)
		assert.are.equal("73919 SFX", kits(loaded)[6])
		frames(loaded, 0.5)
		assert.are_not.equal(count, box.count:GetText())
	end)

	it("with Core's Animations off, shows it done at once, its sound alone marking it", function()
		local loaded, fake, frame = opened(false)
		local slot = slotOf(frame, board.idAt(S + 2))

		board.live(fake, board.cast(S + 100, DUROTAR, { BLACKMOUTH }))

		assert.is_false(slot.goal:IsShown())
		assert.is_true(slot.empty:IsShown())
		frames(loaded, 2)
		-- no stamp nor tack: those are beats of the motion
		assert.are.same({ "844 SFX", "878 SFX", "23287 SFX", "73919 SFX" }, kits(loaded))
	end)

	it("settles when the board closes mid-flight", function()
		local loaded, fake, frame = opened()
		local slot = slotOf(frame, board.idAt(S + 2))
		board.live(fake, board.cast(S + 100, DUROTAR, { BLACKMOUTH }))
		frames(loaded, 0.8)

		loaded.ns.board:Hide()
		loaded.ns.OpenBoard()

		assert.is_nil(slot.busy)
		assert.is_false(slot.goal:IsShown())
		assert.are.same({ 1, 1 }, { slot.goal:GetScale(), slot.goal:GetAlpha() })
	end)
end)

describe("progress inked in (MOTION.md › Progress)", function()
	it("runs the bar from its old share to the new one, the count fading up", function()
		local loaded, fake, frame = opened()
		local slot = slotOf(frame, board.idAt(S + 3))
		local bar = slot.goal.bar

		board.live(fake, board.cast(S + 100, BARRENS, { BLACKMOUTH })) -- another zone: nothing
		assert.are.equal(0, bar.value)
		board.live(fake, board.cast(S + 110, DUROTAR, { BLACKMOUTH }))

		assert.are.equal(0, bar.value)
		assert.are.equal(0.3, slot.goal.progress:GetAlpha())
		frames(loaded, 0.3)
		assert.is_true(bar.value > 0 and bar.value < 0.5)
		frames(loaded, 0.5)
		assert.are.equal(0.5, bar.value)
		assert.are.equal(1, slot.goal.progress:GetAlpha())
	end)
end)
