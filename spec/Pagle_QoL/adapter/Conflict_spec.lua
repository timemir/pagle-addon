-- Coexisting with Angleur and Fishing Buddy: the conflict check at PLAYER_LOGIN, the pinned note, its two choices,
-- Esc, and standing down (QOL-R33, QOL-R80–R84, QOL-R97), driven through FakePagle and the fake client's frames,
-- addon switches and Esc (spec/support/client.lua, spec/support/fake_popup.lua).

local CAST = "SPELL Fishing"
local ANGLEUR = { metadata = { Title = "Angleur" } }
local FISHING_BUDDY = { metadata = { Title = "Fishing Buddy (Forever)" } }

-- QoL loaded against FakePagle with F bound to the Fishing key and `others` installed, then logged in.
---@param others table<string, FakeAddOn>
---@return FakePagle fake
---@return FakeClient client
---@return LoadedAddon loaded
local function start(others)
	local fake = newFakePagle()
	local loaded = fake.load("Pagle_QoL")
	local client = loaded.client
	client.boundKeys.PAGLE_FISHING_KEY = { "F" }
	for name, addon in pairs(others) do
		client.addons[name] = addon
	end
	fake.login()
	fake.fireGameEvent("PLAYER_LOGIN")
	return fake, client, loaded
end

-- The pinned note showing now, the Reload now note before the conflict note, or nil.
---@param loaded LoadedAddon
---@return table?
local function shownNote(loaded)
	for _, name in ipairs({ "PagleQoLReloadNote", "PagleQoLConflictNote" }) do
		local note = loaded.env[name]
		if note and note.shown then
			return note
		end
	end
	return nil
end

-- What the note showing now asks, and its two choices, first and second; nil with none showing.
---@param loaded LoadedAddon
---@return { text: string, buttons: string[] }?
local function note(loaded)
	local shown = shownNote(loaded)
	return shown and { text = shown.Title.text, buttons = { shown.primary.Text.text, shown.secondary.Text.text } }
end

-- Long enough for a note's fade out (0.15 s) to end and hide it.
local FADE_OUT = 0.2

-- Clicks the showing note's first or second choice, and lets the note fade out.
---@param loaded LoadedAddon
---@param which "primary"|"secondary"
local function choose(loaded, which)
	assert(shownNote(loaded))[which]:Click()
	loaded.client.update(FADE_OUT)
end

describe("The conflict check", function()
	it("shows no note and arms at login when no other fishing-key addon is loaded (QOL-R80, QOL-R33)", function()
		local _, client, loaded = start({ Details = { metadata = { Title = "Details!" } } })

		assert.is_nil(note(loaded))
		assert.are.equal(CAST, client.overrideAction("F"))
	end)

	it("ignores an other fishing-key addon that is installed but not loaded (QOL-R80)", function()
		local _, client, loaded = start({ Angleur = { enabled = false, metadata = { Title = "Angleur" } } })

		assert.is_nil(note(loaded))
		assert.are.equal(CAST, client.overrideAction("F"))
	end)

	it("asks with Use Pagle and Use {Angleur's title} when Angleur is loaded (QOL-R81)", function()
		local _, _, loaded = start({ Angleur = ANGLEUR })

		assert.are.same(
			{ text = "Two addons want your fishing key.", buttons = { "Use Pagle", "Use Angleur" } },
			note(loaded)
		)
	end)

	it("offers Use the others when several are loaded (QOL-R81)", function()
		local _, _, loaded = start({ Angleur = ANGLEUR, FishingBuddy = FISHING_BUDDY })

		assert.are.same({ "Use Pagle", "Use the others" }, assert(note(loaded)).buttons)
	end)

	it("is a note pinned with wax at the top centre, its first choice on leather (qol.md › UI)", function()
		local _, _, loaded = start({ Angleur = ANGLEUR })

		local shown = assert(shownNote(loaded))
		assert.are.equal(loaded.env.UIParent, shown.parent)
		assert.are.same({ 440, 200 }, { shown.width, shown.height })
		assert.are.same({ { "TOP", loaded.env.UIParent, "TOP", 0, -135 } }, shown.points)
		local field = "Interface\\AddOns\\Pagle\\media\\field\\Field"
		assert.are.equal(field, shown.primary.children[1].middle.texture)
		assert.are.equal(field, shown.secondary.children[1].middle.texture)
		-- Esc hides it through UISpecialFrames.
		assert.truthy(table.concat(loaded.env.UISpecialFrames, " "):find("PagleQoLConflictNote", 1, true))
	end)

	it("runs before the first arm, so QoL never arms and then stands down (QOL-R33, QOL-R82)", function()
		local _, client = start({ Angleur = ANGLEUR })

		assert.is_nil(client.overrideAction("F"))
		assert.are.same({}, client.bindingCalls)
	end)
end)

