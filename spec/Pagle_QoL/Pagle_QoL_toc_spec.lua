-- Pagle_QoL.toc and what ships beside it (CORE-R2, CORE-R3, CORE-R5, QOL-R1).

local DIR = "addons/Pagle_QoL/"

-- Every file under addons/Pagle_QoL/ with one of the given extensions, relative to it, sorted.
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

describe("Pagle_QoL.toc", function()
	local loaded = loadAddon("Pagle_QoL", FOREVER_GLOBALS)
	local fields = assert(loaded.client.addons.Pagle_QoL.metadata)

	it("has the fields every TOC has (CORE-R2)", function()
		assert.are.equal("16001", fields.Interface)
		assert.are.equal("camelot", fields.AllowLoadGameType)
		assert.are.equal("Pagle", fields.Group)
		assert.are.equal("Professions", fields.Category)
		assert.are.equal("@project-version@", fields.Version)
	end)

	it("is the addon's only TOC: no per-flavour TOC files (CORE-R2)", function()
		assert.are.same({ "Pagle_QoL.toc" }, filesIn({ "toc" }))
	end)

	it("depends on Pagle, declares X-Pagle-API 1 and loads normally, not on demand (CORE-R3, QOL-R1)", function()
		assert.are.equal("Pagle", fields.Dependencies)
		assert.are.equal("1", fields["X-Pagle-API"])
		assert.is_nil(fields.LoadOnDemand)
	end)

	it("is titled Pagle QoL, the name QOL-R83's chat lines use", function()
		assert.are.equal("Pagle QoL", fields.Title)
	end)

	it("saves PagleQoLDB account-wide and nothing per character (QOL-R1, CORE-R5)", function()
		assert.are.equal("PagleQoLDB", fields.SavedVariables)
		assert.is_nil(fields.SavedVariablesPerCharacter)
	end)

	it("lists every Lua file in the addon folder, so none is left out of the load (CORE-R2)", function()
		local listed = addonFiles("Pagle_QoL")
		table.sort(listed)

		assert.are.same(filesIn({ "lua" }), listed)
	end)
end)
