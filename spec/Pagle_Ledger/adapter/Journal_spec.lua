-- The Fish Journal's book on FakePagle (LED-R120–R123, LED-R125, LED-R145; ledger.md › UI): the frame, what its
-- pages show while the projection updates and after, live redraws, navigation and the shared widgets. Its entry
-- points through Core's real logic are in Ledger_spec.

local MACKEREL = 6303 -- Raw Slitherskin Mackerel, a Species in the generated catalogue

-- A Ledger on a fake that has logged in, with the projection built (login step 3) unless `updating`.
---@param updating boolean?
local function loggedIn(updating)
	return openJournal({ building = updating, id = false })
end

-- Whether `list` has `text`.
---@param list string[]
---@param text string
local function has(list, text)
	for _, item in ipairs(list) do
		if item == text then
			return true
		end
	end
	return false
end

-- The crumbs' labels the book shows now.
local function crumbLabels(loaded)
	local labels = {}
	for i, crumb in ipairs(loaded.ns.journal.pages.crumbs or {}) do
		labels[i] = crumb.label
	end
	return labels
end

-- A test spread three crumbs deep (Home ❧ Waters ❧ Zone ❧ Fish), showing the lifetime Catches on its left page
-- and the fish chosen (its selection) on its right.
---@type LedgerSpread
local DEEP = {
	crumbs = function(args)
		return {
			{ label = "Waters", place = { id = "home", args = { tab = 0 } } },
			{ label = "Zone", place = { id = "zone" } },
			{ label = "Fish " .. args.fish, place = { id = "deep", args = args } },
		}
	end,
	draw = function(args, context)
		return {
			left = { { kind = "text", text = context.state.catches .. " Catches" } },
			right = { { kind = "text", text = "chosen " .. args.fish } },
		}
	end,
}

