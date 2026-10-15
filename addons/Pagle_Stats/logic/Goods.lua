if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- Stats' goods (STA-R88): its one slot and three goods as data, each good's name and description from lore, and the
-- goods to register made from them. Pure logic, everything passed in (CORE-R7): adapter/Goods.lua registers them,
-- draws each preview and holds the frame looks the tracker wears (STA-R84).

--- The tracker frame slot (STA-R88): the live tracker's frame (STA-R84).
ns.TRACKER_FRAME_SLOT = "stats.trackerframe"

local ICONS = "Interface\\Icons\\"

--- One of Stats' goods, as data: exactly one of `default` or `tier` (SHOP-R22; Stats has no earned goods), and its
--- icon, the Curio Shop's swatch for it (STA-R88): an in-client texture.
---@class StatsGoodData
---@field id string
---@field default? true
---@field tier? 1|2 -- Tunables: Tracker frame tiers
---@field icon string

--- STA-R88's slot and goods, in the order they register.
---@type { id: string, label: string, category: "Trackers", goods: StatsGoodData[] }
ns.STATS_GOODS = {
	id = ns.TRACKER_FRAME_SLOT,
	label = "SLOT_TRACKER_FRAME",
	category = "Trackers",
	goods = {
		-- A plain note: the plain native tracker, no frame.
		{ id = "stats.trackerframe.none", default = true, icon = ICONS .. "INV_Misc_Note_03" },
		-- A ledger book: a parchment backing with a ruled-ledger border.
		{ id = "stats.trackerframe.logbook", tier = 1, icon = ICONS .. "INV_Misc_Book_08" },
		-- A bronze framework: a thin brass rim with riveted corners.
		{ id = "stats.trackerframe.brass", tier = 2, icon = ICONS .. "INV_Gizmo_BronzeFramework_01" },
	},
}

--- A good's name (STA-R88): its lore, `statsgood.<goodID>.name`, or its ID while the key has no text.
---@param goodID string
---@return string
function ns.StatsGoodName(goodID)
	return rawget(ns.L, "statsgood." .. goodID .. ".name") or goodID
end

--- A good's description (STA-R88): its lore, `statsgood.<goodID>.description`, or nil while it has none.
---@param goodID string
---@return string?
function ns.StatsGoodDescription(goodID)
	return rawget(ns.L, "statsgood." .. goodID .. ".description")
end

--- The sample tracker each preview draws (STA-R88): a Session of 21 minutes, 38 Casts, 31 Catches, 7 got away, 62
--- per hour and skill +3, then a normal watch (item 4603 in area 35, 40 Casts) and an unlucky one (item 13759 in area
--- 357, by night, 212 Casts).
ns.SAMPLE_TRACKER = {
	seconds = 21 * 60,
	casts = 38,
	catches = 31,
	gotAway = 7,
	perHour = 62,
	skill = 3,
	watches = {
		{ item = 4603, area = 35, count = 40, band = "normal" },
		{ item = 13759, area = 357, window = "night", count = 212, band = "unlucky" },
	},
}

--- The sample tracker's lines (STA-R88), laid out as STA-R82 for the tracker block, with its item and area names
--- resolved now through Stats' words (STA-R59: "Item {id}" until the client has the item), and the item IDs the
--- client hasn't loaded yet, for the caller to ask for.
---@return StatsTrackerLine[] lines
---@return integer[] unloaded
function ns.SampleTrackerLines()
	local L, sample = ns.L, ns.SAMPLE_TRACKER
	local lines = {
		{ kind = "header", text = L.TITLE, right = L.TRACKER_SESSION:format(ns.Duration(sample.seconds)) },
		{
			kind = "line",
			text = L.TRACKER_COUNTS:format(
				ns.Count(sample.casts, "Casts"),
				ns.Count(sample.catches, "Catches"),
				ns.Number(sample.gotAway)
			),
		},
		{
			kind = "line",
			text = L.TRACKER_PER_HOUR:format(ns.Number(sample.perHour), ns.Number(sample.skill)),
			dim = true,
		},
	}
	local unloaded = {}
	for _, watch in ipairs(sample.watches) do
		local name, _, loaded = ns.Item(watch.item)
		if not loaded then
			unloaded[#unloaded + 1] = watch.item
		end
		local sub = { ns.AreaName(watch.area) }
		if watch.window then
			sub[#sub + 1] = L.WINDOW_NAMES[watch.window]
		end
		sub[#sub + 1] = ns.BandWord(watch.band)
		lines[#lines + 1] = {
			kind = "watch",
			band = watch.band,
			name = name,
			count = ns.Number(watch.count),
			sub = table.concat(sub, L.TRACKER_JOIN),
		}
	end
	return lines, unloaded
end

--- Stats' slot and its goods to register (STA-R88): each good named from lore, its icon its swatch, and its preview
--- drawn by `preview(stage, goodID)`.
---@param preview fun(stage: Frame, goodID: string)
---@return PagleSlot slot
---@return PagleGood[] goods
function ns.StatsGoods(preview)
	local data = ns.STATS_GOODS
	local goods = {}
	for i, good in ipairs(data.goods) do
		local goodID = good.id
		goods[i] = {
			id = goodID,
			slot = data.id,
			name = ns.StatsGoodName(goodID),
			description = ns.StatsGoodDescription(goodID),
			icon = good.icon,
			default = good.default,
			tier = good.tier,
			preview = function(stage)
				preview(stage, goodID)
			end,
		}
	end
	return { id = data.id, label = ns.L[data.label], category = data.category }, goods
end
