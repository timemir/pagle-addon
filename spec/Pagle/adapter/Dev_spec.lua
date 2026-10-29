-- /pagle dev (#247): Core's hidden dev commands for fast exit checks, through the real TOC and the fake client. The
-- switch is PagleDB.global.dev; `endsession` ends the open Session as if its gap had passed (LOG-R62); `catch`
-- records a synthetic caught Cast through Core's real append path, on a test log only (PagleLog.test); `glyphs`
-- shows a probe line in each font Pagle uses (#248, CORE-R9).

-- Types `/pagle <msg>` in chat.
local function pagle(loaded, msg)
	loaded.env.SlashCmdList.PAGLE(msg)
end

-- A test log (PagleLog.test, as the test-log tooling writes it) holding `entries`.
local function testLog(entries)
	local log = savedLog(entries)
	log.test = true
	return log
end

-- Registers a Module whose projection raises a toast for each live caught Cast, noting each Catch event it gets.
local function moduleRaising(loaded)
	local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
	local seen = { catches = {}, applied = {} }
	M:NewProjection({
		db = {},
		rulesVersion = 1,
		reset = function()
			return {}
		end,
		apply = function(_, record, mode)
			if record.kind == "cast" and mode == "live" then
				seen.applied[#seen.applied + 1] = record.seq
				M:RaiseMoment({ rung = "toast", kind = "newSpecies", title = "New Species", cast = record.id })
			end
		end,
	})
	loaded.env.Pagle.RegisterCallback(seen, "Catch", function(_, catch)
		seen.catches[#seen.catches + 1] = catch.itemID
	end)
	return seen
end

-- The last record in the Catch log, as Core reads it back.
local function lastRecord(loaded)
	local last
	for record in loaded.env.Pagle.IterateCatches() do
		last = record
	end
	return last
end

describe("/pagle dev", function()
	it("isn't in the help list (#247, CORE-R60)", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }))

		pagle(loaded, "help")

		for _, line in ipairs(loaded.printed) do
			assert.is_nil(line:find("dev", 1, true))
		end
	end)

	it("is reserved: a Module's dev subcommand is skipped and reported (#247, CORE-R61, CORE-R62)", function()
		local loaded = loadCore({ BUILD_ENTRY })
		loaded.env.Pagle.RegisterModule({
			name = "Ledger",
			title = "Ledger",
			order = 10,
			slash = { { name = "Dev", fn = print } },
		})

		local errors = loaded.client.errors
		enterWorld(loaded)

		assert.are.same({ "Pagle: Ledger's /pagle Dev is skipped: Pagle reserves dev" }, errors)
	end)

	it("turns on and off in PagleDB.global.dev (#247)", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }))

		pagle(loaded, "dev on")
		assert.is_true(loaded.env.PagleDB.global.dev)
		pagle(loaded, "DEV OFF")

		assert.is_false(loaded.env.PagleDB.global.dev)
		assert.are.same({ "Pagle dev: dev commands are on.", "Pagle dev: dev commands are off." }, loaded.printed)
	end)

	it("refuses every other subcommand with one line while off, doing nothing (#247)", function()
		local loaded = loadCore(testLog({ BUILD_ENTRY }))
		enterWorld(loaded, 1)
		catchOne(loaded)
		local entries = #loaded.env.PagleLog.entries

		for _, line in ipairs({ "dev", "dev endsession", "dev catch 6358", "dev preview banner", "dev glyphs" }) do
			pagle(loaded, line)
		end

		local off = "Pagle dev: dev commands are off; /pagle dev on turns them on."
		assert.are.same({ off, off, off, off, off }, loaded.printed)
		assert.is_nil(loaded.ns.glyphProbeFrame)
		assert.is_not_nil(loaded.env.Pagle.GetSession())
		assert.are.equal(entries, #loaded.env.PagleLog.entries)
	end)
end)

