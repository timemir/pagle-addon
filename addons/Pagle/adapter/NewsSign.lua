---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The news sign, The Morning Tide to players (core/news-sign.md): one piece of news about the Anglers the player follows, or a region headline,
-- drops in from the top of the screen in one of six looks, hangs about 8 s and goes back up. This file is the sign's
-- frame and its drawing kit, and when a drop may start: out of combat and restriction, with no letter on screen and
-- the Field guide closed (SIGN-R40, ONB-R17). adapter/NewsSignLooks.lua has the six looks' motion, adapter/NewsSignDev.lua `/pagle dev sign`
-- (SIGN-R60), and adapter/NewsSignDrop.lua the once-a-session drop with the news (SIGN-R14–R19).
--
-- One frame, PagleNewsSign, sits where the sign rests (SIGN-R20); every region is placed from its top left each frame,
-- in UI units with y growing down, as the design kit's canvas (engine.js) draws it. Three child frames stack the
-- art: `back`, then `clip` (it clips its children, for an unrolling or opening reveal), then `front`. Its clock is one
-- animation on Pagle's motion driver (adapter/Motion.lua), so it ticks only while it shows, and with Animations off the
-- sign appears at rest and leaves at once (SIGN-R43).

local OWNER = "Pagle news sign"

--- Where the art and sounds are.
local MEDIA = "Interface\\AddOns\\Pagle\\media\\sign\\"
local SOUNDS = MEDIA .. "sounds\\"

--- Tunables (core/news-sign.md › Tunables): the sign's scale on UIParent, its rest spot (its centre's x and its top's y,
--- as fractions of UIParent from its top left), how long it hangs, how fast hover eases, and the longest a drop lives.
ns.NEWS_SIGN_SCALE = 0.85
ns.NEWS_SIGN_SPOT = { x = 0.285, y = 0.05 }
ns.NEWS_SIGN_HANG = 8
local HOVER_RATE = 10
local LIFETIME = 600

---@class PagleNewsSignNews
---@field kind string "first" | "legend" | "prestige" | "ledger" | "colour" | "hunt" | "zone" | "monster" | "region"
---@field kicker string? the kind's name over the headline
---@field head string the headline
---@field detail string? the line under it
---@field plate string? the region headline's plate
---@field more string? the "+N more" line
---@field id string? the news item shown, by its id (VIEW-R41), for SIGN-R42; none for a sample
---@field emblem table how the kind's emblem draws (SIGN-R13); `variety.silhouette` true draws an uncaught one dark (VAR-R27)

