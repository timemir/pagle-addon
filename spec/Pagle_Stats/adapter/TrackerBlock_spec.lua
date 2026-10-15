-- The tracker block maker (STA-R82, STA-R84; stats.md › UI › Live tracker): a native objective-tracker-style block
-- drawn from line descriptions, in a frame look. The Curio Shop's previews draw it (STA-R88), and the live tracker
-- (adapter/Tracker.lua) fills it with live lines.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local textsOf = stats.fontTexts

-- A block on a fresh frame, with Stats loaded.
local function newBlock()
	local loaded = stats.load()
	local ns = loaded.ns
	return ns.NewTrackerBlock(loaded.env.CreateFrame("Frame")), ns, loaded
end

-- The tracker's lines as STA-R82 lays them out: the header, the Session's two lines and two watches.
local LINES = {
	{ kind = "header", text = "Stats", right = "Session · 21m" },
	{ kind = "line", text = "38 Casts · 31 Catches · 7 got away" },
	{ kind = "line", text = "62 per hour · skill +3", dim = true },
	{ kind = "watch", band = "normal", name = "Raw Spotted Yellowtail", count = "40", sub = "Booty Bay · normal" },
	{ kind = "watch", name = "Raw Nightfin Snapper", count = "212", sub = "Feralas · by night · learning 37/100" },
}

describe("A tracker block", function()
	it(
		"draws its lines top to bottom: the header with its right text, plain lines, then each watch's name, count and sub-line (STA-R82)",
		function()
			local block = newBlock()

			block:SetLines(LINES)

			assert.are.same({
				"Stats",
				"Session · 21m",
				"38 Casts · 31 Catches · 7 got away",
				"62 per hour · skill +3",
				"Raw Spotted Yellowtail",
				"40",
				"Booty Bay · normal",
				"Raw Nightfin Snapper",
				"212",
				"Feralas · by night · learning 37/100",
			}, textsOf(block))
		end
	)

	it(
		"grows with its lines, about 250 px wide, and hides the rows a shorter list no longer needs (STA-R82)",
		function()
			local block, ns = newBlock()

			local tall = block:SetLines(LINES)
			local short = block:SetLines({ LINES[1], LINES[4] })

			assert.are.equal(250, ns.TRACKER_WIDTH)
			assert.are.equal(ns.TRACKER_WIDTH, block:GetWidth())
			assert.is_true(short < tall)
			assert.are.equal(short, block:GetHeight())
			assert.are.same(
				{ "Stats", "Session · 21m", "Raw Spotted Yellowtail", "40", "Booty Bay · normal" },
				textsOf(block)
			)
		end
	)

	it(
		"dots each watch in its band's colour: green normal, amber unlucky, red very unlucky, grey with no luck reading (STA-R82)",
		function()
			local block, ns = newBlock()
			local colours = ns.BAND_DOT_COLORS

			block:SetLines({
				{ kind = "watch", band = "normal", name = "a", count = "1", sub = "x" },
				{ kind = "watch", band = "unlucky", name = "b", count = "2", sub = "x" },
				{ kind = "watch", band = "veryUnlucky", name = "c", count = "3", sub = "x" },
				{ kind = "watch", name = "d", count = "4", sub = "x" },
			})

			local dots = {}
			for _, row in ipairs(block.rows) do
				local tint = row.dot.vertexColor
				dots[#dots + 1] = { tint[1], tint[2], tint[3] }
			end
			assert.are.same({ colours.normal, colours.unlucky, colours.veryUnlucky, colours.none }, dots)
			-- Green, amber, red and grey: green leads the normal dot, red the very unlucky one, and grey is even.
			assert.is_true(colours.normal[2] > colours.normal[1] and colours.normal[2] > colours.normal[3])
			assert.is_true(colours.unlucky[1] > colours.unlucky[2] and colours.unlucky[2] > colours.unlucky[3])
			assert.is_true(colours.veryUnlucky[1] > 2 * colours.veryUnlucky[2])
			assert.are.equal(colours.none[1], colours.none[2])
			assert.are.equal(colours.none[2], colours.none[3])
		end
	)
end)

describe("A tracker block's frame", function()
	it("is no paper with no look: the native block, its lines over a fading shade (STA-R84, STA-R88)", function()
		local block, ns = newBlock()
		block:SetLines(LINES)

		block:SetFrame(nil)

		assert.are.equal(ns.TRACKER_LOOKS.native, block.look)
		assert.is_false(block.paper:IsShown())
		assert.is_true(block.rows[2].shade:IsShown())
	end)

	it(
		"lays a look's paper behind the block, sliced down to its height, its ruling repeated at its pitch (STA-R84)",
		function()
			local block, ns = newBlock()
			block:SetLines(LINES)
			local logbook = ns.TRACKER_LOOKS.logbook

			block:SetFrame(logbook)

			assert.is_true(block.paper:IsShown())
			assert.are.equal(ns.ATLASES.TrackerLogbook.file, block.paper.top.texture)
			assert.are.same({ logbook.width, block:GetHeight() }, { block:GetWidth(), block.paper.height })
			assert.is_false(block.rows[2].shade:IsShown())
			-- the middle repeats every 40 units, never stretched past it
			for _, middle in ipairs(block.paper.middles) do
				if middle:IsShown() then
					assert.is_true(middle.height <= 40)
				end
			end
		end
	)

	it("sets the words in a look's inks and type, and back in the native ones after (STA-R84)", function()
		local block, ns = newBlock()
		local logbook = ns.TRACKER_LOOKS.logbook

		-- The look first, then the lines: lines drawn later still take its inks.
		block:SetFrame(logbook)
		block:SetLines(LINES)

		local header = block.rows[1].text
		local watch = block.rows[4]
		assert.are.equal("STATS", header:GetText()) -- small caps on the paper
		assert.are.same(logbook.ink.header, { header.textColor[1], header.textColor[2], header.textColor[3] })
		assert.are.same(logbook.ink.text, { watch.text.textColor[1], watch.text.textColor[2], watch.text.textColor[3] })
		assert.are.same(logbook.ink.dim, { watch.sub.textColor[1], watch.sub.textColor[2], watch.sub.textColor[3] })
		assert.are.same(
			logbook.ink.count,
			{ watch.right.textColor[1], watch.right.textColor[2], watch.right.textColor[3] }
		)
		-- the band dot in ink on the paper
		assert.are.same(ns.BAND_DOT_INKS.normal, { unpack(watch.dot.vertexColor, 1, 3) })

		block:SetFrame(nil)

		local native = ns.TRACKER_INKS
		assert.are.equal("Stats", header:GetText())
		assert.are.same(native.header, { header.textColor[1], header.textColor[2], header.textColor[3] })
		assert.are.same(native.text, { watch.text.textColor[1], watch.text.textColor[2], watch.text.textColor[3] })
	end)
end)
