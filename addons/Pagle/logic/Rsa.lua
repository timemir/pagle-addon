---@class PagleNS
local ns = select(2, ...)

-- The RSA-2048 signature check of pushed content (PUSH-R11): RSASSA-PKCS1-V1_5-VERIFY (RFC 8017 §8.2.2) with SHA-256
-- and the public exponent 65537, in pure Lua 5.1 with no `bit` calls.
--
-- A number below 2^2064 is 86 limbs of 24 bits, the lowest first, each an integer held in a double. Montgomery
-- multiplication (CIOS: one pass of multiply and reduce per limb) keeps every product below 2^48 and every
-- accumulator below 2^50, so all of it is exact below 2^53, using only *, +, -, % and division by 2^24 of a multiple
-- of 2^24. The Montgomery radix is R = 2^(24 * 86). Each key ships R^2 mod n and -n^-1 mod 2^24 beside its modulus
-- (logic/PushedKeys.lua, from scripts/pushed-key.py), so a check does no key setup.
--
-- s^65537 mod n is 18 multiplications: s into Montgomery form (s * R^2), 16 squarings, and one multiplication by s
-- itself, which also takes the result back out of Montgomery form. The check then rebuilds the one block a valid
-- signature can give, EMSA-PKCS1-v1_5 for this digest (RFC 8017 §9.2), and compares it with s^65537 mod n whole. It
-- never parses the block (RFC 8017 §8.2.2 step 4's note), which is what defeats the forgeries that fool lax parsers.

local byte, char, floor = string.byte, string.char, math.floor

local LIMBS = 86
local RADIX = 16777216 -- 2^24
local BYTES = 256 -- the modulus, and every signature, is 2048 bits
local HEX_DIGITS = 2 * BYTES

-- RFC 8017 §9.2 Note 1: the DER of DigestInfo for SHA-256, which the digest follows.
local DIGEST_INFO = char(48, 49, 48, 13, 6, 9, 96, 134, 72, 1, 101, 3, 4, 2, 1, 5, 0, 4, 32)
local DIGEST_BYTES = 32

local KEY = "the key is malformed"
local DIGEST = "the digest isn't 32 bytes"
local LENGTH = "the signature isn't as long as the modulus"
local RANGE = "the signature isn't below the modulus"
local MISMATCH = "the signature doesn't match"

-- Montgomery multiplications done since load, for the spec that holds each step to one.
local multiplications = 0

--- 256 big-endian bytes as limbs.
---@param bytes string
---@return number[]
local function fromBytes(bytes)
	local limbs = {}
	for i = 1, LIMBS - 1 do
		local at = BYTES - 3 * i + 1
		local b1, b2, b3 = byte(bytes, at, at + 2)
		limbs[i] = (b1 * 256 + b2) * 256 + b3
	end
	limbs[LIMBS] = byte(bytes, 1)
	return limbs
end

--- Limbs of a number below 2^2048 as 256 big-endian bytes.
---@param limbs number[]
---@return string
local function toBytes(limbs)
	local out = { char(limbs[LIMBS]) }
	for i = LIMBS - 1, 1, -1 do
		local v = limbs[i]
		local high = floor(v / 65536)
		local rest = v - high * 65536
		local mid = floor(rest / 256)
		out[#out + 1] = char(high, mid, rest - mid * 256)
	end
	return table.concat(out)
end

--- 512 lowercase hex digits, big-endian, as limbs; nil for anything else.
---@param hex any
---@return number[]?
local function fromHex(hex)
	if type(hex) ~= "string" or #hex ~= HEX_DIGITS or hex:find("[^0-9a-f]") then
		return nil
	end
	local limbs = {}
	for i = 1, LIMBS - 1 do
		local stop = HEX_DIGITS - 6 * (i - 1)
		limbs[i] = tonumber(hex:sub(stop - 5, stop), 16)
	end
	limbs[LIMBS] = tonumber(hex:sub(1, 2), 16)
	return limbs
end

--- Whether a < b.
---@param a number[]
---@param b number[]
---@return boolean
local function below(a, b)
	for i = LIMBS, 1, -1 do
		if a[i] ~= b[i] then
			return a[i] < b[i]
		end
	end
	return false
end

--- a * b / R mod n, for a, b < n: the result is below n too.
---@param a number[]
---@param b number[]
---@param n number[]
---@param n0inv number -n^-1 mod 2^24
---@return number[]
local function montgomery(a, b, n, n0inv)
	multiplications = multiplications + 1
	local t = {}
	for j = 1, LIMBS + 1 do
		t[j] = 0
	end
	local b1, n1 = b[1], n[1]
	for i = 1, LIMBS do
		local ai = a[i]
		-- m makes t + ai * b + m * n a multiple of 2^24, so the pass shifts it down one limb exactly.
		local m = ((t[1] + ai * b1) % RADIX * n0inv) % RADIX
		local x = t[1] + ai * b1 + m * n1
		local carry = x / RADIX
		for j = 2, LIMBS do
			x = t[j] + ai * b[j] + m * n[j] + carry
			local low = x % RADIX
			carry = (x - low) / RADIX
			t[j - 1] = low
		end
		x = t[LIMBS + 1] + carry
		local low = x % RADIX
		t[LIMBS] = low
		t[LIMBS + 1] = (x - low) / RADIX
	end
	-- t < 2n: one subtraction of n at most brings it below n.
	if t[LIMBS + 1] > 0 or not below(t, n) then
		local borrow = 0
		for j = 1, LIMBS do
			local x = t[j] - n[j] - borrow
			if x < 0 then
				t[j], borrow = x + RADIX, 1
			else
				t[j], borrow = x, 0
			end
		end
	end
	t[LIMBS + 1] = nil
	return t
end

--- The key's limbs, or nil if it isn't an RSA-2048 key in PushedKeys.lua's form: n odd and at least 2^2047, rr below
--- n, and n0inv the integer in [0, 2^24) with n * n0inv = -1 mod 2^24.
---@param key any
---@return { n: number[], rr: number[], n0inv: number }?
local function readKey(key)
	if type(key) ~= "table" then
		return nil
	end
	local n, rr, n0inv = fromHex(key.n), fromHex(key.rr), key.n0inv
	if not n or not rr or type(n0inv) ~= "number" then
		return nil
	end
	if n[LIMBS] < 128 or n[1] % 2 == 0 or not below(rr, n) then
		return nil
	end
	if n0inv < 0 or n0inv >= RADIX or n0inv % 1 ~= 0 or (n[1] * n0inv) % RADIX ~= RADIX - 1 then
		return nil
	end
	return { n = n, rr = rr, n0inv = n0inv }
end

--- The raw RSA public operation in steps (RSAVP1, RFC 8017 §5.2.2, with e = 65537): a function that does one
--- Montgomery multiplication a call and returns nil until, at the 18th, it returns s^65537 mod n as limbs.
---@param key { n: number[], rr: number[], n0inv: number }
---@param s number[]
---@return fun(): number[]?
local function publicSteps(key, s)
	local n, n0inv = key.n, key.n0inv
	local done, x = 0, s
	return function()
		done = done + 1
		if done == 1 then
			x = montgomery(s, key.rr, n, n0inv)
		elseif done <= 17 then
			x = montgomery(x, x, n, n0inv)
		else
			return montgomery(x, s, n, n0inv)
		end
		return nil
	end
end

--- The key's limbs and the signature's, or nil and the reason the signature can't be checked under it.
---@param key any
---@param signature any
---@return { n: number[], rr: number[], n0inv: number }?
---@return number[]|string
local function start(key, signature)
	local read = readKey(key)
	if not read then
		return nil, KEY
	end
	if type(signature) ~= "string" or #signature ~= BYTES then
		return nil, LENGTH
	end
	local s = fromBytes(signature)
	if not below(s, read.n) then
		return nil, RANGE
	end
	return read, s
end

--- Checks an RSA-2048 PKCS#1 v1.5 SHA-256 signature in steps, for a coroutine to yield between (PUSH-R10, PUSH-R11).
--- Returns a function; each call does one step, at most one Montgomery multiplication (20 steps in all), and returns
--- nothing until the last, which returns true, or false and the reason. Calls after that return the same verdict.
---
--- The first step reads the key and checks the signature's form and the digest's: a signature that isn't exactly as
--- long as the modulus (256 bytes), or whose value is n or more, fails there, before any multiplication. The last
--- compares s^65537 mod n with the EMSA-PKCS1-v1_5 block for `digest`, byte for byte.
---@param key { n: string, rr: string, n0inv: integer } a ns.PUSHED_KEYS entry (PUSH-R12)
---@param signature string the signature's raw bytes, big-endian
---@param digest string the SHA-256 of the signed bytes, 32 raw bytes (ns.Sha256)
---@return fun(): (boolean?, string?)
function ns.RsaVerifySteps(key, signature, digest)
	local ok, why ---@type boolean?, string?
	local power ---@type (fun(): number[]?)?
	local result ---@type number[]?
	return function()
		if ok ~= nil then
			return ok, why
		end
		if result then
			local block = char(0, 1) .. ("\255"):rep(BYTES - 3 - #DIGEST_INFO - DIGEST_BYTES) .. char(0) .. DIGEST_INFO
			if toBytes(result) == block .. digest then
				ok, why = true, nil
			else
				ok, why = false, MISMATCH
			end
			return ok, why
		end
		if power then
			result = power()
			return nil
		end
		local read, s = start(key, signature)
		if not read then
			---@cast s string
			ok, why = false, s
		elseif type(digest) ~= "string" or #digest ~= DIGEST_BYTES then
			ok, why = false, DIGEST
		else
			---@cast s number[]
			power = publicSteps(read, s)
			return nil
		end
		return ok, why
	end
end

--- Checks a signature at once, every step of ns.RsaVerifySteps in one call: true, or false and the reason.
---@param key { n: string, rr: string, n0inv: integer }
---@param signature string
---@param digest string
---@return boolean ok
---@return string? reason
function ns.RsaVerify(key, signature, digest)
	local step = ns.RsaVerifySteps(key, signature, digest)
	local ok, why = step()
	while ok == nil do
		ok, why = step()
	end
	return ok, why
end

--- s^65537 mod n for the signature's bytes under `key`, as 256 big-endian bytes (RSAVP1, RFC 8017 §5.2.2), at once;
--- or nil and the reason, as ns.RsaVerifySteps gives it, when the key or the signature can't be used.
---@param key { n: string, rr: string, n0inv: integer }
---@param signature string
---@return string? block
---@return string? reason
function ns.RsaVp1(key, signature)
	local read, s = start(key, signature)
	if not read then
		---@cast s string
		return nil, s
	end
	---@cast s number[]
	local power = publicSteps(read, s)
	local m = power()
	while not m do
		m = power()
	end
	return toBytes(m)
end

--- How many Montgomery multiplications have run since load: what the spec holds each step to.
---@return integer
function ns.RsaMultiplications()
	return multiplications
end
