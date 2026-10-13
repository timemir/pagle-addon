---@class PagleNS
local ns = select(2, ...)

-- The Session summary's data (announcements.md › Session summary, › Data): pure logic over PagleDB.global (CORE-R7).
-- Every moment Core keeps lands in the open Session's summary, and a Session that earned one becomes a card when it
-- ends. logic/Cards.lua shows the cards; the data lives in PagleDB only, never in the Catch log (ANN-R56).

local RUNG_HEIGHT = {}
for height, rung in ipairs(ns.MOMENT_RUNGS) do
	RUNG_HEIGHT[rung] = height
end

--- A moment as the summary stores it (announcements.md › Data): who raised it, by its stored title and order so a
--- since-disabled Module still sorts, and what the card shows.
---@class PagleStoredMoment
---@field module string
---@field moduleTitle string
---@field moduleOrder integer
---@field kind string
---@field rung PagleRung
---@field title string
---@field text? string
---@field icon? integer|string
---@field stamp? string
---@field coins? integer
---@field expiresAt? integer
---@field pastText? string
---@field expired? boolean -- on a card: it had expired when the card was made, so it shows its pastText (ANN-R45)

--- One Module's moments on a card: its stored title and order, its moments highest rung first (ANN-R53).
---@class PagleCardMoments
---@field module string
---@field title string
---@field order integer
---@field moments PagleStoredMoment[]

--- One Module's summary lines on a card, as the Module last set them (ANN-R51).
---@class PagleCardLines
---@field module string
---@field title string
---@field lines string[]               -- by key

--- A Session summary card (ANN-R53, announcements.md › Data), waiting in `global.cards` until the player closes it
--- (ANN-R54). logic/Cards.lua shows it.
---@class PagleSummaryCard: PagleCard
---@field title string                 -- "Your last session" for a `whileAway` one, else "Fishing session" (ANN-R54)
---@field numbers { casts: integer, catches: integer, gotAway: integer, seconds: integer } -- Core's, from the Session
---@field coins integer                -- the moments' coins summed; "Pagle Coins +N" shows only above 0
---@field lines PagleCardLines[]       -- the registered Modules' lines, by Module order
---@field moments PagleCardMoments[]   -- by stored Module order
---@field whileAway? boolean           -- from the SessionEnded fired at login for a Session ended while away
---@field writeUp? PagleWriteUpStored[] -- Write-up sections that waited in Cozy mode, by Module order (ANN-R62)

local STORED = {
	"module",
	"moduleTitle",
	"moduleOrder",
	"kind",
	"rung",
	"title",
	"text",
	"icon",
	"stamp",
	"coins",
	"expiresAt",
	"pastText",
}

--- The fields of a raised moment the summary keeps (announcements.md › Data).
---@param moment PagleRaisedMoment
---@return PagleStoredMoment
function ns.StoredMoment(moment)
	local stored = {}
	for _, key in ipairs(STORED) do
		stored[key] = moment[key]
	end
	return stored
end

