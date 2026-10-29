---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The Curio crate in the Curio Shop's well (wallet-and-shop.md › UI, the crate's stage; SHOP-R54): the assembled crate at
-- rest, the same parts as the opening's (adapter/ShopCrate.lua puts them together), scaled to the well. While the pointer
-- is over it, the lid lifts a few units and a warm glow comes out of the seam, with the kit's rays, light and sparks
-- twinkling out of it, until the pointer leaves; with the Animations setting off it shows the glow still and nothing
-- moves (SET-R30). It takes no click: buying opens the reel from the bill (SHOP-R55). Every motion is the shop's own
-- (adapter/Motion.lua's ns.Animate, on the well's view as its owner), so it stops where the view hides.
local BOX = ns.CRATE_BOX
-- The crate's drawn extent, from the top of the lid to the foot of the body, in the box's units, and its width with the
-- lid's overhang: the crate is scaled to the well's height and centred in it by these.
local TOP, FOOT, WIDE = 23, 229, 306
local SCALE = 0.55
-- How far the lid lifts, in the crate's units, and the glow's size along the seam and across it, as the seal's glow sprite
-- stretches.
local LIFT = 10
local GLOW_W, GLOW_H = 3.4, 0.7
-- How much of its whole opacity each light shows at its fullest (the rays and the beam are the opening's, softened for a
-- well that stands still at rest).
local RAYS_ALPHA, BEAM_ALPHA = 0.22, 0.4
-- The glow's breath and the rays' turn, in seconds a cycle, and the rise and fall of the lid and glow.
local BREATH, TURN, RISE, FALL = 1.5, 36, 0.3, 0.2
-- The warm colour the sparks are drawn in.
local WARM = { 1, 0.86, 0.5 }

