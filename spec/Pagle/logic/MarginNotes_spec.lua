-- Margin notes (core/onboarding.md › Margin notes): what makes a note a Module may show (ONB-R50, ONB-R90), once per
-- account and only with Margin notes on (ONB-R50), how long one stays and what holds or drops it (ONB-R51), the
-- first-moment notes Core shows for an Announcement, a card and a moment's `firstNote` (ONB-R52, ONB-R53), and where a
-- note and its pencil arrow go (ONB-R50, core/onboarding.md › UI). Pure logic (CORE-R7), so it runs over plain tables.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

-- A stand-in target: shown until `hidden` is set.
local function target(name)
	local region = { name = name, hidden = false }
	function region:IsVisible()
		return not self.hidden
	end
	return region
end

-- Margin notes over a fresh onboarding state, a clock and a view noting what it is asked to do. Returns the notes,
-- the onboarding state, and `seen`: `shown` (each note shown, in order), `hidden` ({ id, atOnce }), `placed` (ids),
-- `restricted` (set it), and `wait(seconds)`, which runs each timer that comes due.
local function margins()
	local global = { onboarding = ns.NewOnboardingState("waiting") }
	local onboarding = ns.NewOnboarding({
		global = function()
			return global
		end,
		call = function(fn, ...)
			return fn(...)
		end,
		print = function() end,
	})
	local seen = { shown = {}, hidden = {}, placed = {}, restricted = false, now = 0, timers = {} }
	local function resolve(note)
		local region = note.target
		if type(region) == "function" then
			region = region()
		end
		return region
	end
	local notes = ns.NewMarginNotes({
		onboarding = function()
			return onboarding
		end,
		isRestricted = function()
			return seen.restricted
		end,
		after = function(seconds, fn)
			seen.timers[#seen.timers + 1] = { at = seen.now + seconds, fn = fn }
		end,
		view = {
			show = function(note)
				seen.shown[#seen.shown + 1] = note
			end,
			hide = function(note, atOnce)
				seen.hidden[#seen.hidden + 1] = { note.id, atOnce }
			end,
			place = function(note)
				seen.placed[#seen.placed + 1] = note.id
			end,
			isShown = function(note)
				local region = resolve(note)
				return region ~= nil and region:IsVisible()
			end,
		},
	})
	function seen.wait(seconds)
		seen.now = seen.now + seconds
		local due = {}
		for i = #seen.timers, 1, -1 do
			if seen.timers[i].at <= seen.now then
				table.insert(due, 1, table.remove(seen.timers, i))
			end
		end
		for _, timer in ipairs(due) do
			timer.fn()
		end
	end
	return notes, global.onboarding, seen, onboarding
end

-- The ids of the notes `seen` was asked to show, in order.
local function shownIds(seen)
	local ids = {}
	for i, note in ipairs(seen.shown) do
		ids[i] = note.id
	end
	return ids
end

-- A moment as Core holds it once raised, from `module`, with `fields`.
local function raised(module, kind, rung, fields)
	local moment =
		{ rung = rung, kind = kind, title = kind, module = module, moduleTitle = module, moduleOrder = 10, raised = 1 }
	for key, value in pairs(fields or {}) do
		moment[key] = value
	end
	return moment
end

describe("ns.MarginNoteProblem", function()
	local note = function(fields)
		local made = { id = "ledger.fresh", text = "A rest is never a penalty.", target = target("bar") }
		for key, value in pairs(fields or {}) do
			made[key] = value
		end
		return made
	end

	it("takes a note with an id of the Module's, a text, a target and a side, or none (Contracts, ONB-R90)", function()
		assert.is_nil(ns.MarginNoteProblem(note(), "Ledger"))
		for _, side in ipairs({ "LEFT", "RIGHT", "ABOVE", "BELOW" }) do
			assert.is_nil(ns.MarginNoteProblem(note({ side = side }), "Ledger"))
		end
		assert.is_nil(ns.MarginNoteProblem(note({ id = "qol.lure" }), "QoL"))
	end)

	it("names each missing or mistyped field (ONB-R90)", function()
		assert.matches("takes a note table", ns.MarginNoteProblem("ledger.fresh", "Ledger"))
		assert.matches("needs an id", ns.MarginNoteProblem(note({ id = 4 }), "Ledger"))
		assert.matches("ledger%.<name>", ns.MarginNoteProblem(note({ id = "fresh" }), "Ledger"))
		assert.matches("ledger%.<name>", ns.MarginNoteProblem(note({ id = "core.fresh" }), "Ledger"))
		assert.matches("needs a text", ns.MarginNoteProblem(note({ text = "" }), "Ledger"))
		assert.matches("needs a target", ns.MarginNoteProblem(note({ target = "bar" }), "Ledger"))
		assert.matches("side", ns.MarginNoteProblem(note({ side = "TOP" }), "Ledger"))
	end)
end)

describe("Margin notes", function()
	local function lure(region)
		return { id = "qol.lure", text = "Only that.", target = region or target("button") }
	end

	it("show a note once per account, marking it seen as it shows (ONB-R50)", function()
		local notes, state, seen = margins()

		assert.is_true(notes:Show(lure()))
		seen.wait(13)
		assert.is_false(notes:Show(lure()))

		assert.are.same({ "qol.lure" }, shownIds(seen))
		assert.are.same({ ["qol.lure"] = true }, state.notesSeen)
	end)

	it("show none with Margin notes off, and mark none seen (ONB-R50, ONB-R81)", function()
		local notes, state, seen = margins()
		state.notesOn = false

		assert.is_false(notes:Show(lure()))

		assert.are.same({}, seen.shown)
		assert.are.same({}, state.notesSeen)
	end)

	it("show one again once /pagle guide notes has cleared notesSeen (ONB-R80)", function()
		local notes, _, seen, onboarding = margins()
		notes:Show(lure())
		seen.wait(12)

		onboarding:ShowNotesAgain()
		notes:Show(lure())

		assert.are.same({ "qol.lure", "qol.lure" }, shownIds(seen))
	end)

	it("leave after 12 s, when clicked, or when the target hides, whichever is first (ONB-R51)", function()
		local notes, _, seen = margins()
		notes:Show(lure())
		seen.wait(11.9)
		assert.are.same({}, seen.hidden)
		seen.wait(0.1)
		assert.are.same({ { "qol.lure", false } }, seen.hidden)

		notes:Show({ id = "core.nod", text = "A Nod.", target = target("nod") })
		notes:Leave("core.nod")
		notes:Show({ id = "core.toast", text = "A coin.", target = target("coin") })
		notes:TargetHidden("core.toast")
		seen.wait(12)

		assert.are.same({ { "qol.lure", false }, { "core.nod", false }, { "core.toast", false } }, seen.hidden)
		assert.are.same({}, notes:Showing())
	end)

	it("hold a note raised while restricted, and show it once the restriction ends (ONB-R51)", function()
		local notes, state, seen = margins()
		seen.restricted = true

		assert.is_true(notes:Show(lure()))
		assert.are.same({}, seen.shown)
		assert.is_nil(state.notesSeen["qol.lure"])

		seen.restricted = false
		notes:RestrictionChanged(false)

		assert.are.same({ "qol.lure" }, shownIds(seen))
		assert.is_true(state.notesSeen["qol.lure"])
	end)

	it("drop a held note whose target hid meanwhile, unseen, so its next first time shows it (ONB-R51)", function()
		local notes, state, seen = margins()
		local button = target("button")
		seen.restricted = true
		notes:Show(lure(button))
		button.hidden = true

		seen.restricted = false
		notes:RestrictionChanged(false)

		assert.are.same({}, seen.shown)
		assert.is_nil(state.notesSeen["qol.lure"])
		assert.is_true(notes:Show(lure()))
	end)

	it("take a note on screen off at once as a restriction starts, and show it again after (ONB-R51)", function()
		local notes, _, seen = margins()
		notes:Show(lure())
		seen.wait(5)

		seen.restricted = true
		notes:RestrictionChanged(true)
		assert.are.same({ { "qol.lure", true } }, seen.hidden)
		seen.wait(10)
		seen.restricted = false
		notes:RestrictionChanged(false)
		seen.wait(11)

		assert.are.same({ "qol.lure", "qol.lure" }, shownIds(seen))
		assert.are.same({ { "qol.lure", true } }, seen.hidden)
		seen.wait(1)
		assert.are.same({ { "qol.lure", true }, { "qol.lure", false } }, seen.hidden)
	end)

	it("place each note on screen again when asked, as Pagle's menu button moves (ONB-R108)", function()
		local notes, _, seen = margins()
		notes:Show(lure())
		notes:Show({ id = "core.welcome", text = "Welcome back.", target = target("menu") })

		notes:Retarget()

		assert.are.same({ "qol.lure", "core.welcome" }, seen.placed)
	end)

	it("show a note for /pagle dev onboarding note however it stands, marking nothing (ONB-R83)", function()
		local notes, state, seen = margins()
		state.notesOn = false
		state.notesSeen["qol.lure"] = true

		assert.is_true(notes:ShowNow(lure()))

		assert.are.same({ "qol.lure" }, shownIds(seen))
		assert.are.same({ ["qol.lure"] = true }, state.notesSeen)
	end)
end)

describe("Core's first-moment notes", function()
	local L = ns.L

	-- The targets an Announcement's frame gives: the frame, and its coin.
	local function targets()
		local frame, coin = target("frame"), target("coin")
		return {
			frame = function()
				return frame
			end,
			coin = function()
				return coin
			end,
		},
			frame,
			coin
	end

	-- The catch Nod of a Cast, as Core holds it (ANN-R13).
	local function catchNod()
		return ns.MakeAnnouncement({ raised("Pagle", "catch", "nod", { catchNod = true, cast = "c1" }) }) --[[@as table]]
	end

	it("show core.nod beside the first catch Nod, once (ONB-R52)", function()
		local notes, _, seen = margins()
		local where, frame = targets()

		notes:AnnouncementShown(catchNod(), "nod", where, false)
		notes:AnnouncementShown(catchNod(), "nod", where, false)

		assert.are.same({ "core.nod" }, shownIds(seen))
		assert.are.equal(ns.RedPencil(L.NOTE_NOD), seen.shown[1].text)
		assert.are.equal(frame, seen.shown[1].target())
	end)

	it("show core.uncharted, not core.nod, beside an Uncharted Catch's Nod, a Module's or Core's (ONB-R52)", function()
		local notes, state, seen = margins()
		local where = targets()
		local ledgers = ns.MakeAnnouncement({ raised("Ledger", "uncharted", "nod", { cast = "c2" }) }) --[[@as table]]

		notes:AnnouncementShown(ledgers, "nod", where, true)
		notes:AnnouncementShown(catchNod(), "nod", where, true)

		assert.are.same({ "core.uncharted" }, shownIds(seen))
		assert.are.equal(ns.RedPencil(L.NOTE_UNCHARTED), seen.shown[1].text)
		assert.is_nil(state.notesSeen["core.nod"])
	end)

	it("show core.toast at the coin of the first toast with Coins, and none for a Nod's Coins (ONB-R52)", function()
		local notes, _, seen = margins()
		local where, _, coin = targets()

		notes:AnnouncementShown(
			ns.MakeAnnouncement({ raised("Ledger", "newInZone", "nod", { coins = 2 }) }) --[[@as table]],
			"nod",
			where,
			false
		)
		notes:AnnouncementShown(
			ns.MakeAnnouncement({ raised("Ledger", "sizeRecord", "toast", { coins = 5 }) }) --[[@as table]],
			"toast",
			where,
			false
		)

		assert.are.same({ "core.toast" }, shownIds(seen))
		assert.are.equal(ns.RedPencil(L.NOTE_TOAST), seen.shown[1].text)
		assert.are.equal(coin, seen.shown[1].target())
	end)

	it("prefix core.toast with the moment's firstNote, marking {module}.{kind} seen too (ONB-R52, ONB-R53)", function()
		local notes, state, seen = margins()
		local first = "A new Species for your Ledger."
		local toast = ns.MakeAnnouncement({
			raised("Ledger", "newSpecies", "toast", { coins = 5, firstNote = first }),
		}) --[[@as table]]

		notes:AnnouncementShown(toast, "toast", targets(), false)
		notes:AnnouncementShown(toast, "toast", targets(), false)

		assert.are.same({ "core.toast" }, shownIds(seen))
		assert.are.equal(first .. " " .. ns.RedPencil(L.NOTE_TOAST), seen.shown[1].text)
		assert.is_true(state.notesSeen["ledger.newSpecies"])
	end)

	it(
		"show a moment's firstNote beside its frame the first time a moment of that Module and kind shows, id"
			.. " {module}.{kind} (ONB-R53)",
		function()
			local notes, _, seen = margins()
			local where, frame = targets()
			local hunt = function(kind)
				return ns.MakeAnnouncement({
					raised("Hunts", kind, "toast.low", { firstNote = "A Hunt opened." }),
				}) --[[@as table]]
			end

			notes:AnnouncementShown(hunt("windowOpened"), "toast", where, false)
			notes:AnnouncementShown(hunt("windowOpened"), "toast", where, false)
			notes:AnnouncementShown(hunt("pinned"), "toast", where, false)

			assert.are.same({ "hunts.windowOpened", "hunts.pinned" }, shownIds(seen))
			assert.are.equal("A Hunt opened.", seen.shown[1].text)
			assert.are.equal(frame, seen.shown[1].target())
		end
	)

	it("show nothing for /pagle dev preview's samples or the fighting digest (ONB-R52)", function()
		local notes, _, seen = margins()

		notes:AnnouncementShown(ns.DevPreviewAnnouncement("toast") --[[@as table]], "toast", targets(), false)
		notes:AnnouncementShown(ns.DevPreviewAnnouncement("nod") --[[@as table]], "nod", targets(), false)
		local digest = ns.MakeAnnouncement({ raised("Ledger", "sizeRecord", "toast", { coins = 5 }) }) --[[@as table]]
		digest.fighting = {}
		notes:AnnouncementShown(digest, "toast", targets(), false)

		assert.are.same({}, seen.shown)
	end)

	it("show core.summary beside the first Session summary card, and not for a Write-up or sample (ONB-R52)", function()
		local notes, _, seen = margins()
		local card = target("card")
		local function at()
			return card
		end

		notes:CardShown({ title = "Write-up", writeUp = {} }, at)
		notes:CardShown(ns.DevPreviewCard(), at)
		notes:CardShown({ title = "Session", numbers = { casts = 3, catches = 2, gotAway = 1, seconds = 600 } }, at)

		assert.are.same({ "core.summary" }, shownIds(seen))
		assert.are.equal(ns.RedPencil(L.NOTE_SUMMARY), seen.shown[1].text)
	end)
end)

describe("ns.RedPencil", function()
	it("writes each *term* in the red pencil (ONB-R50)", function()
		assert.are.equal("That’s a |cff9a2a1aNod|r: one line.", ns.RedPencil("That’s a *Nod*: one line."))
	end)
end)

describe("ns.PlaceMarginNote", function()
	local SCREEN = { width = 1920, height = 1080 }

	it("puts a note on the side with most room, the gap from its target, inside the screen (ONB-R50)", function()
		-- a Nod at the column's foot, centred: most room above
		local nod = { left = 760, right = 1160, bottom = 140, top = 166 }
		local place = ns.PlaceMarginNote(nod, 250, 90, SCREEN)
		assert.are.equal("ABOVE", place.side)
		assert.are.equal(166 + ns.MARGIN_NOTE_GAP + 90, place.top)
		assert.is_true(place.left >= 0 and place.left + 250 <= 1920)

		-- the minimap button at the top right: most room to its left
		local button = { left = 1700, right = 1731, bottom = 900, top = 931 }
		place = ns.PlaceMarginNote(button, 280, 70, SCREEN)
		assert.are.equal("LEFT", place.side)
		assert.are.equal(1700 - ns.MARGIN_NOTE_GAP - 280, place.left)
	end)

	it("keeps a note's own side when it gives one, and holds it on screen (Contracts, ONB-R106)", function()
		local button = { left = 1880, right = 1911, bottom = 1040, top = 1071 }

		local place = ns.PlaceMarginNote(button, 280, 70, SCREEN, "RIGHT")

		assert.are.equal("RIGHT", place.side)
		assert.are.equal(1920 - 8 - 280, place.left)
		assert.is_true(place.top <= 1080 - 8)
	end)
end)

describe("ns.NoteArrowPath", function()
	it(
		"runs a curve of 14 segments from the note's edge nearest the target to a point on it, with a two-stroke head"
			.. " (core/onboarding.md › UI)",
		function()
			local note = { left = 100, right = 350, bottom = 200, top = 290 }
			local nod = { left = 60, right = 460, bottom = 300, top = 326 }

			local path = ns.NoteArrowPath(note, nod, 0.2)

			assert.are.equal(15, #path.points)
			-- from the note's top edge, its middle: the target is above it
			assert.are.same({ 225, 290 }, path.points[1])
			local finish = path.points[15]
			assert.is_true(finish[1] >= 60 and finish[1] <= 460 and finish[2] >= 300 and finish[2] <= 326)
			assert.are.same(finish, path.finish)
			assert.are.equal(2, #path.head)
			for _, stroke in ipairs(path.head) do
				local dx, dy = stroke[1] - finish[1], stroke[2] - finish[2]
				assert.is_true(math.abs(math.sqrt(dx * dx + dy * dy) - 9) < 1e-9)
			end
		end
	)

	it("starts from the note's left or right edge for a target beside it", function()
		local note = { left = 100, right = 350, bottom = 200, top = 290 }

		local left = ns.NoteArrowPath(note, { left = 10, right = 40, bottom = 260, top = 280 }, 0.2)
		local right = ns.NoteArrowPath(note, { left = 500, right = 530, bottom = 260, top = 280 }, -0.2)

		assert.are.same({ 100, 260 }, left.points[1])
		assert.are.same({ 350, 260 }, right.points[1])
	end)
end)
