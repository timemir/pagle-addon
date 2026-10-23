-- The Ledger's crest record on FakePagle (LED-R156, #76 item 19): the crest the bookplate pins (LED-R112), logged as
-- a `crest` Module record whenever it isn't the one the log's latest crest record names, the frame after it changes
-- or after the projection's done, so Pagle's backend can show the equipped crest. Plain is logged as an empty payload,
-- and never while the log names no crest.

local MACKEREL = 6303
local ELWYNN = 12
local T0 = SERVER_TIME - 700
local CREST = "ledger.crest.elwynn"

-- Elwynn lists Mackerel alone.
local function catalogue()
	return catalogueWith({
		items = { [MACKEREL] = fishRecord(MACKEREL) },
		areas = { [ELWYNN] = areaRecord(0, { skillBase = 1, catches = { catchEntry(MACKEREL) } }) },
	})
end

-- A Ledger crest record at `time`, as the Catch log holds one.
local function crestRecord(payload, time)
	return { kind = "module", char = 1, time = time, module = "Ledger", recordKind = "crest", payload = payload }
end

-- A Ledger on a fake over the catalogue and `log` (a Mackerel Catch first), with `equipped` the saved crest pick,
-- logged in and, unless `updating`, in the world (its projection built).
---@param log table[]?
---@param options { equipped: string?, updating: boolean? }?
---@return FakePagle fake
---@return LoadedAddon loaded
local function loggedIn(log, options)
	options = options or {}
	local fake = newFakePagle()
	fake.setCatalogue(catalogue())
	fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
	fake.catchLog:Append(castRecord({ time = T0, zone = ELWYNN, items = { MACKEREL } }))
	for _, record in ipairs(log or {}) do
		fake.catchLog:Append(record)
	end
	if options.equipped then
		fake.setPurchased({ [options.equipped] = true }) -- owned: a purchased ID is (SHOP-R30)
		fake.profile.appearance = fake.profile.appearance or {}
		fake.profile.appearance["core.crest"] = options.equipped
	end
	local loaded = fake.load("Pagle_Ledger")
	fake.login()
	if not options.updating then
		fake.enterWorld()
	end
	return fake, loaded
end

-- The payloads of the Ledger's crest records in the log, in log order.
---@param fake FakePagle
---@return string[]
local function crestRecords(fake)
	local payloads = {}
	for record in fake.catchLog:Iterate(0, "Ledger") do
		local module = record --[[@as PagleModuleRecord]]
		if record.kind == "module" and module.recordKind == "crest" then
			payloads[#payloads + 1] = module.payload
		end
	end
	return payloads
end

describe("the Ledger's crest record (LED-R156, #76 item 19)", function()
	it("logs nothing while Plain is equipped and the log names no crest", function()
		local fake, loaded = loggedIn()
		loaded.client.runTimers()

		assert.are.same({}, crestRecords(fake))
	end)

	it("logs a crest the Player equips, the frame after, and Plain again as an empty payload", function()
		local fake, loaded = loggedIn()
		loaded.client.runTimers()
		fake.setPurchased({ [CREST] = true })

		assert.is_true(fake.Pagle.SetEquipped("core.crest", CREST))
		assert.are.same({}, crestRecords(fake))
		loaded.client.runTimers()
		assert.are.same({ CREST }, crestRecords(fake))

		assert.is_true(fake.Pagle.SetEquipped("core.crest", "core.crest.plain"))
		loaded.client.runTimers()
		assert.are.same({ CREST, "" }, crestRecords(fake))
	end)

	it("folds what it logs, so the Ledger's state names the equipped crest", function()
		local fake, loaded = loggedIn()
		loaded.client.runTimers()
		fake.setPurchased({ [CREST] = true })
		fake.Pagle.SetEquipped("core.crest", CREST)
		loaded.client.runTimers()

		assert.are.equal(CREST, loaded.ns.StateNow().crest.good)
	end)

	it("logs the crest equipped at login once, when the log doesn't name it yet", function()
		local fake, loaded = loggedIn(nil, { equipped = CREST })
		loaded.client.runTimers()
		loaded.client.runTimers()

		assert.are.same({ CREST }, crestRecords(fake))
	end)

	it("logs nothing at login when the latest crest record already names the equipped crest", function()
		local fake, loaded = loggedIn({ crestRecord("", T0 + 10), crestRecord(CREST, T0 + 20) }, { equipped = CREST })
		loaded.client.runTimers()

		assert.are.same({ "", CREST }, crestRecords(fake))
	end)

	it("waits for the projection's done while it is updating, then logs", function()
		local fake, loaded = loggedIn(nil, { equipped = CREST, updating = true })
		loaded.client.runTimers()
		assert.are.same({}, crestRecords(fake))

		fake.enterWorld()
		loaded.client.runTimers()
		assert.are.same({ CREST }, crestRecords(fake))
	end)
end)
