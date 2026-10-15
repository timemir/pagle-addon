if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Journal bindings on the client (LED-R110–R112): the slot and goods registered with Core, the closed-book swatch
-- each good draws on the Curio Shop's preview stage, the equipped crest's icon for the bookplate, and the Journal's
-- redraw when either look changes.

local LOOK = ns.JOURNAL_LOOK

-- The bus owner of the Journal's look (CORE-R23).
local OWNER = "Pagle_Ledger Journal look"

-- Core's crest slot (SHOP-R25): the Angler's emblem, drawn on the bookplate (LED-R112).
local CREST_SLOT = "core.crest"

-- The closed book on the stage, as the prototype's swatch: its size, the spine's shadow, the gilt rules' inset from
-- the edges (more at the spine), and the brass plate's size and place up from its foot.
local SWATCH_WIDTH, SWATCH_HEIGHT = 110, 140
local SWATCH_SPINE = 8
local RULE_INSET, RULE_SPINE_INSET = 10, 18
local PLATE_WIDTH, PLATE_HEIGHT, PLATE_FOOT = 46, 14, 24

--- A closed-book swatch (LED-R110): the leather in its tint and grain, the gilt rules and the brass plate, no pages.
---@class LedgerBindingSwatch: Frame
---@field leather Texture
---@field grain Texture
---@field rules Texture[]
---@field plateEdge Texture
---@field plate Texture

-- One swatch per stage, made on its first preview: the shop shows one good at a time.
---@type table<Frame, LedgerBindingSwatch>
local swatches = setmetatable({}, { __mode = "k" })

-- A 1-pixel line on `frame` from point `from` offset by `fromX`, `fromY` to point `to` offset by `toX`, `toY`.
---@param frame Frame
---@param from FramePoint
---@param fromX number
---@param fromY number
---@param to FramePoint
---@param toX number
---@param toY number
---@return Texture
local function line(frame, from, fromX, fromY, to, toX, toY)
	local texture = frame:CreateTexture(nil, "ARTWORK")
	texture:SetPoint(from, fromX, fromY)
	texture:SetPoint(to, toX, toY)
	if fromX == toX then
		texture:SetWidth(1)
	else
		texture:SetHeight(1)
	end
	return texture
end

-- Builds a stage's swatch, at its top as Core's crest bookplate sits (adapter/CoreGoods.lua).
---@param stage Frame
---@return LedgerBindingSwatch
local function buildSwatch(stage)
	local swatch = CreateFrame("Frame", nil, stage) --[[@as LedgerBindingSwatch]]
	swatch:SetSize(SWATCH_WIDTH, SWATCH_HEIGHT)
	swatch:SetPoint("TOP", 0, -16)
	ns.JournalSolid(swatch, LOOK.leatherEdge, "BACKGROUND")
	swatch.leather = ns.JournalSolid(swatch, LOOK.leather, "BACKGROUND")
	swatch.leather:SetPoint("TOPLEFT", 1, -1)
	swatch.leather:SetPoint("BOTTOMRIGHT", -1, 1)
	swatch.grain = swatch:CreateTexture(nil, "BORDER")
	swatch.grain:SetTexture(ns.JOURNAL_TEXTURES.leather)
	swatch.grain:SetAlpha(0.5)
	swatch.grain:SetPoint("TOPLEFT", 1, -1)
	swatch.grain:SetPoint("BOTTOMRIGHT", -1, 1)
	local spine = swatch:CreateTexture(nil, "BORDER")
	spine:SetColorTexture(0, 0, 0, 0.35)
	spine:SetPoint("TOPLEFT", 1, -1)
	spine:SetPoint("BOTTOMLEFT", 1, 1)
	spine:SetWidth(SWATCH_SPINE)
	-- The gilt rules: a rectangle inset from the edges, further in at the spine.
	local left, inset = RULE_SPINE_INSET, RULE_INSET
	swatch.rules = {
		line(swatch, "TOPLEFT", left, -inset, "TOPRIGHT", -inset, -inset),
		line(swatch, "BOTTOMLEFT", left, inset, "BOTTOMRIGHT", -inset, inset),
		line(swatch, "TOPLEFT", left, -inset, "BOTTOMLEFT", left, inset),
		line(swatch, "TOPRIGHT", -inset, -inset, "BOTTOMRIGHT", -inset, inset),
	}
	swatch.plateEdge = swatch:CreateTexture(nil, "ARTWORK")
	ns.JournalPaint(swatch.plateEdge, LOOK.leatherEdge)
	swatch.plateEdge:SetSize(PLATE_WIDTH, PLATE_HEIGHT)
	swatch.plateEdge:SetPoint("BOTTOM", (RULE_SPINE_INSET - RULE_INSET) / 2, PLATE_FOOT)
	swatch.plate = swatch:CreateTexture(nil, "OVERLAY")
	swatch.plate:SetPoint("TOPLEFT", swatch.plateEdge, "TOPLEFT", 1, -1)
	swatch.plate:SetPoint("BOTTOMRIGHT", swatch.plateEdge, "BOTTOMRIGHT", -1, 1)
	return swatch
end

--- Draws binding `look`'s closed book on the Curio Shop's preview stage (LED-R110): one swatch per stage, tinted
--- afresh and shown at each call. The shop hides what another good drew there.
---@param stage Frame
---@param look LedgerBindingLook
---@return LedgerBindingSwatch
function ns.DrawBindingSwatch(stage, look)
	local swatch = swatches[stage]
	if not swatch then
		swatch = buildSwatch(stage)
		swatches[stage] = swatch
	end
	ns.JournalPaint(swatch.leather, look.leather)
	swatch.grain:SetVertexColor(unpack(look.leather))
	for _, rule in ipairs(swatch.rules) do
		ns.JournalPaint(rule, look.gilt, 0.85)
	end
	ns.JournalPaint(swatch.plate, look.plate)
	swatch:Show()
	return swatch
end

--- The equipped crest's icon (LED-R112, SHOP-R25), to draw on the Angler page's bookplate: the icon Core cached for
--- `Pagle.GetEquipped("core.crest")` (Pagle.GetGood), or nil while the slot or its icon is missing.
---@return (integer|string)?
function ns.CrestIcon()
	local crest = Pagle.GetEquipped(CREST_SLOT)
	local good = crest and Pagle.GetGood(crest)
	return good and good.icon
end

--- Registers the Ledger's slot and its goods (LED-R110, SHOP-R21), from OnInitialize after RegisterModule, and
--- redraws the open Journal whenever the equipped binding or crest changes (LED-R112, SHOP-R33). A level binding is
--- earned from the projection's state and the celebrated set as they stand when Core asks (LED-R111, SHOP-R31).
---@param module PagleModuleHandle
function ns.RegisterBindings(module)
	module:RegisterSlot(ns.BindingSlot())
	local goods = ns.BindingGoods({
		earned = function(level)
			local projection = ns.projection
			local state = projection and projection:GetState() --[[@as LedgerState?]]
			-- Read as saved: asking makes none of the celebrated set's keys (LED-R90).
			return ns.LevelBindingEarned(level, state, ns.db.global.celebrated or {})
		end,
		preview = ns.DrawBindingSwatch,
	})
	for _, good in ipairs(goods) do
		module:RegisterGood(good)
	end
	Pagle.RegisterCallback(OWNER, "AppearanceChanged", function(_, slot)
		if slot == ns.BINDING_SLOT or slot == CREST_SLOT then
			ns.journal:Draw()
		end
	end)
end
