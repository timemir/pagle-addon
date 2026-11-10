---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The news sign's six looks (core/news-sign.md › Looks, SIGN-R50–R56): plain wood on rope, the default, and five to
-- unlock. Each is the kit's canvas motion (the sign kit's engine.js) moved to the sign's drawing kit
-- (adapter/NewsSign.lua): `draw(k, t, s)` places every piece for time t, from the drop; s.exitAt is when the exit
-- began, s.hover eases 0..1, s.top is the screen's top edge (units above the sign's rest), s.news what it shows.
-- Coordinates are UI units from the sign's top left at rest, y down.

local M = ns.NewsSignMath
local TAU, clamp, lerp, seg = M.TAU, M.clamp, M.lerp, M.seg
local easeOutCubic, easeInCubic, easeInOut, easeOutBack = M.easeOutCubic, M.easeInCubic, M.easeInOut, M.easeOutBack
local spring, sway, rng, noise1 = M.spring, M.sway, M.rng, M.noise1
local sin, cos, exp, max, min, sqrt, floor = math.sin, math.cos, math.exp, math.max, math.min, math.sqrt, math.floor

local function rgb(hex)
	return {
		tonumber(hex:sub(1, 2), 16) / 255,
		tonumber(hex:sub(3, 4), 16) / 255,
		tonumber(hex:sub(5, 6), 16) / 255,
	}
end
local WHITE = { 1, 1, 1 }
local WARM = rgb("ffdc90")

-- The rise every hung look shares: a sag of 4 units as the weight is taken, then hauled up off the screen.
local function haul(s, t, from, sag, dur, power)
	if not s.exitAt then
		return 0
	end
	local r = t - s.exitAt
	if r < sag then
		return 4 * sin(math.pi / 2 * r / sag)
	end
	return 4 + (s.top - from) * seg(r, sag, sag + dur) ^ power
end

local LOOKS = ns.NEWS_SIGN_LOOKS

-- ------------------------------------------------------------------ plain wood on rope (SIGN-R51, the default)
LOOKS.wood = {
	key = "wood",
	atlas = "SignWood",
	w = 400,
	h = 112,
	enter = 1.0,
	out = 0.74,
	words = { x = 98, y = 12, w = 270, h = 88 },
	moreOnBoard = false,
	moreW = 196, -- the tag's face
	theme = {
		kick = rgb("e3c896"),
		head = rgb("f6d98a"),
		det = rgb("f1e3c2"),
		more = rgb("f2e4c0"),
		shadow = { 0.04, 0.02, 0, 0.85 },
	},
	sounds = { { "wood_land", 0.46 }, { "wood_creak", 0.84 }, { "wood_creak", 1.6 } },
	outSounds = { { "wood_rise", 0 } },
	draw = function(k, t, s)
		local top, Tf = s.top, 0.46
		local v0 = 9 * TAU / 1.5
		local dx, dy
		if t < Tf then
			dy = (top - 160) * (1 - (t / Tf) ^ 2.2)
			dx = -v0 * (Tf - t)
		else
			dy = spring(t - Tf, 16, 0.42, 0.3)
			dx = sway(t - Tf, 9, 1.5, 1.05)
		end
		dy = dy - 3 * s.hover + haul(s, t, 170, 0.12, 0.62, 2.4)
		local bx, by = -14 + dx, -18 + dy
		k:clipTo(-40, -40, 480, 220)
		for i, rx in ipairs({ 70, 330 }) do
			k:tiles("rope" .. i, "rope", rx, top, bx + 14 + rx, by + 24)
		end
		k:sprite("board", bx, by)
		k:glow("hover", bx + 214, by + 74, 240, WARM, s.hover * 0.22)
		k:emblem(s.news, bx + 60, by + 74)
		k:placeWords(s.words, s.look, dx, dy, t)
		if s.words.more then -- the tag on two short ropes, lagging the swing
			local lag = t > Tf and sway(t - Tf - 0.09, 5, 1.05, 0.85) or 0
			local tw = 236
			local tx, ty = bx + 394 - tw + lag, by + 132
			for i, hx in ipairs({ bx + 394 - tw + 38, bx + 394 - 38 }) do
				k:tiles("twine" .. i, "rope", hx, by + 126, hx + lag, by + 148, { w = 6 })
			end
			k:sprite("tag", tx, ty)
			local f = s.words.more
			f:ClearAllPoints()
			f:SetPoint("CENTER", k.host, "TOPLEFT", tx + 124, -(ty + 29))
			f:SetAlpha(1)
		end
		-- sawdust shaken loose at the catch
		local tau = t - Tf
		if tau > 0 and tau < 1.6 then
			local r = rng(11)
			for i = 1, 22 do
				local x0, vx, vy, life = bx + 214 + (r() - 0.5) * 400, (r() - 0.5) * 30, -r() * 20, 0.8 + r() * 0.8
				local u = tau / life
				local size = 0.6 + r() * 1.1
				if u < 1 then
					k:dot(
						"dust" .. i,
						x0 + vx * tau,
						by + 18 + vy * tau + 120 * tau * tau,
						size,
						rgb("d8b88a"),
						(1 - u) * 0.8,
						{ z = 40 }
					)
				end
			end
		end
	end,
}

