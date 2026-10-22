describe("ns.Base64Decode", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns
	local fixtures = signingFixtures()

	local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

	-- The spec's own encoder (RFC 4648 §4), to round-trip byte strings the fixtures don't hold.
	local function encode(bytes)
		local out = {}
		for i = 1, #bytes, 3 do
			local a, b, c = bytes:byte(i, i + 2)
			local n = a * 65536 + (b or 0) * 256 + (c or 0)
			local quad = {}
			for k = 1, 4 do
				local sextet = math.floor(n / 2 ^ (6 * (4 - k))) % 64
				quad[k] = ALPHABET:sub(sextet + 1, sextet + 1)
			end
			if not b then
				quad[3], quad[4] = "=", "="
			elseif not c then
				quad[4] = "="
			end
			out[#out + 1] = table.concat(quad)
		end
		return table.concat(out)
	end

	it("decodes RFC 4648 §10's test vectors (PUSH-R2)", function()
		local vectors = {
			{ "", "" },
			{ "Zg==", "f" },
			{ "Zm8=", "fo" },
			{ "Zm9v", "foo" },
			{ "Zm9vYg==", "foob" },
			{ "Zm9vYmE=", "fooba" },
			{ "Zm9vYmFy", "foobar" },
		}
		for _, vector in ipairs(vectors) do
			assert.are.equal(vector[2], ns.Base64Decode(vector[1]))
		end
	end)

	it("decodes openssl's Base64 of every byte value, 0 to 255 (PUSH-R2)", function()
		local all = {}
		for byte = 0, 255 do
			all[#all + 1] = string.char(byte)
		end

		assert.are.equal(table.concat(all), ns.Base64Decode(fixtures.allBytesBase64))
	end)

	it("round-trips every byte value in each position of a quad, and every length to 70 (PUSH-R2)", function()
		for byte = 0, 255 do
			local c = string.char(byte)
			for _, bytes in ipairs({ c, "a" .. c, "ab" .. c, c .. "ab", c .. c .. c }) do
				assert.are.equal(bytes, ns.Base64Decode(encode(bytes)))
			end
		end
		for length = 0, 70 do
			local bytes = fixtures.data:sub(1, length)
			assert.are.equal(bytes, ns.Base64Decode(encode(bytes)))
		end
	end)

	it("decodes 64 KiB, the payload cap, exactly (PUSH-R2)", function()
		assert.are.equal(fixtures.data, ns.Base64Decode(encode(fixtures.data)))
	end)

	it("rejects a character outside the alphabet, whitespace and line ends included (PUSH-R2)", function()
		for _, text in ipairs({
			"Zm9v!mFy",
			"Zm9v YmF",
			"Zm9v\nYmF",
			"Zm9vYmF\r",
			"Zm9vYm\r\n",
			"Zm9-",
			"Zm9_",
			"Zm\0v",
		}) do
			local bytes, why = ns.Base64Decode(text)

			assert.is_nil(bytes)
			assert.are.equal("a character outside the Base64 alphabet", why)
		end
		local bytes, why = ns.Base64Decode("Zm9vYmFy\195\169===")
		assert.is_nil(bytes)
		assert.is_string(why)
	end)

	it("rejects a length that isn't a multiple of 4 (PUSH-R2)", function()
		for _, text in ipairs({ "Z", "Zm", "Zm9", "Zm9vY", "Zg=", "Zg", "Zm9vYmFy=" }) do
			local bytes, why = ns.Base64Decode(text)

			assert.is_nil(bytes)
			assert.are.equal("a length that isn't a multiple of 4", why)
		end
	end)

	it("rejects bad padding: '=' anywhere but the last two places, three of them, or stray bits (PUSH-R2)", function()
		for _, text in ipairs({
			"====",
			"Z===",
			"Zg=a",
			"=m9v",
			"Zm=v",
			"Zg==Zm9v",
			"Zm8=Zm9v",
			"Zh==", -- 'f' is Zg==: the last sextet's low four bits must be zero
			"Zm9=", -- "fo" is Zm8=: the last sextet's low two bits must be zero
			"Zm9vYmFyZh==",
		}) do
			local bytes, why = ns.Base64Decode(text)

			assert.are.equal(nil, bytes, text)
			assert.are.equal("bad padding", why)
		end
	end)

	it("rejects a value that isn't a string (PUSH-R2)", function()
		for _, value in ipairs({ 42, true, {} }) do
			local bytes, why = ns.Base64Decode(value)

			assert.is_nil(bytes)
			assert.are.equal("not a string", why)
		end
	end)
end)

describe("ns.Base64DecodeSteps", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns
	local fixtures = signingFixtures()

	-- Every step to the verdict, `chars` characters a step: the verdict, the bytes or reason, and the calls it took.
	local function stepped(text, chars)
		local step = ns.Base64DecodeSteps(text, chars)
		local calls = 0
		local ok, result
		repeat
			calls = calls + 1
			ok, result = step()
		until ok ~= nil
		return ok, result, calls
	end

	-- What one ns.Base64Decode call gives, in the steps' form.
	local function once(text)
		local bytes, why = ns.Base64Decode(text)
		if bytes then
			return true, bytes
		end
		return false, why
	end

	it("decodes 64 KiB a chunk a step, to the same bytes as one call (PUSH-R2, PUSH-R10)", function()
		local text = toBase64(fixtures.data)

		local ok, bytes, calls = stepped(text)

		assert.is_true(ok)
		assert.are.equal(fixtures.data, bytes)
		-- 87384 characters at 8192 a step: ten whole chunks, and the rest with the padding in the last.
		assert.are.equal(11, calls)
		local _, small = stepped(text, 4)
		assert.are.equal(true, small == bytes, "4 characters a step")
	end)

	it("gives one call's verdict and reason for every bad text, whichever chunk the fault is in (PUSH-R2)", function()
		local good = toBase64(fixtures.data:sub(1, 30)) -- 40 characters, no padding
		local texts = { "", "QQ", "QQ=", "Q===", "QR==", "not a string?", good .. "QQ==", good .. "QR==" }
		for at = 1, #good do
			for _, bad in ipairs({ "=", "*", " ", "-" }) do
				texts[#texts + 1] = good:sub(1, at - 1) .. bad .. good:sub(at + 1)
			end
			texts[#texts + 1] = good:sub(1, at - 1) .. "*" .. good:sub(at + 1, at + 2) .. "=" .. good:sub(at + 4)
		end
		for _, text in ipairs(texts) do
			for _, chars in ipairs({ 4, 8, 12, 40, 8192 }) do
				local ok, result = stepped(text, chars)
				assert.are.same({ once(text) }, { ok, result }, ("%q in chunks of %d"):format(text, chars))
			end
		end
		for _, value in ipairs({ 42, true }) do
			local ok, why = stepped(value)
			assert.are.same({ false, "not a string" }, { ok, why })
		end
	end)

	it("keeps its verdict for calls after the last", function()
		local step = ns.Base64DecodeSteps("Zm9v", 4)

		assert.are.same({ true, "foo" }, { step() })
		assert.are.same({ true, "foo" }, { step() })
	end)
end)
