-- What Core's own guide pages say and set (core/onboarding.md › The steps): Welcome's count of parts (ONB-R30), What's
-- in the box's rows and kicker (ONB-R31, ONB-R91, ONB-R102, ONB-R103), the Moments presets and which one the settings
-- match (ONB-R35), and Off you go's windows with First looks and the First evening list as it will look (ONB-R38,
-- ONB-R61). Pure logic (CORE-R7), over plain tables here.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

-- The announcement settings as a new profile holds them (announcements.md › Data).
local function defaults()
	return { cozy = false, everyCatch = true, motion = true, budget = { on = true, count = 40, window = 300 } }
end

-- Registered Modules as the registry lists them (by def.order): `defs` are { name, title, order, guideBlurb? }.
local function modules(defs)
	local list = {}
	for i, def in ipairs(defs) do
		list[i] = { def = { name = def[1], title = def[2], order = def[3], guideBlurb = def[4] } }
	end
	return list
end

-- The five Modules, every one on, with their blurbs (ONB-R91).
local function everyModule()
	return modules({
		{ "Ledger", "Ledger", 10, "Your book." },
		{ "Hunts", "Hunts", 20, "Fish that only bite at night." },
		{ "Stats", "Stats", 30, "Your own numbers." },
		{ "TackleBoard", "Tackle Board", 40, "Small goals." },
		{ "QoL", "QoL", 50 },
	})
end

