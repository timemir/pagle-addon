if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Hunts' goods (HNT-R120–R123): its slot and its goods as data, its earned bindings in Core's binding slot, Night Watch
-- in Core's sound set slot and its three toast styles in Core's toast style slot, each good's name and description from
-- lore, when each earned good is owned, and the goods to register made from them. Pure logic, everything passed in
-- (CORE-R7): adapter/Goods.lua registers them, draws each tracker frame's preview and holds the looks the tracker
-- wears. Core draws the bindings and the styles and plays the sound set (ADR 0015, SHOP-R25, ANN-R85).

--- The tracker frame slot (HNT-R120): the Hunts tracker's frame (HNT-R79).
ns.TRACKER_FRAME_SLOT = "hunts.trackerframe"
--- Core's sound set slot (SHOP-R25), open to earned goods (SHOP-R23): Night Watch's (HNT-R123).
ns.CORE_SOUND_SET_SLOT = "core.soundset"
--- Core's binding slot (SHOP-R25), open to earned goods (SHOP-R23): Hunts' three earned bindings' (HNT-R122). Pagle's
--- API doesn't name Core's slots, so Hunts names it.
ns.CORE_BINDING_SLOT = "core.binding"
--- Core's toast style slot (SHOP-R25), open to earned goods (SHOP-R23): Nightfin Tide, The Deep Trench and Nat's Study,
--- the epic styles Hunts earns (HNT-R123, ANN-R85).
ns.CORE_TOAST_STYLE_SLOT = "core.toaststyle"

local ICONS = "Interface\\Icons\\"

--- Where Core keeps the bindings' materials (ADR 0015): Core draws Hunts' earned bindings, and each one's material is
--- also its good's icon (HNT-R123).
local BINDING_TILES = "Interface\\AddOns\\Pagle\\media\\books\\bindings\\"

--- What earns an earned good (HNT-R122): any set's title, every set's title (HNT-R20), ns.WAGER_GOODS_RUNS completed
--- runs (HNT-R148), ns.WAGER_STUDY_RUNS of them, `nightTide` three Hunts of the night events at tier 3, or `deepTrench` a
--- run of the lobster event with every Hunt at tier 3.
---@alias HuntsEarnedRule "anySetTitle"|"everySetTitle"|"wagerRuns"|"wagerCentury"|"nightTide"|"deepTrench"

--- One of Hunts' goods, as data: exactly one of `default`, `tier` or `earned` (SHOP-R22, HNT-R122), and its icon, the
--- shop's swatch for it (HNT-R121): an in-client texture, or an earned binding's material.
---@class HuntsGoodData
---@field id string
---@field default? true
---@field tier? 1|2|3|4|5 -- Tunables: tracker frame tiers
---@field earned? HuntsEarnedRule
---@field icon string

--- One of Hunts' slots, with its goods in the order the shop lists them.
---@class HuntsSlotData
---@field id string
---@field label string -- an ns.L key
---@field category "Trackers"
---@field goods HuntsGoodData[]

--- The slot's default (HNT-R121, SHOP-R22): no tracker frame (the plain native block).
ns.NO_TRACKER_FRAME = "hunts.trackerframe.none"

--- How many completed runs earn Winner's Brocade and Winner's Ribbon (HNT-R122): the completed-run count's (HNT-R148).
ns.WAGER_GOODS_RUNS = 10
--- How many earn Nat's Study (HNT-R122): the last step of the ladder (ns.LADDER_STEPS).
ns.WAGER_STUDY_RUNS = 100
--- The completed runs each counted rule takes, for its earned text.
ns.EARNED_RUNS = { wagerRuns = ns.WAGER_GOODS_RUNS, wagerCentury = ns.WAGER_STUDY_RUNS }

