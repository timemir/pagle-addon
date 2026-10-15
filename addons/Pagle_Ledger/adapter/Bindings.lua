if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Journal bindings on the client (LED-R110–R112): the slot and goods registered with Core, the closed-book swatch
-- each good draws on the Curio Shop's preview stage, the equipped crest's icon for the bookplate, and the Journal's
-- redraw when either look changes.

-- The bus owner of the Journal's look (CORE-R23).
local OWNER = "Pagle_Ledger Journal look"

-- Core's crest slot (SHOP-R25): the Angler's emblem, drawn on the bookplate (LED-R112).
local CREST_SLOT = "core.crest"
-- Its default, Plain, which draws no emblem (SHOP-R25). Pagle's API doesn't say which good is a slot's default, so
-- the Ledger names it, as it names the slot.
local DEFAULT_CREST = "core.crest.plain"

-- The closed book's place on the stage: down from its top, as Core's crest bookplate sits (adapter/CoreGoods.lua).
local SWATCH_TOP = 16

--- A closed-book swatch (LED-R110): the kit's swatch of the binding, a closed book with its gilt rules and brass
--- plate, no pages.
---@class LedgerBindingSwatch: Frame
---@field book LedgerSpriteTexture

-- One swatch per stage, made on its first preview: the shop shows one good at a time.
---@type table<Frame, LedgerBindingSwatch>
local swatches = setmetatable({}, { __mode = "k" })

-- Builds a stage's swatch, the book's box centred at the stage's top.
---@param stage Frame
---@return LedgerBindingSwatch
local function buildSwatch(stage)
	local swatch = CreateFrame("Frame", nil, stage) --[[@as LedgerBindingSwatch]]
	local sprite = ns.JOURNAL_ATLASES.Bindings.sprites["binding-field-leather"]
	swatch:SetSize(sprite.box[3], sprite.box[4])
	swatch:SetPoint("TOP", 0, -SWATCH_TOP)
	swatch.book = ns.JournalSprite(swatch, "Bindings", "binding-field-leather", "ARTWORK")
	ns.JournalPut(swatch.book, swatch, 0, 0)
	return swatch
end

--- Draws binding `look`'s closed book on the Curio Shop's preview stage (LED-R110): one swatch per stage, re-pointed
--- at the binding's and shown at each call. The shop hides what another good drew there.
---@param stage Frame
---@param look LedgerBindingLook
---@return LedgerBindingSwatch
function ns.DrawBindingSwatch(stage, look)
	local swatch = swatches[stage]
	if not swatch then
		swatch = buildSwatch(stage)
		swatches[stage] = swatch
	end
	ns.JournalSetSprite(swatch.book, "Bindings", look.swatch)
	swatch:Show()
	return swatch
end

--- The equipped crest's icon (LED-R112, SHOP-R25), to draw on the Angler page's bookplate: the icon Core cached for
--- `Pagle.GetEquipped("core.crest")` (Pagle.GetGood); nil for the slot's default, Plain ("No emblem, only the owner's
--- name"), and while the slot or its icon is missing.
---@return (integer|string)?
function ns.CrestIcon()
	local crest = Pagle.GetEquipped(CREST_SLOT)
	if crest == DEFAULT_CREST then
		return nil
	end
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
			-- The state even mid-update: Core asks only at registration, before any update, and after a live entry
			-- or a done (SHOP-R31).
			local projection = ns.projection
			local state = projection and projection:GetState() --[[@as LedgerState?]]
			return ns.LevelBindingEarned(level, state, ns.SavedCelebrated())
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
