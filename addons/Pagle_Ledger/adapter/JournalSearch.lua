if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Journal's search box on the client (LED-R148): on every text change it asks logic/JournalSpecies.lua's search
-- and lists the results in a dropdown under the box; picking one opens its spread. Nothing matching shows the
-- no-match line; an empty box shows no dropdown.

local LOOK = ns.JOURNAL_LOOK
local ROW_HEIGHT = 20
local ROW_INSET = 8

---@class LedgerSearchRowView: LedgerJournalClickable
---@field label FontString

---@class LedgerJournalSearchDrop: Frame
---@field rows LedgerSearchRowView[]

--- Makes `box` the Journal's search box (LED-R148): a dropdown under it, filled on every text change.
---@param journal LedgerJournal
---@param box EditBox
---@return LedgerJournalSearchDrop
function ns.AttachJournalSearch(journal, box)
	local drop = CreateFrame("Frame", nil, box) --[[@as LedgerJournalSearchDrop]]
	drop:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -2)
	drop:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -2)
	drop:SetFrameStrata("DIALOG")
	ns.JournalSolid(drop, LOOK.paper, "BACKGROUND")
	drop.rows = {}
	drop:Hide()

	-- Picking a result empties the box, which hides the dropdown, and opens the result's place.
	---@param place LedgerJournalPlace
	local function pick(place)
		box:SetText("")
		box:ClearFocus()
		drop:Hide()
		journal:OpenPlace(place)
	end

	-- Row `i`, made on first use: a result's name opening its spread, or the no-match line, opening nothing.
	---@param i integer
	---@return LedgerSearchRowView
	local function rowAt(i)
		local row = drop.rows[i]
		if not row then
			row = CreateFrame("Button", nil, drop) --[[@as LedgerSearchRowView]]
			row:SetHeight(ROW_HEIGHT)
			row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
			row:SetPoint("TOPRIGHT", 0, -(i - 1) * ROW_HEIGHT)
			row.label = ns.JournalText(row, ns.JournalFonts().text, LOOK.ink)
			row.label:SetPoint("LEFT", ROW_INSET, 0)
			ns.JournalClickable(row)
			row.open = pick
			drop.rows[i] = row
		end
		return row
	end

	box:SetScript("OnTextChanged", function(self)
		local context = journal:Context()
		local results = not context.updating and ns.JournalSearch(self:GetText() or "", context) or nil
		if not results then
			drop:Hide()
			return
		end
		local lines = #results
		if lines == 0 then
			local row = rowAt(1)
			row.label:SetText(ns.L.SEARCH_NONE)
			row.label:SetTextColor(LOOK.faded[1], LOOK.faded[2], LOOK.faded[3])
			row.place = nil
			row:Show()
			lines = 1
		end
		for i, result in ipairs(results) do
			local row = rowAt(i)
			row.label:SetText(result.label)
			row.label:SetTextColor(LOOK.ink[1], LOOK.ink[2], LOOK.ink[3])
			row.place = result.place
			row:Show()
		end
		for i = lines + 1, #drop.rows do
			drop.rows[i]:Hide()
		end
		drop:SetHeight(lines * ROW_HEIGHT)
		drop:Show()
	end)
	return drop
end
