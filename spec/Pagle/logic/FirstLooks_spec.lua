-- First looks (core/onboarding.md › First looks): what makes a set one a Module may register (ONB-R56, ONB-R90), which
-- set shows and when (ONB-R55, ONB-R59), which of its notes show and how they're numbered (ONB-R56), where each note
-- sits beside its window (ONB-R58), and the tour's showing (ONB-R84). Pure logic (CORE-R7), so it runs over plain
-- tables.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

-- A stand-in region: shown until `hidden` is set.
local function region(name)
	local made = { name = name, hidden = false }
	function made:IsVisible()
		return not self.hidden
	end
	return made
end

-- A stand-in window: Show and Hide set `shown`.
local function window()
	local made = { shown = false, showed = 0 }
	function made:IsShown()
		return self.shown
	end
	function made:Show()
		self.shown, self.showed = true, self.showed + 1
	end
	function made:Hide()
		self.shown = false
	end
	return made
end

-- A set of `n` notes on `frame`, each pointing at its own region (returned too).
local function fixture(id, frame, n)
	local targets, notes = {}, {}
	for i = 1, n or 3 do
		targets[i] = region("target " .. i)
		notes[i] = {
			text = "note " .. i,
			target = function()
				return targets[i]
			end,
			x = -214,
			y = 100 * i,
			w = 200,
		}
	end
	return { id = id or "ledger.journal", window = frame or window(), title = "the Fish Journal", notes = notes },
		targets
end

