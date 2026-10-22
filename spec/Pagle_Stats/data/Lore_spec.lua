-- Stats' generated lore (DATA-R104, STA-R88): addons/Pagle_Stats/data/Lore.lua adds to ns.L the name and description of
-- each of Stats' eight tracker frames, from data/lore/stats.toml: the M6 batch (DATA-R111) and the Curio Shop
-- expansion's five.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

-- STA-R88: Stats' eight goods.
local GOODS = stats.GOODS

describe("Stats' committed lore (DATA-R111, its M6 batch)", function()
	local ns

	setup(function()
		ns = stats.load().ns
	end)

	it("has a name and a description for each of Stats' eight goods once Pagle_Stats loads (STA-R88)", function()
		for _, good in ipairs(GOODS) do
			for _, field in ipairs({ "name", "description" }) do
				local key = ("statsgood.%s.%s"):format(good, field)
				local value = rawget(ns.L, key)
				assert(type(value) == "string" and value:find("%S"), key .. " has no text")
			end
		end
	end)

	it("keeps the hand-written interface strings beside the lore (CORE-R8)", function()
		assert.are.equal("Stats", ns.L.TITLE)
	end)
end)
