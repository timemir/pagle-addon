-- The home spread's lines (stats.md › UI › Home spread; STA-R10, STA-R13, STA-R32, STA-R60, STA-R64, STA-R93,
-- STA-R97): the zone tiles of the left page and what "Right now" reads on the right, over hand-built StatsState tables
-- and the fixture catalogue through Core's own accessors. The book drawing them is in adapter/Home_spec.lua.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local DARKSHORE, AUBERDINE, BASHAL_ARAN, ELWYNN = 148, 442, 446, 12
local FERALAS, FEATHERMOON = 357, 1116
local MACKEREL, BLACKMOUTH, FIREFIN, SMALLFISH = 6303, 6358, 6359, 6291
local NOW = 1791740000
local DAY, NIGHT = 600, 1200 -- realm 10:00 and 20:00: the fixture's day is 06:00–18:00, night 18:00–06:00

-- A place record (StatsPlace) with `casts` Casts in `zone`.
local function place(zone, casts)
	return { zone = zone, casts = casts, catches = 0, gotAway = 0, items = {} }
end

-- A state in stats.md's Projection state shape with what the home spread reads.
---@param fields table
---@return StatsState
local function stateWith(fields)
	local state =
		{ totals = { casts = 0, catches = 0, gotAway = 0 }, places = {}, scopes = {}, hits = {}, sessions = {} }
	for key, value in pairs(fields) do
		state[key] = value
	end
	return state
end

-- A live snapshot (LOG-R45) in `zone`/`subzone` at realm minute `minute`, with Fishing rank+mod.
local function conditions(zone, subzone, minute, rank, mod)
	return { zone = zone, subzone = subzone, minute = minute, skillRank = rank, skillMod = mod, events = {}, auras = {} }
end

-- A Session record (StatsSession).
local function session(id, startTime, endTime, casts, catches, gotAway)
	return {
		id = id,
		startTime = startTime,
		endTime = endTime,
		casts = casts,
		catches = catches,
		gotAway = gotAway,
		chars = {},
		zones = {},
		items = {},
		skill = 0,
	}
end

-- The texts of a list of tiles, links or watch lines, by field.
local function pluck(list, field)
	local out = {}
	for i, entry in ipairs(list) do
		local value = entry[field]
		if value == nil then
			value = false
		end
		out[i] = value
	end
	return out
end

