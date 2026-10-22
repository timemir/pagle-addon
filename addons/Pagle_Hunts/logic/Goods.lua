if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Hunts' goods (HNT-R120–R123): its two slots and their goods as data, Night Watch in Core's sound set slot, each
-- good's name and description from lore, when each earned good is owned, and the goods to register made from them.
-- Pure logic, everything passed in (CORE-R7): adapter/Goods.lua registers them, draws each preview and holds the looks
-- the board and the tracker wear.

--- The notebook cover slot (HNT-R120): the board's leather (HNT-R70).
ns.COVER_SLOT = "hunts.notebookcover"
--- The tracker frame slot (HNT-R120): the Hunts tracker's frame (HNT-R79).
ns.TRACKER_FRAME_SLOT = "hunts.trackerframe"
--- Core's sound set slot (SHOP-R25), open to earned goods (SHOP-R23): Night Watch's (HNT-R123).
ns.CORE_SOUND_SET_SLOT = "core.soundset"

local ICONS = "Interface\\Icons\\"
-- The expansion's covers' material textures (HNT-R123), each also its good's icon.
local COVER_TILES = "Interface\\AddOns\\Pagle_Hunts\\media\\books\\covers\\"

--- What earns an earned good (HNT-R122): any set's title, every set's title (HNT-R20), or ns.WAGER_GOODS_RUNS
--- completed runs (HNT-R148).
---@alias HuntsEarnedRule "anySetTitle"|"everySetTitle"|"wagerRuns"

--- One of Hunts' goods, as data: exactly one of `default`, `tier` or `earned` (SHOP-R22, HNT-R122), and its icon, the
--- shop's swatch for it (HNT-R121): an in-client texture, or an expansion cover's material.
---@class HuntsGoodData
---@field id string
---@field default? true
---@field tier? 1|2|3|4|5 -- Tunables: notebook cover and tracker frame tiers
---@field earned? HuntsEarnedRule
---@field icon string

--- One of Hunts' slots, with its goods in the order the shop lists them.
---@class HuntsSlotData
---@field id string
---@field label string -- an ns.L key
---@field category "Hunts"|"Trackers"
---@field goods HuntsGoodData[]

--- The slots' defaults (HNT-R121, SHOP-R22): the board's own leather, and no tracker frame (the plain native block).
ns.DEFAULT_COVER = "hunts.notebookcover.leather"
ns.NO_TRACKER_FRAME = "hunts.trackerframe.none"

--- How many completed runs earn Winner's Brocade and Winner's Ribbon (HNT-R122): the completed-run count's (HNT-R148).
ns.WAGER_GOODS_RUNS = 10

-- An expansion cover (HNT-R121, HNT-R123): for sale at `tier`, or earned by `earned`; its icon its material.
---@param key string
---@param tier (1|2|3|4|5)?
---@param earned HuntsEarnedRule?
---@return HuntsGoodData
local function cover(key, tier, earned)
	return { id = ns.COVER_SLOT .. "." .. key, tier = tier, earned = earned, icon = COVER_TILES .. key }
end

