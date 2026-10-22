-- Core's RSA-2048 PKCS#1 v1.5 check (PUSH-R11) against known answers from outside Pagle's code: openssl over the
-- test key (spec/Pagle/fixtures/Signing.lua, written by scripts/make-signing-fixtures.sh) and C2SP Wycheproof's
-- rsa_signature_2048_sha256_test.json at commit 7a325932 (spec/Pagle/fixtures/wycheproof/, Apache 2.0).

local MISMATCH = "the signature doesn't match"
local LENGTH = "the signature isn't as long as the modulus"
local RANGE = "the signature isn't below the modulus"
local KEY = "the key is malformed"
local DIGEST = "the digest isn't 32 bytes"

describe("ns.RsaVerifySteps", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns
	local fixtures = signingFixtures()
	local testKey = fixtures.testKey

	-- `bytes` with bit `bit` (0 = the lowest) of byte `at` flipped.
	local function flipped(bytes, at, bit)
		local byte = bytes:byte(at)
		local mask = 2 ^ bit
		local value = math.floor(byte / mask) % 2 == 1 and byte - mask or byte + mask
		return bytes:sub(1, at - 1) .. string.char(value) .. bytes:sub(at + 1)
	end

	-- Runs every step to the verdict, counting the steps and the Montgomery multiplications each did.
	local function stepped(key, signature, digest)
		local step = ns.RsaVerifySteps(key, signature, digest)
		local perStep = {}
		local ok, why
		repeat
			local before = ns.RsaMultiplications()
			ok, why = step()
			perStep[#perStep + 1] = ns.RsaMultiplications() - before
		until ok ~= nil
		return ok, why, perStep
	end

	-- Whether big-endian `a` is below `b`, both of the same length.
	local function below(a, b)
		for i = 1, #a do
			if a:byte(i) ~= b:byte(i) then
				return a:byte(i) < b:byte(i)
			end
		end
		return false
	end

	local function message(signed)
		return signed.message and fromHex(signed.message) or fixtures.data:sub(1, signed.prefix)
	end

	describe("over the test key's signatures by openssl dgst -sha256 -sign", function()
		it("accepts each one (PUSH-R11)", function()
			assert.are.equal(5, #fixtures.signatures)
			for _, signed in ipairs(fixtures.signatures) do
				local ok, why = ns.RsaVerify(testKey, fromHex(signed.signature), ns.Sha256(message(signed)))

				assert.are.equal(true, ok, why)
				assert.is_nil(why)
			end
		end)

		it("rejects each one with a payload bit flipped (PUSH-R11)", function()
			for _, signed in ipairs(fixtures.signatures) do
				local bytes = message(signed)
				if #bytes > 0 then
					for _, at in ipairs({ 1, math.ceil(#bytes / 2), #bytes }) do
						local ok, why =
							ns.RsaVerify(testKey, fromHex(signed.signature), ns.Sha256(flipped(bytes, at, 0)))

						assert.is_false(ok)
						assert.are.equal(MISMATCH, why)
					end
				end
			end
		end)

		it("rejects each one with a signature bit flipped, wherever it is (PUSH-R11)", function()
			local n = fromHex(testKey.n)
			for _, signed in ipairs(fixtures.signatures) do
				local signature, digest = fromHex(signed.signature), ns.Sha256(message(signed))
				for _, at in ipairs({ 1, 2, 100, 255, 256 }) do
					for _, bit in ipairs({ 0, 7 }) do
						local wrong = flipped(signature, at, bit)
						local ok, why = ns.RsaVerify(testKey, wrong, digest)

						assert.is_false(ok)
						assert.are.equal(below(wrong, n) and MISMATCH or RANGE, why)
					end
				end
			end
		end)

		it("rejects a signature under another key (PUSH-R12)", function()
			local signed = fixtures.signatures[2]
			local signature = fromHex(signed.signature)
			local ok, why = ns.RsaVerify(fixtures.wycheproofKey, signature, ns.Sha256(message(signed)))

			assert.is_false(ok)
			assert.are.equal(below(signature, fromHex(fixtures.wycheproofKey.n)) and MISMATCH or RANGE, why)
		end)
	end)

	describe("over blocks the test key signed raw", function()
		it("accepts the exact EMSA-PKCS1-v1_5 block, and rejects every other block (PUSH-R11)", function()
			assert.are.equal(12, #fixtures.crafted)
			local digest = ns.Sha256("abc")
			for _, crafted in ipairs(fixtures.crafted) do
				local ok, why = ns.RsaVerify(testKey, fromHex(crafted.signature), digest)

				if crafted.name == "exact" then
					assert.are.equal(true, ok, why)
				else
					assert.are.equal(false, ok, crafted.name)
					assert.are.equal(MISMATCH, why)
				end
			end
		end)
	end)

	describe("over Wycheproof's rsa_signature_2048_sha256 vectors", function()
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1 with dkjson; the WoW client has no require
		local json = require("dkjson")
		local suite = json.decode(readFile("spec/Pagle/fixtures/wycheproof/rsa_signature_2048_sha256_test.json"))
		-- The first group is the one with e = 65537, the exponent PUSH-R11 fixes; the other two use e = 3.
		local group = suite.testGroups[1]

		it("are the pinned file, its first group RSA-2048 with SHA-256 and e = 65537 (PUSH-R11)", function()
			assert.are.equal("RSASSA-PKCS1-v1_5", suite.algorithm)
			assert.are.equal(2048, group.keySize)
			assert.are.equal("SHA-256", group.sha)
			assert.are.equal("010001", group.publicKey.publicExponent)
			assert.are.equal("00" .. fixtures.wycheproofKey.n, group.publicKey.modulus)
			assert.are.equal(257, #group.tests)
		end)

		it(
			"accepts each valid vector, and rejects each invalid or merely acceptable one with a reason (PUSH-R11)",
			function()
				local verdicts = {}
				for _, test in ipairs(group.tests) do
					local ok, why =
						ns.RsaVerify(fixtures.wycheproofKey, fromHex(test.sig), ns.Sha256(fromHex(test.msg)))
					local label = ("tcId %d (%s, %s)"):format(test.tcId, test.result, test.comment)

					if test.result == "valid" then
						assert.are.equal(true, ok, label .. ": " .. tostring(why))
					else
						-- "acceptable" is tcId 8, a DigestInfo without its NULL, which a strict check rejects.
						assert.are.equal(false, ok, label)
						assert.are.equal("string", type(why), label)
					end
					verdicts[test.result] = (verdicts[test.result] or 0) + 1
				end

				assert.are.same({ valid = 7, acceptable = 1, invalid = 249 }, verdicts)
			end
		)

		it("gives the length, range or mismatch reason each vector calls for (PUSH-R11)", function()
			local want = {
				[246] = MISMATCH, -- "2 bytes too long": the modulus's bytes shifted two places, 256 bytes and below n
				[247] = LENGTH, -- the signature is empty
				[244] = RANGE, -- the signature is not reduced (s + n)
				[245] = RANGE,
				[252] = RANGE, -- the signature has value n
				[253] = RANGE, -- n + 1
				[254] = RANGE, -- -1, as 256 bytes of FF
				[248] = MISMATCH, -- 0
				[249] = MISMATCH, -- 1
				[250] = MISMATCH, -- 2
				[251] = MISMATCH, -- n - 1
				[8] = MISMATCH, -- the missing NULL
				[243] = MISMATCH, -- PKCS#1 padding too short
				[255] = MISMATCH, -- an RSASSA-PSS signature
			}
			for _, test in ipairs(group.tests) do
				if want[test.tcId] then
					local _, why = ns.RsaVerify(fixtures.wycheproofKey, fromHex(test.sig), ns.Sha256(fromHex(test.msg)))

					assert.are.equal(want[test.tcId], why, "tcId " .. test.tcId)
				end
			end
		end)
	end)

	describe("checking the signature's form before any multiplication", function()
		local signature = fromHex(fixtures.signatures[2].signature)
		local digest = ns.Sha256("abc")

		it("rejects a signature one byte short or long, or empty, as the wrong length (PUSH-R11)", function()
			for _, wrong in ipairs({ signature:sub(2), "\0" .. signature, signature .. "\0", "" }) do
				local ok, why, perStep = stepped(testKey, wrong, digest)

				assert.is_false(ok)
				assert.are.equal(LENGTH, why)
				assert.are.same({ 0 }, perStep)
			end
		end)

		it("rejects n, n + 1 and 256 bytes of FF as not below the modulus (PUSH-R11)", function()
			local n = fromHex(testKey.n)
			local nPlusOne = n:sub(1, 255) .. string.char(n:byte(256) + 1)
			for _, wrong in ipairs({ n, nPlusOne, ("\255"):rep(256) }) do
				local ok, why, perStep = stepped(testKey, wrong, digest)

				assert.is_false(ok)
				assert.are.equal(RANGE, why)
				assert.are.same({ 0 }, perStep)
			end
		end)

		it("rejects a signature that isn't a string (PUSH-R11)", function()
			local ok, why = ns.RsaVerify(testKey, nil, digest)

			assert.is_false(ok)
			assert.are.equal(LENGTH, why)
		end)

		it("rejects a digest that isn't 32 bytes (PUSH-R11)", function()
			for _, wrong in ipairs({ digest:sub(2), digest .. "\0", "", 42 }) do
				local ok, why = ns.RsaVerify(testKey, signature, wrong)

				assert.is_false(ok)
				assert.are.equal(DIGEST, why)
			end
		end)
	end)

	describe("checking the key's form (PUSH-R12)", function()
		local signed = fixtures.signatures[2]
		local signature, digest = fromHex(signed.signature), ns.Sha256("abc")

		local function with(field, value)
			local key = { n = testKey.n, rr = testKey.rr, n0inv = testKey.n0inv }
			key[field] = value
			return key
		end

		it(
			"rejects a modulus that isn't 2048 bits, a 1024-bit, 2040-bit or 3072-bit one among them (PUSH-R11)",
			function()
				for _, n in ipairs({
					testKey.n:sub(257), -- 1024 bits
					testKey.n:sub(3), -- 2040 bits
					testKey.n .. testKey.n:sub(1, 256), -- 3072 bits
					"00" .. testKey.n:sub(3), -- 256 bytes, but under 2^2047
					testKey.n .. "00",
				}) do
					local ok, why, perStep = stepped(with("n", n), signature, digest)

					assert.is_false(ok)
					assert.are.equal(KEY, why)
					assert.are.same({ 0 }, perStep)
				end
			end
		)

		it("rejects an even modulus, or one in capitals or with a stray character (PUSH-R12)", function()
			local even = testKey.n:sub(1, 511) .. "2"
			for _, key in ipairs({
				with("n", even),
				with("n", testKey.n:upper()),
				with("n", testKey.n:sub(1, 511) .. "g"),
				with("n", nil),
				with("n", 42),
			}) do
				local ok, why = ns.RsaVerify(key, signature, digest)

				assert.is_false(ok)
				assert.are.equal(KEY, why)
			end
		end)

		it("rejects an rr that isn't 512 hex digits below the modulus (PUSH-R12)", function()
			for _, rr in ipairs({ testKey.rr:sub(3), testKey.rr .. "00", testKey.n, ("f"):rep(512), nil }) do
				local ok, why = ns.RsaVerify(with("rr", rr), signature, digest)

				assert.is_false(ok)
				assert.are.equal(KEY, why)
			end
		end)

		it("rejects an n0inv that isn't -n^-1 mod 2^24 (PUSH-R12)", function()
			for _, n0inv in ipairs({ testKey.n0inv + 1, 0, -testKey.n0inv, 2 ^ 24 + testKey.n0inv, 1.5, "1", nil }) do
				local ok, why = ns.RsaVerify(with("n0inv", n0inv), signature, digest)

				assert.is_false(ok)
				assert.are.equal(KEY, why)
			end
		end)

		it("rejects a key that isn't a table (PUSH-R12)", function()
			local ok, why = ns.RsaVerify(nil, signature, digest)

			assert.is_false(ok)
			assert.are.equal(KEY, why)
		end)

		it("fails, without crashing, on a well-formed key whose rr is wrong (PUSH-R12)", function()
			local ok, why = ns.RsaVerify(with("rr", ("0"):rep(511) .. "1"), signature, digest)

			assert.is_false(ok)
			assert.are.equal(MISMATCH, why)
		end)
	end)

	describe("in steps", function()
		local signed = fixtures.signatures[2]
		local signature, digest = fromHex(signed.signature), ns.Sha256("abc")

		it(
			"does at most one Montgomery multiplication a step, 18 in all: in, 16 squarings, and s (PUSH-R10, PUSH-R11)",
			function()
				for _, case in ipairs({ { signature, true }, { flipped(signature, 100, 3), false } }) do
					local ok, _, perStep = stepped(testKey, case[1], digest)

					assert.are.equal(case[2], ok)
					local total = 0
					for index, count in ipairs(perStep) do
						assert.are.equal(true, count <= 1, "step " .. index .. " did " .. count)
						total = total + count
					end
					assert.are.equal(18, total)
					assert.are.equal(20, #perStep)
				end
			end
		)

		it("gives nothing until the last step, then the verdict, and the same verdict after (PUSH-R10)", function()
			local step = ns.RsaVerifySteps(testKey, flipped(signature, 50, 1), digest)
			for _ = 1, 19 do
				assert.are.same({}, { step() })
			end

			assert.are.same({ false, MISMATCH }, { step() })
			assert.are.same({ false, MISMATCH }, { step() })
			local before = ns.RsaMultiplications()
			step()
			assert.are.equal(before, ns.RsaMultiplications())
		end)

		it("keeps two checks in flight apart, as a coroutine would interleave them (PUSH-R10)", function()
			local good = ns.RsaVerifySteps(testKey, signature, digest)
			local bad = ns.RsaVerifySteps(testKey, flipped(signature, 80, 5), digest)
			local goodOk, badOk
			for _ = 1, 20 do
				goodOk, badOk = good(), bad()
			end

			assert.is_true(goodOk)
			assert.is_false(badOk)
		end)

		it("reads the key once, at its first step: a key changed mid-check doesn't change it (PUSH-R10)", function()
			local key = { n = testKey.n, rr = testKey.rr, n0inv = testKey.n0inv }
			local step = ns.RsaVerifySteps(key, signature, digest)
			step()
			key.n, key.rr = ("f"):rep(512), ("0"):rep(512)
			local ok
			repeat
				ok = step()
			until ok ~= nil

			assert.is_true(ok)
		end)
	end)
end)

describe("ns.RsaVp1", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns
	local fixtures = signingFixtures()

	it("computes s^65537 mod n as openssl's raw RSA does, 0, 1, 2, n - 2 and n - 1 among them (PUSH-R11)", function()
		assert.are.equal(17, #fixtures.raw)
		for _, raw in ipairs(fixtures.raw) do
			assert.are.equal(raw.m, toHex(assert(ns.RsaVp1(fixtures.testKey, fromHex(raw.s)))), raw.s)
		end
	end)

	it("gives nil and the reason for a signature it can't take (PUSH-R11)", function()
		local m, why = ns.RsaVp1(fixtures.testKey, "\1")

		assert.is_nil(m)
		assert.are.equal(LENGTH, why)
	end)
end)

describe("the signature code", function()
	local FILES = {
		"addons/Pagle/logic/Base64.lua",
		"addons/Pagle/logic/Sha256.lua",
		"addons/Pagle/logic/Rsa.lua",
		"addons/Pagle/logic/PushedKeys.lua",
	}

	it("makes no bit library call, so it doesn't depend on the client's `bit` (PUSH-R11)", function()
		for _, path in ipairs(FILES) do
			local code = withoutComments(readFile(path))

			assert.are.equal(nil, code:match("[%w_]*bit%s*%.%s*[%a_]+"), path)
			assert.are.equal(nil, code:match("bit%s*%["), path)
			assert.are.equal(nil, code:match("bit32"), path)
		end
	end)

	it("never loads code from data (PUSH-R20)", function()
		for _, path in ipairs(FILES) do
			local code = withoutComments(readFile(path))

			assert.are.equal(nil, code:match("loadstring"), path)
			assert.are.equal(nil, code:match("setfenv"), path)
		end
	end)

	it("is in Core's TOC, in logic/ (CORE-R7)", function()
		local at = {}
		for index, file in ipairs(addonFiles("Pagle")) do
			at[file] = index
		end
		for _, path in ipairs(FILES) do
			assert.are.equal("number", type(at[path:sub(#"addons/Pagle/" + 1)]), path)
		end
	end)
end)

describe("the private test key", function()
	it("is nowhere in the addons/ folders scripts/package.sh zips, nor any other private key (PUSH-R12)", function()
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
		local grep = assert(io.popen("git ls-files -z addons | xargs -0 grep -l -e 'PRIVATE KEY' -e 'BEGIN RSA' --"))
		local found = grep:read("*a")
		grep:close()

		assert.are.equal("", found)
	end)

	it("lives under spec/ only, marked TEST ONLY (PUSH-R12)", function()
		local pem = readFile("spec/Pagle/fixtures/signing/test-only-private-key.pem")

		assert.are.equal(1, pem:find("TEST ONLY", 1, true))
		assert.is_truthy(pem:find("-----BEGIN PRIVATE KEY-----", 1, true))
	end)
end)
