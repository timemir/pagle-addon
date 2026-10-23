-- The Fish Journal in the Ledger art kit (ledger.md › UI): its textures and fonts, its sounds, its fit to the screen,
-- the page turn and the moments of change, each played only while Core's Animations setting is on.

local MACKEREL = 6303 -- Raw Slitherskin Mackerel, a Species in the generated catalogue

-- A test spread whose left page is what `pages.left` holds when drawn, and whose right page names it.
---@param pages { left: LedgerBlock[] }
---@return LedgerSpread
local function spreadOf(pages)
	return {
		crumbs = function()
			return { { label = "Test", place = { id = "test" } } }
		end,
		draw = function()
			return { left = pages.left, right = { { kind = "text", text = "the test spread" } } }
		end,
	}
end

-- The sounds played since `from` (an index into client.sounds), as "<id> SFX".
---@param loaded LoadedAddon
---@param from integer
---@return string[]
local function soundsSince(loaded, from)
	return { unpack(loaded.client.sounds, from + 1) }
end

-- Whether `list` has `text`.
local function has(list, text)
	for _, item in ipairs(list) do
		if item == text then
			return true
		end
	end
	return false
end

describe("the Fish Journal's art (ledger.md › UI)", function()
	it(
		"draws its own parts from its media, the bindings' swatches from Core's, as BLP files that ship (LED-R110, ADR 0015)",
		function()
			local fake, loaded = openJournal()
			local atlases = loaded.ns.JOURNAL_ATLASES
			local function path(file)
				return file:gsub("^Interface\\AddOns\\", "addons/"):gsub("\\", "/") .. ".blp"
			end

			local parts = atlases.Parts.file
			assert.matches("^Interface\\AddOns\\Pagle_Ledger\\media\\journal\\", parts)
			assert(#readFile(path(parts)) > 0, path(parts))
			-- The kit's old Prestige and Legend crests and its Prestige emblem are retired: Core draws the Prestige
			-- frames, emblems and Legend crests (LED-R152, LED-R153, LED-R154).
			assert.is_nil(atlases.Crests)
			assert.is_nil(atlases.Parts.sprites.emblem)
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
			assert.is_nil(io.open("addons/Pagle_Ledger/media/journal/Crests.blp", "rb"))
			for _, name in ipairs({ "Bindings", "Bindings2" }) do
				local file = atlases[name].file
				assert.matches("^Interface\\AddOns\\Pagle\\media\\books\\", file)
				assert(#readFile(path(file)) > 0, path(file))
			end
			for _, binding in ipairs(loaded.ns.BINDINGS) do
				local look = fake.Pagle.GetBindingLook(loaded.ns.BindingID(binding))
				assert(atlases[look.swatchAtlas].sprites[look.swatch], look.swatch)
			end
		end
	)

	it("wraps a seal's words, so Home's seal shows both \"Ledger\" and the completion under it", function()
		local _, loaded = openJournal()
		local seal = loaded.ns.JournalSeal(loaded.ns.journal.frame, 76, 13)

		loaded.ns.JournalSetSeal(seal, loaded.ns.L.HOME_SEAL_WORD .. "\n62%", true)

		assert.is_true(seal.label.wordWrap)
		assert.are.equal("Ledger\n62%", seal.label.text)
	end)

	it(
		"crops a medallion's icon to inside its square border, so the round mask shows no flat edge in the ring",
		function()
			local _, loaded = openJournal()
			local medal = loaded.ns.JournalMedal(loaded.ns.journal.frame, 60)

			loaded.ns.JournalSetMedal(medal, MACKEREL, "sepia")

			assert.are.same({ 0.08, 0.92, 0.08, 0.92 }, medal.icon.texCoord)
		end
	)

	it("draws its book shell from Core's media/books, which the Hunts board and the Stats book share", function()
		local _, loaded = openJournal()

		assert.are.equal("Interface\\AddOns\\Pagle\\media\\books\\BookAtlas", loaded.ns.JOURNAL_ATLASES.Book.file)
		assert.are.equal("Interface\\AddOns\\Pagle\\media\\books\\Parchment", loaded.ns.JOURNAL_FILES.parchment)
		assert.are.equal(loaded.ns.JOURNAL_FILES.parchment, loaded.ns.journal.frame.parchments.left.paper.texture)
	end)

	it("sets its small capitals in IM Fell English SC, bundled in Core's fonts with its licence", function()
		local _, loaded = openJournal()

		assert.are.equal("Interface\\AddOns\\Pagle\\media\\fonts\\IMFeENsc28P.ttf", loaded.ns.JournalFontFile("sc"))
		assert.is_true(#readFile("addons/Pagle/media/fonts/IMFeENsc28P.ttf") > 0)
		assert.matches("SIL OPEN FONT LICENSE", readFile("addons/Pagle/media/fonts/OFL-IMFellEnglishSC.txt"))
		-- Home's kicker is drawn in it
		local kicker = loaded.ns.journal.shown.left.drawn.kicker[1].label
		assert.are.same({ loaded.ns.JournalFontFile("sc"), 14, "" }, kicker.fontObject.font)
	end)

	it("shrinks to fit a small screen, centred, and never grows past its size", function()
		local _, loaded = openJournal({ id = false })
		local journal = loaded.ns.journal
		loaded.env.UIParent:SetSize(800, 600)

		journal:Toggle()

		-- 950 × 700 with the wax close and the ribbons' hang (BOOK-R3), 24 free each side
		assert.are.equal(math.min((600 - 48) / 700, (800 - 48) / 950), journal.frame:GetScale())
		journal:Toggle()
		loaded.env.UIParent:SetSize(1920, 1080)
		journal:Toggle()
		assert.are.equal(1, journal.frame:GetScale())
	end)

	it("fits the screen again where it stands when the UI scale changes, through Core's fit (BOOK-R3)", function()
		local _, loaded = openJournal({ id = false })
		local journal = loaded.ns.journal
		journal:Toggle()
		assert.are.equal(1, journal.frame:GetScale())

		loaded.env.UIParent:SetSize(800, 600)
		loaded.client.fireGameEvent("UI_SCALE_CHANGED")

		assert.are.equal(math.min((600 - 48) / 700, (800 - 48) / 950), journal.frame:GetScale())
		local point, relativeTo, relativePoint, x, y = journal.frame:GetPoint(1)
		assert.are.same(
			{ "CENTER", loaded.env.UIParent, "CENTER", 0, 40 / journal.frame:GetScale() },
			{ point, relativeTo, relativePoint, x, y }
		)
	end)
end)

describe("the Fish Journal's sounds (ledger.md › UI)", function()
	it("plays the book's own sounds as it opens and closes, by sound kit id on the SFX channel", function()
		local _, loaded = openJournal({ id = false })
		local from = #loaded.client.sounds

		loaded.ns.journal:Toggle()
		loaded.ns.journal:Toggle()
		loaded.ns.journal:Toggle()
		loaded.client.pressEscape()

		assert.are.same({ "829 SFX", "830 SFX", "829 SFX", "830 SFX" }, soundsSince(loaded, from))
	end)

	it("turns the page silently while things don't move: the page turn's sound is tied to its motion", function()
		local _, loaded = openJournal()
		local from = #loaded.client.sounds

		loaded.ns.journal.shown.right.drawn.leader[1]:Click()

		assert.are.same({}, soundsSince(loaded, from))
		assert.are.same({ "Home", "The Trophy Room" }, {
			loaded.ns.journal.pages.crumbs[1].label,
			loaded.ns.journal.pages.crumbs[2].label,
		})
	end)

	it("sounds a fish picked while things don't move: only the page turn's beat is tied to its motion", function()
		local _, loaded = openJournal()
		local journal = loaded.ns.journal
		local spread = spreadOf({ left = { { kind = "text", text = "the fish" } } })
		spread.subjects = { left = {}, right = { "fish" } } -- picking a fish changes the right page alone
		loaded.ns.RegisterJournalSpread("test", spread)
		journal:Open("test", { fish = 1 })
		local from = #loaded.client.sounds

		journal:Open("test", { fish = 2 })

		assert.are.same({ "836 SFX" }, soundsSince(loaded, from))
	end)

	it("sounds a Legend's plate opening while things don't move", function()
		local _, loaded = openJournal()
		local from = #loaded.client.sounds

		loaded.ns.OpenLegendPlate(loaded.ns.journal.legendPlate)

		assert.are.same({ "836 SFX" }, soundsSince(loaded, from))
	end)
end)

describe("the Fish Journal's motion (ledger.md › UI, the kit's MOTION.md)", function()
	it("fades the book in as it opens", function()
		local _, loaded = openJournal({ id = false, motion = true })

		loaded.ns.journal:Toggle()
		assert.are.equal(0, loaded.ns.journal.frame.alpha)
		loaded.client.update(0.2)

		assert.are.equal(1, loaded.ns.journal.frame.alpha)
	end)

	it("turns the page to another spread with its sound, the old pages gone once it lands", function()
		local _, loaded = openJournal({ motion = true })
		local journal = loaded.ns.journal
		loaded.client.update(0.2)
		local from = #loaded.client.sounds
		local home = journal.shown.left

		journal.shown.right.drawn.leader[1]:Click()

		assert.are.same({ "836 SFX" }, soundsSince(loaded, from))
		assert.are_not.equal(home, journal.shown.left)
		-- mid-turn, Home's left page still shows beside the lifting leaf
		assert.is_true(has(shownTexts(journal.frame), "Where I've Fished"))
		loaded.client.update(0.3)
		loaded.client.update(0.3)

		assert.is_false(has(shownTexts(journal.frame), "Where I've Fished"))
		assert.is_true(has(shownTexts(journal.frame), "The Trophy Room"))
		assert.is_false(journal.frame.turnFold:IsShown())
	end)

	it("logs a fish caught since the page was drawn: its medallion, a green wash and the write sound", function()
		local _, loaded = openJournal({ motion = true })
		local journal = loaded.ns.journal
		local pages = {
			left = {
				{
					kind = "row",
					icon = MACKEREL,
					look = "silhouette",
					text = "— unknown —",
					place = { id = "test" },
				},
			},
		}
		loaded.ns.RegisterJournalSpread("test", spreadOf(pages))
		journal:Open("test")
		loaded.client.update(1)
		local from = #loaded.client.sounds

		pages.left = {
			{
				kind = "row",
				icon = MACKEREL,
				look = "sepia",
				text = "Raw Slitherskin Mackerel",
				place = { id = "test" },
			},
		}
		journal:Draw()

		assert.are.same({ "3093 SFX" }, soundsSince(loaded, from))
		local row = journal.shown.left.drawn.row[1]
		loaded.client.update(0.4)
		assert.is_true(row.glow.alpha > 0)
		loaded.client.update(1.2)
		assert.are.same({ 0, 1 }, { row.glow.alpha, row.name.alpha })
		assert.is_true(row.medal.icon:IsShown())
	end)

	it("presses a new seal on as a zone's rank rises, the stamp sounding as it lands", function()
		local _, loaded = openJournal({ motion = true })
		local journal = loaded.ns.journal
		local pages = { left = { { kind = "seal", text = "Visitor", inked = true } } }
		loaded.ns.RegisterJournalSpread("test", spreadOf(pages))
		journal:Open("test")
		loaded.client.update(1)
		local from = #loaded.client.sounds

		pages.left = { { kind = "seal", text = "Regular", inked = true } }
		journal:Draw()
		local seal = journal.shown.left.drawn.seal[1].seal
		assert.are.equal("Visitor", seal.label.text)
		loaded.client.update(0.2)
		assert.are.equal("Regular", seal.label.text)
		loaded.client.update(0.3)

		assert.are.same({ "1204 SFX" }, soundsSince(loaded, from))
		assert.are.same({ 64, 1 }, { seal.width, seal.alpha })
	end)

	it("runs the ink on as the XP bar fills, settling at its new length", function()
		local _, loaded = openJournal({ motion = true })
		local journal = loaded.ns.journal
		local pages = { left = { { kind = "xpBar", bar = { fill = 0.2, text = "200 of 1,000." } } } }
		loaded.ns.RegisterJournalSpread("test", spreadOf(pages))
		journal:Open("test")
		loaded.client.update(1)

		pages.left = { { kind = "xpBar", bar = { fill = 0.6, text = "600 of 1,000." } } }
		journal:Draw()
		local bar = journal.shown.left.drawn.xpBar[1].bar
		assert.are.equal(0.2, bar.pct)
		loaded.client.update(0.3)
		assert.is_true(bar.pct > 0.2 and bar.pct < 0.6)
		loaded.client.update(0.4)

		assert.are.equal(0.6, bar.pct)
	end)

	it("draws everything settled while Core's Animations setting is off", function()
		local _, loaded = openJournal()
		local journal = loaded.ns.journal
		local pages = { left = { { kind = "xpBar", bar = { fill = 0.2, text = "200 of 1,000." } } } }
		loaded.ns.RegisterJournalSpread("test", spreadOf(pages))
		journal:Open("test")

		pages.left = { { kind = "xpBar", bar = { fill = 0.6, text = "600 of 1,000." } } }
		journal:Draw()

		assert.are.equal(0.6, journal.shown.left.drawn.xpBar[1].bar.pct)
		assert.are.equal(1, journal.frame.alpha)
	end)
end)
