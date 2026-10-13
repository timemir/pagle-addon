describe("ns.StripSecrets", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns
	-- Stands in for a value the client marks secret.
	local secret = {}
	local function isSecret(value)
		return value == secret
	end
	local function pack(...)
		return { n = select("#", ...), ... }
	end

	it("replaces each secret value with nil and keeps the count (CORE-R31)", function()
		local stripped = pack(ns.StripSecrets(isSecret, secret, "a", nil, secret))

		assert.are.same({ n = 4, nil, "a" }, stripped)
	end)

	it("replaces secret values in a table and the tables it holds, in place (CORE-R31)", function()
		local snapshot = { zone = secret, weather = { id = secret, intensity = 0.5 }, seq = 7 }

		local returned = ns.StripSecrets(isSecret, snapshot)

		assert.are.equal(snapshot, returned)
		assert.are.same({ weather = { intensity = 0.5 }, seq = 7 }, snapshot)
	end)

	it("strips a table that holds itself without looping (CORE-R31)", function()
		local record = { item = secret }
		record.self = record

		ns.StripSecrets(isSecret, record)

		assert.is_nil(record.item)
		assert.are.equal(record, record.self)
	end)

	it("leaves a payload with no secrets as it was (CORE-R31)", function()
		local record = { item = 6358, outcome = "c" }

		assert.are.same({ 1, record, false }, { ns.StripSecrets(isSecret, 1, record, false) })
		assert.are.same({ item = 6358, outcome = "c" }, record)
	end)
end)
