if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Fish Journal's Angler page (LED-R146): the bookplate on the left, with the crest (LED-R112), the active title
-- (LED-R77), the Prestige emblem and button (LED-R33, LED-R34) and the next Catch Milestone (LED-R42); the hands on
-- the rod, the Skill Milestones, "Signed As" and "Bindings" on the right. Pure logic, everything read from the
-- spread's context (CORE-R7); the book draws it (adapter/Journal.lua).

--- The Angler page's ID (LED-R125).
ns.JOURNAL_ANGLER = "angler"

-- The parts of Ledger completion, one line each, in the Angler page's order (LED-R71, LED-R146).
local PARTS = { "species", "junk", "treasure", "trophy", "zones" }

-- The lifetime Catches (LED-R42), with the next Catch Milestone while one is left: "{n} Catches · next milestone {T}".
---@param catches integer
---@param format fun(n: integer): string
---@return string
local function catchesLine(catches, format)
	local L = ns.L
	local text = (catches == 1 and L.ANGLER_CATCHES_ONE or L.ANGLER_CATCHES_OTHER):format(format(catches))
	for _, n in ipairs(ns.CATCH_MILESTONES) do
		if catches < n then
			return text .. L.ANGLER_NEXT_MILESTONE:format(format(n))
		end
	end
	return text
end

