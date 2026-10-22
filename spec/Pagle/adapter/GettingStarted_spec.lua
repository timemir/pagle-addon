-- The Settings root's Getting started section on the client (ONB-R81, settings.md SET-R10 rows 4–6), Core's own rows
-- drawn on its own frames (SET-R5, SET-R6): the Field guide's Show me around again (ONB-R22), the Margin notes
-- checkbox and Show them again (ONB-R50, ONB-R80), and the First evening list checkbox with its count, offered only
-- while the list is unfinished (ONB-R63). The tree itself is spec/settings_tree_spec.lua's.

-- Core over a log holding `entries` (the build entry alone: a new Angler), with Animations off and a fixture Ledger
-- registered, logged in and in the world, and PagleDB `saved` if given.
local function ready(entries, saved)
	local loaded = loadCore(entries or { BUILD_ENTRY }, saved)
	local ledger = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
	enterWorld(loaded, 3)
	loaded.ns.db.profile.announcements.motion = false
	return loaded, ledger
end

-- The root's rows as the panel draws them now.
local function rootRows(loaded)
	local settings = loaded.client.settings
	return settings.show(settings.page("Pagle"))
end

-- The root's row whose first text is `label`, as drawn now; nil if none.
local function rowOf(loaded, label)
	for _, row in ipairs(rootRows(loaded)) do
		if loaded.client.settings.textsOf(row.frame)[1] == label then
			return row
		end
	end
	return nil
end

-- The root's row whose first text is `label`, as drawn now; an error if none.
local function rowNamed(loaded, label)
	return assert(rowOf(loaded, label), "no row " .. label)
end

-- A drawn widget's first shown descendant of `kind`, depth first.
local function shownOf(widget, kind)
	for _, child in ipairs(widget.children) do
		if child.shown then
			if child.kind == kind then
				return child
			end
			local found = shownOf(child, kind)
			if found then
				return found
			end
		end
	end
	return nil
end

-- A drawn widget's first shown descendant of `kind`; an error if none.
local function shown(widget, kind)
	return assert(shownOf(widget, kind), "no shown " .. kind)
end

-- PagleDB.global.onboarding as the client holds it.
local function state(loaded)
	return loaded.env.PagleDB.global.onboarding
end

describe("The Settings root's Getting started section (ONB-R81, SET-R10)", function()
	it("comes after the status list and its note, before Help chart the waters", function()
		local loaded = ready()

		local texts = {}
		for _, row in ipairs(rootRows(loaded)) do
			texts[#texts + 1] = loaded.client.settings.textsOf(row.frame)[1] or row.initializer:GetName()
		end

		local at
		for i, text in ipairs(texts) do
			if text == "Getting started" then
				at = i
			end
		end
		assert.are.same({
			"Turn Modules on or off in the AddOns list.",
			"Getting started",
			"Field guide",
			"Margin notes",
			"First evening list",
			"Help chart the waters",
		}, { unpack(texts, at - 1, at + 4) })
	end)

	it("opens the Field guide from Show me around again, closing the panel first (ONB-R22, SET-R12)", function()
		local loaded = ready()
		loaded.env.Pagle.OpenSettings()
		local row = rowNamed(loaded, "Field guide")
		assert.are.same(
			{ "Field guide", "Show me around again", "The eight pages you saw on your first day." },
			loaded.client.settings.textsOf(row.frame)
		)

		shown(row.frame, "Button"):Click()

		assert.is_false(loaded.client.settings.panel:IsShown())
		assert.is_true(loaded.ns.guide:IsOpen())
	end)

	it("turns Margin notes off and on, and Show them again shows every note again (ONB-R50, ONB-R80)", function()
		local loaded = ready()
		state(loaded).notesSeen["core.nod"] = true
		local row = rowNamed(loaded, "Margin notes")
		local check = shown(row.frame, "CheckButton")
		assert.is_true(check:GetChecked())

		check:Click()
		assert.is_false(state(loaded).notesOn)
		shown(row.frame, "Button"):Click()

		assert.are.same({}, state(loaded).notesSeen)
		assert.are.equal("Pagle: margin notes will show again, once each.", loaded.printed[#loaded.printed])
		check:Click()
		assert.is_true(state(loaded).notesOn)
	end)

	it("explains Margin notes in the row's tooltip", function()
		local loaded = ready()
		local row = rowNamed(loaded, "Margin notes")

		assert(row.frame:GetScript("OnEnter"))(row.frame)

		assert.are.same({ "Margin notes", "Explain things the first time they happen." }, loaded.client.tooltipLines())
	end)

	it("shows the First evening list from its checkbox, counting it, and closes it unchecked (ONB-R63)", function()
		local loaded, ledger = ready()
		ledger:CompleteEveningItem("journal")
		local row = rowNamed(loaded, "First evening list")
		local check = shown(row.frame, "CheckButton")
		assert.is_false(check:GetChecked())
		assert.are.equal("1 of 5 done", loaded.client.settings.textsOf(row.frame)[2])

		check:Click()

		assert.is_true(loaded.ns.eveningFrame:IsShown())
		assert.is_true(state(loaded).evening.shown)
		check:Click()
		assert.is_false(loaded.ns.eveningFrame:IsShown())
		assert.is_true(state(loaded).evening.closed)
		check:Click()
		assert.is_true(loaded.ns.eveningFrame:IsShown())
		assert.is_false(state(loaded).evening.closed)
	end)

	it("draws the First evening list's row empty once the list is done, and leaves it out after (ONB-R81)", function()
		local loaded, ledger = ready()
		loaded.ns.evening:SetShown(true)
		ledger:CompleteEveningItem("journal")
		for _, id in ipairs({ "cast", "catch", "session", "shop" }) do
			loaded.ns.evening:Complete(id)
		end
		loaded.client.advance(2.5)

		local empty = 0
		for _, row in ipairs(rootRows(loaded)) do
			local own = row.initializer:GetTemplate() == "PagleSettingsRowTemplate"
			empty = empty + ((own and #loaded.client.settings.textsOf(row.frame) == 0) and 1 or 0)
		end
		assert.are.equal(1, empty)

		local again = ready(nil, loaded.env.PagleDB)
		assert.is_nil(rowOf(again, "First evening list"))
		assert.is_not_nil(rowOf(again, "Margin notes"))
	end)

	it("has no First evening list row for a returning Angler (ONB-R2, ONB-R81)", function()
		local loaded = ready({ BUILD_ENTRY, castEntry(SERVER_TIME - 4000) })

		assert.is_nil(rowOf(loaded, "First evening list"))
		assert.is_not_nil(rowOf(loaded, "Field guide"))
	end)

	it("is left by the root's Defaults button (SET-R13)", function()
		local loaded = ready()
		state(loaded).notesOn = false

		loaded.client.settings.defaults(loaded.client.settings.page("Pagle"))

		assert.is_false(state(loaded).notesOn)
	end)
end)
