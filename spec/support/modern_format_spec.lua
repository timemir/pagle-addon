-- The modern client's string.format (spec/support/modern_format.lua): %d, %i, %x and %X raise past a signed 32-bit
-- int, as the game does, so a spec fails on a hash or a sum the client could not format.

describe("the harness's string.format", function()
	it("raises for a %d, %i, %x or %X of a number past a signed 32-bit int, naming it", function()
		for _, conversion in ipairs({ "%d", "%i", "%x", "%X", "%08d", "%-12d" }) do
			assert.has_error(function()
				return conversion:format(2657620567)
			end, "integer overflow attempting to store 2657620567")
		end
		assert.has_error(function()
			return string.format("%d", 2 ^ 31)
		end, "integer overflow attempting to store 2147483648")
		assert.has_error(function()
			return string.format("%s then %d", "a", -2 ^ 31 - 1)
		end, "integer overflow attempting to store -2147483649")
	end)

	it("formats the signed 32-bit range, %s, %f and %.0f as stock Lua does", function()
		assert.are.equal("2147483647 -2147483648", ("%d %d"):format(2 ^ 31 - 1, -2 ^ 31))
		assert.are.equal("7fffffff", ("%x"):format(2 ^ 31 - 1))
		assert.are.equal("2657620567", ("%.0f"):format(2657620567))
		assert.are.equal("2657620567", ("%s"):format(2657620567))
		assert.are.equal("100% 5", ("%d%% %d"):format(100, 5))
		assert.are.equal("a2657620567", ("%s%.0f"):format("a", 2657620567))
	end)

	it("counts the arguments past a %%, so the %d checked is the right one", function()
		assert.has_error(function()
			return ("%d%% of %d"):format(5, 4227872046)
		end, "integer overflow attempting to store 4227872046")
	end)
end)
