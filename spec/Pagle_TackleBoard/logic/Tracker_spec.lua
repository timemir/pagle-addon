-- The tracker's lines (TKB-R2, TKB-R104, TKB-R120–R124): whether it shows, its header, the goals workable here in
-- board order with their counts and where lines, the "+N more" and "All done" lines, the collapsed and updating
-- states and the "Complete" flash, decided by logic/Tracker.lua over hand-built TackleBoardState tables, on FakePagle
-- over the fixture catalogue with the fake client's names. The block docked and drawn is in adapter/Tracker_spec.lua.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

local DUROTAR, DARKSHORE, BARRENS = 14, 148, 17
local SMALLFISH = 6291 -- a Species with a catch entry in Durotar, none in Darkshore (fixture)

-- The Tackle Board loaded, its client knowing the fixture's names.
local function loadNamed()
	local loaded = board.load()
	loaded.client.areaNames[DUROTAR] = "Durotar"
	loaded.client.areaNames[DARKSHORE] = "Darkshore"
	loaded.client.itemNames[SMALLFISH] = "Raw Brilliant Smallfish"
	return loaded.ns
end

local nextSeq = 0

-- An open goal (TackleGoal) with ID `id`: a Notice or an Expedition of `kind`, with no progress. `fields` changes any
-- of it.
local function goal(id, goalType, kind, fields)
	nextSeq = nextSeq + 1
	local g = {
		id = id,
		seq = nextSeq,
		type = goalType,
		kind = kind,
		tier = goalType == "e" and 0 or 2,
		pay = goalType == "e" and 60 or 15,
		need = 30,
		reposted = false,
		issuedDay = 0,
		time = SERVER_TIME,
		progress = 0,
		seen = {},
	}
	for key, value in pairs(fields or {}) do
		g[key] = value
	end
	return g
end

-- A started board (TackleBoardState) holding `goals`: each pinned in order on the first empty pin of its type, a goal
-- with `pin = false` in the overflow strip; a goal with `doneDay` is done and on no pin. Its Campfire at `fire` days.
local function started(ns, goals, fire)
	local state = ns.NewBoardState()
	state.started = { seq = 1, time = SERVER_TIME }
	state.fire.count = fire or 0
	for _, g in ipairs(goals) do
		state.goals[g.id] = g
		if g.pin == false then
			g.pin = nil
		elseif not g.doneDay then
			local pins = g.type == "e" and state.pins.expeditions or state.pins.notices
			for i, id in ipairs(pins) do
				if not id then
					pins[i], g.pin = g.id, i
					break
				end
			end
		end
	end
	return state
end

-- The tracker's view for `state` in Darkshore: on, built, started, expanded, not updating, no flash, unless `fields`
-- says otherwise.
local function view(ns, state, fields)
	local input = {
		on = true,
		built = true,
		started = state.started ~= nil,
		updating = false,
		collapsed = false,
		state = state,
		zone = DARKSHORE,
		flashing = {},
	}
	for key, value in pairs(fields or {}) do
		input[key] = value
	end
	return ns.TrackerView(input)
end

