-- Pagle_Stats.toc and what ships beside it (CORE-R2, CORE-R3, CORE-R5; stats.md › Data).

local DIR = "addons/Pagle_Stats/"

-- Every file under addons/Pagle_Stats/ with one of the given extensions, relative to it, sorted.
---@param extensions string[]
---@return string[]
local function filesIn(extensions)
	local found = {}
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
	local find = assert(io.popen("find " .. DIR .. " -type f"))
	for path in find:lines() do
		local file = path:sub(#DIR + 1)
		for _, extension in ipairs(extensions) do
			if file:sub(-#extension - 1) == "." .. extension then
				found[#found + 1] = file
			end
		end
	end
	find:close()
	table.sort(found)
	return found
end

describe("Pagle_Stats.toc", function()
	local loaded = loadAddon("Pagle_Stats", FOREVER_GLOBALS)
	local fields = assert(loaded.client.addons.Pagle_Stats.metadata)

	it("has the fields every TOC has (CORE-R2)", function()
		assert.are.equal("16001", fields.Interface)
		assert.are.equal("camelot", fields.AllowLoadGameType)
		assert.are.equal("Pagle", fields.Group)
		assert.are.equal("Professions", fields.Category)
		assert.are.equal("@project-version@", fields.Version)
	end)

	it("names the Module Stats in its Notes, in the glossary's words, none on an Avoid list", function()
		-- CONTEXT.md › Stats, Your odds and Dry spell.
		assert.matches("^Pagle's Stats: ", fields.Notes)
		assert.is_not_nil(fields.Notes:find("Your odds", 1, true))
		assert.is_not_nil(fields.Notes:find("Dry spells", 1, true))
		local notes = fields.Notes:lower()
		for _, avoided in ipairs({ "metrics", "drop rate", "loot chance", "catch rate", "pity", "overdue" }) do
			assert.is_nil(notes:find(avoided, 1, true))
		end
	end)

	it("is the addon's only TOC: no per-flavour TOC files (CORE-R2)", function()
		assert.are.same({ "Pagle_Stats.toc" }, filesIn({ "toc" }))
	end)

	it("depends on Pagle, declares X-Pagle-API 1 and loads normally, not on demand (CORE-R3)", function()
		assert.are.equal("Pagle", fields.Dependencies)
		assert.are.equal("1", fields["X-Pagle-API"])
		assert.is_nil(fields.LoadOnDemand)
	end)

	it("is titled Pagle Stats, as the Ledger's is Pagle Ledger and Hunts' Pagle Hunts", function()
		assert.are.equal("Pagle Stats", fields.Title)
	end)

	it("saves PagleStatsDB account-wide and nothing per character (stats.md › Data, CORE-R5)", function()
		assert.are.equal("PagleStatsDB", fields.SavedVariables)
		assert.is_nil(fields.SavedVariablesPerCharacter)
	end)

	it("lists every Lua file in the addon folder, so none is left out of the load (CORE-R2)", function()
		local listed = addonFiles("Pagle_Stats")
		table.sort(listed)

		assert.are.same(filesIn({ "lua" }), listed)
	end)

	it("splits its code into logic/ and adapter/, its strings in locale/ and only generated files in data/", function()
		-- CORE-R7, CORE-R8; DATA-R107: the generator writes data/Lore.lua from the M6 lore batch on.
		local generated = { ["data/Lore.lua"] = true }
		local folders, handWrittenData = {}, {}
		for _, file in ipairs(filesIn({ "lua" })) do
			local folder = file:match("^([^/]+)/")
			folders[folder] = true
			if folder == "data" and not generated[file] then
				handWrittenData[#handWrittenData + 1] = file
			end
		end
		folders.data = nil

		assert.are.same({ adapter = true, locale = true, logic = true }, folders)
		assert.are.same({}, handWrittenData)
	end)

	it("loads locale/enUS.lua first, so every file after it has ns.L (CORE-R8)", function()
		assert.are.equal("locale/enUS.lua", addonFiles("Pagle_Stats")[1])
	end)
end)
