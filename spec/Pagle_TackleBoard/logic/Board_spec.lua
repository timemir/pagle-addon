-- What the Tackle Board decides (logic/Board.lua): what the board shows before Start, while updating and once started
-- (TKB-R5, TKB-R107, TKB-R108), and the parts the pins' and the ledge's tickets draw (TKB-R101, TKB-R103, TKB-R106).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

describe("what the board shows", function()
	local ns = board.load().ns

	it("before Start: the empty slip, an enabled Start my board, bare cork and ledge (TKB-R107, TKB-R5)", function()
		assert.are.same(
			{ empty = true, startEnabled = true, updating = false, parts = {} },
			ns.BoardShows(false, false)
		)
	end)

	it('before Start, while updating: the slip, a disabled Start and "Updating…" (TKB-R5, TKB-R108)', function()
		assert.are.same({ empty = true, startEnabled = false, updating = true, parts = {} }, ns.BoardShows(false, true))
	end)

	it("once started: no slip and no Start button, every part in board order (TKB-R5, TKB-R101)", function()
		assert.are.same({
			empty = false,
			startEnabled = false,
			updating = false,
			parts = { "pins", "overflow", "spike", "ledge" },
		}, ns.BoardShows(true, false))
	end)

	it('once started, while updating: every part still drawn, under "Updating…" (TKB-R108)', function()
		assert.are.same({
			empty = false,
			startEnabled = false,
			updating = true,
			parts = { "pins", "overflow", "spike", "ledge" },
		}, ns.BoardShows(true, true))
	end)
end)

describe("the board's parts (TKB-R101, TKB-R103, TKB-R106)", function()
	local ns = board.load().ns

	it(
		"are the pins, the overflow strip, the spike and the ledge, in drawing order (TKB-R101, TKB-R103, TKB-R106)",
		function()
			assert.are.same({ "pins", "overflow", "spike", "ledge" }, ns.BOARD_PARTS)
		end
	)

	it("have no renderer until one is registered, and a later registration replaces the first", function()
		local parts = ns.NewBoardParts()
		local first, second = function() end, function() end

		assert.is_nil(parts:Renderer("spike"))
		parts:Register("spike", first)
		parts:Register("spike", second)

		assert.are.equal(second, parts:Renderer("spike"))
		assert.is_nil(parts:Renderer("ledge"))
	end)

	it("refuse a part the board doesn't have, or a renderer that isn't a function", function()
		local parts = ns.NewBoardParts()

		assert.has_error(function()
			parts:Register("drawer", function() end)
		end)
		assert.has_error(function()
			parts:Register("pins", "draw me")
		end)
	end)
end)
