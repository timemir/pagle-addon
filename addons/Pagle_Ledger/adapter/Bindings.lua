if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Journal bindings on the client (LED-R110–R112): the slot and goods registered with Core, the closed-book swatch
-- each good draws on the Curio Shop's preview stage, the zone crests registered in Core's crest slot (LED-R113–R115),
-- the equipped crest's icon for the bookplate, and the Journal's redraw when either look changes.

-- The bus owner of the Journal's look (CORE-R23).
local OWNER = "Pagle_Ledger Journal look"

-- Core's crest slot (SHOP-R25, ns.CREST_SLOT): the Angler's emblem, drawn on the bookplate (LED-R112).
local CREST_SLOT = ns.CREST_SLOT
-- Its default, Plain, which draws no emblem (SHOP-R25). Pagle's API doesn't say which good is a slot's default, so
-- the Ledger names it, as it names the slot.
local DEFAULT_CREST = "core.crest.plain"

-- The closed book's place on the stage: down from its top, as Core's crest bookplate sits (adapter/CoreGoods.lua);
-- and its width, the Ledger art kit's books', which the expansion's larger ones are drawn down to so every binding
-- shows the same size and fits the stage's 190.
local SWATCH_TOP, SWATCH_W = 16, 104

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
	swatch:SetPoint("TOP", 0, -SWATCH_TOP)
	swatch.book = ns.JournalSprite(swatch, "Bindings", "binding-field-leather", "ARTWORK")
	return swatch
end

--- Draws binding `look`'s closed book on the Curio Shop's preview stage (LED-R110): one swatch per stage, re-pointed
--- at the binding's, in its atlas, drawn 104 wide (the Ledger art kit's books' width), and shown at each call. The
--- shop hides what another good drew there.
---@param stage Frame
---@param look LedgerBindingLook
---@return LedgerBindingSwatch
function ns.DrawBindingSwatch(stage, look)
	local swatch = swatches[stage]
	if not swatch then
		swatch = buildSwatch(stage)
		swatches[stage] = swatch
	end
	local book = swatch.book
	ns.JournalResprite(book, look.swatchAtlas, look.swatch, SWATCH_W)
	swatch:SetSize(book.box[3], book.box[4])
	ns.JournalBoxAt(book, swatch, 0, 0)
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

--- Whether expansion good `goodID` is earned now (LED-R116, LED-R117): by `rule` over the projection's state as it
--- stands (even mid-update: Core asks only at registration, before any update, and after a live entry or a done,
--- SHOP-R31) and the celebrated set as saved, or kept there once earned.
---@param goodID string
---@param rule LedgerEarnedRule
---@return boolean
function ns.EarnedGoodNow(goodID, rule)
	local projection = ns.projection
	return ns.EarnedGoodOwned(goodID, rule, {
		state = projection and projection:GetState() --[[@as LedgerState?]],
		celebrated = ns.SavedCelebrated(),
		world = ns.world,
	})
end

--- Registers the Ledger's slot and its goods (LED-R110, SHOP-R21), then the zone crests in Core's crest slot (LED-R113,
--- SHOP-R23) and its four goods in Core's toast style and sound set slots (LED-R117), from OnInitialize after
--- RegisterModule, and redraws the open Journal whenever the equipped binding or crest changes (LED-R112, SHOP-R33).
--- A level binding, a zone crest and an expansion good are earned from the projection's state and the celebrated set
--- as they stand when Core asks (LED-R111, LED-R114, LED-R116, LED-R117, SHOP-R31); a crest's texts, from the state
--- the Journal shows (LED-R115).
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
		earnedBy = ns.EarnedGoodNow,
		preview = ns.DrawBindingSwatch,
	})
	for _, good in ipairs(goods) do
		module:RegisterGood(good)
	end
	local crests = ns.ZoneCrestGoods({
		state = function()
			local projection = ns.projection
			return projection and projection:GetState() --[[@as LedgerState?]]
		end,
		updating = function()
			local projection = ns.projection
			return projection == nil or projection:IsUpdating()
		end,
		celebrated = ns.SavedCelebrated,
		world = function()
			return ns.world
		end,
		areaName = ns.ClientNames.AreaName,
	})
	for _, crest in ipairs(crests) do
		module:RegisterGood(crest)
	end
	-- LED-R117's four in Core's toast style and sound set slots, which Core opens to earned goods (SHOP-R23, SHOP-R25)
	-- and draws and plays.
	for _, good in ipairs(ns.CoreSlotGoods(ns.EarnedGoodNow)) do
		module:RegisterGood(good)
	end
	Pagle.RegisterCallback(OWNER, "AppearanceChanged", function(_, slot)
		if slot == ns.BINDING_SLOT or slot == CREST_SLOT then
			ns.journal:Draw()
		end
	end)
end
