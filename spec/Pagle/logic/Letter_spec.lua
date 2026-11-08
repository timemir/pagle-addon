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
-- order, `confirmed` the ids of the Module letters whose confirm button ran, `global` PagleDB.global, `clock` the
-- fake clock's advance, `serverTime` what GetServerTime() returns (a re-ask policy's clock, ONB-R16) and `showingAtHide`
-- whether the Letter said a letter was showing as each hide ran, `reported` each error a call reported.
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
	seen.serverTime, seen.showingAtHide, seen.reported = 1000000, {}, {}
	seen.world = { restricted = false, instance = false, settled = true, guide = false, test = false }
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
			seen.showingAtHide[#seen.showingAtHide + 1] = seen.made:IsShowing()
		end,
		now = function()
			return seen.serverTime
		end,
		-- host.call: an error in a Module's function reported, not raised
		call = function(fn, ...)
			local ok, result = pcall(fn, ...)
			if not ok then
				seen.reported[#seen.reported + 1] = result
				return nil
			end
			return result
		end,
		openGuide = function()
			seen.guides = seen.guides + 1
		end,
		guideOpen = function()
			return seen.world.guide
		end,
		afterMoments = function(fn)
			if seen.world.moments then
				seen.world.moments[#seen.world.moments + 1] = fn
			else
				fn()
			end
		end,
		testLog = function()
			return seen.world.test == true
		end,
	})
	seen.made = made
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

	it(
		"checks only after the moments raised so far have reached the lanes, not in the frame it was sent (ONB-R10)",
		function()
			local letter, seen = withModuleLetter()
			seen.world.moments = {}

			assert.is_true(letter:Send("ledger.prestige"))
			assert.are.equal(0, seen.shown)
			assert.are.equal("waiting", seen.global.onboarding.letters["ledger.prestige"])
			-- the toast is in the lanes by the time the flush has run
			seen.world.settled = false
			for _, fn in ipairs(seen.world.moments) do
				fn()
			end
			assert.are.equal(0, seen.shown)
			seen.world.settled = true
			letter:Check()

			assert.are.equal(1, seen.shown)
		end
	)

	it("is never sent on a test log, and no state is made for it (ONB-R16)", function()
		local letter, seen = withModuleLetter()
		seen.world.test = true

		assert.is_false(letter:Send("ledger.prestige"))

		assert.are.equal(0, seen.shown)
		assert.is_nil(seen.global.onboarding.letters)
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
		"ShowNow makes a Module letter's state waiting, so Later steps it, and leaves a state it has (ONB-R16, ONB-R83)",
		function()
			local letter, seen = letterWith("opened")
			register(letter, seen, "ledger.prestige")
			register(letter, seen, "ledger.other")
			seen.global.onboarding.letters = { ["ledger.other"] = "declined" }

			letter:ShowNow("ledger.prestige")
			letter:Later()
			assert.are.equal("later", seen.global.onboarding.letters["ledger.prestige"])
			letter:ShowNow("ledger.other")

			assert.are.equal("declined", seen.global.onboarding.letters["ledger.other"])
		end
	)

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

describe("a letter's third button, live words and re-ask policy (ONB-R15, ONB-R16; from 1.6, #665)", function()
	local DAY = 24 * 60 * 60

	-- A Letter over an answered onboarding Letter, past the delay, with `ledger.ask` registered as `over` makes it.
	local function asking(over)
		local letter, seen = letterWith("opened")
		local spec = {
			kicker = "A kicker",
			text = "The line",
			confirm = "Yes",
			later = "Not now",
			decline = "No thanks",
			onConfirm = function()
				seen.confirmed[#seen.confirmed + 1] = "ledger.ask"
			end,
		}
		for key, value in pairs(over or {}) do
			spec[key] = value
		end
		assert.is_nil(letter:Register("ledger.ask", spec, "Ledger"))
		letter:EnteredWorld()
		seen.clock(ns.LETTER_DELAY)
		return letter, seen
	end

	-- The next login over `seen`'s saved state and server time.
	local function nextLogin(seen, over)
		local letter, again = asking(over)
		again.global.onboarding = seen.global.onboarding
		again.serverTime = seen.serverTime
		return letter, again
	end

	it("onb_r15 takes a decline label, a words function and an again in seconds, each optional", function()
		local letter = letterWith()
		local function spec(over)
			local made = { kicker = "k", text = "t", confirm = "c", later = "l", onConfirm = function() end }
			for key, value in pairs(over) do
				made[key] = value
			end
			return made
		end

		assert.is_nil(
			letter:Register("ledger.a", spec({ decline = "No", words = function() end, again = DAY }), "Ledger")
		)
		assert.matches("needs a decline", letter:Register("ledger.b", spec({ decline = "" }), "Ledger"))
		assert.matches("words is a function, got string", letter:Register("ledger.b", spec({ words = "w" }), "Ledger"))
		assert.matches("again is a number of seconds", letter:Register("ledger.b", spec({ again = 0 }), "Ledger"))
		assert.matches("again is a number of seconds", letter:Register("ledger.b", spec({ again = "1d" }), "Ledger"))
		assert.are.same({ "ledger.a" }, letter:Ids())
	end)

	it("onb_r15 shows a third button only for a letter that has one", function()
		local letter, seen = asking()
		register(letter, seen, "hunts.other")
		letter:Send("ledger.ask")
		letter:Send("hunts.other")
		assert.are.equal("No thanks", seen.contents[1].decline)

		letter:Open()
		seen.clock(ns.LETTER_DELAY)

		assert.are.equal("The line of hunts.other", seen.contents[2].text)
		assert.is_nil(seen.contents[2].decline)
	end)

	it("onb_r16 the third button declines the letter: it goes, and never shows again", function()
		local letter, seen = asking()
		letter:Send("ledger.ask")

		letter:Decline()

		assert.are.equal("declined", seen.global.onboarding.letters["ledger.ask"])
		assert.are.equal(1, seen.hidden)
		assert.are.same({}, seen.confirmed)
		assert.is_false(letter:IsShowing())
		local again, seenAgain = nextLogin(seen)
		seenAgain.serverTime = seen.serverTime + 30 * DAY
		assert.is_false(again:Send("ledger.ask"))
		assert.are.equal(0, seenAgain.shown)
	end)

	it("onb_r16 the third button does nothing for a letter without one, nor with no letter on screen", function()
		local letter, seen = letterWith("opened")
		register(letter, seen, "ledger.prestige")
		letter:Decline()
		letter:EnteredWorld()
		seen.clock(ns.LETTER_DELAY)
		letter:Send("ledger.prestige")

		letter:Decline()

		assert.is_true(letter:IsShowing())
		assert.are.equal("waiting", seen.global.onboarding.letters["ledger.prestige"])
		assert.are.equal(0, seen.hidden)
	end)

	it("onb_r17 the next letter follows a declined one LETTER_DELAY on, as after any answer", function()
		local letter, seen = asking()
		register(letter, seen, "hunts.other")
		letter:Send("ledger.ask")
		letter:Send("hunts.other")

		letter:Decline()
		seen.clock(ns.LETTER_DELAY - 0.1)
		assert.are.equal(1, seen.shown)
		seen.clock(0.1)

		assert.are.equal(2, seen.shown)
		assert.are.equal("The line of hunts.other", seen.contents[2].text)
	end)

	it("onb_r15 writes a letter's live words as it shows, each time, its registered ones standing in", function()
		local calls, name = 0, "Kukli"
		local letter, seen = asking({
			words = function()
				calls = calls + 1
				return { text = name .. " is here", decline = "Never" }
			end,
		})
		letter:Send("ledger.ask")
		assert.are.equal(1, calls)
		assert.are.same(
			{ kicker = "A kicker", text = "Kukli is here", confirm = "Yes", later = "Not now", decline = "Never" },
			seen.contents[1]
		)

		name = "Arwen"
		letter:Later()
		letter:ShowNow("ledger.ask")
		letter:Later()
		name = "Bram"
		letter:TourShow("ledger.ask")

		assert.are.equal(3, calls)
		assert.are.same({ "Arwen is here", "Bram is here" }, { seen.contents[2].text, seen.contents[3].text })
	end)

	it("onb_r15 falls back to a letter's registered words when its live words fail", function()
		local letter, seen = asking({
			words = function()
				error("no zone")
			end,
		})

		letter:Send("ledger.ask")

		assert.are.equal(1, #seen.reported)
		assert.are.same(
			{ kicker = "A kicker", text = "The line", confirm = "Yes", later = "Not now", decline = "No thanks" },
			seen.contents[1]
		)
	end)

	it(
		"onb_r16 asks again after again's seconds: Later keeps it later, the time kept, and never declines it",
		function()
			local letter, seen = asking({ again = DAY })
			letter:Send("ledger.ask")

			letter:Later()

			assert.are.equal("later", seen.global.onboarding.letters["ledger.ask"])
			assert.are.equal(seen.serverTime, seen.global.onboarding.laterAt["ledger.ask"])

			-- Within the day: sent, but neither queued nor shown.
			local soon, seenSoon = nextLogin(seen, { again = DAY })
			seenSoon.serverTime = seen.serverTime + DAY - 60
			assert.is_false(soon:Send("ledger.ask"))
			seenSoon.clock(ns.LETTER_DELAY)
			assert.are.equal(0, seenSoon.shown)

			-- After it: shown again; Later again keeps it later, with the new time.
			local day, seenDay = nextLogin(seen, { again = DAY })
			seenDay.serverTime = seen.serverTime + DAY + 60
			assert.is_true(day:Send("ledger.ask"))
			assert.are.equal(1, seenDay.shown)
			day:Later()
			assert.are.equal("later", seenDay.global.onboarding.letters["ledger.ask"])
			assert.are.equal(seen.serverTime + DAY + 60, seenDay.global.onboarding.laterAt["ledger.ask"])
		end
	)

	it("onb_r16 asks at most once a login, however long the login: an answered letter stays answered", function()
		local letter, seen = asking({ again = DAY })
		letter:Send("ledger.ask")
		letter:Later()

		seen.serverTime = seen.serverTime + 2 * DAY
		seen.clock(ns.LETTER_DELAY)

		assert.is_false(letter:Send("ledger.ask"))
		assert.are.equal(1, seen.shown)
	end)

	it("onb_r16 forgets the kept time once the letter is opened or declined", function()
		local letter, seen = asking({ again = DAY })
		letter:Send("ledger.ask")
		letter:Later()
		local day, seenDay = nextLogin(seen, { again = DAY })
		seenDay.serverTime = seen.serverTime + 2 * DAY

		day:Send("ledger.ask")
		day:Decline()

		assert.are.equal("declined", seenDay.global.onboarding.letters["ledger.ask"])
		assert.is_nil(seenDay.global.onboarding.laterAt)
	end)

	it("onb_r84 the tour's sample has the third button, which only closes it, writing nothing", function()
		local letter, seen = asking({ again = DAY })

		letter:TourShow("ledger.ask")
		assert.are.equal("No thanks", seen.contents[1].decline)
		letter:Decline()
		letter:TourShow("ledger.ask")
		letter:Later()
		letter:TourShow("ledger.ask")
		letter:Open()

		assert.is_false(letter:IsShowing())
		assert.are.equal(3, seen.hidden)
		assert.is_nil(seen.global.onboarding.letters)
		assert.is_nil(seen.global.onboarding.laterAt)
		assert.are.same({}, seen.confirmed)
	end)

	it(
		"onb_r17 no letter reads as showing as any of its three buttons takes it away (the news sign's turn, SIGN-R40)",
		function()
			local letter, seen = asking()
			register(letter, seen, "hunts.one")
			register(letter, seen, "hunts.two")
			letter:Send("ledger.ask")
			letter:Send("hunts.one")
			letter:Send("hunts.two")

			letter:Decline()
			seen.clock(ns.LETTER_DELAY)
			letter:Later()
			seen.clock(ns.LETTER_DELAY)
			letter:Open()

			assert.are.same({ false, false, false }, seen.showingAtHide)
			assert.are.equal(3, seen.shown)
		end
	)

	it("onb_r83 /pagle dev onboarding reset forgets every kept time with every letter's state", function()
		local letter, seen = asking({ again = DAY })
		letter:Send("ledger.ask")
		letter:Later()
		local onboarding = letter.options.onboarding()

		onboarding:Reset("Player-1")

		assert.is_nil(seen.global.onboarding.laterAt)
		assert.is_nil(seen.global.onboarding.letters)
	end)
end)