describe("/pagle dev endsession", function()
	it(
		"ends the open Session now: SessionEnded fires, the summary card shows, and the log is unchanged"
			.. " (#247, LOG-R62, ANN-R53)",
		function()
			local loaded = loadCore({ BUILD_ENTRY })
			moduleRaising(loaded)
			enterWorld(loaded, 2)
			catchAndFlush(loaded)
			-- The toast settles, stays its hold and leaves the column: the card may show.
			loaded.client.advance(loaded.ns.SETTLE_SECONDS.toast + loaded.ns.HOLD_SECONDS.toast)
			local ended = {}
			loaded.env.Pagle.RegisterCallback(ended, "SessionEnded", function(_, session)
				ended[#ended + 1] = session.id
			end)
			local entries = { unpack(loaded.env.PagleLog.entries) }
			pagle(loaded, "dev on")

			pagle(loaded, "dev endsession")

			assert.are.equal(1, #ended)
			assert.is_nil(loaded.env.Pagle.GetSession())
			assert.are.equal(1, #loaded.env.PagleDB.global.cards)
			local frame = loaded.ns.cardFrame
			assert.is_true(frame:IsShown())
			assert.are.equal("Fishing session", frame.title:GetText())
			assert.are.same(entries, loaded.env.PagleLog.entries)
			assert.are.equal("Pagle dev: the Session ended, as if its gap had passed.", loaded.printed[2])
		end
	)

	it(
		"has the next Cast, 10 s later, start a new Session that the projections and every later read see"
			.. " (#258, LOG-R99)",
		function()
			local loaded = loadCore({ BUILD_ENTRY })
			local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			local applied = {}
			M:NewProjection({
				db = {},
				rulesVersion = 1,
				reset = function()
					return {}
				end,
				apply = function(_, record)
					if record.kind == "cast" then
						applied[#applied + 1] = record.session
					end
				end,
			})
			local started = {}
			loaded.env.Pagle.RegisterCallback(started, "SessionStarted", function(_, session)
				started[#started + 1] = session.id
			end)
			enterWorld(loaded, 2)
			catchOne(loaded)
			pagle(loaded, "dev on")
			pagle(loaded, "dev endsession")

			loaded.client.advance(10)
			catchOne(loaded)

			assert.are.equal(2, #started)
			assert.are_not.equal(started[1], started[2])
			assert.are.same(started, applied)
			assert.are.equal(started[2], loaded.env.Pagle.GetSession().id)
			-- After a /reload, Core cuts the same two Sessions from the saved log.
			local reloaded = enterWorld(loadCore(loaded.env.PagleLog, loaded.env.PagleDB))
			local tags = {}
			for record in reloaded.env.Pagle.IterateCatches() do
				if record.kind == "cast" then
					tags[#tags + 1] = record.session
				end
			end
			assert.are.same(started, tags)
		end
	)

	it("says so, and fires nothing, with no Session open (#247, LOG-R64)", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }), 2)
		local ended = {}
		loaded.env.Pagle.RegisterCallback(ended, "SessionEnded", function()
			ended[#ended + 1] = true
		end)
		pagle(loaded, "dev on")

		pagle(loaded, "dev endsession")

		assert.are.same({}, ended)
		assert.are.equal("Pagle dev: no Session is open.", loaded.printed[2])
	end)

	it("doesn't end the Session again when its gap passes later (#247, LOG-R62)", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }), 2)
		catchOne(loaded)
		local ended = {}
		loaded.env.Pagle.RegisterCallback(ended, "SessionEnded", function()
			ended[#ended + 1] = true
		end)
		pagle(loaded, "dev on")
		pagle(loaded, "dev endsession")

		loaded.client.advance(2 * loaded.ns.SESSION_GAP)

		assert.are.equal(1, #ended)
	end)
end)

describe("/pagle dev catch", function()
	it(
		"on a test log appends one caught Cast for the character now, in the current zone, which Modules get"
			.. " live as a real Catch (#247, LOG-R9)",
		function()
			local loaded = loadCore(testLog({ BUILD_ENTRY }))
			local seen = moduleRaising(loaded)
			enterWorld(loaded, 2)
			local entries = #loaded.env.PagleLog.entries
			pagle(loaded, "dev on")

			pagle(loaded, "dev catch 6358")
			loaded.client.advance(0)

			local cast = lastRecord(loaded)
			assert.are.equal(entries + 1, #loaded.env.PagleLog.entries)
			assert.are.same(
				{ "cast", "caught", loaded.env.Pagle.GetAngler().current, 6358, 1 },
				{ cast.kind, cast.outcome, cast.char, cast.items[1].itemID, cast.items[1].quantity }
			)
			assert.are.equal(loaded.env.Pagle.GetConditions().zone, cast.conditions.zone)
			assert.are.equal(SERVER_TIME, cast.time)
			assert.are.same({ 6358 }, seen.catches)
			assert.are.same({ cast.seq }, seen.applied)
			assert.are.equal("New Species", loaded.ns.announcementFrames.toast.title:GetText())
			assert.are.equal(cast.session, loaded.env.Pagle.GetSession().id)
			assert.are.equal(
				("Pagle dev: caught item 6358 in zone %d (entry %d)."):format(cast.conditions.zone, cast.seq),
				loaded.printed[2]
			)
			assert.are.equal("idle", loaded.env.Pagle.GetFishingState())
		end
	)

	it("records it in the zone or subzone given by areaID (#247, LOG-R55)", function()
		local loaded = enterWorld(loadCore(testLog({ BUILD_ENTRY })), 2)
		pagle(loaded, "dev on")

		pagle(loaded, "dev catch 6358 453")
		local subzone = lastRecord(loaded)
		pagle(loaded, "dev catch 6303 148")
		local zone = lastRecord(loaded)

		assert.are.same({ 148, 453 }, { subzone.conditions.zone, subzone.conditions.subzone })
		assert.are.same({ 148, 0, 6303 }, { zone.conditions.zone, zone.conditions.subzone, zone.items[1].itemID })
	end)

	it("on a real log refuses with one line and appends nothing (#247)", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }), 2)
		local entries = { unpack(loaded.env.PagleLog.entries) }
		pagle(loaded, "dev on")

		pagle(loaded, "dev catch 6358")

		assert.are.same(entries, loaded.env.PagleLog.entries)
		assert.are.equal(
			"Pagle dev: catch writes to the Catch log, so it runs on a test log only (PagleLog.test); "
				.. "this log is real, and nothing was added.",
			loaded.printed[2]
		)
	end)

	for _, args in ipairs({ "", "fish", "0", "6358 here", "-5" }) do
		it(("prints its usage for /pagle dev catch %s, appending nothing (#247)"):format(args), function()
			local loaded = enterWorld(loadCore(testLog({ BUILD_ENTRY })), 2)
			local entries = #loaded.env.PagleLog.entries
			pagle(loaded, "dev on")

			pagle(loaded, "dev catch " .. args)

			assert.are.equal(entries, #loaded.env.PagleLog.entries)
			assert.are.equal("Pagle dev: /pagle dev catch <itemID> [areaID]", loaded.printed[2])
		end)
	end

	it("refuses an areaID outside the catalogue, appending nothing (#247, LOG-R55)", function()
		local loaded = enterWorld(loadCore(testLog({ BUILD_ENTRY })), 2)
		local entries = #loaded.env.PagleLog.entries
		pagle(loaded, "dev on")

		pagle(loaded, "dev catch 6358 999999")

		assert.are.equal(entries, #loaded.env.PagleLog.entries)
		assert.are.equal("Pagle dev: 999999 isn't an area in Pagle's catalogue.", loaded.printed[2])
	end)
end)

-- A plain copy of a table, nested tables too, to compare saved state before and after.
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in pairs(value) do
		result[key] = copy(item)
	end
	return result
end

describe("/pagle dev stage", function()
	it("sets and clears the count the Folio's chart is drawn at, saving nothing (ANN-R85)", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }), 2)
		pagle(loaded, "dev on")
		local saved = copy(loaded.env.PagleDB.global)

		pagle(loaded, "dev stage 30")
		assert.are.equal(30, loaded.ns.devStageCount)
		pagle(loaded, "dev stage")
		pagle(loaded, "dev stage off")

		assert.is_nil(loaded.ns.devStageCount)
		assert.are.same(saved, copy(loaded.env.PagleDB.global))
		assert.are.same({
			"Pagle dev: the Cartographer's Folio is drawn as if 30 zones were at Master, until /pagle dev stage off.",
			"Pagle dev: the Cartographer's Folio is drawn as if 30 zones were at Master.",
			"Pagle dev: the Cartographer's Folio is drawn at its real stage.",
		}, { loaded.printed[2], loaded.printed[3], loaded.printed[4] })
	end)

	it("takes a whole number from 0 and says its usage for anything else", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }), 2)
		pagle(loaded, "dev on")

		pagle(loaded, "dev stage -3")
		pagle(loaded, "dev stage many")

		assert.is_nil(loaded.ns.devStageCount)
		assert.are.equal("Pagle dev: /pagle dev stage <count of zones at Master> | off", loaded.printed[2])
	end)
