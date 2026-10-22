---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- A composed toast style's layers on the client (announcements.md › Toast styles, ANN-R82): the round two kit's
-- sprites stacked on a toast's or Nod's frame from its art (data/ToastStyleArt2.lua), each on the host the art puts it
-- on, under the medallion's icon, over it or over the words; its stamp plates; and its motion, played on the motion
-- driver (adapter/Motion.lua) once the toast lands and stopped when it goes. adapter/Announcements.lua lays out the
-- medallion, words, stamps and Coins round them. Nothing here is drawn for the round one styles.

-- When a toast has landed, the motion's start (ANN-R82): a toast's page once it has slid in (0.14 of its motion's
-- 7 s timeline, adapter/Announcements.lua), a Nod once it has faded in.
local LANDING = { toast = 0.98, nod = ns.SETTLE_SECONDS.nod }
-- The client's draw layer for each host's sprites: the body's under the medallion, the medallion's over its icon, and
-- their own frame's over the words.
local DRAW_LAYER = { under = "BORDER", front = "OVERLAY", over = "ARTWORK" }

--- One sprite of a composed rung as drawn: its texture (and a sweep's mask), its layer, its box on the page (a sweep's
--- window), the origin it moves about, its sprite's texture coordinates, a sweep's window over its strip and where its
--- motion has it now.
---@class PagleLayerSlot
---@field texture Texture
---@field mask MaskTexture?
---@field layer PagleToastLayer
---@field box PagleToastBox
---@field origin { x: number, y: number }
---@field tc number[]
---@field window number[]?
---@field state table<string, number[]>

--- A toast's or Nod's composed layers: the frame the under-sprites hang on (the toast's body, the Nod's frame), the
--- frame over its words, each host's textures by place, the Nod body's three slices, and what is drawn and playing.
---@class PagleToastLayers
---@field host Frame
---@field over Frame
---@field front Frame
---@field pools table<string, PagleLayerSlot[]>
---@field sweeps table<string, PagleLayerSlot[]>
---@field slices Texture[]?
---@field active PagleLayerSlot[]
---@field playing PagleDisplay?
---@field playingKey string?

--- A composed stamp as drawn: its art, its plate's width and its three slices.
---@class PagleLayeredStamp
---@field spec PagleToastLayer
---@field width number

-- A frame's layers, made the first time a composed style draws on it.
---@param frame PagleAnnouncementFrame
---@param host Frame
---@return PagleToastLayers
local function layersOf(frame, host)
	local layers = frame.toastLayers
	if not layers then
		local over = CreateFrame("Frame", nil, host)
		over:SetAllPoints(host)
		-- Over the words and what hangs on them: the stamps, their borders, the Coins.
		over:SetFrameLevel(frame.words:GetFrameLevel() + 4)
		layers = {
			host = host,
			over = over,
			front = frame.bezel --[[@as Frame]],
			pools = { under = {}, front = {}, over = {} },
			sweeps = { under = {}, front = {}, over = {} },
			active = {},
		}
		frame.toastLayers = layers
	end
	return layers
end

-- The slot for the `i`th layer on a host, made on first use: a sweep's has its mask.
---@param layers PagleToastLayers
---@param hostName string
---@param i integer
---@param masked boolean
---@return PagleLayerSlot
local function slotOf(layers, hostName, i, masked)
	local pool = masked and layers.sweeps[hostName] or layers.pools[hostName]
	local slot = pool[i]
	if not slot then
		local parent = hostName == "under" and layers.host or hostName == "front" and layers.front or layers.over
		local texture = ns.ArtCrisp(parent:CreateTexture(nil, DRAW_LAYER[hostName], nil, math.min(7, i - 7)))
		slot = { texture = texture } --[[@as PagleLayerSlot]]
		if masked then
			slot.mask = parent:CreateMaskTexture()
			texture:AddMaskTexture(slot.mask)
		end
		pool[i] = slot
	end
	return slot
end

-- A sprite's texture coordinates in its atlas: left, right, top, bottom.
---@param atlas PagleAtlas
---@param name string
---@return number[]
local function coordsOf(atlas, name)
	local sprite = atlas.sprites[name]
	return {
		sprite.x / atlas.width,
		(sprite.x + sprite.w) / atlas.width,
		sprite.y / atlas.height,
		(sprite.y + sprite.h) / atlas.height,
	}
