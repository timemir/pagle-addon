-- Core's own guide pages on the client, through the real TOC and the fake client (core/onboarding.md › The steps):
-- Welcome (ONB-R30), What's in the box (ONB-R31, ONB-R91, ONB-R102, ONB-R103), Moments with its still samples and its
-- presets (ONB-R34, ONB-R35) and Off you go (ONB-R38). Each page's words and parts are asserted, not pixels.

-- The five Modules as their own tickets register them (CORE-R50's orders, ONB-R91's blurbs), each with a view and
-- QoL with its live Input entry (CORE-R52), by roster name; those with a First look (ONB-R57) register it, by its
-- title.
local MODULES = {
	{
		name = "Ledger",
		title = "Ledger",
		order = 10,
		guideBlurb = "Your book.",
		view = "Fish Journal",
		look = "the Fish Journal",
	},
	{
		name = "Hunts",
		title = "Hunts",
		order = 20,
		guideBlurb = "Fish that bite at night.",
		view = "Hunts",
		look = "Hunts",
	},
	{ name = "Stats", title = "Stats", order = 30, view = "Stats", look = "Stats" },
	{
		name = "TackleBoard",
		title = "Tackle Board",
		order = 40,
		guideBlurb = "Small goals.",
		view = "Tackle Board",
		look = "the Tackle Board",
	},
	{ name = "QoL", title = "QoL", order = 50, guideBlurb = "One press, one action." },
}

-- Has the kit's font strings measure as the client wraps them (the fake's GetStringHeight is one 14-unit line whatever
-- the text): a text `size` tall that wraps to `lines[text]` lines (1 when unlisted) is that many lines tall with the
-- spacing ns.GuideText was given between them.
---@param loaded table
---@param linesOf fun(ns: table): table<string, integer> the lines each text wraps to, from the load's words
local function measure(loaded, linesOf)
	local lines = linesOf(loaded.ns)
	local GuideText = loaded.ns.GuideText
	loaded.ns.GuideText = function(parent, face, size, ink, words, options)
		local fontString = GuideText(parent, face, size, ink, words, options)
		local spacing = options and options.spacing or 0
		fontString.GetStringHeight = function(self)
			local n = self.wordWrap and lines[self.text] or 1
			return n * size + (n - 1) * spacing
		end
		return fontString
	end
end

-- Core logged in on Forever with the Modules named in `names` registered (every one when nil), Animations off, and the
-- guide open at step `id`, its texts wrapping as `linesOf` says (see measure) when given, and a Module named in
-- `blurbs` registering that guideBlurb in place of its own. Returns the client load.
local function guideAt(id, names, linesOf, blurbs)
	local loaded = loadCore({ BUILD_ENTRY })
	for _, module in ipairs(MODULES) do
		local wanted = names == nil
		for _, name in ipairs(names or {}) do
			wanted = wanted or name == module.name
		end
		if wanted then
			loaded.client.addons["Pagle_" .. module.name] = { metadata = { ["X-Pagle-API"] = "1" } }
			local blurb = (blurbs or {})[module.name] or module.guideBlurb
			local def = { name = module.name, title = module.title, order = module.order, guideBlurb = blurb }
			if module.view then
				def.views = { { id = "main", label = module.view, open = function() end } }
			end
			if module.name == "QoL" then
				def.menu = {
					{
						label = function()
							return "Input: " .. loaded.env.QoLInput
						end,
						onClick = function() end,
					},
				}
				loaded.env.QoLInput = "Both"
			end
			local M = loaded.env.Pagle.RegisterModule(def)
			if module.look then
				M:RegisterFirstLook({
					id = module.name:lower() .. ".main",
					window = loaded.env.CreateFrame("Frame"),
					title = module.look,
					notes = { { text = "A note.", target = function() end, x = -214, y = 100, w = 200 } },
				})
			end
		end
	end
	enterWorld(loaded, 3)
	loaded.ns.db.profile.announcements.motion = false
	if linesOf then
		measure(loaded, linesOf)
	end
	loaded.ns.guide:Open(id)
	return loaded
end

-- Step `id`'s `side` page.
local function page(loaded, id, side)
	return loaded.ns.guideBook.sides[id][side].content
end

