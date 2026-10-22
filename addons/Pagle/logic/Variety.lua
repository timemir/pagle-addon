---@class PagleNS
---@field VARIETY_ATLASES string[]? data/VarietyArt.lua: the atlas textures, by number (VAR-R11, UI)
---@field VARIETY_ART_SIZE { w: integer, h: integer, atlas: integer }? data/VarietyArt.lua: one variety's art and an
--- atlas's side, in texels
---@field VARIETY_ART table<integer, { [1]: integer, [2]: integer, [3]: integer }[]>? data/VarietyArt.lua: each
--- Species' ten rectangles by position, `{ atlas, x, y }` in texels
local ns = select(2, ...)

-- Fish varieties (VAR-R1–R5, VAR-R11, ADR 0010): which of its Species' ten varieties a Catch is, from its Catch ID
-- alone, and each Species' ten as Core hands them out. Pure logic on Lua 5.1 numbers and the client's `bit` library
-- (LuaBitOp), every intermediate kept exact below 2^53, as logic/Size.lua's.

--- A Catch's variety (VAR-R4), which records carry beside `size`.
---@class PagleVariety
---@field id string              -- "<speciesID>.<key>" (VAR-R2)
---@field index integer          -- its position in the Species' ten, 1–10
---@field rarity "common"|"uncommon"|"rare"|"epic"

--- A variety's art (VAR-R11, UI): its atlas texture and texture coordinates, ready for `SetTexCoord`.
---@class PagleVarietyArt
---@field texture string
---@field left number
---@field right number
---@field top number
---@field bottom number

--- One of a Species' ten, as `Pagle.GetVarieties` lists them (VAR-R11).
---@class PagleVarietyEntry
---@field id string              -- "<speciesID>.<key>"
---@field key string
---@field index integer          -- 1–10
---@field rarity "common"|"uncommon"|"rare"|"epic"
---@field name string?           -- lore's; nil when lore lacks it
---@field description string?    -- lore's; nil when lore lacks it
---@field art PagleVarietyArt?   -- nil when data/VarietyArt.lua has no rectangle for it

--- A rarity of varieties (VAR-R2, VAR-R11): its key, its name, the odds weight of each of its varieties, and its
--- colour and its darker ink on parchment (UI), each { r, g, b } from 0 to 1.
---@class PagleVarietyRarity
---@field key "common"|"uncommon"|"rare"|"epic"
---@field name string?           -- interface text; nil where logic/ loads without locale/
---@field weight integer         -- one of its varieties' Catches per 10,000 of its Species (VAR-R3)
---@field color number[]
---@field ink number[]

-- Frozen (VAR-R5, ADR 0010), as Size's hash and cut points: the salt, the weights and the rarity of each position.
-- spec/Pagle/logic/Variety_spec.lua pins them and every constant of the hash below.
local SALT = "#variety"
-- Per 10,000 Catches of a Species, by position (VAR-R3): Common 70%, Uncommon 22%, Rare 7%, Epic 1%.
local WEIGHTS = { 1750, 1750, 1750, 1750, 734, 733, 733, 350, 350, 100 }
-- The rarity of each position, an index into ns.VARIETY_RARITIES (VAR-R2): 1–4 Common, 5–7 Uncommon, 8–9 Rare,
-- 10 Epic.
local RARITY_OF = { 1, 1, 1, 1, 2, 2, 2, 3, 3, 4 }

