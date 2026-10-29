---@class PagleNS
local ns = select(2, ...)

-- Core's onboarding state (core/onboarding.md › Data): the account-wide table in PagleDB.global.onboarding that the
-- Letter, the Field guide, Margin notes, First looks and the First evening list read and write, who is new,
-- returning or another character (ONB-R1–R3), `/pagle guide` (ONB-R80) and the `/pagle dev onboarding` group
-- (ONB-R83). Pure logic over what it's handed (CORE-R7); logic/Wiring.lua's ns.WireOnboarding builds it over Core's
-- host, so Core's adapter and FakePagle run the same state.

--- Where the Letter stands (ONB-R2, ONB-R12): `waiting` for a new Angler, `later` after one Later, `declined` after
--- the second, `opened` once Open the letter is pressed, `returning` for an Angler whose Catch log already held a Cast.
---@alias PagleLetterState "waiting"|"later"|"declined"|"opened"|"returning"

--- The id of the onboarding Letter among the letters Core sends (ONB-R15). Its state is `letter`; a Module's letter
--- keeps its state in `letters[id]` (ONB-R16), the same four words (a returning Angler is only the onboarding Letter's).
ns.ONBOARDING_LETTER = "core.onboarding"

--- PagleDB.global.onboarding (core/onboarding.md › Data). It isn't in ns.PAGLEDB_DEFAULTS: AceDB would make it read
--- as present before it is created (ONB-R1), so it is created whole, and saved whole.
---@class PagleOnboardingState
---@field letter PagleLetterState         -- ONB-R2, ONB-R12: the onboarding Letter's (ONB-R15)
---@field letters? table<string, PagleLetterState> -- ONB-R16: each Module letter's, by id; made as the first is sent
---@field guideStep string?                -- the step id last shown (ONB-R22)
---@field stepsSeen table<string, true>    -- every step shown, by id (ONB-R22, ONB-R24)
---@field guideDone boolean                -- Off to the water was pressed (ONB-R26)
---@field skipped boolean                  -- "I'll find my own way" on the Welcome step (ONB-R26)
---@field reopen boolean                   -- a restriction closed the guide, to reopen when it ends (ONB-R25)
---@field notesOn boolean                  -- the Margin notes setting (ONB-R81)
---@field notesSeen table<string, true>    -- each Margin note shown, by id (ONB-R50)
---@field looksSeen table<string, true>    -- each First look shown, by set id (ONB-R55)
---@field evening { shown: boolean, closed: boolean, done: table<string, true> } -- the First evening list (ONB-R60–R63)
---@field characters table<string, true>   -- each character's GUID seen since the state was made (ONB-R3)

--- The onboarding state as created (core/onboarding.md › Data): every key at its default, with `letter` as given.
--- `characters` is empty: the first character's GUID goes in at its PLAYER_LOGIN (Onboarding:SeeCharacter).
---@param letter PagleLetterState
---@return PagleOnboardingState
function ns.NewOnboardingState(letter)
	return {
		letter = letter,
		guideStep = nil,
		stepsSeen = {},
		guideDone = false,
		skipped = false,
		reopen = false,
		notesOn = true,
		notesSeen = {},
		looksSeen = {},
		evening = { shown = false, closed = false, done = {} },
		characters = {},
	}
end

--- Adds `global.onboarding` if it is missing (ONB-R1), with `letter` by ONB-R2: `returning` when `catchLog` already
--- holds a Cast entry (a reinstall, a new computer with old SavedVariables, a Pagle from before onboarding), else
--- `waiting`. A table that exists is never recreated. PagleDB's migration step 2 calls it at login step 1, and
--- PLAYER_LOGIN again for a PagleDB that lost it since. Returns whether it added one.
---@param global table PagleDB.global
---@param catchLog PagleCatchLog
---@return boolean added
function ns.AddOnboarding(global, catchLog)
	if global.onboarding ~= nil then
		return false
	end
	local hasCast = catchLog:Has("cast")
	global.onboarding = ns.NewOnboardingState(hasCast and "returning" or "waiting")
	return true
end

--- The moments Core raises for a later ticket to fill (#325 shows a Margin note for each): `welcome` for a returning
--- Angler at the first SessionStarted or 20 s after login (ONB-R2, `core.welcome`), `character` at another
--- character's first login while QoL is registered (ONB-R3, `core.character`). Each is called through
--- `options.call`, so an error in one is reported, not raised.
---@alias PagleOnboardingHook "welcome"|"character"

-- The hooks Onboarding:SetHook takes.
local HOOKS = { welcome = true, character = true }

--- ONB-R2's delay: a returning Angler's welcome is due this long after PLAYER_LOGIN, unless a Session starts first.
ns.ONBOARDING_WELCOME_DELAY = 20

--- What onboarding is fed. Every function is called when needed, never stored.
---@class PagleOnboardingOptions
---@field global fun(): table                    -- PagleDB.global, which holds `onboarding` from login step 1 on
---@field call fun(fn: function, ...: any): ...   -- calls fn; an error is reported, not raised (securecallfunction)
---@field print fun(line: string)                -- prints a chat line

--- One of `/pagle dev onboarding`'s subcommands (ONB-R83).
---@class PagleOnboardingDevCommand
---@field name string             -- lowercased, the word after `/pagle dev onboarding`
---@field usage string            -- how the usage line shows it: "reset", "step <id>"
---@field fn fun(args: string)    -- gets the rest of the line, trimmed

--- Core's onboarding (core/onboarding.md): its state's reads and writes, the hooks, `/pagle guide` and the dev group.
--- Each call reads `PagleDB.global.onboarding` afresh, so a dev reset that replaces the table is seen at once; none
--- may be made before login step 1 has added it.
---@class PagleOnboarding
---@field package options PagleOnboardingOptions
---@field package hooks table<PagleOnboardingHook, function>
---@field package openGuide (fun(args: string))?
---@field package devCommands PagleOnboardingDevCommand[]
local Onboarding = {}
Onboarding.__index = Onboarding

---@param options PagleOnboardingOptions
---@return PagleOnboarding
function ns.NewOnboarding(options)
	return setmetatable({ options = options, hooks = {}, devCommands = {} }, Onboarding)
end

--- The state now: PagleDB.global.onboarding.
---@return PagleOnboardingState
function Onboarding:State()
	return self.options.global().onboarding
end

-- One of the state's sets, made again if a hand-edited PagleDB lost it.
---@param onboarding PagleOnboarding
---@param key "stepsSeen"|"notesSeen"|"looksSeen"|"characters"
---@return table<string, true>
local function set(onboarding, key)
	local state = onboarding:State()
	if type(state[key]) ~= "table" then
		state[key] = {}
	end
	return state[key]
end

-- The First evening list's table, made again if a hand-edited PagleDB lost it or its `done`.
---@param onboarding PagleOnboarding
---@return { shown: boolean, closed: boolean, done: table<string, true> }
local function evening(onboarding)
	local state = onboarding:State()
	if type(state.evening) ~= "table" then
		state.evening = { shown = false, closed = false, done = {} }
	end
	if type(state.evening.done) ~= "table" then
		state.evening.done = {}
	end
	return state.evening
end

--- Sets the function a hook calls (PagleOnboardingHook), replacing any set before. Raises an error for a hook it
--- doesn't know or a value that isn't a function.
---@param name PagleOnboardingHook
---@param fn fun()
function Onboarding:SetHook(name, fn)
	if not HOOKS[name] then
		error(("onboarding has no %s hook"):format(tostring(name)), 2)
	elseif type(fn) ~= "function" then
		error(("the %s hook must be a function"):format(name), 2)
	end
	self.hooks[name] = fn
end

-- Calls a hook's function through `call`, if one is set.
---@param onboarding PagleOnboarding
---@param name PagleOnboardingHook
local function raise(onboarding, name)
	local fn = onboarding.hooks[name]
	if fn then
		onboarding.options.call(fn)
	end
end

-- New or returning, another character (ONB-R2, ONB-R3).

--- Whether this Angler is a returning one, who gets no Letter and no First evening list (ONB-R2).
---@return boolean
function Onboarding:IsReturning()
	return self:State().letter == "returning"
end

--- The welcome-note moment (ONB-R2): raises the `welcome` hook for a returning Angler. The wiring calls it once a
--- login, at the first SessionStarted or ONBOARDING_WELCOME_DELAY s after PLAYER_LOGIN. Returns whether it raised.
---@return boolean
function Onboarding:Welcome()
	if not self:IsReturning() then
		return false
	end
	raise(self, "welcome")
	return true
end

--- PLAYER_LOGIN (ONB-R3): adds the logged-in character's GUID to `characters`. A GUID new to a list that already
--- holds another raises the `character` hook first, only while QoL is registered (ONB-R101); the first character's
--- goes in without it. Nothing happens without a GUID (LOG-R26). Returns whether it raised the hook.
---@param guid string?
---@param qolRegistered boolean
---@return boolean
function Onboarding:SeeCharacter(guid, qolRegistered)
	if type(guid) ~= "string" then
		return false
	end
	local characters = set(self, "characters")
	if characters[guid] then
		return false
	end
	local another = next(characters) ~= nil
	characters[guid] = true
	if another and qolRegistered then
		raise(self, "character")
		return true
	end
	return false
end

-- The Letter (ONB-R10, ONB-R12) and the letters a Module sends (ONB-R15, ONB-R16). A letter's id is
-- ns.ONBOARDING_LETTER for the onboarding Letter, whose state is `letter` (and is nil where an id is optional), or a
-- Module's, whose state is `letters[id]`.

-- Where letter `id`'s state is kept: the table and the key in it. A Module letter nobody has sent has no state yet.
---@param onboarding PagleOnboarding
---@param id string?
---@return table holder
---@return string key
local function letterSlot(onboarding, id)
	local state = onboarding:State()
	if id == nil or id == ns.ONBOARDING_LETTER then
		return state, "letter"
	end
	if type(state.letters) ~= "table" then
		state.letters = {}
	end
	return state.letters, id
end

--- Where the Letter stands (the onboarding Letter's by default); nil for a Module letter nobody has sent.
---@param id string?
---@return PagleLetterState?
function Onboarding:Letter(id)
	local holder, key = letterSlot(self, id)
	return holder[key]
end

--- Whether letter `id` is still due, so ONB-R10 shows it once this login when its conditions hold: `waiting` or
--- `later`. A Module's letter nobody has sent isn't: it becomes `waiting` as its Module sends it (ONB-R16).
---@param id string?
---@return boolean
function Onboarding:IsLetterDue(id)
	local letter = self:Letter(id)
	return letter == "waiting" or letter == "later"
end

--- A Module sends letter `id` (ONB-R16): one with no state yet becomes `waiting`. Returns whether it is due, which a
--- `declined` or `opened` letter never is.
---@param id string
---@return boolean due
function Onboarding:RaiseLetter(id)
	local holder, key = letterSlot(self, id)
	if holder[key] == nil then
		holder[key] = "waiting"
	end
	return self:IsLetterDue(id)
end

--- Open the letter (ONB-R12): `opened`, so it never shows again.
---@param id string?
function Onboarding:OpenLetter(id)
	local holder, key = letterSlot(self, id)
	holder[key] = "opened"
end

--- Later (ONB-R12): from `waiting` to `later`, so the next login shows it once more; from `later` to `declined`. Any
--- other state stays. Returns the state after.
---@param id string?
---@return PagleLetterState
function Onboarding:LetterLater(id)
	local holder, key = letterSlot(self, id)
	if holder[key] == "waiting" then
		holder[key] = "later"
	elseif holder[key] == "later" then
		holder[key] = "declined"
	end
	return holder[key]
end

-- The Field guide (ONB-R22, ONB-R25, ONB-R26).

--- The step id last shown, where the guide reopens if that step is still registered (ONB-R22); nil before any.
---@return string?
function Onboarding:GuideStep()
	return self:State().guideStep
end

--- A step shown (ONB-R22): `guideStep` becomes its id and it joins `stepsSeen` (its ribbon's tick, ONB-R24).
---@param id string
function Onboarding:StepShown(id)
	self:State().guideStep = id
	set(self, "stepsSeen")[id] = true
end

--- Whether a step has been shown (ONB-R24).
---@param id string
---@return boolean
function Onboarding:IsStepSeen(id)
	return set(self, "stepsSeen")[id] == true
end

--- Off to the water (ONB-R26): the guide is done.
function Onboarding:FinishGuide()
	self:State().guideDone = true
end

---@return boolean
function Onboarding:IsGuideDone()
	return self:State().guideDone == true
end

--- "I'll find my own way" on the Welcome step (ONB-R26): the Angler skipped the guide, so no First evening list
--- (ONB-R60).
function Onboarding:SkipGuide()
	self:State().skipped = true
end

---@return boolean
function Onboarding:IsSkipped()
	return self:State().skipped == true
end

--- Whether the guide reopens when the restriction ends (ONB-R25): set as a restriction closes it, cleared as it
--- reopens.
---@param reopen boolean
function Onboarding:SetReopen(reopen)
	self:State().reopen = reopen
end

---@return boolean
function Onboarding:ShouldReopen()
	return self:State().reopen == true
end

-- Margin notes and First looks (ONB-R50, ONB-R55, ONB-R59, ONB-R81).

--- The Margin notes setting (ONB-R81): with it off, no Margin note or First look shows on its own (ONB-R50, ONB-R55).
---@return boolean
function Onboarding:AreNotesOn()
	return self:State().notesOn ~= false
end

---@param on boolean
function Onboarding:SetNotesOn(on)
	self:State().notesOn = on
end

--- Whether a Margin note has shown (ONB-R50).
---@param id string "<module>.<name>"
---@return boolean
function Onboarding:IsNoteSeen(id)
	return set(self, "notesSeen")[id] == true
end

--- A Margin note shows (ONB-R50): it never shows on its own again.
---@param id string
function Onboarding:MarkNoteSeen(id)
	set(self, "notesSeen")[id] = true
end

--- Whether a First look has shown (ONB-R55).
---@param id string "<module>.<window>"
---@return boolean
function Onboarding:IsLookSeen(id)
	return set(self, "looksSeen")[id] == true
end

--- A First look shows (ONB-R55, ONB-R59): opening its window doesn't show it again.
---@param id string
function Onboarding:MarkLookSeen(id)
	set(self, "looksSeen")[id] = true
end

--- `/pagle guide notes` and the Settings root's Show them again (ONB-R80, ONB-R81): every Margin note and First look
--- shows again, once each. The Margin notes setting stays as it is.
function Onboarding:ShowNotesAgain()
	local state = self:State()
	state.notesSeen, state.looksSeen = {}, {}
end

-- The First evening list (ONB-R60–R63).

--- Whether the list has docked once (ONB-R60).
---@return boolean
function Onboarding:IsEveningShown()
	return evening(self).shown == true
end

--- The list docks for the first time (ONB-R60).
function Onboarding:MarkEveningShown()
	evening(self).shown = true
end

--- Whether the list is closed, by its close mark or folded away when done (ONB-R62, ONB-R63).
---@return boolean
function Onboarding:IsEveningClosed()
	return evening(self).closed == true
end

--- Closes the list (ONB-R62, ONB-R63).
function Onboarding:CloseEvening()
	evening(self).closed = true
end

--- The Settings root's First evening list checkbox (ONB-R63): the list shows again, unclosed.
function Onboarding:ReopenEvening()
	evening(self).closed = false
end

--- Whether an item is done (ONB-R61).
---@param id string
---@return boolean
function Onboarding:IsEveningItemDone(id)
	return evening(self).done[id] == true
end

--- An item's owner says it's done (ONB-R61): kept even before the list docks, so it shows ticked; ignored when the
--- list is closed or the item already done. Returns whether it was marked now.
---@param id string
---@return boolean
function Onboarding:CompleteEveningItem(id)
	local list = evening(self)
	if list.closed or list.done[id] then
		return false
	end
	list.done[id] = true
	return true
end

-- /pagle guide (ONB-R80, CORE-R61).

--- Sets what `/pagle guide` opens the guide with (#322): it gets the rest of the line, trimmed, and opens at
--- `guideStep` (ONB-R22) or as its args say.
---@param open fun(args: string)
function Onboarding:SetGuideOpener(open)
	self.openGuide = open
end

--- `/pagle guide [args]` (ONB-R80): `notes` shows Margin notes and First looks again (ShowNotesAgain) and prints
--- "Pagle: margin notes will show again, once each."; anything else opens the guide. Until something sets the guide's
--- opener (#322), it returns `"help"`, and /pagle prints its help list instead.
---@param args string what follows `/pagle guide`
---@return "help"?
function Onboarding:Guide(args)
	if ns.ParseSlash(args) == "notes" then
		self:ShowNotesAgain()
		self.options.print(ns.L.GUIDE_NOTES_AGAIN)
		return nil
	end
	local open = self.openGuide
	if not open then
		return "help"
	end
	open((args:match("^%s*(.-)%s*$")))
	return nil
end

-- /pagle dev onboarding (ONB-R83).

--- `/pagle dev onboarding reset` (ONB-R83): the state as created for a new Angler (`letter = "waiting"`, everything
--- else default, no Module letter sent yet, ONB-R17), whatever the Catch log holds, with `guid`, the logged-in
--- character's, in `characters`.
---@param guid string
function Onboarding:Reset(guid)
	local state = ns.NewOnboardingState("waiting")
	state.characters[guid] = true
	self.options.global().onboarding = state
end

--- Adds a subcommand to `/pagle dev onboarding` (ONB-R83): `/pagle dev onboarding <name> <args>` calls `fn(args)`.
--- Each piece adds its own (`letter`, `step <id>`, `note <id>`, `look <id>`, `evening`) as it arrives; Core's wiring
--- adds `reset`. Dev mode gates them all (ns.dev). Raises an error for a name added before, case-insensitively, or a
--- non-function.
---@param name string one word
---@param usage string how the usage line shows it, such as "step <id>"
---@param fn fun(args: string)
function Onboarding:AddDevCommand(name, usage, fn)
	local key = name:lower()
	for _, command in ipairs(self.devCommands) do
		if command.name == key then
			error(("/pagle dev onboarding %s is added already"):format(key), 2)
		end
	end
	if type(fn) ~= "function" then
		error(("/pagle dev onboarding %s has no function"):format(key), 2)
	end
	self.devCommands[#self.devCommands + 1] = { name = key, usage = usage, fn = fn }
end

--- Runs `/pagle dev onboarding <args>` (ONB-R83): the subcommand it names, with the rest of the line, or for none or
--- an unknown one the group's usage line, each subcommand in the order added.
---@param args string what follows `/pagle dev onboarding`
function Onboarding:RunDev(args)
	local name, rest = ns.ParseSlash(args)
	for _, command in ipairs(self.devCommands) do
		if command.name == name then
			command.fn(rest)
			return
		end
	end
	local usages = {}
	for i, command in ipairs(self.devCommands) do
		usages[i] = command.usage
	end
	self.options.print(ns.L.DEV_ONBOARDING_USAGE:format(table.concat(usages, " | ")))
end
