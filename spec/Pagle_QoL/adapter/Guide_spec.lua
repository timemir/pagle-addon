-- QoL's Field guide steps, Casting and Fishing clothes (ONB-R21, ONB-R32, ONB-R33, ONB-R90, ONB-R91, ONB-R100,
-- ONB-R101, ONB-R105), and the `qol.lure` Margin note (ONB-R52), driven through FakePagle: its guide runs each step's
-- build on QoL's client with plain stand-in widgets (fake.guidePages), and the fake client's game side.

local FISHING_POLE, SWORD, HAT, GLOVES = 6256, 25, 33, 34
local FISHING, PREVIOUS = 3, 5
local HAT_ICON, GLOVES_ICON, POLE_ICON, SWORD_ICON, SET_ICON = 133100, 132900, 132932, 135274, 132940
local FISHING_ICON, BAUBLE_ICON = 136245, 134335
local SHINY_BAUBLE = 6529
local CAST = "SPELL Fishing"
local FIELD = "Interface\\AddOns\\Pagle\\media\\field\\Field"

-- QoL loaded against FakePagle and logged in: F bound to the Fishing key and G to Swap gear, a sword in hand, no sets.
-- `before(fake, client, loaded)` runs after the load and before PLAYER_LOGIN.
---@param before fun(fake: FakePagle, client: FakeClient, loaded: LoadedAddon)?
---@return FakePagle fake
---@return FakeClient client
---@return LoadedAddon loaded
local function start(before)
	local fake = newFakePagle()
	local loaded = fake.load("Pagle_QoL")
	local client = loaded.client
	client.boundKeys.PAGLE_FISHING_KEY = { "F" }
	client.boundKeys.PAGLE_SWAP_GEAR = { "G" }
	client.mainHand = SWORD
	client.itemIcons[HAT], client.itemIcons[GLOVES] = HAT_ICON, GLOVES_ICON
	client.itemIcons[SHINY_BAUBLE] = BAUBLE_ICON
	if before then
		before(fake, client, loaded)
	end
	fake.login()
	fake.fireGameEvent("PLAYER_LOGIN")
	return fake, client, loaded
end

-- Opens the guide at step `id` and returns its two pages as its build drew them.
---@param fake FakePagle
---@param id string
---@return table left
---@return table right
local function open(fake, id)
	fake.guide:Open(id)
	local pages = assert(fake.guidePages[id], "no pages for " .. id)
	return pages.left, pages.right
end

