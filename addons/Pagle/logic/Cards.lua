---@class PagleNS
local ns = select(2, ...)

-- The cards (announcements.md › Session summary, › Write-up, › UI): pure logic over PagleDB.global (CORE-R7). Which
-- card shows when, the Write-up sections Modules raise from a projection's done, and the rows a card shows.
-- adapter/Cards.lua draws them in the Torn Page card frame.

--- Session summary cards kept at most (ANN-R54; Tunables). The Write-up is outside the limit (ANN-R61).
ns.CARDS_KEPT = 3

--- What a Module passes to `M:RaiseWriteUp` (announcements.md › Contracts).
---@class PagleWriteUpSection
---@field heading string         -- "Your Ledger was written up from 2,340 Casts" / "While Hunts was off"
---@field lines string[]

--- A Write-up section as Core keeps it in `global.writeUp` (announcements.md › Data): who raised it, by its stored
--- title and order, and the Module's own heading and lines, which Core adds nothing to (ANN-R60).
---@class PagleWriteUpStored
---@field module string
---@field order integer
---@field title string
---@field heading string
---@field lines string[]

--- Write-up sections by Module order, then Module name, each Module's in the order raised (ANN-R61): a new list of
--- the same sections.
---@param sections PagleWriteUpStored[]
---@return PagleWriteUpStored[]
function ns.WriteUpInOrder(sections)
	local entries = {}
	for position, section in ipairs(sections) do
		entries[position] = { section = section, position = position }
	end
	table.sort(entries, function(a, b)
		local sectionA, sectionB = a.section, b.section
		if sectionA.module ~= sectionB.module then
			return ns.ModuleSortsBefore(sectionA.order, sectionA.module, sectionB.order, sectionB.module)
		end
		return a.position < b.position
	end)
	local ordered = {}
	for i, entry in ipairs(entries) do
		ordered[i] = entry.section
	end
	return ordered
end

--- Why a Module's Write-up section can't be raised, or nil if it can (announcements.md › Contracts).
---@param section any
---@return string?
function ns.WriteUpProblem(section)
	if type(section) ~= "table" then
		return "RaiseWriteUp takes a section table, got " .. type(section)
	end
	if type(section.heading) ~= "string" or section.heading == "" then
		return "RaiseWriteUp: a section needs a heading"
	end
	if type(section.lines) ~= "table" then
		return "RaiseWriteUp: a section needs its lines, a list of strings"
	end
	for _, line in ipairs(section.lines) do
		if type(line) ~= "string" then
			return "RaiseWriteUp: each line must be a string, got " .. type(line)
		end
	end
	return nil
end

--- Core's numbers on a Session summary card, from the Session (ANN-R53): its Casts, Catches, Casts got away and
--- seconds fished (endTime − startTime).
---@class PagleSessionNumbers
---@field casts integer
---@field catches integer
---@field gotAway integer
---@field seconds integer

