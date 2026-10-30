-- Stats' projection (STA-R20–R27, STA-R30, STA-R31, STA-R90–R95; LOG-R70–R77) on FakePagle over the fixture
-- catalogue (spec/Pagle_Stats/fixtures/Catalogue.lua): a history appended with fake.catchLog:Append, then login and
-- the first PLAYER_ENTERING_WORLD, then live Casts and Skill Readings. Every expected value is worked out by hand
-- from the rules, Cast by Cast, in the comments beside the history.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local I = stats.IDS
local DARKSHORE, AUBERDINE, ELWYNN = I.DARKSHORE, I.AUBERDINE, I.ELWYNN
local MACKEREL, BLACKMOUTH, FIREFIN, NIGHTFIN, SMALLFISH = I.MACKEREL, I.BLACKMOUTH, I.FIREFIN, I.NIGHTFIN, I.SMALLFISH
local T0, NIGHT = stats.T0, stats.NIGHT
-- Cast and Skill Reading records (stats.cast: by day in Darkshore, no subzone, no modifier; `rank` nil is an unknown
-- skill).
local cast, skill = stats.cast, stats.skill

-- A new FakePagle whose log has the player's character (1) and another (2), then `records`, appended in order.
-- Returns the fake and each record as the log returned it.
---@param records table[]
---@return FakePagle fake
---@return table[] appended records: PagleCast and PagleSkillReading
local function withHistory(records)
	local fake = newFakePagle()
	fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
	fake.catchLog.data.characters[2] = { guid = stats.OTHER_GUID }
	local appended = {}
	for i, record in ipairs(records) do
		appended[i] = fake.catchLog:Append(record)
	end
	return fake, appended
end

-- Stats loaded on `fake`, then login and its first PLAYER_ENTERING_WORLD: the projection's first build.
---@param fake FakePagle
---@param options { catalogue: table?, prepare: fun(loaded: LoadedAddon)? }? stats.load's options
---@return PagleStatsNS ns
---@return LoadedAddon loaded
local function built(fake, options)
	options = options or {}
	local loaded = stats.start({ fake = fake, catalogue = options.catalogue, prepare = options.prepare })
	return loaded.ns, loaded
end

-- The ten Casts of the main worked example. Darkshore's line is 75 + 95 = 170 (STA-R12); Auberdine uses it too.
-- Darkshore's windows are just `night` (STA-R16; Auberdine's entries are in its zone's catches); there, Nightfin's
-- window is `night`, while Mackerel, Blackmouth and Smallfish have none (STA-R14). Elwynn has no line (side `na`)
-- and the windows `day` and `summer`; Nightfin is ungated there.
local MAIN = {
	-- 1: Auberdine by day, 175 (hi, +5: hi0), two slots of Mackerel: one hit per place (STA-R24)
	cast({ time = T0, subzone = AUBERDINE, rank = 150, mod = 25, items = { MACKEREL, MACKEREL } }),
	-- 2: Auberdine by night, hi0, Nightfin in its window: night scope counts and hits in both places
	cast({ time = T0 + 60, minute = NIGHT, subzone = AUBERDINE, rank = 150, mod = 25, items = { NIGHTFIN } }),
	-- 3: Darkshore by day, hi0, Nightfin out of its window: no hit (STA-R24)
	cast({ time = T0 + 120, rank = 150, mod = 25, items = { NIGHTFIN } }),
	-- 4: Darkshore by day, 100 (lo, -70: lo50), got away
	cast({ time = T0 + 180, rank = 100 }),
	-- 5: Darkshore by night, 160 (lo, -10: lo1), Mackerel and a secret item 0
	cast({ time = T0 + 240, minute = NIGHT, rank = 160, items = { MACKEREL, 0 } }),
	-- 6: zone 0 (secret) with a subzone: no place, no margin, but every total (STA-R10, STA-R93)
	cast({ time = T0 + 300, zone = 0, subzone = AUBERDINE, rank = 150, mod = 25, items = { SMALLFISH } }),
	-- 7: Elwynn by day, no line: side na, the `day` window matches and `summer` doesn't; Nightfin ungated
	cast({ time = T0 + 360, zone = ELWYNN, rank = 150, mod = 25, items = { NIGHTFIN } }),
	-- 8: the other character in Auberdine by day, 200 (hi, +30: hi25), Mackerel
	cast({ time = T0 + 420, char = 2, subzone = AUBERDINE, rank = 200, items = { MACKEREL } }),
	-- 9: Darkshore by day, hi0, Blackmouth: Darkshore's hi scope moves on past Mackerel's `at`
	cast({ time = T0 + 480, rank = 150, mod = 25, items = { BLACKMOUTH } }),
	-- 10: Darkshore by day with an unknown skill: side na although the zone has a line, no margin (STA-R13, STA-R26)
	cast({ time = T0 + 540, items = { MACKEREL } }),
}