-- The sparks twinkling out of the seam: where along it each starts (from the box's left), how far it rises and drifts, how
-- many seconds it lives, when it starts, and its size, in each cycle's order. Fixed, so the same twinkle plays every
-- time. None rises past 66 units: the well's clip cuts the box at 6 units from its top, 76 above the seam, and a spark
-- is gone (and at 15% of its size) by the time it is 66 up, so none is ever sliced by it.
local SPARKS = {
	{ 70, 62, -10, 1.8, 0.0, 1.0 },
	{ 104, 66, 6, 2.2, 0.35, 0.8 },
	{ 140, 64, -4, 1.7, 0.9, 1.1 },
	{ 176, 66, 12, 2.4, 0.15, 0.9 },
	{ 90, 60, 8, 2.0, 1.2, 0.7 },
	{ 158, 58, -12, 1.6, 0.6, 1.0 },
	{ 122, 66, 2, 2.6, 1.5, 0.8 },
	{ 190, 64, -6, 1.9, 1.0, 0.7 },
}
local MAX_RISE = 66

---@class PagleCratePreviewSpark
---@field part PagleCratePart
---@field at number[]  the spark's row of SPARKS

---@class PagleCratePreview
---@field view Frame                 the well's clip: all of it draws inside
---@field hit Frame                  what the pointer is over
---@field box Frame                  the crate's box, scaled: its parts' anchor
---@field pose PagleCrateStage       what ns.PoseCratePart reads: the box, and no group pose
---@field crate table<string, PagleCratePart>
---@field rays PagleCratePart
---@field beam PagleCratePart
---@field sparks PagleCratePreviewSpark[]
---@field glow number                how much of the glow shows, 0 to 1
---@field lift number                how far the lid has lifted, 0 to 1
---@field pulse number               the glow's breath, 0 to 1 of its fullest
---@field turn number                the rays' turn, degrees
---@field still boolean              the glow shows with nothing moving (Animations off)

-- Each frame's preview, made at its first drawing. Weak, so a frame that goes takes its preview.
---@type table<Frame, PagleCratePreview>
local previews = setmetatable({}, { __mode = "k" })

-- Puts every part where the preview's state has it: the lid up by its lift, the glow along the seam and its opacity, the
-- rays and the beam in their share of it.
---@param p PagleCratePreview
local function place(p)
	local crate, pose = p.crate, p.pose
	crate.lid.own[2] = -LIFT * p.lift
	ns.PoseCratePart(pose, crate.lid)
	-- the glow rides the seam: the sprite's middle is a little above it, and the gap the lid opens takes it up. Its pose
	-- is set in place, as place runs every frame.
	local glow = crate.glow.own
	glow[2], glow[4], glow[5] = BOX.seamY - 78.4 - LIFT * p.lift * 0.5, GLOW_W, GLOW_H
	ns.PoseCratePart(pose, crate.glow)
	ns.FadeCratePart(pose, crate.glow, p.glow * p.pulse)
	p.rays.own[3] = p.turn
	ns.PoseCratePart(pose, p.rays)
	ns.FadeCratePart(pose, p.rays, p.still and 0 or p.glow)
	ns.FadeCratePart(pose, p.beam, p.glow * (0.6 + 0.4 * p.pulse))
end

-- Hides every spark.
---@param p PagleCratePreview
local function clearSparks(p)
	for _, spark in ipairs(p.sparks) do
		spark.part.tex:Hide()
	end
end

-- Puts everything at rest: the lid down, no glow, no light, no sparks.
---@param p PagleCratePreview
local function settle(p)
	p.glow, p.lift, p.pulse, p.turn, p.still = 0, 0, 1, 0, false
	clearSparks(p)
	place(p)
end

-- Everything at rest, and nothing playing.
---@param p PagleCratePreview
local function rest(p)
	ns.StopMotion(p.view)
	settle(p)
end

-- One spark's twinkle as an animation, looping: it grows out of its place on the seam, rises and drifts as it brightens,
-- turns, and fades away smaller; each is offset in time, so some are always twinkling.
---@param p PagleCratePreview
---@param spark PagleCratePreviewSpark
---@return PagleAnimation
local function twinkle(p, spark)
	local x, rise, drift, dur, delay, size = unpack(spark.at)
	rise = math.min(rise, MAX_RISE)
	local y = BOX.seamY
	local part = spark.part
	local def = part.def
	return {
		dur = dur,
		delay = delay,
		iter = "infinite",
		ease = ns.EASE.linear,
		keys = {
			{ 0, { x, y, 0.25 * size, 0, 0 } },
			{ 0.2, { x + drift * 0.2, y - rise * 0.3, size, 1, 30 } },
			{ 0.6, { x + drift * 0.6, y - rise * 0.7, 0.7 * size, 0.7, 70 } },
			{ 1, { x + drift, y - rise, 0.15 * size, 0, 110 } },
		},
		apply = function(v)
			local tex = part.tex
			tex:SetSize(def.size[1] * v[3], def.size[2] * v[3])
			tex:ClearAllPoints()
			tex:SetPoint("CENTER", p.box, "TOPLEFT", v[1], -v[2])
			tex:SetRotation(math.rad(-v[5]))
			tex:SetAlpha(v[4])
			tex:SetShown(v[4] > 0.01)
		end,
	}
end

-- What plays while the pointer is over the crate, from wherever the glow, lid and rays have got to: one clock (seconds
-- since the pointer came, for a day) drives the rise of the lid and the glow, the glow's breath and the rays' slow turn,
-- so each frame places the parts once; and every spark's twinkle. Its motion settles where a hidden owner's animations
-- do (adapter/Motion.lua: the shop closed, the pointer never leaving), which for it is rest.
---@param p PagleCratePreview
---@return PagleAnimation[]
local function hover(p)
	local glow, lift, turn = p.glow, p.lift, p.turn
	local animations = {
		{
			dur = 86400,
			iter = "infinite",
			ease = ns.EASE.linear,
			keys = { { 0, { 0 } }, { 1, { 86400 } } },
			apply = function(v)
				if not p.view:IsVisible() then
					settle(p)
					return
				end
				local t = v[1]
				local u = ns.EASE.out(math.min(1, t / RISE))
				p.glow, p.lift = glow + (1 - glow) * u, lift + (1 - lift) * u
				-- the breath starts at its fullest, as the glow rests, and dips to 0.7 and back every 2 * BREATH
				p.pulse = 0.85 + 0.15 * math.cos(math.pi * t / BREATH)
				p.turn = (turn + 360 * t / TURN) % 360
				place(p)
			end,
		},
	}
	for _, spark in ipairs(p.sparks) do
		animations[#animations + 1] = twinkle(p, spark)
	end
	return animations
end

-- The pointer is over the crate: the lid lifts and the light comes out of the seam, looping until it leaves; with
-- Animations off, the glow shows still.
---@param p PagleCratePreview
local function enter(p)
	ns.StopMotion(p.view)
	if not ns.MotionOn() then
		p.glow, p.lift, p.pulse, p.still = 1, 0, 1, true
		place(p)
		return
	end
	p.still = false
	ns.Animate(p.view, hover(p))
end

-- The pointer has left: what played stops where it is, the sparks go, and the lid comes down and the light fades.
---@param p PagleCratePreview
local function leave(p)
	ns.StopMotion(p.view)
	clearSparks(p)
	ns.Animate(p.view, {
		{
			dur = FALL,
			ease = ns.EASE.out,
			keys = { { 0, { p.glow, p.lift } }, { 1, { 0, 0 } } },
			apply = function(v)
				p.glow, p.lift = v[1], v[2]
				place(p)
			end,
		},
	}, function()
		p.still = false
	end)
end

-- Builds the crate's preview on `frame`: the well's clip, with the light behind the crate, the crate, and the sparks over
-- it, all in one box scaled to the well; and the frame the pointer is over.
---@param frame Frame
---@return PagleCratePreview
local function build(frame)
	local view = CreateFrame("Frame", nil, frame)
	view:SetSize(ns.GOOD_PREVIEW_W, ns.GOOD_PREVIEW_H)
	view:SetPoint("TOP", frame, "TOP", 0, 0)
	view:SetClipsChildren(true)
	local box = CreateFrame("Frame", nil, view)
	box:SetSize(BOX.w, BOX.h)
	box:SetScale(SCALE)
	-- The crate's drawn extent is centred in the well: its middle lies this far under the box's, so the box's lies this
	-- far above the well's.
	box:SetPoint("CENTER", view, "CENTER", 0, (TOP + FOOT) / 2 - BOX.h / 2)
	local level = view:GetFrameLevel()
	local function layer(above)
		local child = CreateFrame("Frame", nil, box)
		child:SetAllPoints(box)
		child:SetFrameLevel(level + above)
		return child
	end
	local light, body, over = layer(1), layer(2), layer(3)
	-- What ns.PoseCratePart reads of a stage: the box, and a group pose that stays put.
	local pose = {
		box = box,
		group = { tx = 0, ty = 0, deg = 0, sx = 1, sy = 1, ox = BOX.w / 2, oy = BOX.h },
		groupAlpha = 1,
	}
	local made = {
		view = view,
		box = box,
		pose = pose,
		sparks = {},
		glow = 0,
		lift = 0,
		pulse = 1,
		turn = 0,
		still = false,
	}
	local p = made --[[@as PagleCratePreview]]
	p.pose = pose --[[@as PagleCrateStage]]
	local mid = BOX.w / 2
	-- the light: the rays turning behind the seam, the beam rising from it, each in the kit's own warm tint
	p.rays = ns.NewCratePart(light, "rays-crate", mid, BOX.seamY, "ARTWORK", 0)
	p.rays.alpha = RAYS_ALPHA
	p.beam = ns.NewCratePart(light, "fx-beam", 0, 0, "ARTWORK", 1)
	p.beam.alpha = BEAM_ALPHA
	p.beam.x, p.beam.y = mid - p.beam.w / 2, BOX.seamY - p.beam.h
	local parts
	p.crate, parts = ns.AssembleCrate(body, 0, 0)
	for _, part in ipairs(parts) do
		ns.PoseCratePart(p.pose, part)
	end
	for _, row in ipairs(SPARKS) do
		local part = ns.NewCratePart(over, "fx-spark", 0, 0, "ARTWORK", 0)
		part.tex:SetVertexColor(WARM[1], WARM[2], WARM[3])
		p.sparks[#p.sparks + 1] = { part = part, at = row }
	end
	-- the pointer: over the crate's drawn extent, which takes no click of its own
	local hit = CreateFrame("Frame", nil, view)
	hit:SetSize(WIDE * SCALE, (FOOT - TOP) * SCALE)
	hit:SetPoint("CENTER", view, "CENTER", 0, 0)
	hit:SetFrameLevel(level + 4)
	hit:EnableMouse(true)
	hit:SetScript("OnEnter", function()
		enter(p)
	end)
	hit:SetScript("OnLeave", function()
		leave(p)
	end)
	p.hit = hit
	-- Hidden with the stage (another good selected, the shop closed): back to rest, so it shows still the next time.
	local function hidden()
		rest(p)
	end
	view:SetScript("OnHide", hidden)
	frame:SetScript("OnHide", hidden)
	-- what is posed every frame keeps its origin, so that posing it allocates none
	for _, part in ipairs({ p.rays, p.crate.glow }) do
		part.origin = { x = part.x + part.w / 2, y = part.y + part.h / 2 }
	end
	for _, part in ipairs({ p.rays, p.beam }) do
		ns.PoseCratePart(p.pose, part)
	end
	return p
end

--- Draws the Curio crate at rest in `frame`, the stage's own frame for it (adapter/GoodPreview.lua's DrawLook hands it
--- over): the preview is made at the first drawing and set back to rest at each one.
---@param frame Frame|{ cratePreview: PagleCratePreview? }
function ns.DrawCratePreview(frame)
	local p = previews[frame]
	if not p then
		p = build(frame)
		previews[frame] = p
	end
	frame.cratePreview = p
	p.view:Show()
	rest(p)
end
