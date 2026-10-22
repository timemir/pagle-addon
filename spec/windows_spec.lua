-- The Pagle windows together on the package as shipped: each shares the HIGH strata at frame levels of its own, so
-- each is toplevel and raised every time it opens, or two open at once draw their parts through each other.

-- The roster Modules' folders, in CORE-R1 order.
local ROSTER = { "Pagle_Ledger", "Pagle_Hunts", "Pagle_Stats", "Pagle_TackleBoard", "Pagle_QoL" }

describe("The Pagle windows, every Module loaded", function()
	it("each opens over the windows already open, and again when asked to open while open", function()
		local loaded = enterWorld(loadAddon("Pagle", foreverWith(), { also = ROSTER }), 3)
		loaded.client.advance(30)
		local ledger = loaded.namespaces.Pagle_Ledger
		local hunts = loaded.namespaces.Pagle_Hunts
		local stats = loaded.namespaces.Pagle_Stats
		local board = loaded.namespaces.Pagle_TackleBoard
		local windows = {
			{
				open = function()
					ledger.journal:Show()
				end,
				frame = function()
					return ledger.journal.frame
				end,
			},
			{
				open = function()
					hunts.OpenBoard()
				end,
				frame = function()
					return hunts.board.frame
				end,
			},
			{
				open = function()
					stats.OpenBook()
				end,
				frame = function()
					return stats.book.frame
				end,
			},
			{
				open = function()
					board.OpenBoard()
				end,
				frame = function()
					return board.board.frame
				end,
			},
		}

		for _, window in ipairs(windows) do
			window.open()
			local frame = window.frame()
			assert.are.same({ "HIGH", true, 1 }, { frame:GetFrameStrata(), frame.toplevel, frame.raised })
			window.open()
			assert.are.equal(2, frame.raised)
		end
		assert.are.same({}, loaded.client.errors)
	end)
end)
