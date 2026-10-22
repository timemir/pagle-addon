-- The First evening list (core/onboarding.md › The First evening list): when it docks and never does (ONB-R60), its
-- items, each only while its owner is registered, and the cast hint by QoL on or off (ONB-R61, ONB-R101), the ticks,
-- the next item, listDone and the fold (ONB-R62), the close mark and the Settings root's checkbox (ONB-R63, ONB-R81),
-- the dev command's docking (ONB-R83) and the tour stop's quiet showing (ONB-R84). Pure logic (CORE-R7), so it runs
-- over plain tables, a recording view and a hand-driven clock here.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

-- Every owner registered, as with every Module on.
local EVERY = { Core = true, Ledger = true, Hunts = true, QoL = true }

-- The list over a fresh onboarding state with `letter` ("opened" by default), the owners in `owners` registered, and
-- everything its view did noted in `seen`: each draw (`draws`: { list, ticked }), hide, fold and sound, and the
-- timers it set (`timers`, run with `seen.run()`).
local function eveningOver(owners, letter)
	local global = { onboarding = ns.NewOnboardingState(letter or "opened") }
	local seen = { draws = {}, hides = 0, folds = 0, sounds = {}, timers = {} }
	local onboarding = ns.NewOnboarding({
		global = function()
			return global
		end,
		call = function(fn, ...)
			return fn(...)
		end,
		print = function() end,
	})
	local evening = ns.NewEvening({
		onboarding = function()
			return onboarding
		end,
		registered = function(owner)
			return (owners or EVERY)[owner] == true
		end,
		after = function(seconds, fn)
			seen.timers[#seen.timers + 1] = { seconds = seconds, fn = fn }
		end,
		view = {
			draw = function(list, ticked)
				seen.draws[#seen.draws + 1] = { list = list, ticked = ticked }
			end,
			hide = function()
				seen.hides = seen.hides + 1
			end,
			fold = function()
				seen.folds = seen.folds + 1
			end,
			sound = function(name)
				seen.sounds[#seen.sounds + 1] = name
			end,
		},
	})
	function seen.run()
		local timers = seen.timers
		seen.timers = {}
		for _, timer in ipairs(timers) do
			timer.fn()
		end
	end
	return evening, seen, global.onboarding, onboarding
end

-- The last list drawn, each line as "text", "[x] text", "> text (hint)".
local function lastDrawn(seen)
	local draw = seen.draws[#seen.draws]
	local lines = {}
	for i, line in ipairs(draw.list.lines) do
		local text = (line.done and "[x] " or "") .. (line.next and "> " or "") .. line.text
		lines[i] = line.hint and ("%s (%s)"):format(text, line.hint) or text
	end
	return lines
end

-- Every item's id, in order.
local ALL = { "cast", "catch", "journal", "hunts", "session", "shop" }

describe("The First evening list's docking (ONB-R60)", function()
	it("docks after Off to the water, setting evening.shown, with every item and none done", function()
		local evening, seen, state = eveningOver()

		evening:OffToTheWater()

		assert.is_true(state.evening.shown)
		assert.is_true(evening:IsShowing())
		assert.are.same({
			"> Make a Cast (press your Fishing key, or double right-click)",
			"Land a Catch",
			"Open the Fish Journal",
			"See what’s biting on Hunts",
			"Finish a Session",
			"Peek into the Curio Shop",
		}, lastDrawn(seen))
		assert.are.same({ 0, 6 }, { seen.draws[1].list.done, seen.draws[1].list.total })
	end)

	it("never docks for a returning Angler, nor a skipped one (ONB-R60, ONB-R2, ONB-R26)", function()
		local returning, returnSeen, returnState = eveningOver(nil, "returning")
		returning:OffToTheWater()
		returning:Login()

		local skipped, skipSeen, skipState, onboarding = eveningOver()
		onboarding:SkipGuide()
		skipped:OffToTheWater()

		assert.are.same({}, returnSeen.draws)
		assert.are.same({}, skipSeen.draws)
		assert.is_false(returnState.evening.shown)
		assert.is_false(skipState.evening.shown)
	end)

	it("shows again at the next login while unfinished and unclosed, and not before it docked (ONB-R60)", function()
		local before, beforeSeen = eveningOver()
		before:Login()
		assert.are.same({}, beforeSeen.draws)

		local evening, seen, state = eveningOver()
		state.evening.shown = true
		evening:Login()

		assert.are.equal(1, #seen.draws)
		assert.is_true(evening:IsShowing())
	end)

	it(
		"doesn't show at login once closed, and closes a finished one an interrupted fold left open (ONB-R62)",
		function()
			local closed, closedSeen, closedState = eveningOver()
			closedState.evening.shown, closedState.evening.closed = true, true
			closed:Login()
			assert.are.same({}, closedSeen.draws)

			local finished, seen, state = eveningOver()
			state.evening.shown = true
			for _, id in ipairs(ALL) do
				state.evening.done[id] = true
			end
			finished:Login()

			assert.are.same({}, seen.draws)
			assert.is_true(state.evening.closed)
		end
	)
end)

describe("The First evening list's items (ONB-R61, ONB-R101)", function()
	it("lists only the items whose owner is registered", function()
		local evening, seen = eveningOver({ Core = true, QoL = true })

		evening:OffToTheWater()

		assert.are.same({
			"> Make a Cast (press your Fishing key, or double right-click)",
			"Land a Catch",
			"Finish a Session",
			"Peek into the Curio Shop",
		}, lastDrawn(seen))
		assert.are.equal(4, seen.draws[1].list.total)
	end)

	it("gives the cast item QoL's hint with QoL on and the right-click one with it off (ONB-R101)", function()
		local evening, seen = eveningOver({ Core = true })

		evening:OffToTheWater()

		assert.are.equal("> Make a Cast (right-click the water with Fishing)", lastDrawn(seen)[1])
	end)

	it("keeps items done before it docked, and shows them ticked", function()
		local evening, seen, state = eveningOver()

		assert.is_true(evening:Complete("cast"))
		assert.is_true(evening:Complete("shop"))
		assert.are.same({}, seen.draws) -- not docked yet: kept, nothing drawn
		evening:OffToTheWater()

		assert.is_true(state.evening.done.cast)
		assert.are.same({
			"[x] Make a Cast",
			"> Land a Catch", -- the next item, which has no hint (ONB-R61)
			"Open the Fish Journal",
			"See what’s biting on Hunts",
			"Finish a Session",
			"[x] Peek into the Curio Shop",
		}, lastDrawn(seen))
		assert.are.same({ 2, 6 }, { evening:Count() })
	end)

	it("ignores an item done already, and every item once closed", function()
		local evening, seen, state = eveningOver()
		evening:OffToTheWater()
		evening:Complete("cast")

		assert.is_false(evening:Complete("cast"))
		evening:Close()
		assert.is_false(evening:Complete("catch"))

		assert.is_nil(state.evening.done.catch)
		assert.are.equal(2, #seen.draws)
	end)

	it("writes nothing for a returning Angler, who never has the list (ONB-R2)", function()
		local evening, _, state = eveningOver(nil, "returning")

		assert.is_false(evening:Complete("cast"))

		assert.are.same({}, state.evening.done)
	end)

	it("knows each item's owner: Core's four, the Ledger's journal and Hunts' hunts", function()
		local owners = {}
		for _, id in ipairs(ALL) do
			owners[#owners + 1] = ns.EveningItem(id).owner
		end

		assert.are.same({ "Core", "Core", "Ledger", "Hunts", "Core", "Core" }, owners)
		assert.is_nil(ns.EveningItem("fish"))
	end)
end)

describe("The First evening list's ticks and fold (ONB-R62)", function()
	it("ticks an item with tick, moving the green wash and the hint to the next one", function()
		local evening, seen = eveningOver()
		evening:OffToTheWater()

		evening:Complete("cast")

		assert.are.equal("cast", seen.draws[2].ticked)
		assert.are.same({ "tick" }, seen.sounds)
		assert.are.same({
			"[x] Make a Cast",
			"> Land a Catch",
			"Open the Fish Journal",
			"See what’s biting on Hunts",
			"Finish a Session",
			"Peek into the Curio Shop",
		}, lastDrawn(seen))
	end)

	it("plays listDone at the last tick, folds 2.5 s later, closes and never returns", function()
		local evening, seen, state = eveningOver()
		evening:OffToTheWater()
		for _, id in ipairs(ALL) do
			evening:Complete(id)
		end

		assert.are.same({ "tick", "tick", "tick", "tick", "tick", "tick", "listDone" }, seen.sounds)
		assert.are.same({ 2.5 }, { seen.timers[1].seconds })
		assert.are.equal(0, seen.folds)
		assert.is_false(state.evening.closed)

		seen.run()

		assert.are.equal(1, seen.folds)
		assert.is_true(state.evening.closed)
		assert.is_false(evening:IsShowing())
		assert.is_false(evening:IsOffered())
		evening:Login()
		evening:SetShown(true)
		assert.are.equal(7, #seen.draws) -- the dock and the six ticks, nothing after
	end)

	it("finishes on the registered items alone: a Module that's off has none to wait for", function()
		local evening, seen = eveningOver({ Core = true })
		evening:OffToTheWater()

		for _, id in ipairs({ "cast", "catch", "session", "shop" }) do
			evening:Complete(id)
		end

		assert.are.equal("listDone", seen.sounds[#seen.sounds])
		assert.is_true(evening:IsFinished())
	end)
end)

describe("Closing and reopening the First evening list (ONB-R63, ONB-R81)", function()
	it("closes with its close mark, setting evening.closed", function()
		local evening, seen, state = eveningOver()
		evening:OffToTheWater()

		evening:Close()

		assert.is_true(state.evening.closed)
		assert.are.equal(1, seen.hides)
		assert.is_false(evening:IsShowing())
	end)

	it("shows again, unclosed, from the Settings root's checkbox while unfinished", function()
		local evening, seen, state = eveningOver()
		evening:OffToTheWater()
		evening:Complete("cast")
		evening:Close()

		evening:SetShown(true)

		assert.is_false(state.evening.closed)
		assert.is_true(evening:IsShowing())
		assert.are.equal("[x] Make a Cast", lastDrawn(seen)[1])
		evening:SetShown(false)
		assert.is_true(state.evening.closed)
	end)

	it("is offered on the root while unfinished, to an Angler who isn't returning", function()
		local evening = eveningOver()
		local returning = eveningOver(nil, "returning")

		assert.is_true(evening:IsOffered())
		assert.is_false(returning:IsOffered())
	end)

	it("never folds a list closed in its 2.5 s wait twice", function()
		local evening, seen = eveningOver()
		evening:OffToTheWater()
		for _, id in ipairs(ALL) do
			evening:Complete(id)
		end
		evening:Close()

		seen.run()

		assert.are.equal(0, seen.folds)
	end)
end)

describe("The First evening list for the dev and the tour (ONB-R83, ONB-R84)", function()
	it("docks from the dev command whatever the state, even for a returning Angler (ONB-R83)", function()
		local evening, seen, state = eveningOver(nil, "returning")
		state.evening.closed = true

		evening:Dock()

		assert.is_true(state.evening.shown)
		assert.is_false(state.evening.closed)
		assert.are.equal(1, #seen.draws)
	end)

	it("shows a sample at the tour stop, two items done, writing nothing, and puts it back (ONB-R84)", function()
		local evening, seen, state = eveningOver()

		evening:TourShow()

		assert.are.same({
			"[x] Make a Cast",
			"[x] Land a Catch",
			"> Open the Fish Journal (Pagle menu by the minimap » Fish Journal)",
			"See what’s biting on Hunts",
			"Finish a Session",
			"Peek into the Curio Shop",
		}, lastDrawn(seen))
		assert.are.same(ns.NewOnboardingState("opened").evening, state.evening)

		evening:TourHide()

		assert.are.equal(1, seen.hides)
		assert.is_false(evening:IsShowing())
	end)

	it("redraws the real list at the tour stop's hide when it was showing (ONB-R84, CORE-R68)", function()
		local evening, seen = eveningOver()
		evening:OffToTheWater()

		evening:TourShow()
		evening:TourHide()

		assert.are.equal(0, seen.hides)
		assert.are.equal("> Make a Cast (press your Fishing key, or double right-click)", lastDrawn(seen)[1])
		assert.is_true(evening:IsShowing())
	end)
end)
