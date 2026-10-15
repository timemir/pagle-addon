if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The Tackle Board's goods on the client (TKB-R125, TKB-R124): registered with Core, previewed on the Curio Shop's
-- stage as a sample tracker drawn by the tracker block maker (adapter/TrackerBlock.lua), and the frame looks the live
-- tracker wears.

-- A tint from its hex code, as the prototype's CSS writes it: { r, g, b }, 0 to 1.
---@param hex string "RRGGBB"
---@return number[]
local function tint(hex)
	return {
		tonumber(hex:sub(1, 2), 16) / 255,
		tonumber(hex:sub(3, 4), 16) / 255,
		tonumber(hex:sub(5, 6), 16) / 255,
	}
end

local LOOK, TEXTURES = ns.BOARD_LOOK, ns.BOARD_TEXTURES

--- Each tracker frame's look, by good ID (TKB-R125, TKB-R124). No frame (`tackleboard.trackerframe.none`) has none:
--- the plain native block. Both use the board's own textures (adapter/BoardWidgets.lua), in-client files.
---@type table<string, TackleTrackerFrameLook>
ns.TRACKER_FRAMES = {
	-- Tracker K2's `.fr-cork`: the board's cork (#a7773f with darker flecks) in a 3 px #5a3a1a wooden border, its words
	-- in dark ink: near-black goals, a deep red count, brown small print, and its `.here` green for "Complete".
	["tackleboard.trackerframe.corkboard"] = {
		base = LOOK.cork,
		texture = TEXTURES.fleck,
		tint = LOOK.corkFleck,
		alpha = 0.35,
		border = tint("5a3a1a"),
		borderSize = 3,
		ink = {
			header = tint("2a1a08"),
			dim = tint("3a2a14"),
			goal = tint("1a1006"),
			expedition = tint("1a1006"),
			count = tint("6a1a0a"),
			where = tint("3a2814"),
			more = tint("3a2814"),
			complete = tint("1a5a1a"),
		},
	},
	-- Tracker K2's `.fr-plank`: a weathered plank (#7d6244 with #6a5238 grain) in a 2 px #3a2a18 border; the words keep
	-- their native colours.
	["tackleboard.trackerframe.driftwood"] = {
		base = tint("7d6244"),
		texture = TEXTURES.grain,
		tint = tint("6a5238"),
		alpha = 0.7,
		border = tint("3a2a18"),
		borderSize = 2,
	},
}

-- Each stage's sample tracker, made at its first drawing: the shop gives every good its own stage (#157), so one
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