-- ------------------------------------------------------------------ the Angler's Scroll (SIGN-R52)
LOOKS.scroll = {
	key = "scroll",
	atlas = "SignScroll",
	w = 400,
	h = 176,
	enter = 1.55,
	out = 0.8,
	words = { x = 128, y = 30, w = 226, h = 96 },
	theme = {
		kick = rgb("8a4a1a"),
		head = rgb("3a1e08"),
		det = rgb("5a3410"),
		more = rgb("4a4a52"),
		shadow = { 1, 0.94, 0.78, 0.5 },
		shadowDy = 0.8,
		moreSize = 16,
	},
	sounds = { { "reel_out", 0 }, { "line_snap", 0.44 }, { "paper_unroll", 0.56 }, { "seal_thump", 1.32 } },
	outSounds = { { "paper_roll", 0 }, { "reel_in", 0.3 } },
	draw = function(k, t, s)
		local top, Tf = s.top, 0.44
		local dy = t < Tf and (top - 120) * (1 - (t / Tf) ^ 2) or spring(t - Tf, 10, 0.38, 0.32)
		local dx = t < Tf and 0 or sway(t - 0.56, 4, 1.7, 1.4) + 0.6 * sin(TAU * t / 3.1)
		dy = dy - 3 * s.hover
		local unroll = easeOutBack(seg(t, 0.56, 1.2), 1.2)
		if s.exitAt then
			local r = t - s.exitAt
			unroll = unroll * (1 - easeInCubic(seg(r, 0, 0.32)))
			dy = dy + seg(r, 0.3, 0.8) ^ 2.2 * (top - 200)
		end
		local x0, y0 = dx, dy
		local paperH = 150 * unroll
		-- the line, the float, the hook
		local bobY = y0 - 46 + (t > Tf and sin(TAU * t / 1.3) * 1.6 or -18 * (1 - t / Tf))
		local ink = rgb("e8e0d0")
		k:line("line1", 200 + x0 * 0.4, top, 200 + x0 * 0.7, bobY, 0.9, ink, 0.85)
		k:line("line2", 200 + x0 * 0.7, bobY + 34, 200 + x0, y0 + 2, 0.9, ink, 0.85)
		k:sprite("bobber", 190 + x0 * 0.7, bobY)
		-- the sheet, unrolled to paperH, clipped; the words on it
		k:clipTo(x0 + 28, y0 + 13, 344, paperH)
		if paperH > 0.5 then
			k:sprite("paper", x0 + 28, y0 + 13, { on = "clip" })
		end
		k:placeWords(s.words, s.look, dx, dy, t)
		-- the wax seal and its emblem, slammed on once the sheet is open
		local sealU = seg(t, 1.2, 1.38)
		if sealU > 0 and unroll > 0.9 then
			local sc = sealU < 1 and lerp(2.4, 1, easeInCubic(sealU))
				or 1 + 0.08 * exp(-(t - 1.38) * 14) * cos((t - 1.38) * 40)
			k:sprite("seal", x0 + 34, y0 + 30, { scale = sc, alpha = sealU, on = "front" })
			k:emblem(s.news, x0 + 72, y0 + 68, { scale = sc * 0.9, alpha = sealU, on = "front" })
			if t > 1.38 and t < 2 then
				local u = (t - 1.38) / 0.6
				k:ring(
					"shock",
					x0 + 72,
					y0 + 68,
					40 + 50 * easeOutCubic(u),
					40 + 50 * easeOutCubic(u),
					rgb("fff4dc"),
					(1 - u) * 0.7,
					{ on = "front" }
				)
				local r = rng(4)
				for i = 1, 12 do
					local a2, sp = r() * TAU, 40 + r() * 60
					k:dot(
						"wax" .. i,
						x0 + 72 + cos(a2) * (30 + sp * u * 0.6),
						y0 + 68 + sin(a2) * (30 + sp * u * 0.6) + 30 * u * u,
						1.2,
						rgb("b82a20"),
						1 - u,
						{ on = "front", z = 60 }
					)
				end
			end
		end
		k:sprite("rod", x0, y0, { on = "front" })
		k:sprite("roller", x0, y0 + paperH - 1, { on = "front" })
		k:glow("hover", x0 + 200, y0 + 80, 220, WARM, s.hover * 0.3)
	end,
}

