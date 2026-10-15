if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Fish Journal's Angler page (LED-R146): the bookplate on the left, with the crest (LED-R112), the active title
-- (LED-R77), the Prestige emblem and button (LED-R33, LED-R34) and the next Catch Milestone (LED-R42); the hands on
-- the rod, the Skill Milestones, "Signed As" and "Bindings" on the right. Pure logic, everything read from the
-- spread's context (CORE-R7); the book draws it (adapter/Journal.lua).

-- The Angler page is ns.JOURNAL_ANGLER, its place ns.JournalPlace.angler (logic/Journal.lua).

-- The lifetime Catches (LED-R42), with the next Catch Milestone while one is left: "{n} Catches · next milestone {T}".
---@param catches integer
---@param format fun(n: integer): string
---@return string
local function catchesLine(catches, format)
	local L = ns.L
	local text = ns.CountText(catches, L.ANGLER_CATCHES_ONE, L.ANGLER_CATCHES_OTHER, format)
	local next = ns.NextCatchMilestone(catches)
	return next and text .. L.ANGLER_NEXT_MILESTONE:format(format(next)) or text
end

-- The bookplate (LED-R146): the equipped crest (LED-R112), "Ex Libris", "The Angler's Ledger", "kept since
-- {date}" (none before the first Catch), the shown level (LED-R36), the active title in handwriting (LED-R77,
-- none without lore text, LED-R161), the ink XP bar (LED-R145), the Prestige emblem and stars or "No Prestige seals
-- yet" (LED-R34), the Prestige button while LED-R33 allows it, Ledger completion and its parts (LED-R70, LED-R71),
-- and the lifetime Catches with the next Catch Milestone (LED-R42).
---@param context LedgerSpreadContext
---@return LedgerBlock[]
local function bookplate(context)
	local L = ns.L
	local state = context.state
	local celebrated = context.celebrated
	local format = context.formatNumber
	-- the Prestige crest for the rank, holding the likeness, with the bookplate crest pinned on it (LED-R112)
	local blocks = { { kind = "crest", rank = state.prestige, icon = context.crest } }
	blocks[#blocks + 1] = { kind = "kicker", text = L.ANGLER_EX_LIBRIS }
	blocks[#blocks + 1] = { kind = "title", text = L.ANGLER_LEDGER }
	-- The first Catch with a realm date; with none, the first Catch's server time at the realm's offset now.
	local since = state.firstDate and context.text:Date(state.firstDate)
		or state.firstTime and context.text:DateAt(state.firstTime)
	if since then
		blocks[#blocks + 1] = { kind = "text", color = "faded", text = L.ANGLER_KEPT_SINCE:format(since) }
	end
	-- the shown level with "Angler Level" and the active title beside it, and the Prestige emblem and its words
	local _, title = ns.ActiveTitle(context --[[@as LedgerTitleView]])
	local mark = ns.PrestigeMark(state.prestige)
	blocks[#blocks + 1] = {
		kind = "bookplate",
		text = tostring(ns.ShownLevel(state, celebrated)),
		value = L.HOME_LEVEL,
		signature = title,
		mark = mark.emblem and mark or nil,
		note = ns.PrestigeName(state.prestige) or L.ANGLER_NO_PRESTIGE,
	}
	blocks[#blocks + 1] = { kind = "xpBar", bar = ns.InkXpBar(state, celebrated, context.now, format) }
	if context.canPrestige then
		blocks[#blocks + 1] = { kind = "button", text = L.ANGLER_PRESTIGE, action = context.askPrestige }
	end
	local completion = ns.LedgerCompletion(context.world, state)
	blocks[#blocks + 1] = {
		kind = "kicker",
		text = L.ANGLER_TALLY,
		value = L.ANGLER_COMPLETE:format(completion.percent, format(completion.done), format(completion.total)),
	}
	for _, part in ipairs(ns.COMPLETION_PARTS) do
		local count = completion[part]
		blocks[#blocks + 1] = {
			kind = "leader",
			style = "pair",
			text = L.ANGLER_PARTS[part],
			value = L.ANGLER_PART_COUNT:format(format(count.done), format(count.total)),
		}
	end
	blocks[#blocks + 1] = { kind = "text", text = catchesLine(state.catches, format) }
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
	blocks[#blocks + 1] = { kind = "kicker", text = L.ANGLER_HANDS }
	for _, index in ipairs(indices) do
		local reading = skill[index]
		blocks[#blocks + 1] = {
			kind = "leader",
			style = "pair",
			text = context.text:Character(index),
			value = L.ANGLER_HAND:format(reading.rank, reading.max),
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

-- "Signed As" (LED-R146, LED-R77, SET-R70): "Automatic", then each earned title with lore text in LED-R75's order
-- (LED-R161), as a pick list; the stored pick marked, or Automatic when it is nil or not earned. Picking calls
-- context.pickTitle with the title key, Automatic with nil.
---@param context LedgerSpreadContext
---@param blocks LedgerBlock[]
local function signedAs(context, blocks)
	local L = ns.L
	local pick = context.pickTitle
	local stored = context.activeTitle
	local titles, marked = {}, nil
	local keys = ns.TitleKeys(context --[[@as LedgerTitleView]])
	for _, key in ipairs(keys) do
		local name = ns.TitleName(key, context.text)
		if name then
			titles[#titles + 1] = { key = key, name = name }
			if key == stored then
				marked = key
			end
		end
	end
	blocks[#blocks + 1] = { kind = "kicker", text = L.ANGLER_SIGNED_AS }
	---@param key string?
	---@param name string
	local function line(key, name)
		blocks[#blocks + 1] = {
			kind = "link",
			style = "radio",
			on = key == marked,
			text = name,
			action = function()
				pick(key)
			end,
		}
	end
	line(nil, L.ANGLER_AUTOMATIC)
	for _, title in ipairs(titles) do
		line(title.key, title.name)
	end
end

-- "Bindings" (LED-R146, LED-R110): every binding in LED-R110's order, its name and its state: "In use" for the
-- equipped one, "Use" (equipping it, SHOP-R32) when owned, "Angler Level {L}" for a level binding not earned yet
-- (LED-R111), and "In the Curio Shop" (opening the shop at it, SHOP-R40) for one for sale and not owned. Look and
-- Feel picks the same setting, so the page reads Pagle.GetEquipped at each draw.
---@param context LedgerSpreadContext
---@param blocks LedgerBlock[]
local function bindings(context, blocks)
	local L = ns.L
	local goods = context.goods
	local equipped = goods.getEquipped(ns.BINDING_SLOT)
	blocks[#blocks + 1] = { kind = "kicker", text = L.ANGLER_BINDINGS }
	for _, binding in ipairs(ns.BINDINGS) do
		local id = ns.BindingID(binding)
		---@type LedgerBlock
		local line = { kind = "leader", text = ns.BindingName(binding), binding = binding.swatch }
		if id == equipped then
			line.value, line.state = L.ANGLER_BINDING_IN_USE, "inUse"
		elseif goods.isOwned(id) then
			line.value, line.state = L.ANGLER_BINDING_USE, "use"
			line.action = function()
				goods.setEquipped(ns.BINDING_SLOT, id)
			end
		elseif binding.level then
			line.value, line.state = L.BINDING_EARNED:format(binding.level), "level"
		else
			line.value, line.state = L.ANGLER_BINDING_SHOP, "shop"
			line.action = function()
				goods.openShop(id)
			end
		end
		blocks[#blocks + 1] = line
	end
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
		signedAs(context, right)
		bindings(context, right)
		return { left = bookplate(context), right = right }
	end,
})