--- HNT-R120's slots and HNT-R121's goods, in the order they register.
---@type HuntsSlotData[]
ns.HUNTS_GOODS = {
	{
		id = ns.COVER_SLOT,
		label = "SLOT_NOTEBOOK_COVER",
		category = "Hunts",
		goods = {
			{ id = ns.DEFAULT_COVER, default = true, icon = ICONS .. "INV_Misc_LeatherScrap_05" },
			{ id = "hunts.notebookcover.oilcloth", tier = 1, icon = ICONS .. "INV_Fabric_Felcloth_Ebon" },
			{ id = "hunts.notebookcover.tooled", tier = 2, icon = ICONS .. "Trade_LeatherWorking" },
			{ id = "hunts.notebookcover.verdigris", tier = 3, icon = ICONS .. "INV_Ore_Copper_01" },
			cover("canvas", 1),
			cover("kraft", 1),
			cover("tartan", 1),
			cover("maplinen", 2),
			cover("planks", 2),
			cover("snakeskin", 3),
			cover("shagreen", 3),
			cover("lacquer", 3),
			cover("bone", 3),
			cover("brasscase", 3),
			cover("scrimshaw", 4),
			cover("trophycase", 5),
			cover("pathfinder", nil, "anySetTitle"),
			cover("fiveseal", nil, "everySetTitle"),
			cover("wagersilk", nil, "wagerRuns"),
		},
	},
	{
		id = ns.TRACKER_FRAME_SLOT,
		label = "SLOT_TRACKER_FRAME",
		category = "Trackers",
		goods = {
			{ id = ns.NO_TRACKER_FRAME, default = true, icon = ICONS .. "INV_Misc_Note_02" },
			{ id = "hunts.trackerframe.inkwash", tier = 1, icon = ICONS .. "INV_Inscription_InkBlack01" },
			{ id = "hunts.trackerframe.waxseal", tier = 2, icon = ICONS .. "INV_Letter_03" },
			{ id = "hunts.trackerframe.slate", tier = 1, icon = ICONS .. "INV_Misc_Note_03" },
			{ id = "hunts.trackerframe.mapscrap", tier = 1, icon = ICONS .. "INV_Misc_Map_01" },
			{ id = "hunts.trackerframe.bounty", tier = 2, icon = ICONS .. "INV_Misc_Note_01" },
			{ id = "hunts.trackerframe.spyglass", tier = 3, icon = ICONS .. "INV_Misc_Spyglass_03" },
			{ id = "hunts.trackerframe.wagerribbon", earned = "wagerRuns", icon = ICONS .. "INV_Misc_Ribbon_01" },
		},
	},
}

--- Hunts' goods in Core's slots (SHOP-R23): none yet.
---@type { slot: string, goods: HuntsGoodData[] }[]
ns.HUNTS_CORE_GOODS = {}

--- The rule that earns good `goodID` (HNT-R122), or nil for a good that isn't Hunts' earned one.
---@param goodID string
---@return HuntsEarnedRule?
function ns.HuntsGoodRule(goodID)
	for _, list in ipairs({ ns.HUNTS_GOODS, ns.HUNTS_CORE_GOODS }) do
		for _, slot in ipairs(list) do
			for _, good in ipairs(slot.goods) do
				if good.id == goodID then
					return good.earned
				end
			end
		end
	end
	return nil
end

-- Whether set `setID`'s title is earned in `state` (HNT-R20) or was shown, by the celebrated set (HNT-R90).
---@param state HuntsState?
---@param celebrated HuntsCelebrated
---@param setID string
---@return boolean
local function hasTitle(state, celebrated, setID)
	return (state ~= nil and state.sets[setID] ~= nil) or (celebrated.sets ~= nil and celebrated.sets[setID] == true)
end

--- The completed-run count as Hunts' goods read it (HNT-R122, HNT-R148): the most of the projection's count, the
--- celebrated set's runs whose completion was shown, and its highest ladder title shown (HNT-R90). A rebuild or a
--- dropped run entry (HNT-R92) never lowers it below what was shown.
---@param state HuntsState?
---@param celebrated HuntsCelebrated
---@return integer
function ns.CompletedRunCount(state, celebrated)
	local count = state and state.settled or 0
	local shown = 0
	for _, run in pairs(celebrated.runs or {}) do
		if run.settled then
			shown = shown + 1
		end
	end
	count = math.max(count, shown)
	for step in pairs(celebrated.ladder or {}) do
		count = math.max(count, step)
	end
	return count
end

