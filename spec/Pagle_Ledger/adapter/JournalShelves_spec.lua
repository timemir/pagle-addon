-- The Fish Journal's Collection on FakePagle (LED-R166–R175, LED-R132): its spread and a shelf's spread, drawn from
-- Core's goods (SHOP-R36) with the Ledger's titles, the right page by each look's state, using a look here, what is new
-- and what was added lately, what is put away, the ways in and the search. ledger.md › The Collection.

local DAY = 24 * 3600
local PAGE = "core.toaststyle.page" -- Torn Page, the default
local RIPPLE = "core.toaststyle.ripple" -- for sale, tier 1, 250 Coins
local STORM = "core.toaststyle.storm" -- for sale, tier 4, 3,000 Coins
local FOIL = "core.toaststyle.foil" -- the Curio crate's alone
local TALE = "ledger.toaststyle.legend" -- earned: a Legend caught
local VELLUM = "ledger.toaststyle.prestige" -- earned: Prestige V
local CRIER = "ledger.toaststyle.crier" -- earned: 100 fish as a Human
local FIELD = "core.binding.field" -- Field Leather, the default
local LOG = "0123456789abcdef"

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local bounds = dofile("spec/support/bounds.lua")

-- The Collection's spread (`id` "collection") or a shelf's (`id` "shelf", `args`) open on a Ledger over FakePagle, with
-- `options` for openJournal: its `before` and `modules` run as openJournal runs them.
---@param id string
---@param args table?
---@param options table?
---@return FakePagle fake
---@return LoadedAddon loaded
local function open(id, args, options)
	options = options or {}
	options.id, options.args, options.logId = id, args, options.logId or LOG
	options.globals = options.globals or { BreakUpLargeNumbers = breakUpLargeNumbers }
	-- The first noting waits a frame for the projections to be idle (LED-R171): `before` finds the Collection noted, as a
	-- Journal opened some time after login would, so what it makes owned is new.
	local before = options.before
	options.before = function(loaded, fake)
		loaded.client.runTimers()
		if before then
			before(loaded, fake)
		end
	end
	return openJournal(options)
end

-- A shelf's spread on `shelf`, a look chosen when given.
---@param shelf string
---@param look string?
---@param options table?
local function shelfOf(shelf, look, options)
	return open("shelf", { shelf = shelf, look = look }, options)
end

-- What the drawn widgets of `kind` read, on the left or right page.
local function drawn(loaded, side, kind)
	return loaded.ns.journal.shown[side].drawn[kind] or {}
end

-- The cards of the shelf drawn, in order, as { name, tag, state, "new!", view = card }, each text false while hidden.
local function cards(loaded)
	local list = {}
	for _, widget in ipairs(drawn(loaded, "left", "cards")) do
		for i = 1, #widget.views do
			local view = widget.views[i]
			if view:IsShown() then
				list[#list + 1] = {
					view.name:GetText(),
					view.tag:IsShown() and view.tag:GetText() or false,
					view.state:IsShown() and view.state:GetText() or false,
					view.newMark:IsShown() and view.newMark:GetText() or false,
					view = view,
				}
			end
		end
	end
	return list
end

-- The card named `name` on the shelf drawn.
local function cardNamed(loaded, name)
	for _, card in ipairs(cards(loaded)) do
		if card[1] == name then
			return card
		end
	end
	error("no card reads " .. name)
end

-- The right page's blocks, as their texts or "[kind]".
local function rightTexts(loaded)
	local list = {}
	for i, block in ipairs(loaded.ns.journal.pages.right) do
		local bracketed = block.kind == "stage" or block.kind == "useRow"
		list[i] = not bracketed and block.text or ("[" .. block.kind .. "]")
	end
	return list
end

-- The right page's first block of `kind`.
local function rightBlock(loaded, kind)
	return blockOfKind(loaded.ns.journal.pages.right, kind)
end

-- The drawn "useRow" on the right page: what it reads.
local function useRow(loaded)
	local widget = drawn(loaded, "right", "useRow")[1]
	return {
		seal = widget.seal:IsShown() and widget.seal.label:GetText() or false,
		button = widget.face:IsShown() and widget.face.label:GetText() or false,
		text = widget.words:IsShown() and widget.words:GetText() or false,
		sub = widget.sub:IsShown() and widget.sub:GetText() or false,
	},
		widget
end

-- Runs the frame a redraw waits for.
local function frame(loaded)
	loaded.client.runTimers()
end

-- Stands Core's balance at `coins` (SHOP-R12).
local function balance(coins)
	return function(fake)
		fake.Pagle.GetBalance = function()
			return { balance = coins, held = false, earned = {} }
		end
	end
end

-- Hands Core the goods bought, each with when it was bought, and the ones a crate gave, each with when (SHOP-R36).
local function owning(bought, crated)
	return function(_, fake)
		local purchased, at, from = {}, {}, {}
		for id, time in pairs(bought or {}) do
			purchased[id], at[id] = true, time
		end
		for id, time in pairs(crated or {}) do
			purchased[id], at[id], from[id] = true, time, true
		end
		fake.setPurchased(purchased, at, from)
	end
end

-- Makes good `id` earned: the Ledger's celebrated set has it, which its rule reads (LED-R116, LED-R117).
local function earned(...)
	local ids = { ... }
	return function(loaded)
		local goods = {}
		for _, id in ipairs(ids) do
			goods[id] = true
		end
		loaded.ns.db.global.celebrated.goods = goods
		loaded.ns.Module:RefreshGoods()
	end
end

-- Runs `...` in order, each as `before` or `modules` would run it.
local function chain(...)
	local steps = { ... }
	return function(a, b)
		for _, step in ipairs(steps) do
			step(a, b)
		end
	end
end

-- What the Journal's date reads for `time`: the same words a Fish Journal page prints (LED-R126).
local function date(loaded, time)
	return loaded.ns.journalText:DateAt(time)
end

