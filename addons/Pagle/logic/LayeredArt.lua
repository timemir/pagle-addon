---@class PagleNS
local ns = select(2, ...)

-- Layered art (announcements.md › ANN-R82, ANN-R83; ledger.md › LED-R154): a stack of sprites from one atlas, each at
-- its box, on the host its art puts it on, with its motion, the CSS keyframes of the kit that drew it. Core's one
-- renderer for everything drawn so: the composed toast styles (adapter/ToastLayers.lua) and the Prestige frames
-- (logic/PrestigeFrames.lua, as well art: layers round a well and a label); a layered piece on a host of its own (a
-- Legend crest) draws its slots with ns.CommitLayerSlot and moves them with ns.LayerAnimations. It only calls methods
-- on the regions it is handed and plays its motion on the motion player it is handed, so FakePagle builds the real
-- thing over a Module's client too.
--
--   local art = ns.NewLayeredArt({ anchor = frame, hosts = { back = { frame = frame, layer = "BORDER" } },
--       owner = frame, motion = { animate = ns.Animate, stop = ns.StopMotion, isOn = ns.MotionOn } })
--   art:Draw(atlas, layers, { scale = 0.65 })  -- each layer at its box × scale, resting (ns.LayerRests)
--   art:Play(token, key, delay)                 -- its layers' motion, looping, until Stop or its owner hides
--   art:Stop()  art:Clear()

--- A box in a kit's units: its top left from the art's top left (y down), and its size.
---@class PagleArtBox
---@field x number
---@field y number
---@field w number
---@field h number

--- A layer's motion: its CSS animation, one track per property it moves (logic/Motion.lua's keys, each { at, ... }).
---@class PagleArtMotion
---@field keyframes string            -- the canvas's keyframes' name
---@field dur number
---@field ease string
---@field delay? number
---@field loop boolean                -- the canvas's; the art's `once` plays some once in game
---@field origin { x: number, y: number }
---@field window? PagleArtBox         -- a sweep's: the part of the art its strip scrolls through
---@field alpha? number[][]           -- { at, alpha }
---@field transform? number[][]       -- { at, x, y, rotate (degrees, clockwise), sx, sy }
---@field scroll? number[][]          -- { at, u, v }: the strip's place in its window, as CSS's background-position

--- One sprite of a stack: its sprite in the atlas, its box, the host it draws on (a name the art's hosts give), its
--- blend, a sweep's mask (another sprite, at its own box) and its motion.
---@class PagleArtLayer: PagleArtBox
---@field name string
---@field sprite string
---@field host string
---@field blend? "ADD"|"MOD"
---@field mask? PagleArtBox|{ sprite: string }
---@field motion? PagleArtMotion

--- Draws texels as they are, unsnapped, so a sprite scaled by the UI doesn't shimmer (a client without the setting
--- draws as it does).
---@param texture Texture
---@return Texture
function ns.ArtCrisp(texture)
	if texture.SetSnapToPixelGrid then
		texture:SetSnapToPixelGrid(false)
		texture:SetTexelSnappingBias(0)
	end
	return texture
end

--- Where a layer's box is drawn under one moment of its transform (CSS's: translate, then rotate, skew and scale about
--- its origin, in UI units with y down): its centre, size, rotation for the client (radians, anticlockwise), whether
--- it is mirrored across, and, for a skewed one, the matrix the client can't draw with a rotation alone. The translation
--- is in the kit's units, drawn at `scale` (default 1) as the box is.
---@param box PagleArtBox
---@param origin { x: number, y: number }
---@param t number[]? { x, y, rotate (degrees clockwise), sx, sy, kx?, ky? (skew, degrees) }, none for none
---@param scale number?
---@return { cx: number, cy: number, w: number, h: number, rotation: number, mirrored: boolean, skewed: boolean, matrix: number[] }
function ns.TransformLayerBox(box, origin, t, scale)
	local tx, ty, degrees, sx, sy, kx, ky = 0, 0, 0, 1, 1, 0, 0
	if t then
		tx, ty, degrees, sx, sy, kx, ky = t[1], t[2], t[3], t[4], t[5], t[6] or 0, t[7] or 0
	end
	scale = scale or 1
	local dx, dy = box.x + box.w / 2 - origin.x, box.y + box.h / 2 - origin.y
	local r = math.rad(degrees)
	local c, s = math.cos(r), math.sin(r)
	-- The matrix R . K . S of rotate, skew and scale, as CSS's (a, b, c, d): x' = a x + c y, y' = b x + d y.
	local ka, kb, kc, kd = sx, math.tan(math.rad(ky)) * sx, math.tan(math.rad(kx)) * sy, sy
	local a, b = c * ka - s * kb, s * ka + c * kb
	local cc, d = c * kc - s * kd, s * kc + c * kd
	return {
		cx = origin.x + tx * scale + a * dx + cc * dy,
		cy = origin.y + ty * scale + b * dx + d * dy,
		w = box.w * math.abs(sx),
		h = box.h * math.abs(sy),
		rotation = -r,
		mirrored = sx < 0,
		skewed = kx ~= 0 or ky ~= 0,
		matrix = { a, b, cc, d },
	}
