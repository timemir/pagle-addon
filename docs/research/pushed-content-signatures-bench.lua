-- Bench harness for docs/research/pushed-content-signatures.md (#283). Throwaway research code, not addon code.
-- usage: LUA_CPATH=<luabitop dir>/?.so lua pushed-content-signatures-bench.lua <dir holding wowbit.lua> <dl dir> <keys dir> [hash|ed|rsa|all]
--   <dl dir>/sha2/sha2.lua       pure_lua_SHA at 6adac177c16c3496899f69d220dfb20bc31c03df
--   <dl dir>/ccl/ccryptolib/...  ccryptolib at 14489aa1ec408f8a07e1292be5ef91dfe8567c74
--   <keys dir>: msg.bin (4096 random bytes), ed.pub.der + ed.sig (openssl pkeyutl -sign -rawin),
--     rsa2048 / rsa2048e3 / rsa3072 .n.hex (openssl rsa -noout -modulus) + .sig (openssl dgst -sha256 -sign)
-- wowbit.lua, the WoW-shaped bit table this loads, is reproduced in the comment at the end of this file.
-- Benchmarks signature checks in plain Lua 5.1.5 with a WoW-shaped `bit` table.
-- usage: lua bench.lua <scriptsdir> <dldir> <keysdir> <part>
-- part: hash | ed | rsa | all
local SCRIPTS, DL, KEYS, PART = arg[1], arg[2], arg[3], arg[4] or "all"
package.path = SCRIPTS .. "/?.lua;" .. package.path
local WB = dofile(SCRIPTS .. "/wowbit.lua")
local floor = math.floor

local function readfile(p)
	local f = assert(io.open(p, "rb"))
	local s = f:read("*a")
	f:close()
	return s
end
local function hex(s) return (s:gsub(".", function(c) return ("%02x"):format(c:byte()) end)) end
local function unhex(h) return (h:gsub("%s", ""):gsub("..", function(x) return string.char(tonumber(x, 16)) end)) end

local function time(label, n, fn)
	fn() -- warm
	local t0 = os.clock()
	for _ = 1, n do fn() end
	local ms = (os.clock() - t0) / n * 1000
	print(("%-52s %9.2f ms"):format(label, ms))
	return ms
end

-- Lua 5.1 does not read "\xNN"; rewrite those escapes as decimal ones before loading.
local function fix51(src)
	return (src:gsub("\\x(%x%x)", function(h) return ("\\%03d"):format(tonumber(h, 16)) end))
end

local MSG = readfile(KEYS .. "/msg.bin")

---------------------------------------------------------------------------------------------------
-- Egor Skriptunoff's sha2.lua
local function loadSha2(bitlib)
	local env = setmetatable({}, { __index = _G })
	env._G = env
	env.bit = bitlib
	env.bit32 = nil
	local chunk = assert(loadstring(readfile(DL .. "/sha2/sha2.lua"), "sha2"))
	setfenv(chunk, env)
	return chunk()
end

-- WoW's bit has no rol/ror, so sha2.lua's LIB32 branch asserts; add them from shifts.
local WB_ROT = {}
for k, v in pairs(WB) do WB_ROT[k] = v end
WB_ROT.rol = function(x, n) return WB.bor(WB.lshift(x, n), WB.rshift(x, 32 - n)) end
WB_ROT.ror = function(x, n) return WB.bor(WB.rshift(x, n), WB.lshift(x, 32 - n)) end

local sha_wow = loadSha2(WB_ROT)
local sha_emul = loadSha2(nil)

-- bit32-like shim on the WoW-shaped table, two-argument calls only.
local M32 = 2 ^ 32
local bit32shim = {
	band = function(a, b) return WB.band(a, b) end,
	bor = function(a, b) return WB.bor(a, b) end,
	bxor = function(a, b, c)
		if c then return WB.bxor(WB.bxor(a, b), c) end
		return WB.bxor(a, b)
	end,
	bnot = function(a) return WB.bnot(a) end,
	lshift = function(a, n) return WB.lshift(a, n) end,
	rshift = function(a, n) return WB.rshift(a, n) end,
	lrotate = function(x, n) return WB.bor(WB.lshift(x, n), WB.rshift(x, 32 - n)) end,
	extract = function(x, f, w) w = w or 1 return floor(x / 2 ^ f) % 2 ^ w end,
}
local _ = M32

if PART == "hash" or PART == "all" then
	print("== hashes over 4096 bytes")
	local want256 = sha_wow.sha256(MSG)
	assert(sha_emul.sha256(MSG) == want256)
	print("sha256 = " .. want256)
	time("sha2.lua SHA-256, WoW bit + rol/ror shim", 50, function() sha_wow.sha256(MSG) end)
	time("sha2.lua SHA-256, no bit (EMUL branch)", 10, function() sha_emul.sha256(MSG) end)
	time("sha2.lua SHA-512, WoW bit + rol/ror shim", 50, function() sha_wow.sha512(MSG) end)
	time("sha2.lua SHA-512, no bit (EMUL branch)", 5, function() sha_emul.sha512(MSG) end)
	local k = ("k"):rep(32)
	time("sha2.lua HMAC-SHA-256, WoW bit", 50, function() sha_wow.hmac(sha_wow.sha256, k, MSG) end)
end

---------------------------------------------------------------------------------------------------
-- ccryptolib (migeyel) Ed25519, loaded under Lua 5.1 with stubs for the CC-only modules.
local function loadCcl()
	local cache = {}
	local stubs = {
		["cc.expect"] = { expect = function() end },
		["ccryptolib.internal.hw"] = setmetatable({}, { __index = function() return function() return false end end }),
		["ccryptolib.random"] = { random = function(n) return ("\0"):rep(n) end },
	}
	local env = setmetatable({}, { __index = _G })
	env._G = env
	env.bit32 = bit32shim
	env.table = setmetatable({ unpack = unpack }, { __index = table })
	env.load = function(s, name) if type(s) == "string" then return loadstring(s, name) end return load(s, name) end
	local function req(name)
		if stubs[name] then return stubs[name] end
		if cache[name] then return cache[name] end
		local path = DL .. "/ccl/" .. name:gsub("%.", "/") .. ".lua"
		local chunk = assert(loadstring(fix51(readfile(path)), name))
		setfenv(chunk, env)
		cache[name] = chunk()
		return cache[name]
	end
	env.require = req
	return req("ccryptolib.ed25519"), req("ccryptolib.internal.sha512")
end

if PART == "ed" or PART == "all" then
	print("== Ed25519 (ccryptolib, ported shim)")
	local ed, sha512 = loadCcl()
	-- SHA-512 cross-check against sha2.lua
	assert(hex(sha512.digest(MSG)) == sha_wow.sha512(MSG), "ccryptolib sha512 mismatch")
	-- RFC 8032 section 7.1, TEST 1 (empty message)
	local pk1 = unhex("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a")
	local sig1 = unhex("e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b")
	print("RFC 8032 TEST 1 verifies:", ed.verify(pk1, "", sig1))
	-- OpenSSL-made signature over the 4096-byte message
	local der = readfile(KEYS .. "/ed.pub.der")
	local pk = der:sub(-32)
	local sig = readfile(KEYS .. "/ed.sig")
	print("OpenSSL 4 KB signature verifies:", ed.verify(pk, MSG, sig))
	local bad = MSG:sub(1, 100) .. string.char((MSG:byte(101) + 1) % 256) .. MSG:sub(102)
	print("tampered message rejected:", not ed.verify(pk, bad, sig))
	time("Ed25519 verify, 4 KB message", 10, function() ed.verify(pk, MSG, sig) end)
	time("Ed25519 verify, empty message", 10, function() ed.verify(pk1, "", sig1) end)
	time("  of which SHA-512 of 4 KB (ccryptolib)", 50, function() sha512.digest(MSG) end)
end

---------------------------------------------------------------------------------------------------
-- RSA PKCS#1 v1.5 verify: a minimal Montgomery modexp on 24-bit limbs held in doubles (prototype).
local R = 16777216
local function bytesToLimbs(s, k) -- big-endian bytes -> k little-endian 24-bit limbs
	s = ("\0"):rep(3 * k - #s) .. s
	local t = {}
	for i = 1, k do
		local p = #s - 3 * i + 1
		local a, b, c = s:byte(p, p + 2)
		t[i] = a * 65536 + b * 256 + c
	end
	return t
end
local function limbsToBytes(t, nbytes)
	local parts = {}
	for i = #t, 1, -1 do
		local v = t[i]
		parts[#parts + 1] = string.char(floor(v / 65536), floor(v / 256) % 256, v % 256)
	end
	local s = table.concat(parts)
	return s:sub(-nbytes)
end
local function geq(a, n, k)
	for i = k, 1, -1 do
		if a[i] ~= n[i] then return a[i] > n[i] end
	end
	return true
end
local function subInPlace(a, n, k)
	local borrow = 0
	for i = 1, k do
		local x = a[i] - n[i] - borrow
		if x < 0 then x = x + R borrow = 1 else borrow = 0 end
		a[i] = x
	end
end
local function montmul(a, b, n, ninv, k)
	local t = {}
	for j = 1, k + 1 do t[j] = 0 end
	local b1, n1 = b[1], n[1]
	for i = 1, k do
		local ai = a[i]
		local u = (t[1] + ai * b1) % R
		local m = (u * ninv) % R
		local x = t[1] + ai * b1 + m * n1
		local c = (x - x % R) / R
		for j = 2, k do
			x = t[j] + ai * b[j] + m * n[j] + c
			local lo = x % R
			c = (x - lo) / R
			t[j - 1] = lo
		end
		x = t[k + 1] + c
		local lo = x % R
		t[k] = lo
		t[k + 1] = (x - lo) / R
	end
	if t[k + 1] > 0 or geq(t, n, k) then
		-- t < 2n: one subtraction, carrying the top limb
		local borrow = 0
		for i = 1, k do
			local x = t[i] - n[i] - borrow
			if x < 0 then x = x + R borrow = 1 else borrow = 0 end
			t[i] = x
		end
		t[k + 1] = t[k + 1] - borrow
	end
	t[k + 1] = nil
	return t
end
local function setupKey(nhex)
	local nbytes = #nhex / 2
	local k = math.ceil(nbytes / 3)
	local n = bytesToLimbs(unhex(nhex), k)
	-- ninv = -n^-1 mod 2^24
	local inv = 1
	for _ = 1, 6 do
		local y = (n[1] * inv) % R
		y = (2 - y) % R
		inv = (inv * y) % R
	end
	local ninv = (R - inv) % R
	-- RR = R^(2k) mod n, by doubling (done once per key; could be shipped with the key)
	local x = {}
	for i = 1, k do x[i] = 0 end
	x[1] = 1
	for _ = 1, 2 * k * 24 do
		local c = 0
		for i = 1, k do
			local v = x[i] * 2 + c
			if v >= R then v = v - R c = 1 else c = 0 end
			x[i] = v
		end
		if c == 1 or geq(x, n, k) then
			-- x < 2n; subtract n (with the carried bit)
			subInPlace(x, n, k)
		end
	end
	return { n = n, k = k, ninv = ninv, rr = x, nbytes = nbytes }
end
local function rsaPublic(key, sigBytes, e)
	local k, n, ninv = key.k, key.n, key.ninv
	local s = bytesToLimbs(sigBytes, k)
	local sM = montmul(s, key.rr, n, ninv, k)
	local x
	if e == 3 then
		x = montmul(montmul(sM, sM, n, ninv, k), sM, n, ninv, k)
	else -- 65537
		x = sM
		for _ = 1, 16 do x = montmul(x, x, n, ninv, k) end
		x = montmul(x, sM, n, ninv, k)
	end
	local one = {}
	for i = 1, k do one[i] = 0 end
	one[1] = 1
	x = montmul(x, one, n, ninv, k)
	if geq(x, n, k) then subInPlace(x, n, k) end
	return limbsToBytes(x, key.nbytes)
end
local DIGESTINFO_SHA256 = unhex("3031300d060960864801650304020105000420")
local function emsa(hashBytes, nbytes)
	local t = DIGESTINFO_SHA256 .. hashBytes
	return "\0\1" .. ("\255"):rep(nbytes - #t - 3) .. "\0" .. t
end

if PART == "rsa" or PART == "all" then
	print("== RSA PKCS#1 v1.5 + SHA-256 (prototype Montgomery, 24-bit limbs)")
	local H = unhex(sha_wow.sha256(MSG))
	for _, spec in ipairs({ { "rsa2048", 65537 }, { "rsa2048e3", 3 }, { "rsa3072", 65537 } }) do
		local name, e = spec[1], spec[2]
		local key = setupKey(readfile(KEYS .. "/" .. name .. ".n.hex"):gsub("%s", ""))
		local sig = readfile(KEYS .. "/" .. name .. ".sig")
		local ok = rsaPublic(key, sig, e) == emsa(H, key.nbytes)
		local badsig = sig:sub(1, -2) .. string.char((sig:byte(-1) + 1) % 256)
		local rej = rsaPublic(key, badsig, e) ~= emsa(H, key.nbytes)
		print(("%s e=%d: verifies %s, tampered sig rejected %s"):format(name, e, tostring(ok), tostring(rej)))
		time(("  %s e=%d modexp only"):format(name, e), 20, function() rsaPublic(key, sig, e) end)
		time(("  %s e=%d key setup (RR by doubling, once)"):format(name, e), 3, function()
			setupKey(readfile(KEYS .. "/" .. name .. ".n.hex"):gsub("%s", ""))
		end)
	end
end

--[==[ wowbit.lua
-- A `bit` table shaped like the WoW client's: only the eight names the Forever API dump lists
-- (arshift, band, bnot, bor, bxor, lshift, mod, rshift), built on LuaBitOp. No tobit, tohex, rol, ror, bswap.
-- Results are normalised to unsigned 0..2^32-1, as BitLib does; WoW's real signedness is unverified.
local L = require("bit")
local M = 2 ^ 32
local function u(x) return x % M end
local W = {
	band = function(a, b, ...) local r = L.band(a, b, ...) return r % M end,
	bor = function(a, b, ...) local r = L.bor(a, b, ...) return r % M end,
	bxor = function(a, b, ...) local r = L.bxor(a, b, ...) return r % M end,
	bnot = function(a) return L.bnot(a) % M end,
	lshift = function(a, n) return L.lshift(a, n) % M end,
	rshift = function(a, n) return L.rshift(a, n) % M end,
	arshift = function(a, n) return L.arshift(a, n) % M end,
	mod = function(a, n) return math.fmod(a, n) end,
}
local _ = u
return W
]==]
