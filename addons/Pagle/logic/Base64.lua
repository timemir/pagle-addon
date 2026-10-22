---@class PagleNS
local ns = select(2, ...)

local byte, char, concat, floor = string.byte, string.char, table.concat, math.floor

-- Each alphabet character's byte value to its sextet (RFC 4648 §4); every other byte is absent.
---@type table<integer, integer>
local SEXTET = {}
do
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, #alphabet do
		SEXTET[byte(alphabet, i)] = i - 1
	end
end
local PAD = byte("=")

-- Quads decoded per string.char call: 3 bytes each, well under any argument limit.
local QUADS_PER_CALL = 64

-- Why a quad whose first `count` characters (byte values) aren't all in the alphabet fails: a character outside it,
-- or "=" where padding can't be.
---@param count integer
---@param ... integer
---@return nil
---@return string
local function rejected(count, ...)
	for i = 1, count do
		local value = select(i, ...)
		if not SEXTET[value] and value ~= PAD then
			return nil, "a character outside the Base64 alphabet"
		end
	end
	return nil, "bad padding"
end

--- The bytes Base64 `text` encodes (PUSH-R2), strictly as RFC 4648 §4 writes them: the standard alphabet, a length
--- that is a multiple of 4, "=" only as the last one or two characters, and the bits padding leaves over all zero, so
--- each byte string has exactly one encoding. No whitespace or line ends. Pure Lua, no `bit` calls.
---@param text any
---@return string? bytes
---@return string? reason why `text` isn't Base64, when `bytes` is nil
function ns.Base64Decode(text)
	if type(text) ~= "string" then
		return nil, "not a string"
	end
	local length = #text
	if length % 4 ~= 0 then
		return nil, "a length that isn't a multiple of 4"
	end
	if length == 0 then
		return ""
	end
	-- The padding, checked at the end alone; every quad before the last is four alphabet characters.
	local pads = 0
	if byte(text, length) == PAD then
		pads = byte(text, length - 1) == PAD and 2 or 1
	end
	local last = length - 3
	local pieces, out, n = {}, {}, 0
	for i = 1, last - 1, 4 do
		local w, x, y, z = byte(text, i, i + 3)
		local a, b, c, d = SEXTET[w], SEXTET[x], SEXTET[y], SEXTET[z]
		if not (a and b and c and d) then
			return rejected(4, w, x, y, z)
		end
		local v = ((a * 64 + b) * 64 + c) * 64 + d
		local hi = floor(v / 65536)
		local rest = v - hi * 65536
		local mid = floor(rest / 256)
		out[n + 1], out[n + 2], out[n + 3] = hi, mid, rest - mid * 256
		n = n + 3
		if n >= 3 * QUADS_PER_CALL then
			pieces[#pieces + 1] = char(unpack(out, 1, n))
			n = 0
		end
	end
	if n > 0 then
		pieces[#pieces + 1] = char(unpack(out, 1, n))
	end
	-- The last quad: "xxxx", "xxx=" or "xx==".
	local w, x, y, z = byte(text, last, length)
	local a, b = SEXTET[w], SEXTET[x]
	local c, d = 0, 0
	if pads < 2 then
		c = SEXTET[y]
	end
	if pads < 1 then
		d = SEXTET[z]
	end
	if not (a and b and c and d) then
		return rejected(4 - pads, w, x, y, z)
	end
	local v = ((a * 64 + b) * 64 + c) * 64 + d
	local hi = floor(v / 65536)
	local rest = v - hi * 65536
	local mid = floor(rest / 256)
	local lo = rest - mid * 256
	if pads == 2 then
		if rest ~= 0 then
			return nil, "bad padding"
		end
		pieces[#pieces + 1] = char(hi)
	elseif pads == 1 then
		if lo ~= 0 then
			return nil, "bad padding"
		end
		pieces[#pieces + 1] = char(hi, mid)
	else
		pieces[#pieces + 1] = char(hi, mid, lo)
	end
	return concat(pieces)
end
