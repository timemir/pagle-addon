-- Fitting a big window to the screen as maths (core/README.md › Contracts, Pagle.FitToScreen): the scale that fits a
-- window's whole extent inside the screen less a margin, never above 1.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

describe("the fit's scale", function()
	it("shrinks a window taller or wider than the screen less 24 a side, and never grows one", function()
		assert.are.equal(0.5, ns.FitScale(1048, 1048, 1000, 2000)) -- too tall: (1048 - 48) / 2000
		assert.are.equal(0.25, ns.FitScale(1048, 2048, 4000, 1000)) -- too wide: (1048 - 48) / 4000
		assert.are.equal(1, ns.FitScale(1920, 1080, 800, 600))
	end)

	it("leaves a window at 1 on a screen not laid out yet", function()
		assert.are.same({ 1, 1 }, { ns.FitScale(0, 0, 800, 600), ns.FitScale(1920, 0, 800, 600) })
	end)
end)
