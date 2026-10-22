-- The Settings UX gate (#265): the whole Settings tree, with every Module loaded on the fake client, walked page by
-- page and compared with docs/spec/settings.md's tree, written out below as EXPECTED. Run again with each Module off
-- (SET-R4, SET-R90), with the Tackle Board unstarted and started (SET-R11, SET-R43), and while restricted (SET-R93).
-- Then every greying condition on and off (SET-R20, SET-R31, SET-R43, SET-R61), each page's Defaults (SET-R13,
-- SET-R21, SET-R33, SET-R45, SET-R52, SET-R60), the strings (CORE-R8, CORE-R9, CONTEXT.md) and the tour stops
-- (CORE-R68). Each part also has its own specs, over fixture Modules: this one checks the real package as shipped.

-- The roster Modules, by roster name and folder, in CORE-R1 order.
local ROSTER = {
	{ name = "Ledger", addon = "Pagle_Ledger" },
	{ name = "Hunts", addon = "Pagle_Hunts" },
	{ name = "Stats", addon = "Pagle_Stats" },
	{ name = "TackleBoard", addon = "Pagle_TackleBoard" },
	{ name = "QoL", addon = "Pagle_QoL" },
}

-- What each row's template is, as the tree's tables name its kind (SET-R2, SET-R5).
local KINDS = {
	SettingsListSectionHeaderTemplate = "header",
	SettingsCheckboxControlTemplate = "checkbox",
	SettingsSliderControlTemplate = "slider",
	SettingsDropdownControlTemplate = "dropdown",
	SettingButtonControlTemplate = "button",
	PagleSettingsKeyRowTemplate = "keybinding",
	PagleSettingsSlotRowTemplate = "slot",
	PagleStatsWatchedRowTemplate = "custom",
}

-- The tooltips settings.md gives (Core's and Hunts' rows) and the owners' specs give (every other Module row).
local TIPS = {
	fieldReport = "Copy what you've caught that Pagle's data doesn't know yet, and paste it into the issue form.",
	reminder = "A chat line every 50 Casts not yet saved. WoW saves only on /reload or logout, so a crash loses them.",
	lengthUnit = "How Pagle shows the length of your Catches. Records are kept in millimetres, so switching changes "
		.. "only what you see.",
	clock = "How Pagle writes a time of day, such as the realm time at the top of the Hunts board. Following the game "
		.. "uses the minimap clock's 24-hour mode.",
	castWith = "Also on the compartment menu and /pagle qol input.",
	fishingKey = "Each press does the next single thing: cast, reel, or a lure, gear or clam when needed.",
	fishingSet = "The Fishing key puts it on when no pole is in hand. Double-click skips this.",
	swapGear = "Swaps between your fishing set and what you wore before (saved as Pagle Previous).",
	lures = "A press before a cast applies a lure when none is on.",
	clams = "One clam per press, never during a cast.",
	audio = "While you fish: effects at full; music, ambience and dialog muted; master untouched. Put back afterwards.",
	autoLoot = "Only while you fish. Skipped if you already have auto-loot on.",
	button = "Shows what your next press will do. Shift-drag to move.",
	cozy = "Nothing pops up or plays. Every moment waits in the Session summary. A Legend's splash still shows, "
		.. "silently.",
	budget = "When toasts come close together, the smaller ones step down to a quiet Nod. Records always keep their "
		.. "ruler. Greyed out in Cozy mode, which holds everything anyway.",
	everyCatch = "A quiet line for each catch: its name, size band and length. A toast or banner for the same catch "
		.. "shows instead. Greyed out in Cozy mode, which shows nothing.",
	motion = "Toasts slide in and stamp themselves, banners drop their seal, and the Legend's rays turn. Off, each "
		.. "appears as it settles.",
	windowMoments = "A quiet Nod when a pinned Hunt's window opens. It fades when the window closes.",
	companionHint = "A line on the Hunts board, and a Nod once a week, while the Pagle companion isn't bringing you "
		.. "new wagers.",
	marginNotes = "Explain things the first time they happen.",
	minimapIcon = "A round Pagle button on the minimap's edge that opens the Pagle menu. The menu is also in the AddOns "
		.. "button by the minimap.",
	anglerTooltips = "Adds a Pagle block to the tooltip of players whose Angler is on the Pagle website. Needs the Pagle "
		.. "Companion.",
	trackerPosition = "Shift-drag any Pagle tracker to move them all. This puts them back under the minimap.",
	huntsTracker = "A small tracker under the minimap with the Hunts you've pinned on the board.",
	statsTracker = "Shows this Session and your watched Dry spells under the minimap. Watching a Dry spell turns it on.",
	watched = "Watch or stop watching from any fish's page in the Stats book.",
	boardTracker = "Lists the goals you can work on where you are. Before your board is started, use Start my board "
		.. "on the Pagle page.",
}

-- The tracker Modules: the Trackers page and its Core row stand only while one of them is On (SET-R1, SET-R40), and
-- Look and Feel's Trackers header only while one of their frames is shown (SET-R50).
local TRACKER_MODULES = { "Hunts", "Stats", "TackleBoard" }

