-- The Field report box and its entry points (field-report.md › Privacy, › The box and its entry points; REP-R37,
-- REP-R40–R47, REP-R93; CORE-R33, CORE-R40, CORE-R50, CORE-R61; settings.md SET-R10, SET-R12).

local URL = "https://github.com/timemir/wow-fish/issues/new?template=field-report.yml"

local FIRST = SERVER_TIME - 700 -- the history's Casts are at FIRST + 1, + 2, …

-- The box Core drew, or nil before the first opening.
local function box(loaded)
	return loaded.ns.fieldReportBox
end

-- Long enough for the box's fade out (0.15 s) to end and hide it.
local FADE_OUT = 0.2

describe("Pagle.OpenFieldReport (REP-R40)", function()
	it(
		"opens the box titled Help chart the waters, the privacy line above the report text, selected, and the issue"
			.. " form URL below it (REP-R37, REP-R40, REP-R46)",
		function()
			local loaded = enterWorld(loadCore(unchartedHistory(2, FIRST)), 2)
			local parts = loaded.ns.FieldReportText(assert(loaded.ns.FieldReportRows()))

			loaded.env.Pagle.OpenFieldReport()

			local frame = assert(box(loaded))
			assert.is_true(frame:IsShown())
			assert.are.equal("Help chart the waters", frame.title:GetText())
			assert.is_true(frame.privacy:IsShown())
			assert.are.equal("This will be posted publicly. It contains no character names.", frame.privacy:GetText())
			assert.are.equal(1, #parts)
			assert.are.equal(parts[1], frame.text:GetText())
			assert.truthy(frame.text:GetText():find("^PAGLE%-REPORT 1\n"))
			assert.is_true(frame.text:IsShown())
			assert.are.equal(frame.text, loaded.client.focus, "focused, so Ctrl+C copies it")
			assert.are.same({ 0, -1 }, frame.text.highlight, "all of it selected")
			assert.is_true(frame.url:IsShown())
			assert.are.equal(URL, frame.url:GetText())
			assert.is_false(frame.message:IsShown())
			assert.are.same({}, loaded.printed)
		end
	)
end)

-- A caught Cast of an item no catalogue has, on the fake client.
local function catchUncharted(loaded)
	catchOne(loaded, { { link = "|cffffffff|Hitem:9990::::::::15:::::::::|h[Mystery]|h|r", quantity = 1 } })
	loaded.client.advance(0)
end

describe("The Field report box (REP-R40–R42)", function()
	it("puts the report back, selected, when the player types in the text box (REP-R40)", function()
		local loaded = enterWorld(loadCore(unchartedHistory(2, FIRST)), 2)
		loaded.env.Pagle.OpenFieldReport()
		local frame = assert(box(loaded))
		local report = frame.text:GetText()

		frame.text:Type(report .. "x")
		assert.are.equal(report, frame.text:GetText())
		assert.are.same({ 0, -1 }, frame.text.highlight)
		frame.text:Type("")
		assert.are.equal(report, frame.text:GetText())
	end)

	it("puts the URL back when the player types in the URL box (REP-R40, REP-R46)", function()
		local loaded = enterWorld(loadCore(unchartedHistory(2, FIRST)), 2)
		loaded.env.Pagle.OpenFieldReport()
		local frame = assert(box(loaded))

		frame.url:Type("https://example.com")

		assert.are.equal(URL, frame.url:GetText())
		assert.are.same({ 0, -1 }, frame.url.highlight, "selected again, for Ctrl+C")
		assert.are.equal(0, frame.url:GetCursorPosition())
	end)

	it("shows the URL from its start, not scrolled to its end (REP-R40, field-report.md › UI)", function()
		local loaded = enterWorld(loadCore(unchartedHistory(2, FIRST)), 2)
		loaded.env.Pagle.OpenFieldReport()
		local frame = assert(box(loaded))
		assert.are.equal(0, frame.url:GetCursorPosition())

		frame.url:SetFocus()
		frame.url:SetCursorPosition(#URL) -- the player clicked its end, or pressed End
		frame.url:GetScript("OnEditFocusLost")(frame.url)
		assert.are.equal(0, frame.url:GetCursorPosition())

		frame.close:Click()
		loaded.client.update(FADE_OUT)
		loaded.env.Pagle.OpenFieldReport()
		assert.are.equal(0, frame.url:GetCursorPosition())
	end)

	it("closes with Esc, from the focused text box or with no box focused, and with Close (REP-R40)", function()
		local loaded = enterWorld(loadCore(unchartedHistory(2, FIRST)), 2)
		local Pagle = loaded.env.Pagle

		Pagle.OpenFieldReport()
		loaded.client.pressEscape()
		assert.is_false(box(loaded):IsShown())
		-- A hidden box keeps no keyboard focus.
		assert.is_nil(loaded.client.focus)

		Pagle.OpenFieldReport()
		box(loaded).text:ClearFocus()
		loaded.client.pressEscape()
		assert.is_false(box(loaded):IsShown())

		Pagle.OpenFieldReport()
		box(loaded).close:Click()
		loaded.client.update(FADE_OUT)
		assert.is_false(box(loaded):IsShown())
	end)

	it("hides the part controls for a one-part report (REP-R40)", function()
		local loaded = enterWorld(loadCore(unchartedHistory(2, FIRST)), 2)

		loaded.env.Pagle.OpenFieldReport()

		local frame = assert(box(loaded))
		assert.is_false(frame.partLabel:IsShown())
		assert.is_false(frame.previous:IsShown())
		assert.is_false(frame.next:IsShown())
	end)

	it("shows Part 1 of 2 with Next for a two-part report, and pages between the parts (REP-R33, REP-R40)", function()
		local loaded = enterWorld(loadCore(unchartedHistory(4, FIRST)), 2)
		-- A smaller part limit, so four rows fill two parts.
		loaded.ns.FIELD_REPORT_PART_BYTES = 200
		local parts = loaded.ns.FieldReportText(assert(loaded.ns.FieldReportRows()))
		assert.are.equal(2, #parts)

		loaded.env.Pagle.OpenFieldReport()

		local frame = assert(box(loaded))
		assert.are.equal(parts[1], frame.text:GetText())
		assert.is_true(frame.partLabel:IsShown())
		assert.are.equal("Part 1 of 2", frame.partLabel:GetText())
		assert.is_true(frame.next:IsShown())
		assert.is_true(frame.next:IsEnabled())
		assert.is_false(frame.previous:IsEnabled())

		frame.next:Click()
		assert.are.equal(parts[2], frame.text:GetText())
		assert.are.equal("Part 2 of 2", frame.partLabel:GetText())
		assert.are.same({ 0, -1 }, frame.text.highlight)
		assert.is_false(frame.next:IsEnabled())
		frame.text:Type("typed")
		assert.are.equal(parts[2], frame.text:GetText())

		frame.previous:Click()
		assert.are.equal(parts[1], frame.text:GetText())
		assert.are.equal("Part 1 of 2", frame.partLabel:GetText())
	end)

	it("always opens at part 1 (REP-R40)", function()
		local loaded = enterWorld(loadCore(unchartedHistory(4, FIRST)), 2)
		loaded.ns.FIELD_REPORT_PART_BYTES = 200
		loaded.env.Pagle.OpenFieldReport()
		box(loaded).next:Click()
		box(loaded).close:Click()

		loaded.env.Pagle.OpenFieldReport()

		assert.are.equal("Part 1 of 2", box(loaded).partLabel:GetText())
	end)

	it("isn't refreshed while it stays open (REP-R40)", function()
		local loaded = enterWorld(loadCore(unchartedHistory(2, FIRST)), 2)
		loaded.env.Pagle.OpenFieldReport()
		local frame = assert(box(loaded))
		local shown = frame.text:GetText()

		-- The client caches the item's name, so a report built now names it.
		loaded.client.itemNames[9999] = "Mystery Fish"
		local now = loaded.ns.FieldReportText(assert(loaded.ns.FieldReportRows()))[1]
		assert.truthy(now:find("Mystery Fish", 1, true))

		assert.are.equal(shown, frame.text:GetText())
	end)

	it("says Nothing to report with no text or URL when no row qualifies (REP-R41)", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }), 2)
		assert.are.same({}, loaded.ns.FieldReportRows())

		loaded.env.Pagle.OpenFieldReport()

		local frame = assert(box(loaded))
		assert.is_true(frame:IsShown())
		assert.is_true(frame.message:IsShown())
		assert.are.equal("Nothing to report. Thanks for checking!", frame.message:GetText())
		assert.is_false(frame.text:IsShown())
		assert.is_false(frame.scroll:IsShown())
		assert.is_false(frame.url:IsShown())
		assert.is_false(frame.partLabel:IsShown())
		assert.is_false(frame.next:IsShown())
	end)

	it("says Updating with no text while the projection is updating (REP-R42, REP-R91)", function()
		-- Over 500 entries, so the rebuild runs over several frames (LOG-R72), and none has run yet.
		local loaded = enterWorld(loadCore(history(600)))
		assert.is_nil(loaded.ns.FieldReportRows())

		loaded.env.Pagle.OpenFieldReport()

		local frame = assert(box(loaded))
		assert.is_true(frame.message:IsShown())
		assert.are.equal("Updating... try again in a moment.", frame.message:GetText())
		assert.is_false(frame.text:IsShown())
		assert.is_false(frame.url:IsShown())
	end)

	it("shows the text once the projection has caught up, after REP-R42's line (REP-R40, REP-R42)", function()
		local loaded = enterWorld(loadCore(unchartedHistory(600, FIRST)))
		loaded.env.Pagle.OpenFieldReport()
		local frame = assert(box(loaded))
		assert.is_true(frame.message:IsShown())
		frame.close:Click()
		for _ = 1, 20 do
			loaded.client.advance(0)
		end

		loaded.env.Pagle.OpenFieldReport()

		assert.is_false(frame.message:IsShown())
		assert.is_true(frame.text:IsShown())
		assert.is_true(frame.privacy:IsShown())
		assert.is_true(frame.url:IsShown())
		assert.are.equal(URL, frame.url:GetText())
	end)

	it("never opens on its own: catching, combat and time leave it closed (REP-R45)", function()
		local loaded = enterWorld(loadCore(unchartedHistory(2, FIRST)), 2)
		catchUncharted(loaded)
		setCombat(loaded, true)
		setCombat(loaded, false)
		loaded.client.advance(1000)

		assert.is_nil(box(loaded))
	end)
end)

