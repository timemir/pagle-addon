-- Core's pushed-content reader (core/pushed-content.md, ADR 0013): the check of PagleContentData over frames
-- (PUSH-R10–R13), the companion states (PUSH-R15, PUSH-R16), the hand-out (PUSH-R21–R23) and `/pagle dev content`'s
-- report (PUSH-R14), over files signed by openssl with the TEST ONLY key (scripts/make-content-fixtures.sh).

local DAY = 24 * 3600

describe("ns.NewPushedContent", function()
	local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
	local ns = loaded.ns
	local fixtures = pushedContentFixtures()

	-- A reader over `data` (a PagleContentData), with the test key alone as Core's keys, PagleDB.global `global`, the
	-- server time `now` (SERVER_TIME by default) and a clock that stands still unless `clock` is given. `run()` starts
	-- it and runs every frame to the end; `frame()` runs one.
	local function reader(data, options)
		options = options or {}
		local r = {
			fired = {},
			reports = {},
			reads = 0,
			queue = {},
			frames = 0,
			now = options.now or SERVER_TIME,
			global = options.global or { pushed = {} },
		}
		r.content = ns.NewPushedContent({
			data = function()
				r.reads = r.reads + 1
				return data
			end,
			presence = function()
				return options.presence or { installed = true, loaded = true }
			end,
			keys = function()
				return { testKey = fixtures.testKey }
			end,
			global = options.globalFn or function()
				return r.global
			end,
			serverTime = function()
				return r.now
			end,
			clock = options.clock or function()
				return 0
			end,
			nextFrame = function(step)
				r.queue[#r.queue + 1] = step
			end,
			fire = function(state)
				r.fired[#r.fired + 1] = state
			end,
			report = function(message)
				r.reports[#r.reports + 1] = message
			end,
		})
		function r.frame()
			local queue = r.queue
			r.queue = {}
			for _, step in ipairs(queue) do
				r.frames = r.frames + 1
				step()
			end
		end
		function r.run()
			r.content:Start()
			while #r.queue > 0 do
				r.frame()
			end
			return r
		end
		return r
	end

	-- A copy of `data` with `changes` made; ns.NONE removes a field.
	local NONE = {}
	local function with(data, changes)
		local copy = {}
		for key, value in pairs(data) do
			copy[key] = value
		end
		for key, value in pairs(changes) do
			if value == NONE then
				copy[key] = nil
			else
				copy[key] = value
			end
		end
		return copy
	end

	-- `bytes` with byte `at` flipped in its lowest bit.
	local function flipped(bytes, at)
		local byte = bytes:byte(at)
		return bytes:sub(1, at - 1) .. string.char(byte % 2 == 0 and byte + 1 or byte - 1) .. bytes:sub(at + 1)
	end

	-- The decoded payload of a fixture.
	local function payloadOf(data)
		return assert(ns.Base64Decode(data.payload))
	end

	describe("a file signed with the test key", function()
		it(
			"reads connected, hands out the run, drops the unknown kinds and stores the seq (PUSH-R13, PUSH-R15, PUSH-R21–R22)",
			function()
				local r = reader(fixtures.good).run()

				assert.are.equal("connected", r.content:State())
				assert.are.same({ "connected" }, r.fired)
				assert.are.equal(42, r.global.pushed.seq)
				local runs = r.content:Items("huntRun")
				assert.are.same(
					{ { kind = "huntRun", v = 1, event = "p_test_tide", start = 1791720000, ["end"] = 1791979200 } },
					runs
				)
				assert.are.equal(1, #r.content:Items("huntEvent"))
				assert.are.same({}, r.content:Items("notice"))
				assert.are.same({}, r.content:Items("nothing"))
				assert.are.same({}, r.reports)
			end
		)

		it("hands out a fresh deep copy each call, which the caller may change (PUSH-R22)", function()
			local r = reader(fixtures.good).run()

			local first = r.content:Items("huntEvent")
			first[1].hunts[1].tiers[1] = 999
			first[1].zones = nil
			local second = r.content:Items("huntEvent")

			assert.are_not.equal(first, second)
			assert.are_not.equal(first[1], second[1])
			assert.are.same({ 20, 50, 100 }, second[1].hunts[1].tiers)
			assert.are.same({ 85, 10 }, second[1].zones)
		end)

		it(
			"prints the state, the header, the kinds and the check's frames for /pagle dev content (PUSH-R14)",
			function()
				local r = reader(fixtures.good).run()

				assert.are.same({
					"Pagle dev: pushed content is connected.",
					"Pagle dev: generatedAt 1791728100, keyId testKey, seq 42, expires 1792336500.",
					"Pagle dev: kinds handed out: huntEvent 1, huntRun 1.",
					"Pagle dev: kinds dropped as unknown: huntRun v2 1, notice v1 1.",
					"Pagle dev: frames the check ran in: 1, the longest 0.00 ms (budget 4 ms).",
				}, r.content:Report())
			end
		)

		it("accepts the seq last accepted again, and a higher one (PUSH-R13)", function()
			assert.are.equal(
				"connected",
				reader(fixtures.good, { global = { pushed = { seq = 42 } } }).run().content:State()
			)
			local r = reader(fixtures.good, { global = { pushed = { seq = 7 } } }).run()
			assert.are.equal("connected", r.content:State())
			assert.are.equal(42, r.global.pushed.seq)
		end)

		it("accepts a payload of exactly 64 KiB decoded, the cap (PUSH-R13)", function()
			assert.are.equal(ns.PUSHED_SIZE_CAP, #payloadOf(fixtures.big))
			local r = reader(fixtures.big).run()

			assert.are.equal("connected", r.content:State())
			assert.are.equal(700, #r.content:Items("huntRun"))
		end)
	end)

	describe("an absent file (PUSH-R13, PUSH-R14)", function()
		-- Each failure, the file that makes it, and the first line /pagle dev content prints for it.
		local good, bigBytes = fixtures.good, nil
		local BAD_KEY_ID = "a keyId that isn't 1 to 32 of A-Z, a-z, 0-9, _ and -"
		local KEY_32 = "AZaz09_-" .. ("k"):rep(24)
		local function cases()
			bigBytes = bigBytes or payloadOf(fixtures.big)
			local goodBytes = payloadOf(good)
			return {
				{ "a missing field", with(good, { sig = NONE }), "a missing field, sig" },
				{ "a missing first field", with(good, { v = NONE, sig = NONE }), "a missing field, v" },
				{ "a seq that isn't a whole number", with(good, { seq = 42.5 }), "seq isn't a whole number" },
				{ "a seq written as a string", with(good, { seq = "42" }), "seq isn't a whole number" },
				{ "a keyId that isn't a string", with(good, { keyId = 1 }), "keyId isn't a string" },
				-- PUSH-R2's form: a "|" would make the canonical header (PUSH-R11) read two ways.
				{ "a keyId with a |", with(good, { keyId = "test|Key" }), BAD_KEY_ID },
				{ "an empty keyId", with(good, { keyId = "" }), BAD_KEY_ID },
				{ "a keyId of 33 characters", with(good, { keyId = ("k"):rep(33) }), BAD_KEY_ID },
				{ "a keyId with a dot", with(good, { keyId = "test.Key" }), BAD_KEY_ID },
				{ "a keyId with a space", with(good, { keyId = "test Key" }), BAD_KEY_ID },
				{ "a keyId with a letter outside A-Z", with(good, { keyId = "testK\195\169y" }), BAD_KEY_ID },
				{ "a keyId of 32 characters, unknown", with(good, { keyId = KEY_32 }), "an unknown keyId, " .. KEY_32 },
				{ "an unknown v", with(good, { v = 2 }), "an unknown file format, v 2" },
				{ "an unknown keyId", with(good, { keyId = "otherKey" }), "an unknown keyId, otherKey" },
				{
					"a sig that isn't Base64",
					with(good, { sig = "abc" }),
					"sig isn't Base64 (a length that isn't a multiple of 4)",
				},
				{
					"a payload that isn't Base64",
					with(good, { payload = good.payload:sub(1, 8) .. "*" .. good.payload:sub(10) }),
					"payload isn't Base64 (a character outside the Base64 alphabet)",
				},
				{
					"over 64 KiB decoded",
					with(good, { payload = toBase64(bigBytes .. " ") }),
					"over the size cap, 65537 bytes decoded of 65536 at most",
				},
				{
					"a flipped payload byte",
					with(good, { payload = toBase64(flipped(goodBytes, 100)) }),
					"a bad signature (the signature doesn't match)",
				},
				{
					"a flipped last payload byte",
					with(good, { payload = toBase64(flipped(goodBytes, #goodBytes)) }),
					"a bad signature (the signature doesn't match)",
				},
				{ "a flipped seq", with(good, { seq = 43 }), "a bad signature (the signature doesn't match)" },
				{
					"a flipped generatedAt",
					with(good, { generatedAt = good.generatedAt + 1 }),
					"a bad signature (the signature doesn't match)",
				},
				{
					"a flipped expires",
					with(good, { expires = good.expires + 1 }),
					"a bad signature (the signature doesn't match)",
				},
				{
					"another file's signature",
					with(good, { sig = fixtures.big.sig }),
					"a bad signature (the signature doesn't match)",
				},
				{
					"a signature of the wrong length",
					with(good, { sig = toBase64(("\1"):rep(255)) }),
					"a bad signature (the signature isn't as long as the modulus)",
				},
				{
					"a payload with a function call",
					fixtures.functionCall,
					"a parse error at byte 35: a name, print, where a value goes",
				},
				{
					"a payload with a ' string",
					fixtures.singleQuote,
					"a parse error at byte 35: an unexpected character, '",
				},
			}
		end

		it("reads missing for each failure, hands out nothing, stores no seq and names the reason", function()
			for _, case in ipairs(cases()) do
				local r = reader(case[2]).run()

				assert.are.equal("missing", r.content:State(), case[1])
				assert.are.same({ "missing" }, r.fired, case[1])
				assert.are.same({}, r.content:Items("huntRun"), case[1])
				assert.are.same({}, r.content:Items("huntEvent"), case[1])
				assert.are.equal(nil, r.global.pushed.seq, case[1])
				assert.are.equal("Pagle dev: pushed content is missing: " .. case[3] .. ".", r.content:Report()[1])
			end
		end)

		it("reads missing for a replayed old file: a seq below the last accepted (PUSH-R92)", function()
			local r = reader(fixtures.good, { global = { pushed = { seq = 43 } } }).run()

			assert.are.equal("missing", r.content:State())
			assert.are.same({}, r.content:Items("huntRun"))
			assert.are.equal(43, r.global.pushed.seq)
			assert.are.equal(
				"Pagle dev: pushed content is missing: a lower seq, 42, below the last accepted 43.",
				r.content:Report()[1]
			)
		end)

		it("reads missing at expires and after, never before (PUSH-R13)", function()
			for _, now in ipairs({ fixtures.expires, fixtures.expires + DAY }) do
				local r = reader(fixtures.good, { now = now }).run()

				assert.are.equal("missing", r.content:State())
				assert.are.equal(
					("Pagle dev: pushed content is missing: expired at 1792336500, and the server time is %d."):format(
						now
					),
					r.content:Report()[1]
				)
			end
			assert.are.equal("notRunning", reader(fixtures.good, { now = fixtures.expires - 1 }).run().content:State())
		end)

		it("names only the first failure, in the check's order", function()
			local files = {
				{
					with(fixtures.good, { keyId = "a|b", v = 2 }),
					"a keyId that isn't 1 to 32 of A-Z, a-z, 0-9, _ and -",
				},
				{ with(fixtures.good, { v = 2, keyId = "otherKey", sig = "abc" }), "an unknown file format, v 2" },
				{ with(fixtures.good, { keyId = "otherKey", payload = "*" }), "an unknown keyId, otherKey" },
				{
					with(fixtures.good, { seq = 43, payload = "*" }),
					"payload isn't Base64 (a length that isn't a multiple of 4)",
				},
				{
					with(fixtures.functionCall, { seq = 43 }),
					"a bad signature (the signature doesn't match)",
				},
			}
			for _, case in ipairs(files) do
				assert.are.equal(
					"Pagle dev: pushed content is missing: " .. case[2] .. ".",
					reader(case[1], { now = fixtures.expires + 1 }).run().content:Report()[1]
				)
			end
			-- Both a lower seq and expired: the seq is checked first.
			local r = reader(fixtures.good, { now = fixtures.expires, global = { pushed = { seq = 50 } } }).run()
			assert.are.equal(
				"Pagle dev: pushed content is missing: a lower seq, 42, below the last accepted 50.",
				r.content:Report()[1]
			)
		end)

		it(
			"reads missing at once with no file, naming why there's none, after one read (PUSH-R13, PUSH-R90)",
			function()
				local presences = {
					{
						{ installed = false, loaded = false, reason = "MISSING" },
						"no file (Pagle_Content isn't installed)",
					},
					{
						{ installed = true, loaded = false, reason = "DISABLED" },
						"no file (Pagle_Content didn't load: DISABLED)",
					},
					{
						{ installed = true, loaded = true },
						"no file (Pagle_Content loaded but set no PagleContentData)",
					},
				}
				for _, case in ipairs(presences) do
					local r = reader(nil, { presence = case[1] })
					r.content:Start()

					assert.are.equal("missing", r.content:State())
					assert.are.same({ "missing" }, r.fired)
					assert.are.same({}, r.queue)
					assert.are.equal(1, r.reads)
					assert.are.same({ "Pagle dev: pushed content is missing: " .. case[2] .. "." }, r.content:Report())
				end
			end
		)

		it("reads missing when PagleContentData isn't a table", function()
			local r = reader("a string").run()

			assert.are.equal("missing", r.content:State())
			assert.are.same({
				"Pagle dev: pushed content is missing: PagleContentData isn't a table.",
				"Pagle dev: generatedAt none, keyId none, seq none, expires none.",
				"Pagle dev: frames the check ran in: 1, the longest 0.00 ms (budget 4 ms).",
			}, r.content:Report())
		end)

		it("reads missing, and reports the error, when the check itself fails (PUSH-R13)", function()
			local r = reader(fixtures.good, {
				globalFn = function()
					error("PagleDB is gone")
				end,
			}).run()

			assert.are.equal("missing", r.content:State())
			assert.are.same({ "missing" }, r.fired)
			assert.are.equal(1, #r.reports)
			assert.truthy(r.reports[1]:find("PagleDB is gone", 1, true))
			assert.are.equal(
				"Pagle dev: pushed content is missing: the check itself failed (see the Lua error).",
				r.content:Report()[1]
			)
		end)
	end)

	describe("the states", function()
		it(
			"reads notRunning 24 hours after generatedAt and later, and still hands out its items (PUSH-R15, PUSH-R22)",
			function()
				local generatedAt = fixtures.generatedAt
				for _, case in ipairs({
					{ generatedAt + DAY - 1, "connected" },
					{ generatedAt + DAY, "notRunning" },
					{ generatedAt + 25 * 3600, "notRunning" },
				}) do
					local r = reader(fixtures.good, { now = case[1] }).run()

					assert.are.equal(case[2], r.content:State())
					assert.are.same({ case[2] }, r.fired)
					assert.are.equal(1, #r.content:Items("huntRun"))
				end
			end
		)

		it(
			"reads checking, handing out nothing, until the check ends; then fires PushedContentReady once (PUSH-R10, PUSH-R16)",
			function()
				local r = reader(fixtures.good)
				assert.are.equal("checking", r.content:State())
				assert.are.same({}, r.content:Items("huntRun"))

				r.content:Start()
				assert.are.equal("checking", r.content:State())
				assert.are.same({}, r.content:Items("huntRun"))
				assert.are.same({}, r.fired)
				assert.are.same({
					"Pagle dev: pushed content is checking.",
					"Pagle dev: generatedAt 1791728100, keyId testKey, seq 42, expires 1792336500.",
				}, r.content:Report())

				r.frame()
				assert.are.equal("connected", r.content:State())
				assert.are.same({ "connected" }, r.fired)

				r.content:Start()
				r.content:Finish({ state = "missing" })
				r.frame()
				assert.are.equal("connected", r.content:State())
				assert.are.same({ "connected" }, r.fired)
				assert.are.equal(1, r.reads)
			end
		)

		it("is ended by Finish as a check ends it, keeping only the kinds and versions passed on (PUSH-R21)", function()
			local r = reader(nil)
			r.content:Finish({
				state = "notRunning",
				items = { { kind = "huntRun", v = 1, event = "e" }, { kind = "huntRun", v = 3 }, { kind = "x", v = 1 } },
			})

			assert.are.equal("notRunning", r.content:State())
			assert.are.same({ "notRunning" }, r.fired)
			assert.are.same({ { kind = "huntRun", v = 1, event = "e" } }, r.content:Items("huntRun"))
			assert.has_error(function()
				r.content:Finish({ state = "checking" })
			end)
		end)
	end)

	describe("over frames (PUSH-R10, PUSH-R93)", function()
		-- A clock that moves `step` ms each time it's read: each piece of work costs the reads it takes.
		local function ticking(step)
			local now = 0
			return function()
				now = now + step
				return now
			end, function()
				return now
			end
		end

		it("spreads a 64 KiB check over frames, none over the budget, when every step costs the same", function()
			local clock, peek = ticking(0.25)
			local r = reader(fixtures.big, { clock = clock })
			r.content:Start()
			local longest, frames = 0, 0
			while #r.queue > 0 do
				local started = peek()
				r.frame()
				frames = frames + 1
				longest = math.max(longest, peek() - started)
			end

			assert.are.equal("connected", r.content:State())
			assert.are.equal(true, frames > 10, tostring(frames))
			assert.are.equal(true, longest <= ns.PUSHED_CHECK_BUDGET, tostring(longest))
		end)

		it(
			"checks again at the next login when a login ends mid-check, storing nothing meanwhile (PUSH-R93)",
			function()
				local clock = ticking(0.25)
				local global = { pushed = { seq = 7 } }
				local first = reader(fixtures.big, { clock = clock, global = global })
				first.content:Start()
				for _ = 1, 3 do
					first.frame()
				end
				assert.are.equal("checking", first.content:State())
				assert.are.equal(7, global.pushed.seq)

				local next = reader(fixtures.big, { clock = clock, global = global }).run()
				assert.are.equal("connected", next.content:State())
				assert.are.equal(42, global.pushed.seq)
			end
		)

		it("never runs over the budget on a 64 KiB payload with the real clock #slow", function()
			-- The best of three runs: the gate's other shards share the machine, and a frame they slow isn't the pacer's.
			local best
			for _ = 1, 3 do
				local r = reader(fixtures.big, {
					clock = function()
						---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os
						return os.clock() * 1000
					end,
				})
				r.content:Start()
				local longest = 0
				while #r.queue > 0 do
					---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os
					local started = os.clock()
					r.frame()
					---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os
					longest = math.max(longest, (os.clock() - started) * 1000)
				end
				assert.are.equal("connected", r.content:State())
				best = math.min(best or math.huge, longest)
				if best <= ns.PUSHED_CHECK_BUDGET then
					break
				end
			end

			assert.are.equal(true, best <= ns.PUSHED_CHECK_BUDGET, ("the longest frame took %.2f ms"):format(best))
		end)
	end)
end)
