---@class PagleNS
local ns = select(2, ...)

-- Margin notes (core/onboarding.md › Margin notes): a slip of paper in the Angler's pencil beside the thing it
-- explains, with a pencil arrow to a red ring on it. What makes a note a Module may show (ONB-R50, ONB-R90), once per
-- account and only with Margin notes on (ONB-R50), how long one stays and what holds or drops it (ONB-R51), Core's
-- own first-moment notes for an Announcement, a card and a moment's `firstNote` (ONB-R52, ONB-R53), and where a note
-- and its arrow go (core/onboarding.md › UI). Pure logic over what it's handed (CORE-R7): logic/Wiring.lua's
-- ns.WireMarginNotes builds it over Core's host and a view, Core's adapter/MarginNotes.lua draws it, and FakePagle runs
-- the same notes over its records.

--- A Margin note (Contracts): `M:ShowMarginNote(note)`'s, or one of Core's own, whose `target` may be a function
--- returning the region it points at now (nil once it's gone): Core's notes follow a frame that is reused, or Pagle's
--- menu button, which moves between the minimap icon and the compartment (ONB-R108).
---@class PagleMarginNote
---@field id string                                -- "<module>.<name>"
---@field text string                              -- |cff9a2a1a…|r marks the red term
---@field target Region|PagleNoteTarget            -- what the arrow points at
---@field side? "LEFT"|"RIGHT"|"ABOVE"|"BELOW"     -- where the note sits; default: the side with most room
---@field alsoSeen? string[]                       -- Core's: more ids marked seen as it shows (ONB-R53's firstNote)

--- What a Core note points at: the region now, nil once it's gone.
---@alias PagleNoteTarget fun(): Region?

--- How long a note stays at most (ONB-R51; Tunables).
ns.MARGIN_NOTE_LIFETIME = 12

-- The sides a note may sit on (Contracts).
local SIDES = { LEFT = true, RIGHT = true, ABOVE = true, BELOW = true }

