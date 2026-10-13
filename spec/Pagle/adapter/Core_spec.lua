-- Project IDs as the clients define them: Forever's is WOW_PROJECT_CAMELOT (BIR forever README, scripts/tools.env).
local CAMELOT = 18
local MAINLINE = 1

describe("Core loaded through Pagle.toc", function()
	describe("on Forever", function()
		local loaded = loadAddon("Pagle", { WOW_PROJECT_ID = CAMELOT, WOW_PROJECT_CAMELOT = CAMELOT })

		it("creates the Pagle global at API version 1 before 1.0 (CORE-R15)", function()
			assert.are.equal(1, loaded.env.Pagle.API_VERSION)
		end)

		it("prints nothing to chat (CORE-R4)", function()
			assert.are.same({}, loaded.printed)
		end)
	end)

	describe("off Forever", function()
		local offForever = {
			["a client with another project ID"] = { WOW_PROJECT_ID = MAINLINE, WOW_PROJECT_CAMELOT = CAMELOT },
			["a client without WOW_PROJECT_CAMELOT"] = { WOW_PROJECT_ID = MAINLINE },
		}
		for client, globals in pairs(offForever) do
			describe("on " .. client, function()
				local loaded = loadAddon("Pagle", globals)

				it("never creates the Pagle global (CORE-R4)", function()
					assert.is_nil(loaded.env.Pagle)
				end)

				it("prints one chat line saying Pagle stays off (CORE-R4)", function()
					assert.are.same(
						{ "Pagle: this isn't World of Warcraft: Forever, so Pagle stays off." },
						loaded.printed
					)
				end)
			end)
		end
	end)
end)
