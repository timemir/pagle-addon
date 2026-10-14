if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The zone spread's own widgets (LED-R135–R137; ledger.md › UI): Zone Mastery's rank ladder and the list rows of
-- Species and trophy families, drawn from the blocks logic/JournalZone.lua makes. The look follows
-- prototypes/fish-journal/ variant E.

local LOOK = ns.JOURNAL_LOOK

-- The rank ladder's rung height, and the room each side of a rung's word.
local RUNG_HEIGHT = 18
local RUNG_PAD = 6

-- A box of four 1.5 px red edges around `frame`, as variant E circles the shown rung.
---@param frame Frame
---@return Texture[]
local function redBox(frame)
	local edges = {}
	for _, points in ipairs({
		{ "TOPLEFT", "TOPRIGHT", true },
		{ "BOTTOMLEFT", "BOTTOMRIGHT", true },
		{ "TOPLEFT", "BOTTOMLEFT", false },
		{ "TOPRIGHT", "BOTTOMRIGHT", false },
	}) do
		local edge = frame:CreateTexture(nil, "BORDER")
		edge:SetPoint(points[1])
		edge:SetPoint(points[2])
		if points[3] then
			edge:SetHeight(1.5)
		else
			edge:SetWidth(1.5)
		end
		edge:SetColorTexture(LOOK.red[1], LOOK.red[2], LOOK.red[3], 1)
		edges[#edges + 1] = edge
	end
	return edges
end

---@class LedgerLadderRungView
---@field frame Frame
---@field text FontString
---@field box Texture[]
---@field separator FontString?

-- Zone Mastery's ladder (LED-R135): the ranks side by side, those reached inked, the shown one red in a red box.
ns.RegisterJournalWidget("ladder", function(parent)
	local widget = CreateFrame("Button", nil, parent) --[[@as LedgerJournalWidget]]
	---@type LedgerLadderRungView[]
	local rungs = {}
	local function rungAt(i)
		if not rungs[i] then
			local frame = CreateFrame("Frame", nil, widget)
			local text = ns.JournalText(frame, ns.JournalFonts().text, LOOK.stampOff)
			text:SetPoint("CENTER")
			local separator
			if i > 1 then
				separator = ns.JournalText(widget, ns.JournalFonts().text, LOOK.stampOff)
				separator:SetText(ns.L.ZONE_LADDER_SEPARATOR)
			end
			rungs[i] = { frame = frame, text = text, box = redBox(frame), separator = separator }
		end
		return rungs[i]
	end
	function widget.Fill(_, block)
		local list = block.rungs or {}
		local x = 0
		for i, data in ipairs(list) do
			local rung = rungAt(i)
			if rung.separator then
				rung.separator:ClearAllPoints()
				rung.separator:SetPoint("LEFT", widget, "TOPLEFT", x, -RUNG_HEIGHT / 2)
				rung.separator:Show()
				x = x + rung.separator:GetStringWidth()
			end
			local color = data.circled and LOOK.red or data.inked and LOOK.title or LOOK.stampOff
			rung.text:SetText(data.text)
			rung.text:SetTextColor(color[1], color[2], color[3])
			for _, edge in ipairs(rung.box) do
				edge:SetShown(data.circled)
			end
			local width = rung.text:GetStringWidth() + 2 * RUNG_PAD
			rung.frame:SetSize(width, RUNG_HEIGHT)
			rung.frame:ClearAllPoints()
			rung.frame:SetPoint("TOPLEFT", x, 0)
			rung.frame:Show()
			x = x + width
		end
		for i = #list + 1, #rungs do
			rungs[i].frame:Hide()
			if rungs[i].separator then
				rungs[i].separator:Hide()
			end
		end
		return RUNG_HEIGHT
	end
	return widget
end)

-- A row's icon size, and the gap after the icon and before the stars and value.
local ROW_ICON_SIZE = 22
local ROW_GAP = 6

---@class LedgerJournalRowView: LedgerJournalWidget
---@field icon Texture
---@field name FontString
---@field margin FontString
---@field stars FontString
---@field value FontString
---@field highlight Texture

-- A list row (LED-R136, LED-R137): a small item icon in sepia or as a black silhouette (LED-R124), the text (faded for
-- what is unknown), its margin notes in handwriting under it, its stars ("★★☆", ns.JournalStars) and a value at the
-- right, a faint wash when selected; a click opens its place.
ns.RegisterJournalWidget("row", function(parent)
	local widget = CreateFrame("Button", nil, parent) --[[@as LedgerJournalRowView]]
	local fonts = ns.JournalFonts()
	widget.highlight = ns.JournalSolid(widget, LOOK.kicker, "BACKGROUND", 0.15)
	widget.icon = widget:CreateTexture(nil, "ARTWORK")
	widget.icon:SetSize(ROW_ICON_SIZE, ROW_ICON_SIZE)
	widget.icon:SetPoint("TOPLEFT")
	widget.icon:SetDesaturated(true)
	widget.value = ns.JournalText(widget, fonts.text, LOOK.ink)
	widget.value:SetPoint("TOPRIGHT")
	widget.value:SetJustifyH("RIGHT")
	widget.stars = ns.JournalText(widget, fonts.text, LOOK.red)
	widget.stars:SetJustifyH("RIGHT")
	widget.name = ns.JournalText(widget, fonts.text, LOOK.ink)
	widget.name:SetWordWrap(true)
	widget.label = widget.name
	widget.margin = ns.JournalText(widget, fonts.hand, LOOK.blue)
	widget.margin:SetWordWrap(true)
	local place, openPlace
	widget:SetScript("OnClick", function()
		if place then
			openPlace(place)
		end
	end)
	function widget.Fill(_, block, width, open)
		place, openPlace = block.place, open
		widget.highlight:SetShown(block.selected == true)
		local icon = block.icon
		widget.icon:SetShown(icon ~= nil)
		if type(icon) == "number" then
			local _, _, _, _, fileID = C_Item.GetItemInfoInstant(icon)
			icon = fileID or icon
		end
		widget.icon:SetTexture(icon)
		local tint = block.look == "silhouette" and { 0, 0, 0 } or LOOK.sepia
		widget.icon:SetVertexColor(tint[1], tint[2], tint[3])
		local left = icon and ROW_ICON_SIZE + ROW_GAP or 0
		widget.value:SetText(block.value or "")
		widget.value:SetShown(block.value ~= nil)
		local right = block.value and widget.value:GetStringWidth() + ROW_GAP or 0
		widget.stars:ClearAllPoints()
		widget.stars:SetPoint("TOPRIGHT", -right, 0)
		widget.stars:SetText(block.stars and ns.JournalStars(block.stars) or "")
		widget.stars:SetShown(block.stars ~= nil)
		right = right + (block.stars and widget.stars:GetStringWidth() + ROW_GAP or 0)
		local ink = block.color == "faded" and LOOK.faded or LOOK.ink
		widget.name:SetTextColor(ink[1], ink[2], ink[3])
		widget.name:ClearAllPoints()
		widget.name:SetPoint("TOPLEFT", left, 0)
		widget.name:SetWidth(width - left - right)
		widget.name:SetText(block.text)
		local height = widget.name:GetStringHeight()
		local margin = block.margin
		widget.margin:SetShown(margin ~= nil)
		if margin then
			widget.margin:ClearAllPoints()
			widget.margin:SetPoint("TOPLEFT", left, -height)
			widget.margin:SetWidth(width - left)
			widget.margin:SetText(table.concat(margin, ns.L.ZONE_MARGIN_SEPARATOR))
			height = height + widget.margin:GetStringHeight()
		end
		return math.max(height, icon and ROW_ICON_SIZE or 0)
	end
	return widget
end)