--- Why a Module's note can't be shown, or nil if it can (Contracts, ONB-R90): an id `<module>.<name>` with the Module's
--- name lowercased, a text, a target region and, if given, a side.
---@param note any
---@param module string the Module's def.name
---@return string?
function ns.MarginNoteProblem(note, module)
	if type(note) ~= "table" then
		return "ShowMarginNote takes a note table, got " .. type(note)
	end
	if type(note.id) ~= "string" or note.id == "" then
		return "ShowMarginNote: a note needs an id"
	end
	local prefix = module:lower() .. "."
	if note.id:sub(1, #prefix) ~= prefix or #note.id == #prefix then
		return ("ShowMarginNote: a note's id is %s<name>, got %s"):format(prefix, note.id)
	end
	if type(note.text) ~= "string" or note.text == "" then
		return "ShowMarginNote: note " .. note.id .. " needs a text"
	end
	if type(note.target) ~= "table" then
		return "ShowMarginNote: note " .. note.id .. " needs a target region"
	end
	if note.side ~= nil and not SIDES[note.side] then
		return ("ShowMarginNote: note %s's side is LEFT, RIGHT, ABOVE or BELOW, got %s"):format(
			note.id,
			tostring(note.side)
		)
	end
	return nil
end

--- `text` with each *term* in the red pencil (ONB-R50; the kit's P.Red): Core's note texts mark their term so.
---@param text string
---@return string
function ns.RedPencil(text)
	return (text:gsub("%*(.-)%*", "|cff9a2a1a%1|r"))
end

--- Core's own notes (ONB-R52), by id: each one's text in ns.L, and which target it points at, as the view resolves it:
--- `nod` the Nod, `coin` a toast's coin, `card` the card, `menu` Pagle's menu button.
---@type table<string, { text: string, target: "nod"|"coin"|"card"|"menu" }>
ns.CORE_MARGIN_NOTES = {
	["core.nod"] = { text = "NOTE_NOD", target = "nod" },
	["core.toast"] = { text = "NOTE_TOAST", target = "coin" },
	["core.summary"] = { text = "NOTE_SUMMARY", target = "card" },
	["core.uncharted"] = { text = "NOTE_UNCHARTED", target = "nod" },
	["core.welcome"] = { text = "NOTE_WELCOME", target = "menu" },
	["core.character"] = { text = "NOTE_CHARACTER", target = "menu" },
}

--- One of Core's notes, by id, pointing at `target`.
---@param id string a key of ns.CORE_MARGIN_NOTES
---@param target fun(): Region?
---@return PagleMarginNote
function ns.CoreMarginNote(id, target)
	local core = assert(ns.CORE_MARGIN_NOTES[id], "no Core margin note " .. tostring(id))
	return { id = id, text = ns.RedPencil(ns.L[core.text]), target = target }
end

--- The id of a moment's own note (ONB-R53): `{module}.{kind}`, the Module's name lowercased.
---@param moment PagleRaisedMoment
---@return string
function ns.MomentNoteId(moment)
	return moment.module:lower() .. "." .. moment.kind
end

--- Where the notes are drawn: Core's adapter's frames, FakePagle's records. Each gets the note as shown.
---@class PagleMarginNotesView
---@field show fun(note: PagleMarginNote)                  -- puts it beside its target, moving in (MOTION.md)
---@field hide fun(note: PagleMarginNote, atOnce: boolean) -- takes it away; at once for a restriction
---@field place fun(note: PagleMarginNote)                 -- draws its arrow to where its target is now, without motion
---@field isShown fun(note: PagleMarginNote): boolean      -- whether its target is on screen now

--- What the notes are fed. Every function is called when needed, never stored.
---@class PagleMarginNotesOptions
---@field onboarding fun(): PagleOnboarding       -- notesOn and notesSeen (ONB-R50)
---@field isRestricted fun(): boolean             -- Pagle.IsRestricted() (ONB-R51)
---@field after fun(seconds: number, fn: fun())   -- runs fn `seconds` from now (C_Timer.After)
---@field view PagleMarginNotesView

-- A note on screen: the note, and the count its lifetime timer checks, so a timer from an earlier showing does nothing.
---@class PagleShowingNote
---@field note PagleMarginNote
---@field showing integer

--- The notes Core shows, on screen and waiting (ONB-R50, ONB-R51).
---@class PagleMarginNotes
---@field package options PagleMarginNotesOptions
---@field package showing PagleShowingNote[]   -- on screen, in the order shown
---@field package held { note: PagleMarginNote, shown: boolean }[] -- waiting for the restriction to end, in order
---@field package shows integer                -- notes shown so far, for each showing's count
local MarginNotes = {}
MarginNotes.__index = MarginNotes

---@param options PagleMarginNotesOptions
---@return PagleMarginNotes
function ns.NewMarginNotes(options)
	return setmetatable({ options = options, showing = {}, held = {}, shows = 0 }, MarginNotes)
end

-- The index of the note `id` in `list` (of entries with a `note`), or nil.
---@param list { note: PagleMarginNote }[]
---@param id string
---@return integer?
local function indexOf(list, id)
	for i, entry in ipairs(list) do
		if entry.note.id == id then
			return i
		end
	end
	return nil
end

-- Puts `note` on screen for its lifetime (ONB-R51), marking it seen (and any `alsoSeen`) when `mark` (ONB-R50).
---@param notes PagleMarginNotes
---@param note PagleMarginNote
---@param mark boolean
local function display(notes, note, mark)
	if mark then
		local onboarding = notes.options.onboarding()
		onboarding:MarkNoteSeen(note.id)
		for _, id in ipairs(note.alsoSeen or {}) do
			onboarding:MarkNoteSeen(id)
		end
	end
	notes.shows = notes.shows + 1
	local entry = { note = note, showing = notes.shows }
	notes.showing[#notes.showing + 1] = entry
	notes.options.view.show(note)
	local showing = entry.showing
	notes.options.after(ns.MARGIN_NOTE_LIFETIME, function()
		if entry.showing == showing and indexOf(notes.showing, note.id) then
			notes:Leave(note.id)
		end
	end)
end

-- Whether `id` is on screen or waiting.
---@param notes PagleMarginNotes
---@param id string
---@return boolean
local function pending(notes, id)
	return indexOf(notes.showing, id) ~= nil or indexOf(notes.held, id) ~= nil
end

--- Shows a note beside its target (ONB-R50, ONB-R51): nothing with Margin notes off, for a note seen before, or for
--- one on screen or waiting already. While restricted it waits for the restriction to end. Returns whether it shows
--- or waits.
---@param note PagleMarginNote
---@return boolean
function MarginNotes:Show(note)
	local onboarding = self.options.onboarding()
	if not onboarding:AreNotesOn() or onboarding:IsNoteSeen(note.id) or pending(self, note.id) then
		return false
	end
	if self.options.isRestricted() then
		self.held[#self.held + 1] = { note = note, shown = false }
		return true
	end
	display(self, note, true)
	return true
end

--- Shows a note now, however Margin notes and notesSeen stand, marking nothing: `/pagle dev onboarding note <id>`
--- (ONB-R83). Nothing for one on screen already. Returns whether it shows.
---@param note PagleMarginNote
---@return boolean
function MarginNotes:ShowNow(note)
	if indexOf(self.showing, note.id) then
		return false
	end
	display(self, note, false)
	return true
end

--- Takes a note on screen away (ONB-R51): it was clicked, or its time is up. Nothing for one not on screen.
---@param id string
function MarginNotes:Leave(id)
	local i = indexOf(self.showing, id)
	if i then
		local entry = table.remove(self.showing, i)
		self.options.view.hide(entry.note, false)
	end
end

--- The note's target hid (ONB-R51): the note leaves with it.
---@param id string
function MarginNotes:TargetHidden(id)
	self:Leave(id)
end

--- RestrictionChanged (ONB-R51): as a restriction starts, each note on screen goes at once and waits with the rest;
--- as it ends, each one waiting shows if its target is on screen, and is dropped, unseen, if not. One that hadn't shown
--- yet is checked again against Margin notes and notesSeen.
---@param isRestricted boolean
function MarginNotes:RestrictionChanged(isRestricted)
	if isRestricted then
		local showing = self.showing
		self.showing = {}
		for i, entry in ipairs(showing) do
			self.options.view.hide(entry.note, true)
			table.insert(self.held, i, { note = entry.note, shown = true })
		end
		return
	end
	local held = self.held
	self.held = {}
	local onboarding = self.options.onboarding()
	for _, entry in ipairs(held) do
		local note = entry.note
		if self.options.view.isShown(note) then
			if entry.shown then
				display(self, note, false)
			elseif onboarding:AreNotesOn() and not onboarding:IsNoteSeen(note.id) then
				display(self, note, true)
			end
		end
	end
end

--- Draws each note's arrow on screen again to where its target is now (ONB-R108: Pagle's menu button moved).
function MarginNotes:Retarget()
	for _, entry in ipairs(self.showing) do
		self.options.view.place(entry.note)
	end
end

--- The notes on screen now, in the order shown.
---@return PagleMarginNote[]
function MarginNotes:Showing()
	local list = {}
	for i, entry in ipairs(self.showing) do
		list[i] = entry.note
	end
	return list
end

--- The regions an Announcement's frame offers a note, each resolved when read (nil once the frame shows another).
---@class PagleAnnouncementTargets
---@field frame fun(): Region?
---@field coin fun(): Region?

--- An Announcement has shown (ONB-R52, ONB-R53): Core's first-moment notes for it. A Nod shows `core.uncharted` for an
--- Uncharted Catch (`uncharted`: its Cast caught an item no catalogue has), else `core.nod` for the catch Nod; the
--- first toast with Coins shows `core.toast` at its coin, prefixed by the `firstNote` of its first moment whose
--- `{module}.{kind}` note isn't seen yet, which it marks seen too; otherwise that moment's own note shows beside the
--- frame. Samples (`/pagle dev preview`'s, the Curio Shop's in their own style) and the "While you were fighting"
--- digest show none. A moment held by Cozy
--- mode never shows, so it never gets here (ONB-R52).
---@param announcement PagleAnnouncement
---@param form PagleAnnouncementForm
---@param targets PagleAnnouncementTargets
---@param uncharted boolean
function MarginNotes:AnnouncementShown(announcement, form, targets, uncharted)
	local headline = announcement.headline
	if headline.kind == "devPreview" or announcement.style or announcement.fighting then
		return
	end
	if form == "nod" then
		if uncharted then
			self:Show(ns.CoreMarginNote("core.uncharted", targets.frame))
		elseif headline.catchNod then
			self:Show(ns.CoreMarginNote("core.nod", targets.frame))
		end
	end
	local onboarding = self.options.onboarding()
	local first
	for _, moment in ipairs(announcement.moments) do
		if type(moment.firstNote) == "string" and not onboarding:IsNoteSeen(ns.MomentNoteId(moment)) then
			first = moment
			break
		end
	end
	if form == "toast" and announcement.coins > 0 and not onboarding:IsNoteSeen("core.toast") then
		local note = ns.CoreMarginNote("core.toast", targets.coin)
		if first then
			note.text = first.firstNote .. " " .. note.text
			note.alsoSeen = { ns.MomentNoteId(first) }
		end
		if self:Show(note) then
			return
		end
	end
	if first then
		self:Show({ id = ns.MomentNoteId(first), text = first.firstNote, target = targets.frame })
	end
end

--- A card has shown (ONB-R52): the first Session summary card shows `core.summary` beside it. A Write-up card or a
--- `/pagle dev preview card` sample shows none.
---@param card PagleCard
---@param target fun(): Region?
function MarginNotes:CardShown(card, target)
	if card.numbers and not card.preview then
		self:Show(ns.CoreMarginNote("core.summary", target))
	end
end

-- Where a note and its arrow go (core/onboarding.md › UI). Rectangles are { left, right, bottom, top } in UIParent's
-- units, y growing upward, as the client's GetLeft, GetRight, GetBottom and GetTop read.

---@class PagleRect
---@field left number
---@field right number
---@field bottom number
---@field top number

--- The room between a note and its target, for the arrow.
ns.MARGIN_NOTE_GAP = 40
-- How far a note stays inside the screen's edge.
local EDGE = 8
-- Where a note beside its target starts its arrow: this far below its top (the kit's P.Pointed).
local ARROW_DROP = 30

-- Each side, in the order a tie goes.
local SIDE_ORDER = { "RIGHT", "LEFT", "ABOVE", "BELOW" }

--- Where a note `width` x `height` sits beside `target` on a screen `screen.width` x `screen.height` (ONB-R50): on
--- `side`, or the side with most room past the note itself, MARGIN_NOTE_GAP from the target; beside it, its top
--- ARROW_DROP above the target's middle; above or below it, centred on it. Held EDGE inside the screen (ONB-R106).
---@param target PagleRect
---@param width number
---@param height number
---@param screen { width: number, height: number }
---@param side ("LEFT"|"RIGHT"|"ABOVE"|"BELOW")?
---@return { left: number, top: number, side: "LEFT"|"RIGHT"|"ABOVE"|"BELOW" }
function ns.PlaceMarginNote(target, width, height, screen, side)
	if not side then
		local rooms = {
			LEFT = target.left - width,
			RIGHT = screen.width - target.right - width,
			ABOVE = screen.height - target.top - height,
			BELOW = target.bottom - height,
		}
		for _, candidate in ipairs(SIDE_ORDER) do
			if not side or rooms[candidate] > rooms[side] then
				side = candidate
			end
		end
	end
	---@cast side "LEFT"|"RIGHT"|"ABOVE"|"BELOW"
	local cx, cy = (target.left + target.right) / 2, (target.bottom + target.top) / 2
	local left, top
	if side == "LEFT" then
		left, top = target.left - ns.MARGIN_NOTE_GAP - width, cy + ARROW_DROP
	elseif side == "RIGHT" then
		left, top = target.right + ns.MARGIN_NOTE_GAP, cy + ARROW_DROP
	elseif side == "ABOVE" then
		left, top = cx - width / 2, target.top + ns.MARGIN_NOTE_GAP + height
	else
		left, top = cx - width / 2, target.bottom - ns.MARGIN_NOTE_GAP
	end
	left = math.max(EDGE, math.min(screen.width - EDGE - width, left))
	top = math.max(EDGE + height, math.min(screen.height - EDGE, top))
	return { left = left, top = top, side = side }
end

--- The segments an arrow is cut into (core/onboarding.md › UI).
ns.NOTE_ARROW_SEGMENTS = 14
-- The arrow's head: each stroke's length, and its angle off the arrow's line.
local HEAD_LENGTH, HEAD_ANGLE = 9, 0.5

--- A note's pencil arrow (core/onboarding.md › UI; the kit's P.Pointed and P.Arrow): from the note's edge nearest its
--- target (its side 30 below its top for a target beside it, else the middle of its top or bottom) to the point of the
--- target nearest that, kept a little inside it, along a quadratic curve bowed by `bend` (a share of its length, + to
--- the left of travel) and cut into NOTE_ARROW_SEGMENTS, with a two-stroke head along the curve's end. `points` are its
--- NOTE_ARROW_SEGMENTS + 1 points, `finish` its last (where the ring goes), `head` each stroke's other end.
---@param note PagleRect
---@param target PagleRect
---@param bend number
---@return { points: number[][], finish: number[], head: number[][] }
function ns.NoteArrowPath(note, target, bend)
	local tx, ty = (target.left + target.right) / 2, (target.bottom + target.top) / 2
	local height = note.top - note.bottom
	local x0, y0
	if tx < note.left then
		x0, y0 = note.left, note.top - math.min(height - 10, ARROW_DROP)
	elseif tx > note.right then
		x0, y0 = note.right, note.top - math.min(height - 10, ARROW_DROP)
	else
		x0, y0 = (note.left + note.right) / 2, ty > note.top and note.top or note.bottom
	end
	local insetX = math.min(6, (target.right - target.left) / 2)
	local insetY = math.min(6, (target.top - target.bottom) / 2)
	local x1 = math.max(target.left + insetX, math.min(target.right - insetX, x0))
	local y1 = math.max(target.bottom + insetY, math.min(target.top - insetY, y0))
	-- the control point, off the middle to the left of travel (y up: the left of (dx, dy) is (-dy, dx))
	local dx, dy = x1 - x0, y1 - y0
	local cx, cy = (x0 + x1) / 2 - dy * bend, (y0 + y1) / 2 + dx * bend
	local points = {}
	for i = 0, ns.NOTE_ARROW_SEGMENTS do
		local s = i / ns.NOTE_ARROW_SEGMENTS
		local u = 1 - s
		points[i + 1] = { u * u * x0 + 2 * u * s * cx + s * s * x1, u * u * y0 + 2 * u * s * cy + s * s * y1 }
	end
	points[1], points[#points] = { x0, y0 }, { x1, y1 }
	local ux, uy = x1 - cx, y1 - cy
	local length = math.sqrt(ux * ux + uy * uy)
	if length == 0 then
		ux, uy = 0, -1
	else
		ux, uy = ux / length, uy / length
	end
	local head = {}
	for _, angle in ipairs({ HEAD_ANGLE, -HEAD_ANGLE }) do
		local c, s = math.cos(angle), math.sin(angle)
		head[#head + 1] = { x1 - HEAD_LENGTH * (ux * c - uy * s), y1 - HEAD_LENGTH * (ux * s + uy * c) }
	end
	return { points = points, finish = { x1, y1 }, head = head }
end