end

--- The texture coordinates of a skewed layer's region: the region keeps the layer's size, centred where the matrix puts
--- the box, and each of its four corners shows the point of the sprite the matrix maps there (the client turns a
--- texture about its centre, but has no skew). A sprite with nothing past its edge shows nothing there: the art keeps
--- a margin round each sprite. Mirrors come with the matrix, so the coordinates are never flipped on top.
---@param placed { w: number, h: number, matrix: number[] } from TransformLayerBox
---@param box PagleArtBox the sprite's box, in the units of `placed`
---@param tc number[] the sprite's atlas coordinates: left, right, top, bottom
---@return number[] ULx, ULy, LLx, LLy, URx, URy, LRx, LRy for SetTexCoord
function ns.SkewedTexCoords(placed, box, tc)
	local a, b, cc, d = placed.matrix[1], placed.matrix[2], placed.matrix[3], placed.matrix[4]
	local det = a * d - cc * b
	if math.abs(det) < 1e-9 then
		return { tc[1], tc[3], tc[1], tc[4], tc[2], tc[3], tc[2], tc[4] }
	end
	local u0, v0 = (tc[1] + tc[2]) / 2, (tc[3] + tc[4]) / 2
	local du, dv = (tc[2] - tc[1]) / box.w, (tc[4] - tc[3]) / box.h
	-- The sprite point a screen offset (qx, qy) from the region's centre shows: the matrix's inverse.
	local function at(qx, qy)
		local px, py = (d * qx - cc * qy) / det, (-b * qx + a * qy) / det
		return u0 + px * du, v0 + py * dv
	end
	local hw, hh = placed.w / 2, placed.h / 2
	local ulx, uly = at(-hw, -hh)
	local llx, lly = at(-hw, hh)
	local urx, ury = at(hw, -hh)
	local lrx, lry = at(hw, hh)
	return { ulx, uly, llx, lly, urx, ury, lrx, lry }
end

--- The share of a sweep's strip seen through its window at a scroll (CSS's background-position: 0 shows the strip's
--- start, 1 its end), as left, right, top and bottom from 0 to 1 across the strip: the window is `ku` of its width and
--- `kv` of its height.
---@param ku number
---@param kv number
---@param u number
---@param v number
---@return number left
---@return number right
---@return number top
---@return number bottom
function ns.ScrollWindow(ku, kv, u, v)
	local left, top = u * (1 - ku), v * (1 - kv)
	return left, left + ku, top, top + kv
end

-- The kit's easings by name, looked up as a motion is built: logic/Motion.lua's.
local function easing(name)
	if name == "steps1" then
		return ns.Steps(1)
	end
	return ns.EASE[name] or ns.EASE.ease
end

--- Whether a layer shows in its resting frame (Animations off, or a preview standing still): as the kit drew it,
--- unmoved and opaque, unless it only flashes (its motion starts unseen: lightning, a ripple, a puff, a bubble) or is a
--- sweep's band of light.
---@param layer PagleArtLayer
---@return boolean
function ns.LayerRests(layer)
	local motion = layer.motion
	if not motion then
		return true
	end
	return motion.scroll == nil and not (motion.alpha and motion.alpha[1][2] == 0)
end

