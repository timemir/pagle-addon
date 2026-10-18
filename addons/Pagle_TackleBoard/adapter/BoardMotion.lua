if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The board's motion (tackle-board.md › UI, the board art kit's MOTION.md), played by Core's motion driver
-- (Pagle.Animate, announcements.md › Contracts), which reads Core's Animations setting itself: the Campfire in its
-- layers (three flames flickering out of step about the fire's foot, the 365-day rays turning, a dead fire's embers
-- breathing), the fire's light breathing on the cork, the ring of a pin opened from the tracker pulsing twice, and a pin
-- straightening and lifting under the mouse. The functions are the kit's (PagleArtBoard's Board.lua:
-- P.Fire, transform, P.FireMotion, P.RingMotion, the pin hover and board.StartMotion), copied over the board's frames.
-- The board's loops run only while it shows: the driver settles an owner that no longer shows (a loop to its first
-- key), and the board starts them again when it shows again (adapter/Board.lua). With Core's Animations setting off,
-- everything draws in its settled state.

--- Whether things move: Core's Animations setting, `Pagle.IsAnimationsOn()` (announcements.md › Contracts; on by
--- default); the one seam the board reads it through, for what it decides beside the driver (a moment, a beat's sound).
---@return boolean
function ns.MotionOn()
	return Pagle.IsAnimationsOn() ~= false
end

-- The Campfire, in its moving layers (the kit's P.Fire): each stage is baked in layers that share the fire's 138 × 130
-- box: base (logs, stones, ember bed), the 365-day rays, three flame layers, the front stones over the flames' feet,
-- and a dead fire's embers; "none" (never lit) is one sprite. Every layer sits at the same point, stacked by sublevel.
local LAYERS = {
	none = { "" },
	out = { "-base", "-embers", "-front" },
	["365"] = { "-base", "-rays", "-fl1", "-fl2", "-fl3", "-front" },
}
local FLAMES =
	{ ["-fl1"] = { 1.4, "alternate" }, ["-fl2"] = { 1.1, "alternate-reverse" }, ["-fl3"] = { 0.9, "alternate" } }
-- Each layer's sublevel, so they stack as the canvas draws them whichever stage shows.
local SUBLEVELS = { [""] = 1, ["-base"] = 1, ["-rays"] = 2, ["-embers"] = 2, ["-fl1"] = 3, ["-fl2"] = 4, ["-fl3"] = 5 }
SUBLEVELS["-front"] = 6

--- The Campfire's layers on the ledge: where its box sits, and a texture per layer, shown as its stage needs.
---@class TackleBoardFire
---@field parent Frame
---@field x number
---@field y number
---@field stage string?
---@field layers table<string, TackleSprite>   -- by suffix, the stage's own only
---@field textures table<string, TackleSprite> -- every layer made so far, by suffix
---@field pop number?                          -- the flames' scale over their flicker, while the fire steps up or dies

---@class TackleFireLayer: TackleSprite
---@field w0 number?   -- its size at rest, for the flicker
---@field h0 number?

--- The Campfire's layers on `parent`, its box's top left at `x`, `y` (y down), shown by ns.SetBoardFire.
---@param parent Frame
---@param x number
---@param y number
---@return TackleBoardFire
function ns.NewBoardFire(parent, x, y)
	return { parent = parent, x = x, y = y, layers = {}, textures = {} }
end

--- Shows the Campfire's `stage` ("none", "3", "7", "30", "100", "365" or "out"), its layers at rest.
---@param fire TackleBoardFire
---@param stage string
function ns.SetBoardFire(fire, stage)
	local textures = fire.textures
	for _, texture in pairs(textures) do
		texture:Hide()
	end
	fire.layers, fire.stage = {}, stage
	for _, suffix in ipairs(LAYERS[stage] or { "-base", "-fl1", "-fl2", "-fl3", "-front" }) do
		local texture = textures[suffix]
		if not texture then
			texture = ns.ArtSprite(fire.parent, "Fire", "fire-" .. stage .. suffix, "ARTWORK", SUBLEVELS[suffix])
			textures[suffix] = texture
		end
		ns.SetSprite(texture, "Fire", "fire-" .. stage .. suffix)
		local layer = texture --[[@as TackleFireLayer]]
		layer.w0, layer.h0 = nil, nil
		if texture.SetRotation then
			texture:SetRotation(0)
		end
		texture:SetAlpha(1)
		ns.PlaceSprite(texture, fire.parent, fire.x, fire.y)
		texture:Show()
		fire.layers[suffix] = texture
	end
end

-- Scale (sx, sy) and turn (deg, CCW as SetRotation) a placed sprite about the point (ox, oy) of its design box.
-- The turn waits on the papers' lean (profile.lean), the board's one SetRotation switch (adapter/BoardArt.lua).
local function transform(t, rel, x, y, ox, oy, sx, sy, deg)
	local b = t.box
	t.w0 = t.w0 or t:GetWidth()
	t.h0 = t.h0 or t:GetHeight()
	local Ox, Oy = x + ox, y + oy
	local cx = x - b[1] + t.w0 / 2
	local cy = y - b[2] + t.h0 / 2 -- centre at rest
	cx, cy = Ox + (cx - Ox) * sx, Oy + (cy - Oy) * sy -- scaled about O
	local a = ns.Leans() and math.rad(deg) or 0
	local dx, dy = cx - Ox, cy - Oy -- turned about O (y grows down)
	cx, cy = Ox + dx * math.cos(a) + dy * math.sin(a), Oy - dx * math.sin(a) + dy * math.cos(a)
	t:SetSize(t.w0 * sx, t.h0 * sy)
	if t.SetRotation then
		t:SetRotation(a)
	end
	t:ClearAllPoints()
	t:SetPoint("CENTER", rel, "TOPLEFT", cx, -cy)
end

--- The canvas's motion for the fire: t-flick on each flame layer (scale 1,1 skewX -2deg to scale .94,1.06 skewX 2.5deg,
--- ease-in-out, 1.4 / 1.1 / 0.9 s, alternating; the origin is the flames' foot, 80,116 of the 160 x 150 drawing =
--- 69,100.4 of the box). The client has no skew, so the lean is a turn about the same foot. t-spin turns the 365-day
--- rays once in 40 s about 80,70 (69,60.7); t-ember breathes a dead fire's embers.
---@param owner Frame
---@param fire TackleBoardFire
function ns.FireMotion(owner, fire)
	local anims = {}
	for suffix, spec in pairs(FLAMES) do
		local t = fire.layers[suffix]
		if t then
			anims[#anims + 1] = {
				dur = spec[1],
				ease = Pagle.EASE.inOut,
				iter = "infinite",
				dir = spec[2],
				keys = { { 0, { 1, 1, -2 } }, { 1, { 0.94, 1.06, 2.5 } } },
				apply = function(v)
					local k = fire.pop or 1 -- the flames rising as the fire steps up, sinking as it goes out
					transform(t, fire.parent, fire.x, fire.y, 69, 100.4, v[1] * k, v[2] * k, v[3])
				end,
			}
		end
	end
	local rays = fire.layers["-rays"]
	if rays then
		anims[#anims + 1] = {
			dur = 40,
			ease = Pagle.EASE.linear,
			iter = "infinite",
			keys = { { 0, { 0 } }, { 1, { -360 } } },
			apply = function(v)
				transform(rays, fire.parent, fire.x, fire.y, 69, 60.7, 1, 1, v[1])
			end,
		}
	end
	local emb = fire.layers["-embers"]
	if emb then
		anims[#anims + 1] = {
			dur = 2.4,
			ease = Pagle.EASE.inOut,
			iter = "infinite",
			dir = "alternate",
			keys = { { 0, { 0.55 } }, { 1, { 1 } } },
			apply = function(v)
				emb:SetAlpha(v[1])
			end,
		}
	end
	Pagle.Animate(owner, anims)
end

--- The ring round a pin opened from the tracker (canvas t-ring: opacity .4 to 1, 1 s ease-in-out, twice, alternate;
--- then it stays lit).
---@param owner Frame
---@param r Texture
function ns.RingMotion(owner, r)
	Pagle.Animate(owner, {
		{
			dur = 1,
			ease = Pagle.EASE.inOut,
			iter = 2,
			dir = "alternate",
			keys = { { 0, { 0.4 } }, { 1, { 1 } } },
			apply = function(v)
				r:SetAlpha(v[1])
			end,
		},
	}, function()
		r:SetAlpha(1)
	end)
end

--- A pin's hover (canvas .t-pin:hover): its paper turns to `lean` and the pin lifts `lift` units, over 0.18 s ease-out,
--- from wherever it is now; the words stay straight throughout.
---@param slip Frame the pin's paper frame, anchored over its slot
---@param paper TackleSprite
---@param lean number
---@param lift number
function ns.PinHover(slip, paper, lean, lift)
	local pin = slip --[[@as { leanNow: number?, lift: number? }]]
	local function set(v)
		pin.leanNow, pin.lift = v[1], v[2]
		ns.LeanSprite(paper, slip, 0, 0, v[1])
		local slot = slip:GetParent()
		slip:ClearAllPoints()
		slip:SetPoint("TOPLEFT", slot, "TOPLEFT", 0, v[2])
		slip:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 0, v[2])
	end
	Pagle.StopMotion(slip)
	Pagle.Animate(slip, {
		{
			dur = 0.18,
			ease = Pagle.EASE.out,
			keys = { { 0, { pin.leanNow or lean, pin.lift or 0 } }, { 1, { lean, lift } } },
			apply = set,
		},
	})
