describe("Pagle.toc", function()
	local loaded = loadAddon("Pagle", FOREVER_GLOBALS)

	for _, lib in ipairs({ "CallbackHandler-1.0", "AceAddon-3.0", "AceEvent-3.0", "AceDB-3.0" }) do
		it("embeds " .. lib .. ", reachable through LibStub (CORE-R6)", function()
			assert.is_table(loaded.env.LibStub:GetLibrary(lib, true))
		end)
	end

	it("lists PagleLog and PagleDB as account-wide SavedVariables, and nothing per character (CORE-R5)", function()
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
		local toc = assert(io.open("addons/Pagle/Pagle.toc", "r"))
		local tags = {}
		for line in toc:lines() do
			local tag, value = line:gsub("\r$", ""):match("^## ([%w-]+):%s*(.-)%s*$")
			if tag then
				tags[tag] = value
			end
		end
		toc:close()

		assert.are.equal("PagleLog, PagleDB", tags.SavedVariables)
		assert.is_nil(tags.SavedVariablesPerCharacter)
	end)
end)
