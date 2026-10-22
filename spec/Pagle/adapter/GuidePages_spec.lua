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

-- Core logged in on Forever with the Modules named in `names` registered (every one when nil), Animations off, and the
-- guide open at step `id`. Returns the client load.
local function guideAt(id, names)
	local loaded = loadCore({ BUILD_ENTRY })
	for _, module in ipairs(MODULES) do
		local wanted = names == nil
		for _, name in ipairs(names or {}) do
			wanted = wanted or name == module.name
		end
		if wanted then
			loaded.client.addons["Pagle_" .. module.name] = { metadata = { ["X-Pagle-API"] = "1" } }
			local def =
				{ name = module.name, title = module.title, order = module.order, guideBlurb = module.guideBlurb }
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