--- The rarities in order, Common to Epic (VAR-R2, VAR-R11). `weight` is one variety's odds, so a page can say "About
--- one Catch in {round(10000 / weight)}" (VAR-R24): Uncommon's is 733, as two of its three are (the third's 734
--- rounds to the same one in 14). The colours are the game's own quality colours, the inks the darker ones Pagle uses
--- on parchment (UI). The names are interface text; logic/ also loads without locale/, in the backend's driver
--- (#223), and then the rarities have no names.
---@type PagleVarietyRarity[]
ns.VARIETY_RARITIES = {}
local rarityNames = ns.L and ns.L.VARIETY_RARITIES or {}
for rarity, entry in ipairs({
	{ key = "common", weight = 1750, color = { 1, 1, 1 }, ink = { 0x6a / 255, 0x5a / 255, 0x44 / 255 } },
	{ key = "uncommon", weight = 733, color = { 0x1e / 255, 1, 0 }, ink = { 0x2f / 255, 0x6a / 255, 0x2a / 255 } },
	{ key = "rare", weight = 350, color = { 0, 0x70 / 255, 0xdd / 255 }, ink = { 0x23 / 255, 0x40 / 255, 0x7a / 255 } },
	{
		key = "epic",
		weight = 100,
		color = { 0xa3 / 255, 0x35 / 255, 0xee / 255 },
		ink = { 0x7a / 255, 0x2f / 255, 0x8a / 255 },
	},
}) do
	entry.name = rarityNames[rarity]
	ns.VARIETY_RARITIES[rarity] = entry
end

--- The rarity of a variety position (VAR-R2): its ns.VARIETY_RARITIES entry, nil for a position outside 1–10.
---@param index integer
---@return PagleVarietyRarity?
function ns.VarietyRarity(index)
	local rarity = RARITY_OF[index]
	return rarity and ns.VARIETY_RARITIES[rarity]
end

local TWO_32 = 4294967296
local bxor, rshift, byte = bit.bxor, bit.rshift, string.byte

-- `a * b mod 2^32` for 32-bit `a`, with `b` split into its 16-bit halves (`low`, `high`) so no product reaches 2^53
-- (LOG-R66's mul32).
---@param a integer
---@param low integer
---@param high integer
---@return integer
local function mul32(a, low, high)
	return (a * low + ((a * high) % 65536) * 65536) % TWO_32
end

--- The frozen variety hash of a Catch (VAR-R3): LOG-R66 steps 1 and 2, FNV-1a 32-bit then Murmur3's fmix32, over the
--- Catch ID with the salt `#variety` appended here, so callers pass the bare Catch ID. It is deliberately its own copy
--- of ns.SizeHash's steps, never a call into Size (VAR-R5): the Simulated Size can change (its rules version, its
--- Reach, ADR 0014) and must never move a variety. Every `bit` result is taken mod 2^32, as LuaBitOp's are signed.
---@param catchId string the bare Catch ID
---@return integer h in [0, 2^32)
function ns.VarietyHash(catchId)
	local text = catchId .. SALT
	local h = 2166136261
	for i = 1, #text do
		h = bxor(h, byte(text, i)) % TWO_32
		h = ((h % 256) * 16777216 + h * 403) % TWO_32 -- h * 16777619 mod 2^32
	end
	h = bxor(h, rshift(h, 16)) % TWO_32
	h = mul32(h, 0xca6b, 0x85eb) -- 0x85ebca6b
	h = bxor(h, rshift(h, 13)) % TWO_32
	h = mul32(h, 0xae35, 0xc2b2) -- 0xc2b2ae35
	return bxor(h, rshift(h, 16)) % TWO_32
end

--- A Catch's variety percentile `v` (VAR-R3), independent of its size percentile.
---@param catchId string the bare Catch ID
---@return number v in [0, 1)
function ns.VarietyPercentile(catchId)
	return ns.VarietyHash(catchId) / TWO_32
end

--- A Catch's variety position (VAR-R3): the first position whose cumulative weight exceeds `v × 10000`, compared as
--- `h × 10000 < cumulative × 2^32` so it stays exact (both below 2^46).
---@param catchId string the bare Catch ID
---@return integer index 1–10
function ns.VarietyIndex(catchId)
	local scaled = ns.VarietyHash(catchId) * 10000
	local cumulative = 0
	for index, weight in ipairs(WEIGHTS) do
		cumulative = cumulative + weight
		if scaled < cumulative * TWO_32 then
			return index
		end
	end
	return #WEIGHTS -- unreachable: the weights add up to 10,000 and h < 2^32
end

-- Whether a Catch of `item` has a Simulated Size (LOG-R65): a fish or quest fish that isn't Noise, once the catalogue
-- gives its Species a typical length. The same test ns.SizeOf makes, kept here rather than read from logic/Size.lua,
-- which changes with the Simulated Size (VAR-R5); spec/Pagle/logic/Variety_spec.lua checks the two agree.
---@param item PagleItem
---@return boolean
local function sized(item)
	return not item.noise and item.typicalLength ~= nil and (item.category == "fish" or item.category == "questFish")
end

--- The variety of a Catch of `item` (VAR-R1, VAR-R4), or nil: only a Catch with a Simulated Size (LOG-R65) of an item
--- that isn't a Legend and whose catalogue record lists its Species' ten `varieties` has one. Trophies, Sub-collection
--- items, Noise, Legends and an Uncharted item (`item` nil) have none. One per Catch, whatever its quantity (VAR-R92).
---@param catchId string
---@param item PagleItem?
---@return PagleVariety?
function ns.VarietyOf(catchId, item)
	if not item or item.legend or not item.varieties or not sized(item) then
		return nil
	end
	local index = ns.VarietyIndex(catchId)
	local key = item.varieties[index]
	if not key then
		return nil -- the generator never emits fewer than ten (VAR-R2)
	end
	return { id = item.species .. "." .. key, index = index, rarity = ns.VARIETY_RARITIES[RARITY_OF[index]].key }
end

--- A variety's art (VAR-R11, UI), from data/VarietyArt.lua's rectangle at its position (positions, not keys, so a
--- renamed key keeps its art): the atlas and the texel rectangle as texture coordinates. nil when that file, or its
--- rectangle for this Species and position, is missing.
---@param speciesID integer
---@param index integer
---@return PagleVarietyArt?
function ns.VarietyArt(speciesID, index)
	local rects, size, atlases = ns.VARIETY_ART, ns.VARIETY_ART_SIZE, ns.VARIETY_ATLASES
	local rect = rects and rects[speciesID] and rects[speciesID][index]
	local texture = rect and atlases and atlases[rect[1]]
	if not rect or not texture or not size then
		return nil
	end
	local x, y, atlas = rect[2], rect[3], size.atlas
	return {
		texture = texture,
		left = x / atlas,
		right = (x + size.w) / atlas,
		top = y / atlas,
		bottom = (y + size.h) / atlas,
	}
end

--- A Species' ten as `Pagle.GetVarieties` lists them (VAR-R11), in order, from its catalogue `keys`: each one's
--- rarity, its name and description from lore (`variety.<speciesID>.<key>.name` and `.description`) and its art.
---@param speciesID integer
---@param keys string[]
---@return PagleVarietyEntry[]
function ns.VarietyList(speciesID, keys)
	local L = ns.L or {}
	local list = {}
	for index = 1, math.min(#keys, #WEIGHTS) do
		local key = keys[index]
		local id = speciesID .. "." .. key
		list[index] = {
			id = id,
			key = key,
			index = index,
			rarity = ns.VARIETY_RARITIES[RARITY_OF[index]].key,
			name = L["variety." .. id .. ".name"],
			description = L["variety." .. id .. ".description"],
			art = ns.VarietyArt(speciesID, index),
		}
	end
	return list
end
