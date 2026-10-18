---@class PagleNS
local ns = select(2, ...)

-- Simulated Size (LOG-R65–R68, ADR 0010): a Species Catch's length and Size band, from its Catch ID alone. Pure logic
-- on Lua 5.1 numbers and the client's `bit` library (LuaBitOp), every intermediate kept exact below 2^53 (LOG-R66).

--- A Simulated Size (LOG-R65–R67).
---@class PagleSize
---@field length integer         -- whole millimetres
---@field band integer           -- 1 Tiddler … 5 Monster

--- Changes whenever the multipliers below change; a Module that stores sizes folds it into its rules version
--- (LOG-R68). Tunable before 1.0.
ns.SIZE_RULES_VERSION = 1

--- Tunable: the multipliers of the typical length at each band edge, from Tiddler's low edge to Monster's high one
--- (LOG-R67). A change here changes ns.SIZE_RULES_VERSION.
ns.SIZE_MULTIPLIERS = { 0.55, 0.75, 1.10, 1.30, 1.55, 1.80 }

-- Frozen (LOG-R68, ADR 0010): the band edges of the percentile, never tunable. Band i is [CUTS[i], CUTS[i + 1]).
-- spec/Pagle/logic/Size_spec.lua pins them and every constant of ns.SizeHash below as the 1.0 freeze (#267).
local CUTS = { 0, 0.15, 0.70, 0.93, 0.995, 1 }

--- The Size bands in order, as `{ key, name }` (LOG-R67). The names are interface text, signed off for 1.0 (#264).
--- logic/ also loads without locale/, in the backend's driver (#223), and then the bands have no names.
---@type { key: string, name: string }[]
ns.SIZE_BANDS = {}
local bandNames = ns.L and ns.L.SIZE_BANDS or {}
for band, key in ipairs({ "tiddler", "typical", "hefty", "whopper", "monster" }) do
	ns.SIZE_BANDS[band] = { key = key, name = bandNames[band] }
end

local TWO_32 = 4294967296
local bxor, rshift, byte, floor = bit.bxor, bit.rshift, string.byte, math.floor

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

--- The Simulated Size of a Catch of a Species with this typical length (LOG-R67): the band whose cut points hold its
--- percentile, and a length linear in the percentile between that band's two multipliers.
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

--- The Simulated Size of a Catch of `item` (LOG-R65): only a fish or quest fish that isn't Noise has one, Legends
--- included, once the catalogue gives its Species a typical length. Trophies, Sub-collection items, Noise and an
--- Uncharted item (`item` nil) have none.
---@param catchId string
---@param item PagleItem?
---@return PagleSize?
function ns.SizeOf(catchId, item)
	if not item or item.noise or not item.typicalLength then
		return nil
	end
	if item.category ~= "fish" and item.category ~= "questFish" then
		return nil
	end
	return ns.SimulatedSize(catchId, item.typicalLength)
end
