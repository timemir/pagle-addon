-- The Field guide's steps and its moving between them (core/onboarding.md › The Field guide): the step registry
-- (ONB-R21, ONB-R90, Contracts), where it opens (ONB-R22), Next, back, the skip links and the ribbons (ONB-R23,
-- ONB-R24), Off to the water and the Welcome skip (ONB-R26), the restriction (ONB-R25), the hold (ONB-R70) and the
-- tour stops' quiet showing (ONB-R84). Pure logic (CORE-R7), so it runs over plain tables and a recording view here.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

-- A step with every field it needs (Contracts), as `fields` change it.
local function step(id, order, fields)
	local made = { id = id, order = order, ribbon = "Ribbon " .. tostring(id), build = function() end }
	for key, value in pairs(fields or {}) do
		made[key] = value
	end
	return made
end

-- A registry holding `steps` (owner, step), closed as at ModulesChanged.
local function stepsOf(list)
	local steps = ns.NewGuideSteps()
	for _, entry in ipairs(list) do
		assert(steps:Add(entry[1], entry[2]) == nil)
	end
	steps:Close()
	return steps
end

-- Core's four steps and the Modules' four, at their orders (ONB-R21).
local function everyStep()
	return stepsOf({
		{ "Core", step("welcome", 10, { skipTo = "close" }) },
		{ "Core", step("box", 20) },
		{ "QoL", step("casting", 30) },
		{ "QoL", step("clothes", 40, { skipTo = "next" }) },
		{ "Core", step("moments", 50) },
		{ "Ledger", step("ledger", 60) },
		{ "TackleBoard", step("board", 70, { skipTo = "next" }) },
		{ "Core", step("off", 90) },
	})
end

