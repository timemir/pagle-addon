-- The news sign with real news (core/news-sign.md SIGN-R14–R19, SIGN-R40, SIGN-R57; onboarding.md ONB-R17): one
-- decision a session, 5 s after the first PLAYER_ENTERING_WORLD; the floor, the holds and what is marked seen; the
-- pick's words and the more line; the equipped look; and the letters, one at a time with the sign. Through the real
-- TOC and the fake client. The news itself is VIEW-R40–R46's (#656): Pagle.GetNews, MarkNewsSeen and NewsWords are
-- faked here as those rules give them, so the sign's side is what these check.

local DAY = 86400
local LETTER_DELAY = 4

-- Runs `seconds` of frames at 30 a second.
local function run(loaded, seconds)
	for _ = 1, math.floor(seconds * 30 + 0.5) do
		loaded.client.nextFrame(1 / 30)
	end
end

local serial = 0
-- A news line of `kind`, `ago` seconds before the fake client's server time at login, as VIEW-R42 hands it out: new.
local function item(kind, ago, fields)
	serial = serial + 1
	local it = {
		id = ("%016x"):format(serial),
		kind = kind,
		time = SERVER_TIME - (ago or 600),
		new = true,
		angler = 1,
		name = "Kukli Emnabi",
		region = "eu",
		item = 0,
		rank = 0,
		key = "",
		text = "",
		zone = 0,
		length = 0,
	}
	for k, v in pairs(fields or {}) do
		it[k] = v
	end
	return it
end

-- PagleDB with the sign's floor set a day ago (SIGN-R18), and `global` merged into its global table.
local function floored(global)
	local saved = { global = { news = { since = SERVER_TIME - DAY, seen = {} } } }
	for k, v in pairs(global or {}) do
		saved.global[k] = v
	end
	return saved
end