describe("Welcome's count of parts (ONB-R30)", function()
	it("names the roster's size in words: Pagle comes in five parts", function()
		assert.are.equal(
			"Pagle comes in five parts. Turn any of them off in the AddOns list and it leaves no trace.",
			ns.GuidePartsLine(#ns.MODULE_ROSTER)
		)
	end)

	it("writes small counts in words and larger ones in figures", function()
		assert.are.same(
			{ "no", "one", "two", "five" },
			{ ns.GuideCountWord(0), ns.GuideCountWord(1), ns.GuideCountWord(2), ns.GuideCountWord(5) }
		)
		assert.are.same({ "ten", "11" }, { ns.GuideCountWord(10), ns.GuideCountWord(11) })
	end)
end)

describe("What's in the box (ONB-R31, ONB-R91, ONB-R102, ONB-R103)", function()
	it("has a row per registered Module in def.order, its icon, title and blurb, then the Curio Shop's", function()
		local rows = ns.GuideBoxRows(everyModule())

		local read = {}
		for i, row in ipairs(rows) do
			read[i] = { row.sprite, row.title, row.blurb or false }
		end
		assert.are.same({
			{ "ic-journal", "Ledger", "Your book." },
			{ "ic-hunts", "Hunts", "Fish that only bite at night." },
			{ "ic-stats", "Stats", "Your own numbers." },
			{ "ic-board", "Tackle Board", "Small goals." },
			{ "ic-qol", "QoL", false },
			{ "ic-shop", "Curio Shop", "Pagle Coins come from things you achieve, and buy looks, never power." },
		}, read)
	end)

	it("counts the registered Modules in its kicker, in words: Five parts, and a shop", function()
		assert.are.equal("Five parts, and a shop", ns.GuideBoxKicker(5))
		assert.are.equal("Four parts, and a shop", ns.GuideBoxKicker(4))
		assert.are.equal("One part, and a shop", ns.GuideBoxKicker(1))
	end)

	it("leaves out a Module that is off (ONB-R102)", function()
		local rows = ns.GuideBoxRows(modules({ { "Hunts", "Hunts", 20 }, { "QoL", "QoL", 50 } }))

		assert.are.same({ "Hunts", "QoL", "Curio Shop" }, { rows[1].title, rows[2].title, rows[3].title })
	end)

	it("shows only the Curio Shop with every Module off (ONB-R103)", function()
		local rows = ns.GuideBoxRows({})

		assert.are.same({ "Curio Shop" }, { rows[1].title, rows[2] })
		assert.are.equal("Turn parts on in the AddOns list.", ns.L.GUIDE_BOX_NONE)
	end)
end)

describe("the Moments presets (ONB-R35)", function()
	it("writes Lively: Cozy mode off, Show every catch on, the budget on at 40 per 5 min", function()
		local announcements = defaults()
		announcements.cozy, announcements.everyCatch = true, false
		announcements.budget = { on = false, count = 3, window = 60 }

		ns.ApplyGuidePreset(announcements, "lively")

		assert.are.same(
			{ cozy = false, everyCatch = true, motion = true, budget = { on = true, count = 40, window = 300 } },
			announcements
		)
	end)

	it("writes Quieter: Cozy mode off, Show every catch off, the budget on at 10 per 5 min", function()
		local announcements = defaults()
		announcements.cozy = true

		ns.ApplyGuidePreset(announcements, "quieter")

		assert.are.same(
			{ cozy = false, everyCatch = false, motion = true, budget = { on = true, count = 10, window = 300 } },
			announcements
		)
	end)

	it("writes Cozy: Cozy mode on, everything else as it was", function()
		local announcements = defaults()
		announcements.everyCatch = false
		announcements.budget = { on = false, count = 7, window = 120 }

		ns.ApplyGuidePreset(announcements, "cozy")

		assert.are.same(
			{ cozy = true, everyCatch = false, motion = true, budget = { on = false, count = 7, window = 120 } },
			announcements
		)
	end)

	it("never touches Animations, and keeps the budget table it found", function()
		local announcements = defaults()
		announcements.motion = false
		local budget = announcements.budget

		ns.ApplyGuidePreset(announcements, "quieter")

		assert.is_false(announcements.motion)
		assert.are.equal(budget, announcements.budget)
	end)

	it("chooses the preset the settings match: Lively for the defaults, a new Angler's", function()
		assert.are.equal("lively", ns.GuidePresetOf(defaults()))
		for _, id in ipairs({ "lively", "quieter", "cozy" }) do
			local announcements = defaults()
			ns.ApplyGuidePreset(announcements, id)
			assert.are.equal(id, ns.GuidePresetOf(announcements))
		end
	end)

	it("matches Cozy whenever Cozy mode is on, whatever else is set", function()
		local announcements = defaults()
		announcements.cozy, announcements.everyCatch, announcements.budget.count = true, false, 3

		assert.are.equal("cozy", ns.GuidePresetOf(announcements))
	end)

	it("matches none for a hand-set mix", function()
		for _, change in ipairs({
			function(a)
				a.budget.count = 19
			end,
			function(a)
				a.budget.window = 240
			end,
			function(a)
				a.budget.on = false
			end,
			function(a)
				a.everyCatch = false
			end,
		}) do
			local announcements = defaults()
			change(announcements)
			assert.is_nil(ns.GuidePresetOf(announcements))
		end
	end)

	it("lists Lively, Quieter and Cozy, in that order, each card's pencilled line naming its numbers", function()
		local cards = {}
		for i, preset in ipairs(ns.GUIDE_PRESETS) do
			cards[i] = { preset.id, ns.GuidePresetWhat(preset) }
		end

		assert.are.same({
			{ "lively", "40 pop-ups in 5 minutes" },
			{ "quieter", "10 pop-ups in 5 minutes" },
			{ "cozy", "a Legend still shows, silently" },
		}, cards)
	end)
end)

describe("Off you go (ONB-R38, ONB-R61)", function()
	-- The First looks registered (ns.firstLooks:List()): each as { owner, title }.
	local function looks(list)
		local records = {}
		for i, look in ipairs(list) do
			records[i] = { owner = look[1], set = { id = look[1]:lower() .. ".window", title = look[2] } }
		end
		return records
	end
	-- Every set ONB-R57 lists, registered out of order, the Curio Shop's first as Core's adapter has it.
	local EVERY_LOOK = looks({
		{ "Core", "the Curio Shop" },
		{ "TackleBoard", "the Tackle Board" },
		{ "Ledger", "the Fish Journal" },
		{ "Stats", "Stats" },
		{ "Hunts", "Hunts" },
	})

	it("names the windows with First looks registered, the Modules' in def.order, then the Curio Shop", function()
		assert.are.equal(
			"Don’t want notes? Turn off Margin notes in Settings. The Fish Journal, Hunts, Stats, the Tackle Board"
				.. " and the Curio Shop each get a short set the first time you open them.",
			ns.GuideLooksLine(ns.GuideLookWindows(everyModule(), EVERY_LOOK))
		)
	end)

	it("names only the registered ones, and the Curio Shop alone with no Module's set", function()
		assert.are.equal(
			"Don’t want notes? Turn off Margin notes in Settings. Stats and the Curio Shop each get a short set the"
				.. " first time you open them.",
			ns.GuideLooksLine(
				ns.GuideLookWindows(modules({ { "Stats", "Stats", 30 }, { "QoL", "QoL", 50 } }), EVERY_LOOK)
			)
		)
		assert.are.equal(
			"Don’t want notes? Turn off Margin notes in Settings. The Curio Shop gets a short set the first time you"
				.. " open it.",
			ns.GuideLooksLine(ns.GuideLookWindows(everyModule(), looks({ { "Core", "the Curio Shop" } })))
		)
	end)

	it("previews each item of the First evening list whose owner is registered, in order (ONB-R61)", function()
		local items = ns.GuideEveningPreview(everyModule())

		local read = {}
		for i, item in ipairs(items) do
			read[i] = { item.id, item.text, item.hint or false }
		end
		assert.are.same({
			{ "cast", "Make a Cast", "press your Fishing key, or double right-click" },
			{ "catch", "Land a Catch", false },
			{ "journal", "Open the Fish Journal", false },
			{ "hunts", "See what’s biting on Hunts", false },
			{ "session", "Finish a Session", "step away 5 minutes for your summary" },
			{ "shop", "Peek into the Curio Shop", false },
		}, read)
	end)

	it("leaves out the Ledger's and Hunts' items when they're off, with the QoL-off hint to cast (ONB-R101)", function()
		local items = ns.GuideEveningPreview(modules({ { "Stats", "Stats", 30 } }))

		local ids = {}
		for i, item in ipairs(items) do
			ids[i] = item.id
		end
		assert.are.same({ "cast", "catch", "session", "shop" }, ids)
		assert.are.equal("right-click the water with Fishing", items[1].hint)
	end)
end)