describe("the Fish Journal's frame (LED-R120, LED-R121)", function()
	it("is PagleLedgerJournal, closed until opened, and Esc closes it (LED-R120)", function()
		local _, loaded = loggedIn()
		local journal = loaded.ns.journal

		assert.is_false(journal:IsShown())
		journal:Toggle()

		local frame = journal.frame
		assert.are.equal("PagleLedgerJournal", frame.name)
		assert.is_true(has(loaded.env.UISpecialFrames, "PagleLedgerJournal"))
		assert.is_true(frame:IsShown())
		loaded.client.pressEscape()
		assert.is_false(journal:IsShown())
	end)

	it("moves by dragging its leather, saved by Core and never by the client (LED-R120, BOOK-R5)", function()
		local fake, loaded = loggedIn()
		local journal = loaded.ns.journal
		journal:Toggle()
		local frame = journal.frame

		assert.is_true(frame:IsMovable())
		frame:Drag({ "TOPLEFT", loaded.env.UIParent, "TOPLEFT", 40, -60 })

		assert.is_false(frame:IsUserPlaced())
		assert.are.same({ "TOPLEFT", "TOPLEFT", 40, -60 }, fake.profile.books["ledger.journal"])
	end)

	it("opens where it was left, and stays put while open (LED-R120)", function()
		local _, loaded = loggedIn()
		local journal = loaded.ns.journal
		journal:Toggle()
		local frame = journal.frame

		frame:Drag({ "TOPLEFT", loaded.env.UIParent, "TOPLEFT", 40, -60 })
		local dragged = frame.points
		journal:Show()
		assert.are.same(dragged, frame.points)

		journal:Toggle()
		journal:Toggle()
		assert.are.same(
			{ "TOPLEFT", "TOPLEFT", 40, -60 },
			{ frame.points[1][1], frame.points[1][3], frame.points[1][4], frame.points[1][5] }
		)
	end)

	it("closes with its close button, and each toggle opens or closes it (LED-R120)", function()
		local _, loaded = loggedIn()
		local journal = loaded.ns.journal

		journal:Toggle()
		journal.frame.close:Click()
		assert.is_false(journal:IsShown())
		journal:Toggle()
		assert.is_true(journal:IsShown())
		journal:Toggle()
		assert.is_false(journal:IsShown())
	end)

	it("still ends closed when the whole UI hides as it fades out, and opens whole again (LED-R120)", function()
		local _, loaded = openJournal({ id = false, motion = true })
		local journal = loaded.ns.journal
		journal:Toggle()
		loaded.client.update(0.5)
		local frame = journal.frame

		journal:Close()
		loaded.client.update(0.05)
		-- Alt-Z: the client runs the OnHide of each shown frame under UIParent.
		loaded.env.UIParent:Hide()
		frame.scripts.OnHide(frame)
		loaded.client.update(0.05)
		loaded.env.UIParent:Show()
		loaded.client.update(0.05)

		assert.are.same({ false, false, 1 }, { frame:IsShown(), journal:IsShown(), frame.alpha })
		journal:Toggle()
		loaded.client.update(0.5)
		assert.are.same({ true, 1 }, { journal:IsShown(), frame.alpha })
	end)

	it("shows Home at its first opening, and the spread it was left on when reopened (LED-R120)", function()
		local _, loaded = loggedIn()
		local journal = loaded.ns.journal
		loaded.ns.RegisterJournalSpread("deep", DEEP)

		journal:Toggle()
		assert.are.same({ "Home" }, crumbLabels(loaded))
		assert.is_true(has(shownTexts(journal.frame), "Where I've Fished"))

		journal:Open("deep", { fish = MACKEREL })
		loaded.client.pressEscape()
		journal:Toggle()

		assert.are.same({ "Home", "Waters", "Zone", "Fish 6303" }, crumbLabels(loaded))
		assert.is_true(has(shownTexts(journal.frame), "chosen 6303"))
	end)

	it("shows Home again after a /reload, at its first opening (LED-R120)", function()
		local _, loaded = loggedIn()
		loaded.ns.RegisterJournalSpread("deep", DEEP)
		loaded.ns.journal:Open("deep", { fish = MACKEREL })

		local _, reloaded = loggedIn()
		reloaded.ns.journal:Toggle()

		assert.are.same({ "Home" }, crumbLabels(reloaded))
	end)

	it("opens and works while restricted: it makes no secure frames (LED-R121)", function()
		local fake, loaded = loggedIn()
		loaded.ns.RegisterJournalSpread("deep", DEEP)
		fake.setRestricted(true)

		loaded.ns.journal:Toggle()
		loaded.ns.journal:Open("deep", { fish = MACKEREL })

		assert.is_true(loaded.ns.journal:IsShown())
		assert.are.same({ "Home", "Waters", "Zone", "Fish 6303" }, crumbLabels(loaded))
	end)
end)

