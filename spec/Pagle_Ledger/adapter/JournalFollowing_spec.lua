-- The Journal's Following on FakePagle (LED-R151, LED-R132, LED-R125, LED-R126, LED-R129, LED-R146): Home's
-- "Following" line and the Following spread, its index and the selected Angler's card, and its empty states, drawn
-- from Pagle.GetFollowedAnglers() in each of its four states (VIEW-R11). The files are built in the shape of IGV
-- Contracts' Pagle_Following example (helpers.lua's anglerFileExamples), Ada being that example's Angler.

local DAY = 24 * 3600

-- A Followed Angler's line in Pagle_Following: Ada, the example's (Prestige I, a title, one more character, not
-- Hardcore, as of 12 Oct 2026), with `fields` over her.
---@param fields table?
---@return table
local function angler(fields)
	local line = anglerFileExamples().following.anglers[1]
	for key, value in pairs(fields or {}) do
		line[key] = value
	end
	return line
end

-- The four Followed Anglers, by name as the file has them (IGV-R31): Ada at Prestige I; Bram, Hardcore, at rank 0,
-- with no title and no other character; Iver at Prestige X, as of a date last year; Talia at Master Prestige 1.
local function four()
	return {
		angler(),
		angler({
			name = "Bram Ashcombe",
			more = 0,
			hardcore = true,
			title = "",
			level = 31,
			prestige = 0,
			ledger = 24,
			legends = 1,
			waters = 1,
			catches = 4102,
			asOf = 20261009,
			guids = { "Player-4618-0B000001" },
		}),
		angler({
			name = "Iver Coldwater",
			more = 3,
			title = "Keeper of the Ledger",
			level = 60,
			prestige = 10,
			ledger = 100,
			legends = 7,
			waters = 20,
			catches = 61930,
			asOf = 20250930,
			guids = { "Player-4618-0C000001" },
		}),
		angler({
			name = "Talia Brook",
			more = 4,
			title = "Master of Stranglethorn",
			level = 12,
			prestige = 11,
			ledger = 97,
			legends = 8,
			waters = 19,
			catches = 88406,
			asOf = 20261013,
			guids = { "Player-4618-0D000001" },
		}),
	}
end

-- A Pagle_Following file of `anglers` (four() by default) in the example's shape, written `age` seconds before the
-- fake's server time (ten minutes by default).
---@param anglers table[]?
---@param age integer?
---@return table
local function file(anglers, age)
	local data = anglerFileExamples().following
	data.anglers = anglers or four()
	data.count = #data.anglers
	data.generatedAt = SERVER_TIME - (age or 600)
	return data
end

-- A Ledger on a fake with `following` as Pagle_Following's data (none, so absent, when nil), logged in, in the world,
-- with the Journal open on `id` (Home by default) with `args`.
---@param following table?
---@param id string?
---@param args table?
---@return FakePagle fake
---@return LoadedAddon loaded
local function journalWith(following, id, args)
	return openJournal({
		globals = { BreakUpLargeNumbers = breakUpLargeNumbers },
		following = following,
		id = id,
		args = args,
	})
end

