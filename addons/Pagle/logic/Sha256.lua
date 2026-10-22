---@class PagleNS
local ns = select(2, ...)

-- SHA-256 (FIPS 180-4 §6.2) in pure Lua 5.1 with no `bit` calls (PUSH-R11): Pagle's own code, written for #292.
-- Each 32-bit word is an integer in [0, 2^32) held in a double; every sum stays below 2^35, so all of it is exact.
--
-- Without bit operations, the work is done a byte at a time through tables, with the bits of a byte "spread": bit i
-- moved to bit 2i, so up to three spread bytes add without carries, each bit summing in its own two-bit field. The
-- low bit of each field is then the XOR of the bits summed, and the high bit their majority (or, for two, their AND),
-- read back as a byte from the tables P and H. So:
--
-- - Σ0, Σ1, σ0 and σ1 are each three rotations or shifts XORed: linear, so a byte of the result is the P of the sum of
--   what each byte of the word contributes to it, one table read per byte (`contribution`).
-- - Maj(a, b, c) is the H of the sum of the three spread bytes, and Ch(e, f, g) = (e AND f) + (NOT e AND g), whose
--   two terms share no bit, two H reads.
--
-- The tables come to about 2 MB, so they are built when a hash starts (or in steps, by ns.Sha256Prepare) and held only
-- by what uses them, through a weak cache: once the pushed-content check ends, the collector takes them back.

local byte, char, concat, floor = string.byte, string.char, table.concat, math.floor

local TWO32 = 4294967296

-- FIPS 180-4 §4.2.2: the first 32 bits of the fractional parts of the cube roots of the first 64 primes.
local K = {
	0x428a2f98,
	0x71374491,
	0xb5c0fbcf,
	0xe9b5dba5,
	0x3956c25b,
	0x59f111f1,
	0x923f82a4,
	0xab1c5ed5,
	0xd807aa98,
	0x12835b01,
	0x243185be,
	0x550c7dc3,
	0x72be5d74,
	0x80deb1fe,
	0x9bdc06a7,
	0xc19bf174,
	0xe49b69c1,
	0xefbe4786,
	0x0fc19dc6,
	0x240ca1cc,
	0x2de92c6f,
	0x4a7484aa,
	0x5cb0a9dc,
	0x76f988da,
	0x983e5152,
	0xa831c66d,
	0xb00327c8,
	0xbf597fc7,
	0xc6e00bf3,
	0xd5a79147,
	0x06ca6351,
	0x14292967,
	0x27b70a85,
	0x2e1b2138,
	0x4d2c6dfc,
	0x53380d13,
	0x650a7354,
	0x766a0abb,
	0x81c2c92e,
	0x92722c85,
	0xa2bfe8a1,
	0xa81a664b,
	0xc24b8b70,
	0xc76c51a3,
	0xd192e819,
	0xd6990624,
	0xf40e3585,
	0x106aa070,
	0x19a4c116,
	0x1e376c08,
	0x2748774c,
	0x34b0bcb5,
	0x391c0cb3,
	0x4ed8aa4a,
	0x5b9cca4f,
	0x682e6ff3,
	0x748f82ee,
	0x78a5636f,
	0x84c87814,
	0x8cc70208,
	0x90befffa,
	0xa4506ceb,
	0xbef9a3f7,
	0xc67178f2,
}

-- FIPS 180-4 §5.3.3: the first 32 bits of the fractional parts of the square roots of the first 8 primes.
local H0 = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 }

-- The tables a hash works through, while some hash holds them (see the top).
local cache = setmetatable({}, { __mode = "v" })

--- Bit n of the byte or word x.
---@param x number
---@param n integer
---@return integer
local function bitOf(x, n)
	return floor(x / 2 ^ n) % 2
end