-- The moments grouped by Module, by stored Module order (then name), each group highest rung first and otherwise in
-- the order raised (ANN-R53).
---@param moments PagleStoredMoment[]
---@return PagleCardMoments[]
local function byModule(moments)
	local groups, index = {}, {}
	for position, moment in ipairs(moments) do
		local group = index[moment.module]
		if not group then
			group = { module = moment.module, title = moment.moduleTitle, order = moment.moduleOrder, moments = {} }
			index[moment.module] = group
			groups[#groups + 1] = group
		end
		group.moments[#group.moments + 1] = { moment = moment, position = position }
	end
	table.sort(groups, function(a, b)
		if a.order ~= b.order then
			return a.order < b.order
		end
		return a.module < b.module
	end)
	for _, group in ipairs(groups) do
		table.sort(group.moments, function(a, b)
			local heightA, heightB = RUNG_HEIGHT[a.moment.rung], RUNG_HEIGHT[b.moment.rung]
			if heightA ~= heightB then
				return heightA > heightB
			end
			return a.position < b.position
		end)
		for i, entry in ipairs(group.moments) do
			group.moments[i] = entry.moment
		end
	end
	return groups
end

--- What the summary is fed. Every function is called when needed, never stored.
---@class PagleSummaryOptions
---@field global fun(): table              -- PagleDB.global, which keeps summary, pending and cards
---@field isOpen fun(): boolean            -- a Session is open (Pagle.GetSession() isn't nil, LOG-R64)
---@field modules fun(): PagleModule[]     -- the registered Modules, by order
---@field cozy fun(): boolean              -- Cozy mode is on (ANN-R42, ANN-R62)
---@field serverTime fun(): number         -- server time, which a moment's expiresAt is in (ANN-R45)
---@field waitingChanged fun(waiting: integer) -- the waiting count changed (ANN-R42): the compartment entry's label
---@field takeWriteUp fun(): PagleWriteUpStored[] -- takes the Write-up sections waiting off screen (ns.cards:TakeWriteUp)

--- The Session summary over PagleDB.global (ANN-R50–R53), and the count of moments Cozy mode sent it (ANN-R42).
---@class PagleSummary
---@field package options PagleSummaryOptions
---@field package waiting integer -- moments kept while Cozy mode was on since a Session summary last showed
local Summary = {}
Summary.__index = Summary

---@param options PagleSummaryOptions
---@return PagleSummary
function ns.NewSummary(options)
	return setmetatable({ options = options, waiting = 0 }, Summary)
end

--- The moments kept while Cozy mode was on, waiting for a Session summary to show (ANN-R42, CORE-R51). It lives in
--- memory only, like the rest of Cozy mode's display state.
---@return integer
function Summary:Waiting()
	return self.waiting
end

--- A Session summary card showed (ANN-R42): nothing waits any more. Turning Cozy mode off doesn't reset the count.
function Summary:SummaryShown()
	if self.waiting > 0 then
		self.waiting = 0
		self.options.waitingChanged(0)
	end
end

-- PagleDB.global with the summary's keys in place.
---@package
---@return { summary: { moments: PagleStoredMoment[], lines: table }, pending: PagleStoredMoment[], cards: PagleSummaryCard[], writeUp: PagleWriteUpStored[]? }
function Summary:data()
	local global = self.options.global()
	global.summary = global.summary or {}
	global.summary.moments = global.summary.moments or {}
	global.summary.lines = global.summary.lines or {}
	global.pending = global.pending or {}
	global.cards = global.cards or {}
	return global
end

--- Keeps a moment Core accepted, popped up or not (ANN-R25): in the open Session's summary (ANN-R50), or, with no
--- Session open, in `global.pending` for the next one (ANN-R52). In Cozy mode it adds one to the waiting count
--- (ANN-R42).
---@param moment PagleRaisedMoment
function Summary:Add(moment)
	local data = self:data()
	local moments = self.options.isOpen() and data.summary.moments or data.pending
	moments[#moments + 1] = ns.StoredMoment(moment)
	if self.options.cozy() then
		self.waiting = self.waiting + 1
		self.options.waitingChanged(self.waiting)
	end
end

--- At SessionStarted (ANN-R52): the moments raised while no Session was open move into its summary, ahead of its
--- own.
function Summary:Started()
	local data = self:data()
	local moments = data.pending
	for _, moment in ipairs(data.summary.moments) do
		moments[#moments + 1] = moment
	end
	data.summary.moments, data.pending = moments, {}
end

--- Sets or, with nil, removes one of a Module's summary lines (ANN-R51). Lines aren't tied to a Session: they stay
--- until the Module changes them. Each is stored with the Module's title and order (announcements.md › Data).
---@param module PagleModule
---@param key string
---@param text string?
function Summary:SetLine(module, key, text)
	local lines = self:data().summary.lines
	local name = module.def.name
	local entry = lines[name] or { lines = {} }
	entry.order, entry.title = module.def.order, module.def.title
	entry.lines[key] = text
	lines[name] = next(entry.lines) ~= nil and entry or nil
end

-- The registered Modules' lines, by Module order, each Module's by key (ANN-R51, ANN-R53): copies, so a card keeps
-- the lines it was made with (ANN-R55). A Module that isn't registered now is left out; its lines stay stored.
---@param lines table<string, { order: integer, title: string, lines: table<string, string> }>
---@param modules PagleModule[]
---@return PagleCardLines[]
local function cardLines(lines, modules)
	local card = {}
	for _, module in ipairs(modules) do
		local entry = lines[module.def.name]
		if entry then
			local keys = {}
			for key in pairs(entry.lines) do
				keys[#keys + 1] = key
			end
			table.sort(keys)
			local texts = {}
			for i, key in ipairs(keys) do
				texts[i] = entry.lines[key]
			end
			card[#card + 1] = { module = module.def.name, title = module.def.title, lines = texts }
		end
	end
	return card
end

--- `M:SetSummaryLine(key, text?)` over `summary` (ANN-R51), so Core's adapter and FakePagle publish one method: an
--- error at the Module's call, setting nothing, for a key that isn't a non-empty string or text that isn't a string
--- or nil.
---@param registry PagleModuleRegistry
---@param summary PagleSummary
---@return fun(self: PagleModuleHandle, key: string, text: string?)
function ns.SetSummaryLineMethod(registry, summary)
	return function(self, key, text)
		local module = registry:ModuleOf(self)
		if not module then
			error("SetSummaryLine is a Module handle method: call M:SetSummaryLine(key, text)", 2)
		end
		if type(key) ~= "string" or key == "" then
			error("SetSummaryLine: the key must be a non-empty string, got " .. type(key), 2)
		end
		if text ~= nil and type(text) ~= "string" then
			error("SetSummaryLine: the text must be a string, or nil to remove the line, got " .. type(text), 2)
		end
		summary:SetLine(module, key, text)
	end
end

--- At SessionEnded (ANN-R53): with at least one moment raised in the Session, or in Cozy mode a Write-up waiting
--- (ANN-R62), adds a card to `global.cards`, dropping the oldest beyond CARDS_KEPT (ANN-R54), and returns it. In Cozy
--- mode the waiting Write-up sections move onto it, except those on screen (ANN-R61). Either way the moments are cleared for the next Session, and the
--- lines stay (ANN-R51). Lines alone make no card. Expiry is checked again as the card is made: a moment past its
--- expiresAt is marked expired, so the card shows its pastText (ANN-R45).
---@param session PagleSession
---@return PagleSummaryCard?
function Summary:Ended(session)
	local data = self:data()
	local moments = data.summary.moments
	data.summary.moments = {}
	local now = self.options.serverTime()
	for _, moment in ipairs(moments) do
		if moment.expiresAt and now >= moment.expiresAt then
			moment.expired = true
		end
	end
	local writeUp
	if self.options.cozy() then
		local taken = self.options.takeWriteUp()
		writeUp = #taken > 0 and taken or nil
	end
	if #moments == 0 and not writeUp then
		return nil
	end
	local coins = 0
	for _, moment in ipairs(moments) do
		coins = coins + (moment.coins or 0)
	end
	---@type PagleSummaryCard
	local card = {
		title = session.whileAway and ns.L.CARD_LAST_SESSION or ns.L.CARD_SESSION,
		numbers = {
			casts = session.casts,
			catches = session.catches,
			gotAway = session.gotAway,
			seconds = session.endTime - session.startTime,
		},
		coins = coins,
		lines = cardLines(data.summary.lines, self.options.modules()),
		moments = byModule(moments),
		whileAway = session.whileAway,
		writeUp = writeUp,
	}
	data.cards[#data.cards + 1] = card
	while #data.cards > ns.CARDS_KEPT do
		table.remove(data.cards, 1)
	end
	return card
end