-- Every shown font string's text under `widget`, depth first, in the order made.
local function texts(widget, out)
	out = out or {}
	for _, child in ipairs(widget.children) do
		if child.shown ~= false then
			if child.kind == "FontString" and child.text and child.text ~= "" then
				out[#out + 1] = child.text
			end
			texts(child, out)
		end
	end
	return out
end

-- Whether `widget` shows a font string reading `text` somewhere under it.
local function reads(widget, text)
	for _, found in ipairs(texts(widget)) do
		if found == text then
			return true
		end
	end
	return false
end

-- The font string under `widget` reading `text`, depth first.
local function find(widget, text)
	for _, child in ipairs(widget.children) do
		if child.kind == "FontString" and child.text == text then
			return child
		end
		local found = find(child, text)
		if found then
			return found
		end
	end
	return nil
end

-- A region's top, in units down from the top left it is anchored to (its one anchor's y, as ns.GuideAt and the
-- pages' texts set it).
local function top(region)
	return -region.points[1][5]
end

-- A font string's bottom, as it measures.
local function bottom(fontString)
	return top(fontString) + fontString:GetStringHeight()
end

-- The tops of the drawn wax discs on `side` (the GuideParts sprites among its children), in order.
local function discTops(side)
	local tops = {}
	for _, child in ipairs(side.children) do
		if child.kind == "Texture" and (child.texture or ""):find("GuideParts") then
			tops[#tops + 1] = top(child) + child.box[2]
		end
	end
	return tops
end

-- The menu drawing's rows on show, top to bottom.
local function menuRows(menu)
	local rows = {}
	for _, row in ipairs(menu.rows) do
		if row.shown then
			rows[#rows + 1] = row.text
		end
	end
	return rows
end

-- The announcement settings as stored.
local function settings(loaded)
	return loaded.ns.db.profile.announcements
end

describe("the Welcome step (ONB-R30)", function()
	it("is the letter in the hand, signed Pagle, with the foot line, on the left page", function()
		local loaded = guideAt("welcome")
		local left = page(loaded, "welcome", "left")

		assert.are.same({
			"A letter, left on the dock",
			"Dear Angler,",
			"From now on, every fish you pull out of the water gets written down: where, when, how big, and what it took to land it.",
			"Fish long enough and the water starts telling you things: what bites only at night, which fish you keep missing, how far you’ve come.",
			"Let me show you around. It takes two minutes, and you can change everything later.",
			"Pagle",
			"Everything here is also in Options » AddOns » Pagle.",
		}, texts(left))
	end)

	it("makes three promises beside wax discs I, II and III, the third saying Pagle comes in five parts", function()
		local loaded = guideAt("welcome")
		local right = page(loaded, "welcome", "right")

		local read = texts(right)
		assert.are.same({
			"Before anything else",
			"Three promises",
			"I",
			"I never fish for you.",
			"Pagle watches and writes things down. Every key press does one thing at most, and your hands do the fishing.",
			"II",
			"Nothing expires.",
			"There are no dailies to miss. Goals wait for you, and a day away costs you nothing.",
			"III",
			"Every part is optional.",
			"Pagle comes in five parts. Turn any of them off in the AddOns list and it leaves no trace.",
		}, { unpack(read, 1, 11) })
		local discs = 0
		for _, child in ipairs(right.children) do
			discs = discs + ((child.kind == "Texture" and child.texture or ""):find("GuideParts") and 1 or 0)
		end
		assert.are.equal(3, discs)
	end)

	-- The Letter's paragraphs wrapping to `letter`'s lines and the promises' lines to `promises`'.
	local function welcomeLines(letter, promises)
		return function(ns)
			local lines = {}
			for i, words in ipairs(ns.L.GUIDE_WELCOME_LETTER) do
				lines[words] = letter[i]
			end
			for i, promise in ipairs(ns.L.GUIDE_WELCOME_PROMISES) do
				lines[promise[3] or ns.GuidePartsLine(5)] = promises[i]
			end
			return lines
		end
	end

	it("signs the letter under its last line, and starts each paragraph under the last, however they wrap", function()
		local loaded = guideAt("welcome", nil, welcomeLines({ 3, 4, 3 }, { 2, 2, 2 }))
		local left = page(loaded, "welcome", "left")
		local L = loaded.ns.L

		local paragraphs = {}
		for i, words in ipairs(L.GUIDE_WELCOME_LETTER) do
			paragraphs[i] = find(left, words)
		end
		local signed = find(left, L.GUIDE_WELCOME_SIGNED)
		assert.is_true(top(paragraphs[2]) > bottom(paragraphs[1]) + 10)
		assert.is_true(top(paragraphs[3]) > bottom(paragraphs[2]) + 10)
		assert.is_true(top(signed) > bottom(paragraphs[3]) + 5)
		-- the paragraphs are as far apart as the art has them, whatever their lines
		assert.is.near(top(paragraphs[2]) - bottom(paragraphs[1]), top(paragraphs[3]) - bottom(paragraphs[2]), 0.01)
	end)

	it("puts the letter where the art does when it wraps as the art's, three, three and two lines", function()
		local loaded = guideAt("welcome", nil, welcomeLines({ 3, 3, 2 }, { 2, 2, 2 }))
		local left = page(loaded, "welcome", "left")
		local L = loaded.ns.L

		-- each paragraph's line box (28.06 at 23) at the art's place, the signature's (30 at 30) at 345.8
		for i, y in ipairs({ 87.4, 183.6, 279.7 }) do
			assert.is.near(y + 2.53, top(find(left, L.GUIDE_WELCOME_LETTER[i])), 0.06)
		end
		assert.is.near(345.8, top(find(left, L.GUIDE_WELCOME_SIGNED)), 0.06)
	end)

	it("starts each promise under the last one's line, evenly, each disc beside its heading", function()
		local loaded = guideAt("welcome", nil, welcomeLines({ 3, 3, 2 }, { 3, 2, 1 }))
		local right = page(loaded, "welcome", "right")
		local promises = loaded.ns.L.GUIDE_WELCOME_PROMISES

		local headings, lines = {}, {}
		for i, promise in ipairs(promises) do
			headings[i] = find(right, promise[2])
			lines[i] = find(right, promise[3] or loaded.ns.GuidePartsLine(5))
		end
		local discs = discTops(right)
		for i = 1, 3 do
			assert.is_true(top(lines[i]) > bottom(headings[i]))
			assert.is.near(top(headings[i]) - discs[i], top(headings[1]) - discs[1], 0.01)
		end
		assert.is_true(top(headings[2]) > bottom(lines[1]) + 10)
		assert.is_true(top(headings[3]) > bottom(lines[2]) + 10)
		assert.is.near(top(headings[2]) - bottom(lines[1]), top(headings[3]) - bottom(lines[2]), 0.01)
	end)

	it("puts the promises where the art does when each line wraps to two", function()
		local loaded = guideAt("welcome", nil, welcomeLines({ 3, 3, 2 }, { 2, 2, 2 }))

		local discs = discTops(page(loaded, "welcome", "right"))
		for i, y in ipairs({ 89.3, 175.1, 260.9 }) do
			assert.is.near(y, discs[i], 0.06)
		end
	end)

	it("counts the roster, not what is on: five parts with every Module off too (ONB-R30)", function()
		local loaded = guideAt("welcome", {})

		assert.is_true(
			reads(
				page(loaded, "welcome", "right"),
				"Pagle comes in five parts. Turn any of them off in the AddOns list and it leaves no trace."
			)
		)
	end)

	it("closes with I’ll find my own way, setting skipped (ONB-R26)", function()
		local loaded = guideAt("welcome")

		assert.is_true(reads(page(loaded, "welcome", "right"), "I’ll find my own way"))
		loaded.ns.guide:Skip()

		assert.is_false(loaded.ns.guide:IsOpen())
		assert.is_true(loaded.env.PagleDB.global.onboarding.skipped)
	end)
end)

describe("the What's in the box step (ONB-R31, ONB-R91)", function()
	it("lists five rows in def.order with icon, title and blurb, then the Curio Shop's", function()
		local loaded = guideAt("box")
		local right = page(loaded, "box", "right")

		assert.are.same({
			"Five parts, and a shop",
			"Ledger",
			"Your book.",
			"Hunts",
			"Fish that bite at night.",
			"Stats",
			"Tackle Board",
			"Small goals.",
			"QoL",
			"One press, one action.",
			"Curio Shop",
			"Pagle Coins come from things you achieve, and buy looks, never power.",
		}, { unpack(texts(right), 1, 12) })
		local icons = {}
		for _, row in ipairs(loaded.ns.guidePages.rows) do
			icons[#icons + 1] = row.icon.texture and row.sprite
		end
		assert.are.same({ "ic-journal", "ic-hunts", "ic-stats", "ic-board", "ic-qol", "ic-shop" }, icons)
	end)

	-- The rows' blurbs wrapping to `lines`' lines, in the rows' order, the Curio Shop's last.
	local function boxLines(lines)
		return function(ns)
			local out = {}
			for i, row in ipairs(ns.GuideBoxRows(ns.Modules:Modules())) do
				if row.blurb then
					out[row.blurb] = lines[i]
				end
			end
			return out
		end
	end

	-- Stats with a blurb too, so each of the six rows has one, as on the board.
	local SIX = { Stats = "Your own numbers." }

	-- A row's icon's drawn top (it is 36 tall).
	local function iconTop(row)
		return top(row.icon) + row.icon.box[2]
	end

	-- Where a row ends: under the lower of its icon and its words' line box (the blurb's 18.225 at 13.5, or the
	-- title's 19.55 at 17 when it has none).
	local function rowEnd(row)
		local words = row.blurb and bottom(row.blurb) + (18.225 - 13.5) / 2 or bottom(row.title) + (19.55 - 17) / 2
		return math.max(iconTop(row) + 36, words)
	end

	it("puts the rows where the board does when every blurb wraps to two lines", function()
		local loaded = guideAt("box", nil, boxLines({ 2, 2, 2, 2, 2, 2 }), SIX)
		local rows = loaded.ns.guidePages.rows

		assert.are.equal(6, #rows)
		-- each row 73.98 under the last from 55: its title's line box (19.55 at 17) level with the icon, the blurb's
		-- (18.225 at 13.5) 21.5 under it, the rule 66 under the row's top, and none under the last
		for i, row in ipairs(rows) do
			local y = 55 + (i - 1) * 73.98
			assert.is.near(y, iconTop(row), 0.05)
			assert.is.near(y + 1.275, top(row.title), 0.05)
			assert.is.near(y + 21.5 + 2.3625, top(row.blurb), 0.05)
			if i < #rows then
				assert.is.near(y + 66, top(row.rule), 0.05)
			else
				assert.is_nil(row.rule)
			end
		end
	end)

	it("starts each row under the last one's rule, a blurb on three lines pushing the rows under it down", function()
		-- Stats without a blurb, its row as tall as its icon
		local loaded = guideAt("box", nil, boxLines({ 3, 2, 2, 2, 2, 2 }))
		local rows = loaded.ns.guidePages.rows

		for i, row in ipairs(rows) do
			assert.is.near(iconTop(row) + 1.275, top(row.title), 0.01)
			if i < #rows then
				assert.is_true(top(row.rule) > rowEnd(row))
				assert.is_true(iconTop(rows[i + 1]) > top(row.rule))
				assert.is_true(top(rows[i + 1].title) > top(row.rule))
			end
		end
		-- Ledger's third line takes Hunts 18.225 lower than the board has it, the rows the board's 16.03 apart
		assert.is.near(55 + 73.98 + 18.225, iconTop(rows[2]), 0.05)
		for i = 1, #rows - 1 do
			assert.is.near(16.03, iconTop(rows[i + 1]) - rowEnd(rows[i]), 0.01)
		end
	end)

	it("tightens the gaps between the rows evenly to keep them off the foot when blurbs wrap longer", function()
		local loaded = guideAt("box", nil, boxLines({ 3, 2, 3, 2, 2, 2 }), SIX)
		local rows = loaded.ns.guidePages.rows

		local gap = iconTop(rows[2]) - rowEnd(rows[1])
		assert.is_true(gap < 16.03 - 5)
		for i = 1, #rows - 1 do
			assert.is.near(gap, iconTop(rows[i + 1]) - rowEnd(rows[i]), 0.01)
			assert.is_true(top(rows[i].rule) > rowEnd(rows[i]))
			assert.is_true(iconTop(rows[i + 1]) > top(rows[i].rule))
		end
		-- the last row ends no lower than 483, 7 over the foot's Next at 490
		assert.is_true(rowEnd(rows[#rows]) <= 483.01)
	end)

	it("keeps the rows at least 8 apart, the rule between, however long their blurbs", function()
		local loaded = guideAt("box", nil, boxLines({ 4, 4, 4, 2, 2, 2 }), SIX)
		local rows = loaded.ns.guidePages.rows

		for i = 1, #rows - 1 do
			assert.is.near(8, iconTop(rows[i + 1]) - rowEnd(rows[i]), 0.01)
			assert.is_true(top(rows[i].rule) > rowEnd(rows[i]))
			assert.is_true(iconTop(rows[i + 1]) > top(rows[i].rule))
		end
	end)

	it("puts 'Turn parts on in the AddOns list.' a row under the Curio Shop's with every Module off", function()
		local loaded = guideAt("box", {}, boxLines({ 2 }))
		local none = find(page(loaded, "box", "right"), "Turn parts on in the AddOns list.")

		-- its line box (17.55 at 13) where the board's second row would be
		assert.is.near(55 + 73.98 + 2.275, top(none), 0.05)
	end)

	it("draws the Pagle menu from the real menu's labels as it shows, with the balance and a coin", function()
		local loaded = guideAt("box")
		local menu = loaded.ns.guidePages.menu

		assert.are.same({
			"Fish Journal",
			"Hunts",
			"Stats",
			"Tackle Board",
			"Input: Both",
			"Curio Shop",
			"Help chart the waters",
			"Settings",
		}, menuRows(menu))
		assert.are.same({ "Pagle", "0", true }, { texts(menu)[1], menu.balance.text, menu.coin.shown })
		assert.are.equal(page(loaded, "box", "left"), menu:GetParent())

		loaded.env.QoLInput = "Fishing key"
		loaded.ns.guide:GoTo("welcome")
		loaded.ns.guide:GoTo("box")
		assert.is_true(reads(menu, "Input: Fishing key"))
		assert.is_false(reads(menu, "Input: Both"))
	end)

	it("pencils the note 'Click a name to open it. /pagle opens Settings.' beside the menu", function()
		local loaded = guideAt("box")
		local left = page(loaded, "box", "left")

		assert.is_true(reads(left, "Click a name to open it. |cff9a2a1a/pagle|r opens Settings."))
	end)

	it("leaves out a Module that is off, counting what's on in its kicker (ONB-R102)", function()
		local loaded = guideAt("box", { "Hunts", "QoL" })
		local right = page(loaded, "box", "right")

		assert.are.same(
			{ "Two parts, and a shop", "Hunts", "Fish that bite at night.", "QoL", "One press, one action." },
			{ unpack(texts(right), 1, 5) }
		)
		assert.is_false(reads(right, "Ledger"))
	end)

	it("shows only the Curio Shop and 'Turn parts on in the AddOns list.' with every Module off (ONB-R103)", function()
		local loaded = guideAt("box", {})
		local right = page(loaded, "box", "right")

		assert.are.same({
			"No parts, and a shop",
			"Curio Shop",
			"Pagle Coins come from things you achieve, and buy looks, never power.",
			"Turn parts on in the AddOns list.",
		}, { unpack(texts(right), 1, 4) })
		assert.are.same({ "Curio Shop", "Help chart the waters", "Settings" }, menuRows(loaded.ns.guidePages.menu))
	end)
end)

describe("the Moments step (ONB-R34, ONB-R35)", function()
	it("draws a Nod, a toast and a banner by the real display frames, standing still, each named", function()
		local loaded = guideAt("moments")
		local left = page(loaded, "moments", "left")
		local samples = loaded.ns.guidePages.samples
		loaded.client.sounds = {}

		loaded.client.advance(30)
		for _ = 1, 60 do
			loaded.client.nextFrame(1 / 60)
		end

		assert.are.same(
			{ "NEW HERE", "NEW SPECIES", "Oily Blackmouth" },
			{ samples.nod.title:GetText(), samples.toast.title:GetText(), samples.banner.text:GetText() }
		)
		for _, form in ipairs({ "nod", "toast", "banner" }) do
			local frame = samples[form]
			assert.are.same({ true, 1 }, { frame.shown, frame.alpha })
			assert.is_true(frame:GetScale() < 1)
			assert.is_nil(frame.lanes)
		end
		assert.is_nil(loaded.ns.announcementFrames.nod)
		assert.are.same({}, loaded.client.sounds)
		for _, name in ipairs({ "A Nod", "A toast", "A banner" }) do
			assert.is_true(reads(left, name))
		end
		assert.is_true(reads(left, "Every Catch. One line, gone in 3 seconds."))
		assert.is_true(
			reads(
				left,
				"At most 20 pop-ups every 5 minutes: past that, small ones step down to a Nod. Everything lands on the"
					.. " Session summary when you stop."
			)
		)
	end)

	it("shows Lively chosen for a new Angler's settings, the three cards in order with their lines", function()
		local loaded = guideAt("moments")
		local right = page(loaded, "moments", "right")
		local pages = loaded.ns.guidePages
		local cards = pages.cards

		assert.are.same(
			{ "Lively", "Quieter", "Cozy" },
			{ cards[1].title.text, cards[2].title.text, cards[3].title.text }
		)
		assert.are.same({ true, false, false }, { cards[1].chosen, cards[2].chosen, cards[3].chosen })
		assert.are.equal("as it comes", cards[1].tag.text)
		assert.are.same(
			{ "20 pop-ups in 5 minutes", "10 pop-ups in 5 minutes", "a Legend still shows, silently" },
			{ cards[1].what.text, cards[2].what.text, cards[3].what.text }
		)
		assert.is_false(pages.ownMix.shown)
		assert.is_true(
			reads(
				right,
				"Each one only sets the switches in Settings » Announcements, where you can fine-tune them later."
			)
		)
	end)

	-- The preset cards' lines wrapping to `cards`' lines (Lively, Quieter, Cozy) and the note to `note`'s.
	local function presetLines(cards, note)
		return function(ns)
			local lines = { [ns.L.GUIDE_MOMENTS_NOTE] = note }
			for i, preset in ipairs(ns.GUIDE_PRESETS) do
				lines[ns.L.GUIDE_PRESETS[preset.id][2]] = cards[i]
			end
			return lines
		end
	end

	it("pencils each card's line under its wrapped line, the card grown to fit, the cards evenly apart", function()
		local loaded = guideAt("moments", nil, presetLines({ 2, 3, 2 }, 2))
		local pages = loaded.ns.guidePages
		local cards = pages.cards

		for _, card in ipairs(cards) do
			assert.is_true(top(card.what) > bottom(card.line))
			assert.is_true(card:GetHeight() > top(card.what) + 17.6)
		end
		-- "as it comes" stays at Lively's top right
		local tag = cards[1].tag.points[1]
		assert.are.same({ "TOPRIGHT", cards[1], "TOPLEFT", 382 - 9 }, { tag[1], tag[2], tag[3], tag[4] })
		local gaps = {}
		for i = 2, 3 do
			gaps[i] = top(cards[i]) - (top(cards[i - 1]) + cards[i - 1]:GetHeight())
			assert.is_true(gaps[i] > 5)
		end
		assert.is.near(gaps[2], gaps[3], 0.01)
		local last = top(cards[3]) + cards[3]:GetHeight()
		assert.is_true(top(pages.presetNote) > last + 10)

		loaded.ns.db.profile.announcements.budget.count = 12
		loaded.ns.guide:GoTo("box")
		loaded.ns.guide:GoTo("moments")
		assert.is_true(top(pages.ownMix) > last)
		assert.is_true(top(pages.presetNote) > top(pages.ownMix) + 17)
	end)

	it("puts the cards where the art does when Lively's line takes one line and the others two", function()
		local loaded = guideAt("moments", nil, presetLines({ 1, 2, 2 }, 2))
		local pages = loaded.ns.guidePages

		for i, at in ipairs({ { 81.3, 83.4 }, { 172.6, 101.6 }, { 282.2, 101.6 } }) do
			local card = pages.cards[i]
			assert.are.same({ true, true }, {
				math.abs(top(card) - at[1]) < 0.06,
				math.abs(card:GetHeight() - at[2]) < 0.06,
			})
			-- the pencilled line's box (17.6 at 16) 4 under the italic line's (18.2 a line at 13.5)
			assert.is.near(32.5 + (i == 1 and 1 or 2) * 18.2 + 4 + 0.8, top(card.what), 0.06)
		end
		assert.is.near(397.8 + 2.275, top(pages.presetNote), 0.06)
	end)

	it("writes ONB-R35's values exactly as Quieter, Lively and Cozy are chosen, choosing that card", function()
		local loaded = guideAt("moments")
		local cards = loaded.ns.guidePages.cards

		cards[2]:Click()
		assert.are.same(
			{ cozy = false, everyCatch = false, motion = false, budget = { on = true, count = 10, window = 300 } },
			settings(loaded)
		)
		assert.are.same({ false, true, false }, { cards[1].chosen, cards[2].chosen, cards[3].chosen })

		cards[1]:Click()
		assert.are.same(
			{ cozy = false, everyCatch = true, motion = false, budget = { on = true, count = 20, window = 300 } },
			settings(loaded)
		)

		settings(loaded).budget.on = false
		cards[3]:Click()
		assert.are.same(
			{ cozy = true, everyCatch = true, motion = false, budget = { on = false, count = 20, window = 300 } },
			settings(loaded)
		)
		assert.are.same({ false, false, true }, { cards[1].chosen, cards[2].chosen, cards[3].chosen })
	end)

	it("plays check as a card is chosen", function()
		local loaded = guideAt("moments")
		loaded.client.sounds = {}

		loaded.ns.guidePages.cards[2]:Click()

		assert.are.same({ "856 SFX" }, loaded.client.sounds)
	end)

	it("chooses no card for a hand-set mix and reads 'Your own mix, kept as it is.', re-read as it shows", function()
		local loaded = guideAt("box")
		settings(loaded).budget.count = 12

		loaded.ns.guide:GoTo("moments")
		local pages = loaded.ns.guidePages

		assert.are.same({ false, false, false }, {
			pages.cards[1].chosen,
			pages.cards[2].chosen,
			pages.cards[3].chosen,
		})
		assert.is_true(pages.ownMix.shown)
		assert.are.equal("Your own mix, kept as it is.", pages.ownMix.text)

		settings(loaded).cozy = true
		loaded.ns.guide:GoTo("box")
		loaded.ns.guide:GoTo("moments")
		assert.are.same({ true, false }, { pages.cards[3].chosen, pages.ownMix.shown })
	end)
end)

describe("the Off you go step (ONB-R38)", function()
	it("draws the sample Nod with its note 1, and names the windows with First looks", function()
		local loaded = guideAt("off")
		local left = page(loaded, "off", "left")

		local sample = loaded.ns.guidePages.offSample
		assert.are.equal("NEW HERE", sample.title:GetText())
		assert.is_nil(sample.lanes)
		assert.is_true(reads(left, "That’s a |cff9a2a1aNod|r: every Catch gets one. It’s gone in three seconds."))
		assert.is_true(reads(left, "1"))
		assert.is_true(
			reads(
				left,
				"Don’t want notes? Turn off Margin notes in Settings. The Fish Journal, Hunts, Stats, the Tackle Board"
					.. " and the Curio Shop each get a short set the first time you open them."
			)
		)
	end)

	it("names only the registered windows (ONB-R38, ONB-R102)", function()
		local loaded = guideAt("off", { "Stats", "QoL" })

		assert.is_true(
			reads(
				page(loaded, "off", "left"),
				"Don’t want notes? Turn off Margin notes in Settings. Stats and the Curio Shop each get a short set the"
					.. " first time you open them."
			)
		)
	end)

	it("draws the First evening list as it will look, its items done ticked", function()
		local loaded = guideAt("box")
		loaded.ns.onboarding:CompleteEveningItem("cast")
		loaded.ns.guide:GoTo("off")
		local list = loaded.ns.guidePages.evening

		assert.are.same({
			"First evening",
			"1 of 6",
			"Make a Cast",
			"press your Fishing key, or double right-click",
			"Land a Catch",
			"Open the Fish Journal",
			"See what’s biting on Hunts",
			"Finish a Session",
			"step away 5 minutes for your summary",
			"Peek into the Curio Shop",
		}, texts(list))
		assert.are.same({ true, false }, { list.rows[1].done, list.rows[2].done })
	end)

	it("lists only the items whose owners are on (ONB-R61, ONB-R101)", function()
		local loaded = guideAt("off", {})
		local list = loaded.ns.guidePages.evening

		assert.are.same({
			"First evening",
			"0 of 4",
			"Make a Cast",
			"right-click the water with Fishing",
			"Land a Catch",
			"Finish a Session",
			"step away 5 minutes for your summary",
			"Peek into the Curio Shop",
		}, texts(list))
	end)

	it("sets guideDone and closes with Off to the water, then calls its hook (ONB-R26, ONB-R38)", function()
		local loaded = guideAt("off")
		local docked = 0
		loaded.ns.guide:SetOffToTheWater(function()
			docked = docked + 1
		end)
		local right = page(loaded, "off", "right")
		assert.is_true(reads(right, "|cff3e220c/pagle guide|r opens this guide again."))

		loaded.ns.guidePages.offButton:Click()

		assert.is_true(loaded.env.PagleDB.global.onboarding.guideDone)
		assert.is_false(loaded.ns.guide:IsOpen())
		assert.are.equal(1, docked)
	end)
end)
