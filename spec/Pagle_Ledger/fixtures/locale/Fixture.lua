-- A test fixture, never shipped: the Ledger's side of the made-up Locales in spec/Pagle/fixtures/locale/Fixture.lua.
local ns = select(2, ...)

ns.Locale("xxXX", function(L)
	L.UNFISHED = "[xx] unfished"
end, {
	name = "Xxxx",
	listed = true,
	plural = function()
		return "other"
	end,
	decimal = ",",
	thousands = ".",
})
ns.Locale("xxYY", function(L)
	L.POOLS = "[yy] pools"
end, { name = "Yyyy", listed = true, fallback = "xxXX" })
ns.Locale("xxZZ", function(L)
	L.UNFISHED = "[zz] unfished"
end, {
	name = "Zzzz",
	listed = false,
	plural = function()
		return "other"
	end,
	decimal = ",",
	thousands = ".",
})
