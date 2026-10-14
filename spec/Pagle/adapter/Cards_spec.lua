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
			loaded.client.advance(6)

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
		"show when the Session ends and the lanes are empty; a summaryOnly moment never pops up and makes its"
			.. " Session's card (ANN-R21, ANN-R63, ANN-R91)",
		function()
			local loaded = loadCore(history(2))
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

			catchAndFlush(loaded)
			loaded.client.advance(299)
			assert.is_nil(shownCard(loaded))
			loaded.client.advance(1)

			assert.are.same({ "# Ledger", "New Species" }, shownCard(loaded).rows)
			assert.is_nil(loaded.ns.announcementFrames.toast)
			assert.are.same({}, loaded.client.sounds)
		end
	)

	it("draw in the toast's one Timber style: the same planks and brass edge (ANN-R80)", function()
		local loaded = loadCore(history(2), { global = { cards = { storedCard(1, "First") } } })
		local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
		enterWorld(loaded)
		frames(loaded)
		M:RaiseMoment({ rung = "toast", kind = "newSpecies", title = "New Species" })
		loaded.client.advance(0)

		local toast, card = loaded.ns.announcementFrames.toast, loaded.ns.cardFrame
		assert.are.same(
			{ wood = toast.children[1].color, edge = toast.children[2].color },
			{ wood = card.children[1].color, edge = card.children[2].color }
		)
	end)

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