end)

describe("/pagle dev preview", function()
	for _, kind in ipairs({ "toast", "nod", "banner", "splash" }) do
		it(
			("draws a sample %s through the lanes, with its sound, changing no saved state (#247, ANN-R20)"):format(
				kind
			),
			function()
				local loaded = enterWorld(loadCore({ BUILD_ENTRY }), 2)
				pagle(loaded, "dev on")
				local saved, log = copy(loaded.env.PagleDB.global), copy(loaded.env.PagleLog)

				pagle(loaded, "dev preview " .. kind:upper())

				local frame = loaded.ns.announcementFrames[kind]
				assert.is_true(frame:IsShown())
				assert.is_truthy(frame.title:GetText())
				assert.are.same(saved, copy(loaded.env.PagleDB.global))
				assert.are.same(log, copy(loaded.env.PagleLog))
				assert.are.equal(("Pagle dev: previewing a %s."):format(kind), loaded.printed[2])
				if kind ~= "nod" then
					assert.are.equal(1, #loaded.client.sounds)
				end
			end
		)
	end

	it(
		"draws a toast.high on its own page, with a variety of a rarity after it, for judging its gleam (ANN-R85)",
		function()
			local loaded = enterWorld(loadCore({ BUILD_ENTRY }), 2)
			pagle(loaded, "dev on")
			local saved = copy(loaded.env.PagleDB.global)

			pagle(loaded, "dev preview high")
			local plain = loaded.ns.announcementFrames.toast
			assert.is_true(plain.shown)
			assert.is_true(loaded.ns.ToastPage(plain.display.announcement).high)
			assert.is_nil(loaded.ns.ToastVarietyLook(plain.display.announcement))
			loaded.client.advance(12)

			pagle(loaded, "dev preview high EPIC")
			local frame = loaded.ns.announcementFrames.toast
			local look = loaded.ns.ToastVarietyLook(frame.display.announcement) --[[@as table]]
			assert.are.same({ "epic", true }, { look.rarity, look.gleam })
			assert.are.equal("Pagle dev: previewing a high epic.", loaded.printed[#loaded.printed])
			assert.are.same(saved, copy(loaded.env.PagleDB.global))
		end
	)

	it("shows a sample Session summary card that closing removes nothing from (#247, ANN-R53)", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }), 2)
		pagle(loaded, "dev on")
		local saved = copy(loaded.env.PagleDB.global)

		pagle(loaded, "dev preview card")
		local frame = loaded.ns.cardFrame
		assert.is_true(frame:IsShown())
		assert.are.equal("Fishing session", frame.title:GetText())
		frame.close:Click()

		assert.is_false(frame:IsShown())
		assert.are.same(saved, copy(loaded.env.PagleDB.global))
	end)

	it("lists the kinds with none or an unknown one (#247)", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }), 2)
		pagle(loaded, "dev on")

		pagle(loaded, "dev preview")
		pagle(loaded, "dev preview whale")

		local kinds =
			"Pagle dev: /pagle dev preview <kind>, where kind is one of toast, high, nod, banner, splash, card"
		assert.are.same({ kinds, kinds }, { loaded.printed[2], loaded.printed[3] })
	end)

	it(
		"holds a sample through combat as the lanes hold any Announcement, and refuses a card (#247, ANN-R35)",
		function()
			local loaded = enterWorld(loadCore({ BUILD_ENTRY }), 2)
			pagle(loaded, "dev on")
			setCombat(loaded, true)

			pagle(loaded, "dev preview banner")
			pagle(loaded, "dev preview card")

			local banner = loaded.ns.announcementFrames.banner
			assert.is_true(banner == nil or not banner:IsShown())
			assert.are.equal("Pagle dev: cards wait until combat ends; try again then.", loaded.printed[3])
		end
	)