end

-- Draws a slot where its motion has it now (its resting frame with none): a sweep's strip seen through its window at
-- its scroll, any other sprite moved, turned, scaled or mirrored about its origin, at its alpha.
---@param slot PagleLayerSlot
---@param anchor Frame
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
	local placed = ns.TransformToastBox(box, slot.origin, state.transform)
	texture:SetSize(math.max(0.01, placed.w), math.max(0.01, placed.h))
	texture:ClearAllPoints()
	texture:SetPoint("CENTER", anchor, "TOPLEFT", placed.cx, -placed.cy)
	texture:SetRotation(placed.rotation)
	if placed.mirrored then
		texture:SetTexCoord(tc[2], tc[1], tc[3], tc[4])
	else
		texture:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
	end
end

-- The Nod's body three-sliced to `width` (ANN-R82): `slice.left` (where its words start) and `slice.right` of it kept,
-- its middle stretched.
---@param layers PagleToastLayers
---@param atlas PagleAtlas
---@param layer PagleToastLayer
---@param rung PagleToastRung
---@param width number
local function sliceBody(layers, atlas, layer, rung, width)
	local slices = layers.slices
	if not slices then
		slices = {}
		for i = 1, 3 do
			slices[i] = ns.ArtCrisp(layers.host:CreateTexture(nil, DRAW_LAYER.under, nil, -8))
		end
		layers.slices = slices
	end
	local tc = coordsOf(atlas, layer.sprite)
	local left, right = rung.slice.left, rung.slice.right
	local right0 = layer.x + layer.w + width - rung.w
	local du = (tc[2] - tc[1]) / layer.w
	local cuts = {
		{ 0, left, layer.x },
		{ left, layer.w - right, layer.x + left },
		{ layer.w - right, layer.w, right0 - right },
	}
	for i, cut in ipairs(cuts) do
		local texture = slices[i]
		texture:SetTexture(atlas.file)
		texture:SetTexCoord(tc[1] + du * cut[1], tc[1] + du * cut[2], tc[3], tc[4])
		texture:ClearAllPoints()
		texture:SetPoint("TOPLEFT", layers.host, "TOPLEFT", cut[3], -layer.y)
		local span = i == 2 and math.max(0.01, right0 - right - layer.x - left) or (cut[2] - cut[1])
		texture:SetSize(span, layer.h)
		texture:Show()
	end
end