describe("The conflict note's choices", function()
	it("Use Pagle turns each other addon off for all characters and names them (QOL-R83)", function()
		local _, client, loaded = start({ Angleur = ANGLEUR, FishingBuddy = FISHING_BUDDY })

		choose(loaded, "primary")

		assert.are.same({ { name = "Angleur" }, { name = "FishingBuddy" } }, client.disabledAddOns)
		assert.are.same(
			{ "Pagle: turned off Angleur, Fishing Buddy (Forever). Type /reload to finish." },
			loaded.printed
		)
		assert.are.equal(0, client.reloads)
	end)

	it("Use {other} turns off Pagle QoL alone, for all characters (QOL-R83)", function()
		local _, client, loaded = start({ Angleur = ANGLEUR })

		choose(loaded, "secondary")

		assert.are.same({ { name = "Pagle_QoL" } }, client.disabledAddOns)
		assert.are.same({
			"Pagle: turned off Pagle QoL. Type /reload to finish. Pagle keeps recording your Catches.",
		}, loaded.printed)
		assert.are.equal(0, client.reloads)
	end)

	it("Esc chooses nothing (QOL-R81, QOL-R84)", function()
		local _, client, loaded = start({ Angleur = ANGLEUR })

		client.pressEscape()

		assert.is_nil(note(loaded))
		assert.are.same({}, client.disabledAddOns)
		assert.are.same({}, loaded.printed)
		assert.are.equal(0, client.reloads)
	end)

	it("asks again at the next login after Esc (QOL-R84)", function()
		local _, client = start({ Angleur = ANGLEUR })
		client.pressEscape()

		local _, _, nextLogin = start({ Angleur = ANGLEUR })

		assert.are.same({ "Use Pagle", "Use Angleur" }, assert(note(nextLogin)).buttons)
	end)
end)

describe("The Reload now note", function()
	-- Each choice, by the conflict note's button that makes it (QOL-R81).
	local CHOICES = { ["Use Pagle"] = "primary", ["Use {other}"] = "secondary" }

	for choice, button in pairs(CHOICES) do
		it(("follows %s, in place of the conflict note (QOL-R83)"):format(choice), function()
			local _, client, loaded = start({ Angleur = ANGLEUR })

			choose(loaded, button)

			assert.are.same(
				{ text = "Reload the interface now to finish?", buttons = { "Reload now", "Later" } },
				note(loaded)
			)
			assert.is_false(loaded.env.PagleQoLConflictNote.shown)
			assert.are.equal(0, client.reloads)
		end)

		it(("reloads on a click on Reload now after %s (QOL-R6, QOL-R83)"):format(choice), function()
			local _, client, loaded = start({ Angleur = ANGLEUR })
			choose(loaded, button)

			choose(loaded, "primary")

			assert.are.equal(1, client.reloads)
			assert.is_nil(note(loaded))
		end)

		it(("doesn't reload on Later or Esc after %s (QOL-R6, QOL-R83)"):format(choice), function()
			local _, client, loaded = start({ Angleur = ANGLEUR })
			choose(loaded, button)
			choose(loaded, "secondary")
			local _, again, againLoaded = start({ Angleur = ANGLEUR })
			choose(againLoaded, button)
			again.pressEscape()

			assert.is_nil(note(loaded))
			assert.is_nil(note(againLoaded))
			assert.are.equal(0, client.reloads + again.reloads)
		end)
	end

	it("never reloads on its own: not at load, on events, restriction or time (QOL-R6)", function()
		local fake, client, loaded = start({ Angleur = ANGLEUR })
		choose(loaded, "primary")

		fake.fireGameEvent("UPDATE_BINDINGS")
		fake.fire("CastStarted")
		fake.fire("CastEnded")
		fake.setRestricted(true)
		fake.setRestricted(false)
		client.update(60)

		assert.are.equal(0, client.reloads)
	end)

	it("isn't offered when no other fishing-key addon is loaded, nor on Esc (QOL-R83, QOL-R84)", function()
		local _, client, loaded = start({})
		local _, escaped, escapedLoaded = start({ Angleur = ANGLEUR })
		escaped.pressEscape()

		assert.is_nil(note(loaded))
		assert.is_nil(note(escapedLoaded))
		assert.is_nil(escapedLoaded.env.PagleQoLReloadNote)
		assert.are.equal(0, client.reloads + escaped.reloads)
	end)
end)

