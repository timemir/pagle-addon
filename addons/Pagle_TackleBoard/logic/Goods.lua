if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The Tackle Board's goods (TKB-R125, TKB-R126): its one slot and its goods as data, each good's name and description
-- from lore (TKB-R130), the earned ones' Campfire milestones, and the goods to register made from them. Pure logic,
-- everything passed in (CORE-R7): adapter/Goods.lua registers them, draws each preview, holds the frame looks the
-- tracker wears (TKB-R124) and refreshes the earned ones (SHOP-R31). Titles and flies are never goods (SHOP-R20).

--- The tracker frame slot (TKB-R125): the live tracker's frame (TKB-R124).
ns.TRACKER_FRAME_SLOT = "tackleboard.trackerframe"

local ICONS = "Interface\\Icons\\"

--- One of the Tackle Board's goods, as data: exactly one of `default`, `tier` or `milestone` (SHOP-R22): an earned
--- good is earned at that Campfire milestone (TKB-R126); and its icon, the shop's swatch for it (SHOP-R26): an
--- in-client texture.
---@class TackleGoodData
---@field id string
---@field default? true
---@field tier? 1|2
---@field milestone? integer  -- earned: the Campfire milestone's days (TKB-R73)
---@field icon string

--- TKB-R125's slot and goods, in the order they register.
---@type { id: string, label: string, category: "Trackers", goods: TackleGoodData[] }
ns.BOARD_GOODS = {
	id = ns.TRACKER_FRAME_SLOT,
	label = "SLOT_TRACKER_FRAME",
	category = "Trackers",
	goods = {
		-- A plain note: the plain native tracker, no frame.
		{ id = "tackleboard.trackerframe.none", default = true, icon = ICONS .. "INV_Misc_Note_04" },
		-- A pinned note: a cork backing in a thin wooden border.
		{ id = "tackleboard.trackerframe.corkboard", tier = 1, icon = ICONS .. "INV_Misc_Note_06" },
		-- A wooden crate: a weathered plank backing.
		{ id = "tackleboard.trackerframe.driftwood", tier = 2, icon = ICONS .. "INV_Crate_01" },
		-- The Curio Shop expansion's (TKB-R125). Linen: a square of old net.
		{ id = "tackleboard.trackerframe.net", tier = 1, icon = ICONS .. "INV_Fabric_Linen_01" },
		-- A fishing pole: bamboo slats.
		{ id = "tackleboard.trackerframe.bamboo", tier = 1, icon = ICONS .. "INV_Fishingpole_01" },
		-- A box: a tackle tin.
		{ id = "tackleboard.trackerframe.tin", tier = 2, icon = ICONS .. "INV_Box_01" },
		-- Fishing: a line and its bobber.
		{ id = "tackleboard.trackerframe.bobber", tier = 2, icon = ICONS .. "Trade_Fishing" },
		-- A fire: Live Embers, earned at the Campfire's 365-day milestone (TKB-R126).
		{ id = "tackleboard.trackerframe.embers", milestone = 365, icon = ICONS .. "Spell_Fire_Fire" },
	},
}

--- Whether the Campfire milestone of `days` is reached (TKB-R126, TKB-R73): kept in the projection's
--- `fire.milestones`, or its title in the celebrated set, so a milestone once reached is never lost, even to a
--- rebuild that no longer reaches it (TKB-R64, TKB-R83).
---@param state TackleBoardState
---@param celebrated { [string]: true } the celebrated set's titles
---@param days integer
---@return boolean
function ns.MilestoneReached(state, celebrated, days)
	if state.fire.milestones[days] ~= nil then
		return true
	end
	for _, milestone in ipairs(ns.CAMPFIRE_MILESTONES) do
		if milestone.days == days then
			return celebrated[milestone.title] == true
		end
	end
	return false
end

--- How many of the earned goods' Campfire milestones the projection has reached (TKB-R126): the Tackle Board calls
--- `M:RefreshGoods()` after a live entry that changes it (SHOP-R31).
---@param state TackleBoardState
---@return integer
function ns.GoodMilestonesReached(state)
	local reached = 0
	for _, good in ipairs(ns.BOARD_GOODS.goods) do
		if good.milestone and state.fire.milestones[good.milestone] ~= nil then
			reached = reached + 1
		end
	end
	return reached
end

