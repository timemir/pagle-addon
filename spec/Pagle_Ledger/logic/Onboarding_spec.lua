-- The Ledger's onboarding as data, with no Core (core/onboarding.md): the Your Ledger step's live parts (ONB-R36,
-- LED-R40, LED-R146) through ns.GuideLedgerPage, the Fish Journal's First look (ONB-R57) as ns.JOURNAL_FIRST_LOOK,
-- and the red pencil a Margin note's term is written in (Contracts).

describe("the Ledger's onboarding", function()
	local ns = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns
	local T0 = SERVER_TIME - 3600

	-- The Journal's text, as far as the step reads it: character names, a realm date and a server time's date.
	local text = {
		Character = function(_, index)
			return ({ "Kukli Vail", "Bea" })[index] or "..."
		end,
		Date = function(_, date)
			return ("%d Oct"):format(date.day)
		end,
		DateAt = function(_, time)
			return ("at %d"):format(time)
		end,
	}

	-- A state with `skill` credited (threshold -> time), and `fields` over it.
	---@param skill table<integer, integer>?
	---@param fields table?
	---@return LedgerState
	local function stateWith(skill, fields)
		local state = { casts = 0, catches = 0, xp = 0, prestige = 0, fresh = 0, coins = 0, skill = skill or {} }
		for key, value in pairs(fields or {}) do
			state[key] = value
		end
		return state
	end

	-- What the step reads: `state` (nil while the projection updates), an empty celebrated set unless given, and the
	-- Angler on character 1 at fishing skill `rank` (none without one).
	---@param state LedgerState?
	---@param rank integer?
	---@param celebrated table?
	local function page(state, rank, celebrated)
		local skill = {}
		if rank then
			skill[1] = { rank = rank, max = 150 }
		end
		return ns.GuideLedgerPage({
			state = state,
			celebrated = celebrated or { skill = {} },
			angler = { current = 1, characters = {}, skill = skill, bestBaseSkill = rank or 0 },
			text = text,
			formatNumber = breakUpLargeNumbers,
		})
	end

	-- Each row as { credited, title, line, xp }.
	local function rows(model)
		local list = {}
		for i, row in ipairs(model.rows) do
			list[i] = { row.credited, row.title, row.line, row.xp }
		end
		return list
	end

	describe("the Your Ledger step (ONB-R36)", function()
		it(
			"heads the box with the character and their skill, ticks the credited Skill Milestone with its XP, gives "
				.. "the next its skill to go and folds the rest for later (ONB-R36, LED-R40)",
			function()
				local model = page(stateWith({ [75] = T0 }), 125)

				assert.are.equal("Kukli Vail", model.name)
				assert.are.equal("Kukli Vail · Fishing 125", model.heading)
				assert.are.same({
					{ true, "Skill Milestone 75", "reached before Pagle came", "+1,000 XP" },
					{ false, "Skill Milestone 150", "25 skill to go", "+1,000 XP" },
					{ false, "Skill Milestones 225 and 300", "for later" },
				}, rows(model))
			end
		)

		it(
			"reads kept since … your first Catch until there is one, then the first Catch's date (ONB-R36, LED-R146)",
			function()
				assert.are.equal("kept since … your first Catch", page(stateWith(), 1).since)
				local caught = stateWith(
					{},
					{ catches = 1, firstTime = T0, firstDate = { year = 2026, month = 10, day = 11 } }
				)
				assert.are.equal("kept since 11 Oct", page(caught, 1).since)
				-- no Catch with a realm date: the first Catch's server time, as the Angler page reads it
				assert.are.equal("kept since at " .. T0, page(stateWith({}, { catches = 1, firstTime = T0 }), 1).since)
			end
		)

		it("says when a Skill Milestone credited after the first Catch was reached (ONB-R36, LED-R40)", function()
			local state = stateWith({ [75] = T0 - 60, [150] = T0 + 60 }, { catches = 2, firstTime = T0 })

			local model = page(state, 160)

			assert.are.same({ true, "Skill Milestone 75", "reached before Pagle came", "+1,000 XP" }, rows(model)[1])
			assert.are.same({ true, "Skill Milestone 150", "reached at " .. (T0 + 60), "+1,000 XP" }, rows(model)[2])
			assert.are.same({ false, "Skill Milestone 225", "65 skill to go", "+1,000 XP" }, rows(model)[3])
			assert.are.same({ false, "Skill Milestone 300", "for later" }, rows(model)[4])
		end)

		it("folds three Milestones into one line, and none past the last (ONB-R36)", function()
			assert.are.same({
				{ false, "Skill Milestone 75", "74 skill to go", "+1,000 XP" },
				{ false, "Skill Milestones 150, 225 and 300", "for later" },
			}, rows(page(stateWith(), 1)))
			assert.are.same(
				{ false, "Skill Milestone 300", "70 skill to go", "+1,000 XP" },
				rows(page(stateWith({ [75] = T0, [150] = T0, [225] = T0 }), 230))[4]
			)
			assert.are.equal(4, #page(stateWith({ [75] = T0, [150] = T0, [225] = T0 }), 230).rows)
		end)

		it(
			"ticks every Milestone credited in the state or the celebrated set, with no next one (LED-R40, LED-R92)",
			function()
				local model = page(stateWith({ [75] = T0, [150] = T0, [225] = T0 }), 300, { skill = { [300] = true } })

				assert.are.same({
					{ true, "Skill Milestone 75", "reached before Pagle came", "+1,000 XP" },
					{ true, "Skill Milestone 150", "reached before Pagle came", "+1,000 XP" },
					{ true, "Skill Milestone 225", "reached before Pagle came", "+1,000 XP" },
					{ true, "Skill Milestone 300", "reached before Pagle came", "+1,000 XP" },
				}, rows(model))
			end
		)

		it("reads a character with no Skill Reading as Fishing 0 (ONB-R36)", function()
			local model = page(stateWith(), nil)

			assert.are.equal("Kukli Vail · Fishing 0", model.heading)
			assert.are.same({ false, "Skill Milestone 75", "75 skill to go", "+1,000 XP" }, rows(model)[1])
		end)

		it(
			"while the projection updates, credits what the Skill Readings reach and leaves kept since out (LED-R40, "
				.. "LOG-R74)",
			function()
				local model = page(nil, 160)

				assert.is_nil(model.since)
				assert.are.equal(0, model.prestige)
				assert.are.same(
					{ true, "Skill Milestone 75", "reached before Pagle came", "+1,000 XP" },
					rows(model)[1]
				)
				assert.are.same({ false, "Skill Milestone 225", "65 skill to go", "+1,000 XP" }, rows(model)[3])
			end
		)

		it("holds the crest's prestige rank (LED-R146, LED-R34)", function()
			assert.are.equal(3, page(stateWith({}, { prestige = 3 }), 1).prestige)
		end)
	end)

	describe("the Fish Journal's First look (ONB-R57)", function()
		it("is five notes, verbatim from the canvas, each with the part it points at", function()
			local look = ns.JOURNAL_FIRST_LOOK

			assert.are.equal("ledger.journal", look.id)
			assert.are.equal("the Fish Journal", ns.L[look.title])
			local notes = {}
			for i, note in ipairs(look.notes) do
				notes[i] = { note.target, ns.L[note.text] }
			end
			assert.are.same({
				{ "tile", "Every water you fish gets a tile. Its rank climbs from *Visitor* to *Master*." },
				{ "xpBar", "Your Angler Level. The *blue* stretch is Fresh Water: bonus XP after a break." },
				{ "notes", "Notes to self: what’s closest to done. They rewrite themselves as you fish." },
				{ "search", "Find a water or a fish. A fish you haven’t caught is *never named*." },
				{ "unfished", "Dashed tiles are waters you haven’t fished yet, with the skill they ask." },
			}, notes)
		end)

		it("sits its notes in the margins beside the book, from its top left, 176 wide (ONB-R58)", function()
			for _, note in ipairs(ns.JOURNAL_FIRST_LOOK.notes) do
				assert.are.equal(176, note.w)
				assert.is_true(note.x < 0 or note.x > ns.JOURNAL_FIRST_LOOK.width)
			end
		end)
	end)

	it("writes a note's *term* in the red pencil (Contracts: |cff9a2a1a…|r)", function()
		assert.are.equal(
			"That’s |cff9a2a1aFresh Water|r, the blue.",
			ns.RedPencilTerms("That’s *Fresh Water*, the blue.")
		)
	end)
end)
