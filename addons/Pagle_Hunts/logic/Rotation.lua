if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The fallback rotation (HNT-R152, HNT-R156, ADR 0012 and its note): pure logic, everything passed in (CORE-R7); the
-- starting point (`ns.ROTATION_ORIGIN`) is read at call time, so a spec can move it. Every client must agree on every
-- pick, so the arithmetic is exact and written out in HNT-R152: slots of 72 hours from the origin, cycling the
-- low, mid and high bands, each band's visits taking its events in a Fisher–Yates shuffle seeded by the FNV-1a hash
-- of "<band>:<pass>", drawn from a 32-bit linear congruential generator. Which slot gets logged, and when, is the run
-- log's (logic/RunLog.lua, HNT-R151, HNT-R153).

--- Tunables (hunts.md): the rotation's starting point, 15:00 UTC. Before 1.0 a placeholder in the past so dogfooding
--- has runs: Monday 19 October 2026 15:00 UTC, the Monday before #300 landed. #275's checklist sets it to 1.0's
--- release day.
ns.ROTATION_ORIGIN = 1792422000

--- Tunables (hunts.md): every fallback run's length, and the default run length (HNT-R142, HNT-R152): 72 hours.
ns.RUN_LENGTH = 72 * 3600

--- The bands in slot order: slot `k`'s band is `ROTATION_BANDS[k mod 3 + 1]` (HNT-R152, HNT-R156).
ns.ROTATION_BANDS = { "low", "mid", "high" }

local TWO_32 = 4294967296
local bxor, byte = bit.bxor, string.byte -- luacheck: read globals bit

--- FNV-1a 32-bit over a string's bytes (LOG-R66 step 1): `h = 2166136261`; for each byte `c`, `h = bxor(h, c) % 2^32`,
--- then `h * 16777619 mod 2^32`, split so no product passes 2^53. Every `bit` result is taken mod 2^32, as LuaBitOp's
--- are signed. Hunts' own copy (ADR 0001: no Core internals).
---@param text string
---@return integer h in [0, 2^32)
function ns.Fnv1a(text)
	local h = 2166136261
	for i = 1, #text do
		h = bxor(h, byte(text, i)) % TWO_32
		h = ((h % 256) * 16777216 + h * 403) % TWO_32 -- h * 16777619 mod 2^32
	end
	return h
end

--- The rotation's generator (HNT-R152): the 32-bit linear congruential step `x = (1664525 × x + 1013904223) mod 2^32`.
--- The product stays below 2^53 (1664525 × (2^32 − 1) < 2^53), so plain arithmetic is exact on every client.
---@param x integer in [0, 2^32)
---@return integer in [0, 2^32)
function ns.RotationStep(x)
	return (1664525 * x + 1013904223) % TWO_32
end

--- A Fisher–Yates shuffle of `list` seeded by the FNV-1a hash of `seedText` (HNT-R152), as a new list: with `x` the
--- hash, for each 0-based position `i` from `n − 1` down to 1, `x` steps once (ns.RotationStep) and position `i`
--- swaps with `floor(x × (i + 1) / 2^32)`. `list` itself is left as it was.
---@generic T
---@param list T[]
---@param seedText string
---@return T[]
function ns.SeededShuffle(list, seedText)
	local out = { unpack(list) }
	local x = ns.Fnv1a(seedText)
	for i = #out - 1, 1, -1 do
		x = ns.RotationStep(x)
		local r = math.floor(x * (i + 1) / TWO_32)
		out[i + 1], out[r + 1] = out[r + 1], out[i + 1]
	end
	return out
end

--- The fallback slot holding server time `t` (HNT-R152): `floor((t − origin) / 72 h)`, or nil before the origin.
---@param t integer
---@return integer?
function ns.RotationSlotAt(t)
	local origin = ns.ROTATION_ORIGIN
	if t < origin then
		return nil
	end
	return math.floor((t - origin) / ns.RUN_LENGTH)
end

--- One fallback slot (HNT-R152): its number, its span `[origin + 72 h × k, origin + 72 h × (k + 1))` and its band.
---@class HuntsRotationSlot
---@field slot integer
---@field start integer
---@field end_ integer
---@field band "low"|"mid"|"high"

--- Slot `k` (k >= 0) of the fallback rotation (HNT-R152).
---@param k integer
---@return HuntsRotationSlot
function ns.RotationSlot(k)
	local start = ns.ROTATION_ORIGIN + ns.RUN_LENGTH * k
	return { slot = k, start = start, end_ = start + ns.RUN_LENGTH, band = ns.ROTATION_BANDS[k % 3 + 1] }
end

--- The events of `band` the rotation picks from at server time `at` (HNT-R152, HNT-R156, DATA-R98): those of `pool`
--- with `rotation` and no `retired` at or before `at`, in event-ID order. Pushed events never rotate (HNT-R140).
---@param pool HuntEvent[] the pool's events (ns.events:Events())
---@param band "low"|"mid"|"high"
---@param at integer a slot's start
---@return HuntEvent[]
function ns.RotationBand(pool, band, at)
	local out = {}
	for _, event in ipairs(pool) do
		if
			event.rotation
			and not event.pushed
			and event.band == band
			and not (event.retired and event.retired <= at)
		then
			out[#out + 1] = event
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

--- Slot `k`'s picks in the order the rotation tries them (HNT-R152, HNT-R153): its band's visit `j = floor(k / 3)`
--- picks `perm_{b,p}[j mod n_b]`, `p = floor(j / n_b)`, from the band at the slot's start; then visits `j + 1`, `j + 2`,
--- …, each event once, until every event of the band is listed ("the next pick in its band"). Empty for an empty
--- band.
---@param pool HuntEvent[]
---@param k integer
---@param origin integer? trusted archived origin for backend validation
---@param length integer? trusted archived run length
---@return HuntEvent[]
function ns.RotationPicks(pool, k, origin, length)
	local slot = ns.RotationSlot(k)
	if origin and length then
		slot.start = origin + length * k
	end
	local events = ns.RotationBand(pool, slot.band, slot.start)
	local n = #events
	local picks, seen, perms = {}, {}, {}
	local j = math.floor(k / 3)
	-- Two passes' worth of visits from j hold every event: the rest of pass p, then the whole of pass p + 1.
	for visit = j, j + 2 * n - 1 do
		local pass = math.floor(visit / n)
		local perm = perms[pass]
		if not perm then
			perm = ns.SeededShuffle(events, slot.band .. ":" .. pass)
			perms[pass] = perm
		end
		local event = perm[visit % n + 1]
		if not seen[event.id] then
			seen[event.id] = true
			picks[#picks + 1] = event
		end
		if #picks == n then
			break
		end
	end
	return picks
end

--- Slot `k`'s event (HNT-R152, HNT-R153): its first pick for which `busy(event)` is false (the band's next pick when
--- the slot's own already has a run on), or nil when every pick is busy or its band is empty. Without `busy`, the
--- slot's own pick.
---@param pool HuntEvent[]
---@param k integer
---@param busy (fun(event: HuntEvent): boolean)?
---@return HuntEvent?
function ns.RotationPick(pool, k, busy)
	for _, event in ipairs(ns.RotationPicks(pool, k)) do
		if not busy or not busy(event) then
			return event
		end
	end
	return nil
end
