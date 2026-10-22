---@class PagleNS
local ns = select(2, ...)

-- Simulated Size (LOG-R65–R68, ADR 0014): a Species Catch's length and Size band, from its Catch ID, bounded by a
-- Reach of the Cast's fishing skill and the Angler's earlier Catches of the item; a Legend's from its Catch ID alone
-- (ADR 0010). Pure logic on Lua 5.1 numbers and the client's `bit` library (LuaBitOp), every intermediate of the hash
-- kept exact below 2^53 (LOG-R66).

--- A Simulated Size (LOG-R65–R67).
---@class PagleSize
---@field length integer         -- whole millimetres
---@field band integer           -- 1 Tiddler … 5 Monster

--- Changes whenever how a size is drawn changes; a Module that stores sizes folds it into its rules version
--- (LOG-R68). 2 from the Reach (ADR 0014). Tunable before 1.0.
ns.SIZE_RULES_VERSION = 2

--- Tunable: a Legend's multipliers of the typical length at each of its band edges, from Tiddler's low edge to
--- Monster's high one (LOG-R67). The two ends are the full range's, frozen; a change to the inner four changes
--- ns.SIZE_RULES_VERSION.
ns.SIZE_MULTIPLIERS = { 0.55, 0.75, 1.10, 1.30, 1.55, 1.80 }

