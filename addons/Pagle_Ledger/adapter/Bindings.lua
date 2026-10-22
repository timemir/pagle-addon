if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Ledger's goods on the client: its earned bindings registered in Core's binding slot (LED-R110–R112, ADR 0015),
-- the zone crests registered in Core's crest slot (LED-R113–R115), the equipped crest's icon for the bookplate, and the
-- Journal's redraw when either look changes. Core draws every binding on the shop's stage, the Ledger's too.

-- The bus owner of the Journal's look (CORE-R23).
local OWNER = "Pagle_Ledger Journal look"

-- Core's crest slot (SHOP-R25, ns.CREST_SLOT): the Angler's emblem, drawn on the bookplate (LED-R112).
local CREST_SLOT = ns.CREST_SLOT
-- Its default, Plain, which draws no emblem (SHOP-R25). Pagle's API doesn't say which good is a slot's default, so
-- the Ledger names it, as it names the slot.
local DEFAULT_CREST = "core.crest.plain"

--- What a binding draws (Core's look, its logic/Bindings.lua, ADR 0015), as the Journal reads it.
---@alias LedgerBindingLook PagleBindingLook
---@alias LedgerBindingCorners PagleBindingCorners

--- The look of binding good `goodID`, any binding in Core's slot (Pagle.GetBindingLook): Field Leather's for an ID that
--- isn't a binding's.
--- SHIM (#351): the Journal's book (adapter/Journal.lua, adapter/JournalBook.lua) reads its look here until it wears
--- Core's binding renderer.
---@param goodID string?
---@return LedgerBindingLook
function ns.BindingLook(goodID)
	return Pagle.GetBindingLook(goodID)
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
		sizeBands = ns.SizeBandCount(Pagle.SIZE_BANDS),
	})
end

--- Registers the Ledger's earned bindings in Core's binding slot (LED-R110, SHOP-R23), then the zone crests in Core's
--- crest slot (LED-R113) and its four goods in Core's toast style and sound set slots (LED-R117), from OnInitialize
--- after RegisterModule, and redraws the open Journal whenever the equipped binding or crest changes (LED-R112,
--- SHOP-R33).
--- A level binding, a zone crest and an expansion good are earned from the projection's state and the celebrated set
--- as they stand when Core asks (LED-R111, LED-R114, LED-R116, LED-R117, SHOP-R31); a crest's texts, from the state
--- the Journal shows (LED-R115).
---@param module PagleModuleHandle
function ns.RegisterBindings(module)
	local goods = ns.BindingGoods({
		earned = function(level)
			-- The state even mid-update: Core asks only at registration, before any update, and after a live entry
			-- or a done (SHOP-R31).
			local projection = ns.projection
			local state = projection and projection:GetState() --[[@as LedgerState?]]
			return ns.LevelBindingEarned(level, state, ns.SavedCelebrated())
		end,
		earnedBy = ns.EarnedGoodNow,
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
