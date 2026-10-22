-- The Stats book's page router (STA-R70, STA-R74): which page shows, with what chosen on it, which renderer draws each
-- side, the breadcrumb trail and where each ribbon goes. Pure logic, on the fixture catalogue's places: Darkshore
-- (148) with its subzone Auberdine (442), and Elwynn Forest (12).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local DARKSHORE, AUBERDINE, ELWYNN = 148, 442, 12
local NIGHTFIN = 13759

-- A new router, and Stats' namespace.
local function newRouter()
	local loaded = stats.load()
	return loaded.ns.NewBookRouter(), loaded.ns
end

-- The fixture's zones: Auberdine is in Darkshore; every other place here is a zone.
local function zoneOf(area)
	return area == AUBERDINE and DARKSHORE or area
end

-- The trail's crumbs as "kind id -> page area item" strings, "-" for nothing and no arrow for a crumb that does
-- nothing.
local function trailOf(router)
	local out = {}
	for i, crumb in ipairs(router:Trail(zoneOf)) do
		local line = crumb.kind .. " " .. tostring(crumb.id or "-")
		local target = crumb.target
		if target then
			line = line
				.. (" -> %s %s %s"):format(target.page, tostring(target.area or "-"), tostring(target.item or "-"))
		end
		out[i] = line
	end
	return out
end

describe("the Stats book's router (STA-R70, STA-R74)", function()
	it("starts on the home spread, so the first opening after a login or /reload shows it (STA-R70)", function()
		local router = newRouter()

		assert.are.same({ page = "home" }, router:Place())
	end)

	it("keeps the page it was left on, with its chosen item, Session and Sessions page number (STA-R70)", function()
		local router = newRouter()

		router:Open({ page = "place", area = DARKSHORE, item = NIGHTFIN })
		assert.are.same({ page = "place", area = DARKSHORE, item = NIGHTFIN }, router:Place())
		router:Open({ page = "sessions", session = "S-3", ledgerPage = 2 })

		assert.are.same({ page = "sessions", session = "S-3", ledgerPage = 2 }, router:Place())
	end)

	it("keeps only what each page shows, and hands out copies", function()
		local router = newRouter()

		router:Open({ page = "lifetime", area = DARKSHORE, item = NIGHTFIN, session = "S-1", ledgerPage = 3 })
		assert.are.same({ page = "lifetime" }, router:Place())
		router:Open({ page = "item", item = NIGHTFIN, area = AUBERDINE, ledgerPage = 3 })
		local place = router:Place()
		place.item = 1

		assert.are.same({ page = "item", item = NIGHTFIN, area = AUBERDINE }, router:Place())
	end)

	it("refuses a page it doesn't have, a place page with no place and an item page with no item", function()
		local router = newRouter()
		router:Open({ page = "lifetime" })

		assert.error_matches(function()
			router:Open({ page = "journal" })
		end, "the Stats book has no page journal", nil, true)
		assert.error_matches(function()
			router:Open({ page = "place" })
		end, "a Stats book place page needs its area", nil, true)
		assert.error_matches(function()
			router:Open({ page = "item", area = DARKSHORE })
		end, "a Stats book item page needs its item", nil, true)
		assert.are.same({ page = "lifetime" }, router:Place())
	end)

	it("gives each page and side the renderer registered for it, the last one registered, or none", function()
		local router, ns = newRouter()
		local first, second, other = function() end, function() end, function() end

		router:Register("place", "left", first)
		router:Register("place", "left", second)
		router:Register("place", "right", other)

		assert.are.equal(second, router:Renderer("place", "left"))
		assert.are.equal(other, router:Renderer("place", "right"))
		assert.is_nil(router:Renderer("home", "left"))
		assert.are.same({ "home", "place", "item", "session", "lifetime", "sessions" }, ns.BOOK_PAGES)
	end)

	it("refuses a renderer for a page or side it doesn't have", function()
		local router = newRouter()

		assert.error_matches(function()
			router:Register("hunts", "left", function() end)
		end, "the Stats book has no page hunts", nil, true)
		assert.error_matches(function()
			router:Register("home", "middle", function() end)
		end, "a Stats book page's side is left or right, not middle", nil, true)
		assert.error_matches(function()
			router:Register("home", "left", "not a function")
		end, "a Stats book page's renderer is a function", nil, true)
	end)
end)

