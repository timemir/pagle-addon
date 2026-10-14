-- The Field report box and its entry points (field-report.md › Privacy, › The box and its entry points; REP-R37,
-- REP-R40–R46, REP-R93; CORE-R33, CORE-R40, CORE-R50, CORE-R61; settings.md SET-R10, SET-R12).

local URL = "https://github.com/timemir/wow-fish/issues/new?template=field-report.yml"

-- Entry `i` of a saved log: a Cast by Ada in Darkshore (148, subzone 0) at realm 08:14, Fishing 86+25, catching
-- `item`, which no catalogue has, so it is Uncharted and makes an I row (REP-R10, REP-R20).
local function uncharted(i, item)
	return ("C1|1|%d|0|c|494|1439|1|148|0|86|25|263|||%dx1"):format(1791731000 + i, item)
end

-- A log of `items` Uncharted Catches, one item each (9999, 9998, …), after the build entry the fake client matches.
local function unchartedLog(items)
	local entries = { BUILD_ENTRY }
	for i = 1, items do
		entries[#entries + 1] = uncharted(i, 10000 - i)
	end
	return entries
end

-- Core over a saved log holding `entries`, logged in, in the world, with its projections caught up.
local function ready(entries)
	return enterWorld(loadCore(entries), 2)
end

-- The box Core drew, or nil before the first opening.
local function box(loaded)
	return loaded.ns.fieldReportBox
end

describe("Pagle.OpenFieldReport", function()
	it(
		"opens the box titled Help chart the waters, the privacy line above the report text, selected, and the issue"
			.. " form URL below it (REP-R37, REP-R40, REP-R46)",
		function()
			local loaded = ready(unchartedLog(2))
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

-- Presses Esc as the client does: the focused edit box takes it (OnEscapePressed); with none focused,
-- CloseSpecialWindows hides every shown frame named in UISpecialFrames.
local function escape(loaded)
	local focus = loaded.client.focus
	local onEscape = focus and focus:GetScript("OnEscapePressed")
	if onEscape then
		onEscape(focus)
		return
	end
	local frame = box(loaded)
	for _, name in ipairs(loaded.env.UISpecialFrames) do
		if frame and name == frame.name and frame:IsShown() then
			frame:Hide()
			local onHide = frame:GetScript("OnHide")
			if onHide then
				onHide(frame)
			end
		end
	end
end

-- A caught Cast of an item no catalogue has, on the fake client.
local function catchUncharted(loaded)
	catchOne(loaded, { { link = "|cffffffff|Hitem:9990::::::::15:::::::::|h[Mystery]|h|r", quantity = 1 } })
	loaded.client.advance(0)
end

describe("The Field report box", function()
	it("puts the report back, selected, when the player types in the text box (REP-R40)", function()
		local loaded = ready(unchartedLog(2))
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
		local loaded = ready(unchartedLog(2))
		loaded.env.Pagle.OpenFieldReport()
		local frame = assert(box(loaded))

		frame.url:Type("https://example.com")

		assert.are.equal(URL, frame.url:GetText())
	end)

	it("closes with Esc, from the focused text box or with no box focused, and with Close (REP-R40)", function()
		local loaded = ready(unchartedLog(2))
		local Pagle = loaded.env.Pagle

		Pagle.OpenFieldReport()
		escape(loaded)
		assert.is_false(box(loaded):IsShown())
		-- A hidden box keeps no keyboard focus.
		assert.is_nil(loaded.client.focus)

		Pagle.OpenFieldReport()
		box(loaded).text:ClearFocus()
		escape(loaded)
		assert.is_false(box(loaded):IsShown())

		Pagle.OpenFieldReport()
		box(loaded).close:Click()
		assert.is_false(box(loaded):IsShown())
	end)

	it("hides the part controls for a one-part report (REP-R40)", function()
		local loaded = ready(unchartedLog(2))

		loaded.env.Pagle.OpenFieldReport()

		local frame = assert(box(loaded))
		assert.is_false(frame.partLabel:IsShown())
		assert.is_false(frame.previous:IsShown())
		assert.is_false(frame.next:IsShown())
	end)

	it("shows Part 1 of 2 with Next for a two-part report, and pages between the parts (REP-R33, REP-R40)", function()
		local loaded = ready(unchartedLog(4))
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
		local loaded = ready(unchartedLog(4))
		loaded.ns.FIELD_REPORT_PART_BYTES = 200
		loaded.env.Pagle.OpenFieldReport()
		box(loaded).next:Click()
		box(loaded).close:Click()

		loaded.env.Pagle.OpenFieldReport()

		assert.are.equal("Part 1 of 2", box(loaded).partLabel:GetText())
	end)

	it("isn't refreshed while it stays open (REP-R40)", function()
		local loaded = ready(unchartedLog(2))
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
		local loaded = ready({ BUILD_ENTRY })
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
		assert.are.equal("Updating… try again in a moment.", frame.message:GetText())
		assert.is_false(frame.text:IsShown())
		assert.is_false(frame.url:IsShown())
	end)

	it("shows the text once the projection has caught up, after REP-R42's line (REP-R40, REP-R42)", function()
		local loaded = enterWorld(loadCore(unchartedLog(600)))
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
		local loaded = ready(unchartedLog(2))
		catchUncharted(loaded)
		setCombat(loaded, true)
		setCombat(loaded, false)
		loaded.client.advance(1000)

		assert.is_nil(box(loaded))
	end)
end)

-- Clicks Pagle in the Addon Compartment and returns the menu Core opens on the next frame.
local function compartmentMenu(loaded)
	local opened = #loaded.client.menus
	loaded.client.clickCompartment("Pagle")
	loaded.client.runTimers()
	return assert(loaded.client.menus[opened + 1])
end

describe("The compartment menu's Help chart the waters entry", function()
	it("reads Help chart the waters (3) at a count of 3, between the Curio Shop and Settings (CORE-R50)", function()
		local loaded = ready(unchartedLog(2))
		assert.are.equal(3, loaded.env.Pagle.GetFieldReportCount())

		local texts = compartmentMenu(loaded).texts()

		assert.are.same({ "Help chart the waters (3)", "Settings" }, { texts[#texts - 1], texts[#texts] })
		assert.truthy(texts[#texts - 2]:find("^Curio Shop"))
	end)

	it("reads Help chart the waters at a count of 0 (CORE-R50)", function()
		local loaded = ready({ BUILD_ENTRY })
		assert.are.equal(0, loaded.env.Pagle.GetFieldReportCount())

		local texts = compartmentMenu(loaded).texts()

		assert.are.equal("Help chart the waters", texts[#texts - 1])
	end)

	it("opens the box at part 1 with the text selected and the URL below it (REP-R40, REP-R43)", function()
		local loaded = ready(unchartedLog(2))

		compartmentMenu(loaded).click("Help chart the waters (3)")

		local frame = assert(box(loaded))
		assert.is_true(frame:IsShown())
		assert.are.equal(frame.text, loaded.client.focus)
		assert.are.same({ 0, -1 }, frame.text.highlight)
		assert.are.equal(URL, frame.url:GetText())
	end)

	it("prints REP-R44's line while restricted and opens nothing (REP-R44, CORE-R33)", function()
		local loaded = ready(unchartedLog(2))
		setCombat(loaded, true)

		compartmentMenu(loaded).click("Help chart the waters (3)")

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

describe("The Settings root's Help chart the waters section", function()
	it(
		"has the header and the Field report row after the Modules note, before Saving, with SET-R10's tooltip"
			.. " (CORE-R40, SET-R10)",
		function()
			local loaded = ready(unchartedLog(2))

			local names = {}
			for i, row in ipairs(loaded.client.settings.show(assert(loaded.client.settings.category("Pagle")))) do
				names[i] = row.initializer:GetName() or loaded.client.settings.textsOf(row.frame)[1]
			end
			local _, button = reportRows(loaded)

			local note = "Turn Modules on or off in the AddOns list."
			for i, name in ipairs(names) do
				if name == note then
					assert.are.same(
						{ note, "Help chart the waters", "Field report", "Saving" },
						{ names[i], names[i + 1], names[i + 2], names[i + 3] }
					)
				end
			end
			assert.are.equal(
				"Copy what you've caught that Pagle's data doesn't know yet, and paste it into the issue form.",
				button.initializer:GetTooltip()
			)
			assert.are.same({ "FIELD REPORT", "OPEN FIELD REPORT" }, button.initializer.searchTags)
		end
	)

	it("labels the button with the count, read each time the root is shown (SET-R10, SET-R12)", function()
		local loaded = ready(unchartedLog(2))
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
		local loaded = ready(unchartedLog(2))
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
		local loaded = ready(unchartedLog(2))
		loaded.env.Pagle.OpenSettings()
		local _, button = reportRows(loaded)
		setCombat(loaded, true)

		loaded.client.settings.buttonsOf(button.frame)[1]:Click()

		assert.is_false(loaded.client.settings.panel:IsShown())
		assert.is_nil(box(loaded))
		assert.are.same({ "Pagle: the Field report opens after combat." }, loaded.printed)
	end)
end)

describe("Pagle.OpenFieldReport while restricted", function()
	it("prints the chat line and opens nothing (REP-R44, CORE-R33, REP-R93)", function()
		local loaded = ready(unchartedLog(2))
		setCombat(loaded, true)

		loaded.env.Pagle.OpenFieldReport()

		assert.is_nil(box(loaded))
		assert.are.same({ "Pagle: the Field report opens after combat." }, loaded.printed)
	end)

	it("leaves a box already open as it is, on its part (REP-R44, CORE-R33, REP-R93)", function()
		local loaded = ready(unchartedLog(4))
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
