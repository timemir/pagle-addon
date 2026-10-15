if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The tracker block maker (TKB-R122, TKB-R124, CORE-R73; tackle-board.md › UI, the tracker): the Tackle Board's block in
-- Core's dock, drawn from a list of line descriptions in one of its three frames, as the board art kit draws them
-- (PagleArtBoard's Tracker.lua): No frame (the default, native look: each line on a fading shade), Corkboard (a cork
-- panel in a brass rim, each goal a paper slip on a tack) and Driftwood Plank (a grey plank, its lines ruled apart).
-- The frames are sliced in three down, so they fit any number of lines. The Curio Shop's previews draw a sample with it
-- (TKB-R125, adapter/Goods.lua); the live tracker (adapter/Tracker.lua) fills it with live lines, gives its rows
-- clicks and docks it. The header's flame and chevron and a slip's tack come from the small Marks atlas, so the tracker
-- loads the frames' atlas (Tracker) only with a Corkboard or Driftwood Plank.

--- The tracker's width in UI units, its words' width, so the dock's blocks line up (CORE-R70). A frame reaches out
--- round it.
ns.TRACKER_WIDTH = 250

--- One of the tracker's frames (TKB-R124, TKB-R125), as the kit lays it out, its x from the words' left edge and its y
--- from the block's top: the frame's sprite and how far it reaches left and right of the words, the header's top and
--- its fonts, where the first goal line starts, each goal line's height, where its text and where line sit in it, the
--- room under the last line, and its fonts and the green of " · here".
---@class TackleTrackerStyle
---@field frame string?        -- its sprite in the Tracker atlas; nil: no frame
---@field left number          -- how far the frame reaches left of the words
---@field right number         -- and right of them
---@field header number        -- the header's top
---@field title string         -- fonts (adapter/BoardArt.lua's ns.BOARD_FONTS)
---@field caps boolean?        -- the title in capitals
---@field headRight string
---@field top number           -- the first goal line's top
---@field step number          -- a goal line's height
---@field textY number         -- its text's top in it
---@field whereY number        -- its where line's top in it
---@field whereX number        -- its where line's indent
---@field goal string
---@field count string
---@field where string
---@field more string
---@field moreX number         -- a plain line's indent, and its top below the last goal line
---@field moreY number
---@field pad number           -- the room under the last line
---@field here string          -- " · here" in green
---@field complete string      -- a goal flashing "Complete" (TKB-R123)
---@field shade boolean?       -- each line on a fading shade (No frame)
---@field slips boolean?       -- each goal on a paper slip with a tack (Corkboard)
---@field rules boolean?       -- a faint rule between lines (Driftwood Plank)

---@type table<string, TackleTrackerStyle>
ns.TRACKER_STYLES = {
	none = {
		left = 8,
		right = 8,
		header = 0,
		title = "TrackerTitle",
		headRight = "TrackerHeadRight",
		top = 26,
		step = 41,
		textY = 3,
		whereY = 17,
		whereX = 12,
		goal = "TrackerGoal",
		count = "TrackerCount",
		where = "TrackerWhere",
		more = "TrackerMore",
		moreX = 0,
		moreY = 4,
		pad = 4,
		here = "8FD18F",
		complete = "9CF09C",
		shade = true,
	},
	cork = {
		frame = "trk-cork",
		left = 19,
		right = 19,
		header = 8,
		title = "CorkTitle",
		headRight = "CorkHeadRight",
		top = 40,
		step = 53,
		textY = 7,
		whereY = 24,
		whereX = 0,
		goal = "CorkGoal",
		count = "CorkCount",
		where = "CorkWhere",
		more = "CorkMore",
		moreX = -3,
		moreY = -6,
		pad = 10,
		here = "2A6A2A",
		complete = "1E6A1E",
		slips = true,
	},
	drift = {
		frame = "trk-drift",
		left = 22,
		right = 20,
		header = 12,
		title = "DriftTitle",
		caps = true,
		headRight = "DriftHeadRight",
		top = 39,
		step = 45,
		textY = 6,
		whereY = 21,
		whereX = 0,
		goal = "DriftGoal",
		count = "DriftCount",
		where = "DriftWhere",
		more = "DriftMore",
		moreX = 0,
		moreY = 4,
		pad = 12,
		here = "A8E09A",
		complete = "9CF09C",
		rules = true,
	},
}

--- One line of the tracker, top to bottom (TKB-R122):
--- - `header`: `text` ("Tackle Board"), the flame before it while `fire`, `right` on the right ("12 · 4 open") and the
---   chevron, turned up while `collapsed`;
--- - `goal`: `text` with its `count` right-aligned ("12/30"), then its `where` line, " · here" in green; `expedition`
---   marks an Expedition's; `complete` (a goal completed live, TKB-R123) draws it green, "Complete" in the count's
---   place, with no where line;
--- - `line`: a plain line ("+2 more on the board (elsewhere)", "All done. Fresh Notices at reset.", "Updating…").
---@class TackleTrackerLine
---@field kind "header"|"goal"|"line"
---@field text string
---@field right string?
---@field fire boolean?
---@field collapsed boolean?
---@field count string?
---@field where string?
---@field expedition boolean?
---@field complete boolean?
---@field goalID string?   -- a goal's ID, for the live tracker's click (TKB-R123)
---@field board boolean?   -- a plain line whose click opens the board ("+N more", TKB-R123)

-- A plain line's height, and a collapsed header's.
local LINE_HEIGHT, HEADER_HEIGHT = 26, 26
-- The slips' lean on the Corkboard, line by line.
local SLIP_LEANS = { -0.6, 0.5, -0.3, 0.7, -0.5 }

--- One row of the block: every widget a line kind may use, shown as its line needs. A button, so the live tracker can
--- give it clicks (TKB-R122, TKB-R123).
---@class TackleTrackerRow: Button
---@field line TackleTrackerLine
---@field flame TackleSprite   -- the header's flame
---@field chevron TackleSprite -- the header's chevron
---@field text FontString      -- the header's title, a goal's text, a plain line
---@field right FontString     -- the header's right text, a goal's count
---@field sub FontString       -- a goal's where line
---@field here FontString      -- its " · here", in green
---@field shade Texture        -- No frame: the line's shade
---@field slip TackleSprite?   -- Corkboard: the goal's slip
---@field tack TackleSprite?
---@field rule Texture         -- Driftwood Plank: the rule above it

--- A tracker block (TKB-R122): `SetLines` draws its lines and returns its height; `SetFrame` dresses it in one of the
--- frames (nil: No frame). Either may come first.
---@class TackleTrackerBlock: Frame
---@field rows TackleTrackerRow[]
---@field frame TackleVSlice?
---@field style TackleTrackerStyle
---@field lines TackleTrackerLine[]
---@field SetLines fun(self: TackleTrackerBlock, lines: TackleTrackerLine[]): number
---@field SetFrame fun(self: TackleTrackerBlock, style: TackleTrackerStyle?)

---@param row Button
---@param font string
---@return FontString
local function fontString(row, font)
	local text = ns.ArtText(row, font)
	text:SetWordWrap(false)
	return text
end

-- Builds one row of `block`.
---@param block TackleTrackerBlock
---@return TackleTrackerRow
local function newRow(block)
	local row = CreateFrame("Button", nil, block) --[[@as TackleTrackerRow]]
	row.shade = row:CreateTexture(nil, "BACKGROUND")
	row.rule = row:CreateTexture(nil, "BACKGROUND", nil, 1)
	row.flame = ns.ArtSprite(row, "Marks", "fl", "ARTWORK")
	row.chevron = ns.ArtSprite(row, "Marks", "chev", "ARTWORK")
	row.text = fontString(row, "TrackerGoal")
	row.right = fontString(row, "TrackerCount")
	row.right:SetJustifyH("RIGHT")
	row.sub = fontString(row, "TrackerWhere")
	row.here = fontString(row, "TrackerWhere")
	row.here:SetPoint("LEFT", row.sub, "RIGHT", 0, 0)
	return row
end

-- Turns the chevron up (collapsed) or down, by flipping its sprite.
---@param chevron TackleSprite
---@param up boolean
local function pointChevron(chevron, up)
	local atlas = ns.BOARD_ATLASES.Marks
	local sprite = atlas.sprites.chev
	local top, bottom = sprite.y / atlas.height, (sprite.y + sprite.h) / atlas.height
	local left, right = sprite.x / atlas.width, (sprite.x + sprite.w) / atlas.width
	if up then
		chevron:SetTexCoord(left, right, bottom, top)
	else
		chevron:SetTexCoord(left, right, top, bottom)
	end
end

-- Splits a where line from its " · here" (logic/Words.lua's WHERE_HERE), so the kit's green can ink it apart.
---@param where string
---@return string where
---@return string here "" when there is none
local function splitHere(where)
	local suffix = ns.Fill(ns.L.WHERE_HERE, { where = "" })
	if suffix ~= "" and where:sub(-#suffix) == suffix then
		return where:sub(1, #where - #suffix), suffix
	end
	return where, ""
end

-- Lays out `row` for `line` in `style`, the `n`th goal line, and returns its height.
---@param row TackleTrackerRow
---@param line TackleTrackerLine
---@param style TackleTrackerStyle
---@param n integer
---@param last boolean the header with no lines under it
---@return number
local function layOut(row, line, style, n, last)
	local width = ns.TRACKER_WIDTH
	row.line = line
	local kind = line.kind
	local text, right = row.text, row.right
	text:ClearAllPoints()
	right:ClearAllPoints()
	row.flame:SetShown(kind == "header" and line.fire == true)
	row.chevron:SetShown(kind == "header")
	row.sub:SetShown(kind == "goal" and not line.complete)
	row.here:SetShown(kind == "goal" and not line.complete)
	row.shade:SetShown(style.shade == true and kind == "goal")
	row.rule:SetShown(style.rules == true and kind == "goal" and n > 1)
	if row.slip then
		row.slip:SetShown(style.slips == true and kind == "goal")
		row.tack:SetShown(style.slips == true and kind == "goal")
	end
	text:SetText(kind == "header" and style.caps and line.text:upper() or line.text)
	if kind == "header" then
		local height = last and style.header + HEADER_HEIGHT or style.top
		ns.SetArtFont(text, style.title)
		local headerY = style.header
		ns.PlaceSprite(row.flame, row, 0, headerY + 6)
		text:SetPoint("TOPLEFT", 18, -(headerY + (style.caps and 6 or 4)))
		ns.SetArtFont(right, style.headRight)
		right:SetPoint("TOPRIGHT", row, "TOPLEFT", width - 26, -(headerY + 5))
		right:SetText(line.right or "")
		right:SetShown(line.right ~= nil)
		ns.PlaceSprite(row.chevron, row, width - 9, headerY + 9)
		pointChevron(row.chevron, line.collapsed == true)
		return height
	elseif kind == "goal" then
		ns.SetArtFont(text, style.goal)
		ns.SetArtFont(right, style.count)
		right:SetText(line.count)
		right:Show()
		right:SetPoint("TOPRIGHT", row, "TOPLEFT", width, -(style.textY - 2))
		text:SetPoint("TOPLEFT", 0, -style.textY)
		text:SetWidth(width - right:GetStringWidth() - 6)
		if line.complete then
			ns.Ink(text, style.complete)
			ns.Ink(right, style.complete)
		else
			local where, here = splitHere(line.where or "")
			ns.SetArtFont(row.sub, style.where)
			ns.SetArtFont(row.here, style.where)
			ns.Ink(row.here, style.here)
			row.sub:ClearAllPoints()
			row.sub:SetPoint("TOPLEFT", style.whereX, -style.whereY)
			row.sub:SetText(where)
			row.here:SetText(here)
			row.here:SetShown(here ~= "")
		end
		if style.shade then
			row.shade:SetColorTexture(
				line.complete and 0.24 or 0,
				line.complete and 0.63 or 0,
				line.complete and 0.24 or 0,
				line.complete and 0.4 or 0.3
			)
			row.shade:ClearAllPoints()
			row.shade:SetPoint("TOPLEFT", -style.left, 0)
			row.shade:SetSize(width + style.left + style.right, style.step)
		end
		if style.rules then
			row.rule:SetColorTexture(1, 0.94, 0.82, 0.12)
			row.rule:ClearAllPoints()
			row.rule:SetPoint("TOPLEFT", 14 - style.left, 0)
			row.rule:SetSize(width + style.left + style.right - 28, 1)
		end
		if style.slips then
			local slip = row.slip --[[@as TackleSprite]]
			ns.SetSprite(slip, "Tracker", line.complete and "trk-slip-done" or "trk-slip")
			ns.SizeSprite(slip, width + 18)
			ns.LeanSprite(slip, row, -9, 0, SLIP_LEANS[(n - 1) % #SLIP_LEANS + 1])
			ns.PlaceSprite(row.tack --[[@as TackleSprite]], row, (width + 18) / 2 - 9 - 4.5, -4)
		end
		return style.step
	end
	ns.SetArtFont(text, style.more)
	text:SetPoint("TOPLEFT", style.moreX, -style.moreY)
	text:SetWidth(width)
	right:Hide()
	return LINE_HEIGHT
end

--- A new, empty tracker block on `parent`, ns.TRACKER_WIDTH wide, with no frame.
---@param parent Frame
---@return TackleTrackerBlock
function ns.NewTrackerBlock(parent)
	local block = CreateFrame("Frame", nil, parent) --[[@as TackleTrackerBlock]]
	block:SetSize(ns.TRACKER_WIDTH, 1)
	block.rows = {}
	block.lines = {}
	block.style = ns.TRACKER_STYLES.none

	-- Draws the block's lines in its style, its frame round them, and returns its height.
	local function draw()
		local style = block.style
		local lines = block.lines
		local y, goals = 0, 0
		for i, line in ipairs(lines) do
			local row = block.rows[i]
			if not row then
				row = newRow(block)
				block.rows[i] = row
			end
			if style.slips and not row.slip then
				row.slip = ns.ArtSprite(row, "Tracker", "trk-slip", "BACKGROUND", 1)
				row.tack = ns.ArtSprite(row, "Marks", "tack-s", "ARTWORK", 3)
			end
			if line.kind == "goal" then
				goals = goals + 1
			end
			local height = layOut(row, line, style, goals, #lines == 1)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 0, -y)
			row:SetSize(ns.TRACKER_WIDTH, height)
			row:Show()
			y = y + height
		end
		for i = #lines + 1, #block.rows do
			block.rows[i]:Hide()
		end
		local height = y + (#lines > 1 and style.pad or 0)
		block:SetHeight(math.max(height, 1))
		if style.frame then
			if not block.frame then
				block.frame = CreateFrame("Frame", nil, block) --[[@as TackleVSlice]]
				block.frame:SetFrameLevel(block:GetFrameLevel())
			end
			local frame = block.frame --[[@as TackleVSlice]]
			ns.SetVSlice(frame, "Tracker", style.frame, ns.TRACKER_WIDTH + style.left + style.right, height, 30, 20)
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", -style.left, 0)
			frame:Show()
		elseif block.frame then
			block.frame:Hide()
		end
		return height
	end

	function block.SetLines(_, lines)
		block.lines = lines
		return draw()
	end

	function block.SetFrame(_, style)
		block.style = style or ns.TRACKER_STYLES.none
		draw()
	end

	return block
end