-- Fakes VIEW-R42–R45 on `loaded` over `items`: GetNews reads them in state `fake.state` ("ok"), MarkNewsSeen records
-- each call in `fake.marked` ("all" for no ids), NewsWords words an item as "News <id>" with the item's `detail` and
-- `emblem` (the laurel by default) and records its id in `fake.worded`.
local function fakeNews(loaded, items)
	local fake = { state = "ok", marked = {}, worded = {}, reads = 0 }
	local Pagle = loaded.env.Pagle
	Pagle.GetNews = function()
		fake.reads = fake.reads + 1
		local copy = {}
		if fake.state == "ok" then
			for i, it in ipairs(items) do
				copy[i] = it
			end
		end
		return { state = fake.state, items = copy }
	end
	Pagle.MarkNewsSeen = function(ids)
		fake.marked[#fake.marked + 1] = ids or "all"
	end
	Pagle.NewsWords = function(it)
		fake.worded[#fake.worded + 1] = it.id
		return {
			kind = it.kind,
			kicker = "Kicker " .. it.kind,
			head = "News " .. it.id,
			detail = it.detail,
			emblem = it.emblem or { sign = "laurel" },
		}
	end
	return fake
end

-- Core loaded for a returning Angler (no Letter of its own, ONB-R2) over PagleDB `saved` (the floor set a day ago by
-- default) with the news `items`, logged in; its drops counted in `fake.drops`.
local function login(items, saved, before)
	local loaded = loadCore(history(2), saved or floored())
	local fake = fakeNews(loaded, items)
	fake.drops = 0
	local drop = loaded.ns.DropNewsSign
	loaded.ns.DropNewsSign = function(...)
		fake.drops = fake.drops + 1
		return drop(...)
	end
	if before then
		before(loaded, fake)
	end
	enterWorld(loaded)
	return loaded, fake
end

-- The texts of the sign's font strings that show.
local function words(loaded)
	local out = {}
	local function walk(region)
		for _, child in ipairs(region.children or {}) do
			if child.kind == "FontString" and child.shown ~= false and child.text then
				out[#out + 1] = child.text
			end
			walk(child)
		end
	end
	local frame = loaded.ns.NewsSignFrame()
	if frame then
		walk(frame)
	end
	return out
end

local function has(list, value)
	for _, v in ipairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

describe("When the sign drops (SIGN-R14)", function()
	it("sign_r14: decides once, 5 s after the session's first PLAYER_ENTERING_WORLD, and drops", function()
		local loaded, fake = login({ item("legend") })

		loaded.client.advance(4.9)
		assert.are.equal(0, fake.reads)
		assert.is_nil(loaded.ns.NewsSignState())
		loaded.client.advance(0.1)

		assert.are.equal(1, fake.reads)
		assert.are.equal(1, fake.drops)
		assert.is_not_nil(loaded.ns.NewsSignState())
	end)

	it("sign_r14: drops once a session, whatever loading screens follow", function()
		local loaded, fake = login({ item("legend") })
		loaded.client.advance(3)
		loaded.client.fire("PLAYER_ENTERING_WORLD", false, false)
		loaded.client.advance(20)
		loaded.client.fire("PLAYER_ENTERING_WORLD", false, false)
		loaded.client.advance(20)

		assert.are.equal(1, fake.reads)
		assert.are.equal(1, fake.drops)
	end)

	it("sign_r14: reads and marks nothing, and drops nothing, while the news isn't ok", function()
		for _, state in ipairs({ "absent", "expired", "none" }) do
			local loaded, fake = login({ item("legend") }, nil, function(_, fake)
				fake.state = state
			end)
			loaded.client.advance(6)

			assert.are.same({}, fake.marked, state)
			assert.are.equal(0, fake.drops, state)
			assert.are.same({}, fake.worded, state)
		end
	end)

	it("sign_r14: does nothing on a Core without the news reader (VIEW-R42 not there)", function()
		local loaded = login({}, nil, function(loaded)
			loaded.env.Pagle.GetNews = nil
		end)

		loaded.client.advance(6)

		assert.is_nil(loaded.ns.NewsSignState())
		assert.are.equal(SERVER_TIME - DAY, loaded.ns.db.global.news.since)
	end)

	it("sign_r14_r18: with no floor yet sets it to now, marks every item seen and drops nothing", function()
		local loaded, fake = login({ item("legend") }, {})

		loaded.client.advance(5)

		assert.are.equal(SERVER_TIME + 5, loaded.ns.db.global.news.since)
		assert.are.same({ "all" }, fake.marked)
		assert.are.equal(0, fake.drops)
	end)

	it("sign_r14_r17: with Show news at login off, drops nothing and marks every item seen (SET-R37)", function()
		local loaded, fake = login({ item("legend") }, floored({ newsSign = { show = false } }))

		loaded.client.advance(5)

		assert.are.same({ "all" }, fake.marked)
		assert.are.equal(0, fake.drops)
	end)

	it("sign_r14_r17: Cozy mode holds the sign and marks every item seen (ANN-R40)", function()
		local loaded, fake = login({ item("legend"), item("region") }, nil, function(loaded)
			loaded.ns.db.profile.announcements.cozy = true
		end)

		loaded.client.advance(5)

		assert.are.same({ "all" }, fake.marked)
		assert.are.equal(0, fake.drops)
		assert.is_nil(loaded.ns.NewsSignState())
	end)

	it("sign_r14: with nothing due, drops nothing and marks every item seen", function()
		local loaded, fake = login({ item("legend", 600, { new = false }), item("zone", 2 * DAY) })

		loaded.client.advance(5)

		assert.are.same({ "all" }, fake.marked)
		assert.are.equal(0, fake.drops)
	end)
end)

describe("What the sign shows (SIGN-R15, SIGN-R16, SIGN-R19)", function()
	it("sign_r15_r16: drops the pick's words with '+N more' for the other due followed items", function()
		local zone, legend, monster, headline = item("zone"), item("legend"), item("monster"), item("region")
		local loaded, fake = login({ zone, headline, monster, legend })

		loaded.client.advance(5)
		run(loaded, 2)

		local shown = words(loaded)
		assert.truthy(has(shown, "News " .. legend.id))
		assert.truthy(has(shown, "Kicker legend"))
		assert.truthy(has(shown, "+2 more from your anglers"))
		assert.are.same({ legend.id }, fake.worded)
	end)

	it("sign_r16: leaves the more line out at 0, and beside a region headline", function()
		local loaded = login({ item("region"), item("region") })

		loaded.client.advance(5)
		run(loaded, 2)

		for _, text in ipairs(words(loaded)) do
			assert(not text:find("more from your anglers", 1, true), text)
		end
	end)

	it("sign_r15_r16: reads each kind's switch and Region headlines from PagleDB.global.newsSign (SET-R37)", function()
		local legend, zone, monster, headline = item("legend"), item("zone"), item("monster"), item("region", 60)
		local loaded, fake = login(
			{ legend, zone, monster, headline },
			floored({ newsSign = { kinds = { legend = false, monster = false } } })
		)

		loaded.client.advance(5)
		run(loaded, 2)

		assert.are.same({ zone.id }, fake.worded)
		for _, text in ipairs(words(loaded)) do
			assert(not text:find("more from your anglers", 1, true), text)
		end
	end)

	it("sign_r15: with Region headlines off, a headline alone drops nothing (SET-R37)", function()
		local loaded, fake = login({ item("region") }, floored({ newsSign = { headlines = false } }))

		loaded.client.advance(5)

		assert.are.equal(0, fake.drops)
		assert.are.same({ "all" }, fake.marked)
	end)

	it("sign_r19: waits up to 2 s for an item name the client hasn't loaded, and words it once it has", function()
		local legend = item("legend", 600, { item = 19805 })
		local loaded, fake = login({ legend })
		loaded.client.itemNames[19805] = nil

		loaded.client.advance(5)
		assert.are.equal(0, fake.drops)
		loaded.client.advance(1)
		loaded.client.loadItem(19805, "Keefer's Angelfish")

		assert.are.equal(1, fake.drops)
		assert.are.same({ legend.id }, fake.worded)
		loaded.client.advance(2)
		assert.are.equal(1, fake.drops)
	end)

	it("sign_r19: drops after the name wait though the name never comes", function()
		local loaded, fake = login({ item("monster", 600, { item = 13422 }) })
		loaded.client.itemNames[13422] = nil

		loaded.client.advance(5 + 1.9)
		assert.are.equal(0, fake.drops)
		loaded.client.advance(0.1)

		assert.are.equal(1, fake.drops)
	end)

	it("sign_r12_r13_var_r27: draws an uncaught variety's fish as a dark silhouette, in NewsWords' words", function()
		local colour = item("colour", 600, {
			detail = "Epic Spotted Yellowtail",
			emblem = { variety = { species = 4603, position = 8, silhouette = true } },
		})
		local loaded = login({ colour })

		loaded.client.advance(5)
		run(loaded, 2)

		assert.truthy(has(words(loaded), "Epic Spotted Yellowtail"))
		local art = loaded.ns.VARIETY_ART[4603][8]
		local file = loaded.ns.VARIETY_ATLASES[art[1]]
		local fish
		local function walk(region)
			for _, child in ipairs(region.children or {}) do
				if child.kind == "Texture" and child.texture == file and child.shown ~= false then
					fish = child
				end
				walk(child)
			end
		end
		walk(loaded.ns.NewsSignFrame())
		assert(fish, "the variety's fish is drawn")
		assert.is_true(fish.desaturated)
		assert.are.same({ 0, 0, 0 }, { fish.vertexColor[1], fish.vertexColor[2], fish.vertexColor[3] })
	end)

	it("sign_r13: draws a caught variety's fish in its colours", function()
		local loaded = login({ item("colour", 600, { emblem = { variety = { species = 4603, position = 8 } } }) })

		loaded.client.advance(5)
		run(loaded, 2)

		local file = loaded.ns.VARIETY_ATLASES[loaded.ns.VARIETY_ART[4603][8][1]]
		local fish
		local function walk(region)
			for _, child in ipairs(region.children or {}) do
				if child.kind == "Texture" and child.texture == file and child.shown ~= false then
					fish = child
				end
				walk(child)
			end
		end
		walk(loaded.ns.NewsSignFrame())
		assert(fish, "the variety's fish is drawn")
		assert.is_falsy(fish.desaturated)
		assert.are.same({ 1, 1, 1 }, { fish.vertexColor[1], fish.vertexColor[2], fish.vertexColor[3] })
	end)
end)

describe("Holds, and marking seen (SIGN-R17, SIGN-R40)", function()
	it("sign_r40_r17: in combat the drop waits, keeping its words, and marks nothing until it drops", function()
		local legend = item("legend")
		local loaded, fake = login({ legend, item("zone") })
		setCombat(loaded, true)

		loaded.client.advance(10)
		assert.is_nil(loaded.ns.NewsSignState())
		assert.are.same({}, fake.marked)
		setCombat(loaded, false)
		run(loaded, 2)

		assert.is_not_nil(loaded.ns.NewsSignState())
		assert.are.same({ "all" }, fake.marked)
		assert.truthy(has(words(loaded), "News " .. legend.id))
		assert.are.equal(1, fake.reads)
	end)

	it("sign_r40: waits for an addon restriction to end too", function()
		local loaded, fake = login({ item("legend") })
		loaded.client.fire("ADDON_RESTRICTION_STATE_CHANGED", 1, 2)

		loaded.client.advance(6)
		assert.is_nil(loaded.ns.NewsSignState())
		assert.are.same({}, fake.marked)
		loaded.client.fire("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)

		assert.is_not_nil(loaded.ns.NewsSignState())
		assert.are.same({ "all" }, fake.marked)
	end)

	it("sign_r17: marks every item seen once, as the sign drops", function()
		local loaded, fake = login({ item("legend"), item("region"), item("zone", 600, { new = false }) })

		loaded.client.advance(5)
		run(loaded, 12)

		assert.are.same({ "all" }, fake.marked)
	end)

	it("sign_r17_r60: a drop from /pagle dev sign marks nothing", function()
		local loaded, fake = login({}, nil, function(loaded)
			loaded.env.SlashCmdList.PAGLE("dev on")
		end)
		loaded.client.advance(6)
		fake.marked = {}

		loaded.env.SlashCmdList.PAGLE("dev sign wood first")

		assert.is_not_nil(loaded.ns.NewsSignState())
		assert.are.same({}, fake.marked)
	end)
end)

describe("Which look (SIGN-R57)", function()
	it("sign_r57: wears Wood, the default, with no look equipped", function()
		local loaded = login({ item("legend") })

		loaded.client.advance(5)

		assert.are.equal("wood", loaded.ns.NewsSignState().look)
	end)

	it("sign_r57: wears the look equipped in core.newssign (SHOP-R32)", function()
		local asked
		local loaded = login({ item("legend") }, nil, function(loaded)
			loaded.env.Pagle.GetEquipped = function(slot)
				asked = slot
				return "core.newssign.kraken"
			end
		end)

		loaded.client.advance(5)

		assert.are.equal("core.newssign", asked)
		assert.are.equal("kraken", loaded.ns.NewsSignState().look)
	end)

	it("sign_r57: wears the look equipped when it drops, after a wait for combat", function()
		local equipped = "core.newssign.scroll"
		local loaded = login({ item("legend") }, nil, function(loaded)
			loaded.env.Pagle.GetEquipped = function()
				return equipped
			end
		end)
		setCombat(loaded, true)
		loaded.client.advance(6)

		equipped = "core.newssign.coral"
		setCombat(loaded, false)

		assert.are.equal("coral", loaded.ns.NewsSignState().look)
	end)

	it("sign_r57: falls back to Wood for a look it doesn't know", function()
		local loaded = login({ item("legend") }, nil, function(loaded)
			loaded.env.Pagle.GetEquipped = function()
				return "core.newssign.barrel"
			end
		end)

		loaded.client.advance(5)

		assert.are.equal("wood", loaded.ns.NewsSignState().look)
	end)
end)

describe("The sign and the letters, one at a time (SIGN-R40, ONB-R17)", function()
	it("sign_r40: never drops while a letter shows, and drops with its words once it is answered", function()
		local legend = item("legend")
		local loaded, fake = login({ legend })
		loaded.ns.letter:ShowNow()
		assert.is_true(loaded.ns.letter:IsShowing())

		loaded.client.advance(10)
		assert.is_nil(loaded.ns.NewsSignState())
		assert.are.same({}, fake.marked)
		loaded.ns.letter:Later()
		run(loaded, 2)

		assert.is_not_nil(loaded.ns.NewsSignState())
		assert.truthy(has(words(loaded), "News " .. legend.id))
		assert.are.same({ "all" }, fake.marked)
	end)

	it("onb_r17: a letter due while the sign shows waits until it has gone up, then LETTER_DELAY", function()
		-- a new Angler's Letter, held by the login's card (ONB-R10) until the sign has dropped
		local saved = floored({
			cards = {
				{
					title = "Fishing session",
					numbers = { casts = 1, catches = 1, gotAway = 0, seconds = 60 },
					coins = 0,
					lines = {},
					moments = {},
				},
			},
		})
		local loaded = loadCore({ BUILD_ENTRY }, saved)
		fakeNews(loaded, { item("legend") })
		loaded.ns.db.profile.announcements.motion = false
		enterWorld(loaded, 3)
		loaded.client.advance(5)
		assert.is_not_nil(loaded.ns.NewsSignState())

		loaded.client.pressEscape()
		assert.is_false(loaded.ns.letter:IsShowing())
		-- with Animations off the sign hangs 8 s and goes at once (SIGN-R43)
		loaded.client.advance(7.5)
		assert.is_not_nil(loaded.ns.NewsSignState())
		assert.is_false(loaded.ns.letter:IsShowing())
		loaded.client.advance(0.6)
		assert.is_nil(loaded.ns.NewsSignState())
		loaded.client.advance(LETTER_DELAY - 0.2)
		assert.is_false(loaded.ns.letter:IsShowing())
		loaded.client.advance(0.2)

		assert.is_true(loaded.ns.letter:IsShowing())
	end)
end)
