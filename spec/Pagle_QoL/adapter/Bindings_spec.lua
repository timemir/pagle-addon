-- Pagle_QoL's Bindings.xml (QOL-R1, QOL-R10). The client loads it from the addon folder by name, not from the TOC.

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

	it("holds only the Fishing key in M1; Swap gear comes in Track Q (QOL-R1)", function()
		assert.are.equal(1, #bindings)
		assert.are.equal("PAGLE_FISHING_KEY", bindings[1].name)
	end)

	it("lists it under the Pagle header in the AddOns category (QOL-R1)", function()
		assert.are.equal("PAGLE", bindings[1].header)
		assert.are.equal("ADDONS", bindings[1].category)
	end)

	it("gives the Fishing key a body that does nothing (QOL-R10)", function()
		assert.matches("^%s*$", bindings[1].body)
	end)
end)