--- Whether `rule` holds (HNT-R122) over the projection's `state` (nil before it is built, or while it updates) and
--- the celebrated set together, so a good once earned is never lost: any set's title, every one of `sets`' titles,
--- or ns.WAGER_GOODS_RUNS completed runs.
---@param rule HuntsEarnedRule
---@param state HuntsState?
---@param celebrated HuntsCelebrated
---@param sets { id: string }[] the Hunt list's sets (HNT-R1)
---@return boolean
function ns.HuntsGoodEarned(rule, state, celebrated, sets)
	if rule == "wagerRuns" then
		return ns.CompletedRunCount(state, celebrated) >= ns.WAGER_GOODS_RUNS
	elseif rule == "anySetTitle" then
		return (state ~= nil and next(state.sets) ~= nil) or next(celebrated.sets or {}) ~= nil
	end
	for _, set in ipairs(sets) do
		if not hasTitle(state, celebrated, set.id) then
			return false
		end
	end
	return #sets > 0
end

--- An earned good's `earnedText` (HNT-R122): what earns it, in the Curio Shop.
---@param rule HuntsEarnedRule
---@return string
function ns.HuntsEarnedText(rule)
	local L = ns.L
	if rule == "wagerRuns" then
		return L.EARNED_WAGER_RUNS:format(ns.WAGER_GOODS_RUNS)
	end
	return rule == "anySetTitle" and L.EARNED_ANY_SET_TITLE or L.EARNED_EVERY_SET_TITLE
end

--- A good's name (HNT-R121): its lore, `huntgood.<goodID>.name` (HNT-R130), or its ID while the key has no text.
---@param goodID string
---@return string
function ns.HuntsGoodName(goodID)
	return ns.Lore(ns.L, "huntgood." .. goodID .. ".name") or goodID
end

--- A good's description (HNT-R121): its lore, `huntgood.<goodID>.description` (HNT-R130), or nil while it has none.
---@param goodID string
---@return string?
function ns.HuntsGoodDescription(goodID)
	return ns.Lore(ns.L, "huntgood." .. goodID .. ".description")
end

--- What a good's preview draws on the Curio Shop's stage: `goodID`'s look in slot `slotID`.
---@alias HuntsPreview fun(stage: Frame, slotID: string, goodID: string)

-- A good to register: named from lore, its icon its swatch, earned by its rule through `earned`, and its preview
-- drawn by `preview` (none for a good in Core's slot, which Core previews, SHOP-R23).
---@param slotID string
---@param good HuntsGoodData
---@param preview HuntsPreview?
---@param earned fun(rule: HuntsEarnedRule): boolean
---@return PagleGood
local function goodOf(slotID, good, preview, earned)
	local goodID, rule = good.id, good.earned
	return {
		id = goodID,
		slot = slotID,
		name = ns.HuntsGoodName(goodID),
		description = ns.HuntsGoodDescription(goodID),
		icon = good.icon,
		default = good.default,
		tier = good.tier,
		isEarned = rule and function()
			return earned(rule)
		end,
		earnedText = rule and ns.HuntsEarnedText(rule),
		preview = preview and function(stage)
			preview(stage, slotID, goodID)
		end,
	}
end

--- Hunts' slots and their goods to register, in order (HNT-R120–R123): each good named from lore, its icon its
--- swatch, an earned good owned while `earned(rule)` holds (HNT-R122), and its preview drawn by `preview`; then its
--- goods in Core's slots, with no slot of their own (`slot` nil) and Core's preview.
---@param preview HuntsPreview
---@param earned fun(rule: HuntsEarnedRule): boolean
---@return { slot: PagleSlot?, goods: PagleGood[] }[]
function ns.HuntsGoods(preview, earned)
	local list = {}
	for _, data in ipairs(ns.HUNTS_GOODS) do
		local goods = {}
		for k, good in ipairs(data.goods) do
			goods[k] = goodOf(data.id, good, preview, earned)
		end
		list[#list + 1] = {
			slot = { id = data.id, label = ns.L[data.label], category = data.category },
			goods = goods,
		}
	end
	for _, data in ipairs(ns.HUNTS_CORE_GOODS) do
		local goods = {}
		for k, good in ipairs(data.goods) do
			goods[k] = goodOf(data.slot, good, nil, earned)
		end
		list[#list + 1] = { goods = goods }
	end
	return list
end
