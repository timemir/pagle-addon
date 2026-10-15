-- The live tracker's lines (STA-R81, STA-R82, STA-R83, STA-R85; stats.md › UI › Live tracker): whether it shows, its
-- header, this Session's lines, each watch's line and its hover, over hand-built StatsState tables and the fixture
-- catalogue through Core's own accessors. The block docked and drawn is in adapter/Tracker_spec.lua.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local DARKSHORE, AUBERDINE, FERALAS = 148, 442, 357
local MACKEREL, BLACKMOUTH, FIREFIN, SMALLFISH, NIGHTFIN = 6303, 6358, 6359, 6291, 13759
local NOW = 1791740000

-- A state in stats.md's Projection state shape with what the tracker reads.
---@param fields table?
---@return StatsState
local function stateWith(fields)
	local state =
		{ totals = { casts = 0, catches = 0, gotAway = 0 }, places = {}, scopes = {}, hits = {}, sessions = {} }
	for key, value in pairs(fields or {}) do
		state[key] = value
	end
	return state
end

-- A Session record (StatsSession), `seconds` long, ending at NOW.
local function record(id, seconds, casts, catches, gotAway, skill)
	return {
		id = id,
		startTime = NOW - seconds,
		endTime = NOW,
		casts = casts,
		catches = catches,
		gotAway = gotAway,
		chars = {},
		zones = {},
		items = {},
		skill = skill or 0,
	}
end

-- Core's Session (PagleSession, LOG-R64), as Pagle.GetSession() hands it out.
local function live(id, seconds, casts, catches, gotAway)
	return {
		id = id,
		startTime = NOW - seconds,
		endTime = NOW,
		casts = casts,
		catches = catches,
		gotAway = gotAway,
		characters = {},
		zones = {},
	}
end

-- 400 Casts in Darkshore on the hi side (its line is 170; skill 150 + 25 is past it).
local function watchedState()
	return stateWith({
		totals = { casts = 400, catches = 0, gotAway = 0 },
		places = { [DARKSHORE] = { zone = DARKSHORE, casts = 400, catches = 0, gotAway = 0, items = {} } },
		scopes = { ["148:hi"] = 400, ["148:hi:night"] = 150 },
		hits = {
			-- k/n = 0.1, since 20: P = 0.9^20 ≈ 0.12, normal (STA-R52)
			["148:hi#6303"] = { n = 40, at = 380, last = NOW - 600 },
			-- k/n = 0.25, since 20: P = 0.75^20 ≈ 0.0032, unlucky
			["148:hi#6358"] = { n = 100, at = 380, last = NOW - 600 },
			-- caught on the last Cast: a Dry spell of 0
			["148:hi#6291"] = { n = 4, at = 400, last = NOW - 60 },
			-- by night: k/n = 0.5, since 20: P = 0.5^20 ≈ 9.5e-7, very unlucky
			["148:hi:night#13759"] = { n = 75, at = 130, last = NOW - 900 },
		},
	})
end

-- The texts of the lines, by kind: "header <text> | <right>", "line <text>", "watch <band> <name> | <count> | <sub>".
local function read(lines)
	local out = {}
	for i, line in ipairs(lines) do
		if line.kind == "header" then
			out[i] = ("header %s | %s"):format(line.text, line.right)
		elseif line.kind == "line" then
			out[i] = ("line %s%s"):format(line.text, line.dim and " (dim)" or "")
		else
			out[i] = ("watch %s %s | %s | %s"):format(line.band or "grey", line.name, line.count, line.sub)
		end
	end
	return out
end

