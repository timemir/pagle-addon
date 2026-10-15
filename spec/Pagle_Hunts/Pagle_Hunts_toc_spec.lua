-- Pagle_Hunts.toc and what ships beside it (CORE-R2, CORE-R3, CORE-R5; hunts.md › Data).

local DIR = "addons/Pagle_Hunts/"

-- Every file under addons/Pagle_Hunts/ with one of the given extensions, relative to it, sorted.
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

describe("Pagle_Hunts.toc", function()
	local loaded = loadAddon("Pagle_Hunts", FOREVER_GLOBALS)
	local fields = assert(loaded.client.addons.Pagle_Hunts.metadata)

	it("has the fields every TOC has (CORE-R2)", function()
		assert.are.equal("16001", fields.Interface)
		assert.are.equal("camelot", fields.AllowLoadGameType)
		assert.are.equal("Pagle", fields.Group)
		assert.are.equal("Professions", fields.Category)
		assert.are.equal("@project-version@", fields.Version)
	end)

	it("names the Module Hunts in its Notes, the glossary's word, not a variant on its Avoid list", function()
		assert.matches("^Pagle's Hunts: ", fields.Notes)
		for _, avoided in ipairs({ "Hunt board", "Hunt module" }) do
			assert.is_nil(fields.Notes:find(avoided, 1, true))
		end
	end)

	it("is the addon's only TOC: no per-flavour TOC files (CORE-R2)", function()
		assert.are.same({ "Pagle_Hunts.toc" }, filesIn({ "toc" }))
	end)

	it("depends on Pagle, declares X-Pagle-API 1 and loads normally, not on demand (CORE-R3)", function()
		assert.are.equal("Pagle", fields.Dependencies)
		assert.are.equal("1", fields["X-Pagle-API"])
		assert.is_nil(fields.LoadOnDemand)
	end)

	it("is titled Pagle Hunts, as the Ledger's is Pagle Ledger", function()
		assert.are.equal("Pagle Hunts", fields.Title)
	end)

	it("saves PagleHuntsDB account-wide and nothing per character (hunts.md › Data, CORE-R5)", function()
		assert.are.equal("PagleHuntsDB", fields.SavedVariables)
		assert.is_nil(fields.SavedVariablesPerCharacter)
	end)

	it("lists every Lua file in the addon folder, so none is left out of the load (CORE-R2)", function()
		local listed = addonFiles("Pagle_Hunts")
		table.sort(listed)

		assert.are.same(filesIn({ "lua" }), listed)
	end)

	it("splits its code into logic/ and adapter/, its strings in locale/ and only generated files in data/", function()
		-- CORE-R7, CORE-R8; DATA-R75: the generator writes data/HuntList.lua (and, from the lore batch, data/Lore.lua).
		local generated = { ["data/HuntList.lua"] = true, ["data/Lore.lua"] = true }
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

	it("lists its generated Lore.lua right after locale/enUS.lua, the file that creates ns.L (DATA-R75)", function()
		-- DATA-R104, HNT-R130: the lore extends ns.L, so it loads after the locale and before any code reads a name.
		local at = {}
		for index, file in ipairs(addonFiles("Pagle_Hunts")) do
			at[file] = index
		end

		assert.is_number(at["data/Lore.lua"])
		assert.are.equal(at["locale/enUS.lua"] + 1, at["data/Lore.lua"])
	end)

	it("lists the generated HuntList.lua after locale/enUS.lua and before any code (DATA-R93)", function()
		local listed = addonFiles("Pagle_Hunts")
		local at = {}
		for index, file in ipairs(listed) do
			at[file] = index
		end
		local huntList = at["data/HuntList.lua"]
		assert.is_not_nil(huntList)

		assert.is_true(huntList > at["locale/enUS.lua"])
		local codeBefore = {}
		for file, index in pairs(at) do
			if (file:match("^logic/") or file:match("^adapter/")) and index < huntList then
				codeBefore[#codeBefore + 1] = file
			end
		end
		assert.are.same({}, codeBefore)
	end)
end)
