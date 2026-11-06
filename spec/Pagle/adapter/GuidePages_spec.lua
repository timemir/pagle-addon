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
-- `blurbs` registering that guideBlurb in place of its own; `words` changes ns.L before the guide opens (a longer
-- translation). Returns the client load.
local function guideAt(id, names, linesOf, blurbs, words)
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
	if words then
		words(loaded.ns.L)
	end
	loaded.ns.guide:Open(id)
	return loaded
end

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local bounds = dofile("spec/support/bounds.lua")

-- A font string's size, as the art's font object it is set in names it (ns.ArtFaceFont's PagleArtFace_<face>_<size>).
local function sizeOf(fontString)
	local name = fontString.fontObject and fontString.fontObject.name or tostring(fontString.fontObject)
	local whole, part = name:match("_(%d+)_?(%d*)$")
	return tonumber(whole .. (part ~= "" and "." .. part or ""))
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
			"Copy for the website",
			"Help chart the waters",
			"Settings",
		}, menuRows(menu))
		assert.are.same({ "Pagle", "0", true }, { texts(menu)[1], menu.balance.text, menu.coin.shown })
		assert.are.equal(page(loaded, "box", "left"), menu:GetParent())
		-- nine rows 23 apart from 31, the rule's 9 and 6 under the last: it ends at 422.5, clear of « back at 508
		assert.are.equal(253, menu:GetHeight())
		assert.is_true(top(menu) + menu:GetHeight() < 508)

		loaded.env.QoLInput = "Fishing key"
		loaded.ns.guide:GoTo("welcome")
		loaded.ns.guide:GoTo("box")
		assert.is_true(reads(menu, "Input: Fishing key"))
		assert.is_false(reads(menu, "Input: Both"))
	end)

	it("holds the Curio Shop's row clear of its balance, however long its name (ONB-R31)", function()
		local loaded = guideAt("box", nil, nil, nil, function(L)
			L.GUIDE_BOX_SHOP = "Tienda de Curiosidades del Pescador"
		end)
		local menu = loaded.ns.guidePages.menu
		local row = assert(find(menu, "Tienda de Curiosidades del Pescador"))

		-- the balance is right-aligned to 183: the name ends 8 short of where it starts
		local balance = #menu.balance.text * 6
		assert(row.width and row.width > 0, "the shop's row has a width")
		assert.is_true(14 + row.width <= 183 - balance - 8)
		assert.is_true(sizeOf(row) < 13)
		assert.are.same({}, bounds.overflows(menu))
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
		assert.are.same(
			{ "Curio Shop", "Copy for the website", "Help chart the waters", "Settings" },
			menuRows(loaded.ns.guidePages.menu)
		)
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
		assert.is_true(reads(left, "When Pagle’s said a lot lately. One line, gone in 3 seconds."))
		assert.is_true(reads(left, "Every Catch, a new fish, a record, Coins earned."))
		assert.is_true(
			reads(
				left,
				"At most 40 pop-ups every 5 minutes: past that, small ones step down to a Nod. Everything lands on the"
					.. " Session summary when you stop."
			)
		)
	end)

	it("starts a sample's name under the line above it when that wraps long, its window with it (ONB-R34)", function()
		local nodLine = "When Pagle’s said a lot lately. One line, gone in 3 seconds."
		local loaded = guideAt("moments", nil, function()
			return { [nodLine] = 4 }
		end)
		local left = page(loaded, "moments", "left")
		local windows = loaded.ns.guidePages.windows

		local line, toast, banner = find(left, nodLine), find(left, "A toast"), find(left, "A banner")
		assert.is_true(top(toast) >= bottom(line) + 10)
		-- the toast's window moves down with its name, as far
		assert.is.near(top(toast) - (193.6 + 0.8), top(windows[2]) - 189.3, 0.01)
		assert.is_true(top(banner) > bottom(find(left, "Every Catch, a new fish, a record, Coins earned.")))
		-- the budget paragraph starts under the banner's window
		local budget = find(
			left,
			"At most 40 pop-ups every 5 minutes: past that, small ones step down to a Nod. Everything lands on the"
				.. " Session summary when you stop."
		)
		assert.is_true(top(budget) > top(windows[3]) + 104)
	end)

	it("keeps each sample's name on one line beside its window, set smaller when longer (ONB-R34)", function()
		local loaded = guideAt("moments", nil, nil, nil, function(L)
			L.GUIDE_MOMENTS_SAMPLES.toast = { "UN AVISO EMERGENTE EN LA PANTALLA", L.GUIDE_MOMENTS_SAMPLES.toast[2] }
		end)
		local name = assert(find(page(loaded, "moments", "left"), "UN AVISO EMERGENTE EN LA PANTALLA"))

		assert.are.equal(156, name.width)
		assert.is_true(sizeOf(name) < 16)
		assert.are.same({}, bounds.overflows(page(loaded, "moments", "left")))
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
			{ "40 pop-ups in 5 minutes", "10 pop-ups in 5 minutes", "a Legend still shows, silently" },
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
			{ cozy = false, everyCatch = true, motion = false, budget = { on = true, count = 40, window = 300 } },
			settings(loaded)
		)

		settings(loaded).budget.on = false
		cards[3]:Click()
		assert.are.same(
			{ cozy = true, everyCatch = true, motion = false, budget = { on = false, count = 40, window = 300 } },
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

	it("starts the margin-notes paragraph under the Nod's note when the note wraps long (ONB-R38)", function()
		local nodNote = "That’s a *Nod*: every Catch gets one. It’s gone in three seconds."
		local loaded = guideAt("off", nil, function()
			return { [nodNote:gsub("%*(.-)%*", "|cff9a2a1a%1|r")] = 6 }
		end)
		local left = page(loaded, "off", "left")

		local note = find(left, nodNote:gsub("%*(.-)%*", "|cff9a2a1a%1|r")):GetParent()
		local looks = find(
			left,
			"Don’t want notes? Turn off Margin notes in Settings. The Fish Journal, Hunts, Stats, the Tackle Board"
				.. " and the Curio Shop each get a short set the first time you open them."
		)
		assert.is_true(top(looks) >= top(note) + note:GetHeight() + 12)
	end)

	it(
		"wraps an item or a hint too long for the First evening list's paper, its row growing (ONB-R38, ONB-R61)",
		function()
			local long = "Wirf einen Blick in den Kuriositätenladen"
			local hint = "drück deine Angeltaste oder mach einen Doppel-Rechtsklick"
			local function lists(lines)
				local loaded = guideAt(
					"off",
					nil,
					function()
						return { [long] = lines, [hint] = lines }
					end,
					nil,
					function(L)
						L.GUIDE_EVENING_ITEMS.shop = long
						L.GUIDE_EVENING_HINTS.cast = hint
					end
				)
				return loaded.ns.guidePages.evening
			end
			local list, one = lists(2), lists(1)

			local item, cast = assert(find(list, long)), assert(find(list, hint))
			-- On one line at 6 a byte, both run past the paper's 217 for an item's words.
			assert.is_true(#long * 6 > 217 and #hint * 6 > 217)
			for _, words in ipairs({ item, cast }) do
				assert.are.same({ 274 - 43 - 14, true }, { words.width, words.wordWrap })
			end
			assert.are.equal(13.5, sizeOf(item))
			-- the cast row's hint takes a second line (16.3), pushing the rows under it down; the shop's item a second
			-- (17.6), the paper with it
			assert.is.near(top(find(one, "Land a Catch")) + 16.3, top(find(list, "Land a Catch")), 1e-9)
			assert.is.near(one:GetHeight() + 16.3 + 17.6, list:GetHeight(), 1e-9)
			assert.are.same({}, bounds.overflows(list))
		end
	)

	-- A done item was struck through its first line only: a longer language's wrapped one kept its second unstruck.
	it("onb_r62 strikes a done item on the First evening list through every line it wraps to", function()
		local long = "Wirf einen Blick in den Kuriositätenladen"
		local loaded = guideAt(
			"box",
			nil,
			function()
				return { [long] = 2 }
			end,
			nil,
			function(L)
				L.GUIDE_EVENING_ITEMS.shop = long
			end
		)
		loaded.ns.onboarding:CompleteEveningItem("shop")
		loaded.ns.onboarding:CompleteEveningItem("cast")
		loaded.ns.guide:GoTo("off")
		local list = loaded.ns.guidePages.evening

		local function struck(id)
			for _, row in ipairs(list.rows) do
				if row.id == id then
					local out = {}
					for _, strike in ipairs(row.strikes) do
						if strike.shown then
							out[#out + 1] = { strike.width, strike.points[1][4], -strike.points[1][5] }
						end
					end
					return out
				end
			end
		end
		-- at 6 a byte the paper's 217 holds "Wirf einen Blick in den" and not the next word, which takes the second line
		assert.is_true(#long * 6 > 217)
		local shop = struck("shop")
		local y = shop[1] and shop[1][3]
		assert.are.same({
			{ #"Wirf einen Blick in den" * 6, 43, y },
			{ #"Kuriositätenladen" * 6, 43, y + 17.6 },
		}, shop)
		assert.are.same({ { #"Make a Cast" * 6, 43, 30 + 11 } }, struck("cast"))
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

	-- Off to the water's top and the bottom of the line under it, on the right page (that line's box is 17.55 tall at
	-- 13, as text() sets it), and the First evening list's foot.
	local function offFoot(loaded)
		local right = page(loaded, "off", "right")
		local again = assert(find(right, "|cff3e220c/pagle guide|r opens this guide again."))
		local list = loaded.ns.guidePages.evening
		return top(loaded.ns.guidePages.offButton), top(again) - (17.55 - 13) / 2 + 17.55, top(list) + list:GetHeight()
	end

	it("puts Off to the water and the line under it at the board's places (ONB-R38)", function()
		local buttonY, againFoot = offFoot(guideAt("off"))

		assert.are.equal(359.7, buttonY)
		assert.is_true(math.abs(againFoot - (359.7 + 56 + 17.55)) < 0.01)
	end)

	it(
		"keeps Off to the water and the line under it above the foot when the list's paragraph wraps long (ONB-R38)",
		function()
			for _, lines in ipairs({ 5, 6, 7 }) do
				local loaded = guideAt("off", nil, function(ns)
					return { [ns.L.GUIDE_OFF_LIST_TEXT] = lines }
				end)
				local buttonY, againFoot, listFoot = offFoot(loaded)

				assert(againFoot <= 486 + 0.01, lines .. " lines: the line under the button runs into the foot")
				assert(buttonY >= listFoot + 4 - 0.01, lines .. " lines: the button runs into the list")
				assert(againFoot - 17.55 >= buttonY + 46 + 4 - 0.01, lines .. " lines: the line runs into the button")
			end
		end
	)

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

describe("the guide's titles and foot on every page (ONB-R23)", function()
	it("holds a long title to the column on one line, set smaller, never into the spine", function()
		local long = "Lo que hay en la caja, y todo lo que puedes hacer con ello esta misma noche"
		local loaded = guideAt("box", nil, nil, nil, function(L)
			L.GUIDE_BOX_TITLE = long
		end)
		local left = page(loaded, "box", "left")
		local title = assert(find(left, long))

		assert.are.equal(382, title.width)
		assert.is_true(sizeOf(title) < 29)
		assert.are.same({}, bounds.overflows(left))
	end)

	it("keeps the skip link clear of Next », set smaller and cut short when longer", function()
		local long = "Saltarse todo lo demás y empezar a pescar ahora mismo sin leer nada"
		local loaded = guideAt("box", nil, nil, nil, function(L)
			L.GUIDE_SKIP = long
		end)
		local right = page(loaded, "box", "right")
		local label = assert(find(right, long))
		local skip = label:GetParent()
		local nextButton = assert(find(right, loaded.ns.L.GUIDE_NEXT)):GetParent()

		-- Next » is right-aligned to 412: the link ends 16 short of its left edge
		assert.is_true(30 + skip:GetWidth() <= 412 - nextButton:GetWidth() - 16)
		assert.is_true(30 + label.width <= 412 - nextButton:GetWidth() - 16)
		assert.is_true(sizeOf(label) < 14)
	end)
end)
