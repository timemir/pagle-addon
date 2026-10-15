if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Legends spread's own widget (LED-R147; ledger.md › UI): a Legend's plate, drawn inside the book from the blocks
-- logic/JournalLegends.lua makes, one filling each page. It is the Journal's own drawing, never an Announcement. The
-- look follows variant C's bookplate in prototypes/fish-journal/ (a double rule in the kicker's brown).

local LOOK = ns.JOURNAL_LOOK

-- The plate's height (a page body's, under the book's insets), its double rule's inset and gap, the room inside it,
-- the icon's size and the gap between its lines.
local PLATE_HEIGHT = 480
local RULE_GAP = 4
local PAD = 24
local PLATE_ICON = 96
local LINE_GAP = 12

---@class LedgerPlateWidget: LedgerJournalWidget
---@field lines FontString[]
---@field foot FontString

-- A rectangle of four thin rules, `inset` in from `frame`'s edges.
---@param frame Frame
---@param inset number
local function ruled(frame, inset)
	for _, side in ipairs({
		{ "TOPLEFT", "TOPRIGHT", false },
		{ "BOTTOMLEFT", "BOTTOMRIGHT", false },
		{ "TOPLEFT", "BOTTOMLEFT", true },
		{ "TOPRIGHT", "BOTTOMRIGHT", true },
	}) do
		local line = frame:CreateTexture(nil, "BORDER")
		ns.JournalPaint(line, LOOK.kicker)
		local x = side[1]:find("RIGHT") and -inset or inset
		local y = side[1]:find("BOTTOM") and inset or -inset
		local toX = side[2]:find("RIGHT") and -inset or inset
		local toY = side[2]:find("BOTTOM") and inset or -inset
		line:SetPoint(side[1], x, y)
		line:SetPoint(side[2], toX, toY)
		if side[3] then
			line:SetWidth(1)
		else
			line:SetHeight(1)
		end
	end
end

-- A Legend's plate (LED-R147): a double rule round the page, then either the Legend's icon in sepia over its name, or
-- its lines (the first in handwriting), centred, with the faded words at its foot. A click anywhere opens its place.
ns.RegisterJournalWidget("plate", function(parent)
	local widget = CreateFrame("Button", nil, parent) --[[@as LedgerPlateWidget]]
	local fonts = ns.JournalFonts()
	ruled(widget, 0)
	ruled(widget, RULE_GAP)
	local texture = widget:CreateTexture(nil, "ARTWORK")
	texture:SetSize(PLATE_ICON, PLATE_ICON)
	texture:SetPoint("TOP", 0, -(PAD + 40))
	widget.texture = texture
	local name = ns.JournalText(widget, fonts.title, LOOK.title)
	name:SetJustifyH("CENTER")
	name:SetWordWrap(true)
	name:SetPoint("TOP", texture, "BOTTOM", 0, -LINE_GAP)
	widget.label = name
	widget.lines = {}
	widget.foot = ns.JournalText(widget, fonts.small, LOOK.faded)
	widget.foot:SetJustifyH("CENTER")
	widget.foot:SetPoint("BOTTOM", 0, PAD)
	ns.JournalClickable(widget)
	-- Line `i` of the plate's words, made on first use: the first in handwriting, the rest in the serif face.
	local function lineAt(i)
		local line = widget.lines[i]
		if not line then
			line = ns.JournalText(widget, i == 1 and fonts.hand or fonts.text, i == 1 and LOOK.blue or LOOK.ink)
			line:SetJustifyH("CENTER")
			line:SetWordWrap(true)
			widget.lines[i] = line
		end
		return line
	end
	function widget.Fill(_, block, width, open)
		widget.place, widget.open = block.place, open
		local inner = width - 2 * PAD
		local icon = block.icon
		texture:SetShown(icon ~= nil)
		if icon ~= nil then
			ns.JournalItemIcon(texture, icon, "sepia")
		end
		name:SetWidth(inner)
		name:SetText(block.text or "")
		name:SetShown(block.text ~= nil)
		local list = block.lines or {}
		local y = PAD + 80
		for i, text in ipairs(list) do
			local line = lineAt(i)
			line:SetWidth(inner)
			line:SetText(text)
			line:ClearAllPoints()
			line:SetPoint("TOP", 0, -y)
			line:Show()
			y = y + line:GetStringHeight() + LINE_GAP
		end
		for i = #list + 1, #widget.lines do
			widget.lines[i]:Hide()
		end
		widget.foot:SetWidth(inner)
		widget.foot:SetText(block.value or "")
		widget.foot:SetShown(block.value ~= nil)
		return PLATE_HEIGHT
	end
	return widget
end)
