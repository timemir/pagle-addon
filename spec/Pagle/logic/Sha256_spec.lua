describe("ns.Sha256", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns
	local fixtures = signingFixtures()

	-- The examples of FIPS 180-4 (NIST's "SHA256.pdf" and "SHA2_Additional.pdf" example files, the same messages as
	-- FIPS 180-2 Appendix B): "abc", the 448-bit message, and a million "a".
	local ABC = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
	local TWO_BLOCKS = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
	local TWO_BLOCKS_DIGEST = "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
	local MILLION_A = "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0"

	it("returns 32 raw bytes (PUSH-R11)", function()
		assert.are.equal(32, #ns.Sha256(""))
	end)

	it("hashes FIPS 180-4's one-block, two-block and million-'a' examples (PUSH-R11)", function()
		assert.are.equal(ABC, toHex(ns.Sha256("abc")))
		assert.are.equal(56, #TWO_BLOCKS)
		assert.are.equal(TWO_BLOCKS_DIGEST, toHex(ns.Sha256(TWO_BLOCKS)))
		assert.are.equal(MILLION_A, toHex(ns.Sha256(("a"):rep(1000000))))
	end)

	it("matches openssl dgst -sha256 at every length to 130 bytes, across each padding boundary (PUSH-R11)", function()
		for length, digest in pairs(fixtures.prefixDigests) do
			assert.are.equal(digest, toHex(ns.Sha256(fixtures.data:sub(1, length))), "length " .. length)
		end
	end)

	it("matches openssl dgst -sha256 over a 64 KiB file, in one piece (PUSH-R11)", function()
		assert.are.equal(65536, #fixtures.data)
		assert.are.equal(fixtures.prefixDigests[65536], toHex(ns.Sha256(fixtures.data)))
	end)

	describe("hashing incrementally", function()
		local function inChunks(bytes, size)
			local hash = ns.NewSha256()
			for i = 1, #bytes, size do
				hash:Update(bytes:sub(i, i + size - 1))
			end
			return hash:Final()
		end

		it("gives the same digest for the 64 KiB file fed in 1 KiB chunks (PUSH-R10, PUSH-R11)", function()
			assert.are.equal(fixtures.prefixDigests[65536], toHex(inChunks(fixtures.data, 1024)))
		end)

		it("gives the same digest whatever the chunks' sizes, aligned to a block or not (PUSH-R11)", function()
			local bytes = fixtures.data:sub(1, 4096)
			for _, size in ipairs({ 1, 3, 55, 56, 63, 64, 65, 127, 1000, 4096 }) do
				assert.are.equal(fixtures.prefixDigests[4096], toHex(inChunks(bytes, size)), "chunks of " .. size)
			end
		end)

		it("treats empty updates as nothing, and hashes nothing as the empty message (PUSH-R11)", function()
			local hash = ns.NewSha256()
			hash:Update("")
			hash:Update("ab")
			hash:Update("")
			hash:Update("c")

			assert.are.equal(ABC, toHex(hash:Final()))
			assert.are.equal(fixtures.prefixDigests[0], toHex(ns.NewSha256():Final()))
		end)

		it("keeps separate hashes apart (PUSH-R11)", function()
			local one, two = ns.NewSha256(), ns.NewSha256()
			one:Update("ab")
			two:Update(TWO_BLOCKS:sub(1, 30))
			one:Update("c")
			two:Update(TWO_BLOCKS:sub(31))

			assert.are.equal(ABC, toHex(one:Final()))
			assert.are.equal(TWO_BLOCKS_DIGEST, toHex(two:Final()))
		end)

		it("can build its tables in steps first, which a coroutine yields between (PUSH-R10)", function()
			-- Nothing holds the tables now, so the collector takes them and the preparation starts afresh.
			collectgarbage("collect")
			collectgarbage("collect")
			local prepare = ns.Sha256Prepare()
			local steps = 1
			while not prepare() do
				steps = steps + 1
			end

			assert.are.equal(13, steps)
			assert.is_true(prepare())
			local hash = ns.NewSha256()
			hash:Update(fixtures.data:sub(1, 4096))
			assert.are.equal(fixtures.prefixDigests[4096], toHex(hash:Final()))
			assert.is_true(ns.Sha256Prepare()())
		end)

		it("refuses an update or a second final once it has given its digest (PUSH-R11)", function()
			local hash = ns.NewSha256()
			hash:Final()

			assert.has_error(function()
				hash:Update("a")
			end)
			assert.has_error(function()
				hash:Final()
			end)
		end)
	end)
end)