-- The bookplate (LED-R146): the equipped crest (LED-R112), "Ex Libris", "The Angler's Ledger", "kept since
-- {firstDate}" (none before the first Catch), the shown level (LED-R36), the active title in handwriting (LED-R77,
-- none without lore text, LED-R161), the ink XP bar (LED-R145), the Prestige emblem and stars or "No Prestige seals
-- yet" (LED-R34), the Prestige button while LED-R33 allows it, Ledger completion and its parts (LED-R70, LED-R71),
-- and the lifetime Catches with the next Catch Milestone (LED-R42).
---@param context LedgerJournalContext
---@return LedgerBlock[]
local function bookplate(context)
	local L = ns.L
	local state = context.state --[[@as LedgerState]]
	local celebrated = context.celebrated --[[@as LedgerCelebrated]]
	local format = context.formatNumber
	local blocks = {}
	if context.crest then
		blocks[1] = { kind = "icon", icon = context.crest }
	end
	blocks[#blocks + 1] = { kind = "kicker", text = L.ANGLER_EX_LIBRIS }
	blocks[#blocks + 1] = { kind = "title", text = L.ANGLER_LEDGER }
	if state.firstDate then
		blocks[#blocks + 1] = { kind = "text", text = L.ANGLER_KEPT_SINCE:format(context.text:Date(state.firstDate)) }
	end
	blocks[#blocks + 1] = { kind = "title", text = L.ANGLER_LEVEL:format(ns.ShownLevel(state, celebrated)) }
	local _, title = ns.ActiveTitle(context --[[@as LedgerTitleView]])
	if title then
		blocks[#blocks + 1] = { kind = "text", hand = true, text = title }
	end
	blocks[#blocks + 1] = { kind = "xpBar", bar = ns.InkXpBar(state, celebrated, context.now, format) }
	if state.prestige > 0 then
		blocks[#blocks + 1] = { kind = "emblem", mark = ns.PrestigeMark(state.prestige) }
	else
		blocks[#blocks + 1] = { kind = "text", color = "faded", text = L.ANGLER_NO_PRESTIGE }
	end
	if context.canPrestige then
		blocks[#blocks + 1] = { kind = "button", text = L.ANGLER_PRESTIGE, action = context.askPrestige }
	end
	local completion = ns.LedgerCompletion(
		context.world --[[@as LedgerWorld]],
		state,
		context.getItem --[[@as fun(itemID: integer): PagleItem?]]
	)
	blocks[#blocks + 1] = {
		kind = "text",
		text = L.ANGLER_COMPLETE:format(completion.percent, format(completion.done), format(completion.total)),
	}
	for _, part in ipairs(PARTS) do
		local count = completion[part]
		blocks[#blocks + 1] =
			{ kind = "text", text = L.ANGLER_PARTS[part]:format(format(count.done), format(count.total)) }
	end
	blocks[#blocks + 1] = { kind = "text", text = catchesLine(state.catches, format) }
	return blocks
end

-- "Hands on the Rod" (LED-R146): one line per character with a Skill Reading, by character index, read from
-- Pagle.GetAngler().skill and not from the projection (LED-R41).
---@param context LedgerJournalContext
---@param blocks LedgerBlock[]
local function hands(context, blocks)
	local L = ns.L
	local skill = (context.angler --[[@as Angler]]).skill
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
---@param context LedgerJournalContext
---@param blocks LedgerBlock[]
local function milestones(context, blocks)
	local L = ns.L
	local credited = (context.state --[[@as LedgerState]]).skill
	local celebrated = (context.celebrated --[[@as LedgerCelebrated]]).skill
	local boxes = {}
	for i, threshold in ipairs(ns.SKILL_MILESTONES) do
		local done = credited[threshold] ~= nil or celebrated[threshold] ~= nil
		boxes[i] = (done and L.ANGLER_MILESTONE_DONE or L.ANGLER_MILESTONE_OPEN):format(threshold)
	end
	blocks[#blocks + 1] = { kind = "kicker", text = L.ANGLER_MILESTONES }
	blocks[#blocks + 1] = { kind = "text", text = table.concat(boxes, L.ANGLER_MILESTONE_SEPARATOR) }
end

-- "Signed As" (LED-R146, LED-R77, SET-R70): "Automatic", then each earned title with lore text in LED-R75's order
-- (LED-R161), as a pick list; the stored pick marked, or Automatic when it is nil or not earned. Picking calls
-- context.pickTitle with the title key, Automatic with nil.
---@param context LedgerJournalContext
---@param blocks LedgerBlock[]
local function signedAs(context, blocks)
	local L = ns.L
	local pick = context.pickTitle --[[@as fun(key: string?)]]
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
	blocks[#blocks + 1] = { kind = "title", text = L.ANGLER_SIGNED_AS }
	---@param key string?
	---@param name string
	local function line(key, name)
		local mark = key == marked and L.ANGLER_SIGNED_ON or L.ANGLER_SIGNED_OFF
		blocks[#blocks + 1] = {
			kind = "link",
			text = mark:format(name),
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
---@param context LedgerJournalContext
---@param blocks LedgerBlock[]
local function bindings(context, blocks)
	local L = ns.L
	local isOwned = context.isOwned --[[@as fun(goodID: string): boolean]]
	local setEquipped = context.setEquipped --[[@as fun(slot: string, goodID: string): boolean]]
	local openShop = context.openShop --[[@as fun(goodID: string?)]]
	local equipped = (context.getEquipped --[[@as fun(slot: string): string?]])(ns.BINDING_SLOT)
	blocks[#blocks + 1] = { kind = "title", text = L.ANGLER_BINDINGS }
	for _, binding in ipairs(ns.BINDINGS) do
		local id = ns.BindingID(binding)
		---@type LedgerBlock
		local line = { kind = "leader", text = ns.BindingName(binding) }
		if id == equipped then
			line.value = L.ANGLER_BINDING_IN_USE
		elseif isOwned(id) then
			line.value = L.ANGLER_BINDING_USE
			line.action = function()
				setEquipped(ns.BINDING_SLOT, id)
			end
		elseif binding.level then
			line.value = L.BINDING_EARNED:format(binding.level)
		else
			line.value = L.ANGLER_BINDING_SHOP
			line.action = function()
				openShop(id)
			end
		end
		blocks[#blocks + 1] = line
	end
end

ns.RegisterJournalSpread(ns.JOURNAL_ANGLER, {
	-- Home ❧ The Angler (LED-R125).
	crumbs = function()
		return { { label = ns.L.ANGLER_CRUMB, place = { id = ns.JOURNAL_ANGLER } } }
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
