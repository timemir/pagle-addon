-- The live generation context (M7 graph, shapes; TKB-R30–R33): ns.GenerationContext builds what ns.GenerateGoal
-- reads from the projection's state, Core's catalogue calls and the Angler's best base skill.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

describe("ns.GenerationContext (TKB-R30–R33)", function()
	local loaded, fake, ns

	before_each(function()
		loaded, fake = board.load()
		ns = loaded.ns
		fake.login()
		board.readSkill(fake)
	end)

	-- A goal in the state, open unless `doneDay` is given.
	local function goal(id, seq, kind, target, doneDay)
		return { id = id, seq = seq, type = "n", kind = kind, target = target, doneDay = doneDay }
	end

	it("reads Core's catalogue calls, the Angler's best base skill and the state's zones and caught items", function()
		local state = ns.State()
		state.zones[14] = SERVER_TIME - 3600
		state.caught[92011] = true
		local random = board.random(3)

		local ctx = ns.GenerationContext(state, SERVER_TIME, random)

		assert.are.equal(fake.globals.Pagle, ctx.pagle)
		assert.are.same({ board.SKILL, SERVER_TIME }, { ctx.bestBaseSkill, ctx.now })
		assert.are.equal(state.zones, ctx.zones)
		assert.are.equal(state.caught, ctx.caught)
		assert.are.equal(random, ctx.random)
	end)

	it("lists the open goals, by seq, and leaves out the completed ones", function()
		local state = ns.State()
		state.goals.b = goal("b", 9, "size", 3)
		state.goals.a = goal("a", 4, "haul", 14)
		state.goals.c = goal("c", 6, "quality", 2, 1)

		local open = ns.GenerationContext(state, SERVER_TIME, board.random(1)).open

		assert.are.same({ "a", "b" }, { open[1].id, open[2].id })
		assert.are.equal(2, #open)
	end)

	it("is what ns.GenerateGoal draws a goal from (TKB-R30)", function()
		local ctx = ns.GenerationContext(ns.State(), SERVER_TIME, board.random(5))

		local generated = ns.GenerateGoal(ctx, "e")

		assert.are.same({ "e", 0, 60 }, { generated.type, generated.tier, generated.pay })
	end)
end)
