if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The collection spreads' own widgets (LED-R143, LED-R144; ledger.md › UI): the Trophy Room's measuring board and
-- the Junk Museum's plinths, drawn from the blocks logic/JournalCollections.lua makes. The look follows
-- prototypes/fish-journal/ variant E (its book is variant C's).

local LOOK = ns.JOURNAL_LOOK

-- The measuring board: its height, the room at each end of the rule, and each tick's length, longer when inked.
local BOARD_HEIGHT, BOARD_END = 58, 14
local TICK, TICK_INKED = 12, 22

---@class LedgerBoardTickView
---@field mark FontString    -- "✓" over a weight landed
---@field weight FontString  -- the weight in pounds
---@field line Texture

-- The measuring board (LED-R143, LED-R62): a rule along the page's foot with a tick per weight, placed by its pounds,
-- its weight over it, and a red ✓ over it, the tick inked red and longer, where landed.
ns.RegisterJournalWidget("board", function(parent)
	local widget = CreateFrame("Button", nil, parent) --[[@as LedgerJournalWidget]]
	local fonts = ns.JournalFonts()
	local rule = widget:CreateTexture(nil, "BORDER")
	rule:SetColorTexture(LOOK.kicker[1], LOOK.kicker[2], LOOK.kicker[3], 1)
	rule:SetPoint("BOTTOMLEFT")
	rule:SetPoint("BOTTOMRIGHT")
	rule:SetHeight(2)
	---@type LedgerBoardTickView[]
	local views = {}
	local function viewAt(i)
		if not views[i] then
			local mark = ns.JournalText(widget, fonts.hand, LOOK.red)
			mark:SetText(ns.L.TROPHY_TICK_MARK)
			local weight = ns.JournalText(widget, fonts.small, LOOK.stampOff)
			weight:SetJustifyH("CENTER")
			views[i] = { mark = mark, weight = weight, line = widget:CreateTexture(nil, "ARTWORK") }
		end
		return views[i]
	end
	function widget.Fill(_, block, width)
		local ticks = block.ticks or {}
		for i, tick in ipairs(ticks) do
			local view = viewAt(i)
			local x = BOARD_END + tick.at * (width - 2 * BOARD_END)
			local color = tick.inked and LOOK.red or LOOK.stampOff
			local length = tick.inked and TICK_INKED or TICK
			view.line:SetColorTexture(color[1], color[2], color[3], 1)
			view.line:SetSize(2, length)
			view.line:ClearAllPoints()
			view.line:SetPoint("BOTTOM", widget, "BOTTOMLEFT", x, 2)
			local ink = tick.inked and LOOK.title or LOOK.stampOff
			view.weight:SetTextColor(ink[1], ink[2], ink[3])
			view.weight:SetText(tick.text)
			view.weight:ClearAllPoints()
			view.weight:SetPoint("BOTTOM", view.line, "TOP", 0, 2)
			view.weight:Show()
			view.line:Show()
			view.mark:ClearAllPoints()
			view.mark:SetPoint("BOTTOM", view.weight, "TOP", 0, 0)
			view.mark:SetShown(tick.inked)
		end
		for i = #ticks + 1, #views do
			views[i].mark:Hide()
			views[i].weight:Hide()
			views[i].line:Hide()
		end
		return BOARD_HEIGHT
	end
	return widget
end)