describe("the Collection's spread (LED-R168)", function()
	it("is the Collection, Home » The Collection, with the way back to Home (LED-R125, LED-R166)", function()
		local _, loaded = open("collection")
		local journal = loaded.ns.journal

		local labels = {}
		for i, crumb in ipairs(journal.pages.crumbs) do
			labels[i] = crumb.label
		end

		assert.are.same({ "Home", "The Collection" }, labels)
		assert.are.same({ id = "home" }, journal.pages.back)
		assert.are.same({ left = "collection", right = "collection" }, journal.pages.subjects)
	end)

	it(
		'reads "In this Ledger", "The Collection", its line and a wax seal of looks and titles together (LED-R168)',
		function()
			local _, loaded = open("collection")
			local journal = loaded.ns.journal
			local model = loaded.ns.CollectionModel(journal.context)
			local left = journal.pages.left

			assert.are.same({ "In this Ledger", "The Collection" }, { left[1].text, left[2].text })
			assert.are.same(
				{ kind = "seal", text = ("%d\nof %d"):format(model.owned, model.total), inked = true },
				left[3]
			)
			assert.are.equal(
				"Every look Pagle has: the ones you wear, the ones you keep, and how to earn the rest.",
				left[4].text
			)
			assert.are.same({
				"In this Ledger",
				"The Collection",
				"Every look Pagle has: the ones you wear, the ones you keep, and how to earn the rest.",
			}, {
				drawn(loaded, "left", "kicker")[1].label:GetText(),
				drawn(loaded, "left", "title")[1].label:GetText(),
				drawn(loaded, "left", "text")[1].label:GetText(),
			})
			local seal = drawn(loaded, "left", "seal")[1].seal
			assert.are.same({ true, left[3].text }, { seal.wax:IsShown(), seal.label:GetText() })
		end
	)

	it(
		"has a row per shelf in GetSlots' order, Titles last, each wearing what is in use (LED-R167, LED-R168)",
		function()
			local _, loaded = open("collection")

			local rows = {}
			for _, block in ipairs(loaded.ns.journal.pages.left) do
				if block.kind == "shelfRow" then
					rows[#rows + 1] = { block.text, block.sub }
				end
			end

			assert.are.same({
				{ "Toast styles", "Wearing Torn Page" },
				{ "Sound sets", "Wearing Driftwood" },
				{ "Bookplate crests", "Wearing Plain" },
				{ "Bindings", "Wearing Field Leather" },
				{ "Titles", "Signed “Minnow”" },
			}, rows)
		end
	)

	it(
		'draws each row\'s name, its count over a small ink bar and "{n} new", and opens its shelf on a click (LED-R168)',
		function()
			local _, loaded = open("collection", nil, { before = owning({ [RIPPLE] = SERVER_TIME - 2 * DAY }) })
			local journal = loaded.ns.journal
			local model = loaded.ns.CollectionModel(journal.context)
			local toasts = model.byKey["core.toaststyle"]

			local row = drawn(loaded, "left", "shelfRow")[1]

			assert.are.same(
				{ "Toast styles", ("%d of %d"):format(toasts.owned, #toasts.looks), "1 new", "Wearing Torn Page" },
				{ row.name:GetText(), row.count:GetText(), row.new:GetText(), row.sub:GetText() }
			)
			assert.are.equal(toasts.owned / #toasts.looks, row.bar.pct)
			row:Click()
			assert.are.same({ id = "shelf", args = { shelf = "core.toaststyle" } }, journal:Place())
			assert.are.same({ "Home", "The Collection", "Toast styles" }, {
				journal.pages.crumbs[1].label,
				journal.pages.crumbs[2].label,
				journal.pages.crumbs[3].label,
			})
		end
	)

	it(
		"draws the look in use small by Core's preview at card size, and the Ledger's own art for the rest (LED-R168)",
		function()
			local fake, loaded = open("collection")

			local kinds = {}
			for _, block in ipairs(loaded.ns.journal.pages.left) do
				if block.kind == "shelfRow" then
					kinds[#kinds + 1] = block.lookArt.kind
				end
			end

			assert.are.same({ "preview", "speaker", "shield", "book", "quill" }, kinds)
			local first = fake.goodPreviews[1]
			assert.are.same({ PAGE, "card" }, { first.goodID, first.size })
		end
	)

	it(
		'keeps "Within reach" to looks to earn whose count is above 0 and below 1, highest share first, each opening its shelf with it chosen (LED-R168)',
		function()
			local _, loaded = open("collection", nil, {
				modules = function(fake)
					local progress = fake.Pagle.GetEarnedProgress
					fake.Pagle.GetEarnedProgress = function(id)
						if id == CRIER then
							return { tag = "62 of 100 fish", note = "Catch 100 fish as a Human", have = 62, need = 100 }
						elseif id == VELLUM then
							return { tag = "Prestige V", note = "Prestige V", have = 4, need = 5 }
						elseif id == TALE then
							return { tag = "Land a Legend", note = "Land a Legend" }
						end
						return progress(id)
					end
				end,
			})
			local journal = loaded.ns.journal

			local right = journal.pages.right

			assert.are.same({ kind = "kicker", text = "Within reach" }, right[1])
			assert.are.same(
				{ "Oxblood Vellum", "Toast style", 0.8, "4 of 5" },
				{ right[2].text, right[2].value, right[2].fill, right[2].note }
			)
			assert.are.same(
				{ "Town Crier's Proclamation", 0.62, "62 of 100 fish" },
				{ right[3].text, right[3].fill, right[3].note }
			)
			assert.are.same({ id = "shelf", args = { shelf = "core.toaststyle", look = VELLUM } }, right[2].place)
			assert.are.equal("reachRow", right[3].kind)
			assert.is_true(right[4].kind ~= "reachRow") -- the look with no count is never here
			drawn(loaded, "right", "reachRow")[1]:Click()
			assert.are.same({ shelf = "core.toaststyle", look = VELLUM }, journal:Place().args)
		end
	)

	it("draws a row within reach's name, shelf in italic, ink bar and its count in the hand (LED-R168)", function()
		local _, loaded = open("collection", nil, {
			modules = function(fake)
				local progress = fake.Pagle.GetEarnedProgress
				fake.Pagle.GetEarnedProgress = function(id)
					if id == CRIER then
						return { tag = "62 of 100 fish", have = 62, need = 100 }
					end
					return progress(id)
				end
			end,
		})

		local row = drawn(loaded, "right", "reachRow")[1]

		assert.are.same(
			{ "Town Crier's Proclamation", "Toast style", "62 of 100 fish", 0.62 },
			{ row.name:GetText(), row.shelf:GetText(), row.count:GetText(), row.bar.pct }
		)
		assert.is_true(row.bar:IsShown())
	end)

	it(
		'lists "Lately added", the owned most recently newest first, as Bought, From a Curio crate or Earned with its date and "new!" (LED-R168, LED-R171)',
		function()
			local _, loaded = open("collection", nil, {
				before = owning({ [RIPPLE] = SERVER_TIME - 3 * DAY }, { [FOIL] = SERVER_TIME - 2 * DAY }),
			})

			local right = loaded.ns.journal.pages.right

			assert.are.same({ kind = "kicker", text = "Lately added", value = "newest first" }, right[1])
			assert.are.same({
				{
					"Prize Foil",
					"From a Curio crate · " .. date(loaded, SERVER_TIME - 2 * DAY),
					"Toast style",
					"new!",
				},
				{ "Ripple", "Bought · " .. date(loaded, SERVER_TIME - 3 * DAY), "Toast style", "new!" },
			}, {
				{ right[2].text, right[2].sub, right[2].value, right[2].note },
				{ right[3].text, right[3].sub, right[3].value, right[3].note },
			})
			assert.are.same({ id = "shelf", args = { shelf = "core.toaststyle", look = FOIL } }, right[2].place)
			local row = drawn(loaded, "right", "latelyRow")[1]
			assert.are.same(
				{ "Prize Foil", "Toast style", "new!" },
				{ row.name:GetText(), row.shelf:GetText(), row.new:GetText() }
			)
			assert.are.equal("From a Curio crate · " .. date(loaded, SERVER_TIME - 2 * DAY), row.sub:GetText())
		end
	)

	it('dates a look earned by when the Ledger first saw it, "Earned · {date}" (LED-R171)', function()
		local _, loaded = open("collection", nil, { before = earned(TALE) })
		local seen = loaded.ns.db.global.collection.seen[TALE]

		local row = loaded.ns.journal.pages.right[2]

		assert.are.same(
			{ "The Tall Tale", "Earned · " .. date(loaded, seen), "new!" },
			{ row.text, row.sub, row.note }
		)
	end)

	it(
		'never lists the default, nor a look nobody added, and shows no "Lately added" with nothing to list (LED-R168)',
		function()
			local _, loaded = open("collection")

			for _, block in ipairs(loaded.ns.journal.pages.right) do
				assert.is_true(block.kind ~= "latelyRow")
				assert.is_true(block.text ~= "Lately added")
			end
		end
	)

	it(
		'ends with the looks for sale you don\'t have and the way to the Curio Shop, "Open the Curio Shop" (LED-R168)',
		function()
			local fake, loaded = open("collection")
			local journal = loaded.ns.journal
			local model = loaded.ns.CollectionModel(journal.context)

			local block = journal.pages.right[#journal.pages.right]
			drawn(loaded, "right", "shopFoot")[1]:Click()

			assert.is_true(block.foot)
			assert.are.same(
				{ "shopFoot", ("%d looks for sale you don't have yet."):format(model.forSale), "Open the Curio Shop" },
				{ block.kind, block.text, block.value }
			)
			assert.are.same({ { goodID = nil, selected = nil } }, fake.shopsOpened)
		end
	)

	it("counts the looks for sale it doesn't have: not owned, put away or not, and sold now (LED-R168)", function()
		local _, bought = open("collection", nil, { before = owning({ [RIPPLE] = SERVER_TIME - DAY }) })
		local _, none = open("collection")

		local function forSale(loaded)
			return loaded.ns.CollectionModel(loaded.ns.journal.context).forSale
		end

		assert.are.equal(forSale(none) - 1, forSale(bought))
	end)

	it('says "1 look" for one', function()
		local _, loaded = open("collection")
		local L = loaded.ns.L

		assert.are.equal(
			"1 look for sale you don't have yet.",
			loaded.ns.CountText(1, L.COLLECTION_FOR_SALE_ONE, L.COLLECTION_FOR_SALE_OTHER)
		)
		assert.are.equal(
			"2 looks for sale you don't have yet.",
			loaded.ns.CountText(2, L.COLLECTION_FOR_SALE_ONE, L.COLLECTION_FOR_SALE_OTHER)
		)
	end)

	it("keeps its words on the parchment at the default size (LED-R168, CORE-R65)", function()
		local _, loaded = open("collection", nil, {
			modules = function(fake)
				local progress = fake.Pagle.GetEarnedProgress
				fake.Pagle.GetEarnedProgress = function(id)
					if id == CRIER then
						return { tag = "62 of 100 fish", have = 62, need = 100 }
					end
					return progress(id)
				end
			end,
			before = owning({ [RIPPLE] = SERVER_TIME - DAY }, { [FOIL] = SERVER_TIME - DAY }),
		})
		local shown = loaded.ns.journal.shown

		assert.are.same({}, bounds.overflows(shown.left))
		assert.are.same({}, bounds.overflows(shown.right))
		assert.is_true(bounds.measured > 0)
	end)

	it("lists a look any Module registers as soon as it registers, with nothing added here (LED-R166)", function()
		local _, plain = open("collection")
		local _, loaded = open("collection", nil, {
			modules = function(fake)
				local stats = fake.Pagle.RegisterModule({ name = "Stats", title = "Stats", order = 30 })
				stats:RegisterSlot({ id = "stats.trackerframe", label = "Stats tracker frame", category = "Trackers" })
				stats:RegisterGood({
					id = "stats.trackerframe.none",
					slot = "stats.trackerframe",
					name = "No Frame",
					default = true,
				})
				stats:RegisterGood({
					id = "stats.trackerframe.map",
					slot = "stats.trackerframe",
					name = "Map Scrap",
					tier = 1,
				})
			end,
		})

		local function total(l)
			return l.ns.CollectionModel(l.ns.journal.context).total
		end
		local rows = {}
		for _, block in ipairs(loaded.ns.journal.pages.left) do
			if block.kind == "shelfRow" then
				rows[#rows + 1] = { block.text, block.sub }
			end
		end

		assert.are.equal(total(plain) + 2, total(loaded))
		assert.are.same({ "Tracker frames", "No Frame" }, rows[5])
		assert.are.same("Titles", rows[6][1])
	end)

	it(
		"is the Ledger's view, offered to Core as def.collection, so it is gone with the Ledger off and Look and Feel changes a look (LED-R166, CORE-R45, SET-R50)",
		function()
			local off = newFakePagle()
			local on = open("collection")

			assert.is_nil(off.ns.CollectionOffered())
			assert.is_function(on.ns.CollectionOffered())
		end
	)
end)

describe("a shelf's spread (LED-R169)", function()
	it("opens Home » The Collection » {shelf}, « back going up to the Collection (LED-R125, LED-R169)", function()
		local _, loaded = shelfOf("core.toaststyle")
		local journal = loaded.ns.journal

		local labels = {}
		for i, crumb in ipairs(journal.pages.crumbs) do
			labels[i] = crumb.label
		end

		assert.are.same({ "Home", "The Collection", "Toast styles" }, labels)
		assert.are.same({ id = "collection" }, journal.pages.back)
		assert.are.same(
			{ left = "shelf shelf=core.toaststyle tab=nil", right = "shelf shelf=core.toaststyle look=nil" },
			journal.pages.subjects
		)
	end)

	it(
		'reads "The Collection", the shelf\'s name and "{owned} of {total} yours" in the hand at its right (LED-R169)',
		function()
			local _, loaded = shelfOf("core.toaststyle")
			local model = loaded.ns.CollectionModel(loaded.ns.journal.context)
			local shelf = model.byKey["core.toaststyle"]
			local left = loaded.ns.journal.pages.left

			assert.are.same(
				{ "The Collection", "Toast styles", ("%d of %d yours"):format(shelf.owned, #shelf.looks) },
				{ left[1].text, left[2].text, left[2].value }
			)
			local title = drawn(loaded, "left", "title")[1]
			assert.are.same({ "Toast styles", left[2].value }, { title.label:GetText(), title.note:GetText() })
		end
	)

	it(
		"shows the tabs All, Yours, To earn and In the shop with their counts, a tab with nothing in it left out (LED-R169)",
		function()
			local _, loaded = shelfOf("core.toaststyle")
			local model = loaded.ns.CollectionModel(loaded.ns.journal.context)
			local shelf = model.byKey["core.toaststyle"]

			local tabs = {}
			for i, tab in ipairs(loaded.ns.journal.pages.left[3].tabs) do
				tabs[i] = { tab.text, tab.count, tab.on }
			end

			assert.are.same({
				{ "All", tostring(#shelf.looks), true },
				{ "Yours", "1", false },
				{ "To earn", tostring(#loaded.ns.CollectionFilter(shelf.looks, "earn")), false },
				{ "In the shop", tostring(#loaded.ns.CollectionFilter(shelf.looks, "shop")), false },
			}, tabs)
			local view = drawn(loaded, "left", "tabs")[1].tabs
			assert.are.same({ "All", tabs[1][2] }, { view[1].label:GetText(), view[1].count:GetText() })
			local _, titles = shelfOf("titles")
			local names = {}
			for i, tab in ipairs(titles.ns.journal.pages.left[3].tabs) do
				names[i] = tab.text
			end
			assert.are.same({ "All", "Yours", "To earn" }, names)
		end
	)

	it("filters by the tab on, opening the shelf with the tab, the look chosen kept (LED-R169)", function()
		local _, loaded = shelfOf("core.toaststyle")
		local journal = loaded.ns.journal
		local model = loaded.ns.CollectionModel(journal.context)
		local shelf = model.byKey["core.toaststyle"]

		drawn(loaded, "left", "tabs")[1].tabs[3]:Click()

		assert.are.same({ shelf = "core.toaststyle", look = PAGE, tab = "earn" }, journal:Place().args)
		assert.are.equal(#loaded.ns.CollectionFilter(shelf.looks, "earn"), #cards(loaded))
		assert.are.equal("To earn", journal.pages.left[3].tabs[3].text)
		assert.is_true(journal.pages.left[3].tabs[3].on)
		-- the right page still shows the look chosen
		assert.are.equal("Torn Page", journal.pages.right[2].text)
	end)

	it(
		'lists the cards in registration order, ungrouped first and each group under its header with "{owned} of {n}" (LED-R169, SHOP-R21, SHOP-R27)',
		function()
			local _, loaded = shelfOf("core.crest")

			local headers = {}
			for _, block in ipairs(loaded.ns.journal.pages.left) do
				if block.kind == "kicker" and block.value then
					headers[#headers + 1] = { block.text, block.value }
				end
			end

			assert.are.same({ { "Zone crests", "0 of 54" }, { "Fish crests", "0 of 37" } }, headers)
			assert.are.equal("Plain", cards(loaded)[1][1])
			assert.are.equal("Plain", loaded.ns.journal.pages.left[4].cards[1].name)
		end
	)

	it(
		"draws each shelf's cards its way: look, speaker, book and shield, with the titles a pick list (LED-R169)",
		function()
			local layouts = {}
			for _, shelf in ipairs({ "core.toaststyle", "core.soundset", "core.binding", "core.crest", "titles" }) do
				local _, loaded = shelfOf(shelf)
				for _, block in ipairs(loaded.ns.journal.pages.left) do
					if block.kind == "cards" then
						layouts[#layouts + 1] = block.layout
						break
					end
				end
			end

			assert.are.same({ "look", "speaker", "book", "shield", "pick" }, layouts)
		end
	)

	it(
		"lays toast styles two across at 176 × 54, bindings four across at 70 × 92, crests five across at 56 × 62 (LED-R169, ledger.md › UI)",
		function()
			local sizes = {}
			for _, shelf in ipairs({ "core.toaststyle", "core.soundset", "core.binding", "core.crest" }) do
				local _, loaded = shelfOf(shelf)
				local view = cards(loaded)[1].view
				local art = view.art
				sizes[#sizes + 1] = { art:GetWidth(), art:GetHeight(), view:GetWidth() }
				local second = cards(loaded)[2].view
				sizes[#sizes][4] = select(5, view:GetPoint(1)) ~= select(5, second:GetPoint(1))
			end

			assert.are.same(176, sizes[1][1])
			assert.are.same({ 176, 54 }, { sizes[1][1], sizes[1][2] })
			assert.are.same({ 70, 92 }, { sizes[3][1], sizes[3][2] })
			assert.are.same({ 56, 62 }, { sizes[4][1], sizes[4][2] })
			assert.are.same({ 40, 40 }, { sizes[2][1], sizes[2][2] })
			-- two across: a card's width is under half the page's body, five across a fifth
			local page = 382
			assert.is_true(sizes[1][3] > page / 2 - 8 and sizes[1][3] < page / 2)
			assert.is_true(sizes[3][3] > page / 4 - 8 and sizes[3][3] < page / 4)
			assert.is_true(sizes[4][3] > page / 5 - 8 and sizes[4][3] < page / 5)
		end
	)

	it(
		'tags each card: "In use" after a wax dot, "The default", "Yours", the earned text over a bar, a price after the coin, "Curio crate" (LED-R169)',
		function()
			local _, loaded = shelfOf("core.toaststyle", nil, {
				before = chain(owning({ [RIPPLE] = SERVER_TIME - DAY }), earned(TALE)),
				modules = function(fake)
					local progress = fake.Pagle.GetEarnedProgress
					fake.Pagle.GetEarnedProgress = function(id)
						if id == CRIER then
							return { tag = "62 of 100 fish", have = 62, need = 100 }
						end
						return progress(id)
					end
				end,
			})

			local torn, ripple, tale =
				cardNamed(loaded, "Torn Page"), cardNamed(loaded, "Ripple"), cardNamed(loaded, "The Tall Tale")
			local storm, foil = cardNamed(loaded, "Storm Front"), cardNamed(loaded, "Prize Foil")
			local crier, vellum = cardNamed(loaded, "Town Crier's Proclamation"), cardNamed(loaded, "Oxblood Vellum")

			-- Torn Page is in use: the wax dot and \"In use\"
			assert.are.same({ false, "In use" }, { torn[2], torn[3] })
			assert.is_true(torn.view.dot:IsShown())
			assert.are.same({ "Yours", false }, { ripple[2], ripple[3] })
			assert.are.same({ "Yours" }, { tale[2] })
			-- to earn: the earned text, with a bar when it has a count
			assert.are.same(
				{ "62 of 100 fish", true, 0.62 },
				{ crier[2], crier.view.bar:IsShown(), crier.view.bar.pct }
			)
			assert.are.same({ "Prestige V", false }, { vellum[2], vellum.view.bar:IsShown() })
			-- in the shop: the price after a coin, or "Curio crate"
			assert.are.same({ "3,000", true }, { storm[2], storm.view.coin:IsShown() })
			assert.are.same({ "Curio crate", false }, { foil[2], foil.view.coin:IsShown() })
		end
	)

	it('tags the default "The default" once another look is in use (LED-R169)', function()
		local _, loaded = shelfOf("core.toaststyle", nil, {
			before = function(_, fake)
				fake.setPurchased({ [RIPPLE] = true })
				fake.Pagle.SetEquipped("core.toaststyle", RIPPLE)
			end,
		})

		assert.are.same(
			{ "The default", false },
			{ cardNamed(loaded, "Torn Page")[2], cardNamed(loaded, "Torn Page")[3] }
		)
		assert.are.same({ false, "In use" }, { cardNamed(loaded, "Ripple")[2], cardNamed(loaded, "Ripple")[3] })
	end)

	it("outlines the chosen card in red ink, the look in use chosen by default (LED-R169, LED-R170)", function()
		local _, loaded = shelfOf("core.toaststyle")

		local torn, ripple = cardNamed(loaded, "Torn Page").view, cardNamed(loaded, "Ripple").view

		assert.is_true(torn.chosen[1]:IsShown())
		assert.is_false(ripple.chosen[1]:IsShown())
		local _, chosen = shelfOf("core.toaststyle", RIPPLE)
		assert.are.same({ false, true }, {
			cardNamed(chosen, "Torn Page").view.chosen[1]:IsShown(),
			cardNamed(chosen, "Ripple").view.chosen[1]:IsShown(),
		})
	end)

	it(
		"opens the shelf with a card's look chosen on a click, the right page crossfading (LED-R169, LED-R170, BOOK-R30)",
		function()
			local _, loaded = shelfOf("core.toaststyle", nil, { motion = true })
			local journal = loaded.ns.journal
			loaded.client.update(1)

			cardNamed(loaded, "Ripple").view:Click()
			loaded.client.update(0.1)

			assert.are.same({ shelf = "core.toaststyle", look = RIPPLE }, journal:Place().args)
			assert.are.equal("Ripple", journal.pages.right[2].text)
			assert.is_true(journal.frame:IsShown())
			assert.is_true(loaded.client.sounds[#loaded.client.sounds]:find("836 SFX", 1, true) ~= nil)
		end
	)

	it(
		"keeps the left page's scroll while a card is chosen and starts it again under another tab (LED-R129, LED-R169)",
		function()
			local _, loaded = shelfOf("core.toaststyle")
			local journal = loaded.ns.journal
			scrollPage(loaded, "left", 120)
			scrollPage(loaded, "right", 30)

			cardNamed(loaded, "Storm Front").view:Click()

			assert.are.same({ 120, 0 }, { pageScroll(loaded, "left"), pageScroll(loaded, "right") })
			scrollPage(loaded, "left", 120)
			drawn(loaded, "left", "tabs")[1].tabs[2]:Click()
			assert.are.equal(0, pageScroll(loaded, "left"))
			assert.are.same("yours", journal:Place().args.tab)
		end
	)

	it("shows an unknown shelf as the Collection's own pages, the crumb of the Collection alone (LED-R166)", function()
		local _, loaded = shelfOf("elsewhere")
		local journal = loaded.ns.journal

		assert.are.same({ "Home", "The Collection" }, { journal.pages.crumbs[1].label, journal.pages.crumbs[2].label })
		assert.are.equal("The Collection", journal.pages.left[2].text)
	end)

	it("keeps its words on the parchment at the default size on every shelf (LED-R169, CORE-R65)", function()
		for _, shelf in ipairs({ "core.toaststyle", "core.soundset", "core.binding", "core.crest", "titles" }) do
			local _, loaded = shelfOf(shelf, nil, { before = owning({ [RIPPLE] = SERVER_TIME - DAY }) })
			local shown = loaded.ns.journal.shown

			assert.are.same({}, bounds.overflows(shown.left))
			assert.are.same({}, bounds.overflows(shown.right))
			assert.is_true(bounds.measured > 0)
		end
	end)
end)

describe("Tracker frames and the Titles (LED-R167, LED-R169)", function()
	-- Stats' and Hunts' tracker frame slots, each with a default and a frame for sale.
	local function trackers(fake)
		for _, module in ipairs({ { "Hunts", 20 }, { "Stats", 30 } }) do
			local name, order = module[1], module[2]
			local handle = fake.Pagle.RegisterModule({ name = name, title = name, order = order })
			local slot = name:lower() .. ".trackerframe"
			handle:RegisterSlot({ id = slot, label = name .. " tracker frame", category = "Trackers" })
			handle:RegisterGood({ id = slot .. ".none", slot = slot, name = name .. " No Frame", default = true })
			handle:RegisterGood({ id = slot .. ".map", slot = slot, name = name .. " Map Scrap", tier = 1 })
		end
	end

	it(
		'share one shelf, Tracker frames, grouped by Module under its name with "{owned} of {n}" (LED-R167, LED-R169)',
		function()
			local _, loaded = shelfOf("trackers", nil, { modules = trackers })

			local headers = {}
			for _, block in ipairs(loaded.ns.journal.pages.left) do
				if block.kind == "kicker" and block.value then
					headers[#headers + 1] = { block.text, block.value }
				end
			end

			assert.are.same({ { "Hunts", "1 of 2" }, { "Stats", "1 of 2" } }, headers)
			assert.are.equal("Tracker frames", loaded.ns.journal.pages.left[2].text)
			assert.are.same({ "Hunts No Frame", "Hunts Map Scrap", "Stats No Frame", "Stats Map Scrap" }, {
				cards(loaded)[1][1],
				cards(loaded)[2][1],
				cards(loaded)[3][1],
				cards(loaded)[4][1],
			})
		end
	)

	it("show the frames each Module wears on the Collection's row, joined (LED-R168)", function()
		local _, loaded = open("collection", nil, { modules = trackers })

		local row = loaded.ns.journal.pages.left[9]

		assert.are.same({ "Tracker frames", "Hunts No Frame · Stats No Frame" }, { row.text, row.sub })
	end)

	it(
		'sit Titles last, Automatic first under "Levels and Prestige", then the Wardens, Legends and the whole Ledger (LED-R167, LED-R169, LED-R75)',
		function()
			local _, loaded = shelfOf("titles")

			local headers, first = {}, cards(loaded)
			for _, block in ipairs(loaded.ns.journal.pages.left) do
				if block.kind == "kicker" and block.value then
					headers[#headers + 1] = block.text
				end
			end

			assert.are.same({ "Levels and Prestige", "Wardens", "Legends", "The whole Ledger" }, headers)
			assert.are.same({ "Automatic", "Minnow", "Dabbler" }, { first[1][1], first[2][1], first[3][1] })
			-- Automatic is signed with, Minnow's earned: its earning line, in italic at the right; the rest are in pencil
			assert.are.same(
				{ "signed as", "Angler Level 1", "Angler Level 10" },
				{ first[1][2], first[2][2], first[3][2] }
			)
			assert.is_true(first[1].view.radio:IsShown())
			assert.are.equal("radio-on", first[1].view.radio.texture and "radio-on")
		end
	)

	it(
		"pick a title as a list of radios: the one signed with on, one not earned dimmed (LED-R169, LED-R170)",
		function()
			local _, loaded = shelfOf("titles")

			local automatic, minnow, dabbler =
				cardNamed(loaded, "Automatic").view, cardNamed(loaded, "Minnow").view, cardNamed(loaded, "Dabbler").view

			assert.are.same(
				{ 1, 1, 0.45 },
				{ automatic.radio:GetAlpha(), minnow.radio:GetAlpha(), dabbler.radio:GetAlpha() }
			)
			assert.is_true(automatic.dots:IsShown())
		end
	)
end)

describe("ink and pencil (LED-R170)", function()
	it(
		"draws a look owned in its colours on a card with a solid edge, one not owned in pencil on a dashed one",
		function()
			local _, loaded = shelfOf("core.toaststyle", nil, { before = owning({ [RIPPLE] = SERVER_TIME - DAY }) })

			local ripple, storm = cardNamed(loaded, "Ripple").view, cardNamed(loaded, "Storm Front").view

			assert.are.same(
				{ true, false, 0, 1 },
				{ ripple.edges[1]:IsShown(), ripple.dashes:IsShown(), ripple.art.pencil, ripple.art:GetAlpha() }
			)
			assert.are.same(
				{ false, true, 1, 0.5 },
				{ storm.edges[1]:IsShown(), storm.dashes:IsShown(), storm.art.pencil, storm.art:GetAlpha() }
			)
		end
	)

	it("names every look either way, a look never hidden before it is the Angler's (LED-R170, LED-R124)", function()
		local _, loaded = shelfOf("core.toaststyle")

		local names = {}
		for _, card in ipairs(cards(loaded)) do
			names[card[1]] = true
		end

		assert.is_true(names["Oxblood Vellum"] and names["Storm Front"] and names["Prize Foil"])
	end)

	it("tints the pencil by the Tunables: desaturated, sepia 0.45, alpha 0.5", function()
		local _, loaded = shelfOf("core.toaststyle")

		assert.are.same({ sepia = 0.45, alpha = 0.5 }, loaded.ns.COLLECTION_PENCIL)
	end)

	it(
		'draws the chosen look in its colours on the stage whatever its state, "A look before you have it" under it while not owned (LED-R170)',
		function()
			local fake, loaded = shelfOf("core.toaststyle", STORM)

			local stage = rightBlock(loaded, "stage")
			local widget = drawn(loaded, "right", "stage")[1]

			assert.are.same(
				{ kind = "stage", lookArt = { kind = "preview", good = STORM }, note = "A look before you have it" },
				stage
			)
			assert.are.equal("A look before you have it", widget.foot:GetText())
			local last = fake.goodPreviews[#fake.goodPreviews]
			assert.are.same({ STORM, "stage" }, { last.goodID, last.size })
			assert.are.same({ 1, 1 }, { widget.preview:GetAlpha(), widget:GetAlpha() })
			local _, owned = shelfOf("core.toaststyle", PAGE)
			assert.is_nil(rightBlock(owned, "stage").note)
		end
	)
end)

describe("the right page by a look's state (LED-R170)", function()
	it(
		'reads a look in use: the wax seal "In use", what it does in the hand and how it came, "Free, and always yours." for the default',
		function()
			local _, loaded = shelfOf("core.toaststyle", PAGE)

			assert.are.same({
				"[stage]",
				"Torn Page",
				"Toast style · The default",
				"A fresh page torn from the logbook and pinned to a leather spine. Brass trim, red ink.",
				"[useRow]",
			}, rightTexts(loaded))
			assert.are.same({
				seal = "In use",
				button = false,
				text = "Every Announcement wears it.",
				sub = "Free, and always yours.",
			}, (useRow(loaded)))
		end
	)

	it('reads a look in use bought: "Bought {date} for {price} Coins." (LED-R170)', function()
		local _, loaded = shelfOf("core.toaststyle", RIPPLE, {
			before = function(_, fake)
				fake.setPurchased({ [RIPPLE] = true }, { [RIPPLE] = SERVER_TIME - 5 * DAY })
				fake.Pagle.SetEquipped("core.toaststyle", RIPPLE)
			end,
		})

		local row = useRow(loaded)

		assert.are.same({
			seal = "In use",
			button = false,
			text = "Every Announcement wears it.",
			sub = "Bought " .. date(loaded, SERVER_TIME - 5 * DAY) .. " for 250 Coins.",
		}, row)
		assert.are.equal("Toast style · Curio Shop", rightTexts(loaded)[3])
	end)

	it('reads a look in use from a crate: "From a Curio crate, {date}." (LED-R170, SHOP-R36)', function()
		local _, loaded = shelfOf("core.toaststyle", FOIL, {
			before = function(_, fake)
				fake.setPurchased({ [FOIL] = true }, { [FOIL] = SERVER_TIME - 4 * DAY }, { [FOIL] = true })
				fake.Pagle.SetEquipped("core.toaststyle", FOIL)
			end,
		})

		assert.are.equal("From a Curio crate, " .. date(loaded, SERVER_TIME - 4 * DAY) .. ".", (useRow(loaded)).sub)
		assert.are.equal("Toast style · Curio crate only", rightTexts(loaded)[3])
	end)

	it('reads a look in use earned: "Earned {date}: {earning line}." (LED-R170)', function()
		local _, loaded = shelfOf("core.toaststyle", TALE, {
			before = function(l, fake)
				l.ns.db.global.celebrated.goods = { [TALE] = true }
				l.ns.Module:RefreshGoods()
				fake.Pagle.SetEquipped("core.toaststyle", TALE)
			end,
		})
		local seen = loaded.ns.db.global.collection.seen[TALE]

		assert.are.equal("Earned " .. date(loaded, seen) .. ": Land a Legend.", (useRow(loaded)).sub)
		assert.are.equal("Toast style · Ledger reward", rightTexts(loaded)[3])
	end)

	it(
		'reads an owned look: "Use it" and how it came, "Wear it" for a binding, and equips it on a click (LED-R170, SHOP-R32)',
		function()
			local fake, loaded =
				shelfOf("core.toaststyle", RIPPLE, { before = owning({ [RIPPLE] = SERVER_TIME - 5 * DAY }) })

			local row, widget = useRow(loaded)

			assert.are.same({
				seal = false,
				button = "Use it",
				text = false,
				sub = "Bought " .. date(loaded, SERVER_TIME - 5 * DAY) .. " for 250 Coins.",
			}, row)
			widget.face:Click()
			assert.are.equal(RIPPLE, fake.Pagle.GetEquipped("core.toaststyle"))
			local _, bindings = shelfOf(
				"core.binding",
				"core.binding.birch",
				{ before = owning({ ["core.binding.birch"] = SERVER_TIME - DAY }) }
			)
			assert.are.equal("Wear it", (useRow(bindings)).button)
		end
	)

	it(
		'reads a look to earn: "How to earn it", its earned text and, with a count, an ink bar and "{have} of {need} {unit}" (LED-R170)',
		function()
			local _, loaded = shelfOf("core.toaststyle", CRIER, {
				modules = function(fake)
					local progress = fake.Pagle.GetEarnedProgress
					fake.Pagle.GetEarnedProgress = function(id)
						if id == CRIER then
							return { tag = "62 of 100 fish", note = "Catch 100 fish as a Human", have = 62, need = 100 }
						end
						return progress(id)
					end
				end,
			})

			assert.are.same({
				"[stage]",
				"Town Crier's Proclamation",
				"Toast style · Ledger reward",
				rightTexts(loaded)[4],
				"How to earn it",
				"Catch 100 fish as a Human",
				"62 of 100 fish",
			}, rightTexts(loaded))
			assert.are.same(
				{ 0.62, "62 of 100 fish" },
				{ rightBlock(loaded, "count").fill, drawn(loaded, "right", "count")[1].label:GetText() }
			)
			assert.is_true(drawn(loaded, "right", "count")[1].bar:IsShown())
		end
	)

	it("reads a look to earn with no count: its earned text alone, no bar (LED-R170)", function()
		local _, loaded = shelfOf("core.toaststyle", VELLUM)

		assert.are.same({ "How to earn it", "Prestige V" }, { rightTexts(loaded)[5], rightTexts(loaded)[6] })
		assert.is_nil(rightBlock(loaded, "count"))
		assert.are.equal(6, #rightTexts(loaded))
	end)

	-- A Hunts toast style earned by a rule that doesn't hold, on sale at its fallback price from `from` (SHOP-R28).
	local function fallback(from)
		return function(fake)
			local hunts = fake.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
			hunts:RegisterGood({
				id = "hunts.toaststyle.glow",
				slot = "core.toaststyle",
				name = "Hunt Glow",
				earnedText = "Every Hunt done",
				isEarned = function()
					return false
				end,
				fallbackTier = 2,
				fallbackFrom = from,
			})
		end
	end

	it(
		'reads a look to earn with a fallback not reached: "Not earned by {date}? Then it goes on sale too, for {price} Coins." (LED-R170, SHOP-R28)',
		function()
			local from = SERVER_TIME + 10 * DAY
			local _, loaded = shelfOf("core.toaststyle", "hunts.toaststyle.glow", { modules = fallback(from) })

			assert.are.same({
				"[stage]",
				"Hunt Glow",
				"Toast style · Hunts reward",
				"How to earn it",
				"Every Hunt done",
				"Not earned by " .. date(loaded, from) .. "? Then it goes on sale too, for 400 Coins.",
			}, rightTexts(loaded))
			assert.is_nil(rightBlock(loaded, "price"))
		end
	)

	it(
		'reads a look to earn with its fallback reached: its price and "Buy in the Curio Shop" (LED-R170, SHOP-R28)',
		function()
			local fake, loaded =
				shelfOf("core.toaststyle", "hunts.toaststyle.glow", { modules = fallback(SERVER_TIME - DAY) })

			assert.are.equal("400", rightBlock(loaded, "price").value)
			assert.are.equal("Buy in the Curio Shop", (useRow(loaded)).button)
			drawn(loaded, "right", "useRow")[1].face:Click()
			assert.are.equal("hunts.toaststyle.glow", fake.shopsOpened[#fake.shopsOpened].goodID)
		end
	)

	it(
		'reads a look in the shop: its price with a coin, "Buy in the Curio Shop" and what you have left to go (LED-R170)',
		function()
			local fake, loaded = shelfOf("core.toaststyle", RIPPLE, { modules = balance(120) })

			assert.are.same({
				"[stage]",
				"Ripple",
				"Toast style · Curio Shop",
				"Blue leather and silver trim, with faint rings spreading across the page as if something just bit.",
				"[price]",
				"[useRow]",
				"You have 120 Coins: 130 more to go.",
			}, rightTexts(loaded))
			assert.are.equal("250", rightBlock(loaded, "price").value)
			assert.are.equal("250", drawn(loaded, "right", "price")[1].label:GetText())
			assert.are.same(
				{ seal = false, button = "Buy in the Curio Shop", text = false, sub = false },
				(useRow(loaded))
			)
			drawn(loaded, "right", "useRow")[1].face:Click()
			assert.are.equal(RIPPLE, fake.shopsOpened[#fake.shopsOpened].goodID)
		end
	)

	it('says "enough for it" with the Coins to buy it (LED-R170)', function()
		local _, loaded = shelfOf("core.toaststyle", RIPPLE, { modules = balance(1250) })

		assert.are.equal("You have 1,250 Coins, enough for it.", rightTexts(loaded)[7])
	end)

	it(
		'reads a crate-only look: "Only ever from a Curio crate.", "Open a crate" and that a crate gives it or nothing does (LED-R170, SHOP-R50)',
		function()
			local fake, loaded = shelfOf("core.toaststyle", FOIL)

			assert.are.same({
				"Only ever from a Curio crate.",
				"[useRow]",
				"Never for sale and never earned: a crate gives it, or nothing does.",
			}, { rightTexts(loaded)[5], rightTexts(loaded)[6], rightTexts(loaded)[7] })
			assert.are.equal("Open a crate", (useRow(loaded)).button)
			drawn(loaded, "right", "useRow")[1].face:Click()
			assert.are.equal("core.crate", fake.shopsOpened[#fake.shopsOpened].goodID)
			assert.is_nil(rightBlock(loaded, "price"))
		end
	)

	it(
		'reads a look\'s name with "new!" beside it while new, and its kicker "{slot label} · {source}" (LED-R170, LED-R171)',
		function()
			local _, loaded = shelfOf("core.toaststyle", RIPPLE, { before = owning({ [RIPPLE] = SERVER_TIME - DAY }) })

			assert.are.same(
				{ kind = "title", text = "Ripple", value = "new!", color = "red" },
				loaded.ns.journal.pages.right[2]
			)
			local title = drawn(loaded, "right", "title")[1]
			assert.are.same({ "Ripple", "new!" }, { title.label:GetText(), title.note:GetText() })
			assert.are.equal("Toast style · Curio Shop", loaded.ns.journal.pages.right[3].text)
		end
	)

	it("names a zone crest's zone as its source, and a binding's slot \"Binding\" (LED-R170)", function()
		local _, crest = shelfOf("core.crest", "ledger.crest.elwynn", { areaNames = { [12] = "Elwynn Forest" } })
		local _, binding = shelfOf("core.binding", FIELD)

		assert.are.equal("Bookplate crest · Elwynn Forest", rightTexts(crest)[3])
		assert.are.equal("Binding · The default", rightTexts(binding)[3])
	end)

	it('greys a look put away: "Put away: {Module} is off" and no button (LED-R170, LED-R172)', function()
		local _, loaded = shelfOf("core.toaststyle", "hunts.toaststyle.old", {
			modules = function(fake)
				fake.global.goods["hunts.toaststyle.old"] = {
					name = "Old Glow",
					slot = "core.toaststyle",
					slotLabel = "Toast style",
					category = "Announcements",
					module = "Hunts",
					earned = true,
				}
			end,
		})

		assert.are.equal("Put away: Hunts is off", rightTexts(loaded)[#rightTexts(loaded)])
		assert.are.same(
			{ "faded" },
			{ rightBlock(loaded, "text") and loaded.ns.journal.pages.right[#loaded.ns.journal.pages.right].color }
		)
		assert.are.equal(0, #drawn(loaded, "right", "useRow"))
	end)

	it("keeps its words on the parchment at the default size, whichever its state (LED-R170, CORE-R65)", function()
		for _, look in ipairs({ PAGE, RIPPLE, STORM, FOIL, TALE, VELLUM, CRIER }) do
			local _, loaded = shelfOf("core.toaststyle", look, {
				modules = balance(12345678),
				before = owning({ [RIPPLE] = SERVER_TIME - DAY }),
			})

			assert.are.same({}, bounds.overflows(loaded.ns.journal.shown.right))
		end
	end)
end)

describe("titles on the right page (LED-R170, LED-R77, LED-R157)", function()
	it('draws the stage as "Signed as", the title in the hand and the Angler\'s name and level (LED-R170)', function()
		local _, loaded = shelfOf("titles", "title:level1")

		local stage = rightBlock(loaded, "stage")
		local widget = drawn(loaded, "right", "stage")[1]

		assert.are.same({ "Signed as", "Minnow" }, { stage.sub, stage.text })
		assert.are.same(
			{ "Signed as", "Minnow", stage.lines[1] },
			{ widget.signed:GetText(), widget.words:GetText(), widget.line:GetText() }
		)
		assert.matches("^.+ · Angler Level 1$", stage.lines[1])
		assert.is_false(widget.preview:IsShown())
	end)

	it('reads its name, the kicker "Title · {group}" and the Ledger\'s description (LED-R170)', function()
		local _, loaded = shelfOf("titles", "title:level1")

		assert.are.same({
			"[stage]",
			"Minnow",
			"Title · Levels and Prestige",
			"A title of the Ledger. Sign the Ledger with it, and it shows on your brass plate and your bookplate.",
			"[useRow]",
		}, rightTexts(loaded))
		assert.are.same(
			{ seal = false, button = "Sign with it", text = false, sub = "Earned: Angler Level 1." },
			(useRow(loaded))
		)
	end)

	it(
		'signs with it on a click: the active title, its card "signed as", the seal in use, and logged as the title record (LED-R173, LED-R77, LED-R157)',
		function()
			local fake, loaded = shelfOf("titles", "title:level1")
			local journal = loaded.ns.journal

			drawn(loaded, "right", "useRow")[1].face:Click()
			frame(loaded)

			assert.are.equal("title:level1", loaded.ns.db.profile.activeTitle)
			assert.are.same(
				{ false, "signed as" },
				{ cardNamed(loaded, "Automatic")[2] == "signed as", cardNamed(loaded, "Minnow")[2] }
			)
			assert.are.same({
				seal = "In use",
				button = false,
				text = "The Ledger is signed with it.",
				sub = "Earned: Angler Level 1.",
			}, (useRow(loaded)))
			local payloads = {}
			for record in fake.catchLog:Iterate(0, "Ledger") do
				local module = record --[[@as PagleModuleRecord]]
				if record.kind == "module" and module.recordKind == "title" then
					payloads[#payloads + 1] = module.payload
				end
			end
			assert.are.same({ "title:level1" }, payloads)
			assert.are.equal("Signed “Minnow”", loaded.ns.CollectionModel(journal.context).byKey.titles.wearing)
		end
	)

	it("signs with Automatic by clearing the pick (LED-R77)", function()
		local _, loaded = shelfOf("titles", "automatic", {
			before = function(l)
				l.ns.db.profile.activeTitle = "title:level1"
			end,
		})

		assert.are.equal("Sign with it", (useRow(loaded)).button)
		drawn(loaded, "right", "useRow")[1].face:Click()

		assert.is_nil(loaded.ns.db.profile.activeTitle)
	end)

	it(
		'reads a title not earned: "How to earn it" and its earning line, the stage "A look before you have it" (LED-R170)',
		function()
			local _, loaded = shelfOf("titles", "title:level30")

			assert.are.same({ "How to earn it", "Angler Level 30" }, { rightTexts(loaded)[5], rightTexts(loaded)[6] })
			assert.are.equal("A look before you have it", rightBlock(loaded, "stage").note)
			assert.are.equal(0, #drawn(loaded, "right", "useRow"))
		end
	)

	it("shows Automatic as the highest level title earned, whatever is stored (LED-R77)", function()
		local _, loaded = shelfOf("titles", "automatic")

		assert.are.equal("Minnow", rightBlock(loaded, "stage").text)
		assert.are.equal("Automatic", loaded.ns.journal.pages.right[2].text)
		assert.are.equal("Title · Levels and Prestige", loaded.ns.journal.pages.right[3].text)
	end)
end)

describe("new and lately (LED-R171)", function()
	it("starts nothing new on a first opening: every look and title owned is noted seen and looked at once", function()
		local _, loaded = open("collection")

		local collection = loaded.ns.db.global.collection

		local seen, looked = {}, {}
		for id in pairs(collection.seen) do
			seen[id] = true
		end
		for id in pairs(collection.looked) do
			looked[id] = true
		end
		assert.are.same(seen, looked)
		assert.are.same({ SERVER_TIME, SERVER_TIME, SERVER_TIME }, {
			collection.seen[PAGE],
			collection.seen.automatic,
			collection.seen["title:level1"],
		})
		assert.are.equal(0, loaded.ns.CollectionModel(loaded.ns.journal.context).new)
	end)

	it(
		"never rebuilds the collection from the log: it is PagleLedgerDB.global.collection, kept as it was saved",
		function()
			local saved = { global = { collection = { seen = { [PAGE] = 5 }, looked = {} } } }
			local _, loaded = open(
				"collection",
				nil,
				{ globals = { PagleLedgerDB = saved, BreakUpLargeNumbers = breakUpLargeNumbers } }
			)

			-- what it held stays as it was; the owned looks and titles it hadn't are new, not looked at (LED-R171)
			assert.are.equal(5, loaded.ns.db.global.collection.seen[PAGE])
			assert.is_nil(loaded.ns.db.global.collection.looked[PAGE])
			assert.is_nil(loaded.ns.db.global.collection.looked[FIELD])
			assert.are.equal(6, loaded.ns.CollectionModel(loaded.ns.journal.context).new)
		end
	)

	it(
		"notes a look owned after the first opening with the time now, new until its shelf is drawn (LED-R171)",
		function()
			local _, loaded = open("collection", nil, { before = owning({ [RIPPLE] = SERVER_TIME - DAY }) })
			local collection = loaded.ns.db.global.collection

			assert.are.same({ SERVER_TIME, nil }, { collection.seen[RIPPLE], collection.looked[RIPPLE] })
			assert.are.equal(1, loaded.ns.CollectionModel(loaded.ns.journal.context).new)
		end
	)

	it(
		'marks "new!" at a new look\'s corner on its shelf, and has looked at it once the shelf is drawn (LED-R169, LED-R171)',
		function()
			local _, loaded = shelfOf("core.toaststyle", nil, { before = owning({ [RIPPLE] = SERVER_TIME - DAY }) })

			assert.are.equal("new!", cardNamed(loaded, "Ripple")[4])
			assert.is_false(cardNamed(loaded, "Torn Page")[4])
			assert.is_true(loaded.ns.db.global.collection.looked[RIPPLE])
			-- drawn again, it is no longer new
			loaded.ns.journal:Draw()
			assert.is_false(cardNamed(loaded, "Ripple")[4])
		end
	)

	it("counts a shelf's new looks on the Collection's row until its shelf is drawn (LED-R168, LED-R171)", function()
		local _, loaded = open("collection", nil, { before = owning({ [RIPPLE] = SERVER_TIME - DAY }) })
		local journal = loaded.ns.journal

		assert.are.equal("1 new", journal.pages.left[5].note)
		assert.is_nil(journal.pages.left[6].note)
		drawn(loaded, "left", "shelfRow")[1]:Click()
		journal:Open("collection")
		assert.is_nil(journal.pages.left[5].note)
	end)

	it(
		'counts every new look and title in Home\'s line, "{n} new" in red hand beside "x / N" (LED-R132, LED-R171)',
		function()
			local _, loaded =
				open("home", nil, { before = owning({ [RIPPLE] = SERVER_TIME - DAY, [STORM] = SERVER_TIME - DAY }) })

			local block = loaded.ns.journal.pages.right[10]
			local line = drawn(loaded, "right", "leader")[4]

			assert.are.same(
				{ "iv.", "The Collection: looks and titles", "2 new" },
				{ line.numeral:GetText(), line.label:GetText(), line.note:GetText() }
			)
			assert.are.same({ "2 new", "collection" }, { block.note, block.place.id })
			assert.is_true(line.note:IsShown())
			line:Click()
			assert.are.same({ id = "collection" }, loaded.ns.journal:Place())
		end
	)

	it("reads Home's line as x / N of looks and titles without a note while nothing is new (LED-R132)", function()
		local _, loaded = open("home")
		local model = loaded.ns.CollectionModel(loaded.ns.journal.context)

		local line = drawn(loaded, "right", "leader")[4]

		assert.are.equal(("%d / %d"):format(model.owned, model.total), line.value:GetText())
		assert.is_false(line.note:IsShown())
	end)

	-- Core's projections as the spec holds them: updating until `idle.now` is set, as a rebuild's wallet is until its done.
	local function slowCore()
		local idle = { now = false }
		return idle,
			function(fake)
				local updating = fake.Pagle.IsUpdating
				fake.Pagle.IsUpdating = function()
					return not idle.now or updating()
				end
			end
	end

	it(
		"waits for the projections to catch up before noting: a purchase handed over late after a first opening is not new (LED-R171)",
		function()
			local idle, slow = slowCore()
			local fake, loaded = open("collection", nil, { building = true, id = false, modules = slow })
			fake.enterWorld()
			loaded.ns.journal:Open("collection")
			loaded.client.runTimers()

			-- the Journal opened and drew while Core's wallet was still catching up: nothing noted, nothing new
			assert.is_nil(loaded.ns.db.global.collection)
			assert.are.equal(0, loaded.ns.CollectionModel(loaded.ns.journal.context).new)

			-- its done hands the purchases over, and the projections are idle: the first noting takes them as owned all along
			fake.setPurchased({ [RIPPLE] = true }, { [RIPPLE] = SERVER_TIME - DAY })
			idle.now = true
			loaded.client.runTimers()

			local collection = loaded.ns.db.global.collection
			assert.are.same({ SERVER_TIME, true }, { collection.seen[RIPPLE], collection.looked[RIPPLE] })
			assert.are.equal(0, loaded.ns.CollectionModel(loaded.ns.journal.context).new)
			assert.is_true(loaded.ns.journal.pages.left[5].note == nil)
		end
	)

	it("draws the open Journal again once it has noted, the looks it had no word of owned (LED-R171)", function()
		local idle, slow = slowCore()
		local fake, loaded = open("collection", nil, { building = true, id = false, modules = slow })
		fake.enterWorld()
		loaded.ns.journal:Open("collection")
		local before = loaded.ns.CollectionModel(loaded.ns.journal.context).owned
		fake.setPurchased({ [RIPPLE] = true }, { [RIPPLE] = SERVER_TIME - DAY })

		idle.now = true
		loaded.client.runTimers()

		assert.are.equal(before + 1, loaded.ns.CollectionModel(loaded.ns.journal.context).owned)
	end)

	it("keeps a purchase made after the first noting new, as before (LED-R171)", function()
		local idle, slow = slowCore()
		local fake, loaded = open("collection", nil, { building = true, id = false, modules = slow })
		fake.enterWorld()
		idle.now = true
		loaded.client.runTimers()

		fake.setPurchased({ [RIPPLE] = true }, { [RIPPLE] = SERVER_TIME })
		loaded.ns.journal:Open("collection")

		assert.is_nil(loaded.ns.db.global.collection.looked[RIPPLE])
		assert.are.equal(1, loaded.ns.CollectionModel(loaded.ns.journal.context).new)
	end)

	it("notes a title earned live as seen, new until the Titles shelf is drawn (LED-R171)", function()
		local _, loaded = open("collection", nil, {
			before = function(l)
				l.ns.db.global.celebrated.titles = { ["title:level10"] = true }
			end,
		})
		local collection = loaded.ns.db.global.collection

		assert.is_true(collection.seen["title:level10"] ~= nil)
		assert.is_nil(collection.looked["title:level10"])
		assert.are.equal("1 new", loaded.ns.journal.pages.left[9].note)
	end)

	it("notes a good a live entry earns when that entry is applied, before any drawing (LED-R171)", function()
		local _, loaded = open("collection", nil, { id = false })
		local global = loaded.ns.db.global
		global.celebrated.goods = { [TALE] = true }
		loaded.ns.Module:RefreshGoods()

		loaded.ns.NoteCollection()

		assert.is_true(global.collection.seen[TALE] ~= nil)
		assert.is_nil(global.collection.looked[TALE])
	end)

	it("never lists a Curio crate that paid its Coins back, which gave no look (LED-R171, SHOP-R51)", function()
		-- Core hands over no good for a payback, so there is nothing for the Collection to count or list
		local _, plain = open("collection")
		local _, loaded = open("collection", nil, { before = owning({}) })

		assert.are.equal(
			plain.ns.CollectionModel(plain.ns.journal.context).owned,
			loaded.ns.CollectionModel(loaded.ns.journal.context).owned
		)
		for _, block in ipairs(loaded.ns.journal.pages.right) do
			assert.is_true(block.kind ~= "latelyRow")
		end
	end)
end)

describe("put away (LED-R172)", function()
	-- A good of Hunts, which is off, in Core's toast style slot: earned and owned, or not owned and for sale.
	local function away(modules)
		return function(fake)
			fake.global.goods["hunts.toaststyle.old"] = {
				name = "Old Glow",
				slot = "core.toaststyle",
				slotLabel = "Toast style",
				category = "Announcements",
				module = "Hunts",
				earned = true,
			}
			fake.global.goods["hunts.toaststyle.next"] = {
				name = "Next Glow",
				slot = "core.toaststyle",
				slotLabel = "Toast style",
				category = "Announcements",
				module = "Hunts",
				earned = false,
			}
			fake.global.goods["stats.trackerframe.map"] = {
				name = "Map Scrap",
				slot = "stats.trackerframe",
				slotLabel = "Stats tracker frame",
				category = "Trackers",
				module = "Stats",
				earned = true,
			}
			if modules then
				modules(fake)
			end
		end
	end

	it(
		'lists a Module off\'s good last on its shelf under "Put away: {Module} is off", pencil, owned or not (LED-R172)',
		function()
			local _, loaded = shelfOf("core.toaststyle", nil, { modules = away() })

			local headers = {}
			for _, block in ipairs(loaded.ns.journal.pages.left) do
				if block.kind == "kicker" and block.value then
					headers[#headers + 1] = { block.text, block.value }
				end
			end

			assert.are.same({ { "Put away: Hunts is off", "1 of 2" } }, headers)
			local list = cards(loaded)
			-- Core lists a Module's put away goods by ID
			assert.are.same({ "Next Glow", "Old Glow" }, { list[#list - 1][1], list[#list][1] })
			for _, name in ipairs({ "Old Glow", "Next Glow" }) do
				local view = cardNamed(loaded, name).view
				assert.are.same({ false, true, 1 }, { view.edges[1]:IsShown(), view.dashes:IsShown(), view.art.pencil })
				assert.are.same({ "Put away", false }, { cardNamed(loaded, name)[2], cardNamed(loaded, name)[3] })
			end
		end
	)

	it('is never in use and has no button, "Put away: {Module} is off" in its place (LED-R172)', function()
		local _, loaded = shelfOf("core.toaststyle", "hunts.toaststyle.old", {
			modules = away(),
			before = function(_, fake)
				fake.profile.appearance["core.toaststyle"] = "hunts.toaststyle.old"
			end,
		})

		assert.are.equal(
			"Wearing Torn Page",
			loaded.ns.CollectionModel(loaded.ns.journal.context).byKey["core.toaststyle"].wearing
		)
		assert.are.equal("Put away: Hunts is off", rightTexts(loaded)[#rightTexts(loaded)])
		assert.are.equal(0, #drawn(loaded, "right", "useRow"))
	end)

	it("counts in {owned} of {total} as it did, from the cache (LED-R172)", function()
		local _, plain = shelfOf("core.toaststyle")
		local _, loaded = shelfOf("core.toaststyle", nil, { modules = away() })

		local before = plain.ns.CollectionModel(plain.ns.journal.context).byKey["core.toaststyle"]
		local shelf = loaded.ns.CollectionModel(loaded.ns.journal.context).byKey["core.toaststyle"]

		assert.are.same({ before.owned + 1, #before.looks + 2 }, { shelf.owned, #shelf.looks })
		assert.are.equal(("%d of %d yours"):format(shelf.owned, #shelf.looks), loaded.ns.journal.pages.left[2].value)
	end)

	it(
		"shows a Tracker frames group whose Module is off with only its put away looks under its header (LED-R172)",
		function()
			local _, loaded = shelfOf("trackers", nil, { modules = away() })

			local headers = {}
			for _, block in ipairs(loaded.ns.journal.pages.left) do
				if block.kind == "kicker" and block.value then
					headers[#headers + 1] = { block.text, block.value }
				end
			end

			assert.are.same({ { "Stats", "1 of 1" } }, headers)
			assert.are.same({ "Map Scrap", "Put away" }, { cards(loaded)[1][1], cards(loaded)[1][2] })
		end
	)
end)

describe("using a look here (LED-R173)", function()
	it(
		'changes the one equipped setting, the button giving way to the wax seal and the old look\'s "In use" becoming "Yours" (LED-R173, SHOP-R32)',
		function()
			local fake, loaded =
				shelfOf("core.toaststyle", RIPPLE, { before = owning({ [RIPPLE] = SERVER_TIME - DAY }) })

			drawn(loaded, "right", "useRow")[1].face:Click()
			frame(loaded)

			assert.are.equal(RIPPLE, fake.Pagle.GetEquipped("core.toaststyle"))
			assert.are.same(
				{ seal = "In use", button = false },
				{ seal = (useRow(loaded)).seal, button = (useRow(loaded)).button }
			)
			assert.are.same(
				{ "In use", "The default" },
				{ cardNamed(loaded, "Ripple")[3], cardNamed(loaded, "Torn Page")[2] }
			)
		end
	)

	it("shows a change Look and Feel or the Curio Shop makes at once, on AppearanceChanged (LED-R173)", function()
		local fake, loaded = shelfOf("core.toaststyle", nil, { before = owning({ [RIPPLE] = SERVER_TIME - DAY }) })
		assert.are.same({ "Yours" }, { cardNamed(loaded, "Ripple")[2] })

		fake.Pagle.SetEquipped("core.toaststyle", RIPPLE)
		frame(loaded)

		assert.are.same({ false, "In use" }, { cardNamed(loaded, "Ripple")[2], cardNamed(loaded, "Ripple")[3] })
		assert.are.equal(
			"Wearing Ripple",
			loaded.ns.CollectionModel(loaded.ns.journal.context).byKey["core.toaststyle"].wearing
		)
	end)

	it(
		"presses the seal on from 2.2 times its size (0.45 s) with the Journal's seal sound (LED-R173, ledger.md › UI)",
		function()
			local _, loaded = shelfOf("core.toaststyle", RIPPLE, {
				motion = true,
				before = owning({ [RIPPLE] = SERVER_TIME - DAY }),
			})
			loaded.client.update(1)
			local before = #loaded.client.sounds

			drawn(loaded, "right", "useRow")[1].face:Click()
			frame(loaded)
			loaded.client.update(0.01)
			local seal = drawn(loaded, "right", "useRow")[1].seal

			assert.is_true(seal:GetWidth() > 64 * 2)
			assert.are.equal("1204 SFX", loaded.client.sounds[#loaded.client.sounds])
			assert.is_true(#loaded.client.sounds > before)
			loaded.client.update(0.5)
			assert.are.same({ 64, 64 }, { seal:GetWidth(), seal:GetHeight() })
		end
	)

	it("shows the seal settled with Animations off, the sound still playing (LED-R173, ledger.md › UI)", function()
		local _, loaded = shelfOf("core.toaststyle", RIPPLE, { before = owning({ [RIPPLE] = SERVER_TIME - DAY }) })

		drawn(loaded, "right", "useRow")[1].face:Click()
		frame(loaded)

		local seal = drawn(loaded, "right", "useRow")[1].seal
		assert.are.same({ 64, 64, 1 }, { seal:GetWidth(), seal:GetHeight(), seal:GetAlpha() })
		assert.are.equal("1204 SFX", loaded.client.sounds[#loaded.client.sounds])
	end)

	it("lets a binding's Wear it change every book, Core playing the binding's change (LED-R173, ADR 0015)", function()
		local fake, loaded = shelfOf("core.binding", "core.binding.birch", {
			before = owning({ ["core.binding.birch"] = SERVER_TIME - DAY }),
		})

		drawn(loaded, "right", "useRow")[1].face:Click()
		frame(loaded)

		assert.are.equal("core.binding.birch", fake.Pagle.GetEquipped("core.binding"))
		assert.are.equal("In use", (useRow(loaded)).seal)
		assert.are.equal("Every book of yours wears it.", (useRow(loaded)).text)
	end)
end)

describe("getting there (LED-R174)", function()
	it(
		"opens on a look's shelf with it chosen, or on the Collection, through def.collection (LED-R166, LED-R174, CORE-R45)",
		function()
			local _, loaded = open("home")
			local def = loaded.ns.Module and loaded.ns.ModuleDef(loaded.ns.ToggleJournal, loaded.ns.OpenCollection)
			local journal = loaded.ns.journal

			def.collection(VELLUM)

			assert.are.same({ id = "shelf", args = { shelf = "core.toaststyle", look = VELLUM } }, journal:Place())
			def.collection()
			assert.are.same({ id = "collection" }, journal:Place())
			def.collection("nope.nothing")
			assert.are.same({ id = "collection" }, journal:Place())
		end
	)

	it(
		"is the Module def's `collection`, which Core opens from Look and Feel and from OpenShop on an earned look the shop doesn't list (CORE-R45, SHOP-R40)",
		function()
			local fake, loaded = open("home", nil, { id = false })

			fake.Pagle.OpenShop(VELLUM)

			assert.is_true(loaded.ns.journal:IsShown())
			assert.are.same(
				{ id = "shelf", args = { shelf = "core.toaststyle", look = VELLUM } },
				loaded.ns.journal:Place()
			)
			assert.are.same({}, fake.shopsOpened)
		end
	)

	it(
		"opens the Journal on a look's shelf while restricted: it makes no secure frames (LED-R121, LED-R174)",
		function()
			local fake, loaded = open("home", nil, { id = false })
			fake.setRestricted(true)

			fake.Pagle.OpenShop(VELLUM)
			assert.are.same(
				{ id = "shelf", args = { shelf = "core.toaststyle", look = VELLUM } },
				loaded.ns.journal:Place()
			)
			fake.slash("collection")

			assert.are.same({ id = "collection" }, loaded.ns.journal:Place())
			assert.is_true(loaded.ns.journal:IsShown())
		end
	)

	it("opens the Collection from /pagle collection, the Journal opening if it is closed (LED-R174)", function()
		local fake, loaded = open("home", nil, { id = false })

		fake.slash("collection")

		assert.is_true(loaded.ns.journal:IsShown())
		assert.are.same({ id = "collection" }, loaded.ns.journal:Place())
		assert.are.same(
			{ "Home", "The Collection" },
			{ loaded.ns.journal.pages.crumbs[1].label, loaded.ns.journal.pages.crumbs[2].label }
		)
	end)

	it("moves an open Journal to the Collection from /pagle collection (LED-R174)", function()
		local fake, loaded = open("home")

		fake.slash("collection")

		assert.are.same({ id = "collection" }, loaded.ns.journal:Place())
	end)

	it("opens the Collection from Home's contents line (LED-R132, LED-R174)", function()
		local _, loaded = open("home")

		drawn(loaded, "right", "leader")[4]:Click()

		assert.are.same({ id = "collection" }, loaded.ns.journal:Place())
	end)

	it('reads Home\'s line "The Collection: looks and titles" between Legends and the Angler (LED-R132)', function()
		local _, loaded = open("home")

		local lines = {}
		for _, block in ipairs(loaded.ns.journal.pages.right) do
			if block.kind == "leader" then
				lines[#lines + 1] = block.text
			end
		end

		assert.are.same({
			"The Trophy Room",
			"Curios: junk, treasure, uncharted",
			"Legends",
			"The Collection: looks and titles",
			"The Angler: hands and milestones",
			"Following",
		}, lines)
	end)

	it(
		"opens the shelf of a Module's own tracker slot for a good of it, and the shelf of an earned look in a Core slot (LED-R174)",
		function()
			local _, loaded = open("home", nil, {
				id = false,
				modules = function(fake)
					local stats = fake.Pagle.RegisterModule({ name = "Stats", title = "Stats", order = 30 })
					stats:RegisterSlot({
						id = "stats.trackerframe",
						label = "Stats tracker frame",
						category = "Trackers",
					})
					stats:RegisterGood({
						id = "stats.trackerframe.none",
						slot = "stats.trackerframe",
						name = "No Frame",
						default = true,
					})
				end,
			})

			loaded.ns.OpenCollection("stats.trackerframe.none")

			assert.are.same(
				{ id = "shelf", args = { shelf = "trackers", look = "stats.trackerframe.none" } },
				loaded.ns.journal:Place()
			)
		end
	)
end)

describe("searching the Collection (LED-R175)", function()
	-- Types `query` into the search slip as the player does.
	local function typeInto(loaded, query)
		local search = loaded.ns.journal.search
		search:SetText(query)
		search:GetScript("OnTextChanged")(search, true)
	end

	-- The drop-down's shown lines: { label, note }.
	local function dropdown(loaded)
		local lines = {}
		local drop = loaded.ns.journal.searchDrop
		if not drop:IsShown() then
			return lines
		end
		for _, row in ipairs(drop.rows) do
			if row:IsShown() then
				lines[#lines + 1] = { row.label:GetText(), row.note:IsShown() and row.note:GetText() or false }
			end
		end
		return lines
	end

	it(
		"reads \"Find a look…\" on the Collection's spreads, and the fish search's words elsewhere (LED-R175, LED-R148)",
		function()
			local _, loaded = open("collection")
			local hint = loaded.ns.journal.searchHint
			assert.are.equal("Find a look…", hint:GetText())

			loaded.ns.journal:Open("shelf", { shelf = "core.toaststyle" })
			assert.are.equal("Find a look…", hint:GetText())
			loaded.ns.journal:Open("home")
			assert.are.equal("Find a fish or a water…", hint:GetText())
		end
	)

	it(
		"finds a look by name, owned or not, each with its shelf at the right, and opens its shelf with it chosen (LED-R175)",
		function()
			local _, loaded = open("collection")

			typeInto(loaded, "front")

			assert.are.same({ { "Storm Front", "Toast style" } }, dropdown(loaded))
			loaded.ns.journal.searchDrop.rows[1]:Click()
			assert.are.same(
				{ id = "shelf", args = { shelf = "core.toaststyle", look = STORM } },
				loaded.ns.journal:Place()
			)
			assert.are.equal("Storm Front", loaded.ns.journal.pages.right[2].text)
			assert.are.equal("", loaded.ns.journal.search:GetText())
		end
	)

	it("finds an earned title and no title not earned, searching from a shelf's spread too (LED-R175)", function()
		local _, loaded = shelfOf("core.binding")

		typeInto(loaded, "minnow")
		assert.are.same({ { "Minnow", "Title" } }, dropdown(loaded))
		-- Dabbler is Angler Level 10's, not earned at level 1
		typeInto(loaded, "dabbler")
		assert.are.same({ { "Nothing by that name in the Ledger yet.", false } }, dropdown(loaded))
	end)

	it(
		"says nothing by that name in the Ledger yet, as the fish search does, and shows nothing for an empty box (LED-R175, LED-R148)",
		function()
			local _, loaded = open("collection")

			typeInto(loaded, "zzzzzz")
			assert.are.same({ { "Nothing by that name in the Ledger yet.", false } }, dropdown(loaded))
			typeInto(loaded, "")
			assert.are.same({}, dropdown(loaded))
		end
	)

	it("keeps LED-R148's search on the Journal's other spreads, unchanged (LED-R175)", function()
		local _, loaded = open("home")

		typeInto(loaded, "storm")

		assert.are.same({ { "Nothing by that name in the Ledger yet.", false } }, dropdown(loaded))
	end)
end)

describe("the Collection's motion (LED-R170, ledger.md › UI)", function()
	it(
		'inks a look that turns owned while its shelf is shown in from pencil to its colours, "new!" written beside it (0.6 s)',
		function()
			local fake, loaded = shelfOf("core.toaststyle", nil, { motion = true })
			loaded.client.update(1)
			local ripple = cardNamed(loaded, "Ripple").view
			assert.are.same({ 1, 0.5 }, { ripple.art.pencil, ripple.art:GetAlpha() })

			fake.setPurchased({ [RIPPLE] = true }, { [RIPPLE] = SERVER_TIME - 10 })
			fake.setSpent(250) -- the purchase changes the balance (SHOP-R12), which draws the shelf again
			frame(loaded)
			loaded.client.update(0.01)
			local view = cardNamed(loaded, "Ripple").view

			assert.are.equal("new!", cardNamed(loaded, "Ripple")[4])
			assert.is_true(view.art.pencil > 0.9)
			loaded.client.update(0.3)
			assert.is_true(view.art.pencil < 0.9 and view.art.pencil > 0.1)
			loaded.client.update(0.4)
			assert.are.same({ 0, 1 }, { view.art.pencil, view.art:GetAlpha() })
		end
	)

	it("shows the look in ink at once with Animations off (LED-R170, BOOK-R32)", function()
		local fake, loaded = shelfOf("core.toaststyle")

		fake.setPurchased({ [RIPPLE] = true }, { [RIPPLE] = SERVER_TIME - 10 })
		fake.setSpent(250)
		frame(loaded)

		local view = cardNamed(loaded, "Ripple").view
		assert.are.same(
			{ 0, 1, true, false },
			{ view.art.pencil, view.art:GetAlpha(), view.edges[1]:IsShown(), view.dashes:IsShown() }
		)
	end)

	it(
		"inks in a look new when it is first drawn, once, drawn in its colours when drawn again (LED-R170, LED-R171)",
		function()
			local _, loaded = shelfOf("core.toaststyle", nil, {
				motion = true,
				before = owning({ [RIPPLE] = SERVER_TIME - DAY }),
			})
			local view = cardNamed(loaded, "Ripple").view
			loaded.client.update(0.01)
			assert.is_true(view.art.pencil > 0.9)
			loaded.client.update(1)
			assert.are.equal(0, view.art.pencil)

			loaded.ns.journal:Draw()
			loaded.client.update(0.01)

			assert.are.equal(0, view.art.pencil)
		end
	)
end)
