if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The Pagle Wagers spread's art (HNT-R162, HNT-R163, HNT-R166, HNT-R167), the Wagers redesign's variant A: its inks and
-- the pieces its two pages share, the event mark and the time dial, over the Wagers atlas (adapter/BookAtlas.lua). The
-- kit's sources are data/art/wagers/: art.json has every ink, colour, sprite and part's place, in UI units, and the
-- files that draw the pages (adapter/WagersSpread.lua, adapter/WagersEntry.lua) take their measures from it.
--
-- An ink is a face of adapter/BookArt.lua at a size, in one of BOARD_LOOK's tints, and its line's height. `caps` sets
-- its words in capitals at 0.84 of its size, standing in for the canvas's small capitals, which the client doesn't have;
-- `upper` in capitals at full size. A text's place is its line's top: the font string, its size high, sits half the
-- line's leading below it.

local LOOK = ns.BOARD_LOOK

--- One of the kit's inks (art.json › inks).
---@class WagerInk
---@field face HuntsArtFace
---@field size number
---@field color string        -- a BOARD_LOOK tint's name
---@field lineHeight number?  -- its line's height: 1.2 times its size when not given
---@field caps boolean?
---@field upper boolean?

---@type table<string, WagerInk>
ns.WAGER_INKS = {
	kicker = { face = "print", size = 14, color = "kicker", caps = true },
	title = { face = "print", size = 27, color = "title", lineHeight = 28.35 },
	margin = { face = "handSemi", size = 18, color = "red", lineHeight = 18.9 },
	note = { face = "italic", size = 13.5, color = "count", lineHeight = 17.55 },
	secLabel = { face = "print", size = 13, color = "oxblood", caps = true },
	secLabelAhead = { face = "print", size = 13, color = "legend", caps = true },
	secCount = { face = "handSemi", size = 16, color = "oxblood", lineHeight = 16 },
	secCountAhead = { face = "handSemi", size = 16, color = "legend", lineHeight = 16 },
	secCaption = { face = "italic", size = 11.5, color = "note" },
	dialText = { face = "gilt", size = 10, color = "ink" },
	dialTextUrgent = { face = "gilt", size = 10, color = "nowLine" },
	tkName = { face = "print", size = 16.5, color = "title", lineHeight = 18.15 },
	tkLine = { face = "italic", size = 12.5, color = "small", lineHeight = 15 },
	need = { face = "hand", size = 14, color = "pencil" },
	tkMarks = { face = "print", size = 12, color = "small", lineHeight = 12 },
	tag = { face = "gilt", size = 9.5, color = "tagText", upper = true },
	ahName = { face = "print", size = 14, color = "title", lineHeight = 14.7 },
	ahZones = { face = "italic", size = 12, color = "legend", lineHeight = 14.4 },
	ahOpens = { face = "handSemi", size = 15, color = "group", lineHeight = 15 },
	ahFor = { face = "italic", size = 11.5, color = "note", lineHeight = 14.95 },
	hint = { face = "hand", size = 17, color = "hand", lineHeight = 18.7 },
	hintSmall = { face = "italic", size = 12, color = "count", lineHeight = 15.6 },
	empty = { face = "hand", size = 19, color = "hand", lineHeight = 21.85 },
	ladLabel = { face = "print", size = 13, color = "kicker", caps = true },
	ladCount = { face = "handSemi", size = 17, color = "red" },
	ladLine = { face = "print", size = 12.5, color = "small", lineHeight = 17.5 },
	ladTitle = { face = "italic", size = 12.5, color = "setName" },
	postNum = { face = "gilt", size = 10.5, color = "group" },
	postNumGot = { face = "gilt", size = 10.5, color = "clock" },
	postTitle = { face = "italic", size = 11.5, color = "legend", lineHeight = 12.65 },
	src = { face = "print", size = 12.5, color = "kicker", caps = true },
	evName = { face = "print", size = 23, color = "title", lineHeight = 23.92 },
	timeHand = { face = "hand", size = 21, color = "red", lineHeight = 22.68 },
	timeHandAhead = { face = "hand", size = 21, color = "hand", lineHeight = 22.68 },
	timeSmall = { face = "print", size = 12.5, color = "small", lineHeight = 16.9 },
	chip = { face = "print", size = 12.5, color = "chipText" },
	chipHere = { face = "hand", size = 15, color = "here" },
	chipPencil = { face = "italic", size = 12.5, color = "pencil" },
	chipHoliday = { face = "gilt", size = 11, color = "tagText", upper = true },
	evNote = { face = "hand", size = 16.5, color = "hand", lineHeight = 17.33 },
	evNoteTight = { face = "hand", size = 15, color = "hand", lineHeight = 15.75 },
	huntName = { face = "print", size = 14.5, color = "title", lineHeight = 16 },
	huntCount = { face = "handSemi", size = 16, color = "hand", lineHeight = 16 },
	huntNext = { face = "handSemi", size = 16, color = "group", lineHeight = 16 },
	huntLine = { face = "print", size = 11.5, color = "legend", lineHeight = 13.8 },
	window = { face = "italic", size = 11.5, color = "note", lineHeight = 13.8 },
	windowOpen = { face = "italic", size = 11.5, color = "here", lineHeight = 13.8 },
	updating = { face = "hand", size = 16, color = "note", lineHeight = 19.2 },
	casts = { face = "italic", size = 12, color = "legend", lineHeight = 14.4 },
	payLabel = { face = "print", size = 11, color = "kicker", caps = true },
	payAmount = { face = "handSemi", size = 16, color = "red" },
	payRefresh = { face = "handSemi", size = 13, color = "red" },
	payRule = { face = "italic", size = 10.5, color = "note", lineHeight = 13.13 },
	sealWord = { face = "print", size = 9, color = "sealText", caps = true },
	sealDate = { face = "gilt", size = 11.5, color = "sealText" },
	emptyTitle = { face = "print", size = 24, color = "title", lineHeight = 25.2 },
	emptyHand = { face = "hand", size = 20, color = "hand", lineHeight = 21.6 },
	more = { face = "handSemi", size = 15, color = "group", lineHeight = 20 },
}
local INKS = ns.WAGER_INKS