end)

describe("/pagle dev glyphs", function()
	-- The probe line (#248, CORE-R9): each candidate character after its code point, so a box can be told apart.
	local PROBE = "2013 –  2014 —  2026 …  2018 ‘  2019 ’  201C “  201D ”  2022 •  00B7 ·  00AB «  00BB »  "
		.. "00D7 ×  2192 →  2605 ★  2713 ✓"
	-- Where Core's bundled fonts are.
	local ART = "Interface\\AddOns\\Pagle\\media\\fonts\\"

	it("prints the probe line in the chat font, and shows it in each font Pagle uses (#248, CORE-R9)", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }), 2)
		pagle(loaded, "dev on")

		pagle(loaded, "dev glyphs")

		assert.are.same({
			"Pagle dev: the glyph probe in the chat font: " .. PROBE,
			"Pagle dev: the same line in each font Pagle uses is on screen; a box is a character that font lacks."
				.. " Click it or press Esc to close.",
		}, { loaded.printed[2], loaded.printed[3] })
		local frame = loaded.ns.glyphProbeFrame
		assert.is_true(frame:IsShown())
		local rows = {}
		for _, row in ipairs(frame.rows) do
			rows[#rows + 1] = { row:GetText(), row.fontObject }
		end
		assert.are.same({
			{ "GameFontHighlight (Core's frames): " .. PROBE, "GameFontHighlight" },
			{ "ChatFontNormal (chat, the Field report's text): " .. PROBE, "ChatFontNormal" },
			{ "NumberFontNormalSmallGray (QoL's key label): " .. PROBE, "NumberFontNormalSmallGray" },
			{ ART .. "IMFeENsc28P.ttf (the Fish Journal's small capitals): " .. PROBE, "PagleDevGlyphsFont4" },
			{ ART .. "IMFeENrm28P.ttf (the announcements' print): " .. PROBE, "PagleDevGlyphsFont5" },
			{ ART .. "Caveat-SemiBold.ttf (the announcements' hand): " .. PROBE, "PagleDevGlyphsFont6" },
			{
				ART .. "Marcellus-Regular.ttf (the announcements' gilt and stamps): " .. PROBE,
				"PagleDevGlyphsFont7",
			},
			{ ART .. "IMFeENit28P.ttf (the Curio Shop's italic): " .. PROBE, "PagleDevGlyphsFont8" },
		}, rows)

		frame:Click()
		assert.is_false(frame:IsShown())
	end)

	it("shows the same frame again, changing no saved state (#248)", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }), 2)
		pagle(loaded, "dev on")
		local saved = copy(loaded.env.PagleDB.global)

		pagle(loaded, "dev glyphs")
		local frame = loaded.ns.glyphProbeFrame
		frame:Click()
		pagle(loaded, "dev glyphs")

		assert.are.equal(frame, loaded.ns.glyphProbeFrame)
		assert.is_true(frame:IsShown())
		assert.are.equal(8, #frame.rows)
		assert.are.same(saved, copy(loaded.env.PagleDB.global))
	end)
