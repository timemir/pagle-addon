-- The Catch log at the sizes players and test logs reach (LOG-R98, LOG-R103–R105): a log of 441,178 entries, as the
-- format-4 big20 test log held on the retail client on 29 Oct, opens and answers every question a login asks of it
-- without looking at every entry, and a login whose Session cutter was kept walks no Session. The times are desktop
-- Lua's, printed for the PR; the budgets are generous, to catch a walk that grows with the log, not to time it.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os
local clock = os.clock

local ENTRIES = 441178

-- `n` Casts of Ada's 30 s apart, with an hour between each 60 (ten minutes is a Session break), one build and one
-- Skill Reading at the start. With `one`, no break at all: the log is one Session, as no player's is.
local function entries(n, one)
	local list, time = { "B1|1|1791000000|0|70338|1.60.1|pagle-2026c", "S1|1|1791000001|0|86|150|25" }, 1791000002
	for i = 1, n do
		time = time + ((not one and i % 60 == 0) and 3600 or 30)
		list[#list + 1] = ("C1|1|%d|0|c|494|1439|1|148|453|86|25|263|||%dx1"):format(time, 6303 + i % 4)
	end
	return list
end

local function milliseconds(from)
	return math.floor((clock() - from) * 1000 + 0.5)
end

describe("the Catch log at 441,178 entries #slow", function()
	local data = setLogEntries(savedLog({}, 4), entries(ENTRIES - 2), 256)
	local report = {}

	local function timed(name, fn)
		local from = clock()
		local result = fn()
		report[#report + 1] = ("%s %d ms"):format(name, milliseconds(from))
		return result, milliseconds(from)
	end

	teardown(function()
		print("441,178 entries: " .. table.concat(report, ", "))
	end)

	it("holds the log in about 1,700 blocks and checks them in a login's time", function()
		assert.are.equal(ENTRIES, data.count)
		assert.are.equal(1724, #data.blocks)
		local problem, took = timed("block check", function()
			return ns.CatchLogProblem(data)
		end)
		assert.is_nil(problem)
		assert(took < 1000, took)
		local _, again = timed("block check again", function()
			return ns.CatchLogProblem(data)
		end)
		assert(again < 50, "a log still as it passed is not read again")
	end)

	it(
		"finds the Prestiges, the Companion entry, the last build and Skill Reading without looking at every entry",
		function()
			local global = {}
			local catchLog = ns.OpenCatchLog(data, global, 1791999999)
			local _, prestiges = timed("Prestiges", function()
				assert.are.equal(0, catchLog:Prestiges())
			end)
			local _, companion = timed("HasCompanion", function()
				assert.is_false(catchLog:HasCompanion())
			end)
			local _, build = timed("last build", function()
				assert.are.equal(1, catchLog:Reverse("build")().seq)
			end)
			local _, skill = timed("last Skill Reading", function()
				assert.are.equal(2, catchLog:Reverse("skill")().seq)
			end)
			for _, took in ipairs({ prestiges, companion, build, skill }) do
				assert(took < 300, took)
			end
		end
	)

	it("cuts the tail Session in a login's time, and a login that kept the cutter walks none", function()
		local global = {}
		local catchLog = ns.OpenCatchLog(data, global, 1791999999, function()
			return nil
		end)
		local session, took = timed("tail Session", function()
			return catchLog:Session()
		end)
		assert(took < 500, took)
		assert.are.equal(57, session.casts) -- Casts 441,120 to 441,176: each 60th opens a Session
		local again = ns.OpenCatchLog(data, global, 1791999999)
		local second, warm = timed("tail Session, kept cutter", function()
			return again:Session()
		end)
		assert.are.same(session, second)
		assert(warm < 50, warm)
	end)

	it("appends a Skill Reading and a build without counting the log, and keeps the cutter up to date", function()
		local global = {}
		local catchLog = ns.OpenCatchLog(data, global, 1791999999, function()
			return nil
		end)
		local _, took = timed("Skill Reading and build appended", function()
			catchLog:Append({ kind = "skill", char = 1, time = 1900000000, rank = 87, max = 150, mod = 25 })
			catchLog:Append({
				kind = "build",
				char = 1,
				time = 1900000001,
				build = 70339,
				version = "1.60.2",
				rules = "pagle-2026c",
			})
		end)
		assert(took < 300, took)
		assert.are.equal(data.count, global.tailSession.seq)
	end)
end)

describe("the Catch log as one Session of 110,000 Casts #slow", function()
	it("cuts it whole once, and the next login not at all", function()
		local data = setLogEntries(savedLog({}, 4), entries(110000, true), 256)
		local global = {}
		local from = clock()
		local first = ns.OpenCatchLog(data, global, 1791999999):Session()
		local cold = milliseconds(from)
		from = clock()
		local second = ns.OpenCatchLog(data, global, 1791999999):Session()
		local warm = milliseconds(from)
		print(("110,000 Casts in one Session: cut cold %d ms, kept cutter %d ms"):format(cold, warm))
		assert.are.equal(110000, first.casts)
		assert.are.same(first, second)
		assert(warm < 50, warm)
	end)
end)
