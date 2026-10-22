if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- Stats' goods on the client (STA-R88, STA-R84): registered with Core, previewed on the Curio Shop's stage as a
-- sample tracker drawn by the tracker block maker (adapter/TrackerBlock.lua), and the looks the live tracker wears:
-- the books art kit's Logbook (ruled paper with its margin, the words in the book's inks) and Brass (a dark plate in a
-- brass rim with a rivet on each corner, the words bright over it), and the Curio Shop expansion's five.

--- Each tracker frame's look, by good ID (STA-R88, STA-R84). No frame (`stats.trackerframe.none`) has none: the native
--- look.
---@type table<string, StatsTrackerFrameLook>
ns.TRACKER_FRAMES = {
	["stats.trackerframe.logbook"] = ns.TRACKER_LOOKS.logbook,
	["stats.trackerframe.brass"] = ns.TRACKER_LOOKS.brass,
	["stats.trackerframe.greenbar"] = ns.TRACKER_LOOKS.greenbar,
	["stats.trackerframe.chalkboard"] = ns.TRACKER_LOOKS.chalkboard,
	["stats.trackerframe.tidegauge"] = ns.TRACKER_LOOKS.tidegauge,
	["stats.trackerframe.abacus"] = ns.TRACKER_LOOKS.abacus,
	["stats.trackerframe.astrolabe"] = ns.TRACKER_LOOKS.astrolabe,
}

-- Each stage's sample tracker, made at its first drawing: the Curio Shop gives every good its own stage, so one
-- each. Weak, so a stage the Curio Shop drops goes.
---@type table<Frame, StatsTrackerBlock>
local drawn = setmetatable({}, { __mode = "k" })
-- The good each sample shows, by sample.
---@type table<StatsTrackerBlock, string>
local shows = setmetatable({}, { __mode = "k" })
local OWNER = "Pagle_Stats goods"

-- Draws the sample tracker on `block` in `goodID`'s frame.
---@param block StatsTrackerBlock
---@param goodID string
---@return integer[] unloaded
local function drawSample(block, goodID)
	local lines, unloaded = ns.SampleTrackerLines()
	block:SetLines(lines)
	block:SetFrame(ns.TRACKER_FRAMES[goodID])
	shows[block] = goodID
	return unloaded
end

-- Asks the client for an item the sample names (STA-R59), once while it is on its way; when it loads, every sample
-- drawn redraws with its name.
local ask = ns.NewItemLoader(OWNER, function()
	for _, block in pairs(drawn) do
		drawSample(block, shows[block])
	end
end)

--- Draws tracker frame `goodID`'s sample tracker on `stage` (STA-R88): the header, the Session's two lines and the
--- two watches, in that frame.
---@param stage Frame
---@param goodID string
function ns.PreviewGood(stage, goodID)
	local block = drawn[stage]
	if not block then
		block = ns.NewTrackerBlock(stage)
		block:SetPoint("TOP", 0, -24)
		drawn[stage] = block
	end
	for _, itemID in ipairs(drawSample(block, goodID)) do
		ask(itemID)
	end
	block:Show()
end

--- Registers Stats' slot and goods (STA-R88, SHOP-R21), from OnInitialize right after RegisterModule.
---@param module PagleModuleHandle
function ns.RegisterGoods(module)
	local slot, goods = ns.StatsGoods(ns.PreviewGood)
	module:RegisterSlot(slot)
	for _, good in ipairs(goods) do
		module:RegisterGood(good)
	end
end
