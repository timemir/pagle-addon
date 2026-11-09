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

	it("names its CurseForge and Wago projects, so the tag's release uploads to both (CORE-R74)", function()
		local fields = assert(loaded.client.addons.Pagle.metadata)

		assert.are.equal("1742678", fields["X-Curse-Project-ID"])
		assert.are.equal("qGZA7bKd", fields["X-Wago-ID"])
	end)

	it(
		"sign_toc: loads the news sign's files from TOC lines of their own, once each, after Settings (news-sign.md Contracts)",
		function()
			local at, count = {}, {}
			for index, file in ipairs(addonFiles("Pagle")) do
				at[file] = at[file] or index
				count[file] = (count[file] or 0) + 1
			end
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
			local tocFile = assert(io.open("addons/Pagle/Pagle.toc", "r"))
			local toc = tocFile:read("*a")
			tocFile:close()
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
			local xmlFile = assert(io.open("addons/Pagle/adapter/Settings.xml", "r"))
			local xml = xmlFile:read("*a")
			xmlFile:close()

			local files = {
				"data/NewsSignArt.lua",
				"adapter/NewsSign.lua",
				"adapter/NewsSignLooks.lua",
				"adapter/NewsSignDev.lua",
				"adapter/NewsSignDrop.lua",
			}
			for i, file in ipairs(files) do
				assert.are.equal(1, count[file], file)
				assert(toc:find((file:gsub("/", "\\")), 1, true), file .. " has a TOC line")
				assert(not xml:find(file:match("[^/]+$"), 1, true), file .. " left Settings.xml")
				if i > 1 then
					assert(at[file] > at[files[i - 1]], file)
				end
			end
			-- after the files they use: the art, the motion driver, the fonts, Settings, the letters and the pick
			for _, used in ipairs({
				"data/LegendCrestArt.lua",
				"data/VarietyArt.lua",
				"data/NewsSignArt.lua",
				"logic/NewsSign.lua",
				"adapter/Restriction.lua",
				"adapter/Fonts.lua",
				"adapter/Settings.lua",
				"adapter/Motion.lua",
				"adapter/Slash.lua",
				"adapter/Letter.lua",
			}) do
				assert(at[used] < at["adapter/NewsSign.lua"], used)
			end
		end
	)

	it(
		"party_toc: loads the party files and the news sign's Settings section from TOC lines of their own, once each, in"
			.. " their order, between Settings and the party catches and Announcements (ANN-R103, SET-R37)",
		function()
			local at, count = {}, {}
			for index, file in ipairs(addonFiles("Pagle")) do
				at[file] = at[file] or index
				count[file] = (count[file] or 0) + 1
			end
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
			local tocFile = assert(io.open("addons/Pagle/Pagle.toc", "r"))
			local toc = tocFile:read("*a")
			tocFile:close()
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
			local xmlFile = assert(io.open("addons/Pagle/adapter/Settings.xml", "r"))
			local xml = xmlFile:read("*a")
			xmlFile:close()
			assert(not xml:find("<Script", 1, true), "Settings.xml loads no file, only its templates")

			local files = {
				"adapter/PartyMessages.lua",
				"adapter/Party.lua",
				"adapter/PartyToast.lua",
				"adapter/PartySettings.lua",
				"adapter/PartyLetter.lua",
				"adapter/PartyHunts.lua",
				"adapter/NewsSignSettings.lua",
			}
			for i, file in ipairs(files) do
				assert.are.equal(1, count[file], file)
				assert(toc:find((file:gsub("/", "\\")), 1, true), file .. " has a TOC line")
				assert(at[file] > (i > 1 and at[files[i - 1]] or at["adapter/Settings.lua"]), file)
			end
			for _, later in ipairs({
				"adapter/PartyCatches.lua",
				"adapter/Letter.lua",
				"adapter/AnnouncementSettings.lua",
			}) do
				assert(at[later] > at["adapter/NewsSignSettings.lua"], later)
			end
		end
	)

	-- Every page builds its rows when the tree is registered, after every file has loaded, so this order is for reading:
	-- the creators sit with the templates they draw on, ahead of the sections that call them.
	it(
		"loads SettingsControls.lua from a TOC line of its own right after Settings.xml, its templates, and before the"
			.. " Party, Morning Tide, Announcements and Look and Feel builders (SET-R7)",
		function()
			local at, count = {}, {}
			for index, file in ipairs(addonFiles("Pagle")) do
				at[file] = at[file] or index
				count[file] = (count[file] or 0) + 1
			end

			assert.are.equal(1, count["adapter/SettingsControls.lua"])
			assert.are.equal(at["adapter/Settings.xml"] + 1, at["adapter/SettingsControls.lua"])
			for _, builder in ipairs({
				"adapter/PartySettings.lua",
				"adapter/NewsSignSettings.lua",
				"adapter/AnnouncementSettings.lua",
				"adapter/LookAndFeel.lua",
			}) do
				assert(at[builder] > at["adapter/SettingsControls.lua"], builder)
			end
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
