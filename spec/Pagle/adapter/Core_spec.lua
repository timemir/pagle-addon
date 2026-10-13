describe("Core loaded through Pagle.toc", function()
	describe("on Forever", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)

		it("creates the Pagle global at API version 1 before 1.0 (CORE-R15)", function()
			assert.are.equal(1, loaded.env.Pagle.API_VERSION)
		end)

		it("prints nothing to chat (CORE-R4)", function()
			assert.are.same({}, loaded.printed)
		end)
	end)

	describe("off Forever", function()
		local offForever = {
			["a client with another project ID"] = {
				WOW_PROJECT_ID = PROJECT_IDS.MAINLINE,
				WOW_PROJECT_CAMELOT = PROJECT_IDS.CAMELOT,
			},
			["a client without WOW_PROJECT_CAMELOT"] = { WOW_PROJECT_ID = PROJECT_IDS.MAINLINE },
		}
		for client, globals in pairs(offForever) do
			describe("on " .. client, function()
				local loaded = loadAddon("Pagle", globals)

				it("never creates the Pagle global (CORE-R4)", function()
					assert.is_nil(loaded.env.Pagle)
				end)

				it("prints one chat line, from the string table, saying Pagle stays off (CORE-R4, CORE-R8)", function()
					assert.is_string(loaded.ns.L.NOT_FOREVER)
					assert.are.same({ loaded.ns.L.NOT_FOREVER }, loaded.printed)
				end)
			end)
		end
	end)
end)
