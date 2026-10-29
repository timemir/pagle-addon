-- The export window and its entry points (paste-string.md PST-R20–R23, PST-R30–R33, PST-R40, PST-R50–R53, PST-R60;
-- CORE-R33, CORE-R61, SET-R10 row 12, SET-R12), through the real TOC, the vendored LibDeflate and the fake client.

local FIRST = SERVER_TIME - 700 -- the history's Casts are at FIRST + 1, + 2, …
local LOG_ID = "3f9a2c1e7b0d4a65"
local URL = "https://pagle.app/me/paste"

-- Types `/pagle <msg>` in chat.
local function pagle(loaded, msg)
	loaded.env.SlashCmdList.PAGLE(msg)
end

-- The window Core drew, or nil before the first opening.
local function window(loaded)
	return loaded.ns.pasteExportWindow
end

-- Long enough for the window's fade out (0.15 s) to end and hide it.
local FADE_OUT = 0.2

-- Core logged in over `n` of Ada's Casts (and the build entry after them, LOG-R36).
local function withCasts(n)
	return enterWorld(loadCore(history(n, FIRST)), 2)
end

-- The document a Paste string holds, read back with the vendored LibDeflate (UPL-R50).
local function unpaste(loaded, paste)
	local LibDeflate = loaded.env.LibStub("LibDeflate")
	assert.are.equal("!PGL2!", paste:sub(1, 6))
	assert(paste:sub(7):match("^[a-zA-Z0-9()]+$"), "one unbroken run of the print alphabet")
	return assert(LibDeflate:DecompressDeflate(assert(LibDeflate:DecodeForPrint(paste:sub(7)))))
end

