-- Pagle_QoL's Bindings.xml (QOL-R1, QOL-R10, QOL-R46). The client loads it from the addon folder by name, not from the TOC.

---@return string
local function bindingsXml()
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
	local file = assert(io.open("addons/Pagle_QoL/Bindings.xml", "r"))
	local text = file:read("*a")
	file:close()
	return text
end

describe("Bindings.xml", function()
	local bindings = {}
	for attributes, body in bindingsXml():gmatch("<Binding%s+(.-)>(.-)</Binding>") do
		local binding = { body = body:gsub("<!%-%-.-%-%->", "") }
		for key, value in attributes:gmatch('(%w+)="(.-)"') do
			binding[key] = value
		end
		bindings[#bindings + 1] = binding
	end

	it("holds the Fishing key and Swap gear, in that order (QOL-R1)", function()
		assert.are.equal(2, #bindings)
		assert.are.equal("PAGLE_FISHING_KEY", bindings[1].name)
		assert.are.equal("PAGLE_SWAP_GEAR", bindings[2].name)
	end)

	it("lists both under the one Pagle header in the AddOns category (QOL-R1)", function()
		assert.are.equal("PAGLE", bindings[1].header)
		-- A header attribute starts a new header row, so the second binding names none and sits under the first's.
		assert.is_nil(bindings[2].header)
		assert.are.equal("ADDONS", bindings[1].category)
		assert.are.equal("ADDONS", bindings[2].category)
	end)

	it("gives Swap gear QoL's Swap gear as its body, guarded for a QoL without Core (QOL-R46)", function()
		assert.are.equal("if PagleQoL_SwapGear then PagleQoL_SwapGear() end", bindings[2].body)
	end)

	it("gives the Fishing key a body that does nothing (QOL-R10)", function()
		assert.matches("^%s*$", bindings[1].body)
	end)
end)
