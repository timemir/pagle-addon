if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The board's moments of change (tackle-board.md › UI, the board art kit's MOTION.md › Moments of change): what the
-- canvas shows only as before and after, played while the board shows and something changes on it. A goal done is
-- stamped DONE, unpinned and flown to the spike, where its slip appears under the nail and its empty pin fades in; a
-- fresh goal drops onto its pin and its tack is pressed in; progress is inked in and its bar runs on; the Campfire steps
-- up (or is lit), burns a Kindling stick or goes out; the Fly Box hops as a fly is tied, and an open drawer settles the
-- fly into its compartment. The functions are the kit's (PagleArtBoard's Transitions.lua), played over the board's own
-- frames after a draw has drawn the new state: adapter/Board.lua hands over what the board showed before the draw.
-- Which moments play is logic/BoardChanges.lua's ns.BoardChanges, over two snapshots of the board (ns.BoardSnapshot).
-- Nothing plays at the board's opening or while the projection updates, and with Core's Animations setting off the
-- board simply shows the new state, each moment marked by its sound alone (adapter/BoardSound.lua's). The moments move
-- on Core's motion driver (Pagle.Animate, announcements.md › Contracts), which reads that setting itself.

local lerp = function(a, b, k)
	return a + (b - a) * k
end

-- When each moment's steps happen, in seconds (MOTION.md).
local STAMP_SOUND, LANDS, EMPTY_FADES, DONE_ENDS = 0.26, 1.3, 1.5, 1.9
local TACK_SOUND, FRESH_ENDS = 0.55, 0.6
-- Where the DONE stamp lands on a Notice's paper and on a poster (its centre).
local STAMP_NOTICE, STAMP_POSTER = { 150, 70 }, { 190, 92 }
-- The done slip's width, which a goal's paper shrinks to on its way to the spike.
local DONE_WIDTH = 136
-- The Fly Box waits for a goal done's slip to land before it hops.
local HOP_AFTER_DONE = 1.5

-- The moments playing: each one's settle (which puts its frames back at rest) by the frames it moves.
---@type table<fun(), Frame[]>
local playing = {}

---@class TackleGrownSprite: TackleSprite
---@field w0 number?   -- its size at rest
---@field h0 number?

-- Sizes `sprite` to `k` times its size at rest, its drawn element's centre kept at `cx`, `cy` of `relativeTo`.
---@param sprite TackleSprite
---@param relativeTo Region
---@param cx number
---@param cy number
---@param k number
local function growAt(sprite, relativeTo, cx, cy, k)
	local grown = sprite --[[@as TackleGrownSprite]]
	grown.w0 = grown.w0 or sprite:GetWidth()
	grown.h0 = grown.h0 or sprite:GetHeight()
	local box, w0, h0 = sprite.box, grown.w0, grown.h0
	sprite:SetSize(math.max(0.01, w0 * k), math.max(0.01, h0 * k))
	sprite:ClearAllPoints()
	sprite:SetPoint(
		"CENTER",
		relativeTo,
		"TOPLEFT",
		cx + (w0 / 2 - (box[1] + box[3] / 2)) * k,
		-(cy + (h0 / 2 - (box[2] + box[4] / 2)) * k)
	)
end

-- Puts a grown sprite back at its size at rest.
---@param sprite TackleSprite
local function ungrow(sprite)
	local grown = sprite --[[@as TackleGrownSprite]]
	if grown.w0 then
		sprite:SetSize(grown.w0, grown.h0)
	end
end

-- Plays one moment: `anims` on `owner` from now, `settle` once `length` seconds have passed (or sooner, when the board
-- hides or opens again), then the board drawn again, so whatever the moment held back shows as the board has it. Only
-- ns.PlayBoardChanges plays one, and only with Core's Animations setting on.
---@param owner Frame
---@param length number
---@param anims table[]
---@param settle fun()
local function play(owner, length, anims, settle)
	playing[settle] = { owner }
	Pagle.Animate(owner, anims)
	Pagle.Cue(owner, length, function()
		if playing[settle] then
			playing[settle] = nil
			settle()
			ns.board:Draw("moment")
		end
	end)
end

-- A step of a moment, `t` seconds in, on `owner` (which `settle`'s moment stops with it).
---@param settle fun()
---@param owner Frame
---@param t number
---@param fn fun()
local function at(settle, owner, t, fn)
	local frames = playing[settle]
	if frames and frames[#frames] ~= owner then
		frames[#frames + 1] = owner
	end
	Pagle.Cue(owner, t, fn)
end

--- Stops every moment playing and puts its frames at rest: the board hides, or opens again.
function ns.SettleBoardChanges()
	local settles = {}
	for settle, frames in pairs(playing) do
		for _, frame in ipairs(frames) do
			Pagle.StopMotion(frame)
		end
		settles[#settles + 1] = settle
	end
	playing = {}
	for _, settle in ipairs(settles) do
		settle()
	end
end

--- What the board shows now, for the next draw to tell what changed (adapter/Board.lua).
---@param frame TackleBoardFrame
---@return TackleBoardShot
function ns.BoardSnapshot(frame)
	---@type TackleBoardShot
	local shot = { pins = {}, hung = {}, glow = frame.glow:IsShown() and frame.glowBase or nil }
	local pins = frame.parts.pins --[[@as TacklePinsFrame]]
	for _, row in ipairs({ pins.slots.expeditions, pins.slots.notices }) do
		for _, slot in ipairs(row) do
			---@cast slot TacklePinSlot
			local slip = slot.goal
			shot.pins[#shot.pins + 1] = {
				slot = slot,
				id = slot.goalID,
				fill = slip and slip.bar.value,
				progress = slip and slip.progress:GetText(),
				busy = slot.busy,
			}
		end
	end
	local ledge = frame.parts.ledge --[[@as TackleLedgeFrame]]
	local fire = ledge.fire
	if fire then
		local view = fire.view
		shot.fire = {
			stage = fire.burning.stage,
			state = view and view.state,
			kindling = view and view.kindling,
			glow = fire.glow:IsShown() and fire.glow:GetAlpha() or nil,
			sticks = #fire.sticks,
		}
		shot.tied, shot.box = ledge.box.tied, ledge.box.count:GetText()
		shot.tally = ledge.plate.counts:GetText()
		local drawer = ledge.drawer
		if drawer and drawer:IsShown() then
			shot.cells = {}
			for i, cell in ipairs(drawer.cells) do
				shot.cells[i] = cell.cell ~= nil and cell.cell.tied
			end
		end
	end
	local spike = frame.parts.spike --[[@as TackleSpikeFrame]]
	if spike.label then
		shot.spike = spike.label:GetText()
	end
	-- the done goals whose slip hangs on the spike
	local goals = ns.State().goals
	for _, slip in ipairs(spike.slips or {}) do
		local id = slip:IsShown() and slip.view and slip.view.id
		local goal = id and goals[id]
		if id and goal and goal.doneDay ~= nil then
			shot.hung[id] = true
		end
	end
	return shot
end

-- A goal done (MOTION.md › A Notice gets done): the DONE stamp lands on its paper, its tacks lift off, and it flies
-- over the cork to the spike, shrinking to a done slip and turning to the angle that slip hangs at; there the slip
-- appears under the nail, the spike's label and the tally plate change, and the empty pin fades in where it hung.
---@param frame TackleBoardFrame
---@param slot TacklePinSlot
---@param hung TackleSpikedSlip
---@param before TackleBoardShot
---@param after TackleBoardShot
local function goalDone(frame, slot, hung, before, after)
	local slip, spike = slot.goal, frame.parts.spike --[[@as TackleSpikeFrame]]
	local ledge = frame.parts.ledge --[[@as TackleLedgeFrame]]
	local width, height = slot:GetSize()
	local x0, y0 = slot.at.x - spike.at.x, slot.at.y - spike.at.y
	local tx, ty, swing, k1 = hung.hangX, hung.hangY, hung.swing, DONE_WIDTH / width
	local lean = slip.lean
	slot.busy = true
	ns.BoardHoverHide()
	slip:Show()
	slip:EnableMouse(false)
	-- It flies over the cork's papers and the spike's slips, and under the nail and every overlay (ns.BOARD_LAYERS).
	slip:SetFrameLevel(frame:GetFrameLevel() + ns.BoardLayer("nail") - 1)
	slip:SetSize(width, height)
	slot.empty:SetAlpha(0)
	hung:SetAlpha(0)
	local stampAt = slip.poster and STAMP_POSTER or STAMP_NOTICE
	local stamp = slip.doneStamp or ns.ArtSprite(slip, "Board", "stamp-done", "OVERLAY", 5)
	slip.doneStamp = stamp
	stamp:Show()
	-- The tally plate and the spike's label keep their words, through any draw, until the slip lands.
	local plate = ledge.plate
	local function hold(tally, label)
		if plate and tally then
			plate.held = tally
			plate.counts:SetText(tally)
		end
		if spike.label and label then
			spike.held = label
			spike.label:SetText(label)
		end
	end
	local function release()
		hold(after.tally, after.spike)
		if plate then
			plate.held = nil
		end
		spike.held = nil
	end
	hold(before.tally, before.spike)

	local function settle()
		slot.busy = nil
		slip:SetScale(1)
		slip:SetAlpha(1)
		slip:ClearAllPoints()
		slip:SetAllPoints(slot)
		slip:EnableMouse(true)
		slip:SetFrameLevel(slip.restLevel)
		slip.lift = 0
		stamp:Hide()
		for i, tack in ipairs(slip.tacks) do
			ns.PlaceSprite(tack, slip, slip.tackAt[i][1], slip.tackAt[i][2])
			tack:SetAlpha(1)
		end
		hung:SetAlpha(1)
		slot.empty:SetAlpha(1)
		release()
	end

	play(slot, DONE_ENDS, {
		-- The DONE stamp lands (0 to 0.32 s), cubic-bezier(.3, 1.6, .5, 1).
		{
			dur = 0.32,
			ease = Pagle.Bezier(0.3, 1.6, 0.5, 1),
			keys = { { 0, { 2.4, 0 } }, { 0.8, { 0.95, 0.95 } }, { 1, { 1, 0.9 } } },
			apply = function(v)
				growAt(stamp, slip, stampAt[1], stampAt[2], v[1])
				stamp:SetAlpha(v[2])
			end,
		},
		-- Unpinned: its tacks lift off (0.55 to 0.7 s).
		{
			dur = 0.7,
			ease = Pagle.EASE.out,
			keys = { { 0, { 0, 1 } }, { 0.78, { 0, 1 } }, { 1, { -8, 0 } } },
			apply = function(v)
				for i, tack in ipairs(slip.tacks) do
					ns.PlaceSprite(tack, slip, slip.tackAt[i][1], slip.tackAt[i][2] + v[1])
					tack:SetAlpha(v[2])
				end
			end,
		},
		-- It flies to the spike (0.65 to 1.3 s), shrinking to the done slip's size and turning to hang, ease-in-out.
		{
			dur = 1.4,
			ease = Pagle.EASE.inOut,
			keys = {
				{ 0, { 0, 0, 1, lean, 1 } },
				{ 0.46, { 0, -6, 1.03, lean, 1 } },
				{ 0.93, { 1, 0, k1, swing, 1 } },
				{ 1, { 1, 0, k1, swing, 0 } },
			},
			apply = function(v)
				local x, y, s = lerp(x0, tx, v[1]), lerp(y0, ty, v[1]) + v[2], v[3]
				slip:SetScale(s)
				slip:ClearAllPoints()
				slip:SetPoint("TOPLEFT", spike, "TOPLEFT", x / s, -y / s) -- a scaled frame's offsets scale with it
				ns.LeanSprite(slip.paper, slip, 0, 0, v[4])
				slip:SetAlpha(v[5])
			end,
		},
	}, settle)
	at(settle, slot, STAMP_SOUND, function()
		ns.BoardSound("stamp", true)
	end)
	-- It lands: its slip shows on the spike over the others, under the nail (1.3 s).
	at(settle, hung, LANDS, function()
		Pagle.Animate(hung, {
			{
				dur = 0.2,
				ease = Pagle.EASE.out,
				keys = { { 0, { 0 } }, { 1, { 1 } } },
				apply = function(v)
					hung:SetAlpha(v[1])
				end,
			},
		})
		ns.BoardSound("pin", true)
		release()
	end)
	-- The empty pin fades in where it hung (1.5 to 1.9 s).
	at(settle, slot.empty, EMPTY_FADES, function()
		Pagle.Animate(slot.empty, {
			{
				dur = 0.4,
				ease = Pagle.EASE.out,
				keys = { { 0, { 0 } }, { 1, { 1 } } },
				apply = function(v)
					slot.empty:SetAlpha(v[1])
				end,
			},
		})
	end)
end

-- A fresh goal on its pin (MOTION.md › A fresh Notice at reset; a goal taken down is replaced the same way): the empty
-- outline fades out, the paper drops in from 30 units up at 108%, leaning to its angle, and its tacks are pressed in.
---@param slot TacklePinSlot
---@param sound boolean its tack's sound: one for the goals pinned at once
local function freshGoal(slot, sound)
	local slip = slot.goal
	local empty = slot.empty
	local width, height = slot:GetSize()
	empty:Show()
	empty:SetAlpha(1)
	local function settle()
		slip:SetScale(1)
		slip:SetAlpha(1)
		slip:ClearAllPoints()
		slip:SetAllPoints(slot)
		slip.lift = 0
		ns.LeanSprite(slip.paper, slip, 0, 0, slip.lean)
		for i, tack in ipairs(slip.tacks) do
			ungrow(tack)
			ns.PlaceSprite(tack, slip, slip.tackAt[i][1], slip.tackAt[i][2])
			tack:SetAlpha(1)
		end
		empty:SetAlpha(1)
		empty:SetShown(slot.goalID == nil)
	end
	slip:SetSize(width, height)
	play(slot, FRESH_ENDS, {
		{
			dur = 0.25,
			ease = Pagle.EASE.out,
			keys = { { 0, { 1 } }, { 1, { 0 } } },
			apply = function(v)
				empty:SetAlpha(v[1])
			end,
		},
		-- It drops onto the cork (0.1 to 0.45 s), cubic-bezier(.3, 1.4, .5, 1).
		{
			dur = 0.45,
			ease = Pagle.Bezier(0.3, 1.4, 0.5, 1),
			keys = { { 0, { -30, 1.08, 0, 0 } }, { 0.22, { -30, 1.08, 0, 0 } }, { 1, { 0, 1, 1, slip.lean } } },
			apply = function(v)
				local s = v[2]
				slip:SetScale(s)
				slip:ClearAllPoints()
				slip:SetPoint("TOPLEFT", slot, "TOPLEFT", 0, -v[1] / s)
				slip:SetAlpha(math.min(1, v[3]))
				ns.LeanSprite(slip.paper, slip, 0, 0, v[4])
			end,
		},
		-- And its tacks are pressed in (0.45 to 0.6 s).
		{
			dur = 0.6,
			ease = Pagle.EASE.out,
			keys = { { 0, { 2, 0 } }, { 0.75, { 2, 0 } }, { 1, { 1, 1 } } },
			apply = function(v)
				for i, tack in ipairs(slip.tacks) do
					local box = tack.box
					growAt(tack, slip, slip.tackAt[i][1] + box[3] / 2, slip.tackAt[i][2] + box[4] / 2, v[1])
					tack:SetAlpha(v[2])
				end
			end,
		},
	}, settle)
	if sound then
		at(settle, slot, TACK_SOUND, function()
			ns.BoardSound("pin", true)
		end)
	end
end

-- Progress inked in (MOTION.md › Progress): the count is rewritten, fading up from 30%, and the bar runs from its old
-- share to the new one, cut to length.
---@param slot TacklePinSlot
---@param from number
---@param to number
local function inked(slot, from, to)
	local slip = slot.goal
	local bar = slip.bar
	local width = bar.width
	play(slot, 0.6, {
		{
			dur = 0.3,
			ease = Pagle.EASE.out,
			keys = { { 0, { 0.3 } }, { 1, { 1 } } },
			apply = function(v)
				slip.progress:SetAlpha(v[1])
			end,
		},
		{
			dur = 0.6,
			ease = Pagle.EASE.out,
			keys = { { 0, { from } }, { 1, { to } } },
			apply = function(v)
				bar:SetBar(width, v[1])
			end,
		},
	}, function()
		slip.progress:SetAlpha(1)
		bar:SetBar(width, to)
	end)
end

-- The fire as it was, drawn over the fire as it is while one crosses to the other, in its own layers.
---@param fire TackleCampfireButton
---@param stage string
---@return TackleBoardFire
local function ghostOf(fire, stage)
	local ghost = fire.ghost or ns.NewBoardFire(fire, fire.burning.x, fire.burning.y)
	fire.ghost = ghost
	ns.SetBoardFire(ghost, stage)
	return ghost
end

-- Hides the ghost's layers.
---@param ghost TackleBoardFire
local function bury(ghost)
	ghost.pop = nil
	for _, texture in pairs(ghost.textures) do
		texture:Hide()
	end
end

-- The Campfire steps up, or is lit (MOTION.md › The Campfire): the old fire and the new crossfade, so it never dips;
-- the new flames rise from 60% to 112% and settle; the ledge's glow swells and the light on the cork flares, then both
-- settle.
---@param frame TackleBoardFrame
---@param fire TackleCampfireButton
---@param from string the stage it was at
local function fireUp(frame, fire, from)
	local burning, ghost = fire.burning, ghostOf(fire, from)
	local glowAt = fire.glowAt
	local function settle()
		bury(ghost)
		burning.pop = nil
		for _, layer in pairs(burning.layers) do
			layer:SetAlpha(1)
		end
		frame.glowBoost = nil
		ungrow(fire.glow)
		ns.PlaceSprite(fire.glow, fire, glowAt[1], glowAt[2])
	end
	play(fire, 1.2, {
		{
			dur = 0.45,
			ease = Pagle.EASE.inOut,
			keys = { { 0, { 1 } }, { 0.22, { 1 } }, { 1, { 0 } } },
			apply = function(v)
				for _, layer in pairs(ghost.layers) do
					layer:SetAlpha(v[1])
				end
			end,
		},
		{
			dur = 0.4,
			ease = Pagle.EASE.out,
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				for _, layer in pairs(burning.layers) do
					layer:SetAlpha(v[1])
				end
			end,
		},
		{
			dur = 0.9,
			ease = Pagle.Bezier(0.3, 1.5, 0.5, 1),
			keys = { { 0, { 0.6 } }, { 1, { 1 } } },
			apply = function(v)
				burning.pop = v[1]
			end,
		},
		{
			dur = 1.2,
			ease = Pagle.EASE.inOut,
			keys = { { 0, { 1, 1 } }, { 0.35, { 1.5, 1.6 } }, { 1, { 1, 1 } } },
			apply = function(v)
				local box = fire.glow.box
				growAt(fire.glow, fire, glowAt[1] + box[3] / 2, glowAt[2] + box[4] / 2, v[1])
				frame.glowBoost = v[2]
			end,
		},
	}, settle)
end

-- The Campfire goes out (MOTION.md › The Campfire): the flames sink to 15% and fade, the logs cross to the charred ones
-- with the embers, the ledge's glow and the light on the cork die with them, and "Gone out" shows at 0.8 s.
---@param frame TackleBoardFrame
---@param fire TackleCampfireButton
---@param from string the stage it was at
---@param before TackleBoardShot
local function fireOut(frame, fire, from, before)
	local burning, ghost = fire.burning, ghostOf(fire, from)
	local ledgeGlow, corkGlow = before.fire and before.fire.glow or 0, before.glow or 0
	fire.glow:Show()
	frame.glow:Show()
	-- Its days stay, through any draw, until "Gone out" shows.
	fire.held = true
	fire.text:Hide()
	fire.days:Show()
	fire.word:Show()
	local function goneOut()
		fire.held = nil
		fire.days:Hide()
		fire.word:Hide()
		fire.text:Show()
	end
	-- The ghost's flames flicker on as they sink, on a frame of their own, stopped with the moment.
	local flicker = fire.ghostMotion or CreateFrame("Frame", nil, fire)
	fire.ghostMotion = flicker
	local function settle()
		goneOut()
		Pagle.StopMotion(flicker)
		bury(ghost)
		for _, layer in pairs(burning.layers) do
			layer:SetAlpha(1)
		end
		fire.glow:Hide()
		frame.glow:Hide()
	end
	ns.FireMotion(flicker, ghost)
	play(fire, 1.6, {
		{
			dur = 1.2,
			ease = Pagle.Bezier(0.42, 0, 1, 1),
			keys = { { 0, { 1, 1 } }, { 1, { 0.15, 0 } } },
			apply = function(v)
				ghost.pop = v[1]
				for suffix, layer in pairs(ghost.layers) do
					if suffix:find("-fl", 1, true) then
						layer:SetAlpha(v[2])
					end
				end
			end,
		},
		{
			dur = 1.6,
			ease = Pagle.EASE.inOut,
			keys = { { 0, { 1, 0 } }, { 0.4, { 1, 0 } }, { 1, { 0, 1 } } },
			apply = function(v)
				for suffix, layer in pairs(ghost.layers) do
					if not suffix:find("-fl", 1, true) then
						layer:SetAlpha(v[1])
					end
				end
				-- The embers breathe on their own (adapter/BoardMotion.lua); the charred logs and stones come up.
				for suffix, layer in pairs(burning.layers) do
					if suffix ~= "-embers" then
						layer:SetAlpha(v[2])
					end
				end
				fire.glow:SetAlpha(ledgeGlow * v[1])
				frame.glow:SetAlpha(corkGlow * v[1])
			end,
		},
	}, settle)
	at(settle, fire, 0.8, goneOut)
end

-- A Kindling stick burns (MOTION.md › The Campfire): a flare of ember, then it chars and dims to the spent stick's 28%.
---@param fire TackleCampfireButton
---@param stick TackleSprite
local function kindlingBurns(fire, stick)
	play(fire, 0.9, {
		{
			dur = 0.9,
			ease = Pagle.EASE.inOut,
			keys = {
				{ 0, { 1, 1, 1, 1 } },
				{ 0.25, { 1, 0.62, 0.3, 1 } },
				{ 0.6, { 0.3, 0.18, 0.12, 0.8 } },
				{ 1, { 1, 1, 1, 0.28 } },
			},
			apply = function(v)
				stick:SetVertexColor(v[1], v[2], v[3])
				stick:SetAlpha(v[4])
			end,
		},
	}, function()
		stick:SetVertexColor(1, 1, 1)
		stick:SetAlpha(0.28)
	end)
end

-- A fly tied, on the ledge (MOTION.md › A fly tied): the Fly Box hops 4 units, then 2, and its count ticks over.
---@param ledge TackleLedgeFrame
---@param from string its count as it was
---@param delay number
---@param sound boolean
local function boxHops(ledge, from, delay, sound)
	local box = ledge.box
	local to = box.count:GetText()
	-- Its count keeps its words, through any draw, until it hops.
	box.held = from
	box.count:SetText(from)
	local function place(dy)
		box:ClearAllPoints()
		box:SetPoint("TOPLEFT", ledge, "TOPLEFT", box.at[1], -(box.at[2] + dy))
	end
	local function tick()
		box.held = nil
		box.count:SetText(to)
	end
	local function settle()
		place(0)
		tick()
	end
	play(box, delay + 0.5, {}, settle)
	at(settle, box, math.max(0.001, delay), function()
		if sound then
			ns.BoardSound("flyTied")
		end
		Pagle.Animate(box, {
			{
				dur = 0.5,
				ease = Pagle.EASE.out,
				keys = { { 0, { 0 } }, { 0.2, { -4 } }, { 0.4, { 0 } }, { 0.6, { -2 } }, { 0.8, { 0 } }, { 1, { 0 } } },
				apply = function(v)
					place(v[1])
				end,
			},
		})
		Pagle.Cue(box, 0.15, tick)
	end)
end

-- A fly tied, in the open drawer (MOTION.md › A fly tied): the fly takes its colour and settles into its compartment
-- from 150%, the compartment's gilt ring glows twice, and its name fades in.
---@param cell TackleFlyCellView
local function flySettles(cell)
	local fly = cell.fly
	local glow = cell.glow
	if not glow then
		glow = ns.ArtSprite(cell, "Board", "cell-rare", "OVERLAY", 3)
		ns.SizeSprite(glow, cell:GetWidth(), cell:GetHeight())
		ns.PlaceSprite(glow, cell, 0, 0)
		glow:SetBlendMode("ADD")
		cell.glow = glow
	end
	glow:Show()
	local box = fly.box
	local cx, cy = cell.flyAt[1] + box[3] / 2, cell.flyAt[2] + box[4] / 2
	play(cell, 1.2, {
		{
			dur = 0.6,
			ease = Pagle.Bezier(0.3, 1.5, 0.5, 1),
			keys = { { 0, { 1.5, 0.22 } }, { 1, { 1, 1 } } },
			apply = function(v)
				growAt(fly, cell, cx, cy, v[1])
				fly:SetAlpha(v[2])
			end,
		},
		{
			dur = 0.6,
			ease = Pagle.EASE.inOut,
			iter = 2,
			dir = "alternate",
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				glow:SetAlpha(v[1])
			end,
		},
		{
			dur = 0.4,
			ease = Pagle.EASE.out,
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				cell.label:SetAlpha(v[1])
			end,
		},
	}, function()
		ungrow(fly)
		ns.PlaceSprite(fly, cell, cell.flyAt[1], cell.flyAt[2])
		fly:SetAlpha(1)
		glow:Hide()
		cell.label:SetAlpha(1)
	end)
end

-- The done slip on the spike for `goalID`, if one hangs there.
---@param spike TackleSpikeFrame
---@param goalID string
---@return TackleSpikedSlip?
local function hungSlip(spike, goalID)
	for _, slip in ipairs(spike.slips or {}) do
		if slip:IsShown() and slip.view and slip.view.id == goalID then
			return slip
		end
	end
	return nil
end

--- Plays what changed on the board since `before` (ns.BoardSnapshot), over what the draw just drew: adapter/Board.lua
--- calls it after each draw of an open, started board that isn't updating, but the one that opens it. Which moments and
--- sounds play is ns.BoardChanges's (logic/BoardChanges.lua): with Core's Animations setting off no moment plays, but
--- each one's sound marks it all the same (the beats of the motion aside).
---@param frame TackleBoardFrame
---@param before TackleBoardShot
function ns.PlayBoardChanges(frame, before)
	local spike = frame.parts.spike --[[@as TackleSpikeFrame]]
	local ledge = frame.parts.ledge --[[@as TackleLedgeFrame]]
	local fire = ledge.fire
	local after = ns.BoardSnapshot(frame)
	for _, moment in ipairs(ns.BoardChanges(before, after, ns.MotionOn())) do
		if moment.sound then
			ns.BoardSound(moment.sound)
		end
		local kind = moment.kind
		if kind == "goalDone" then
			goalDone(frame, moment.slot, hungSlip(spike, moment.goalID) --[[@as TackleSpikedSlip]], before, after)
		elseif kind == "freshGoal" then
			freshGoal(moment.slot, moment.tack == true)
		elseif kind == "inked" then
			inked(moment.slot, moment.from, moment.to --[[@as number]])
		elseif kind == "fireUp" and fire then
			fireUp(frame, fire, moment.from)
		elseif kind == "fireOut" and fire then
			fireOut(frame, fire, moment.from, before)
		elseif kind == "kindlingBurns" and fire then
			kindlingBurns(fire, fire.sticks[moment.stick])
		elseif kind == "flySettles" and ledge.drawer then
			flySettles(ledge.drawer.cells[moment.cell])
		elseif kind == "boxHops" then
			boxHops(ledge, moment.from, moment.afterDone and HOP_AFTER_DONE or 0, moment.flyTied == true)
		end
	end
end