end

-- The fire's light on the cork (canvas t-glow: .9, 1 at 30%, .78 at 55%, .95 at 75%, 3.2 s ease-in-out), times its
-- base: faint on an unstarted board, by the Campfire's brightness while it burns.
local GLOW_KEYS = { { 0, { 0.9 } }, { 0.3, { 1 } }, { 0.55, { 0.78 } }, { 0.75, { 0.95 } }, { 1, { 0.9 } } }

--- What the board moves now (the kit's board.StartMotion): the Campfire's flames, rays or embers and the glow on the
--- cork, from its frame's `fire` (the ledge's, once drawn) and `glow`, at `base` alpha (nil: the glow is hidden). It
--- starts them again only when something it moves changed, or `restart`, so a redraw doesn't jolt the flicker.
---@param frame TackleBoardFrame
---@param fire TackleBoardFire?
---@param base number?
---@param restart boolean?
function ns.BoardMotion(frame, fire, base, restart)
	local on = ns.MotionOn()
	local key = table.concat({
		tostring(on),
		tostring(ns.Leans()),
		fire and fire.stage or "-",
		base and ("%.3f"):format(base) or "-",
	}, ":")
	local board = frame --[[@as { motionKey: string? }]]
	if not restart and board.motionKey == key then
		return
	end
	board.motionKey = key
	Pagle.StopMotion(frame)
	if fire then
		ns.FireMotion(frame, fire)
	end
	if base then
		Pagle.Animate(frame, {
			{
				dur = 3.2,
				ease = Pagle.EASE.inOut,
				iter = "infinite",
				keys = GLOW_KEYS,
				apply = function(v)
					-- glowBoost: the light flaring as the fire steps up (adapter/BoardChanges.lua)
					frame.glow:SetAlpha(v[1] * base * (frame.glowBoost or 1))
				end,
			},
		})
	end
end