describe("the live tracker's lines", function()
	local loaded = stats.load()
	local ns = loaded.ns
	loaded.client.areaNames[DARKSHORE] = "Darkshore"
	loaded.client.areaNames[AUBERDINE] = "Auberdine"
	loaded.client.areaNames[FERALAS] = "Feralas"
	loaded.client.itemNames[MACKEREL] = "Raw Mackerel"
	loaded.client.itemNames[BLACKMOUTH] = "Oily Blackmouth"
	loaded.client.itemNames[FIREFIN] = "Firefin Snapper"
	loaded.client.itemNames[NIGHTFIN] = "Raw Nightfin Snapper"

	-- The tracker's lines with these inputs: on, not updating, skill 175, at NOW, no Session and no watch by default.
	local function lines(fields)
		local input = { on = true, state = stateWith(), watched = {}, updating = false, skill = 175, now = NOW }
		for key, value in pairs(fields or {}) do
			input[key] = value
		end
		return ns.TrackerLines(input)
	end

	describe("when it shows (STA-R81, STA-R97)", function()
		it("shows while on with a current Session or a watch", function()
			local session = record("S1", 1260, 38, 31, 7)
			local state = stateWith({ sessions = { session } })

			assert.is_true(lines({ state = state, live = live("S1", 1260, 38, 31, 7) }).shown)
			assert.is_true(lines({ watched = { { item = MACKEREL, area = DARKSHORE } } }).shown)
		end)

		it("hides with no current Session and no watch, even with Sessions on record", function()
			local state = stateWith({ sessions = { record("S1", 1260, 38, 31, 7) } })

			assert.is_false(lines({ state = state }).shown)
		end)

		it("hides while off, whatever there is to show", function()
			local state = stateWith({ sessions = { record("S1", 1260, 38, 31, 7) } })

			local view = lines({
				on = false,
				state = state,
				live = live("S1", 1260, 38, 31, 7),
				watched = { { item = MACKEREL, area = DARKSHORE } },
			})

			assert.is_false(view.shown)
		end)
	end)

	describe("its header and this Session's lines (STA-R82)", function()
		it('reads "Session · 21m", the counts and the per-hour line with skill gained during a Session', function()
			local state = stateWith({ sessions = { record("S0", 600, 5, 5, 0), record("S1", 1260, 38, 31, 7, 3) } })

			local view = lines({ state = state, live = live("S1", 1260, 38, 31, 7) })

			-- 31 × 3600 / 1260 ≈ 88.6, rounded half up (STA-R33)
			assert.are.same({
				"header Stats | Session · 21m",
				"line 38 Casts · 31 Catches · 7 got away",
				"line 89 per hour · skill +3 (dim)",
			}, read(view.lines))
			assert.is_true(view.ticking)
		end)

		it('reads "skill +0" with no skill gained, and singular counts (STA-R59, STA-R82)', function()
			local state = stateWith({ sessions = { record("S1", 30, 1, 1, 0) } })

			local view = lines({ state = state, live = live("S1", 30, 1, 1, 0) })

			-- under 60 s, Catches per hour divides by 60 s (STA-R33)
			assert.are.same({
				"header Stats | Session · under 1m",
				"line 1 Cast · 1 Catch · 0 got away",
				"line 60 per hour · skill +0 (dim)",
			}, read(view.lines))
		end)

		it('reads "no Session" on the header with none open, and no Session lines', function()
			local state = stateWith({ sessions = { record("S1", 1260, 38, 31, 7) } })

			local view = lines({ state = state, watched = { { item = MACKEREL, area = DARKSHORE } } })

			assert.are.same("header Stats | no Session", read(view.lines)[1])
			assert.are.equal("watch", view.lines[2].kind)
			assert.is_false(view.ticking)
		end)
	end)

	describe("each watch's line (STA-R82, STA-R64)", function()
		it("reads its dot, name, Dry spell count and sub-line, oldest first, each knowing its watch", function()
			loaded.client.itemNames[SMALLFISH] = "Raw Brilliant Smallfish"
			finally(function()
				loaded.client.itemNames[SMALLFISH] = nil
			end)
			local watched = {
				{ item = MACKEREL, area = DARKSHORE },
				{ item = BLACKMOUTH, area = DARKSHORE },
				{ item = NIGHTFIN, area = DARKSHORE },
				{ item = SMALLFISH, area = DARKSHORE },
				{ item = FIREFIN, area = AUBERDINE },
			}

			local view = lines({ state = watchedState(), watched = watched })

			assert.are.same({
				"header Stats | no Session",
				"watch normal Raw Mackerel | 20 | Darkshore · normal",
				"watch unlucky Oily Blackmouth | 20 | Darkshore · unlucky",
				"watch veryUnlucky Raw Nightfin Snapper | 20 | Darkshore · by night · very unlucky",
				-- a known Dry spell of 0: P = 1, a green dot and "normal" (STA-R51, STA-R52, STA-R82)
				"watch normal Raw Brilliant Smallfish | just now | Darkshore · normal",
				-- never caught in its scope: the bare count; Auberdine has under 100 Casts, so it reads across
				-- Darkshore, under the place's own name (STA-R42)
				"watch grey Firefin Snapper | 400 | Auberdine · not seen yet",
			}, read(view.lines))
			assert.are.same({ MACKEREL, DARKSHORE }, { view.lines[2].item, view.lines[2].area })
			assert.are.same({ FIREFIN, AUBERDINE }, { view.lines[6].item, view.lines[6].area })
			assert.are.same({}, view.pending)
		end)

		it("reads learning in short with no luck reading, and lists an unloaded item to ask for (STA-R43)", function()
			local state = watchedState()
			state.scopes["357:hi"] = 37
			state.places[FERALAS] = { zone = FERALAS, casts = 37, catches = 0, gotAway = 0, items = {} }

			-- Feralas' line is 300: skill 310 is past it
			local view = lines({ state = state, skill = 310, watched = { { item = SMALLFISH, area = FERALAS } } })

			assert.are.same(
				{ "header Stats | no Session", "watch grey Item 6291 | 37 | Feralas · learning 37/100" },
				read(view.lines)
			)
			assert.are.same({ SMALLFISH }, view.pending)
		end)

		it(
			"reads a watch on the reading side of the moment: below the line, the lo scope (STA-R41, STA-R64)",
			function()
				local state = watchedState()
				state.scopes["148:lo"] = 12

				local view = lines({ state = state, skill = 100, watched = { { item = MACKEREL, area = DARKSHORE } } })

				assert.are.equal("watch grey Raw Mackerel | 12 | Darkshore · learning 12/100", read(view.lines)[2])
			end
		)
	end)

	describe("while the projection is updating (STA-R85, STA-R32)", function()
		it("reads the Session lines from Core's Session alone, and each watch's name with updating", function()
			local view = lines({
				updating = true,
				state = watchedState(),
				live = live("S9", 125, 4, 3, 1),
				watched = { { item = BLACKMOUTH, area = AUBERDINE } },
			})

			assert.are.same({
				"header Stats | Session · 2m",
				"line 4 Casts · 3 Catches · 1 got away",
				"watch grey Oily Blackmouth | updating | Auberdine",
			}, read(view.lines))
			assert.is_true(view.shown)
		end)

		it("reads Core's Session alone too while Stats has no record of it yet", function()
			local state = stateWith({ sessions = { record("S1", 1260, 38, 31, 7, 3) } })

			local view = lines({ state = state, live = live("S2", 125, 4, 3, 1) })

			assert.are.same(
				{ "header Stats | Session · 2m", "line 4 Casts · 3 Catches · 1 got away" },
				read(view.lines)
			)
		end)
	end)

	describe("a watch's hover (STA-R83)", function()
		-- The hover of a watch with these inputs: not updating, skill 175, at NOW.
		local function hover(watch, fields)
			local input = { state = watchedState(), updating = false, skill = 175, now = NOW }
			for key, value in pairs(fields or {}) do
				input[key] = value
			end
			return ns.TrackerHover(input, watch)
		end

		it(
			"titles it with the item, then its Dry spell, its luck wording and its Your odds sentence under the heading (STA-R46)",
			function()
				local title, lines_, heading = hover({ item = MACKEREL, area = DARKSHORE })

				assert.are.equal("Raw Mackerel", title)
				assert.are.equal(3, heading)
				assert.are.same({
					"20 Casts since my last Raw Mackerel.",
					"About 12 anglers in 100 wait this long. Nothing unusual.",
					"Your odds",
					"From 400 of my Casts here, at or above 170 skill; 40 caught.",
				}, lines_)
			end
		)

		it("adds STA-R46's sentences that apply: the entry, the window and the pool (STA-R46)", function()
			local _, nightfin = hover({ item = NIGHTFIN, area = DARKSHORE })
			local _, blackmouth = hover({ item = BLACKMOUTH, area = DARKSHORE })

			assert.are.same({
				"20 Casts since my last Raw Nightfin Snapper.",
				"Fewer than 1 angler in a million waits this long. Very unlucky, and every Cast is still its own roll.",
				"Your odds",
				"From 150 of my Casts here by night, at or above 170 skill; 75 caught.",
				"Pagle hasn't confirmed it bites here yet.",
				"The window isn't confirmed yet.",
			}, nightfin)
			assert.are.same({
				"20 Casts since my last Oily Blackmouth.",
				"Roughly 1 angler in 320 waits this long. Unlucky, not broken.",
				"Your odds",
				"From 400 of my Casts here, at or above 170 skill; 100 caught.",
				"Pagle hasn't confirmed it bites here yet.",
				"Open water and pools combined: there is no pool data.",
			}, blackmouth)
		end)

		it("reads STA-R54's and STA-R50's texts, then the unseen or learning sentence (STA-R50, STA-R54)", function()
			local state = watchedState()
			state.scopes["357:hi"] = 37
			state.places[FERALAS] = { zone = FERALAS, casts = 37, catches = 0, gotAway = 0, items = {} }

			local _, smallfish = hover({ item = SMALLFISH, area = DARKSHORE })
			local _, firefin = hover({ item = FIREFIN, area = AUBERDINE })
			local _, learning = hover({ item = SMALLFISH, area = FERALAS }, { state = state, skill = 310 })

			assert.are.same({
				"Caught one on my last Cast here.",
				"Your odds",
				"From 400 of my Casts here, at or above 170 skill; 4 caught.",
				"Pagle hasn't confirmed it bites here yet.",
			}, smallfish)
			assert.are.same({
				"400 Casts across Darkshore, none yet.",
				"Your odds",
				"In 400 Casts across Darkshore, at or above 170 skill: rarer than about 1 in 130, if it bites here at all.",
				"Pagle hasn't confirmed it bites here yet.",
			}, firefin)
			assert.are.same({
				"37 Casts here, none yet.",
				"Your odds",
				"37 of the 100 Casts I need here, at or above 300 skill before Your odds show a number.",
				"The no-junk line isn't confirmed yet.", -- Feralas' skillBase isn't confirmed in the fixture
			}, learning)
		end)

		it("reads only the updating line while the projection is updating (STA-R85)", function()
			local title, lines_, heading = hover({ item = MACKEREL, area = DARKSHORE }, { updating = true })

			assert.are.equal("Raw Mackerel", title)
			assert.are.same({ "Updating my records…" }, lines_)
			assert.is_nil(heading)
		end)
	end)
end)
