-- The Letter (core/onboarding.md › The Letter): when it shows, once per login (ONB-R10), Open the letter and Later
-- (ONB-R12), whether it shows now for the menu's tooltip (ONB-R13), the restriction and instances hiding it until
-- ONB-R10's checks pass again (ONB-R14), a Module's dialog it waits for (ONB-R100), `/pagle dev onboarding letter`
-- (ONB-R83) and its tour stop (ONB-R84). Pure logic (CORE-R7), so it runs over plain tables and a fake clock here.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

-- A Letter over a new Angler's onboarding state (`letter` "waiting" unless given) and conditions that hold unless a
-- spec changes them: not restricted, not in an instance, the login's cards settled. Returns the Letter and what it
-- did: `shown` and `hidden` count each show and hide of its frame, `guides` each guide opened, `world` the
-- conditions to change, `global` PagleDB.global and `clock` the fake clock's advance.
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
	local seen = { shown = 0, hidden = 0, guides = 0, global = global }
	seen.world = { restricted = false, instance = false, settled = true }
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
		show = function()
			seen.shown = seen.shown + 1
		end,
		hide = function()
			seen.hidden = seen.hidden + 1
		end,
		openGuide = function()
			seen.guides = seen.guides + 1
		end,
	})
	return made, seen
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

	it("shows while letter is waiting or later, and never once declined, opened or returning (ONB-R10, ONB-R12)", function()
		for state, shows in pairs({ waiting = 1, later = 1, declined = 0, opened = 0, returning = 0 }) do
			local _, seen = arrived(state)

			assert.are.equal(shows, seen.shown, state)
		end
	end)

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

	it("makes the tour's sample inert: its buttons only hide it, writing nothing and opening nothing (CORE-R68)", function()
		local letter, seen = letterWith()

		letter:TourShow()
		letter:Later()
		letter:TourShow()
		letter:Open()
		letter:TourHide()

		assert.are.equal("waiting", seen.global.onboarding.letter)
		assert.are.equal(0, seen.guides)
		assert.are.same({ 2, 2 }, { seen.shown, seen.hidden })
	end)

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