-- Frozen (LOG-R68, ADR 0010): a Legend's band edges of the percentile, never tunable. Band i is
-- [CUTS[i], CUTS[i + 1]). spec/Pagle/logic/Size_spec.lua pins them as the 1.0 freeze (#267), with every constant of
-- ns.SizeHash below and of the Reach.
local CUTS = { 0, 0.15, 0.70, 0.93, 0.995, 1 }

-- Frozen (LOG-R67, LOG-R68, ADR 0014): the skill rank and the earlier Catches at which each reach is full, the full
-- range (RANGE_LOW to RANGE_LOW + RANGE_SPAN, 0.55× to 1.80× the typical length) and, for every band from Decent on,
-- its low edge `c` as a place in that range, kept as c³: band i holds p = R × u^(1/3) when R³ × u >= EDGE_CUBES[i],
-- which reads the band with multiplications alone, the same on every libm.
local SKILL_FULL, CATCHES_FULL = 300, 1000
local RANGE_LOW, RANGE_SPAN = 0.55, 1.25
local EDGE_CUBES = {}
for band, edge in ipairs({ 0.16, 0.44, 0.60, 0.80 }) do
	EDGE_CUBES[band + 1] = edge * edge * edge
end

--- The Size bands in order, as `{ key, name }` (LOG-R67). The names are interface text, signed off for 1.0 (#264).
--- logic/ also loads without locale/, in the backend's driver (#223), and then the bands have no names.
---@type { key: string, name: string }[]
ns.SIZE_BANDS = {}
local bandNames = ns.L and ns.L.SIZE_BANDS or {}
for band, key in ipairs({ "tiddler", "typical", "hefty", "whopper", "monster" }) do
	ns.SIZE_BANDS[band] = { key = key, name = bandNames[band] }
end

local TWO_32 = 4294967296
local bxor, rshift, byte, floor, min, max, sqrt =
	bit.bxor, bit.rshift, string.byte, math.floor, math.min, math.max, math.sqrt

-- `a * b mod 2^32` for 32-bit `a`, with `b` split into its 16-bit halves (`low`, `high`) so no product reaches 2^53
-- (LOG-R66's mul32).
---@param a integer
---@param low integer
---@param high integer
---@return integer
local function mul32(a, low, high)
	return (a * low + ((a * high) % 65536) * 65536) % TWO_32
end

--- The frozen hash of a Catch ID (LOG-R66 steps 1 and 2): FNV-1a 32-bit over its bytes, then Murmur3's fmix32.
--- Every `bit` result is taken mod 2^32, as LuaBitOp's are signed.
---@param catchId string
---@return integer h in [0, 2^32)
function ns.SizeHash(catchId)
	local h = 2166136261
	for i = 1, #catchId do
		h = bxor(h, byte(catchId, i)) % TWO_32
		h = ((h % 256) * 16777216 + h * 403) % TWO_32 -- h * 16777619 mod 2^32
	end
	h = bxor(h, rshift(h, 16)) % TWO_32
	h = mul32(h, 0xca6b, 0x85eb) -- 0x85ebca6b
	h = bxor(h, rshift(h, 13)) % TWO_32
	h = mul32(h, 0xae35, 0xc2b2) -- 0xc2b2ae35
	return bxor(h, rshift(h, 16)) % TWO_32
end

--- A Catch's percentile `u` (LOG-R66 step 3).
---@param catchId string
---@return number u in [0, 1)
function ns.SizePercentile(catchId)
	return ns.SizeHash(catchId) / TWO_32
end

--- A Legend's Simulated Size, from its Catch ID alone (LOG-R67, ADR 0010): the band whose cut points hold its
--- percentile, and a length linear in the percentile between that band's two multipliers of the typical length. The
--- `/pagle dev probe` reads its band too (#261).
---@param catchId string
---@param typicalLength integer millimetres
---@param multipliers number[]? the six band-edge multipliers; ns.SIZE_MULTIPLIERS by default
---@return PagleSize
function ns.SimulatedSize(catchId, typicalLength, multipliers)
	local m = multipliers or ns.SIZE_MULTIPLIERS
	local u = ns.SizePercentile(catchId)
	local band = 1
	while u >= CUTS[band + 1] do
		band = band + 1
	end
	local within = (u - CUTS[band]) / (CUTS[band + 1] - CUTS[band])
	return { length = floor(typicalLength * (m[band] + (m[band + 1] - m[band]) * within) + 0.5), band = band }
end

--- The Reach of a Catch (LOG-R67, ADR 0014), as a place in the full range from 0 to 1: the lesser of the skill reach,
--- `skillRank` ÷ 300, and the experience reach, √(`earlier` ÷ 1,000), each at most 1.
---@param skillRank integer the Cast's skill rank, its modifier left out
---@param earlier integer the Angler's earlier Catches of the item
---@return number reach in [0, 1]
function ns.Reach(skillRank, earlier)
	local skill = min(max(skillRank / SKILL_FULL, 0), 1)
	return min(skill, sqrt(min(max(earlier, 0), CATCHES_FULL) / CATCHES_FULL))
end

--- The Simulated Size of a Species Catch (LOG-R67): a Legend's (ns.SimulatedSize) for a Legend; for every other
--- Species, its place `p = R × u^(1/3)` in the full range under its Reach `R`, its length
--- `floor(typical × (0.55 + 1.25 × p) + 0.5)` and the band whose low edge `c` has R³ × u >= c³. The band never
--- reads the typical length, which stays tunable (LOG-R68).
---@param catchId string
---@param typicalLength integer millimetres
---@param skillRank integer the Cast's skill rank (LOG-R65)
---@param earlier integer the Angler's earlier Catches of the item (LOG-R65)
---@param legend boolean? a Legend: no Reach
---@return PagleSize
function ns.CatchSize(catchId, typicalLength, skillRank, earlier, legend)
	if legend then
		return ns.SimulatedSize(catchId, typicalLength)
	end
	local reach = ns.Reach(skillRank, earlier)
	local u = ns.SizePercentile(catchId)
	local cube = reach * reach * reach * u
	local band = 1
	while EDGE_CUBES[band + 1] and cube >= EDGE_CUBES[band + 1] do
		band = band + 1
	end
	local place = reach * u ^ (1 / 3)
	return { length = floor(typicalLength * (RANGE_LOW + RANGE_SPAN * place) + 0.5), band = band }
end

--- The Simulated Size of a Catch of `item` (LOG-R65): only a fish or quest fish that isn't Noise has one, Legends
--- included, once the catalogue gives its Species a typical length. Trophies, Sub-collection items, Noise and an
--- Uncharted item (`item` nil) have none.
---@param catchId string
---@param item PagleItem?
---@param skillRank integer the Cast's skill rank, else the character's latest Skill Reading's, else 1 (LOG-R65)
---@param earlier integer the Angler's Catches of the item before this one, from the log alone (LOG-R65)
---@return PagleSize?
function ns.SizeOf(catchId, item, skillRank, earlier)
	if not item or item.noise or not item.typicalLength then
		return nil
	end
	if item.category ~= "fish" and item.category ~= "questFish" then
		return nil
	end
	return ns.CatchSize(catchId, item.typicalLength, skillRank, earlier, item.legend)
end
