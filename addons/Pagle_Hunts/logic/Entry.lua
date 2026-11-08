if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- A Hunt's entry on the board's right page (HNT-R3, HNT-R64–R66, HNT-R69) as data: each line's text and state, worked
-- out from what is passed in (CORE-R7). adapter/Entry.lua draws it for the Board, entry and retired modes.

--- What an entry is worked out from.
---@class HuntEntryInput
---@field hunt HuntDef
---@field list HuntList            -- names, notes, sets and a fixed class's members
---@field where HuntWhere          -- where it bites (HNT-R30–R34)
---@field state HuntsState         -- ns.State()
---@field updating boolean         -- ns.IsUpdating(): nothing is drawn from the state (HNT-R69)
---@field retired boolean?         -- a Retired Hunt: the retired entry (HNT-R3)
---@field row HuntRow?             -- its row in the grouping, for the window line
---@field unconfirmed "window"|"gating"|nil   -- ns.Unconfirmed(hunt, row.window): the unconfirmed chip (HNT-R34)
---@field pinned boolean
---@field fromSet string?          -- the set whose page it was opened from (HNT-R66)
---@field now integer              -- the grouping's time: labels count from it, so they freeze with it (HNT-R43)
---@field snapshot table           -- one live Pagle.GetConditions(): realm time (HNT-R50) and the live zone
---@field best integer             -- Pagle.GetAngler().bestBaseSkill (HNT-R33)
---@field sources HuntNameSources

--- One tier's step on the ladder (HNT-R64): its threshold and, once reached, its Catch's short date and zone; from
--- 1.6, "party" after them and a tooltip when a groupmate's Catch reached it (HNT-R186).
---@class HuntEntryTier
---@field tier integer
---@field threshold integer
---@field reached boolean
---@field when string?   -- "12 Oct, Darkshore", or "12 Oct" when the zone was 0; "12 Oct, Darkshore · party"
---@field party boolean?   -- a Party Catch reached it (HNT-R181, HNT-R186)
---@field tooltip string[]?   -- a party tier's: what it is, and when pagle.app counts it (HNT-R186, HNT-R208)

---@class HuntEntryLadder
---@field updating string?             -- the updating line, in place of the tiers (HNT-R69)
---@field tiers HuntEntryTier[]?
---@field bar { fill: number, label: string }?   -- toward the next unreached tier, or the count once finished

--- A chip (HNT-R65): its kind, its words, and the tooltip's lines if it has one.
---@class HuntEntryChip
---@field kind "zone"|"more"|"skill"|"lure"|"note"|"unconfirmed"|"holiday" -- a run's entry adds "holiday" (HNT-R163)
---@field text string
---@field here boolean?        -- a zone chip for the live zone: the "you're here" badge
---@field badge string?        -- the badge's words
---@field short boolean?       -- a skill chip short of skill: in red
---@field tooltip string[]?

--- A Hunt's entry, top to bottom (HNT-R64); a field left nil isn't shown.
---@class HuntEntry
---@field back string?          -- "back to {set}" (HNT-R66)
---@field backSet string?       -- the set it goes back to
---@field kicker string?        -- "{set} · Natural", set in small caps by the board
---@field name string
---@field target string
---@field retiredLine string?   -- "Retired {date}" (HNT-R3)
---@field seal HuntEntrySeal
---@field pin { pinned: boolean }?
---@field window string?
---@field conditions string?
---@field chips HuntEntryChip[]
---@field ladder HuntEntryLadder
---@field effort { text: string, odds: string }
---@field setLine string?

--- The seal (HNT-R64): its words, whether it is pressed, and the pressed seal's words stacked as it sets them (the
--- word, the short date and the year), nil when it isn't pressed.
---@class HuntEntrySeal
---@field text string
---@field filled boolean
---@field lines string[]?

-- The seal (HNT-R64): "Hunted {full date of tier 1}" once done, a dashed "not yet" before.
---@param progress HuntProgress?
---@return HuntEntrySeal
local function sealOf(progress)
	local L = ns.L
	if ns.HuntDone(progress) then
		local first = (progress --[[@as HuntProgress]]).reached[1]
		local date = first.date
		return {
			text = ns.Text(L.SEAL_HUNTED, { fullDate = ns.FormatFullDate(date) }),
			filled = true,
			lines = { L.SEAL_HUNTED_WORD, ns.FormatShortDate(date), tostring(date.year) },
		}
	end
	return { text = L.SEAL_NOT_YET, filled = false }
end

-- A reached tier's words: the short date of its Catch's realm date, and its zone's name unless the zone was 0; then
-- "party" when a Party Catch reached it (HNT-R186).
---@param reached HuntTier
---@param sources HuntNameSources
---@return string
local function whenOf(reached, sources)
	local L = ns.L
	local when = ns.FormatShortDate(reached.date)
	if reached.zone ~= 0 then
		when = ns.Text(L.LADDER_WHEN_ZONE, { date = when, areaName = sources.AreaName(reached.zone) or L.NAME_UNKNOWN })
	end
	if reached.party then
		when = ns.Text(L.LADDER_WHEN_PARTY, { when = when })
	end
	return when