describe("The Field report box's look (field-report.md › UI)", function()
	-- The atlas sprite a texture shows, by its texture coordinates.
	local function spriteName(loaded, texture)
		for atlasName, atlas in pairs(loaded.ns.ATLASES) do
			for name, sprite in pairs(atlas.sprites) do
				if
					texture.texture == atlas.file
					and texture.texCoord[1] == sprite.x / atlas.width
					and texture.texCoord[3] == sprite.y / atlas.height
				then
					return atlasName .. "/" .. name
				end
			end
		end
		return nil
	end

	it("is the sea chart with the typed slip, Ctrl+C to copy and Post it at beside the URL", function()
		local loaded = enterWorld(loadCore(unchartedHistory(2, FIRST)), 2)

		loaded.env.Pagle.OpenFieldReport()

		local frame = assert(box(loaded))
		assert.are.equal("Chart/chart", spriteName(loaded, frame.chart))
		assert.are.equal("Interface\\AddOns\\Pagle\\media\\field\\Chart", frame.chart.texture)
		assert.are.equal("Ctrl+C to copy", frame.copyHint:GetText())
		assert.is_true(frame.copyHint:IsShown())
		assert.are.equal("POST IT AT", frame.postAt:GetText())
		assert.is_true(frame.postAt:IsShown())
		-- Typed in Cutive Mono, bundled in Core's fonts.
		assert.are.same(
			{ "Interface\\AddOns\\Pagle\\media\\fonts\\CutiveMono-Regular.ttf", 12, "" },
			frame.text.fontObject.font
		)
	end)

	it("is the bare chart for a message, with no slip, hint or URL label (REP-R41)", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }), 2)

		loaded.env.Pagle.OpenFieldReport()

		local frame = assert(box(loaded))
		assert.are.equal("Chart/chart-empty", spriteName(loaded, frame.chart))
		assert.is_false(frame.copyHint:IsShown())
		assert.is_false(frame.postAt:IsShown())
		assert.is_false(frame.thumb:IsShown())
	end)

	it("greys the arrow that can't page further", function()
		local loaded = enterWorld(loadCore(unchartedHistory(4, FIRST)), 2)
		loaded.ns.FIELD_REPORT_PART_BYTES = 200

		loaded.env.Pagle.OpenFieldReport()

		local frame = assert(box(loaded))
		assert.is_true(frame.previous.art.desaturated)
		assert.is_false(frame.next.art.desaturated)
		frame.next:Click()
		assert.is_false(frame.previous.art.desaturated)
		assert.is_true(frame.next.art.desaturated)
	end)

	it("never lets POST IT AT run under the URL: a wide label is set smaller, and the URL starts after it", function()
		local ns = enterWorld(loadCore({ BUILD_ENTRY }), 2).ns

		-- It fits before the chart's URL field (from 90, 4 short): as drawn, the URL at 98.
		assert.are.same({ 1, 98 }, { ns.FieldReportUrlLine(60) })
		assert.are.same({ 1, 98 }, { ns.FieldReportUrlLine(64) })
		-- Too wide: smaller, to end at 86, the URL still at 98.
		local scale, urlX = ns.FieldReportUrlLine(80)
		assert.are.equal(0.8, scale)
		assert.are.equal(98, urlX)
		-- Wider than it can shrink: three quarters of its size, and the URL starts 6 after it.
		assert.are.same({ 0.75, 22 + 150 * 0.75 + 6 }, { ns.FieldReportUrlLine(150) })
	end)

	it("puts the URL box after the label and Close at the bottom centre, with or without parts", function()
		for _, history in ipairs({ unchartedHistory(4, FIRST), { BUILD_ENTRY } }) do
			local loaded = enterWorld(loadCore(history), 2)
			loaded.ns.FIELD_REPORT_PART_BYTES = 200

			loaded.env.Pagle.OpenFieldReport()

			local frame = assert(box(loaded))
			assert.are.same({ { "CENTER", frame, "TOP", 0, -324 } }, frame.close.points)
			assert.are.same({ { "LEFT", frame, "TOPLEFT", 98, -279 } }, frame.url.points)
			assert.are.same({ { "LEFT", frame, "TOPLEFT", 22, -324 } }, frame.previous.points)
		end
	end)

	it("closes with the brass X too, giving back the keyboard (REP-R40)", function()
		local loaded = enterWorld(loadCore(unchartedHistory(2, FIRST)), 2)
		loaded.env.Pagle.OpenFieldReport()

		box(loaded).closeCorner:Click()
		loaded.client.update(FADE_OUT)

		assert.is_false(box(loaded):IsShown())
		assert.is_nil(loaded.client.focus)
	end)

	it("scrolls the slip with the thumb and the mouse wheel, within its range (REP-R47)", function()
		local loaded = enterWorld(loadCore(unchartedHistory(2, FIRST)), 2)
		loaded.env.Pagle.OpenFieldReport()
		local frame = assert(box(loaded))

		frame.scroll.scripts.OnScrollRangeChanged(frame.scroll, 0, 100)
		assert.is_true(frame.thumb:IsShown())
		frame.scroll.scripts.OnMouseWheel(frame.scroll, -1)
		assert.are.equal(36, frame.scroll:GetVerticalScroll())
		frame.thumb:SetValue(500)
		assert.are.equal(100, frame.scroll:GetVerticalScroll())

		frame.scroll.scripts.OnScrollRangeChanged(frame.scroll, 0, 0)
		assert.is_false(frame.thumb:IsShown())
	end)
