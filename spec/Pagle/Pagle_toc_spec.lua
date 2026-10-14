describe("Pagle.toc", function()
	local loaded = loadAddon("Pagle", FOREVER_GLOBALS)

	for _, lib in ipairs({ "CallbackHandler-1.0", "AceAddon-3.0", "AceEvent-3.0", "AceDB-3.0" }) do
		it("embeds " .. lib .. ", reachable through LibStub (CORE-R6)", function()
			assert.is_table(loaded.env.LibStub:GetLibrary(lib, true))
		end)
	end

	it("lists PagleLog and PagleDB as account-wide SavedVariables, and nothing per character (CORE-R5)", function()
		local fields = assert(loaded.client.addons.Pagle.metadata)

		assert.are.equal("PagleLog, PagleDB", fields.SavedVariables)
		assert.is_nil(fields.SavedVariablesPerCharacter)
	end)

	it("lists its generated Lore.lua right after locale/enUS.lua, the file that creates ns.L (DATA-R75)", function()
		local at = {}
		for index, file in ipairs(addonFiles("Pagle")) do
			at[file] = index
		end

		assert.is_number(at["data/Lore.lua"])
		assert.are.equal(at["locale/enUS.lua"] + 1, at["data/Lore.lua"])
	end)
end)
