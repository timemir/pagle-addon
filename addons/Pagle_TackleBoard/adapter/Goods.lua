if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The Tackle Board's goods on the client (TKB-R125, TKB-R126, TKB-R124): registered with Core, previewed on the Curio
-- Shop's stage as a sample tracker drawn by the tracker block maker (adapter/TrackerBlock.lua), the frame looks the
-- live tracker wears, and the earned ones refreshed (SHOP-R31).

--- Each tracker frame's style, by good ID (TKB-R125, TKB-R124): the board art kit's Corkboard and Tideworn Plank, and
--- the Curio Shop expansion's five (adapter/TrackerBlock.lua's ns.TRACKER_STYLES). No frame
--- (`tackleboard.trackerframe.none`) has none: the block's native look.
---@type table<string, TackleTrackerStyle>
ns.TRACKER_FRAMES = {
	["tackleboard.trackerframe.corkboard"] = ns.TRACKER_STYLES.cork,
	["tackleboard.trackerframe.driftwood"] = ns.TRACKER_STYLES.drift,
	["tackleboard.trackerframe.net"] = ns.TRACKER_STYLES.net,
	["tackleboard.trackerframe.bamboo"] = ns.TRACKER_STYLES.bamboo,
	["tackleboard.trackerframe.tin"] = ns.TRACKER_STYLES.tin,
	["tackleboard.trackerframe.bobber"] = ns.TRACKER_STYLES.bobber,
	["tackleboard.trackerframe.embers"] = ns.TRACKER_STYLES.embers,
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

--- Registers the Tackle Board's slot and goods (TKB-R125, TKB-R126, SHOP-R21), from OnInitialize right after
--- RegisterModule. An earned good reads the projection's state and the celebrated set when Core asks: at registration
--- (before the projection, an empty state) and at each ns.RefreshGoods (SHOP-R31).
---@param module PagleModuleHandle
function ns.RegisterGoods(module)
	local slot, goods = ns.BoardGoods({
		preview = ns.PreviewGood,
		reached = function(days)
			local celebrated = ns.Celebrated()
			return ns.MilestoneReached(ns.State(), celebrated and celebrated.titles or {}, days)
		end,
	})
	module:RegisterSlot(slot)
	for _, good in ipairs(goods) do
		module:RegisterGood(good)
	end
end

--- Asks Core to read the earned goods again (TKB-R126, SHOP-R31), with `M:RefreshGoods()`: the projection calls it
--- after a live entry that reaches an earned good's Campfire milestone, and from its done. Nothing without a Module
--- handle (an inert Module, CORE-R13).
function ns.RefreshGoods()
	local module = ns.Module
	if module then
		module:RefreshGoods()
	end
end