end)

describe("The Field report box's motion and sounds (field-report.md › UI)", function()
	-- The sound kits played since `from` (an index into client.sounds), as "<id> <channel>": the box's own, never a
	-- sound set's files.
	local function soundKits(loaded, from)
		local played = {}
		for i = (from or 0) + 1, #loaded.client.sounds do
			local sound = loaded.client.sounds[i]
			if sound:find("^%d+ ") then
				played[#played + 1] = sound
			end
		end
		return played
	end

	-- The box open on a two-part report, and how many sounds had played before it opened.
	local function opened()
		local loaded = enterWorld(loadCore(unchartedHistory(4, FIRST)), 2)
		loaded.ns.FIELD_REPORT_PART_BYTES = 200
		local before = #loaded.client.sounds
		loaded.env.Pagle.OpenFieldReport()
		return loaded, assert(box(loaded)), before
	end

	it("fades in over 0.2 s as it opens, with IG_MAINMENU_OPEN on the SFX channel", function()
		local loaded, frame, before = opened()

		assert.are.equal(0, frame:GetAlpha())
		assert.are.same({ "850 SFX" }, soundKits(loaded, before))
		loaded.client.update(0.1)
		assert.is_true(frame:GetAlpha() > 0.5 and frame:GetAlpha() < 1)
		loaded.client.update(0.15)
		assert.are.equal(1, frame:GetAlpha())
	end)

	it("plays IG_MAINMENU_OPTION for Close and the arrows, and fades out over 0.15 s with IG_MAINMENU_CLOSE", function()
		local loaded, frame, before = opened()
		loaded.client.update(0.25)

		frame.next:Click()
		frame.close:Click()
		frame.close:Click()

		assert.are.same({ "850 SFX", "852 SFX", "852 SFX", "851 SFX" }, soundKits(loaded, before))
		-- The keyboard given back at once.
		assert.is_nil(loaded.client.focus)
		assert.is_true(frame:IsShown())
		loaded.client.update(0.1)
		assert.is_true(frame:GetAlpha() > 0 and frame:GetAlpha() < 1)
		loaded.client.update(0.1)
		assert.is_false(frame:IsShown())
		assert.are.equal(1, frame:GetAlpha(), "left at rest for its next opening")
		assert.are.same({ "850 SFX", "852 SFX", "852 SFX", "851 SFX" }, soundKits(loaded, before))
	end)

	it("closes from the brass X with IG_MAINMENU_CLOSE alone, and from Esc at once with it", function()
		local loaded, frame, before = opened()
		frame.closeCorner:Click()
		loaded.client.update(FADE_OUT)
		loaded.env.Pagle.OpenFieldReport()
		frame.text:ClearFocus()

		loaded.client.pressEscape()

		assert.is_false(frame:IsShown())
		assert.are.same({ "850 SFX", "851 SFX", "850 SFX", "851 SFX" }, soundKits(loaded, before))
	end)

	it("fades back in, at part 1, when opened again while it fades out", function()
		local loaded, frame = opened()
		loaded.client.update(0.25)
		frame.next:Click()
		frame.close:Click()
		loaded.client.update(0.05)

		loaded.env.Pagle.OpenFieldReport()
		loaded.client.update(0.25)

		assert.is_true(frame:IsShown())
		assert.are.equal(1, frame:GetAlpha())
		assert.are.equal("Part 1 of 2", frame.partLabel:GetText())
		assert.are.equal(frame.text, loaded.client.focus)
	end)

	it("shows and hides at once with the Animations setting off, its sounds still playing", function()
		local loaded = enterWorld(loadCore(unchartedHistory(2, FIRST)), 2)
		loaded.ns.db.profile.announcements.motion = false
		local before = #loaded.client.sounds

		loaded.env.Pagle.OpenFieldReport()
		local frame = assert(box(loaded))
		assert.are.equal(1, frame:GetAlpha())
		frame.close:Click()

		assert.is_false(frame:IsShown())
		assert.are.same({ "850 SFX", "852 SFX", "851 SFX" }, soundKits(loaded, before))
	end)
end)

describe("The Field report box's size (REP-R47)", function()
	-- The box opened over `rows` Casts in Darkshore, each of an Uncharted item no catalogue will have, so it shows one
	-- I row each (REP-R10, REP-R20).
	local function opened(rows)
		local entries = { BUILD_ENTRY }
		for i = 1, rows do
			entries[#entries + 1] = castEntry(FIRST + i, 900000 + i, 0)
		end
		local loaded = enterWorld(loadCore(entries), 2)
		loaded.env.Pagle.OpenFieldReport()
		local frame = assert(box(loaded))
		local _, shown = frame.text:GetText():gsub("\nI ", "")
		assert.are.equal(rows, shown)
		return frame
	end

	it("is 520 × 360 and centred, whether the report has 1 row or 300, and the text scrolls inside it", function()
		for _, rows in ipairs({ 1, 300 }) do
			local frame = opened(rows)

			assert.are.same({ 520, 360 }, { frame:GetSize() }, rows .. " rows")
			assert.are.same({ { "CENTER" } }, frame.points, "anchored only at its centre, never over the screen")
			assert.are.equal(frame.text, frame.scroll.scrollChild, "the text scrolls in the scroll frame")
			-- The slip sits inside the box, between the privacy line and the URL.
			assert.are.same({ 426, 156 }, { frame.scroll:GetSize() })
		end
	end)
end)

describe("The compartment menu's Help chart the waters entry (CORE-R50, REP-R43)", function()
	it("reads Help chart the waters (3) at a count of 3, between the Curio Shop and Settings (CORE-R50)", function()
		local loaded = enterWorld(loadCore(unchartedHistory(2, FIRST)), 2)
		assert.are.equal(3, loaded.env.Pagle.GetFieldReportCount())

		local texts = loaded.client.openCompartmentMenu("Pagle").texts()

		assert.are.same({ "Help chart the waters (3)", "Settings" }, { texts[#texts - 1], texts[#texts] })
		assert.truthy(texts[#texts - 2]:find("^Curio Shop"))
	end)

	it("reads Help chart the waters at a count of 0 (CORE-R50)", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }), 2)
		assert.are.equal(0, loaded.env.Pagle.GetFieldReportCount())

		local texts = loaded.client.openCompartmentMenu("Pagle").texts()

		assert.are.equal("Help chart the waters", texts[#texts - 1])
	end)

	it("opens the box at part 1 with the text selected and the URL below it (REP-R40, REP-R43)", function()
		local loaded = enterWorld(loadCore(unchartedHistory(2, FIRST)), 2)

		loaded.client.openCompartmentMenu("Pagle").click("Help chart the waters (3)")

		local frame = assert(box(loaded))
		assert.is_true(frame:IsShown())
		assert.are.equal(frame.text, loaded.client.focus)
		assert.are.same({ 0, -1 }, frame.text.highlight)
		assert.are.equal(URL, frame.url:GetText())
	end)

	it("prints REP-R44's line while restricted and opens nothing (REP-R44, CORE-R33)", function()
		local loaded = enterWorld(loadCore(unchartedHistory(2, FIRST)), 2)
		setCombat(loaded, true)

		loaded.client.openCompartmentMenu("Pagle").click("Help chart the waters (3)")

		assert.is_nil(box(loaded))
		assert.are.same({ "Pagle: the Field report opens after combat." }, loaded.printed)
	end)
end)

-- The Settings root's Help chart the waters rows, as the panel shows them now: the header and the button row.
local function reportRows(loaded)
	local rows = loaded.client.settings.show(assert(loaded.client.settings.category("Pagle")))
	for i, row in ipairs(rows) do
		if row.initializer:GetName() == "Help chart the waters" then
			return row, rows[i + 1]
		end
	end
	error("no Help chart the waters header on the root")
end

describe("The Settings root's Help chart the waters section (SET-R10)", function()
	it(
		"has the header and the Field report row after Getting started, before Saving, with SET-R10's tooltip"
			.. " (CORE-R40, SET-R10)",
		function()
			local loaded = enterWorld(loadCore(unchartedHistory(2, FIRST)), 2)

			local names = {}
			for i, row in ipairs(loaded.client.settings.show(assert(loaded.client.settings.category("Pagle")))) do
				names[i] = row.initializer:GetName() or loaded.client.settings.textsOf(row.frame)[1]
			end
			local _, button = reportRows(loaded)

			-- Getting started's last row, for this returning Angler: Margin notes, as it has no First evening list
			-- (SET-R10 rows 4–6, ONB-R81).
			local header = "Help chart the waters"
			local found = false
			for i, name in ipairs(names) do
				if name == header then
					found = true
					assert.are.same(
						{ "Margin notes", header, "Field report", "Saving" },
						{ names[i - 1], names[i], names[i + 1], names[i + 2] }
					)
				end
			end
			assert.is_true(found)
			assert.are.equal(
				"Copy what you've caught that Pagle's data doesn't know yet, and paste it into the issue form.",
				button.initializer:GetTooltip()
			)
			assert.are.same({ "FIELD REPORT", "OPEN FIELD REPORT" }, button.initializer.searchTags)
		end
	)

	it("labels the button with the count, read each time the root is shown (SET-R10, SET-R12)", function()
		local loaded = enterWorld(loadCore(unchartedHistory(2, FIRST)), 2)
		local Pagle = loaded.env.Pagle

		local _, button = reportRows(loaded)
		assert.are.same({ "Field report", "Open Field report (3)" }, loaded.client.settings.textsOf(button.frame))

		Pagle.GetFieldReportCount = function()
			return 0
		end
		_, button = reportRows(loaded)
		assert.are.same({ "Field report", "Open Field report" }, loaded.client.settings.textsOf(button.frame))
	end)

	it("closes the Settings panel first, then opens the box (SET-R12, REP-R43)", function()
		local loaded = enterWorld(loadCore(unchartedHistory(2, FIRST)), 2)
		local Pagle = loaded.env.Pagle
		local open = Pagle.OpenFieldReport
		local panelShownAtOpen
		Pagle.OpenFieldReport = function()
			panelShownAtOpen = loaded.client.settings.panel:IsShown()
			open()
		end
		Pagle.OpenSettings()
		local _, button = reportRows(loaded)

		loaded.client.settings.buttonsOf(button.frame)[1]:Click()

		assert.is_false(panelShownAtOpen)
		assert.is_true(assert(box(loaded)):IsShown())
	end)

	it("closes the panel and prints REP-R44's line while restricted (SET-R12, REP-R44)", function()
		local loaded = enterWorld(loadCore(unchartedHistory(2, FIRST)), 2)
		loaded.env.Pagle.OpenSettings()
		local _, button = reportRows(loaded)
		setCombat(loaded, true)

		loaded.client.settings.buttonsOf(button.frame)[1]:Click()

		assert.is_false(loaded.client.settings.panel:IsShown())
		assert.is_nil(box(loaded))
		assert.are.same({ "Pagle: the Field report opens after combat." }, loaded.printed)
	end)
end)

describe("Pagle.OpenFieldReport while restricted (REP-R44, CORE-R33)", function()
	it("prints the chat line and opens nothing (REP-R44, CORE-R33, REP-R93)", function()
		local loaded = enterWorld(loadCore(unchartedHistory(2, FIRST)), 2)
		setCombat(loaded, true)

		loaded.env.Pagle.OpenFieldReport()

		assert.is_nil(box(loaded))
		assert.are.same({ "Pagle: the Field report opens after combat." }, loaded.printed)
	end)

	it("leaves a box already open as it is, on its part (REP-R44, CORE-R33, REP-R93)", function()
		local loaded = enterWorld(loadCore(unchartedHistory(4, FIRST)), 2)
		loaded.ns.FIELD_REPORT_PART_BYTES = 200
		loaded.env.Pagle.OpenFieldReport()
		local frame = assert(box(loaded))
		frame.next:Click()

		setCombat(loaded, true)
		loaded.env.Pagle.OpenFieldReport()

		assert.is_true(frame:IsShown())
		assert.are.equal("Part 2 of 2", frame.partLabel:GetText())
		assert.are.same({ "Pagle: the Field report opens after combat." }, loaded.printed)
	end)
end)
