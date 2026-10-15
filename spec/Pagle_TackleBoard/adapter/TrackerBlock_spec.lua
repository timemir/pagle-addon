-- The tracker block maker (TKB-R122, TKB-R124, CORE-R73; tackle-board.md › UI, the tracker): a native
-- objective-tracker-style block drawn from line descriptions, in a frame look. The shop's previews draw it now
-- (TKB-R125); the live tracker (#241) fills it with live lines.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

-- Every shown widget under `widget`, depth first, skipping hidden ones and what they hold.
local function shownDescendants(widget, list)
	list = list or {}
	for _, child in ipairs(widget.children) do
		if child.shown then
			list[#list + 1] = child
			shownDescendants(child, list)
		end
	end
	return list
end

-- The texts of every shown font string under `widget`, depth first.
local function textsOf(widget)
	local texts = {}
	for _, child in ipairs(shownDescendants(widget)) do
		if child.kind == "FontString" and child.text then
			texts[#texts + 1] = child.text
		end
	end
	return texts
end

---@param color number[]
local function rgb(color)
	return { color[1], color[2], color[3] }
end

-- A block on a fresh frame, with the Tackle Board loaded.
local function newBlock()
	local loaded = board.load()
	local ns = loaded.ns
	return ns.NewTrackerBlock(loaded.env.CreateFrame("Frame")), ns, loaded
end

-- The tracker's lines as TKB-R122 lays them out: the header, an Expedition's and a Notice's line pairs, then a plain
-- line.
local LINES = {
	{ kind = "header", text = "Tackle Board", right = "12 · 4 open", fire = true },
	{
		kind = "goal",
		text = "Expedition: Catches in 5 zones of Kalimdor",
		count = "2/5",
		where = "Kalimdor · here",
		expedition = true,
	},
	{ kind = "goal", text = "30 Catches in Durotar", count = "12/30", where = "Durotar · here" },
	{ kind = "line", text = "+2 more on the board (elsewhere)" },
}

describe("A tracker block", function()
	it(
		"draws its lines top to bottom: the header with its right text, each goal's text and count then where, then plain lines (TKB-R122, CORE-R73)",
		function()
			local block = newBlock()

			block:SetLines(LINES)

			assert.are.same({
				"Tackle Board",
				"12 · 4 open",
				"Expedition: Catches in 5 zones of Kalimdor",
				"2/5",
				"Kalimdor · here",
				"30 Catches in Durotar",
				"12/30",
				"Durotar · here",
				"+2 more on the board (elsewhere)",
			}, textsOf(block))
		end
	)

	it("grows with its lines, 250 px wide, and hides the rows a shorter list no longer needs (TKB-R122)", function()
		local block, ns = newBlock()

		local tall = block:SetLines(LINES)
		local short = block:SetLines({ LINES[1], LINES[3] })

		assert.are.equal(250, ns.TRACKER_WIDTH)
		assert.are.equal(ns.TRACKER_WIDTH, block:GetWidth())
		assert.is_true(short < tall)
		assert.are.equal(short, block:GetHeight())
		assert.are.same(
			{ "Tackle Board", "12 · 4 open", "30 Catches in Durotar", "12/30", "Durotar · here" },
			textsOf(block)
		)
	end)

	it(
		"shows the flame only by a lit fire's days, and the collapse mark as minus or plus (TKB-R122, TKB-R106)",
		function()
			local block, ns = newBlock()

			block:SetLines({ LINES[1] })
			local header = block.rows[1]
			assert.is_true(header.flame:IsShown())
			assert.are.equal(ns.BOARD_TEXTURES.flame, header.flame.texture)
			assert.are.equal("Interface\\Buttons\\UI-MinusButton-Up", header.mark.texture)

			block:SetLines({ { kind = "header", text = "Tackle Board", right = "4 open", collapsed = true } })
			assert.is_false(header.flame:IsShown())
			assert.are.equal("Interface\\Buttons\\UI-PlusButton-Up", header.mark.texture)
			assert.are.same({ "Tackle Board", "4 open" }, textsOf(block))
		end
	)

	it("inks an Expedition's line apart from a Notice's, as the prototype's tracker (TKB-R122)", function()
		local block, ns = newBlock()

		block:SetLines(LINES)

		local inks = ns.TRACKER_INKS
		assert.are.same(inks.expedition, rgb(block.rows[2].text.textColor))
		assert.are.same(inks.goal, rgb(block.rows[3].text.textColor))
		assert.are_not.same(inks.goal, inks.expedition)
		assert.are.same(inks.count, rgb(block.rows[3].right.textColor))
		assert.are.same(inks.where, rgb(block.rows[3].sub.textColor))
		assert.are.same(inks.more, rgb(block.rows[4].text.textColor))
	end)

	it('draws a goal flashing "Complete" as one green line with no where line (TKB-R123)', function()
		local block, ns = newBlock()
		local flashing = { kind = "goal", text = "30 Catches in Durotar", count = "Complete", complete = true }

		local pair = block:SetLines({ LINES[3] })
		local single = block:SetLines({ flashing })

		assert.is_true(single < pair)
		assert.are.same({ "30 Catches in Durotar", "Complete" }, textsOf(block))
		local green = ns.TRACKER_INKS.complete
		assert.are.same({ 0x7d / 255, 1, 0x7d / 255 }, green) -- tracker K2's `.ln.fin`
		assert.are.same(green, rgb(block.rows[1].text.textColor))
		assert.are.same(green, rgb(block.rows[1].right.textColor))

		-- A look's inks without a green of their own keep the native one; Corkboard has its own darker green.
		local plain = { base = { 1, 1, 1 }, texture = "x", tint = { 1, 1, 1 }, alpha = 1, border = { 0, 0, 0 } }
		plain.borderSize, plain.ink = 1, {}
		block:SetFrame(plain)
		assert.are.same(green, rgb(block.rows[1].right.textColor))
		local cork = ns.TRACKER_FRAMES["tackleboard.trackerframe.corkboard"]
		block:SetFrame(cork)
		assert.are.same(cork.ink.complete, rgb(block.rows[1].right.textColor))
		assert.are_not.same(green, cork.ink.complete)
	end)

	it("gives each row the line it shows, for the live tracker's clicks (TKB-R123)", function()
		local block = newBlock()

		block:SetLines(LINES)

		assert.are.equal(LINES[3], block.rows[3].line)
	end)
end)

describe("A tracker block's frame", function()
	it("is nothing with no look: the plain native block (TKB-R124, TKB-R125)", function()
		local block = newBlock()
		block:SetLines(LINES)

		block:SetFrame(nil)

		assert.is_false(block.frame.backing:IsShown())
		assert.is_false(block.frame.grain:IsShown())
		for _, line in ipairs(block.frame.border) do
			assert.is_false(line:IsShown())
		end
	end)

	it("lays a look's backing, its grain in its tint, and its border round the block (TKB-R124)", function()
		local block = newBlock()
		block:SetLines(LINES)
		local look = {
			base = { 0.6, 0.45, 0.25 },
			texture = "Interface\\FrameGeneral\\UI-Background-Marble",
			tint = { 0.1, 0.2, 0.3 },
			alpha = 0.4,
			border = { 0.35, 0.23, 0.1 },
			borderSize = 3,
		}

		block:SetFrame(look)

		local frame = block.frame
		assert.is_true(frame.backing:IsShown())
		assert.are.same(look.base, rgb(frame.backing.color))
		assert.is_true(frame.grain:IsShown())
		assert.are.equal(look.texture, frame.grain.texture)
		assert.are.same(look.tint, rgb(frame.grain.vertexColor))
		assert.are.equal(0.4, frame.grain:GetAlpha())
		for _, line in ipairs(frame.border) do
			assert.is_true(line:IsShown())
			assert.are.same(look.border, rgb(line.color))
		end
	end)

	it("sets the words in a look's inks on a pale backing, and back in the native colours after (TKB-R124)", function()
		local block, ns = newBlock()
		local ink = {
			header = { 0.16, 0.1, 0.03 },
			dim = { 0.23, 0.16, 0.08 },
			goal = { 0.1, 0.06, 0.02 },
			expedition = { 0.1, 0.06, 0.03 },
			count = { 0.42, 0.1, 0.04 },
			where = { 0.23, 0.16, 0.08 },
			more = { 0.22, 0.15, 0.07 },
		}
		local look = {
			base = { 1, 1, 1 },
			texture = "x",
			tint = { 1, 1, 1 },
			alpha = 1,
			border = { 0, 0, 0 },
			borderSize = 1,
			ink = ink,
		}

		-- The look first, then the lines: lines drawn later still take its inks.
		block:SetFrame(look)
		block:SetLines(LINES)

		local header, goal = block.rows[1], block.rows[3]
		assert.are.same(ink.header, rgb(header.text.textColor))
		assert.are.same(ink.dim, rgb(header.right.textColor))
		assert.are.same(ink.goal, rgb(goal.text.textColor))
		assert.are.same(ink.count, rgb(goal.right.textColor))
		assert.are.same(ink.where, rgb(goal.sub.textColor))

		block:SetFrame(nil)

		local native = ns.TRACKER_INKS
		assert.are.same(native.header, rgb(header.text.textColor))
		assert.are.same(native.goal, rgb(goal.text.textColor))
	end)
end)