--- The table, over bytes b, of what b, as the byte at offset k after output byte j, adds to each output bit's spread
--- sum for a word rotated right by each of `rotations` and shifted right by `shift` (if given; none wraps). A linear
--- map, so only the eight single bits are worked out and the rest are sums.
---@param rotations integer[]
---@param shift integer?
---@param j integer
---@param k integer
---@return number[]
local function contribution(rotations, shift, j, k)
	local t = { [0] = 0 }
	for n = 0, 7 do
		local v = 0
		for i = 0, 7 do
			for _, r in ipairs(rotations) do
				if floor((i + r) / 8) % 4 == k and (i + r) % 8 == n then
					v = v + 4 ^ i
				end
			end
			if shift and floor((i + shift) / 8) == k and j + k <= 3 and (i + shift) % 8 == n then
				v = v + 4 ^ i
			end
		end
		t[2 ^ n] = v
	end
	local high = 1
	for b = 2, 255 do
		if b == 2 * high then
			high = b
		elseif b > high then
			t[b] = t[high] + t[b - high]
		end
	end
	return t
end

-- P and H entries a preparation step fills, and contribution tables it builds once they're filled: each about half a
-- millisecond's work in stock Lua 5.1, so a step fits a frame's budget with room on a slower machine (#293).
local FILL_PER_STEP = 8192
local CONTRIBUTIONS_PER_STEP = 8

--- Builds the spread tables in steps: SP[b], byte b with each bit i moved to bit 2i, so that adding up to three spread
--- bytes sums each bit in its own two-bit field; P[v] and H[v], the low and the high bit of each field of a sum v (its
--- XOR, and its majority or AND); and for each Σ and σ, each byte's contribution to each output byte (`contribution`).
--- Returns a function that does one step a call and returns the tables once they are whole, nil before. It holds them
--- while it lives.
---@return fun(): table<string, any>?
local function buildSteps()
	local T = cache.T
	if T then
		return function()
			return T
		end
	end
	local SP = {}
	for b = 0, 255 do
		local v = 0
		for i = 0, 7 do
			v = v + bitOf(b, i) * 4 ^ i
		end
		SP[b] = v
	end
	local P, H = { [0] = 0 }, { [0] = 0 }
	local filled = 0
	-- Each contribution table to build: where it goes, its index there, and contribution's arguments.
	local S, s0, s1 = {}, {}, {}
	local jobs = {}
	for k = 0, 3 do
		jobs[#jobs + 1] = { S, k + 1, { 2, 13, 22 }, nil, 0, k } -- Σ0
		jobs[#jobs + 1] = { S, k + 5, { 6, 11, 25 }, nil, 0, k } -- Σ1
	end
	for j = 0, 3 do
		for k = 0, 3 do
			jobs[#jobs + 1] = { s0, 4 * j + k + 1, { 7, 18 }, 3, j, k } -- σ0
			jobs[#jobs + 1] = { s1, 4 * j + k + 1, { 17, 19 }, 10, j, k } -- σ1
		end
	end
	local built = 0
	return function()
		if T then
			return T
		end
		if filled < 65535 then
			-- Field by field from the top: P[v] = 2 * P[v >> 2] + (v AND 1), H[v] = 2 * H[v >> 2] + (v >> 1 AND 1).
			local stop = filled + FILL_PER_STEP
			if stop > 65535 then
				stop = 65535
			end
			for v = filled + 1, stop do
				local field = v % 4
				local rest = (v - field) / 4
				P[v] = 2 * P[rest] + field % 2
				H[v] = 2 * H[rest] + (field - field % 2) / 2
			end
			filled = stop
			return nil
		end
		local stop = built + CONTRIBUTIONS_PER_STEP
		if stop > #jobs then
			stop = #jobs
		end
		for i = built + 1, stop do
			local job = jobs[i]
			job[1][job[2]] = contribution(job[3], job[4], job[5], job[6])
		end
		built = stop
		if built < #jobs then
			return nil
		end
		T = { SP = SP, P = P, H = H, S = S, s0 = s0, s1 = s1 }
		cache.T = T
		return T
	end
end

--- The tables, built at once if no hash or preparation holds them now.
---@return table<string, any>
local function tables()
	local step = buildSteps()
	local T = step()
	while not T do
		T = step()
	end
	return T
end

-- The message schedule, words and their bytes (WB[4t - 3] the lowest byte of W[t]), reused by every block:
-- compression never yields, so hashes in flight can share them.
---@type number[], number[]
local W, WB = {}, {}

--- Hashes the 64-byte block of `bytes` at `at` into the eight words `h` (FIPS 180-4 §6.2.2), a byte at a time. A byte
--- of Σ0(a) is the parity of the spread sums of a's four bytes' contributions (four table reads, one P read); Maj and
--- Ch are H reads of sums of spread bytes. Only the two new words of a round, a and e, are split into bytes. Sums of
--- spread bytes stay below 2^16, and every word sum below 2^35.
---@param T table<string, any>
---@param h number[]
---@param bytes string
---@param at integer
local function compress(T, h, bytes, at)
	local P, H, SP = T.P, T.H, T.SP
	local S00, S01, S02, S03, S10, S11, S12, S13 = unpack(T.S)
	local s000, s001, s002, s003, s010, s011, s012, s013 = unpack(T.s0, 1, 8)
	local s020, s021, s022, s023, s030, s031, s032, s033 = unpack(T.s0, 9, 16)
	local s100, s101, s102, s103, s110, s111, s112, s113 = unpack(T.s1, 1, 8)
	local s120, s121, s122, s123, s130, s131, s132, s133 = unpack(T.s1, 9, 16)
	local x
	-- The block's 16 words, big-endian, and their bytes, the lowest first.
	for t = 1, 16 do
		local w3, w2, w1, w0 = byte(bytes, at, at + 3)
		local i = 4 * t
		WB[i - 3], WB[i - 2], WB[i - 1], WB[i] = w0, w1, w2, w3
		W[t] = ((w3 * 256 + w2) * 256 + w1) * 256 + w0
		at = at + 4
	end
	-- W[t] = σ1(W[t - 2]) + W[t - 7] + σ0(W[t - 15]) + W[t - 16], σ1 + σ0 a byte at a time.
	for t = 17, 64 do
		local i, k = 4 * (t - 2), 4 * (t - 15)
		local x0, x1, x2, x3 = WB[i - 3], WB[i - 2], WB[i - 1], WB[i]
		local y0, y1, y2, y3 = WB[k - 3], WB[k - 2], WB[k - 1], WB[k]
		local z0 = P[s100[x0] + s101[x1] + s102[x2] + s103[x3]] + P[s000[y0] + s001[y1] + s002[y2] + s003[y3]]
		local z1 = P[s110[x1] + s111[x2] + s112[x3] + s113[x0]] + P[s010[y1] + s011[y2] + s012[y3] + s013[y0]]
		local z2 = P[s120[x2] + s121[x3] + s122[x0] + s123[x1]] + P[s020[y2] + s021[y3] + s022[y0] + s023[y1]]
		local z3 = P[s130[x3] + s131[x0] + s132[x1] + s133[x2]] + P[s030[y3] + s031[y0] + s032[y1] + s033[y2]]
		local w = (W[t - 7] + W[t - 16] + z0 + z1 * 256 + z2 * 65536 + z3 * 16777216) % TWO32
		W[t] = w
		i = 4 * t
		local w0 = w % 256
		x = (w - w0) / 256
		local w1 = x % 256
		x = (x - w1) / 256
		local w2 = x % 256
		WB[i - 3], WB[i - 2], WB[i - 1], WB[i] = w0, w1, w2, (x - w2) / 256
	end
	-- The working variables: a and e with their bytes (for Σ), and the spread bytes of a, b, c (for Maj) and of
	-- e, f, g (for Ch).
	local a, b, c, d, e, f, g, hh = h[1], h[2], h[3], h[4], h[5], h[6], h[7], h[8]
	local a0, a1, a2, a3, as0, as1, as2, as3, bs0, bs1, bs2, bs3, cs0, cs1, cs2, cs3
	local e0, e1, e2, e3, es0, es1, es2, es3, fs0, fs1, fs2, fs3, gs0, gs1, gs2, gs3
	a0 = a % 256
	x = (a - a0) / 256
	a1 = x % 256
	x = (x - a1) / 256
	a2 = x % 256
	a3 = (x - a2) / 256
	as0, as1, as2, as3 = SP[a0], SP[a1], SP[a2], SP[a3]
	x = b
	bs0 = SP[x % 256]
	x = (x - x % 256) / 256
	bs1 = SP[x % 256]
	x = (x - x % 256) / 256
	bs2 = SP[x % 256]
	bs3 = SP[(x - x % 256) / 256]
	x = c
	cs0 = SP[x % 256]
	x = (x - x % 256) / 256
	cs1 = SP[x % 256]
	x = (x - x % 256) / 256
	cs2 = SP[x % 256]
	cs3 = SP[(x - x % 256) / 256]
	e0 = e % 256
	x = (e - e0) / 256
	e1 = x % 256
	x = (x - e1) / 256
	e2 = x % 256
	e3 = (x - e2) / 256
	es0, es1, es2, es3 = SP[e0], SP[e1], SP[e2], SP[e3]
	x = f
	fs0 = SP[x % 256]
	x = (x - x % 256) / 256
	fs1 = SP[x % 256]
	x = (x - x % 256) / 256
	fs2 = SP[x % 256]
	fs3 = SP[(x - x % 256) / 256]
	x = g
	gs0 = SP[x % 256]
	x = (x - x % 256) / 256
	gs1 = SP[x % 256]
	x = (x - x % 256) / 256
	gs2 = SP[x % 256]
	gs3 = SP[(x - x % 256) / 256]
	for t = 1, 64 do
		-- Σ1(e) + Ch(e, f, g): Ch = (e AND f) + (NOT e AND g), the spread of NOT e being 21845 minus e's.
		local t1 = hh
			+ K[t]
			+ W[t]
			+ P[S10[e0] + S11[e1] + S12[e2] + S13[e3]]
			+ H[es0 + fs0]
			+ H[21845 - es0 + gs0]
			+ (P[S10[e1] + S11[e2] + S12[e3] + S13[e0]] + H[es1 + fs1] + H[21845 - es1 + gs1]) * 256
			+ (P[S10[e2] + S11[e3] + S12[e0] + S13[e1]] + H[es2 + fs2] + H[21845 - es2 + gs2]) * 65536
			+ (P[S10[e3] + S11[e0] + S12[e1] + S13[e2]] + H[es3 + fs3] + H[21845 - es3 + gs3]) * 16777216
		-- Σ0(a) + Maj(a, b, c): Maj is the high bit of each spread bit's sum of three.
		local t2 = P[S00[a0] + S01[a1] + S02[a2] + S03[a3]]
			+ H[as0 + bs0 + cs0]
			+ (P[S00[a1] + S01[a2] + S02[a3] + S03[a0]] + H[as1 + bs1 + cs1]) * 256
			+ (P[S00[a2] + S01[a3] + S02[a0] + S03[a1]] + H[as2 + bs2 + cs2]) * 65536
			+ (P[S00[a3] + S01[a0] + S02[a1] + S03[a2]] + H[as3 + bs3 + cs3]) * 16777216
		hh = g
		g, gs0, gs1, gs2, gs3 = f, fs0, fs1, fs2, fs3
		f, fs0, fs1, fs2, fs3 = e, es0, es1, es2, es3
		e = (d + t1) % TWO32
		e0 = e % 256
		x = (e - e0) / 256
		e1 = x % 256
		x = (x - e1) / 256
		e2 = x % 256
		e3 = (x - e2) / 256
		es0, es1, es2, es3 = SP[e0], SP[e1], SP[e2], SP[e3]
		d = c
		c, cs0, cs1, cs2, cs3 = b, bs0, bs1, bs2, bs3
		b, bs0, bs1, bs2, bs3 = a, as0, as1, as2, as3
		a = (t1 + t2) % TWO32
		a0 = a % 256
		x = (a - a0) / 256
		a1 = x % 256
		x = (x - a1) / 256
		a2 = x % 256
		a3 = (x - a2) / 256
		as0, as1, as2, as3 = SP[a0], SP[a1], SP[a2], SP[a3]
	end
	h[1], h[2], h[3], h[4] = (h[1] + a) % TWO32, (h[2] + b) % TWO32, (h[3] + c) % TWO32, (h[4] + d) % TWO32
	h[5], h[6], h[7], h[8] = (h[5] + e) % TWO32, (h[6] + f) % TWO32, (h[7] + g) % TWO32, (h[8] + hh) % TWO32
end

--- A SHA-256 hash fed in pieces (PUSH-R10): the pushed-content check spreads a payload of up to 64 KiB over frames.
---@class PagleSha256
---@field private T table<string, any>? the tables, until the digest is given
---@field private h number[]
---@field private pending string bytes short of a whole block
---@field private length number bytes fed so far
local Sha256 = {}
Sha256.__index = Sha256

--- Builds the tables a hash works through in steps, for a coroutine to yield between (PUSH-R10): about 2 MB that
--- ns.NewSha256 otherwise builds in one go, some 5 ms in stock Lua 5.1. Returns a function; each call does one step,
--- under a millisecond there, and returns true once the tables are whole. Keep it until ns.NewSha256 has run: it
--- holds the tables meanwhile, and the collector may take them back once neither it nor a hash in flight does.
---@return fun(): boolean
function ns.Sha256Prepare()
	local step = buildSteps()
	return function()
		return step() ~= nil
	end
end

--- A new hash, of nothing yet (FIPS 180-4 §6.2: init). Builds its tables first unless a hash in flight or an
--- ns.Sha256Prepare still holds them.
---@return PagleSha256
function ns.NewSha256()
	local h = {}
	for i = 1, 8 do
		h[i] = H0[i]
	end
	return setmetatable({ T = tables(), h = h, pending = "", length = 0 }, Sha256)
end

--- Feeds `chunk`, of any length, after what came before. Hashes every whole block it completes at once.
---@param chunk string
function Sha256:Update(chunk)
	local T = assert(self.T, "this hash has given its digest")
	self.length = self.length + #chunk
	local at = 1
	local pending = self.pending
	if pending ~= "" then
		local need = 64 - #pending
		if #chunk < need then
			self.pending = pending .. chunk
			return
		end
		compress(T, self.h, pending .. chunk:sub(1, need), 1)
		at = need + 1
	end
	local stop = #chunk - 63
	while at <= stop do
		compress(T, self.h, chunk, at)
		at = at + 64
	end
	self.pending = chunk:sub(at)
end

--- The 32 raw bytes of the digest of everything fed (FIPS 180-4 §5.1.1 padding). The hash takes nothing after.
---@return string
function Sha256:Final()
	local T = assert(self.T, "this hash has given its digest")
	local bits = self.length * 8
	local high = floor(bits / TWO32)
	local low = bits - high * TWO32
	local zeros = (55 - self.length) % 64
	local tail = self.pending
		.. "\128"
		.. ("\0"):rep(zeros)
		.. char(floor(high / 16777216), floor(high / 65536) % 256, floor(high / 256) % 256, high % 256)
		.. char(floor(low / 16777216), floor(low / 65536) % 256, floor(low / 256) % 256, low % 256)
	for at = 1, #tail, 64 do
		compress(T, self.h, tail, at)
	end
	self.T = nil
	local out = {}
	for i = 1, 8 do
		local v = self.h[i]
		out[i] = char(floor(v / 16777216), floor(v / 65536) % 256, floor(v / 256) % 256, v % 256)
	end
	return concat(out)
end

--- The SHA-256 digest of `bytes`, as 32 raw bytes (FIPS 180-4).
---@param bytes string
---@return string
function ns.Sha256(bytes)
	local hash = ns.NewSha256()
	hash:Update(bytes)
	return hash:Final()
end
