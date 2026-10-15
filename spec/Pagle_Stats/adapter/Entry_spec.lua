-- An item's entry on a place's right page, on FakePagle (stats.md › UI › Place spread, the item's entry; STA-R43,
-- STA-R45, STA-R46, STA-R50–R54, STA-R60, STA-R61, STA-R72): the watch toggle, Your odds in large ink with its range,
-- scope line or learning bar, the extra sentences, the Dry spell with its luck wording and luck ruler, *In my records*
-- and the link to the item page. A history goes into the Catch log before login, so the projection's first build
-- counts it; the words of every form are logic/Odds_spec.lua's and logic/DrySpell_spec.lua's, read back here as drawn.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local I = stats.IDS
local DARKSHORE, AUBERDINE, ELWYNN = I.DARKSHORE, I.AUBERDINE, I.ELWYNN
local MACKEREL, BLACKMOUTH, FIREFIN, NIGHTFIN, SMALLFISH = I.MACKEREL, I.BLACKMOUTH, I.FIREFIN, I.NIGHTFIN, I.SMALLFISH
local T0 = stats.T0
local HOUR, DAYS = 3600, 86400

-- A Cast record in `zone` (Darkshore if nil) by day at skill 150 + 25 = 175 (Darkshore's line is 170: side hi), as the
-- worked history's. `items` are item IDs (none: got away).
---@param time integer
---@param items integer[]?
---@param zone integer?
local function cast(time, items, zone)
	return stats.cast({ time = time, zone = zone, rank = 150, mod = 25, items = items })
end

-- `n` Casts in Darkshore by day, 10 s apart from T0, catching `catches[i]` on Cast i.
---@param n integer
---@param catches table<integer, integer>
local function castsInDarkshore(n, catches)
	local records = {}
	for i = 1, n do
		records[i] = cast(T0 + 10 * i, catches[i] and { catches[i] })
	end
	return records
end

-- The worked Darkshore history (stats.darkshore, worked by hand there with STA-R43–R45 and STA-R50–R53): Smallfish
-- known and unlucky, Blackmouth known and normal ("About 17 anglers in 100"), Firefin a Dry spell of 0, Mackerel
-- unseen, Nightfin learning 0/100.
local darkshore = stats.darkshore

-- The server time the specs read: 3 hours after Blackmouth's last catch (Cast 20).
local NOW = T0 + 200 + 3 * HOUR

-- Stats over a FakePagle whose log holds `records`, logged in with its projection built, the areas and items named,
-- the player in Darkshore's Auberdine at skill 200 (side hi), Stats' server time at NOW. `options` go to stats.load.
local function ready(records, options)
	options = options or {}
	local loaded, fake = stats.start({
		records = records,
		catalogue = options.catalogue,
		prepare = options.prepare,
		at = { zone = DARKSHORE, subzone = AUBERDINE, skillRank = 200, skillMod = 0 },
	})
	loaded.env.GetServerTime = function()
		return NOW
	end
	return loaded.ns, loaded, fake
end

-- Opens `area`'s page with `item` chosen and returns the entry's view (adapter/Entry.lua keeps it on its frame).
local function entry(ns, area, item)
	ns.OpenBook({ page = "place", area = area, item = item })
	for _, child in ipairs(ns.book.pages["place:right"].content.children) do
		if child.entryView and child.shown then
			return child.entryView
		end
	end
	error("no entry drawn")
end

-- A font string's text if shown, else nil.
local function shown(text)
	return text.shown and text.text or nil
end

-- How far across its parent a part of the ruler sits, as anchored: SetPoint(point, x, y), or SetPoint(point, parent,
-- "TOPLEFT", x, y) for a part centred on x.
local function xOf(region)
	local anchor = region.points[1]
	return type(anchor[2]) == "number" and anchor[2] or anchor[4]
end

describe("an item's entry (stats.md › UI › Place spread)", function()
	describe("Your odds (STA-R43, STA-R45, STA-R46)", function()
		it("reads a known reading as about 1 in N in large ink, its range, then its scope line", function()
			local ns = ready(darkshore())

			local view = entry(ns, DARKSHORE, SMALLFISH)

			assert.are.equal("about 1 in 30", shown(view.headline))
			-- Wilson's range for 5 of 150 at z = 1.96: 0.0143 to 0.0757, so 1 in 70 to 1 in 13.
			assert.are.equal("Likely between 1 in 13 and 1 in 70 (95%).", shown(view.range))
			assert.are.equal("From 150 of my Casts here, at or above 170 skill; 5 caught.", shown(view.sentence))
			assert.is_false(view.bar.shown)
			-- Darkshore's GetZoneCatches lists Smallfish only in Auberdine's list, unconfirmed.
			assert.are.equal("Pagle hasn't confirmed it bites here yet.", shown(view.notes))
		end)

		it("follows the sentence with each extra sentence that applies, and none when none does", function()
			local ns = ready(darkshore())

			-- Blackmouth: an unconfirmed entry and pool-associated.
			assert.are.equal(
				"Pagle hasn't confirmed it bites here yet. Open water and pools combined: there is no pool data.",
				shown(entry(ns, DARKSHORE, BLACKMOUTH).notes)
			)
			-- Mackerel's entry is confirmed, Darkshore's line too, and it has no window.
			assert.is_nil(shown(entry(ns, DARKSHORE, MACKEREL).notes))
		end)

		it("reads an unseen reading as not seen yet and its rule-of-three bound, with no range", function()
			local ns = ready(darkshore())

			local view = entry(ns, DARKSHORE, MACKEREL)

			assert.are.equal("not seen yet", shown(view.headline))
			assert.are.equal(
				"In 150 Casts here, at or above 170 skill: rarer than about 1 in 50, if it bites here at all.",
				shown(view.sentence)
			)
			assert.is_nil(shown(view.range))
			assert.is_false(view.bar.shown)
		end)

		it("reads a learning reading as Learning… in handwriting over an ink bar at n / 100", function()
			-- 40 Casts, Smallfish on the 10th.
			local ns = ready(castsInDarkshore(40, { [10] = SMALLFISH }))

			local view = entry(ns, DARKSHORE, SMALLFISH)

			assert.are.equal("Learning…", shown(view.headline))
			assert.are.same({ unpack(ns.BOOK_LOOK.hand) }, { unpack(view.headline.textColor, 1, 3) })
			assert.is_true(view.bar.shown)
			assert.are.equal(0.4, view.bar.value)
			assert.are.equal(
				"40 of the 100 Casts I need here, at or above 170 skill before Your odds show a number.",
				shown(view.sentence)
			)
			assert.is_nil(shown(view.range))
		end)

		it("names the place and the item's window in the kicker, over the icon and name", function()
			local ns, loaded = ready(darkshore())
			loaded.client.itemIcons[NIGHTFIN] = 133890

			local view = entry(ns, DARKSHORE, NIGHTFIN)

			assert.are.equal("YOUR ODDS · DARKSHORE, BY NIGHT", shown(view.kicker))
			assert.are.equal("Raw Nightfin Snapper", shown(view.name.title))
			assert.are.equal(133890, view.name.icon.icon.texture)
			assert.are.equal("YOUR ODDS · DARKSHORE", shown(entry(ns, DARKSHORE, SMALLFISH).kicker))
		end)
	end)

	describe("the Dry spell (STA-R50–R54)", function()
		it("heads it Dry spell, counted like the odds above", function()
			local ns = ready(darkshore())

			local heading = entry(ns, DARKSHORE, SMALLFISH).dryHeading

			assert.are.equal("DRY SPELL", heading.label.text)
			assert.are.equal("counted like the odds above", shown(heading.note))
		end)

		it("reads a luck reading's first sentence, its luck wording and the ruler at its P", function()
			local ns = ready(darkshore())

			local view = entry(ns, DARKSHORE, SMALLFISH)

			-- Last caught on Cast 5, 3 hours before NOW; P = (1 − 5/150)^145 ≈ 0.00733: 1 in 136, unlucky.
			assert.are.equal("145 Casts since my last one, 3h ago.", shown(view.dryFirst))
			assert.are.equal("Roughly 1 angler in 140 waits this long. Unlucky, not broken.", shown(view.dryAfter))
			assert.is_true(view.ruler.shown)
			-- log(0.00733) / log(10⁻⁶) ≈ 0.356 of the way to "1 in 1M".
			assert.are.near(0.3558, view.ruler.position, 0.0001)
			view = entry(ns, DARKSHORE, BLACKMOUTH)
			assert.are.equal("130 Casts since my last one, 3h ago.", shown(view.dryFirst))
			assert.are.equal("About 17 anglers in 100 wait this long. Nothing unusual.", shown(view.dryAfter))
			assert.is_true(view.ruler.shown)
			assert.are.near(0.1263, view.ruler.position, 0.0001)
		end)

		it("reads a Dry spell of 0 with no luck wording and no ruler (STA-R54)", function()
			local ns = ready(darkshore())

			local view = entry(ns, DARKSHORE, FIREFIN)

			assert.are.equal("Caught one on my last Cast here.", shown(view.dryFirst))
			assert.is_nil(shown(view.dryAfter))
			assert.is_false(view.ruler.shown)
		end)

		it("reads a learning Dry spell with its first sentence, the learning line and no ruler (STA-R54)", function()
			-- 40 Casts, Smallfish on the 10th, at T0 + 100: 3 hours and 100 s before NOW.
			local ns = ready(castsInDarkshore(40, { [10] = SMALLFISH }))

			local view = entry(ns, DARKSHORE, SMALLFISH)

			assert.are.equal("30 Casts since my last one, 3h ago.", shown(view.dryFirst))
			assert.are.equal("A luck reading comes once Your odds have a number.", shown(view.dryAfter))
			assert.is_false(view.ruler.shown)
		end)

		it("reads an item never caught in the scope as a bare count, with no ruler (STA-R50)", function()
			local ns = ready(darkshore())

			local view = entry(ns, DARKSHORE, MACKEREL)

			assert.are.equal("150 Casts here, none yet.", shown(view.dryFirst))
			assert.is_nil(shown(view.dryAfter))
			assert.is_false(view.ruler.shown)
		end)
	end)

	describe("the luck ruler (UI › Place spread)", function()
		-- The ruler's shown tick labels, left to right as anchored, and the same for its band labels.
		local function labels(list)
			local out = {}
			for i, text in ipairs(list) do
				out[i] = shown(text)
			end
			return out
		end

		it("has seven ticks on a log scale, two red washes, three band labels and the fixed line", function()
			local ns = ready(darkshore())

			local ruler = entry(ns, DARKSHORE, SMALLFISH).ruler

			assert.are.same(
				{ "all", "1 in 10", "1 in 100", "1 in 1k", "1 in 10k", "1 in 100k", "1 in 1M" },
				labels(ruler.tickLabels)
			)
			assert.are.equal(7, #ruler.ticks)
			local width = ruler:GetWidth()
			for i, tick in ipairs(ruler.ticks) do
				-- each tick a sixth further along: P = 10^-(i − 1)
				assert.are.near((i - 1) / 6 * width, xOf(tick), 0.001)
			end
			assert.are.same({ "normal", "unlucky", "very unlucky" }, labels(ruler.bandLabels))
			-- unlucky from 1 in 100 to 1 in 10k, very unlucky from there to the right end, both in faint red
			assert.are.equal(2, #ruler.washes)
			assert.are.near(width / 3, xOf(ruler.washes[1]), 0.001)
			assert.are.near(width / 3, ruler.washes[1].width, 0.001)
			assert.are.near(2 * width / 3, xOf(ruler.washes[2]), 0.001)
			assert.are.near(width / 3, ruler.washes[2].width, 0.001)
			for _, wash in ipairs(ruler.washes) do
				assert.are.same({ unpack(ns.BOOK_LOOK.red) }, { unpack(wash.color, 1, 3) })
				assert.is_true(wash.color[4] < 0.25)
			end
			assert.are.equal("Every Cast is its own roll; nothing is owed.", shown(ruler.owed))
			assert.are.equal("me", shown(ruler.me))
		end)

		it("puts its red me mark at P, clamped at both ends", function()
			local ns = ready(darkshore())
			local ruler = entry(ns, DARKSHORE, SMALLFISH).ruler
			local width = ruler:GetWidth()

			ruler:SetRuler(1)
			assert.are.equal(0, ruler.position)
			assert.are.equal(0, xOf(ruler.mark))
			ruler:SetRuler(1e-9)
			assert.are.equal(1, ruler.position)
			assert.are.equal(width, xOf(ruler.mark))
			ruler:SetRuler(1e-3)
			assert.are.near(width / 2, xOf(ruler.mark), 0.001)
			assert.are.same({ unpack(ns.BOOK_LOOK.red) }, { unpack(ruler.mark.color, 1, 3) })
		end)

		it("clamps a very unlucky wait past 1 in a million at the right end", function()
			-- 200 Casts, Smallfish on each of the first 100: 1 in 2, 100 since, P = 0.5^100.
			local catches = {}
			for i = 1, 100 do
				catches[i] = SMALLFISH
			end
			local ns = ready(castsInDarkshore(200, catches))

			local view = entry(ns, DARKSHORE, SMALLFISH)

			assert.are.equal(
				"Fewer than 1 angler in a million waits this long. Very unlucky, and every Cast is still its own roll.",
				shown(view.dryAfter)
			)
			assert.are.equal(1, view.ruler.position)
		end)
	end)

	describe("In my records", function()
		-- Read as the lines are drawn: each label and its value.
		local function records(view)
			local out = {}
			for i, line in ipairs(view.records) do
				out[i] = line.label.text .. " | " .. line.value.text
			end
			return out
		end

		it("reads the Catches in this count and anywhere, and the first and last dates", function()
			-- Darkshore's history, then two Smallfish in Elwynn two days before it: in no Darkshore scope.
			local log = darkshore()
			table.insert(log, 1, cast(T0 - 2 * DAYS, { SMALLFISH }, ELWYNN))
			table.insert(log, 2, cast(T0 - 2 * DAYS + 10, { SMALLFISH }, ELWYNN))
			local ns = ready(log)

			local view = entry(ns, DARKSHORE, SMALLFISH)

			assert.are.equal("IN MY RECORDS", view.recordsHeading.label.text)
			assert.are.same({
				"Caught in this count | 5",
				"Caught anywhere | 7",
				"First caught | 9 Oct 2026",
				"Last caught | 11 Oct 2026",
			}, records(view))
		end)

		it("reads 0 and — for an item I've never caught", function()
			local ns = ready(darkshore())

			local view = entry(ns, DARKSHORE, MACKEREL)

			assert.are.same({
				"Caught in this count | 0",
				"Caught anywhere | 0",
				"First caught | —",
				"Last caught | —",
			}, records(view))
		end)

		it("links Every water it bites in ☛ to the item's page", function()
			local ns = ready(darkshore())
			local view = entry(ns, DARKSHORE, SMALLFISH)

			assert.are.equal("Every water it bites in", view.link.label.text)
			assert.is_true(view.link.mark.shown)
			view.link:Click()

			assert.are.same({ page = "item", item = SMALLFISH }, ns.book.router:Place())
		end)
	end)

	describe("the watch toggle (STA-R60, STA-R61, STA-R72)", function()
		-- The row of `item` on `area`'s left page, or nil.
		local function rowOf(ns, item)
			for _, child in ipairs(ns.book.pages["place:left"].content.children) do
				if child.isBookRow and child.shown and child.name.text == stats.NAMES.items[item] then
					return child
				end
			end
			return nil
		end

		it("reads watch, and watching once pressed, starring the item's row; pressed again it stops", function()
			local ns, loaded = ready(darkshore())
			local toggle = entry(ns, DARKSHORE, BLACKMOUTH).toggle
			assert.are.equal("watch", toggle.label.text)
			assert.is_true(toggle.star.shown)
			assert.is_false(rowOf(ns, BLACKMOUTH).star.shown)

			toggle:Click()
			loaded.client.runTimers()

			assert.is_true(ns.IsWatched(BLACKMOUTH, DARKSHORE))
			assert.are.equal("watching", toggle.label.text)
			assert.are.same({ unpack(ns.BOOK_LOOK.red) }, { unpack(toggle.label.textColor, 1, 3) })
			assert.is_true(rowOf(ns, BLACKMOUTH).star.shown)
			-- watched from this place only (STA-R60)
			assert.is_false(ns.IsWatched(BLACKMOUTH, AUBERDINE))

			toggle:Click()
			loaded.client.runTimers()

			assert.is_false(ns.IsWatched(BLACKMOUTH, DARKSHORE))
			assert.are.equal("watch", toggle.label.text)
			assert.is_false(rowOf(ns, BLACKMOUTH).star.shown)
		end)

		it("reads watching for an item already watched from this place", function()
			local ns = ready(darkshore())
			ns.Watch(SMALLFISH, DARKSHORE)

			assert.are.equal("watching", entry(ns, DARKSHORE, SMALLFISH).toggle.label.text)
			assert.are.equal("watch", entry(ns, AUBERDINE, SMALLFISH).toggle.label.text)
		end)

		it("leaves a 4th unwatched: the toggle still reads watch (STA-R61)", function()
			local ns, loaded = ready(darkshore())
			ns.Watch(SMALLFISH, DARKSHORE)
			ns.Watch(FIREFIN, DARKSHORE)
			ns.Watch(MACKEREL, DARKSHORE)
			local toggle = entry(ns, DARKSHORE, BLACKMOUTH).toggle

			toggle:Click()
			loaded.client.runTimers()

			assert.is_false(ns.IsWatched(BLACKMOUTH, DARKSHORE))
			assert.are.equal("watch", toggle.label.text)
			assert.are.equal(1, #loaded.client.uiErrors)
		end)

		it("is never offered while the projection is updating, and is once it is done (STA-R72)", function()
			local fake = newFakePagle()
			fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
			local loaded = stats.load(fake)
			fake.login()
			local ns = loaded.ns
			ns.OpenBook({ page = "place", area = DARKSHORE, item = SMALLFISH })
			assert.is_true(ns.IsUpdating())
			assert.is_false(ns.book.pages["place:right"] ~= nil and ns.book.pages["place:right"].scroll.shown)

			fake.enterWorld()
			loaded.client.runTimers()

			local toggle = entry(ns, DARKSHORE, SMALLFISH).toggle
			assert.is_true(toggle:IsEnabled())
		end)

		it("does nothing if pressed while the projection is updating (STA-R72)", function()
			local ns, loaded = ready(darkshore())
			local toggle = entry(ns, DARKSHORE, SMALLFISH).toggle
			ns.IsUpdating = function()
				return true
			end

			toggle:Click()
			loaded.client.runTimers()

			assert.is_false(ns.IsWatched(SMALLFISH, DARKSHORE))
		end)

		it("opens a watch's entry and reads it when the item has left the place's rows (STA-R60)", function()
			-- A content update took Mackerel off Darkshore's list; I never caught it there, so it has no row.
			local catalogue = stats.catalogue()
			table.remove(catalogue.areas[DARKSHORE].catches, 1)
			local ns = ready(darkshore(), { catalogue = catalogue })
			ns.db.profile.watched = { { item = MACKEREL, area = DARKSHORE } }

			local view = entry(ns, DARKSHORE, MACKEREL)

			assert.is_nil(rowOf(ns, MACKEREL))
			assert.are.equal("not seen yet", view.headline.text)
			assert.are.equal("150 Casts here, none yet.", view.dryFirst.text)
			assert.are.equal("watching", view.toggle.label.text)
		end)
	end)
end)