describe("the home spread", function()
	local loaded = stats.load()
	local ns = loaded.ns
	loaded.client.areaNames[DARKSHORE] = "Darkshore"
	loaded.client.areaNames[AUBERDINE] = "Auberdine"
	loaded.client.areaNames[BASHAL_ARAN] = "Bashal'Aran"
	loaded.client.areaNames[ELWYNN] = "Elwynn Forest"
	loaded.client.areaNames[FERALAS] = "Feralas"
	loaded.client.areaNames[FEATHERMOON] = "Feathermoon Stronghold"
	loaded.client.itemNames[MACKEREL] = "Raw Mackerel"
	loaded.client.itemNames[BLACKMOUTH] = "Oily Blackmouth"
	loaded.client.itemNames[FIREFIN] = "Firefin Snapper"

	-- Darkshore: 3 Casts, 2 in Auberdine and 1 in Bashal'Aran; Elwynn: 5 Casts, no waters.
	local function fished()
		return stateWith({
			totals = { casts = 8, catches = 6, gotAway = 2 },
			places = {
				[DARKSHORE] = place(DARKSHORE, 3),
				[AUBERDINE] = place(DARKSHORE, 2),
				[BASHAL_ARAN] = place(DARKSHORE, 1),
				[ELWYNN] = place(ELWYNN, 5),
			},
		})
	end

	describe("the left page, Where I've fished (stats.md › UI › Home spread)", function()
		it("tiles each zone in places by my Casts there, with its waters, the current zone first with none", function()
			local waters = ns.HomeWaters(fished(), conditions(FERALAS, FEATHERMOON, DAY, 150, 25), {})

			assert.is_nil(waters.empty)
			assert.are.same({ FERALAS, ELWYNN, DARKSHORE }, pluck(waters.tiles, "zone"))
			assert.are.same({ "Feralas", "Elwynn Forest", "Darkshore" }, pluck(waters.tiles, "name"))
			assert.are.same(
				{ "not fished yet", "5 Casts · 0 waters", "3 Casts · 2 waters" },
				pluck(waters.tiles, "line")
			)
			assert.are.same({ "I'm here", false, false }, pluck(waters.tiles, "here"))
			assert.are.same({ page = "place", area = DARKSHORE }, waters.tiles[3].target)
		end)

		it('marks the current zone "I\'m here" in its place by Casts, from its subzone too (STA-R10)', function()
			local waters = ns.HomeWaters(fished(), conditions(DARKSHORE, AUBERDINE, DAY, 150, 25), {})

			assert.are.same({ ELWYNN, DARKSHORE }, pluck(waters.tiles, "zone"))
			assert.are.same({ false, "I'm here" }, pluck(waters.tiles, "here"))
		end)

		it('notes "watching {N}" on a zone whose watches are on it or one of its subzones (STA-R60)', function()
			local watched = {
				{ item = MACKEREL, area = AUBERDINE },
				{ item = BLACKMOUTH, area = DARKSHORE },
				{ item = SMALLFISH, area = ELWYNN },
			}
			local waters = ns.HomeWaters(fished(), conditions(0, 0, DAY), watched)

			assert.are.same({ ELWYNN, DARKSHORE }, pluck(waters.tiles, "zone"))
			assert.are.same({ "watching 1", "watching 2" }, pluck(waters.tiles, "note"))
		end)

		it("finds a watched subzone's zone in Core's catalogue when my records have no Casts there", function()
			local watched = { { item = MACKEREL, area = AUBERDINE } }
			local state = stateWith({
				totals = { casts = 1, catches = 0, gotAway = 1 },
				places = { [DARKSHORE] = place(DARKSHORE, 1) },
			})

			local waters = ns.HomeWaters(state, conditions(0, 0, DAY), watched)

			assert.are.same({ "watching 1" }, pluck(waters.tiles, "note"))
			assert.are.same({ "1 Cast · 0 waters" }, pluck(waters.tiles, "line"))
		end)

		it("ties by areaID, and leaves out zone 0 (STA-R10, STA-R93)", function()
			local state = stateWith({
				totals = { casts = 4, catches = 0, gotAway = 4 },
				places = { [DARKSHORE] = place(DARKSHORE, 2), [ELWYNN] = place(ELWYNN, 2) },
			})

			local waters = ns.HomeWaters(state, conditions(0, AUBERDINE, DAY), {})

			assert.are.same({ ELWYNN, DARKSHORE }, pluck(waters.tiles, "zone"))
		end)

		it('reads "Not fished anywhere yet." with no Casts, and no tiles, not even here (STA-R97)', function()
			local waters = ns.HomeWaters(stateWith({}), conditions(DARKSHORE, AUBERDINE, DAY, 150, 25), {})

			assert.are.same({}, waters.tiles)
			assert.are.equal("Not fished anywhere yet.", waters.empty)
		end)
	end)

	describe("the right page, Right now (stats.md › UI › Home spread)", function()
		local function rightNow(state, snapshot, live, watched)
			return ns.HomeRightNow(state, snapshot, live, watched or {}, NOW)
		end

		describe("where I am and my skill", function()
			it("reads the subzone, the zone, by day, and a skill past the line (STA-R10, STA-R13)", function()
				local now = rightNow(stateWith({}), conditions(DARKSHORE, AUBERDINE, DAY, 150, 25))

				assert.are.equal("Fishing Auberdine, Darkshore, by day.", now.where)
				-- STA-R12: Darkshore's line is 75 + 95 = 170; 150 + 25 is at or above it
				assert.are.equal("Skill 175, past the no-junk line (170).", now.skill)
			end)

			it("leaves out a subzone 0, reads by night from the night window, and a skill below the line", function()
				local now = rightNow(stateWith({}), conditions(DARKSHORE, 0, NIGHT, 160, 0))

				assert.are.equal("Fishing Darkshore, by night.", now.where)
				assert.are.equal("Skill 160, below the no-junk line (170).", now.skill)
			end)

			it("reads no skill line in a zone with no line (side na, STA-R13)", function()
				local now = rightNow(stateWith({}), conditions(ELWYNN, 0, DAY, 150, 25))

				assert.are.equal("Fishing Elwynn Forest, by day.", now.where)
				assert.is_nil(now.skill)
			end)

			it("leaves out what it can't read in combat: the realm minute and the skill (STA-R93)", function()
				local now = rightNow(stateWith({}), conditions(DARKSHORE, AUBERDINE, nil, nil, nil))

				assert.are.equal("Fishing Auberdine, Darkshore.", now.where)
				assert.is_nil(now.skill)
			end)

			it('reads "I can\'t tell where I am." with zone 0, and Where I am opens home (STA-R74, STA-R93)', function()
				local now = rightNow(stateWith({}), conditions(0, AUBERDINE, DAY, 150, 25))

				assert.are.equal("I can't tell where I am.", now.where)
				assert.is_nil(now.skill)
				assert.are.same({ label = "Where I am: unknown", target = { page = "home" } }, now.contents[1])
			end)
		end)

		describe("the Session (STA-R32, STA-R33)", function()
			local function withSessions()
				return stateWith({
					sessions = {
						session("S1", NOW - 90000, NOW - 86400, 10, 8, 2),
						session("S2", NOW - 1260, NOW - 60, 3, 2, 1),
					},
				})
			end

			it("reads the current Session's Casts, Catches, got away and time so far", function()
				local live =
					{ id = "S2", startTime = NOW - 1260, endTime = NOW - 60, casts = 3, catches = 2, gotAway = 1 }

				local now = rightNow(withSessions(), conditions(DARKSHORE, 0, DAY), live)

				assert.are.equal("This Session: 3 Casts, 2 Catches, 1 got away, 21m so far.", now.session)
			end)

			it("reads Core's Session alone when it isn't the last record yet (STA-R32)", function()
				local live =
					{ id = "S3", startTime = NOW - 60, endTime = NOW - 60, casts = 1, catches = 1, gotAway = 0 }

				local now = rightNow(withSessions(), conditions(DARKSHORE, 0, DAY), live)

				assert.are.equal("This Session: 1 Cast, 1 Catch, 0 got away, 1m so far.", now.session)
			end)

			it("reads when the last one ended with no Session open", function()
				local state = withSessions()
				state.sessions[2].endTime = NOW - 3 * 3600

				local now = rightNow(state, conditions(DARKSHORE, 0, DAY))

				assert.are.equal("No Session right now. The last one ended 3h ago.", now.session)
			end)

			it('reads "No Session yet." with no Sessions ever (STA-R97)', function()
				local now = rightNow(stateWith({}), conditions(DARKSHORE, 0, DAY))

				assert.are.equal("No Session yet.", now.session)
			end)
		end)

		describe("Dry spells I'm watching (STA-R60, STA-R64)", function()
			-- 400 Casts in Darkshore on the hi side; Mackerel, Blackmouth and Smallfish have no window there (STA-R14).
			local function watchedState()
				return stateWith({
					totals = { casts = 400, catches = 0, gotAway = 0 },
					places = { [DARKSHORE] = place(DARKSHORE, 400) },
					scopes = { ["148:hi"] = 400 },
					hits = {
						-- k/n = 0.1, since 20: P = 0.9^20 ≈ 0.12, normal (STA-R52)
						["148:hi#6303"] = { n = 40, at = 380, last = NOW - 600 },
						-- k/n = 0.25, since 20: P = 0.75^20 ≈ 0.0032, unlucky
						["148:hi#6358"] = { n = 100, at = 380, last = NOW - 600 },
						-- caught on the last Cast: a Dry spell of 0
						["148:hi#6291"] = { n = 4, at = 400, last = NOW - 60 },
					},
				})
			end

			it(
				"writes each watch's Dry spell on the reading side, in the forms of the UI, each opening its entry",
				function()
					local watched = {
						{ item = MACKEREL, area = DARKSHORE },
						{ item = BLACKMOUTH, area = DARKSHORE },
						{ item = SMALLFISH, area = DARKSHORE },
						{ item = FIREFIN, area = DARKSHORE },
					}
					loaded.client.itemNames[SMALLFISH] = "Raw Brilliant Smallfish"
					finally(function()
						loaded.client.itemNames[SMALLFISH] = nil
					end)

					local now = rightNow(watchedState(), conditions(DARKSHORE, 0, DAY, 150, 25), nil, watched)

					assert.are.same({
						"Raw Mackerel, Darkshore: 20 since the last.",
						"Oily Blackmouth, Darkshore: 20 since the last, unlucky.",
						"Raw Brilliant Smallfish, Darkshore: caught on my last Cast.",
						"Firefin Snapper, Darkshore: 400 Casts, none yet.",
					}, pluck(now.watches, "text"))
					assert.are.same({ false, ", unlucky", false, false }, pluck(now.watches, "red"))
					assert.are.same({ page = "place", area = DARKSHORE, item = BLACKMOUTH }, now.watches[2].target)
					assert.is_nil(now.noWatches)
					assert.are.same({}, now.pending)
				end
			)

			it(
				"reads a watch on the reading side of the moment: below the line, the lo scope (STA-R41, STA-R64)",
				function()
					local state = watchedState()
					state.scopes["148:lo"] = 12

					local now = rightNow(
						state,
						conditions(DARKSHORE, 0, DAY, 100, 0),
						nil,
						{ { item = MACKEREL, area = DARKSHORE } }
					)

					assert.are.same({ "Raw Mackerel, Darkshore: 12 Casts, none yet." }, pluck(now.watches, "text"))
				end
			)

			it("names an item not loaded yet by its ID, and lists it to ask the client for", function()
				local now = rightNow(watchedState(), conditions(DARKSHORE, 0, DAY, 150, 25), nil, {
					{ item = SMALLFISH, area = DARKSHORE },
				})

				assert.are.same({ "Item 6291, Darkshore: caught on my last Cast." }, pluck(now.watches, "text"))
				assert.are.same({ SMALLFISH }, now.pending)
			end)

			it("reads very unlucky in its words, and a watch from a subzone across its zone (STA-R42)", function()
				local state = watchedState()
				state.hits["148:hi#6358"] = { n = 200, at = 380, last = NOW - 600 } -- 0.5^20 ≈ 9.5e-7

				local now = rightNow(state, conditions(DARKSHORE, 0, DAY, 150, 25), nil, {
					{ item = BLACKMOUTH, area = AUBERDINE },
				})

				assert.are.same(
					{ "Oily Blackmouth, Auberdine: 20 since the last, very unlucky." },
					pluck(now.watches, "text")
				)
				assert.are.same({ ", very unlucky" }, pluck(now.watches, "red"))
			end)

			it("reads the empty line with no watches", function()
				local now = rightNow(watchedState(), conditions(DARKSHORE, 0, DAY, 150, 25))

				assert.are.same({}, now.watches)
				assert.are.equal("Nothing yet. Watch a Dry spell from any fish's page.", now.noWatches)
			end)
		end)

		describe("In this book (STA-R74)", function()
			it("lists Where I am, the Session page, Lifetime with my Casts and Every Session with the count", function()
				local state = stateWith({
					totals = { casts = 1840, catches = 0, gotAway = 0 },
					sessions = { session("S1", NOW - 9000, NOW - 8000, 1840, 0, 0) },
				})

				local now = rightNow(state, conditions(DARKSHORE, AUBERDINE, DAY, 150, 25))

				assert.are.same({
					{ label = "Where I am: Auberdine", target = { page = "place", area = AUBERDINE } },
					{ label = "My last Session", target = { page = "session" } },
					{ label = "Lifetime", value = "1,840", target = { page = "lifetime" } },
					{ label = "Every Session", value = "1", target = { page = "sessions" } },
				}, now.contents)
			end)

			it("reads This Session during one, and Where I am at the zone with subzone 0", function()
				local state = stateWith({ sessions = { session("S1", NOW - 60, NOW - 60, 1, 0, 1) } })
				local live =
					{ id = "S1", startTime = NOW - 60, endTime = NOW - 60, casts = 1, catches = 0, gotAway = 1 }

				local now = rightNow(state, conditions(DARKSHORE, 0, DAY, 150, 25), live)

				assert.are.same(
					{ "Where I am: Darkshore", "This Session" },
					{ now.contents[1].label, now.contents[2].label }
				)
				assert.are.same({ page = "place", area = DARKSHORE }, now.contents[1].target)
			end)

			it("opens the current place with no Casts at all, every count 0 (STA-R97)", function()
				local now = rightNow(stateWith({}), conditions(DARKSHORE, AUBERDINE, DAY, 150, 25))

				assert.are.same({
					{ label = "Where I am: Auberdine", target = { page = "place", area = AUBERDINE } },
					{ label = "This Session", target = { page = "session" } },
					{ label = "Lifetime", value = "0", target = { page = "lifetime" } },
					{ label = "Every Session", value = "0", target = { page = "sessions" } },
				}, now.contents)
			end)
		end)
	end)
end)