--- A card as it shows (announcements.md › UI): a stored Session summary card (PagleSummaryCard), or the Write-up,
--- which has only a title and its sections.
---@class PagleCard
---@field title string
---@field numbers? PagleSessionNumbers
---@field coins? integer
---@field lines? PagleCardLines[]
---@field moments? PagleCardMoments[]
---@field writeUp? PagleWriteUpStored[]
---@field preview? true          -- a `/pagle dev preview card` sample (#247): stored nowhere, ends no waiting count

--- What the cards are fed. Every function is called when needed, never stored.
---@class PagleCardsOptions
---@field global fun(): table                    -- PagleDB.global, which keeps cards and writeUp
---@field mode fun(): PagleApplyMode|"done"|nil  -- the projection apply in progress (ns.projections:Mode())
---@field whenIdle fun(fn: fun())               -- runs fn once no projection is updating (ns.projections:WhenIdle)
---@field nextFrame fun(step: fun())            -- runs step on the next frame
---@field lanesEmpty fun(): boolean             -- no toast, banner or splash shows or waits (ns.lanes:IsEmpty())
---@field held fun(): boolean                   -- the lanes are held, for any reason (ns.lanes:IsHeld(), ANN-R38)
---@field cozy fun(): boolean                   -- Cozy mode is on (ANN-R62)
---@field show fun(card: PagleCard)             -- puts the card on screen, until the player closes it
---@field hide fun(card: PagleCard)             -- takes it off screen without closing it (ANN-R35)

--- The cards: which shows when (ANN-R21, ANN-R54, ANN-R61), and the Write-up sections Modules raise (ANN-R60).
---@class PagleCards
---@field package options PagleCardsOptions
---@field package ready boolean      -- login has settled: no projection updating, the held Announcements shown
---@field package showing PagleCard? -- the card on screen
local Cards = {}
Cards.__index = Cards

---@param options PagleCardsOptions
---@return PagleCards
function ns.NewCards(options)
	return setmetatable({ options = options, ready = false }, Cards)
end

-- PagleDB.global, whose cards keys ns.PAGLEDB_DEFAULTS puts in place.
---@package
---@return { cards: PagleSummaryCard[], writeUp: PagleWriteUpStored[] }
function Cards:data()
	return self.options.global()
end

--- At load: no card shows before no projection is updating (ANN-R61, LOG-R74). The held Cast Announcements flush on
--- the frame after that (ANN-R10), so the cards wait one frame more, and those are in the lanes first (ANN-R21).
function Cards:Start()
	self.options.whenIdle(function()
		self.options.nextFrame(function()
			self.options.nextFrame(function()
				self.ready = true
				self:Next()
			end)
		end)
	end)
end

--- Shows the next card if one may show now (ANN-R21): login has settled, none is showing, the lanes aren't held
--- for any reason (ANN-R38, ANN-R55) and no toast, banner or splash shows or waits. The Write-up comes first, unless
--- Cozy mode is on (ANN-R61, ANN-R62); then the stored cards, oldest first (ANN-R54). Cards aren't interruptions and
--- play no sound (ANN-R30): they never go through the lanes.
function Cards:Next()
	if not self.ready or self.showing or self.options.held() or not self.options.lanesEmpty() then
		return
	end
	local data = self:data()
	---@type PagleCard?
	local card = data.cards[1]
	if #data.writeUp > 0 and not self.options.cozy() then
		card = { title = ns.L.CARD_WRITE_UP, writeUp = ns.WriteUpInOrder(data.writeUp) }
	end
	if card then
		self.showing = card
		self.options.show(card)
	end
end

--- `/pagle dev preview card` (#247): puts `card` on screen now, in place of the card showing (which shows again once
--- it's closed, as it stays stored). Cards wait for the lanes and login only to keep their order; a preview doesn't,
--- but it holds through combat like any card (ANN-R35). Returns false, showing nothing, while held.
---@param card PagleCard
---@return boolean shown
function Cards:Preview(card)
	if self.options.held() then
		return false
	end
	if self.showing then
		self.options.hide(self.showing)
	end
	self.showing = card
	self.options.show(card)
	return true
end

--- A hold started, for any reason (ANN-R35, ANN-R38; adapter/Announcements.lua's ns.HoldAnnouncements): the card on
--- screen goes off it unclosed, so it stays in global.cards (or its sections in global.writeUp) and shows again once
--- the lanes have shown what they held (ANN-R36). Which reasons hold is the lanes' to keep: the cards wait on held().
function Cards:Hold()
	local card = self.showing
	if card then
		self.showing = nil
		self.options.hide(card)
	end
end

-- Removes each of `items` from `list`, by identity.
---@param list table[]
---@param items table[]
local function removeAll(list, items)
	for _, item in ipairs(items) do
		for i = #list, 1, -1 do
			if list[i] == item then
				table.remove(list, i)
			end
		end
	end
end

--- In Cozy mode, at SessionEnded (ANN-R62): the Write-up sections waiting, by Module order, taken out of
--- global.writeUp to join the Session's card. The sections on screen stay, kept until the player closes their card
--- (ANN-R61), so none shows twice.
---@return PagleWriteUpStored[]
function Cards:TakeWriteUp()
	local data = self:data()
	local onScreen = {}
	for _, section in ipairs(self.showing and self.showing.writeUp or {}) do
		onScreen[section] = true
	end
	local taken, kept = {}, {}
	for _, section in ipairs(data.writeUp) do
		local list = onScreen[section] and kept or taken
		list[#list + 1] = section
	end
	data.writeUp = kept
	return ns.WriteUpInOrder(taken)
end

--- The player closed `card` (ANN-R54, ANN-R61): a summary card leaves global.cards, the Write-up's sections leave
--- global.writeUp, and the next card shows. Nothing for a card that isn't the one showing.
---@param card PagleCard
function Cards:Close(card)
	if card ~= self.showing then
		return
	end
	self.showing = nil
	local data = self:data()
	if card.numbers then
		removeAll(data.cards, { card })
	else
		removeAll(data.writeUp, card.writeUp)
	end
	self:Next()
end

--- Keeps a Module's Write-up section in global.writeUp (ANN-R60, ANN-R61): a copy, with the Module's name, title and
--- order. It shows once the cards may (ANN-R21). The caller has checked it with ns.WriteUpProblem.
---@param module PagleModule
---@param section PagleWriteUpSection
function Cards:Raise(module, section)
	local lines = {}
	for i, line in ipairs(section.lines) do
		lines[i] = line
	end
	local writeUp = self:data().writeUp
	writeUp[#writeUp + 1] = {
		module = module.def.name,
		order = module.def.order,
		title = module.def.title,
		heading = section.heading,
		lines = lines,
	}
	self:Next()
end

--- `M:RaiseWriteUp(section)` over `cards` (ANN-R60), so Core's adapter and FakePagle publish one method: an error at
--- the Module's call, keeping nothing, outside a projection's done or for a section the contract refuses.
---@param registry PagleModuleRegistry
---@param cards PagleCards
---@return fun(self: PagleModuleHandle, section: PagleWriteUpSection)
function ns.RaiseWriteUpMethod(registry, cards)
	return function(self, section)
		local module = registry:ModuleCalling(self, "RaiseWriteUp", "section")
		if cards.options.mode() ~= "done" then
			error("RaiseWriteUp: a Write-up section is raised only from a projection's done (ANN-R60)", 2)
		end
		local problem = ns.WriteUpProblem(section)
		if problem then
			error(problem, 2)
		end
		cards:Raise(module, section)
	end
end

--- One row of a card's list (announcements.md › UI): a heading, a line of text, or a moment with its text and icon.
---@class PagleCardRow
---@field kind "heading"|"line"|"moment"
---@field text string
---@field detail? string
---@field icon? integer|string

--- A card's rows below Core's numbers (ANN-R53): "Pagle Coins +N" above 0, each Module's summary lines, each
--- Module's moments under its stored title, then the Write-up sections, each under its own heading (ANN-R60: Core
--- adds nothing of its own to a section). A moment that had expired when the card was made shows its pastText
--- instead, or its title if it has none (ANN-R45).
---@param card PagleCard
---@param formatNumber fun(n: integer): string the Coins sum as shown ("1,200", BreakUpLargeNumbers)
---@return PagleCardRow[]
function ns.CardRows(card, formatNumber)
	local rows = {}
	if (card.coins or 0) > 0 then
		rows[#rows + 1] = { kind = "line", text = ns.L.CARD_COINS:format(formatNumber(card.coins)) }
	end
	for _, group in ipairs(card.lines or {}) do
		for _, line in ipairs(group.lines) do
			rows[#rows + 1] = { kind = "line", text = line }
		end
	end
	for _, group in ipairs(card.moments or {}) do
		rows[#rows + 1] = { kind = "heading", text = group.title }
		for _, moment in ipairs(group.moments) do
			if moment.expired and moment.pastText then
				rows[#rows + 1] = { kind = "moment", text = moment.pastText, icon = moment.icon }
			else
				rows[#rows + 1] = { kind = "moment", text = moment.title, detail = moment.text, icon = moment.icon }
			end
		end
	end
	for _, section in ipairs(card.writeUp or {}) do
		rows[#rows + 1] = { kind = "heading", text = section.heading }
		for _, line in ipairs(section.lines) do
			rows[#rows + 1] = { kind = "line", text = line }
		end
	end
	return rows
end

--- Time fished as a card shows it (ANN-R53): whole minutes, rounded, at least 1; from an hour, hours and minutes.
---@param seconds integer
---@return string
function ns.CardDuration(seconds)
	local minutes = math.max(1, math.floor(seconds / 60 + 0.5))
	if minutes < 60 then
		return ns.L.MINUTES:format(minutes)
	end
	return ns.L.CARD_HOURS:format(math.floor(minutes / 60), minutes % 60)
end
