-- The Fish Journal's router (LED-R120, LED-R122, LED-R125) through ns.NewJournalRouter, with no Core and no frame:
-- which spread is open, its breadcrumbs and back link, and what both pages show, as data.

describe("the Fish Journal's router", function()
	local ns = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns
	local L = ns.L

	---@type LedgerJournalContext
	local context = { updating = false, now = 1791731700, formatNumber = breakUpLargeNumbers, text = ns.journalText }

	-- A spread three crumbs deep (Home ❧ Waters ❧ {zone} ❧ {fish}), its left page naming its args.
	---@type LedgerSpread
	local deep = {
		crumbs = function(args)
			return {
				{ label = "Waters", place = { id = "waters" } },
				{ label = "Zone " .. args.zone, place = { id = "zone", args = { zone = args.zone } } },
				{ label = "Fish " .. args.fish, place = { id = "deep", args = args } },
			}
		end,
		draw = function(args)
			return { left = { { kind = "title", text = "Fish " .. args.fish } }, right = {} }
		end,
	}

	-- The zone level above it: Home ❧ Waters ❧ {zone}.
	---@type LedgerSpread
	local zone = {
		crumbs = function(args)
			return {
				{ label = "Waters", place = { id = "waters" } },
				{ label = "Zone " .. args.zone, place = { id = "zone", args = args } },
			}
		end,
		draw = function()
			return { left = {}, right = {} }
		end,
	}

	-- A registry with Home's placeholder, the zone spread and the deep one.
	local function newRouter()
		local spreads = { home = ns.journalSpreads.home, zone = zone, deep = deep }
		return ns.NewJournalRouter(spreads)
	end

	-- The labels of the pages' crumbs.
	---@param pages LedgerJournalPages
	---@return string[]
	local function labels(pages)
		local out = {}
		for i, crumb in ipairs(pages.crumbs) do
			out[i] = crumb.label
		end
		return out
	end

	it("starts on Home, which has one crumb and no back link (LED-R120, LED-R125)", function()
		local pages = newRouter():Pages(context)

		assert.are.same({ L.JOURNAL_HOME }, labels(pages))
		assert.are.same({ id = "home" }, pages.crumbs[1].place)
		assert.is_nil(pages.back)
		assert.is_false(pages.updating)
	end)

	it("draws a placeholder Home with its title only until the Home spread lands (LED-R130)", function()
		local pages = newRouter():Pages(context)

		assert.are.same({ { kind = "title", text = "Where I've Fished" } }, pages.left)
		assert.are.same({}, pages.right)
	end)

	it("shows Home ❧ and a spread's own crumbs, each opening its level, and back one crumb up (LED-R125)", function()
		local router = newRouter()

		assert.is_true(router:Open("deep", { zone = 12, fish = 6303 }))
		local pages = router:Pages(context)

		assert.are.same({ "Home", "Waters", "Zone 12", "Fish 6303" }, labels(pages))
		assert.are.same({ id = "home" }, pages.crumbs[1].place)
		assert.are.same({ id = "zone", args = { zone = 12 } }, pages.crumbs[3].place)
		assert.are.same({ id = "zone", args = { zone = 12 } }, pages.back)
		assert.are.same({ { kind = "title", text = "Fish 6303" } }, pages.left)
	end)

	it("opens the crumb above with the back link's place, one level at a time (LED-R125)", function()
		local router = newRouter()
		router:Open("deep", { zone = 12, fish = 6303 })
		local up = router:Pages(context).back --[[@as LedgerJournalPlace]]

		assert.is_true(router:Open(up.id, up.args))
		local pages = router:Pages(context)

		assert.are.same({ "Home", "Waters", "Zone 12" }, labels(pages))
		assert.are.same({ id = "waters" }, pages.back)
	end)

	it("does nothing when asked to open a spread nobody registered (LED-R125)", function()
		local router = newRouter()
		router:Open("deep", { zone = 12, fish = 6303 })

		assert.is_false(router:Open("legends"))

		assert.are.same({ id = "deep", args = { zone = 12, fish = 6303 } }, router:Place())
	end)

	it("takes later registrations, so Home's spread replaces the placeholder", function()
		local spreads = { home = ns.journalSpreads.home }
		local router = ns.NewJournalRouter(spreads)

		spreads.home = {
			crumbs = function()
				return {}
			end,
			draw = function()
				return { left = { { kind = "kicker", text = "The Waters" } }, right = {} }
			end,
		}

		assert.are.same({ { kind = "kicker", text = "The Waters" } }, router:Pages(context).left)
	end)

	it("while the projection updates, shows only LED-R122's line on both pages, with no crumbs (LED-R122)", function()
		local router = newRouter()
		router:Open("deep", { zone = 12, fish = 6303 })

		local pages = router:Pages({ updating = true, now = context.now, formatNumber = breakUpLargeNumbers })

		local line = { { kind = "text", text = "The Ledger is being written up from your Catch log." } }
		assert.is_true(pages.updating)
		assert.are.same(line, pages.left)
		assert.are.same(line, pages.right)
		assert.is_nil(pages.crumbs)
		assert.is_nil(pages.back)
		-- and the spread it was on stays open for when the update finishes
		assert.are.same({ id = "deep", args = { zone = 12, fish = 6303 } }, router:Place())
	end)

	it("registers spreads by ID through ns.RegisterJournalSpread", function()
		local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns

		loaded.RegisterJournalSpread("deep", deep)

		assert.are.equal(deep, loaded.journalSpreads.deep)
	end)
end)
