---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- A composed toast style's layers on the client (announcements.md › Toast styles, ANN-R82): the round two kit's
-- sprites stacked on a toast's or Nod's frame from its art (data/ToastStyleArt2.lua), each on the host the art puts it
-- on, under the medallion's icon, over it or over the words; its stamp plates; and its motion, played on the motion
-- driver (adapter/Motion.lua) once the toast lands and stopped when it goes. Drawn by Core's layered art
-- (logic/LayeredArt.lua); this file fits a rung to its page, slices the Nod's body and draws the stamps.
-- adapter/Announcements.lua lays out the medallion, words, stamps and Coins round them. Nothing here is drawn for the
-- round one styles.

-- When a toast has landed, the motion's start (ANN-R82): a toast's page once it has slid in (0.14 of its motion's
-- 7 s timeline, adapter/Announcements.lua), a Nod once it has faded in.
local LANDING = { toast = 0.98, nod = ns.SETTLE_SECONDS.nod }
-- The client's draw layer for each host's sprites: the body's under the medallion, the medallion's over its icon, and
-- their own frame's over the words.
local DRAW_LAYER = { under = "BORDER", front = "OVERLAY", over = "ARTWORK" }
-- The motion player the layers play on.
local MOTION = { animate = ns.Animate, stop = ns.StopMotion, isOn = ns.MotionOn }

--- A toast's or Nod's composed layers (logic/LayeredArt.lua's, its boxes from `host`'s top left): the frame the
--- under-sprites hang on (the toast's body, the Nod's frame), the frame over its words, the medallion's, and the Nod
--- body's three slices.
---@class PagleToastLayers: PagleLayeredArt
---@field host Frame
---@field over Frame
---@field front Frame
---@field slices Texture[]?
---@field playing PagleDisplay?

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
		local front = frame.bezel --[[@as Frame]]
		layers = ns.NewLayeredArt({
			anchor = host,
			hosts = {
				under = { frame = host, layer = DRAW_LAYER.under },
				front = { frame = front, layer = DRAW_LAYER.front },
				over = { frame = over, layer = DRAW_LAYER.over },
			},
			owner = over,
			motion = MOTION,
			once = ns.TOAST_MOTION_ONCE,
		}) --[[@as PagleToastLayers]]
		layers.host, layers.over, layers.front = host, over, front
		frame.toastLayers = layers
	end
	return layers
end

local coordsOf = ns.SpriteCoords

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
	for _, texture in ipairs(layers.slices or {}) do
		texture:Hide()
	end
	layers:Draw(atlas, rung.layers, {
		-- The medallion's back and front stay centred down a taller page; a sweep's mask fits as its box does.
		fit = function(box, layer, mask)
			local centred = not mask and (layer.name == "mback" or layer.name == "mfront")
			return ns.FitToastBox(box, rung, w, h, centred)
		end,
		-- The Nod's body, three-sliced to its line's length.
		custom = function(layer)
			if not page and layer.name == "body" and rung.slice then
				sliceBody(layers, atlas, layer --[[@as PagleToastLayer]], rung, w)
				return true
			end
			return false
		end,
	})
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
		layers:Stop()
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
	layers:Clear()
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
--- properties on their own keyframes, looping while it shows (logic/LayeredArt.lua's ns.LayerAnimations; a keyframe
--- ns.TOAST_MOTION_ONCE names plays once), a moving stamp plate turning with them. Drawn again with the same display,
--- style and rung, it carries on. A frame standing still (a sample), or with Animations off, keeps its resting frame:
--- nothing moves.
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
	if not frame.lanes then
		layers:Stop()
		return
	end
	local stamps = {}
	for _, stamp in ipairs(movingStamps(frame)) do
		local motion = stamp.layered.spec.motion --[[@as PagleArtMotion]]
		local turns = ns.LayerAnimations(motion, LANDING[form], function(kind, values)
			if kind == "transform" and stamp.layered then
				tilt(stamp, values[3])
			end
		end, ns.TOAST_MOTION_ONCE[motion.keyframes])
		for _, animation in ipairs(turns) do
			stamps[#stamps + 1] = animation
		end
	end
	layers:Play(display, key, LANDING[form], stamps)
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