describe("the Stats book's breadcrumbs (STA-R74)", function()
	it('reads "Stats" on the home spread', function()
		local router = newRouter()

		assert.are.same({ "stats - -> home - -" }, trailOf(router))
	end)

	it('reads "Stats ❧ {zone}" on a zone page, each crumb opening what it names', function()
		local router = newRouter()
		router:Open({ page = "place", area = DARKSHORE })

		assert.are.same({ "stats - -> home - -", "zone 148 -> place 148 -" }, trailOf(router))
	end)

	it(
		'adds "❧ {subzone}" on a subzone page, then "❧ {item}", which does nothing, while an entry is chosen',
		function()
			local router = newRouter()
			router:Open({ page = "place", area = AUBERDINE, item = NIGHTFIN })

			assert.are.same({
				"stats - -> home - -",
				"zone 148 -> place 148 -",
				"subzone 442 -> place 442 -",
				"item 13759",
			}, trailOf(router))
		end
	)

	it('reads "Stats ❧ {item}" on an item page', function()
		local router = newRouter()
		router:Open({ page = "item", item = NIGHTFIN })

		assert.are.same({ "stats - -> home - -", "item 13759 -> item - 13759" }, trailOf(router))
	end)

	it('reads "Stats ❧ {its kicker}" on a ribbon page, the page keeping its Session and page number', function()
		local router = newRouter()

		router:Open({ page = "session" })
		assert.are.same({ "stats - -> home - -", "ribbon session -> session - -" }, trailOf(router))
		router:Open({ page = "lifetime" })
		assert.are.same({ "stats - -> home - -", "ribbon lifetime -> lifetime - -" }, trailOf(router))
		router:Open({ page = "sessions", session = "S-2", ledgerPage = 2 })
		local crumbs = router:Trail(zoneOf)

		assert.are.equal("ribbon", crumbs[2].kind)
		assert.are.same({ page = "sessions", session = "S-2", ledgerPage = 2 }, crumbs[2].target)
	end)
end)

describe("the Stats book's ribbons (STA-R74)", function()
	it("opens Where I am on the current subzone's place page, the zone's with subzone 0, home with zone 0", function()
		local _, ns = newRouter()

		assert.are.same({ page = "place", area = AUBERDINE }, ns.WhereIAm({ zone = DARKSHORE, subzone = AUBERDINE }))
		assert.are.same({ page = "place", area = ELWYNN }, ns.WhereIAm({ zone = ELWYNN, subzone = 0 }))
		assert.are.same({ page = "home" }, ns.WhereIAm({ zone = 0, subzone = AUBERDINE }))
	end)

	it("hangs Where I am, This Session, Lifetime and Sessions, top to bottom, Where I am green", function()
		local _, ns = newRouter()

		local ribbons = {}
		for i, ribbon in ipairs(ns.BOOK_RIBBONS) do
			ribbons[i] = ribbon.id .. " " .. tostring(ribbon.page) .. (ribbon.green and " green" or "")
		end
		assert.are.same({ "here nil green", "session session", "lifetime lifetime", "sessions sessions" }, ribbons)
	end)

	it(
		"marks the ribbon of the page shown: Where I am on the current place's page, with or without an entry",
		function()
			local _, ns = newRouter()

			assert.are.equal("here", ns.ChosenRibbon({ page = "place", area = AUBERDINE, item = NIGHTFIN }, AUBERDINE))
			assert.is_nil(ns.ChosenRibbon({ page = "place", area = DARKSHORE }, AUBERDINE))
			assert.is_nil(ns.ChosenRibbon({ page = "home" }, nil))
			assert.are.equal("session", ns.ChosenRibbon({ page = "session" }, AUBERDINE))
			assert.are.equal("lifetime", ns.ChosenRibbon({ page = "lifetime" }, nil))
			assert.are.equal("sessions", ns.ChosenRibbon({ page = "sessions", ledgerPage = 2 }, nil))
			assert.is_nil(ns.ChosenRibbon({ page = "item", item = NIGHTFIN }, AUBERDINE))
		end
	)
end)

describe("the spread the book's First look shows on (ONB-R57, board 14)", function()
	local SMALLFISH, BLACKMOUTH, FIREFIN = 6291, 6358, 6359

	-- A row's reading: `n` Casts, `k` catches, the last at Cast `at` (none when nil), Your odds known or learning.
	local function reading(item, n, k, at, state)
		return { item = item, n = n, k = k, hit = at and { at = at } or nil, state = state or "known" }
	end

	it("is the place's page with the first row whose Dry spell has a luck reading chosen, its ruler drawn", function()
		local _, ns = newRouter()
		local groups = {
			{ readings = { reading(FIREFIN, 150, 1, 150), reading(NIGHTFIN, 0, 0, nil, "learning") } },
			{ readings = { reading(BLACKMOUTH, 150, 2, 20), reading(SMALLFISH, 150, 5, 5) } },
		}

		assert.are.same({ page = "place", area = AUBERDINE, item = BLACKMOUTH }, ns.BookLookTarget(AUBERDINE, groups))
	end)

	it("is the first row's entry when no row has a luck reading", function()
		local _, ns = newRouter()
		local groups = {
			{ readings = {} },
			{ readings = { reading(NIGHTFIN, 0, 0, nil, "learning"), reading(FIREFIN, 150, 1, 150) } },
		}

		assert.are.same({ page = "place", area = DARKSHORE, item = NIGHTFIN }, ns.BookLookTarget(DARKSHORE, groups))
	end)

	it("is none with no place to show (zone 0) or a place with no rows", function()
		local _, ns = newRouter()

		assert.is_nil(ns.BookLookTarget(nil, { { readings = { reading(FIREFIN, 150, 1, 150) } } }))
		assert.is_nil(ns.BookLookTarget(ELWYNN, {}))
		assert.is_nil(ns.BookLookTarget(ELWYNN, { { readings = {} } }))
	end)
end)
