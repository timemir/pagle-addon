-- Core's book shell (core/book.md), Pagle.NewBook, as FakePagle hands it to a Module: Core's real adapter/Book.lua on
-- the Module's client fake.

describe("Pagle.NewBook (core/book.md)", function()
	local fake, loaded, client

	before_each(function()
		fake = newFakePagle()
		loaded = fake.load("Pagle_QoL")
		client = loaded.client
	end)

	-- A small book: a home page, a numbered page and a page with what it needs.
	local function newBook(extra)
		local options = {
			id = "test",
			name = "PagleTestBook",
			width = 600,
			height = 400,
			pages = {
				home = { order = 0 },
				leaf = { keeps = { "n" }, needs = "n", order = 1 },
			},
			home = { page = "home" },
			trail = function(place)
				local trail = { { text = "Home", target = { page = "home" } } }
				if place.page == "leaf" then
					trail[2] = { text = "Leaf " .. place.n }
				end
				return trail
			end,
			ribbons = {
				{ id = "home", text = "Home", color = { 0.2, 0.4, 0.2 }, target = { page = "home" } },
				{ id = "one", text = "One", color = { 0.5, 0.2, 0.2 }, target = { page = "leaf", n = 1 } },
			},
		}
		for key, value in pairs(extra or {}) do
			options[key] = value
		end
		return fake.Pagle.NewBook(options)
	end

	local function soundsSince(from)
		return { unpack(client.sounds, from + 1) }
	end

	it(
		"builds nothing until its first opening, then opens named, in UISpecialFrames, with its sound (BOOK-R1–R4)",
		function()
			local book = newBook()
			assert.is_nil(book.frame)
			local from = #client.sounds
			book:Open()
			assert.are.equal(book.frame, loaded.env.PagleTestBook)
			assert.is_true(book:IsShown())
			assert.are.equal("HIGH", book.frame.strata)
			assert.is_true(book.frame.toplevel)
			assert.are.same({ "829 SFX" }, soundsSince(from))
			local special = false
			for _, name in ipairs(loaded.env.UISpecialFrames) do
				special = special or name == "PagleTestBook"
			end
			assert.is_true(special)
		end
	)

	it("refuses a second book with the same id, and a home its pages refuse (BOOK-R1, BOOK-R20)", function()
		newBook()
		assert.has_error(function()
			newBook()
		end)
		assert.has_error(function()
			newBook({ id = "other", home = { page = "leaf" } })
		end)
	end)

	it("draws each side with its renderer and lays the crumbs from the trail (BOOK-R21, BOOK-R24)", function()
		local book = newBook()
		local drawn = {}
		book:RegisterPage("leaf", "left", function(content, place)
			drawn[#drawn + 1] = place.n
			assert.is_table(content)
			return 900
		end)
		book:Open({ page = "leaf", n = 7 })
		assert.are.same({ 7 }, drawn)
		local crumbs = book.frame.crumbButtons
		assert.are.equal("Home", crumbs[1].label:GetText())
		assert.are.equal("Leaf 7", crumbs[2].label:GetText())
		assert.is_nil(crumbs[2]:GetScript("OnClick"))
		crumbs[1]:Click()
		assert.are.same({ page = "home" }, book:Place())
	end)

	it("turns the page with its sound and hook as it changes page while open (BOOK-R31, BOOK-R33)", function()
		local phases = {}
		local book = newBook({
			onTurn = function(turn, phase)
				if phases[#phases] ~= phase then
					phases[#phases + 1] = phase
				end
				assert.is_true(turn.forward)
			end,
		})
		book:RegisterPage("leaf", "right", function() end)
		book:RegisterPage("home", "right", function() end)
		book:Open()
		local from = #client.sounds
		book:Open({ page = "leaf", n = 1 })
		client.update(0.6)
		assert.are.same({ "836 SFX" }, soundsSince(from))
		assert.are.same({ "start", "lift", "midway", "land", "done" }, phases)
	end)

	it("asks options.how for an Open without one (BOOK-R34)", function()
		local asked = {}
		local book = newBook({
			how = function(from, to)
				asked[#asked + 1] = from.page .. ">" .. to.page
				return { motion = "still" }
			end,
		})
		book:Open()
		local from = #client.sounds
		book:Open({ page = "leaf", n = 1 })
		assert.are.same({ "home>home", "home>leaf" }, asked)
		assert.are.same({}, soundsSince(from))
	end)

	it(
		"hangs its ribbons, chooses the page shown's, opens a ribbon's target and replaces the list (BOOK-R17–R19)",
		function()
			local book = newBook()
			book:Open()
			local ribbons = book.frame.ribbons
			assert.are.equal(86, ribbons[1].length)
			assert.are.equal(75, ribbons[2].length)
			ribbons[2]:Click()
			assert.are.same({ page = "leaf", n = 1 }, book:Place())
			book:SetRibbons({
				{
					id = "only",
					text = "Only",
					count = "3 on",
					tooltip = { "Only", "a line" },
					color = { 1, 1, 1 },
					target = {
						page = "home",
					},
				},
			})
			assert.is_true(ribbons[1]:IsShown())
			assert.is_false(ribbons[2]:IsShown())
			assert.are.equal("3 on", ribbons[1].count:GetText())
			assert.are.equal(ribbons[1], book:RibbonFrame("only"))
			assert.is_nil(book:RibbonFrame("one"))
		end
	)

	it(
		"tints each ribbon its colour, the chosen one brighter, and eases a change of choice over 0.2 s (BOOK-R17)",
		function()
			local book = newBook()
			book:Open()
			local ribbons = book.frame.ribbons
			assert.are.same({ 0.2 * 1.13, 0.4 * 1.13, 0.2 * 1.13 }, { unpack(ribbons[1].body.vertexColor, 1, 3) })
			assert.are.same({ 0.5, 0.2, 0.2 }, { unpack(ribbons[2].body.vertexColor, 1, 3) })
			assert.is_nil(ribbons[1].stitch.vertexColor) -- the gold stitch keeps its own colour
			ribbons[2]:Click()
			client.update(0.1)
			assert.is_true(ribbons[2].height > 75 and ribbons[2].height < 86)
			client.update(0.6)
			assert.are.equal(86, ribbons[2].height)
			assert.are.equal(75, ribbons[1].height)
		end
	)

	it("sizes the brass plate to its words and tones it silver for a look that says so (BOOK-R10, BOOK-R14)", function()
		local book = newBook({ plate = { x = 30, y = 360 } })
		book:SetPlate("No Casts yet")
		book:Open()
		local plate = book.frame.plate
		assert.are.equal(#"No Casts yet" * 6 + 22, plate.width)
		book.binding.onLook({
			gilt = { 0.8, 0.82, 0.86 },
			giltShadow = { 0, 0, 0, 0.9, 1, -1 },
			silver = true,
			paperTint = { 1, 0.97, 0.93 },
		})
		for _, slice in ipairs({ plate.brass.left, plate.brass.middle, plate.brass.right }) do
			assert.is_true(slice.desaturated)
			assert.are.same({ 1.1, 1.1, 1.15 }, slice.vertexColor)
		end
		assert.are.same({ 1, 0.97, 0.93 }, { unpack(book.frame.parchments.left.paper.vertexColor, 1, 3) })
	end)

	it("saves where it is dragged in profile.books and opens there again (BOOK-R5)", function()
		local book = newBook()
		book:Open()
		book.frame:Drag({ "TOPLEFT", loaded.env.UIParent, "TOPLEFT", 100, -50 })
		local saved = fake.profile.books.test
		assert.are.equal("TOPLEFT", saved[1])
		book:Close()
		client.update(0.2)
		book:Open()
		local point = book.frame.points[1]
		assert.are.equal("TOPLEFT", point[1])
	end)

	it("never moves a fixed book, and dims the world behind it (BOOK-R6)", function()
		local book = newBook({ fixed = true, dim = 0.58 })
		book:Open()
		assert.is_falsy(book.frame.movable)
		assert.is_true(book.frame.dim:IsShown())
		book:Close()
		client.update(0.2)
		assert.is_false(book.frame.dim:IsShown())
	end)

	it("fades its dim with it, whole again once settled (BOOK-R6, BOOK-R35)", function()
		local book = newBook({ fixed = true, dim = 0.58 })
		book:Open()
		client.update(0.08)
		local dim = book.frame.dim
		assert.is_true(dim:GetAlpha() > 0 and dim:GetAlpha() < 1)
		assert.are.equal(book.frame:GetAlpha(), dim:GetAlpha())
		book:Settle()
		assert.are.equal(1, dim:GetAlpha())
	end)

	it("wraps a ribbon's name to two lines inside the ribbon (BOOK-R17)", function()
		local book = newBook()
		book:Open()
		local label = book.frame.ribbons[1].label
		assert.is_true(label:CanWordWrap())
		assert.are.equal(82, label.width)
		assert.are.equal(2, label:GetMaxLines())
	end)

	it("reads as closed while it fades out after a close (BOOK-R23)", function()
		local book = newBook()
		book:Open()
		book:Close()
		assert.is_true(book.frame:IsShown())
		assert.is_false(book:IsShown())
		book:Toggle()
		assert.is_true(book:IsShown())
	end)

	it("fades out, closes with its sound and calls onHide once (BOOK-R4, BOOK-R40)", function()
		local hidden = 0
		local book = newBook({
			onHide = function()
				hidden = hidden + 1
			end,
		})
		book:Open()
		local showing = book:Showing()
		local from = #client.sounds
		book.frame.close:Click()
		assert.is_true(book.frame:IsShown())
		client.update(0.2)
		assert.is_false(book:IsShown())
		assert.are.same({ "830 SFX" }, soundsSince(from))
		assert.are.equal(1, hidden)
		assert.are.equal(showing + 1, book:Showing())
	end)

	it("settles every motion at once with Settle (BOOK-R35)", function()
		local book = newBook()
		book:RegisterPage("leaf", "left", function() end)
		book:RegisterPage("home", "left", function() end)
		book:Open()
		book:Open({ page = "leaf", n = 1 })
		book:Settle()
		assert.is_nil(book.motion)
		assert.are.equal(1, book.frame:GetAlpha())
	end)

	it("writes the plate with its tooltip, silver with a silver look (BOOK-R14)", function()
		local book = newBook({ plate = { x = 30, y = 360 } })
		book:SetPlate("12 Casts", { "Titles", "One" })
		book:Open()
		assert.are.equal("12 Casts", book.frame.plate.label:GetText())
		assert.is_true(book.frame.plate.mouseEnabled)
	end)
end)
