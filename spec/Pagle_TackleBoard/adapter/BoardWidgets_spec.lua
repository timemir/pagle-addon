-- The board art kit on the client (TKB-R100, TKB-R102, TKB-R105, TKB-R107, TKB-R109; tackle-board.md › UI): the
-- atlases and their BLP textures, the bundled fonts, the sprite helpers (adapter/BoardArt.lua), the papers' lean and its
-- switch, the board's tooltip, and the pieces adapter/BoardWidgets.lua makes, on the fake client.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

-- The Tackle Board's ns, and a frame to draw on.
local function kit()
	local loaded = board.load()
	return loaded.ns, loaded.env.CreateFrame("Frame"), loaded
end

-- Records a region's turns: the fake client's SetRotation keeps nothing.
local function turning(region)
	region.SetRotation = function(self, radians)
		self.rotation = radians
	end
	return region
end

-- Whether a file is in the addon folder (a texture path is the folder's, under Interface\AddOns\).
local function shipped(path)
	local file = path:gsub("^Interface\\AddOns\\", "addons/"):gsub("\\", "/")
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
	local handle = io.open(file, "rb")
	if handle then
		handle:close()
	end
	return handle ~= nil
end

describe("the board art kit's atlases (tackle-board.md › UI)", function()
	it("ship each texture as a BLP in media/board, and the fonts in Core's media/fonts", function()
		local ns = kit()

		for name, atlas in pairs(ns.BOARD_ATLASES) do
			assert.is_true(shipped(atlas.file .. ".blp"), name)
		end
		assert.is_true(shipped(ns.CORK_TEXTURE .. ".blp"))
		for face, path in pairs(ns.BOARD_FONT_FACES) do
			assert.is_true(shipped(path), face)
		end
	end)

	it("keep every sprite inside its texture, its drawn element inside the sprite", function()
		local ns = kit()

		for name, atlas in pairs(ns.BOARD_ATLASES) do
			for sprite, at in pairs(atlas.sprites) do
				local where = name .. " " .. sprite
				assert.is_true(at.x >= 0 and at.x + at.w <= atlas.width, where)
				assert.is_true(at.y >= 0 and at.y + at.h <= atlas.height, where)
				assert.is_true(at.box[1] + at.box[3] <= at.w / atlas.scale + 0.01, where)
				assert.is_true(at.box[2] + at.box[4] <= at.h / atlas.scale + 0.01, where)
			end
		end
	end)

	it("give the tracker its own small Marks atlas: the header's flame and chevron and a slip's tack", function()
		local ns = kit()

		local marks = {}
		for sprite in pairs(ns.BOARD_ATLASES.Marks.sprites) do
			marks[#marks + 1] = sprite
		end
		table.sort(marks)

		assert.are.same({ "chev", "fl", "tack-s" }, marks)
		assert.are.same({ 64, 64 }, { ns.BOARD_ATLASES.Marks.width, ns.BOARD_ATLASES.Marks.height })
	end)
end)

describe("the board's fonts", function()
	it("are the kit's faces from Core's media/fonts, each made at its first use with its size and ink", function()
		local ns, parent = kit()

		local text = ns.ArtText(parent, "Goal")
		local font = ns.ArtFont("Goal")

		assert.are.equal("PagleTackleBoardGoal", font.name)
		assert.are.same({ "Interface\\AddOns\\Pagle\\media\\fonts\\IMFeENrm28P.ttf", 15, "" }, font.font)
		assert.are.equal(font, text.fontObject)
		assert.are.same(ns.BoardHex("2A180A"), { text.textColor[1], text.textColor[2], text.textColor[3] })
		assert.are.equal(font, ns.ArtFont("Goal"))
	end)

	it("name a face the kit bundles for every font", function()
		local ns = kit()

		for key, def in pairs(ns.BOARD_FONTS) do
			assert.is_string(ns.BOARD_FONT_FACES[def[1]], key)
		end
	end)

	it("fall back to the client's FRIZQT__ when a face won't load", function()
		local loaded = board.load()
		local ns = loaded.ns
		local create = loaded.env.CreateFont
		loaded.env.CreateFont = function(name)
			local font = create(name)
			local set = font.SetFont
			font.SetFont = function(self, file, size, flags)
				set(self, file, size, flags)
				return file == "Fonts\\FRIZQT__.TTF"
			end
			return font
		end

		assert.are.equal("Fonts\\FRIZQT__.TTF", ns.ArtFont("Kind").font[1])
	end)

	it("letter-space capitals as the kit sets its gilt titles", function()
		local ns = kit()

		assert.are.equal("T A C K L E   B O A R D", ns.Spaced("Tackle Board"))
		assert.are.equal("F L Y   B O X", ns.Spaced("Fly box"))
	end)
end)

describe("the sprite helpers", function()
	it("show a sprite at its designed size, cut from its atlas, its drawn element's box kept", function()
		local ns, parent = kit()

		local tack = ns.ArtSprite(parent, "Board", "tack")
		local atlas = ns.BOARD_ATLASES.Board

		assert.are.equal(atlas.file, tack.texture)
		assert.are.same({ 890 / 1024, 942 / 1024, 1346 / 2048, 1398 / 2048 }, tack.texCoord)
		assert.are.same({ 26, 26 }, { tack.width, tack.height })
		assert.are.same({ 3, 2, 15, 15 }, tack.box)
	end)

	it("place a sprite by its drawn element, not its margin", function()
		local ns, parent = kit()

		local tack = ns.ArtSprite(parent, "Board", "tack")
		ns.PlaceSprite(tack, parent, 100, 20)

		assert.are.same({ "TOPLEFT", parent, "TOPLEFT", 97, -18 }, tack.points[1])
	end)

	it("three-slice a strip to any width, its caps kept and its middle stretched", function()
		local ns, parent, loaded = kit()
		local strip = loaded.env.CreateFrame("Frame", nil, parent)

		ns.SetThreeSlice(strip, "Board", "btn", 300, 12)

		assert.are.same({ 300, 38 }, { strip.width, strip.height })
		assert.are.equal(18, strip.left.width) -- its 6-unit margin and its 12-unit cap
		assert.are.equal(18, strip.right.width)
	end)

	it("slice a tracker frame in three down to any height and squeeze it across to the width given", function()
		local ns, parent, loaded = kit()
		local frame = loaded.env.CreateFrame("Frame", nil, parent)

		ns.SetVSlice(frame, "Tracker", "trk-cork", 288, 400, 30, 20)

		assert.are.same({ 288, 400 }, { frame.width, frame.height })
		assert.are.equal(36, frame.top.height) -- its 6-unit margin and its 30-unit cap
		assert.are.equal(462 / 1.5 * 288 / 296, frame.top.width)
	end)

	it("cut a bar's fill to length rather than squeeze it", function()
		local ns, parent = kit()

		local fill = ns.SetCropSprite(parent:CreateTexture(), "Board", "bar-fill", 50)

		assert.are.same({ 2 / 1024, 102 / 1024 }, { fill.texCoord[1], fill.texCoord[2] })
		assert.are.equal(50, fill.width)
	end)
end)

describe("the papers' lean (TKB-R102)", function()
	it("leans a paper by its angle while on, and hangs it straight with `/pagle board lean` off, saved", function()
		local loaded, fake = board.load()
		fake.login()
		local ns = loaded.ns
		local paper = turning(ns.ArtSprite(loaded.env.CreateFrame("Frame"), "Board", "notice"))

		assert.is_true(ns.Leans())
		ns.LeanSprite(paper, paper:GetParent(), 0, 0, -1.6)
		assert.are.equal(math.rad(1.6), paper.rotation)

		fake.slash("board lean")
		ns.LeanSprite(paper, paper:GetParent(), 0, 0, -1.6)

		assert.is_false(ns.Leans())
		assert.is_false(ns.db.profile.lean)
		assert.are.equal(0, paper.rotation)
		assert.are.equal(loaded.ns.L.LEAN_OFF, loaded.printed[#loaded.printed])

		fake.slash("board lean")
		assert.is_true(ns.Leans())
		assert.are.equal(loaded.ns.L.LEAN_ON, loaded.printed[#loaded.printed])
	end)

	it("centres a leaning paper where it would hang straight", function()
		local ns, parent = kit()
		local paper = turning(ns.ArtSprite(parent, "Board", "notice"))

		ns.LeanSprite(paper, parent, 10, 20, 0)

		-- The drawn element (236 × 116) at 10, 20: its centre at 128, 78; the sprite's margins are 10 left, 4 top.
		local width, height = paper.width, paper.height
		assert.are.same(
			{ "CENTER", parent, "TOPLEFT", 10 + 118 + width / 2 - 128, -(20 + 58 + height / 2 - 62) },
			paper.points[1]
		)
	end)
end)

describe("the board's tooltip (TKB-R102, TKB-R103, TKB-R106)", function()
	it("shows its first line as its title and the rest under it, by its owner, and hides", function()
		local ns, parent = kit()

		ns.BoardHover(parent, { "Posted Wed 7 Oct, 09:00", "Only my Catches since then count" })

		assert.are.same({ "Posted Wed 7 Oct, 09:00", "Only my Catches since then count" }, ns.BoardHoverLines())
		ns.BoardHoverHide()
		assert.is_nil(ns.BoardHoverLines())
	end)

	it("ticks a Variety Expedition's caught Species, and draws a done goal's fly", function()
		local ns, parent = kit()

		ns.BoardHover(parent, { "Posted" }, {
			species = { { name = "Mightfish", caught = true }, { name = "Oily Blackmouth", caught = false } },
		})

		assert.are.same({ "Posted", "Mightfish", "Oily Blackmouth" }, ns.BoardHoverLines())

		ns.BoardHover(parent, { "1 Catch in Durotar", "Paid 10 Coins", "Tied for your Fly Box: x" }, {
			fly = "needles_ant",
		})
		assert.are.same({ "1 Catch in Durotar", "Paid 10 Coins", "Tied for your Fly Box: x" }, ns.BoardHoverLines())
	end)
end)

describe("the board's pieces", function()
	it(
		"outline an empty pin in dashes with a lone tack, its words by hand and its time in brackets under (TKB-R105)",
		function()
			local ns, parent = kit()

			local pin = ns.NewBoardEmptyPin(parent, 232, 108)
			pin:SetEmpty("A fresh Notice at reset (in 13h)")

			assert.are.same({ 232, 108 }, { pin.width, pin.height })
			assert.is_true(#pin.dashes > 0)
			assert.are.equal(ns.BOARD_ATLASES.Board.file, pin.tack.texture)
			assert.are.same({ "A fresh Notice at reset", "(in 13h)" }, { pin.label:GetText(), pin.note:GetText() })

			pin:SetEmpty("More Notices at later resets")

			assert.are.equal("More Notices at later resets", pin.label:GetText())
			assert.is_false(pin.note:IsShown())
		end
	)

	it("load the highlight's ring only when it first shows, sized round what it rings (TKB-R109)", function()
		local ns, parent = kit()
		parent:SetSize(236, 116)

		local ring = ns.NewBoardHighlight(parent, false)

		assert.is_false(ring:IsShown())
		assert.is_nil(ring.ring)
		ring:Show()
		assert.are.equal(ns.BOARD_ATLASES.Tracker.file, ring.ring.texture)
		assert.are.same({ 254, 134 }, { ring.ring.box[3], ring.ring.box[4] })
	end)

	it("make a leather button that calls back, greyed while it can't be used (TKB-R107)", function()
		local ns, parent = kit()
		local clicks = 0

		local button = ns.NewBoardButton(parent, "Start my board", 182, "Button", function()
			clicks = clicks + 1
		end)
		button:Click()
		button:SetUsable(false)
		button:Click()

		assert.are.equal(1, clicks)
		assert.are.equal("Start my board", button.label:GetText())
		assert.are.equal(182, button.width)
		assert.are.equal(0.55, button:GetAlpha())
	end)

	it("stamp RE-POSTED in red ink in a double rule (TKB-R55)", function()
		local ns, parent = kit()

		local stamp = ns.NewBoardStamp(parent, "RE-POSTED")

		assert.are.equal("RE-POSTED", stamp.label:GetText())
		assert.are.equal(8, #stamp.rules)
	end)

	it('write "take it down" in red pencil over a dotted line, greyed while it is not usable (TKB-R108)', function()
		local ns, parent = kit()

		local link = ns.NewTakeDownLink(parent, "take it down")
		link:SetUsable(false)

		assert.are.equal("take it down", link.label:GetText())
		assert.is_true(#link.dots > 0)
		assert.is_false(link:IsEnabled())
	end)
end)