--- Draws a composed style's layers for `page` (a Nod's with none, `width` long) on `frame` in their resting frame
--- (ANN-R82): each sprite of its rung at its box fitted to the page (logic/ToastStyles.lua's ns.FitToastBox), on its
--- host, in the rung's order, a sweep's strip under its mask; one that only flashes, and a sweep, unseen. The page's
--- and Nod strip's art of the round one styles is the caller's to hide.
---@param frame PagleAnnouncementFrame
---@param host Frame the toast's body, or the Nod's frame
---@param style PagleToastStyle
---@param page PagleToastPage?
---@param width number? the Nod's
function ns.DrawToastLayers(frame, host, style, page, width)
	local layers = layersOf(frame, host)
	local rung = ns.ToastRungArt(style, page) --[[@as PagleToastRung]]
	local atlas = ns.ATLASES[style.art.atlas]
	local w, h = page and page.w or width or rung.w, page and page.h or rung.h
	local used, counts = {}, { under = 0, front = 0, over = 0 }
	layers.active = {}
	if layers.slices then
		for _, texture in ipairs(layers.slices) do
			texture:Hide()
		end
	end
	for _, layer in ipairs(rung.layers) do
		local hostName = layer.host
		counts[hostName] = counts[hostName] + 1
		if not page and layer.name == "body" and rung.slice then
			sliceBody(layers, atlas, layer, rung, w)
		else
			local slot = slotOf(layers, hostName, counts[hostName], layer.mask ~= nil)
			used[slot] = true
			local motion = layer.motion
			local window = motion and motion.window
			slot.layer = layer
			slot.tc = coordsOf(atlas, layer.sprite)
			slot.box = ns.FitToastBox(window or layer, rung, w, h, layer.name == "mback" or layer.name == "mfront")
			slot.window = window and { window.w / layer.w, window.h / layer.h } or nil
			local from = window or layer
			local origin = motion and motion.origin or { x = from.x + from.w / 2, y = from.y + from.h / 2 }
			slot.origin = { x = origin.x + slot.box.x - from.x, y = origin.y + slot.box.y - from.y }
			slot.state = {}
			local texture = slot.texture
			texture:SetTexture(atlas.file)
			texture:SetBlendMode(layer.blend or "BLEND")
			texture:SetDesaturated(false)
			texture:SetVertexColor(1, 1, 1)
			if slot.mask then
				local mask = layer.mask --[[@as PagleToastBox|{ sprite: string }]]
				local at = ns.FitToastBox(mask, rung, w, h)
				local mc = coordsOf(atlas, mask.sprite)
				slot.mask:SetTexture(atlas.file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
				slot.mask:SetTexCoord(mc[1], mc[2], mc[3], mc[4])
				slot.mask:ClearAllPoints()
				slot.mask:SetPoint("TOPLEFT", host, "TOPLEFT", at.x, -at.y)
				slot.mask:SetSize(at.w, at.h)
			end
			commit(slot, host)
			texture:SetShown(ns.ToastLayerRests(layer))
			layers.active[#layers.active + 1] = slot
		end
	end
	for _, pools in ipairs({ layers.pools, layers.sweeps }) do
		for _, pool in pairs(pools) do
			for _, slot in pairs(pool) do
				if not used[slot] then
					slot.texture:Hide()
				end
			end
		end
	end
end

--- Tints a composed Nod's medallion (its back and front) in `color`, greyed first so the colour shows true, as a
--- catch Nod's ring takes its rarity's (VAR-R26); with none, leaves it as drawn.
---@param frame PagleAnnouncementFrame
---@param color number[]?
function ns.TintToastMedallion(frame, color)
	if not color then
		return
	end
	for _, slot in ipairs(frame.toastLayers.active) do
		if slot.layer.name == "mfront" or slot.layer.name == "mback" then
			slot.texture:SetDesaturated(true)
			slot.texture:SetVertexColor(color[1], color[2], color[3])
		end
	end
end

--- Stops a frame's layers' motion where it is.
---@param frame PagleAnnouncementFrame
function ns.StopToastLayers(frame)
	local layers = frame.toastLayers
	if layers then
		ns.StopMotion(layers.over)
		layers.playing, layers.playingKey = nil, nil
	end
end

--- Takes a composed style's layers off a frame a round one style draws on now: its motion stopped and its sprites
--- hidden.
---@param frame PagleAnnouncementFrame
function ns.ClearToastLayers(frame)
	local layers = frame.toastLayers
	if not layers then
		return
	end
	ns.StopToastLayers(frame)
	layers.active = {}
	for _, pools in ipairs({ layers.pools, layers.sweeps }) do
		for _, pool in pairs(pools) do
			for _, slot in pairs(pool) do
				slot.texture:Hide()
			end
		end
	end
	for _, texture in ipairs(layers.slices or {}) do
		texture:Hide()
	end
end

-- Turns a composed stamp's plate `degrees` clockwise about its pivot (its motion's origin, else its centre), its
-- slices each turned and moved with it, and its word if the client turns words.
---@param stamp PagleStamp
---@param degrees number
local function tilt(stamp, degrees)
	local info = stamp.layered --[[@as PagleLayeredStamp]]
	local spec, width = info.spec, info.width
	local left, right, height = spec.slice.left, spec.slice.right, spec.h
	local px, py = width / 2, height / 2
	if spec.motion then
		px, py = spec.motion.origin.x - spec.x, spec.motion.origin.y - spec.y
	end
	local r = math.rad(degrees)
	local c, s = math.cos(r), math.sin(r)
	local function place(region, x)
		local dx, dy = x - px, height / 2 - py
		region:ClearAllPoints()
		region:SetPoint("CENTER", stamp, "TOPLEFT", px + c * dx - s * dy, -(py + s * dx + c * dy))
		if region.SetRotation then
			region:SetRotation(-r)
		end
	end
	local plate = stamp.plate --[[@as Texture[] ]]
	place(plate[1], left / 2)
	place(plate[2], left + (width - left - right) / 2)
	place(plate[3], width - right / 2)
	place(stamp.label, left + (width - left - right) / 2)
end

--- Draws a stamp as a composed style's plate (ANN-R82): its rung's stamp sprite (logic/ToastStyles.lua's
--- ns.ToastStampArt) three-sliced at its caps to hold the word, in the stamp's own face and ink, the capitals as the
--- kit gives them, tilted as the kit tilts it. Shown.
---@param stamp PagleStamp
---@param text string
---@param style PagleToastStyle
---@param page PagleToastPage?
function ns.SetLayeredStamp(stamp, text, style, page)
	local spec = ns.ToastStampArt(style, page)
	local ink = ns.ToastInk(style, page, "stamp")
	local atlas = ns.ATLASES[style.art.atlas]
	if not stamp.plate then
		stamp.plate = {}
		for i = 1, 3 do
			stamp.plate[i] = ns.ArtCrisp(stamp.border:CreateTexture(nil, "ARTWORK"))
		end
	end
	local border = stamp.border
	for _, slice in ipairs({ border.left, border.middle, border.right }) do
		slice:Hide()
	end
	local label = stamp.label
	if ink then
		ns.SetInkFont(label, ink)
		label:SetText(ink.caps and ns.Capitals(text) or text)
	else
		ns.SetArtFont(label, "Stamp")
		label:SetText(ns.Capitals(text))
	end
	local left, right = spec.slice.left, spec.slice.right
	local width = math.max(left + right, label:GetStringWidth() + left + right - 8)
	stamp:SetSize(width, spec.h)
	stamp.layered = { spec = spec, width = width }
	local tc = coordsOf(atlas, spec.sprite)
	local du = (tc[2] - tc[1]) / spec.w
	local cuts =
		{ { 0, left, left }, { left, spec.w - right, width - left - right }, { spec.w - right, spec.w, right } }
	for i, cut in ipairs(cuts) do
		local slice = stamp.plate[i]
		slice:SetTexture(atlas.file)
		slice:SetTexCoord(tc[1] + du * cut[1], tc[1] + du * cut[2], tc[3], tc[4])
		slice:SetSize(math.max(0.01, cut[3]), spec.h)
		slice:Show()
	end
	tilt(stamp, spec.tilt or 0)
	stamp:Show()
end

--- Puts a stamp a composed style drew back to the round one styles' rubber stamp: its plate hidden, its border and
--- its word's font, ink and angle as they were.
---@param stamp PagleStamp
function ns.ClearLayeredStamp(stamp)
	for _, slice in ipairs(stamp.plate or {}) do
		slice:Hide()
	end
	local border = stamp.border
	for _, slice in ipairs({ border.left, border.middle, border.right }) do
		slice:Show()
	end
	stamp.layered = nil
	if stamp.label.SetRotation then
		stamp.label:SetRotation(0)
	end
	stamp.label:ClearAllPoints()
	stamp.label:SetPoint("CENTER", stamp, "CENTER")
	ns.SetArtFont(stamp.label, "Stamp")
end

-- The stamps a frame shows with a moving composed plate.
---@param frame PagleAnnouncementFrame
---@return PagleStamp[]
local function movingStamps(frame)
	local out = {}
	local stamps = { unpack(frame.stamps) }
	if frame.ruler then
		stamps[#stamps + 1] = frame.ruler.record
	end
	for _, stamp in ipairs(stamps) do
		if stamp.layered and stamp.layered.spec.motion then
			out[#out + 1] = stamp
		end
	end
	return out
end

--- Plays a composed style's layers' motion on a frame of the lanes (ANN-R82), from `form`'s landing, each layer's
--- properties on their own keyframes, looping while it shows (logic/ToastStyles.lua's ns.ToastLayerAnimations), a
--- moving stamp plate turning with them. Drawn again with the same display, style and rung, it carries on. A frame
--- standing still (a sample), or with Animations off, keeps its resting frame: nothing moves.
---@param frame PagleAnnouncementFrame
---@param display PagleDisplay
---@param style PagleToastStyle
---@param page PagleToastPage?
---@param form "toast"|"nod"
function ns.PlayToastLayers(frame, display, style, page, form)
	local layers = frame.toastLayers
	if not layers then
		return
	end
	local key = style.id .. " " .. ns.ToastRungKey(page)
	if layers.playing == display and layers.playingKey == key then
		return
	end
	ns.StopToastLayers(frame)
	if not (frame.lanes and ns.MotionOn()) then
		return
	end
	layers.playing, layers.playingKey = display, key
	local animations = {}
	local function add(list)
		for _, animation in ipairs(list) do
			animations[#animations + 1] = animation
		end
	end
	for _, slot in ipairs(layers.active) do
		local motion = slot.layer.motion
		if motion then
			add(ns.ToastLayerAnimations(motion, LANDING[form], function(kind, values)
				slot.state[kind] = values
				slot.texture:Show()
				commit(slot, layers.host)
			end))
		end
	end
	for _, stamp in ipairs(movingStamps(frame)) do
		add(ns.ToastLayerAnimations(stamp.layered.spec.motion, LANDING[form], function(kind, values)
			if kind == "transform" and stamp.layered then
				tilt(stamp, values[3])
			end
		end))
	end
	if #animations > 0 then
		ns.Animate(layers.over, animations)
	end
end

--- One sprite of a layered piece that isn't a toast: its sprite in the piece's atlas, its box in the piece's own
--- units, its z (the order it draws in: z 4 at sublevel 0 of the ARTWORK layer), and any blend and motion, as a toast
--- style's layer has them.
---@class PagleLayeredPieceLayer: PagleToastBox
---@field name string
---@field sprite string
---@field z number
---@field blend? "ADD"|"MOD"
---@field motion? PagleToastLayerMotion

--- A frame a layered piece is drawn on (a Legend crest's box, LED-R153), and the piece's sprites as drawn.
---@class PagleLayeredHost: Frame
---@field layeredPiece { slots: PagleLayerSlot[] }?

--- Draws `layers` of atlas `atlasName` on `host` in their resting frame (unmoved, opaque), as a toast's layers are
--- drawn (`commit`): each sprite at its box, in its blend, about its motion's origin; one `shown` refuses hidden, and
--- any left over from what `host` drew before. Its owner plays its motion (ns.MoveLayeredPiece).
---@param host PagleLayeredHost
---@param atlasName string
---@param layers PagleLayeredPieceLayer[]
---@param shown (fun(layer: PagleLayeredPieceLayer): boolean)?
function ns.DrawLayeredPiece(host, atlasName, layers, shown)
	local piece = host.layeredPiece
	if not piece then
		piece = { slots = {} }
		host.layeredPiece = piece
	end
	local atlas = ns.ATLASES[atlasName]
	for i, layer in ipairs(layers) do
		local slot = piece.slots[i]
		if not slot then
			slot = { texture = ns.ArtCrisp(host:CreateTexture(nil, "ARTWORK")) } --[[@as PagleLayerSlot]]
			piece.slots[i] = slot
		end
		local texture = slot.texture
		texture:SetDrawLayer("ARTWORK", math.max(-8, math.min(7, layer.z - 4)))
		slot.layer = layer --[[@as PagleToastLayer]]
		slot.tc = coordsOf(atlas, layer.sprite)
		slot.box = { x = layer.x, y = layer.y, w = layer.w, h = layer.h }
		local origin = layer.motion and layer.motion.origin or { x = layer.x + layer.w / 2, y = layer.y + layer.h / 2 }
		slot.origin = { x = origin.x, y = origin.y }
		slot.window = nil
		slot.state = {}
		texture:SetTexture(atlas.file)
		texture:SetBlendMode(layer.blend or "BLEND")
		commit(slot, host)
		texture:SetShown(shown == nil or shown(layer))
	end
	for i = #layers + 1, #piece.slots do
		piece.slots[i].texture:Hide()
	end
end

--- Moves layer `i` of the piece ns.DrawLayeredPiece drew on `host` to where its motion has it now: its "alpha"
--- ({ alpha }) or "transform" ({ x, y, rotate, sx, sy }) at `values`.
---@param host PagleLayeredHost
---@param i integer
---@param kind string
---@param values number[]
function ns.MoveLayeredPiece(host, i, kind, values)
	local slot = (host.layeredPiece --[[@as { slots: PagleLayerSlot[] }]]).slots[i]
	slot.state[kind] = values
	commit(slot, host)
end