--- A good's name (TKB-R130): its lore, `boardgood.<goodID>.name`, or its ID while the key has no text.
---@param goodID string
---@return string
function ns.BoardGoodName(goodID)
	return rawget(ns.L, "boardgood." .. goodID .. ".name") or goodID
end

--- A good's description (TKB-R130): its lore, `boardgood.<goodID>.description`, or nil while it has none.
---@param goodID string
---@return string?
function ns.BoardGoodDescription(goodID)
	return rawget(ns.L, "boardgood." .. goodID .. ".description")
end

--- The tracker header's right text (TKB-R122): the Campfire's days and the open goals ("12 · 4 open"), or the open
--- goals alone while no fire is lit (`fire` nil), when the header shows no flame.
---@param fire integer? the Campfire's days, nil with no fire lit
---@param open integer the open goals
---@return string
function ns.TrackerHeaderRight(fire, open)
	local count = ns.Plural(open, "TRACKER_OPEN")
	if fire == nil then
		return count
	end
	return ns.Plural(fire, "TRACKER_FIRE_OPEN", { fire = fire, open = count })
end

--- A goal line's count (TKB-R122): its displayed progress over its need ("12/30").
---@param progress integer
---@param need integer
---@return string
function ns.TrackerCount(progress, need)
	return ns.Plural(progress, "TRACKER_COUNT", { need = need })
end

--- The sample tracker each preview draws (TKB-R125): a Campfire of 5 days, then TKB-R125's two fixed goal lines, a
--- Haul Notice of 30 Catches in Elwynn Forest (area 12) at 12, and a Quality Notice of 5 uncommon-or-better Catches
--- at 2. Both are Notices; the zone's name is read from the client when drawn (TKB-R36).
ns.SAMPLE_TRACKER = {
	fire = 5,
	goals = {
		{ goal = { type = "n", kind = "haul", tier = 2, pay = 15, need = 30, target = 12 }, progress = 12 },
		{ goal = { type = "n", kind = "quality", tier = 2, pay = 15, need = 5, target = 2 }, progress = 2 },
	},
}

--- The sample tracker's lines (TKB-R125), laid out as TKB-R122 for the tracker block, in the board's words (logic/
--- Words.lua): the header with the flame, then each goal's text and count, then where, as workable here.
---@return TackleTrackerLine[]
function ns.SampleTrackerLines()
	local sample = ns.SAMPLE_TRACKER
	local lines = {
		{
			kind = "header",
			text = ns.L.TITLE,
			right = ns.TrackerHeaderRight(sample.fire, #sample.goals),
			fire = true,
		},
	}
	for _, entry in ipairs(sample.goals) do
		local goal = entry.goal --[[@as TackleGoalDef]]
		lines[#lines + 1] = {
			kind = "goal",
			text = ns.GoalText(goal),
			count = ns.TrackerCount(entry.progress, goal.need),
			where = ns.TrackerWhere(goal, true),
			expedition = goal.type == "e",
		}
	end
	return lines
end

--- What the Tackle Board's goods need from the client: `preview(stage, goodID)` draws a good's preview, and
--- `reached(days)` says whether that Campfire milestone is reached, from the state as it stands when Core asks.
---@class TackleGoodHooks
---@field preview fun(stage: Frame, goodID: string)
---@field reached fun(days: integer): boolean

--- The Tackle Board's slot and its goods to register (TKB-R125, TKB-R126): each good named from lore, its icon its
--- swatch, and its preview drawn by `hooks.preview`; an earned one earned while its Campfire milestone is reached
--- (`hooks.reached`), its earnedText saying which ("Campfire: 365 days").
---@param hooks TackleGoodHooks
---@return PagleSlot slot
---@return PagleGood[] goods
function ns.BoardGoods(hooks)
	local data = ns.BOARD_GOODS
	local goods = {}
	for i, good in ipairs(data.goods) do
		local goodID, days = good.id, good.milestone
		goods[i] = {
			id = goodID,
			slot = data.id,
			name = ns.BoardGoodName(goodID),
			description = ns.BoardGoodDescription(goodID),
			icon = good.icon,
			default = good.default,
			tier = good.tier,
			isEarned = days and function()
				return hooks.reached(days)
			end,
			earnedText = days and ns.Fill(ns.L.GOOD_EARNED_CAMPFIRE, { days = days }),
			preview = function(stage)
				hooks.preview(stage, goodID)
			end,
		}
	end
	return { id = data.id, label = ns.L[data.label], category = data.category }, goods
end