describe("Stats' projection", function()
	describe("the fold (STA-R21–R26)", function()
		it(
			"counts a history in a zone and its subzone, by day and night, on both sides, to the hand-worked state",
			function()
				local ns = built(withHistory(MAIN))
				local state = ns.State()

				-- STA-R22: ten Casts, 2+1+1+0+2+1+1+1+1+1 entries (item 0 included), one got away
				assert.are.same({ casts = 10, catches = 11, gotAway = 1 }, state.totals)
				assert.are.same({
					[1] = { casts = 9, catches = 10, gotAway = 1 },
					[2] = { casts = 1, catches = 1, gotAway = 0 },
				}, state.chars)
				-- STA-R22: Casts 1–5 and 8–10 in Darkshore, 1, 2 and 8 in Auberdine, 7 in Elwynn; none for Cast 6
				assert.are.same({
					[DARKSHORE] = {
						zone = DARKSHORE,
						casts = 8,
						catches = 9,
						gotAway = 1,
						items = { [MACKEREL] = 5, [NIGHTFIN] = 2, [BLACKMOUTH] = 1 },
					},
					[AUBERDINE] = {
						zone = DARKSHORE,
						casts = 3,
						catches = 4,
						gotAway = 0,
						items = { [MACKEREL] = 3, [NIGHTFIN] = 1 },
					},
					[ELWYNN] = { zone = ELWYNN, casts = 1, catches = 1, gotAway = 0, items = { [NIGHTFIN] = 1 } },
				}, state.places)
				-- STA-R23
				assert.are.same({
					["148:hi"] = 5, -- Casts 1, 2, 3, 8, 9
					["148:hi:night"] = 1, -- Cast 2
					["442:hi"] = 3, -- Casts 1, 2, 8
					["442:hi:night"] = 1, -- Cast 2
					["148:lo"] = 2, -- Casts 4, 5
					["148:lo:night"] = 1, -- Cast 5
					["148:na"] = 1, -- Cast 10
					["12:na"] = 1, -- Cast 7
					["12:na:day"] = 1, -- Cast 7
				}, state.scopes)
				-- STA-R24: `at` is the scope's count after the Cast that hit
				assert.are.same({
					["148:hi#6303"] = { n = 2, at = 4, last = T0 + 420 }, -- Casts 1 and 8
					["442:hi#6303"] = { n = 2, at = 3, last = T0 + 420 }, -- Casts 1 and 8
					["148:hi:night#13759"] = { n = 1, at = 1, last = T0 + 60 }, -- Cast 2
					["442:hi:night#13759"] = { n = 1, at = 1, last = T0 + 60 }, -- Cast 2
					["148:lo#6303"] = { n = 1, at = 2, last = T0 + 240 }, -- Cast 5
					["12:na#13759"] = { n = 1, at = 1, last = T0 + 360 }, -- Cast 7
					["148:hi#6358"] = { n = 1, at = 5, last = T0 + 480 }, -- Cast 9
					["148:na#6303"] = { n = 1, at = 1, last = T0 + 540 }, -- Cast 10
				}, state.hits)
				-- STA-R25: per entry, item 0 left out
				assert.are.same({
					[MACKEREL] = { n = 5, first = T0, last = T0 + 540 },
					[NIGHTFIN] = { n = 3, first = T0 + 60, last = T0 + 360 },
					[SMALLFISH] = { n = 1, first = T0 + 300, last = T0 + 300 },
					[BLACKMOUTH] = { n = 1, first = T0 + 480, last = T0 + 480 },
				}, state.items)
				-- STA-R26: Casts 1, 2, 3, 9 hi0; 4 lo50 (got away); 5 lo1; 8 hi25; 6, 7, 10 none
				assert.are.same({
					lo50 = { casts = 1, gotAway = 1 },
					lo1 = { casts = 1, gotAway = 0 },
					hi0 = { casts = 4, gotAway = 0 },
					hi25 = { casts = 1, gotAway = 0 },
				}, state.margins)
			end
		)

		it("records no hit for a night-gated item caught by day, in its zone or subzone (STA-R24)", function()
			local ns = built(withHistory({
				cast({ time = T0, subzone = AUBERDINE, rank = 150, mod = 25, items = { NIGHTFIN } }),
			}))
			local state = ns.State()

			assert.are.same({}, state.hits)
			assert.are.same({ ["148:hi"] = 1, ["442:hi"] = 1 }, state.scopes)
			-- the Catch still counts everywhere else (STA-R22, STA-R25)
			assert.are.same({ [NIGHTFIN] = 1 }, state.places[DARKSHORE].items)
			assert.are.same({ n = 1, first = T0, last = T0 }, state.items[NIGHTFIN])
		end)

		it(
			"puts an ungated item's hit in the side scope, even when one of the zone's windows matched (STA-R24)",
			function()
				local ns = built(withHistory({
					cast({ time = T0, minute = NIGHT, rank = 150, mod = 25, items = { MACKEREL } }),
					-- Firefin's Darkshore entries differ (night, and ungated in Auberdine's list): no window (STA-R14)
					cast({ time = T0 + 60, rank = 150, mod = 25, items = { FIREFIN } }),
				}))

				assert.are.same({ ["148:hi"] = 2, ["148:hi:night"] = 1 }, ns.State().scopes)
				assert.are.same({
					["148:hi#6303"] = { n = 1, at = 1, last = T0 },
					["148:hi#6359"] = { n = 1, at = 2, last = T0 + 60 },
				}, ns.State().hits)
			end
		)

		it("sets `at` to the scope's count after the Cast that hit, not after later ones (STA-R24)", function()
			local ns = built(withHistory({
				cast({ time = T0, minute = NIGHT, rank = 150, mod = 25, items = { NIGHTFIN } }), -- night scope 1
				cast({ time = T0 + 60, minute = NIGHT, rank = 150, mod = 25 }), -- 2, got away
				cast({ time = T0 + 120, minute = NIGHT, rank = 150, mod = 25, items = { NIGHTFIN } }), -- 3
				cast({ time = T0 + 180, minute = NIGHT, rank = 150, mod = 25, items = { MACKEREL } }), -- 4
				cast({ time = T0 + 240, rank = 150, mod = 25, items = { MACKEREL } }), -- by day: not in the scope
			}))

			assert.are.same({ n = 2, at = 3, last = T0 + 120 }, ns.State().hits["148:hi:night#13759"])
			assert.are.equal(4, ns.State().scopes["148:hi:night"])
		end)

		it("ignores every record that isn't a Cast or a Skill Reading (STA-R21)", function()
			local fake = withHistory({ cast({ time = T0, rank = 150, mod = 25, items = { MACKEREL } }) })
			fake.catchLog:Append({ kind = "prestige", char = 1, time = T0 + 10, rank = 1 })
			fake.catchLog:Append({
				kind = "purchase",
				char = 1,
				time = T0 + 20,
				good = "core.toaststyle.ripple",
				price = 1,
			})
			fake.catchLog:Append({
				kind = "build",
				char = 1,
				time = T0 + 30,
				build = 70338,
				version = "1.60.1",
				rules = "pagle-2026a",
			})
			local reference = built(withHistory({ cast({ time = T0, rank = 150, mod = 25, items = { MACKEREL } }) }))

			assert.are.same(reference.State(), built(fake).State())
		end)
	end)

	describe("Skill Readings and Session records (STA-R27, STA-R30, STA-R31)", function()
		local B = SERVER_TIME - 90000 -- long ended before login

		-- Two Sessions, more than Core's 300 s gap apart (LOG-R60), with the readings STA-R27 and STA-R31 tell apart.
		local TWO = {
			-- Session 1
			cast({ time = B, subzone = AUBERDINE, rank = 150, mod = 25, items = { MACKEREL } }), -- 1
			skill(B + 30, 100), -- 2: character 1's first reading: nothing
			cast({ time = B + 60, char = 2, zone = ELWYNN }), -- 3: the other character, got away
			skill(B + 90, 103), -- 4: +3 to Session 1
			cast({ time = B + 120, zone = 0, items = { 0 } }), -- 5: zone 0, item 0
			-- Session 2
			skill(B + 2000, 105), -- 6: before Session 2's first Cast: no `session`, so +2 credited nowhere
			cast({ time = B + 2100, zone = ELWYNN, items = { NIGHTFIN } }), -- 7
			skill(B + 2130, 107), -- 8: +2
			skill(B + 2150, 50, 2), -- 9: character 2's first reading: nothing
			skill(B + 2160, 52, 2), -- 10: +2
		}

		it("builds one record per Session with its chars, zones, items and skill gained", function()
			local fake, appended = withHistory(TWO)
			local ns = built(fake)

			assert.are.same({
				{
					id = appended[1].id,
					startTime = B,
					endTime = B + 120,
					casts = 3,
					catches = 2, -- Mackerel and item 0
					gotAway = 1,
					chars = { [1] = 2, [2] = 1 },
					zones = { [DARKSHORE] = 1, [ELWYNN] = 1 }, -- zone 0 left out
					items = { [MACKEREL] = 1 }, -- item 0 left out
					skill = 3,
				},
				{
					id = appended[7].id,
					startTime = B + 2100,
					endTime = B + 2100,
					casts = 1,
					catches = 1,
					gotAway = 0,
					chars = { [1] = 1 },
					zones = { [ELWYNN] = 1 },
					items = { [NIGHTFIN] = 1 },
					skill = 4,
				},
			}, ns.State().sessions)
			assert.are.same({ [1] = 107, [2] = 52 }, ns.State().lastRank)
		end)

		it("credits a character's first reading to no Session, even inside one", function()
			local ns = built(withHistory({ cast({ time = B, items = { MACKEREL } }), skill(B + 30, 120) }))

			assert.are.equal(0, ns.State().sessions[1].skill)
			assert.are.same({ [1] = 120 }, ns.State().lastRank)
		end)

		it("credits a reading with no `session` to no record (STA-R31; STA-R27's first accepted inaccuracy)", function()
			local fake, appended = withHistory(TWO)
			local ns = built(fake)

			assert.is_nil(appended[6].session) -- appended 1880 s after Session 1's last Cast: no Session open
			-- Character 1 went 100 → 107, yet only 3 + 2 is credited: the 103 → 105 step, read before Session 2's
			-- first Cast, counts toward no Session.
			assert.are.same({ 3, 4 }, { ns.State().sessions[1].skill, ns.State().sessions[2].skill })
		end)

		it(
			"credits an open Session with skill gained elsewhere when login reads it (STA-R27's second accepted inaccuracy)",
			function()
				-- A Session open at login (its last Cast 100 s ago, inside Core's 300 s gap) whose character read 100;
				-- skill rose to 130 away from the log (another computer, say), and login reads 130 inside the Session.
				local fake = withHistory({
					cast({ time = SERVER_TIME - 200, items = { MACKEREL } }),
					skill(SERVER_TIME - 190, 100),
					cast({ time = SERVER_TIME - 100, items = { MACKEREL } }),
				})
				local ns = built(fake)

				fake.readSkill(130, 300, 0)

				assert.are.equal(1, #ns.State().sessions)
				assert.are.equal(30, ns.State().sessions[1].skill)
			end
		)

		it("keeps a Session that crosses midnight as one record, dated by its start (STA-R95)", function()
			local ns = built(withHistory({
				cast({ time = B, minute = 23 * 60 + 58, items = { MACKEREL } }), -- realm 23:58
				cast({ time = B + 240, minute = 2, items = { MACKEREL } }), -- realm 00:02 the next day, inside the gap
			}))

			local sessions = ns.State().sessions
			assert.are.equal(1, #sessions)
			assert.are.same({ B, B + 240, 2 }, { sessions[1].startTime, sessions[1].endTime, sessions[1].casts })
		end)
	end)

	describe("live (LOG-R73)", function()
		it("folds a live Cast and Skill Reading into the open Session's record and redraws for each", function()
			-- Its last Cast 100 s before login, inside Core's 300 s gap: the Session is still open.
			local fake = withHistory({ cast({ time = SERVER_TIME - 100, rank = 86, mod = 25, items = { MACKEREL } }) })
			local ns = stats.load(fake).ns
			local redraws = {}
			ns.OnRedraw(function(reason)
				redraws[#redraws + 1] = reason
			end)
			fake.login()
			fake.enterWorld()
			assert.are.same({ "projection" }, redraws) -- the first build's done

			fake.readSkill(86, 150, 25) -- the first reading: nothing gained
			fake.playCast("caught", { { itemID = BLACKMOUTH, quantity = 1 } }) -- The Long Wash (148/453), 86+25
			fake.readSkill(88, 150, 25)

			assert.are.same({ "projection", "projection", "projection", "projection" }, redraws)
			local sessions = ns.State().sessions
			assert.are.same(
				{ 1, 2, { [DARKSHORE] = 2 }, { [MACKEREL] = 1, [BLACKMOUTH] = 1 }, 2 },
				{ #sessions, sessions[1].casts, sessions[1].zones, sessions[1].items, sessions[1].skill }
			)
			-- 86+25 = 111 is 59 below Darkshore's line (170): lo, lo50 (STA-R13, STA-R26)
			assert.are.same({ n = 1, at = 2, last = SERVER_TIME }, ns.State().hits["148:lo#6358"])
			assert.are.same({ n = 1, at = 1, last = SERVER_TIME }, ns.State().hits["453:lo#6358"])
			assert.are.same({ casts = 2, gotAway = 0 }, ns.State().margins.lo50)
		end)

		it("keeps folding while restricted, as in combat (STA-R93, LOG-R93)", function()
			local fake = newFakePagle()
			local ns = built(fake)

			fake.setRestricted(true)
			fake.playCast("caught", { { itemID = MACKEREL, quantity = 1 } })
			fake.playCast("gotAway")

			assert.are.same({ casts = 2, catches = 1, gotAway = 1 }, ns.State().totals)
		end)

		it("folds a Cast 10 s after /pagle dev endsession into a second Session (#258, LOG-R99)", function()
			local fake = newFakePagle()
			local ns = built(fake)
			fake.playCast("caught", { { itemID = MACKEREL, quantity = 1 } })
			fake.slash("dev on")
			fake.slash("dev endsession")

			fake.wait(10)
			fake.playCast("caught", { { itemID = MACKEREL, quantity = 1 } })

			local sessions = ns.State().sessions
			assert.are.same({ 2, 1, 1 }, { #sessions, sessions[1].casts, sessions[2].casts })
		end)
	end)

	describe("rebuilds and catch-ups (STA-R20, STA-R90–R92, STA-R94, LOG-R71, LOG-R72)", function()
		-- A deep copy, to compare against after the saved state changes.
		local function copy(value)
			if type(value) ~= "table" then
				return value
			end
			local out = {}
			for key, inner in pairs(value) do
				out[key] = copy(inner)
			end
			return out
		end

		-- A first login over MAIN, then the saved projection marked (its casts total raised by 1000), so the next
		-- login shows whether it caught up on the saved state (the mark stays) or rebuilt from seq 0 (it's gone).
		-- Returns the PagleLog data, the PagleStatsDB global the next login loads, and the state the first built.
		local function savedMarked()
			local fake = withHistory(MAIN)
			local ns, loaded = built(fake)
			local first = copy(ns.State())
			local global = loaded.env.PagleStatsDB.global
			global.projection.projection.totals.casts = global.projection.projection.totals.casts + 1000
			return fake.catchLog.data, global, first
		end

		-- The next login on the same machine: a new FakePagle over the same log, with `between` Casts recorded
		-- meanwhile (while Stats was off), PagleStatsDB's global as saved (nil: lost) and Core's Session rules
		-- version `sessionRules` (default Core's own).
		---@return PagleStatsNS ns
		---@return FakePagle fake
		local function nextLogin(log, global, options)
			options = options or {}
			local fake = newFakePagle()
			fake.catchLog.data = log
			for _, record in ipairs(options.between or {}) do
				fake.catchLog:Append(record)
			end
			if options.sessionRules then
				fake.Pagle.SESSION_RULES_VERSION = options.sessionRules
			end
			fake.globals.PagleStatsDB = global and { global = global } or nil
			local ns = built(fake, options)
			return ns, fake
		end

		it(
			"catches up from lastSeq with nothing changed, counting Casts made while Stats was off (STA-R90, LOG-R71)",
			function()
				local log, global, first = savedMarked()

				local ns, fake = nextLogin(log, global, {
					between = { cast({ time = T0 + 600, rank = 150, mod = 25, items = { MACKEREL } }) },
				})

				assert.are.equal(first.totals.casts + 1000 + 1, ns.State().totals.casts) -- the mark stays
				assert.are.same({ n = 3, at = 6, last = T0 + 600 }, ns.State().hits["148:hi#6303"])
				assert.are.equal(11, ns.State().sessions[1].casts) -- still Session 1: 60 s after Cast 10
				assert.are.same({}, fake.writeUps) -- nothing earned, so no Write-up
				assert.are.equal(log.count, global.projection.lastSeq)
			end
		)

		it("rebuilds to the same state when STATS_RULES_VERSION changes (STA-R20)", function()
			local log, global, first = savedMarked()

			local ns = nextLogin(log, global, {
				prepare = function(loaded)
					loaded.ns.STATS_RULES_VERSION = 2
				end,
			})

			assert.are.same(first, ns.State())
			assert.are.equal(202, global.projection.rulesVersion) -- 100 × 2 + Core's SESSION_RULES_VERSION, 2
		end)

		it("rebuilds to the same state when Pagle.SESSION_RULES_VERSION changes (STA-R20, STA-R91)", function()
			local log, global, first = savedMarked()

			local ns = nextLogin(log, global, { sessionRules = 3 }) -- one past Core's 2

			assert.are.same(first, ns.State())
			assert.are.equal(103, global.projection.rulesVersion)
		end)

		it("rebuilds to the same state when the content fingerprint changes (STA-R91)", function()
			local log, global, first = savedMarked()
			local catalogue = stats.catalogue()
			catalogue.fingerprint = "0123456789abcdef"

			local ns = nextLogin(log, global, { catalogue = catalogue })

			assert.are.same(first, ns.State())
			assert.are.equal("0123456789abcdef", global.projection.fingerprint)
		end)

		it("rebuilds when lastSeq is beyond the log, as after a crash (STA-R94)", function()
			local log, global, first = savedMarked()
			global.projection.lastSeq = log.count + 5

			local ns = nextLogin(log, global)

			assert.are.same(first, ns.State())
			assert.are.equal(log.count, global.projection.lastSeq)
		end)

		it("builds a lost PagleStatsDB from the whole log, as a first build (STA-R92)", function()
			local log, _, first = savedMarked()

			local ns = nextLogin(log, nil)

			assert.are.same(first, ns.State())
		end)
	end)

	describe("raising nothing (STA-R2, STA-R91, STA-R92)", function()
		it("raises no moment, summary line, Write-up or Coins report in a first build, live or a rebuild", function()
			local fake = withHistory(MAIN)
			local loaded = stats.load(fake)
			fake.login()
			fake.enterWorld() -- the first build over history
			fake.readSkill(86, 150, 25)
			fake.playCast("caught", { { itemID = NIGHTFIN, quantity = 1 } })
			fake.playCast("gotAway")
			fake.readSkill(90, 150, 25)
			loaded.ns.projection:Rebuild()
			fake.nextFrame()
			fake.wait(fake.Pagle.SESSION_GAP) -- the Session ends: its card would carry anything Stats had raised
			fake.nextFrame()

			assert.are.same({}, fake.announcements)
			assert.are.same({}, fake.summarized)
			assert.are.same({}, fake.writeUps)
			assert.is_nil(fake.global.summary.lines.Stats)
			for _, report in ipairs(fake.coinReports) do
				assert.are_not.equal("Stats", report.module)
			end
		end)
	end)

	describe("the seams (STA-R20, LOG-R74)", function()
		it("hand out the projection's state and updating flag once it is built", function()
			local fake = withHistory(MAIN)
			local ns = stats.load(fake).ns
			fake.login()
			assert.is_true(ns.IsUpdating()) -- logged in, not yet at PLAYER_ENTERING_WORLD

			fake.enterWorld()

			assert.is_false(ns.IsUpdating())
			assert.are.equal(ns.projection:GetState(), ns.State())
			assert.are.equal(10, ns.State().totals.casts)
		end)
	end)
end)
