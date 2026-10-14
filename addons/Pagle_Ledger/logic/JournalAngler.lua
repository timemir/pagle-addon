if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Fish Journal's Angler page (LED-R146), as far as M3 goes (LED-R4): the bookplate on the left, the hands on the
-- rod and the Skill Milestones on the right. Pure logic, everything read from the spread's context (CORE-R7); the
-- book draws it (adapter/Journal.lua). M4 adds the crest (LED-R112), the active title, the Prestige emblems and
-- button, the Catch Milestone part, "Signed As" and "Bindings" to these pages.

-- The Angler page is ns.JOURNAL_ANGLER, its place ns.JournalPlace.angler (logic/Journal.lua).

-- The bookplate (LED-R146): "Ex Libris", "The Angler's Ledger", "kept since {firstDate}" (none before the first
-- Catch), the shown level (LED-R36), the ink XP bar (LED-R145), Ledger completion and its parts (LED-R70, LED-R71),
-- and the lifetime Catches (LED-R42; M3 shows no next milestone, LED-R4).
---@param context LedgerSpreadContext
---@return LedgerBlock[]
local function bookplate(context)
	local L = ns.L
	local state = context.state
	local celebrated = context.celebrated
	local format = context.formatNumber
	local blocks = {
		{ kind = "kicker", text = L.ANGLER_EX_LIBRIS },
		{ kind = "title", text = L.ANGLER_LEDGER },
	}
	-- The first Catch with a realm date; with none, the first Catch's server time at the realm's offset now.
	local since = state.firstDate and context.text:Date(state.firstDate)
		or state.firstTime and context.text:DateAt(state.firstTime)
	if since then
		blocks[#blocks + 1] = { kind = "text", text = L.ANGLER_KEPT_SINCE:format(since) }
	end
	blocks[#blocks + 1] = { kind = "title", text = L.ANGLER_LEVEL:format(ns.ShownLevel(state, celebrated)) }
	blocks[#blocks + 1] = { kind = "xpBar", bar = ns.InkXpBar(state, celebrated, context.now, format) }
	local completion = ns.LedgerCompletion(context.world, state)
	blocks[#blocks + 1] = {
		kind = "text",
		text = L.ANGLER_COMPLETE:format(completion.percent, format(completion.done), format(completion.total)),
	}
	for _, part in ipairs(ns.COMPLETION_PARTS) do
		local count = completion[part]
		blocks[#blocks + 1] =
			{ kind = "text", text = L.ANGLER_PARTS[part]:format(format(count.done), format(count.total)) }
	end
	blocks[#blocks + 1] =
		{ kind = "text", text = ns.CountText(state.catches, L.ANGLER_CATCHES_ONE, L.ANGLER_CATCHES_OTHER, format) }
	return blocks
end

-- "Hands on the Rod" (LED-R146): one line per character with a Skill Reading, by character index, read from
-- Pagle.GetAngler().skill and not from the projection (LED-R41).
---@param context LedgerSpreadContext
---@param blocks LedgerBlock[]
local function hands(context, blocks)
	local L = ns.L
	local skill = context.angler.skill
	local indices = {}
	for index in pairs(skill) do
		indices[#indices + 1] = index
	end
	table.sort(indices)
	blocks[#blocks + 1] = { kind = "title", text = L.ANGLER_HANDS }
	for _, index in ipairs(indices) do
		local reading = skill[index]
		blocks[#blocks + 1] = {
			kind = "text",
			hand = true,
			text = L.ANGLER_HAND:format(context.text:Character(index), reading.rank, reading.max),
		}
	end
end

-- "Milestones" (LED-R146): ☑ for each Skill Milestone credited, in the state or the celebrated set (LED-R40,
-- LED-R92), ☐ for the rest.
---@param context LedgerSpreadContext
---@param blocks LedgerBlock[]
local function milestones(context, blocks)
	local L = ns.L
	local credited = context.state.skill
	local celebrated = context.celebrated.skill
	local boxes = {}
	for i, threshold in ipairs(ns.SKILL_MILESTONES) do
		local done = credited[threshold] ~= nil or celebrated[threshold] ~= nil
		boxes[i] = L.ANGLER_MILESTONE:format(done and L.CHECK_ON or L.CHECK_OFF, threshold)
	end
	blocks[#blocks + 1] = { kind = "kicker", text = L.ANGLER_MILESTONES }
	blocks[#blocks + 1] = { kind = "text", text = table.concat(boxes, L.ANGLER_MILESTONE_SEPARATOR) }
end

ns.RegisterJournalSpread(ns.JOURNAL_ANGLER, {
	-- Home ❧ The Angler (LED-R125).
	crumbs = function()
		return { { label = ns.L.ANGLER_CRUMB, place = ns.JournalPlace.angler() } }
	end,
	draw = function(_, context)
		local right = {}
		hands(context, right)
		milestones(context, right)
		return { left = bookplate(context), right = right }
	end,
})
