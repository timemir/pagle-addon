-- A hand-made Lore.lua in the generator's shape (DATA-R104) for the titles' specs: LED-R75's working names for some
-- title IDs and a Legend's title, and no text for `prestige5`, `prestige10`, `complete.treasure` and
-- `complete.trophy`, so their titles have no name (LED-R161).

if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

local L = select(2, ...).L

L["legend.19807.title"] = "The Tasty One"
L["title.complete.junk.text"] = "Collector of Boots"
L["title.complete.ledger.text"] = "Angler of Azeroth"
L["title.level1.text"] = "Minnow"
L["title.level10.text"] = "Dabbler"
L["title.level20.text"] = "Line-Caster"
L["title.level30.text"] = "Fisher"
L["title.level40.text"] = "Old Salt"
L["title.level50.text"] = "Ledgerkeeper"
L["title.level60.text"] = "Pagle's Peer"
L["title.prestige1.text"] = "Returning Tide"
L["title.zonemaster.text"] = "Warden of {zone} Waters"
