if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- Stats' goods on the client (STA-R88, STA-R84): registered with Core, previewed on the Curio Shop's stage as a
-- sample tracker drawn by the tracker block maker (adapter/TrackerBlock.lua), and the frame looks the live tracker
-- wears. Every texture is one the book already draws (ns.BOOK_TEXTURES, in-client files), laid under a tint.

-- A tint from its hex code, as the prototypes' CSS writes it: { r, g, b }, 0 to 1.
---@param hex string "RRGGBB"
---@return number[]
local function tint(hex)
	return {
		tonumber(hex:sub(1, 2), 16) / 255,
		tonumber(hex:sub(3, 4), 16) / 255,
		tonumber(hex:sub(5, 6), 16) / 255,
	}
end

local BOOK = ns.BOOK_LOOK

--- Each tracker frame's look, by good ID (STA-R88, STA-R84). No frame (`stats.trackerframe.none`) has none: the plain
--- native block.
---@type table<string, StatsTrackerFrameLook>
ns.TRACKER_FRAMES = {
	-- A page from the book: its parchment, edged in the ruled ledger's brown with a second, fainter rule inside it, as a
	-- ledger's ruled border; the words in the book's inks.
	["stats.trackerframe.logbook"] = {
		backing = ns.BOOK_TEXTURES.paper,
		tint = BOOK.paper,
		alpha = 0.95,
		border = BOOK.ledgerRule,
		borderSize = 2,
		inner = BOOK.rowRule,
		innerAlpha = 0.6,
		ink = { header = BOOK.title, text = BOOK.ink, dim = BOOK.small, name = BOOK.kicker },
	},
	-- prototypes/curio-shop/'s brass frame (`.fr-brass`): a dark plate (#2a2218 to #15100a), a thin #b08a3a rim with a
	-- #5a4518 line inside it, and a bright brass rivet on each corner; the words keep their native colours.
	["stats.trackerframe.brass"] = {
		backing = ns.BOOK_TEXTURES.leather,
		tint = tint("201910"),
		alpha = 0.9,
		border = tint("b08a3a"),
		borderSize = 2,
		inner = tint("5a4518"),
		rivets = tint("e8c96a"),
	},
}

-- Each stage's sample tracker, made at its first drawing: the shop gives every good its own stage (#157), so one
-- each. Weak, so a stage the shop drops goes.
---@type table<Frame, StatsTrackerBlock>
local drawn = setmetatable({}, { __mode = "k" })
-- The good each sample shows, by sample.
---@type table<StatsTrackerBlock, string>
local shows = setmetatable({}, { __mode = "k" })
-- The sample's items asked of the client and not loaded yet.
---@type table<integer, true>
local asked = {}
-- Whether ITEM_DATA_LOAD_RESULT is registered.
local listening = false
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
---@param itemID integer
local function ask(itemID)
	if asked[itemID] then
		return
	end
	if not listening then
		listening = true
		Pagle.RegisterEvent(OWNER, "ITEM_DATA_LOAD_RESULT", function(_, loadedID, success)
			if not asked[loadedID] then
				return
			end
			asked[loadedID] = nil
			if success ~= false then
				for _, block in pairs(drawn) do
					drawSample(block, shows[block])
				end
			end
		end)
	end
	asked[itemID] = true
	C_Item.RequestLoadItemDataByID(itemID)
end

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
