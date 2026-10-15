if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The Tackle Board's goods on the client (TKB-R125, TKB-R124): registered with Core, previewed on the Curio Shop's
-- stage as a sample tracker drawn by the tracker block maker (adapter/TrackerBlock.lua), and the frame looks the live
-- tracker wears.

--- Each tracker frame's style, by good ID (TKB-R125, TKB-R124): the board art kit's Corkboard and Driftwood Plank
--- (adapter/TrackerBlock.lua's ns.TRACKER_STYLES). No frame (`tackleboard.trackerframe.none`) has none: the block's
--- native look.
---@type table<string, TackleTrackerStyle>
ns.TRACKER_FRAMES = {
	["tackleboard.trackerframe.corkboard"] = ns.TRACKER_STYLES.cork,
	["tackleboard.trackerframe.driftwood"] = ns.TRACKER_STYLES.drift,
}

-- Each stage's sample tracker, made at its first drawing: the Curio Shop gives every good its own stage, so one
-- each. Weak, so a stage the shop drops goes.
---@type table<Frame, TackleTrackerBlock>
local drawn = setmetatable({}, { __mode = "k" })

--- Draws tracker frame `goodID`'s sample tracker on `stage` (TKB-R125): the header and the two sample goals, in that
--- frame, their words read afresh (the zone's name from the client).
---@param stage Frame
---@param goodID string
function ns.PreviewGood(stage, goodID)
	local block = drawn[stage]
	if not block then
		block = ns.NewTrackerBlock(stage)
		block:SetPoint("TOP", 0, -24)
		drawn[stage] = block
	end
	block:SetLines(ns.SampleTrackerLines())
	block:SetFrame(ns.TRACKER_FRAMES[goodID])
	block:Show()
end

--- Registers the Tackle Board's slot and goods (TKB-R125, SHOP-R21), from OnInitialize right after RegisterModule.
---@param module PagleModuleHandle
function ns.RegisterGoods(module)
	local slot, goods = ns.BoardGoods(ns.PreviewGood)
	module:RegisterSlot(slot)
	for _, good in ipairs(goods) do
		module:RegisterGood(good)
	end
end
