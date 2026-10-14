-- Prestige and purchase entries on the client (LOG-R38, LOG-R39, LOG-R42, LOG-R73, SHOP-R10): M:RecordPrestige on a
-- Module handle and Core's own ns.RecordPurchase, through the real TOC over a saved log.

-- A minute after login: what the client appended at login (a Skill Reading) is a second behind, so it shares no tie.
local NOW = SERVER_TIME + 60

-- Core over a saved log holding `entries`, logged in and in the world, with the Ledger registered, at NOW. Its
-- projection notes each apply ("<seq> <kind> <mode>") and each Prestige event ("Prestige <rank>") in `seen`, in order.
---@param entries table
local function coreWithLedger(entries)
	local loaded = loadCore(entries)
	local Pagle = loaded.env.Pagle
	local seen = {}
	local M = Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
	M:NewProjection({
		db = {},
		rulesVersion = 1,
		reset = function()
			return {}
		end,
		apply = function(_, record, mode)
			seen[#seen + 1] = record.seq .. " " .. record.kind .. " " .. mode
		end,
	})
	Pagle.RegisterCallback("Spec", "Prestige", function(_, record)
		seen[#seen + 1] = "Prestige " .. record.rank
	end)
	enterWorld(loaded)
	loaded.client.advance(NOW - SERVER_TIME)
	return loaded, M, seen
end

-- The log's entries after the first `n`.
local function entriesAfter(loaded, n)
	return { unpack(loaded.env.PagleLog.entries, n + 1) }
end

describe("M:RecordPrestige", function()
	it(
		"appends rank 1, then rank 2, for the current character, each applied live before Prestige fires"
			.. " (LOG-R38, LOG-R73)",
		function()
			local loaded, M, seen = coreWithLedger(history(2))
			local before = #loaded.env.PagleLog.entries
			local count = #seen

			local first = M:RecordPrestige()
			local second = M:RecordPrestige()

			local now = NOW
			assert.are.same({
				("P1|2|%d|0|1"):format(now),
				("P1|2|%d|1|2"):format(now),
			}, entriesAfter(loaded, before))
			assert.are.same({
				("%d prestige live"):format(before + 1),
				"Prestige 1",
				("%d prestige live"):format(before + 2),
				"Prestige 2",
			}, { unpack(seen, count + 1) })
			assert.are.same({ "prestige", 1, 2, PLAYER_GUID .. "-" .. now .. "-0" }, {
				first.kind,
				first.rank,
				first.char,
				first.id,
			})
			assert.are.equal(2, second.rank)
		end
	)

	it(
		"counts the Prestiges already in the log, from any character, but not an undecodable one (LOG-R38, LOG-R16)",
		function()
			local entries = history(1)
			entries[#entries + 1] = prestigeEntry(SERVER_TIME - 3000, 1)
			entries[#entries + 1] = "P1|1|1791700000|0|two" -- undecodable: readers skip it, so it is no Prestige
			entries[#entries + 1] = prestigeEntry(SERVER_TIME - 2000, 2)
			local _, M = coreWithLedger(entries) -- the logged-in character is the client's, not Ada

			assert.are.equal(3, M:RecordPrestige().rank)
			assert.are.equal(4, M:RecordPrestige().rank)
		end
	)

	it("is a Module handle method (LOG-R38, CORE-R12)", function()
		local _, M = coreWithLedger(history(1))

		local ok, err = pcall(M.RecordPrestige)

		assert.is_false(ok)
		assert.matches("RecordPrestige is a Module handle method: call M:RecordPrestige()", err, 1, true)
	end)

	it("raises an error, appending nothing, from a replay or rebuild apply (LOG-R38, LOG-R75)", function()
		local M
		local raised = {}
		local loaded = loadCore(history(1))
		local Pagle = loaded.env.Pagle
		M = Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
		M:NewProjection({
			db = {},
			rulesVersion = 1,
			reset = function()
				return {}
			end,
			apply = function(_, record, mode)
				if record.kind == "cast" then
					raised[#raised + 1] = mode .. " " .. tostring(not pcall(M.RecordPrestige, M))
				end
			end,
		})
		local logged = #loaded.env.PagleLog.entries

		enterWorld(loaded)

		assert.are.same({ "rebuild true" }, raised)
		for _, entry in ipairs(entriesAfter(loaded, logged)) do
			assert.is_nil(entry:match("^P1"))
		end
	end)
end)

describe("a purchase entry", function()
	it("is appended by ns.RecordPurchase for the current character and applied live (LOG-R39, SHOP-R10)", function()
		local loaded, _, seen = coreWithLedger(history(1))
		local before = #loaded.env.PagleLog.entries
		local count = #seen

		local record = loaded.ns.RecordPurchase("core.toaststyle.ripple", 150)

		assert.are.same({ ("U1|2|%d|0|core.toaststyle.ripple|150"):format(NOW) }, entriesAfter(loaded, before))
		assert.are.same({ ("%d purchase live"):format(before + 1) }, { unpack(seen, count + 1) })
		assert.are.same({ "purchase", "core.toaststyle.ripple", 150 }, { record.kind, record.good, record.price })
	end)

	it(
		"raises an error and appends nothing for a good ID outside [%w_.]+ or a price that isn't whole (LOG-R39)",
		function()
			local loaded = coreWithLedger(history(1))
			local before = #loaded.env.PagleLog.entries

			for _, bad in ipairs({
				{ "core.toast style", 150 },
				{ "core.crest.otter", -1 },
				{ "core.crest.otter", 2.5 },
			}) do
				assert.has_error(function()
					loaded.ns.RecordPurchase(bad[1], bad[2])
				end)
			end
			assert.are.equal(before, #loaded.env.PagleLog.entries)
		end
	)

	it("is appended by nothing on Pagle or a Module handle (LOG-R39)", function()
		local loaded = coreWithLedger(history(1))
		local found = {}
		for _, place in ipairs({ { "Pagle", loaded.env.Pagle }, { "M", loaded.ns.ModuleHandle } }) do
			for key in pairs(place[2]) do
				if tostring(key):lower():find("purchase") or tostring(key):lower():find("buy") then
					found[#found + 1] = place[1] .. "." .. tostring(key)
				end
			end
		end

		assert.are.same({}, found)
	end)
end)

describe("a dev log written before Prestige and purchase entries", function()
	it("still loads with the same logId and entries, and silently (LOG-R14, LOG-R15, LOG-R18)", function()
		local saved = savedLog({
			"B1|1|1791731680|0|70338|1.60.1",
			"S1|1|1791731681|0|86|150|0",
			"C1|1|1791731747|0|c|494|1439|1|148|453|86|25|263|||6358x1",
		})
		local loaded, M = coreWithLedger(saved)
		M:RecordPrestige()

		local log = loaded.env.PagleLog
		assert.are.equal("3f9a2c1e7b0d4a65", log.logId)
		assert.are.equal("C1|1|1791731747|0|c|494|1439|1|148|453|86|25|263|||6358x1", log.entries[3])
		assert.are.equal("P1", log.entries[#log.entries]:sub(1, 2))
		assert.are.same({}, loaded.printed)
	end)
end)