describe("The notes' motion and sounds (qol.md › UI)", function()
	-- The sound kits played so far, as "<id> <channel>".
	local function soundKits(loaded)
		local played = {}
		for _, sound in ipairs(loaded.client.sounds) do
			if sound:find("^%d+ ") then
				played[#played + 1] = sound
			end
		end
		return played
	end

	it("fades a note in over 0.2 s with IG_MAINMENU_OPEN, its wax pressed on from 1.8 times its size", function()
		local _, client, loaded = start({ Angleur = ANGLEUR })
		local shown = assert(shownNote(loaded))
		local wax = shown.wax

		assert.are.same({ "850 SFX" }, soundKits(loaded))
		assert.are.equal(0, shown:GetAlpha())
		assert.are.same({ 74 * 1.8, 0 }, { wax:GetWidth(), wax:GetAlpha() })
		client.update(0.29)
		assert.are.equal(1, shown:GetAlpha())
		-- Pressed just under its size.
		assert.is_true(math.abs(wax:GetWidth() - 74 * 0.95) < 0.5)
		client.update(0.1)
		assert.are.same({ 74, 74, 1 }, { wax:GetWidth(), wax:GetHeight(), wax:GetAlpha() })
	end)

	it(
		"plays IG_MAINMENU_OPTION, then IG_MAINMENU_CLOSE as the note fades out; a second click chooses nothing",
		function()
			local _, client, loaded = start({ Angleur = ANGLEUR })
			client.update(0.4)
			local conflictNote = loaded.env.PagleQoLConflictNote

			conflictNote.secondary:Click()
			conflictNote.secondary:Click()

			assert.are.same({ { name = "Pagle_QoL" } }, client.disabledAddOns)
			-- The Reload now note opens as the conflict note fades.
			assert.are.same({ "850 SFX", "852 SFX", "851 SFX", "850 SFX" }, soundKits(loaded))
			assert.is_true(conflictNote.shown)
			client.update(0.1)
			assert.is_true(conflictNote:GetAlpha() > 0 and conflictNote:GetAlpha() < 1)
			client.update(0.1)
			assert.is_false(conflictNote.shown)
		end
	)

	it(
		"stays closed when the whole UI hides as it fades after a choice, never open for a second one (QOL-R83)",
		function()
			local _, client, loaded = start({ Angleur = ANGLEUR })
			client.update(0.4)
			local conflictNote = loaded.env.PagleQoLConflictNote
			conflictNote.secondary:Click()
			client.update(0.05)

			-- Alt-Z: the client runs the OnHide of each shown frame under UIParent, then its OnShow as UIParent shows again.
			loaded.env.UIParent:Hide()
			conflictNote.scripts.OnHide(conflictNote)
			client.update(0.05)
			loaded.env.UIParent:Show()
			if conflictNote.shown then
				conflictNote.scripts.OnShow(conflictNote)
			end

			assert.is_false(conflictNote.shown)
			assert.are.same({ { name = "Pagle_QoL" } }, client.disabledAddOns)
		end
	)

	it("hides at once on Esc, with IG_MAINMENU_CLOSE", function()
		local _, client, loaded = start({ Angleur = ANGLEUR })

		client.pressEscape()

		assert.is_nil(note(loaded))
		assert.are.same({ "850 SFX", "851 SFX" }, soundKits(loaded))
	end)

	it("shows settled and goes at once with Core's Animations setting off, its sounds still playing", function()
		local fake = newFakePagle()
		fake.profile.announcements.motion = false
		local loaded = fake.load("Pagle_QoL")
		loaded.client.addons.Angleur = ANGLEUR
		fake.login()
		fake.fireGameEvent("PLAYER_LOGIN")
		local shown = assert(shownNote(loaded))

		assert.are.same({ 1, 74, 1 }, { shown:GetAlpha(), shown.wax:GetWidth(), shown.wax:GetAlpha() })
		shown.primary:Click()

		assert.is_false(shown.shown)
		assert.are.same({ "850 SFX", "852 SFX", "851 SFX", "850 SFX" }, soundKits(loaded))
	end)
end)

describe("Standing down", function()
	-- Every way the note can end: unanswered, either choice (which waits for /reload), or Esc.
	local ENDINGS = {
		unanswered = function() end,
		["Use Pagle"] = function(_, loaded)
			choose(loaded, "primary")
		end,
		["Use {other}"] = function(_, loaded)
			choose(loaded, "secondary")
		end,
		Esc = function(client)
			client.pressEscape()
		end,
	}

	for ending, finish in pairs(ENDINGS) do
		it(("binds nothing and doesn't tick for the session: %s (QOL-R82, QOL-R97)"):format(ending), function()
			local fake, client, loaded = start({ Angleur = ANGLEUR })
			finish(client, loaded)

			client.boundKeys.PAGLE_FISHING_KEY = { "G" }
			fake.fireGameEvent("UPDATE_BINDINGS")
			fake.fire("CastStarted")
			fake.setRestricted(true)
			fake.setRestricted(false)
			client.update(0.5)

			assert.are.same({}, client.bindingCalls)
			for _, frame in ipairs(client.frames) do
				assert.is_nil(frame.scripts.OnUpdate)
			end
		end)
	end

	it("keeps QoL registered with Core and its saved settings, which still save (QOL-R82)", function()
		local fake, _, loaded = start({ Angleur = ANGLEUR })

		assert.are.equal("on", fake.moduleState("QoL"))
		loaded.ns.db.global.someSetting = true
		assert.is_true(loaded.env.PagleQoLDB.global.someSetting)
	end)
end)

describe("Core's Letter while QoL asks (ONB-R100, ONB-R10)", function()
	-- Each way the question ends: Esc on the conflict note, or either choice and then Later, Esc or Reload now on the
	-- Reload now note.
	local ENDINGS = {
		["Esc on the conflict note"] = function(client)
			client.pressEscape()
		end,
		["Use Pagle, then Later"] = function(_, loaded)
			choose(loaded, "primary")
			choose(loaded, "secondary")
		end,
		["Use {other}, then Esc"] = function(client, loaded)
			choose(loaded, "secondary")
			client.pressEscape()
		end,
		["Use Pagle, then Reload now"] = function(_, loaded)
			choose(loaded, "primary")
			choose(loaded, "primary")
		end,
	}

	for ending, finish in pairs(ENDINGS) do
		it(("tells Core its dialog is open until the question ends: %s (ONB-R100)"):format(ending), function()
			local fake, client, loaded = start({ Angleur = ANGLEUR })
			assert.is_true(fake.letter:IsDialogOpen())

			finish(client, loaded)

			assert.is_false(fake.letter:IsDialogOpen())
		end)
	end

	it("keeps it open from a choice to the Reload now note, with Core's Animations off too (ONB-R100)", function()
		local fake = newFakePagle()
		fake.profile.announcements.motion = false
		local loaded = fake.load("Pagle_QoL")
		loaded.client.addons.Angleur = ANGLEUR
		fake.login()
		fake.fireGameEvent("PLAYER_LOGIN")
		local opened = {}
		local setDialogOpen = fake.letter.SetDialogOpen
		function fake.letter.SetDialogOpen(self, owner, open)
			opened[#opened + 1] = open
			setDialogOpen(self, owner, open)
		end

		assert(shownNote(loaded)).primary:Click()

		assert.is_true(fake.letter:IsDialogOpen())
		assert.are.same({ true }, opened)
	end)

	it("tells Core nothing when no other fishing-key addon is loaded, nor for the tour's samples (CORE-R68)", function()
		local fake, _, loaded = start({})

		loaded.ns.PreviewNotes(true)
		assert.is_false(fake.letter:IsDialogOpen())
		loaded.ns.PreviewNotes(false)

		assert.is_false(fake.letter:IsDialogOpen())
	end)
end)