-- The guide over `steps` and a fresh onboarding state, with everything it does noted in `seen`: each page shown
-- (`shown`: { id, how, index, count }), each close, hold and release, each event fired and chat line printed.
local function guideOver(steps, options)
	options = options or {}
	local global = { onboarding = ns.NewOnboardingState("opened") }
	local seen = { shown = {}, closes = 0, holds = {}, releases = {}, fired = {}, printed = {}, restricted = false }
	local onboarding = ns.NewOnboarding({
		global = function()
			return global
		end,
		call = function(fn, ...)
			return fn(...)
		end,
		print = function() end,
	})
	local guide = ns.NewGuide({
		steps = steps,
		onboarding = function()
			return onboarding
		end,
		isRestricted = function()
			return seen.restricted
		end,
		view = {
			show = function(page, how)
				seen.shown[#seen.shown + 1] =
					{ id = page.entry.step.id, how = how, index = page.index, count = page.count }
				seen.page = page
			end,
			close = function()
				seen.closes = seen.closes + 1
			end,
		},
		hold = function(reason)
			seen.holds[#seen.holds + 1] = reason
		end,
		release = function(reason)
			seen.releases[#seen.releases + 1] = reason
		end,
		fire = function(event, ...)
			seen.fired[#seen.fired + 1] = { event, ... }
		end,
		call = options.call or function(fn, ...)
			return fn(...)
		end,
		print = function(line)
			seen.printed[#seen.printed + 1] = line
		end,
	})
	return guide, seen, global.onboarding, onboarding
end

-- The ids of the pages shown so far, in order.
local function shownIds(seen)
	local ids = {}
	for i, page in ipairs(seen.shown) do
		ids[i] = page.id
	end
	return ids
end

describe("ns.NewGuideSteps", function()
	it("lists the steps by order, whoever registered them, and counts them (ONB-R21)", function()
		local steps = stepsOf({
			{ "Core", step("off", 90) },
			{ "Ledger", step("ledger", 60) },
			{ "Core", step("welcome", 10) },
			{ "QoL", step("casting", 30) },
		})

		local ids = {}
		for i, entry in ipairs(steps:List()) do
			ids[i] = entry.step.id
		end
		assert.are.same({ "welcome", "casting", "ledger", "off" }, ids)
		assert.are.equal(4, steps:Count())
		assert.are.equal("Ledger", steps:List()[3].owner)
		assert.are.equal(3, steps:Index("ledger"))
		assert.is_nil(steps:Index("board"))
	end)

	it("drops a Module's steps that never registered, so the count drops with them (ONB-R21)", function()
		local everything, without = everyStep(), ns.NewGuideSteps()
		for _, entry in ipairs(everything:List()) do
			if entry.owner ~= "TackleBoard" then
				without:Add(entry.owner, entry.step)
			end
		end

		assert.are.equal(8, everything:Count())
		assert.are.equal(7, without:Count())
		assert.is_nil(without:Index("board"))
	end)

	it("names each Module's first step, by order, and none for a Module without one (ONB-R82)", function()
		local steps = everyStep()

		assert.are.equal("casting", steps:FirstOf("QoL"))
		assert.are.equal("board", steps:FirstOf("TackleBoard"))
		assert.is_nil(steps:FirstOf("Hunts"))
	end)

	it("keeps a copy of the step, so a Module changing its table later changes nothing (ONB-R90)", function()
		local steps = ns.NewGuideSteps()
		local mine = step("ledger", 60)
		steps:Add("Ledger", mine)
		mine.order = 5

		assert.are.equal(60, steps:List()[1].step.order)
	end)

	it("refuses every malformed step, adding nothing (ONB-R90, Contracts)", function()
		local cases = {
			{ "not a table", "ledger" },
			{ "no id", step(nil, 60) },
			{ "an id with a space", step("my step", 60) },
			{ "no order", step("ledger", nil) },
			{ "an order that isn't a number", step("ledger", "60") },
			{ "no ribbon", step("ledger", 60, { ribbon = false }) },
			{ "an empty ribbon", step("ledger", 60, { ribbon = "" }) },
			{ "no build", step("ledger", 60, { build = false }) },
			{ "a skipLabel that isn't a string", step("ledger", 60, { skipLabel = 3 }) },
			{ "an unknown skipTo", step("ledger", 60, { skipTo = "first" }) },
			{ "an onShow that isn't a function", step("ledger", 60, { onShow = "yes" }) },
			{ "Core's skipTo close", step("ledger", 60, { skipTo = "close" }) },
			{ "Core's own nextLabel", step("ledger", 60, { nextLabel = "Go" }) },
			{ "Core's own ownFoot", step("ledger", 60, { ownFoot = true }) },
		}
		for _, case in ipairs(cases) do
			local steps = ns.NewGuideSteps()
			local problem = steps:Add("Ledger", case[2])
			assert(type(problem) == "string", case[1])
			assert.are.equal(0, steps:Count(), case[1])
		end
	end)

	it("lets Core alone close the guide from a skip link, label its Next and draw its own foot (ONB-R26)", function()
		local steps = ns.NewGuideSteps()

		assert.is_nil(steps:Add("Core", step("welcome", 10, { skipTo = "close", nextLabel = "Show me around" })))
		assert.is_nil(steps:Add("Core", step("off", 90, { ownFoot = true })))
	end)

	it("refuses an id registered before, by anyone (ONB-R21: ids are unique in the guide)", function()
		local steps = ns.NewGuideSteps()
		steps:Add("Core", step("box", 20))

		assert.is_string(steps:Add("Ledger", step("box", 60)))
		assert.are.equal(1, steps:Count())
	end)

	it("refuses a step after the registry closes as late, adding nothing (ONB-R21, CORE-R42)", function()
		local steps = everyStep()
		local problem, late = steps:Add("Ledger", step("late", 65))

		assert.is_string(problem)
		assert.is_true(late)
		assert.are.equal(8, steps:Count())
	end)
end)

describe("opening the guide (ONB-R22)", function()
	it(
		"opens at the first step by order, holding Announcements for the guide and firing GuideOpened (ONB-R70)",
		function()
			local guide, seen = guideOver(everyStep())

			guide:Open()

			assert.are.same({ { id = "welcome", how = "open", index = 1, count = 8 } }, seen.shown)
			assert.is_true(guide:IsOpen())
			assert.are.same({ "guide" }, seen.holds)
			assert.are.same({ { "GuideOpened" } }, seen.fired)
		end
	)

	it("sets guideStep and stepsSeen for each step shown (ONB-R22)", function()
		local guide, _, state = guideOver(everyStep())

		guide:Open()
		guide:Next()

		assert.are.equal("box", state.guideStep)
		assert.are.same({ welcome = true, box = true }, state.stepsSeen)
	end)

	it("reopens at guideStep while it is registered (ONB-R22, ONB-R104)", function()
		local guide, seen, state = guideOver(everyStep())
		state.guideStep = "moments"

		guide:Open()

		assert.are.same({ "moments" }, shownIds(seen))
		assert.are.equal(5, seen.shown[1].index)
	end)

	it("opens at the first step when guideStep's step is no longer registered (ONB-R22)", function()
		local guide, seen, state = guideOver(stepsOf({ { "Core", step("welcome", 10) }, { "Core", step("off", 90) } }))
		state.guideStep = "board"

		guide:Open()

		assert.are.same({ "welcome" }, shownIds(seen))
	end)

	it("opens at a step asked for, ahead of guideStep (ONB-R22, ONB-R82)", function()
		local guide, seen, state = guideOver(everyStep())
		state.guideStep = "moments"

		guide:Open("board")

		assert.are.same({ "board" }, shownIds(seen))
	end)

	it("opens at a Module's first step, and does nothing for a Module without one (ONB-R82)", function()
		local guide, seen = guideOver(everyStep())

		assert.is_false(guide:OpenModule("Hunts"))
		assert.is_false(guide:IsOpen())
		assert.is_true(guide:OpenModule("QoL"))

		assert.are.same({ "casting" }, shownIds(seen))
	end)

	it("turns to a step asked for while open, without opening again (ONB-R22)", function()
		local guide, seen = guideOver(everyStep())
		guide:Open()

		guide:Open("ledger")

		assert.are.same({ "welcome", "ledger" }, shownIds(seen))
		assert.are.equal("forward", seen.shown[2].how)
		assert.are.same({ "guide" }, seen.holds)
		assert.are.equal(1, #seen.fired)
	end)

	it("does nothing with no step registered", function()
		local guide, seen = guideOver(stepsOf({}))

		guide:Open()

		assert.are.same({}, seen.shown)
		assert.is_false(guide:IsOpen())
	end)

	it("calls the step's onShow each time it shows, through call (Contracts)", function()
		local shows, called = 0, 0
		local guide = guideOver(
			stepsOf({
				{
					"Core",
					step("welcome", 10, {
						onShow = function()
							shows = shows + 1
						end,
					}),
				},
				{ "Core", step("off", 90) },
			}),
			{
				call = function(fn, ...)
					called = called + 1
					return fn(...)
				end,
			}
		)

		guide:Open()
		guide:Next()
		guide:Back()

		assert.are.equal(2, shows)
		assert.are.equal(2, called)
	end)
end)

describe("moving through the guide (ONB-R23, ONB-R24)", function()
	it("turns forward with Next and back with back, and does neither past an end (ONB-R23)", function()
		local guide, seen = guideOver(everyStep())
		guide:Open()

		guide:Back()
		guide:Next()
		guide:Next()
		guide:Back()

		assert.are.same({ "welcome", "box", "casting", "box" }, shownIds(seen))
		assert.are.same({ "open", "forward", "forward", "back" }, {
			seen.shown[1].how,
			seen.shown[2].how,
			seen.shown[3].how,
			seen.shown[4].how,
		})

		guide:Open("off")
		guide:Next()
		assert.are.equal("off", seen.shown[#seen.shown].id)
		assert.are.equal(5, #seen.shown)
	end)

	it("tells the view which page it shows: n of m, first, last (ONB-R20, ONB-R23)", function()
		local guide, seen = guideOver(everyStep())

		guide:Open()
		assert.is_true(seen.page.first)
		assert.is_false(seen.page.last)

		guide:Open("off")
		assert.are.equal(8, seen.page.index)
		assert.are.equal(8, seen.page.count)
		assert.is_false(seen.page.first)
		assert.is_true(seen.page.last)
	end)

	it("skips to the last step by default, and to the next where the step says so (ONB-R23)", function()
		local guide, seen = guideOver(everyStep())
		guide:Open("box")

		guide:Skip()
		assert.are.equal("off", seen.shown[#seen.shown].id)

		guide:Open("clothes")
		guide:Skip()
		assert.are.equal("moments", seen.shown[#seen.shown].id)
		assert.are.equal("forward", seen.shown[#seen.shown].how)
	end)

	it("skips past the steps between without showing them, so they aren't seen (ONB-R23, ONB-R24)", function()
		local guide, _, state = guideOver(everyStep())
		guide:Open("box")

		guide:Skip()

		assert.are.same({ box = true, off = true }, state.stepsSeen)
	end)

	it("closes the guide and sets skipped from the Welcome step's skip (ONB-R26)", function()
		local guide, seen, state = guideOver(everyStep())
		guide:Open()

		guide:Skip()

		assert.is_false(guide:IsOpen())
		assert.is_true(state.skipped)
		assert.are.equal(1, seen.closes)
	end)

	it("turns to a ribbon's step, forward or back by order (ONB-R24)", function()
		local guide, seen = guideOver(everyStep())
		guide:Open("moments")

		guide:GoTo("board")
		guide:GoTo("box")
		guide:GoTo("box")

		assert.are.same({ "moments", "board", "box" }, shownIds(seen))
		assert.are.equal("forward", seen.shown[2].how)
		assert.are.equal("back", seen.shown[3].how)
	end)

	it("hangs one ribbon per step: the current one, the seen ones ticked, the rest not (ONB-R24)", function()
		local guide, seen = guideOver(everyStep())
		guide:Open()
		guide:Next()
		guide:GoTo("ledger")

		local ribbons = seen.page.ribbons
		assert.are.equal(8, #ribbons)
		assert.are.same({ id = "ledger", label = "Ribbon ledger", current = true, seen = true }, ribbons[6])
		assert.are.same({ id = "welcome", label = "Ribbon welcome", current = false, seen = true }, ribbons[1])
		assert.are.same({ id = "box", label = "Ribbon box", current = false, seen = true }, ribbons[2])
		assert.are.same({ id = "casting", label = "Ribbon casting", current = false, seen = false }, ribbons[3])
	end)
end)

describe("closing and finishing (ONB-R22, ONB-R26, ONB-R70)", function()
	it("keeps guideStep when it closes, releases the hold and fires GuideClosed with the step (ONB-R22)", function()
		local guide, seen, state = guideOver(everyStep())
		guide:Open()
		guide:Next()

		guide:Close()

		assert.is_false(guide:IsOpen())
		assert.are.equal("box", state.guideStep)
		assert.are.same({ "guide" }, seen.releases)
		assert.are.same({ "GuideClosed", "box" }, seen.fired[2])

		guide:Close()
		assert.are.equal(1, seen.closes)
		assert.are.equal(1, #seen.releases)
	end)

	it("sets guideDone with Off to the water, closes, then calls its hook (ONB-R26, ONB-R38)", function()
		local guide, seen, state = guideOver(everyStep())
		local done = {}
		guide:SetOffToTheWater(function()
			done[#done + 1] = guide:IsOpen()
		end)
		guide:Open("off")

		guide:Finish()

		assert.is_true(state.guideDone)
		assert.is_false(guide:IsOpen())
		assert.are.same({ false }, done)
		assert.are.equal(1, seen.closes)
	end)
end)

describe("the guide and a restriction (ONB-R25)", function()
	it("closes as a restriction starts, keeping guideStep and setting reopen; reopens there after", function()
		local guide, seen, state = guideOver(everyStep())
		guide:Open("casting")

		seen.restricted = true
		guide:RestrictionChanged(true)
		assert.is_false(guide:IsOpen())
		assert.is_true(state.reopen)
		assert.are.equal("casting", state.guideStep)
		assert.are.same({ "guide" }, seen.releases)

		seen.restricted = false
		guide:RestrictionChanged(false)
		assert.is_true(guide:IsOpen())
		assert.is_false(state.reopen)
		assert.are.same({ "casting", "casting" }, shownIds(seen))
		assert.are.equal("open", seen.shown[2].how)
		assert.are.same({ "guide", "guide" }, seen.holds)
	end)

	it("does nothing as a restriction starts or ends while it is closed", function()
		local guide, seen, state = guideOver(everyStep())

		guide:RestrictionChanged(true)
		guide:RestrictionChanged(false)

		assert.is_false(state.reopen)
		assert.are.same({}, seen.shown)
	end)

	it("never reopens for a reopen saved by an earlier login, and clears it (ONB-R25)", function()
		local guide, seen, state = guideOver(everyStep())
		state.reopen = true

		guide:RestrictionChanged(false)

		assert.is_false(guide:IsOpen())
		assert.is_false(state.reopen)
		assert.are.same({}, seen.shown)
	end)

	it("waits out a restriction when asked to open during one, then opens where asked (ONB-R25)", function()
		local guide, seen = guideOver(everyStep())
		seen.restricted = true

		guide:Open("board")
		assert.is_false(guide:IsOpen())
		assert.are.equal(1, #seen.printed)

		seen.restricted = false
		guide:RestrictionChanged(false)
		assert.are.same({ "board" }, shownIds(seen))
	end)
end)

describe("the tour stops' showing (ONB-R84, CORE-R68)", function()
	it("shows a step without writing guideStep or stepsSeen, and closes again at its hide", function()
		local guide, seen, state = guideOver(everyStep())
		state.guideStep = "box"
		state.stepsSeen = { welcome = true, box = true }

		guide:TourShow("ledger")
		assert.is_true(guide:IsOpen())
		assert.are.same({ "ledger" }, shownIds(seen))
		assert.is_false(seen.page.ribbons[6].seen)
		guide:Next()
		guide:TourHide()

		assert.is_false(guide:IsOpen())
		assert.are.equal("box", state.guideStep)
		assert.are.same({ welcome = true, box = true }, state.stepsSeen)
		assert.are.same({ "guide" }, seen.releases)
	end)

	it("turns back to the step that was open, leaving the guide open, and then marks as before", function()
		local guide, seen, state = guideOver(everyStep())
		guide:Open("box")

		guide:TourShow("board")
		guide:TourHide()

		assert.is_true(guide:IsOpen())
		assert.are.same({ "box", "board", "box" }, shownIds(seen))
		assert.are.same({ box = true }, state.stepsSeen)
		guide:Next()
		assert.are.equal("casting", state.guideStep)
	end)

	it("never sets reopen when a restriction closes a step the tour showed", function()
		local guide, seen, state = guideOver(everyStep())
		guide:TourShow("ledger")

		seen.restricted = true
		guide:RestrictionChanged(true)
		guide:TourHide()

		assert.is_false(state.reopen)
		assert.is_false(guide:IsOpen())
	end)
end)
