-- scripts/api-inventory.lua (#261): writes the WoW API inventory, .luacheckrc's stds.wow and stds.wow_variables, into
-- addons/Pagle/data/ApiInventory.lua, so `/pagle dev probe` can check every name on a live client without the repo
-- (launch re-verification check 11). With --check it writes nothing and fails while the file is stale, as the api
-- stage of scripts/check.sh runs it.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local script = dofile("spec/support/script.lua")
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os
local os = os

-- A luacheck config with a few names of each kind: a string, a namespace with fields, a nested enum, a field Pagle
-- writes (read_only = false) and a client variable.
local CONFIG = [[
stds.wow = {
	read_globals = {
		"CreateFrame",
		C_Spell = { fields = { "GetSpellName", "GetSpellTexture" } },
		Enum = { fields = { AddOnEnableState = { fields = { "None" } } } },
	},
}
stds.wow_variables = {
	read_globals = {
		"WOW_PROJECT_ID",
		SlashCmdList = { fields = { PAGLE = { read_only = false } } },
	},
}
stds.pagle = { read_globals = { "LibStub", "Pagle" } }
]]

-- A fresh temporary file holding `text`, or none when `text` is nil; returns its path.
local function tempFile(text)
	local path = os.tmpname()
	if text then
		script.wtf.writeFile(path, text)
	else
		os.remove(path)
	end
	return path
end

describe("scripts/api-inventory.lua", function()
	it("writes every inventoried name, dotted through its fields, sorted, leaving out what Pagle writes", function()
		local config, out = tempFile(CONFIG), tempFile(nil)

		local _, err, code = script.run("scripts/api-inventory.lua", { config, out })

		assert.are.equal("", err)
		assert.are.equal(0, code)
		local ns = {}
		assert(loadstring(script.wtf.readFile(out)))("Pagle", ns)
		assert.are.same({
			"C_Spell",
			"C_Spell.GetSpellName",
			"C_Spell.GetSpellTexture",
			"CreateFrame",
			"Enum",
			"Enum.AddOnEnableState",
			"Enum.AddOnEnableState.None",
			"SlashCmdList",
			"WOW_PROJECT_ID",
		}, ns.API_INVENTORY)
		os.remove(config)
		os.remove(out)
	end)

	it("with --check, passes on a current file and fails on a stale one, writing nothing", function()
		local config, out = tempFile(CONFIG), tempFile(nil)
		script.run("scripts/api-inventory.lua", { config, out })

		local _, _, current = script.run("scripts/api-inventory.lua", { "--check", config, out })
		script.wtf.writeFile(out, "-- stale\n")
		local _, err, stale = script.run("scripts/api-inventory.lua", { "--check", config, out })

		assert.are.equal(0, current)
		assert.are.equal(1, stale)
		assert.are.equal(
			"api-inventory: " .. out .. " is stale; run lua scripts/api-inventory.lua " .. config .. " " .. out .. "\n",
			err
		)
		assert.are.equal("-- stale\n", script.wtf.readFile(out))
		os.remove(config)
		os.remove(out)
	end)

	it("keeps the repo's addons/Pagle/data/ApiInventory.lua current with .luacheckrc", function()
		local _, err, code =
			script.run("scripts/api-inventory.lua", { "--check", ".luacheckrc", "addons/Pagle/data/ApiInventory.lua" })

		assert.are.equal("", err)
		assert.are.equal(0, code)
	end)

	it("fails with its usage on missing arguments", function()
		local _, err, code = script.run("scripts/api-inventory.lua", { "--check" })

		assert.are.equal(2, code)
		assert.truthy(err:find("usage: lua scripts/api-inventory.lua", 1, true))
	end)
end)
