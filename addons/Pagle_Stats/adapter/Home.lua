if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The home spread on the Stats book (stats.md › UI › Home spread): the page the book opens on. Its left page, Where
-- I've fished, tiles each zone I've fished; its right page, Right now, writes in handwriting where I am, my skill, the
-- Session, my watched Dry spells and the book's contents. The lines are logic/Home.lua's; this file lays them out in
-- adapter/BookWidgets.lua's art, after prototypes/stats-window/ variant D. The book redraws the spread on its tick and
-- its redraw events (STA-R73), and never while the projection updates (STA-R72).

local L = ns.L
local LOOK = ns.BOOK_LOOK

-- Variant D's measures: the gaps between a page's parts, a link's height and the watches' pencil mark.
local KICKER_GAP, TITLE_GAP, PARA_GAP, GROUP_GAP = 18, 30, 8, 14
local LINK_HEIGHT, MARK_SIZE, MARK_INDENT = 20, 14, 20

---@class StatsHomeWatersView
---@field kicker FontString
---@field title FontString
---@field intro FontString
---@field empty FontString
---@field grid StatsBookTileGridView

---@class StatsHomeWatchView: Button
---@field mark Texture
---@field label FontString

---@class StatsHomeRightNowView
---@field kicker FontString
---@field where FontString
---@field session FontString
---@field watched StatsBookHeadingView
---@field watches StatsHomeWatchView[]
---@field noWatches FontString
---@field contents StatsBookHeadingView
---@field links StatsBookFigureView[]

---@class StatsHomeContent: Frame
---@field waters StatsHomeWatersView?
---@field rightNow StatsHomeRightNowView?

-- The watches, oldest first (STA-R60).
---@return StatsWatch[]
local function watched()
	return ns.db and ns.db.profile.watched or {}
end

-- `text` with `part` of it written in red ink: the band of a watched Dry spell (", unlucky").
---@param text string
---@param part string?
---@return string
local function withRed(text, part)
	if not part then
		return text
	end
	local from, to = text:find(part, 1, true)
	if not from then
		return text
	end
	local red = LOOK.red
	local code = ("|cff%02x%02x%02x"):format(
		math.floor(red[1] * 255 + 0.5),
		math.floor(red[2] * 255 + 0.5),
		math.floor(red[3] * 255 + 0.5)
	)
	return text:sub(1, from - 1) .. code .. part .. "|r" .. text:sub(to + 1)
end

-- Sets a font string's tint.
---@param text FontString
---@param color number[]
local function tintText(text, color)
	text:SetTextColor(color[1], color[2], color[3])
end

-- Puts `region` at the top left of `content`, `y` pixels down.
---@param region Region
---@param content Frame
---@param y number
local function at(region, content, y)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
end

---@param content StatsHomeContent
---@return StatsHomeWatersView
local function buildWaters(content)
	local width = content:GetWidth()
	local view = {
		kicker = ns.NewBookKicker(content),
		title = ns.NewBookTitle(content),
		intro = ns.BookText(content, ns.BookFonts().small, LOOK.small),
		empty = ns.NewBookHand(content),
		grid = ns.NewBookTileGrid(content),
	}
	view.kicker:SetText(L.HOME_KICKER)
	view.title:SetText(L.HOME_TITLE)
	view.intro:SetText(L.HOME_INTRO)
	view.intro:SetWordWrap(true)
	for _, text in ipairs({ view.kicker, view.title, view.intro, view.empty }) do
		text:SetWidth(width)
	end
	content.waters = view
	return view
end

--- The left page, Where I've fished: its kicker, title and line, then a tile per zone, two a row, each opening its
--- place page; with no Casts, "Not fished anywhere yet." (STA-R97).
---@param content StatsHomeContent
---@return number height
local function drawWaters(content)
	local view = content.waters or buildWaters(content)
	local data = ns.HomeWaters(ns.State(), Pagle.GetConditions(), watched(), ns.places)
	at(view.kicker, content, 0)
	at(view.title, content, KICKER_GAP)
	at(view.intro, content, KICKER_GAP + TITLE_GAP)
	local y = KICKER_GAP + TITLE_GAP + view.intro:GetStringHeight() + GROUP_GAP
	view.empty:SetText(data.empty or "")
	view.empty:SetShown(data.empty ~= nil)
	at(view.empty, content, y)
	local height = view.grid:SetTiles(data.tiles, y)
	return y + (height > 0 and height or view.empty:GetStringHeight())
end

