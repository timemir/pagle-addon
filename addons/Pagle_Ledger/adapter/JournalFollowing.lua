if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Following spread's own widget (LED-R163; ledger.md › UI): the selected Angler's level on its card, drawn from
-- the block logic/JournalFollowing.lua makes, in the Ledger art kit's look and with its pieces only (the print face's
-- large numerals, the small capitals, the wax seal), as variant A of pagle-backend's prototype lays the card out
-- (IGV-R81). The index's rows are the zone spread's (adapter/JournalZone.lua), the ruled rows the contents lines'
-- (adapter/JournalWidgets.lua).

local INK = ns.JOURNAL_INK

-- The seal's size, its words' size, and the row's height.
local SEAL, SEAL_TEXT, LEVEL_H = 78, 12.5, 96

---@class LedgerFollowingLevelWidget: LedgerJournalWidget
---@field caption FontString
---@field numerals FontString
---@field note FontString
---@field seal LedgerSeal

-- A Followed Angler's level (LED-R163): "Angler Level" in small capitals over the level in large numerals, the
-- Prestige's words under them as the bookplate writes them (LED-R146), and at the right a wax seal reading "Ledger
-- {p}%".
ns.RegisterJournalWidget("level", function(parent)
	local widget = ns.NewJournalWidget(parent) --[[@as LedgerFollowingLevelWidget]]
	widget.caption = ns.JournalLabel(widget, "sc", 13, INK.kicker)
	widget.caption:SetPoint("TOPLEFT", 0, 0)
	widget.numerals = ns.JournalLabel(widget, "print", 54, INK.title)
	widget.numerals:SetPoint("TOPLEFT", 0, -16)
	widget.label = widget.numerals
	widget.note = ns.JournalLabel(widget, "italic", 13.5, INK.note)
	widget.note:SetPoint("TOPLEFT", 0, -76)
	widget.seal = ns.JournalSeal(widget, SEAL, SEAL_TEXT)
	function widget.Fill(self, block, width)
		local room = width - SEAL - 16
		self.caption:SetText(block.value or "")
		ns.JournalBound(self.caption, room)
		self.numerals:SetText(block.text)
		ns.JournalBound(self.numerals, room)
		self.note:SetText(block.note or "")
		ns.JournalBound(self.note, room)
		self.seal:ClearAllPoints()
		self.seal:SetPoint("CENTER", self, "TOPLEFT", width - SEAL / 2 - 4, -LEVEL_H / 2)
		ns.JournalSetSeal(self.seal, block.seal or "", true)
		return LEVEL_H
	end
	return widget
end)