--- A Hunt's last tier: three in every event Hunt of the pool, so the top of its ladder (HNT-R15, HNT-R122).
ns.TOP_TIER = 3
--- The night Wager events Nightfin Tide counts Hunts of (HNT-R122), and how many different Hunts of them, each at its top
--- tier in some run, earn it: two may come from the same event.
ns.NIGHT_TIDE_EVENTS = {
	darkshore_moonlight = true,
	felwood_moonglade = true,
	dustwallow_marsh_night = true,
	deadwind_pass_night = true,
	eastern_plaguelands_night = true,
	tirisfal_silverpine_dusk = true,
}
ns.NIGHT_TIDE_HUNTS = 3
--- The event whose every Hunt, at its top tier in one run, earns The Deep Trench (HNT-R122).
ns.DEEP_TRENCH_EVENT = "azshara_lobster"

-- An earned binding of Hunts' (HNT-R122, ADR 0015), `hunts.binding.<key>`, earned by `earned`; its icon its material.
---@param key string
---@param earned HuntsEarnedRule
---@return HuntsGoodData
local function binding(key, earned)
	return { id = "hunts.binding." .. key, earned = earned, icon = BINDING_TILES .. key }
end

--- HNT-R120's slot and HNT-R121's goods, in the order they register.
---@type HuntsSlotData[]
ns.HUNTS_GOODS = {
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

--- Hunts' goods in Core's slots (HNT-R122, HNT-R123, SHOP-R23): its three earned bindings, then Night Watch, earned
--- with every set's title, then its three toast styles. Core draws the bindings (ADR 0015) and the styles (ANN-R85) and
--- plays the sound set (ANN-R72), and previews each with its slot's preview; Hunts only says when each is owned.
---@type { slot: string, goods: HuntsGoodData[] }[]
ns.HUNTS_CORE_GOODS = {
	{
		slot = ns.CORE_BINDING_SLOT,
		goods = {
			binding("pathfinder", "anySetTitle"),
			binding("fiveseal", "everySetTitle"),
			binding("wagersilk", "wagerRuns"),
		},
	},
	{
		slot = ns.CORE_SOUND_SET_SLOT,
		goods = {
			{ id = "hunts.soundset.nightwatch", earned = "everySetTitle", icon = ICONS .. "INV_Misc_Lantern_01" },
		},
	},
	{
		slot = ns.CORE_TOAST_STYLE_SLOT,
		goods = {
			{ id = "hunts.toaststyle.nightfin", earned = "nightTide", icon = ICONS .. "Spell_Nature_Moonglow" },
			{
				id = "hunts.toaststyle.trench",
				earned = "deepTrench",
				icon = ICONS .. "Spell_Frost_SummonWaterElemental",
			},
			{ id = "hunts.toaststyle.study", earned = "wagerCentury", icon = ICONS .. "INV_Misc_Book_09" },
		},
	},
}

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

--- The IDs of the Hunts of the pool's event `eventID`, in file order (HNT-R141), or nil for an event it doesn't have: the
--- default for the rules that read an event's Hunts.
---@param eventID string
---@return string[]?
function ns.EventHuntIDs(eventID)
	local event = ns.events and ns.events:Event(eventID)
	if not event then
		return nil
	end
	local ids = {}
	for i, hunt in ipairs(event.hunts) do
		ids[i] = hunt.id
	end
	return ids
end

--- A run's key's event ID (HNT-R142: `<eventID>@<start>`).
---@param key string
---@return string?
local function eventOfKey(key)
	return key:match("^(.+)@%d+$")
end

-- Every run the projection and the celebrated set together know (HNT-R145, HNT-R90), by run key, with its event and the
-- highest tier each of its Hunts reached: the most of the projection's and the celebrated run's, so a rebuild that no
-- longer reaches a tier shown doesn't lower it.
---@param state HuntsState?
---@param celebrated HuntsCelebrated
---@return table<string, { event: string?, tiers: table<string, integer> }>
local function runTiers(state, celebrated)
	local runs = {}
	for key, run in pairs(state and state.runs or {}) do
		local tiers = {}
		for huntID, progress in pairs(run.hunts) do
			tiers[huntID] = #progress.reached
		end
		runs[key] = { event = run.event, tiers = tiers }
	end
	for key, run in pairs(celebrated.runs or {}) do
		local entry = runs[key]
		if not entry then
			entry = { event = eventOfKey(key), tiers = {} }
			runs[key] = entry
		end
		for huntID, tier in pairs(run.tiers or {}) do
			entry.tiers[huntID] = math.max(entry.tiers[huntID] or 0, tier)
		end
	end
	return runs
end

-- Each rule (HNT-R122) over the projection's state and the celebrated set together, the Hunt list's sets, and the Hunts
-- of an event (ns.EventHuntIDs).
---@alias HuntsEventHunts fun(eventID: string): string[]?
---@type table<HuntsEarnedRule, fun(state: HuntsState?, celebrated: HuntsCelebrated, sets: { id: string }[], huntsOf: HuntsEventHunts): boolean>
local RULES = {
	-- Any set's title (HNT-R20).
	anySetTitle = function(state, celebrated)
		return (state ~= nil and next(state.sets) ~= nil) or next(celebrated.sets or {}) ~= nil
	end,
	-- Every one of the Hunt list's sets' titles (HNT-R20), and at least one set.
	everySetTitle = function(state, celebrated, sets)
		for _, set in ipairs(sets) do
			if not hasTitle(state, celebrated, set.id) then
				return false
			end
		end
		return #sets > 0
	end,
	-- ns.WAGER_GOODS_RUNS completed runs (HNT-R148).
	wagerRuns = function(state, celebrated)
		return ns.CompletedRunCount(state, celebrated) >= ns.WAGER_GOODS_RUNS
	end,
	-- ns.WAGER_STUDY_RUNS completed runs (HNT-R148).
	wagerCentury = function(state, celebrated)
		return ns.CompletedRunCount(state, celebrated) >= ns.WAGER_STUDY_RUNS
	end,
	-- ns.NIGHT_TIDE_HUNTS different Hunts of the night events, each at its top tier in some run (HNT-R145): the same
	-- Hunt in two runs counts once, and two Hunts of one event count twice.
	nightTide = function(state, celebrated)
		local hunts, count = {}, 0
		for _, run in pairs(runTiers(state, celebrated)) do
			if run.event and ns.NIGHT_TIDE_EVENTS[run.event] then
				for huntID, tier in pairs(run.tiers) do
					if tier >= ns.TOP_TIER and not hunts[huntID] then
						hunts[huntID] = true
						count = count + 1
					end
				end
			end
		end
		return count >= ns.NIGHT_TIDE_HUNTS
	end,
	-- One run of ns.DEEP_TRENCH_EVENT with every one of the event's Hunts at its top tier within it (HNT-R145): the
	-- Hunts of different runs don't add up.
	deepTrench = function(state, celebrated, _, huntsOf)
		local hunts = huntsOf(ns.DEEP_TRENCH_EVENT)
		if not hunts or #hunts == 0 then
			return false
		end
		for _, run in pairs(runTiers(state, celebrated)) do
			if run.event == ns.DEEP_TRENCH_EVENT then
				local all = true
				for _, huntID in ipairs(hunts) do
					if (run.tiers[huntID] or 0) < ns.TOP_TIER then
						all = false
						break
					end
				end
				if all then
					return true
				end
			end
		end
		return false
	end,
}

--- Whether `rule` holds (HNT-R122) over the projection's `state` (nil before it is built, or while it updates) and
--- the celebrated set together: any set's title, every one of `sets`' titles, ns.WAGER_GOODS_RUNS or ns.WAGER_STUDY_RUNS
--- completed runs, three Hunts of the night events at tier 3, or the lobster event's run at tier 3 in every Hunt.
--- `huntsOf` gives an event's Hunt IDs (the pool's, ns.EventHuntIDs, by default).
---@param rule HuntsEarnedRule
---@param state HuntsState?
---@param celebrated HuntsCelebrated
---@param sets { id: string }[] the Hunt list's sets (HNT-R1)
---@param huntsOf HuntsEventHunts?
---@return boolean
function ns.HuntsGoodEarned(rule, state, celebrated, sets, huntsOf)
	return RULES[rule](state, celebrated, sets, huntsOf or ns.EventHuntIDs)
