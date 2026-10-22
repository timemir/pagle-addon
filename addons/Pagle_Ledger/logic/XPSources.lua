if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- "Where your XP came from" (LED-R150) as data: the Ledger's own XP and each source's Activity XP (LED-R37, AXP-R6),
-- this climb and all told, for the Angler page and the ink XP bar's tooltip (LED-R145). Pure logic, everything passed
-- in (CORE-R7); logic/JournalAngler.lua and logic/Home.lua lay it out, adapter/JournalWidgets.lua draws it.

--- The sources the Ledger names, by def.name, in Core's Module order (`def.order`, CORE-R1's roster): a disabled
--- Module isn't registered, so its title can't be read from Core, and the Ledger names it in its own words (ns.L). A
--- source not listed here comes after them, by def.name, named by it.
ns.XP_SOURCE_ORDER = { "Hunts", "TackleBoard" }

--- The Ledger's own line's source.
ns.XP_SOURCE_OWN = "ledger"

--- One line of "Where your XP came from" (LED-R150).
---@class LedgerXPSourceLine
---@field source string   -- ns.XP_SOURCE_OWN for the Ledger's own XP, else the source's def.name
---@field name string     -- "Catches and discoveries", "Hunts", "Tackle Board"
---@field climb integer   -- this climb's XP from it
---@field total integer   -- all told
---@field off boolean     -- its Module isn't On (AXP-R6's `enabled` false): greyed and struck through, still counted

--- Each source's total at the latest Prestige, as the confirm card saved them in PagleLedgerDB.global.prestigeSources
--- (LED-R150): display only, outside the projection, never rebuilt.
---@class LedgerPrestigeSources
---@field rank integer                   -- the Prestige entry's rank
---@field activityXP integer             -- its `activityXP` snapshot (AXP-R5)
---@field totals table<string, integer>  -- each source's total then, by def.name

--- What to save at a Prestige (LED-R150): each source's total in `bySource` (Pagle.GetActivityXP().bySource as the
--- Prestige entry `record` was appended), with the entry's rank and snapshot, so they are used only for that climb.
---@param bySource table<string, { total: integer, enabled: boolean }>
---@param record { rank: integer, activityXP: integer? }
---@return LedgerPrestigeSources
function ns.PrestigeSources(bySource, record)
	local totals = {}
	for name, source in pairs(bySource) do
		totals[name] = source.total
	end
	return { rank = record.rank, activityXP = record.activityXP or 0, totals = totals }
end

-- Where `name` sits in Core's Module order: ns.XP_SOURCE_ORDER's index, any other after them.
---@param name string
---@return integer
local function orderOf(name)
	for i, known in ipairs(ns.XP_SOURCE_ORDER) do
		if known == name then
			return i
		end
	end
	return #ns.XP_SOURCE_ORDER + 1
end

-- `whole` split in proportion to `weights` (each 0 or more, summing above 0), rounded so the parts sum to `whole`: each
-- part rounded down, the rest one each to the largest remainders, ties to the earlier.
---@param whole integer
---@param weights integer[]
---@param sum integer
---@return integer[]
local function split(whole, weights, sum)
	local parts, order, given = {}, {}, 0
	for i, weight in ipairs(weights) do
		local share = whole * weight
		parts[i] = math.floor(share / sum)
		order[i] = { i = i, rest = share - parts[i] * sum }
		given = given + parts[i]
	end
	table.sort(order, function(a, b)
		if a.rest ~= b.rest then
			return a.rest > b.rest
		end
		return a.i < b.i
	end)
	for k = 1, whole - given do
		local i = order[k].i
		parts[i] = parts[i] + 1
	end
	return parts
end

--- "Where your XP came from" (LED-R150) for `state`: "Catches and discoveries", the Ledger's own XP (this climb's,
--- LED-R31, and all told), then each source in `activityXP.bySource` (Pagle.GetActivityXP(), AXP-R6) in Core's Module
--- order, its total all told and its part of the current climb's Activity XP (LED-R37). That part is in proportion to
--- the source's rise since the latest Prestige: its total now minus its total in `saved` (0 when not saved, never
--- below 0), with `saved` used only when it was saved at that Prestige (its rank and snapshot the state's). With
--- nothing saved for it, or no rise at all, in proportion to each source's total now. The parts are rounded to sum to
--- the climb's Activity XP. A source whose Module isn't On is `off`, and still counts (AXP-R90).
---@param state LedgerState
---@param activityXP ActivityXP? Pagle.GetActivityXP(); with none, no source and ns.ActivityXPTotal()
---@param saved LedgerPrestigeSources? PagleLedgerDB.global.prestigeSources
---@return LedgerXPSourceLine[]
function ns.XPSourceLines(state, activityXP, saved)
	local L = ns.L
	activityXP = activityXP or { total = ns.ActivityXPTotal(), bySource = {} }
	local lines = {
		{
			source = ns.XP_SOURCE_OWN,
			name = L.XP_SOURCE_OWN,
			climb = state.xp,
			total = state.lifetimeXP or 0,
			off = false,
		},
	}
	local names = {}
	for name in pairs(activityXP.bySource) do
		names[#names + 1] = name
	end
	table.sort(names, function(a, b)
		local oa, ob = orderOf(a), orderOf(b)
		if oa ~= ob then
			return oa < ob
		end
		return a < b
	end)
	if #names == 0 then
		return lines
	end
	local before = saved
		and saved.rank == state.prestige
		and saved.activityXP == (state.prestigeActivityXP or 0)
		and saved.totals
	local rises, nows, riseSum, nowSum = {}, {}, 0, 0
	for i, name in ipairs(names) do
		local now = activityXP.bySource[name].total
		nows[i], nowSum = now, nowSum + now
		rises[i] = before and math.max(0, now - (before[name] or 0)) or now
		riseSum = riseSum + rises[i]
	end
	local climb = ns.ClimbActivityXP(state, activityXP.total)
	local parts
	if climb <= 0 then
		parts = {}
	elseif riseSum > 0 then
		parts = split(climb, rises, riseSum)
	elseif nowSum > 0 then
		parts = split(climb, nows, nowSum)
	else
		parts = {}
	end
	for i, name in ipairs(names) do
		lines[#lines + 1] = {
			source = name,
			name = L.XP_SOURCE_NAMES[name] or name,
			climb = parts[i] or 0,
			total = nows[i],
			off = activityXP.bySource[name].enabled == false,
		}
	end
	return lines
end

--- The ink XP bar's tooltip (LED-R145): "Where this climb's XP came from", this climb's line of each of `lines`
--- (ns.XPSourceLines) with its XP, `off` for one whose Module isn't On, and the note that the split is approximate.
---@class LedgerXpTip
---@field title string
---@field lines { text: string, value: string, off: boolean }[]
---@field note string

--- The tooltip for `lines` (LED-R145, LED-R150), numbers through `formatNumber`.
---@param lines LedgerXPSourceLine[]
---@param formatNumber fun(n: integer): string BreakUpLargeNumbers
---@return LedgerXpTip
function ns.XPBarTip(lines, formatNumber)
	local L = ns.L
	local tip = { title = L.XP_BAR_TIP_TITLE, lines = {}, note = L.XP_BAR_TIP_NOTE }
	for i, line in ipairs(lines) do
		tip.lines[i] = { text = line.name, value = formatNumber(line.climb), off = line.off }
	end
	return tip
end
