-- The Morning Tide's section on the Announcements page (settings.md SET-R37; core/news-sign.md SIGN-R14, SIGN-R15,
-- SIGN-R18, SIGN-R31, Data; from 1.6, #659), through the real TOC and the fake client's Settings panel: its rows in
-- order under their header after the Party block, the kinds and Region headlines indented under the master and greyed
-- with it or in Cozy mode, the values in PagleDB.global.newsSign with nil meaning the default, the floor the master
-- sets when it is turned on, Mute the sign silencing the sign, and the look's slot dropdown, Wood and the looks owned.

-- The section's rows as the panel names them, in SET-R37's order, the look's slot row aside.
local MASTER = "Show news at login"
local KINDS = {
	{ "first", "First reported" },
	{ "legend", "Legends" },
	{ "prestige", "Prestige" },
	{ "ledger", "Ledger completed" },
	{ "colour", "Rare varieties" },
	{ "hunt", "Hunt gold" },
	{ "zone", "Zone Master" },
	{ "monster", "Monster records" },
}
local HEADLINES = "Region headlines"
local MUTE = "Mute the sign"
local LOOK = "News sign"

-- Every row of the section a switch is under the master: the eight kinds, then Region headlines.
local UNDER = {}
for i, kind in ipairs(KINDS) do
	UNDER[i] = kind[2]