-- ------------------------------------------------------------------ the Lantern of the Deep (SIGN-R53)
LOOKS.lantern = {
	key = "lantern",
	atlas = "SignLantern",
	w = 460,
	h = 100,
	enter = 2.1,
	out = 1.1,
	words = { x = 100, y = 10, w = 264, h = 80 },
	theme = {
		kick = rgb("8fe0d8"),
		head = rgb("ffe7a8"),
		det = rgb("cfeee8"),
		more = rgb("9fd8d0"),
		shadow = { 0, 0, 0, 0.6 },
	},
	sounds = { { "chain_lower", 0 }, { "lantern_clank", 0.78 }, { "ignite", 1.0 }, { "glass_chime", 1.25 } },
	outSounds = { { "snuff", 0 }, { "chain_raise", 0.35 } },
	draw = function(k, t, s)
		local top, T = s.top, 0.8
		local dy = t < T and (top - 160) * (1 - easeOutCubic(t / T)) or spring(t - T, 6, 0.5, 0.35)
		dy = dy - 3 * s.hover
		local lit, out = clamp(seg(t, 1.0, 1.25)), 0
		if s.exitAt then
			local r = t - s.exitAt
			out = seg(r, 0, 0.3)
			lit = lit * (1 - out)
			dy = dy + seg(r, 0.4, 1.1) ^ 2.3 * (top - 200)
		end
		local swing = t < T and 0.25 * (1 - t / T) or sway(t - T, 0.22, 1.15, 1.3) + 0.03 * sin(TAU * t / 2.7)
		local y0 = dy
		local flick = 1 + 0.12 * (noise1(t * 9, 1) - 0.5) + 0.06 * (noise1(t * 23, 2) - 0.5)
		local amber = rgb("ff9a3c")
		k:clipTo(-20, y0 - 40, 500, 200)
		-- the light it throws on everything behind
		k:glow("light", 440, y0 + 80, 380, amber, lit * 0.45 * flick * (1 + 0.4 * s.hover), { z = 0 })
		-- chains to the bar, the bar, short chains to the pane
		for i, cx in ipairs({ 40, 360 }) do
			k:tiles("chain" .. i, "chain", cx, top, cx, y0 - 18, { w = 8 })
		end
		k:sprite("bar", -20, y0 - 32)
		for i, cx in ipairs({ 72, 332 }) do
			k:tiles("short" .. i, "chain", cx, y0 - 12, cx, y0 + 2, { w = 7 })
		end
		k:sprite("pane", -12, y0 - 14)
		k:emblem(s.news, 50, y0 + 50, { alpha = 0.35 + 0.65 * lit })
		k:glow("panelight", 300, y0 + 50, 220, amber, lit * 0.25 * flick)
		-- the words light up one line after another once it's lit
		k:placeWords(s.words, s.look, 0, dy, t, function(i)
			return clamp((t - (1.15 + 0.22 * (i - 1))) / 0.4) * (1 - out)
		end)
		-- the lantern on its chain from the bar's right curl, swinging on its own
		local lx, ly = 418, y0 - 12
		local px = lx + sin(swing) * 70
		k:tiles("lchain", "chain", lx, ly, px, ly + 18, { w = 6, on = "front" })
		k:sprite("lantern", px - 32, ly + 14, { scale = 1.3, cx = 32, cy = 0, on = "front" })
		if lit > 0 then
			k:sprite("lit", px - 32, ly + 14, { scale = 1.3, cx = 32, cy = 0, alpha = lit, on = "front" })
			k:glow("flame", px, ly + 100, 60, rgb("ffdc8c"), lit * 0.9 * flick, { on = "front" })
			k:sprite(
				"lit",
				px - 32,
				ly + 14,
				{ key = "litadd", scale = 1.3, cx = 32, cy = 0, alpha = lit * 0.6 * flick, blend = "ADD", on = "front" }
			)
		end
		-- the strike: a flash as it lights
		local strike = seg(t, 1.0, 1.25)
		if strike > 0 and strike < 1 then
			k:glow("strike", px, ly + 100, 180, rgb("fff0c8"), (1 - strike) * 0.9, { on = "front" })
			k:sparkle("strikestar", px, ly + 100, 34 * (1 - strike) + 6, 1 - strike, nil, { on = "front" })
		end
		-- smoke as it's snuffed
		if s.exitAt then
			local r = t - s.exitAt
			local rr = rng(8)
			for i = 1, 8 do
				local d = rr() * 0.3
				local u = (r - d) / 1.1
				local jx = (rr() - 0.5) * 10
				if u > 0 and u < 1 then
					k:common(
						"puff",
						"smoke" .. i,
						px + jx + sin(u * 6 + i) * 6,
						ly + 90 - u * 70,
						{ 8 + u * 20, 8 + u * 20 },
						{ tint = rgb("9a9aa8"), alpha = (1 - u) * 0.35, on = "front" }
					)
				end
			end
		end
		-- fireflies, drawn out by the light
		local fr = rng(21)
		for i = 1, 9 do
			local ph, cx, cy, ax, ay, sp =
				fr() * TAU, 120 + fr() * 340, -40 + fr() * 170, 30 + fr() * 50, 14 + fr() * 24, 0.25 + fr() * 0.3
			local blinkRate = 0.6 + fr() * 0.5
			local a = clamp((t - (1.2 + i * 0.12)) / 0.5) * lit
			if a > 0 then
				local x, y = cx + ax * sin(TAU * sp * t + ph), y0 + cy + ay * sin(TAU * sp * 1.7 * t + ph * 2)
				local blink = 0.5 + 0.5 * sin(TAU * blinkRate * t + ph)
				k:glow("ffg" .. i, x, y, 9, rgb("d2ff8c"), a * (0.25 + 0.5 * blink), { on = "front", z = 70 })
				k:dot("ff" .. i, x, y, 1.2, rgb("f6ffd8"), a * (0.4 + 0.6 * blink), { on = "front", z = 71 })
			end
		end
	end,
}