end)

-- /pagle dev skill (#465): the retail UI check reports Fishing skill 1, where the skill reach (ADR 0014) lets every
-- record grow by a millimetre. The fake client's Fishing reads 75/150 with no modifier.
describe("/pagle dev skill", function()
	local CLIENT_SKILL = { 75, 150 }

	-- The rank and max of the logged-in character's latest Skill Reading, as Core holds them.
	local function reading(loaded)
		local angler = loaded.env.Pagle.GetAngler()
		local latest = angler.skill[angler.current]
		return { latest.rank, latest.max }
	end

	-- The skill the Cast conditions hold now: rank and modifier.
	local function conditionsSkill(loaded)
		local conditions = loaded.env.Pagle.GetConditions()
		return { conditions.skillRank, conditions.skillMod }
	end

	local function ready(saved)
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }, saved), 2)
		loaded.client.advance(0)
		return loaded
	end

	it(
		"reports the rank and a max of 300 as Fishing skill, logs a Skill Reading and says so (#465, LOG-R31)",
		function()
			local loaded = ready()
			pagle(loaded, "dev on")
			assert.are.same(CLIENT_SKILL, reading(loaded))
			local changed = {}
			loaded.env.Pagle.RegisterCallback(changed, "SkillChanged", function(_, skill)
				changed[#changed + 1] = { skill.rank, skill.max }
			end)

			pagle(loaded, "dev skill 1")

			assert.are.same({ 1, 300 }, reading(loaded))
			assert.are.same({ { 1, 300 } }, changed)
			assert.are.same({ 1, 0 }, conditionsSkill(loaded))
			assert.are.same({ rank = 1, max = 300 }, loaded.env.PagleDB.global.devSkill)
			assert.are.equal(
				"Pagle dev: Fishing skill now reads 1/300, whatever the client says. Casts and Skill Readings record it."
					.. " /pagle dev skill off puts the client's back.",
				loaded.printed[2]
			)
		end
	)

	it("takes a max rank too, and keeps the client's modifier (#465)", function()
		local loaded = ready()
		loaded.env.GetProfessionInfo = function(index)
			if index == 8 then
				return "Fishing", 136245, 75, 150, 2, 34, 356, 5, -1, 0, "Fishing"
			end
		end
		pagle(loaded, "dev on")

		pagle(loaded, "DEV SKILL 120 150")

		assert.are.same({ 120, 150 }, reading(loaded))
		assert.are.same({ 120, 5 }, conditionsSkill(loaded))
	end)

	it("records the Casts that follow at that skill, and marks their diagnostics entries (#465, LOG-R81)", function()
		local loaded = ready()
		pagle(loaded, "dev on")
		pagle(loaded, "dev skill 40")

		catchAndFlush(loaded)

		local cast = lastRecord(loaded)
		assert.are.same({ 40, 0 }, { cast.conditions.skillRank, cast.conditions.skillMod })
		local entries = loaded.env.PagleDB.global.diagnostics
		assert.are.equal(40, entries[#entries].devSkill)
		pagle(loaded, "dev skill off")
		catchAndFlush(loaded)
		entries = loaded.env.PagleDB.global.diagnostics
		assert.are.equal(75, lastRecord(loaded).conditions.skillRank)
		assert.is_nil(entries[#entries].devSkill)
	end)

	it("off puts the client's reading back, logging it, and says so (#465)", function()
		local loaded = ready()
		pagle(loaded, "dev on")
		pagle(loaded, "dev skill 1")

		pagle(loaded, "dev skill off")

		assert.are.same(CLIENT_SKILL, reading(loaded))
		assert.are.same({ 75, 0 }, conditionsSkill(loaded))
		assert.is_nil(loaded.env.PagleDB.global.devSkill)
		assert.are.equal("Pagle dev: Fishing skill reads as the client says again.", loaded.printed[3])
	end)

	it("says which reading holds when asked with no argument (#465)", function()
		local loaded = ready()
		pagle(loaded, "dev on")

		pagle(loaded, "dev skill")
		pagle(loaded, "dev skill 30")
		pagle(loaded, "dev skill")

		assert.are.equal(
			"Pagle dev: Fishing skill reads as the client says; /pagle dev skill <rank> overrides it.",
			loaded.printed[2]
		)
		assert.are.equal(
			"Pagle dev: Fishing skill is overridden to 30/300 (/pagle dev skill off to clear it).",
			loaded.printed[4]
		)
	end)

	it(
		"refuses a rank or max outside 1 to 300, or a max below the rank, with its usage, changing nothing (#465)",
		function()
			local loaded = ready()
			pagle(loaded, "dev on")
			local entries = #loaded.env.PagleLog.entries

			for _, args in ipairs({ "0", "301", "-5", "abc", "2.5", "100 99", "10 301", "10 20 30", "off 5" }) do
				pagle(loaded, "dev skill " .. args)
			end

			local usage = "Pagle dev: /pagle dev skill <rank> [max], from 1 to 300 (max defaults to 300), "
				.. "or /pagle dev skill off"
			assert.are.equal(10, #loaded.printed)
			for i = 2, 10 do
				assert.are.equal(usage, loaded.printed[i])
			end
			assert.is_nil(loaded.env.PagleDB.global.devSkill)
			assert.are.equal(entries, #loaded.env.PagleLog.entries)
		end
	)

	it("is refused with one line while dev mode is off, and a saved override doesn't apply (#465)", function()
		local loaded = ready({ global = { dev = false, devSkill = { rank = 1, max = 300 } } })

		pagle(loaded, "dev skill 5")

		assert.are.same({ "Pagle dev: dev commands are off; /pagle dev on turns them on." }, loaded.printed)
		assert.are.same(CLIENT_SKILL, reading(loaded))
		assert.are.same({ 75, 0 }, conditionsSkill(loaded))
		assert.are.same({ rank = 1, max = 300 }, loaded.env.PagleDB.global.devSkill)
	end)

	it("is cleared by /pagle dev off, which reads the client's skill again (#465)", function()
		local loaded = ready()
		pagle(loaded, "dev on")
		pagle(loaded, "dev skill 1")

		pagle(loaded, "dev off")

		assert.is_nil(loaded.env.PagleDB.global.devSkill)
		assert.are.same(CLIENT_SKILL, reading(loaded))
		assert.are.same({ 75, 0 }, conditionsSkill(loaded))
		assert.are.same({
			"Pagle dev: dev commands are off.",
			"Pagle dev: Fishing skill reads as the client says again.",
		}, { loaded.printed[3], loaded.printed[4] })
	end)

	it("persists across a login, reminds in chat and is the login's first Skill Reading (#465, LOG-R31)", function()
		local loaded = ready({ global = { dev = true, devSkill = { rank = 1, max = 300 } } })

		assert.are.same({ 1, 300 }, reading(loaded))
		assert.are.same({ 1, 0 }, conditionsSkill(loaded))
		assert.are.same(
			{ "Pagle dev: Fishing skill is overridden to 1/300 (/pagle dev skill off to clear it)." },
			loaded.printed
		)
	end)

	it("ignores a saved override that is malformed, and says nothing at login (#465)", function()
		for _, bad in ipairs({
			"x",
			{ rank = 0, max = 300 },
			{ rank = 5, max = 301 },
			{ rank = 9, max = 3 },
			{ rank = 2.5, max = 9 },
		}) do
			local loaded = ready({ global = { dev = true, devSkill = bad } })

			assert.are.same(CLIENT_SKILL, reading(loaded))
			assert.are.same({}, loaded.printed)
		end
	end)
end)
