-- Pagle_Ledger.toc and what ships beside it (CORE-R2, CORE-R3, CORE-R5; ledger.md › Data).

local DIR = "addons/Pagle_Ledger/"

-- Every file under addons/Pagle_Ledger/ with one of the given extensions, relative to it, sorted.
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

describe("Pagle_Ledger.toc", function()
	local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)
	local fields = assert(loaded.client.addons.Pagle_Ledger.metadata)

	it("has the fields every TOC has (CORE-R2)", function()
		assert.are.equal("16001", fields.Interface)
		assert.are.equal("camelot", fields.AllowLoadGameType)
		assert.are.equal("Pagle", fields.Group)
		assert.are.equal("Professions", fields.Category)
		assert.are.equal("@project-version@", fields.Version)
	end)

	it("names the Module the Ledger in its Notes, the glossary's word, not a variant on its Avoid list", function()
		assert.matches("^Pagle's Ledger: ", fields.Notes)
		assert.is_nil(fields.Notes:find("Fishing Ledger", 1, true))
	end)

	it("is the addon's only TOC: no per-flavour TOC files (CORE-R2)", function()
		assert.are.same({ "Pagle_Ledger.toc" }, filesIn({ "toc" }))
	end)

	it("depends on Pagle, declares X-Pagle-API 1 and loads normally, not on demand (CORE-R3)", function()
		assert.are.equal("Pagle", fields.Dependencies)
		assert.are.equal("1", fields["X-Pagle-API"])
		assert.is_nil(fields.LoadOnDemand)
	end)

	it("is titled Pagle Ledger, as QoL's is Pagle QoL", function()
		assert.are.equal("Pagle Ledger", fields.Title)
	end)

	it("saves PagleLedgerDB account-wide and nothing per character (ledger.md › Data, CORE-R5)", function()
		assert.are.equal("PagleLedgerDB", fields.SavedVariables)
		assert.is_nil(fields.SavedVariablesPerCharacter)
	end)

	it("lists every Lua file in the addon folder, so none is left out of the load (CORE-R2)", function()
		local listed = addonFiles("Pagle_Ledger")
		table.sort(listed)

		assert.are.same(filesIn({ "lua" }), listed)
	end)

	it("splits its code into logic/ and adapter/, with its strings in locale/ (CORE-R7, CORE-R8)", function()
		local folders = {}
		for _, file in ipairs(filesIn({ "lua" })) do
			folders[file:match("^([^/]+)/")] = true
		end

		assert.are.same({ adapter = true, locale = true, logic = true }, folders)
	end)
end)
