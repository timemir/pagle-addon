---@class PagleNS
local ns = select(2, ...)

-- First looks (core/onboarding.md › First looks): a set of numbered Margin notes on one window, shown together the
-- first time it opens, with the coach bar under it (ONB-R55). What makes a set one a Module may register (ONB-R56,
-- ONB-R90), the registry, which set shows and when (once per account with Margin notes on, or on the window's "?"
-- whatever was seen, ONB-R59), which of its notes show and how they're numbered (a hidden target drops its note,
-- ONB-R56), where each note goes beside its window (ONB-R58), and the tour's showing, which marks nothing (ONB-R84).
-- Pure logic over what it's handed (CORE-R7): logic/Wiring.lua's ns.WireFirstLooks builds it over Core's host and a
-- view, Core's adapter/FirstLooks.lua draws it, and FakePagle runs the same sets over its records.

--- One note of a First look (Contracts): its text (*term* or |cff9a2a1a…|r marks the red term), what it points at now
--- (nil while that isn't there: the note drops), and where it sits, in the window's units from its top left: a
--- negative `x` puts it in the left margin, one past the window's width in the right (ONB-R58).
---@class PagleFirstLookNote
---@field text string
---@field target fun(): Region?
---@field x number
---@field y number
---@field w number

--- A First look (Contracts): `window` is the window's frame, or a function returning it (nil until it's made), so a
--- set can register before its window exists. `open`, if given, opens the window as the Angler would, for the tour
--- (ONB-R84); without it the tour shows the window's frame.
---@class PagleFirstLook
---@field id string                       -- "<module>.<window>"
---@field window Frame|fun(): Frame?      -- the window the set belongs to
---@field title string                    -- "the Fish Journal" (the bar reads "First look · {title}")
---@field notes PagleFirstLookNote[]
---@field open? fun()

