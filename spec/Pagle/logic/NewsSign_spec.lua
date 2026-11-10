-- The news sign's pick (core/news-sign.md SIGN-R15, SIGN-R16): which news items are due, the one the sign shows and
-- how many more it counts. Pure logic (CORE-R7), so it runs over plain news items here, as VIEW-R42 hands them out.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

local DAY = 86400
-- 2026-10-11 15:15 UTC, the fake client's server time.
local NOW = SERVER_TIME
-- The floor: two days before now.
local FLOOR = NOW - 2 * DAY

local serial = 0
-- A news item of `kind`, `ago` seconds before now, new (VIEW-R42), with an id of its own.
local function item(kind, ago, fields)
	serial = serial + 1
	local it = {
		id = ("%016x"):format(serial),
		kind = kind,
		time = NOW - (ago or 60),
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

-- Every switch on, or those `off` names off (a kind, or "headlines").
local function switches(off)
	off = off or {}
	return {
		kind = function(kind)
			return not off[kind]
		end,
		headlines = function()
			return not off.headlines
		end,
	}
end

local function pick(items, off)
	return ns.PickNews(items, NOW, FLOOR, switches(off))
end

describe("Which news is due (SIGN-R15)", function()
	it("sign_r15: an item already seen at the session's first read isn't due", function()
		local seen = item("legend", 60, { new = false })

		assert.is_false(ns.NewsItemDue(seen, NOW, FLOOR, switches()))
	end)

	it("sign_r15_r18: an item timed before the floor isn't due, one at the floor is", function()
		assert.is_false(ns.NewsItemDue(item("legend", 2 * DAY + 1), NOW, FLOOR, switches()))
		assert.is_true(ns.NewsItemDue(item("legend", 2 * DAY), NOW, FLOOR, switches()))
	end)

	it("sign_r15: an item older than the news age, 30 days, isn't due whatever the floor", function()
		local floor = NOW - 60 * DAY

		assert.is_true(ns.NewsItemDue(item("legend", 30 * DAY), NOW, floor, switches()))
		assert.is_false(ns.NewsItemDue(item("legend", 30 * DAY + 1), NOW, floor, switches()))
	end)

	it("sign_r15: a followed item whose kind is switched off isn't due (SET-R37)", function()
		assert.is_false(ns.NewsItemDue(item("prestige"), NOW, FLOOR, switches({ prestige = true })))
		assert.is_true(ns.NewsItemDue(item("legend"), NOW, FLOOR, switches({ prestige = true })))
	end)

	it("sign_r15: a region headline is due only with Region headlines on (SET-R37)", function()
		assert.is_false(ns.NewsItemDue(item("region"), NOW, FLOOR, switches({ headlines = true })))
		assert.is_true(ns.NewsItemDue(item("region"), NOW, FLOOR, switches()))
	end)

	it("sign_r15: a region headline from an earlier UTC month isn't due, its 'this month' no longer true", function()
		-- 2026-10-11 15:15 UTC: the month began 10 days, 15 hours and 15 minutes ago
		local sinceMonth = 10 * DAY + 15 * 3600 + 15 * 60
		local floor = NOW - 20 * DAY

		assert.is_true(ns.NewsItemDue(item("region", sinceMonth), NOW, floor, switches()))
		assert.is_false(ns.NewsItemDue(item("region", sinceMonth + 1), NOW, floor, switches()))
	end)

	it("sign_r15: a kind the sign doesn't know is never due", function()
		assert.is_false(ns.NewsItemDue(item("weather"), NOW, FLOOR, switches()))
	end)
end)

describe("The pick (SIGN-R15)", function()
	it("sign_r15: takes the first due followed item in SIGN-R10's rank", function()
		local zone, legend, monster = item("zone", 60), item("legend", 3600), item("monster", 30)

		local shown = pick({ zone, monster, legend })

		assert.are.equal(legend, shown)
	end)

	it("sign_r15: ranks first, legend, prestige, ledger, colour, hunt, zone, monster", function()
		local order = { "first", "legend", "prestige", "ledger", "colour", "hunt", "zone", "monster" }
		assert.are.same(order, ns.NEWS_FOLLOWED_KINDS)
		for i = 1, #order - 1 do
			local higher, lower = item(order[i], 3600), item(order[i + 1], 60)
			assert.are.equal(higher, pick({ lower, higher }), order[i])
		end
	end)

	it("sign_r15: between two of the same kind takes the newer", function()
		local older, newer = item("prestige", 3600), item("prestige", 60)

		assert.are.equal(newer, pick({ older, newer }))
		assert.are.equal(newer, pick({ newer, older }))
	end)

	it("sign_r15: between two of the same kind and time keeps the block's order", function()
		local a, b = item("hunt", 600), item("hunt", 600)

		assert.are.equal(a, pick({ a, b }))
		assert.are.equal(b, pick({ b, a }))
	end)

	it("sign_r15: passes over a higher kind that isn't due for a lower one that is", function()
		local legend, zone = item("legend", 60, { new = false }), item("zone", 60)

		assert.are.equal(zone, pick({ legend, zone }))
		assert.are.equal(zone, pick({ item("legend"), zone }, { legend = true }))
	end)

	it("sign_r15: shows a region headline only when no followed item is due", function()
		local headline, hunt = item("region", 30), item("hunt", 3600)

		assert.are.equal(hunt, pick({ headline, hunt }))
		assert.are.equal(headline, pick({ headline, item("hunt", 60, { new = false }) }))
	end)

	it("sign_r15: of the region headlines takes the newest, then the block's first", function()
		local older, newer, twin = item("region", 3600), item("region", 60), item("region", 60)

		assert.are.equal(newer, pick({ older, newer, twin }))
	end)

	it("sign_r15: picks nothing when nothing is due", function()
		local shown, more = pick({ item("legend", 60, { new = false }), item("region", 60) }, { headlines = true })

		assert.is_nil(shown)
		assert.are.equal(0, more)
		assert.is_nil(pick({}))
	end)
end)

describe("The more line's count (SIGN-R16)", function()
	it("sign_r16: counts the due followed items other than the one shown", function()
		local _, more = pick({ item("legend"), item("zone"), item("monster"), item("legend") })

		assert.are.equal(3, more)
	end)

	it("sign_r16: never counts region headlines", function()
		local _, more = pick({ item("legend"), item("region"), item("region") })

		assert.are.equal(0, more)
	end)

	it("sign_r16: counts none beside a region headline", function()
		local shown, more = pick({ item("region"), item("region") })

		assert.are.equal("region", shown.kind)
		assert.are.equal(0, more)
	end)

	it("sign_r16: never counts a switched-off kind, a seen item or one before the floor", function()
		local _, more = pick({
			item("first"),
			item("prestige"),
			item("hunt", 60, { new = false }),
			item("zone", 3 * DAY),
			item("monster"),
		}, { prestige = true })

		assert.are.equal(1, more)
	end)
end)
