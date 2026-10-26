describe("Pagle.toc", function()
	local loaded = loadAddon("Pagle", FOREVER_GLOBALS)

	for _, lib in ipairs({ "CallbackHandler-1.0", "AceAddon-3.0", "AceEvent-3.0", "AceDB-3.0" }) do
		it("embeds " .. lib .. ", reachable through LibStub (CORE-R6)", function()
			assert.is_table(loaded.env.LibStub:GetLibrary(lib, true))
		end)
	end

	it("embeds LibDeflate 1.0.2, reachable through LibStub, for the Paste string (CORE-R6, PST-R30)", function()
		local LibDeflate, minor = loaded.env.LibStub:GetLibrary("LibDeflate", true)

		assert.is_table(LibDeflate)
		assert.are.equal(3, minor, "LibStub's minor for 1.0.2")
		assert.are.equal("1.0.2-release", LibDeflate._VERSION)
	end)

	it(
		"lists PagleLog, PagleDB and the Recovery archive as account-wide SavedVariables, and nothing per character (CORE-R5)",
		function()
			local fields = assert(loaded.client.addons.Pagle.metadata)

			assert.are.equal("PagleLog, PagleDB, PagleRecovery", fields.SavedVariables)
			assert.is_nil(fields.SavedVariablesPerCharacter)
		end
	)

	it("lists its generated Lore.lua right after locale/enUS.lua, the file that creates ns.L (DATA-R75)", function()
		local at = {}
		for index, file in ipairs(addonFiles("Pagle")) do
			at[file] = index
		end

		assert.is_number(at["data/Lore.lua"])
		assert.are.equal(at["locale/enUS.lua"] + 1, at["data/Lore.lua"])
	end)
end)