end

--- Whether earned good `goodID`, earned by `rule`, is owned (HNT-R122): the celebrated set's goods have it, or the
--- rule holds now (ns.HuntsGoodEarned), so a good once earned is never lost, not even when a release adds a set.
---@param goodID string
---@param rule HuntsEarnedRule
---@param state HuntsState?
---@param celebrated HuntsCelebrated
---@param sets { id: string }[] the Hunt list's sets (HNT-R1)
---@param huntsOf HuntsEventHunts?
---@return boolean
function ns.HuntsGoodOwned(goodID, rule, state, celebrated, sets, huntsOf)
	local goods = celebrated.goods
	return (goods ~= nil and goods[goodID] == true) or ns.HuntsGoodEarned(rule, state, celebrated, sets, huntsOf)
end

--- Every one of Hunts' earned goods (HNT-R122), as `{ id, earned }`: its own slots' in their order, then its goods in
--- Core's slots, its toast styles last.
---@return { id: string, earned: HuntsEarnedRule }[]
function ns.HuntsEarnedGoods()
	local list = {}
	for _, slots in ipairs({ ns.HUNTS_GOODS, ns.HUNTS_CORE_GOODS }) do
		for _, slot in ipairs(slots) do
			for _, good in ipairs(slot.goods) do
				if good.earned then
					list[#list + 1] = { id = good.id, earned = good.earned }
				end
			end
		end
	end
	return list
end

--- Adds to the celebrated set (HNT-R90) each earned good whose rule now holds and that it doesn't have yet, so a good
--- once earned is never lost (HNT-R122): after a live entry and in `done`, before Hunts calls `M:RefreshGoods()`
--- (SHOP-R31). True when it added one.
---@param celebrated HuntsCelebrated its `goods` made with the first good noted
---@param state HuntsState?
---@param sets { id: string }[] the Hunt list's sets (HNT-R1)
---@param huntsOf HuntsEventHunts?
---@return boolean
function ns.NoteHuntsGoods(celebrated, state, sets, huntsOf)
	local noted = false
	for _, good in ipairs(ns.HuntsEarnedGoods()) do
		local goods = celebrated.goods
		if not (goods and goods[good.id]) and ns.HuntsGoodEarned(good.earned, state, celebrated, sets, huntsOf) then
			if type(goods) ~= "table" then
				goods = {}
				celebrated.goods = goods
			end
			goods[good.id] = true
			noted = true
		end
	end
	return noted
end

--- An earned good's `earnedText` (HNT-R122): what earns it, in the Curio Shop.
---@param rule HuntsEarnedRule
---@return string
function ns.HuntsEarnedText(rule)
	-- Only a completed-run rule's text has a number in it: the runs it takes.
	return ns.L.EARNED_TEXT[rule]:format(ns.EARNED_RUNS[rule] or 0)
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

-- A good to register: named from lore, its icon its swatch, owned by its ID and rule through `earned`, and its
-- preview drawn by `preview` (none for a good in Core's slot, which Core previews, SHOP-R23).
---@param slotID string
---@param good HuntsGoodData
---@param preview HuntsPreview?
---@param earned fun(goodID: string, rule: HuntsEarnedRule): boolean
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
			return earned(goodID, rule)
		end,
		earnedText = rule and ns.HuntsEarnedText(rule),
		preview = preview and function(stage)
			preview(stage, slotID, goodID)
		end,
	}
end

--- Hunts' slots and their goods to register, in order (HNT-R120–R123): each good named from lore, its icon its
--- swatch, an earned good owned while `earned(goodID, rule)` holds (HNT-R122), and its preview drawn by `preview`;
--- then its goods in Core's slots, with no slot of their own (`slot` nil) and Core's preview.
---@param preview HuntsPreview
---@param earned fun(goodID: string, rule: HuntsEarnedRule): boolean
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