-- First looks over a fresh onboarding state and a view noting what it's asked: `shown` ({ id, numbers }), `renumbered`
-- ({ id, numbers }), `hidden` (ids). `numbers` lists each shown note as "index=n".
local function looks()
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
	local seen = { shown = {}, renumbered = {}, hidden = {}, reported = {} }
	local function numbers(entries)
		local list = {}
		for i, entry in ipairs(entries) do
			list[i] = entry.index .. "=" .. entry.n
		end
		return list
	end
	local firstLooks = ns.NewFirstLooks({
		onboarding = function()
			return onboarding
		end,
		call = function(fn, ...)
			local results = { pcall(fn, ...) }
			if not results[1] then
				seen.reported[#seen.reported + 1] = results[2]
				return
			end
			return unpack(results, 2)
		end,
		view = {
			show = function(set, entries)
				seen.shown[#seen.shown + 1] = { set.id, numbers(entries) }
			end,
			renumber = function(set, entries)
				seen.renumbered[#seen.renumbered + 1] = { set.id, numbers(entries) }
			end,
			hide = function(set)
				seen.hidden[#seen.hidden + 1] = set.id
			end,
			isShown = function(target)
				return target:IsVisible()
			end,
		},
	})
	return firstLooks, onboarding, seen
end

describe("registering a First look (ONB-R56, ONB-R90)", function()
	it("takes a set of the Module's own, a copy, and lists it with its owner", function()
		local firstLooks = looks()
		local set = fixture()

		assert.is_nil(firstLooks:Add("Ledger", set))
		set.title = "changed"
		set.notes[1].text = "changed"

		local list = firstLooks:List()
		assert.are.equal(1, #list)
		assert.are.equal("Ledger", list[1].owner)
		assert.are.equal("the Fish Journal", list[1].set.title)
		assert.are.equal("note 1", list[1].set.notes[1].text)
		assert.are.equal("Ledger", firstLooks:Owner("ledger.journal"))
	end)

	it("takes a window that is a function, read when it's needed", function()
		local firstLooks = looks()
		local frame
		local set = fixture("core.shop", function()
			return frame
		end)

		assert.is_nil(firstLooks:Add(ns.CORE_OWNER, set))
		assert.is_nil(firstLooks:Window("core.shop"))
		frame = window()
		assert.are.equal(frame, firstLooks:Window("core.shop"))
	end)

	it("names each missing or mistyped field, and an id registered before", function()
		local function problem(change, module)
			local set = fixture()
			change(set)
			return ns.FirstLookProblem(set, module or "Ledger")
		end
		assert.are.equal("RegisterFirstLook takes a set table, got string", ns.FirstLookProblem("set", "Ledger"))
		assert.are.equal(
			"RegisterFirstLook: a set needs an id",
			problem(function(set)
				set.id = nil
			end)
		)
		assert.are.equal(
			"RegisterFirstLook: a set's id is hunts.<window>, got ledger.journal",
			problem(function() end, "Hunts")
		)
		assert.are.equal(
			"RegisterFirstLook: set ledger.journal needs its window, a frame or a function returning it",
			problem(function(set)
				set.window = "PagleJournal"
			end)
		)
		assert.are.equal(
			"RegisterFirstLook: set ledger.journal needs a title",
			problem(function(set)
				set.title = ""
			end)
		)
		assert.are.equal(
			"RegisterFirstLook: set ledger.journal needs its notes",
			problem(function(set)
				set.notes = {}
			end)
		)
		assert.are.equal(
			"RegisterFirstLook: set ledger.journal's note 2 needs a target function",
			problem(function(set)
				set.notes[2].target = region()
			end)
		)
		assert.are.equal(
			"RegisterFirstLook: set ledger.journal's note 3 needs its x, y and w (w above 0)",
			problem(function(set)
				set.notes[3].w = 0
			end)
		)
		assert.are.equal(
			"RegisterFirstLook: set ledger.journal's open is a function, got boolean",
			problem(function(set)
				set.open = true
			end)
		)

		local firstLooks = looks()
		firstLooks:Add("Ledger", fixture())
		assert.are.equal(
			"RegisterFirstLook: set ledger.journal is already registered",
			firstLooks:Add("Ledger", fixture())
		)
	end)
end)

describe("showing a First look (ONB-R55, ONB-R56)", function()
	it("shows every note numbered 1 to n the first time, marking looksSeen, and never again", function()
		local firstLooks, onboarding, seen = looks()
		firstLooks:Add("Ledger", fixture())

		assert.is_true(firstLooks:Show("ledger.journal"))
		firstLooks:Hide()
		assert.is_false(firstLooks:Show("ledger.journal"))

		assert.are.same({ { "ledger.journal", { "1=1", "2=2", "3=3" } } }, seen.shown)
		assert.is_true(onboarding:IsLookSeen("ledger.journal"))
		assert.are.same({ "ledger.journal" }, seen.hidden)
	end)

	it("shows nothing with Margin notes off, and marks nothing", function()
		local firstLooks, onboarding, seen = looks()
		firstLooks:Add("Ledger", fixture())
		onboarding:SetNotesOn(false)

		assert.is_false(firstLooks:Show("ledger.journal"))

		assert.are.same({}, seen.shown)
		assert.is_false(onboarding:IsLookSeen("ledger.journal"))
	end)

	it("drops a note whose target is hidden or gone as it shows, the numbers closing up", function()
		local firstLooks, _, seen = looks()
		local set, targets = fixture(nil, nil, 4)
		targets[2].hidden = true
		set.notes[4].target = function() end
		firstLooks:Add("Ledger", set)

		firstLooks:Show("ledger.journal")

		assert.are.same({ { "ledger.journal", { "1=1", "3=2" } } }, seen.shown)
	end)

	it("drops a note whose target raises, reporting it once", function()
		local firstLooks, _, seen = looks()
		local set = fixture(nil, nil, 2)
		set.notes[1].target = function()
			error("no tile")
		end
		firstLooks:Add("Ledger", set)

		firstLooks:Show("ledger.journal")

		assert.are.same({ { "ledger.journal", { "2=1" } } }, seen.shown)
		assert.are.equal(1, #seen.reported)
	end)

	it("shows nothing, marking nothing, when none of its targets shows", function()
		local firstLooks, onboarding, seen = looks()
		local set, targets = fixture(nil, nil, 1)
		targets[1].hidden = true
		firstLooks:Add("Ledger", set)

		assert.is_false(firstLooks:Show("ledger.journal"))

		assert.are.same({}, seen.shown)
		assert.is_false(onboarding:IsLookSeen("ledger.journal"))
	end)

	it("drops a note as its target hides, renumbering the rest, and goes with its last", function()
		local firstLooks, _, seen = looks()
		firstLooks:Add("Ledger", fixture())
		firstLooks:Show("ledger.journal")

		firstLooks:TargetHidden("ledger.journal", 1)
		assert.are.same({ { "ledger.journal", { "2=1", "3=2" } } }, seen.renumbered)
		assert.are.same(
			{ id = "ledger.journal", notes = { { index = 2, n = 1 }, { index = 3, n = 2 } } },
			firstLooks:Showing()
		)

		firstLooks:TargetHidden("ledger.journal", 2)
		firstLooks:TargetHidden("ledger.journal", 3)
		assert.are.same({ "ledger.journal" }, seen.hidden)
		assert.is_nil(firstLooks:Showing())
	end)

	it("hides as its window closes (ONB-R55), and shows one set at a time", function()
		local firstLooks, _, seen = looks()
		firstLooks:Add("Ledger", fixture())
		firstLooks:Add("Hunts", fixture("hunts.board"))

		firstLooks:Show("ledger.journal")
		firstLooks:Show("hunts.board")
		assert.are.same({ "ledger.journal" }, seen.hidden)

		firstLooks:WindowHidden("ledger.journal")
		assert.are.same({ "ledger.journal" }, seen.hidden)
		firstLooks:WindowHidden("hunts.board")
		assert.are.same({ "ledger.journal", "hunts.board" }, seen.hidden)
	end)
end)

describe('the "?" (ONB-R59)', function()
	it("shows a set seen before, and with Margin notes off, marking it seen; pressed again it hides it", function()
		local firstLooks, onboarding, seen = looks()
		firstLooks:Add("Ledger", fixture())
		onboarding:SetNotesOn(false)

		assert.is_true(firstLooks:Show("ledger.journal", true))
		assert.is_true(onboarding:IsLookSeen("ledger.journal"))
		assert.is_false(firstLooks:Show("ledger.journal", true))
		assert.are.same({ "ledger.journal" }, seen.hidden)

		assert.is_true(firstLooks:Show("ledger.journal", true))
		assert.are.equal(2, #seen.shown)
	end)

	it("leaves a set showing alone when its window's OnShow asks for it again", function()
		local firstLooks, _, seen = looks()
		firstLooks:Add("Ledger", fixture())
		firstLooks:Show("ledger.journal", true)

		assert.is_true(firstLooks:Show("ledger.journal"))

		assert.are.equal(1, #seen.shown)
		assert.are.same({}, seen.hidden)
	end)
end)

describe("/pagle dev onboarding look (ONB-R83)", function()
	it("shows a set whose window is open, seen or not, marking nothing; names why not otherwise", function()
		local firstLooks, onboarding, seen = looks()
		local set = fixture()
		firstLooks:Add("Ledger", set)
		onboarding:MarkLookSeen("ledger.journal")
		onboarding:SetNotesOn(false)

		assert.are.equal("unknown", firstLooks:ShowNow("hunts.board"))
		assert.are.equal("closed", firstLooks:ShowNow("ledger.journal"))
		set.window:Show()
		assert.are.equal("shown", firstLooks:ShowNow("ledger.journal"))

		assert.are.equal(1, #seen.shown)
	end)
end)

describe("the tour stop (ONB-R84, CORE-R68)", function()
	it("opens the window, shows the set without marking it, and closes the window again", function()
		local firstLooks, onboarding, seen = looks()
		local set = fixture()
		firstLooks:Add("Ledger", set)

		firstLooks:TourShow("ledger.journal")
		assert.is_true(set.window.shown)
		assert.are.same({ { "ledger.journal", { "1=1", "2=2", "3=3" } } }, seen.shown)
		assert.is_false(firstLooks:Show("ledger.journal"))
		firstLooks:TourHide()

		assert.is_false(set.window.shown)
		assert.are.same({ "ledger.journal" }, seen.hidden)
		assert.is_false(onboarding:IsLookSeen("ledger.journal"))
		assert.is_true(firstLooks:Show("ledger.journal"))
	end)

	it("opens it through the set's own open, and leaves a window open before it open", function()
		local firstLooks = looks()
		local frame = window()
		local set = fixture("core.shop", function()
			return frame
		end)
		local opened = 0
		set.open = function()
			opened = opened + 1
			frame:Show()
		end
		firstLooks:Add(ns.CORE_OWNER, set)

		firstLooks:TourShow("core.shop")
		firstLooks:TourHide()
		assert.are.equal(1, opened)
		assert.is_false(frame.shown)

		frame:Show()
		firstLooks:TourShow("core.shop")
		firstLooks:TourHide()
		assert.are.equal(1, opened)
		assert.is_true(frame.shown)
	end)
end)

describe("where a set's notes sit (ONB-R58)", function()
	local function place(x, w, free, scale)
		return ns.PlaceLookNote({ x = x, y = 120, w = w }, { width = 980, scale = scale or 1, free = free })
	end

	it("keeps a margin note's gap to the window's edge, and scales a note over the window with it", function()
		assert.are.same(
			{ relativePoint = "TOPLEFT", x = -214, y = -96 },
			place(-214, 200, { left = 300, right = 300 }, 0.8)
		)
		assert.are.same(
			{ relativePoint = "TOPRIGHT", x = 12, y = -96 },
			place(992, 200, { left = 300, right = 300 }, 0.8)
		)
		assert.are.same({ relativePoint = "TOPLEFT", x = 480, y = -96 }, place(600, 240, nil, 0.8))
	end)

	it("overlaps the window's edge with less than 210 free on that side", function()
		assert.are.same(
			{ relativePoint = "TOPLEFT", x = -142, y = -120 },
			place(-214, 200, { left = 150, right = 300 })
		)
		assert.are.same(
			{ relativePoint = "TOPRIGHT", x = -108, y = -120 },
			place(992, 200, { left = 300, right = 100 })
		)
		assert.are.same({ relativePoint = "TOPLEFT", x = -214, y = -120 }, place(-214, 200, { left = 210, right = 0 }))
	end)
end)
