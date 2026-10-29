-- The Letter (core/onboarding.md › The Letter): when it shows, once per login (ONB-R10), Open the letter and Later
-- (ONB-R12), whether it shows now for the menu's tooltip (ONB-R13), the restriction and instances hiding it until
-- ONB-R10's checks pass again (ONB-R14), a Module's dialog it waits for (ONB-R100), `/pagle dev onboarding letter`
-- (ONB-R83) and its tour stop (ONB-R84); and the letters a Module sends through Core: their states and Later's rule
-- (ONB-R15, ONB-R16), and one letter at a time, the onboarding Letter first (ONB-R17). Pure logic (CORE-R7), so it
-- runs over plain tables and a fake clock here.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

-- A Letter over a new Angler's onboarding state (`letter` "waiting" unless given) and conditions that hold unless a
-- spec changes them: not restricted, not in an instance, the login's cards settled. Returns the Letter and what it
-- did: `shown` and `hidden` count each show and hide of its frame, `guides` each guide opened, `world` the
-- conditions to change (`guide` is the Field guide being open, ONB-R17), `contents` the words of each letter shown, in
-- order, `confirmed` the ids of the Module letters whose confirm button ran, `global` PagleDB.global and `clock` the
-- fake clock's advance.
local function letterWith(letter)
	local global = { onboarding = ns.NewOnboardingState(letter or "waiting") }
	local onboarding = ns.NewOnboarding({
		global = function()
			return global
		end,
		call = function(fn, ...)
			return fn(...)
		end,
		print = function() end,
	})
	local timers = {}
	local now = 0
	local seen = { shown = 0, hidden = 0, guides = 0, global = global, contents = {}, confirmed = {} }
	seen.world = { restricted = false, instance = false, settled = true, guide = false }
	function seen.clock(seconds)
		now = now + seconds
		for _, timer in ipairs({ unpack(timers) }) do
			if not timer.done and timer.at <= now + 1e-9 then
				timer.done = true
				timer.fn()
			end
		end
	end
	local made = ns.NewLetter({
		onboarding = function()
			return onboarding
		end,
		isRestricted = function()
			return seen.world.restricted
		end,
		inInstance = function()
			return seen.world.instance
		end,
		cardsSettled = function()
			return seen.world.settled
		end,
		after = function(seconds, fn)
			timers[#timers + 1] = { at = now + seconds, fn = fn }
		end,
		show = function(content)
			seen.shown = seen.shown + 1
			seen.contents[#seen.contents + 1] = content
		end,
		hide = function()
			seen.hidden = seen.hidden + 1
		end,
		openGuide = function()
			seen.guides = seen.guides + 1
		end,
		guideOpen = function()
			return seen.world.guide
		end,
	})
	return made, seen
end

-- A Module letter `id` registered for `owner` (the id's prefix, capitalised), its confirm button recording in
-- `seen.confirmed`.
local function register(letter, seen, id)
	local owner = id:match("^(%w+)%."):gsub("^%l", string.upper)
	local problem = letter:Register(id, {
		kicker = "A kicker",
		text = "The line of " .. id,
		confirm = "Show me",
		later = "Later",
		onConfirm = function()
			seen.confirmed[#seen.confirmed + 1] = id
		end,
	}, owner)
	assert.is_nil(problem)
end

-- A Letter whose login has entered the world and waited the delay.
local function arrived(letter)
	local made, seen = letterWith(letter)
	made:EnteredWorld()
	seen.clock(ns.LETTER_DELAY)
	return made, seen
end

describe("when the Letter shows (ONB-R10)", function()
	it("shows 4 s after PLAYER_ENTERING_WORLD for a new Angler, not before (ONB-R10, Tunables)", function()
		local letter, seen = letterWith()
		letter:EnteredWorld()

		seen.clock(3.9)
		assert.are.equal(0, seen.shown)
		assert.is_false(letter:IsShowing())
		seen.clock(0.1)

		assert.are.equal(4, ns.LETTER_DELAY)
		assert.are.equal(1, seen.shown)
		assert.is_true(letter:IsShowing())
	end)

	it(
		"shows while letter is waiting or later, and never once declined, opened or returning (ONB-R10, ONB-R12)",
		function()
			for state, shows in pairs({ waiting = 1, later = 1, declined = 0, opened = 0, returning = 0 }) do
				local _, seen = arrived(state)

				assert.are.equal(shows, seen.shown, state)
			end
		end
	)

	it("shows once a login: a later check while it shows draws nothing again (ONB-R10)", function()
		local letter, seen = arrived()

		letter:Check()
		letter:EnteredWorld()
		seen.clock(ns.LETTER_DELAY)

		assert.are.equal(1, seen.shown)
	end)

	it("never shows again this login once answered, whatever is checked after (ONB-R10, ONB-R12)", function()
		local letter, seen = arrived()
		letter:Later()

		letter:Check()
		letter:EnteredWorld()
		seen.clock(ns.LETTER_DELAY)

		assert.are.equal(1, seen.shown)
		assert.is_false(letter:IsShowing())
	end)

	-- Each condition that holds it back, and how the check comes again once it passes (ONB-R10).
	for _, case in ipairs({
		{ "restricted", "restricted", true },
		{ "in an instance", "instance", true },
		{ "before the login's cards have shown and closed (ANN-R21)", "settled", false },
	}) do
		it("waits while " .. case[1] .. ", and shows at the next check once it passes (ONB-R10)", function()
			local letter, seen = letterWith()
			seen.world[case[2]] = case[3]
			letter:EnteredWorld()
			seen.clock(ns.LETTER_DELAY)
			assert.are.equal(0, seen.shown)

			seen.world[case[2]] = not case[3]
			letter:Check()

			assert.are.equal(1, seen.shown)
		end)
	end

	it("waits while a Module's dialog is open, and shows as the last one closes (ONB-R10, ONB-R100)", function()
		local letter, seen = letterWith()
		letter:SetDialogOpen("QoL", true)
		letter:SetDialogOpen("Ledger", true)
		letter:EnteredWorld()
		seen.clock(ns.LETTER_DELAY)
		assert.is_true(letter:IsDialogOpen())

		letter:SetDialogOpen("QoL", false)
		assert.are.equal(0, seen.shown)
		letter:SetDialogOpen("Ledger", false)

		assert.is_false(letter:IsDialogOpen())
		assert.are.equal(1, seen.shown)
	end)

	it("doesn't count the delay before PLAYER_ENTERING_WORLD: a check before it shows nothing (ONB-R10)", function()
		local letter, seen = letterWith()

		letter:Check()
		letter:SetDialogOpen("QoL", false)

		assert.are.equal(0, seen.shown)
	end)

	it("waits 4 s again after a later PLAYER_ENTERING_WORLD, counting from that one (ONB-R10)", function()
		local letter, seen = letterWith()
		seen.world.instance = true
		letter:EnteredWorld()
		seen.clock(ns.LETTER_DELAY)
		seen.world.instance = false

		letter:EnteredWorld()
		seen.clock(3)
		assert.are.equal(0, seen.shown)
		seen.clock(1)

		assert.are.equal(1, seen.shown)
	end)
end)

describe("the Letter's buttons (ONB-R12)", function()
	it("Open the letter sets opened, hides it and opens the guide (ONB-R12)", function()
		local letter, seen = arrived()

		letter:Open()

		assert.are.equal("opened", seen.global.onboarding.letter)
		assert.are.equal(1, seen.hidden)
		assert.are.equal(1, seen.guides)
		assert.is_false(letter:IsShowing())
	end)

	it("Later goes from waiting to later, then at the next login's Letter from later to declined (ONB-R12)", function()
		local letter, seen = arrived()

		letter:Later()
		assert.are.equal("later", seen.global.onboarding.letter)
		assert.are.equal(1, seen.hidden)
		assert.are.equal(0, seen.guides)

		local again, seenAgain = arrived("later")
		assert.are.equal(1, seenAgain.shown)
		again:Later()
		assert.are.equal("declined", seenAgain.global.onboarding.letter)
		local _, seenLast = arrived("declined")
		assert.are.equal(0, seenLast.shown)
	end)

	it("does nothing from a button while the Letter isn't showing (ONB-R12)", function()
		local letter, seen = letterWith()

		letter:Open()
		letter:Later()

		assert.are.equal("waiting", seen.global.onboarding.letter)
		assert.are.equal(0, seen.guides)
	end)
end)

describe("the Letter and a restriction (ONB-R14)", function()
	it("hides as a restriction starts and shows again once ONB-R10's checks pass after it (ONB-R14)", function()
		local letter, seen = arrived()

		seen.world.restricted = true
		letter:Check()
		assert.are.equal(1, seen.hidden)
		assert.is_false(letter:IsShowing())
		assert.are.equal("waiting", seen.global.onboarding.letter)

		seen.world.restricted = false
		seen.world.settled = false
		letter:Check()
		assert.are.equal(1, seen.shown)
		seen.world.settled = true
		letter:Check()

		assert.are.equal(2, seen.shown)
		assert.is_true(letter:IsShowing())
	end)

	it("hides on entering an instance, and shows again on leaving it (ONB-R10)", function()
		local letter, seen = arrived()

		seen.world.instance = true
		letter:EnteredWorld()
		assert.are.equal(1, seen.hidden)

		seen.world.instance = false
		letter:EnteredWorld()
		seen.clock(ns.LETTER_DELAY)
		assert.are.equal(2, seen.shown)
	end)

	it("stays up for a card or a dialog: only a restriction or an instance hides it (ONB-R11, ONB-R14)", function()
		local letter, seen = arrived()

		seen.world.settled = false
		letter:SetDialogOpen("QoL", true)
		letter:Check()

		assert.are.equal(0, seen.hidden)
		assert.is_true(letter:IsShowing())
	end)
end)

describe("/pagle dev onboarding letter and the Letter's tour stop (ONB-R83, ONB-R84)", function()
	it("ShowNow shows it at once, whatever the conditions and state, and its buttons act (ONB-R83)", function()
		local letter, seen = letterWith("opened")
		seen.world.restricted = true

		letter:ShowNow()
		assert.are.equal(1, seen.shown)
		assert.is_true(letter:IsShowing())
		letter:ShowNow()
		assert.are.equal(1, seen.shown)
		letter:Open()

		assert.are.equal(1, seen.guides)
	end)

	it("TourShow shows it without touching the state, and TourHide hides it again (ONB-R84, CORE-R68)", function()
		local letter, seen = letterWith()

		letter:TourShow()
		assert.is_true(letter:IsShowing())
		letter:TourHide()

		assert.are.same({ 1, 1 }, { seen.shown, seen.hidden })
		assert.is_false(letter:IsShowing())
		assert.are.equal("waiting", seen.global.onboarding.letter)
	end)

	it(
		"makes the tour's sample inert: its buttons only hide it, writing nothing and opening nothing (CORE-R68)",
		function()
			local letter, seen = letterWith()

			letter:TourShow()
			letter:Later()
			letter:TourShow()
			letter:Open()
			letter:TourHide()

			assert.are.equal("waiting", seen.global.onboarding.letter)
			assert.are.equal(0, seen.guides)
			assert.are.same({ 2, 2 }, { seen.shown, seen.hidden })
		end
	)

	it("leaves the real Letter as it was when the tour stops on it (CORE-R68)", function()
		local letter, seen = arrived()

		letter:TourShow()
		letter:TourHide()

		assert.is_true(letter:IsShowing())
		assert.are.same({ 1, 0 }, { seen.shown, seen.hidden })
	end)

	it("puts back a Letter waiting to show: the tour's hide lets ONB-R10 show it (CORE-R68)", function()
		local letter, seen = letterWith()
		letter:EnteredWorld()
		letter:TourShow()
		seen.clock(ns.LETTER_DELAY)
		assert.are.equal(1, seen.shown)

		letter:TourHide()
		letter:Check()

		assert.are.equal(2, seen.shown)
		assert.is_true(letter:IsShowing())
	end)
end)

describe("the letters a Module sends (ONB-R15, ONB-R16)", function()
	-- A Letter whose onboarding Letter is answered already (`opened`), over a login that has waited the delay, with the
	-- Module letter `ledger.prestige` registered.
	local function withModuleLetter(onboardingState)
		local letter, seen = letterWith(onboardingState or "opened")
		register(letter, seen, "ledger.prestige")
		letter:EnteredWorld()
		seen.clock(ns.LETTER_DELAY)
		return letter, seen
	end

	it("takes a letter with an id <module>.<name>, its four words and an onConfirm, and no other (ONB-R15)", function()
		local letter = letterWith()
		local function spec(over)
			local made = { kicker = "k", text = "t", confirm = "c", later = "l", onConfirm = function() end }
			for key, value in pairs(over or {}) do
				made[key] = value
			end
			return made
		end

		assert.is_nil(letter:Register("ledger.prestige", spec(), "Ledger"))
		assert.matches("is registered already", letter:Register("ledger.prestige", spec(), "Ledger"))
		assert.matches("id is ledger%.<name>", letter:Register("hunts.x", spec(), "Ledger"))
		assert.matches("id is ledger%.<name>", letter:Register("ledger.", spec(), "Ledger"))
		assert.matches("needs an id", letter:Register("", spec(), "Ledger"))
		assert.matches("takes a letter table", letter:Register("ledger.a", "no", "Ledger"))
		for _, field in ipairs({ "kicker", "text", "confirm", "later" }) do
			assert.matches("needs a " .. field, letter:Register("ledger.a", spec({ [field] = "" }), "Ledger"))
		end
		assert.matches("needs an onConfirm", letter:Register("ledger.a", spec({ onConfirm = "go" }), "Ledger"))
		assert.are.same({ "ledger.prestige" }, letter:Ids())
	end)

	it(
		"waits while its isDue says no, and shows once it says yes: a reason that has passed shows nothing (ONB-R15)",
		function()
			local letter, seen = letterWith("opened")
			local due = true
			assert.is_nil(letter:Register("ledger.prestige", {
				kicker = "k",
				text = "t",
				confirm = "c",
				later = "l",
				onConfirm = function() end,
				isDue = function()
					return due
				end,
			}, "Ledger"))
			letter:EnteredWorld()
			seen.clock(ns.LETTER_DELAY)
			letter:Send("ledger.prestige")
			letter:Later()
			assert.are.equal(1, seen.shown)

			-- Sent again at the next login, but its reason has passed before it shows.
			local again, seenAgain = letterWith("opened")
			due = false
			again:Register("ledger.prestige", {
				kicker = "k",
				text = "t",
				confirm = "c",
				later = "l",
				onConfirm = function() end,
				isDue = function()
					return due
				end,
			}, "Ledger")
			again:EnteredWorld()
			seenAgain.clock(ns.LETTER_DELAY)
			again:Send("ledger.prestige")
			assert.are.equal(0, seenAgain.shown)

			due = true
			again:Check()

			assert.are.equal(1, seenAgain.shown)
		end
	)

	it("takes an isDue only if it is a function (ONB-R15)", function()
		local letter = letterWith()

		assert.matches(
			"isDue is a function, got string",
			letter:Register("ledger.a", {
				kicker = "k",
				text = "t",
				confirm = "c",
				later = "l",
				onConfirm = function() end,
				isDue = "yes",
			}, "Ledger")
		)
	end)

	it("shows nothing until its Module sends it, then the letter's own words (ONB-R15, ONB-R16)", function()
		local letter, seen = withModuleLetter()
		assert.are.equal(0, seen.shown)
		assert.is_nil(seen.global.onboarding.letters)

		assert.is_true(letter:Send("ledger.prestige"))

		assert.are.equal(1, seen.shown)
		assert.are.equal("ledger.prestige", letter:Showing())
		assert.is_true(letter:IsShowing())
		assert.are.same({ "A kicker", "The line of ledger.prestige", "Show me", "Later" }, {
			seen.contents[1].kicker,
			seen.contents[1].text,
			seen.contents[1].confirm,
			seen.contents[1].later,
		})
		assert.are.same({ ["ledger.prestige"] = "waiting" }, seen.global.onboarding.letters)
	end)

	it("sends nothing for a letter nobody registered (ONB-R15)", function()
		local letter, seen = withModuleLetter()

		assert.is_false(letter:Send("ledger.other"))

		assert.are.equal(0, seen.shown)
		assert.is_nil(seen.global.onboarding.letters)
	end)

	it("keeps each letter's state account-wide, apart from the onboarding Letter's (ONB-R16)", function()
		local letter, seen = withModuleLetter()
		letter:Send("ledger.prestige")
		letter:Later()

		assert.are.same({ ["ledger.prestige"] = "later" }, seen.global.onboarding.letters)
		assert.are.equal("opened", seen.global.onboarding.letter)
	end)

	it("Later from waiting is later, shown once more at the next login; from later it is declined (ONB-R16)", function()
		local letter, seen = withModuleLetter()
		letter:Send("ledger.prestige")
		letter:Later()
		assert.are.equal("later", seen.global.onboarding.letters["ledger.prestige"])
		assert.are.equal(1, seen.hidden)
		assert.are.same({}, seen.confirmed)

		-- The next login: the same state, a new Letter.
		local again, seenAgain = letterWith("opened")
		seenAgain.global.onboarding.letters = { ["ledger.prestige"] = "later" }
		register(again, seenAgain, "ledger.prestige")
		again:EnteredWorld()
		seenAgain.clock(ns.LETTER_DELAY)
		assert.is_true(again:Send("ledger.prestige"))
		assert.are.equal(1, seenAgain.shown)
		again:Later()

		assert.are.equal("declined", seenAgain.global.onboarding.letters["ledger.prestige"])
		local last, seenLast = letterWith("opened")
		seenLast.global.onboarding.letters = { ["ledger.prestige"] = "declined" }
		register(last, seenLast, "ledger.prestige")
		last:EnteredWorld()
		seenLast.clock(ns.LETTER_DELAY)
		assert.is_false(last:Send("ledger.prestige"))
		assert.are.equal(0, seenLast.shown)
	end)

	it(
		"the confirm button sets opened, hides it and runs the Module's onConfirm, and it never shows again (ONB-R16)",
		function()
			local letter, seen = withModuleLetter()
			letter:Send("ledger.prestige")

			letter:Open()

			assert.are.equal("opened", seen.global.onboarding.letters["ledger.prestige"])
			assert.are.equal(1, seen.hidden)
			assert.are.same({ "ledger.prestige" }, seen.confirmed)
			assert.are.equal(0, seen.guides)
			assert.is_false(letter:IsShowing())
			local later, seenLater = letterWith("opened")
			seenLater.global.onboarding.letters = { ["ledger.prestige"] = "opened" }
			register(later, seenLater, "ledger.prestige")
			later:EnteredWorld()
			seenLater.clock(ns.LETTER_DELAY)
			assert.is_false(later:Send("ledger.prestige"))
		end
	)

	it(
		"shows a letter once a login: sending it again, or after it is answered, shows nothing more (ONB-R10)",
		function()
			local letter, seen = withModuleLetter()
			letter:Send("ledger.prestige")
			letter:Send("ledger.prestige")
			assert.are.equal(1, seen.shown)

			letter:Later()
			assert.is_false(letter:Send("ledger.prestige"))
			seen.clock(ns.LETTER_DELAY)

			assert.are.equal(1, seen.shown)
			assert.are.equal("later", seen.global.onboarding.letters["ledger.prestige"])
		end
	)

	-- Each condition that holds a Module's letter back, as it does the onboarding Letter (ONB-R10).
	for _, case in ipairs({
		{ "restricted", "restricted", true },
		{ "in an instance", "instance", true },
		{ "before the login's cards have shown and closed (ANN-R21)", "settled", false },
	}) do
		it("waits while " .. case[1] .. ", and shows at the next check once it passes (ONB-R10)", function()
			local letter, seen = letterWith("opened")
			register(letter, seen, "ledger.prestige")
			seen.world[case[2]] = case[3]
			letter:EnteredWorld()
			seen.clock(ns.LETTER_DELAY)
			letter:Send("ledger.prestige")
			assert.are.equal(0, seen.shown)

			seen.world[case[2]] = not case[3]
			letter:Check()

			assert.are.equal(1, seen.shown)
		end)
	end

	it("waits 4 s after PLAYER_ENTERING_WORLD, and while a Module's dialog is open (ONB-R10, ONB-R100)", function()
		local letter, seen = letterWith("opened")
		register(letter, seen, "ledger.prestige")
		letter:SetDialogOpen("QoL", true)
		letter:EnteredWorld()
		letter:Send("ledger.prestige")
		seen.clock(3.9)
		assert.are.equal(0, seen.shown)
		seen.clock(0.1)
		assert.are.equal(0, seen.shown)

		letter:SetDialogOpen("QoL", false)

		assert.are.equal(1, seen.shown)
	end)

	it("hides as a restriction starts and shows again once ONB-R10's checks pass after it (ONB-R14)", function()
		local letter, seen = withModuleLetter()
		letter:Send("ledger.prestige")

		seen.world.restricted = true
		letter:Check()
		assert.are.equal(1, seen.hidden)
		assert.is_false(letter:IsShowing())
		assert.are.equal("waiting", seen.global.onboarding.letters["ledger.prestige"])

		seen.world.restricted = false
		letter:Check()

		assert.are.equal(2, seen.shown)
		assert.are.equal("ledger.prestige", letter:Showing())
	end)

	it("waits while the Field guide is open, and shows as it closes (ONB-R17)", function()
		local letter, seen = withModuleLetter()
		seen.world.guide = true
		letter:Send("ledger.prestige")
		assert.are.equal(0, seen.shown)

		seen.world.guide = false
		letter:Check()

		assert.are.equal(1, seen.shown)
	end)
end)

describe("one letter at a time, the onboarding Letter first (ONB-R17)", function()
	-- A new Angler's Letter with `ledger.prestige` and `hunts.wager` registered, a login past the delay.
	local function crowded()
		local letter, seen = letterWith("waiting")
		register(letter, seen, "ledger.prestige")
		register(letter, seen, "hunts.wager")
		letter:EnteredWorld()
		seen.clock(ns.LETTER_DELAY)
		return letter, seen
	end

	it("shows the onboarding Letter before a Module's, though the Module sent first (ONB-R17)", function()
		local letter, seen = letterWith("waiting")
		register(letter, seen, "ledger.prestige")
		letter:Send("ledger.prestige")
		letter:EnteredWorld()
		seen.clock(ns.LETTER_DELAY)

		assert.are.equal(1, seen.shown)
		assert.are.equal(ns.ONBOARDING_LETTER, letter:Showing())
	end)

	it("keeps the others off screen while one shows, so one frame is ever up (ONB-R17)", function()
		local letter, seen = crowded()
		letter:Send("ledger.prestige")
		letter:Send("hunts.wager")
		letter:Check()
		seen.clock(ns.LETTER_DELAY)

		assert.are.equal(1, seen.shown)
		assert.are.equal(ns.ONBOARDING_LETTER, letter:Showing())
	end)

	it("shows the next letter LETTER_DELAY after the one before is answered, in the order sent (ONB-R17)", function()
		local letter, seen = crowded()
		letter:Send("hunts.wager")
		letter:Send("ledger.prestige")
		letter:Later()
		assert.are.equal(1, seen.shown)
		assert.is_false(letter:IsShowing())

		seen.clock(ns.LETTER_DELAY - 0.1)
		assert.are.equal(1, seen.shown)
		seen.clock(0.1)
		assert.are.equal("hunts.wager", letter:Showing())
		letter:Later()
		seen.clock(ns.LETTER_DELAY)

		assert.are.equal("ledger.prestige", letter:Showing())
		assert.are.equal(3, seen.shown)
		assert.are.same({ "later", "later" }, {
			seen.global.onboarding.letter,
			seen.global.onboarding.letters["hunts.wager"],
		})
	end)

	it(
		"lets the onboarding Letter's Open the letter open the guide, and the next letter wait for it to close (ONB-R17)",
		function()
			local letter, seen = crowded()
			letter:Send("ledger.prestige")

			letter:Open()
			seen.world.guide = true
			seen.clock(ns.LETTER_DELAY)
			assert.are.equal(1, seen.guides)
			assert.are.equal(1, seen.shown)

			seen.world.guide = false
			letter:Check()

			assert.are.equal("ledger.prestige", letter:Showing())
		end
	)

	it(
		"shows the Module's letter alone once the onboarding Letter is opened, declined or returning (ONB-R17)",
		function()
			for _, state in ipairs({ "opened", "declined", "returning" }) do
				local letter, seen = letterWith(state)
				register(letter, seen, "ledger.prestige")
				letter:EnteredWorld()
				seen.clock(ns.LETTER_DELAY)

				letter:Send("ledger.prestige")

				assert.are.equal("ledger.prestige", letter:Showing(), state)
			end
		end
	)

	it("counts as showing for the menu's tooltip whichever letter it is (ONB-R13)", function()
		local letter, seen = letterWith("opened")
		register(letter, seen, "ledger.prestige")
		letter:EnteredWorld()
		seen.clock(ns.LETTER_DELAY)
		assert.is_false(letter:IsShowing())

		letter:Send("ledger.prestige")
		assert.is_true(letter:IsShowing())
		letter:Open()

		assert.is_false(letter:IsShowing())
	end)
end)

describe("a Module's letter from /pagle dev onboarding letter and the tour (ONB-R83, ONB-R84)", function()
	it("ShowNow(id) shows it at once, whatever its state and the conditions, its buttons acting (ONB-R83)", function()
		local letter, seen = letterWith("opened")
		register(letter, seen, "ledger.prestige")
		seen.global.onboarding.letters = { ["ledger.prestige"] = "declined" }
		seen.world.restricted = true

		assert.is_true(letter:ShowNow("ledger.prestige"))
		assert.is_true(letter:ShowNow("ledger.prestige"))
		assert.are.equal(1, seen.shown)
		assert.are.equal("ledger.prestige", letter:Showing())
		letter:Open()

		assert.are.same({ "ledger.prestige" }, seen.confirmed)
		assert.are.equal(0, seen.guides)
	end)

	it(
		"ShowNow shows another letter in place of the one on screen, and false for an id that is no letter (ONB-R83)",
		function()
			local letter, seen = letterWith("waiting")
			register(letter, seen, "ledger.prestige")
			letter:ShowNow()
			assert.are.equal(ns.ONBOARDING_LETTER, letter:Showing())

			assert.is_true(letter:ShowNow("ledger.prestige"))
			assert.are.equal("ledger.prestige", letter:Showing())
			assert.are.equal(2, seen.shown)
			assert.is_false(letter:ShowNow("ledger.nothing"))
			assert.are.equal("ledger.prestige", letter:Showing())
		end
	)

	it("TourShow(id) shows it as a sample writing nothing, and TourHide takes it away (ONB-R84, CORE-R68)", function()
		local letter, seen = letterWith("opened")
		register(letter, seen, "ledger.prestige")

		letter:TourShow("ledger.prestige")
		assert.are.equal("ledger.prestige", letter:Showing())
		letter:Later()
		letter:TourShow("ledger.prestige")
		letter:Open()
		letter:TourShow("ledger.prestige")
		letter:TourHide()

		assert.are.same({ 3, 3 }, { seen.shown, seen.hidden })
		assert.are.same({}, seen.confirmed)
		assert.is_nil(seen.global.onboarding.letters)
		assert.is_false(letter:IsShowing())
	end)

	it("makes a sample of a letter that isn't registered nothing (ONB-R84)", function()
		local letter, seen = letterWith("opened")

		letter:TourShow("ledger.prestige")

		assert.are.equal(0, seen.shown)
		assert.is_false(letter:IsShowing())
	end)
end)
