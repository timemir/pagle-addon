-- Whether a goal can be taken down, once per board day (TKB-R55), and what "take it down" says under the mouse
-- (TKB-R55, TKB-R44, TKB-R108), decided by logic/Reroll.lua on FakePagle over the fixture catalogue. The projection
-- that sets a re-posted goal's day and the button that enforces the rule are adapter/Projection_spec and
-- adapter/Reroll_spec's.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

local BLACKMOUTH, REMOVED_FISH = 6358, 92003

-- A goal on the board (TackleGoal): a Notice or an Expedition, open, issued on board day 3. `fields` changes any of it.
local function goal(goalType, fields)
	local g = {
		id = "Player-1-0A-1791731747-0",
		seq = 5,
		type = goalType,
		kind = "lure",
		tier = goalType == "e" and 0 or 2,
		pay = goalType == "e" and 60 or 15,
		need = 3,
		reposted = false,
		pin = 1,
		issuedDay = 3,
		time = 0,
		progress = 0,
		seen = {},
	}
	for key, value in pairs(fields or {}) do
		g[key] = value
	end
	return g
end

-- The Tackle Board loaded: its namespace, and Core's catalogue calls it reads (ns.api.pagle).
local function load()
	local ns = board.load().ns
	return ns, ns.api.pagle
end

-- A board state at board day `today` holding `g`.
local function stateWith(ns, g, today)
	local state = ns.NewBoardState()
	state.day = today
	state.goals[g.id] = g
	return state
end

describe("a goal re-posted today (TKB-R55)", function()
	it("is one a take-down posted on this board day or a later one, and no other", function()
		local ns = load()
		local issued = goal("n")
		local reposted = goal("n", { reposted = true, issuedDay = 3 })

		assert.is_false(ns.IsRepostedToday(issued, 3)) -- not re-posted, whatever its day
		assert.is_true(ns.IsRepostedToday(reposted, 3))
		assert.is_true(ns.IsRepostedToday(reposted, 2)) -- a clock step back leaves it blocked
		assert.is_false(ns.IsRepostedToday(reposted, 4))
	end)
end)

describe("whether a goal can be taken down (TKB-R55, TKB-R44)", function()
	it("allows an open goal that was not re-posted, a Notice or an Expedition, on the day it was issued", function()
		local ns, pagle = load()

		for _, goalType in ipairs({ "n", "e" }) do
			local g = goal(goalType)
			assert.are.equal(g, ns.TakeDownGoal(stateWith(ns, g, 3), g.id, pagle))
		end
	end)

	it("refuses a re-posted goal on the day it was re-posted, and allows it from the next board day", function()
		local ns, pagle = load()

		for _, goalType in ipairs({ "n", "e" }) do
			local g = goal(goalType, { reposted = true, issuedDay = 3 })
			assert.is_nil(ns.TakeDownGoal(stateWith(ns, g, 3), g.id, pagle))
			assert.are.equal(g, ns.TakeDownGoal(stateWith(ns, g, 4), g.id, pagle))
			-- a long absence: the next daily reset is every day's, an Expedition's too
			assert.are.equal(g, ns.TakeDownGoal(stateWith(ns, g, 10), g.id, pagle))
		end
	end)

	it("allows a stranded goal re-posted today, and refuses a completed or unknown one", function()
		local ns, pagle = load()
		local stranded = goal("n", { kind = "species", target = REMOVED_FISH, reposted = true, issuedDay = 3 })
		local done = goal("n", { doneDay = 3 })

		assert.are.equal(stranded, ns.TakeDownGoal(stateWith(ns, stranded, 3), stranded.id, pagle))
		assert.is_nil(ns.TakeDownGoal(stateWith(ns, done, 3), done.id, pagle))
		assert.is_nil(ns.TakeDownGoal(stateWith(ns, done, 3), "Player-0-0-0-0", pagle))
	end)
end)

describe('"take it down"\'s tooltip (TKB-R55, TKB-R44, TKB-R108)', function()
	it("says the new one waits for the daily reset, with the time to it", function()
		local ns, pagle = load()

		local tip = ns.TakeDownTip(goal("n"), 3, false, pagle, "13h")

		assert.are.equal(ns.L.TAKE_DOWN_TIP_TITLE, tip[1])
		assert.are.equal(
			"The new one can't be taken down again until the daily reset (in 13h), unless it stops being catchable.",
			tip[3]
		)
	end)

	it("says the board is updating before anything about the reset", function()
		local ns, pagle = load()

		assert.are.equal(ns.L.TAKE_DOWN_TIP_UPDATING, ns.TakeDownTip(goal("n"), 3, true, pagle, "13h")[3])
	end)

	it(
		"says a stranded goal re-posted today comes down though re-posted, and any other stranded goal just that",
		function()
			local ns, pagle = load()
			local today = goal("n", { kind = "species", target = REMOVED_FISH, reposted = true, issuedDay = 3 })
			local yesterday = goal("n", { kind = "species", target = REMOVED_FISH, reposted = true, issuedDay = 2 })
			local first = goal("n", { kind = "species", target = REMOVED_FISH, reposted = false, issuedDay = 3 })

			assert.are.equal(ns.L.TAKE_DOWN_TIP_STRANDED, ns.TakeDownTip(today, 3, false, pagle, "13h")[3])
			-- a re-post of an earlier day is no "even though it was re-posted": nothing held it back
			assert.are.equal(ns.L.TAKE_DOWN_TIP_STRANDED_FIRST, ns.TakeDownTip(yesterday, 3, false, pagle, "13h")[3])
			assert.are.equal(ns.L.TAKE_DOWN_TIP_STRANDED_FIRST, ns.TakeDownTip(first, 3, false, pagle, "13h")[3])
		end
	)
end)

describe("the confirm's question and the post's (TKB-R56, TKB-R59)", function()
	it("tell the player the new goal can't be taken down again today, and that a posted one can once a day", function()
		local ns, pagle = load()
		local g = goal("n", { progress = 2, need = 3, kind = "species", target = BLACKMOUTH })

		local question = ns.TakeDownQuestion(g, 3, pagle)

		assert.are.equal(
			"Its progress (2/3) is lost, and the new one can't be taken down again today.",
			question and question.text
		)
		assert.are.equal(
			"This uses 1 Refresh, and it can't be undone. The new goal can be taken down once a day, like any other.",
			ns.PostQuestion("n").text
		)
	end)
end)
