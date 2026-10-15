if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Journal's search box on the client (LED-R148): on every text change it asks logic/JournalSpecies.lua's search
-- and lists the results in the Ledger art kit's drop-down under the slip (its Home.lua: P.ShowSearch), the waters
-- first, each with its tile's line, then the fish, each with its medallion; picking one opens its spread. Nothing
-- matching shows the no-match line; an empty box shows no drop-down. It falls open 6 units while fading in (0.14 s).

local INK = ns.JOURNAL_INK

-- The drop-down's size and place on the book (under the search slip), its rows' heights and its insets.
local DROP_W, DROP_X, DROP_Y = 268, 626, 33
local HEAD_H, ZONE_H, FISH_H, NONE_H = 21, 27, 34, 30
local INSET = 15

---@class LedgerSearchRowView: LedgerJournalClickable
---@field label FontString
---@field note FontString
---@field medal LedgerMedal
---@field wash Texture

---@class LedgerJournalSearchDrop: Frame
---@field back Frame?
---@field backH number?
---@field rows LedgerSearchRowView[]
---@field heads FontString[]
---@field rule Texture
---@field none FontString

--- Makes `box` the Journal's search box (LED-R148), its drop-down on the book `frame`, filled on every text change.
---@param journal LedgerJournal
---@param box EditBox
---@param frame Frame
---@return LedgerJournalSearchDrop
function ns.AttachJournalSearch(journal, box, frame)
	local drop = CreateFrame("Frame", nil, frame) --[[@as LedgerJournalSearchDrop]]
	drop:SetFrameLevel(frame:GetFrameLevel() + 12)
	drop:SetSize(DROP_W, 60)
	drop.rows, drop.heads = {}, {}
	drop.heads[1] = ns.JournalLabel(drop, "sc", 13, INK.kicker, ns.L.SEARCH_WATERS)
	drop.heads[2] = ns.JournalLabel(drop, "sc", 13, INK.kicker, ns.L.SEARCH_FISH)
	drop.rule = ns.JournalTint(drop, INK.rule, 1)
	drop.rule:SetSize(DROP_W - 14, 1)
	drop.none =
		ns.JournalLabel(drop, "italic", 14, INK.noteLight, ns.L.SEARCH_NONE, { wrap = true, width = DROP_W - 30 })
	drop:Hide()

	-- Picking a result empties the box, which hides the drop-down, and opens the result's place.
	---@param place LedgerJournalPlace
	local function pick(place)
		box:SetText("")
		box:ClearFocus()
		drop:Hide()
		journal:OpenPlace(place)
	end

	-- Row `i`, made on first use: a result's name, its tile's line or its medallion, opening its spread.
	---@param i integer
	---@return LedgerSearchRowView
	local function rowAt(i)
		local row = drop.rows[i]
		if not row then
			row = CreateFrame("Button", nil, drop) --[[@as LedgerSearchRowView]]
			row.wash = ns.JournalTint(row, "784614", 0.12, "BORDER")
			row.wash:SetAllPoints()
			row.wash:Hide()
			row.medal = ns.JournalMedal(row, 26)
			row.label = ns.JournalLabel(row, "print", 15, INK.body)
			row.note = ns.JournalLabel(row, "italic", 13, INK.note, "", { justify = "RIGHT" })
			row.note:SetPoint("RIGHT", -8, 0)
			ns.JournalClickable(row)
			row.open = pick
			row:SetScript("OnEnter", function(self)
				self.wash:Show()
			end)
			row:SetScript("OnLeave", function(self)
				self.wash:Hide()
			end)
			drop.rows[i] = row
		end
		return row
	end

	-- The drop-down's paper, made again at a new height.
	---@param height number
	local function paper(height)
		if drop.backH == height then
			return
		end
		if drop.back then
			drop.back:Hide()
		end
		drop.back = ns.JournalVSlice(drop, "Parts", "drop", height, 12, 12, "BACKGROUND")
		drop.back:SetPoint("TOPLEFT")
		drop.backH = height
	end

	-- It falls open: 6 units down while fading in (0.14 s, ease-out).
	local function fallOpen()
		ns.Moving()
		ns.Animate(drop, {
			{
				dur = 0.14,
				ease = ns.Ease.out,
				keys = { { 0, { -6, 0 } }, { 1, { 0, 1 } } },
				apply = function(v)
					ns.JournalAt(drop, frame, DROP_X, DROP_Y + v[1])
					drop:SetAlpha(v[2])
				end,
			},
		})
	end

	box:SetScript("OnTextChanged", function(self)
		local text = self:GetText() or ""
		local hint = journal.frame and journal.frame.searchHint
		if hint then
			hint:SetShown(text == "")
		end
		local context = journal:Context()
		local results = not context.updating and ns.JournalSearch(text, context --[[@as LedgerSpreadContext]]) or nil
		if not results then
			drop:Hide()
			return
		end
		---@cast context LedgerSpreadContext
		local zones, fish = {}, {}
		for _, result in ipairs(results) do
			table.insert(result.place.id == ns.JOURNAL_ZONE and zones or fish, result)
		end
		local y = 9
		local used = 0
		local function section(head, list, height)
			head:SetShown(#list > 0)
			if #list == 0 then
				return
			end
			ns.JournalAt(head, drop, INSET, y)
			y = y + HEAD_H - 5
			for _, result in ipairs(list) do
				used = used + 1
				local row = rowAt(used)
				local isZone = result.place.id == ns.JOURNAL_ZONE
				row:SetSize(DROP_W - 14, height)
				ns.JournalAt(row, drop, 7, y)
				row.label:SetText(result.label)
				row.label:ClearAllPoints()
				row.label:SetPoint("LEFT", isZone and INSET - 7 or 42, 0)
				row.medal:SetShown(not isZone)
				row.note:SetShown(isZone)
				if isZone then
					local tile = ns.JournalZoneTile(result.place.args.zone, context)
					row.note:SetText(tile.line or "")
					ns.JournalBound(row.note, 110)
					ns.JournalBound(row.label, DROP_W - 14 - (INSET - 7) - row.note:GetWidth() - 16)
				else
					local args = result.place.args or {}
					local itemID = args.species or args.legend
					ns.JournalSetMedal(row.medal, itemID, "sepia")
					ns.JournalAt(row.medal, row, 8, (height - 26) / 2)
					ns.JournalBound(row.label, DROP_W - 14 - 42 - 8)
				end
				row.place = result.place
				row:Show()
				y = y + height
			end
		end
		section(drop.heads[1], zones, ZONE_H)
		drop.rule:SetShown(#zones > 0 and #fish > 0)
		if #zones > 0 and #fish > 0 then
			ns.JournalAt(drop.rule, drop, 7, y + 4)
			y = y + 8
		end
		section(drop.heads[2], fish, FISH_H)
		drop.none:SetShown(#results == 0)
		if #results == 0 then
			ns.JournalAt(drop.none, drop, INSET, y)
			y = y + NONE_H
		end
		for i = used + 1, #drop.rows do
			drop.rows[i]:Hide()
		end
		local height = y + 10
		drop:SetHeight(height)
		paper(height)
		if not drop:IsShown() then
			drop:Show()
			fallOpen()
		else
			ns.JournalAt(drop, frame, DROP_X, DROP_Y)
		end
	end)
	return drop
end