end

-- One tier's step on the ladder (HNT-R64): a party tier's adds `party` and its tooltip (HNT-R186).
---@param k integer
---@param threshold integer
---@param got HuntTier?
---@param sources HuntNameSources
---@return HuntEntryTier
local function stepOf(k, threshold, got, sources)
	local step = { tier = k, threshold = threshold, reached = got ~= nil, when = got and whenOf(got, sources) or nil }
	if got and got.party then
		step.party = true
		step.tooltip = { ns.L.LADDER_PARTY_TIP, ns.L.LADDER_PARTY_TIP_SITE }
	end
	return step
end

--- The tier ladder (HNT-R64, HNT-R18's trims are the board's): one step per tier, then the ink bar toward the next
--- unreached tier, or the count once every tier is reached. A run's entry draws each event Hunt's with it (HNT-R163).
---@param hunt HuntDef|HuntEventHunt
---@param progress HuntProgress?
---@param sources HuntNameSources
---@return HuntEntryLadder
function ns.HuntLadder(hunt, progress, sources)
	local L = ns.L
	local reached = progress and progress.reached or {}
	local count = progress and progress.count or 0
	local tiers, next = {}, nil
	for k, threshold in ipairs(hunt.tiers) do
		local got = reached[k]
		tiers[k] = stepOf(k, threshold, got, sources)
		if not got and not next then
			next = threshold
		end
	end
	local bar
	if next then
		bar = {
			fill = math.min(1, count / next),
			label = ns.Text(L.LADDER_PROGRESS, { ladder_progress_1 = count, ladder_progress_2 = next }),
		}
	else
		bar = { fill = 1, label = ns.Text(L.LADDER_CAUGHT, { ladder_caught = count }) }
	end
	return { tiers = tiers, bar = bar }
end

-- The effort counter (HNT-R26, HNT-R27): the effort Casts, and after the first qualifying Catch those since the
-- latest one; then the note that odds live in Stats, as plain text.
---@param progress HuntProgress?
---@return { text: string, odds: string }
local function effortOf(progress)
	local L = ns.L
	local effort = progress and progress.effort or 0
	local casts = ns.Text(ns.L.EFFORT_CASTS, { count = effort })
	local text
	if progress and progress.caught then
		text = ns.Text(L.EFFORT_SINCE, { casts = casts, sinceLast = progress.sinceLast })
	else
		text = ns.Text(L.EFFORT, { casts = casts })
	end
	return { text = text, odds = L.EFFORT_ODDS }
end

-- The window line (HNT-R52), from the Hunt's row in the grouping; nil before the Hunt has one.
---@param input HuntEntryInput
---@return string?
local function windowOf(input)
	local row = input.row
	if not row then
		return nil
	end
	return ns.HuntWindowLine(ns.LabelCase(row, input.where, input.now, input.snapshot, input.best), input.sources)
end

--- Tunables (hunts.md): how many zone chips show before "+N more" (HNT-R65).
ns.ZONE_CHIPS = 3

