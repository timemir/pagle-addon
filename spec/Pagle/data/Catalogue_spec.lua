describe("the generated catalogue", function()
	local loaded = loadAddon("Pagle", FOREVER_GLOBALS)

	it("is ns.catalogue once Core loads through its TOC (DATA-R75, DATA-R76)", function()
		assert.is_table(loaded.ns.catalogue)
	end)

	it("carries a 16-hex fingerprint (DATA-R70)", function()
		assert.is_truthy(tostring(loaded.ns.catalogue.fingerprint):match("^" .. ("%x"):rep(16) .. "$"))
	end)
end)