-- An ink by name, or an error naming it.
---@param name string
---@return WagerInk
local function inkOf(name)
	return assert(INKS[name], "the Pagle Wagers kit has no ink " .. tostring(name))
end

--- An ink's line height.
---@param name string
---@return number
function ns.WagerLineHeight(name)
	local ink = inkOf(name)
	return ink.lineHeight or ink.size * 1.2
end

--- A font string with its words in the kit's ink `name`, as ns.SetWagerInk sets it.
---@class WagerText: FontString
---@field ink string
---@field words string?   -- its words as given, before capitals

--- Sets `text` in ink `name`: its face and size (capitals at 0.84 of it), its tint, and its leading when it wraps.
---@param text FontString
---@param name string
---@return WagerText
function ns.SetWagerInk(text, name)
	local ink = inkOf(name)
	local shown = text --[[@as WagerText]]
	shown:SetFontObject(ns.ArtFont(ink.face, ink.caps and ink.size * 0.84 or ink.size))
	local color = LOOK[ink.color]
	shown:SetTextColor(color[1], color[2], color[3])
	shown:SetSpacing(math.max(0, ns.WagerLineHeight(name) - ink.size))
	shown.ink = name
	if shown.words then
		shown:SetText((ink.caps or ink.upper) and shown.words:upper() or shown.words)
	end
	return shown
end

--- A one-line font string on `parent` in ink `name`.
---@param parent Frame
---@param name string
---@return WagerText
function ns.NewWagerText(parent, name)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetJustifyH("LEFT")
	text:SetWordWrap(false)
	return ns.SetWagerInk(text, name)
end

--- Sets `text`'s words, in capitals when its ink says so.
---@param text WagerText
---@param words string
function ns.SetWagerWords(text, words)
	local ink = inkOf(text.ink)
	text.words = words
	text:SetText((ink.caps or ink.upper) and words:upper() or words)
end

