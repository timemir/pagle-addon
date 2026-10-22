-- The public keys Core checks pushed content with (PUSH-R12), and the per-key values scripts/pushed-key.py prints for
-- them, recomputed here by a slow, separate route: 16-bit limbs and repeated doubling, nothing shared with logic/Rsa.lua.

local LIMB = 65536

-- `hex` (big-endian) as 16-bit limbs, the lowest first.
local function limbs(hex)
	local out = {}
	for i = #hex - 3, 1, -4 do
		out[#out + 1] = tonumber(hex:sub(i, i + 3), 16)
	end
	return out
end

-- Whether a >= b, both with the same number of limbs.
local function atLeast(a, b)
	for i = #a, 1, -1 do
		if a[i] ~= b[i] then
			return a[i] > b[i]
		end
	end
	return true
end

-- 2^power mod n, by doubling 1 `power` times and subtracting n whenever the value reaches it.
local function twoToThe(power, nHex)
	local n = limbs(nHex)
	local x = {}
	for i = 1, #n do
		x[i] = 0
	end
	x[1] = 1
	for _ = 1, power do
		local carry = 0
		for i = 1, #x do
			local v = x[i] * 2 + carry
			carry = v >= LIMB and 1 or 0
			x[i] = v - carry * LIMB
		end
		if carry == 1 or atLeast(x, n) then
			local borrow = 0
			for i = 1, #x do
				local v = x[i] - n[i] - borrow
				borrow = v < 0 and 1 or 0
				x[i] = v + borrow * LIMB
			end
		end
	end
	local hex = {}
	for i = #x, 1, -1 do
		hex[#hex + 1] = ("%04x"):format(x[i])
	end
	return table.concat(hex)
end

-- Checks one key entry's form and values: n 2048 bits and odd, rr = R^2 mod n with R = 2^(24 * 86), and
-- n0inv = -n^-1 mod 2^24.
local function assertWellFormed(key, label)
	assert.are.equal(512, #key.n, label)
	assert.are.equal(nil, key.n:find("[^0-9a-f]"), label)
	assert.are.equal(true, tonumber(key.n:sub(1, 1), 16) >= 8, label)
	assert.are.equal(1, tonumber(key.n:sub(-1), 16) % 2, label)
	assert.are.equal(twoToThe(2 * 24 * 86, key.n), key.rr, label)
	local low = tonumber(key.n:sub(-6), 16)
	assert.are.equal(2 ^ 24 - 1, (low * key.n0inv) % 2 ^ 24, label)
	assert.are.equal(true, key.n0inv >= 0 and key.n0inv < 2 ^ 24 and key.n0inv % 1 == 0, label)
end

describe("ns.PUSHED_KEYS", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	it("ships pagle-backend's current key, pagle-2026a, and its next, pagle-2026b, and no other (PUSH-R12)", function()
		local keyIds = {}
		for keyId in pairs(ns.PUSHED_KEYS) do
			keyIds[#keyIds + 1] = keyId
		end
		table.sort(keyIds)

		assert.are.same({ "pagle-2026a", "pagle-2026b" }, keyIds)
		for _, keyId in ipairs(keyIds) do
			local key = ns.PUSHED_KEYS[keyId]
			assert.are.equal(512, #key.n, keyId)
			assert(type(key.rr) == "string", keyId)
			assert(type(key.n0inv) == "number", keyId)
		end
		assert.are_not.equal(ns.PUSHED_KEYS["pagle-2026a"].n, ns.PUSHED_KEYS["pagle-2026b"].n)
	end)

	it("never ships the TEST ONLY key: a spec hands it in itself (PUSH-R12)", function()
		local testKey = pushedContentFixtures().testKey

		assert.is_nil(ns.PUSHED_KEYS.testKey)
		for keyId, key in pairs(ns.PUSHED_KEYS) do
			assert.are_not.equal(testKey.n, key.n, keyId)
		end
	end)

	it("names each key in its header, which is current and which next, and the backend commit (PUSH-R12)", function()
		local header = readFile("addons/Pagle/logic/PushedKeys.lua"):match("^(.-)\n[^%-]")

		assert.is_truthy(header:find("pagle-2026a, the current key", 1, true))
		assert.is_truthy(header:find("pagle-2026b, the next key", 1, true))
		assert.is_truthy(header:find("ede15a8", 1, true))
	end)

	it("holds only well-formed entries, by key ID, each n, rr and n0inv (PUSH-R11, PUSH-R12)", function()
		for keyId, key in pairs(ns.PUSHED_KEYS) do
			assert.is_string(keyId)
			assertWellFormed(key, keyId)
		end
	end)

	it("says in its header how to add a key, with scripts/pushed-key.py (PUSH-R12)", function()
		local header = readFile("addons/Pagle/logic/PushedKeys.lua"):match("^(.-)\n[^%-]")

		assert.is_truthy(header:find("scripts/pushed-key.py", 1, true))
		assert.is_truthy(header:find("pagle-backend", 1, true))
	end)
end)

describe("scripts/pushed-key.py's values for the fixture keys", function()
	local fixtures = signingFixtures()

	it("match a separate computation, for the test key and Wycheproof's (PUSH-R11)", function()
		assertWellFormed(fixtures.testKey, "testKey")
		assertWellFormed(fixtures.wycheproofKey, "wycheproofKey")
	end)
end)