describe("the Fish Journal while the projection updates (LED-R122)", function()
	it("shows only LED-R122's line on both pages, with the crumbs and search hidden (LED-R122, BOOK-R22)", function()
		local _, loaded = loggedIn(true)
		local journal = loaded.ns.journal

		journal:Toggle()

		local line = "The Ledger is being written up from your Catch log."
		assert.is_true(journal.pages.updating)
		assert.are.same({ { kind = "text", text = line } }, journal.pages.left)
		assert.are.same({ { kind = "text", text = line } }, journal.pages.right)
		-- once, under the quill on the left page (BOOK-R25), and the First look's "?" beside the wax close, on the
		-- leather like the close (ONB-R59)
		assert.are.same({ line, "?" }, shownTexts(journal.frame))
		assert.is_false(journal.frame.notices.left:IsShown())
		assert.are.same({}, shownTexts(journal.frame.crumbs))
		assert.is_false(journal.search:IsShown())
		assert.is_false(journal.frame.back:IsShown())
	end)

	it(
		"shows the quill over its line and the fleuron rule on the left page, a fleuron on the right (LED-R122,"
			.. " BOOK-R25)",
		function()
			local _, loaded = loggedIn(true)
			local journal = loaded.ns.journal

			journal:Toggle()

			local layers = journal.frame.noticeLayers
			local view = journal.updatingView
			assert.is_true(view.quill:IsVisible())
			assert.are.equal(layers.left, view.quill:GetParent())
			assert.is_truthy(view.quill:GetTexture():find("LedgerParts$"))
			assert.are.equal("The Ledger is being written up from your Catch log.", view.words:GetText())
			assert.are.same({ "TOP", layers.left, "TOPLEFT", 221, -273 }, { view.words:GetPoint() })
			assert.is_true(view.fleuron:IsVisible())
			assert.are.equal(layers.right, view.fleuron:GetParent())
			assert.is_truthy(view.fleuron:GetTexture():find("BookAtlas$"))
			assert.are.same(
				{ 22, 22, 0.5 },
				{ view.fleuron:GetWidth(), view.fleuron:GetHeight(), view.fleuron:GetAlpha() }
			)
		end
	)

	it("sways the quill 4° each way while it shows, and stops it when the update finishes (LED-R122)", function()
		local fake, loaded = openJournal({ building = true, motion = true })
		local journal = loaded.ns.journal
		local quill = journal.updatingView.quill
		local lowest, highest = math.huge, -math.huge
		for _ = 1, 40 do
			loaded.client.update(0.05)
			local degrees = math.deg(quill.rotation)
			lowest, highest = math.min(lowest, degrees), math.max(highest, degrees)
		end
		assert.is_true(lowest < -3.9 and lowest >= -4.001)
		assert.is_true(highest > 3.9 and highest <= 4.001)

		fake.enterWorld()
		local rested = quill.rotation
		loaded.client.update(0.3)

		assert.is_false(journal.frame.noticeLayers.left:IsShown())
		assert.are.equal(rested, quill.rotation)
	end)

	it("redraws when the update finishes (LED-R122)", function()
		local fake, loaded = loggedIn(true)
		local journal = loaded.ns.journal
		journal:Toggle()

		fake.enterWorld()

		assert.is_false(journal.pages.updating)
		assert.are.same({ "Home" }, shownTexts(journal.frame.crumbs))
		assert.is_true(journal.search:IsShown())
		assert.is_true(has(shownTexts(journal.frame), "Where I've Fished"))
	end)

	it(
		"adds its redraws to a copy of the projection's def, leaving the def it was given as it was (LED-R122)",
		function()
			local _, loaded = loggedIn(true)
			local applied, finished = {}, 0
			local def = {
				apply = function(_, record)
					applied[#applied + 1] = record
				end,
				done = function()
					finished = finished + 1
				end,
			}
			local apply, done = def.apply, def.done

			local wrapped = loaded.ns.WithJournalRedraws(def)
			wrapped.apply({}, "record", "live")
			wrapped.done({}, {})

			assert.are_not.equal(def, wrapped)
			assert.are.same({ apply, done }, { def.apply, def.done })
			assert.are.same({ { "record" }, 1 }, { applied, finished })
		end
	)
end)

describe("the Fish Journal's live redraw (LED-R123)", function()
	it("redraws the open spread on the frame after a live entry, keeping its selection (LED-R123)", function()
		local fake, loaded = loggedIn()
		local journal = loaded.ns.journal
		loaded.ns.RegisterJournalSpread("deep", DEEP)
		journal:Open("deep", { fish = MACKEREL })
		assert.are.same({ { kind = "text", text = "0 Catches" } }, journal.pages.left)

		fake.playCast("caught", { { itemID = MACKEREL, quantity = 1 } })
		fake.playCast("caught", { { itemID = MACKEREL, quantity = 1 } })
		assert.are.same({ { kind = "text", text = "0 Catches" } }, journal.pages.left)
		loaded.client.runTimers()

		assert.are.same({ { kind = "text", text = "2 Catches" } }, journal.pages.left)
		assert.are.same({ { kind = "text", text = "chosen 6303" } }, journal.pages.right)
		assert.are.same({ "Home", "Waters", "Zone", "Fish 6303" }, crumbLabels(loaded))
	end)

	it("doesn't draw a closed book for a live entry (LED-R123)", function()
		local fake, loaded = loggedIn()
		local journal = loaded.ns.journal
		local draws = 0
		loaded.ns.RegisterJournalSpread("home", {
			crumbs = function()
				return {}
			end,
			draw = function()
				draws = draws + 1
				return { left = {}, right = {} }
			end,
		})

		fake.playCast("caught", { { itemID = MACKEREL, quantity = 1 } })
		loaded.client.runTimers()

		assert.are.equal(0, draws)
		assert.is_false(journal:IsShown())
	end)
end)

describe("the Fish Journal's navigation (LED-R125)", function()
	it("shows three crumbs for a spread three deep, and back goes one crumb up (LED-R125)", function()
		local _, loaded = loggedIn()
		local journal = loaded.ns.journal
		loaded.ns.RegisterJournalSpread("deep", DEEP)
		loaded.ns.RegisterJournalSpread("zone", {
			crumbs = function()
				return {
					{ label = "Waters", place = { id = "home", args = { tab = 0 } } },
					{ label = "Zone", place = { id = "zone" } },
				}
			end,
			draw = function()
				return { left = { { kind = "title", text = "The zone" } }, right = {} }
			end,
		})
		journal:Open("deep", { fish = MACKEREL })

		-- the crumbs' words, a fleuron before each but the first
		local texts = shownTexts(journal.frame.crumbs)
		assert.are.same({ "Home", "Waters", "Zone", "Fish 6303" }, texts)
		local fleurons = {}
		for i = 1, 4 do
			fleurons[i] = journal.frame.crumbButtons[i].fleuron ~= nil
		end
		assert.are.same({ false, true, true, true }, fleurons)
		assert.is_true(journal.frame.back:IsShown())

		journal.frame.back:Click()

		assert.are.same({ "Home", "Waters", "Zone" }, crumbLabels(loaded))
		assert.is_true(has(shownTexts(journal.frame), "The zone"))
	end)

	it("opens a crumb's level when it is clicked, and Home has no back link (LED-R125)", function()
		local _, loaded = loggedIn()
		local journal = loaded.ns.journal
		loaded.ns.RegisterJournalSpread("deep", DEEP)
		journal:Open("deep", { fish = MACKEREL })

		journal.frame.crumbButtons[1]:Click()

		assert.are.same({ "Home" }, crumbLabels(loaded))
		assert.is_false(journal.frame.back:IsShown())
	end)

	it("does nothing for a spread nobody registered (LED-R125)", function()
		local _, loaded = loggedIn()
		local journal = loaded.ns.journal

		assert.is_false(journal:Open("unregistered"))

		assert.is_false(journal:IsShown())
	end)
end)

describe("the Fish Journal's widgets (ledger.md › UI)", function()
	-- Opens a spread whose left page is `blocks`.
	local function drawn(blocks)
		local _, loaded = loggedIn()
		loaded.ns.RegisterJournalSpread("widgets", {
			crumbs = function()
				return { { label = "Widgets", place = { id = "widgets" } } }
			end,
			draw = function()
				return { left = blocks, right = {} }
			end,
		})
		loaded.ns.journal:Open("widgets")
		return loaded, shownTexts(loaded.ns.journal.shown.left)
	end

	it("draws the ink XP bar's words, Fresh Water's in blue (LED-R145)", function()
		local bar = { fill = 0.5, fresh = { from = 0.5, to = 0.6 }, text = "500 of 1,160.", freshText = " Fresh." }

		local loaded, texts = drawn({ { kind = "xpBar", bar = bar } })

		assert.are.same({ "500 of 1,160.", " Fresh." }, texts)
		local widget = loaded.ns.journal.shown.left.drawn.xpBar[1]
		assert.are.same({ 0x23 / 255, 0x40 / 255, 0x7a / 255 }, { unpack(widget.fresh.textColor, 1, 3) })
	end)

	it("draws each kind of block with its words (ledger.md › UI)", function()
		local loaded, texts = drawn({
			{ kind = "kicker", text = "The Waters" },
			{ kind = "title", text = "Where I've Fished" },
			{ kind = "text", text = "A note", hand = true, color = "blue" },
			{ kind = "link", text = "Home", place = { id = "home" } },
			{ kind = "leader", text = "The Trophy Room", value = "3 / 40", place = { id = "home" } },
			{ kind = "seal", text = "Local" },
			{ kind = "stamps", stamps = { { text = "Caught", inked = true }, { text = "Regular", inked = false } } },
			{
				kind = "tiles",
				tiles = {
					{ name = "Elwynn Forest", line = "Local · 63%", bar = 0.63, seal = "M", note = "2 new!" },
					{ name = "Duskwood", line = "unfished · skill ~150", faded = true },
				},
			},
			{ kind = "icon", icon = MACKEREL, look = "silhouette" },
		})

		assert.are.same({
			"The Waters",
			"Where I've Fished",
			"A note",
			"Home",
			"The Trophy Room",
			"3 / 40",
			"Local",
			"Elwynn Forest",
			"Local · 63%",
			"2 new!",
			"Duskwood",
			"unfished · skill ~150",
		}, texts)
		-- the stamps are the kit's, inked or in ghost ink
		local stamps = loaded.ns.journal.shown.left.drawn.stamps[1].stamps
		assert.are.same({ "stamp-caught", "stamp-regular-off" }, { stamps[1].sprite, stamps[2].sprite })
	end)

	it("draws a sepia icon round in its ring, warmed toward sepia (ledger.md › UI)", function()
		local loaded = drawn({ { kind = "icon", icon = 136245, look = "sepia" } })

		local medal = loaded.ns.journal.shown.left.drawn.icon[1].medal
		assert.is_true(medal.icon:IsShown())
		assert.are.equal(136245, medal.icon.texture)
		assert.are.same({ 1, 0.94, 0.82 }, medal.icon.vertexColor)
		assert.is_false(medal.unknown:IsShown())
	end)

	it(
		"draws the one unknown-fish medallion for what isn't caught, never its icon, on an entry, a row and a plinth (LED-R124)",
		function()
			local loaded = drawn({
				{ kind = "icon", icon = MACKEREL, look = "silhouette" },
				{ kind = "row", icon = MACKEREL, look = "silhouette", text = "— unknown —" },
				{ kind = "plinth", icon = MACKEREL, look = "silhouette", text = "An empty plinth" },
			})

			local drawnWidgets = loaded.ns.journal.shown.left.drawn
			for _, medal in ipairs({
				drawnWidgets.icon[1].medalLarge,
				drawnWidgets.row[1].medal,
				drawnWidgets.plinth[1].medal,
			}) do
				assert.are.same({ true, false }, { medal.unknown:IsShown(), medal.icon:IsShown() })
				assert.is_nil(medal.icon.texture)
			end
		end
	)

	it("opens a link's place when it is clicked (LED-R125)", function()
		local loaded = drawn({ { kind = "link", text = "Home", place = { id = "home" } } })

		loaded.ns.journal.shown.left.drawn.link[1]:Click()

		assert.are.same({ "Home" }, crumbLabels(loaded))
	end)

	it("hides the widgets a redraw no longer uses (ledger.md › UI, LED-R123)", function()
		local loaded = drawn({ { kind = "seal", text = "Local" }, { kind = "seal", text = "Expert" } })

		loaded.ns.journal:OpenPlace(loaded.ns.JournalPlace.home())

		local texts = shownTexts(loaded.ns.journal.shown.left)
		assert.are.same({ "The Waters", "Where I've Fished" }, { texts[1], texts[2] })
		assert.is_false(has(texts, "Local"))
		assert.is_false(has(texts, "Expert"))
	end)
end)

describe("a Journal page's mouse wheel (ledger.md › UI › Motion)", function()
	it("glides a third of the page a notch, quick notches adding up, to the content's foot", function()
		local _, loaded = openJournal({ id = false, motion = true })
		local page = loaded.ns.NewJournalPage(loaded.env.UIParent, 200, 300)
		page.contentH = 1000
		local wheel = page.scroll:GetScript("OnMouseWheel")

		wheel(page.scroll, -1)
		loaded.client.update(0.03)
		wheel(page.scroll, -1)
		loaded.client.update(0.2)

		-- Two notches of 300 / 3, the second while the first still glided (26 a notch, each restarted from where the
		-- glide had got to, went some 40).
		assert.are.equal(200, math.floor(page.scroll:GetVerticalScroll() + 0.5))
		assert.is_true(page.thumb:IsShown())
		for _ = 1, 10 do
			wheel(page.scroll, -1)
		end
		loaded.client.update(0.2)
		assert.are.equal(700, math.floor(page.scroll:GetVerticalScroll() + 0.5), "it stops at the content's foot")
	end)
end)