--- A note of the set on screen: which of the set's notes (`index`), its number now (`n`, ONB-R56: the shown ones count
--- 1 to n), and what it points at now, read each time (nil once it's gone).
---@class PagleLookEntry
---@field index integer
---@field n integer
---@field target fun(): Region?

--- How long after the one before each note of a set starts moving in (core/onboarding.md › Motion).
ns.LOOK_NOTE_STAGGER = 0.12
--- The free margin beside a window below which its notes overlap its edge (ONB-R58; Tunables).
ns.LOOK_FREE_MARGIN = 210
-- How far a note that overlaps the window's edge stays inside the screen's.
local EDGE = 8

-- A number that is one (not NaN).
---@param value any
---@return boolean
local function isNumber(value)
	return type(value) == "number" and value == value
end

--- Why a set can't be registered, or nil if it can (Contracts, ONB-R90): an id `<module>.<name>` with the Module's
--- name lowercased, a window (a frame, or a function returning it), a title, and at least one note, each with a text,
--- a target function and its x, y and w (w above 0); `open`, if given, a function.
---@param set any
---@param module string the Module's def.name, or Core's
---@return string?
function ns.FirstLookProblem(set, module)
	if type(set) ~= "table" then
		return "RegisterFirstLook takes a set table, got " .. type(set)
	end
	if type(set.id) ~= "string" or set.id == "" then
		return "RegisterFirstLook: a set needs an id"
	end
	local prefix = module:lower() .. "."
	if set.id:sub(1, #prefix) ~= prefix or #set.id == #prefix then
		return ("RegisterFirstLook: a set's id is %s<window>, got %s"):format(prefix, set.id)
	end
	local id = set.id
	if type(set.window) ~= "table" and type(set.window) ~= "function" then
		return ("RegisterFirstLook: set %s needs its window, a frame or a function returning it"):format(id)
	end
	if type(set.title) ~= "string" or set.title == "" then
		return ("RegisterFirstLook: set %s needs a title"):format(id)
	end
	if set.open ~= nil and type(set.open) ~= "function" then
		return ("RegisterFirstLook: set %s's open is a function, got %s"):format(id, type(set.open))
	end
	if type(set.notes) ~= "table" or set.notes[1] == nil then
		return ("RegisterFirstLook: set %s needs its notes"):format(id)
	end
	for i, note in ipairs(set.notes) do
		if type(note) ~= "table" then
			return ("RegisterFirstLook: set %s's note %d isn't a table"):format(id, i)
		elseif type(note.text) ~= "string" or note.text == "" then
			return ("RegisterFirstLook: set %s's note %d needs a text"):format(id, i)
		elseif type(note.target) ~= "function" then
			return ("RegisterFirstLook: set %s's note %d needs a target function"):format(id, i)
		elseif not (isNumber(note.x) and isNumber(note.y) and isNumber(note.w)) or note.w <= 0 then
			return ("RegisterFirstLook: set %s's note %d needs its x, y and w (w above 0)"):format(id, i)
		end
	end
	return nil
end

--- Where a note of a set sits (ONB-R58): its anchor on the window, the note an unscaled frame in UIParent. In the left
--- margin (its right edge left of the window) its right edge keeps its gap to the window's left edge, and in the right
--- margin (its left edge past the window's width) its left edge keeps its gap to the window's right edge; a note over
--- the window sits where it says, scaled with the window. Down from the window's top, its `y` scaled with the window.
--- With less than LOOK_FREE_MARGIN free on its side (`free`, nil while the window isn't laid out) a margin note
--- overlaps the window's edge, held just inside the screen.
---@param note { x: number, y: number, w: number }
---@param window { width: number, scale: number, free: { left: number, right: number }? } its width in its own units,
--- its scale against UIParent's, and the room between it and each side of the screen, in UIParent's units
---@return { relativePoint: "TOPLEFT"|"TOPRIGHT", x: number, y: number }
function ns.PlaceLookNote(note, window)
	local k, free = window.scale, window.free
	local y = -note.y * k
	if note.x + note.w <= 0 then
		local x = note.x
		if free and free.left < ns.LOOK_FREE_MARGIN then
			x = EDGE - free.left
		end
		return { relativePoint = "TOPLEFT", x = x, y = y }
	elseif note.x >= window.width then
		local x = note.x - window.width
		if free and free.right < ns.LOOK_FREE_MARGIN then
			x = free.right - EDGE - note.w
		end
		return { relativePoint = "TOPRIGHT", x = x, y = y }
	end
	return { relativePoint = "TOPLEFT", x = note.x * k, y = y }
end

--- Where a set is drawn: Core's adapter's frames, FakePagle's records.
---@class PagleFirstLooksView
---@field show fun(set: PagleFirstLook, entries: PagleLookEntry[]) -- the notes beside the window, numbered, moving in
--- 0.12 s apart with `noteIn` once, and the coach bar under it (ONB-R55)
---@field renumber fun(set: PagleFirstLook, entries: PagleLookEntry[]) -- a note dropped: the rest renumbered, at once
---@field hide fun(set: PagleFirstLook) -- the notes and the bar off screen
---@field isShown fun(region: Region): boolean -- whether a target is on screen now (shown and laid out)

--- What the sets are fed. Every function is called when needed, never stored.
---@class PagleFirstLooksOptions
---@field onboarding fun(): PagleOnboarding -- notesOn and looksSeen (ONB-R55)
---@field call fun(fn: function, ...: any): ... -- runs a Module's function, reporting an error and returning nothing
---@field view PagleFirstLooksView

-- A registered set and its owner.
---@class PagleLookRecord
---@field owner string
---@field set PagleFirstLook

--- The First looks: every registered set and the one on screen (ONB-R55–R59).
---@class PagleFirstLooks
---@field package options PagleFirstLooksOptions
---@field package records table<string, PagleLookRecord> by id
---@field package order string[] ids, as registered
---@field package showing { set: PagleFirstLook, entries: PagleLookEntry[] }?
---@field package tour { id: string, wasShown: boolean }? the tour stop showing a set (ONB-R84)
local FirstLooks = {}
FirstLooks.__index = FirstLooks

---@param options PagleFirstLooksOptions
---@return PagleFirstLooks
function ns.NewFirstLooks(options)
	return setmetatable({ options = options, records = {}, order = {} }, FirstLooks)
end

--- Adds `owner`'s set, a copy, so a later change to the caller's table changes nothing. Returns why it can't, adding
--- nothing: a mistake ns.FirstLookProblem names, or an id registered before.
---@param owner string a Module's def.name, or ns.CORE_OWNER
---@param set PagleFirstLook
---@return string? problem
function FirstLooks:Add(owner, set)
	local problem = ns.FirstLookProblem(set, owner)
	if problem then
		return problem
	end
	if self.records[set.id] then
		return ("RegisterFirstLook: set %s is already registered"):format(set.id)
	end
	local notes = {}
	for i, note in ipairs(set.notes) do
		notes[i] = { text = note.text, target = note.target, x = note.x, y = note.y, w = note.w }
	end
	local copy = { id = set.id, window = set.window, title = set.title, notes = notes, open = set.open }
	self.records[set.id] = { owner = owner, set = copy }
	self.order[#self.order + 1] = set.id
	return nil
end

--- Who registered set `id`, or nil for one never registered.
---@param id string
---@return string?
function FirstLooks:Owner(id)
	local record = self.records[id]
	return record and record.owner
end

--- Every set, as registered: each with its owner.
---@return PagleLookRecord[]
function FirstLooks:List()
	local list = {}
	for i, id in ipairs(self.order) do
		list[i] = self.records[id]
	end
	return list
end

--- Set `id`'s window now, nil while it isn't made (or for an unknown id).
---@param id string
---@return Frame?
function FirstLooks:Window(id)
	local record = self.records[id]
	if not record then
		return nil
	end
	local window = record.set.window
	if type(window) == "function" then
		return self.options.call(window)
	end
	return window --[[@as Frame]]
end

-- `fn` read through `call`, so a Module's target that raises is reported once and drops its note from then on.
---@param call fun(fn: function, ...: any): ...
---@param fn fun(): Region?
---@return fun(): Region?
local function guarded(call, fn)
	local broken = false
	return function()
		if broken then
			return nil
		end
		local finished = false
		local region = call(function()
			local found = fn()
			finished = true
			return found
		end)
		if not finished then
			broken = true
			return nil
		end
		return type(region) == "table" and region or nil
	end
end

-- Puts `set` on screen with each note whose target shows now, numbered 1 to n (ONB-R56), in place of any set showing
-- (one at a time). Marks it seen with `mark` (ONB-R55). Nothing, and nothing marked, when none of its targets shows.
---@param looks PagleFirstLooks
---@param set PagleFirstLook
---@param mark boolean
---@return boolean shown
local function display(looks, set, mark)
	local view, call = looks.options.view, looks.options.call
	local entries = {}
	for i, note in ipairs(set.notes) do
		local target = guarded(call, note.target)
		local region = target()
		if region and view.isShown(region) then
			entries[#entries + 1] = { index = i, n = #entries + 1, target = target }
		end
	end
	if #entries == 0 then
		return false
	end
	looks:Hide()
	if mark then
		looks.options.onboarding():MarkLookSeen(set.id)
	end
	looks.showing = { set = set, entries = entries }
	view.show(set, entries)
	return true
end

--- Shows set `id` (ONB-R55, ONB-R59): from its window's OnShow, once per account and only with Margin notes on; with
--- `again` (the window's "?"), whether or not it was seen and whether or not Margin notes is on, or, while it shows,
--- hides it. Marks it seen as it shows. Nothing while a tour stop shows a set (ONB-R84). Returns whether it shows.
---@param id string
---@param again boolean?
---@return boolean
function FirstLooks:Show(id, again)
	local record = self.records[id]
	if not record or self.tour then
		return false
	end
	local showing = self.showing
	if showing and showing.set.id == id then
		if again then
			self:Hide()
			return false
		end
		return true
	end
	if not again then
		local onboarding = self.options.onboarding()
		if not onboarding:AreNotesOn() or onboarding:IsLookSeen(id) then
			return false
		end
	end
	return display(self, record.set, true)
end

--- `/pagle dev onboarding look <id>` (ONB-R83): shows set `id` now, however Margin notes and looksSeen stand, marking
--- nothing. Its window must be open. Returns "shown", "closed" (its window isn't open), "empty" (none of its targets
--- shows) or "unknown".
---@param id string
---@return "shown"|"closed"|"empty"|"unknown"
function FirstLooks:ShowNow(id)
	local record = self.records[id]
	if not record then
		return "unknown"
	end
	local window = self:Window(id)
	if not (window and window:IsShown()) then
		return "closed"
	end
	return display(self, record.set, false) and "shown" or "empty"
end

--- Hides the set on screen, if one is: the coach bar's link (ONB-R55), the "?" pressed again (ONB-R59).
function FirstLooks:Hide()
	local showing = self.showing
	if showing then
		self.showing = nil
		self.options.view.hide(showing.set)
	end
end

--- Set `id`'s window closed, or Esc closed it (ONB-R55): its set goes with it.
---@param id string
function FirstLooks:WindowHidden(id)
	local showing = self.showing
	if showing and showing.set.id == id then
		self:Hide()
	end
end

--- A note's target hid (ONB-R56): set `id`'s note `index` drops and the rest close up, renumbered; the set goes with
--- its last note.
---@param id string
---@param index integer
function FirstLooks:TargetHidden(id, index)
	local showing = self.showing
	if not (showing and showing.set.id == id) then
		return
	end
	local entries = {}
	for _, entry in ipairs(showing.entries) do
		if entry.index ~= index then
			entry.n = #entries + 1
			entries[#entries + 1] = entry
		end
	end
	if #entries == #showing.entries then
		return
	end
	if #entries == 0 then
		self:Hide()
		return
	end
	showing.entries = entries
	self.options.view.renumber(showing.set, entries)
end

--- The set on screen: its id and the notes showing, each as { index, n }; nil while none shows.
---@return { id: string, notes: { index: integer, n: integer }[] }?
function FirstLooks:Showing()
	local showing = self.showing
	if not showing then
		return nil
	end
	local notes = {}
	for i, entry in ipairs(showing.entries) do
		notes[i] = { index = entry.index, n = entry.n }
	end
	return { id = showing.set.id, notes = notes }
end

--- The tour stop `core.onboarding.look.<id>` (ONB-R84): opens set `id`'s window (its `open`, else its frame's Show),
--- then shows the set, marking nothing; the window's own ShowFirstLook does nothing meanwhile.
---@param id string
function FirstLooks:TourShow(id)
	local record = self.records[id]
	if not record then
		return
	end
	local window = self:Window(id)
	self.tour = { id = id, wasShown = window ~= nil and window:IsShown() }
	if not self.tour.wasShown then
		if record.set.open then
			self.options.call(record.set.open)
		elseif window then
			window:Show()
		end
	end
	display(self, record.set, false)
end

--- The tour stop's hide (CORE-R68): the set goes, and its window closes unless it was open before the stop.
function FirstLooks:TourHide()
	local tour = self.tour
	if not tour then
		return
	end
	self:Hide()
	self.tour = nil
	local window = self:Window(tour.id)
	if not tour.wasShown and window and window:IsShown() then
		window:Hide()
	end
end