-- ------------------------------------------------------------------ the Kraken's Gift (SIGN-R54)
-- A tentacle from `base` (above the screen) to `grip`: a centreline bent by a travelling wave, its body discs tapering
-- to the tip, suckers along its inner side, then its tip curled round the tablet's corner by o.curl (0..1).
local function tentacle(k, key, base, grip, t, o)
	local N = 34
	local pts = {}
	local dx, dy = grip[1] - base[1], grip[2] - base[2]
	local L = sqrt(dx * dx + dy * dy)
	local nx, ny = -dy / L, dx / L
	for i = 0, N do
		local u = i / N
		local env = sin(math.pi * u) * (1 - u * 0.4)
		local w = o.amp * env * sin(TAU * (u * 1.3 - t * o.freq)) + o.bow * sin(math.pi * u)
		pts[#pts + 1] = { base[1] + dx * u + nx * w, base[2] + dy * u + ny * w }
	end
	local last, prev = pts[#pts], pts[#pts - 1]
	local ang = math.atan2(last[2] - prev[2], last[1] - prev[1])
	local curlN = 16
	for i = 1, floor(curlN * o.curl) do
		local u = i / curlN
		local r = 16 * (1 - u * 0.78)
		ang = ang + 0.42 * (1 + u * 1.2) * o.dir
		local p = pts[#pts]
		pts[#pts + 1] = { p[1] + cos(ang) * r * 0.42, p[2] + sin(ang) * r * 0.42 }
	end
	local count = #pts
	local dark, light = rgb("2a0c3a"), rgb("b05a96")
	for i = 1, count do
		local u = (i - 1) / (count - 1)
		local w = o.width * (1 - 0.82 * u) + 1.2
		local c = { lerp(dark[1], light[1], u), lerp(dark[2], light[2], u), lerp(dark[3], light[3], u) }
		k:common(
			"disc",
			key .. "d" .. i,
			pts[i][1],
			pts[i][2],
			{ w * 1.15, w * 1.15 },
			{ tint = c, on = o.on, z = o.z }
		)
		if i % 3 == 0 and i < count - 1 then
			local a, b = pts[max(1, i - 1)], pts[min(count, i + 1)]
			local tx, ty = b[1] - a[1], b[2] - a[2]
			local l = sqrt(tx * tx + ty * ty)
			if l > 0 then
				local sx, sy = pts[i][1] + ty / l * w * 0.32, pts[i][2] - tx / l * w * 0.32
				local r = w * 0.18 * (1 + 0.12 * sin(t * 6 + i))
				k:common("sucker", key .. "s" .. i, sx, sy, { r * 2, r * 2 }, { on = o.on, z = o.z + 1 })
			end
		end
	end
end

LOOKS.kraken = {
	key = "kraken",
	atlas = "SignKraken",
	w = 392,
	h = 112,
	enter = 1.6,
	out = 0.75,
	words = { x = 104, y = 16, w = 270, h = 78 },
	theme = {
		kick = rgb("7fe8c8"),
		head = rgb("d8fff0"),
		det = rgb("bfe8dc"),
		more = rgb("7fe8c8"),
		shadow = { 0, 0.04, 0.03, 0.8 },
		shadowDy = 1.2,
	},
	sounds = {
		{ "ink_burst", 0 },
		{ "kraken_groan", 0.2 },
		{ "tentacle_slap", 0.58 },
		{ "drip", 1.4 },
		{ "drip", 2.3 },
	},
	outSounds = { { "whoosh_up", 0 }, { "ink_burst", 0.1 } },
	draw = function(k, t, s)
		local top, Tf = s.top, 0.58
		local dy = t < Tf and (top - 170) * (1 - easeOutCubic(t / Tf)) ^ 1.2 or spring(t - Tf, 13, 0.46, 0.3)
		dy = dy - 3 * s.hover
		if s.exitAt then
			dy = dy + seg(t - s.exitAt, 0.05, 0.6) ^ 2.5 * (top - 240)
		end
		local sw = t < Tf and 0 or sway(t - Tf, 5, 1.6, 1.4) + 1.5 * sin(TAU * t / 3.3)
		local x0, y0 = sw, dy
		local settle = exp(-max(0, t - Tf) / 0.7)
		local amp = (t < Tf and 26 or 6 + 20 * settle) + 10 * s.hover + (s.exitAt and 26 or 0)
		k:clipTo(-40, y0 - 40, 480, 200)
		-- ink where it came from
		local function ink(tau, n, seed)
			local r = rng(seed)
			for i = 1, n do
				local d = r() * 0.15
				local x, y = 330 + (r() - 0.5) * 220, top + 6 + r() * 30
				local jx, jy, jr = r() - 0.5, r(), r()
				local u = (tau - d) / 1.3
				if u > 0 and u < 1 then
					local R = 26 + 46 * easeOutCubic(u) + jr * 18
					k:common(
						"puff",
						"ink" .. seed .. i,
						x + jx * 90 * u,
						y + 60 * u * jy,
						{ R * 2, R * 2 },
						{ tint = rgb("2a0a3c"), alpha = (1 - u) * 0.85, z = 2 }
					)
				end
			end
		end
		ink(t, 14, 3)
		if s.exitAt then
			ink(t - s.exitAt - 0.1, 14, 9)
		end
		k:glow("deep", x0 + 200, y0 + 56, 260, rgb("3cc8aa"), 0.12 + 0.06 * sin(TAU * t / 2.4) + 0.1 * s.hover)
		-- a second, smaller tentacle coiling behind the tablet's left end
		local t2 = clamp((t - 0.7) / 0.6) * (s.exitAt and 1 - seg(t - s.exitAt, 0, 0.3) or 1)
		if t2 > 0 then
			tentacle(k, "t2", { 20 + x0, top - 20 }, { 6 + x0, y0 + 30 + 40 * (1 - t2) }, t * 0.8, {
				amp = 8,
				freq = 0.5,
				bow = -22,
				width = 26,
				curl = t2 * 0.9,
				dir = -1,
				on = "back",
				z = 10,
			})
		end
		k:sprite("tablet", x0 - 10, y0 - 12, { z = 30 })
		k:emblem(s.news, x0 + 52, y0 + 56, { z = 32 })
		k:glow("pearl", x0 + 60, y0 + 56, 60, rgb("50ffc8"), 0.18 + 0.15 * s.hover, { z = 33 })
		k:placeWords(s.words, s.look, sw, dy, t)
		-- the runes along its foot glow in waves
		for i = 0, 9 do
			local a = 0.3 + 0.7 * max(0, sin(TAU * (t / 2.4 - i / 10)))
			k:glow("rune" .. i, x0 + 114 + i * 26, y0 + 101, 9, rgb("5affc8"), a * 0.45, { z = 34 })
		end
		-- drips off its edge
		local dr = rng(33)
		for i = 1, 6 do
			local ph, per, x = dr() * 2, 1.6 + dr() * 1.2, x0 + 30 + dr() * 340
			local tt = t - Tf - ph
			if tt >= 0 then
				local fall = (tt % per)
				if fall < 0.7 then
					k:common(
						"drop",
						"drip" .. i,
						x,
						y0 + 112 + 160 * fall * fall,
						{ 3, 4.8 },
						{ alpha = (1 - fall / 0.7) * 0.9, z = 35 }
					)
				end
			end
		end
		-- the main tentacle: down from the deep, its tip round the tablet's right end
		tentacle(k, "t1", { 290 + x0 * 0.2, top - 30 }, { x0 + 382, y0 - 2 }, t, {
			amp = amp * 1.3,
			freq = 0.9,
			bow = 46,
			width = 54,
			curl = easeOutCubic(seg(t, Tf - 0.05, Tf + 0.45)),
			dir = 1,
			on = "front",
			z = 20,
		})
		-- bubbles rising from behind it
		local br = rng(41)
		for i = 1, 10 do
			local per = 2.4 + br() * 1.6
			local ph, x, size = br() * per, x0 + 40 + br() * 340, 1.4 + br() * 2
			local tt = t - Tf - ph
			if tt >= 0 then
				local u = (tt % per) / per
				k:dot(
					"bub" .. i,
					x + sin(u * 9 + i) * 4,
					y0 + 100 - u * 150,
					size,
					rgb("c8fffa"),
					(1 - u) * 0.5,
					{ on = "front", z = 60 }
				)
			end
		end
	end,
}

-- ------------------------------------------------------------------ the Starfall Astrolabe (SIGN-R55)
LOOKS.astro = {
	key = "astro",
	atlas = "SignAstro",
	w = 392,
	h = 100,
	enter = 1.5,
	out = 0.9,
	words = { x = 138, y = 4, w = 242, h = 84 },
	theme = {
		kick = rgb("c8d0ff"),
		head = rgb("fff2c4"),
		det = rgb("dfe4ff"),
		more = rgb("b8c4ff"),
		shadow = { 0, 0, 0.08, 0.7 },
		headSize = 17,
	},
	sounds = { { "star_fall", 0 }, { "star_impact", 0.55 }, { "astro_spin", 0.7 } },
	outSounds = { { "astro_out", 0 } },
	draw = function(k, t, s)
		local hit, cx, cy = 0.55, 62, 50
		local fy = -3 * s.hover + 2 * sin(TAU * t / 3.6)
		local col = s.exitAt and seg(t - s.exitAt, 0, 0.55) or 0
		local blue, gold = rgb("b4c8ff"), rgb("ffe9a8")
		-- the falling star and its trail
		if t < hit + 0.05 then
			local function at(tt)
				local u = easeInCubic(seg(tt, 0, hit))
				return lerp(780, cx, u), lerp(-330, cy, u) - 60 * sin(math.pi * u)
			end
			for i = 0, 17 do
				local x, y = at(t - i * 0.016)
				k:dot(
					"trail" .. i,
					x,
					y,
					5 * (1 - i / 18),
					i < 4 and WHITE or rgb("9fb4ff"),
					(1 - i / 18) * 0.8,
					{ on = "front", z = 10, blend = "ADD" }
				)
			end
			local sx, sy = at(t)
			k:glow("star", sx, sy, 50, blue, 0.9, { on = "front" })
			k:sparkle("starglint", sx, sy, 16, 1, nil, { on = "front" })
		end
		k:clipTo(0, fy - 12, 0.01, 140)
		local kk = t - hit
		if kk > 0 and kk < 1.2 then
			k:glow(
				"flash",
				cx,
				cy,
				220 * easeOutCubic(clamp(kk / 0.4)),
				rgb("c8d7ff"),
				(1 - clamp(kk / 0.5)) * 0.85,
				{ on = "front" }
			)
			local rr = 20 + 260 * easeOutCubic(clamp(kk / 0.8))
			k:ring("shock", cx, cy, rr, rr, rgb("cfd8ff"), (1 - clamp(kk / 0.8)) * 0.8, { on = "front" })
			local r = rng(5)
			for i = 1, 24 do
				local a, sp, life, size, warm = r() * TAU, 60 + r() * 180, 0.6 + r() * 0.6, 3 + r() * 4, r() < 0.3
				local u = kk / life
				if u < 1 then
					local e = easeOutCubic(u)
					k:sparkle(
						"burst" .. i,
						cx + cos(a) * sp * e,
						cy + sin(a) * sp * e + 30 * u * u,
						size,
						1 - u,
						warm and gold or nil,
						{ on = "front", z = 72 }
					)
				end
			end
		end
		if t < hit then
			return
		end
		-- the plate opens out of the ring to the right, its words with it; then the rings
		local open = easeInOut(seg(t, hit + 0.2, hit + 0.85)) * (1 - easeInCubic(seg(col, 0, 0.45)))
		local pw = 392 * open
		k:clipTo(0, fy - 12, pw, 140)
		if pw > 1 then
			k:sprite("plate", -12, fy - 12, { on = "clip", z = 0 })
			-- a constellation drawn across it, star by star
			local stars = { { 150, 18 }, { 196, 34 }, { 238, 22 }, { 286, 40 }, { 330, 26 }, { 362, 62 } }
			local drawn = seg(t, hit + 0.6, hit + 1.4) * (#stars - 1)
			for i = 1, #stars - 1 do
				local u = clamp(drawn - (i - 1))
				if u <= 0 then
					break
				end
				local a1, b1, a2, b2 = stars[i][1], stars[i][2], stars[i + 1][1], stars[i + 1][2]
				k:line(
					"con" .. i,
					a1,
					b1 + fy,
					lerp(a1, a2, u),
					lerp(b1, b2, u) + fy,
					0.7,
					rgb("b8c4ff"),
					0.35,
					{ on = "clip", z = 2, gap = 6 }
				)
			end
			for i, st in ipairs(stars) do
				local tw = 0.5 + 0.5 * sin(TAU * (t * 0.7 + i * 0.37))
				if drawn >= i - 1.01 then
					k:sparkle(
						"cs" .. i,
						st[1],
						st[2] + fy,
						3 + 2 * tw,
						0.35 + 0.4 * tw,
						rgb("e6ecff"),
						{ on = "clip", z = 3 }
					)
				end
			end
			if open < 1 then
				k:glow("edge", pw, fy + 50, 40, rgb("dce6ff"), 0.8, { on = "front" })
				k:line("edgeline", pw, fy - 2, pw, fy + 102, 1.6, rgb("f0f4ff"), 0.9, { on = "front" })
			end
		end
		k:placeWords(s.words, s.look, 0, fy, t)
		local grow = easeOutBack(seg(t, hit, hit + 0.55), 1.4) * (1 - easeInCubic(col))
		local spin = 1 - easeOutCubic(seg(t, hit, hit + 1.1))
		local speed = 1 + 2.5 * s.hover
		local aO, aI, aA = spin * 7 + t * 0.1 * speed, -spin * 9 - t * 0.17 * speed, sin(t * 0.8) * 0.6 + spin * 4
		k:glow(
			"ringglow",
			cx,
			cy + fy,
			90,
			rgb("8ca0ff"),
			(0.25 + 0.2 * sin(TAU * t / 2.8) + 0.25 * s.hover) * grow,
			{ on = "front" }
		)
		if grow > 0.01 then
			k:sprite("arm", cx - 70, cy + fy - 70, { scale = grow * 1.25, rot = aA, alpha = 0.8, on = "front" })
			k:sprite("inner", cx - 70, cy + fy - 70, { scale = grow, rot = aI, alpha = 0.9, on = "front" })
			k:sprite("outer", cx - 70, cy + fy - 70, { scale = grow, rot = aO, on = "front" })
			k:emblem(s.news, cx, cy + fy, { scale = grow * 0.95, on = "front" })
		end
		-- a little shooting star now and then
		local per = 3.7
		local u = ((t - 2.2) % per) / 0.5
		if t > 2.2 and u < 1 and col == 0 then
			local x, y = lerp(370, 180, u), lerp(fy - 30, fy + 30, u)
			k:dot("shoot", x, y, 1.6, WHITE, 1 - u, { on = "front", blend = "ADD" })
			k:line("shoottail", x, y, x + 30, y - 10, 0.8, rgb("c8d4ff"), (1 - u) * 0.6, { on = "front", gap = 4 })
		end
		-- the exit: gathered to a point that shoots up
		if col > 0 then
			local uu = seg(col, 0.5, 1)
			local y = lerp(cy, -420, easeInCubic(uu))
			local a = sin(math.pi * clamp(col * 1.3))
			k:glow("gone", cx, y + fy, 60, rgb("c8d7ff"), 0.9 * a, { on = "front" })
			k:sparkle("gonestar", cx, y + fy, 14, a, nil, { on = "front" })
		end
	end,
}

-- ------------------------------------------------------------------ the Coral Splash (SIGN-R56)
LOOKS.coral = {
	key = "coral",
	atlas = "SignCoral",
	w = 392,
	h = 108,
	enter = 1.4,
	out = 0.9,
	words = { x = 108, y = 12, w = 256, h = 76 },
	moreY = 75, -- above the pearls
	theme = {
		kick = rgb("9ff0f0"),
		head = WHITE,
		det = rgb("d6f6f4"),
		more = rgb("bdf4ee"),
		shadow = { 0, 0.12, 0.16, 0.7 },
		shadowDy = 1.2,
	},
	sounds = { { "drop_fall", 0 }, { "splash", 0.46 }, { "bubbles", 0.7 } },
	outSounds = { { "splash_down", 0 } },
	draw = function(k, t, s)
		local hit, ix, iy = 0.46, 200, 52
		local bob = 2 * sin(TAU * t / 3.2) - 3 * s.hover
		local col = s.exitAt and seg(t - s.exitAt, 0, 0.7) or 0
		local foam = rgb("d8faff")
		-- the drop
		if t < hit then
			local u = (t / hit) ^ 2
			local y = lerp(-360, iy, u)
			local st = 1 + 1.2 * u
			k:common("drop", "drop", ix, y, { 24 / sqrt(st), 38 * st }, { on = "front" })
			k:glow("dropglow", ix, y, 30, rgb("a0f0ff"), 0.5, { on = "front" })
			k:clipTo(0, 0, 0.01, 0.01)
			k:placeWords(s.words, s.look, 0, bob, t, function()
				return 0
			end)
			return
		end
		local kk = t - hit
		-- the plaque surfaces where the drop landed: up from the water, overshooting a little
		local rise = clamp(kk / 0.35) * (1 - easeInCubic(col))
		local sc = (0.55 + 0.45 * easeOutBack(clamp(kk / 0.5), 1.6)) * (1 - 0.4 * easeInCubic(col))
		local function scaled(x, y)
			return ix + (x - ix) * sc, iy + bob + (y - iy) * sc
		end
		-- kelp behind, growing up, then swaying
		local grow = easeOutBack(seg(t, 0.75, 1.25)) * (1 - col)
		if grow > 0 then
			k:sprite("kelp1", -6 + 4 * sin(TAU * t / 2.6), 30 + bob, { sy = grow, cy = 130, z = 1 })
			k:sprite("kelp2", 360 + 4 * sin(TAU * t / 2.9 + 1.4), 26 + bob, { sy = grow, cy = 130, z = 2 })
			k:sprite(
				"kelp1",
				384 + 4 * sin(TAU * t / 2.2 + 0.5),
				40 + bob,
				{ key = "kelp1b", sy = grow * 0.8, cy = 130, z = 3 }
			)
		end
		local px, py = scaled(-44, -44)
		k:sprite("plaque", px, py, { scale = sc, cx = 0, cy = 0, alpha = rise, z = 10 })
		local ex, ey = scaled(52, 54)
		k:emblem(s.news, ex, ey, { scale = sc, alpha = rise, z = 12 })
		-- light dancing over its water panel
		local qx, qy = scaled(98, 12)
		k:clipTo(qx, qy, 276 * sc, 82 * sc)
		for i = 0, 5 do
			local x = 98 + ((i * 53 + t * 22) % 300)
			local y = 12 + 41 + 26 * sin(t * 1.3 + i * 1.7)
			local cxs, cys = scaled(x, y)
			k:glow(
				"caustic" .. i,
				cxs,
				cys,
				34 + 8 * sin(t * 2 + i),
				rgb("a0ffff"),
				0.12 * rise,
				{ on = "clip", z = 1 }
			)
		end
		k:placeWords(s.words, s.look, 0, bob, t, function()
			return clamp((kk - 0.3) / 0.4) * (1 - col)
		end)
		-- the splash: rings, a crown of drops, a flash
		if kk < 1.4 then
			for i = 0, 2 do
				local u = clamp((kk - i * 0.12) / 1)
				if u > 0 and u < 1 then
					k:ring("ripple" .. i, ix, iy + bob, 30 + 300 * u, 8 + 70 * u, foam, (1 - u) * 0.7, { on = "front" })
				end
			end
			local r = rng(7)
			for i = 1, 30 do
				local a, sp, life, size = math.pi + r() * math.pi, 80 + r() * 180, 0.7 + r() * 0.5, 1.4 + r() * 2.4
				local u = kk / life
				if u < 1 then
					k:dot(
						"spray" .. i,
						ix + cos(a) * sp * kk,
						iy + sin(a) * sp * kk * 1.2 + 260 * kk * kk,
						size,
						rgb("e6fcff"),
						(1 - u) * 0.9,
						{ on = "front", z = 60 }
					)
				end
			end
			k:glow("splash", ix, iy, 160, rgb("b4faff"), (1 - clamp(kk / 0.35)) * 0.7, { on = "front" })
		end
		-- bubbles from the coral, all the while
		if col == 0 then
			local br = rng(51)
			for i = 1, 14 do
				local per = 1.8 + br() * 1.8
				local ph = br() * per
				local left = br() < 0.5
				local x = left and -10 + br() * 50 or 330 + br() * 70
				local rr = (1.2 + br() * 2.6) * (1 + s.hover)
				local tt = t - 0.8 - ph
				if tt >= 0 then
					local u = (tt % per) / per
					local bx, by = x + sin(u * 10 + i) * 3, 100 + bob - u * 180
					k:ring(
						"bubble" .. i,
						bx,
						by,
						rr,
						rr,
						foam,
						(1 - u) * 0.8,
						{ on = "front", z = 61, blend = "BLEND" }
					)
					k:dot(
						"bubblehi" .. i,
						bx - rr * 0.35,
						by - rr * 0.35,
						rr * 0.3,
						WHITE,
						(1 - u) * 0.8,
						{ on = "front", z = 62 }
					)
				end
			end
		end
		-- pearls catch the light now and then
		local pg = (t * 0.6) % 1
		if kk > 1 then
			k:sparkle("pearl", 160 + 220 * pg, 100 + bob, 4, sin(math.pi * pg) * 0.8, nil, { on = "front" })
		end
		-- the exit: the water closes and runs off as drops
		if col > 0 then
			local r = rng(17)
			for i = 1, 30 do
				local x, y0, d, size = 20 + r() * 380, r() * 100, r() * 0.2, 1.6 + r() * 1.6
				local u = clamp((col - d) / 0.8)
				if u > 0 and u < 1 then
					k:dot("run" .. i, x, y0 + 200 * u * u, size, rgb("cff6ff"), 1 - u, { on = "front", z = 63 })
				end
			end
		end
	end,
}