-- The zone chips (HNT-R65): up to ZONE_CHIPS of the Hunt's zones, the live zone first with "you're here", the rest in
-- their order (ascending IDs, HNT-R31); then "+N more" with the others' names in its tooltip.
---@param input HuntEntryInput
---@param chips HuntEntryChip[]
local function addZoneChips(input, chips)
	local L, sources = ns.L, input.sources
	local live = input.snapshot.zone
	local zones = {}
	for _, zone in ipairs(input.where.zones) do
		if zone == live then
			table.insert(zones, 1, zone)
		else
			zones[#zones + 1] = zone
		end
	end
	local rest = {}
	for i, zone in ipairs(zones) do
		local name = sources.AreaName(zone) or L.NAME_UNKNOWN
		if i <= ns.ZONE_CHIPS then
			local here = zone == live or nil
			chips[#chips + 1] = { kind = "zone", text = name, here = here, badge = here and L.CHIP_HERE or nil }
		else
			rest[#rest + 1] = name
		end
	end
	if #rest > 0 then
		chips[#chips + 1] = { kind = "more", text = ns.Text(L.CHIP_MORE, { rest = #rest }), tooltip = rest }
	end
end

-- The tooltips of the unconfirmed chip, by ns.Unconfirmed's reason (HNT-R34, HNT-R65).
local UNCONFIRMED_TOOLTIPS = { window = "UNCONFIRMED_WINDOW", gating = "UNCONFIRMED_GATING" }

-- The chips (HNT-R65), in order, each only when it applies: zones, skill, lure, the Hunt's note then its set's, and
-- unconfirmed.
---@param input HuntEntryInput
---@return HuntEntryChip[]
local function chipsOf(input)
	local L, where, list, hunt = ns.L, input.where, input.list, input.hunt
	local chips = {}
	addZoneChips(input, chips)
	local need = where.skillNeed
	if need then
		if ns.SkillShortfall(need, input.best) then
			chips[#chips + 1] =
				{ kind = "skill", text = ns.Text(L.CHIP_SHORT, { need = need, best = input.best }), short = true }
		else
			chips[#chips + 1] = { kind = "skill", text = ns.Text(L.CHIP_SKILL, { need = need }) }
		end
	end
	if where.boardSpec and where.boardSpec.lure then
		chips[#chips + 1] = { kind = "lure", text = L.CHIP_LURE }
	end
	for _, note in ipairs({ list:HuntNote(hunt.id) or false, list:SetNote(hunt.set) or false }) do
		if note then
			chips[#chips + 1] = { kind = "note", text = note }
		end
	end
	local reason = input.unconfirmed
	if reason then
		chips[#chips + 1] =
			{ kind = "unconfirmed", text = L.CHIP_UNCONFIRMED, tooltip = { L[UNCONFIRMED_TOOLTIPS[reason]] } }
	end
	return chips
end

-- The set line: "{set}: {done} of {current} · earns {title}", or "· earned {title}" once earned (HNT-R20, HNT-R64),
-- counting the set's current Hunts that are done.
---@param input HuntEntryInput
---@return string
local function setLineOf(input)
	local L, list, setID = ns.L, input.list, input.hunt.set
	local done, current = ns.DoneOfCurrent(list, input.state, input.now, setID)
	local title = list:SetTitle(setID)
	local earned = input.state.sets[setID] and ns.Text(L.SET_EARNED, { title = title })
		or ns.Text(L.SET_EARNS, { title = title })
	return ns.Text(L.SET_LINE, { name = list:SetName(setID), done = done, current = current, earned = earned })
end

-- What is drawn from the projection's state (HNT-R69): the seal, the tier ladder, the effort counter and the set's
-- progress; while it is updating, each reads "Updating from your Catch log…".
---@param input HuntEntryInput
---@return HuntEntrySeal seal
---@return HuntEntryLadder ladder
---@return { text: string, odds: string } effort
---@return string setLine
local function progressOf(input)
	local L, hunt = ns.L, input.hunt
	if input.updating then
		return { text = L.UPDATING, filled = false },
			{ updating = L.UPDATING },
			{ text = L.UPDATING, odds = L.EFFORT_ODDS },
			ns.Text(L.SET_LINE_UPDATING, { name = input.list:SetName(hunt.set), updating = L.UPDATING })
	end
	local progress = input.state.hunts[hunt.id]
	return sealOf(progress), ns.HuntLadder(hunt, progress, input.sources), effortOf(progress), setLineOf(input)
end

--- A Hunt's entry (HNT-R64), or for a Retired Hunt its retired entry (HNT-R3): its name, target line, "Retired
--- {date}", seal, tier ladder and effort counter, with no window line, conditions line, chips or pin toggle. Opened
--- from a set's page, either reads "back to {set}" above it (HNT-R66).
---@param input HuntEntryInput
---@return HuntEntry
function ns.HuntEntry(input)
	local L, hunt, list = ns.L, input.hunt, input.list
	local seal, ladder, effort, setLine = progressOf(input)
	---@type HuntEntry
	local entry = {
		name = list:HuntName(hunt.id),
		target = ns.HuntTargetLine(hunt, list, input.sources),
		seal = seal,
		chips = {},
		ladder = ladder,
		effort = effort,
		setLine = setLine,
	}
	if input.fromSet then
		entry.back, entry.backSet = ns.Text(L.ENTRY_BACK, { name = list:SetName(input.fromSet) }), input.fromSet
	end
	if input.retired then
		-- A retired date is a UTC day (DATA-R87), as a title from a retirement is dated (HNT-R23).
		entry.retiredLine = ns.Text(L.ENTRY_RETIRED, {
			fullDate = ns.FormatFullDate(ns.UtcDate(hunt.retired --[[@as integer]])),
		})
		entry.setLine = nil
		return entry
	end
	local kind = hunt.kind == "natural" and L.ENTRY_NATURAL or L.ENTRY_IMPOSED
	entry.kicker = ns.Text(L.ENTRY_KICKER, { name = list:SetName(hunt.set), kind = kind })
	entry.pin = { pinned = input.pinned }
	entry.window = windowOf(input)
	entry.conditions = ns.HuntConditionsLine(
		input.where.boardSpec,
		hunt.kind == "natural" and hunt.window or nil,
		input.now,
		input.snapshot,
		input.sources
	)
	entry.chips = chipsOf(input)
	return entry
end

--- The Board's right page when it shows no entry (HNT-R67): with Hunts current but no row visible under the "show
--- completed" filter, that every Hunt here is done; otherwise nothing (no Hunt current at all leaves it empty).
---@param current integer the current Hunts, the grouping's rows
---@param visible integer the rows the board's groups show
---@return string?
function ns.EntryEmptyLine(current, visible)
	if current > 0 and visible == 0 then
		return ns.L.ENTRY_ALL_DONE
	end
	return nil
end