---@param content StatsHomeContent
---@return StatsHomeRightNowView
local function buildRightNow(content)
	local width = content:GetWidth()
	local view = {
		kicker = ns.NewBookKicker(content),
		where = ns.NewBookHand(content),
		session = ns.NewBookHand(content),
		watched = ns.NewBookHeading(content, width),
		watches = {},
		noWatches = ns.BookText(content, ns.BookFonts().note, LOOK.note),
		contents = ns.NewBookHeading(content, width),
		links = {},
	}
	view.kicker:SetText(L.HOME_RIGHT_NOW)
	view.watched:SetHeading(L.HOME_WATCHED, L.HOME_WATCHED_NOTE)
	view.contents:SetHeading(L.HOME_CONTENTS)
	view.noWatches:SetWordWrap(true)
	for _, text in ipairs({ view.kicker, view.where, view.session, view.noWatches }) do
		text:SetWidth(width)
	end
	content.rightNow = view
	return view
end

-- Watch line `i`, made on first use: the pencil mark, then its words in handwriting, red under the mouse.
---@param content StatsHomeContent
---@param view StatsHomeRightNowView
---@param i integer
---@return StatsHomeWatchView
local function watchAt(content, view, i)
	local line = view.watches[i]
	if not line then
		line = CreateFrame("Button", nil, content) --[[@as StatsHomeWatchView]]
		line:SetWidth(content:GetWidth())
		line.mark = ns.NewBookMark(line, "pencil", MARK_SIZE)
		line.mark:SetPoint("TOPLEFT", 0, -2)
		line.label = ns.NewBookHand(line)
		line.label:SetPoint("TOPLEFT", MARK_INDENT, 0)
		line.label:SetWidth(content:GetWidth() - MARK_INDENT)
		line:SetScript("OnEnter", function(self)
			tintText(self.label, LOOK.red)
		end)
		line:SetScript("OnLeave", function(self)
			tintText(self.label, LOOK.hand)
		end)
		view.watches[i] = line
	end
	return line
end

-- In this book's link `i`, made on first use: a figure line (ns.NewBookFigure), as a table of contents.
---@param content StatsHomeContent
---@param view StatsHomeRightNowView
---@param i integer
---@return StatsBookFigureView
local function linkAt(content, view, i)
	local link = view.links[i]
	if not link then
		link = ns.NewBookFigure(content, content:GetWidth(), LINK_HEIGHT)
		view.links[i] = link
	end
	return link
end

--- The right page, Right now: where I am and my skill, the Session, then *Dry spells I'm watching*, each line opening
--- its entry, and *In this book*, each link opening its page. A watched item the client hasn't loaded is asked for,
--- and the spread redraws when it arrives (STA-R73).
---@param content StatsHomeContent
---@return number height
local function drawRightNow(content)
	local view = content.rightNow or buildRightNow(content)
	local data =
		ns.HomeRightNow(ns.State(), Pagle.GetConditions(), Pagle.GetSession(), watched(), GetServerTime(), ns.places)
	for _, itemID in ipairs(data.pending) do
		ns.book:RequestItem(itemID)
	end
	at(view.kicker, content, 0)
	view.where:SetText(data.skill and (data.where .. " " .. data.skill) or data.where)
	at(view.where, content, KICKER_GAP)
	local y = KICKER_GAP + view.where:GetStringHeight() + PARA_GAP
	view.session:SetText(data.session)
	at(view.session, content, y)
	y = y + view.session:GetStringHeight() + GROUP_GAP

	at(view.watched, content, y)
	y = y + view.watched:GetHeight() + 4
	for i, watch in ipairs(data.watches) do
		local line = watchAt(content, view, i)
		line.label:SetText(withRed(watch.text, watch.red))
		tintText(line.label, LOOK.hand)
		local height = math.max(line.label:GetStringHeight(), MARK_SIZE + 2)
		line:SetHeight(height)
		local target = watch.target
		line:SetScript("OnClick", function()
			ns.OpenBook(target)
		end)
		at(line, content, y)
		line:Show()
		y = y + height + 4
	end
	for i = #data.watches + 1, #view.watches do
		view.watches[i]:Hide()
	end
	view.noWatches:SetText(data.noWatches or "")
	view.noWatches:SetShown(data.noWatches ~= nil)
	if data.noWatches then
		at(view.noWatches, content, y)
		y = y + view.noWatches:GetStringHeight() + 4
	end

	y = y + GROUP_GAP
	at(view.contents, content, y)
	y = y + view.contents:GetHeight() + 2
	for i, entry in ipairs(data.contents) do
		local link = linkAt(content, view, i)
		local target = entry.target
		link:SetFigure({
			label = entry.label,
			value = entry.value,
			onClick = function()
				ns.OpenBook(target)
			end,
		})
		at(link, content, y)
		link:Show()
		y = y + LINK_HEIGHT
	end
	for i = #data.contents + 1, #view.links do
		view.links[i]:Hide()
	end
	return y
end

ns.book:RegisterPage("home", "left", drawWaters)
ns.book:RegisterPage("home", "right", drawRightNow)