-- settings.md's tree with every Module On and the board unstarted (SET-R1, SET-R10–R11, SET-R20, SET-R30, SET-R32,
-- SET-R40–R44, SET-R50), page by page in the panel's order. A row is { kind, label }, with `under` when it is
-- indented under the nearest row before it without `under` (↳), `caption` for a button's caption, `tip` for its
-- tooltip, `range` for a slider's { min, max, step } as shown (settings.md › Tunables), and for a status line its
-- `state` and `button`. A row Core draws itself on the root (Getting started's, SET-R10 rows 4–6) is a "button" or
-- "checkbox" with its `caption` and `line`; the First evening list's line counts the items of the Modules On
-- (`evening`, ONB-R61). A button given one quoted string has only a caption
-- (SET-R2). `of` names the Module (or Modules, all of which must be off) whose row it is: it vanishes while that
-- Module isn't On (SET-R4), and a status line reads Off with no button instead (SET-R90).
local EXPECTED = {
	{
		name = "Pagle",
		rows = {
			{ "header", "Modules" },
			{ "status", "Ledger", state = "On", button = "Open Fish Journal", of = "Ledger" },
			{ "status", "Hunts", state = "On", button = "Open Hunts", of = "Hunts" },
			{ "status", "Stats", state = "On", button = "Open Stats", of = "Stats" },
			{ "status", "Tackle Board", state = "On", button = "Start my board", of = "TackleBoard" },
			{ "status", "QoL", state = "On", button = "Fishing settings »", of = "QoL" },
			{ "text", "Turn Modules on or off in the AddOns list." },
			{ "header", "Getting started" },
			{
				"button",
				"Field guide",
				caption = "Show me around again",
				line = "The eight pages you saw on your first day.",
			},
			{ "checkbox", "Margin notes", caption = "Show them again", tip = TIPS.marginNotes },
			{ "checkbox", "First evening list", line = "0 of %d done", evening = true },
			{ "header", "Help chart the waters" },
			{ "button", "Field report", caption = "Open Field report", tip = TIPS.fieldReport },
			{ "header", "Saving" },
			{ "checkbox", "Remind me to /reload when Casts are unsaved", tip = TIPS.reminder },
			{ "header", "Units" },
			{ "dropdown", "Length unit", tip = TIPS.lengthUnit },
			{ "dropdown", "Clock", tip = TIPS.clock },
			{ "header", "Pagle menu" },
			{ "checkbox", "Show the minimap icon", tip = TIPS.minimapIcon },
			{ "header", "Pagle website" },
			{ "checkbox", "Show other Anglers on player tooltips", tip = TIPS.anglerTooltips },
		},
	},
	{
		name = "Fishing",
		rows = {
			{ "header", "Casting", of = "QoL" },
			{ "dropdown", "Cast with", tip = TIPS.castWith, of = "QoL" },
			{ "keybinding", "Fishing key", under = true, tip = TIPS.fishingKey, of = "QoL" },
			{ "header", "Gear", of = "QoL" },
			{ "dropdown", "Fishing set", tip = TIPS.fishingSet, of = "QoL" },
			{ "button", under = true, caption = "Save what I'm wearing as my fishing set", of = "QoL" },
			{ "keybinding", "Swap gear", under = true, tip = TIPS.swapGear, of = "QoL" },
			{ "header", "Lures and clams", of = "QoL" },
			{ "dropdown", "Lures", tip = TIPS.lures, of = "QoL" },
			{ "dropdown", "Lure", under = true, of = "QoL" },
			{ "checkbox", "Open clams between Casts", tip = TIPS.clams, of = "QoL" },
			{ "header", "While you fish", of = "QoL" },
			{ "checkbox", "Fishing audio mix", tip = TIPS.audio, of = "QoL" },
			{ "checkbox", "Keep sound when the game is in the background", under = true, of = "QoL" },
			{ "checkbox", "Auto-loot while fishing", tip = TIPS.autoLoot, of = "QoL" },
			{ "checkbox", "Show the next-action button", tip = TIPS.button, of = "QoL" },
			{ "button", "Button position", under = true, caption = "Reset", of = "QoL" },
		},
	},
	{
		name = "Announcements",
		rows = {
			{ "checkbox", "Cozy mode", tip = TIPS.cozy },
			{ "checkbox", "Interruption budget", tip = TIPS.budget },
			{ "slider", "Interruptions", under = true, range = { 1, 30, 1 } },
			{ "slider", "Per", under = true, range = { 1, 15, 1 } },
			{ "checkbox", "Show every catch", tip = TIPS.everyCatch },
			{ "checkbox", "Animations", tip = TIPS.motion },
			{ "slot", "Toast style" },
			{ "slot", "Sound set" },
			{ "header", "Hunts", of = "Hunts" },
			{ "checkbox", "Tell me when a pinned Hunt's window opens", tip = TIPS.windowMoments, of = "Hunts" },
		},
	},
	{
		name = "Trackers",
		rows = {
			{ "button", "Tracker position", caption = "Reset", tip = TIPS.trackerPosition, of = TRACKER_MODULES },
			{ "header", "Hunts", of = "Hunts" },
			{ "checkbox", "Show the Hunts tracker", tip = TIPS.huntsTracker, of = "Hunts" },
			{ "slot", "Hunts tracker frame", of = "Hunts" },
			{ "header", "Stats", of = "Stats" },
			{ "checkbox", "Show the live tracker", tip = TIPS.statsTracker, of = "Stats" },
			{ "custom", "Watched Dry spells", under = true, tip = TIPS.watched, of = "Stats" },
			{ "slot", "Stats tracker frame", of = "Stats" },
			{ "header", "Tackle Board", of = "TackleBoard" },
			{ "checkbox", "Show goals workable here", tip = TIPS.boardTracker, of = "TackleBoard" },
			{ "slot", "Tackle Board tracker frame", of = "TackleBoard" },
		},
	},
	{
		name = "Look and Feel",
		rows = {
			{ "text", "Looks you own. Pick one here or with Use in the Curio Shop; both change the same thing." },
			{ "header", "Announcements" },
			{ "slot", "Toast style" },
			{ "slot", "Sound set" },
			{ "header", "Crests" },
			{ "slot", "Crests" },
			{ "header", "Fish Journal", of = "Ledger" },
			{ "slot", "Journal binding", of = "Ledger" },
			{ "header", "Hunts", of = "Hunts" },
			{ "slot", "Notebook cover", of = "Hunts" },
			{ "header", "Trackers", of = TRACKER_MODULES },
			{ "slot", "Hunts tracker frame", of = "Hunts" },
			{ "slot", "Stats tracker frame", of = "Stats" },
			{ "slot", "Tackle Board tracker frame", of = "TackleBoard" },
			{ "header", "Curio Shop" },
			{ "button", "Buy more looks with Pagle Coins", caption = "Open the Curio Shop" },
		},
	},
}

-- Whether a row `of` the given owner stays while the Modules in `off` aren't On: Core's always, a Module's while it
-- is On, a row of several Modules while any of them is.
---@param of string|string[]|nil
---@param off table<string, true>
local function stays(of, off)
	if of == nil then
		return true
	end
	for _, name in ipairs(type(of) == "table" and of or { of }) do
		if not off[name] then
			return true
		end
	end
	return false
end

-- EXPECTED with the Modules in `off` not On (SET-R4, SET-R90): their rows, headers and slots gone, their status
-- lines Off with no button, and a page left with no rows not registered (SET-R1). `started` reads the Tackle Board's
-- status button as after Start (SET-R11).
---@param off string[]?
---@param started boolean?
---@return { name: string, rows: table[] }[]
local function expectedTree(off, started)
	local isOff = {}
	for _, name in ipairs(off or {}) do
		isOff[name] = true
	end
	local tree = {}
	for _, page in ipairs(EXPECTED) do
		local rows = {}
		for _, row in ipairs(page.rows) do
			local copy = {}
			for key, value in pairs(row) do
				copy[key] = value
			end
			copy.of, copy.evening = nil, nil
			if row.evening then
				-- Core's four items, the Ledger's journal and Hunts' hunts (ONB-R61)
				local total = 4 + (isOff.Ledger and 0 or 1) + (isOff.Hunts and 0 or 1)
				copy.line = row.line:format(total)
			end
			if row[1] == "status" and isOff[row.of] then
				copy.state, copy.button = "Off", nil
				rows[#rows + 1] = copy
			elseif stays(row.of, isOff) then
				if row.of == "TackleBoard" and row[1] == "status" and started then
					copy.button = "Open Tackle Board"
				end
				rows[#rows + 1] = copy
			end
		end
		if #rows > 0 then
			tree[#tree + 1] = { name = page.name, rows = rows }
		end
	end
	return tree
end

-- The whole package on the fake client: Core, then every roster Module but those in `options.off`, each of which is
-- installed but disabled in the AddOns list (CORE-R41's Off). `options.globals` adds to the Forever globals.
-- `options.hintOn` turns Hunts' companion hint switch on before its OnInitialize, as the release that turns it on
-- will (HNT-R172): shipped, it is off.
---@param options { off: string[]?, globals: table?, hintOn: boolean? }?
---@return LoadedAddon
local function loadPackage(options)
	options = options or {}
	local off = {}
	for _, name in ipairs(options.off or {}) do
		off[name] = true
	end
	local also = {}
	for _, module in ipairs(ROSTER) do
		if not off[module.name] then
			also[#also + 1] = module.addon
		end
	end
	local beforeLoaded = options.hintOn
			and {
				Pagle_Hunts = function(ns)
					ns.COMPANION_HINT_ON = true
				end,
			}
		or nil
	local loaded = loadAddon("Pagle", foreverWith(options.globals), { also = also, beforeLoaded = beforeLoaded })
	for _, module in ipairs(ROSTER) do
		if off[module.name] then
			loaded.client.addons[module.addon] = {
				enabled = false,
				loaded = false,
				metadata = { ["X-Pagle-API"] = "1", Version = "@project-version@" },
			}
		end
	end
	return loaded
end

-- The package logged in and in the world, its projections' first builds done: the tree is registered.
---@param options { off: string[]?, globals: table?, hintOn: boolean? }?
---@return LoadedAddon
local function ready(options)
	return enterWorld(loadPackage(options), 3)
end

-- The tooltip a drawn row shows: a native row's or a keybinding row's own, or what a custom row puts on GameTooltip
-- when the mouse goes over it.
---@param loaded LoadedAddon
---@param row { initializer: table, frame: table }
---@return string?
local function tooltipOf(loaded, row)
	local data = row.initializer:GetData()
	local tip = row.initializer:GetTooltip() or data.tooltip
	local onEnter = row.frame:GetScript("OnEnter")
	if tip == nil and onEnter then
		onEnter(row.frame)
		tip = loaded.client.tooltipLines()[2]
		row.frame:GetScript("OnLeave")(row.frame)
	end
	return tip
end

-- Whether a drawn widget holds a shown check button, depth first.
---@param widget table
---@return boolean
local function holdsCheck(widget)
	for _, child in ipairs(widget.children) do
		if child.shown and (child.kind == "CheckButton" or holdsCheck(child)) then
			return true
		end
	end
	return false
end

-- A row Core draws itself, not a status line, as EXPECTED writes it: a paragraph or note ("text"), or one of Getting
-- started's (SET-R10 rows 4–6): a "checkbox" with a shown check button, else a "button" with a shown one, each with its
-- label, its button's `caption` and the text left as its `line`.
---@param settings FakeSettings
---@param frame table
---@param texts string[]
---@return table
local function coreRowAsWritten(settings, frame, texts)
	local caption
	for _, button in ipairs(settings.buttonsOf(frame)) do
		caption = button.text
	end
	local kind = holdsCheck(frame) and "checkbox" or caption and "button" or "text"
	if kind == "text" then
		return { "text", texts[1] }
	end
	local out = { kind, texts[1], caption = caption }
	for i = 2, #texts do
		if texts[i] ~= caption and texts[i] ~= "" then
			out.line = texts[i]
		end
	end
	return out
end

-- A drawn row as EXPECTED writes it. An indented row whose parent isn't the nearest unindented row before it reads
-- `under = "wrong parent"`.
---@param loaded LoadedAddon
---@param row { initializer: table, frame: table }
---@param top table? the initializer of the nearest unindented row before it
---@return table
local function asWritten(loaded, row, top)
	local settings = loaded.client.settings
	local initializer, frame = row.initializer, row.frame
	local template = initializer:GetTemplate()
	local out
	if template == "PagleSettingsRowTemplate" then
		local texts = settings.textsOf(frame)
		if initializer.searchTags[1] == "MODULES" then
			out = { "status", texts[1], state = texts[3], button = texts[4] }
		else
			out = coreRowAsWritten(settings, frame, texts)
		end
	elseif template == "SettingButtonControlTemplate" then
		local label = initializer:GetData().name
		out = { "button", label ~= "" and label or nil, caption = frame.Button.text }
	else
		out = { KINDS[template] or template, initializer:GetName() }
	end
	if out[1] == "slider" then
		local options = initializer:GetData().options
		local min, max = options.minValue, options.maxValue
		out.range = { min, max, (max - min) / options.steps }
	end
	out.tip = tooltipOf(loaded, row)
	local parent = initializer:GetParentInitializer()
	if parent then
		out.under = parent == top or "wrong parent"
	end
	return out
end

-- The rows of the page `category`, shown as the panel shows them, as EXPECTED writes them.
---@param loaded LoadedAddon
---@param category table
---@return table[]
local function pageAsWritten(loaded, category)
	local rows, top = {}, nil
	for i, row in ipairs(loaded.client.settings.show(category)) do
		rows[i] = asWritten(loaded, row, top)
		if not row.initializer:GetParentInitializer() then
			top = row.initializer
		end
	end
	return rows
end

-- The registered tree, as expectedTree writes it: every category in the panel's order, each a subcategory of the
-- root, the root alone under AddOns.
---@param loaded LoadedAddon
---@return { name: string, rows: table[] }[]
local function drawnTree(loaded)
	local settings = loaded.client.settings
	assert.are.equal(1, #settings.addOnCategories)
	local root = settings.addOnCategories[1]
	local tree = {}
	for i, category in ipairs(settings.categories) do
		assert.are.equal(i > 1 and root or nil, category.parent)
		tree[i] = { name = category.name, rows = pageAsWritten(loaded, category) }
	end
	return tree
end

describe("The Settings tree, every Module loaded", function()
	it("is settings.md's tree with every Module On, the board unstarted (SET-R1–R3, SET-R10–R50)", function()
		local loaded = ready()

		assert.are.same(expectedTree(), drawnTree(loaded))
	end)

	for _, module in ipairs(ROSTER) do
		it(
			("with %s off, loses its rows, headers and slots, its status Off (SET-R4, SET-R90)"):format(module.name),
			function()
				local loaded = ready({ off = { module.name } })

				assert.are.same(expectedTree({ module.name }), drawnTree(loaded))
			end
		)
	end

	it("is unchanged by the companion hint while its switch is off, as at 1.0 (HNT-R172)", function()
		local loaded = ready()

		assert.is_false(loaded.namespaces.Pagle_Hunts.COMPANION_HINT_ON)
		assert.are.same(expectedTree(), drawnTree(loaded))
		local rows = pageAsWritten(loaded, loaded.client.settings.page("Announcements"))
		assert.are.same({ "checkbox", "Tell me when a pinned Hunt's window opens" }, { rows[#rows][1], rows[#rows][2] })
	end)

	it(
		"adds Remind me about the Pagle companion after Hunts' window row once the hint switch is on (SET-R32, HNT-R172)",
		function()
			local loaded = ready({ hintOn = true })

			local expected = expectedTree()
			for _, page in ipairs(expected) do
				if page.name == "Announcements" then
					page.rows[#page.rows + 1] =
						{ "checkbox", "Remind me about the Pagle companion", tip = TIPS.companionHint }
				end
			end
			assert.are.same(expected, drawnTree(loaded))
		end
	)

	it("registers no Trackers page while no tracker Module is On (SET-R1, SET-R40)", function()
		local loaded = ready({ off = TRACKER_MODULES })

		assert.is_nil(loaded.client.settings.category("Trackers"))
		assert.are.same(expectedTree(TRACKER_MODULES), drawnTree(loaded))
	end)

	it("shows the paragraph and Core's pages alone while no Module is On (SET-R1, SET-R10)", function()
		local loaded = ready({ off = { "Ledger", "Hunts", "Stats", "TackleBoard", "QoL" } })

		local tree = drawnTree(loaded)

		local expected = expectedTree({ "Ledger", "Hunts", "Stats", "TackleBoard", "QoL" })
		table.insert(expected[1].rows, 1, { "text", "Recording your Catches. Enable a Module to see them." })
		assert.are.same(expected, tree)
	end)

	it("reads Open Tackle Board on the root once the board is started (SET-R11, SET-R12, CORE-R44)", function()
		local loaded = ready()

		loaded.namespaces.Pagle_TackleBoard.Start()

		assert.are.same(expectedTree(nil, true), drawnTree(loaded))
	end)

	it("registers nothing while restricted, then the whole tree when it ends (SET-R93, CORE-R32)", function()
		local inCombat = true
		local loaded = loadPackage({
			globals = {
				InCombatLockdown = function()
					return inCombat
				end,
			},
		})
		enterWorld(loaded, 3)
		assert.are.same({}, loaded.client.settings.categories)

		inCombat = false
		setCombat(loaded, false)

		assert.are.same(expectedTree(), drawnTree(loaded))
	end)

	it("keeps every row while restricted, a panel already open being Blizzard's (SET-R93)", function()
		local loaded = ready()

		setCombat(loaded, true)

		assert.are.same(expectedTree(), drawnTree(loaded))
	end)
end)

-- Whether a drawn row is greyed out: a native control's `enabled`, a keybinding row's keys, a slot row's dropdown.
-- A header, a text row or a custom row has no greying of its own, so it reads false.
---@param loaded LoadedAddon
---@param row { initializer: table, frame: table }
---@return boolean
local function isGreyed(loaded, row)
	local template = row.initializer:GetTemplate()
	if template == "PagleSettingsKeyRowTemplate" then
		return not keyRowDrawn(loaded, row.frame).live
	elseif template == "PagleSettingsSlotRowTemplate" then
		return not loaded.client.settings.dropdownOf(row):IsEnabled()
	end
	return row.frame.enabled == false
end

-- The rows of the page named `name` greyed out as it shows now, each by its label (a caption-only button by its
-- caption).
---@param loaded LoadedAddon
---@param name string
---@return string[]
local function greyedOn(loaded, name)
	local greyed = {}
	for _, row in ipairs(loaded.client.settings.show(loaded.client.settings.page(name))) do
		if isGreyed(loaded, row) then
			local written = asWritten(loaded, row, nil)
			greyed[#greyed + 1] = written[2] or written.caption
		end
	end
	return greyed
end

-- The setting a row named `label` on page `name` changes, as the panel's control does (SET-R62).
---@param loaded LoadedAddon
---@param name string
---@param label string
---@param value any
local function setRow(loaded, name, label, value)
	local settings = loaded.client.settings
	local row = settings.rowNamed(settings.show(settings.page(name)), label)
	row.initializer:GetSetting():SetValue(value)
end

describe("Greying in the Settings tree", function()
	it("greys only Swap gear, Lure and the Tackle Board's checkbox at first (SET-R20, SET-R43)", function()
		local loaded = ready()

		assert.are.same({}, greyedOn(loaded, "Pagle"))
		assert.are.same({ "Swap gear", "Lure" }, greyedOn(loaded, "Fishing"))
		assert.are.same({}, greyedOn(loaded, "Announcements"))
		assert.are.same({ "Show goals workable here" }, greyedOn(loaded, "Trackers"))
		assert.are.same({}, greyedOn(loaded, "Look and Feel"))
	end)

	it("greys the Fishing key under Double right-click, and not under the other two (SET-R20)", function()
		local loaded = ready()

		setRow(loaded, "Fishing", "Cast with", "click")
		assert.are.same({ "Fishing key", "Swap gear", "Lure" }, greyedOn(loaded, "Fishing"))

		setRow(loaded, "Fishing", "Cast with", "key")
		assert.are.same({ "Swap gear", "Lure" }, greyedOn(loaded, "Fishing"))
	end)

	it("greys Swap gear while no fishing set is chosen (SET-R20, SET-R61)", function()
		local loaded = ready()
		loaded.client.equipmentSets[3] = { name = "Fishing", items = { [16] = 6256 } }

		setRow(loaded, "Fishing", "Fishing set", 3)
		assert.are.same({ "Lure" }, greyedOn(loaded, "Fishing"))

		setRow(loaded, "Fishing", "Fishing set", loaded.namespaces.Pagle_QoL.NO_FISHING_SET)
		assert.are.same({ "Swap gear", "Lure" }, greyedOn(loaded, "Fishing"))
	end)

	it("greys Lure unless Lures is Only this one (SET-R20)", function()
		local loaded = ready()

		setRow(loaded, "Fishing", "Lures", "one")
		assert.are.same({ "Swap gear" }, greyedOn(loaded, "Fishing"))

		setRow(loaded, "Fishing", "Lures", "off")
		assert.are.same({ "Swap gear", "Lure" }, greyedOn(loaded, "Fishing"))
	end)

	it("greys Keep sound while the audio mix is off (SET-R20, SET-R31)", function()
		local loaded = ready()

		setRow(loaded, "Fishing", "Fishing audio mix", false)
		assert.are.same(
			{ "Swap gear", "Lure", "Keep sound when the game is in the background" },
			greyedOn(loaded, "Fishing")
		)

		setRow(loaded, "Fishing", "Fishing audio mix", true)
		assert.are.same({ "Swap gear", "Lure" }, greyedOn(loaded, "Fishing"))
	end)

	it("greys Button position while the next-action button is off (SET-R20)", function()
		local loaded = ready()

		setRow(loaded, "Fishing", "Show the next-action button", false)
		assert.are.same({ "Swap gear", "Lure", "Button position" }, greyedOn(loaded, "Fishing"))

		setRow(loaded, "Fishing", "Show the next-action button", true)
		assert.are.same({ "Swap gear", "Lure" }, greyedOn(loaded, "Fishing"))
	end)

	it("greys the budget, its sliders and Show every catch in Cozy mode, and nothing else (SET-R30–R32)", function()
		local loaded = ready()

		setRow(loaded, "Announcements", "Cozy mode", true)
		assert.are.same(
			{ "Interruption budget", "Interruptions", "Per", "Show every catch" },
			greyedOn(loaded, "Announcements")
		)

		setRow(loaded, "Announcements", "Cozy mode", false)
		assert.are.same({}, greyedOn(loaded, "Announcements"))
	end)

	it("greys Interruptions and Per while the budget is off, until it is on again (SET-R30, SET-R31)", function()
		local loaded = ready()

		setRow(loaded, "Announcements", "Interruption budget", false)
		assert.are.same({ "Interruptions", "Per" }, greyedOn(loaded, "Announcements"))

		setRow(loaded, "Announcements", "Cozy mode", true)
		setRow(loaded, "Announcements", "Cozy mode", false)
		assert.are.same({ "Interruptions", "Per" }, greyedOn(loaded, "Announcements"))

		setRow(loaded, "Announcements", "Interruption budget", true)
		assert.are.same({}, greyedOn(loaded, "Announcements"))
	end)

	it("makes the Tackle Board's checkbox live once the board is started (SET-R43, SET-R61)", function()
		local loaded = ready()

		loaded.namespaces.Pagle_TackleBoard.Start()

		assert.are.same({}, greyedOn(loaded, "Trackers"))
	end)

	it("greys the keybinding rows while restricted (SET-R93), and the fishing set and its button (QOL-R41)", function()
		local loaded = ready()

		setCombat(loaded, true)
		assert.are.same({}, greyedOn(loaded, "Pagle"))
		assert.are.same({
			"Fishing key",
			"Fishing set",
			"Save what I'm wearing as my fishing set",
			"Swap gear",
			"Lure",
		}, greyedOn(loaded, "Fishing"))
		assert.are.same({}, greyedOn(loaded, "Announcements"))
		assert.are.same({ "Show goals workable here" }, greyedOn(loaded, "Trackers"))
		assert.are.same({}, greyedOn(loaded, "Look and Feel"))

		setCombat(loaded, false)
		assert.are.same({ "Swap gear", "Lure" }, greyedOn(loaded, "Fishing"))
	end)
end)

-- The label of every setting registered on the page named `name`, sorted: what its Defaults button restores, a
-- setting with no default aside (SET-R60).
---@param loaded LoadedAddon
---@param name string
---@return string[]
local function restoredOn(loaded, name)
	local page = loaded.client.settings.page(name)
	local labels = {}
	for _, setting in pairs(loaded.client.settings.variables) do
		if setting.category == page and setting:GetDefaultValue() ~= nil then
			labels[#labels + 1] = setting:GetName()
		end
	end
	table.sort(labels)
	return labels
end

-- Every native value row's shown value on page `name`, by label (equipped reads the slot dropdowns).
---@param loaded LoadedAddon
---@param name string
---@return table<string, any>
local function valuesOn(loaded, name)
	local values = {}
	for _, row in ipairs(loaded.client.settings.show(loaded.client.settings.page(name))) do
		if row.initializer:GetSetting() then
			values[row.initializer:GetName()] = row.frame.value
		end
	end
	return values
end

-- One look besides the default for every slot in the package (SHOP-R25, LED-R110, LED-R113, HNT-R120, STA-R88,
-- TKB-R125). The crest is the Ledger's, in Core's slot (SHOP-R23).
local LOOKS = {
	"core.toaststyle.ripple",
	"core.soundset.gilded",
	"ledger.crest.elwynn",
	"ledger.binding.birch",
	"hunts.notebookcover.oilcloth",
	"hunts.trackerframe.inkwash",
	"stats.trackerframe.brass",
	"tackleboard.trackerframe.corkboard",
}

-- A good's slot: its ID without the last part, but Core's crest slot for the Ledger's zone crests (LED-R113).
---@param good string
---@return string
local function slotOf(good)
	if good:find("^ledger%.crest%.") then
		return "core.crest"
	end
	return (good:match("^(.+)%.[^.]+$"))
end

-- The package over a log in which the Angler bought every look in LOOKS (SHOP-R11): the earned crest too, owned like
-- any purchased ID (SHOP-R30).
---@return LoadedAddon
local function readyWithLooks()
	local entries = history(0)
	for i, good in ipairs(LOOKS) do
		entries[#entries + 1] = purchaseEntry(SERVER_TIME - 2000 + i, good, 0)
	end
	return ready({ globals = { PagleLog = savedLog(entries) } })
end

-- Equips every look in LOOKS, as Use in the Curio Shop does (SHOP-R32).
---@param loaded LoadedAddon
local function wearEveryLook(loaded)
	for _, good in ipairs(LOOKS) do
		assert.is_true(loaded.env.Pagle.SetEquipped(slotOf(good), good))
	end
end

-- The good each slot in LOOKS wears now, by slot.
---@param loaded LoadedAddon
---@return table<string, string>
local function equipped(loaded)
	local worn = {}
	for _, good in ipairs(LOOKS) do
		worn[slotOf(good)] = loaded.env.Pagle.GetEquipped(slotOf(good))
	end
	return worn
end

describe("Each page's Defaults button", function()
	it(
		"restores exactly the value rows settings.md gives each page (SET-R13, SET-R21, SET-R33, SET-R45, SET-R52)",
		function()
			local loaded = ready()

			assert.are.same(
				{ "Clock", "Length unit", "Remind me to /reload when Casts are unsaved" },
				restoredOn(loaded, "Pagle")
			)
			assert.are.same({
				"Auto-loot while fishing",
				"Cast with",
				"Fishing audio mix",
				"Keep sound when the game is in the background",
				"Lure",
				"Lures",
				"Open clams between Casts",
				"Show the next-action button",
			}, restoredOn(loaded, "Fishing"))
			assert.are.same({
				"Animations",
				"Cozy mode",
				"Interruption budget",
				"Interruptions",
				"Per",
				"Show every catch",
				"Sound set",
				"Tell me when a pinned Hunt's window opens",
				"Toast style",
			}, restoredOn(loaded, "Announcements"))
			assert.are.same({
				"Hunts tracker frame",
				"Show goals workable here",
				"Show the Hunts tracker",
				"Show the live tracker",
				"Stats tracker frame",
				"Tackle Board tracker frame",
			}, restoredOn(loaded, "Trackers"))
			assert.are.same({
				"Crests",
				"Hunts tracker frame",
				"Journal binding",
				"Notebook cover",
				"Sound set",
				"Stats tracker frame",
				"Tackle Board tracker frame",
				"Toast style",
			}, restoredOn(loaded, "Look and Feel"))
		end
	)

	it(
		"on the root restores the reminder to off, the length unit to the region's and the Clock to the game's,"
			.. " leaving Show the minimap icon and Show other Anglers on player tooltips (SET-R13, LOG-R69, CORE-R87,"
			.. " CORE-R56, VIEW-R30)",
		function()
			local loaded = ready()
			setRow(loaded, "Pagle", "Remind me to /reload when Casts are unsaved", true)
			setRow(loaded, "Pagle", "Length unit", "cm")
			setRow(loaded, "Pagle", "Clock", "12h")
			setRow(loaded, "Pagle", "Show the minimap icon", false)
			setRow(loaded, "Pagle", "Show other Anglers on player tooltips", false)

			loaded.client.settings.defaults(loaded.client.settings.page("Pagle"))

			assert.are.same({
				["Remind me to /reload when Casts are unsaved"] = false,
				["Length unit"] = "in", -- the fake client's realm is a US one
				["Clock"] = "game",
				["Show the minimap icon"] = false,
				["Show other Anglers on player tooltips"] = false,
			}, valuesOn(loaded, "Pagle"))
			assert.is_nil(loaded.namespaces.Pagle.db.profile.lengthUnit) -- following the region (SET-R13)
			assert.is_nil(loaded.namespaces.Pagle.db.profile.clockFormat) -- following the game's clock (SET-R13)
		end
	)

	it(
		"on Fishing restores QoL's value rows, leaving the fishing set, the key bindings and the button's place (SET-R21)",
		function()
			local loaded = ready()
			local qol = loaded.namespaces.Pagle_QoL
			loaded.client.equipmentSets[3] = { name = "Fishing", items = { [16] = 6256 } }
			loaded.client.boundKeys.PAGLE_FISHING_KEY = { "F" }
			loaded.client.boundKeys.PAGLE_SWAP_GEAR = { "G" }
			local point = { "CENTER", "UIParent", "CENTER", 40, -20 }
			qol.db.profile.indicator.point = point
			for label, value in pairs({
				["Cast with"] = "click",
				["Fishing set"] = 3,
				["Lures"] = "one",
				["Lure"] = qol.LURES[2].itemID,
				["Open clams between Casts"] = false,
				["Fishing audio mix"] = false,
				["Keep sound when the game is in the background"] = true,
				["Auto-loot while fishing"] = false,
				["Show the next-action button"] = false,
			}) do
				setRow(loaded, "Fishing", label, value)
			end

			loaded.client.settings.defaults(loaded.client.settings.page("Fishing"))

			-- qol.md › Settings' defaults: Both, Best I have, the Shiny Bauble, on, on, off, on, on.
			assert.are.same({
				["Cast with"] = "both",
				["Fishing set"] = 3,
				["Lures"] = "best",
				["Lure"] = 6529,
				["Open clams between Casts"] = true,
				["Fishing audio mix"] = true,
				["Keep sound when the game is in the background"] = false,
				["Auto-loot while fishing"] = true,
				["Show the next-action button"] = true,
			}, valuesOn(loaded, "Fishing"))
			assert.are.same({ "F" }, loaded.client.boundKeys.PAGLE_FISHING_KEY)
			assert.are.same({ "G" }, loaded.client.boundKeys.PAGLE_SWAP_GEAR)
			assert.are.equal(point, qol.db.profile.indicator.point)
		end
	)

	it("on Announcements restores the companion row to on once the hint switch is on (SET-R33, HNT-R170)", function()
		local loaded = ready({ hintOn = true })
		setRow(loaded, "Announcements", "Remind me about the Pagle companion", false)
		assert.is_false(loaded.namespaces.Pagle_Hunts.db.profile.companionHint)

		loaded.client.settings.defaults(loaded.client.settings.page("Announcements"))

		assert.is_true(valuesOn(loaded, "Announcements")["Remind me about the Pagle companion"])
		assert.is_true(loaded.namespaces.Pagle_Hunts.db.profile.companionHint)
	end)

	it("on Announcements restores every row, the two looks and Hunts' row included (SET-R33)", function()
		local loaded = readyWithLooks()
		for label, value in pairs({
			["Cozy mode"] = true,
			["Interruption budget"] = false,
			["Interruptions"] = 7,
			["Per"] = 10,
			["Show every catch"] = false,
			["Animations"] = false,
			["Tell me when a pinned Hunt's window opens"] = true,
		}) do
			setRow(loaded, "Announcements", label, value)
		end
		wearEveryLook(loaded)

		loaded.client.settings.defaults(loaded.client.settings.page("Announcements"))

		-- SET-R30's and SET-R32's defaults.
		assert.are.same({
			["Cozy mode"] = false,
			["Interruption budget"] = true,
			["Interruptions"] = 20,
			["Per"] = 5,
			["Show every catch"] = true,
			["Animations"] = true,
			["Tell me when a pinned Hunt's window opens"] = false,
		}, valuesOn(loaded, "Announcements"))
		assert.are.equal(300, loaded.namespaces.Pagle.db.profile.announcements.budget.window) -- stored in seconds
		assert.are.same({
			["core.toaststyle"] = "core.toaststyle.page",
			["core.soundset"] = "core.soundset.driftwood",
			["core.crest"] = "ledger.crest.elwynn",
			["ledger.binding"] = "ledger.binding.birch",
			["hunts.notebookcover"] = "hunts.notebookcover.oilcloth",
			["hunts.trackerframe"] = "hunts.trackerframe.inkwash",
			["stats.trackerframe"] = "stats.trackerframe.brass",
			["tackleboard.trackerframe"] = "tackleboard.trackerframe.corkboard",
		}, equipped(loaded))
		assert.is_true(loaded.env.Pagle.IsOwned("core.toaststyle.ripple")) -- no longer used, still owned (SET-R60)
	end)

	it("on Trackers restores the three checkboxes and the three frames, leaving the dock's place (SET-R45)", function()
		local loaded = readyWithLooks()
		local core = loaded.namespaces.Pagle
		for label, value in pairs({
			["Show the Hunts tracker"] = false,
			["Show the live tracker"] = true,
			["Show goals workable here"] = false, -- greyed out, the board unstarted: restored too (SET-R60)
		}) do
			setRow(loaded, "Trackers", label, value)
		end
		wearEveryLook(loaded)
		local point = { "TOPRIGHT", "UIParent", "TOPRIGHT", -80, -300 }
		core.db.profile.dock.point = point

		loaded.client.settings.defaults(loaded.client.settings.page("Trackers"))

		assert.are.same({
			["Show the Hunts tracker"] = true,
			["Show the live tracker"] = false,
			["Show goals workable here"] = true,
		}, valuesOn(loaded, "Trackers"))
		assert.are.same({
			["core.toaststyle"] = "core.toaststyle.ripple",
			["core.soundset"] = "core.soundset.gilded",
			["core.crest"] = "ledger.crest.elwynn",
			["ledger.binding"] = "ledger.binding.birch",
			["hunts.notebookcover"] = "hunts.notebookcover.oilcloth",
			["hunts.trackerframe"] = "hunts.trackerframe.none",
			["stats.trackerframe"] = "stats.trackerframe.none",
			["tackleboard.trackerframe"] = "tackleboard.trackerframe.none",
		}, equipped(loaded))
		assert.are.equal(point, core.db.profile.dock.point)
	end)

	it("on Look and Feel puts every slot shown back to its default good, each look still owned (SET-R52)", function()
		local loaded = readyWithLooks()
		wearEveryLook(loaded)

		loaded.client.settings.defaults(loaded.client.settings.page("Look and Feel"))

		assert.are.same({
			["core.toaststyle"] = "core.toaststyle.page",
			["core.soundset"] = "core.soundset.driftwood",
			["core.crest"] = "core.crest.plain",
			["ledger.binding"] = "ledger.binding.field",
			["hunts.notebookcover"] = "hunts.notebookcover.leather",
			["hunts.trackerframe"] = "hunts.trackerframe.none",
			["stats.trackerframe"] = "stats.trackerframe.none",
			["tackleboard.trackerframe"] = "tackleboard.trackerframe.none",
		}, equipped(loaded))
		for _, good in ipairs(LOOKS) do
			assert.is_true(loaded.env.Pagle.IsOwned(good))
		end
	end)

	it("on Look and Feel leaves the stored look of a Module that isn't On (SET-R52, SHOP-R32)", function()
		local entries = history(0)
		entries[#entries + 1] = purchaseEntry(SERVER_TIME - 2000, "hunts.notebookcover.oilcloth", 0)
		local loaded = ready({
			off = { "Hunts" },
			globals = {
				PagleLog = savedLog(entries),
				PagleDB = {
					profiles = {
						Default = { appearance = { ["hunts.notebookcover"] = "hunts.notebookcover.oilcloth" } },
					},
				},
			},
		})

		loaded.client.settings.defaults(loaded.client.settings.page("Look and Feel"))

		assert.are.equal(
			"hunts.notebookcover.oilcloth",
			loaded.namespaces.Pagle.db.profile.appearance["hunts.notebookcover"]
		)
	end)
end)

-- The rows whose options are names the client gives, not Pagle's strings: the lure table's items (QOL-R54) and the
-- character's own equipment sets (QOL-R40).
local CLIENT_NAMED = { Lure = true, ["Fishing set"] = true }

-- Every string the tree draws, each once, as { text, what }: `what` is "row" for a row's label, a button's caption
-- and a header (SET-R2), "text" for everything else (tooltips, notes, paragraphs, status texts, keys, values and
-- options). A status line's version is the TOC's, not a string, so it is left out.
---@param loaded LoadedAddon
---@param strings { text: string, what: string }[]
---@param seen table<string, true>
local function collectStrings(loaded, strings, seen)
	local settings = loaded.client.settings
	local function add(text, what)
		if type(text) == "string" and text ~= "" and not seen[what .. text] then
			seen[what .. text] = true
			strings[#strings + 1] = { text = text, what = what }
		end
	end
	for _, category in ipairs(settings.categories) do
		add(category.name, "row")
		for _, row in ipairs(settings.show(category)) do
			local written = asWritten(loaded, row, nil)
			local template = row.initializer:GetTemplate()
			if written[1] == "status" then
				add(written[2], "text")
				add(written.state, "text")
				add(written.button, "text")
			else
				if written[1] ~= "text" then
					add(written[2], "row")
				end
				add(written.caption, "row")
				add(written.tip, "text")
				if template ~= "SettingButtonControlTemplate" then
					for _, text in ipairs(settings.textsOf(row.frame)) do
						add(text, "text")
					end
				end
				if not CLIENT_NAMED[written[2]] then
					add(row.frame.valueLabel, "text")
				end
			end
			local options = row.initializer:GetOptions()
			if type(options) == "function" and not CLIENT_NAMED[written[2]] then
				for _, option in ipairs(options()) do
					add(option.label, "text")
				end
			elseif template == "PagleSettingsSlotRowTemplate" then
				for _, choice in ipairs(settings.optionValues(row)) do
					add(choice:match("=(.*)$"), "text")
				end
			end
		end
	end
end

-- Every string the tree draws in the states that change its texts: every Module On before and after Start, with a
-- slider's value shown, and no Module On (SET-R10, SET-R11).
---@return { text: string, what: string }[] strings
---@return LoadedAddon[] loads the packages they were drawn from
local function everyString()
	local strings, seen = {}, {}
	local loaded = ready()
	collectStrings(loaded, strings, seen)
	loaded.namespaces.Pagle_TackleBoard.Start()
	collectStrings(loaded, strings, seen)
	local none = ready({ off = { "Ledger", "Hunts", "Stats", "TackleBoard", "QoL" } })
	collectStrings(none, strings, seen)
	-- the companion hint's row, only once its switch is on (HNT-R172)
	local hint = ready({ hintOn = true })
	collectStrings(hint, strings, seen)
	return strings, { loaded, none, hint }
end

-- A Lua pattern matching what `format` draws once filled, capturing each filled part, and each part's specifier
-- ("d" or "s"), in order; nil for a string with no %d or %s.
---@param format string
---@return string?
---@return string[]
local function patternOf(format)
	local pattern, kinds, at = "^", {}, 1
	while true do
		local from, to, kind = format:find("%%[%d%.]*([ds])", at)
		local literal = format:sub(at, (from or #format + 1) - 1)
		pattern = pattern .. literal:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
		if not from then
			break
		end
		pattern = pattern .. (kind == "d" and "(%-?%d+)" or "(.+)")
		kinds[#kinds + 1] = kind
		at = to + 1
	end
	return #kinds > 0 and pattern .. "$" or nil, kinds
end

-- Every string in the string tables of the addons `loads` loaded (CORE-R8), nested tables included.
---@param loads LoadedAddon[]
---@return string[]
local function stringTables(loads)
	local found = {}
	local function walk(value)
		if type(value) == "string" then
			found[#found + 1] = value
		elseif type(value) == "table" then
			for _, item in pairs(value) do
				walk(item)
			end
		end
	end
	for _, loaded in ipairs(loads) do
		for _, ns in pairs(loaded.namespaces) do
			walk(ns.L)
		end
	end
	return found
end

-- Whether `text` is a string from a string table, or one of its formats filled with numbers and, for each %s, a
-- string from a string table itself ("Open %s" with "Hunts").
---@param text string
---@param tables string[]
---@return boolean
local function fromStringTable(text, tables)
	local plain = {}
	for _, known in ipairs(tables) do
		plain[known] = true
	end
	if plain[text] then
		return true
	end
	for _, known in ipairs(tables) do
		local pattern, kinds = patternOf(known)
		local filled = pattern and { text:match(pattern) } or {}
		local fits = #filled > 0
		for i, part in ipairs(filled) do
			fits = fits and (kinds[i] == "d" or plain[part] == true)
		end
		if fits then
			return true
		end
	end
	return false
end

-- Words CONTEXT.md's glossary lists to avoid, as Settings could say them: whole words or phrases, any case. "shop" and
-- "report" are avoided alone, so "Curio Shop" and "Field report" are taken out first. Words that are also plain
-- English the tree uses in another sense ("reset", "item", "category", "tracker") aren't listed.
local AVOIDED = {
	"plugin",
	"sub-addon",
	"framework",
	"base module",
	"angler's ledger",
	"journal module",
	"codex",
	"encyclopedia",
	"quests?",
	"bounty",
	"challenges?",
	"dailies",
	"daily",
	"weekly",
	"automation",
	"helpers",
	"utility module",
	"metrics",
	"database",
	"event store",
	"loot table",
	"data dump",
	"export",
	"fishing level",
	"rebirth",
	"paragon",
	"rested xp",
	"zone level",
	"fish level",
	"size roll",
	"weight",
	"size class",
	"trophy",
	"legendary",
	"notifications?",
	"alerts?",
	"popups?",
	"mini toast",
	"whisper",
	"rate limit",
	"throttle",
	"cooldown",
	"quiet mode",
	"do not disturb",
	"recap",
	"session stats",
	"catch%-up toast",
	"backfill",
	"welcome screen",
	"currency",
	"gold",
	"store",
	"trading post",
	"bait shop",
	"shop",
	"report",
	"one key",
	"cast key",
	"interact key",
	"action key",
	"fishing mode",
	"reminder",
	"warning",
	"custom hunt",
	"streak",
	"tackle box",
	"drop rate",
	"loot chance",
	"catch rate",
	"pity",
	"overdue",
}

-- Each avoided word `text` says.
---@param text string
---@return string[]
local function avoidedIn(text)
	local said = {}
	local lower = text:lower():gsub("curio shop", ""):gsub("field report", "")
	for _, word in ipairs(AVOIDED) do
		if lower:find("%f[%w]" .. word .. "%f[^%w]") then
			said[#said + 1] = word
		end
	end
	return said
end

-- The capitalised words a row may have after its first: CONTEXT.md's terms and names, which keep their capitals.
local NAMES = {
	AddOns = true,
	Anglers = true,
	Board = true,
	Casts = true,
	Catches = true,
	Coins = true,
	Curio = true,
	Dry = true,
	Field = true,
	Fish = true,
	Hunt = true,
	Hunts = true,
	["I'm"] = true,
	Journal = true,
	Modules = true,
	Pagle = true,
	QoL = true,
	Shop = true,
	Stats = true,
	Tackle = true,
}

-- Each word of row label `text`, after its first, written with a capital it shouldn't have in sentence case.
---@param text string
---@return string[]
local function titleCased(text)
	local wrong, first = {}, true
	for word in text:gmatch("%S+") do
		local bare = word:gsub("^%p+", ""):gsub("[%p]+$", ""):gsub("'s$", "")
		if not first and bare:match("^%u") and not NAMES[bare] then
			wrong[#wrong + 1] = word
		end
		first = false
	end
	return wrong
end

describe("The Settings tree's strings", function()
	local strings, loads = everyString()

	it("all come from the string tables (CORE-R8)", function()
		local tables = stringTables(loads)
		local stray = {}
		for _, string in ipairs(strings) do
			if not fromStringTable(string.text, tables) then
				stray[#stray + 1] = string.text
			end
		end

		assert.are.same({}, stray)
	end)

	it("use only CORE-R9's characters", function()
		local outside = {}
		for _, string in ipairs(strings) do
			for _, what in ipairs(glyphsOutside(string.text)) do
				outside[#outside + 1] = what .. " in " .. string.text
			end
		end

		assert.are.same({}, outside)
	end)

	it("use CONTEXT.md's terms, no word it says to avoid", function()
		local said = {}
		for _, string in ipairs(strings) do
			for _, word in ipairs(avoidedIn(string.text)) do
				said[#said + 1] = word .. " in " .. string.text
			end
		end

		assert.are.same({}, said)
	end)

	it("write every row in sentence case, as settings.md's tree does (SET-R2)", function()
		local wrong = {}
		for _, string in ipairs(strings) do
			if string.what == "row" and string.text ~= "Look and Feel" then -- a page's name (CORE-R40)
				if not string.text:match("^%u") then
					wrong[#wrong + 1] = string.text
				end
				for _, word in ipairs(titleCased(string.text)) do
					wrong[#wrong + 1] = word .. " in " .. string.text
				end
			end
		end

		assert.are.same({}, wrong)
	end)

	it("are checked for real: a stray, a box glyph, an avoided word and a title-cased row are each caught", function()
		local tables = stringTables(loads)
		assert.is_true(fromStringTable("12 more in the Curio Shop", tables))
		assert.is_true(fromStringTable("Open Hunts", tables))
		assert.is_false(fromStringTable("Open Sesame", tables))
		assert.is_false(fromStringTable("Turn Modules on or off.", tables))
		assert.are.same({ "U+2605" }, glyphsOutside("Records ★"))
		assert.are.same({ "popups?" }, avoidedIn("No popups"))
		assert.are.same({}, avoidedIn("Open the Curio Shop"))
		assert.are.same({ "Mode" }, titleCased("Cozy Mode"))
	end)
end)

describe("The Settings tour stops", function()
	-- Core's Settings stops in tour order, each as "<name>: <the page its show opens>".
	---@param loaded LoadedAddon
	---@return string[]
	local function stops(loaded)
		local core = loaded.namespaces.Pagle
		local out = {}
		for _, stop in ipairs(core.tourStops:List(core.Modules:Modules(), "core")) do
			if stop.name:match("^core%.settings") then
				stop.show()
				local opened = openedNames(loaded)
				out[#out + 1] = stop.name .. ": " .. tostring(opened[#opened])
				stop.hide()
				assert.is_false(loaded.client.settings.panel.shown)
			end
		end
		return out
	end

	it("are the root and every registered page, in the panel's order (CORE-R68)", function()
		assert.are.same({
			"core.settings: Pagle",
			"core.settings.fishing: Fishing",
			"core.settings.announcements: Announcements",
			"core.settings.trackers: Trackers",
			"core.settings.look: Look and Feel",
		}, stops(ready()))
	end)

	it("leave out a page that isn't registered (CORE-R68, SET-R1)", function()
		assert.are.same({
			"core.settings: Pagle",
			"core.settings.announcements: Announcements",
			"core.settings.look: Look and Feel",
		}, stops(ready({ off = { "Hunts", "Stats", "TackleBoard", "QoL" } })))
	end)
end)