-- Home's contents line for Following: its block, and its widget as drawn.
---@param loaded LoadedAddon
---@return LedgerBlock
---@return table
local function followingLine(loaded)
	local journal = loaded.ns.journal
	local leaders = {}
	for _, block in ipairs(journal.pages.right) do
		if block.kind == "leader" then
			leaders[#leaders + 1] = block
		end
	end
	return leaders[#leaders], journal.shown.right.drawn.leader[#leaders]
end

describe("Home's Following line (LED-R132, LED-R151)", function()
	it('reads "Following" last in In this Ledger, with the number followed in state ok (LED-R132, LED-R151)', function()
		local _, loaded = journalWith(file())

		local block, drawn = followingLine(loaded)

		assert.are.same(
			{ kind = "leader", numeral = "v.", text = "Following", value = "4", place = { id = "following" } },
			block
		)
		assert.are.equal(block, loaded.ns.journal.pages.right[#loaded.ns.journal.pages.right])
		assert.are.same({ "v.", "Following", "4" }, shownTexts(drawn))
	end)

	it('reads "0" with no one followed, in state none (LED-R151)', function()
		local _, loaded = journalWith(file({}))

		assert.are.same({ "v.", "Following", "0" }, shownTexts(select(2, followingLine(loaded))))
	end)

	it('reads "—" once the file is a day old, in state expired (LED-R151)', function()
		local _, loaded = journalWith(file(nil, DAY))

		assert.are.same({ "v.", "Following", "—" }, shownTexts(select(2, followingLine(loaded))))
	end)

	it('greys out as "no Companion" with no Pagle_Following, in state absent (LED-R151)', function()
		local _, loaded = journalWith(nil)

		local block, drawn = followingLine(loaded)

		assert.are.same({
			kind = "leader",
			numeral = "v.",
			text = "Following",
			value = "no Companion",
			color = "faded",
			place = { id = "following" },
		}, block)
		assert.are.same({ "v.", "Following", "no Companion" }, shownTexts(drawn))
		-- the faded ink of the Journal's greyed lines, its words and its value
		local faded = { 0x9a / 255, 0x80 / 255, 0x60 / 255 }
		assert.are.same(faded, { unpack(drawn.label.textColor, 1, 3) })
		assert.are.same(faded, { unpack(drawn.value.textColor, 1, 3) })
	end)

	it(
		"reads the state at each drawing: a file that expires while Home is open shows — at the next (LED-R151)",
		function()
			local fake, loaded = journalWith(file())

			fake.wait(DAY - 600)
			loaded.ns.journal:Draw()

			assert.are.equal("—", (followingLine(loaded)).value)
		end
	)

	for _, case in ipairs({
		{ "ok", file() },
		{ "none", file({}) },
		{ "expired", file(nil, DAY) },
		{ "absent", nil },
	}) do
		it(
			("opens the Following spread in state %s, Home ❧ Following with the back link (LED-R151, LED-R125)"):format(
				case[1]
			),
			function()
				local _, loaded = journalWith(case[2])
				local journal = loaded.ns.journal

				select(2, followingLine(loaded)):Click()

				assert.are.same({ id = "following" }, journal.router:Place())
				assert.are.same(
					{ "Home", "Following" },
					{ journal.pages.crumbs[1].label, journal.pages.crumbs[2].label }
				)
				assert.are.equal(2, #journal.pages.crumbs)
				assert.are.same({ id = "home" }, journal.pages.back)
				assert.is_true(journal.frame.back:IsShown())
			end
		)
	end
end)

-- The rows of a Following page's index: each row block's name, HC stamp (false without) and right-hand value.
---@param blocks LedgerBlock[]
---@return table[]
local function indexRows(blocks)
	local rows = {}
	for _, block in ipairs(blocks) do
		if block.kind == "row" then
			rows[#rows + 1] = { block.text, block.stamp or false, block.value }
		end
	end
	return rows
end

describe("the Following spread's left page (LED-R151)", function()
	it("reads its kicker, title and count, then a row per Followed Angler in the file's order (LED-R151)", function()
		local _, loaded = journalWith(file(), "following")
		local left = loaded.ns.journal.pages.left

		assert.are.same({
			"In this Ledger",
			"Following",
			"4 Anglers you follow. Follow and unfollow on the Pagle website.",
			"Ada",
			"Bram Ashcombe",
			"Iver Coldwater",
			"Talia Brook",
		}, blockTexts(left))
		assert.are.same({ kind = "kicker", text = "In this Ledger" }, left[1])
		assert.are.same({ kind = "title", text = "Following" }, left[2])
		assert.are.equal("text", left[3].kind)
	end)

	it(
		'reads "Lv {L} · {roman} · {p}%" at each row\'s right, no roman at rank 0 and X from rank 11, and stamps HC (LED-R151, LED-R34)',
		function()
			local _, loaded = journalWith(file(), "following")

			assert.are.same({
				{ "Ada", false, "Lv 23 · I · 37%" },
				{ "Bram Ashcombe", "HC", "Lv 31 · 24%" },
				{ "Iver Coldwater", false, "Lv 60 · X · 100%" },
				{ "Talia Brook", false, "Lv 12 · X · 97%" },
			}, indexRows(loaded.ns.journal.pages.left))
		end
	)

	it("counts one Angler in the singular (LED-R151)", function()
		local _, loaded = journalWith(file({ angler() }), "following")

		assert.are.equal(
			"1 Angler you follow. Follow and unfollow on the Pagle website.",
			loaded.ns.journal.pages.left[3].text
		)
	end)

	it("selects the first row on opening, and a row its click opens (LED-R151)", function()
		local _, loaded = journalWith(file(), "following")
		local journal = loaded.ns.journal
		local function selected()
			local marks = {}
			for _, block in ipairs(journal.pages.left) do
				if block.kind == "row" then
					marks[#marks + 1] = block.selected == true
				end
			end
			return marks
		end
		assert.are.same({ true, false, false, false }, selected())
		assert.are.same({ id = "following", args = { angler = 3 } }, journal.pages.left[6].place)

		journal.shown.left.drawn.row[3]:Click()

		assert.are.same({ id = "following", args = { angler = 3 } }, journal.router:Place())
		assert.are.same({ false, false, true, false }, selected())
		assert.are.equal("Iver Coldwater", blockOfKind(journal.pages.right, "title").text)
	end)

	it("selects the first row when its args name no Angler in the file (LED-R151)", function()
		local _, loaded = journalWith(file(), "following", { angler = 9 })

		assert.is_true(loaded.ns.journal.pages.left[4].selected)
		assert.are.equal("Ada", blockOfKind(loaded.ns.journal.pages.right, "title").text)
	end)

	it("draws each row's name, the HC stamp for a Hardcore Angler only, and its value (LED-R151)", function()
		local _, loaded = journalWith(file(), "following")
		local rows = loaded.ns.journal.shown.left.drawn.row

		assert.are.same({ "Ada", "Lv 23 · I · 37%" }, shownTexts(rows[1]))
		assert.are.same({ "Bram Ashcombe", "HC", "Lv 31 · 24%" }, shownTexts(rows[2]))
		assert.is_true(rows[1].wash:IsShown())
		assert.is_false(rows[2].wash:IsShown())
	end)

	it("gives each row its Angler's prestige rank for the emblem, none at rank 0 (LED-R151, LED-R152)", function()
		local _, loaded = journalWith(file(), "following")
		local ranks = {}
		for _, block in ipairs(loaded.ns.journal.pages.left) do
			if block.kind == "row" then
				ranks[#ranks + 1] = block.rank or false
			end
		end

		assert.are.same({ 1, false, 10, 11 }, ranks)
	end)

	it(
		"draws Core's Prestige emblem at 22 just before each row's value, the Master's from rank 11 (LED-R151, LED-R152)",
		function()
			local fake, loaded = journalWith(file(), "following")
			local rows = loaded.ns.journal.shown.left.drawn.row
			local atlas = fake.ns.ATLASES.PrestigeEmblems
			-- The emblem sprite a row's texture shows, by its texture coordinates in Core's emblems atlas.
			local function emblemOf(row)
				for name, sprite in pairs(atlas.sprites) do
					if
						row.emblem.texCoord[1] == sprite.x / atlas.width
						and row.emblem.texCoord[3] == sprite.y / atlas.height
					then
						return name
					end
				end
				return nil
			end

			for i, sprite in pairs({ [1] = "emblem-i", [3] = "emblem-x", [4] = "emblem-master" }) do
				local row = rows[i]
				local emblem = row.emblem
				assert.are.same(
					{ sprite, atlas.file, 22, 22, true },
					{ emblemOf(row), emblem.texture, emblem.width, emblem.height, emblem:IsShown() }
				)
				-- its right edge 5 units before the value's words, centred on the row
				local _, _, _, valueRight = row.value:GetPoint(1)
				local _, _, _, x, y = emblem:GetPoint(1)
				assert.are.same({ valueRight - row.value:GetWidth() - 5, -(25 - 22) / 2 }, { x + 22, y })
			end
		end
	)

	it(
		"draws no emblem at rank 0, and keeps no room for one: the row's height, name and value as a ranked row's (LED-R151, LED-R152)",
		function()
			local _, loaded = journalWith(file(), "following")
			local rows = loaded.ns.journal.shown.left.drawn.row
			local ranked, plain = rows[1], rows[2]
			-- Where `region` sits on its row `row`: its point, whether it is placed on the row, the row's point and the
			-- offsets, SetPoint(point, x, y) being on the same point of its parent.
			local function at(region, row)
				local anchor = { region:GetPoint(1) }
				if type(anchor[2]) == "number" then
					anchor = { anchor[1], region.parent, anchor[1], anchor[2], anchor[3] }
				end
				return { anchor[1], anchor[2] == row, anchor[3], anchor[4], anchor[5] }
			end

			assert.is_false(plain.emblem:IsShown())
			assert.are.same({ 25, 25 }, { ranked:GetHeight(), plain:GetHeight() })
			assert.are.same(at(ranked.name, ranked), at(plain.name, plain))
			assert.are.same(at(ranked.value, ranked), at(plain.value, plain))
		end
	)

	it("hides a row's emblem when the row is drawn again for an Angler at rank 0 (LED-R151, LED-R152)", function()
		local unranked = false
		local _, loaded = openJournal({
			globals = { BreakUpLargeNumbers = breakUpLargeNumbers },
			following = file({ angler() }),
			id = "following",
			modules = function(fake)
				local read = fake.Pagle.GetFollowedAnglers
				fake.Pagle.GetFollowedAnglers = function()
					local followed = read()
					followed.anglers[1].prestige = unranked and 0 or followed.anglers[1].prestige
					return followed
				end
			end,
		})
		assert.is_true(loaded.ns.journal.shown.left.drawn.row[1].emblem:IsShown())

		unranked = true
		loaded.ns.journal:Draw()

		assert.is_false(loaded.ns.journal.shown.left.drawn.row[1].emblem:IsShown())
	end)

	it(
		"keeps the index's scroll as another Angler is selected, starting the card at the top (LED-R129, LED-R151)",
		function()
			local _, loaded = journalWith(file(), "following")
			local journal = loaded.ns.journal
			scrollPage(loaded, "left", 120)
			scrollPage(loaded, "right", 80)

			journal.shown.left.drawn.row[4]:Click()

			assert.are.same({ 120, 0 }, { pageScroll(loaded, "left"), pageScroll(loaded, "right") })
			scrollPage(loaded, "right", 40)
			journal:Draw()
			assert.are.same({ 120, 40 }, { pageScroll(loaded, "left"), pageScroll(loaded, "right") })
		end
	)

	it(
		"keeps its words on the parchment at the default size, a long Hardcore name and large figures too (LED-R151, CORE-R65)",
		function()
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
			local bounds = dofile("spec/support/bounds.lua")
			local long = angler({
				name = "Maximiliana Featherstonehaugh-Saltmarsh",
				hardcore = true,
				level = 60,
				prestige = 8,
				ledger = 100,
				title = "Warden of the Wetlands and the Long Shore",
				more = 12,
				legends = 12,
				catches = 1234567,
				waters = 120,
			})
			local _, loaded = journalWith(file({ long, angler() }), "following")
			local frame = loaded.ns.journal

			assert.are.same({}, bounds.overflows(frame.shown.left))
			assert.are.same({}, bounds.overflows(frame.shown.right))
			assert.is_true(bounds.measured > 0)
			assert.are.same({ "Lv 60 · VIII · 100%" }, { frame.shown.left.drawn.row[1].value:GetText() })
		end
	)
end)

describe("the Following spread's right page, the selected Angler's card (LED-R151)", function()
	-- The card of the Angler at `at` in four(), as the right page's blocks.
	local function cardOf(at)
		local _, loaded = journalWith(file(), "following", { angler = at })
		return loaded.ns.journal.pages.right, loaded
	end

	it(
		"reads Prestige I's card: the name, its other character, the title in the hand, the level and the seal (LED-R151, LED-R146)",
		function()
			local right = cardOf(1)

			assert.are.same({
				{ kind = "title", text = "Ada" },
				{ kind = "text", color = "faded", text = "and 1 more character" },
				{ kind = "text", hand = true, text = "Warden of Feralas Waters" },
				{ kind = "level", text = "23", value = "Angler Level", note = "Prestige I", seal = "Ledger 37%" },
				{ kind = "leader", style = "ruled", text = "Legends", value = "3 of 12" },
				{ kind = "leader", style = "ruled", text = "Waters mastered", value = "4" },
				{ kind = "leader", style = "ruled", text = "Lifetime Catches", value = "5,120" },
				{ kind = "text", color = "faded", text = "As of 12 Oct" },
			}, right)
		end
	)

	it(
		'reads a Hardcore Angler at rank 0 with "Hardcore Angler", no title, no other character and no Prestige (LED-R151, LED-R146)',
		function()
			local right = cardOf(2)

			assert.are.same({
				"Hardcore Angler",
				"Bram Ashcombe",
				"31",
				"Legends",
				"Waters mastered",
				"Lifetime Catches",
				"As of 9 Oct",
			}, blockTexts(right))
			assert.are.same({ kind = "kicker", text = "Hardcore Angler" }, right[1])
			assert.are.same({
				kind = "level",
				text = "31",
				value = "Angler Level",
				note = "No Prestige yet",
				seal = "Ledger 24%",
			}, right[3])
			assert.are.same({ "1 of 12", "1", "4,102" }, { right[4].value, right[5].value, right[6].value })
		end
	)

	it(
		'reads Prestige X at rank 10, "and {n} more characters", and the year on a date outside this one (LED-R151, LED-R126)',
		function()
			local right = cardOf(3)

			assert.are.same({
				"Iver Coldwater",
				"and 3 more characters",
				"Keeper of the Ledger",
				"60",
				"Legends",
				"Waters mastered",
				"Lifetime Catches",
				"As of 30 Sep 2025",
			}, blockTexts(right))
			assert.are.same({ "Prestige X", "Ledger 100%" }, { right[4].note, right[4].seal })
			assert.are.same({ "7 of 12", "20", "61,930" }, { right[5].value, right[6].value, right[7].value })
		end
	)

	it('reads "Master Prestige {n}" from rank 11 (LED-R151, LED-R146)', function()
		local right = cardOf(4)

		assert.are.same({ "12", "Master Prestige 1", "Ledger 97%" }, { right[4].text, right[4].note, right[4].seal })
		assert.are.equal("As of 13 Oct", right[#right].text)
	end)

	it(
		"draws the card: the level in large numerals, the Prestige under it, the seal and the ruled rows (LED-R151)",
		function()
			local _, loaded = journalWith(file(), "following")
			local drawn = loaded.ns.journal.shown.right.drawn

			assert.are.same({
				"Ada",
				"and 1 more character",
				"Warden of Feralas Waters",
				"Angler Level",
				"23",
				"Prestige I",
				"Ledger 37%",
				"Legends",
				"3 of 12",
				"Waters mastered",
				"4",
				"Lifetime Catches",
				"5,120",
				"As of 12 Oct",
			}, shownTexts(loaded.ns.journal.shown.right))
			local level = drawn.level[1]
			assert.is_true(level.seal.wax:IsShown())
			assert.is_true(drawn.leader[1].rule:IsShown())
		end
	)
end)

describe("the Following spread's empty states (LED-R151)", function()
	for _, case in ipairs({
		{
			"none",
			file({}),
			{
				"You follow no one yet.",
				"Follow an Angler from their page on the Pagle website.",
				"The Companion brings them in within the hour; they show here after your next /reload.",
			},
		},
		{
			"absent",
			nil,
			{
				"The Companion keeps this page.",
				"Anglers you follow on the Pagle website are brought into the game by the Pagle Companion.",
				"Without it, this page stays empty. Pasting your log still updates your own Angler page.",
			},
		},
		{
			"expired",
			file(nil, DAY),
			{
				"These pages are more than a day old.",
				"Pagle has set them aside until the Companion brings fresh ones.",
				"Start the Companion, then /reload.",
			},
		},
	}) do
		local state, following, lines = case[1], case[2], case[3]

		it(("keeps the kicker and title, then reads its three lines in state %s (LED-R151)"):format(state), function()
			local _, loaded = journalWith(following, "following")
			local left = loaded.ns.journal.pages.left

			assert.are.same({
				{ kind = "kicker", text = "In this Ledger" },
				{ kind = "title", text = "Following" },
				{ kind = "text", hand = true, text = lines[1] },
				{ kind = "text", text = lines[2] },
				{ kind = "text", color = "faded", text = lines[3] },
			}, left)
			assert.are.same(
				{ "In this Ledger", "Following", lines[1], lines[2], lines[3] },
				shownTexts(loaded.ns.journal.shown.left)
			)
		end)

		it(("leaves the right page blank in state %s (LED-R151)"):format(state), function()
			local _, loaded = journalWith(following, "following", { angler = 1 })

			assert.are.same({}, loaded.ns.journal.pages.right)
			assert.are.same({}, shownTexts(loaded.ns.journal.shown.right))
		end)
	end

	it(
		"shows the expired state at the next drawing once the file expires while the spread is open (LED-R151)",
		function()
			local fake, loaded = journalWith(file(), "following", { angler = 2 })
			assert.are.equal("Bram Ashcombe", blockOfKind(loaded.ns.journal.pages.right, "title").text)

			fake.wait(DAY - 600)
			loaded.ns.journal:Draw()

			assert.are.equal("These pages are more than a day old.", loaded.ns.journal.pages.left[3].text)
			assert.are.same({}, loaded.ns.journal.pages.right)
		end
	)
end)

describe("the Following spread's reads (LED-R151)", function()
	it("reads the Followed Anglers only as the Journal draws, never while it stays closed (LED-R151)", function()
		local calls = 0
		local _, loaded = openJournal({
			following = file(),
			id = false,
			modules = function(fake)
				local read = fake.Pagle.GetFollowedAnglers
				fake.Pagle.GetFollowedAnglers = function()
					calls = calls + 1
					return read()
				end
			end,
		})
		assert.are.equal(0, calls)

		loaded.ns.journal:Toggle()

		assert.are.equal(1, calls)
		assert.are.equal("4", (followingLine(loaded)).value)
	end)
end)
