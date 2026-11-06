-- The cards on the client, through the real TOC (announcements.md › The display queue, › Session summary,
-- › Write-up, › UI): Write-up sections a Module raises from its projection's done and the Session summary cards
-- SessionEnded stores show one at a time in the card frame, closed with its button or Esc.

-- Registers a Module whose projection, over `db`, raises a Write-up section from its done when it first builds:
-- "<name> written up" with the Casts it applied.
local function moduleWritingUp(loaded, name, order, db)
	local M = loaded.env.Pagle.RegisterModule({ name = name, title = name, order = order })
	local casts = 0
	M:NewProjection({
		db = db or {},
		rulesVersion = 1,
		reset = function()
			return {}
		end,
		apply = function(_, record)
			if record.kind == "cast" then
				casts = casts + 1
			end
		end,
		done = function(_, info)
			if info.firstBuild then
				M:RaiseWriteUp({ heading = name .. " written up", lines = { casts .. " Casts" } })
			end
		end,
	})
	return M
end

-- Runs `n` frames (3 by default): enough for every catch-up under 500 entries per frame, the held Announcements'
-- frame and the cards' frame after it.
local function frames(loaded, n)
	for _ = 1, n or 3 do
		loaded.client.advance(0)
	end
end

-- The card on screen as { title, numbers, rows }: the numbers grid's values (nil when it's hidden), and each shown
-- row as "# heading", "line" or "moment · its text"; nil when no card shows.
local function shownCard(loaded)
	local frame = loaded.ns.cardFrame
	if not (frame and frame.shown) then
		return nil
	end
	local numbers
	if frame.numbersBox.shown then
		numbers = {}
		for i, number in ipairs(frame.numbers) do
			numbers[i] = number.value:GetText()
		end
	end
	local rows = {}
	for _, row in ipairs(frame.rows) do
		if row.shown then
			local text = row.text:GetText()
			if row.kind == "heading" then
				text = "# " .. text
			elseif row.kind == "moment" and row.detail:GetText() ~= "" then
				text = text .. " · " .. row.detail:GetText()
			end
			rows[#rows + 1] = text
		end
	end
	return { title = frame.title:GetText(), numbers = numbers, rows = rows }
end

-- The title of the card on screen, or nil.
local function shownTitle(loaded)
	local card = shownCard(loaded)
	return card and card.title
end

-- Clicks the card's close button.
local function close(loaded)
	loaded.ns.cardFrame.close:Click()
end

-- A stored summary card for PagleDB.global.cards, with `casts` Casts and one Ledger moment titled `title`.
local function storedCard(casts, title)
	return {
		title = "Fishing session",
		numbers = { casts = casts, catches = casts, gotAway = 0, seconds = 600 },
		coins = 0,
		lines = {},
		moments = {
			{
				module = "Ledger",
				title = "Ledger",
				order = 10,
				moments = {
					{
						module = "Ledger",
						moduleTitle = "Ledger",
						moduleOrder = 10,
						kind = "x",
						rung = "toast",
						title = title,
					},
				},
			},
		},
	}
end

describe("the Write-up card", function()
	it(
		"ends a section from a Module with a Field guide step with Show me around », which closes the card and opens"
			.. " the guide at that Module's first step; a Module with no step gets none (ANN-R64, ONB-R82)",
		function()
			local loaded = loadCore(history(2))
			moduleWritingUp(loaded, "Hunts", 20)
			local ledger = moduleWritingUp(loaded, "Ledger", 10)
			ledger:RegisterGuideStep({ id = "ledger", order = 60, ribbon = "Your Ledger", build = function() end })
			enterWorld(loaded)
			frames(loaded)

			assert.are.same({
				title = "Write-up",
				rows = { "# Ledger written up", "2 Casts", "Show me around »", "# Hunts written up", "2 Casts" },
			}, shownCard(loaded))
			local link
			for _, row in ipairs(loaded.ns.cardFrame.rows) do
				if row.kind == "link" then
					link = row.link
				end
			end
			link:Click()

			assert.is_nil(shownCard(loaded))
			assert.are.same({}, loaded.env.PagleDB.global.writeUp)
			assert.is_true(loaded.ns.guide:IsOpen())
			assert.are.equal("ledger", loaded.ns.guide:Current().step.id)
		end
	)

	it(
		"puts two Modules' first-build sections on one Write-up card by Module order, shown only after the last"
			.. " projection finishes and the lanes are empty, with no sound (ANN-R21, ANN-R60, ANN-R61, ANN-R92)",
		function()
			local loaded = loadCore(history(501))
			moduleWritingUp(loaded, "Hunts", 20)
			local ledger = moduleWritingUp(loaded, "Ledger", 10)
			loaded.client.fire("PLAYER_LOGIN")
			ledger:RaiseMoment({ rung = "toast", kind = "welcome", title = "Welcome back", sound = false })
			loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)
			assert.is_true(loaded.ns.projections:IsUpdating())

			frames(loaded)
			assert.is_false(loaded.ns.projections:IsUpdating())
			assert.is_true(loaded.ns.announcementFrames.toast.shown)
			assert.is_nil(shownCard(loaded))
			loaded.client.advance(loaded.ns.SETTLE_SECONDS.toast + loaded.ns.HOLD_SECONDS.toast)

			assert.are.same({
				title = "Write-up",
				rows = { "# Ledger written up", "501 Casts", "# Hunts written up", "501 Casts" },
			}, shownCard(loaded))
			assert.are.same({}, loaded.client.sounds)
		end
	)

	it(
		"keeps a Write-up not closed before logout and shows it at the next login, before any summary card; each"
			.. " closes with its button or Esc (ANN-R54, ANN-R61, announcements.md › UI)",
		function()
			local first = loadCore(history(2))
			moduleWritingUp(first, "Ledger", 10)
			enterWorld(first)
			frames(first)
			assert.are.equal("Write-up", shownTitle(first))

			local global = first.env.PagleDB.global
			global.cards = { storedCard(3, "New Species") }
			local second = loadCore(history(2), { global = global })
			moduleWritingUp(second, "Ledger", 10, {})
			enterWorld(second)
			frames(second)

			assert.are.equal("Write-up", shownTitle(second))
			close(second)
			assert.are.same({}, second.env.PagleDB.global.writeUp)
			assert.are.same({ "# Ledger", "New Species" }, shownCard(second).rows)
			second.client.pressEscape()
			assert.is_nil(shownCard(second))
			assert.are.same({}, second.env.PagleDB.global.cards)
		end
	)

	it(
		"keeps the sections on screen out of a Session card made after Cozy mode goes on, so they show once"
			.. " (ANN-R61, ANN-R62)",
		function()
			local loaded = loadCore(history(2))
			local ledger = moduleWritingUp(loaded, "Ledger", 10)
			enterWorld(loaded)
			frames(loaded)
			assert.are.equal("Write-up", shownTitle(loaded))

			loaded.ns.db.profile.announcements.cozy = true
			catchAndFlush(loaded)
			ledger:RaiseMoment({ rung = "toast", kind = "newSpecies", title = "New Species" })
			loaded.client.advance(300)
			assert.are.equal("Write-up", shownTitle(loaded))
			close(loaded)

			assert.are.same({ "# Ledger", "New Species" }, shownCard(loaded).rows)
			assert.are.same({}, loaded.env.PagleDB.global.writeUp)
			close(loaded)
			assert.is_nil(shownCard(loaded))
		end
	)

	it("stays on screen while UIParent hides, which isn't the player closing it (announcements.md › UI)", function()
		local loaded = loadCore(history(2))
		moduleWritingUp(loaded, "Ledger", 10)
		enterWorld(loaded)
		frames(loaded)
		local frame = loaded.ns.cardFrame

		frame.scripts.OnHide(frame)

		assert.are.equal("Write-up", shownTitle(loaded))
		assert.are.equal(1, #loaded.env.PagleDB.global.writeUp)
	end)

	it(
		"in Cozy mode isn't shown: its section waits and rides on the next card, which shows although its Session"
			.. " raised nothing (ANN-R53, ANN-R62)",
		function()
			-- No Session to end at login: the log holds no Cast yet.
			local loaded = loadCore({ BUILD_ENTRY })
			loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			-- A Write-up waiting from an earlier login.
			loaded.ns.db.global.writeUp = {
				{
					module = "Ledger",
					order = 10,
					title = "Ledger",
					heading = "Ledger written up",
					lines = { "2 Casts" },
				},
			}
			loaded.ns.db.profile.announcements.cozy = true
			enterWorld(loaded)
			frames(loaded)
			assert.is_nil(shownCard(loaded))

			catchAndFlush(loaded)
			loaded.client.advance(300)

			assert.are.same({
				title = "Fishing session",
				numbers = { "1", "1", "0", "1 min" },
				rows = { "# Ledger written up", "2 Casts" },
			}, shownCard(loaded))
			assert.are.same({}, loaded.env.PagleDB.global.writeUp)
		end
	)

	it("raises an error at the Module's call outside a projection's done (ANN-R60)", function()
		local loaded = loadCore(history(2))
		local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
		enterWorld(loaded)

		local ok, err = pcall(M.RaiseWriteUp, M, { heading = "Written up", lines = {} })

		assert.is_false(ok)
		assert.matches("only from a projection's done", err)
		assert.are.same({}, loaded.env.PagleDB.global.writeUp or {})
	end)

	it(
		"covers a Module's catch-up after it was off with a section and no pop-ups (ANN-R4, ANN-R60, ANN-R90)",
		function()
			local loaded = loadCore(history(3))
			local M = loaded.env.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
			local fingerprint = loaded.env.Pagle.CONTENT_FINGERPRINT
			M:NewProjection({
				db = {
					projection = {},
					lastSeq = 1,
					logId = loaded.env.PagleLog.logId,
					fingerprint = fingerprint,
					rulesVersion = 1,
				},
				rulesVersion = 1,
				reset = function()
					return {}
				end,
				apply = function(_, record)
					if record.kind == "cast" then
						M:RaiseMoment({ rung = "toast.high", kind = "hunt", title = "Hunt completed", cast = record.id })
					end
				end,
				done = function(_, info)
					M:RaiseWriteUp({ heading = "While Hunts was off", lines = { info.replayed .. " entries" } })
				end,
			})
			local errors = {}
			loaded.env.geterrorhandler = function()
				return function(err)
					errors[#errors + 1] = tostring(err)
				end
			end
			enterWorld(loaded)
			frames(loaded)

			assert.are.same({ "# While Hunts was off", "3 entries" }, shownCard(loaded).rows)
			assert.is_nil(loaded.ns.announcementFrames.toast)
			assert.are.equal(1, #errors)
			assert.matches("dropped %(ANN%-R4%)", errors[1])
		end
	)
end)

describe("the Session summary cards", function()
	it(
		'keep the newest 3 of 4 and show them oldest first, one at a time, "Your last session" titled (ANN-R54)',
		function()
			-- Three cards from earlier logins, and the last login crashed with a moment in its open Session.
			local saved = {
				global = {
					cards = { storedCard(1, "First"), storedCard(2, "Second"), storedCard(3, "Third") },
					summary = {
						moments = {
							{
								module = "Ledger",
								moduleTitle = "Ledger",
								moduleOrder = 10,
								kind = "levelUp",
								rung = "banner",
								title = "Angler Level 12",
								coins = 1200,
							},
						},
						lines = {},
					},
				},
			}
			local loaded =
				loadCore({ BUILD_ENTRY, castEntry(SERVER_TIME - 2000), castEntry(SERVER_TIME - 1990) }, saved)
			enterWorld(loaded)
			frames(loaded)

			local shown = { shownCard(loaded) }
			for _ = 1, 3 do
				close(loaded)
				shown[#shown + 1] = shownCard(loaded)
			end

			assert.are.same({
				{ title = "Fishing session", numbers = { "2", "2", "0", "10 min" }, rows = { "# Ledger", "Second" } },
				{ title = "Fishing session", numbers = { "3", "3", "0", "10 min" }, rows = { "# Ledger", "Third" } },
				{
					title = "Your last session",
					numbers = { "2", "2", "0", "1 min" },
					rows = {
						"Pagle Coins +1,200 |TInterface\\MoneyFrame\\UI-GoldIcon:0|t",
						"# Ledger",
						"Angler Level 12",
					},
				},
			}, shown)
			assert.are.same({}, loaded.env.PagleDB.global.cards)
		end
	)

	it("show a since-disabled Module's moments and lines, and show in Cozy mode (ANN-R55, ANN-R90)", function()
		local card = storedCard(4, "New Species")
		card.moments[1] = {
			module = "Hunts",
			title = "Hunts",
			order = 20,
			moments = {
				{
					module = "Hunts",
					moduleTitle = "Hunts",
					moduleOrder = 20,
					kind = "hunt",
					rung = "toast.high",
					title = "Hunt completed",
					text = "Dusk Hunt",
				},
			},
		}
		card.lines = { { module = "Hunts", title = "Hunts", lines = { "Hunts: 2 pinned" } } }
		local loaded = loadCore(history(2), { global = { cards = { card } } })
		loaded.ns.db.profile.announcements.cozy = true
		enterWorld(loaded)
		frames(loaded)

		assert.are.same({ "Hunts: 2 pinned", "# Hunts", "Hunt completed · Dusk Hunt" }, shownCard(loaded).rows)
	end)

	it(
		"lay a moment's text too long to sit beside its title on the ruled lines under it, from the title's left and"
			.. " wrapped to the row, which takes every line it fills; a short one stays at the right of the title's"
			.. " line (#314, announcements.md › UI)",
		function()
			-- The page's ruled lines' spacing, and the text's width under a title: the row's, past the icon.
			local LINE, UNDER = 30, 580 - 62 - 30 - 28
			-- Two cards like #314's: a Ledger moment, then the Tackle Board's long one and a short one.
			local function tackleCard()
				local card = storedCard(27, "Angler Level 8")
				local function moment(title, text)
					return {
						module = "TackleBoard",
						moduleTitle = "Tackle Board",
						moduleOrder = 30,
						kind = "notice",
						rung = "toast",
						title = title,
						text = text,
					}
				end
				card.moments[2] = {
					module = "TackleBoard",
					title = "Tackle Board",
					order = 30,
					moments = {
						moment("Notice complete", "6 Notices or better Catches. Tied for your Fly Box: Red Rock Ember"),
						moment("Hunt completed", "Dusk Hunt"),
					},
				}
				return card
			end
			local loaded = loadCore(history(2), { global = { cards = { tackleCard(), tackleCard() } } })
			enterWorld(loaded)
			frames(loaded)
			-- Each shown row as { first line, lines, where its moment's text is }, its lines counted down the list.
			local function layout()
				local frame = loaded.ns.cardFrame
				local laid = {}
				for _, row in ipairs(frame.rows) do
					if row.shown then
						local _, _, _, _, y = row:GetPoint()
						local place = "-"
						if row.kind == "moment" and row.detail:GetText() ~= "" then
							local point, _, relativePoint, x, dy = row.detail:GetPoint()
							place = ("%s of %s %d,%d"):format(point, relativePoint, x, dy)
							if row.detail:CanWordWrap() then
								place = ("%s, wrapped to %d"):format(place, row.detail.width)
							end
						end
						laid[#laid + 1] = { 1 - y / LINE, row:GetHeight() / LINE, place }
					end
				end
				return laid, frame.content:GetHeight() / LINE, frame.scroll:GetHeight() / LINE
			end

			assert.are.same({
				"# Ledger",
				"Angler Level 8",
				"# Tackle Board",
				"Notice complete · 6 Notices or better Catches. Tied for your Fly Box: Red Rock Ember",
				"Hunt completed · Dusk Hunt",
			}, shownCard(loaded).rows)
			local under = ("BOTTOMLEFT of BOTTOMLEFT 28,4, wrapped to %d"):format(UNDER)
			assert.are.same({
				{
					{ 1, 1, "-" },
					{ 2, 1, "-" },
					{ 3, 1, "-" },
					{ 4, 2, under },
					{ 6, 1, "BOTTOMRIGHT of TOPRIGHT 0,-26" },
				},
				6,
				6,
			}, { layout() })

			-- The client wraps a text too long for one line under the title onto two, LINE apart: the row takes three.
			for _, row in ipairs(loaded.ns.cardFrame.rows) do
				row.detail.GetStringHeight = function()
					return 2 * LINE - 10
				end
			end
			close(loaded)
			local laid, content = layout()
			assert.are.same({ 4, 3, under }, laid[4])
			assert.are.same({ 7, 1, "BOTTOMRIGHT of TOPRIGHT 0,-26" }, laid[5])
			assert.are.equal(7, content)
		end
	)

	it(
		"show when the Session ends and the lanes are empty; a summaryOnly moment never pops up and makes its"
			.. " Session's card (ANN-R21, ANN-R63, ANN-R91)",
		function()
			local loaded = loadCore(history(2))
			-- Margin notes off: no note's noteIn among the sounds (ONB-R50, ONB-R52).
			loaded.env.PagleDB.global.onboarding.notesOn = false
			local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			M:NewProjection({
				-- Built before, under other rules: a rebuild that isn't a first build.
				db = { projection = {}, lastSeq = 3, logId = "old", fingerprint = "old", rulesVersion = 0 },
				rulesVersion = 1,
				reset = function()
					return {}
				end,
				apply = function() end,
				done = function(_, info)
					assert(info.rebuilt and not info.firstBuild)
					M:RaiseMoment({ rung = "toast", kind = "newSpecies", title = "New Species", summaryOnly = true })
				end,
			})
			enterWorld(loaded)
			frames(loaded)
			assert.is_nil(shownCard(loaded))

			-- No catch toast: it would hold the card back as any toast does (ANN-R21).
			loaded.ns.db.profile.announcements.everyCatch = false
			catchAndFlush(loaded)
			loaded.client.advance(299)
			assert.is_nil(shownCard(loaded))
			loaded.client.advance(1)

			assert.are.same({ "# Ledger", "New Species" }, shownCard(loaded).rows)
			assert.is_nil(loaded.ns.announcementFrames.toast)
			assert.are.same({}, loaded.client.sounds)
		end
	)

	it(
		"draw on the art's ledger page: its ruled body under a leather head with the gilt title (announcements.md › UI)",
		function()
			local loaded = loadCore(history(2), { global = { cards = { storedCard(1, "First") } } })
			loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			enterWorld(loaded)
			frames(loaded)

			local card = loaded.ns.cardFrame
			assert.are.same(
				{ loaded.ns.ATLASES.Announce.file, "PagleArtCardTitle" },
				{ card.tiles[1].texture, card.title.fontObject }
			)
		end
	)

	it(
		"hold each of the numbers inside its own column, between the rules and their padding: time fished in hours"
			.. " and minutes and counts in the thousands step their size down to fit, short ones keep the art's full"
			.. " size (ANN-R53)",
		function()
			-- The page's width past its margin, the columns' left, and the padding kept clear of a rule.
			local PAGE_WIDTH, LEFT, PAD = 580 - 62 - 10, 62 - 20, 8
			local FULL, FLOOR = 44, 22
			-- A card whose Session fished `seconds` with `count` Casts and Catches and `away` got away.
			local function numbered(count, away, seconds)
				local card = storedCard(count, "Angler Level 8")
				card.numbers = { casts = count, catches = count, gotAway = away, seconds = seconds }
				return card
			end
			-- The long cases: "23 h 59 min" and a day-long stretch of "100 h 05 min", and counts of 4, 5 and 6 digits.
			local cases = {
				numbered(130, 0, 3900), -- "130", "130", "0", "1 h 05 min"
				numbered(1234, 1234, 3900), -- "1,234", at the full size
				numbered(12345, 12345, 86340), -- "12,345", "23 h 59 min"
				numbered(123456, 99999, 360300), -- "123,456", "99,999", "100 h 05 min"
			}
			local loaded = loadCore(history(2), { global = { cards = { storedCard(1, "First"), unpack(cases) } } })
			enterWorld(loaded)
			frames(loaded)
			local frame = loaded.ns.cardFrame
			-- The width the client measures, 0.37 a character a unit (the art's "1 h 05 min" at 44 is about 162).
			for _, number in ipairs(frame.numbers) do
				number.value.GetStringWidth = function(self)
					return #(self.text or "") * 0.37 * (self.font and self.font[2] or FULL)
				end
			end
			-- Each number's { size, left edge, right edge } on the grid.
			local function extents()
				local laid = {}
				for i, number in ipairs(frame.numbers) do
					local value = number.value
					local size = value.font and value.font[2] or FULL
					local x = select(4, value:GetPoint())
					laid[i] =
						{ size = size, left = x - value:GetStringWidth() / 2, right = x + value:GetStringWidth() / 2 }
				end
				return laid
			end

			local sizes = {}
			for n = 1, #cases do
				close(loaded)
				local laid = extents()
				sizes[n] = {}
				for i, number in ipairs(laid) do
					sizes[n][i] = number.size
					assert.is_true(number.size >= FLOOR)
					-- Inside its own column, clear of both its rules by the padding.
					assert.is_true(number.right - number.left <= frame.numberRooms[i])
					if i > 1 then
						assert.is_true(laid[i - 1].right + 2 * PAD <= number.left + 0.001)
					end
				end
				assert.is_true(laid[1].left >= LEFT + PAD - 0.001)
				assert.is_true(laid[#laid].right <= LEFT + PAGE_WIDTH - PAD + 0.001)
			end

			-- The short numbers and "1 h 05 min" keep the full size; every long one is stepped down, and a shorter
			-- value after it goes back up (the frame is the same one).
			assert.are.same({ FULL, FULL, FULL, FULL }, sizes[1])
			assert.are.same({ FULL, FULL, FULL, FULL }, sizes[2])
			assert.is_true(sizes[3][1] < FULL and sizes[3][4] < FULL)
			assert.is_true(sizes[4][1] <= sizes[3][1] and sizes[4][4] <= sizes[3][4])
			assert.are.same({ "123,456", "123,456", "99,999", "100 h 05 min" }, shownCard(loaded).numbers)
		end
	)

	it("wait while a toast shows when the Session ends, and show once it goes (ANN-R21)", function()
		local loaded = loadCore(history(2))
		local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
		enterWorld(loaded)
		frames(loaded)
		catchAndFlush(loaded)
		M:RaiseMoment({ rung = "toast", kind = "newSpecies", title = "New Species" })
		loaded.client.advance(295)
		M:RaiseMoment({ rung = "toast", kind = "late", title = "Late toast" })
		loaded.client.advance(5)
		assert.is_true(loaded.ns.announcementFrames.toast.shown)
		assert.is_nil(shownCard(loaded))

		loaded.client.advance(6)

		assert.are.equal("Fishing session", shownTitle(loaded))
	end)
end)

describe("moving the card (ANN-R102)", function()
	-- UIParent is 1920 × 1080 here, so its centre is (960, 540).
	local SCREEN_WIDTH, SCREEN_HEIGHT = 1920, 1080

	-- Core logged in with two stored summary cards, the first on screen.
	local function withCard(saved)
		saved = saved or {}
		saved.global = saved.global or { cards = { storedCard(1, "First"), storedCard(2, "Second") } }
		local loaded = loadCore(history(2), saved)
		loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
		enterWorld(loaded)
		frames(loaded)
		assert.are.equal("Fishing session", shownTitle(loaded))
		return loaded, loaded.ns.cardFrame
	end

	-- Where the card is: its CENTER's offsets from UIParent's CENTER.
	local function centreOf(loaded)
		local point, relativeTo, relativePoint, x, y = loaded.ns.cardFrame:GetPoint(1)
		assert.are.same({ "CENTER", loaded.env.UIParent, "CENTER" }, { point, relativeTo, relativePoint })
		return { x = x, y = y }
	end

	-- A left-button drag of the card that is let go with its centre at (`x`, `y`) from UIParent's centre, as the
	-- client reports it then. Returns whether the drag moved the card.
	local function dragCard(frame, x, y)
		frame.scripts.OnDragStart(frame, "LeftButton")
		local moved = frame.moving == true
		frame.screenCenter = { SCREEN_WIDTH / 2 + x, SCREEN_HEIGHT / 2 + y }
		frame.scripts.OnDragStop(frame)
		return moved
	end

	-- The saved point, if any.
	local function saved(loaded)
		local cards = loaded.ns.db.profile.cards
		return cards and cards.point
	end

	it("stands centre-screen with nothing saved, and takes a left-button drag (ANN-R102)", function()
		local loaded, frame = withCard()

		assert.is_nil(saved(loaded))
		assert.are.same({ x = 0, y = 0 }, centreOf(loaded))
		assert.are.same({ "LeftButton" }, frame.dragButtons)
		assert.is_true(frame:IsMovable())
	end)

	it("moves with a Shift-drag and saves where it is left (ANN-R102)", function()
		local loaded, frame = withCard()
		loaded.client.keysDown.SHIFT = true

		assert.is_true(dragCard(frame, 200, 150))

		assert.are.same({ x = 200, y = 150 }, saved(loaded))
		assert.are.same({ x = 200, y = 150 }, centreOf(loaded))
		assert.is_false(frame.moving)
		-- The client's layout cache never keeps it: profile.cards.point is the one place its position is kept.
		assert.is_false(frame:IsUserPlaced())
		assert.are.equal("Fishing session", shownTitle(loaded))
	end)

	it("doesn't move with a plain drag (ANN-R102)", function()
		local loaded, frame = withCard()

		assert.is_false(dragCard(frame, 200, 150))

		assert.is_nil(saved(loaded))
		assert.are.same({ x = 0, y = 0 }, centreOf(loaded))
	end)

	it("doesn't move while restricted, Shift or not (ANN-R102)", function()
		local loaded, frame = withCard()
		loaded.client.keysDown.SHIFT = true
		loaded.env.Pagle.IsRestricted = function()
			return true
		end

		assert.is_false(dragCard(frame, 200, 150))

		assert.is_nil(saved(loaded))
		assert.are.same({ x = 0, y = 0 }, centreOf(loaded))
	end)

	it("stops a drag where it is when the card hides for restriction, and saves it (ANN-R102, ANN-R35)", function()
		local loaded, frame = withCard()
		loaded.client.keysDown.SHIFT = true
		frame.scripts.OnDragStart(frame, "LeftButton")
		frame.screenCenter = { SCREEN_WIDTH / 2 - 150, SCREEN_HEIGHT / 2 + 100 }

		setCombat(loaded, true)

		assert.is_nil(shownCard(loaded))
		assert.is_false(frame.moving)
		assert.are.same({ x = -150, y = 100 }, saved(loaded))
		-- Letting go later changes nothing.
		frame.screenCenter = { SCREEN_WIDTH / 2 + 300, SCREEN_HEIGHT / 2 }
		frame.scripts.OnDragStop(frame)
		assert.are.same({ x = -150, y = 100 }, saved(loaded))
		-- And when it is over, the card shows again where it was left.
		setCombat(loaded, false)
		loaded.client.advance(2)
		frames(loaded)
		assert.are.equal("Fishing session", shownTitle(loaded))
		assert.are.same({ x = -150, y = 100 }, centreOf(loaded))
	end)

	it("shows the next card where the last was left (ANN-R102)", function()
		local loaded, frame = withCard()
		loaded.client.keysDown.SHIFT = true
		dragCard(frame, -300, 120)

		close(loaded)

		assert.are.same({ "# Ledger", "Second" }, shownCard(loaded).rows)
		assert.are.same({ x = -300, y = 120 }, centreOf(loaded))
	end)

	it("shows at the saved point at the next login (ANN-R102, announcements.md › Data)", function()
		local first, frame = withCard()
		first.client.keysDown.SHIFT = true
		dragCard(frame, 250, -100)

		local loaded = withCard(first.env.PagleDB)

		assert.are.same({ x = 250, y = -100 }, centreOf(loaded))
	end)

	it("reads a saved value it can't make sense of as centred (ANN-R102)", function()
		for _, point in ipairs({ "garbage", { x = 1 }, { x = 0 / 0, y = 3 }, { x = math.huge, y = 0 } }) do
			local loaded = loadCore(history(2), { global = { cards = { storedCard(1, "First") } } })
			loaded.ns.db.profile.cards = { point = point }
			enterWorld(loaded)
			frames(loaded)

			assert.are.same({ x = 0, y = 0 }, centreOf(loaded))
		end
	end)

	it("keeps the dropped card on the screen, whole (ANN-R102)", function()
		local loaded, frame = withCard()
		loaded.client.keysDown.SHIFT = true
		local height = frame:GetHeight()

		dragCard(frame, 5000, 5000)

		-- 580 wide: its centre no nearer the edges than half that, and half its height.
		local corner = { x = SCREEN_WIDTH / 2 - 290, y = SCREEN_HEIGHT / 2 - height / 2 }
		assert.are.same(corner, saved(loaded))
		assert.are.same(corner, centreOf(loaded))
		dragCard(frame, -5000, -5000)
		assert.are.same({ x = -corner.x, y = -corner.y }, saved(loaded))
	end)

	it(
		"places a saved point the screen can't hold at the nearest that fits, without rewriting it (ANN-R102)",
		function()
			local loaded = loadCore(history(2), { global = { cards = { storedCard(1, "First") } } })
			loaded.ns.db.profile.cards = { point = { x = 5000, y = -5000 } }
			enterWorld(loaded)
			frames(loaded)
			local height = loaded.ns.cardFrame:GetHeight()

			assert.are.same({ x = SCREEN_WIDTH / 2 - 290, y = -(SCREEN_HEIGHT / 2 - height / 2) }, centreOf(loaded))
			assert.are.same({ x = 5000, y = -5000 }, loaded.ns.db.profile.cards.point)
		end
	)

	it("keeps the card on screen when the screen shrinks, and follows a bigger one back (ANN-R102)", function()
		local loaded = withCard()
		loaded.ns.db.profile.cards = { point = { x = 600, y = 300 } }
		-- The next card shows at the saved point.
		close(loaded)
		local height = loaded.ns.cardFrame:GetHeight()
		assert.are.same({ x = 600, y = 300 }, centreOf(loaded))

		loaded.env.UIParent:SetSize(1366, 768)

		assert.are.same({ x = 1366 / 2 - 290, y = math.min(300, 768 / 2 - height / 2) }, centreOf(loaded))
		assert.are.same({ x = 600, y = 300 }, loaded.ns.db.profile.cards.point)
		loaded.env.UIParent:SetSize(SCREEN_WIDTH, SCREEN_HEIGHT)
		assert.are.same({ x = 600, y = 300 }, centreOf(loaded))
	end)

	it("Reset clears the saved point and puts the card on screen back in the centre (ANN-R102)", function()
		local loaded, frame = withCard()
		loaded.client.keysDown.SHIFT = true
		dragCard(frame, 200, 150)

		assert.is_true(loaded.ns.ResetCard())

		assert.is_nil(saved(loaded))
		assert.are.same({ x = 0, y = 0 }, centreOf(loaded))
	end)

	it("Reset does nothing while restricted (ANN-R102)", function()
		local loaded, frame = withCard()
		loaded.client.keysDown.SHIFT = true
		dragCard(frame, 200, 150)
		loaded.env.Pagle.IsRestricted = function()
			return true
		end

		assert.is_false(loaded.ns.ResetCard())

		assert.are.same({ x = 200, y = 150 }, saved(loaded))
		assert.are.same({ x = 200, y = 150 }, centreOf(loaded))
	end)

	it('says "Shift-drag to move" at the page\'s foot, beside the close button (ANN-R102)', function()
		local _, frame = withCard()

		assert.are.equal("Shift-drag to move", frame.moveHint:GetText())
		assert.is_true(frame.moveHint:IsShown())
	end)
end)
