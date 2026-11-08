if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The news list's own widgets (LED-R176; ledger.md › UI), drawn from the blocks logic/JournalNews.lua makes, in the
-- Ledger art kit's look and with its pieces only: an item's row (the wax seal as a small red dot, the kicker in small
-- capitals, the headline in print, its age), and the chosen item's emblem, which Core draws as the news sign's slot
-- draws it (Pagle.DrawNewsEmblem, SIGN-R13). And the Ledger's `def.news` (LED-R178).

local INK = ns.JOURNAL_INK

-- A row's height, the dot's size and the room it keeps at the left, and the emblem's size (LED-R176).
local ROW_H, DOT, DOT_ROOM = 42, 12, 22
local EMBLEM = 96

---@class LedgerNewsRowWidget: LedgerJournalWidget
---@field dot LedgerSpriteTexture
---@field kicker FontString
---@field head FontString
---@field age FontString
---@field wash Texture
---@field hover Texture
---@field dashes Frame?
---@field dashW number?

-- An item's row (LED-R176): a small red wax dot for a new item, the kind's kicker in small capitals over the headline
-- on one line, cut with "…" when it is longer than the row, and its age at the right; a faint wash under the mouse,
-- and the chosen one a deeper wash in a dashed outline, as the index rows (adapter/JournalZone.lua). A click chooses it.
ns.RegisterJournalWidget("newsRow", function(parent)
	local widget = ns.NewJournalWidget(parent) --[[@as LedgerNewsRowWidget]]
	ns.JournalClickable(widget)
	widget.wash = ns.JournalTint(widget, "784614", 0.13, "BACKGROUND", 1)
	widget.wash:SetAllPoints()
	widget.hover = ns.JournalTint(widget, "784614", 0.08, "BACKGROUND", 0)
	widget.hover:SetAllPoints()
	widget.hover:Hide()
	widget.dot = ns.JournalSprite(widget, "Book", "seal", "ARTWORK", 1, DOT)
	widget.dot:SetRotation(math.rad(-8))
	widget.kicker = ns.JournalLabel(widget, "sc", 12, INK.kicker)
	widget.head = ns.JournalLabel(widget, "print", 15, INK.body)
	widget.label = widget.head
	widget.age = ns.JournalLabel(widget, "print", 13.5, INK.small, "", { justify = "RIGHT" })
	widget:SetScript("OnEnter", function(self)
		self.hover:Show()
	end)
	widget:SetScript("OnLeave", function(self)
		self.hover:Hide()
	end)
	function widget.Fill(self, block, width, open)
		self.place, self.open = block.place, open
		self.wash:SetShown(block.selected == true)
		if self.dashes and self.dashW ~= width then
			self.dashes:Hide()
			self.dashes = nil
		end
		if block.selected and not self.dashes then
			self.dashes = ns.JournalDashes(self, 0, 0, width, ROW_H, INK.kicker, 1)
			self.dashW = width
		end
		if self.dashes then
			self.dashes:SetShown(block.selected == true)
		end
		self.dot:SetShown(block.new == true)
		ns.JournalBoxAt(self.dot, self, 6, (ROW_H - DOT) / 2)
		-- the age at the right, then the words in what is left
		local right = width - 5
		self.age:SetText(block.value or "")
		ns.JournalBound(self.age, (right - DOT_ROOM) * 0.3)
		self.age:ClearAllPoints()
		self.age:SetPoint("TOPRIGHT", self, "TOPLEFT", right, -(ROW_H - 17) / 2)
		local room = math.max(10, right - self.age:GetWidth() - 9 - DOT_ROOM)
		self.kicker:SetText(block.kicker or "")
		ns.JournalBound(self.kicker, room)
		ns.JournalAt(self.kicker, self, DOT_ROOM, 5)
		self.head:SetText(block.text)
		ns.JournalBound(self.head, room)
		ns.JournalAt(self.head, self, DOT_ROOM, 20)
		return ROW_H
	end
	return widget
end)

---@class LedgerNewsEmblemWidget: LedgerJournalWidget
---@field art Frame

-- The chosen item's emblem (LED-R176): at 96 units, centred across the page, drawn by Core as the Wood look's slot
-- draws it (SIGN-R13), a variety the player hasn't caught as its silhouette. On a Core without the drawing (before
-- 1.6's news) the room stays empty.
ns.RegisterJournalWidget("newsEmblem", function(parent)
	local widget = ns.NewJournalWidget(parent) --[[@as LedgerNewsEmblemWidget]]
	widget.art = CreateFrame("Frame", nil, widget)
	widget.art:SetSize(EMBLEM, EMBLEM)
	function widget.Fill(self, block, width)
		ns.JournalAt(self.art, self, (width - EMBLEM) / 2, 0)
		if Pagle.DrawNewsEmblem then
			Pagle.DrawNewsEmblem(self.art, block.emblem, EMBLEM)
		end
		return EMBLEM + 4
	end
	return widget
end)

--- Opens the Fish Journal, closed or open, on the news list with item `id` chosen, the newest when it names none the
--- news has (LED-R178): the Ledger's `def.news`, which the news sign's left click calls (SIGN-R42, VIEW-R46). It makes
--- no secure frames, so it works while restricted (LED-R121).
---@param id string?
function ns.OpenJournalNews(id)
	local place = ns.JournalPlace.news(id)
	ns.journal:Open(place.id, place.args)
end