-- The header's fields and the entry lines of `document` (UPL Contracts › The upload document).
local function read(document)
	local lines = {}
	for line in document:gmatch("([^\n]*)\n") do
		lines[#lines + 1] = line
	end
	local header = {}
	for field in (lines[1] .. "|"):gmatch("([^|]*)|") do
		header[#header + 1] = field
	end
	local chars = tonumber(header[7])
	local entries = {}
	for i = 2 + chars, #lines do
		entries[#entries + 1] = lines[i]
	end
	return {
		asOf = tonumber(header[5]),
		total = tonumber(header[6]),
		from = tonumber(header[8]),
		anchor = header[9],
		count = tonumber(header[10]),
		entries = entries,
	}
end

-- Ctrl+C (or, with `meta`, Cmd+C) pressed in the window's string box.
local function copy(loaded, meta)
	local key = meta and "META" or "CTRL"
	loaded.client.keysDown[key] = true
	local frame = assert(window(loaded))
	frame.paste:GetScript("OnKeyDown")(frame.paste, "C")
	loaded.client.keysDown[key] = nil
end

-- PagleDB.global.pasteExports, the last exported seq of each log (PST-R40).
local function marks(loaded)
	return loaded.ns.db.global.pasteExports
end

describe("/pagle export and Pagle.OpenPasteExport (PST-R50, PST-R51, CORE-R61)", function()
	it(
		"open the window on New since last export, part 1's Paste string selected and focused, with its lines and"
			.. " the Paste upload page",
		function()
			local loaded = withCasts(3)
			local log = loaded.ns.catchLog.data

			pagle(loaded, "export")

			local frame = assert(window(loaded))
			assert.is_true(frame:IsShown())
			assert.are.equal("Export for the website", frame.title:GetText())
			assert.are.equal(
				"Holds your characters' names. Paste it only on the Pagle website.",
				frame.privacy:GetText()
			)
			assert.are.equal("Ctrl+C to copy", frame.copyHint:GetText())
			assert.are.equal("• New since last export", frame.choices.new.label:GetText())
			assert.are.equal("Everything", frame.choices.everything.label:GetText())

			local document = read(unpaste(loaded, frame.paste:GetText()))
			local total = log.count
			assert.are.equal(1, document.from, "no mark yet, so from the start (PST-R21)")
			assert.are.equal(total, document.total)
			assert.are.same(logEntries(log), document.entries)
			assert.are.equal(loaded.env.GetServerTime(), document.asOf, "GetServerTime() as it opened (PST-R20)")
			assert.are.equal(frame.paste, loaded.client.focus, "focused, so Ctrl+C copies it")
			assert.are.same({ 0, -1 }, frame.paste.highlight, "all of it selected")
			local size = math.ceil(#frame.paste:GetText() / 1024)
			assert.are.equal(("Entries 1–%d of %d  ·  %d KB"):format(total, total, size), frame.line:GetText())
			assert.is_false(frame.note:IsShown())
			assert.is_false(frame.partLabel:IsShown())
			assert.is_false(frame.next:IsShown())
			assert.are.equal("PASTE IT AT", frame.pasteAt:GetText())
			assert.are.equal(URL, frame.url:GetText())
			assert.are.equal(0, frame.url:GetCursorPosition(), "from https://")
			assert.is_false(frame.message:IsShown())
			assert.are.same({}, loaded.printed)
		end
	)

	it("keeps the string on one line, never wrapped (PST-R31)", function()
		local loaded = withCasts(3)

		pagle(loaded, "export")

		local frame = assert(window(loaded))
		assert.is_false(frame.paste:IsMultiLine())
		assert.falsy(frame.paste:GetText():find("%s"))
	end)

	it("puts the string back, selected, when the player types in its box (PST-R51)", function()
		local loaded = withCasts(3)
		pagle(loaded, "export")
		local frame = assert(window(loaded))
		local paste = frame.paste:GetText()

		frame.paste:Type(paste .. " x")

		assert.are.equal(paste, frame.paste:GetText())
		assert.are.same({ 0, -1 }, frame.paste.highlight)
	end)

	it("closes with Esc and with Close, giving back the keyboard (PST-R51)", function()
		local loaded = withCasts(3)

		pagle(loaded, "export")
		loaded.client.pressEscape()
		assert.is_false(window(loaded):IsShown())
		assert.is_nil(loaded.client.focus)

		pagle(loaded, "export")
		window(loaded).close:Click()
		loaded.client.update(FADE_OUT)
		assert.is_false(window(loaded):IsShown())
	end)

	it("print PST-R50's line while restricted, opening nothing, and leave a window already open (CORE-R33)", function()
		local loaded = withCasts(3)
		setCombat(loaded, true)

		pagle(loaded, "export")

		assert.is_nil(window(loaded))
		assert.are.same({ "Pagle: the export window opens after combat." }, loaded.printed)

		setCombat(loaded, false)
		loaded.env.Pagle.OpenPasteExport()
		setCombat(loaded, true)
		loaded.env.Pagle.OpenPasteExport()
		assert.is_true(window(loaded):IsShown())
	end)
end)

describe("The export window's parts (PST-R22, PST-R32, PST-R33)", function()
	it("shows a cheap single-part export immediately while preparation stays within its frame budget", function()
		local loaded = withCasts(130)
		pagle(loaded, "export")
		local frame = assert(window(loaded))
		assert.is_true(frame.paste:IsShown())
		assert.are.equal(loaded.ns.catchLog.data.count, read(unpaste(loaded, frame.paste:GetText())).count)
	end)

	it("prepares long prefixes across frames and retains the captured export while fishing continues", function()
		local loaded = withCasts(130)
		local profile = 0
		loaded.env.debugprofilestop = function()
			profile = profile + 0.125
			return profile
		end
		local log = loaded.ns.catchLog.data
		local total = log.count
		marks(loaded)[LOG_ID] = total - 1
		pagle(loaded, "export")
		local frame = assert(window(loaded))
		assert.is_true(frame.message:IsShown())
		assert.are.equal("Preparing your Paste string…", frame.message:GetText())
		assert.is_false(frame.paste:IsShown())
		loaded.ns.LogBlocks.Append(loaded.ns.catchLog.data, "S1|1|" .. SERVER_TIME .. "|99|150|150|0")
		loaded.ns.catchLog.data.characters[1].name = "Changed"
		loaded.client.advance(5)
		for _ = 1, 20 do
			loaded.client.update(0.016)
			if frame.paste:IsShown() then
				break
			end
		end
		local raw = unpaste(loaded, frame.paste:GetText())
		local document = read(raw)
		assert.are.equal(total, document.total)
		assert.are.equal(total, document.from)
		assert.are.equal(1, document.count)
		assert.is_nil(raw:find("Changed", 1, true))
		assert.are.equal(SERVER_TIME, document.asOf)
		copy(loaded)
		assert.are.equal(total, marks(loaded)[LOG_ID])
	end)

	it("shows Part 1 of k, pages between the parts, and every part shares the as-of and the total", function()
		local loaded = withCasts(3)
		loaded.ns.PASTE_PART_ENTRIES = 2
		local log = loaded.ns.catchLog.data
		assert.are.equal(5, log.count, "3 Casts, the build entry and login's Skill Reading")

		pagle(loaded, "export")

		local frame = assert(window(loaded))
		assert.are.equal("Part 1 of 3", frame.partLabel:GetText())
		assert.is_true(frame.next:IsEnabled())
		assert.is_false(frame.previous:IsEnabled())
		assert.is_true(frame.note:IsShown())
		assert.are.equal("Paste each part on its own, in order.", frame.note:GetText())

		local rebuilt, asOf = {}, nil
		for n = 1, 3 do
			if n > 1 then
				frame.next:Click()
			end
			assert.are.equal(("Part %d of 3"):format(n), frame.partLabel:GetText())
			assert.are.same({ 0, -1 }, frame.paste.highlight)
			local document = read(unpaste(loaded, frame.paste:GetText()))
			asOf = asOf or document.asOf
			assert.are.equal(asOf, document.asOf)
			assert.are.equal(5, document.total)
			assert.are.equal(2 * n - 1, document.from)
			for _, entry in ipairs(document.entries) do
				rebuilt[#rebuilt + 1] = entry
			end
		end
		assert.are.same(logEntries(log), rebuilt)
		assert.is_false(frame.next:IsEnabled())
		frame.previous:Click()
		assert.are.equal("Part 2 of 3", frame.partLabel:GetText())
	end)

	it("compresses a part only once it shows, and once (PST-R33)", function()
		local loaded = withCasts(4)
		loaded.ns.PASTE_PART_ENTRIES = 2
		local LibDeflate = loaded.env.LibStub("LibDeflate")
		local compress, calls = LibDeflate.CompressDeflate, 0
		LibDeflate.CompressDeflate = function(...)
			calls = calls + 1
			return compress(...)
		end

		pagle(loaded, "export")
		assert.are.equal(1, calls)
		local frame = assert(window(loaded))
		frame.next:Click()
		frame.previous:Click()
		assert.are.equal(2, calls)
		LibDeflate.CompressDeflate = compress
	end)
end)

describe("The last exported seq (PST-R21, PST-R40)", function()
	it("rises to a part's last seq on Ctrl+C or Cmd+C in its box, and only then", function()
		local loaded = withCasts(4)
		loaded.ns.PASTE_PART_ENTRIES = 2
		pagle(loaded, "export")
		local frame = assert(window(loaded))

		assert(marks(loaded)[LOG_ID] == nil, "showing a part doesn't mark it")
		frame.paste:GetScript("OnKeyDown")(frame.paste, "C")
		assert(marks(loaded)[LOG_ID] == nil, "C alone isn't a copy")

		copy(loaded)
		assert.are.equal(2, marks(loaded)[LOG_ID])
		frame.next:Click()
		copy(loaded, true)
		assert.are.equal(4, marks(loaded)[LOG_ID])
		frame.previous:Click()
		copy(loaded)
		assert.are.equal(4, marks(loaded)[LOG_ID], "it never falls")
	end)

	it("starts New since last export after the mark, and says Nothing new once every entry was copied", function()
		local loaded = withCasts(4)
		local total = loaded.ns.catchLog.data.count
		pagle(loaded, "export")
		copy(loaded)
		assert.are.equal(total, marks(loaded)[LOG_ID])
		window(loaded).close:Click()
		loaded.client.update(FADE_OUT)

		pagle(loaded, "export")
		local frame = assert(window(loaded))
		assert.is_true(frame.message:IsShown())
		assert.are.equal("Nothing new since your last export.", frame.message:GetText())
		assert.is_false(frame.paste:IsShown())
		assert.is_false(frame.url:IsShown())
		assert.is_false(frame.partLabel:IsShown())
		assert(frame.choices.everything:IsShown(), "the choices stay")

		catchOne(loaded)
		loaded.client.advance(0)
		frame.close:Click()
		loaded.client.update(FADE_OUT)
		pagle(loaded, "export")
		local document = read(unpaste(loaded, frame.paste:GetText()))
		assert.are.equal(total + 1, document.from)
		assert.are.equal(1, document.count)
		assert.are.equal(logEntries(loaded.ns.catchLog.data)[total + 1], document.entries[1])
		assert(document.anchor:match("^[0-9a-f]+$") and #document.anchor == 64, "anchored to prefix content")
	end)

	it(
		"exports from 1 for Everything, whatever the mark, and back to New since on the other choice (PST-R51)",
		function()
			local loaded = withCasts(4)
			local total = loaded.ns.catchLog.data.count
			pagle(loaded, "export")
			copy(loaded)
			local frame = assert(window(loaded))

			frame.choices.everything:Click()
			assert.are.equal("• Everything", frame.choices.everything.label:GetText())
			assert.are.equal("New since last export", frame.choices.new.label:GetText())
			local document = read(unpaste(loaded, frame.paste:GetText()))
			assert.are.equal(1, document.from)
			assert.are.equal(total, document.count)

			local shown = frame.paste:GetText()
			frame.choices.everything:Click()
			assert.are.equal(shown, frame.paste:GetText(), "picking the choice shown changes nothing")

			frame.choices.new:Click()
			assert.are.equal("Nothing new since your last export.", frame.message:GetText())
		end
	)

	it("keeps another log's mark (PST-R40)", function()
		local loaded = withCasts(2)
		marks(loaded)["0123456789abcdef"] = 40
		pagle(loaded, "export")
		copy(loaded)

		assert.are.equal(40, marks(loaded)["0123456789abcdef"])
		assert.are.equal(loaded.ns.catchLog.data.count, marks(loaded)[LOG_ID])
	end)
end)

describe("A log Core can't export (PST-R15)", function()
	it("says Pagle can't export this Catch log instead of a string, and marks nothing", function()
		local log = savedLog(history(2, FIRST))
		log.characters[1].guid = "Player-4618-not-hex"
		local loaded = enterWorld(loadCore(log), 2)
		-- Login adds the fake client's character, whose GUID is fine: break the first one only.
		loaded.ns.catchLog.data.characters[1].guid = "Player-4618-not-hex"

		pagle(loaded, "export")

		local frame = assert(window(loaded))
		assert.are.equal("Pagle can't export this Catch log.", frame.message:GetText())
		assert.is_false(frame.paste:IsShown())
		copy(loaded)
		assert.is_nil(marks(loaded)[LOG_ID])
	end)
end)

-- The root's Pagle website section (SET-R10 rows 11 and 12): its header row and the rows after it.
local function websiteRows(loaded)
	local rows = loaded.client.settings.show(assert(loaded.client.settings.category("Pagle")))
	for i, row in ipairs(rows) do
		if row.initializer:GetName() == "Pagle website" then
			return rows[i + 1], rows[i + 2]
		end
	end
	error("no Pagle website header on the root")
end

describe("The Settings root's export button (SET-R10 row 12, SET-R12)", function()
	it("is Catch log, Copy for the website, after Show other Anglers on player tooltips", function()
		local loaded = withCasts(2)
		local tooltips, button = websiteRows(loaded)

		assert.are.equal("Show other Anglers on player tooltips", tooltips.initializer:GetName())
		assert.are.same({ "Catch log", "Copy for the website" }, loaded.client.settings.textsOf(button.frame))
		assert.are.equal(
			"Copy your Catch log as a Paste string, to paste on the Pagle website without the Companion.",
			button.initializer:GetTooltip()
		)
	end)

	it("closes the Settings panel first, then opens the window", function()
		local loaded = withCasts(2)
		local Pagle = loaded.env.Pagle
		local open = Pagle.OpenPasteExport
		local panelShownAtOpen
		Pagle.OpenPasteExport = function()
			panelShownAtOpen = loaded.client.settings.panel:IsShown()
			open()
		end
		Pagle.OpenSettings()
		local _, button = websiteRows(loaded)

		loaded.client.settings.buttonsOf(button.frame)[1]:Click()

		assert.is_false(panelShownAtOpen)
		assert.is_true(assert(window(loaded)):IsShown())
	end)
end)

describe("/pagle dev pastetest (PST-R60)", function()
	it("shows a test string of that many KB in the window, with no choice picked, and marks nothing", function()
		local loaded = withCasts(2)
		pagle(loaded, "dev on")

		pagle(loaded, "dev pastetest 64")

		local frame = assert(window(loaded))
		assert.are.equal(64 * 1024, #frame.paste:GetText())
		assert.are.equal("(00000000PGLtest", frame.paste:GetText():sub(1, 16))
		assert.are.equal("Copy test: 64 KB", frame.line:GetText())
		assert.are.equal("New since last export", frame.choices.new.label:GetText())
		assert.are.equal("Everything", frame.choices.everything.label:GetText())
		assert.are.same({ 0, -1 }, frame.paste.highlight)
		copy(loaded)
		assert.is_nil(marks(loaded)[LOG_ID])
		assert.are.equal(
			"Pagle dev: a 64 KB test string is in the export window; copy it and check its length.",
			loaded.printed[#loaded.printed]
		)

		frame.choices.everything:Click()
		assert.are.equal("!PGL2!", frame.paste:GetText():sub(1, 6), "a choice makes a real export again")
	end)

	it("prints its usage without a size in range, and nothing with dev mode off", function()
		local loaded = withCasts(2)
		pagle(loaded, "dev on")
		for _, args in ipairs({ "", "0", "2049", "big", "1.5" }) do
			pagle(loaded, "dev pastetest " .. args)
			assert.are.equal(
				"Pagle dev: /pagle dev pastetest <KB>, from 1 to 2048; the check copies 64, 128, 256 and 512.",
				loaded.printed[#loaded.printed]
			)
		end
		assert.is_nil(window(loaded))

		pagle(loaded, "dev off")
		pagle(loaded, "dev pastetest 64")
		assert.is_nil(window(loaded))
	end)
end)