-- The view's lines as read: "<title> | <right>" for the header (with "(flame) " before the right text while it shows
-- the flame), "<text> | <count> | <where>" for a goal, "<text> | Complete" for a flashing one, a plain line's text.
local function read(shown)
	local out = {}
	for _, line in ipairs(shown.lines) do
		if line.kind == "header" then
			out[#out + 1] = line.text .. " | " .. (line.fire and "(flame) " or "") .. (line.right or "")
		elseif line.kind == "goal" and line.complete then
			out[#out + 1] = line.text .. " | " .. line.count
		elseif line.kind == "goal" then
			out[#out + 1] = line.text .. " | " .. line.count .. " | " .. line.where
		else
			out[#out + 1] = line.text
		end
	end
	return out
end

describe("when the tracker shows (TKB-R120, TKB-R2)", function()
	it("shows a started board once the projection's first update this login is done, with the setting on", function()
		local ns = loadNamed()
		local state = started(ns, {})

		assert.is_true(view(ns, state).shown)
	end)

	it("shows nothing before Start, before the first update ends, or with the setting off", function()
		local ns = loadNamed()
		local state = started(ns, {})

		assert.is_false(view(ns, ns.NewBoardState()).shown) -- TKB-R2: nothing before Start
		assert.is_false(view(ns, state, { built = false }).shown)
		assert.is_false(view(ns, state, { on = false }).shown)
	end)
end)

describe("its header (TKB-R122)", function()
	it("reads the title, the flame with the Campfire's days and the open goals", function()
		local ns = loadNamed()
		local state = started(ns, {
			goal("a", "n", "lure", { need = 25 }),
			goal("b", "n", "haul", { target = DUROTAR }),
			goal("c", "e", "rarity", { need = 8, target = 3 }),
		}, 5)

		local lines = view(ns, state).lines

		assert.are.equal("Tackle Board | (flame) 5 · 3 open", read(view(ns, state))[1])
		assert.is_true(lines[1].fire)
		assert.is_false(lines[1].collapsed)
	end)

	it("reads the open goals alone, with no flame, while no fire is lit", function()
		local ns = loadNamed()
		local state = started(ns, { goal("a", "n", "lure", { need = 25 }) })

		assert.are.equal("Tackle Board | 1 open", read(view(ns, state))[1])
	end)
end)

describe("its goal lines (TKB-R121, TKB-R122, TKB-R104)", function()
	it(
		'lists the goals workable here in board order with their counts and where, then "+N more (elsewhere)"',
		function()
			local ns = loadNamed()
			local state = started(ns, {
				goal("lure", "n", "lure", { need = 25, progress = 4 }),
				goal("durotar", "n", "haul", { target = DUROTAR }),
				goal("darkshore", "n", "haul", { target = DARKSHORE, progress = 12 }),
				goal("rarity", "e", "rarity", { need = 8, target = 3 }),
				goal("strip", "n", "rarity", { need = 3, target = 2, pin = false }),
			})

			local shown = view(ns, state)

			-- Board order: the Expedition pin, the Notice pins, then the strip (TKB-R101). Durotar's Haul isn't here.
			assert.are.same({
				"Tackle Board | 5 open",
				"Expedition: 8 Catches of a rare variety or better | 0/8 | anywhere",
				"25 Catches with a lure on | 4/25 | anywhere",
				"30 Catches in Darkshore | 12/30 | Darkshore · here",
				"3 Catches of an uncommon variety or better | 0/3 | anywhere",
				"+1 more on the board (elsewhere)",
			}, read(shown))
			assert.is_true(shown.lines[2].expedition)
			assert.are.equal("rarity", shown.lines[2].goalID)
			assert.is_falsy(shown.lines[3].expedition)
			assert.are.equal("darkshore", shown.lines[4].goalID)
		end
	)

	it("follows the zone: in Durotar its Haul and Species goals are here and Darkshore's isn't", function()
		local ns = loadNamed()
		local state = started(ns, {
			goal("durotar", "n", "haul", { target = DUROTAR }),
			goal("darkshore", "n", "haul", { target = DARKSHORE }),
			goal("species", "n", "species", { need = 10, target = SMALLFISH }),
		})

		assert.are.same({
			"Tackle Board | 3 open",
			"30 Catches in Durotar | 0/30 | Durotar · here",
			"10 Raw Brilliant Smallfish | 0/10 | wherever it bites · here",
			"+1 more on the board (elsewhere)",
		}, read(view(ns, state, { zone = DUROTAR })))
	end)

	it("lists only the always-workable goals in zone 0 (TKB-R121)", function()
		local ns = loadNamed()
		local state = started(ns, {
			goal("darkshore", "n", "haul", { target = DARKSHORE }),
			goal("lure", "n", "lure", { need = 25 }),
		})

		assert.are.same({
			"Tackle Board | 2 open",
			"25 Catches with a lure on | 0/25 | anywhere",
			"+1 more on the board (elsewhere)",
		}, read(view(ns, state, { zone = 0 })))
	end)

	it('has no "+N more" line when every open goal is workable here', function()
		local ns = loadNamed()
		local state = started(ns, { goal("lure", "n", "lure", { need = 25 }) })

		assert.are.same(
			{ "Tackle Board | 1 open", "25 Catches with a lure on | 0/25 | anywhere" },
			read(view(ns, state, { zone = BARRENS }))
		)
	end)

	it(
		'shows a day-bound goal\'s progress only on its own board day, and "today · " first (TKB-R104, TKB-R122)',
		function()
			local ns = loadNamed()
			local state = started(ns, {
				goal("collector", "n", "collector", { need = 2, progress = 1, progressDay = 5 }),
			})

			state.day = 5
			assert.are.equal("A junk item and a container today | 1/2 | today · anywhere", read(view(ns, state))[2])
			state.day = 6 -- the live step at the next reset advanced the projection (TKB-R13)
			assert.are.equal("A junk item and a container today | 0/2 | today · anywhere", read(view(ns, state))[2])
		end
	)

	it('reads "All done. Fresh Notices at reset." with nothing open', function()
		local ns = loadNamed()
		local state = started(ns, { goal("done", "n", "lure", { need = 25, progress = 25, doneDay = 0 }) }, 1)

		assert.are.same(
			{ "Tackle Board | (flame) 1 · 0 open", "All done. Fresh Notices at reset." },
			read(view(ns, state))
		)
	end)
end)

describe("collapsed and updating (TKB-R122, TKB-R124)", function()
	it("shows only its header, marked collapsed, while collapsed", function()
		local ns = loadNamed()
		local state = started(ns, { goal("lure", "n", "lure", { need = 25 }) }, 2)

		local shown = view(ns, state, { collapsed = true })

		assert.are.same({ "Tackle Board | (flame) 2 · 1 open" }, read(shown))
		assert.is_true(shown.lines[1].collapsed)
	end)

	it('shows only its header and "Updating…" while the projection is updating', function()
		local ns = loadNamed()
		local state = started(ns, { goal("lure", "n", "lure", { need = 25 }) }, 2)

		local shown = view(ns, state, { updating = true })

		assert.is_true(shown.shown)
		assert.are.same({ "Tackle Board | ", "Updating…" }, read(shown))
	end)

	it("shows only its header while collapsed and updating", function()
		local ns = loadNamed()
		local state = started(ns, {})

		assert.are.same({ "Tackle Board | " }, read(view(ns, state, { updating = true, collapsed = true })))
	end)
end)

describe('the "Complete" flash (TKB-R123)', function()
	it('puts each flashing goal first, its text and "Complete", with no where line', function()
		local ns = loadNamed()
		local state = started(ns, {
			goal("done", "n", "haul", { target = DARKSHORE, progress = 30, doneDay = 0 }),
			goal("expedition", "e", "rarity", { need = 8, target = 3, progress = 8, doneDay = 0 }),
			goal("lure", "n", "lure", { need = 25 }),
		})

		local shown = view(ns, state, { flashing = { "done", "expedition", "gone" } })

		assert.are.same({
			"Tackle Board | 1 open",
			"30 Catches in Darkshore | Complete",
			"Expedition: 8 Catches of a rare variety or better | Complete",
			"25 Catches with a lure on | 0/25 | anywhere",
		}, read(shown))
		assert.is_true(shown.lines[2].complete)
		assert.is_nil(shown.lines[2].where)
		assert.are.equal("done", shown.lines[2].goalID)
		assert.is_true(shown.lines[3].expedition)
	end)

	it('shows a flashing goal above "All done" when it was the last one open', function()
		local ns = loadNamed()
		local state = started(ns, { goal("done", "n", "lure", { need = 25, progress = 25, doneDay = 0 }) })

		assert.are.same({
			"Tackle Board | 0 open",
			"25 Catches with a lure on | Complete",
			"All done. Fresh Notices at reset.",
		}, read(view(ns, state, { flashing = { "done" } })))
	end)
end)
