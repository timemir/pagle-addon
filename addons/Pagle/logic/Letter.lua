---@class PagleNS
local ns = select(2, ...)

-- The Letter (core/onboarding.md › The Letter) and the letters a Module sends through Core (ONB-R15–R18): when a
-- letter shows, once per login, as ONB-R10's conditions hold; Open the letter and Later (ONB-R12, ONB-R16); which of
-- several letters shows first, one at a time (ONB-R17); whether one shows now, for the menu's tooltip (ONB-R13); a
-- restriction or an instance hiding it until the checks pass again (ONB-R14); the Modules' dialogs it waits for
-- (ONB-R100, QoL's conflict note); `/pagle dev onboarding letter` (ONB-R83) and its tour stops' samples (ONB-R84).
-- Pure logic over what it's handed (CORE-R7); logic/Wiring.lua's ns.WireLetter builds it over Core's host, and
-- adapter/Letter.lua draws the frame.

--- ONB-R10's delay (Tunables): the Letter shows no sooner than this many seconds after PLAYER_ENTERING_WORLD, and the
--- next letter (ONB-R17) no sooner than this many after the one before was answered.
ns.LETTER_DELAY = 4

--- One letter's words and what its confirm button does (ONB-R15): the frame's kicker, its line in the hand, its two
--- buttons, and the function called once the letter is `opened`. `isDue`, if given, is asked as the letter is about to
--- show: while it answers false the letter waits, so a letter whose reason has passed while it waited never shows.
---@class PagleLetterSpec
---@field kicker string
---@field text string
---@field confirm string
---@field later string
---@field onConfirm fun()
---@field isDue? fun(): boolean

--- What the Letter is fed. Every function is called when needed, never stored.
---@class PagleLetterOptions
---@field onboarding fun(): PagleOnboarding -- Core's onboarding state (ns.onboarding)
---@field isRestricted fun(): boolean       -- Pagle.IsRestricted() (CORE-R33)
---@field inInstance fun(): boolean         -- IsInInstance()
---@field cardsSettled fun(): boolean       -- the login's held Announcements and cards have shown and closed (ANN-R21)
---@field after fun(seconds: number, fn: fun()) -- runs fn `seconds` from now
---@field show fun(content: PagleLetterSpec) -- puts the frame on screen with these words, rising in with the `letter` sound (ONB-R11)
---@field hide fun()                        -- takes it off screen at once
---@field openGuide fun()                   -- opens the Field guide at its first step (ONB-R12, ONB-R20)
---@field guideOpen? fun(): boolean         -- the Field guide is open: a Module's letter waits (ONB-R17); none: never
---@field call? fun(fn: function, ...: any) -- calls a Module's function, an error reported and not raised (host.call)

--- Where the letters are: `waiting` for one to show, `shown` on screen, `away` hidden by a restriction or an instance
--- to show again (ONB-R14).
---@alias PagleLetterPhase "waiting"|"shown"|"away"

--- The letters Core sends, one on screen at a time.
---@class PagleLetter
---@field package options PagleLetterOptions
---@field package phase PagleLetterPhase
---@field package current string?             -- the letter on screen, or away, by id
---@field package ready boolean               -- LETTER_DELAY has passed since the latest PLAYER_ENTERING_WORLD
---@field package entered integer             -- each wait for the delay bumps it, so only the latest one's counts
---@field package dialogs table<string, true> -- the Modules whose dialog is open now (M:SetDialogOpen)
---@field package preview string?             -- the tour's sample on screen, by letter id (ONB-R84)
---@field package letters table<string, { spec: PagleLetterSpec, owner: string }> -- the Modules' letters (ONB-R15)
---@field package queue string[]              -- the Modules' letters sent this login, in the order sent, not answered
---@field package answered table<string, true> -- the letters answered this login (ONB-R12)
local Letter = {}
Letter.__index = Letter

---@param options PagleLetterOptions
---@return PagleLetter
function ns.NewLetter(options)
	return setmetatable({
		options = options,
		phase = "waiting",
		ready = false,
		entered = 0,
		dialogs = {},
		letters = {},
		queue = {},
		answered = {},
	}, Letter)
end

--- What is wrong with a Module's letter, or nil (ONB-R15): a table with an id `<module>.<name>` and non-empty
--- `kicker`, `text`, `confirm` and `later` strings and an `onConfirm` function. `module` is the Module's def.name.
---@param id any
---@param spec any
---@param module string
---@return string?
function ns.LetterProblem(id, spec, module)
	if type(id) ~= "string" or id == "" then
		return "RegisterLetter: a letter needs an id"
	end
	local prefix = module:lower() .. "."
	if id:sub(1, #prefix) ~= prefix or #id == #prefix then
		return ("RegisterLetter: a letter's id is %s<name>, got %s"):format(prefix, id)
	end
	if type(spec) ~= "table" then
		return "RegisterLetter takes a letter table, got " .. type(spec)
	end
	for _, field in ipairs({ "kicker", "text", "confirm", "later" }) do
		if type(spec[field]) ~= "string" or spec[field] == "" then
			return ("RegisterLetter: letter %s needs a %s"):format(id, field)
		end
	end
	if type(spec.onConfirm) ~= "function" then
		return ("RegisterLetter: letter %s needs an onConfirm function"):format(id)
	end
	if spec.isDue ~= nil and type(spec.isDue) ~= "function" then
		return ("RegisterLetter: letter %s's isDue is a function, got %s"):format(id, type(spec.isDue))
	end
	return nil
end

--- Declares a Module's letter (ONB-R15): its words and what its confirm button does, for `Send` to raise and the dev
--- command and the tour to show. Core keeps a copy. Returns what is wrong with it (ns.LetterProblem), or that the id
--- is registered already, and adds nothing then.
---@param id string
---@param spec PagleLetterSpec
---@param owner string the Module's def.name
---@return string? problem
function Letter:Register(id, spec, owner)
	local problem = ns.LetterProblem(id, spec, owner)
	if problem then
		return problem
	end
	if self.letters[id] then
		return ("RegisterLetter: letter %s is registered already"):format(id)
	end
	self.letters[id] = {
		spec = {
			kicker = spec.kicker,
			text = spec.text,
			confirm = spec.confirm,
			later = spec.later,
			onConfirm = spec.onConfirm,
			isDue = spec.isDue,
		},
		owner = owner,
	}
	return nil
end

--- The registered Modules' letter ids, sorted.
---@return string[]
function Letter:Ids()
	local ids = {}
	for id in pairs(self.letters) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	return ids
end

--- The Module that registered letter `id` (its def.name), or nil for an id nobody did.
---@param id any
---@return string?
function Letter:OwnerOf(id)
	local entry = type(id) == "string" and self.letters[id]
	return entry and entry.owner or nil
end

--- The words and action of letter `id`: the onboarding Letter's (ONB-R11, ONB-R12) or a registered Module letter's;
--- nil for an id that is neither.
---@param id string
---@return PagleLetterSpec?
function Letter:Spec(id)
	if id == ns.ONBOARDING_LETTER then
		local L = ns.L
		return {
			kicker = L.LETTER_KICKER,
			text = L.LETTER_LINE,
			confirm = L.LETTER_OPEN,
			later = L.LETTER_LATER,
			onConfirm = self.options.openGuide,
		}
	end
	local entry = self.letters[id]
	return entry and entry.spec
end

--- The letter on screen now, the tour's sample included: its id, or nil.
---@return string?
function Letter:Showing()
	if self.preview then
		return self.preview
	end
	return self.phase == "shown" and self.current or nil
end

--- Whether a letter is on screen now, the tour's sample included: the menu's tooltip then adds "A letter for you"
--- (ONB-R13, CORE-R55), whichever letter it is.
---@return boolean
function Letter:IsShowing()
	return self:Showing() ~= nil
end

--- Whether a Module's dialog that the Letter waits for is open (ONB-R100).
---@return boolean
function Letter:IsDialogOpen()
	return next(self.dialogs) ~= nil
end

-- Whether a restriction or an instance keeps the letters off screen (ONB-R10, ONB-R14).
---@param letter PagleLetter
---@return boolean
local function keptAway(letter)
	return letter.options.isRestricted() or letter.options.inInstance()
end

-- Whether the reason a Module's letter was sent still holds (its `isDue`, if it has one): an error in it counts as no.
---@param letter PagleLetter
---@param spec PagleLetterSpec
---@return boolean
local function reasonHolds(letter, spec)
	local isDue = spec.isDue
	if not isDue then
		return true
	end
	local call = letter.options.call
	if call then
		return call(isDue) == true
	end
	return isDue() == true
end

-- The letter to show next (ONB-R17): the onboarding Letter if it is due, else the first of the Modules' sent this
-- login that is still due; none that was answered this login. A Module's waits while the Field guide is open.
---@param letter PagleLetter
---@return string?
local function nextLetter(letter)
	local onboarding = letter.options.onboarding()
	if not letter.answered[ns.ONBOARDING_LETTER] and onboarding:IsLetterDue(ns.ONBOARDING_LETTER) then
		return ns.ONBOARDING_LETTER
	end
	local guideOpen = letter.options.guideOpen
	if guideOpen and guideOpen() then
		return nil
	end
	for _, id in ipairs(letter.queue) do
		if not letter.answered[id] and onboarding:IsLetterDue(id) and reasonHolds(letter, letter.letters[id].spec) then
			return id
		end
	end
	return nil
end

--- ONB-R10's checks, run at each moment a letter may come or go: the delay's end, RestrictionChanged,
--- ZONE_CHANGED_NEW_AREA, a card closing, a Module's dialog closing and the Field guide closing. A letter still to
--- show this login shows once it is due (waiting or later), the delay has passed, no Module's dialog is open, the
--- login's cards have shown and closed, and neither a restriction nor an instance keeps it away; only one shows at a
--- time, the onboarding Letter first (ONB-R17). One on screen hides for a restriction or an instance alone (ONB-R14),
--- and shows again at a later check. While the tour's sample shows, nothing changes.
function Letter:Check()
	if self.preview then
		return
	end
	local options = self.options
	if self.phase == "shown" then
		if keptAway(self) then
			self.phase = "away"
			options.hide()
		end
		return
	end
	if not self.ready or self:IsDialogOpen() or keptAway(self) or not options.cardsSettled() then
		return
	end
	local id = nextLetter(self)
	local spec = id and self:Spec(id)
	if id and spec then
		self.current = id
		self.phase = "shown"
		options.show(spec)
	end
end

-- The delay counts again from now (ONB-R10, ONB-R17): only the latest wait's end makes the letters ready.
---@param letter PagleLetter
local function wait(letter)
	letter.entered = letter.entered + 1
	local entered = letter.entered
	letter.ready = false
	letter.options.after(ns.LETTER_DELAY, function()
		if entered == letter.entered then
			letter.ready = true
			letter:Check()
		end
	end)
end

--- PLAYER_ENTERING_WORLD, at the login and at each loading screen after: the delay counts again from now (ONB-R10),
--- and a letter on screen hides if the world is an instance.
function Letter:EnteredWorld()
	wait(self)
	self:Check()
end

--- A Module's dialog that asks the player something opened or closed (M:SetDialogOpen, ONB-R100): the letters wait
--- while any is open, and check again as one closes.
---@param owner string the Module's def.name
---@param open boolean
function Letter:SetDialogOpen(owner, open)
	self.dialogs[owner] = open or nil
	if not open then
		self:Check()
	end
end

--- A Module sends its letter (M:ShowLetter, ONB-R16): a letter with no state yet becomes `waiting`, and one that is
--- `waiting` or `later` and not answered this login joins the queue, to show as ONB-R10's conditions hold (ONB-R17).
--- A `declined` or `opened` letter, one answered this login and one never registered are left alone, and sending a
--- letter again changes nothing. Returns whether the letter is queued or on screen.
---@param id string
---@return boolean
function Letter:Send(id)
	if not self.letters[id] or self.answered[id] then
		return false
	end
	if not self.options.onboarding():RaiseLetter(id) then
		return false
	end
	local queued = false
	for _, sent in ipairs(self.queue) do
		queued = queued or sent == id
	end
	if not queued then
		self.queue[#self.queue + 1] = id
	end
	self:Check()
	return true
end

-- A button on the tour's sample: it only goes. Returns whether the sample was showing.
---@param letter PagleLetter
---@return boolean
local function endPreview(letter)
	if not letter.preview then
		return false
	end
	letter.preview = nil
	letter.options.hide()
	return true
end

-- The letter on screen is answered (ONB-R12, ONB-R16): not again this login, off the queue, and the delay before the
-- next one starts (ONB-R17). Returns its id and words.
---@param letter PagleLetter
---@return string id
---@return PagleLetterSpec spec
local function answer(letter)
	local id = letter.current --[[@as string]]
	local spec = letter:Spec(id) --[[@as PagleLetterSpec]]
	letter.phase = "waiting"
	letter.current = nil
	letter.answered[id] = true
	for i, sent in ipairs(letter.queue) do
		if sent == id then
			table.remove(letter.queue, i)
			break
		end
	end
	wait(letter)
	return id, spec
end

--- Open the letter (ONB-R12, ONB-R16): the letter on screen is `opened`, it goes, and its confirm button's action
--- runs: the guide at its first step for the onboarding Letter, the Module's `onConfirm` for another.
function Letter:Open()
	if endPreview(self) or self.phase ~= "shown" then
		return
	end
	local id, spec = answer(self)
	self.options.onboarding():OpenLetter(id)
	self.options.hide()
	local call = self.options.call
	if call and id ~= ns.ONBOARDING_LETTER then
		call(spec.onConfirm)
	else
		spec.onConfirm()
	end
end

--- Later (ONB-R12, ONB-R16): the letter goes; from `waiting` it is `later`, shown once more at the next login, and
--- from `later` it is `declined`.
function Letter:Later()
	if endPreview(self) or self.phase ~= "shown" then
		return
	end
	local id = answer(self)
	self.options.onboarding():LetterLater(id)
	self.options.hide()
end

--- `/pagle dev onboarding letter [id]` (ONB-R83): letter `id` (the onboarding Letter's by default) on screen now,
--- whatever its state and ONB-R10's conditions, its buttons acting as ever. The tour's sample on screen becomes it,
--- and another letter on screen gives way to it. Returns false for an id that is no letter.
---@param id string?
---@return boolean
function Letter:ShowNow(id)
	id = id or ns.ONBOARDING_LETTER
	local spec = self:Spec(id)
	if not spec then
		return false
	end
	if self.preview == id then
		self.preview = nil
		self.current = id
		self.phase = "shown"
		return true
	end
	endPreview(self)
	if self.phase ~= "shown" or self.current ~= id then
		self.current = id
		self.phase = "shown"
		self.options.show(spec)
	end
	return true
end

--- The tour stop `core.onboarding.letter`'s show (ONB-R84), or a Module letter's `core.onboarding.letter.<id>`: the
--- letter on screen as a sample, writing nothing, its buttons only closing it (CORE-R68). Nothing while a letter
--- itself shows.
---@param id string? the onboarding Letter's by default
function Letter:TourShow(id)
	id = id or ns.ONBOARDING_LETTER
	local spec = self:Spec(id)
	if self:IsShowing() or not spec then
		return
	end
	self.preview = id
	self.options.show(spec)
end

--- The tour stop's hide (CORE-R68): the sample goes, and a letter still to show this login is checked for again.
function Letter:TourHide()
	if endPreview(self) then
		self:Check()
	end
end