---@class PagleNewsSignLook
---@field key string
---@field w number the hit box, units
---@field h number
---@field enter number seconds its entrance takes
---@field out number seconds its exit takes
---@field theme table the words' faces and inks
---@field words table the words' box { x, y, w, h } at rest, units
---@field sounds table[] { name, at } from the drop
---@field outSounds table[] { name, at } from the exit
---@field atlas string the look's own atlas, a key of ns.ATLASES
---@field moreOnBoard boolean? false when the more line hangs off the board (Wood's tag)
---@field moreW number? the more line's room off the board, units
---@field moreY number? the more line's top on the board, units, when it isn't the box's foot
---@field draw fun(k: table, t: number, s: table)
---@field rest number? the time its pose is drawn at when Animations are off (default enter + 1)

--- The six looks, by key, as adapter/NewsSignLooks.lua adds them, and their order.
---@type table<string, PagleNewsSignLook>
ns.NEWS_SIGN_LOOKS = {}
ns.NEWS_SIGN_LOOK_ORDER = { "wood", "scroll", "lantern", "kraken", "astro", "coral" }

-- ------------------------------------------------------------------ maths, as the kit's engine.js has them
local TAU = math.pi * 2
local function clamp(v, a, b)
	a, b = a or 0, b or 1
	return v < a and a or (v > b and b or v)
end
local function lerp(a, b, u)
	return a + (b - a) * u
end
local function seg(t, a, b)
	return clamp((t - a) / (b - a))
end
local function easeOutCubic(u)
	return 1 - (1 - u) ^ 3
end
local function easeInCubic(u)
	return u * u * u
end
local function easeInOut(u)
	return u < 0.5 and 4 * u * u * u or 1 - ((-2 * u + 2) ^ 3) / 2
end
local function easeOutBack(u, s)
	s = s or 1.7
	return 1 + (s + 1) * (u - 1) ^ 3 + s * (u - 1) ^ 2
end
--- A damped spring released from 0: overshoots `amp` first, `period` seconds a swing, damped by `zeta`.
local function spring(tau, amp, period, zeta)
	if tau <= 0 then
		return 0
	end
	local wd = TAU / period
	local wn = wd / math.sqrt(1 - zeta * zeta)
	local tp = math.atan(math.sqrt(1 - zeta * zeta) / zeta) / wd
	local A = amp / (math.exp(-zeta * wn * tp) * math.sin(wd * tp))
	return A * math.exp(-zeta * wn * tau) * math.sin(wd * tau)
end
local function sway(tau, amp, period, decay)
	if tau <= 0 then
		return 0
	end
	return amp * math.exp(-tau / decay) * math.sin(TAU * tau / period)
end
--- A seeded generator of numbers in [0, 1), the same each frame for the same seed, so particles are a pure function
--- of time.
local function rng(seed)
	local s = seed % 2147483647
	if s <= 0 then
		s = s + 2147483646
	end
	return function()
		s = (s * 16807) % 2147483647
		return (s - 1) / 2147483646
	end
end
local function noise1(x, seed)
	local i = math.floor(x)
	local f = x - i
	local function h(n)
		local v = math.sin((n + (seed or 0) * 57.13) * 127.1) * 43758.5453
		return v - math.floor(v)
	end
	local u = f * f * (3 - 2 * f)
	return lerp(h(i), h(i + 1), u)
end

ns.NewsSignMath = {
	TAU = TAU,
	clamp = clamp,
	lerp = lerp,
	seg = seg,
	easeOutCubic = easeOutCubic,
	easeInCubic = easeInCubic,
	easeInOut = easeInOut,
	easeOutBack = easeOutBack,
	spring = spring,
	sway = sway,
	rng = rng,
	noise1 = noise1,
}

-- ------------------------------------------------------------------ the drawing kit
-- A frame's draw layers, in order, and how many sublevels each lends: 5 layers of 16 make 80 places a frame.
local LAYERS = { "BACKGROUND", "BORDER", "ARTWORK", "OVERLAY", "HIGHLIGHT" }

---@class PagleNewsSignKit
---@field host Frame the sign's frame
---@field atlas string the look's atlas
---@field back Frame
---@field clip Frame clips its children
---@field front Frame
---@field pool table<string, Texture> by key, made once
---@field used table<string, true> the keys placed this frame
---@field order table<string, integer> each child frame's next draw place
---@field fonts table<string, FontString> by child frame and role, made once
---@field top number
local Kit = {}
Kit.__index = Kit

--- The kit for a look: `host` is the sign's frame, `atlas` the look's atlas name.
---@return PagleNewsSignKit
local function newKit(host, atlas)
	local kit = setmetatable({ host = host, atlas = atlas, pool = {}, used = {}, order = {}, fonts = {}, top = 0 }, Kit)
	for i, name in ipairs({ "back", "clip", "front" }) do
		local f = CreateFrame("Frame", nil, host)
		f:SetFrameLevel(host:GetFrameLevel() + i)
		f:SetAllPoints(host)
		kit[name] = f
		kit.order[name] = 0
	end
	kit.clip:SetClipsChildren(true)
	return kit
end

-- The next draw place on `on`, or the one given.
function Kit:place(on, z)
	local n = z or self.order[on]
	if not z then
		self.order[on] = n + 1
	end
	n = clamp(n, 0, 79)
	return LAYERS[math.floor(n / 16) + 1], (n % 16) - 8
end

-- The texture keyed `key` on child frame `on`, made once.
function Kit:texture(key, on)
	local t = self.pool[key]
	if not t then
		t = self[on]:CreateTexture(nil, "ARTWORK")
		self.pool[key] = t
	end
	self.used[key] = true
	return t
end

--- Starts a frame: nothing is drawn until it is placed again.
function Kit:begin()
	self.used = {}
	for name in pairs(self.order) do
		self.order[name] = 0
	end
end

--- Ends a frame: what wasn't placed this frame is hidden.
function Kit:finish()
	for key, t in pairs(self.pool) do
		if not self.used[key] then
			t:Hide()
		end
	end
end

--- Places region `r` with its centre at (cx, cy) units from the host's top left (y down), `w` by `h`.
function Kit:at(r, cx, cy, w, h)
	r:ClearAllPoints()
	r:SetPoint("CENTER", self.host, "TOPLEFT", cx, -cy)
	if w then
		r:SetSize(math.max(w, 0.01), math.max(h, 0.01))
	end
end

--- Draws a sprite of the look's atlas (or o.atlas), its top left at (x, y) at its own size (its box), on o.on (back).
--- o: alpha, scale or sx/sy about (cx, cy) in its own units (its centre by default), rot (radians, for a round sprite),
--- blend ("ADD"), tint { r, g, b }, z (a fixed draw place), key (the texture's key; the sprite's name by default),
--- w/h (a size of its own, units).
function Kit:sprite(name, x, y, o)
	o = o or {}
	local atlas = ns.ATLASES[o.atlas or self.atlas]
	local s = atlas.sprites[name]
	local key = o.key or ((o.atlas or self.atlas) .. ":" .. name)
	local t = self:texture(key, o.on or "back")
	local w, h = o.w or s.box[3], o.h or s.box[4]
	local sx, sy = o.sx or o.scale or 1, o.sy or o.scale or 1
	local cx, cy = o.cx or w / 2, o.cy or h / 2
	-- the centre, scaled about (cx, cy) and turned about it
	local mx, my = (w / 2 - cx) * sx, (h / 2 - cy) * sy
	if o.rot and o.rot ~= 0 then
		local c, sn = math.cos(o.rot), math.sin(o.rot)
		mx, my = mx * c - my * sn, mx * sn + my * c
	end
	t:SetTexture(atlas.file)
	t:SetTexCoord(s.x / atlas.width, (s.x + s.w) / atlas.width, s.y / atlas.height, (s.y + s.h) / atlas.height)
	if t.SetRotation then
		t:SetRotation(-(o.rot or 0))
	end
	t:SetBlendMode(o.blend or "BLEND")
	local tint = o.tint
	t:SetVertexColor(tint and tint[1] or 1, tint and tint[2] or 1, tint and tint[3] or 1)
	t:SetAlpha(clamp(o.alpha or 1))
	t:SetDrawLayer(self:place(o.on or "back", o.z))
	self:at(t, x + cx + mx, y + cy + my, w * math.abs(sx), h * math.abs(sy))
	t:Show()
	return t
end

-- The shared atlas's sprites, centred.
function Kit:common(name, key, cx, cy, size, o)
	o = o or {}
	o.atlas, o.key = "SignCommon", key
	o.w, o.h = size[1], size[2]
	return self:sprite(name, cx - size[1] / 2, cy - size[2] / 2, o)
end

--- A soft light at (x, y), `r` units across its middle, added on.
function Kit:glow(key, x, y, r, tint, alpha, o)
	if alpha <= 0 then
		return
	end
	o = o or {}
	o.blend, o.tint, o.alpha = "ADD", tint, alpha
	self:common("glow", key, x, y, { r * 2, r * 2 }, o)
end

--- A soft round dot.
function Kit:dot(key, x, y, r, tint, alpha, o)
	if alpha <= 0 or r <= 0 then
		return
	end
	o = o or {}
	o.tint, o.alpha = tint, alpha
	self:common("dot", key, x, y, { r * 2.4, r * 2.4 }, o)
end

--- A four-point glint with a little light round it.
function Kit:sparkle(key, x, y, r, alpha, tint, o)
	if alpha <= 0 then
		return
	end
	o = o or {}
	o.blend, o.tint, o.alpha = "ADD", tint, alpha
	self:common("sparkle", key, x, y, { r * 2, r * 2 }, o)
	self:glow(key .. "g", x, y, r * 1.6, tint, alpha * 0.5, { on = o.on, z = o.z })
end

--- A ring (a shockwave, a ripple), `rx` by `ry` units across its radii.
function Kit:ring(key, x, y, rx, ry, tint, alpha, o)
	if alpha <= 0 then
		return
	end
	o = o or {}
	o.tint, o.alpha, o.blend = tint, alpha, o.blend or "ADD"
	self:common("ring", key, x, y, { rx * 2, ry * 2 }, o)
end

--- A straight line from (x1, y1) to (x2, y2), `w` units wide: a column for a near-vertical line, else dots every
--- `gap` units (3 by default).
function Kit:line(key, x1, y1, x2, y2, w, tint, alpha, o)
	o = o or {}
	local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
	if alpha <= 0 or len <= 0 then
		return
	end
	if math.abs(x2 - x1) <= len * 0.08 then
		self:sprite("pixel", (x1 + x2) / 2 - w / 2, math.min(y1, y2), {
			atlas = "SignCommon",
			key = key,
			w = w,
			h = len,
			tint = tint,
			alpha = alpha,
			on = o.on,
			z = o.z,
		})
		return
	end
	local n = math.max(2, math.floor(len / (o.gap or 3)))
	for i = 0, n do
		local u = i / n
		self:dot(key .. i, lerp(x1, x2, u), lerp(y1, y2, u), w * 0.7, tint, alpha, { on = o.on, z = o.z })
	end
end

--- A chain or a rope: tiles of `sprite` (of the look's atlas, or o.atlas) hung from (x, y) down to (x2, y2), each
--- upright, `o.w` units wide (its own width by default). The bottom tile ends on the lower end, so the links come down
--- with what they hold; the top one runs past the upper end, off the screen's edge.
function Kit:tiles(key, sprite, x, y, x2, y2, o)
	o = o or {}
	local atlas = ns.ATLASES[o.atlas or self.atlas]
	local s = atlas.sprites[sprite]
	local tw = o.w or s.box[3]
	local th = s.box[4] * tw / s.box[3]
	local len = math.sqrt((x2 - x) ^ 2 + (y2 - y) ^ 2)
	if len <= 0 then
		return
	end
	for i = 1, math.ceil(len / th) do
		local c = (len - (i - 0.5) * th) / len -- the tile's centre, as a fraction from the upper end
		self:sprite(sprite, lerp(x, x2, c) - tw / 2, lerp(y, y2, c) - th / 2, {
			atlas = o.atlas,
			key = key .. i,
			w = tw,
			h = th,
			on = o.on,
			z = o.z,
			alpha = o.alpha,
		})
	end
end

--- Sets the clip frame's rectangle, (x, y) its top left in units, `w` by `h`.
function Kit:clipTo(x, y, w, h)
	local c = self.clip
	c:ClearAllPoints()
	c:SetPoint("TOPLEFT", self.host, "TOPLEFT", x, -y)
	c:SetSize(math.max(w, 0.01), math.max(h, 0.01))
end

-- ------------------------------------------------------------------ the words (SIGN-R12)
-- Each look's inks: kicker, headline, detail, "+N more" (r, g, b), the shadow (r, g, b, a) and its offset.
-- Sizes in UI units: the kicker 12, the headline 18 (two lines at most), the detail 15, the more line 15. Words that
-- don't fit their box at those sizes, as a long translation's may not, are set smaller together, down to SHRINK's last.
local KICKER_FACE, HEAD_FACE, DETAIL_FACE, MORE_FACE =
	"IMFeENsc28P.ttf", "Marcellus-Regular.ttf", "IMFeENit28P.ttf", "Caveat-SemiBold.ttf"
local SHRINK = { 1, 0.9, 0.8, 0.72 }

-- A font string's width on one line: its unbounded width where the client has it.
local function oneLine(f)
	return (f.GetUnboundedStringWidth and f:GetUnboundedStringWidth()) or f:GetStringWidth() or 0
end

--- Sets the words' font strings for one drop, on `on`, laid out in `box` (units); returns { lines, more, all, scale }.
--- Each line's string is made once per frame and role and kept, since the client never frees one.
function Kit:words(news, look, on)
	local th, box = look.theme, look.words
	on = on or "back"
	local parent = self[on]
	local made = {}
	local function fs(role, text, face, size, ink)
		local key = on .. ":" .. role
		local f = self.fonts[key]
		if not f then
			f = parent:CreateFontString(nil, "OVERLAY")
			self.fonts[key] = f
		end
		f:Show()
		ns.faces:Set(f, face, size) -- the client sets no text in a string without a font
		f:SetTextColor(ink[1], ink[2], ink[3])
		local sh = th.shadow
		f:SetShadowColor(sh[1], sh[2], sh[3], sh[4])
		f:SetShadowOffset(0, -(th.shadowDy or 1))
		f:SetJustifyH("LEFT")
		f:SetJustifyV("TOP")
		f:SetText(text)
		made[#made + 1] = f
		return f
	end
	local kicker = news.kicker and fs("kicker", news.kicker, KICKER_FACE, th.kickSize or 12, th.kick)
	local head = fs("head", news.head, HEAD_FACE, th.headSize or 18, th.head)
	local detail = news.detail and fs("detail", news.detail, DETAIL_FACE, th.detSize or 15, th.det)
	local more = news.more and fs("more", news.more, MORE_FACE, th.moreSize or 15, th.more)
	local moreOnBoard = more and look.moreOnBoard ~= false
	if kicker then
		kicker:SetWidth(box.w)
		kicker:SetWordWrap(false)
	end
	head:SetWidth(box.w)
	head:SetWordWrap(true)
	if head.SetMaxLines then
		head:SetMaxLines(2)
	end
	if detail then
		detail:SetWordWrap(false)
	end
	if more then
		more:SetJustifyH(moreOnBoard and "RIGHT" or "CENTER")
		more:SetWordWrap(false)
	end

	-- the words at `scale`: their lines and their height together
	local function layout(scale)
		local sizes = {
			kicker = (th.kickSize or 12) * scale,
			head = (th.headSize or 18) * scale,
			detail = (th.detSize or 15) * scale,
			more = (th.moreSize or 15) * scale,
		}
		local lines = {}
		if kicker then
			ns.faces:Set(kicker, KICKER_FACE, sizes.kicker)
			lines[#lines + 1] = { f = kicker, h = sizes.kicker * 1.25 }
		end
		ns.faces:Set(head, HEAD_FACE, sizes.head)
		-- its height: what the client measures, or its lines by its width on one line, whichever is more
		local guess = math.min(2, math.max(1, math.ceil(oneLine(head) / box.w))) * sizes.head * 1.14
		lines[#lines + 1] = { f = head, h = math.max(head:GetStringHeight() or 0, guess) + 2 }
		if detail then
			ns.faces:Set(detail, DETAIL_FACE, sizes.detail)
			lines[#lines + 1] = { f = detail, h = sizes.detail * 1.3, scroll = true }
		end
		local total = 0
		for _, l in ipairs(lines) do
			total = total + l.h
		end
		-- the room: the box, less the more line's when it's on the board, and above a more line set higher (moreY)
		local bottom = box.y + box.h - (moreOnBoard and sizes.more * 0.9 or 0)
		if moreOnBoard and look.moreY then
			bottom = math.min(bottom, look.moreY - 1)
		end
		local cut = head.IsTruncated and head:IsTruncated()
		return lines, total, bottom, sizes, not cut and total <= bottom - box.y
	end

	local lines, total, bottom, sizes, fits, scale
	for _, s in ipairs(SHRINK) do
		scale = s
		lines, total, bottom, sizes, fits = layout(s)
		if fits then
			break
		end
	end
	if more then
		-- the more line at the words' size, smaller still if it's wider than its room, and cut there at the last
		local room = moreOnBoard and box.w or (look.moreW or box.w)
		local size = sizes.more
		ns.faces:Set(more, MORE_FACE, size)
		local wide = oneLine(more)
		if wide > room then
			ns.faces:Set(more, MORE_FACE, math.max(size * room / wide, size * SHRINK[#SHRINK]))
		end
		more:SetWidth(room)
	end
	-- centred in the room, but never above the box's top
	local y = math.max(box.y, box.y + (bottom - box.y - total) / 2)
	for _, l in ipairs(lines) do
		l.y = y
		y = y + l.h
	end
	return { lines = lines, more = more, all = made, scale = scale }
end

--- Places the words at an offset (dx, dy) from rest, each line at alpha `alpha(i, line)`; a detail too long for its
--- room scrolls to and fro inside the box (ANN-R101: ns.MARQUEE_SPEED units a second, ns.MARQUEE_HOLD at each end).
function Kit:placeWords(words, look, dx, dy, t, alpha)
	local box = look.words
	for i, l in ipairs(words.lines) do
		local f = l.f
		local x = box.x
		if l.scroll then
			local over = (f:GetStringWidth() or 0) - box.w
			if over > 1 then
				local speed, hold = ns.MARQUEE_SPEED or 40, ns.MARQUEE_HOLD or 1
				local run = over / speed
				local cyc = 2 * run + 2 * hold
				local p = t % cyc
				local u = p < hold and 0
					or p < hold + run and (p - hold) / run
					or p < 2 * hold + run and 1
					or 1 - (p - 2 * hold - run) / run
				x = x - over * u
			end
		end
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", self.host, "TOPLEFT", x + dx, -(l.y + dy))
		f:SetAlpha(clamp(alpha and alpha(i, l) or 1))
	end
	if words.more and look.moreOnBoard ~= false then
		local f = words.more
		f:ClearAllPoints()
		f:SetPoint("TOPRIGHT", self.host, "TOPLEFT", box.x + box.w + dx, -((look.moreY or box.y + box.h - 4) + dy))
		f:SetAlpha(clamp(alpha and alpha(#words.lines + 1) or 1))
	end
end

-- ------------------------------------------------------------------ the emblem (SIGN-R13)
--- Draws `news.emblem` centred at (cx, cy), 58 units across times `scale`.
function Kit:emblem(news, cx, cy, o)
	o = o or {}
	local e = news.emblem
	local size = 58 * (o.scale or 1)
	local alpha = o.alpha or 1
	local on, z = o.on or "back", o.z
	if alpha <= 0 or size <= 0.5 then
		return
	end
	-- `dark`: drawn as a dark silhouette, as the varieties spread draws an uncaught variety (VAR-R24, VAR-R27)
	local function file(key, path, w, h, coords, dark)
		local t = self:texture("emblem:" .. key, on)
		t:SetTexture(path)
		t:SetTexCoord(unpack(coords or { 0, 1, 0, 1 }))
		t:SetDesaturated(dark == true)
		if dark then
			t:SetVertexColor(0, 0, 0)
		else
			t:SetVertexColor(1, 1, 1)
		end
		t:SetBlendMode("BLEND")
		t:SetAlpha(alpha)
		if t.SetRotation then
			t:SetRotation(0)
		end
		t:SetDrawLayer(self:place(on, z))
		self:at(t, cx, cy, w, h)
		t:Show()
	end
	if e.sign then
		self:sprite(e.sign, cx - size / 2, cy - size / 2, {
			atlas = "SignCommon",
			key = "emblem:sign",
			w = size,
			h = size,
			alpha = alpha,
			on = on,
			z = z,
		})
	elseif e.atlas then
		local a = ns.ATLASES[e.atlas]
		local s = a and a.sprites[e.sprite]
		if s then
			file("atlas", a.file, size, size, {
				s.x / a.width,
				(s.x + s.w) / a.width,
				s.y / a.height,
				(s.y + s.h) / a.height,
			})
		end
	elseif e.legend then
		-- the Legend's crest, its layers in the crest box (260 x 280) brought to the slot
		local art = ns.LEGEND_CREST_ART and ns.LEGEND_CREST_ART[e.legend]
		local a = art and ns.ATLASES[art.atlas]
		if a then
			local k = size / 280
			for i, layer in ipairs(art.layers) do
				local s = a.sprites[layer.sprite]
				if s and layer.name ~= "lab" then
					local lx, ly =
						cx - 130 * k + (layer.x + layer.w / 2) * k, cy - 140 * k + (layer.y + layer.h / 2) * k
					local t = self:texture("emblem:legend" .. i, on)
					t:SetTexture(a.file)
					t:SetTexCoord(s.x / a.width, (s.x + s.w) / a.width, s.y / a.height, (s.y + s.h) / a.height)
					t:SetVertexColor(1, 1, 1)
					t:SetBlendMode(layer.blend == "add" and "ADD" or "BLEND")
					t:SetAlpha(alpha)
					t:SetDrawLayer(self:place(on, z))
					self:at(t, lx, ly, layer.w * k, layer.h * k)
					t:Show()
				end
			end
			local icon = e.item and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.item)
			if icon then
				local w = ns.LEGEND_CREST_WELL
				local r = w.r * k * 1.7
				file("legendIcon", icon, r, r, { 0.08, 0.92, 0.08, 0.92 })
			end
		end
	elseif e.variety then
		local art = ns.VARIETY_ART and ns.VARIETY_ART[e.variety.species]
		local at = art and art[e.variety.position]
		local A = ns.VARIETY_ART_SIZE
		if at and A then
			-- a variety the player hasn't caught is never coloured on the sign (SIGN-R13, VAR-R27)
			file("variety", ns.VARIETY_ATLASES[at[1]], size, size / 2, {
				at[2] / A.atlas,
				(at[2] + A.w) / A.atlas,
				at[3] / A.atlas,
				(at[3] + A.h) / A.atlas,
			}, e.variety.silhouette == true)
		end
	elseif e.file then
		file("file", e.file, size * (e.fill or 1), size * (e.fill or 1))
	end
	if e.tape then
		self:sprite("tape", cx - size / 2, cy - size / 2, {
			atlas = "SignCommon",
			key = "emblem:tape",
			w = size,
			h = size,
			alpha = alpha,
			on = on,
			z = z,
		})
	end
end

-- ------------------------------------------------------------------ the frame and one drop
---@type Button?
local frame
---@type table? the drop showing: look, news, kit, words, t, exitAt, hover, hanging, hangLeft, cues, top
local drop
---@type table? a drop waiting for combat, restriction, a letter and the guide to end: { look?, news, onStart? }
local waiting

-- ------------------------------------------------------------------ the sign's settings (news-sign.md › Data)
-- PagleDB.global.newsSign as stored, or nil: nothing is written until a switch is turned off, the sign muted or moved.
---@return { show: boolean?, kinds: table<string, boolean>?, headlines: boolean?, mute: boolean?, point: table? }?
local function stored()
	return ns.db and ns.db.global and ns.db.global.newsSign
end

--- Whether a switch of the sign's is on (SET-R37, news-sign.md › Data): "show" (Show news at login) or "headlines"
--- (Region headlines), on unless stored as false. The one read of them: the decision's (adapter/NewsSignDrop.lua) and
--- the Settings rows' alike.
---@param key "show"|"headlines"
---@return boolean
function ns.NewsOption(key)
	local sign = stored()
	return not (sign and sign[key] == false)
end

--- Whether the switch of the followed kind `kind` (SIGN-R10) is on: on unless stored as false, so a missing key, or a
--- kind a later release adds, reads as on (news-sign.md › Data).
---@param kind string
---@return boolean
function ns.NewsKindOn(kind)
	local sign = stored()
	local kinds = sign and sign.kinds
	return not (type(kinds) == "table" and kinds[kind] == false)
end

--- Whether the sign is muted (SIGN-R31): only when stored as true.
---@return boolean
function ns.NewsSignMuted()
	local sign = stored()
	return sign ~= nil and sign.mute == true
end

-- The saved spot, or the default (SIGN-R20).
local function spot()
	local saved = stored()
	local p = saved and saved.point
	if p and type(p.x) == "number" and type(p.y) == "number" then
		return p
	end
	return ns.NEWS_SIGN_SPOT
end

-- Puts the frame at its spot, kept whole on the screen: its top centre at the spot's fractions of UIParent.
local function placeFrame()
	assert(frame)
	local p = spot()
	local W, H = UIParent:GetWidth(), UIParent:GetHeight()
	local s = frame:GetScale()
	local w = frame:GetWidth() * s
	local x = clamp(p.x * W, w / 2, math.max(w / 2, W - w / 2))
	local y = clamp(p.y * H, 0, math.max(0, H - frame:GetHeight() * s))
	frame:ClearAllPoints()
	frame:SetPoint("TOP", UIParent, "TOPLEFT", x / s, -y / s)
end

-- The screen's top edge, in the frame's units from its top left (negative: above it).
local function screenTop()
	assert(frame)
	local fs, us = frame:GetEffectiveScale(), UIParent:GetEffectiveScale()
	local top, uTop = frame:GetTop(), UIParent:GetTop()
	if not top or not uTop then
		return -150
	end
	return -((uTop * us - top * fs) / fs)
end

local function playSound(name)
	if not ns.NewsSignMuted() then
		PlaySoundFile(SOUNDS .. name .. ".ogg", "SFX")
	end
end

local function finish()
	if not drop then
		return
	end
	ns.StopMotion(assert(frame))
	for _, f in ipairs(drop.words.all) do
		f:Hide()
	end
	for _, name in ipairs({ "back", "clip", "front" }) do
		drop.kit[name]:Hide()
	end
	drop = nil
	assert(frame):Hide()
	Pagle.UnregisterEvent(OWNER, "PLAYER_REGEN_DISABLED")
	-- a letter that came due while the sign showed follows it, LETTER_DELAY on (ONB-R17)
	if ns.letter then
		ns.letter:SetSignShowing(false)
	end
end

--- Sends the sign up now: its exit plays, then it hides (SIGN-R42). With Animations off it hides at once.
function ns.SendNewsSignUp()
	if not drop or drop.exitAt then
		return
	end
	if drop.static then
		finish()
		return
	end
	drop.exitAt = drop.t
end

-- One frame of the drop at time t (seconds since it began).
local function render(t)
	local d = drop
	if not d then
		return
	end
	local dt = math.max(0, t - (d.t or 0))
	d.t = t
	d.hover = d.hover + ((d.hovering and not d.exitAt) and 1 - d.hover or -d.hover) * math.min(1, HOVER_RATE * dt)
	-- the countdown runs from the end of the entrance, paused while hovered (SIGN-R41)
	if not d.exitAt and t >= d.look.enter then
		if not d.hovering then
			d.hangLeft = d.hangLeft - dt
		end
		if d.hangLeft <= 0 then
			d.exitAt = t
		end
	end
	for _, cue in ipairs(d.look.sounds) do
		if not d.cues[cue] and t >= cue[2] then
			d.cues[cue] = true
			if t - cue[2] < 0.25 then
				playSound(cue[1])
			end
		end
	end
	if d.exitAt then
		for _, cue in ipairs(d.look.outSounds) do
			if not d.cues[cue] and t - d.exitAt >= cue[2] then
				d.cues[cue] = true
				playSound(cue[1])
			end
		end
	end
	d.kit:begin()
	d.look.draw(d.kit, t, d)
	d.kit:finish()
	if d.exitAt and t - d.exitAt > d.look.out + 0.15 then
		finish()
	end
end

local function makeFrame()
	local f = CreateFrame("Button", "PagleNewsSign", UIParent)
	f:SetFrameStrata("HIGH")
	f:SetFrameLevel(20)
	f:SetScale(ns.NEWS_SIGN_SCALE)
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	f:RegisterForDrag("LeftButton")
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:Hide()
	f:SetScript("OnEnter", function()
		if drop then
			drop.hovering = true
		end
	end)
	f:SetScript("OnLeave", function()
		if drop then
			drop.hovering = false
		end
	end)
	f:SetScript("OnMouseDown", function(self)
		self.dragged = false
	end)
	f:SetScript("OnDragStart", function(self)
		if Pagle.IsRestricted() then
			return
		end
		self.dragged = true
		self:StartMoving()
	end)
	-- the spot is kept as fractions of the screen (SIGN-R20), as the detached minimap button's is (CORE-R53)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		-- the frame is named, so the client would keep it in its layout cache too; newsSign.point is the one place its
		-- spot is kept, as Cards.lua's and Book.lua's drags keep theirs
		self:SetUserPlaced(false)
		local s, W, H = self:GetScale(), UIParent:GetWidth(), UIParent:GetHeight()
		local left, top = self:GetLeft(), self:GetTop()
		if left and top and W > 0 and H > 0 then
			ns.db.global.newsSign = ns.db.global.newsSign or {}
			ns.db.global.newsSign.point = {
				x = (left + self:GetWidth() / 2) * s / W,
				y = (H - top * s) / H,
			}
		end
		placeFrame()
		if drop then
			drop.top = screenTop()
		end
	end)
	-- a left click opens the news (the Fish Journal; SIGN-R42), a right click sends it up; the release that ends a
	-- drag does neither
	f:SetScript("OnClick", function(self, button)
		if self.dragged then
			self.dragged = false
			return
		end
		if button == "LeftButton" then
			ns.OpenNewsSignNews()
		end
		ns.SendNewsSignUp()
	end)
	return f
end

--- What a left click on the sign opens: the Fish Journal, through the Ledger's view, if the Ledger is on. (Its
--- Following spread, the brief's, needs a view of its own from the Ledger: core/news-sign.md › Open questions.)
function ns.OpenNewsSignNews()
	for _, module in ipairs(ns.Modules and ns.Modules:Modules() or {}) do
		for _, view in ipairs(module.def.views or {}) do
			if view.id == "journal" and view.open then
				view.open()
				return true
			end
		end
	end
	return false
end

local kits = {}

-- Starts a drop now: the frame takes the look's size and its spot, the words are set, and the clock starts.
local function start(lookKey, news)
	local look = assert(ns.NEWS_SIGN_LOOKS[lookKey], lookKey)
	if drop then
		finish()
	end
	frame = frame or makeFrame()
	frame:SetSize(look.w, look.h)
	placeFrame()
	frame:Show()
	-- each look's kit is made once and kept, with its frames, textures and font strings (the client frees none)
	local kit = kits[look.key]
	if kit then
		for _, t in pairs(kit.pool) do
			t:Hide()
		end
		for _, name in ipairs({ "back", "clip", "front" }) do
			kit[name]:Show()
		end
	else
		kit = newKit(frame, look.atlas)
		kits[look.key] = kit
	end
	local d = {
		look = look,
		news = news,
		kit = kit,
		t = 0,
		hover = 0,
		hovering = false,
		hangLeft = ns.NEWS_SIGN_HANG,
		cues = {},
		top = screenTop(),
	}
	d.words = kit:words(news, look, "clip")
	drop = d
	if ns.letter then
		ns.letter:SetSignShowing(true) -- no letter shows while the sign does (ONB-R17)
	end
	Pagle.RegisterEvent(OWNER, "PLAYER_REGEN_DISABLED", function()
		ns.SendNewsSignUp()
	end)
	if not ns.MotionOn() then
		-- Animations off (SIGN-R43): at rest, still; it leaves at once when its time is up
		d.static = true
		d.cues = setmetatable({}, {
			__index = function()
				return true
			end,
		})
		render(look.rest or look.enter + 1)
		d.hangLeft = ns.NEWS_SIGN_HANG
		local ticker
		ticker = C_Timer.NewTicker(0.25, function()
			if drop ~= d then
				ticker:Cancel()
				return
			end
			if not d.hovering then
				d.hangLeft = d.hangLeft - 0.25
			end
			if d.hangLeft <= 0 then
				ticker:Cancel()
				finish()
			end
		end)
		return
	end
	ns.Animate(frame, {
		{
			dur = LIFETIME,
			ease = ns.EASE.linear,
			keys = { { 0, { 0 } }, { 1, { LIFETIME } } },
			apply = function(v)
				render(v[1])
			end,
		},
	}, function()
		finish()
	end)
end

--- The look the sign wears (SIGN-R57): the one equipped in Core's slot `core.newssign` (Pagle.GetEquipped, SHOP-R32),
--- its key the good ID's last part; Wood, the default, while the slot has no goods (a Core before SHOP-R60's) or for
--- a look the sign doesn't know.
---@return string
function ns.EquippedNewsSignLook()
	local id = Pagle.GetEquipped and Pagle.GetEquipped("core.newssign")
	local key = type(id) == "string" and id:match("^core%.newssign%.(%w+)$")
	if key and ns.NEWS_SIGN_LOOKS[key] then
		return key
	end
	return "wood"
end

-- Starts the drop waiting, unless a letter is on screen or the Field guide is open (SIGN-R40, ONB-R17): then it waits
-- on, and ns.NewsSignLetterGone or GuideClosed tries again.
local function tryWaiting()
	local w = waiting
	if not w or (ns.letter and ns.letter:IsShowing()) or (ns.guide and ns.guide:IsOpen()) then
		return
	end
	waiting = nil
	start(w.look or ns.EquippedNewsSignLook(), w.news)
	if w.onStart then
		w.onStart()
	end
end

--- Drops the sign (SIGN-R40): `look` is a key of ns.NEWS_SIGN_LOOKS, or nil for the look equipped as it drops
--- (SIGN-R57); `news` is what it shows; `onStart`, if given, is called as its entrance starts (SIGN-R17's marking).
--- Never in combat or while restricted, never while a letter shows and never while the Field guide is open: it waits
--- until all have ended, keeping its words, and only the last one asked for waits.
---@param lookKey string?
---@param news PagleNewsSignNews
---@param onStart fun()?
function ns.DropNewsSign(lookKey, news, onStart)
	waiting = { look = lookKey, news = news, onStart = onStart }
	ns.RunWhenUnrestricted(tryWaiting)
end

-- A drop waiting tries again, once unrestricted.
local function retry()
	if waiting then
		ns.RunWhenUnrestricted(tryWaiting)
	end
end

--- A letter left the screen (adapter/Letter.lua's hide: answered, or hidden by a restriction or an instance): a drop
--- waiting for it tries again a frame later (SIGN-R40), since the letter hides before its confirm button acts, and
--- the onboarding Letter's opens the Field guide, which the drop then waits for.
function ns.NewsSignLetterGone()
	if waiting then
		C_Timer.After(0, retry)
	end
end

-- SIGN-R40: the Field guide closing lets a drop waiting for it start, as it lets a letter (ONB-R17).
Pagle.RegisterCallback("Pagle news sign guide", "GuideClosed", retry)

--- The drop showing, for the specs and the dev command: its look key, time and state.
function ns.NewsSignState()
	if not drop then
		return nil
	end
	return {
		look = drop.look.key,
		id = drop.news.id, -- the news item shown (VIEW-R41), none for a sample
		t = drop.t,
		exiting = drop.exitAt ~= nil,
		hangLeft = drop.hangLeft,
		hover = drop.hover,
		static = drop.static == true,
		words = drop.words, -- its lines ({ f, h, y }), its more line and the scale it was set at (SIGN-R12)
	}
end

--- The sign's frame, once made.
function ns.NewsSignFrame()
	return frame
end