--- Puts `text` with its line's top `y` down from `relative`'s top and its left `x` in (or, with `right`, its right `x`
--- in from `relative`'s right), its font string half its line's leading below that top; shows it.
---@param text WagerText
---@param relative Region
---@param x number
---@param y number
---@param right boolean?
function ns.PlaceWagerText(text, relative, x, y, right)
	local ink = inkOf(text.ink)
	local top = y + (ns.WagerLineHeight(text.ink) - ink.size) / 2
	text:ClearAllPoints()
	if right then
		text:SetJustifyH("RIGHT")
		text:SetPoint("TOPRIGHT", relative, "TOPRIGHT", -x, -top)
	else
		text:SetPoint("TOPLEFT", relative, "TOPLEFT", x, -top)
	end
	text:Show()
end

--- Sets `text` to `words` and keeps it within `room`, cut short with an ellipsis past it; returns the width it takes.
---@param text WagerText
---@param words string
---@param room number
---@return number
function ns.FitWagerText(text, words, room)
	ns.SetWagerWords(text, words)
	text:SetWidth(0)
	local width = math.max(1, math.min(math.ceil(text:GetStringWidth()) + 1, math.max(1, room)))
	text:SetWidth(width)
	return width
end

--- A texture showing a Wagers sprite; ns.SetSprite and ns.PlaceSprite (adapter/BookArt.lua) size and put it.
---@param parent Frame
---@param name string
---@param size number?
---@param layer DrawLayer?
---@param sublevel integer?
---@return HuntsSpriteTexture
function ns.WagerSprite(parent, name, size, layer, sublevel)
	return ns.ArtSprite(parent, "Wagers", name, layer or "ARTWORK", sublevel or 0, size)
end

--- Tints a texture with one of BOARD_LOOK's tints, its fourth value (or `alpha`) its alpha.
---@param texture Texture
---@param color number[]
---@param alpha number?
function ns.TintWager(texture, color, alpha)
	texture:SetVertexColor(color[1], color[2], color[3], alpha or color[4] or 1)
end

--- Fills a texture with one of BOARD_LOOK's tints, its fourth value its alpha.
---@param texture Texture
---@param color number[]
function ns.FillWager(texture, color)
	texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
end

-- The event mark -----------------------------------------------------------------------------------------------------

-- The mark's box, and its charm's box and centre in it (art.json › mark), in mark units.
local MARK_BOX, CHARM_BOX, CHARM_AT = 64, 22, 46

--- The event mark (HNT-R166): its layers stacked in a `size` box, each drawn at size / 64 of its own.
---@class WagerMarkView: Frame
---@field layers HuntsSpriteTexture[]
---@field names string[]
---@field size number
---@field SetMark fun(self: WagerMarkView, layers: string[], faded: boolean?)

--- An event mark on `parent`, `size` across.
---@param parent Frame
---@param size number
---@return WagerMarkView
function ns.NewEventMark(parent, size)
	local mark = CreateFrame("Frame", nil, parent) --[[@as WagerMarkView]]
	mark:SetSize(size, size)
	mark.layers, mark.names, mark.size = {}, {}, size
	function mark.SetMark(self, layers, faded)
		local k = self.size / MARK_BOX
		for i, name in ipairs(layers) do
			local texture = self.layers[i] or ns.WagerSprite(self, name, nil, "ARTWORK", math.min(7, i))
			self.layers[i] = texture
			local charm = name:find("^mark%-charm%-") ~= nil
			ns.SetSprite(texture, "Wagers", name, (charm and CHARM_BOX or MARK_BOX) * k)
			if charm then
				ns.PlaceSprite(texture, self, (CHARM_AT - CHARM_BOX / 2) * k, (CHARM_AT - CHARM_BOX / 2) * k)
			else
				ns.PlaceSprite(texture, self, 0, 0)
			end
			texture:SetDesaturated(faded == true)
			texture:Show()
		end
		for i = #layers + 1, #self.layers do
			self.layers[i]:Hide()
		end
		self.names = layers
		self:SetAlpha(faded and 0.75 or 1)
	end
	return mark
end

-- The time dial ------------------------------------------------------------------------------------------------------

--- The time dial (HNT-R167): its face, and its fill at the step the run's share left gives, tinted by its state; the
--- dashed face of a run ahead. It steps at each draw and never moves on its own.
---@class WagerDialView: Frame
---@field face HuntsSpriteTexture
---@field fill HuntsSpriteTexture
---@field kind ("on"|"settled"|"closed"|"ahead")?
---@field step integer?
---@field ink number[]?
---@field SetDial fun(self: WagerDialView, dial: WagerDial)

--- A time dial on `parent`, `size` across.
---@param parent Frame
---@param size number
---@return WagerDialView
function ns.NewWagerDial(parent, size)
	local dial = CreateFrame("Frame", nil, parent) --[[@as WagerDialView]]
	dial:SetSize(size, size)
	dial.face = ns.WagerSprite(dial, "dial-face", size, "ARTWORK", 0)
	dial.fill = ns.WagerSprite(dial, "dial-fill-01", size, "ARTWORK", 1)
	function dial.SetDial(self, data)
		ns.SetSprite(self.face, "Wagers", data.kind == "ahead" and "dial-ahead" or "dial-face", size)
		ns.PlaceSprite(self.face, self, 0, 0)
		self.kind, self.step = data.kind, data.step
		if data.step and (data.kind == "on" or data.kind == "settled") then
			ns.SetSprite(self.fill, "Wagers", ("dial-fill-%02d"):format(data.step), size)
			ns.PlaceSprite(self.fill, self, 0, 0)
			self.ink = data.kind == "settled" and LOOK.spent or data.urgent and LOOK.nowLine or LOOK.oxblood
			ns.TintWager(self.fill, self.ink)
			self.fill:Show()
		else
			self.ink = nil
			self.fill:Hide()
		end
	end
	return dial
end