-- Every widget under `widget`, depth first, `widget` itself left out.
---@param widget table
---@param into table[]?
---@return table[]
local function descendants(widget, into)
	into = into or {}
	for _, child in ipairs(widget.children) do
		into[#into + 1] = child
		descendants(child, into)
	end
	return into
end

-- Whether `widget` shows: it and every parent up to the page.
---@param widget table
---@return boolean
local function showing(widget)
	while widget do
		if not widget.shown then
			return false
		end
		widget = widget.parent
	end
	return true
end

-- The texts of the font strings showing under `widget`, depth first.
---@param widget table
---@return string[]
local function texts(widget)
	local found = {}
	for _, region in ipairs(descendants(widget)) do
		if region.kind == "FontString" and showing(region) and region.text and region.text ~= "" then
			found[#found + 1] = region.text
		end
	end
	return found
end

-- The font string under `widget` reading `text`; an error when there is none.
---@param widget table
---@param text string
---@return table
local function textReading(widget, text)
	for _, region in ipairs(descendants(widget)) do
		if region.kind == "FontString" and region.text == text then
			return region
		end
	end
	error("no font string reads " .. text)
end

-- Whether a font string under `widget` that shows reads `text`.
---@param widget table
---@param text string
---@return boolean
local function says(widget, text)
	for _, said in ipairs(texts(widget)) do
		if said == text then
			return true
		end
	end
	return false
end

-- Asserts that a font string under `widget` that shows reads `text`; failing, it lists what shows there.
---@param widget table
---@param text string
local function assertSays(widget, text)
	assert.are.equal(text, says(widget, text) and text or table.concat(texts(widget), " | "))
end

-- The widgets under `widget` for which `match` holds, depth first.
---@param widget table
---@param match fun(region: table): boolean
---@return table[]
local function all(widget, match)
	local found = {}
	for _, region in ipairs(descendants(widget)) do
		if match(region) then
			found[#found + 1] = region
		end
	end
	return found
end

-- The choice cards nav.ChoiceCard made on a page, in order.
---@param page table
---@return table[]
local function cardsOn(page)
	return all(page, function(region)
		return region.title ~= nil and region.SetChosen ~= nil
	end)
end

-- The card titled `title` on a page.
---@param page table
---@param title string
---@return table
local function card(page, title)
	for _, made in ipairs(cardsOn(page)) do
		if made.title == title then
			return made
		end
	end
	error("no card " .. title)
end

-- The binding field nav.BindingField made on a page for `action`.
---@param page table
---@param action string
---@return table
local function field(page, action)
	return assert(
		all(page, function(region)
			return region.action == action
		end)[1],
		"no field for " .. action
	)
end

-- The next-action sequence's faces on the Casting step's left page, in order: each frame drawn on the Field atlas's
-- bezel, as its shown texts (its label, then its key).
---@param left table
---@return string[][]
local function sequence(left)
	local faces = {}
	for _, child in ipairs(left.children) do
		local ring = child.children[1]
		if child.kind == "Frame" and ring and ring.texture == FIELD then
			faces[#faces + 1] = texts(child)
		end
	end
	return faces
end

-- Where `region` sits on its parent: its top left's x and y down, as `at` put it.
---@param region table
---@return number[]
local function placeOf(region)
	local point = region.points[1]
	return { point[4], -point[5] }
end

-- The Casting step's checkbox: the Part sprites "check" and "check-off", and which shows.
---@param right table
---@return "on"|"off"
local function checkState(right)
	local on = all(right, function(region)
		return region.sprite == "check"
	end)[1]
	local off = all(right, function(region)
		return region.sprite == "check-off"
	end)[1]
	assert(on and off, "no checkbox")
	assert(on.shown ~= off.shown, "the checkbox shows both states")
	return on.shown and "on" or "off"
end

describe("QoL's Field guide steps", function()
	it(
		"registers Casting at 30 and Fishing clothes at 40, whose skip link goes on to the next step (ONB-R21, ONB-R33)",
		function()
			local fake = start()

			local steps = {}
			for _, entry in ipairs(fake.guideSteps:List()) do
				local step = entry.step
				steps[#steps + 1] = { entry.owner, step.id, step.order, step.ribbon, step.skipLabel, step.skipTo }
			end
			assert.are.same({
				{ "Core", "welcome", 10, "Welcome", "I’ll find my own way", "close" },
				{ "Core", "box", 20, "What’s in the box" },
				{ "QoL", "casting", 30, "Casting" },
				{ "QoL", "clothes", 40, "Fishing clothes", "I don’t keep fishing clothes", "next" },
				{ "Core", "moments", 50, "Moments" },
				{ "Core", "off", 90, "Off you go" },
			}, steps)

			fake.guide:Open("clothes")
			fake.guide:Skip()
			assert.are.equal("moments", fake.guide:Current().step.id)
		end
	)

	it("has neither step with QoL off: it never loads, so it registers nothing (ONB-R101, CORE-R17)", function()
		local fake = newFakePagle()
		fake.login()

		local ids = {}
		for i, entry in ipairs(fake.guideSteps:List()) do
			ids[i] = entry.step.id
		end
		assert.are.same({ "welcome", "box", "moments", "off" }, ids)
	end)

	it("loads on a Core without RegisterGuideStep, registering no step (ONB-R90)", function()
		local fake = newFakePagle()
		fake.ns.ModuleHandle.RegisterGuideStep = nil
		local loaded = fake.load("Pagle_QoL")
		fake.login()
		fake.fireGameEvent("PLAYER_LOGIN")

		assert.is_table(loaded.ns.Module)
		assert.are.equal(4, fake.guideSteps:Count())
	end)

	it("gives Core QoL's line for What's in the box, def.guideBlurb (ONB-R91)", function()
		local fake = start()

		assert.are.equal(
			"The Fishing key, your fishing clothes, lures and clams: one press, one action.",
			fake.registry:Modules()[1].def.guideBlurb
		)
	end)
end)

describe("The Casting step (ONB-R32)", function()
	it("reads the kit's copy on both pages, with the double right-click's note on the left", function()
		local fake = start()

		local left, right = open(fake, "casting")

		for _, text in ipairs({
			"Casting",
			"One key for the whole cast",
			"Press the Fishing key and Pagle does the one next thing, then waits for your next press. It never does two things at once, and it never does anything on its own.",
			"your fishing clothes go on",
			"the best lure you have",
			"out it goes",
			"when the bobber dips",
			"Steps you don’t need are passed over: no fishing clothes saved, no gear step; a lure already on, no lure step. A small button by the water shows what your next press will do.",
		}) do
			assertSays(left, text)
		end
		local thens = all(left, function(region)
			return region.kind == "FontString" and region.text == "»"
		end)
		assert.are.equal(3, #thens)
		local note = all(left, function(region)
			return region.text and region.x ~= nil
		end)[1]
		assert.are.same(
			{ "A *double right-click* on the water casts and reels too, but never changes your clothes.", 56, 400, 300 },
			{ note.text, note.x, note.y, note.w }
		)
		assertSays(right, "Your choice")
		assertSays(right, "How would you like to cast?")
	end)

	it(
		"draws Gear » Lure » Cast » Reel on the next-action button's own face, the Fishing key on its caps (QOL-R70, QOL-R71)",
		function()
			local fake = start(function(_, client, loaded)
				client.equipmentSets[FISHING] = { name = "Fishing", icon = SET_ICON, items = { [16] = FISHING_POLE } }
				loaded.ns.db.global.gear[PLAYER_GUID] = { setID = FISHING, name = "Fishing" }
			end)

			local left = open(fake, "casting")

			assert.are.same({ { "Gear", "F" }, { "Lure", "F" }, { "Cast", "F" }, { "Reel", "F" } }, sequence(left))
			local icons = {}
			for _, child in ipairs(left.children) do
				if child.kind == "Frame" and child.children[1] and child.children[1].texture == FIELD then
					icons[#icons + 1] = child.children[2].texture
				end
			end
			-- The fishing set's icon for Gear, the chosen lure's for Lure, the Fishing spell's for Cast and Reel.
			assert.are.same({ SET_ICON, BAUBLE_ICON, FISHING_ICON, FISHING_ICON }, icons)
		end
	)

	it("shows no key on the caps under Double right-click, as the button shows none then (QOL-R70)", function()
		local fake, _, loaded = start()
		loaded.ns.SetInput("click")

		local left = open(fake, "casting")

		assert.are.same({ { "Gear" }, { "Lure" }, { "Cast" }, { "Reel" } }, sequence(left))
	end)

	it("offers the three Input cards, the current one chosen and Both tagged the usual (QOL-R12)", function()
		local fake = start()

		local _, right = open(fake, "casting")

		local cards = {}
		for i, made in ipairs(cardsOn(right)) do
			cards[i] = { made.title, made.line, made.tag, made.chosen, made.width, made.height, unpack(placeOf(made)) }
		end
		assert.are.same({
			{
				"The Fishing key",
				"One key does the next thing, clothes and lures included.",
				nil,
				false,
				382,
				61.8,
				30,
				81.3,
			},
			{
				"Double right-click",
				"Right-click twice, as you would anyway. No key to give up.",
				nil,
				false,
				382,
				61.8,
				30,
				151,
			},
			{
				"Both",
				"The key when you want it, the mouse when you don’t.",
				"the usual",
				true,
				382,
				61.8,
				30,
				220.8,
			},
		}, cards)
	end)

	it(
		"sets Input as /pagle qol input does, without printing, at each card's click (ONB-R32, QOL-R17, QOL-R18)",
		function()
			local fake, client, loaded = start()
			local left, right = open(fake, "casting")

			card(right, "Double right-click"):Click()
			assert.are.equal("click", loaded.ns.db.profile.input)
			-- At once: the key is disarmed (QOL-R12), and the sample caps lose their key.
			assert.is_nil(client.overrideAction("F"))
			assert.are.same({ "Lure" }, sequence(left)[2])
			assert.are.same({ false, true, false }, {
				card(right, "The Fishing key").chosen,
				card(right, "Double right-click").chosen,
				card(right, "Both").chosen,
			})

			card(right, "The Fishing key"):Click()
			assert.are.equal("key", loaded.ns.db.profile.input)
			assert.are.equal(CAST, client.overrideAction("F"))

			card(right, "Both"):Click()
			assert.are.equal("both", loaded.ns.db.profile.input)
			assert.are.same({}, loaded.printed)
		end
	)

	it("binds the Fishing key through Core's field, greyed under Double right-click (ONB-R32, ONB-R40)", function()
		local fake, _, loaded = start()
		local _, right = open(fake, "casting")

		local fishing = field(right, "PAGLE_FISHING_KEY")
		assert.are.equal("Fishing key", fishing.label)
		assert.are.same({ 30, 298.5 }, placeOf(fishing))
		assert.is_false(fishing.greyed)

		card(right, "Double right-click"):Click()
		assert.is_true(fishing.greyed)
		card(right, "Both"):Click()
		assert.is_false(fishing.greyed)

		-- Input changed elsewhere shows when the step is next shown (ONB-R44).
		loaded.ns.SetInput("click")
		fake.guide:Next()
		fake.guide:Back()
		assert.is_true(fishing.greyed)
		assert.is_true(card(right, "Double right-click").chosen)
	end)

	it("re-reads the field's bindings each time the step shows (ONB-R44)", function()
		local fake = start()
		local _, right = open(fake, "casting")
		local fishing = field(right, "PAGLE_FISHING_KEY")
		local shown = fishing.refreshed

		fake.guide:Next()
		fake.guide:Back()

		assert.are.equal(shown + 1, fishing.refreshed)
	end)

	it(
		"has the next-action button's checkbox, its tooltip the line under it, as its setting (ONB-R32, QOL-R72)",
		function()
			local fake, _, loaded = start(function(_, client)
				client.mainHand = FISHING_POLE
			end)
			local _, right = open(fake, "casting")
			assertSays(right, "Show the next-action button")
			assertSays(right, "Shows what your next press will do. Shift-drag to move.")
			assert.are.equal("on", checkState(right))

			local row = textReading(right, "Show the next-action button").parent
			row:Click()

			assert.is_false(loaded.ns.db.profile.indicator.shown)
			assert.are.equal("off", checkState(right))
			-- It hides at once (QOL-R25): the button made at login is hidden.
			local button
			for _, frame in ipairs(loaded.client.frames) do
				if frame.Icon and frame.HotKey then
					button = frame
				end
			end
			assert.is_false(assert(button).shown)

			row:Click()
			assert.is_true(loaded.ns.db.profile.indicator.shown)
			assert.are.equal("on", checkState(right))
		end
	)

	it("rests the Fishing key while QoL stands down: its line under the title, the field greyed (ONB-R100)", function()
		local fake = start(function(_, client)
			client.addons.Angleur = { metadata = { Title = "Angleur" } }
		end)

		local _, right = open(fake, "casting")

		assert.is_true(
			says(
				right,
				"Pagle’s Fishing key is resting while Angleur has it. You can still cast with a double right-click."
			)
		)
		assert.is_true(field(right, "PAGLE_FISHING_KEY").greyed)
	end)

	it("has no resting line while QoL doesn't stand down (ONB-R100)", function()
		local fake = start()

		local _, right = open(fake, "casting")

		for _, text in ipairs(texts(right)) do
			assert.is_nil(text:find("resting", 1, true))
		end
	end)
end)

describe("The Fishing clothes step (ONB-R33)", function()
	-- The set cards on the left page, each { name, its slots' icons }.
	local function setCards(left)
		local cards = {}
		for _, child in ipairs(left.children) do
			if child.panel == "card" then
				local icons = {}
				for _, region in ipairs(child.children) do
					if region.kind == "Texture" and region.sprite == nil then
						icons[#icons + 1] = region.shown and region.texture or false
					end
				end
				cards[#cards + 1] = { texts(child)[1], icons }
			end
		end
		return cards
	end

	it("reads the kit's copy on both pages", function()
		local fake = start()

		local left, right = open(fake, "clothes")

		for _, text in ipairs({
			"Fishing clothes",
			"Your hat, your pole",
			"If you keep a fishing outfit, Pagle can put it on for you: the Fishing key’s first press at the water changes your clothes, and what you were wearing is kept, ready to put back.",
			"what you wore before",
			"your fishing clothes",
			"one key",
			"Both are ordinary equipment sets, so you’ll see them in your character sheet too. When you walk away with your pole still in hand, a small note reminds you how to change back. Pagle never changes your clothes without a press.",
		}) do
			assertSays(left, text)
		end
		for _, text in ipairs({
			"If you have a fishing outfit",
			"Put it on, then save it",
			"Wear your fishing hat, gloves and pole now, then press the button. You can do this later from Settings » Fishing.",
			"Save what I’m wearing as my fishing set",
			"or use a set you made",
			"Needs two free equipment set slots: one for your fishing clothes and one for Pagle Previous.",
			"If you walk off still dressed for it",
		}) do
			assertSays(right, text)
		end
		assert.are.equal(1, #all(left, function(region)
			return region.sprite == "arrows"
		end))
	end)

	it("draws the two sets with the drawn placeholders while they don't exist (ONB-R33)", function()
		local fake = start()

		local left = open(fake, "clothes")

		assert.are.same({
			{
				"Pagle Previous",
				{
					"Interface\\Icons\\INV_Helmet_01",
					"Interface\\Icons\\INV_Chest_Chain_05",
					"Interface\\Icons\\INV_Gauntlets_04",
					"Interface\\Icons\\INV_Sword_04",
				},
			},
			{
				"Pagle Fishing",
				{
					"Interface\\Icons\\INV_Misc_Bandana_03",
					"Interface\\Icons\\INV_Shirt_05",
					"Interface\\Icons\\INV_Gauntlets_05",
					"Interface\\Icons\\INV_Fishingpole_02",
				},
			},
		}, setCards(left))
		-- Each slot in the guide atlas's ring.
		assert.are.equal(8, #all(left, function(region)
			return region.sprite == "slot"
		end))
	end)

	it(
		"shows the real items once the sets exist: Pagle Previous and the chosen set, an empty slot empty (ONB-R33)",
		function()
			local fake = start(function(_, client, loaded)
				client.equipmentSets[PREVIOUS] = { name = "Pagle Previous", items = { [1] = HAT, [16] = SWORD } }
				client.equipmentSets[FISHING] =
					{ name = "Fishing", icon = SET_ICON, items = { [10] = GLOVES, [16] = FISHING_POLE } }
				loaded.ns.db.global.gear[PLAYER_GUID] = { setID = FISHING, name = "Fishing" }
			end)

			local left = open(fake, "clothes")

			assert.are.same({
				{ "Pagle Previous", { HAT_ICON, false, false, SWORD_ICON } },
				{ "Fishing", { false, false, GLOVES_ICON, POLE_ICON } },
			}, setCards(left))
		end
	)

	it("saves what's worn with Save, as the Fishing page's button does, and draws the sets saved (QOL-R41)", function()
		local fake, client, loaded = start(function(_, client)
			client.worn[1] = HAT
		end)
		local left, right = open(fake, "clothes")

		textReading(right, "Save what I’m wearing as my fishing set").parent.parent:Click()

		assert.are.same({
			"clear ignored",
			"create Pagle Fishing " .. FISHING_ICON,
			"clear ignored",
			"create Pagle Previous " .. SWORD_ICON,
		}, client.equipmentSetCalls)
		assert.are.same({ setID = 0, name = "Pagle Fishing" }, loaded.env.PagleQoLDB.global.gear[PLAYER_GUID])
		assert.are.same({
			{ "Pagle Previous", { HAT_ICON, false, false, SWORD_ICON } },
			{ "Pagle Fishing", { HAT_ICON, false, false, SWORD_ICON } },
		}, setCards(left))
		assertSays(right, "Pagle Fishing")
	end)

	it(
		"shows Save's message under it in red when the slots run short, until the step is left (ONB-R105, QOL-R42)",
		function()
			local fake, client, loaded = start(function(_, client)
				for setID = 0, 8 do
					client.equipmentSets[setID] = { name = "Set " .. setID, items = {} }
				end
			end)
			local _, right = open(fake, "clothes")
			local save = textReading(right, "Save what I’m wearing as my fishing set").parent.parent
			-- It stays enabled: pressing it runs QOL-R42, which says why.
			assert.is_true(save:IsEnabled())

			save:Click()

			local line = "Pagle: needs two free equipment set slots for Pagle Fishing and Pagle Previous."
			assert.are.same({ line }, loaded.printed)
			assert.are.same({}, client.equipmentSetCalls)
			local message = textReading(right, line)
			assert.is_true(showing(message))
			assert.are.same({ 0x9a / 255, 0x2a / 255, 0x1a / 255 }, { unpack(message.textColor, 1, 3) })
			local saveTop, messageTop = -save.points[1][5], -message.points[1][5]
			assert.is_true(messageTop > saveTop + save.height - 1)

			fake.guide:Next()
			fake.guide:Back()
			assert.is_false(showing(message))
		end
	)

	it("disables Save and the Fishing set field while restricted (QOL-R41, ONB-R25)", function()
		local fake, client = start()
		local _, right = open(fake, "clothes")
		local save = textReading(right, "Save what I’m wearing as my fishing set").parent.parent
		local dropdown = textReading(right, "None (gear stays as it is)").parent

		fake.setRestricted(true)
		save:Click()
		dropdown:Click()

		assert.is_false(save:IsEnabled())
		assert.is_false(dropdown:IsEnabled())
		assert.are.same({}, client.equipmentSetCalls)
		assert.are.same({}, client.menus)

		fake.setRestricted(false)
		assert.is_true(save:IsEnabled())
		assert.is_true(dropdown:IsEnabled())
	end)

	it("chooses the fishing set from its field as the Fishing page's dropdown does (QOL-R40)", function()
		local fake, client, loaded = start(function(_, client)
			client.equipmentSets[FISHING] = { name = "Fishing", items = { [16] = FISHING_POLE } }
			client.equipmentSets[PREVIOUS] = { name = "Pagle Previous", items = { [16] = SWORD } }
		end)
		local _, right = open(fake, "clothes")
		local dropdown = textReading(right, "None (gear stays as it is)").parent
		assert.are.equal("field", dropdown.panel)

		dropdown:Click()
		local menu = client.menus[#client.menus]
		assert.are.same({ "None (gear stays as it is)", "Fishing" }, menu.texts())
		menu.click("Fishing")

		assert.are.same({ setID = FISHING, name = "Fishing" }, loaded.env.PagleQoLDB.global.gear[PLAYER_GUID])
		assertSays(dropdown, "Fishing")
	end)

	it("binds Swap gear through Core's field (ONB-R33, ONB-R40)", function()
		local fake = start()

		local _, right = open(fake, "clothes")

		local swap = field(right, "PAGLE_SWAP_GEAR")
		assert.are.equal("Swap gear", swap.label)
		assert.are.same({ 30, 231.7 }, placeOf(swap))
	end)

	-- What a Nudge strip says, its pieces left to right.
	local function lineOf(strip)
		local pieces = {}
		for _, child in ipairs(strip.children) do
			local text = child.kind == "FontString" and child or child.Text
			if child.shown and text and child.points[1] then
				pieces[#pieces + 1] = { x = child.points[1][4], text = text.text }
			end
		end
		table.sort(pieces, function(a, b)
			return a.x < b.x
		end)
		local line = {}
		for i, piece in ipairs(pieces) do
			line[i] = piece.text
		end
		return line
	end

	it(
		"draws the swap-back Nudge as a sample on its own strip, Swap gear's key on its cap (ONB-R33, QOL-R77)",
		function()
			local fake, client = start()
			local _, right = open(fake, "clothes")

			-- The sample: the Nudge's paper strip, not the Nudge (no frame says a Nudge).
			local strip = assert(all(right, function(region)
				return region.pools ~= nil and region.middle.texture == FIELD
			end)[1])
			assert.are.same({ "Still holding your pole. Press", "G", "to swap back." }, lineOf(strip))
			for _, frame in ipairs(client.frames) do
				assert.is_nil(frame.message)
			end
			-- Too wide for the column, the strip is drawn smaller.
			assert.is_true(strip.width * strip.scale <= 382 + 1e-9)

			client.boundKeys.PAGLE_SWAP_GEAR = nil
			fake.fireGameEvent("UPDATE_BINDINGS")

			assert.are.same({
				"Still holding your pole. Bind",
				"Pagle: Swap gear",
				"to swap back in one press.",
			}, lineOf(strip))
		end
	)
end)

describe("The qol.lure Margin note (ONB-R52)", function()
	it("shows on the next-action button the first time it shows Lure, once (ONB-R52)", function()
		local fake, client, loaded = start(function(_, client)
			client.mainHand = FISHING_POLE
			client.bags[SHINY_BAUBLE] = 5
		end)

		local notes = assert(fake.notesShown)
		assert.are.equal(1, #notes)
		assert.are.equal("qol.lure", notes[1].id)
		assert.are.equal(
			"Your pole has no lure on. Your next press puts the best one in your bags on. |cff9a2a1aOnly that|r; then you cast.",
			notes[1].text
		)
		local button = notes[1].target --[[@as table]]
		assert.is_truthy(button.Icon and button.HotKey)
		assert.are.equal("Lure", button.Label.text)

		-- A lure on, then gone again: Lure shows once more, and the note doesn't.
		client.mainHandEnchant = 263
		fake.fireGameEvent("UNIT_INVENTORY_CHANGED", "player")
		loaded.ns.EvaluateFishingKey()
		assert.are.equal("Cast", button.Label.text)
		client.mainHandEnchant = nil
		loaded.ns.EvaluateFishingKey()
		assert.are.equal("Lure", button.Label.text)
		assert.are.equal(1, #notes)
	end)

	it("doesn't show while the button shows anything but Lure (ONB-R52)", function()
		local fake = start(function(_, client)
			client.mainHand = FISHING_POLE
			client.mainHandEnchant = 263
		end)

		assert.are.same({}, fake.notesShown)
	end)
end)

describe("QoL's steps on Core's own book", function()
	it("draw with Core's real nav: its cards, binding fields, note, sprites and panels (ONB-R32, ONB-R33)", function()
		local loaded = enterWorld(loadAddon("Pagle_QoL", FOREVER_GLOBALS), 3)
		local core = loaded.namespaces.Pagle
		loaded.client.boundKeys.PAGLE_SWAP_GEAR = { "G" }
		-- Animations off, so each page shows settled (SET-R30).
		core.db.profile.announcements.motion = false

		core.guide:Open("casting")

		local casting = core.guideBook.sides.casting
		for _, text in ipairs({ "One key for the whole cast", "Gear", "The Fishing key", "the usual", "Fishing key" }) do
			assert.are.equal(text, (says(casting.left.content, text) or says(casting.right.content, text)) and text)
		end

		core.guide:Next()

		assert.are.same({}, loaded.client.errors)
		assert.are.equal("clothes", core.guide:Current().step.id)
		local clothes = core.guideBook.sides.clothes
		assertSays(clothes.left.content, "Pagle Previous")
		assertSays(clothes.right.content, "Swap gear")
		assertSays(clothes.right.content, "I don’t keep fishing clothes")
	end)
end)
