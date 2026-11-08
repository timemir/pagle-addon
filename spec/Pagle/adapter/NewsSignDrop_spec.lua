-- The news sign with real news (core/news-sign.md SIGN-R14–R19, SIGN-R40, SIGN-R57; onboarding.md ONB-R17): one
-- decision a session, 5 s after the first PLAYER_ENTERING_WORLD; the floor, the holds and what is marked seen; the
-- pick's words and the more line; the equipped look; and the letters, one at a time with the sign. Through the real
-- TOC and the fake client, over Core's real news reader (VIEW-R40–R46): Pagle_Following installed with IGV Contracts'
-- news example (anglerFileExamples().news) carrying each spec's lines, Pagle.GetNews, MarkNewsSeen and NewsWords
-- watched as the sign calls them.

local DAY = 86400
local LETTER_DELAY = 4

-- Runs `seconds` of frames at 30 a second.
local function run(loaded, seconds)
	for _ = 1, math.floor(seconds * 30 + 0.5) do
		loaded.client.nextFrame(1 / 30)
	end
end

local serial = 0
-- A news line of `kind` (IGV Contracts' fields), `ago` seconds before the fake client's server time at login.
local function item(kind, ago, fields)
	serial = serial + 1
	local it = {
		id = ("%016x"):format(serial),
		kind = kind,
		time = SERVER_TIME - (ago or 600),
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

-- PagleDB with the sign's floor set a day ago (SIGN-R18), the items of `seen` marked seen (VIEW-R44), and `global`
-- merged into its global table.
local function floored(global, seen)
	local saved = { global = { news = { since = SERVER_TIME - DAY, seen = {} } } }
	for _, it in ipairs(seen or {}) do
		saved.global.news.seen[it.id] = it.time
	end
	for k, v in pairs(global or {}) do
		saved.global[k] = v
	end
	return saved
end

-- Installs Pagle_Following on `loaded`, before PLAYER_LOGIN, with the news example's file carrying the lines `items`
-- in state `watch.state`: "ok" (written ten minutes ago), "expired" (written past the view expiry age, VIEW-R2),
-- "none" (a Companion that predates the news: no news block) or "absent" (not installed). Then watches Core's news
-- API: each Pagle.GetNews counted in `watch.reads`, each Pagle.MarkNewsSeen in `watch.marked` ("all" for no ids),
-- each item Pagle.NewsWords words in `watch.worded`, its words in `watch.words[id]`; each still Core's own.
local function installNews(loaded, items, watch)
	watch.reads, watch.marked, watch.worded = 0, {}, {}
	if watch.state ~= "absent" then
		local data = anglerFileExamples().news
		data.generatedAt = watch.state == "expired" and SERVER_TIME - 2 * DAY or SERVER_TIME - 600
		data.news = watch.state ~= "none" and items or nil
		loaded.client.addons.Pagle_Following = { metadata = {} }
		loaded.env.PagleFollowingData = data
	end
	local Pagle = loaded.env.Pagle
	local getNews, markNewsSeen, newsWords = Pagle.GetNews, Pagle.MarkNewsSeen, Pagle.NewsWords
	Pagle.GetNews = function()
		watch.reads = watch.reads + 1
		return getNews()
	end
	Pagle.MarkNewsSeen = function(ids)
		watch.marked[#watch.marked + 1] = ids or "all"
		return markNewsSeen(ids)
	end
	watch.words = {}
	Pagle.NewsWords = function(it)
		watch.worded[#watch.worded + 1] = it.id
		watch.words[it.id] = newsWords(it)
		return watch.words[it.id]
	end
	return watch
end

-- Whether every item of `items` is marked seen in PagleDB (VIEW-R44).
local function allSeen(loaded, items)
	for _, it in ipairs(items) do
		if not loaded.ns.anglerViews:NewsSeen(it.id) then
			return false
		end
	end
	return true
end

-- Core loaded for a returning Angler (no Letter of its own, ONB-R2) over PagleDB `saved` (the floor set a day ago by
-- default) with the news `items`, logged in; `before(loaded, fake)` runs first, and may set `fake.state`. Its drops
-- are counted in `fake.drops`.
local function login(items, saved, before)
	local loaded = loadCore(history(2), saved or floored())
	local fake = { state = "ok", drops = 0 }
	if before then
		before(loaded, fake)
	end
	installNews(loaded, items, fake)
	local drop = loaded.ns.DropNewsSign
	loaded.ns.DropNewsSign = function(...)
		fake.drops = fake.drops + 1
		return drop(...)
	end
	enterWorld(loaded)
	return loaded, fake
end

-- The news item the sign shows, by its id, or nil with none showing.
local function shownId(loaded)
	local state = loaded.ns.NewsSignState()
	return state and state.id
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

	it("sign_r14_r18: sets no floor while the news isn't ok, so the first login with news still sets it", function()
		for _, state in ipairs({ "absent", "expired", "none" }) do
			local loaded = login({ item("legend") }, {}, function(_, fake)
				fake.state = state
			end)

			loaded.client.advance(6)

			local kept = loaded.ns.db.global.news
			assert(kept == nil or kept.since == nil, state)
		end
	end)

	it("sign_r14_r18: with no floor yet sets it to now, marks every item seen and drops nothing", function()
		local legend = item("legend")
		local loaded, fake = login({ legend }, {})

		loaded.client.advance(5)

		assert.are.equal(SERVER_TIME + 5, loaded.ns.db.global.news.since)
		assert.are.same({ "all" }, fake.marked)
		assert.is_true(allSeen(loaded, { legend }))
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
		-- one already seen (VIEW-R44), one older than the floor (SIGN-R18)
		local seen, old = item("legend"), item("zone", 2 * DAY)
		local loaded, fake = login({ seen, old }, floored(nil, { seen }))

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
		assert.are.equal(legend.id, shownId(loaded))
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

	-- The variety fish texture of species 4603 at `position` drawn on the sign, if any.
	local function fishOf(loaded, position)
		local file = loaded.ns.VARIETY_ATLASES[loaded.ns.VARIETY_ART[4603][position][1]]
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
		return fish
	end

	it("sign_r12_r13_var_r27: draws an uncaught variety's fish as a dark silhouette, in NewsWords' words", function()
		-- the Spotted Yellowtail's epic variety, which this Angler hasn't caught
		local colour = item("colour", 600, { item = 4603, key = "tidecaller" })
		local loaded, fake = login({ colour })
		loaded.client.loadItem(4603, "Spotted Yellowtail")

		loaded.client.advance(5)
		run(loaded, 2)

		local said = assert(fake.words[colour.id])
		assert.is_true(said.emblem.variety.silhouette)
		assert.are.equal("Epic Spotted Yellowtail", said.detail)
		assert.truthy(has(words(loaded), said.detail))
		local fish = fishOf(loaded, said.emblem.variety.position)
		assert(fish, "the variety's fish is drawn")
		assert.is_true(fish.desaturated)
		assert.are.same({ 0, 0, 0 }, { fish.vertexColor[1], fish.vertexColor[2], fish.vertexColor[3] })
	end)

	it("sign_r13: draws a caught variety's fish in its colours", function()
		local loaded = login({})
		loaded.client.advance(6)

		loaded.ns.DropNewsSign("wood", {
			kind = "colour",
			kicker = "Rare colour",
			head = "Ada Brook caught a rare colour",
			emblem = { variety = { species = 4603, position = 8 } },
		})
		run(loaded, 2)

		local fish = fishOf(loaded, 8)
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
		assert.are.equal(legend.id, shownId(loaded))
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
		local items = { item("legend"), item("region"), item("zone") }
		local loaded, fake = login(items, floored(nil, { items[3] }))

		loaded.client.advance(5)
		run(loaded, 12)

		assert.are.same({ "all" }, fake.marked)
		assert.is_true(allSeen(loaded, items))
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

		assert.are.equal(legend.id, shownId(loaded))
		assert.are.same({ "all" }, fake.marked)
	end)

	it(
		"sign_r40: waits for the Field guide that Open the letter opens, and drops with its items once it closes",
		function()
			-- a new Angler's Letter at 4 s (ONB-R10), the sign's decision at 5 s, waiting for it
			local legend = item("legend")
			local loaded = loadCore({ BUILD_ENTRY }, floored())
			local fake = installNews(loaded, { legend }, { state = "ok" })
			loaded.ns.db.profile.announcements.motion = false
			enterWorld(loaded, 3)
			loaded.client.advance(5)
			assert.is_true(loaded.ns.letter:IsShowing())
			assert.is_nil(loaded.ns.NewsSignState())

			local frame = assert(loaded.env.PagleLetter)
			assert.are.equal("Open the letter", frame.open.label.text)
			frame.open:Click()
			loaded.client.advance(1)
			assert.is_true(loaded.ns.guide:IsOpen())
			assert.is_nil(loaded.ns.NewsSignState())
			assert.are.same({}, fake.marked)
			loaded.ns.guide:Close()
			loaded.client.advance(0)

			assert.are.equal(legend.id, shownId(loaded))
			assert.are.same({ "all" }, fake.marked)
		end
	)

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
		installNews(loaded, { item("legend") }, { state = "ok" })
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
