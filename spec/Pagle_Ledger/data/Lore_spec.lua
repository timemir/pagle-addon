-- The Ledger's generated lore (DATA-R104): addons/Pagle_Ledger/data/Lore.lua adds each key's text to ns.L. The
-- fixture is the generator's output for scripts/tests/test_lore.py's BLANK_RIDDLE ledger.toml (a pytest checks they agree),
-- loaded in the committed file's TOC place.

local FIXTURE = "spec/Pagle_Ledger/fixtures/Lore.lua"

describe("the Ledger's Lore.lua", function()
	it("adds each key's text to ns.L once Pagle_Ledger loads through its TOC (DATA-R104, LED-R160)", function()
		local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS, { replace = { ["data/Lore.lua"] = FIXTURE } })

		assert.are.equal("Bites where the water runs lazy.", loaded.ns.L["species.13759.riddle"])
		assert.are.equal("Master of {zone}", loaded.ns.L["title.zonemaster.text"])
		assert.are.equal('Somebody\'s boot. "Size 9".', loaded.ns.L["sub.4000.plaque"])
	end)

	it("keeps the hand-written interface strings beside the lore (CORE-R8)", function()
		local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS, { replace = { ["data/Lore.lua"] = FIXTURE } })

		assert.are.equal("Ledger", loaded.ns.L.TITLE)
	end)

	it("leaves a key with no text out, so its line shows nothing (LED-R161)", function()
		-- The fixture's source gives Species 6303 a blurb and a whitespace-only riddle (test_lore.py's BLANK_RIDDLE).
		local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS, { replace = { ["data/Lore.lua"] = FIXTURE } })

		assert.are.equal("Slick, quick and gone from the shoals.", loaded.ns.L["species.6303.blurb"])
		assert.is_nil(loaded.ns.L["species.6303.riddle"])
	end)

	it("loads as committed, in the TOC after locale\\enUS.lua (DATA-R75)", function()
		local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)

		assert.are.equal("Ledger", loaded.ns.L.TITLE)
	end)
end)

describe("the Ledger's committed lore (DATA-R111, its M3 batch)", function()
	-- The text each key needs, from the committed catalogue and Lore.lua as Pagle_Ledger loads them (DATA-R103,
	-- LED-R160): a key missing here would leave its Journal line out (LED-R161).
	local L, items

	setup(function()
		local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)
		L, items = loaded.ns.L, loaded.namespaces.Pagle.catalogue.items
	end)

	---@param key string
	local function hasText(key)
		local text = L[key]
		assert(type(text) == "string" and text:find("%S"), key .. " has no text")
	end

	it("has a blurb and a riddle for every Species in the catalogue, Legends aside (DATA-R103, LED-R160)", function()
		local species = 0
		for itemID, item in pairs(items) do
			if item.species == itemID and not item.legend then
				species = species + 1
				hasText(("species.%d.blurb"):format(itemID))
				hasText(("species.%d.riddle"):format(itemID))
			end
		end
		assert.is_true(species > 30)
	end)

	it("has a blurb and a title for every Legend (DATA-R103, LED-R160)", function()
		local legends = {}
		for itemID, item in pairs(items) do
			if item.legend then
				legends[#legends + 1] = itemID
				hasText(("legend.%d.blurb"):format(itemID))
				hasText(("legend.%d.title"):format(itemID))
			end
		end
		table.sort(legends)
		assert.are.same({ 19803, 19805, 19806 }, legends)
	end)

	it("never gives a Legend the title Master Angler (LED-R75)", function()
		for _, itemID in ipairs({ 19803, 19805, 19806 }) do
			assert.are_not.equal("Master Angler", L[("legend.%d.title"):format(itemID)])
		end
	end)

	it("has a plaque for every curio item and a name for every trophy family (LED-R160)", function()
		for itemID, item in pairs(items) do
			if item.category == "junk" or item.category == "container" or item.category == "treasure" then
				hasText(("sub.%d.plaque"):format(itemID))
			elseif item.category == "trophy" then
				hasText(("family.%d.name"):format(item.family))
			end
		end
	end)

	it("has the four shared lines (LED-R138, LED-R144, LED-R147, LED-R162)", function()
		for _, id in ipairs({ "uncaughtlegend", "uncaughtjunk", "uncaughttreasure", "unchartedwaters" }) do
			hasText(("line.%s.text"):format(id))
		end
	end)
end)

describe("the Ledger's committed lore (DATA-R111, its M4 batch)", function()
	-- LED-R75's title IDs and LED-R110's bindings, without their ledger.binding. prefix (LED-R160).
	local TITLES = {
		"level1",
		"level10",
		"level20",
		"level30",
		"level40",
		"level50",
		"level60",
		"prestige1",
		"prestige5",
		"prestige10",
		"zonemaster",
		"complete.ledger",
		"complete.junk",
		"complete.treasure",
		"complete.trophy",
	}
	local BINDINGS =
		{ "field", "level10", "level20", "level30", "level40", "level50", "level60", "birch", "buckram", "sharkskin" }
	local L

	setup(function()
		L = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns.L
	end)

	---@param key string
	local function hasText(key)
		local text = L[key]
		assert(type(text) == "string" and text:find("%S"), key .. " has no text")
	end

	it("has a text for each of the 15 titles, none of them Master Angler (LED-R75, LED-R160)", function()
		for _, title in ipairs(TITLES) do
			local key = ("title.%s.text"):format(title)
			hasText(key)
			assert(not L[key]:lower():find("master angler", 1, true), key .. " is Master Angler")
		end
	end)

	it("keeps {zone} in the zonemaster title, filled at runtime (LED-R161, DATA-R108)", function()
		assert.is_truthy(L["title.zonemaster.text"]:find("{zone}", 1, true))
	end)

	it("has a name and a description for each of the 10 bindings (LED-R110, LED-R160)", function()
		for _, binding in ipairs(BINDINGS) do
			hasText(("binding.%s.name"):format(binding))
			hasText(("binding.%s.description"):format(binding))
		end
	end)
end)

describe("the Ledger's committed lore for the Curio Shop's second round (LED-R118, LED-R160)", function()
	-- LED-R118's nine earned bindings, without their ledger.binding. prefix, and its seven toast styles.
	local BINDINGS =
		{ "wave", "logbook", "heartwood", "stormglass", "lacquer", "knit", "flywallet", "carapace", "ember" }
	local TOAST_STYLES = {
		"ledger.toaststyle.glass",
		"ledger.toaststyle.deep",
		"ledger.toaststyle.koi",
		"ledger.toaststyle.trophy",
		"ledger.toaststyle.slate",
		"ledger.toaststyle.ice",
		"ledger.toaststyle.stitch",
	}
	local L

	setup(function()
		L = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns.L
	end)

	---@param key string
	local function hasText(key)
		local text = L[key]
		assert(type(text) == "string" and text:find("%S"), key .. " has no text")
	end

	it("has a name and a description for each of the nine bindings and seven toast styles", function()
		for _, binding in ipairs(BINDINGS) do
			hasText(("binding.%s.name"):format(binding))
			hasText(("binding.%s.description"):format(binding))
		end
		for _, good in ipairs(TOAST_STYLES) do
			hasText(("ledgergood.%s.name"):format(good))
			hasText(("ledgergood.%s.description"):format(good))
		end
	end)

	it("leaves Shagreen and Bone to Core's lore, as Core's binding (SHOP-R25)", function()
		assert.is_nil(rawget(L, "binding.shagreen.name"))
		assert.is_nil(rawget(L, "binding.shagreenbone.name"))
	end)
end)
