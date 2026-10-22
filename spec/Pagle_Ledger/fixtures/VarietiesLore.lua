-- A hand-made Lore.lua in the generator's shape (DATA-R104) for the varieties' specs: the `complete.varieties` title's
-- lore (VAR-R22) and a level title, so a Write-up names them (LED-R94).

if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

local L = select(2, ...).L

L["title.level1.text"] = "Minnow"
L["title.complete.varieties.text"] = "Keeper of Every Colour"