end
UNDER[#UNDER + 1] = HEADLINES

-- The news sign's slot as wallet-and-shop.md SHOP-R60 has #660 register it, cut to Wood and two of the looks for sale.
---@param ns table Core's namespace
local function registerSignSlot(ns)
	ns.RegisterCoreSlot({ id = "core.newssign", label = "News sign", category = "Announcements" })
	ns.RegisterCoreGood({ id = "core.newssign.wood", slot = "core.newssign", name = "Wood", default = true })
	ns.RegisterCoreGood({ id = "core.newssign.scroll", slot = "core.newssign", name = "Scroll", tier = 3 })
	ns.RegisterCoreGood({ id = "core.newssign.kraken", slot = "core.newssign", name = "Kraken", tier = 5 })
end

-- Core logged in and in the world over `saved` (a PagleDB), the Ledger registered; with `withSlot`, the news sign's
-- slot registered before the pages are built, as #660 will.
---@param saved table?
---@param withSlot boolean?
local function loggedIn(saved, withSlot)
	local loaded = loadCore(nil, saved)
	loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
	if withSlot then
		registerSignSlot(loaded.ns)
	end
	return enterWorld(loaded, 3)
end

local function page(loaded)
	return assert(loaded.client.settings.category("Announcements"))
end

-- The section's own labels: Legends, Prestige and Zone Master are the Party block's labels too (SET-R36), so these are
-- looked for from the section's header on.
local OWN = { [MASTER] = true, [HEADLINES] = true, [MUTE] = true, [LOOK] = true }
for _, kind in ipairs(KINDS) do
	OWN[kind[2]] = true
end

-- The index of the first of `list` named `label`, from the section's header on when it is one of the section's own.
---@param list table[]
---@param nameOf fun(entry: table): string?
---@param label string
local function find(list, nameOf, label)
	local after = not OWN[label]
	for i, entry in ipairs(list) do
		after = after or nameOf(entry) == "The Morning Tide"
		if after and nameOf(entry) == label then
			return i
		end
	end
	error("no row " .. label)
end

-- The initializer named `label` on the Announcements page.
local function row(loaded, label)
	local initializers = page(loaded).layout.initializers
	return initializers[find(initializers, function(initializer)
		return initializer:GetName()
	end, label)]
end

-- The page's row names from the section's header on.
local function sectionNames(loaded)
	local names, after = {}, false
	for _, initializer in ipairs(page(loaded).layout.initializers) do
		after = after or initializer:GetName() == "The Morning Tide"
		if after then
			names[#names + 1] = initializer:GetName()
		end
	end
	return names
end

-- Whether the shown row named `label` is live, not greyed out (SET-R31).
local function live(loaded, label)
	local settings = loaded.client.settings
	local rows = settings.show(page(loaded))
	local shown = rows[find(rows, function(entry)
		return entry.initializer:GetName()
	end, label)]
	if shown.initializer:GetTemplate() == "PagleSettingsSlotRowTemplate" then
		return settings.dropdownOf(shown):IsEnabled()
	end
	return shown.frame.enabled ~= false
end

local function value(loaded, label)
	return row(loaded, label):GetSetting():GetValue()
end

local function set(loaded, label, to)
	row(loaded, label):GetSetting():SetValue(to)
end

describe("The Morning Tide's section (SET-R37)", function()
	it("follows the Party block under its header: the master, its nine rows indented, then Mute the sign", function()
		local loaded = loggedIn()

		local names = sectionNames(loaded)

		local expected = { "The Morning Tide", MASTER }
		for _, label in ipairs(UNDER) do
			expected[#expected + 1] = label
		end
		expected[#expected + 1] = MUTE
		assert.are.same(expected, names)
		local master = row(loaded, MASTER)
		for _, label in ipairs(UNDER) do
			assert.are.equal(master, row(loaded, label):GetParentInitializer(), label)
		end
		assert.is_nil(master:GetParentInitializer())
		assert.is_nil(row(loaded, MUTE):GetParentInitializer())
		-- The Party block's last row comes just before it (SET-R36).
		local initializers = page(loaded).layout.initializers
		for i, initializer in ipairs(initializers) do
			if initializer:GetName() == "The Morning Tide" then
				assert.are.equal("Cheers sounds", initializers[i - 1]:GetName())
			end
		end
	end)

	it("gives the master, Region headlines and Mute the sign their tooltips", function()
		local loaded = loggedIn()

		assert.are.equal(
			"At login or /reload, a sign drops in with the best news about the Anglers you follow on the Pagle website."
				.. " Needs the Pagle Companion. A left click opens the rest in the Fish Journal.",
			row(loaded, MASTER):GetTooltip()
		)
		assert.are.equal(
			"Who was first in your region this month to land a Legend, whether you follow them or not.",
			row(loaded, HEADLINES):GetTooltip()
		)
		assert.are.equal(
			"The sign drops without its sounds. The game's sound settings still apply.",
			row(loaded, MUTE):GetTooltip()
		)
		for _, kind in ipairs(KINDS) do
			assert(row(loaded, kind[2]):GetTooltip() == nil, kind[2])
		end
	end)
end)

describe("The Morning Tide's values (SET-R37, news-sign.md › Data)", function()
	it("reads every switch on and the sign unmuted with nothing stored", function()
		local loaded = loggedIn()

		assert.is_true(value(loaded, MASTER))
		for _, label in ipairs(UNDER) do
			assert(value(loaded, label) == true, label)
		end
		assert.is_false(value(loaded, MUTE))
		assert.is_nil(loaded.ns.db.global.newsSign)
	end)

	it("stores each kind by its key in newsSign.kinds, false for off, and clears it for on", function()
		local loaded = loggedIn()

		for _, kind in ipairs(KINDS) do
			set(loaded, kind[2], false)
		end
		set(loaded, HEADLINES, false)
		set(loaded, MASTER, false)
		set(loaded, MUTE, true)

		assert.are.same({
			show = false,
			kinds = {
				first = false,
				legend = false,
				prestige = false,
				ledger = false,
				colour = false,
				hunt = false,
				zone = false,
				monster = false,
			},
			headlines = false,
			mute = true,
		}, loaded.ns.db.global.newsSign)

		for _, kind in ipairs(KINDS) do
			set(loaded, kind[2], true)
		end
		set(loaded, HEADLINES, true)
		set(loaded, MASTER, true)
		set(loaded, MUTE, false)
		assert.are.same({ kinds = {} }, loaded.ns.db.global.newsSign)
	end)

	it("reads what a saved PagleDB holds, a missing kind as on, and keeps the sign's spot", function()
		local loaded = loggedIn({
			global = {
				newsSign = { point = { x = 0.5, y = 0.1 }, show = false, kinds = { hunt = false }, mute = true },
			},
		})

		assert.is_false(value(loaded, MASTER))
		assert.is_false(value(loaded, "Hunt gold"))
		assert.is_true(value(loaded, "Zone Master"))
		assert.is_true(value(loaded, HEADLINES))
		assert.is_true(value(loaded, MUTE))

		set(loaded, MUTE, false)
		assert.are.same({ x = 0.5, y = 0.1 }, loaded.ns.db.global.newsSign.point)
	end)

	it("is restored by the page's Defaults: every switch on and the sign unmuted (SET-R33)", function()
		local loaded = loggedIn()
		set(loaded, MASTER, false)
		set(loaded, "Monster records", false)
		set(loaded, HEADLINES, false)
		set(loaded, MUTE, true)

		loaded.client.settings.defaults(page(loaded))

		assert.is_true(value(loaded, MASTER))
		for _, label in ipairs(UNDER) do
			assert(value(loaded, label) == true, label)
		end
		assert.is_false(value(loaded, MUTE))
	end)
end)

describe("Greying in The Morning Tide (SET-R37, SET-R31, SET-R61)", function()
	it("greys the kinds and Region headlines while the master is off, keeping their values", function()
		local loaded = loggedIn()
		set(loaded, "Legends", false)

		set(loaded, MASTER, false)

		for _, label in ipairs(UNDER) do
			assert(live(loaded, label) == false, label)
		end
		assert.is_true(live(loaded, MASTER))
		assert.is_true(live(loaded, MUTE))
		assert.is_false(value(loaded, "Legends"))

		set(loaded, MASTER, true)
		for _, label in ipairs(UNDER) do
			assert(live(loaded, label) == true, label)
		end
	end)

	it("greys the master and its rows in Cozy mode, and never Mute the sign or the look", function()
		local loaded = loggedIn(nil, true)

		set(loaded, "Cozy mode", true)

		assert.is_false(live(loaded, MASTER))
		for _, label in ipairs(UNDER) do
			assert(live(loaded, label) == false, label)
		end
		assert.is_true(live(loaded, MUTE))
		assert.is_true(live(loaded, LOOK))

		set(loaded, "Cozy mode", false)
		assert.is_true(live(loaded, MASTER))
		assert.is_true(live(loaded, "First reported"))
	end)
end)

describe("Turning Show news at login on (SET-R37, SIGN-R18)", function()
	it("sets the news floor to the server time, and leaves it while the master is turned off", function()
		local loaded = loggedIn()
		set(loaded, MASTER, false)
		assert.is_nil(loaded.ns.db.global.news and loaded.ns.db.global.news.since)

		loaded.client.advance(60)
		set(loaded, MASTER, true)

		assert.are.equal(SERVER_TIME + 60, loaded.ns.db.global.news.since)
		loaded.client.advance(60)
		set(loaded, MASTER, false)
		assert.are.equal(SERVER_TIME + 60, loaded.ns.db.global.news.since)
	end)

	it("keeps the floor and the seen items when the master is set on while already on", function()
		local loaded =
			loggedIn({ global = { news = { since = SERVER_TIME - 600, seen = { ["0123456789abcdef"] = 1 } } } })

		set(loaded, MASTER, true)
		loaded.client.settings.defaults(page(loaded))

		assert.are.same({ since = SERVER_TIME - 600, seen = { ["0123456789abcdef"] = 1 } }, loaded.ns.db.global.news)
	end)

	it("sets the floor when the page's Defaults turns the sign back on (SET-R37)", function()
		local loaded = loggedIn({ global = { news = { since = SERVER_TIME - 600, seen = {} } } })
		set(loaded, MASTER, false)
		loaded.client.advance(30)

		loaded.client.settings.defaults(page(loaded))

		assert.is_true(value(loaded, MASTER))
		assert.are.equal(SERVER_TIME + 30, loaded.ns.db.global.news.since)
		assert.are.same({}, loaded.ns.db.global.news.seen)
	end)
end)

describe("Mute the sign (SET-R37, SIGN-R31)", function()
	-- The sign's sounds played over two seconds of a Wood drop with sample news.
	local function dropSounds(loaded)
		local before = #loaded.client.sounds
		loaded.ns.DropNewsSign("wood", loaded.ns.NewsSignSample("first"))
		for _ = 1, 60 do
			loaded.client.nextFrame(1 / 30)
		end
		local names = {}
		for i = before + 1, #loaded.client.sounds do
			names[#names + 1] = loaded.client.sounds[i]:match("sign\\sounds\\([%w_]+)%.ogg SFX$")
		end
		return names
	end

	it("silences the sign once ticked, and lets it play again once unticked", function()
		local loaded = loggedIn()
		set(loaded, MUTE, true)

		assert.are.same({}, dropSounds(loaded))

		loaded.ns.SendNewsSignUp()
		for _ = 1, 60 do
			loaded.client.nextFrame(1 / 30)
		end
		set(loaded, MUTE, false)
		assert.are.same({ "wood_land", "wood_creak", "wood_creak" }, dropSounds(loaded))
	end)
end)

describe("The Morning Tide's look (SET-R37, SET-R51, SHOP-R60)", function()
	it("has no row while Core has no news sign slot, so the section ends with Mute the sign", function()
		local loaded = loggedIn()

		local names = sectionNames(loaded)

		assert.are.equal(MUTE, names[#names])
	end)

	it("ends the section with the slot's dropdown, Wood alone while no other look is owned", function()
		local loaded = loggedIn(nil, true)
		local settings = loaded.client.settings

		local names = sectionNames(loaded)

		assert.are.same({ MUTE, LOOK }, { names[#names - 1], names[#names] })
		assert.is_nil(row(loaded, LOOK):GetParentInitializer())
		local look = settings.rowNamed(settings.show(page(loaded)), LOOK)
		assert.are.same({ "core.newssign.wood=Wood" }, settings.optionValues(look))
		assert.are.equal("core.newssign.wood", settings.dropdownOf(look).selected)
		assert.are.same({ "2 more in the Curio Shop" }, settings.notesOf(look))
	end)

	it("lists Wood and each look owned, in registration order, and picking one equips it", function()
		local loaded = loggedIn(nil, true)
		local settings = loaded.client.settings
		loaded.ns.goods:SetPurchased({ ["core.newssign.kraken"] = true })
		local look = settings.rowNamed(settings.show(page(loaded)), LOOK)

		assert.are.same({ "core.newssign.wood=Wood", "core.newssign.kraken=Kraken" }, settings.optionValues(look))

		settings.dropdownOf(look):pick("core.newssign.kraken")
		assert.are.equal("core.newssign.kraken", loaded.env.Pagle.GetEquipped("core.newssign"))

		loaded.client.settings.defaults(page(loaded))
		assert.are.equal("core.newssign.wood", loaded.env.Pagle.GetEquipped("core.newssign"))
		assert.is_true(loaded.env.Pagle.IsOwned("core.newssign.kraken"))
	end)

	it("isn't among Core's rows before Toast position, Toast style and Sound set being the only looks there", function()
		local loaded = loggedIn(nil, true)
		local names = {}
		for _, initializer in ipairs(page(loaded).layout.initializers) do
			if initializer:GetName() == "Toast position" then
				break
			end
			names[#names + 1] = initializer:GetName()
		end

		assert.are.same({
			"Cozy mode",
			"Interruption budget",
			"Interruptions",
			"Per",
			"Show every catch",
			"Animations",
			"Toast style",
			"Sound set",
		}, names)
	end)
end)