--- A layer's motion as animations for the motion player (logic/Motion.lua), one per property it moves, as CSS
--- animates each on its own keyframes: "alpha" ({ alpha }), "transform" ({ x, y, rotate, sx, sy }) and "scroll"
--- ({ u, v }), each `apply(kind, values)`. Each starts `delay` seconds in (its art landing), holding its first frame
--- till then, and loops for as long as its owner plays, but one played `once` plays once and holds its end.
---@param motion PagleArtMotion
---@param delay number
---@param apply fun(kind: string, values: number[])
---@param once boolean?
---@return PagleAnimation[]
function ns.LayerAnimations(motion, delay, apply, once)
	local animations = {}
	for _, kind in ipairs({ "alpha", "transform", "scroll" }) do
		local track = motion[kind]
		if track then
			local keys = {}
			for i, key in ipairs(track) do
				keys[i] = { key[1], { unpack(key, 2) } }
			end
			animations[#animations + 1] = {
				dur = motion.dur,
				delay = delay + (motion.delay or 0),
				ease = easing(motion.ease),
				iter = (motion.loop and not once) and "infinite" or 1,
				keys = keys,
				apply = function(values)
					apply(kind, values)
				end,
			}
		end
	end
	return animations
end

--- A sprite of a stack as drawn: its texture (and a sweep's mask), its layer, its box from the art's anchor (a sweep's
--- window), the origin it moves about, the scale it is drawn at, its sprite's texture coordinates, a sweep's window
--- over its strip and where its motion has it now.
---@class PagleLayerSlot
---@field texture Texture
---@field mask MaskTexture?
---@field layer PagleArtLayer
---@field box PagleArtBox
---@field origin { x: number, y: number }
---@field scale number
---@field tc number[]
---@field window number[]?
---@field state table<string, number[]>

--- Where a host's sprites are made: on `frame`, in its draw layer `layer`, the host's sprites one sublevel apart in
--- the art's order.
---@class PagleArtHost
---@field frame Frame
---@field layer DrawLayer

--- The motion player a stack plays on: Core's (adapter/Motion.lua) or FakePagle's, and the Animations setting.
---@class PagleArtMotionPlayer
---@field animate fun(owner: PagleMotionOwner, animations: PagleAnimation[], onDone: fun()?)
---@field stop fun(owner: PagleMotionOwner)
---@field isOn fun(): boolean

---@class PagleLayeredArtOptions
---@field anchor Region the boxes are measured from its top left
---@field hosts table<string, PagleArtHost>
---@field owner PagleMotionOwner what its motion plays on: hidden, it settles and stops
---@field motion PagleArtMotionPlayer
---@field once table<string, boolean>? keyframes, by name, that play once in game though the canvas loops them

--- How a stack is drawn this time: at `scale` of its kit's units (default 1); `fit`, a box moved to where it goes
--- (a toast's rung fitted to a taller page; `mask` for a sweep's mask), in the kit's units; and `custom`, a layer its
--- caller draws itself (the Nod's sliced body), which still takes its place in its host's order.
---@class PagleArtPlacing
---@field scale number?
---@field fit (fun(box: PagleArtBox, layer: PagleArtLayer, mask: boolean?): PagleArtBox)?
---@field custom (fun(layer: PagleArtLayer): boolean)?

---@class PagleLayeredArt
---@field anchor Region
---@field hosts table<string, PagleArtHost>
---@field owner PagleMotionOwner
---@field motion PagleArtMotionPlayer
---@field once table<string, boolean>
---@field pools table<string, PagleLayerSlot[]>
---@field sweeps table<string, PagleLayerSlot[]>
---@field active PagleLayerSlot[] what it drew last, in the art's order
---@field playing any what it plays for (its caller's token), nil while still
---@field playingKey string?
local LayeredArt = {}
LayeredArt.__index = LayeredArt

--- A stack drawn on `options.hosts`, measured from `options.anchor`, its motion on `options.owner`. Nothing is drawn
--- until Draw.
---@param options PagleLayeredArtOptions
---@return PagleLayeredArt
function ns.NewLayeredArt(options)
	return setmetatable({
		anchor = options.anchor,
		hosts = options.hosts,
		owner = options.owner,
		motion = options.motion,
		once = options.once or {},
		pools = {},
		sweeps = {},
		active = {},
	}, LayeredArt)
end

-- The slot for the `i`th layer on a host, made on first use: a sweep's has its mask.
---@param art PagleLayeredArt
---@param hostName string
---@param i integer
---@param masked boolean
---@return PagleLayerSlot
local function slotOf(art, hostName, i, masked)
	local pools = masked and art.sweeps or art.pools
	pools[hostName] = pools[hostName] or {}
	local pool = pools[hostName]
	local slot = pool[i]
	if not slot then
		local host = assert(art.hosts[hostName], "the art has no host " .. tostring(hostName))
		local parent = host.frame
		local texture = ns.ArtCrisp(parent:CreateTexture(nil, host.layer, nil, math.min(7, i - 7)))
		local made = { texture = texture }
		slot = made --[[@as PagleLayerSlot]]
		if masked then
			slot.mask = parent:CreateMaskTexture()
			texture:AddMaskTexture(slot.mask)
		end
		pool[i] = slot
	end
	return slot
end

--- A sprite's texture coordinates in its atlas: left, right, top, bottom.
---@param atlas PagleAtlas
---@param name string
---@return number[]
function ns.SpriteCoords(atlas, name)
	local sprite = atlas.sprites[name]
	return {
		sprite.x / atlas.width,
		(sprite.x + sprite.w) / atlas.width,
		sprite.y / atlas.height,
		(sprite.y + sprite.h) / atlas.height,
	}
end

---@param box PagleArtBox
---@param scale number
---@return PagleArtBox
local function scaled(box, scale)
	return { x = box.x * scale, y = box.y * scale, w = box.w * scale, h = box.h * scale }
end

--- Draws a slot where its motion has it now (its resting frame with none): a sweep's strip seen through its window at
--- its scroll, any other sprite moved, turned, scaled or mirrored about its origin, at its alpha. Its box and origin
--- are from `anchor`'s top left.
---@param slot PagleLayerSlot
---@param anchor Region
local function commit(slot, anchor)
	local texture, state, box, tc = slot.texture, slot.state, slot.box, slot.tc
	local alpha = state.alpha and math.max(0, math.min(1, state.alpha[1])) or 1
	texture:SetAlpha(alpha)
	if slot.window then
		local scroll = state.scroll or { 0, 0 }
		local left, right, top, bottom = ns.ScrollWindow(slot.window[1], slot.window[2], scroll[1], scroll[2])
		local du, dv = tc[2] - tc[1], tc[4] - tc[3]
		texture:SetTexCoord(tc[1] + du * left, tc[1] + du * right, tc[3] + dv * top, tc[3] + dv * bottom)
		texture:ClearAllPoints()
		texture:SetPoint("TOPLEFT", anchor, "TOPLEFT", box.x, -box.y)
		texture:SetSize(box.w, box.h)
		return
	end
	local placed = ns.TransformLayerBox(box, slot.origin, state.transform, slot.scale)
	texture:SetSize(math.max(0.01, placed.w), math.max(0.01, placed.h))
	texture:ClearAllPoints()
	texture:SetPoint("CENTER", anchor, "TOPLEFT", placed.cx, -placed.cy)
	if placed.skewed then
		-- The client has no skew, so the region's four corners are given the sprite's points the matrix maps there.
		texture:SetRotation(0)
		texture:SetTexCoord(unpack(ns.SkewedTexCoords(placed, box, tc)))
		return
	end
	texture:SetRotation(placed.rotation)
	if placed.mirrored then
		texture:SetTexCoord(tc[2], tc[1], tc[3], tc[4])
	else
		texture:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
	end
end
ns.CommitLayerSlot = commit

--- Draws `layers` from `atlas` in their resting frame: each sprite at its box (fitted, then scaled, as `placing`
--- has it) on its host, in the art's order, a sweep's strip under its mask; one that only flashes, and a sweep,
--- unseen (ns.LayerRests). What it drew before and doesn't now is hidden. Its motion is Play's.
---@param atlas PagleAtlas
---@param layers PagleArtLayer[]
---@param placing PagleArtPlacing?
function LayeredArt:Draw(atlas, layers, placing)
	placing = placing or {}
	local scale = placing.scale or 1
	local fit = placing.fit or function(box)
		return box
	end
	local used, counts = {}, {}
	self.active = {}
	for _, layer in ipairs(layers) do
		local hostName = layer.host
		counts[hostName] = (counts[hostName] or 0) + 1
		if not (placing.custom and placing.custom(layer)) then
			local slot = slotOf(self, hostName, counts[hostName], layer.mask ~= nil)
			used[slot] = true
			local motion = layer.motion
			local window = motion and motion.window
			local from = window or layer
			local box = fit(from, layer)
			slot.layer = layer
			slot.tc = ns.SpriteCoords(atlas, layer.sprite)
			slot.scale = scale
			slot.box = scaled(box, scale)
			slot.window = window and { window.w / layer.w, window.h / layer.h } or nil
			local origin = motion and motion.origin or { x = from.x + from.w / 2, y = from.y + from.h / 2 }
			slot.origin = { x = (origin.x + box.x - from.x) * scale, y = (origin.y + box.y - from.y) * scale }
			slot.state = {}
			local texture = slot.texture
			texture:SetTexture(atlas.file)
			texture:SetBlendMode(layer.blend or "BLEND")
			texture:SetDesaturated(false)
			texture:SetVertexColor(1, 1, 1)
			if slot.mask then
				local mask = layer.mask --[[@as PagleArtBox|{ sprite: string }]]
				local at = scaled(fit(mask, layer, true), scale)
				local mc = ns.SpriteCoords(atlas, mask.sprite)
				slot.mask:SetTexture(atlas.file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
				slot.mask:SetTexCoord(mc[1], mc[2], mc[3], mc[4])
				slot.mask:ClearAllPoints()
				slot.mask:SetPoint("TOPLEFT", self.anchor, "TOPLEFT", at.x, -at.y)
				slot.mask:SetSize(at.w, at.h)
			end
			commit(slot, self.anchor)
			texture:SetShown(ns.LayerRests(layer))
			self.active[#self.active + 1] = slot
		end
	end
	for _, pools in ipairs({ self.pools, self.sweeps }) do
		for _, pool in pairs(pools) do
			for _, slot in pairs(pool) do
				if not used[slot] then
					slot.texture:Hide()
				end
			end
		end
	end
end

--- Plays the drawn layers' motion for `token` (whatever its caller plays it for: a toast's display, a frame's rank),
--- `delay` seconds from now, each property on its own keyframes (ns.LayerAnimations), looping while its owner shows,
--- with `extra` animations beside them (a toast's moving stamps). Asked again for the same `token` and `key` while it
--- plays, it carries on. With Animations off it stays still. Its owner hidden, the player settles it, and then it is
--- still again: the next Play starts it afresh.
---@param token any
---@param key string
---@param delay number
---@param extra PagleAnimation[]?
function LayeredArt:Play(token, key, delay, extra)
	if self.playing == token and self.playingKey == key then
		return
	end
	self:Stop()
	if not self.motion.isOn() then
		return
	end
	self.playing, self.playingKey = token, key
	local animations = {}
	local function add(list)
		for _, animation in ipairs(list) do
			animations[#animations + 1] = animation
		end
	end
	local anchor = self.anchor
	for _, slot in ipairs(self.active) do
		local motion = slot.layer.motion
		if motion then
			add(ns.LayerAnimations(motion, delay, function(kind, values)
				slot.state[kind] = values
				slot.texture:Show()
				commit(slot, anchor)
			end, self.once[motion.keyframes]))
		end
	end
	add(extra or {})
	if #animations > 0 then
		local playing, owner = self.playing, self.owner
		-- Settled because its owner hid (not because a motion played once ended): still again.
		self.motion.animate(owner, animations, function()
			local hidden = owner.IsVisible ~= nil and not owner:IsVisible()
			if hidden and self.playing == playing then
				self.playing, self.playingKey = nil, nil
			end
		end)
	end
end

--- Stops its motion where it is.
function LayeredArt:Stop()
	self.motion.stop(self.owner)
	self.playing, self.playingKey = nil, nil
end

--- Stops its motion and hides every sprite it drew.
function LayeredArt:Clear()
	self:Stop()
	self.active = {}
	for _, pools in ipairs({ self.pools, self.sweeps }) do
		for _, pool in pairs(pools) do
			for _, slot in pairs(pool) do
				slot.texture:Hide()
			end
		end
	end
end

-- ---------------------------------------------------------------- well art

--- Layered art round a well (ledger.md › LED-R154; announcements.md › ANN-R83): a Prestige frame round the Angler's
--- likeness, a Legend crest round its item's icon. Its art is a kit's box of layers (ns.PRESTIGE_BOX), "back" ones
--- behind the well and "front" ones over it, its well a circle in the box (ns.PRESTIGE_WELL), its label the words on
--- its plaque in the kit's ink, and the point a crest is pinned at.
---@class PagleWellArtSpec
---@field atlas string             -- ns.ATLASES' name
---@field layers PagleArtLayer[]   -- each on host "back" or "front"
---@field label? { top: number, ink: PagleToastInk } -- the words' top, in the box, and their ink; none, no words
---@field pin? { x: number, y: number, w: number } -- where a crest's shield is pinned, centred, and its width

--- What its plaque reads: the words, then `stars` star stamps and "+`more`" after them.
---@class PagleWellArtLabel
---@field text string
---@field stars integer
---@field more integer

--- What well art needs from its client: a frame made on a parent, a label put in an ink at a size (adapter/Art.lua's
--- ns.SetInkFont), and the motion player.
---@class PagleWellArtClient
---@field createFrame fun(parent: Frame): Frame
---@field setInk fun(fontString: FontString, ink: PagleToastInk, size: number)
---@field motion PagleArtMotionPlayer

--- Well art as drawn: a frame the size of its box at its scale, its layers, its well (a texture its caller fills: the
--- player's portrait, an icon) over a dark disc, both masked round, and its label with its stars.
---@class PagleWellArt: Frame
---@field art PagleLayeredArt
---@field well Texture
---@field disc Texture
---@field label FontString
---@field more FontString
---@field stars Texture[]
---@field spec PagleWellArtSpec?
---@field scale number
---@field key string?
---@field DrawArt fun(self: PagleWellArt, spec: PagleWellArtSpec, scale: number, label: PagleWellArtLabel?, key: string?)
---@field Play fun(self: PagleWellArt, delay: number?)
---@field Stop fun(self: PagleWellArt)
---@field GetWell fun(self: PagleWellArt): Texture
---@field GetPin fun(self: PagleWellArt): number?, number?, number?
---@field IsMoving fun(self: PagleWellArt): boolean

-- The mask that rounds the well, the star stamped on a label (the client's own gold star), and the well's dark disc,
-- as the kit draws the well before the likeness fills it.
local ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local STAR = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"
local DISC = { 40 / 255, 70 / 255, 74 / 255 }
-- The room before a label's stars and before its "+n", and from one star to the next, of the label's size.
local STAR_GAP, STAR_STEP = 0.3, 1.05

-- Writes a label on well art's plaque, centred across its box at the label's top: its words, its stars and "+n".
---@param self PagleWellArt
---@param client PagleWellArtClient
---@param spec PagleWellArtSpec
---@param label PagleWellArtLabel?
---@param scale number
local function drawLabel(self, client, spec, label, scale)
	local ink = spec.label and spec.label.ink
	local shown = label ~= nil and ink ~= nil
	local stars = label and ink and label.stars or 0
	local more = label and ink and label.more or 0
	self.label:SetShown(shown)
	self.more:SetShown(more > 0)
	for i = 1, math.max(stars, #self.stars) do
		local star = self.stars[i]
		if not star then
			star = ns.ArtCrisp(self:CreateTexture(nil, "OVERLAY"))
			star:SetTexture(STAR)
			self.stars[i] = star
		end
		star:SetShown(i <= stars)
	end
	if not label or not ink then
		return
	end
	local size = ink.size * scale
	client.setInk(self.label, ink, size)
	self.label:SetText(ink.caps and ns.Capitals(label.text) or label.text)
	local width = self.label:GetStringWidth()
	if stars > 0 then
		width = width + size * STAR_GAP + stars * size * STAR_STEP
	end
	if more > 0 then
		client.setInk(self.more, ink, size)
		self.more:SetText(("+%d"):format(more))
		width = width + size * STAR_GAP + self.more:GetStringWidth()
	end
	local x = (ns.PRESTIGE_BOX.w * scale - width) / 2
	local top = -spec.label.top * scale
	self.label:ClearAllPoints()
	self.label:SetPoint("TOPLEFT", self, "TOPLEFT", x, top)
	x = x + self.label:GetStringWidth()
	if stars > 0 then
		x = x + size * STAR_GAP
		for i = 1, stars do
			local star = self.stars[i]
			star:SetSize(size, size)
			star:ClearAllPoints()
			star:SetPoint("TOPLEFT", self, "TOPLEFT", x, top)
			x = x + size * STAR_STEP
		end
	end
	self.more:ClearAllPoints()
	self.more:SetPoint("TOPLEFT", self, "TOPLEFT", x + size * STAR_GAP, top)
end

--- Makes well art over a client (Core's adapter, or FakePagle's over a Module's client): `make(parent)` returns a
--- PagleWellArt with nothing drawn until DrawArt.
---@param client PagleWellArtClient
---@return fun(parent: Frame): PagleWellArt
function ns.WellArtMaker(client)
	return function(parent)
		local self = client.createFrame(parent) --[[@as PagleWellArt]]
		self.art = ns.NewLayeredArt({
			anchor = self,
			hosts = { back = { frame = self, layer = "BORDER" }, front = { frame = self, layer = "ARTWORK" } },
			owner = self,
			motion = client.motion,
		})
		-- The well over the back layers and under the frame, whose layers start at ARTWORK's sublevel -6.
		self.disc = self:CreateTexture(nil, "ARTWORK", nil, -8)
		self.disc:SetColorTexture(DISC[1], DISC[2], DISC[3], 1)
		self.well = ns.ArtCrisp(self:CreateTexture(nil, "ARTWORK", nil, -7))
		local mask = self:CreateMaskTexture()
		mask:SetTexture(ROUND, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		mask:SetAllPoints(self.well)
		self.well:AddMaskTexture(mask)
		self.disc:AddMaskTexture(mask)
		self.label = self:CreateFontString(nil, "OVERLAY")
		self.label:SetWordWrap(false)
		self.more = self:CreateFontString(nil, "OVERLAY")
		self.more:SetWordWrap(false)
		self.stars = {}
		self.scale = 1

		-- Draws `spec` at `scale` of its box, resting (Play moves it), its plaque reading `label` (none, no words),
		-- and sizes itself to the box. Drawn as another `key` (its art's name) than before, what played stops.
		function self.DrawArt(_, spec, scale, label, key)
			if key ~= self.key then
				self.art:Stop()
			end
			self.spec, self.scale, self.key = spec, scale, key
			local box, well = ns.PRESTIGE_BOX, ns.PRESTIGE_WELL
			self:SetSize(box.w * scale, box.h * scale)
			self.art:Draw(ns.ATLASES[spec.atlas], spec.layers, { scale = scale })
			for _, texture in ipairs({ self.disc, self.well }) do
				texture:SetSize(2 * well.r * scale, 2 * well.r * scale)
				texture:ClearAllPoints()
				texture:SetPoint("CENTER", self, "TOPLEFT", well.cx * scale, -well.cy * scale)
			end
			drawLabel(self, client, spec, label, scale)
		end

		-- Its motion from `delay` seconds on (default 0), looping while it shows and Animations are on (SET-R30);
		-- asked again for the same art, it carries on. Hidden, it stops; its next Play starts it again.
		function self.Play(_, delay)
			self.art:Play(self, self.key or "", delay or 0)
		end

		-- Stops its motion where it is.
		function self.Stop()
			self.art:Stop()
		end

		-- The texture in its well, for its caller to fill (SetPortraitTexture, an icon).
		function self.GetWell()
			return self.well
		end

		-- Where a crest is pinned on it, from its top left in its units (y down), and the shield's width; none for
		-- art without a pin.
		function self.GetPin()
			local pin = self.spec and self.spec.pin
			if not pin then
				return nil, nil, nil
			end
			return pin.x * self.scale, pin.y * self.scale, pin.w * self.scale
		end

		-- Whether any of its layers move.
		function self.IsMoving()
			for _, layer in ipairs(self.spec and self.spec.layers or {}) do
				if layer.motion then
					return true
				end
			end
			return false
		end

		return self
	end
end
