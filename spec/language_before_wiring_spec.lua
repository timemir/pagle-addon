-- CORE-R8: nothing of Core reads a string of `ns.L` before Core applies the Language in its ADDON_LOADED. A string read
-- while Core's files load is copied in English and stays English all session, in every Language: the Field guide's
-- ribbons and Welcome links, the Curio Shop's First look. top_level_l_spec.lua finds such a read in a file's main chunk;
-- this one finds it anywhere, a function a file calls as it loads included (ns.WireGuide's ns.CoreGuideSteps, say),
-- by loading the package with Core's `ns.L` behind a table that records each read until ADDON_LOADED.

-- The roster Modules' folders, in CORE-R1 order.
local ROSTER = { "Pagle_Ledger", "Pagle_Hunts", "Pagle_Stats", "Pagle_TackleBoard", "Pagle_QoL" }

-- Core's locale/enUS.lua, then its `ns.L` behind a recording table: reads are recorded while `env.__langReads` is a
-- table, writes go to the strings themselves.
local RECORDING = "spec/fixtures/language_before_wiring_enUS.lua"

describe("Core's strings before the Language is applied (CORE-R8)", function()
	it("are not read while Core's files load, with every Module installed", function()
		local reads = {}
		local loaded =
			loadAddon("Pagle", foreverWith({ __langReads = reads, PagleDB = { global = { language = "esES" } } }), {
				replace = { ["locale/enUS.lua"] = RECORDING },
				beforeLoaded = {
					Pagle = function(_, _, env)
						env.__langReads = nil
					end,
				},
				also = ROSTER,
			})
		assert.are.equal("esES", loaded.namespaces.Pagle.language)
		-- Dev text stays English in any Language (ADR 0019), so a DEV_ key read early does no harm.
		local early = {}
		for _, key in ipairs(reads) do
			if not key:find("^DEV_") then
				early[#early + 1] = key
			end
		end
		assert.are.same({}, early)
	end)

	it("reach the Field guide's and the Curio Shop's First look in the Language", function()
		local loaded = enterWorld(
			loadAddon("Pagle", foreverWith({ PagleDB = { global = { language = "esES" } } }), { also = ROSTER }),
			3
		)
		local ns = loaded.namespaces.Pagle
		local L = ns.L
		local ribbons = {}
		for _, entry in ipairs(ns.guideSteps:List()) do
			ribbons[entry.step.id] = entry.step.ribbon
		end
		assert.are.equal(L.GUIDE_RIBBON_WELCOME, ribbons.welcome)
		assert.are_not.equal("Welcome", ribbons.welcome)
		assert.are.equal(L.GUIDE_RIBBON_OFF, ribbons.off)
		local shop = ns.ShopFirstLook()
		assert.are_not.equal("the Curio Shop", shop.title)
	end)
end)
